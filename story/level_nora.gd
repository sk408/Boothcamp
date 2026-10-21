extends Node
## LevelNora (Speech): Day 4, "Word recognition (WRS)". Nora Nightingale, 58, choir director, whose
## left ear "has gone like a radio between stations": she hears the voices, not the words. Design:
## docs/CHAPTER4.md (beat by beat, §3); contracts: CONTRACTS.md §3.1, §9.20 (the movies) and §9.21
## (the plans). Every blocking beat emits Events.awaiting_input with a solver. Nobody names a
## diagnosis: the day measures carefully, raises the red flags and refers her to an ear doctor.
##   world:  res://world/clinic.tscn with patient_id = "nora"
##   ui:     res://ui/audiometer/audiometer_screen.tscn (Hoot runs every tone test, x8)
##           res://ui/speech/speech_screen.tscn: the SRTs (Hoot's off-screen run on a quick visit),
##           then WORD mode, one start_test per word list (Word list 1 to 4, in play order, D25)
##   board:  res://story/games/nora_board.gd (the Red-Flag Roll Call, the stamp tray, the letter)
##   paper:  the Daily Decibel with res://story/papers/paper_word_golf.gd as its sports column
## Beats: the movie's own explainer beat (or a choice on replays), dialogue, choice, the SPEECH
## screen's speech / lens_try / call_it beats, flag_pick, the stamp's choice, results_continue.
## (Clinical review A1-A5) The verdicts are the mode's: "her tones predict at least {min}%"
## (A1), rollover by the index (A2), the ears "too far apart for chance" (A3); this file adds A5's
## recorded-list line, "Slow still counts when one ear lags", and "loud enough for every sound".

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const NoraBoard := preload("res://story/games/nora_board.gd")
const LevelMike := preload("res://story/level_mike.gd")
const CaseData := preload("res://story/case_data.gd")
const Voice := preload("res://story/voice.gd")
const Movies := preload("res://story/explainers/movies.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const SPEECH_SCENE := "res://ui/speech/speech_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_nora.tscn"
const EXPLAINER_SCENE := "res://story/explainers/explainer_player.tscn"
const SPORTS_SCRIPT := "res://story/papers/paper_word_golf.gd"
const PATIENT_ID := "nora"
const MOVIE_ID := "letter_choir"
const MASKING_MOVIE := "masking"
## Her voice (story/voice.gd is not edited: registered at runtime, CHAPTER4 §14).
const VOICE := {"f0": 230.0, "wobble": 0.09}

## The player's words per list on a quick visit; Hoot scores the rest at top speed (CHAPTER4 §3.1).
const QUICK_WORDS: Dictionary[StringName, int] = {&"right": 8, &"left": 8, &"redo": 5, &"louder": 5}
## Hoot's masked bone on her left at these frequencies only (CHAPTER4 §3.1). The AudiOtron asks for
## masked bone only where an unmasked bone stamp shows a gap, so Hoot first runs unmasked bone at
## the same two frequencies on her better (right) mastoid, the cases' one-sided pattern.
const BONE_FREQS: Array[int] = [1000, 4000]

## Her chatty hits follow the word itself ("Seal! Like a good downbeat.": WrsModel writes the word,
## contract §9.12.1), six words or fewer around it.
const NORA_CHATTER: Array[String] = ["Like a good downbeat.", "Lovely and clear, that {word}.", "I'd know it anywhere.", "Next!"]
const NORA_SILENCES: Array[String] = ["Sorry?", "Mm?", "(hums uncertainly)"]
## List 2's chat demo (CHAPTER4 §5.6): chatting level on her left ear, before the player sets it.
const TEA_DEMO := {
	"text": "Fancy a cup of tea?", "level": 50,
	"chunks": [["F", "f"], ["a", "vowel"], ["n", "n"], ["c", "s"], ["y", "vowel"], [" ", ""], ["a", "vowel"], [" ", ""], ["c", "k"],
		["u", "vowel"], ["p", "p"], [" ", ""], ["o", "vowel"], ["f", "v"], [" ", ""], ["t", "t"], ["ea", "vowel"], ["?", ""]],
	"lines": [["hoot", "This is chatting level, 50. Watch what reaches her left ear."], ["nora", "Candy... a canoe? At my age?"],
		["hoot", "That's her complaint: voices, but not words!"],
		["hoot", "Your turn: set a level loud enough for every sound, and decide about noise."]],
}

const STEPS: Array[StringName] = [&"chat", &"peek", &"explain", &"beeps", &"srt", &"words_r", &"words_l", &"louder", &"flags", &"call"]
const STEP_LABELS: Dictionary = {
	&"chat": "Chat", &"peek": "Peek", &"explain": "Explain", &"beeps": "Beeps", &"srt": "SRT",
	&"words_r": "Words R", &"words_l": "Words L", &"louder": "Louder", &"flags": "Flags", &"call": "Call",
}

## Case-history rounds: [text, points (2 best, 1 good, 0 joke), reply, case note, tag].
const HISTORY: Array[Dictionary] = [
	{
		"prompt": "Ask Nora a question:",
		"options": [
			["Any ringing, or dizziness?", 2, "A hiss in the LEFT, like a kettle that never boils. And I wobble on stairs sometimes. No pain, no drips.",
				"Hiss in the left ear only; some unsteadiness on stairs; no pain or discharge", "red_flags"],
			["Any loud noise over the years?", 1, "Forty sopranos every Thursday. But they stand on my RIGHT.", "Choir noise, reaches both ears", "noise"],
			["Do you hum to test your ears?", 0, "Doesn't everyone?", "", ""],
		],
	},
	{
		"prompt": "Next question:",
		"options": [
			["Which ear? Did it come on suddenly or slowly?", 2, "The left. It crept up slowly, over about a year. Nothing sudden. The right is still lovely.",
				"LEFT ear, gradual over about a year, nothing sudden", "onset"],
			["Where is it hardest to follow words?", 1, "Rehearsals. The altos stand on my left, and it's all mush. I hear them. I can't make out the words.",
				"Left: hears voices but not words", "hardest"],
			["Could you sing me your symptoms?", 0, "(sings) Oh, left ear, why so fuzzy... That's the whole aria, darling.", "", ""],
		],
	},
]
const RED_FLAG_ANSWER := "A hiss in the LEFT, like a kettle that never boils. And I wobble on stairs sometimes. No pain, no drips."
const RED_FLAG_NOTE := "Hiss in the left ear only; some unsteadiness on stairs; no pain or discharge"

## The Daily Decibel, Day 4 (CHAPTER4 §10): {r} / {l} / {b} are the right, left and louder scores.
const HEADLINES: Dictionary = {
	"S": "TRAINEE HITS EVERY NOTE: WORDS SCORED, FLAGS RAISED, EAR DOCTOR NEXT",
	"A": "CHOIR DIRECTOR'S WORDS SCORED, FLAGGED AND REFERRED, ALL IN KEY",
	"B": "WORD SCORES SUNG; A FEW NOTES FLAT, SAYS OWL",
	"C": "SOME WORDS WENT OFF-KEY, CONFIRMS OWL",
	"Do-over": "NORA BACK TOMORROW FOR AN ENCORE; GHOST STILL HUMMING",
}
const SUBHEADS: Dictionary = {
	"S": "Better ear first, noise in the good ear, rollover caught. A doctor's check before any fitting.",
	"A": "Right {r}%, left {l}%, louder {b}%: red flags raised. A doctor's check before any fitting.",
	"B": "The flags flew. A few words were scored in the wrong key. Whole words only, says Hoot.",
	"C": "Remember: loud enough for every sound, 4% a word, and noise in the good ear.",
	"Do-over": "Word scores are a whole new song. Everyone sings a wrong note once.",
}
const MEDAL_BEATS: Array = [["history", "Chat"], ["instructions", "Explain"], ["masking", "Noise"], ["evidence", "Flags"], ["referral", "Call"]]
const WEATHER := "Weather: scattered consonants, fog over the left"

## The Roll Call's nine cards in their fixed shuffled order (CHAPTER4 §7).
const ROLL_CALL_ORDER: Array[String] = ["hiss", "canals", "tones", "agree", "apart", "slowly", "predicted", "wobbly", "louder"]
## The referral letter (P-LETTER): every clause from the visit.
const LETTER := "REFERRAL to ear doctor (ENT), soon. Asymmetric sensorineural hearing loss, left (masked bone), gradual over about a year; one-sided tinnitus (left); some unsteadiness. SRT agrees with PTA both ears. Word recognition poorer than the audiogram predicts, with rollover: left {l}% at {lv} dB HL (masked), {b}% at {bv}; right {r}% at {rv}. Please assess, including imaging (e.g. MRI), before any hearing aid fitting."

var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
## The AudiOtron, then the SPEECH screen (one at a time).
var screen: CanvasLayer
## Hoot's tone results (§5.1), then the merged visit results (§9.5).
var tones: Dictionary = {}
var results: Dictionary = {}
## The movie reached its seen_at scene this visit (lines may refer to it).
var _movie_watched := false
## Word lists handed out so far (play order, D25).
var _lists_given := 0
## The Roll Call's wrong sorts (the paper's line and the Flags medal).
var _flag_slips := 0
var _boo_seen := false
var _boo_shot_pending := false
var _lens_used := false
var _call_shot := false
var _speech_on := false
var _session: SpeechSession   # only when the SPEECH screen is missing (Hoot's fallback run)


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	Voice.register("Nora", VOICE)
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", PATIENT_ID)
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, "NORA NIGHTINGALE'S VISIT",
		{&"words_r": Palette.RIGHT_RED, &"words_l": Palette.LEFT_BLUE, &"louder": Palette.LEFT_BLUE})
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.technique_event.connect(_on_technique)
	Events.speech_lens_toggled.connect(_on_lens_toggled)
	Events.speech_state_changed.connect(_on_speech_state)
	Events.awaiting_input.connect(_on_beat)
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
	Events.screenshot_requested.emit("day4_" + shot_name)


