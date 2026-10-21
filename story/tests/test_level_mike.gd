extends TestCase
## (Speech) Day 3, Mike (story/level_mike.gd, story/games/mike_board.gd): the board's three beats
## and their solvers, the level's SPEECH plans and objection cards with real numbers (and Hoot's
## recheck when the player's SRT can't show the mismatch), Hoot's textbook fallback run, Hoot's
## line lengths, the Daily Decibel's word golf card, and a smoke run of the first beats.

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
	assert_true(Hoot.has_anchor("word_card_rainbow"))
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
	b.call("_try_drop", "rainbow")
	await wait_frames(2)
	assert_eq(b.drop_slips, 1, "dropping a word he said back fine is a slip")
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


## Familiarisation by ear: the cards face the clinician (the sign), Hoot says each word and Mike
## says it back (the "now saying" line, a tick per card); the windmill gets his echo but no tick.
func test_board_familiarize_by_ear() -> void:
	var b := MikeBoard.new()
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 6.0
	await b.run_cards(_twelve())
	var sign := _find_label(b, MikeBoard.CUE_TEXT)
	assert_true(sign != null and sign.is_visible_in_tree(), "the 'Mike can't see this' sign is up")
	assert_true(_find_label(b, MikeBoard.CUE_HEAD) != null, "the clinician's side")
	assert_true(Hoot.has_anchor("familiarize_cue"))
	assert_true(_find_label(b, "SPONDEE LIST A: HOOT SAYS, MIKE REPEATS") != null, "the header says who says what")
	var done := [false]
	var sweep := func() -> void:
		await b.say_along(0, 10, 3.0)
		done[0] = true
	sweep.call()
	var seen_hoot := false
	var seen_mike := false
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 5000:
		var line := b.echo_line()
		seen_hoot = seen_hoot or line.begins_with("Hoot: \"")
		seen_mike = seen_mike or line.contains("Mike: \"")
		await wait_frames(1)
	assert_true(done[0], "the sweep ends by itself")
	assert_true(seen_hoot and seen_mike, "the line shows Hoot's word, then Mike's echo")
	for it: Dictionary in _twelve().slice(0, 11):
		assert_true(b.is_echoed(String(it["id"])), "Mike said %s back" % it["id"])
	assert_false(b.is_echoed("windmill"), "the windmill isn't said yet")
	assert_eq(b.echo_line(), "", "the line clears after the sweep")
	b.say_word("windmill", "Wind... mill?")
	assert_eq(b.echo_line(), "Hoot: \"windmill\"      Mike: \"Wind... mill?\"", "every word on screen, his echo too")
	assert_false(b.is_echoed("windmill"), "no tick: he doesn't know it")
	assert_eq(b.echo_of("rainbow"), "Rainbow!")
	# a sweep cut short (the player clicked on) still ticks its cards and returns
	var b2 := MikeBoard.new()
	add_node(b2)
	await wait_frames(2)
	await b2.run_cards(_twelve())
	var done2 := [false]
	var sweep2 := func() -> void:
		await b2.say_along(0, 10, 60.0)
		done2[0] = true
	sweep2.call()
	await wait_frames(3)
	b2.finish_say_along()
	await wait_frames(1)
	assert_true(done2[0], "finish_say_along ends the sweep")
	assert_true(b2.is_echoed("raincoat"), "every card it covered is ticked")
	b2.finish_say_along()   # a second call is harmless


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
	assert_true(bool(l.get("hoot_turn_after_up", false)),
		"the player's words run to the first miss and the step back up 5; Hoot finishes the bracket")
	assert_true(LevelMike.LEFT_SOLO_WORDS >= 9, "the cap leaves room: eight words down to the first miss (90 to 20), then up 5")
	assert_true(String(l["intro"]).contains("90"), "PTA 75 + 15 = 90: " + String(l["intro"]))
	assert_true(String(l["intro"]).split(" ", false).size() <= 18)
	assert_false(bool(r.get("low_start_ok", true)), "no low start before the whisper is on screen")
	lv.set("_whisper_seen", true)
	assert_true(bool((lv.call("speech_plan", "right") as Dictionary).get("low_start_ok", false)), "after the whisper: starting low is smart")
	assert_true(bool((lv.call("speech_plan", "left") as Dictionary).get("low_start_ok", false)))
	assert_eq(String(lv.call("pta_line")), "That's his PTA, pure-tone average: his beeps at 500, 1000 and 2000 Hz, averaged.",
		"Mike's PTA is the three-frequency average")
	Game.settings["quick_visit"] = false
	if not Game.cli_flag("quick"):
		assert_false((lv.call("speech_plan", "left") as Dictionary).has("hoot_turn_after"), "full visit: never")
	Game.settings["quick_visit"] = quick
	lv.free()


