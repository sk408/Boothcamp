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
	assert_eq(result.get("watched", true), false, "skipped in scene 1: not watched")
	assert_false(Game.is_movie_seen("masking"), "(polish) an early skip is not 'seen': it plays again next visit")
	assert_true(tree.get_first_node_in_group("explainer_player") == null, "out of the group after")


## (polish) Space / Enter advance like the dialogue box: finish the caption, else the scene's next
## caption (never thrown away), else the next scene. Esc skips it all.
func test_player_keys_space_next_esc_skip() -> void:
	var p := _player()
	await wait_frames(1)
	p.call("play", "masking", "test")
	await wait_seconds(0.5)   # past the input grace; scene 1's first caption is typing
	assert_eq(int(p.get("scene_index")), 0)
	var cap: Label = p.get("_caption")
	assert_true(cap.visible_characters >= 0 and cap.visible_characters < cap.text.length(), "the caption is still typing")
	await tap_action(&"advance_dialogue")
	assert_eq(int(p.get("scene_index")), 0, "the first Space finishes the caption")
	assert_eq(cap.visible_characters, -1, "the whole caption shows")
	await tap_action(&"ui_accept")
	assert_eq(int(p.get("scene_index")), 0, "(Steve) scene 1 opens with what the movie is about: three captions")
	assert_eq(int(p.get("_cap_i")), 1, "then Enter: the scene's next caption")
	for i in 8:
		if int(p.get("scene_index")) >= 1:
			break
		await tap_action(&"advance_dialogue")
	assert_eq(int(p.get("scene_index")), 1, "after its last caption: the next scene")
	p.call("skip_scene")
	await wait_frames(3)
	assert_eq(int(p.get("scene_index")), 2, "the wall scene: two captions")
	var wall_caps: Array = (Movies.movie("masking")["scenes"] as Array)[2]["captions"]
	for i in 4:
		if int(p.get("_cap_i")) >= 1:
			break
		await tap_action(&"advance_dialogue")
	assert_eq(int(p.get("scene_index")), 2, "Space never skips the second caption")
	assert_eq(int(p.get("_cap_i")), 1, "it jumps to the second caption")
	assert_eq(cap.text, String(wall_caps[1]))
	assert_true(float(p.get("_scene_t")) >= 5.5, "the drawing jumps with the caption")
	await tap_action(&"advance_dialogue")
	if cap.visible_characters != -1:
		await tap_action(&"advance_dialogue")
	await tap_action(&"advance_dialogue")
	assert_eq(int(p.get("scene_index")), 3, "after the last caption: the next scene")
	await tap_action(&"ui_cancel")
	await wait_frames(3)
	assert_false(bool(p.call("is_playing")), "Esc skips the movie")
	assert_true(bool(p.get("skipped")))


## (polish) Seen = reached the movie's "seen_at" scene (masking: the plateau); the last scene's
## button says "Start the day" (day start) or "Done" (replays).
func test_player_seen_at_and_last_button() -> void:
	Game.progress["movies_seen"] = []
	var p := _player()
	await wait_frames(1)
	var next_btn: Button = p.get("_next_btn")
	var n := MASKING_SCENES.size()
	var plateau := MASKING_SCENES.find("plateau")
	assert_eq(String(Movies.movie("masking").get("seen_at", "")), "plateau")
	var result := {}
	var run := func(src: String) -> void:
		result.clear()
		result.merge(await p.call("play", "masking", src))
	p.set("start_scene", plateau - 1)
	run.call("day_start")
	await wait_frames(2)
	assert_eq(next_btn.text, "Next")
	p.call("skip_all")
	await wait_frames(3)
	assert_eq(result.get("watched", true), false, "Esc before the plateau scene")
	assert_false(Game.is_movie_seen("masking"), "not seen: it plays again next visit")
	p.set("start_scene", plateau)
	run.call("day_start")
	await wait_frames(2)
	p.call("skip_all")
	await wait_frames(3)
	assert_eq(result.get("watched", false), true, "Esc in the plateau scene still counts")
	assert_true(Game.is_movie_seen("masking"), "seen")
	p.set("start_scene", n - 1)
	run.call("day_start")
	await wait_frames(2)
	assert_eq(next_btn.text, "Start the day", "the day-start movie's last button")
	for i in 5:
		if not bool(p.call("is_playing")):
			break
		next_btn.pressed.emit()   # the caption, its typing, then the end
		await wait_frames(2)
	await wait_frames(2)
	assert_false(bool(p.call("is_playing")), "the last Next ends the movie")
	assert_eq(result.get("skipped", true), false, "played to the end")
	p.set("start_scene", n - 1)
	run.call("pause")
	await wait_frames(2)
	assert_eq(next_btn.text, "Done", "a replay's last button")
	p.call("skip_all")
	await wait_frames(3)


