extends RefCounted
## Room: builds the cheerful procedural clinic (world-internal). Low-poly primitives only.
## Layout (metres, the camera looks toward -Z):
##   back wall z = -4.2; entrance door on the left (x -4.6); posters and a clock in the middle;
##   the desk with the AudiOtron monitor (Hoot perches on it) centre-left; the sound booth
##   on the right (x 1.8..5.6, z -4.0..-0.5) with a big front window and a side door.
## build() returns a Dictionary of the nodes the clinic animates.

const Kit := preload("res://world/kit.gd")

const WALL := Color("#f7d9b0")
const WALL_LOW := Color("#efc08f")
const TRIM := Color("#fff3dc")
const FLOOR := Color("#8fcfb3")
const WOOD := Color("#c8874b")
const BOOTH := Color("#dfe9f2")
const BOOTH_TRIM := Color("#8fb0cf")
const INK := Color("#2e2442")

const BOOTH_X0 := 1.8
const BOOTH_X1 := 5.6
const BOOTH_Z0 := -4.0
const BOOTH_Z1 := -0.5
const BOOTH_H := 2.7
const CHAIR_POS := Vector3(3.7, 0, -2.75)
const DESK_POS := Vector3(-0.8, 0, -0.95)
const MONITOR_POS := Vector3(0.05, 0.86, -1.0)


static func build(root: Node3D, comfy_chair: bool) -> Dictionary:
	var refs: Dictionary = {}
	var room := Node3D.new()
	room.name = "Room"
	root.add_child(room)
	refs["room"] = room
	_shell(room, refs)
	_entrance(room, refs)
	_wall_decor(room, refs)
	_desk(room, refs)
	_booth(room, refs, comfy_chair)
	_plants(room)
	_fish_tank(room, refs)
	return refs


# ---------------------------------------------------------------- walls and floor

static func _shell(room: Node3D, refs: Dictionary) -> void:
	var flat := {"outline": 0.0, "rim": 0.0}
	var floor_opts := flat.duplicate()
	floor_opts.merge({"pattern": 3, "pattern_scale": 1.0, "pattern_color": FLOOR.lightened(0.12), "pattern_mix": 1.0})
	Kit.box(room, Vector3(16, 0.2, 11), Vector3(0, -0.1, 0.8), FLOOR, floor_opts)
	# back wall with wainscot and trim
	Kit.box(room, Vector3(16, 4.6, 0.2), Vector3(0, 2.3, -4.3), WALL, flat)
	var low := flat.duplicate()
	low.merge({"pattern": 2, "pattern_scale": 2.5, "pattern_color": WALL_LOW.darkened(0.05), "pattern_mix": 1.0})
	Kit.box(room, Vector3(16, 1.0, 0.06), Vector3(0, 0.5, -4.18), WALL_LOW, low)
	Kit.box(room, Vector3(16, 0.08, 0.1), Vector3(0, 1.02, -4.15), TRIM, {"outline": 0.0})
	Kit.box(room, Vector3(16, 0.12, 0.08), Vector3(0, 0.06, -4.15), WOOD.darkened(0.1), {"outline": 0.0})
	# side walls
	Kit.box(room, Vector3(0.2, 4.6, 11), Vector3(-7.2, 2.3, 0.8), WALL.darkened(0.05), flat)
	Kit.box(room, Vector3(0.06, 1.0, 11), Vector3(-7.08, 0.5, 0.8), WALL_LOW.darkened(0.05), low)
	Kit.box(room, Vector3(0.2, 4.6, 11), Vector3(7.2, 2.3, 0.8), WALL.darkened(0.05), flat)
	# a big round rug under the desk area
	Kit.cylinder(room, 2.3, 2.3, 0.02, Vector3(-1.2, 0.01, -1.5), Color("#ffcf6b"), {"outline": 0.0, "rim": 0.0}, 40)
	Kit.cylinder(room, 1.75, 1.75, 0.022, Vector3(-1.2, 0.012, -1.5), Color("#ff9f7a"), {"outline": 0.0, "rim": 0.0}, 40)
	Kit.cylinder(room, 1.2, 1.2, 0.024, Vector3(-1.2, 0.014, -1.5), Color("#ffcf6b"), {"outline": 0.0, "rim": 0.0}, 40)


