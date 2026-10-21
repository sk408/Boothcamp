extends Node
## LevelMarco (Speech): Day 5, "Speech in noise (SNR loss)". Marco Polenta, 54, restaurant critic,
## whose ears are "perfect, in quiet. At a busy table, every word turns to soup." Design:
## docs/CHAPTER5.md (beat by beat, §3); contracts: CONTRACTS.md §3.1, §9.20 (the movie) and §9.21
## (the plans). Every blocking beat emits Events.awaiting_input with a solver. Nobody names a cause
## or a condition: the day measures the party, proves the audiogram isn't the whole story, tests
## the aids blind and seats Marco well. No referral: no red flags, no gap, words fit his beeps.
##   world:  res://world/clinic.tscn with patient_id = "marco" (show_soundfield: the booth speakers)
##   ui:     res://ui/audiometer/audiometer_screen.tscn (Hoot runs every tone test, x8)
##           res://ui/speech/speech_screen.tscn: Hoot's SRTs and words in quiet off-screen
##           (run_hidden), then PARTY mode, one start_test per party list (Party list 1 to 6)
##   boards: res://story/games/marco_board.gd (the bill, the band ruler, the plates, the pizza, the
##           switch, the reveal), marco_seats.gd (Trattoria Clatter's floor plan), marco_dinner.gd
##   paper:  the Daily Decibel with res://story/papers/paper_party_golf.gd as its sports column
## Beats: the movie's own explainer beat (or a choice on replays), dialogue, choice, the SPEECH
## screen's speech beats, band_pick, plates_serve, focus_switch, the seat choice, results_continue.
## (Clinical review A7) Band names are SIN_BAND_NAMES ("Near-normal", never "Small"); the plates'
## line is "His audiogram can't tell us how he copes in noise"; the booth is never sold as proof of
## benefit at a real table.

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const MarcoBoard := preload("res://story/games/marco_board.gd")
const MarcoSeats := preload("res://story/games/marco_seats.gd")
const MarcoDinner := preload("res://story/games/marco_dinner.gd")
const LevelMike := preload("res://story/level_mike.gd")
const CaseData := preload("res://story/case_data.gd")
const Voice := preload("res://story/voice.gd")
const Movies := preload("res://story/explainers/movies.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const SPEECH_SCENE := "res://ui/speech/speech_screen.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_marco.tscn"
const EXPLAINER_SCENE := "res://story/explainers/explainer_player.tscn"
const SPORTS_SCRIPT := "res://story/papers/paper_party_golf.gd"
const PATIENT_ID := "marco"
const MOVIE_ID := "party_noise"
## Voices (story/voice.gd is not edited: registered at runtime, CHAPTER5 §12).
const VOICE := {"f0": 118.0, "wobble": 0.07, "roll": 0.85}
const ROSA_VOICE := {"f0": 215.0, "wobble": 0.08, "roll": 0.7}

## His noise-wins answers (Appendix B): Dessert, nothing caught. The model picks one, never twice in a row.
const MARCO_LOST: Array[String] = [
	"Words? Gone. Like the last breadstick.", "Nothing. Only clatter. Like a kitchen at closing time.",
	"I heard... a birthday? Somebody always has a birthday.", "Sorry. The party ate the whole sentence.",
	"Something about... soup? It's always soup.", "I'm nodding and smiling. My famous dinner-party trick.",
	"Was that 'tiramisu'? I want it to be 'tiramisu'.", "Clink, clink, ha-ha. That's all I've got.",
]

const STEPS: Array[StringName] = [&"chat", &"peek", &"explain", &"beeps", &"party1", &"bill", &"party2", &"plates", &"prog_a", &"prog_b", &"seat"]
const STEP_LABELS: Dictionary = {
	&"chat": "Chat", &"peek": "Peek", &"explain": "Explain", &"beeps": "Beeps", &"party1": "Party 1", &"bill": "Bill",
	&"party2": "Party 2", &"plates": "Plates", &"prog_a": "A", &"prog_b": "B", &"seat": "Seat",
}

## Case-history rounds: [text, points (2 best, 1 good, 0 joke), reply, case note, tag]. The first 18
## characters of every option are unique (the mouse bot clicks by them).
const HISTORY: Array[Dictionary] = [
	{
		"prompt": "Ask Marco a question:",
		"options": [
			["Where is it hardest to follow talk?", 2, "Busy restaurants. Parties. Weddings. One-to-one in a quiet room? Perfect. Like a library.",
				"Lost in noise; fine one-to-one in quiet", "hardest"],
			["Any pain, dizziness, ringing or drips?", 2, "No pain, no spinning, no drips. A faint hiss after very loud nights, both ears. Gone by breakfast.",
				"No red flags; a brief hiss in both ears after loud nights", "red_flags"],
			["What's the best meal you ever had?", 0, "A mushroom risotto in a hill town. I wept. The chef wept. The waiter asked for a tissue.", "", ""],
		],
	},
	{
		"prompt": "Next question:",
		"options": [
			["Did it come on slowly, or suddenly?", 2, "Slowly, over a few years. Like a sauce reducing. Both ears the same.",
				"Gradual over years; both ears alike", "onset"],
			["How do you manage busy dinners now?", 1, "I book the 5:30 table. Empty room, perfect hearing. My friends call me the Early Bird.",
				"Books early tables to dodge the noise", "coping"],
			["Have you tried shushing the whole restaurant?", 0, "Once. A wedding party of ninety shushed me back. In harmony.", "", ""],
		],
	},
]
const RED_FLAG_ANSWER := "No pain, no spinning, no drips. A faint hiss after very loud nights, both ears. Gone by breakfast."
const RED_FLAG_NOTE := "No red flags; a brief hiss in both ears after loud nights"
const ONSET_ANSWER := "Slowly, over a few years. Like a sauce reducing. Both ears the same."
const ONSET_NOTE := "Gradual over years; both ears alike"

## Every Hoot line of the level (18 words or fewer with tokens at their longest; keys only through
## {key:<action>}). Tokens: {pta} {r} {l} {verdict} {total} {loss} {avg} {band} {benefit} {crit}.
const HOOT: Dictionary[String, String] = {
	"movie_new": "New trick today: WORDS IN NOISE. A quick cartoon first, then our next patient!",
	"movie_again": "Hoot's party movie again? Popcorn's on me!",
	"movie_skipped": "Skipped! Rewatch it any time: pause menu, \"Watch {title}\".",
	"review": "...Welcome to Booth Camp.",
	"purpose": "Day 5, trainee: speech in noise! Today the party talks back.",
	"joke": "Delicious, but not a clue. Ask about his hearing!",
	"hardest": "Fine one-to-one, lost in a crowd. That's exactly what today measures.",
	"onset": "Slowly, both ears alike: noted. Sudden would have been a red flag.",
	"coping": "The early table is a clue too. People quietly avoid what's hard.",
	"sweep_flags": "Always check red flags too: pain, dizziness, drips, one-sided ringing or loss, sudden changes.",
	"sweep_onset": "Sudden changes are red flags too. Slowly, or suddenly?",
	"hiss": "Hiss in both ears after loud nights isn't a red flag. It's a noise warning.",
	"earplugs": "Earplugs for loud nights: filtered ones keep the music clear.",
	"after_history": "Fine in quiet, lost at busy tables, both ears alike. No red flags. Let's measure!",
	"otoscopy": "Canals clear, eardrums healthy. Nothing in the way.",
	"napkin": "...You can take the napkin off.",
	"instructions_prompt": "Party test! Tell Marco what to do:",
	"instructions_best": "Repeat the main voice, even single words. Guess if unsure. The party gets louder.",
	"instructions_strict": "Too strict! Every key word counts, even one. Guessing is welcome.",
	"instructions_party": "Just the main voice! The party is the noise we measure against.",
	"tones": "I'll run the beeps at top speed. Better ear first: the right.",
	"bone": "Bone matches air: no gap. Sensorineural, both ears.",
	"bone_other": "Bone's in. Now his words, in quiet first.",
	"words_noise": "Now words in quiet, my turn. The rule says noise in the other ear.",
	"words_quiet": "Now words in quiet, my turn. No noise needed this time.",
	"no_wrs": "Word lists are still at the printer. His beeps say words in quiet should be fine.",
	"summary": "Mild high-pitch loss, PTA about {pta}. Words in quiet: {r} and {l} percent. {verdict}!",
	"list_done": "Six sentences done. Time for the bill!",
	"bill": "{total} key words. Check the receipt's formula. What's the bill?",
	"bill_right": "Every key word he missed adds 1 dB. Most ears miss about four or five anyway.",
	"bill_total": "That's the key words, not the loss. Subtract them from 25.5.",
	"bill_added": "Subtract, don't add! Fewer words right means a bigger SNR loss.",
	"band_prompt": "{loss} dB of SNR loss. Point to its band on the ruler.",
	"band_normal": "Near-normal: good habits first. Let's still see what the aids do.",
	"band_mild": "Mild: if aids, standard settings. Let's still see what the mics do.",
	"band_moderate": "Moderate: the menu says directional mics. Let's prove it in the booth.",
	"band_severe": "Severe: the menu says a remote mic. Let's first see what the mics do.",
	"second_list": "One list is a rough guess. Two make it solid. Second list!",
	"average": "Average of two lists: {avg} dB. {band} SNR loss.",
	"normed": "Real clinics use normed tests built like this. Our lists are for practice.",
	"plates": "Marco says two things. Serve each clue to the claim it proves.",
	"whole_story": "His audiogram can't tell us how he copes in noise. Measured: {avg} dB.",
	"real_trouble": "His SRTs agree with his beeps. This noise trouble is real, and very common.",
	"sound_field": "Hearing aids on. We test them with speakers: voice in front, party behind.",
	"blind": "Blind tasting! Marco won't know which programme is on, so he can't guess.",
	"pizza": "Omni hears the whole pizza. Directional favours the front half and turns the back down.",
	"switch": "Marco, eyes closed! Trainee, flip the switch to programme B.",
	"like_with_like": "Compare like with like: same speakers, same level, only the microphones changed.",
	"benefit_real": "Programme B was FOCUS: {benefit} dB better, two lists each. Real, not luck.",
	"benefit_small": "Programme B was FOCUS: {benefit} dB better. Under {crit}, that could be luck.",
	"benefit_small_then": "In clinic, run another list each before you promise anything.",
	"why_blind": "Patients who know try harder on the 'better' one. Blind keeps it fair.",
	"booth_kinder": "The booth is kinder than a real restaurant. We'll check how the aids do at your table.",
	"seat_prompt": "Where should Marco sit? His mics favour the front.",
	"seat_kitchen": "Kitchen doors swing and clatter right beside him. Try a quieter spot.",
	"seat_speaker": "Right under the music. The mics can't escape that. Try again.",
	"seat_facing": "Noise in front is what the mics listen to! Turn him around.",
	"seat_back": "Back to the room, facing his guest, light on her face. Perfect!",
	"tips": "Face your guest. Good light on faces. Quieter times. Tell the host.",
	"remote_mic": "If noise ever beats the aids, a remote mic on his guest can help.",
	"expectations": "Directional mics turn noise behind him down, not off. Honest expectations matter.",
	"allow": "...I'll allow it.",
	"goodbye": "That's the job: measure the party, then fix the party. Lovely work, trainee!",
	# screen texts (the SPEECH screen's intro and Hoot-turn banners)
	"intro_party1": "Party time! Both ears together, like a real dinner. His ears match.",
	"intro_party2": "Set the talker, then I'll pour the easy courses. You take the noisy end.",
	"intro_aided_a": "Programme A, in the sound field. Hoot sets the talker at a chatting level.",
	"intro_aided_b": "Programme B, same speakers, same level. Only the microphones change.",
	"pours": "I'll pour the easy courses. You take the noisy end.",
	"hoot_list": "My list, at top speed: two lists make it solid.",
}
## The bill's three answers: the loss (right), the key words, the two added.
const BILL_LINES: Dictionary[StringName, String] = {&"loss": "bill_right", &"total": "bill_total", &"added": "bill_added"}
## The seats in their fixed order (a map, CHAPTER5 §7.1): text, Hoot's line, the right one.
const SEATS: Array[Dictionary] = [
	{"id": "kitchen", "text": "Next to the kitchen doors", "line": "seat_kitchen"},
	{"id": "speaker", "text": "Right under the music speaker", "line": "seat_speaker"},
	{"id": "facing", "text": "Corner booth, facing the room", "line": "seat_facing"},
	{"id": "back", "text": "Corner booth, back to the room", "line": "seat_back", "best": true},
]

## The Daily Decibel, Day 5 (CHAPTER5 §8.4): Marco's review is the subhead, forks by grade.
const HEADLINES: Dictionary = {
	"S": "TRAINEE SERVES A FIVE-STAR PARTY TEST; CRITIC LICKS PLATE",
	"A": "FOOD CRITIC HEARS \"MARRIED\" OVER A FULL DINING ROOM",
	"B": "PARTY TEST SERVED WARM; A FEW KEY WORDS UNDERCOOKED",
	"C": "SOME KEY WORDS SENT BACK TO THE KITCHEN, CONFIRMS OWL",
	"Do-over": "MARCO BOOKS A TABLE FOR TOMORROW; BRING YOUR SCORING FORK",
}
const SUBHEADS: Dictionary = {
	"S": "Five forks. \"Precise, kind, and the owl knows his soup.\" M. Polenta, Table Talk.",
	"A": "Four forks. \"Every key word plated with care. The coffee: still two stars.\" M. Polenta",
	"B": "Three forks. \"Solid service, a few key words undercooked. I will return.\" M. Polenta",
	"C": "Two forks. \"Some words came back to the wrong table. Promising.\" M. Polenta",
	"Do-over": "One fork, but a hopeful one. \"The owl was charming. Book me again.\" M. Polenta",
}
const MEDAL_BEATS: Array = [["history", "Chat"], ["instructions", "Explain"], ["bill", "Bill"], ["evidence", "Case"], ["help", "Help"]]
const WEATHER := "Weather: rising babble, clearing with directional mics"

var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
## The AudiOtron, then the SPEECH screen (one at a time; the SPEECH screen stays for every list).
var screen: CanvasLayer
var board: Control
## Hoot's tone results (§5.1), then the merged visit results (§9.5).
var tones: Dictionary = {}
var results: Dictionary = {}
var _movie_watched := false
var _bill_tries := 0
var _band_tries := 0
var _plates_slips := 0
var _seat_tries := 0
var _speech_on := false
var _session: SpeechSession   # only when the SPEECH screen is missing (Hoot's fallback run)


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	Voice.register("Marco", VOICE)
	Voice.register("Rosa", ROSA_VOICE)
	# the party's babble loop is built now, so the first PRESENT never hitches (contract §9.16)
	SpeechBabble.loop()
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	clinic.set("patient_id", PATIENT_ID)
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, "MARCO POLENTA'S VISIT", {&"prog_a": Palette.SUNNY, &"prog_b": Palette.MINT})
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.level_started.emit(PATIENT_ID)
	_run.call_deferred()


