extends TestCase
## v3 core: bone conduction and masking in the session (core/audiometry_session.gd sheets,
## configure(), the plateau dance) and the simulator's cross-hearing, on Bonnie (Day 2).
## docs/CHAPTER2.md §3 (truth table) and §6 (rules).


## A perfectly consistent patient: hears iff level >= the response threshold (cross-hearing
## included), fixed latency, no tricks.
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


## A patient who never answers (a miss on every tone).
class DeafSim extends FixedSim:
	func on_tone_start(_ear: String, _freq: int, _db: int, _gap_s: float) -> Dictionary:
		last_heard_by = &""
		return {"heard": false, "press": false, "guess": false, "latency_s": 0.5}


func _deaf_sim(p: PatientProfile) -> PatientSim:
	return DeafSim.new(p)


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
var _n := 0


func _bonnie() -> AudiometrySession:
	var s := AudiometrySession.new(Game.load_patient("bonnie") as PatientProfile, 7)
	s.sim = FixedSim.new(s.patient)
	return s


func _tick(s: AudiometrySession, seconds: float) -> void:
	for i in int(round(seconds / 0.05)):
		s.advance(0.05)


func _present(s: AudiometrySession) -> void:
	_tick(s, GAPS[_n % GAPS.size()])
	_n += 1
	s.tone_down()
	_tick(s, 1.5)
	s.tone_up()
	_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)


## Follow recommended_action() (v3 actions included) until the goal sheet is done for the ear.
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


## Day 2 up to the masked bone: air both ears, then unmasked bone on the right.
func _through_unmasked_bone(s: AudiometrySession) -> void:
	_play(s, "right")
	s.set_ear("left")
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "left")
	s.set_ear("right")
	s.configure({"test": &"bc"})
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "right")


func test_bonnie_profile() -> void:
	var p := Game.load_patient("bonnie") as PatientProfile
	assert_eq(p.validate(), PackedStringArray())
	assert_true(p.has_bone_data())
	assert_eq(p.get_threshold("right", 1000), 50)
	assert_eq(p.get_bc_threshold("right", 1000), 10)
	assert_eq(p.get_bc_threshold("right", 2000), 25, "the Carhart notch")
	assert_eq(p.get_bc_threshold("left", 1000), 0)
	assert_eq(p.get_ia(&"bone"), 0)
	assert_false((Game.load_patient("gus") as PatientProfile).has_bone_data(), "Gus: air only, bone = air")


func test_gus_condition_is_plain_air() -> void:
	# Chapter 1 must not change: with phones and no masker the answer is the ear's own air threshold.
	var gus := Game.load_patient("gus") as PatientProfile
	var sim := PatientSim.new(gus, 3)
	for e: String in ClinicRules.EARS:
		for f: int in ClinicRules.AC_FREQS:
			assert_eq(sim.effective_threshold(e, f), gus.get_threshold(e, f), "%s %d" % [e, f])
	var s := AudiometrySession.new(gus, 3)
	assert_eq(s.test, &"ac")
	assert_eq(s.goal_test, &"ac")
	assert_eq(s.transducer, &"phones")
	assert_false(s.mask_on)


func test_unmasked_bone_is_the_better_cochlea() -> void:
	var s := _bonnie()
	s.configure({"test": &"bc"})
	assert_eq(s.test, &"bc")
	assert_eq(s.transducer, &"bone")
	s.sim.transducer = &"bone"
	var c := s.sim.condition("right", 1000)
	assert_eq(int(c["threshold"]), 0, "the left cochlea answers at 0")
	assert_eq(c["by"], &"cross")
	assert_eq(s.response_truth("right", 1000), 0, "an accurate unmasked bone stamp is 0")


func test_bone_controls() -> void:
	var s := _bonnie()
	s.set_freq(8000)
	s.set_level(90)
	assert_true(s.set_transducer(&"bone"))
	assert_eq(s.freq, 4000, "no bone above 4 kHz")
	assert_eq(s.db, ClinicRules.max_db_for(4000, &"bone"), "clamped to the oscillator's maximum")
	assert_false(s.step_freq(1), "4 kHz is the top bone pitch")
	assert_false(s.step_level(1))
	assert_true(s.set_transducer(&"phones"))
	assert_eq(s.test, &"ac")
	assert_true(s.toggle_mask())
	assert_eq(s.test, &"ac_masked")
	assert_true(s.step_mask(1))
	assert_eq(s.mask_db, AudiometrySession.MASK_DIAL_START_DB + 5)
	assert_eq(s.masker_ear(), "left")


