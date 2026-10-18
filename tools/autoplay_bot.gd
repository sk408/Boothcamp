extends Node
## AutoplayBot: plays the whole level through PUBLIC contracts only (CONTRACTS.md §7).
## Added by main.gd with:  -- --autoplay [--shots=/abs/dir] [--speed=4] [--seed=N]
##  - Non-audiometer beats: waits a moment, then calls the solver from Events.awaiting_input.
##  - Audiometry: real InputEventActions (present_tone, louder, softer, freq_up/down, store,
##    no_response, ear_right/left) and only the observable patient_responded signal, running a
##    proper Hughson-Westlake search (down 10 / up 5, 2 of 3 ascending), 1 kHz retest and
##    interoctaves. It never peeks at the patient's true thresholds while testing.
##  - (v3) Bone and masking (Day 2, --day=2): switches the route (transducer_bone / _air), runs the
##    same search on bone, and the plateau ("Hood") dance on masked sheets with toggle_mask and
##    mask_louder / mask_softer: heard -> noise +5, missed -> tone +5, store after 3 noise steps
##    with the same answer. It reads only get_state() (what the screen shows) and its own stamps.
##  - Screenshots at each phase and key moments; prints AUTOPLAY_RESULT {json}; quits.
##  - --mouse: the mouse-only path. Every beat and every audiometer control is driven with real
##    InputEventMouseButton / InputEventMouseMotion at the on-screen anchors (Hoot anchors, visible
##    buttons), never with keys or solvers. On the results paper it clicks "Back to the title" and
##    checks that the title screen comes back.
## Exit codes: 0 ok, 2 stalled, 3 overall timeout, 4 results failed sanity checks,
##             5 script errors were logged during the run, 6 a mouse target was not found.

const BEAT_DELAY_S := 0.6       ## game seconds before solving a beat (lets things settle)
const STALL_TIMEOUT_S := 120.0  ## game seconds without progress -> exit 2
const MAX_RUN_S := 3000.0       ## game seconds overall -> exit 3
const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]  ## varied gaps: no rhythm
const DURATIONS: Array[float] = [1.3, 1.6, 1.2, 1.5, 1.7, 1.4]


class ScriptErrorCounter extends Logger:
	var count := 0
	var messages: PackedStringArray = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _n: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT:
			return
		_m.lock()
		count += 1
		if messages.size() < 20:
			messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_m.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _shots: Node
var _errors := ScriptErrorCounter.new()
var _last_progress := 0.0
var _phase: StringName = &""
var _phase_info: Dictionary = {}
var _pending_phase_shot := ""
var _last_beat: StringName = &""
var _ear_done: Dictionary = {}
var _responded := false
var _listening := false
var _n := 0
var _finished := false
var _shot_flags: Dictionary = {}
var _summary: Dictionary = {}
var _mouse := false
var _mouse_pos := Vector2(640, 360)
var _mouse_misses: PackedStringArray = []
var _back_at_title := false
var _want_title := false
var _resolved: Dictionary = {}   # beat -> times Events.input_resolved fired
const MOUSE_ANCHORS: Dictionary = {
	&"present_tone": "tone_button", &"louder": "louder_button", &"softer": "softer_button",
	&"freq_up": "freq_up_button", &"freq_down": "freq_down_button", &"store": "store_button",
	&"no_response": "no_response_button", &"ear_right": "ear_right_button", &"ear_left": "ear_left_button",
	# v3
	&"mask_louder": "mask_louder_button", &"mask_softer": "mask_softer_button", &"toggle_mask": "mask_toggle_button",
	&"transducer_bone": "transducer_button", &"transducer_air": "transducer_button",
}
## (v3) The bot's own stamps per sheet: test -> ear -> freq -> dB (for masked start levels).
var _mine: Dictionary = {}
var _plateaus := 0
## (v3, integrator) --via-days: start the level from the title's Days card instead of Play, with
## real input (mouse clicks with --mouse, else ui_* key actions). --pick=<chapter id> picks the card
## (default Game.next_chapter_id()); --try-locked=<id> first presses that card and expects it to
## refuse; --toggle-unlock presses "Unlock all days (demo)" first; --expect-days=gus,bonnie checks
## the unlocked list. The result gets a "days" report and problems for any failed expectation.
var _via_days := false
var _days_opened := false
var _days_report: Dictionary = {}
var _days_problems: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	OS.add_logger(_errors)
	_shots = get_parent().get_node_or_null("ScreenshotService")
	Events.phase_changed.connect(_on_phase)
	Events.awaiting_input.connect(_on_awaiting)
	Events.audiometry_started.connect(_on_audiometry_started)
	Events.patient_responded.connect(_on_responded)
	Events.tone_started.connect(_on_tone_started)
	Events.threshold_stored.connect(_on_stored)
	Events.ear_completed.connect(_on_ear_completed)
	Events.level_finished.connect(func(s: Dictionary) -> void:
		_summary = s
		_progress())
	for sig: Signal in [Events.dialogue_line, Events.audiometer_state_changed, Events.tone_stopped, Events.scene_changed]:
		sig.connect(func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void: _progress())
	_mouse = Game.cli_flag("mouse")
	_via_days = Game.cli_flag("via-days")
	Events.scene_changed.connect(func(path: String, _n: Node) -> void:
		if _want_title and path.ends_with("title_screen.tscn"):
			_back_at_title = true)
	Events.input_resolved.connect(func(b: StringName) -> void:
		_resolved[b] = int(_resolved.get(b, 0)) + 1)
	print("AutoplayBot: speed x%s, seed %d%s" % [str(Engine.time_scale), Game.rng.seed, ", MOUSE ONLY" if _mouse else ""])


