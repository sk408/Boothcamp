extends TestCase
## Cases (docs/CASES.md, CONTRACTS.md §11): every case file is playable and keeps the house rules, and
## each patient's truth table really shows the pattern, asymmetry and urgency the case teaches.

const CaseData := preload("res://story/case_data.gd")
const CasePortraits := preload("res://story/case_portraits.gd")
const LevelCase := preload("res://story/level_case.gd")
const Voice := preload("res://story/voice.gd")
const CaseOtoscopy := preload("res://story/games/case_otoscopy.gd")
const CaseProps := preload("res://story/games/case_props.gd")

## case id -> [the call, the truth shape per ear (right, left), asymmetric?, the case ear's type]
const EXPECTED: Dictionary = {
	"noise_notch": [&"fit", &"notch", &"notch", false, &"sensorineural"],
	"menieres": [&"refer", &"normal", &"rising", true, &"sensorineural"],
	"sudden": [&"today", &"flat", &"normal", true, &"sensorineural"],
	"cookie_bite": [&"fit", &"cookie_bite", &"cookie_bite", false, &"sensorineural"],
	"wax": [&"refer", &"flat", &"normal", true, &"conductive"],
	"fluid": [&"refer", &"normal", &"flat", true, &"conductive"],
}
## The conductive cases: case id -> the ear with the gap.
const CONDUCTIVE: Dictionary = {"wax": "right", "fluid": "left"}
## The octaves every case plan stamps in air (_stamped adds the half-octaves a chart asks for).
const STAMPED: Array[int] = [250, 500, 1000, 2000, 4000, 8000]
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
	assert_true(ids.size() >= 6, "batches 1 and 2 register six cases")
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
	var banned: PackedStringArray = ["notch", "rising", "sudden", "overnight", "cookie", "bite", "spin", "dizz", "refer", "doctor", "fit ",
		"wax", "fluid", "plug", "block", "cold", "drain", "muffl", "bubbl", "pop", "burst"]
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
		for pair: Array in CaseData.scripts(c):   # every choose, the retest's prediction included
			for e: Variant in pair[1]:
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
	assert_eq(CaseRules.tymp_b_reading(0.5), &"blocked")
	assert_eq(CaseRules.tymp_b_reading(0.7), &"fluid", "the blocked floor is 0.6 mL, not the adult band's 0.9")
	assert_eq(CaseRules.tymp_b_reading(3.0), &"hole")
	assert_eq(CaseRules.ecv_band(0.4), &"tiny")
	assert_eq(CaseRules.ecv_band(0.7), &"low")
	assert_eq(CaseRules.ecv_band(1.1), &"normal")
	assert_eq(CaseRules.ecv_band(2.5), &"large")


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
	Game.current_chapter_id = "barnaby"
	assert_eq(LevelCase.pick_case_id(), "wax")
	Game.current_chapter_id = "skye"
	assert_eq(LevelCase.pick_case_id(), "fluid")


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
		assert_eq(CaseData.truth_type(p, ear), (EXPECTED[id] as Array)[4], "%s %s ear" % [id, ear])
	var marina := Game.load_patient("marina") as PatientProfile
	assert_eq(CaseData.truth_type(marina, "right"), &"normal", "Marina's good ear")
	assert_eq(CaseData.truth_type(null, "right"), &"unknown")


func test_finding_sources_are_checked() -> void:
	var c := _case("menieres").duplicate(true)
	assert_true(CaseData.validate(c).is_empty())
	(c["findings"] as Array).append({"tag": "x", "text": "x", "src": "gossip"})
	var problems := CaseData.validate(c)
	assert_true("; ".join(problems).contains("src must be"), "an unknown card source is reported")


# ---------------------------------------------------------------- batch 2: conductive cases, retest

## The air frequencies a plan stamps on an ear: STAMPED, plus each half-octave whose neighbours in the
## truth differ by ClinicRules.INTEROCTAVE_DIFF_DB or more (Rocco's 3k and 6k, Ginger's 750).
func _stamped(p: PatientProfile, ear: String) -> Array[int]:
	var out: Array[int] = STAMPED.duplicate()
	out.append_array(ClinicRules.required_interoctaves(CaseData.truth(p, ear)))
	return out


