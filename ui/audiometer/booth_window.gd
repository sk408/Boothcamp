class_name AoBoothWindow
extends Control
## AoBoothWindow: the live window into the sound booth (ui/ only). Shows the clinic's booth
## camera (Stage.get_booth_texture(); a placeholder when no clinic is loaded) inside a chunky
## frame, a big PRESS lamp that flashes lime when the patient presses, sound waves on the
## side of the test ear while the tone plays, and little emote bubbles for reactions.
## The patient faces us: his RIGHT ear is on the viewer's LEFT.

var texture: Texture2D
var tone_glow: float = 0.0
var tone_ear: String = "right"
## (v3) The ear the masking noise plays into ("" = masker off): hissy squiggles on that side.
var noise_ear: String = ""
var _press := 0.0
var _press_ear := "right"
var _emote := ""
var _emote_t := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func flash_press(ear: String) -> void:
	_press = 1.0
	_press_ear = ear


func emote(kind: String) -> void:
	_emote = kind
	_emote_t = 1.4


## Global position of the PRESS lamp (for particles).
func lamp_global_position() -> Vector2:
	return get_global_transform_with_canvas() * _lamp_center()


func _lamp_center() -> Vector2:
	return Vector2(size.x - 44.0, size.y - 42.0)


func glass_rect() -> Rect2:
	return Rect2(Vector2(12, 12), size - Vector2(24, 24))


