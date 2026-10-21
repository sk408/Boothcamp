extends TestCase
## The tune-up (Day 15, docs/TUNEUP.md): the chapter and its patient, the opening question, the
## tune-up desk's tickets and tools, the datalog, the visit's scores and the paper.

const TuneDesk := preload("res://story/games/tune_desk.gd")
const BingoNight := preload("res://story/games/bingo_night.gd")
const WaxGuard := preload("res://story/games/wax_guard.gd")
const LevelTuneup := preload("res://story/level_tuneup.gd")
const PaperTuneup := preload("res://story/papers/paper_tuneup.gd")
const TargetMatch := preload("res://story/games/target_match.gd")
const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")

const SAVE := "user://test_tuneup_save.json"
const BOT_PREFIX := 18   # the mouse bot clicks an option by its first 18 characters

var _saved_path := ""
var _saved_progress := {}
var _saved_settings := {}
var _saved_chapter := ""


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_progress = Game.progress.duplicate(true)
	_saved_settings = Game.settings.duplicate(true)
	_saved_chapter = Game.current_chapter_id
	Game.save_path = SAVE


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Game.save_path = _saved_path
	Game.progress = _saved_progress
	Game.settings = _saved_settings
	Game.apply_settings()
	Game.current_chapter_id = _saved_chapter


static func _words(line: String) -> int:
	return line.split(" ", false).size()


func _desk() -> Control:
	var g: Control = add_node(TuneDesk.new())
	g.call("show_ticket", 0)
	g.set("_accepting", true)
	return g


func test_day_15_is_gus_tune_up() -> void:
	var ch := Game.chapter("gus_tune")
	assert_eq(int(ch["day"]), 15)
	assert_eq(String(ch["patient_id"]), "gus_tune")
	assert_eq(String(ch["requires"]), "gus_fit")
	assert_eq(String(ch["scene"]), "res://story/level_tuneup.tscn")
	assert_true(ResourceLoader.exists(String(ch["scene"])))
	assert_eq(Game.chapter_for_patient("gus_tune")["id"], "gus_tune", "its own patient id (= the chapter id)")
	var tune := Game.load_patient("gus_tune") as PatientProfile
	var gus := Game.load_patient("gus") as PatientProfile
	assert_eq(tune.id, "gus_tune")
	assert_eq(tune.short_name(), "Gus")
	assert_true(tune.validate().is_empty(), "the profile validates")
	for ear: String in ["right", "left"]:
		assert_eq(tune.get_thresholds(ear), gus.get_thresholds(ear), "%s: Gus's own thresholds" % ear)
	for p: StringName in [&"datalog", &"tune_desk", &"listening_check"]:
		assert_has(Game.PHASES, p, "tune-up phase")


func test_opening_question() -> void:
	var seen := {}
	var right := 0
	for a: Array in LevelTuneup.ASKS:
		var prefix := String(a[0]).substr(0, BOT_PREFIX)
		assert_false(seen.has(prefix), "the mouse bot can tell %s apart" % prefix)
		seen[prefix] = true
		if String(a[1]) == LevelTuneup.RIGHT_ASK:
			right += 1
		for k in [2, 3]:
			assert_true(_words(String(a[k])) <= Hoot.MAX_WORDS, String(a[k]))
	assert_eq(right, 1, "one right question")
	assert_eq(LevelTuneup._ask_index(LevelTuneup.RIGHT_ASK), 1)


func test_one_right_tool_per_ticket_and_every_line_short() -> void:
	var ids: Array[String] = []
	for t: Array in TuneDesk.TOOLS:
		ids.append(String(t[0]))
	assert_eq(ids.size(), 7)
	assert_has(ids, TuneDesk.HARM_TOOL)
	var rights := {}
	for i in TuneDesk.TICKETS.size():
		var t: Dictionary = TuneDesk.TICKETS[i]
		assert_has(ids, String(t["right"]), "%s: its right tool is on the tray" % t["id"])
		rights[String(t["right"])] = true
		var n_right := 0
		for tool: String in ids:
			if TuneDesk.is_right(i, tool):
				n_right += 1
			var lines: Array = TuneDesk.lines_for(i, tool)
			assert_false(lines.is_empty(), "%s / %s plays something" % [t["id"], tool])
			for l: Array in lines:
				assert_true(_words(String(l[1])) <= Hoot.MAX_WORDS, "%d words: %s" % [_words(String(l[1])), l[1]])
		assert_eq(n_right, 1, "%s has one right tool" % t["id"])
		for key: String in (t["lines"] as Dictionary):
			assert_true(key == "default" or ids.has(key), "%s: %s is a tool" % [t["id"], key])
	assert_eq(rights.size(), TuneDesk.TICKETS.size(), "every ticket needs a different tool")
	assert_false(rights.has(TuneDesk.HARM_TOOL), "whole aid up fixes nothing")
	assert_true(_words(TuneDesk.START_TIP) <= Hoot.MAX_WORDS)


