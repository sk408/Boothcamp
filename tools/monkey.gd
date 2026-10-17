extends Node
## Monkey: a sloppy, button-mashing trainee for the AudiOtron (stress test, not a player).
## Boot:  godot --headless --path . --fixed-fps 30 -- --scene=res://tools/monkey.tscn --speed=3 --seed=N
## Tests the coached right ear, then the solo left ear (quick visit: Hoot's x8 turn), while it
## half-follows the textbook and half mashes random keys, clicks, right-clicks, pause-menu keys,
## too-short and too-long beeps. Checks every frame:
##   - no script errors;  - no tone left playing without a held key or mouse;
##   - Engine.time_scale only x8 during Hoot's turn and back to normal after it.
## Prints MONKEY_RESULT {json}; exit 0 ok, 1 an invariant broke, 3 timeout.

const ErrorCounter := preload("res://tools/autoplay_bot.gd").ScriptErrorCounter
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const MAX_GAME_S := 1500.0
const ACTIONS: Array[StringName] = [&"present_tone", &"louder", &"softer", &"freq_up", &"freq_down", &"store",
	&"no_response", &"ear_right", &"ear_left", &"toggle_key_hints", &"advance_dialogue", &"ui_accept"]

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
var _tone_unheld_s := 0.0
var _tone_flagged := false
var _done := false


func demo_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps mashing inside the pause menu too
	OS.add_logger(_errors)
	_rng.seed = int(Game.cli.get("seed", 1))
	_base_scale = Engine.time_scale
	_screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate()
	add_child(_screen)
	Events.threshold_stored.connect(func(_e: String, _f: int, _d: int, _i: Dictionary) -> void: _stats["stores"] = int(_stats["stores"]) + 1)
	_screen.call("demo_start")
	await _screen.test_finished
	_release_all()
	_screen.call("start_test", Game.load_patient("gus"), "left", false)
	await _screen.test_finished
	_release_all()
	await get_tree().process_frame
	if not is_equal_approx(Engine.time_scale, _base_scale):
		_problem("time_scale stuck at %.2f after the visit" % Engine.time_scale)
	_finish(0 if _problems.is_empty() and _errors.count == 0 else 1)


func _process(delta: float) -> void:
	if _done or _screen == null or not is_instance_valid(_screen):
		return
	_t += get_process_delta_time() if not get_tree().paused else delta
	if Game.clock > MAX_GAME_S:
		_problem("timeout")
		_finish(3)
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
		var a: StringName = ACTIONS[_rng.randi() % ACTIONS.size()]
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
	}
	print("MONKEY_RESULT ", JSON.stringify(out))
	Events.quit_requested.emit(code)
