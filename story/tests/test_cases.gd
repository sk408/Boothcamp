extends TestCase
## Cases (docs/CASES.md, CONTRACTS.md §11): every case file is playable and keeps the house rules, and
## each patient's truth table really shows the pattern, asymmetry and urgency the case teaches.

const CaseData := preload("res://story/case_data.gd")
const CasePortraits := preload("res://story/case_portraits.gd")
const LevelCase := preload("res://story/level_case.gd")
const Voice := preload("res://story/voice.gd")

## case id -> [the call, the truth shape per ear (right, left), asymmetric?]
const EXPECTED: Dictionary = {
	"noise_notch": [&"fit", &"notch", &"notch", false],
	"menieres": [&"refer", &"normal", &"rising", true],
	"sudden": [&"today", &"flat", &"normal", true],
	"cookie_bite": [&"fit", &"cookie_bite", &"cookie_bite", false],
}
const BOT_PREFIX := 18   # the mouse bot clicks an option by its first 18 characters

var _saved_chapter := ""


func before_each() -> void:
	_saved_chapter = Game.current_chapter_id


func after_each() -> void:
	Game.current_chapter_id = _saved_chapter


func _case(id: String) -> Dictionary:
	return CaseData.load_case(id)


func _truth(id: String, ear: String) -> Dictionary:
	var c := _case(id)
	return CaseData.truth(Game.load_patient(String(c["patient_id"])) as PatientProfile, ear)


func test_every_registered_case_validates() -> void:
	var ids := CaseData.chapter_case_ids()
	assert_true(ids.size() >= 4, "the first batch registers four cases")
	for id: String in ids:
		var problems := CaseData.validate(_case(id))
		assert_true(problems.is_empty(), "%s: %s" % [id, "; ".join(problems)])
		var ch := ""
		for c: Dictionary in Game.chapters():
			if String(c.get("case", "")) == id:
				ch = String(c["id"])
		assert_eq(String(Game.chapter(ch).get("scene", "")), "res://story/level_case.tscn", id)


func test_hoot_lines_are_short() -> void:
	for id: String in CaseData.chapter_case_ids():
		for pair: Array in CaseData.hoot_lines(_case(id)):
			var words := String(pair[1]).split(" ", false).size()
			assert_true(words <= CaseData.HOOT_MAX_WORDS, "%s %s: %d words: %s" % [id, pair[0], words, pair[1]])


func test_day_picker_teasers_give_nothing_away() -> void:
	# picker text names the person or the joke, never the pattern, condition or call
	var banned: PackedStringArray = ["notch", "rising", "sudden", "overnight", "cookie", "bite", "spin", "dizz", "refer", "doctor", "fit "]
	for c: Dictionary in Game.chapters():
		if String(c.get("case", "")) == "":
			continue
		var t := String(c.get("teaches", "")).to_lower()
		assert_true(t.length() <= 30, "%s teaser fits one line" % c["id"])
		for b: String in banned:
			assert_false(t.contains(b), "%s teaser gives away '%s'" % [c["id"], b])


