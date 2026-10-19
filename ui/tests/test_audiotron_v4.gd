extends TestCase
## Builder A (ui/, v4): Day 2's better-ear-first bone on the AudiOtron. The coached LEFT bone sheet
## (route lesson, no masking talk, "?" nowhere); the Ghost demo (only TONE is live, locked keys and
## clicks wiggle and say so, no par / dance / pips, the right ear's unknown bone shows as a "?"
## range, a miss steps up 5, Hoot presses TONE when the player waits, at most max_tones beeps,
## nothing stored, no ear_completed, the deck comes back); then the masked right bone coach names
## the unmasked bone it starts from.

const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"


## A perfectly consistent patient: hears iff level >= the response threshold (cross-hearing
## included), fixed latency, no tricks.
class FixedSim extends PatientSim:
	var deaf := false

	func _init(p: PatientProfile, p_deaf: bool = false) -> void:
		super(p, 1)
		deaf = p_deaf

	func on_tone_start(ear: String, freq: int, db: int, _gap_s: float) -> Dictionary:
		var c := condition(ear, freq)
		var heard := db >= int(c["threshold"]) and not deaf
		last_heard_by = StringName(c["by"]) if heard else &""
		return {"heard": heard, "press": heard, "guess": false, "latency_s": 0.5}

	func false_alarm_tick(_delta: float) -> bool:
		return false

	func anticipation_delay() -> float:
		return -1.0

	func keeps_press_after_short_tone(_e: String, _f: int, _d: int, _dur: float) -> bool:
		return true


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
const SCRATCH_SAVE := "user://test_audiotron_v4_save.json"
var _n := 0
var _saved_path := ""
var _saved_scale := 1.0


func before_each() -> void:
	super()
	_saved_path = Game.save_path
	Game.save_path = SCRATCH_SAVE
	_saved_scale = Engine.time_scale


func after_each() -> void:
	Engine.time_scale = _saved_scale
	Game.save_path = _saved_path
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Hoot.clear()
	super()


func _screen() -> AudiometerScreen:
	var screen := (load(AUDIOMETER) as PackedScene).instantiate() as AudiometerScreen
	add_node(screen)
	return screen


func _tick(s: AudiometrySession, seconds: float) -> void:
	for i in int(round(seconds / 0.05)):
		s.advance(0.05)


func _present(screen: AudiometerScreen) -> void:
	var s := screen.session
	_tick(s, GAPS[_n % GAPS.size()])
	_n += 1
	screen._hold_add("mouse")
	_tick(s, 1.5)
	screen._hold_remove("mouse")
	_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)


