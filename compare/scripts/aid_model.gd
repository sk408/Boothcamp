extends RefCounted
## Neutral 3D shapes of hearing aid styles, built from swept tubes in code. No product shapes are copied: each
## style is a generic form (RIC, mini BTE, in-the-canal, completely-in-canal) with its parts named for labels.

const SHELLS := {
	"silver": Color(0.76, 0.77, 0.79),
	"graphite": Color(0.36, 0.37, 0.40),
	"graphite_dark": Color(0.3, 0.31, 0.34),
	"beige": Color(0.85, 0.75, 0.63),
	"rose": Color(0.86, 0.67, 0.62),
}

const STYLE_NAMES := {
	"ric": "Receiver in canal (RIC)",
	"bte": "Mini behind the ear (BTE)",
	"itc": "In the canal (ITC)",
	"cic": "Completely in canal (CIC)",
}

## Plain words for each part, shown in the 3D view.
const PART_HELP := {
	"Microphones": "Two small openings pick up sound from in front and behind.",
	"Button": "Press to change program or volume.",
	"Receiver wire": "A thin wire carries the sound to the speaker.",
	"Receiver": "The speaker. It sits inside your ear canal.",
	"Dome": "A soft tip that holds the speaker in place.",
	"Sound tube": "A clear tube carries sound into the ear.",
	"Faceplate": "The outer face, with the microphone and battery door.",
	"Vent": "A small hole that lets air in so your own voice sounds natural.",
	"Removal line": "Pull it to take the aid out.",
	"Shell": "A custom shell made from an impression of your ear.",
	"Case": "Holds the battery, chip and microphones.",
}


## Returns {"root": Node3D, "parts": {name: Vector3}} for a style.
static func build(style: String, shell: String) -> Dictionary:
	var col: Color = SHELLS.get(shell, SHELLS.silver)
	var root := Node3D.new()
	var parts := {}
	match style:
		"itc", "cic":
			_build_canal(root, parts, col, style == "cic")
		"bte":
			_build_behind(root, parts, col, true)
		_:
			_build_behind(root, parts, col, false)
	return {"root": root, "parts": parts}


static func _build_behind(root: Node3D, parts: Dictionary, col: Color, bte: bool) -> void:
	# The case: a short kidney lying along the top of the ear, about three times as long as it is tall, with blunt
	# ends and a flatter inner face. A 60 degree arc of a wide circle, swept with a superellipse thickness.
	var R := 3.4 if bte else 3.0
	var thick := 0.62 if bte else 0.52
	var span := 70.0 if bte else 60.0
	var body := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 40
	for i in n + 1:
		var t := float(i) / n
		var a := deg_to_rad(90.0 - span * 0.5 + span * t)
		body.append(Vector3(cos(a) * R, sin(a) * R - R, 0))
		# Superellipse ends: full thickness almost to the tips, then a quick round-off.
		radii.append(max(thick * pow(max(0.0, 1.0 - pow(absf(2.0 * t - 1.0), 6.0)), 1.0 / 6.0), 0.02))
	var shell := _mat(col, 0.55)
	root.add_child(_sweep(body, radii, 0.72, 28, shell))
	var top := func(t: float, lift: float) -> Vector3:
		# A point on the case's top ridge at t (0 = front end, 1 = back end).
		var a := deg_to_rad(90.0 - span * 0.5 + span * t)
		var p := Vector3(cos(a) * R, sin(a) * R - R, 0)
		return p + Vector3(cos(a), sin(a), 0) * (thick * lift)
	parts["Case"] = body[n / 2] + Vector3(0, -thick * 0.2, thick * 0.9)
	# Two microphone slots and a raised button on the top ridge; two gold charging contacts underneath.
	var dark := _mat(Color(0.07, 0.07, 0.08), 0.6)
	for k: float in [0.36, 0.5]:
		var slot := _capsule(0.045, 0.22, dark)
		slot.position = top.call(k, 0.97)
		slot.rotation = Vector3(PI / 2, 0, 0)
		root.add_child(slot)
	parts["Microphones"] = top.call(0.43, 1.4)
	var btn := _capsule(0.09, 0.42, _mat(col.darkened(0.22), 0.4))
	btn.position = top.call(0.74, 0.93)
	btn.rotation = Vector3(0, 0, deg_to_rad(90.0 - span * 0.5 + span * 0.74) + PI / 2)
	root.add_child(btn)
	parts["Button"] = top.call(0.8, 1.5)
	var gold := _mat(Color(0.85, 0.68, 0.3), 0.3)
	gold.metallic = 0.8
	for k: float in [0.44, 0.56]:
		var c := _ball(0.07, gold)
		c.scale = Vector3(1, 0.5, 1)
		c.position = top.call(k, -0.95)
		root.add_child(c)
	# From the top front end, the hair-thin wire (RIC) or the clear tube (BTE) arcs forward over the ear, then
	# down and inward into the canal.
	var start: Vector3 = top.call(0.02, 0.35)
	var tip := start + Vector3(0.9, -2.9, 0.9)
	var c1 := start + Vector3(1.0, 0.35, 0.1)
	var c2 := tip + Vector3(0.35, 1.5, -0.2)
	var path := PackedVector3Array()
	var wr := PackedFloat32Array()
	for i in 41:
		var t := float(i) / 40.0
		path.append(_bez(start, c1, c2, tip, t))
		wr.append(0.09 if bte else 0.03)
	var wire_col := Color(0.86, 0.9, 0.94, 0.5) if bte else Color(0.62, 0.65, 0.7, 0.85)
	root.add_child(_sweep(path, wr, 1.0, 10, _mat(wire_col, 0.25, true)))
	parts["Sound tube" if bte else "Receiver wire"] = path[10] + Vector3(0.15, 0.05, 0)
	var dir := (path[40] - path[37]).normalized()
	var end := tip
	if not bte:
		var rec := _capsule(0.12, 0.46, _mat(col.darkened(0.08), 0.5))
		rec.transform = Transform3D(_along(dir), tip + dir * 0.2)
		root.add_child(rec)
		parts["Receiver"] = tip + dir * 0.2 + Vector3(0.25, 0, 0)
		end = tip + dir * 0.4
	# A soft mushroom dome: a flattened cap over a short stem.
	var dome_mat := _mat(Color(0.97, 0.97, 0.98, 0.55), 0.3, true)
	var cap := _ball(0.32, dome_mat)
	cap.transform = Transform3D(_along(dir).scaled(Vector3(1.0, 0.55, 1.0)), end + dir * 0.12)
	root.add_child(cap)
	parts["Dome"] = end + dir * 0.2 + Vector3(-0.35, -0.1, 0)


