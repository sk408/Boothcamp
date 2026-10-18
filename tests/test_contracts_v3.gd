extends TestCase
## (v3) Chapter 2 contract checks (CONTRACTS.md, everything marked v3): the new signals, the
## AudiOtron's test plan and state keys, the masking / route actions, the audiogram layers, the
## clinic's Bonnie and oscillator, and the Day 2 story beats with their solvers.

const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const AUDIOGRAM := "res://ui/audiogram/audiogram.tscn"
const CLINIC := "res://world/clinic.tscn"

const EVENTS_SIGNALS_V3 := ["chapter_completed", "masker_changed", "transducer_changed"]
const STATE_KEYS_V3 := ["test", "goal_test", "transducer", "air_transducer", "masking_controls", "mask_on", "mask_db",
	"mask_ear", "mask_status", "initial_mask_db", "overmask_limit_db", "plateau", "stored_tests", "hoot_turn", "quick_visit", "max_db"]


func test_events_v3_signals() -> void:
	for s in EVENTS_SIGNALS_V3:
		assert_has_signal(Events, s, "Events (v3)")


func test_day1_plan_is_unchanged() -> void:
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	await wait_frames(2)
	Game.begin_visit("gus")
	screen.call("start_test", Game.load_patient("gus"), "right", true)
	var st: Dictionary = screen.call("get_state")
	for k in STATE_KEYS_V3:
		assert_has(st, k, "state (v3)")
	assert_eq(st["test"], &"ac")
	assert_eq(st["goal_test"], &"ac")
	assert_eq(st["transducer"], &"phones")
	assert_false(bool(st["masking_controls"]), "no masking deck on Day 1")
	assert_eq(st["freqs_available"], ClinicRules.AC_FREQS, "air frequencies")
	await _tap(&"toggle_mask")
	await _tap(&"transducer_bone")
	st = screen.call("get_state")
	assert_false(bool(st["mask_on"]), "M does nothing on Day 1")
	assert_eq(st["transducer"], &"phones", "B does nothing on Day 1")
	Hoot.clear()


func test_bone_plan_and_masking_actions() -> void:
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_node(screen)
	await wait_frames(2)
	Game.begin_visit("bonnie")
	var routes := []
	var maskers := []
	var on_route := func(tr: StringName, ear: String) -> void: routes.append([tr, ear])
	var on_mask := func(ear: String, _f: int, db: int, on: bool) -> void: maskers.append([ear, db, on])
	Events.transducer_changed.connect(on_route)
	Events.masker_changed.connect(on_mask)
	screen.call("start_test", Game.load_patient("bonnie"), "right", false, {"test": "bc", "hoot_turn_after": 99})
	var st: Dictionary = screen.call("get_state")
	assert_eq(st["goal_test"], &"bc")
	assert_eq(st["transducer"], &"bone", "a bone plan starts on the oscillator")
	assert_true(bool(st["masking_controls"]), "masking deck shown for bone")
	assert_eq(st["freqs_available"], ClinicRules.BC_FREQS, "bone frequencies 250-4k")
	assert_eq(int(st["max_db"]), ClinicRules.max_db_for(int(st["freq"]), &"bone"), "bone max output")
	assert_eq(st["remaining"], ClinicRules.BC_REQUIRED, "bone plan: 1k, 2k, 4k, 500")
	assert_eq(routes.back(), [&"bone", "right"], "transducer_changed on start")
	await _tap(&"toggle_mask")
	st = screen.call("get_state")
	assert_true(bool(st["mask_on"]), "M = masking on")
	assert_eq(st["test"], &"bc_masked", "bone + masking = the masked bone sheet")
	assert_eq(st["mask_ear"], "left", "the noise goes in the non-test ear")
	var m0 := int(st["mask_db"])
	await _tap(&"mask_louder")
	assert_eq(int(screen.call("get_state")["mask_db"]), m0 + 5, "PgUp = noise +5")
	var db0 := int(screen.call("get_state")["db"])
	_shift_up()
	await wait_frames(3)
	st = screen.call("get_state")
	assert_eq(int(st["mask_db"]), m0 + 10, "Shift+Up = noise +5")
	assert_eq(int(st["db"]), db0, "Shift+Up does not also move the tone")
	await _tap(&"mask_softer")
	assert_eq(int(screen.call("get_state")["mask_db"]), m0 + 5, "PgDn = noise -5")
	assert_true(maskers.size() > 0 and maskers.back()[0] == "left" and bool(maskers.back()[2]), "masker_changed on the left ear")
	assert_true(int(st["initial_mask_db"]) > 0, "the helper shows a starting level")
	await _tap(&"toggle_mask")
	await _tap(&"transducer_air")
	st = screen.call("get_state")
	assert_eq(st["transducer"], &"phones", "A = air")
	assert_eq(st["test"], &"ac")
	assert_false(bool(maskers.back()[2]), "masker_changed off")
	Events.transducer_changed.disconnect(on_route)
	Events.masker_changed.disconnect(on_mask)
	Hoot.clear()


