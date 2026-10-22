extends Control
## Small drawn icons (Fredoka has no symbols): topic icons, check, cross, chevron, info.

var kind := "check"
var color := Color("#2e2442")


static func make(icon_kind: String, col: Color, px: float = 28.0) -> Control:
	var c: Control = load("res://scripts/icon.gd").new()
	c.kind = icon_kind
	c.color = col
	c.custom_minimum_size = Vector2(px, px)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	var w := maxf(2.0, s * 0.11)
	match kind:
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-0.32, 0.02) * s, c + Vector2(-0.08, 0.26) * s,
					c + Vector2(0.34, -0.24) * s]), color, w * 1.2, true)
		"cross":
			var h := s * 0.26
			draw_line(c + Vector2(-h, -h), c + Vector2(h, h), color, w, true)
			draw_line(c + Vector2(-h, h), c + Vector2(h, -h), color, w, true)
		"dash":
			draw_line(c + Vector2(-s * 0.25, 0), c + Vector2(s * 0.25, 0), color, w, true)
		"chevron_down":
			draw_polyline(PackedVector2Array([c + Vector2(-0.28, -0.12) * s, c + Vector2(0, 0.16) * s,
					c + Vector2(0.28, -0.12) * s]), color, w, true)
		"chevron_up":
			draw_polyline(PackedVector2Array([c + Vector2(-0.28, 0.12) * s, c + Vector2(0, -0.16) * s,
					c + Vector2(0.28, 0.12) * s]), color, w, true)
		"info":
			draw_arc(c, s * 0.4, 0, TAU, 32, color, w * 0.8, true)
			draw_line(c + Vector2(0, -s * 0.02), c + Vector2(0, s * 0.2), color, w, true)
			draw_circle(c + Vector2(0, -s * 0.18), w * 0.6, color)
		"price":
			draw_circle(c, s * 0.42, color)
			var f: Font = load("res://scripts/ui.gd").font(700)
			var fs := int(s * 0.62)
			var tw := f.get_string_size("$", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
			draw_string(f, c + Vector2(-tw.x * 0.5, fs * 0.36), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#fffbf2"))
		"battery":
			var r := Rect2(c + Vector2(-0.4, -0.22) * s, Vector2(0.72, 0.44) * s)
			_rrect(r, color, false, w * 0.8)
			draw_rect(Rect2(c + Vector2(0.33, -0.1) * s, Vector2(0.08, 0.2) * s), color)
			draw_rect(Rect2(r.position + Vector2(w * 1.3, w * 1.3), Vector2(r.size.x * 0.62, r.size.y - w * 2.6)), color)
		"phone":
			var r2 := Rect2(c + Vector2(-0.22, -0.4) * s, Vector2(0.44, 0.8) * s)
			_rrect(r2, color, false, w * 0.8)
			draw_circle(c + Vector2(0, 0.28) * s, w * 0.55, color)
		"sound":
			draw_circle(c + Vector2(-0.22, 0) * s, s * 0.1, color)
			for i in 3:
				draw_arc(c + Vector2(-0.22, 0) * s, s * (0.22 + 0.14 * i), -0.9, 0.9, 12, color, w * 0.8, true)
		"ear":
			draw_arc(c + Vector2(0.02, -0.08) * s, s * 0.3, PI * 1.0, PI * 2.25, 24, color, w, true)
			draw_line(c + Vector2(0.2, 0.15) * s, c + Vector2(0.0, 0.4) * s, color, w, true)
			draw_arc(c + Vector2(0.04, -0.06) * s, s * 0.12, PI * 1.1, PI * 2.1, 12, color, w * 0.8, true)
		"app":
			for i in 2:
				for j in 2:
					_rrect(Rect2(c + Vector2(-0.36 + 0.4 * i, -0.36 + 0.4 * j) * s, Vector2(0.3, 0.3) * s), color, true, 0)
		"maker":
			draw_rect(Rect2(c + Vector2(-0.38, -0.05) * s, Vector2(0.76, 0.4) * s), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.38, -0.05) * s, c + Vector2(-0.1, -0.3) * s,
					c + Vector2(-0.1, -0.05) * s, c + Vector2(0.18, -0.3) * s, c + Vector2(0.18, -0.05) * s,
					c + Vector2(0.38, -0.38) * s, c + Vector2(0.38, -0.05) * s]), color)
		"close":
			var h2 := s * 0.24
			draw_line(c + Vector2(-h2, -h2), c + Vector2(h2, h2), color, w * 1.1, true)
			draw_line(c + Vector2(-h2, h2), c + Vector2(h2, -h2), color, w * 1.1, true)


func _rrect(r: Rect2, col: Color, filled: bool, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(r.size.y * 0.25))
	sb.anti_aliasing = true
	if filled:
		sb.bg_color = col
	else:
		sb.bg_color = Color.TRANSPARENT
		sb.set_border_width_all(int(maxf(1.0, width)))
		sb.border_color = col
	draw_style_box(sb, r)