## Quick visit as Day 3 reads it: --quick / --full win, else the setting (default on).
static func quick_visit() -> bool:
	return LevelMike.quick_visit()


func _run() -> void:
	await _masking_offer()
	await _movie()
	await _intro()
	await _history()
	await _otoscopy()
	await _instructions()
	await _tones()
	await _speech()
	var board: Control = await _evidence()
	await _referral(board)
	await _payoff(board)
	await _results()


# ---------------------------------------------------------------- 0. the movies (contract §9.20)

## Day 4 only, called before _movie(): the masking movie for a player who skipped Day 2.
func _masking_offer() -> void:
	if not Movies.has(MASKING_MOVIE) or Game.is_movie_seen(MASKING_MOVIE) or Game.is_chapter_done("bonnie"):
		return
	clinic.call("focus_camera", &"door", 0.0)
	var opts: Array[String] = ["Show me the Ghost movie! (about %d s)" % int(roundf(Movies.total_s(MASKING_MOVIE) / 10.0) * 10.0),
		"Skip it: on with words."]
	var c: int = await dialogue.choose("New to the Cross-Hearing Ghost? My masking movie explains it first.", opts, 1)
	if c == 0:
		await _play_movie(MASKING_MOVIE)


## Hoot's word movie, played as Day 2 plays its own (level_bonnie._movie): a one-line announcement
## before the first play only; once seen, just the replay offer (the best answer is to skip).
func _movie() -> void:
	if not Movies.has(MOVIE_ID):
		return
	var seen := Game.is_movie_seen(MOVIE_ID)
	_phase(&"explainer", {"movie": MOVIE_ID, "source": "day_start", "seen": seen})
	clinic.call("focus_camera", &"door", 0.0)
	if seen:
		var opts: Array[String] = ["Roll the film! (about %d s)" % int(roundf(Movies.total_s(MOVIE_ID) / 10.0) * 10.0),
			"Skip it: I know my banana."]
		var c: int = await dialogue.choose("Hoot's word movie again? Popcorn's on me!", opts, 1)
		if c != 0:
			return
	else:
		await _say("Hoot", "New trick today: WORD SCORES. A quick cartoon first, then our next patient!")
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