func test_audiogram_v3_layers() -> void:
	var ag: Node = (load(AUDIOGRAM) as PackedScene).instantiate()
	add_node(ag)
	await wait_frames(1)
	for p in ["layers", "cursor_test", "max_output_transducer"]:
		assert_true(p in ag, "Audiogram.%s (v3)" % p)
	ag.call("set_point", "right", 1000, 50, false, false, &"ac")
	ag.call("set_point", "right", 1000, 10, false, false, &"bc_masked")
	ag.call("set_point", "right", 1000, 0, false, false, &"bc")
	assert_eq(int(ag.call("point_count", "right", &"ac")), 1)
	assert_eq(int(ag.call("point_count", "right", &"bc_masked")), 1)
	var air: Vector2 = ag.call("get_point_global_position", "right", 1000, &"ac")
	var bone: Vector2 = ag.call("get_point_global_position", "right", 1000, &"bc_masked")
	assert_true(bone.x < air.x, "right bone sits left of the frequency line")
	assert_true(bone.y < air.y, "bone 10 is above air 50")


func test_clinic_bonnie_and_oscillator() -> void:
	var clinic: Node = (load(CLINIC) as PackedScene).instantiate()
	assert_true("patient_id" in clinic, "Clinic.patient_id (v3)")
	clinic.set("patient_id", "bonnie")
	for m in ["put_on_bone_oscillator", "put_on_masking_phone", "take_off_bone_oscillator"]:
		assert_has_method(clinic, m, "Clinic (v3)")
	add_node(clinic)
	await wait_frames(2)
	var bean: Node = clinic.call("get_patient")
	assert_eq(String((bean.get("cfg") as Dictionary)["name"]), "Bonnie", "patient_id builds Bonnie")
	clinic.call("put_on_earphones", true)
	clinic.call("put_on_bone_oscillator", "right")
	clinic.call("put_on_masking_phone", "left")
	await wait_frames(2)
	clinic.call("take_off_bone_oscillator")
	await wait_frames(1)


