extends TestCase
## Speech core (Days 3-5, CONTRACTS.md §9): the rules, the material, the patient's answers, the
## session's technique checker and results, and the voice's safety.

## The published spondee lists (ASHA 1988 guideline, asha.org/policy/gl1988-00008; CID W-1, Hirsh et
## al. 1952), whole: no word of any of them may be in our material.
const ASHA_A: PackedStringArray = ["airplane", "armchair", "backbone", "baseball", "birthday", "blackboard",
	"cookbook", "cowboy", "doormat", "drawbridge", "duck pond", "eardrum", "earthquake", "eyebrow", "greyhound",
	"hardware", "headlight", "horseshoe", "hot dog", "ice cream", "inkwell", "mousetrap", "mushroom", "northwest",
	"nutmeg", "oatmeal", "outside", "padlock", "pancake", "playground", "railroad", "stairway", "sunset",
	"toothbrush", "whitewash", "woodwork"]
const ASHA_B: PackedStringArray = ["inkwell", "woodwork", "grandson", "mousetrap", "playground", "baseball",
	"eardrum", "drawbridge", "sidewalk", "workshop", "toothbrush", "padlock", "railroad", "doormat", "northwest"]
const ASHA_C: PackedStringArray = ["cupcake", "toothbrush", "popcorn", "flashlight", "airplane", "bathtub",
	"fire truck", "bluebird", "baseball", "ice cream", "mailman", "toothpaste", "cowboy", "shoelace", "snowman",
	"reindeer", "hotdog", "football", "sailboat", "seesaw"]
const CID_W1: PackedStringArray = ["airplane", "armchair", "baseball", "birthday", "cowboy", "daybreak", "doormat",
	"drawbridge", "duckpond", "eardrum", "farewell", "grandson", "greyhound", "hardware", "headlight", "horseshoe",
	"hotdog", "hothouse", "iceberg", "inkwell", "mishap", "mousetrap", "northwest", "oatmeal", "padlock", "pancake",
	"playground", "railroad", "schoolboy", "sidewalk", "stairway", "sunset", "toothbrush", "whitewash", "woodwork",
	"workshop"]


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


func _session(p: PatientProfile, seed_value: int = 11, extra: Dictionary = {}) -> SpeechSession:
	var s := SpeechSession.new(p, seed_value)
	var plan := {"test": "srt", "tones": SpeechSession.tone_results_from(p)}
	plan.merge(extra, true)
	s.configure(plan)
	return s


## A word matched ignoring case, spaces and hyphens ("Duck pond" = "duckpond").
static func _plain(w: String) -> String:
	return w.to_lower().replace(" ", "").replace("-", "")


## Technique kinds the session emits, in order (each with its data).
func _record(s: SpeechSession) -> Array:
	var got: Array = []
	s.technique.connect(func(k: StringName, d: Dictionary) -> void: got.append([k, d]))
	return got


static func _kinds(got: Array) -> Array[StringName]:
	var out: Array[StringName] = []
	for g: Array in got:
		out.append(g[0])
	return out


## The textbook dance through the session's own coach (what Hoot and the bot do). Returns the sheet
## (or {} without storing, when do_store is false: the dial then sits at the bracketed SRT).
func _textbook(s: SpeechSession, ear: String, do_store: bool = true) -> Dictionary:
	s.begin(ear)
	for i in 200:
		var a := s.recommended_action()
		match a["action"]:
			&"score_correct":
				s.score(true)
			&"score_missed":
				s.score(false)
			&"louder":
				s.step_level(1)
			&"softer":
				s.step_level(-1)
			&"mask_toggle":
				s.toggle_mask()
			&"present":
				s.present()
			&"store":
				return s.store() if do_store else {}
			_:
				break
	return {}


# ---------------------------------------------------------------- rules