# ---------------------------------------------------------------- 1. intro: the tuning gag

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"chat")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	_react(&"wave")
	await _say("Nora", "(hums up a scale) Do, re, mi, fa, so... (stops on a note) Mmm.")
	clinic.call("gus_look", &"hoot")
	_shot("intro", 0.4)
	await _say("Nora", "Your hoot is a touch sharp, Professor. Try an A flat. My favourite. Terribly misunderstood.")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "I've been called sharp before. Questions first, then beeps, then words.")
	clinic.call("gus_look", &"camera")
	_react(&"confused")
	await _say("Nora", "My left ear has gone like a radio between stations. I hear the voices. I just can't make out the WORDS.")
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "Day 4, trainee: word scores! Loud enough is easy. CLEAR enough is the question.")


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
		await _say("Nora", String(pick[2]))
		if String(pick[3]) != "":
			hud.call("add_clue", String(pick[3]))
		match tag:
			"":
				clinic.call("hoot_emote", &"facepalm")
				await _say("Hoot", "Fun, but not a clue. Ask about her hearing!")
			"noise":
				await _say("Hoot", "Good to know: noise reaches both ears. Her trouble is one-sided, though.")
			"red_flags":
				await _say("Hoot", "One-sided hiss, and wobbles. Those go on the red-flag list.")
			"hardest":
				await _say("Hoot", "Hears voices but not words. That's clarity, not loudness. Today's test!")
			"onset":
				await _say("Hoot", "Slowly, over a year: noted. Sudden would have meant a doctor today.")
	# nothing important is lost by a pick: her onset aside, then Hoot's red-flag sweep
	if not tags.has("onset"):
		await _say("Nora", "Oh, and it crept up slowly, over about a year. Nothing sudden.")
		hud.call("add_clue", "LEFT ear, gradual over about a year, nothing sudden")
	if not tags.has("red_flags"):
		await _say("Hoot", "Always ask about red flags: one-sided ringing, dizziness, pain, discharge, sudden change.")
		await _say("Nora", RED_FLAG_ANSWER)
		hud.call("add_clue", RED_FLAG_NOTE)
	clinic.call("hoot_emote", &"nod")
	await _say("Hoot", "One-sided hiss, one-sided mush, wobbly stairs. We measure carefully, then decide who she sees.")
	hud.call("add_clue", "One-sided hiss and wobbly stairs: sort the red flags after the tests.", "flag")
	Game.record_medal("history", history_medal(points))
	Game.set_visit_flag("asked_red_flags", tags.has("red_flags"))
	Game.set_visit_flag("asked_onset", tags.has("onset"))
	hud.call("complete_step", &"chat")


## Chat: gold for the 2-point question in both rounds (4), silver 2-3, bronze 0-1.
static func history_medal(points: int) -> String:
	return "gold" if points >= 4 else ("silver" if points >= 2 else "bronze")


# ---------------------------------------------------------------- 3. otoscopy: Middle C

func _otoscopy() -> void:
	_phase(&"otoscopy")
	hud.call("set_step", &"peek")
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var g := Otoscopy.new()
	hud.call("add_game", g)
	await g.show_clear("left", LevelMike.SPECULUM_CAPTION % ["Nora", "LEFT"])
	await _say("Hoot", "Look before you test! Clear canals, healthy eardrums. Nothing blocking the left.")
	hud.call("add_clue", "Canals clear, eardrums healthy")
	g.queue_free()
	await clinic.call("focus_camera", &"face", 0.6)
	_shot("tuning_fork", 0.5)
	await _say("Hoot", "...You have a tuning fork in your hair.")
	_react(&"nod")
	await _say("Nora", "Middle C. For emergencies.")
	clinic.call("focus_camera", &"desk", 0.6)
	Game.record_medal("otoscopy", "gold")
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. instructions: words, guesses count

