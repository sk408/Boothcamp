extends "res://story/games/otoscopy.gd"
## CaseOtoscopy (cases): a case's look in the ear. view "clear" = builder B's healthy drum (show_clear),
## "wax" = a plug hides the drum, "fluid" = a dull amber drum, a fluid line and bubbles, no cone of light.
## Overrides _draw_canal (otoscopy.gd connects _canal.draw to it by name, so the override dispatches).
## Story-internal:
##   var g := CaseOtoscopy.new(); hud.add_game(g)
##   await g.show_view("right", "wax", caption)    # the light sweeps, the caption names it
## Reads otoscopy.gd's view_center, ear and _canal; the drum numbers below mirror its _draw_canal.

## The eardrum as otoscopy.gd draws it (right ear; the left ear mirrors x and the tilt).
const DRUM_OFFSET := Vector2(-6, 6)
const DRUM_RX := 112.0
const DRUM_RY := 98.0
const DRUM_TILT := -0.25
const DRUM_GREY := Color("#c9c6cf")
## Wax: a glossy plug, a touch bigger than the drum so none of it peeks out.
const WAX := Color("#b5762b")
const WAX_RIM := Color("#8a5320")
const WAX_SHINE := Color("#f0c27a")
const WAX_FLAKE := Color("#d39a4c")
const WAX_RX := 124.0
const WAX_RY := 112.0
## Lumps on the plug (drum frame: x, y, radius).
const WAX_LUMPS: Array[Vector3] = [Vector3(-48, -40, 34), Vector3(34, -52, 32), Vector3(64, 6, 34), Vector3(-62, 26, 32), Vector3(6, 40, 38), Vector3(-6, -8, 30)]
## Flakes stuck to the canal wall (from the view centre: x, y, size).
const WAX_FLAKES: Array[Vector3] = [Vector3(122, -116, 11), Vector3(-152, -58, 9), Vector3(58, 164, 13)]
const FLAKE_SHAPE: Array[float] = [1.0, 0.62, 0.92, 0.55, 0.86, 0.7]
## Fluid: an amber wash, the fluid line (meniscus) and bubbles behind the drum.
const FLUID := Color("#e0a64a")
const FLUID_LINE := Color("#c98a2e")
## Bubbles (level frame: x, y, radius): one at the fluid line, the rest under it, clear of the malleus handle.
const BUBBLES: Array[Vector3] = [Vector3(-68, -26, 8), Vector3(-42, 14, 12), Vector3(-76, 36, 7), Vector3(50, 0, 10), Vector3(78, 30, 6), Vector3(-14, 58, 11), Vector3(40, 60, 8)]

var view := "clear"


## (coroutine) An input-free look at a case's ear: view "clear", "wax" or "fluid", then show_clear's sweep.
func show_view(p_ear: String, p_view: String, text: String) -> void:
	view = p_view
	await show_clear(p_ear, text)


func _draw_canal() -> void:
	super()
	match view:
		"wax":
			_draw_wax()
		"fluid":
			_draw_fluid()


# ---------------------------------------------------------------- wax

