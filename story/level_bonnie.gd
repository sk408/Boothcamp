extends Node
## LevelBonnie (v3): Day 2, "Bone conduction + masking". Bonnie Bunsworth, 34, baker, with a
## slowly muffled RIGHT ear (otosclerosis). Design: docs/CHAPTER2.md. Same contracts as Day 1
## (CONTRACTS.md §3.1): every blocking beat emits Events.awaiting_input with a solver.
##   world:  res://world/clinic.tscn with patient_id = "bonnie" (§6 + the v3 extras)
##   ui:     res://ui/audiometer/audiometer_screen.tscn start_test(patient, ear, coached, plan)
##   global: Game (visit, medals, scores), Events (phases, awaiting_input), Hoot (tips)
## Beats: dialogue, choice, earphones_place, bc_placement, the AudiOtron's tone beats,
## referral_stamp, results_continue.

const Hud := preload("res://story/hud.gd")
const Earphones := preload("res://story/games/earphones.gd")
const BonePlacement := preload("res://story/games/bone_placement.gd")
const Day2Board := preload("res://story/games/day2_board.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_bonnie.tscn"
const PATIENT_ID := "bonnie"

const STEPS: Array[StringName] = [&"chat", &"peek", &"explain", &"phones", &"air", &"bone", &"mask", &"reveal", &"case", &"refer"]
const STEP_LABELS: Dictionary = {
	&"chat": "Chat", &"peek": "Peek", &"explain": "Explain", &"phones": "Phones", &"air": "Air",
	&"bone": "Bone", &"mask": "Mask", &"reveal": "Reveal", &"case": "Case", &"refer": "Refer",
}

## Case-history rounds: [text, points (2 best, 1 good, 0 joke), reply, clue, tag].
const HISTORY: Array[Dictionary] = [
	{
		"prompt": "Ask Bonnie a question:",
		"options": [
			["Which ear, and since when?", 2, "Just the right. It's crept up over a year or two. The left is perfect.", "RIGHT ear only, slowly over 1-2 years", "one_sided"],
			["Is your favourite bread sourdough?", 0, "Rye, if I'm honest. Don't tell the sourdough. It's sensitive.", "", ""],
			["Anyone in the family with hearing trouble?", 2, "Mum and Gran both went 'underwater' in their thirties. Runs in the family, like baking.", "Family: Mum and Gran, same thing in their 30s", "family"],
		],
	},
	{
		"prompt": "Next question:",
		"options": [
			["Any ear pain, drainage, dizziness, or sudden change?", 2, "No pain, no drips, no spinning. Just slowly gone muffled.", "No pain, drainage, dizziness or sudden change", "red_flags"],
			["Does your own voice sound different?", 1, "Yes! My voice booms in that ear. And chewing crusts is LOUD.", "Own voice + chewing sound LOUD on the right", "own_voice"],
			["Have you tried a gluten-free ear?", 0, "I'm a baker, love. Gluten is my love language.", "", ""],
		],
	},
]

var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var screen: CanvasLayer
var results: Dictionary = {}
var _walk_done := true
var _found_glasses := false   # the player tried the oscillator on her glasses (the running gag)


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", PATIENT_ID)
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, "BONNIE BUNSWORTH'S VISIT")
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


func _shot(shot_name: String, delay: float = 0.0) -> void:
	if not Game.cli.has("shots"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	Events.screenshot_requested.emit("day2_" + shot_name)


func _run() -> void:
	await _intro()
	await _history()
	await _otoscopy()
	await _instructions()
	await _earphones()
	await _air()
	await _bone_placement()
	await _bone()
	await _masking()
	var board: Control = await _reveal()
	await _evidence(board)
	await _referral(board)
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
	await _say("Bonnie", "Morning! Bonnie Bunsworth, Bunsworth's Bakery. I brought croissants for the waiting room!")
	clinic.call("put_down_basket")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "Day 2, trainee! Today we test through the bone, not just the air.")
	clinic.call("gus_look", &"camera")
	_react(&"confused")
	await _say("Bonnie", "My right ear has gone all underwater. Like listening through a loaf of sourdough.")
	await _say("Bonnie", "And I've lost my reading glasses. Again. Third time this week!")
	clinic.call("gus_look", &"hoot")
	clinic.call("hoot_emote", &"facepalm")
	await _say("Hoot", "(Psst, trainee: they're on her head. Let's see when she notices.)")
	await _say("Hoot", "One muffled ear. Let's find out WHERE the sound gets stuck. Questions first!")