func _instructions() -> void:
	_phase(&"instructions")
	hud.call("set_step", &"explain")
	clinic.call("focus_camera", &"desk", 0.8)
	var good := "Repeat each word you hear. Guess if you're not sure."
	var opts: Array[String] = ["Sing each word back to me.", good, "Only answer when you're certain."]
	var tries := 0
	while true:
		tries += 1
		var best := opts.find(good)
		var c: int = await dialogue.choose("What do we tell Nora before the words?", opts, best)
		if c == best:
			break
		if opts[c].begins_with("Sing"):
			_react(&"cheer")
			await _say("Nora", "Ro-o-o-ope! ...With vibrato?")
			await _say("Hoot", "Gorgeous. But just SAY them, so we score words, not notes.")
		else:
			_react(&"confused")
			await _say("Nora", "Certain? Then you'll hear very little from me.")
			await _say("Hoot", "Too strict! Guesses count. A careful patient hides what she really hears.")
		opts.remove_at(c)
	Game.record_medal("instructions", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	Game.set_visit_flag("instructed", true)
	Game.set_visit_flag("instructed_first_try", tries == 1)
	await _say("Hoot", "Perfect. Guesses count: a word list should catch everything she can make out.")
	await _say("Hoot", "Repeat each word, and guess if unsure. No practice run: word lists test her first try.")
	_react(&"nod")
	await _say("Nora", "Guess? I've been guessing the altos' words for a year.")
	hud.call("complete_step", &"explain")


# ---------------------------------------------------------------- 5. tones: Hoot runs them, x8

func _air_transducer() -> StringName:
	return &"inserts" if Game.has_upgrade("insert_earphones") else &"phones"


func _open_audiometer() -> Camera3D:
	if screen == null:
		screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate() as CanvasLayer
		add_child(screen)
	screen.visible = true
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	return cam


func _hide_audiometer(cam: Camera3D) -> void:
	if screen != null:
		screen.visible = false
	cam.current = true


## One of Hoot's tone tests: his montage (instant stamps), whatever quick visit says.
func _tone_test(ear: String, plan: Dictionary) -> void:
	plan["air_transducer"] = _air_transducer()
	_phase(&"audiometry", {"ear": ear, "test": String(plan.get("test", "ac"))})
	# Hoot runs every tone test today (plan hoot_turn_after 0); set it per test, since the pause
	# menu's Quick visit toggle updates the screen in between
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
	await _say("Hoot", LevelMike.ROUTINE_LINE)
	await _say("Hoot", "Earphones on! I'll run the beeps at top speed. Better ear first: right.")
	clinic.call("put_on_earphones", true)
	await _wait(0.6)
	var cam := _open_audiometer()
	# the right ear is the visit's first air ear, so its montage owes the 1 kHz retest (E2)
	await _tone_test("right", {"test": "ac", "hoot_turn_after": 0, "montage": true,
		"intro": "Better ear first: the right. Watch the stamps fly in!",
		"hoot_turn_text": "My montage! Right ear at top speed."})
	await _tone_test("left", {"test": "ac", "hoot_turn_after": 0, "montage": true,
		"intro": "Left ear, Hoot speed!", "hoot_turn_text": "Left ear at top speed. Same dance, other ear!"})
	# bone at 1k and 4k: unmasked on her better (right) mastoid, then masked on her left
	_hide_audiometer(cam)
	clinic.call("focus_camera", &"ear_right", 0.5)
	clinic.call("put_on_bone_oscillator", "right")
	await _wait(0.6)
	cam = _open_audiometer()
	await _tone_test("right", {"test": "bc", "bc_freqs": BONE_FREQS.duplicate(), "masking_controls": true, "hoot_turn_after": 0,
		"montage": true, "intro": "Bone on her better ear first: 1k and 4k, at Hoot speed."})
	_hide_audiometer(cam)
	clinic.call("focus_camera", &"face", 0.5)
	clinic.call("put_on_bone_oscillator", "left")
	clinic.call("put_on_masking_phone", "right")
	await _wait(0.5)
	if not Game.is_chapter_done("bonnie"):
		await _say("Hoot", "Loud sounds can cross the skull to the other ear. That's the Cross-Hearing Ghost!")
	cam = _open_audiometer()
	await _tone_test("left", {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 0, "montage": true,
		"intro": "Now masked bone on her left, at 1k and 4k. Noise in the right keeps the Ghost out."})
	screen.queue_free()
	screen = null
	cam.current = true
	clinic.call("take_off_bone_oscillator")
	hud.call("complete_step", &"beeps")
	clinic.call("focus_camera", &"face", 0.6)
	var gap := tone_gap(tones)
	if CaseData.measured_type(tones, "left") == &"sensorineural":
		await _say("Hoot", "Masked bone sits right on her air lines: sensorineural. Left %s dB worse." % gap_words(gap))
	else:
		await _say("Hoot", "Bone's in. Left %s dB worse than right in the air." % gap_words(gap))
	_react(&"nod")
	await _say("Nora", "%s worse? Sounds like a modern opera." % gap_words(gap))


## How much worse her left air is than her right, over the octaves both ears have: [lo, hi] dB
## ([0, 0] before the tones).
static func tone_gap(tone_results: Dictionary) -> Vector2i:
	var r := ClinicRules.sheet_thresholds(tone_results, "right", &"ac")
	var l := ClinicRules.sheet_thresholds(tone_results, "left", &"ac")
	var lo := 999
	var hi := -999
	for f: int in [250, 500, 1000, 2000, 4000, 8000]:
		if r.has(f) and l.has(f):
			var d := int(l[f]) - int(r[f])
			lo = mini(lo, d)
			hi = maxi(hi, d)
	return Vector2i(lo, hi) if hi > -999 else Vector2i.ZERO


## "20 to 30", or "25" when the gap is the same everywhere.
static func gap_words(gap: Vector2i) -> String:
	return str(gap.x) if gap.x == gap.y else "%d to %d" % [gap.x, gap.y]


# ---------------------------------------------------------------- 6-9. the SPEECH screen: SRTs, then words

## The next word list in play order (D25): words_1 right, words_2 left, then words_3, words_4.
func next_list() -> String:
	var i := mini(_lists_given, SpeechRules.WRS_LISTS.size() - 1)
	_lists_given += 1
	return SpeechRules.WRS_LISTS[i]


## A word list's plan (contract §9.21). kind: &"right" (List 1, coached), &"left" (List 2, solo),
## &"redo" (coached, redoing list `n`), &"louder" (coached, 20 dB above the counted comfortable list `n`).
func list_plan(kind: StringName, list_id: String, quick: bool, n: int = 0) -> Dictionary:
	var plan := {"test": "wrs", "tones": tones, "list": list_id, "transducer": String(_air_transducer())}
	match kind:
		&"right":
			plan.merge({"lens_try_after": 2, "call_it": [&"faint_hit"], "chatter": NORA_CHATTER,
				"intro": "Word scores! One-syllable words, loud enough for every sound. Twenty-five of them, 4% each.",
				"hoot_turn_text": "Lovely scoring! I'll score the rest at top speed."})
		&"left":
			plan.merge({"level": SpeechRules.CHAT_DB, "chat_demo": TEA_DEMO, "ensure_audible_miss_by": 6, "audible_stamp": true,
				"call_it": [&"audible_miss"], "aside_by": 8, "self_correct": true, "chatter": NORA_CHATTER, "silences": NORA_SILENCES,
				"confirmed_wrong_hoot_after": 3})
		&"redo":
			plan.merge({"redo_of": n, "ensure_audible_miss_by": 6, "audible_stamp": true, "aside_by": 5, "chatter": NORA_CHATTER,
				"silences": NORA_SILENCES})
		&"louder":
			plan.merge({"louder_than": n, "mask_on": true, "lock_noise": true, "loud_bubble": true, "aside_by": 5,
				"chatter": NORA_CHATTER, "silences": NORA_SILENCES})
	if quick:
		plan["hoot_turn_after"] = int(QUICK_WORDS.get(kind, 8))
	return plan


func _speech() -> void:
	clinic.call("put_on_earphones", true)
	clinic.call("hold_response_button", false)
	clinic.call("focus_camera", &"face", 0.6)
	await _say("Hoot", "Now the words. First her SRT in both ears: the softest level for words.")
	var cam: Camera3D = clinic.call("get_main_camera")
	var packed: PackedScene = load(SPEECH_SCENE) as PackedScene if ResourceLoader.exists(SPEECH_SCENE) else null
	if packed != null:
		screen = packed.instantiate() as CanvasLayer
		add_child(screen)
		cam.current = false
	else:
		push_warning("LevelNora: no SPEECH screen (%s); Hoot runs the words himself" % SPEECH_SCENE)
	_speech_on = true
	await _srt()
	await _list_right()
	var comfy := await _list_left()
	comfy = await _redo_if_needed(comfy)
	hud.call("complete_step", &"words_l")
	await _louder(comfy)
	_speech_on = false
	if screen != null:
		screen.queue_free()
		screen = null
	cam.current = true
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"face", 0.6)
	Game.set_visit_flag("lens_used", _lens_used)
	Game.set_visit_flag("boo_seen", _boo_seen)
	Game.set_visit_flag("ghost_words", ghost_words(results))
	Game.set_visit_flag("call_it", call_its(results))


