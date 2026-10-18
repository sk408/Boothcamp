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
## A case with a "retest" block (Day 10's wax) brings the patient back after treatment: a second,
## unscored visit with a fresh chart over the first one's (_retest).
## Which case: the current chapter's "case"; else --case=<id>; else the first registered case.

const Hud := preload("res://story/hud.gd")
const CaseOtoscopy := preload("res://story/games/case_otoscopy.gd")
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
	&"pattern": "Pattern", &"call": "The call", &"retest": "Retest",
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
## The runner's own lines (case_scripts.py prints them too: keep the two in step).
## After masked bone, when no ear needed masked air (built from the stamps).
const NO_MASKED_AIR := "At these levels, air tones can't cross the head. Only bone needed masking today!"
## When a conditional finding reads differently on the chart than in the story (wandering stamps).
const MISMATCH := "Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!"
## The retest's chart when its measured type is not the story's.
const RETEST_NEUTRAL := "Much better with the plug out. A few stamps wandered: in clinic, we'd recheck those."

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
## Wax fills the canal (the otoscope's "wax" view): air goes through headphones, never a foam insert.
var _canal_blocked := false


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
		# a broken case never half-plays: back to the title
		push_error("LevelCase %s: %s" % [case_id, "; ".join(problems)])
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
	var steps: Array[StringName] = STEPS.duplicate()
	if case_data.has("retest"):
		steps.append(&"retest")
	hud.call("set_steps", steps, STEP_LABELS, String(case_data["case_title"]))
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
		"letter", "phone", "boat", "wax_jar", "plane":
			if what != "phone":
				_shot(what, 0.6)
			await _props().call("play", what)


## The payoff props layer, made on first use.
func _props() -> Control:
	if props == null:
		props = CaseProps.new()
		hud.call("add_game", props)
	return props


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
	await _otoscopy(case_data["otoscopy"])
	await _tymp()
	await _instructions(case_data["instructions"])
	await _audiometry(case_data["audiometry"])
	var board: Control = await _reveal()
	await _evidence(board)
	await _decision(board)
	await _payoff(board)
	if case_data.has("retest"):
		await _retest()
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

## A look in the ear: the case's otoscopy section, or the retest's (first_pass false: no step pill,
## and no card unless the section has a clue). A "wax" view blocks the canal for the air tests.
func _otoscopy(oto: Dictionary, first_pass: bool = true) -> void:
	_phase(&"otoscopy", {} if first_pass else {"retest": true})
	if first_pass:
		hud.call("set_step", &"peek")
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var view := String(oto.get("view", "clear"))
	_canal_blocked = view == "wax"
	var g := CaseOtoscopy.new()
	hud.call("add_game", g)
	await g.show_view(String(oto.get("ear", "right")), view, String(oto.get("caption", "")))
	_shot("otoscopy" if first_pass else "retest_otoscopy")
	await _play(oto.get("lines", []))
	if String(oto.get("clue", "")) != "":
		var kind := String(oto.get("kind", "clue"))
		hud.call("add_clue", String(oto["clue"]), kind)
		_add_clue(String(oto.get("tag", "")), String(oto["clue"]), kind, "look")
	g.queue_free()
	clinic.call("focus_camera", &"desk", 0.6)
	if first_pass:
		hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. the tympanometer

func _tymp() -> void:
	_phase(&"tymp")
	hud.call("set_step", &"tymp")
	var ty: Dictionary = case_data["tymp"]
	clinic.call("focus_camera", _look_shot(), 0.8)
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


## The camera on the ear the otoscope looked in.
func _look_shot() -> StringName:
	return StringName("ear_" + String((case_data["otoscopy"] as Dictionary).get("ear", "right")))


## The retest's tymp: the visit's tip seals at once, both ears sweep, the types show. No quiz, no
## medal. spec: {tip?, right, left, after?}.
func _tymp_recheck(spec: Dictionary) -> void:
	_phase(&"tymp", {"retest": true})
	clinic.call("focus_camera", _look_shot(), 0.8)
	var g := CaseTymp.new()
	hud.call("add_game", g)
	var tip := StringName(String(spec.get("tip", (case_data["tymp"] as Dictionary)["tip"])))
	g.call("show_tips", tip)
	await g.call("try_tip", tip)
	await g.call("measure", "right", spec["right"])
	await g.call("measure", "left", spec["left"])
	for ear: String in ["right", "left"]:
		g.call("reveal_type", ear)
	_shot("retest_tymp", 0.4)
	await _play(spec.get("after", []))
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	await t.finished
	g.queue_free()


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