## A right-ear SRT sheet like SpeechSession's (no "bracketed" key: the screen works it out).
static func _sheet(stored: int, agreement: String, cand: int) -> Dictionary:
	var pta := 71.7
	return {"ear": "right", "test": "srt", "stored_db": stored, "pta": pta, "agreement": agreement, "diff": SpeechRules.srt_pta_diff(stored, pta),
		"candidate_db": cand, "errors": [] if cand == stored else [&"srt_store_no_bracket"], "by_hoot": false, "strokes": 6, "par": 12, "golf": "par"}


static func _with_right(sheet: Dictionary) -> Dictionary:
	return {"speech": {"srt": {"right": sheet}}}


## A level (not in the tree) with Mike's tones and the twelve cards, for the plans and the recheck.
func _level_with_tones() -> Node:
	var lv: Node = LevelMike.new()
	lv.set("patient", _mike())
	lv.set("tones", SpeechSession.tone_results_from(_mike()))
	var ws: Array[String] = []
	for it: Dictionary in _twelve():
		ws.append(String(it["id"]))
	lv.set("words", ws)
	lv.set("dropped", ["windmill"] as Array[String])
	return lv


func test_objection_cards_by_sheet() -> void:
	var cases: Array = [
		["fair, no bracket", _sheet(65, "fair", SpeechRules.NO_SRT), false],
		["good", _sheet(70, "good", 70), false],
		["poor, worse", _sheet(90, "poor", 90), false],
		["poor, better", _sheet(30, "poor", 30), true],
	]
	var unbracketed := _sheet(30, "poor", 30)
	unbracketed["bracketed"] = false   # the session's own key wins
	cases.append(["poor, better, bracketed false", unbracketed, false])
	for c: Array in cases:
		var sheet: Dictionary = c[1]
		var what := String(c[0])
		assert_eq(LevelMike._srt_shows_mismatch(sheet), bool(c[2]), "mismatch: " + what)
		assert_true(LevelMike.recheck_line(sheet).split(" ", false).size() <= Hoot.MAX_WORDS, "recheck line fits: " + what)
		var lv: Node = LevelMike.new()
		lv.set("results", _with_right(sheet))
		var cards: Array = lv.call("objection_cards")
		lv.free()
		var claim: Dictionary = cards[0]
		var clues: Array[Dictionary] = cards[1]
		var best: Array[String] = []
		for cl: Dictionary in clues:
			if bool(cl.get("best", false)):
				best.append(String(cl["id"]))
		assert_eq(best, ["srt_pta"] as Array[String], "the measurement is the best clue, never the whisper: " + what)
		assert_eq(String(clues[1]["title"]), "SRT %d vs PTA 72" % int(sheet["stored_db"]), "the player's own numbers: " + what)
		var verdict := String(claim["verdict"])
		var note := String(claim["note"])
		if int(sheet["diff"]) < 0:
			assert_true(verdict.contains("softer"), what + ": " + verdict)
		else:
			assert_true(verdict.contains("more"), what + ": " + verdict)
		if what.begins_with("poor, worse"):
			assert_false(note.contains("beat"), "words worse than beeps never read as his story: " + note)
		assert_true(note.begins_with(String(sheet["agreement"]).capitalize()), note)
	# the clue captions don't give the answer away (the explanations wait in "why")
	var lv2: Node = LevelMike.new()
	var neutral: Array = lv2.call("objection_cards")
	lv2.free()
	for cl: Dictionary in (neutral[1] as Array):
		if String(cl["id"]) != "srt_pta":
			var sub := String(cl["sub"]).to_lower()
			for giveaway: String in ["measurement", "calibrated", "real loss", "but "]:
				assert_false(sub.contains(giveaway), "neutral caption (%s): %s" % [cl["id"], cl["sub"]])


