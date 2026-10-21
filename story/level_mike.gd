extends Node
## LevelMike (Speech): Day 3, "SRT" (speech recognition threshold). Mike Lenders, 41, forklift
## driver, who says he can't hear ANYTHING. Design: docs/CHAPTER3.md; contracts: CONTRACTS.md §3.1
## and §9.8. Every blocking beat emits Events.awaiting_input with a solver. The game never calls
## him a liar: it records the facts, stays kind and refers him on (doctor included).
##   world:  res://world/clinic.tscn with patient_id = "mike" (§6 + the Speech extras)
##   ui:     res://ui/audiometer/audiometer_screen.tscn (Hoot runs both tone ears)
##           res://ui/speech/speech_screen.tscn start_test(patient, ear, coached, plan) (§9.7)
##   global: Game (visit, medals, scores), Events (phases, awaiting_input), Hoot (tips)
## Beats: the movie's own explainer beat (or a choice on replays), dialogue, choice,
## familiarize_cards, the SPEECH screen's speech beats, objection_present, referral_stamp,
## results_continue. Board: story/games/mike_board.gd. (Clinical review S7) The day opens with
## Hoot's spondee movie (story/explainers/movies/srt_ladder.gd), played as Day 4 plays its own.

const Hud := preload("res://story/hud.gd")
const MikeBoard := preload("res://story/games/mike_board.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const Movies := preload("res://story/explainers/movies.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const SPEECH_SCENE := "res://ui/speech/speech_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_mike.tscn"
const EXPLAINER_SCENE := "res://story/explainers/explainer_player.tscn"
const PATIENT_ID := "mike"
## (Clinical review S7) Hoot's spondee movie, The Spondee Ladder.
const MOVIE_ID := "srt_ladder"

## The spondee list, how many cards Hoot says for Mike to repeat, and the one he has never heard of.
const LIST_ID := "spondee_a"
const FAMILIAR_WORDS := 12
const UNKNOWN_WORD := "windmill"
## Seconds for Hoot and Mike to go through the known cards (a short step: the player may click on).
const SAY_ALONG_S := 4.4
## Mike says back this many of them in his dialogue line (the rest are on the cards).
const ECHO_WORDS := 8
## Hoot's 1 kHz retest after the right-ear montage comes back this much BETTER than the first 1 kHz
## result: past ClinicRules.RETEST_TOLERANCE_DB (5), a test-retest mismatch, one more sign of a
## non-organic loss. Mike's simulated tones are steady, so the level derives the retest from the
## measured result (the shared tone code is left as it is).
const RETEST_BETTER_DB := 15
## The solo (second, normally left) ear on a quick visit: the player scores words down to Mike's
## first miss below his SRT (down 10 per hit from PTA + 15: eight words) and the step back up 5,
## then Hoot finishes the bracket (plan hoot_turn_after_up). This many words is the cap, for a
## descent that never misses.
const LEFT_SOLO_WORDS := 12
## (Clinical review A1, all days) The routine around the test, short and ungraded, in the cases'
## own words (story/level_case.gd ROUTINE_LINE and OTHER_EAR_CAPTION); Days 4 and 5 use these too.
## Once a visit, before the first tone test: the morning listening check, the response button and
## the dials out of the patient's view. At the otoscope: a fresh speculum (%s: the patient, then the
## ear in capitals).
const ROUTINE_LINE := "This morning's listening check: every beep clean, the button works. Dials stay out of view."
const SPECULUM_CAPTION := "Fresh speculum. %s's %s ear: clear canal, healthy eardrum."

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
## Hoot's right-ear 1 kHz retest (retest_1k(); {} before the tones).
var tone_retest: Dictionary = {}
## Familiarisation: the word ids used, and the ones dropped.
var words: Array[String] = []
var dropped: Array[String] = []
## Hoot's by-the-book rerun of the right ear when the player's SRT can't show the mismatch
## ({} when none): the board uses it; the player's own sheet stays in results for the grade.
var recheck: Dictionary = {}
## Hoot's coffee whisper has been on screen: from then on a low (ascending) SRT start is smart.
var _whisper_seen := false
## The movie reached its seen_at scene this visit (lines may refer to it).
var _movie_watched := false
var _session: SpeechSession   # only when the SPEECH screen is missing (Hoot's fallback run)


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", PATIENT_ID)
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	_set_hud_steps("right")
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.level_started.emit(PATIENT_ID)
	_run.call_deferred()


## The visit's steps on the HUD, with the SRT ears in test order (`first` ear first).
func _set_hud_steps(first: String) -> void:
	hud.call("set_steps", steps_for(first), STEP_LABELS, "MIKE LENDERS' VISIT", {&"srt_r": Palette.RIGHT_RED, &"srt_l": Palette.LEFT_BLUE})


## STEPS with the SRT ears in test order: "SRT L" before "SRT R" when the left goes first.
static func steps_for(first: String) -> Array[StringName]:
	var out: Array[StringName] = STEPS.duplicate()
	if first == "left":
		var i := out.find(&"srt_r")
		out[i] = &"srt_l"
		out[i + 1] = &"srt_r"
	return out


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
	await _movie()
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


# ---------------------------------------------------------------- 0. the movie (contract §9.20)

## (Clinical review S7) Hoot's spondee movie, played as Day 4 plays its own (level_nora._movie): a
## one-line announcement before the first play only; once seen, just the replay offer (best: skip).
func _movie() -> void:
	if not Movies.has(MOVIE_ID):
		return
	var seen := Game.is_movie_seen(MOVIE_ID)
	_phase(&"explainer", {"movie": MOVIE_ID, "source": "day_start", "seen": seen})
	clinic.call("focus_camera", &"door", 0.0)
	if seen:
		var opts: Array[String] = ["Roll the film! (about %d s)" % int(roundf(Movies.total_s(MOVIE_ID) / 10.0) * 10.0),
			"Skip it: I know my spondees."]
		var c: int = await dialogue.choose("Hoot's spondee movie again? Popcorn's on me!", opts, 1)
		if c != 0:
			return
	else:
		await _say("Hoot", "New trick today: SPEECH THRESHOLDS. A quick cartoon first, then our next patient!")
	var r := await _play_movie(MOVIE_ID)
	_movie_watched = bool(r.get("watched", not bool(r.get("skipped", false))))
	Game.set_visit_flag("movie_watched", _movie_watched)
	if bool(r.get("skipped", false)):
		await _say("Hoot", "Skipped! Rewatch it any time: pause menu, \"Watch %s\"." % Movies.title(MOVIE_ID))


func _play_movie(id: String) -> Dictionary:
	var player: Node = (load(EXPLAINER_SCENE) as PackedScene).instantiate()
	add_child(player)
	var r: Dictionary = await player.call("play", id, "day_start")
	player.queue_free()
	return r


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
	_whisper_seen = true
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
	await g.show_clear("right", SPECULUM_CAPTION % ["Mike", "RIGHT"])
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
			await _say("Mike", "RAINBOW! LIGHTHOUSE! I LOVE this test!")
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
	# Hoot runs both ears today, whatever the quick-visit setting (plan hoot_turn_after 0); set it
	# per ear, since the pause menu's Quick visit toggle updates the screen in between
	screen.set("quick_visit", true)
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
	await _say("Hoot", ROUTINE_LINE)
	await _say("Hoot", "Earphones on! I'll run the beeps myself today, at top speed.")
	clinic.call("put_on_earphones", true)
	await _wait(0.6)
	screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate() as CanvasLayer
	add_child(screen)
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	# a few-second montage per ear (as on Day 2): the beeps aren't today's lesson
	await _tone_test("right", {"test": "ac", "hoot_turn_after": 0, "montage": true, "skip_hoot_retest": true,
		"intro": "Beeps first. I'll run them; watch the stamps fly in.",
		"hoot_turn_text": "My turn! Right ear at 8x. Watch the dance card!"})
	await _retest_right_1k()
	await _tone_test("left", {"test": "ac", "hoot_turn_after": 0, "montage": true, "skip_hoot_retest": true,
		"intro": "Left ear, Hoot speed!",
		"hoot_turn_text": "Left ear at 8x. Same dance, other ear!"})
	_record_retest()
	screen.queue_free()
	screen = null
	cam.current = true
	hud.call("complete_step", &"beeps")
	clinic.call("focus_camera", &"face", 0.6)
	var avg := (ear_pta("right") + ear_pta("left")) * 0.5
	var about := SpeechRules.snap5(avg) if not is_nan(avg) else 70
	# the degree from the game's own scale (ClinicRules), for the number Hoot says
	var degree := ClinicRules.degree_name(float(about))
	await _say("Hoot", "About %d dB in both ears. %s, on paper. Yet he heard my whisper..." % [about, _cap(degree)])
	await _say("Hoot", pta_line())
	_react(&"nod")
	if degree.begins_with("moderately "):
		await _say("Mike", "Severe! Write that down. In big letters. Skip the 'moderately'.")
	else:
		await _say("Mike", "%s! Write that down. In big letters." % _cap(degree))


## The right ear's 1 kHz retest from Hoot's tone results: the first 1 kHz result minus
## RETEST_BETTER_DB, in the §5.1 retest_1k shape (plus by_hoot). {} when 1 kHz wasn't measured.
static func retest_1k(tone_results: Dictionary) -> Dictionary:
	var ac := ClinicRules.sheet_thresholds(tone_results, "right", &"ac")
	if not ac.has(ClinicRules.START_FREQ):
		return {}
	var first := int(ac[ClinicRules.START_FREQ])
	var again := maxi(ClinicRules.MIN_DB, first - RETEST_BETTER_DB)
	return {"first_db": first, "stored_db": again, "diff": first - again, "strokes": 0, "par": 0, "by_hoot": true}


## Hoot's remark on the retest: the numbers and the 5 dB rule, never a verdict on Mike.
static func retest_remark(rt: Dictionary) -> String:
	return "1000 Hz again: %d dB, %d better than before. Retests usually agree within %d dB." % [
		int(rt.get("stored_db", 0)), int(rt.get("diff", 0)), ClinicRules.RETEST_TOLERANCE_DB]


## After the right-ear montage: Hoot retests 1 kHz and it comes back better (test-retest mismatch).
func _retest_right_1k() -> void:
	tone_retest = retest_1k(tones)
	if tone_retest.is_empty():
		return
	await _say("Hoot", retest_remark(tone_retest))
	_react(&"wince")
	await _say("Mike", "Must be the earphones warming up. Happens to my forklift too.")


## The retest goes on the record (results.ears.right.retest_1k), next to Hoot's first 1 kHz stamp;
## the PTA keeps the first one (the two disagree by more than ClinicRules.RETEST_TOLERANCE_DB).
func _record_retest() -> void:
	if tone_retest.is_empty() or not (tones.get("ears", {}) as Dictionary).has("right"):
		return
	((tones["ears"] as Dictionary)["right"] as Dictionary)["retest_1k"] = tone_retest.duplicate()
	results = tones
	Game.set_audiometry_results(results)


## Hoot's PTA definition, true to the average the speech tests use (SpeechRules.pta_method).
func pta_line() -> String:
	var best_two := false
	if not tones.is_empty():
		for e: String in ["right", "left"]:
			best_two = best_two or SpeechRules.pta_method(ClinicRules.best_thresholds(tones, e, false)) == "best two"
	if best_two:
		return "That's his PTA, pure-tone average: his best two beeps of 500, 1000 and 2000 Hz, averaged."
	return "That's his PTA, pure-tone average: his beeps at 500, 1000 and 2000 Hz, averaged."


static func _cap(s: String) -> String:
	return s.left(1).to_upper() + s.substr(1)


## The ear's PTA from Hoot's tones (as the SPEECH screen computes it). NAN before the tones.
func ear_pta(ear: String) -> float:
	if tones.is_empty():
		return NAN
	return SpeechRules.pta_for_speech(ClinicRules.best_thresholds(tones, ear, false))


# ---------------------------------------------------------------- 6. familiarise the word list

## Mike's line while he says the cards back after Hoot (the first ECHO_WORDS; all of them are on
## the cards): "Lighthouse! Rainbow! Sunbeam! Bookshelf! Easy! Moonlight! ...".
static func echo_line(items: Array) -> String:
	var said: Array[String] = []
	for it: Variant in items.slice(0, ECHO_WORDS):
		said.append(_cap(String((it as Dictionary).get("text", ""))))
	var first := "! ".join(PackedStringArray(said.slice(0, 4)))
	var rest := "! ".join(PackedStringArray(said.slice(4)))
	return "%s! Easy! %s..." % [first, rest] if rest != "" else "%s! Easy!" % first


## Returns the board: the objection and the referral happen on it later.
func _familiarize() -> Control:
	_phase(&"familiarize")
	hud.call("set_step", &"words")
	await _say("Hoot", "Spondees: two-part words, equal stress on both parts, like rain-bow. Chosen because they're equally easy to hear.")
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
	# by ear, not by eye: Hoot says each word, Mike says it back, and the cards face Hoot (the
	# board's "Mike can't see this" sign); every word is on the cards and the "now saying" line
	await _say("Hoot", "I'll say each word, nice and loud. You say it back. No peeking: the cards face me!")
	var unknown := words.find(UNKNOWN_WORD)
	var last_known := (unknown - 1) if unknown > 0 else words.size() - 1
	b.say_along(0, last_known, SAY_ALONG_S)
	_react(&"nod")
	await _say("Mike", echo_line(items.slice(0, last_known + 1)))
	b.finish_say_along()   # the player may click on before the sweep ends
	if unknown >= 0:
		b.say_word(UNKNOWN_WORD, "Wind... mill?")
		b.stumble(UNKNOWN_WORD)
		_react(&"confused")
		await _say("Mike", "Wind... mill? Never seen one. Is it a fan for a field?")
		await _say("Hoot", "Never seen a windmill? Drop it. Only use words they know.")
		_shot("familiarize", 0.4)
		await b.run_drop(UNKNOWN_WORD)
		dropped = b.dropped.duplicate()
		_react(&"nod")
		await _say("Mike", "The rest? Know 'em all. Not that I'll HEAR any of 'em.")
	# his instructions for the SRT: the answers come from this list
	await _say("Hoot", "Every test word comes from this list, Mike. Say back what you hear, and guess if unsure.")
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

## The SRT ear order (clinical review S6): the better ear first, by the lower tone PTA, right on a
## tie. The first ear is the coached one; Mike's right is normally the better (71.7 against 73.3).
func srt_ears() -> Array[String]:
	return SpeechRules.ears_better_first(ear_pta("right"), ear_pta("left"))


## Hoot's lead-in on the first SRT ear: the better one by name, else the ear srt_ears() picks (a tie,
## or a missing PTA).
func first_ear_lead() -> String:
	var r := ear_pta("right")
	var l := ear_pta("left")
	var first: String = srt_ears()[0]
	if is_nan(r) or is_nan(l) or is_equal_approx(r, l):
		return "%s ear first." % _cap(first)
	return "Better ear first: the %s." % first


## The SPEECH screen plan for one ear (§9.7).
func speech_plan(ear: String) -> Dictionary:
	var plan := {"test": "srt", "tones": tones, "list": LIST_ID, "words": words.duplicate(), "transducer": String(_air_transducer())}
	if not dropped.is_empty():
		plan["exclude"] = dropped.duplicate()
	# once the coffee whisper has been on screen, starting below his beeps is smart, not a slip
	plan["low_start_ok"] = _whisper_seen
	var start := SpeechRules.srt_start(ear_pta(ear))
	if ear == srt_ears()[0]:
		plan["intro"] = "%s Start at his PTA plus 15: %d dB, easy to repeat." % [first_ear_lead(), start]
	elif quick_visit():
		plan["intro"] = "%s ear: yours to the first miss and back up 5! PTA plus 15 is %d dB." % [_cap(ear), start]
		plan["hoot_turn_after"] = LEFT_SOLO_WORDS
		plan["hoot_turn_after_up"] = true
	else:
		plan["intro"] = "%s ear, your turn! PTA plus 15 is %d dB." % [_cap(ear), start]
	return plan


func _speech() -> void:
	clinic.call("focus_camera", &"face", 0.6)
	# words are answered out loud: no response button today
	clinic.call("hold_response_button", false)
	await _say("Hoot", "SRT, speech recognition threshold: the softest level where he repeats at least two words, half or more.")
	await _say("Hoot", "Now the words. He repeats each one; you score what he SAID.")
	# the same-level rule (SpeechRules.SRT_MAX_WORDS_PER_LEVEL), as the wrong-step tip says
	await _say("Hoot", "Got it: down 10. Missed: up 5. Another word at the same level is fine too!")
	# (clinical review S5) one common routine, not the only one
	await _say("Hoot", "Down 10, up 5 is one common way, not the only method.")
	var cam: Camera3D = clinic.call("get_main_camera")
	var packed: PackedScene = load(SPEECH_SCENE) as PackedScene if ResourceLoader.exists(SPEECH_SCENE) else null
	if packed != null:
		screen = packed.instantiate() as CanvasLayer
		add_child(screen)
		cam.current = false
	else:
		push_warning("LevelMike: no SPEECH screen (%s); Hoot runs the words himself" % SPEECH_SCENE)
	recheck = {}
	# better ear first (S6); Hoot coaches the first ear
	var order := srt_ears()
	if order[0] != "right":
		_set_hud_steps(order[0])
	for ear: String in order:
		hud.call("set_step", &"srt_r" if ear == "right" else &"srt_l")
		_phase(&"speech", {"ear": ear, "test": "srt"})
		var plan := speech_plan(ear)
		var r: Dictionary
		if screen != null:
			screen.call("start_test", patient, ear, ear == order[0], plan)
			r = await screen.test_finished
		else:
			r = await _fallback_speech(ear, plan)
		results = with_recheck(r)
		Game.set_audiometry_results(results)
		if ear == "right" and not _srt_shows_mismatch(srt_sheet("right")):
			await _recheck_right()
			results = with_recheck(results)
			Game.set_audiometry_results(results)
		hud.call("complete_step", &"srt_r" if ear == "right" else &"srt_l")
	if screen != null:
		screen.queue_free()
		screen = null
	cam.current = true
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"face", 0.6)
	var sheet := board_sheet()
	var diff := int(sheet.get("diff", 0))   # SRT - PTA: below zero, his words beat his beeps
	var within := "SRT should sit within %d dB of the PTA." % SpeechRules.AGREE_GOOD_DB
	var poor := StringName(String(sheet.get("agreement", ""))) == &"poor"
	if poor and diff < 0:
		await _say("Hoot", "%s His is %d dB better. Poor agreement!" % [within, -diff])
		_react(&"confused")
		await _say("Mike", "Poor? Poor is bad, right? Bad is good for my form... I mean, oh no.")
	elif poor:
		# words WORSE than beeps point elsewhere (never at his story)
		await _say("Hoot", "%s His is %d dB worse. Poor agreement!" % [within, diff])
		await _say("Hoot", "Words worse than beeps? Think instructions, language or word scores.")
	else:
		await _say("Hoot", "%s His is %d dB apart. Let's look closer." % [within, absi(diff)])


