extends TestCase
## Speech core (Days 3-5, CONTRACTS.md §9): the rules, the material, the patient's answers, the
## session's technique checker and results, and the voice's safety.


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


func _session(p: PatientProfile, seed_value: int = 11) -> SpeechSession:
	var s := SpeechSession.new(p, seed_value)
	s.configure({"test": "srt", "tones": SpeechSession.tone_results_from(p)})
	return s


## The textbook dance through the session's own coach (what Hoot and the bot do). Returns the sheet.
func _textbook(s: SpeechSession, ear: String) -> Dictionary:
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
				return s.store()
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
	assert_eq(SpeechRules.srt_step_verdict(50, true, 50), &"wrong")


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

func test_every_list_is_valid_and_original() -> void:
	var ids := SpeechMaterial.list_ids()
	assert_has(ids, "spondee_a")
	# words of published spondee lists must never appear (a sample of the classic adult list)
	var banned := ["airplane", "armchair", "baseball", "birthday", "cowboy", "hotdog", "iceberg", "mousetrap",
		"padlock", "pancake", "playground", "railroad", "sidewalk", "sunset", "toothbrush", "workshop"]
	for id: String in ids:
		var list := SpeechMaterial.load_list(id)
		assert_eq(SpeechMaterial.validate(list), PackedStringArray(), id)
		for it: Dictionary in SpeechMaterial.items(id):
			assert_false(banned.has(String(it["text"])), "%s uses %s" % [id, it["text"]])


func test_half_words() -> void:
	var it := SpeechMaterial.item("spondee_a", "cupcake")
	assert_eq(SpeechMaterial.half_word(it, false), "...cake?")
	assert_eq(SpeechMaterial.half_word(it, true), "Cup...?")
	assert_eq(SpeechMaterial.recording_path("spondee_a", "cupcake"), "")


# ---------------------------------------------------------------- patient

func test_mike_profile() -> void:
	var m := _mike()
	assert_eq(m.validate(), PackedStringArray())
	var sim := SpeechSim.new(m, 3)
	assert_eq(sim.true_srt("right"), 30)
	assert_near(sim.half_word_share(), 0.6, 0.001)
	# his tones say about 70: the PTA/SRT gap is the lesson
	assert_eq(SpeechRules.agreement(sim.true_srt("right"), SpeechRules.pta_for_speech(m.get_thresholds("right"))), &"poor")


func test_honest_srt_follows_the_pta() -> void:
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
	var it := SpeechMaterial.item("spondee_a", "cupcake")
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
	sim.mask_db = SpeechRules.speech_mask_level(90)
	assert_true(sim.p_srt("right", 90) < 0.05, "speech noise keeps the left ear busy")


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
	s.present()   # same level again: not the dance
	assert_true(kinds.has(&"srt_wrong_step"))
	s.score(true)
	var sheet := s.store()
	assert_true(kinds.has(&"srt_store_no_bracket"))
	assert_false(bool(sheet["clean"]))
	assert_true(s.build_results()["technique"] < 0.5)


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
	var it := SpeechMaterial.item("spondee_a", "rainbow")
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


func test_speech_level_mapping() -> void:
	assert_true(AudioSafety.speech_to_rms(0.0) < AudioSafety.speech_to_rms(40.0))
	assert_true(AudioSafety.speech_to_rms(200.0) <= AudioSafety.speech_ceiling() + 1e-9)