func test_recheck_without_screen_keeps_the_player_sheet() -> void:
	var lv := _level_with_tones()
	var mine := _sheet(65, "fair", SpeechRules.NO_SRT)
	lv.set("results", _with_right(mine))
	assert_false(LevelMike._srt_shows_mismatch(mine))
	await lv.call("rerun_right")
	var re: Dictionary = lv.get("recheck")
	assert_false(re.is_empty(), "Hoot's recheck sheet")
	assert_true(bool(re.get("by_hoot", false)), "his run is not scored")
	assert_true(LevelMike._srt_shows_mismatch(re), "by the book, Mike's SRT shows the mismatch")
	assert_eq(int((lv.call("srt_sheet", "right") as Dictionary).get("stored_db", -1)), 65, "the player's own sheet stays for the grade")
	assert_eq(lv.call("board_sheet"), re, "the board uses the recheck")
	var cards: Array = lv.call("objection_cards")
	var title := String((cards[1] as Array)[1]["title"])
	assert_true(title.begins_with("Hoot's recheck: SRT ") and title.contains(" vs PTA "), title)
	assert_true(title.length() <= 40, "fits the clue card: " + title)
	lv.free()


func test_recheck_on_the_speech_screen() -> void:
	Engine.time_scale = 8.0
	var quick: Variant = Game.settings.get("quick_visit", true)
	Game.settings["quick_visit"] = false   # a full visit: Hoot still reruns the ear himself
	var lv := _level_with_tones()
	var s := (load(LevelMike.SPEECH_SCENE) as PackedScene).instantiate() as SpeechScreen
	add_node(s)
	lv.set("screen", s)
	var plan: Dictionary = lv.call("speech_plan", "right")
	plan["hoot_turn_after"] = 0
	s.quick_visit = true
	var mine: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: mine.append(r), CONNECT_ONE_SHOT)
	s.start_test(_mike(), "right", false, plan)   # stands in for the player's own (stored) right ear
	var t0 := Time.get_ticks_msec()
	while mine.is_empty() and Time.get_ticks_msec() - t0 < 30000:
		await wait_frames(2)
	assert_false(mine.is_empty(), "the first right ear is stored")
	s.quick_visit = false
	var player_session := s.session
	lv.set("results", mine[0] if not mine.is_empty() else {})
	await lv.call("rerun_right")
	var re: Dictionary = lv.get("recheck")
	assert_false(re.is_empty(), "Hoot's recheck on the screen")
	assert_true(bool(re.get("by_hoot", false)))
	assert_true(LevelMike._srt_shows_mismatch(re), "the recheck shows the mismatch")
	assert_ne(s.session, player_session, "on a fresh session")
	assert_eq(bool(s.get("quick_visit")), LevelMike.quick_visit(), "the quick-visit setting comes back")
	s.start_test(_mike(), "left", false, lv.call("speech_plan", "left"))
	assert_eq(s.session, player_session, "the left ear goes back to the player's session")
	assert_true(player_session.is_done("right"), "with the first right SRT still stored")
	Game.settings["quick_visit"] = quick
	lv.free()


## A stand-in clinic for the speech step: the calls _speech() makes, and a camera to switch off.
class StubClinic extends Node3D:
	var cam := Camera3D.new()
	var calls: Array[String] = []

	func _init() -> void:
		add_child(cam)

	func focus_camera(_shot: StringName, _seconds: float = 0.0) -> void:
		calls.append("focus_camera")

	func hold_response_button(_on: bool) -> void:
		calls.append("hold_response_button")

	func get_main_camera() -> Camera3D:
		return cam

	func take_off_earphones() -> void:
		calls.append("take_off_earphones")


