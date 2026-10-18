extends Node3D
## Bean person: a procedural cartoon character built from primitives (world-internal).
## Grandpa Gus and Doris are both beans with a different config. Faces are 2D textures
## (face_rig.gd) projected on the head; everything else is low-poly primitives with the
## toon shader + outline. Animation is code-driven: locomotion/idle in _process, reactions
## with tweens on "channels" so they never fight each other.
##
## The character faces local +Z. Its RIGHT side is local -X (red earphone goes there).

const Kit := preload("res://world/kit.gd")
const FaceRig := preload("res://world/characters/face_rig.gd")
const FACE_SHADER := preload("res://world/shaders/toon_face.gdshader")

signal arrived

const STEP_LEN := 0.34
const GUS := {
	"name": "Gus", "face": &"gus",
	"skin": Color("#ffcf9e"), "skin_shade": Color("#e59f74"), "nose": Color("#f5a37f"),
	"cardigan": Color("#3a9d96"), "pants": Color("#8a6243"), "shirt": Color("#fff3dc"),
	"accent": Color("#ff6f59"), "shoes": Color("#5a3d2b"),
	"hair": Color("#f6f2ea"), "hair_style": &"tufts", "mustache": true, "brows": true,
	"glasses": &"round", "glasses_color": Color("#5a3d2b"), "walker": true, "prop": &"",
}
const DORIS := {
	"name": "Doris", "face": &"doris",
	"skin": Color("#ffd6b0"), "skin_shade": Color("#e8a983"), "nose": Color("#f7b593"),
	"cardigan": Color("#c77dba"), "pants": Color("#6b5e7e"), "shirt": Color("#fffbf2"),
	"accent": Color("#fffbf2"), "shoes": Color("#8e5cc4"),
	"hair": Color("#c9d3ea"), "hair_style": &"beehive", "mustache": false, "brows": false,
	"glasses": &"cateye", "glasses_color": Color("#e5383b"), "walker": false, "prop": &"plate",
}
## (v3) Day 2: Bonnie Bunsworth, 34, baker. Bun with a wooden spoon in it, flour-dusted apron,
## mint reading glasses perched on her head (she is always looking for them), a basket of croissants.
const BONNIE := {
	"name": "Bonnie", "face": &"bonnie",
	"skin": Color("#e8b088"), "skin_shade": Color("#c98a62"), "nose": Color("#dd9670"),
	"cardigan": Color("#f2a541"), "pants": Color("#4f6d8f"), "shirt": Color("#fff3dc"),
	"accent": Color("#ff6f59"), "shoes": Color("#7a4b2a"),
	"hair": Color("#8a4f2a"), "hair_style": &"bun", "mustache": false, "brows": false,
	"glasses": &"perched", "glasses_color": Color("#2fb3a3"), "walker": false, "prop": &"basket", "apron": true,
}
## (Speech) Day 3: Mike Lenders, 41, forklift driver. A hi-vis vest over a cherry
## bowling shirt, a foam neck brace "just in case", sunglasses pushed up on his head, a slick
## quiff, a little stubble, and a clipboard of forms from his cousin Vinnie.
const MIKE := {
	"name": "Mike", "face": &"mike",
	"skin": Color("#d9a07a"), "skin_shade": Color("#b97f5a"), "nose": Color("#cf8f69"),
	"cardigan": Color("#a3333d"), "pants": Color("#34405e"), "shirt": Color("#fff3dc"),
	"accent": Color("#ffd23f"), "shoes": Color("#4a3a30"),
	"hair": Color("#3a2a22"), "hair_style": &"quiff", "mustache": false, "brows": true,
	"glasses": &"shades", "glasses_color": Color("#2e2442"), "walker": false, "prop": &"clipboard",
	"apron": false, "vest": true, "neck_brace": true,
}
## (v3) Pick a bean spec by patient id (unknown ids get Gus).
static func spec_for(patient_id: String) -> Dictionary:
	match patient_id:
		"bonnie":
			return BONNIE
		"mike":
			return MIKE
	return GUS

var cfg: Dictionary = {}
var parts: Dictionary = {}
var face: FaceRig
var walking := false
var seated := false
var holding_button := false
var base_expr: Dictionary = {"eyes": &"open", "mouth": &"smile", "look": Vector2.ZERO, "blush": false, "sweat": false, "tear": false}

var _path: Array[Vector3] = []
var _speed := 1.0
var _step_phase := 0.0
var _last_step := 0
var _t := 0.0
var _talk_left := 0.0
var _blink_t := 2.0
var _blink_left := 0.0
var _expr_left := 0.0
var _tweens: Dictionary = {}
var _rest: Dictionary = {}
var _seat_lift := 0.0
var _groove_left := 0.0
var _head_mat: ShaderMaterial
var _btn_mat_on: Material
var _btn_mat_off: Material


func build(config: Dictionary) -> void:
	cfg = GUS.duplicate()
	cfg.merge(config, true)
	name = String(cfg["name"])
	face = FaceRig.new(cfg["face"])
	face.name = "Face"
	add_child(face)
	_build_body()
	_build_head()
	if bool(cfg["walker"]):
		_build_walker()
	if cfg["prop"] == &"plate":
		_build_plate()
	elif cfg["prop"] == &"basket":
		_build_basket()
	elif cfg["prop"] == &"clipboard":
		_build_clipboard()
	_build_button()
	for k: String in ["hand_r", "hand_l", "foot_r", "foot_l"]:
		_rest[k] = (parts[k] as Node3D).position
	_set_hands(_idle_pose(), 0.0)
	set_expression(base_expr)


# ---------------------------------------------------------------- construction

func _build_body() -> void:
	var body := Node3D.new()
	body.name = "Body"
	add_child(body)
	parts["body"] = body
	for side: int in [-1, 1]:
		var foot := Kit.sphere(body, 0.11, Vector3(0.15 * side, 0.07, 0.07), cfg["shoes"], Vector3(1.0, 0.62, 1.5))
		parts["foot_r" if side < 0 else "foot_l"] = foot
	Kit.capsule(body, 0.31, 0.6, Vector3(0, 0.37, 0), cfg["pants"])
	var torso := Node3D.new()
	torso.name = "Torso"
	torso.position = Vector3(0, 0.42, 0)
	body.add_child(torso)
	parts["torso"] = torso
	Kit.capsule(torso, 0.37, 0.98, Vector3(0, 0.31, 0), cfg["cardigan"], {}, 20)
	# shirt V and collar ((Speech) under a vest it is the bowling shirt itself)
	var vest := bool(cfg.get("vest", false))
	Kit.sphere(torso, 0.15, Vector3(0, 0.66, 0.255), cfg["cardigan"].lightened(0.06) if vest else cfg["shirt"], Vector3(1.0, 1.05, 0.55), {"outline": 0.012})
	if not vest:
		# (a vest covers the cardigan's lapels, buttons and pockets)
		for side: int in [-1, 1]:
			var lapel := Kit.box(torso, Vector3(0.045, 0.26, 0.04), Vector3(0.085 * side, 0.6, 0.325), cfg["cardigan"].darkened(0.12), {"outline": 0.0})
			lapel.rotation.z = 0.38 * side
			lapel.rotation.x = -0.2
		for i in 3:
			Kit.sphere(torso, 0.03, Vector3(0.0, 0.36 - i * 0.13, 0.372 - i * 0.004), Color("#f6e1b3"), Vector3(1, 1, 0.6), {"outline": 0.006}, 10)
		# pockets
		for side: int in [-1, 1]:
			Kit.box(torso, Vector3(0.14, 0.11, 0.02), Vector3(0.2 * side, 0.08, 0.335), cfg["cardigan"].darkened(0.1), {"outline": 0.006}).rotation.y = -0.45 * side
	if bool(cfg.get("neck_brace", false)):
		_build_neck_brace(torso)
	if vest:
		_build_vest(torso)
	elif bool(cfg.get("apron", false)):
		_build_apron(torso)
	elif String(cfg["face"]) == "gus":
		# bow tie
		var bow := Node3D.new()
		bow.position = Vector3(0, 0.76, 0.3)
		torso.add_child(bow)
		parts["bow"] = bow
		for side: int in [-1, 1]:
			var wing := Kit.sphere(bow, 0.06, Vector3(0.06 * side, 0, 0), cfg["accent"], Vector3(1.1, 0.7, 0.45), {"outline": 0.008}, 12)
			wing.rotation.z = 0.25 * side
		Kit.sphere(bow, 0.028, Vector3(0, 0, 0.012), cfg["accent"].darkened(0.15), Vector3.ONE, {"outline": 0.006}, 10)
	else:
		# pearl necklace
		for i in 9:
			var a := lerpf(-1.1, 1.1, i / 8.0)
			Kit.sphere(torso, 0.026, Vector3(sin(a) * 0.25, 0.74 - cos(a) * 0.09 + 0.05, cos(a) * 0.25 + 0.04), Color("#fffbf2"), Vector3.ONE, {"outline": 0.005}, 8)
	# floating mitten hands
	for side: int in [-1, 1]:
		var hand := Kit.sphere(body, 0.1, Vector3(0.5 * side, 0.82, 0.12), cfg["skin"], Vector3(0.95, 1.0, 1.1))
		parts["hand_r" if side < 0 else "hand_l"] = hand
		var thumb := Kit.sphere(hand, 0.045, Vector3(-0.07 * side, 0.03, 0.06), cfg["skin"], Vector3.ONE, {"outline": 0.008}, 10)
		thumb.name = "Thumb"


