extends Node
## Dev gallery for the SPEECH screen's WORD mode (Day 4; developer tool, never reachable from the
## game). Nora (built here until core/patients/nora.tres exists) and Hoot's tone sheets; the four
## Day 4 lists are played through the screen's own controls (do_action), scoring each word by the
## truth, with a screenshot at every new state: the coached denial, the level set, the first word,
## lens_try, the lens and the Banana Board, Call it, Hoot's x8 turn, a stored list, the tea demo,
## the level chip, BOO!, GHOST BUSTED!, the audible miss stamp, the ear compare, the lurking Ghost,
## the loud bubble and the louder list's slide.
##   timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy --fixed-fps 30 -- --scene=res://ui/dev/dev_speech_word.tscn --shots=/abs/dir
## Full HD: add --resolution 1920x1080 before "--" (and a 1920x1080x24 screen). Optional:
## --reduced-motion, --only=w1,w2,redo,louder (lists to shoot; the others still run).

const SCREEN_SCENE := "res://ui/speech/speech_screen.tscn"
## Her chatty-hit lines follow the word itself ("Seal! Like a good downbeat."; contract §9.12.1).
const NORA_CHATTER: Array[String] = ["Like a good downbeat.", "Lovely and clear, that {word}.", "I'd know it anywhere.", "Next!"]
const NORA_SILENCES: Array[String] = ["Sorry?", "Mm?", "(hums uncertainly)"]
const TEA_DEMO := {
	"text": "Fancy a cup of tea?", "level": 50,
	"chunks": [["F", "f"], ["a", "vowel"], ["n", "n"], ["c", "s"], ["y", "vowel"], [" ", ""], ["a", "vowel"], [" ", ""], ["c", "k"],
		["u", "vowel"], ["p", "p"], [" ", ""], ["o", "vowel"], ["f", "v"], [" ", ""], ["t", "t"], ["ea", "vowel"], ["?", ""]],
	"lines": [["hoot", "This is chatting level, 50. Watch what reaches her left ear."], ["nora", "Candy... a canoe? At my age?"],
		["hoot", "That's her complaint: voices, but not words!"],
		["hoot", "Your turn: set a level loud enough for every sound, and decide about noise."]],
}

var screen: SpeechScreen
var nora: PatientProfile
var tones: Dictionary = {}
var _finished := false
var _only: PackedStringArray = []


func demo_start() -> void:
	Game.settings["show_key_hints"] = true
	Game.settings["reduced_motion"] = Game.cli_flag("reduced-motion")
	Game.settings["quick_visit"] = true
	var only := Game.cli_value("only", "")
	if only != "":
		_only = only.split(",")
	Game.begin_visit("nora")
	Hoot.reset_visit()
	nora = _nora()
	tones = _nora_tones()
	screen = (load(SCREEN_SCENE) as PackedScene).instantiate() as SpeechScreen
	add_child(screen)
	screen.quick_visit = true
	screen.test_finished.connect(func(_r: Dictionary) -> void: _finished = true)
	await _wait(0.4)
	await _list_1()
	await _list_2()
	await _redo()
	await _louder()
	await _wait(0.3)
	get_tree().quit(0)


# ---------------------------------------------------------------- the lists

func _list_1() -> void:
	_start("right", true, {"list": "words_1", "lens_try_after": 2, "call_it": [&"faint_hit"], "chatter": NORA_CHATTER, "hoot_turn_after": 8})
	await _wait(1.2)
	# the coached denial: PRESENT at the start level
	screen.do_action(&"present")
	await _wait(0.6)
	await _shot("w1", "w1_deny")
	await _to_target()
	await _wait(1.0)
	await _shot("w1", "w1_level_set")
	await _present()
	await _shot("w1", "w1_first_word")
	_score_truth()
	await _word()
	await _wait(0.6)
	await _shot("w1", "w1_lens_try")
	screen.do_action(&"lens_toggle")
	await _wait(0.9)
	await _shot("w1", "w1_lens_on")
	await _until(func() -> bool: return screen.idle() or bool(screen.get_state()["call_it_card"]))
	while not bool(screen.get_state()["call_it_card"]) and not screen.session.is_done() and screen.session.trials_for().size() < 6:
		await _word()
	if bool(screen.get_state()["call_it_card"]):
		await _wait(0.5)
		await _shot("w1", "w1_call_it")
		_call_best()
		await _present()
		await _wait(0.4)
		await _shot("w1", "w1_call_after")
		_score_truth()
	await _play_until_hoot()
	await _wait(0.8)
	await _shot("w1", "w1_hoot_turn")
	await _until_stored()
	await _wait(0.5)
	await _shot("w1", "w1_stored")
	await _wait(1.0)
	await _shot("w1", "w1_celebrate")
	await _until(func() -> bool: return _finished, 12.0)


