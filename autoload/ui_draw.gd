class_name UiDraw
extends RefCounted
## UiDraw: procedural icons for CanvasItem._draw(). Fredoka has no arrow, heart, star or
## check glyphs, so draw them. All functions are static; pass the CanvasItem that is drawing.


## Filled arrow pointing along dir (any length). size = overall length in px.
static func arrow(ci: CanvasItem, center: Vector2, size: float, dir: Vector2, color: Color) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var tip := center + d * size * 0.5
	var base := center - d * size * 0.5
	var head_base := center + d * size * 0.05
	var pts := PackedVector2Array([
		tip,
		head_base + n * size * 0.45,
		head_base + n * size * 0.18,
		base + n * size * 0.18,
		base - n * size * 0.18,
		head_base - n * size * 0.18,
		head_base - n * size * 0.45,
	])
	ci.draw_colored_polygon(pts, color)


static func triangle(ci: CanvasItem, center: Vector2, size: float, up: bool, color: Color) -> void:
	var s := 1.0 if up else -1.0
	var pts := PackedVector2Array([
		center + Vector2(0, -0.5 * size * s),
		center + Vector2(0.55 * size, 0.4 * size * s),
		center + Vector2(-0.55 * size, 0.4 * size * s),
	])
	ci.draw_colored_polygon(pts, color)


static func heart(ci: CanvasItem, center: Vector2, size: float, color: Color) -> void:
	var r := size * 0.27
	ci.draw_circle(center + Vector2(-r, -r * 0.4), r, color)
	ci.draw_circle(center + Vector2(r, -r * 0.4), r, color)
	var pts := PackedVector2Array([
		center + Vector2(-2.0 * r, -r * 0.15),
		center + Vector2(2.0 * r, -r * 0.15),
		center + Vector2(0, size * 0.5),
	])
	ci.draw_colored_polygon(pts, color)


static func star(ci: CanvasItem, center: Vector2, radius: float, color: Color, points: int = 5) -> void:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := -PI / 2.0 + i * PI / points
		var r := radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(pts, color)


static func check(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 4.0) -> void:
	var pts := PackedVector2Array([
		center + Vector2(-0.45, 0.0) * size,
		center + Vector2(-0.12, 0.32) * size,
		center + Vector2(0.48, -0.36) * size,
	])
	ci.draw_polyline(pts, color, width, true)


static func cross(ci: CanvasItem, center: Vector2, size: float, color: Color, width: float = 3.0) -> void:
	var h := size * 0.5
	ci.draw_line(center + Vector2(-h, -h), center + Vector2(h, h), color, width, true)
	ci.draw_line(center + Vector2(-h, h), center + Vector2(h, -h), color, width, true)


## ASHA air-conduction symbol: right = O (red), left = X (blue). no_response adds the
## down-and-outward arrow (right: down-left, left: down-right).
static func ear_symbol(ci: CanvasItem, center: Vector2, ear: String, size: float, width: float = 3.0, no_response: bool = false, color_override: Color = Color(0, 0, 0, 0)) -> void:
	var color := Palette.ear_color(ear) if color_override.a == 0.0 else color_override
	if ear == "left":
		cross(ci, center, size * 0.9, color, width)
	else:
		ci.draw_arc(center, size * 0.5, 0.0, TAU, 28, color, width, true)
	if no_response:
		var dir := Vector2(-1, 1) if ear == "right" else Vector2(1, 1)
		var start := center + dir.normalized() * size * 0.55
		var end := start + dir.normalized() * size * 0.9
		ci.draw_line(start, end, color, width, true)
		var n := Vector2(-dir.y, dir.x).normalized()
		var back := end - dir.normalized() * size * 0.35
		ci.draw_colored_polygon(PackedVector2Array([end, back + n * size * 0.22, back - n * size * 0.22]), color)


## Rounded rectangle helper using a StyleBoxFlat (cached per call site is fine for UI).
static func rounded_rect(ci: CanvasItem, rect: Rect2, color: Color, radius: int = 12, border: int = 0, border_color: Color = Palette.INK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)
