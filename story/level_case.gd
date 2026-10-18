extends Node
## LevelCase (cases): one runner for every case file (docs/CASES.md, CONTRACTS.md §11). It reads the
## case for the current chapter (Game.CHAPTERS "case" key) from res://story/cases/<case_id>.json and
## plays it: the patient's story and clues, a look in the ear, the tympanometer, the case's test plan
## (plus whatever masked tests the rules ask for), the chart, the shape question (the pattern comes
## alive once the player names it), then the call: FIT / REFER / DOCTOR TODAY, and the clue card that
## proves it. Every choice is shuffled with Game.rng (seeded by --seed, so autoplay is reproducible).
## Same contracts as Days 1-2: every blocking beat emits Events.awaiting_input with a solver
## (dialogue, choice, the AudiOtron's beats, results_continue).
##   world:  res://world/clinic.tscn with patient_id + patient_spec (the case's look and extras)
##   ui:     res://ui/audiometer/audiometer_screen.tscn start_test(patient, ear, coached, plan)
##   global: Game (visit, medals, flags), Events (phases, awaiting_input), Hoot
## Which case: the current chapter's "case"; else --case=<id>; else the first registered case.

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const CaseData := preload("res://story/case_data.gd")
const CaseBoard := preload("res://story/games/case_board.gd")
const CaseTymp := preload("res://story/games/case_tymp.gd")
const CaseClock := preload("res://story/games/case_clock.gd")
const CaseProps := preload("res://story/games/case_props.gd")
const Voice := preload("res://story/voice.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_case.tscn"

const STEPS: Array[StringName] = [&"chat", &"peek", &"tymp", &"beeps", &"reveal", &"pattern", &"call"]
const STEP_LABELS: Dictionary = {
	&"chat": "Chat", &"peek": "Peek", &"tymp": "Tymp", &"beeps": "Beeps", &"reveal": "Reveal",
	&"pattern": "Pattern", &"call": "The call",
}
## The Daily Decibel's medal row for every case.
const MEDAL_BEATS: Array = [["history", "Chat"], ["tymp", "Tymp"], ["evidence", "Pattern"], ["decision", "Call"]]
const TIP_OPTIONS: Array[String] = ["Small tip", "Medium tip", "Large tip"]
## The tympanogram types the quiz offers (plus any other type the case uses).
const TYMP_QUIZ: Array[StringName] = [&"A", &"B", &"C"]
const TYPE_ANSWERS: Dictionary = {&"sensorineural": 0, &"conductive": 1, &"mixed": 2}
## Unmasked bone reads the better cochlea, so it can stand in for an ear with no bone test of its own
## when it sits within this many dB of that ear's air at every bone frequency (no gap is possible).
const BORROW_BONE_DB := 10
## Hoot's one-time briefing, the first time a player opens any case.
const BRIEFING := "Case Files! Gather clues, then stamp it: FIT, REFER, or DOCTOR TODAY."

var case_id := ""
var case_data: Dictionary = {}
var speaker := "Patient"
var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var screen: CanvasLayer
var results: Dictionary = {}
var clock_widget: Control
var props: Control
## Every clue the player has gathered, for the case file: {tag, text, kind, src}.
var clues: Array[Dictionary] = []
var _walk_done := true


## The case this level should play.
static func pick_case_id() -> String:
	var cid := CaseData.case_for_chapter(Game.current_chapter_id)
	if cid == "":
		cid = Game.cli_value("case", "")
	if cid == "":
		var ids := CaseData.chapter_case_ids()
		cid = ids[0] if not ids.is_empty() else "noise_notch"
	return cid


func _ready() -> void:
	case_id = pick_case_id()
	case_data = CaseData.load_case(case_id)
	var problems := CaseData.validate(case_data) if not case_data.is_empty() else PackedStringArray(["no case file"])
	if not problems.is_empty():
		push_error("LevelCase %s: %s" % [case_id, "; ".join(problems)])
		if case_data.is_empty():
			Events.goto_scene.emit.call_deferred(TITLE_SCENE)
			return
	speaker = String(case_data["speaker"])
	if case_data.get("voice", null) is Dictionary:
		Voice.register(speaker, case_data["voice"])
	var voices: Dictionary = case_data.get("voices", {})
	for who: String in voices:
		if (voices[who] as Dictionary).get("voice", null) is Dictionary:
			Voice.register(who, (voices[who] as Dictionary)["voice"])
	var pid := String(case_data["patient_id"])
	Game.begin_visit(pid)
	Game.set_visit_flag("case_id", case_id)
	patient = Game.load_patient(pid) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", pid)
	clinic.set("patient_spec", CaseData.bean_spec(case_data))
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, String(case_data["case_title"]))
	dialogue = DialogueBox.new()
	add_child(dialogue)
	if case_data.has("sudden_clock"):
		clock_widget = CaseClock.new()
		clock_widget.call("setup", float((case_data["sudden_clock"] as Dictionary).get("onset_h", 24)))
		hud.call("add_game", clock_widget)
	Events.level_started.emit(pid)
	_run.call_deferred()


