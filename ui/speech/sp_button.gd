class_name SpButton
extends AoButton
## SpButton: the AudiOtron's chunky AoButton with the SPEECH screen's own glyphs (ui/speech only):
## a tick (CORRECT), a cross (MISSED), a talking mouth (PRESENT) and a noise burst (MASK); (Days 4-5)
## an eye (the lens), a padlock (LOCK IN) and a stack of ticks (ALL GOT).
## Everything else (press depth, key chip, beckon ring, glow, flame) is AoButton's.

enum Glyph { NONE, CHECK, CROSS, TALK, NOISE, EYE, LOCK, ALL }

var glyph: Glyph = Glyph.NONE:
	set(v):
		glyph = v
		if v != Glyph.NONE and icon == Icon.NONE:
			icon = Icon.STAMP   # any icon: AoButton only asks for one when it has one
		queue_redraw()


func _draw_icon(c: Vector2, s: float, col: Color) -> void:
	match glyph:
		Glyph.CHECK:
			UiDraw.check(self, c + Vector2(0, 2), s * 1.05, col, 7.0)
		Glyph.CROSS:
			UiDraw.cross(self, c, s * 0.72, col, 7.0)
		Glyph.TALK:
			_draw_talk(c, s, col)
		Glyph.NOISE:
			_draw_noise(c, s, col)
		Glyph.EYE:
			_draw_eye(c, s, col)
		Glyph.LOCK:
			_draw_lock(c, s, col)
		Glyph.ALL:
			_draw_all(c, s, col)
		_:
			super(c, s, col)


## A speech balloon with three dots, and sound arcs while the word plays (glow).
func _draw_talk(c: Vector2, s: float, col: Color) -> void:
	var bc := c + Vector2(-s * 0.18, -s * 0.04)
	var r := Rect2(bc - Vector2(s * 0.5, s * 0.34), Vector2(s, s * 0.62))
	AoDraw.rbox(self, r, Color(col, 0.0), int(s * 0.26), 4, col)
	draw_colored_polygon(PackedVector2Array([r.position + Vector2(s * 0.18, r.size.y - 2.0), r.position + Vector2(s * 0.42, r.size.y - 2.0), r.position + Vector2(s * 0.08, r.size.y + s * 0.22)]), col)
	for i in 3:
		var bounce := sin(_t * 9.0 - i * 0.9) * 3.0 * glow
		draw_circle(r.get_center() + Vector2((i - 1) * s * 0.26, bounce), s * 0.07, col)
	var ac := Vector2(r.end.x + s * 0.06, r.get_center().y)
	for i in 2:
		var rr := s * (0.18 + 0.16 * i)
		var a := 0.7 + (0.12 * sin(_t * 12.0 - i) if glow > 0.0 else 0.0)
		draw_arc(ac, rr, -a, a, 14, Color(col, 0.55 + 0.45 * glow), 3.5, true)


## A hissy zig-zag burst (speech noise).
func _draw_noise(c: Vector2, s: float, col: Color) -> void:
	for row in 3:
		var pts := PackedVector2Array()
		var y := c.y + (row - 1) * s * 0.3
		for j in 7:
			var x := c.x - s * 0.5 + j * s / 6.0
			pts.append(Vector2(x, y + (s * 0.1 if j % 2 == 0 else -s * 0.1)))
		draw_polyline(pts, col, 3.5, true)


## (Days 4-5) An almond eye with its pupil (the lens).
func _draw_eye(c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.56
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for j in 13:
		var t := -1.0 + j / 6.0
		top.append(c + Vector2(t * w, -(1.0 - t * t) * s * 0.3))
		bottom.append(c + Vector2(t * w, (1.0 - t * t) * s * 0.3))
	draw_polyline(top, col, 3.5, true)
	draw_polyline(bottom, col, 3.5, true)
	draw_circle(c, s * 0.15 + 2.0 * glow, col)


## (Days 4-5) A padlock (LOCK IN).
func _draw_lock(c: Vector2, s: float, col: Color) -> void:
	var body := Rect2(c + Vector2(-s * 0.36, -s * 0.06), Vector2(s * 0.72, s * 0.5))
	draw_arc(c + Vector2(0, -s * 0.06), s * 0.22, PI, TAU, 14, col, 4.0, true)
	AoDraw.rbox(self, body, col, int(s * 0.1))
	draw_circle(body.get_center() + Vector2(0, -s * 0.03), s * 0.06, Color(Palette.INK, 0.6))


## (Days 4-5) Three small ticks, staggered (ALL GOT).
func _draw_all(c: Vector2, s: float, col: Color) -> void:
	for i in 3:
		UiDraw.check(self, c + Vector2((i - 1) * s * 0.3, (i - 1) * s * 0.06), s * 0.42, col, 4.0)
