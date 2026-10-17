class_name Clinic
extends Node3D
## Clinic: the cheerful procedural 3D clinic with Grandpa Gus, Doris and Professor Hoot.
## Contract: CONTRACTS.md §6 (scene res://world/clinic.tscn, methods called by name).
## Registers with Stage so the AudiOtron can show the booth window without referencing world/.
## Listens to Events.patient_reaction (Gus reacts), Events.screen_shake (camera shake),
## Events.dialogue_line (whoever speaks flaps their mouth), Events.hoot_tip_shown (Hoot talks),
## Events.audiometry_started / audiometry_finished (booth "testing" lamp), tone_started/stopped.
## Methods marked (coroutine) can be awaited: await clinic.walk_in().
##
## Extras beyond §6 (story calls them by name; listed in world/INTEGRATION_NOTES.md):
##   doris_enter() (coroutine), doris_react(kind), gus_look(target), set_title_mode(on),
##   play_birdsong(), get_head_screen_position(), take_off_glasses() / put_on_glasses(),
##   put_on_hearing_aids(), get_muffle().
## (v3) patient_id (set before add_child: "bonnie" = Day 2), put_on_bone_oscillator(ear),
##   put_on_masking_phone(ear), take_off_bone_oscillator().

const Kit := preload("res://world/kit.gd")
const Room := preload("res://world/room.gd")
const Bean := preload("res://world/characters/bean.gd")
const Owl := preload("res://world/characters/owl.gd")
const GREY_SHADER := preload("res://world/shaders/grey_world.gdshader")

## Every reaction kind the patient understands (Events.patient_reaction / play_patient_reaction).
const REACTIONS: Array[StringName] = [
	&"heard", &"missed", &"false_alarm", &"too_loud_blast", &"startle", &"grooving", &"bored",
	&"straining", &"squint", &"yawn", &"cheer", &"confused", &"point_wrong_way", &"nod", &"wince",
]
## Camera shots for focus_camera(). (&"title" and &"fitting" are extras for the story.)
const SHOTS: Array[StringName] = [&"wide", &"door", &"desk", &"booth", &"ear_right", &"ear_left", &"face", &"otoscope", &"title", &"fitting"]
## Named spots Gus can walk to.
const SPOTS: Dictionary[StringName, Vector3] = {&"door": Vector3(-4.5, 0, -3.1), &"desk": Vector3(-2.85, 0, -1.45), &"booth": Vector3(3.7, 0, -2.75)}
## Which way Gus faces when he arrives at a spot (yaw, radians; 0 = toward the camera).
const SPOT_FACING: Dictionary[StringName, float] = {&"door": 0.0, &"desk": 0.55, &"booth": 0.0}
const BOOTH_VIEW_SIZE := Vector2i(512, 320)
const DORIS_SPOT := Vector3(-4.15, 0, -1.25)
const GUS_TURN_TO_DORIS := -0.35   # body yaw while chatting with Doris (head turns the rest)
const GUS_FACE_CAMERA := 0.15      # body yaw for the big "I can hear!" moment
const TITLE_GUS_SPOT := Vector3(1.05, 0, 0.35)
const TITLE_IDLES: Array[StringName] = [&"grooving", &"nod", &"cheer", &"confused", &"grooving"]

signal action_finished(action: StringName)

var gus: Node3D
var doris: Node3D
var hoot: Node3D
var refs: Dictionary = {}
var _rig: Node3D
var _cam: Camera3D
var _env: Environment
var _booth_vp: SubViewport
var _booth_cam: Camera3D
var _grey_layer: CanvasLayer
var _grey_rect: ColorRect
var _grey_mat: ShaderMaterial
var _saturation := 1.0
var _phones: Node3D
var _t := 0.0
var _shake_left := 0.0
var _shake_strength := 0.0
var _drift := true
var _title_mode := false
var _tick := 0
var _glasses_off := false
var _look_lock: StringName = &""
var _title_idle := 0.0
## (v3) Which bean walks in: "" / "gus" = Grandpa Gus, "bonnie" = Bonnie. Set before add_child.
## (The patient node keeps the name `gus` so every existing call keeps working.)
var patient_id := ""
var _bone: Node3D
var _mask_phone: Node3D


func _enter_tree() -> void:
	Stage.register_clinic(self)


func _exit_tree() -> void:
	Stage.unregister_clinic(self)


