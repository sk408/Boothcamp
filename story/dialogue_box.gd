class_name DialogueBox
extends CanvasLayer
## DialogueBox (CanvasLayer 30): speech box with a typewriter, a bobbing portrait, quiet
## gibberish voices, and multiple-choice questions.
##   await box.say("Gus", "Everyone mumbles!")
##   var i: int = await box.choose("Ask Gus:", ["Any ringing?", "Loud noise?"], 0)
## Advance: Space / Enter (action advance_dialogue) or a click anywhere. The first press
## finishes the typing, the next one continues.
## Choices: click, keys 1-9, or Up/Down + Enter/Space.
## Every wait emits Events.awaiting_input ("dialogue" / "choice") with a solver (CONTRACTS.md §3.2).
## Input is only read while the box is waiting, so it never steals keys from the audiometer.

signal _advanced
signal _chosen(index: int)

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const Voice := preload("res://story/voice.gd")

const CHARS_PER_SECOND := 42.0
const DISPLAY_NAMES: Dictionary = {"Gus": "Grandpa Gus", "Hoot": "Professor Hoot", "Doris": "Doris", "You": "You", "Mike": "Mike \"Totally Deaf\" Lenders"}
const PANEL_W := 900.0
const PANEL_H := 156.0

var _root: Control
var _catcher: Control
var _panel: PanelContainer
var _portrait: Control
var _name_tag: PanelContainer
var _name: Label
var _text: Label
var _hints: HBoxContainer
var _more: Control
var _choices: VBoxContainer
var _voice: Node

var _speaker := ""
var _typing := false
var _waiting := false
var _shown := 0.0
var _pause_left := 0.0
var _last_char := 0
var _t := 0.0
var _talk_open := false
var _choice_rows: Array[PanelContainer] = []
var _choice_hl := 0
var _choice_armed := 0.0
var _choosing := false


func _ready() -> void:
	layer = 30
	_voice = Voice.new()
	add_child(_voice)
	_build()
	_hide_all()
	Events.key_style_changed.connect(func(_s: String) -> void: _refresh_hints())
	Events.settings_changed.connect(func(k: String, _v: Variant) -> void:
		if k == "show_key_hints":
			_refresh_hints())


## (coroutine) Show one line and wait for click / advance_dialogue / the bot.
func say(speaker: String, text: String) -> void:
	_choosing = false
	_clear_choices()
	_show_speaker(speaker)
	_text.text = text
	_text.visible_characters = 0
	_shown = 0.0
	_last_char = 0
	_pause_left = 0.0
	_typing = true
	_waiting = true
	_catcher.visible = true
	_more.visible = false
	_refresh_hints()
	_panel.visible = true
	Juice.pop(_panel, 1.03, 0.18)
	Events.dialogue_line.emit(speaker, text)
	Events.awaiting_input.emit(&"dialogue", {"speaker": speaker, "text": text}, _advance_solver)
	await _advanced
	_waiting = false
	_typing = false
	_catcher.visible = false
	_panel.visible = false
	_name_tag.visible = false
	_portrait.visible = false
	Events.input_resolved.emit(&"dialogue")


## (coroutine) Show a prompt with options; returns the chosen index. best = the solver's pick.
func choose(prompt: String, options: Array[String], best: int = 0) -> int:
	_show_speaker("You")
	_text.text = prompt
	_text.visible_characters = -1
	_typing = false
	_waiting = false
	_catcher.visible = false
	_more.visible = false
	_panel.visible = true
	_refresh_hints(options.size())
	_clear_choices()
	for i in options.size():
		var row := _make_choice_row(i, options[i])
		_choices.add_child(row)
		_choice_rows.append(row)
		Juice.bounce_in(row, 0.3 + 0.06 * i)
	_choices.visible = true
	_choice_hl = -1
	_choosing = true
	_choice_armed = 0.18
	Sfx.play(&"pop", 1.2, -8.0)
	Events.awaiting_input.emit(&"choice", {"prompt": prompt, "options": options, "best": best}, func() -> void: _pick(best))
	var picked: int = await _chosen
	_choosing = false
	_choices.visible = false
	_panel.visible = false
	_name_tag.visible = false
	_portrait.visible = false
	_clear_choices()
	Events.input_resolved.emit(&"choice")
	return picked


func is_open() -> bool:
	return _panel.visible


func is_typing() -> bool:
	return _typing


# ---------------------------------------------------------------- internals

