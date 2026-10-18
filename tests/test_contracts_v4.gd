extends TestCase
## (v4) Day 2 feedback contract checks (CONTRACTS.md, everything marked v4): Hoot's movies (the
## registry, the data, the player's beat, keys and events, the pause-menu replay), Game.movies_seen,
## the new phases, bone on the better (left) ear first, the one-tone Ghost demo (plan demo_tone)
## and the unmasked-bone rule (from either mastoid).

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const PLAYER := "res://story/explainers/explainer_player.tscn"
const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const PAUSE_MENU := "res://story/pause_menu.tscn"
const EVENTS_SIGNALS_V4 := ["explainer_started", "explainer_scene", "explainer_finished"]
const MASKING_SCENES := ["meet", "air", "wall", "bone", "ghost", "mask", "under", "over", "plateau", "outro"]

var _saved_path := ""
var _saved_progress := {}
var _saved_settings := {}


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_progress = Game.progress.duplicate(true)
	_saved_settings = Game.settings.duplicate(true)
	Game.save_path = "user://test_save_v4.json"


func after_each() -> void:
	if tree.paused:
		tree.paused = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save_v4.json"))
	Game.save_path = _saved_path
	Game.progress = _saved_progress
	Game.settings = _saved_settings
	Hoot.clear()


# ---------------------------------------------------------------- Events, Game

func test_events_v4_signals() -> void:
	for s in EVENTS_SIGNALS_V4:
		assert_has_signal(Events, s, "Events (v4)")


func test_game_v4_phases_and_movies_seen() -> void:
	assert_has(Game.PHASES, &"explainer", "v4 phase")
	assert_has(Game.PHASES, &"ghost_demo", "v4 phase")
	assert_has(Game.DEFAULT_PROGRESS, "movies_seen", "v4 progress key")
	assert_eq(Game.DEFAULT_PROGRESS["movies_seen"], [], "nothing seen on a new save")
	Game.progress["movies_seen"] = []
	assert_false(Game.is_movie_seen("masking"))
	Game.mark_movie_seen("masking")
	Game.mark_movie_seen("masking")
	assert_true(Game.is_movie_seen("masking"))
	assert_eq(Game.progress["movies_seen"], ["masking"], "marked once")
	Game.progress.erase("movies_seen")
	assert_false(Game.is_movie_seen("masking"), "an old save without the key")
	Game.mark_movie_seen("masking")
	assert_true(Game.is_movie_seen("masking"), "the key is created")


# ---------------------------------------------------------------- the movie data

func test_movies_registry() -> void:
	assert_has(Movies.ids(), "masking")
	assert_true(Movies.has("masking"))
	assert_false(Movies.has("nope"))
	assert_eq(Movies.movie("nope"), {})
	assert_eq(Movies.for_chapter("bonnie"), ["masking"] as Array[String], "Day 2 plays the masking movie")
	assert_true(Movies.for_chapter("gus").is_empty(), "Day 1 has no movie (Day 1 must not change)")
	assert_eq(Movies.title("masking"), "Hoot's masking movie")


func test_masking_movie_is_valid() -> void:
	var bad := Movies.validate("masking", Stage2D.SETS)
	assert_true(bad.is_empty(), "validate: %s" % ", ".join(bad))
	var m := Movies.movie("masking")
	var ids: Array = []
	for sc: Dictionary in m["scenes"]:
		ids.append(String(sc["id"]))
		assert_true(String(sc["teaches"]) != "", "%s teaches one idea" % sc["id"])
		for c: Variant in sc["captions"]:
			assert_true(Movies.word_count(String(c)) <= 18, "Hoot caption <= 18 words: %s" % c)
	assert_eq(ids, MASKING_SCENES, "the storyboard (docs/CHAPTER2.md §16)")
	assert_between(Movies.total_s("masking"), 60.0, 100.0, "a short: about 60-100 s")


