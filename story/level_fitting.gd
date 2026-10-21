extends Node
## LevelFitting (Day 14, docs/FITTING.md): Gus comes back for his hearing aids, the story's finale.
## The workup recap, a style pick, matching his prescription in the real ear band by band
## (story/games/target_match.gd) while the grey world colours back in, Hoot's left ear at Hoot speed,
## and the dishes callback. Talks to other modules only by contract, like level_gus.gd:
##   world:  res://world/clinic.tscn (Clinic API §6 and its extras, called by name)
##   global: Game (visit, scores), Events (phases, awaiting_input), Hoot (tips)
## Blocking beats: dialogue, choice, fitting_target, results_continue.
## Scores (FITTING.md §3): accuracy from the match, technique from the style pick and a clean fit,
## efficiency from moves against par, care from comfort (each kind of overshoot costs a point).

const Hud := preload("res://story/hud.gd")
const TargetMatch := preload("res://story/games/target_match.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_fitting.tscn"
const PAPER_SCRIPT := "res://story/papers/paper_fitting.gd"
const PATIENT_ID := "gus_fit"

const STEPS: Array[StringName] = [&"file", &"style", &"match", &"birds"]
const STEP_LABELS: Dictionary = {&"file": "File", &"style": "Style", &"match": "Match", &"birds": "Birds"}
const STEPS_TITLE := "Gus's fitting"
## Doris's line during the match: TargetMatch.heard() drops the sounds of the bands not matched yet.
const DORIS_LINE := "Gus, the finches are back! Shall I put the kettle on?"
## The workup since Day 1, for the notes board: [text, kind].
const FILE_NOTES: Array = [
	["Red flags: none (Day 1)", "flag"],
	["Bone matched air: the loss is in the inner ear", "clue"],
	["Words in quiet: clear when loud enough", "clue"],
	["Party Noise Test: some trouble in noise", "clue"],
]
const STYLE_PROMPT := "Pick Gus's hearing aid style:"
## The styles in display order: [option text, id]. Right: the open receiver-in-canal (his lows are
## nearly normal, so the ear stays open). The wrong two both plug the ear (the occlusion effect).
const STYLES: Array = [
	["Behind the ear, with a custom earmold that seals his canal.", "bte_mold"],
	["A tiny speaker in his canal on a thin wire, with an open dome.", "ric_open"],
	["A custom-made shell that sits inside and fills his whole canal.", "full_shell"],
]
const RIGHT_STYLE := "ric_open"
## Technique's style part by pick: first, second, third.
const STYLE_SCORES: Array[float] = [1.0, 0.5, 0.2]
const STYLE_MEDALS: Array[String] = ["gold", "silver", "bronze"]
## World colour by matched bands (0..3). The last band crosses 0.6, which brings the birdsong.
const SAT_BY_MATCHED: Array[float] = [0.0, 0.3, 0.55, 1.0]
const MEDAL_BEATS: Array = [["style", "Style"], ["match", "Match"]]
const WEATHER := "Weather: clear skies, finches likely"
const HEADLINES: Dictionary = {
	"S": "TARGET MATCHED TO THE DECIBEL; FINCHES RETURN TO LOCAL GRANDPA",
	"A": "GUS HEARS EVERY WORD; DORIS HEARS NO MORE EXCUSES",
	"B": "AIDS FITTED, FINCHES SPOTTED, DISHES PENDING",
	"C": "AIDS ON, A LITTLE OFF TARGET, CONFIRMS OWL",
	"Do-over": "GUS BACK NEXT WEEK FOR A TUNE-UP; BRINGS PLAIN BAGELS",
}
const SUBHEADS: Dictionary = {
	"S": "Every band a bullseye, par on the knobs. Doris has run out of excuses for him.",
	"A": "Matched to his prescription in his own ear. Gus reports \"an alarming number of birds\".",
	"B": "Every band in the green, with a few extra turns. Hoot recommends a steady hand.",
	"C": "Close to the target. Remember: open dome for good lows, then match each band.",
	"Do-over": "Fitting is a craft. Everyone overshoots a band once.",
}

var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var style_tries := 0


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, STEPS_TITLE)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.level_started.emit(PATIENT_ID)
	_run.call_deferred()