## A results dict from a patient's truth, as perfect stamps: air at _stamped in both ears, unmasked
## bone (the better cochlea: bone IA is 0) on bc_ears at BC_REQUIRED, and masked bone (the ear's
## own cochlea) on masked_ears. wobble: [ear, sheet, freq, dB] adds dB to one stamp.
func _perfect(p: PatientProfile, bc_ears: PackedStringArray, masked_ears: PackedStringArray, wobble: Array = []) -> Dictionary:
	var ears := {}
	for ear: String in ["right", "left"]:
		var other := "left" if ear == "right" else "right"
		var e := {"freqs": {}, "bc": {}, "bc_masked": {}, "ac_masked": {}}
		for f: int in _stamped(p, ear):
			(e["freqs"] as Dictionary)[f] = {"stored_db": p.get_threshold(ear, f)}
		for f: int in ClinicRules.BC_REQUIRED:
			if bc_ears.has(ear):
				(e["bc"] as Dictionary)[f] = {"stored_db": mini(p.get_bc_threshold(ear, f), p.get_bc_threshold(other, f))}
			if masked_ears.has(ear):
				(e["bc_masked"] as Dictionary)[f] = {"stored_db": p.get_bc_threshold(ear, f)}
		ears[ear] = e
	if wobble.size() == 4:
		var sheet: Dictionary = (ears[String(wobble[0])] as Dictionary)[String(wobble[1])]
		if sheet.has(int(wobble[2])):
			var info: Dictionary = sheet[int(wobble[2])]
			info["stored_db"] = int(info["stored_db"]) + int(wobble[3])
	return {"ears": ears}


func _patient(id: String) -> PatientProfile:
	return Game.load_patient(String(_case(id)["patient_id"])) as PatientProfile


func test_masking_plans_unchanged_for_shipped_cases() -> void:
	# the runner checks every air-tested ear for masked bone and every ear for masked air: with perfect
	# stamps only a one-sided case's reveal ear needs masked bone, and the better ear never needs
	# masked air, so no case gains a test it shouldn't run
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var p := _patient(id)
		var bc_ears := CaseData.plan_ears(c["audiometry"], "bc")
		var case_ear := String((c["reveal"] as Dictionary).get("ear", "both"))
		var res := _perfect(p, bc_ears, PackedStringArray())
		var masked_ears := PackedStringArray()
		for ear: String in CaseData.masked_bone_ears(c["audiometry"]):
			var need := ClinicRules.masked_freqs_needed(res, ear, &"bc_masked")
			if ear == case_ear:
				assert_false(need.is_empty(), "%s: masked bone on the %s (reveal) ear" % [id, ear])
				masked_ears.append(ear)
			else:
				assert_eq(need, [] as Array[int], "%s: the %s ear needs no masked bone" % [id, ear])
		for m: PackedStringArray in [PackedStringArray(), masked_ears]:
			var r2 := _perfect(p, bc_ears, m)
			for ear: String in CaseData.plan_ears(c["audiometry"], "ac"):
				if ear == case_ear or (case_ear == "both" and bc_ears.has(ear)):
					continue
				for tr: StringName in [&"phones", &"inserts"]:
					assert_eq(ClinicRules.masked_freqs_needed(r2, ear, &"ac_masked", tr), [] as Array[int],
						"%s: the %s ear needs no masked air (%s)" % [id, ear, tr])


func test_unmasked_bone_goes_on_the_better_ear() -> void:
	# Steve's convention (as on Day 2): a one-sided case puts unmasked bone on the better ear only (it
	# answers for the better cochlea wherever it sits); masked bone then follows on the reveal ear
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var case_ear := String((c["reveal"] as Dictionary).get("ear", "both"))
		if case_ear != "right" and case_ear != "left":
			continue
		var p := _patient(id)
		var better := "left" if case_ear == "right" else "right"
		assert_true(ClinicRules.pta(CaseData.truth(p, better)) < ClinicRules.pta(CaseData.truth(p, case_ear)),
			"%s: the reveal ear is the poorer one" % id)
		assert_eq(CaseData.plan_ears(c["audiometry"], "bc"), PackedStringArray([better]), "%s: unmasked bone" % id)
		assert_eq(CaseData.masked_bone_ears(c["audiometry"]), PackedStringArray([better, case_ear]), "%s: masked bone checks" % id)