func _show_speaker(speaker: String) -> void:
	_speaker = speaker
	var col: Color = Portraits.name_color(speaker)
	_name.text = DISPLAY_NAMES.get(speaker, speaker)
	_name_tag.add_theme_stylebox_override("panel", UiKit.style(col, Palette.INK, 14, 3, 0, 12))
	_name_tag.visible = speaker != ""
	_portrait.visible = true
	Juice.pop(_portrait, 1.12, 0.22)
	Juice.pop(_name_tag, 1.15, 0.2)


func _pick(i: int) -> void:
	if not _choosing or i < 0 or i >= _choice_rows.size():
		return
	_choosing = false
	Sfx.play(&"click")
	var row := _choice_rows[i]
	row.add_theme_stylebox_override("panel", UiKit.style(Palette.SUNNY, Palette.INK, 18, 4, 4, 12))
	Juice.pop(row, 1.08, 0.15)
	await get_tree().create_timer(0.16).timeout
	_chosen.emit(i)


func _advance_solver() -> void:
	if not _waiting:
		return
	_finish_typing()
	_advanced.emit()


func _finish_typing() -> void:
	_text.visible_characters = -1
	_typing = false
	_talk_open = false
	_more.visible = true


func _try_advance() -> void:
	if not _waiting:
		return
	if _typing:
		_finish_typing()
	else:
		Sfx.play(&"click", 1.1, -6.0)
		_advanced.emit()


func _process(delta: float) -> void:
	_t += delta
	if _choice_armed > 0.0:
		_choice_armed -= delta
	if _typing:
		if _pause_left > 0.0:
			_pause_left -= delta
		else:
			var speed := CHARS_PER_SECOND * maxf(0.25, float(Game.settings.get("text_speed", 1.0)))
			_shown += delta * speed
			var n := int(_shown)
			var total := _text.get_total_character_count()
			while _last_char < mini(n, total):
				var ch := _text.text.substr(_last_char, 1)
				_last_char += 1
				if _last_char % 3 == 1 and ch.strip_edges() != "" and ch.unicode_at(0) > 64:
					_voice.call("syllable", _speaker, _last_char / 3)
					_talk_open = not _talk_open
				if ch in [".", "!", "?"]:
					_pause_left = 0.16
					_talk_open = false
					break
				if ch == ",":
					_pause_left = 0.08
					break
			_text.visible_characters = _last_char
			if _last_char >= total:
				_finish_typing()
	if _panel.visible:
		_portrait.queue_redraw()
		_more.position.y = 2.0 * sin(_t * 6.0)


func _unhandled_input(event: InputEvent) -> void:
	if _choosing:
		_choice_input(event)
		return
	if not _waiting:
		return
	if event.is_action_pressed(&"advance_dialogue") and not event.is_echo():
		_try_advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_try_advance()
		get_viewport().set_input_as_handled()


func _choice_input(event: InputEvent) -> void:
	if _choice_armed > 0.0 or not (event is InputEventKey or event is InputEventAction):
		return
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var k := (event as InputEventKey).keycode
		var pk := (event as InputEventKey).physical_keycode
		if k < KEY_1 or k > KEY_9:
			k = pk  # AZERTY and friends: the digit row by position
		if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < _choice_rows.size():
			_pick(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
		if k >= KEY_KP_1 and k <= KEY_KP_9 and k - KEY_KP_1 < _choice_rows.size():
			_pick(k - KEY_KP_1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"freq_up"):
		_set_highlight((_choice_hl + 1) % _choice_rows.size())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"freq_down"):
		_set_highlight((_choice_hl - 1 + _choice_rows.size()) % _choice_rows.size() if _choice_hl >= 0 else _choice_rows.size() - 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"advance_dialogue") or event.is_action_pressed(&"ui_accept"):
		if _choice_hl >= 0:
			_pick(_choice_hl)
		else:
			_set_highlight(0)
		get_viewport().set_input_as_handled()


func _set_highlight(i: int) -> void:
	_choice_hl = i
	for j in _choice_rows.size():
		var on := j == i
		_choice_rows[j].add_theme_stylebox_override("panel", UiKit.style(Color("#fff1b8") if on else Palette.PAPER, Palette.INK, 18, 4 if on else 3, 6 if on else 3, 12))
	if i >= 0:
		Sfx.play(&"blip", 1.4, -12.0)


func _make_choice_row(i: int, text: String) -> PanelContainer:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UiKit.style(Palette.PAPER, Palette.INK, 18, 3, 3, 12))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.custom_minimum_size = Vector2(720, 50)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(h)
	var chip := UiKit.key_chip(str(i + 1), 18)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(chip)
	var l := UiKit.label(text, 22, Palette.INK, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(l)
	row.mouse_entered.connect(func() -> void:
		if _choosing:
			_set_highlight(i))
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_pick(i))
	return row


