extends Node
## Monkey: a sloppy, button-mashing trainee for the AudiOtron (stress test, not a player).
## Boot:  godot --headless --path . --fixed-fps 30 -- --scene=res://tools/monkey.tscn --speed=3 --seed=N
## Tests the coached right ear, then the solo left ear (quick visit: Hoot's x8 turn), while it
## half-follows the textbook and half mashes random keys, clicks, right-clicks, pause-menu keys,
## too-short and too-long beeps. Checks every frame:
##   - no script errors;  - no tone left playing without a held key or mouse;
##   - Engine.time_scale only x8 during Hoot's turn and back to normal after it.
## (v3) --day=2: Bonnie's Day 2 tests instead (air both ears with Hoot's turns, then bone, masked
## bone and masked air), mashing the MASKING / ROUTE controls too (M, PgUp / PgDn, Shift+Up / Down,
## A, B). Extra invariants: the noise dial stays in 0..100 dB EM, the masker only plays while
## MASK is on, and no masker is left playing after a test.
## (v4) --day=2 first mashes Hoot's masking movie three ways (story/explainers/, CONTRACTS.md §3.4):
## (1) as a level plays it (a pausable parent) with Space / Enter / clicks / Next scene / P but no
## Esc: it must step one scene at a time to the end, not skipped, and P must freeze it; (2) the same
## plus Esc and "Skip movie": an accepted Esc ends it at once; (3) the pause menu's "Watch Hoot's
## masking movie" replay (a real click) with the same keys: the menu comes back. Invariants: the
## scenes go 0, 1, 2, ... one at a time, every movie ends within MOVIE_MAX_S, nothing is left paused
## or in the explainer_player group.
## Prints MONKEY_RESULT {json}; exit 0 ok, 1 an invariant broke, 3 timeout.

const ErrorCounter := preload("res://tools/autoplay_bot.gd").ScriptErrorCounter
const Movies := preload("res://story/explainers/movies.gd")
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const MAX_GAME_S := 1500.0
const ACTIONS: Array[StringName] = [&"present_tone", &"louder", &"softer", &"freq_up", &"freq_down", &"store",
	&"no_response", &"ear_right", &"ear_left", &"toggle_key_hints", &"advance_dialogue", &"ui_accept"]
## (v3) Day 2's extra controls.
const ACTIONS_V3: Array[StringName] = [&"toggle_mask", &"mask_louder", &"mask_softer", &"transducer_air", &"transducer_bone"]
const MAX_GAME_S_DAY2 := 3600.0
## (v3) Bonnie's tests in story order: [ear, coached, plan].
## (v4) bone on the better (left) ear first, then the one-tone Ghost demo on the right (plan
## demo_tone: only TONE works, nothing is stored), then masked right bone and air.
const DAY2_TESTS := [
	["right", true, {"test": "ac", "hoot_turn_after": 1}],
	["left", false, {"test": "ac", "hoot_turn_after": 0}],
	["left", true, {"test": "bc", "masking_controls": true, "hoot_turn_after": 1}],
	["right", false, {"test": "bc", "bc_freqs": [1000], "masking_controls": false, "hoot_turn_after": 99, "demo_tone": {"freq": 1000, "db": 10, "title": "BOO!"}}],
	["right", true, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 2}],
	["right", false, {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 0}],
]