## The instructions (the case's, or the retest's: first_pass false), then into the booth.
func _instructions(lines: Variant, first_pass: bool = true) -> void:
	_phase(&"instructions", {} if first_pass else {"retest": true})
	if first_pass:
		hud.call("set_step", &"beeps")
	clinic.call("focus_camera", &"desk", 0.8)
	await _play(lines)
	if first_pass:
		Game.set_visit_flag("instructed", true)
	await _seat_with_earphones()


func _seat_with_earphones() -> void:
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


## Headphones, or foam inserts once the upgrade is owned. Never an insert into a canal full of wax.
## The masking rules read the same transducer.
func _air_transducer() -> StringName:
	if _canal_blocked:
		return &"phones"
	return &"inserts" if Game.has_upgrade("insert_earphones") else &"phones"


func _test(ear: String, plan: Dictionary, info: Dictionary = {}) -> Dictionary:
	plan["air_transducer"] = _air_transducer()
	var phase_info := {"ear": ear, "test": String(plan.get("test", "ac"))}
	phase_info.merge(info)
	_phase(&"audiometry", phase_info)
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


## A test step's plan for the AudiOtron: the test, Hoot's turn, an intro that fits, and any PLAN_KEYS
## (Hoot's montage) passed straight through.
func _plan_from(pd: Dictionary) -> Dictionary:
	var plan := {"test": String(pd["test"]), "hoot_turn_after": int(pd.get("hoot_turn_after", 0))}
	# an intro for a Hoot-speed test ("Left at Hoot speed!") only fits when Hoot really runs it:
	# with Quick visit off the player runs everything and the screen says its own line
	if pd.has("intro") and (_quick() or int(plan["hoot_turn_after"]) > 0):
		plan["intro"] = String(pd["intro"])
	for k: String in CaseData.PLAN_KEYS:
		if pd.has(k):
			plan[k] = bool(pd[k])
	return plan


