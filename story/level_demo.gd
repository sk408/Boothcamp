extends Node
## LevelDemo (career-fair demo, docs/DEMO.md): Grandpa Gus in about seven minutes, for a booth.
## One visit from "HELLO? Is this the beep place?" to "did you just say DISHES?": one chat question,
## the sesame seed, the earphones, a few beeps (Hoot finishes both ears), the chart, then the aids
## matched on the real-ear graph. Started by the title's Play in demo mode (Game.is_demo()); the
## paper's "Next visitor" goes back to the title, which starts a fresh visitor.
## Reuses Day 1's mini-games and history (level_gus.gd) and Day 14's target match (level_fitting.gd)
## without changing them. Patient "gus", so the visit scores like Day 1 in the demo's own save.
## Beats: dialogue, choice, otoscopy_find, earphones_place, the audiometer's, fitting_target,
## results_continue. Left alone for IDLE_RESET_S (a visitor walked off), it goes back to the title.

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const Earphones := preload("res://story/games/earphones.gd")
const Reveal := preload("res://story/games/reveal.gd")
const TargetMatch := preload("res://story/games/target_match.gd")
const LevelGus := preload("res://story/level_gus.gd")
const LevelFitting := preload("res://story/level_fitting.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_demo.tscn"
const PATIENT_ID := "gus"

const STEPS: Array[StringName] = [&"chat", &"peek", &"phones", &"beeps", &"chart", &"fit"]
const STEP_LABELS: Dictionary = {&"chat": "Chat", &"peek": "Peek", &"phones": "Phones", &"beeps": "Beeps",
	&"chart": "Chart", &"fit": "Fit"}
const STEPS_TITLE := "Gus's big day"
## What Doris says before and after the aids (Day 1's line; TargetMatch.heard() drops the sounds Gus misses).
const DORIS_LINE := "Gus, honey, can you please do the dishes?"
## The right ear: the coached stamp plus one on the player's own, then Hoot fills in the rest.
const RIGHT_PLAN: Dictionary = {"hoot_turn_after": 2, "montage_after": true,
	"hoot_turn_text": "Nice work! I'll fill in the rest of this ear in a flash."}
## The left ear: Hoot fills it in a few seconds.
const LEFT_PLAN: Dictionary = {"hoot_turn_after": 0, "montage": true, "intro": "Left ear: watch me fill it in a flash!"}
## No input for this long (real seconds, whatever the game speed or pause): back to the title.
const IDLE_RESET_S := 120.0

const MEDAL_BEATS: Array = [["history", "Chat"], ["otoscopy", "Peek"], ["earphones", "Phones"], ["match", "Fit"]]
const WEATHER := "Weather: sunny, with a chance of careers"
const HEADLINES: Dictionary = {
	"S": "VISITOR BEEPS LIKE A PRO; OWL SAYS \"DO THIS FOR REAL!\"",
	"A": "LOCAL GRANDPA HEARS \"DISHES\" FOR FIRST TIME IN YEARS",
	"B": "VISITOR CRACKS THE CASE OF THE MISSING \"DISHES\"",
	"C": "BEEPS MOSTLY BEEPED; GUS HEARS BIRDS ANYWAY",
	"Do-over": "GUS HAPPY TO COME BACK (\"THEY HAVE BAGELS\")",
}
const SUBHEADS: Dictionary = {
	"S": "Hoot calls the audiogram \"frame-worthy\". Hearing care pros do this every day.",
	"A": "Doris reports dishes finally done. \"I'm framing the sponge.\"",
	"B": "Gus: \"Best beeps I've had all week.\" Doris: \"Now the dishes.\"",
	"C": "A few beeps went astray. Hoot recommends practice and a snack.",
	"Do-over": "Every audiologist's first booth is a little wobbly. Have another go!",
}


## Kiosk: no input for limit_s real seconds (paused or not, at any game speed) sends the demo back to
## the title for the next visitor. Never under autoplay.
class Watchdog extends Node:
	var limit_s := 120.0
	var title_scene := ""
	var _last_ms := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_last_ms = Time.get_ticks_msec()

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseMotion or event.is_pressed():
			_last_ms = Time.get_ticks_msec()

	func _process(_delta: float) -> void:
		if Time.get_ticks_msec() - _last_ms < int(limit_s * 1000.0):
			return
		set_process(false)
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm != null and bool(pm.call("is_open")):
			pm.call("close")
		get_tree().paused = false
		Events.goto_scene.emit(title_scene)


var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var results: Dictionary = {}
var _walk_done := true


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
	if not Game.is_autoplay():
		var dog := Watchdog.new()
		dog.limit_s = IDLE_RESET_S
		dog.title_scene = TITLE_SCENE
		add_child(dog)
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
	Events.screenshot_requested.emit("story_demo_" + shot_name)


func _run() -> void:
	await _intro()
	await _chat()
	await _peek()
	await _phones()
	await _beeps()
	await _chart()
	await _fit()
	await _results()


# ---------------------------------------------------------------- 1. hello

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"chat")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	await _say("Gus", "HELLO? Is this the beep place? Pardon the crumbs: sesame bagel, every morning since 1987!")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "Welcome to Booth Camp! Hearing care pros solve puzzles like Gus every day. Let's try one!")
	clinic.call("gus_look", &"camera")
	_react(&"confused")
	await _say("Gus", "Everyone MUMBLES these days! Especially Doris. Especially when she says something about... fishes?")
	clinic.call("gus_look", &"hoot")
	await _say("Hoot", "First, we chat. Pick a good question!")


