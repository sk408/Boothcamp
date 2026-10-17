extends Node3D
## Professor Hoot's 3D body (world-internal): a round barn owl with a heart-shaped face,
## lopsided ear tufts, a graduation cap and half-moon spectacles. Perches on the AudiOtron.
## Cosmetic only: the tip queue lives in the Hoot autoload. Bobs and flaps her beak when talking.

const Kit := preload("res://world/kit.gd")
const FaceRig := preload("res://world/characters/face_rig.gd")
const FACE_SHADER := preload("res://world/shaders/toon_face.gdshader")

const FEATHER := Color("#d9a066")
const FEATHER_DARK := Color("#b9773f")
const BELLY := Color("#fff1de")
const BEAK := Color("#ff9f1c")
const CAP := Color("#2e2442")

var parts: Dictionary = {}
var face: FaceRig
var _t := 0.0
var _talk_left := 0.0
var _blink_t := 1.5
var _blink_left := 0.0
var _expr_left := 0.0
var _idle_trick_t := 14.0
var _tweens: Dictionary = {}


func _ready() -> void:
	name = "Hoot"
	face = FaceRig.new(&"owl")
	add_child(face)
	var bob := Node3D.new()
	bob.name = "Bob"
	add_child(bob)
	parts["bob"] = bob
	var spin := Node3D.new()
	spin.name = "Spin"
	bob.add_child(spin)
	parts["spin"] = spin
	var bc := Vector3(0, 0.26, 0)
	# body with the face painted on the upper front
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	sm.radial_segments = 26
	sm.rings = 13
	var mat := ShaderMaterial.new()
	mat.shader = FACE_SHADER
	mat.set_shader_parameter("albedo", FEATHER)
	mat.set_shader_parameter("shade", Kit.auto_shade(FEATHER))
	mat.set_shader_parameter("face_tex", face.get_texture())
	mat.set_shader_parameter("face_size", 0.44)
	mat.set_shader_parameter("face_offset", Vector2(0.0, 0.055))
	mat.set_shader_parameter("face_front", 0.02)
	mat.next_pass = Kit.outline_material(0.014)
	var body := Kit.mesh(spin, sm, bc, mat, Vector3(1.0, 1.04, 0.94))
	parts["body"] = body
	# fluffy cream belly with a few speckles
	Kit.sphere(spin, 0.17, bc + Vector3(0, -0.1, 0.12), BELLY, Vector3(1.0, 0.9, 0.6), {"outline": 0.0}, 18)
	for p: Vector3 in [Vector3(-0.05, -0.08, 0.215), Vector3(0.06, -0.13, 0.205), Vector3(0.0, -0.17, 0.19), Vector3(-0.08, -0.15, 0.19)]:
		Kit.sphere(spin, 0.012, bc + p, FEATHER_DARK, Vector3.ONE, {"outline": 0.0}, 6)
	# beak (upper fixed, lower flaps)
	var upper := Kit.cylinder(spin, 0.0, 0.038, 0.08, bc + Vector3(0, 0.035, 0.245), BEAK, {"outline": 0.008}, 10)
	upper.rotation.x = PI * 0.62
	var lower_pivot := Node3D.new()
	lower_pivot.position = bc + Vector3(0, 0.02, 0.235)
	spin.add_child(lower_pivot)
	parts["beak_lower"] = lower_pivot
	var lower := Kit.cylinder(lower_pivot, 0.0, 0.025, 0.05, Vector3(0, -0.012, 0.012), BEAK.darkened(0.15), {"outline": 0.006}, 8)
	lower.rotation.x = PI * 0.75
	# half-moon spectacles under the eyes
	var specs := Node3D.new()
	specs.position = bc + Vector3(0, 0.07, 0.235)
	spin.add_child(specs)
	parts["specs"] = specs
	for side: int in [-1, 1]:
		var arc := Kit.arc_tube(specs, 0.06, 0.007, 190, 350, 6, Color("#ffd23f"), {"outline": 0.0})
		arc.position = Vector3(0.1 * side, 0.0, 0.0)
	Kit.box(specs, Vector3(0.06, 0.012, 0.012), Vector3(0, 0.0, 0.0), Color("#ffd23f"), {"outline": 0.0})
	# lopsided ear tufts (real barn owls are asymmetric, she is proud of it)
	var tl := Kit.cylinder(spin, 0.0, 0.055, 0.15, bc + Vector3(0.13, 0.23, 0.02), FEATHER_DARK, {"outline": 0.01}, 8)
	tl.rotation.z = -0.35
	parts["tuft_l"] = tl
	var tr := Kit.cylinder(spin, 0.0, 0.05, 0.11, bc + Vector3(-0.15, 0.18, 0.03), FEATHER_DARK, {"outline": 0.01}, 8)
	tr.rotation.z = 0.85
	parts["tuft_r"] = tr
	# wings
	for side: int in [-1, 1]:
		var pivot := Node3D.new()
		pivot.position = bc + Vector3(0.2 * side, 0.08, -0.01)
		spin.add_child(pivot)
		Kit.sphere(pivot, 0.15, Vector3(0.03 * side, -0.13, 0.0), FEATHER_DARK, Vector3(0.38, 1.0, 0.82), {"outline": 0.012}, 14)
		parts["wing_r" if side < 0 else "wing_l"] = pivot
	# feet
	for side: int in [-1, 1]:
		for k in 3:
			Kit.sphere(bob, 0.022, Vector3(0.07 * side + (k - 1) * 0.022, 0.015, 0.1 + absf(k - 1) * -0.01), BEAK, Vector3(1, 0.8, 1.6), {"outline": 0.005}, 8)
	# graduation cap with a swinging tassel
	var cap := Node3D.new()
	cap.position = bc + Vector3(0.0, 0.245, -0.01)
	cap.rotation = Vector3(-0.08, 0.25, -0.12)
	spin.add_child(cap)
	parts["cap"] = cap
	Kit.cylinder(cap, 0.115, 0.13, 0.08, Vector3(0, 0.0, 0), CAP, {"outline": 0.008}, 16)
	Kit.box(cap, Vector3(0.36, 0.025, 0.36), Vector3(0, 0.045, 0), CAP, {"outline": 0.01})
	Kit.sphere(cap, 0.02, Vector3(0, 0.065, 0), Color("#ffd23f"), Vector3.ONE, {"outline": 0.0}, 8)
	var cord := Kit.box(cap, Vector3(0.17, 0.008, 0.008), Vector3(0.085, 0.062, 0.0), Color("#ffd23f"), {"outline": 0.0})
	cord.rotation.z = -0.05
	var tassel := Node3D.new()
	tassel.position = Vector3(0.17, 0.055, 0.0)
	cap.add_child(tassel)
	parts["tassel"] = tassel
	Kit.box(tassel, Vector3(0.008, 0.1, 0.008), Vector3(0, -0.05, 0), Color("#ffd23f"), {"outline": 0.0})
	Kit.cylinder(tassel, 0.012, 0.028, 0.06, Vector3(0, -0.12, 0), Color("#ffd23f"), {"outline": 0.005}, 8)
	face.set_state({"eyes": &"open", "mouth": &"smile"})


