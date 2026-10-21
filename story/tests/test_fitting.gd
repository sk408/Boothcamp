extends TestCase
## The fitting (Day 14, docs/FITTING.md): the chapter and its patient, the target match's rules (the
## prescription, the zone, moves and par, overshoots, what Gus hears), the visit's scores and the paper.

const TargetMatch := preload("res://story/games/target_match.gd")
const LevelFitting := preload("res://story/level_fitting.gd")
const PaperFitting := preload("res://story/papers/paper_fitting.gd")

const SAVE := "user://test_fitting_save.json"
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


func _gus(ear: String) -> Dictionary:
	return (Game.load_patient("gus") as PatientProfile).get_thresholds(ear)


func _game(ear: String = "right") -> Control:
	var g: Control = add_node(TargetMatch.new())
	g.call("setup", ear, _gus(ear), LevelFitting.DORIS_LINE)
	return g


func test_day_14_is_gus_coming_back() -> void:
	var ch := Game.chapter("gus_fit")
	assert_eq(int(ch["day"]), 14)
	assert_eq(String(ch["patient_id"]), "gus_fit")
	assert_eq(String(ch["scene"]), "res://story/level_fitting.tscn")
	assert_eq(Game.chapter_for_patient("gus_fit")["id"], "gus_fit", "its own patient id (= the chapter id), so it never scores as Day 1")
	assert_eq(Game.chapter_for_patient("gus")["id"], "gus", "Day 1 is still Day 1")
	var fit := Game.load_patient("gus_fit") as PatientProfile
	var gus := Game.load_patient("gus") as PatientProfile
	assert_eq(fit.id, "gus_fit")
	assert_eq(fit.short_name(), "Gus")
	assert_true(fit.validate().is_empty(), "the profile validates")
	for ear: String in ["right", "left"]:
		assert_eq(fit.get_thresholds(ear), gus.get_thresholds(ear), "%s: Gus's own thresholds" % ear)
		for f: int in ClinicRules.BC_FREQS:
			assert_eq(fit.get_bc_threshold(ear, f), fit.get_threshold(ear, f), "%s %d: bone matches air" % [ear, f])
	for p: StringName in [&"aid_style", &"real_ear"]:
		assert_has(Game.PHASES, p, "fitting phase")


func test_prescription_for_gus() -> void:
	# NAL-R: 0.31 H + 0.05 (H500 + H1k + H2k) + k
	var r := _gus("right")
	assert_near(TargetMatch.target_gain(r, 1000), 13.0, 0.01)
	assert_near(TargetMatch.target_gain(r, 2000), 15.65, 0.01)
	assert_near(TargetMatch.target_gain(r, 4000), 19.3, 0.01)
	assert_eq(TargetMatch.target_gain(r, 250), 0.0, "never below 0")
	assert_eq(TargetMatch.targets(r), [13, 16, 19] as Array[int])
	assert_eq(TargetMatch.targets(_gus("left")), [13, 17, 21] as Array[int])


func test_what_gus_hears() -> void:
	var line := LevelFitting.DORIS_LINE
	assert_eq(TargetMatch.heard(line, [false, false, false]), "_u_, _e _in_e_ are ba_! _all I _u_ _e _e__le on?")
	assert_eq(TargetMatch.heard(line, [true, false, false]), "_u_, _e _inche_ are ba_! Shall I _u_ _e _e__le on?")
	assert_eq(TargetMatch.heard(line, [true, true, false]), "Gu_, _e _inche_ are back! Shall I put _e kettle on?")
	assert_eq(TargetMatch.heard(line, [true, true, true]), line, "every band matched: the whole line")


func test_scores_per_band_and_moves() -> void:
	assert_eq(TargetMatch.band_accuracy(0), 1.0)
	assert_eq(TargetMatch.band_accuracy(-2), 1.0, "a bullseye either side")
	assert_near(TargetMatch.band_accuracy(5), 0.85, 0.001, "the zone's edge")
	assert_near(TargetMatch.band_accuracy(-7), 0.65, 0.001, "past the zone")
	assert_eq(TargetMatch.efficiency(3, 3), 1.0)
	assert_eq(TargetMatch.efficiency(2, 3), 1.0, "under par is still full marks")
	assert_near(TargetMatch.efficiency(5, 3), 0.76, 0.001)
	assert_eq(TargetMatch.efficiency(20, 3), 0.3, "never below 0.3")


func test_first_guess_par_and_done_gate() -> void:
	var g := _game()
	assert_eq(g.call("gains"), [7, 6, 5] as Array[int], "6, 10 and 14 dB under target")
	assert_eq(int(g.call("par")), 3, "every band starts outside the green")
	assert_eq(int(g.call("matched_count")), 0)
	g.set("_accepting", true)
	var counts: Array[int] = []
	g.connect("matched_changed", func(n: int) -> void: counts.append(n))
	for i in 2:
		g.call("_press", 0, 1)   # 7 -> 11: one run of presses is one move
	assert_eq(int(g.get("_moves")), 1)
	assert_eq(counts, [1] as Array[int], "MIDS in the green")
	g.call("_finish")
	assert_false(bool(g.get("_done")), "Done waits for all three bands")
	g.call("_press", 1, 1)
	g.call("_press", 0, 1)
	assert_eq(int(g.get("_moves")), 3, "another band, then back: two more moves")
	g.call("_press", 0, -1)
	assert_eq(int(g.get("_moves")), 4, "reversing is a new move")
	assert_true((g.call("done_button") as Button).disabled, "Done stays off")


