extends SubViewport
## FaceRig: a tiny 2D viewport that paints a cartoon face, used as a texture on a 3D head
## (world/shaders/toon_face.gdshader projects it onto the front of the head).
## It only re-renders when the expression changes (UPDATE_ONCE), so it is cheap.
##
## State (set with set_state / set_part):
##   eyes:  &"open" &"happy" &"closed" &"wide" &"squint" &"sleepy" &"wink" &"worried" &"stars"
##   mouth: &"smile" &"grin" &"flat" &"frown" &"o" &"yawn" &"wavy" &"talk" &"oops" &"tongue"
##   look:  Vector2 pupil offset (-1..1)
##   blush, sweat, tear: bool
## style: &"gus", &"doris" or &"owl" (layout and colours differ).
## Layout: texture covers face_size metres of the head, centred on face_offset (see the shader).

const SIZE := 256
const INK := Color("#2e2442")
const WHITE := Color("#fffdf8")

var style: StringName = &"gus"
var state: Dictionary = {"eyes": &"open", "mouth": &"smile", "look": Vector2.ZERO, "blush": false, "sweat": false, "tear": false}
var talk_open := false
var blinking := false
## pixel layout per style
var eye_y := 108.0
var eye_dx := 43.0
var eye_r := 25.0
var mouth_y := 190.0
var mouth_w := 34.0

var _canvas: Control


func _init(face_style: StringName = &"gus") -> void:
	style = face_style
	size = Vector2i(SIZE, SIZE)
	transparent_bg = true
	disable_3d = true
	render_target_update_mode = SubViewport.UPDATE_ONCE
	render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	match style:
		&"doris":
			eye_y = 112.0
			eye_dx = 40.0
			eye_r = 21.0
			mouth_y = 178.0
			mouth_w = 28.0
		&"owl":
			eye_y = 112.0
			eye_dx = 46.0
			eye_r = 27.0
			mouth_y = 168.0
			mouth_w = 16.0


func _ready() -> void:
	_canvas = Control.new()
	_canvas.size = Vector2(SIZE, SIZE)
	_canvas.draw.connect(_paint)
	add_child(_canvas)
	refresh()


func set_state(new_state: Dictionary) -> void:
	for k: String in new_state:
		state[k] = new_state[k]
	refresh()


func set_part(key: String, value: Variant) -> void:
	if state.get(key) == value:
		return
	state[key] = value
	refresh()


func set_talk_open(open: bool) -> void:
	if talk_open == open:
		return
	talk_open = open
	refresh()


func set_blink(closed: bool) -> void:
	if blinking == closed:
		return
	blinking = closed
	refresh()


func refresh() -> void:
	if _canvas:
		_canvas.queue_redraw()
	render_target_update_mode = SubViewport.UPDATE_ONCE


# ---------------------------------------------------------------- painting

func _paint() -> void:
	var c := _canvas
	if style == &"owl":
		_paint_owl_disc(c)
	var eyes: StringName = state.get("eyes", &"open")
	if blinking and (eyes == &"open" or eyes == &"wide" or eyes == &"worried"):
		eyes = &"closed"
	var look: Vector2 = state.get("look", Vector2.ZERO)
	for side: int in [-1, 1]:
		var e := Vector2(128 + eye_dx * side, eye_y)
		_paint_eye(c, e, side, eyes, look)
	if bool(state.get("blush", false)) or style == &"doris":
		var a := 0.55 if bool(state.get("blush", false)) else 0.3
		for side: int in [-1, 1]:
			_ellipse(c, Vector2(128 + (eye_dx + 22) * side, eye_y + 40), Vector2(17, 9), Color(1.0, 0.45, 0.45, a))
	var mouth: StringName = state.get("mouth", &"smile")
	if talk_open and mouth != &"yawn":
		mouth = &"talk"
	_paint_mouth(c, mouth)
	if bool(state.get("sweat", false)):
		_paint_drop(c, Vector2(128 + eye_dx + 38, eye_y - 30), 13.0, Color("#7fd3ff"))
	if bool(state.get("tear", false)):
		_paint_drop(c, Vector2(128 - eye_dx, eye_y + eye_r + 14), 9.0, Color("#7fd3ff"))