func test_pta_and_start() -> void:
	assert_near(SpeechRules.pta3({500: 20, 1000: 30, 2000: 40}), 30.0, 0.01)
	assert_eq(SpeechRules.pta_method({500: 10, 1000: 20, 2000: 60}), "best two")
	assert_near(SpeechRules.pta_for_speech({500: 10, 1000: 20, 2000: 60}), 15.0, 0.01)
	assert_eq(SpeechRules.srt_start(71.7), 85)
	assert_true(SpeechRules.srt_start_ok(85, 71.7))
	assert_false(SpeechRules.srt_start_ok(110, 71.7))
	assert_false(SpeechRules.srt_start_ok(75, 71.7))


func test_srt_steps() -> void:
	assert_eq(SpeechRules.srt_next_level(50, true), 40)
	assert_eq(SpeechRules.srt_next_level(50, false), 55)
	assert_eq(SpeechRules.srt_step_verdict(50, true, 40), &"textbook")
	assert_eq(SpeechRules.srt_step_verdict(50, true, 45), &"tolerated")
	assert_eq(SpeechRules.srt_step_verdict(50, false, 60), &"wrong")
	assert_eq(SpeechRules.srt_step_verdict(50, true, 55), &"wrong", "up 5 after a correct word")
	# another word at the same level: tolerated after a hit or a miss, while fewer than 4 were given there
	assert_eq(SpeechRules.SRT_MAX_WORDS_PER_LEVEL, 4)
	assert_eq(SpeechRules.srt_step_verdict(50, true, 50), &"tolerated", "a second word after a hit")
	assert_eq(SpeechRules.srt_step_verdict(50, false, 50, 1), &"tolerated", "a second word after a miss")
	assert_eq(SpeechRules.srt_step_verdict(50, false, 50, 3), &"tolerated", "the 4th word at a level")
	assert_eq(SpeechRules.srt_step_verdict(50, true, 50, 4), &"wrong", "the 5th word at a level (after a hit)")
	assert_eq(SpeechRules.srt_step_verdict(50, false, 50, 4), &"wrong", "the 5th word at a level (after a miss)")
	assert_eq(SpeechRules.srt_step_verdict(SpeechRules.MIN_DB, true, SpeechRules.MIN_DB, 9), &"textbook", "the floor")


func test_low_start_rule() -> void:
	assert_true(SpeechRules.srt_start_low(60, 71.7), "10 dB or more below the PTA")
	assert_false(SpeechRules.srt_start_low(70, 71.7), "the dial's default (the PTA) is not an ascending start")
	assert_false(SpeechRules.srt_start_low(80, 71.7), "just under the window is not one either")
	assert_false(SpeechRules.srt_start_low(85, 71.7), "in the window")
	assert_false(SpeechRules.srt_start_low(100, 71.7), "too high is not low")
	assert_false(SpeechRules.srt_start_low(0, NAN), "no PTA: no start window")


func test_srt_candidate_needs_the_bracket() -> void:
	var t := [{"db": 40, "correct": true}, {"db": 30, "correct": true}, {"db": 20, "correct": false},
		{"db": 25, "correct": true}, {"db": 15, "correct": false}]
	# 25 has one right only; 30 has one right only: nothing passes yet
	assert_eq(SpeechRules.srt_candidate(t), -1)
	t.append({"db": 20, "correct": false})
	t.append({"db": 25, "correct": true})
	# 25: 2/2, and 20 (5 below) is 0/2
	assert_eq(SpeechRules.srt_candidate(t), 25)
	assert_eq(SpeechRules.srt_lowest_passing(t), 25)


func test_srt_par_is_the_steady_dance() -> void:
	# 85 75 65 55 45 35 (6), 25 miss, 30, 20 miss, 25 miss, 30 = 11, + slack
	assert_eq(SpeechRules.srt_textbook_words(85, 30), 11)
	assert_eq(SpeechRules.srt_par(85, 30), 11 + SpeechRules.SRT_PAR_SLACK)


func test_agreement_bands() -> void:
	assert_eq(SpeechRules.agreement(30, 28.3), &"good")
	assert_eq(SpeechRules.agreement(40, 30.0), &"fair")
	assert_eq(SpeechRules.agreement(30, 71.7), &"poor")
	assert_eq(SpeechRules.srt_pta_diff(30, 71.7), -42)