## The facts Steve reviews (docs/CHAPTER2.md §16): IA 40 on-ear / 55+ inserts, bone 0, plateau 15 dB.
func test_masking_movie_facts() -> void:
	var by := {}
	for sc: Dictionary in Movies.movie("masking")["scenes"]:
		by[String(sc["id"])] = sc
	var wall: Dictionary = by["wall"]["params"]
	assert_eq(int(wall["ia"]), ClinicRules.ia_rule(&"phones"), "on-ear IA = the rule (40)")
	assert_eq(int(wall["inserts_ia"]), ClinicRules.ia_rule(&"inserts"), "inserts IA = the rule (55)")
	assert_eq(int(by["bone"]["params"]["ia"]), ClinicRules.ia_rule(&"bone"), "bone IA treated as 0")
	var p: Dictionary = by["plateau"]["params"]
	var rise: Array = p["rise"]
	var flat: Array = p["flat"]
	var last_rise: Array = rise[-1]
	for pt: Array in flat:
		assert_eq(int(pt[1]), int(last_rise[1]), "the answer holds on the plateau")
	for i in range(1, flat.size()):
		assert_eq(int(flat[i][0]) - int(flat[i - 1][0]), ClinicRules.MASK_STEP_DB, "5 dB noise steps")
	assert_eq(flat.size(), ClinicRules.PLATEAU_STEPS, "three steps")
	assert_eq(int(flat[-1][0]) - int(last_rise[0]), ClinicRules.PLATEAU_STEPS * ClinicRules.MASK_STEP_DB, "the same answer through 15 dB more noise")
	for i in range(1, rise.size()):
		assert_eq(int(rise[i][1]) - int(rise[i - 1][1]), int(rise[i][0]) - int(rise[i - 1][0]), "the Ghost climbs with the noise")
	# overmasking: the noise minus IA reaches the test cochlea
	var over: Dictionary = by["over"]["params"]
	assert_true(int(over["mask_db"]) - int(over["ia"]) >= int(last_rise[1]), "the 'too much' scene really overmasks")


## Every sound is quiet (CONTRACTS.md §1.3): Sfx names only, at -6 dB or softer, nothing loud.
func test_masking_movie_sounds_are_quiet() -> void:
	var player_script: GDScript = load("res://story/explainers/explainer_player.gd")
	var cue_max := float(player_script.get_script_constant_map()["CUE_MAX_DB"])
	assert_true(cue_max <= -6.0, "cue cap")
	for sc: Dictionary in Movies.movie("masking")["scenes"]:
		for cue: Dictionary in sc.get("cues", []):
			assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s: a known Sfx" % sc["id"])
			assert_true(float(cue.get("vol_db", 0.0)) <= cue_max, "%s: %s at %s dB" % [sc["id"], cue["sfx"], cue.get("vol_db", 0.0)])
			assert_between(float(cue.get("t", 0.0)), 0.0, float(sc["duration"]), "%s: cue inside the scene" % sc["id"])


# ---------------------------------------------------------------- the player

func _player() -> CanvasLayer:
	var p: CanvasLayer = (load(PLAYER) as PackedScene).instantiate()
	add_node(p)
	return p