func _phase(p: StringName, info: Dictionary = {}) -> void:
	Events.phase_changed.emit(p, info)


func _say(who: String, text: String) -> void:
	await dialogue.say(who, text)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _react(kind: StringName, data: Dictionary = {}) -> void:
	Events.patient_reaction.emit(kind, data)


## Extra story screenshots (only saved when the game runs with --shots).
func _shot(shot_name: String, delay: float = 0.0) -> void:
	if not Game.cli.has("shots"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	Events.screenshot_requested.emit("story_" + shot_name)


func _run() -> void:
	await _intro()
	await _file()
	await _style()
	await _match()
	await _payoff()
	await _results()


# ---------------------------------------------------------------- 1. back again

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"file")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	await _say("Gus", "I'm BACK! Plain bagel today. No seeds. Doris checked.")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "Welcome back, Gus! Today's the big day: your hearing aids.")
	clinic.call("gus_look", &"camera")
	await _say("Gus", "Doris is parking the car. She says I owe her forty years of dishes.")
	clinic.call("gus_look", &"hoot")


func _file() -> void:
	await _say("Hoot", "Since Day 1 we finished his workup. Aids come after the checks, never before.")
	for n: Array in FILE_NOTES:
		hud.call("add_clue", String(n[0]), String(n[1]))
		await _wait(0.25)
	await _say("Hoot", "No red flags, an inner-ear loss, clear words when loud enough. That's a FIT!")
	hud.call("add_clue", "The call: FIT hearing aids")
	_react(&"cheer")
	await _say("Gus", "Fit? Nobody has called me fit since 1962.")
	hud.call("complete_step", &"file")


# ---------------------------------------------------------------- 2. the style

func _style() -> void:
	_phase(&"aid_style")
	hud.call("set_step", &"style")
	await _say("Hoot", "First, the style. His lows are nearly normal; only the highs need a boost.")
	var opts: Array[String] = []
	var ids: Array[String] = []
	for s: Array in STYLES:
		opts.append(String(s[0]))
		ids.append(String(s[1]))
	style_tries = 0
	while true:
		var c: int = await dialogue.choose(STYLE_PROMPT, opts, ids.find(RIGHT_STYLE))
		style_tries += 1
		if ids[c] == RIGHT_STYLE:
			break
		_react(&"confused")
		if ids[c] == "bte_mold":
			await _say("Gus", "Hello? HELLO? Why do I sound like I'm talking in a barrel?")
			await _say("Hoot", "A sealed ear traps his own voice: the occlusion effect. His lows don't need help.")
		else:
			await _say("Gus", "Why does my bagel sound like a marching band?")
			await _say("Hoot", "A full shell plugs the ear too, so chewing booms. Keep his good lows open.")
		opts.remove_at(c)
		ids.remove_at(c)
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Yes! The open dome lets his good lows in naturally. The aid adds the highs.")
	_react(&"nod")
	await _say("Gus", "An open dome. Sounds like a stadium. I like it.")
	Game.record_medal("style", STYLE_MEDALS[mini(style_tries, STYLE_MEDALS.size()) - 1])
	Game.set_visit_flag("style_tries", style_tries)
	hud.call("complete_step", &"style")


# ---------------------------------------------------------------- 3. match the target

func _match() -> void:
	_phase(&"real_ear")
	hud.call("set_step", &"match")
	clinic.call("focus_camera", &"fitting", 0.8)
	clinic.call("gus_look", &"camera")
	clinic.call("put_on_hearing_aids")
	await _wait(0.6)
	await _say("Hoot", "On they go, with the software's first guess. But every ear canal is different.")
	await _say("Hoot", "So a thin tube sits near his eardrum. Its tiny mic hears what the aid does.")
	clinic.call("set_world_saturation", 0.0)
	await _say("Hoot", "Here's Gus's world on the first guess. Still a bit grey.")
	await clinic.call("doris_enter")
	clinic.call("gus_look", &"doris")
	await _say("Doris", TargetMatch.heard(DORIS_LINE, [false, false, false]))
	_react(&"confused")
	await _say("Gus", "The PINCHES are back? Doris, that was ONE time!")
	clinic.call("doris_react", &"wince")
	var g := TargetMatch.new()
	hud.call("add_game", g)
	g.setup("right", patient.get_thresholds("right"), DORIS_LINE)
	g.matched_changed.connect(func(n: int) -> void: clinic.call("set_world_saturation", SAT_BY_MATCHED[n]))
	g.overshoot.connect(func(kind: String) -> void: Game.lose_comfort("fitting_" + kind))
	_shot("fitting_match", 0.48)   # the first guess, before the bot solves it (0.6 s)
	await g.run()
	var right := g.result()
	await _wait(0.6)
	_react(&"cheer")
	_shot("fitting_matched", 0.2)
	await _say("Gus", "FINCHES! Doris, the finches are back! Have there always been this many?")
	clinic.call("doris_react", &"nod")
	await _say("Hoot", "Right ear matched. Left ear's the same story, so watch me go!")
	await g.run_hoot("left", patient.get_thresholds("left"))
	Game.record_medal("match", match_medal(right))
	Game.set_audiometry_results(results_for(right, style_tries, g.result()))
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	await t.finished
	g.queue_free()
	hud.call("complete_step", &"match")


