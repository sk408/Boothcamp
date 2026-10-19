extends TestCase
## v3 rulebook: bone conduction, air-bone gap, masking rules and the cross-hearing model
## (res://autoload/clinic_rules.gd, docs/CHAPTER2.md §6). The numbers are the teaching defaults.


func test_tests_and_transducers() -> void:
	assert_eq(ClinicRules.TESTS, [&"ac", &"ac_masked", &"bc", &"bc_masked"])
	assert_eq(ClinicRules.test_id(true, true), &"bc_masked")
	assert_eq(ClinicRules.test_id(false, false), &"ac")
	assert_true(ClinicRules.test_is_bone(&"bc_masked"))
	assert_false(ClinicRules.test_is_bone(&"ac_masked"))
	assert_eq(ClinicRules.unmasked_test(&"ac_masked"), &"ac")
	assert_eq(ClinicRules.test_freqs(&"bc"), ClinicRules.BC_FREQS)
	assert_false(ClinicRules.test_freqs(&"bc").has(8000), "no bone above 4 kHz")


func test_bone_limits_are_lower_than_air() -> void:
	assert_between(ClinicRules.max_db_for(250, &"bone"), 40, 50, "bone runs out at about 45 at 250 Hz")
	for f: int in [500, 1000, 2000, 4000]:
		assert_between(ClinicRules.max_db_for(f, &"bone"), 60, 70, "bone max %d Hz" % f)
		assert_true(ClinicRules.max_db_for(f, &"bone") < ClinicRules.max_db_for(f, &"phones"))
	assert_eq(ClinicRules.clamp_db_for(95, 1000, &"bone"), 70)
	assert_eq(ClinicRules.clamp_db_for(95, 1000, &"phones"), 95)


func test_air_bone_gap_and_red_flag() -> void:
	assert_false(ClinicRules.is_conductive_gap(10), "10 dB is no real gap")
	assert_true(ClinicRules.is_conductive_gap(15))
	var ac := {500: 55, 1000: 50, 2000: 50}
	assert_true(ClinicRules.abg_red_flag(ac, {500: 10, 1000: 10, 2000: 25}))
	assert_false(ClinicRules.abg_red_flag(ac, {500: 10, 1000: 10, 2000: 40}), "gap 10 at 2k: no flag")
	assert_false(ClinicRules.abg_red_flag(ac, {500: 10, 1000: 10}), "needs all three frequencies")


func test_hearing_type() -> void:
	assert_eq(ClinicRules.hearing_type({500: 10, 1000: 5, 2000: 10, 4000: 15}, {}), &"normal")
	assert_eq(ClinicRules.hearing_type({500: 55, 1000: 50, 2000: 50, 4000: 35}, {500: 10, 1000: 10, 2000: 25, 4000: 10}), &"conductive")
	assert_eq(ClinicRules.hearing_type({500: 70, 1000: 70, 2000: 70, 4000: 70}, {500: 40, 1000: 40, 2000: 45, 4000: 50}), &"mixed")
	assert_eq(ClinicRules.hearing_type({500: 30, 1000: 40, 2000: 50, 4000: 60}, {500: 25, 1000: 35, 2000: 50, 4000: 55}), &"sensorineural")
	assert_eq(ClinicRules.hearing_type({500: 50}, {}), &"unknown")


func test_carhart_notch() -> void:
	assert_true(ClinicRules.has_carhart_notch({1000: 10, 2000: 25, 4000: 10}))
	assert_false(ClinicRules.has_carhart_notch({1000: 10, 2000: 15, 4000: 10}), "a 5 dB wobble is not a notch")
	assert_false(ClinicRules.has_carhart_notch({1000: 10, 2000: 25}), "needs 4 kHz too")
	# (polish) a classic Carhart pattern dips at 1 kHz as well: still a notch against 500 / 4k
	assert_true(ClinicRules.has_carhart_notch({500: 5, 1000: 15, 2000: 20, 4000: 5}), "1k dips a little too")
	assert_true(ClinicRules.has_carhart_notch({500: 10, 1000: 10, 2000: 25, 4000: 10}), "Bonnie")
	assert_false(ClinicRules.has_carhart_notch({500: 5, 1000: 10, 2000: 25, 4000: 40}), "a sloping loss is not a notch")
	assert_false(ClinicRules.has_carhart_notch({500: 10, 1000: 30, 2000: 25, 4000: 10}), "the bottom is at 1k, not 2k")


