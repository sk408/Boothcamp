extends Control
## FsTray (freestyle, story-internal): the row of big buttons along the bottom of the clinic
## (docs/FREESTYLE.md §1). pick() shows the tool tray: one card per tool, an icon over its name; a
## tool already run wears a tick and can run again. choose() shows plain text buttons for the visit's
## other decisions (which ear first, the ear tip, the tympanogram type, masking, the chart, the call),
## so the chart or a gadget above stays in view. Both are standard `choice` beats (options = the
## button texts, best = the solver's pick): the autoplay bot plays them like any other choice.
##   var tray := FsTray.new(); hud.add_game(tray)
##   var tool: StringName = await tray.pick(tools, done, best, "What next?")
##   var i: int = await tray.choose("Which ear first?", ["Right ear first", "Left ear first"], 0)
## Keys: 1-9, or Left / Right + Enter. Mouse: click a button.

signal _picked(i: int)

const UiKit := preload("res://story/ui_kit.gd")
const FsRules := preload("res://story/freestyle/fs_rules.gd")

const CARD := Vector2(146, 112)
const TEXT_CARD_H := 66.0
const TEXT_CARD_MIN_W := 150.0
const GAP := 12.0
const BOTTOM := 20.0
const SIDE := 16.0   ## the row never comes closer than this to the screen's edges
const ICON_Y := 38.0

var _cards: Array[Button] = []
var _tools: Array[StringName] = []   ## the tray's tools; empty for a choose() row
var _labels: Array[String] = []
var _colors: Dictionary = {}
var _done: Dictionary = {}
var _hl := -1
var _accepting := false
var _armed := 0.0
var _t := 0.0
var _prompt: PanelContainer
var _prompt_label: Label
var _hints: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override("panel", UiKit.style(Color(Palette.PAPER, 0.96), Palette.INK, 18, 3, 4, 12))
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_prompt)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(h)
	_prompt_label = UiKit.label("", 22, Palette.INK, 700)
	h.add_child(_prompt_label)
	_hints = HBoxContainer.new()
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_hints)


func _process(delta: float) -> void:
	_t += delta
	if _armed > 0.0:
		_armed -= delta
	if visible and _hl >= 0 and _hl < _cards.size():
		_cards[_hl].queue_redraw()


## (coroutine) Show the tray and wait for a tool. tools: in tray order; done: {tool: true};
## best: the solver's pick (what a pro would run next).
func pick(tools: Array[StringName], done: Dictionary, best: StringName, prompt: String) -> StringName:
	_tools = tools.duplicate()
	_done = done.duplicate()
	var labels: Array[String] = []
	for t: StringName in _tools:
		labels.append(String(FsRules.TOOL_LABELS[t]))
	var i: int = await _open(prompt, labels, maxi(0, _tools.find(best)), {})
	return _tools[i]


## (coroutine) A row of text buttons; returns the index picked. colors: {index: Color} for a
## button's face (the call's stamps).
func choose(prompt: String, labels: Array[String], best: int, colors: Dictionary = {}) -> int:
	_tools.clear()
	_done.clear()
	return await _open(prompt, labels, best, colors)


func _open(prompt: String, labels: Array[String], best: int, colors: Dictionary) -> int:
	_labels = labels.duplicate()
	_colors = colors.duplicate()
	_build_cards()
	_prompt_label.text = prompt
	for c in _hints.get_children():
		c.queue_free()
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_row([["1"], "-", [str(_labels.size())], "or", ["Left", "Right"], "+", [Game.key_label(&"advance_dialogue")], "or click"], 15))
	visible = true
	_hl = -1
	_accepting = true
	_armed = 0.2
	_layout()
	for i in _cards.size():
		Juice.bounce_in(_cards[i], 0.3 + 0.04 * i)
	Sfx.play(&"pop", 1.1, -8.0)
	var bi := clampi(best, 0, _labels.size() - 1)
	Events.awaiting_input.emit(&"choice", {"prompt": prompt, "options": _labels.duplicate(), "best": bi}, func() -> void: _choose(bi))
	var picked: int = await _picked
	Events.input_resolved.emit(&"choice")
	visible = false
	return picked


func is_open() -> bool:
	return _accepting


func _choose(i: int) -> void:
	if not _accepting or i < 0 or i >= _cards.size():
		return
	_accepting = false
	Sfx.play(&"click")
	var c := _cards[i]
	c.pivot_offset = c.size * 0.5
	Juice.pop(c, 1.12, 0.2)
	_picked.emit.call_deferred(i)


