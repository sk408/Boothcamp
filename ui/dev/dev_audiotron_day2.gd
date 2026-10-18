extends Node
## Dev gallery for the AudiOtron's Day 2 states (developer tool, builder A; never reachable from
## the game). Bonnie in the booth; the session is driven by the textbook (recommended_action())
## straight through its API, then screenshots of each teaching state:
## bone route, the Cross-Hearing Ghost, the masking deck, the plateau graph, overmasking, masked
## air and the finished audiogram with every symbol and the gap bridge.
##   timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy --fixed-fps 30 -- --scene=res://ui/dev/dev_audiotron_day2.tscn --shots=/abs/dir
## Optional: --only=bc,mask,... (shot groups), --day1 (a Day 1 Gus check instead).

const SCREEN_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const CLINIC_SCENE := "res://world/clinic.tscn"

var clinic: Node3D
var screen: CanvasLayer
var patient: PatientProfile
var _n := 0


func _ready() -> void:
	pass


func demo_start() -> void:
	var day1 := Game.cli_flag("day1")
	Game.settings["show_key_hints"] = true
	var pid := "gus" if day1 else "bonnie"
	Game.begin_visit(pid)
	Game.set_visit_flag("instructed", true)
	patient = Game.load_patient(pid) as PatientProfile
	if ResourceLoader.exists(CLINIC_SCENE):
		clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
		clinic.set("patient_id", pid)
		add_child(clinic)
		var cam: Camera3D = clinic.call("get_main_camera")
		if cam != null:
			cam.current = false
		clinic.call("put_on_earphones", true)
		clinic.call("sit")
	screen = (load(SCREEN_SCENE) as PackedScene).instantiate() as CanvasLayer
	add_child(screen)
	await _wait(0.5)
	if day1:
		await _day1()
	else:
		await _day2()
	await _wait(0.3)
	get_tree().quit(0)


func _s() -> AudiometrySession:
	return screen.get("session") as AudiometrySession


func _day1() -> void:
	Events.phase_changed.emit(&"audiometry", {})  # clears Hoot tips, like the level
	screen.call("start_test", patient, "right", true)
	await _wait(1.2)
	await _shot("d1_start")
	_drive("right", 3)
	await _wait(0.6)
	await _shot("d1_three_stamps")


func _day2() -> void:
	# air, both ears (Hoot speed in the game; here straight through the session)
	Events.phase_changed.emit(&"audiometry", {})  # clears Hoot tips, like the level
	screen.call("start_test", patient, "right", false, {"test": "ac", "hoot_turn_after": 99})
	_drive("right", 99)
	await _wait(3.5)
	Events.phase_changed.emit(&"audiometry", {})  # clears Hoot tips, like the level
	screen.call("start_test", patient, "left", false, {"test": "ac", "hoot_turn_after": 99})
	_drive("left", 99)
	await _wait(3.5)
	await _shot("d2_air_done")
	# unmasked bone, coached: the route button beckons
	if clinic != null:
		clinic.call("put_on_bone_oscillator", "right")
	Events.phase_changed.emit(&"audiometry", {})  # clears Hoot tips, like the level
	screen.call("start_test", patient, "right", true, {"test": "bc", "masking_controls": true, "hoot_turn_after": 99,
		"intro": "Bone time! B = bone. Same dance: down 10, up 5. Start at 1k."})
	await _wait(1.5)
	await _shot("d2_bc_route")
	_s().set_transducer(&"bone")
	screen.call("_refresh")
	await _wait(0.4)
	await _shot("d2_bc_bone_on")
	# a few beeps at 1 kHz until the Ghost answers
	var ghost := false
	for i in 8:
		var rec := _present()
		if bool(rec.get("responded", false)):
			ghost = true
			break
		_follow_level()
	await _wait(0.4)
	await _shot("d2_bc_ghost_fly" if ghost else "d2_bc_trail")
	await _wait(0.7)
	await _shot("d2_bc_ghost_boo" if ghost else "d2_bc_trail2")
	_drive("right", 2)
	await _wait(1.0)
	await _shot("d2_bc_two_stamps")
	_drive("right", 99)
	await _wait(3.5)
	await _shot("d2_bc_done")
	# masked bone, coached
	if clinic != null:
		clinic.call("put_on_masking_phone", "left")
	Events.phase_changed.emit(&"audiometry", {})  # clears Hoot tips, like the level
	screen.call("start_test", patient, "right", true, {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 99,
		"intro": "M = masking on. PgUp / PgDn move the noise. Find the flat line!"})
	await _wait(1.5)
	await _shot("d2_mask_needed")
	_s().toggle_mask()
	screen.call("_refresh")
	await _wait(0.4)
	await _shot("d2_mask_on_low")
	# noise to the starting level, then the dance until 2 of 3 raises
	_drive_until(func() -> bool: return int(_s().plateau_info()["steps"]) >= 2, 30)
	screen.call("_refresh")
	await _wait(0.3)
	await _shot("d2_plateau_2of3")
	_drive_until(func() -> bool: return bool(_s().plateau_info()["found"]), 30)
	screen.call("_refresh")
	await _wait(0.5)
	await _shot("d2_plateau_found")
	_drive("right", 1)
	await _wait(1.0)
	await _shot("d2_masked_first_store")
	# overmasking: crank the noise and beep (a gag, visual only)
	var s := _s()
	var keep := s.mask_db
	s.set_mask_level(s.overmask_limit_db() + 5)
	screen.call("_refresh")
	_present()
	await _wait(0.4)
	await _shot("d2_overmasked")
	s.set_mask_level(keep)
	screen.call("_refresh")
	_drive("right", 99)
	await _wait(3.5)
	await _shot("d2_bc_masked_done")
	# masked air
	if clinic != null:
		clinic.call("take_off_bone_oscillator")
		clinic.call("put_on_earphones", true)
	Events.phase_changed.emit(&"audiometry", {})  # clears Hoot tips, like the level
	screen.call("start_test", patient, "right", false, {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 99})
	await _wait(0.8)
	_drive_until(func() -> bool: return int(_s().plateau_info()["steps"]) >= 1, 30)
	screen.call("_refresh")
	await _wait(0.3)
	await _shot("d2_ac_masked_mid")
	_drive("right", 99)
	await _wait(3.8)
	await _shot("d2_all_done")