## The level without its _ready (no clinic scene, no _run): the test hands _speech() what it needs.
class QuietLevel extends "res://story/level_mike.gd":
	func _ready() -> void:
		pass


## The speech step itself (level_mike._speech()) through the recheck gate: the player's right SRT is
## stored 5 dB off its bracket, so it can't show the mismatch; Hoot reruns the ear on the SPEECH
## screen, the board uses his sheet, the results keep the player's for the grade, and the left
## ear goes on (Hoot finishing it after the step up).
func test_speech_step_through_the_recheck_gate() -> void:
	Engine.time_scale = 8.0
	var quick: Variant = Game.settings.get("quick_visit", true)
	Game.settings["quick_visit"] = true
	var lv: Node = QuietLevel.new()
	lv.set("patient", _mike())
	lv.set("tones", SpeechSession.tone_results_from(_mike()))
	var ws: Array[String] = []
	for it: Dictionary in _twelve():
		ws.append(String(it["id"]))
	lv.set("words", ws)
	lv.set("dropped", ["windmill"] as Array[String])
	var hud: CanvasLayer = (load("res://story/hud.gd") as GDScript).new()
	add_node(hud)
	var dlg := DialogueBox.new()
	add_node(dlg)
	var clinic := StubClinic.new()
	add_node(clinic)
	lv.set("hud", hud)
	lv.set("dialogue", dlg)
	lv.set("clinic", clinic)
	add_node(lv)
	var done := [false]
	var run := func() -> void:
		await lv.call("_speech")
		done[0] = true
	run.call()
	var lines: Array[String] = []
	var spoiled := [SpeechRules.NO_SRT]   # the bracketed SRT the player's right store stepped off
	var handled := 0
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 90000:
		await wait_frames(1)
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		var info: Dictionary = b["info"]
		if b["beat"] == &"dialogue":
			lines.append("%s: %s" % [info.get("speaker", ""), info.get("text", "")])
		elif b["beat"] == &"speech" and String(info.get("ear", "")) == "right" and String(info.get("action", "")) == "store" \
				and spoiled[0] == SpeechRules.NO_SRT:
			# the player steps off the bracket, then stores: an SRT that can't carry the board
			spoiled[0] = int(info["target_db"])
			await tap_action(&"louder")
			await tap_action(&"store")
			continue
		await wait_seconds(0.05)
		(b["solver"] as Callable).call()
	assert_true(done[0], "the speech step finished")
	assert_ne(spoiled[0], SpeechRules.NO_SRT, "the right ear reached its store")
	var mine: Dictionary = lv.call("srt_sheet", "right")
	assert_eq(int(mine.get("stored_db", -1)), spoiled[0] + 5, "the player's right SRT, 5 dB off its bracket")
	assert_false(LevelMike._srt_shows_mismatch(mine), "it can't carry the board")
	var re: Dictionary = lv.get("recheck")
	assert_false(re.is_empty(), "Hoot's recheck ran")
	assert_true(bool(re.get("by_hoot", false)), "his run is not scored")
	assert_true(LevelMike._srt_shows_mismatch(re), "by the book, Mike's SRT shows the mismatch")
	assert_eq(lv.call("board_sheet"), re, "the board uses the recheck")
	var cards: Array = lv.call("objection_cards")
	assert_true(String((cards[1] as Array)[1]["title"]).begins_with("Hoot's recheck: SRT "), "the clue names his recheck")
	var on_record: Dictionary = ((((lv.get("results") as Dictionary).get("speech", {}) as Dictionary).get("recheck", {}) as Dictionary) \
		.get("srt", {}) as Dictionary).get("right", {})
	assert_eq(int(on_record.get("stored_db", -1)), int(re.get("stored_db", -2)), "his recheck is on the visit's record (the paper's note)")
	assert_eq(Game.visit.get("audiometry", {}), lv.get("results"), "and in the visit's results")
	assert_has(lines, "Hoot: The bracket said %d dB, not that one. I'll recheck the right ear by the book." % spoiled[0])
	var left: Dictionary = lv.call("srt_sheet", "left")
	assert_false(left.is_empty(), "the left ear went on after the recheck")
	assert_true(bool(left.get("by_hoot", false)), "Hoot finished the left bracket after the step up")
	var verdict := false
	for l: String in lines:
		verdict = verdict or (l.begins_with("Hoot: SRT should sit within") and l.ends_with("better. Poor agreement!"))
	assert_true(verdict, "the agreement verdict from the recheck: %s" % str(lines))
	assert_has(clinic.calls, "take_off_earphones")
	assert_eq(lv.get("screen"), null, "the SPEECH screen is gone")
	Game.settings["quick_visit"] = quick