func _build_cards() -> void:
	for c in _cards:
		c.queue_free()
	_cards.clear()
	var icons := not _tools.is_empty()
	var sizes := _card_sizes(icons)
	for i in _labels.size():
		var t: StringName = _tools[i] if icons else &""
		var size: Vector2 = sizes[i]
		var b := UiKit.button(_labels[i], &"", size)
		# the card's width comes from _card_sizes, never from the theme's text measure
		b.clip_text = true
		b.size = size
		b.add_theme_font_override("font", UiKit.font(700))
		b.add_theme_font_size_override("font_size", 17 if icons else 20)
		var face: Color = _colors.get(i, Color(0, 0, 0, 0))
		for st: String in ["normal", "hover", "pressed", "focus"]:
			var col := _card_color(t, st == "hover")
			if face.a > 0.0:
				col = face.lightened(0.25) if st == "hover" else face
			var sb := UiKit.style(col, Palette.INK, 18, 4, 6 if st != "pressed" else 2, 8)
			sb.content_margin_top = 70 if icons else 8
			sb.content_margin_left = 8 if icons else 34
			sb.content_margin_bottom = 6
			b.add_theme_stylebox_override(st, sb)
		for cs: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(cs, Palette.INK)
		b.set_meta("tool", t)
		var idx := i
		b.pressed.connect(func() -> void: _choose(idx))
		b.mouse_entered.connect(func() -> void:
			if _accepting and _hl != idx:
				_set_hl(idx, false))
		b.draw.connect(_draw_card.bind(b, idx))
		add_child(b)
		_cards.append(b)


## Each card's size: wide enough for its label, and the whole row squeezed to fit the screen.
func _card_sizes(icons: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var total := (_labels.size() - 1) * GAP
	for l: String in _labels:
		var tw := UiKit.font(700).get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 17 if icons else 20).x
		var sz := Vector2(maxf(CARD.x, tw + 30.0), CARD.y) if icons else Vector2(maxf(TEXT_CARD_MIN_W, tw + 64.0), TEXT_CARD_H)
		out.append(sz)
		total += sz.x
	var room := get_viewport_rect().size.x - 2.0 * SIDE
	if total > room:
		var k := (room - (_labels.size() - 1) * GAP) / (total - (_labels.size() - 1) * GAP)
		for i in out.size():
			out[i].x = floorf(out[i].x * k)
	return out


func _card_color(t: StringName, hover: bool) -> Color:
	if hover:
		return Palette.SUNNY if t == &"call" else Color("#fff1b8")
	return Color("#fff1b8") if t == &"call" else Palette.PAPER


func _layout() -> void:
	var vp := get_viewport_rect().size
	var w := (_cards.size() - 1) * GAP
	for c in _cards:
		w += c.size.x
	var x := (vp.x - w) * 0.5
	var h := _cards[0].size.y if not _cards.is_empty() else CARD.y
	var y := vp.y - BOTTOM - h
	var x0 := x
	for c in _cards:
		c.position = Vector2(x, y)
		x += c.size.x + GAP
	_prompt.reset_size()
	_prompt.position = Vector2(maxf(SIDE, x0), y - _prompt.get_combined_minimum_size().y - 12.0)


func _set_hl(i: int, sound: bool = true) -> void:
	_hl = i
	for j in _cards.size():
		_cards[j].queue_redraw()
	if sound:
		Sfx.play(&"blip", 1.3, -12.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or _armed > 0.0 or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var k := (event as InputEventKey).keycode
		if k < KEY_1 or k > KEY_9:
			k = (event as InputEventKey).physical_keycode
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _cards.size():
			_choose(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"freq_up"):
		_set_hl((_hl + 1) % _cards.size())
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"freq_down"):
		_set_hl((_hl - 1 + _cards.size()) % _cards.size() if _hl >= 0 else _cards.size() - 1)
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _hl >= 0:
			_choose(_hl)
		else:
			_set_hl(0)
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawing

