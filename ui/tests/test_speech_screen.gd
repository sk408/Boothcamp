extends TestCase
## (Speech) The SPEECH screen (CONTRACTS.md §9.7): API and state keys, never the AudiOtron, a full
## coached SRT on Mike by keys and by mouse clicks on the anchors, the awaiting_input(&"speech")
## beat and its solver (and a stale solver), Hoot's x8 turn (time scale restored), Hoot's recheck on
## a fresh session, the tell, the low-start praise and the coached ear's STORE guard, the feedback
## after a store (no praise off the bracket), the level locked while a word plays, and the swapped
## key style.

const SCREEN := "res://ui/speech/speech_screen.tscn"
const SCRATCH_SAVE := "user://test_speech_screen_save.json"
const STATE_KEYS: Array[String] = ["test", "ear", "db", "pta", "recommended_start", "candidate_db", "trail", "awaiting_score", "current",
	"mask_on", "masking_needed", "done", "combo", "points", "scoring", "accepting_input", "talking", "answer_shown", "hoot_turn",
	"coached", "patient_id", "quick_visit"]
## The tests run the clock fast (game time); every wait below is bounded in real time.
const TEST_SPEED := 8.0

var _saved_path := ""
var _saved_scale := 1.0
var _saved_quick := true
var _saved_hints := true
var _saved_rng_state := 0
## The screen seeds each patient from Game.rng: a fixed seed per test keeps the SRTs (and the
## +/- 5 dB checks below) the same on every run.
const RNG_SEED := 1234


func before_each() -> void:
	super()
	_saved_path = Game.save_path
	Game.save_path = SCRATCH_SAVE
	_saved_scale = Engine.time_scale
	_saved_quick = bool(Game.settings.get("quick_visit", true))
	_saved_hints = bool(Game.settings.get("show_key_hints", true))
	Game.begin_visit("mike")
	_saved_rng_state = Game.rng.state
	Game.rng.seed = RNG_SEED
	Engine.time_scale = TEST_SPEED


func after_each() -> void:
	# take the screens out of the tree first: a screen in Hoot's x8 turn restores the time scale it
	# saved as it leaves, and that must not land after ours
	for n: Node in tree.get_nodes_in_group("speech_screen"):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
			n.queue_free()
	Engine.time_scale = _saved_scale
	Game.rng.state = _saved_rng_state
	Game.set_key_style("otosuite")
	Game.set_setting("quick_visit", _saved_quick)
	Game.set_setting("show_key_hints", _saved_hints)
	Game.save_path = _saved_path
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Hoot.clear()
	super()


func _screen() -> SpeechScreen:
	var s := (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	add_node(s)
	return s


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


func _plan(extra: Dictionary = {}) -> Dictionary:
	var p := {"test": "srt", "tones": SpeechSession.tone_results_from(_mike())}
	p.merge(extra, true)
	return p


func _wait_until(cond: Callable, max_real_s: float = 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_real_s * 1000.0):
			return false
		await wait_frames(1)
	return true


## The screen waits for the player (no word playing, no answer pending), or the ear is done.
static func _player_turn(s: SpeechScreen) -> bool:
	var st := s.get_state()
	if bool(st["finishing"]):
		return true
	return bool(st["accepting_input"]) and not bool(st["talking"]) and not bool(st["listening"]) \
		and (not bool(st["awaiting_score"]) or bool(st["answer_shown"]))


## Canvas position -> window position (the headless window is tiny; the canvas is stretched).
func _to_window(p: Vector2) -> Vector2:
	return tree.root.get_final_transform() * p


func _click_anchor(id: String) -> void:
	var r := Hoot.anchor_screen_rect(id)
	var at := _to_window(r.get_center())
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await wait_frames(2)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)
		await wait_frames(2)


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


