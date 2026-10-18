extends TestCase
## (Speech) Day 3, Mike (story/level_mike.gd, story/games/mike_board.gd): the board's three beats
## and their solvers, the level's SPEECH plans and objection cards with real numbers, Hoot's
## textbook fallback run, the Daily Decibel's word golf card, and a smoke run of the first beats.

const MikeBoard := preload("res://story/games/mike_board.gd")
const LevelMike := preload("res://story/level_mike.gd")

var beats: Array = []
var phases: Array[StringName] = []
var resolved: Array[StringName] = []


func before_each() -> void:
	beats.clear()
	phases.clear()
	resolved.clear()
	Events.awaiting_input.connect(_on_awaiting)
	Events.phase_changed.connect(_on_phase)
	Events.input_resolved.connect(_on_resolved)
	Game.begin_visit("mike")


func after_each() -> void:
	Events.awaiting_input.disconnect(_on_awaiting)
	Events.phase_changed.disconnect(_on_phase)
	Events.input_resolved.disconnect(_on_resolved)
	Hoot.clear()
	Hoot.clear_bubble_hint()
	Engine.time_scale = 1.0
	if tree.paused:
		tree.paused = false


func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
	beats.append({"beat": beat, "info": info, "solver": solver})


func _on_phase(p: StringName, _info: Dictionary) -> void:
	phases.append(p)


func _on_resolved(beat: StringName) -> void:
	resolved.append(beat)


func _last(beat: StringName) -> Dictionary:
	for i in range(beats.size() - 1, -1, -1):
		if beats[i]["beat"] == beat:
			return beats[i]
	return {}


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


func _twelve() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it: Dictionary in SpeechMaterial.items(LevelMike.LIST_ID):
		if out.size() < LevelMike.FAMILIAR_WORDS:
			out.append(it)
	return out


## Merged visit results like the SPEECH screen hands back: Mike's tones (all Hoot's) plus two SRTs
## run by the textbook.
func _merged() -> Dictionary:
	var tones := SpeechSession.tone_results_from(_mike())
	var s := SpeechSession.new(_mike(), 7)
	s.configure({"test": "srt", "tones": tones, "exclude": ["windmill"]})
	LevelMike.hoot_runs_ear(s, "right")
	LevelMike.hoot_runs_ear(s, "left")
	return SpeechSession.merge_results(tones, s.build_results())


func _find_label(root: Node, text: String) -> Label:
	if root is Label and (root as Label).text == text:
		return root as Label
	for c in root.get_children():
		var f := _find_label(c, text)
		if f != null:
			return f
	return null


# ---------------------------------------------------------------- the board

func test_board_familiarize_drop_slip_then_solver() -> void:
	var b := MikeBoard.new()
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 6.0
	await b.run_cards(_twelve())
	assert_true(Hoot.has_anchor("word_card_windmill"), "every card is an anchor")
	assert_true(Hoot.has_anchor("word_card_cupcake"))
	b.stumble("windmill")
	var done := [false]
	var run := func() -> void:
		await b.run_drop("windmill")
		done[0] = true
	run.call()
	await wait_frames(2)
	var beat := _last(&"familiarize_cards")
	assert_false(beat.is_empty(), "familiarize_cards beat")
	var info: Dictionary = beat.get("info", {})
	assert_eq(info.get("targets", []), ["word_card_windmill"], "targets the unknown word")
	assert_eq((info.get("mouse", {}) as Dictionary).get("click", ""), "word_card_windmill", "mouse route: click it")
	b.call("_try_drop", "cupcake")
	await wait_frames(2)
	assert_eq(b.drop_slips, 1, "dropping a word he read fine is a slip")
	assert_false(done[0], "still waiting for the windmill")
	assert_true(Hoot.is_showing(), "Hoot nudges kindly")
	(beat["solver"] as Callable).call()
	await wait_seconds(1.0)
	assert_true(done[0], "the solver drops it")
	assert_eq(b.dropped, ["windmill"] as Array[String])
	assert_true(resolved.has(&"familiarize_cards"), "input_resolved")