func test_speech_masking_rule() -> void:
	assert_true(SpeechRules.speech_masking_needed(80, 10.0))
	assert_false(SpeechRules.speech_masking_needed(85, 70.0))
	assert_eq(SpeechRules.speech_mask_level(80), 60)


# ---------------------------------------------------------------- material

## Every list is valid, and no word of ASHA (1988) Appendices A (Table 1), B and C or CID W-1 is in any
## of them (the whole lists, matched ignoring case, spaces and hyphens).
func test_every_list_is_valid_and_original() -> void:
	var ids := SpeechMaterial.list_ids()
	assert_has(ids, "spondee_a")
	assert_eq([ASHA_A.size(), ASHA_B.size(), ASHA_C.size(), CID_W1.size()], [36, 15, 20, 36], "the whole published lists")
	var banned := {}
	for words: PackedStringArray in [ASHA_A, ASHA_B, ASHA_C, CID_W1]:
		for w: String in words:
			banned[_plain(w)] = w
	for w: String in ["Ice-Cream", "pop-corn", "bath tub", "SNOWMAN", "duckpond", "hot-dog", "firetruck"]:
		assert_true(banned.has(_plain(w)), "the guard catches %s" % w)
	var checked := 0
	for id: String in ids:
		var list := SpeechMaterial.load_list(id)
		assert_eq(SpeechMaterial.validate(list), PackedStringArray(), id)
		for it: Dictionary in SpeechMaterial.items(id):
			for t: String in [String(it.get("text", "")), String(it.get("id", ""))]:
				assert_false(banned.has(_plain(t)), "%s uses %s, a published spondee" % [id, t])
			checked += 1
	assert_true(checked >= 16, "checked %d words" % checked)


func test_half_words() -> void:
	var it := SpeechMaterial.item("spondee_a", "rainbow")
	assert_false(it.is_empty())
	assert_eq(SpeechMaterial.half_word(it, false), "...bow?")
	assert_eq(SpeechMaterial.half_word(it, true), "Rain...?")
	assert_eq(SpeechMaterial.recording_path("spondee_a", "__no_such_word__"), "", "no file, no recording")


# ---------------------------------------------------------------- patient

func test_mike_profile() -> void:
	var m := _mike()
	assert_eq(m.validate(), PackedStringArray())
	var sim := SpeechSim.new(m, 3)
	assert_eq(sim.true_srt("right"), 30)
	assert_near(sim.half_word_share(), 0.6, 0.001)
	# his tones say about 70: the PTA/SRT gap is the lesson
	assert_eq(SpeechRules.agreement(sim.true_srt("right"), SpeechRules.pta_for_speech(m.get_thresholds("right"))), &"poor")


func test_reliable_srt_follows_the_pta() -> void:
	var gus := Game.load_patient("gus") as PatientProfile
	var sim := SpeechSim.new(gus, 3)
	# Gus right 500/1k/2k = 20/25/40 spread 20: best two (22.5) -> 25
	assert_eq(sim.true_srt("right"), 25)
	assert_true(sim.p_srt("right", 50) > 0.98)
	assert_true(sim.p_srt("right", 15) < 0.05)
	assert_true(sim.p_srt("right", 30) > sim.p_srt("right", 25))
	assert_true(sim.p_srt("right", 25) > 0.5)


func test_answers_have_every_kind() -> void:
	var sim := SpeechSim.new(_mike(), 5)
	var it := SpeechMaterial.item("spondee_a", "rainbow")
	var kinds := {}
	for i in 300:
		var a := sim.respond_srt("right", 25, it, SpeechMaterial.items("spondee_a"))
		kinds[a["kind"]] = true
		assert_true(String(a["text"]) != "")
		assert_true(float(a["delay_s"]) >= 0.8)
		if a["kind"] == &"correct":
			assert_true(bool(a["correct"]))
	for k: StringName in [&"correct", &"half", &"wrong", &"silence"]:
		assert_true(kinds.has(k), "missing answer kind %s" % k)


