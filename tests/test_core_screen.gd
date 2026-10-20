extends TestCase
## Builder A: the AudiOtron 3000 screen (ui/audiometer/audiometer_screen.gd). API and state
## keys, keys + mouse driving the same controls, coached tips, the key-style swap, the H
## toggle, the ear lock, stamping on the audiogram and test_finished on completion.

const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const EXTRA_KEYS := ["points", "multiplier", "trail", "strokes", "par", "candidate_db", "stimulus", "combo", "presentations"]


## A perfectly consistent patient: hears iff level >= threshold, fixed latency, no tricks.
class FixedSim extends PatientSim:
	func _init(p: PatientProfile) -> void:
		super(p, 1)

	func on_tone_start(ear: String, freq: int, db: int, _gap_s: float) -> Dictionary:
		var heard := db >= effective_threshold(ear, freq)
		return {"heard": heard, "press": heard, "guess": false, "latency_s": 0.5}

	func false_alarm_tick(_delta: float) -> bool:
		return false

	func anticipation_delay() -> float:
		return -1.0

	func keeps_press_after_short_tone(_e: String, _f: int, _d: int, _dur: float) -> bool:
		return true


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
var _n := 0
var _saved_settings: Dictionary = {}


const SCRATCH_SAVE := "user://test_core_screen_save.json"
var _saved_path := ""


## Settings changed here (key style, key hints) are saved by Game: point it at a scratch file
## so the player's real save is never touched, and put everything back afterwards.
func before_each() -> void:
	super()
	_saved_path = Game.save_path
	Game.save_path = SCRATCH_SAVE
	_saved_settings = {"key_style": Game.get_key_style(), "show_key_hints": Game.settings.get("show_key_hints", true)}


func after_each() -> void:
	if Game.get_key_style() != String(_saved_settings["key_style"]):
		Game.set_key_style(String(_saved_settings["key_style"]))
	if Game.settings.get("show_key_hints", true) != _saved_settings["show_key_hints"]:
		Game.set_setting("show_key_hints", _saved_settings["show_key_hints"])
	Game.save_path = _saved_path
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Engine.time_scale = 1.0
	Hoot.clear()
	super()


func _screen(ear: String = "right", coached: bool = true) -> AudiometerScreen:
	var screen := (load(AUDIOMETER) as PackedScene).instantiate() as AudiometerScreen
	add_node(screen)
	Game.begin_visit("gus")
	screen.start_test(Game.load_patient("gus") as PatientProfile, ear, coached)
	return screen


func _fixed(screen: AudiometerScreen) -> void:
	screen.session.sim = FixedSim.new(screen.session.patient)


## One presentation through the screen's own mouse path (hold the TONE pad).
func _present(screen: AudiometerScreen) -> void:
	var s := screen.session
	_tick(s, GAPS[_n % GAPS.size()])
	_n += 1
	screen._hold_add("mouse")
	_tick(s, 1.5)
	screen._hold_remove("mouse")
	_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)


func _tick(s: AudiometrySession, seconds: float) -> void:
	for i in int(round(seconds / 0.05)):
		s.advance(0.05)