func test_case_air_transducer() -> void:
	var saved: Variant = Game.progress.get("upgrades", null)
	Game.progress["upgrades"] = []
	assert_eq(CaseData.air_transducer(false), &"phones", "headphones until the inserts are owned")
	Game.progress["upgrades"] = ["insert_earphones"]
	assert_eq(CaseData.air_transducer(false), &"inserts")
	assert_eq(CaseData.air_transducer(true), &"phones", "a blocked canal keeps the headphones")
	if saved == null:
		Game.progress.erase("upgrades")
	else:
		Game.progress["upgrades"] = saved
	assert_true(CaseData.canal_blocked(_case("wax")), "Barnaby's canal is full of wax")
	assert_false(CaseData.canal_blocked(_case("fluid")), "Skye's canal is clear")


func test_conductive_truth_survives_a_wobble() -> void:
	for id: String in CONDUCTIVE:
		var ear := String(CONDUCTIVE[id])
		var p := _patient(id)
		var air := CaseData.truth(p, ear)
		var bone := {}
		for f: int in ClinicRules.BC_FREQS:
			bone[f] = p.get_bc_threshold(ear, f)
		assert_eq(ClinicRules.hearing_type(air, bone), &"conductive", id)
		assert_true(ClinicRules.abg_red_flag(air, bone), "%s: the air-bone-gap red flag" % id)
		for f: int in [500, 1000, 2000, 4000]:
			for d: int in [-5, 5]:
				var a2 := air.duplicate()
				a2[f] = int(a2[f]) + d
				var b2 := bone.duplicate()
				b2[f] = int(b2[f]) + d
				for pair: Array in [[a2, bone], [air, b2]]:
					assert_eq(ClinicRules.hearing_type(pair[0], pair[1]), &"conductive", "%s with %d Hz %+d" % [id, f, d])
					assert_true(ClinicRules.abg_red_flag(pair[0], pair[1]), "%s flag with %d Hz %+d" % [id, f, d])


func test_conductive_cases_mask_bone_not_air() -> void:
	for id: String in CONDUCTIVE:
		var ear := String(CONDUCTIVE[id])
		var other := "left" if ear == "right" else "right"
		var p := _patient(id)
		var bc_ears := PackedStringArray([other])   # unmasked bone on the better ear only
		var res := _perfect(p, bc_ears, PackedStringArray())
		assert_eq(ClinicRules.masked_freqs_needed(res, ear, &"bc_masked"), [1000, 2000, 4000, 500] as Array[int], "%s masked bone" % id)
		assert_eq(ClinicRules.masked_freqs_needed(res, other, &"bc_masked"), [] as Array[int], "%s: no masked bone on the better ear" % id)
		var transducers: Array[StringName] = [&"phones"]
		if id != "wax":   # wax keeps headphones
			transducers.append(&"inserts")
		for m: PackedStringArray in [PackedStringArray(), PackedStringArray([ear])]:
			var r2 := _perfect(p, bc_ears, m)
			for e: String in ["right", "left"]:
				for tr: StringName in transducers:
					assert_eq(ClinicRules.masked_freqs_needed(r2, e, &"ac_masked", tr), [] as Array[int], "%s %s: no masked air (%s)" % [id, e, tr])
		# no masking dilemma at any masked bone frequency
		for f: int in [500, 1000, 2000, 4000]:
			for tr: StringName in transducers:
				var init := ClinicRules.initial_masking(p.get_threshold(other, f), f, &"bc_masked", 0, tr)
				var limit := ClinicRules.overmask_limit(p.get_bc_threshold(ear, f), &"bc_masked", 0, tr)
				assert_false(ClinicRules.masking_dilemma(init, limit), "%s %d Hz: %d below %d (%s)" % [id, f, init, limit, tr])
		# one wandering stamp never adds masked air
		for e: String in ["right", "left"]:
			for sheet: String in ["freqs", "bc", "bc_masked"]:
				for f: int in _stamped(p, e):
					for d: int in [-5, 5]:
						var rw := _perfect(p, bc_ears, PackedStringArray([ear]), [e, sheet, f, d])
						for chk: String in ["right", "left"]:
							assert_eq(ClinicRules.masked_freqs_needed(rw, chk, &"ac_masked", &"phones"), [] as Array[int],
								"%s: %s %s %d %+d adds masked air on the %s" % [id, e, sheet, f, d, chk])


