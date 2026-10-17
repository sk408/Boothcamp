extends Node
## LevelGus: the first playable level's director. Grandpa Gus, the sesame seed, and "dishes".
## Runs the beats in order (CONTRACTS.md §3.1) and talks to other modules only by contract:
##   world:  res://world/clinic.tscn (Clinic API §6, called by name)
##   ui:     res://ui/audiometer/audiometer_screen.tscn (start_test / test_finished §4.2)
##           res://ui/audiogram/audiogram.tscn (reveal + evidence, §4.6)
##   global: Game (visit, scores), Events (phases, awaiting_input), Hoot (tips)
## Every blocking beat emits Events.awaiting_input with a solver (dialogue, choice,
## otoscopy_find, earphones_place, evidence_present, fitting_switch_on, results_continue).

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const Earphones := preload("res://story/games/earphones.gd")
const Reveal := preload("res://story/games/reveal.gd")
const Evidence := preload("res://story/games/evidence.gd")
const Fitting := preload("res://story/games/fitting.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_gus.tscn"
const PATIENT_ID := "gus"

## Case-history rounds: options in display order, each [text, points (2 best, 1 good, 0 joke), reply, clue, tag].
## tag: "hardest" / "noise" / "duration" / "red_flags" feed the summary line; "" for jokes.
const HISTORY: Array[Dictionary] = [
	{
		"prompt": "Ask Gus a question:",
		"options": [
			["Is it harder to follow talk in noisy places?", 1, "Restaurants are the worst. Everyone talks like they're underwater... in another room.", "Noisy places = trouble following talk", "noise"],
			["Is your walker turbocharged?", 0, "Turbo? It has a cup holder AND a horn. Honk honk!", "", ""],
			["Which sounds are hardest to hear?", 2, "Birds, whistles, the grandkids... and when Doris says 'dishes', I hear 'fishes'.", "Hardest: birds, whistles, kids, 'dishes'", "hardest"],
		],
	},
	{
		"prompt": "Next question:",
		"options": [
			["Ever worked around loud noise?", 1, "Forty years at the library. The loudest thing was the date stamp. Ka-CHUNK.", "Noise: quiet library job (ka-chunk)", ""],
			["Any ear pain, drainage, dizziness, or sudden change?", 2, "No pain, no leaks, no spinning. Just a slow fade over ten years, both ears.", "Gradual, ~10 years, both ears", "red_flags"],
			["Have you tried turning your ears off and on again?", 0, "Doris has asked if mine have an off switch. Many times.", "", ""],
			["How long has it been going on, and in which ear?", 2, "Slowly, about ten years. Both ears, same as my hairline.", "Gradual, ~10 years, both ears", "duration"],
		],
	},
]

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


## --shots only: once the next line has started, finish its typing and grab a screenshot.
func _shot_line(shot_name: String) -> void:
	if not Game.cli.has("shots"):
		return
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	if dialogue.is_typing():
		dialogue.call("_finish_typing")
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit("story_" + shot_name)


func _run() -> void:
	await _intro()
	await _history()
	await _otoscopy()
	await _instructions()
	await _earphones()
	await _audiometry()
	await _reveal()
	await _evidence()
	await _fitting()
	await _results()


# ---------------------------------------------------------------- 1. intro

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"chat")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	_shot("door_burst", 1.1)
	await clinic.call("walk_in")
	await _say("Gus", "HELLO? Is this the beep place? Pardon the crumbs: sesame bagel, every morning since 1987!")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "Welcome to Booth Camp! I'm Professor Hoot. You, trainee, are on beeps today.")
	clinic.call("gus_look", &"camera")
	_react(&"confused")
	await _say("Gus", "Everyone MUMBLES these days! Especially Doris. Especially when she says something about... fishes?")
	clinic.call("gus_look", &"hoot")
	await _say("Hoot", "Let's find out what Gus is missing. First, we chat. Pick good questions!")


# ---------------------------------------------------------------- 2. case history