# ---------------------------------------------------------------- 2. case history

func _history() -> void:
	_phase(&"history")
	var points := 0
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
		_react(&"cheer" if int(pick[1]) == 0 else &"nod")
		await _say("Bonnie", String(pick[2]))
		if String(pick[3]) != "":
			hud.call("add_clue", String(pick[3]))
		if int(pick[1]) == 0:
			clinic.call("hoot_emote", &"facepalm")
			await _say("Hoot", "Delicious, but not a clue. Ask about her hearing!")
		elif String(pick[4]) == "own_voice":
			await _say("Hoot", "Own voice booming? A classic sign that sound is blocked before the inner ear.")
	if not tags.has("red_flags"):
		await _say("Hoot", "Always ask about red flags too: pain, drainage, dizziness, sudden change.")
		await _say("Bonnie", "None of those, love. Just the sourdough feeling.")
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "One-sided hearing loss is a red flag by itself. A doctor should see her.")
	hud.call("add_clue", "Pain, drainage, dizziness, sudden change: NONE.\nOne ear only: YES = see a doctor.", "flag")
	var medal := "gold" if points >= 4 else ("silver" if points >= 2 else "bronze")
	Game.record_medal("history", medal)
	Game.set_visit_flag("asked_red_flags", tags.has("red_flags"))
	hud.call("complete_step", &"chat")


# ---------------------------------------------------------------- 3. otoscopy (a quick look)

func _otoscopy() -> void:
	_phase(&"otoscopy")
	hud.call("set_step", &"peek")
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var g := Otoscopy.new()
	hud.call("add_game", g)
	await g.show_clear("right", "Bonnie's RIGHT ear: clear canal, shiny eardrum.")
	await _say("Hoot", "Look before you beep! Canals clear, both eardrums healthy and shiny.")
	await _say("Bonnie", "No croissant crumbs in there? I find them EVERYWHERE.")
	await _say("Hoot", "Not a crumb. A healthy-looking eardrum can still hide a stiff middle ear.")
	hud.call("add_clue", "Canals clear, eardrums look normal")
	g.queue_free()
	clinic.call("focus_camera", &"desk", 0.6)
	Game.record_medal("otoscopy", "gold")
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. instructions

func _instructions() -> void:
	_phase(&"instructions")
	hud.call("set_step", &"explain")
	clinic.call("focus_camera", &"desk", 0.8)
	var good := "Press for every beep, even faint ones. Ignore the shhh noise."
	var opts: Array[String] = ["Press for every sound you hear, the shhh noise too.", good, "Only press when you're totally sure."]
	var first_try := true
	while true:
		var best := opts.find(good)
		var c: int = await dialogue.choose("Today there's a noise too. Tell Bonnie what to do:", opts, best)
		if c == best:
			break
		first_try = false
		if opts[c].begins_with("Only"):
			_react(&"confused")
			await _say("Bonnie", "Totally sure? I'm never sure. I still check the oven twelve times.")
			await _say("Hoot", "Too strict! She'd keep quiet for the faint beeps. Try again.")
		else:
			_react(&"false_alarm")
			await _say("Bonnie", "The shhh too? *click* *click* *click* This is like kneading!")
			Game.lose_comfort("no_instructions")
			await _say("Hoot", "She'd press for the noise all day! Beeps only. Try again.")
		opts.remove_at(c)
	Game.set_visit_flag("instructed", true)
	Game.set_visit_flag("instructed_first_try", first_try)
	_react(&"nod")
	await _say("Bonnie", "Beeps yes, shhh no. Like ignoring the mixer and listening for the oven timer!")
	hud.call("complete_step", &"explain")


