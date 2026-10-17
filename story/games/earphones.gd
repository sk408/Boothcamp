extends Control
## Earphones micro-game: put the RED cup on Gus's RIGHT ear and the BLUE cup on his LEFT.
## Gus faces us, so his right ear is on the screen's LEFT (the classic mix-up).
## Mouse: drag a cup onto an ear, or click a cup then click an ear.
## Keyboard: Left/Right choose an ear, Enter/Space places the cup in hand (red first).
## Story-internal:  var g := Earphones.new(); g.setup(clinic); hud.add_game(g); await g.run()
## Beat: earphones_place. Anchors: ear_target_right/left, earphone_red/blue.

signal _changed

const UiKit := preload("res://story/ui_kit.gd")
const CUP_R := 44.0
const TARGET_R := 50.0

var clinic: Node
## (v3) "his" (Gus) or "her" (Bonnie): the patient's right is on YOUR left either way.
var pronoun := "his"
var mistakes := 0
var placed: Dictionary = {"right": false, "left": false}
var _targets: Dictionary = {}   # ear -> Control (ring)
var _cups: Dictionary = {}      # ear -> Control
var _homes: Dictionary = {}     # ear -> Vector2
var _dragging := ""
var _selected := ""
var _drag_off := Vector2.ZERO
var _kb_target := ""
var _accepting := false
var _t := 0.0
var _caption: Label
var _hints: HBoxContainer
var _legend: PanelContainer


func setup(p_clinic: Node, p_pronoun: String = "his") -> void:
	clinic = p_clinic
	pronoun = p_pronoun


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 92
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_caption = UiKit.label("Earphones on! Red cup = RIGHT ear. Blue cup = LEFT ear.", 28, Palette.PAPER, 700, 10, Palette.INK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_caption)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hints)
	for ear: String in ["right", "left"]:
		var ring := Control.new()
		ring.size = Vector2(TARGET_R * 2.0, TARGET_R * 2.0)
		ring.mouse_filter = Control.MOUSE_FILTER_STOP
		ring.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ring.draw.connect(_draw_ring.bind(ear, ring))
		ring.gui_input.connect(_on_ring_input.bind(ear))
		add_child(ring)
		_targets[ear] = ring
		Hoot.register_anchor("ear_target_" + ear, ring)
	# the tray: blue on the left, red on the right (tempting!)
	var tray := Control.new()
	tray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tray.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tray.offset_left = -170
	tray.offset_right = 170
	tray.offset_top = -150
	tray.offset_bottom = -26
	tray.draw.connect(func() -> void:
		UiDraw.rounded_rect(tray, Rect2(Vector2(0, 30), Vector2(340, 90)), Color("#c8874b"), 24, 4, Palette.INK)
		UiDraw.rounded_rect(tray, Rect2(Vector2(12, 40), Vector2(316, 30)), Color(1, 1, 1, 0.18), 14))
	add_child(tray)
	for ear: String in ["left", "right"]:
		var cup := Control.new()
		cup.size = Vector2(CUP_R * 2.0, CUP_R * 2.0)
		cup.pivot_offset = cup.size * 0.5
		cup.mouse_filter = Control.MOUSE_FILTER_STOP
		cup.mouse_default_cursor_shape = Control.CURSOR_DRAG
		cup.draw.connect(_draw_cup.bind(ear, cup))
		cup.gui_input.connect(_on_cup_input.bind(ear))
		add_child(cup)
		_cups[ear] = cup
		Hoot.register_anchor("earphone_" + ("red" if ear == "right" else "blue"), cup)
	_legend = UiKit.panel(Color(Palette.PAPER, 0.95), Palette.INK, 16)
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_legend.offset_left = 20
	_legend.offset_top = -120
	_legend.offset_bottom = -20
	_legend.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var lv := VBoxContainer.new()
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.add_child(lv)
	lv.add_child(UiKit.label("Red = Right   (O)", 20, Palette.RIGHT_RED, 700))
	lv.add_child(UiKit.label("Blue = Left   (X)", 20, Palette.LEFT_BLUE, 700))
	lv.add_child(UiKit.label("%s right is YOUR left" % pronoun.capitalize(), 15, Palette.INK_SOFT, 500))
	add_child(_legend)
	resized.connect(_layout)


