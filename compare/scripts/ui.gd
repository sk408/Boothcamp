extends RefCounted
## The page's UI kit, in the game's look: Fredoka, ink outlines, chunky shadows, bright rounded cards.
## Usage: const Ui := preload("res://scripts/ui.gd")

const CREAM := Color("#fff3dc")      ## page background
const PAPER := Color("#fffbf2")      ## cards
const INK := Color("#2e2442")        ## outlines and text
const INK_SOFT := Color("#6b5e7e")   ## secondary text (5.4:1 on cream)
const SUNNY := Color("#ffd23f")      ## main buttons
const SUNNY_SOFT := Color("#fff0b3")
const MINT := Color("#5bc8a3")
const MINT_SOFT := Color("#d3f4e6")
const CORAL := Color("#ff6f59")
const SKY := Color("#bfe6ff")
const GREY_SOFT := Color("#ece7f0")
const GOOD := Color("#1d7a4f")       ## "yes" text
const WARN := Color("#8a5a00")       ## "some" text

## Text sizes (logical px). Nothing a shopper reads is under SMALL.
const H1 := 34
const H2 := 26
const H3 := 22
const BODY := 18
const SMALL := 16

static var _fonts: Dictionary = {}


static func font(weight: int = 500) -> Font:
	if not _fonts.has(weight):
		var path := "res://assets/fonts/fredoka-%d.woff2" % weight
		_fonts[weight] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[weight]


static func style(bg: Color, border: Color = INK, radius: int = 22, border_w: int = 4, shadow: int = 6,
		margin: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border_w)
	sb.border_color = border
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	if shadow > 0:
		sb.shadow_color = Color(INK, 0.22)
		sb.shadow_size = 0
		sb.shadow_offset = Vector2(0, shadow)
	sb.anti_aliasing = true
	return sb


## A rounded card. PASS lets a finger drag on it scroll the page.
static func card(bg: Color, border: Color = INK, radius: int = 22, margin: int = 16, shadow: int = 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, border, radius, 4 if border.a > 0 else 0, shadow, margin))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	return p


static func label(text: String, size: int = BODY, color: Color = INK, weight: int = 500) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func wrap(text: String, size: int = BODY, color: Color = INK, weight: int = 500) -> Label:
	var l := label(text, size, color, weight)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(40, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A chunky button: kind "main" (sunny), "plain" (paper), "dark" (ink), "chip" (pill toggle).
## wrap = true lets long text wrap; use it only where the button gets a full row.
static func button(text: String, kind: String = "plain", size: int = BODY, min_h: int = 52, wrap: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, min_h)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font(600))
	b.add_theme_font_size_override("font_size", size)
	if wrap:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := PAPER
	var fg := INK
	var radius := 16
	match kind:
		"main":
			bg = SUNNY
		"dark":
			bg = INK
			fg = PAPER
		"chip":
			radius = 26
	var pad := 14 if kind != "chip" else 18
	var normal := style(bg, INK, radius, 3, 4, pad)
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = bg.lightened(0.12) if kind != "dark" else bg.lightened(0.15)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = SUNNY if kind == "chip" else bg.darkened(0.08)
	pressed.shadow_offset = Vector2(0, 1)
	var focus := style(Color.TRANSPARENT, Color("#2d6cdf"), radius + 3, 3, 0, pad)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover_pressed", pressed)
	b.add_theme_stylebox_override("focus", focus)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg if not (kind == "chip" and k.contains("pressed")) else INK)
	return b


## A small rounded tag: text on a coloured pill.
static func pill(text: String, bg: Color, fg: Color = INK, size: int = SMALL, weight: int = 600) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := style(bg, Color.TRANSPARENT, 14, 0, 0, 10)
	sb.content_margin_top = 3
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, size, fg, weight))
	return p


static func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	return v


static func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


static func flow(sep: int = 10) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", sep)
	f.mouse_filter = Control.MOUSE_FILTER_PASS
	return f


## Text colour that reads on bg (ink on light colours, paper on dark ones).
static func on(bg: Color) -> Color:
	return INK if bg.get_luminance() > 0.5 else PAPER