# ---------------------------------------------------------------- 5. earphones

func _earphones() -> void:
	_phase(&"earphones")
	hud.call("set_step", &"phones")
	clinic.call("focus_camera", &"booth", 1.2)
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.8)
	var g := Earphones.new()
	g.setup(clinic, "her")
	hud.call("add_game", g)
	Hoot.say("Red = Right. Blue = Left. Her right is on YOUR left.", Hoot.NORMAL, "earphone_red")
	await g.run()
	Hoot.dismiss_current()
	var mistakes := g.mistakes
	Game.record_medal("earphones", "gold" if mistakes == 0 else ("silver" if mistakes == 1 else "bronze"))
	clinic.call("put_on_earphones", true)
	await _wait(0.5)
	g.queue_free()
	_react(&"cheer")
	hud.call("complete_step", &"phones")


# ---------------------------------------------------------------- 6. air conduction (Hoot runs most of it)

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


## Quick visit as the AudiOtron sees it (the setting, or --quick / --full): Hoot takes turns.
func _quick() -> bool:
	return screen != null and bool(screen.get("quick_visit"))


func _test(ear: String, coached: bool, plan: Dictionary) -> Dictionary:
	plan["air_transducer"] = _air_transducer()
	_phase(&"audiometry", {"ear": ear, "test": String(plan.get("test", "ac"))})
	screen.call("start_test", patient, ear, coached, plan)
	var r: Dictionary = await screen.test_finished
	results = r
	Game.set_audiometry_results(results)
	return r


func _air() -> void:
	var cam := _open_screen()
	hud.call("set_step", &"air")
	# a career-fair player may start here (Unlock all days): no "like yesterday"
	var veteran := Game.is_chapter_done("gus")
	await _test("right", true, {"test": "ac", "hoot_turn_after": 1, "skip_hoot_retest": true, "done_title": "RIGHT AIR DONE!",
		"intro": "Air first, like yesterday. Stamp 1k, then I'll whizz through the rest!" if veteran
			else "New trainee? Air first: I'll coach your first beep, then whizz through the rest!",
		"intro_full": "Air first: her whole right ear is yours. I'll coach the first beep."})
	# quick visit: the left ear is a few-second montage (Hoot "did it while you chatted")
	await _test("left", false, {"test": "ac", "hoot_turn_after": 0, "montage": true, "skip_hoot_retest": true, "done_title": "LEFT AIR DONE!",
		"intro": "I did her left while you chatted. Normal! Watch the stamps fly in.",
		"intro_full": "Left ear: all yours this time! Same dance as the right."})
	hud.call("complete_step", &"air")
	_close_screen(cam)
	clinic.call("focus_camera", &"face", 0.6)
	await _say("Hoot", "Right ear needs about 50 dB, left is normal. But WHERE is it stuck?")
	await _say("Hoot", "Air goes through the ear canal and middle ear. Bone skips both, straight to the cochlea.")


# ---------------------------------------------------------------- 7. bone oscillator placement

func _bone_placement() -> void:
	_phase(&"bc_placement")
	hud.call("set_step", &"bone")
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"ear_right", 0.8)
	await _say("Hoot", "Meet the bone buzzer! It goes behind the ear, on the mastoid bone.")
	var g := BonePlacement.new()
	hud.call("add_game", g)
	_shot("bone_placement", 0.7)
	await g.run()
	var m := g.mistakes
	_found_glasses = g.wrong_spots.has("top")
	var was_unicorn := g.wrong_spots.has("forehead")
	Game.record_medal("bc_placement", "gold" if m == 0 else ("silver" if m == 1 else "bronze"))
	Game.set_visit_flag("bc_placement_mistakes", m)
	await _wait(0.6)
	g.queue_free()
	clinic.call("put_on_bone_oscillator", "right")
	await _wait(0.4)
	if was_unicorn:
		await _say("Bonnie", "Was I a unicorn for a second there? I felt majestic.")
	if _found_glasses:
		await _say("Bonnie", "And you found my glasses! They were on my HEAD? All morning?")
	await _say("Hoot", "Snug on the mastoid, not touching the ear. Bone tones go 500 to 4000 Hz.")


