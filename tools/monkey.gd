extends Node
## Monkey: a sloppy, button-mashing trainee for the AudiOtron (stress test, not a player).
## Boot:  godot --headless --path . --fixed-fps 30 -- --scene=res://tools/monkey.tscn --speed=3 --seed=N
## Tests the coached right ear, then the solo left ear (quick visit: Hoot's x8 turn), while it
## half-follows the textbook and half mashes random keys, clicks, right-clicks, pause-menu keys,
## too-short and too-long beeps. Checks every frame:
##   - no script errors;  - no tone left playing without a held key or mouse;
##   - Engine.time_scale only x8 during Hoot's turn and back to normal after it.
## (v3) --day=2: Bonnie's Day 2 tests instead (air both ears with Hoot's turns, then bone, masked
## bone and masked air), mashing the MASKING / ROUTE controls too (M, PgUp / PgDn, Shift+Up / Down,
## A, B). Extra invariants: the noise dial stays in 0..100 dB EM, the masker only plays while
## MASK is on, and no masker is left playing after a test.
## (v4) --day=2 first mashes Hoot's masking movie three ways (story/explainers/, CONTRACTS.md §3.4):
## (1) as a level plays it (a pausable parent) with Space / Enter / clicks / Next / P / II but no
## Esc: it must step one scene at a time to the end, not skipped, and P must freeze it; (2) the same
## plus Esc and "Skip movie": an accepted Esc ends it at once; (3) the pause menu's "Watch Hoot's
## masking movie" replay (a real click) with the same keys: the menu comes back. Invariants: the
## scenes go 0, 1, 2, ... one at a time, every movie ends within MOVIE_MAX_S, nothing is left paused
## or in the explainer_player group.
## (cases) --day=6 and up (any chapter with a "case"): that case's test plan on its patient (with
## its montage and Hoot's turns), then masked bone and masked air on each ear wherever the stamps
## ask (the runner's order, CaseData.masked_bone_ears), then the case's retest plan if it
## has one (a fresh session on the treated ear). The masking keys and Day 2's invariants apply.
## (Speech) --day=3: Mike's Day 3 instead: the SPEECH screen (the coached right ear, Hoot's recheck
## of it on a fresh session at x8, then the left ear with Hoot's x8 turn after the step up 5, as
## the level plans it), mashing PRESENT / CORRECT / MISSED / the level / STORE / MASK by key and by
## click (with sloppy scores and double STOREs), then the Day 3 board (the cards flip, the
## say-along cut short, the drop, OBJECTION!, the stamp) under random arrows, Enter, 1-3, clicks
## and drags. Extra invariants: the dial stays in SpeechRules.MIN_DB..MAX_DB; the speech noise only
## plays while MASK is on, in the other ear at the session's mask level, never in Hoot's (silent)
## turn, and none is left after an ear; no TALK lamp stuck; Hoot's recheck stores its bracket; the
## board ticks every card the say-along covered, drops exactly the unknown word, lands the
## measurement clue and stamps.
## Any other day (Days 4 and 5, or a --day / --chapter that names no chapter) is refused with a
## message and exit 2: nothing runs, never Day 1 in its place.
## Prints MONKEY_RESULT {json}; exit 0 ok, 1 an invariant broke, 2 unsupported day, 3 timeout.

const ErrorCounter := preload("res://tools/autoplay_bot.gd").ScriptErrorCounter
const Movies := preload("res://story/explainers/movies.gd")
const CaseData := preload("res://story/case_data.gd")
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const MAX_GAME_S := 1500.0
const ACTIONS: Array[StringName] = [&"present_tone", &"louder", &"softer", &"freq_up", &"freq_down", &"store",
	&"no_response", &"ear_right", &"ear_left", &"toggle_key_hints", &"advance_dialogue", &"ui_accept"]
## (v3) Day 2's extra controls.
const ACTIONS_V3: Array[StringName] = [&"toggle_mask", &"mask_louder", &"mask_softer", &"transducer_air", &"transducer_bone"]
const MAX_GAME_S_DAY2 := 3600.0
## (v3) Bonnie's tests in story order: [ear, coached, plan].
## (v4) bone on the better (left) ear first, then the one-tone Ghost demo on the right (plan
## demo_tone: only TONE works, nothing is stored), then masked right bone and air.
const DAY2_TESTS := [
	["right", true, {"test": "ac", "hoot_turn_after": 1}],
	["left", false, {"test": "ac", "hoot_turn_after": 0}],
	["left", true, {"test": "bc", "masking_controls": true, "hoot_turn_after": 1}],
	["right", false, {"test": "bc", "bc_freqs": [1000], "masking_controls": false, "hoot_turn_after": 99, "demo_tone": {"freq": 1000, "db": 10, "title": "BOO!"}}],
	["right", true, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 2}],
	["right", false, {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 0}],
]
## (Speech) The days this monkey plays: chapter id -> day number (and every case day: _supported()).
const SUPPORTED: Dictionary[String, int] = {"gus": 1, "bonnie": 2, "mike": 3}
const SPEECH_SCENE := "res://ui/speech/speech_screen.tscn"
const LevelMike := preload("res://story/level_mike.gd")
const MikeBoard := preload("res://story/games/mike_board.gd")
const Hud := preload("res://story/hud.gd")
## (Speech) Day 3's SPEECH screen controls (and two keys it ignores).
const ACTIONS_SPEECH: Array[StringName] = [&"present_tone", &"speech_correct", &"speech_incorrect", &"louder", &"softer", &"store",
	&"toggle_mask", &"toggle_key_hints", &"advance_dialogue", &"ui_accept"]
