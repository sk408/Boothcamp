extends RefCounted
## (Days 4-5) Day 3 golden snapshots for test_speech_seams.gd (not a test file itself). Each builder
## plays a fixed, seeded piece of Day 3 and writes down everything the S0b seams could disturb, as
## text (var_to_str). The goldens under core/tests/golden/ were written by the code BEFORE the seams
## (CONTRACTS.md §9.24: "a Day 3 scripted session gives the same trials, sheets and results as before
## S0"), so a seam that leaks into the SRT path shows up as a diff.
##   session_snapshot(): a scripted SpeechSession on Mike, slips included, both ears and a Hoot run
##   screen_snapshot(tc): the SPEECH screen's layout, anchors, every beat and the coach on two ears
##   paper_snapshot(tc, speech): every label of a Day 3 Daily Decibel (or a tones-only one)
## Rewrite them on purpose only: BC_WRITE_GOLDEN=1 godot ... -s res://tests/run_tests.gd -- --filter=golden

const DIR := "res://core/tests/golden/"
const SCREEN := "res://ui/speech/speech_screen.tscn"
const PAPER := "res://story/daily_decibel.tscn"
## The state keys a snapshot records (the Day 3 ones: later steps may only add keys, never change these).
const SESSION_STATE_KEYS: Array[String] = ["test", "ear", "db", "min_db", "max_db", "list_id", "list_title", "next_word",
	"words_left", "pta", "pta_right", "pta_left", "recommended_start", "candidate_db", "trail", "strokes", "awaiting_score",
	"current", "mask_on", "mask_db", "mask_ear", "masking_needed", "transducer", "done", "stored_db", "agreement", "diff",
	"combo", "multiplier", "points", "presentations", "scoring"]
const SCREEN_STATE_KEYS: Array[String] = ["accepting_input", "talking", "listening", "answer_shown", "hoot_turn", "coached",
	"patient_id", "quick_visit", "finishing", "hoot_turn_after"]


## The golden text for `name` ("" when it was never written).
static func golden(name: String) -> String:
	var path := DIR + name + ".txt"
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


