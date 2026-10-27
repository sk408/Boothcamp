extends TestCase
## Freestyle (docs/FREESTYLE.md): every walk-in case file is playable and keeps the house rules, and
## each patient's truth really supports the call the case teaches (type of loss per ear, which tests a
## full workup needs, masking, asymmetry, urgency), robustly enough that a few dB of wandering stamps
## do not flip the lesson.

const FsData := preload("res://story/freestyle/fs_data.gd")
const FsRules := preload("res://story/freestyle/fs_rules.gd")
const CaseData := preload("res://story/case_data.gd")
const FsTray := preload("res://story/freestyle/fs_tray.gd")
const FsClipboard := preload("res://story/freestyle/fs_clipboard.gd")
const LevelFreestyle := preload("res://story/freestyle/level_freestyle.gd")
const Movies := preload("res://story/explainers/movies.gd")
const PAUSE_MENU := "res://story/pause_menu.tscn"
const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"

## case id -> [the call, right ear type, left ear type, asymmetric?, needs bone?, needs tymp?]
const EXPECTED: Dictionary = {
	"fs_penny": [&"clear", &"normal", &"normal", false, false, false],
	"fs_mabel": [&"fit", &"sensorineural", &"sensorineural", false, true, false],
	"fs_sid": [&"fit", &"sensorineural", &"sensorineural", false, true, false],
	"fs_viola": [&"fit", &"sensorineural", &"sensorineural", false, true, false],
	"fs_buck": [&"refer", &"sensorineural", &"sensorineural", true, true, false],
	"fs_melody": [&"today", &"sensorineural", &"normal", true, true, true],
	"fs_skyler": [&"refer", &"normal", &"conductive", true, true, true],
	"fs_hector": [&"refer", &"sensorineural", &"mixed", true, true, true],
}
const BOT_PREFIX := 18


func _case(id: String) -> Dictionary:
	return FsData.load_case(id)


func _patient(id: String) -> PatientProfile:
	return FsData.patient_for(_case(id))


func test_every_case_file_is_listed_and_validates() -> void:
	var dir := DirAccess.open(FsData.CASES_DIR)
	assert_true(dir != null, "the cases folder exists")
	var files := PackedStringArray()
	for f: String in dir.get_files():
		if f.ends_with(".json"):
			files.append(f.get_basename())
	for f: String in files:
		assert_has(FsData.CASE_IDS, f, "case file %s is listed in FsData.CASE_IDS" % f)
	for id: String in FsData.CASE_IDS:
		if not files.has(id):
			continue   # cases still being written are checked once their file lands
		var c := _case(id)
		assert_eq(String(c.get("id", "")), id, "id matches the file name")
		assert_eq(Array(FsData.validate(c)), [], "case %s validates" % id)


func test_expected_cases_exist() -> void:
	for id: String in EXPECTED:
		assert_false(_case(id).is_empty(), "case file " + id)
		assert_true(_patient(id) != null, "patient for " + id)
	for id: String in FsData.CASE_IDS:
		assert_true(EXPECTED.has(id), "%s has an EXPECTED row (its call and truth are pinned)" % id)


## Steve (2026-10-19): every workup asks where the patient has trouble, and the answer names places in
## their daily life. A FIT turns those places into goals. The keys always leave the player a free pick.
func test_every_walk_in_asks_where_they_have_trouble() -> void:
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		var keys: Array = c["key_questions"]
		assert_has(keys, FsRules.TROUBLE_QUESTION, id + ": the trouble question is a key question")
		assert_true(keys.size() < FsRules.CHAT_BUDGET, id + ": the keys leave a free pick")
		assert_true(FsData.answer_note(c, FsRules.TROUBLE_QUESTION).begins_with("Trouble: "), id + ": the note lists the trouble spots")
		assert_true(FsData.answer_lines(c, FsRules.TROUBLE_QUESTION).size() >= 2, id + ": more than one place")
		if String(c["decision"]) != "fit":
			continue
		var goals := false
		for l: Array in FsData.hoot_lines(c):
			goals = goals or (String(l[0]) == "debrief" and String(l[1]).contains("goals"))
		assert_true(goals, id + ": the debrief turns the trouble spots into goals")


