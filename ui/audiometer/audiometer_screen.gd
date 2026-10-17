class_name AudiometerScreen
extends CanvasLayer
## AudiometerScreen: the AudiOtron 3000 (builder A). CONTRACTS.md §4.2-§4.7.
## Root of res://ui/audiometer/audiometer_screen.tscn (CanvasLayer, layer 20). Story adds it,
## calls start_test() once per ear and awaits test_finished. Everything else goes through
## Events / Stage / Hoot. Playable with keys (OTOsuite-style defaults, Up = louder) AND mouse:
## hold the TONE pad, right-click it for no response, click the audiogram or the test plan
## to jump to a frequency, click the LCD chevrons or scroll over the level.
## (v3, Day 2) start_test(..., plan) picks the test (CONTRACTS.md §4.2 v3): bone conduction and
## masking add a MASKING group (noise down / on-off / up: PgDn, M, PgUp or Shift+arrows) and a
## ROUTE button (air / bone: A, B) to the deck, a NOISE box on the LCD and the plateau graph.
## Day 1 plans never show them.

## Emitted when every required measurement of the requested ear is stored (after the
## ear-complete fanfare). results: CONTRACTS.md §5.1 (all ears tested so far this visit).
signal test_finished(results: Dictionary)

const ANCHORS: Array[String] = ["tone_button", "louder_button", "softer_button", "freq_up_button", "freq_down_button", "store_button", "no_response_button", "ear_right_button", "ear_left_button", "audiogram_right", "audiogram_left"]
## (v3) Buttons (and Hoot anchors) that only show on Day 2 plans (hidden on Day 1).
## Anchor ids: mask_softer_button, mask_toggle_button, mask_louder_button, transducer_button.
const MASK_BUTTONS: Array[String] = ["mask_softer_button", "mask_toggle_button", "mask_louder_button", "transducer_button"]
## (v3) Test-plan panel titles per goal test.
const QUEST_TITLES: Dictionary[StringName, String] = {&"ac": "TEST PLAN", &"bc": "BONE PLAN", &"bc_masked": "MASKED BONE", &"ac_masked": "MASKED AIR"}
## Runtime action for the key-hint toggle (H). Added here if project.godot lacks it.
const TOGGLE_HINTS_ACTION := &"toggle_key_hints"
const HINT_FEATHERS := 3
const TEXTBOOK_CALLOUTS: Array[String] = ["Textbook!", "By the book!", "Hughson would be proud!", "Westlake-tastic!", "Smooth!", "Clinic-grade!"]
## Golf callout colours. Par is a neutral sunny yellow, never an ear colour (red = right, blue = left).
const GOLF_COLORS: Dictionary[StringName, Color] = {
	&"albatross": Color("#8e5cc4"), &"eagle": Color("#ff9f1c"), &"birdie": Color("#5bc8a3"), &"par": Color("#ffd23f"),
	&"bogey": Color("#fffbf2"), &"double_bogey": Color("#fffbf2"), &"triple_bogey": Color("#fffbf2"),
}
const EMOTES: Dictionary[StringName, String] = {
	&"too_loud_blast": "blast", &"bored": "bored", &"yawn": "bored", &"grooving": "groove", &"straining": "strain",
	&"squint": "squint", &"false_alarm": "confused", &"point_wrong_way": "wrong",
	&"tickle": "giggle", &"cross_heard": "ghost", &"overmasked": "confused",
}
const ERROR_KINDS: Array[StringName] = [&"wrong_step", &"start_too_high", &"store_without_bracket", &"store_wrong_level", &"start_not_1k", &"missed_retest", &"retest_mismatch", &"nr_too_early", &"tone_too_short", &"tone_too_long", &"rhythmic",
	&"mask_wrong_step", &"mask_too_low", &"mask_start", &"store_no_plateau", &"overmasked"]
## Tips that repeat (with a cooldown) instead of firing once: the everyday slips.
const REPEAT_TIPS: Array[StringName] = [&"wrong_step", &"store_without_bracket", &"store_wrong_level", &"tone_too_short", &"rhythmic", &"mask_wrong_step", &"store_no_plateau"]
const TIP_COOLDOWN_S := 20.0
## After this many clean steps the player knows the dance: repeats get rarer.
const TIP_QUIET_AFTER_STEPS := 10
const TIP_COOLDOWN_LATE_S := 45.0
## Store / no-response presses this soon after a stamp are ignored (a double tap of S or Enter).
const STORE_DEBOUNCE_S := 0.35
## Quick visit: the solo (left) ear is the player's for this many stamps, then Hoot finishes it.
const QUICK_SOLO_HOLES := 3
## Reactions that zoom the booth camera in over the right ear card.
## Sub-lines for a stamp with a store-time slip.
const STORE_ERROR_SUBS: Dictionary[StringName, String] = {
	&"store_without_bracket": "store after 2 hits going UP",
	&"store_wrong_level": "not the lowest level heard twice",
	&"start_not_1k": "each ear starts at 1000 Hz",
	&"missed_retest": "recheck 1000 Hz before the lows",
	&"retest_mismatch": "retest is more than 5 dB off",
	&"nr_too_early": "NR only after a miss at max",
	&"store_no_plateau": "no plateau yet: 3 noise raises",
}
const PUNCH_KINDS: Array[StringName] = [&"too_loud_blast", &"squint", &"grooving", &"false_alarm", &"point_wrong_way"]
const PUNCH_SCALE := 2.2
const PUNCH_HOLD_S := 1.2
## Gus thinks out loud between beeps (after every second stamp, never during a tone).
const GUS_QUIPS: Array[String] = [
	"Was that a bird? No? Carry on.",
	"Doris never beeps this politely.",
	"Ka-CHUNK! Sorry, library habit.",
	"Is this the ball game?",
	"Forty years of shushing people. Now the room shushes ME.",
	"I'm pressing with my good thumb, you know.",
	"Beep, boop... are we texting now?",
	"If I nod off, take it as a compliment.",
	"These earmuffs would be great for ice fishing.",
	"Is it rude to hum along?",
	"I hear better after a bagel. Just saying.",
	"Tell the beeps I said hello.",
	"Cozy in here. Do you rent it out?",
	"Was that one for me, or for the owl?",
	"I spy, with my little ear...",
	"Quieter than the reference section in here!",
]
const HOOT_GOLF_QUIPS: Dictionary[StringName, Array] = {
	&"birdie": ["A birdie! The one thing he can't hear.", "Birdie! Fewer beeps, same great threshold.", "Tweet tweet! Quick AND accurate.", "Birdie! His ears thank you for the shortcut."],
	&"eagle": ["An eagle! Owls are jealous, frankly.", "Eagle! You barely beeped and nailed it.", "Eagle! That bracket was sharp as a talon."],
	&"albatross": ["An ALBATROSS! I've only read about those.", "Albatross! Frame that trail.", "Albatross! Even the bird is impressed."],
	&"par": ["Par! Steady and by the book.", "Right on par. That's how pros do it.", "Par! In audiology, boring is beautiful.", "Par. Neat as a library shelf."],
}

var session: AudiometrySession
## Quick visit (default, pause menu "Quick visit", --quick / --full): the solo ear is the
## player's for QUICK_SOLO_HOLES stamps, then Hoot fast-forwards the rest so the level fits ~10 min.
var quick_visit := true
var _accepting := false
var _ear := "right"
var _coached := false
var _coach_active := false
var _coach_tip := -1
var _coach_key := ""
var _familiar_note_done := false
var _tone: ToneGenerator
var _stim := 0
var _hold: Dictionary = {}
var _tone_glow := 0.0
var _feathers := HINT_FEATHERS
var _finishing := false
var _perch_hidden := false
var _clean_steps := 0
var _tip_last: Dictionary = {}       ## tip kind -> session time it was last shown
var _last_store_t := -100.0
var _player_stamps := 0              ## stamps made by the player this visit (Gus quips on every 2nd)
var _par_count := 0
var _solo_stamps := 0                ## player stamps on the current uncoached ear (quick visit)
var _quip_order: Array[int] = []
var _punch_t := -100.0
var _punch_tween: Tween
var _told_3k6k := false
var _dance_key := ""
var _auto: AoAutoTester
var _auto_running := false
var _auto_done_ears: Dictionary = {}
var _base_time_scale := 1.0
var _ff_on := false
var _music_ducked := false
# ---- v3
## The plan given to start_test() (CONTRACTS.md §4.2 v3), {} on Day 1.
var _plan: Dictionary = {}
## Masking / route controls are live (Day 2 plans).
var _masking_ui := false
## Quick visit: player stamps before Hoot's turn on this test (plan "hoot_turn_after").
var _solo_limit := QUICK_SOLO_HOLES
var _masker_key: Array = []
var _ghost_t := -100.0

var _root: Control
var _bg: Control
var _deck: Control
var _booth: AoBoothWindow
var _lcd: AoLcd
var _status: AoStatus
var _quest: AoQuest
var _dance: AoDanceCard
var _hoot_spot: Control
var _ff_banner: Control
var _fx: AoFx
var _cards: Dictionary[String, AoEarCard] = {}
var _buttons: Dictionary[String, AoButton] = {}
var _group_labels: Array = []   ## [text, Rect2] drawn on the deck


func _enter_tree() -> void:
	Stage.register_audiometer(self)
	# the booth stays quiet for the beeps: no music while the AudiOtron is up
	if Sfx.has_method("music_duck"):
		Sfx.music_duck(true)
		_music_ducked = true


func _exit_tree() -> void:
	if _auto_running:
		_end_hoot_turn()
	Hoot.clear_bubble_hint()
	Hoot.clear()
	Stage.unregister_audiometer(self)
	Stage.set_booth_view_active(false)
	for id: String in ANCHORS + MASK_BUTTONS:
		Hoot.unregister_anchor(id)
	if _music_ducked:
		Sfx.music_duck(false)


func _ready() -> void:
	layer = 20
	_ensure_hint_action()
	_tone = ToneGenerator.new()
	add_child(_tone)
	_auto = AoAutoTester.new()
	_auto.name = "HootTurn"
	add_child(_auto)
	quick_visit = bool(Game.settings.get("quick_visit", true))
	if Game.cli_flag("quick"):
		quick_visit = true
	if Game.cli_flag("full"):
		quick_visit = false
	for i in GUS_QUIPS.size():
		_quip_order.append(i)
	_quip_order.shuffle()
	_build_ui()
	Events.key_style_changed.connect(func(_s: String) -> void: _refresh_keys())
	Events.settings_changed.connect(func(_k: String, _v: Variant) -> void: _refresh_keys())
	Events.comfort_changed.connect(func(h: int, _r: String) -> void: _status.set_hearts(h))
	Events.screen_shake.connect(_on_screen_shake)
	Events.settings_changed.connect(func(k: String, v: Variant) -> void:
		if k == "quick_visit" and not Game.cli_flag("quick") and not Game.cli_flag("full"):
			quick_visit = bool(v))
	Events.pause_toggled.connect(_on_pause_toggled)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_status.set_hearts(Game.get_comfort())
	_refresh()