# ---------------------------------------------------------------- 8. unmasked bone: the Cross-Hearing Ghost

func _bone() -> void:
	var cam := _open_screen()
	await _test("right", true, {"test": "bc", "bc_freqs": ClinicRules.BC_REQUIRED, "masking_controls": true,
		"hoot_turn_after": 2, "done_title": "BONE DONE!",
		"intro": "Bone time! %s = bone. Same dance: down 10, up 5. Start at 1k." % Game.key_label(&"transducer_bone")})
	_close_screen(cam)
	clinic.call("focus_camera", &"face", 0.6)
	var bone := ClinicRules.sheet_thresholds(results, "right", &"bc")
	var air := ClinicRules.sheet_thresholds(results, "right", &"ac")
	var b1 := int(bone.get(1000, 5))
	var a1 := int(air.get(1000, 50))
	await _say("Hoot", "Bone at %d dB, air at %d? Suspicious. Bone buzzes BOTH cochleas." % [b1, a1])
	_react(&"startle")
	await _say("Hoot", "Bone has almost zero interaural attenuation. Her LEFT cochlea may have answered!")
	await _say("Bonnie", "A ghost in my skull?! I KNEW that oven was haunted.")
	hud.call("complete_step", &"bone")


# ---------------------------------------------------------------- 9. masking

func _masking() -> void:
	_phase(&"masking")
	hud.call("set_step", &"mask")
	await _say("Hoot", "To hear the right cochlea alone, keep the left one busy with noise. Masking!")
	var opts: Array[String] = ["The right ear: the one we're testing.", "The left ear: the good one.", "Both ears, for maximum shhh."]
	var medal := "gold"
	while true:
		var c: int = await dialogue.choose("Which ear gets the shhh noise?", opts, opts.find("The left ear: the good one."))
		var picked: String = opts[c]
		if picked.begins_with("The left"):
			break
		medal = "silver" if medal == "gold" else "bronze"
		if picked.begins_with("The right"):
			await _say("Hoot", "Noise in the test ear just hides the beep. Busy the OTHER ear.")
		else:
			_react(&"wince")
			await _say("Hoot", "Then nobody hears the beep! Noise goes in the non-test ear only.")
		opts.remove_at(c)
	Game.record_medal("masking", medal)
	clinic.call("put_on_masking_phone", "left")
	_react(&"nod")
	# (polish) one hook, no rule dump: the coach teaches the numbers step by step on the AudiOtron
	await _say("Hoot", "I'll walk you through it. Trick: if more noise makes her answer vanish, it was the Ghost.")
	var cam := _open_screen()
	await _test("right", true, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 2, "done_title": "GHOST BUSTED!",
		"intro": "Noise in her LEFT ear, bone on her right. Find the flat line!"})
	await _masked_air()
	screen.queue_free()
	screen = null
	cam.current = true
	clinic.call("take_off_earphones")
	hud.call("complete_step", &"mask")