func test_level_lines_are_short() -> void:
	var src := FileAccess.get_file_as_string("res://story/level_tuneup.gd")
	var re := RegEx.create_from_string("_say\\(\"(\\w+)\", \"([^\"]*)\"\\)")
	var n := 0
	for m: RegExMatch in re.search_all(src):
		n += 1
		assert_true(_words(m.get_string(2)) <= Hoot.MAX_WORDS, m.get_string(2))
	assert_true(n >= 15, "found the level's lines (%d)" % n)
	for s: Array in LevelTuneup.STORIES:
		assert_true(_words(String(s[1])) <= Hoot.MAX_WORDS, String(s[1]))


func test_muffled_doris_is_the_fittings_strip() -> void:
	var line: Array = TuneDesk.lines_for(0, "all_down")[0]
	assert_eq(String(line[0]), "Doris")
	assert_eq(String(line[1]), TargetMatch.heard("Your tea's ready, dear!", [false, false, false]))


func test_datalog() -> void:
	assert_eq(TuneDesk.DATALOG_HOURS.size(), 14, "two weeks")
	assert_near(TuneDesk.datalog_average(), 3.5, 0.001, "the ticket says 3.5 hours")
	for d: int in TuneDesk.DATALOG_BINGO:
		assert_eq(TuneDesk.DATALOG_HOURS[d], 0.0, "none on bingo night")
	assert_true(String(TuneDesk.TICKETS[3]["text"]).contains("3.5"))
	assert_true(LevelTuneup.DATALOG_NOTE.contains("3.5"))


func test_scoring_rules() -> void:
	assert_eq(TuneDesk.ticket_score(1), 1.0)
	assert_eq(TuneDesk.ticket_score(2), 0.5)
	assert_eq(TuneDesk.ticket_score(5), 0.2)
	assert_eq(TuneDesk.accuracy_of([1, 1, 2, 3]), (1.0 + 1.0 + 0.5 + 0.2) / 4.0)
	assert_eq(TuneDesk.efficiency(4, 4), 1.0)
	assert_near(TuneDesk.efficiency(6, 4), 0.76, 0.001)
	assert_eq(TuneDesk.efficiency(30, 4), 0.3)


func test_desk_solves_and_keeps_score() -> void:
	var g := _desk()
	# a wrong tool first, then the bot's solver
	var wrong := "all_down"
	g.call("_use", TuneDesk.tool_index(wrong))
	g.call("mark_wrong", wrong)
	g.set("_accepting", true)
	g.call("_set_tools_enabled", true)
	assert_true((g.call("tool_button", wrong) as Button).disabled, "a wrong tool stays greyed for the ticket")
	g.call("solve")
	g.call("stamp_fixed")
	for i in range(1, TuneDesk.TICKETS.size()):
		g.call("show_ticket", i)
		g.set("_accepting", true)
		assert_eq(String(g.call("right_tool")), String(TuneDesk.TICKETS[i]["right"]))
		g.call("_set_tools_enabled", true)
		assert_false((g.call("tool_button", wrong) as Button).disabled, "a new ticket clears the greyed tools")
		g.call("solve")
		g.call("stamp_fixed")
	var r: Dictionary = g.call("result")
	assert_eq(int(r["tools_used"]), 5)
	assert_eq(int(r["par"]), 4)
	assert_eq(int(r["tickets"][0]["tries"]), 2)
	assert_eq(r["tickets"][0]["wrong"], [wrong])
	for t: Dictionary in r["tickets"]:
		assert_true(bool(t["fixed"]))
	# the panel draws in both modes, the stamp included
	await wait_frames(2)
	g.set("_mode", "log")
	await wait_frames(2)