func _draw_card(b: Button, i: int) -> void:
	var t: StringName = b.get_meta("tool")
	var c := Vector2(b.size.x * 0.5, ICON_Y)
	if i == _hl:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		UiDraw.rounded_rect(b, Rect2(Vector2(-5, -5), b.size + Vector2(10, 10)), Color(0, 0, 0, 0), 22, 4, Palette.SELECT_ORANGE.lerp(Palette.SUNNY, pulse))
	if t != &"":
		draw_icon(b, t, c, 1.0)
	if UiKit.show_key_hints():
		var kr := Rect2(Vector2(8, 8), Vector2(22, 22)) if t != &"" else Rect2(Vector2(8, b.size.y * 0.5 - 11.0), Vector2(22, 22))
		UiDraw.rounded_rect(b, kr, Palette.PAPER, 6, 2, Palette.INK_SOFT)
		b.draw_string(UiKit.font(600), kr.position + Vector2(6, 17), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
	if bool(_done.get(t, false)):
		var tc := Vector2(b.size.x - 20.0, 20.0)
		b.draw_circle(tc, 13.0, Palette.INK)
		b.draw_circle(tc, 10.5, Palette.MINT)
		UiDraw.check(b, tc, 12.0, Color.WHITE, 3.0)


## A tool's icon centred on c (also used by the debrief card). s scales it.
static func draw_icon(ci: CanvasItem, t: StringName, c: Vector2, s: float) -> void:
	var ink := Palette.INK
	match t:
		&"chat":
			var r := Rect2(c + Vector2(-28, -20) * s, Vector2(56, 34) * s)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-12, 12) * s, c + Vector2(-2, 12) * s, c + Vector2(-16, 24) * s]), ink)
			UiDraw.rounded_rect(ci, r, Color("#dbe9ff"), int(12 * s), 3, ink)
			for k in 3:
				ci.draw_circle(c + Vector2(-12 + 12 * k, -3) * s, 3.4 * s, ink)
		&"otoscopy":
			ci.draw_line(c + Vector2(-20, 22) * s, c + Vector2(-4, 4) * s, ink, 11.0 * s)
			ci.draw_line(c + Vector2(-20, 22) * s, c + Vector2(-4, 4) * s, Color("#7b8794"), 7.0 * s)
			ci.draw_circle(c + Vector2(2, -2) * s, 12.0 * s, ink)
			ci.draw_circle(c + Vector2(2, -2) * s, 9.0 * s, Color("#c8d3dc"))
			var cone := PackedVector2Array([c + Vector2(8, -8) * s, c + Vector2(26, -22) * s, c + Vector2(30, -16) * s, c + Vector2(12, -2) * s])
			ci.draw_colored_polygon(cone, ink)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(28, -24) * s, c + Vector2(40, -30) * s, c + Vector2(42, -12) * s, c + Vector2(32, -14) * s]), Color(Palette.SUNNY, 0.8))
		&"tymp":
			var r := Rect2(c + Vector2(-30, -20) * s, Vector2(60, 40) * s)
			UiDraw.rounded_rect(ci, r, Color("#1d2b33"), int(8 * s), 3, ink)
			var pts := PackedVector2Array()
			for k in 21:
				var x := -24.0 + 48.0 * k / 20.0
				var y := 12.0 - 22.0 * exp(-pow(x / 7.0, 2.0))
				pts.append(c + Vector2(x, y) * s)
			ci.draw_polyline(pts, Color("#d7f5ee"), 2.5 * s, true)
		&"air":
			ci.draw_arc(c + Vector2(0, 4) * s, 24.0 * s, PI, TAU, 18, ink, 6.0 * s, true)
			for side: int in [-1, 1]:
				var cup := Rect2(c + Vector2(side * 24 - 8, 0) * s, Vector2(16, 24) * s)
				UiDraw.rounded_rect(ci, cup, Palette.RIGHT_RED if side < 0 else Palette.LEFT_BLUE, int(6 * s), 3, ink)
		&"bone":
			ci.draw_arc(c + Vector2(0, 6) * s, 24.0 * s, PI * 1.05, TAU * 0.98, 18, ink, 5.0 * s, true)
			var osc := Rect2(c + Vector2(14, -2) * s, Vector2(18, 20) * s)
			UiDraw.rounded_rect(ci, osc, Color("#b8c4cc"), int(5 * s), 3, ink)
			for k in 3:
				ci.draw_arc(c + Vector2(34, 8) * s, (6.0 + 5.0 * k) * s, -0.6, 0.6, 6, Color(ink, 0.7 - 0.2 * k), 2.0 * s)
			ci.draw_circle(c + Vector2(-24, 10) * s, 6.0 * s, Palette.SKIN)
		&"masking":
			var pts2 := PackedVector2Array()
			for k in 25:
				var x := -28.0 + 56.0 * k / 24.0
				pts2.append(c + Vector2(x, sin(k * 2.1) * 9.0 + sin(k * 5.3) * 5.0) * s)
			ci.draw_polyline(pts2, Palette.PLUM, 3.5 * s, true)
			ci.draw_string(UiKit.font(700), c + Vector2(-22, -14) * s, "shhh", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * s), ink)
		&"speech":
			ci.draw_circle(c + Vector2(0, -6) * s, 12.0 * s, ink)
			ci.draw_circle(c + Vector2(0, -6) * s, 9.0 * s, Color("#c8d3dc"))
			ci.draw_line(c + Vector2(0, 6) * s, c + Vector2(0, 20) * s, ink, 4.0 * s)
			ci.draw_line(c + Vector2(-10, 20) * s, c + Vector2(10, 20) * s, ink, 4.0 * s)
		&"call":
			ci.draw_circle(c + Vector2(0, -16) * s, 9.0 * s, ink)
			ci.draw_circle(c + Vector2(0, -16) * s, 6.5 * s, Palette.CORAL)
			ci.draw_rect(Rect2(c + Vector2(-4, -8) * s, Vector2(8, 12) * s), ink)
			var base := Rect2(c + Vector2(-24, 4) * s, Vector2(48, 14) * s)
			UiDraw.rounded_rect(ci, base, Palette.CORAL, int(4 * s), 3, ink)
			ci.draw_rect(Rect2(c + Vector2(-26, 20) * s, Vector2(52, 4) * s), Color(Palette.RIGHT_RED, 0.7))