func _process(_delta: float) -> void:
	if _finished:
		return
	if Game.clock - _last_progress > STALL_TIMEOUT_S:
		_fail(2, "stalled in phase %s (last beat %s)" % [_phase, _last_beat])
	elif Game.clock > MAX_RUN_S:
		_fail(3, "overall timeout")


func _progress() -> void:
	_last_progress = Game.clock


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	if _shots != null:
		await _shots.call("take", shot_name)


# ---------------------------------------------------------------- story beats

func _on_phase(phase: StringName, info: Dictionary) -> void:
	_progress()
	_phase = phase
	_phase_info = info
	var suffix := ("_" + String(info["ear"])) if info.has("ear") else ""
	if info.has("test") and String(info["test"]) != "ac":
		suffix += "_" + String(info["test"])
	_pending_phase_shot = String(phase) + suffix
	print("BOT phase ", phase, " ", info, "  t=%.0fs" % Game.clock)


func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
	_progress()
	_last_beat = beat
	await _wait(BEAT_DELAY_S)
	if _pending_phase_shot != "":
		# let the typewriter finish the line (42 chars/s) so the phase shot is readable
		if beat == &"dialogue":
			await _wait(minf(4.0, String(info.get("text", "")).length() / 40.0))
		var n := _pending_phase_shot
		_pending_phase_shot = ""
		await _shot(n)
	if beat == &"results_continue":
		await _wait(1.2)
		await _shot("results_final")
		if _mouse:
			await _mouse_results_continue()
		_finish()
		return
	if _via_days and beat == &"title_start" and not _days_opened:
		_days_opened = true
		await _open_days()
		return
	if _via_days and beat == &"chapter_select":
		await _pick_via_days(info)
		return
	if _mouse:
		await _mouse_beat(beat, info)
		return
	if solver.is_valid():
		solver.call()
	else:
		push_warning("AutoplayBot: beat %s has no valid solver" % beat)


# ---------------------------------------------------------------- audiometry

func _on_audiometry_started(_pid: String, ear: String, _coached: bool) -> void:
	_progress()
	_ear_done[ear] = false
	_run_audiometry.call_deferred(ear)


func _on_responded(_e: String, _f: int, _d: int, tone_related: bool) -> void:
	_progress()
	if tone_related and _listening:
		_responded = true


func _on_tone_started(ear: String, _f: int, _d: int) -> void:
	_progress()
	if not _shot_flags.has("tone_" + ear):
		_shot_flags["tone_" + ear] = true
		await _wait(0.35)
		await _shot("audiometry_%s_first_tone" % ear)