# ---------------------------------------------------------------- 2. one question

## Day 1's first history round. Whatever the pick, Gus's hardest sounds come out (the payoff needs
## "dishes"); the medal is the player's.
func _chat() -> void:
	_phase(&"history")
	var rd: Dictionary = LevelGus.HISTORY[0]
	var opts: Array[String] = []
	var best := 0
	for o: Array in rd["options"]:
		opts.append(String(o[0]))
		if int(o[1]) > int((rd["options"] as Array)[best][1]):
			best = opts.size() - 1
	var c: int = await dialogue.choose(String(rd["prompt"]), opts, best)
	var pick: Array = (rd["options"] as Array)[c]
	_react(&"cheer" if int(pick[1]) == 0 else &"nod")
	await _say("Gus", String(pick[2]))
	if String(pick[3]) != "":
		hud.call("add_clue", String(pick[3]))
	if c != best:
		if int(pick[1]) == 0:
			clinic.call("hoot_emote", &"facepalm")
			await _say("Hoot", "Delightful. Not a clue, though. Let me try one.")
		else:
			await _say("Hoot", "Good clue! One more from me.")
		var top: Array = (rd["options"] as Array)[best]
		await _say("Hoot", "Which sounds are hardest to hear, Gus?")
		await _say("Gus", String(top[2]))
		hud.call("add_clue", String(top[3]))
	await _say("Hoot", "Clue! Soft, high-pitched sounds are slipping away.")
	await _say("Hoot", "We always check red flags too: pain, drainage, dizziness, sudden or one-sided change.")
	await _say("Gus", "Oh, none of those. Just the mumbling.")
	hud.call("add_clue", "Red flags: NONE. Any one = see a doctor first.", "flag")
	Game.record_medal("history", ["bronze", "silver", "gold"][clampi(int(pick[1]), 0, 2)])
	hud.call("complete_step", &"chat")


# ---------------------------------------------------------------- 3. the sesame seed

func _peek() -> void:
	_phase(&"otoscopy")
	hud.call("set_step", &"peek")
	await _say("Hoot", "Rule one: look before you beep! Gently pull the ear up and back.")
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var g := Otoscopy.new()
	hud.call("add_game", g)
	g.modulate.a = 0.0
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 1.0, 0.3)
	await t.finished
	await g.run_find()
	g.slide_aside(-290.0, 0.4)
	_shot("seed_found", 0.3)
	var medal := "gold" if g.elapsed() < 12.0 and g.wrong_clicks() <= 2 else ("silver" if g.elapsed() < 25.0 else "bronze")
	var c: int = await dialogue.choose("A sesame seed in the ear canal! What now?", ["Grab a paperclip and dig it out!", "Don't poke! Note it and arrange safe removal.", "Ignore it. It's only a little seed."], 1)
	match c:
		0:
			clinic.call("hoot_emote", &"gasp")
			await _say("Hoot", "NO paperclips! Never poke in an ear. That's how eardrums get hurt.")
			medal = "silver" if medal == "gold" else "bronze"
			Game.set_visit_flag(Game.NO_S_FLAG, true)
		1:
			clinic.call("hoot_emote", &"nod")
			await _say("Hoot", "Exactly. A doctor or trained clinician removes stuck things safely.")
		2:
			await _say("Hoot", "Hmm. A stuck object can block sound. A doctor or trained clinician removes it first.")
			medal = "silver" if medal == "gold" else "bronze"
			Game.set_visit_flag(Game.NO_S_FLAG, true)
	Game.record_medal("otoscopy", medal)
	g.slide_aside(0.0, 0.35)
	await _say("Gus", "Ah... ah... AH...")
	_react(&"startle")
	Events.screen_shake.emit(0.5, 0.35)
	await g.sneeze_out()
	await _say("Gus", "My sesame seed! It's been in there since 1987!")
	await _say("Hoot", "Cartoon physics! Real ears can't sneeze things out. Canal clear, eardrum healthy: safe to test!")
	await g.show_left_clear()
	hud.call("add_clue", "Right canal: 1 sesame seed (sneezed out). Eardrums: healthy!")
	var t2 := g.create_tween()
	t2.tween_property(g, "modulate:a", 0.0, 0.3)
	await t2.finished
	g.queue_free()
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. earphones (Hoot instructs)