func _draw_wax() -> void:
	var flip := _flip()
	# a soft smear where the plug meets the deep canal wall
	_canal.draw_colored_polygon(_drum_pts(_wax_outline(WAX_RX + 14.0, WAX_RY + 12.0)), Color(WAX_RIM, 0.35))
	# the plug: amber where the light catches it, brown in the shadows
	var body := _wax_outline(WAX_RX, WAX_RY)
	var cols := PackedColorArray()
	for p: Vector2 in body:
		cols.append(_wax_shade(p))
	var outline := _drum_pts(body)
	_canal.draw_polygon(outline, cols)
	# lumps: a little raised, a crease underneath, a wet shine on top
	for lump: Vector3 in WAX_LUMPS:
		var lc := Vector2(lump.x, lump.y)
		var lump_pts := _oval(lc, lump.z, lump.z * 0.9, 20, 0.08)
		var lump_cols := PackedColorArray()
		for p: Vector2 in lump_pts:
			lump_cols.append(_wax_shade(p).lightened(0.07))
		_canal.draw_polygon(_drum_pts(lump_pts), lump_cols)
		_drum_arc(lc, lump.z * 0.95, 0.2, 2.3, Color(WAX_RIM, 0.75), 3.5)
		_drum_arc(lc, lump.z * 0.62, 3.6, 4.5, Color(WAX_SHINE, 0.7), 4.0)
	outline.append(outline[0])
	_canal.draw_polyline(outline, WAX_RIM, 5.0, true)
	# the big glossy streak and a few sparkles
	_drum_arc(Vector2.ZERO, 92.0, 3.55, 4.35, Color(WAX_SHINE, 0.9), 8.0)
	_drum_arc(Vector2.ZERO, 78.0, 3.7, 4.1, Color(1, 1, 1, 0.5), 3.0)
	for dot: Vector3 in [Vector3(-66, -64, 5), Vector3(-30, -84, 3.5), Vector3(54, -30, 3.5), Vector3(-14, 20, 3)]:
		_canal.draw_circle(_drum_pt(Vector2(dot.x, dot.y)), dot.z, Color("#fff6e0", 0.9))
	# dry flakes on the canal wall
	for i in WAX_FLAKES.size():
		var f := WAX_FLAKES[i]
		var fc := view_center + Vector2(f.x * flip, f.y)
		var flake := PackedVector2Array()
		for j in FLAKE_SHAPE.size():
			var a := TAU * j / FLAKE_SHAPE.size() + i * 1.3
			flake.append(fc + Vector2(cos(a) * flip, sin(a)) * f.z * FLAKE_SHAPE[j])
		_canal.draw_colored_polygon(flake, WAX_FLAKE)
		flake.append(flake[0])
		_canal.draw_polyline(flake, WAX_RIM, 2.0, true)
		_canal.draw_circle(fc + Vector2(-0.25 * flip, -0.3) * f.z, f.z * 0.22, WAX_SHINE)