func _phase(p: StringName, info: Dictionary = {}) -> void:
	Events.phase_changed.emit(p, info)


func _say(who: String, text: String) -> void:
	await dialogue.say(who, text)


## A reply from the case file: one line, or a list of lines said in turn.
func _say_all(who: String, reply: Variant) -> void:
	if reply is Array:
		for r: Variant in reply:
			await _say(who, String(r))
	else:
		await _say(who, String(reply))


## 0..n-1 in a Game.rng order (Fisher-Yates), so every choice's layout is fresh but reproducible.
static func shuffled_order(n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(i)
	for i in range(n - 1, 0, -1):
		var j := Game.rng.randi_range(0, i)
		var t := out[i]
		out[i] = out[j]
		out[j] = t
	return out


## True the first time a player opens any case (no case chapter finished yet).
static func first_case() -> bool:
	for cid: Variant in Game.progress.get("chapters_done", []):
		if String(Game.chapter(String(cid)).get("case", "")) != "":
			return false
	return true


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _react(kind: StringName, data: Dictionary = {}) -> void:
	Events.patient_reaction.emit(kind, data)


func _shot(shot_name: String, delay: float = 0.0) -> void:
	if not Game.cli.has("shots"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	Events.screenshot_requested.emit("case_%s_%s" % [case_id, shot_name])


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
			if d.has("choose"):
				await _choose(d["choose"])


## A counselling choice in a script: {"prompt", "options": [[text, points, Hoot's line]]}. Shuffled;
## Hoot answers each pick, and it repeats until the best option is picked. No medal.
func _choose(spec: Dictionary) -> void:
	var raw: Array = spec.get("options", [])
	if raw.is_empty():
		return
	var order := shuffled_order(raw.size())
	var best_pts := -1
	for o: Variant in raw:
		best_pts = maxi(best_pts, int((o as Array)[1]))
	while not order.is_empty():
		var opts: Array[String] = []
		var best := 0
		for k in order.size():
			var o: Array = raw[order[k]]
			opts.append(String(o[0]))
			if int(o[1]) == best_pts:
				best = k
		var ch: int = await dialogue.choose(String(spec.get("prompt", "Pick one:")), opts, best)
		var pick: Array = raw[order[ch]]
		var good := int(pick[1]) == best_pts
		if good:
			_react(&"cheer")
		await _say("Hoot", String(pick[2]) if pick.size() > 2 else "")
		if good:
			return
		order.remove_at(ch)


## The payoff actions.
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
			if what != "phone":
				_shot(what, 0.6)
			await props.call("play", what)


## Add a clue to the case file (a later clue with the same tag replaces the earlier one).
func _add_clue(tag: String, text: String, kind: String, src: String) -> void:
	if text == "":
		return
	var entry := {"tag": tag, "text": text, "kind": kind, "src": src}
	for i in clues.size():
		if tag != "" and String(clues[i]["tag"]) == tag:
			clues[i] = entry
			return
	clues.append(entry)


func _run() -> void:
	await _intro()
	await _history()
	await _otoscopy()
	await _tymp()
	await _instructions()
	await _audiometry()
	var board: Control = await _reveal()
	await _evidence(board)
	await _decision(board)
	await _payoff(board)
	await _results()


# ---------------------------------------------------------------- 1. intro

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"chat")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	_react(&"wave")
	_shot("intro", 0.3)
	if first_case():
		clinic.call("hoot_emote", &"wing_up")
		await _say("Hoot", BRIEFING)
	await _play(case_data["intro"])
	for cl: Variant in case_data.get("always_clues", []):
		var d: Dictionary = cl
		hud.call("add_clue", String(d["text"]), String(d.get("kind", "clue")))
		_add_clue(String(d.get("tag", "")), String(d["text"]), String(d.get("kind", "clue")), "note")


# ---------------------------------------------------------------- 2. case history

func _history() -> void:
	_phase(&"history")
	var rf: Dictionary = case_data["red_flags"]
	var points := 0
	var tags: Dictionary = {}
	for rd: Variant in case_data["history"]:
		var r: Dictionary = rd
		var raw: Array = r["options"]
		var order := shuffled_order(raw.size())
		var opts: Array[String] = []
		var best := 0
		var best_pts := -1
		for k in order.size():
			var oa: Array = raw[order[k]]
			opts.append(String(oa[0]))
			if int(oa[1]) > best_pts:
				best_pts = int(oa[1])
				best = k
		var ch: int = await dialogue.choose(String(r.get("prompt", "Ask a question:")), opts, best)
		var pick: Array = raw[order[ch]]
		var pts := int(pick[1])
		var tag := String(pick[4])
		points += pts
		if tag != "":
			tags[tag] = true
		_react(&"cheer" if pts == 0 else &"nod")
		var who := String(pick[6]) if pick.size() > 6 and String(pick[6]) != "" else speaker
		await _say_all(who, pick[2])
		if String(pick[3]) != "":
			hud.call("add_clue", String(pick[3]))
			_add_clue(tag, String(pick[3]), "clue", "history")
		if pts == 0:
			clinic.call("hoot_emote", &"facepalm")
			await _say("Hoot", String(case_data.get("joke_line", "Fun, but not a clue. Ask about the hearing!")))
		elif pick.size() > 5 and String(pick[5]) != "":
			await _say("Hoot", String(pick[5]))
	# the red-flag sweep always happens
	var asked := tags.has(String(rf["tag"]))
	if not asked:
		await _say("Hoot", String(rf["ask_line"]))
		await _say_all(speaker, rf["answer"])
	clinic.call("hoot_emote", &"nod")
	hud.call("add_clue", String(rf["card"]), String(rf.get("card_kind", "clue")))
	# the case-file card can differ from the HUD summary: Dash's "No pain or drainage" is not itself a flag
	_add_clue(String(rf["tag"]), String(rf["clue"]), String(rf.get("clue_kind", rf.get("card_kind", "clue"))), "flag")
	for ex: Variant in rf.get("extra_clues", []):
		var exd: Dictionary = ex
		_add_clue(String(exd.get("tag", "")), String(exd["text"]), String(exd.get("kind", "clue")), "flag")
	Game.record_medal("history", "gold" if points >= 4 else ("silver" if points >= 2 else "bronze"))
	Game.set_visit_flag("asked_red_flags", asked)
	await _play(case_data.get("after_history", []))
	hud.call("complete_step", &"chat")


# ---------------------------------------------------------------- 3. otoscopy (a quick look)

func _otoscopy() -> void:
	_phase(&"otoscopy")
	hud.call("set_step", &"peek")
	var oto: Dictionary = case_data["otoscopy"]
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var g := Otoscopy.new()
	hud.call("add_game", g)
	await g.show_clear(String(oto.get("ear", "right")), String(oto.get("caption", "")))
	_shot("otoscopy")
	await _play(oto.get("lines", []))
	hud.call("add_clue", String(oto["clue"]))
	_add_clue(String(oto["tag"]), String(oto["clue"]), "clue", "look")
	g.queue_free()
	clinic.call("focus_camera", &"desk", 0.6)
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. the tympanometer

func _tymp() -> void:
	_phase(&"tymp")
	hud.call("set_step", &"tymp")
	var ty: Dictionary = case_data["tymp"]
	clinic.call("focus_camera", &"ear_right", 0.8)
	var g := CaseTymp.new()
	hud.call("add_game", g)
	await _say("Hoot", "The Tymp-O-Matic! It checks how well the eardrum moves. First, a snug ear tip.")
	var right_tip := StringName(String(ty["tip"]))
	g.call("show_tips", right_tip)
	var sizes: Array[StringName] = CaseRules.TIP_SIZES.duplicate()
	var opts: Array[String] = TIP_OPTIONS.duplicate()
	var slips := 0
	var tip_tries := 0
	while true:
		tip_tries += 1
		var canal := String(ty.get("canal", ""))
		var tprompt := "Which ear tip fits %s's %s canal?" % [speaker, canal] if canal != "" \
			else "Which ear tip fits %s's ear canal?" % speaker
		var ch: int = await dialogue.choose(tprompt, opts, sizes.find(right_tip))
		var size := sizes[ch]
		var ok: bool = await g.call("try_tip", size)
		if ok:
			break
		slips += 1
		if CaseRules.TIP_SIZES.find(size) < CaseRules.TIP_SIZES.find(right_tip):
			await _say("Hoot", "Too small: hisss, it leaks! No seal, no reading. Try a bigger one.")
		else:
			_react(&"wince")
			await _say("Hoot", "Too big: it won't go in! Never force a tip. Try a smaller one.")
		sizes.remove_at(ch)
		opts.remove_at(ch)
	_react(&"nod")
	await _say("Hoot", "Sealed! Now it sweeps the air pressure and watches the eardrum wobble.")
	_shot("tymp_sweep", 1.0)
	await g.call("measure", "right", ty["right"])
	await g.call("measure", "left", ty["left"])
	_shot("tymp_curves")
	var type_r := StringName(String((ty["right"] as Dictionary)["type"]))
	var type_l := StringName(String((ty["left"] as Dictionary)["type"]))
	if ty.get("quiz", null) is Dictionary:
		# the patient's own worry, answered by the tymp ("Her ear feels full. Fluid?")
		slips += await _tymp_quiz(ty["quiz"])
		for ear: String in ["right", "left"]:
			g.call("reveal_type", ear)
	else:
		slips += await _tymp_type_quiz(g, type_r, type_l)
	hud.call("add_clue", String(ty["clue"]))
	_add_clue(String(ty["tag"]), String(ty["clue"]), "clue", "tymp")
	await _play(ty.get("after", []))
	Game.record_medal("tymp", "gold" if slips == 0 else ("silver" if slips == 1 else "bronze"))
	Game.set_visit_flag("tymp_tip_tries", tip_tries)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	await t.finished
	g.queue_free()
	hud.call("complete_step", &"tymp")


## The case's own tymp question: {"prompt", "options": [[text, right, Hoot's line when wrong]]}.
## Returns the slips.
func _tymp_quiz(q: Dictionary) -> int:
	var raw: Array = q.get("options", [])
	var order := shuffled_order(raw.size())
	var slips := 0
	while not order.is_empty():
		var opts: Array[String] = []
		var best := 0
		for k in order.size():
			var o: Array = raw[order[k]]
			opts.append(String(o[0]))
			if bool(o[1]):
				best = k
		var ch: int = await dialogue.choose(String(q.get("prompt", "What does the tymp show?")), opts, best)
		var pick: Array = raw[order[ch]]
		if bool(pick[1]):
			break
		slips += 1
		var why := String(pick[2]) if pick.size() > 2 else ""
		await _say("Hoot", why if why != "" else "Look where the peak sits, and how tall.")
		order.remove_at(ch)
	return slips


## The plain "what type is it?" quiz (both ears at once when they match). Returns the slips.
func _tymp_type_quiz(g: Control, type_r: StringName, type_l: StringName) -> int:
	var slips := 0
	var asks: Array = [["both", type_r]] if type_r == type_l else [["right", type_r], ["left", type_l]]
	for ask: Array in asks:
		var pool: Array[StringName] = TYMP_QUIZ.duplicate()
		if not pool.has(ask[1]):
			pool.append(ask[1])
		var types: Array[StringName] = []
		for k: int in shuffled_order(pool.size()):
			types.append(pool[k])
		var topts: Array[String] = []
		for t: StringName in types:
			topts.append(CaseRules.TYMP_TITLES[t])
		var prompt := "What type are both of %s's tympanograms?" % speaker if String(ask[0]) == "both" \
			else "What type is the %s ear's tympanogram?" % String(ask[0]).to_upper()
		while true:
			var ti: int = await dialogue.choose(prompt, topts, types.find(ask[1]))
			if types[ti] == ask[1]:
				break
			slips += 1
			await _say("Hoot", "Type %s would be %s. Look where the peak sits, and how tall." % [types[ti], CaseRules.TYMP_SHAPES[types[ti]]])
			types.remove_at(ti)
			topts.remove_at(ti)
		for ear: String in (["right", "left"] if String(ask[0]) == "both" else [String(ask[0])]):
			g.call("reveal_type", ear)
	return slips


# ---------------------------------------------------------------- 5. instructions + earphones

func _instructions() -> void:
	_phase(&"instructions")
	hud.call("set_step", &"beeps")
	clinic.call("focus_camera", &"desk", 0.8)
	await _play(case_data["instructions"])
	Game.set_visit_flag("instructed", true)
	clinic.call("focus_camera", &"booth", 1.2)
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.8)
	clinic.call("put_on_earphones", true)
	await _wait(0.6)