func test_day2_by_the_book() -> void:
	var s := _bonnie()
	var reactions := []
	var kinds := []
	s.reaction.connect(func(k: StringName, _d: Dictionary) -> void: reactions.append(k))
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	_through_unmasked_bone(s)
	assert_eq(s.stored_thresholds("right", &"ac"), {250: 55, 500: 55, 1000: 50, 1500: 50, 2000: 50, 3000: 40, 4000: 35, 6000: 35, 8000: 40})
	assert_eq(s.stored_thresholds("left", &"ac"), {250: 10, 500: 5, 1000: 5, 1500: 5, 2000: 5, 3000: 10, 4000: 10, 6000: 15, 8000: 15})
	assert_eq(s.stored_thresholds("right", &"bc"), {500: 5, 1000: 0, 2000: 5, 4000: 5}, "unmasked bone = the better (left) cochlea")
	assert_has(reactions, &"cross_heard", "the Cross-Hearing Ghost showed up")
	assert_has(kinds, &"cross_hearing")
	# the masking plan
	assert_eq(s.sheet_required("right", &"bc_masked"), [1000, 2000, 4000, 500] as Array[int])
	assert_eq(s.sheet_required("right", &"ac_masked"), [1000, 1500, 2000, 500, 250] as Array[int], "E1: 1.5k is charted, so it is masked too")
	assert_eq(s.sheet_required("left", &"bc_masked"), [] as Array[int])
	assert_eq(s.initial_mask_db("right", 1000), 25, "5 + 10 + 10 occlusion")
	assert_eq(s.initial_mask_db("right", 500), 30)
	assert_eq(s.initial_mask_db("right", 2000), 15)
	assert_eq(s.initial_mask_db("right", 4000), 20)
	# masked bone (plateau)
	s.configure({"test": &"bc_masked"})
	assert_eq(s.recommended_action()["action"], &"mask_toggle", "turn the noise on first")
	s.set_freq(1000)
	_play(s, "right")
	assert_eq(s.stored_thresholds("right", &"bc_masked"), {1000: 10, 2000: 25, 4000: 10, 500: 10}, "masked bone = her right cochlea")
	assert_has(kinds, &"plateau_found")
	assert_has(kinds, &"undermasked", "at 2 kHz the Ghost answers through the starting noise")
	var info: Dictionary = s.sheet(&"bc_masked")["stored"]["right"][2000]
	assert_true(bool(info["masked"]))
	assert_eq(info["test"], "bc_masked")
	assert_true(bool(info["plateau"]["found"]))
	assert_eq(int(info["true_db"]), 25)
	# masked air
	s.configure({"test": &"ac_masked"})
	assert_eq(s.transducer, &"phones", "the plan puts the phones back on")
	assert_eq(s.recommended_action()["action"], &"mask_toggle")
	_play(s, "right")
	assert_eq(s.stored_thresholds("right", &"ac_masked"), {1000: 50, 1500: 50, 2000: 50, 500: 55, 250: 55})
	for k: Dictionary in s.errors:
		fail("no technique errors by the book, got %s at %s %d" % [k["kind"], k["ear"], int(k["freq"])])
	var r := s.build_results()
	var right: Dictionary = r["ears"]["right"]
	assert_eq(right["hearing_type"], &"conductive")
	assert_true(bool(right["abg_red_flag"]), "gap >= 15 at 500, 1k and 2k: refer")
	assert_true(bool(right["carhart_notch"]))
	assert_eq(r["ears"]["left"]["hearing_type"], &"normal")
	assert_eq((right["bc_masked"] as Dictionary).size(), 4)
	assert_true(bool(right["complete_tests"]["bc_masked"]))
	assert_has(r["tests"], "bc_masked")
	assert_true(float(r["accuracy"]) > 0.95, "accuracy %f" % float(r["accuracy"]))
	assert_true(float(r["technique"]) > 0.99)


func test_masked_step_errors() -> void:
	var s := _bonnie()
	_through_unmasked_bone(s)
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	s.toggle_mask()
	var kinds := []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	# noise too low for the first masked tone
	s.set_mask_level(10)
	s.set_level(0)
	_present(s)
	assert_has(kinds, &"mask_too_low")
	# catch up to the initial level, then climb to a hit
	s.set_mask_level(25)
	s.set_level(5)
	_present(s)
	s.set_level(10)
	_present(s)
	assert_true(bool(s.measurement("right", 1000)[-1]["responded"]), "heard at 10 with 25 noise")
	# heard -> the tone must stay put and the NOISE goes up; moving the tone is a wrong step
	s.set_level(0)
	_present(s)
	assert_has(kinds, &"mask_wrong_step")
	# storing before a plateau
	var info := s.store()
	assert_has(info["errors"], &"store_no_plateau")