func _layout() -> void:
	var vp := size
	_homes["left"] = Vector2(vp.x * 0.5 - 95.0, vp.y - 76.0)
	_homes["right"] = Vector2(vp.x * 0.5 + 95.0, vp.y - 76.0)
	for ear: String in _cups:
		if not placed[ear] and _dragging != ear:
			(_cups[ear] as Control).position = (_homes[ear] as Vector2) - Vector2(CUP_R, CUP_R)
	if clinic:
		for ear: String in _targets:
			var p: Vector2 = clinic.call("get_ear_screen_position", ear)
			(_targets[ear] as Control).position = p - Vector2(TARGET_R, TARGET_R)


## (coroutine) Wait until both cups sit on the right ears. Emits awaiting_input(earphones_place).
func run() -> void:
	_layout()
	_accepting = true
	_set_hints()
	for ear: String in _cups:
		Juice.bounce_in(_cups[ear] as Control, 0.4)
	Events.awaiting_input.emit(&"earphones_place", {"targets": ["ear_target_right", "ear_target_left"]}, _solve)
	while not (placed["right"] and placed["left"]):
		await _changed
	_accepting = false
	_caption.text = "Snug as a bug!" if mistakes == 0 else "There we go. Red = Right!"
	Juice.pop(_caption, 1.2, 0.3)


func _solve() -> void:
	for ear: String in ["right", "left"]:
		if not placed[ear]:
			_drop(ear, (_targets[ear] as Control).get_global_rect().get_center())


func _set_hints() -> void:
	for c in _hints.get_children():
		c.queue_free()
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_panel(["Drag RED onto %s right ear (your left)   or" % pronoun.to_upper(), ["Left", "Right"], "+", ["Enter"]], 16))


func _in_hand() -> String:
	if _selected != "" and not placed[_selected]:
		return _selected
	if not placed["right"]:
		return "right"
	if not placed["left"]:
		return "left"
	return ""


func _on_cup_input(event: InputEvent, ear: String) -> void:
	if not _accepting or placed[ear]:
		return
	var cup: Control = _cups[ear]
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = ear
			_drag_off = mb.position
			_selected = ear
			cup.scale = Vector2.ONE * 1.12
			Sfx.play(&"pop", 1.3, -10.0)
			cup.move_to_front()
		else:
			_dragging = ""
			cup.scale = Vector2.ONE
			var center := cup.get_global_rect().get_center()
			if center.distance_to(_homes[ear] as Vector2) < CUP_R:
				return  # a click, not a drag: keep it selected for click-to-place
			_drop(ear, center)
		accept_event()
	elif event is InputEventMouseMotion and _dragging == ear:
		# relative is in the cup's local space; the grabbed cup is scaled up, so convert back
		# to the parent's space or the cup lags behind the cursor
		cup.position += (event as InputEventMouseMotion).relative * cup.scale


func _on_ring_input(event: InputEvent, ring_ear: String) -> void:
	if not _accepting:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var ear := _in_hand()
		if ear != "":
			_drop(ear, (_targets[ring_ear] as Control).get_global_rect().get_center())
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"freq_down"):
		_kb_target = "right"  # his right ear is on the screen's left
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"freq_up"):
		_kb_target = "left"
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _kb_target == "":
			_kb_target = "right" if (_targets["right"] as Control).position.x < (_targets["left"] as Control).position.x else "left"
			Sfx.play(&"blip", 1.3, -10.0)
		else:
			var ear := _in_hand()
			if ear != "":
				_drop(ear, (_targets[_kb_target] as Control).get_global_rect().get_center())
	else:
		return
	Sfx.play(&"blip", 1.4, -12.0)
	get_viewport().set_input_as_handled()