func _list_2() -> void:
	_start("left", false, {"list": "words_2", "level": SpeechRules.CHAT_DB, "chat_demo": TEA_DEMO, "ensure_audible_miss_by": 6,
		"audible_stamp": true, "call_it": [&"audible_miss"], "aside_by": 8, "self_correct": true, "chatter": NORA_CHATTER,
		"silences": NORA_SILENCES, "confirmed_wrong_hoot_after": 3, "hoot_turn_after": 8})
	await _wait(2.8)
	await _shot("w2", "w2_tea_demo")
	await _until(func() -> bool: return not screen.hoot_running() and screen.idle(), 30.0)
	await _wait(0.3)
	screen.do_action(&"present")
	await _wait(0.6)
	await _shot("w2", "w2_confirm_level")
	await _to_target()
	await _wait(0.5)
	screen.do_action(&"present")
	await _wait(0.7)
	await _shot("w2", "w2_boo")
	screen.do_action(&"mask_toggle")
	await _wait(0.95)   # the GHOST BUSTED! callout lands at about 0.76 s
	await _shot("w2", "w2_busted")
	await _wait(1.2)
	await _present()
	await _shot("w2", "w2_first_word")
	_score_truth()
	var guard := 0
	while not bool(screen.get_state()["call_it_card"]) and guard < 8 and not screen.hoot_running():
		guard += 1
		await _word()
	if bool(screen.get_state()["call_it_card"]):
		await _wait(0.5)
		await _shot("w2", "w2_call_it")
		_call_best()
		await _present()
		_score_truth()
		await _wait(0.5)
		await _shot("w2", "w2_audible_miss")
	await _play_until_hoot()
	await _until_stored()
	await _wait(1.6)
	await _shot("w2", "w2_stored")
	await _until(func() -> bool: return _finished, 12.0)


func _redo() -> void:
	_start("left", true, {"list": "words_3", "redo_of": 2, "ensure_audible_miss_by": 6, "audible_stamp": true, "aside_by": 5,
		"chatter": NORA_CHATTER, "silences": NORA_SILENCES, "hoot_turn_after": 5})
	await _wait(1.0)
	await _shot("redo", "redo_start")
	for i in 4:
		screen.do_action(&"louder")
		await _wait(0.15)
	await _wait(0.8)
	await _shot("redo", "redo_lurk")
	await _to_target()
	await _wait(0.9)
	await _shot("redo", "redo_lurk_bold")
	screen.do_action(&"mask_toggle")
	await _wait(0.95)
	await _shot("redo", "redo_busted")
	await _wait(1.0)


func _louder() -> void:
	_start("left", true, {"list": "words_4", "louder_than": 2, "mask_on": true, "lock_noise": true, "loud_bubble": true, "aside_by": 5,
		"chatter": NORA_CHATTER, "silences": NORA_SILENCES, "hoot_turn_after": 5})
	await _wait(1.0)
	await _shot("louder", "louder_start")
	screen.do_action(&"mask_toggle")
	await _wait(0.5)
	await _shot("louder", "louder_noise_locked")
	await _to_target()
	await _wait(0.6)
	await _present()
	await _wait(0.3)
	await _shot("louder", "louder_first_answer")
	_score_truth()
	await _play_until_hoot()
	await _until_stored()
	await _wait(1.6)
	await _shot("louder", "louder_stored")
	await _until(func() -> bool: return _finished, 12.0)
	await _wait(0.3)
	await _shot("louder", "louder_after")


# ---------------------------------------------------------------- driving the screen

func _start(ear: String, coached: bool, extra: Dictionary) -> void:
	_finished = false
	Events.phase_changed.emit(&"speech", {})   # clears Hoot's tips, like the level
	var plan := {"test": "wrs", "tones": tones}
	plan.merge(extra, true)
	screen.start_test(nora, ear, coached, plan)