func _history() -> void:
	_phase(&"history")
	var points := 0
	var asked_red_flags := false
	var tags: Dictionary = {}
	for round_i in HISTORY.size():
		var rd: Dictionary = HISTORY[round_i]
		var opts: Array[String] = []
		var best := 0
		var best_pts := -1
		for o: Array in rd["options"]:
			opts.append(String(o[0]))
			if int(o[1]) > best_pts:
				best_pts = int(o[1])
				best = opts.size() - 1
		var c: int = await dialogue.choose(String(rd["prompt"]), opts, best)
		var pick: Array = (rd["options"] as Array)[c]
		points += int(pick[1])
		if String(pick[4]) != "":
			tags[String(pick[4])] = true
		_react(&"cheer" if int(pick[1]) == 0 and round_i == 0 else &"nod")
		await _say("Gus", String(pick[2]))
		if String(pick[3]) != "":
			hud.call("add_clue", String(pick[3]))
			if round_i == 0:
				_shot("history_clue", 0.5)
		if round_i == 0:
			if int(pick[1]) == 2:
				await _say("Hoot", "Clue! Soft, high-pitched sounds are slipping away.")
			elif int(pick[1]) == 0:
				clinic.call("hoot_emote", &"facepalm")
				await _say("Hoot", "Delightful. Not a clue, though. Let's ask about his hearing!")
		elif round_i == 1:
			if String(pick[4]) == "red_flags":
				asked_red_flags = true
				clinic.call("hoot_emote", &"nod")
				await _say("Hoot", "Red flags! Any one means a doctor should check his ears before any hearing aid.")
			else:
				if int(pick[1]) == 0:
					clinic.call("hoot_emote", &"facepalm")
				await _say("Hoot", "Always ask about red flags too: pain, drainage, dizziness, sudden or one-sided change.")
				await _say("Gus", "Oh, none of those. Just the mumbling.")
			hud.call("add_clue", "Pain, drainage, dizziness, sudden or one-sided change: NONE.\nAny one = refer to a doctor.", "flag")
	await _say("Hoot", _history_summary(tags))
	var medal := "bronze"
	if asked_red_flags and points >= 3:
		medal = "gold"
	elif points >= 2:
		medal = "silver"
	Game.record_medal("history", medal)
	Game.set_visit_flag("asked_red_flags", asked_red_flags)
	hud.call("complete_step", &"chat")


## Hoot sums up only what the player actually found out.
static func _history_summary(tags: Dictionary) -> String:
	var parts: Array[String] = []
	if tags.has("duration") or tags.has("red_flags"):
		parts.append("gradual, both ears")
	if tags.has("hardest"):
		parts.append("soft high sounds missing")
	elif tags.has("noise"):
		parts.append("noisy rooms are hard")
	if parts.is_empty():
		return "We missed some clues. Let's see what the ears say!"
	var line := ", ".join(parts)
	return line.substr(0, 1).to_upper() + line.substr(1) + ". Now let's peek inside!"


# ---------------------------------------------------------------- 3. otoscopy

func _otoscopy() -> void:
	_phase(&"otoscopy")
	hud.call("set_step", &"peek")
	await _say("Hoot", "Rule one: look before you beep! Gently pull the ear up and back, and brace on his head.")
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var g := Otoscopy.new()
	hud.call("add_game", g)
	g.modulate.a = 0.0
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 1.0, 0.3)
	await t.finished
	await g.run_find()
	g.slide_aside(-290.0, 0.4)
	_shot("seed_found", 0.5)
	var medal := "gold" if g.elapsed() < 12.0 and g.wrong_clicks() <= 2 else ("silver" if g.elapsed() < 25.0 else "bronze")
	var c: int = await dialogue.choose("A sesame seed in the ear canal! What now?", ["Grab a paperclip and dig it out!", "Don't poke! Note it and arrange safe removal.", "Ignore it. It's only a little seed."], 1)
	match c:
		0:
			clinic.call("hoot_emote", &"gasp")
			await _say("Hoot", "NO paperclips! Never poke in an ear. That's how eardrums get hurt.")
			medal = "silver" if medal == "gold" else "bronze"
		1:
			clinic.call("hoot_emote", &"nod")
			await _say("Hoot", "Exactly. Something stuck in the canal? A doctor or trained clinician removes it safely.")
		2:
			await _say("Hoot", "Hmm. A stuck object can block sound, or the earphone. A doctor or trained clinician removes it first.")
			medal = "silver" if medal == "gold" else "bronze"
	Game.record_medal("otoscopy", medal)
	g.slide_aside(0.0, 0.35)
	await _say("Gus", "Ah... ah... AH...")
	_react(&"startle")
	Events.screen_shake.emit(0.5, 0.35)
	await g.sneeze_out()
	_shot_line("sneeze")
	await _say("Gus", "My sesame seed! It's been in there since 1987!")
	await _say("Hoot", "...Well. Cartoon physics! Real ears can't sneeze things out. Canal clear, eardrum pearly grey and shiny: safe to test!")
	await g.show_left_clear()
	hud.call("add_clue", "Right canal: 1 sesame seed (sneezed out). Eardrums: healthy!")
	var t2 := g.create_tween()
	t2.tween_property(g, "modulate:a", 0.0, 0.3)
	await t2.finished
	g.queue_free()
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. instructions