## Present one beep through the session (timing like a careful clinician). Returns its record.
func _present() -> Dictionary:
	var s := _s()
	_n += 1
	s.advance(AoAutoTester.GAPS[_n % AoAutoTester.GAPS.size()])
	screen.call("_tone_down")
	s.advance(AoAutoTester.DURATIONS[_n % AoAutoTester.DURATIONS.size()])
	screen.call("_tone_up")
	for i in 20:
		s.advance(0.1)
	screen.call("_refresh")
	var recs := s.measurement(s.ear, s.freq)
	return recs[-1] if not recs.is_empty() else {}


## Move the dial the way the textbook says after the last beep.
func _follow_level() -> void:
	var s := _s()
	for i in 20:
		var a := s.recommended_action()
		match a["action"]:
			&"louder":
				s.step_level(1)
			&"softer":
				s.step_level(-1)
			&"mask_louder":
				s.step_mask(1)
			&"mask_softer":
				s.step_mask(-1)
			_:
				return


## Follow the textbook until `stores` more stamps on this ear (or the ear is complete).
func _drive(ear: String, stores: int) -> void:
	var s := _s()
	var done := 0
	var guard := 0
	while guard < 800 and done < stores and not s.is_ear_complete(ear):
		guard += 1
		var did := _step(ear)
		if did == &"store":
			done += 1
	screen.call("_refresh")


func _drive_until(cond: Callable, max_steps: int) -> void:
	var guard := 0
	while guard < max_steps * 4 and not bool(cond.call()):
		guard += 1
		if _step(_s().ear) == &"store":
			return


func _step(ear: String) -> StringName:
	var s := _s()
	var rem := s.required_remaining(ear)
	if s.measurement(ear, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
		s.set_freq(rem[0])
		return &"jump"
	var a := s.recommended_action()
	var act: StringName = a["action"]
	match act:
		&"present":
			_present()
		&"louder":
			s.step_level(1)
		&"softer":
			s.step_level(-1)
		&"store":
			s.store()
		&"no_response":
			s.store_no_response()
		&"transducer":
			s.set_transducer(StringName(a["target"]))
		&"mask_toggle":
			s.toggle_mask()
		&"mask_louder":
			s.step_mask(1)
		&"mask_softer":
			s.step_mask(-1)
		_:
			s.advance(0.2)
	return act


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