func _build_head() -> void:
	var neck := Node3D.new()
	neck.name = "Head"
	neck.position = Vector3(0, 0.79, 0)
	(parts["torso"] as Node3D).add_child(neck)
	parts["head"] = neck
	var hc := Vector3(0, 0.31, 0)
	parts["head_center"] = hc
	var sm := SphereMesh.new()
	sm.radius = 0.36
	sm.height = 0.72
	sm.radial_segments = 28
	sm.rings = 14
	_head_mat = ShaderMaterial.new()
	_head_mat.shader = FACE_SHADER
	_head_mat.set_shader_parameter("albedo", cfg["skin"])
	_head_mat.set_shader_parameter("shade", cfg["skin_shade"])
	_head_mat.set_shader_parameter("face_tex", face.get_texture())
	_head_mat.set_shader_parameter("face_size", 0.72)
	_head_mat.next_pass = Kit.outline_material(Kit.DEFAULT_OUTLINE)
	var head := Kit.mesh(neck, sm, hc, _head_mat, Vector3(1.0, 0.97, 0.95))
	head.name = "Skull"
	parts["skull"] = head
	# nose
	Kit.sphere(neck, 0.08, hc + Vector3(0, -0.035, 0.345), cfg["nose"], Vector3(1.05, 0.95, 0.95), {"outline": 0.012})
	# ears (+ an anchor on the outside of each, for earphones and drag targets)
	for side: int in [-1, 1]:
		var ear := Kit.sphere(neck, 0.085, hc + Vector3(0.345 * side, -0.02, -0.01), cfg["skin"], Vector3(0.55, 1.0, 0.85), {"outline": 0.012})
		Kit.sphere(ear, 0.05, Vector3(0.04 * side, 0, 0.0), cfg["skin_shade"], Vector3(0.4, 0.8, 0.7), {"outline": 0.0}, 10)
		var key := "ear_r" if side < 0 else "ear_l"
		parts[key] = ear
		var anchor := Node3D.new()
		anchor.name = key + "_anchor"
		anchor.position = hc + Vector3(0.42 * side, -0.02, 0.0)
		neck.add_child(anchor)
		parts[key + "_anchor"] = anchor
	# eyebrows
	if bool(cfg["brows"]):
		for side: int in [-1, 1]:
			var bp := Node3D.new()
			bp.position = hc + Vector3(0.125 * side, 0.205, 0.315)
			neck.add_child(bp)
			var brow := Kit.capsule(bp, 0.035, 0.17, Vector3.ZERO, cfg["hair"], {"outline": 0.01}, 10)
			brow.rotation.z = PI / 2.0
			brow.scale = Vector3(1.15, 1.0, 0.8)
			parts["brow_r" if side < 0 else "brow_l"] = bp
	# glasses
	match cfg["glasses"]:
		&"round":
			_build_round_glasses(neck, hc)
		&"cateye":
			_build_cateye_glasses(neck, hc)
		&"perched":
			_build_perched_glasses(neck, hc)
		&"shades":
			_build_shades(neck, hc)
	# mustache
	if bool(cfg["mustache"]):
		var mus := Node3D.new()
		mus.position = hc + Vector3(0, -0.115, 0.305)
		neck.add_child(mus)
		parts["mustache"] = mus
		for side: int in [-1, 1]:
			var half := Kit.sphere(mus, 0.1, Vector3(0.078 * side, 0, 0), cfg["hair"], Vector3(1.2, 0.55, 0.62), {"outline": 0.012})
			half.rotation.z = -0.32 * side
	# hair
	match cfg["hair_style"]:
		&"tufts":
			for side: int in [-1, 1]:
				var tuft := Node3D.new()
				tuft.position = hc + Vector3(0.28 * side, 0.12, -0.08)
				neck.add_child(tuft)
				parts["tuft_r" if side < 0 else "tuft_l"] = tuft
				Kit.sphere(tuft, 0.085, Vector3(0.05 * side, 0.0, 0.0), cfg["hair"], Vector3.ONE, {"outline": 0.012}, 12)
				Kit.sphere(tuft, 0.07, Vector3(0.08 * side, -0.08, 0.05), cfg["hair"], Vector3.ONE, {"outline": 0.012}, 12)
				Kit.sphere(tuft, 0.065, Vector3(0.03 * side, 0.06, -0.08), cfg["hair"], Vector3.ONE, {"outline": 0.012}, 12)
			var curl := Node3D.new()
			curl.position = hc + Vector3(0.0, 0.335, 0.02)
			neck.add_child(curl)
			parts["curl"] = curl
			var stem := Kit.capsule(curl, 0.011, 0.07, Vector3(0, 0.025, 0), cfg["hair"], {"outline": 0.006}, 8)
			stem.rotation.z = 0.1
			var hook := Kit.arc_tube(curl, 0.032, 0.011, -70.0, 180.0, 9, cfg["hair"], {"outline": 0.006})
			hook.position = Vector3(0.032, 0.06, 0)
		&"bun":
			_build_bun(neck, hc)
		&"quiff":
			_build_quiff(neck, hc)
		&"beehive":
			var hive := Node3D.new()
			hive.position = hc
			neck.add_child(hive)
			parts["tuft_r"] = hive
			parts["tuft_l"] = hive
			Kit.sphere(hive, 0.34, Vector3(0, 0.17, -0.05), cfg["hair"], Vector3(1.06, 0.82, 1.0), {}, 20)
			Kit.sphere(hive, 0.25, Vector3(0, 0.42, -0.06), cfg["hair"], Vector3.ONE, {}, 16)
			Kit.sphere(hive, 0.15, Vector3(0.02, 0.62, -0.06), cfg["hair"], Vector3.ONE, {}, 14)
			for side: int in [-1, 1]:
				Kit.sphere(hive, 0.1, Vector3(0.3 * side, 0.02, 0.02), cfg["hair"], Vector3.ONE, {"outline": 0.012}, 12)
			# a bow in the hive
			Kit.sphere(hive, 0.06, Vector3(0.2, 0.36, 0.17), Color("#ff6f59"), Vector3(1.4, 0.8, 0.6), {"outline": 0.01}, 10)
	# emote anchor above the head
	var emote := Node3D.new()
	emote.position = hc + Vector3(0.28, 0.5, 0.1)
	neck.add_child(emote)
	parts["emote"] = emote


## (v3) Bonnie's hair: a smooth cap, a big round bun on top, a wooden spoon poked through it.
func _build_bun(neck: Node3D, hc: Vector3) -> void:
	var cap := Node3D.new()
	cap.position = hc
	neck.add_child(cap)
	Kit.sphere(cap, 0.34, Vector3(0, 0.12, -0.06), cfg["hair"], Vector3(1.08, 0.78, 1.02), {}, 20)
	for side: int in [-1, 1]:
		Kit.sphere(cap, 0.11, Vector3(0.29 * side, 0.03, -0.02), cfg["hair"], Vector3(0.8, 1.1, 1.0), {"outline": 0.012}, 12)
	var bun := Node3D.new()
	bun.name = "Bun"
	bun.position = hc + Vector3(0, 0.4, -0.08)
	neck.add_child(bun)
	parts["tuft_r"] = bun
	parts["tuft_l"] = bun
	parts["bun"] = bun
	Kit.sphere(bun, 0.17, Vector3.ZERO, cfg["hair"], Vector3(1.0, 0.9, 1.0), {}, 16)
	# the wooden spoon (handle + bowl), stuck through at a jaunty angle
	var spoon := Node3D.new()
	spoon.position = Vector3(0.0, 0.04, 0.0)
	spoon.rotation.z = 0.95
	bun.add_child(spoon)
	var wood := Color("#d9a066")
	Kit.capsule(spoon, 0.018, 0.5, Vector3(0, 0, 0), wood, {"outline": 0.006}, 8)
	Kit.sphere(spoon, 0.055, Vector3(0, 0.27, 0), wood, Vector3(0.9, 1.25, 0.45), {"outline": 0.008}, 10)