func test_player_buttons_for_the_mouse() -> void:
	var p := _player()
	await wait_frames(1)
	p.call("play", "masking", "test")
	await wait_frames(2)
	var next_btn: Button = p.get("_next_btn")
	var skip_btn: Button = p.get("_skip_btn")
	var pause_btn: Button = p.get("_pause_btn")
	assert_eq(next_btn.text, "Next")
	assert_eq(skip_btn.text, "Skip movie")
	assert_eq(next_btn.focus_mode, Control.FOCUS_NONE, "buttons never take focus")
	assert_eq(pause_btn.focus_mode, Control.FOCUS_NONE, "buttons never take focus")
	assert_true(pause_btn.visible, "(polish) a pause button for the mouse")
	for i in 8:
		if int(p.get("scene_index")) >= 1:
			break
		next_btn.pressed.emit()
		await wait_frames(2)
	assert_eq(int(p.get("scene_index")), 1, "Next button (advances like Space)")
	skip_btn.pressed.emit()
	await wait_frames(3)
	assert_false(bool(p.call("is_playing")), "Skip movie button")


# ---------------------------------------------------------------- pause-menu replay

func test_pause_menu_movie_button() -> void:
	var menu: CanvasLayer = (load(PAUSE_MENU) as PackedScene).instantiate()
	add_node(menu)
	await wait_frames(1)
	Game.current_chapter_id = "gus"
	menu.call("open")
	await wait_frames(1)
	assert_true(menu.call("movie_button") == null, "Day 1's pause menu does not change")
	menu.call("close")
	Game.current_chapter_id = "bonnie"
	menu.call("open")
	await wait_frames(1)
	var b: Button = menu.call("movie_button")
	assert_true(b != null and b.visible, "Day 2's pause menu offers the movie")
	assert_eq(b.text, "Watch Hoot's masking movie", "one movie here: its own Watch button")
	assert_false(menu.call("movie_ids_here").has("masking_recap"), "never the recap")
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
	assert_eq(rows[0], ["bc", "left"], "golf card: left bone '>' row")
	assert_has(rows, ["bc_masked", "right"])
	assert_has(rows, ["bc", "right"])   # (cases) a better right ear's unmasked bone


# ---------------------------------------------------------------- (v4, builders) merged at integration

## The wall scene's meter (docs/CHAPTER2.md §16): the soft beeps lose everything at the wall
## ("fizzle!"), only the loud one arrives on the other side, 40 dB smaller.
func test_masking_movie_wall_levels() -> void:
	var wall: Dictionary = {}
	for sc: Dictionary in Movies.movie("masking")["scenes"]:
		if String(sc["id"]) == "wall":
			wall = sc["params"]
	var levels: Array = wall["levels"]
	var ia := int(wall["ia"])
	var lefty := int(wall["lefty_hears"])
	assert_true(levels.size() >= 2)
	for i in levels.size() - 1:
		assert_true(int(levels[i]) - ia < lefty, "%d - %d is below Lefty's %d: fizzle" % [levels[i], ia, lefty])
	assert_true(int(levels[-1]) - ia >= lefty, "the loud beep crosses and Lefty hears it")
	for i in range(1, levels.size()):
		assert_true(int(levels[i]) > int(levels[i - 1]), "the meter climbs")


## The generic data-only "card" set, its limits, and the fallback for a set the stage does not know.
func test_stage_card_set_and_fallback() -> void:
	assert_has(Stage2D.SETS, &"card", "the generic card set")
	var icons: Array = Stage2D.CARD_ICONS
	for ic: String in ["", "snails", "ghost", "cloud", "note", "dial", "hoot"]:
		assert_has(icons, ic, "card icon")
	assert_eq(Movies.CARD_MAX_LINES, 4)
	assert_eq(Movies.CARD_MAX_CHARS, 36)
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	for sc: Dictionary in [
		{"id": "c", "set": "card", "title": "A card", "duration": 4.0,
			"params": {"heading": "Hello", "lines": ["One", "Two"], "icon": "ghost", "tint": "#e9f4ff"}},
		{"id": "x", "set": "no_such_set", "title": "Fallback", "duration": 4.0}]:
		st.call("show_scene", sc)
		for tt: float in [0.0, 1.0, 3.5]:
			st.set("t", tt)
			st.queue_redraw()
			await wait_frames(1)
		assert_eq(String(st.get("scene_title")), String(sc["title"]), "the scene title chip")