## Masked air, only where the rules ask for it with THIS air transducer: supra-aural phones lose
## about 40 dB crossing the head (rule of thumb), insert earphones about 55, so with inserts (the
## Day 2 shop upgrade) Bonnie's right air usually cannot reach her left cochlea at all.
func _masked_air() -> void:
	var tr := _air_transducer()
	var ia := ClinicRules.ia_rule(tr)
	var need := ClinicRules.masked_freqs_needed(results, "right", &"ac_masked", tr)
	var air := ClinicRules.sheet_thresholds(results, "right", &"ac")
	if need.is_empty():
		var top := 0
		for f: int in air:
			top = maxi(top, int(air[f]))
		await _say("Hoot", "Inserts! About %d dB is lost crossing her head. %d minus %d can't reach her left ear." % [ia, top, ia])
		await _say("Hoot", "No Ghost on air: no masked air needed today. That's what the upgrade buys you!")
		return
	var a0 := int(air.get(need[0], 50))
	await _say("Hoot", "Air leaks too! %d dB minus about %d lost crossing her head could reach her left ear." % [a0, ia])
	await _say("Hoot", "(Clinics often mask air first. Today the Ghost couldn't wait!)")
	clinic.call("take_off_bone_oscillator")
	clinic.call("put_on_earphones", true)
	await _test("right", not _quick(), {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 0, "done_title": "MASKED AIR DONE!",
		"intro": "Masked air, Hoot speed. Same plateau dance, noise in the left ear.",
		"intro_full": "Masked air is yours: the same plateau dance, through the earphones."})


# ---------------------------------------------------------------- 10. reveal: the toll bridge

## Returns the board: the evidence and referral beats happen on it.
func _reveal() -> Control:
	_phase(&"reveal")
	hud.call("set_step", &"reveal")
	var b := Day2Board.new()
	hud.call("add_game", b)
	clinic.call("focus_camera", &"desk", 0.0)
	_walk_done = false
	var go := func() -> void:
		await clinic.call("walk_to", &"desk", 2.4)
		_walk_done = true
	go.call()
	await b.run_reveal(results)
	_shot("reveal")
	await _say("Hoot", "Brackets are masked bone. Bone near normal, air down at 50.")
	await b.show_gap()
	_shot("bridge", 0.2)
	await _say("Hoot", "That gap is the toll bridge: air pays a toll at the middle ear. Bone drives past.")
	await _say("Bonnie", "So the sourdough really IS in my ear?")
	await _say("Hoot", "No bread! Something in the middle ear stops sound crossing to the cochlea.")
	hud.call("complete_step", &"reveal")
	return b


# ---------------------------------------------------------------- 11. evidence: type of loss