func test_board_familiarize_keyboard() -> void:
	var b := MikeBoard.new()
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 6.0
	await b.run_cards(_twelve())
	var run := func() -> void:
		await b.run_drop("windmill")
	run.call()
	await wait_frames(2)
	await tap_action(&"ui_left")   # from nothing, Left lands on the last card (the windmill)
	await tap_action(&"ui_accept")
	assert_true(b.is_dropped("windmill"), "arrows + Enter drop it")
	assert_eq(b.drop_slips, 0)


func test_board_objection_wrong_pick_then_solver_then_stamp() -> void:
	var lv: Node = LevelMike.new()
	lv.set("results", _merged())
	var cards: Array = lv.call("objection_cards")
	lv.free()
	var claim: Dictionary = cards[0]
	var clues: Array[Dictionary] = cards[1]
	assert_eq(clues.size(), 3, "three clues")
	var best: Array[String] = []
	for c: Dictionary in clues:
		if bool(c.get("best", false)):
			best.append(String(c["id"]))
		assert_true(String(c.get("title", "")).length() <= 40, "clue title fits: " + String(c.get("title", "")))
		if not bool(c.get("best", false)):
			assert_true(String(c.get("why", "")).split(" ", false).size() <= 18, "Hoot's nudge is 18 words or fewer")
	assert_eq(best, ["srt_pta"] as Array[String], "the SRT/PTA mismatch is the strongest clue")
	var srt_title := String(clues[1]["title"])
	assert_true(srt_title.begins_with("SRT ") and srt_title.contains(" vs PTA "), "real numbers: " + srt_title)
	assert_true(String(claim.get("quote", "")).contains("ANYTHING"))
	var b := MikeBoard.new()
	add_node(b)
	await wait_frames(2)
	b.show_objection(claim, clues)
	for id: String in ["objection_claim", "clue_srt_pta", "clue_coffee", "clue_canals"]:
		assert_true(Hoot.has_anchor(id), "anchor " + id)
	var done := [false]
	var run := func() -> void:
		await b.run_objection()
		done[0] = true
	run.call()
	await wait_frames(3)
	var beat := _last(&"objection_present")
	assert_false(beat.is_empty(), "objection_present beat")
	var info: Dictionary = beat.get("info", {})
	assert_eq(info.get("targets", []), ["objection_claim"])
	assert_eq((info.get("mouse", {}) as Dictionary).get("drag", []), ["clue_srt_pta", "objection_claim"], "mouse route: drag the best clue")
	b.call("_present", 0)   # the whisper: a real clue, just not a measurement
	await wait_frames(2)
	assert_false(b.solved, "a weaker clue is a gentle retry")
	assert_eq(b.picks, ["coffee"] as Array[String])
	(beat["solver"] as Callable).call()
	await wait_frames(3)
	assert_true(done[0] and b.solved, "the solver presents the strongest clue")
	assert_eq(b.picks, ["coffee", "srt_pta"] as Array[String])
	Engine.time_scale = 6.0
	b.set_referral_mode(true)
	await wait_seconds(0.5)
	var stamped := [false]
	var stamp := func() -> void:
		await b.run_stamp()
		stamped[0] = true
	stamp.call()
	await wait_frames(2)
	assert_false(_last(&"referral_stamp").is_empty(), "referral_stamp beat")
	assert_true(Hoot.has_anchor("referral_stamp"))
	await tap_action(&"ui_accept")
	assert_true(b.stamped, "Enter stamps")
	await wait_seconds(1.2)
	assert_true(stamped[0])