func _phase(p: StringName, info: Dictionary = {}) -> void:
	Events.phase_changed.emit(p, info)


func _say(who: String, text: String) -> void:
	await dialogue.say(who, text)


## One of Hoot's lines (HOOT) with its tokens filled.
func _hoot(key: String, tokens: Dictionary = {}) -> void:
	await dialogue.say("Hoot", line(key, tokens))


static func line(key: String, tokens: Dictionary = {}) -> String:
	var s := String(HOOT.get(key, key))
	for k: Variant in tokens:
		s = s.replace("{%s}" % String(k), str(tokens[k]))
	return s


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _react(kind: StringName, data: Dictionary = {}) -> void:
	Events.patient_reaction.emit(kind, data)


func _shot(shot_name: String, delay: float = 0.0) -> void:
	if not Game.cli.has("shots"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	Events.screenshot_requested.emit("day5_" + shot_name)


## Quick visit as Day 3 reads it: --quick / --full win, else the setting (default on).
static func quick_visit() -> bool:
	return LevelMike.quick_visit()


## A dB figure as the receipt prints it: 9.5, 16, 4.0 (one decimal unless whole for counts).
static func db_text(v: float) -> String:
	return "%.1f" % v


func _run() -> void:
	await _movie()
	await _intro()
	await _history()
	await _otoscopy()
	await _instructions()
	await _montage()
	await _party_1()
	await _bill()
	await _party_2()
	await _plates()
	await _fitting()
	await _programme(&"A")
	await _pizza_and_switch()
	await _programme(&"B")
	await _reveal()
	await _close_speech()
	await _seat()
	await _dinner()
	await _results()


# ---------------------------------------------------------------- 0. the movie (contract §9.20)

## Hoot's party movie, played as Day 4 plays its word movie (level_nora._movie): a one-line
## announcement before the first play only; once seen, just the replay offer (the best answer is
## to skip).
func _movie() -> void:
	if not Movies.has(MOVIE_ID):
		return
	var seen := Game.is_movie_seen(MOVIE_ID)
	_phase(&"explainer", {"movie": MOVIE_ID, "source": "day_start", "seen": seen})
	clinic.call("focus_camera", &"door", 0.0)
	if seen:
		var opts: Array[String] = ["Roll the film! (about %d s)" % int(roundf(Movies.total_s(MOVIE_ID) / 10.0) * 10.0),
			"Skip it: I know my SNR."]
		var c: int = await dialogue.choose(line("movie_again"), opts, 1)
		if c != 0:
			return
	else:
		await _hoot("movie_new")
	var r := await _play_movie(MOVIE_ID)
	_movie_watched = bool(r.get("watched", not bool(r.get("skipped", false))))
	Game.set_visit_flag("movie_watched", _movie_watched)
	if bool(r.get("skipped", false)):
		await _hoot("movie_skipped", {"title": Movies.title(MOVIE_ID)})


func _play_movie(id: String) -> Dictionary:
	var player: Node = (load(EXPLAINER_SCENE) as PackedScene).instantiate()
	add_child(player)
	var r: Dictionary = await player.call("play", id, "day_start")
	player.queue_free()
	return r


# ---------------------------------------------------------------- 1. intro: the review

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"chat")
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.5)
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	_react(&"wave")
	await _say("Marco", "(sniffs, opens his notebook) Ambience: beige. Coffee: burnt, two stars. Service: an owl. Intriguing.")
	_shot("review", 0.3)
	clinic.call("hoot_emote", &"wing_up")
	await _hoot("review")
	clinic.call("gus_look", &"camera")
	await _say("Marco", "My ears are perfect, in quiet. At a busy table, every word turns to soup.")
	_react(&"confused")
	await _say("Marco", "My daughter Rosa wants dinner at Trattoria Clatter on Saturday. The loudest room in town. She has news.")
	clinic.call("hoot_emote", &"nod")
	await _hoot("purpose")


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
		await _say("Marco", String(pick[2]))
		if String(pick[3]) != "":
			hud.call("add_clue", String(pick[3]))
		match tag:
			"":
				clinic.call("hoot_emote", &"facepalm")
				await _hoot("joke")
			"red_flags":
				await _hiss_lines()
			_:
				await _hoot(tag)
	# the red-flag sweep always happens (CHAPTER5 §1)
	if not tags.has("red_flags"):
		await _hoot("sweep_flags")
		await _say("Marco", RED_FLAG_ANSWER)
		hud.call("add_clue", RED_FLAG_NOTE)
		await _hiss_lines()
	if not tags.has("onset"):
		await _hoot("sweep_onset")
		await _say("Marco", ONSET_ANSWER)
		hud.call("add_clue", ONSET_NOTE)
	clinic.call("hoot_emote", &"nod")
	await _hoot("after_history")
	hud.call("add_clue", "No red flags", "ok")
	_shot("history_clue", 0.4)
	Game.record_medal("history", history_medal(points))
	Game.set_visit_flag("asked_red_flags", tags.has("red_flags"))
	Game.set_visit_flag("asked_onset", tags.has("onset"))
	hud.call("complete_step", &"chat")


