class_name SpeechScreen
extends CanvasLayer
## SpeechScreen: the AudiOtron 3000 in SPEECH mode (CONTRACTS.md §9.7). Root of
## res://ui/speech/speech_screen.tscn (CanvasLayer, layer 20). The story adds it, calls start_test()
## once per ear and awaits test_finished. It is NOT the AudiOtron: it never registers as
## Stage.audiometer and never emits audiometry_started.
##
## One word: PRESENT says the next word on the clinician's card (TALK lamp, SpeechVoice), then
## after the patient's pause his answer pops up in the speech bubble ("Rainbow!", "...bow?",
## "Huh?"). The player scores what he SAID: CORRECT or MISSED. Got it = down 10, missed = up 5;
## STORE once the SRT ladder shows a bracket (the speech recognition threshold). The agreement
## meter (the "lie detector") then swings to |SRT - PTA| and clunks into place: with Mike it slams
## into the red.
## Keys and mouse both work everywhere: every control is a clickable AoButton with its key chip.

## Emitted after the ear-complete fanfare. results: §9.5, merged with the tone results.
signal test_finished(results: Dictionary)

const ANCHORS: Array[String] = ["speech_present_button", "speech_correct_button", "speech_incorrect_button", "speech_louder_button",
	"speech_softer_button", "speech_store_button", "speech_mask_button", "speech_word_card", "speech_response", "speech_ladder", "agreement_meter"]
## recommended_action() name -> the button (and Hoot anchor) that does it.
const ACTION_BUTTONS: Dictionary[StringName, String] = {
	&"present": "speech_present_button", &"score_correct": "speech_correct_button", &"score_missed": "speech_incorrect_button",
	&"louder": "speech_louder_button", &"softer": "speech_softer_button", &"store": "speech_store_button", &"mask_toggle": "speech_mask_button",
}
## recommended_action() name -> the input action that does it (the beat solver sends these).
const ACTION_INPUTS: Dictionary[StringName, StringName] = {
	&"present": &"present_tone", &"score_correct": &"speech_correct", &"score_missed": &"speech_incorrect",
	&"louder": &"louder", &"softer": &"softer", &"store": &"store", &"mask_toggle": &"toggle_mask",
}
const TOGGLE_HINTS_ACTION := &"toggle_key_hints"
## Hoot's turn runs this many times faster (Engine.time_scale is multiplied, then restored exactly).
const HOOT_SPEED := 8.0
## The TALK lamp stays lit at least this long, even for a very short word.
const MIN_TALK_S := 0.8
## Hoot waits this long after the answer before he scores it (game seconds, so x8 in his turn).
const HOOT_READ_S := 0.7
const ERROR_KINDS: Array[StringName] = [&"srt_start", &"srt_wrong_step", &"misscored", &"srt_store_no_bracket", &"srt_store_wrong_level", &"speech_marathon"]
## Slips that repeat (with a cooldown) instead of firing once.
const REPEAT_TIPS: Array[StringName] = [&"srt_wrong_step", &"misscored", &"srt_store_wrong_level"]
const TIP_COOLDOWN_S := 20.0
## Session observations that would give the answer away before it shows: held until then.
const HOLD_KINDS: Array[StringName] = [&"half_word", &"cross_heard_speech"]
## A STORE before the scores bracket an SRT warns first; a second press this soon stores anyway
## (never on the coached ear: the coach keeps that one by the book).
const STORE_CONFIRM_S := 4.0
## "The tell": Hoot's once-per-visit note when a word is repeated this far (dB) below the ear's PTA.
const TELL_GAP_DB := 30
const TEXTBOOK_CALLOUTS: Array[String] = ["Textbook!", "Clean score!", "By the book!", "Sharp ears!", "Clinic-grade!", "Smooth!"]
## Golf callout colours (par is sunny yellow, never an ear colour).
const GOLF_COLORS: Dictionary[StringName, Color] = {
	&"albatross": Color("#8e5cc4"), &"eagle": Color("#ff9f1c"), &"birdie": Color("#5bc8a3"), &"par": Color("#ffd23f"),
	&"bogey": Color("#fffbf2"), &"double_bogey": Color("#fffbf2"), &"triple_bogey": Color("#fffbf2"),
}
const AGREEMENT_COLORS: Dictionary[StringName, Color] = {&"good": Color("#5bc8a3"), &"fair": Color("#ffb627"), &"poor": Color("#ff6f59")}

var session: SpeechSession
## Plan "fresh_session" (Hoot's recheck) parks the player's session here; it comes back on the
## next start_test without that key, with its sheets (the grade) untouched.
var _kept_session: SpeechSession
var _fresh_active := false
## Quick visit (setting, --quick / --full): plan "hoot_turn_after" hands the ear to Hoot.
var quick_visit := true
var _plan: Dictionary = {}
var _ear := "right"
var _coached := false
var _show_agreement := true
var _accepting := false
var _talking := false
var _listening := false
var _answer_shown := false
var _presenting := false
var _finishing := false
var _answer_t := -100.0
var _clock := 0.0
## Words the player presented on this ear (Hoot's turn starts after plan hoot_turn_after of them).
var _player_words := 0
var _hoot_after := -1
var _last_scored: Variant = null
var _pending: Array = []          ## [kind, data] technique tips held until the answer shows
var _pending_reactions: Array = []  ## [kind, data] patient reactions held until the answer shows
var _agreement_tip := ""
var _tip_last: Dictionary = {}
var _store_warn_t := -100.0
var _store_warns := 0
var _clean_steps := 0
var _talk_glow := 0.0
var _mic := 0.0
var _perch_hidden := false
var _music_ducked := false
# serials: every timer callback and beat solver checks the one it was made for
var _ear_serial := 0
var _word_serial := 0
var _beat_serial := 0
var _solved_serial := -1
var _beat_key := ""
var _beat_queued := false
# coach
var _coach_active := false
var _coach_tip := -1
var _coach_key := ""
# Hoot's turn
var _auto_running := false
var _ff_on := false
var _base_time_scale := 1.0
var _hoot_serial := 0
var _hoot_steps := 0
var _hoot_done_ears: Dictionary = {}
## start_test() with hoot_turn_after 0: his turn starts on the next idle frame; no player beat before.
var _hoot_pending := false

var _voice: SpeechVoice
var _root: Control
var _bg: Control
var _deck: Control
var _booth: AoBoothWindow
var _mic_lamp: Control
var _lcd: SpLcd
var _status: AoStatus
var _bubble: SpBubble
var _card: SpWordCard
var _ladder: SpLadder
var _meter: SpAgreementMeter
var _dance: SpDance
var _hoot_spot: Control
var _ff_banner: Control
var _fx: AoFx
var _buttons: Dictionary[String, AoButton] = {}
var _group_labels: Array = []   ## [text, Rect2] drawn on the deck


func _enter_tree() -> void:
	add_to_group("speech_screen")
	Stage.set_booth_view_active(true)
	if Sfx.has_method("music_duck") and not _music_ducked:
		Sfx.music_duck(true)
		_music_ducked = true
	if not _buttons.is_empty():
		_register_anchors()


func _exit_tree() -> void:
	if _auto_running:
		_end_hoot_turn()
	if _voice != null:
		_voice.stop()
		_voice.stop_noise()
	Hoot.clear_bubble_hint()
	Hoot.clear()
	Stage.set_booth_view_active(false)
	for id: String in ANCHORS:
		Hoot.unregister_anchor(id)
	if _music_ducked:
		Sfx.music_duck(false)
		_music_ducked = false


func _ready() -> void:
	layer = 20
	_ensure_hint_action()
	_voice = SpeechVoice.new()
	_voice.name = "SpeechVoice"
	add_child(_voice)
	quick_visit = bool(Game.settings.get("quick_visit", true))
	if Game.cli_flag("quick"):
		quick_visit = true
	if Game.cli_flag("full"):
		quick_visit = false
	_build_ui()
	Events.key_style_changed.connect(_on_key_style_changed)
	Events.settings_changed.connect(_on_settings_changed)
	Events.comfort_changed.connect(_on_comfort_changed)
	Events.screen_shake.connect(_on_screen_shake)
	Events.pause_toggled.connect(_on_pause_toggled)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_status.set_hearts(Game.get_comfort())
	_register_anchors()
	_refresh()


## Standalone boot (--scene=res://ui/speech/speech_screen.tscn): Mike, his tones from his profile,
## a coached right-ear SRT. Extras: --demo-play (answers its own beats), --demo-ear=left,
## --demo-uncoached, --demo-hoot=N (plan hoot_turn_after).
func demo_start() -> void:
	Game.begin_visit("mike")
	var clinic_path := "res://world/clinic.tscn"
	if DisplayServer.get_name() != "headless" and not Stage.has_clinic() and ResourceLoader.exists(clinic_path) and get_parent() != null:
		var clinic: Node = (load(clinic_path) as PackedScene).instantiate()
		if "patient_id" in clinic:
			clinic.set("patient_id", "mike")
		get_parent().add_child(clinic)
		if clinic.has_method("get_main_camera"):
			var cam: Camera3D = clinic.call("get_main_camera")
			if cam != null:
				cam.current = false
		if clinic.has_method("put_on_earphones"):
			clinic.call("put_on_earphones", true)
		if clinic.has_method("sit"):
			clinic.call("sit")
	var mike := Game.load_patient("mike") as PatientProfile
	var plan := {"test": "srt", "tones": SpeechSession.tone_results_from(mike)}
	if Game.cli_value("demo-hoot", "") != "":
		plan["hoot_turn_after"] = int(Game.cli_value("demo-hoot", "0"))
	if Game.cli_flag("demo-play"):
		Events.awaiting_input.connect(_on_demo_beat)
	start_test(mike, Game.cli_value("demo-ear", "right"), not Game.cli_flag("demo-uncoached"), plan)