func _clear_choices() -> void:
	for c in _choices.get_children():
		c.queue_free()
	_choice_rows.clear()


func _hide_all() -> void:
	_portrait.visible = false
	_panel.visible = false
	_name_tag.visible = false
	_choices.visible = false
	_catcher.visible = false


func _refresh_hints(n_options: int = 0) -> void:
	for c in _hints.get_children():
		c.queue_free()
	if n_options > 0:
		var parts: Array = []
		if UiKit.show_key_hints():
			parts = [["1"], "-", [str(n_options)], "or", ["Up", "Down"], "+", [Game.key_label(&"advance_dialogue")], "or click"]
		else:
			parts = ["Click an answer"]
		_hints.add_child(UiKit.hint_row(parts, 15))
	else:
		var keys := Game.key_labels(&"advance_dialogue")
		var shown: Array = []
		for k in keys:
			if shown.size() < 2 and not shown.has(k):
				shown.append(k)
		var parts2: Array = [shown, "or click"] if UiKit.show_key_hints() else ["Click to continue"]
		_hints.add_child(UiKit.hint_row(parts2, 15))


func _build() -> void:
	_root = UiKit.full_rect()
	add_child(_root)
	# invisible click-catcher: a click anywhere advances the line
	_catcher = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	_catcher.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_try_advance())
	_root.add_child(_catcher)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.style(Palette.PAPER, Palette.INK, 26, 5, 10, 18))
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_W * 0.5 + 40.0
	_panel.offset_right = PANEL_W * 0.5 + 40.0
	_panel.offset_top = -PANEL_H - 18.0
	_panel.offset_bottom = -18.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_try_advance())
	_root.add_child(_panel)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 112)
	m.add_theme_constant_override("margin_top", 10)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(m)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	_text = UiKit.label("", 25, Palette.INK, 500)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_constant_override("line_spacing", 2)
	v.add_child(_text)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.alignment = BoxContainer.ALIGNMENT_END
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	_hints = HBoxContainer.new()
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(_hints)
	var more_box := Control.new()
	more_box.custom_minimum_size = Vector2(22, 18)
	more_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(more_box)
	_more = Control.new()
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.size = Vector2(22, 18)
	_more.draw.connect(func() -> void: UiDraw.triangle(_more, Vector2(11, 9), 18.0, false, Palette.CORAL))
	more_box.add_child(_more)

	# portrait sits half outside the panel's left edge
	_portrait = Control.new()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.anchor_left = 0.5
	_portrait.anchor_right = 0.5
	_portrait.anchor_top = 1.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = -PANEL_W * 0.5 + 40.0 - 40.0
	_portrait.offset_right = _portrait.offset_left + 150.0
	_portrait.offset_top = -PANEL_H - 18.0 - 34.0
	_portrait.offset_bottom = _portrait.offset_top + 150.0
	_portrait.draw.connect(_draw_portrait)
	_root.add_child(_portrait)

	_name_tag = PanelContainer.new()
	_name_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_tag.anchor_left = 0.5
	_name_tag.anchor_right = 0.5
	_name_tag.anchor_top = 1.0
	_name_tag.anchor_bottom = 1.0
	_name_tag.offset_left = -PANEL_W * 0.5 + 40.0 + 112.0
	_name_tag.offset_right = _name_tag.offset_left
	_name_tag.offset_top = -PANEL_H - 18.0 - 22.0
	_name_tag.offset_bottom = _name_tag.offset_top
	_name_tag.grow_horizontal = Control.GROW_DIRECTION_END
	_name_tag.grow_vertical = Control.GROW_DIRECTION_END
	_root.add_child(_name_tag)
	_name = UiKit.label("", 21, Color.WHITE, 700, 0)
	_name_tag.add_child(_name)

	_choices = VBoxContainer.new()
	_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -360.0 + 220.0
	_choices.offset_right = 360.0 + 220.0
	_choices.offset_top = -PANEL_H - 50.0
	_choices.offset_bottom = -PANEL_H - 50.0
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.alignment = BoxContainer.ALIGNMENT_END
	_choices.add_theme_constant_override("separation", 10)
	_root.add_child(_choices)


func _draw_portrait() -> void:
	var bob := 0.0
	if _typing:
		bob = -absf(sin(_t * 11.0)) * 4.0
	var blink := fmod(_t + 0.7, 3.4) < 0.12
	Portraits.draw(_portrait, _speaker, Vector2(66, 62 + bob), 58.0, _typing and _talk_open, blink)