func test_script_names_are_known() -> void:
	var reactions: Array = (load("res://world/clinic.gd") as Script).get_script_constant_map()["REACTIONS"]
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var speakers := {String(c["speaker"]): true, "Hoot": true}
		for v: Variant in c.get("voices", {}):
			speakers[String(v)] = true
		for pair: Array in CaseData.scripts(c):
			for e: Variant in pair[1]:
				if CaseData.is_line(e):
					assert_true(speakers.has(String((e as Array)[0])), "%s %s: speaker %s" % [id, pair[0], (e as Array)[0]])
				elif e is Dictionary:
					var d: Dictionary = e
					if d.has("react"):
						assert_has(reactions, StringName(String(d["react"])), "%s %s: reaction" % [id, pair[0]])
					if d.has("hoot"):
						assert_has(CaseData.HOOT_EMOTES, String(d["hoot"]), "%s %s: Hoot emote" % [id, pair[0]])
					if d.has("do"):
						assert_has(CaseData.DOS, String(d["do"]), "%s %s: prop" % [id, pair[0]])


func test_case_patients_match_their_chapters() -> void:
	for ch: Dictionary in Game.chapters():
		var cid := String(ch.get("case", ""))
		if cid == "":
			continue
		var c := _case(cid)
		assert_eq(String(c["patient_id"]), String(ch["patient_id"]), "%s patient" % cid)
		assert_eq(String(c["speaker"]), String(ch.get("face", "")), "%s speaker is the picker's face" % cid)
		assert_eq(_patient(cid).id, String(ch["patient_id"]), "%s .tres id" % cid)
		if c.get("retest", null) is Dictionary:
			var rpid := String((c["retest"] as Dictionary)["patient_id"])
			assert_eq((Game.load_patient(rpid) as PatientProfile).id, rpid, "%s retest .tres id" % cid)


func test_case_patients_validate() -> void:
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var pids: Array[String] = [String(c["patient_id"])]
		if c.get("retest", null) is Dictionary:
			pids.append(String((c["retest"] as Dictionary)["patient_id"]))
		for pid: String in pids:
			var problems := (Game.load_patient(pid) as PatientProfile).validate()
			assert_true(problems.is_empty(), "%s: %s" % [pid, "; ".join(problems)])


func test_flat_tymps_read_their_canal_volume() -> void:
	for id: String in CaseData.chapter_case_ids():
		var ty: Dictionary = _case(id)["tymp"]
		for ear: String in ["right", "left"]:
			var t: Dictionary = ty[ear]
			assert_true(t.has("ecv_ml"), "%s %s has a canal volume" % [id, ear])
			if String(t["type"]) == "B":
				assert_true(float(t["peak_ml"]) < CaseRules.TYMP_FLAT_ML, "%s %s flat" % [id, ear])
				assert_ne(CaseRules.ecv_band(float(t["ecv_ml"])), &"low", "%s %s outside the grey zone" % [id, ear])
	assert_eq(CaseRules.tymp_b_reading(float((_case("wax")["tymp"] as Dictionary)["right"]["ecv_ml"])), &"blocked", "wax reads blocked")
	assert_eq(CaseRules.tymp_b_reading(float((_case("fluid")["tymp"] as Dictionary)["left"]["ecv_ml"])), &"fluid", "fluid reads fluid")


## The problems validate() finds in a copy of the wax case after change(copy).
func _wax_problems(change: Callable) -> String:
	var c := _case("wax").duplicate(true)
	change.call(c)
	return "; ".join(CaseData.validate(c))