## The visit results with Hoot's recheck on the record when he ran one (speech.recheck {srt: {right}},
## §9.5): the paper notes it; the sheets and the grade stay the player's.
func with_recheck(r: Dictionary) -> Dictionary:
	if recheck.is_empty() or not (r.get("speech", null) is Dictionary):
		return r
	var out := r.duplicate()
	var sp: Dictionary = (out["speech"] as Dictionary).duplicate()
	sp["recheck"] = {"srt": {"right": recheck.duplicate(true)}}
	out["speech"] = sp
	return out


## The right SRT can carry the board only when it shows the mismatch for real: poor agreement,
## words BETTER than beeps, and the stored level is the bracketed SRT (candidate == stored).
static func _srt_shows_mismatch(sheet: Dictionary) -> bool:
	return StringName(String(sheet.get("agreement", ""))) == &"poor" and int(sheet.get("diff", 0)) < 0 \
		and SpeechScreen.is_bracketed(sheet)


## Hoot says why he reruns the right ear, true to the player's sheet (18 words max).
static func recheck_line(sheet: Dictionary) -> String:
	if not SpeechScreen.is_bracketed(sheet):
		var cand := int(sheet.get("candidate_db", SpeechRules.NO_SRT))
		if cand != SpeechRules.NO_SRT and cand != int(sheet.get("stored_db", cand)):
			return "The bracket said %d dB, not that one. I'll recheck the right ear by the book." % cand
		return "That SRT didn't get a full bracket. I'll recheck the right ear by the book."
	for k: Variant in sheet.get("errors", []):
		if String(k) == "misscored":
			return "Some scores didn't match what he said. I'll recheck the right ear by the book."
	return "Let's be sure of that one. I'll recheck the right ear by the book."