func _on_stored(ear: String, freq: int, db: int, info: Dictionary) -> void:
	_progress()
	var test := String(info.get("test", "ac"))
	if not _mine.has(test):
		_mine[test] = {"right": {}, "left": {}}
	(_mine[test][ear] as Dictionary)[freq] = db
	print("BOT stored %s %s %d Hz at %d dB (true %d, strokes %d, %s)" % [test, ear, freq, db, int(info.get("true_db", -99)), int(info.get("strokes", 0)), str(info.get("golf", ""))])
	if test != "ac":
		var key := "stored_%s_%s" % [test, ear]
		if not _shot_flags.has(key):
			_shot_flags[key] = true
			await _wait(0.25)
			await _shot("audiometry_%s_%s_first_store" % [ear, test])
		return
	if not _shot_flags.has("stored_" + ear):
		_shot_flags["stored_" + ear] = true
		await _wait(0.25)
		await _shot("audiometry_%s_first_store" % ear)
	elif ear == "right" and not _shot_flags.has("quip_right"):
		# the second stamp: Gus thinks out loud a beat later (mid-test, combo going)
		_shot_flags["quip_right"] = true
		await _wait(2.2)
		await _shot("audiometry_right_mid_test")


func _on_ear_completed(ear: String, _r: Dictionary) -> void:
	_progress()
	_ear_done[ear] = true
	await _wait(2.1)
	await _shot("audiometry_%s_complete" % ear)


func _screen() -> Node:
	return Stage.audiometer


func _state() -> Dictionary:
	var s := _screen()
	return s.call("get_state") if s != null else {}


func _send(action: StringName, pressed: bool) -> void:
	if _mouse and MOUSE_ANCHORS.has(action):
		var at := _anchor_center(String(MOUSE_ANCHORS[action]))
		_mouse_move(at)
		_mouse_button(at, pressed)
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(action: StringName) -> void:
	_send(action, true)
	await _frames(2)
	_send(action, false)
	await _frames(2)


func _run_audiometry(ear: String) -> void:
	var guard := 0
	while not bool(_state().get("accepting_input", false)) and guard < 200:
		await _frames(1)
		guard += 1
	if _pending_phase_shot != "":
		var n := _pending_phase_shot
		_pending_phase_shot = ""
		await _wait(0.5)
		await _shot(n)
	if String(_state().get("ear", "")) != ear:
		await _tap(&"ear_right" if ear == "right" else &"ear_left")
	var goal := StringName(_state().get("goal_test", &"ac"))
	if goal != &"ac":
		await _run_v3(ear, goal)
		return
	var found: Dictionary = {}   # freq -> db (first measurement)
	var last := -1
	var plan: Array[int] = ClinicRules.TEST_ORDER.duplicate()
	var i := 0
	while i < plan.size() and not _ear_done.get(ear, false) and not _hoot_turn():
		var f: int = plan[i]
		i += 1
		var start := ClinicRules.START_DB if last < 0 else clampi(last + 10, 20, ClinicRules.MAX_START_DB)
		if found.has(f):
			start = clampi(int(found[f]) + 10, ClinicRules.MIN_DB, ClinicRules.MAX_START_DB)  # retest
		var thr := await _measure(f, start)
		if thr.is_empty() or _hoot_turn():
			break
		if not found.has(f):
			found[f] = thr["db"]
		last = thr["db"]
		# insert any newly required inter-octave right after its upper neighbour is known
		for io: int in ClinicRules.required_interoctaves(found):
			if not found.has(io) and not plan.slice(i).has(io):
				plan.insert(i, io)
	# Fallback: whatever the screen still asks for.
	var safety := 0
	while not _ear_done.get(ear, false) and safety < 6 and not _hoot_turn():
		safety += 1
		var rem: Array = _state().get("remaining", [])
		if rem.is_empty():
			break
		var f2: int = rem[0]
		var start2 := clampi((int(found[f2]) if found.has(f2) else last) + 10, ClinicRules.MIN_DB, ClinicRules.MAX_START_DB)
		var thr2 := await _measure(f2, start2)
		if thr2.is_empty():
			break
		last = thr2["db"]
	# quick visit: Hoot finishes the solo ear at x8 (input locked); wait for it in game time
	if _hoot_turn() and not _shot_flags.has("hoot_turn"):
		_shot_flags["hoot_turn"] = true
		print("BOT Hoot's turn on the %s ear" % ear)
		await _wait(3.0)
		await _shot("audiometry_%s_hoot_turn" % ear)
	var t0 := Game.clock
	while not _ear_done.get(ear, false) and Game.clock - t0 < 900.0:
		await _frames(1)