func test_overmasking() -> void:
	var s := _bonnie()
	_through_unmasked_bone(s)
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	s.toggle_mask()
	assert_eq(s.overmask_limit_db("right", 1000, 10), 50, "bone: tone + 40")
	s.set_mask_level(60)
	s.set_level(10)
	assert_eq(s.mask_status(), &"over")
	var kinds := []
	var reactions := []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	s.reaction.connect(func(k: StringName, _d: Dictionary) -> void: reactions.append(k))
	_present(s)
	assert_has(kinds, &"overmasked")
	assert_has(reactions, &"overmasked")
	s.set_mask_level(25)
	assert_eq(s.mask_status(), &"ok")



## Air overmasking: the test ear's bone + 40, whatever the tone; at 250 Hz (no bone measured there)
## the 500 Hz bone stands in. A heard tone one noise step under that limit can be stored: the
## safe window is full, so the plateau cannot be finished.
func test_air_overmask_limit_and_full_window() -> void:
	var s := _bonnie()
	_through_unmasked_bone(s)
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	_play(s, "right")
	s.configure({"test": &"ac_masked"})
	s.toggle_mask()
	s.set_freq(1000)
	assert_eq(s.overmask_limit_db("right", 1000, 50), 50, "air: masked bone 10 + 40")
	assert_eq(s.overmask_limit_db("right", 1000, 70), 50, "the tone level does not move the air limit")
	s.set_freq(250)
	assert_eq(s.overmask_limit_db("right", 250, 55), 50, "250 Hz borrows the 500 Hz bone")
	s.set_mask_level(45)
	s.set_level(55)
	assert_false(s.window_full("right", 250))
	_present(s)
	assert_true(s.window_full("right", 250), "heard at 45 and 50 would overmask")
	assert_eq(s.store_candidate("right", 250), 55)
	assert_eq(s.recommended_action()["action"], &"store")
	var info := s.store()
	assert_false((info["errors"] as Array).has(&"store_no_plateau"), "a full window is not a skipped plateau")
	assert_true(bool(info["plateau_not_reached"]), "E9: stored as plateau not reached")


## (Clinical review E9) A masking dilemma: a large conductive loss in both ears. The textbook start
## (other ear's air 60 + 10 = 70) already overmasks a bone tone at 5 dB (limit 5 + 40 = 45), so the
## coach starts the noise one step short (40), never says "too little", explains the dilemma once,
## and the heard tone is stored as "plateau not reached" with full credit.
func test_masking_dilemma_stops_short_of_overmasking() -> void:
	var p := PatientProfile.new()
	p.id = "dilemma"
	p.display_name = "Test dilemma"
	for f: int in ClinicRules.AC_FREQS:
		p.thresholds_right[f] = 60
		p.thresholds_left[f] = 60
	for f: int in ClinicRules.BC_FREQS:
		p.bc_right[f] = 5
		p.bc_left[f] = 5
	var s := AudiometrySession.new(p, 7)
	s.sim = FixedSim.new(p)
	_play(s, "right")
	s.set_ear("left")
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "left")
	s.set_ear("right")
	s.configure({"test": &"bc"})
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "right")
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	assert_eq(s.recommended_action()["action"], &"mask_toggle")
	s.toggle_mask()
	assert_eq(s.initial_mask_db(), 70, "other ear's air 60 + 10, no occlusion (that ear has a gap)")
	assert_true(s.in_dilemma("right", 1000, 5), "70 already reaches the limit 45")
	assert_eq(s.start_mask_db("right", 1000, 5), 40, "one step short of overmasking")
	var a := s.recommended_action()
	assert_eq(int(a["target_mask"]), 40, "the coach never asks for the overmasking start")
	s.set_mask_level(40)
	s.set_level(int(s.recommended_start("right", 1000)))
	assert_eq(s.mask_status(), &"impossible", "the lamp shows the dilemma")
	var kinds := []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	_present(s)
	assert_has(kinds, &"masking_dilemma")
	assert_has(kinds, &"plateau_not_reached")
	assert_false(kinds.has(&"mask_too_low"), "the safe maximum is not too little noise")
	assert_false(kinds.has(&"overmasked"))
	assert_true(s.window_full("right", 1000))
	assert_eq(s.recommended_action()["action"], &"store")
	var info := s.store()
	assert_true(bool(info["plateau_not_reached"]))
	assert_eq((info["errors"] as Array).size(), 0, "storing the held level is the right call")
	assert_eq(float(info["accuracy"]), 1.0)
	assert_true(s.textbook_mask_presentations("right", 1000, 5, 40) <= 2, "par ends when the window is full")
	# the next pitch is dialled to the safe start, never the overmasking textbook level
	assert_true(s.freq != 1000, "moved on to the next masked bone pitch")
	assert_eq(s.mask_db, s.start_mask_db("right", s.freq, s.db))
	assert_true(s.mask_db < s.overmask_limit_db(), "the preset noise does not overmask")
	assert_eq(s.recommended_action()["action"], &"present", "no noise fix needed first")
	# a player who overmasks and misses: the coach brings the noise back under the limit
	s.set_mask_level(s.overmask_limit_db() + 5)
	var before := s.mask_db
	s.sim = _deaf_sim(p)
	_present(s)
	var a2 := s.recommended_action()
	assert_true(int(a2.get("target_mask", before)) < s.overmask_limit_db("right", s.freq, int(a2["target_db"])), "never recommends overmasking")
	# and following that advice is graded a textbook step, not a wrong one
	s.set_mask_level(int(a2["target_mask"]))
	s.set_level(int(a2["target_db"]))
	kinds.clear()
	_present(s)
	assert_has(kinds, &"textbook_step", "the capped step is the textbook step")
	assert_false(kinds.has(&"mask_wrong_step"))