var _screen: Node
var _errors := ErrorCounter.new()
var _rng := RandomNumberGenerator.new()
var _held_key := false
var _held_mouse := false
var _release_at := -1.0
var _next_t := 0.0
var _t := 0.0
var _base_scale := 1.0
var _problems: PackedStringArray = []
var _stats := {"inputs": 0, "clicks": 0, "pauses": 0, "short_beeps": 0, "long_beeps": 0, "hoot_turn_frames": 0, "stores": 0}
var _day2 := false
var _actions: Array[StringName] = ACTIONS.duplicate()
var _masker_on := false
var _tone_unheld_s := 0.0
var _tone_flagged := false
var _done := false
## (v4) Hoot's movie mashing: -1 = off; 0 = level, no Esc; 1 = level, anything; 2 = pause-menu replay.
const MOVIE_PLAYER := "res://story/explainers/explainer_player.tscn"
const MOVIE_ID := "masking"
const MOVIE_MAX_S := 300.0
var _movie_style := -1
var _in_movies := false
var _movie_player: CanvasLayer
var _movie_t0 := 0.0
var _movie_scene := -1
var _movie_esc_t := -1.0
var _movie_paused_t := -1.0
var _movie_frozen_at := -1.0
var _movie_runs: Array = []


func demo_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps mashing inside the pause menu too
	OS.add_logger(_errors)
	_rng.seed = int(Game.cli.get("seed", 1))
	_base_scale = Engine.time_scale
	_screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate()
	add_child(_screen)
	Events.threshold_stored.connect(func(_e: String, _f: int, _d: int, _i: Dictionary) -> void: _stats["stores"] = int(_stats["stores"]) + 1)
	Events.masker_changed.connect(func(_e: String, _f: int, _d: int, on: bool) -> void: _masker_on = on)
	_day2 = Game.cli_chapter_id() == "bonnie"
	if _day2:
		_actions.append_array(ACTIONS_V3)
		await _run_day2()
	else:
		_screen.call("demo_start")
		await _screen.test_finished
		_release_all()
		_screen.call("start_test", Game.load_patient("gus"), "left", false)
		await _screen.test_finished
		_release_all()
	await get_tree().process_frame
	if _masker_on:
		_problem("masker still playing after the visit")
	if not is_equal_approx(Engine.time_scale, _base_scale):
		_problem("time_scale stuck at %.2f after the visit" % Engine.time_scale)
	_finish(0 if _problems.is_empty() and _errors.count == 0 else 1)


## (v3) Day 2: Bonnie's tests in order on one session (CONTRACTS.md §4.2 plans).
func _run_day2() -> void:
	Game.begin_visit("bonnie")
	Events.explainer_scene.connect(_on_movie_scene)
	_in_movies = true   # no AudiOtron mashing in between the movie runs
	for style in 3:
		await _run_movie(style)
		if _done:
			return
	_in_movies = false
	var bonnie := Game.load_patient("bonnie")
	for t: Array in DAY2_TESTS:
		_screen.call("start_test", bonnie, String(t[0]), bool(t[1]), (t[2] as Dictionary).duplicate())
		await _screen.test_finished
		_release_all()
		_stats["tests"] = int(_stats.get("tests", 0)) + 1
		if _masker_on:
			_problem("masker still playing after the %s test" % String((t[2] as Dictionary)["test"]))


func _process(delta: float) -> void:
	if _done or _screen == null or not is_instance_valid(_screen):
		return
	_t += get_process_delta_time() if not get_tree().paused else delta
	if Game.clock > (MAX_GAME_S_DAY2 if _day2 else MAX_GAME_S):
		_problem("timeout")
		_finish(3)
		return
	if _in_movies:
		if _movie_style >= 0:
			_movie_tick()
		return
	var st: Dictionary = _screen.call("get_state")
	var hoot := bool(st.get("hoot_turn", false))
	# invariants
	if hoot:
		_stats["hoot_turn_frames"] = int(_stats["hoot_turn_frames"]) + 1
	elif not get_tree().paused and not is_equal_approx(Engine.time_scale, _base_scale):
		_problem("time_scale %.2f outside Hoot's turn" % Engine.time_scale)
	if bool(st.get("tone_on", false)) and not hoot and not _held_key and not _held_mouse and not get_tree().paused:
		_tone_unheld_s += delta
		if _tone_unheld_s > 0.6 and not _tone_flagged:
			_tone_flagged = true
			_problem("tone on with nothing held (%.1f s)" % _tone_unheld_s)
	else:
		_tone_unheld_s = 0.0
	if _day2:
		var m := int(st.get("mask_db", 0))
		if m < ClinicRules.MASK_MIN_DB or m > ClinicRules.MASK_MAX_DB:
			_problem("noise dial at %d dB EM" % m)
		if _masker_on and not bool(st.get("mask_on", false)):
			_problem("masker playing with MASK off")
	# releases
	if _release_at >= 0.0 and _t >= _release_at:
		_release_all()
	if _t < _next_t or _release_at >= 0.0:
		return
	_next_t = _t + _rng.randf_range(0.05, 0.6)
	_act(st)