func _hiss_lines() -> void:
	await _hoot("hiss")
	await _hoot("earplugs")


## Chat: gold for 4 points, silver 2-3, bronze 0-1.
static func history_medal(points: int) -> String:
	return "gold" if points >= 4 else ("silver" if points >= 2 else "bronze")


# ---------------------------------------------------------------- 3. otoscopy: the napkin

func _otoscopy() -> void:
	_phase(&"otoscopy")
	hud.call("set_step", &"peek")
	await clinic.call("focus_camera", &"otoscope", 0.8)
	var g := Otoscopy.new()
	hud.call("add_game", g)
	await g.show_clear("right", "Marco's RIGHT ear: clear canal, healthy eardrum.")
	await _hoot("otoscopy")
	hud.call("add_clue", "Canals clear, eardrums healthy")
	g.queue_free()
	await clinic.call("focus_camera", &"face", 0.6)
	await _hoot("napkin")
	_react(&"nod")
	await _say("Marco", "Never. Life is a buffet.")
	clinic.call("focus_camera", &"desk", 0.6)
	Game.record_medal("otoscopy", "gold")
	hud.call("complete_step", &"peek")


# ---------------------------------------------------------------- 4. instructions: the main voice

const INSTRUCT_BEST := "Repeat the main voice, even single words. Guess if unsure."
const INSTRUCT_STRICT := "Only repeat sentences you hear perfectly."
const INSTRUCT_PARTY := "Repeat everything you hear, party and all."