func test_tymp_and_plug_rules_are_checked() -> void:
	assert_eq(_wax_problems(func(_c: Dictionary) -> void: pass), "", "the wax case itself is fine")
	var cases: Array = [
		["a flat tymp with a peak", func(c: Dictionary) -> void: c["tymp"]["right"]["peak_ml"] = 0.5, "no peak"],
		["no canal volume", func(c: Dictionary) -> void: (c["tymp"]["left"] as Dictionary).erase("ecv_ml"), "ecv_ml must be a number"],
		["a flat tymp in the grey zone", func(c: Dictionary) -> void: c["tymp"]["right"]["ecv_ml"] = 0.75, "grey zone"],
		["a type A with a huge canal", func(c: Dictionary) -> void: c["tymp"]["left"]["ecv_ml"] = 2.5, "outside the adult band"],
		["a bad view", func(c: Dictionary) -> void: c["otoscopy"]["view"] = "foggy", "view must be"],
		["a bad kind", func(c: Dictionary) -> void: c["otoscopy"]["kind"] = "purple", "kind must be"],
		["a bad plug", func(c: Dictionary) -> void: c["reveal"]["plug"] = "jam", "needs plug"],
		["a bad when", func(c: Dictionary) -> void: c["findings"][0]["when"] = "sometimes", "when must be"],
		["a plug without a gap", func(c: Dictionary) -> void: c["reveal"]["pattern"] = "notch", "plug only goes"],
		["a type question with two options", func(c: Dictionary) -> void: (c["evidence"]["options"] as Array).pop_back(), "exactly 3 options"],
		["a montage with player stamps", func(c: Dictionary) -> void: c["audiometry"][0]["hoot_turn_after"] = 2, "montage is Hoot's"],
		["no bone on the better ear", func(c: Dictionary) -> void: (c["audiometry"] as Array).remove_at(2), "better ear (left) only"],
		["unmasked bone on the poorer ear", func(c: Dictionary) -> void: c["audiometry"][2]["ear"] = "right", "better ear (left) only"],
		["unmasked bone on both ears", func(c: Dictionary) -> void: (c["audiometry"] as Array).append({"ear": "right", "test": "bc"}), "better ear (left) only"],
		["an unknown Hoot emote", func(c: Dictionary) -> void: (c["intro"] as Array).append({"hoot": "moonwalk"}), "unknown hoot emote"],
		["an unknown speaker", func(c: Dictionary) -> void: (c["intro"] as Array).append(["Gerald", "Bzz."]), "unknown speaker"],
		["a wrong-first headline for the answer", func(c: Dictionary) -> void: c["paper"]["wrong_first"]["refer"] = {"headline": "X"}, "not a wrong call"],
		["a retest of the same patient", func(c: Dictionary) -> void: c["retest"]["patient_id"] = "barnaby", "must differ"],
		["a retest of a chapter's patient", func(c: Dictionary) -> void: c["retest"]["patient_id"] = "gus", "belongs to a chapter"],
		["a retest with bone", func(c: Dictionary) -> void: c["retest"]["audiometry"][0]["test"] = "bc", "air (ac) only"],
		["a retest reveal with no air test", func(c: Dictionary) -> void: c["retest"]["reveal"]["ear"] = "left", "has no air test"],
		["a retest look with a bad view", func(c: Dictionary) -> void: c["retest"]["otoscopy"]["view"] = "foggy", "retest otoscopy: view"],
		["a retest tymp in the grey zone", func(c: Dictionary) -> void: c["retest"]["tymp"]["right"] = {"type": "B", "peak_daPa": 0, "peak_ml": 0.05, "ecv_ml": 0.8}, "grey zone"],
		["a bad retest script", func(c: Dictionary) -> void: (c["retest"]["payoff"] as Array).append({"do": "confetti"}), "unknown do"],
		["a bad red-flag card kind", func(c: Dictionary) -> void: c["red_flags"]["card_kind"] = "purple", "red_flags.card_kind"],
		["more proof cards than the board holds", func(c: Dictionary) -> void: c["clue_pick"]["decoys"] = ["a", "b", "c", "d", "e", "f"], "fit on the board"],
	]
	for t: Array in cases:
		var got := _wax_problems(t[1])
		assert_true(got.contains(String(t[2])), "%s is reported (got: %s)" % [t[0], got])
	# a card with no text is never dealt, so it can't be the proof that is always on the board
	var c := _case("wax").duplicate(true)
	c["otoscopy"]["clue"] = ""
	c["clue_pick"]["answers"] = ["wax_plug", "gap"]
	assert_true("; ".join(CaseData.validate(c)).contains("always on the board"), "an empty proof card is caught")


