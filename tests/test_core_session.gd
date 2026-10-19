extends TestCase
## Builder A: the audiometry session (core/audiometry_session.gd). Hughson-Westlake step
## checks, the 2-of-3 ascending threshold rule, test order and retest, par / golf, combo,
## points, scoring and the results shape (CONTRACTS.md §4.4, §4.5, §5.1).


## A perfectly consistent patient: hears iff level >= threshold, fixed latency, no tricks.
class FixedSim extends PatientSim:
	var latency := 0.5
	var force: Dictionary = {}  ## db -> heard override, for scripted trails

	func _init(p: PatientProfile) -> void:
		super(p, 1)

	func on_tone_start(ear: String, freq: int, db: int, _gap_s: float) -> Dictionary:
		var heard: bool = force.get(db, db >= effective_threshold(ear, freq))
		return {"heard": heard, "press": heard, "guess": false, "latency_s": latency}

	func false_alarm_tick(_delta: float) -> bool:
		return false

	func anticipation_delay() -> float:
		return -1.0

	func keeps_press_after_short_tone(_e: String, _f: int, _d: int, _dur: float) -> bool:
		return true


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
var _n := 0


func _session(seed_value: int = 5) -> AudiometrySession:
	var s := AudiometrySession.new(Game.load_patient("gus") as PatientProfile, seed_value)
	s.sim = FixedSim.new(s.patient)
	return s


func _kinds(s: AudiometrySession) -> Array:
	var out := []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: out.append(k))
	return out


## One presentation: varied gap, 1.5 s tone, then the response window. Returns responded.
func _present(s: AudiometrySession, duration: float = 1.5) -> bool:
	_tick(s, GAPS[_n % GAPS.size()])
	_n += 1
	var got := [false]
	var cb := func(_e: String, _f: int, _d: int, related: bool) -> void:
		if related:
			got[0] = true
	s.responded.connect(cb)
	s.tone_down()
	_tick(s, duration)
	s.tone_up()
	_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)
	s.responded.disconnect(cb)
	return got[0]


func _tick(s: AudiometrySession, seconds: float) -> void:
	var steps := int(round(seconds / 0.05))
	for i in steps:
		s.advance(0.05)