## The case's test plan, then whatever masking the stamps ask for: masked bone on each bone-tested
## ear, then masked air on each air-tested ear. first_pass false: the retest (air only, no masking,
## no case lines, no step pill).
func _audiometry(steps: Array, first_pass: bool = true) -> void:
	var cam := _open_screen()
	var info := {} if first_pass else {"retest": true}
	var bc_ears: Array[String] = []
	var ac_ears: Array[String] = []
	var oscillator_on := ""
	for p: Variant in steps:
		var pd: Dictionary = p
		var ear := String(pd["ear"])
		var plan := _plan_from(pd)
		if plan["test"] == "bc":
			if not bc_ears.has(ear):
				bc_ears.append(ear)
			plan["bc_freqs"] = ClinicRules.BC_REQUIRED
			plan["masking_controls"] = true
			_close_screen(cam)
			clinic.call("focus_camera", StringName("ear_" + ear), 0.6)
			clinic.call("put_on_bone_oscillator", ear)
			oscillator_on = ear
			await _wait(0.5)
			await _play(pd.get("before", []))
			_open_screen()
		else:
			if not ac_ears.has(ear):
				ac_ears.append(ear)
			if pd.has("before"):
				await _aside(cam, pd["before"])
		await _test(ear, plan, info)
	var masked_bone := false
	var masked_air := false
	if first_pass:
		for ear: String in bc_ears:
			if ClinicRules.masked_freqs_needed(results, ear, &"bc_masked").is_empty():
				continue
			var other := "left" if ear == "right" else "right"
			_close_screen(cam)
			if oscillator_on != ear:
				clinic.call("put_on_bone_oscillator", ear)
				oscillator_on = ear
			clinic.call("focus_camera", &"face", 0.5)
			clinic.call("put_on_masking_phone", other)
			await _say("Hoot", ("Bone buzzes both cochleas. I'll keep the %s ear busy with noise." if _quick()
				else "Bone buzzes both cochleas. Your turn: masked bone, noise in the %s ear.") % other)
			_open_screen()
			await _test(ear, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 0,
				"intro": ("Masked bone at Hoot speed: the shhh goes in the %s ear." if _quick()
					else "Masked bone: the shhh goes in the %s ear.") % other})
			masked_bone = true
		for ear: String in ac_ears:
			if ClinicRules.masked_freqs_needed(results, ear, &"ac_masked", _air_transducer()).is_empty():
				continue
			var other := "left" if ear == "right" else "right"
			_close_screen(cam)
			if not masked_air:
				clinic.call("take_off_bone_oscillator")
				oscillator_on = ""
				clinic.call("put_on_earphones", true)
				await _say("Hoot", "Loud air tones can cross the head too. " + ("Masked air, Hoot speed!" if _quick() else "Masked air, your turn!"))
			_open_screen()
			await _test(ear, {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 0,
				"intro": "Masked air: same plateau dance, noise in the %s ear." % other})
			masked_air = true
		_borrow_bone()
	screen.queue_free()
	screen = null
	cam.current = true
	clinic.call("take_off_bone_oscillator")
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"face", 0.4)
	if not first_pass:
		return
	hud.call("complete_step", &"beeps")
	if masked_bone and not masked_air:
		await _say("Hoot", NO_MASKED_AIR)
	# the case's line describes the true chart ("bone sits with the air: no gap"); if the player's
	# stamps left a different type on a bone ear, it would contradict the screen, so say a neutral line
	var agrees := true
	for ear: String in bc_ears:
		var measured: StringName = ((results.get("ears", {}) as Dictionary).get(ear, {}) as Dictionary).get("hearing_type", &"unknown")
		if measured != CaseData.truth_type(patient, ear):
			agrees = false
	if agrees:
		await _play(case_data.get("after_audiometry", []))
	else:
		await _say("Hoot", "Bone's in. Let's lay it over the air and see what it says.")


## Quick visit (the default): Hoot runs the tests the plan gives him. Off: the player runs everything.
## Read when needed, since the pause menu can change it mid-visit.
func _quick() -> bool:
	return screen != null and bool(screen.get("quick_visit"))


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
	_walk_to_desk()
	await b.run_reveal(results)
	_shot("reveal")
	await _play((case_data["reveal"] as Dictionary).get("ask", [["Hoot", "Here's the chart, trainee. What shape do you see?"]]))
	hud.call("complete_step", &"reveal")
	return b


## The patient strolls to the desk while the chart draws (await _until_walked() before using them).
func _walk_to_desk() -> void:
	_walk_done = false
	var go := func() -> void:
		await clinic.call("walk_to", &"desk", 2.4)
		_walk_done = true
	go.call()


func _until_walked() -> void:
	while not _walk_done:
		await _wait(0.2)


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
	# the type badge and an "answer_from_type" question follow the patient's TRUE type, like every
	# authored line around them (a few wandering stamps must not make the game insist on "mixed")
	var kind: StringName = CaseData.truth_type(patient, _case_ear())
	if ev.has("answer_from_type"):
		answer = int(TYPE_ANSWERS.get(CaseData.truth_type(patient, String(ev["answer_from_type"])), answer))
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
	await _add_findings()
	hud.call("complete_step", &"pattern")


## The reveal's cards for the case file. A finding's "when" (finding_shows) is read on the measured
## chart. If any conditional finding reads differently on the truth tables, a few stamps wandered:
## Hoot says so once (MISMATCH), since the case's lines tell the true story.
func _add_findings() -> void:
	var right := ClinicRules.best_thresholds(results, "right", false)
	var left := ClinicRules.best_thresholds(results, "left", false)
	if right.is_empty() or left.is_empty():
		right = CaseData.truth(patient, "right")
		left = CaseData.truth(patient, "left")
	var asym := CaseRules.is_asymmetric(right, left)
	var truth_asym := CaseRules.is_asymmetric(CaseData.truth(patient, "right"), CaseData.truth(patient, "left"))
	var ear := _case_ear()
	var wandered := false
	for f: Variant in case_data["findings"]:
		var fd: Dictionary = f
		var when := String(fd.get("when", ""))
		var shows := finding_shows(when, results, patient, ear, asym)
		if shows != finding_shows(when, {}, patient, ear, truth_asym):
			wandered = true
		if shows:
			_add_clue(String(fd["tag"]), String(fd["text"]), String(fd.get("kind", "clue")), String(fd.get("src", "test")))
	if wandered:
		clinic.call("hoot_emote", &"nod")
		await _say("Hoot", MISMATCH)