func test_bot_solver_matches_at_par() -> void:
	var g := _game()
	g.set("_accepting", true)
	g.call("solve")
	assert_true(bool(g.get("_done")))
	var r: Dictionary = g.call("result")
	assert_eq(int(r["moves"]), 3)
	assert_eq(int(r["par"]), 3)
	for b: Dictionary in r["bands"]:
		assert_eq(int(b["err"]), 0, "%d Hz on target" % int(b["freq"]))
	assert_eq(float(r["accuracy"]), 1.0)
	assert_eq(float(r["efficiency"]), 1.0)
	assert_eq(LevelFitting.match_medal(r), "gold")


func test_overshoots_once_per_kind() -> void:
	var g := _game()
	g.set("_accepting", true)
	var kinds: Array[String] = []
	g.connect("overshoot", func(k: String) -> void: kinds.append(k))
	for i in 7:
		g.call("_press", 1, 1)   # 2k: 6 -> 20 dB, target 16: 4 over, not yet
	assert_eq(kinds, [] as Array[String])
	g.call("_press", 1, 1)   # 22: 6 over
	assert_eq(kinds, ["loud"] as Array[String], "too loud at 2k")
	g.call("_press", 1, -1)
	g.call("_press", 1, 1)
	assert_eq(kinds, ["loud"] as Array[String], "the same kind only once")
	for i in 10:
		g.call("_press", 2, 1)   # 4k: 5 -> 25, target 19: 6 over
	assert_eq(kinds, ["loud", "whistle"] as Array[String], "too much top boost whistles")
	assert_eq((g.call("result") as Dictionary)["overshoots"], ["loud", "whistle"])


func test_hoots_left_ear_keeps_the_colour() -> void:
	var g := _game()
	g.set("_accepting", true)
	g.call("solve")
	var counts: Array[int] = []
	g.connect("matched_changed", func(n: int) -> void: counts.append(n))
	await g.call("run_hoot", "left", _gus("left"))
	assert_eq(counts, [] as Array[int], "Hoot's ear never re-greys the world")
	assert_eq(g.call("gains"), [13, 17, 21] as Array[int], "the left ear on target")
	assert_eq(int((g.call("result") as Dictionary)["moves"]), 0, "unscored")


func test_keys_drive_the_bands() -> void:
	var g := _game()
	g.set("_accepting", true)
	g.call("_unhandled_input", _key(&"ui_right"))
	g.call("_unhandled_input", _key(&"ui_up"))
	assert_eq((g.call("gains") as Array)[1], 8, "Right picks HIGHS, Up boosts it")
	g.call("_unhandled_input", _key(&"ui_down"))
	assert_eq((g.call("gains") as Array)[1], 6)


func _key(action: StringName) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	return ev


func test_visit_scores_and_paper() -> void:
	var g := _game()
	g.set("_accepting", true)
	g.call("solve")
	var left: Control = _game("left")
	var res := LevelFitting.results_for(g.call("result"), 2, left.call("result"))
	assert_eq(float(res["accuracy"]), 1.0)
	assert_near(float(res["technique"]), 0.6 * 0.5 + 0.4, 0.001, "second pick, clean fit")
	assert_eq(float(res["efficiency"]), 1.0)
	var fit: Dictionary = res["fitting"]
	assert_eq(String(fit["style"]), "ric_open")
	assert_eq(int(fit["style_tries"]), 2)
	assert_true(bool(fit["left_by_hoot"]))
	Game.reset_save()
	Game.begin_visit("gus_fit")
	assert_eq(Game.current_chapter_id, "gus_fit")
	Game.set_audiometry_results(res)
	var s := Game.finish_visit()
	assert_eq(String(s["chapter_id"]), "gus_fit")
	assert_eq(int(s["day"]), 14)
	assert_true(Game.is_chapter_done("gus_fit"))
	assert_false(Game.is_chapter_done("gus"), "Day 1 is untouched")
	var rows := PaperFitting.rows(fit)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0], ["MIDS 1k", "13 dB", "13 dB", "0", "BULLSEYE"])
	var lines := PaperFitting.lines(fit)
	assert_eq(lines[0], "Moves: 3, par 3: PAR")
	assert_true(lines[1].contains("second pick"), lines[1])
	var c2: VBoxContainer = add_node(VBoxContainer.new())
	PaperFitting.new().build(c2, res, s)
	assert_true(c2.get_child_count() >= 3, "the header, the card and the lines")


func test_style_options_and_lines() -> void:
	var seen := {}
	var lengths: Array[int] = []
	for st: Array in LevelFitting.STYLES:
		var prefix := String(st[0]).substr(0, BOT_PREFIX)
		assert_false(seen.has(prefix), "the mouse bot can tell %s apart" % prefix)
		seen[prefix] = true
		lengths.append(String(st[0]).length())
	assert_eq(seen.size(), 3)
	assert_true(lengths.max() - lengths.min() <= 12, "options about as long, so length gives nothing away")
	assert_has(LevelFitting.STYLES.map(func(s: Array) -> String: return String(s[1])), LevelFitting.RIGHT_STYLE)
	# Hoot keeps to 18 words, in the level and in the game's tips
	var src := FileAccess.get_file_as_string("res://story/level_fitting.gd")
	var re := RegEx.create_from_string("_say\\(\"Hoot\", \"([^\"]*)\"\\)")
	var n := 0
	for m: RegExMatch in re.search_all(src):
		n += 1
		assert_true(m.get_string(1).split(" ", false).size() <= Hoot.MAX_WORDS, m.get_string(1))
	assert_true(n >= 10, "found Hoot's lines (%d)" % n)
	for tip: String in [TargetMatch.START_TIP, TargetMatch.LOUD_TIP, TargetMatch.WHISTLE_TIP]:
		assert_true(tip.split(" ", false).size() <= Hoot.MAX_WORDS, tip)