func _instructions() -> void:
	_phase(&"instructions")
	hud.call("set_step", &"explain")
	clinic.call("focus_camera", &"desk", 0.8)
	var opts: Array[String] = [INSTRUCT_STRICT, INSTRUCT_BEST, INSTRUCT_PARTY]
	var tries := 0
	while true:
		tries += 1
		var best := opts.find(INSTRUCT_BEST)
		var c: int = await dialogue.choose(line("instructions_prompt"), opts, best)
		if c == best:
			break
		if opts[c] == INSTRUCT_PARTY:
			_react(&"cheer")
			await _say("Marco", "Clink! Ha-ha! Happy birthday! More bread!")
			await _hoot("instructions_party")
		else:
			_react(&"confused")
			await _say("Marco", "Perfectly? Then you'll hear nothing from me after the soup.")
			await _hoot("instructions_strict")
		opts.remove_at(c)
	Game.record_medal("instructions", "gold" if tries == 1 else ("silver" if tries == 2 else "bronze"))
	Game.set_visit_flag("instructed", true)
	Game.set_visit_flag("instructed_first_try", tries == 1)
	await _hoot("instructions_best")
	_react(&"nod")
	await _say("Marco", "The main voice. Like listening to the chef over the clatter.")
	hud.call("complete_step", &"explain")