func _instructions() -> void:
	_phase(&"instructions")
	hud.call("set_step", &"explain")
	clinic.call("focus_camera", &"desk", 0.8)
	var opts: Array[String] = ["Only press when you're totally, completely sure.", "Just relax. I'll figure it out.", "Press the button whenever you hear a beep, even if it's very faint."]
	var first_try := true
	while true:
		var best := opts.find("Press the button whenever you hear a beep, even if it's very faint.")
		var c: int = await dialogue.choose("Before the beeps, tell Gus what to do:", opts, best)
		var picked: String = opts[c]
		if c == best:
			break
		first_try = false
		if picked.begins_with("Only"):
			_react(&"confused")
			await _say("Gus", "Totally sure? I'm not even sure what day it is.")
			await _say("Hoot", "Too strict! He'd stay quiet for the faint beeps. Try again.")
		else:
			_react(&"false_alarm")
			await _say("Gus", "Relax? Okay! Was that a beep? *click* That was the clock. *click* Was THAT?")
			_react(&"false_alarm")
			Game.lose_comfort("no_instructions")
			await _say("Hoot", "Vague instructions mean guessing, and a stressed patient. Try again.")
		opts.remove_at(c)
	Game.set_visit_flag("instructed", true)
	Game.set_visit_flag("instructed_first_try", first_try)
	_react(&"nod")
	await _say("Gus", "Every beep. Even the teeny ones. I'll be like a hawk!")
	clinic.call("hoot_emote", &"facepalm")
	await _say("Hoot", "...An OWL, Gus. Be like an owl.")
	hud.call("complete_step", &"explain")


# ---------------------------------------------------------------- 5. earphones

func _earphones() -> void:
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
	_shot("earphones_game", 0.4)
	await g.run()
	Hoot.dismiss_current()
	var mistakes := g.mistakes
	Game.record_medal("earphones", "gold" if mistakes == 0 else ("silver" if mistakes == 1 else "bronze"))
	if mistakes == 0:
		Hoot.note_clean_use(&"earphones")
	clinic.call("put_on_earphones", true)
	await _wait(0.5)
	g.queue_free()
	_shot("earphones_on", 0.3)
	_react(&"cheer")
	hud.call("complete_step", &"phones")


# ---------------------------------------------------------------- 6. audiometry

func _audiometry() -> void:
	var screen: Node = (load(AUDIOMETER_SCENE) as PackedScene).instantiate()
	add_child(screen)
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false  # the AudiOtron covers the screen: only the booth camera renders
	hud.call("set_step", &"beep_r")
	_phase(&"audiometry", {"ear": "right"})
	screen.call("start_test", patient, "right", true)
	results = await screen.test_finished
	hud.call("complete_step", &"beep_r")
	hud.call("set_step", &"beep_l")
	_phase(&"audiometry", {"ear": "left"})
	screen.call("start_test", patient, "left", false)
	results = await screen.test_finished
	Game.set_audiometry_results(results)
	hud.call("complete_step", &"beep_l")
	screen.queue_free()
	cam.current = true
	clinic.call("take_off_earphones")
	clinic.call("put_on_glasses")


# ---------------------------------------------------------------- 7. reveal

