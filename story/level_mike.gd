extends Node
## LevelMike (Speech): Day 3, "SRT". Mike "Totally Deaf" Lenders, 41, forklift driver, who says he
## can't hear ANYTHING. Design: docs/CHAPTER3.md; contracts: CONTRACTS.md §3.1 and §9.8. Every
## blocking beat emits Events.awaiting_input with a solver. The game never calls him a liar:
## it records the facts, stays kind and refers him on.
##   world:  res://world/clinic.tscn with patient_id = "mike" (§6 + the Speech extras)
##   ui:     res://ui/audiometer/audiometer_screen.tscn (Hoot runs both tone ears)
##           res://ui/speech/speech_screen.tscn start_test(patient, ear, coached, plan) (§9.7)
##   global: Game (visit, medals, scores), Events (phases, awaiting_input), Hoot (tips)
## Beats: dialogue, choice, familiarize_cards, the SPEECH screen's speech beats, objection_present,
## referral_stamp, results_continue. Board: story/games/mike_board.gd.

const Hud := preload("res://story/hud.gd")
const MikeBoard := preload("res://story/games/mike_board.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const SPEECH_SCENE := "res://ui/speech/speech_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_mike.tscn"
const PATIENT_ID := "mike"

## The spondee list, how many cards Mike reads, and the one he has never heard of.
const LIST_ID := "spondee_a"
const FAMILIAR_WORDS := 12
const UNKNOWN_WORD := "windmill"
## Words the player scores on the solo (left) ear before Hoot finishes it (quick visit).
const LEFT_SOLO_WORDS := 4
## Hoot's "the tell" tip: a word repeated this far (dB) below the ear's PTA.
const TELL_GAP_DB := 30

const STEPS: Array[StringName] = [&"chat", &"peek", &"explain", &"beeps", &"words", &"srt_r", &"srt_l", &"case", &"next"]
const STEP_LABELS: Dictionary = {
	&"chat": "Chat", &"peek": "Peek", &"explain": "Explain", &"beeps": "Beeps", &"words": "Words",
	&"srt_r": "SRT R", &"srt_l": "SRT L", &"case": "Case", &"next": "Next",
}

## Case-history rounds: [text, points (2 best, 1 good, 0 joke), reply, case note, tag].
const HISTORY: Array[Dictionary] = [
	{
		"prompt": "Ask Mike a question:",
		"options": [
			["When did it start, and how?", 2, "Tuesday. The forklift reversed, BEEP BEEP BEEP, then silence. Both ears.", "Sudden, both ears, after a reversing beeper (Tuesday)", "onset"],
			["Any pain, dizziness or ringing?", 2, "No pain, no spinning, no ringing. Just... nothing. Total silence.", "No pain, dizziness or tinnitus", "red_flags"],
			["What's your favourite forklift?", 0, "Old Rumbles, bay six. She's a beauty. Purrs like a kitten.", "", ""],
		],
	},
	{
		"prompt": "Next question:",
		"options": [
			["Is the test for a work form?", 2, "My cousin Vinnie says you get paid leave for this. I mean: what form?", "Wants a form for paid leave from work", "form"],
			["How do you manage phone calls?", 1, "Fine, I just put it on speaker... I mean, I DON'T. Can't hear phones.", "Nearly said he uses the phone on speaker", "phone"],
			["Have you tried switching your ears off and on again?", 0, "Is that a thing? Hang on. *wiggles ears* Nope.", "", ""],
		],
	},
]

var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var screen: CanvasLayer
## The tone results from Hoot's run (§5.1), then the merged visit results (§9.5).
var tones: Dictionary = {}
var results: Dictionary = {}
## Familiarisation: the word ids used, and the ones dropped.
var words: Array[String] = []
var dropped: Array[String] = []
var _tell_said := false
var _session: SpeechSession   # only when the SPEECH screen is missing (Hoot's fallback run)


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", PATIENT_ID)
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, "MIKE LENDERS' VISIT", {&"srt_r": Palette.RIGHT_RED, &"srt_l": Palette.LEFT_BLUE})
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.speech_response.connect(_on_speech_response)
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
	Events.screenshot_requested.emit("day3_" + shot_name)