## One measurement on the SPEECH screen (or Hoot's fallback run): the merged results come back.
func _run_list(ear: String, coached: bool, plan: Dictionary) -> void:
	var r: Dictionary
	if screen != null:
		screen.set("quick_visit", quick_visit())
		screen.call("start_test", patient, ear, coached, plan)
		r = await screen.test_finished
	else:
		r = await _fallback(ear, plan)
	results = r
	Game.set_audiometry_results(results)


## No SPEECH screen in this build: Hoot runs it by the textbook through SpeechSession (C23).
func _fallback(ear: String, plan: Dictionary) -> Dictionary:
	if _session == null:
		_session = SpeechSession.new(patient, Game.rng.randi())
	_session.configure(plan)
	_session.run_by_textbook(ear)
	await _wait(0.5)
	return SpeechSession.merge_results(tones, _session.build_results())


func _srt() -> void:
	hud.call("set_step", &"srt")
	var quick := quick_visit()
	var by_hoot := quick
	for ear: String in ["right", "left"]:
		_phase(&"speech", {"ear": ear, "test": "srt"})
		var plan := {"test": "srt", "tones": tones, "transducer": String(_air_transducer())}
		if quick and screen != null:
			# Hoot's quick SRTs, off-screen (D23): the agreement meter swings to the result
			await screen.call("run_hidden", patient, ear, plan)
			results = (screen as SpeechScreen).get_results()
			Game.set_audiometry_results(results)
		elif quick:
			results = await _fallback(ear, plan)
			Game.set_audiometry_results(results)
		else:
			if ear == "right":
				await _say("Hoot", "Your turn: SRT both ears, right first. You know the dance from Mike." if Game.is_chapter_done("mike")
					else "Your turn: SRT both ears, right first. I'll coach every step.")
			await _run_list(ear, not Game.is_chapter_done("mike"), plan)
	var r := srt_sheet("right")
	var l := srt_sheet("left")
	var agree := String(r.get("agreement", "")) == "good" and String(l.get("agreement", "")) == "good"
	if by_hoot:
		await _say("Hoot", ("My quick SRTs: %d and %d. Both agree with her beeps: trustworthy!" if agree
			else "My quick SRTs: %d and %d. Close enough to her beeps to go on.") % [int(r.get("stored_db", 0)), int(l.get("stored_db", 0))])
	elif agree:
		await _say("Hoot", "Good agreement both ears: her beeps are trustworthy.")
	else:
		await _say("Hoot", "SRTs stored. Now the main event: word scores!")
	hud.call("complete_step", &"srt")


## Word list 1: her right (better) ear, coached; quick visit gives the player 8 words.
func _list_right() -> void:
	hud.call("set_step", &"words_r")
	await _say("Hoot", "Real clinics play recorded word lists, so every patient hears the very same voice.")
	_phase(&"speech", {"ear": "right", "test": "wrs"})
	await _run_list("right", true, list_plan(&"right", next_list(), quick_visit()))
	_react(&"cheer")
	await _say("Nora", "Clear as a bell. Well, a small bell.")
	hud.call("complete_step", &"words_r")