func test_validate_survives_broken_files() -> void:
	var breaks: Array = [
		func(c: Dictionary) -> void: c["history"] = "oops",
		func(c: Dictionary) -> void: c["red_flags"] = [],
		func(c: Dictionary) -> void: c["tymp"]["right"] = "A",
		func(c: Dictionary) -> void: c["findings"] = [3],
		func(c: Dictionary) -> void: c["decision"]["lines"] = [],
		func(c: Dictionary) -> void: (c["clue_pick"] as Dictionary).erase("right_line"),
		func(c: Dictionary) -> void: c["history"][0]["options"][0] = "a question",
		func(c: Dictionary) -> void: c["history"][1] = 7,
		func(c: Dictionary) -> void: c["audiometry"][0] = "left",
		func(c: Dictionary) -> void: c["always_clues"][0] = ["tag", "text"],
		func(c: Dictionary) -> void: c["intro"][0] = ["Barnaby", 42],
		func(c: Dictionary) -> void: c["retest"] = {"patient_id": 3, "audiometry": "air"},
		func(c: Dictionary) -> void: c["retest"]["reveal"] = "UNPLUGGED",
		func(c: Dictionary) -> void: c["paper"]["wrong_first"] = ["fit"],
		func(c: Dictionary) -> void: c["evidence"]["answer"] = "one",
		func(c: Dictionary) -> void: c["evidence"]["wrong"] = "nope",
		func(c: Dictionary) -> void: c["audiometry"][0]["montage"] = "true",
		func(c: Dictionary) -> void: c["tymp"]["quiz"]["options"][0][1] = "true",
		func(c: Dictionary) -> void: c["red_flags"]["extra_clues"] = null,
	]
	for i in breaks.size():
		var got := _wax_problems(breaks[i])
		assert_true(got != "", "broken file %d is reported, with no script error" % i)


func test_retest_profile() -> void:
	var visit := Game.load_patient("barnaby") as PatientProfile
	var after := Game.load_patient("barnaby_after") as PatientProfile
	assert_true(Game.chapter_for_patient("barnaby_after").is_empty(), "no chapter plays the retest patient")
	assert_eq(after.bc_right, visit.bc_right, "the cochlea is the same")
	for f: int in ClinicRules.BC_FREQS:
		assert_true(absi(after.get_threshold("right", f) - after.get_bc_threshold("right", f)) <= 5, "air back to bone at %d" % f)
	for f: int in [500, 1000, 2000, 4000]:
		assert_true(visit.get_threshold("right", f) - after.get_threshold("right", f) >= 20, "20+ dB better at %d" % f)
	assert_eq(CaseData.truth_type(after, "right"), &"normal")
	assert_eq(CaseData.truth(after, "left"), CaseData.truth(visit, "left"), "the left ear is the visit's")
	assert_false(CaseRules.is_asymmetric(CaseData.truth(after, "right"), CaseData.truth(after, "left")), "symmetric after")


func test_findings_conditions() -> void:
	var gus := Game.load_patient("gus") as PatientProfile
	var wax := _patient("wax")
	var mk := func(kind: StringName, air: Dictionary, bone: Dictionary) -> Dictionary:
		var e := {"hearing_type": kind, "freqs": {}, "bc": {}}
		for f: int in air:
			(e["freqs"] as Dictionary)[f] = {"stored_db": int(air[f])}
		for f: int in bone:
			(e["bc"] as Dictionary)[f] = {"stored_db": int(bone[f])}
		return {"ears": {"right": e}}
	var gap_air := {500: 40, 1000: 40, 2000: 40, 4000: 40}
	var gap_bone := {500: 10, 1000: 10, 2000: 10, 4000: 10}
	assert_true(LevelCase.finding_shows("conductive", mk.call(&"conductive", gap_air, gap_bone), gus, "right", false))
	assert_false(LevelCase.finding_shows("conductive", mk.call(&"mixed", gap_air, gap_bone), wax, "right", false), "mixed is not conductive")
	assert_false(LevelCase.finding_shows("conductive", mk.call(&"sensorineural", gap_air, gap_air), wax, "right", false))
	assert_true(LevelCase.finding_shows("conductive", mk.call(&"unknown", gap_air, {}), wax, "right", false), "unknown falls back to the truth")
	assert_false(LevelCase.finding_shows("conductive", mk.call(&"unknown", gap_air, {}), gus, "right", false), "Gus's truth is not conductive")
	assert_true(LevelCase.finding_shows("abg_flag", mk.call(&"conductive", gap_air, gap_bone), gus, "right", false), "the measured gap")
	assert_false(LevelCase.finding_shows("abg_flag", mk.call(&"conductive", gap_air, {500: 30, 1000: 10, 2000: 10, 4000: 10}), wax, "right", false), "10 at 500 is no flag (needs 15)")
	assert_true(LevelCase.finding_shows("abg_flag", mk.call(&"unknown", gap_air, {}), wax, "right", false), "no bone: the truth")
	assert_true(LevelCase.finding_shows("asymmetric", {}, gus, "right", true))
	assert_false(LevelCase.finding_shows("symmetric", {}, gus, "right", true))
	assert_true(LevelCase.finding_shows("", {}, gus, "right", true))
	for id: String in CONDUCTIVE:
		var p := _patient(id)
		var ear := String(CONDUCTIVE[id])
		var asym := CaseRules.is_asymmetric(CaseData.truth(p, "right"), CaseData.truth(p, "left"))
		for f: Variant in _case(id)["findings"]:
			assert_true(LevelCase.finding_shows(String((f as Dictionary).get("when", "")), {}, p, ear, asym), "%s %s shows on the truth" % [id, f["tag"]])