func _evidence(b: Control) -> void:
	_phase(&"evidence")
	hud.call("set_step", &"case")
	var ear: Dictionary = (results.get("ears", {}) as Dictionary).get("right", {})
	var kind: StringName = ear.get("hearing_type", &"conductive")
	if kind == &"unknown" or kind == &"normal":
		kind = &"conductive"
	var opts: Array[String] = ["Sensorineural: the inner ear itself.", "Conductive: blocked before the inner ear.", "Mixed: a bit of both."]
	var answer := {&"sensorineural": 0, &"conductive": 1, &"mixed": 2}.get(kind, 1) as int
	b.call("set_compact", true)   # the choices go under the shrunken chart
	# (polish) the answer follows the player's own chart, so the hints must too
	var wrong := {
		&"conductive": {0: "Then bone would be down too. Her bone is near normal! Look again.",
			2: "Mixed needs poor bone AND a gap. Her bone is near normal."},
		&"mixed": {0: "Look at the gap: on your chart air sits well below bone.",
			1: "Check the bone: on your chart it's poorer than 25 dB too."},
		&"sensorineural": {1: "Conductive needs a gap. On your chart air and bone sit together.",
			2: "Mixed needs a gap too. On your chart air and bone sit together."},
	}
	var tries := 0
	while true:
		tries += 1
		var c: int = await dialogue.choose("What type of loss is Bonnie's right ear?", opts, answer)
		if c == answer:
			break
		await _say("Hoot", String((wrong.get(kind, {}) as Dictionary).get(c, "Close! Compare bone with normal, then compare air with bone.")))
	Game.record_medal("evidence", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	var title := String(ClinicRules.HEARING_TYPE_TITLES.get(kind, "Conductive loss"))
	b.call("show_type", title)
	Sfx.play(&"ding", 1.2, -6.0)
	_shot("type", 0.3)
	match kind:
		&"mixed":
			await _say("Hoot", "%s on your chart: a gap AND bone poorer than 25 dB." % title)
		&"sensorineural":
			await _say("Hoot", "%s on your chart: no real gap, air and bone down together." % title)
		_:
			await _say("Hoot", "%s! A gap over 10 dB, bone near normal. 15 or more at 500, 1k AND 2k: a red flag." % title)
	if kind != &"conductive":
		await _say("Hoot", "Hmm, your masked bone came out poor. Overmasked? A real clinic would recheck: her real pattern is conductive.")
	if bool(ear.get("carhart_notch", false)):
		b.call("show_carhart")
		_shot("carhart", 0.5)
		await _say("Hoot", "See the bone dip at 2k? A Carhart notch: a stiff middle ear fakes a small bone dip. Her cochlea is fine!")
	else:
		await _say("Hoot", "Young, one ear, family history, normal eardrum: a doctor may suspect otosclerosis.")
	await _say("Hoot", "If BOTH ears had big gaps, even masking could overmask. The masking dilemma. Another day!")
	hud.call("complete_step", &"case")


# ---------------------------------------------------------------- 12. referral stamp

func _referral(b: Control) -> void:
	_phase(&"referral")
	hud.call("set_step", &"refer")
	var opts: Array[String] = ["Hearing aids today, all sorted!", "Refer her to an ENT doctor.", "See you in five years."]
	var medal := "gold"
	while true:
		var c: int = await dialogue.choose("What's next for Bonnie?", opts, opts.find("Refer her to an ENT doctor."))
		if opts[c].begins_with("Refer"):
			break
		medal = "silver" if medal == "gold" else "bronze"
		if opts[c].begins_with("Hearing"):
			await _say("Hoot", "Aids may help later. An air-bone gap like this sees a doctor first.")
		else:
			_react(&"confused")
			await _say("Hoot", "Five years of sourdough ears? A one-sided gap like this needs a doctor now.")
		opts.remove_at(c)
	Game.record_medal("referral", medal)
	b.call("set_compact", false)
	await _say("Hoot", "An air-bone gap like this: refer to an ENT doctor. Often very treatable! Stamp it!")
	await b.call("run_stamp")
	_shot("stamp", 0.1)
	_react(&"cheer")
	# (polish) what otosclerosis is and what happens next; the ENT confirms, the game never diagnoses
	await _say("Hoot", "If it's otosclerosis: extra bone grows around the stapes, the tiny stirrup bone, so it can't vibrate freely.")
	await _say("Bonnie", "A tiny stirrup! Like the nozzle on my piping bag, gone stiff?")
	await _say("Hoot", "Exactly! The ENT checks it. Then you and the doctor choose: surgery to free it, or hearing aids. Both can work well.")
	await _say("Bonnie", "A doctor for my ear, then back to my buns. Deal! Croissant for the road?")
	await _payoff(b)
	hud.call("complete_step", &"refer")


## The board fades, a croissant flies to Hoot, the glasses gag lands, and Bonnie waves goodbye.
func _payoff(b: Control) -> void:
	var t := b.create_tween()
	t.tween_property(b, "modulate:a", 0.0, 0.35)
	await t.finished
	b.queue_free()
	while not _walk_done:   # she strolled to the desk during the reveal
		await _wait(0.2)
	await clinic.call("focus_camera", &"desk", 0.5)
	_shot("croissant", 0.45)
	await clinic.call("give_croissant")
	clinic.call("hoot_emote", &"cheer")
	await _say("Hoot", "Mmf! I'm not going anywhere, but thank you! Lovely work, trainee.")
	await _say("Hoot", "You busted the ghost AND found the gap!")
	if not _found_glasses:
		await _say("Hoot", "Oh, and Bonnie? Your glasses are on your head.")
		_react(&"startle")
		await _say("Bonnie", "...All MORNING? Don't tell the sourdough.")
	clinic.call("focus_camera", &"door", 1.6)
	_shot("goodbye", 1.6)
	await clinic.call("walk_out")


# ---------------------------------------------------------------- 13. results

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
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