func test_when_to_mask() -> void:
	# AC: test-ear level - 40 (supra-aural) >= non-test bone
	assert_true(ClinicRules.ac_masking_needed(55, 5))
	assert_true(ClinicRules.ac_masking_needed(45, 5), "45 - 40 = 5 >= 5")
	assert_false(ClinicRules.ac_masking_needed(35, 5))
	assert_false(ClinicRules.ac_masking_needed(55, 5, &"inserts"), "inserts give 55 dB")
	# BC: air-bone gap of 10 dB or more (clinical review E5, ASHA 2005 / BSA 2018 rule 2)
	assert_true(ClinicRules.bc_masking_needed(50, 0))
	assert_true(ClinicRules.bc_masking_needed(15, 5), "gap 10: masked bone needed")
	assert_false(ClinicRules.bc_masking_needed(10, 5), "gap 5: no masked bone")
	assert_false(ClinicRules.is_conductive_gap(10), "but a 10 dB gap still names no conductive loss")


func test_initial_masking_with_occlusion() -> void:
	# non-test AC + 10, plus 15 / 15 / 10 / 0 occlusion for bone at 250 / 500 / 1k / 2k+
	assert_eq(ClinicRules.initial_masking(5, 250, &"bc_masked"), 30)
	assert_eq(ClinicRules.initial_masking(5, 500, &"bc_masked"), 30)
	assert_eq(ClinicRules.initial_masking(5, 1000, &"bc_masked"), 25)
	assert_eq(ClinicRules.initial_masking(5, 2000, &"bc_masked"), 15)
	assert_eq(ClinicRules.initial_masking(10, 4000, &"bc_masked"), 20)
	assert_eq(ClinicRules.initial_masking(5, 500, &"ac_masked"), 15, "no occlusion allowance for air")
	assert_eq(ClinicRules.initial_masking(40, 500, &"bc_masked", 30), 50, "a conductive non-test ear has no occlusion effect")
	assert_eq(ClinicRules.initial_masking(5, 500, &"bc_masked", 0, &"inserts"), 15, "deep inserts: no occlusion")


func test_overmasking_and_dilemma() -> void:
	# bone: overmasking when masker - 40 >= tone
	assert_eq(ClinicRules.overmask_limit(10, &"bc_masked"), 50)
	assert_false(ClinicRules.is_overmasked(45, 10, &"bc_masked"))
	assert_true(ClinicRules.is_overmasked(50, 10, &"bc_masked"))
	# air: masker - 40 >= tone - test-ear gap
	assert_eq(ClinicRules.overmask_limit(50, &"ac_masked", 40), 50)
	assert_true(ClinicRules.masking_dilemma(55, 50))
	assert_false(ClinicRules.masking_dilemma(25, 50))
	assert_eq(ClinicRules.mask_status(false, true, 0, 25, 50), &"needed")
	assert_eq(ClinicRules.mask_status(false, false, 0, 25, 50), &"off")
	assert_eq(ClinicRules.mask_status(true, true, 20, 25, 50), &"under")
	assert_eq(ClinicRules.mask_status(true, true, 25, 25, 50), &"ok")
	assert_eq(ClinicRules.mask_status(true, true, 50, 25, 50), &"over")
	assert_eq(ClinicRules.mask_status(true, true, 60, 60, 50), &"impossible")


func test_plateau_dance() -> void:
	assert_eq(ClinicRules.next_mask_step(10, 25, true), Vector2i(10, 30), "heard: noise up 5")
	assert_eq(ClinicRules.next_mask_step(10, 25, false), Vector2i(15, 25), "missed: tone up 5")
	var recs := [
		{"db": 5, "mask_db": 25, "responded": false},
		{"db": 10, "mask_db": 25, "responded": true},
		{"db": 10, "mask_db": 30, "responded": true},
		{"db": 10, "mask_db": 35, "responded": true},
	]
	var run := ClinicRules.plateau_run(recs)
	assert_eq(run, {"db": 10, "steps": 2, "start_mask": 25})
	recs.append({"db": 10, "mask_db": 40, "responded": true})
	assert_eq(int(ClinicRules.plateau_run(recs)["steps"]), ClinicRules.PLATEAU_STEPS, "3 raises = 15 dB plateau")
	recs.append({"db": 10, "mask_db": 45, "responded": false})
	assert_eq(int(ClinicRules.plateau_run(recs)["steps"]), 0, "a miss breaks the run")
	# re-presenting at the same masker after a hit is not a plateau step
	var same := [{"db": 10, "mask_db": 25, "responded": true}, {"db": 10, "mask_db": 25, "responded": true}]
	assert_eq(int(ClinicRules.plateau_run(same)["steps"]), 0)