## Play one ear by the textbook: every move is session.recommended_action(), sent by keys
## (tap_action) or by mouse clicks on the button's anchor. Returns the results from test_finished.
func _play_ear(s: SpeechScreen, by_mouse: bool) -> Dictionary:
	var finished: Array = []
	var cb := func(r: Dictionary) -> void: finished.append(r)
	s.test_finished.connect(cb)
	var moves := 0
	while finished.is_empty() and moves < 200:
		var ok: bool = await _wait_until(_player_turn.bind(s), 20.0)
		assert_true(ok, "the screen comes back to the player")
		if not ok:
			break
		if bool(s.get_state()["finishing"]):
			var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 20.0)
			assert_true(done, "test_finished after the store")
			break
		var act: StringName = s.session.recommended_action()["action"]
		assert_true(SpeechScreen.ACTION_INPUTS.has(act), "a real move: %s" % act)
		if not SpeechScreen.ACTION_INPUTS.has(act):
			break
		if by_mouse:
			await _click_anchor(SpeechScreen.ACTION_BUTTONS[act])
		else:
			await tap_action(SpeechScreen.ACTION_INPUTS[act])
		moves += 1
	s.test_finished.disconnect(cb)
	return finished[0] if not finished.is_empty() else {}


# ---------------------------------------------------------------- API

func test_api_and_state_keys() -> void:
	var s := _screen()
	assert_eq(s.layer, 20)
	for m: String in ["start_test", "get_state", "get_results", "demo_start"]:
		assert_has_method(s, m)
	assert_has_signal(s, "test_finished")
	assert_true(s.is_in_group("speech_screen"))
	assert_eq(s.get_results(), {}, "no results before the first ear")
	var st0 := s.get_state()
	for k: String in STATE_KEYS:
		assert_has(st0, k, "state before start_test: " + k)
	var started: Array = []
	var cb := func(pid: String, ear: String, test: StringName, coached: bool) -> void: started.append([pid, ear, test, coached])
	Events.speech_started.connect(cb)
	s.start_test(_mike(), "right", true, _plan())
	Events.speech_started.disconnect(cb)
	assert_eq(started.size(), 1)
	if started.size() == 1:
		assert_eq(started[0], ["mike", "right", &"srt", true])
	var st := s.get_state()
	for k: String in STATE_KEYS:
		assert_has(st, k)
	assert_eq(st["patient_id"], "mike")
	assert_eq(st["ear"], "right")
	assert_true(bool(st["coached"]))
	assert_true(bool(st["accepting_input"]))
	assert_false(bool(st["talking"]))
	assert_eq(int(st["db"]), 70, "the dial starts at the PTA rounded to 5")
	assert_eq(int(st["recommended_start"]), 85, "start = PTA + 15")
	await wait_frames(3)
	for a: String in SpeechScreen.ANCHORS:
		assert_true(Hoot.has_anchor(a), "anchor " + a)


func test_anchors_on_screen_and_clear_of_hoot() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", true, _plan())
	await wait_frames(3)
	var vp := Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)
	for a: String in SpeechScreen.ANCHORS:
		var r := Hoot.anchor_screen_rect(a)
		assert_true(r.size.x > 20.0 and r.size.y > 20.0, "anchor %s has a size" % a)
		assert_true(vp.encloses(r), "anchor %s is on screen: %s" % [a, r])
	# Hoot's bubble sits on its perch, never over a button (or the bot's clicks would hit it)
	var hint := Hoot.bubble_rect_hint
	assert_true(hint.size.x > 200.0, "the bubble hint is set")
	for id: String in SpeechScreen.ACTION_BUTTONS.values():
		assert_false(hint.intersects(Hoot.anchor_screen_rect(id)), "bubble hint clear of " + id)
	s.queue_free()
	await wait_frames(2)
	assert_eq(Hoot.bubble_rect_hint, Rect2(), "the bubble hint is cleared on exit")
	assert_false(Hoot.has_anchor("speech_present_button"), "anchors are dropped on exit")


# ---------------------------------------------------------------- a full ear

