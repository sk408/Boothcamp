extends RefCounted
## Neutral 3D shapes of hearing aid styles, built from swept tubes in code. No product shapes are copied: each
## style is a generic form (RIC, mini BTE, in-the-canal, completely-in-canal) with its parts named for labels.

const SHELLS := {
	"silver": Color(0.76, 0.77, 0.79),
	"graphite": Color(0.36, 0.37, 0.40),
	"graphite_dark": Color(0.22, 0.23, 0.25),
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
	var R := 1.9 if bte else 1.7
	var thick := 0.46 if bte else 0.36
	# The case: a crescent over the top of the ear, thick in the middle, rounded at both ends.
	var body := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 28
	for i in n + 1:
		var t := float(i) / n
		var a := deg_to_rad(lerp(25.0, 160.0, t))
		body.append(Vector3(cos(a) * R, sin(a) * R - R * 0.55, 0))
		var end_round := sqrt(max(0.0, sin(PI * t)))
		radii.append(thick * lerp(0.55, 1.0, end_round) * (0.2 + 0.8 * end_round) + 0.02)
	root.add_child(_sweep(body, radii, 0.78, 20, _mat(col, 0.38)))
	parts["Case"] = body[n / 2] + Vector3(0, 0, thick * 0.8)
	# Two microphone ports and a button along the top.
	var dark := _mat(Color(0.08, 0.08, 0.09), 0.6)
	for k in [0.38, 0.55]:
		var p := body[int(n * k)]
		var out := p.normalized() if p.length() > 0.01 else Vector3.UP
		var port := _ball(0.07, dark)
		port.position = p + Vector3(0, thick * 0.9, 0) + out * 0.02
		root.add_child(port)
	parts["Microphones"] = body[int(n * 0.47)] + Vector3(0, thick + 0.1, 0)
	var btn := _ball(0.15, _mat(col.darkened(0.25), 0.3))
	btn.scale = Vector3(1.3, 0.6, 1.0)
	btn.position = body[int(n * 0.78)] + Vector3(-0.05, thick * 0.85, 0.0)
	root.add_child(btn)
	parts["Button"] = btn.position + Vector3(0, 0.15, 0)
	# From the front end, the wire (RIC) or the tube (BTE) curves down into the canal.
	var start := body[0] + Vector3(0.0, -0.05, 0)
	var tip := Vector3(start.x + 0.3, start.y - 2.4, 0.9)
	var c1 := start + Vector3(0.9, -0.2, 0.1)
	var c2 := tip + Vector3(0.6, 0.9, 0.0)
	var path := PackedVector3Array()
	var wr := PackedFloat32Array()
	for i in 25:
		var t := float(i) / 24.0
		path.append(_bez(start, c1, c2, tip, t))
		wr.append(0.1 if bte else 0.045)
	var tube_col := Color(0.92, 0.94, 0.96, 0.55) if bte else Color(0.55, 0.57, 0.6)
	root.add_child(_sweep(path, wr, 1.0, 10, _mat(tube_col, 0.2, bte)))
	parts["Sound tube" if bte else "Receiver wire"] = path[8] + Vector3(0.12, 0, 0)
	var dir := (path[24] - path[22]).normalized()
	if not bte:
		var rec := _capsule(0.13, 0.5, _mat(Color(0.18, 0.19, 0.21), 0.4))
		rec.position = tip + dir * 0.2
		rec.look_at_from_position(rec.position, rec.position + dir, Vector3.BACK)
		rec.rotate_object_local(Vector3.RIGHT, PI / 2)
		root.add_child(rec)
		parts["Receiver"] = rec.position + Vector3(0.2, 0, 0)
	var dome := _ball(0.36, _mat(Color(0.97, 0.97, 0.98, 0.6), 0.25, true))
	dome.scale = Vector3(1.0, 0.75, 1.0)
	dome.position = tip + dir * (0.5 if not bte else 0.25)
	root.add_child(dome)
	parts["Dome"] = dome.position + Vector3(0, -0.35, 0)


static func _build_canal(root: Node3D, parts: Dictionary, col: Color, cic: bool) -> void:
	var length := 1.6 if cic else 2.2
	var r0 := 0.62 if cic else 0.82
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	var n := 32
	for i in n + 1:
		var t := float(i) / n
		# The canal bends a little: the shell follows it.
		path.append(Vector3(sin(t * 1.1) * 0.35, -t * length, t * t * 0.25))
		var taper: float = lerp(r0, r0 * 0.6, t)
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
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if see_through:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