## Word list 2: her left ear, solo, after the tea demo. Returns its list record.
func _list_left() -> Dictionary:
	hud.call("set_step", &"words_l")
	_phase(&"speech", {"ear": "left", "test": "wrs"})
	_shot("tea_demo", 2.8)
	await _run_list("left", false, list_plan(&"left", next_list(), quick_visit()))
	var rec := newest_list("left")
	Game.record_medal("masking", masking_medal(rec, _boo_seen))
	Game.set_visit_flag("masked_first_try", bool(rec.get("masked", false)) and not _boo_seen)
	return rec


## Noise: gold = noise on before List 2's first word, unprompted; silver = on after the BOO;
## bronze = tested unmasked (the redo follows).
static func masking_medal(rec: Dictionary, boo_seen: bool) -> String:
	var needed := bool(rec.get("masking_needed", true))
	var masked := bool(rec.get("masked", false))
	if needed and not masked:
		return "bronze"
	return "silver" if boo_seen else "gold"


## List 2 can't count (unmasked, or outside the window): a coached redo on the next list.
## Returns the comfortable list the louder one builds on.
func _redo_if_needed(rec: Dictionary) -> Dictionary:
	if bool(rec.get("counts", true)):
		Game.set_visit_flag("wrs_redo", "")
		return rec
	var why := "unmasked" if bool(rec.get("masking_needed", false)) and not bool(rec.get("masked", false)) else "level"
	Game.set_visit_flag("wrs_redo", why)
	_phase(&"speech", {"ear": "left", "test": "wrs", "redo": true})
	await _run_list("left", true, list_plan(&"redo", next_list(), quick_visit(), int(rec.get("n", 2))))
	return newest_list("left")


## "Is that her best?": the rollover choice, the comfort check, then the louder list (coached,
## noise locked on).
func _louder(comfy: Dictionary) -> void:
	hud.call("set_step", &"louder")
	var pct := int(comfy.get("pct", wrs_sheet("left").get("pct", 0)))
	var good := "Try a new list 20 dB louder."
	var opts: Array[String] = [good, "Stop here: %d%% is her score." % pct, "Crank it to 100 and call it fixed."]
	while true:
		var best := opts.find(good)
		var c: int = await dialogue.choose("Left ear: %d%%. What next?" % pct, opts, best)
		if c == best:
			break
		if opts[c].begins_with("Stop"):
			await _say("Hoot", "Not yet! A poor score earns one more check: a new list, 20 louder.")
		else:
			await _say("Nora", "Louder never fixed my altos.")
			await _say("Hoot", "Max volume isn't a test. Twenty louder, and we compare.")
		opts.remove_at(c)
	await _say("Hoot", "Is %d her best? A list 20 louder tells us. Worse instead is rollover." % pct)
	var target := SpeechRules.wrs_louder_level(int(comfy.get("level_db", SpeechRules.wrs_level(ear_pta("left")))))
	await _say("Hoot", "%d dB is loud. Tell me if it's too loud, Nora." % target)
	await _say("Nora", "Loud, but bearable. Like the tenors.")
	_phase(&"speech", {"ear": "left", "test": "wrs", "louder": true})
	await _run_list("left", true, list_plan(&"louder", next_list(), quick_visit(), int(comfy.get("n", 2))))
	hud.call("complete_step", &"louder")


## The ear's PTA from Hoot's tones (as the SPEECH screen computes it). NAN before the tones.
func ear_pta(ear: String) -> float:
	if tones.is_empty():
		return NAN
	return SpeechRules.pta_for_speech(ClinicRules.best_thresholds(tones, ear, false))


func srt_sheet(ear: String) -> Dictionary:
	return (((results.get("speech", {}) as Dictionary).get("srt", {}) as Dictionary).get(ear, {}) as Dictionary)


func wrs_sheet(ear: String) -> Dictionary:
	return (((results.get("speech", {}) as Dictionary).get("wrs", {}) as Dictionary).get(ear, {}) as Dictionary)


## The ear's newest word list ({} = none).
func newest_list(ear: String) -> Dictionary:
	var lists: Array = wrs_sheet(ear).get("lists", [])
	return (lists.back() as Dictionary) if not lists.is_empty() else {}


## Words the other ear answered on unmasked lists this visit (the Ghost's words).
static func ghost_words(res: Dictionary) -> int:
	var n := 0
	var per: Dictionary = (res.get("speech", {}) as Dictionary).get("wrs", {})
	for e: Variant in per:
		for l: Variant in ((per[e] as Dictionary).get("lists", []) as Array):
			n += int((l as Dictionary).get("ghost_words", 0))
	return n


## The Call it guesses of the visit, in play order: [{moment, word, guess, outcome}].
static func call_its(res: Dictionary) -> Array:
	var out: Array = []
	var lists: Array = []
	var per: Dictionary = (res.get("speech", {}) as Dictionary).get("wrs", {})
	for e: Variant in per:
		lists.append_array((per[e] as Dictionary).get("lists", []))
	lists.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("seq", 0)) < int(b.get("seq", 0)))
	for l: Dictionary in lists:
		for c: Variant in (l.get("call_its", []) as Array):
			out.append((c as Dictionary).duplicate())
	return out


func _on_technique(kind: StringName, _data: Dictionary) -> void:
	if not _speech_on:
		return
	match kind:
		&"boo":
			_boo_seen = true
			_boo_shot_pending = true
			_shot("boo", 0.3)
		&"audible_miss":
			_shot("audible_miss", 0.5)


func _on_lens_toggled(ear: String, on: bool) -> void:
	if not _speech_on or not on:
		return
	if not _lens_used and ear == "right":
		_shot("lens_right", 0.9)
	_lens_used = true


func _on_speech_state(state: Dictionary) -> void:
	if _boo_shot_pending and bool(state.get("mask_on", false)):
		_boo_shot_pending = false
		_shot("ghostbuster", 0.8)


