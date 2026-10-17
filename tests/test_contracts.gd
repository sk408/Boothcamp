extends TestCase
## Contract checks between modules (CONTRACTS.md). Builders: run this after replacing stubs.
## It fails if a public scene, method, signal or constant the other side relies on is missing.

const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const AUDIOGRAM := "res://ui/audiogram/audiogram.tscn"
const CLINIC := "res://world/clinic.tscn"
const STORY_SCENES := ["res://story/title_screen.tscn", "res://story/level_gus.tscn", "res://story/hoot_bubble.tscn", "res://story/pause_menu.tscn", "res://story/daily_decibel.tscn"]

const EVENTS_SIGNALS := [
	"goto_scene", "scene_changed", "phase_changed", "level_started", "level_finished", "awaiting_input",
	"input_resolved", "screenshot_requested", "pause_toggled", "quit_requested", "settings_changed",
	"key_style_changed", "comfort_changed", "coins_changed", "dialogue_line", "hoot_say", "hoot_tip_shown",
	"hoot_tip_dismissed", "hoot_mastered", "audiometry_started", "tone_started", "tone_stopped",
	"patient_responded", "audiometer_state_changed", "threshold_stored", "technique_event", "combo_changed",
	"ear_completed", "audiometry_finished", "patient_reaction", "screen_shake",
]
const REQUIRED_REACTIONS := [&"heard", &"missed", &"false_alarm", &"too_loud_blast", &"startle", &"grooving", &"bored"]
const STATE_KEYS := ["patient_id", "ear", "freq", "db", "tone_on", "accepting_input", "coached", "freqs_available", "stored", "remaining", "ear_complete",
	# v2 extras
	"points", "multiplier", "trail", "strokes", "par", "candidate_db", "stimulus"]


func test_events_declares_all_signals() -> void:
	for s in EVENTS_SIGNALS:
		assert_has_signal(Events, s, "Events")


func test_gus_profile() -> void:
	var p := Game.load_patient("gus") as PatientProfile
	assert_true(p != null)
	assert_eq(p.validate(), PackedStringArray(), "gus.tres validates")
	assert_eq(p.display_name, "Grandpa Gus")
	for f: int in ClinicRules.AC_FREQS:
		assert_true(absi(p.get_threshold("right", f) - p.get_threshold("left", f)) <= 10, "symmetric within 10 dB at %d" % f)
	assert_eq(ClinicRules.classify_shape(p.thresholds_right), &"sloping")
	assert_eq(ClinicRules.classify_shape(p.thresholds_left), &"sloping")


func test_audiogram_api() -> void:
	var ag: Node = (load(AUDIOGRAM) as PackedScene).instantiate()
	assert_true(ag is Control, "audiogram root is a Control")
	for m in ["set_point", "clear_points", "show_results", "set_cursor", "freq_to_x", "db_to_y", "get_point_global_position", "get_region_global_rect"]:
		assert_has_method(ag, m, "Audiogram")
	assert_has_signal(ag, "draw_finished", "Audiogram")
	for m in ["play_melody", "point_count", "freq_at"]:
		assert_has_method(ag, m, "Audiogram (v2)")
	assert_has_signal(ag, "freq_clicked", "Audiogram (v2)")
	ag.free()


func test_audiometer_screen_api_and_input() -> void:
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	assert_true(screen is CanvasLayer, "audiometer root is a CanvasLayer")
	for m in ["start_test", "get_state"]:
		assert_has_method(screen, m, "AudiometerScreen")
	assert_has_signal(screen, "test_finished", "AudiometerScreen")
	add_node(screen)
	await wait_frames(2)
	var started := []
	var cb := func(pid: String, ear: String, coached: bool) -> void: started.append([pid, ear, coached])
	Events.audiometry_started.connect(cb)
	Game.begin_visit("gus")
	screen.call("start_test", Game.load_patient("gus"), "right", true)
	Events.audiometry_started.disconnect(cb)
	assert_eq(started.size(), 1, "audiometry_started emitted")
	var st: Dictionary = screen.call("get_state")
	for k in STATE_KEYS:
		assert_has(st, k, "state")
	assert_eq(st["ear"], "right")
	assert_true(bool(st["accepting_input"]), "accepting input after start_test")
	assert_eq(Stage.audiometer, screen, "screen registered with Stage")
	# Input contract: InputEventAction drives the screen.
	var db0: int = st["db"]
	await _tap(&"louder")
	assert_eq(int(screen.call("get_state")["db"]), db0 + 5, "louder = +5 dB")
	await _tap(&"softer")
	assert_eq(int(screen.call("get_state")["db"]), db0, "softer = -5 dB")
	var f0: int = screen.call("get_state")["freq"]
	await _tap(&"freq_up")
	assert_true(int(screen.call("get_state")["freq"]) > f0, "freq_up raises frequency")
	await _tap(&"freq_down")
	var tones := []
	var on := func(e: String, f: int, d: int) -> void: tones.append("on")
	var off := func(e: String, f: int, d: int, dur: float) -> void: tones.append("off")
	Events.tone_started.connect(on)
	Events.tone_stopped.connect(off)
	_send(&"present_tone", true)
	await wait_frames(3)
	assert_true(bool(screen.call("get_state")["tone_on"]), "tone on while held")
	_send(&"present_tone", false)
	await wait_frames(3)
	Events.tone_started.disconnect(on)
	Events.tone_stopped.disconnect(off)
	assert_eq(tones, ["on", "off"], "tone_started/tone_stopped")
	Hoot.clear()