func test_every_choice_is_clickable_by_its_prefix() -> void:
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var groups: Array = []
		for rd: Variant in c["history"]:
			groups.append(((rd as Dictionary)["options"] as Array).map(func(o: Array) -> String: return String(o[0])))
		groups.append((c["evidence"] as Dictionary)["options"])
		var quiz: Variant = (c["tymp"] as Dictionary).get("quiz", null)
		if quiz is Dictionary:
			groups.append(((quiz as Dictionary)["options"] as Array).map(func(o: Array) -> String: return String(o[0])))
		for e: Variant in c["payoff"]:
			if e is Dictionary and (e as Dictionary).has("choose"):
				groups.append((((e as Dictionary)["choose"] as Dictionary)["options"] as Array).map(func(o: Array) -> String: return String(o[0])))
		# every clue card the board could show, one per tag
		var cards := {}
		for cl: Variant in c.get("always_clues", []):
			cards[String(cl["tag"])] = String(cl["text"])
		for rd: Variant in c["history"]:
			for o: Variant in (rd as Dictionary)["options"]:
				if String(o[3]) != "":
					cards[String(o[4])] = String(o[3])
		var rf: Dictionary = c["red_flags"]
		cards[String(rf["tag"])] = String(rf["clue"])
		for ex: Variant in rf.get("extra_clues", []):
			cards[String(ex["tag"])] = String(ex["text"])
		cards[String(c["otoscopy"]["tag"])] = String(c["otoscopy"]["clue"])
		cards[String(c["tymp"]["tag"])] = String(c["tymp"]["clue"])
		for f: Variant in c["findings"]:
			cards[String(f["tag"])] = String(f["text"])
		groups.append(cards.values())
		for g: Variant in groups:
			var seen := {}
			for t: Variant in g:
				var key := String(t).left(BOT_PREFIX)
				assert_false(seen.has(key), "%s: two options start '%s'" % [id, key])
				seen[key] = true


func test_truth_tables_show_the_taught_pattern() -> void:
	for id: String in EXPECTED:
		var exp: Array = EXPECTED[id]
		for k in 2:
			var ear := "right" if k == 0 else "left"
			var t := _truth(id, ear)
			assert_eq(ClinicRules.classify_shape(t), exp[1 + k], "%s %s shape" % [id, ear])
			# one ordinary 5 dB wobble anywhere must not change the shape
			for f: int in t:
				for d: int in [-5, 5]:
					var w := t.duplicate()
					w[f] = int(w[f]) + d
					assert_eq(ClinicRules.classify_shape(w), exp[1 + k], "%s %s shape with %d Hz %+d" % [id, ear, f, d])
		assert_eq(CaseRules.is_asymmetric(_truth(id, "right"), _truth(id, "left")), exp[3], "%s asymmetry" % id)
		assert_eq(String((_case(id)["decision"] as Dictionary)["answer"]), String(exp[0]), "%s call" % id)


func test_dash_meets_the_sudden_definition() -> void:
	var r := _truth("sudden", "right")
	var l := _truth("sudden", "left")
	var run := 0
	var best := 0
	for f: int in ClinicRules.AC_FREQS:
		run = run + 1 if int(r[f]) - int(l[f]) >= CaseRules.SUDDEN_MIN_DB else 0
		best = maxi(best, run)
	assert_true(best >= CaseRules.SUDDEN_MIN_FREQS, "30 dB or more at 3+ neighbouring frequencies")
	assert_true(float((_case("sudden")["sudden_clock"] as Dictionary)["onset_h"]) <= CaseRules.SUDDEN_ONSET_MAX_H, "came on within the definition")


func test_charts_on_file() -> void:
	# Marina: her spring test is ~25 dB better in the low pitches, and was not itself asymmetric
	var prev: Dictionary = CaseData.thresholds((_case("menieres")["reveal"] as Dictionary)["previous"]["thresholds"])
	var today := _truth("menieres", "left")
	for f: int in [250, 500, 1000]:
		assert_eq(int(today[f]) - int(prev[f]), 25, "spring drop at %d" % f)
	assert_false(CaseRules.is_asymmetric(_truth("menieres", "right"), prev), "the spring test was symmetric enough")
	# Ginger: nine years ago, within 5 dB of today everywhere
	var old: Dictionary = CaseData.thresholds((_case("cookie_bite")["reveal"] as Dictionary)["previous"]["thresholds"])
	var now := _truth("cookie_bite", "right")
	for f: int in old:
		assert_true(absi(int(now[f]) - int(old[f])) <= 5, "Ginger stable at %d" % f)