## Play what recommended_action() says, through the screen's controls, until the ear is
## complete (or only the first stored frequency when one_freq is true).
func _play(screen: AudiometerScreen, e: String, one_freq: bool = false) -> void:
	var s := screen.session
	var guard := 0
	var stored0 := s.stored_thresholds(e).size()
	while not s.is_ear_complete(e) and guard < 500:
		guard += 1
		if one_freq and s.stored_thresholds(e).size() > stored0:
			return
		var rem := s.required_remaining(e)
		if s.measurement(e, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
			screen._jump_freq(rem[0])
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(screen)
			&"softer":
				screen._level(-1)
			&"louder":
				screen._level(1)
			&"store":
				screen._store(false)
			&"no_response":
				screen._store(true)
			_:
				_tick(s, 0.1)


func test_state_has_contract_and_extra_keys() -> void:
	var screen := _screen()
	await wait_frames(2)
	var st := screen.get_state()
	for k in EXTRA_KEYS:
		assert_has(st, k, "state")
	assert_eq(int(st["freq"]), 1000, "starts at 1 kHz")
	assert_eq(int(st["db"]), 40, "starts at 40 dB HL")
	assert_eq(String(st["stimulus"]), "PULSED", "E7: pulsed by default")
	assert_eq(st["remaining"], [1000, 1500, 2000, 3000, 4000, 6000, 8000, 500, 250], "textbook order (E1)")
	var labels := []
	for it: Dictionary in screen._quest.items:
		labels.append(String(it["label"]))
	assert_eq(labels, ["1k", "1.5k", "2k", "3k", "4k", "6k", "8k", "1k R", "500", "250"], "test plan shows the 1k retest")
	for id in AudiometerScreen.ANCHORS:
		assert_true(Hoot.has_anchor(id), "anchor %s registered" % id)
		assert_true(Hoot.anchor_screen_rect(id).size.x > 0.0, "anchor %s laid out" % id)


func test_coached_tip_points_at_tone_pad() -> void:
	var screen := _screen("right", true)
	await wait_frames(2)
	var tip := Hoot.current_tip()
	assert_eq(String(tip.get("target", "")), "tone_button", "first coached tip points at TONE")
	assert_true(String(tip.get("text", "")).contains("SPACE"), "tip names the key: %s" % tip.get("text", ""))
	assert_true((screen._buttons["tone_button"] as AoButton).beckon, "TONE pad beckons")
	# After a heard tone, the coach points at SOFTER (heard = down 10).
	_fixed(screen)
	_present(screen)
	screen._refresh()
	screen._coach_update()
	assert_eq(String(Hoot.current_tip().get("target", "")), "softer_button", "heard -> coach points at SOFTER")


func test_key_style_swap_relabels() -> void:
	var screen := _screen()
	await wait_frames(1)
	Game.set_key_style("otosuite")
	assert_eq(Game.key_label(&"louder"), "Up")
	assert_eq((screen._buttons["style_toggle"] as AoButton).text, "Up = LOUDER")
	screen._toggle_key_style()
	assert_eq(Game.get_key_style(), "affinity")
	assert_eq(Game.key_label(&"louder"), "Down", "affinity style: Down = louder")
	assert_eq((screen._buttons["style_toggle"] as AoButton).text, "Up = SOFTER")
	var db0 := int(screen.get_state()["db"])
	await tap_action(&"louder")
	assert_eq(int(screen.get_state()["db"]), db0 + 5, "louder action still means louder")


func test_level_is_blocked_while_tone_plays() -> void:
	var screen := _screen()
	await wait_frames(2)
	var db0 := int(screen.get_state()["db"])
	send_action(&"present_tone", true)
	await wait_frames(3)
	assert_true(bool(screen.get_state()["tone_on"]), "tone on")
	assert_true((screen._buttons["tone_button"] as AoButton).glow > 0.0, "TONE pad lights while the tone plays")
	assert_true(screen._lcd.tone_glow > 0.0, "LCD tone lamp lights while the tone plays")
	await tap_action(&"louder")
	assert_eq(int(screen.get_state()["db"]), db0, "no level change during a tone")
	send_action(&"present_tone", false)
	await wait_frames(3)
	assert_false(bool(screen.get_state()["tone_on"]), "tone off")
	await tap_action(&"louder")
	assert_eq(int(screen.get_state()["db"]), db0 + 5, "level changes after release")


func test_mouse_drives_the_same_controls() -> void:
	var screen := _screen()
	await wait_frames(2)
	var tone := screen._buttons["tone_button"] as AoButton
	tone.pressed_down.emit()
	assert_true(bool(screen.get_state()["tone_on"]), "holding the TONE pad plays a tone")
	tone.released.emit()
	assert_false(bool(screen.get_state()["tone_on"]), "releasing the pad stops it")
	(screen._buttons["louder_button"] as AoButton).clicked.emit()
	assert_eq(int(screen.get_state()["db"]), 45, "LOUDER button")
	(screen._buttons["softer_button"] as AoButton).clicked.emit()
	assert_eq(int(screen.get_state()["db"]), 40, "SOFTER button")
	(screen._buttons["freq_up_button"] as AoButton).clicked.emit()
	assert_eq(int(screen.get_state()["freq"]), 1500, "Hz > button")
	screen._quest.token_clicked.emit(1000)
	assert_eq(int(screen.get_state()["freq"]), 1000, "test-plan token jumps to its frequency")


func test_ear_is_locked_to_the_requested_ear() -> void:
	var screen := _screen("right")
	await wait_frames(2)
	await tap_action(&"ear_left")
	assert_eq(String(screen.get_state()["ear"]), "right", "L does not switch away mid-ear")
	assert_true((screen._buttons["ear_left_button"] as AoButton).locked)


func test_h_toggles_key_hints() -> void:
	var screen := _screen()
	await wait_frames(2)
	var before := bool(Game.settings.get("show_key_hints", true))
	await tap_action(AudiometerScreen.TOGGLE_HINTS_ACTION)
	assert_eq(bool(Game.settings.get("show_key_hints", true)), not before, "H flips show_key_hints")
	assert_eq((screen._buttons["store_button"] as AoButton).show_keycap, not before, "key caps follow the setting")
	await tap_action(AudiometerScreen.TOGGLE_HINTS_ACTION)
	assert_eq(bool(Game.settings.get("show_key_hints", true)), before)


func test_store_stamps_the_audiogram() -> void:
	var screen := _screen("right", true)
	await wait_frames(2)
	_fixed(screen)
	var stored := []
	var cb := func(e: String, f: int, d: int, _i: Dictionary) -> void: stored.append([e, f, d])
	Events.threshold_stored.connect(cb)
	_play(screen, "right", true)
	Events.threshold_stored.disconnect(cb)
	var t := screen.session.patient.get_threshold("right", 1000)
	assert_eq(stored, [["right", 1000, t]], "1 kHz stored at the true threshold")
	var card := screen._cards["right"] as AoEarCard
	assert_eq(card.audiogram.point_count("right"), 1, "one symbol stamped on the right card")
	assert_eq(int(screen.get_state()["stored"]["right"][1000]), t)
	assert_false(screen._coach_active, "the coach hands over after the first stamp")
	assert_true(int(screen.get_state()["points"]) > 0, "points for clean steps and the stamp")


func test_completing_the_ear_emits_test_finished() -> void:
	var screen := _screen("right", false)
	await wait_frames(2)
	_fixed(screen)
	var got := []
	screen.test_finished.connect(func(r: Dictionary) -> void: got.append(r))
	_play(screen, "right")
	assert_true(screen.session.is_ear_complete("right"), "ear complete by the book")
	assert_false(bool(screen.get_state()["accepting_input"]), "input stops for the fanfare")
	Engine.time_scale = 8.0
	var frames := 0
	while got.is_empty() and frames < 600:
		frames += 1
		await wait_frames(1)
	Engine.time_scale = 1.0
	assert_eq(got.size(), 1, "test_finished emitted once")
	if got.is_empty():
		return
	var r: Dictionary = got[0]
	assert_has(r, "ears")
	assert_has(r["ears"], "right")
	assert_eq(String(r["grade"]), "S", "a by-the-book run earns S")
	assert_eq((screen._cards["right"] as AoEarCard).audiogram.point_count("right"), 6, "six symbols on the card (the retest adds none)")
	assert_false((r["ears"]["right"]["retest_1k"] as Dictionary).is_empty(), "retest recorded")


## (E10) The mask lamp's green state reads "in range" until the plateau is found, then "good".
## (E15) The audiogram's degree bands use the rules' names, and the chart names the scale.
func test_mask_lamp_words_and_degree_names() -> void:
	assert_eq(AoLcd.MASK_WORDS[&"ok"], "in range")
	assert_eq(AoLcd.MASK_WORD_FOUND, "good")
	var names: Array = []
	for band: Array in ClinicRules.DEGREE_BANDS:
		names.append(String(band[1]))
	names.append(ClinicRules.DEGREE_TOP)
	var chart: Array = []
	for d: Array in Audiogram.DEGREES:
		chart.append(String(d[2]))
	assert_eq(chart, names, "one name for each degree everywhere")
	for i in ClinicRules.DEGREE_BANDS.size():
		assert_eq(int(Audiogram.DEGREES[i][1]), int(ClinicRules.DEGREE_BANDS[i][0]), "same band edges")
	assert_true(ClinicRules.DEGREE_SCALE_NOTE.contains("Goodman"))