func _ready() -> void:
	_build_environment()
	refs = Room.build(self, Game.has_upgrade("comfy_chair"))
	gus = Bean.new()
	gus.build(Bean.spec_for(patient_id) if patient_id != "" else Bean.GUS)
	add_child(gus)
	gus.position = SPOTS[&"door"]
	doris = Bean.new()
	doris.build(Bean.DORIS)
	add_child(doris)
	doris.position = refs["door_spot_outside"]
	doris.visible = false
	hoot = Owl.new()
	add_child(hoot)
	hoot.position = Room.MONITOR_POS + Vector3(0, 0.84, -0.02)
	hoot.rotation.y = -0.25
	_build_booth_view()
	_build_grey_overlay()
	focus_camera(&"wide", 0.0)
	Events.patient_reaction.connect(play_patient_reaction)
	Events.screen_shake.connect(_on_shake)
	Events.dialogue_line.connect(_on_dialogue_line)
	Events.hoot_tip_shown.connect(_on_hoot_tip)
	Events.audiometry_started.connect(func(_p: String, _e: String, _c: bool) -> void: _set_booth_lamp(true))
	Events.audiometry_finished.connect(func(_r: Dictionary) -> void: _set_booth_lamp(false))
	Events.tone_started.connect(func(_e: String, _f: int, _d: int) -> void: _set_tone_lamp(true))
	Events.tone_stopped.connect(func(_e: String, _f: int, _d: int, _s: float) -> void: _set_tone_lamp(false))
	_set_tone_lamp(false)


## Standalone boot (main.gd --scene=res://world/clinic.tscn): a showcase of every animation.
## With --shots it saves one picture per beat (with the booth view as picture-in-picture).
func demo_start() -> void:
	focus_camera(&"door", 0.0)
	await _wait(0.4)
	Events.screenshot_requested.emit("demo_door")
	await walk_in()
	Events.screenshot_requested.emit("demo_arrived")
	await focus_camera(&"desk", 0.8)
	Events.dialogue_line.emit("Gus", "Everyone MUMBLES these days!")
	await _wait(0.5)
	Events.screenshot_requested.emit("demo_desk_talk")
	await _wait(1.1)
	hoot_emote(&"hop")
	Events.dialogue_line.emit("Hoot", "Welcome to Booth Camp!")
	await _wait(0.3)
	Events.screenshot_requested.emit("demo_hoot_hop")
	await _wait(1.1)
	focus_camera(&"wide", 1.0)
	var done := [false]
	var go := func() -> void:
		await sit()
		done[0] = true
	go.call()
	await _wait(2.0)
	Events.screenshot_requested.emit("demo_wide_walk")
	while not done[0]:
		await get_tree().process_frame
	await focus_camera(&"booth", 0.8)
	Events.screenshot_requested.emit("demo_booth_shot")
	await focus_camera(&"face", 0.8)
	put_on_earphones(true)
	await _wait(0.8)
	Events.screenshot_requested.emit("demo_earphones")
	_demo_pip()
	set_booth_view_active(true)
	for k: StringName in REACTIONS:
		play_patient_reaction(k, {"ear": "right", "intensity": 1.0})
		await _wait(0.35)
		Events.screenshot_requested.emit("demo_react_" + String(k))
		await _wait(1.5)
	await stand()
	await walk_to(&"desk")
	focus_camera(&"fitting", 0.0)
	set_world_saturation(0.0)
	await doris_enter()
	Events.screenshot_requested.emit("demo_grey_doris")
	var t := create_tween()
	t.tween_method(set_world_saturation, 0.0, 1.0, 1.6)
	await _wait(0.8)
	Events.screenshot_requested.emit("demo_colour_wave")
	await t.finished
	play_patient_reaction(&"cheer")
	doris_react(&"nod")
	await _wait(0.4)
	Events.screenshot_requested.emit("demo_fitting_cheer")


func _demo_pip() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var frame := Panel.new()
	frame.position = Vector2(16, 16)
	frame.size = Vector2(BOOTH_VIEW_SIZE) * 0.62 + Vector2(12, 12)
	layer.add_child(frame)
	var tr := TextureRect.new()
	tr.texture = get_booth_texture()
	tr.position = Vector2(22, 22)
	tr.size = Vector2(BOOTH_VIEW_SIZE) * 0.62
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(tr)