func _on_demo_beat(beat: StringName, _info: Dictionary, solver: Callable) -> void:
	if beat == &"speech" and is_inside_tree():
		get_tree().create_timer(0.45, false).timeout.connect(_call_solver.bind(solver))


func _call_solver(solver: Callable) -> void:
	if solver.is_valid():
		solver.call()


## Begin one ear (§9.7). The session is made on the first call and kept between ears.
## Plan keys: test ("srt"), tones (§5.1, for the PTA), list, words, exclude, level, transducer,
## hoot_turn_after (player words before Hoot finishes at x8 on a quick visit; 0 = Hoot runs the
## ear; missing = never), intro, hoot_turn_text, show_agreement (default true), done_title,
## low_start_ok (SpeechSession), fresh_session (this ear on a new session: Hoot's recheck; the
## player's session comes back on the next start_test without it).
func start_test(patient: PatientProfile, ear: String, coached: bool, plan: Dictionary = {}) -> void:
	if patient == null:
		push_error("SpeechScreen.start_test: no patient")
		return
	if _auto_running:
		_end_hoot_turn()
	var fresh := bool(plan.get("fresh_session", false))
	if fresh:
		if not _fresh_active:
			_kept_session = session
			_fresh_active = true
		session = null
	elif _fresh_active:
		session = _kept_session   # null when there was none: a new one below
		_kept_session = null
		_fresh_active = false
	if session == null or session.patient.id != patient.id:
		session = SpeechSession.new(patient, Game.rng.randi())
		session.technique.connect(_on_technique)
		session.combo_changed.connect(_on_combo)
		session.reaction.connect(_on_reaction)
		session.stored.connect(_on_stored)
		if not fresh:
			_hoot_done_ears.clear()
			_tip_last.clear()
	_voice.stop()
	_plan = plan.duplicate(true)
	session.configure(_plan)
	session.begin(ear, coached)
	_ear = ear
	_coached = coached
	_show_agreement = bool(_plan.get("show_agreement", true)) and session.test == &"srt"
	_hoot_after = int(_plan["hoot_turn_after"]) if _plan.has("hoot_turn_after") else -1
	_player_words = 0
	_talking = false
	_listening = false
	_answer_shown = false
	_presenting = false
	_finishing = false
	_last_scored = null
	_pending.clear()
	_pending_reactions.clear()
	_agreement_tip = ""
	_store_warn_t = -100.0
	_ear_serial += 1
	_word_serial += 1
	_beat_key = ""
	_accepting = true
	var who := patient.short_name()
	_bubble.speaker = who
	_fx.speaker = who
	_bubble.clear()
	_booth.texture = Stage.get_booth_texture()
	_booth.tone_ear = ear
	_meter.reset()
	_meter.visible = _show_agreement
	_ladder.clear_stamp()
	_dance.clear()
	_card.ear = ear
	_card.state = &"idle"
	_card.done_text = ""
	Stage.set_booth_view_active(true)
	_layout()
	Events.speech_started.emit(patient.id, ear, session.test, coached)
	_coach_key = ""
	_coach_tip = -1
	var hoot_now := quick_visit and _hoot_after == 0 and not session.is_done()
	_hoot_pending = hoot_now
	_coach_active = coached and not hoot_now and not session.is_done()
	var intro := String(_plan.get("intro", ""))
	if hoot_now:
		if intro != "":
			Hoot.say(intro, Hoot.NORMAL, "", "", 2.0)
		_start_hoot_turn.call_deferred()
	elif coached:
		Hoot.say(intro if intro != "" else _say("Speech time! {He} repeats each word. You score what {he} SAID."), Hoot.NORMAL, "", "", 3.0)
	elif intro != "":
		Hoot.say(intro, Hoot.NORMAL)
	elif quick_visit and _hoot_after > 0:
		Hoot.say("%s ear, all yours for %d word%s! Then I'll take a turn." % [ear.capitalize(), _hoot_after, "" if _hoot_after == 1 else "s"], Hoot.NORMAL)
	else:
		Hoot.say("%s ear, all on your own! I'll only chime in if something goes wrong." % ear.capitalize(), Hoot.NORMAL)
	_refresh()
	if session.is_done():
		_complete_ear.call_deferred()


## Snapshot for UI, bot and tests: SpeechSession.get_state() (§9.4) plus the screen's keys.
func get_state() -> Dictionary:
	var st: Dictionary
	if session != null:
		st = session.get_state()
	else:
		st = {"test": &"srt", "ear": _ear, "db": 40, "min_db": SpeechRules.MIN_DB, "max_db": SpeechRules.MAX_DB, "list_id": "",
			"list_title": "", "next_word": "", "words_left": 0, "pta": NAN, "pta_right": NAN, "pta_left": NAN, "recommended_start": 40,
			"candidate_db": SpeechRules.NO_SRT, "trail": [], "strokes": 0, "awaiting_score": false, "current": {}, "mask_on": false,
			"mask_db": -1, "mask_ear": "left", "masking_needed": false, "transducer": &"phones", "done": false, "stored_db": -1,
			"agreement": &"", "diff": 0, "combo": 0, "multiplier": 1, "points": 0, "presentations": 0, "scoring": true}
	st["accepting_input"] = _player_ok()
	st["talking"] = _talking
	st["listening"] = _listening
	st["answer_shown"] = _answer_shown
	st["hoot_turn"] = _auto_running
	st["coached"] = _coached
	st["patient_id"] = session.patient.id if session != null else ""
	st["quick_visit"] = quick_visit
	st["finishing"] = _finishing
	st["hoot_turn_after"] = _hoot_after
	return st


## §9.5 results merged with the tone results: SpeechSession.merge_results(plan tones, speech).
func get_results() -> Dictionary:
	if session == null:
		return {}
	return SpeechSession.merge_results(session.tone_results, session.build_results())


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_HINTS_ACTION):
		_toggle_hints()
		get_viewport().set_input_as_handled()
		return
	if not _player_ok():
		return
	if event.is_action_pressed(&"present_tone"):
		_do(&"present")
	elif event.is_action_pressed(&"speech_correct"):
		_do(&"score_correct")
	elif event.is_action_pressed(&"speech_incorrect"):
		_do(&"score_missed")
	elif event.is_action_pressed(&"louder", true):
		_do(&"louder")
	elif event.is_action_pressed(&"softer", true):
		_do(&"softer")
	elif event.is_action_pressed(&"store"):
		_do(&"store")
	elif event.is_action_pressed(&"toggle_mask"):
		_do(&"mask_toggle")
	else:
		return
	get_viewport().set_input_as_handled()


## Player input is live: after start_test, before the ear is done, not in Hoot's turn.
func _player_ok() -> bool:
	return _accepting and session != null and not _auto_running and not _finishing and not _hoot_pending


## Waiting for the player (a beat): input live and no word playing or being answered.
func _idle() -> bool:
	return _player_ok() and not _talking and not _listening and not _presenting


## A control from the keyboard or Hoot: flash its button, then do it.
func _do(action: StringName) -> void:
	var b: AoButton = _buttons.get(ACTION_BUTTONS.get(action, ""))
	if b != null:
		b.flash_press()
	_act(action)


func _act(action: StringName) -> void:
	match action:
		&"present":
			_present()
		&"score_correct":
			_score(true)
		&"score_missed":
			_score(false)
		&"louder":
			_level(1)
		&"softer":
			_level(-1)
		&"store":
			_store()
		&"mask_toggle":
			_toggle_mask()


func _busy() -> bool:
	return _talking or _listening or _presenting


func _present() -> void:
	if session == null or _finishing or session.is_done():
		return
	if _busy():
		_btn("speech_present_button").wiggle()
		return
	if session.awaiting_score:
		session.present()   # refused: the session asks for the score first (once)
		for id: String in ["speech_correct_button", "speech_incorrect_button"]:
			_btn(id).wiggle()
		Sfx.play(&"error", 1.0, -12.0)
		return
	var it := session.next_item().duplicate()
	if it.is_empty():
		return
	_presenting = true
	var trial := session.present()
	_presenting = false
	if trial.is_empty():
		_flush_pending()
		return
	if not _auto_running:
		_player_words += 1
	_word_serial += 1
	_talking = true
	_answer_shown = false
	_store_warn_t = -100.0
	var dur := 0.0
	if _auto_running:
		# Hoot's x8 turn is silent (the murmur would be cut to an eighth); the TALK lamp still lights
		var syl := SpeechVoice.syllables_for(it)
		dur = syl * SpeechVoice.SYLLABLE_S + maxi(0, syl - 1) * SpeechVoice.SYLLABLE_GAP_S
	else:
		dur = _voice.play_item(session.ear, session.list_id, it, float(int(trial["db"])))
	dur = maxf(MIN_TALK_S, dur)
	_bubble.clear()
	_card.state = &"talking"
	_card.set_word(String(trial["word"]), it.get("parts", []), int(trial["n"]), int(session.get_state()["words_left"]))
	Events.speech_presented.emit(session.ear, session.test, int(trial["db"]), it)
	_after(dur, _on_word_end.bind(_word_serial))
	_refresh()


func _on_word_end(serial: int) -> void:
	if serial != _word_serial or not is_inside_tree() or session == null:
		return
	_talking = false
	_listening = true
	_bubble.listen()
	_card.state = &"listening"
	_after(float(session.current.get("delay_s", 1.0)), _on_answer.bind(serial))
	_refresh()