func _paint_owl_disc(c: Control) -> void:
	# barn owl heart-shaped facial disc
	var pts := PackedVector2Array()
	for i in 48:
		var t := TAU * i / 48.0
		# heart curve, flipped so the dip is at the top
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(Vector2(128 + x * 6.6, 122 - y * 6.2))
	var rim := PackedVector2Array()
	for p in pts:
		rim.append(Vector2(128, 122) + (p - Vector2(128, 122)) * 1.07)
	c.draw_colored_polygon(rim, Color("#b9773f"))
	c.draw_colored_polygon(pts, Color("#fff4e2"))
	# soft feather lines
	for i in 7:
		var a := lerpf(-0.9, 0.9, i / 6.0)
		var from := Vector2(128, 150) + Vector2(sin(a), -cos(a)) * 30.0
		var to := Vector2(128, 150) + Vector2(sin(a), -cos(a)) * 92.0
		c.draw_line(from, to, Color("#f1dcc0"), 3.0, true)


func _paint_eye(c: Control, e: Vector2, side: int, eyes: StringName, look: Vector2) -> void:
	var r := eye_r
	var lw := 6.0
	match eyes:
		&"closed":
			c.draw_arc(e + Vector2(0, -4), r * 0.8, 0.25, PI - 0.25, 16, INK, lw, true)
		&"happy":
			c.draw_arc(e + Vector2(0, 8), r * 0.8, PI + 0.3, TAU - 0.3, 16, INK, lw, true)
		&"squint":
			# ">  <" squeezed eyes, tips pointing at the nose
			var tip := e + Vector2(-side * r * 0.35, 0)
			var pts := PackedVector2Array([e + Vector2(side * r * 0.8, -r * 0.45), tip, e + Vector2(side * r * 0.8, r * 0.45)])
			c.draw_polyline(pts, INK, lw, true)
		&"stars":
			_star(c, e, r * 1.05, Color("#ffd23f"))
			_star(c, e, r * 0.5, Color("#fff6c8"))
		_:
			var pr := r * 0.52
			var white_r := r
			if eyes == &"wide":
				white_r = r * 1.15
				pr = r * 0.3
			if style == &"owl":
				# big dark owl eyes with highlights
				c.draw_circle(e, white_r + 4, INK)
				c.draw_circle(e + look * 3.0, white_r - 1.0, Color("#3b2a4f"))
				c.draw_circle(e + look * 5.0 + Vector2(-7, -8), white_r * 0.32, WHITE)
				c.draw_circle(e + look * 5.0 + Vector2(8, 7), white_r * 0.14, WHITE)
			else:
				c.draw_circle(e, white_r + 3.5, INK)
				c.draw_circle(e, white_r, WHITE)
				var pp := e + look * (white_r - pr - 2.0)
				c.draw_circle(pp, pr, INK)
				c.draw_circle(pp + Vector2(-pr * 0.35, -pr * 0.4), pr * 0.35, WHITE)
			if eyes == &"sleepy":
				# heavy eyelid over the top half
				var lid := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					lid.append(e + Vector2(cos(a), sin(a)) * (white_r + 4.5))
				lid.append(e + Vector2(white_r + 4.5, 3))
				lid.append(e + Vector2(-white_r - 4.5, 3))
				c.draw_colored_polygon(lid, _lid_color())
				c.draw_line(e + Vector2(-white_r - 3, 3), e + Vector2(white_r + 3, 3), INK, 5.0, true)
			elif eyes == &"worried":
				var lid2 := PackedVector2Array([e + Vector2(-white_r - 5, -white_r - 6), e + Vector2(white_r + 5, -white_r - 6), e + Vector2(white_r + 5, -white_r * 0.2 * side - 4), e + Vector2(-white_r - 5, white_r * 0.2 * side - 4)])
				c.draw_colored_polygon(lid2, _lid_color())
	if eyes == &"wink" and side > 0:
		# redraw: right-hand eye closed
		c.draw_circle(e, r + 4.5, _lid_color())
		c.draw_arc(e + Vector2(0, 8), r * 0.8, PI + 0.3, TAU - 0.3, 16, INK, lw, true)