func _act(st: Dictionary) -> void:
	_stats["inputs"] = int(_stats["inputs"]) + 1
	var roll := _rng.randf()
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm != null and bool(pm.call("is_open")):
		# mash menu keys, then close it
		var keys: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ESCAPE]
		_key(keys[_rng.randi() % keys.size()])
		return
	if roll < 0.55:
		_follow(st)
	elif roll < 0.8:
		var a: StringName = _actions[_rng.randi() % _actions.size()]
		if a == &"present_tone":
			_beep(_rng.randf_range(0.05, 3.5))
		else:
			_tap(a)
	elif roll < 0.92:
		_click(Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720)), _rng.randf() < 0.2)
	elif roll < 0.95:
		_stats["pauses"] = int(_stats["pauses"]) + 1
		_tap(&"pause")
	# else: idle


## (v4) One run of Hoot's masking movie under the monkey's fingers (see the header).
func _run_movie(style: int) -> void:
	_movie_scene = -1
	_movie_esc_t = -1.0
	_movie_paused_t = -1.0
	_movie_frozen_at = -1.0
	_movie_t0 = _t
	_next_t = _t + 0.1
	var holder: Node = null
	var r: Dictionary = {}
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if style < 2:
		# as a level plays it: a pausable parent, so P (the pause menu) freezes the movie
		holder = Node.new()
		holder.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(holder)
		_movie_player = (load(MOVIE_PLAYER) as PackedScene).instantiate()
		holder.add_child(_movie_player)
		_movie_style = style
		r = await _movie_player.call("play", MOVIE_ID, "test")
	else:
		if pm == null:
			_problem("no pause menu for the movie replay")
			return
		pm.call("open")
		await get_tree().create_timer(0.4, true, false, true).timeout
		var btn: Button = (pm.get("_movie_btns") as Dictionary).get(MOVIE_ID)
		if btn == null or not btn.is_visible_in_tree():
			_problem("pause menu: no visible 'Watch' button on Day 2")
			pm.call("close")
			return
		_movie_style = style
		var done := [false, true]   # [finished, skipped] (a lambda cannot assign the outer r)
		var cb := func(_id: String, sk: bool) -> void:
			done[0] = true
			done[1] = sk
		Events.explainer_finished.connect(cb)
		_click(btn.get_global_rect().get_center(), false)
		await get_tree().process_frame
		_movie_player = get_tree().get_first_node_in_group("explainer_player")
		if _movie_player == null:
			_problem("the Watch button did not start the replay")
		while not done[0] and not _done and _t - _movie_t0 < MOVIE_MAX_S:
			await get_tree().process_frame
		Events.explainer_finished.disconnect(cb)
		r = {"skipped": bool(done[1]), "scenes_seen": _movie_scene + 1}
		await get_tree().create_timer(0.2, true, false, true).timeout
		if not bool(pm.call("is_open")):
			_problem("the pause menu did not come back after the replay")
	_movie_style = -1
	_release_all()
	if pm != null and bool(pm.call("is_open")):
		pm.call("close")
	await get_tree().process_frame
	_movie_runs.append({"style": style, "skipped": bool(r.get("skipped", true)), "scenes": int(r.get("scenes_seen", 0)), "s": snappedf(_t - _movie_t0, 0.1)})
	if style == 0 and (bool(r.get("skipped", true)) or int(r.get("scenes_seen", 0)) != (Movies.movie(MOVIE_ID)["scenes"] as Array).size()):
		_problem("movie without Esc did not play to the end: %s" % JSON.stringify(r))
	if get_tree().get_first_node_in_group("explainer_player") != null:
		_problem("an explainer player is still playing after the movie (style %d)" % style)
	if get_tree().paused:
		_problem("the game is still paused after the movie (style %d)" % style)
	if holder != null:
		holder.queue_free()
	_movie_player = null