## A basis whose Y axis points along dir (capsules and spheres are built along Y).
static func _along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.BACK)
	if x.length() < 0.1:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	return Basis(x, y, x.cross(y).normalized())


static func _build_canal(root: Node3D, parts: Dictionary, col: Color, cic: bool) -> void:
	var length := 1.5 if cic else 1.8
	var r0 := 0.62 if cic else 0.9
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 32
	for i in n + 1:
		var t := float(i) / n
		# The canal bends a little: the shell follows it.
		path.append(Vector3(t * t * 0.45, -t * length, t * t * 0.3))
		# A rounded body that fills the ear's bowl, narrowing to a short canal tip.
		var taper: float = lerp(r0, r0 * (0.62 if cic else 0.5), smoothstep(0.25, 0.6, t))
		# Round the deep end off smoothly over the last 30 %.
		var cap := sqrt(max(0.0, 1.0 - pow((t - 0.7) / 0.3, 2.0))) if t > 0.7 else 1.0
		radii.append(max(taper * cap, 0.01))
	root.add_child(_sweep(path, radii, 0.82, 22, _mat(col, 0.42)))
	parts["Shell"] = path[n / 2] + Vector3(radii[n / 2] + 0.1, 0, 0)
	# Faceplate disc on the outer end.
	var face := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r0 * 1.02
	cyl.bottom_radius = r0 * 1.02
	cyl.height = 0.12
	face.mesh = cyl
	face.scale = Vector3(1.0, 1.0, 0.82)
	face.material_override = _mat(col.darkened(0.12), 0.3)
	face.position = Vector3(0, 0.05, 0)
	root.add_child(face)
	parts["Faceplate"] = Vector3(-r0 * 1.5, 0.0, 0)
	var dark := _mat(Color(0.08, 0.08, 0.09), 0.6)
	var vent := _ball(0.08, dark)
	vent.position = Vector3(r0 * 0.45, 0.12, 0.1)
	root.add_child(vent)
	parts["Vent"] = vent.position + Vector3(r0 * 0.9, 0.05, 0)
	var mic := _ball(0.06, dark)
	mic.position = Vector3(-r0 * 0.3, 0.12, -0.25)
	root.add_child(mic)
	parts["Microphones"] = mic.position + Vector3(-0.2, 0.45, -0.2)
	if cic:
		var line := PackedVector3Array()
		var lr := PackedFloat32Array()
		for i in 8:
			var t := float(i) / 7.0
			line.append(Vector3(0.1 + t * 0.15, 0.1 + t * 0.7, 0.2 + t * 0.1))
			lr.append(0.03)
		root.add_child(_sweep(line, lr, 1.0, 8, _mat(Color(0.2, 0.2, 0.22), 0.5)))
		parts["Removal line"] = line[7] + Vector3(0.1, 0.05, 0)


## A tube along `points` with a radius per point; `flat` squashes the cross-section into an ellipse.
static func _sweep(points: PackedVector3Array, radii: PackedFloat32Array, flat: float, seg: int,
		mat: Material) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	var count := points.size()
	var normal := Vector3.ZERO
	for i in count:
		var tan := (points[min(i + 1, count - 1)] - points[max(i - 1, 0)]).normalized()
		if i == 0:
			normal = tan.cross(Vector3.BACK)
			if normal.length() < 0.1:
				normal = tan.cross(Vector3.UP)
			normal = normal.normalized()
		else:
			# Parallel transport keeps the ring from twisting.
			normal = (normal - tan * normal.dot(tan)).normalized()
		var bin := tan.cross(normal).normalized()
		for s in seg:
			var th := TAU * s / seg
			var off := normal * cos(th) * radii[i] + bin * sin(th) * radii[i] * flat
			verts.append(points[i] + off)
			norms.append((normal * cos(th) + bin * sin(th) / max(flat, 0.01)).normalized())
	for i in count - 1:
		for s in seg:
			var a := i * seg + s
			var b := i * seg + (s + 1) % seg
			var c := a + seg
			var d := b + seg
			idx.append_array([a, b, c, b, d, c])
	# Caps.
	for e: int in [0, count - 1]:
		var center := verts.size()
		var tan2 := (points[min(e + 1, count - 1)] - points[max(e - 1, 0)]).normalized()
		verts.append(points[e])
		norms.append(-tan2 if e == 0 else tan2)
		for s in seg:
			var a := e * seg + s
			var b := e * seg + (s + 1) % seg
			if e == 0:
				idx.append_array([center, b, a])
			else:
				idx.append_array([center, a, b])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


static func _bez(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


static func _ball(r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 20
	m.rings = 10
	mi.mesh = m
	mi.material_override = mat
	return mi


static func _capsule(r: float, h: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	mi.mesh = m
	mi.material_override = mat
	return mi


static func _mat(c: Color, rough: float, see_through: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.05
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