func _process(delta: float) -> void:
	_t += delta
	# camera life: a gentle handheld drift, plus shake
	var off := Vector3.ZERO
	if _drift and not bool(Game.settings.get("reduced_motion", false)):
		off += Vector3(sin(_t * 0.37) * 0.025, sin(_t * 0.53) * 0.018, 0.0)
	if _shake_left > 0.0:
		_shake_left -= delta
		off += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.07 * _shake_strength * clampf(_shake_left * 4.0, 0.0, 1.0)
	_cam.position = off
	# clock ticks once a game second
	var tick := int(_t)
	if tick != _tick:
		_tick = tick
		var minute: Node3D = refs["clock_minute"]
		minute.rotation.z -= TAU / 60.0
		var hour: Node3D = refs["clock_hour"]
		hour.rotation.z -= TAU / 720.0
	# Bubbles the fish
	var fish: Node3D = refs["fish"]
	fish.position.x = sin(_t * 0.45) * 0.42
	fish.position.y = 1.18 + sin(_t * 1.3) * 0.05
	fish.rotation.y = 0.0 if cos(_t * 0.45) > 0.0 else PI
	if _grey_layer.visible:
		_grey_mat.set_shader_parameter("center", _head_uv())
	# title screen: Gus does a little something every few seconds
	if _title_mode:
		_title_idle -= delta
		if _title_idle <= 0.0:
			_title_idle = 3.5 + randf() * 2.0
			gus.call("react", TITLE_IDLES[randi() % TITLE_IDLES.size()], {})
			if randf() < 0.4:
				hoot.call("emote", &"hop")


# ---------------------------------------------------------------- public API (§6.1)

## (coroutine) Door bursts open, Gus shuffles in to the desk with his squeaky walker.
func walk_in() -> void:
	gus.position = refs["door_spot_outside"]
	gus.rotation.y = 0.0
	gus.visible = true
	await _door_burst()
	await gus.call("walk_path", [refs["door_spot_inside"], SPOTS[&"desk"]], 1.25)
	_door_close()
	await gus.call("turn_to", SPOT_FACING[&"desk"], 0.35)
	gus.call("look_toward", hoot.global_position)
	action_finished.emit(&"walk_in")


## (coroutine) Walk to a named spot (SPOTS). Routes through the booth door when needed.
func walk_to(spot: StringName, duration: float = 2.2) -> void:
	if bool(gus.get("seated")):
		await stand()
	var target: Vector3 = SPOTS.get(spot, gus.position)
	var path := _route(gus.position, target)
	if path.is_empty():
		return
	var length := 0.0
	var prev := gus.position
	for p in path:
		length += prev.distance_to(p)
		prev = p
	var speed := clampf(length / maxf(0.3, duration), 0.9, 1.7)
	var through_door := _in_booth(gus.position) != _in_booth(target)
	if through_door:
		_booth_door_open(true)
	await gus.call("walk_path", path, speed)
	if through_door:
		_booth_door_open(false)
	await gus.call("turn_to", SPOT_FACING.get(spot, 0.0), 0.3)
	action_finished.emit(&"walk_to")


## (coroutine) Sit in the booth chair (walks there first if needed).
func sit() -> void:
	if bool(gus.get("seated")):
		return
	var chair: Vector3 = SPOTS[&"booth"]
	var front: Vector3 = refs["chair_front"]
	if gus.position.distance_to(chair) > 0.2:
		var path := _route(gus.position, front)
		_booth_door_open(true)
		await gus.call("walk_path", path, 1.4)
		_booth_door_open(false)
		await gus.call("turn_to", 0.0, 0.3)
		var t := create_tween()
		t.tween_property(gus, "position", chair, 0.35).set_trans(Tween.TRANS_SINE)
		await t.finished
	await gus.call("sit_down", 0.2, Vector3(0.85, 0, 0.15))
	action_finished.emit(&"sit")


## (coroutine)
func stand() -> void:
	gus.call("set_holding_button", false)
	await gus.call("stand_up")
	if gus.position.distance_to(SPOTS[&"booth"]) < 0.3:
		var t := create_tween()
		t.tween_property(gus, "position", refs["chair_front"] as Vector3, 0.3)
		await t.finished