## Every DOCTOR TODAY walk-in meets the game's sudden-loss definition (CaseRules, like Dash).
func test_doctor_today_means_a_sudden_loss() -> void:
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		if c.is_empty() or String(c["decision"]) != "today":
			continue
		var p := _patient(id)
		var r := FsRules.truth_air(p, "right")
		var l := FsRules.truth_air(p, "left")
		var best := 0
		for pair: Array in [[r, l], [l, r]]:
			var run := 0
			for f: int in ClinicRules.AC_FREQS:
				run = run + 1 if int(pair[0][f]) - int(pair[1][f]) >= CaseRules.SUDDEN_MIN_DB else 0
				best = maxi(best, run)
		assert_true(best >= CaseRules.SUDDEN_MIN_FREQS, "%s: 30 dB or more at 3+ neighbouring frequencies" % id)


func test_the_call_and_the_truth_agree() -> void:
	for id: String in EXPECTED:
		var e: Array = EXPECTED[id]
		var c := _case(id)
		var p := _patient(id)
		assert_eq(StringName(String(c["decision"])), e[0], id + ": the call")
		assert_eq(FsRules.truth_type(p, "right"), e[1], id + ": right ear type")
		assert_eq(FsRules.truth_type(p, "left"), e[2], id + ": left ear type")
		assert_eq(CaseRules.is_asymmetric(FsRules.truth_air(p, "right"), FsRules.truth_air(p, "left")), e[3], id + ": asymmetry")
		assert_eq(FsRules.truth_needs_bone(p), e[4], id + ": bone needed")
		assert_eq(FsRules.needs_tymp(c, p), e[5], id + ": tymp needed")


## "No aids needed" only for normal hearing in both ears; every other call has a real loss somewhere.
func test_clear_means_normal_hearing() -> void:
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		if c.is_empty():
			continue
		var p := _patient(id)
		var normal := FsRules.truth_type(p, "right") == &"normal" and FsRules.truth_type(p, "left") == &"normal"
		assert_eq(String(c["decision"]) == "clear", normal, id + ": 'no aids needed' exactly when both ears are normal")


## The type of each ear holds with every true threshold 5 dB better or poorer (a few wandering stamps).
func test_types_survive_five_db_of_wobble() -> void:
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		if c.is_empty():
			continue
		var p := _patient(id)
		for ear: String in ClinicRules.EARS:
			var want := FsRules.truth_type(p, ear)
			var air := FsRules.truth_air(p, ear)
			var bone := FsRules.truth_bone(p, ear)
			for shift: int in [-5, 5]:
				var a2 := {}
				for f: int in air:
					a2[f] = int(air[f]) + shift
				assert_eq(ClinicRules.hearing_type(a2, bone), want, "%s %s ear: air %+d dB keeps the type" % [id, ear, shift])
				var b2 := {}
				for f: int in bone:
					b2[f] = mini(int(bone[f]) + shift, int(air.get(f, 120)))
				assert_eq(ClinicRules.hearing_type(air, b2), want, "%s %s ear: bone %+d dB keeps the type" % [id, ear, shift])


func test_tymp_tip_matches_the_canal() -> void:
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		if c.is_empty():
			continue
		assert_has(CaseRules.TIP_SIZES, FsData.tip_for(c), id + ": a real tip size")


func test_speakers_are_unique() -> void:
	var seen := {}
	for cid: String in CaseData.chapter_case_ids():
		seen[String(CaseData.load_case(cid).get("speaker", ""))] = cid
	for who: String in ["Gus", "Doris", "Bonnie", "Mike", "Hoot"]:
		seen[who] = "story"
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		if c.is_empty():
			continue
		var who := String(c["speaker"])
		assert_false(seen.has(who), "%s: speaker %s is already %s" % [id, who, seen.get(who, "")])
		seen[who] = id


## The bot clicks buttons by their first 18 characters: deck questions, tool cards, the call's stamps,
## the type choices and every case's notes and why-options must not collide.
func test_bot_prefixes_are_unique() -> void:
	var fixed := {}
	for q: Dictionary in FsRules.QUESTIONS:
		_add_prefix(fixed, String(q["text"]), "question")
	_add_prefix(fixed, FsRules.DONE_ASKING, "done")
	for t: StringName in FsRules.TOOL_LABELS:
		_add_prefix(fixed, FsRules.TOOL_LABELS[t], "tool")
	for d: StringName in FsRules.DECISION_STAMPS:
		_add_prefix(fixed, FsRules.DECISION_STAMPS[d], "stamp")
	for k: StringName in FsRules.TYPE_LABELS:
		_add_prefix(fixed, FsRules.TYPE_LABELS[k], "type")
	for id: String in FsData.CASE_IDS:
		var c := _case(id)
		if c.is_empty():
			continue
		var mine := fixed.duplicate()
		for o: Variant in (c["why"] as Dictionary)["options"]:
			_add_prefix(mine, String((o as Array)[0]), id + " why")
		# notes sit on the clipboard while tools are on screen: no note may start like a button
		for q: Dictionary in FsRules.QUESTIONS:
			var note := FsData.answer_note(c, String(q["id"]))
			for label: String in fixed:
				if note != "" and (note.begins_with(label) or label.begins_with(note.substr(0, BOT_PREFIX))):
					fail("%s: note '%s' starts like the button '%s'" % [id, note, label])