func test_board_objection_keyboard_numbers() -> void:
	var lv: Node = LevelMike.new()
	var cards: Array = lv.call("objection_cards")   # no results yet: sensible defaults
	lv.free()
	var b := MikeBoard.new()
	add_node(b)
	await wait_frames(2)
	b.show_objection(cards[0], cards[1])
	var run := func() -> void:
		await b.run_objection()
	run.call()
	await wait_frames(3)
	var two := InputEventKey.new()
	two.keycode = KEY_2
	two.pressed = true
	Input.parse_input_event(two)
	await wait_frames(2)
	await tap_action(&"ui_accept")
	assert_true(b.solved, "2 + Enter presents clue B (the SRT/PTA mismatch)")


# ---------------------------------------------------------------- the level's plans and numbers

func test_speech_plans_and_pta() -> void:
	var lv: Node = LevelMike.new()
	lv.set("patient", _mike())
	lv.set("tones", SpeechSession.tone_results_from(_mike()))
	var ws: Array[String] = []
	for it: Dictionary in _twelve():
		ws.append(String(it["id"]))
	lv.set("words", ws)
	lv.set("dropped", ["windmill"] as Array[String])
	assert_near(float(lv.call("ear_pta", "right")), 71.7, 0.1, "right PTA from the tones")
	assert_near(float(lv.call("ear_pta", "left")), 73.3, 0.1, "left PTA")
	var quick: Variant = Game.settings.get("quick_visit", true)
	Game.settings["quick_visit"] = true
	var r: Dictionary = lv.call("speech_plan", "right")
	var l: Dictionary = lv.call("speech_plan", "left")
	assert_eq(String(r["test"]), "srt")
	assert_eq((r["words"] as Array).size(), 12, "the twelve familiarised words")
	assert_eq(r.get("exclude", []), ["windmill"], "minus the one he didn't know")
	assert_false(r.has("hoot_turn_after"), "the coached right ear is all the player's")
	assert_true(String(r["intro"]).contains("85"), "PTA 70 + 15 = 85: " + String(r["intro"]))
	assert_true(String(r["intro"]).split(" ", false).size() <= 18)
	assert_false((r["tones"] as Dictionary).is_empty(), "tones for the PTA")
	assert_eq(int(l.get("hoot_turn_after", -1)), LevelMike.LEFT_SOLO_WORDS, "quick visit: Hoot finishes the left ear")
	Game.settings["quick_visit"] = false
	if not Game.cli_flag("quick"):
		assert_false((lv.call("speech_plan", "left") as Dictionary).has("hoot_turn_after"), "full visit: never")
	Game.settings["quick_visit"] = quick
	lv.free()


func test_hoot_textbook_run_gives_poor_agreement() -> void:
	var res := _merged()
	var srt: Dictionary = (res.get("speech", {}) as Dictionary).get("srt", {})
	for e: String in ["right", "left"]:
		assert_true(srt.has(e), e + " SRT stored")
		var sh: Dictionary = srt.get(e, {})
		assert_true(absi(int(sh.get("stored_db", -99)) - int(sh.get("true_db", 99))) <= 10, "%s SRT within 10 dB of the truth" % e)
		assert_eq(StringName(String(sh.get("agreement", ""))), &"poor", e + " agreement is poor (about 40 dB)")
		assert_true(bool(sh.get("by_hoot", false)), "Hoot's run is not scored")


func test_level_constants() -> void:
	var ids: Array[String] = []
	for it: Dictionary in _twelve():
		ids.append(String(it["id"]))
	assert_has(ids, LevelMike.UNKNOWN_WORD, "the unknown word is among the twelve cards")
	assert_eq(ids.size(), 12)
	var ch := Game.chapter("mike")
	assert_eq(String(ch.get("scene", "")), LevelMike.LEVEL_SCENE)
	assert_true(ResourceLoader.exists(LevelMike.LEVEL_SCENE), "the level scene exists")
	for s: StringName in LevelMike.STEPS:
		assert_true(LevelMike.STEP_LABELS.has(s), "label for step " + String(s))
	for rd: Dictionary in LevelMike.HISTORY:
		for o: Array in rd["options"]:
			assert_true(String(o[0]).length() <= 60, "choice fits: " + String(o[0]))


