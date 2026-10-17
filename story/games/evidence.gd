extends Control
## Present the Evidence: which part of the audiogram explains why Gus hears "fishes" when
## Doris says "dishes"? Drag an exhibit onto the case card (or click it, then the card).
## Keyboard: 1 / 2 / 3 picks an exhibit, Enter / Space presents it.
## Story-internal:  var e := Evidence.new(); hud.add_game(e); await e.run(results)
## Beat: evidence_present. Anchors: evidence_target (case card), evidence_slope (exhibit B).

signal _presented

const UiKit := preload("res://story/ui_kit.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"
const CORRECT := 1

var attempts := 0
var solved := false
var ag: Audiogram
var _board: PanelContainer
var _case: PanelContainer
var _case_body: Label
var _slot: Control
var _exhibits: Array[PanelContainer] = []
var _regions: Array[Rect2] = []
var _selected := -1
var _dragging := -1
var _drag_ghost: PanelContainer
var _accepting := false
var _fx: Control
var _t := 0.0
var _burst := 0.0
var _burst_text := ""
var _burst_color := Palette.SUNNY
var _burst_at := Vector2.ZERO
var _hints: HBoxContainer

const EXHIBITS: Array[Dictionary] = [
	{"tag": "A", "title": "The LOW pitches", "sub": "250-500 Hz", "col": Color("#ffd23f")},
	{"tag": "B", "title": "The HIGH-pitch slope", "sub": "2000-8000 Hz", "col": Color("#ff9f1c")},
	{"tag": "C", "title": "One sesame seed", "sub": "ear, 1987-today", "col": Color("#c9b98a")},
]
## Every exhibit looks the same until it is hovered or picked (colour must not give the answer away).
const EXHIBIT_NEUTRAL := Color("#fffaf0")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("#e9d2ad")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var cork := UiKit.full_rect()
	cork.draw.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 42
		for i in 260:
			cork.draw_circle(Vector2(rng.randf() * size.x, rng.randf() * size.y), rng.randf_range(1.0, 2.6), Color("#c9a77a")))
	add_child(cork)
	var head := UiKit.label("PRESENT THE EVIDENCE!", 38, Palette.PAPER, 700, 14, Palette.INK)
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.offset_top = 14
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(head)

	_board = UiKit.panel(Palette.PAPER, Palette.INK, 18)
	_board.position = Vector2(34, 82)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_board)
	var bv := VBoxContainer.new()
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_child(bv)
	bv.add_child(UiKit.label("Gus's audiogram", 18, Palette.INK_SOFT, 700))
	if ResourceLoader.exists(AUDIOGRAM_SCENE):
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Audiogram
		ag.ear = "both"
		ag.custom_minimum_size = Vector2(640, 330)
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(ag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bv.add_child(row)
	for i in EXHIBITS.size():
		var ex := _make_exhibit(i)
		row.add_child(ex)
		_exhibits.append(ex)
	Hoot.register_anchor("evidence_slope", _exhibits[CORRECT])

	_case = UiKit.panel(Color("#fffdf3"), Palette.INK, 10)
	_case.position = Vector2(748, 112)
	_case.custom_minimum_size = Vector2(480, 0)
	_case.rotation = 0.02
	_case.mouse_filter = Control.MOUSE_FILTER_STOP
	_case.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_case.gui_input.connect(_on_case_input)
	add_child(_case)
	Hoot.register_anchor("evidence_target", _case)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_case.add_child(cv)
	cv.add_child(UiKit.label("CASE FILE #1987", 16, Palette.RIGHT_RED, 700))
	cv.add_child(UiKit.label("The Mystery of the Missing \"Dishes\"", 25, Palette.INK, 700))
	_case_body = UiKit.label("Doris says:  \"Do the DISHES.\"\nGus hears:  \"Do the... FISHES?\"\n\nWhy do the soft consonants get scrambled?", 21, Palette.INK, 500)
	_case_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_case_body.custom_minimum_size = Vector2(440, 0)
	cv.add_child(_case_body)
	_slot = Control.new()
	_slot.custom_minimum_size = Vector2(440, 96)
	_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slot.draw.connect(_draw_slot)
	cv.add_child(_slot)

	_hints = HBoxContainer.new()
	_hints.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hints.offset_top = -40
	_hints.offset_bottom = -12
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	_fx = UiKit.full_rect()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	# Hoot's objections sit under the case file, not on top of it
	Hoot.set_bubble_hint(Rect2(Vector2(748, 452), Vector2(480, 110)))


func _exit_tree() -> void:
	Hoot.clear_bubble_hint()


func _make_exhibit(i: int) -> PanelContainer:
	var spec: Dictionary = EXHIBITS[i]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.style(EXHIBIT_NEUTRAL, Palette.INK, 12, 3, 4, 10))  # no colour hint until picked
	p.custom_minimum_size = Vector2(204, 0)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UiKit.key_chip(str(i + 1), 14))
	top.add_child(UiKit.label("  EXHIBIT " + String(spec["tag"]), 14, Palette.INK_SOFT, 700))
	v.add_child(UiKit.label(spec["title"], 19, Palette.INK, 700))
	v.add_child(UiKit.label(spec["sub"], 15, Palette.INK_SOFT, 500))
	p.gui_input.connect(_on_exhibit_input.bind(i))
	p.mouse_entered.connect(func() -> void:
		if _accepting and _dragging < 0:
			_select(i, false))
	return p