# ---------------------------------------------------------------- 5. Hoot's montage: tones, bone, SRTs, words

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
	screen.set("quick_visit", true)
	screen.call("start_test", patient, ear, false, plan)
	var r: Dictionary = await screen.test_finished
	tones = r
	results = r
	Game.set_audiometry_results(results)


func _montage() -> void:
	hud.call("set_step", &"beeps")
	clinic.call("focus_camera", &"booth", 1.2)
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.8)
	await _say("Marco", "Cosy. Like a pantry. Four stars.")
	await _hoot("tones")
	clinic.call("put_on_earphones", true)
	await _wait(0.6)
	var cam := _open_audiometer()
	# the right ear is the visit's first air ear, so its montage owes the 1 kHz retest (E2)
	await _tone_test("right", {"test": "ac", "hoot_turn_after": 0, "montage": true,
		"intro": "Better ear first: the right. Watch the stamps fly in!", "hoot_turn_text": "My montage! Right ear at top speed."})
	await _tone_test("left", {"test": "ac", "hoot_turn_after": 0, "montage": true,
		"intro": "Left ear, Hoot speed!", "hoot_turn_text": "Left ear at top speed. Same dance, other ear!"})
	# unmasked bone at 500-4k on the right mastoid; masked bone only where a gap shows
	_hide_audiometer(cam)
	clinic.call("focus_camera", &"ear_right", 0.5)
	clinic.call("put_on_bone_oscillator", "right")
	await _wait(0.6)
	cam = _open_audiometer()
	await _tone_test("right", {"test": "bc", "bc_freqs": ClinicRules.BC_REQUIRED.duplicate(), "masking_controls": true,
		"hoot_turn_after": 0, "montage": true, "intro": "Bone at 500 to 4k, at Hoot speed: is there any gap?"})
	var on_mastoid := "right"
	for ear: String in ClinicRules.EARS:
		if ClinicRules.masked_freqs_needed(results, ear, &"bc_masked").is_empty():
			continue
		var other := "left" if ear == "right" else "right"
		_hide_audiometer(cam)
		if on_mastoid != ear:
			clinic.call("put_on_bone_oscillator", ear)
			on_mastoid = ear
		clinic.call("put_on_masking_phone", other)
		await _wait(0.5)
		cam = _open_audiometer()
		await _tone_test(ear, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 0, "montage": true,
			"intro": "A gap? Masked bone settles it: the shhh goes in the %s ear." % other})
	Game.set_visit_flag("masked_bone", (((results.get("ears", {}) as Dictionary).get("right", {}) as Dictionary).get("bc_masked", {}) as Dictionary).size()
		+ (((results.get("ears", {}) as Dictionary).get("left", {}) as Dictionary).get("bc_masked", {}) as Dictionary).size() > 0)
	screen.queue_free()
	screen = null
	cam.current = true
	clinic.call("take_off_bone_oscillator")
	clinic.call("focus_camera", &"face", 0.6)
	var snhl := true
	for ear: String in ClinicRules.EARS:
		snhl = snhl and CaseData.measured_type(tones, ear) == &"sensorineural"
	await _hoot("bone" if snhl else "bone_other")
	await _hidden_speech()
	hud.call("complete_step", &"beeps")


## Hoot's SRTs and words in quiet, off-screen and right first (run_hidden: whatever quick visit
## says). The SPEECH screen is made here and kept for every party list (one session, D21).
func _hidden_speech() -> void:
	clinic.call("put_on_earphones", true)
	clinic.call("hold_response_button", false)
	var cam: Camera3D = clinic.call("get_main_camera")
	var packed: PackedScene = load(SPEECH_SCENE) as PackedScene if ResourceLoader.exists(SPEECH_SCENE) else null
	if packed != null:
		screen = packed.instantiate() as CanvasLayer
		add_child(screen)
		cam.current = false
	else:
		push_warning("LevelMarco: no SPEECH screen (%s); Hoot runs the tests himself" % SPEECH_SCENE)
	_speech_on = true
	var tr := String(_air_transducer())
	for ear: String in ClinicRules.EARS:
		_phase(&"speech", {"ear": ear, "test": "srt"})
		await _hidden(ear, {"test": "srt", "tones": tones, "transducer": tr})
	var wrs_ok := ResourceLoader.exists(SpeechTestMode.PATHS[&"wrs"])
	if not wrs_ok:
		await _hoot("no_wrs")
		return
	await _hoot("words_noise" if words_need_noise(tones, _air_transducer()) else "words_quiet")
	var lists := {"right": SpeechRules.WRS_LISTS[0], "left": SpeechRules.WRS_LISTS[1]}
	for ear: String in ClinicRules.EARS:
		_phase(&"speech", {"ear": ear, "test": "wrs"})
		await _hidden(ear, {"test": "wrs", "tones": tones, "list": String(lists[ear]), "transducer": tr})
	_shot("montage")
	var r := wrs_sheet("right")
	var l := wrs_sheet("left")
	var poorer := r if int(r.get("pct", 0)) < int(l.get("pct", 0)) else l
	var verdict := String(SpeechRules.WRS_BAND_TITLES.get(StringName(String(poorer.get("band", ""))), "Fine"))
	var pta := roundi(minf(ear_pta("right"), ear_pta("left")))
	await _hoot("summary", {"pta": pta, "r": int(r.get("pct", 0)), "l": int(l.get("pct", 0)), "verdict": verdict})