func test_every_conductive_ear_gets_masked_bone() -> void:
	# an ear with a gap can't borrow the other ear's bone (it would stay "unknown"): the runner checks
	# it for masked bone, and against the better ear's unmasked bone the rules ask for it
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var p := _patient(id)
		var res := _perfect(p, CaseData.plan_ears(c["audiometry"], "bc"), PackedStringArray())
		for ear: String in ["right", "left"]:
			var kind := CaseData.truth_type(p, ear)
			if kind == &"conductive" or kind == &"mixed":
				assert_true(CaseData.masked_bone_ears(c["audiometry"]).has(ear), "%s: the %s ear is checked for masked bone" % [id, ear])
				assert_false(ClinicRules.masked_freqs_needed(res, ear, &"bc_masked").is_empty(), "%s: the %s ear gets masked bone" % [id, ear])


func test_wrong_first_headlines() -> void:
	for id: String in CaseData.chapter_case_ids():
		var c := _case(id)
		var answer := String((c["decision"] as Dictionary)["answer"])
		var wf: Dictionary = (c["paper"] as Dictionary).get("wrong_first", {})
		assert_eq(wf.size(), 2, "%s has a headline for both wrong first stamps" % id)
		for k: String in wf:
			assert_ne(k, answer, id)
	var wax := _case("wax")
	var before := JSON.stringify(wax)
	var p := LevelCase.paper_for(wax, "fit")
	var head := String((wax["paper"]["wrong_first"] as Dictionary)["fit"]["headline"])
	for g: String in ["S", "A", "B", "C"]:
		assert_eq(String((p["headlines"] as Dictionary)[g]), head, "grade %s takes the wrong-first headline" % g)
	assert_eq(String((p["headlines"] as Dictionary)["Do-over"]), String(wax["paper"]["headlines"]["Do-over"]), "Do-over keeps its own")
	assert_eq(JSON.stringify(CaseData.load_case("wax")), before, "the cached case is untouched")
	var right := LevelCase.paper_for(wax, "refer")
	assert_eq(String((right["headlines"] as Dictionary)["S"]), String(wax["paper"]["headlines"]["S"]), "the right first stamp keeps the case's paper")
	var bare := wax.duplicate(true)
	(bare["paper"] as Dictionary).erase("wrong_first")
	var gen := LevelCase.paper_for(bare, "today")
	assert_true(String((gen["headlines"] as Dictionary)["A"]).contains("DOCTOR TODAY"), "a generic headline names the first stamp")


func test_retest_restores_the_first_visit() -> void:
	var saved_visit := Game.visit.duplicate(true)
	var saved_pid := Game.current_patient_id
	Game.begin_visit("barnaby")
	var first_patient := Game.load_patient("barnaby") as PatientProfile
	var first := {"ears": {"right": {"pta": 35}}, "score": 80}
	var lc: Node = LevelCase.new()
	lc.set("patient", Game.load_patient("barnaby_after"))
	lc.set("results", {"ears": {"right": {"pta": 10}}})
	Game.set_audiometry_results(lc.get("results"))
	var comfort := Game.get_comfort()
	Game.lose_comfort("retest_test", 2)
	lc.call("_restore_first_visit", first, first_patient, comfort)
	assert_eq(lc.get("results"), first, "the level's results are the first visit's again")
	assert_eq(Game.visit["audiometry"], first, "so are the visit's (the paper reads them)")
	assert_eq(lc.get("patient"), first_patient, "and the first visit's patient")
	assert_eq(Game.get_comfort(), comfort, "hearts lost on the retest come back")
	Game.lose_comfort("retest_test", 2)
	var low := Game.get_comfort()
	Game.gain_comfort("retest_test", 1)
	lc.call("_restore_first_visit", first, first_patient, low)
	assert_eq(Game.get_comfort(), low + 1, "a heart gained on the retest is never taken away")
	lc.free()
	Game.visit = saved_visit
	Game.current_patient_id = saved_pid