## (Speech) The Day 3 board's keys (1-3 pick a clue too).
const ACTIONS_BOARD: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down", &"ui_accept", &"advance_dialogue"]
const MAX_GAME_S_DAY3 := 1800.0
## (Speech) A TALK lamp lit this long (unpaused game seconds) is stuck.
const TALK_STUCK_S := 6.0

var _screen: Node
var _errors := ErrorCounter.new()
var _rng := RandomNumberGenerator.new()
var _held_key := false
var _held_mouse := false
var _release_at := -1.0
var _next_t := 0.0
var _t := 0.0
var _base_scale := 1.0
var _problems: PackedStringArray = []
var _stats := {"inputs": 0, "clicks": 0, "pauses": 0, "short_beeps": 0, "long_beeps": 0, "hoot_turn_frames": 0, "stores": 0}
var _day2 := false
## Day 2 or a case day: the masking controls and their invariants.
var _masking := false
var _actions: Array[StringName] = ACTIONS.duplicate()
var _masker_on := false
var _tone_unheld_s := 0.0
var _tone_flagged := false
var _done := false
## (Speech) Day 3.
var _day3 := false
var _board: Control                  ## the MikeBoard during the board part
var _board_step := ""
var _beat := &""                     ## the board's open beat and its info (follow mode)
var _beat_info: Dictionary = {}
var _dragging := false
var _talk_s := 0.0
var _flagged: Dictionary = {}
var _srt: Dictionary = {}            ## test label -> {stored_db, candidate_db, agreement, words}
var _board_report: Dictionary = {}
## (v4) Hoot's movie mashing: -1 = off; 0 = level, no Esc; 1 = level, anything; 2 = pause-menu replay.
const MOVIE_PLAYER := "res://story/explainers/explainer_player.tscn"
const MOVIE_ID := "masking"
const MOVIE_MAX_S := 300.0
var _movie_style := -1
var _in_movies := false
var _movie_player: CanvasLayer
var _movie_t0 := 0.0
var _movie_scene := -1
var _movie_esc_t := -1.0
var _movie_paused_t := -1.0
var _movie_frozen_at := -1.0
var _movie_runs: Array = []


func demo_start() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps mashing inside the pause menu too
	OS.add_logger(_errors)
	var chapter := _chapter_id()
	if not _supported(chapter):
		_refuse()
		return
	_rng.seed = int(Game.cli.get("seed", 1))
	_base_scale = Engine.time_scale
	_day3 = chapter == "mike"
	if _day3:
		_actions = ACTIONS_SPEECH.duplicate()
		await _run_day3()
		await get_tree().process_frame
		if not is_equal_approx(Engine.time_scale, _base_scale):
			_problem("time_scale stuck at %.2f after the visit" % Engine.time_scale)
		_finish(0 if _problems.is_empty() and _errors.count == 0 else 1)
		return
	_screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate()
	add_child(_screen)
	Events.threshold_stored.connect(func(_e: String, _f: int, _d: int, _i: Dictionary) -> void: _stats["stores"] = int(_stats["stores"]) + 1)
	Events.masker_changed.connect(func(_e: String, _f: int, _d: int, on: bool) -> void: _masker_on = on)
	_day2 = chapter == "bonnie"
	var case_id := _case_id(chapter)
	_masking = _day2 or case_id != ""
	if _masking:
		_actions.append_array(ACTIONS_V3)
	if _day2:
		await _run_day2()
	elif case_id != "":
		await _run_case(case_id)
	else:
		_screen.call("demo_start")
		await _screen.test_finished
		_release_all()
		_screen.call("start_test", Game.load_patient("gus"), "left", false)
		await _screen.test_finished
		_release_all()
	await get_tree().process_frame
	if _masker_on:
		_problem("masker still playing after the visit")
	if not is_equal_approx(Engine.time_scale, _base_scale):
		_problem("time_scale stuck at %.2f after the visit" % Engine.time_scale)
	_finish(0 if _problems.is_empty() and _errors.count == 0 else 1)


## (v3) Day 2: Bonnie's tests in order on one session (CONTRACTS.md §4.2 plans).
func _run_day2() -> void:
	Game.begin_visit("bonnie")
	Events.explainer_scene.connect(_on_movie_scene)
	_in_movies = true   # no AudiOtron mashing in between the movie runs
	for style in 3:
		await _run_movie(style)
		if _done:
			return
	_in_movies = false
	var bonnie := Game.load_patient("bonnie")
	for t: Array in DAY2_TESTS:
		_screen.call("start_test", bonnie, String(t[0]), bool(t[1]), (t[2] as Dictionary).duplicate())
		await _screen.test_finished
		_release_all()
		_stats["tests"] = int(_stats.get("tests", 0)) + 1
		if _masker_on:
			_problem("masker still playing after the %s test" % String((t[2] as Dictionary)["test"]))


# ---------------------------------------------------------------- (Speech) Day 3