func _drop(ear: String, at: Vector2) -> void:
	var cup: Control = _cups[ear]
	var hit := ""
	for tgt_ear: String in _targets:
		var ring: Control = _targets[tgt_ear]
		if ring.get_global_rect().grow(26.0).has_point(at):
			hit = tgt_ear
	if hit == ear and not placed[ear]:
		placed[ear] = true
		_selected = ""
		var ring2: Control = _targets[ear]
		var t := cup.create_tween()
		t.tween_property(cup, "position", ring2.position + (ring2.size - cup.size) * 0.5, 0.12)
		t.tween_property(cup, "scale", Vector2(1.25, 0.8), 0.06)
		t.tween_property(cup, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Sfx.play(&"pop")
		Juice.float_text(self, "Right ear!" if ear == "right" else "Left ear!", ring2.get_global_rect().get_center() + Vector2(0, -70), Palette.ear_color(ear), 30)
		Events.patient_reaction.emit(&"nod", {"ear": ear})
		_changed.emit()
		return
	if hit != "" and hit != ear:
		mistakes += 1
		# A wrong drop bounces back, so the cups always end up on the right ears: record the slip,
		# but do NOT set "earphones_swapped" (the AudiOtron reads that as phones on the wrong ears).
		Game.set_visit_flag("earphone_slips", int(Game.get_visit_flag("earphone_slips", 0)) + 1)
		Sfx.play(&"boing", 1.2)
		Events.patient_reaction.emit(&"point_wrong_way", {"ear": hit})
		Juice.float_text(self, "Wrong ear!", at + Vector2(-110, -80), Palette.CORAL, 30)  # clear of Hoot's bubble
		Hoot.say_once("tip_red_right", "Red = Right! %s right... which is on YOUR left." % pronoun.to_upper(), Hoot.HIGH, "ear_target_right")
	_selected = ""
	var home: Vector2 = _homes[ear]
	var tb := cup.create_tween()
	tb.tween_property(cup, "position", home - Vector2(CUP_R, CUP_R), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_changed.emit()


func _process(delta: float) -> void:
	_t += delta
	if clinic and _accepting:
		for ear: String in _targets:
			var p: Vector2 = clinic.call("get_ear_screen_position", ear)
			var ring: Control = _targets[ear]
			ring.position = p - Vector2(TARGET_R, TARGET_R)
			if placed[ear]:
				(_cups[ear] as Control).position = ring.position + (ring.size - (_cups[ear] as Control).size) * 0.5
	for k: String in _targets:
		(_targets[k] as Control).queue_redraw()
	for k: String in _cups:
		(_cups[k] as Control).queue_redraw()


func _draw_ring(ear: String, ring: Control) -> void:
	if placed[ear]:
		return
	var c := ring.size * 0.5
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var hl := _kb_target == ear
	ring.draw_circle(c, TARGET_R, Color(Palette.SUNNY, 0.18 + 0.14 * pulse))
	ring.draw_arc(c, TARGET_R - 3.0, 0, TAU, 40, Color(Palette.INK, 0.55), 8.0, true)
	var segs := 16
	for i in segs:
		if i % 2 == 0:
			var a0 := TAU * i / segs + _t * 0.8
			ring.draw_arc(c, TARGET_R - 3.0, a0, a0 + TAU / segs, 6, Palette.SUNNY if hl else Palette.PAPER, 6.0 if hl else 4.5, true)
	var who := ("%s RIGHT" if ear == "right" else "%s LEFT") % pronoun.to_upper()
	var f := UiKit.font(700)
	var w := f.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	ring.draw_string_outline(f, c + Vector2(-w * 0.5, TARGET_R + 20.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Palette.INK)
	ring.draw_string(f, c + Vector2(-w * 0.5, TARGET_R + 20.0), who, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.PAPER)


func _draw_cup(ear: String, cup: Control) -> void:
	var c := cup.size * 0.5
	var col := Palette.ear_color(ear)
	var lifted := (_in_hand() == ear and _accepting) or _dragging == ear
	if lifted and not placed[ear]:
		cup.draw_circle(c + Vector2(0, 8), CUP_R - 2.0, Color(0, 0, 0, 0.25))
	cup.draw_circle(c, CUP_R, Palette.INK)
	cup.draw_circle(c, CUP_R - 4.0, col)
	cup.draw_circle(c, CUP_R * 0.58, Color("#2e2442"))
	cup.draw_circle(c, CUP_R * 0.4, Color("#4a3f5e"))
	cup.draw_circle(c + Vector2(-CUP_R * 0.45, -CUP_R * 0.45), CUP_R * 0.14, Color(1, 1, 1, 0.5))
	var f := UiKit.font(700)
	var s := "R" if ear == "right" else "L"
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	cup.draw_string(f, c + Vector2(-w * 0.5, 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	if lifted and not placed[ear] and _dragging == "":
		UiDraw.triangle(cup, c + Vector2(0, -CUP_R - 14.0 - 4.0 * absf(sin(_t * 6.0))), 16.0, false, Palette.SUNNY)