## The familiarisation step on the level (board, dialogue and HUD, no clinic): Hoot says the words,
## Mike says them back and the player drops the windmill; then Mike's SRT instructions.
func test_familiarize_flow() -> void:
	Engine.time_scale = 6.0
	var lv: Node = LevelMike.new()
	var hud: CanvasLayer = (load("res://story/hud.gd") as GDScript).new()
	add_node(hud)
	var dlg := DialogueBox.new()
	add_node(dlg)
	lv.set("hud", hud)
	lv.set("dialogue", dlg)
	var out: Array = [null]
	var run := func() -> void:
		out[0] = await lv.call("_familiarize")
	run.call()
	var lines: Array[String] = []
	var handled := 0
	var t0 := Time.get_ticks_msec()
	while out[0] == null and Time.get_ticks_msec() - t0 < 40000:
		await wait_frames(2)
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		var info: Dictionary = b["info"]
		if b["beat"] == &"dialogue":
			lines.append("%s: %s" % [info.get("speaker", ""), info.get("text", "")])
		elif b["beat"] == &"familiarize_cards":
			lines.append("(drop)")
		await wait_seconds(0.1)
		(b["solver"] as Callable).call()
	assert_true(out[0] != null, "the step finished")
	var by_ear := lines.find("Hoot: I'll say each word, nice and loud. You say it back. No peeking: the cards face me!")
	var echo := -1
	for i in lines.size():
		if lines[i].begins_with("Mike: Lighthouse! Rainbow!"):
			echo = i
	var windmill := lines.find("Mike: Wind... mill? Never seen one. Is it a fan for a field?")
	var drop := lines.find("(drop)")
	var told := lines.find("Hoot: Every test word comes from this list, Mike. Say back what you hear, and guess if unsure.")
	assert_true(by_ear >= 0 and echo > by_ear, "Hoot says the words, Mike says them back: %s" % str(lines))
	assert_true(windmill > echo and drop > windmill, "the windmill gag, then the player's drop")
	assert_true(told > drop, "his SRT instructions: the words come from this list")
	assert_eq(lv.get("dropped"), ["windmill"] as Array[String])
	assert_eq(String((Game.visit.get("medals", {}) as Dictionary).get("familiarize", "")), "gold", "yes + a clean drop")
	var board: Control = out[0]
	for it: Dictionary in _twelve().slice(0, 11):
		assert_true(bool(board.call("is_echoed", String(it["id"]))), "said back: " + String(it["id"]))
	assert_true(LevelMike.echo_line(_twelve()).begins_with("Lighthouse! Rainbow! Sunbeam! Bookshelf! Easy! Moonlight!"))
	lv.free()