## A wrong word is asked once: only its first letter up, one "?" (mishears like "rain... crow?" too).
func test_wrong_words_ask_once() -> void:
	assert_eq(SpeechSim.as_question("light... mouse?"), "Light... mouse?")
	assert_eq(SpeechSim.as_question("night house"), "Night house?")
	assert_eq(SpeechSim.as_question("doorbell"), "Doorbell?")
	assert_eq(SpeechSim.as_question(""), "?")
	var sim := SpeechSim.new(_mike(), 8)
	var all := SpeechMaterial.items("spondee_a")
	var wrong := 0
	for it: Dictionary in all:
		for i in 40:
			var a := sim.respond_srt("right", 25, it, all)
			var t := String(a["text"])
			assert_false(t.contains("??"), "%s: %s" % [it["id"], t])
			if a["kind"] == &"wrong":
				wrong += 1
				assert_eq(t.left(1), t.left(1).to_upper(), t)
				assert_true(t.ends_with("?"), t)
				assert_eq(t.count("?"), 1, "one question mark: " + t)
	assert_true(wrong > 20, "plenty of wrong words (%d)" % wrong)


func test_cross_hearing_and_masking() -> void:
	# a patient with one dead ear: loud speech crosses to the good ear unless it is masked
	var p := PatientProfile.new()
	p.id = "lopsided"
	p.display_name = "Lop Sided"
	for f: int in ClinicRules.AC_FREQS:
		p.thresholds_right[f] = 110
		p.thresholds_left[f] = 5
	var sim := SpeechSim.new(p, 9)
	assert_true(sim.p_srt("right", 90) > 0.9, "crossed to the left cochlea")
	var it := {"id": "x", "text": "rainbow", "parts": ["rain", "bow"]}
	var crossed := 0
	for i in 40:
		if sim.respond_srt("right", 90, it)["heard_by"] == &"cross":
			crossed += 1
	assert_true(crossed > 30, "the dead ear's words are the other cochlea's (%d/40)" % crossed)
	sim.mask_db = SpeechRules.speech_mask_level(90)
	assert_true(sim.p_srt("right", 90) < 0.05, "speech noise keeps the left ear busy")


## A word the test ear hears itself is never blamed on the other ear (no Ghost, no "mask!" tip),
## even when loud speech would also reach the other cochlea: Mike's first words at 85 / 90 dB.
func test_cross_credit_only_when_the_test_ear_missed() -> void:
	var sim := SpeechSim.new(_mike(), 5)
	var it := {"id": "x", "text": "rainbow", "parts": ["rain", "bow"]}
	assert_true(sim.p_srt_cross("left", 90) > 0.5, "90 dB does reach his right cochlea")
	for ear: String in ["right", "left"]:
		for i in 60:
			var a := sim.respond_srt(ear, 90 if ear == "left" else 85, it)
			assert_ne(a["heard_by"], &"cross", "%s ear's own word blamed on the other ear" % ear)


# ---------------------------------------------------------------- session

func test_textbook_search_on_mike() -> void:
	var exact := 0
	for seed_value in 30:
		var s := _session(_mike(), 100 + seed_value)
		var sheet := _textbook(s, "right")
		assert_false(sheet.is_empty(), "stored")
		assert_true(absi(int(sheet["stored_db"]) - 30) <= 5, "stored %d" % sheet["stored_db"])
		assert_eq(StringName(sheet["agreement"]), &"poor")
		assert_eq(int(sheet["start_db"]), 85)
		assert_true(bool(sheet["clean"]), "textbook is clean")
		if int(sheet["stored_db"]) == 30:
			exact += 1
	assert_true(exact >= 15, "textbook stores the true SRT most of the time (%d/30)" % exact)


