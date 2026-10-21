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
##  - (v4) Hoot's masking movie (beat "explainer"): keys press Space (advance like dialogue) until
##    scene 2, then Esc (skip); --mouse clicks "Next" then "Skip movie". The masking recap card
##    (one scene) the same way. The Ghost demo (get_state().demo): hold TONE
##    once (again if she misses); it stores nothing and emits no ear_completed, so the bot also
##    treats Events.audiometry_finished as the end of a test.
##  - Screenshots at each phase and key moments; prints AUTOPLAY_RESULT {json}; quits.
##  - --mouse: the mouse-only path. Every beat and every audiometer control is driven with real
##    InputEventMouseButton / InputEventMouseMotion at the on-screen anchors (Hoot anchors, visible
##    buttons), never with keys or solvers. On the results paper it clicks "Back to the title" and
##    checks that the title screen comes back.
## Exit codes: 0 ok, 2 stalled, 3 overall timeout, 4 results failed sanity checks,
##             5 script errors were logged during the run, 6 a mouse target was not found.

const CaseData := preload("res://story/case_data.gd")
const BEAT_DELAY_S := 0.6       ## game seconds before solving a beat (lets things settle)
const STALL_TIMEOUT_S := 120.0  ## game seconds without progress -> exit 2
const MAX_RUN_S := 3000.0       ## game seconds overall -> exit 3
const GAPS: Array[float] = [1.1, 1.6, 1.05, 2.1, 1.2, 1.8, 1.3, 2.4]  ## varied gaps: no rhythm, never shorter than a beep (E6)
const DURATIONS: Array[float] = [1.3, 1.6, 1.2, 1.5, 1.7, 1.4]


