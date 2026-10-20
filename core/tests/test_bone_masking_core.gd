extends TestCase
## Builder A (core/): Chapter 2 bone conduction and masking in the simulator and the session, on
## Bonnie (right otosclerosis) and two made-up heads. Cross-hearing through the real sim, the Ghost
## reaction and its lessons, bone output limits and no-response, the vibrotactile tickle, the
## plateau dance step by step, the masked accuracy grace, the dilemma light, the masker noise
## through the tone generator (quiet and capped), and the patient's pronouns in Hoot's tips.


## A perfectly consistent patient: hears iff level >= the response threshold (cross-hearing
## included), fixed latency, no tricks. Reports which cochlea answered, like the real sim.
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


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
var _n := 0


func _session(p: PatientProfile) -> AudiometrySession:
	var s := AudiometrySession.new(p, 11)
	s.sim = FixedSim.new(p)
	return s


func _bonnie() -> AudiometrySession:
	return _session(Game.load_patient("bonnie") as PatientProfile)


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


## Air on both ears, then (optionally) unmasked bone on the right: the stamps masking needs.
func _air_both(s: AudiometrySession, bone_right: bool = false) -> void:
	_play(s, "right")
	s.set_ear("left")
	s.set_freq(1000)
	s.set_level(40)
	_play(s, "left")
	s.set_ear("right")
	if bone_right:
		s.configure({"test": &"bc"})
		s.set_freq(1000)
		s.set_level(40)
		_play(s, "right")


## A made-up head: the same air / bone everywhere on both ears.
static func _head(id: String, ac: int, bc: int) -> PatientProfile:
	var p := PatientProfile.new()
	p.id = id
	p.display_name = "Test %s" % id
	for f: int in ClinicRules.AC_FREQS:
		p.thresholds_right[f] = ac
		p.thresholds_left[f] = ac
	for f: int in ClinicRules.BC_FREQS:
		p.bc_right[f] = bc
		p.bc_left[f] = bc
	return p


# ---------------------------------------------------------------- the simulator

## The real simulator with Bonnie's real head (phones IA 60, bone IA 0): who answers what.
func test_sim_cross_hearing_and_overmasking() -> void:
	var p := Game.load_patient("bonnie") as PatientProfile
	var sim := PatientSim.new(p, 5)
	# unmasked air on the bad right ear: crossing needs left bone 0 + 60, so the right ear answers
	var c := sim.condition_for("right", 1000, &"phones", -1)
	assert_eq(int(c["threshold"]), 50)
	assert_eq(c["by"], &"test")
	# unmasked bone: zero IA, the better LEFT cochlea answers at its own bone (the Ghost)
	for f: int in ClinicRules.BC_FREQS:
		c = sim.condition_for("right", f, &"bone", -1)
		assert_eq(int(c["threshold"]), mini(p.get_bc_threshold("left", f), p.get_bc_threshold("right", f)), "unmasked bone %d" % f)
	c = sim.condition_for("right", 1000, &"bone", -1)
	assert_eq(c["by"], &"cross")
	# masked at the textbook start (left air 5 + 10 + 10 occlusion): the right cochlea answers
	c = sim.condition_for("right", 1000, &"bone", 25)
	assert_eq(int(c["threshold"]), 10, "masked bone = the right cochlea")
	assert_eq(c["by"], &"test")
	# more noise inside the window changes nothing (that is the plateau)
	for m: int in [30, 35, 40, 45]:
		assert_eq(int(sim.condition_for("right", 1000, &"bone", m)["threshold"]), 10, "plateau at noise %d" % m)
	# far too much noise leaks back across the head (real IA 60) and lifts the right cochlea too
	c = sim.condition_for("right", 1000, &"bone", 90)
	assert_eq(int(c["threshold"]), 30, "overmasked: 90 - 60 = 30")
	# the left (good) ear's own air test never needs the ghost
	c = sim.condition_for("left", 1000, &"phones", -1)
	assert_eq(int(c["threshold"]), 5)
	assert_eq(c["by"], &"test")


