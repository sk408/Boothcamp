extends TestCase
## Builder A (core/, v4): Day 2 tests bone on the BETTER ear first. Unmasked bone on Bonnie's LEFT
## mastoid answers for both cochleas (bone IA 0), so: the left ear needs no masking; the right
## ear's masked bone is needed everywhere and starts at that left bone; the masking light and the
## technique check agree; and the Ghost demo's one tone can be thrown away, even mid-press.


## A perfectly consistent patient: hears iff level >= the response threshold (cross-hearing
## included), fixed latency, no tricks. Reports which cochlea answered, like the real sim.
class FixedSim extends PatientSim:
	var latency := 0.5

	func _init(p: PatientProfile, lat: float = 0.5) -> void:
		super(p, 1)
		latency = lat

	func on_tone_start(ear: String, freq: int, db: int, _gap_s: float) -> Dictionary:
		var c := condition(ear, freq)
		var heard := db >= int(c["threshold"])
		last_heard_by = StringName(c["by"]) if heard else &""
		return {"heard": heard, "press": heard, "guess": false, "latency_s": latency}

	func false_alarm_tick(_delta: float) -> bool:
		return false

	func anticipation_delay() -> float:
		return -1.0

	func keeps_press_after_short_tone(_e: String, _f: int, _d: int, _dur: float) -> bool:
		return true


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
var _n := 0


func _bonnie() -> AudiometrySession:
	var p := Game.load_patient("bonnie") as PatientProfile
	var s := AudiometrySession.new(p, 11)
	s.sim = FixedSim.new(p)
	return s


func _tick(s: AudiometrySession, seconds: float) -> void:
	for i in int(round(seconds / 0.05)):
		s.advance(0.05)


func _present(s: AudiometrySession) -> bool:
	_tick(s, GAPS[_n % GAPS.size()])
	_n += 1
	s.tone_down()
	_tick(s, 1.5)
	s.tone_up()
	_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)
	var recs := s.measurement(s.ear, s.freq)
	return not recs.is_empty() and bool((recs[-1] as Dictionary)["responded"])


## Follow recommended_action() until the goal sheet is done for the ear.
func _play(s: AudiometrySession, e: String) -> void:
	if s.ear != e:
		s.set_ear(e)
	var guard := 0
	while not s.is_ear_complete(e) and guard < 600:
		guard += 1
		var rem := s.required_remaining(e)
		if s.test == s.goal_test and s.measurement(e, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
			s.set_freq(rem[0])
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(s)
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


## The v4 order up to the Ghost demo: air right, air left, then unmasked bone on the LEFT mastoid.
func _air_both_then_left_bone(s: AudiometrySession) -> void:
	_play(s, "right")
	s.set_ear("left")
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "left")
	s.configure({"test": &"bc", "bc_freqs": ClinicRules.BC_REQUIRED})
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "left")


func test_left_bone_first_needs_no_masking() -> void:
	var s := _bonnie()
	_air_both_then_left_bone(s)
	var p := Game.load_patient("bonnie") as PatientProfile
	var lb := s.stored_thresholds("left", &"bc")
	for f: int in ClinicRules.BC_REQUIRED:
		assert_true(lb.has(f), "left bone %d stored" % f)
		assert_near(float(lb[f]), float(p.get_bc_threshold("left", f)), 5.0, "left bone %d near the truth" % f)
	assert_true(s.stored_thresholds("right", &"bc").is_empty(), "no right unmasked bone on Day 2")
	var v := s.results_view()
	# the left ear: air and bone together, so no masking anywhere
	for f: int in ClinicRules.BC_REQUIRED:
		assert_false(s.masking_needed_here("left", f), "left %d: no masking" % f)
	assert_true(ClinicRules.masked_freqs_needed(v, "left", &"bc_masked").is_empty())
	# the right ear: its air (about 50) against the unmasked bone from the LEFT mastoid
	for f: int in ClinicRules.BC_REQUIRED:
		assert_true(s.masking_needed_here("right", f), "right %d: the gap says mask" % f)
		assert_eq(ClinicRules.unmasked_bone(v, f), lb[f], "the left bone answers for both at %d" % f)
	assert_eq(ClinicRules.masked_freqs_needed(v, "right", &"bc_masked").size(), ClinicRules.BC_REQUIRED.size())