static func quick_visit() -> bool:
	if Game.cli_flag("quick"):
		return true
	if Game.cli_flag("full"):
		return false
	return bool(Game.settings.get("quick_visit", true))


func _run() -> void:
	await _intro()
	await _history()
	await _otoscopy()
	await _instructions()
	await _tones()
	var board: Control = await _familiarize()
	await _speech()
	await _evidence(board)
	await _referral(board)
	await _payoff(board)
	await _results()


# ---------------------------------------------------------------- 1. intro: the coffee whisper

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"chat")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	_react(&"wave")
	await _say("Mike", "Mike Lenders, forklift legend! I'm here about my ears. They're BROKEN. Totally.")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "Day 3, trainee: speech! Today we check if words agree with the beeps.")
	clinic.call("gus_look", &"camera")
	_react(&"confused")
	await _say("Mike", "I can't hear ANYTHING since the forklift beeped at work. Not a THING.")
	clinic.call("gus_look", &"hoot")
	await _say("Hoot", "...And the neck brace?")
	await _say("Mike", "Just in case.")
	await _say("Hoot", "(whispering) Would you like a coffee, Mike?")
	_react(&"nod")
	await _say("Mike", "Two sugars, thanks.")
	_react(&"startle")
	await _say("Mike", "I mean... WHAT?")
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Our job today: an accurate answer, not a gotcha. Questions first!")


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
		var tag := String(pick[4])
		if tag != "":
			tags[tag] = true
		_react(&"cheer" if int(pick[1]) == 0 else &"nod")
		await _say("Mike", String(pick[2]))
		if String(pick[3]) != "":
			hud.call("add_clue", String(pick[3]))
		if int(pick[1]) == 0:
			clinic.call("hoot_emote", &"facepalm")
			await _say("Hoot", "Fun, but not a clue. Ask about his hearing!")
		elif tag == "phone":
			await _say("Hoot", "Just write down exactly what he says. Facts, not guesses.")
		elif tag == "form":
			await _say("Hoot", "A form is fine. Our job stays the same: accurate results, whatever they show.")
	if not tags.has("red_flags"):
		await _say("Hoot", "Always ask about red flags too: pain, dizziness, ringing.")
		await _say("Mike", "No pain, no spinning, no ringing. Just... nothing. Total silence.")
		hud.call("add_clue", "No pain, dizziness or tinnitus")
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Sudden loss in both ears is a red flag. A doctor needs to know fast, if it's real.")
	hud.call("add_clue", "Sudden, both ears: a doctor must know fast.", "flag")
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
	await g.show_clear("right", "Mike's RIGHT ear: clear canal, healthy eardrum.")
	await _say("Hoot", "Look before you beep! Canals clear, eardrums normal. Nothing blocking the way in.")
	await _say("Mike", "See? Nothing in there. Not even the beep.")
	hud.call("add_clue", "Canals clear, eardrums look normal")
	g.queue_free()
	clinic.call("focus_camera", &"desk", 0.6)
	Game.record_medal("otoscopy", "gold")
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. instructions: beeps AND words