## The plug's lumpy edge (drum frame): slow bumps, plus two lobes that spill onto the deep canal wall.
## The radius never drops below 0.92, so the plug always hides the drum and its rim.
func _wax_outline(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 56:
		var a := TAU * i / 56.0
		var k := 1.0 + 0.05 * sin(5.0 * a + 0.7) + 0.03 * sin(9.0 * a + 2.1)
		k += 0.16 * exp(-pow(wrapf(a - 1.95, -PI, PI) / 0.32, 2.0))
		k += 0.08 * exp(-pow(wrapf(a + 0.75, -PI, PI) / 0.25, 2.0))
		pts.append(Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts


## Amber toward the light (upper left, mirrored in the left ear), brown away from it.
func _wax_shade(local: Vector2) -> Color:
	var k := clampf(0.5 + 0.5 * local.dot(Vector2(-0.6, -0.8)) / 130.0, 0.0, 1.0)
	return WAX.darkened(0.2).lerp(WAX.lightened(0.14), k)


# ---------------------------------------------------------------- fluid

func _draw_fluid() -> void:
	var flip := _flip()
	var still := bool(Game.settings.get("reduced_motion", false))
	var t := 0.0 if still else Time.get_ticks_msec() / 1000.0
	# drum-coloured patch over the cone of light (same triangle as otoscopy.gd, a touch bigger)
	var drum := _drum_center()
	var cone_local: Array[Vector2] = [Vector2(8, 8), Vector2(56, 74), Vector2(26, 84)]
	var mid := (cone_local[0] + cone_local[1] + cone_local[2]) / 3.0
	var cone := PackedVector2Array()
	for p: Vector2 in cone_local:
		var q := mid + (p - mid) * 1.08
		cone.append(drum + Vector2(q.x * flip, q.y))
	_canal.draw_colored_polygon(cone, DRUM_GREY)
	# the amber wash over the whole drum
	var oval := _oval(Vector2.ZERO, DRUM_RX, DRUM_RY, 40)
	_canal.draw_colored_polygon(_drum_pts(oval), Color(FLUID, 0.55))
	# a little deeper below the fluid line (fluid finds its level, so this part ignores the drum's tilt)
	var level_oval := PackedVector2Array()
	for p: Vector2 in oval:
		level_oval.append(p.rotated(DRUM_TILT))
	var below := PackedVector2Array()
	for x in range(-130, 131, 10):
		below.append(Vector2(x, _meniscus_y(x, t)))
	below.append(Vector2(130, 140))
	below.append(Vector2(-130, 140))
	for part: PackedVector2Array in Geometry2D.intersect_polygons(level_oval, below):
		var tint := PackedVector2Array()
		for p: Vector2 in part:
			tint.append(_level_pt(p))
		_canal.draw_colored_polygon(tint, Color(FLUID_LINE, 0.22))
	# the fluid line across the upper third, with a glint under it
	var line := PackedVector2Array()
	var glint := PackedVector2Array()
	for x in range(-110, 111, 5):
		var p := Vector2(x, _meniscus_y(x, t))
		var d := p.rotated(-DRUM_TILT)
		if pow(d.x / DRUM_RX, 2.0) + pow(d.y / DRUM_RY, 2.0) < 0.95:
			line.append(_level_pt(p))
			glint.append(_level_pt(p + Vector2(0, 5)))
	if line.size() > 1:
		_canal.draw_polyline(glint, Color(1, 1, 1, 0.3), 2.0, true)
		_canal.draw_polyline(line, FLUID_LINE, 4.0, true)
	# bubbles, gently bobbing
	for i in BUBBLES.size():
		var b := BUBBLES[i]
		var bob := Vector2(sin(t * 0.9 + i * 1.7) * 1.5, sin(t * 1.7 + i * 2.3) * 3.0)
		var bp := _level_pt(Vector2(b.x, b.y) + bob)
		_canal.draw_circle(bp, b.z, Color(1, 1, 1, 0.14))
		_canal.draw_arc(bp, b.z, 0, TAU, 20, Color(1, 1, 1, 0.85), 2.0, true)
		_canal.draw_circle(bp + Vector2(-0.35 * flip, -0.35) * b.z, maxf(1.8, b.z * 0.28), Color(1, 1, 1, 0.95))


## The fluid line's height (level frame): edges creep up the wall, a tiny ripple rides along it.
func _meniscus_y(x: float, t: float) -> float:
	return -40.0 + 9.0 * (1.0 - pow(x / 100.0, 2.0)) + sin(x * 0.08 + t * 2.0) * 1.2


# ---------------------------------------------------------------- the drum frame

func _flip() -> float:
	return -1.0 if ear == "left" else 1.0


func _drum_center() -> Vector2:
	return view_center + Vector2(DRUM_OFFSET.x * _flip(), DRUM_OFFSET.y)


## A point in the drum frame (right ear, before the tilt) to canal coordinates, as otoscopy.gd places the drum.
func _drum_pt(local: Vector2) -> Vector2:
	var flip := _flip()
	return _drum_center() + Vector2(local.x * flip, local.y).rotated(DRUM_TILT * flip)


## The level frame: the drum frame mirrored for the ear but not tilted, so fluid lies flat.
func _level_pt(local: Vector2) -> Vector2:
	return _drum_center() + Vector2(local.x * _flip(), local.y)


func _drum_pts(local: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in local:
		out.append(_drum_pt(p))
	return out


## A closed oval in the drum frame; wobble > 0 makes it lumpy.
func _oval(center: Vector2, rx: float, ry: float, n: int, wobble := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + wobble * sin(3.0 * a + center.x * 0.1)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry) * k)
	return pts


## An arc in the drum frame (angles in that frame, so it mirrors with the ear).
func _drum_arc(center: Vector2, r: float, a0: float, a1: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(a0, a1, i / 12.0)
		pts.append(_drum_pt(center + Vector2(cos(a), sin(a)) * r))
	_canal.draw_polyline(pts, color, width, true)