func _process(delta: float) -> void:
	_t += delta
	var bob: Node3D = parts["bob"]
	var talking := _talk_left > 0.0
	if talking:
		_talk_left -= delta
		var open := fmod(_t * 8.0, 1.0) < 0.5 and _talk_left > 0.05
		(parts["beak_lower"] as Node3D).rotation.x = 0.55 if open else 0.0
		bob.position.y = 0.025 * absf(sin(_t * 8.0))
		(parts["wing_r"] as Node3D).rotation.z = -0.15 * absf(sin(_t * 5.0))
	else:
		(parts["beak_lower"] as Node3D).rotation.x = 0.0
		bob.position.y = lerpf(bob.position.y, 0.0, minf(1.0, delta * 10.0))
	# breathing
	(parts["body"] as Node3D).scale = Vector3(1.0 + 0.012 * sin(_t * 2.3), 1.04 + 0.018 * sin(_t * 2.3), 0.94)
	# tassel swing
	(parts["tassel"] as Node3D).rotation.z = 0.25 * sin(_t * 2.0) + (0.4 * sin(_t * 9.0) if talking else 0.0)
	# blink
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.2, 5.0)
		_blink_left = 0.12
		face.set_blink(true)
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			face.set_blink(false)
	if _expr_left > 0.0:
		_expr_left -= delta
		if _expr_left <= 0.0:
			face.set_state({"eyes": &"open", "mouth": &"smile", "look": Vector2.ZERO})
	# idle owl tricks: a curious head tilt, now and then a full head swivel
	if not talking:
		_idle_trick_t -= delta
		if _idle_trick_t <= 0.0:
			_idle_trick_t = randf_range(9.0, 16.0)
			if randf() < 0.35:
				_swivel()
			else:
				_tilt()


