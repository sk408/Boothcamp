extends Node
## LevelFreestyle (freestyle): one walk-in visit (docs/FREESTYLE.md §1). Plays the waiting room's pick
## (FsData.next_case(), or --freestyle=<id>): the patient walks in and says why they came, then the
## player picks tools from the tray in any order (questions, otoscope, tympanometer, air, bone,
## masking), names the type of hearing in each ear and makes the call: FIT / REFER / DOCTOR TODAY /
## NO AIDS NEEDED, and why. Hoot never coaches the tones (a wrong tympanogram or chart type gets a
## one-line hint; short routine lines and, until Day 2's movie is seen, the masking recap card); the debrief compares the visit with the workup a pro would run (FsRules.workup). Every choice is shuffled or ordered with Game.rng only
## where the story's runners do; every blocking beat emits Events.awaiting_input with a solver.
##   world:  res://world/clinic.tscn with patient_id + patient_spec (the case's look)
##   ui:     res://ui/audiometer/audiometer_screen.tscn start_test(patient, ear, false, plan), one
##           screen for the whole visit so every test lands on the same chart
##   global: Game (visit, medals, flags), Events (phases, awaiting_input), Hoot

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const CaseData := preload("res://story/case_data.gd")
const CaseProps := preload("res://story/games/case_props.gd")
const FsData := preload("res://story/freestyle/fs_data.gd")
const FsRules := preload("res://story/freestyle/fs_rules.gd")
const FsTray := preload("res://story/freestyle/fs_tray.gd")
const FsQuestions := preload("res://story/freestyle/fs_questions.gd")
const FsClipboard := preload("res://story/freestyle/fs_clipboard.gd")
const FsChart := preload("res://story/freestyle/fs_chart.gd")
const FsDebrief := preload("res://story/freestyle/fs_debrief.gd")
const Movies := preload("res://story/explainers/movies.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const LEVEL_SCENE := "res://story/freestyle/level_freestyle.tscn"
const WAITING_ROOM := "res://story/freestyle/waiting_room.tscn"

const STEPS: Array[StringName] = [&"workup", &"chart", &"call"]
const STEP_LABELS: Dictionary = {&"workup": "Workup", &"chart": "Chart", &"call": "The call"}
## The Daily Decibel's medal row (Game.record_medal beats).
const MEDAL_BEATS: Array = [["fs_chat", "Chat"], ["fs_workup", "Workup"], ["fs_chart", "Chart"], ["fs_call", "Call"]]
const MEDAL_VALUES: Dictionary = {"gold": 1.0, "silver": 0.7, "bronze": 0.4}
## The paper's score: this share from the medals, the rest from the visit's audiometry score.
const MEDAL_WEIGHT := 0.6
## Quick visit: the player stamps this many air tones per ear, then Hoot finishes at x8.
const AIR_SOLO := 3
const BRIEFING := "Your clinic, your call! Any tool, any order. I'll save my notes for the end."
## Hoot's runner lines (18 words at most once filled in; tests check the longest fill).
const TYMP_HINT := "Type %s would be %s. Look where the peak sits, and how tall."
const WANDER_LINE := "That's what your chart shows. Underneath, the %s ear is %s: a few stamps wandered."
const GAP_LINE := "The %s ear's bone was never masked: the other cochlea may have answered. Underneath, it's %s."
const TEXTBOOK_LINE := "A textbook workup: every step a pro would take, in the right order."
## (Clinical review A1) The routine around the tests, ungraded: a clean speculum tip every visit,
## the patient told how to answer (BSA 2018, 6.1), and once per session Hoot's daily listening check
## and the dials kept out of the patient's view (BSA 2018, 4.1 and 11.1; ASHA 2005), in the cases'
## own words (story/level_case.gd ROUTINE_LINE).
const SPECULUM_LINE := "A fresh speculum tip, then a quick look in each ear."
const INSTRUCT_LINE := "Press the button as soon as you hear a beep, in either ear, even a very faint one. Let go when it stops."
const ROUTINE_LINE := "This morning's listening check: every beep clean, the button works. Dials stay out of view."
## (FS-01) Masked bone starts from unmasked bone (either mastoid): nothing to start from yet.
const BONE_FIRST_LINE := "Masked bone starts from unmasked bone. Bone tones first!"
## (A2) Before the visit's first masked test, when Day 2's masking movie is still unseen: the
## one-card recap, then where the full movie lives (the pause menu offers it once E19 is in).
const EXPLAINER_SCENE := "res://story/explainers/explainer_player.tscn"
const MOVIE_ID := "masking"
const RECAP_ID := "masking_recap"
const MOVIE_HINT := "The full masking movie is under Hoot's Movies, in the pause menu or on the title screen."
## (FS-03) A Carhart notch the truth has and the chart shows: named, as on Day 2.
const CARHART_LINE := "See the bone dip at 2k on the %s? A Carhart notch: a stiff middle ear fakes it."
## (FS-13, with the cases' C13) Every FIT: word tests come with a full fitting.
const WORDS_LINE := "A full fitting also checks words, in quiet and in noise."
const TIP_OPTIONS: Array[String] = ["Small tip", "Medium tip", "Large tip"]
const EAR_OPTIONS: Array[String] = ["Right ear first", "Left ear first"]
const MASTOID_OPTIONS: Array[String] = ["Right mastoid", "Left mastoid"]
const MASK_OPTIONS: Array[String] = ["Masked bone R", "Masked bone L", "Masked air R", "Masked air L", "No masking"]
const MASK_STEPS: Array = [["bc_masked", "right"], ["bc_masked", "left"], ["ac_masked", "right"], ["ac_masked", "left"], ["", ""]]
const TYMP_LABELS: Dictionary = {
	&"A": "A: normal peak", &"As": "As: shallow peak", &"Ad": "Ad: very tall peak", &"B": "B: flat", &"C": "C: peak moved left",
}
const STAMP_COLORS: Dictionary = {
	&"fit": Color("#c9f2dd"), &"refer": Color("#ffe1a8"), &"today": Color("#ffc9c0"), &"clear": Color("#dbe9ff"),
}
## What each deck question is about, for the debrief ("You never asked about ...").
const TOPICS: Dictionary = {
	"which_ear": "which ear is better", "onset": "how it started", "ringing": "ringing",
	"red_flags": "pain, drainage and dizziness", "noise": "loud noise", "ear_history": "ear infections and injuries",
	"family": "family hearing loss", "health": "health and medicines", "aids": "hearing aids before",
	"hardest": "daily trouble spots",
}

var case_id := ""
var case_data: Dictionary = {}
var speaker := "Patient"
var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var screen: CanvasLayer
var tray: Control
var board: Control
var clipboard: Control
var chart: Control
var debrief_card: Control
var results: Dictionary = {}
## Tools run so far ({tool: true}; masked runs as {"bc_masked:right": true}) and the tray's picks in order.
var done: Dictionary = {}
var order: Array[StringName] = []
## Deck questions asked, in order.
var asked: Array = []
## Which ear went first for air / which mastoid for bone ("" = not run yet).
var air_first := ""
var bone_side := ""
## Masked sheets the player ran: ["bc_masked:right", ...]
var masked_runs: Array[String] = []
var chart_slips := 0
var call_slips := 0
## Wrong tympanogram types named (Hoot explains each; not a Chart slip, see FREESTYLE.md §5).
var tymp_misreads := 0
## True once any test began before the otoscope looked: the tymp probe, earphones, the bone
## oscillator or a masking earphone (the "look first" slip; FS-08).
var tested_before_look := false
var props: Control
var _cam: Camera3D
var _seated := false
var _instructed := false
var _recapped := false
## (A1) Hoot's once-per-session routine line (the listening check, the dials) has been said.
static var _routine_said := false


func _ready() -> void:
	add_to_group(&"masking_level")  # (E19) the pause menu offers the masking movie (Movies.MASKING_LEVEL_GROUP)
	Game.current_chapter_id = FsData.NOT_A_DAY
	case_id = FsData.next_case()
	case_data = FsData.load_case(case_id)
	var problems := FsData.validate(case_data) if not case_data.is_empty() else PackedStringArray(["no case file"])
	if not problems.is_empty():
		push_error("LevelFreestyle %s: %s" % [case_id, "; ".join(problems)])
		if case_data.is_empty():
			Events.goto_scene.emit.call_deferred(WAITING_ROOM)
			return
	FsData.register_speakers()
	speaker = String(case_data["speaker"])
	var pid := String(case_data["patient_id"])
	Game.begin_visit(pid)
	Game.set_visit_flag("freestyle_case", case_id)
	patient = Game.load_patient(pid) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", pid)
	clinic.set("patient_spec", CaseData.bean_spec(case_data))
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, "WALK-IN: " + patient.display_name.to_upper())
	hud.call("set_notes_visible", false)
	clipboard = FsClipboard.new()
	hud.call("add_game", clipboard)
	clipboard.call("setup", "%s, %d" % [patient.display_name, patient.age])
	clipboard.visible = false
	chart = FsChart.new()
	hud.call("add_game", chart)
	board = FsQuestions.new()
	hud.call("add_game", board)
	tray = FsTray.new()
	hud.call("add_game", tray)
	debrief_card = FsDebrief.new()
	hud.call("add_game", debrief_card)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.level_started.emit(pid)
	_run.call_deferred()