## Draw Gus's results on the board before the beat starts (so Hoot's question has data under it).
func preview(results: Dictionary) -> void:
	if ag:
		ag.show_results(results, false)


## (coroutine) Emits awaiting_input(evidence_present); returns once the right exhibit lands.
func run(results: Dictionary) -> void:
	if ag:
		ag.show_results(results, false)
	await get_tree().process_frame
	_compute_regions()
	_accepting = true
	_set_hints()
	Events.awaiting_input.emit(&"evidence_present", {"target": "evidence_target"}, _solve)
	while not solved:
		await _presented
	_accepting = false


func _solve() -> void:
	_present(CORRECT)


func _compute_regions() -> void:
	_regions.clear()
	if ag == null:
		return
	_regions.append(ag.get_region_global_rect(250, 500, -10, 45))
	_regions.append(ag.get_region_global_rect(2000, 8000, 25, 85))
	var seed_r := ag.get_region_global_rect(750, 1500, 70, 110)
	_regions.append(Rect2(seed_r.get_center() - Vector2(30, 22), Vector2(60, 44)))


func _set_hints() -> void:
	for c in _hints.get_children():
		c.queue_free()
	var parts: Array = ["Drag an exhibit onto the case file"]
	if UiKit.show_key_hints():
		parts = ["Drag an exhibit onto the case file, or press", ["1"], ["2"], ["3"], "then", ["Enter"]]
	_hints.add_child(UiKit.hint_row(parts, 17, Palette.INK))


func _select(i: int, sound: bool = true) -> void:
	_selected = i
	for j in _exhibits.size():
		var on := j == i
		var spec: Dictionary = EXHIBITS[j]
		_exhibits[j].add_theme_stylebox_override("panel", UiKit.style(Color(spec["col"]).lightened(0.25) if on else EXHIBIT_NEUTRAL, Palette.INK, 12, 4 if on else 3, 8 if on else 4, 10))
	if sound:
		Sfx.play(&"blip", 1.3, -8.0)


func _on_exhibit_input(event: InputEvent, i: int) -> void:
	if not _accepting:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = i
			_select(i)
			_make_ghost(i, mb.global_position)
		else:
			var at := mb.global_position
			_dragging = -1
			_free_ghost()
			if _case.get_global_rect().grow(16.0).has_point(at):
				_present(i)
		accept_event()
	elif event is InputEventMouseMotion and _dragging == i and _drag_ghost:
		_drag_ghost.position = (event as InputEventMouseMotion).global_position - _drag_ghost.size * 0.5


