extends RefCounted
## Story UI kit: chunky rounded styles, labels and key chips shared by the story screens.
## Usage: const UiKit := preload("res://story/ui_kit.gd")

static var _fonts: Dictionary = {}


static func font(weight: int = 600) -> Font:
	if not _fonts.has(weight):
		var path := "res://assets/fonts/fredoka-%d.woff2" % weight
		_fonts[weight] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[weight]


static func style(bg: Color, border: Color = Palette.INK, radius: int = 22, border_w: int = 4, shadow: int = 8, margin: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.75
	sb.content_margin_bottom = margin * 0.75
	if shadow > 0:
		sb.shadow_color = Color(Palette.INK, 0.25)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.6)
	sb.anti_aliasing = true
	return sb


static func panel(bg: Color = Palette.PAPER, border: Color = Palette.INK, radius: int = 22) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border, radius))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	return p


static func label(text: String, size: int = 22, color: Color = Palette.INK, weight: int = 600, outline: int = 0, outline_color: Color = Palette.PAPER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, variation: StringName = &"", min_size: Vector2 = Vector2(0, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## A small rounded "key chip" such as [Space] or [1].
static func key_chip(text: String, size: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(Palette.PAPER, Palette.INK_SOFT, 8, 2, 0, 6)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	sb.border_width_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, size, Palette.INK, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


## "Key hint" row: chips and words, e.g. [["Space", "Enter"], "or click to continue"].
static func hint_row(parts: Array, size: int = 16, color: Color = Palette.INK_SOFT) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p: Variant in parts:
		if p is Array:
			for k: String in p:
				h.add_child(key_chip(k, size - 2))
		else:
			h.add_child(label(String(p), size, color, 500))
	return h


static func show_key_hints() -> bool:
	return bool(Game.settings.get("show_key_hints", true))


## Full-rect Control that ignores the mouse (a layout root).
static func full_rect(mouse: Control.MouseFilter = Control.MOUSE_FILTER_IGNORE) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = mouse
	return c


## A hint row on a soft paper pill, readable over any 3D background.
static func hint_panel(parts: Array, size: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(Color(Palette.PAPER, 0.92), Color(Palette.INK, 0.6), 16, 2, 0, 10)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.add_child(hint_row(parts, size, Palette.INK))
	return p
