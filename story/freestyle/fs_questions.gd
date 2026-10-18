extends Control
## FsQuestions (freestyle, story-internal): the case-history question board (docs/FREESTYLE.md §4.1).
## The ten deck questions in two columns, plus "Done asking". Questions already asked are ticked
## and greyed. ask() is a standard `choice` beat (options = the button texts, deck order, then Done).
##   var board := FsQuestions.new(); hud.add_game(board)
##   var qid: String = await board.ask(asked, left, best_id, "Penny")   # "" = done asking
## Keys: 1-9 and 0 (question 10), arrows + Enter. Mouse: click.

signal _picked(i: int)

const UiKit := preload("res://story/ui_kit.gd")
const FsRules := preload("res://story/freestyle/fs_rules.gd")

const BTN := Vector2(500, 48)
const COLS := 2

var _panel: PanelContainer
var _title: Label
var _left_label: Label
var _grid: GridContainer
var _buttons: Array[Button] = []
var _asked: Array = []
var _hl := -1
var _accepting := false
var _armed := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.offset_top = 70
	cc.offset_bottom = -40
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	_panel = UiKit.panel(Color(Palette.PAPER, 0.98), Palette.INK, 24)
	cc.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	_title = UiKit.label("", 26, Palette.INK, 700)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_left_label = UiKit.label("", 20, Palette.CORAL.darkened(0.2), 700)
	head.add_child(_left_label)
	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 8)
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_grid)
	for i in FsRules.QUESTIONS.size():
		_buttons.append(_make_button(i, String(FsRules.QUESTIONS[i]["text"])))
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_theme_constant_override("separation", 12)
	v.add_child(foot)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["1"], "-", ["0"], "or arrows +", [Game.key_label(&"advance_dialogue")], "or click"], 15)
		hr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(hr)
	else:
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		foot.add_child(sp)
	var done := _make_button(FsRules.QUESTIONS.size(), FsRules.DONE_ASKING, false)
	done.custom_minimum_size = Vector2(220, 46)
	foot.add_child(done)
	_buttons.append(done)


func _process(delta: float) -> void:
	if _armed > 0.0:
		_armed -= delta


## (coroutine) Show the board; returns the question id picked, or "" for Done asking.
## asked: ids already asked (ticked); left: questions left this visit; best_id: the solver's pick
## ("" = done); who: the patient's short name.
func ask(asked: Array, left: int, best_id: String, who: String) -> String:
	_asked = asked.duplicate()
	_title.text = "Ask %s:" % who
	_left_label.text = "%d question%s left" % [left, "" if left == 1 else "s"]
	for i in FsRules.QUESTIONS.size():
		var qid := String(FsRules.QUESTIONS[i]["id"])
		var b := _buttons[i]
		b.disabled = _asked.has(qid)
		b.queue_redraw()
	visible = true
	_accepting = true
	_armed = 0.2
	_hl = -1
	_refresh_hl()
	Juice.bounce_in(_panel, 0.35)
	Sfx.play(&"pop", 1.2, -8.0)
	var options: Array[String] = []
	for b: Button in _buttons:
		options.append(String(b.get_meta("text")))
	var best := FsRules.QUESTIONS.size()
	for i in FsRules.QUESTIONS.size():
		if String(FsRules.QUESTIONS[i]["id"]) == best_id:
			best = i
	Events.awaiting_input.emit(&"choice", {"prompt": _title.text, "options": options, "best": best}, func() -> void: _choose(best))
	var i2: int = await _picked
	Events.input_resolved.emit(&"choice")
	visible = false
	return String(FsRules.QUESTIONS[i2]["id"]) if i2 < FsRules.QUESTIONS.size() else ""


func _make_button(i: int, text: String, in_grid: bool = true) -> Button:
	var b := UiKit.button(text, &"", BTN)
	b.set_meta("text", text)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 19)
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var col := Palette.PAPER
		if st == "hover":
			col = Color("#fff1b8")
		elif st == "disabled":
			col = Color("#ece6da")
		var sb := UiKit.style(col, Palette.INK if st != "disabled" else Color(Palette.INK, 0.35), 14, 3, 3 if st != "disabled" else 0, 10)
		sb.content_margin_left = 44
		b.add_theme_stylebox_override(st, sb)
	for cs: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(cs, Palette.INK)
	b.add_theme_color_override("font_disabled_color", Color(Palette.INK, 0.4))
	b.pressed.connect(func() -> void: _choose(i))
	b.mouse_entered.connect(func() -> void:
		if _accepting and not b.disabled and _hl != i:
			_hl = i
			_refresh_hl())
	b.draw.connect(func() -> void: _draw_button(b, i))
	if in_grid:
		_grid.add_child(b)
	return b


func _draw_button(b: Button, i: int) -> void:
	var c := Vector2(22, b.size.y * 0.5)
	if b.disabled:
		b.draw_circle(c, 11.0, Palette.MINT)
		UiDraw.check(b, c, 10.0, Color.WHITE, 3.0)
	elif UiKit.show_key_hints():
		var key := "0" if i == 9 else (str(i + 1) if i < 9 else "")
		if key != "":
			UiDraw.rounded_rect(b, Rect2(c - Vector2(11, 11), Vector2(22, 22)), Palette.PAPER, 6, 2, Palette.INK_SOFT)
			b.draw_string(UiKit.font(600), c + Vector2(-5, 6), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
	if i == _hl:
		UiDraw.rounded_rect(b, Rect2(Vector2(-4, -4), b.size + Vector2(8, 8)), Color(0, 0, 0, 0), 16, 4, Palette.SELECT_ORANGE)


func _refresh_hl() -> void:
	for b: Button in _buttons:
		b.queue_redraw()


func _choose(i: int) -> void:
	if not _accepting or i < 0 or i >= _buttons.size() or _buttons[i].disabled:
		return
	_accepting = false
	Sfx.play(&"click")
	_picked.emit.call_deferred(i)


## Next enabled button from i in steps of d (wrapping), for the arrow keys.
func _step(from: int, d: int) -> int:
	var n := _buttons.size()
	var i := from
	for k in n:
		i = (i + d + n) % n
		if not _buttons[i].disabled:
			return i
	return from


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or _armed > 0.0 or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var k := (event as InputEventKey).keycode
		if k < KEY_0 or k > KEY_9:
			k = (event as InputEventKey).physical_keycode
		if k >= KEY_0 and k <= KEY_9:
			var idx := 9 if k == KEY_0 else k - KEY_1
			if idx < FsRules.QUESTIONS.size() and not _buttons[idx].disabled:
				_choose(idx)
				get_viewport().set_input_as_handled()
				return
	var start := _hl if _hl >= 0 else -1
	if event.is_action_pressed(&"ui_down"):
		_hl = _step(start, COLS if start >= 0 and start < FsRules.QUESTIONS.size() - COLS else 1)
	elif event.is_action_pressed(&"ui_up"):
		_hl = _step(maxi(start, 0), -COLS if start >= COLS and start < FsRules.QUESTIONS.size() else -1)
	elif event.is_action_pressed(&"ui_right"):
		_hl = _step(start, 1)
	elif event.is_action_pressed(&"ui_left"):
		_hl = _step(maxi(start, 0), -1)
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _hl >= 0:
			_choose(_hl)
		else:
			_hl = _step(-1, 1)
	else:
		return
	Sfx.play(&"blip", 1.3, -12.0)
	_refresh_hl()
	get_viewport().set_input_as_handled()