## Whether a finding with this "when" shows: "" always; "symmetric" / "asymmetric" by asym (the
## chart's, or the truth's); "conductive" when the case ear types conductive on the chart (the truth
## type when the chart can't tell); "abg_flag" when the ear's own air and bone show the air-bone-gap
## red flag (the truth when the ear has no bone). res = {} reads the truth.
static func finding_shows(when: String, res: Dictionary, p: PatientProfile, ear: String, asym: bool) -> bool:
	match when:
		"symmetric":
			return not asym
		"asymmetric":
			return asym
		"conductive":
			var measured: StringName = ((res.get("ears", {}) as Dictionary).get(ear, {}) as Dictionary).get("hearing_type", &"unknown")
			if measured == &"unknown":
				measured = CaseData.truth_type(p, ear)
			return measured == &"conductive"
		"abg_flag":
			var bone := ClinicRules.best_thresholds(res, ear, true)
			if not bone.is_empty():
				return ClinicRules.abg_red_flag(ClinicRules.best_thresholds(res, ear, false), bone)
			if p == null:
				return false
			var air := CaseData.truth(p, ear)
			var truth_bone := {}
			for f: int in air:
				truth_bone[f] = p.get_bc_threshold(ear, f)
			return ClinicRules.abg_red_flag(air, truth_bone)
	return true


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
	await _until_walked()   # the patient strolled to the desk during the reveal
	await clinic.call("focus_camera", &"desk", 0.5)
	await _play(case_data["payoff"])
	if props != null:
		props.call("hang_up")
	clinic.call("focus_camera", &"door", 1.6)
	_shot("goodbye", 1.6)
	await clinic.call("walk_out")


# ---------------------------------------------------------------- 11. the retest (after treatment)

## Days later the patient comes back treated: a look, a tymp recheck, a prediction, then air on a
## fresh AudiOtron, and the new chart flies up over the first one's. A victory lap: no medal, and the
## first visit's results stay the scored set. The retest's truth is its own patient file
## (retest.patient_id, e.g. barnaby_after), loaded without a second begin_visit.
func _retest() -> void:
	var rt: Dictionary = case_data["retest"]
	var first_results := results.duplicate(true)
	var first_patient := patient
	_phase(&"retest")
	hud.call("set_step", &"retest")
	clinic.call("focus_camera", &"door", 0.0)
	await _props().call("play", "later", String(rt.get("card", "LATER")))
	_shot("retest_later")
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	_react(&"wave")
	await _play(rt.get("intro", []))
	patient = Game.load_patient(String(rt["patient_id"])) as PatientProfile
	_canal_blocked = false
	if rt.get("otoscopy", null) is Dictionary:
		await _otoscopy(rt["otoscopy"], false)
	if rt.get("tymp", null) is Dictionary:
		await _tymp_recheck(rt["tymp"])
	await _play(rt.get("before", []))
	await _instructions(rt.get("instructions", []), false)
	await _audiometry(rt["audiometry"], false)
	var rv: Dictionary = rt["reveal"]
	var ear := String(rv["ear"])
	var shown := merge_retest(first_results, results, CaseData.plan_ears(rt["audiometry"], "ac"))
	var measured: StringName = ((shown["ears"] as Dictionary).get(ear, {}) as Dictionary).get("hearing_type", &"unknown")
	_phase(&"reveal", {"retest": true})
	var b := CaseBoard.new()
	b.setup(retest_board_case(case_data, rt, first_results))
	hud.call("add_game", b)
	clinic.call("focus_camera", &"desk", 0.0)
	_walk_to_desk()
	await b.run_reveal(shown)
	await b.show_pattern()
	_shot("retest_chart", 0.3)
	var truth := CaseData.truth_type(patient, ear)
	b.call("show_type", String(ClinicRules.HEARING_TYPE_TITLES.get(truth, "")))
	if measured == truth:
		await _play(rv.get("lines", []))
	else:
		await _say("Hoot", RETEST_NEUTRAL)
	await b.call("fade_out")
	b.queue_free()
	await _until_walked()
	await clinic.call("focus_camera", &"desk", 0.5)
	await _play(rt.get("payoff", []))
	clinic.call("focus_camera", &"door", 1.6)
	_shot("retest_goodbye", 1.6)
	await clinic.call("walk_out")
	results = first_results
	patient = first_patient
	Game.set_audiometry_results(first_results)   # the score is the first visit's
	Game.set_visit_flag("retested", true)
	Game.set_visit_flag("retest_type", String(measured))
	hud.call("complete_step", &"retest")


