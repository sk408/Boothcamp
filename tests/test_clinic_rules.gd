extends TestCase
## Shared clinical rulebook (res://autoload/clinic_rules.gd).


func test_accuracy_curve() -> void:
	assert_near(ClinicRules.accuracy_for_error(0), 1.0, 0.001)
	assert_near(ClinicRules.accuracy_for_error(5), 1.0, 0.001, "within test-retest = full credit")
	assert_near(ClinicRules.accuracy_for_error(-5), 1.0, 0.001, "symmetric")
	assert_near(ClinicRules.accuracy_for_error(10), 0.4, 0.001)
	assert_near(ClinicRules.accuracy_for_error(15), 0.0, 0.001)


func test_grade_bands() -> void:
	assert_eq(ClinicRules.grade_for_score(100.0), "S")
	assert_eq(ClinicRules.grade_for_score(95.0), "S")
	assert_eq(ClinicRules.grade_for_score(90.0), "A")
	assert_eq(ClinicRules.grade_for_score(70.0), "B")
	assert_eq(ClinicRules.grade_for_score(55.0), "C")
	assert_eq(ClinicRules.grade_for_score(10.0), ClinicRules.GRADE_FAIL)


func test_golf_names() -> void:
	# Run-sized bands: par is within one stroke, so one patient wobble is not a bogey.
	assert_eq(ClinicRules.golf_name(10, 10), &"par")
	assert_eq(ClinicRules.golf_name(9, 10), &"par")
	assert_eq(ClinicRules.golf_name(11, 10), &"par")
	assert_eq(ClinicRules.golf_name(8, 10), &"birdie")
	assert_eq(ClinicRules.golf_name(7, 10), &"birdie")
	assert_eq(ClinicRules.golf_name(6, 10), &"eagle")
	assert_eq(ClinicRules.golf_name(4, 10), &"albatross")
	assert_eq(ClinicRules.golf_name(12, 10), &"bogey")
	assert_eq(ClinicRules.golf_name(14, 10), &"double_bogey")
	assert_eq(ClinicRules.golf_name(16, 10), &"triple_bogey")


func test_combo_multiplier_steps() -> void:
	assert_eq(ClinicRules.combo_multiplier(0), 1)
	assert_eq(ClinicRules.combo_multiplier(3), 2)
	assert_eq(ClinicRules.combo_multiplier(6), 3)
	assert_eq(ClinicRules.combo_multiplier(10), 5)


func test_weights_sum_to_one() -> void:
	var total := 0.0
	for k: String in ClinicRules.SCORE_WEIGHTS:
		total += ClinicRules.SCORE_WEIGHTS[k]
	assert_near(total, 1.0, 0.0001)


func test_interoctave_rule() -> void:
	var thr := {500: 20, 1000: 25, 2000: 45, 4000: 50}
	var need := ClinicRules.required_interoctaves(thr)
	assert_has(need, 1500, "1k->2k differ by 20")
	assert_false(need.has(750), "500->1k differ by 5")
	assert_false(need.has(3000), "2k->4k differ by 5")


func test_shape_classification() -> void:
	assert_eq(ClinicRules.classify_shape({250: 10, 500: 10, 1000: 10, 2000: 15, 4000: 10, 8000: 15}), &"normal")
	assert_eq(ClinicRules.classify_shape({250: 15, 500: 20, 1000: 25, 2000: 40, 4000: 55, 8000: 65}), &"sloping")
	assert_eq(ClinicRules.classify_shape({250: 10, 500: 10, 1000: 10, 2000: 15, 3000: 40, 4000: 50, 6000: 35, 8000: 15}), &"notch")
	assert_eq(ClinicRules.classify_shape({250: 55, 500: 50, 1000: 40, 2000: 30, 4000: 25, 8000: 25}), &"rising")
	assert_eq(ClinicRules.classify_shape({250: 45, 500: 45, 1000: 50, 2000: 45, 4000: 50, 8000: 45}), &"flat")
	assert_eq(ClinicRules.classify_shape({1000: 20}), &"unknown")


func test_clamp_db_snaps_and_limits() -> void:
	assert_eq(ClinicRules.clamp_db(42, 1000), 40)
	assert_eq(ClinicRules.clamp_db(-30, 1000), ClinicRules.MIN_DB)
	assert_eq(ClinicRules.clamp_db(200, 250), ClinicRules.max_db(250))


func test_degree_names() -> void:
	assert_eq(ClinicRules.degree_name(20), "normal")
	assert_eq(ClinicRules.degree_name(35), "mild")
	assert_eq(ClinicRules.degree_name(95), "profound")


## (E18) The chart notes under a finished audiogram: transducer, mastoids, reliability.
func test_chart_notes() -> void:
	var r := {"air_transducer": "phones", "duration_s": 600.0, "false_alarms": 2, "ears": {
		"right": {"retest_1k": {"diff": 0}, "bc": {}, "bc_masked": {1000: {}}},
		"left": {"retest_1k": {}, "bc": {1000: {}}, "bc_masked": {}}}}
	assert_eq(ClinicRules.reliability(r), "good", "retest agreed, 0.2 false alarms a minute")
	var n := ClinicRules.chart_notes(r)
	assert_true(n.begins_with("Headphones"), n)
	assert_true(n.contains("Bone on both mastoids"), n)
	assert_true(n.ends_with("Reliability: good"), n)
	r["air_transducer"] = "inserts"
	(r["ears"]["right"] as Dictionary)["bc_masked"] = {}
	n = ClinicRules.chart_notes(r)
	assert_true(n.begins_with("Insert earphones") and n.contains("Bone on the left mastoid"), n)
	(r["ears"]["right"] as Dictionary)["retest_1k"] = {"diff": 10}
	assert_eq(ClinicRules.reliability(r), "fair", "a retest 10 dB off")
	(r["ears"]["right"] as Dictionary)["retest_1k"] = {"diff": 15}
	assert_eq(ClinicRules.reliability(r), "poor", "a retest 15 dB off")
	(r["ears"]["right"] as Dictionary)["retest_1k"] = {"diff": 0}
	r["false_alarms"] = 12
	assert_eq(ClinicRules.reliability(r), "fair", "1.2 false alarms a minute")
	r["false_alarms"] = 25
	assert_eq(ClinicRules.reliability(r), "poor", "2.5 false alarms a minute")
	var air_only := {"air_transducer": "phones", "ears": {"right": {}, "left": {}}}
	assert_false(ClinicRules.chart_notes(air_only).contains("Bone"), "no bone, no mastoid note")