# ---------------------------------------------------------------- the session

## The Ghost: an unmasked bone beep heard by the left cochlea fires cross_heard (the UI flies the
## ghost) and the cross_hearing lesson once; too little noise later fires the undermasked lesson.
func test_ghost_reaction_and_lessons() -> void:
	var s := _bonnie()
	_air_both(s)
	var reactions: Array = []
	var lessons: Array = []
	s.reaction.connect(func(k: StringName, d: Dictionary) -> void:
		if k == &"cross_heard":
			reactions.append(d))
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: lessons.append(k))
	s.configure({"test": &"bc"})
	s.set_freq(1000)
	s.set_level(20)
	assert_true(_present(s), "heard at 20 (by the left cochlea)")
	assert_eq(reactions.size(), 1, "the Ghost flies")
	assert_eq(String(reactions[0]["ear"]), "right")
	assert_eq(String(reactions[0]["via"]), "left")
	assert_false(bool(reactions[0]["masked"]))
	assert_has(lessons, &"cross_hearing")
	s.set_level(10)
	_present(s)
	assert_eq(lessons.count(&"cross_hearing"), 1, "the lesson plays once")
	# masked, but the noise is too low: the ghost answers through it
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	s.toggle_mask()
	s.set_mask_level(15)
	s.set_level(5)
	assert_true(_present(s), "heard at 5: the left cochlea, through only 15 dB of noise")
	assert_true(bool(reactions[-1]["masked"]))
	assert_has(lessons, &"undermasked")
	assert_has(lessons, &"mask_too_low")


## The plateau dance, one beep at a time, then the masked stamp: steps, found, the store.
func test_plateau_dance_step_by_step() -> void:
	var s := _bonnie()
	_air_both(s, true)
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	assert_eq(s.initial_mask_db("right", 1000), 25, "left air 5 + 10 + 10 occlusion")
	assert_eq(s.mask_status(), &"needed")
	s.toggle_mask()
	s.set_mask_level(25)
	assert_eq(s.mask_status(), &"ok")
	s.set_level(10)
	assert_true(_present(s))
	assert_eq(int(s.plateau_info()["steps"]), 0, "heard at the start: no raises yet")
	assert_false(bool(s.plateau_info()["found"]))
	for want: int in [1, 2, 3]:
		assert_eq(s.recommended_action()["action"], &"mask_louder", "heard -> noise up")
		s.step_mask(1)
		assert_true(_present(s), "still 10 with noise %d" % s.mask_db)
		assert_eq(int(s.plateau_info()["steps"]), want)
	assert_true(bool(s.plateau_info()["found"]), "three raises: a plateau")
	assert_eq(int(s.plateau_info()["db"]), 10)
	assert_eq(int(s.plateau_info()["needed"]), ClinicRules.PLATEAU_STEPS)
	assert_eq(s.recommended_action()["action"], &"store")
	var info := s.store()
	assert_eq((info["errors"] as Array), [], "a by-the-book masked stamp")
	assert_true(bool(info["masked"]))
	assert_eq(int(info["stored_db"]), 10)
	assert_near(float(info["accuracy"]), 1.0, 1e-6)
	assert_eq(s.stored_thresholds("right", &"bc_masked"), {1000: 10})