static func _entrance(room: Node3D, refs: Dictionary) -> void:
	var door_x := -4.6
	var z := -4.18
	# frame
	for sx: int in [-1, 1]:
		Kit.box(room, Vector3(0.14, 2.5, 0.16), Vector3(door_x + 0.72 * sx, 1.25, z + 0.02), Color("#8e5cc4"), {"outline": 0.01})
	Kit.box(room, Vector3(1.58, 0.16, 0.16), Vector3(door_x, 2.52, z + 0.02), Color("#8e5cc4"), {"outline": 0.01})
	# dark doorway behind the door (the waiting room)
	Kit.box(room, Vector3(1.3, 2.44, 0.05), Vector3(door_x, 1.22, z - 0.02), Color("#ffe2b8"), {"outline": 0.0, "rim": 0.0})
	# the door: pivot on the hinge (left edge), swings into the room
	var pivot := Node3D.new()
	pivot.name = "EntranceDoor"
	pivot.position = Vector3(door_x - 0.64, 0, z + 0.06)
	room.add_child(pivot)
	refs["door"] = pivot
	Kit.box(pivot, Vector3(1.28, 2.4, 0.09), Vector3(0.64, 1.2, 0), Color("#ff6f59"), {"outline": 0.012})
	# porthole + panels
	var port := Kit.cylinder(pivot, 0.2, 0.2, 0.11, Vector3(0.64, 1.75, 0), Color("#bfe6ff"), {"outline": 0.01, "emission": Color("#bfe6ff") * 0.25}, 20)
	port.rotation.x = PI / 2.0
	var ring := Kit.torus(pivot, 0.19, 0.25, Vector3(0.64, 1.75, 0.055), Color("#ffd23f"), {"outline": 0.008}, 22, 6)
	ring.rotation.x = PI / 2.0
	Kit.box(pivot, Vector3(0.9, 0.7, 0.02), Vector3(0.64, 0.7, 0.05), Color("#ff6f59").darkened(0.08), {"outline": 0.006})
	Kit.sphere(pivot, 0.065, Vector3(1.12, 1.1, 0.09), Color("#ffd23f"), Vector3.ONE, {"outline": 0.008}, 12)
	# sign above the door
	var sign := Node3D.new()
	sign.position = Vector3(door_x, 2.95, z + 0.12)
	room.add_child(sign)
	Kit.box(sign, Vector3(1.7, 0.42, 0.06), Vector3.ZERO, Color("#2e2442"), {"outline": 0.0})
	Kit.label(sign, "WAITING ROOM", Vector3(0, 0, 0.04), 64, Color("#ffd23f"), 0, 700)
	# a little "open" door hanger
	var hanger := Node3D.new()
	hanger.position = Vector3(0.64, 1.35, 0.06)
	pivot.add_child(hanger)
	Kit.box(hanger, Vector3(0.36, 0.2, 0.012), Vector3.ZERO, Color("#fffbf2"), {"outline": 0.005})
	Kit.label(hanger, "COME IN!", Vector3(0, 0, 0.008), 26, Color("#e5383b"), 0, 700)
	refs["door_spot_outside"] = Vector3(door_x, 0, -5.2)
	refs["door_spot_inside"] = Vector3(door_x + 0.1, 0, -3.1)