func _add_prefix(seen: Dictionary, text: String, where: String) -> void:
	var p := text.substr(0, BOT_PREFIX)
	if seen.has(p):
		fail("'%s' (%s) starts like '%s'" % [text, where, seen[p]])
	seen[p] = where


## The runner's other rows of tray buttons: unique within the row, and no clipboard note starts like one.
func test_runner_button_rows_are_unique() -> void:
	var rows: Array = [LevelFreestyle.TIP_OPTIONS, LevelFreestyle.EAR_OPTIONS, LevelFreestyle.MASTOID_OPTIONS,
		LevelFreestyle.MASK_OPTIONS, LevelFreestyle.TYMP_LABELS.values()]
	for row: Array in rows:
		var seen := {}
		for label: Variant in row:
			_add_prefix(seen, String(label), "runner row")
		for id: String in FsData.CASE_IDS:
			var c := _case(id)
			if c.is_empty():
				continue
			for q: Dictionary in FsRules.QUESTIONS:
				var note := FsData.answer_note(c, String(q["id"]))
				for label: Variant in row:
					if note != "" and note.begins_with(String(label).substr(0, BOT_PREFIX)):
						fail("%s: note '%s' starts like the button '%s'" % [id, note, label])


## Every row the tray shows (all eight tools, the longest choice rows) fits on a 1280-wide screen.
func test_tray_rows_fit_the_screen() -> void:
	var tray := FsTray.new()
	add_node(tray)
	var tools: Array[StringName] = []
	tools.assign(FsRules.TOOLS)
	var rows: Array = [LevelFreestyle.MASK_OPTIONS, LevelFreestyle.TYMP_LABELS.values(), FsRules.DECISION_STAMPS.values(),
		FsRules.TYPE_LABELS.values()]
	for k in rows.size() + 1:
		var got := [false]
		var run := func() -> void:
			if k == 0:
				await tray.pick(tools, {}, &"chat", "What next for Penny?")
			else:
				var labels: Array[String] = []
				for l: Variant in rows[k - 1]:
					labels.append(String(l))
				await tray.choose("Which one?", labels, 0)
			got[0] = true
		run.call()
		await wait_seconds(0.2)
		var vw := tray.get_viewport_rect().size.x
		for c: Node in tray.get_children():
			if c is Button:
				var b := c as Button
				assert_true(b.position.x >= 0.0 and b.position.x + b.size.x <= vw,
					"row %d: '%s' sits on screen (%d to %d of %d)" % [k, b.text, int(b.position.x), int(b.position.x + b.size.x), int(vw)])
		(tray as Object).call("_choose", 0)
		await wait_seconds(0.2)
		assert_true(got[0], "row %d answered" % k)


## Each waiting-room card's teaser wraps inside the card (no line runs under the next card).
func test_waiting_room_teasers_wrap_inside_their_cards() -> void:
	var room: Control = (load("res://story/freestyle/waiting_room.tscn") as PackedScene).instantiate()
	add_node(room)
	await wait_seconds(0.4)
	var cards := 0
	for b: Variant in room.get("_cards"):
		var card := b as Button
		cards += 1
		for c: Node in card.get_children():
			var l := c as Label
			if l == null or not l.text.begins_with("\""):
				continue
			assert_true(l.position.x >= 0.0 and l.position.x + l.size.x <= card.size.x,
				"%s: the teaser fits the card's width (%d + %d of %d)" % [card.get_meta("label", "?"), int(l.position.x), int(l.size.x), int(card.size.x)])
			assert_true(l.get_combined_minimum_size().y <= l.size.y + 1.0, "%s: the teaser fits the card's height" % card.get_meta("label", "?"))
	assert_eq(cards, FsData.CASE_IDS.size(), "one card per walk-in")