## Does a word list at the comfortable level need noise in the other ear, on either ear (the WRS
## mode's rule, D12)? The montage's line says so before Hoot runs them.
static func words_need_noise(tone_results: Dictionary, transducer: StringName) -> bool:
	for ear: String in ClinicRules.EARS:
		var pta := SpeechRules.pta_for_speech(ClinicRules.best_thresholds(tone_results, ear, false))
		if SpeechRules.speech_masking_needed(SpeechRules.wrs_level(pta), SpeechRules.nontest_best_bone(tone_results, ear), transducer):
			return true
	return false


## One of Hoot's off-screen tests on the SPEECH screen (or his fallback run without it).
func _hidden(ear: String, plan: Dictionary) -> void:
	if screen != null:
		await screen.call("run_hidden", patient, ear, plan)
		results = (screen as SpeechScreen).get_results()
	else:
		results = await _fallback(ear, plan)
	Game.set_audiometry_results(results)


## No SPEECH screen in this build: Hoot runs it by the textbook through SpeechSession (C23).
func _fallback(ear: String, plan: Dictionary) -> Dictionary:
	if _session == null:
		_session = SpeechSession.new(patient, Game.rng.randi())
	_session.configure(plan)
	_session.run_by_textbook(ear)
	await _wait(0.5)
	return SpeechSession.merge_results(tones, _session.build_results())


# ---------------------------------------------------------------- 6-14. the Party Noise Test

## Party list n's plan (contract §9.21, Day 5). Aided lists take SIN_AIDED_DB and level_by_hoot by
## default (SinTest); quick visit adds Hoot's first courses (hoot_first) on the player's lists.
func party_plan(n: int, quick: bool) -> Dictionary:
	var plan := {"test": "sin", "tones": tones, "list": SpeechRules.SIN_LISTS[n - 1], "lost_lines": MARCO_LOST.duplicate()}
	match n:
		1:
			plan.merge({"condition": "unaided", "level": 50, "practice": SpeechRules.SIN_PRACTICE_LIST, "hide_loss": true,
				"intro": line("intro_party1")})
		2:
			plan.merge({"condition": "unaided", "level_first": true})
			if quick:
				plan.merge({"hoot_first": 3, "intro": line("intro_party2"), "hoot_turn_text": line("pours")})
		3, 5:
			plan.merge({"condition": "omni" if n == 3 else "directional", "programme": "A" if n == 3 else "B",
				"intro": line("intro_aided_a" if n == 3 else "intro_aided_b")})
			if n == 5:
				plan["compare_to"] = "aided_omni"
			if quick:
				plan.merge({"hoot_first": 3, "hoot_turn_text": line("pours")})
		4, 6:
			plan.merge({"condition": "omni" if n == 4 else "directional", "programme": "A" if n == 4 else "B",
				"hoot_only": true, "hoot_turn_after": 0, "hoot_turn_text": line("hoot_list")})
			plan.erase("lost_lines")
			if n == 6:
				plan["compare_to"] = "aided_omni"
	if n <= 2:
		plan["transducer"] = String(_air_transducer())
	return plan


## One party list on the SPEECH screen (or Hoot's fallback run): the merged results come back.
func _party_list(n: int, coached: bool) -> void:
	var plan := party_plan(n, quick_visit())
	_phase(&"speech", {"ear": "both", "test": "sin", "list": String(plan["list"]), "condition": String(plan["condition"])})
	if screen != null:
		screen.visible = true
		(clinic.call("get_main_camera") as Camera3D).current = false
		screen.set("quick_visit", quick_visit())
		screen.call("start_test", patient, "both", coached, plan)
		results = await screen.test_finished
	else:
		results = await _fallback("both", plan)
	Game.set_audiometry_results(results)


## The SPEECH screen steps aside for a board (its session is kept for the next list).
func _screen_aside() -> void:
	if screen != null:
		screen.visible = false
	(clinic.call("get_main_camera") as Camera3D).current = true


func _party_1() -> void:
	hud.call("set_step", &"party1")
	await _party_list(1, true)
	_screen_aside()
	clinic.call("focus_camera", &"face", 0.4)
	_react(&"confused")
	await _say("Marco", "The starter was delicious. The main was muddy. Dessert? I tasted only noise.")
	await _hoot("list_done")
	hud.call("complete_step", &"party1")


## The bill (CHAPTER5 §5.7): the receipt with the player's own counts, "What's the bill?", the band.
func _bill() -> void:
	_phase(&"evidence", {"board": "bill"})
	hud.call("set_step", &"bill")
	board = MarcoBoard.new()
	hud.call("add_game", board)
	var rec := newest_party("both")
	var total := int(rec.get("total", 0))
	var loss := SpeechRules.snr_loss(total)
	await board.call("show_bill", rec)
	_shot("bill", 0.2)
	var opts := bill_options(total)
	var keys: Array[StringName] = []
	var texts: Array[String] = []
	for o: Array in opts:
		keys.append(StringName(o[0]))
		texts.append(String(o[1]))
	while true:
		_bill_tries += 1
		var c: int = await dialogue.choose(line("bill", {"total": total}), texts, keys.find(&"loss"))
		await _hoot(String(BILL_LINES[keys[c]]))
		if keys[c] == &"loss":
			break
	if SpeechRules.sin_band(loss) == &"moderate" or SpeechRules.sin_band(loss) == &"severe":
		await _say("Marco", "%s dB! For a critic, that's a terrible review." % db_text(loss))
	var band := SpeechRules.sin_band(loss)
	await _hoot("band_prompt", {"loss": db_text(loss)})
	while true:
		_band_tries += 1
		var pick: StringName = await board.call("pick_band", loss)
		if pick == band:
			break
	await board.call("pay", band)
	_shot("band_pointer", 0.3)
	await _hoot("band_" + String(band))
	await _say("Marco", "So my ears need the voice served... a little hotter than everyone else's.")
	Game.set_visit_flag("bill_tries", _bill_tries)
	Game.set_visit_flag("band_tries", _band_tries)
	Game.record_medal("bill", bill_medal(_bill_tries, _band_tries))
	hud.call("complete_step", &"bill")


