extends TestCase
## The fitting (Day 14, docs/FITTING.md): the chapter and its patient, the target match's rules (the
## prescription, the zone, moves and par, overshoots, what Gus hears), the probe tube, the loud-sound
## check, the counselling, the visit's scores and the paper.

const TargetMatch := preload("res://story/games/target_match.gd")
const LevelFitting := preload("res://story/level_fitting.gd")
const PaperFitting := preload("res://story/papers/paper_fitting.gd")
const ProbeTube := preload("res://story/games/probe_tube.gd")
const LoudCheck := preload("res://story/games/loud_check.gd")

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
	for p: StringName in [&"aid_style", &"real_ear", &"probe_tube", &"loud_check", &"counselling"]:
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
	var res := LevelFitting.results_for(g.call("result"), {"style_tries": 2}, left.call("result"))
	assert_eq(float(res["accuracy"]), 1.0)
	assert_near(float(res["technique"]), 0.25 * 0.5 + 0.2 + 0.2 + 0.15 + 0.2, 0.001, "second pick, the rest clean")
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
	assert_eq(lines[2], "Tube: first try. Loud limit: first drop. Talk: three of three, no slips.")
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


func _probe() -> Control:
	var g: Control = add_node(ProbeTube.new())
	g.call("setup", "right")
	g.set("_accepting", true)
	return g


func _loud() -> Control:
	var g: Control = add_node(LoudCheck.new())
	g.set("_accepting", true)
	return g


func test_probe_tube_rules() -> void:
	assert_eq(ProbeTube.zone_of(17), "shallow")
	assert_eq(ProbeTube.zone_of(6), "shallow")
	assert_eq(ProbeTube.zone_of(5), "zone", "within 5 mm of the eardrum")
	assert_eq(ProbeTube.zone_of(1), "zone")
	assert_eq(ProbeTube.zone_of(0), "touch")
	assert_near(ProbeTube.dip_hz(17), 5044.0, 1.0, "a quarter wavelength from the drum: c / 4d")
	assert_true(ProbeTube.reading_error(17, 4000.0) < -5.0, "too shallow: the highs read low")
	assert_true(ProbeTube.reading_error(5, 8000.0) > -0.5, "within 5 mm: flat up to 8k")
	assert_true(ProbeTube.reading_error(17, 500.0) > -0.5, "the lows read right either way")
	for mm: int in [17, 14, 11, 8]:
		assert_true(ProbeTube.highs_read_low(mm), "%d mm: the strip says the highs read low" % mm)
	assert_false(ProbeTube.highs_read_low(5), "in the zone the highs read right")
	assert_false(ProbeTube.highs_read_low(2))


func test_probe_tube_bot_solver() -> void:
	var g := _probe()
	assert_eq(int(g.call("depth")), ProbeTube.START_MM)
	assert_eq(int(g.call("presses_needed")), 4, "17 -> 14 -> 11 -> 8 -> 5")
	g.call("solve")
	assert_true(bool(g.get("_done")))
	var r: Dictionary = g.call("result")
	assert_eq(int(r["depth"]), 5)
	assert_eq(int(r["mistakes"]), 0)
	assert_false(bool(r["touched"]))


func test_probe_tube_mistakes() -> void:
	var g := _probe()
	var touches := [0]
	var kinds: Array[String] = []
	g.connect("touched", func() -> void: touches[0] += 1)
	g.connect("mistake", func(k: String) -> void: kinds.append(k))
	g.call("_lock")
	assert_false(bool(g.get("_done")), "locking short of the zone is refused")
	assert_eq(kinds, ["shallow"] as Array[String])
	for i in 6:
		g.call("_slide", -1)   # 17 ... 5, 2, then -1: the drum
	assert_eq(kinds, ["shallow", "touch"] as Array[String])
	assert_eq(touches[0], 1)
	assert_eq(int(g.call("depth")), ProbeTube.RECOIL_MM, "the tube springs back out of the zone")
	for i in 3:
		g.call("_slide", -1)   # 8, 5, 2, then the drum again
	assert_eq(touches[0], 1, "only the first touch costs comfort")
	assert_eq(kinds.count("touch"), 2, "every touch is a mistake")
	g.call("_slide", -1)
	g.call("_lock")
	var r: Dictionary = g.call("result")
	assert_true(bool(g.get("_done")))
	assert_eq(int(r["mistakes"]), 3)
	assert_eq(int(r["shallow"]), 1)
	assert_true(bool(r["touched"]))


func test_probe_tube_keys() -> void:
	var g := _probe()
	g.call("_unhandled_input", _key(&"ui_right"))
	assert_eq(int(g.call("depth")), 14, "Right slides it in")
	g.call("_unhandled_input", _key(&"ui_left"))
	assert_eq(int(g.call("depth")), 17, "Left slides it out")
	g.call("_unhandled_input", _key(&"ui_accept"))
	assert_eq(int((g.call("result") as Dictionary)["shallow"]), 1, "Enter locks")