## Play only what recommended_action() says until the ear is complete.
func _play_by_the_book(s: AudiometrySession, e: String) -> void:
	s.set_ear(e)
	var guard := 0
	while not s.is_ear_complete(e) and guard < 400:
		guard += 1
		var rem := s.required_remaining(e)
		if s.measurement(e, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
			s.set_freq(rem[0])
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(s)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"store":
				s.store()
			&"no_response":
				s.store_no_response()
			_:
				_tick(s, 0.1)


# ---------------------------------------------------------------- par

func test_textbook_presentations_known_values() -> void:
	# start 40, threshold 25: 40 H, 30 H, 20 M, 25 H(1), 15 M, 20 M, 25 H(2) = 7
	assert_eq(AudiometrySession.textbook_presentations(40, 25, 1000), 7)
	# threshold 40: 40 H, 30 M, 35 M, 40 H(1), 30 M, 35 M, 40 H(2) = 7
	assert_eq(AudiometrySession.textbook_presentations(40, 40, 1000), 7)
	# threshold 50: 40 M, 50 H (familiarisation, not counted), 40 M, 45 M, 50 H(1), 40 M, 45 M, 50 H(2) = 8
	assert_eq(AudiometrySession.textbook_presentations(40, 50, 1000), 8)
	# threshold 20: 40 H, 30 H, 20 H, 10 M, 15 M, 20 H(1), 10 M, 15 M, 20 H(2) = 9
	assert_eq(AudiometrySession.textbook_presentations(40, 20, 1000), 9)
	# 8 kHz, threshold 65: 40 M, 50 M, 60 M, 70 H(1), 60 M, 65 H(1), 55 M, 60 M, 65 H(2) = 9
	assert_eq(AudiometrySession.textbook_presentations(40, 65, 8000), 9)
	# beyond the audiometer (250 Hz max 90): 40, 50, 60, 70, 80, 90 all missed = 6
	assert_eq(AudiometrySession.textbook_presentations(40, 105, 250), 6)


func test_par_is_the_typical_textbook_search() -> void:
	var s := _session()
	var t := s.patient.get_threshold("right", 1000)
	var slope := s.patient.psychometric_slope_db
	var typical := AudiometrySession.expected_presentations(40 - t, 120 - t, -10 - t, slope)
	assert_eq(s.par_for("right", 1000), int(round(typical)) + AudiometrySession.PAR_SLACK, "before any tone: from the dial level")
	assert_true(s.par_for("right", 1000) >= AudiometrySession.textbook_presentations(40, t, 1000), "never below the lucky minimum")
	assert_eq(AudiometrySession.expected_presentations(40 - t, 120 - t, -10 - t, slope), typical, "deterministic (cached, fixed seed)")
	var par40 := s.par_for("right", 1000)
	s.set_level(70)
	_present(s)
	s.set_level(90)
	assert_eq(s.par_for("right", 1000), par40, "par comes from the recommended start, not from where the player began")


# ---------------------------------------------------------------- HW steps

func test_textbook_steps_build_a_combo() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_level(40)
	assert_true(_present(s), "40 heard")
	s.set_level(30)
	assert_true(_present(s), "30 heard")
	s.set_level(20)
	assert_false(_present(s), "20 missed")
	s.set_level(25)
	assert_true(_present(s), "25 heard")
	assert_eq(kinds.count(&"good_start"), 1)
	assert_eq(kinds.count(&"textbook_step"), 3)
	assert_false(kinds.has(&"wrong_step"))
	assert_eq(s.combo, 4)
	assert_true(s.points > 0, "points for textbook steps")


func test_down_five_after_a_hit_is_a_wrong_step() -> void:
	var s := _session()
	var data := []
	s.technique.connect(func(k: StringName, d: Dictionary) -> void:
		if k == &"wrong_step":
			data.append(d))
	s.set_level(60)
	_present(s)
	s.set_level(55)
	_present(s)
	assert_eq(data.size(), 1)
	assert_eq(int(data[0]["expected"]), 50)
	assert_eq(int(data[0]["got"]), 55)
	assert_true(String(data[0]["message"]).length() > 0, "lesson text")
	assert_eq(s.combo, 0, "combo broken")


func test_up_ten_after_a_miss_once_heard_is_a_wrong_step() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_level(40)
	_present(s)  # heard
	s.set_level(30)
	_present(s)  # heard
	s.set_level(20)
	_present(s)  # missed
	s.set_level(30)  # should be 25
	_present(s)
	assert_has(kinds, &"wrong_step")


func test_initial_search_goes_up_in_tens() -> void:
	var s := _session()
	s.set_freq(8000)  # Gus right 8 kHz = 65
	var kinds := _kinds(s)
	s.set_level(40)
	assert_false(_present(s))
	s.set_level(50)
	assert_false(_present(s))
	s.set_level(70)  # +20 is tolerated in the familiarisation search
	assert_true(_present(s))
	assert_false(kinds.has(&"wrong_step"), str(kinds))


func test_start_too_high() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_level(80)
	_present(s)
	assert_has(kinds, &"start_too_high")


# ---------------------------------------------------------------- threshold rule

func test_threshold_needs_two_ascending_hits() -> void:
	var s := _session()
	for lvl: int in [40, 30, 20, 25]:
		s.set_level(lvl)
		_present(s)
	assert_eq(s.ascending_threshold("right", 1000), null, "one ascending hit is not enough")
	assert_eq(s.ascending_hits("right", 1000, 25), 1)
	for lvl: int in [15, 20, 25]:
		s.set_level(lvl)
		_present(s)
	assert_eq(s.ascending_threshold("right", 1000), 25, "two ascending hits at 25")


## (polish) Heard twice at -10 dB HL, the bottom of the scale: nothing softer to bracket from, so
## -10 is the threshold (a store there is by the book, and the coach says store).
func test_floor_response_counts_as_threshold() -> void:
	var s := _session()
	var sim := s.sim as FixedSim
	for lvl: int in [40, 30, 20, 10, 0, -10]:
		sim.force = {lvl: true}
		s.set_level(lvl)
		_present(s)
	assert_eq(s.ascending_threshold("right", 1000), null, "one floor hit is not enough")
	_present(s)
	assert_eq(s.ascending_threshold("right", 1000), ClinicRules.MIN_DB, "heard twice at the floor")
	assert_eq(StringName(s.recommended_action()["action"]), &"store")
	var kinds := _kinds(s)
	var info := s.store()
	assert_false(kinds.has(&"store_without_bracket"))
	assert_eq(int(info["stored_db"]), ClinicRules.MIN_DB)
	# a consistent patient at the floor: the lucky minimum ends on the second floor hit
	assert_eq(AudiometrySession.textbook_presentations(40, -10, 1000), 7)


func test_threshold_needs_half_of_the_ascending_runs() -> void:
	var s := _session()
	var sim := s.sim as FixedSim
	# Scripted wobbly patient at 1 kHz: 25 heard, then missed twice on the way up, then heard.
	var script := [[40, true], [30, true], [20, false], [25, true], [15, false], [20, false], [25, false], [30, true], [20, false], [25, false], [30, true]]
	for step: Array in script:
		sim.force = {int(step[0]): bool(step[1])}
		s.set_level(int(step[0]))
		_present(s)
	# 25: 1 hit of 3 ascending runs -> not threshold. 30: 2 hits of 2 -> threshold.
	assert_eq(s.ascending_threshold("right", 1000), 30)


func test_store_rules() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_level(40)
	_present(s)
	s.store()  # no bracket at all
	assert_has(kinds, &"store_without_bracket")
	kinds.clear()
	# 2 kHz properly bracketed, stored at the wrong level
	s.set_freq(2000)  # Gus right 2k = 40
	for lvl: int in [50, 40, 30, 35, 40, 30, 35, 40]:
		s.set_level(lvl)
		_present(s)
	assert_eq(s.ascending_threshold("right", 2000), 40)
	s.set_level(45)
	var info := s.store()
	assert_has(kinds, &"store_wrong_level")
	assert_eq(int(info["candidate_db"]), 40)
	assert_false(bool(info["technique_ok"]))


func test_start_not_1k_and_lows_before_the_retest() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_freq(2000)
	for lvl: int in [50, 40, 30, 35, 40, 30, 35, 40]:
		s.set_level(lvl)
		_present(s)
	s.store()
	assert_has(kinds, &"start_not_1k")
	kinds.clear()
	s.set_freq(1000)
	for lvl: int in [40, 30, 20, 25, 15, 20, 25]:
		s.set_level(lvl)
		_present(s)
	s.store()
	s.set_freq(500)  # Gus right 500 = 20, before the 1 kHz retest
	for lvl: int in [40, 30, 20, 10, 15, 20, 10, 15, 20]:
		s.set_level(lvl)
		_present(s)
	s.store()
	# (E2) BSA retests after 250 Hz, ASHA before 500: either is fine, and the retest is still owed
	assert_false(kinds.has(&"missed_retest"), "lows before the retest are not an error")
	assert_has(s.required_remaining("right"), 1000, "the first ear still owes its retest")


## (E2) The 1 kHz retest is owed by the first air ear of the visit only (ASHA 2005; BSA 2018, 6.4).
func test_retest_first_ear_only() -> void:
	var s := _session()
	_play_by_the_book(s, "right")
	assert_false((s.retest["right"] as Dictionary).is_empty(), "the first ear retested 1 kHz")
	assert_eq(s.air_ear_order, ["right"] as Array[String])
	assert_true(s.retest_required("right"))
	assert_false(s.retest_required("left"), "the second ear does not owe it")
	_play_by_the_book(s, "left")
	assert_true(s.is_ear_complete("left"), "the left ear closes without a retest")
	assert_true((s.retest["left"] as Dictionary).is_empty())
	assert_eq((s.order["left"] as Array).count(1000), 1, "1 kHz once on the second ear")


## (E2) The second ear owes a retest when the first ear's was off by more than 5 dB; a waived first
## ear (Hoot's montage) passes nothing on; the left-first visit makes the left ear the one.
func test_retest_second_ear_after_a_mismatch() -> void:
	var s := _session()
	s.air_ear_order = ["right"] as Array[String]
	(s.sheet(&"ac")["retest"] as Dictionary)["right"] = {"stored_db": 40, "diff": 15, "strokes": 6, "par": 6, "first_db": 25}
	assert_true(s.retest_required("left"), "a 15 dB mismatch on the first ear: retest the second too")
	(s.sheet(&"ac")["retest"] as Dictionary)["right"] = {"stored_db": 30, "diff": 5, "strokes": 6, "par": 6, "first_db": 25}
	assert_false(s.retest_required("left"), "within 5 dB: the second ear is free")
	var s2 := _session()
	s2.retest_waived["left"] = true
	s2.air_ear_order = ["left"] as Array[String]
	assert_false(s2.retest_required("left"), "a waived ear never owes it")
	assert_false(s2.retest_required("right"), "and the next ear is a second ear")
	var s3 := _session()
	s3.set_ear("left")
	assert_true(s3.retest_required("left"), "nothing stored yet: whichever ear comes first owes it")
	assert_true(s3.retest_required("right"))


func test_retest_ok_and_mismatch() -> void:
	var s := _session()
	var kinds := _kinds(s)
	for lvl: int in [40, 30, 20, 25, 15, 20, 25]:
		s.set_level(lvl)
		_present(s)
	s.store()
	s.set_freq(2000)
	for lvl: int in [50, 40, 30, 35, 40, 30, 35, 40]:
		s.set_level(lvl)
		_present(s)
	s.store()
	s.set_freq(1000)
	assert_eq(s.measurement_kind("right", 1000), &"retest")
	for lvl: int in [35, 25, 15, 20, 25, 15, 20, 25]:
		s.set_level(lvl)
		_present(s)
	var info := s.store()
	assert_true(bool(info["retest"]))
	assert_has(kinds, &"retest_ok")
	assert_eq(int((s.retest["right"] as Dictionary)["diff"]), 0)
	assert_eq(int(s.stored["right"][1000]["stored_db"]), 25, "first 1 kHz result kept")


func test_no_response_rules() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_freq(250)
	s.set_level(40)
	_present(s)
	s.store_no_response()
	assert_has(kinds, &"nr_too_early")
	var info: Dictionary = s.stored["right"][250]
	assert_true(bool(info["no_response"]))
	assert_eq(int(info["stored_db"]), ClinicRules.max_db(250))


func test_required_order_with_interoctave() -> void:
	var s := _session()
	s.set_ear("left")  # Gus left: 1k 25, 2k 45 -> 1.5 kHz needed
	assert_eq(s.required_remaining("left"), [1000, 2000, 4000, 8000, 500, 250] as Array[int])
	_play_by_the_book(s, "left")
	assert_true(s.is_ear_complete("left"), "left ear done by the book")
	var order: Array = s.order["left"]
	assert_eq(order.slice(0, 2), [1000, 2000])
	assert_true(order.has(1500), "1.5 kHz tested")
	assert_true(order.find(1500) < order.find(4000), "the half-octave comes right after its neighbours")
	assert_eq(order.count(1000), 2, "1 kHz retest")


func test_textbook_play_scores_high() -> void:
	var s := _session()
	_play_by_the_book(s, "right")
	_play_by_the_book(s, "left")
	var r := s.build_results()
	for k in ["patient_id", "patient_name", "ears", "technique_errors", "presentations", "false_alarms", "max_combo", "accuracy", "technique", "efficiency", "score", "grade", "duration_s", "points"]:
		assert_has(r, k, "results")
	assert_eq(float(r["technique"]), 1.0, "no technique errors: %s" % str(r["technique_errors"]))
	assert_eq(float(r["accuracy"]), 1.0, "a consistent patient is found exactly")
	assert_true(float(r["efficiency"]) >= 0.95, "efficiency %f" % float(r["efficiency"]))
	assert_eq(r["grade"], "S")
	assert_true(int(r["max_combo"]) >= 10, "long combo")
	for e: String in ["right", "left"]:
		var er: Dictionary = r["ears"][e]
		for k in ["freqs", "complete", "retest_1k", "order", "strokes", "par", "accuracy", "shape", "pta", "coached"]:
			assert_has(er, k, "ears." + e)
		assert_true(bool(er["complete"]))
		assert_eq(er["shape"], &"sloping")
		for f: int in er["freqs"]:
			var info: Dictionary = er["freqs"][f]
			for k in ["ear", "freq", "stored_db", "true_db", "error_db", "no_response", "strokes", "par", "golf", "accuracy", "errors", "technique_ok", "retest", "masked", "order_index"]:
				assert_has(info, k, "freq info")
			assert_true(int(info["strokes"]) <= int(info["par"]), "%s %d: strokes %d par %d" % [e, f, int(info["strokes"]), int(info["par"])])


func test_golf_and_combo_events() -> void:
	var s := _session()
	var kinds := _kinds(s)
	var combos := []
	s.combo_changed.connect(func(n: int, m: int) -> void: combos.append([n, m]))
	for lvl: int in [40, 30, 20, 25, 15, 20, 25]:
		s.set_level(lvl)
		_present(s)
	var info := s.store()
	assert_eq(int(info["strokes"]), 7)
	assert_true(int(info["par"]) >= 7, "par is never below the lucky minimum")
	assert_eq(info["golf"], ClinicRules.golf_name(7, int(info["par"])))
	if info["golf"] in [&"birdie", &"eagle", &"albatross"]:
		assert_has(kinds, info["golf"], "under par is announced")
	assert_eq(combos[-1], [8, 3], "8 clean checks -> x3")


func test_timing_and_rhythm_errors() -> void:
	var s := _session()
	var kinds := _kinds(s)
	s.set_level(40)
	_present(s, 0.2)
	assert_has(kinds, &"tone_too_short")
	s.set_level(30)
	_present(s, 3.5)
	assert_has(kinds, &"tone_too_long")
	kinds.clear()
	for i in 9:  # identical gaps
		_tick(s, 1.0)
		s.tone_down()
		_tick(s, 1.2)
		s.tone_up()
	assert_has(kinds, &"rhythmic")


func test_short_blip_is_thrown_away_and_the_level_kept() -> void:
	var s := _session()
	(s.sim as FixedSim).latency = 0.6
	s.set_level(40)
	var kinds := _kinds(s)
	s.tone_down()
	_tick(s, 0.2)
	s.tone_up()  # FixedSim keeps presses after short tones: answered later, so it stands
	_tick(s, 2.0)
	assert_eq(s.trail("right", 1000).size(), 1, "an answered blip is kept")
	assert_has(kinds, &"tone_too_short")


func test_unheard_blip_is_voided() -> void:
	var s := AudiometrySession.new(Game.load_patient("gus") as PatientProfile, 4)
	s.set_level(40)
	s.tone_down()
	s.advance(0.1)
	s.tone_up()  # 0.1 s: shorter than any reaction time; a kept press still lands in the window
	_tick(s, 2.0)
	if s.trail("right", 1000).is_empty():
		assert_true(s.last_short, "the coach knows it was too quick")
		assert_eq(s.recommended_action()["action"], &"present", "same level again")
		assert_eq(s.db, 40)
	else:
		assert_true(bool(s.trail("right", 1000)[0]["responded"]), "only an answered blip survives")


func test_retest_starts_just_above_the_first_1k() -> void:
	var s := _session()
	_play_until_retest(s)
	assert_eq(s.freq, 1000)
	assert_eq(s.db, mini(int(s.stored["right"][1000]["stored_db"]) + 10, ClinicRules.START_DB), "retest start")
	assert_eq(s.recommended_action()["action"], &"present")


func _play_until_retest(s: AudiometrySession) -> void:
	var guard := 0
	while s.measurement_kind("right", s.freq) != &"retest" and guard < 300:
		guard += 1
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(s)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"store":
				s.store()
			&"no_response":
				s.store_no_response()
			_:
				_tick(s, 0.1)


func test_coach_following_never_blasts() -> void:
	# Regression (audiology review): following recommended_action() must never cost a heart.
	var loud := [0]
	for seed_value in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]:
		var s := AudiometrySession.new(Game.load_patient("gus") as PatientProfile, seed_value)
		s.technique.connect(func(k: StringName, _d: Dictionary) -> void:
			if k == &"too_loud":
				loud[0] += 1)
		_follow_coach(s, "right")
		_follow_coach(s, "left")
		assert_true(s.is_ear_complete("right") and s.is_ear_complete("left"), "seed %d complete" % seed_value)
	assert_eq(int(loud[0]), 0, "too_loud events while following the coach")