## Standalone boot (main.gd --scene=res://ui/audiometer/audiometer_screen.tscn): a coached
## right-ear test of Gus, with the 3D clinic behind the booth window when it is available.
func demo_start() -> void:
	Game.begin_visit("gus")
	var clinic_path := "res://world/clinic.tscn"
	if not Stage.has_clinic() and ResourceLoader.exists(clinic_path):
		var clinic: Node = (load(clinic_path) as PackedScene).instantiate()
		get_parent().add_child(clinic)
		if clinic.has_method("get_main_camera"):
			var cam: Camera3D = clinic.call("get_main_camera")
			if cam != null:
				cam.current = false
		if clinic.has_method("put_on_earphones"):
			clinic.call("put_on_earphones", true)
		if clinic.has_method("sit"):
			clinic.call("sit")
	start_test(Game.load_patient("gus") as PatientProfile, "right", true)


## Begin testing one ear. Re-uses the session (and its audiogram) for the same patient.
## (v3) plan (CONTRACTS.md §4.2 v3): {} = the Day 1 air test. Keys:
##   "test": &"ac" | &"bc" | &"bc_masked" | &"ac_masked"   the goal sheet (session.configure())
##   "bc_freqs", "air_transducer", "mask_on", "mask_db"      passed to session.configure()
##   "masking_controls": bool  show MASKING / ROUTE on the deck (default: any non-air test)
##   "hoot_turn_after": int    quick visit: player stamps before Hoot finishes (0 = Hoot at once)
##   "intro": String           Hoot's opening line (instead of the default)
##   "hoot_turn_text": String  Hoot's line when he takes over
##   "done_title": String      the big callout when the test is complete
func start_test(patient: PatientProfile, ear: String, coached: bool, plan: Dictionary = {}) -> void:
	if session == null or session.patient.id != patient.id:
		session = AudiometrySession.new(patient, Game.rng.randi())
		session.responded.connect(_on_responded)
		session.technique.connect(_on_technique)
		session.combo_changed.connect(_on_combo)
		session.stored_point.connect(_on_stored)
		session.presentation_closed.connect(_on_presentation_closed)
		session.reaction.connect(_on_reaction)
		for c: AoEarCard in _cards.values():
			c.audiogram.clear_points()
		_feathers = HINT_FEATHERS
	else:
		session.sim.take_break()
	session.sim.instructed = bool(Game.get_visit_flag("instructed", true))
	session.sim.swapped = bool(Game.get_visit_flag("earphones_swapped", false))
	session.sim.fatigue_scale = 0.5 if Game.has_upgrade("comfy_chair") else 1.0
	_ear = ear
	_coached = coached
	_finishing = false
	_solo_stamps = 0
	_dance_key = ""
	_dance.clear()
	_plan = plan.duplicate(true)
	session.configure(_plan)
	_masking_ui = bool(_plan.get("masking_controls", session.goal_test != &"ac"))
	_solo_limit = int(_plan.get("hoot_turn_after", QUICK_SOLO_HOLES))
	_auto_done_ears.erase(ear)
	for id: String in MASK_BUTTONS:
		(_buttons[id] as AoButton).visible = _masking_ui
	_layout()
	session.coached[ear] = coached
	session.ear = ear
	if session.goal_test == &"ac":
		session.set_freq(ClinicRules.START_FREQ)
		session.set_level(ClinicRules.START_DB)
	else:
		var rem := session.required_remaining(ear)
		session.set_freq(rem[0] if not rem.is_empty() else ClinicRules.START_FREQ)
		session.set_level(session.recommended_start(ear, session.freq))
	Events.transducer_changed.emit(session.transducer, ear)
	_hold.clear()
	_accepting = true
	_booth.texture = Stage.get_booth_texture()
	Stage.set_booth_view_active(true)
	_sync_bubble_hint()
	for e: String in _cards:
		(_cards[e] as AoEarCard).active = e == ear
	(_buttons["ear_right_button"] as AoButton).locked = ear != "right"
	(_buttons["ear_left_button"] as AoButton).locked = ear != "left"
	Events.audiometry_started.emit(patient.id, ear, coached)
	_coach_key = ""
	_coach_tip = -1
	_coach_active = coached
	var intro := String(_plan.get("intro", ""))
	if coached:
		if intro != "":
			Hoot.say(intro, Hoot.NORMAL, "", "", 3.0)
		_coach_update()
	elif quick_visit and _solo_limit <= 0:
		if intro != "":
			Hoot.say(intro, Hoot.NORMAL, "", "", 2.0)
		_start_hoot_turn.call_deferred()
	elif intro != "":
		Hoot.say(intro, Hoot.NORMAL)
	elif quick_visit:
		Hoot.say("%s ear, all yours for %d stamps! Then I'll take a turn." % [ear.capitalize(), QUICK_SOLO_HOLES], Hoot.NORMAL)
	else:
		Hoot.say("%s ear, all on your own! I'll only chime in if something goes wrong." % ear.capitalize(), Hoot.NORMAL)
	_refresh()


## Snapshot for UI, bot and tests. Shape: CONTRACTS.md §4.3 (plus a few extra keys).
func get_state() -> Dictionary:
	if session == null:
		return {"patient_id": "", "ear": _ear, "freq": ClinicRules.START_FREQ, "db": ClinicRules.START_DB, "tone_on": false,
			"accepting_input": false, "coached": false, "freqs_available": ClinicRules.AC_FREQS.duplicate(),
			"min_db": ClinicRules.MIN_DB, "max_db": ClinicRules.max_db(ClinicRules.START_FREQ),
			"stored": {"right": {}, "left": {}}, "remaining": [], "ear_complete": false, "combo": 0, "presentations": 0,
			"points": 0, "multiplier": 1, "trail": [], "strokes": 0, "par": 0, "candidate_db": -1, "stimulus": ToneGenerator.STIMULUS_NAMES[_stim],
			"hoot_turn": false, "quick_visit": quick_visit,
			"test": &"ac", "goal_test": &"ac", "transducer": &"phones", "air_transducer": &"phones", "masking_controls": false,
			"mask_on": false, "mask_db": 0, "mask_ear": "left", "mask_status": &"off", "initial_mask_db": 0, "overmask_limit_db": 0,
			"plateau": {}, "stored_tests": {}}
	var cand: Variant = session.store_candidate(session.ear, session.freq)
	var trail := session.trail(session.ear, session.freq)
	var stored_tests := {}
	for t: StringName in ClinicRules.TESTS:
		stored_tests[String(t)] = {"right": session.stored_thresholds("right", t), "left": session.stored_thresholds("left", t)}
	var masked_now := ClinicRules.test_is_masked(session.test)
	return {
		"patient_id": session.patient.id,
		"ear": session.ear,
		"freq": session.freq,
		"db": session.db,
		"tone_on": session.tone_on,
		"accepting_input": _accepting and not _auto_running,
		"coached": _coached,
		"freqs_available": ClinicRules.test_freqs(session.test),
		"min_db": ClinicRules.MIN_DB,
		"max_db": ClinicRules.max_db_for(session.freq, session.transducer),
		"stored": {"right": session.stored_thresholds("right"), "left": session.stored_thresholds("left")},  # current sheet
		"remaining": session.required_remaining(session.ear),
		"ear_complete": session.is_ear_complete(session.ear),
		"combo": session.combo,
		"presentations": session.presentations,
		"points": session.points,
		"multiplier": ClinicRules.combo_multiplier(session.combo),
		"trail": trail,
		"strokes": trail.size(),
		"par": session.par_for(session.ear, session.freq) if not trail.is_empty() else 0,
		"candidate_db": int(cand) if cand != null else -1,
		"stimulus": ToneGenerator.STIMULUS_NAMES[_stim],
		"hoot_turn": _auto_running,
		"quick_visit": quick_visit,
		# v3 (CONTRACTS.md §4.3): "stored" / "remaining" / "ear_complete" are for the current
		# sheet / the goal sheet; stored_tests has every sheet.
		"test": session.test,
		"goal_test": session.goal_test,
		"transducer": session.transducer,
		"air_transducer": session.air_transducer,
		"masking_controls": _masking_ui,
		"mask_on": session.mask_on,
		"mask_db": session.mask_db,
		"mask_ear": session.masker_ear(),
		"mask_status": session.mask_status() if _masking_ui else &"off",
		"initial_mask_db": session.initial_mask_db() if _masking_ui else 0,
		"overmask_limit_db": session.overmask_limit_db() if _masking_ui else 0,
		"plateau": session.plateau_info() if masked_now else {},
		"stored_tests": stored_tests,
	}


func get_results() -> Dictionary:
	return session.build_results() if session != null else {}


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_HINTS_ACTION):
		_toggle_hints()
		get_viewport().set_input_as_handled()
		return
	if not _player_ok():
		return
	if event.is_action_pressed(&"present_tone"):
		_buttons["tone_button"].show_press(true)
		_hold_add("key")
	elif event.is_action_released(&"present_tone"):
		_buttons["tone_button"].show_press(false)
		_hold_remove("key")
	# v3: the masker pair first (Shift+Up also matches plain "louder")
	elif _masking_ui and event.is_action_pressed(&"mask_louder", true):
		_buttons["mask_louder_button"].flash_press()
		_mask_level(1)
	elif _masking_ui and event.is_action_pressed(&"mask_softer", true):
		_buttons["mask_softer_button"].flash_press()
		_mask_level(-1)
	elif _masking_ui and event.is_action_pressed(&"toggle_mask"):
		_buttons["mask_toggle_button"].flash_press()
		_toggle_mask()
	elif _masking_ui and event.is_action_pressed(&"transducer_bone"):
		_buttons["transducer_button"].flash_press()
		_set_transducer(&"bone")
	elif _masking_ui and event.is_action_pressed(&"transducer_air"):
		_buttons["transducer_button"].flash_press()
		_set_transducer(session.air_transducer)
	elif event.is_action_pressed(&"louder", true):
		_buttons["louder_button"].flash_press()
		_level(1)
	elif event.is_action_pressed(&"softer", true):
		_buttons["softer_button"].flash_press()
		_level(-1)
	elif event.is_action_pressed(&"freq_up", true):
		_buttons["freq_up_button"].flash_press()
		_freq(1)
	elif event.is_action_pressed(&"freq_down", true):
		_buttons["freq_down_button"].flash_press()
		_freq(-1)
	elif event.is_action_pressed(&"store"):
		_buttons["store_button"].flash_press()
		_store(false)
	elif event.is_action_pressed(&"no_response"):
		_buttons["no_response_button"].flash_press()
		_store(true)
	elif event.is_action_pressed(&"ear_right"):
		_buttons["ear_right_button"].flash_press()
		_set_ear("right")
	elif event.is_action_pressed(&"ear_left"):
		_buttons["ear_left_button"].flash_press()
		_set_ear("left")
	else:
		return
	get_viewport().set_input_as_handled()