func _phones() -> void:
	_phase(&"earphones")
	hud.call("set_step", &"phones")
	clinic.call("focus_camera", &"booth", 1.2)
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.8)
	await _say("Hoot", "Glasses off first: they lift the cushions and let sound sneak in.")
	clinic.call("take_off_glasses")
	await _wait(0.4)
	await _say("Gus", "Now you're all blurry. Handsome, though.")
	var g := Earphones.new()
	g.setup(clinic)
	hud.call("add_game", g)
	Hoot.say("Red = Right. Blue = Left. Pop each cup onto the matching ear.", Hoot.NORMAL, "earphone_red")
	_shot("earphones_game", 0.3)
	await g.run()
	Hoot.dismiss_current()
	var mistakes := g.mistakes
	Game.record_medal("earphones", "gold" if mistakes == 0 else ("silver" if mistakes == 1 else "bronze"))
	clinic.call("put_on_earphones", true)
	await _wait(0.5)
	g.queue_free()
	_react(&"cheer")
	# Day 1's instruction beat, said by Hoot (the full game lets the player pick the words)
	await _say("Hoot", "Gus: press whenever you hear a beep, even a faint one. Let go when it stops.")
	Game.set_visit_flag("instructed", true)
	await _say("Gus", "Every beep. Even the teeny ones. I'll be like a hawk!")
	clinic.call("hoot_emote", &"facepalm")
	await _say("Hoot", "...An OWL, Gus. Be like an owl.")
	hud.call("complete_step", &"phones")


# ---------------------------------------------------------------- 5. beeps

func _beeps() -> void:
	hud.call("set_step", &"beeps")
	await _say("Hoot", "Better ear first! Gus says both are the same, so right it is.")
	var screen: Node = (load(AUDIOMETER_SCENE) as PackedScene).instantiate()
	add_child(screen)
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false  # the AudiOtron covers the screen: only the booth camera renders
	_phase(&"audiometry", {"ear": "right"})
	screen.call("start_test", patient, "right", true, RIGHT_PLAN)
	results = await screen.test_finished
	_phase(&"audiometry", {"ear": "left"})
	screen.call("start_test", patient, "left", false, LEFT_PLAN)
	results = await screen.test_finished
	Game.set_audiometry_results(results)
	screen.queue_free()
	cam.current = true
	clinic.call("take_off_earphones")
	clinic.call("put_on_glasses")
	hud.call("complete_step", &"beeps")


# ---------------------------------------------------------------- 6. the chart

func _chart() -> void:
	_phase(&"reveal")
	hud.call("set_step", &"chart")
	var r := Reveal.new()
	hud.call("add_game", r)
	clinic.call("focus_camera", &"desk", 0.0)
	_walk_done = false
	var go := func() -> void:
		await clinic.call("walk_to", &"desk", 2.4)
		_walk_done = true
	go.call()
	await r.run(results)
	var shape: StringName = ((results.get("ears", {}) as Dictionary).get("right", {}) as Dictionary).get("shape", &"unknown")
	if shape == &"sloping":
		await _say("Hoot", "A sloping high-frequency loss: the classic! Low pitches fine, high pitches fading.")
	else:
		await _say("Hoot", "%s, by your stamps. Lower on the chart means louder beeps." % String(ClinicRules.SHAPE_TITLES.get(shape, "Gus's hearing")))
	await _say("Hoot", "Soft sounds like s, sh, f and th live up high, right where Gus slopes down.")
	await _say("Gus", "So THAT'S why \"dishes\" sounds like \"fishes\"!")
	r.queue_free()
	hud.call("complete_step", &"chart")


