extends TestCase
## Freestyle (docs/FREESTYLE.md): every walk-in case file is playable and keeps the house rules, and
## each patient's truth really supports the call the case teaches (type of loss per ear, which tests a
## full workup needs, masking, asymmetry, urgency), robustly enough that a few dB of wandering stamps
## do not flip the lesson.

const FsData := preload("res://story/freestyle/fs_data.gd")
const FsRules := preload("res://story/freestyle/fs_rules.gd")
const CaseData := preload("res://story/case_data.gd")
const FsTray := preload("res://story/freestyle/fs_tray.gd")
const LevelFreestyle := preload("res://story/freestyle/level_freestyle.gd")

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