func _instructions() -> void:
	_phase(&"instructions")
	hud.call("set_step", &"explain")
	clinic.call("focus_camera", &"desk", 0.8)
	var good := "Press for every beep, even faint ones. Repeat every word, and guess if unsure."
	var opts: Array[String] = ["Only press or answer when you're totally sure.", good, "Shout every word as LOUD as you can."]
	var tries := 0
	while true:
		tries += 1
		var best := opts.find(good)
		var c: int = await dialogue.choose("Beeps AND words today. Tell Mike what to do:", opts, best)
		if c == best:
			break
		if opts[c].begins_with("Only"):
			_react(&"confused")
			await _say("Mike", "Totally sure? Oh, I'll be VERY careful. Super careful.")
			await _say("Hoot", "Too strict! Careful answers hide the faint ones. Try again.")
		else:
			_react(&"cheer")
			await _say("Mike", "CUPCAKE! RAINBOW! I LOVE this test!")
			await _say("Hoot", "Loud isn't the point! We need every word he hears, even faint ones.")
		opts.remove_at(c)
	Game.record_medal("instructions", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	Game.set_visit_flag("instructed", true)
	Game.set_visit_flag("instructed_first_try", tries == 1)
	await _say("Hoot", "Beeps AND words today. Repeat every word you hear, and guess if you're not sure.")
	_react(&"nod")
	await _say("Mike", "Guess? Got it. Not that I'll hear anything.")
	hud.call("complete_step", &"explain")


# ---------------------------------------------------------------- 5. tones: Hoot runs both ears

func _air_transducer() -> StringName:
	return &"inserts" if Game.has_upgrade("insert_earphones") else &"phones"


func _tone_test(ear: String, plan: Dictionary) -> void:
	plan["air_transducer"] = _air_transducer()
	_phase(&"audiometry", {"ear": ear, "test": "ac"})
	screen.call("start_test", patient, ear, false, plan)
	var r: Dictionary = await screen.test_finished
	tones = r
	results = r
	Game.set_audiometry_results(results)


func _tones() -> void:
	hud.call("set_step", &"beeps")
	clinic.call("focus_camera", &"booth", 1.2)
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.8)
	await _say("Hoot", "Earphones on! I'll run the beeps myself today, at top speed.")
	clinic.call("put_on_earphones", true)
	await _wait(0.6)
	screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate() as CanvasLayer
	add_child(screen)
	# Hoot runs both ears today, whatever the quick-visit setting (plan hoot_turn_after 0)
	screen.set("quick_visit", true)
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	await _tone_test("right", {"test": "ac", "hoot_turn_after": 0,
		"intro": "Beeps first. I'll run them; watch how Mike answers.",
		"hoot_turn_text": "My turn! Right ear at 8x. Watch the dance card!"})
	await _tone_test("left", {"test": "ac", "hoot_turn_after": 0,
		"intro": "Left ear, Hoot speed!",
		"hoot_turn_text": "Left ear at 8x. Same dance, other ear!"})
	screen.queue_free()
	screen = null
	cam.current = true
	hud.call("complete_step", &"beeps")
	clinic.call("focus_camera", &"face", 0.6)
	var avg := (ear_pta("right") + ear_pta("left")) * 0.5
	var about := SpeechRules.snap5(avg) if not is_nan(avg) else 70
	await _say("Hoot", "About %d dB in both ears. Severe, on paper. Yet he heard my whisper..." % about)
	_react(&"nod")
	await _say("Mike", "Severe! Write that down. In big letters.")


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


## The ear's PTA from Hoot's tones (as the SPEECH screen computes it). NAN before the tones.
func ear_pta(ear: String) -> float:
	if tones.is_empty():
		return NAN
	return SpeechRules.pta_for_speech(ClinicRules.best_thresholds(tones, ear, false))


# ---------------------------------------------------------------- 6. familiarise the word list