## (v3) A baker's apron with a pocket, a little flour on it and a loaf stitched on the bib.
func _build_apron(torso: Node3D) -> void:
	var cream := Color("#fffaf0")
	Kit.box(torso, Vector3(0.44, 0.52, 0.04), Vector3(0, 0.1, 0.35), cream, {"outline": 0.008})
	Kit.box(torso, Vector3(0.26, 0.2, 0.04), Vector3(0, 0.46, 0.33), cream, {"outline": 0.008})
	for side: int in [-1, 1]:
		var strap := Kit.box(torso, Vector3(0.04, 0.3, 0.03), Vector3(0.12 * side, 0.66, 0.29), cream, {"outline": 0.0})
		strap.rotation.z = -0.25 * side
	Kit.box(torso, Vector3(0.2, 0.09, 0.02), Vector3(0, -0.02, 0.375), Color("#f3e3c8"), {"outline": 0.006})
	Kit.sphere(torso, 0.06, Vector3(0, 0.46, 0.355), Color("#d98b3a"), Vector3(1.4, 0.75, 0.35), {"outline": 0.006}, 10)
	for p: Vector3 in [Vector3(-0.14, 0.24, 0.374), Vector3(0.12, 0.05, 0.374), Vector3(0.05, 0.3, 0.374)]:
		Kit.sphere(torso, 0.022, p, Color("#ffffff"), Vector3(1.6, 1.0, 0.3), {"outline": 0.0}, 8)


## (Speech) Mike's hi-vis vest: a lime-yellow shell over the bowling shirt (a barrel that hugs the
## torso capsule), two silver reflective bands, a name patch, and the shirt's camp collar on top.
func _build_vest(torso: Node3D) -> void:
	var vest := Node3D.new()
	vest.name = "Vest"
	torso.add_child(vest)
	parts["vest"] = vest
	var lime := Color("#d6ef3a")
	var silver := Color("#eef2f7")
	var shell := 0.015
	# the torso capsule's radius at a height (torso space), plus the shell thickness
	var r := func(y: float) -> float:
		var cy := clampf(y, 0.19, 0.43)
		return sqrt(maxf(0.0, 0.37 * 0.37 - (y - cy) * (y - cy))) + shell
	var bands: Array[Vector2] = [Vector2(-0.03, 0.12), Vector2(0.12, 0.31), Vector2(0.31, 0.47), Vector2(0.47, 0.62)]
	for b: Vector2 in bands:
		Kit.cylinder(vest, r.call(b.y), r.call(b.x), b.y - b.x, Vector3(0, (b.x + b.y) * 0.5, 0), lime, {"outline": 0.01}, 22)
	for b: Vector2 in [Vector2(0.06, 0.12), Vector2(0.31, 0.37)]:
		Kit.cylinder(vest, r.call(b.y) + 0.006, r.call(b.x) + 0.006, b.y - b.x, Vector3(0, (b.x + b.y) * 0.5, 0), silver, {"outline": 0.0, "rim": 0.5}, 22)
	# the name patch on his left chest
	var px := 0.15
	var py := 0.5
	var pz: float = r.call(py)
	var patch := Node3D.new()
	patch.position = Vector3(px, py, sqrt(maxf(0.0, pz * pz - px * px)) + 0.004)
	patch.rotation = Vector3(-0.28, asin(px / pz), 0.0)
	vest.add_child(patch)
	Kit.box(patch, Vector3(0.15, 0.06, 0.008), Vector3.ZERO, Color("#fffbf2"), {"outline": 0.004})
	var name_l := Kit.label(patch, "MIKE", Vector3(0, 0, 0.006), 15, Color("#e5383b"), 0, 700)
	name_l.name = "NamePatch"
	# the bowling shirt's camp collar, flared over the vest
	for side: int in [-1, 1]:
		var flap := Kit.box(vest, Vector3(0.13, 0.024, 0.11), Vector3(0.105 * side, 0.665, 0.235), cfg["shirt"], {"outline": 0.006})
		flap.rotation = Vector3(-0.55, 0.0, 0.42 * side)


## (Speech) A chunky foam neck brace ("just in case"): a soft collar between torso and chin.
func _build_neck_brace(torso: Node3D) -> void:
	var foam := Color("#f4ecdc")
	var brace := Node3D.new()
	brace.name = "NeckBrace"
	brace.position = Vector3(0, 0.79, 0)
	torso.add_child(brace)
	parts["neck_brace"] = brace
	Kit.cylinder(brace, 0.245, 0.29, 0.15, Vector3.ZERO, foam, {"outline": 0.01}, 22)
	# rolled edges and the velcro strap at the front
	Kit.cylinder(brace, 0.297, 0.297, 0.022, Vector3(0, -0.068, 0), foam.darkened(0.08), {"outline": 0.0}, 22)
	Kit.box(brace, Vector3(0.11, 0.09, 0.03), Vector3(0, -0.005, 0.262), Color("#cfd6de"), {"outline": 0.005}).rotation.x = -0.15