## (Polish) Masked stamps are scored like unmasked ones (MASKED_GRACE_DB 0): the simulator's
## masked calibration (PatientSim.MASKED_BIAS_DB) puts a by-the-book plateau on the truth instead.
func test_masked_accuracy_no_grace() -> void:
	assert_eq(AudiometrySession.MASKED_GRACE_DB, 0)
	var s := _bonnie()
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	if not s.mask_on:
		s.toggle_mask()
	assert_eq(s.test, &"bc_masked", "noise on: the masked sheet")
	var none: Array[StringName] = []
	var cases := {10: 0.0, 15: 5.0, 20: 10.0, 5: -5.0}
	for lvl: int in cases:
		s.set_level(lvl)
		var info: Dictionary = s._make_info([], none, false, &"first", null)
		assert_eq(int(info["true_db"]), 10, "true_db is the right cochlea, unchanged")
		assert_near(float(info["accuracy"]), ClinicRules.accuracy_for_error(float(cases[lvl])), 1e-6, "masked stamp at %d" % lvl)
	# unmasked bone: its truth is whoever answers (the left cochlea, 0)
	s.configure({"test": &"bc"})
	if s.mask_on:
		s.toggle_mask()
	assert_eq(s.test, &"bc")
	s.set_freq(1000)
	s.set_level(10)
	var un: Dictionary = s._make_info([], none, false, &"first", null)
	assert_eq(int(un["true_db"]), 0)
	assert_near(float(un["accuracy"]), ClinicRules.accuracy_for_error(10.0), 1e-6)
	assert_true(float(un["accuracy"]) < 1.0)


## (Polish) Calibration: Hoot's by-the-book plateau (instant_measure, the real wobbly simulator)
## lands on Bonnie's profile value at least 65 % of the time for masked bone AND masked air, with
## a small mean error, so masked air confirms unmasked air (docs/CHAPTER2.md section 2).
func test_by_the_book_plateau_lands_on_truth() -> void:
	var p := Game.load_patient("bonnie") as PatientProfile
	var hits := {&"bc_masked": 0, &"ac_masked": 0}
	var n := {&"bc_masked": 0, &"ac_masked": 0}
	var err_sum := {&"bc_masked": 0.0, &"ac_masked": 0.0}
	var same_as_unmasked := 0
	for seed_i in 60:
		var s := AudiometrySession.new(p, 1000 + seed_i)
		s.scoring = false
		for plan: Array in [[&"ac", "right"], [&"ac", "left"], [&"bc", "right"], [&"bc_masked", "right"], [&"ac_masked", "right"]]:
			s.configure({"test": plan[0]})
			if plan[0] == &"ac":
				s.retest_waived[plan[1]] = true
			var e: String = plan[1]
			var guard := 0
			while not s.is_ear_complete(e) and guard < 30:
				guard += 1
				var rem := s.required_remaining(e)
				if rem.is_empty():
					break
				var info := s.instant_measure(e, rem[0])
				if info.is_empty():
					break
			assert_true(s.is_ear_complete(e), "seed %d: %s %s complete" % [seed_i, plan[0], e])
			if ClinicRules.test_is_masked(plan[0]):
				var st: Dictionary = (s.sheet(plan[0])["stored"] as Dictionary)[e]
				var un: Dictionary = (s.sheet(ClinicRules.unmasked_test(plan[0]))["stored"] as Dictionary)[e]
				for f: int in st:
					var d := int(st[f]["stored_db"]) - int(st[f]["true_db"])
					if plan[0] == &"ac_masked" and un.has(f) and int(un[f]["stored_db"]) == int(st[f]["stored_db"]):
						same_as_unmasked += 1
					n[plan[0]] = int(n[plan[0]]) + 1
					err_sum[plan[0]] = float(err_sum[plan[0]]) + d
					if d == 0:
						hits[plan[0]] = int(hits[plan[0]]) + 1
	for t: StringName in hits:
		assert_true(int(n[t]) > 100, "%s measured often enough" % t)
		var rate := float(hits[t]) / float(n[t])
		var mean := float(err_sum[t]) / float(n[t])
		assert_true(rate >= 0.65, "%s: a by-the-book plateau lands on the truth %.0f %% of the time" % [t, rate * 100.0])
		assert_between(mean, -2.5, 2.5, "%s mean error %.1f dB" % [t, mean])
	var agree := float(same_as_unmasked) / float(n[&"ac_masked"])
	assert_true(agree >= 0.75, "masked air confirms unmasked air %.0f %% of the time" % (agree * 100.0))