func _on_movie_scene(_id: String, index: int, _scene: String) -> void:
	if _movie_style < 0:
		return
	if index != _movie_scene + 1:
		_problem("movie jumped from scene %d to %d" % [_movie_scene, index])
	_movie_scene = index


## (v4) The movie's invariants and the next mash.
func _movie_tick() -> void:
	if _t - _movie_t0 > MOVIE_MAX_S:
		_problem("movie still playing after %.0f s (style %d)" % [MOVIE_MAX_S, _movie_style])
		_finish(3)
		return
	var p := _movie_player
	var playing := p != null and is_instance_valid(p) and bool(p.call("is_playing"))
	var pm := get_tree().get_first_node_in_group("pause_menu")
	var menu_up := pm != null and bool(pm.call("is_open")) and _movie_style != 2
	if _movie_esc_t >= 0.0 and playing and _t - _movie_esc_t > 1.0:
		_problem("Esc did not skip the movie (style %d)" % _movie_style)
		_movie_esc_t = -1.0
	if menu_up and playing:
		# P froze the level's movie: its clock must not move while the menu is open
		var st := float(p.get("_scene_t"))
		_stats["movie_menu_frames"] = int(_stats.get("movie_menu_frames", 0)) + 1
		if _movie_paused_t < 0.0:
			_movie_paused_t = _t
			_movie_frozen_at = st
		elif _t - _movie_paused_t > 0.3 and absf(st - _movie_frozen_at) > 0.001 and int(p.get("scene_index")) == _movie_scene:
			_problem("the movie kept playing under the pause menu")
			_movie_frozen_at = st
	else:
		_movie_paused_t = -1.0
	if _t < _next_t or not playing:
		return
	_next_t = _t + _rng.randf_range(0.08, 1.2)
	_stats["movie_inputs"] = int(_stats.get("movie_inputs", 0)) + 1
	if menu_up:
		# the level's pause menu over the movie: wander a little, then P closes it
		if _rng.randf() < 0.6:
			_tap(&"pause")
		else:
			_key(KEY_DOWN if _rng.randf() < 0.5 else KEY_UP)
		return
	var age := float(p.get("_age"))
	var roll := _rng.randf()
	if roll < 0.18:
		_key(KEY_SPACE)
	elif roll < 0.26:
		_key(KEY_ENTER)
	elif roll < 0.32:
		_tap(&"advance_dialogue")
	elif roll < 0.5:
		# a click somewhere on the screen (never on "Skip movie" without Esc allowed)
		var at := Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720))
		var skip_b: Control = p.get("_skip_btn")
		if _movie_style == 0 and skip_b != null and skip_b.get_global_rect().grow(6.0).has_point(at):
			return
		_click(at, _rng.randf() < 0.15)
	elif roll < 0.58:
		_click((p.get("_next_btn") as Control).get_global_rect().get_center(), false)
	elif roll < 0.66:
		_stats["movie_p"] = int(_stats.get("movie_p", 0)) + 1
		_key(KEY_P)
	elif roll < 0.70 and _movie_style != 0:
		_stats["movie_esc"] = int(_stats.get("movie_esc", 0)) + 1
		_key(KEY_ESCAPE)
		if age > 0.4:
			_movie_esc_t = _t   # past the start grace: the movie must end at once
	elif roll < 0.72 and _movie_style != 0:
		_click((p.get("_skip_btn") as Control).get_global_rect().get_center(), false)
	# else: idle, watch a bit


