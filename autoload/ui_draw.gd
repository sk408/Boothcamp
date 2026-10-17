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


## (v3) Any ASHA audiogram symbol. test: &"ac" O / X, &"ac_masked" triangle / square,
## &"bc" < / >, &"bc_masked" [ / ] (right / left). no_response adds the down-and-outward arrow.
## Bone symbols are drawn beside the frequency line: add symbol_offset() to the centre first.
static func audiogram_symbol(ci: CanvasItem, center: Vector2, ear: String, test: StringName, size: float, width: float = 3.0, no_response: bool = false, color_override: Color = Color(0, 0, 0, 0)) -> void:
	if test == &"ac" or test == &"":
		ear_symbol(ci, center, ear, size, width, no_response, color_override)
		return
	var color := Palette.ear_color(ear) if color_override.a == 0.0 else color_override
	var h := size * 0.5
	var right := ear != "left"
	match test:
		&"ac_masked":
			if right:
				ci.draw_polyline(PackedVector2Array([center + Vector2(0, -h), center + Vector2(h * 0.95, h * 0.75), center + Vector2(-h * 0.95, h * 0.75), center + Vector2(0, -h)]), color, width, true)
			else:
				ci.draw_polyline(PackedVector2Array([center + Vector2(-h * 0.8, -h * 0.8), center + Vector2(h * 0.8, -h * 0.8), center + Vector2(h * 0.8, h * 0.8), center + Vector2(-h * 0.8, h * 0.8), center + Vector2(-h * 0.8, -h * 0.8)]), color, width, true)
		&"bc":
			var s := -1.0 if right else 1.0   # "<" points left (right ear), ">" points right (left ear)
			ci.draw_polyline(PackedVector2Array([center + Vector2(-s * h * 0.45, -h), center + Vector2(s * h * 0.55, 0), center + Vector2(-s * h * 0.45, h)]), color, width, true)
		&"bc_masked":
			var s2 := 1.0 if right else -1.0  # "[" opens to the right (right ear), "]" to the left
			ci.draw_polyline(PackedVector2Array([center + Vector2(s2 * h * 0.45, -h), center + Vector2(-s2 * h * 0.35, -h), center + Vector2(-s2 * h * 0.35, h), center + Vector2(s2 * h * 0.45, h)]), color, width, true)
	if no_response:
		var dir := Vector2(-1, 1) if right else Vector2(1, 1)
		var start := center + dir.normalized() * size * 0.55
		var end := start + dir.normalized() * size * 0.9
		ci.draw_line(start, end, color, width, true)
		var n := Vector2(-dir.y, dir.x).normalized()
		var back := end - dir.normalized() * size * 0.35
		ci.draw_colored_polygon(PackedVector2Array([end, back + n * size * 0.22, back - n * size * 0.22]), color)


## (v3) Where a symbol sits relative to its frequency line: bone symbols beside it (right ear to
## the left, left ear to the right), air symbols on it.
static func symbol_offset(ear: String, test: StringName, size: float) -> Vector2:
	if ClinicRules.test_is_bone(test):
		return Vector2(-0.62 * size if ear != "left" else 0.62 * size, 0.0)
	return Vector2.ZERO