## (Speech) Day 3: Mike's SRTs on the SPEECH screen with the level's plans (CONTRACTS.md §9.7):
## the coached right ear, Hoot's recheck of it on a fresh session, the left ear with Hoot's x8
## turn. Then the board, on this run's sheets.
func _run_day3() -> void:
	Game.begin_visit("mike")
	var mike := Game.load_patient("mike") as PatientProfile
	_screen = (load(SPEECH_SCENE) as PackedScene).instantiate()
	add_child(_screen)
	Events.speech_stored.connect(func(_e: String, _t: StringName, _s: Dictionary) -> void: _stats["stores"] = int(_stats["stores"]) + 1)
	var words: Array[String] = []
	for it: Dictionary in _familiar_items():
		words.append(String(it.get("id", "")))
	var tones := SpeechSession.tone_results_from(mike)
	var base := {"test": "srt", "tones": tones, "list": LevelMike.LIST_ID, "words": words, "exclude": [LevelMike.UNKNOWN_WORD]}
	# [label, ear, coached, plan extras]
	var tests: Array = [
		["right", "right", true, {}],
		["recheck", "right", false, {"fresh_session": true, "hoot_turn_after": 0}],
		["left", "left", false, {"hoot_turn_after": LevelMike.LEFT_SOLO_WORDS, "hoot_turn_after_up": true}],
	]
	var res: Dictionary = {}
	var recheck: Dictionary = {}
	for t: Array in tests:
		var label := String(t[0])
		var plan := base.duplicate(true)
		plan.merge(t[3] as Dictionary, true)
		_screen.set("quick_visit", true)
		_screen.call("start_test", mike, String(t[1]), bool(t[2]), plan)
		var r: Dictionary = await _screen.test_finished
		_stats["tests"] = int(_stats.get("tests", 0)) + 1
		var sheet: Dictionary = ((r.get("speech", {}) as Dictionary).get("srt", {}) as Dictionary).get(String(t[1]), {})
		if label == "recheck":
			recheck = sheet
			if not SpeechScreen.is_bracketed(sheet):
				_problem("Hoot's recheck stored %d dB off its bracket (%d)" % [int(sheet.get("stored_db", -99)), int(sheet.get("candidate_db", -99))])
		else:
			res = r
		var stored := int(sheet.get("stored_db", -999))
		if sheet.is_empty() or stored < SpeechRules.MIN_DB or stored > SpeechRules.MAX_DB:
			_problem("no SRT stored on the %s test" % label)
		_srt[label] = {"stored_db": stored, "candidate_db": int(sheet.get("candidate_db", SpeechRules.NO_SRT)),
			"agreement": String(sheet.get("agreement", "")), "words": int(sheet.get("words", 0))}
		var voice: SpeechVoice = _screen.get("_voice")
		if voice != null and voice.noise_on:
			_problem("speech noise still playing after the %s test" % label)
		if not is_equal_approx(Engine.time_scale, _base_scale):
			_problem("time_scale %.2f after the %s test" % [Engine.time_scale, label])
	var screen := _screen
	_screen = null
	screen.queue_free()
	await get_tree().process_frame
	await _run_board(res, recheck, tones)


## (Speech) The first FAMILIAR_WORDS items of Day 3's list (the board's cards, the level's words).
func _familiar_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for it: Dictionary in SpeechMaterial.items(LevelMike.LIST_ID):
		if items.size() < LevelMike.FAMILIAR_WORDS:
			items.append(it)
	return items


## (Speech) The Day 3 board under random input, steps in the level's order: the cards flip, Hoot's
## say-along (cut short at a random moment, as a click on would), the drop, OBJECTION! on this
## run's sheets (Hoot's recheck when he ran one), the referral stamp.
func _run_board(res: Dictionary, recheck: Dictionary, tones: Dictionary) -> void:
	var hud: CanvasLayer = Hud.new()
	add_child(hud)
	hud.call("set_steps", LevelMike.STEPS, LevelMike.STEP_LABELS, "MIKE LENDERS' VISIT", {})
	hud.call("set_step", &"words")
	var b := MikeBoard.new()
	hud.call("add_game", b)
	_board = b
	Events.awaiting_input.connect(_on_board_beat)
	Events.input_resolved.connect(_on_board_resolved)
	var items := _familiar_items()
	var ids: Array[String] = []
	for it: Dictionary in items:
		ids.append(String(it.get("id", "")))
	_board_step = "cards"
	await b.run_cards(items, SpeechMaterial.title(LevelMike.LIST_ID))
	var unknown := ids.find(LevelMike.UNKNOWN_WORD)
	var last_known := (unknown - 1) if unknown > 0 else ids.size() - 1
	_board_step = "say_along"
	b.say_along(0, last_known, LevelMike.SAY_ALONG_S)
	await get_tree().create_timer(_rng.randf_range(0.3, LevelMike.SAY_ALONG_S + 0.5)).timeout
	b.finish_say_along()
	for i in last_known + 1:
		if not b.is_echoed(ids[i]):
			_problem("card %s not ticked after the say-along" % ids[i])
	b.say_word(LevelMike.UNKNOWN_WORD, "Wind... mill?")
	b.stumble(LevelMike.UNKNOWN_WORD)
	_board_step = "drop"
	await b.run_drop(LevelMike.UNKNOWN_WORD)
	if b.dropped != [LevelMike.UNKNOWN_WORD]:
		_problem("the board dropped %s, not just %s" % [str(b.dropped), LevelMike.UNKNOWN_WORD])
	var lv: Node = LevelMike.new()
	lv.set("tones", tones)
	lv.set("results", res)
	lv.set("recheck", recheck)
	var cards: Array = lv.call("objection_cards")
	lv.free()
	b.show_objection(cards[0], cards[1])
	_board_step = "objection"
	await b.run_objection()
	if not b.solved or b.picks.is_empty() or b.picks.back() != "srt_pta":
		_problem("OBJECTION! ended without the measurement clue (picks %s)" % str(b.picks))
	b.set_referral_mode(true)
	_board_step = "stamp"
	await b.run_stamp()
	if not b.stamped:
		_problem("the referral stamp never landed")
	_board_report = {"drop_slips": b.drop_slips, "picks": b.picks.size(), "stamped": b.stamped}
	_board_step = ""
	Events.awaiting_input.disconnect(_on_board_beat)
	Events.input_resolved.disconnect(_on_board_resolved)
	_board = null
	hud.queue_free()
	await get_tree().process_frame