func _on_beat(beat: StringName, _info: Dictionary, _solver: Callable) -> void:
	if beat == &"call_it" and not _call_shot:
		_call_shot = true
		_shot("call_it", 0.5)


# ---------------------------------------------------------------- 10. evidence: the Red-Flag Roll Call

## The Roll Call's nine cards from this visit (CHAPTER4 §7), in ROLL_CALL_ORDER. A card is a red
## flag only when its rule fires on the visit's results; one that did not fire is a FINE card with
## its "no flag" line. Each card: {id, text, flag, src, right_line, wrong_line}.
static func roll_call_cards(res: Dictionary) -> Array[Dictionary]:
	var sp: Dictionary = res.get("speech", {})
	var wrs: Dictionary = sp.get("wrs", {})
	var right: Dictionary = wrs.get("right", {})
	var left: Dictionary = wrs.get("left", {})
	var r_air := ClinicRules.best_thresholds(res, "right", false)
	var l_air := ClinicRules.best_thresholds(res, "left", false)
	var gap := gap_words(tone_gap(res))
	var asym_tones := CaseRules.is_asymmetric(r_air, l_air)
	var r_best := int(right.get("pb_max", right.get("pct", 0)))
	var l_best := int(left.get("pb_max", left.get("pct", 0)))
	var apart := bool(left.get("asymmetric", false)) or bool(right.get("asymmetric", false))
	var below := bool(left.get("below_predicted", false))
	var pmin := int(left.get("predicted_min", 0))
	var roll := bool(left.get("rollover", false))
	var comfy := int(left.get("pct", 0))
	var louder := int(left.get("louder_pct", 0))
	var by: Dictionary = {}
	by["hiss"] = {"text": "Hiss in the LEFT ear only", "flag": true, "src": "history",
		"right_line": "One-sided ringing: a red flag.", "wrong_line": "Ringing in just one ear is a red flag. Try again!"}
	by["wobbly"] = {"text": "Wobbly on stairs sometimes", "flag": true, "src": "history",
		"right_line": "Unsteady, plus a one-sided loss: the doctor should know.",
		"wrong_line": "Dizziness with a one-sided loss is a red flag. Try again!"}
	if asym_tones:
		by["tones"] = {"text": "Left tones %s dB worse than right" % gap.replace(" to ", "-"), "flag": true, "src": "tones",
			"right_line": "Left %s dB worse than right: an asymmetry." % gap,
			"wrong_line": "One ear %s dB worse than the other: an asymmetry, a red flag." % gap}
	else:
		by["tones"] = {"text": "Left tones %s dB worse than right" % gap.replace(" to ", "-"), "flag": false, "src": "tones",
			"right_line": "The ears' tones are close: no asymmetry flag there.",
			"wrong_line": "The ears' tones are close: no asymmetry flag there."}
	var apart_text := "Best words: right %d%%, left %d%%" % [r_best, l_best]
	if apart:
		by["apart"] = {"text": apart_text, "flag": true, "src": "words",
			"right_line": "Right %d, left %d: too far apart for chance. Ears this different need a doctor's look." % [r_best, l_best],
			"wrong_line": "Scores too far apart for chance are a red flag. Try again!"}
	else:
		by["apart"] = {"text": apart_text, "flag": false, "src": "words",
			"right_line": "Close enough to be chance: not a red flag on its own.",
			"wrong_line": "Close enough to be chance: not a red flag on its own."}
	var pred_text := "Left best %d%%; tones predict %d%% or more" % [l_best, pmin]
	if below:
		by["predicted"] = {"text": pred_text, "flag": true, "src": "words",
			"right_line": "Tones predict at least %d%%. Her best was %d. Worse than predicted." % [pmin, l_best],
			"wrong_line": "Her best is worse than her tones predict: a red flag."}
	else:
		by["predicted"] = {"text": pred_text, "flag": false, "src": "words",
			"right_line": "Her best reached her tones' prediction: no flag there.",
			"wrong_line": "Her best reached her tones' prediction: no flag there."}
	var louder_text := "Louder list: %d%% fell to %d%%" % [comfy, louder] if louder <= comfy else "Louder list: %d%% went to %d%%" % [comfy, louder]
	if roll:
		by["louder"] = {"text": louder_text, "flag": true, "src": "words",
			"right_line": "Louder made it worse. Rollover: a classic reason to check further.",
			"wrong_line": "Louder made it worse: rollover. That's a red flag."}
	else:
		by["louder"] = {"text": louder_text, "flag": false, "src": "words",
			"right_line": "Louder didn't make it worse: no rollover, no flag.",
			"wrong_line": "Louder didn't make it worse: no rollover, no flag."}
	by["canals"] = {"text": "Ear canals clear", "flag": false, "src": "look",
		"right_line": "Clear canals: nothing blocking. The problem is deeper.",
		"wrong_line": "Clear canals are good news. Nothing blocking: the problem is deeper."}
	by["agree"] = {"text": "SRT agrees with PTA in both ears", "flag": false, "src": "srt",
		"right_line": "Agreement means her tones are trustworthy. That makes the flags MORE believable.",
		"wrong_line": "Agreement means her tones are trustworthy. That's good news, not a flag."}
	by["slowly"] = {"text": "Came on slowly, over about a year", "flag": false, "src": "history",
		"right_line": "Slow still counts when one ear lags. Sudden would mean a doctor today.",
		"wrong_line": "Slow still counts when one ear lags. Sudden would mean a doctor today."}
	var out: Array[Dictionary] = []
	for id: String in ROLL_CALL_ORDER:
		var c: Dictionary = (by[id] as Dictionary).duplicate()
		c["id"] = id
		out.append(c)
	return out