static func _wall_decor(room: Node3D, refs: Dictionary) -> void:
	var z := -4.17
	# poster 1: Red = Right
	var p1 := Node3D.new()
	p1.position = Vector3(-2.75, 2.25, z)
	p1.rotation.z = 0.03
	room.add_child(p1)
	Kit.box(p1, Vector3(1.25, 1.45, 0.04), Vector3.ZERO, Color("#fffbf2"), {"outline": 0.01})
	Kit.box(p1, Vector3(1.25, 0.08, 0.05), Vector3(0, 0.68, 0.0), Color("#ffd23f"), {"outline": 0.0})
	var o := Kit.torus(p1, 0.17, 0.25, Vector3(-0.29, 0.22, 0.04), Color("#e5383b"), {"outline": 0.008}, 24, 8)
	o.rotation.x = PI / 2.0
	for a: float in [0.785, -0.785]:
		var bar := Kit.box(p1, Vector3(0.07, 0.48, 0.05), Vector3(0.3, 0.22, 0.04), Color("#2d6cdf"), {"outline": 0.008})
		bar.rotation.z = a
	Kit.label(p1, "RED = RIGHT", Vector3(0, -0.22, 0.03), 58, Color("#e5383b"), 0, 700)
	Kit.label(p1, "BLUE = LEFT", Vector3(0, -0.45, 0.03), 58, Color("#2d6cdf"), 0, 700)
	# poster 2: the original surround sound
	var p2 := Node3D.new()
	p2.position = Vector3(-0.85, 2.45, z)
	p2.rotation.z = -0.025
	room.add_child(p2)
	Kit.box(p2, Vector3(1.5, 1.2, 0.04), Vector3.ZERO, Color("#bfe6ff"), {"outline": 0.01})
	var ear := Node3D.new()
	ear.position = Vector3(-0.36, 0.08, 0.04)
	p2.add_child(ear)
	var outer := Kit.torus(ear, 0.13, 0.22, Vector3.ZERO, Color("#ffb38a"), {"outline": 0.008}, 22, 8)
	outer.rotation.x = PI / 2.0
	outer.scale = Vector3(0.8, 1.0, 1.25)
	Kit.sphere(ear, 0.09, Vector3(0.02, -0.04, 0.0), Color("#f5a37f"), Vector3(1, 1, 0.4), {"outline": 0.006}, 12)
	Kit.sphere(ear, 0.07, Vector3(-0.02, -0.25, 0.0), Color("#ffb38a"), Vector3(1, 1, 0.5), {"outline": 0.006}, 12)
	for i in 3:
		var wave := Kit.arc_tube(p2, 0.12 + i * 0.07, 0.012, -45, 45, 6, Color("#8e5cc4"), {"outline": 0.0})
		wave.position = Vector3(-0.12, 0.08, 0.04)
	Kit.label(p2, "EARS", Vector3(0.36, 0.22, 0.03), 74, Color("#2e2442"), 0, 700)
	Kit.label(p2, "the original\nsurround sound", Vector3(0.33, -0.05, 0.03), 34, Color("#2e2442"), 0, 500)
	Kit.label(p2, "(est. a long time ago)", Vector3(0.0, -0.45, 0.03), 26, Color("#6b5e7e"), 0, 500)
	# small framed "license" style certificate
	var p3 := Node3D.new()
	p3.position = Vector3(0.75, 2.6, z)
	room.add_child(p3)
	Kit.box(p3, Vector3(0.7, 0.55, 0.04), Vector3.ZERO, Color("#c8874b"), {"outline": 0.008})
	Kit.box(p3, Vector3(0.58, 0.43, 0.05), Vector3.ZERO, Color("#fffbf2"), {"outline": 0.0})
	Kit.label(p3, "Certified\nBeep Wrangler", Vector3(0, 0.06, 0.03), 22, Color("#2e2442"), 0, 600)
	Kit.cylinder(p3, 0.06, 0.06, 0.02, Vector3(0.18, -0.12, 0.035), Color("#ffd23f"), {"outline": 0.004}, 14).rotation.x = PI / 2.0
	# clock (ticks)
	var clock := Node3D.new()
	clock.position = Vector3(-1.95, 3.35, z + 0.02)
	room.add_child(clock)
	var face := Kit.cylinder(clock, 0.3, 0.3, 0.06, Vector3.ZERO, Color("#fffbf2"), {"outline": 0.012}, 28)
	face.rotation.x = PI / 2.0
	var rim := Kit.torus(clock, 0.28, 0.34, Vector3(0, 0, 0.03), Color("#ff6f59"), {"outline": 0.008}, 28, 8)
	rim.rotation.x = PI / 2.0
	for i in 12:
		var a := TAU * i / 12.0
		Kit.box(clock, Vector3(0.025, 0.05 if i % 3 == 0 else 0.03, 0.01), Vector3(sin(a) * 0.23, cos(a) * 0.23, 0.035), INK, {"outline": 0.0}).rotation.z = -a
	var hour := Node3D.new()
	hour.position = Vector3(0, 0, 0.045)
	clock.add_child(hour)
	Kit.box(hour, Vector3(0.035, 0.14, 0.01), Vector3(0, 0.06, 0), INK, {"outline": 0.0})
	var minute := Node3D.new()
	minute.position = Vector3(0, 0, 0.05)
	clock.add_child(minute)
	Kit.box(minute, Vector3(0.025, 0.21, 0.01), Vector3(0, 0.095, 0), Color("#e5383b"), {"outline": 0.0})
	hour.rotation.z = -1.2
	refs["clock_minute"] = minute
	refs["clock_hour"] = hour