func _on_answer(serial: int) -> void:
	if serial != _word_serial or not is_inside_tree() or session == null:
		return
	_listening = false
	_answer_shown = true
	_answer_t = _clock
	var cur := session.current
	var said := String(cur.get("said", ""))
	var kind := StringName(String(cur.get("kind", "")))
	var db := int(cur.get("db", session.db))
	_bubble.show_answer(said)
	Juice.pop(_bubble, 1.06, 0.25)
	_card.state = &"score"
	_mic = 1.0
	Sfx.play(&"pop", 1.15, -8.0 if not _auto_running else -16.0)
	Events.speech_response.emit(session.ear, session.test, db, {"said": said, "kind": kind})
	if _is_spoken(said):
		Events.dialogue_line.emit(session.patient.short_name(), said)
	var rd := {"ear": session.ear, "db": db, "via": "speech"}
	match kind:
		&"correct", &"wrong":
			Stage.react(&"nod", rd)
		&"half":
			Stage.react(&"squint", rd)
			_booth.emote("squint")
		&"silence":
			Stage.react(&"confused", rd)
			_booth.emote("confused")
	_flush_pending()
	_refresh()


## A bubble text the patient actually says out loud ("..." and "(shrugs)" are not).
static func _is_spoken(said: String) -> bool:
	if said.begins_with("("):
		return false
	for i in said.length():
		var c := said.unicode_at(i)
		if (c >= 65 and c <= 90) or (c >= 97 and c <= 122):
			return true
	return false


func _flush_pending() -> void:
	var reacts := _pending_reactions.duplicate()
	_pending_reactions.clear()
	for r: Array in reacts:
		_show_reaction(StringName(r[0]), r[1])
	var tips := _pending.duplicate()
	_pending.clear()
	for t: Array in tips:
		_handle_technique(StringName(t[0]), t[1])


func _score(correct: bool) -> void:
	if session == null or _finishing:
		return
	if not session.awaiting_score or not _answer_shown:
		for id: String in ["speech_correct_button", "speech_incorrect_button"]:
			_btn(id).wiggle()
		if not _busy():
			Sfx.play(&"error", 1.0, -12.0)
		return
	var truth := bool(session.current.get("correct", false))
	var tr := session.score(correct)
	if tr.is_empty():
		return
	var db := int(tr["db"])
	_last_scored = correct
	_bubble.mark(correct)
	_card.state = &"idle"
	Events.speech_scored.emit(session.ear, session.test, db, correct, correct == truth)
	Sfx.play(&"ding" if correct else &"click", 1.1 if correct else 0.8, -8.0 if not _auto_running else -16.0)
	var at := _bubble.badge_global()
	_fx.burst(at, Palette.MINT if correct else Palette.CORAL, 8 if not _auto_running else 4, 180.0)
	if not _auto_running and correct and correct == truth:
		_maybe_tell(db)
	_refresh()
	if not _auto_running and quick_visit and _hoot_after > 0 and _player_words >= _hoot_after and not session.is_done() \
			and not _hoot_done_ears.has(_ear):
		_start_hoot_turn()


## "The tell" (once per visit): a word rightly scored repeated TELL_GAP_DB or more below the ear's
## PTA. Hoot's hand points at the agreement meter (never at the answer being judged); on the
## coached ear the coach's line comes back after it.
func _maybe_tell(db: int) -> void:
	var pta := session.pta_for(session.ear)
	if is_nan(pta) or float(db) > pta - TELL_GAP_DB:
		return
	var msg := _say("{He}'s repeating words %d dB below {his} beeps. Hmm!") % roundi(pta - db)
	var target := "agreement_meter" if _show_agreement else "speech_ladder"
	if _coach_active:
		_interrupt_coach(&"speech_tell", msg, target, false)
	else:
		_tip(&"speech_tell", msg, target)


func _level(direction: int) -> void:
	if session == null or _finishing:
		return
	if _busy():
		_deny(_btn("speech_louder_button" if direction > 0 else "speech_softer_button"))
		return
	if session.step_level(direction):
		Sfx.play(&"blip", 1.0 + 0.04 * clampf((session.db - 40) / 10.0, -4.0, 6.0), -10.0 if not _auto_running else -18.0)
		_sync_noise()
	else:
		_lcd.deny()
	_refresh()


## "Not now": the level, the noise and STORE are locked while a word plays and he answers.
func _deny(b: AoButton) -> void:
	_lcd.deny()
	if b != null:
		b.wiggle()
	Sfx.play(&"error", 1.0, -12.0)
	if not _auto_running:
		Hoot.say_once("speech_level_locked", "Let the word and the answer finish, then change the level.", Hoot.NORMAL, "speech_word_card")


func _store() -> void:
	if session == null or _finishing or session.is_done():
		return
	var b := _btn("speech_store_button")
	if _busy():
		_deny(b)
		return
	if session.awaiting_score:
		b.wiggle()
		for id: String in ["speech_correct_button", "speech_incorrect_button"]:
			_btn(id).wiggle()
		_tip(&"score_first", session.tip_text(&"score_first"), "speech_response")
		return
	if session.trials_for().is_empty():
		b.wiggle()
		Hoot.say("Say a few words first, then store the SRT.", Hoot.NORMAL, "speech_present_button")
		return
	# no bracket yet: warn first (a second press soon after stores anyway, except on the coached ear)
	if session.candidate() == SpeechRules.NO_SRT and not _auto_running and (_coached or _clock - _store_warn_t > STORE_CONFIRM_S):
		_store_warn_t = _clock
		_store_warns += 1
		b.wiggle()
		Sfx.play(&"error", 1.0, -10.0)
		if _coach_active:
			_interrupt_coach(&"srt_store_no_bracket", session.tip_text(&"srt_store_no_bracket"), "speech_ladder", true)
		else:
			Hoot.say(session.tip_text(&"srt_store_no_bracket"), Hoot.HIGH, "speech_ladder")
		var chip := "not bracketed yet: keep going" if _coached else "not bracketed: press again to store anyway"
		_fx.chip(chip, b.get_global_rect().get_center() + Vector2(0, -92), Palette.PAPER, Palette.INK, 15, 2.2)
		_refresh()
		return
	_store_warn_t = -100.0
	session.store()   # -> _on_stored


func _toggle_mask() -> void:
	if session == null or _finishing:
		return
	if _busy():
		_deny(_btn("speech_mask_button"))
		return
	session.toggle_mask()
	Sfx.play(&"click", 1.2 if session.mask_on else 0.9, -6.0 if not _auto_running else -16.0)
	_sync_noise()
	_refresh()


## Speech noise in the other ear at level - 20 while MASK is on (SpeechVoice only, never loud).
func _sync_noise() -> void:
	if session == null:
		return
	var on := session.mask_on and _accepting and not _finishing
	if on and not _auto_running:
		_voice.start_noise(session.masker_ear(), float(session.mask_level()))
	else:
		_voice.stop_noise()
	_booth.noise_ear = session.masker_ear() if on else ""


func _toggle_hints() -> void:
	Game.set_setting("show_key_hints", not bool(Game.settings.get("show_key_hints", true)))
	Sfx.play(&"click", 1.1, -4.0)


func _toggle_key_style() -> void:
	Game.set_key_style("affinity" if Game.get_key_style() == "otosuite" else "otosuite")
	Sfx.play(&"click", 1.2, -4.0)
	var swapped := Game.get_key_style() == "affinity"
	_fx.callout("Up = SOFTER" if swapped else "Up = LOUDER", _btn("style_toggle").get_global_rect().get_center() + Vector2(-150, -112),
		Palette.SUNNY, 34, "arrow keys swapped" if swapped else "default arrows", -3.0, 1.6)


func _open_pause_menu() -> void:
	var menu := get_tree().get_first_node_in_group("pause_menu")
	if menu != null and menu.has_method("open"):
		menu.call("open")


func _ensure_hint_action() -> void:
	if InputMap.has_action(TOGGLE_HINTS_ACTION):
		return
	InputMap.add_action(TOGGLE_HINTS_ACTION)
	var ev := InputEventKey.new()
	ev.keycode = KEY_H
	ev.device = -1
	InputMap.action_add_event(TOGGLE_HINTS_ACTION, ev)


# ---------------------------------------------------------------- session callbacks

func _on_reaction(kind: StringName, data: Dictionary) -> void:
	if _busy():
		_pending_reactions.append([kind, data])   # a ghost before the answer would give it away
	else:
		_show_reaction(kind, data)


func _show_reaction(kind: StringName, data: Dictionary) -> void:
	Stage.react(kind, data)
	if kind == &"cross_heard":
		_booth.emote("ghost")


func _on_technique(kind: StringName, data: Dictionary) -> void:
	Events.technique_event.emit(kind, data)
	if kind in HOLD_KINDS and _busy():
		_pending.append([kind, data])
		return
	_handle_technique(kind, data)