## Player input is live (not before start_test, not after the ear is done, not during Hoot's turn).
func _player_ok() -> bool:
	return _accepting and session != null and not _auto_running


func _hold_add(src: String) -> void:
	var was := not _hold.is_empty()
	_hold[src] = true
	if not was:
		_tone_down()


func _hold_remove(src: String) -> void:
	if not _hold.has(src):
		return
	_hold.erase(src)
	if _hold.is_empty():
		_tone_up()


func _tone_down() -> void:
	if not _accepting or session == null or session.tone_on:
		return
	session.tone_down()
	_tone.set_stimulus(_stim)
	_tone.start_tone(session.ear, session.freq, session.db)
	Sfx.play(&"thunk", 1.0, -8.0)
	_fx.clear_speech()  # Gus never talks over a beep
	_dance.clear()
	_dance_key = ""
	_booth.tone_ear = session.ear
	Events.tone_started.emit(session.ear, session.freq, session.db)
	_refresh()
	_coach_update()


func _tone_up() -> void:
	if session == null or not session.tone_on:
		return
	var dur := session.time - session.tone_start_t
	session.tone_up()
	_tone.stop_tone()
	Events.tone_stopped.emit(session.ear, session.freq, session.db, dur)
	_refresh()
	_coach_update()


func _level(direction: int) -> void:
	if not _accepting:
		return
	if session.tone_on:
		_lcd.deny()
		Sfx.play(&"error", 1.2, -12.0)
		Hoot.say_once("tip_level_during_tone", "Let go of the beep first, then change the level.", Hoot.NORMAL, "tone_button")
		return
	if session.step_level(direction):
		Sfx.play(&"click", 1.0 + direction * 0.1, -4.0)
	else:
		_lcd.deny()
		Sfx.play(&"error", 1.2, -12.0)
	_refresh()
	_coach_update()


## (v3) Masker dial one step up (+1) / down (-1). Works with the noise off (preset).
func _mask_level(direction: int) -> void:
	if not _accepting or not _masking_ui or session == null:
		return
	if session.tone_on:
		_lcd.deny()
		Hoot.say_once("tip_level_during_tone", "Let go of the beep first, then change the level.", Hoot.NORMAL, "tone_button")
		return
	if session.step_mask(direction):
		Sfx.play(&"click", 0.8 + direction * 0.08, -6.0)
	else:
		_lcd.deny()
		Sfx.play(&"error", 1.2, -12.0)
	_refresh()
	_coach_update()


## (v3) Masking noise on / off (M).
func _toggle_mask() -> void:
	if not _accepting or not _masking_ui or session == null:
		return
	if session.tone_on:
		_lcd.deny()
		return
	if session.toggle_mask():
		Sfx.play(&"click", 0.7 if session.mask_on else 0.6, -4.0)
	_refresh()
	_coach_update()


## (v3) Air (A) or bone (B).
func _set_transducer(tr: StringName) -> void:
	if not _accepting or not _masking_ui or session == null:
		return
	if session.tone_on:
		_lcd.deny()
		return
	if session.set_transducer(tr):
		Sfx.play(&"thunk", 1.3 if tr == &"bone" else 1.1, -8.0)
		Events.transducer_changed.emit(session.transducer, session.ear)
	_refresh()
	_coach_update()


## (v3) Keep the masking noise, the booth squiggles and Events.masker_changed in step with the
## session (called from _refresh()). The noise only plays while the AudiOtron takes input.
func _sync_masker() -> void:
	if session == null or _tone == null:
		return
	var on := session.mask_on and _accepting
	var me := session.masker_ear()
	if on:
		_tone.start_masker(me, session.freq, session.mask_db)
	else:
		_tone.stop_masker()
	var key: Array = [on, me, session.freq, session.mask_db]
	if key != _masker_key:
		_masker_key = key
		Events.masker_changed.emit(me, session.freq, session.mask_db, on)
	_booth.noise_ear = me if on else ""


func _freq(direction: int) -> void:
	if not _accepting:
		return
	if session.tone_on:
		_lcd.deny()
		return
	if session.step_freq(direction):
		Sfx.play(&"click", 0.85 + 0.05 * ClinicRules.AC_FREQS.find(session.freq), -4.0)
	_refresh()
	_coach_update()


func _jump_freq(f: int) -> void:
	if not _accepting or session.tone_on:
		return
	if session.set_freq(f):
		Sfx.play(&"click", 0.85 + 0.05 * ClinicRules.AC_FREQS.find(f), -4.0)
		_refresh()
		_coach_update()


func _set_ear(e: String) -> void:
	if not _accepting:
		return
	if e != _ear:
		var b: AoButton = _buttons["ear_right_button" if e == "right" else "ear_left_button"]
		b.wiggle()
		Hoot.say_once("tip_ear_locked_" + _ear, "One ear at a time: finish the %s ear first!" % _ear, Hoot.NORMAL, "ear_%s_button" % _ear)
		return
	if session.set_ear(e):
		_refresh()


func _store(no_response: bool) -> void:
	if not _accepting or session == null:
		return
	if session.tone_on:
		_lcd.deny()
		return
	if session.time - _last_store_t < STORE_DEBOUNCE_S:
		return  # a double tap of S / Enter right after a stamp
	if session.measurement(session.ear, session.freq).is_empty():
		# nothing to stamp yet at this pitch (an accidental second S would stamp the next one)
		_lcd.deny()
		Sfx.play(&"error", 1.2, -12.0)
		_tip(&"store_empty", "Beep first, then store!", "tone_button")
		return
	if no_response:
		session.store_no_response()
	else:
		session.store()
	_refresh()


func _cycle_stimulus() -> void:
	_stim = (_stim + 1) % ToneGenerator.STIMULUS_NAMES.size()
	_tone.set_stimulus(_stim)
	Sfx.play(&"click", 1.3, -4.0)
	_refresh()


func _toggle_hints() -> void:
	Game.set_setting("show_key_hints", not bool(Game.settings.get("show_key_hints", true)))
	Sfx.play(&"click", 1.1, -4.0)


func _toggle_key_style() -> void:
	Game.set_key_style("affinity" if Game.get_key_style() == "otosuite" else "otosuite")
	Sfx.play(&"click", 1.2, -4.0)
	var swapped := Game.get_key_style() == "affinity"
	_fx.callout("Up = SOFTER" if swapped else "Up = LOUDER", _buttons["style_toggle"].get_global_rect().get_center() + Vector2(-150, -112), Palette.SUNNY, 34, "arrow keys swapped" if swapped else "default arrows", -3.0, 1.6)


## Ask Hoot: one hint about the next textbook move (3 feathers per patient).
func _ask_hoot() -> void:
	if not _player_ok():
		return
	var b: AoButton = _buttons["hint_button"]
	if _feathers <= 0:
		b.wiggle()
		Hoot.say("Out of feathers! Trust the dance: heard = down 10, missed = up 5.", Hoot.HIGH)
		return
	_feathers -= 1
	var tip := _coach_text(session.recommended_action())
	Hoot.say(tip[0] if tip[0] != "" else "Watch his hand... give him a moment.", Hoot.HIGH, tip[1], "", 7.0)
	Sfx.play(&"chirp", 1.2, -6.0)
	_refresh_keys()


func _ensure_hint_action() -> void:
	if InputMap.has_action(TOGGLE_HINTS_ACTION):
		return
	InputMap.add_action(TOGGLE_HINTS_ACTION)
	var ev := InputEventKey.new()
	ev.keycode = KEY_H
	ev.device = -1
	InputMap.action_add_event(TOGGLE_HINTS_ACTION, ev)


# ---------------------------------------------------------------- session callbacks

func _on_responded(ear: String, freq: int, db: int, related: bool) -> void:
	_booth.flash_press(ear)
	_fx.burst(_booth.lamp_global_position(), Palette.ear_color(ear), 10, 230.0)
	_fx.burst(_booth.lamp_global_position(), Palette.PRESS_LIME, 6, 160.0)
	Sfx.play(&"pop", 1.25 if related else 0.9, -6.0)
	if related:
		# the answer lands where the player is looking: beside the TONE pad and on the trail
		_fx.chip("HEARD!", _buttons["tone_button"].get_global_rect().get_center() + Vector2(0, -66), Palette.PRESS_LIME, Palette.INK, 20)
		_fx.chip("HEARD!", _lcd.last_dot_global() + Vector2(0, -26), Palette.PRESS_LIME, Palette.INK, 14, 0.8)
	Events.patient_responded.emit(ear, freq, db, related)
	_refresh()


func _on_presentation_closed(_e: String, _f: int, rec: Dictionary) -> void:
	if not bool(rec.get("responded", false)):
		# a miss: a grey puff where the "HEARD!" would have been
		_fx.chip("...", _buttons["tone_button"].get_global_rect().get_center() + Vector2(0, -66), Color("#d9d3e3"), Palette.INK_SOFT, 20, 0.8)
		_fx.chip("...", _lcd.last_dot_global() + Vector2(0, -24), Color("#d9d3e3"), Palette.INK_SOFT, 13, 0.7)
	_refresh()
	_coach_update()


func _on_reaction(kind: StringName, data: Dictionary) -> void:
	Events.patient_reaction.emit(kind, data)
	if EMOTES.has(kind):
		_booth.emote(EMOTES[kind])
	if kind in PUNCH_KINDS and not _auto_running:
		_punch_in(kind)
	# v3 gags (visual only)
	var bc := _booth.get_global_rect().get_center()
	match kind:
		&"cross_heard":
			if session != null and session.time - _ghost_t > 1.2:
				_ghost_t = session.time
				var via := String(data.get("via", "left"))
				if _auto_running:
					_fx.chip("boo!", bc + Vector2(0, -40), Color("#efeaf7"), Palette.PLUM, 16, 0.7)
				else:
					_fx.callout("BOO!", bc + Vector2(0, 40), Color("#efeaf7"), 40, "the Ghost: the %s cochlea heard it" % via.to_upper(), 6.0, 1.3)
		&"tickle":
			if not _auto_running:
				_fx.chip("hee hee! it tickles", bc + Vector2(0, 70), Palette.SUNNY, Palette.INK, 16, 1.1)
		&"overmasked":
			if not _auto_running:
				Events.screen_shake.emit(0.3, 0.25)
				_fx.callout("TOO MUCH NOISE!", bc + Vector2(80, 60), Palette.CORAL, 34, "it leaks back into the test ear", -5.0, 1.5)