## A 1 kHz retest after the right-ear montage that comes back 15 dB better: derived from the measured
## result, past the 5 dB test-retest tolerance, on the record, and the PTA keeps the first stamp.
func test_retest_1k_comes_back_better() -> void:
	var tones := SpeechSession.tone_results_from(_mike())
	var rt := LevelMike.retest_1k(tones)
	assert_eq(int(rt.get("first_db", -1)), 70, "Mike's first right 1 kHz")
	var diff := int(rt["first_db"]) - int(rt["stored_db"])
	assert_eq(diff, LevelMike.RETEST_BETTER_DB)
	assert_true(diff >= 10 and diff <= 15, "10-15 dB better")
	assert_true(diff > ClinicRules.RETEST_TOLERANCE_DB, "past the 5 dB test-retest tolerance")
	assert_eq(int(rt["diff"]), diff)
	assert_true(bool(rt["by_hoot"]), "Hoot's retest, not the player's")
	var other := tones.duplicate(true)
	other["ears"]["right"]["freqs"][1000]["stored_db"] = 60
	assert_eq(int(LevelMike.retest_1k(other)["stored_db"]), 60 - LevelMike.RETEST_BETTER_DB, "from the measured result")
	assert_true(LevelMike.retest_1k({}).is_empty(), "no tones: no retest")
	var line := LevelMike.retest_remark(rt)
	assert_true(line.split(" ", false).size() <= Hoot.MAX_WORDS, "%d words: %s" % [line.split(" ", false).size(), line])
	assert_true(line.contains("55 dB") and line.contains("15 better"), line)
	for word: String in ["fake", "faking", "liar", "lying", "fib", "pretend"]:
		assert_false(line.to_lower().contains(word), "never accusing: " + line)
	var lv := _level_with_tones()
	var pta := float(lv.call("ear_pta", "right"))
	lv.set("tone_retest", rt)
	lv.call("_record_retest")
	var right: Dictionary = ((lv.get("tones") as Dictionary)["ears"] as Dictionary)["right"]
	assert_eq(int((right.get("retest_1k", {}) as Dictionary).get("stored_db", -1)), 55, "on the record")
	assert_near(float(lv.call("ear_pta", "right")), pta, 0.001, "the PTA keeps the first 1 kHz stamp")
	assert_true(String((lv.call("speech_plan", "right") as Dictionary)["intro"]).contains("85"), "the SRT start is unchanged")
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	var note := String(paper.call("_retest_line", lv.get("tones")))
	paper.free()
	assert_true(note.contains("Right 70 then 55") and note.contains("More than 5 dB apart"), "the paper's beep card: " + note)
	lv.free()


## (E2) Hoot's montage waives the AudiOtron's own 1 kHz retest on both ears, so its test plan never
## shows "1k R" and neither sheet gets a retest; the visit's one retest is Hoot's retest_1k in the
## level, on the first air ear (the right). The second air ear owes none.
func test_montage_retest_on_the_first_air_ear_only() -> void:
	var src := FileAccess.get_file_as_string((LevelMike as Script).resource_path)
	assert_eq(src.count("\"montage\": true, \"skip_hoot_retest\": true"), 2, "both ears: Hoot's montage, no AudiOtron retest")
	Engine.time_scale = 8.0
	var screen: CanvasLayer = (load("res://ui/audiometer/audiometer_screen.tscn") as PackedScene).instantiate()
	add_node(screen)
	screen.set("quick_visit", true)
	var shown: Dictionary = {}
	var watch := func() -> void:
		var q: Node = screen.get("_quest")
		for it: Dictionary in q.get("items"):
			if String(it.get("label", "")) == "1k R":
				shown[String(q.get("ear"))] = true
	tree.process_frame.connect(watch)
	var r: Dictionary = {}
	for ear: String in ["right", "left"]:
		screen.call("start_test", _mike(), ear, false, {"test": "ac", "hoot_turn_after": 0, "montage": true, "skip_hoot_retest": true})
		r = await screen.test_finished
	tree.process_frame.disconnect(watch)
	var s: AudiometrySession = screen.get("session")
	assert_eq(s.air_ear_order, ["right", "left"] as Array[String], "right is the first air ear")
	assert_true(shown.is_empty(), "the test plan never shows 1k R (%s)" % [shown])
	for ear: String in ["right", "left"]:
		assert_true((s.retest[ear] as Dictionary).is_empty(), "the AudiOtron retests no %s 1 kHz" % ear)
	assert_false(s.retest_required("left"), "the second air ear owes no retest")
	var lv: Node = LevelMike.new()
	lv.set("tones", r)
	lv.set("tone_retest", LevelMike.retest_1k(r))
	lv.call("_record_retest")
	var ears: Dictionary = (lv.get("tones") as Dictionary)["ears"]
	assert_false(((ears["right"] as Dictionary).get("retest_1k", {}) as Dictionary).is_empty(), "Hoot's retest on the right")
	assert_true(((ears["left"] as Dictionary).get("retest_1k", {}) as Dictionary).is_empty(), "and none on the left")
	lv.free()
	Engine.time_scale = 1.0