func _evidence() -> Control:
	_phase(&"evidence")
	hud.call("set_step", &"flags")
	clinic.call("focus_camera", &"desk", 0.6)
	var b := NoraBoard.new()
	b.setup(roll_call_cards(results))
	hud.call("add_game", b)
	await _say("Hoot", "Red-flag roll call! Each clue steps up: red flag, or fine?")
	get_tree().create_timer(6.0, false).timeout.connect(func() -> void: _shot("flags"))
	await b.run_roll_call()
	_shot("flags_done", 0.4)
	_flag_slips = b.slips
	Game.set_visit_flag("flag_slips", _flag_slips)
	Game.record_medal("evidence", "gold" if _flag_slips == 0 else ("silver" if _flag_slips == 1 else "bronze"))
	await _wait(0.8)
	await _say("Hoot", "Words worse than her tones, one ear far worse, plus rollover: the doctor should look further.")
	hud.call("complete_step", &"flags")
	return b


# ---------------------------------------------------------------- 11. referral: the stamp tray, the letter

## What the visit's word scores call for (D27): &"refer" (an ear doctor, soon), never "doctor
## today" from word scores alone. Refer is also right when the summary is missing.
func referral() -> StringName:
	var s: Dictionary = (results.get("speech", {}) as Dictionary).get("wrs_summary", {})
	var r := StringName(String(s.get("referral", "refer")))
	return r if r != &"" else &"refer"


## The letter with this visit's numbers (P-LETTER).
static func letter_text(res: Dictionary) -> String:
	var wrs: Dictionary = (res.get("speech", {}) as Dictionary).get("wrs", {})
	var right: Dictionary = wrs.get("right", {})
	var left: Dictionary = wrs.get("left", {})
	return LETTER.replace("{l}", str(int(left.get("pct", 0)))).replace("{lv}", str(int(left.get("level_db", 0)))) \
		.replace("{b}", str(int(left.get("louder_pct", 0)))).replace("{bv}", str(int(left.get("louder_level_db", 0)))) \
		.replace("{r}", str(int(right.get("pct", 0)))).replace("{rv}", str(int(right.get("level_db", 0))))


func _referral(b: Control) -> void:
	_phase(&"referral")
	hud.call("set_step", &"call")
	var answer := referral()
	var lines: Dictionary = {
		&"fit": "Not yet! Aids can wait. First a doctor checks what's behind those flags.",
		&"today": "Close! But it crept in over a year. Soon, not today: days to two weeks.",
		&"refer": "Refer: an ear doctor soon. The doctor decides on scans. No fitting until then.",
	}
	await b.call("open_tray")
	var tries := 0
	while true:
		tries += 1
		var i: int = await b.call("choose_stamp", "Your call for Nora:", CaseRules.DECISIONS.find(answer))
		var d: StringName = CaseRules.DECISIONS[i]
		var right := d == answer
		if tries == 1:
			Game.set_visit_flag("decision_first", String(d))
		await b.call("slam", d, right)
		if right:
			_shot("stamp", 0.1)
			_react(&"nod")
		await _say("Hoot", String(lines.get(d, "")))
		if right:
			break
	Game.set_visit_flag("decision", String(answer))
	Game.set_visit_flag("decision_tries", tries)
	Game.record_medal("referral", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	await _say("Hoot", "The letter says what we found, not what it is. The doctor decides.")
	get_tree().create_timer(1.6, false).timeout.connect(func() -> void: _shot("letter"))
	await b.call("show_letter", letter_text(results))
	await _say("Hoot", "Sudden drop, or worse wobbles before then? Call a doctor that same day.")
	hud.call("complete_step", &"call")


# ---------------------------------------------------------------- 12. the payoff: altos to the right

func _payoff(b: Control) -> void:
	await b.call("fade_out")
	b.queue_free()
	await clinic.call("focus_camera", &"face", 0.5)
	_react(&"confused")
	await _say("Nora", "A doctor first? Should I be worried, darling?")
	await _say("Hoot", "I can't tell you what it is. The doctor can, and that's why we check.")
	await _say("Hoot", "Most checks like this come back clear. Checking is how we stay safe.")
	await _say("Nora", "And my hearing aid?")
	await _say("Hoot", "Once the doctor says go, we'll talk aids.")
	await _say("Hoot", "Until then, stand the altos on your right, your clearer side.")
	_react(&"cheer")
	await _say("Nora", "Altos to the right, darling! That's a revolution.")
	await _say("Nora", "(sings up an arpeggio) Thank you, Pro-fes-sor!")
	clinic.call("focus_camera", &"door", 1.6)
	await clinic.call("walk_out")
	await clinic.call("peek_in")
	_shot("a_flat", 0.2)
	await _say("Nora", "Professor, your hoot is an A flat now.")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "...Is that good?")
	await _say("Nora", "It's misunderstood.")
	await clinic.call("walk_out")


# ---------------------------------------------------------------- 13. results

## The paper's subheads with this visit's scores ({r}, {l}, {b}).
static func subheads(res: Dictionary) -> Dictionary:
	var wrs: Dictionary = (res.get("speech", {}) as Dictionary).get("wrs", {})
	var right: Dictionary = wrs.get("right", {})
	var left: Dictionary = wrs.get("left", {})
	var out := {}
	for g: String in SUBHEADS:
		out[g] = String(SUBHEADS[g]).replace("{r}", str(int(right.get("pct", 0)))).replace("{l}", str(int(left.get("pct", 0)))) \
			.replace("{b}", str(int(left.get("louder_pct", 0))))
	return out


func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	summary["headlines"] = HEADLINES
	summary["subheads"] = subheads(results)
	summary["medal_beats"] = MEDAL_BEATS
	summary["weather"] = WEATHER
	summary["sports_script"] = SPORTS_SCRIPT
	summary["roll_call"] = {"cards": ROLL_CALL_ORDER.size(), "slips": _flag_slips}
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