## The title's "Hoot's Movies" button: a mouse shortcut, menu state only, plays the one movie from
## the title (source "title") through the pause menu and lands back on the title.
func test_title_movies_button() -> void:
	Game.progress["movies_seen"] = []
	var beats := {}
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void: beats[beat] = [info, solver]
	Events.awaiting_input.connect(cb)
	var sources: Array = []
	var cs := func(_id: String, src: String) -> void: sources.append(src)
	Events.explainer_started.connect(cs)
	var menu: CanvasLayer = (load(PAUSE_MENU) as PackedScene).instantiate()
	add_node(menu)
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	if beats.has(&"disclaimer_ok"):
		(beats[&"disclaimer_ok"][1] as Callable).call()
		await wait_seconds(0.5)
	var b := title.find_child("MoviesButton", true, false) as Button
	assert_true(b != null, "the title has a Hoot's Movies button")
	assert_eq(b.focus_mode, Control.FOCUS_NONE, "never takes keyboard focus")
	await wait_frames(1)
	assert_true(b.visible, "shown in the menu state")
	b.pressed.emit()
	await wait_frames(3)
	var p := tree.get_first_node_in_group("explainer_player")
	assert_true(p != null and bool(p.call("is_playing")), "the movie plays from the title")
	assert_eq(sources, ["title"], "source title")
	assert_true(tree.paused, "the title waits paused")
	p.call("skip_all")
	await wait_frames(6)
	assert_false(bool(menu.call("is_open")), "back on the title, the menu closed")
	assert_false(tree.paused)
	assert_eq(title.get("_state"), &"menu")
	Events.awaiting_input.disconnect(cb)
	Events.explainer_started.disconnect(cs)


# ---------------------------------------------------------------- (polish) review fixes

## The music duck is reference-counted by owner: a movie replayed over the AudiOtron leaves the
## booth quiet, and a movie freed mid-play (P, then Quit to title) gives its duck back.
func test_music_duck_owners() -> void:
	var before: Array = Sfx.music_duck_owners()
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	await wait_frames(2)
	assert_true(Sfx.is_music_ducked(), "the AudiOtron ducks the music")
	var p := _player()
	await wait_frames(1)
	p.call("play", "masking", "pause")
	await wait_frames(2)
	assert_eq(Sfx.music_duck_owners().size(), before.size() + 2, "two owners now")
	p.call("skip_all")
	await wait_frames(3)
	assert_true(Sfx.is_music_ducked(), "the movie ended over the AudiOtron: still ducked")
	screen.queue_free()
	await wait_frames(2)
	assert_eq(Sfx.music_duck_owners(), before, "the AudiOtron gave its duck back")
	var p2 := _player()
	await wait_frames(1)
	p2.call("play", "masking", "day_start")
	await wait_frames(2)
	assert_true(Sfx.is_music_ducked(), "the movie ducks the music")
	p2.queue_free()
	await wait_frames(2)
	assert_eq(Sfx.music_duck_owners(), before, "freed mid-play: its duck is undone")
	assert_true(tree.get_first_node_in_group("explainer_player") == null, "and it left the group")
	Sfx.music_duck(true, "test")
	Sfx.music_duck(true, "test")
	Sfx.music_duck(false, "test")
	assert_eq(Sfx.music_duck_owners(), before, "one key = one owner, however often it ducks")


## Plan "masking_deck": false keeps the AIR | BONE route but no MASKING group (unmasked bone).
func test_masking_deck_off_keeps_the_route() -> void:
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	await wait_frames(2)
	Game.begin_visit("bonnie")
	screen.call("start_test", Game.load_patient("bonnie"), "left", false,
		{"test": "bc", "bc_freqs": [1000], "masking_controls": true, "masking_deck": false, "hoot_turn_after": 99})
	await wait_frames(2)
	var st: Dictionary = screen.call("get_state")
	assert_true(bool(st["masking_controls"]), "the route buttons stay")
	assert_false(bool(st["masking_deck"]), "no masking deck")
	var btns: Dictionary = screen.get("_buttons")
	for id: String in ["mask_softer_button", "mask_toggle_button", "mask_louder_button"]:
		assert_false((btns[id] as Control).visible, "%s hidden" % id)
	for id: String in ["transducer_air_button", "transducer_bone_button"]:
		assert_true((btns[id] as Control).visible, "%s shown" % id)
	var db0 := int(st["mask_db"])
	await tap_action(&"toggle_mask")
	await tap_action(&"mask_louder")
	st = screen.call("get_state")
	assert_false(bool(st["mask_on"]), "M does nothing without the deck")
	assert_eq(int(st["mask_db"]), db0, "PgUp does nothing without the deck")
	screen.call("start_test", Game.load_patient("bonnie"), "right", false,
		{"test": "bc_masked", "bc_freqs": [1000], "masking_controls": true, "hoot_turn_after": 99})
	await wait_frames(2)
	assert_true(bool((screen.call("get_state") as Dictionary)["masking_deck"]), "masked bone: the deck is back (default)")
	assert_true((btns["mask_toggle_button"] as Control).visible)
	var src := (load("res://story/level_bonnie.gd") as GDScript).source_code
	assert_eq(src.count("\"masking_deck\": false"), 2, "the left bone and the bonus hole")