func test_hoot_lines_fit() -> void:
	var src := FileAccess.get_file_as_string((LevelMike as Script).resource_path)
	var re := RegEx.create_from_string("_say\\(\"Hoot\", \"((?:[^\"\\\\]|\\\\.)*)\"")
	var n := 0
	for m: RegExMatch in re.search_all(src):
		n += 1
		var line := m.get_string(1)
		assert_true(line.split(" ", false).size() <= Hoot.MAX_WORDS, "%d words: %s" % [line.split(" ", false).size(), line])
	assert_true(n >= 30, "found Hoot's dialogue lines (%d)" % n)
	var lv := _level_with_tones()
	for line: String in [String(lv.call("pta_line")), LevelMike.claim_note("poor", -40), LevelMike.claim_note("poor", 18)]:
		assert_true(line.split(" ", false).size() <= Hoot.MAX_WORDS, line)
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


func test_daily_decibel_c_grade_names_the_slip() -> void:
	var aud := _merged()
	var sp: Dictionary = aud["speech"]
	var right: Dictionary = (sp["srt"] as Dictionary)["right"]
	right["by_hoot"] = false
	right["candidate_db"] = SpeechRules.NO_SRT   # stored before a bracket
	right.erase("bracketed")
	sp["technique_errors"] = [{"kind": "srt_wrong_step"}, {"kind": "srt_store_no_bracket"}, {"kind": "srt_store_no_bracket"}]
	var heads: Dictionary = (load("res://story/daily_decibel.gd") as GDScript).get_script_constant_map()
	var subs: Dictionary = heads["SPEECH_C_SUBHEADS"]
	var summary := _summary(aud)
	summary["grade"] = "C"
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var run := func() -> void:
		await paper.call("show_summary", summary)
	run.call()
	await wait_seconds(1.0)
	assert_true(_find_label(paper, String(subs["srt_store_no_bracket"])) != null, "the C subhead names the most frequent slip")
	assert_true(_find_label(paper, "no bracket") != null, "no golf name for an SRT stored off its bracket")
	var b := _last(&"results_continue")
	(b["solver"] as Callable).call()
	await wait_frames(2)
	sp["technique_errors"] = []
	assert_eq(String(paper.call("speech_c_subhead", aud)), String(heads["SPEECH_C_CLEAN"]), "no slips: the long-road line")