func _on_board_beat(beat: StringName, info: Dictionary, _solver: Callable) -> void:
	_beat = beat
	_beat_info = info


func _on_board_resolved(beat: StringName) -> void:
	if beat == _beat:
		_beat = &""
		_beat_info = {}


func _process_day3(delta: float) -> void:
	var speech := _screen != null and is_instance_valid(_screen)
	if _done or (not speech and _board == null):
		return
	_t += get_process_delta_time() if not get_tree().paused else delta
	if Game.clock > MAX_GAME_S_DAY3:
		_problem("timeout" + ((" in the board's %s step" % _board_step) if _board != null else ""))
		_finish(3)
		return
	if speech:
		_watch_speech(delta)
	elif not get_tree().paused and not is_equal_approx(Engine.time_scale, _base_scale):
		_problem_once("board_scale", "time_scale %.2f on the board" % Engine.time_scale)
	if _t < _next_t or _dragging:
		return
	_next_t = _t + _rng.randf_range(0.05, 0.6)
	_stats["inputs"] = int(_stats["inputs"]) + 1
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm != null and bool(pm.call("is_open")):
		var keys: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ESCAPE]
		_key(keys[_rng.randi() % keys.size()])
		return
	if speech:
		_act_speech()
	else:
		_act_board()


## (Speech) The SPEECH screen's invariants, every frame.
func _watch_speech(delta: float) -> void:
	var st: Dictionary = _screen.call("get_state")
	var hoot := bool(st.get("hoot_turn", false))
	if hoot:
		_stats["hoot_turn_frames"] = int(_stats["hoot_turn_frames"]) + 1
	elif not get_tree().paused and not is_equal_approx(Engine.time_scale, _base_scale):
		_problem_once("speech_scale", "time_scale %.2f outside Hoot's turn" % Engine.time_scale)
	var d := int(st.get("db", 0))
	if d < SpeechRules.MIN_DB or d > SpeechRules.MAX_DB:
		_problem_once("dial", "speech dial at %d dB HL" % d)
	var voice: SpeechVoice = _screen.get("_voice")
	if voice != null and voice.noise_on:
		_stats["noise_frames"] = int(_stats.get("noise_frames", 0)) + 1
		if hoot:
			_problem_once("noise_hoot", "speech noise in Hoot's silent turn")
		elif not bool(st.get("mask_on", false)):
			_problem_once("noise_off", "speech noise playing with MASK off")
		elif voice.noise_ear != String(st.get("mask_ear", "")) or voice.noise_ear == String(st.get("ear", "")):
			_problem_once("noise_ear", "speech noise in the %s ear while testing the %s" % [voice.noise_ear, String(st.get("ear", ""))])
		elif roundi(voice.noise_db) != int(st.get("mask_db", -1)):
			_problem_once("noise_db", "speech noise at %d dB EM, MASK says %d" % [roundi(voice.noise_db), int(st.get("mask_db", -1))])
	if bool(st.get("talking", false)) and not get_tree().paused:
		_talk_s += delta
		if _talk_s > TALK_STUCK_S:
			_problem_once("talk", "TALK lamp lit for %.1f s" % _talk_s)
	else:
		_talk_s = 0.0


func _act_speech() -> void:
	var roll := _rng.randf()
	if roll < 0.55:
		_follow_speech()
	elif roll < 0.8:
		_tap(_actions[_rng.randi() % _actions.size()])
	elif roll < 0.92:
		_click(Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720)), _rng.randf() < 0.2)
	elif roll < 0.95:
		_stats["pauses"] = int(_stats["pauses"]) + 1
		_tap(&"pause")
	# else: idle


## (Speech) Roughly the textbook move (the screen's own beat), by key or by its button, with a
## wrong score now and then and a STORE pressed twice (the "press again to store anyway" path).
func _follow_speech() -> void:
	var session: SpeechSession = _screen.get("session")
	if session == null:
		return
	var act: StringName = session.recommended_action()["action"]
	if act == &"none":
		act = &"store"
	if not SpeechScreen.ACTION_INPUTS.has(act):
		return
	var input: StringName = SpeechScreen.ACTION_INPUTS[act]
	var r := _rng.randf()
	if (act == &"score_correct" or act == &"score_missed") and r < 0.1:
		input = &"speech_incorrect" if act == &"score_correct" else &"speech_correct"
		_stats["misscores"] = int(_stats.get("misscores", 0)) + 1
	elif act == &"store" and r < 0.3:
		_tap(input)
		_stats["double_stores"] = int(_stats.get("double_stores", 0)) + 1
	var buttons: Dictionary = _screen.get("_buttons")
	var b: Control = buttons.get(SpeechScreen.ACTION_BUTTONS.get(act, ""), null)
	if b != null and input == SpeechScreen.ACTION_INPUTS[act] and _rng.randf() < 0.25:
		_click(b.get_global_rect().get_center(), false)
	else:
		_tap(input)


