extends Node
## Dev gallery for Day 5 (developer tool, not part of the game flow): the SPEECH screen's PARTY mode
## on Marco, driven by the textbook (SpeechSession.recommended_action() through the screen's own
## controls), with a screenshot at each step:
##   tools/scene_shot.sh res://story/dev_marco.tscn /abs/dir "1" 200   (shots come from the script)
## Add -- --part=screen after the quit time (the default and, for now, the only part); add
## --reduced-motion to shoot the still versions. Marco is his patient file once it is in, else a
## stand-in with the same numbers as the tests' (core/tests/test_speech_sin_model.gd).
##   day5_party_level    the coached list: the talker at 50, the coach's hand on LOUDER
##   day5_practice       Hoot's practice sentence at x1
##   day5_scoring        sentence 1: chips half marked, the focus ring
##   day5_lock_tray      LOCK IN: the misses ride off on the waiter's tray (reduced motion: greyed)
##   day5_noise_wins     Dessert at 0 dB: the bars meet, the room is packed
##   day5_list_done      the total lands on the courses
##   day5_soundfield     programme A in the sound field: the talker in front, the party behind
##   day5_focus_revealed programme B once the reveal names FOCUS: the front half bright
##   day5_hoot_turn      Hoot pours the first courses at x8

const SCREEN := "res://ui/speech/speech_screen.tscn"
const MARCO := "res://core/patients/marco.tres"

var screen: SpeechScreen
var marco: PatientProfile


func _ready() -> void:
	Game.begin_visit("mike")
	if Game.cli_flag("reduced-motion"):
		Game.settings["reduced_motion"] = true
	marco = load(MARCO) as PatientProfile if ResourceLoader.exists(MARCO) else _stand_in()


func demo_start() -> void:
	var part := Game.cli_value("part", "screen")
	if part in ["all", "screen"]:
		await _screen_part()
	get_tree().quit()