func _handle_technique(kind: StringName, data: Dictionary) -> void:
	var auto := bool(data.get("auto", false)) or _auto_running
	match kind:
		&"speech_textbook", &"srt_good_start", &"srt_store_ok", &"srt_low_start":
			var n := int(data.get("combo", 0))
			Sfx.play_note(523.25 * pow(2.0, minf(n, 24) / 12.0), -14.0 if not auto else -22.0)
			if auto:
				return
			_clean_steps += 1
			Hoot.note_clean_use(&"srt_step")
			var at := _ladder.last_dot_global() + Vector2(34, -30)
			if int(data.get("points", 0)) > 0:
				_fx.callout("+%d" % int(data["points"]), at, Palette.MINT, 22, "", 0.0, 0.7)
			if n >= 3 and (n == 3 or n == 6 or n == 10 or n % 5 == 0):
				var word := TEXTBOOK_CALLOUTS[(n / 3) % TEXTBOOK_CALLOUTS.size()]
				var c := _ladder.get_global_rect().get_center() + Vector2(0, -60)
				_fx.callout(word, c, Palette.MINT, 36, "", randf_range(-6.0, 6.0))
				_fx.stars(c, 8, Palette.SUNNY)
				Sfx.play(&"ding", 1.0 + 0.04 * minf(n, 20), -8.0)
			# a clean move can carry Hoot's praise (srt_low_start: starting low once answers look exaggerated)
			var praise := String(data.get("message", ""))
			if praise != "":
				if _coach_active:
					_interrupt_coach(kind, praise, _target_for(kind, data), false)
				else:
					_tip(kind, praise, _target_for(kind, data))
		&"srt_stored", &"birdie", &"eagle", &"albatross":
			pass   # celebrated in _on_stored
		&"srt_agreement":
			# shown once the needle has clunked (Hoot's ear too: the gag is the point of the day)
			_agreement_tip = String(data.get("message", ""))
			if not _show_agreement and _agreement_tip != "":
				Hoot.say(_agreement_tip, Hoot.HIGH, "speech_ladder")
				_agreement_tip = ""
		&"speech_marathon":
			if auto:
				return
			Game.lose_comfort("marathon")
			_tip(kind, String(data.get("message", "")), "speech_store_button")
		_:
			if auto:
				return
			var msg := String(data.get("message", ""))
			if msg == "" and session != null:
				msg = session.tip_text(kind)
			var error := kind in ERROR_KINDS
			if error and not _coached:
				Sfx.play(&"sad_trombone", 1.0, -12.0)
			if msg == "":
				return
			if _coach_active:
				_interrupt_coach(kind, msg, _target_for(kind, data), error)
			else:
				_tip(kind, msg, _target_for(kind, data))


## While coaching: the tip takes the coach's place for a moment, then the coach's line comes back
## (the sticky coach tip is dismissed so the tip shows now; the new coach tip queues behind it).
func _interrupt_coach(kind: StringName, msg: String, target: String, error: bool) -> void:
	var key := "" if error or kind in REPEAT_TIPS else "tip_" + String(kind)
	if Hoot.say(msg, Hoot.HIGH, target, key, 4.0) < 0:
		return   # a once-per-visit tip already shown
	if _coach_tip >= 0:
		Hoot.dismiss(_coach_tip)
	_coach_tip = -1
	_coach_key = ""
	_coach_update()


## A technique tip: everyday slips repeat with a cooldown, everything else fires once per visit.
func _tip(kind: StringName, msg: String, target: String) -> void:
	if msg == "":
		return
	if kind in REPEAT_TIPS:
		if _clock - float(_tip_last.get(kind, -1000.0)) < TIP_COOLDOWN_S:
			return
		_tip_last[kind] = _clock
		Hoot.say(msg, Hoot.HIGH, target)
	else:
		Hoot.say_once("tip_" + String(kind), msg, Hoot.HIGH if kind in ERROR_KINDS else Hoot.NORMAL, target)


func _target_for(kind: StringName, data: Dictionary) -> String:
	match kind:
		&"srt_start":
			var exp := int(data.get("expected", 0))
			return "speech_louder_button" if int(data.get("db", 0)) < exp else "speech_softer_button"
		&"srt_wrong_step":
			return "speech_softer_button" if bool(data.get("prev_correct", false)) else "speech_louder_button"
		&"misscored":
			return "speech_correct_button" if StringName(String(data.get("said_kind", ""))) == &"correct" else "speech_incorrect_button"
		&"srt_store_no_bracket", &"srt_store_wrong_level", &"srt_low_start":
			return "speech_ladder"
		&"speech_marathon":
			return "speech_store_button"
		&"half_word", &"score_first":
			return "speech_response"
		&"srt_agreement":
			return "agreement_meter"
		&"cross_heard_speech", &"speech_mask_needed":
			return "speech_mask_button"
	return ""


func _on_combo(n: int, mult: int) -> void:
	var before := _status.multiplier
	Events.combo_changed.emit(n, mult)
	_status.set_combo(n, mult)
	if mult > before and n > 0:
		var at := _status.get_global_rect().position + Vector2(140, 156)
		_fx.callout("x%d COMBO!" % mult, at, Palette.SELECT_ORANGE, 30, "", -6.0, 1.1)
		Sfx.play(&"sparkle", 0.9 + 0.1 * mult, -8.0)
	elif n == 0 and before > 1:
		Sfx.play(&"whoosh", 0.7, -10.0)


func _on_stored(ear: String, test: StringName, sheet: Dictionary) -> void:
	_finishing = true
	_accepting = false
	var by_hoot := bool(sheet.get("by_hoot", false))
	var db := int(sheet.get("stored_db", session.db))
	if _coach_active:
		_coach_active = false
		if _coach_tip >= 0:
			Hoot.dismiss(_coach_tip)
		_coach_tip = -1
	_ladder.stamp(db)
	Sfx.play(&"stamp", randf_range(0.95, 1.05), -2.0 if not by_hoot else -8.0)
	_after(0.18, _stamp_jolt.bind(_ear_serial))
	if _show_agreement:
		_meter.lock_in(db, float(sheet.get("pta", NAN)), StringName(String(sheet.get("agreement", ""))))
	_card.state = &"done"
	_card.done_text = "SRT %d dB" % db
	_card.done_sub = _done_sub(sheet)
	Events.speech_stored.emit(ear, test, sheet)
	if not by_hoot:
		_golf_callout(sheet)
	else:
		_fx.chip("Hoot: SRT %d dB" % db, _ladder.row_global(db) + Vector2(0, -36), Palette.HOOT_FACE, Palette.INK, 16, 1.2)
	_refresh()
	_complete_ear()


## Was this sheet's stored level the bracketed SRT? The sheet's "bracketed" (SpeechSession), else
## worked out from candidate_db and stored_db (older sheets).
static func is_bracketed(sheet: Dictionary) -> bool:
	var cand := int(sheet.get("candidate_db", SpeechRules.NO_SRT))
	return bool(sheet.get("bracketed", cand != SpeechRules.NO_SRT and int(sheet.get("stored_db", -999)) == cand))


## The word card's line under "SRT 30 dB": praise only for a bracketed store.
static func _done_sub(sheet: Dictionary) -> String:
	if bool(sheet.get("by_hoot", false)):
		return "stored by Hoot, by the book"
	if not is_bracketed(sheet):
		var cand := int(sheet.get("candidate_db", SpeechRules.NO_SRT))
		return "stored before a bracket" if cand == SpeechRules.NO_SRT else "the bracket said %d dB" % cand
	return "ear done: nice work!" if (sheet.get("errors", []) as Array).is_empty() else "ear done: check Hoot's tips"


func _stamp_jolt(serial: int) -> void:
	if serial != _ear_serial or not is_inside_tree():
		return
	Juice.shake(_ladder, 6.0, 0.18)
	var at := _ladder.row_global(int(get_state()["stored_db"]))
	_fx.burst(at, Palette.ear_color(_ear), 12, 260.0, 5.0)
	_fx.ring(at, Palette.ear_color(_ear), 46.0)


func _golf_callout(sheet: Dictionary) -> void:
	var golf := StringName(String(sheet.get("golf", "par")))
	var text := golf_text(sheet)
	var col: Color = GOLF_COLORS.get(golf, Palette.PAPER) if text[0] != "Oops!" else Palette.PAPER
	var big := golf in [&"birdie", &"eagle", &"albatross"] and text[0] != "Oops!"
	var at := _ladder.row_global(int(sheet.get("stored_db", 0))) + Vector2(0, -70)
	_fx.callout(text[0], at, col, 46 if big else 36, text[1], randf_range(-7.0, 3.0), 1.6)
	if big:
		_fx.confetti(at, 18)
		Sfx.play(&"chirp", 1.0, -6.0)


## [callout, small line] after the player's store: the golf name over "words, par" for a clean,
## bracketed SRT ("Clean!" when a clean run over par still counts as par: never "Par!" over
## "14 words, par 12"); "Oops!" after a slip or an SRT stored off its bracket (no golf praise).
static func golf_text(sheet: Dictionary) -> Array[String]:
	var golf := StringName(String(sheet.get("golf", "par")))
	var strokes := int(sheet.get("strokes", 0))
	var par := int(sheet.get("par", 0))
	if not (sheet.get("errors", []) as Array).is_empty() or not is_bracketed(sheet):
		return ["Oops!", "check Hoot's tip"]
	var word := String(golf).replace("_", " ").capitalize() + "!"
	if golf == &"par" and strokes > par:
		word = "Clean!"
	return [word, "%d words, par %d" % [strokes, par]]


func _on_meter_clunked(agreement: StringName) -> void:
	if not is_inside_tree():
		return
	Juice.shake(_meter, 12.0, 0.4)
	Sfx.play(&"thunk", 0.9, -4.0)
	var r := _meter.get_global_rect()
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.32)
	var diff := absi(int(get_state().get("diff", 0)))
	var col: Color = AGREEMENT_COLORS.get(agreement, Palette.PAPER)
	match agreement:
		&"poor":
			Events.screen_shake.emit(0.35, 0.3)
			Sfx.play(&"boing", 0.8, -8.0)
			_fx.callout("POOR AGREEMENT!", c, col, 32, "%d dB apart" % diff, -5.0, 2.2)
			_fx.burst(c, Palette.CORAL, 16, 280.0)
			_fx.burst(c, Palette.SUNNY, 8, 200.0)
		&"fair":
			_fx.callout("FAIR AGREEMENT", c, col, 30, "%d dB apart" % diff, -4.0, 1.8)
		&"good":
			_fx.callout("GOOD AGREEMENT!", c, col, 30, "%d dB apart" % diff, -4.0, 1.8)
			_fx.stars(c, 10, Palette.SUNNY)
			Sfx.play(&"sparkle", 1.0, -6.0)
	if _agreement_tip != "":
		_after(1.0, _show_agreement_tip.bind(_ear_serial, _agreement_tip))
		_agreement_tip = ""