## (coroutine) Move the main camera to a shot (SHOTS). duration 0 = cut. Await it to know
## the camera has arrived (e.g. before projecting ear positions for drag targets).
func focus_camera(shot: StringName, duration: float = 0.8) -> void:
	var target := _shot_transform(shot)
	_cam.fov = 50.0
	if duration <= 0.0:
		_rig.global_transform = target
		return
	var t := create_tween()
	t.tween_property(_rig, "global_transform", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func put_on_earphones(red_on_right: bool = true) -> void:
	take_off_earphones()
	var head: Node3D = gus.get("parts")["head"]
	var hc: Vector3 = gus.get("parts")["head_center"]
	_phones = Node3D.new()
	_phones.name = "Earphones"
	_phones.position = hc
	head.add_child(_phones)
	var band := Kit.arc_tube(_phones, 0.41, 0.032, 8, 172, 12, Color("#4d4d5c"), {"outline": 0.01})
	band.position = Vector3(0, 0.0, -0.02)
	Kit.box(_phones, Vector3(0.22, 0.05, 0.06), Vector3(0, 0.415, -0.02), Color("#ffd23f"), {"outline": 0.008})
	for side: int in [-1, 1]:
		var his_right := side < 0
		var red := his_right == red_on_right
		var col := Color("#e5383b") if red else Color("#2d6cdf")
		var cup := Node3D.new()
		cup.position = Vector3(0.425 * side, -0.02, 0.0)
		_phones.add_child(cup)
		var shell := Kit.cylinder(cup, 0.13, 0.14, 0.1, Vector3(0.02 * side, 0, 0), col, {"outline": 0.012}, 20)
		shell.rotation.z = PI / 2.0
		var cushion := Kit.torus(cup, 0.06, 0.13, Vector3(-0.045 * side, 0, 0), Color("#2e2442"), {"outline": 0.0}, 20, 6)
		cushion.rotation.z = PI / 2.0
		Kit.label(cup, "R" if red else "L", Vector3(0.075 * side, 0, 0), 48, Color.WHITE, 0, 700).rotation.y = PI / 2.0 * side
		# fly in from outside, squash on landing
		var rest := cup.position
		cup.position = rest + Vector3(0.6 * side, 0.4, 0.2)
		cup.scale = Vector3.ONE * 0.6
		var t := cup.create_tween()
		t.tween_interval(0.08 * (side + 1))
		t.tween_property(cup, "position", rest, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(cup, "scale", Vector3.ONE, 0.22)
		t.tween_property(cup, "scale", Vector3(0.7, 1.2, 1.2), 0.06)
		t.tween_property(cup, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	band.scale = Vector3(1.2, 1.4, 1.2)
	var tb := band.create_tween()
	tb.tween_property(band, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"pop", 1.1, -6.0)
	get_tree().create_timer(0.25).timeout.connect(Sfx.play.bind(&"pop", 0.9, -6.0))
	gus.call("set_holding_button", true)


func take_off_earphones() -> void:
	if _phones and is_instance_valid(_phones):
		_phones.queue_free()
	_phones = null


## Play one of REACTIONS. data: {"ear": "right", "intensity": 0..1}. Unknown kinds are ignored.
func play_patient_reaction(kind: StringName, data: Dictionary = {}) -> void:
	if not REACTIONS.has(kind) or gus == null:
		return
	gus.call("react", kind, data)
	match kind:
		&"heard":
			_booth_zoom(0.95)
		&"too_loud_blast":
			hoot.call("emote", &"gasp")
			_booth_zoom(1.1)
		&"cheer":
			hoot.call("emote", &"hop")
		&"point_wrong_way":
			hoot.call("emote", &"facepalm")


## 0 = grey and muffled world .. 1 = full colour (fitting). The colour returns as a wave
## that starts at Gus's head and sweeps outward.
func set_world_saturation(amount: float) -> void:
	var was := _saturation
	_saturation = clampf(amount, 0.0, 1.0)
	_env.adjustment_saturation = lerpf(0.55, 1.0, _saturation) if _saturation < 1.0 else 1.0
	if _saturation >= 0.999:
		_grey_layer.visible = false
		if was < 0.6:
			play_birdsong()
		return
	_grey_layer.visible = true
	_grey_mat.set_shader_parameter("center", _head_uv())
	_grey_mat.set_shader_parameter("radius", lerpf(-0.25, 2.3, _saturation))


## How muffled the world sounds: 0 clear .. 1 fully muffled (the grey fitting world).
## The muffling is done at the sound sources (quieter, lower world sounds; the story's dialogue
## voice switches to a muffled bank), never with bus effects: adding an effect to a bus at runtime
## deadlocked AudioServer in headless test runs.
func get_muffle() -> float:
	return 0.0 if _saturation >= 0.999 else 1.0 - _saturation


func get_booth_texture() -> Texture2D:
	return _booth_vp.get_texture()


func set_booth_view_active(active: bool) -> void:
	_booth_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


## Screen position of Gus's ear through the main camera (for drag targets).
func get_ear_screen_position(ear: String) -> Vector2:
	return _cam.unproject_position(gus.call("ear_world", ear))


func get_patient() -> Node3D:
	return gus


func get_main_camera() -> Camera3D:
	return _cam


## Hoot body language: &"wing_up", &"facepalm", &"nod", &"hop" (+ &"gasp", &"cheer").
func hoot_emote(kind: StringName) -> void:
	hoot.call("emote", kind)


# ---------------------------------------------------------------- extras for the story

## (coroutine) Doris bursts through the waiting-room door holding a plate.
func doris_enter() -> void:
	doris.visible = true
	doris.position = refs["door_spot_outside"]
	doris.rotation.y = 0.0
	await _door_burst()
	await doris.call("walk_path", [refs["door_spot_inside"], DORIS_SPOT], 1.6)
	_door_close()
	await doris.call("turn_to", deg_to_rad(25.0), 0.3)
	doris.call("look_toward", gus.call("head_world"))
	gus.call("look_toward", doris.call("head_world"))


func doris_react(kind: StringName) -> void:
	if doris.visible:
		doris.call("react", kind, {})


## Gus turns his head toward &"hoot", &"doris", or anything else = straight ahead (the camera).
## Standing, he also turns his body (toward Doris, or to face the camera).
## Looking at Doris or straight ahead holds until gus_look(&"hoot") (Hoot's lines won't turn him).
func gus_look(target: StringName) -> void:
	_look_lock = &"" if target == &"hoot" else target
	var standing := not bool(gus.get("seated"))
	match target:
		&"hoot":
			gus.call("look_toward", hoot.global_position)
		&"doris":
			if standing:
				# Doris stands beside him: turn the body a little so the head can finish the job.
				_turn_then_look(GUS_TURN_TO_DORIS)
			else:
				gus.call("look_toward", doris.call("head_world"))
		_:
			if standing:
				gus.call("turn_to", GUS_FACE_CAMERA, 0.4)
			gus.call("look_toward", null)


func _turn_then_look(yaw: float) -> void:
	await gus.call("turn_to", yaw, 0.35)
	if _look_lock == &"doris":
		gus.call("look_toward", doris.call("head_world"))


## Title-screen backdrop: Gus waits at the desk, the camera drifts on the title shot.
func set_title_mode(on: bool) -> void:
	_title_mode = on
	if on:
		gus.position = TITLE_GUS_SPOT
		gus.rotation.y = -0.75
		gus.visible = true
		gus.call("look_toward", null)
		focus_camera(&"title", 0.0)


func play_birdsong() -> void:
	var pitches := [1.0, 1.25, 1.12, 1.5, 1.33, 1.18, 1.6, 1.4]
	for i in pitches.size():
		get_tree().create_timer(0.16 * i + (0.25 if i > 3 else 0.0)).timeout.connect(Sfx.play.bind(&"chirp", pitches[i], -9.0))
	Kit.burst(self, gus.call("head_world") as Vector3 + Vector3(0, 0.3, 0), [Color("#ffd23f"), Color("#ff9f1c"), Color("#5bc8a3"), Color("#bfe6ff")], 30, 2.4, -1.5, 0.05, 1.4)


func get_head_screen_position() -> Vector2:
	return _cam.unproject_position(gus.call("head_world"))


## Glasses off before the earphones (real practice: they lift the cushions).
func take_off_glasses() -> void:
	var g: Node3D = gus.get("parts").get("glasses")
	if g == null or _glasses_off:
		return
	_glasses_off = true
	var t := g.create_tween()
	t.tween_property(g, "position:y", g.position.y + 0.25, 0.2).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(g, "scale", Vector3.ONE * 0.2, 0.25)
	t.tween_callback(func() -> void: g.visible = false)
	Sfx.play(&"whoosh", 1.3, -10.0)


func put_on_glasses() -> void:
	var g: Node3D = gus.get("parts").get("glasses")
	if g == null or not _glasses_off:
		return
	_glasses_off = false
	g.visible = true
	g.scale = Vector3.ONE * 0.3
	var hc: Vector3 = gus.get("parts")["head_center"]
	g.position = hc + Vector3(0, 0.055, 0.34)
	var t := g.create_tween()
	t.tween_property(g, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK)


## Fitting teaser: two tiny teal behind-the-ear aids pop onto Gus with a sparkle.
func put_on_hearing_aids() -> void:
	var head: Node3D = gus.get("parts")["head"]
	var hc: Vector3 = gus.get("parts")["head_center"]
	var old := head.get_node_or_null("HearingAids")
	if old:
		old.queue_free()
	var aids := Node3D.new()
	aids.name = "HearingAids"
	aids.position = hc
	head.add_child(aids)
	for side: int in [-1, 1]:
		var aid := Node3D.new()
		aid.position = Vector3(0.44 * side, 0.06, -0.07)
		aids.add_child(aid)
		var shell := Kit.capsule(aid, 0.035, 0.15, Vector3.ZERO, Color("#36c2b4"), {"outline": 0.008})
		shell.rotation.x = -0.35
		Kit.sphere(aid, 0.016, Vector3(-0.012 * side, -0.06, 0.07), Color("#fffbf2"), Vector3.ONE, {"outline": 0.004}, 8)
		Kit.sphere(aid, 0.012, Vector3(0.0, 0.06, 0.02), Color("#ffd23f"), Vector3.ONE, {"unshaded": true}, 8)
		aid.scale = Vector3.ONE * 0.05
		var t := aid.create_tween()
		t.tween_interval(0.12 * (side + 1))
		t.tween_property(aid, "scale", Vector3.ONE * 1.25, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(aid, "scale", Vector3.ONE, 0.2)
	Kit.burst(head, hc + Vector3(0, 0.1, 0.1), [Color("#36d6e7"), Color("#ffd23f"), Color("#fffbf2")], 24, 1.6, -0.8, 0.04, 1.0)
	Sfx.play(&"sparkle", 1.0, -6.0)


## (v3) The bone oscillator: a thin headband over the crown and the little vibrator box pressed on
## the mastoid, just behind the test ear (never touching the pinna).
func put_on_bone_oscillator(ear: String = "right") -> void:
	take_off_bone_oscillator()
	take_off_earphones()
	var head: Node3D = gus.get("parts")["head"]
	var hc: Vector3 = gus.get("parts")["head_center"]
	var side := -1.0 if ear == "right" else 1.0
	_bone = Node3D.new()
	_bone.name = "BoneOscillator"
	_bone.position = hc
	head.add_child(_bone)
	var band := Kit.arc_tube(_bone, 0.43, 0.02, 4, 176, 14, Color("#8d94a6"), {"outline": 0.008})
	band.rotation.x = -0.42
	var box := Node3D.new()
	box.position = Vector3(0.33 * side, -0.07, -0.13)
	_bone.add_child(box)
	Kit.box(box, Vector3(0.07, 0.1, 0.08), Vector3.ZERO, Color("#5c6370"), {"outline": 0.01})
	Kit.sphere(box, 0.022, Vector3(0.03 * side, 0.02, 0.03), Color("#ffd23f"), Vector3.ONE, {"unshaded": true}, 8)
	Kit.capsule(box, 0.008, 0.3, Vector3(0, -0.18, 0), Color("#4d4d5c"), {"outline": 0.0}, 6)
	Kit.sphere(_bone, 0.04, Vector3(-0.4 * side, 0.02, -0.12), Color("#8d94a6"), Vector3(0.6, 1.0, 1.0), {"outline": 0.008}, 10)
	box.scale = Vector3.ONE * 0.3
	var t := box.create_tween()
	t.tween_property(box, "scale", Vector3(1.25, 0.8, 1.25), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(box, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Sfx.play(&"pop", 0.8, -6.0)
	gus.call("set_holding_button", true)


## (v3) One earphone on the non-test ear, for the masking noise during bone tests.
func put_on_masking_phone(ear: String = "left") -> void:
	if _mask_phone and is_instance_valid(_mask_phone):
		_mask_phone.queue_free()
	var head: Node3D = gus.get("parts")["head"]
	var hc: Vector3 = gus.get("parts")["head_center"]
	var side := -1.0 if ear == "right" else 1.0
	_mask_phone = Node3D.new()
	_mask_phone.name = "MaskingPhone"
	_mask_phone.position = hc
	head.add_child(_mask_phone)
	var col := Color("#e5383b") if ear == "right" else Color("#2d6cdf")
	var cup := Node3D.new()
	cup.position = Vector3(0.425 * side, -0.02, 0.0)
	_mask_phone.add_child(cup)
	var shell := Kit.cylinder(cup, 0.13, 0.14, 0.1, Vector3(0.02 * side, 0, 0), col, {"outline": 0.012}, 20)
	shell.rotation.z = PI / 2.0
	Kit.label(cup, "R" if ear == "right" else "L", Vector3(0.075 * side, 0, 0), 48, Color.WHITE, 0, 700).rotation.y = PI / 2.0 * side
	var strap := Kit.arc_tube(_mask_phone, 0.41, 0.026, 90.0 - 82.0 * side, 90.0, 8, Color("#4d4d5c"), {"outline": 0.01})
	strap.position = Vector3(0, 0, 0.04)
	cup.scale = Vector3.ONE * 0.4
	var t := cup.create_tween()
	t.tween_property(cup, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"pop", 1.0, -6.0)


func take_off_bone_oscillator() -> void:
	for n: Node3D in [_bone, _mask_phone]:
		if n and is_instance_valid(n):
			n.queue_free()
	_bone = null
	_mask_phone = null


# ---------------------------------------------------------------- construction

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color("#ffe9c7")
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color.WHITE
	_env.ambient_light_energy = 0.4
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.adjustment_enabled = true
	_env.adjustment_saturation = 1.0
	_env.adjustment_brightness = 1.0
	_env.adjustment_contrast = 1.0
	we.environment = _env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation_degrees = Vector3(-52, -28, 0)
	key.light_energy = 1.0
	key.light_color = Color("#fff6e8")
	key.shadow_enabled = false
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_energy = 0.18
	fill.light_color = Color("#d8e6ff")
	fill.shadow_enabled = false
	add_child(fill)
	_rig = Node3D.new()
	_rig.name = "CameraRig"
	add_child(_rig)
	_cam = Camera3D.new()
	_cam.name = "MainCamera"
	_cam.fov = 50
	_rig.add_child(_cam)
	_cam.current = true


func _build_booth_view() -> void:
	_booth_vp = SubViewport.new()
	_booth_vp.name = "BoothView"
	_booth_vp.size = BOOTH_VIEW_SIZE
	_booth_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_booth_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_booth_vp)
	_booth_cam = Camera3D.new()
	_booth_cam.name = "BoothCamera"
	_booth_cam.fov = 34.0
	_booth_vp.add_child(_booth_cam)
	# just outside the booth window, looking in at the patient's head and shoulders
	var chair: Vector3 = SPOTS[&"booth"]
	var from := Vector3(chair.x - 0.25, 1.62, Room.BOOTH_Z1 + 0.55)
	var look := Vector3(chair.x, 1.42, chair.z)
	_booth_cam.transform = Transform3D(Basis.looking_at(look - from, Vector3.UP), from)
	_booth_cam.current = true


func _build_grey_overlay() -> void:
	_grey_layer = CanvasLayer.new()
	_grey_layer.name = "GreyWorld"
	_grey_layer.layer = 1
	add_child(_grey_layer)
	_grey_rect = ColorRect.new()
	_grey_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_grey_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grey_mat = ShaderMaterial.new()
	_grey_mat.shader = GREY_SHADER
	_grey_rect.material = _grey_mat
	_grey_layer.add_child(_grey_rect)
	_grey_layer.visible = false


# ---------------------------------------------------------------- internals

func _shot_transform(shot: StringName) -> Transform3D:
	var head: Vector3 = gus.call("head_world") if gus else Vector3(0, 1.5, 0)
	var from := Vector3(0.2, 2.6, 6.2)
	var look := Vector3(0.2, 1.3, -1.8)
	match shot:
		&"door":
			from = Vector3(-2.7, 1.75, 0.9)
			look = Vector3(-4.5, 1.25, -3.6)
		&"desk":
			from = Vector3(-1.35, 1.8, 2.75)
			look = Vector3(-1.4, 1.3, -1.3)
		&"booth":
			from = Vector3(3.2, 1.9, 3.1)
			look = Vector3(3.7, 1.25, -2.3)
		&"ear_right":
			from = head + Vector3(-1.2, 0.12, 0.6)
			look = head + Vector3(-0.3, 0, 0)
		&"ear_left":
			from = head + Vector3(1.2, 0.12, 0.6)
			look = head + Vector3(0.3, 0, 0)
		&"face":
			from = head + Vector3(0, 0.05, 2.2)
			look = head + Vector3(0, -0.2, 0)
		&"otoscope":
			from = head + Vector3(-0.85, 0.08, 0.35)
			look = head + Vector3(-0.36, 0, 0)
		&"title":
			from = Vector3(-3.6, 2.35, 3.6)
			look = Vector3(-0.6, 1.35, -1.8)
		&"fitting":
			from = Vector3(-3.0, 1.75, 2.4)
			look = Vector3(-3.45, 1.2, -1.5)
		&"fitting_close":
			# push-in on Gus from the fitting angle (the "DISHES?" moment)
			from = head.lerp(Vector3(-3.0, 1.75, 2.4), 0.42)
			look = head + Vector3(0, -0.12, 0)
	return Transform3D(Basis.looking_at(look - from, Vector3.UP), from)


func _in_booth(p: Vector3) -> bool:
	return p.x > Room.BOOTH_X0 and p.z < Room.BOOTH_Z1 and p.z > Room.BOOTH_Z0


func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var path: Array[Vector3] = []
	var a := _in_booth(from)
	var b := _in_booth(to)
	if a and not b:
		path.append(refs["booth_door_inside"])
		path.append(refs["booth_door_outside"])
	elif b and not a:
		path.append(refs["booth_door_outside"])
		path.append(refs["booth_door_inside"])
	path.append(to)
	return path


func _door_burst() -> void:
	var door: Node3D = refs["door"]
	var t := create_tween()
	t.tween_property(door, "rotation:y", deg_to_rad(-118.0), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(door, "rotation:y", deg_to_rad(-96.0), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sfx(&"door", 1.0, -2.0)
	get_tree().create_timer(0.14).timeout.connect(func() -> void:
		Events.screen_shake.emit(0.35, 0.25)
		Kit.burst(self, Vector3(-4.6, 0.3, -3.6), [Color("#fff3dc"), Color("#f7d9b0"), Color("#ffe2b8")], 18, 1.6, -2.0, 0.08, 0.9, Vector3(0, 0.6, 1), 50.0))
	await _wait(0.25)


func _door_close() -> void:
	var door: Node3D = refs["door"]
	var t := create_tween()
	t.tween_interval(0.4)
	t.tween_property(door, "rotation:y", 0.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	t.tween_callback(_sfx.bind(&"thunk", 0.9, -10.0))


func _booth_door_open(open: bool) -> void:
	var door: Node3D = refs["booth_door"]
	var t := create_tween()
	if open:
		t.tween_property(door, "rotation:y", deg_to_rad(-105.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_sfx(&"whoosh", 0.7, -12.0)
	else:
		t.tween_interval(0.2)
		t.tween_property(door, "rotation:y", 0.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(_sfx.bind(&"thunk", 0.7, -8.0))


func _set_booth_lamp(on: bool) -> void:
	var lamp: MeshInstance3D = refs["booth_lamp"]
	lamp.material_override = refs["booth_lamp_on"] if on else refs["booth_lamp_off"]
	(refs["booth_quiet"] as Label3D).visible = on


func _set_tone_lamp(on: bool) -> void:
	var lamp: Node3D = refs["tone_lamp"]
	lamp.visible = on


func _booth_zoom(scale_fov: float) -> void:
	if _booth_cam == null or bool(Game.settings.get("reduced_motion", false)):
		return
	var t := _booth_cam.create_tween()
	t.tween_property(_booth_cam, "fov", 34.0 * scale_fov, 0.12).set_trans(Tween.TRANS_SINE)
	t.tween_property(_booth_cam, "fov", 34.0, 0.5).set_trans(Tween.TRANS_SINE)


func _on_shake(strength: float, duration: float) -> void:
	if bool(Game.settings.get("reduced_motion", false)):
		strength *= 0.25
	_shake_strength = clampf(strength, 0.0, 1.0)
	_shake_left = maxf(0.05, duration)


func _on_dialogue_line(speaker: String, text: String) -> void:
	var secs := clampf(text.length() / (45.0 * maxf(0.2, float(Game.settings.get("text_speed", 1.0)))), 0.5, 5.0)
	match speaker:
		"Gus":
			gus.call("talk", secs)
		"Doris":
			if doris.visible:
				doris.call("talk", secs)
		"Hoot":
			hoot.call("talk", secs)
			if not bool(gus.get("seated")) and _look_lock == &"":
				gus.call("look_toward", hoot.global_position)


func _on_hoot_tip(tip: Dictionary) -> void:
	var words := String(tip.get("text", "")).split(" ", false).size()
	hoot.call("talk", clampf(0.6 + words * 0.12, 0.8, 2.5))


func _head_uv() -> Vector2:
	var vp := get_viewport().get_visible_rect().size
	if not _cam.is_inside_tree() or _cam.is_position_behind(gus.call("head_world")):
		return Vector2(0.5, 0.45)
	var p := _cam.unproject_position(gus.call("head_world"))
	return Vector2(p.x / vp.x, p.y / vp.y)


## World sound effects go through here so the grey world sounds a little muffled.
func _sfx(sound: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var m := get_muffle()
	Sfx.play(sound, pitch, volume_db - 3.0 * m)  # a touch quieter; his loss is about clarity, not pitch


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