func _act_board() -> void:
	var roll := _rng.randf()
	if roll < 0.3:
		_follow_board()
	elif roll < 0.6:
		if _rng.randf() < 0.3:
			_key((KEY_1 + _rng.randi() % 3) as Key)
		else:
			_tap(ACTIONS_BOARD[_rng.randi() % ACTIONS_BOARD.size()])
	elif roll < 0.8:
		var ids := _board_anchors()
		var at := Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720))
		if not ids.is_empty() and _rng.randf() < 0.7:
			at = Hoot.anchor_screen_rect(ids[_rng.randi() % ids.size()]).get_center()
		_click(at, _rng.randf() < 0.2)
	elif roll < 0.9:
		var ids := _board_anchors()
		if ids.size() >= 2:
			var to := Hoot.anchor_screen_rect(ids[_rng.randi() % ids.size()]).get_center()
			if _rng.randf() < 0.3:
				to = Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720))
			_drag(Hoot.anchor_screen_rect(ids[_rng.randi() % ids.size()]).get_center(), to)
	elif roll < 0.93:
		_stats["pauses"] = int(_stats["pauses"]) + 1
		_tap(&"pause")
	# else: idle


## (Speech) The open beat's own move: its mouse route (a click or a drag) or its target, or Enter.
func _follow_board() -> void:
	var mouse: Dictionary = _beat_info.get("mouse", {})
	var targets: Array = _beat_info.get("targets", [])
	if mouse.has("drag"):
		var d: Array = mouse["drag"]
		_drag(Hoot.anchor_screen_rect(String(d[0])).get_center(), Hoot.anchor_screen_rect(String(d[1])).get_center())
	elif mouse.has("click") and _rng.randf() < 0.7:
		_click(Hoot.anchor_screen_rect(String(mouse["click"])).get_center(), false)
	elif not targets.is_empty() and _rng.randf() < 0.5:
		_click(Hoot.anchor_screen_rect(String(targets[0])).get_center(), false)
	else:
		_tap(&"ui_accept")


## (Speech) The board's anchors on screen now (cards, cue, claim, clues, stamp).
func _board_anchors() -> Array[String]:
	var out: Array[String] = []
	var ids: Array[String] = ["familiarize_cue", "objection_claim", "referral_stamp"]
	for it: Dictionary in _familiar_items():
		ids.append("word_card_" + String(it.get("id", "")))
	for c: String in ["coffee", "srt_pta", "canals"]:
		ids.append("clue_" + c)
	for id: String in ids:
		if Hoot.anchor_screen_rect(id) != Rect2():
			out.append(id)
	return out


## (Speech) Press at `from`, move over a few frames with the button held, release at `to`.
func _drag(from: Vector2, to: Vector2) -> void:
	_dragging = true
	_stats["drags"] = int(_stats.get("drags", 0)) + 1
	_mouse(from, true, MOUSE_BUTTON_LEFT)
	for i in range(1, 7):
		await get_tree().process_frame
		var w := get_viewport().get_final_transform() * from.lerp(to, i / 6.0)
		var mv := InputEventMouseMotion.new()
		mv.position = w
		mv.global_position = w
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(mv)
	await get_tree().process_frame
	_mouse(to, false, MOUSE_BUTTON_LEFT)
	_dragging = false


## (Speech) The chapter asked for: --day / --chapter, else Day 1 (Gus); "" when no such day.
func _chapter_id() -> String:
	if not Game.cli.has("day") and not Game.cli.has("chapter"):
		return "gus"
	return Game.cli_chapter_id()


## A day this monkey plays: Days 1-3 (SUPPORTED) or a case day (a chapter with a "case").
func _supported(chapter_id: String) -> bool:
	return SUPPORTED.has(chapter_id) or _case_id(chapter_id) != ""


## (cases) The chapter's case file id, "" when it is not a case day.
func _case_id(chapter_id: String) -> String:
	return String(Game.chapter(chapter_id).get("case", "")) if chapter_id != "" else ""


## (Speech) A day the monkey doesn't play: say so and quit with 2 (never Day 1 in its place).
func _refuse() -> void:
	var asked := ("--day=" + Game.cli_value("day")) if Game.cli.has("day") else ("--chapter=" + Game.cli_value("chapter"))
	var msg := "%s is not supported: the monkey plays --day=1 (Gus), --day=2 (Bonnie), --day=3 (Mike) or a case day (--day=6 and up). Nothing ran." % asked
	printerr("MONKEY: " + msg)
	print("MONKEY_RESULT ", JSON.stringify({"ok": false, "unsupported": asked, "problems": [msg]}))
	_done = true
	Events.quit_requested.emit(2)