# ---------------------------------------------------------------- the Daily Decibel, Day 3

func _summary(aud: Dictionary, chapter: String = "mike") -> Dictionary:
	return {"patient_id": chapter, "score": 84.0, "grade": "A", "accuracy": 0.9, "technique": 0.9, "efficiency": 0.8,
		"care": 1.0, "comfort": 3, "medals": {"history": "gold", "instructions": "gold", "familiarize": "silver", "evidence": "gold", "referral": "bronze"},
		"coins_earned": 60, "coins_total": 60, "audiometry": aud, "chapter_id": chapter, "day": 3, "patient_name": "Mike Lenders"}


func test_daily_decibel_speech_card() -> void:
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var done := [false]
	var run := func() -> void:
		await paper.call("show_summary", _summary(_merged()))
		done[0] = true
	run.call()
	await wait_seconds(1.0)
	var heads: Dictionary = (paper.get_script() as GDScript).get("CHAPTER_HEADLINES")
	assert_true((heads.get("mike", {}) as Dictionary).size() == 5, "a Day 3 headline per grade")
	assert_true(_find_label(paper, String((heads["mike"] as Dictionary)["A"])) != null, "the Day 3 headline")
	assert_true(_find_label(paper, "SPORTS: THE WORD GOLF CARD") != null, "the word golf card on a speech day")
	assert_true(_find_label(paper, "SPORTS: THE BEEP GOLF CARD") == null, "instead of the beep card")
	assert_true(_find_label(paper, "POOR") != null, "the agreement chip")
	for m: String in ["Chat", "Explain", "Words", "Case", "Next"]:
		assert_true(_find_label(paper, m) != null, "medal " + m)
	var b := _last(&"results_continue")
	assert_false(b.is_empty(), "results_continue beat")
	(b["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(done[0])


func test_daily_decibel_tone_only_day3_results() -> void:
	# Day 3 results without "speech" (e.g. the SPEECH screen was skipped): the beep card, no crash
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var run := func() -> void:
		await paper.call("show_summary", _summary(SpeechSession.tone_results_from(_mike())))
	run.call()
	await wait_seconds(1.0)
	assert_true(_find_label(paper, "SPORTS: THE BEEP GOLF CARD") != null, "tone-only results keep the beep card")
	var b := _last(&"results_continue")
	(b["solver"] as Callable).call()
	await wait_frames(2)


# ---------------------------------------------------------------- smoke: the first beats

## The level from the start up to the instructions choice, every beat solved like the bot does.
func test_level_smoke_to_instructions() -> void:
	Engine.time_scale = 6.0
	var lv: Node = (load(LevelMike.LEVEL_SCENE) as PackedScene).instantiate()
	add_node(lv)
	var t0 := Time.get_ticks_msec()
	var handled := 0
	while Time.get_ticks_msec() - t0 < 60000:
		await wait_frames(2)
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		if b["beat"] == &"choice" and phases.has(&"instructions"):
			break
		await wait_seconds(0.1)
		assert_true((b["solver"] as Callable).is_valid(), "beat %s has a solver" % b["beat"])
		(b["solver"] as Callable).call()
	for p: StringName in [&"intro", &"history", &"otoscopy", &"instructions"]:
		assert_has(phases, p, "phase " + String(p))
	assert_ne(String((Game.visit.get("medals", {}) as Dictionary).get("history", "")), "", "history medal")
	assert_eq(String((Game.visit.get("medals", {}) as Dictionary).get("history", "")), "gold", "best questions = gold")
	var clinic: Node = lv.get("clinic")
	assert_eq(String(clinic.call("patient_name")), "Mike", "Mike walked in")
	lv.queue_free()
	await wait_seconds(0.5)