func test_loud_check_rules() -> void:
	var v: Array[String] = []
	for n in range(1, LoudCheck.NOTCHES + 1):
		v.append(LoudCheck.verdict(n))
	assert_eq(v, ["squashed", "squashed", "right", "ouch", "ouch"] as Array[String])
	assert_eq(LoudCheck.verdict(LoudCheck.START_NOTCH), "ouch", "the first guess stings")
	assert_eq(LoudCheck.verdict(LoudCheck.RIGHT_NOTCH), "right")
	assert_eq(LoudCheck.LINES.size(), LoudCheck.NOTCHES)
	var g := _loud()
	assert_eq(int(g.call("presses_needed")), -1)
	g.call("solve")
	assert_true(bool(g.get("_done")))
	assert_eq(g.call("result"), {"notch": 3, "drops": 1, "squashed": 0, "ouch": false})
	assert_eq(LevelFitting.loud_medal(1), "gold")


func test_loud_check_slips() -> void:
	var g := _loud()
	var ouches := [0]
	g.connect("ouch", func() -> void: ouches[0] += 1)
	g.call("_unhandled_input", _key(&"ui_right"))
	assert_eq(int(g.call("notch")), 5, "Right turns the limit up")
	g.call("_drop")
	g.call("_drop")
	assert_eq(ouches[0], 1, "only the first painful clang costs comfort")
	for i in 4:
		g.call("_turn", -1)
	assert_eq(int(g.call("notch")), 1, "the dial stops at 1")
	g.call("_drop")
	assert_false(bool(g.get("_done")))
	g.call("_turn", 1)
	g.call("_turn", 1)
	g.call("_unhandled_input", _key(&"ui_accept"))
	assert_true(bool(g.get("_done")), "just right finishes")
	assert_eq(g.call("result"), {"notch": 3, "drops": 4, "squashed": 1, "ouch": true})
	assert_eq(LevelFitting.loud_medal(3), "silver")
	assert_eq(LevelFitting.loud_medal(4), "bronze")


func test_technique_parts() -> void:
	var g := _game()
	g.set("_accepting", true)
	g.call("solve")
	var r: Dictionary = g.call("result")
	var w := 0.0
	for k: String in LevelFitting.TECHNIQUE_WEIGHTS:
		w += float(LevelFitting.TECHNIQUE_WEIGHTS[k])
	assert_near(w, 1.0, 0.0001, "the weights add up to 1")
	assert_near(float(LevelFitting.results_for(r, {})["technique"]), 1.0, 0.0001, "every part right first time")
	var worst := LevelFitting.results_for(r, {"style_tries": 3, "probe_mistakes": 4, "loud_drops": 6, "counsel_slips": 2})
	assert_near(float(worst["technique"]), 0.25 * 0.2 + 0.2 * 0.2 + 0.2 * 0.2 + 0.15 * 0.2 + 0.2, 0.0001, "every slip part at 0.2, still a clean fit")
	var fit: Dictionary = worst["fitting"]
	assert_eq([int(fit["probe_mistakes"]), int(fit["loud_drops"]), int(fit["counsel_slips"])], [4, 6, 2])
	var lines := PaperFitting.lines(fit)
	assert_eq(lines[2], "Tube: 4 slips. Loud limit: 6 drops. Talk: three of three, 2 slips.")


func test_counsel_options_and_lines() -> void:
	var seen := {}
	var lengths: Array[int] = []
	var right := 0
	for c: Array in LevelFitting.COUNSEL:
		var prefix := String(c[0]).substr(0, BOT_PREFIX)
		assert_false(seen.has(prefix), "the mouse bot can tell %s apart" % prefix)
		seen[prefix] = true
		lengths.append(String(c[0]).length())
		if bool(c[2]):
			right += 1
			assert_eq(String(c[3]), "", "a right tip needs no joke")
		else:
			assert_true(String(c[3]) != "", "a wrong tip gets Gus's line")
		assert_true(String(c[4]).split(" ", false).size() <= Hoot.MAX_WORDS, String(c[4]))
	assert_eq(right, 3, "three right tips: all-day wear, a few weeks, the follow-up")
	assert_eq(seen.size(), 5)
	assert_true(lengths.max() - lengths.min() <= 8, "tips about as long, so length gives nothing away")
	for tip: String in [ProbeTube.START_TIP, ProbeTube.SHALLOW_TIP, ProbeTube.TOUCH_TIP, LoudCheck.START_TIP, LoudCheck.SQUASH_TIP, LoudCheck.OUCH_TIP]:
		assert_true(tip.split(" ", false).size() <= Hoot.MAX_WORDS, tip)