# ---------------------------------------------------------------- 7. the fitting and the payoff

func _fit() -> void:
	_phase(&"real_ear")
	hud.call("set_step", &"fit")
	var guard := 0.0
	while not _walk_done and guard < 10.0:
		await get_tree().process_frame
		if not get_tree().paused:
			guard += get_process_delta_time()
	clinic.call("set_world_saturation", 0.0)
	clinic.call("focus_camera", &"fitting", 0.0)
	clinic.call("gus_look", &"camera")
	await _say("Hoot", "Here's Gus's world now: loud enough, just not clear. Listen to Doris.")
	await clinic.call("doris_enter")
	clinic.call("gus_look", &"doris")
	await _say("Doris", TargetMatch.heard(DORIS_LINE, [false, false, false]))
	_react(&"confused")
	await _say("Gus", "Do the... FISHES? We don't HAVE fishes, Doris!")
	clinic.call("doris_react", &"wince")
	# (clinical review D1-3) honest about what the demo skips
	await _say("Hoot", "Skipping ahead! Real aids come after more tests, like bone and speech. The full game has them.")
	clinic.call("gus_look", &"camera")
	clinic.call("put_on_hearing_aids")
	await _wait(0.5)
	await _say("Hoot", "In go the aids. Raise each band into the green, and watch his world fill in.")
	var g := TargetMatch.new()
	hud.call("add_game", g)
	g.setup("right", patient.get_thresholds("right"), DORIS_LINE)
	g.matched_changed.connect(func(n: int) -> void: clinic.call("set_world_saturation", LevelFitting.SAT_BY_MATCHED[n]))
	g.overshoot.connect(func(kind: String) -> void: Game.lose_comfort("fitting_" + kind))
	_shot("match", 0.3)   # the first guess, well before the bot solves it
	await g.run()
	var right := g.result()
	await _wait(0.4)
	await _say("Hoot", "Right ear matched! The left ear is the same story. Watch me go!")
	await g.run_hoot("left", patient.get_thresholds("left"))
	Game.record_medal("match", LevelFitting.match_medal(right))
	results["fitting"] = right
	Game.set_audiometry_results(results)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	await t.finished
	g.queue_free()
	clinic.call("set_world_saturation", 1.0)
	_react(&"cheer")
	await _say("Gus", "Wait... are those BIRDS? Have there always been birds?!")
	clinic.call("doris_react", &"nod")
	await _say("Doris", "Gus, honey. Can you PLEASE do the DISHES?")
	clinic.call("gus_look", &"doris")
	_react(&"startle")
	clinic.call("focus_camera", &"fitting_close", 0.5)
	_shot("dishes", 0.3)
	await _say("Gus", "Doris... did you just say DISHES?")
	clinic.call("focus_camera", &"fitting", 0.6)
	await _say("Doris", "Forty years, Gus. FORTY. YEARS.")
	await _say("Hoot", "Real fittings take fine-tuning and a few weeks of getting used to.")
	clinic.call("hoot_emote", &"cheer")
	await _say("Hoot", "That's the job: every beep you measured made that moment. Lovely work!")
	await _say("Hoot", "Like puzzles AND people? Hearing care could be your job. Ask at this booth!")
	hud.call("complete_step", &"fit")


# ---------------------------------------------------------------- 8. the paper

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	apply_summary(summary)
	Events.level_finished.emit(summary)
	var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
	add_child(paper)
	var next: Variant = await paper.call("show_summary", summary)
	Events.goto_scene.emit(LEVEL_SCENE if String(next) == "again" else TITLE_SCENE)


## The demo's paper: its own headlines, medals and weather, no next day, "Next visitor" back to the title.
static func apply_summary(summary: Dictionary) -> void:
	summary["demo"] = true
	summary["headlines"] = HEADLINES
	summary["subheads"] = SUBHEADS
	summary["medal_beats"] = MEDAL_BEATS
	summary["weather"] = WEATHER
	summary["next_chapter_id"] = ""
	summary["continue_text"] = "Next visitor"
