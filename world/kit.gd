extends RefCounted
## WorldKit: toon materials and primitive-mesh helpers for the procedural clinic (world-internal).
## Usage: const Kit := preload("res://world/kit.gd")  then  Kit.sphere(parent, 0.2, pos, color)
## Materials are cached per colour + options, so hundreds of parts share a handful of materials.
## Options (Dictionary, all optional):
##   shade: Color         shadow band colour (default: auto, darker + a touch of plum)
##   outline: float       inverted-hull width in object units (0 = none; default 0.018)
##   rim: float           rim light amount (default 0.22)
##   emission: Color      glow (screens, bulbs)
##   pattern: int         1 dots, 2 stripes x, 3 floor checker, 4 stripes y
##   pattern_scale, pattern_color, pattern_mix
##   unshaded: bool       flat colour (StandardMaterial3D), e.g. particles
##   alpha: float         < 1 makes a transparent unshaded material (glass)

const TOON := preload("res://world/shaders/toon.gdshader")
const OUTLINE := preload("res://world/shaders/outline.gdshader")
const OUTLINE_COLOR := Color("#2e2442")
const DEFAULT_OUTLINE := 0.018

static var _mats: Dictionary = {}
static var _font: Font


static func auto_shade(c: Color) -> Color:
	return c.darkened(0.22).lerp(Color("#6a4c8c"), 0.14)


static func toon(color: Color, opts: Dictionary = {}) -> Material:
	var key := color.to_html() + var_to_str(opts)
	if _mats.has(key):
		return _mats[key]
	var m: Material
	if bool(opts.get("unshaded", false)) or float(opts.get("alpha", 1.0)) < 1.0:
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.albedo_color = Color(color, float(opts.get("alpha", color.a)))
		if sm.albedo_color.a < 1.0:
			sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.vertex_color_use_as_albedo = bool(opts.get("vertex_color", false))
		m = sm
	else:
		var s := ShaderMaterial.new()
		s.shader = TOON
		s.set_shader_parameter("albedo", color)
		s.set_shader_parameter("shade", opts.get("shade", auto_shade(color)))
		s.set_shader_parameter("rim_amount", float(opts.get("rim", 0.22)))
		if opts.has("emission"):
			s.set_shader_parameter("emission", opts["emission"])
		if opts.has("pattern"):
			s.set_shader_parameter("pattern", int(opts["pattern"]))
			s.set_shader_parameter("pattern_scale", float(opts.get("pattern_scale", 8.0)))
			s.set_shader_parameter("pattern_color", opts.get("pattern_color", color.darkened(0.1)))
			s.set_shader_parameter("pattern_mix", float(opts.get("pattern_mix", 1.0)))
		var ow := float(opts.get("outline", DEFAULT_OUTLINE))
		if ow > 0.0:
			s.next_pass = outline_material(ow)
		m = s
	_mats[key] = m
	return m


static func outline_material(width: float) -> ShaderMaterial:
	var key := "outline_%.4f" % width
	if _mats.has(key):
		return _mats[key]
	var o := ShaderMaterial.new()
	o.shader = OUTLINE
	o.set_shader_parameter("width", width)
	o.set_shader_parameter("color", OUTLINE_COLOR)
	_mats[key] = o
	return o


static func mesh(parent: Node3D, m: Mesh, pos: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.scale = scale_v
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color, opts: Dictionary = {}) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent, b, pos, toon(color, opts))


static func sphere(parent: Node3D, r: float, pos: Vector3, color: Color, scale_v: Vector3 = Vector3.ONE, opts: Dictionary = {}, segs: int = 16) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(4, segs / 2)
	return mesh(parent, s, pos, toon(color, opts), scale_v)


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, color: Color, opts: Dictionary = {}, segs: int = 16) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = segs
	c.rings = 6
	return mesh(parent, c, pos, toon(color, opts))