class ScriptErrorCounter extends Logger:
	var count := 0
	var messages: PackedStringArray = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _n: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		# script errors, plus engine errors and push_error() (polish): warnings stay out
		if error_type != Logger.ERROR_TYPE_SCRIPT and error_type != Logger.ERROR_TYPE_ERROR:
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
var _cur_ear := ""               # (v4) the ear of the test on screen (audiometry_started)
var _movies: Array[String] = []  # (v4) movies that started (Events.explainer_started)
var _paper_text: PackedStringArray = []   # (Days 4-5) Day 5: the Daily Decibel's words, read before it goes
var _demo_tones := 0             # (v4) tones held in the Ghost demo
var _phase_log: Array[StringName] = []
const MOUSE_ANCHORS: Dictionary = {
	&"present_tone": "tone_button", &"louder": "louder_button", &"softer": "softer_button",
	&"freq_up": "freq_up_button", &"freq_down": "freq_down_button", &"store": "store_button",
	&"no_response": "no_response_button", &"ear_right": "ear_right_button", &"ear_left": "ear_left_button",
	# v3
	&"mask_louder": "mask_louder_button", &"mask_softer": "mask_softer_button", &"toggle_mask": "mask_toggle_button",
	&"transducer_bone": "transducer_bone_button", &"transducer_air": "transducer_air_button",
}
## (v3) The bot's own stamps per sheet: test -> ear -> freq -> dB (for masked start levels).
var _mine: Dictionary = {}
var _plateaus := 0
## (v3, integrator) --via-days: start the level from the title's Days card instead of Play, with
## real input (mouse clicks with --mouse, scrolling the grid with the wheel when the card is out
## of view; else ui_* key actions). --pick=<chapter id> picks the card (default
## Game.next_chapter_id()); --expect-days=gus,bonnie checks that the listed days are on the grid,
## open and in this order (other days may sit between or after them);
## (polish) --expect-suggested=<id> checks which card wears the UP NEXT badge. Every day is open,
## so any --pick works on any save. The result gets a "days" report and problems for any failed
## expectation.
var _via_days := false
## (freestyle) --via-freestyle: start from the title's Freestyle button; the waiting room's pick
## is then an ordinary choice beat (best = --freestyle=<id>, docs/FREESTYLE.md).
var _via_freestyle := false
var _freestyle_opened := false
var _days_opened := false
var _days_report: Dictionary = {}
var _days_problems: PackedStringArray = []
## (Cases) Problems seen during a case's visit (the retest must start after the scored visit is saved).
var _case_problems: PackedStringArray = []


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
	# (v4) the Ghost demo ends with audiometry_finished only (nothing stored, no ear_completed)
	Events.audiometry_finished.connect(func(_r: Dictionary) -> void:
		_progress()
		if _cur_ear != "":
			_ear_done[_cur_ear] = true)
	Events.explainer_started.connect(func(id: String, _src: String) -> void:
		_progress()
		_movies.append(id))
	Events.explainer_scene.connect(func(_id: String, _i: int, _sid: String) -> void: _progress())
	Events.level_finished.connect(func(s: Dictionary) -> void:
		_summary = s
		_progress())
	for sig: Signal in [Events.dialogue_line, Events.audiometer_state_changed, Events.tone_stopped, Events.scene_changed]:
		sig.connect(func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null) -> void: _progress())
	# (Speech, §9.9) the SPEECH screen's progress; its beats come through awaiting_input like any other
	for sig: Signal in [Events.speech_started, Events.speech_response, Events.speech_scored, Events.speech_state_changed]:
		sig.connect(func(_a: Variant = null, _b: Variant = null, _c: Variant = null, _d: Variant = null, _e: Variant = null) -> void: _progress())
	Events.speech_presented.connect(_on_speech_presented)
	Events.speech_stored.connect(_on_speech_stored)
	_mouse = Game.cli_flag("mouse")
	_via_days = Game.cli_flag("via-days")
	_via_freestyle = Game.cli_flag("via-freestyle")
	Events.scene_changed.connect(func(path: String, _n: Node) -> void:
		# (freestyle) the paper's main button can lead elsewhere: summary "continue_scene"
		if _want_title and (path.ends_with("title_screen.tscn") or path == String(_summary.get("continue_scene", "-"))):
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
	_phase_log.append(phase)
	if phase == &"retest" and not Game.visit.has("summary"):
		_case_problems.append("retest: began before the scored visit was saved (quitting would lose the day)")
	var suffix := ("_" + String(info["ear"])) if info.has("ear") else ""
	if info.has("test") and String(info["test"]) != "ac":
		suffix += "_" + String(info["test"])
	if bool(info.get("retest", false)):
		suffix += "_retest"   # a case's retest repeats phases: keep the first visit's shots
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
		# (Days 4-5) §9.22.6: Day 5 reads the paper's words while it is on screen
		if String(_summary.get("chapter_id", "")) == "marco":
			_paper_text = _visible_texts(get_tree().root)
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
	if beat == &"explainer" and not _mouse:
		await _keys_explainer(solver, info)
		return
	if _via_freestyle and beat == &"title_start" and not _freestyle_opened:
		_freestyle_opened = true
		await _open_title_button("Freestyle")
		return
	if _mouse:
		await _mouse_beat(beat, info)
		return
	if solver.is_valid():
		solver.call()
	else:
		push_warning("AutoplayBot: beat %s has no valid solver" % beat)


## (v4) Hoot's movie with real keys: Space advances like dialogue (finish the caption, the next
## caption, the next scene) until scene 2 shows, a peek at it, then Esc (skip it all). The solver
## is the fallback when the keys did not end it. A one-scene recap: one Space, the peek, Esc.
func _keys_explainer(solver: Callable, info: Dictionary = {}) -> void:
	var p := get_tree().get_first_node_in_group("explainer_player")
	for i in 4:
		if _explainer_peeked(p):
			break
		await _tap(&"advance_dialogue")
		await _wait(0.3)
	await _wait(_explainer_settle(p))
	await _shot(_explainer_shot(info))
	await _tap(&"ui_cancel")
	await _wait(0.6)
	p = get_tree().get_first_node_in_group("explainer_player")
	if p != null and bool(p.call("is_playing")) and solver.is_valid():
		push_warning("AutoplayBot: Esc did not skip the movie; using the solver")
		solver.call()


## True once the peek has gone far enough: scene 2 of a long movie, the first (only) scene of a
## one-scene recap (advancing there would end it before its shot), or the movie is gone.
func _explainer_peeked(p: Node) -> bool:
	if p == null or not bool(p.call("is_playing")):
		return true
	var scenes: Array = (p.get("movie") as Dictionary).get("scenes", [])
	return int(p.get("scene_index")) >= mini(1, scenes.size() - 1)


## How long to let the peeked scene play before its shot: a recap card's four lines are all in by 6.2 s.
func _explainer_settle(p: Node) -> float:
	if p == null or not bool(p.call("is_playing")):
		return 0.3
	var scenes: Array = (p.get("movie") as Dictionary).get("scenes", [])
	return 6.6 if scenes.size() <= 1 else 1.3


## The peek's shot name: explainer_scene_2 for the day's movie, explainer_<id> for a recap.
func _explainer_shot(info: Dictionary) -> String:
	var id := String(info.get("movie", "masking"))
	return "explainer_scene_2" if id == "masking" else "explainer_%s" % id


# ---------------------------------------------------------------- audiometry

func _on_audiometry_started(_pid: String, ear: String, _coached: bool) -> void:
	_progress()
	_cur_ear = ear
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


# ---------------------------------------------------------------- speech (§9.9)

func _on_speech_presented(ear: String, test: StringName, db: int, item: Dictionary) -> void:
	_progress()
	var key := "speech_%s_%s_first_word" % [ear, test]
	# (Days 4-5) D26: a word or party list's shots carry its slot and list id
	if test != &"srt":
		key = _speech_shot_key(ear, test, String(item.get("slot", ear)), String(item.get("list_id", ""))) + "_first_word"
	if not _shot_flags.has(key):
		_shot_flags[key] = true
		await Events.speech_response   # this word's answer: the bubble is up
		await _wait(0.3)
		await _shot(key)
	# (Days 4-5) D26: the descent shot is an SRT idea
	if test != &"srt":
		return
	if not _shot_flags.has("speech_%s_low" % ear) and db <= 40:
		_shot_flags["speech_%s_low" % ear] = true
		await Events.speech_response
		await _wait(0.3)
		await _shot("speech_%s_%s_descent" % [ear, test])


func _on_speech_stored(ear: String, test: StringName, sheet: Dictionary) -> void:
	_progress()
	print("BOT speech stored %s %s at %d dB (true %d, words %d, par %d, %s, agreement %s)" % [test, ear, int(sheet.get("stored_db", -99)),
		int(sheet.get("true_db", -99)), int(sheet.get("words", 0)), int(sheet.get("par", 0)), str(sheet.get("golf", "")), str(sheet.get("agreement", ""))])
	await _wait(1.0)
	# (Days 4-5) D26: each list of an ear (comfortable, redo, louder) gets its own stored shot
	if test != &"srt":
		var lists: Array = sheet.get("lists", [])
		var list_id := String((lists.back() as Dictionary).get("list_id", "")) if not lists.is_empty() else String(sheet.get("list_id", ""))
		await _shot(_speech_shot_key(ear, test, String(sheet.get("slot", ear)), list_id) + "_stored")
		return
	await _shot("speech_%s_%s_stored" % [ear, test])


## (Days 4-5) D26: Day 3's SRT names stay; a word or party list adds its slot and list id.
func _speech_shot_key(ear: String, test: StringName, slot: String, list_id: String) -> String:
	if test == &"srt":
		return "speech_%s_%s" % [ear, test]
	return "speech_%s_%s_%s" % [slot, test, list_id]


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
	var st0 := _state()
	print("BOT test %s %s opens at %d Hz %d dB on %s" % [ear, goal, int(st0.get("freq", 0)), int(st0.get("db", 0)), str(st0.get("test", ""))])
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
		if f == ClinicRules.START_FREQ and found.has(f) and not (_state().get("remaining", []) as Array).has(f):
			continue   # (E2) the 1 kHz retest is only owed by the first air ear of the visit
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
	var floor_hits := 0
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
				floor_hits += 1
				if floor_hits >= ClinicRules.ASCENDING_HITS_NEEDED:
					return {"db": level, "no_response": false}  # heard twice at the floor
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
	if bool(_state().get("demo", false)):
		await _demo(ear)
		return
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


## (v4) The Ghost demo: every control but TONE is locked. Hold TONE once; if she misses, the screen
## raises the tone 5 and asks again (at most 3 tones), then ends by itself.
func _demo(ear: String) -> void:
	for i in 3:
		if not bool(_state().get("demo", false)) or not bool(_state().get("accepting_input", false)):
			break
		_demo_tones += 1
		var heard := await _present()
		print("BOT Ghost demo tone %d at %d dB: %s" % [i + 1, int(_state().get("db", -1)), "heard" if heard else "missed"])
		if i == 0:
			await _wait(0.5)
			await _shot("audiometry_%s_ghost_demo" % ear)
		if heard:
			break
	var t0 := Game.clock
	while not _ear_done.get(ear, false) and Game.clock - t0 < 60.0:
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
	var mine_un: Dictionary = _mine.get(unmasked, {})
	var start := -999
	if (mine_un.get(ear, {}) as Dictionary).has(freq):
		start = int(mine_un[ear][freq])
	elif ClinicRules.test_is_bone(goal):
		# (v4) bone went on the better ear first: unmasked bone from EITHER mastoid is the start
		for e: String in ["right", "left"]:
			if (mine_un.get(e, {}) as Dictionary).has(freq):
				start = int(mine_un[e][freq]) if start == -999 else mini(start, int(mine_un[e][freq]))
	if start == -999:
		start = int(_state().get("db", 30))
	# (E9) the screen's start: the initial masking, or one step short of overmasking in a dilemma
	var initial := int(_state().get("start_mask_db", _state().get("initial_mask_db", 30)))
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
			var lim := int(_state().get("overmask_limit_db", 999))
			if int(_state()["mask_db"]) >= lim:
				await _set_mask(lim - ClinicRules.MASK_STEP_DB)  # (E9) never overmask the next tone
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
			# (v4) the left mastoid first, then the right one for the Ghost demo: info.targets says which
			var targets: Array = info.get("targets", ["mastoid_target_right"])
			await _drag(_anchor_center("oscillator"), _anchor_center(String(targets[0])))
		&"explainer":
			# (v4) Hoot's movie: "Next" (advances like dialogue) until scene 2 shows, then "Skip movie"
			var p := get_tree().get_first_node_in_group("explainer_player")
			for i in 4:
				if _explainer_peeked(p):
					break
				await _click((p.get("_next_btn") as Control).get_global_rect().get_center())   # a real click on "Next"
				await _wait(0.3)
			await _wait(_explainer_settle(p))
			await _shot(_explainer_shot(info))
			if p != null and bool(p.call("is_playing")):
				await _click_text("Skip movie")
		&"referral_stamp":
			await _click(_anchor_center("referral_stamp"))
		&"chapter_select":
			await _press_days_button(_days_button(String(Game.chapter(String(info.get("next", "gus"))).get("title", "Day 1"))))
		&"fitting_switch_on":
			var fit := _find_script_node("story/games/fitting.gd")
			var btn: Control = fit.get("_btn") as Control if fit != null else null
			if btn == null:
				_mouse_misses.append("fitting switch")
				return
			await _click(btn.get_global_rect().get_center())
		&"fitting_target":
			# (Day 14) each band's + or - button as many times as it needs, then Done
			var tm := _find_script_node("story/games/target_match.gd")
			if tm == null:
				_mouse_misses.append("target match")
				return
			for i in (tm.call("gains") as Array).size():
				var n := int(tm.call("presses_needed", i))
				var b: Control = tm.call("arrow_button", i, n > 0)
				for k in absi(n):
					await _click(b.get_global_rect().get_center())
			await _click((tm.call("done_button") as Control).get_global_rect().get_center())
		_:
			if info.get("mouse", null) is Dictionary:
				await _mouse_route(info["mouse"] as Dictionary)
				return
			_mouse_misses.append("beat " + String(beat))
			push_warning("AutoplayBot(mouse): no mouse route for beat " + String(beat))


## (Speech, §9.9) A beat that says how a player would solve it with the mouse:
## {click: anchor} | {drag: [from_anchor, to_anchor]} | {text: "visible text prefix"}.
func _mouse_route(m: Dictionary) -> void:
	if m.has("click"):
		await _click(_anchor_center(String(m["click"])))
	elif m.has("drag"):
		var d: Array = m["drag"]
		await _drag(_anchor_center(String(d[0])), _anchor_center(String(d[1])))
	elif m.has("text"):
		await _click_text(String(m["text"]))
	else:
		_mouse_misses.append("mouse route " + str(m))


func _mouse_results_continue() -> void:
	_want_title = true
	await _click_text(String(_summary.get("continue_text", "Back to the title")))
	var t0 := Game.clock
	while not _back_at_title and Game.clock - t0 < 10.0:
		await _frames(2)
	if not _back_at_title:
		_mouse_misses.append("title after results")


# ---------------------------------------------------------------- v3: the title's Days card

## Title menu -> "Days", like a player: click it (--mouse) or move the highlight with ui_down and
## press ui_accept (keys). The title then emits the chapter_select beat.
func _open_days() -> void:
	await _open_title_button("Days")


## A title menu button by its text (Days, Freestyle): a click (--mouse), or ui_down until it is
## highlighted and ui_accept (keys).
func _open_title_button(text: String) -> void:
	if _mouse:
		await _click_text(text)
		return
	for i in 8:
		var b := _find_visible_text(text) as Button
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
		await _wheel_into_view(b)
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


## (polish) A card below (or above) the Days grid's scroll window: roll the mouse wheel over the
## grid, like a player, until the whole card is in view.
func _wheel_into_view(b: Control) -> void:
	var sc: ScrollContainer = null
	var p := b.get_parent()
	while p != null:
		if p is ScrollContainer:
			sc = p
			break
		p = p.get_parent()
	if sc == null:
		return
	for i in 40:
		var vr := sc.get_global_rect()
		var br := b.get_global_rect()
		if br.position.y >= vr.position.y - 1.0 and br.end.y <= vr.end.y + 1.0:
			return
		var down := br.end.y > vr.end.y
		var at := vr.get_center()
		_mouse_move(at)
		for pressed: bool in [true, false]:
			var ev := InputEventMouseButton.new()
			var w := _to_window(at)
			ev.position = w
			ev.global_position = w
			ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
			ev.pressed = pressed
			ev.factor = 1.0
			Input.parse_input_event(ev)
		await _frames(2)
	_mouse_misses.append("days card out of view: " + String(b.get_meta("label", "")))


func _pick_via_days(info: Dictionary) -> void:
	var unlocked: Array = info.get("chapters", [])
	_days_report["unlocked"] = unlocked.duplicate()
	# --expect-days lists days that must be on the grid, in this order (others may sit between or
	# after them), so a new chapter doesn't break the check
	var expect := String(Game.cli_value("expect-days", ""))
	if expect != "":
		var at := 0
		for want: String in expect.split(",", false):
			while at < unlocked.size() and String(unlocked[at]) != want:
				at += 1
			if at >= unlocked.size():
				_days_problems.append("days: unlocked %s, expected %s among them, in order" % [str(unlocked), expect])
				break
			at += 1
	# (polish) every day is open: the suggested day wears the UP NEXT badge
	_days_report["suggested"] = String(info.get("suggested", ""))
	var want_sug := String(Game.cli_value("expect-suggested", ""))
	if want_sug != "" and String(info.get("suggested", "")) != want_sug:
		_days_problems.append("days: suggested %s, expected %s" % [info.get("suggested", ""), want_sug])
	if want_sug != "":
		var sc := _days_button(String(Game.chapter(want_sug).get("title", "?")))
		if sc == null or not bool(sc.get_meta("suggested", false)):
			_days_problems.append("days: the %s card has no UP NEXT badge" % want_sug)
	var pick := String(Game.cli_value("pick", info.get("next", "gus")))
	_days_report["picked"] = pick
	var card2 := _days_button(String(Game.chapter(pick).get("title", "?")))
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
	_check_speech(res, report, problems)
	# (Day 14, chapter gus_fit) the fitting tests no ears: its check is the match itself
	var fitting_day := String(_summary.get("chapter_id", Game.current_chapter_id)) == "gus_fit"
	if fitting_day:
		_check_fitting(res, report, problems)
	var ear_list: Array = [] if fitting_day else ["right", "left"]
	for ear: String in ear_list:
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
	problems.append_array(_case_problems)
	if _summary.has("freestyle_case"):
		report["freestyle"] = {"case": _summary["freestyle_case"], "medals": _summary.get("medals", {}),
			"visit_score": snappedf(float(_summary.get("visit_score", 0.0)), 0.1)}
		var want_fs := String(Game.cli_value("freestyle", ""))
		if want_fs != "" and String(_summary["freestyle_case"]) != want_fs:
			problems.append("freestyle: asked for %s but played %s" % [want_fs, _summary["freestyle_case"]])
	if _via_freestyle and not _freestyle_opened:
		problems.append("freestyle: the title's Freestyle button never opened")
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


## (Day 14, docs/FITTING.md) The fitting: every band of the right ear in the green, the style picked,
## and Hoot's left ear done.
func _check_fitting(res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var fit: Dictionary = res.get("fitting", {})
	if fit.is_empty():
		problems.append("fitting: no fitting results")
		return
	var errs := {}
	for b: Dictionary in fit.get("bands", []):
		errs[str(b.get("freq", 0))] = int(b.get("err", 99))
		if absi(int(b.get("err", 99))) > 5:
			problems.append("fitting: %s Hz left %+d dB off target" % [str(b.get("freq", 0)), int(b.get("err", 99))])
	if errs.size() != 3:
		problems.append("fitting: %d bands, expected 3" % errs.size())
	if String(fit.get("style", "")) != "ric_open":
		problems.append("fitting: style %s" % fit.get("style", ""))
	if not bool(fit.get("left_by_hoot", false)):
		problems.append("fitting: Hoot never did the left ear")
	report["fitting"] = {"errs": errs, "moves": fit.get("moves", 0), "par": fit.get("par", 0), "style_tries": fit.get("style_tries", 0),
		"overshoots": fit.get("overshoots", []), "medals": _summary.get("medals", {})}


## (v3) Bone / masked sheets: every stamp within 10 dB of the truth; on Day 2 the right ear must
## come out conductive with the referral red flag, with masked bone at 500-4k.
func _check_v3(res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var ears: Dictionary = res.get("ears", {})
	var sheets := {}
	var not_reached: Array[String] = []
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
				if bool(info.get("plateau_not_reached", false)):
					not_reached.append("%s %s %d" % [ear, key, f])
					if int(info["stored_db"]) <= int(info["true_db"]):
						continue  # (E9) a full window: the true threshold may be poorer, that is the "?"
				if bool(info.get("no_response", false)) and int(info["true_db"]) > int(info["stored_db"]):
					continue  # (Day 12) no response at the limit, and the truth lies past it: right
				if absi(int(info["stored_db"]) - int(info["true_db"])) > 10:
					problems.append("%s %s %d Hz off by more than 10 dB" % [ear, key, f])
			sheets["%s_%s" % [ear, key]] = t
	if not sheets.is_empty():
		report["sheets"] = sheets
		report["plateaus_found"] = _plateaus
		report["plateau_not_reached"] = not_reached
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
		# (v4) bone on the better (left) ear first, unmasked; the Ghost demo stores nothing
		var l: Dictionary = ears.get("left", {})
		for f: int in [500, 1000, 2000, 4000]:
			if not (l.get("bc", {}) as Dictionary).has(f):
				problems.append("left unmasked bone missing at %d Hz" % f)
		if not (r.get("bc", {}) as Dictionary).is_empty():
			problems.append("right unmasked bone was stamped (the Ghost demo must store nothing)")
		report["movies"] = _movies
		report["ghost_demo_tones"] = _demo_tones
		if not _phase_log.has(&"explainer"):
			problems.append("no explainer phase (Hoot's masking movie)")
		elif not _movies.has("masking") and not Game.cli_flag("keep-save"):
			problems.append("Hoot's masking movie never started on a fresh save")
		if not _phase_log.has(&"ghost_demo"):
			problems.append("no ghost_demo phase")
		if _demo_tones == 0:
			problems.append("the Ghost demo never played a tone")
		# masked air only where the rules ask for it with this air transducer (inserts: often none)
		var tr := &"inserts" if Game.has_upgrade("insert_earphones") else &"phones"
		var need := ClinicRules.masked_freqs_needed(res, "right", &"ac_masked", tr)
		report["air_transducer"] = String(tr)
		report["masked_air_needed"] = need
		for f: int in need:
			if not (r.get("ac_masked", {}) as Dictionary).has(f):
				problems.append("right masked air missing at %d Hz" % f)
		if need.is_empty() and not (r.get("ac_masked", {}) as Dictionary).is_empty():
			problems.append("right masked air stamped where no masking was needed")
	var case_id := String(Game.chapter(String(_summary.get("chapter_id", ""))).get("case", ""))
	if case_id != "":
		_check_conductive_case(case_id, res, report, problems)
		_check_dead_ear_case(case_id, res, report, problems)
		_check_dilemma_case(case_id, res, report, problems)
		# (cases, clinical review C12) Hoot's three case movies start on a fresh save (level_case.gd _movie)
		report["movies"] = _movies
		if not Game.cli_flag("keep-save"):
			for id: String in ["case_files", "tymp", "shapes"]:
				if not _movies.has(id):
					problems.append("Hoot's %s movie never started on a fresh save" % id)


## (cases) A conductive case (Days 10 and 11): the case ear comes out conductive with the air-bone
## gap red flag and masked bone at 500-4k, and masked air sits exactly where the rules ask on each
## ear (none for wax and fluid). The transducer is headphones while the canal is full of wax.
func _check_conductive_case(case_id: String, res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var c := CaseData.load_case(case_id)
	var ear := String((c.get("reveal", {}) as Dictionary).get("ear", "right"))
	var p := Game.load_patient(String(c.get("patient_id", ""))) as PatientProfile
	if (ear != "right" and ear != "left") or CaseData.truth_type(p, ear) != &"conductive":
		return
	var ears: Dictionary = res.get("ears", {})
	var e: Dictionary = ears.get(ear, {})
	report["case_ear_type"] = String(e.get("hearing_type", ""))
	if StringName(e.get("hearing_type", &"")) != &"conductive":
		problems.append("%s: the %s ear should be conductive, got %s" % [case_id, ear, str(e.get("hearing_type", ""))])
	if not bool(e.get("abg_red_flag", false)):
		problems.append("%s: no air-bone gap red flag on the %s ear" % [case_id, ear])
	for f: int in [500, 1000, 2000, 4000]:
		if not (e.get("bc_masked", {}) as Dictionary).has(f):
			problems.append("%s: %s masked bone missing at %d Hz" % [case_id, ear, f])
	var tr := CaseData.air_transducer(CaseData.canal_blocked(c))
	report["air_transducer"] = String(tr)
	for chk: String in ["right", "left"]:
		var need := ClinicRules.masked_freqs_needed(res, chk, &"ac_masked", tr)
		var stamped: Dictionary = (ears.get(chk, {}) as Dictionary).get("ac_masked", {})
		for f: int in need:
			if not stamped.has(f):
				problems.append("%s: %s masked air missing at %d Hz" % [case_id, chk, f])
		if need.is_empty() and not stamped.is_empty():
			problems.append("%s: %s masked air stamped where no masking was needed" % [case_id, chk])


## (cases, clinical review C10) A deaf case ear (Day 12): its unmasked air answered (the shadow, heard
## by the other ear), then masked bone at 500-4k and masked air at every routine frequency found no response.
func _check_dead_ear_case(case_id: String, res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var c := CaseData.load_case(case_id)
	var ear := String((c.get("reveal", {}) as Dictionary).get("ear", "right"))
	var p := Game.load_patient(String(c.get("patient_id", ""))) as PatientProfile
	if (ear != "right" and ear != "left") or not CaseData.dead_truth(p, ear):
		return
	var e: Dictionary = (res.get("ears", {}) as Dictionary).get(ear, {})
	report["case_ear_type"] = String(CaseData.measured_type(res, ear))
	report["shadow"] = CaseData.shadow_shows(res, p, ear)
	if not CaseData.shadow_shows(res, p, ear):
		problems.append("%s: no shadow on the %s ear (unmasked answers, masked no response)" % [case_id, ear])
	if not CaseData.no_response_shows(res, p, ear):
		problems.append("%s: the %s ear's masked marks are not all no response" % [case_id, ear])
	for f: int in [500, 1000, 2000, 4000]:
		if not (e.get("bc_masked", {}) as Dictionary).has(f):
			problems.append("%s: %s masked bone missing at %d Hz" % [case_id, ear, f])
	for f: int in ClinicRules.ROUTINE_FREQS:
		if not (e.get("ac_masked", {}) as Dictionary).has(f):
			problems.append("%s: %s masked air missing at %d Hz" % [case_id, ear, f])
	if CaseData.measured_type(res, ear) != &"sensorineural":
		problems.append("%s: the %s ear should read sensorineural, got %s" % [case_id, ear, CaseData.measured_type(res, ear)])


## (cases, clinical review C9) Gaps in both ears (Day 13): each ear reads conductive with the
## air-bone-gap red flag and masked bone at 500-4k; the purple ? ("plateau not reached") at 500 Hz and
## 1 kHz on each ear, and at 2k or 4k only after a missed beep in that run; masked air exactly where
## the rules ask from the stamps (headphone stamps keep the headphones' rule); the dilemma lines said;
## Hoot's inserts lent when none were owned, and not when they were.
func _check_dilemma_case(case_id: String, res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var c := CaseData.load_case(case_id)
	if not c.has("on_dilemma"):
		return
	var ears: Dictionary = res.get("ears", {})
	var tr := StringName(String(res.get("air_transducer", "phones")))
	var marks := {}
	for ear: String in ["right", "left"]:
		var e: Dictionary = ears.get(ear, {})
		if CaseData.measured_type(res, ear) != &"conductive":
			problems.append("%s: the %s ear should be conductive, got %s" % [case_id, ear, CaseData.measured_type(res, ear)])
		if not bool(e.get("abg_red_flag", false)):
			problems.append("%s: no air-bone gap red flag on the %s ear" % [case_id, ear])
		var bm: Dictionary = e.get("bc_masked", {})
		var got: Array[int] = []
		for f: int in [500, 1000, 2000, 4000]:
			if not bm.has(f):
				problems.append("%s: %s masked bone missing at %d Hz" % [case_id, ear, f])
				continue
			var info: Dictionary = bm[f]
			if not bool(info.get("plateau_not_reached", false)):
				continue
			got.append(f)
			var missed := false
			for r: Array in info.get("responses", []):
				if r.size() >= 2 and not bool(r[1]):
					missed = true
			if (f == 2000 or f == 4000) and not missed:
				problems.append("%s: %s %d Hz has room for a plateau, yet no plateau and no missed beep" % [case_id, ear, f])
		for f: int in [500, 1000]:
			if bm.has(f) and not got.has(f):
				problems.append("%s: no purple ? at %s %d Hz (no room for a plateau there)" % [case_id, ear, f])
		marks[ear] = got
		var need := ClinicRules.masked_freqs_needed(res, ear, &"ac_masked", tr)
		var stamped: Dictionary = e.get("ac_masked", {})
		for f: int in need:
			if not stamped.has(f):
				problems.append("%s: %s masked air missing at %d Hz" % [case_id, ear, f])
		for f: int in stamped:
			if not need.has(f):
				problems.append("%s: %s masked air at %d Hz where no masking was needed" % [case_id, ear, f])
	report["no_plateau"] = marks
	report["air_transducer"] = String(tr)
	var lent := bool(Game.get_visit_flag("lent_inserts", false))
	report["lent_inserts"] = lent
	if not bool(Game.get_visit_flag("dilemma_told", false)):
		problems.append("%s: the dilemma lines never played" % case_id)
	if bool(c.get("lend_inserts", false)):
		var owned := Game.has_upgrade("insert_earphones")
		if owned and lent:
			problems.append("%s: inserts lent to a player who owns them" % case_id)
		if not owned and (not lent or tr != &"inserts"):
			problems.append("%s: the inserts were never lent" % case_id)


func _fail(code: int, why: String) -> void:
	if _finished:
		return
	_finished = true
	print("AUTOPLAY_FAILED code=%d: %s" % [code, why])
	for m in _errors.messages:
		print("SCRIPT ERROR: ", m)
	await _shot("stuck_" + String(_phase))
	Events.quit_requested.emit(code)


## (Speech, §9.9) Every stored speech measurement within 10 dB of the truth; on a speech day both
## ears have an SRT; on Day 3 (Mike) the PTA/SRT agreement comes out poor in both ears, and a
## fresh save starts Hoot's spondee movie.
func _check_speech(res: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var sp: Dictionary = res.get("speech", {})
	var chapter := String(_summary.get("chapter_id", Game.current_chapter_id))
	var speech_day := chapter == "mike"
	# (Days 4-5) §9.22: Days 4 and 5 are speech days too
	speech_day = speech_day or chapter in ["nora", "marco"]
	if sp.is_empty():
		if speech_day:
			problems.append("no speech results on a speech day")
		return
	var out := {}
	for t: String in ["srt", "wrs", "sin"]:
		var per: Dictionary = sp.get(t, {})
		for e: Variant in per:
			var sh: Dictionary = per[e]
			out["%s_%s" % [t, e]] = [sh.get("stored_db", -99), sh.get("true_db", -99), sh.get("agreement", ""), sh.get("words", 0), sh.get("par", 0)]
			if absi(int(sh.get("stored_db", -99)) - int(sh.get("true_db", 99))) > 10:
				problems.append("%s %s off by more than 10 dB" % [t, e])
	report["speech"] = out
	report["speech_scores"] = {"accuracy": snappedf(float(sp.get("accuracy", 0.0)), 0.001), "technique": snappedf(float(sp.get("technique", 0.0)), 0.001),
		"efficiency": snappedf(float(sp.get("efficiency", 0.0)), 0.001)}
	if chapter == "mike":
		var srt: Dictionary = sp.get("srt", {})
		for e: String in ["right", "left"]:
			if not srt.has(e):
				problems.append("Day 3: no %s SRT" % e)
			elif StringName(String((srt[e] as Dictionary).get("agreement", ""))) != &"poor":
				problems.append("Day 3: %s PTA/SRT agreement is not poor" % e)
		# (clinical review S7) Hoot's spondee movie starts on a fresh save (level_mike._movie, contract §9.20)
		report["movies"] = _movies
		if not _movies.has("srt_ladder") and not Game.cli_flag("keep-save"):
			problems.append("Day 3: Hoot's srt_ladder movie never started on a fresh save")
	# (Days 4-5) §9.22: every counted word list on any day with a word sheet; Day 4's own checks
	if not (sp.get("wrs", {}) as Dictionary).is_empty():
		_check_wrs_lists(sp, report, problems)
	if chapter == "nora":
		_check_nora(res, sp, problems)
		# (Days 4-5) Hoot's word movie starts on a fresh save (level_nora._movie, contract §9.20)
		report["movies"] = _movies
		if not _movies.has("letter_choir") and not Game.cli_flag("keep-save"):
			problems.append("Day 4: Hoot's letter_choir movie never started on a fresh save")
	# (Days 4-5) §9.22.4: every party list on any day with a party sheet; Day 5's own checks
	if not (sp.get("sin", {}) as Dictionary).is_empty():
		_check_sin_lists(sp, report, problems)
	if chapter == "marco":
		_check_marco(sp, problems)
		# (Days 4-5) Hoot's party movie starts on a fresh save (level_marco._movie, contract §9.20)
		report["movies"] = _movies
		if not _movies.has("party_noise") and not Game.cli_flag("keep-save"):
			problems.append("Day 5: Hoot's party_noise movie never started on a fresh save")


## (Days 4-5) §9.22.3: every counted list the player scored lands near its deal, matches the truth
## when nothing was misscored, started at a fair level and was masked exactly when it had to be.
func _check_wrs_lists(sp: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var wrs: Dictionary = sp.get("wrs", {})
	var rows: Array[String] = []
	for e: String in ["right", "left"]:
		if not wrs.has(e):
			continue
		for v: Variant in ((wrs[e] as Dictionary).get("lists", []) as Array):
			var l: Dictionary = v
			var id := String(l.get("list_id", ""))
			rows.append("%s:%s:%d:%d:%d%s" % [e, id, int(l.get("level_db", 0)), int(l.get("mask_db", -1)), int(l.get("pct", -1)),
				"" if bool(l.get("counts", false)) else ":void"])
			if not bool(l.get("counts", false)) or int(l.get("player_words", 0)) <= 0:
				continue
			if absi(int(l.get("pct", 0)) - int(l.get("expected_pct", 0))) > 8:
				problems.append("wrs %s %s: %d%% is more than 8 from the expected %d%%" % [e, id, int(l.get("pct", 0)), int(l.get("expected_pct", 0))])
			if int(l.get("matches", 0)) == int(l.get("player_words", 0)) and int(l.get("pct", 0)) != int(l.get("true_pct", 0)):
				problems.append("wrs %s %s: no misscore, yet %d%% is not the true %d%%" % [e, id, int(l.get("pct", 0)), int(l.get("true_pct", 0))])
			if not bool(l.get("start_ok", false)):
				problems.append("wrs %s %s: a counted list started off the comfortable level" % [e, id])
			if bool(l.get("masked", false)) != bool(l.get("masking_needed", false)):
				problems.append("wrs %s %s: masked %s, needed %s" % [e, id, str(l.get("masked", false)), str(l.get("masking_needed", false))])
	report["wrs_lists"] = rows


## (Days 4-5) §9.22.4: every party list has its six sentences and a total that is their sum, no
## practice sentence is stored, and a two-list sheet lands within 3 dB of the truth. Adds
## report.sin_lists (slot:list_id:level:total, with :hoot on a list Hoot scored all of).
func _check_sin_lists(sp: Dictionary, report: Dictionary, problems: PackedStringArray) -> void:
	var sin: Dictionary = sp.get("sin", {})
	var rows: Array[String] = []
	for slot: Variant in sin:
		var sh: Dictionary = sin[slot]
		for v: Variant in (sh.get("lists", []) as Array):
			var l: Dictionary = v
			var id := String(l.get("list_id", ""))
			rows.append("%s:%s:%d:%d%s" % [slot, id, int(l.get("level_db", 0)), int(l.get("total", -1)),
				":hoot" if int(l.get("player_sentences", 0)) == 0 else ""])
			var sentences: Array = l.get("sentences", [])
			if sentences.size() != 6:
				problems.append("sin %s %s: %d sentences, expected 6" % [slot, id, sentences.size()])
			var sum := 0
			for sv: Variant in sentences:
				var st: Dictionary = sv
				sum += int(st.get("count", 0))
				if bool(st.get("practice", false)) or String(st.get("item_id", "")).begins_with(SpeechRules.SIN_PRACTICE_LIST):
					problems.append("sin %s %s: a practice sentence was stored" % [slot, id])
			if sum != int(l.get("total", -1)):
				problems.append("sin %s %s: total %d is not the sentences' %d" % [slot, id, int(l.get("total", -1)), sum])
		if int(sh.get("lists_done", 0)) == 2 and absf(float(sh.get("snr_loss", 0.0)) - float(sh.get("true_loss", 0.0))) > 3.0:
			problems.append("sin %s: SNR loss %.1f is more than 3 dB from the true %.1f" % [slot, float(sh.get("snr_loss", 0.0)), float(sh.get("true_loss", 0.0))])
	report["sin_lists"] = rows


## (Days 4-5) §9.22.6, Day 5 (Marco): Hoot's SRTs and words in quiet, right first, both good; three
## party sheets of two lists each on six different lists; a moderate unaided band, aided sheets at the
## chatting level with no band; FOCUS helps (real, or flagged as unsure with a positive benefit); and
## no "beeps" or "spondees" on the paper.
func _check_marco(sp: Dictionary, problems: PackedStringArray) -> void:
	for t: String in ["srt", "wrs"]:
		var per: Dictionary = sp.get(t, {})
		for e: String in ["right", "left"]:
			if not per.has(e):
				problems.append("Day 5: no %s %s" % [e, t])
			elif not bool((per[e] as Dictionary).get("by_hoot", false)):
				problems.append("Day 5: the %s %s is not Hoot's" % [e, t])
		if per.has("right") and per.has("left") and int((per["right"] as Dictionary).get("seq", 0)) > int((per["left"] as Dictionary).get("seq", 0)):
			problems.append("Day 5: the left %s came before the right" % t)
	var wrs: Dictionary = sp.get("wrs", {})
	for e: String in ["right", "left"]:
		if wrs.has(e) and not [&"excellent", &"good"].has(StringName(String((wrs[e] as Dictionary).get("band", "")))):
			problems.append("Day 5: %s words in quiet are %s, expected excellent or good" % [e, str((wrs[e] as Dictionary).get("band", ""))])
	var sin: Dictionary = sp.get("sin", {})
	var ids: Array[String] = []
	for slot: String in ["both", "aided_omni", "aided_directional"]:
		if not sin.has(slot):
			problems.append("Day 5: no %s party sheet" % slot)
			continue
		var sh: Dictionary = sin[slot]
		if int(sh.get("lists_done", 0)) != 2:
			problems.append("Day 5: %s has %d lists, expected 2" % [slot, int(sh.get("lists_done", 0))])
		for v: Variant in (sh.get("lists", []) as Array):
			var id := String((v as Dictionary).get("list_id", ""))
			if ids.has(id):
				problems.append("Day 5: %s was played twice" % id)
			ids.append(id)
			if slot != "both" and int((v as Dictionary).get("level_db", 0)) != SpeechRules.SIN_AIDED_DB:
				problems.append("Day 5: %s %s at %d dB, expected %d" % [slot, id, int((v as Dictionary).get("level_db", 0)), SpeechRules.SIN_AIDED_DB])
		if slot == "both" and StringName(String(sh.get("band", ""))) != &"moderate":
			problems.append("Day 5: the unaided band is %s, expected moderate" % str(sh.get("band", "")))
		if slot != "both" and String(sh.get("band", "")) != "":
			problems.append("Day 5: the %s sheet has a band (%s)" % [slot, str(sh.get("band", ""))])
	var focus: Dictionary = sin.get("aided_directional", {})
	if not focus.is_empty() and not bool(focus.get("real_change", false)) \
			and not (bool(Game.get_visit_flag("benefit_unsure", false)) and float(focus.get("benefit_db", 0.0)) > 0.0):
		problems.append("Day 5: FOCUS is neither a real change nor a flagged positive benefit (%.1f dB)" % float(focus.get("benefit_db", 0.0)))
	if _paper_text.is_empty():
		problems.append("Day 5: the paper's words were never read")
	for t: String in _paper_text:
		var low := t.to_lower()
		if low.contains("beeps") or low.contains("spondee"):
			problems.append("Day 5: the paper says \"%s\"" % t)
			break


## (Days 4-5) Every visible Label's and Button's text under `root` (the paper's words, for Day 5).
func _visible_texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if root is Control and not (root as Control).is_visible_in_tree():
		return out
	if root is Label:
		out.append((root as Label).text)
	elif root is Button:
		out.append((root as Button).text)
	for c in root.get_children():
		out.append_array(_visible_texts(c))
	return out


## (Days 4-5) §9.22.5, Day 4 (Nora): better ear first, the lists in play order, a clear right ear, a
## poor, asymmetric left ear below its prediction that rolls over on a louder list masked by the
## formula, and a referral.
func _check_nora(res: Dictionary, sp: Dictionary, problems: PackedStringArray) -> void:
	var wrs: Dictionary = sp.get("wrs", {})
	if not wrs.has("right") or not wrs.has("left"):
		problems.append("Day 4: no word score on the %s ear" % ("right" if not wrs.has("right") else "left"))
		return
	var r: Dictionary = wrs["right"]
	var l: Dictionary = wrs["left"]
	var r_lists: Array = r.get("lists", [])
	var l_lists: Array = l.get("lists", [])
	for v: Variant in l_lists:
		if int(r.get("seq", 0)) >= int((v as Dictionary).get("seq", 0)):
			problems.append("Day 4: a left list came before the right ear's (better ear first)")
			break
	var ids: Array[String] = []
	for v: Variant in r_lists:
		ids.append("R " + String((v as Dictionary).get("list_id", "")))
	for v: Variant in l_lists:
		ids.append("L " + String((v as Dictionary).get("list_id", "")))
	var want: Array[String] = ["R " + SpeechRules.WRS_LISTS[0]]
	for i in l_lists.size():
		want.append("L " + (SpeechRules.WRS_LISTS[1 + i] if 1 + i < SpeechRules.WRS_LISTS.size() else "?"))
	if r_lists.size() != 1 or ids != want:
		problems.append("Day 4: lists %s, expected %s (play order)" % [str(ids), str(want)])
	if int(r.get("pb_max", -1)) < 88 or not [&"excellent", &"good"].has(StringName(String(r.get("band", "")))):
		problems.append("Day 4: right ear %d%% (%s), expected 88%% or more, excellent or good" % [int(r.get("pb_max", -1)), str(r.get("band", ""))])
	var comfy := {}
	var louder := {}
	for v: Variant in l_lists:
		var li: Dictionary = v
		if not bool(li.get("counts", false)):
			continue
		if int(li.get("louder_than", 0)) > 0:
			louder = li
		else:
			comfy = li
	if comfy.is_empty() or int(comfy.get("pct", 100)) > 64:
		problems.append("Day 4: the left ear's comfortable list is %s, expected 64%% or less" % ("missing" if comfy.is_empty() else "%d%%" % int(comfy["pct"])))
	for k: String in ["best_final", "below_predicted", "asymmetric", "rollover"]:
		if not bool(l.get(k, false)):
			problems.append("Day 4: the left word sheet's %s is not true" % k)
	if louder.is_empty():
		problems.append("Day 4: no counted louder list on the left")
	else:
		var best := INF
		var bone := SpeechRules.ear_best_bone(res, "left")
		for f: Variant in bone:
			best = minf(best, float(bone[f]))
		var want_db := SpeechRules.wrs_mask_level(int(louder.get("level_db", 0)), best if best != INF else NAN,
			StringName(String(l.get("transducer", "phones"))), SpeechRules.nontest_largest_abg(res, "left"))
		var got := int(louder.get("mask_db", -1))
		if got != want_db or got < 65 or got > 75:
			problems.append("Day 4: the louder list's noise is %d dB, expected %d (65-75)" % [got, want_db])
	if StringName(String((sp.get("wrs_summary", {}) as Dictionary).get("referral", ""))) != &"refer":
		problems.append("Day 4: the word scores do not call for a referral")
	var decision := String(Game.get_visit_flag("decision", ""))
	if decision != "" and decision != "refer":
		problems.append("Day 4: the visit's decision is %s, not refer" % decision)
