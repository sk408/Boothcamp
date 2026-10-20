extends RefCounted
## DeskArt (arcade, story-internal): the pictures of Ears, Please! (the intake boxes, the wall's
## rule cards, the stamps' icons, the otoscope, a hearing aid, the pushpin), drawn in code like
## every other picture in the game (no image files). Each draw takes the canvas, a centre and a size.
##   DeskArt.intake(ci, "dizziness", centre, 24.0)
##   DeskArt.rule(ci, "gap", centre, 30.0)
##   DeskArt.stamp_icon(ci, &"refer", centre, 22.0)

const INK := Color("#2e2442")
const SKIN := Color("#ffcf9e")
const SKIN_SHADE := Color("#e09a6c")
const WATER := Color("#36a3e7")
const WAX := Color("#c98d2e")
const ENVELOPE := Color("#fffbf2")
const AID := Color("#d9d2c5")
const FLAG := Color("#e5383b")


## An ear seen from the side (the outer ear's C shape), facing right.
static func ear(ci: CanvasItem, c: Vector2, s: float, fill: Color = SKIN, odd := false) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a := -PI * 0.55 + i * PI * 1.25 / 20.0
		var r := s * (0.5 + (0.12 * sin(a * 3.0) if odd else 0.0))
		pts.append(c + Vector2(cos(a) * r * 0.75, sin(a) * r))
	var body := pts.duplicate()
	body.append(c + Vector2(s * 0.12, s * 0.2))
	body.append(c + Vector2(s * 0.12, -s * 0.2))
	ci.draw_colored_polygon(body, fill)
	ci.draw_polyline(pts, INK, maxf(2.0, s * 0.09), true)
	# the inner fold and the canal
	ci.draw_arc(c + Vector2(-s * 0.05, 0), s * 0.25, -PI * 0.4, PI * 0.6, 12, SKIN_SHADE, maxf(2.0, s * 0.07))
	ci.draw_circle(c + Vector2(s * 0.06, s * 0.04), s * 0.08, INK)


## The intake box pictures (DeskRules.INTAKE_WORDS ids).
static func intake(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	match id:
		"drainage":
			ear(ci, c + Vector2(-s * 0.15, -s * 0.1), s * 0.8)
			for i in 2:
				var d := c + Vector2(s * 0.1 + i * s * 0.18, s * 0.3 + i * s * 0.2)
				ci.draw_circle(d, s * 0.1, WATER)
				ci.draw_colored_polygon(PackedVector2Array([d + Vector2(-s * 0.1, 0), d + Vector2(0, -s * 0.2), d + Vector2(s * 0.1, 0)]), WATER)
		"pain":
			ear(ci, c + Vector2(-s * 0.15, 0), s * 0.8)
			var z := PackedVector2Array()
			for i in 6:
				z.append(c + Vector2(s * 0.3 + (i % 2) * s * 0.18, -s * 0.45 + i * s * 0.18))
			ci.draw_polyline(z, FLAG, maxf(2.5, s * 0.1), true)
		"dizziness":
			var sp := PackedVector2Array()
			for i in 40:
				var a := i * 0.42
				sp.append(c + Vector2(cos(a), sin(a)) * s * (0.06 + i * 0.012))
			ci.draw_polyline(sp, Color("#8e5cc4"), maxf(2.5, s * 0.1), true)
			UiDraw.star(ci, c + Vector2(s * 0.45, -s * 0.4), s * 0.14, Color("#ffd23f"))
			UiDraw.star(ci, c + Vector2(-s * 0.5, -s * 0.3), s * 0.1, Color("#ffd23f"))
		"one_sided":
			ear(ci, c + Vector2(-s * 0.2, 0), s * 0.8)
			for i in 3:
				ci.draw_arc(c + Vector2(s * 0.1, 0), s * (0.25 + i * 0.15), -0.6, 0.6, 8, Color("#ff9f1c"), maxf(2.0, s * 0.08))
		"wax":
			ear(ci, c, s * 0.9)
			ci.draw_circle(c + Vector2(s * 0.06, s * 0.04), s * 0.17, WAX)
			ci.draw_arc(c + Vector2(s * 0.06, s * 0.04), s * 0.17, 0.0, TAU, 16, INK, 2.0)
		"deformity":
			ear(ci, c, s * 0.9, SKIN, true)
			ci.draw_string(ThemeDB.fallback_font, c + Vector2(s * 0.35, -s * 0.25), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(s * 0.7), INK)


## The otoscope (the LOOKED boxes come from looking in the ear).
static func otoscope(ci: CanvasItem, c: Vector2, s: float) -> void:
	ci.draw_line(c + Vector2(-s * 0.1, s * 0.5), c + Vector2(-s * 0.1, -s * 0.05), INK, s * 0.26)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.25, -s * 0.05), c + Vector2(s * 0.05, -s * 0.05),
		c + Vector2(s * 0.5, -s * 0.3), c + Vector2(s * 0.5, -s * 0.42), c + Vector2(-s * 0.25, -s * 0.3)]), INK)
	ci.draw_circle(c + Vector2(-s * 0.32, -s * 0.18), s * 0.1, Color("#ffd23f"))


