extends TestCase
## Ears, Please! (docs/ARCADE.md part 2): the shift's pure parts (DeskRun) and the arcade hall. The
## warm-up teaches what it says, PROVE IT always lists the proof among everything else, the arrow
## keys reach every target on the real desk layout, every line Hoot says fits his bubble, and each
## shift keeps its own high-score board.

const DeskRules := preload("res://story/arcade/desk_rules.gd")
const DeskDeck := preload("res://story/arcade/desk_deck.gd")
const DeskRun := preload("res://story/arcade/desk_run.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const EarsPlease := preload("res://story/arcade/ears_please.gd")
const ChartChute := preload("res://story/arcade/chart_chute.gd")
const ArcadeHall := preload("res://story/arcade/arcade_hall.gd")
const TitleScreen := preload("res://story/title_screen.gd")

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
				var want := &"fit" if kind == "fit" or kind == "fit_masked" else &"refer"
				assert_eq(v["decision"], want, "shift %d seed %d: warm-up %s" % [shift_id, seed, kind])
				assert_true(DeskRun.WARMUP_LINES.has(String(f["warm"])), "warm-up %s has its lines" % f["warm"])
				if String(step[1]) != "":
					assert_eq(DeskRules.best_proof(v), {"kind": "intake", "id": String(step[1])}, "the ticked box is the proof")
				if kind == "fit_masked":
					assert_true(DeskRun.has_masked_bone(f), "seed %d: the masked-bone warm-up shows brackets" % seed)
				if kind == "gap_both":
					assert_eq(DeskRun.best_reason(v, f), "Air-bone gap, both ears")


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
					assert_eq(DeskRun.step(centres, i, Vector2.UP), i, "Up on a column stays put")
					assert_eq(DeskRun.step(centres, i, Vector2.DOWN), i, "Down on a column stays put")
	view.free()


func test_every_line_hoot_says_fits_his_bubble() -> void:
	var lines: Array[String] = [DeskRun.WARMUP_WRONG_STAMP, DeskRun.WARMUP_WRONG_PROOF, DeskRun.WARMUP_DONE, DeskRun.VIP_LINE]
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
				var over := DeskRun.slip(v, f, DeskRules.OVER, &"refer")
				assert_eq(over["title"], "EXTRA REFERRAL")
				continue
			var why := DeskRun.best_reason(v, f)
			assert_ne(why, "", "%s has words for its proof" % f["kind"])
			for o: StringName in [DeskRules.MISSED_FLAG, DeskRules.WRONG_REASON]:
				var s := DeskRun.slip(v, f, o, &"refer")
				assert_ne(s["title"], "", "%s: %s has a title" % [f["kind"], o])
				assert_true(String(s["line"]).contains(why), "%s: '%s' names '%s'" % [o, s["line"], why])


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
	assert_eq(ids, [ChartChute.MODE, EarsPlease.MODE], "cabinet ids are the games' save keys, in key order")
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