## The paper after a misscored right ear that Hoot rechecked: no golf name for the slip, the C
## subhead says which way the scores went, Hoot's recheck has its note, and the legend says which
## way a poor gap points.
func test_daily_decibel_after_a_misscored_ear() -> void:
	var aud := _merged()
	var sp: Dictionary = aud["speech"]
	var hoots: Dictionary = ((sp["srt"] as Dictionary)["right"] as Dictionary).duplicate(true)
	var right: Dictionary = (sp["srt"] as Dictionary)["right"]
	right["by_hoot"] = false
	right["errors"] = [&"misscored"]
	right["golf"] = "par"
	assert_true(SpeechScreen.is_bracketed(right), "stored at its bracket: only the misscore is wrong")
	sp["technique_errors"] = [{"kind": "misscored", "scored": true, "said_kind": "half"}, {"kind": "misscored", "scored": true, "said_kind": "wrong"}]
	sp["recheck"] = {"srt": {"right": hoots}}
	var summary := _summary(aud)
	summary["grade"] = "C"
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var run := func() -> void:
		await paper.call("show_summary", summary)
	run.call()
	await wait_seconds(1.0)
	var k: Dictionary = (load("res://story/daily_decibel.gd") as GDScript).get_script_constant_map()
	assert_true(_find_label(paper, "1 slip") != null, "the golf cell names the slip")
	assert_true(_find_label(paper, "par") == null, "no par for a misscored ear")
	var generous := String((k["SPEECH_C_MISSCORED"] as Dictionary)["generous"])
	assert_true(_find_label(paper, generous) != null, "the C subhead says which way: misses scored as repeated")
	var note := String(paper.call("recheck_note", sp))
	assert_true(note.begins_with("Hoot's recheck: SRT %d dB" % int(hoots["stored_db"])), note)
	assert_true(_find_label(paper, note) != null, "Hoot's recheck on the paper")
	var legend := String(paper.call("agreement_legend"))
	assert_true(legend.contains("better than beeps point to a non-organic loss") and legend.contains("instructions, language or word recognition"), legend)
	assert_false(legend.to_lower().contains("slop"), "(A8) a sloping loss is no reason for words worse than beeps: " + legend)
	assert_true(_find_label(paper, legend) != null, "the legend says which way a poor gap points")
	var b := _last(&"results_continue")
	(b["solver"] as Callable).call()
	await wait_frames(2)
	sp["technique_errors"] = [{"kind": "misscored", "scored": false}, {"kind": "misscored", "scored": false}, {"kind": "misscored", "scored": true}]
	assert_eq(String(paper.call("speech_c_subhead", aud)), String((k["SPEECH_C_MISSCORED"] as Dictionary)["strict"]), "whole words scored as misses")
	sp["technique_errors"] = [{"kind": "misscored", "scored": false}, {"kind": "misscored", "scored": true}]
	assert_eq(String(paper.call("speech_c_subhead", aud)), String((k["SPEECH_C_SUBHEADS"] as Dictionary)["misscored"]), "a tie: the plain line")
	sp["technique_errors"] = [{"kind": "misscored"}]
	assert_eq(String(paper.call("speech_c_subhead", aud)), String((k["SPEECH_C_SUBHEADS"] as Dictionary)["misscored"]), "no direction on record")
	assert_eq(String(paper.call("recheck_note", {"srt": {}})), "", "no recheck: no note")


## The tallest Day 3 paper (a C with Hoot's recheck note, the legend and the real visit's three
## buttons) fits a 1280x720 window without scaling down.
func test_daily_decibel_day3_paper_fits_the_window() -> void:
	var aud := _merged()
	var sp: Dictionary = aud["speech"]
	var right: Dictionary = (sp["srt"] as Dictionary)["right"]
	sp["recheck"] = {"srt": {"right": right.duplicate(true)}}
	right["by_hoot"] = false
	right["errors"] = [&"misscored", &"misscored"]
	sp["technique_errors"] = [{"kind": "misscored", "scored": true, "said_kind": "half"}, {"kind": "misscored", "scored": true, "said_kind": "wrong"}]
	var summary := _summary(aud)
	summary["grade"] = "C"
	summary["next_chapter_id"] = "rocco"
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var run := func() -> void:
		await paper.call("show_summary", summary)
	run.call()
	await wait_seconds(1.0)
	var texts: Array[String] = []
	for b: Node in paper.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("Next: Day")), "three buttons: %s" % str(texts))
	assert_true(_find_label(paper, String(paper.call("recheck_note", sp))) != null, "Hoot's recheck note")
	var sz: Vector2 = (paper.get("_paper") as Control).size
	assert_eq(float(paper.call("fit_scale", sz, Vector2(1280, 720))), 1.0, "fits at scale 1: %s" % sz)
	var b := _last(&"results_continue")
	(b["solver"] as Callable).call()
	await wait_frames(2)


## A misscore in the session's technique errors keeps which way it went (the paper's C subhead).
func test_misscore_error_keeps_its_direction() -> void:
	var s := SpeechSession.new(_mike(), 5)
	s.configure({"test": "srt", "tones": SpeechSession.tone_results_from(_mike())})
	s.begin("right")
	var tr := s.present()
	assert_false(tr.is_empty())
	var truth := bool(s.current.get("correct", false))
	s.score(not truth)
	var e: Dictionary = s.errors.back()
	assert_eq(String(e["kind"]), "misscored")
	assert_eq(e.get("scored", null), not truth, "the player's score")
	assert_true(e.has("said_kind"), "what was said")


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