## A long visit's clipboard (nine two-line notes and the chart) stays above the tray's prompt.
func test_clipboard_stays_above_the_tray() -> void:
	var cb := FsClipboard.new()
	add_node(cb)
	cb.setup("HECTOR TICKTOCK, 63")
	for i in 11:
		cb.add_note("Note %d: slowly worse over about ten years, nothing sudden" % i, "flag" if i == 2 else "note")
	var tests: Array[String] = ["Right air: PTA 15 dB (normal)", "Left air: PTA 63 dB (moderately severe)",
		"Bone: right and left mastoids", "Masked: left bone, left air"]
	cb.set_tests(tests)
	await wait_seconds(0.3)
	var panel := cb.get("_panel") as Control
	assert_true(panel.size.y <= FsClipboard.MAX_H + 6.0, "the board is %d px tall (max %d)" % [int(panel.size.y), int(FsClipboard.MAX_H)])
	var text := ""
	for l: Node in panel.find_children("*", "Label", true, false):
		text += (l as Label).text + "\n"
	assert_true(text.contains("Note 2:"), "red flags are never dropped")


# ---------------------------------------------------------------- the visit's own rules

## A visit with only its state set (never added to the tree, so no clinic): for the pure checks.
func _visit(id: String) -> Node:
	var lv: Node = LevelFreestyle.new()
	lv.set("case_id", id)
	lv.set("case_data", _case(id))
	lv.set("patient", _patient(id))
	return lv


func _sheet(vals: Dictionary) -> Dictionary:
	var out := {}
	for f: int in vals:
		out[f] = {"stored_db": int(vals[f])}
	return out


## One ear's chart as the AudiOtron stores it: air, unmasked bone (optional) and masked bone (optional).
func _ear(air: Dictionary, bc: Dictionary, bc_masked: Dictionary = {}) -> Dictionary:
	var e := {"freqs": _sheet(air)}
	if not bc.is_empty():
		e["bc"] = _sheet(bc)
	if not bc_masked.is_empty():
		e["bc_masked"] = _sheet(bc_masked)
	var bone := bc.duplicate()
	for f: int in bc_masked:
		bone[f] = bc_masked[f]
	e["hearing_type"] = ClinicRules.hearing_type(air, bone)
	return e


## Melody's right ear: unmasked bone on the right mastoid hears the good left cochlea, so the chart
## reads conductive. That reading is not accepted until masked bone is run, and Hoot names the truth.
func test_an_unmasked_gap_is_not_an_accepted_type() -> void:
	var lv := _visit("fs_melody")
	var p := _patient("fs_melody")
	var cross := {}
	var own := {}
	for f: int in ClinicRules.BC_REQUIRED:
		cross[f] = FsRules.better_cochlea(p, f)
		own[f] = int(FsRules.truth_bone(p, "right").get(f, p.get_threshold("right", f)))
	var air_r := FsRules.truth_air(p, "right")
	var air_l := FsRules.truth_air(p, "left")
	lv.set("results", {"ears": {"right": _ear(air_r, cross), "left": _ear(air_l, {})}})
	assert_eq(lv.call("measured_type", "right"), &"conductive", "the cross-heard chart reads conductive")
	assert_true(bool(lv.call("unmasked_gap", "right")), "the gap was never masked")
	assert_eq(lv.call("accepted_types", "right"), [&"sensorineural"], "only the truth counts")
	lv.set("results", {"ears": {"right": _ear(air_r, cross, own), "left": _ear(air_l, {})}})
	assert_false(bool(lv.call("unmasked_gap", "right")), "masked bone answers it")
	assert_has(lv.call("accepted_types", "right"), &"sensorineural")
	lv.free()


## A wandering stamp (Penny's right ear charted at 30 dB once) still counts: the chart's own reading.
func test_a_wandering_stamp_still_counts() -> void:
	var lv := _visit("fs_penny")
	var p := _patient("fs_penny")
	var air := FsRules.truth_air(p, "right")
	air[4000] = 30
	var bc := {}
	for f: int in ClinicRules.BC_REQUIRED:
		bc[f] = int(air[f])
	lv.set("results", {"ears": {"right": _ear(air, bc), "left": _ear(FsRules.truth_air(p, "left"), {})}})
	assert_eq(lv.call("accepted_types", "right"), [&"normal", &"sensorineural"], "the truth and the chart's own reading")
	lv.free()