## Taps LOUDER / SOFTER to the textbook level.
func _to_target() -> void:
	var guard := 0
	while guard < 30:
		guard += 1
		var target := screen.session.mode.textbook_target()
		if screen.session.db == target:
			return
		screen.do_action(&"louder" if screen.session.db < target else &"softer")
		await _wait(0.1)


## PRESENT, then wait for her answer.
func _present() -> void:
	await _until(func() -> bool: return screen.idle(), 10.0)
	screen.do_action(&"present")
	await _until(func() -> bool: return screen.answer_shown() and screen.session.awaiting_score, 15.0)
	await _wait(0.25)


func _score_truth() -> void:
	var ok := bool(screen.session.current.get("correct", false))
	screen.do_action(&"score_correct" if ok else &"score_missed")


func _word() -> void:
	await _present()
	_score_truth()
	await _wait(0.2)


func _call_best() -> void:
	var rec := screen.session.recommended_action()
	screen.do_action(&"call_it_yes" if bool(rec.get("guess", true)) else &"call_it_no")


## The player's words until Hoot takes his turn (or the list ends).
func _play_until_hoot() -> void:
	var guard := 0
	while guard < 30 and not screen.hoot_running() and not screen.session.is_done():
		guard += 1
		await _until(func() -> bool: return screen.idle() or screen.hoot_running() or screen.session.is_done(), 10.0)
		if screen.hoot_running() or screen.session.is_done():
			break
		if bool(screen.get_state()["call_it_card"]):
			_call_best()
			await _wait(0.2)
			continue
		await _word()


func _until_stored() -> void:
	await _until(func() -> bool: return screen.session.is_done(), 40.0)


func _until(cond: Callable, max_s: float = 10.0) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_s * 1000.0):
			push_warning("dev_speech_word: timed out waiting")
			return
		await get_tree().process_frame


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _shot(group: String, n: String) -> void:
	if not _only.is_empty() and group not in _only:
		return
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


# ---------------------------------------------------------------- Nora (CHAPTER4 §2)

func _nora() -> PatientProfile:
	if ResourceLoader.exists("res://core/patients/nora.tres"):
		return Game.load_patient("nora") as PatientProfile
	var p := PatientProfile.new()
	p.id = "nora"
	p.display_name = "Nora Nightingale"
	p.pronoun = "she"
	var r := [10, 10, 10, 15, 15, 20, 25, 30, 35, 40]
	var l := [30, 35, 35, 40, 45, 45, 50, 55, 55, 60]
	for i in ClinicRules.AC_FREQS.size():
		p.thresholds_right[ClinicRules.AC_FREQS[i]] = r[i]
		p.thresholds_left[ClinicRules.AC_FREQS[i]] = l[i]
	p.ia_phones_db = 50
	p.ia_inserts_db = 75
	p.speech = {"srt": {"right": 15, "left": 40}, "wrs_max": {"right": 96, "left": 52},
		"rollover": {"left": {"after": 75, "drop_per_10db": 20}}, "neural": {"left": true}}
	return p


## Hoot's three Day 4 tone sheets: right air, left air, left masked bone at 1k and 4k.
static func _nora_tones() -> Dictionary:
	var oct := {"right": {250: 10, 500: 10, 1000: 15, 1500: 15, 2000: 20, 3000: 25, 4000: 30, 6000: 35, 8000: 40},
		"left": {250: 30, 500: 35, 1000: 40, 1500: 45, 2000: 45, 3000: 50, 4000: 55, 6000: 55, 8000: 60}}
	var ears := {}
	for e: String in ["right", "left"]:
		var freqs := {}
		var t: Dictionary = oct[e]
		for f: int in t:
			freqs[f] = {"ear": e, "freq": f, "stored_db": t[f], "true_db": t[f], "error_db": 0.0, "by_hoot": true, "test": "ac"}
		ears[e] = {"freqs": freqs, "complete": true}
	ears["left"]["bc_masked"] = {
		1000: {"ear": "left", "freq": 1000, "stored_db": 40, "true_db": 40, "by_hoot": true, "test": "bc_masked"},
		4000: {"ear": "left", "freq": 4000, "stored_db": 55, "true_db": 55, "by_hoot": true, "test": "bc_masked"},
	}
	return {"patient_id": "nora", "ears": ears}