static func cylinder(parent: Node3D, top_r: float, bottom_r: float, h: float, pos: Vector3, color: Color, opts: Dictionary = {}, sides: int = 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return mesh(parent, c, pos, toon(color, opts))


static func torus(parent: Node3D, inner_r: float, outer_r: float, pos: Vector3, color: Color, opts: Dictionary = {}, rings: int = 20, ring_segs: int = 8) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = inner_r
	t.outer_radius = outer_r
	t.rings = rings
	t.ring_segments = ring_segs
	return mesh(parent, t, pos, toon(color, opts))


## A curved tube (arc of short cylinders) in the XY plane of `parent`, e.g. a headband.
static func arc_tube(parent: Node3D, radius: float, thickness: float, from_deg: float, to_deg: float, segments: int, color: Color, opts: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var cm := CylinderMesh.new()
	var seg_len := TAU * radius * absf(to_deg - from_deg) / 360.0 / segments
	cm.top_radius = thickness
	cm.bottom_radius = thickness
	cm.height = seg_len * 1.15
	cm.radial_segments = 8
	cm.rings = 1
	var mat := toon(color, opts)
	for i in segments:
		var a := deg_to_rad(lerpf(from_deg, to_deg, (i + 0.5) / segments))
		var mi := mesh(root, cm, Vector3(cos(a), sin(a), 0) * radius, mat)
		mi.rotation.z = a  # cylinder axis (Y) becomes the tangent
	return root


## Flat extruded polygon (points in the XY plane, metres), facing +Z. For signs and decals.
static func flat_shape(parent: Node3D, points: PackedVector2Array, depth: float, pos: Vector3, color: Color, opts: Dictionary = {}) -> MeshInstance3D:
	var idx := Geometry2D.triangulate_polygon(points)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hz := depth * 0.5
	for i in range(0, idx.size(), 3):
		for k in [0, 2, 1]:
			var p := points[idx[i + k]]
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(Vector3(p.x, p.y, hz))
	for i in range(0, idx.size(), 3):
		for k in [0, 1, 2]:
			var p := points[idx[i + k]]
			st.set_normal(Vector3(0, 0, -1))
			st.add_vertex(Vector3(p.x, p.y, -hz))
	var n := points.size()
	for i in n:
		var a := points[i]
		var b := points[(i + 1) % n]
		var nrm := Vector3(b.y - a.y, -(b.x - a.x), 0).normalized()
		for v: Vector3 in [Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, -hz)]:
			st.set_normal(nrm)
			st.add_vertex(v)
	return mesh(parent, st.commit(), pos, toon(color, opts))


static func circle_points(r: float, n: int = 20, scale_v: Vector2 = Vector2.ONE) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * r * scale_v.x, sin(a) * r * scale_v.y))
	return pts


static func font(weight: int = 600) -> Font:
	if _font == null:
		_font = load("res://assets/fonts/fredoka-600.woff2")
	if weight != 600:
		var path := "res://assets/fonts/fredoka-%d.woff2" % weight
		if ResourceLoader.exists(path):
			return load(path)
	return _font


static func label(parent: Node3D, text: String, pos: Vector3, size: int, color: Color, outline: int = 0, weight: int = 600, width: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font(weight)
	l.font_size = size
	l.pixel_size = 0.0035
	l.modulate = color
	l.outline_size = outline
	l.outline_modulate = Color("#fffbf2")
	l.position = pos
	l.double_sided = false
	l.shaded = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width
	parent.add_child(l)
	return l


## One-shot burst of flat-coloured particles (confetti, dust, sweat, sparkles).
static func burst(parent: Node3D, pos: Vector3, colors: Array, amount: int = 16, speed: float = 1.6, gravity: float = -4.0, size: float = 0.05, lifetime: float = 0.9, dir: Vector3 = Vector3.UP, spread: float = 60.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = lifetime
	p.explosiveness = 0.92
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = speed * 0.6
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	p.color_ramp = g
	var cg := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / maxf(1.0, colors.size() - 1))
		cols.append(colors[i])
	cg.offsets = offs
	cg.colors = cols
	p.color_initial_ramp = cg
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	p.mesh = m
	p.angular_velocity_min = -360
	p.angular_velocity_max = 360
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