## "Look first" counts any test begun before the otoscope (bone included, FS-08), not the tray's order.
func test_look_first_counts_any_test() -> void:
	var lv := _visit("fs_penny")
	var p := _patient("fs_penny")
	lv.set("results", {"ears": {"right": _ear(FsRules.truth_air(p, "right"), {}), "left": _ear(FsRules.truth_air(p, "left"), {})}})
	lv.set("done", {&"chat": true, &"otoscopy": true, &"air": true})
	lv.set("asked", Array(_case("fs_penny")["key_questions"]))
	var oto := func() -> String:
		for r: Dictionary in (lv.call("workup_report") as Dictionary)["rows"]:
			if String(r["tool"]) == "otoscopy":
				return String(r["state"])
		return ""
	assert_eq(oto.call(), "ok")
	lv.set("tested_before_look", true)
	assert_eq(oto.call(), "slip", "a probe, earphone or bone oscillator before the look is the slip")
	assert_has((lv.call("workup_report") as Dictionary)["lines"], "Look before any test, bone too: what you see explains the chart.")
	lv.free()


## (FS-05) Every masked frequency on headphones leaves at least 20 dB between the starting noise and
## the overmasking line, so a 15 dB plateau fits without the warning. Conservative: the occlusion
## allowance whenever the masked ear's own gap allows it, and for masked air's line the better cochlea
## at the nearest stamped bone frequency (the AudiOtron's stand-in, AudiometrySession._nearest_freq).
func test_masking_windows_fit_a_plateau() -> void:
	for id: String in FsData.CASE_IDS:
		var p := _patient(id)
		for ear: String in ClinicRules.EARS:
			var other := "left" if ear == "right" else "right"
			for f: int in FsRules.truth_masked_bone(p, ear):
				var start := ClinicRules.initial_masking(p.get_threshold(other, f), f, &"bc_masked",
					p.get_threshold(other, f) - p.get_bc_threshold(other, f), &"phones")
				var limit := ClinicRules.overmask_limit(p.get_bc_threshold(ear, f), &"bc_masked", 0, &"phones")
				assert_true(limit - start >= 20, "%s %s masked bone %d Hz: noise starts at %d, overmasking at %d" % [id, ear, f, start, limit])
			for f: int in FsRules.truth_masked_air(p, ear, &"phones"):
				var bf := 0
				for b: int in ClinicRules.BC_REQUIRED:
					if bf == 0 or absf(log(float(b) / f)) < absf(log(float(bf) / f)) - 0.0001:
						bf = b
				var start2 := ClinicRules.initial_masking(p.get_threshold(other, f), f, &"ac_masked", 0, &"phones")
				var limit2 := ClinicRules.overmask_limit(p.get_threshold(ear, f), &"ac_masked",
					p.get_threshold(ear, f) - FsRules.better_cochlea(p, bf), &"phones")
				assert_true(limit2 - start2 >= 20, "%s %s masked air %d Hz: noise starts at %d, overmasking at %d" % [id, ear, f, start2, limit2])


## (FS-14) No walk-in's true bone reaches the felt-vibration line at 500 Hz (about 55 dB HL), as on the days.
func test_bone_stays_under_the_felt_line() -> void:
	for id: String in FsData.CASE_IDS:
		var p := _patient(id)
		for ear: String in ClinicRules.EARS:
			assert_true(p.get_bc_threshold(ear, 500) < 55, "%s %s bone at 500 Hz is %d" % [id, ear, p.get_bc_threshold(ear, 500)])


## (FS-03, FS-13) After the case's debrief: the Carhart line only when the truth has the notch and the
## chart shows it (Hector), and the word-test line on every FIT.
func test_debrief_extras() -> void:
	var lv := _visit("fs_hector")
	assert_true(ClinicRules.has_carhart_notch(FsRules.truth_bone(_patient("fs_hector"), "left")), "Hector's stiff ear has the notch")
	assert_eq(lv.call("debrief_extras"), [] as Array[String], "no notch on the chart, no line")
	lv.set("results", {"ears": {"left": {"carhart_notch": true}, "right": {"carhart_notch": true}}})
	assert_eq(lv.call("debrief_extras"), [LevelFreestyle.CARHART_LINE % "left"], "the left ear only: the right's truth has no notch")
	lv.free()
	for id: String in FsData.CASE_IDS:
		var v := _visit(id)
		var fit := StringName(String(_case(id)["decision"])) == &"fit"
		assert_eq((v.call("debrief_extras") as Array).has(LevelFreestyle.WORDS_LINE), fit, "%s: the word-test line on a FIT only" % id)
		v.free()