## Returns the board: the objection and the referral happen on it later.
func _familiarize() -> Control:
	_phase(&"familiarize")
	hud.call("set_step", &"words")
	await _say("Hoot", "Spondees: two-part words like cup-cake. Easy to guess, so they find the softest level fast.")
	var opts: Array[String] = ["Yes: go through the words together first.", "No: straight into the test."]
	var c: int = await dialogue.choose("Go through the word list with Mike first?", opts, 0)
	var said_yes := c == 0
	if said_yes:
		await _say("Hoot", "Good call! Familiarise first, or you test his vocabulary, not his hearing.")
	else:
		await _say("Hoot", "Familiarise first, or you test his vocabulary, not his hearing. Let's do it now.")
	var items: Array[Dictionary] = []
	for it: Dictionary in SpeechMaterial.items(LIST_ID):
		if items.size() < FAMILIAR_WORDS:
			items.append(it)
	words.clear()
	for it: Dictionary in items:
		words.append(String(it.get("id", "")))
	var b := MikeBoard.new()
	hud.call("add_game", b)
	await b.run_cards(items, SpeechMaterial.title(LIST_ID))
	var unknown := words.find(UNKNOWN_WORD)
	var last_known := (unknown - 1) if unknown > 0 else words.size() - 1
	b.read_along(0, last_known, 2.6)
	var texts: Array[String] = []
	for it: Dictionary in items.slice(0, mini(8, last_known + 1)):
		texts.append(String(it.get("text", "")))
	var first := ", ".join(PackedStringArray(texts.slice(0, 4)))
	var rest := ", ".join(PackedStringArray(texts.slice(4)))
	await _say("Mike", "%s... easy! %s..." % [_cap(first), _cap(rest)])
	if unknown >= 0:
		b.stumble(UNKNOWN_WORD)
		_react(&"confused")
		await _say("Mike", "Wind... mill? Never seen one. Is it a fan for a field?")
		await _say("Hoot", "Never seen a windmill? Drop it. Only use words they know.")
		_shot("familiarize", 0.4)
		await b.run_drop(UNKNOWN_WORD)
		dropped = b.dropped.duplicate()
		_react(&"nod")
		await _say("Mike", "The rest? Know 'em all. Not that I'll HEAR any of 'em.")
	var problems := (0 if said_yes else 1) + b.drop_slips
	Game.record_medal("familiarize", "gold" if problems == 0 else ("silver" if problems == 1 else "bronze"))
	Game.set_visit_flag("familiarized_first", said_yes)
	var t := b.create_tween()
	t.tween_property(b, "modulate:a", 0.0, 0.3)
	await t.finished
	b.visible = false
	hud.call("complete_step", &"words")
	return b


# ---------------------------------------------------------------- 7-8. SRT: the SPEECH screen

## The SPEECH screen plan for one ear (§9.7).
func speech_plan(ear: String) -> Dictionary:
	var plan := {"test": "srt", "tones": tones, "list": LIST_ID, "words": words.duplicate(), "transducer": String(_air_transducer())}
	if not dropped.is_empty():
		plan["exclude"] = dropped.duplicate()
	var start := SpeechRules.srt_start(ear_pta(ear))
	if ear == "right":
		plan["intro"] = "Start at his PTA plus 15: %d dB. He should repeat that easily." % start
	else:
		plan["intro"] = "Left ear, your turn! PTA plus 15 is %d dB." % start
		if quick_visit():
			plan["hoot_turn_after"] = LEFT_SOLO_WORDS
	return plan


func _speech() -> void:
	clinic.call("focus_camera", &"face", 0.6)
	# words are answered out loud: no response button today
	clinic.call("hold_response_button", false)
	await _say("Hoot", "Now the words. He repeats each one; you score what he SAID.")
	await _say("Hoot", "Got it: down 10. Missed: up 5. Same dance as the beeps!")
	var cam: Camera3D = clinic.call("get_main_camera")
	var packed: PackedScene = load(SPEECH_SCENE) as PackedScene if ResourceLoader.exists(SPEECH_SCENE) else null
	if packed != null:
		screen = packed.instantiate() as CanvasLayer
		add_child(screen)
		cam.current = false
	else:
		push_warning("LevelMike: no SPEECH screen (%s); Hoot runs the words himself" % SPEECH_SCENE)
	for ear: String in ["right", "left"]:
		hud.call("set_step", &"srt_r" if ear == "right" else &"srt_l")
		_phase(&"speech", {"ear": ear, "test": "srt"})
		var plan := speech_plan(ear)
		var r: Dictionary
		if screen != null:
			screen.call("start_test", patient, ear, ear == "right", plan)
			r = await screen.test_finished
		else:
			r = await _fallback_speech(ear, plan)
		results = r
		Game.set_audiometry_results(results)
		hud.call("complete_step", &"srt_r" if ear == "right" else &"srt_l")
	if screen != null:
		screen.queue_free()
		screen = null
	cam.current = true
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"face", 0.6)
	var sheet := srt_sheet("right")
	var agreement := StringName(String(sheet.get("agreement", "")))
	var gap := absi(int(sheet.get("diff", 0)))
	if agreement == &"poor":
		await _say("Hoot", "SRT should sit within 6 dB of the PTA. His is %d dB better. Poor agreement!" % gap)
		_react(&"confused")
		await _say("Mike", "Poor? Poor is bad, right? Bad is good for my form... I mean, oh no.")
	else:
		await _say("Hoot", "SRT should sit within 6 dB of the PTA. His is %d dB apart. Let's look closer." % gap)