## The bill's three answers, shuffled by the total (so the right one moves): [key, text].
static func bill_options(total: int) -> Array:
	var loss := SpeechRules.snr_loss(total)
	var opts: Array = [["loss", "%s dB" % db_text(loss)], ["total", "%d dB" % total], ["added", "%s dB" % db_text(SpeechRules.SIN_CONSTANT + total)]]
	for i in total % 3:
		opts.push_back(opts.pop_front())
	return opts


## Bill: gold = the bill and the band both first try; silver = one slip; bronze = more.
static func bill_medal(bill_tries: int, band_tries: int) -> String:
	var slips := (bill_tries - 1) + (band_tries - 1)
	return "gold" if slips <= 0 else ("silver" if slips == 1 else "bronze")


func _party_2() -> void:
	hud.call("set_step", &"party2")
	await _hoot("second_list")
	if board != null:
		board.visible = false
	await _party_list(2, false)
	_screen_aside()
	var sheet := sin_sheet("both")
	var avg := float(sheet.get("snr_loss", 0.0))
	var band := StringName(String(sheet.get("band", SpeechRules.sin_band(avg))))
	if board != null:
		board.visible = true
		await board.call("show_average", sheet.get("lists", []), avg, band)
	_shot("average", 0.2)
	await _hoot("average", {"avg": db_text(avg), "band": String(SpeechRules.SIN_BAND_NAMES.get(band, ""))})
	await _hoot("normed")
	hud.call("complete_step", &"party2")


## The four clue cards for the two plates (CHAPTER5 §5.7), with this visit's numbers.
func plate_cards() -> Array[Dictionary]:
	var r := wrs_sheet("right")
	var l := wrs_sheet("left")
	var poorer := r if int(r.get("pct", 0)) < int(l.get("pct", 0)) else l
	var wband := String(SpeechRules.WRS_BAND_TITLES.get(StringName(String(poorer.get("band", ""))), "Fine"))
	var sheet := sin_sheet("both")
	var avg := float(sheet.get("snr_loss", 0.0))
	var sband := String(SpeechRules.SIN_BAND_NAMES.get(StringName(String(sheet.get("band", SpeechRules.sin_band(avg)))), ""))
	var pta := roundi(minf(ear_pta("right"), ear_pta("left")))
	return MarcoBoard.plate_cards(int(r.get("pct", 0)), int(l.get("pct", 0)), wband, pta, avg, sband)


func _plates() -> void:
	_phase(&"evidence", {"board": "plates"})
	hud.call("set_step", &"plates")
	await _hoot("plates")
	await board.call("setup_plates", plate_cards())
	_shot("plates", 0.6)
	await board.call("run_plates")
	_plates_slips = int(board.get("plate_slips"))
	var pta_used := bool(board.get("pta_used"))
	_shot("both_true", 0.8)
	await _wait(1.0)
	Game.set_visit_flag("plates_slips", _plates_slips)
	Game.record_medal("evidence", plates_medal(_plates_slips, pta_used))
	var avg := float(sin_sheet("both").get("snr_loss", 0.0))
	await _hoot("whole_story", {"avg": db_text(avg)})
	await _hoot("real_trouble")
	hud.call("complete_step", &"plates")


## Case: gold = the two best cards with no slips; silver = one slip or the PTA card; bronze = more.
static func plates_medal(slips: int, pta_used: bool) -> String:
	if slips == 0 and not pta_used:
		return "gold"
	return "silver" if slips + (1 if pta_used else 0) <= 1 else "bronze"


func _fitting() -> void:
	_phase(&"fitting")
	board.visible = false
	clinic.call("focus_camera", &"face", 0.5)
	await _hoot("sound_field")
	clinic.call("take_off_earphones")
	await _wait(0.3)
	clinic.call("put_on_hearing_aids")
	await _wait(0.6)
	clinic.call("focus_camera", &"booth", 0.8)
	clinic.call("show_soundfield", true)
	_shot("soundfield", 1.2)
	await _wait(1.0)
	await _hoot("blind")
	_react(&"nod")
	await _say("Marco", "A blind tasting. My favourite kind.")


## Programme A (OMNI, lists 3-4) or B (FOCUS, lists 5-6): the player's list, then Hoot's.
func _programme(p: StringName) -> void:
	var a := p == &"A"
	hud.call("set_step", &"prog_a" if a else &"prog_b")
	await _party_list(3 if a else 5, false)
	await _party_list(4 if a else 6, false)
	_screen_aside()
	clinic.call("focus_camera", &"face", 0.4)
	if not a:
		await _say("Marco", "Now the voice is the main course, and the noise is just... garnish.")
	hud.call("complete_step", &"prog_a" if a else &"prog_b")