## (cases) A case day's tests, in the runner's order (story/level_case.gd _audiometry).
func _run_case(case_id: String) -> void:
	var c := CaseData.load_case(case_id)
	var pid := String(c["patient_id"])
	Game.begin_visit(pid)
	var patient := Game.load_patient(pid) as PatientProfile
	var tr := CaseData.air_transducer(CaseData.canal_blocked(c))
	var res := {}
	for p: Variant in c["audiometry"]:
		var pd: Dictionary = p
		var plan := {"test": String(pd["test"]), "hoot_turn_after": int(pd.get("hoot_turn_after", 0)), "air_transducer": tr}
		for k: String in CaseData.PLAN_KEYS:
			if pd.has(k):
				plan[k] = bool(pd[k])
		if plan["test"] == "bc":
			plan["bc_freqs"] = ClinicRules.BC_REQUIRED
			plan["masking_controls"] = true
		res = await _case_test(patient, String(pd["ear"]), plan)
	for ear: String in CaseData.masked_bone_ears(c["audiometry"]):
		if not ClinicRules.masked_freqs_needed(res, ear, &"bc_masked").is_empty():
			# (C9) the runner's loan: Hoot's inserts from the first masked bone test that would open in
			# a dilemma through headphones (level_case.gd _dilemma_beat)
			if bool(c.get("lend_inserts", false)) and tr == &"phones" and not CaseData.dilemma_freqs(res, ear, tr).is_empty():
				tr = CaseData.air_transducer(CaseData.canal_blocked(c), true)
			res = await _case_test(patient, ear, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 2, "air_transducer": tr})
	for ear: String in CaseData.plan_ears(c["audiometry"], "ac"):
		if not ClinicRules.masked_freqs_needed(res, ear, &"ac_masked", tr).is_empty():
			res = await _case_test(patient, ear, {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 0, "air_transducer": tr})
	if c.get("retest", null) is Dictionary:
		var rt: Dictionary = c["retest"]
		var after := Game.load_patient(String(rt["patient_id"])) as PatientProfile
		var tr2 := CaseData.air_transducer(false)   # the retest: the canal is clear again
		for p: Variant in rt["audiometry"]:
			var pd: Dictionary = p
			await _case_test(after, String(pd["ear"]), {"test": "ac", "hoot_turn_after": int(pd.get("hoot_turn_after", 0)), "air_transducer": tr2})


func _case_test(patient: PatientProfile, ear: String, plan: Dictionary) -> Dictionary:
	_screen.call("start_test", patient, ear, false, plan)
	var r: Dictionary = await _screen.test_finished
	_release_all()
	_stats["tests"] = int(_stats.get("tests", 0)) + 1
	if _masker_on:
		_problem("masker still playing after the %s %s test" % [ear, String(plan["test"])])
	return r


func _process(delta: float) -> void:
	if _day3:
		_process_day3(delta)
		return
	if _done or _screen == null or not is_instance_valid(_screen):
		return
	_t += get_process_delta_time() if not get_tree().paused else delta
	if Game.clock > (MAX_GAME_S_DAY2 if _masking else MAX_GAME_S):
		_problem("timeout")
		_finish(3)
		return
	if _in_movies:
		if _movie_style >= 0:
			_movie_tick()
		return
	var st: Dictionary = _screen.call("get_state")
	var hoot := bool(st.get("hoot_turn", false))
	# invariants
	if hoot:
		_stats["hoot_turn_frames"] = int(_stats["hoot_turn_frames"]) + 1
	elif not get_tree().paused and not is_equal_approx(Engine.time_scale, _base_scale):
		_problem("time_scale %.2f outside Hoot's turn" % Engine.time_scale)
	if bool(st.get("tone_on", false)) and not hoot and not _held_key and not _held_mouse and not get_tree().paused:
		_tone_unheld_s += delta
		if _tone_unheld_s > 0.6 and not _tone_flagged:
			_tone_flagged = true
			_problem("tone on with nothing held (%.1f s)" % _tone_unheld_s)
	else:
		_tone_unheld_s = 0.0
	if _masking:
		var m := int(st.get("mask_db", 0))
		if m < ClinicRules.MASK_MIN_DB or m > ClinicRules.MASK_MAX_DB:
			_problem("noise dial at %d dB EM" % m)
		if _masker_on and not bool(st.get("mask_on", false)):
			_problem("masker playing with MASK off")
	# releases
	if _release_at >= 0.0 and _t >= _release_at:
		_release_all()
	if _t < _next_t or _release_at >= 0.0:
		return
	_next_t = _t + _rng.randf_range(0.05, 0.6)
	_act(st)


func _act(st: Dictionary) -> void:
	_stats["inputs"] = int(_stats["inputs"]) + 1
	var roll := _rng.randf()
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm != null and bool(pm.call("is_open")):
		# mash menu keys, then close it
		var keys: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_ESCAPE]
		_key(keys[_rng.randi() % keys.size()])
		return
	if roll < 0.55:
		_follow(st)
	elif roll < 0.8:
		var a: StringName = _actions[_rng.randi() % _actions.size()]
		if a == &"present_tone":
			_beep(_rng.randf_range(0.05, 3.5))
		else:
			_tap(a)
	elif roll < 0.92:
		_click(Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720)), _rng.randf() < 0.2)
	elif roll < 0.95:
		_stats["pauses"] = int(_stats["pauses"]) + 1
		_tap(&"pause")
	# else: idle