## The story adds the screen and calls start_test() in the same frame (before any layout).
## The bubble hint must still end up on the laid-out spot, and be released on exit.
func test_audiometer_reserves_bubble_spot() -> void:
	Hoot.clear_bubble_hint()
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	Game.begin_visit("gus")
	screen.call("start_test", Game.load_patient("gus"), "right", true)
	await wait_frames(4)
	var hint: Rect2 = Hoot.bubble_rect_hint
	assert_true(hint.size.x > 0.0 and hint.position.x > 640.0, "bubble spot is in the right-hand column (got %s)" % hint)
	screen.queue_free()
	await wait_frames(2)
	assert_eq(Hoot.bubble_rect_hint, Rect2(), "hint cleared when the screen leaves")
	Hoot.clear()


func test_clinic_api() -> void:
	var clinic: Node = (load(CLINIC) as PackedScene).instantiate()
	assert_true(clinic is Node3D, "clinic root is a Node3D")
	for m in ["walk_in", "sit", "play_patient_reaction", "focus_camera", "put_on_earphones", "set_world_saturation", "get_booth_texture", "set_booth_view_active", "get_ear_screen_position", "get_main_camera"]:
		assert_has_method(clinic, m, "Clinic")
	for m in ["doris_enter", "doris_react", "gus_look", "set_title_mode", "play_birdsong", "get_head_screen_position", "take_off_glasses", "put_on_glasses", "put_on_hearing_aids", "get_muffle"]:
		assert_has_method(clinic, m, "Clinic (v2 story extras)")
	var shots: Array = clinic.get("SHOTS")
	assert_eq(shots.slice(0, 8), [&"wide", &"door", &"desk", &"booth", &"ear_right", &"ear_left", &"face", &"otoscope"], "original SHOTS keep their order")
	assert_has(shots, &"title", "SHOTS v2")
	assert_has(shots, &"fitting", "SHOTS v2")
	var reactions: Array = clinic.get("REACTIONS")
	for r in REQUIRED_REACTIONS:
		assert_has(reactions, r, "Clinic.REACTIONS")
	add_node(clinic)
	await wait_frames(2)
	assert_eq(Stage.clinic, clinic, "clinic registered with Stage")
	assert_true(Stage.get_booth_texture() != null, "booth texture")
	for r in reactions:
		Events.patient_reaction.emit(r, {"ear": "right"})
	await wait_frames(2)


func test_story_scenes_exist() -> void:
	for p in STORY_SCENES:
		assert_true(ResourceLoader.exists(p), p)
	for p in ["res://story/hoot_bubble.tscn", "res://story/pause_menu.tscn"]:
		var n: Node = (load(p) as PackedScene).instantiate()
		add_node(n)
	await wait_frames(1)
	assert_true(tree.get_first_node_in_group("pause_menu") != null, "pause menu joins group pause_menu")


func _send(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _tap(action: StringName) -> void:
	_send(action, true)
	await wait_frames(2)
	_send(action, false)
	await wait_frames(2)


## v2: the key-hint toggle is a real project action (tools/setup_input_map.gd), not only a runtime add.
func test_toggle_key_hints_action_in_project() -> void:
	assert_true(ProjectSettings.has_setting("input/toggle_key_hints"), "input/toggle_key_hints in project.godot")
	assert_eq(Game.key_label(&"toggle_key_hints"), "H")


## v2: a wrong earphone drop bounces back, so it must not tell the AudiOtron the phones are swapped.
func test_earphone_slip_does_not_swap_phones() -> void:
	Game.begin_visit("gus")
	var g: Control = (load("res://story/games/earphones.gd") as GDScript).new()
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_node(g)
	await wait_frames(2)
	g.call("_layout")
	var targets: Dictionary = g.get("_targets")
	(targets["right"] as Control).position = Vector2(300, 300)
	(targets["left"] as Control).position = Vector2(800, 300)
	g.call("_drop", "right", (targets["left"] as Control).get_global_rect().get_center())
	assert_eq(int(g.get("mistakes")), 1, "a wrong drop counts as a slip")
	assert_false(bool(Game.get_visit_flag("earphones_swapped", false)), "phones are not swapped after a slip")
	assert_eq(int(Game.get_visit_flag("earphone_slips", 0)), 1)
	Hoot.clear()