## The "Hoot's Movies" list grows with the game: five made-up movies on one day, a vertical list
## that fits a 720p window, keys pick a row and it scrolls, Enter plays it, the list comes back.
func test_movie_list_layout_many_movies() -> void:
	var base := Movies.movie("masking")
	for i in 5:
		var m := base.duplicate(true)
		m["id"] = "fake_list_%d" % i
		m["title"] = "Hoot's fake movie number %d with a long title" % (i + 1)
		m["subtitle"] = "Subtitle %d" % i
		m.erase("seen_at")
		Movies.extra[String(m["id"])] = m
	var menu: CanvasLayer = (load(PAUSE_MENU) as PackedScene).instantiate()
	add_node(menu)
	await wait_frames(1)
	Game.current_chapter_id = "bonnie"
	menu.call("open")
	await wait_frames(2)
	var b: Button = menu.call("movie_button")
	assert_true(b != null and b.text.begins_with("Hoot's Movies"), "six movies here: one list button")
	var card: Control = menu.get("_card")
	var vp := tree.root.get_visible_rect().grow(1.0)
	assert_true(vp.encloses(card.get_global_rect()), "the menu card still fits: %s" % card.get_global_rect())
	b.pressed.emit()
	await wait_frames(3)
	assert_true(bool(menu.call("is_movie_list_open")))
	var rows: Array = menu.call("movie_list_rows")
	assert_eq(rows.size(), 6, "masking + five")
	var list_card: Control = menu.get("_list_card")
	assert_true(vp.encloses(list_card.get_global_rect()), "the list fits a 720p window: %s" % list_card.get_global_rect())
	var x0 := (rows[0]["row"] as Control).get_global_rect().position.x
	for r: Dictionary in rows:
		var rc := (r["row"] as Control).get_global_rect()
		assert_near(rc.position.x, x0, 0.5, "one column")
		assert_true(rc.size.y >= 60.0 and rc.size.x <= list_card.size.x, "a full row")
	var y1 := (rows[1]["row"] as Control).get_global_rect().position.y
	assert_true(y1 > (rows[0]["row"] as Control).get_global_rect().position.y, "rows go DOWN, not across")
	var scroll: ScrollContainer = menu.get("_list_scroll")
	await wait_seconds(0.3)
	for i in 5:
		var ev := InputEventKey.new()
		ev.keycode = KEY_DOWN
		ev.physical_keycode = KEY_DOWN
		ev.pressed = true
		Input.parse_input_event(ev)
		await wait_frames(1)
		ev = ev.duplicate() as InputEventKey
		ev.pressed = false
		Input.parse_input_event(ev)
		await wait_frames(1)
	await wait_frames(3)
	assert_eq(int(menu.get("_list_hl")), 5, "Down picks the rows")
	assert_true(scroll.scroll_vertical > 0, "the list scrolls to the picked row")
	var started := []
	var cs := func(id: String, _src: String) -> void: started.append(id)
	Events.explainer_started.connect(cs)
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	Input.parse_input_event(enter)
	await wait_frames(1)
	var enter_up := enter.duplicate() as InputEventKey
	enter_up.pressed = false
	Input.parse_input_event(enter_up)
	await wait_frames(3)
	Events.explainer_started.disconnect(cs)
	assert_eq(started, ["fake_list_4"], "Enter plays the picked movie")
	var p := tree.get_first_node_in_group("explainer_player")
	if p != null:
		p.call("skip_all")
	await wait_frames(4)
	assert_true(bool(menu.call("is_movie_list_open")), "the list comes back after the movie")
	menu.call("close_movie_list")
	assert_false(bool(menu.call("is_movie_list_open")))
	assert_true(bool(menu.call("is_open")), "Back: the menu")
	menu.call("close")
	Movies.extra.clear()