func test_merge_retest() -> void:
	var first := {"ears": {"right": {"pta": 35, "bc": {1000: {"stored_db": 10}}, "best_bc": {1000: 10}},
		"left": {"pta": 5}}, "score": 80}
	var second := {"ears": {"right": {"pta": 10, "bc": {}, "hearing_type": &"normal"}, "left": {}}}
	var shown := LevelCase.merge_retest(first, second, PackedStringArray(["right"]))
	assert_eq(int((shown["ears"]["right"] as Dictionary)["pta"]), 10, "the retested ear is today's")
	assert_eq(int(shown["ears"]["right"]["bc"][1000]["stored_db"]), 10, "air climbs back to the visit's bone, still on the chart")
	assert_eq(int(shown["ears"]["right"]["best_bc"][1000]), 10, "the visit's best bone too")
	assert_eq(shown["ears"]["right"]["hearing_type"], &"normal", "the type is today's")
	assert_eq(int((shown["ears"]["left"] as Dictionary)["pta"]), 5, "the other ear is the visit's")
	assert_eq(int(first["ears"]["right"]["pta"]), 35, "the visit's results are untouched")
	(shown["ears"]["right"] as Dictionary)["pta"] = 99
	assert_eq(int(second["ears"]["right"]["pta"]), 10, "a deep copy")
	var board := LevelCase.retest_board_case(_case("wax"), _case("wax")["retest"],
		{"ears": {"right": {"freqs": {1000: {"stored_db": 35}}}}})
	assert_eq(String(board["reveal"]["pattern"]), "retest")
	assert_eq(int((board["reveal"]["previous"]["thresholds"] as Dictionary)["1000"]), 35, "the visit's air goes behind the new chart")


func test_hoot_lines_cover_the_retest_and_runner() -> void:
	var wheres := {}
	for pair: Array in CaseData.hoot_lines(_case("wax")):
		wheres[String(pair[0])] = true
	for w: String in ["retest.intro", "retest.otoscopy.lines", "retest.tymp.after", "retest.before.choose", "retest.payoff"]:
		assert_true(wheres.has(w), "Hoot's %s lines are counted" % w)
	for line: String in [LevelCase.NO_MASKED_AIR, LevelCase.MISMATCH, LevelCase.RETEST_NEUTRAL, LevelCase.BRIEFING]:
		assert_true(line.split(" ", false).size() <= CaseData.HOOT_MAX_WORDS, line)


func test_new_patients_get_portraits() -> void:
	for who: String in ["Barnaby", "Skye"]:
		assert_true(CasePortraits.has(who), who)


func test_wax_means_headphones() -> void:
	var lc: Node = LevelCase.new()
	var had := Game.has_upgrade("insert_earphones")
	if not had:
		(Game.progress["upgrades"] as Array).append("insert_earphones")
	assert_eq(lc.call("_air_transducer"), &"inserts", "a clear canal takes inserts once owned")
	lc.set("_canal_blocked", true)
	assert_eq(lc.call("_air_transducer"), &"phones", "never a foam insert into a canal full of wax")
	if not had:
		(Game.progress["upgrades"] as Array).erase("insert_earphones")
	lc.free()


func test_new_gadgets_draw_every_view() -> void:
	for view: String in CaseData.VIEWS:
		var g: Control = add_node(CaseOtoscopy.new())
		g.set("case_view", view)
		await wait_frames(2)
		g.queue_free()
	var props: Control = add_node(CaseProps.new())
	await wait_frames(1)
	await props.call("play", "later", "TWO DAYS LATER")
	await props.call("play", "wax_jar")
	await props.call("play", "plane")
	await wait_frames(1)