static func _desk(room: Node3D, refs: Dictionary) -> void:
	var desk := Node3D.new()
	desk.name = "Desk"
	desk.position = DESK_POS
	room.add_child(desk)
	refs["desk"] = desk
	Kit.box(desk, Vector3(2.9, 0.1, 1.05), Vector3(0, 0.81, 0), WOOD, {"outline": 0.014})
	Kit.box(desk, Vector3(2.8, 0.08, 1.0), Vector3(0, 0.73, 0), WOOD.darkened(0.12), {"outline": 0.0})
	# drawer block (left) and legs (right)
	Kit.box(desk, Vector3(0.75, 0.72, 0.95), Vector3(-1.0, 0.38, 0), WOOD.darkened(0.06), {"outline": 0.012})
	for i in 2:
		Kit.box(desk, Vector3(0.62, 0.26, 0.02), Vector3(-1.0, 0.56 - i * 0.32, 0.48), WOOD.lightened(0.08), {"outline": 0.006})
		Kit.sphere(desk, 0.035, Vector3(-1.0, 0.56 - i * 0.32, 0.5), Color("#ffd23f"), Vector3.ONE, {"outline": 0.005}, 10)
	for sz: int in [-1, 1]:
		Kit.cylinder(desk, 0.05, 0.04, 0.76, Vector3(1.3, 0.38, 0.42 * sz), WOOD.darkened(0.15), {"outline": 0.008}, 10)
	# AudiOtron 3000 monitor (screen faces the tester / camera)
	var mon := Node3D.new()
	mon.name = "AudiOtron"
	mon.position = MONITOR_POS - DESK_POS
	desk.add_child(mon)
	refs["monitor"] = mon
	Kit.cylinder(mon, 0.2, 0.26, 0.05, Vector3(0, 0.025, 0), Color("#6b5e7e"), {"outline": 0.008}, 18)
	Kit.box(mon, Vector3(0.1, 0.22, 0.08), Vector3(0, 0.14, -0.02), Color("#6b5e7e"), {"outline": 0.008})
	Kit.box(mon, Vector3(1.0, 0.68, 0.32), Vector3(0, 0.56, 0), Color("#ffe6a8"), {"outline": 0.014})
	Kit.box(mon, Vector3(1.0, 0.13, 0.33), Vector3(0, 0.285, 0.0), Color("#ff6f59"), {"outline": 0.008})
	Kit.box(mon, Vector3(0.84, 0.48, 0.02), Vector3(0, 0.6, 0.162), Color("#1d1a2b"), {"outline": 0.0, "emission": Color("#1d1a2b")})
	# a mini audiogram glowing on the screen
	var scr := Node3D.new()
	scr.position = Vector3(0, 0.6, 0.175)
	mon.add_child(scr)
	refs["screen"] = scr
	var pts := [Vector2(-0.3, 0.12), Vector2(-0.15, 0.09), Vector2(0.0, 0.05), Vector2(0.15, -0.06), Vector2(0.3, -0.14)]
	for i in pts.size():
		var p: Vector2 = pts[i]
		var dot := Kit.torus(scr, 0.016, 0.028, Vector3(p.x, p.y, 0), Color("#ff6f59"), {"unshaded": true}, 12, 4)
		dot.rotation.x = PI / 2.0
		if i > 0:
			var q: Vector2 = pts[i - 1]
			var seg := Kit.box(scr, Vector3((p - q).length(), 0.008, 0.004), Vector3((p.x + q.x) / 2.0, (p.y + q.y) / 2.0, 0), Color("#ff6f59"), {"unshaded": true})
			seg.rotation.z = (p - q).angle()
	Kit.box(scr, Vector3(0.7, 0.004, 0.003), Vector3(0, 0.18, 0), Color("#5d5672"), {"unshaded": true})
	Kit.box(scr, Vector3(0.7, 0.004, 0.003), Vector3(0, -0.2, 0), Color("#5d5672"), {"unshaded": true})
	var lamp := Kit.sphere(mon, 0.03, Vector3(0.4, 0.285, 0.17), Color("#36d6e7"), Vector3.ONE, {"unshaded": true}, 10)
	refs["tone_lamp"] = lamp
	Kit.label(mon, "AudiOtron 3000", Vector3(-0.06, 0.285, 0.17), 26, Color("#fffbf2"), 0, 700)
	# keyboard, mug, notepad
	Kit.box(desk, Vector3(0.62, 0.035, 0.22), Vector3(0.75, 0.875, 0.25), Color("#fffbf2"), {"outline": 0.008})
	for i in 3:
		Kit.box(desk, Vector3(0.54, 0.012, 0.04), Vector3(0.75, 0.9, 0.18 + i * 0.06), Color("#d9d1c4"), {"outline": 0.0})
	var mug := Node3D.new()
	mug.position = Vector3(1.25, 0.86, -0.1)
	desk.add_child(mug)
	Kit.cylinder(mug, 0.07, 0.065, 0.15, Vector3(0, 0.075, 0), Color("#5bc8a3"), {"outline": 0.008}, 14)
	Kit.cylinder(mug, 0.06, 0.06, 0.01, Vector3(0, 0.145, 0), Color("#7a4a2a"), {"outline": 0.0}, 14)
	var handle := Kit.torus(mug, 0.03, 0.05, Vector3(0.075, 0.075, 0), Color("#5bc8a3"), {"outline": 0.006}, 12, 6)
	handle.rotation.x = PI / 2.0
	Kit.box(desk, Vector3(0.3, 0.02, 0.38), Vector3(-0.35, 0.87, 0.15), Color("#fff8c8"), {"outline": 0.006}).rotation.y = 0.2
	var pen := Kit.cylinder(desk, 0.012, 0.012, 0.24, Vector3(-0.3, 0.885, 0.2), Color("#2d6cdf"), {"outline": 0.004}, 6)
	pen.rotation = Vector3(PI / 2.0, 0.5, 0)
	# otoscope in its little stand
	var oto := Node3D.new()
	oto.name = "Otoscope"
	oto.position = Vector3(-0.95, 0.86, 0.2)
	desk.add_child(oto)
	refs["otoscope"] = oto
	# charging cradle with the otoscope lying in it (handle along X, head + speculum at the end)
	Kit.box(oto, Vector3(0.34, 0.05, 0.14), Vector3(0, 0.025, 0), Color("#6b5e7e"), {"outline": 0.008})
	Kit.sphere(oto, 0.012, Vector3(0.13, 0.055, 0.06), Color("#5bc8a3"), Vector3.ONE, {"unshaded": true}, 8)
	var grip := Kit.cylinder(oto, 0.032, 0.036, 0.26, Vector3(-0.02, 0.085, 0), Color("#2e2442"), {"outline": 0.008}, 12)
	grip.rotation.z = PI / 2.0
	for i in 3:
		var ring := Kit.cylinder(oto, 0.039, 0.039, 0.012, Vector3(-0.1 + i * 0.045, 0.085, 0), Color("#8e84a3"), {"outline": 0.0}, 12)
		ring.rotation.z = PI / 2.0
	Kit.sphere(oto, 0.055, Vector3(0.14, 0.1, 0), Color("#3d3554"), Vector3(1.0, 0.9, 0.9), {"outline": 0.008}, 14)
	var lens := Kit.cylinder(oto, 0.04, 0.04, 0.02, Vector3(0.11, 0.1, 0), Color("#bfe6ff"), {"outline": 0.006}, 12)
	lens.rotation.z = PI / 2.0
	var cone := Kit.cylinder(oto, 0.045, 0.012, 0.12, Vector3(0.24, 0.12, 0), Color("#fffbf2"), {"outline": 0.006}, 12)
	cone.rotation.z = PI / 2.0 + 0.25
	Kit.sphere(oto, 0.011, Vector3(0.3, 0.135, 0), Color("#fff6a8"), Vector3.ONE, {"unshaded": true}, 8)
	# spare tennis ball for the walker (lol)
	Kit.sphere(desk, 0.06, Vector3(-1.25, 0.92, 0.3), Color("#d8f26b"), Vector3.ONE, {"outline": 0.008}, 12)
	# patient-side stool next to the desk
	refs["desk_spot"] = Vector3(-2.85, 0, -1.45)