func test_coached_right_srt_by_keys() -> void:
	var tone_started := [false]
	var cb_tone := func(_p: String, _e: String, _c: bool) -> void: tone_started[0] = true
	Events.audiometry_started.connect(cb_tone)
	var counts := {"presented": 0, "response": 0, "scored": 0, "stored": 0, "finished": 0, "lines": 0}
	var cb_p := func(_e: String, _t: StringName, _d: int, _i: Dictionary) -> void: counts["presented"] += 1
	var cb_r := func(_e: String, _t: StringName, _d: int, _a: Dictionary) -> void: counts["response"] += 1
	var cb_s := func(_e: String, _t: StringName, _d: int, _c: bool, right: bool) -> void:
		counts["scored"] += 1
		assert_true(right, "the textbook scores what he said")
	var cb_st := func(_e: String, _t: StringName, _sh: Dictionary) -> void: counts["stored"] += 1
	var cb_f := func(_r: Dictionary) -> void: counts["finished"] += 1
	var cb_l := func(who: String, _t: String) -> void:
		if who == "Mike":
			counts["lines"] += 1
	Events.speech_presented.connect(cb_p)
	Events.speech_response.connect(cb_r)
	Events.speech_scored.connect(cb_s)
	Events.speech_stored.connect(cb_st)
	Events.speech_finished.connect(cb_f)
	Events.dialogue_line.connect(cb_l)
	var s := _screen()
	s.start_test(_mike(), "right", true, _plan())
	var res: Dictionary = await _play_ear(s, false)
	for pair: Array in [[Events.speech_presented, cb_p], [Events.speech_response, cb_r], [Events.speech_scored, cb_s],
			[Events.speech_stored, cb_st], [Events.speech_finished, cb_f], [Events.dialogue_line, cb_l], [Events.audiometry_started, cb_tone]]:
		(pair[0] as Signal).disconnect(pair[1])
	assert_false(res.is_empty(), "test_finished fired")
	if res.is_empty():
		return
	assert_true(Stage.audiometer == null, "never registered as the AudiOtron")
	assert_false(tone_started[0], "never emits audiometry_started")
	assert_has(res, "speech")
	assert_has(res, "ears", "merged with the tone results")
	var sheet: Dictionary = ((res["speech"] as Dictionary)["srt"] as Dictionary).get("right", {})
	assert_false(sheet.is_empty(), "a right SRT sheet")
	assert_near(float(sheet.get("stored_db", -99)), 30.0, 5.0, "SRT within 5 dB of Mike's true 30")
	assert_eq(StringName(String(sheet.get("agreement", ""))), &"poor", "PTA 72 vs SRT 30: poor agreement")
	assert_false(bool(sheet.get("by_hoot", true)))
	assert_eq(int(sheet.get("start_db", 0)), 85, "the coach starts at PTA + 15")
	assert_true((sheet.get("errors", []) as Array).is_empty(), "no technique errors on the textbook path")
	assert_eq(counts["presented"], counts["response"])
	assert_eq(counts["presented"], counts["scored"])
	assert_eq(counts["stored"], 1)
	assert_eq(counts["finished"], 1)
	assert_true(counts["presented"] >= 8, "a real descent: %d words" % counts["presented"])
	assert_true(counts["lines"] >= 1, "Mike's answers reach dialogue_line")
	var st := s.get_state()
	assert_true(bool(st["done"]))
	assert_false(bool(st["accepting_input"]), "input stops after the store")
	assert_eq(res, s.get_results())


func test_coached_right_srt_by_mouse() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", true, _plan())
	await wait_frames(3)
	var res: Dictionary = await _play_ear(s, true)
	assert_false(res.is_empty(), "mouse clicks on the anchors finish the ear")
	if res.is_empty():
		return
	var sheet: Dictionary = ((res["speech"] as Dictionary)["srt"] as Dictionary).get("right", {})
	assert_near(float(sheet.get("stored_db", -99)), 30.0, 5.0)


# ---------------------------------------------------------------- the blocking beat