func test_bc_placement_beat() -> void:
	Game.begin_visit("bonnie")
	var g: Control = (load("res://story/games/bone_placement.gd") as GDScript).new()
	add_node(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(2)
	var got := {}
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		got["beat"] = beat
		got["info"] = info
		got["solver"] = solver
	Events.awaiting_input.connect(cb)
	g.call("run")
	await wait_frames(1)
	Events.awaiting_input.disconnect(cb)
	assert_eq(got.get("beat", &""), &"bc_placement")
	assert_eq((got["info"] as Dictionary)["targets"], ["mastoid_target_right"])
	assert_true(Hoot.has_anchor("oscillator") and Hoot.has_anchor("mastoid_target_right"), "anchors registered")
	g.call("_place", "top")
	assert_eq(int(g.get("mistakes")), 1, "the unicorn is a slip")
	await wait_seconds(1.3)
	(got["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(bool(g.get("placed")), "solver puts it on the mastoid")
	Hoot.clear()


func test_referral_stamp_beat() -> void:
	var b: Control = (load("res://story/games/day2_board.gd") as GDScript).new()
	add_node(b)
	await wait_frames(2)
	var got := {}
	var cb := func(beat: StringName, _info: Dictionary, solver: Callable) -> void:
		got["beat"] = beat
		got["solver"] = solver
	Events.awaiting_input.connect(cb)
	b.call("run_stamp")
	await wait_frames(1)
	Events.awaiting_input.disconnect(cb)
	assert_eq(got.get("beat", &""), &"referral_stamp")
	(got["solver"] as Callable).call()
	assert_true(bool(b.get("stamped")), "solver stamps")
	await wait_seconds(1.1)
	Hoot.clear()


func test_hud_set_steps() -> void:
	var hud: CanvasLayer = (load("res://story/hud.gd") as GDScript).new()
	add_node(hud)
	await wait_frames(1)
	var lv: Script = load("res://story/level_bonnie.gd")
	hud.call("set_steps", lv.get("STEPS"), lv.get("STEP_LABELS"), "BONNIE BUNSWORTH'S VISIT")
	hud.call("set_step", &"mask")
	await wait_frames(1)
	assert_eq(int(hud.get("_current")), (lv.get("STEPS") as Array).find(&"mask"))


func _shift_up() -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_UP
		ev.physical_keycode = KEY_UP
		ev.shift_pressed = true
		ev.pressed = pressed
		Input.parse_input_event(ev)


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


## (v3, builders) The additions merged at integration: pronouns, tip_text, the masked grace, the bone
## channel, the audiogram's optional layers and the clinic's new reactions and story extras.
func test_v3_builder_additions() -> void:
	var bonnie: PatientProfile = Game.load_patient("bonnie") as PatientProfile
	var gus: PatientProfile = Game.load_patient("gus") as PatientProfile
	for p in ["pronoun", "nickname"]:
		assert_true(p in bonnie, "PatientProfile.%s" % p)
	assert_eq(bonnie.short_name(), "Bonnie")
	assert_eq(gus.short_name(), "Gus")
	assert_eq(bonnie.say("{He} said {his} name is {name}."), "She said her name is Bonnie.")
	assert_eq(gus.say("{He} said {his} name is {name}."), "He said his name is Gus.")
	assert_eq(PatientProfile.pronouns("ask {him}", "she"), "ask her")
	assert_true(AudiometrySession.MASKED_GRACE_DB >= 0, "masked grace constant")
	var session := AudiometrySession.new(bonnie)
	assert_has_method(session, "tip_text", "AudiometrySession (v3, builders)")
	for kind: StringName in AudiometrySession.TIPS:
		assert_false(session.tip_text(kind).contains("{"), "tip %s has no unfilled token" % kind)
	var tg := ToneGenerator.new()
	assert_true("bone" in tg, "ToneGenerator.bone")
	assert_eq(ToneGenerator.BONE_CROSS_DB, -10.0)
	tg.free()
	var ag: Node = (load(AUDIOGRAM) as PackedScene).instantiate()
	for p in ["attention", "show_gap", "masker_view"]:
		assert_true(p in ag, "Audiogram.%s" % p)
	assert_false(bool(ag.get("show_gap")), "the gap bridge is off by default")
	ag.free()
	var clinic_script: Script = load("res://world/clinic.gd")
	var reactions: Array = clinic_script.get_script_constant_map()["REACTIONS"]
	for k: StringName in [&"tickle", &"cross_heard", &"overmasked", &"wave"]:
		assert_has(reactions, k, "Clinic.REACTIONS (v3, builders)")
	var clinic: Node = (load(CLINIC) as PackedScene).instantiate()
	for m in ["put_down_basket", "give_croissant", "walk_out", "patient_name"]:
		assert_has_method(clinic, m, "Clinic (v3, builders)")
	clinic.free()
