extends SceneTree
## Generates the procedural project assets. Re-run after changing any of them:
##   godot --headless --path . --import            (first, so class names are known)
##   godot --headless --path . -s res://tools/build_assets.gd [-- --only=icon,theme,buses,gus]
## Writes: res://icon.png, res://default_bus_layout.tres, res://assets/theme/main_theme.tres,
##         res://core/patients/gus.tres (core-owned data after the first run).

const OUT_ICON := "res://icon.png"
const OUT_BUSES := "res://default_bus_layout.tres"
const OUT_THEME := "res://assets/theme/main_theme.tres"
const OUT_GUS := "res://core/patients/gus.tres"

var _only: PackedStringArray = []


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",")
	var ok := true
	if _want("icon"):
		ok = _icon() and ok
	if _want("buses"):
		ok = _buses() and ok
	if _want("theme"):
		ok = _theme() and ok
	if _want("gus"):
		ok = _gus() and ok
	print("build_assets: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _want(n: String) -> bool:
	return _only.is_empty() or _only.has(n)


# ---------------------------------------------------------------- icon (original owl in headphones)

func _icon() -> bool:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var ink := Color("#2e2442")
	for y in s:
		for x in s:
			var p := Vector2(x + 0.5, y + 0.5)
			var col := Color(0, 0, 0, 0)
			# rounded-square background, warm gradient
			var d_bg := _sd_round_rect(p, Vector2(128, 128), Vector2(124, 124), 58)
			col = _over(col, Color("#ffd23f").lerp(Color("#ff9f1c"), y / 256.0), _cov(d_bg))
			# headphone band (ring, upper part only)
			var dr := absf(p.distance_to(Vector2(128, 146)) - 104.0) - 8.0
			if p.y < 150:
				col = _over(col, ink, _cov(dr))
			# owl body
			var d_body := p.distance_to(Vector2(128, 150)) - 88.0
			col = _over(col, ink, _cov(d_body - 7.0))
			col = _over(col, Color("#c98b4f"), _cov(d_body))
			# heart-shaped face disk
			var d_face := minf(p.distance_to(Vector2(102, 140)) - 44.0, p.distance_to(Vector2(154, 140)) - 44.0)
			d_face = minf(d_face, _sd_tri(p, Vector2(62, 150), Vector2(194, 150), Vector2(128, 214)))
			col = _over(col, Color("#fff1de"), _cov(d_face))
			# eyes + glints
			for ex: float in [102.0, 154.0]:
				col = _over(col, ink, _cov(p.distance_to(Vector2(ex, 138)) - 21.0))
				col = _over(col, Color.WHITE, _cov(p.distance_to(Vector2(ex + 7, 130)) - 6.5))
			# beak
			col = _over(col, Color("#ff9f1c"), _cov(_sd_tri(p, Vector2(116, 164), Vector2(140, 164), Vector2(128, 190))))
			# earphone cups: owl's RIGHT ear (viewer's left) red, left blue
			for cup: Array in [[Vector2(30, 150), Color("#e5383b")], [Vector2(226, 150), Color("#2d6cdf")]]:
				var dc := _sd_round_rect(p, cup[0], Vector2(22, 38), 16)
				col = _over(col, ink, _cov(dc - 6.0))
				col = _over(col, cup[1], _cov(dc))
			img.set_pixel(x, y, col)
	var err := img.save_png(OUT_ICON)
	print("icon: ", error_string(err))
	return err == OK


func _cov(d: float) -> float:
	return clampf(0.5 - d, 0.0, 1.0)


func _over(dst: Color, src: Color, a: float) -> Color:
	var sa := src.a * a
	var out_a := sa + dst.a * (1.0 - sa)
	if out_a <= 0.0:
		return Color(0, 0, 0, 0)
	var rgb := (Vector3(src.r, src.g, src.b) * sa + Vector3(dst.r, dst.g, dst.b) * dst.a * (1.0 - sa)) / out_a
	return Color(rgb.x, rgb.y, rgb.z, out_a)


func _sd_round_rect(p: Vector2, c: Vector2, half: Vector2, r: float) -> float:
	var q := (p - c).abs() - half + Vector2(r, r)
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - r


func _sd_tri(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> float:
	# signed distance to a triangle (negative inside)
	var e0 := b - a
	var e1 := c - b
	var e2 := a - c
	var v0 := p - a
	var v1 := p - b
	var v2 := p - c
	var pq0 := v0 - e0 * clampf(v0.dot(e0) / e0.dot(e0), 0.0, 1.0)
	var pq1 := v1 - e1 * clampf(v1.dot(e1) / e1.dot(e1), 0.0, 1.0)
	var pq2 := v2 - e2 * clampf(v2.dot(e2) / e2.dot(e2), 0.0, 1.0)
	var sgn := signf(e0.x * e2.y - e0.y * e2.x)
	var d := Vector2(pq0.dot(pq0), sgn * (v0.x * e0.y - v0.y * e0.x))
	d = d.min(Vector2(pq1.dot(pq1), sgn * (v1.x * e1.y - v1.y * e1.x)))
	d = d.min(Vector2(pq2.dot(pq2), sgn * (v2.x * e2.y - v2.y * e2.x)))
	return -sqrt(d.x) * signf(d.y)


# ---------------------------------------------------------------- audio buses (safety limiters)

func _buses() -> bool:
	while AudioServer.bus_count > 1:
		AudioServer.remove_bus(1)
	for i in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
		AudioServer.remove_bus_effect(0, i)
	var master_lim := AudioEffectHardLimiter.new()
	master_lim.ceiling_db = AudioSafety.MASTER_BUS_CEILING_DB
	AudioServer.add_bus_effect(0, master_lim)
	for bus: StringName in [AudioSafety.TONES_BUS, AudioSafety.SFX_BUS, AudioSafety.MUSIC_BUS, AudioSafety.VOICE_BUS]:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus)
		AudioServer.set_bus_send(idx, &"Master")
	var tones_lim := AudioEffectHardLimiter.new()
	tones_lim.ceiling_db = AudioSafety.TONES_BUS_CEILING_DB
	AudioServer.add_bus_effect(AudioServer.get_bus_index(AudioSafety.TONES_BUS), tones_lim)
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), OUT_BUSES)
	print("buses: ", error_string(err))
	return err == OK