func test_beat_solvers_finish_an_ear() -> void:
	var beats: Array = []
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"speech":
			beats.append([info, solver])
	Events.awaiting_input.connect(cb)
	var finished: Array = []
	var s := _screen()
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	s.start_test(_mike(), "left", false, _plan())
	var got: bool = await _wait_until(func() -> bool: return not beats.is_empty(), 5.0)
	assert_true(got, "a speech beat when the screen waits")
	if got:
		var info: Dictionary = beats[0][0]
		for k: String in ["ear", "test", "action", "mouse"]:
			assert_has(info, k)
		assert_eq(info["ear"], "left")
		assert_eq(info["test"], "srt")
		assert_eq(info["action"], "louder", "Mike's left dial starts at 75: up to the PTA + 15")
		var click := String((info["mouse"] as Dictionary).get("click", ""))
		assert_eq(click, "speech_louder_button")
		assert_true(Hoot.has_anchor(click))
		assert_true((beats[0][1] as Callable).is_valid())
	var used := 0
	var calls := 0
	var t0 := Time.get_ticks_msec()
	while finished.is_empty() and Time.get_ticks_msec() - t0 < 30000:
		if beats.size() > used:
			used = beats.size()
			(beats[used - 1][1] as Callable).call()
			calls += 1
		await wait_frames(1)
	Events.awaiting_input.disconnect(cb)
	assert_false(finished.is_empty(), "calling the solvers finishes the ear")
	if finished.is_empty():
		return
	var sheet: Dictionary = (((finished[0] as Dictionary)["speech"] as Dictionary)["srt"] as Dictionary).get("left", {})
	assert_near(float(sheet.get("stored_db", -99)), 30.0, 5.0)
	assert_eq(StringName(String(sheet.get("agreement", ""))), &"poor")
	# one beat per idle point: every beat was answered by its own solver call (none doubled up)
	assert_eq(beats.size(), calls, "one beat per idle point")
	var actions := {}
	for b: Array in beats:
		actions[String((b[0] as Dictionary)["action"])] = true
	for a: String in ["louder", "present", "softer", "store"]:
		assert_has(actions, a)
	assert_true(actions.has("score_correct") or actions.has("score_missed"))


func test_stale_solver_is_a_noop() -> void:
	var beats: Array = []
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"speech":
			beats.append([info, solver])
	Events.awaiting_input.connect(cb)
	var s := _screen()
	s.start_test(_mike(), "right", true, _plan())
	var got: bool = await _wait_until(func() -> bool: return not beats.is_empty(), 5.0)
	assert_true(got)
	if not got:
		Events.awaiting_input.disconnect(cb)
		return
	var first: Callable = beats[0][1]   # never called: the player moves on by key instead
	var db0 := s.session.db
	await tap_action(&"louder")
	var moved: bool = await _wait_until(func() -> bool: return s.session.db == db0 + 5 and beats.size() >= 2, 5.0)
	assert_true(moved, "the key pressed LOUDER and a new beat came")
	var trials := s.session.trials_for().size()
	first.call()   # stale: the state moved on since it was handed out
	await wait_frames(6)
	assert_eq(s.session.db, db0 + 5, "a stale solver does nothing")
	assert_eq(s.session.trials_for().size(), trials, "and presents nothing")
	var second: Callable = beats[beats.size() - 1][1]
	second.call()
	second.call()  # the same solver twice: one press
	await wait_frames(6)
	assert_eq(s.session.db, db0 + 10)
	Events.awaiting_input.disconnect(cb)


# ---------------------------------------------------------------- Hoot's turn

func test_hoot_turn_runs_the_left_ear() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	var beats: Array = []
	var cb := func(beat: StringName, _info: Dictionary, _solver: Callable) -> void:
		if beat == &"speech":
			beats.append(beat)
	Events.awaiting_input.connect(cb)
	var finished: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	var base := Engine.time_scale
	s.start_test(_mike(), "left", false, _plan({"hoot_turn_after": 0}))
	var on: bool = await _wait_until(func() -> bool: return bool(s.get_state()["hoot_turn"]), 5.0)
	assert_true(on, "Hoot takes the ear at once (hoot_turn_after 0)")
	assert_false(s.session.scoring, "his words never count")
	var fast: bool = await _wait_until(func() -> bool: return is_equal_approx(Engine.time_scale, base * SpeechScreen.HOOT_SPEED), 5.0)
	assert_true(fast, "x8 during his turn")
	var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 30.0)
	Events.awaiting_input.disconnect(cb)
	assert_true(done, "Hoot finishes the ear")
	assert_eq(Engine.time_scale, base, "time scale restored exactly")
	assert_eq(beats.size(), 0, "no player beats during Hoot's turn")
	if not done:
		return
	var sheet: Dictionary = (((finished[0] as Dictionary)["speech"] as Dictionary)["srt"] as Dictionary).get("left", {})
	assert_true(bool(sheet.get("by_hoot", false)), "the sheet is Hoot's")
	assert_near(float(sheet.get("stored_db", -99)), 30.0, 5.0, "Hoot follows the textbook too")
	assert_false(bool(s.get_state()["hoot_turn"]))
	assert_true(s.session.scoring, "scoring back on")