static func write_golden(name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var f := FileAccess.open(DIR + name + ".txt", FileAccess.WRITE)
	f.store_string(text)
	f.close()


static func writing() -> bool:
	return OS.get_environment("BC_WRITE_GOLDEN") == "1"


## Only the Day 3 keys of a state dictionary, in a fixed order.
static func pick(st: Dictionary, keys: Array[String]) -> Dictionary:
	var out := {}
	for k: String in keys:
		out[k] = st.get(k, "<missing>")
	return out


# ---------------------------------------------------------------- the session

## A seeded SpeechSession on Mike: the right ear coached with slips (two misscores, a PRESENT before
## scoring, a wrong step up, a mask on and off), the left ear from a low start (clean with
## low_start_ok), an ear stored before its bracket, and a second session run by Hoot (scoring off).
## Everything the session emits or returns is recorded.
static func session_snapshot() -> String:
	var mike := Game.load_patient("mike") as PatientProfile
	var tones := SpeechSession.tone_results_from(mike)
	var out := {}
	var s := SpeechSession.new(mike, 4242)
	var log: Array = []
	_listen(s, log)
	s.configure({"test": "srt", "tones": tones})
	out["refused_before"] = [s.store(), s.score(true)]
	s.begin("right", true)
	out["state_right_0"] = pick(s.get_state(), SESSION_STATE_KEYS)
	out["play_right"] = _play(s, {"flip": [2, 6], 1: [&"present"], 3: [&"louder", &"louder", &"present"], 4: [&"mask", &"mask"]})
	out["state_right_end"] = pick(s.get_state(), SESSION_STATE_KEYS)
	s.configure({"test": "srt", "tones": tones, "low_start_ok": true, "level": 40})
	s.begin("left", false)
	out["state_left_0"] = pick(s.get_state(), SESSION_STATE_KEYS)
	out["play_left"] = _play(s, {0: [&"present"], "flip": [5]})
	out["state_left_end"] = pick(s.get_state(), SESSION_STATE_KEYS)
	out["queries"] = [s.pta_for("right"), s.pta_for("left"), s.recommended_start("left"), s.candidate("right", &"srt"),
		s.masking_needed_here(80), s.mask_level(), s.masker_ear(), s.is_done("right"), s.is_done("left"), s.slips(),
		s.trials_for("right").size(), s.textbook_target(), s.recommended_action()]
	out["log"] = log
	out["trials"] = s.trials
	out["sheets"] = s.sheets
	out["errors"] = s.errors
	var res := s.build_results()
	out["results"] = res
	out["merged"] = SpeechSession.merge_results(tones, res)
	# an ear stored before its bracket (an error and an "Oops!" sheet), on its own session
	var e := SpeechSession.new(mike, 99)
	var elog: Array = []
	_listen(e, elog)
	e.configure({"test": "srt", "tones": tones})
	e.begin("right", false)
	out["play_early"] = _play(e, {0: [&"present"], 2: [&"store"]})
	out["early_log"] = elog
	out["early_results"] = e.build_results()
	var h := SpeechSession.new(mike, 77)
	var hlog: Array = []
	_listen(h, hlog)
	h.configure({"test": "srt", "tones": tones})
	h.scoring = false
	h.begin("left", false)
	out["play_hoot"] = _play(h, {})
	out["hoot_log"] = hlog
	out["hoot_results"] = h.build_results()
	return var_to_str(out)


static func _listen(s: SpeechSession, log: Array) -> void:
	s.technique.connect(func(kind: StringName, data: Dictionary) -> void: log.append(["technique", kind, data.duplicate(true)]))
	s.combo_changed.connect(func(n: int, m: int) -> void: log.append(["combo", n, m]))
	s.reaction.connect(func(kind: StringName, data: Dictionary) -> void: log.append(["reaction", kind, data.duplicate(true)]))
	s.stored.connect(func(e: String, t: StringName, sheet: Dictionary) -> void: log.append(["stored", e, t, sheet.duplicate(true)]))


## Plays by recommended_action(), with slips: slips.flip lists the scores (counted from 1) given the
## other way; slips[n] (n = scores so far, 0 = before the first) is a list of moves forced in
## before the textbook carries on (&"present", &"louder", &"softer", &"mask", &"store"). Returns
## [step, action, target_db, result] rows.
static func _play(s: SpeechSession, slips: Dictionary) -> Array:
	var rows: Array = []
	var scores := 0
	var forced: Array = []
	var done_at := {}
	var flips: Array = slips.get("flip", [])
	for i in 300:
		if slips.has(scores) and not done_at.has(scores):
			done_at[scores] = true
			forced.append_array(slips[scores])
		var rec := s.recommended_action()
		var act: StringName = rec["action"]
		if not forced.is_empty():
			act = forced.pop_front()
		elif act == &"none":
			break
		elif act in [&"score_correct", &"score_missed"] and flips.has(scores + 1):
			act = &"score_missed" if act == &"score_correct" else &"score_correct"
		var r: Variant = null
		match act:
			&"present":
				r = s.present()
			&"score_correct":
				r = s.score(true)
			&"score_missed":
				r = s.score(false)
			&"louder":
				r = s.step_level(1)
			&"softer":
				r = s.step_level(-1)
			&"mask", &"mask_toggle":
				r = s.toggle_mask()
			&"store":
				r = s.store()
		if act in [&"score_correct", &"score_missed"] and not (r as Dictionary).is_empty():
			scores += 1
		rows.append([i, act, rec.get("target_db", -1), r])
		if s.is_done():
			break
	return rows


# ---------------------------------------------------------------- the SPEECH screen

## The screen on Mike: its layout and anchors, then the coached right ear played by the beat
## solvers (each beat's info, the state, the LCD view, the buttons, the card and the coach's line),
## then the left ear uncoached with Hoot taking over after 3 words. tc: the running test.
static func screen_snapshot(tc: TestCase) -> String:
	var mike := Game.load_patient("mike") as PatientProfile
	var plan := {"test": "srt", "tones": SpeechSession.tone_results_from(mike)}
	var s := (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	tc.add_node(s)
	s.quick_visit = true
	var out := {}
	var beats: Array = []
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"speech":
			beats.append([info.duplicate(true), solver])
	Events.awaiting_input.connect(cb)
	s.start_test(mike, "right", true, plan)
	await tc.wait_frames(3)
	out["layout"] = _layout(s)
	out["anchors"] = _anchors(s)
	out["right"] = await _play_by_beats(tc, s, beats)
	out["right_results"] = s.get_results()
	var plan2 := plan.duplicate(true)
	plan2["hoot_turn_after"] = 3
	beats.clear()
	s.start_test(mike, "left", false, plan2)
	await tc.wait_frames(2)
	out["layout_left"] = _layout(s)
	out["left"] = await _play_by_beats(tc, s, beats)
	out["left_results"] = s.get_results()
	Events.awaiting_input.disconnect(cb)
	return var_to_str(out)


static func _play_by_beats(tc: TestCase, s: SpeechScreen, beats: Array) -> Array:
	var rows: Array = []
	var finished: Array = []
	var fin := func(r: Dictionary) -> void: finished.append(r)
	s.test_finished.connect(fin)
	var used := 0
	var t0 := Time.get_ticks_msec()
	while finished.is_empty() and Time.get_ticks_msec() - t0 < 60000:
		if beats.size() > used:
			used = beats.size()
			var info: Dictionary = beats[used - 1][0]
			rows.append(_beat_row(s, info))
			(beats[used - 1][1] as Callable).call()
		await tc.wait_frames(1)
	s.test_finished.disconnect(fin)
	rows.append(["finished", not finished.is_empty(), s.get_state().get("hoot_turn", false), Engine.time_scale])
	return rows


static func _beat_row(s: SpeechScreen, info: Dictionary) -> Dictionary:
	var st := s.get_state()
	var row := {"info": info, "session": pick(st, SESSION_STATE_KEYS), "screen": pick(st, SCREEN_STATE_KEYS)}
	row["lcd"] = (s._lcd.view as Dictionary).duplicate(true)
	row["coach"] = s._coach_text(s.session.recommended_action())
	row["dance"] = s._dance.lit()
	row["card"] = [s._card.state, s._card.list_title, s._card.ear, s._card.number, s._card.words_left, s._card.done_text]
	var buttons := {}
	var ids: Array = s._buttons.keys()
	ids.sort()
	for id: String in ids:
		var b: AoButton = s._buttons[id]
		buttons[id] = [b.text, b.locked, b.beckon, b.visible, b.show_keycap]
	row["buttons"] = buttons
	return row


static func _layout(s: SpeechScreen) -> Dictionary:
	var out := {}
	var ids: Array = s._buttons.keys()
	ids.sort()
	for id: String in ids:
		var b := s._buttons[id] as SpButton
		out[id] = [b.position, b.size, b.visible, b.text, b.sub_text, int(b.icon), int(b.glyph), b.action, b.font_size, b.face_color]
	out["groups"] = s._group_labels.duplicate(true)
	for n: String in ["_booth", "_lcd", "_status", "_bubble", "_card", "_ladder", "_meter", "_hoot_spot", "_dance", "_deck", "_ff_banner"]:
		var c := s.get(n) as Control
		out[n] = [c.position, c.size, c.visible]
	return out


static func _anchors(s: SpeechScreen) -> Array:
	var out: Array = []
	var ids: Array = (Hoot.get("_anchors") as Dictionary).keys()
	ids.sort()
	for id: String in ids:
		if Hoot.has_anchor(id):
			out.append([id, Hoot.anchor_screen_rect(id)])
	return out


# ---------------------------------------------------------------- the Daily Decibel

## Every label of the paper, top to bottom, for a Day 3 summary over `aud` (or a Day 1 one when
## chapter is "gus"). Buttons are left out: their text follows the save (owned, key hints).
static func paper_snapshot(tc: TestCase, aud: Dictionary, chapter: String = "mike") -> String:
	var paper: Node = (load(PAPER) as PackedScene).instantiate()
	tc.add_node(paper)
	var summary := {"patient_id": chapter, "score": 84.0, "grade": "C", "accuracy": 0.9, "technique": 0.9, "efficiency": 0.8,
		"care": 1.0, "comfort": 3, "medals": {"history": "gold", "instructions": "gold", "familiarize": "silver", "evidence": "gold"},
		"coins_earned": 60, "coins_total": 60, "audiometry": aud, "chapter_id": chapter, "day": 3 if chapter == "mike" else 1,
		"patient_name": "Mike Lenders" if chapter == "mike" else "Gus Grumble", "patient_short": "Mike" if chapter == "mike" else "Gus"}
	paper.call("_build", summary)
	var texts: Array = []
	_labels(paper, texts)
	paper.queue_free()
	return var_to_str(texts)


static func _labels(n: Node, out: Array) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c: Node in n.get_children():
		_labels(c, out)