func _process(delta: float) -> void:
	_t += delta
	_press = maxf(0.0, _press - delta * 1.5)
	_emote_t = maxf(0.0, _emote_t - delta)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Color("#5fb8a5"), 24)
	var g := glass_rect()
	if texture != null:
		var ts := texture.get_size()
		var scale := maxf(g.size.x / ts.x, g.size.y / ts.y)
		var src := Rect2((ts - g.size / scale) * 0.5, g.size / scale)
		draw_texture_rect_region(texture, g, src)
	else:
		draw_rect(g, Palette.SKY)
	# glass glare
	draw_colored_polygon(PackedVector2Array([g.position + Vector2(g.size.x * 0.55, 0), g.position + Vector2(g.size.x * 0.68, 0), g.position + Vector2(g.size.x * 0.48, g.size.y), g.position + Vector2(g.size.x * 0.35, g.size.y)]), Color(1, 1, 1, 0.07))
	# frame over the glass corners
	AoDraw.ring(self, g.grow(4.0), Color("#5fb8a5"), 18, 6)
	AoDraw.ring(self, g.grow(1.0), Palette.INK, 14, 3)
	# LIVE plate
	var plate := Rect2(Vector2(22, 20), Vector2(72, 24))
	AoDraw.rbox(self, plate, Color(Palette.INK, 0.75), 12)
	var blink := 0.6 + 0.4 * sin(_t * 4.0)
	draw_circle(plate.position + Vector2(14, 12), 5.0, Color(Palette.RIGHT_RED, blink))
	AoDraw.text_l(self, plate.position + Vector2(24, 12), "BOOTH", 13, Palette.PAPER, AoDraw.FONT_BOLD)
	# sound waves into the test ear (patient's right = viewer's left)
	if tone_glow > 0.0:
		var left_side := tone_ear == "right"
		var cx := g.position.x + (g.size.x * 0.22 if left_side else g.size.x * 0.78)
		var c := Vector2(cx, g.position.y + g.size.y * 0.42)
		var col := Palette.ear_color(tone_ear)
		for i in 3:
			var k := fmod(_t * 1.6 + i / 3.0, 1.0)
			var rr := 10.0 + 34.0 * k
			var a0 := PI - 0.7 if left_side else -0.7
			draw_arc(c, rr, a0, a0 + 1.4, 16, Color(Palette.PAPER, tone_glow * (1.0 - k)), 6.0, true)
			draw_arc(c, rr, a0, a0 + 1.4, 16, Color(col, tone_glow * (1.0 - k)), 3.0, true)
	# v3: masking noise into the other ear: grey-violet static squiggles (visible without sound)
	if noise_ear != "":
		var ls := noise_ear == "right"
		var nx := g.position.x + (g.size.x * 0.2 if ls else g.size.x * 0.8)
		var ny := g.position.y + g.size.y * 0.42
		var dir := -1.0 if ls else 1.0
		for i in 3:
			var pts := PackedVector2Array()
			var off := 14.0 + 11.0 * i
			for j in 7:
				var yy := ny - 18.0 + j * 6.0
				var jit := sin(_t * 23.0 + j * 1.7 + i * 2.3) * 3.0
				pts.append(Vector2(nx + dir * (off + (4.0 if j % 2 == 0 else -2.0) + jit), yy))
			draw_polyline(pts, Color(Palette.PAPER, 0.85), 5.0, true)
			draw_polyline(pts, Color(Palette.PLUM, 0.8), 2.5, true)
		AoDraw.text_c(self, Vector2(nx + dir * 26.0, ny + 30.0), "NOISE", 11, Palette.PAPER, AoDraw.FONT_BOLD, 4, Palette.PLUM)
	# emote bubble
	if _emote_t > 0.0 and _emote != "":
		var a := clampf(_emote_t / 0.3, 0.0, 1.0)
		var pop := 1.0 + 0.25 * maxf(0.0, (_emote_t - 1.1) / 0.3)
		var bc := Vector2(g.end.x - 40.0, g.position.y + 34.0)
		draw_set_transform(bc, 0.0, Vector2.ONE * pop)
		draw_colored_polygon(PackedVector2Array([Vector2(-10, 14), Vector2(-22, 30), Vector2(2, 18)]), Color(Palette.PAPER, a))
		draw_circle(Vector2.ZERO, 24.0, Color(Palette.INK, a))
		draw_circle(Vector2.ZERO, 21.0, Color(Palette.PAPER, a))
		var glyph := {"blast": "!!", "bored": "zzz", "groove": "~", "strain": "?", "squint": "??", "confused": "?!", "wrong": "<-", "cheer": ":)", "giggle": "hee", "ghost": "boo"}.get(_emote, "!") as String
		var gc := Palette.CORAL if _emote in ["blast", "confused"] else Palette.INK
		AoDraw.text_c(self, Vector2(0, 1), glyph, 20 if glyph.length() < 3 else 15, Color(gc, a), AoDraw.FONT_BOLD)
		if _emote == "groove":
			_note(Vector2(-4, 2), Color(Palette.PLUM, a))
		draw_set_transform(Vector2.ZERO)
	# PRESS lamp
	var lc := _lamp_center()
	var p := _press
	var s := 1.0 + 0.35 * sin(minf(1.0, (1.0 - p) * 3.0) * PI) * p
	var plate2 := Rect2(lc - Vector2(34, 32), Vector2(68, 70))
	AoDraw.rbox(self, Rect2(plate2.position + Vector2(0, 3), plate2.size), Color(Palette.INK, 0.35), 16)
	AoDraw.rbox(self, plate2, Palette.LCD_BG, 16, 3, Palette.INK)
	if p > 0.0:
		draw_circle(lc, 30.0 * s, Color(Palette.PRESS_LIME, 0.35 * p))
	draw_circle(lc, 20.0 * s, Palette.INK)
	draw_circle(lc, 16.5 * s, Palette.LCD_DIM.lerp(Palette.PRESS_LIME, minf(1.0, p * 1.6)))
	draw_circle(lc + Vector2(-5, -6) * s, 4.5 * s, Color(1, 1, 1, 0.3 + 0.4 * p))
	AoDraw.text_c(self, lc + Vector2(0, 28), "PRESS", 12, Palette.PAPER.lerp(Palette.PRESS_LIME, p), AoDraw.FONT_BOLD)
	if p > 0.4:
		_draw_hand(lc + Vector2(-44, -30 - 10.0 * (1.0 - p)), clampf((p - 0.4) / 0.3, 0.0, 1.0))


func _note(at: Vector2, col: Color) -> void:
	draw_circle(at + Vector2(-4, 8), 5.0, col)
	draw_line(at + Vector2(0, 8), at + Vector2(0, -10), col, 3.0)
	draw_line(at + Vector2(0, -10), at + Vector2(8, -6), col, 3.0)


## A cartoon mitten waving up: "I heard it!"
func _draw_hand(c: Vector2, a: float) -> void:
	var col := Color(Palette.SKIN, a)
	var ink := Color(Palette.INK, a)
	draw_circle(c, 13.0, ink)
	draw_circle(c, 10.5, col)
	for i in 3:
		var fx := c + Vector2(-7 + i * 7, -12)
		draw_circle(fx, 5.5, ink)
		draw_circle(fx, 3.6, col)
	draw_circle(c + Vector2(12, 2), 5.0, ink)
	draw_circle(c + Vector2(12, 2), 3.2, col)
	draw_rect(Rect2(c + Vector2(-7, 9), Vector2(14, 10)), ink)
	draw_rect(Rect2(c + Vector2(-5, 9), Vector2(10, 9)), Color(Palette.SKY, a))