func _screen_part() -> void:
	screen = (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	add_child(screen)
	var tones := SpeechSession.tone_results_from(marco)
	# Party list 1: coached, the practice first, the dial at 50
	screen.start_test(marco, "both", true, {"test": "sin", "tones": tones, "list": "party_1", "condition": "unaided", "level": 50,
		"practice": "party_practice", "hide_loss": true, "intro": "Party time! Both ears together, like a real dinner. His ears match."})
	await _wait(5.0)
	await _shot("day5_party_level")
	while screen.session.db < screen.session.textbook_target():
		screen.do_action(&"louder")
		await _wait(0.25)
	screen.do_action(&"present")   # Hoot's practice turn
	await _until(func() -> bool: return bool(screen.get_state()["answer_shown"]) and screen.hoot_running(), 30.0)
	await _wait(1.0)
	await _shot("day5_practice")
	await _until(func() -> bool: return not screen.hoot_running() and screen.idle(), 30.0)
	await _wait(1.2)
	# sentence 1 by the player: two chips marked, then the shot
	screen.do_action(&"present")
	await _until(_marking, 30.0)
	for i in 2:
		_textbook_mark()
		await _wait(0.3)
	await _wait(0.6)
	await _shot("day5_scoring")
	# a slip on purpose so the tray carries something: chip 5 ticked whatever he said, then lock
	while int(_sin().get("focus_key", -1)) >= 0 and int(_sin().get("focus_key", -1)) < 4:
		_textbook_mark()
		await _wait(0.2)
	screen.do_action(&"score_missed")
	await _wait(0.3)
	screen.do_action(&"lock")
	await _wait(0.55)
	await _shot("day5_lock_tray")
	await _wait(2.0)
	# sentences 2-5 by the textbook, fast; then Dessert
	Engine.time_scale = 6.0
	while int(_sin().get("sentence_n", 1)) < 6 or not bool(_sin().get("awaiting_lock", false)):
		await _until(func() -> bool: return screen.idle() or bool(screen.get_state()["finishing"]), 30.0)
		if bool(screen.get_state()["finishing"]):
			break
		if int(_sin().get("sentence_n", 1)) == 6 and not bool(_sin().get("awaiting_lock", false)):
			screen.do_action(&"present")
			await _until(_marking, 30.0)
			break
		var rec := screen.session.recommended_action()
		screen.do_action(StringName(String(rec["action"])), rec)
		await _wait(0.2)
	Engine.time_scale = 1.0
	await _wait(0.8)
	await _shot("day5_noise_wins")
	await _finish_by_textbook()
	await _wait(0.9)
	await _shot("day5_list_done")
	await _until(func() -> bool: return not bool(screen.get_state()["finishing"]) or not screen.is_inside_tree(), 8.0)
	await _wait(3.5)
	# programme A in the sound field (set by Hoot), then B once FOCUS is revealed
	screen.start_test(marco, "both", false, {"test": "sin", "tones": tones, "list": "party_3", "condition": "omni", "programme": "A"})
	await _wait(1.0)
	screen.do_action(&"present")
	await _wait(1.6)
	await _shot("day5_soundfield")
	await _until(_marking, 30.0)
	await _finish_by_textbook()
	await _wait(5.0)
	screen.start_test(marco, "both", false, {"test": "sin", "tones": tones, "list": "party_5", "condition": "directional", "programme": "B",
		"compare_to": "aided_omni", "revealed": true, "hoot_first": 3, "hoot_only": true})
	await _wait(2.6)
	await _shot("day5_hoot_turn")
	await _until(func() -> bool: return not screen.hoot_running() and screen.idle(), 60.0)
	screen.do_action(&"present")
	await _wait(1.6)
	await _shot("day5_focus_revealed")


## Lock in what is on the card by the textbook, then the rest of the list.
func _finish_by_textbook() -> void:
	Engine.time_scale = 6.0
	var guard := 0
	while not bool(screen.get_state()["finishing"]) and guard < 200:
		guard += 1
		await _until(func() -> bool: return screen.idle() or bool(screen.get_state()["finishing"]), 30.0)
		if bool(screen.get_state()["finishing"]):
			break
		var rec := screen.session.recommended_action()
		screen.do_action(StringName(String(rec["action"])), rec)
		await _wait(0.15)
	Engine.time_scale = 1.0


func _textbook_mark() -> void:
	var rec := screen.session.recommended_action()
	screen.do_action(StringName(String(rec["action"])), rec)


func _marking() -> bool:
	var st := screen.get_state()
	return bool(_sin().get("awaiting_lock", false)) and bool(st["answer_shown"]) and not bool(st["talking"]) and not bool(st["listening"])


func _sin() -> Dictionary:
	return screen.get_state().get("sin", {})


func _until(cond: Callable, max_s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()) and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n + ("_still" if bool(Game.settings.get("reduced_motion", false)) else ""))
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


## Marco until his patient file is in: the numbers the Day 5 tests pin (a mild sloping loss, ears
## alike, an SNR loss of 9 dB and a FOCUS benefit of 4).
static func _stand_in() -> PatientProfile:
	var p := PatientProfile.new()
	p.id = "marco_standin"
	p.display_name = "Marco Polenta"
	var right: Dictionary[int, int] = {250: 10, 500: 15, 750: 15, 1000: 20, 1500: 25, 2000: 30, 3000: 35, 4000: 40, 6000: 40, 8000: 35}
	var left: Dictionary[int, int] = {250: 10, 500: 15, 750: 15, 1000: 25, 1500: 25, 2000: 30, 3000: 35, 4000: 40, 6000: 45, 8000: 40}
	p.thresholds_right = right
	p.thresholds_left = left
	p.reaction_time_min_s = 0.7
	p.reaction_time_max_s = 1.3
	p.psychometric_slope_db = 2.5
	p.attention = 0.95
	p.speech = {"wrs_max": {"right": 96, "left": 92}, "snr_loss": 9.0, "directional_benefit": 4.0}
	return p