## (Polish) instant_measure is Hoot's only: it does nothing while scoring is on, and the 1 kHz retest
## can be waived for an ear (Day 2: Hoot skips it).
func test_instant_measure_and_retest_waiver() -> void:
	var p := Game.load_patient("bonnie") as PatientProfile
	var s := AudiometrySession.new(p, 77)
	assert_eq(s.instant_measure("left", 1000), {}, "scoring on: the player's holes are never instant")
	s.scoring = false
	var info := s.instant_measure("left", 1000)
	assert_false(info.is_empty())
	assert_true(bool(info["by_hoot"]))
	assert_between(int(info["stored_db"]), 0, 15)
	for f: int in [1500, 2000, 3000, 4000, 6000, 8000]:
		s.instant_measure("left", f)
	assert_eq(s.required_remaining("left")[0], 1000, "the retest is next")
	s.retest_waived["left"] = true
	assert_false(s.required_remaining("left").has(1000), "waived")
	assert_eq(s.measurement_kind("left", 1000), &"redo")
	assert_eq(s.ear_progress("left")[1], 9, "1k 1.5k 2k 3k 4k 6k 8k 500 250, no retest")


## The bone oscillator's outputs are lower than the earphones'; a miss at the bone maximum may be
## stored as no response (and scores as right when the cochlea really is beyond it).
func test_bone_output_limits_and_no_response() -> void:
	var s := _bonnie()
	assert_true(s.set_transducer(&"bone"))
	for f: int in ClinicRules.BC_FREQS:
		s.set_freq(f)
		s.set_level(200)
		assert_eq(s.db, ClinicRules.max_db_for(f, &"bone"), "bone max at %d" % f)
		assert_true(s.db < ClinicRules.max_db(f), "bone max below air max at %d" % f)
	# a head with both cochleas beyond the oscillator at 250 Hz (bone max 45)
	var deep := _session(_head("deep", 90, 80))
	deep.configure({"test": &"bc"})
	deep.set_freq(250)
	deep.set_level(45)
	assert_eq(deep.db, 45)
	var kinds: Array = []
	deep.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	assert_false(_present(deep), "nothing at the bone maximum")
	var info := deep.store_no_response()
	assert_true(bool(info["no_response"]))
	assert_false((info["errors"] as Array).has(&"nr_too_early"), "a miss at the max may be NR")
	assert_near(float(info["accuracy"]), 1.0, 1e-6, "NR is right: the cochleas are at 80")
	assert_has(kinds, &"vibrotactile", "45 dB at 250 Hz is felt, not heard")


## Loud low bone tones are felt: a tickle reaction each time, the lesson once.
func test_vibrotactile_tickle() -> void:
	var s := _bonnie()
	_air_both(s)
	var tickles := [0]
	var lessons: Array = []
	s.reaction.connect(func(k: StringName, _d: Dictionary) -> void:
		if k == &"tickle":
			tickles[0] += 1)
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: lessons.append(k))
	s.configure({"test": &"bc"})
	s.set_freq(250)
	s.set_level(ClinicRules.VIBROTACTILE_DB[250] - 5)
	_present(s)
	assert_eq(int(tickles[0]), 0, "below the tickle level")
	s.set_level(ClinicRules.VIBROTACTILE_DB[250])
	_present(s)
	_present(s)
	assert_eq(int(tickles[0]), 2)
	assert_eq(lessons.count(&"vibrotactile"), 1)


