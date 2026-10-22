extends TestCase
## Ears, Please! (docs/ARCADE.md part 2): the shift's pure parts (DeskRun) and the arcade hall. The
## warm-up teaches what it says, PROVE IT always lists the proof among everything else, the arrow
## keys reach every target on the real desk layout, every line Hoot says fits his bubble, the
## alarm-clock card (shift 3) says what happened and never the stamp, and each shift keeps its own
## high-score board.

const DeskRules := preload("res://story/arcade/desk_rules.gd")
const DeskDeck := preload("res://story/arcade/desk_deck.gd")
const DeskRun := preload("res://story/arcade/desk_run.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const EarsPlease := preload("res://story/arcade/ears_please.gd")
const ChartChute := preload("res://story/arcade/chart_chute.gd")
const ArcadeHall := preload("res://story/arcade/arcade_hall.gd")
const TitleScreen := preload("res://story/title_screen.gd")
const UiKit := preload("res://story/ui_kit.gd")

const SEEDS := 40

var _saved_progress: Dictionary = {}


func before_each() -> void:
	_saved_progress = Game.progress.duplicate(true)
	Game.progress["arcade"] = {}


func after_each() -> void:
	Game.progress = _saved_progress


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


## Files of every kind a playable shift deals, over many seeds.
func _deck(shift_id: int) -> Array[Dictionary]:
	var sh := DeskRules.shift(shift_id)
	var out: Array[Dictionary] = []
	for seed in SEEDS:
		var rng := _rng(seed * 31 + shift_id)
		out.append(DeskDeck.make_kind(rng, sh, "fit", seed))
		if (sh["mix"] as Dictionary).has(&"today"):
			out.append(DeskDeck.make_kind(rng, sh, "today", seed))
		for kind: String in (sh["refer_kinds"] as Dictionary):
			out.append(DeskDeck.make_kind(rng, sh, kind, seed))
	return out


func test_warm_up_files_are_what_their_step_teaches() -> void:
	for shift_id in range(1, DeskRun.PLAYABLE + 1):
		var sh := DeskRules.shift(shift_id)
		for seed in SEEDS:
			var rng := _rng(seed)
			for step: Array in DeskRun.WARMUP[shift_id]:
				var f := DeskRun.warmup_file(rng, sh, step, 1)
				var v := DeskRules.decide(f)
				var kind := String(step[0])
				var want := &"fit" if kind == "fit" or kind == "fit_masked" else (&"today" if kind == "today" else &"refer")
				assert_eq(v["decision"], want, "shift %d seed %d: warm-up %s" % [shift_id, seed, kind])
				assert_true(DeskRun.WARMUP_LINES.has(String(f["warm"])), "warm-up %s has its lines" % f["warm"])
				if String(step[1]) != "":
					assert_eq(DeskRules.best_proof(v), {"kind": "intake", "id": String(step[1])}, "the ticked box is the proof")
				if kind == "fit_masked":
					assert_true(DeskRun.has_masked_bone(f), "seed %d: the masked-bone warm-up shows brackets" % seed)
				if kind == "gap_both":
					assert_eq(DeskRun.best_reason(v, f), "Air-bone gap, both ears")
				if kind in ["today", "sudden_late", "fluctuating"]:
					assert_eq(DeskRules.best_target(v), {"kind": "sudden"}, "seed %d: the %s warm-up points at the alarm clock" % [seed, kind])


func test_prove_it_lists_every_box_and_column_and_never_hints() -> void:
	for shift_id in range(1, DeskRun.PLAYABLE + 1):
		var sh := DeskRules.shift(shift_id)
		for f: Dictionary in _deck(shift_id):
			var t := DeskRun.targets(f, sh)
			var v := DeskRules.decide(f)
			var boxes := t.filter(func(x: Dictionary) -> bool: return x["kind"] == "intake").map(func(x: Dictionary) -> String: return x["id"])
			assert_eq(boxes, sh["intake"], "every intake box of the shift, ticked or not, in order")
			var cols := t.filter(func(x: Dictionary) -> bool: return x["kind"] == "chart").map(func(x: Dictionary) -> int: return x["freq"])
			var charted: Array = (f["ac"]["right"] as Dictionary).keys()
			charted.sort()
			assert_eq(cols, charted, "every charted column, low to high")
			var clocks := t.filter(func(x: Dictionary) -> bool: return x["kind"] == "sudden").size()
			assert_eq(clocks, 1 if bool(sh["sudden"]) else 0, "the alarm clock is a target on every shift 3 file, and only there")
			if v["decision"] != &"fit":
				var best := DeskRules.best_target(v)
				assert_true(DeskRun.target_index(t, best) >= 0, "%s: the proof %s can be pointed at" % [f["kind"], best])
				assert_true(DeskRules.proof_ok(v, best), "%s: the best target proves the call" % f["kind"])
				assert_ne(DeskRun.anchor(best), "")


func test_the_arrow_keys_reach_every_target_on_the_desk() -> void:
	var view: Control = EarsPlease.FileView.new()
	view.setup()
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	for shift_id in range(1, DeskRun.PLAYABLE + 1):
		var sh := DeskRules.shift(shift_id)
		view.set("sh", sh)
		view.call("place_chart")
		for f: Dictionary in _deck(shift_id).slice(0, 12):
			view.set("file", f)
			var t := DeskRun.targets(f, sh)
			var centres: Array[Vector2] = []
			for x: Dictionary in t:
				centres.append((view.call("target_rect", x) as Rect2).get_center())
			var seen := {0: true}
			var todo := [0]
			while not todo.is_empty():
				var i: int = todo.pop_back()
				for d: Vector2 in dirs:
					var j := DeskRun.step(centres, i, d)
					if not seen.has(j):
						seen[j] = true
						todo.append(j)
			assert_eq(seen.size(), t.size(), "shift %d %s: arrows from the first box reach all %d targets" % [shift_id, f["kind"], t.size()])
			for i in t.size():
				if t[i]["kind"] == "chart":
					# Up never jumps to the intake card; on shift 3 it may reach the alarm clock above
					var up := DeskRun.step(centres, i, Vector2.UP)
					assert_true(up == i or t[up]["kind"] == "sudden", "Up on a column stays put or reaches the alarm clock")
					assert_eq(DeskRun.step(centres, i, Vector2.DOWN), i, "Down on a column stays put")
				if t[i]["kind"] == "sudden":
					assert_eq(t[DeskRun.step(centres, i, Vector2.DOWN)]["kind"], "chart", "Down from the alarm clock reaches the chart")
	view.free()


func test_the_alarm_clock_card_sits_clear_of_the_chart_and_the_intake() -> void:
	var view: Control = EarsPlease.FileView.new()
	view.setup()
	var sh := DeskRules.shift(3)
	view.set("sh", sh)
	view.call("place_chart")
	var card: Rect2 = view.call("target_rect", {"kind": "sudden"})
	for f: Dictionary in _deck(3).slice(0, 12):
		view.set("file", f)
		for x: Dictionary in DeskRun.targets(f, sh):
			if x["kind"] != "sudden":
				assert_false(card.intersects(view.call("target_rect", x) as Rect2), "the alarm clock overlaps %s" % str(x))
	assert_true(Rect2(Vector2.ZERO, view.size).encloses(card), "the alarm clock is on the file")
	assert_eq(view.call("chart_rect"), EarsPlease.FileView.CHART_LOW)
	view.set("sh", DeskRules.shift(2))
	assert_eq(view.call("chart_rect"), EarsPlease.FileView.CHART, "shifts 1 and 2 keep the tall chart")
	view.free()


func test_the_alarm_clock_says_what_happened_never_the_stamp() -> void:
	var seen := {}
	var widths: Array[float] = [202.0, 130.0, 68.0]   # FileView._draw_history's fields
	for f: Dictionary in _deck(3):
		var h := DeskRun.history(f["sudden"])
		assert_eq(h.size(), 3)
		var words := " ".join(h.map(func(x: Array) -> String: return String(x[1]))).to_upper()
		for stamp: String in ["FIT", "REFER", "TODAY", "DOCTOR"]:
			assert_false(words.contains(stamp), "the card never names the stamp: %s" % words)
		for i in h.size():
			var w := UiKit.font(700).get_string_size(String(h[i][1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			assert_true(w <= widths[i], "'%s' fits its field (%d px)" % [h[i][1], int(w)])
		var kind := String(f["kind"])
		seen[kind] = true
		var s: Dictionary = f["sudden"]
		match kind:
			"today":
				assert_true(String(h[0][1]).begins_with("Suddenly"))
				assert_true(int(s["came_on_h"]) <= CaseRules.SUDDEN_ONSET_MAX_H and int(s["days_ago"]) <= CaseRules.SUDDEN_REFER_TODAY_DAYS)
				assert_true(String(h[1][1]).ends_with("days ago") or String(h[1][1]) == "Yesterday", "under a month reads in days: %s" % h[1][1])
				assert_true(int(s["days_ago"]) >= roundi(int(s["came_on_h"]) / 24.0), "it started no later than it took to come on: %s" % str(s))
				assert_eq(String(h[2][2]), String(f["poorer"]), "the card names the ear that dropped")
			"sudden_late":
				assert_true(String(h[1][1]).ends_with("months ago"), "an old sudden loss reads in months: %s" % h[1][1])
				assert_eq(String(h[2][2]), String(f["poorer"]))
			"fluctuating":
				assert_eq(String(h[0][1]), "Comes and goes")
				assert_eq(String(h[2][1]), "–")
			_:
				assert_eq(String(h[0][1]), "Slowly, over years")
				assert_true(String(h[1][1]).ends_with("years ago"))
	for kind: String in ["fit", "today", "sudden_late", "fluctuating", "one_ear"]:
		assert_true(seen.has(kind), "shift 3 deals %s files" % kind)
	assert_eq(DeskRun.history({"pattern": "sudden", "came_on_h": 8, "days_ago": 1, "ear": "right"})[1][1], "Yesterday")
	assert_eq(DeskRun.history({"pattern": "sudden", "came_on_h": 48, "days_ago": 3, "ear": "right"})[0][1], "Suddenly, in 2 days")


func test_the_sudden_loss_card_names_both_calls_and_fits_the_wall() -> void:
	var calls: Array = DeskRules.SUDDEN_ROWS.map(func(r: Array) -> StringName: return r[1])
	assert_eq(calls, [&"today", &"refer"], "under a month: DOCTOR TODAY; older, or on and off: REFER")
	for r: Array in DeskRules.SUDDEN_ROWS:
		var w := UiKit.font(600).get_string_size(String(r[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		assert_true(w <= EarsPlease.CARD_SIZE.x - 20, "'%s' fits the card (%d px)" % [r[0], int(w)])
	var info: Dictionary = DeskRules.RULES["sudden"]
	assert_true(UiKit.font(700).get_string_size(String(info["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= EarsPlease.CARD_SIZE.x - 54, "the title fits beside the clock")
	assert_true(UiKit.font(600).get_string_size(String(info["sub"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x <= EarsPlease.CARD_SIZE.x - 54, "the sub fits beside the clock")
	# whatever the alarm clock proves, the card it lights says that call
	var lit := {}
	for f: Dictionary in _deck(3):
		var v := DeskRules.decide(f)
		var p := DeskRules.best_proof(v)
		if not p.is_empty() and DeskRules.card_for(p) == "sudden":
			var s: Dictionary = f["sudden"]
			var recent := String(s["pattern"]) == "sudden" and int(s["days_ago"]) <= CaseRules.SUDDEN_REFER_TODAY_DAYS
			assert_eq(v["decision"], calls[0] if recent else calls[1], "the lit line matches the clock: %s" % str(s))
			lit[v["decision"]] = true
	assert_true(lit.has(&"today") and lit.has(&"refer"), "shift 3 lights both lines")


func test_the_shift_picker_tiles_fit_the_screen() -> void:
	# a tile is a Button (22 px, 20 px margins, 300 px wide at least): three of them and the panel fit 1280
	var lines: Array[String] = ["Your best lately: 99,999"]
	for id in range(1, DeskRules.SHIFTS.size() + 1):
		lines.append_array(EarsPlease._shift_blurb(id).split("\n"))
		lines.append_array(EarsPlease._lock_text(id).split("\n"))
	for l: String in lines:
		var w := UiKit.font(600).get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		assert_true(w <= 260.0, "'%s' keeps its tile 300 px wide (%d px)" % [l, int(w)])


func test_every_line_hoot_says_fits_his_bubble() -> void:
	var lines: Array[String] = [DeskRun.WARMUP_WRONG_STAMP, DeskRun.WARMUP_WRONG_PROOF, DeskRun.WARMUP_DONE, DeskRun.VIP_LINE, DeskRun.INCIDENT_LINE]
	for pair: Array in DeskRun.WARMUP_LINES.values():
		for l: String in pair:
			if l != "":
				lines.append(l)
	for l: String in DeskRun.SHIFT_START.values():
		lines.append(l)
	for shift_id in range(1, DeskRun.PLAYABLE + 1):
		for f: Dictionary in _deck(shift_id):
			lines.append(DeskRun.help_line(DeskRules.decide(f), f))
	for l: String in lines:
		assert_true(l.split(" ", false).size() <= Hoot.MAX_WORDS, "%d words: %s" % [l.split(" ", false).size(), l])


func test_every_slip_has_a_title_and_names_the_proof() -> void:
	for shift_id in range(1, DeskRun.PLAYABLE + 1):
		for f: Dictionary in _deck(shift_id):
			var v := DeskRules.decide(f)
			if v["decision"] == &"fit":
				for st: StringName in [&"refer", &"today"]:
					var over := DeskRun.slip(v, f, DeskRules.OVER, st)
					assert_eq(over["title"], "EXTRA REFERRAL")
					assert_eq(String(over["line"]).contains("slow loss"), shift_id == 3, "only shift 3 files have a history to read")
				continue
			var why := DeskRun.best_reason(v, f)
			assert_ne(why, "", "%s has words for its proof" % f["kind"])
			# the slips each call can really get (DeskRules.score_call), with the stamp that gets them
			var slips: Array = [[DeskRules.MISSED_TODAY, &"refer"], [DeskRules.MISSED_TODAY, &"fit"], [DeskRules.WRONG_REASON, &"today"]] \
				if v["decision"] == &"today" else [[DeskRules.MISSED_FLAG, &"fit"], [DeskRules.WRONG_REASON, &"refer"], [DeskRules.TOO_URGENT, &"today"]]
			for pair: Array in slips:
				var s := DeskRun.slip(v, f, pair[0], pair[1])
				assert_ne(s["title"], "", "%s: %s has a title" % [f["kind"], pair[0]])
				assert_true(String(s["line"]).contains(why), "%s: '%s' names '%s'" % [pair[0], s["line"], why])


func test_every_playable_kind_has_a_lesson_and_a_breakdown_row() -> void:
	for shift_id in range(1, DeskRun.PLAYABLE + 1):
		for f: Dictionary in _deck(shift_id):
			assert_true(DeskRun.LESSONS.has(DeskRun.lesson(f)), "%s: lesson %s" % [f["kind"], DeskRun.lesson(f)])
			assert_true(DeskRun.ROWS.has(DeskRun.row(f)), "%s: row %s" % [f["kind"], DeskRun.row(f)])
			assert_true(DeskRun.ROW_TIPS.has(DeskRun.row(f)))
	for rank: String in ["Desk Legend", "Red Flag Radar", "Learning the Ropes", "Better Safe Than Sorry", "Show Your Working", "One Got Away",
			"Red Flags Got Through", "Incident Report", "Desk Closed", "Coffee Break"]:
		assert_true(DeskRun.RANK_LINES.has(rank), "rank %s has its line" % rank)


func test_each_shift_keeps_its_own_board() -> void:
	assert_eq(DeskRun.board(1), "table")
	assert_eq(DeskRun.board(2), "table_2")
	var one := ArcadeScores.table(EarsPlease.MODE, DeskRun.board(1))
	var two := ArcadeScores.table(EarsPlease.MODE, DeskRun.board(2))
	assert_eq(one[0]["initials"], "HOO")
	assert_eq(two[2]["initials"], "VIO", "shift 2 has its own seed rows")
	assert_eq(DeskRun.board(3), "table_3")
	assert_eq(ArcadeScores.table(EarsPlease.MODE, DeskRun.board(3))[1]["initials"], "MEL", "and shift 3")
	assert_eq(ArcadeScores.add_score(EarsPlease.MODE, "ZED", 30000, 1.0, DeskRun.board(2)), 0)
	assert_eq(ArcadeScores.table(EarsPlease.MODE, DeskRun.board(2))[0]["initials"], "ZED")
	assert_eq(ArcadeScores.table(EarsPlease.MODE, DeskRun.board(1))[0]["initials"], "HOO", "shift 1's board is untouched")
	assert_false(ArcadeScores.qualifies(EarsPlease.MODE, 0, DeskRun.board(2)), "a zero never makes a board")


func test_promotion_needs_says_what_is_missing() -> void:
	assert_eq(DeskRun.promotion_needs({"files": 12, "clean": 12, "helps": 0, "missed_flag": 0}), "")
	var need := DeskRun.promotion_needs({"files": 4, "clean": 2, "helps": 0, "missed_flag": 1})
	assert_true(need.contains("no red flag missed"), need)
	assert_true(need.contains("3 in 4"), need)
	assert_true(need.contains("%d+ files" % DeskRules.PROMOTE_FILES), need)


func test_the_hall_has_a_cabinet_for_each_game_and_the_title_opens_it() -> void:
	assert_eq(TitleScreen.ARCADE_SCENE, "res://story/arcade/arcade_hall.tscn")
	assert_true(ResourceLoader.exists(TitleScreen.ARCADE_SCENE))
	var ids: Array = ArcadeHall.CABINETS.map(func(c: Dictionary) -> String: return c["id"])
	assert_eq(ids, [ChartChute.MODE, EarsPlease.MODE, ChartChute.MODE_TYPES, ChartChute.MODE_TYMPS, ChartChute.MODE_DEGREES, ChartChute.MODE_FLATS, ChartChute.MODE_OTOS, ChartChute.MODE_MASKS, ChartChute.MODE_NOISE, ChartChute.MODE_SPEECH], "cabinet ids are the games' save keys, in key order")
	for c: Dictionary in ArcadeHall.CABINETS:
		assert_true(ResourceLoader.exists(String(c["scene"])), "%s opens %s" % [c["name"], c["scene"]])
	assert_eq(EarsPlease.HALL_SCENE, TitleScreen.ARCADE_SCENE, "Ears, Please! comes back to the hall")
	assert_eq(ChartChute.HALL_SCENE, TitleScreen.ARCADE_SCENE, "Chart Chute comes back to the hall")


func test_the_hall_shows_the_top_score_and_your_best() -> void:
	assert_eq(ArcadeHall._top_line(EarsPlease.MODE), "HIGH SCORE   HOO  24,000")
	assert_eq(ArcadeHall._extra_line(EarsPlease.MODE), "Never played: go on!")
	ArcadeScores.add_run(EarsPlease.MODE, {"score": 12500})
	ArcadeScores.add_run(EarsPlease.MODE, {"score": 9000})
	ArcadeScores.data(EarsPlease.MODE)["unlocked"] = 2
	assert_eq(ArcadeHall._extra_line(EarsPlease.MODE), "Your best lately: 12,500  ·  Shift 2 open")
	ArcadeScores.data(EarsPlease.MODE)["unlocked"] = 3.0   # JSON brings it back a float
	assert_eq(ArcadeHall._extra_line(EarsPlease.MODE), "Your best lately: 12,500  ·  Shift 3 open")
	ArcadeScores.data(EarsPlease.MODE)["unlocked"] = 9
	assert_eq(ArcadeHall._extra_line(EarsPlease.MODE), "Your best lately: 12,500  ·  Shift 3 open", "a hand-edited save never names a shift that isn't there")


## More cabinets than fit: pages of ArcadeHall.PAGE_SIZE. The selection turns the page, the page
## arrows and Page Up/Down turn it, and the number keys open a cabinet on any page.
func test_the_hall_turns_its_pages() -> void:
	ArcadeHall.last = 0
	var hall: Control = (load(TitleScreen.ARCADE_SCENE) as PackedScene).instantiate()
	add_node(hall)
	await wait_frames(2)
	var pages := ceili(ArcadeHall.CABINETS.size() / float(ArcadeHall.PAGE_SIZE))
	assert_eq(hall.call("page_count"), pages, "one page per %d cabinets" % ArcadeHall.PAGE_SIZE)
	assert_eq(hall.call("page"), 0, "the hall opens on the first page")
	if pages < 2:
		return
	hall.call("_select", ArcadeHall.PAGE_SIZE)
	assert_eq(hall.call("page"), 1, "selecting a cabinet on the next page turns to it")
	hall.call("_turn", -1)
	assert_eq(hall.call("page"), 0, "the previous arrow turns back")
	assert_eq(hall.call("selected"), 0, "the selection follows to the page's first cabinet")
	hall.call("_turn", -1)
	assert_eq(hall.call("page"), 0, "no page before the first")
	hall.call("_turn", 1)
	assert_eq(hall.call("selected"), ArcadeHall.PAGE_SIZE, "turning the page selects its first cabinet")
	for k in pages + 1:
		hall.call("_turn", 1)
	assert_eq(hall.call("page"), pages - 1, "no page after the last")
	var arrows: Array = hall.get("_arrows")
	assert_eq(arrows.size(), 2, "two page arrows")
	assert_false(bool(arrows[1].get("enabled")), "the next arrow is off on the last page")
	assert_true(bool(arrows[0].get("enabled")), "the previous arrow is on")
	# coming back to the hall from a cabinet on page 2 shows page 2
	hall.queue_free()
	await wait_frames(1)
	ArcadeHall.last = ArcadeHall.CABINETS.size() - 1
	var again: Control = (load(TitleScreen.ARCADE_SCENE) as PackedScene).instantiate()
	add_node(again)
	await wait_frames(2)
	assert_eq(again.call("page"), pages - 1, "the hall comes back on the last cabinet's page")
	ArcadeHall.last = 0