static func _booth(room: Node3D, refs: Dictionary, comfy_chair: bool) -> void:
	var booth := Node3D.new()
	booth.name = "Booth"
	room.add_child(booth)
	refs["booth"] = booth
	var panel := {"outline": 0.012, "pattern": 1, "pattern_scale": 9.0, "pattern_color": BOOTH.darkened(0.12), "pattern_mix": 1.0}
	var x0 := BOOTH_X0
	var x1 := BOOTH_X1
	var z0 := BOOTH_Z0
	var z1 := BOOTH_Z1
	var h := BOOTH_H
	var t := 0.14
	var cx := (x0 + x1) / 2.0
	var cz := (z0 + z1) / 2.0
	# floor carpet
	Kit.box(booth, Vector3(x1 - x0, 0.06, z1 - z0), Vector3(cx, 0.03, cz), Color("#7d8fc6"), {"outline": 0.0, "pattern": 3, "pattern_scale": 2.0, "pattern_color": Color("#8a9ccf"), "pattern_mix": 1.0})
	# back wall + right wall + roof
	Kit.box(booth, Vector3(x1 - x0, h, t), Vector3(cx, h / 2.0, z0), BOOTH, panel)
	Kit.box(booth, Vector3(t, h, z1 - z0), Vector3(x1, h / 2.0, cz), BOOTH, panel)
	Kit.box(booth, Vector3(x1 - x0 + 0.3, 0.18, z1 - z0 + 0.3), Vector3(cx, h + 0.09, cz), BOOTH_TRIM, {"outline": 0.014})
	# left wall with a door opening (z -1.0 .. -2.1)
	var dz0 := -2.15
	var dz1 := -1.05
	var dh := 2.2
	Kit.box(booth, Vector3(t, h, dz0 - z0), Vector3(x0, h / 2.0, (z0 + dz0) / 2.0), BOOTH, panel)
	Kit.box(booth, Vector3(t, h, z1 - dz1), Vector3(x0, h / 2.0, (dz1 + z1) / 2.0), BOOTH, panel)
	Kit.box(booth, Vector3(t, h - dh, dz1 - dz0), Vector3(x0, dh + (h - dh) / 2.0, (dz0 + dz1) / 2.0), BOOTH, panel)
	# the heavy booth door (hinge at dz1, swings out toward -X)
	var door := Node3D.new()
	door.name = "BoothDoor"
	door.position = Vector3(x0 - 0.02, 0, dz1)
	booth.add_child(door)
	refs["booth_door"] = door
	Kit.box(door, Vector3(0.2, dh - 0.02, dz1 - dz0 - 0.04), Vector3(0, dh / 2.0, -(dz1 - dz0) / 2.0), Color("#c9d8e6"), {"outline": 0.014, "pattern": 1, "pattern_scale": 9.0, "pattern_color": Color("#b4c6d8"), "pattern_mix": 1.0})
	var lever := Kit.capsule(door, 0.035, 0.32, Vector3(-0.15, 1.05, -0.88), Color("#6b5e7e"), {"outline": 0.008}, 10)
	lever.rotation.x = PI / 2.0
	Kit.box(door, Vector3(0.04, 0.5, 0.06), Vector3(-0.11, 1.05, -0.92), Color("#6b5e7e"), {"outline": 0.006})
	# front wall with the big window (x 2.7..4.7, y 0.85..2.05)
	var wx0 := 2.7
	var wx1 := 4.7
	var wy0 := 0.85
	var wy1 := 2.05
	Kit.box(booth, Vector3(wx0 - x0, h, t), Vector3((x0 + wx0) / 2.0, h / 2.0, z1), BOOTH, panel)
	Kit.box(booth, Vector3(x1 - wx1, h, t), Vector3((wx1 + x1) / 2.0, h / 2.0, z1), BOOTH, panel)
	Kit.box(booth, Vector3(wx1 - wx0, wy0, t), Vector3((wx0 + wx1) / 2.0, wy0 / 2.0, z1), BOOTH, panel)
	Kit.box(booth, Vector3(wx1 - wx0, h - wy1, t), Vector3((wx0 + wx1) / 2.0, wy1 + (h - wy1) / 2.0, z1), BOOTH, panel)
	# chunky window frame
	var fr := Color("#ffd23f")
	var fo := {"outline": 0.01}
	Kit.box(booth, Vector3(wx1 - wx0 + 0.2, 0.1, 0.22), Vector3((wx0 + wx1) / 2.0, wy0, z1 + 0.02), fr, fo)
	Kit.box(booth, Vector3(wx1 - wx0 + 0.2, 0.1, 0.22), Vector3((wx0 + wx1) / 2.0, wy1, z1 + 0.02), fr, fo)
	Kit.box(booth, Vector3(0.1, wy1 - wy0, 0.22), Vector3(wx0, (wy0 + wy1) / 2.0, z1 + 0.02), fr, fo)
	Kit.box(booth, Vector3(0.1, wy1 - wy0, 0.22), Vector3(wx1, (wy0 + wy1) / 2.0, z1 + 0.02), fr, fo)
	# glass: faint tint + two glints in the corners
	var glass := Kit.box(booth, Vector3(wx1 - wx0, wy1 - wy0, 0.01), Vector3((wx0 + wx1) / 2.0, (wy0 + wy1) / 2.0, z1 + 0.03), Color("#bfe6ff"), {"alpha": 0.1})
	glass.name = "Glass"
	for g: Array in [[Vector3(wx1 - 0.3, wy1 - 0.22, z1 + 0.04), 0.06], [Vector3(wx1 - 0.18, wy1 - 0.3, z1 + 0.04), 0.03]]:
		var glint := Kit.box(booth, Vector3(g[1], 0.32, 0.005), g[0], Color.WHITE, {"alpha": 0.45})
		glint.rotation.z = -0.7
	# corner bumpers
	for p: Vector2 in [Vector2(x0, z1), Vector2(x1, z1)]:
		Kit.cylinder(booth, 0.1, 0.1, h, Vector3(p.x, h / 2.0, p.y), BOOTH_TRIM, {"outline": 0.01}, 12)
	# sign + "testing" lamp above the window
	var sign := Node3D.new()
	sign.position = Vector3(cx + 0.1, 2.38, z1 + 0.09)
	booth.add_child(sign)
	Kit.box(sign, Vector3(1.9, 0.38, 0.06), Vector3.ZERO, Color("#2e2442"), {"outline": 0.0})
	Kit.label(sign, "SOUND BOOTH", Vector3(-0.15, 0.0, 0.035), 56, Color("#fffbf2"), 0, 700)
	var lamp := Kit.sphere(sign, 0.1, Vector3(0.75, 0.0, 0.05), Color("#6b5e7e"), Vector3(1, 1, 0.6), {"outline": 0.008}, 14)
	refs["booth_lamp"] = lamp
	refs["booth_lamp_off"] = lamp.material_override
	refs["booth_lamp_on"] = Kit.toon(Color("#ff6f59"), {"outline": 0.008, "emission": Color("#ff6f59") * 0.9})
	var quiet := Kit.label(booth, "shh... testing!", Vector3(cx + 0.1, 0.55, z1 + 0.09), 30, Color("#6b5e7e"), 0, 600)
	quiet.visible = false
	refs["booth_quiet"] = quiet
	# interior: a "hang in there" poster behind the patient, a speaker grill, a small table
	var poster := Node3D.new()
	poster.position = Vector3(cx - 1.0, 1.65, z0 + 0.09)
	booth.add_child(poster)
	Kit.box(poster, Vector3(0.6, 0.75, 0.03), Vector3.ZERO, Color("#fffbf2"), {"outline": 0.008})
	Kit.box(poster, Vector3(0.012, 0.25, 0.01), Vector3(0, 0.18, 0.02), Color("#6b5e7e"), {"outline": 0.0})
	var dangling := Kit.sphere(poster, 0.08, Vector3(0, 0.02, 0.03), Color("#ffb38a"), Vector3(0.7, 1.0, 0.4), {"outline": 0.006}, 12)
	dangling.rotation.z = 0.3
	Kit.label(poster, "HANG IN\nTHERE", Vector3(0, -0.24, 0.02), 26, Color("#2e2442"), 0, 700)
	var spk := Kit.cylinder(booth, 0.22, 0.22, 0.06, Vector3(x1 - 0.12, 2.1, cz), Color("#6b5e7e"), {"outline": 0.01}, 20)
	spk.rotation.z = PI / 2.0
	Kit.cylinder(booth, 0.15, 0.15, 0.065, Vector3(x1 - 0.12, 2.1, cz), Color("#2e2442"), {"outline": 0.0, "pattern": 1, "pattern_scale": 30.0, "pattern_color": Color("#6b5e7e"), "pattern_mix": 1.0}, 20).rotation.z = PI / 2.0
	# chair (or the comfy-chair upgrade)
	var chair := Node3D.new()
	chair.name = "BoothChair"
	chair.position = CHAIR_POS
	booth.add_child(chair)
	refs["chair"] = chair
	if comfy_chair:
		_comfy_chair(chair)
	else:
		_plain_chair(chair)
	refs["booth_door_outside"] = Vector3(x0 - 0.75, 0, (dz0 + dz1) / 2.0)
	refs["booth_door_inside"] = Vector3(x0 + 0.6, 0, (dz0 + dz1) / 2.0)
	refs["chair_front"] = CHAIR_POS + Vector3(0, 0, 0.55)
	refs["window_center"] = Vector3((wx0 + wx1) / 2.0, (wy0 + wy1) / 2.0, z1)