func _phase(p: StringName, info: Dictionary = {}) -> void:
	Events.phase_changed.emit(p, info)


func _say(who: String, text: String) -> void:
	await dialogue.say(who, text)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _react(kind: StringName, data: Dictionary = {}) -> void:
	Events.patient_reaction.emit(kind, data)


func _shot(shot_name: String, delay: float = 0.0) -> void:
	if not Game.cli.has("shots"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	Events.screenshot_requested.emit("freestyle_%s_%s" % [case_id, shot_name])


## Play a script from the case file: lines ["Speaker", "text"] and actions {"react"}, {"hoot"}, {"do"}.
func _play(lines: Variant) -> void:
	if not lines is Array:
		return
	for e: Variant in lines:
		if CaseData.is_line(e):
			var a: Array = e
			await _say(String(a[0]), String(a[1]))
		elif e is Dictionary:
			var d: Dictionary = e
			if d.has("react"):
				_react(StringName(String(d["react"])))
			if d.has("hoot"):
				clinic.call("hoot_emote", StringName(String(d["hoot"])))
			if d.has("do"):
				await _do(String(d["do"]))


func _do(what: String) -> void:
	match what:
		"hearing_aids":
			await clinic.call("focus_camera", &"face", 0.5)
			clinic.call("put_on_hearing_aids")
			_shot("hearing_aids", 0.4)
			await _wait(1.2)
			clinic.call("focus_camera", &"desk", 0.6)
		"letter", "phone", "boat":
			if props == null:
				props = CaseProps.new()
				hud.call("add_game", props)
			# the phone stays on the desk through the call's lines; _goodbye hangs up
			await props.call("play", what)


## True the first time a player opens freestyle (no walk-in finished yet).
static func first_visit() -> bool:
	var pats: Dictionary = Game.progress.get("patients", {})
	for id: String in FsData.CASE_IDS:
		if pats.has(String(FsData.load_case(id).get("patient_id", id))):
			return false
	return true


func _air_transducer() -> StringName:
	return &"inserts" if Game.has_upgrade("insert_earphones") else &"phones"


func _run() -> void:
	await _intro()
	await _workup()
	await _walk_to_desk()
	await _chart_question()
	await _decision()
	await _debrief()
	await _goodbye()
	await _results()


# ---------------------------------------------------------------- 1. the walk-in

func _intro() -> void:
	_phase(&"intro")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	_react(&"wave")
	_shot("intro", 0.3)
	if first_visit():
		clinic.call("hoot_emote", &"wing_up")
		await _say("Hoot", BRIEFING)
	await _play(case_data["hello"])
	clipboard.visible = true


# ---------------------------------------------------------------- 2. the workup: the tray loop

## The tools on offer: the deck while questions are left, everything else always (speech joins once
## its screen is in the build and a case asks for it).
func _tray_tools() -> Array[StringName]:
	var out: Array[StringName] = []
	for t: StringName in FsRules.TOOLS:
		if t == &"chat" and asked.size() >= FsRules.CHAT_BUDGET:
			continue
		if t == &"speech":
			continue
		if t == &"tymp" and not ResourceLoader.exists(FsRules.TYMP_GADGET):
			continue
		out.append(t)
	return out


func _workup() -> void:
	while true:
		_phase(&"freestyle_tray")
		hud.call("set_step", &"workup")
		clipboard.visible = true
		_show_chart()
		var tools := _tray_tools()
		var best := FsRules.best_tool(case_data, patient, results, done, asked, _air_transducer())
		if not tools.has(best):
			best = &"call"
		var who := patient.short_name()
		var t: StringName = await tray.call("pick", tools, done, best, "What next for %s?" % who)
		order.append(t)
		if t == &"call":
			break
		match t:
			&"chat":
				await _chat()
			&"otoscopy":
				await _otoscopy()
			&"tymp":
				await _tymp()
			&"air":
				await _air()
			&"bone":
				await _bone()
			&"masking":
				await _masking()
		_refresh_clipboard()
	hud.call("complete_step", &"workup")


func _show_chart() -> void:
	if (results.get("ears", {}) as Dictionary).is_empty():
		chart.call("hide_chart")
	else:
		chart.call("show_chart", "%s'S CHART" % patient.short_name().to_upper(), results)


func _hide_overlays() -> void:
	chart.call("hide_chart")
	clipboard.visible = false


# ---------------------------------------------------------------- 2a. questions

func _chat() -> void:
	_phase(&"history")
	_hide_overlays()
	if _seated:
		clinic.call("focus_camera", &"face", 0.6)
	else:
		clinic.call("focus_camera", &"desk", 0.6)
	while asked.size() < FsRules.CHAT_BUDGET:
		var keys := FsRules.keys_left(case_data, asked)
		var best_id := keys[0] if not keys.is_empty() else ""
		# the board covers the clipboard's column: the clipboard shows while the patient answers
		clipboard.visible = false
		var qid: String = await board.call("ask", asked, FsRules.CHAT_BUDGET - asked.size(), best_id, patient.short_name())
		if qid == "":
			break
		asked.append(qid)
		_react(&"nod")
		clipboard.visible = true
		for line: String in FsData.answer_lines(case_data, qid):
			await _say(speaker, line)
		var a: Dictionary = (case_data["answers"] as Dictionary).get(qid, {})
		clipboard.call("add_note", FsData.answer_note(case_data, qid), "flag" if bool(a.get("flag", false)) else "note")
		await _wait(0.4)   # the note lands before the board comes back
	clipboard.visible = true
	done[&"chat"] = true
	Game.set_visit_flag("freestyle_asked", asked.duplicate())


# ---------------------------------------------------------------- 2b. the otoscope

func _otoscopy() -> void:
	_phase(&"otoscopy")
	_hide_overlays()
	await _stand_if_seated()
	await clinic.call("focus_camera", &"otoscope", 0.8)
	await _say("You", SPECULUM_LINE)
	var oto: Dictionary = case_data["otoscopy"]
	var g := Otoscopy.new()
	hud.call("add_game", g)
	for ear: String in ClinicRules.EARS:
		var v: Dictionary = oto[ear]
		var view := String(v.get("view", "clear"))
		if view != "clear" and g.has_method("show_view"):
			await g.call("show_view", ear, view, "")
		else:
			await g.show_clear(ear, "")
		_shot("otoscopy_" + ear, 0.2)
		await _say("You", String(v["caption"]))
	g.queue_free()
	clipboard.call("add_note", String(oto["note"]))
	var canal := String(oto["canal"])
	clipboard.call("add_note", "%s%s ear canals" % [canal.left(1).to_upper(), canal.substr(1)])
	clinic.call("focus_camera", &"desk", 0.6)
	done[&"otoscopy"] = true


# ---------------------------------------------------------------- 2c. the tympanometer

func _tymp() -> void:
	_phase(&"tymp")
	_hide_overlays()
	await _stand_if_seated()
	clinic.call("focus_camera", &"ear_right", 0.8)
	var ty: Dictionary = case_data["tymp"]
	# the cases thread's gadget, loaded by path (the tray hides the tool when it is missing)
	var g: Control = (load(FsRules.TYMP_GADGET) as GDScript).new()
	hud.call("add_game", g)
	var right_tip := FsData.tip_for(case_data)
	g.call("show_tips", right_tip)
	var sizes: Array[StringName] = CaseRules.TIP_SIZES.duplicate()
	var opts: Array[String] = TIP_OPTIONS.duplicate()
	var tries := 0
	while true:
		tries += 1
		var ch: int = await tray.call("choose", "Which ear tip seals %s's ear canal?" % patient.short_name(), opts, sizes.find(right_tip))
		var ok: bool = await g.call("try_tip", sizes[ch])
		if ok:
			break
		sizes.remove_at(ch)
		opts.remove_at(ch)
	Game.set_visit_flag("freestyle_tip_tries", tries)
	_test_begins()
	_react(&"nod")
	_shot("tymp_sweep", 1.0)
	await g.call("measure", "right", ty["right"])
	await g.call("measure", "left", ty["left"])
	for ear: String in ClinicRules.EARS:
		var truth := CaseRules.tymp_type_of(ty[ear])
		var types: Array[StringName] = CaseRules.TYMP_TYPES.duplicate()
		while true:
			var labels: Array[String] = []
			for k: StringName in types:
				labels.append(String(TYMP_LABELS[k]))
			var pick: int = await tray.call("choose", "What type is the %s ear's tympanogram?" % ear.to_upper(), labels, types.find(truth))
			if types[pick] == truth:
				break
			tymp_misreads += 1
			await _say("Hoot", TYMP_HINT % [types[pick], CaseRules.TYMP_SHAPES[types[pick]]])
			types.remove_at(pick)
		g.call("reveal_type", ear)
	Game.set_visit_flag("freestyle_tymp_misreads", tymp_misreads)
	_shot("tymp_curves", 0.3)
	clipboard.call("add_note", String(ty["note"]))
	await _wait(0.6)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	await t.finished
	g.queue_free()
	clinic.call("focus_camera", &"desk", 0.6)
	done[&"tymp"] = true


# ---------------------------------------------------------------- 2d. audiometry (one screen per visit)

func _open_screen() -> void:
	if screen == null:
		screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(screen)
	elif not screen.visible:
		screen.process_mode = Node.PROCESS_MODE_INHERIT
		Stage.register_audiometer(screen)
		Sfx.music_duck(true)
	screen.visible = true
	_cam = clinic.call("get_main_camera")
	_cam.current = false


## Between tests the screen stays in the tree (its Hoot anchors are registered once, in _ready) but
## stops: no false-alarm presses during a chat, and the pause corner and the music come back.
func _close_screen() -> void:
	if screen != null:
		screen.visible = false
		screen.process_mode = Node.PROCESS_MODE_DISABLED
		Stage.unregister_audiometer(screen)
		Stage.set_booth_view_active(false)
		Sfx.music_duck(false)
	if _cam != null:
		_cam.current = true


func _quick() -> bool:
	return screen == null or bool(screen.get("quick_visit"))


func _test(ear: String, plan: Dictionary) -> void:
	plan["air_transducer"] = _air_transducer()
	_phase(&"audiometry", {"ear": ear, "test": String(plan.get("test", "ac"))})
	screen.call("start_test", patient, ear, false, plan)
	var r: Dictionary = await screen.test_finished
	results = r
	Game.set_audiometry_results(results)


## Into the booth chair (once), with the patient told what to do the first time.
func _to_booth() -> void:
	_hide_overlays()
	if not _seated:
		clinic.call("focus_camera", &"booth", 1.0)
		await clinic.call("sit")
		_seated = true
	await clinic.call("focus_camera", &"face", 0.6)
	if not _routine_said:
		_routine_said = true
		await _say("Hoot", ROUTINE_LINE)
	if not _instructed:
		_instructed = true
		await _say("You", INSTRUCT_LINE)
		_react(&"nod")
		Game.set_visit_flag("instructed", true)


func _stand_if_seated() -> void:
	if _seated:
		clinic.call("take_off_earphones")
		clinic.call("take_off_bone_oscillator")
		await clinic.call("walk_to", &"desk", 1.6)
		_seated = false


## A test begins (tymp probe, earphones, bone oscillator, a masking earphone): before the otoscope
## looked? (FS-08: ASHA 2005 and BSA 2018 put otoscopy before every test, bone included.)
func _test_begins() -> void:
	if not done.has(&"otoscopy"):
		tested_before_look = true


func _walk_to_desk() -> void:
	if screen != null:
		screen.queue_free()
		screen = null
	if _cam != null:
		_cam.current = true
	await _stand_if_seated()


## The better ear by the true pure-tone average ("" when within 5 dB: either ear is fine).
func _better_ear_truth() -> String:
	return FsRules.better_ear(FsRules.truth_air(patient, "right"), FsRules.truth_air(patient, "left"))


func _air() -> void:
	# asked at the desk, with the chart and the clipboard's notes still in view
	var better := _better_ear_truth()
	var ch: int = await tray.call("choose", "Which ear goes first?", EAR_OPTIONS, 1 if better == "left" else 0)
	var first := "right" if ch == 0 else "left"
	if air_first == "":
		air_first = first
	await _to_booth()
	_test_begins()
	clinic.call("take_off_bone_oscillator")
	clinic.call("put_on_earphones", true)
	await _wait(0.5)
	_open_screen()
	for ear: String in [first, "left" if first == "right" else "right"]:
		await _test(ear, air_plan())
	_close_screen()
	clinic.call("take_off_earphones")
	done[&"air"] = true


func _bone() -> void:
	var better := _better_ear_measured()
	var ch: int = await tray.call("choose", "Which side for the bone oscillator?", MASTOID_OPTIONS, 1 if better == "left" else 0)
	var ear := "right" if ch == 0 else "left"
	if bone_side == "":
		bone_side = ear
	await _to_booth()
	_test_begins()
	await _bone_on(ear)
	clinic.call("take_off_bone_oscillator")
	done[&"bone"] = true


## The better ear for bone: by the measured air when there is some, else by the truth.
func _better_ear_measured() -> String:
	var r := ClinicRules.best_thresholds(results, "right", false)
	var l := ClinicRules.best_thresholds(results, "left", false)
	if r.is_empty() or l.is_empty():
		return _better_ear_truth()
	return FsRules.better_ear(r, l)


## Unmasked bone on one mastoid (Hoot's montage on a quick visit).
func _bone_on(ear: String) -> void:
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", StringName("ear_" + ear), 0.5)
	clinic.call("put_on_bone_oscillator", ear)
	await _wait(0.5)
	_open_screen()
	await _test(ear, bone_plan())
	_close_screen()


## The air plan: the player stamps AIR_SOLO frequencies, then Hoot finishes the ear at 8x. (FS-07, E2)
## The 1 kHz retest is owed by the visit's first air ear only, or the second too after a first-ear
## mismatch over 5 dB: the session lives for the whole visit (one screen), so it knows which ear came first.
static func air_plan() -> Dictionary:
	return {"test": "ac", "hoot_turn_after": AIR_SOLO}


## The bone plan: Hoot's montage on one mastoid. (FS-07) No "skip_hoot_retest": the screen waives the
## retest per ear, not per test, so a bone run before air would cost that ear its air retest.
static func bone_plan() -> Dictionary:
	return {"test": "bc", "bc_freqs": ClinicRules.BC_REQUIRED, "masking_controls": true, "hoot_turn_after": 0,
		"montage": true}


func _masking() -> void:
	if not FsRules.air_done(results):
		# masking levels come from the air chart: nothing to work from yet
		await _say("You", "Masking works from the air chart. Air tones first!")
		return
	var best := MASK_STEPS.size() - 1
	for step: Dictionary in FsRules.workup(case_data, patient, results, _air_transducer()):
		var id := String(step["id"])
		if id == "bc_masked" and not FsRules.bone_done(results):
			continue   # (FS-01) masked bone waits for unmasked bone: not the pro's pick yet
		if (id == "bc_masked" or id == "ac_masked") and not FsRules.step_done(step, done, results):
			for i in MASK_STEPS.size():
				if MASK_STEPS[i][0] == id and MASK_STEPS[i][1] == String(step["ear"]):
					best = i
			break
	var ch: int = await tray.call("choose", "Which masked test?", MASK_OPTIONS, best)
	var test := String(MASK_STEPS[ch][0])
	if test == "":
		return
	if test == "bc_masked" and not FsRules.bone_done(results):
		# (FS-01) the masked search starts at the unmasked bone (from either mastoid): none yet
		await _say("You", BONE_FIRST_LINE)
		return
	var ear := String(MASK_STEPS[ch][1])
	var other := "left" if ear == "right" else "right"
	await _to_booth()
	_test_begins()
	var run := "%s:%s" % [test, ear]
	if not masked_runs.has(run):
		masked_runs.append(run)
	# air is on the chart, so the AudiOtron's own rule decides; "nothing to mask" still counts as run
	done[StringName(run)] = true
	if test == "bc_masked":
		clinic.call("take_off_earphones")
		clinic.call("put_on_bone_oscillator", ear)
		clinic.call("put_on_masking_phone", other)
	else:
		clinic.call("take_off_bone_oscillator")
		clinic.call("put_on_earphones", true)
	await _recap()
	await _wait(0.5)
	_open_screen()
	var what := "bone" if test == "bc_masked" else "air"
	await _test(ear, {"test": test, "masking_controls": true, "hoot_turn_after": 0,
		"intro": ("Masked %s at Hoot speed: the shhh goes in the %s ear." if _quick() else "Masked %s: the shhh goes in the %s ear.") % [what, other]})
	_close_screen()
	clinic.call("take_off_bone_oscillator")
	clinic.call("take_off_earphones")
	done[&"masking"] = true


## (A2) The masking recap card before the visit's first masked test, while Day 2's full movie is
## unseen (a player who starts in freestyle has never met masking), as Day 2's _recap() plays it.
func _recap() -> void:
	if _recapped or Game.is_movie_seen(MOVIE_ID) or not Movies.has(RECAP_ID):
		return
	_recapped = true
	var player: Node = (load(EXPLAINER_SCENE) as PackedScene).instantiate()
	add_child(player)
	await player.call("play", RECAP_ID, "recap")
	player.queue_free()
	await _say("Hoot", MOVIE_HINT)


## The clipboard's chart lines: each ear's air (PTA and degree), bone and masked sheets run.
func _refresh_clipboard() -> void:
	var lines: Array[String] = []
	for ear: String in ClinicRules.EARS:
		var air := ClinicRules.best_thresholds(results, ear, false)
		if not air.is_empty():
			var p := ClinicRules.pta(air)
			if not is_nan(p):
				lines.append("%s air: PTA %d dB (%s)" % [ear.capitalize(), int(round(p)), ClinicRules.degree_name(p)])
	# one line for bone and one for masking, so a long visit still fits the board
	var bone: Array[String] = []
	for ear: String in ClinicRules.EARS:
		if FsRules.has_sheet(results, ear, &"bc"):
			bone.append(ear)
	if not bone.is_empty():
		lines.append("Bone: %s mastoid%s" % [" and ".join(bone), "s" if bone.size() > 1 else ""])
	var masked: Array[String] = []
	for ear: String in ClinicRules.EARS:
		for test: StringName in FsRules.MASK_SHEETS:
			if FsRules.has_sheet(results, ear, test):
				masked.append("%s %s" % [ear, "bone" if test == &"bc_masked" else "air"])
	if not masked.is_empty():
		lines.append("Masked: %s" % ", ".join(masked))
	clipboard.call("set_tests", lines)


# ---------------------------------------------------------------- 3. the chart: type per ear

## The type a player may name for an ear: the truth, or what their own chart shows when it differs
## (a few wandering stamps), but not a gap the chart asked to mask when nobody masked it.
func accepted_types(ear: String) -> Array[StringName]:
	var out: Array[StringName] = [FsRules.truth_type(patient, ear)]
	var measured := measured_type(ear)
	if measured != &"unknown" and not out.has(measured) and not unmasked_gap(ear):
		out.append(measured)
	return out


func measured_type(ear: String) -> StringName:
	return ((results.get("ears", {}) as Dictionary).get(ear, {}) as Dictionary).get("hearing_type", &"unknown")


## True when this ear's air sits 10 dB or more above unmasked bone and masked bone was never run on
## it: the "gap" may be the other cochlea answering.
func unmasked_gap(ear: String) -> bool:
	return not FsRules.masked_bone_needed(results, ear).is_empty() and not FsRules.has_sheet(results, ear, &"bc_masked")


func _chart_question() -> void:
	_phase(&"freestyle_chart")
	hud.call("set_step", &"chart")
	clipboard.visible = true
	_show_chart()
	clinic.call("focus_camera", &"desk", 0.6)
	_shot("chart", 0.4)
	var types_named: Dictionary = {}
	for ear: String in ClinicRules.EARS:
		var ok_types := accepted_types(ear)
		var kinds: Array[StringName] = FsRules.TYPE_CHOICES.duplicate()
		while true:
			var labels: Array[String] = []
			for k: StringName in kinds:
				labels.append(String(FsRules.TYPE_LABELS[k]))
			var pick: int = await tray.call("choose", "What type of hearing is in the %s ear?" % ear.to_upper(), labels, kinds.find(ok_types[0]))
			var k2 := kinds[pick]
			var truth := FsRules.truth_type(patient, ear)
			if ok_types.has(k2):
				types_named[ear] = k2
				Sfx.play(&"ding", 1.2, -6.0)
				if k2 != truth:
					# the chart's own reading counts; Hoot still says what the ear really is
					await _say("Hoot", WANDER_LINE % [ear, _type_word(truth)])
				break
			chart_slips += 1
			if k2 == measured_type(ear) and unmasked_gap(ear):
				await _say("Hoot", GAP_LINE % [ear, _type_word(truth)])
			else:
				await _say("Hoot", _type_hint(k2, ear))
			kinds.remove_at(pick)
	Game.set_visit_flag("freestyle_types", types_named)
	Game.record_medal("fs_chart", FsRules.medal_for_slips(chart_slips))
	hud.call("complete_step", &"chart")


## "sensorineural", "a mixed loss": a type name for Hoot's sentences.
static func _type_word(t: StringName) -> String:
	if t == &"mixed":
		return "a mixed loss"
	return String(t)


## Hoot's nudge after a wrong type: what that type would need to show.
func _type_hint(wrong: StringName, ear: String) -> String:
	match wrong:
		&"normal":
			return "Normal means every %s air tone at 25 dB or better. Check the chart." % ear
		&"sensorineural":
			return "Sensorineural means bone sits with the air: no gap. Is that what the chart shows?"
		&"conductive":
			return "Conductive means a gap: bone near normal, air poorer. Is that what the chart shows?"
	return "Mixed means a gap AND poorer bone. Look at where the bone sits."


# ---------------------------------------------------------------- 4. the call, then why

func _decision() -> void:
	_phase(&"decision")
	hud.call("set_step", &"call")
	var answer := StringName(String(case_data["decision"]))
	var lines: Dictionary = case_data["decision_lines"]
	var labels: Array[String] = []
	var colors: Dictionary = {}
	for i in FsRules.DECISIONS.size():
		labels.append(String(FsRules.DECISION_STAMPS[FsRules.DECISIONS[i]]))
		colors[i] = STAMP_COLORS[FsRules.DECISIONS[i]]
	var tries := 0
	while true:
		tries += 1
		var i2: int = await tray.call("choose", "Make the call for %s:" % patient.short_name(), labels, FsRules.DECISIONS.find(answer), colors)
		var d: StringName = FsRules.DECISIONS[i2]
		var right := d == answer
		if tries == 1:
			Game.set_visit_flag("decision_first", String(d))
		if chart.call("is_shown"):
			await chart.call("slam", FsRules.DECISION_STAMPS[d], right)
		if right:
			_react(&"cheer")
			_shot("stamp", 0.1)
		await _say("Hoot", String(lines.get(String(d), "")))
		if right:
			break
		call_slips += 1
	Game.set_visit_flag("decision", String(answer))
	Game.set_visit_flag("decision_tries", tries)
	chart.call("hide_chart")
	await _why()
	Game.record_medal("fs_call", FsRules.medal_for_slips(call_slips))
	hud.call("complete_step", &"call")


## "Why?": the case's reasons, shuffled; repeats until a right one is picked.
func _why() -> void:
	var w: Dictionary = case_data["why"]
	var raw: Array = w["options"]
	var order_i: Array[int] = []
	for k in raw.size():
		order_i.append(k)
	for k in range(order_i.size() - 1, 0, -1):
		var j := Game.rng.randi_range(0, k)
		var tmp := order_i[k]
		order_i[k] = order_i[j]
		order_i[j] = tmp
	while not order_i.is_empty():
		var opts: Array[String] = []
		var best := 0
		for k in order_i.size():
			var o: Array = raw[order_i[k]]
			opts.append(String(o[0]))
			if bool(o[1]) and not bool((raw[order_i[best]] as Array)[1]):
				best = k
		var ch: int = await dialogue.choose(String(w["prompt"]), opts, best)
		var pick: Array = raw[order_i[ch]]
		if bool(pick[1]):
			_react(&"nod")
			await _say("Hoot", String(pick[2]))
			return
		call_slips += 1
		await _say("Hoot", String(pick[2]))
		order_i.remove_at(ch)


# ---------------------------------------------------------------- 5. the debrief: the workup card

## The workup card's rows and the slips Hoot explains: {"rows": [...], "lines": [...], "slips": int,
## "keys_missed": [...]}. Public and pure (reads only the visit state) so tests can drive it.
func workup_report() -> Dictionary:
	var rows: Array[Dictionary] = []
	var lines: Array[String] = []
	var slips := 0
	var steps := FsRules.workup(case_data, patient, results, _air_transducer())
	var needed: Dictionary = {}
	var keys: Array = case_data.get("key_questions", [])
	var keys_missed: Array[String] = []
	for k: Variant in keys:
		if not asked.has(String(k)):
			keys_missed.append(String(k))
	for step: Dictionary in steps:
		var id := String(step["id"])
		var ear := String(step["ear"])
		needed[id + ":" + ear] = true
		match id:
			"chat":
				var got := keys.size() - keys_missed.size()
				rows.append({"tool": "chat", "text": "Ask questions: %d of %d key questions" % [got, keys.size()],
					"state": "ok" if keys_missed.is_empty() else "miss"})
				if keys_missed.has(FsRules.RED_FLAG_QUESTION):
					lines.append("Always ask about pain, drainage and dizziness. Red flags decide referrals.")
				var others: Array[String] = []
				for k: String in keys_missed:
					if k != FsRules.RED_FLAG_QUESTION:
						others.append(String(TOPICS.get(k, k)))
				if not others.is_empty():
					lines.append("Worth asking %s about: %s." % [patient.short_name(), ", ".join(others)])
			"otoscopy":
				if not done.has(&"otoscopy"):
					slips += 1
					rows.append({"tool": "otoscopy", "text": "Look in the ears", "state": "miss"})
					lines.append("Always look in the ears first. Wax or a hole can change the whole chart.")
				elif tested_before_look:
					slips += 1
					rows.append({"tool": "otoscopy", "text": "Look in the ears (but only after a test began)", "state": "slip"})
					lines.append("Look before any test, bone too: what you see explains the chart.")
				else:
					rows.append({"tool": "otoscopy", "text": "Look in the ears", "state": "ok"})
			"tymp":
				if done.has(&"tymp"):
					rows.append({"tool": "tymp", "text": "Tympanometer", "state": "ok"})
				else:
					slips += 1
					rows.append({"tool": "tymp", "text": "Tympanometer", "state": "miss"})
					lines.append("This case needed the tympanometer: it shows how each eardrum moves.")
			"air":
				if not done.has(&"air"):
					slips += 1
					rows.append({"tool": "air", "text": "Air tones, both ears", "state": "miss"})
					lines.append("No air tones, no chart! Air conduction is the backbone of every visit.")
				elif _wrong_first(air_first, _better_ear_truth()):
					slips += 1
					rows.append({"tool": "air", "text": "Air tones (the poorer ear went first)", "state": "slip"})
					lines.append("Start air with the better ear. Ask which ear is better, then begin there.")
				else:
					rows.append({"tool": "air", "text": "Air tones, both ears", "state": "ok"})
			"bone":
				if not done.has(&"bone") and not _any_bone():
					slips += 1
					rows.append({"tool": "bone", "text": "Bone conduction", "state": "miss"})
					lines.append("Air was poorer than 25 dB, so bone was needed to tell what kind of loss.")
				elif bone_side != "" and _wrong_first(bone_side, _better_ear_truth()):
					slips += 1
					rows.append({"tool": "bone", "text": "Bone conduction (on the poorer side first)", "state": "slip"})
					lines.append("Bone goes on the better ear first.")
				else:
					rows.append({"tool": "bone", "text": "Bone conduction", "state": "ok"})
			"bc_masked", "ac_masked":
				var what := "bone" if id == "bc_masked" else "air"
				var text := "Masked %s, %s ear" % [what, ear]
				if FsRules.step_done(step, done, results):
					rows.append({"tool": "masking", "text": text, "state": "ok"})
				else:
					slips += 1
					rows.append({"tool": "masking", "text": text, "state": "miss"})
					if id == "bc_masked":
						lines.append("The %s ear's air sat 10 dB or more above bone. Masked bone shows the truth." % ear)
					else:
						lines.append("Loud air tones in the %s ear can cross the head. Masked air was needed." % ear)
	# extras: never slips, but say why they were not needed
	if done.has(&"tymp") and not needed.has("tymp:"):
		rows.append({"tool": "tymp", "text": "Tympanometer (extra: both eardrums were fine)", "state": "extra"})
	if done.has(&"bone") and not needed.has("bone:"):
		rows.append({"tool": "bone", "text": "Bone conduction (extra: all air at 25 dB or better)", "state": "extra"})
	for run: String in masked_runs:
		if not needed.has(run):
			var parts := run.split(":")
			rows.append({"tool": "masking", "text": "Masked %s, %s ear (extra: nothing to mask)" % ["bone" if parts[0] == "bc_masked" else "air", parts[1]], "state": "extra"})
	return {"rows": rows, "lines": lines, "slips": slips, "keys_missed": keys_missed}


func _wrong_first(first: String, better: String) -> bool:
	return first != "" and better != "" and first != better


func _any_bone() -> bool:
	return FsRules.bone_done(results)


func _debrief() -> void:
	_phase(&"freestyle_debrief")
	var rep := workup_report()
	Game.record_medal("fs_chat", FsRules.chat_medal(rep["keys_missed"]))
	Game.record_medal("fs_workup", FsRules.medal_for_slips(int(rep["slips"])))
	Game.set_visit_flag("freestyle_slips", int(rep["slips"]))
	var rows: Array[Dictionary] = []
	rows.assign(rep["rows"])
	debrief_card.call("show_rows", "%s'S WORKUP: WHAT A PRO WOULD RUN" % patient.short_name().to_upper(), rows)
	_shot("debrief", 0.5)
	clinic.call("hoot_emote", &"nod")
	var lines: Array = rep["lines"]
	if lines.is_empty():
		await _say("Hoot", TEXTBOOK_LINE)
	else:
		for l: Variant in lines.slice(0, 4):
			await _say("Hoot", String(l))
	await debrief_card.call("hide_card")
	await _play(case_data["debrief"])
	for l: String in debrief_extras():
		await _say("Hoot", l)


## Hoot's lines after the case's own debrief: a Carhart notch the chart shows on an ear whose truth
## has one, with a middle-ear part (FS-03), and the word tests every FIT still needs (FS-13). Public
## and pure, for the tests.
func debrief_extras() -> Array[String]:
	var out: Array[String] = []
	for ear: String in ClinicRules.EARS:
		var shown := bool(((results.get("ears", {}) as Dictionary).get(ear, {}) as Dictionary).get("carhart_notch", false))
		var stiff := FsRules.truth_type(patient, ear) in [&"conductive", &"mixed"]
		if shown and stiff and ClinicRules.has_carhart_notch(FsRules.truth_bone(patient, ear)):
			out.append(CARHART_LINE % ear)
	if StringName(String(case_data.get("decision", ""))) == &"fit":
		out.append(WORDS_LINE)
	return out


# ---------------------------------------------------------------- 6. goodbye and the paper

func _goodbye() -> void:
	clipboard.visible = false
	await clinic.call("focus_camera", &"desk", 0.5)
	await _play(case_data["goodbye"])
	if props != null:
		props.call("hang_up")
	clinic.call("focus_camera", &"door", 1.6)
	_shot("goodbye", 1.6)
	await clinic.call("walk_out")


## The paper's score: MEDAL_WEIGHT from the four medals, the rest from Game.finish_visit's score.
static func freestyle_score(visit_score: float, medals: Dictionary) -> float:
	var total := 0.0
	for pair: Array in MEDAL_BEATS:
		total += float(MEDAL_VALUES.get(String(medals.get(pair[0], "")), 0.0))
	var medal_part := total / MEDAL_BEATS.size()
	return clampf(100.0 * (MEDAL_WEIGHT * medal_part + (1.0 - MEDAL_WEIGHT) * visit_score / 100.0), 0.0, 100.0)


func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	var score := freestyle_score(float(summary.get("score", 0.0)), summary.get("medals", {}))
	var grade := ClinicRules.grade_for_score(score)
	summary["visit_score"] = summary.get("score", 0.0)
	summary["score"] = score
	summary["grade"] = grade
	summary["freestyle_case"] = case_id
	var paper_data: Dictionary = case_data.get("paper", {})
	summary["headlines"] = paper_data.get("headlines", {})
	summary["subheads"] = paper_data.get("subheads", {})
	summary["medal_beats"] = MEDAL_BEATS
	summary["next_chapter_id"] = ""
	summary["first_clear"] = false
	summary["continue_text"] = "Waiting room"
	summary["continue_scene"] = WAITING_ROOM
	_record_best(String(case_data["patient_id"]), score, grade)
	Events.level_finished.emit(summary)
	var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
	add_child(paper)
	var next: Variant = await paper.call("show_summary", summary)
	if String(next) == "again":
		Events.goto_scene.emit(LEVEL_SCENE)
	else:
		Events.goto_scene.emit(WAITING_ROOM)


## The best freestyle grade per walk-in, for the waiting-room card (inside the save's patient record).
static func _record_best(pid: String, score: float, grade: String) -> void:
	var pats: Dictionary = Game.progress.get("patients", {})
	var rec: Dictionary = pats.get(pid, {})
	if score >= float(rec.get("fs_best_score", -1.0)):
		rec["fs_best_score"] = score
		rec["fs_best_grade"] = grade
	pats[pid] = rec
	Game.save_game()
