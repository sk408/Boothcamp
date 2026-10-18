extends Node3D
## CaseExtras (cases, world-internal): the case-file patients' costume bits, added to a bean by the
## clinic when its patient_spec lists "extras" (story/cases/<id>.json "look"):
##   headband     a sweatband (colour "headband"), the drummer's
##   drumsticks   two sticks poking out of a cardigan pocket
##   captain_cap  a ferry captain's white peaked cap with a gold badge
##   cap          a baseball cap (colour "cap")
##   pizza_box    a pizza courier's insulated delivery bag, worn on the back
## Hats come off by themselves while earphones, the bone oscillator or the masking phone are on,
## and go back on afterwards.
##   CaseExtras.attach(bean, spec)    # returns the CaseExtras node ({} spec / no extras = null)

const Kit := preload("res://world/kit.gd")
const HATS: PackedStringArray = ["headband", "captain_cap", "cap"]
const HEAD_GEAR: PackedStringArray = ["Earphones", "BoneOscillator", "MaskingPhone"]

var _head: Node3D
var _hats: Array[Node3D] = []
var _hats_on := true


static func attach(bean: Node3D, spec: Dictionary) -> Node3D:
	var extras: Array = spec.get("extras", [])
	if extras.is_empty() or bean == null:
		return null
	var x: Node3D = (load("res://world/characters/case_extras.gd") as GDScript).new()
	x.name = "CaseExtras"
	bean.add_child(x)
	x.call("build", bean, spec)
	return x


func build(bean: Node3D, spec: Dictionary) -> void:
	var parts: Dictionary = bean.get("parts")
	_head = parts["head"]
	var hc: Vector3 = parts["head_center"]
	var torso: Node3D = parts["torso"]
	for e: Variant in spec.get("extras", []):
		match String(e):
			"headband":
				_hats.append(_headband(hc, _col(spec, "headband", Color("#e5383b"))))
			"captain_cap":
				_hats.append(_captain_cap(hc))
			"cap":
				_hats.append(_cap(hc, _col(spec, "cap", Color("#e5383b"))))
			"drumsticks":
				_drumsticks(torso)
			"pizza_box":
				_delivery_bag(torso)