func test_results_and_merge() -> void:
	var s := _session(_mike())
	_textbook(s, "right")
	_textbook(s, "left")
	var r := s.build_results()
	assert_has(r, "srt")
	assert_true((r["srt"] as Dictionary).has("right") and (r["srt"] as Dictionary).has("left"))
	assert_eq(int(r["scored_sheets"]), 2)
	assert_near(float(r["technique"]), 1.0, 0.001)
	assert_true(float(r["accuracy"]) >= 0.8)
	assert_true(float(r["efficiency"]) > 0.6)
	var tones := SpeechSession.tone_results_from(_mike())
	assert_eq(SpeechSession.scored_tone_stamps(tones), 0)
	var merged := SpeechSession.merge_results(tones, r)
	assert_near(float(merged["accuracy"]), float(r["accuracy"]), 0.001)
	assert_has(merged, "speech")
	assert_has(merged, "ears")
	assert_true(float(merged["score"]) > 80.0)


func test_misscoring_and_wrong_steps_are_caught() -> void:
	var s := _session(_mike())
	var kinds: Array[StringName] = []
	s.technique.connect(func(k: StringName, _d: Dictionary) -> void: kinds.append(k))
	s.begin("right")
	s.set_level(60)   # too low a start (PTA 72: start 82-97)
	var tr := s.present()
	assert_false(tr.is_empty())
	assert_true(kinds.has(&"srt_start"))
	assert_true(s.present().is_empty(), "no new word before the score")
	s.score(not bool(tr["correct"]))   # the wrong score
	assert_true(kinds.has(&"misscored"))
	s.present()   # a second word at the same level is fine
	assert_false(kinds.has(&"srt_wrong_step"), "another word at the same level")
	s.score(true)
	s.step_level(1)
	s.present()   # up 5 after a word scored correct: not the dance
	assert_true(kinds.has(&"srt_wrong_step"))
	s.score(true)
	var sheet := s.store()
	assert_true(kinds.has(&"srt_store_no_bracket"))
	assert_false(bool(sheet["clean"]))
	assert_false(bool(sheet["bracketed"]))
	assert_true(s.build_results()["technique"] < 0.5)


## Up to SRT_MAX_WORDS_PER_LEVEL words at one level, after a hit or a miss; the 5th is a wrong step.
func test_more_words_at_one_level() -> void:
	var s := _session(_mike())
	var got := _record(s)
	s.begin("right")
	s.set_level(85)
	for i in SpeechRules.SRT_MAX_WORDS_PER_LEVEL:
		assert_false(s.present().is_empty())
		s.score(i % 2 == 0)   # scored a hit, then a miss, then a hit, then a miss
	assert_false(_kinds(got).has(&"srt_wrong_step"), "4 words at 85, after hits and misses")
	assert_true(_kinds(got).count(&"speech_textbook") >= 3, "each same-level word is a clean step")
	s.present()   # the 5th word at 85
	var kinds := _kinds(got)
	assert_true(kinds.has(&"srt_wrong_step"), "the 5th word at one level")
	var d: Dictionary = got[kinds.find(&"srt_wrong_step")][1]
	assert_eq(int(d["words_here"]), 4)
	assert_eq(int(d["expected"]), 90, "after a miss: up 5")
	assert_eq(String(d["message"]), "4 words at one level is plenty. Got it: down 10. Missed: up 5.", "not 'another word here is fine'")
	assert_eq(s.tip_text(&"srt_wrong_step"), "Got it: down 10. Missed: up 5. Another word here is fine too!")
	# coming back to a level counts the words already given there
	var s2 := _session(_mike())
	var got2 := _record(s2)
	s2.begin("right")
	s2.set_level(85)
	for i in 3:
		s2.present()
		s2.score(true)
	s2.set_level(75)
	s2.present()
	s2.score(false)
	s2.set_level(80)
	s2.present()
	s2.score(false)
	s2.set_level(85)
	s2.present()   # the 4th word at 85: up 5 after a miss, the textbook step anyway
	s2.score(true)
	assert_false(_kinds(got2).has(&"srt_wrong_step"))
	s2.present()   # the 5th word at 85
	assert_true(_kinds(got2).has(&"srt_wrong_step"), "5 words at 85 in this ear")