static func _plain_chair(chair: Node3D) -> void:
	var c := Color("#8e5cc4")
	Kit.box(chair, Vector3(0.78, 0.1, 0.62), Vector3(0, 0.36, 0), c, {"outline": 0.012})
	Kit.box(chair, Vector3(0.72, 0.06, 0.56), Vector3(0, 0.43, 0.0), c.lightened(0.2), {"outline": 0.008})
	Kit.box(chair, Vector3(0.78, 0.75, 0.1), Vector3(0, 0.76, -0.3), c, {"outline": 0.012})
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			Kit.cylinder(chair, 0.03, 0.03, 0.34, Vector3(0.33 * sx, 0.17, 0.25 * sz), Color("#6b5e7e"), {"outline": 0.006}, 8)


static func _comfy_chair(chair: Node3D) -> void:
	var c := Color("#ff6f59")
	var cushion := Color("#ffd23f")
	Kit.box(chair, Vector3(1.05, 0.38, 0.8), Vector3(0, 0.2, 0), c, {"outline": 0.014})
	Kit.capsule(chair, 0.16, 0.8, Vector3(0, 0.44, 0.05), cushion, {"outline": 0.012}, 14).rotation.z = PI / 2.0
	Kit.box(chair, Vector3(1.05, 0.95, 0.24), Vector3(0, 0.75, -0.32), c, {"outline": 0.014})
	for sx: int in [-1, 1]:
		Kit.capsule(chair, 0.13, 0.82, Vector3(0.5 * sx, 0.55, 0.0), c.lightened(0.1), {"outline": 0.012}, 14).rotation.x = PI / 2.0
	Kit.sphere(chair, 0.12, Vector3(0.25, 0.95, -0.15), Color("#5bc8a3"), Vector3(1.3, 1.0, 0.6), {"outline": 0.01}, 12)