func test_hoot_turn_after_two_words() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	var finished: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	var base := Engine.time_scale
	s.start_test(_mike(), "left", false, _plan({"hoot_turn_after": 2}))
	var words := 0
	while words < 2:
		var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
		assert_true(ok)
		if not ok:
			return
		assert_false(bool(s.get_state()["hoot_turn"]), "still the player's ear")
		var act: StringName = s.session.recommended_action()["action"]
		await tap_action(SpeechScreen.ACTION_INPUTS[act])
		if act == &"score_correct" or act == &"score_missed":
			words += 1
	await wait_frames(2)
	assert_true(bool(s.get_state()["hoot_turn"]), "Hoot takes over after two scored words")
	var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 30.0)
	assert_true(done)
	assert_eq(Engine.time_scale, base)
	if done:
		var sheet: Dictionary = (((finished[0] as Dictionary)["speech"] as Dictionary)["srt"] as Dictionary).get("left", {})
		assert_true(bool(sheet.get("by_hoot", false)))
		assert_eq(int(sheet.get("strokes", -1)), 2, "the player's two words")


## Plan hoot_turn_after_up (Day 3's solo left ear): the player keeps the ear through a miss and
## the word stepped up after it, then Hoot finishes the bracket; the count stays the cap.
func test_hoot_turn_after_the_step_up() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	s.start_test(_mike(), "left", false, _plan({"hoot_turn_after": 12, "hoot_turn_after_up": true, "level": 40}))
	# the player's own scores drive it: missed at 40, missed again at 40 (no step up yet), up 5, then any score
	for move: StringName in [&"present_tone", &"speech_incorrect", &"present_tone", &"speech_incorrect", &"louder", &"present_tone"]:
		var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
		assert_true(ok)
		if not ok:
			return
		assert_false(bool(s.get_state()["hoot_turn"]), "still the player's ear before the step-up word is scored (%s)" % move)
		await tap_action(move)
	var shown: bool = await _wait_until(_player_turn.bind(s), 10.0)
	assert_true(shown)
	assert_eq(int(s.get_state()["db"]), 45, "the word stepped up 5")
	await tap_action(&"speech_correct")
	await wait_frames(2)
	assert_true(bool(s.get_state()["hoot_turn"]), "Hoot takes over once the step-up word is scored")
	assert_eq(int(s.get("_player_words")), 3, "after three of the player's words, well under the cap of 12")


func test_hoot_turn_stops_when_the_screen_leaves() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	var base := Engine.time_scale
	s.start_test(_mike(), "left", false, _plan({"hoot_turn_after": 0}))
	var fast: bool = await _wait_until(func() -> bool: return Engine.time_scale > base * 2.0, 5.0)
	assert_true(fast)
	s.get_parent().remove_child(s)
	assert_eq(Engine.time_scale, base, "leaving the tree restores the time scale")
	s.free()
	await wait_frames(30)
	assert_eq(Engine.time_scale, base)