func _reveal() -> void:
	_phase(&"reveal")
	hud.call("set_step", &"reveal")
	var r := Reveal.new()
	hud.call("add_game", r)
	clinic.call("focus_camera", &"desk", 0.0)
	_walk_done = false
	var go := func() -> void:
		await clinic.call("walk_to", &"desk", 2.4)
		_walk_done = true
	go.call()
	await r.run(results)
	_shot_line("reveal_title")
	var shape: StringName = ((results.get("ears", {}) as Dictionary).get("right", {}) as Dictionary).get("shape", &"unknown")
	if shape == &"sloping":
		await _say("Hoot", "A sloping high-frequency loss: the classic! Low pitches fine, high pitches fading.")
		await _say("Hoot", "Lower on the chart means he needs louder beeps. See it ski downhill?")
		await _say("Gus", "Downhill? I used to ski! Badly. Like my hearing, apparently.")
	else:
		await _say("Hoot", "%s, by your stamps. Lower on the chart means he needs louder beeps." % String(ClinicRules.SHAPE_TITLES.get(shape, "Gus's hearing")))
		await _say("Gus", "Is that good? It looks like my old ski trail.")
	r.queue_free()
	hud.call("complete_step", &"reveal")


# ---------------------------------------------------------------- 8. evidence

func _evidence() -> void:
	_phase(&"evidence")
	hud.call("set_step", &"evidence")
	var e := Evidence.new()
	hud.call("add_game", e)
	e.preview(results)
	await _say("Hoot", "Now crack the case! Which part of the audiogram explains the missing 'dishes'?")
	_shot("evidence_board", 0.4)
	await e.run(results)
	_shot("evidence_solved", 0.35)
	Game.record_medal("evidence", "gold" if e.attempts <= 1 else ("silver" if e.attempts == 2 else "bronze"))
	await _wait(0.8)
	await _say("Hoot", "Soft consonants like s, sh, f and th live up in the high pitches, right where Gus slopes down. He fills the gaps with a guess!")
	e.queue_free()
	hud.call("complete_step", &"evidence")


# ---------------------------------------------------------------- 9. teaser fitting

func _fitting() -> void:
	_phase(&"fitting")
	hud.call("set_step", &"fit")
	var guard := 0.0
	while not _walk_done and guard < 10.0:
		await get_tree().process_frame
		if not get_tree().paused:
			guard += get_process_delta_time()
	clinic.call("set_world_saturation", 0.0)
	clinic.call("focus_camera", &"fitting", 0.0)
	clinic.call("gus_look", &"camera")
	await _say("Hoot", "A sneak peek at Gus's world: loud enough, just not clear. The soft high sounds are missing.")
	await clinic.call("doris_enter")
	clinic.call("gus_look", &"doris")
	_shot_line("fitting_grey")
	await _say("Doris", "Gu_, honey... can you plea_e do the di_e_?")
	_react(&"confused")
	await _say("Gus", "Do the... FISHES? We don't HAVE fishes, Doris!")
	clinic.call("doris_react", &"wince")
	await _say("Hoot", "A teaser of what's coming: a little boost, right where his hearing slopes.")
	var f := Fitting.new()
	hud.call("add_game", f)
	await f.run()
	clinic.call("gus_look", &"camera")
	clinic.call("put_on_hearing_aids")
	await _wait(0.5)
	var t := create_tween()
	t.tween_method(func(v: float) -> void: clinic.call("set_world_saturation", v), 0.0, 1.0, 2.2).set_trans(Tween.TRANS_SINE)
	await t.finished
	_react(&"cheer")
	_shot("fitting_colour", 0.3)
	await _wait(0.6)
	f.queue_free()
	await _say("Gus", "Wait... are those BIRDS? Have there always been birds?!")
	clinic.call("doris_react", &"nod")
	await _say("Doris", "Gus, honey. Can you PLEASE do the DISHES?")
	clinic.call("gus_look", &"doris")
	_react(&"startle")
	clinic.call("focus_camera", &"fitting_close", 0.5)
	_shot_line("fitting_dishes")
	await _say("Gus", "Doris... did you just say DISHES?")
	clinic.call("focus_camera", &"fitting", 0.6)
	await _say("Doris", "Forty years, Gus. FORTY. YEARS.")
	await _say("Hoot", "Real fittings take fine-tuning and a few weeks of getting used to. That's a later level!")
	clinic.call("hoot_emote", &"cheer")
	await _say("Hoot", "That's the job: every beep you measured made that moment. Lovely work, trainee!")
	hud.call("complete_step", &"fit")


# ---------------------------------------------------------------- 10. results

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	Events.level_finished.emit(summary)
	var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
	add_child(paper)
	var next: Variant = await paper.call("show_summary", summary)
	Events.goto_scene.emit(LEVEL_SCENE if String(next) == "again" else TITLE_SCENE)