## (E19) After a day with its own movie, freestyle's pause menu still offers the masking movie that
## Hoot's MOVIE_HINT points to: the waiting room leaves the days behind (FsData.NOT_A_DAY).
func test_a_visit_pauses_to_the_masking_movie() -> void:
	var m := Movies.movie("masking")
	m["id"] = "fake_day_movie"
	m["chapter"] = "rocco"
	m.erase("seen_at")
	Movies.extra["fake_day_movie"] = m
	Game.current_chapter_id = "rocco"   # the day played last, with a movie of its own
	# (cases) a level that can mask offers every replay movie, even beside a day's own movies
	assert_true(Movies.for_level(Game.current_chapter_id, true).has("masking"), "the masking movie stays beside a day's own")
	var room: Control = (load("res://story/freestyle/waiting_room.tscn") as PackedScene).instantiate()
	add_node(room)
	await wait_frames(1)
	assert_eq(Game.current_chapter_id, FsData.NOT_A_DAY, "the waiting room leaves the days behind")
	var visit := Node.new()   # stands in for the runner, which joins the same group
	visit.add_to_group(Movies.MASKING_LEVEL_GROUP)
	add_node(visit)
	var menu: CanvasLayer = (load(PAUSE_MENU) as PackedScene).instantiate()
	add_node(menu)
	await wait_frames(1)
	menu.call("open")
	await wait_frames(1)
	var here: Array = menu.call("movie_ids_here")
	assert_true(here.has("masking"), "the pause menu offers the masking movie (%s)" % [here])
	assert_false(here.has("masking_recap"), "never the recap")
	assert_true(LevelFreestyle.MOVIE_HINT.contains("pause menu"), "Hoot's hint names the pause menu")
	menu.call("close")
	Movies.extra.clear()


## (FS-07, E2) Bone before air keeps the visit's 1 kHz retest: the screen waives the retest per ear, not
## per test, so the bone plan must not ask Hoot to skip it. With one screen (one session) per visit,
## the first air ear then owes the retest and the second does not (E2).
func test_bone_first_keeps_the_air_retest() -> void:
	assert_false(bool(LevelFreestyle.bone_plan().get("skip_hoot_retest", false)), "the bone plan waives nothing")
	assert_false(bool(LevelFreestyle.air_plan().get("skip_hoot_retest", false)), "the air plan waives nothing")
	var screen: CanvasLayer = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	Game.begin_visit("fs_mabel")
	var plan := LevelFreestyle.bone_plan()
	plan["air_transducer"] = &"phones"
	screen.call("start_test", _patient("fs_mabel"), "right", false, plan)
	await wait_frames(3)
	var s: AudiometrySession = screen.get("session")
	assert_true(s.retest_waived.is_empty(), "Hoot's bone montage waives no ear's air retest (%s)" % [s.retest_waived])
	assert_true(s.retest_required("right"), "right air first, after right bone: it owes the retest")
	s.air_ear_order = ["right"] as Array[String]
	assert_false(s.retest_required("left"), "the second air ear does not")
	Engine.time_scale = 1.0
	Hoot.clear()


## A double-click on a tray card cannot also answer the next row (mouse presses wait out the arming).
func test_tray_ignores_a_double_click() -> void:
	var tray := FsTray.new()
	add_node(tray)
	var labels: Array[String] = ["Right ear first", "Left ear first"]
	var got: Array = []
	var run := func() -> void:
		got.append(await tray.choose("Which ear goes first?", labels, 0))
	run.call()
	await wait_frames(2)
	var cards: Array = tray.get("_cards")
	(cards[0] as Button).pressed.emit()
	await wait_frames(3)
	assert_eq(got, [], "a press while the row arms is ignored")
	await wait_seconds(0.3)
	(cards[1] as Button).pressed.emit()
	await wait_frames(3)
	assert_eq(got, [1], "a press once armed answers")


