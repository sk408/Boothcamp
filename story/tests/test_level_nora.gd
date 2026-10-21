extends TestCase
## (Days 4-5) Day 4, Nora (story/level_nora.gd, story/games/nora_board.gd, story/papers/
## paper_word_golf.gd, story/dev_nora.gd): the movie beat (announced only before its first play),
## the masking-movie offer, the word-list plans and quick-visit counts, coached SRTs before Day 3,
## the Roll Call (nine cards, six flags; keys, buttons, a wrong sort bouncing back), the stamp tray
## and the letter, the word golf card on the paper, Hoot's line lengths and words, a smoke run of
## the first beats, and (clinical review A1 and A2, all days) the routine lines and the masking
## recap before Hoot's masked bone.

const LevelNora := preload("res://story/level_nora.gd")
const NoraBoard := preload("res://story/games/nora_board.gd")
const PaperWordGolf := preload("res://story/papers/paper_word_golf.gd")
const DevNora := preload("res://story/dev_nora.gd")
const Hud := preload("res://story/hud.gd")
const LevelMike := preload("res://story/level_mike.gd")
const LevelCase := preload("res://story/level_case.gd")
const Movies := preload("res://story/explainers/movies.gd")

## Words Hoot never says on Day 4 (he names no diagnosis).
const BANNED: Array[String] = ["tumour", "tumor", "neuroma", "schwannoma", "cancer", "acoustic"]

var beats: Array = []
var phases: Array[StringName] = []
var phase_info: Array[Dictionary] = []
var resolved: Array[StringName] = []
var lines: Array[String] = []
## (A1, A2) Phases with their test ("audiometry:bc_masked"), movies ("movie:masking_recap") and
## lines ("Hoot: ..."), in order.
var timeline: Array[String] = []
## (A1) A label showed the caption _play_until_test watched for.
var caption_seen := false
var _progress: Dictionary = {}
var _settings: Dictionary = {}


## A SPEECH screen stand-in: records each start_test, then hands back fixed results.
class FakeScreen extends CanvasLayer:
	signal test_finished(results: Dictionary)
	var quick_visit := true
	var calls: Array[Dictionary] = []
	var res: Dictionary = {}

	func start_test(_p: PatientProfile, ear: String, coached: bool, plan: Dictionary) -> void:
		calls.append({"ear": ear, "coached": coached, "test": String(plan.get("test", ""))})
		(func() -> void: test_finished.emit(res)).call_deferred()


func before_each() -> void:
	beats.clear()
	phases.clear()
	phase_info.clear()
	resolved.clear()
	lines.clear()
	timeline.clear()
	_progress = Game.progress.duplicate(true)
	_settings = Game.settings.duplicate(true)
	Events.awaiting_input.connect(_on_awaiting)
	Events.phase_changed.connect(_on_phase)
	Events.input_resolved.connect(_on_resolved)
	Events.dialogue_line.connect(_on_line)
	Game.begin_visit("nora")


func after_each() -> void:
	Events.awaiting_input.disconnect(_on_awaiting)
	Events.phase_changed.disconnect(_on_phase)
	Events.input_resolved.disconnect(_on_resolved)
	Events.dialogue_line.disconnect(_on_line)
	Game.progress = _progress
	Game.settings = _settings
	Hoot.clear()
	Hoot.clear_bubble_hint()
	Engine.time_scale = 1.0
	if tree.paused:
		tree.paused = false


func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
	beats.append({"beat": beat, "info": info, "solver": solver})
	if beat == &"explainer":
		timeline.append("movie:" + String(info.get("movie", "")))


func _on_phase(p: StringName, info: Dictionary) -> void:
	phases.append(p)
	phase_info.append(info)
	timeline.append("%s:%s" % [p, String(info.get("test", ""))])


func _on_resolved(beat: StringName) -> void:
	resolved.append(beat)


func _on_line(speaker: String, text: String) -> void:
	lines.append("%s: %s" % [speaker, text])
	timeline.append("%s: %s" % [speaker, text])


func _count(beat: StringName) -> int:
	return beats.filter(func(b: Dictionary) -> bool: return b["beat"] == beat).size()