## The visit's results (FITTING.md §3): the usual three parts, plus "fitting" for the paper and the bot.
static func results_for(right: Dictionary, tries: int, left: Dictionary = {}) -> Dictionary:
	var style := STYLE_SCORES[clampi(tries, 1, STYLE_SCORES.size()) - 1]
	var clean := maxf(0.0, 1.0 - 0.5 * float((right.get("overshoots", []) as Array).size()))
	var fit := right.duplicate(true)
	fit["style"] = RIGHT_STYLE
	fit["style_tries"] = tries
	fit["left_by_hoot"] = not left.is_empty()
	if not left.is_empty():
		fit["left"] = left.get("bands", [])
	return {
		"accuracy": float(right.get("accuracy", 0.0)),
		"technique": 0.6 * style + 0.4 * clean,
		"efficiency": float(right.get("efficiency", 0.0)),
		"fitting": fit,
	}


## gold: at par with every band a bullseye; silver: within par + 2; bronze otherwise.
static func match_medal(r: Dictionary) -> String:
	var moves := int(r.get("moves", 0))
	var par := int(r.get("par", 0))
	var bull := true
	for b: Dictionary in r.get("bands", []):
		bull = bull and absi(int(b.get("err", 99))) <= TargetMatch.BULLSEYE_DB
	if moves <= par and bull:
		return "gold"
	return "silver" if moves <= par + 2 else "bronze"


# ---------------------------------------------------------------- 4. payoff

func _payoff() -> void:
	_phase(&"fitting")
	hud.call("set_step", &"birds")
	clinic.call("set_world_saturation", 1.0)
	clinic.call("focus_camera", &"fitting", 0.6)
	await _say("Doris", "Wonderful. Now, Gus, about those dishes...")
	clinic.call("gus_look", &"camera")
	await _say("Gus", "Hmm? Sorry, dear. Can't hear a thing. Must be the new aids.")
	clinic.call("hoot_emote", &"facepalm")
	await _say("Hoot", "Nice try, Gus. I just measured them in your ear. They're perfect.")
	clinic.call("gus_look", &"doris")
	clinic.call("doris_react", &"nod")
	clinic.call("focus_camera", &"fitting_close", 0.5)
	await _say("Doris", "Forty years of \"fishes\", Gus. I kept a LIST.")
	_react(&"startle")
	clinic.call("focus_camera", &"fitting", 0.6)
	await _say("Gus", "...Fine. But I'm wearing these while I wash. I want to hear the finches.")
	clinic.call("gus_look", &"hoot")
	await _say("Hoot", "His brain needs a few weeks to get used to sound. All-day wear helps.")
	await _say("Hoot", "We'll see him in a week or two to fine-tune. That's a real fitting!")
	clinic.call("hoot_emote", &"cheer")
	_shot("fitting_finale", 0.4)
	await _say("Hoot", "Fourteen days, trainee. From your first beep to Gus's first finch. Bravo!")
	hud.call("complete_step", &"birds")


# ---------------------------------------------------------------- 5. results

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	summary["headlines"] = HEADLINES
	summary["subheads"] = SUBHEADS
	summary["medal_beats"] = MEDAL_BEATS
	summary["weather"] = WEATHER
	summary["sports_script"] = PAPER_SCRIPT
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