## The title's menu card (seven buttons for a returning player, with stats) ends above the safety footer.
func test_title_menu_clears_the_footer() -> void:
	Game.reset_save()
	Game.progress["plays"] = 3
	Game.progress["coins"] = 80
	Game.progress["patients"] = {"gus": {"best_grade": "S", "best_score": 95.0}, "bonnie": {"best_grade": "A", "best_score": 85.0}}
	Game.progress["upgrades"] = ["comfy_chair", "insert_earphones"]
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	title.call("_on_notice_ok")
	await wait_seconds(0.6)
	var buttons: Array = title.get("_menu_buttons")
	assert_eq(buttons.size(), 8, "Play, Days, Training, Freestyle, Arcade, New player, Options, Quit")
	var card := title.get("_menu_card") as Control
	var foot := title.get_viewport_rect().size.y - float(title.get("FOOTER_H"))
	assert_true(card.get_global_rect().end.y <= foot, "the card ends at %d, the footer starts at %d" % [int(card.get_global_rect().end.y), int(foot)])
	Game.reset_save()


## The medal rules and the paper's blend (FREESTYLE.md §5).
func test_medals_and_the_paper_score() -> void:
	assert_eq(FsRules.chat_medal([]), "gold")
	assert_eq(FsRules.chat_medal(["onset"]), "silver", "one key question missed")
	assert_eq(FsRules.chat_medal(["red_flags"]), "bronze", "the red flags count double")
	assert_eq(FsRules.chat_medal(["onset", "noise"]), "bronze")
	assert_eq([FsRules.medal_for_slips(0), FsRules.medal_for_slips(1), FsRules.medal_for_slips(2)], ["gold", "silver", "bronze"])
	var golds := {"fs_chat": "gold", "fs_workup": "gold", "fs_chart": "gold", "fs_call": "gold"}
	assert_near(LevelFreestyle.freestyle_score(80.0, golds), 92.0, 0.01, "60 % medals, 40 % the visit")
	var mixed := {"fs_chat": "gold", "fs_workup": "silver", "fs_chart": "bronze", "fs_call": "gold"}
	assert_near(LevelFreestyle.freestyle_score(80.0, mixed), 78.5, 0.01, "silver 70, bronze 40")


## A visit that only ran air tones misses every other step a pro runs, each with its own slip.
func test_an_air_only_visit_misses_the_rest() -> void:
	var lv := _visit("fs_hector")
	var p := _patient("fs_hector")
	lv.set("results", {"ears": {"right": _ear(FsRules.truth_air(p, "right"), {}), "left": _ear(FsRules.truth_air(p, "left"), {})}})
	lv.set("done", {&"air": true})
	var rep: Dictionary = lv.call("workup_report")
	var states := {}
	var misses := 0
	for r: Dictionary in rep["rows"]:
		states[String(r["tool"])] = String(r["state"])
		if String(r["state"]) == "miss" and String(r["tool"]) != "chat":
			misses += 1
	for tool: String in ["otoscopy", "tymp", "bone", "masking"]:
		assert_eq(states.get(tool, ""), "miss", "%s is missed" % tool)
	assert_eq(int(rep["slips"]), misses, "one slip per missed step (questions go to the Chat medal)")
	assert_eq(FsRules.chat_medal(rep["keys_missed"]), "bronze")
	lv.free()


## Every line the runner gives Hoot keeps the house limit, filled with its longest words.
func test_runner_hoot_lines_fit_the_limit() -> void:
	var lines: Array[String] = [LevelFreestyle.BRIEFING, LevelFreestyle.TEXTBOOK_LINE,
		LevelFreestyle.WANDER_LINE % ["right", "a mixed loss"], LevelFreestyle.GAP_LINE % ["right", "a mixed loss"],
		LevelFreestyle.ROUTINE_LINE, LevelFreestyle.MOVIE_HINT, LevelFreestyle.CARHART_LINE % "right",
		LevelFreestyle.WORDS_LINE]
	for k: StringName in CaseRules.TYMP_TYPES:
		lines.append(LevelFreestyle.TYMP_HINT % [k, CaseRules.TYMP_SHAPES[k]])
	for id: String in FsData.CASE_IDS:
		var lv := _visit(id)
		for k: StringName in FsRules.TYPE_CHOICES:
			lines.append(String(lv.call("_type_hint", k, "right")))
		var rep: Dictionary = lv.call("workup_report")   # nothing run: every slip line at once
		for l: Variant in rep["lines"]:
			lines.append(String(l))
		lv.free()
	for l: String in lines:
		var words := l.split(" ", false).size()
		assert_true(words <= CaseData.HOOT_MAX_WORDS, "%d words: %s" % [words, l])