func _process(_delta: float) -> void:
	if _head == null:
		return
	var gear := false
	for n: String in HEAD_GEAR:
		var g := _head.get_node_or_null(n)
		if g != null and not g.is_queued_for_deletion():
			gear = true
	if gear == _hats_on:
		_hats_on = not gear
		for h in _hats:
			h.visible = _hats_on
			if _hats_on:
				h.scale = Vector3.ONE * 0.6
				var t := h.create_tween()
				t.tween_property(h, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _col(spec: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = spec.get(key, null)
	if v is Color:
		return v
	if v is String and String(v).begins_with("#"):
		return Color(String(v))
	return fallback


func _hat_root(hc: Vector3, hat_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = hat_name
	n.position = hc
	_head.add_child(n)
	return n


## A terry sweatband round the forehead, the knot's tails at the back.
func _headband(hc: Vector3, col: Color) -> Node3D:
	var n := _hat_root(hc, "Headband")
	var band := Kit.torus(n, 0.33, 0.385, Vector3(0, 0.15, 0.0), col, {"outline": 0.008}, 28, 6)
	band.rotation.x = -0.18
	band.scale = Vector3(1.0, 1.6, 0.98)
	for s: int in [-1, 1]:
		var tail := Kit.capsule(n, 0.025, 0.16, Vector3(0.05 * s, 0.07, -0.37), col, {"outline": 0.006}, 8)
		tail.rotation = Vector3(0.9, 0.0, 0.5 * s)
	Kit.box(n, Vector3(0.07, 0.04, 0.01), Vector3(0, 0.2, 0.37), Color.WHITE, {"outline": 0.0}).rotation.x = -0.2
	return n


## White crown, navy band, black visor, gold badge.
func _captain_cap(hc: Vector3) -> Node3D:
	var n := _hat_root(hc, "CaptainCap")
	Kit.cylinder(n, 0.34, 0.3, 0.1, Vector3(0, 0.36, -0.02), Color("#1f3a5f"), {"outline": 0.008}, 24)
	var top := Kit.cylinder(n, 0.42, 0.36, 0.09, Vector3(0, 0.45, -0.04), Color("#fbfbf7"), {"outline": 0.01}, 24)
	top.rotation.x = -0.12
	var visor := Kit.sphere(n, 0.2, Vector3(0, 0.32, 0.28), Color("#1d1d26"), Vector3(1.2, 0.18, 0.75), {"outline": 0.006}, 16)
	visor.rotation.x = 0.3
	Kit.sphere(n, 0.045, Vector3(0, 0.39, 0.33), Color("#ffd23f"), Vector3(1.2, 1.0, 0.4), {"outline": 0.006}, 10)
	Kit.box(n, Vector3(0.32, 0.015, 0.01), Vector3(0, 0.335, 0.33), Color("#ffd23f"), {"outline": 0.0})
	return n


## A baseball cap, worn forwards (he's in a hurry, not a music video).
func _cap(hc: Vector3, col: Color) -> Node3D:
	var n := _hat_root(hc, "Cap")
	Kit.sphere(n, 0.37, Vector3(0, 0.2, -0.02), col, Vector3(1.0, 0.62, 1.0), {"outline": 0.01}, 20)
	var brim := Kit.sphere(n, 0.22, Vector3(0, 0.22, 0.34), col.darkened(0.12), Vector3(1.0, 0.12, 0.85), {"outline": 0.006}, 16)
	brim.rotation.x = 0.12
	Kit.sphere(n, 0.035, Vector3(0, 0.44, 0.0), col.darkened(0.25), Vector3.ONE, {"outline": 0.005}, 8)
	Kit.label(n, "SS", Vector3(0, 0.26, 0.355), 40, Color.WHITE, 6, 700).rotation.x = -0.35
	return n


## Two drumsticks poking out of the right cardigan pocket.
func _drumsticks(torso: Node3D) -> void:
	var n := Node3D.new()
	n.name = "Drumsticks"
	n.position = Vector3(-0.2, 0.12, 0.34)
	torso.add_child(n)
	for i in 2:
		var stick := Kit.capsule(n, 0.016, 0.42, Vector3(0.025 * i, 0.12, 0.0), Color("#e9c48a"), {"outline": 0.005}, 8)
		stick.rotation.z = 0.25 - 0.18 * i
		Kit.sphere(stick, 0.022, Vector3(0, 0.21, 0), Color("#f6e1b3"), Vector3(1, 1.4, 1), {"outline": 0.004}, 8)


## An insulated pizza delivery bag strapped on the back, with straps over the shoulders.
func _delivery_bag(torso: Node3D) -> void:
	var n := Node3D.new()
	n.name = "DeliveryBag"
	n.position = Vector3(0, 0.38, -0.46)
	torso.add_child(n)
	Kit.box(n, Vector3(0.62, 0.62, 0.22), Vector3.ZERO, Color("#e5383b"), {"outline": 0.01})
	Kit.box(n, Vector3(0.5, 0.18, 0.02), Vector3(0, 0.08, -0.115), Color("#fff3dc"), {"outline": 0.004})
	var l := Kit.label(n, "PIZZA", Vector3(0, 0.08, -0.13), 64, Color("#e5383b"), 0, 700)
	l.rotation.y = PI
	for s: int in [-1, 1]:
		var strap := Kit.box(torso, Vector3(0.06, 0.5, 0.03), Vector3(0.2 * s, 0.6, 0.0), Color("#2e2442"), {"outline": 0.0})
		strap.rotation.x = 0.5
		strap.position.z = -0.2