func test_player_beat_solver_and_events() -> void:
	Game.progress["movies_seen"] = []
	var p := _player()
	await wait_frames(1)
	assert_eq(p.layer, 85, "above the Hoot bubble, below the pause menu")
	var got := {"scenes": [], "finished": []}
	var on_beat := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"explainer":
			got["info"] = info
			got["solver"] = solver
	var on_start := func(id: String, src: String) -> void: got["started"] = [id, src]
	var on_scene := func(_id: String, i: int, sid: String) -> void: (got["scenes"] as Array).append([i, sid])
	var on_done := func(id: String, skipped: bool) -> void: (got["finished"] as Array).append([id, skipped])
	var on_res := func(b: StringName) -> void:
		if b == &"explainer":
			got["resolved"] = true
	Events.awaiting_input.connect(on_beat)
	Events.explainer_started.connect(on_start)
	Events.explainer_scene.connect(on_scene)
	Events.explainer_finished.connect(on_done)
	Events.input_resolved.connect(on_res)
	var result := {}
	var run := func() -> void: result.merge(await p.call("play", "masking", "test"))
	run.call()
	await wait_frames(2)
	assert_true(bool(p.call("is_playing")))
	assert_eq(got.get("started", []), ["masking", "test"])
	var info: Dictionary = got.get("info", {})
	assert_eq(info.get("movie", ""), "masking")
	assert_eq(int(info.get("scenes", 0)), MASKING_SCENES.size())
	assert_eq(info.get("source", ""), "test")
	assert_eq((got["scenes"] as Array)[0], [0, "meet"], "scene 0 announced")
	assert_true(tree.get_first_node_in_group("explainer_player") == p, "in the group while playing")
	(got["solver"] as Callable).call()
	await wait_frames(3)
	Events.awaiting_input.disconnect(on_beat)
	Events.explainer_started.disconnect(on_start)
	Events.explainer_scene.disconnect(on_scene)
	Events.explainer_finished.disconnect(on_done)
	Events.input_resolved.disconnect(on_res)
	assert_false(bool(p.call("is_playing")), "the solver skips the movie")
	assert_eq(got["finished"], [["masking", true]])
	assert_true(bool(got.get("resolved", false)), "input_resolved(explainer)")
	assert_eq(result.get("skipped", false), true)
	assert_eq(result.get("movie", ""), "masking")
	assert_true(Game.is_movie_seen("masking"), "seen once it ends, skipped or not")
	assert_true(tree.get_first_node_in_group("explainer_player") == null, "out of the group after")


func test_player_keys_space_next_esc_skip() -> void:
	var p := _player()
	await wait_frames(1)
	p.call("play", "masking", "test")
	await wait_seconds(0.4)   # past the input grace
	assert_eq(int(p.get("scene_index")), 0)
	await tap_action(&"advance_dialogue")
	await wait_frames(2)
	assert_eq(int(p.get("scene_index")), 1, "Space / Enter: next scene")
	await tap_action(&"ui_accept")
	await wait_frames(2)
	assert_eq(int(p.get("scene_index")), 2, "ui_accept: next scene")
	await tap_action(&"ui_cancel")
	await wait_frames(3)
	assert_false(bool(p.call("is_playing")), "Esc skips the movie")
	assert_true(bool(p.get("skipped")))


func test_player_buttons_for_the_mouse() -> void:
	var p := _player()
	await wait_frames(1)
	p.call("play", "masking", "test")
	await wait_frames(2)
	var next_btn: Button = p.get("_next_btn")
	var skip_btn: Button = p.get("_skip_btn")
	assert_eq(next_btn.text, "Next scene")
	assert_eq(skip_btn.text, "Skip movie")
	assert_eq(next_btn.focus_mode, Control.FOCUS_NONE, "buttons never take focus")
	next_btn.pressed.emit()
	await wait_frames(2)
	assert_eq(int(p.get("scene_index")), 1, "Next scene button")
	skip_btn.pressed.emit()
	await wait_frames(3)
	assert_false(bool(p.call("is_playing")), "Skip movie button")


# ---------------------------------------------------------------- pause-menu replay

func test_pause_menu_movie_button() -> void:
	var menu: CanvasLayer = (load(PAUSE_MENU) as PackedScene).instantiate()
	add_node(menu)
	await wait_frames(1)
	var btns: Dictionary = menu.get("_movie_btns")
	assert_has(btns, "masking", "one Watch button per movie")
	var b: Button = btns["masking"]
	assert_eq(b.text, "Watch Hoot's masking movie")
	Game.current_chapter_id = "gus"
	menu.call("open")
	await wait_frames(1)
	assert_false(b.visible, "Day 1's pause menu does not change")
	menu.call("close")
	Game.current_chapter_id = "bonnie"
	menu.call("open")
	await wait_frames(1)
	assert_true(b.visible, "Day 2's pause menu offers the movie")
	var replay := func() -> void: await menu.call("play_movie", "masking")
	replay.call()
	await wait_frames(3)
	var p := tree.get_first_node_in_group("explainer_player")
	assert_true(p != null and bool(p.call("is_playing")), "the replay plays over the paused game")
	assert_true(tree.paused, "the game stays paused")
	assert_false((menu.get("_root") as Control).visible, "the menu hides while it plays")
	await tap_action(&"pause")
	assert_true(bool(menu.call("is_open")), "P does not close the menu mid-movie")
	p.call("skip_all")
	await wait_frames(4)
	assert_true((menu.get("_root") as Control).visible, "the menu comes back")
	assert_true(bool(menu.call("is_open")))
	menu.call("close")
	assert_false(tree.paused)


