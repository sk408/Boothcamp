extends TestCase
## The career-fair demo (docs/DEMO.md): the --demo / ?demo flag, the fresh visitor per title, the
## Play-only title, the demo level's plans, paper and lines, the audiometer's "montage_after", the
## paper without Decibucks or shop, and the booth's attract loop.

const LevelDemo := preload("res://story/level_demo.gd")
const LevelGus := preload("res://story/level_gus.gd")
const TitleScreen := preload("res://story/title_screen.gd")
const DemoAttract := preload("res://story/demo_attract.gd")
const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"

const SAVE := "user://test_demo_save.json"
const MAX_HOOT_WORDS := 18

var _saved_path := ""
var _saved_progress := {}
var _saved_settings := {}
var _saved_cli := {}
var _saved_notice := false


## A patient who hears every tone at or above the threshold, with no tricks (as in the AudiOtron tests).
class FixedSim extends PatientSim:
	func _init(p: PatientProfile) -> void:
		super(p, 1)

	func on_tone_start(ear: String, freq: int, db: int, _gap_s: float) -> Dictionary:
		var c := condition(ear, freq)
		var heard := db >= int(c["threshold"])
		last_heard_by = StringName(c["by"]) if heard else &""
		return {"heard": heard, "press": heard, "guess": false, "latency_s": 0.5}

	func false_alarm_tick(_delta: float) -> bool:
		return false

	func anticipation_delay() -> float:
		return -1.0

	func keeps_press_after_short_tone(_e: String, _f: int, _d: int, _dur: float) -> bool:
		return true


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_progress = Game.progress.duplicate(true)
	_saved_settings = Game.settings.duplicate(true)
	_saved_cli = Game.cli.duplicate(true)
	_saved_notice = TitleScreen._notice_seen_this_session
	Game.save_path = SAVE


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Game.save_path = _saved_path
	Game.progress = _saved_progress
	Game.settings = _saved_settings
	Game.cli = _saved_cli
	Game.apply_settings()
	TitleScreen._notice_seen_this_session = _saved_notice
	Hoot.clear()


## Words in a line, as a reader counts them ("...An" and "OWL," are one word each).
static func _words(line: String) -> int:
	var n := 0
	for w: String in line.split(" ", false):
		var letters := RegEx.create_from_string("[A-Za-z0-9]")
		if letters.search(w) != null:
			n += 1
	return n


func test_demo_flag_and_the_web_address() -> void:
	Game.cli = {}
	assert_false(Game.is_demo(), "off by default")
	Game.cli = {"demo": true}
	assert_true(Game.is_demo(), "--demo")
	Game.cli = {}
	Game._parse_web_query("?demo")
	assert_true(Game.is_demo(), "?demo in the page's address")
	Game.cli = {}
	Game._parse_web_query("?lang=en&demo=1")
	assert_true(Game.is_demo(), "?lang=en&demo=1")
	Game.cli = {}
	Game._parse_web_query("?demo=0")
	assert_false(Game.is_demo(), "?demo=0 is off")
	Game.cli = {}
	Game._parse_web_query("?autoplay&scene=res://tools/monkey.tscn&save=user://x.json")
	assert_true(Game.cli.is_empty(), "only the listed flags: a page address can't start the bot or a dev scene")
	Game.cli = {"demo": "0"}
	Game._parse_web_query("?demo")
	assert_false(Game.is_demo(), "a flag already set stays as it is")
	assert_eq(Game.WEB_FLAGS, PackedStringArray(["demo"]))
	assert_ne(Game.DEMO_SAVE_PATH, Game.DEFAULT_SAVE_PATH, "the booth never touches a player's save")


func test_next_visitor_starts_fresh_but_keeps_the_settings() -> void:
	Game.progress["coins"] = 77
	Game.progress["plays"] = 2
	Game.progress["patients"] = {"gus": {"best_grade": "S", "best_score": 99.0, "plays": 2}}
	Game.progress["chapters_done"] = ["gus"]
	Game.settings["tone_volume"] = 0.35
	Game.settings["key_style"] = "affinity"
	Game.reset_demo_visitor()
	assert_eq(Game.progress, Game.DEFAULT_PROGRESS, "records, coins and days all go")
	assert_near(float(Game.settings["tone_volume"]), 0.35, 0.001, "the booth's volume stays")
	assert_eq(Game.settings["key_style"], "affinity", "the booth's key style stays")