## The integrator's hook (CONTRACTS.md §3.4): MOVIE.stage names the movie's own sets script
## (extending story/explainers/explainer_sets.gd); the stage draws those sets with the same inputs,
## and validate() accepts them.
func test_movie_sets_hook() -> void:
	Movies.extra["fake_hook"] = "res://tests/fixtures/fake_movie.gd"
	var Fake: GDScript = load("res://tests/fixtures/fake_movie_sets.gd")
	assert_eq(Movies.own_sets("fake_hook"), [&"fake_word", &"fake_snail"] as Array[StringName], "the script's SETS")
	var bad := Movies.validate("fake_hook", Stage2D.SETS)
	assert_true(bad.is_empty(), "validate accepts its own sets: %s" % ", ".join(bad))
	var broken := Movies.movie("fake_hook")
	(broken["scenes"] as Array)[0]["set"] = "no_such_set"
	Movies.extra["fake_broken"] = broken
	broken["id"] = "fake_broken"
	assert_false(Movies.validate("fake_broken", Stage2D.SETS).is_empty(), "an unknown set is still caught")
	broken["stage"] = "res://tests/fixtures/nope_sets.gd"
	assert_false(Movies.validate("fake_broken", Stage2D.SETS).is_empty(), "a missing sets script is caught")
	assert_false(Movies.for_chapter("bonnie").has("fake_hook"), "a short is not listed for replay")
	# the stage delegates to it
	Fake.set("drawn", [])
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", Movies.movie("fake_hook"))
	assert_eq(st.call("movie_set_ids"), [&"fake_word", &"fake_snail"] as Array[StringName])
	var scenes: Array = Movies.movie("fake_hook")["scenes"]
	st.call("show_scene", scenes[0])
	st.set("t", 1.5)
	st.queue_redraw()
	await wait_frames(2)
	var drawn: Array = Fake.get("drawn")
	assert_true(not drawn.is_empty(), "the stage drew the movie's own set")
	if not drawn.is_empty():
		var last: Array = drawn[-1]
		assert_eq(String(last[0]), "fake_word")
		assert_near(float(last[1]), 1.5, 0.001, "same t")
		assert_near(float(last[2]), 4.0, 0.001, "same duration")
		assert_eq(String(last[3]), "HOOK!", "same params")
	st.call("show_scene", scenes[1])
	st.set("t", 2.0)
	st.queue_redraw()
	await wait_frames(2)
	drawn = Fake.get("drawn")
	assert_eq(String((drawn[-1] as Array)[0]), "fake_snail", "the second set, with the stage's own helpers")
	# the player plays it end to end through the hook
	var p := _player()
	await wait_frames(1)
	var r := {}
	var run := func() -> void: r.merge(await p.call("play", "fake_hook", "test"))
	run.call()
	for i in 12:
		if not bool(p.call("is_playing")):
			break
		p.call("skip_scene")
		await wait_frames(2)
	await wait_frames(2)
	assert_eq(int(r.get("scenes_seen", 0)), 3, "all three scenes played")
	# without the movie's script, its sets fall back to a card (never a blank screen)
	st.call("use_movie", {})
	st.call("show_scene", scenes[0])
	var n_before := (Fake.get("drawn") as Array).size()
	st.queue_redraw()
	await wait_frames(2)
	assert_eq((Fake.get("drawn") as Array).size(), n_before, "no sets script: the card fallback")
	Movies.extra.clear()


## The masking recap: a "short" card that the masking phase plays, never in a replay list.
func test_masking_recap_short() -> void:
	assert_true(Movies.has("masking_recap"))
	assert_true(Movies.is_short("masking_recap"))
	var bad := Movies.validate("masking_recap", Stage2D.SETS)
	assert_true(bad.is_empty(), "validate: %s" % ", ".join(bad))
	assert_between(Movies.total_s("masking_recap"), 10.0, 15.0, "10-15 s")
	assert_false(Movies.replay_ids().has("masking_recap"), "not on the title's list")
	assert_eq(Movies.for_chapter("bonnie"), ["masking"] as Array[String], "not in Day 2's replay")
	var src := (load("res://story/level_bonnie.gd") as GDScript).source_code
	var at_mask := src.find("func _masking() -> void:")
	assert_true(src.find("await _recap()", at_mask) > at_mask, "the masking phase plays it")
	assert_true(src.contains("Rewatch it any time"), "a day-start skip says where the movie lives")