func test_visit_scores_and_paper() -> void:
	var desk := {"tickets": [
		{"id": "sharp", "fix": "soften_loud", "tries": 2, "wrong": ["all_up"], "fixed": true},
		{"id": "whistle", "fix": "feedback_test", "tries": 1, "wrong": [], "fixed": true},
		{"id": "bingo", "fix": "noise_program", "tries": 1, "wrong": [], "fixed": true},
		{"id": "hours", "fix": "talk", "tries": 1, "wrong": [], "fixed": true}], "tools_used": 5, "par": 4}
	var res := LevelTuneup.results_for(desk, 2, 1)
	assert_near(float(res["accuracy"]), 3.5 / 4.0, 0.001)
	assert_near(float(res["technique"]), 0.5 * 0.5 + 0.5 * 0.5, 0.001, "second question, one whole aid up")
	assert_near(float(res["efficiency"]), 0.88, 0.001)
	assert_eq(LevelTuneup.results_for(desk, 1, 0)["technique"], 1.0)
	assert_eq(LevelTuneup.results_for(desk, 1, 2)["technique"], 0.5, "two ups: not safe")
	assert_eq(LevelTuneup.tune_medal(desk), "silver")
	assert_eq(LevelTuneup.tune_medal({"tickets": [{"wrong": []}]}), "gold")
	assert_eq(LevelTuneup.tune_medal({"tickets": [{"wrong": ["a", "b", "c"]}]}), "bronze")
	var tune: Dictionary = res["tuneup"]
	assert_eq(int(tune["ask_tries"]), 2)
	assert_eq(int(tune["ups"]), 1)
	Game.reset_save()
	Game.begin_visit("gus_tune")
	assert_eq(Game.current_chapter_id, "gus_tune")
	Game.set_audiometry_results(res)
	var s := Game.finish_visit()
	assert_eq(String(s["chapter_id"]), "gus_tune")
	assert_eq(int(s["day"]), 15)
	assert_true(Game.is_chapter_done("gus_tune"))
	assert_false(Game.is_chapter_done("gus_fit"), "Day 14 is untouched")
	var rows := PaperTuneup.rows(tune)
	assert_eq(rows.size(), 4)
	assert_eq(rows[0], ["Sharp teaspoons", "Soften loud highs", "2", "FIXED"])
	assert_eq(rows[1], ["Whistle at hugs", "Feedback test", "1", "FIRST TRY"])
	var lines := PaperTuneup.lines(tune)
	assert_eq(lines[0], "Tools: 5, par 4: BOGEY")
	assert_true(lines[1].contains("second pick"), lines[1])
	assert_true(lines[2].begins_with("Whole aid up: once"), lines[2])
	var c2: VBoxContainer = add_node(VBoxContainer.new())
	PaperTuneup.new().build(c2, res, s)
	assert_true(c2.get_child_count() >= 3, "the header, the card and the lines")


func test_bingo_night_draws() -> void:
	var b: Control = add_node(BingoNight.new())
	await wait_frames(2)
	b.call("set_program", true)
	assert_true(bool(b.call("is_program_on")))
	b.call("call_ball", 22)
	b.set("_bingo_t", 0.5)
	await wait_frames(2)


## (part 2) Hoot's tune-up movie: registered, valid and quiet, listed as "Day 15", with short lines,
## and the diary scene shows Gus's own hours.
func test_tuneup_movie() -> void:
	var id := LevelTuneup.MOVIE_ID
	assert_eq(id, "tuneup")
	var bad := Movies.validate(id, Stage2D.SETS)
	assert_true(bad.is_empty(), "%s: %s" % [id, ", ".join(bad)])
	assert_false(Movies.is_short(id), "a full movie")
	assert_has(Movies.replay_ids(), id, "on the title's list")
	assert_eq(Movies.day_label(id), "Day 15")
	assert_has(Movies.for_level("gus_tune", true), id, "Day 15's pause menu")
	var player_script: GDScript = load("res://story/explainers/explainer_player.gd")
	var cue_max := float(player_script.get_script_constant_map()["CUE_MAX_DB"])
	var m := Movies.movie(id)
	assert_true(float((m["scenes"][0] as Dictionary).get("duration", 0.0)) >= 7.0, "the lead-in card holds")
	for sc: Dictionary in m["scenes"]:
		for cue: Dictionary in sc.get("cues", []):
			assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s: a known Sfx" % sc["id"])
			assert_true(float(cue.get("vol_db", 0.0)) <= cue_max, "%s: %s is quiet" % [sc["id"], cue["sfx"]])
		if String(sc["id"]) == "diary":
			var p: Dictionary = sc["params"]
			assert_eq(p["hours"], TuneDesk.DATALOG_HOURS as Array, "Gus's own diary")
			assert_eq(float(p["goal"]), TuneDesk.DATALOG_GOAL_H)
	for l: String in [LevelTuneup.MOVIE_NEW, LevelTuneup.MOVIE_AGAIN, LevelTuneup.MOVIE_SKIPPED]:
		assert_true(_words(l) <= Hoot.MAX_WORDS, l)