## Bilateral conductive loss: the starting noise already reaches the overmasking limit. The
## light turns purple (impossible): the classic masking dilemma.
func test_masking_dilemma_light() -> void:
	var s := _session(_head("both_conductive", 60, 0))
	_air_both(s, true)
	assert_eq(int(s.stored_thresholds("left", &"ac").get(1000, -1)), 60)
	s.configure({"test": &"bc_masked"})
	s.set_freq(1000)
	s.set_level(5)
	assert_eq(s.initial_mask_db("right", 1000), 70, "left air 60 + 10, no occlusion through a gap")
	var fresh := _session(_head("unknown_bone", 60, 0))
	_air_both(fresh)
	fresh.configure({"test": &"bc_masked"})
	assert_eq(fresh.initial_mask_db("right", 1000), 80, "no bone measured yet: occlusion assumed (+10)")
	assert_eq(s.overmask_limit_db("right", 1000, 5), 45, "bone: tone + 40")
	s.toggle_mask()
	s.set_mask_level(70)
	assert_eq(s.mask_status(), &"impossible")


## Masked air: the leak limit is the test ear's BONE + 40, not the tone.
func test_air_overmask_uses_bone() -> void:
	var s := _bonnie()
	_air_both(s, true)
	s.configure({"test": &"ac_masked"})
	s.toggle_mask()
	s.set_freq(1000)
	# no masked bone yet: the unmasked bone (left cochlea, 0) is the conservative stand-in
	assert_eq(s.overmask_limit_db("right", 1000, 50), 40)
	s.set_mask_level(40)
	s.set_level(50)
	assert_eq(s.mask_status(), &"over")
	s.set_mask_level(20)
	assert_eq(s.mask_status(), &"ok")


# ---------------------------------------------------------------- the masker noise

static func _peak(buf: PackedVector2Array) -> Vector2:
	var p := Vector2.ZERO
	for v: Vector2 in buf:
		p = Vector2(maxf(p.x, absf(v.x)), maxf(p.y, absf(v.y)))
	return p


static func _rms(buf: PackedVector2Array, right: bool, from: int = 0) -> float:
	var sum := 0.0
	for i in range(from, buf.size()):
		var v := buf[i].y if right else buf[i].x
		sum += v * v
	return sqrt(sum / maxf(1.0, buf.size() - from))


## Goertzel power of one channel at a frequency (narrow-band check).
static func _power_at(buf: PackedVector2Array, f: float, from: int) -> float:
	var w := TAU * f / ToneGenerator.MIX_RATE
	var k := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in range(from, buf.size()):
		var s0 := buf[i].x + k * s1 - s2
		s2 = s1
		s1 = s0
	return s1 * s1 + s2 * s2 - k * s1 * s2