## (v4) One run of Hoot's masking movie under the monkey's fingers (see the header).
func _run_movie(style: int) -> void:
	_movie_scene = -1
	_movie_esc_t = -1.0
	_movie_paused_t = -1.0
	_movie_frozen_at = -1.0
	_movie_t0 = _t
	_next_t = _t + 0.1
	var holder: Node = null
	var r: Dictionary = {}
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if style < 2:
		# as a level plays it: a pausable parent, so P (the pause menu) freezes the movie
		holder = Node.new()
		holder.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(holder)
		_movie_player = (load(MOVIE_PLAYER) as PackedScene).instantiate()
		holder.add_child(_movie_player)
		_movie_style = style
		r = await _movie_player.call("play", MOVIE_ID, "test")
	else:
		if pm == null:
			_problem("no pause menu for the movie replay")
			return
		pm.call("open")
		await get_tree().create_timer(0.4, true, false, true).timeout
		var btn: Button = pm.call("movie_button")
		if btn == null or not btn.is_visible_in_tree():
			_problem("pause menu: no visible 'Watch' button on Day 2")
			pm.call("close")
			return
		_movie_style = style
		var done := [false, true]   # [finished, skipped] (a lambda cannot assign the outer r)
		var cb := func(_id: String, sk: bool) -> void:
			done[0] = true
			done[1] = sk
		Events.explainer_finished.connect(cb)
		_click(btn.get_global_rect().get_center(), false)
		await get_tree().process_frame
		_movie_player = get_tree().get_first_node_in_group("explainer_player")
		if _movie_player == null:
			_problem("the Watch button did not start the replay")
		while not done[0] and not _done and _t - _movie_t0 < MOVIE_MAX_S:
			await get_tree().process_frame
		Events.explainer_finished.disconnect(cb)
		r = {"skipped": bool(done[1]), "scenes_seen": _movie_scene + 1}
		await get_tree().create_timer(0.2, true, false, true).timeout
		if not bool(pm.call("is_open")):
			_problem("the pause menu did not come back after the replay")
	_movie_style = -1
	_release_all()
	if pm != null and bool(pm.call("is_open")):
		pm.call("close")
	await get_tree().process_frame
	_movie_runs.append({"style": style, "skipped": bool(r.get("skipped", true)), "scenes": int(r.get("scenes_seen", 0)), "s": snappedf(_t - _movie_t0, 0.1)})
	if style == 0 and (bool(r.get("skipped", true)) or int(r.get("scenes_seen", 0)) != (Movies.movie(MOVIE_ID)["scenes"] as Array).size()):
		_problem("movie without Esc did not play to the end: %s" % JSON.stringify(r))
	if get_tree().get_first_node_in_group("explainer_player") != null:
		_problem("an explainer player is still playing after the movie (style %d)" % style)
	if get_tree().paused:
		_problem("the game is still paused after the movie (style %d)" % style)
	if holder != null:
		holder.queue_free()
	_movie_player = null


func _on_movie_scene(_id: String, index: int, _scene: String) -> void:
	if _movie_style < 0:
		return
	if index != _movie_scene + 1:
		_problem("movie jumped from scene %d to %d" % [_movie_scene, index])
	_movie_scene = index


## (v4) The movie's invariants and the next mash.
func _movie_tick() -> void:
	if _t - _movie_t0 > MOVIE_MAX_S:
		_problem("movie still playing after %.0f s (style %d)" % [MOVIE_MAX_S, _movie_style])
		_finish(3)
		return
	var p := _movie_player
	var playing := p != null and is_instance_valid(p) and bool(p.call("is_playing"))
	var pm := get_tree().get_first_node_in_group("pause_menu")
	var menu_up := pm != null and bool(pm.call("is_open")) and _movie_style != 2
	if _movie_esc_t >= 0.0 and playing and _t - _movie_esc_t > 1.0:
		_problem("Esc did not skip the movie (style %d)" % _movie_style)
		_movie_esc_t = -1.0
	if menu_up and playing:
		# P froze the level's movie: its clock must not move while the menu is open
		var st := float(p.get("_scene_t"))
		_stats["movie_menu_frames"] = int(_stats.get("movie_menu_frames", 0)) + 1
		if _movie_paused_t < 0.0:
			_movie_paused_t = _t
			_movie_frozen_at = st
		elif _t - _movie_paused_t > 0.3 and absf(st - _movie_frozen_at) > 0.001 and int(p.get("scene_index")) == _movie_scene:
			_problem("the movie kept playing under the pause menu")
			_movie_frozen_at = st
	else:
		_movie_paused_t = -1.0
	if _t < _next_t or not playing:
		return
	_next_t = _t + _rng.randf_range(0.08, 1.2)
	_stats["movie_inputs"] = int(_stats.get("movie_inputs", 0)) + 1
	if menu_up:
		# the level's pause menu over the movie: wander a little, then P closes it
		if _rng.randf() < 0.6:
			_tap(&"pause")
		else:
			_key(KEY_DOWN if _rng.randf() < 0.5 else KEY_UP)
		return
	var age := float(p.get("_age"))
	var roll := _rng.randf()
	if roll < 0.18:
		_key(KEY_SPACE)
	elif roll < 0.26:
		_key(KEY_ENTER)
	elif roll < 0.32:
		_tap(&"advance_dialogue")
	elif roll < 0.5:
		# a click somewhere on the screen (never on "Skip movie" without Esc allowed)
		var at := Vector2(_rng.randf_range(0, 1280), _rng.randf_range(0, 720))
		var skip_b: Control = p.get("_skip_btn")
		if _movie_style == 0 and skip_b != null and skip_b.get_global_rect().grow(6.0).has_point(at):
			return
		_click(at, _rng.randf() < 0.15)
	elif roll < 0.58:
		_click((p.get("_next_btn") as Control).get_global_rect().get_center(), false)
	elif roll < 0.66:
		_stats["movie_p"] = int(_stats.get("movie_p", 0)) + 1
		_key(KEY_P)
	elif roll < 0.70 and _movie_style != 0:
		_stats["movie_esc"] = int(_stats.get("movie_esc", 0)) + 1
		_key(KEY_ESCAPE)
		if age > 0.4:
			_movie_esc_t = _t   # past the start grace: the movie must end at once
	elif roll < 0.72 and _movie_style != 0:
		_click((p.get("_skip_btn") as Control).get_global_rect().get_center(), false)
	# else: idle, watch a bit