## Exactly what the coach says, including where the session leaves the dial after a stamp.
func _follow_coach(s: AudiometrySession, e: String) -> void:
	if s.ear != e:
		s.set_ear(e)
		s.set_freq(ClinicRules.START_FREQ)
		s.set_level(ClinicRules.START_DB)
	var guard := 0
	while not s.is_ear_complete(e) and guard < 600:
		guard += 1
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(s)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"store":
				s.store()
			&"no_response":
				s.store_no_response()
			_:
				_tick(s, 0.1)


func test_fair_golf() -> void:
	assert_eq(ClinicRules.fair_golf(20, 10, true), &"par", "a clean hole is never worse than par")
	assert_eq(ClinicRules.fair_golf(3, 10, false), &"par", "a hole with errors is never better than par")
	assert_eq(ClinicRules.fair_golf(7, 10, true), &"birdie")
	assert_eq(ClinicRules.fair_golf(14, 10, false), &"double_bogey")


func test_hoot_turn_does_not_score() -> void:
	var s := _session()
	_play_by_the_book(s, "right")
	var r0 := s.build_results()
	s.scoring = false
	_play_by_the_book(s, "left")
	var r := s.build_results()
	assert_true(bool(r["ears"]["left"]["complete"]))
	assert_eq(int(r["presentations"]), int(r0["presentations"]), "Hoot's beeps are not the player's")
	assert_eq(int(r["points"]), int(r0["points"]), "no points for Hoot")
	assert_eq(float(r["technique"]), float(r0["technique"]))
	assert_eq(int(r["ears"]["left"]["hoot_holes"]), (r["ears"]["left"]["order"] as Array).size())
	for f: int in r["ears"]["left"]["freqs"]:
		assert_eq(r["ears"]["left"]["freqs"][f]["golf"], &"hoot")


