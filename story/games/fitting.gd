extends Control
## Teaser fitting: one big friendly switch. Click it, or press Space / Enter.
## Story-internal:  var f := Fitting.new(); hud.add_game(f); await f.run()
## Beat: fitting_switch_on.

signal _switched

const UiKit := preload("res://story/ui_kit.gd")

var _btn: Control
var _label: Label
var _hints: HBoxContainer
var _accepting := false
var _on := false
var _t := 0.0
var _press := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_top = -250
	box.offset_bottom = -40
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_END
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_label = UiKit.label("Switch on Gus's hearing aids", 28, Palette.PAPER, 700, 12, Palette.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	var holder := CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)
	_btn = Control.new()
	_btn.custom_minimum_size = Vector2(240, 120)
	_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_btn.draw.connect(_draw_switch)
	_btn.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_switch_on()
			_btn.accept_event())
	holder.add_child(_btn)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_hints)
	visible = false


## (coroutine) Show the switch; returns once it is on. Emits awaiting_input(fitting_switch_on).
func run() -> void:
	visible = true
	Juice.bounce_in(_btn, 0.5)
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_panel(["Click the switch or press", ["Space"], ["Enter"]], 17))
	_accepting = true
	Events.awaiting_input.emit(&"fitting_switch_on", {}, _switch_on)
	if not _on:
		await _switched
	_accepting = false


func _switch_on() -> void:
	if _on or not _accepting:
		return
	_on = true
	_press = 1.0
	Sfx.play(&"thunk", 1.2, -4.0)
	_label.text = "Hearing aids: ON"
	Juice.pop(_label, 1.3, 0.3)
	Events.input_resolved.emit(&"fitting_switch_on")
	_switched.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"advance_dialogue") or event.is_action_pressed(&"ui_accept"):
		_switch_on()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_press = maxf(0.0, _press - delta * 3.0)
	if visible:
		_btn.queue_redraw()


func _draw_switch() -> void:
	var s := _btn.size
	var r := Rect2(Vector2(10, 18), Vector2(s.x - 20, s.y - 36))
	var glow := 0.5 + 0.5 * sin(_t * 4.0)
	if not _on:
		UiDraw.rounded_rect(_btn, r.grow(8.0 + 6.0 * glow), Color(Palette.SUNNY, 0.35), 50)
	UiDraw.rounded_rect(_btn, Rect2(r.position + Vector2(0, 7), r.size), Color(Palette.INK, 0.35), 44)
	UiDraw.rounded_rect(_btn, r, Palette.MINT if _on else Color("#b9b3c4"), 44, 5, Palette.INK)
	var knob_x := r.end.x - 42.0 if _on else r.position.x + 42.0
	var knob := Vector2(knob_x, r.get_center().y + 2.0 * _press)
	_btn.draw_circle(knob + Vector2(0, 5), 34.0, Color(Palette.INK, 0.3))
	_btn.draw_circle(knob, 34.0, Palette.INK)
	_btn.draw_circle(knob, 29.0, Palette.PAPER)
	var f := UiKit.font(700)
	var txt := "ON" if _on else "OFF"
	var tx := r.position.x + 22.0 if _on else r.end.x - 70.0
	_btn.draw_string(f, Vector2(tx, r.get_center().y + 11.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.INK)
