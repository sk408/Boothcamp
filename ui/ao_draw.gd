class_name AoDraw
extends RefCounted
## AoDraw: drawing helpers for the AudiOtron 3000 widgets (ui/ only). Cached StyleBoxFlats,
## chunky panels with ink outlines and soft drop shadows, centred and outlined text.

const FONT_BOLD: FontFile = preload("res://assets/fonts/fredoka-700.woff2")
const FONT_SEMI: FontFile = preload("res://assets/fonts/fredoka-600.woff2")
const FONT_MED: FontFile = preload("res://assets/fonts/fredoka-500.woff2")
const FONT_REG: FontFile = preload("res://assets/fonts/fredoka-400.woff2")
const OUTLINE := 4

static var _boxes: Dictionary = {}


## A cached rounded box. border_color alpha 0 = no border.
static func box(fill: Color, radius: int, border: int = 0, border_color: Color = Palette.INK, shadow: int = 0, shadow_offset: Vector2 = Vector2.ZERO) -> StyleBoxFlat:
	var key := "%s|%d|%d|%s|%d|%s" % [fill.to_html(), radius, border, border_color.to_html(), shadow, str(shadow_offset)]
	if _boxes.has(key):
		return _boxes[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	if shadow > 0:
		sb.shadow_color = Palette.SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = shadow_offset
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.2
	if _boxes.size() > 600:
		_boxes.clear()
	_boxes[key] = sb
	return sb


## A sticker-like card: fill, thick ink outline and a hard drop shadow below.
static func card(ci: CanvasItem, rect: Rect2, fill: Color, radius: int = 18, border: int = OUTLINE, drop: float = 6.0) -> void:
	if drop > 0.0:
		ci.draw_style_box(box(Color(Palette.INK, 0.22), radius), Rect2(rect.position + Vector2(0, drop), rect.size))
	ci.draw_style_box(box(fill, radius, border, Palette.INK), rect)


static func rbox(ci: CanvasItem, rect: Rect2, fill: Color, radius: int = 12, border: int = 0, border_color: Color = Palette.INK) -> void:
	ci.draw_style_box(box(fill, radius, border, border_color), rect)


## Rounded outline only.
static func ring(ci: CanvasItem, rect: Rect2, color: Color, radius: int, width: int) -> void:
	ci.draw_style_box(box(Color(color, 0.0), radius, width, color), rect)


static func text_size(text: String, size: int, font: Font = FONT_SEMI) -> Vector2:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


## Text centred on a point (baseline computed from the font's ascent/descent).
static func text_c(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color, font: Font = FONT_SEMI, outline: int = 0, outline_color: Color = Palette.INK) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var pos := Vector2(center.x - w * 0.5, center.y + (asc - desc) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Text with its left edge at x and vertically centred on y.
static func text_l(ci: CanvasItem, left_mid: Vector2, text: String, size: int, color: Color, font: Font = FONT_SEMI, outline: int = 0, outline_color: Color = Palette.INK) -> float:
	var asc := font.get_ascent(size)
	var desc := font.get_descent(size)
	var pos := Vector2(left_mid.x, left_mid.y + (asc - desc) * 0.5)
	if outline > 0:
		ci.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	ci.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## Text with its right edge at x and vertically centred on y.
static func text_r(ci: CanvasItem, right_mid: Vector2, text: String, size: int, color: Color, font: Font = FONT_SEMI) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	text_l(ci, Vector2(right_mid.x - w, right_mid.y), text, size, color, font)


## A cartoon flame (combo meter). level 0..1 scales it; t animates the flicker.
static func flame(ci: CanvasItem, base: Vector2, height: float, t: float, heat: float = 0.0) -> void:
	if height <= 1.0:
		return
	var layers := [[1.0, Palette.CORAL.lerp(Palette.PLUM, heat * 0.4)], [0.72, Palette.SELECT_ORANGE], [0.45, Palette.SUNNY], [0.22, Palette.PAPER]]
	for i in layers.size():
		var k: float = layers[i][0]
		var col: Color = layers[i][1]
		var h := height * k
		var w := height * 0.55 * k
		var sway := sin(t * 9.0 + i * 1.3) * w * 0.18
		var pts := PackedVector2Array()
		var steps := 14
		for s in steps + 1:
			var a := PI * float(s) / steps  # 0..PI, around the bottom
			pts.append(base + Vector2(-cos(a) * w * 0.5, -sin(a) * -w * 0.42 - w * 0.05))
		pts.append(base + Vector2(w * 0.42 + sway * 0.3, -h * 0.45))
		pts.append(base + Vector2(w * 0.12 + sway, -h * 0.75))
		pts.append(base + Vector2(sway * 1.4, -h))
		pts.append(base + Vector2(-w * 0.2 + sway * 0.8, -h * 0.68))
		pts.append(base + Vector2(-w * 0.45 + sway * 0.2, -h * 0.4))
		ci.draw_colored_polygon(pts, col)


## A small ink splat (deterministic per seed) around a centre.
static func splat(ci: CanvasItem, center: Vector2, radius: float, color: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	ci.draw_circle(center, radius * 0.55, color)
	for i in 7:
		var a := rng.randf() * TAU
		var d := radius * rng.randf_range(0.6, 1.25)
		ci.draw_circle(center + Vector2(cos(a), sin(a)) * d, radius * rng.randf_range(0.08, 0.2), color)


## Dashed horizontal or vertical line.
static func dashed(ci: CanvasItem, a: Vector2, b: Vector2, color: Color, width: float = 2.0, dash: float = 6.0, gap: float = 5.0) -> void:
	var length := a.distance_to(b)
	if length <= 0.0:
		return
	var dir := (b - a) / length
	var d := 0.0
	while d < length:
		var e := minf(d + dash, length)
		ci.draw_line(a + dir * d, a + dir * e, color, width, true)
		d = e + gap