# ---------------------------------------------------------------- 6. audiometry: the plan, then masking

func _open_screen() -> Camera3D:
	if screen == null:
		screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(screen)
	screen.visible = true
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	return cam


func _close_screen(cam: Camera3D) -> void:
	if screen != null:
		screen.visible = false
	cam.current = true


func _air_transducer() -> StringName:
	return &"inserts" if Game.has_upgrade("insert_earphones") else &"phones"


func _test(ear: String, plan: Dictionary) -> Dictionary:
	plan["air_transducer"] = _air_transducer()
	_phase(&"audiometry", {"ear": ear, "test": String(plan.get("test", "ac"))})
	# the player's own tests are not coached (they learned on Days 1-2); Hoot's run at once
	screen.call("start_test", patient, ear, false, plan)
	var r: Dictionary = await screen.test_finished
	results = r
	Game.set_audiometry_results(results)
	return r


## Close the screen, say some lines in the clinic, open it again.
func _aside(cam: Camera3D, lines: Variant, shot: StringName = &"face") -> void:
	_close_screen(cam)
	clinic.call("focus_camera", shot, 0.5)
	await _play(lines)
	_open_screen()


func _audiometry() -> void:
	var cam := _open_screen()
	var main_ear := ""
	for p: Variant in case_data["audiometry"]:
		var pd: Dictionary = p
		var ear := String(pd["ear"])
		var plan := {"test": String(pd["test"]), "hoot_turn_after": int(pd.get("hoot_turn_after", 0))}
		if pd.has("intro"):
			plan["intro"] = String(pd["intro"])
		if plan["test"] == "bc":
			main_ear = ear
			plan["bc_freqs"] = ClinicRules.BC_REQUIRED
			plan["masking_controls"] = true
			_close_screen(cam)
			clinic.call("focus_camera", StringName("ear_" + ear), 0.6)
			clinic.call("put_on_bone_oscillator", ear)
			await _wait(0.5)
			await _play(pd.get("before", []))
			_open_screen()
		elif pd.has("before"):
			await _aside(cam, pd["before"])
		await _test(ear, plan)
	if main_ear != "":
		var other := "left" if main_ear == "right" else "right"
		if not ClinicRules.masked_freqs_needed(results, main_ear, &"bc_masked").is_empty():
			_close_screen(cam)
			clinic.call("focus_camera", &"face", 0.5)
			clinic.call("put_on_masking_phone", other)
			await _say("Hoot", "Bone buzzes both cochleas. I'll keep the %s ear busy with noise." % other)
			_open_screen()
			await _test(main_ear, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 0,
				"intro": "Masked bone at Hoot speed: the shhh goes in the %s ear." % other})
		if not ClinicRules.masked_freqs_needed(results, main_ear, &"ac_masked", _air_transducer()).is_empty():
			_close_screen(cam)
			clinic.call("take_off_bone_oscillator")
			clinic.call("put_on_earphones", true)
			await _say("Hoot", "Loud air tones can cross the head too. Masked air, Hoot speed!")
			_open_screen()
			await _test(main_ear, {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 0,
				"intro": "Masked air: same plateau dance, noise in the %s ear." % other})
	_borrow_bone()
	screen.queue_free()
	screen = null
	cam.current = true
	clinic.call("take_off_bone_oscillator")
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"face", 0.4)
	hud.call("complete_step", &"beeps")
	await _play(case_data.get("after_audiometry", []))