# ---------------------------------------------------------------- bone on the better ear first

func _beat_of(g: Control) -> Dictionary:
	var got := {}
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		got["beat"] = beat
		got["info"] = info
		got["solver"] = solver
	Events.awaiting_input.connect(cb)
	g.call("run")
	await wait_frames(1)
	Events.awaiting_input.disconnect(cb)
	return got


func test_bc_placement_left_then_right_quick() -> void:
	Game.begin_visit("bonnie")
	var BP: GDScript = load("res://story/games/bone_placement.gd")
	var g: Control = BP.new()
	g.call("setup", "left")
	add_node(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(2)
	var got := await _beat_of(g)
	assert_eq(got.get("beat", &""), &"bc_placement")
	var info: Dictionary = got["info"]
	assert_eq(info["targets"], ["mastoid_target_left"], "left mastoid first")
	assert_eq(info["ear"], "left")
	assert_false(bool(info["quick"]))
	assert_true(Hoot.has_anchor("mastoid_target_left"), "left anchor")
	(got["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(bool(g.get("placed")))
	g.queue_free()
	await wait_frames(2)
	assert_false(Hoot.has_anchor("mastoid_target_left"), "anchor unregistered")
	var g2: Control = BP.new()
	g2.call("setup", "right", true)
	g2.set("glasses_on", false)
	add_node(g2)
	g2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(2)
	var got2 := await _beat_of(g2)
	var info2: Dictionary = got2["info"]
	assert_eq(info2["targets"], ["mastoid_target_right"], "then the right one")
	assert_true(bool(info2["quick"]), "the second placement is quick")
	assert_true(String((g2.get("_caption") as Label).text).begins_with("Swap sides!"))
	assert_false(String(g2.call("_line", g2.call("_zone", "top"))).contains("glasses!"), "no glasses gag twice")
	(got2["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(bool(g2.get("placed")))


# ---------------------------------------------------------------- the rule and the Ghost demo

func _sheet(vals: Dictionary) -> Dictionary:
	var out := {}
	for f: int in vals:
		out[f] = {"stored_db": vals[f]}
	return out


func test_unmasked_bone_from_either_mastoid() -> void:
	var res := {"ears": {
		"right": {"freqs": _sheet({250: 50, 500: 55, 1000: 50, 2000: 50, 4000: 40}), "bc": {}},
		"left": {"freqs": _sheet({250: 5, 500: 5, 1000: 5, 2000: 0, 4000: 5}), "bc": _sheet({500: 5, 1000: 5, 2000: 0, 4000: 5})},
	}}
	assert_eq(ClinicRules.unmasked_bone(res, 1000), 5, "left bone answers for both")
	assert_eq(ClinicRules.unmasked_bone(res, 250), null, "nothing at 250")
	assert_eq(ClinicRules.masked_freqs_needed(res, "right", &"bc_masked"), [1000, 2000, 4000, 500] as Array[int],
		"right air vs unmasked (left) bone: mask everywhere")
	assert_true(ClinicRules.masked_freqs_needed(res, "left", &"bc_masked").is_empty(), "the left ear needs no masked bone")
	(res["ears"]["right"] as Dictionary)["bc"] = _sheet({1000: 0})
	assert_eq(ClinicRules.unmasked_bone(res, 1000), 0, "the lower of both")


func test_demo_tone_plan() -> void:
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	await wait_frames(2)
	Game.begin_visit("bonnie")
	var completed := []
	var reactions := []
	var on_done := func(e: String, _r: Dictionary) -> void: completed.append(e)
	var on_react := func(k: StringName, _d: Dictionary) -> void: reactions.append(k)
	Events.ear_completed.connect(on_done)
	Events.patient_reaction.connect(on_react)
	var finished := {}
	var on_fin := func(r: Dictionary) -> void: finished["r"] = r
	screen.connect("test_finished", on_fin)
	screen.call("start_test", Game.load_patient("bonnie"), "right", false,
		{"test": "bc", "bc_freqs": [1000], "masking_controls": false, "hoot_turn_after": 99,
		"demo_tone": {"freq": 1000, "db": 10, "title": "Bone 10, air 50? BOO!"}})
	var st: Dictionary = screen.call("get_state")
	assert_true(bool(st["demo"]), "state.demo")
	assert_eq(int(st["freq"]), 1000)
	assert_eq(int(st["db"]), 10)
	assert_eq(st["transducer"], &"bone")
	assert_false(bool(st["masking_controls"]), "no masking deck in the demo")
	await tap_action(&"louder")
	await tap_action(&"freq_up")
	st = screen.call("get_state")
	assert_eq(int(st["db"]), 10, "only TONE works in the demo")
	assert_eq(int(st["freq"]), 1000, "only TONE works in the demo")
	for i in 3:
		if finished.has("r") or not bool((screen.call("get_state") as Dictionary).get("demo", false)):
			break
		send_action(&"present_tone", true)
		await wait_seconds(1.4)
		send_action(&"present_tone", false)
		await wait_seconds(2.0)
	var t0 := Time.get_ticks_msec()
	while not finished.has("r") and Time.get_ticks_msec() - t0 < 6000:
		await wait_frames(2)
	Events.ear_completed.disconnect(on_done)
	Events.patient_reaction.disconnect(on_react)
	assert_true(finished.has("r"), "the demo ends by itself")
	var res: Dictionary = finished.get("r", {})
	assert_true(ClinicRules.sheet_thresholds(res, "right", &"bc").is_empty(), "the demo stores nothing")
	assert_true(completed.is_empty(), "no ear_completed for the demo")
	assert_has(reactions, &"cross_heard", "her LEFT cochlea answered: the Ghost")
	assert_false(bool((screen.call("get_state") as Dictionary).get("demo", true)), "demo over")
	var session: Object = screen.get("session")
	assert_true((session.call("measurement", "right", 1000) as Array).is_empty(), "the demo's tone opens no bone search")


# ---------------------------------------------------------------- Day 2 flow and results

## The v4 phase order lives in level_bonnie._run (docs/CHAPTER2.md §3, CONTRACTS.md §3.1).
func test_day2_flow_order() -> void:
	var src := (load("res://story/level_bonnie.gd") as GDScript).source_code
	var run_at := src.find("func _run() -> void:")
	assert_true(run_at >= 0)
	var body := src.substr(run_at, 600)
	var last := -1
	for call: String in ["_movie()", "_intro()", "_air()", "_bone_placement()", "_bone()", "_ghost_demo()", "_masking()", "_reveal()", "_results()"]:
		var at := body.find("await " + call)
		assert_true(at > last, "%s in order" % call)
		last = at
	assert_true(src.contains("g.setup(\"left\")"), "the first placement is the left mastoid")
	assert_true(src.contains("g.setup(\"right\", true)"), "then the right one, quick")
	assert_true(src.contains("\"demo_tone\""), "the Ghost demo plan")


func test_results_show_left_bone() -> void:
	var dd: GDScript = load("res://story/daily_decibel.gd")
	var rows: Array = dd.get_script_constant_map()["GOLF_EXTRA_ROWS"]
	assert_eq(rows[0], ["bc", "L  >", "left"], "golf card: left bone '>' row")
	assert_has(rows, ["bc_masked", "R  [", "right"])