func test_too_loud_costs_comfort_once_per_measurement() -> void:
	var s := _session()
	var loud := []
	s.technique.connect(func(k: StringName, d: Dictionary) -> void:
		if k == &"too_loud":
			loud.append(int(d["comfort_loss"])))
	var reactions := []
	s.reaction.connect(func(k: StringName, _d: Dictionary) -> void: reactions.append(k))
	s.set_level(90)
	_present(s)
	s.set_level(80)
	_present(s)
	assert_eq(loud, [1, 1 - 1], "only the first blast costs a heart")
	assert_has(reactions, &"too_loud_blast")


func test_recommended_action_follows_the_dance() -> void:
	var s := _session()
	assert_eq(s.recommended_action()["action"], &"present")
	_present(s)  # 40 heard
	var a := s.recommended_action()
	assert_eq(a["action"], &"softer")
	assert_eq(int(a["target_db"]), 30)
	s.set_level(30)
	_present(s)
	s.set_level(20)
	_present(s)  # missed
	a = s.recommended_action()
	assert_eq(a["action"], &"louder")
	assert_eq(int(a["target_db"]), 25)


func test_trail_hides_the_truth() -> void:
	var s := _session()
	_present(s)
	var t := s.trail("right", 1000)
	assert_eq(t.size(), 1)
	assert_false(t[0].has("heard"), "public trail has no hidden truth")
	assert_true(bool(t[0]["responded"]))