## A first word below the start window is an srt_start error, unless the plan allows an ascending
## start (low_start_ok): then it is a clean srt_low_start with Hoot's line. Too high stays an error.
func test_low_start_ok() -> void:
	var s := _session(_mike())
	var got := _record(s)
	s.begin("right")
	s.set_level(60)
	s.present()
	assert_eq(_kinds(got), [&"srt_start"] as Array[StringName], "no flag: a low start is an error")
	var ok := _session(_mike(), 11, {"low_start_ok": true})
	var got_ok := _record(ok)
	ok.begin("right")
	ok.set_level(60)
	ok.present()
	assert_eq(_kinds(got_ok), [&"srt_low_start"] as Array[StringName])
	var d: Dictionary = got_ok[0][1]
	assert_eq(String(d.get("message", "")), "Starting low and coming up: smart when answers look exaggerated.")
	assert_eq(ok.combo, 1, "a clean check: combo +1")
	assert_eq(ok.checks, 1)
	assert_eq(ok.clean_checks, 1)
	assert_true(int(d.get("points", 0)) > 0)
	assert_true(ok.errors.is_empty())
	var high := _session(_mike(), 11, {"low_start_ok": true})
	var got_high := _record(high)
	high.begin("right")
	high.set_level(100)
	high.present()
	assert_eq(_kinds(got_high), [&"srt_start"] as Array[StringName], "too high is still an error")
	var good := _session(_mike(), 11, {"low_start_ok": true})
	var got_good := _record(good)
	good.begin("right")
	good.set_level(85)
	good.present()
	assert_eq(_kinds(got_good), [&"srt_good_start"] as Array[StringName], "the window is still the window")
	# the dial opens at the PTA rounded to 5 (70 for Mike's right ear): pressing straight away is not
	# an ascending start, flag or not
	var lazy := _session(_mike(), 11, {"low_start_ok": true})
	var got_lazy := _record(lazy)
	lazy.begin("right")
	assert_eq(lazy.db, 70)
	lazy.present()
	assert_eq(_kinds(got_lazy), [&"srt_start"] as Array[StringName], "the untouched dial is a start error")
	assert_false((got_good[0][1] as Dictionary).has("message"), "a plain clean kind has no line")


## Every SRT sheet says whether it was stored at the bracketed SRT.
func test_sheet_bracketed() -> void:
	var s := _session(_mike())
	var sheet := _textbook(s, "right")
	assert_true(bool(sheet["bracketed"]))
	assert_eq(int(sheet["stored_db"]), int(sheet["candidate_db"]))
	# bracketed, but stored 5 dB above the SRT
	var w := _session(_mike())
	assert_true(_textbook(w, "right", false).is_empty())
	var cand := w.candidate()
	assert_ne(cand, SpeechRules.NO_SRT)
	w.step_level(1)
	var off := w.store()
	assert_eq(int(off["candidate_db"]), cand)
	assert_false(bool(off["bracketed"]), "stored off the bracketed SRT")
	# stored before any bracket
	var n := _session(_mike())
	n.begin("right")
	n.set_level(85)
	n.present()
	n.score(true)
	var early := n.store()
	assert_eq(int(early["candidate_db"]), SpeechRules.NO_SRT)
	assert_false(bool(early["bracketed"]), "no bracket yet")