## No SPEECH screen in this build: Hoot runs the ear by the textbook through SpeechSession
## (not scored), so the visit still has its SRTs.
func _fallback_speech(ear: String, plan: Dictionary) -> Dictionary:
	if _session == null:
		_session = SpeechSession.new(patient, Game.rng.randi())
		_session.configure(plan)
	hoot_runs_ear(_session, ear)
	await _wait(0.5)
	return SpeechSession.merge_results(tones, _session.build_results())


## Hoot runs one ear by the textbook (recommended_action), not scored. Returns the stored sheet.
static func hoot_runs_ear(session: SpeechSession, ear: String) -> Dictionary:
	session.scoring = false
	session.begin(ear, false)
	for i in 120:
		var act: Dictionary = session.recommended_action()
		var kind := StringName(String(act.get("action", "none")))
		if kind == &"score_correct" or kind == &"score_missed":
			session.score(kind == &"score_correct")
		elif kind == &"louder" or kind == &"softer":
			session.set_level(int(act.get("target_db", session.db)))
		elif kind == &"mask_toggle":
			session.toggle_mask()
		elif kind == &"present":
			session.present()
		elif kind == &"store":
			return session.store()
		else:
			break
	return {}


## The stored SRT sheet of one ear from the merged results ({} when missing).
func srt_sheet(ear: String) -> Dictionary:
	var sp: Dictionary = results.get("speech", {})
	return (sp.get("srt", {}) as Dictionary).get(ear, {})


## "The tell": Mike repeats a word far below his own beeps (once per visit).
func _on_speech_response(ear: String, test: StringName, db: int, answer: Dictionary) -> void:
	if _tell_said or test != &"srt" or StringName(String(answer.get("kind", ""))) != &"correct":
		return
	var pta := ear_pta(ear)
	if is_nan(pta) or pta - float(db) < float(TELL_GAP_DB):
		return
	_tell_said = true
	Hoot.say("He's repeating words %d dB below his beeps. Hmm!" % SpeechRules.snap5(pta - float(db)), Hoot.HIGH, "speech_response", "mike_tell")


# ---------------------------------------------------------------- 9. evidence: OBJECTION!

## The claim card and the three clues, with this visit's real numbers.
func objection_cards() -> Array:
	var sheet := srt_sheet("right")
	var srt := int(sheet.get("stored_db", 30))
	var pta := float(sheet.get("pta", ear_pta("right")))
	if is_nan(pta):
		pta = 72.0
	var pta_i := roundi(pta)
	var agreement := String(sheet.get("agreement", "poor"))
	var gap := absi(srt - pta_i)
	var claim := {
		"quote": "I can't hear ANYTHING", "who": "Mike Lenders, 41, forklift driver", "speaker": "Mike",
		"verdict": "Words came back %d dB softer than his beeps." % gap,
		"note": "%s agreement: recheck, and record the facts kindly." % agreement.capitalize(),
	}
	var clues: Array[Dictionary] = [
		{"id": "coffee", "title": "Answered a whispered coffee offer", "best": false,
			"sub": "\"Two sugars, thanks.\" Funny, but a whisper in a room isn't a measurement.",
			"why": "Good spot! But a whisper isn't calibrated. Which clue is a real measurement?"},
		{"id": "srt_pta", "title": "SRT %d vs PTA %d" % [srt, pta_i], "best": true,
			"sub": "Right ear: words at %d dB, beeps at %d. %s agreement." % [srt, pta_i, agreement.capitalize()],
			"why": ""},
		{"id": "canals", "title": "Canals clear", "best": false,
			"sub": "Nothing blocking the sound. But clear canals are normal for most real losses too.",
			"why": "Clear canals fit lots of real losses. Which clue measures his hearing?"},
	]
	return [claim, clues]