func test_demo_title_is_one_play_button() -> void:
	Game.cli = {"demo": true}
	Game.progress["plays"] = 3
	Game.progress["coins"] = 80
	TitleScreen._notice_seen_this_session = true
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	assert_eq(int(Game.progress["plays"]), 0, "the title starts a fresh visitor")
	assert_eq(title.get("_state"), &"notice", "the safety notice greets every visitor")
	title.call("_on_notice_ok")
	await wait_seconds(0.6)
	var buttons: Array = title.get("_menu_buttons")
	assert_eq(buttons.size(), 1, "Play only: no days, modes, options or quit")
	assert_eq(String((buttons[0] as Button).get_meta("label")), "Play")
	assert_true(title.get("_movies_btn") == null, "no movies button")
	var texts: Array[String] = []
	for l: Label in title.find_children("*", "Label", true, false):
		texts.append(l.text)
	assert_has(texts, TitleScreen.DEMO_TAGLINE, "the tagline under Play")
	assert_false(texts.any(func(t: String) -> bool: return t.contains("Decibucks")), "no stats")
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	await tap_action(&"ui_accept")
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, [TitleScreen.DEMO_SCENE], "Enter starts the demo")


func test_demo_scene_and_its_plans() -> void:
	assert_eq(TitleScreen.DEMO_SCENE, LevelDemo.LEVEL_SCENE)
	assert_true(ResourceLoader.exists(LevelDemo.LEVEL_SCENE))
	assert_eq(LevelDemo.PATIENT_ID, "gus", "Gus, scored like Day 1 in the demo's own save")
	assert_eq(Game.chapter_for_patient(LevelDemo.PATIENT_ID)["id"], "gus")
	assert_eq(int(LevelDemo.RIGHT_PLAN["hoot_turn_after"]), 2, "the coached stamp plus one on the player's own")
	assert_true(bool(LevelDemo.RIGHT_PLAN["montage_after"]), "then Hoot fills in the rest")
	assert_eq(int(LevelDemo.LEFT_PLAN["hoot_turn_after"]), 0)
	assert_true(bool(LevelDemo.LEFT_PLAN["montage"]), "Hoot fills the left ear in seconds")
	assert_eq(LevelDemo.STEPS.size(), LevelDemo.STEP_LABELS.size())
	for s: StringName in LevelDemo.STEPS:
		assert_true(LevelDemo.STEP_LABELS.has(s), "a label for %s" % s)
	# the one chat round always brings out "dishes" (the payoff needs it): its best answer says so
	var best: Array = []
	for o: Array in LevelGus.HISTORY[0]["options"]:
		if best.is_empty() or int(o[1]) > int(best[1]):
			best = o
	assert_eq(int(best[1]), 2)
	assert_true(String(best[2]).contains("dishes"), "Gus's hardest sounds include 'dishes'")
	assert_true(LevelDemo.DORIS_LINE.contains("dishes"))


func test_demo_paper() -> void:
	var s := {"next_chapter_id": "bonnie", "chapter_id": "gus", "grade": "A"}
	LevelDemo.apply_summary(s)
	assert_true(bool(s["demo"]))
	assert_eq(s["next_chapter_id"], "", "no next day: the booth's next visitor starts at the title")
	assert_eq(s["continue_text"], "Next visitor")
	var beats: Array = []
	for pair: Array in s["medal_beats"]:
		beats.append(pair[0])
	assert_eq(beats, ["history", "otoscopy", "earphones", "match"])
	for g: String in ["S", "A", "B", "C", "Do-over"]:
		assert_true((s["headlines"] as Dictionary).has(g), "a headline for %s" % g)
		assert_true((s["subheads"] as Dictionary).has(g), "a subhead for %s" % g)
	assert_true(String(s["weather"]).begins_with("Weather:"))