func _hoot_turn() -> bool:
	return bool(_state().get("hoot_turn", false))


## Go to freq, set the start level, bracket, store. Returns {"db", "no_response"}.
func _measure(freq: int, start_db: int) -> Dictionary:
	if not await _goto_freq(freq):
		push_warning("AutoplayBot: cannot reach %d Hz" % freq)
		return {}
	await _set_level(start_db)
	var r := await _hughson_westlake(freq)
	var before := Game.clock
	await _tap(&"no_response" if bool(r["no_response"]) else &"store")
	await _wait(0.3)
	if Game.clock - before > 30.0:
		push_warning("AutoplayBot: store took too long")
	return r


func _hughson_westlake(_freq: int) -> Dictionary:
	var level: int = _state()["db"]
	var max_db := int(_state().get("max_db", ClinicRules.max_db(_freq)))  # bone runs out early
	var hits: Dictionary = {}
	var trials: Dictionary = {}
	var prev_heard := true  # the first response is never "ascending"
	var heard_any := false
	for n in 30:
		var heard := await _present()
		if not prev_heard and heard_any:
			trials[level] = int(trials.get(level, 0)) + 1
		if heard:
			if not prev_heard and heard_any:
				hits[level] = int(hits.get(level, 0)) + 1
				if int(hits[level]) >= ClinicRules.ASCENDING_HITS_NEEDED and int(hits[level]) * 2 >= int(trials[level]):
					return {"db": level, "no_response": false}
			heard_any = true
			if level <= ClinicRules.MIN_DB:
				return {"db": level, "no_response": false}
			level = maxi(level - ClinicRules.DOWN_AFTER_HIT_DB, ClinicRules.MIN_DB)
		else:
			if level >= max_db:
				return {"db": max_db, "no_response": true}
			level = mini(level + (ClinicRules.UP_AFTER_MISS_DB if heard_any else ClinicRules.UP_SEARCH_DB), max_db)
		prev_heard = heard
		await _set_level(level)
	return {"db": level, "no_response": false}


## One presentation: varied gap, hold the tone 1.2-1.7 s, wait for a response window.
func _present() -> bool:
	await _wait(GAPS[_n % GAPS.size()])
	var dur: float = DURATIONS[_n % DURATIONS.size()]
	_n += 1
	_responded = false
	_listening = true
	_send(&"present_tone", true)
	await _wait(dur)
	_send(&"present_tone", false)
	var t0 := Game.clock
	while not _responded and Game.clock - t0 < ClinicRules.RESPONSE_WINDOW_S:
		await _frames(1)
	_listening = false
	return _responded


func _set_level(target: int) -> void:
	var guard := 0
	while int(_state().get("db", target)) != target and guard < 40:
		await _tap(&"louder" if int(_state()["db"]) < target else &"softer")
		guard += 1


func _goto_freq(target: int) -> bool:
	var freqs: Array = _state().get("freqs_available", [])
	if not freqs.has(target):
		return false
	var guard := 0
	while int(_state().get("freq", target)) != target and guard < 20:
		var cur := freqs.find(int(_state()["freq"]))
		await _tap(&"freq_up" if cur < freqs.find(target) else &"freq_down")
		guard += 1
	return int(_state().get("freq", -1)) == target


# ---------------------------------------------------------------- v3: bone and masking

## Bone (unmasked) or a masked sheet: whatever the screen's goal sheet still needs.
func _run_v3(ear: String, goal: StringName) -> void:
	var bone := ClinicRules.test_is_bone(goal)
	var masked := ClinicRules.test_is_masked(goal)
	var safety := 0
	while not _ear_done.get(ear, false) and not _hoot_turn() and safety < 12:
		safety += 1
		await _route(bone, masked)
		var rem: Array = _state().get("remaining", [])
		if rem.is_empty():
			break
		var f: int = rem[0]
		if not await _goto_freq(f):
			push_warning("AutoplayBot: cannot reach %d Hz on %s" % [f, goal])
			break
		if masked:
			await _plateau(ear, f, goal)
		else:
			await _set_level(30)
			var r := await _hughson_westlake(f)
			await _tap(&"no_response" if bool(r["no_response"]) else &"store")
			await _wait(0.3)
	if _hoot_turn() and not _shot_flags.has("hoot_turn_" + String(goal)):
		_shot_flags["hoot_turn_" + String(goal)] = true
		print("BOT Hoot's turn on the %s ear (%s)" % [ear, goal])
		await _wait(3.0)
		await _shot("audiometry_%s_%s_hoot_turn" % [ear, goal])
	var t0 := Game.clock
	while not _ear_done.get(ear, false) and Game.clock - t0 < 900.0:
		await _frames(1)