func _lid_color() -> Color:
	match style:
		&"owl":
			return Color("#fff4e2")
		&"doris":
			return Color("#ffd6b0")
	return Color("#ffcf9e")


func _paint_mouth(c: Control, mouth: StringName) -> void:
	var m := Vector2(128, mouth_y)
	var w := mouth_w
	var lw := 6.0
	var lip := Color("#d9465f") if style == &"doris" else INK
	var inside := Color("#7a2a3a")
	var tongue := Color("#ff8a8a")
	if style == &"owl":
		# the 3D beak does the talking; just a hint of a smile under it
		if mouth == &"frown" or mouth == &"wavy":
			c.draw_arc(m + Vector2(0, 14), 12, PI + 0.6, TAU - 0.6, 10, INK, 4.0, true)
		return
	match mouth:
		&"smile":
			c.draw_arc(m + Vector2(0, -w * 0.55), w, 0.45, PI - 0.45, 18, lip, lw, true)
		&"grin":
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(m + Vector2(cos(a) * w, sin(a) * w * 0.75))
			c.draw_colored_polygon(pts, inside)
			_ellipse(c, m + Vector2(0, w * 0.5), Vector2(w * 0.5, w * 0.22), tongue)
			c.draw_line(m + Vector2(-w, 0), m + Vector2(w, 0), lip, lw, true)
			c.draw_polyline(pts, lip, lw * 0.8, true)
		&"flat":
			c.draw_line(m + Vector2(-w * 0.6, 4), m + Vector2(w * 0.6, 4), lip, lw, true)
		&"frown":
			c.draw_arc(m + Vector2(0, w * 0.9), w * 0.8, PI + 0.6, TAU - 0.6, 14, lip, lw, true)
		&"o":
			_ellipse(c, m + Vector2(0, 6), Vector2(w * 0.32, w * 0.42), inside)
			c.draw_arc(m + Vector2(0, 6), w * 0.38, 0, TAU, 18, lip, lw * 0.8, true)
		&"talk":
			_ellipse(c, m + Vector2(0, 6), Vector2(w * 0.55, w * 0.42), inside)
			_ellipse(c, m + Vector2(0, 14), Vector2(w * 0.3, w * 0.15), tongue)
			c.draw_arc(m + Vector2(0, 6), w * 0.55, 0, TAU, 20, lip, lw * 0.7, true)
		&"yawn":
			_ellipse(c, m + Vector2(0, 14), Vector2(w * 0.62, w * 0.95), inside)
			_ellipse(c, m + Vector2(0, 30), Vector2(w * 0.38, w * 0.25), tongue)
		&"wavy":
			var pts2 := PackedVector2Array()
			for i in 13:
				var x := lerpf(-w * 0.75, w * 0.75, i / 12.0)
				pts2.append(m + Vector2(x, 4 + sin(i * 1.3) * 5.0))
			c.draw_polyline(pts2, lip, lw * 0.8, true)
		&"oops":
			c.draw_line(m + Vector2(-w * 0.6, 6), m + Vector2(w * 0.6, -2), lip, lw, true)
			_ellipse(c, m + Vector2(w * 0.35, 12), Vector2(w * 0.18, w * 0.14), tongue)
		&"tongue":
			c.draw_arc(m + Vector2(0, -w * 0.5), w * 0.8, 0.5, PI - 0.5, 14, lip, lw, true)
			_ellipse(c, m + Vector2(w * 0.25, w * 0.38), Vector2(w * 0.22, w * 0.25), tongue)


func _paint_drop(c: Control, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(at + Vector2(cos(a) * r, sin(a) * r))
	pts.append(at + Vector2(0, -r * 2.2))
	c.draw_colored_polygon(pts, col)
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), INK, 3.0, true)
	c.draw_circle(at + Vector2(-r * 0.35, -r * 0.1), r * 0.25, WHITE)


func _ellipse(c: Control, at: Vector2, radii: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	c.draw_colored_polygon(pts, col)


func _star(c: Control, center: Vector2, radius: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(pts, col)