func test_fresh_session_recheck_keeps_the_player_session() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	var finished: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	s.start_test(_mike(), "right", false, _plan({"hoot_turn_after": 0}))
	var done: bool = await _wait_until(func() -> bool: return finished.size() == 1, 30.0)
	assert_true(done, "the first right ear is stored")
	if not done:
		return
	var mine := s.session
	s.start_test(_mike(), "right", false, _plan({"hoot_turn_after": 0, "fresh_session": true}))
	assert_ne(s.session, mine, "the recheck gets a fresh session")
	assert_false(s.session.is_done("right"), "and starts the ear from scratch")
	done = await _wait_until(func() -> bool: return finished.size() == 2, 30.0)
	assert_true(done, "Hoot finishes the recheck")
	if not done:
		return
	var re: Dictionary = ((finished[1] as Dictionary)["speech"] as Dictionary)["srt"]
	assert_true(bool((re.get("right", {}) as Dictionary).get("by_hoot", false)), "the recheck is Hoot's")
	assert_false(re.has("left"))
	s.start_test(_mike(), "left", false, _plan({"hoot_turn_after": 0}))
	assert_eq(s.session, mine, "the next ear goes back to the player's session")
	assert_true(mine.is_done("right"), "its right SRT untouched")
	done = await _wait_until(func() -> bool: return finished.size() == 3, 30.0)
	assert_true(done)
	if done:
		var both: Dictionary = ((finished[2] as Dictionary)["speech"] as Dictionary)["srt"]
		assert_true(both.has("right") and both.has("left"), "both ears in the player's results")


func test_tell_points_at_the_meter_and_the_coach_comes_back() -> void:
	Hoot.reset_visit()   # the tell is once per visit: an earlier test may have used it
	var s := _screen()
	s.start_test(_mike(), "right", true, _plan())
	var coached: bool = await _wait_until(func() -> bool: return String(Hoot.current_tip().get("target", "")).ends_with("_button"), 5.0)
	assert_true(coached, "the coach's tip is up")
	s.call("_maybe_tell", 50)   # PTA 72 - 50: not far enough below
	assert_false(String(Hoot.current_tip().get("text", "")).contains("below"), "no tell above the gap")
	s.call("_maybe_tell", 35)
	var tip := Hoot.current_tip()
	assert_true(String(tip.get("text", "")).contains("below his beeps"), "the tell: " + String(tip.get("text", "")))
	assert_eq(String(tip.get("target", "")), "agreement_meter", "the hand points at the meter, not at his answer")
	Hoot.dismiss_current()
	await wait_frames(2)
	assert_true(String(Hoot.current_tip().get("target", "")).ends_with("_button"), "the coach's tip comes back")
	s.call("_maybe_tell", 30)
	assert_false(String(Hoot.current_tip().get("text", "")).contains("below his beeps"), "once per visit")


func test_low_start_shows_hoot_s_praise() -> void:
	Hoot.reset_visit()   # a once-per-visit tip: an earlier test may have used it
	var s := _screen()
	# PTA 72: 15 starts low and below his SRT of 30, so he misses it and the first step goes up (S2)
	s.start_test(_mike(), "right", false, _plan({"low_start_ok": true, "level": 15}))
	var praised := func() -> bool: return String(Hoot.current_tip().get("text", "")).begins_with("Starting below")
	var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
	assert_true(ok, "the player's turn")
	if not ok:
		return
	await tap_action(&"present_tone")
	var went_up := false
	for i in 6:
		ok = await _wait_until(_player_turn.bind(s), 10.0)
		assert_true(ok, "the answer is shown")
		assert_false(bool(praised.call()), "no praise before the dial comes up")
		# score what he said; a miss steps up 5 (the ascent), a hit steps down 10 and tries again
		var heard := bool(s.session.current.get("correct", false))
		await tap_action(&"speech_correct" if heard else &"speech_incorrect")
		await _wait_until(_player_turn.bind(s), 10.0)
		for a: StringName in ([&"softer", &"softer"] if heard else [&"louder"]):
			await tap_action(a)
		await tap_action(&"present_tone")
		if not heard:
			went_up = true
			break
	assert_true(went_up, "a miss to step up from")
	var shown: bool = await _wait_until(praised, 10.0)
	assert_true(shown, "Hoot's praise: " + String(Hoot.current_tip().get("text", "")))
	assert_eq(String(Hoot.current_tip().get("target", "")), "speech_ladder")
	assert_true(s.session.combo >= 3, "clean checks all the way: the start, the scores and the steps")
	assert_true(s.session.errors.is_empty(), "not an srt_start error")