# ---------------------------------------------------------------- theme (chunky rounded)

func _sb(bg: Color, radius: int = 16, border: int = 3, border_color: Color = Palette.INK, bottom: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	if bottom >= 0:
		sb.border_width_bottom = bottom
	sb.border_color = border_color
	sb.anti_aliasing = true
	return sb


func _margins(sb: StyleBox, l: float, t: float, r: float, b: float) -> StyleBox:
	sb.content_margin_left = l
	sb.content_margin_top = t
	sb.content_margin_right = r
	sb.content_margin_bottom = b
	return sb


func _button_styles(th: Theme, type: StringName, bg: Color, font: Color) -> void:
	th.set_stylebox("normal", type, _margins(_sb(bg, 16, 3, Palette.INK, 7), 20, 8, 20, 10))
	th.set_stylebox("hover", type, _margins(_sb(bg.lightened(0.18), 16, 3, Palette.INK, 7), 20, 8, 20, 10))
	th.set_stylebox("pressed", type, _margins(_sb(bg.darkened(0.12), 16, 3, Palette.INK, 3), 20, 12, 20, 6))
	th.set_stylebox("hover_pressed", type, _margins(_sb(bg.darkened(0.06), 16, 3, Palette.INK, 3), 20, 12, 20, 6))
	th.set_stylebox("disabled", type, _margins(_sb(Color("#e6dccb"), 16, 3, Palette.INK_SOFT, 7), 20, 8, 20, 10))
	th.set_stylebox("focus", type, StyleBoxEmpty.new())
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		th.set_color(item, type, font)
	th.set_color("font_disabled_color", type, Palette.INK_SOFT)


func _theme() -> bool:
	var f400: FontFile = load("res://assets/fonts/fredoka-400.woff2")
	var f500: FontFile = load("res://assets/fonts/fredoka-500.woff2")
	var f600: FontFile = load("res://assets/fonts/fredoka-600.woff2")
	var f700: FontFile = load("res://assets/fonts/fredoka-700.woff2")
	assert(f400 and f500 and f600 and f700)
	var th := Theme.new()
	th.default_font = f500
	th.default_font_size = 20

	_button_styles(th, &"Button", Palette.SUNNY, Palette.INK)
	th.set_font_size("font_size", &"Button", 22)
	th.set_font("font", &"Button", f600)
	th.set_type_variation(&"AccentButton", &"Button")
	_button_styles(th, &"AccentButton", Palette.CORAL, Palette.PAPER)
	th.set_type_variation(&"GhostButton", &"Button")
	th.set_stylebox("normal", &"GhostButton", _margins(_sb(Color(Palette.PAPER, 0.7), 16, 3, Palette.INK_SOFT, 3), 16, 6, 16, 6))
	th.set_stylebox("hover", &"GhostButton", _margins(_sb(Palette.PAPER, 16, 3, Palette.INK, 3), 16, 6, 16, 6))
	th.set_stylebox("pressed", &"GhostButton", _margins(_sb(Palette.CREAM, 16, 3, Palette.INK, 3), 16, 6, 16, 6))

	var panel := _margins(_sb(Palette.PAPER, 22, 4, Palette.INK), 18, 14, 18, 14) as StyleBoxFlat
	panel.shadow_color = Palette.SHADOW
	panel.shadow_size = 6
	panel.shadow_offset = Vector2(0, 5)
	th.set_stylebox("panel", &"PanelContainer", panel)
	th.set_stylebox("panel", &"Panel", panel)
	th.set_stylebox("panel", &"TooltipPanel", _margins(_sb(Palette.PAPER, 12, 3, Palette.INK), 10, 6, 10, 6))
	th.set_color("font_color", &"TooltipLabel", Palette.INK)
	th.set_stylebox("panel", &"PopupPanel", panel)

	th.set_color("font_color", &"Label", Palette.INK)
	th.set_color("font_outline_color", &"Label", Palette.PAPER)
	th.set_type_variation(&"TitleLabel", &"Label")
	th.set_font("font", &"TitleLabel", f700)
	th.set_font_size("font_size", &"TitleLabel", 92)
	th.set_color("font_color", &"TitleLabel", Palette.CORAL)
	th.set_color("font_outline_color", &"TitleLabel", Palette.INK)
	th.set_constant("outline_size", &"TitleLabel", 22)
	th.set_color("font_shadow_color", &"TitleLabel", Color(Palette.INK, 0.9))
	th.set_constant("shadow_offset_x", &"TitleLabel", 0)
	th.set_constant("shadow_offset_y", &"TitleLabel", 8)
	th.set_constant("shadow_outline_size", &"TitleLabel", 22)
	th.set_type_variation(&"HeaderLabel", &"Label")
	th.set_font("font", &"HeaderLabel", f600)
	th.set_font_size("font_size", &"HeaderLabel", 34)
	th.set_type_variation(&"CaptionLabel", &"Label")
	th.set_font("font", &"CaptionLabel", f400)
	th.set_font_size("font_size", &"CaptionLabel", 16)
	th.set_color("font_color", &"CaptionLabel", Palette.INK_SOFT)

	th.set_color("default_color", &"RichTextLabel", Palette.INK)
	th.set_font("normal_font", &"RichTextLabel", f500)
	th.set_font("bold_font", &"RichTextLabel", f700)

	for t: StringName in [&"CheckButton", &"CheckBox"]:
		for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			th.set_color(item, t, Palette.INK)
		th.set_stylebox("focus", t, StyleBoxEmpty.new())
	var slider := _margins(_sb(Color(Palette.INK, 0.15), 8, 0), 0, 6, 0, 6)
	th.set_stylebox("slider", &"HSlider", slider)
	th.set_stylebox("grabber_area", &"HSlider", _margins(_sb(Palette.SUNNY, 8, 0), 0, 6, 0, 6))
	th.set_stylebox("grabber_area_highlight", &"HSlider", _margins(_sb(Palette.SELECT_ORANGE, 8, 0), 0, 6, 0, 6))
	th.set_stylebox("background", &"ProgressBar", _sb(Color(Palette.INK, 0.12), 10, 0))
	th.set_stylebox("fill", &"ProgressBar", _sb(Palette.MINT, 10, 0))
	th.set_color("font_color", &"ProgressBar", Palette.INK)
	th.set_stylebox("normal", &"LineEdit", _margins(_sb(Palette.PAPER, 12, 3, Palette.INK), 12, 8, 12, 8))
	th.set_color("font_color", &"LineEdit", Palette.INK)
	var err := ResourceSaver.save(th, OUT_THEME)
	print("theme: ", error_string(err))
	return err == OK


# ---------------------------------------------------------------- Grandpa Gus (core-owned data)

func _gus() -> bool:
	var script: GDScript = load("res://core/patient_profile.gd")
	var p: Resource = script.new()
	p.set("id", "gus")
	p.set("display_name", "Grandpa Gus")
	p.set("age", 78)
	p.set("complaint", "Everyone mumbles now. Especially my wife. Especially when she says \"dishes\".")
	# Age-related sloping high-frequency SNHL, symmetric within 10 dB (teaching values).
	var right: Dictionary[int, int] = {250: 15, 500: 20, 750: 20, 1000: 25, 1500: 30, 2000: 40, 3000: 50, 4000: 55, 6000: 60, 8000: 65}
	var left: Dictionary[int, int] = {250: 15, 500: 20, 750: 25, 1000: 25, 1500: 35, 2000: 45, 3000: 50, 4000: 60, 6000: 65, 8000: 65}
	p.set("thresholds_right", right)
	p.set("thresholds_left", left)
	p.set("false_alarms_per_minute", 0.3)
	p.set("reaction_time_min_s", 0.8)
	p.set("reaction_time_max_s", 1.6)
	p.set("psychometric_slope_db", 2.0)
	p.set("attention", 0.95)
	p.set("fatigue_per_tone", 0.002)
	p.set("min_tone_s", 0.6)
	p.set("rhythm_sensitivity", 0.4)
	p.set("tinnitus_hz", 0)
	p.set("tags", PackedStringArray(["presbycusis", "tutorial", "chapter_0"]))
	var err := ResourceSaver.save(p, OUT_GUS)
	print("gus: ", error_string(err))
	return err == OK