func _show_agreement_tip(serial: int, msg: String) -> void:
	if serial == _ear_serial and is_inside_tree():
		Hoot.say(msg, Hoot.HIGH, "agreement_meter", "", 4.5)


## The ear is stored: input stops, a short celebration, then speech_finished / test_finished.
func _complete_ear() -> void:
	_finishing = true
	_accepting = false
	if _auto_running:
		_end_hoot_turn()
	_voice.stop()
	_voice.stop_noise()
	_booth.noise_ear = ""
	_talking = false
	_listening = false
	_dance.clear()
	for b: AoButton in _buttons.values():
		b.beckon = false
	_refresh()
	_after(1.2, _celebrate.bind(_ear_serial))
	_after(4.0, _finish_ear.bind(_ear_serial))


func _celebrate(serial: int) -> void:
	if serial != _ear_serial or not is_inside_tree() or session == null:
		return
	var st := get_state()
	var sheet: Dictionary = (session.sheets[session.test] as Dictionary).get(_ear, {})
	var r := _ladder.get_global_rect()
	var c := Vector2(r.get_center().x, r.position.y + r.size.y * 0.42)
	# no fanfare for an SRT stored off its bracket
	if bool(sheet.get("by_hoot", false)) or is_bracketed(sheet):
		Sfx.play(&"fanfare", 1.0, -6.0)
		_fx.confetti(c + Vector2(0, -40), 36, 380.0)
	var sub := ""
	var pta := float(st["pta"])
	if not is_nan(pta) and StringName(String(st.get("agreement", ""))) != &"":
		sub = "PTA %d vs SRT %d: %s agreement" % [roundi(pta), int(st["stored_db"]), String(st["agreement"])]
	var title := String(_plan.get("done_title", "%s EAR SRT: %d dB" % [_ear.to_upper(), int(st["stored_db"])]))
	_fx.callout(title, c, Palette.SUNNY, 40, sub, -3.0, 2.6)


func _finish_ear(serial: int) -> void:
	if serial != _ear_serial or not is_inside_tree():
		return
	var results := get_results()
	Events.speech_finished.emit(results)
	test_finished.emit(results)


# ---------------------------------------------------------------- Hoot's turn (quick visit)

func _start_hoot_turn() -> void:
	_hoot_pending = false
	if _auto_running or _finishing or session == null or session.is_done() or not is_inside_tree():
		return
	_auto_running = true
	_ff_on = false
	session.scoring = false
	_coach_active = false
	if _coach_tip >= 0:
		Hoot.dismiss(_coach_tip)
	_coach_tip = -1
	_hoot_serial += 1
	_hoot_steps = 0
	_base_time_scale = Engine.time_scale
	_voice.stop_noise()
	for b: AoButton in _buttons.values():
		b.beckon = false
	var turn_text := "Nice work! My turn: I'll finish this ear at 8x. Watch the ladder!" if _player_words > 0 \
		else "My turn! I'll run this ear at 8x. Watch the ladder!"
	Hoot.say(String(_plan.get("hoot_turn_text", turn_text)), Hoot.HIGH, "", "", 2.4)
	_ff_banner.visible = true
	_hoot_spot.queue_redraw()
	_refresh()
	_after(1.8, _hoot_go.bind(_hoot_serial))


func _hoot_go(serial: int) -> void:
	if serial != _hoot_serial or not _auto_running or not is_inside_tree():
		return
	_ff_on = true
	if not get_tree().paused:
		Engine.time_scale = _base_time_scale * HOOT_SPEED
	_hoot_step(serial)


## One move of Hoot's turn: the textbook action, through the screen's own controls.
func _hoot_step(serial: int) -> void:
	if serial != _hoot_serial or not _auto_running or not is_inside_tree() or session == null:
		return
	_hoot_steps += 1
	if _hoot_steps > 400:
		_end_hoot_turn()
		return
	if _busy():
		_after(0.2, _hoot_step.bind(serial))
		return
	var a := session.recommended_action()
	var act: StringName = a["action"]
	var wait := 0.3
	match act:
		&"score_correct", &"score_missed":
			var seen := _clock - _answer_t
			if seen < HOOT_READ_S:
				_after(HOOT_READ_S - seen, _hoot_step.bind(serial))
				return
			wait = 0.6
		&"louder", &"softer":
			wait = 0.18
		&"mask_toggle":
			wait = 0.5
		&"store":
			_do(&"store")
			return
		&"present":
			wait = 0.3
		_:
			_end_hoot_turn()
			_refresh()
			return
	_do(act)
	_after(wait, _hoot_step.bind(serial))


func _end_hoot_turn() -> void:
	if not _auto_running:
		return
	_auto_running = false
	_ff_on = false
	_hoot_serial += 1
	Engine.time_scale = _base_time_scale
	if session != null:
		session.scoring = true
	_hoot_done_ears[_ear] = true
	if _ff_banner != null:
		_ff_banner.visible = false
	if _hoot_spot != null:
		_hoot_spot.queue_redraw()


## The pause menu must not run at x8.
func _on_pause_toggled(paused: bool) -> void:
	if not _auto_running or not _ff_on:
		return
	Engine.time_scale = _base_time_scale if paused else _base_time_scale * HOOT_SPEED


# ---------------------------------------------------------------- blocking beat (§3.2)

func _queue_beat() -> void:
	if _beat_queued or not is_inside_tree():
		return
	_beat_queued = true
	_emit_beat.call_deferred()


## Once per idle point: Events.awaiting_input(&"speech", {ear, test, action, target_db, mouse: {click}}, solver).
func _emit_beat() -> void:
	_beat_queued = false
	if not is_inside_tree() or not _idle():
		return
	var a := _beat_action()
	var act: StringName = a["action"]
	if act == &"none":
		return
	var key := "%d|%s|%d|%s|%d|%s|%d" % [_ear_serial, session.ear, session.trials_for().size(), session.awaiting_score, session.db, session.mask_on, _store_warns]
	if key == _beat_key:
		return
	_beat_key = key
	_beat_serial += 1
	var info := {"ear": session.ear, "test": String(session.test), "action": String(act), "target_db": int(a["target_db"]),
		"mouse": {"click": ACTION_BUTTONS[act]}}
	Events.awaiting_input.emit(&"speech", info, _solve.bind(_beat_serial))


## The textbook move, with "none" on an unfinished ear (no words left) turned into STORE.
func _beat_action() -> Dictionary:
	var a := session.recommended_action()
	if a["action"] == &"none" and not session.is_done() and not session.trials_for().is_empty():
		return {"action": &"store", "target_db": session.db}
	return a


## The beat's solver: the recommended action as a real InputEventAction (pressed, then released).
## A stale solver (the state moved on) does nothing.
func _solve(serial: int) -> void:
	if serial != _beat_serial or serial == _solved_serial or not is_inside_tree() or not _idle():
		return
	var act: StringName = _beat_action()["action"]
	if not ACTION_INPUTS.has(act):
		return
	_solved_serial = serial
	var input: StringName = ACTION_INPUTS[act]
	var press := InputEventAction.new()
	press.action = input
	press.pressed = true
	press.strength = 1.0
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = input
	release.pressed = false
	get_tree().create_timer(0.05, true, false, true).timeout.connect(Callable(Input, "parse_input_event").bind(release))


# ---------------------------------------------------------------- coach (the coached ear)

func _coach_update() -> void:
	if not _coach_active or not _accepting or session == null or _auto_running or _finishing:
		return
	var tip := _coach_text(session.recommended_action())
	if String(tip[0]) == "":
		return
	var key: String = tip[2]
	if key == _coach_key:
		return
	_coach_key = key
	if _coach_tip >= 0:
		Hoot.dismiss(_coach_tip)
	_coach_tip = Hoot.say(String(tip[0]), Hoot.HIGH, String(tip[1]), "", 0.0)