func _on_case_input(event: InputEvent) -> void:
	if not _accepting:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _selected >= 0:
			_present(_selected)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_3:
			_select(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
		_select((_selected + 1) % _exhibits.size())
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		_select((_selected - 1 + _exhibits.size()) % _exhibits.size())
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _selected >= 0:
			_present(_selected)
		else:
			_select(0)
	else:
		return
	get_viewport().set_input_as_handled()


func _make_ghost(i: int, at: Vector2) -> void:
	_free_ghost()
	var spec: Dictionary = EXHIBITS[i]
	_drag_ghost = UiKit.panel(Color(spec["col"]).lightened(0.3), Palette.INK, 12)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.add_child(UiKit.label("EXHIBIT %s: %s" % [spec["tag"], spec["title"]], 18, Palette.INK, 700))
	_drag_ghost.rotation = -0.05
	add_child(_drag_ghost)
	_drag_ghost.reset_size()
	_drag_ghost.position = at - _drag_ghost.size * 0.5


func _free_ghost() -> void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null


func _present(i: int) -> void:
	if solved or not _accepting:
		return
	attempts += 1
	var spec: Dictionary = EXHIBITS[i]
	var center := _case.get_global_rect().get_center()
	if i == CORRECT:
		solved = true
		Hoot.dismiss_current()
		_burst_text = "THAT'S IT!"
		_burst_color = Palette.SUNNY
		_burst_at = center + Vector2(0, -40)
		_burst = 1.0
		Sfx.play(&"stamp")
		get_tree().create_timer(0.25).timeout.connect(Sfx.play.bind(&"fanfare", 1.0, -4.0))
		Events.screen_shake.emit(0.35, 0.25)
		_case_body.text = "Soft consonants (s, sh, f, th) are quiet, HIGH-pitched sounds.\nGus's hearing slopes down right there,\nso he guesses: \"dishes\" becomes \"fishes\"."
		Juice.pop(_case, 1.06, 0.3)
		_select(i, false)
		_slot.set_meta("filled", i)
		_slot.queue_redraw()
		_presented.emit()
		return
	_burst_text = "OBJECTION!"
	_burst_color = Palette.CORAL
	_burst_at = center + Vector2(-60, -30)
	_burst = 1.0
	Sfx.play(&"error")
	Juice.shake(_case, 10.0, 0.3)
	var why := "Objection! His low pitches are nearly normal." if i == 0 else "Objection! The seed is gone. (Gus kept it.)"
	Hoot.say(why, Hoot.HIGH, "evidence_slope")
	_presented.emit()


func _process(delta: float) -> void:
	_t += delta
	if _burst > 0.0:
		_burst = maxf(0.0, _burst - delta * 0.55)
	_fx.queue_redraw()
	_slot.queue_redraw()


func _draw_slot() -> void:
	var r := Rect2(Vector2(4, 8), _slot.size - Vector2(8, 12))
	if _slot.has_meta("filled"):
		var i: int = _slot.get_meta("filled")
		UiDraw.rounded_rect(_slot, r, Color(EXHIBITS[i]["col"]).lightened(0.3), 12, 3, Palette.INK)
		var f := UiKit.font(700)
		_slot.draw_string(f, r.position + Vector2(16, 40), "EXHIBIT B: the high-pitch slope", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
		# the stamp
		_slot.draw_set_transform(r.position + Vector2(r.size.x - 104, 50), -0.25, Vector2.ONE)
		UiDraw.rounded_rect(_slot, Rect2(Vector2(-70, -26), Vector2(140, 52)), Color(Palette.MINT, 0.2), 8, 5, Palette.MINT.darkened(0.2))
		_slot.draw_string(f, Vector2(-58, 13), "IT FITS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.MINT.darkened(0.25))
		_slot.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var segs := 28
	var per := (r.size.x * 2.0 + r.size.y * 2.0) / segs
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := int(a.distance_to(b) / per)
		for j in n:
			if j % 2 == 0:
				_slot.draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(Palette.INK, 0.35 + 0.3 * pulse), 3.0)
	var f2 := UiKit.font(600)
	_slot.draw_string(f2, r.position + Vector2(0, r.size.y * 0.5 + 8), "Drop the evidence here", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Palette.INK_SOFT)


func _draw_fx() -> void:
	# highlight the audiogram region of the selected / dragged exhibit
	var which := _dragging if _dragging >= 0 else _selected
	if _accepting and which >= 0 and which < _regions.size():
		var rr := _regions[which]
		var col: Color = EXHIBITS[which]["col"]
		UiDraw.rounded_rect(_fx, rr, Color(col, 0.28), 10, 3, col.darkened(0.2))
		if which == 2:
			# the infamous seed
			_fx.draw_circle(rr.get_center(), 9.0, Color("#f6e7b8"))
			_fx.draw_arc(rr.get_center(), 9.0, 0, TAU, 14, Color("#b89a60"), 2.0)
	if _burst > 0.0:
		var k := 1.0 - _burst
		var sc := 0.6 + 0.6 * minf(1.0, k * 6.0)
		_fx.draw_set_transform(_burst_at, -0.12, Vector2.ONE * sc)
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var rad := 150.0 if i % 2 == 0 else 105.0
			pts.append(Vector2(cos(a) * rad * 1.5, sin(a) * rad * 0.7))
		_fx.draw_colored_polygon(pts, Color(_burst_color, minf(1.0, _burst * 2.0)))
		pts.append(pts[0])
		_fx.draw_polyline(pts, Color(Palette.INK, minf(1.0, _burst * 2.0)), 5.0, true)
		var f := UiKit.font(700)
		var w := f.get_string_size(_burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52).x
		_fx.draw_string_outline(f, Vector2(-w * 0.5, 18), _burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, 12, Color(Palette.INK, minf(1.0, _burst * 2.0)))
		_fx.draw_string(f, Vector2(-w * 0.5, 18), _burst_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 52, Color(Palette.PAPER, minf(1.0, _burst * 2.0)))
		_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