func _last(beat: StringName) -> Dictionary:
	for i in range(beats.size() - 1, -1, -1):
		if beats[i]["beat"] == beat:
			return beats[i]
	return {}


func _nora() -> PatientProfile:
	return Game.load_patient("nora") as PatientProfile


## Hoot's textbook visit (dev_nora): tones with bone at 1k / 4k, both SRTs, Word lists 1-3.
func _textbook() -> Dictionary:
	var p := _nora()
	return DevNora.textbook_results(p, DevNora.textbook_tones(p))


## The level from the top until `stop` (a phase), every beat solved as the bot solves it.
func _play_until(stop: StringName, max_ms: int = 60000) -> Node:
	Engine.time_scale = 6.0
	var lv: Node = (load(LevelNora.LEVEL_SCENE) as PackedScene).instantiate()
	add_node(lv)
	var t0 := Time.get_ticks_msec()
	var handled := 0
	while Time.get_ticks_msec() - t0 < max_ms:
		await wait_frames(2)
		if phases.has(stop):
			break
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		await wait_seconds(0.05)
		assert_true((b["solver"] as Callable).is_valid(), "beat %s has a solver" % b["beat"])
		(b["solver"] as Callable).call()
	return lv


## (A1, A2) The level from the top until a phase whose info names `test` (Hoot's masked bone:
## "bc_masked"), every beat solved as the bot solves it; caption_seen turns true once a label in
## the level shows `caption` (the otoscope's).
func _play_until_test(test: String, caption: String, max_ms: int = 120000) -> Node:
	Engine.time_scale = 6.0
	caption_seen = false
	var lv: Node = (load(LevelNora.LEVEL_SCENE) as PackedScene).instantiate()
	add_node(lv)
	var t0 := Time.get_ticks_msec()
	var handled := 0
	while Time.get_ticks_msec() - t0 < max_ms:
		await wait_frames(2)
		if not caption_seen and phases.has(&"otoscopy"):
			for n: Node in lv.find_children("*", "Label", true, false):
				caption_seen = caption_seen or (n as Label).text == caption
		if timeline.has("audiometry:" + test) or timeline.has("speech:" + test):
			break
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		await wait_seconds(0.05)
		assert_true((b["solver"] as Callable).is_valid(), "beat %s has a solver" % b["beat"])
		(b["solver"] as Callable).call()
	return lv


func _words(line: String) -> int:
	return line.split(" ", false).size()


## A line with its tokens at their longest: numbers as 3 digits, a gap as "15 to 30".
func _longest(line: String) -> String:
	return line.replace("%%", "%").replace("%d", "100").replace("%s", "15 to 30")