## Narrow-band noise in ONE ear, quiet (under its own ceiling at any dial), ramped in and out,
## centred on the test frequency, louder as the dial goes up.
func test_masker_noise_is_safe_and_narrow() -> void:
	var g := ToneGenerator.new()
	(g.get("_m_rng") as RandomNumberGenerator).seed = 2024   # the noise is random: keep the test steady
	var cap := AudioSafety.masker_ceiling()
	g.start_masker("left", 1000.0, 110.0)
	var buf := g.render(ToneGenerator.MIX_RATE / 2)
	var pk := _peak(buf)
	assert_true(pk.x <= cap + 1e-6, "left peak %f under the masker ceiling %f" % [pk.x, cap])
	assert_true(pk.x > 0.0, "the noise plays")
	assert_eq(pk.y, 0.0, "nothing in the right ear")
	assert_true(absf(buf[0].x) < cap * 0.05, "ramped in, no click")
	# narrow band: far more energy at 1 kHz than three octaves away
	# (polish) averaged over a few bins: one Goertzel bin of noise scatters a lot
	var p_in := 0.0
	var p_out := 0.0
	for d: float in [-60.0, -30.0, 0.0, 30.0, 60.0]:
		p_in += _power_at(buf, 1000.0 + d, 4000)
		p_out += _power_at(buf, 8000.0 + d, 4000)
	assert_true(p_in > 20.0 * p_out, "centred on 1 kHz (%f vs %f)" % [p_in, p_out])
	# louder dial, more noise (well under the cap)
	var lo := ToneGenerator.new()
	lo.start_masker("left", 1000.0, 20.0)
	var hi := ToneGenerator.new()
	hi.start_masker("left", 1000.0, 40.0)
	var r_lo := _rms(lo.render(ToneGenerator.MIX_RATE / 4), false, 4000)
	var r_hi := _rms(hi.render(ToneGenerator.MIX_RATE / 4), false, 4000)
	assert_true(r_hi > r_lo * 2.0, "40 dB EM louder than 20 (%f vs %f)" % [r_hi, r_lo])
	# off: ramps out to exact silence
	g.stop_masker()
	g.render(ToneGenerator.MIX_RATE / 10)
	var after := g.render(1000)
	assert_eq(_peak(after), Vector2.ZERO, "silent after stop")
	# a tone in the right ear and noise in the left stay in their own channels, both capped
	var both := ToneGenerator.new()
	both.start_masker("left", 2000.0, 60.0)
	both.start_tone("right", 2000.0, 120.0)
	var b := both.render(ToneGenerator.MIX_RATE / 4)
	var pb := _peak(b)
	assert_true(pb.x <= cap + 1e-6, "noise capped while a tone plays")
	assert_true(pb.y <= AudioSafety.peak_ceiling() + 1e-6, "tone capped")
	assert_true(pb.y > pb.x, "the tone is louder than the hiss")
	for n: Node in [g, lo, hi, both]:
		n.free()


## (Polish) The masker never drops out when a beep ends mid-buffer: the noise channel keeps
## playing across a stop_tone() boundary (it used to be zeroed for the rest of the buffer).
func test_masker_survives_tone_stop() -> void:
	var g := ToneGenerator.new()
	g.start_masker("left", 1000.0, 50.0)
	g.render(ToneGenerator.MIX_RATE / 10)   # masker fully ramped in
	g.start_tone("right", 1000.0, 40.0)
	g.render(ToneGenerator.MIX_RATE / 10)
	g.stop_tone()
	var buf := g.render(ToneGenerator.MIX_RATE / 10)   # the tone ramps out early in this buffer
	var zeros := 0
	for i in buf.size():
		if buf[i].x == 0.0:
			zeros += 1
	assert_true(zeros < 5, "masker channel silent in %d of %d samples after stop_tone()" % [zeros, buf.size()])
	assert_eq(buf[buf.size() - 1].y, 0.0, "the tone itself has ramped out")
	g.free()


## (Polish) Unmasked air truth follows the cross-hearing model: for a dead right ear the accurate
## unmasked stamp is the shadow curve (the left cochlea + IA), not the ear's own threshold.
func test_unmasked_air_truth_is_the_shadow_curve() -> void:
	var p := _head("dead_right", 0, 0)
	for f: int in ClinicRules.AC_FREQS:
		p.thresholds_right[f] = 110
	for f: int in ClinicRules.BC_FREQS:
		p.bc_right[f] = 110
	p.ia_phones_db = 60
	var s := AudiometrySession.new(p, 3)
	assert_eq(s.test, &"ac")
	assert_eq(s.response_truth("right", 1000), 60, "shadow: left cochlea 0 + 60 dB IA")
	assert_eq(s.response_truth("left", 1000), 0)
	# Bonnie's and Gus's air truths are their own thresholds (no crossing at their levels)
	var b := AudiometrySession.new(Game.load_patient("bonnie") as PatientProfile, 3)
	var g := AudiometrySession.new(Game.load_patient("gus") as PatientProfile, 3)
	for f: int in ClinicRules.AC_FREQS:
		assert_eq(b.response_truth("right", f), b.patient.get_threshold("right", f), "Bonnie right %d" % f)
		assert_eq(g.response_truth("left", f), g.patient.get_threshold("left", f), "Gus left %d" % f)
	g.sim.swapped = true
	assert_eq(g.response_truth("right", 4000), 55, "swapped phones still score the requested ear")