func _build_round_glasses(neck: Node3D, hc: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Glasses"
	g.position = hc + Vector3(0, 0.055, 0.34)
	neck.add_child(g)
	parts["glasses"] = g
	var col: Color = cfg["glasses_color"]
	for side: int in [-1, 1]:
		var rim := Kit.torus(g, 0.098, 0.122, Vector3(0.125 * side, 0, 0), col, {"outline": 0.008}, 22, 6)
		rim.rotation.x = PI / 2.0
		var shine := Kit.box(g, Vector3(0.05, 0.014, 0.004), Vector3(0.125 * side + 0.045, 0.05, 0.004), Color.WHITE, {"unshaded": true})
		shine.rotation.z = 0.7
		var arm := Kit.box(g, Vector3(0.018, 0.018, 0.34), Vector3(0.235 * side, 0.0, -0.17), col, {"outline": 0.0})
		arm.rotation.y = -0.18 * side
	var bridge := Kit.arc_tube(g, 0.035, 0.012, 20, 160, 4, col, {"outline": 0.0})
	bridge.position = Vector3(0, -0.012, 0.006)


func _build_cateye_glasses(neck: Node3D, hc: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Glasses"
	g.position = hc + Vector3(0, 0.07, 0.34)
	neck.add_child(g)
	parts["glasses"] = g
	var col: Color = cfg["glasses_color"]
	for side: int in [-1, 1]:
		var rim := Kit.torus(g, 0.082, 0.104, Vector3(0.112 * side, 0, 0), col, {"outline": 0.008}, 22, 6)
		rim.rotation.x = PI / 2.0
		rim.scale = Vector3(1.2, 1.0, 0.82)
		var wing := Kit.cylinder(g, 0.0, 0.035, 0.09, Vector3(0.215 * side, 0.07, 0), col, {"outline": 0.008}, 8)
		wing.rotation.z = -0.9 * side
		Kit.sphere(g, 0.016, Vector3(0.235 * side, 0.1, 0.01), Color("#ffd23f"), Vector3.ONE, {"outline": 0.0}, 8)
	Kit.box(g, Vector3(0.05, 0.016, 0.016), Vector3(0, 0.0, 0), col, {"outline": 0.0})


## (v3) Bonnie's reading glasses, pushed up on top of her head (and promptly forgotten).
func _build_perched_glasses(neck: Node3D, hc: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Glasses"
	g.position = hc + Vector3(0, 0.345, 0.16)
	g.rotation.x = 0.55
	neck.add_child(g)
	parts["glasses"] = g
	var col: Color = cfg["glasses_color"]
	for side: int in [-1, 1]:
		var rim := Kit.torus(g, 0.062, 0.084, Vector3(0.088 * side, 0, 0), col, {"outline": 0.007}, 20, 6)
		rim.scale = Vector3(1.12, 1.0, 0.92)
		var lens := Kit.cylinder(g, 0.062, 0.062, 0.006, Vector3(0.088 * side, 0.0, 0.0), Color("#dff6ff"), {"alpha": 0.55}, 16)
		lens.scale = Vector3(1.12, 1.0, 0.92)
		var shine := Kit.box(g, Vector3(0.04, 0.006, 0.012), Vector3(0.088 * side + 0.02, 0.006, -0.03), Color.WHITE, {"unshaded": true})
		shine.rotation.y = 0.7
		var arm := Kit.box(g, Vector3(0.014, 0.014, 0.22), Vector3(0.175 * side, -0.01, -0.12), col, {"outline": 0.0})
		arm.rotation.y = 0.12 * side
		arm.rotation.x = -0.25
	Kit.box(g, Vector3(0.05, 0.014, 0.014), Vector3(0, 0.0, 0.04), col, {"outline": 0.0})
	# a little flour on the lenses
	Kit.sphere(g, 0.012, Vector3(-0.07, 0.008, 0.02), Color.WHITE, Vector3(1.5, 0.4, 1.0), {"unshaded": true}, 6)


## (Speech) Mike's quiff: a short cap, sideburns, and a proud front swoop (the part that stands
## up on a too-loud blast). One node for both "tufts", like the bun and the beehive.
func _build_quiff(neck: Node3D, hc: Vector3) -> void:
	var cap := Node3D.new()
	cap.name = "HairCap"
	cap.position = hc
	neck.add_child(cap)
	Kit.sphere(cap, 0.34, Vector3(0, 0.13, -0.07), cfg["hair"], Vector3(1.07, 0.74, 1.0), {}, 20)
	for side: int in [-1, 1]:
		# thin tapered sideburns from the hairline down in front of the ear, flattened onto the skull
		# (a box read as a floating block in 3/4 views)
		var burn := Kit.cylinder(cap, 0.028, 0.01, 0.13, Vector3(0.345 * side, 0.035, 0.075), cfg["hair"], {"outline": 0.0}, 10)
		burn.scale = Vector3(0.45, 1.0, 1.0)
		burn.rotation.x = -0.3
	var q := Node3D.new()
	q.name = "Quiff"
	q.position = hc + Vector3(0, 0.33, 0.06)
	neck.add_child(q)
	parts["tuft_r"] = q
	parts["tuft_l"] = q
	parts["quiff"] = q
	var swoop := Kit.sphere(q, 0.15, Vector3(0, 0.06, 0.02), cfg["hair"], Vector3(1.4, 0.72, 1.2), {}, 16)
	swoop.rotation.x = -0.35
	Kit.sphere(q, 0.075, Vector3(0.05, 0.11, 0.17), cfg["hair"], Vector3(1.3, 0.8, 1.1), {"outline": 0.01}, 12)
	# a glint of hair gel
	Kit.box(q, Vector3(0.09, 0.012, 0.01), Vector3(-0.07, 0.13, 0.14), Color("#7a6458"), {"unshaded": true}).rotation.z = 0.35


## (Speech) Mike's sunglasses, pushed up on his hairline (cool, apparently). Dark lenses with a
## shine, chunky black frames.
func _build_shades(neck: Node3D, hc: Vector3) -> void:
	var g := Node3D.new()
	g.name = "Glasses"
	g.position = hc + Vector3(0, 0.285, 0.215)
	g.rotation.x = 0.7
	neck.add_child(g)
	parts["glasses"] = g
	var col: Color = cfg["glasses_color"]
	for side: int in [-1, 1]:
		var rim := Kit.torus(g, 0.064, 0.088, Vector3(0.1 * side, 0, 0), col, {"outline": 0.007}, 20, 6)
		rim.scale = Vector3(1.25, 1.0, 0.86)
		var lens := Kit.cylinder(g, 0.066, 0.066, 0.008, Vector3(0.1 * side, 0.0, 0.0), Color("#26394a"), {"outline": 0.0, "rim": 0.45}, 16)
		lens.scale = Vector3(1.25, 1.0, 0.86)
		var shine := Kit.box(g, Vector3(0.045, 0.006, 0.012), Vector3(0.1 * side + 0.025, 0.006, 0.025), Color.WHITE, {"unshaded": true})
		shine.rotation.y = 0.7
		var arm := Kit.box(g, Vector3(0.016, 0.016, 0.24), Vector3(0.2 * side, -0.01, -0.13), col, {"outline": 0.0})
		arm.rotation.y = 0.1 * side
		arm.rotation.x = -0.25
	Kit.box(g, Vector3(0.06, 0.018, 0.018), Vector3(0, 0.0, 0.035), col, {"outline": 0.0})


## (Speech) Mike's clipboard of forms from his cousin Vinnie, held up proudly in front of him.
func _build_clipboard() -> void:
	var c := Node3D.new()
	c.name = "Clipboard"
	c.position = Vector3(0, 0.8, 0.47)
	c.rotation.x = -0.25
	(parts["body"] as Node3D).add_child(c)
	parts["clipboard"] = c
	build_clipboard(c)


## A clipboard: a wooden board, a form with ticks and a red stamp, and a metal clip.
static func build_clipboard(c: Node3D) -> void:
	var ink := Color("#2e2442")
	Kit.box(c, Vector3(0.3, 0.4, 0.02), Vector3.ZERO, Color("#c8874b"), {"outline": 0.008})
	Kit.box(c, Vector3(0.26, 0.33, 0.008), Vector3(0, -0.025, 0.013), Color("#fffbf2"), {"outline": 0.0})
	var title := Kit.label(c, "FORMS", Vector3(0, 0.1, 0.019), 17, Color("#e5383b"), 0, 700)
	title.name = "FormTitle"
	for i in 4:
		var y := 0.04 - i * 0.055
		Kit.box(c, Vector3(0.025, 0.025, 0.004), Vector3(-0.09, y, 0.018), Color("#5bc8a3"), {"outline": 0.0})
		Kit.box(c, Vector3(0.13, 0.008, 0.004), Vector3(0.02, y, 0.018), Color(ink, 0.55), {"unshaded": true})
	Kit.box(c, Vector3(0.12, 0.05, 0.03), Vector3(0, 0.19, 0.02), Color("#c3ccd6"), {"outline": 0.006})
	var ring := Kit.torus(c, 0.014, 0.026, Vector3(0, 0.215, 0.022), Color("#c3ccd6"), {"outline": 0.0}, 12, 6)
	ring.rotation.x = PI / 2.0


## (Speech) Hand over the clipboard (onto the desk): like detach_basket, null when not carrying one.
func detach_clipboard() -> Node3D:
	if not parts.has("clipboard"):
		return null
	var c: Node3D = parts["clipboard"]
	parts.erase("clipboard")
	c.set_meta("xf", c.global_transform)
	c.get_parent().remove_child(c)
	_set_hands(&"seated" if seated else &"rest", 0.25)
	return c


## (v3) Bonnie's basket of croissants for the waiting room.
func _build_basket() -> void:
	var b := Node3D.new()
	b.name = "Basket"
	b.position = Vector3(0, 0.78, 0.46)
	(parts["body"] as Node3D).add_child(b)
	parts["basket"] = b
	build_basket(b)


## A wicker basket with three croissants (also used by the clinic for the desk / payoff).
static func build_basket(b: Node3D) -> void:
	var wicker := Color("#c8874b")
	Kit.cylinder(b, 0.17, 0.13, 0.13, Vector3.ZERO, wicker, {"outline": 0.008, "pattern": 4, "pattern_scale": 28.0, "pattern_color": wicker.darkened(0.15)}, 18)
	var rim := Kit.torus(b, 0.15, 0.185, Vector3(0, 0.065, 0), wicker.darkened(0.1), {"outline": 0.006}, 20, 6)
	rim.scale = Vector3(1, 0.6, 1)
	var handle := Kit.arc_tube(b, 0.16, 0.014, 8.0, 172.0, 10, wicker.darkened(0.1), {"outline": 0.006})
	handle.position = Vector3(0, 0.06, 0)
	Kit.box(b, Vector3(0.3, 0.012, 0.22), Vector3(0, 0.07, 0), Color("#fff3dc"), {"outline": 0.0}).rotation.y = 0.4
	for i in 3:
		var c := build_croissant(b, Vector3(-0.08 + i * 0.08, 0.1 + 0.01 * (i % 2), 0.02 * (1 - i)), 0.85)
		c.rotation = Vector3(0.2 * (i - 1), 0.5 * i, 0.15)


## A croissant: a fat golden crescent of five puffs. Returns its root.
static func build_croissant(parent: Node3D, pos: Vector3, s: float = 1.0) -> Node3D:
	var c := Node3D.new()
	c.name = "Croissant"
	c.position = pos
	c.scale = Vector3.ONE * s
	parent.add_child(c)
	var gold := Color("#e9a443")
	for i in 5:
		var a := deg_to_rad(lerpf(-70.0, 70.0, i / 4.0))
		var r := 0.03 if i == 0 or i == 4 else (0.05 if i == 2 else 0.042)
		var col := gold if i % 2 == 0 else gold.darkened(0.12)
		var puff := Kit.sphere(c, r, Vector3(sin(a) * 0.06, 0.0, -cos(a) * 0.06 + 0.06), col, Vector3(1.0, 0.8, 1.25), {"outline": 0.006}, 10)
		puff.rotation.y = -a
	return c


func _build_walker() -> void:
	var w := Node3D.new()
	w.name = "Walker"
	w.position = Vector3(0, 0, 0.5)
	add_child(w)
	parts["walker"] = w
	var metal := Color("#c3ccd6")
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var leg := Kit.cylinder(w, 0.022, 0.022, 0.86, Vector3(0.3 * sx, 0.45, 0.15 * sz), metal, {"outline": 0.006}, 8)
			leg.rotation.x = -0.06 * sz
			if sz > 0:
				var wheel := Kit.cylinder(w, 0.055, 0.055, 0.035, Vector3(0.3 * sx, 0.055, 0.17), Color("#4d4d5c"), {"outline": 0.006}, 12)
				wheel.rotation.z = PI / 2.0
			else:
				Kit.sphere(w, 0.06, Vector3(0.3 * sx, 0.055, -0.16), Color("#d8f26b"), Vector3.ONE, {"outline": 0.008}, 12)
		Kit.box(w, Vector3(0.04, 0.04, 0.36), Vector3(0.3 * sx, 0.87, 0), metal, {"outline": 0.006})
		Kit.capsule(w, 0.035, 0.16, Vector3(0.3 * sx, 0.9, -0.12), Color("#4d4d5c"), {"outline": 0.008}, 10).rotation.x = PI / 2.0
	var bar := Kit.cylinder(w, 0.02, 0.02, 0.6, Vector3(0, 0.62, 0.16), metal, {"outline": 0.006}, 8)
	bar.rotation.z = PI / 2.0
	# a jaunty bicycle bell
	Kit.cylinder(w, 0.045, 0.05, 0.03, Vector3(0.3, 0.93, 0.08), Color("#ffd23f"), {"outline": 0.006}, 12)


func _build_plate() -> void:
	var plate := Node3D.new()
	plate.name = "Plate"
	plate.position = Vector3(0, 0.86, 0.42)
	(parts["body"] as Node3D).add_child(plate)
	parts["plate"] = plate
	var p := Kit.cylinder(plate, 0.2, 0.15, 0.03, Vector3.ZERO, Color("#fffbf2"), {"outline": 0.008}, 20)
	p.rotation.x = 1.15
	var rim := Kit.torus(plate, 0.15, 0.185, Vector3(0, 0.0, 0.0), Color("#2d6cdf"), {"outline": 0.0}, 20, 4)
	rim.rotation.x = 1.15
	rim.position = Vector3(0, 0.012, 0.005)
	for i in 3:
		Kit.sphere(plate, 0.035 - i * 0.008, Vector3(-0.08 + i * 0.07, 0.12 + i * 0.04, 0.05), Color("#e9f6ff"), Vector3.ONE, {"outline": 0.005}, 10)


func _build_button() -> void:
	var hand: Node3D = parts["hand_r"]
	var btn := Node3D.new()
	btn.name = "ResponseButton"
	btn.position = Vector3(0.0, -0.02, 0.1)
	btn.visible = false
	hand.add_child(btn)
	parts["button"] = btn
	var body := Kit.cylinder(btn, 0.045, 0.05, 0.16, Vector3.ZERO, Color("#4d4d5c"), {"outline": 0.008}, 12)
	body.rotation.x = PI / 2.0
	_btn_mat_off = Kit.toon(Color("#e5383b"), {"outline": 0.006})
	_btn_mat_on = Kit.toon(Color("#9ee34b"), {"outline": 0.006, "emission": Color("#9ee34b") * 0.8})
	var cap := Kit.cylinder(btn, 0.035, 0.035, 0.03, Vector3(0, 0.05, 0.03), Color("#e5383b"), {"outline": 0.006}, 12)
	cap.material_override = _btn_mat_off
	parts["button_cap"] = cap
	# the cord loops down to the floor
	var cord := Kit.arc_tube(btn, 0.12, 0.008, 200, 320, 6, Color("#2e2442"), {"outline": 0.0})
	cord.position = Vector3(0.0, 0.0, -0.12)
	cord.rotation.y = PI / 2.0


# ---------------------------------------------------------------- per-frame life

func _process(delta: float) -> void:
	_t += delta
	var torso: Node3D = parts.get("torso")
	if torso == null:
		return
	# breathing
	torso.scale = Vector3(1.0 - 0.008 * sin(_t * 2.1), 1.0 + 0.014 * sin(_t * 2.1), 1.0)
	# blinking
	_blink_t -= delta
	if _blink_t <= 0.0:
		_blink_t = randf_range(2.0, 4.5)
		_blink_left = 0.13
		face.set_blink(true)
	if _blink_left > 0.0:
		_blink_left -= delta
		if _blink_left <= 0.0:
			face.set_blink(false)
	# expression timeout
	if _expr_left > 0.0:
		_expr_left -= delta
		if _expr_left <= 0.0:
			set_expression(base_expr)
			_brows(&"neutral")
	# the hair curl and tufts wobble
	if parts.has("curl"):
		(parts["curl"] as Node3D).rotation.z = 0.25 * sin(_t * 3.1) + (0.4 * sin(_t * 18.0) if walking else 0.0)
	# talking: mouth flap + mustache bounce
	if _talk_left > 0.0:
		_talk_left -= delta
		var open := fmod(_t * 7.5, 1.0) < 0.55 and _talk_left > 0.05
		face.set_talk_open(open)
		if parts.has("mustache"):
			(parts["mustache"] as Node3D).position.y = (parts["head_center"] as Vector3).y - 0.115 + (0.012 if open else 0.0)
		(parts["head"] as Node3D).position.y = 0.79 + (0.008 if open else 0.0)
	elif face.talk_open:
		face.set_talk_open(false)
	if _groove_left > 0.0:
		_groove_left -= delta
		var beat := sin(_t * TAU * 1.6)
		(parts["head"] as Node3D).rotation.x = 0.12 * maxf(0.0, beat)
		torso.rotation.z = 0.06 * beat
		if _groove_left <= 0.0:
			(parts["head"] as Node3D).rotation.x = 0.0
			torso.rotation.z = 0.0
	if walking:
		_process_walk(delta)
	elif seated:
		# little dangling feet swing
		for k: String in ["foot_r", "foot_l"]:
			var f: Node3D = parts[k]
			f.rotation.x = 0.25 * sin(_t * 2.4 + (0.0 if k == "foot_r" else 1.4))


func _process_walk(delta: float) -> void:
	if _path.is_empty():
		_end_walk()
		return
	var target := _path[0]
	var to := target - position
	to.y = 0.0
	var dist := to.length()
	var step := _speed * delta
	if dist <= step:
		position = Vector3(target.x, position.y, target.z)
		_path.pop_front()
		if _path.is_empty():
			_end_walk()
		return
	position += to / dist * step
	var want := atan2(to.x, to.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, delta * 7.0))
	_step_phase += step / STEP_LEN
	var ph := fmod(_step_phase, 1.0)
	var body: Node3D = parts["body"]
	body.position.y = _seat_lift + absf(sin(ph * PI)) * 0.055
	var sq := 0.05 * cos(ph * TAU)
	body.scale = Vector3(1.0 + sq * 0.5, 1.0 - sq, 1.0 + sq * 0.5)
	var swing := sin(_step_phase * PI)
	(parts["foot_r"] as Node3D).position = (_rest["foot_r"] as Vector3) + Vector3(0, maxf(0.0, swing) * 0.05, swing * 0.09)
	(parts["foot_l"] as Node3D).position = (_rest["foot_l"] as Vector3) + Vector3(0, maxf(0.0, -swing) * 0.05, -swing * 0.09)
	if parts.has("walker"):
		var w: Node3D = parts["walker"]
		var lift := maxf(0.0, sin(ph * TAU))
		w.position = Vector3(0, lift * 0.035, 0.5 + lift * 0.05)
	var n := int(_step_phase)
	if n != _last_step:
		_last_step = n
		if bool(cfg["walker"]) and n % 2 == 0:
			Sfx.play(&"squeak", randf_range(0.85, 1.2), -14.0)
		elif not bool(cfg["walker"]) and n % 2 == 0:
			Sfx.play(&"thunk", randf_range(1.6, 2.0), -18.0)


func _end_walk() -> void:
	walking = false
	var body: Node3D = parts["body"]
	body.position.y = _seat_lift
	body.scale = Vector3.ONE
	(parts["foot_r"] as Node3D).position = _rest["foot_r"]
	(parts["foot_l"] as Node3D).position = _rest["foot_l"]
	if parts.has("walker") and not seated:
		(parts["walker"] as Node3D).position = Vector3(0, 0, 0.5)
	arrived.emit()


# ---------------------------------------------------------------- locomotion API

## (coroutine) Walk through the points (world positions on the floor).
func walk_path(points: Array, speed: float = 1.1) -> void:
	if points.is_empty():
		return
	_path.clear()
	for p: Vector3 in points:
		_path.append(p)
	_speed = speed
	look_toward(null, 0.2)
	walking = true
	await arrived


## (coroutine) Turn on the spot to face a yaw (radians; 0 = facing +Z).
func turn_to(yaw: float, duration: float = 0.35) -> void:
	var from := rotation.y
	var t := _channel("turn")
	t.tween_method(func(v: float) -> void: rotation.y = lerp_angle(from, yaw, v), 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE)
	await t.finished


## (coroutine) Plop down onto a seat. seat_lift: how far the body rises to sit on the seat.
func sit_down(seat_lift: float = 0.2, walker_park: Vector3 = Vector3(0.8, 0, 0.1)) -> void:
	seated = true
	_seat_lift = seat_lift
	var body: Node3D = parts["body"]
	var t := _channel("body")
	t.tween_property(body, "position:y", seat_lift + 0.12, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "scale", Vector3(0.94, 1.08, 0.94), 0.18)
	t.tween_property(body, "position:y", seat_lift, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body, "scale", Vector3(1.12, 0.86, 1.12), 0.16)
	t.tween_property(body, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var tf := _channel("feet")
	for k: String in ["foot_r", "foot_l"]:
		tf.parallel().tween_property(parts[k], "position", (_rest[k] as Vector3) + Vector3(0, 0.12, 0.22), 0.3)
	if parts.has("walker"):
		var tw := _channel("walker")
		tw.tween_property(parts["walker"], "position", walker_park, 0.4).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(parts["walker"], "rotation:y", -0.4, 0.4)
	_set_hands(&"seated", 0.3)
	get_tree().create_timer(0.34).timeout.connect(func() -> void: Sfx.play(&"pop", 0.55, -10.0))
	await t.finished


## (coroutine)
func stand_up() -> void:
	var body: Node3D = parts["body"]
	_seat_lift = 0.0
	var t := _channel("body")
	t.tween_property(body, "position:y", 0.08, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "scale", Vector3(0.92, 1.1, 0.92), 0.2)
	t.tween_property(body, "position:y", 0.0, 0.15)
	t.parallel().tween_property(body, "scale", Vector3.ONE, 0.15)
	var tf := _channel("feet")
	for k: String in ["foot_r", "foot_l"]:
		tf.parallel().tween_property(parts[k], "position", _rest[k], 0.25)
		tf.parallel().tween_property(parts[k], "rotation:x", 0.0, 0.25)
	if parts.has("walker"):
		var tw := _channel("walker")
		tw.tween_property(parts["walker"], "position", Vector3(0, 0, 0.5), 0.35).set_trans(Tween.TRANS_BACK)
		tw.parallel().tween_property(parts["walker"], "rotation:y", 0.0, 0.35)
	_set_hands(_idle_pose(), 0.3)
	await t.finished
	seated = false


## The hand pose when nothing special is happening (walker, plate, basket or empty hands).
func _idle_pose() -> StringName:
	if bool(cfg["walker"]):
		return &"walker"
	if parts.has("plate"):
		return &"plate"
	if parts.has("basket"):
		return &"basket"
	if parts.has("clipboard"):
		return &"clipboard"
	return &"rest"


## (v3) Hand over the croissant basket: removes it from the hands and returns it (out of the tree,
## its last global transform in meta "xf"), or null when not carrying one.
func detach_basket() -> Node3D:
	if not parts.has("basket"):
		return null
	var b: Node3D = parts["basket"]
	parts.erase("basket")
	b.set_meta("xf", b.global_transform)
	b.get_parent().remove_child(b)
	_set_hands(&"seated" if seated else &"rest", 0.25)
	return b


func set_holding_button(on: bool) -> void:
	holding_button = on
	(parts["button"] as Node3D).visible = on
	if on and seated:
		_set_hands(&"seated", 0.2)


# ---------------------------------------------------------------- face

func set_expression(e: Dictionary) -> void:
	var st := base_expr.duplicate()
	st.merge(e, true)
	face.set_state(st)


## Temporary expression for `hold` seconds, then back to base_expr.
func emote(eyes: StringName, mouth: StringName, hold: float = 1.2, extra: Dictionary = {}) -> void:
	var e := {"eyes": eyes, "mouth": mouth, "sweat": false, "tear": false, "blush": false, "look": Vector2.ZERO}
	e.merge(extra, true)
	set_expression(e)
	_expr_left = hold


func talk(seconds: float) -> void:
	_talk_left = maxf(_talk_left, seconds)


func is_talking() -> bool:
	return _talk_left > 0.0


func _brows(kind: StringName, duration: float = 0.15) -> void:
	if not parts.has("brow_r"):
		return
	var t := _channel("brows")
	for side: int in [-1, 1]:
		var bp: Node3D = parts["brow_r" if side < 0 else "brow_l"]
		var hc: Vector3 = parts["head_center"]
		var rest := hc + Vector3(0.125 * side, 0.205, 0.315)
		var pos := rest
		var rot := 0.0
		match kind:
			&"up":
				pos = rest + Vector3(0, 0.06, 0)
			&"furrow":
				pos = rest + Vector3(-0.015 * side, -0.025, 0.01)
				rot = 0.35 * side
			&"sad":
				pos = rest + Vector3(0, 0.02, 0)
				rot = -0.3 * side
			&"quizzical":
				pos = rest + Vector3(0, 0.07 if side < 0 else -0.01, 0)
				rot = (-0.2 if side < 0 else 0.2) * side
		t.parallel().tween_property(bp, "position", pos, duration).set_trans(Tween.TRANS_BACK)
		t.parallel().tween_property(bp, "rotation:z", rot, duration)


# ---------------------------------------------------------------- reactions

## Plays one reaction kind (CONTRACTS.md §6.2). Visual only; safe to call every tone.
func react(kind: StringName, data: Dictionary = {}) -> void:
	var ear := String(data.get("ear", "right"))
	var intensity := clampf(float(data.get("intensity", 0.7)), 0.0, 1.0)
	match kind:
		&"heard":
			_press_button(ear)
			emote(&"wide", &"o", 0.5)
			_brows(&"up")
		&"false_alarm":
			_press_button(ear)
			emote(&"worried", &"oops", 1.0, {"blush": true})
			_head_tilt(0.22, 0.9)
		&"missed":
			if randf() < 0.35:
				emote(&"open", &"flat", 0.6, {"look": Vector2(randf_range(-0.7, 0.7), -0.3)})
		&"too_loud_blast":
			if bool(Game.settings.get("no_startle", false)):
				_wobble(0.5)
				emote(&"wide", &"flat", 0.9)
			else:
				_hair_blast(intensity)
		&"startle":
			_jump(0.08)
			emote(&"wide", &"o", 0.7)
			_brows(&"up")
			pop_emote("!", Color("#ff6f59"))
		&"grooving":
			_groove_left = 2.6
			emote(&"happy", &"grin", 2.6)
			for i in 3:
				get_tree().create_timer(0.5 * i).timeout.connect(pop_note)
		&"bored":
			emote(&"sleepy", &"flat", 1.6)
			_head_tilt(-0.12, 1.4)
			pop_emote("...", Color("#6b5e7e"))
		&"yawn":
			_yawn()
		&"straining":
			_lean_in(ear)
		&"squint":
			emote(&"squint", &"wavy", 1.0)
			_brows(&"furrow")
			_lean_in(ear, 0.5)
		&"wince":
			emote(&"squint", &"frown", 0.9)
			_brows(&"furrow")
			_jump(0.03)
		&"cheer":
			_cheer()
		&"confused":
			emote(&"open", &"wavy", 1.5, {"look": Vector2(0.5, -0.4)})
			_brows(&"quizzical")
			_head_tilt(0.25, 1.3)
			pop_emote("?", Color("#2d6cdf"))
		&"point_wrong_way":
			_point_wrong_way(ear)
		&"nod":
			_nod()
		# (v3) Day 2 kinds
		&"tickle":
			_giggle(ear)
		&"overmasked":
			emote(&"spiral", &"wavy", 1.8, {"sweat": true})
			_wobble(0.9)
			_head_tilt(-0.2, 0.8)
			pop_emote("?!", Color("#8e5cc4"))
		&"cross_heard":
			# her OTHER ear perks up: a quick glance that way
			var other := 1.0 if ear == "right" else -1.0
			emote(&"wide", &"o", 0.8, {"look": Vector2(other * 0.8, -0.2)})
		&"wave":
			_wave()


## (v3) A felt, not heard, bone tone: she giggles and squirms (visual only).
func _giggle(ear: String) -> void:
	emote(&"happy", &"grin", 1.4, {"blush": true})
	_brows(&"up")
	var side := -1.0 if ear == "right" else 1.0
	var torso: Node3D = parts["torso"]
	var t := _channel("torso_rot")
	for i in 6:
		t.tween_property(torso, "rotation:z", 0.07 * (1.0 if i % 2 == 0 else -1.0), 0.06)
	t.tween_property(torso, "rotation:z", 0.0, 0.1)
	var head: Node3D = parts["head"]
	var th := _channel("head")
	th.tween_property(head, "rotation:z", 0.22 * -side, 0.12).set_trans(Tween.TRANS_BACK)
	th.tween_interval(0.5)
	th.tween_property(head, "rotation:z", 0.0, 0.25)
	pop_emote("hee!", Color("#e08a1c"))


## (v3) A cheery wave with the free hand (goodbyes).
func _wave() -> void:
	emote(&"happy", &"grin", 1.6)
	var key := "hand_l"
	var hand: Node3D = parts[key]
	var rest: Vector3 = hand.get_meta("pose_pos", _rest[key])
	var th := _channel(key)
	th.tween_property(hand, "position", Vector3(0.6, 1.6, 0.15), 0.2).set_trans(Tween.TRANS_BACK)
	for i in 3:
		th.tween_property(hand, "position:x", 0.72, 0.14).set_trans(Tween.TRANS_SINE)
		th.tween_property(hand, "position:x", 0.55, 0.14).set_trans(Tween.TRANS_SINE)
	th.tween_property(hand, "position", rest, 0.3)


func _press_button(ear: String) -> void:
	var key := "hand_r" if (ear == "right" or holding_button) else "hand_l"
	var hand: Node3D = parts[key]
	var rest: Vector3 = hand.get_meta("pose_pos", _rest[key])
	var t := _channel(key)
	t.tween_property(hand, "position", rest + Vector3(0.0, 0.62, 0.06), 0.13).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(hand, "scale", Vector3(0.8, 1.35, 0.8), 0.1)
	t.tween_property(hand, "scale", Vector3(1.1, 0.9, 1.1), 0.08)
	t.tween_property(hand, "scale", Vector3.ONE, 0.12)
	t.tween_interval(0.3)
	t.tween_property(hand, "position", rest, 0.25).set_trans(Tween.TRANS_SINE)
	if holding_button:
		var cap: MeshInstance3D = parts["button_cap"]
		cap.material_override = _btn_mat_on
		get_tree().create_timer(0.45).timeout.connect(func() -> void:
			if is_instance_valid(cap):
				cap.material_override = _btn_mat_off)


func _hair_blast(intensity: float) -> void:
	emote(&"wide", &"o", 1.6, {"sweat": true})
	_brows(&"up", 0.08)
	_jump(0.18 + 0.2 * intensity)
	pop_emote("!!", Color("#e5383b"))
	for k: String in ["tuft_r", "tuft_l"]:
		if not parts.has(k):
			continue
		var tuft: Node3D = parts[k]
		var side := -1.0 if k == "tuft_r" else 1.0
		if cfg["hair_style"] in [&"beehive", &"bun", &"quiff"]:
			side = 0.0
		var t := _channel(k)
		var rest_pos: Vector3 = tuft.get_meta("rest_pos", tuft.position)
		tuft.set_meta("rest_pos", rest_pos)
		var big := 1.0 + 0.6 * clampf(intensity, 0.0, 1.0)
		t.tween_property(tuft, "rotation:z", 1.15 * side, 0.08).set_trans(Tween.TRANS_QUAD)
		t.parallel().tween_property(tuft, "scale", Vector3(1.3, 2.6, 1.3) * big, 0.08)
		t.parallel().tween_property(tuft, "position", rest_pos + Vector3(0.04 * side, 0.1, 0), 0.08)
		t.tween_interval(0.55)
		t.tween_property(tuft, "rotation:z", 0.0, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tuft, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(tuft, "position", rest_pos, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if parts.has("glasses"):
		var g: Node3D = parts["glasses"]
		var rest := g.position
		var tg := _channel("glasses")
		tg.tween_property(g, "position", rest + Vector3(0, 0.08, 0.06), 0.08)
		tg.parallel().tween_property(g, "rotation:z", 0.25, 0.08)
		tg.tween_property(g, "position", rest, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tg.parallel().tween_property(g, "rotation:z", 0.0, 0.5)
	var hc: Vector3 = parts["head_center"]
	Kit.burst(parts["head"], hc + Vector3(0, 0.3, 0), [Color("#fffbf2"), Color("#ffd23f"), Color("#bfe6ff")], 14, 1.8, -3.0, 0.045, 0.8)


func _jump(height: float) -> void:
	var body: Node3D = parts["body"]
	var base := _seat_lift
	var t := _channel("body")
	t.tween_property(body, "position:y", base + height, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(body, "scale", Vector3(0.88, 1.18, 0.88), 0.12)
	t.tween_property(body, "position:y", base, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(body, "scale", Vector3(1.12, 0.88, 1.12), 0.18)
	t.tween_property(body, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _wobble(amount: float) -> void:
	var torso: Node3D = parts["torso"]
	var t := _channel("torso_rot")
	for i in 4:
		t.tween_property(torso, "rotation:z", amount * 0.2 * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i * 0.22), 0.09)
	t.tween_property(torso, "rotation:z", 0.0, 0.12)


func _head_tilt(angle: float, hold: float) -> void:
	var head: Node3D = parts["head"]
	var t := _channel("head")
	t.tween_property(head, "rotation:z", angle, 0.2).set_trans(Tween.TRANS_BACK)
	t.tween_interval(hold)
	t.tween_property(head, "rotation:z", 0.0, 0.3).set_trans(Tween.TRANS_SINE)


func _lean_in(ear: String, hold: float = 0.9) -> void:
	emote(&"squint", &"tongue", hold + 0.4, {"sweat": true})
	_brows(&"furrow")
	var torso: Node3D = parts["torso"]
	var side := -1.0 if ear == "right" else 1.0
	var t := _channel("torso_rot")
	t.tween_property(torso, "rotation", Vector3(0.18, 0.0, -0.12 * side), 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_interval(hold)
	t.tween_property(torso, "rotation", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_SINE)
	var key := "hand_r" if ear == "right" else "hand_l"
	if not (holding_button and key == "hand_r"):
		var hand: Node3D = parts[key]
		var rest: Vector3 = hand.get_meta("pose_pos", _rest[key])
		var th := _channel(key)
		var hc: Vector3 = parts["head_center"]
		th.tween_property(hand, "position", Vector3(0.43 * side, 0.42 + 0.79 + hc.y - 0.06, 0.05), 0.3)
		th.tween_interval(hold)
		th.tween_property(hand, "position", rest, 0.3)


func _yawn() -> void:
	emote(&"closed", &"yawn", 1.6, {"tear": true})
	var torso: Node3D = parts["torso"]
	var t := _channel("torso_rot")
	t.tween_property(torso, "rotation:x", -0.12, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_interval(0.7)
	t.tween_property(torso, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	for key: String in ["hand_r", "hand_l"]:
		if holding_button and key == "hand_r":
			continue
		var hand: Node3D = parts[key]
		var rest: Vector3 = hand.get_meta("pose_pos", _rest[key])
		var th := _channel(key)
		th.tween_property(hand, "position", rest + Vector3(0, 0.75, -0.05), 0.5).set_trans(Tween.TRANS_SINE)
		th.tween_interval(0.6)
		th.tween_property(hand, "position", rest, 0.5)
	pop_emote("z", Color("#6b5e7e"))


func _cheer() -> void:
	emote(&"happy", &"grin", 2.0, {"blush": true})
	_brows(&"up")
	var body: Node3D = parts["body"]
	var base := _seat_lift
	var t := _channel("body")
	for i in 2:
		t.tween_property(body, "position:y", base + 0.16, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(body, "scale", Vector3(0.9, 1.14, 0.9), 0.16)
		t.tween_property(body, "position:y", base, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.parallel().tween_property(body, "scale", Vector3(1.1, 0.9, 1.1), 0.16)
	t.tween_property(body, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var torso: Node3D = parts["torso"]
	var tw := _channel("torso_rot")
	for i in 4:
		tw.tween_property(torso, "rotation:y", 0.3 * (1.0 if i % 2 == 0 else -1.0), 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(torso, "rotation:y", 0.0, 0.15)
	for key: String in ["hand_r", "hand_l"]:
		var hand: Node3D = parts[key]
		var rest: Vector3 = hand.get_meta("pose_pos", _rest[key])
		var side := -1.0 if key == "hand_r" else 1.0
		var th := _channel(key)
		th.tween_property(hand, "position", Vector3(0.55 * side, 1.75, 0.1), 0.18).set_trans(Tween.TRANS_BACK)
		for i in 3:
			th.tween_property(hand, "position:x", 0.62 * side, 0.12)
			th.tween_property(hand, "position:x", 0.5 * side, 0.12)
		th.tween_property(hand, "position", rest, 0.3)
	Kit.burst(self, Vector3(0, 2.0 + _seat_lift, 0), [Color("#ff6f59"), Color("#ffd23f"), Color("#5bc8a3"), Color("#2d6cdf"), Color("#8e5cc4")], 26, 2.6, -4.0, 0.06, 1.3)


func _point_wrong_way(ear: String) -> void:
	# points at the side that is NOT the one being tested (the earphones are swapped)
	var wrong_side := 1.0 if ear == "right" else -1.0
	var key := "hand_l" if wrong_side > 0 else "hand_r"
	var hand: Node3D = parts[key]
	var rest: Vector3 = hand.get_meta("pose_pos", _rest[key])
	var th := _channel(key)
	th.tween_property(hand, "position", Vector3(0.75 * wrong_side, 1.45, 0.15), 0.2).set_trans(Tween.TRANS_BACK)
	for i in 2:
		th.tween_property(hand, "position:x", 0.85 * wrong_side, 0.1)
		th.tween_property(hand, "position:x", 0.75 * wrong_side, 0.1)
	th.tween_interval(0.5)
	th.tween_property(hand, "position", rest, 0.3)
	var head: Node3D = parts["head"]
	var t := _channel("head")
	t.tween_property(head, "rotation:y", 0.5 * wrong_side, 0.2)
	t.tween_interval(0.9)
	t.tween_property(head, "rotation:y", 0.0, 0.3)
	emote(&"open", &"grin", 1.3, {"look": Vector2(wrong_side, 0)})
	pop_emote("?", Color("#2d6cdf"))


func _nod() -> void:
	var head: Node3D = parts["head"]
	var t := _channel("head")
	for i in 2:
		t.tween_property(head, "rotation:x", 0.22, 0.13).set_trans(Tween.TRANS_SINE)
		t.tween_property(head, "rotation:x", -0.04, 0.13).set_trans(Tween.TRANS_SINE)
	t.tween_property(head, "rotation:x", 0.0, 0.1)
	emote(&"happy", &"smile", 0.8)


## Happy wiggle (used by the story for small wins).
func wiggle() -> void:
	emote(&"happy", &"grin", 1.0)
	var torso: Node3D = parts["torso"]
	var t := _channel("torso_rot")
	for i in 4:
		t.tween_property(torso, "rotation:z", 0.12 * (1.0 if i % 2 == 0 else -1.0), 0.1)
	t.tween_property(torso, "rotation:z", 0.0, 0.1)


## Turn the head toward a world point (yaw only), or back to centre with null.
func look_toward(world_point: Variant, duration: float = 0.35) -> void:
	var head: Node3D = parts["head"]
	var yaw := 0.0
	if world_point is Vector3:
		var local := to_local(world_point as Vector3)
		yaw = clampf(atan2(local.x, local.z), -0.9, 0.9)
	var t := _channel("head_yaw")
	t.tween_property(head, "rotation:y", yaw, duration).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------- props

func _set_hands(pose: StringName, duration: float) -> void:
	for key: String in ["hand_r", "hand_l"]:
		var side := -1.0 if key == "hand_r" else 1.0
		var pos: Vector3 = _rest[key]
		match pose:
			&"walker":
				pos = Vector3(0.3 * side, 0.92, 0.38)
			&"seated":
				pos = Vector3(0.36 * side, 0.62, 0.32)
				if key == "hand_r" and holding_button:
					pos = Vector3(0.3 * side, 0.8, 0.38)
			&"plate":
				pos = Vector3(0.2 * side, 0.85, 0.42)
			&"basket":
				pos = Vector3(0.21 * side, 0.84, 0.44)
			&"clipboard":
				pos = Vector3(0.2 * side, 0.8, 0.43)
		var hand: Node3D = parts[key]
		hand.set_meta("pose_pos", pos)
		if duration <= 0.0:
			hand.position = pos
		else:
			var t := _channel(key)
			t.tween_property(hand, "position", pos, duration).set_trans(Tween.TRANS_SINE)


## Emoji-like pop above the head ("?", "!", "...", "z").
func pop_emote(text: String, color: Color) -> void:
	var anchor: Node3D = parts["emote"]
	var l := Kit.label(anchor, text, Vector3.ZERO, 96, color, 18, 700)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.scale = Vector3.ONE * 0.2
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector3.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "scale", Vector3.ONE, 0.1)
	t.parallel().tween_property(l, "position:y", 0.12, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.3)
	t.tween_callback(l.queue_free)


## A little 3D music note floats up (grooving).
func pop_note() -> void:
	if not is_inside_tree():
		return
	var anchor: Node3D = parts["emote"]
	var n := Node3D.new()
	n.position = Vector3(randf_range(-0.1, 0.25), 0, 0)
	anchor.add_child(n)
	var col := Color("#8e5cc4")
	Kit.sphere(n, 0.045, Vector3.ZERO, col, Vector3(1.25, 0.9, 0.6), {"outline": 0.008}, 10)
	Kit.box(n, Vector3(0.016, 0.16, 0.016), Vector3(0.045, 0.08, 0), col, {"outline": 0.0})
	Kit.box(n, Vector3(0.06, 0.02, 0.016), Vector3(0.07, 0.15, 0), col, {"outline": 0.0}).rotation.z = -0.5
	n.scale = Vector3.ONE * 0.3
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	t.parallel().tween_property(n, "position:y", 0.35, 1.2)
	t.parallel().tween_property(n, "rotation:z", 0.6, 1.2)
	t.tween_callback(n.queue_free)


func _channel(key: String) -> Tween:
	if _tweens.has(key):
		var old: Tween = _tweens[key]
		if old and old.is_valid():
			old.kill()
	var t := create_tween()
	_tweens[key] = t
	return t


## Head centre in world space (for cameras).
func head_world() -> Vector3:
	var head: Node3D = parts["head"]
	return head.to_global(parts["head_center"])


func ear_world(ear: String) -> Vector3:
	return (parts["ear_r_anchor" if ear == "right" else "ear_l_anchor"] as Node3D).global_position