func test_tuneup_movie_draws_every_scene() -> void:
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	var m := Movies.movie("tuneup")
	st.call("use_movie", m)
	for sc: Dictionary in m["scenes"]:
		st.call("show_scene", sc)
		var d := float(sc["duration"])
		for tt: float in [0.0, d * 0.2, d * 0.45, d * 0.7, d * 0.9, d]:
			st.set("t", tt)
			st.queue_redraw()
			await wait_frames(1)
	st.queue_free()


## (part 2) The listening check: one right part (the wax guard), short findings, the bot's path.
func test_wax_guard_check() -> void:
	var right := 0
	for p: Array in WaxGuard.PARTS:
		if bool(p[3]):
			right += 1
			assert_eq(String(p[0]), WaxGuard.RIGHT_PART)
		assert_true(_words(String(p[2])) <= Hoot.MAX_WORDS, String(p[2]))
	assert_eq(right, 1)
	assert_true(WaxGuard.is_right("guard"))
	assert_false(WaxGuard.is_right("battery"))
	var g: Control = add_node(WaxGuard.new())
	await wait_frames(1)
	var picked: Array = []
	var pick_it := func() -> void: picked.append(await g.call("pick"))
	pick_it.call()
	await wait_frames(1)
	g.call("_click", "battery")
	await wait_frames(1)
	assert_eq(picked, ["battery"])
	g.call("mark_checked", "battery")
	pick_it.call()
	await wait_frames(1)
	g.call("_click", "battery")
	await wait_frames(1)
	assert_eq(picked.size(), 1, "a checked part is greyed")
	g.call("solve")
	await wait_frames(1)
	assert_eq(picked, ["battery", "guard"])
	assert_eq(g.call("result"), {"tries": 2, "wrong": ["battery"]})
	var done := [false]
	var swap_it := func() -> void:
		await g.call("swap")
		done[0] = true
	swap_it.call()
	await wait_frames(1)
	assert_true((g.call("part_button", "swap") as Button).visible)
	g.call("solve")
	await wait_seconds(1.6)
	assert_true(done[0], "the new guard clicked in")
	assert_true(bool(g.get("_swapped")))


## (part 2) The next-visit plan: one right option, told apart by the mouse bot, short lines.
func test_next_visit_plan() -> void:
	var seen := {}
	var right := 0
	var lengths: Array[int] = []
	for p: Array in LevelTuneup.PLANS:
		var prefix := String(p[0]).substr(0, BOT_PREFIX)
		assert_false(seen.has(prefix), prefix)
		seen[prefix] = true
		lengths.append(String(p[0]).length())
		if String(p[1]) == LevelTuneup.RIGHT_PLAN:
			right += 1
		for k in [2, 3]:
			assert_true(_words(String(p[k])) <= Hoot.MAX_WORDS, String(p[k]))
	assert_eq(right, 1)
	assert_true(lengths.max() - lengths.min() <= 12, "about as long, so length gives nothing away")
	assert_eq(LevelTuneup._plan_index(LevelTuneup.RIGHT_PLAN), 1)
	var tune: Dictionary = LevelTuneup.results_for({"tickets": [], "tools_used": 4, "par": 4}, 1, 0, {"check_tries": 2, "plan_tries": 1})["tuneup"]
	var lines := PaperTuneup.lines(tune)
	assert_true(lines.has("Listening check: a plugged wax guard, found on the second pick."), str(lines))
	assert_true(lines.has("Next visit: a check in a few months, a test every year (first pick)."), str(lines))