## Hoot's lines (18 words or fewer), the tagline and the plans' lines.
func test_demo_lines_are_short() -> void:
	var src := FileAccess.get_file_as_string("res://story/level_demo.gd")
	var re := RegEx.create_from_string("_say\\(\"Hoot\", \"((?:[^\"\\\\]|\\\\.)*)\"")
	var lines: Array[String] = []
	for m: RegExMatch in re.search_all(src):
		lines.append(m.get_string(1))
	assert_true(lines.size() >= 15, "found Hoot's lines (%d)" % lines.size())
	lines.append(String(LevelDemo.LEFT_PLAN["intro"]))
	lines.append_array(DemoAttract.LINES)
	lines.append(DemoAttract.PROMPT)
	lines.append(String(LevelDemo.RIGHT_PLAN["hoot_turn_text"]))
	for l: String in lines:
		assert_true(_words(l) <= MAX_HOOT_WORDS, "%d words: %s" % [_words(l), l])
	assert_true(_words(TitleScreen.DEMO_TAGLINE) <= MAX_HOOT_WORDS)
	assert_true(src.contains("Ask at this booth!"), "the booth invitation")


## (demo) plan "montage_after": once the player's stamps run out, Hoot fills the rest of the ear in a
## montage (no x8 turn), and the test finishes with every hole stamped.
func test_montage_after_the_players_stamps() -> void:
	var screen := (load(AUDIOMETER) as PackedScene).instantiate() as AudiometerScreen
	add_node(screen)
	await wait_frames(2)
	Game.begin_visit("gus")
	var p := Game.load_patient("gus") as PatientProfile
	screen.quick_visit = true
	screen.start_test(p, "right", false, LevelDemo.RIGHT_PLAN)
	var s := screen.session
	s.sim = FixedSim.new(p)
	var finished := []
	screen.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	var scale := Engine.time_scale
	var stores := 0
	var guard := 0
	while stores < 2 and guard < 400:
		guard += 1
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				for i in 20:
					s.advance(0.05)
				screen._hold_add("mouse")
				for i in 30:
					s.advance(0.05)
				screen._hold_remove("mouse")
				for i in int((ClinicRules.RESPONSE_WINDOW_S + 0.1) / 0.05):
					s.advance(0.05)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"store":
				s.store()
				stores += 1
			_:
				s.advance(0.1)
	assert_eq(stores, 2, "two stamps")
	await wait_frames(2)
	assert_true(bool(screen.get_state().get("hoot_turn", false)), "Hoot takes over after the second stamp")
	var t0 := Time.get_ticks_msec()
	while finished.is_empty() and Time.get_ticks_msec() - t0 < 12000:
		assert_false(bool(screen.get("_ff_on")), "a montage, never the x8 turn")
		await wait_frames(3)
	assert_eq(finished.size(), 1, "the test finished")
	assert_near(Engine.time_scale, scale, 0.001, "game speed untouched")
	assert_true(s.is_ear_complete("right"), "every hole stamped")