## Hoot's agreement line depends on the direction; the dB limits come from SpeechRules.
func test_agreement_tips_by_direction() -> void:
	var s := _session(_mike())
	var good := s.agreement_tip(&"good", -3)
	assert_has(good, "reliable SRT")
	assert_has(good, "within %d dB" % SpeechRules.AGREE_GOOD_DB)
	var better := s.agreement_tip(&"poor", -42)
	assert_has(better, "42 dB better")
	assert_has(better, "non-organic")
	assert_has(better, "recheck")
	var worse := s.agreement_tip(&"poor", 20)
	assert_has(worse, "20 dB worse")
	for w: String in ["instructions", "language", "word recognition", "sloping loss"]:
		assert_has(worse, w)
	assert_false(worse.contains("non-organic"), "a worse SRT is not a sign of a non-organic loss")
	assert_has(s.agreement_tip(&"fair", -9), "9 dB better")
	assert_has(s.agreement_tip(&"fair", 9), "9 dB worse")
	assert_eq(s.agreement_tip(&"", 0), "")
	for k: StringName in SpeechSession.AGREEMENT_TIPS:
		var parts := String(k).split("_")
		var t := s.agreement_tip(StringName(parts[0]), -9 if String(k).ends_with("better") else 9)
		assert_false(t.contains("{") or t.contains("honest"), "%s: %s" % [k, t])
		assert_true(t.split(" ", false).size() <= Hoot.MAX_WORDS, "%s: %s" % [k, t])
	# end to end: Mike's SRT is far better than his tones; an SRT worse than the PTA gets the other line
	var lines: Array[String] = []
	s.technique.connect(func(k: StringName, d: Dictionary) -> void:
		if k == &"srt_agreement":
			lines.append(String(d["message"])))
	_textbook(s, "right")
	assert_eq(lines.size(), 1)
	assert_has(lines[0], "better than the PTA")
	assert_has(lines[0], "non-organic")
	var slow := Game.load_patient("gus").duplicate() as PatientProfile
	slow.speech = {"srt_offset": {"right": 25}}
	var g := _session(slow)
	var glines: Array[String] = []
	g.technique.connect(func(k: StringName, d: Dictionary) -> void:
		if k == &"srt_agreement":
			glines.append(String(d["message"])))
	var gs := _textbook(g, "right")
	assert_eq(StringName(gs["agreement"]), &"poor")
	assert_true(int(gs["diff"]) > 0)
	assert_eq(glines.size(), 1)
	assert_has(glines[0], "worse than the PTA")


## Every Hoot line the session can send fits Hoot.MAX_WORDS and has no unfilled token.
func test_tips_are_short() -> void:
	var s := _session(_mike())
	var lines: Array[String] = []
	for k: StringName in SpeechSession.TIPS:
		lines.append(s.tip_text(k))
	for k: StringName in SpeechSession.MISSCORED_TIPS:
		lines.append(_mike().say(SpeechSession.MISSCORED_TIPS[k]))
	assert_eq(s.tip_text(&"half_word"), "Half a word is a miss. Lots of half-words can be a sign of a non-organic loss.")
	for t: String in lines:
		assert_true(t.split(" ", false).size() <= Hoot.MAX_WORDS, "%d words: %s" % [t.split(" ", false).size(), t])
		assert_false(t.contains("{"), t)
		assert_false(t.contains("exaggerating"), t)


func test_hoot_turn_is_not_scored() -> void:
	var s := _session(_mike())
	s.scoring = false
	var sheet := _textbook(s, "left")
	assert_true(bool(sheet["by_hoot"]))
	assert_eq(StringName(sheet["golf"]), &"hoot")
	var r := s.build_results()
	assert_eq(int(r["scored_sheets"]), 0)
	assert_eq(s.checks, 0)


func test_state_keys() -> void:
	var s := _session(_mike())
	s.begin("right", true)
	var st := s.get_state()
	for k: String in ["test", "ear", "db", "pta", "recommended_start", "candidate_db", "trail", "awaiting_score",
			"current", "mask_on", "masking_needed", "done", "next_word", "combo", "points", "scoring"]:
		assert_has(st, k)
	assert_eq(int(st["db"]), 70, "the dial starts at the PTA, rounded")
	assert_eq(int(st["recommended_start"]), 85)


# ---------------------------------------------------------------- voice