## The pizza (omni hears it all; directional favours the front half), then the blind switch.
func _pizza_and_switch() -> void:
	_phase(&"fitting", {"board": "pizza"})
	board.visible = true
	await board.call("show_pizza")
	_shot("pizza", 1.6)
	await _hoot("pizza")
	board.call("pizza_focus", true)
	await _say("Marco", "The front half, facing my guest. The back half... a little less.")
	await _hoot("switch")
	await board.call("show_switch")
	_shot("switch", 0.5)
	await board.call("flip_switch")
	await _wait(0.6)
	await _hoot("like_with_like")
	board.visible = false


## The reveal card: Marco guesses, then A against B (CHAPTER5 §6.8).
func _reveal() -> void:
	_phase(&"fitting", {"board": "reveal"})
	var omni := sin_sheet("aided_omni")
	var focus := sin_sheet("aided_directional")
	var benefit := float(focus.get("benefit_db", float(omni.get("snr_loss", 0.0)) - float(focus.get("snr_loss", 0.0))))
	var crit := float(focus.get("crit_diff_db", SpeechRules.sin_crit_diff(2)))
	var real := bool(focus.get("real_change", SpeechRules.sin_real_change(benefit, 2)))
	Game.set_visit_flag("marco_guess", "B" if real else "unsure")
	Game.set_visit_flag("benefit_unsure", not real)
	await _say("Marco", "B! B was the main course." if real else "A... or B? Both tasted rather similar.")
	board.visible = true
	await board.call("show_reveal", omni, focus, benefit, crit, real)
	_shot("reveal", 0.6)
	if real:
		await _hoot("benefit_real", {"benefit": db_text(benefit)})
	else:
		await _hoot("benefit_small", {"benefit": db_text(benefit), "crit": db_text(crit)})
		await _hoot("benefit_small_then")
	await _hoot("why_blind")
	await _hoot("booth_kinder")
	await board.call("fade_out")
	board.queue_free()
	board = null


func _close_speech() -> void:
	_speech_on = false
	if screen != null:
		screen.queue_free()
		screen = null
	(clinic.call("get_main_camera") as Camera3D).current = true
	clinic.call("show_soundfield", false)


# ---------------------------------------------------------------- 15. counselling: seat Marco

func _seat() -> void:
	_phase(&"counselling", {"board": "seats"})
	hud.call("set_step", &"seat")
	var seats := MarcoSeats.new()
	hud.call("add_game", seats)
	await _wait(0.4)
	_shot("seats", 0.4)
	var texts: Array[String] = []
	var best := 0
	for i in SEATS.size():
		texts.append(String(SEATS[i]["text"]))
		if bool(SEATS[i].get("best", false)):
			best = i
	while true:
		_seat_tries += 1
		var i: int = await seats.choose(line("seat_prompt"), texts, best)
		await seats.sit(String(SEATS[i]["id"]))
		if String(SEATS[i]["id"]) == "facing":
			_shot("seat_facing", 0.2)
		await _hoot(String(SEATS[i]["line"]))
		if i == best:
			break
	Game.set_visit_flag("seat_tries", _seat_tries)
	Game.record_medal("help", "gold" if _seat_tries == 1 else ("silver" if _seat_tries == 2 else "bronze"))
	await _hoot("tips")
	await _hoot("remote_mic")
	await _say("Marco", "A little microphone for my guest? Like a salt shaker for words!")
	await seats.fade_out()
	seats.queue_free()
	hud.call("complete_step", &"seat")


# ---------------------------------------------------------------- 16. the payoff: dinner at Trattoria Clatter

func _dinner() -> void:
	_phase(&"counselling", {"board": "dinner"})
	await clinic.call("stand")
	var d := MarcoDinner.new()
	hud.call("add_game", d)
	await d.open()
	_shot("dinner", 0.6)
	await _say("Rosa", "Papa, I have news. Luca proposed. We're getting married!")
	d.cheer()
	_shot("married", 0.4)
	await _say("Marco", "Married? MARRIED! I heard every word!")
	d.tray_crash()
	_shot("tray_crash", 0.3)
	await _say("Marco", "And THAT I heard behind me. Just a little. Perfect.")
	await _hoot("expectations")
	await _say("Marco", "Tiramisu for the whole room! ...Put it on the owl's bill.")
	await _hoot("allow")
	await d.write_review()
	await _say("Marco", "Booth Camp. Read my review tomorrow. I'm booking the nine o'clock table.")
	await _hoot("goodbye")
	await d.fade_out()
	d.queue_free()


# ---------------------------------------------------------------- 17. results

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	summary["headlines"] = HEADLINES
	summary["subheads"] = SUBHEADS
	summary["medal_beats"] = MEDAL_BEATS
	summary["weather"] = WEATHER
	summary["sports_script"] = SPORTS_SCRIPT
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


# ---------------------------------------------------------------- sheets

## The ear's PTA from Hoot's tones (as the SPEECH screen computes it). NAN before the tones.
func ear_pta(ear: String) -> float:
	if tones.is_empty():
		return NAN
	return SpeechRules.pta_for_speech(ClinicRules.best_thresholds(tones, ear, false))


func wrs_sheet(ear: String) -> Dictionary:
	return (((results.get("speech", {}) as Dictionary).get("wrs", {}) as Dictionary).get(ear, {}) as Dictionary)


func sin_sheet(slot: String) -> Dictionary:
	return (((results.get("speech", {}) as Dictionary).get("sin", {}) as Dictionary).get(slot, {}) as Dictionary)


## The slot's newest party list ({} = none).
func newest_party(slot: String) -> Dictionary:
	var lists: Array = sin_sheet(slot).get("lists", [])
	return (lists.back() as Dictionary) if not lists.is_empty() else {}