## [text, ghost-hand target, key] for the textbook move. Every line stays under 18 words.
func _coach_text(a: Dictionary) -> Array:
	var act: StringName = a["action"]
	var target_db := int(a["target_db"])
	var list := session.trials_for()
	var n := list.size()
	if _busy():
		return [_say("Listen... what does {he} say back?"), "speech_response", "listen%d" % n]
	var steps := absi(target_db - session.db) / SpeechRules.LEVEL_STEP_DB
	var times := "once" if steps == 1 else ("twice" if steps == 2 else "%d times" % steps)
	var pta := session.pta_for(session.ear)
	match act:
		&"louder", &"softer":
			var key := _k(act)
			var bid: String = ACTION_BUTTONS[act]
			if n == 0:
				# the PTA rounded to the dial's 5 dB steps, as on the LCD's START chip (72 -> 70 + 15 = 85)
				var base := SpeechRules.snap5(pta)
				var said_pta := ("%d" % base) if roundi(pta) == base else ("%d: call it %d" % [roundi(pta), base])
				return [_say("{His} PTA is %s. Start 15 above: tap %s %s to %d dB.") % [said_pta, key, times, target_db], bid, "start%d" % session.db]
			var cand := session.candidate()
			if cand != SpeechRules.NO_SRT and target_db == cand:
				return ["Bracketed at %d dB! Go back: tap %s %s." % [cand, key, times], bid, "back%d" % session.db]
			var last: Dictionary = list[n - 1]
			if session.db == int(last["db"]) and last["scored"] != null:
				if bool(last["scored"]):
					if not is_nan(pta) and float(session.db) <= pta - 20.0:
						return [_say("Got it at %d, way below {his} PTA! DOWN 10: tap %s %s.") % [session.db, key, times], bid, "down%d_%d" % [n, session.db]]
					return ["Got it: DOWN 10! Tap %s %s." % [key, times], bid, "down%d_%d" % [n, session.db]]
				return ["Missed: UP 5. Tap %s %s." % [key, times], bid, "up%d_%d" % [n, session.db]]
			return ["One more tap of %s, to %d dB." % [key, target_db], bid, "step%d_%d" % [n, session.db]]
		&"present":
			if n == 0:
				return ["Start level set! Press %s (or PRESENT) to say the first word." % _k(&"present_tone"), "speech_present_button", "present0"]
			return ["Now say a word at %d dB: press %s." % [session.db, _k(&"present_tone")], "speech_present_button", "present%d" % n]
		&"score_correct":
			return [_say("{He} said the whole word! Score it CORRECT: press %s.") % _k(&"speech_correct"), "speech_correct_button", "score%d" % n]
		&"score_missed":
			var key2 := _k(&"speech_incorrect")
			var kind := StringName(String(session.current.get("kind", "")))
			var line := "No word, no point. Score it MISSED: press %s."
			if kind == &"half":
				line = "Half a word is a miss! Score it MISSED: press %s."
			elif kind == &"wrong":
				line = "A different word is a miss! Score it MISSED: press %s."
			return [line % key2, "speech_incorrect_button", "score%d" % n]
		&"store":
			return ["Bracketed! %d dB: the softest level with half or more right. Press %s to STORE." % [session.db, _k(&"store")], "speech_store_button", "store%d" % n]
		&"mask_toggle":
			return ["This loud, speech can cross over. Press %s: speech noise in the other ear." % _k(&"toggle_mask"), "speech_mask_button", "mask%d" % n]
	return ["", "", ""]


func _k(action: StringName) -> String:
	var label := Game.key_label(action)
	return "[%s]" % ("SPACE" if label == "Space" else label)


func _say(text: String) -> String:
	if session != null and session.patient != null:
		return session.patient.say(text)
	return PatientProfile.pronouns(text, "he").replace("{name}", "Mike")


# ---------------------------------------------------------------- per frame and refresh

func _process(delta: float) -> void:
	_clock += delta
	_talk_glow = move_toward(_talk_glow, 1.0 if _talking else 0.0, delta * 8.0)
	_mic = maxf(0.0, _mic - delta * 0.9)
	if _lcd != null:
		_lcd.talk_glow = _talk_glow
		_booth.tone_glow = _talk_glow
		var pb := _btn("speech_present_button")
		pb.glow = _talk_glow
		var mult := ClinicRules.combo_multiplier(session.combo) if session != null else 1
		var target_flame := 0.0 if session == null or session.combo == 0 else 18.0 + 9.0 * mult
		pb.flame_px = move_toward(pb.flame_px, target_flame, delta * 120.0)
		pb.flame_heat = clampf((mult - 1) / 4.0, 0.0, 1.0)
		_mic_lamp.queue_redraw()
	if _accepting:
		_sync_bubble_hint()
	if Hoot.is_showing() != _perch_hidden and _hoot_spot != null:
		_perch_hidden = Hoot.is_showing()
		_hoot_spot.queue_redraw()
	if _ff_banner != null and _ff_banner.visible:
		_ff_banner.queue_redraw()


func _sync_bubble_hint() -> void:
	if _hoot_spot == null or not _hoot_spot.is_inside_tree():
		return
	var r := _hoot_spot.get_global_rect()
	if r.size.x > 0.0 and r.position != Vector2.ZERO and r != Hoot.bubble_rect_hint:
		Hoot.set_bubble_hint(r)


## The softest level the player scored "repeated" (SpeechRules.NO_SRT = none): the provisional SRT.
static func _provisional(trail: Array) -> int:
	var lo := SpeechRules.NO_SRT
	for tr: Dictionary in trail:
		if tr["scored"] != null and bool(tr["scored"]):
			var d := int(tr["db"])
			if lo == SpeechRules.NO_SRT or d < lo:
				lo = d
	return lo


func _refresh() -> void:
	if _lcd == null:
		return
	var st := get_state()
	var e := String(st["ear"])
	var pta := float(st["pta"])
	var trail: Array = st["trail"]
	var db := int(st["db"])
	var prov := _provisional(trail)
	var right := 0
	var total := 0
	for tr: Dictionary in trail:
		if tr["scored"] != null and int(tr["db"]) == db:
			total += 1
			right += 1 if bool(tr["scored"]) else 0
	var thresholds := {}
	if session != null and not session.tone_results.is_empty():
		thresholds = ClinicRules.best_thresholds(session.tone_results, e, false)
	var idle := _idle()
	_lcd.update_view({"ear": e, "db": db, "talking": _talking, "test": String(st["test"]), "list_title": String(st["list_title"]),
		"word_n": int(trail.size()), "words_left": int(st["words_left"]), "transducer": String(st["transducer"]), "pta": pta,
		"pta_method": SpeechRules.pta_method(thresholds) if not thresholds.is_empty() else "three",
		"start_db": int(st["recommended_start"]), "started": not trail.is_empty(), "tally": [right, total],
		"mask_on": bool(st["mask_on"]), "mask_db": int(st["mask_db"]), "mask_ear": String(st["mask_ear"]),
		"masking_needed": bool(st["masking_needed"]), "accepting": bool(st["accepting_input"])})
	_ladder.set_view({"ear": e, "trail": trail, "db": db, "pta": pta, "candidate_db": int(st["candidate_db"]),
		"talking": _talking or _listening, "accepting": idle, "provisional": prov})
	if _show_agreement and not bool(st["done"]):
		_meter.set_reading(pta, prov, not trail.is_empty())
	# the word card: the word being said / answered, else the next one
	_card.list_title = String(st["list_title"])
	_card.ear = e
	if session != null and not bool(st["done"]):
		if _busy() or (session.awaiting_score and not session.current.is_empty()):
			var it := SpeechMaterial.item(session.list_id, String(session.current.get("item_id", "")))
			_card.set_word(String(session.current.get("word", "")), it.get("parts", []), int(session.current.get("n", 0)), int(st["words_left"]))
			if _talking:
				_card.state = &"talking"
			elif _listening:
				_card.state = &"listening"
			else:
				_card.state = &"score"
		else:
			var nx := session.next_item()
			_card.set_word(String(nx.get("text", "")), nx.get("parts", []), trail.size() + 1, int(st["words_left"]))
			_card.state = &"idle" if not nx.is_empty() else &"empty"
	# Hoot's recheck (a fresh session) scores nothing: the player's points stay on the display
	_status.set_points(_kept_session.points if _kept_session != null else int(st["points"]))
	_refresh_buttons(st)
	_update_dance(st)
	_coach_update()
	Events.speech_state_changed.emit(st)
	_queue_beat()


func _refresh_buttons(st: Dictionary) -> void:
	var busy := _busy()
	var done := bool(st["done"]) or _finishing
	var awaiting := bool(st["awaiting_score"])
	var mb := _btn("speech_mask_button")
	var on := bool(st["mask_on"])
	mb.text = "MASK ON" if on else "MASK OFF"
	mb.face_color = Palette.PLUM.lightened(0.35) if on else Palette.CREAM
	for id: String in ["speech_louder_button", "speech_softer_button", "speech_mask_button"]:
		_btn(id).locked = busy or done
	_btn("speech_present_button").locked = busy or done
	var can_score := awaiting and _answer_shown and not done
	_btn("speech_correct_button").locked = not can_score
	_btn("speech_incorrect_button").locked = not can_score
	_btn("speech_store_button").locked = busy or done or awaiting or (st["trail"] as Array).is_empty()
	for id: String in ACTION_BUTTONS.values():
		var b := _btn(id)
		var want := false
		if _auto_running or done:
			want = false
		elif _coach_active:
			want = id == _coach_action_button()
		elif id == "speech_store_button":
			want = int(st["candidate_db"]) != SpeechRules.NO_SRT and int(st["candidate_db"]) == int(st["db"]) and not awaiting and not busy
		elif id == "speech_mask_button":
			want = bool(st["masking_needed"]) and not on and not busy
		if can_score and not _auto_running and (id == "speech_correct_button" or id == "speech_incorrect_button"):
			want = true   # both pulse until the word is scored
		b.beckon = want
	for b: AoButton in _buttons.values():
		b.queue_redraw()


## The coach's button for the move it is teaching right now ("" while a word plays).
func _coach_action_button() -> String:
	if session == null or _busy():
		return ""
	return String(ACTION_BUTTONS.get(session.recommended_action()["action"], ""))


## The dance card lights the rule for the player's LAST score (never while a word waits for its
## score: that would give the answer away), or BRACKETED -> STORE.
func _update_dance(st: Dictionary) -> void:
	if session == null or bool(st["done"]) or _busy() or bool(st["awaiting_score"]):
		_dance.clear()
		return
	var cand := int(st["candidate_db"])
	if cand != SpeechRules.NO_SRT:
		_dance.pulse(SpDance.CHIP_STORE)
	elif _last_scored == null:
		_dance.clear()
	elif bool(_last_scored):
		_dance.pulse(SpDance.CHIP_GOT)
	else:
		_dance.pulse(SpDance.CHIP_MISSED)