func _press(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	Input.parse_input_event(up)
	await wait_frames(2)


## Gus's chart as stored, for a paper (as in test_story.gd).
static func _results() -> Dictionary:
	var p := Game.load_patient("gus") as PatientProfile
	var ears := {}
	for ear: String in ["right", "left"]:
		var freqs := {}
		var th := {}
		for f: int in [250, 500, 1000, 2000, 4000, 8000]:
			var db := p.get_threshold(ear, f)
			th[f] = db
			freqs[f] = {"ear": ear, "freq": f, "stored_db": db, "true_db": db, "no_response": false, "strokes": 7, "par": 7, "golf": &"par"}
		ears[ear] = {"freqs": freqs, "complete": true, "shape": ClinicRules.classify_shape(th), "pta": ClinicRules.pta(th)}
	return {"patient_id": "gus", "ears": ears, "presentations": 84, "false_alarms": 0, "max_combo": 10,
		"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0, "score": 100.0, "grade": "S"}


## A paper for Gus (the demo's when demo), once it has landed.
func _paper(demo: bool) -> Node:
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var s := {"patient_id": "gus", "score": 88.0, "grade": "A", "accuracy": 0.9, "technique": 0.9, "efficiency": 0.8,
		"care": 1.0, "comfort": 3, "medals": {}, "coins_earned": 60, "coins_total": 560, "audiometry": _results(),
		"patient_name": "Grandpa Gus", "patient_short": "Gus", "chapter_id": "gus", "day": 1, "next_chapter_id": ""}
	if demo:
		LevelDemo.apply_summary(s)
	var run := func() -> void:
		await paper.call("show_summary", s)
	run.call()
	await wait_seconds(1.2)
	return paper


## The texts of a paper's labels and buttons on show.
static func _shown(paper: Node) -> Array[String]:
	var shown: Array[String] = []
	for c: Node in paper.find_children("*", "", true, false):
		if (c is Label or c is Button) and (c as Control).is_visible_in_tree():
			shown.append(c.get("text"))
	return shown


## (demo) The demo's paper has no Decibucks and no shop, and B buys nothing; the WANTED ad stays.
func test_demo_paper_has_no_coins_or_shop() -> void:
	Game.progress["coins"] = 500
	var plain: Node = await _paper(false)
	assert_true(_shown(plain).any(func(t: String) -> bool: return t.contains("Decibucks")), "a normal paper keeps its coins")
	plain.queue_free()
	await wait_frames(2)
	var shown := _shown(await _paper(true))
	assert_false(shown.any(func(t: String) -> bool: return t.contains("Decibucks")), "no Decibucks: %s" % str(shown))
	assert_false(shown.any(func(t: String) -> bool: return t.begins_with("CLASSIFIEDS") or t.begins_with("Buy")), "no shop")
	assert_true(shown.any(func(t: String) -> bool: return t.begins_with("WANTED")), "the WANTED ad")
	assert_true(shown.any(func(t: String) -> bool: return t.begins_with("Next visitor")), "Next visitor")
	await _press(KEY_B)
	assert_eq(int(Game.progress["coins"]), 500, "B buys nothing")
	assert_true((Game.progress.get("upgrades", []) as Array).is_empty())


## (demo) Nobody at the demo's title: the attract loop starts (here after half a second), a nudge of
## the mouse leaves it running, and a key ends it with the safety notice for the visitor.
func test_attract_loop_at_the_booth() -> void:
	assert_near(TitleScreen.ATTRACT_S, 30.0, 0.001)
	Game.cli = {"demo": true, "attract-after": "0.5"}
	assert_near(TitleScreen.attract_after(), 0.5, 0.001, "--attract-after")
	TitleScreen._notice_seen_this_session = true
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	title.call("_on_notice_ok")
	await wait_seconds(0.3)
	assert_eq(title.get("_state"), &"menu")
	var a: Control = title.get("_attract")
	assert_true(a != null, "the demo's title has the attract loop")
	assert_false(bool(a.call("is_running")))
	await wait_seconds(1.0)
	assert_true(bool(a.call("is_running")), "it starts with nobody there")
	assert_true(a.visible)
	var nudge := InputEventMouseMotion.new()
	nudge.relative = Vector2(2, 1)
	nudge.screen_relative = Vector2(2, 1)
	Input.parse_input_event(nudge)
	await wait_frames(3)
	assert_true(bool(a.call("is_running")), "a nudge of the mouse is not a visitor")
	await _press(KEY_SPACE)
	assert_false(bool(a.call("is_running")), "a key ends it")
	assert_eq(title.get("_state"), &"notice", "the safety notice greets the visitor")
	Game.cli["attract-after"] = "100"   # (so it does not come back while we look)
	await wait_seconds(0.5)
	assert_false(a.visible)
	assert_eq(title.get("_state"), &"notice", "the key that woke it did not also close the notice")


## The attract loop is only for the demo, and never under autoplay.
func test_no_attract_loop_outside_the_booth() -> void:
	TitleScreen._notice_seen_this_session = true
	for cli: Dictionary in [{}, {"demo": true, "autoplay": true}]:
		Game.cli = cli
		var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
		add_node(title)
		await wait_frames(3)
		assert_true(title.get("_attract") == null, "no attract loop with %s" % str(cli))
		title.queue_free()
		await wait_frames(2)