## The wall's rule cards: tick, one_ear, gap, sudden.
static func rule(ci: CanvasItem, id: String, c: Vector2, s: float) -> void:
	match id:
		"tick":
			var box := Rect2(c - Vector2(s * 0.42, s * 0.42), Vector2(s * 0.84, s * 0.84))
			UiDraw.rounded_rect(ci, box, Color("#ffd23f"), 6, 3, INK)
			UiDraw.check(ci, c, s * 0.7, INK, maxf(3.0, s * 0.14))
			_flag(ci, c + Vector2(s * 0.75, s * 0.4), s * 0.75)
		"one_ear":
			# the red O line stays high, the blue X line drops away: the split
			var o := PackedVector2Array()
			var x := PackedVector2Array()
			for i in 5:
				var px := c.x - s * 0.9 + i * s * 0.45
				o.append(Vector2(px, c.y - s * 0.4 + i * s * 0.06))
				x.append(Vector2(px, c.y - s * 0.35 + (i * s * 0.06 if i < 2 else s * 0.1 + (i - 1) * s * 0.22)))
			ci.draw_polyline(o, Palette.RIGHT_RED, 3.0, true)
			ci.draw_polyline(x, Palette.LEFT_BLUE, 3.0, true)
			for p: Vector2 in o:
				UiDraw.ear_symbol(ci, p, "right", s * 0.2, 2.5)
			for p: Vector2 in x:
				UiDraw.ear_symbol(ci, p, "left", s * 0.2, 2.5)
		"gap":
			# masked bone [ high above air O, with the gap between them
			var air := c + Vector2(0, s * 0.45)
			var bone := c + Vector2(0, -s * 0.45)
			ci.draw_line(bone + Vector2(0, s * 0.18), air - Vector2(0, s * 0.2), Color("#ff9f1c"), 3.0)
			UiDraw.arrow(ci, bone + Vector2(s * 0.45, s * 0.45), s * 0.5, Vector2.UP, Color("#ff9f1c"))
			UiDraw.audiogram_symbol(ci, bone, "right", &"bc_masked", s * 0.38, 3.0)
			UiDraw.audiogram_symbol(ci, air, "right", &"ac", s * 0.38, 3.0)
		"sudden":
			alarm_clock(ci, c, s)


static func _flag(ci: CanvasItem, foot: Vector2, s: float) -> void:
	ci.draw_line(foot, foot + Vector2(0, -s), INK, 3.0)
	ci.draw_colored_polygon(PackedVector2Array([foot + Vector2(0, -s), foot + Vector2(s * 0.6, -s * 0.8), foot + Vector2(0, -s * 0.6)]), FLAG)


static func alarm_clock(ci: CanvasItem, c: Vector2, s: float) -> void:
	for side in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(side * s * 0.42, -s * 0.42), s * 0.18, Color("#ffd23f"))
	ci.draw_circle(c, s * 0.5, INK)
	ci.draw_circle(c, s * 0.42, ENVELOPE)
	ci.draw_line(c, c + Vector2(0, -s * 0.3), INK, 3.0)
	ci.draw_line(c, c + Vector2(s * 0.22, 0), INK, 3.0)


## The stamps' icons: FIT a hearing aid, REFER an envelope, DOCTOR TODAY a phone.
static func stamp_icon(ci: CanvasItem, stamp: StringName, c: Vector2, s: float, col: Color = INK) -> void:
	match stamp:
		&"fit":
			aid(ci, c, s, col)
		&"refer":
			var r := Rect2(c - Vector2(s * 0.6, s * 0.4), Vector2(s * 1.2, s * 0.8))
			ci.draw_rect(r, ENVELOPE)
			ci.draw_rect(r, col, false, 3.0)
			ci.draw_polyline(PackedVector2Array([r.position, c + Vector2(0, s * 0.05), Vector2(r.end.x, r.position.y)]), col, 3.0)
		&"today":
			ci.draw_arc(c, s * 0.5, PI * 0.15, PI * 0.85, 12, col, s * 0.22)
			ci.draw_circle(c + Vector2(-s * 0.42, s * 0.25), s * 0.16, col)
			ci.draw_circle(c + Vector2(s * 0.42, s * 0.25), s * 0.16, col)


## A behind-the-ear hearing aid: the curved body, the hook and the tube.
static func aid(ci: CanvasItem, c: Vector2, s: float, col: Color = INK) -> void:
	var body := PackedVector2Array()
	for i in 13:
		var a := PI * 0.2 + i * PI * 1.1 / 12.0
		body.append(c + Vector2(cos(a) * s * 0.3 + s * 0.1, sin(a) * s * 0.55))
	ci.draw_colored_polygon(body, AID)
	ci.draw_polyline(body, col, 3.0, true)
	ci.draw_arc(c + Vector2(s * 0.25, -s * 0.5), s * 0.22, PI, TAU, 10, col, 3.0)
	ci.draw_line(c + Vector2(s * 0.47, -s * 0.5), c + Vector2(s * 0.5, -s * 0.1), col, 3.0)


## The red pushpin that marks the proof.
static func pin(ci: CanvasItem, tip: Vector2, s: float) -> void:
	var head := tip + Vector2(s * 0.35, -s * 0.8)
	ci.draw_line(tip, head, INK, 3.0)
	ci.draw_circle(head, s * 0.34, INK)
	ci.draw_circle(head, s * 0.28, FLAG)
	ci.draw_circle(head + Vector2(-s * 0.08, -s * 0.08), s * 0.08, Color(1, 1, 1, 0.7))