## The chart the retest board shows: a deep copy of the first visit's results with each retested ear
## replaced by a copy of the retest's. Neither input changes.
static func merge_retest(first: Dictionary, second: Dictionary, ears: PackedStringArray) -> Dictionary:
	var out := first.duplicate(true)
	if not out.get("ears", null) is Dictionary:
		out["ears"] = {}
	var second_ears: Dictionary = second.get("ears", {})
	for ear: String in ears:
		if second_ears.has(ear):
			(out["ears"] as Dictionary)[ear] = (second_ears[ear] as Dictionary).duplicate(true)
	return out


## The retest board's case: the "retest" pattern, with the first visit's measured air on the retest
## ear dashed behind today's chart (the reveal's label, e.g. "WITH WAX").
static func retest_board_case(c: Dictionary, rt: Dictionary, first_results: Dictionary) -> Dictionary:
	var rv: Dictionary = rt.get("reveal", {})
	var ear := String(rv.get("ear", "right"))
	var before := ClinicRules.best_thresholds(first_results, ear, false)
	var prev := {}
	for f: int in before:
		prev[str(f)] = int(before[f])
	return {
		"speaker": String(c.get("speaker", "Patient")),
		"case_title": String(c.get("case_title", "")),
		"reveal": {"pattern": "retest", "ear": ear, "title": String(rv.get("title", "")),
			"previous": {"ear": ear, "label": String(rv.get("label", "BEFORE")), "thresholds": prev}},
	}


# ---------------------------------------------------------------- 12. results

## The paper's headlines and subheads for a visit: the case's own, except that a wrong first stamp
## takes over every graded headline (S to C; Do-over keeps its own): the case's paper.wrong_first
## entry, or a generic one. Works on copies (CaseData caches the case dict).
static func paper_for(c: Dictionary, decision_first: String) -> Dictionary:
	var paper: Dictionary = c.get("paper", {})
	var headlines: Dictionary = (paper.get("headlines", {}) as Dictionary).duplicate()
	var subheads: Dictionary = (paper.get("subheads", {}) as Dictionary).duplicate()
	var answer := String((c.get("decision", {}) as Dictionary).get("answer", ""))
	if decision_first != "" and decision_first != answer:
		var wf: Dictionary = (paper.get("wrong_first", {}) as Dictionary).get(decision_first, {})
		var head := String(wf.get("headline", ""))
		var sub := String(wf.get("subhead", ""))
		if head == "":
			var said := String(CaseRules.DECISION_STAMPS.get(StringName(decision_first), decision_first.to_upper()))
			var right := String(CaseRules.DECISION_STAMPS.get(StringName(answer), answer.to_upper()))
			head = "FIRST STAMP SAID %s; OWL STEERS TO %s" % [said, right]
			sub = "First stamp: %s. The right call: %s." % [said, right]
		for g: String in ["S", "A", "B", "C"]:
			headlines[g] = head
			if sub != "":
				subheads[g] = sub
	return {"headlines": headlines, "subheads": subheads}


func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	var paper_data := paper_for(case_data, String(Game.get_visit_flag("decision_first", "")))
	summary["case_id"] = case_id
	summary["headlines"] = paper_data["headlines"]
	summary["subheads"] = paper_data["subheads"]
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