## Bone channel: the tone plays in the test ear and, 10 dB softer, in the other ear (bone has no
## interaural attenuation); air stays in one channel. Both through the safe mapping and clamp.
func test_bone_tone_reaches_both_channels() -> void:
	var g := ToneGenerator.new()
	g.bone = true
	g.start_tone("right", 1000.0, 60.0)
	var buf := g.render(ToneGenerator.MIX_RATE / 4)
	var near := _rms(buf, true, 4000)
	var far := _rms(buf, false, 4000)
	assert_true(near > 0.0)
	assert_near(linear_to_db(far / near), ToneGenerator.BONE_CROSS_DB, 0.2, "the far side is 10 dB softer")
	assert_true(_peak(buf).y <= AudioSafety.peak_ceiling() + 1e-6)
	assert_true(absf(buf[0].x) < 1e-3 and absf(buf[0].y) < 1e-3, "ramped in")
	# with masking noise in the far ear, both add up and stay under the tone ceiling
	g.start_masker("left", 1000.0, 110.0)
	g.set_level(200.0)
	var mix := g.render(ToneGenerator.MIX_RATE / 4)
	assert_true(_peak(mix).x <= AudioSafety.peak_ceiling() + 1e-6, "tone + noise capped")
	# air: one channel only
	var a := ToneGenerator.new()
	a.start_tone("left", 1000.0, 60.0)
	var ab := a.render(ToneGenerator.MIX_RATE / 8)
	assert_eq(_peak(ab).y, 0.0, "air tone: nothing in the right channel")
	g.free()
	a.free()


# ---------------------------------------------------------------- pronouns and names

func test_patient_pronouns_and_names() -> void:
	var gus := Game.load_patient("gus") as PatientProfile
	var bonnie := Game.load_patient("bonnie") as PatientProfile
	assert_eq(gus.short_name(), "Gus")
	assert_eq(bonnie.short_name(), "Bonnie")
	assert_eq(gus.pronoun, "he")
	assert_eq(bonnie.pronoun, "she")
	var anon := _head("x", 10, 10)
	anon.display_name = "Pat Example"
	assert_eq(anon.short_name(), "Pat", "no nickname: the first word")
	assert_eq(PatientProfile.pronouns("{He} took {his} hat; give {him} {His} coat, {he} said.", "she"), "She took her hat; give her Her coat, she said.")
	assert_eq(PatientProfile.pronouns("{He} {his} {him}", "they"), "They their them")
	assert_eq(bonnie.say("{name} wobbled: on {him}"), "Bonnie wobbled: on her")
	# Day 1 text is exactly what it was for Gus
	var sg := AudiometrySession.new(gus, 1)
	assert_eq(sg.tip_text(&"rhythmic"), "He's learned your groove and presses on the beat! Vary the gaps between beeps.")
	assert_eq(sg.tip_text(&"too_loud"), "Hair blast! Way above his threshold. Come back down gently.")
	assert_eq(sg.tip_text(&"short_gap"), "Leave at least a beep's worth of quiet between beeps, or he guesses.")
	var sb := AudiometrySession.new(bonnie, 1)
	assert_eq(sb.tip_text(&"not_instructed"), "She's pressing for the air-con hum! Always say: press for EVERY beep.")
	assert_eq(sb.tip_text(&"retest_mismatch"), "Retest is off by more than 5 dB: re-instruct her and recheck the earlier pitches.")
	for k: StringName in AudiometrySession.TIPS:
		for s: AudiometrySession in [sg, sb]:
			var t := s.tip_text(k)
			assert_true(t.find("{") < 0, "no raw token in %s" % k)
			assert_true(t.split(" ", false).size() <= 18, "%s: 18 words max" % k)