## Bonnie's right ear at 1 kHz: AC 50, BC 10; left AC 5, BC 0; phones IA 60, bone IA 0.
func test_cross_hearing_model() -> void:
	# unmasked air: the right cochlea answers (crossing needs 0 + 60)
	var r := ClinicRules.response_threshold(50, 10, 5, 0, false, -1, 60, 60)
	assert_eq(int(r["threshold"]), 50)
	assert_eq(r["by"], &"test")
	# unmasked bone: zero IA, the better LEFT cochlea answers at 0 (the Cross-Hearing Ghost)
	r = ClinicRules.response_threshold(50, 10, 5, 0, true, -1, 0, 60)
	assert_eq(int(r["threshold"]), 0)
	assert_eq(r["by"], &"cross")
	# masked bone at the initial level (5 + 10 + 10 occlusion = 25): the noise reaches the left
	# cochlea at 25 - 5 (its own small gap) = 20, and occlusion makes it hear bone 10 dB better: 10
	r = ClinicRules.response_threshold(50, 10, 5, 0, true, 25, 0, 60, 10)
	assert_eq(int(r["cross"]), 10, "initial masking protects up to non-test bone + 10")
	assert_eq(int(r["threshold"]), 10)
	assert_eq(r["by"], &"test")
	# undermasked (no occlusion pad): the ghost still answers first
	r = ClinicRules.response_threshold(50, 10, 5, 0, true, 15, 0, 60, 10)
	assert_eq(r["by"], &"cross")
	# one plateau step up: the left cochlea is now out of the race
	r = ClinicRules.response_threshold(50, 10, 5, 0, true, 30, 0, 60, 10)
	assert_eq(int(r["cross"]), 15)
	assert_eq(int(r["threshold"]), 10)
	# overmasking: the noise crosses back (masker - 60) and lifts the test cochlea
	r = ClinicRules.response_threshold(50, 10, 5, 0, true, 85, 0, 60, 10)
	assert_eq(int(r["test"]), 25)
	# a conductive non-test ear: the noise loses its gap on the way in
	r = ClinicRules.response_threshold(50, 10, 45, 5, true, 30, 0, 60, 10)
	assert_eq(int(r["cross"]), 5, "30 - 40 gap does not mask a 5 dB cochlea; no occlusion either")


## The masking plan from stored results (Bonnie's typical stamps).
func test_masked_freqs_needed() -> void:
	var res := {"ears": {
		"right": {"freqs": _sheet({250: 55, 500: 55, 1000: 50, 2000: 50, 4000: 35, 8000: 40}),
			"bc": _sheet({500: 5, 1000: 0, 2000: 5, 4000: 5})},
		"left": {"freqs": _sheet({250: 10, 500: 5, 1000: 5, 2000: 5, 4000: 10, 8000: 15})},
	}}
	assert_eq(ClinicRules.masked_freqs_needed(res, "right", &"bc_masked"), [1000, 2000, 4000, 500])
	assert_eq(ClinicRules.masked_freqs_needed(res, "right", &"ac_masked"), [1000, 2000, 500, 250])
	assert_eq(ClinicRules.masked_freqs_needed(res, "right", &"ac_masked", &"inserts"), [], "inserts: no masked air needed")
	assert_eq(ClinicRules.masked_freqs_needed(res, "left", &"ac_masked"), [])
	assert_eq(ClinicRules.best_thresholds(res, "right", true), {500: 5, 1000: 0, 2000: 5, 4000: 5})


static func _sheet(t: Dictionary) -> Dictionary:
	var out := {}
	for f: int in t:
		out[f] = {"stored_db": t[f], "no_response": false}
	return out