## Roughly what the coach says, with sloppy timing.
func _follow(_st: Dictionary) -> void:
	var session: AudiometrySession = _screen.get("session")
	if session == null:
		return
	var a := session.recommended_action()
	match a["action"]:
		&"present":
			var r := _rng.randf()
			var dur := _rng.randf_range(1.0, 2.0)
			if r < 0.1:
				dur = _rng.randf_range(0.1, 0.4)
				_stats["short_beeps"] = int(_stats["short_beeps"]) + 1
			elif r < 0.15:
				dur = _rng.randf_range(3.2, 4.0)
				_stats["long_beeps"] = int(_stats["long_beeps"]) + 1
			_beep(dur)
		&"softer":
			_tap(&"softer")
		&"louder":
			_tap(&"louder")
		&"store":
			_tap(&"store")
		&"no_response":
			_tap(&"no_response")
		&"mask_toggle":
			_tap(&"toggle_mask")
		&"mask_louder":
			if _rng.randf() < 0.5:
				_tap(&"mask_louder")
			else:
				_shift_key(KEY_UP)
		&"mask_softer":
			_tap(&"mask_softer")
		&"transducer":
			_tap(&"transducer_bone" if a["target"] == &"bone" else &"transducer_air")


func _beep(dur: float) -> void:
	if _rng.randf() < 0.25:
		var b: Control = _screen.get("_buttons")["tone_button"]
		var at := b.get_global_rect().get_center()
		_mouse(at, true, MOUSE_BUTTON_LEFT)
		_held_mouse = true
	else:
		_send(&"present_tone", true)
		_held_key = true
	_release_at = _t + dur


func _release_all() -> void:
	if _held_key:
		_send(&"present_tone", false)
		_held_key = false
	if _held_mouse:
		var b: Control = _screen.get("_buttons")["tone_button"]
		_mouse(b.get_global_rect().get_center(), false, MOUSE_BUTTON_LEFT)
		_held_mouse = false
	_release_at = -1.0


func _tap(a: StringName) -> void:
	_send(a, true)
	_send(a, false)


func _send(a: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _key(k: Key) -> void:
	for p: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = p
		Input.parse_input_event(ev)


func _shift_key(k: Key) -> void:
	for p: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.shift_pressed = true
		ev.pressed = p
		Input.parse_input_event(ev)


func _click(at: Vector2, right: bool) -> void:
	_stats["clicks"] = int(_stats["clicks"]) + 1
	var btn := MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	_mouse(at, true, btn)
	_mouse(at, false, btn)


func _mouse(at: Vector2, pressed: bool, btn: MouseButton) -> void:
	var w := get_viewport().get_final_transform() * at
	var mv := InputEventMouseMotion.new()
	mv.position = w
	mv.global_position = w
	Input.parse_input_event(mv)
	var ev := InputEventMouseButton.new()
	ev.position = w
	ev.global_position = w
	ev.button_index = btn
	ev.pressed = pressed
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if btn == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	Input.parse_input_event(ev)


func _problem(msg: String) -> void:
	if _problems.size() < 20:
		_problems.append(msg)


func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	_release_all()
	var res := {}
	if _screen != null and is_instance_valid(_screen):
		res = _screen.call("get_results")
	var out := {
		"ok": code == 0, "game_seconds": Game.clock, "script_errors": _errors.count, "errors": _errors.messages,
		"problems": _problems, "stats": _stats, "grade": res.get("grade", "?"), "presentations": res.get("presentations", 0),
		"technique_errors": (res.get("technique_errors", []) as Array).size(),
		"movie_runs": _movie_runs,
	}
	print("MONKEY_RESULT ", JSON.stringify(out))
	Events.quit_requested.emit(code)
