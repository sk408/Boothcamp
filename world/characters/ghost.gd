extends Node3D
## The Cross-Hearing Ghost (v3, world-internal): a small, round, translucent ghost with big eyes
## and a wavy hem. It stands for a tone that crossed the skull and was heard by the OTHER cochlea.
## The clinic spawns one per event and drives its flights (clinic.gd, "the Ghost"); the ghost
## itself only knows how to look (moods), bob, squash and poof. Visual only.
##   var g := Ghost.new(); clinic.add_child(g); g.global_position = p; g.appear()
##   g.set_mood(&"boo" / &"sneaky" / &"busted"); await g.poof("POOF!")

const Kit := preload("res://world/kit.gd")

const BODY_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_opaque;
uniform vec4 tint : source_color = vec4(0.98, 0.97, 1.0, 1.0);
uniform vec4 rim_color : source_color = vec4(0.55, 0.46, 0.80, 1.0);
uniform float alpha = 0.82;
void fragment() {
	float r = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = mix(tint.rgb, rim_color.rgb, smoothstep(0.55, 0.92, r));
	ALPHA = alpha * mix(0.78, 1.0, smoothstep(0.4, 0.9, r));
}
"""

static var _shader: Shader

var mood: StringName = &"boo"
var _body: Node3D
var _eyes: Array[MeshInstance3D] = []
var _x_eyes: Array[Node3D] = []
var _mouth: MeshInstance3D
var _grin: Node3D
var _hem: Array[MeshInstance3D] = []
var _t := 0.0
var _mat: ShaderMaterial


func _init() -> void:
	name = "CrossHearingGhost"
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BODY_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.render_priority = 2
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	# head and a skirt that flares a little, then the wavy hem
	_part(SphereMesh.new(), Vector3(0, 0.09, 0), Vector3(0.12, 0.125, 0.11))
	var skirt := CylinderMesh.new()
	skirt.top_radius = 0.118
	skirt.bottom_radius = 0.14
	skirt.height = 0.11
	skirt.radial_segments = 18
	skirt.rings = 1
	skirt.cap_top = false
	_part(skirt, Vector3(0, 0.02, 0), Vector3.ONE)
	for i in 5:
		var a := TAU * i / 5.0
		_hem.append(_part(SphereMesh.new(), Vector3(cos(a) * 0.105, -0.04, sin(a) * 0.105), Vector3(0.045, 0.05, 0.045)))
	# little stubby arms
	for side: int in [-1, 1]:
		var arm := _part(SphereMesh.new(), Vector3(0.13 * side, 0.03, 0.02), Vector3(0.04, 0.028, 0.03))
		arm.rotation.z = -0.5 * side
	# face: big glossy eyes, blush, an "o" mouth (or a cheeky grin)
	for side: int in [-1, 1]:
		var eye := Kit.sphere(_body, 0.021, Vector3(0.042 * side, 0.115, 0.098), Color("#2e2442"), Vector3(1.0, 1.35, 0.5), {"unshaded": true}, 10)
		_eyes.append(eye)
		Kit.sphere(eye, 0.007, Vector3(-0.006, 0.007, 0.016), Color.WHITE, Vector3.ONE, {"unshaded": true}, 6)
		Kit.sphere(_body, 0.016, Vector3(0.075 * side, 0.078, 0.088), Color("#ff9aa2"), Vector3(1.3, 0.6, 0.4), {"unshaded": true}, 8)
		var x := Node3D.new()
		x.position = Vector3(0.042 * side, 0.115, 0.104)
		x.visible = false
		_body.add_child(x)
		for k: int in [-1, 1]:
			var bar := Kit.box(x, Vector3(0.045, 0.01, 0.006), Vector3.ZERO, Color("#2e2442"), {"unshaded": true})
			bar.rotation.z = 0.78 * k
		_x_eyes.append(x)
	_mouth = Kit.sphere(_body, 0.016, Vector3(0, 0.068, 0.105), Color("#5a2a4a"), Vector3(0.9, 1.2, 0.4), {"unshaded": true}, 8)
	_grin = Kit.arc_tube(_body, 0.026, 0.005, 200.0, 340.0, 5, Color("#2e2442"), {"unshaded": true})
	_grin.position = Vector3(0, 0.088, 0.107)
	_grin.visible = false
	scale = Vector3.ONE * 0.01


func _part(m: PrimitiveMesh, pos: Vector3, sc: Vector3) -> MeshInstance3D:
	if m is SphereMesh:
		(m as SphereMesh).radial_segments = 18
		(m as SphereMesh).rings = 9
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = _mat
	mi.position = pos
	mi.scale = sc
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	_body.position.y = 0.012 * sin(_t * 7.0)
	_body.rotation.z = 0.08 * sin(_t * 4.3)
	for i in _hem.size():
		_hem[i].position.y = -0.04 + 0.012 * sin(_t * 9.0 + i * 1.3)


## &"boo" (round eyes, "o" mouth), &"sneaky" (a cheeky grin: it slipped past too little noise),
## &"busted" (X eyes: the masking noise got it).
func set_mood(m: StringName) -> void:
	mood = m
	for e in _eyes:
		e.visible = m != &"busted"
	for x in _x_eyes:
		x.visible = m == &"busted"
	_mouth.visible = m != &"sneaky"
	_grin.visible = m == &"sneaky"
	_mat.set_shader_parameter("rim_color", Color("#e5383b") if m == &"busted" else Color(0.55, 0.46, 0.80))


## Pop in from nothing.
func appear(size: float = 1.0) -> void:
	scale = Vector3.ONE * 0.01
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.25, 0.8, 1.25) * size, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "scale", Vector3.ONE * size, 0.22).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A little speech pop above the ghost ("boo!", "POOF!", "BUSTED!"). The label lives on the
## ghost's parent, so it outlives a poof.
func say(text: String, color: Color = Color("#8e5cc4"), size: int = 72) -> void:
	var host := get_parent() as Node3D
	if host == null:
		return
	var at := position + Vector3(0.0, 0.3 * scale.y, 0.02)
	var l := Kit.label(host, text, at, size, color, 16, 700)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 6
	l.scale = Vector3.ONE * 0.2
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE * 1.15, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector3.ONE, 0.1)
	t.parallel().tween_property(l, "position:y", at.y + 0.1, 0.7)
	t.tween_property(l, "modulate:a", 0.0, 0.25)
	t.tween_callback(l.queue_free)


## (coroutine) Squash, burst into lavender puffs and vanish (frees itself).
func poof(text: String = "") -> void:
	if text != "":
		say(text, Color("#e5383b") if mood == &"busted" else Color("#8e5cc4"))
	var t := create_tween()
	t.tween_property(self, "scale", Vector3(1.4, 0.6, 1.4) * scale.x, 0.1)
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await t.finished
	var parent := get_parent() as Node3D
	if parent != null:
		Kit.burst(parent, position, [Color("#fffbf2"), Color("#d9cff2"), Color("#b9a8e6")], 18, 1.1, 0.4, 0.05, 0.6, Vector3.UP, 180.0)
	queue_free()