func _evidence(b: Control) -> void:
	_phase(&"evidence")
	hud.call("set_step", &"case")
	var cards := objection_cards()
	var clues: Array[Dictionary] = cards[1]
	b.call("show_objection", cards[0], clues)
	b.visible = true
	var t := b.create_tween()
	t.tween_property(b, "modulate:a", 1.0, 0.3)
	await _say("Hoot", "Case time! Mike says he can't hear anything. Which clue checks that best?")
	await b.call("run_objection")
	_shot("objection", 0.6)
	var picks: Array[String] = b.get("picks")
	var first := picks[0] if not picks.is_empty() else "srt_pta"
	Game.record_medal("evidence", "gold" if first == "srt_pta" else ("silver" if first == "coffee" else "bronze"))
	await _wait(1.0)
	var sheet := srt_sheet("right")
	await _say("Hoot", "Real measurements! Words at %d dB, beeps at %d. The two tests disagree." % [int(sheet.get("stored_db", 30)), roundi(float(sheet.get("pta", 72.0)))])
	await _say("Hoot", "We don't know WHY yet. And we don't guess.")
	hud.call("complete_step", &"case")


# ---------------------------------------------------------------- 10. referral: recheck + objective tests

func _referral(b: Control) -> void:
	_phase(&"referral")
	hud.call("set_step", &"next")
	b.call("set_referral_mode", true)
	var good := "Re-instruct, retest, refer for objective tests."
	var opts: Array[String] = ["Fit strong hearing aids today.", good, "Call him a fibber."]
	var tries := 0
	while true:
		tries += 1
		var c: int = await dialogue.choose("What's next for Mike?", opts, opts.find(good))
		if opts[c] == good:
			break
		if opts[c].begins_with("Fit"):
			await _say("Hoot", "Not on results we can't trust. Aids need reliable thresholds first.")
		else:
			clinic.call("hoot_emote", &"gasp")
			await _say("Hoot", "Never accuse! Non-organic loss has many causes. Stay kind and record the facts.")
		opts.remove_at(c)
	Game.record_medal("referral", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Re-instruct, retest, and refer for objective tests that don't need his answers. Stamp it!")
	await b.call("run_stamp")
	_shot("stamp")
	hud.call("complete_step", &"next")


# ---------------------------------------------------------------- 11. the confession and GLAZED?!

func _payoff(b: Control) -> void:
	await _wait(0.6)
	var t := b.create_tween()
	t.tween_property(b, "modulate:a", 0.0, 0.35)
	await t.finished
	b.queue_free()
	await clinic.call("focus_camera", &"face", 0.5)
	_react(&"confused")
	await _say("Mike", "Objective tests? The kind where I don't have to answer anything?")
	await _say("Hoot", "Exactly. Tiny sounds, tiny sensors. Your ears do all the talking.")
	_react(&"wince")
	await _say("Mike", "...Okay. Cousin Vinnie said if I acted deaf, I'd get paid leave. My ears are fine.")
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Thank you for telling us, Mike. That took guts.")
	await _say("Hoot", "Honest ears earn honest results. And SRT keeps everyone honest, including us.")
	await _say("Mike", "The neck brace goes back to Vinnie too.")
	clinic.call("focus_camera", &"door", 1.6)
	_shot("goodbye", 1.6)
	await clinic.call("walk_out")
	await _say("Hoot", "(whispering) Psst... free donuts in the break room.")
	await clinic.call("peek_in")
	_shot("glazed", 0.1)
	await _say("Mike", "GLAZED?!")
	clinic.call("hoot_emote", &"cheer")
	await _say("Hoot", "Second shelf, Mike. Enjoy! Lovely, kind work today, trainee.")
	await clinic.call("walk_out")


# ---------------------------------------------------------------- 12. results

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