func test_tymp_curves_are_compensated_and_normal_width() -> void:
	var a := {"type": "A", "peak_daPa": 0, "peak_ml": 0.8}
	assert_near(CaseRules.tymp_admittance(a, 0.0), 0.8, 0.001, "peak at its pressure, no canal volume added")
	var tw := 2.0 * float(CaseRules.TYMP_WIDTH[&"A"])
	assert_between(tw, 50.0, 115.0, "type A tympanometric width in the adult normal range")
	assert_true(CaseRules.tymp_admittance(a, 200.0) < 0.05 * 0.8, "settled by +200 daPa, where canal volume is read")
	assert_true(CaseRules.TYMP_WIDTH[&"Ad"] < CaseRules.TYMP_WIDTH[&"A"], "Ad is the narrow skyscraper")
	assert_eq(CaseRules.tymp_b_reading(1.2), &"fluid")
	assert_eq(CaseRules.tymp_b_reading(0.4), &"blocked")
	assert_eq(CaseRules.tymp_b_reading(3.0), &"hole")


func test_red_flags_and_the_hours_clock() -> void:
	var text := ""
	for f: Dictionary in CaseRules.RED_FLAGS:
		text += String(f["text"]).to_lower() + "|"
	for must: String in ["6 months", "fluctuating", "one ear", "dizziness", "pain", "wax", "air-bone gap"]:
		assert_true(text.contains(must), "red flags mention " + must)
	assert_false(text.contains("90 days"), "the pre-2022 windows are gone")
	assert_near(CaseRules.hours_since_onset(30.0, 3600.0), 31.0, 0.0001, "one real hour")
	assert_near(CaseRules.hours_since_onset(30.0, 0.0), 30.0, 0.0001)


func test_pick_case_follows_the_chapter() -> void:
	Game.current_chapter_id = "dash"
	assert_eq(LevelCase.pick_case_id(), "sudden")
	Game.current_chapter_id = "ginger"
	assert_eq(LevelCase.pick_case_id(), "cookie_bite")


func test_shuffles_are_permutations_and_reproducible() -> void:
	var saved := Game.rng.state
	Game.rng.seed = 42
	var a := LevelCase.shuffled_order(9)
	Game.rng.seed = 42
	var b := LevelCase.shuffled_order(9)
	Game.rng.state = saved
	assert_eq(a, b, "same seed, same layout")
	var sorted := a.duplicate()
	sorted.sort()
	assert_eq(sorted, [0, 1, 2, 3, 4, 5, 6, 7, 8] as Array[int], "every option once")


func test_extra_speakers_get_a_portrait_and_a_voice() -> void:
	assert_true(CasePortraits.has("Chip"), "Ginger's puppet has a portrait")
	assert_eq(String(CasePortraits.look("Chip").get("portrait", "")), "cookie")
	Voice.register("Chip", {"f0": 330.0})
	assert_true(Voice.has_voice("Chip"))
	Voice.register("Gus", {"f0": 999.0})
	assert_near(float((Voice.SPEAKERS["Gus"] as Dictionary)["f0"]), 128.0, 0.01, "built-in voices stay")


func test_type_of_loss_follows_the_truth() -> void:
	# the type badge and Dash's type question are graded against the patient's truth, like the lines
	for id: String in EXPECTED:
		var c := _case(id)
		var p := Game.load_patient(String(c["patient_id"])) as PatientProfile
		var ear := String((c["reveal"] as Dictionary).get("ear", "right"))
		ear = "right" if ear == "both" else ear
		assert_eq(CaseData.truth_type(p, ear), &"sensorineural", "%s %s ear" % [id, ear])
	var marina := Game.load_patient("marina") as PatientProfile
	assert_eq(CaseData.truth_type(marina, "right"), &"normal", "Marina's good ear")
	assert_eq(CaseData.truth_type(null, "right"), &"unknown")


func test_finding_sources_are_checked() -> void:
	var c := _case("menieres").duplicate(true)
	assert_true(CaseData.validate(c).is_empty())
	(c["findings"] as Array).append({"tag": "x", "text": "x", "src": "gossip"})
	var problems := CaseData.validate(c)
	assert_true("; ".join(problems).contains("src must be"), "an unknown card source is reported")