func test_mask_status_light() -> void:
	var s := _bonnie()
	_through_unmasked_bone(s)
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	assert_eq(s.mask_status(), &"needed", "a 50 dB air-bone gap with the noise off")
	s.toggle_mask()
	s.set_mask_level(10)
	assert_eq(s.mask_status(), &"under")
	s.set_mask_level(25)
	assert_eq(s.mask_status(), &"ok")


## (Day 13) After Hoot lends his inserts, the lamp judges air stamped through headphones by the
## headphones' rule, as the masked-air sheet does (Bev, 1 kHz: 55 - 40 >= 10 although 55 - 55 < 10).
func test_mask_lamp_follows_each_stamps_transducer() -> void:
	var s := AudiometrySession.new(Game.load_patient("bev") as PatientProfile, 7)
	s.sim = FixedSim.new(s.patient)
	_through_unmasked_bone(s)
	s.configure({"test": &"ac_masked", "air_transducer": &"inserts"})
	s.set_freq(1000)
	assert_has(ClinicRules.masked_freqs_needed(s.results_view(), "right", &"ac_masked", &"inserts"), 1000)
	assert_true(s.masking_needed_here("right", 1000), "the headphone stamp still needs masking")
	assert_eq(s.mask_status(), &"needed", "the lamp agrees with the sheet")


## The real (wobbly) patient, following the coach through all of Day 2's tests: always finishes,
## never blasts, and the masked bone lands near her right cochlea (a plateau found one step up,
## after a wobble at threshold, is normal: within 5 dB most of the time, never more than 10).
func test_day2_real_patient_seeds() -> void:
	var loud := [0]
	var close := [0, 0]
	for seed_value in [1, 2, 3, 4, 5, 6]:
		var s := AudiometrySession.new(Game.load_patient("bonnie") as PatientProfile, seed_value)
		s.technique.connect(func(k: StringName, _d: Dictionary) -> void:
			if k == &"too_loud":
				loud[0] += 1)
		_through_unmasked_bone(s)
		s.configure({"test": &"bc_masked"})
		s.set_freq(1000)
		_play(s, "right")
		s.configure({"test": &"ac_masked"})
		_play(s, "right")
		var bcm := s.stored_thresholds("right", &"bc_masked")
		for f: int in [500, 1000, 2000, 4000]:
			assert_true(bcm.has(f), "seed %d masked bone %d" % [seed_value, f])
			var err := absi(int(bcm.get(f, -99)) - s.patient.get_bc_threshold("right", f))
			assert_true(err <= 10, "seed %d %d Hz: %d" % [seed_value, f, int(bcm.get(f, -99))])
			close[1] += 1
			if err <= 5:
				close[0] += 1
		var r := s.build_results()
		assert_eq(r["ears"]["right"]["hearing_type"], &"conductive", "seed %d" % seed_value)
		assert_true(bool(r["ears"]["right"]["abg_red_flag"]), "seed %d: refer" % seed_value)
	assert_true(close[0] * 4 >= close[1] * 3, "within 5 dB: %d of %d" % [close[0], close[1]])
	assert_eq(int(loud[0]), 0, "too_loud events while following the coach")