## An ear with air but no bone test of its own: the other ear's UNMASKED bone reads the better cochlea,
## so this ear's bone can be no better than it. When that bone sits within BORROW_BONE_DB of this
## ear's air at every bone frequency, no gap is possible and the ear is typed from it (Rocco's and
## Ginger's left ears). Otherwise the ear stays "unknown" (it would need its own bone test).
func _borrow_bone() -> void:
	var ears: Dictionary = results.get("ears", {})
	for ear: String in ["right", "left"]:
		var e: Dictionary = ears.get(ear, {})
		if e.is_empty() or e.get("hearing_type", &"unknown") != &"unknown":
			continue
		var other := "left" if ear == "right" else "right"
		var bone := ClinicRules.sheet_thresholds(results, other, &"bc")
		var air := ClinicRules.best_thresholds(results, ear, false)
		if bone.is_empty() or air.is_empty():
			continue
		var close := true
		for f: int in bone:
			if air.has(f) and int(air[f]) - int(bone[f]) > BORROW_BONE_DB:
				close = false
		var kind := ClinicRules.hearing_type(air, bone)
		if close and (kind == &"sensorineural" or kind == &"normal"):
			e["hearing_type"] = kind
			e["bone_from"] = other
	Game.set_audiometry_results(results)


# ---------------------------------------------------------------- 7. reveal: the chart