## A clean store on a combo step draws a combo callout ("Clean score!"), except when the ear's
## sheet carries earlier slips: then the store's "Oops!" stands alone.
func test_no_combo_callout_over_an_oops_store() -> void:
	var calls_of := func(scr: SpeechScreen) -> Array[String]:
		var out: Array[String] = []
		for c: Dictionary in (scr.get("_fx") as AoFx).get("_calls"):
			out.append(String(c["text"]))
		return out
	var clean := _screen()
	clean.start_test(_mike(), "left", false, _plan())
	await wait_frames(2)
	clean.call("_handle_technique", &"srt_store_ok", {"combo": 3, "multiplier": 1, "points": 50})
	var words: Array[String] = calls_of.call(clean)
	var combo_word := false
	for w: String in words:
		combo_word = combo_word or SpeechScreen.TEXTBOOK_CALLOUTS.has(w)
	assert_true(combo_word, "a clean ear: the combo callout at the store: %s" % str(words))
	clean.queue_free()
	await wait_frames(2)
	var s := _screen()
	s.start_test(_mike(), "left", false, _plan())
	# one word scored the wrong way: a misscore on this ear
	var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
	assert_true(ok)
	await tap_action(&"present_tone")
	ok = await _wait_until(_player_turn.bind(s), 10.0)
	assert_true(ok)
	var truth := bool(s.session.current.get("correct", false))
	await tap_action(&"speech_incorrect" if truth else &"speech_correct")
	assert_true(s.session.slips().has(&"misscored"), "the slip is on this ear's sheet: %s" % str(s.session.slips()))
	(s.get("_fx") as AoFx).set("_calls", [] as Array[Dictionary])
	s.call("_handle_technique", &"srt_store_ok", {"combo": 3, "multiplier": 1, "points": 50})
	for w: String in calls_of.call(s):
		assert_false(SpeechScreen.TEXTBOOK_CALLOUTS.has(w), "no combo callout under the Oops!: " + w)
	assert_eq(SpeechScreen.golf_text({"errors": [&"misscored"], "candidate_db": 30, "stored_db": 30})[0], "Oops!")


func test_coached_ear_never_stores_off_the_bracket() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", true, _plan())
	# one textbook word, then STORE twice in a row
	var words := 0
	while words < 1:
		var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
		assert_true(ok)
		if not ok:
			return
		var act: StringName = s.session.recommended_action()["action"]
		await tap_action(SpeechScreen.ACTION_INPUTS[act])
		if act == &"score_correct" or act == &"score_missed":
			words += 1
	await _wait_until(_player_turn.bind(s), 10.0)
	await tap_action(&"store")
	await wait_frames(2)
	await tap_action(&"store")
	await wait_frames(2)
	assert_false(s.session.is_done("right"), "the coach keeps the right ear by the book")
	assert_true(bool(s.get_state()["accepting_input"]))


func test_feedback_after_a_store() -> void:
	var good := {"stored_db": 30, "candidate_db": 30, "errors": [], "golf": "par", "strokes": 12, "par": 12, "by_hoot": false}
	assert_true(SpeechScreen.is_bracketed(good))
	assert_eq(SpeechScreen.golf_text(good), ["Par!", "12 words, par 12"] as Array[String])
	assert_eq(SpeechScreen._done_sub(good), "ear done: nice work!")
	var over := good.duplicate()
	over["strokes"] = 14
	assert_eq(SpeechScreen.golf_text(over)[0], "Clean!", "a clean run over par never reads Par!")
	var early := {"stored_db": 65, "candidate_db": SpeechRules.NO_SRT, "errors": [&"srt_store_no_bracket"], "golf": "par", "strokes": 2, "par": 12, "by_hoot": false}
	assert_false(SpeechScreen.is_bracketed(early))
	assert_eq(SpeechScreen.golf_text(early)[0], "Oops!", "no golf praise off the bracket")
	assert_false(SpeechScreen._done_sub(early).contains("nice work"), "no 'nice work' off the bracket")
	var off := {"stored_db": 40, "candidate_db": 30, "errors": [], "golf": "par", "strokes": 9, "par": 12}
	assert_false(SpeechScreen.is_bracketed(off), "stored away from the bracket")
	assert_true(SpeechScreen._done_sub(off).contains("30"), SpeechScreen._done_sub(off))
	var keyed := good.duplicate()
	keyed["bracketed"] = false
	assert_false(SpeechScreen.is_bracketed(keyed), "the session's own key wins")
	var hoot := {"stored_db": 30, "candidate_db": 30, "by_hoot": true, "golf": "hoot"}
	assert_false(SpeechScreen._done_sub(hoot).contains("nice work"))