## Booth-cam punch-in: the little booth window zooms over the right ear card for a beat so the
## big gags (hair blast, squint, groove, false alarm, pointing the wrong way) can't be missed.
func _punch_in(kind: StringName) -> void:
	if session == null or session.time - _punch_t < 2.5:
		return
	_punch_t = session.time
	var big := PUNCH_SCALE if not bool(Game.settings.get("reduced_motion", false)) else 1.6
	if _punch_tween != null and _punch_tween.is_valid():
		_punch_tween.kill()
	_booth.pivot_offset = Vector2.ZERO
	_booth.z_index = 10
	_punch_tween = create_tween()
	_punch_tween.tween_property(_booth, "scale", Vector2.ONE * big, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_interval(PUNCH_HOLD_S)
	_punch_tween.tween_property(_booth, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_punch_tween.tween_callback(func() -> void: _booth.z_index = 0)
	var center := _booth.get_global_rect().position + _booth.size * big * Vector2(0.5, 0.42)
	get_tree().create_timer(0.2, false).timeout.connect(func() -> void:
		_fx.stars(center, 10, Palette.SUNNY)
		if kind == &"too_loud_blast":
			_fx.splash(center + Vector2(60, 40), 18)
			_fx.callout("WHOA!", center + Vector2(0, -150), Palette.CORAL, 46, "too loud for his comfort", -6.0, 1.3))


func _on_technique(kind: StringName, data: Dictionary) -> void:
	Events.technique_event.emit(kind, data)
	var auto := bool(data.get("auto", false)) or _auto_running
	match kind:
		&"good_start", &"textbook_step":
			var n := int(data.get("combo", 0))
			Sfx.play_note(523.25 * pow(2.0, minf(n, 24) / 12.0), -14.0 if not auto else -20.0)
			if auto:
				return
			_clean_steps += 1
			Hoot.note_clean_use(&"hw_step")
			if int(data.get("points", 0)) > 0:
				_fx.callout("+%d" % int(data["points"]), _buttons["tone_button"].get_global_rect().get_center() + Vector2(90, -64), Palette.MINT, 22, "", 0.0, 0.7)
			if n >= 3 and (n == 3 or n == 6 or n == 10 or n % 5 == 0):
				var word := TEXTBOOK_CALLOUTS[(n / 3) % TEXTBOOK_CALLOUTS.size()]
				var at := _buttons["tone_button"].get_global_rect().get_center() + Vector2(0, -118)
				_fx.callout(word, at, Palette.MINT, 38, "", randf_range(-6.0, 6.0))
				_fx.stars(at, 8, Palette.SUNNY)
				Sfx.play(&"ding", 1.0 + 0.04 * minf(n, 20), -8.0)
		&"missed", &"false_alarm":
			pass  # a puff / the booth emote; the on-the-beat lesson is "rhythmic"
		&"interoctave_needed":
			if not auto:
				Hoot.say_once("tip_interoctave_%s" % data["ear"], "Big jump between neighbours! The plan now includes %d Hz in between." % int(data["freq"]), Hoot.HIGH, "")
			Sfx.play(&"sparkle", 1.0, -8.0)
		&"retest_ok":
			var e := String(data["ear"])
			var card: AoEarCard = _cards[e]
			var plotted := int(data.get("plotted_db", -999))
			if plotted > -999:
				card.audiogram.set_point(e, 1000, plotted, false, true)  # the better of the two
			var p := card.audiogram.get_point_global_position(e, 1000)
			_fx.ring(p, Palette.MINT, 50.0)
			if not auto:
				_fx.callout("Retest matches!", p + Vector2(0, -50), Palette.MINT, 30, "within %d dB: the better one counts" % maxi(int(data.get("diff", 0)), 0), 3.0)
			Sfx.play(&"sparkle", 1.0, -6.0)
		&"birdie", &"eagle", &"albatross", &"store_ok":
			pass  # celebrated in _on_stored
		&"too_loud":
			if auto:
				return
			if int(data.get("comfort_loss", 0)) > 0:
				Game.lose_comfort("too_loud")
			Events.screen_shake.emit(0.6, 0.35)
			Sfx.play(&"boing", 1.0, -6.0)
			Hoot.say_once("tip_too_loud", String(data.get("message", "")), Hoot.URGENT, "softer_button")
		&"marathon":
			if auto:
				return
			Game.lose_comfort("marathon")
			Hoot.say_once("tip_marathon", String(data.get("message", "")), Hoot.HIGH, "store_button")
		&"short_gap":
			Hoot.say_once("tip_short_gap", String(data.get("message", "")), Hoot.HIGH, "tone_button")
		&"plateau_step":
			if auto or not bool(data.get("found", false)) and int(data.get("steps", 0)) <= 0:
				return
			var at2 := _lcd.last_dot_global() + Vector2(0, -26)
			if bool(data.get("found", false)):
				_fx.chip("PLATEAU!", at2, Palette.PRESS_LIME, Palette.INK, 16, 1.0)
			else:
				_fx.chip("%d/%d" % [int(data["steps"]), int(data["needed"])], at2, Palette.SUNNY, Palette.INK, 14, 0.8)
			Sfx.play_note(392.0 * pow(2.0, int(data.get("steps", 0)) / 6.0), -12.0)
		&"plateau_found":
			if auto:
				return
			var lc := _lcd.get_global_rect()
			_fx.callout("FLAT LINE!", Vector2(lc.end.x - 150.0, lc.end.y + 30.0), Palette.MINT, 40, "the threshold ignores more noise: plateau", -4.0, 1.6)
			Sfx.play(&"sparkle", 1.1, -6.0)
			_tip(kind, String(data.get("message", "")), "store_button")
		_:
			if auto:
				return
			var msg := String(data.get("message", ""))
			var error := kind in ERROR_KINDS
			if error and not _coach_active:
				Sfx.play(&"sad_trombone", 1.0, -12.0)
			if msg != "" and not (_coach_active and error):
				_tip(kind, msg, _target_for(kind, data))


## Show a technique tip. Everyday slips repeat (with a cooldown); the rest fire once per visit.
func _tip(kind: StringName, msg: String, target: String) -> void:
	if kind in REPEAT_TIPS or kind == &"store_empty":
		var cd := TIP_COOLDOWN_S if _clean_steps < TIP_QUIET_AFTER_STEPS else TIP_COOLDOWN_LATE_S
		var now := session.time if session != null else 0.0
		if now - float(_tip_last.get(kind, -1000.0)) < cd:
			return
		_tip_last[kind] = now
		Hoot.say(msg, Hoot.HIGH, target)
	else:
		Hoot.say_once("tip_" + String(kind), msg, Hoot.HIGH, target)


func _target_for(kind: StringName, data: Dictionary) -> String:
	match kind:
		&"wrong_step":
			return "softer_button" if bool(data.get("prev_heard", false)) else "louder_button"
		&"start_too_high":
			return "softer_button"
		&"store_without_bracket", &"store_wrong_level", &"tone_too_short", &"tone_too_long", &"rhythmic":
			return "tone_button"
		&"start_not_1k", &"missed_retest":
			return "freq_down_button"
		&"nr_too_early":
			return "louder_button"
		&"mask_too_low", &"undermasked":
			return "mask_louder_button"
		&"overmasked":
			return "mask_softer_button"
		&"mask_wrong_step", &"mask_start", &"store_no_plateau", &"cross_hearing", &"vibrotactile":
			return "tone_button"
	return ""


func _on_combo(n: int, mult: int) -> void:
	var before := _status.multiplier
	Events.combo_changed.emit(n, mult)
	_status.set_combo(n, mult)
	if mult > before and n > 0:
		var at := _status.get_global_rect().position + Vector2(140, 116)
		_fx.callout("x%d COMBO!" % mult, at + Vector2(0, 40), Palette.SELECT_ORANGE, 30, "", -6.0, 1.1)
		Sfx.play(&"sparkle", 0.9 + 0.1 * mult, -8.0)
	elif n == 0 and before > 1:
		Sfx.play(&"whoosh", 0.7, -10.0)
	_refresh()


func _on_stored(ear: String, freq: int, db: int, info: Dictionary) -> void:
	var card: AoEarCard = _cards[ear]
	var no_resp := bool(info.get("no_response", false))
	var is_retest := bool(info.get("retest", false))
	var by_hoot := bool(info.get("by_hoot", false))
	_last_store_t = session.time
	var test := StringName(String(info.get("test", "ac")))
	if not is_retest:
		card.audiogram.set_point(ear, freq, db, no_resp, true, test)
	var at := card.audiogram.get_global_transform_with_canvas() * (Vector2(card.audiogram.freq_to_x(freq), card.audiogram.db_to_y(db)) + UiDraw.symbol_offset(ear, test, 17.0))
	Sfx.play(&"stamp", randf_range(0.95, 1.05), -2.0 if not by_hoot else -12.0)
	# hit-stop: the stamp lands, freezes for a beat, then the card jolts and ink flies
	get_tree().create_timer(Audiogram.STAMP_IN_S, false).timeout.connect(func() -> void:
		if not by_hoot:
			Juice.shake(card, 6.0, 0.18)
		_fx.burst(at, Palette.ear_color(ear), 12 if not by_hoot else 5, 260.0, 5.0)
		_fx.ring(at, Palette.ear_color(ear), 46.0))
	if not by_hoot:
		get_tree().create_timer(Audiogram.STAMP_IN_S + Audiogram.HIT_STOP_S + 0.05, false).timeout.connect(func() -> void:
			Sfx.play(&"pen", 1.0, -8.0)
			Sfx.play_note(Sfx.audiogram_note_hz(freq), -8.0))
	Events.threshold_stored.emit(ear, freq, db, info)
	if by_hoot:
		_fx.chip("NR" if no_resp else "%d dB" % db, at + Vector2(0, -30), Palette.HOOT_FACE, Palette.INK, 14, 0.9)
	else:
		_celebrate_stamp(ear, freq, at, info)
	if _coach_active:
		_coach_active = false
		if _coach_tip >= 0:
			Hoot.dismiss(_coach_tip)
		_coach_tip = -1
		var nxt: Array[int] = session.required_remaining(ear)
		var where := ("%d Hz" % nxt[0]) if not nxt.is_empty() else "the next pitch"
		Hoot.say("Stamped! On to %s. Same dance, now you lead!" % where, Hoot.HIGH, "", "", 5.0)
	elif not by_hoot and freq == 4000 and not _told_3k6k and test == &"ac":
		_told_3k6k = true
		Hoot.say("Many clinics also test 3000 and 6000 Hz: fitting formulas use them.", Hoot.LOW, "", "tip_3k6k", 5.0)
	_refresh()
	if session.is_ear_complete(_ear) and ear == _ear and not _finishing:
		_complete_ear(ear)
		return
	if by_hoot or ear != _ear:
		return
	_player_stamps += 1
	if _player_stamps % 2 == 0:
		_gus_quip_later()
	if not _coached and quick_visit and not _auto_done_ears.has(_ear):
		_solo_stamps += 1
		if _solo_stamps >= _solo_limit:
			_start_hoot_turn()
	elif _coached and quick_visit and _plan.has("hoot_turn_after") and not _auto_done_ears.has(_ear):
		# v3: a coached Day 2 test: the coached stamp counts towards Hoot's turn too
		_solo_stamps += 1
		if _solo_stamps >= _solo_limit:
			_start_hoot_turn()


## The golf callout, sub-line and fanfare for a player's stamp (fair golf: Gus's wobbles never
## cost a bogey, a technique slip never earns a birdie).
func _celebrate_stamp(_ear_s: String, _freq: int, at: Vector2, info: Dictionary) -> void:
	var golf: StringName = info.get("golf", &"par")
	var raw: StringName = info.get("golf_raw", golf)
	var errs: Array = info.get("errors", [])
	var clean := bool(info.get("clean", errs.is_empty()))
	var strokes := int(info.get("strokes", 0))
	var par := int(info.get("par", 0))
	var word := String(golf).replace("_", " ").capitalize() + "!"
	var sub := "%d beeps, par %d" % [strokes, par]
	var col: Color = GOLF_COLORS.get(golf, Palette.PAPER)
	var big := golf in [&"birdie", &"eagle", &"albatross"]
	if clean and raw in [&"bogey", &"double_bogey", &"triple_bogey"]:
		sub = "Gus wobbled: +%d on him, not you" % maxi(1, strokes - par)
	elif not clean and raw in [&"birdie", &"eagle", &"albatross"]:
		sub = "birdie pace, but a slip on the way"
	if not errs.is_empty():
		word = "Oops!"
		col = Palette.PAPER
		sub = STORE_ERROR_SUBS.get(StringName(String(errs[0])), "check Hoot's tip")
		big = false
	_fx.callout(word, at + Vector2(0, -64), col, 50 if big else 38, sub, randf_range(-7.0, 3.0), 1.6)
	if golf in [&"eagle", &"albatross"]:
		_fx.confetti(at, 30)
		_fx.stars(at, 10)
		Sfx.play(&"fanfare", 1.15, -8.0)
	elif golf == &"birdie":
		_fx.confetti(at, 16)
		Sfx.play(&"chirp", 1.0, -6.0)
	if int(info.get("points", 0)) > 0:
		_fx.callout("+%d" % int(info["points"]), at + Vector2(0, 40), Palette.SUNNY, 26, "", 0.0, 1.1)
	# Hoot cheers the good holes (not over a tip, not while coaching)
	if errs.is_empty() and not _coach_active and HOOT_GOLF_QUIPS.has(golf):
		var say := big
		if golf == &"par":
			_par_count += 1
			say = _par_count % 3 == 0
		if say and not Hoot.is_showing():
			var lines: Array = HOOT_GOLF_QUIPS[golf]
			Hoot.say(String(lines[randi() % lines.size()]), Hoot.LOW, "", "", 3.5)


## Gus thinks out loud between beeps: a paper speech bubble under the booth window, a beat after
## the stamp. Never over a tone (a new beep clears it) and never during Hoot's turn.
func _gus_quip_later() -> void:
	if _quip_order.is_empty():
		return
	var idx: int = _quip_order[(_player_stamps / 2 - 1) % _quip_order.size()]
	get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
		if session == null or session.tone_on or not _player_ok() or not is_inside_tree():
			return
		var g := _booth.get_global_rect()
		var r := Rect2(Vector2(g.position.x + 14.0, g.end.y + 10.0), Vector2(g.size.x - 4.0, 60.0))
		_fx.speech(GUS_QUIPS[idx], r, Vector2(g.get_center().x - 30.0, g.end.y - 18.0), 3.4))


func _complete_ear(ear: String) -> void:
	_finishing = true
	_accepting = false
	if _auto_running:
		_end_hoot_turn()
	for src: String in _hold.keys():
		_hold_remove(src)
	_hold.clear()
	_tone.stop_tone()
	_buttons["tone_button"].cancel_hold()
	if _coach_tip >= 0:
		Hoot.dismiss(_coach_tip)
	_dance.clear()
	_fx.clear_speech()
	var results := session.build_results()
	var ear_res: Dictionary = results["ears"][ear]
	Events.ear_completed.emit(ear, ear_res)
	var card: AoEarCard = _cards[ear]
	card.flash()
	_refresh()
	await get_tree().create_timer(0.5, false).timeout
	Sfx.play(&"fanfare", 1.0, -6.0)
	var center := card.get_global_rect().get_center()
	_fx.confetti(center + Vector2(0, -60), 40, 420.0)
	var golf := int(ear_res.get("golf", 0))
	var golf_txt := "even par" if golf == 0 else ("%d under par" % -golf if golf < 0 else "%d over par" % golf)
	var pr := session.ear_progress(ear)
	var parts: Array[String] = ["%d stamps" % pr[0], golf_txt]
	var birdies := int(ear_res.get("birdies", 0))
	if birdies > 0:
		parts.append("%d birdie%s!" % [birdies, "" if birdies == 1 else "s"])
	var hoot_n := int(ear_res.get("hoot_holes", 0))
	if hoot_n > 0:
		parts.append("Hoot did %d" % hoot_n)
	_fx.callout(String(_plan.get("done_title", "%s EAR DONE!" % ear.to_upper())), center + Vector2(0, -20), Palette.SUNNY, 52, ", ".join(parts), -3.0, 2.6)
	var melody := card.audiogram.play_melody(ear, 0.2)
	await get_tree().create_timer(melody + 1.4, false).timeout
	results = session.build_results()
	Events.audiometry_finished.emit(results)
	test_finished.emit(results)


# ---------------------------------------------------------------- Hoot's turn (quick visit)

## Quick visit: after QUICK_SOLO_HOLES solo stamps Hoot finishes the ear by the textbook at x8.
## Scoring is off (his stamps never count for or against the player); input is locked.
func _start_hoot_turn() -> void:
	if _auto_running or _finishing or session == null or session.is_ear_complete(_ear):
		return
	for src: String in _hold.keys():
		_hold_remove(src)
	_buttons["tone_button"].cancel_hold()
	_auto_running = true
	_ff_on = false
	session.scoring = false
	_coach_active = false
	_fx.clear_speech()
	for id: String in ["tone_button", "softer_button", "louder_button", "store_button"] + MASK_BUTTONS:
		(_buttons[id] as AoButton).beckon = false
	_base_time_scale = Engine.time_scale
	Hoot.say(String(_plan.get("hoot_turn_text", "Nice work! My turn: I'll finish this ear at 8x. Watch the dance!")), Hoot.HIGH, "", "", 2.4)
	_ff_banner.visible = true
	_hoot_spot.queue_redraw()
	_refresh()
	await get_tree().create_timer(1.8, false).timeout
	if not _auto_running or not is_inside_tree():
		return
	_ff_on = true
	if not get_tree().paused:
		Engine.time_scale = _ff_scale()
	_auto.run(self, session, _ear)


func _end_hoot_turn() -> void:
	if not _auto_running:
		return
	_auto_running = false
	_ff_on = false
	_auto.stop()
	Engine.time_scale = _base_time_scale
	if session != null:
		session.scoring = true
		if _hold.has("auto"):
			_hold_remove("auto")
	_auto_done_ears[_ear] = true
	if _ff_banner != null:
		_ff_banner.visible = false
	if _hoot_spot != null:
		_hoot_spot.queue_redraw()
	if is_inside_tree():
		_buttons["tone_button"].show_press(false)


## The pause menu must not run at x8: drop to normal speed while paused.
func _on_pause_toggled(paused: bool) -> void:
	if not _auto_running or not _ff_on:
		return
	Engine.time_scale = _base_time_scale if paused else _ff_scale()


## x8 for a player; an autoplay run that is already fast-forwarded only goes up to x8 overall
## (a coarser clock would make every simulated answer land a frame late).
func _ff_scale() -> float:
	return maxf(_base_time_scale, AoAutoTester.SPEED)


func _auto_tone(down: bool) -> void:
	if not _auto_running:
		return
	_buttons["tone_button"].show_press(down)
	if down:
		_hold_add("auto")
	else:
		_hold_remove("auto")


func _auto_level(d: int) -> void:
	if not _auto_running:
		return
	(_buttons["louder_button" if d > 0 else "softer_button"] as AoButton).flash_press()
	_level(d)


func _auto_jump(f: int) -> void:
	if _auto_running:
		_jump_freq(f)


func _auto_store(nr: bool) -> void:
	if not _auto_running:
		return
	(_buttons["no_response_button" if nr else "store_button"] as AoButton).flash_press()
	_store(nr)


func _auto_mask_toggle() -> void:
	if not _auto_running:
		return
	(_buttons["mask_toggle_button"] as AoButton).flash_press()
	_toggle_mask()


func _auto_mask_level(d: int) -> void:
	if not _auto_running:
		return
	(_buttons["mask_louder_button" if d > 0 else "mask_softer_button"] as AoButton).flash_press()
	_mask_level(d)


func _auto_transducer(tr: StringName) -> void:
	if not _auto_running:
		return
	(_buttons["transducer_button"] as AoButton).flash_press()
	_set_transducer(tr)


func _draw_ff_banner() -> void:
	var r := Rect2(Vector2.ZERO, _ff_banner.size)
	AoDraw.rbox(_ff_banner, Rect2(r.position + Vector2(0, 4), r.size), Color(Palette.INK, 0.3), 18)
	AoDraw.rbox(_ff_banner, r, Palette.HOOT_FACE, 18, 3, Palette.INK)
	var t := Time.get_ticks_msec() / 1000.0
	for i in 3:
		var a := 0.35 + 0.65 * maxf(0.0, sin(t * 7.0 - i * 0.9))
		UiDraw.arrow(_ff_banner, Vector2(r.end.x - 70.0 + i * 16.0, r.get_center().y), 12.0, Vector2.RIGHT, Color(Palette.INK, a))
	AoDraw.text_l(_ff_banner, Vector2(18.0, r.get_center().y), "HOOT'S TURN  x8", 20, Palette.INK, AoDraw.FONT_BOLD)


## Light the dance-card chip that matches the textbook's next move.
func _update_dance() -> void:
	if _dance == null or session == null:
		return
	var recs := session.measurement(session.ear, session.freq)
	var any_hit := false
	for r: Dictionary in recs:
		if bool(r["responded"]):
			any_hit = true
	_dance.masked = ClinicRules.test_is_masked(session.test)
	_dance.climbing = not any_hit and not _dance.masked
	if recs.is_empty():
		if _dance.lit() >= 0:
			_dance.clear()  # a fresh pitch: nothing to point at until the first answer
		_dance_key = ""
		return
	if session.tone_on:
		return
	var a := session.recommended_action()
	var then_store: bool = a.get("then", &"") == &"store"
	var chip := -1
	match a["action"]:
		&"softer":
			chip = AoDanceCard.CHIP_STORE if then_store else AoDanceCard.CHIP_HEARD
		&"louder", &"no_response":
			chip = AoDanceCard.CHIP_STORE if then_store else AoDanceCard.CHIP_MISSED
		&"store":
			chip = AoDanceCard.CHIP_STORE
		&"mask_louder":
			chip = AoDanceCard.CHIP_HEARD
	if chip < 0:
		return
	var key := "%s:%d:%d:%d" % [session.ear, session.freq, recs.size(), chip]
	if key != _dance_key:
		_dance_key = key
		_dance.pulse(chip)


# ---------------------------------------------------------------- coach (first frequency of a coached ear)

func _coach_update() -> void:
	if not _coach_active or not _accepting or session == null or _auto_running:
		return
	var a := session.recommended_action()
	if a["action"] == &"release":
		return
	var tip := _coach_text(a)
	if tip[0] == "":
		return
	var key: String = tip[2]
	if key == _coach_key:
		return
	_coach_key = key
	if key.begins_with("fam"):
		_familiar_note_done = true
	if _coach_tip >= 0:
		Hoot.dismiss(_coach_tip)
	_coach_tip = Hoot.say(tip[0], Hoot.HIGH, tip[1], "", 0.0)
	for id: String in ["tone_button", "softer_button", "louder_button", "store_button"] + MASK_BUTTONS:
		(_buttons[id] as AoButton).beckon = id == tip[1]


## [text, ghost-hand target, key] for a recommended action. Texts stay under 18 words.
func _coach_text(a: Dictionary) -> Array:
	var recs := session.measurement(session.ear, session.freq)
	var target_db := int(a["target_db"])
	var steps := absi(target_db - session.db) / ClinicRules.LEVEL_STEP_DB
	var times := "once" if steps == 1 else ("twice" if steps == 2 else "%d times" % steps)
	var hits := 0
	for r: Dictionary in recs:
		if bool(r["responded"]):
			hits += 1
	var last_heard := not recs.is_empty() and bool(recs[-1]["responded"])
	var tone_key := _k(&"present_tone")
	var v3 := _coach_text_v3(a, recs, times, last_heard)
	if not v3.is_empty():
		return v3
	match a["action"]:
		&"present":
			if session.last_short:
				return ["Too quick! HOLD %s until the ring turns green." % tone_key, "tone_button", "short%d" % session.presentations]
			if recs.is_empty():
				return ["Hold %s (or the TONE pad) until the ring turns green. Watch his hand!" % tone_key, "tone_button", "present0"]
			return ["Now beep at %d dB: hold %s until the ring is green." % [session.db, tone_key], "tone_button", "present%d" % recs.size()]
		&"wait":
			return ["Watch his hand... give him a moment.", "", "wait%d" % recs.size()]
		&"softer":
			if recs.is_empty():
				return ["Start gently: tap %s down to %d dB." % [_k(&"softer"), target_db], "softer_button", "start_soft%d" % session.db]
			if a.get("then", &"") == &"store":
				return ["Back down to %d dB, the lowest level heard twice going up." % target_db, "softer_button", "to_store%d" % session.db]
			if last_heard and session.db == int(recs[-1]["db"]):
				if hits == 1 and not _familiar_note_done:
					return ["First yes is just the ballpark! Down 10: tap %s %s. Then count yeses going UP." % [_k(&"softer"), times], "softer_button", "fam%d" % session.db]
				return ["He heard %d! Heard means DOWN 10: tap %s %s." % [session.db, _k(&"softer"), times], "softer_button", "down%d_%d" % [recs.size(), session.db]]
			return ["One more tap of %s." % _k(&"softer"), "softer_button", "down%d_%d" % [recs.size(), session.db]]
		&"louder":
			if a.get("then", &"") == &"store":
				return ["Back up to %d dB, the lowest level heard twice going up." % target_db, "louder_button", "to_store%d" % session.db]
			if hits == 0:
				return ["Nothing yet? Climb UP 10 until he hears it: tap %s %s." % [_k(&"louder"), times], "louder_button", "climb%d_%d" % [recs.size(), session.db]]
			if not last_heard and session.db == int(recs[-1]["db"]):
				return ["No hand up. Missed means UP 5: tap %s once." % _k(&"louder"), "louder_button", "up%d_%d" % [recs.size(), session.db]]
			return ["One more tap of %s." % _k(&"louder"), "louder_button", "up%d_%d" % [recs.size(), session.db]]
		&"store":
			return ["Heard twice on the way UP at %d dB: that's threshold! Press %s to STORE." % [session.db, _k(&"store")], "store_button", "store%d" % recs.size()]
		&"no_response":
			return ["No answer even at the maximum. Press %s for no response." % _k(&"no_response"), "no_response_button", "nr%d" % recs.size()]
	return ["", "", ""]


## (v3) Coach lines for the route, the masker and the plateau dance ([] = not a v3 moment).
func _coach_text_v3(a: Dictionary, recs: Array, times: String, last_heard: bool) -> Array:
	var act: StringName = a["action"]
	var masked := ClinicRules.test_is_masked(session.test)
	match act:
		&"transducer":
			if StringName(a.get("target", &"bone")) == &"bone":
				return ["Bone time! Switch the AudiOtron to BONE: press %s." % _k(&"transducer_bone"), "transducer_button", "to_bone"]
			return ["Back to the earphones: press %s for AIR." % _k(&"transducer_air"), "transducer_button", "to_air"]
		&"mask_toggle":
			return ["Turn the masking noise ON with %s. It hisses in the OTHER ear." % _k(&"toggle_mask"), "mask_toggle_button", "mask_on"]
		&"mask_louder", &"mask_softer":
			var tm := int(a.get("target_mask", session.mask_db))
			var n := absi(tm - session.mask_db) / ClinicRules.MASK_STEP_DB
			var ntimes := "once" if n == 1 else ("twice" if n == 2 else "%d times" % n)
			var key := _k(&"mask_louder" if act == &"mask_louder" else &"mask_softer")
			var btn := "mask_louder_button" if act == &"mask_louder" else "mask_softer_button"
			if recs.is_empty():
				var occl := ClinicRules.occlusion_effect(session.freq, session.air_transducer) if session.transducer == &"bone" else 0
				var why := "other ear's air + 10" + (" + %d occlusion" % occl if occl > 0 else "")
				return ["Noise to %d dB (%s): tap %s %s." % [tm, why, key, ntimes], btn, "mask_set%d" % session.mask_db]
			if last_heard:
				return ["Heard through the noise! Plateau dance: noise UP 5, same tone. Tap %s." % key, btn, "mask_up%d_%d" % [recs.size(), session.mask_db]]
			return ["Noise to %d dB: tap %s %s." % [tm, key, ntimes], btn, "mask_to%d_%d" % [recs.size(), session.mask_db]]
	if not masked:
		return []
	match act:
		&"present":
			if recs.is_empty():
				return ["First masked beep: hold %s at %d dB, noise %d." % [_k(&"present_tone"), session.db, session.mask_db], "tone_button", "mpresent0"]
			return ["Beep again: %d dB tone, %d dB noise. Hold %s." % [session.db, session.mask_db, _k(&"present_tone")], "tone_button", "mpresent%d" % recs.size()]
		&"louder":
			if a.get("then", &"") == &"store":
				return ["Back up to %d dB, the plateau level." % int(a["target_db"]), "louder_button", "mto_store%d" % session.db]
			if recs.is_empty():
				return ["Start at the unmasked threshold: tap %s %s." % [_k(&"louder"), times], "louder_button", "mstart%d" % session.db]
			return ["Missed! Masked dance: tone UP 5, same noise. Tap %s." % _k(&"louder"), "louder_button", "mup%d_%d" % [recs.size(), session.db]]
		&"softer":
			if a.get("then", &"") == &"store":
				return ["Back down to %d dB, the plateau level." % int(a["target_db"]), "softer_button", "mto_store%d" % session.db]
			return ["Start at the unmasked threshold: tap %s %s." % [_k(&"softer"), times], "softer_button", "mstart%d" % session.db]
		&"store":
			return ["Flat line! %d dB held through 15 dB more noise. Press %s to STORE." % [session.db, _k(&"store")], "store_button", "mstore%d" % recs.size()]
	return []


func _k(action: StringName) -> String:
	var label := Game.key_label(action)
	return "[%s]" % ("SPACE" if label == "Space" else label)


static func _hz(f: int) -> String:
	return "%d" % f if f < 1000 else ("%dk" % (f / 1000) if f % 1000 == 0 else "%.1fk" % (f / 1000.0))


# ---------------------------------------------------------------- per frame

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _hold.has("mouse"):
		(_buttons["tone_button"] as AoButton).cancel_hold()
		_hold_remove("mouse")


func _process(delta: float) -> void:
	if session != null:
		session.advance(delta)
	if _accepting:
		_sync_bubble_hint()
	if Hoot.is_showing() != _perch_hidden:
		_perch_hidden = Hoot.is_showing()
		_hoot_spot.queue_redraw()
	var on := session != null and session.tone_on
	_tone_glow = move_toward(_tone_glow, 1.0 if on else 0.0, delta * 10.0)
	_lcd.tone_glow = _tone_glow
	_booth.tone_glow = _tone_glow
	var tb: AoButton = _buttons["tone_button"]
	tb.glow = _tone_glow
	tb.hold_s = (session.time - session.tone_start_t) if on else -1.0
	# safety net: a release that never arrived (focus loss, a menu opening mid-hold)
	if _hold.has("key") and not Input.is_action_pressed(&"present_tone"):
		tb.show_press(false)
		_hold_remove("key")
	if _hold.has("mouse") and not tb.is_held():
		_hold_remove("mouse")
	if _ff_banner != null and _ff_banner.visible:
		_ff_banner.queue_redraw()
	var mult := ClinicRules.combo_multiplier(session.combo) if session != null else 1
	var target_flame := 0.0 if session == null or session.combo == 0 else 18.0 + 9.0 * mult
	tb.flame_px = move_toward(tb.flame_px, target_flame, delta * 120.0)
	tb.flame_heat = clampf((mult - 1) / 4.0, 0.0, 1.0)


## Reserve the right-hand spot for Hoot's bubble once the layout has placed it.
func _sync_bubble_hint() -> void:
	if _hoot_spot == null or not _hoot_spot.is_inside_tree():
		return
	var r := _hoot_spot.get_global_rect()
	if r.size.x > 0.0 and r.position != Vector2.ZERO and r != Hoot.bubble_rect_hint:
		Hoot.set_bubble_hint(r)


func _refresh() -> void:
	var st := get_state()
	var e: String = st["ear"]
	var hits: Dictionary = {}
	if session != null and not ClinicRules.test_is_masked(session.test):
		var counts := session.ascending_counts(session.ear, session.freq)
		for lvl: int in counts:
			hits[lvl] = int((counts[lvl] as Array)[0])
	_lcd.update_view({"ear": e, "freq": st["freq"], "db": st["db"], "tone_on": st["tone_on"], "stim": st["stimulus"],
		"trail": st["trail"], "strokes": st["strokes"], "par": st["par"], "hits": hits, "candidate": st["candidate_db"],
		"accepting": st["accepting_input"],
		"transducer": String(st["transducer"]), "test": String(st["test"]), "plateau": st["plateau"],
		"mask": {"enabled": bool(st["masking_controls"]), "on": bool(st["mask_on"]), "db": int(st["mask_db"]), "ear": String(st["mask_ear"]),
			"status": String(st["mask_status"])}})
	for k: String in _cards:
		var card: AoEarCard = _cards[k]
		card.audiogram.cursor_test = StringName(st["test"])
		card.audiogram.max_output_transducer = StringName(st["transducer"]) if StringName(st["transducer"]) == &"bone" else &"phones"
		card.audiogram.set_cursor(int(st["freq"]), int(st["db"]), k == e and bool(st["accepting_input"]))
		if session != null:
			var pr := session.ear_progress(k) if k == _ear or session.goal_test == &"ac" else session.ear_progress(k, &"ac")
			card.set_progress(pr[0], pr[1])
	_status.set_points(int(st["points"]))
	_refresh_quest(st)
	_refresh_mask_buttons(st)
	_sync_masker()
	if not _coach_active:
		for id: String in ["tone_button", "softer_button", "louder_button"] + MASK_BUTTONS:
			(_buttons[id] as AoButton).beckon = false
		var cand := int(st["candidate_db"])
		(_buttons["store_button"] as AoButton).beckon = cand >= 0 and cand == int(st["db"]) and not bool(st["tone_on"]) and bool(st["accepting_input"])
	_update_dance()
	Events.audiometer_state_changed.emit(st)


## (v3) Faces and labels of the MASKING / ROUTE buttons.
func _refresh_mask_buttons(st: Dictionary) -> void:
	if not _masking_ui:
		return
	var tb: AoButton = _buttons["mask_toggle_button"]
	var on := bool(st["mask_on"])
	tb.text = "MASK ON" if on else "MASK OFF"
	tb.face_color = Palette.PLUM.lightened(0.35) if on else Palette.CREAM
	var rb: AoButton = _buttons["transducer_button"]
	var bone := StringName(st["transducer"]) == &"bone"
	rb.text = "BONE" if bone else "AIR"
	rb.face_color = Palette.SKY if bone else Palette.PAPER
	rb.action = &"transducer_air" if bone else &"transducer_bone"
	for b: AoButton in [tb, rb]:
		b.queue_redraw()


func _refresh_quest(st: Dictionary) -> void:
	if session == null:
		_quest.set_plan(_ear, [], 0, 7)
		return
	_quest.title = QUEST_TITLES.get(session.goal_test, "TEST PLAN")
	_quest.test = session.goal_test
	if session.goal_test != &"ac":
		# v3: bone and masked plans list their own frequencies
		var g := session.goal_test
		var st_g: Dictionary = (session.sheet(g)["stored"] as Dictionary)[_ear]
		var rem_g := session.required_remaining(_ear)
		var cur_g: int = rem_g[0] if not rem_g.is_empty() else -1
		if session.ear == _ear and rem_g.has(session.freq):
			cur_g = session.freq
		var items_g: Array = []
		for f: int in session.sheet_required(_ear, g):
			items_g.append(_quest_item(f, st_g, false, cur_g == f))
		var pr_g := session.ear_progress(_ear)
		_quest.set_plan(_ear, items_g, pr_g[0], pr_g[1])
		return
	var e := _ear
	var st_e: Dictionary = session.stored[e]
	var need := ClinicRules.required_interoctaves(session.stored_thresholds(e))
	var rem := session.required_remaining(e)
	var cur_f: int = rem[0] if not rem.is_empty() else -1
	if session.ear == e and rem.has(session.freq):
		cur_f = session.freq  # the player jumped ahead: light the token they are on
	var cur_is_retest := cur_f == 1000 and st_e.has(1000)
	var items: Array = []
	for f: int in [1000, 1500, 2000, 3000, 4000, 6000, 8000]:
		if ClinicRules.is_octave(f) or need.has(f):
			items.append(_quest_item(f, st_e, false, cur_f == f and not cur_is_retest))
	var rt: Dictionary = session.retest[e]
	items.append({"freq": 1000, "label": "1k R", "done": not rt.is_empty(), "db": int(rt.get("stored_db", 0)), "current": cur_is_retest, "retest": true, "nr": false})
	for f: int in [750, 500, 250]:
		if ClinicRules.is_octave(f) or need.has(f):
			items.append(_quest_item(f, st_e, false, cur_f == f))
	var pr := session.ear_progress(e)
	_quest.set_plan(e, items, pr[0], pr[1])


func _quest_item(f: int, st_e: Dictionary, retest: bool, current: bool) -> Dictionary:
	var done := st_e.has(f)
	return {"freq": f, "label": _hz(f), "done": done, "db": int(st_e[f]["stored_db"]) if done else 0,
		"current": current, "retest": retest, "nr": bool(st_e[f]["no_response"]) if done else false}


func _refresh_keys() -> void:
	var show := bool(Game.settings.get("show_key_hints", true))
	for b: AoButton in _buttons.values():
		b.show_keycap = show
		b.queue_redraw()
	var style: AoButton = _buttons.get("style_toggle")
	if style != null:
		style.text = "Up = SOFTER" if Game.get_key_style() == "affinity" else "Up = LOUDER"
	var keys: AoButton = _buttons.get("keys_toggle")
	if keys != null:
		keys.text = "Keys: ON" if show else "Keys: OFF"
		keys.face_color = Palette.MINT if show else Palette.CREAM
	var hint: AoButton = _buttons.get("hint_button")
	if hint != null:
		hint.text = "Ask Hoot x%d" % _feathers
		hint.locked = _feathers <= 0
	if session != null and _coach_active:
		_coach_key = ""
		_coach_update()


func _on_screen_shake(strength: float, duration: float) -> void:
	Juice.shake(_root, 16.0 * strength, duration)


# ---------------------------------------------------------------- UI construction

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "AudiOtron"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_bg = Control.new()
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP  # the AudiOtron covers the world: eat stray clicks
	_bg.draw.connect(_draw_bg)
	_root.add_child(_bg)
	_deck = Control.new()
	_deck.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck.draw.connect(_draw_deck)
	_root.add_child(_deck)
	_booth = AoBoothWindow.new()
	_root.add_child(_booth)
	_lcd = AoLcd.new()
	_lcd.freq_step.connect(func(d: int) -> void:
		if _player_ok():
			_freq(d))
	_lcd.level_step.connect(func(d: int) -> void:
		if _player_ok():
			_level(d))
	_lcd.stimulus_cycle.connect(_cycle_stimulus)
	_root.add_child(_lcd)
	_status = AoStatus.new()
	_root.add_child(_status)
	for e: String in ["right", "left"]:
		var card := AoEarCard.new(e)
		_root.add_child(card)
		_cards[e] = card
		card.audiogram.freq_clicked.connect(func(f: int) -> void:
			if e == _ear and _player_ok():
				_jump_freq(f))
		Hoot.register_anchor("audiogram_" + e, card.audiogram)
	_hoot_spot = Control.new()
	_hoot_spot.name = "HootSpot"
	_hoot_spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hoot_spot.draw.connect(_draw_perch)
	_root.add_child(_hoot_spot)
	_quest = AoQuest.new()
	_quest.token_clicked.connect(func(f: int) -> void:
		if _player_ok():
			_jump_freq(f))
	_root.add_child(_quest)
	_dance = AoDanceCard.new()
	_dance.name = "DanceCard"
	_root.add_child(_dance)
	# controls
	var soft := _make_button("softer_button", "SOFTER", AoButton.Icon.TRI_DOWN, Palette.SUNNY, &"softer", func() -> void: _level(-1))
	var tone := _make_button("tone_button", "TONE", AoButton.Icon.WAVES, Palette.SKY, &"present_tone", Callable())
	tone.font_size = 26
	tone.icon_size = 38.0
	tone.hold_ring = true
	tone.pressed_down.connect(func() -> void:
		if _player_ok():
			_hold_add("mouse"))
	tone.released.connect(func() -> void: _hold_remove("mouse"))
	tone.right_clicked.connect(func() -> void:
		if _player_ok():
			_store(true))
	var loud := _make_button("louder_button", "LOUDER", AoButton.Icon.TRI_UP, Palette.SUNNY, &"louder", func() -> void: _level(1))
	for b: AoButton in [soft, loud]:
		b.font_size = 19
	_make_button("freq_down_button", "Hz", AoButton.Icon.ARROW_LEFT, Palette.SUNNY, &"freq_down", func() -> void: _freq(-1))
	_make_button("freq_up_button", "Hz", AoButton.Icon.ARROW_RIGHT, Palette.SUNNY, &"freq_up", func() -> void: _freq(1))
	_make_button("store_button", "STORE", AoButton.Icon.STAMP, Palette.MINT, &"store", func() -> void: _store(false))
	var nr := _make_button("no_response_button", "NO RESP", AoButton.Icon.NO_RESP, Palette.CORAL, &"no_response", func() -> void: _store(true))
	nr.text_color = Palette.PAPER
	nr.font_size = 17
	# v3: masking and route (hidden on Day 1)
	var ms := _make_button("mask_softer_button", "NOISE", AoButton.Icon.TRI_DOWN, Palette.PLUM.lightened(0.55), &"mask_softer", func() -> void: _mask_level(-1))
	var mt := _make_button("mask_toggle_button", "MASK OFF", AoButton.Icon.NONE, Palette.CREAM, &"toggle_mask", _toggle_mask)
	var ml := _make_button("mask_louder_button", "NOISE", AoButton.Icon.TRI_UP, Palette.PLUM.lightened(0.55), &"mask_louder", func() -> void: _mask_level(1))
	var route := _make_button("transducer_button", "AIR", AoButton.Icon.NONE, Palette.PAPER, &"transducer_bone", func() -> void:
		if session != null:
			_set_transducer(session.air_transducer if session.transducer == &"bone" else &"bone"))
	for b: AoButton in [ms, mt, ml, route]:
		b.font_size = 15
		b.visible = false
	var er := _make_button("ear_right_button", "R", AoButton.Icon.EAR_RIGHT, Palette.RIGHT_TINT, &"ear_right", func() -> void: _set_ear("right"))
	var el := _make_button("ear_left_button", "L", AoButton.Icon.EAR_LEFT, Palette.LEFT_TINT, &"ear_left", func() -> void: _set_ear("left"))
	for b: AoButton in [er, el]:
		b.font_size = 18
		b.icon_size = 26.0
	var keys := _make_button("keys_toggle", "Keys: ON", AoButton.Icon.NONE, Palette.MINT, TOGGLE_HINTS_ACTION, _toggle_hints, false)
	var style := _make_button("style_toggle", "Up = LOUDER", AoButton.Icon.NONE, Palette.PAPER, &"", _toggle_key_style, false)
	var hint := _make_button("hint_button", "Ask Hoot x3", AoButton.Icon.NONE, Palette.HOOT_FACE, &"", _ask_hoot, false)
	# Mouse-only players need a way into the pause menu (volumes, key style, motion) mid-test:
	# the story hides its own corner button while the AudiOtron is up. Esc / P still work too.
	var pause_btn := _make_button("pause_button", "II", AoButton.Icon.NONE, Palette.PAPER, &"", _open_pause_menu, false)
	pause_btn.font_size = 16
	pause_btn.pill = true   # pill: no keycap strip under it (_refresh_keys toggles show_keycap), or the body collapses to a sliver
	pause_btn.depth = 3.0
	pause_btn.radius = 12
	pause_btn.tooltip_text = "Pause (Esc)"
	for b: AoButton in [keys, style, hint]:
		b.font_size = 14
		b.depth = 4.0
		b.radius = 12
		b.pill = true
	_ff_banner = Control.new()
	_ff_banner.name = "HootTurnBanner"
	_ff_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ff_banner.visible = false
	_ff_banner.draw.connect(_draw_ff_banner)
	_root.add_child(_ff_banner)
	_fx = AoFx.new()
	_root.add_child(_fx)
	_refresh_keys()


func _open_pause_menu() -> void:
	var menu := get_tree().get_first_node_in_group("pause_menu")
	if menu != null and menu.has_method("open"):
		for src: String in _hold.keys():
			_hold_remove(src)   # release a held tone properly before the tree pauses
		menu.call("open")


func _make_button(id: String, text: String, icon: AoButton.Icon, color: Color, action: StringName, on_click: Callable, anchor: bool = true) -> AoButton:
	var b := AoButton.new()
	b.name = id
	b.text = text
	b.icon = icon
	b.face_color = color
	b.action = action
	if on_click.is_valid():
		b.clicked.connect(func() -> void:
			if _player_ok() or id in ["keys_toggle", "style_toggle", "pause_button"]:
				on_click.call())
	_root.add_child(b)
	_buttons[id] = b
	if anchor:
		Hoot.register_anchor(id, b)
	return b


func _layout() -> void:
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
	_status.position = Vector2(vp.x - m - col_w, y_top)
	_status.size = Vector2(col_w, top_h)
	var pb: AoButton = _buttons.get("pause_button")
	if pb != null:
		pb.size = Vector2(40.0, 36.0)
		pb.position = Vector2(_status.position.x + col_w - 52.0, y_top + 12.0)
	_lcd.position = Vector2(m * 2.0 + booth_w, y_top)
	_lcd.size = Vector2(vp.x - m * 4.0 - booth_w - col_w, top_h)
	var mid_y := y_top + top_h + m + 4.0
	var bottom_y := vp.y - m - bottom_h
	var mid_h := bottom_y - m - mid_y
	var cards_w := vp.x - m * 3.0 - col_w
	var card_w := (cards_w - m) * 0.5
	(_cards["right"] as AoEarCard).position = Vector2(m, mid_y)
	(_cards["right"] as AoEarCard).size = Vector2(card_w, mid_h)
	(_cards["left"] as AoEarCard).position = Vector2(m * 2.0 + card_w, mid_y)
	(_cards["left"] as AoEarCard).size = Vector2(card_w, mid_h)
	var spot_h := minf(150.0, mid_h * 0.45)
	var dance_h := 48.0
	_hoot_spot.position = Vector2(vp.x - m - col_w, mid_y - 6.0)
	_hoot_spot.size = Vector2(col_w, spot_h)
	_quest.position = Vector2(vp.x - m - col_w, mid_y + spot_h)
	_quest.size = Vector2(col_w, mid_h - spot_h - dance_h - 6.0)
	_dance.position = Vector2(vp.x - m - col_w, mid_y + mid_h - dance_h)
	_dance.size = Vector2(col_w, dance_h)
	_ff_banner.size = Vector2(250.0, 44.0)
	_ff_banner.position = Vector2(_lcd.position.x + (_lcd.size.x - 250.0) * 0.5, y_top + top_h - 22.0)
	_deck.position = Vector2(m, bottom_y)
	_deck.size = Vector2(vp.x - m * 2.0, bottom_h)
	_layout_deck(Rect2(_deck.position, _deck.size))
	_sync_bubble_hint()


func _layout_deck(deck: Rect2) -> void:
	var groups: Array = [
		["LEVEL + TONE", [["softer_button", 96.0], ["tone_button", 196.0], ["louder_button", 96.0]]],
		["FREQUENCY", [["freq_down_button", 84.0], ["freq_up_button", 84.0]]],
		["THRESHOLD", [["store_button", 136.0], ["no_response_button", 108.0]]],
		["EAR", [["ear_right_button", 62.0], ["ear_left_button", 62.0]]],
	]
	if _masking_ui:
		# v3: room for MASKING and ROUTE, everything a little narrower (scales up on wide screens)
		var k := clampf((deck.size.x - 1256.0) / 600.0, 0.0, 1.0)
		groups = [
			["LEVEL + TONE", [["softer_button", lerpf(76.0, 96.0, k)], ["tone_button", lerpf(132.0, 196.0, k)], ["louder_button", lerpf(76.0, 96.0, k)]]],
			["FREQUENCY", [["freq_down_button", lerpf(58.0, 84.0, k)], ["freq_up_button", lerpf(58.0, 84.0, k)]]],
			["THRESHOLD", [["store_button", lerpf(96.0, 136.0, k)], ["no_response_button", lerpf(80.0, 108.0, k)]]],
			["MASKING", [["mask_softer_button", lerpf(54.0, 76.0, k)], ["mask_toggle_button", lerpf(96.0, 110.0, k)], ["mask_louder_button", lerpf(54.0, 76.0, k)]]],
			["ROUTE", [["transducer_button", lerpf(70.0, 90.0, k)]]],
			["EAR", [["ear_right_button", lerpf(46.0, 62.0, k)], ["ear_left_button", lerpf(46.0, 62.0, k)]]],
		]
	# narrower buttons, smaller labels (Day 1 keeps its sizes)
	var fonts := {"softer_button": [19, 15], "louder_button": [19, 15], "tone_button": [26, 22], "store_button": [22, 17], "no_response_button": [17, 13],
		"freq_down_button": [22, 17], "freq_up_button": [22, 17], "ear_right_button": [18, 15], "ear_left_button": [18, 15]}
	for id: String in fonts:
		(_buttons[id] as AoButton).font_size = int(fonts[id][1 if _masking_ui else 0])
	(_buttons["tone_button"] as AoButton).icon_size = 30.0 if _masking_ui else 38.0
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
			var btn: AoButton = _buttons[b[0]]
			btn.position = Vector2(x, y)
			btn.size = Vector2(float(b[1]), h)
			x += float(b[1]) + gap
		x += spacing - gap
	var ux := deck.end.x - 16.0 - util_w
	var uy := deck.position.y + 14.0
	var uh := (deck.size.y - 28.0 - 2.0 * 8.0) / 3.0
	for i in 3:
		var btn: AoButton = _buttons[["keys_toggle", "style_toggle", "hint_button"][i]]
		btn.position = Vector2(ux, uy + i * (uh + 8.0))
		btn.size = Vector2(util_w, uh)
	_deck.queue_redraw()


func _draw_bg() -> void:
	var r := Rect2(Vector2.ZERO, _bg.size)
	_bg.draw_rect(r, Palette.CREAM)
	# soft polka dots on the wall
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
	# warm sunny glow behind the console
	_bg.draw_rect(Rect2(0, 0, r.size.x, 8.0), Palette.CORAL)


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
	# a sleepy little owl outline
	_hoot_spot.draw_circle(c + Vector2(0, -16), 18.0, Color(Palette.INK, 0.08))
	_hoot_spot.draw_arc(c + Vector2(-7, -18), 5.0, 0.2, PI - 0.2, 10, Color(Palette.INK, 0.22), 2.0, true)
	_hoot_spot.draw_arc(c + Vector2(7, -18), 5.0, 0.2, PI - 0.2, 10, Color(Palette.INK, 0.22), 2.0, true)
	var perch_text := "Hoot is testing: watch the dance card!" if _auto_running else "Hoot's perch: tips pop up here"
	AoDraw.text_c(_hoot_spot, c + Vector2(0, 18), perch_text, 13, Color(Palette.INK, 0.32 if not _auto_running else 0.6), AoDraw.FONT_BOLD)


func _draw_deck() -> void:
	var r := Rect2(Vector2.ZERO, _deck.size)
	AoDraw.card(_deck, r, Color("#3b3154"), 26)
	AoDraw.rbox(_deck, Rect2(Vector2(14, 6), Vector2(r.size.x - 28, 10)), Color(1, 1, 1, 0.05), 5)
	for gl: Array in _group_labels:
		var lr: Rect2 = gl[1]
		var local := Rect2(lr.position - _deck.position, lr.size)
		AoDraw.text_c(_deck, local.get_center() + Vector2(0, 2), String(gl[0]), 12, Color(Palette.SUNNY, 0.75), AoDraw.FONT_BOLD)
		_deck.draw_line(Vector2(local.position.x, local.get_center().y + 2), Vector2(local.get_center().x - AoDraw.text_size(String(gl[0]), 12, AoDraw.FONT_BOLD).x * 0.5 - 8, local.get_center().y + 2), Color(Palette.SUNNY, 0.25), 2.0)
		_deck.draw_line(Vector2(local.get_center().x + AoDraw.text_size(String(gl[0]), 12, AoDraw.FONT_BOLD).x * 0.5 + 8, local.get_center().y + 2), Vector2(local.end.x, local.get_center().y + 2), Color(Palette.SUNNY, 0.25), 2.0)