## Put the controls on the goal sheet: the right transducer, masking on or off.
func _route(bone: bool, masked: bool) -> void:
	var guard := 0
	while (StringName(_state().get("transducer", &"phones")) == &"bone") != bone and guard < 4:
		await _tap(&"transducer_bone" if bone else &"transducer_air")
		guard += 1
	guard = 0
	while bool(_state().get("mask_on", false)) != masked and guard < 4:
		await _tap(&"toggle_mask")
		guard += 1


func _set_mask(target: int) -> void:
	var guard := 0
	while int(_state().get("mask_db", target)) != target and guard < 40:
		await _tap(&"mask_louder" if int(_state()["mask_db"]) < target else &"mask_softer")
		guard += 1


## The plateau dance at one frequency: start at the unmasked stamp with the initial masking the
## screen's helper shows, heard -> noise +5, missed -> tone +5, store after PLATEAU_STEPS noise
## raises with the same answer (or when the next raise would overmask).
func _plateau(ear: String, freq: int, goal: StringName) -> void:
	var unmasked := String(ClinicRules.unmasked_test(goal))
	var start := int((_mine.get(unmasked, {}).get(ear, {}) as Dictionary).get(freq, 30))
	var initial := int(_state().get("initial_mask_db", 30))
	await _set_mask(initial)
	await _set_level(start)
	var steps := 0
	var max_db := int(_state().get("max_db", 70))
	for n in 40:
		var heard := await _present()
		var tone := int(_state()["db"])
		var noise := int(_state()["mask_db"])
		if heard:
			if steps >= ClinicRules.PLATEAU_STEPS:
				break
			var limit := int(_state().get("overmask_limit_db", 999))
			if noise + ClinicRules.MASK_STEP_DB >= limit:
				break  # one more step would overmask: the best answer so far
			steps += 1
			await _set_mask(noise + ClinicRules.MASK_STEP_DB)
		else:
			steps = 0
			if tone >= max_db:
				await _tap(&"no_response")
				await _wait(0.3)
				return
			await _set_level(tone + ClinicRules.UP_AFTER_MISS_DB)
	if bool((_state().get("plateau", {}) as Dictionary).get("found", false)):
		_plateaus += 1
		if not _shot_flags.has("plateau"):
			_shot_flags["plateau"] = true
			await _wait(0.2)
			await _shot("audiometry_%s_plateau" % ear)
	await _tap(&"store")
	await _wait(0.3)


# ---------------------------------------------------------------- mouse-only path (--mouse)