static func _plants(room: Node3D) -> void:
	_plant(room, Vector3(-6.3, 0, -3.5), 1.25)
	_plant(room, Vector3(6.4, 0, -0.2), 1.0)
	_plant(room, Vector3(-2.9, 0, -3.65), 0.75)
	# desk succulent
	var s := Node3D.new()
	s.position = DESK_POS + Vector3(-1.25, 0.86, -0.3)
	room.add_child(s)
	Kit.cylinder(s, 0.09, 0.07, 0.13, Vector3(0, 0.065, 0), Color("#ff9f7a"), {"outline": 0.008}, 12)
	for i in 5:
		var a := TAU * i / 5.0
		var leaf := Kit.sphere(s, 0.06, Vector3(cos(a) * 0.05, 0.16, sin(a) * 0.05), Color("#5bc8a3"), Vector3(0.7, 1.3, 0.7), {"outline": 0.006}, 10)
		leaf.rotation = Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5)


static func _plant(room: Node3D, pos: Vector3, s: float) -> void:
	var p := Node3D.new()
	p.position = pos
	p.scale = Vector3.ONE * s
	room.add_child(p)
	Kit.cylinder(p, 0.28, 0.21, 0.45, Vector3(0, 0.225, 0), Color("#e07a4f"), {"outline": 0.012}, 14)
	Kit.cylinder(p, 0.3, 0.3, 0.07, Vector3(0, 0.45, 0), Color("#c8603b"), {"outline": 0.01}, 14)
	var greens := [Color("#5bc8a3"), Color("#46b08e"), Color("#7ad6b3")]
	var leaves := [[Vector3(0, 0.95, 0), 0.32], [Vector3(-0.22, 0.75, 0.08), 0.24], [Vector3(0.22, 0.8, -0.05), 0.26], [Vector3(0.05, 1.25, 0.02), 0.22], [Vector3(-0.12, 1.1, -0.1), 0.2]]
	for i in leaves.size():
		var l: Array = leaves[i]
		Kit.sphere(p, l[1], l[0], greens[i % 3], Vector3(1.0, 1.15, 1.0), {"outline": 0.012}, 14)