func test_voice_is_quiet_and_in_one_ear() -> void:
	var v := SpeechVoice.new()
	add_node(v)
	# an id no list uses, so this always measures the murmur even after recordings are dropped in
	var it := {"id": "__murmur_test", "text": "rainbow", "parts": ["rain", "bow"]}
	var dur := v.play_item("right", "spondee_a", it, 120.0)
	assert_between(dur, 0.4, 1.2)
	var out := v.render(int(dur * SpeechVoice.MIX_RATE) + 100)
	var peak_r := 0.0
	var peak_l := 0.0
	for x: Vector2 in out:
		peak_r = maxf(peak_r, absf(x.y))
		peak_l = maxf(peak_l, absf(x.x))
	assert_true(peak_r > 0.01, "something plays")
	assert_true(peak_r <= AudioSafety.peak_ceiling() + 1e-6, "never above -12 dBFS")
	assert_eq(peak_l, 0.0, "only the test ear")
	assert_false(v.is_playing())
	v.start_noise("left", 100.0)
	var n := v.render(22050)
	var rms := 0.0
	for x: Vector2 in n:
		assert_eq(x.y, 0.0)
		assert_true(absf(x.x) <= AudioSafety.masker_ceiling() + 1e-6)
		rms += x.x * x.x
	assert_true(sqrt(rms / n.size()) > 0.001, "speech noise plays")


## A dropped-in recording: 16- and 8-bit PCM decode to mono (stereo averaged, resampled), the level
## is set by the speech, not by the silence around it, and compressed imports are refused.
func test_recordings_decode_and_level() -> void:
	var tone := PackedFloat32Array()
	for i in 11025:   # 0.25 s of a 300 Hz tone at 0.5 peak, between 0.5 s of silence on each side
		tone.append(0.5 * sin(TAU * 300.0 * i / 44100.0))
	var silence := PackedFloat32Array()
	silence.resize(22050)
	var pcm := silence + tone + silence
	var w16 := AudioStreamWAV.new()
	w16.format = AudioStreamWAV.FORMAT_16_BITS
	w16.mix_rate = 44100
	w16.stereo = true
	var b16 := PackedByteArray()
	b16.resize(pcm.size() * 4)
	for i in pcm.size():
		b16.encode_s16(i * 4, int(pcm[i] * 32767.0))
		b16.encode_s16(i * 4 + 2, int(pcm[i] * 32767.0))
	w16.data = b16
	var mono := SpeechVoice.wav_to_mono(w16)
	assert_near(float(mono.size()), pcm.size() / 2.0, 2.0, "44.1 kHz resampled to 22.05 kHz")
	var w8 := AudioStreamWAV.new()
	w8.format = AudioStreamWAV.FORMAT_8_BITS
	w8.mix_rate = 22050
	var b8 := PackedByteArray()
	b8.resize(pcm.size())
	for i in pcm.size():
		b8.encode_s8(i, int(pcm[i] * 127.0))
	w8.data = b8
	assert_eq(SpeechVoice.wav_to_mono(w8).size(), pcm.size(), "8-bit decodes too")
	var qoa := AudioStreamWAV.new()
	qoa.format = AudioStreamWAV.FORMAT_QOA
	assert_true(SpeechVoice.wav_to_mono(qoa).is_empty(), "a compressed import is refused (the murmur plays)")
	# the speech part comes out at unit RMS whatever the padding (a sine of peak 0.5 has RMS 0.354)
	var lv := SpeechVoice.normalised_speech(mono)
	var sum := 0.0
	var n := 0
	for x: float in lv:
		if absf(x) > 0.05:
			sum += x * x
			n += 1
	assert_near(sqrt(sum / n), 1.0, 0.15, "unit RMS over the speech, not the silence")
	assert_eq(ProjectSettings.get_setting("importer_defaults/wav", {}).get("compress/mode", -1), 0, "WAVs import uncompressed")


func test_speech_level_mapping() -> void:
	assert_true(AudioSafety.speech_to_rms(0.0) < AudioSafety.speech_to_rms(40.0))
	assert_true(AudioSafety.speech_to_rms(200.0) <= AudioSafety.speech_ceiling() + 1e-9)