func talk(seconds: float) -> void:
	_talk_left = maxf(_talk_left, seconds)


func emote(kind: StringName) -> void:
	var spin: Node3D = parts["spin"]
	var bob: Node3D = parts["bob"]
	match kind:
		&"hop", &"cheer":
			face.set_state({"eyes": &"happy", "mouth": &"smile"})
			_expr_left = 1.0
			var t := _channel("hop")
			t.tween_property(bob, "scale", Vector3(1.12, 0.86, 1.12), 0.08)
			t.tween_property(bob, "position:y", 0.16, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.parallel().tween_property(bob, "scale", Vector3(0.9, 1.12, 0.9), 0.14)
			t.tween_property(bob, "position:y", 0.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			t.tween_property(bob, "scale", Vector3(1.1, 0.9, 1.1), 0.06)
			t.tween_property(bob, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			_flap(2)
		&"wing_up":
			face.set_state({"eyes": &"open", "mouth": &"smile", "look": Vector2(-0.4, -0.2)})
			_expr_left = 1.4
			var w: Node3D = parts["wing_l"]
			var t2 := _channel("wing_l")
			t2.tween_property(w, "rotation:z", 2.1, 0.2).set_trans(Tween.TRANS_BACK)
			t2.tween_interval(0.9)
			t2.tween_property(w, "rotation:z", 0.0, 0.3)
		&"facepalm":
			face.set_state({"eyes": &"closed", "mouth": &"frown"})
			_expr_left = 1.4
			var w2: Node3D = parts["wing_r"]
			var t3 := _channel("wing_r")
			t3.tween_property(w2, "rotation", Vector3(-0.3, -0.9, -2.0), 0.2).set_trans(Tween.TRANS_BACK)
			t3.tween_interval(0.9)
			t3.tween_property(w2, "rotation", Vector3.ZERO, 0.3)
			var t4 := _channel("spin")
			for i in 3:
				t4.tween_property(spin, "rotation:y", 0.12 * (1 if i % 2 == 0 else -1), 0.12)
			t4.tween_property(spin, "rotation:y", 0.0, 0.12)
		&"nod":
			var t5 := _channel("spin")
			for i in 2:
				t5.tween_property(spin, "rotation:x", 0.22, 0.12).set_trans(Tween.TRANS_SINE)
				t5.tween_property(spin, "rotation:x", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
		&"gasp":
			face.set_state({"eyes": &"wide", "mouth": &"o"})
			_expr_left = 1.0
			_flap(1)


func _flap(n: int) -> void:
	for key: String in ["wing_r", "wing_l"]:
		var w: Node3D = parts[key]
		var side := -1.0 if key == "wing_r" else 1.0
		var t := _channel(key)
		for i in n:
			t.tween_property(w, "rotation:z", 1.0 * side, 0.09)
			t.tween_property(w, "rotation:z", 0.0, 0.11)


func _tilt() -> void:
	var spin: Node3D = parts["spin"]
	var t := _channel("spin")
	var a := randf_range(0.25, 0.4) * (1.0 if randf() < 0.5 else -1.0)
	t.tween_property(spin, "rotation:z", a, 0.25).set_trans(Tween.TRANS_BACK)
	t.tween_interval(0.8)
	t.tween_property(spin, "rotation:z", 0.0, 0.3)


func _swivel() -> void:
	# owls really can turn their heads a long way; Hoot shows off with the whole bean
	var spin: Node3D = parts["spin"]
	var t := _channel("spin")
	t.tween_property(spin, "rotation:y", TAU, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func() -> void: spin.rotation.y = 0.0)


func _channel(key: String) -> Tween:
	if _tweens.has(key):
		var old: Tween = _tweens[key]
		if old and old.is_valid():
			old.kill()
	var t := create_tween()
	_tweens[key] = t
	return t
