extends TestCase
## Builder A: the patient simulator (core/patient_sim.gd). Psychometric curve, reaction time,
## false alarms, groove / anticipation, swapped earphones, short tones.


func _gus() -> PatientProfile:
	return Game.load_patient("gus") as PatientProfile


func _attentive() -> PatientProfile:
	var p := _gus().duplicate() as PatientProfile
	p.attention = 1.0
	p.fatigue_per_tone = 0.0
	p.psychometric_slope_db = 1.7
	return p


func test_psychometric_curve_shape() -> void:
	var sim := PatientSim.new(_attentive(), 11)
	var t := sim.effective_threshold("right", 1000)
	assert_eq(t, 25, "Gus right 1 kHz")
	# The 50 % point sits THRESHOLD_BIAS_DB below the profile threshold, so a textbook
	# 2-of-3 ascending search lands on the profile value most of the time.
	var at_t := 1.0 / (1.0 + exp(-PatientSim.THRESHOLD_BIAS_DB / 1.7))
	assert_near(sim.hear_probability("right", 1000, t), at_t, 0.03, "about 76 % at threshold")
	assert_between(sim.hear_probability("right", 1000, t + 5), 0.96, 0.995, "about 98 % at +5")
	assert_between(sim.hear_probability("right", 1000, t - 5), 0.10, 0.20, "about 15 % at -5")
	assert_true(sim.hear_probability("right", 1000, t + 20) > 0.999, "loud tones always heard")
	assert_true(sim.hear_probability("right", 1000, t - 20) < 0.001, "very soft tones never heard")
	var prev := 0.0
	for lvl in range(-10, 80, 5):
		var p := sim.hear_probability("right", 1000, lvl)
		assert_true(p >= prev, "monotonic at %d" % lvl)
		prev = p


func test_psychometric_sampling_matches_curve() -> void:
	var sim := PatientSim.new(_attentive(), 1234)
	var n := 2000
	var counts := {20: 0, 25: 0, 30: 0}
	for lvl: int in counts:
		for i in n:
			if bool(sim.on_tone_start("right", 1000, lvl, 1.5)["heard"]):
				counts[lvl] += 1
	assert_between(counts[25] / float(n), 0.71, 0.81, "sampled at threshold")
	assert_between(counts[30] / float(n), 0.96, 1.0, "sampled at +5")
	assert_between(counts[20] / float(n), 0.10, 0.20, "sampled at -5")


func test_inattention_only_near_threshold() -> void:
	var p := _attentive()
	p.attention = 0.6
	var sim := PatientSim.new(p, 3)
	var focused := PatientSim.new(_attentive(), 3)
	assert_true(sim.hear_probability("right", 1000, 25) < focused.hear_probability("right", 1000, 25) - 0.05, "lapses near threshold")
	assert_true(sim.hear_probability("right", 1000, 60) > 0.999, "loud tones still heard")


func test_fatigue_lowers_attention_with_floor() -> void:
	var p := _attentive()
	p.fatigue_per_tone = 0.05
	var sim := PatientSim.new(p, 5)
	for i in 40:
		sim.on_tone_start("right", 1000, 40, 1.5)
	assert_near(sim.attention, PatientSim.MIN_ATTENTION, 0.001, "attention floor")


func test_reaction_time_in_range() -> void:
	var p := _gus()
	var sim := PatientSim.new(p, 9)
	for i in 200:
		var loud := sim.reaction_time("right", 1000, 60)
		assert_between(loud, p.reaction_time_min_s, p.reaction_time_max_s, "loud tone reaction")
		var faint := sim.reaction_time("right", 1000, 25)
		assert_between(faint, p.reaction_time_min_s, p.reaction_time_max_s + PatientSim.NEAR_THRESHOLD_EXTRA_S, "faint tone reaction")
	assert_between(p.reaction_time_min_s, 0.3, 0.5, "Gus reacts in about 0.3-0.9 s")
	assert_between(p.reaction_time_max_s, 0.8, 1.0, "Gus reacts in about 0.3-0.9 s")


func test_false_alarm_rate() -> void:
	var p := _gus()
	var sim := PatientSim.new(p, 21)
	var presses := 0
	for i in 60 * 60 * 30:  # one simulated hour of silence at 30 fps
		if sim.false_alarm_tick(1.0 / 30.0):
			presses += 1
	var per_minute := presses / 60.0
	assert_between(per_minute, p.false_alarms_per_minute * 0.5, p.false_alarms_per_minute * 1.6, "profile rate")
	sim.instructed = false
	var wild := 0
	for i in 60 * 60 * 30:
		if sim.false_alarm_tick(1.0 / 30.0):
			wild += 1
	assert_true(wild > presses * 3, "an uninstructed patient presses for every hum (%d vs %d)" % [wild, presses])