static func _fish_tank(room: Node3D, refs: Dictionary) -> void:
	var t := Node3D.new()
	t.position = Vector3(-6.35, 0, -0.8)
	t.rotation.y = PI / 2.0
	room.add_child(t)
	Kit.box(t, Vector3(1.3, 0.85, 0.55), Vector3(0, 0.425, 0), Color("#8e5cc4"), {"outline": 0.012})
	Kit.box(t, Vector3(1.15, 0.6, 0.45), Vector3(0, 1.15, 0), Color("#7fd3ff"), {"alpha": 0.35})
	Kit.box(t, Vector3(1.19, 0.06, 0.49), Vector3(0, 1.47, 0), Color("#2e2442"), {"outline": 0.006})
	Kit.box(t, Vector3(1.15, 0.08, 0.45), Vector3(0, 0.89, 0), Color("#ffe2b8"), {"outline": 0.0})
	for i in 3:
		var weed := Kit.capsule(t, 0.03, 0.3 + i * 0.06, Vector3(-0.4 + i * 0.12, 1.05, -0.1), Color("#46b08e"), {"outline": 0.0}, 6)
		weed.rotation.z = 0.15 * (i - 1)
	var fish := Node3D.new()
	fish.position = Vector3(0, 1.18, 0.05)
	t.add_child(fish)
	Kit.sphere(fish, 0.07, Vector3.ZERO, Color("#ff9f1c"), Vector3(1.4, 1.0, 0.7), {"outline": 0.006}, 12)
	var tail := Kit.cylinder(fish, 0.0, 0.06, 0.08, Vector3(-0.12, 0, 0), Color("#ff6f59"), {"outline": 0.005}, 6)
	tail.rotation.z = PI / 2.0
	Kit.sphere(fish, 0.012, Vector3(0.06, 0.02, 0.04), Color("#2e2442"), Vector3.ONE, {"outline": 0.0}, 6)
	refs["fish"] = fish
	Kit.label(t, "Bubbles", Vector3(0, 0.6, 0.29), 30, Color("#fffbf2"), 0, 700)