## Follow recommended_action() until the plan's sheet is done; `check` sees every coach line.
func _play(screen: AudiometerScreen, e: String, check: Callable = Callable()) -> void:
	var s := screen.session
	var guard := 0
	while not s.is_ear_complete(e) and guard < 600:
		guard += 1
		var rem := s.required_remaining(e)
		if s.test == s.goal_test and s.measurement(e, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
			s.set_freq(rem[0])
		var a := s.recommended_action()
		if check.is_valid():
			check.call(screen._coach_text(a), a)
		match a["action"]:
			&"present":
				_present(screen)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"mask_louder", &"mask_softer":
				s.set_mask_level(int(a["target_mask"]))
			&"mask_toggle":
				s.toggle_mask()
			&"transducer":
				s.set_transducer(a["target"])
			&"store":
				s.store()
			&"no_response":
				s.store_no_response()
			_:
				_tick(s, 0.1)
	assert_true(guard < 600, "%s %s finished" % [s.goal_test, e])
	screen._refresh()


func _bonnie_test(screen: AudiometerScreen, ear: String, coached: bool, plan: Dictionary, deaf: bool = false) -> void:
	var p := Game.load_patient("bonnie") as PatientProfile
	if not plan.has("hoot_turn_after"):
		plan["hoot_turn_after"] = 99
	screen.start_test(p, ear, coached, plan)
	screen.session.sim = FixedSim.new(p, deaf)


## Let the screen finish the test the way the level waits for it (its done celebration ends with
## test_finished), so a late finish never lands on the next plan.
func _settle(screen: AudiometerScreen) -> void:
	var got := {}
	var cb := func(_r: Dictionary) -> void: got["r"] = true
	screen.test_finished.connect(cb)
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_msec()
	while not got.has("r") and Time.get_ticks_msec() - t0 < 10000:
		await wait_frames(1)
	Engine.time_scale = _saved_scale
	screen.test_finished.disconnect(cb)
	assert_true(got.has("r"), "the screen finished its test")


func _air_both(screen: AudiometerScreen) -> void:
	Game.begin_visit("bonnie")
	_bonnie_test(screen, "right", false, {"test": "ac"})
	_play(screen, "right")
	await _settle(screen)
	_bonnie_test(screen, "left", false, {"test": "ac"})
	_play(screen, "left")
	await _settle(screen)


func _left_bone(screen: AudiometerScreen, coached: bool) -> void:
	_bonnie_test(screen, "left", coached, {"test": "bc", "bc_freqs": ClinicRules.BC_REQUIRED, "masking_controls": true})
	if screen.session.transducer != &"bone":
		screen.session.set_transducer(&"bone")
	_play(screen, "left")
	await _settle(screen)


func _demo_plan(db: int, extra: Dictionary = {}) -> Dictionary:
	var d := {"freq": 1000, "db": db, "title": "Bone %d, air 50? BOO!" % db}
	d.merge(extra, true)
	return {"test": "bc", "bc_freqs": [1000], "masking_controls": false, "hoot_turn_after": 99, "demo_tone": d}


# ---------------------------------------------------------------- the LEFT bone sheet

## Coached unmasked bone on the better (left) ear: the route lesson starts on AIR, '>' marks go
## on the left card, and nothing on the sheet talks about masking.
func test_left_bone_coached_without_masking_talk() -> void:
	var screen := _screen()
	await wait_frames(2)
	await _air_both(screen)
	_bonnie_test(screen, "left", true, {"test": "bc", "bc_freqs": ClinicRules.BC_REQUIRED, "masking_controls": true})
	var st := screen.get_state()
	assert_eq(String(st["ear"]), "left")
	assert_eq(st["goal_test"], &"bc")
	assert_eq(st["transducer"], &"phones", "the route lesson: start on air")
	var first: Array = screen._coach_text(screen.session.recommended_action())
	assert_true(String(first[0]).begins_with("Bone time!"), String(first[0]))
	assert_eq(String(first[1]), "transducer_bone_button")
	screen.session.set_transducer(&"bone")
	var lines: Array = []
	_play(screen, "left", func(line: Array, a: Dictionary) -> void:
		lines.append(String(line[0]))
		assert_false(a["action"] in [&"mask_toggle", &"mask_louder", &"mask_softer"], "no masking on the left: %s" % a)
		assert_ne(screen.session.mask_status(), &"needed", "the masking light stays off on the left"))
	assert_true(lines.size() > 4, "the coach spoke")
	for t: String in lines:
		var low := t.to_lower()
		assert_true(low.find("noise") < 0 and low.find("mask") < 0, "no masking talk: %s" % t)
	var left: Audiogram = screen._cards["left"].audiogram
	var right: Audiogram = screen._cards["right"].audiogram
	assert_eq(left.attention, {}, "nothing blinks on the left")
	assert_eq(left.bone_range, {}, "no '?' on the left: its bone is measured")
	assert_eq(right.bone_range, {}, "the right card is not under test")
	for f: int in ClinicRules.BC_REQUIRED:
		assert_true(screen.session.stored_thresholds("left", &"bc").has(f), "left bone %d" % f)
	assert_true(screen.session.stored_thresholds("right", &"bc").is_empty())


# ---------------------------------------------------------------- the Ghost demo

## The demo's look and locks: only TONE is live; keys and clicks on the rest are refused; no par,
## no pips, no dance; the right card says GHOST TEST and shows its unknown bone as a "?" range.
func test_demo_locks_and_look() -> void:
	var screen := _screen()
	await wait_frames(2)
	await _air_both(screen)
	await _left_bone(screen, false)
	var lb := screen.session.stored_thresholds("left", &"bc")
	var ra := screen.session.stored_thresholds("right", &"ac")
	var db := int(lb[1000]) + ClinicRules.LEVEL_STEP_DB
	_bonnie_test(screen, "right", false, _demo_plan(db))
	await wait_frames(2)
	var st := screen.get_state()
	assert_true(bool(st["demo"]))
	assert_eq(int(st["db"]), db)
	assert_eq(int(st["par"]), 0, "no par on the demo")
	for id: String in AudiometerScreen.DEMO_LOCKED:
		assert_true((screen._buttons[id] as AoButton).locked, "%s locked" % id)
	assert_false((screen._buttons["tone_button"] as AoButton).locked, "TONE stays live")
	assert_true((screen._buttons["tone_button"] as AoButton).beckon, "and beckons")
	assert_false((screen._buttons["store_button"] as AoButton).beckon)
	var card: AoEarCard = screen._cards["right"]
	assert_eq(card.badge, "GHOST TEST")
	assert_eq((screen._cards["left"] as AoEarCard).badge, "TESTING")
	assert_true(card.progress_total <= 0, "no pips: the demo stamps nothing")
	assert_true(screen._quest.note.contains("ONE beep"), screen._quest.note)
	assert_true(screen._dance.lit() < 0, "no dance-card pulse")
	var br: Dictionary = card.audiogram.bone_range.get("right", {})
	assert_true(br.has(1000), "the right ear's bone is unknown: a '?' range")
	assert_eq(br[1000], [int(lb[1000]), int(ra[1000])], "from the left (unmasked) bone up to the right air")
	assert_eq((screen._cards["left"] as AoEarCard).audiogram.bone_range, {})
	# locked keys do nothing (and wiggle), a click on a locked pad is refused too
	await tap_action(&"louder")
	await tap_action(&"freq_up")
	await tap_action(&"store")
	await tap_action(&"ear_left")
	st = screen.get_state()
	assert_eq(int(st["db"]), db, "louder refused")
	assert_eq(int(st["freq"]), 1000, "Hz refused")
	assert_eq(String(st["ear"]), "right", "ear refused")
	assert_true(screen.session.stored_thresholds("right", &"bc").is_empty(), "store refused")
	var denied: Array = []
	var b: AoButton = screen._buttons["softer_button"]
	b.denied.connect(func() -> void: denied.append(true))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	b._gui_input(click)
	assert_eq(denied.size(), 1, "a locked pad says no")
	assert_eq(int(screen.get_state()["db"]), db)


## A deaf moment: every demo beep is missed. Each miss steps the tone up 5, Hoot presses TONE
## when the player waits, and after max_tones the demo ends anyway: nothing stored, no
## ear_completed, the deck and the ear lock come back.
func test_demo_misses_step_up_and_hoot_presses() -> void:
	var screen := _screen()
	await wait_frames(2)
	await _air_both(screen)
	await _left_bone(screen, false)
	var completed: Array = []
	var on_done := func(e: String, _r: Dictionary) -> void: completed.append(e)
	Events.ear_completed.connect(on_done)
	var finished := {}
	screen.test_finished.connect(func(r: Dictionary) -> void: finished["r"] = r)
	_bonnie_test(screen, "right", false, _demo_plan(5, {"idle_s": 0.4, "max_tones": 2}), true)
	Engine.time_scale = 4.0
	var t0 := Time.get_ticks_msec()
	var dbs: Array = [int(screen.get_state()["db"])]
	while not finished.has("r") and Time.get_ticks_msec() - t0 < 20000:
		await wait_frames(1)
		if bool(screen.get_state().get("demo", false)) and int(screen.get_state()["db"]) != int(dbs[-1]):
			dbs.append(int(screen.get_state()["db"]))
	Engine.time_scale = _saved_scale
	Events.ear_completed.disconnect(on_done)
	assert_true(finished.has("r"), "the demo ends by itself, nobody touching a key")
	assert_eq(dbs, [5, 10], "a miss steps up 5")
	assert_eq(screen._demo_tones, 2, "max_tones beeps, all by Hoot's wing")
	assert_true(ClinicRules.sheet_thresholds(finished.get("r", {}), "right", &"bc").is_empty(), "nothing stored")
	assert_eq(completed, [], "no ear_completed for the demo")
	assert_true(screen.session.measurement("right", 1000).is_empty(), "the demo opened no bone search")
	assert_false(bool(screen.get_state()["demo"]))
	assert_false((screen._buttons["louder_button"] as AoButton).locked, "the deck is back")
	assert_true((screen._buttons["ear_left_button"] as AoButton).locked, "the ear lock follows the ear again")
	assert_false((screen._buttons["ear_right_button"] as AoButton).locked)
	assert_eq((screen._cards["right"] as AoEarCard).badge, "TESTING")


## After the demo, the masked right bone: the "?" range stays until a masked stamp lands, and the
## coach's start line names the unmasked (left) bone the search starts from.
func test_masked_right_bone_after_the_demo() -> void:
	var screen := _screen()
	await wait_frames(2)
	await _air_both(screen)
	await _left_bone(screen, false)
	var lb := screen.session.stored_thresholds("left", &"bc")
	_bonnie_test(screen, "right", true, {"test": "bc_masked", "masking_controls": true})
	screen._refresh()
	var right: Audiogram = screen._cards["right"].audiogram
	for f: int in ClinicRules.BC_REQUIRED:
		assert_true((right.bone_range.get("right", {}) as Dictionary).has(f), "'?' at %d before masking" % f)
	assert_eq(screen.session.recommended_start("right", 1000), int(lb[1000]))
	# a player who wandered off the start hears where it is (the left, unmasked bone)
	screen.session.set_level(int(lb[1000]) + 20)
	var firsts: Array = []
	var starts: Array = []
	_play(screen, "right", func(line: Array, _a: Dictionary) -> void:
		var key := String(line[2])
		if key.begins_with("mstart"):
			starts.append(String(line[0]))
		elif key == "mpresent0":
			firsts.append(String(line[0])))
	assert_true(starts.size() > 0, "the coach gave a masked start line")
	for t: String in starts:
		assert_true(t.begins_with("Start at the unmasked bone, %d dB" % int(lb[1000])), t)
	assert_eq(firsts.size(), ClinicRules.BC_REQUIRED.size(), "one first masked beep per frequency")
	for t: String in firsts:
		assert_true(t.contains("the unmasked bone"), t)
	screen._refresh()
	assert_eq(right.bone_range, {}, "every '?' resolved by a masked stamp")