## The player's right SRT can't carry the board: Hoot says why, then reruns the ear.
func _recheck_right() -> void:
	await _say("Hoot", recheck_line(srt_sheet("right")))
	await rerun_right()


## Hoot reruns the right ear by the book on a FRESH session (the SPEECH screen's plan
## fresh_session, else SpeechSession directly) into `recheck`: the board uses his sheet, while
## the player's own sheet stays in results for the grade.
func rerun_right() -> void:
	var plan := speech_plan("right")
	plan.erase("intro")
	plan.erase("hoot_turn_after_up")
	plan["hoot_turn_after"] = 0
	plan["fresh_session"] = true
	plan["hoot_turn_text"] = "Right ear again, by the book, at 8x. Watch the ladder!"
	plan["done_title"] = "HOOT'S RECHECK"
	recheck = {}
	if screen != null:
		# Hoot runs it whatever the quick-visit setting (as for the tones); then the setting is back
		screen.set("quick_visit", true)
		screen.call("start_test", patient, "right", false, plan)
		var r: Dictionary = await screen.test_finished
		screen.set("quick_visit", quick_visit())
		recheck = ((r.get("speech", {}) as Dictionary).get("srt", {}) as Dictionary).get("right", {})
	if recheck.is_empty():
		var s := SpeechSession.new(patient, Game.rng.randi())
		s.configure(plan)
		recheck = hoot_runs_ear(s, "right")


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