func _refresh_keys() -> void:
	var show := bool(Game.settings.get("show_key_hints", true))
	for b: AoButton in _buttons.values():
		b.show_keycap = show
		b.queue_redraw()
	var swapped := Game.get_key_style() == "affinity"
	var style := _btn("style_toggle")
	style.text = "Up = SOFTER" if swapped else "Up = LOUDER"
	style.sub_text = "(swapped)" if swapped else "(default)"
	var keys := _btn("keys_toggle")
	keys.text = "Keys: ON" if show else "Keys: OFF"
	keys.face_color = Palette.MINT if show else Palette.CREAM
	if session != null and _coach_active:
		_coach_key = ""
		_coach_update()


func _on_key_style_changed(_style: String) -> void:
	_refresh_keys()


func _on_settings_changed(key: String, value: Variant) -> void:
	_refresh_keys()
	if key == "quick_visit" and not Game.cli_flag("quick") and not Game.cli_flag("full"):
		quick_visit = bool(value)


func _on_comfort_changed(hearts: int, _reason: String) -> void:
	_status.set_hearts(hearts)


func _on_screen_shake(strength: float, duration: float) -> void:
	Juice.shake(_root, 16.0 * strength, duration)


func _after(seconds: float, cb: Callable) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(maxf(0.0, seconds), false).timeout.connect(cb)


func _btn(id: String) -> AoButton:
	return _buttons.get(id) as AoButton


func _register_anchors() -> void:
	for id: String in ACTION_BUTTONS.values():
		if _buttons.has(id):
			Hoot.register_anchor(id, _buttons[id])
	if _card != null:
		Hoot.register_anchor("speech_word_card", _card)
		Hoot.register_anchor("speech_response", _bubble)
		Hoot.register_anchor("speech_ladder", _ladder)
		Hoot.register_anchor("agreement_meter", _meter)


# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SpeechMode"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bg = Control.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP   # the screen covers the world: eat stray clicks
	_bg.draw.connect(_draw_bg)
	_root.add_child(_bg)
	_deck = Control.new()
	_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck.draw.connect(_draw_deck)
	_root.add_child(_deck)
	_booth = AoBoothWindow.new()
	_root.add_child(_booth)
	_mic_lamp = Control.new()
	_mic_lamp.name = "MicLamp"
	_mic_lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mic_lamp.draw.connect(_draw_mic_lamp)
	_root.add_child(_mic_lamp)
	_lcd = SpLcd.new()
	_lcd.name = "SpeechLcd"
	_lcd.level_step.connect(_on_lcd_step)
	_root.add_child(_lcd)
	_status = AoStatus.new()
	_root.add_child(_status)
	_bubble = SpBubble.new()
	_bubble.name = "AnswerBubble"
	_root.add_child(_bubble)
	_card = SpWordCard.new()
	_card.name = "WordCard"
	_root.add_child(_card)
	_ladder = SpLadder.new()
	_ladder.name = "SrtLadder"
	_root.add_child(_ladder)
	_meter = SpAgreementMeter.new()
	_meter.name = "AgreementMeter"
	_meter.clunked.connect(_on_meter_clunked)
	_root.add_child(_meter)
	_hoot_spot = Control.new()
	_hoot_spot.name = "HootSpot"
	_hoot_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hoot_spot.draw.connect(_draw_perch)
	_root.add_child(_hoot_spot)
	_dance = SpDance.new()
	_dance.name = "DanceCard"
	_root.add_child(_dance)
	# controls
	var soft := _make_button("speech_softer_button", "SOFTER", AoButton.Icon.TRI_DOWN, SpButton.Glyph.NONE, Palette.SUNNY, &"softer", &"softer")
	var present := _make_button("speech_present_button", "PRESENT", AoButton.Icon.NONE, SpButton.Glyph.TALK, Palette.SKY, &"present_tone", &"present")
	present.font_size = 24
	present.icon_size = 38.0
	var loud := _make_button("speech_louder_button", "LOUDER", AoButton.Icon.TRI_UP, SpButton.Glyph.NONE, Palette.SUNNY, &"louder", &"louder")
	for b: AoButton in [soft, loud]:
		b.font_size = 19
	var miss := _make_button("speech_incorrect_button", "MISSED", AoButton.Icon.NONE, SpButton.Glyph.CROSS, Palette.CORAL, &"speech_incorrect", &"score_missed")
	miss.text_color = Palette.PAPER
	_make_button("speech_correct_button", "CORRECT", AoButton.Icon.NONE, SpButton.Glyph.CHECK, Palette.PRESS_LIME, &"speech_correct", &"score_correct")
	_make_button("speech_store_button", "STORE", AoButton.Icon.STAMP, SpButton.Glyph.NONE, Palette.MINT, &"store", &"store")
	var mask := _make_button("speech_mask_button", "MASK OFF", AoButton.Icon.NONE, SpButton.Glyph.NOISE, Palette.CREAM, &"toggle_mask", &"mask_toggle")
	mask.font_size = 17
	var keys := _make_button("keys_toggle", "Keys: ON", AoButton.Icon.NONE, SpButton.Glyph.NONE, Palette.MINT, TOGGLE_HINTS_ACTION, &"")
	keys.clicked.connect(_toggle_hints)
	var style := _make_button("style_toggle", "Up = LOUDER", AoButton.Icon.NONE, SpButton.Glyph.NONE, Palette.PAPER, &"", &"")
	style.clicked.connect(_toggle_key_style)
	for b: AoButton in [keys, style]:
		b.font_size = 14
		b.depth = 4.0
		b.radius = 12
		b.pill = true
	# mouse players need a way into the pause menu (the story hides its corner button meanwhile)
	var pause_btn := _make_button("pause_button", "II", AoButton.Icon.NONE, SpButton.Glyph.NONE, Palette.PAPER, &"", &"")
	pause_btn.clicked.connect(_open_pause_menu)
	pause_btn.font_size = 16
	pause_btn.pill = true
	pause_btn.depth = 3.0
	pause_btn.radius = 12
	pause_btn.tooltip_text = "Pause (Esc)"
	_ff_banner = Control.new()
	_ff_banner.name = "HootTurnBanner"
	_ff_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ff_banner.visible = false
	_ff_banner.draw.connect(_draw_ff_banner)
	_root.add_child(_ff_banner)
	_fx = AoFx.new()
	_root.add_child(_fx)
	_refresh_keys()


func _make_button(id: String, text: String, icon: AoButton.Icon, glyph: SpButton.Glyph, color: Color, input: StringName, action: StringName) -> SpButton:
	var b := SpButton.new()
	b.name = id
	b.text = text
	b.icon = icon
	b.glyph = glyph
	b.face_color = color
	b.action = input
	b.focus_mode = Control.FOCUS_NONE
	if action != &"":
		b.clicked.connect(_on_button_clicked.bind(action))
	_root.add_child(b)
	_buttons[id] = b
	return b


func _on_button_clicked(action: StringName) -> void:
	if _player_ok():
		_act(action)


func _on_lcd_step(direction: int) -> void:
	if _player_ok():
		_level(direction)


func _layout() -> void:
	if not is_inside_tree() or _root == null:
		return
	var vp := get_viewport().get_visible_rect().size
	_root.position = Vector2.ZERO
	_root.size = vp
	_bg.position = Vector2.ZERO
	_bg.size = vp
	_fx.position = Vector2.ZERO
	_fx.size = vp
	var m := 12.0
	var top_h := 176.0
	var bottom_h := 150.0
	var col_w := 300.0
	var booth_w := 292.0
	var y_top := m + 8.0
	_booth.position = Vector2(m, y_top)
	_booth.size = Vector2(booth_w, top_h)
	_mic_lamp.position = _booth.position + Vector2(booth_w - 44.0 - 36.0, top_h - 42.0 - 34.0)
	_mic_lamp.size = Vector2(72.0, 74.0)
	_status.position = Vector2(vp.x - m - col_w, y_top)
	_status.size = Vector2(col_w, top_h)
	var pb := _btn("pause_button")
	pb.size = Vector2(40.0, 36.0)
	pb.position = Vector2(_status.position.x + col_w - 52.0, y_top + 12.0)
	_lcd.position = Vector2(m * 2.0 + booth_w, y_top)
	_lcd.size = Vector2(vp.x - m * 4.0 - booth_w - col_w, top_h)
	var mid_y := y_top + top_h + m + 4.0
	var bottom_y := vp.y - m - bottom_h
	var mid_h := bottom_y - m - mid_y
	# left column: his answer (its tail points up at the booth) over the clinician's word card
	var bub_y := y_top + top_h + 2.0
	var bub_h := clampf(mid_h * 0.44 + 10.0, 136.0, 210.0)
	_bubble.position = Vector2(m, bub_y)
	_bubble.size = Vector2(booth_w, bub_h)
	_bubble.tail_x = booth_w * 0.36
	var card_y := bub_y + bub_h + m
	_card.position = Vector2(m, card_y)
	_card.size = Vector2(booth_w, maxf(120.0, bottom_y - m - card_y))
	# middle: the SRT ladder and the agreement meter
	var mid_x := m * 2.0 + booth_w
	var mid_w := vp.x - m * 4.0 - booth_w - col_w
	var meter_w := clampf(mid_w * 0.42, 250.0, 340.0) if _show_agreement else 0.0
	_ladder.position = Vector2(mid_x, mid_y)
	_ladder.size = Vector2(mid_w - (meter_w + m if _show_agreement else 0.0), mid_h)
	_meter.position = Vector2(mid_x + mid_w - meter_w, mid_y)
	_meter.size = Vector2(maxf(meter_w, 1.0), mid_h)
	# right column: Hoot's perch over the dance card
	var dance_h := 56.0
	_hoot_spot.position = Vector2(vp.x - m - col_w, mid_y - 6.0)
	_hoot_spot.size = Vector2(col_w, mid_h - dance_h - 4.0)
	_dance.position = Vector2(vp.x - m - col_w, mid_y + mid_h - dance_h)
	_dance.size = Vector2(col_w, dance_h)
	_ff_banner.size = Vector2(250.0, 44.0)
	_ff_banner.position = Vector2(_ladder.position.x + (_ladder.size.x - 250.0) * 0.5, y_top + top_h - 22.0)
	_deck.position = Vector2(m, bottom_y)
	_deck.size = Vector2(vp.x - m * 2.0, bottom_h)
	_layout_deck(Rect2(_deck.position, _deck.size))
	_sync_bubble_hint()