func test_real_patient_textbook_play_lands_near_truth() -> void:
	# The real (noisy) simulator: a by-the-book player should be within 5 dB nearly always.
	var off := 0
	var total := 0
	var strokes := 0
	var par := 0
	for seed_value in [3, 17, 99]:
		var s := AudiometrySession.new(Game.load_patient("gus") as PatientProfile, seed_value)
		_play_by_the_book(s, "right")
		_play_by_the_book(s, "left")
		var r := s.build_results()
		for e: String in ["right", "left"]:
			strokes += int(r["ears"][e]["strokes"])
			par += int(r["ears"][e]["par"])
			for f: int in r["ears"][e]["freqs"]:
				total += 1
				var err := absf(float(r["ears"][e]["freqs"][f]["error_db"]))
				assert_true(err <= 10.0, "%s %d Hz within 10 dB" % [e, f])
				if err > 5.0:
					off += 1
	assert_true(off <= 3, "%d of %d thresholds more than 5 dB off" % [off, total])
	assert_between(float(strokes) / par, 0.8, 1.35, "par is fair for a careful player (strokes %d, par %d)" % [strokes, par])


## (E8) A steady tone near the patient's tinnitus pitch: the session tells the simulator, and Hoot's
## tip about pulsed or warble beeps fires once; pulsed tones (the E7 default) never trigger it.
func test_tinnitus_tip_on_steady_tones() -> void:
	var p := Game.load_patient("rocco") as PatientProfile
	assert_eq(p.tinnitus_hz, 4000, "Rocco rings at 4 kHz")
	var s := AudiometrySession.new(p, 5)
	var kinds := []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	s.set_freq(4000)
	s.tone_down()
	s.tone_up()
	assert_false(kinds.has(&"tinnitus_steady"), "pulsed by default: no tip")
	assert_false(s.sim.steady_tone)
	s.set_steady_tone(true)
	assert_true(s.sim.steady_tone, "the simulator hears a steady tone")
	s.advance(2.0)
	s.tone_down()
	s.tone_up()
	assert_eq(kinds.count(&"tinnitus_steady"), 1, "the tip fires")
	s.advance(2.0)
	s.tone_down()
	s.tone_up()
	assert_eq(kinds.count(&"tinnitus_steady"), 1, "once per visit")