## Viewport (canvas) coordinates -> window coordinates, which is what OS mouse events carry.
## Identity in a 1280x720 window; the headless window is 64x64, so this matters there.
func _to_window(p: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * p


func _mouse_move(to: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	var w := _to_window(to)
	ev.position = w
	ev.global_position = w
	ev.relative = w - _to_window(_mouse_pos)
	ev.button_mask = Input.get_mouse_button_mask()
	Input.parse_input_event(ev)
	_mouse_pos = to


func _mouse_button(at: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	var w := _to_window(at)
	ev.position = w
	ev.global_position = w
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)


func _click(at: Vector2) -> void:
	_mouse_move(at)
	await _frames(2)
	_mouse_button(at, true)
	await _frames(2)
	_mouse_button(at, false)
	await _frames(2)


func _drag(from: Vector2, to: Vector2) -> void:
	_mouse_move(from)
	await _frames(2)
	_mouse_button(from, true)
	await _frames(2)
	for i in range(1, 11):
		_mouse_move(from.lerp(to, i / 10.0))
		await _frames(1)
	await _frames(2)
	_mouse_button(to, false)
	await _frames(3)



func _anchor_center(id: String) -> Vector2:
	var r := Hoot.anchor_screen_rect(id)
	if r == Rect2():
		_mouse_misses.append("anchor " + id)
		push_warning("AutoplayBot(mouse): no anchor " + id)
	return r.get_center()


## The visible, on-screen control (Button text or Label text) matching a prefix, like a player
## reading the screen. Returns null when nothing matches.
func _find_visible_text(prefix: String, root: Node = null) -> Control:
	if root == null:
		root = get_tree().root
	for c in root.get_children():
		var found := _find_visible_text(prefix, c)
		if found != null:
			return found
	if root is Control and (root as Control).is_visible_in_tree():
		var t := ""
		if root is Button:
			t = (root as Button).text
		elif root is Label:
			t = (root as Label).text
		# match the start of the text, ignoring decorations like "> Play <"
		if t != "" and t.strip_edges().lstrip("> ").begins_with(prefix):
			return root as Control
	return null


func _click_text(prefix: String) -> void:
	var c := _find_visible_text(prefix)
	if c == null:
		_mouse_misses.append("text '%s'" % prefix)
		push_warning("AutoplayBot(mouse): nothing on screen says '%s'" % prefix)
		return
	await _click(c.get_global_rect().get_center())


func _find_script_node(script_suffix: String, root: Node = null) -> Node:
	if root == null:
		root = get_tree().root
	var sc: Script = root.get_script() as Script
	if sc != null and sc.resource_path.ends_with(script_suffix):
		return root
	for c in root.get_children():
		var f := _find_script_node(script_suffix, c)
		if f != null:
			return f
	return null


func _mouse_beat(beat: StringName, info: Dictionary) -> void:
	var vp := get_viewport().get_visible_rect().size
	match beat:
		&"disclaimer_ok":
			await _click_text("Got it")
		&"title_start":
			await _click_text("Play")
		&"dialogue":
			# click the line: the first click may only finish the typewriter, so click until resolved
			var before := int(_resolved.get(&"dialogue", 0))
			for attempt in 4:
				await _click(Vector2(vp.x * 0.5, vp.y - 110.0))
				var t0 := Game.clock
				while int(_resolved.get(&"dialogue", 0)) == before and Game.clock - t0 < 0.5:
					await _frames(1)
				if int(_resolved.get(&"dialogue", 0)) != before:
					break
		&"choice":
			var opts: Array = info.get("options", [])
			var best := int(info.get("best", 0))
			await _wait(0.4)
			await _click_text(String(opts[best]).substr(0, 18))
		&"otoscopy_find":
			var at := _anchor_center("otoscope_seed")
			for i in range(1, 7):
				_mouse_move(Vector2(vp.x * 0.3, vp.y * 0.5).lerp(at, i / 6.0))
				await _frames(2)
			await _click(at)
		&"earphones_place":
			await _drag(_anchor_center("earphone_red"), _anchor_center("ear_target_right"))
			await _wait(0.6)
			await _drag(_anchor_center("earphone_blue"), _anchor_center("ear_target_left"))
		&"evidence_present":
			await _drag(_anchor_center("evidence_slope"), _anchor_center("evidence_target"))
		&"bc_placement":
			await _drag(_anchor_center("oscillator"), _anchor_center("mastoid_target_right"))
		&"referral_stamp":
			await _click(_anchor_center("referral_stamp"))
		&"chapter_select":
			await _click_text(String(Game.chapter(String(info.get("next", "gus"))).get("title", "Day 1")).substr(0, 12))
		&"fitting_switch_on":
			var fit := _find_script_node("story/games/fitting.gd")
			var btn: Control = fit.get("_btn") as Control if fit != null else null
			if btn == null:
				_mouse_misses.append("fitting switch")
				return
			await _click(btn.get_global_rect().get_center())
		_:
			_mouse_misses.append("beat " + String(beat))
			push_warning("AutoplayBot(mouse): no mouse route for beat " + String(beat))


func _mouse_results_continue() -> void:
	_want_title = true
	await _click_text("Back to the title")
	var t0 := Game.clock
	while not _back_at_title and Game.clock - t0 < 10.0:
		await _frames(2)
	if not _back_at_title:
		_mouse_misses.append("title after results")


# ---------------------------------------------------------------- v3: the title's Days card

## Title menu -> "Days", like a player: click it (--mouse) or move the highlight with ui_down and
## press ui_accept (keys). The title then emits the chapter_select beat.
func _open_days() -> void:
	if _mouse:
		await _click_text("Days")
		return
	for i in 8:
		var b := _find_visible_text("Days") as Button
		if b != null and b.text.begins_with(">"):
			break
		await _tap(&"ui_down")
	await _tap(&"ui_accept")


## A day card or the demo toggle on the Days card, found by what it shows (its label meta, which
## the title also draws on the card).
func _days_button(match_label: String) -> Button:
	var title := get_tree().get_first_node_in_group("title_screen")
	if title == null:
		return null
	for b: Button in title.get("_day_buttons"):
		if b.is_visible_in_tree() and String(b.get_meta("label", "")).begins_with(match_label):
			return b
	return null


## Press one Days-card button: a click (--mouse), or ui_right until it glows and ui_accept (keys).
func _press_days_button(b: Button) -> void:
	if b == null:
		_days_problems.append("days: button missing")
		return
	if _mouse:
		await _click(b.get_global_rect().get_center())
		return
	# the highlight a player sees: a card glows (meta "hl"), a plain button reads "> text <"
	var title := get_tree().get_first_node_in_group("title_screen")
	var buttons: Array = title.get("_day_buttons")
	for i in buttons.size() + 1:
		if bool(b.get_meta("hl", false)) or b.text.begins_with(">"):
			break
		await _tap(&"ui_right")
	await _tap(&"ui_accept")


func _pick_via_days(info: Dictionary) -> void:
	var unlocked: Array = info.get("chapters", [])
	_days_report["unlocked"] = unlocked.duplicate()
	var expect := String(Game.cli_value("expect-days", ""))
	if expect != "" and ",".join(PackedStringArray(unlocked.map(func(x: Variant) -> String: return String(x)))) != expect:
		_days_problems.append("days: unlocked %s, expected %s" % [str(unlocked), expect])
	var locked_id := String(Game.cli_value("try-locked", ""))
	if locked_id != "":
		var ch := Game.chapter(locked_id)
		var card := _days_button(String(ch.get("title", "?")))
		_days_report["locked_label"] = String(card.get_meta("label", "")) if card != null else ""
		if card == null or not bool(card.get_meta("locked", false)):
			_days_problems.append("days: %s should show as locked" % locked_id)
		var before := int(_resolved.get(&"chapter_select", 0))
		await _press_days_button(card)
		await _wait(0.8)
		var refused := int(_resolved.get(&"chapter_select", 0)) == before and Game.is_chapter_unlocked(locked_id) == false
		_days_report["locked_refused"] = refused
		if not refused:
			_days_problems.append("days: the locked %s card started a level" % locked_id)
		await _shot("days_locked_refused")
	if Game.cli_flag("toggle-unlock"):
		await _press_days_button(_days_button("Unlock all days"))
		await _wait(0.5)
		_days_report["toggled"] = bool(Game.settings.get("unlock_all_days", false))
		_days_report["unlocked_after_toggle"] = Game.unlocked_chapter_ids()
		if not bool(Game.settings.get("unlock_all_days", false)):
			_days_problems.append("days: the demo toggle did not switch on")
		await _shot("days_toggled")
	var pick := String(Game.cli_value("pick", info.get("next", "gus")))
	_days_report["picked"] = pick
	var card2 := _days_button(String(Game.chapter(pick).get("title", "?")))
	if card2 != null and bool(card2.get_meta("locked", false)):
		_days_problems.append("days: %s is still locked" % pick)
	await _press_days_button(card2)


# ---------------------------------------------------------------- finish

func _finish() -> void:
	if _finished:
		return
	_finished = true
	var res: Dictionary = _summary.get("audiometry", Game.visit.get("audiometry", {}))
	var report := {"grade": _summary.get("grade", "?"), "score": snappedf(float(_summary.get("score", 0.0)), 0.1),
		"accuracy": snappedf(float(res.get("accuracy", 0.0)), 0.001), "technique": snappedf(float(res.get("technique", 0.0)), 0.001),
		"efficiency": snappedf(float(res.get("efficiency", 0.0)), 0.001), "presentations": res.get("presentations", 0),
		"script_errors": _errors.count, "game_seconds": snappedf(Game.clock, 0.1), "thresholds": {},
		"technique_errors": (res.get("technique_errors", []) as Array).map(func(e: Dictionary) -> String: return "%s@%s/%s" % [e.get("kind", ""), e.get("ear", ""), str(e.get("freq", ""))])}
	var problems: PackedStringArray = []
	var ears: Dictionary = res.get("ears", {})
	_check_v3(res, report, problems)
	for ear: String in ["right", "left"]:
		if not ears.has(ear) or not bool((ears[ear] as Dictionary).get("complete", false)):
			problems.append("%s ear incomplete" % ear)
			continue
		var t := {}
		for f: int in ears[ear]["freqs"]:
			var info: Dictionary = ears[ear]["freqs"][f]
			t[str(f)] = [info["stored_db"], info["true_db"]]
			if absi(int(info["stored_db"]) - int(info["true_db"])) > 10:
				problems.append("%s %d Hz off by more than 10 dB" % [ear, f])
		report["thresholds"][ear] = t
	if _summary.is_empty():
		problems.append("level_finished never fired")
	if _mouse:
		report["mouse_only"] = true
		report["mouse_misses"] = _mouse_misses
		report["back_at_title"] = _back_at_title
	if _via_days:
		_days_report["played"] = String(_summary.get("chapter_id", ""))
		_days_report["chapters_done"] = Game.progress.get("chapters_done", [])
		report["days"] = _days_report
		if not _days_opened or not _days_report.has("picked"):
			problems.append("days: the Days card never opened")
		elif String(_summary.get("chapter_id", "")) != String(_days_report["picked"]):
			problems.append("days: picked %s but played %s" % [_days_report["picked"], _summary.get("chapter_id", "")])
		problems.append_array(_days_problems)
	report["problems"] = problems
	print("AUTOPLAY_RESULT ", JSON.stringify(report))
	var code := 0
	if not problems.is_empty():
		code = 4
	if _mouse and not _mouse_misses.is_empty():
		code = 6
	if _errors.count > 0:
		for m in _errors.messages:
			print("SCRIPT ERROR: ", m)
		code = 5
	OS.remove_logger(_errors)
	Events.quit_requested.emit(code)


## (v3) Bone / masked sheets: every stamp within 10 dB of the truth; on Day 2 the right ear must
## come out conductive with the referral red flag, with masked bone at 500-4k.
func _check_v3(res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var ears: Dictionary = res.get("ears", {})
	var sheets := {}
	for ear: String in ["right", "left"]:
		var e: Dictionary = ears.get(ear, {})
		for key: String in ["bc", "bc_masked", "ac_masked"]:
			var sh: Dictionary = e.get(key, {})
			if sh.is_empty():
				continue
			var t := {}
			for f: int in sh:
				var info: Dictionary = sh[f]
				t[str(f)] = [info["stored_db"], info["true_db"]]
				if absi(int(info["stored_db"]) - int(info["true_db"])) > 10:
					problems.append("%s %s %d Hz off by more than 10 dB" % [ear, key, f])
			sheets["%s_%s" % [ear, key]] = t
	if not sheets.is_empty():
		report["sheets"] = sheets
		report["plateaus_found"] = _plateaus
	if String(_summary.get("chapter_id", "")) == "bonnie":
		var r: Dictionary = ears.get("right", {})
		report["right_type"] = String(r.get("hearing_type", ""))
		report["right_abg"] = r.get("abg", {})
		if StringName(r.get("hearing_type", &"")) != &"conductive":
			problems.append("Bonnie's right ear should be conductive, got %s" % str(r.get("hearing_type", "")))
		if not bool(r.get("abg_red_flag", false)):
			problems.append("no air-bone gap red flag on Bonnie's right ear")
		for f: int in [500, 1000, 2000, 4000]:
			if not (r.get("bc_masked", {}) as Dictionary).has(f):
				problems.append("right masked bone missing at %d Hz" % f)
		if (r.get("ac_masked", {}) as Dictionary).is_empty():
			problems.append("right masked air missing")


func _fail(code: int, why: String) -> void:
	if _finished:
		return
	_finished = true
	print("AUTOPLAY_FAILED code=%d: %s" % [code, why])
	for m in _errors.messages:
		print("SCRIPT ERROR: ", m)
	await _shot("stuck_" + String(_phase))
	Events.quit_requested.emit(code)