func _layout_deck(deck: Rect2) -> void:
	var k := clampf((deck.size.x - 1256.0) / 600.0, 0.0, 1.0)   # wider screens: roomier buttons
	var groups: Array = [
		["LEVEL + WORD", [["speech_softer_button", lerpf(96.0, 110.0, k)], ["speech_present_button", lerpf(196.0, 230.0, k)], ["speech_louder_button", lerpf(96.0, 110.0, k)]]],
		["SCORE WHAT HE SAID", [["speech_incorrect_button", lerpf(128.0, 150.0, k)], ["speech_correct_button", lerpf(128.0, 150.0, k)]]],
		["SRT", [["speech_store_button", lerpf(136.0, 150.0, k)]]],
		["NOISE", [["speech_mask_button", lerpf(116.0, 130.0, k)]]],
	]
	(groups[1] as Array)[0] = _say("SCORE WHAT {he} SAID").to_upper()
	var gap := 9.0
	var util_w := 132.0
	var widths: Array[float] = []
	var total := 0.0
	for g: Array in groups:
		var w := 0.0
		for b: Array in g[1]:
			w += float(b[1])
		w += gap * ((g[1] as Array).size() - 1)
		widths.append(w)
		total += w
	var inner := deck.size.x - 40.0 - util_w
	var spacing := maxf(14.0, (inner - total) / groups.size())
	var x := deck.position.x + 20.0 + spacing * 0.3
	var y := deck.position.y + 26.0
	var h := deck.size.y - 32.0
	_group_labels.clear()
	for gi in groups.size():
		var g: Array = groups[gi]
		_group_labels.append([g[0], Rect2(Vector2(x, deck.position.y + 6.0), Vector2(widths[gi], 16.0))])
		for b: Array in g[1]:
			var btn := _btn(String(b[0]))
			btn.position = Vector2(x, y)
			btn.size = Vector2(float(b[1]), h)
			x += float(b[1]) + gap
		x += spacing - gap
	var ux := deck.end.x - 16.0 - util_w
	var uy := deck.position.y + 14.0
	var uh := (deck.size.y - 28.0 - 10.0) / 2.0
	for i in 2:
		var btn := _btn(["keys_toggle", "style_toggle"][i])
		btn.position = Vector2(ux, uy + i * (uh + 10.0))
		btn.size = Vector2(util_w, uh)
	_deck.queue_redraw()


func _draw_bg() -> void:
	var r := Rect2(Vector2.ZERO, _bg.size)
	_bg.draw_rect(r, Palette.CREAM)
	var col := Palette.CREAM.darkened(0.035)
	var step := 46.0
	var row := 0
	var yy := 0.0
	while yy < r.size.y + step:
		var off := (step * 0.5) if row % 2 == 1 else 0.0
		var xx := -step + off
		while xx < r.size.x + step:
			_bg.draw_circle(Vector2(xx, yy), 6.0, col)
			xx += step
		yy += step * 0.8
		row += 1
	_bg.draw_rect(Rect2(0, 0, r.size.x, 8.0), Palette.SKY)


## Hoot's empty perch (his bubble covers it while he talks).
func _draw_perch() -> void:
	var r := Rect2(Vector2(4, 10), _hoot_spot.size - Vector2(8, 16))
	if r.size.y < 40.0 or Hoot.is_showing():
		return
	var col := Color(Palette.INK, 0.16)
	var k := 14.0
	var pts := [r.position + Vector2(k, 0), Vector2(r.end.x - k, r.position.y), Vector2(r.end.x, r.position.y + k), r.end - Vector2(0, k),
		r.end - Vector2(k, 0), Vector2(r.position.x + k, r.end.y), Vector2(r.position.x, r.end.y - k), r.position + Vector2(0, k)]
	for i in range(0, 8, 2):
		AoDraw.dashed(_hoot_spot, pts[i], pts[i + 1], col, 2.0, 8.0, 6.0)
	var c := r.get_center()
	_hoot_spot.draw_circle(c + Vector2(0, -16), 18.0, Color(Palette.INK, 0.08))
	_hoot_spot.draw_arc(c + Vector2(-7, -18), 5.0, 0.2, PI - 0.2, 10, Color(Palette.INK, 0.22), 2.0, true)
	_hoot_spot.draw_arc(c + Vector2(7, -18), 5.0, 0.2, PI - 0.2, 10, Color(Palette.INK, 0.22), 2.0, true)
	var txt := "Hoot is testing: watch the ladder!" if _auto_running else "Hoot's perch: tips pop up here"
	AoDraw.text_c(_hoot_spot, c + Vector2(0, 18), txt, 13, Color(Palette.INK, 0.32 if not _auto_running else 0.6), AoDraw.FONT_BOLD)


func _draw_deck() -> void:
	var r := Rect2(Vector2.ZERO, _deck.size)
	AoDraw.card(_deck, r, Color("#3b3154"), 26)
	AoDraw.rbox(_deck, Rect2(Vector2(14, 6), Vector2(r.size.x - 28, 10)), Color(1, 1, 1, 0.05), 5)
	for gl: Array in _group_labels:
		var lr: Rect2 = gl[1]
		var local := Rect2(lr.position - _deck.position, lr.size)
		var label := String(gl[0])
		var tw := AoDraw.text_size(label, 12, AoDraw.FONT_BOLD).x
		var cy := local.get_center().y + 2.0
		AoDraw.text_c(_deck, local.get_center() + Vector2(0, 2), label, 12, Color(Palette.SUNNY, 0.75), AoDraw.FONT_BOLD)
		if local.get_center().x - tw * 0.5 - 8.0 > local.position.x:
			_deck.draw_line(Vector2(local.position.x, cy), Vector2(local.get_center().x - tw * 0.5 - 8.0, cy), Color(Palette.SUNNY, 0.25), 2.0)
			_deck.draw_line(Vector2(local.get_center().x + tw * 0.5 + 8.0, cy), Vector2(local.end.x, cy), Color(Palette.SUNNY, 0.25), 2.0)


## The talk-back MIC lamp over the booth's PRESS plate: it lights while he answers.
func _draw_mic_lamp() -> void:
	var r := Rect2(Vector2(2, 2), _mic_lamp.size - Vector2(4, 4))
	var lc := Vector2(r.get_center().x, r.position.y + 30.0)
	var p := _mic
	var lit := clampf(p * 1.6, 0.0, 1.0)
	AoDraw.rbox(_mic_lamp, Rect2(r.position + Vector2(0, 3), r.size), Color(Palette.INK, 0.35), 16)
	AoDraw.rbox(_mic_lamp, r, Palette.LCD_BG, 16, 3, Palette.INK)
	if p > 0.0:
		_mic_lamp.draw_circle(lc, 28.0, Color(Palette.SUNNY, 0.3 * p))
	_mic_lamp.draw_circle(lc, 20.0, Palette.INK)
	_mic_lamp.draw_circle(lc, 16.5, Palette.LCD_DIM.lerp(Palette.SUNNY, lit))
	# a little microphone
	var mc := Color(Palette.INK, 0.75)
	AoDraw.rbox(_mic_lamp, Rect2(lc + Vector2(-4.5, -10.0), Vector2(9.0, 14.0)), mc, 4)
	_mic_lamp.draw_arc(lc + Vector2(0, -2.0), 8.0, 0.15, PI - 0.15, 10, mc, 2.0, true)
	_mic_lamp.draw_line(lc + Vector2(0, 6.0), lc + Vector2(0, 10.0), mc, 2.0)
	_mic_lamp.draw_line(lc + Vector2(-5, 10.5), lc + Vector2(5, 10.5), mc, 2.0)
	AoDraw.text_c(_mic_lamp, Vector2(lc.x, r.end.y - 11.0), "MIC", 12, Palette.PAPER.lerp(Palette.SUNNY, lit), AoDraw.FONT_BOLD)


func _draw_ff_banner() -> void:
	var r := Rect2(Vector2.ZERO, _ff_banner.size)
	AoDraw.rbox(_ff_banner, Rect2(r.position + Vector2(0, 4), r.size), Color(Palette.INK, 0.3), 18)
	AoDraw.rbox(_ff_banner, r, Palette.HOOT_FACE, 18, 3, Palette.INK)
	var t := Time.get_ticks_msec() / 1000.0
	for i in 3:
		var a := 0.35 + 0.65 * maxf(0.0, sin(t * 7.0 - i * 0.9))
		UiDraw.arrow(_ff_banner, Vector2(r.end.x - 70.0 + i * 16.0, r.get_center().y), 12.0, Vector2.RIGHT, Color(Palette.INK, a))
	AoDraw.text_l(_ff_banner, Vector2(18.0, r.get_center().y), "HOOT'S TURN  x8", 20, Palette.INK, AoDraw.FONT_BOLD)