func test_steady_rhythm_builds_groove_and_anticipation() -> void:
	var sim := PatientSim.new(_gus(), 4)
	for i in 6:
		sim.on_tone_start("right", 1000, 40, 1.0)
	assert_true(sim.groove >= PatientSim.ANTICIPATE_GROOVE, "groove %f" % sim.groove)
	var anticipations := 0
	for i in 50:
		var d := sim.anticipation_delay()
		if d >= 0.0:
			anticipations += 1
			assert_between(d, 0.8, 1.2, "presses on the beat")
	assert_true(anticipations > 10, "anticipates often (%d/50)" % anticipations)


func test_varied_gaps_keep_groove_low() -> void:
	var sim := PatientSim.new(_gus(), 4)
	for g: float in [0.8, 2.1, 1.2, 2.6, 0.9, 1.7, 2.4, 1.0]:
		sim.on_tone_start("right", 1000, 40, g)
	assert_true(sim.groove < PatientSim.ANTICIPATE_GROOVE, "groove %f" % sim.groove)
	assert_eq(sim.anticipation_delay(), -1.0, "no anticipation")


func test_short_gaps_cause_guesses() -> void:
	var sim := PatientSim.new(_attentive(), 77)
	var guesses := 0
	for i in 400:
		var d := sim.on_tone_start("right", 1000, 0, 0.2)  # inaudible tone, rushed gap
		assert_false(bool(d["heard"]), "0 dB HL is inaudible for Gus")
		if bool(d["guess"]):
			guesses += 1
			assert_true(bool(d["press"]), "a guess presses")
	assert_between(guesses / 400.0, 0.08, 0.24, "trigger-happy after short gaps")
	var calm := 0
	for i in 400:
		if bool(sim.on_tone_start("right", 1000, 0, 2.0)["guess"]):
			calm += 1
	assert_eq(calm, 0, "no guesses with relaxed gaps")


func test_short_tones_are_often_lost() -> void:
	var sim := PatientSim.new(_attentive(), 8)
	var kept_short := 0
	var kept_long := 0
	for i in 400:
		if sim.keeps_press_after_short_tone("right", 1000, 30, 0.1):
			kept_short += 1
		if sim.keeps_press_after_short_tone("right", 1000, 30, 1.2):
			kept_long += 1
	assert_eq(kept_long, 400, "normal tones keep the press")
	assert_true(kept_short < 200, "a 0.1 s blip near threshold is usually lost (%d/400)" % kept_short)


func test_swapped_earphones_use_the_other_ear() -> void:
	var p := _gus()
	var sim := PatientSim.new(p, 2)
	sim.swapped = true
	assert_eq(sim.effective_threshold("right", 4000), p.get_threshold("left", 4000))
	assert_eq(sim.effective_threshold("left", 4000), p.get_threshold("right", 4000))


func test_cross_hearing_hook() -> void:
	var sim := PatientSim.new(_attentive(), 2)
	assert_true(sim.hear_probability("right", 1000, 0) < 0.01)
	sim.cross_hearing = func(_e: String, _f: int, _d: int) -> float: return 1.0
	assert_near(sim.hear_probability("right", 1000, 0), 1.0, 0.0001, "the hook can make the other ear answer")


## (E8) Near the tinnitus pitch a steady tone is lost in the ring more often and the patient presses
## for nothing more often; pulsed or warble (steady_tone false) and far pitches are unchanged.
func test_tinnitus_confuses_steady_tones() -> void:
	var p := _attentive()
	p.tinnitus_hz = 4000
	var sim := PatientSim.new(p, 31)
	var t := sim.effective_threshold("right", 4000)
	var pulsed := sim.hear_probability("right", 4000, t)
	assert_false(sim.tinnitus_confuses(4000), "pulsed or warble: no confusion")
	sim.steady_tone = true
	assert_true(sim.tinnitus_confuses(4000))
	assert_true(sim.tinnitus_confuses(3000), "half an octave below")
	assert_true(sim.tinnitus_confuses(6000), "half an octave above")
	assert_false(sim.tinnitus_confuses(2000), "an octave away")
	assert_false(sim.tinnitus_confuses(8000), "an octave away")
	assert_near(sim.hear_probability("right", 4000, t), pulsed * (1.0 - PatientSim.TINNITUS_MISS_P), 0.01, "more misses at threshold")
	assert_near(sim.hear_probability("right", 4000, t + 15), 1.0, 0.01, "a clear tone is still heard")
	assert_near(sim.hear_probability("right", 1000, sim.effective_threshold("right", 1000)), pulsed, 0.05, "far from the ring: unchanged")
	var far := 0
	var near := 0
	for i in 60 * 60 * 30:  # one simulated hour of silence at 30 fps, each way
		if sim.false_alarm_tick(1.0 / 30.0, 1000):
			far += 1
		if sim.false_alarm_tick(1.0 / 30.0, 4000):
			near += 1
	assert_true(near > far * 2, "more presses for nothing near the ring (%d vs %d)" % [near, far])
	p.tinnitus_hz = 0
	assert_false(sim.tinnitus_confuses(4000), "no tinnitus, no confusion")