func test_masked_bone_starts_at_the_left_unmasked_bone() -> void:
	var s := _bonnie()
	_air_both_then_left_bone(s)
	var lb := s.stored_thresholds("left", &"bc")
	s.set_ear("right")
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	assert_eq(s.test, &"bc", "noise off: the unmasked bone sheet")
	assert_eq(s.recommended_start("right", 1000), int(lb[1000]), "shown at the left (better) bone")
	assert_eq(s.mask_status(), &"needed", "the masking light: the gap says mask")
	assert_eq(s.recommended_action()["action"], &"mask_toggle", "the right ear needs noise first")
	s.toggle_mask()
	assert_eq(s.test, &"bc_masked")
	assert_eq(s.recommended_start("right", 1000), int(lb[1000]), "the masked search starts at the unmasked bone")
	assert_eq(s.mask_status(), &"under", "the dial starts below the initial level")
	var lessons: Array = []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: lessons.append(k))
	s.set_mask_level(s.initial_mask_db("right", 1000))
	s.set_level(int(lb[1000]))
	_present(s)
	assert_false(lessons.has(&"mask_start"), "a by-the-book start: %s" % [lessons])
	assert_false(lessons.has(&"mask_too_low"), "the noise was at its starting level")
	_play(s, "right")
	var mb := s.stored_thresholds("right", &"bc_masked")
	var ra := s.stored_thresholds("right", &"ac")
	for f: int in ClinicRules.BC_REQUIRED:
		assert_true(mb.has(f), "masked bone %d stored" % f)
		assert_between(float(mb[f]), float(lb[f]), float(ra[f]), "right bone %d between the left bone and the right air" % f)
	assert_eq(s.errors.filter(func(e: Dictionary) -> bool: return String(e["kind"]) == "mask_start").size(), 0, "no mask_start slips")


## The Ghost demo's one tone opens no bone search: discard_open() forgets it, and a press still on
## its way (a slow patient) is dropped instead of landing on a closed measurement.
func test_discard_open_drops_a_pending_press() -> void:
	var s := _bonnie()
	_air_both_then_left_bone(s)
	var lb := s.stored_thresholds("left", &"bc")
	s.set_ear("right")
	s.configure({"test": &"bc", "bc_freqs": [1000]})
	s.scoring = false
	s.sim = FixedSim.new(s.patient, 2.0)   # answers 2 s after the tone starts
	s.set_freq(1000)
	s.set_level(int(lb[1000]) + 5)
	var presses: Array = []
	s.responded.connect(func(e: String, f: int, d: int, _rel: bool) -> void: presses.append([e, f, d]))
	_tick(s, 1.0)
	s.tone_down()
	_tick(s, 1.2)
	s.tone_up()
	_tick(s, 0.2)
	assert_eq(s.measurement("right", 1000).size(), 1, "the demo tone is on the bone sheet")
	s.discard_open("right", 1000)
	_tick(s, 3.0)
	assert_eq(presses, [], "the late press was dropped with the tone")
	assert_true(s.measurement("right", 1000).is_empty(), "nothing open at 1k")
	assert_true(s.stored_thresholds("right", &"bc").is_empty(), "nothing stored")
	# a fresh measurement afterwards starts clean, at the textbook start
	s.sim = FixedSim.new(s.patient)
	s.scoring = true
	s.set_level(s.recommended_start("right", 1000))
	assert_true(_present(s), "heard (by the left cochlea)")
	assert_eq(s.measurement("right", 1000).size(), 1, "one fresh presentation")