func _reveal() -> Control:
	_phase(&"reveal")
	hud.call("set_step", &"reveal")
	var b := CaseBoard.new()
	b.setup(case_data)
	hud.call("add_game", b)
	if clock_widget != null:
		clock_widget.move_to_front()
	clinic.call("focus_camera", &"desk", 0.0)
	_walk_done = false
	var go := func() -> void:
		await clinic.call("walk_to", &"desk", 2.4)
		_walk_done = true
	go.call()
	await b.run_reveal(results)
	_shot("reveal")
	await _play((case_data["reveal"] as Dictionary).get("ask", [["Hoot", "Here's the chart, trainee. What shape do you see?"]]))
	hud.call("complete_step", &"reveal")
	return b


# ---------------------------------------------------------------- 8. evidence: name it, then it comes alive

## The ear the case is about ("both" = the right ear stands in for the pair).
func _case_ear() -> String:
	var ear := String((case_data["reveal"] as Dictionary).get("ear", "right"))
	return "right" if ear == "both" else ear


func _evidence(b: Control) -> void:
	_phase(&"evidence")
	hud.call("set_step", &"pattern")
	var ev: Dictionary = case_data["evidence"]
	var all: Array[String] = []
	for o: Variant in ev["options"]:
		all.append(String(o))
	var answer := int(ev["answer"])
	var ear_info: Dictionary = (results.get("ears", {}) as Dictionary).get(_case_ear(), {})
	var kind: StringName = ear_info.get("hearing_type", &"sensorineural")
	if ev.has("answer_from_type"):
		var info: Dictionary = (results.get("ears", {}) as Dictionary).get(String(ev["answer_from_type"]), {})
		answer = int(TYPE_ANSWERS.get(info.get("hearing_type", &""), answer))
	var answer_text := all[answer]
	var wrong: Array = ev.get("wrong", [])
	b.call("set_compact", true)
	var opts: Array[String] = []
	for k: int in shuffled_order(all.size()):
		opts.append(all[k])
	var tries := 0
	while true:
		tries += 1
		var ch: int = await dialogue.choose(String(ev["prompt"]), opts, opts.find(answer_text))
		if opts[ch] == answer_text:
			break
		var oi := all.find(opts[ch])
		var why := String(wrong[oi]) if oi < wrong.size() else ""
		await _say("Hoot", why if why != "" else "Not quite. Look at the chart again!")
		opts.remove_at(ch)
	Game.record_medal("evidence", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	Sfx.play(&"ding", 1.2, -6.0)
	# the reward: the pattern comes alive, with its title
	await b.show_pattern()
	if String((case_data["reveal"] as Dictionary).get("pattern", "")) == "flat_one" and clock_widget != null:
		clock_widget.move_to_front()
		clock_widget.call("ring")
	_shot("pattern", 0.3)
	await _play((case_data["reveal"] as Dictionary).get("lines", []))
	if kind != &"unknown" and kind != &"normal":
		b.call("show_type", String(ClinicRules.HEARING_TYPE_TITLES.get(kind, "Sensorineural loss")))
	if String(ev.get("right", "")) != "":
		await _say("Hoot", String(ev["right"]))
	_add_findings()
	hud.call("complete_step", &"pattern")


## The reveal's cards for the case file. A finding with "when": "symmetric" / "asymmetric" only
## appears when the measured air says so (the truth table when an ear has no air).
func _add_findings() -> void:
	var right := ClinicRules.best_thresholds(results, "right", false)
	var left := ClinicRules.best_thresholds(results, "left", false)
	if right.is_empty() or left.is_empty():
		right = CaseData.truth(patient, "right")
		left = CaseData.truth(patient, "left")
	var asym := CaseRules.is_asymmetric(right, left)
	for f: Variant in case_data["findings"]:
		var fd: Dictionary = f
		match String(fd.get("when", "")):
			"symmetric":
				if asym:
					continue
			"asymmetric":
				if not asym:
					continue
		_add_clue(String(fd["tag"]), String(fd["text"]), "clue", "test")


# ---------------------------------------------------------------- 9. the call: stamp it, then prove it

## The clue cards for the case file: at most CaseBoard.MAX_CARDS, then shuffled. The proof cards
## (clue_pick "answers") and the deliberate red herrings ("decoys") always stay. Others go first if
## the case never mentions them (no wrong line), then by source: history, notes, the exam, the chart.
const DROP_ORDER: Dictionary = {"history": 1, "note": 2, "look": 3, "tymp": 3, "flag": 4, "test": 4}


func _board_clues() -> Array[Dictionary]:
	var cp: Dictionary = case_data["clue_pick"]
	var keep: Array = (cp.get("answers", []) as Array) + (cp.get("decoys", []) as Array)
	var wrong_lines: Dictionary = cp.get("wrong_lines", {})
	var out: Array[Dictionary] = clues.duplicate()
	while out.size() > CaseBoard.MAX_CARDS:
		var drop := -1
		var drop_rank := 99
		for i in out.size():
			var tag := String(out[i]["tag"])
			if keep.has(tag):
				continue
			var rank: int = 0 if not wrong_lines.has(tag) else int(DROP_ORDER.get(String(out[i]["src"]), 5))
			if rank <= drop_rank:
				drop_rank = rank
				drop = i
		if drop < 0:
			drop = out.size() - 1
		out.remove_at(drop)
	var shuffled: Array[Dictionary] = []
	for k: int in shuffled_order(out.size()):
		shuffled.append(out[k])
	return shuffled


func _decision(b: Control) -> void:
	_phase(&"decision")
	hud.call("set_step", &"call")
	await b.call("open_file", _board_clues())
	_shot("case_file", 0.2)
	var dec: Dictionary = case_data["decision"]
	var answer := StringName(String(dec["answer"]))
	var lines: Dictionary = dec["lines"]
	var slips := 0
	var tries := 0
	while true:
		tries += 1
		var i: int = await b.call("choose_stamp", String(dec["prompt"]), CaseRules.DECISIONS.find(answer))
		var d: StringName = CaseRules.DECISIONS[i]
		var right := d == answer
		if tries == 1:
			Game.set_visit_flag("decision_first", String(d))
		await b.call("slam", d, right)
		if right:
			_shot("stamp", 0.1)
			_react(&"cheer")
		await _say("Hoot", String(lines.get(String(d), "")))
		if right:
			break
		slips += 1
	Game.set_visit_flag("decision", String(answer))
	Game.set_visit_flag("decision_tries", tries)
	var cp: Dictionary = case_data["clue_pick"]
	var answers: Array = cp.get("answers", [])
	var wrong_lines: Dictionary = cp.get("wrong_lines", {})
	var right_lines: Dictionary = cp.get("right_lines", {})
	var cards: Array = b.get("clues")
	var best := 0
	for k in cards.size():
		if answers.has(String((cards[k] as Dictionary)["tag"])):
			best = k
			break
	var clue_tries := 0
	while true:
		clue_tries += 1
		var j: int = await b.call("choose_clue", String(cp["prompt"]), best)
		var tag := String((cards[j] as Dictionary)["tag"])
		var ok := answers.has(tag)
		b.call("mark_card", j, ok)
		if ok:
			_shot("exhibit", 0.2)
			await _say("Hoot", String(right_lines.get(tag, cp["right_line"])))
			break
		slips += 1
		await _say("Hoot", String(wrong_lines.get(tag, cp["wrong_line"])))
	Game.set_visit_flag("clue_tries", clue_tries)
	Game.record_medal("decision", "gold" if slips == 0 else ("silver" if slips == 1 else "bronze"))
	hud.call("complete_step", &"call")


# ---------------------------------------------------------------- 10. payoff

func _payoff(b: Control) -> void:
	await b.call("fade_out")
	b.queue_free()
	while not _walk_done:   # the patient strolled to the desk during the reveal
		await _wait(0.2)
	await clinic.call("focus_camera", &"desk", 0.5)
	await _play(case_data["payoff"])
	if props != null:
		props.call("hang_up")
	clinic.call("focus_camera", &"door", 1.6)
	_shot("goodbye", 1.6)
	await clinic.call("walk_out")


# ---------------------------------------------------------------- 11. results

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	var paper_data: Dictionary = case_data.get("paper", {})
	summary["case_id"] = case_id
	summary["headlines"] = paper_data.get("headlines", {})
	summary["subheads"] = paper_data.get("subheads", {})
	summary["medal_beats"] = MEDAL_BEATS
	Events.level_finished.emit(summary)
	var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
	add_child(paper)
	var next: Variant = await paper.call("show_summary", summary)
	match String(next):
		"again":
			Events.goto_scene.emit(LEVEL_SCENE)
		"next":
			if not Game.start_chapter(String(summary.get("next_chapter_id", ""))):
				Events.goto_scene.emit(TITLE_SCENE)
		_:
			Events.goto_scene.emit(TITLE_SCENE)