func _key_event(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_frames(2)


# ---------------------------------------------------------------- the movies (contract §9.20)

func test_movie_announced_only_when_unseen() -> void:
	Game.mark_movie_seen(LevelNora.MASKING_MOVIE)
	assert_false(Game.is_movie_seen(LevelNora.MOVIE_ID), "a fresh save has not seen the word movie")
	var lv := await _play_until(&"intro")
	assert_has(phases, &"intro", "the visit went on to the intro")
	var announce := "Hoot: New trick today: WORD SCORES. A quick cartoon first, then our next patient!"
	assert_has(lines, announce, "the one-line announcement before the first play")
	assert_true(_count(&"explainer") == 1, "the movie played (its explainer beat)")
	var i := phases.find(&"explainer")
	assert_true(i >= 0 and not bool(phase_info[i].get("seen", true)), "phase explainer, seen false")
	assert_eq(String(phase_info[i].get("movie", "")), LevelNora.MOVIE_ID)
	lv.queue_free()
	await wait_seconds(0.3)
	# once seen (watched to its seen_at scene): only the replay choice, no announcement
	Game.mark_movie_seen(LevelNora.MOVIE_ID)
	beats.clear()
	phases.clear()
	phase_info.clear()
	lines.clear()
	var lv2 := await _play_until(&"intro")
	assert_false(lines.has(announce), "no announcement once the movie is seen")
	var first: Dictionary = beats[0] if not beats.is_empty() else {}
	assert_eq(first.get("beat", &""), &"choice", "the first beat is the replay choice")
	assert_true(String((first.get("info", {}) as Dictionary).get("prompt", "")).contains("again"), "a replay offer")
	assert_eq(_count(&"explainer"), 0, "the solver skips the replay (best answer)")
	var j := phases.find(&"explainer")
	assert_true(j >= 0 and bool(phase_info[j].get("seen", false)), "phase explainer, seen true")
	lv2.queue_free()
	await wait_seconds(0.3)


func test_masking_offer_only_without_day2() -> void:
	Game.mark_movie_seen(LevelNora.MOVIE_ID)
	var lv := await _play_until(&"intro")
	var b0: Dictionary = beats[0] if not beats.is_empty() else {}
	assert_eq(b0.get("beat", &""), &"choice", "a player who skipped Day 2 is offered the masking movie")
	assert_true(String((b0.get("info", {}) as Dictionary).get("prompt", "")).contains("Ghost"), "the Ghost movie offer")
	lv.queue_free()
	await wait_seconds(0.3)
	beats.clear()
	phases.clear()
	(Game.progress["chapters_done"] as Array).append("bonnie")
	var lv2 := await _play_until(&"intro")
	for b: Dictionary in beats:
		if b["beat"] == &"choice":
			assert_false(String((b["info"] as Dictionary).get("prompt", "")).contains("Ghost"), "no offer after Day 2")
	lv2.queue_free()
	await wait_seconds(0.3)


# ---------------------------------------------------------------- the routine (clinical review A1, A2)

## (A1, all days) A fresh speculum on the otoscope's caption, and the cases' listening-check line
## once, before the first tone test. (A2, all days) A player who declined the day-start masking
## offer gets the recap card once, after Hoot's unmasked bone and before his masked bone, then where
## the full movie lives; the pause menu lists the masking movie from then on.
func test_routine_and_masking_recap_when_unseen() -> void:
	assert_eq(LevelMike.ROUTINE_LINE, LevelCase.ROUTINE_LINE, "the cases' own words")
	assert_eq(LevelNora.MASKING_HINT, LevelCase.MASKING_HINT, "the cases' own words")
	assert_eq(LevelNora.MASKING_RECAP, LevelCase.MASKING_RECAP)
	assert_true(LevelMike.SPECULUM_CAPTION.begins_with(LevelCase.OTHER_EAR_CAPTION.substr(0, 15)), "a fresh speculum, as on the case days")
	var caption := LevelMike.SPECULUM_CAPTION % ["Nora", "LEFT"]
	for line: String in [LevelMike.ROUTINE_LINE, LevelNora.MASKING_HINT, caption]:
		assert_true(_words(line) <= Hoot.MAX_WORDS, line)
	Game.mark_movie_seen(LevelNora.MOVIE_ID)
	assert_false(Game.is_movie_seen(LevelNora.MASKING_MOVIE), "a fresh save has not seen the masking movie")
	var lv := await _play_until_test("bc_masked", caption)
	assert_true(caption_seen, "the otoscope's caption: " + caption)
	var routine := "Hoot: " + LevelMike.ROUTINE_LINE
	assert_eq(timeline.count(routine), 1, "the listening check, once")
	assert_true(timeline.find(routine) < timeline.find("audiometry:ac"), "before the first tone test")
	var recap := "movie:" + LevelNora.MASKING_RECAP
	var at := timeline.find(recap)
	assert_eq(timeline.count(recap), 1, "the recap card, once")
	assert_false(timeline.has("movie:" + LevelNora.MASKING_MOVIE), "the offer was declined (its best answer)")
	assert_true(at > timeline.find("audiometry:bc") and at < timeline.find("audiometry:bc_masked"),
		"after unmasked bone, before masked bone")
	var hint := "Hoot: " + LevelNora.MASKING_HINT
	assert_eq(timeline.count(hint), 1, "then where the full movie lives")
	assert_true(timeline.find(hint) > at and timeline.find(hint) < timeline.find("audiometry:bc_masked"), "right after the card")
	assert_true(lv.is_in_group(Movies.MASKING_LEVEL_GROUP), "the pause menu offers every replay movie now (E19)")
	assert_has(Movies.for_level(Game.current_chapter_id, true), LevelNora.MASKING_MOVIE)
	await lv.call("_recap")
	assert_eq(timeline.count(recap), 1, "never twice a visit")
	assert_eq(timeline.count(hint), 1)
	lv.queue_free()
	await wait_seconds(0.5)


## (A2, all days) A watched masking movie: no recap card, no pointer, the pause menu as it was.
func test_no_masking_recap_once_the_movie_is_seen() -> void:
	Game.mark_movie_seen(LevelNora.MOVIE_ID)
	Game.mark_movie_seen(LevelNora.MASKING_MOVIE)
	var lv := await _play_until_test("bc_masked", LevelMike.SPECULUM_CAPTION % ["Nora", "LEFT"])
	assert_has(timeline, "audiometry:bc_masked", "the visit reached Hoot's masked bone")
	assert_false(timeline.has("movie:" + LevelNora.MASKING_RECAP), "no recap card")
	assert_false(timeline.has("Hoot: " + LevelNora.MASKING_HINT), "no pointer to the movie")
	assert_false(lv.is_in_group(Movies.MASKING_LEVEL_GROUP), "the pause menu keeps the day's own movie")
	assert_eq(timeline.count("Hoot: " + LevelMike.ROUTINE_LINE), 1, "the listening check still")
	lv.queue_free()
	await wait_seconds(0.5)


# ---------------------------------------------------------------- plans (contract §9.21)

func test_word_list_plans_and_quick_counts() -> void:
	var lv := LevelNora.new()
	lv.set("tones", DevNora.textbook_tones(_nora()))
	var ids: Array[String] = []
	for i in 5:
		ids.append(String(lv.call("next_list")))
	assert_eq(ids, ["words_1", "words_2", "words_3", "words_4", "words_4"] as Array[String], "play order (D25)")
	var r: Dictionary = lv.call("list_plan", &"right", "words_1", true)
	assert_eq(String(r["test"]), "wrs")
	assert_eq(String(r["list"]), "words_1")
	assert_eq(int(r["hoot_turn_after"]), 8, "quick: 8 words on the right")
	assert_eq(int(r["lens_try_after"]), 2)
	assert_has(r["call_it"], &"faint_hit")
	assert_eq(r["chatter"], LevelNora.NORA_CHATTER)
	var l: Dictionary = lv.call("list_plan", &"left", "words_2", true)
	assert_eq(int(l["level"]), SpeechRules.CHAT_DB, "List 2 starts at chatting level")
	assert_true(l.has("chat_demo"), "the tea demo")
	assert_eq(int(l["ensure_audible_miss_by"]), 6)
	assert_has(l["call_it"], &"audible_miss")
	assert_true(bool(l["self_correct"]))
	assert_eq(int(l["hoot_turn_after"]), 8, "quick: 8 words on the left")
	assert_false(l.has("mask_on"), "the player decides about noise")
	var re: Dictionary = lv.call("list_plan", &"redo", "words_3", true, 2)
	assert_eq(int(re["redo_of"]), 2)
	assert_eq(int(re["hoot_turn_after"]), 5, "quick: 5 words on a redo")
	var lo: Dictionary = lv.call("list_plan", &"louder", "words_3", true, 2)
	assert_eq(int(lo["louder_than"]), 2)
	assert_true(bool(lo["mask_on"]) and bool(lo["lock_noise"]) and bool(lo["loud_bubble"]), "the louder list: noise on and locked")
	assert_eq(int(lo["hoot_turn_after"]), 5, "quick: 5 words on the louder list")
	for kind: StringName in [&"right", &"left", &"redo", &"louder"]:
		var full: Dictionary = lv.call("list_plan", kind, "words_1", false, 2)
		assert_false(full.has("hoot_turn_after"), "%s: a full visit gives the player every word" % kind)
		assert_eq(String(full["transducer"]), "phones")
	lv.free()


func test_srts_are_coached_until_day3_is_done() -> void:
	Game.settings["quick_visit"] = false
	for done: bool in [false, true]:
		if done:
			(Game.progress["chapters_done"] as Array).append("mike")
		var lv := LevelNora.new()
		var hud := Hud.new()
		add_node(hud)
		hud.call("set_steps", LevelNora.STEPS, LevelNora.STEP_LABELS, "NORA")
		var box := DialogueBox.new()
		add_node(box)
		var fake := FakeScreen.new()
		add_node(fake)
		lv.set("hud", hud)
		lv.set("dialogue", box)
		lv.set("screen", fake)
		lv.set("tones", DevNora.textbook_tones(_nora()))
		var finished := [false]
		var run := func() -> void:
			await lv.call("_srt")
			finished[0] = true
		var handled := beats.size()
		run.call()
		var t0 := Time.get_ticks_msec()
		while not finished[0] and Time.get_ticks_msec() - t0 < 10000:
			await wait_frames(2)
			while handled < beats.size():
				(beats[handled]["solver"] as Callable).call()
				handled += 1
		assert_true(finished[0], "the SRT beat ends")
		assert_eq(fake.calls.size(), 2, "both ears on the screen (no quick visit)")
		for c: Dictionary in fake.calls:
			assert_eq(String(c["test"]), "srt")
			assert_eq(bool(c["coached"]), not done, "%s ear coached: %s (Day 3 done: %s)" % [c["ear"], c["coached"], done])
		assert_eq(String(fake.calls[0]["ear"]), "right", "right first")
		lv.free()


# ---------------------------------------------------------------- the Roll Call

func test_roll_call_cards_from_the_textbook_visit() -> void:
	var cards := LevelNora.roll_call_cards(_textbook())
	assert_eq(cards.size(), 9, "nine cards")
	var ids: Array[String] = []
	var flags: Array[String] = []
	for c: Dictionary in cards:
		ids.append(String(c["id"]))
		if bool(c["flag"]):
			flags.append(String(c["id"]))
		for k: String in ["text", "src", "right_line", "wrong_line"]:
			assert_ne(String(c.get(k, "")), "", "%s has %s" % [c["id"], k])
	assert_eq(ids, LevelNora.ROLL_CALL_ORDER, "the fixed order")
	assert_eq(flags.size(), 6, "six red flags: %s" % str(flags))
	for id: String in ["hiss", "wobbly", "tones", "apart", "predicted", "louder"]:
		assert_has(flags, id, id + " is a red flag")
	# a visit where no word rule fired: those cards are FINE, with their own lines
	var fine := LevelNora.roll_call_cards({})
	var by := {}
	for c: Dictionary in fine:
		by[String(c["id"])] = c
	for id: String in ["apart", "predicted", "louder"]:
		assert_false(bool((by[id] as Dictionary)["flag"]), id + " without its rule is fine")
	assert_eq(String((by["apart"] as Dictionary)["right_line"]), "Close enough to be chance: not a red flag on its own.")


func test_board_keys_buttons_and_a_wrong_sort() -> void:
	var cards := LevelNora.roll_call_cards(_textbook())
	var b := NoraBoard.new()
	b.setup(cards)
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 4.0
	for id: String in ["flag_yes_button", "flag_no_button", "flag_podium", "case_stamps", "referral_letter"]:
		assert_true(Hoot.has_anchor(id), "anchor " + id)
	var yes := b.get_node("flag_yes_button") as Button
	var no := b.get_node("flag_no_button") as Button
	assert_true(yes.text.begins_with("RED FLAG") and no.text.begins_with("FINE"), "%s / %s" % [yes.text, no.text])
	var done := [false]
	var run := func() -> void:
		await b.run_roll_call()
		done[0] = true
	run.call()
	await wait_seconds(0.4)
	var beat := _last(&"flag_pick")
	assert_false(beat.is_empty(), "flag_pick beat")
	var info: Dictionary = beat["info"]
	assert_eq(String(info["card"]), "hiss", "the first card")
	assert_eq(String((info["mouse"] as Dictionary)["click"]), "flag_yes_button", "mouse route: the right sort's button")
	# a wrong sort by key: the card bounces back to the podium and waits for a new pick
	await tap_action(&"speech_incorrect")
	await wait_seconds(1.0)
	assert_eq(b.slips, 1, "one wrong sort")
	assert_eq(b.sorted.size(), 0, "the card is still unsorted")
	var nodes: Array = b.get("_nodes")
	assert_eq((nodes[0] as Control).position, NoraBoard.PODIUM_AT, "back on the podium")
	assert_eq(_count(&"flag_pick"), 2, "a new pick for the same card")
	assert_eq(String(_last(&"flag_pick")["info"]["card"]), "hiss")
	assert_true(resolved.has(&"flag_pick"), "input_resolved")
	# the right sort by its button
	yes.pressed.emit()
	await wait_seconds(1.0)
	assert_eq(b.sorted, ["hiss"] as Array[String])
	# the next one (canals, fine) by key
	await tap_action(&"speech_incorrect")
	await wait_seconds(1.0)
	assert_eq(b.sorted, ["hiss", "canals"] as Array[String])
	# the rest by the solver, whenever the board waits for a pick
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 20000:
		await wait_frames(2)
		if bool(b.get("_accepting")):
			(_last(&"flag_pick")["solver"] as Callable).call()
	assert_true(done[0], "the Roll Call ends")
	assert_eq(b.sorted, LevelNora.ROLL_CALL_ORDER, "every card sorted, in order")
	assert_eq(b.slips, 1)
	assert_eq(b.get("_placed"), {"flag": 6, "fine": 3}, "six on the red-flag riser, three on the fine one")


func test_stamp_tray_and_letter() -> void:
	var res := _textbook()
	var b := NoraBoard.new()
	b.setup(LevelNora.roll_call_cards(res))
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 4.0
	await b.open_tray()
	var file: Label = b.get("_file_label")
	assert_true(file.text.contains("rollover") and file.text.contains("one-sided hiss"), file.text)
	var got := [-1]
	var pick := func() -> void:
		got[0] = await b.choose_stamp("Your call for Nora:", CaseRules.DECISIONS.find(&"refer"))
	pick.call()
	await wait_frames(2)
	var beat := _last(&"choice")
	var want: Array[String] = []
	for d: StringName in CaseRules.DECISIONS:
		want.append(CaseRules.DECISION_STAMPS[d])
	assert_eq((beat["info"] as Dictionary)["options"], want, "the three stamps, in CaseRules' order")
	assert_eq(int((beat["info"] as Dictionary)["best"]), CaseRules.DECISIONS.find(&"refer"))
	await _key_event(KEY_1)
	assert_eq(int(got[0]), CaseRules.DECISIONS.find(&"fit"), "key 1 = the first stamp")
	await b.slam(&"fit", false)
	assert_true((b.get("_stamps")[0] as Button).disabled, "a wrong stamp greys out")
	got[0] = -1
	pick.call()
	await wait_frames(2)
	await _key_event(KEY_1)
	assert_eq(int(got[0]), -1, "a greyed stamp can't be picked again")
	(_last(&"choice")["solver"] as Callable).call()
	await wait_frames(2)
	assert_eq(int(got[0]), CaseRules.DECISIONS.find(&"refer"), "the solver stamps REFER")
	await b.slam(&"refer", true)
	var text := LevelNora.letter_text(res)
	await b.show_letter(text)
	var label: Label = b.get("_letter_label")
	assert_eq(label.text, text)
	assert_false((b.get("_letter") as Control).visible, "the letter slid into its envelope")


func test_letter_and_referral() -> void:
	var res := _textbook()
	var text := LevelNora.letter_text(res)
	assert_true(text.contains("imaging"), "the letter asks for imaging")
	assert_true(text.contains("before any hearing aid fitting"), "no fitting before the doctor")
	assert_false(text.contains("{"), "every token filled: " + text)
	var left: Dictionary = ((res["speech"] as Dictionary)["wrs"] as Dictionary)["left"]
	assert_true(text.contains("left %d%% at %d dB HL" % [int(left["pct"]), int(left["level_db"])]), text)
	var lv := LevelNora.new()
	lv.set("results", res)
	assert_eq(lv.call("referral"), &"refer", "the word scores call for a referral")
	lv.set("results", {})
	assert_eq(lv.call("referral"), &"refer", "refer when the summary is missing")
	lv.free()
	var low := text.to_lower()
	for w: String in BANNED:
		assert_false(low.contains(w), "the letter names no diagnosis: " + w)


# ---------------------------------------------------------------- the paper (CHAPTER4 §10)

func test_word_golf_card_rows_and_lines() -> void:
	var res := _textbook()
	var sp: Dictionary = res["speech"]
	var rs := PaperWordGolf.rows(sp)
	assert_eq(rs.size(), 3, "three lists")
	var order: Array[String] = []
	for r: Dictionary in rs:
		order.append("%s %s" % [r["ear"], r["title"]])
	assert_eq(order, ["right " + SpeechMaterial.title("words_1"), "left " + SpeechMaterial.title("words_2"),
		"left " + SpeechMaterial.title("words_3")] as Array[String], "play order")
	var t0 := PaperWordGolf.row_texts(rs[0])
	assert_eq(t0[1], "none", "no noise on the right")
	assert_true(t0[0].begins_with("R · Word list 1 · "), t0[0])
	var t1 := PaperWordGolf.row_texts(rs[1])
	assert_true(int(t1[1]) > 0, "noise on the left: " + t1[1])
	var summary := DevNora.paper_summary(res, "S")
	var ls := PaperWordGolf.lines(sp, summary)
	var roll: Dictionary = (sp["wrs_summary"] as Dictionary)["rollover"]
	assert_has(ls, "Louder: %d%% fell to %d%% (rollover)." % [int(roll["comfy_pct"]), int(roll["louder_pct"])])
	assert_has(ls, "Red flags sorted: 9 of 9 (wrong sorts: 0).")
	assert_true(ls[0].begins_with("Tones predict at least: right "), ls[0])
	assert_true(ls.any(func(l: String) -> bool: return l.begins_with("SRT by Hoot: right ")), "Hoot's SRTs: %s" % str(ls))
	assert_has(ls, PaperWordGolf.HOOT_SAYS_GOOD)
	assert_has(ls, PaperWordGolf.ARTS)
	# a redone list: struck through, marked, and still in play order
	DevNora.with_redone_list(res)
	var rs2 := PaperWordGolf.rows(res["speech"])
	assert_eq(rs2.size(), 4)
	assert_true(bool(rs2[1]["redone"]), "List 2 redone")
	assert_true(PaperWordGolf.row_texts(rs2[1])[0].ends_with("(redone)"))
	assert_false(bool(rs2[2]["redone"]))


func test_daily_decibel_day4_paper_fits_the_window() -> void:
	for redone: bool in [false, true]:
		await _paper_fits(redone)


func _paper_fits(redone: bool) -> void:
	var res := _textbook()
	if redone:
		DevNora.with_redone_list(res)
	var summary := DevNora.paper_summary(res, "A")
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var run := func() -> void:
		await paper.call("show_summary", summary)
	run.call()
	await wait_seconds(1.0)
	var labels: Array[String] = []
	for l: Node in paper.find_children("*", "Label", true, false):
		labels.append((l as Label).text)
	assert_has(labels, PaperWordGolf.HEADER, "the day's own sports column")
	assert_has(labels, LevelNora.WEATHER, "the day's weather")
	assert_has(labels, LevelNora.HEADLINES["A"])
	assert_false(labels.any(func(t: String) -> bool: return t.contains("BEEP GOLF")), "not the tone card")
	var sz: Vector2 = (paper.get("_paper") as Control).size
	assert_eq(float(paper.call("fit_scale", sz, Vector2(1280, 720))), 1.0, "fits at scale 1 (redone list: %s): %s" % [redone, sz])
	var b := _last(&"results_continue")
	if not b.is_empty():
		(b["solver"] as Callable).call()
	await wait_frames(2)
	paper.queue_free()
	await wait_frames(2)


# ---------------------------------------------------------------- lines

func test_hoot_lines_fit_and_name_no_diagnosis() -> void:
	var src := FileAccess.get_file_as_string((LevelNora as Script).resource_path)
	var found: Array[String] = []
	for pat: String in ["_say\\(\"Hoot\", \"((?:[^\"\\\\]|\\\\.)*)\"", "\\[\"hoot\", \"((?:[^\"\\\\]|\\\\.)*)\"\\]",
			"\"(?:intro|hoot_turn_text)\": \"((?:[^\"\\\\]|\\\\.)*)\"", "&\"(?:fit|today|refer)\": \"((?:[^\"\\\\]|\\\\.)*)\"",
			"\"((?:My quick SRTs|Your turn: SRT)[^\"]*)\""]:
		var re := RegEx.create_from_string(pat)
		for m: RegExMatch in re.search_all(src):
			found.append(m.get_string(1))
	for c: Dictionary in LevelNora.roll_call_cards(_textbook()) + LevelNora.roll_call_cards({}):
		found.append(String(c["right_line"]))
		found.append(String(c["wrong_line"]))
	assert_true(found.size() >= 60, "found Hoot's lines (%d)" % found.size())
	for line: String in found:
		var full := _longest(line)
		assert_true(_words(full) <= Hoot.MAX_WORDS, "%d words: %s" % [_words(full), full])
		assert_false(full.contains("[") or full.contains("Space") or full.contains("Enter"), "keys only through {key:}: " + full)
		var low := full.to_lower()
		for w: String in BANNED:
			assert_false(low.contains(w), "no diagnosis (%s): %s" % [w, full])
	for line: String in [LevelNora.gap_words(Vector2i(15, 30)), "Left %s dB worse than right in the air." % "15 to 30"]:
		assert_true(_words(line) <= Hoot.MAX_WORDS, line)


func test_nora_says_darling_three_times_at_most() -> void:
	var src := FileAccess.get_file_as_string((LevelNora as Script).resource_path)
	assert_true(src.count("darling") <= 3, "darling %d times" % src.count("darling"))
	assert_true(src.count("darling") >= 1, "her word is there")


func test_level_constants() -> void:
	var ch := Game.chapter("nora")
	assert_eq(int(ch.get("day", 0)), 4)
	assert_eq(String(ch.get("scene", "")), LevelNora.LEVEL_SCENE)
	assert_eq(String(ch.get("requires", "")), "mike")
	assert_true(ResourceLoader.exists(LevelNora.LEVEL_SCENE), "the level scene exists")
	assert_true(ResourceLoader.exists(LevelNora.SPORTS_SCRIPT), "the sports column exists")
	assert_eq(LevelNora.MEDAL_BEATS.size(), 5)
	for g: String in ["S", "A", "B", "C", "Do-over"]:
		assert_true(LevelNora.HEADLINES.has(g) and LevelNora.SUBHEADS.has(g), g)
	var subs := LevelNora.subheads(_textbook())
	assert_false(String(subs["A"]).contains("{"), "the A subhead is filled: " + String(subs["A"]))
	assert_eq(LevelNora.history_medal(4), "gold")
	assert_eq(LevelNora.history_medal(3), "silver")
	assert_eq(LevelNora.history_medal(1), "bronze")
	assert_eq(LevelNora.masking_medal({"masking_needed": true, "masked": true}, false), "gold")
	assert_eq(LevelNora.masking_medal({"masking_needed": true, "masked": true}, true), "silver")
	assert_eq(LevelNora.masking_medal({"masking_needed": true, "masked": false}, false), "bronze")
	assert_eq(LevelNora.gap_words(Vector2i(20, 30)), "20 to 30")
	assert_eq(LevelNora.gap_words(Vector2i(25, 25)), "25")


# ---------------------------------------------------------------- smoke: the first beats

## The level from the start to the AudiOtron, every beat solved like the bot does.
func test_level_smoke_to_the_tones() -> void:
	Game.mark_movie_seen(LevelNora.MOVIE_ID)
	Game.mark_movie_seen(LevelNora.MASKING_MOVIE)
	var lv := await _play_until(&"audiometry")
	for p: StringName in [&"explainer", &"intro", &"history", &"otoscopy", &"instructions", &"audiometry"]:
		assert_has(phases, p, "phase " + String(p))
	var medals: Dictionary = Game.visit.get("medals", {})
	assert_eq(String(medals.get("history", "")), "gold", "best questions = gold")
	assert_eq(String(medals.get("instructions", "")), "gold", "right instructions first = gold")
	assert_true(bool(Game.get_visit_flag("asked_red_flags", false)), "the red-flag question was asked")
	var clinic: Node = lv.get("clinic")
	assert_eq(String(clinic.call("patient_name")), "Nora", "Nora walked in")
	lv.queue_free()
	await wait_seconds(0.5)