func test_no_hoot_turn_without_quick_visit() -> void:
	Game.set_setting("quick_visit", false)
	var s := _screen()
	s.quick_visit = false
	s.start_test(_mike(), "left", false, _plan({"hoot_turn_after": 0}))
	await wait_frames(10)
	assert_false(bool(s.get_state()["hoot_turn"]), "a full visit: the player runs every ear")
	assert_true(bool(s.get_state()["accepting_input"]))


# ---------------------------------------------------------------- controls

func test_level_locked_while_talking() -> void:
	Engine.time_scale = 1.0   # real time: the taps below must land while the word plays
	var s := _screen()
	s.start_test(_mike(), "right", false, _plan())
	await wait_frames(2)
	for i in 3:
		await tap_action(&"louder")
	assert_eq(s.session.db, 85)
	var heard: Array = []
	var cb := func(_e: String, _t: StringName, db: int, item: Dictionary) -> void: heard.append([db, item])
	Events.speech_presented.connect(cb)
	await tap_action(&"present_tone")
	Events.speech_presented.disconnect(cb)
	assert_eq(heard.size(), 1, "one word")
	assert_true(bool(s.get_state()["talking"]) or bool(s.get_state()["listening"]))
	await tap_action(&"softer")
	await tap_action(&"louder")
	assert_eq(s.session.db, 85, "the level is locked while a word plays")
	await tap_action(&"present_tone")
	assert_eq(s.session.trials_for().size(), 1, "no second word over the first")
	await tap_action(&"speech_correct")
	assert_true(s.session.awaiting_score, "no score before the answer shows")
	var ok: bool = await _wait_until(func() -> bool: return bool(s.get_state()["answer_shown"]), 10.0)
	assert_true(ok, "his answer shows")
	await tap_action(&"softer")
	assert_eq(s.session.db, 80, "unlocked once he has answered")
	await tap_action(&"speech_incorrect")
	assert_false(s.session.awaiting_score, "scored")
	assert_false(bool(s.session.trials_for()[0]["scored"]))
	await wait_seconds(0.6)
	assert_eq(s._card.shown_word(), String(s.session.next_item().get("text", "")), "the card flips to the next word")
	assert_ne(s._card.shown_word(), String(s.session.trials_for()[0]["word"]))


func test_mask_toggle_and_keys_pill() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", false, _plan())
	await tap_action(&"toggle_mask")
	var st := s.get_state()
	assert_true(bool(st["mask_on"]))
	assert_eq(int(st["mask_db"]), int(st["db"]) - 20, "speech noise at level - 20")
	assert_eq(String(st["mask_ear"]), "left")
	await tap_action(&"toggle_mask")
	assert_false(bool(s.get_state()["mask_on"]))
	var shown := bool(Game.settings.get("show_key_hints", true))
	await tap_action(&"toggle_key_hints")
	assert_eq(bool(Game.settings.get("show_key_hints", true)), not shown, "H toggles the key chips")


func test_affinity_style_swaps_louder_and_softer() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", false, _plan())
	await wait_frames(2)
	var db0 := s.session.db
	Game.set_key_style("affinity")
	await wait_frames(1)
	assert_eq(Game.key_label(&"louder"), "Down")
	_key(KEY_UP, true)
	await wait_frames(2)
	_key(KEY_UP, false)
	await wait_frames(2)
	assert_eq(s.session.db, db0 - 5, "affinity: Up = softer")
	_key(KEY_DOWN, true)
	await wait_frames(2)
	_key(KEY_DOWN, false)
	await wait_frames(2)
	assert_eq(s.session.db, db0, "affinity: Down = louder")
	Game.set_key_style("otosuite")
	await wait_frames(1)
	_key(KEY_UP, true)
	await wait_frames(2)
	_key(KEY_UP, false)
	await wait_frames(2)
	assert_eq(s.session.db, db0 + 5, "default: Up = louder")