## The SRT the board and Hoot's verdict use: his recheck when he ran one, else the player's right ear.
func board_sheet() -> Dictionary:
	return recheck if not recheck.is_empty() else srt_sheet("right")


# ---------------------------------------------------------------- 9. evidence: OBJECTION!

## The claim card and the three clues, with this visit's real numbers (board_sheet(): Hoot's
## recheck when he ran one). The measurement is always the best clue; the coffee and canals
## captions stay neutral (their "why" explains after a wrong pick).
func objection_cards() -> Array:
	var sheet := board_sheet()
	var by_hoot := not recheck.is_empty()
	var srt := int(sheet.get("stored_db", 30))
	var pta := float(sheet.get("pta", ear_pta("right")))
	if is_nan(pta):
		pta = 72.0
	var pta_i := roundi(pta)
	var agreement := String(sheet.get("agreement", "poor"))
	var gap := absi(srt - pta_i)
	var verdict := "Words and beeps line up."
	if srt < pta_i:
		verdict = "Words came back %d dB softer than his beeps." % gap
	elif srt > pta_i:
		verdict = "Words needed %d dB more than his beeps." % gap
	var claim := {
		"quote": "I can't hear ANYTHING", "who": "Mike Lenders, 41, forklift driver", "speaker": "Mike",
		"verdict": verdict, "note": claim_note(agreement, srt - pta_i),
	}
	var clues: Array[Dictionary] = [
		{"id": "coffee", "title": "Answered a whispered coffee offer", "best": false,
			"sub": "\"Two sugars, thanks.\" Hoot whispered it at the desk.",
			"why": "Good spot! But a whisper isn't calibrated. Which clue is a real measurement?"},
		{"id": "srt_pta", "title": ("Hoot's recheck: SRT %d vs PTA %d" if by_hoot else "SRT %d vs PTA %d") % [srt, pta_i], "best": true,
			"sub": "%s: words at %d dB, beeps at %d. %s agreement." % ["Right ear, rerun by the book" if by_hoot else "Right ear", srt, pta_i, agreement.capitalize()],
			"why": ""},
		{"id": "canals", "title": "Canals clear", "best": false,
			"sub": "Otoscopy, both ears: clear canals, normal-looking eardrums.",
			"why": "Clear canals fit lots of real losses. Which clue measures his hearing?"},
	]
	return [claim, clues]


