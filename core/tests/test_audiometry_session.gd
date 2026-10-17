extends TestCase
## Core logic (builder A owns this file): a textbook Hughson-Westlake run on the session
## must find Gus's thresholds and produce the CONTRACTS.md §5.1 results shape.

var _gaps := [0.4, 1.3, 0.8, 1.9, 0.6, 1.5]
var _n := 0


func _present(s: AudiometrySession) -> bool:
	s.advance(_gaps[_n % _gaps.size()])
	_n += 1
	var got := [false]
	var cb := func(_e: String, _f: int, _d: int, related: bool) -> void:
		if related:
			got[0] = true
	s.responded.connect(cb)
	s.tone_down()
	for i in 15:
		s.advance(0.1)
	s.tone_up()
	for i in 21:
		s.advance(0.1)
	s.responded.disconnect(cb)
	return got[0]


func _set_level(s: AudiometrySession, db: int) -> void:
	while s.db < db:
		s.step_level(1)
	while s.db > db:
		s.step_level(-1)


## Bracket one frequency with down-10 / up-5 and store at 2 ascending hits.
func _hw(s: AudiometrySession, start: int) -> void:
	_set_level(s, start)
	var hits := {}
	var prev_heard := true
	var heard_any := false
	for i in 30:
		var heard := _present(s)
		if heard:
			if not prev_heard:
				hits[s.db] = int(hits.get(s.db, 0)) + 1
				if hits[s.db] >= 2:
					s.store()
					return
			heard_any = true
			_set_level(s, s.db - 10)
		else:
			_set_level(s, s.db + (5 if heard_any else 10))
		prev_heard = heard
	s.store()


func test_textbook_run_finds_thresholds() -> void:
	var p := Game.load_patient("gus") as PatientProfile
	var s := AudiometrySession.new(p, 4242)
	for ear: String in ["right", "left"]:
		s.ear = ear
		var guard := 0
		while not s.is_ear_complete(ear) and guard < 15:
			var f: int = s.required_remaining(ear)[0]
			s.set_freq(f)
			_hw(s, ClinicRules.clamp_db(mini(p.get_threshold(ear, f) + 15, ClinicRules.MAX_START_DB), f))
			guard += 1
		assert_true(s.is_ear_complete(ear), "%s ear complete" % ear)
	var r := s.build_results()
	for k in ["patient_id", "ears", "technique_errors", "presentations", "accuracy", "technique", "efficiency", "score", "grade", "max_combo"]:
		assert_has(r, k, "results")
	for ear: String in ["right", "left"]:
		var e: Dictionary = r["ears"][ear]
		for k in ["freqs", "complete", "retest_1k", "order", "strokes", "par", "accuracy", "shape"]:
			assert_has(e, k, "ears.%s" % ear)
		assert_false((e["retest_1k"] as Dictionary).is_empty(), "1k retest recorded")
		for f: int in e["freqs"]:
			var info: Dictionary = e["freqs"][f]
			for k in ["stored_db", "true_db", "no_response", "strokes", "par", "golf", "accuracy", "errors"]:
				assert_has(info, k, "freq info")
			assert_true(absi(int(info["stored_db"]) - int(info["true_db"])) <= 10, "%s %d Hz within 10 dB" % [ear, f])
	assert_true(float(r["accuracy"]) >= 0.6, "accuracy %f" % float(r["accuracy"]))
	assert_true(float(r["technique"]) >= 0.9, "technique %f errors %s" % [float(r["technique"]), str(r["technique_errors"])])


func test_wrong_step_is_flagged() -> void:
	var p := Game.load_patient("gus") as PatientProfile
	var s := AudiometrySession.new(p, 7)
	var kinds := []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	s.set_freq(1000)
	_set_level(s, 60)
	assert_true(_present(s), "60 dB is heard by Gus at 1k")
	_set_level(s, 55)  # should have gone down 10
	_present(s)
	assert_has(kinds, &"wrong_step")


func test_too_loud_triggers_visual_gag_only() -> void:
	var p := Game.load_patient("gus") as PatientProfile
	var s := AudiometrySession.new(p, 9)
	var reactions := []
	s.reaction.connect(func(k: StringName, _d: Dictionary) -> void: reactions.append(k))
	s.set_freq(1000)
	_set_level(s, 90)
	_present(s)
	assert_has(reactions, &"too_loud_blast")
	assert_true(AudioSafety.hl_to_peak(90) <= AudioSafety.peak_ceiling())