## Roughly what the coach says, with sloppy timing.
func _follow(_st: Dictionary) -> void:
	var session: AudiometrySession = _screen.get("session")
	if session == null:
		return
	var a := session.recommended_action()
	match a["action"]:
		&"present":
			var r := _rng.randf()
			var dur := _rng.randf_range(1.0, 2.0)
			if r < 0.1:
				dur = _rng.randf_range(0.1, 0.4)
				_stats["short_beeps"] = int(_stats["short_beeps"]) + 1
			elif r < 0.15:
				dur = _rng.randf_range(3.2, 4.0)
				_stats["long_beeps"] = int(_stats["long_beeps"]) + 1
			_beep(dur)
		&"softer":
			_tap(&"softer")
		&"louder":
			_tap(&"louder")
		&"store":
			_tap(&"store")
		&"no_response":
			_tap(&"no_response")
		&"mask_toggle":
			_tap(&"toggle_mask")
		&"mask_louder":
			if _rng.randf() < 0.5:
				_tap(&"mask_louder")
			else:
				_shift_key(KEY_UP)
		&"mask_softer":
			_tap(&"mask_softer")
		&"transducer":
			_tap(&"transducer_bone" if a["target"] == &"bone" else &"transducer_air")


func _beep(dur: float) -> void:
	if _rng.randf() < 0.25:
		var b: Control = _screen.get("_buttons")["tone_button"]
		var at := b.get_global_rect().get_center()
		_mouse(at, true, MOUSE_BUTTON_LEFT)
		_held_mouse = true
	else:
		_send(&"present_tone", true)
		_held_key = true
	_release_at = _t + dur


func _release_all() -> void:
	if _held_key:
		_send(&"present_tone", false)
		_held_key = false
	if _held_mouse:
		var b: Control = _screen.get("_buttons")["tone_button"]
		_mouse(b.get_global_rect().get_center(), false, MOUSE_BUTTON_LEFT)
		_held_mouse = false
	_release_at = -1.0


func _tap(a: StringName) -> void:
	_send(a, true)
	_send(a, false)


func _send(a: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = a
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _key(k: Key) -> void:
	for p: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = p
		Input.parse_input_event(ev)


func _shift_key(k: Key) -> void:
	for p: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.shift_pressed = true
		ev.pressed = p
		Input.parse_input_event(ev)


func _click(at: Vector2, right: bool) -> void:
	_stats["clicks"] = int(_stats["clicks"]) + 1
	var btn := MOUSE_BUTTON_RIGHT if right else MOUSE_BUTTON_LEFT
	_mouse(at, true, btn)
	_mouse(at, false, btn)


func _mouse(at: Vector2, pressed: bool, btn: MouseButton) -> void:
	var w := get_viewport().get_final_transform() * at
	var mv := InputEventMouseMotion.new()
	mv.position = w
	mv.global_position = w
	Input.parse_input_event(mv)
	var ev := InputEventMouseButton.new()
	ev.position = w
	ev.global_position = w
	ev.button_index = btn
	ev.pressed = pressed
	ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if btn == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
	Input.parse_input_event(ev)


func _problem(msg: String) -> void:
	if _problems.size() < 20:
		_problems.append(msg)


## (Speech) A problem that would repeat every frame: reported once per key.
func _problem_once(key: String, msg: String) -> void:
	if not _flagged.has(key):
		_flagged[key] = true
		_problem(msg)


func _finish(code: int) -> void:
	if _done:
		return
	_done = true
	_release_all()
	var res := {}
	if _screen != null and is_instance_valid(_screen):
		res = _screen.call("get_results")
	var out := {
		"ok": code == 0, "game_seconds": Game.clock, "script_errors": _errors.count, "errors": _errors.messages,
		"problems": _problems, "stats": _stats, "grade": res.get("grade", "?"), "presentations": res.get("presentations", 0),
		"technique_errors": (res.get("technique_errors", []) as Array).size(),
		"movie_runs": _movie_runs,
	}
	if _day3:
		out["srt"] = _srt
		out["board"] = _board_report
	print("MONKEY_RESULT ", JSON.stringify(out))
	Events.quit_requested.emit(code)