## The claim card's last line, by agreement and direction (diff = SRT - PTA).
static func claim_note(agreement: String, diff: int) -> String:
	if agreement == "poor" and diff < 0:
		return "Poor agreement: words beat beeps. Record the facts kindly."
	if agreement == "poor":
		return "Poor agreement: words worse. Check instructions, language."
	return "%s agreement: recheck, and record the facts kindly." % agreement.capitalize()


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
	var sheet := board_sheet()
	var lead := "My recheck, by the book!" if not recheck.is_empty() else "Real measurements!"
	var words_beeps := "%s Words at %d dB, beeps at %d." % [lead, int(sheet.get("stored_db", 30)), roundi(float(sheet.get("pta", 72.0)))]
	if _srt_shows_mismatch(sheet):
		await _say("Hoot", words_beeps + " The two tests disagree.")
	else:
		# (only if even Hoot's recheck can't show it) never pretend the numbers settle the claim
		await _say("Hoot", words_beeps)
		await _say("Hoot", "On paper that doesn't settle it. His story still doesn't add up, so we recheck.")
	await _say("Hoot", "We don't know WHY yet. And we don't guess.")
	hud.call("complete_step", &"case")


# ---------------------------------------------------------------- 10. referral: recheck + objective tests + his doctor

func _referral(b: Control) -> void:
	_phase(&"referral")
	hud.call("set_step", &"next")
	b.call("set_referral_mode", true)
	var good := "Re-instruct, retest, objective tests, tell his doctor."
	var opts: Array[String] = ["Fit strong hearing aids today.", good, "Call him a fibber."]
	var tries := 0
	while true:
		tries += 1
		var c: int = await dialogue.choose("What's next for Mike?", opts, opts.find(good))
		if opts[c] == good:
			break
		if opts[c].begins_with("Fit"):
			await _say("Hoot", "Not on results we can't trust. And a sudden loss sees a doctor before any hearing aid.")
		else:
			clinic.call("hoot_emote", &"gasp")
			await _say("Hoot", "Never accuse! Non-organic loss has many causes. Stay kind and record the facts.")
		opts.remove_at(c)
	Game.record_medal("referral", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	clinic.call("hoot_emote", &"nod")
	# the sudden-loss red flag from the case history is closed here
	await _say("Hoot", "Re-instruct, retest, objective tests that don't need his answers, and his doctor hears about the sudden loss today.")
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
	# his own words, no more than the test showed: an SRT of 30 is an upper bound on his hearing, never "fine ears"
	await _say("Mike", "...Okay. Cousin Vinnie said to say I can't hear, for paid leave. I can hear you fine.")
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Thank you for telling us, Mike. That took guts.")
	# the main path must not teach "non-organic = faking"
	await _say("Hoot", "Non-organic loss has many causes: money, stress, worry, even a real loss underneath.")
	await _say("Hoot", "We can't tell which from the booth, so we never accuse.")
	await _say("Hoot", "We'll still finish the objective tests and send your results to your doctor.")
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
