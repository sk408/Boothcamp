extends Control
## Bone-oscillator placement micro-game (v3, Chapter 2). Bonnie in profile (her RIGHT side faces
## us). Put the little vibrator box on her MASTOID: the bony bump just behind the ear, not
## touching the ear itself. Wrong spots are played for laughs (a unicorn horn, a nose boop, a
## buzzing ear flap...) and bounce back; every slip counts.
## Mouse: drag the oscillator onto a spot, or just click a spot.
## Keyboard: Left/Right (or the frequency keys) move the highlight, Enter/Space places it.
## Story-internal:  var g := BonePlacement.new(); hud.add_game(g); await g.run()
## Beat: bc_placement (solver = place on the mastoid). Anchors: "oscillator", "mastoid_target_right".

signal _changed

const UiKit := preload("res://story/ui_kit.gd")
const CARD := Vector2(640, 480)
const HEAD_C := Vector2(330, 236)
const HEAD_R := Vector2(150, 160)
const OSC := Vector2(54, 64)
const SKIN := Color("#e8b088")
const SKIN_SHADE := Color("#c98a62")
const HAIR := Color("#8a4f2a")
const WOOD := Color("#d9a066")
const DEVICE := Color("#5c6370")

## The spots, in keyboard order (front of the face to the back). [id, centre (card), radius,
## Hoot line (<= 18 words), float text]. The first one listed with id "mastoid" is the right one.
const ZONES: Array = [
	["nose", Vector2(-164, 10), 24.0, "Boop! A nose is cartilage. Find the bony bump behind her ear.", "BOOP!"],
	["forehead", Vector2(-116, -50), 30.0, "Foreheads work for some tests. Today: the mastoid, just behind her right ear.", "Hmm, not today"],
	["jaw", Vector2(-62, 116), 28.0, "She'd hear her teeth chatter! Higher and further back: the mastoid.", "Chatter chatter!"],
	["top", Vector2(-6, -150), 32.0, "A majestic unicorn! Sadly not a clinical position. Behind the ear, please.", "UNICORN!"],
	["pinna", Vector2(36, 6), 30.0, "Off the ear flap! Touching the pinna makes it buzz. Behind the ear, on bone.", "Bzzz! Tickles!"],
	["mastoid", Vector2(96, 70), 28.0, "Perfect: on the mastoid bone, behind the ear, not touching it.", "Bone on bone!"],
	["bun", Vector2(74, -178), 40.0, "That's a bun, not a bone! Lovely bun though. Try behind her ear.", "Fresh bun!"],
]

var mistakes := 0
var placed := false
var wrong_spots: Array[String] = []
var _card: Control
var _osc: Control
var _osc_home := Vector2.ZERO
var _zones: Dictionary = {}       # id -> Control (hit target)
var _kb := -1                     # index into ZONES highlighted by the keyboard
var _hover := ""
var _dragging := false
var _accepting := false
var _gag := ""                    # id of the wrong spot currently showing its gag
var _gag_t := 0.0
var _t := 0.0
var _caption: Label
var _hints: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 92
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	_caption = UiKit.label("Bone time! Put the buzzer on her MASTOID, just behind the ear.", 26, Palette.PAPER, 700, 10, Palette.INK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_caption)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hints)
	_card = Control.new()
	_card.size = CARD
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.draw.connect(_draw_card)
	add_child(_card)
	for z: Array in ZONES:
		var id := String(z[0])
		var r := float(z[2])
		var hit := Control.new()
		hit.size = Vector2(r * 2.0, r * 2.0)
		hit.position = HEAD_C + (z[1] as Vector2) - Vector2(r, r)
		hit.mouse_filter = Control.MOUSE_FILTER_STOP
		hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hit.gui_input.connect(_on_zone_input.bind(id))
		hit.mouse_entered.connect(func() -> void: _hover = id)
		hit.mouse_exited.connect(func() -> void: _hover = "" if _hover == id else _hover)
		_card.add_child(hit)
		_zones[id] = hit
	Hoot.register_anchor("mastoid_target_right", _zones["mastoid"])
	_osc = Control.new()
	_osc.size = OSC + Vector2(20, 20)
	_osc.pivot_offset = _osc.size * 0.5
	_osc.mouse_filter = Control.MOUSE_FILTER_STOP
	_osc.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_osc.draw.connect(_draw_osc)
	_osc.gui_input.connect(_on_osc_input)
	_card.add_child(_osc)
	Hoot.register_anchor("oscillator", _osc)
	resized.connect(_layout)


func _exit_tree() -> void:
	Hoot.unregister_anchor("oscillator")
	Hoot.unregister_anchor("mastoid_target_right")


func _layout() -> void:
	_card.position = (size - CARD) * 0.5 + Vector2(0, 46)
	_osc_home = Vector2(CARD.x - 92.0, CARD.y - 96.0)
	if not placed and not _dragging and _gag == "":
		_osc.position = _osc_home - _osc.size * 0.5


## (coroutine) Wait until the oscillator sits on the mastoid. Emits awaiting_input(bc_placement).
func run() -> void:
	_layout()
	_accepting = true
	_set_hints()
	Juice.bounce_in(_osc, 0.4)
	Events.awaiting_input.emit(&"bc_placement", {"targets": ["mastoid_target_right"], "mistakes": mistakes}, _solve)
	while not placed:
		await _changed
	_accepting = false
	_caption.text = "Bone on bone! Snug behind the ear." if mistakes == 0 else "There it is: the mastoid!"
	Juice.pop(_caption, 1.2, 0.3)


func _solve() -> void:
	if not placed:
		_place("mastoid")


func _set_hints() -> void:
	for c in _hints.get_children():
		c.queue_free()
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_panel(["Drag the buzzer, or click a spot   or", ["Left", "Right"], "+", ["Enter"]], 16))


func _zone(id: String) -> Array:
	for z: Array in ZONES:
		if String(z[0]) == id:
			return z
	return []


func _zone_at(card_pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for z: Array in ZONES:
		var d := card_pos.distance_to(HEAD_C + (z[1] as Vector2))
		if d < float(z[2]) + 18.0 and d < best_d:
			best_d = d
			best = String(z[0])
	return best


func _on_zone_input(event: InputEvent, id: String) -> void:
	if not _accepting or _gag != "":
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_place(id)
		accept_event()


func _on_osc_input(event: InputEvent) -> void:
	if not _accepting or placed or _gag != "":
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = true
			_osc.scale = Vector2.ONE * 1.12
			_osc.move_to_front()
			Sfx.play(&"pop", 1.3, -10.0)
		else:
			_dragging = false
			_osc.scale = Vector2.ONE
			var at := _osc.position + _osc.size * 0.5
			var id := _zone_at(at)
			if id != "":
				_place(id)
			else:
				_return_home()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_osc.position += (event as InputEventMouseMotion).relative * _osc.scale
		_hover = _zone_at(_osc.position + _osc.size * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or _gag != "" or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"freq_down"):
		_kb = maxi(0, _kb - 1) if _kb >= 0 else ZONES.size() - 1
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"freq_up"):
		_kb = mini(ZONES.size() - 1, _kb + 1) if _kb >= 0 else 0
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _kb < 0:
			_kb = 0
		else:
			_place(String(ZONES[_kb][0]))
	else:
		return
	Sfx.play(&"blip", 1.4, -12.0)
	get_viewport().set_input_as_handled()


func _place(id: String) -> void:
	if placed or _gag != "":
		return
	var z := _zone(id)
	if z.is_empty():
		return
	var target: Vector2 = HEAD_C + (z[1] as Vector2) - _osc.size * 0.5
	var t := _osc.create_tween()
	t.tween_property(_osc, "position", target, 0.14).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_osc, "scale", Vector2(1.25, 0.8), 0.06)
	t.tween_property(_osc, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if id == "mastoid":
		placed = true
		_hover = ""
		Sfx.play(&"pop")
		Sfx.play(&"ding", 1.2, -8.0)
		Juice.float_text(self, String(z[4]), _card.position + Vector2(116.0, 150.0), Palette.MINT.darkened(0.3), 30)
		Events.patient_reaction.emit(&"nod", {"ear": "right"})
		if mistakes == 0:
			Hoot.say(String(z[3]), Hoot.NORMAL, "mastoid_target_right")
		_changed.emit()
		return
	mistakes += 1
	if not wrong_spots.has(id):
		wrong_spots.append(id)
	Game.set_visit_flag("bc_placement_slips", mistakes)
	_gag = id
	_gag_t = 0.0
	Sfx.play(&"boing", 1.1 + 0.05 * mistakes)
	Events.patient_reaction.emit(&"confused" if id != "pinna" else &"wince", {"ear": "right"})
	Juice.float_text(self, String(z[4]), _card.position + Vector2(116.0, 150.0), Palette.CORAL, 30)
	Hoot.say(String(z[3]), Hoot.HIGH, "mastoid_target_right")
	await get_tree().create_timer(1.1, false).timeout
	_gag = ""
	_return_home()
	_changed.emit()


func _return_home() -> void:
	var tb := _osc.create_tween()
	tb.tween_property(_osc, "position", _osc_home - _osc.size * 0.5, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	_t += delta
	_gag_t += delta
	_card.queue_redraw()
	_osc.queue_redraw()


# ---------------------------------------------------------------- drawing

func _ellipse(c: Vector2, r: Vector2, a0: float = 0.0, a1: float = TAU, n: int = 48) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


func _blob(ci: CanvasItem, pts: PackedVector2Array, fill: Color, outline: float = 4.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Palette.INK, outline, true)


func _draw_card() -> void:
	var c := _card
	UiDraw.rounded_rect(c, Rect2(Vector2(0, 8), CARD), Color(Palette.INK, 0.25), 28)
	UiDraw.rounded_rect(c, Rect2(Vector2.ZERO, CARD), Palette.CREAM, 28, 4, Palette.INK)
	var f := UiKit.font(700)
	c.draw_string(f, Vector2(24, 40), "BONNIE'S RIGHT SIDE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)
	c.draw_string(UiKit.font(500), Vector2(24, 62), "She faces left. Her right ear is the one you see.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_SOFT)
	var h := HEAD_C
	# shoulders + apron, neck
	_blob(c, PackedVector2Array([h + Vector2(-150, 236), h + Vector2(-120, 175), h + Vector2(-20, 150), h + Vector2(120, 160), h + Vector2(190, 236)]), Color("#f2a541"))
	_blob(c, PackedVector2Array([h + Vector2(-80, 236), h + Vector2(-60, 175), h + Vector2(40, 172), h + Vector2(70, 236)]), Color("#fffaf0"), 3.0)
	_blob(c, PackedVector2Array([h + Vector2(-40, 110), h + Vector2(60, 120), h + Vector2(66, 176), h + Vector2(-34, 172)]), SKIN)
	# head (a bean in profile, facing left)
	_blob(c, _ellipse(h, HEAD_R), SKIN)
	# hair: covers the crown and the back of the head above the ear (her bun is pulled up, so the
	# skin behind the ear, over the mastoid, is bare)
	var hair := PackedVector2Array()
	for i in 25:
		var a := lerpf(deg_to_rad(-160.0), deg_to_rad(18.0), i / 24.0)
		hair.append(h + Vector2(cos(a) * HEAD_R.x * 1.05, sin(a) * HEAD_R.y * 1.05))
	for p: Vector2 in [Vector2(138, 48), Vector2(112, 6), Vector2(78, -46), Vector2(24, -84), Vector2(-40, -100), Vector2(-100, -88), Vector2(-136, -60)]:
		hair.append(h + p)
	_blob(c, hair, HAIR)
	c.draw_arc(h + Vector2(10, -40), 90.0, -2.2, -1.2, 12, HAIR.lightened(0.22), 4.0, true)
	# a proper cartoon nose sticking out to the left
	var nose := PackedVector2Array([h + Vector2(-140, -26), h + Vector2(-184, 10), h + Vector2(-178, 26), h + Vector2(-142, 30)])
	c.draw_colored_polygon(nose, SKIN)
	c.draw_polyline(PackedVector2Array([nose[0], nose[1], nose[2], nose[3]]), Palette.INK, 4.0, true)
	# eye looking left, lashes, cheek, smile
	_blob(c, _ellipse(h + Vector2(-100, -20), Vector2(11, 13), 0.0, TAU, 20), Color.WHITE, 3.0)
	c.draw_circle(h + Vector2(-105, -18), 6.0, Palette.INK)
	c.draw_circle(h + Vector2(-107, -21), 2.0, Color.WHITE)
	c.draw_line(h + Vector2(-104, -34), h + Vector2(-116, -44), Palette.INK, 3.0, true)
	c.draw_line(h + Vector2(-96, -34), h + Vector2(-102, -47), Palette.INK, 3.0, true)
	c.draw_circle(h + Vector2(-78, 38), 18.0, Color("#ff9aa2", 0.45))
	c.draw_polyline(_ellipse(h + Vector2(-116, 58), Vector2(20, 12), PI * 0.1, PI * 0.75, 10), Color("#d9465f"), 4.0, true)
	var bun_c := h + Vector2(74, -178)
	var spoon_a := bun_c + Vector2(-70, 34)
	var spoon_b := bun_c + Vector2(64, -40)
	c.draw_line(spoon_a, spoon_b, Palette.INK, 11.0, true)
	c.draw_line(spoon_a, spoon_b, WOOD, 6.0, true)
	_blob(c, _ellipse(bun_c, Vector2(52, 46)), HAIR)
	c.draw_arc(bun_c + Vector2(-6, -4), 26.0, -2.6, -0.6, 12, HAIR.lightened(0.25), 4.0, true)
	_blob(c, _ellipse(spoon_b + Vector2(10, -6), Vector2(16, 11)), WOOD, 3.0)
	# the ear (pinna) and the mastoid bump behind it
	var ear_c := h + Vector2(36, 6)
	_blob(c, _ellipse(ear_c, Vector2(22, 36)), SKIN)
	c.draw_arc(ear_c + Vector2(2, -4), 14.0, -2.6, 1.6, 14, SKIN_SHADE, 5.0, true)
	c.draw_circle(ear_c + Vector2(-2, 6), 5.0, SKIN_SHADE)
	if _gag == "pinna":
		for i in 3:
			var a := -0.9 + i * 0.9
			var r := 40.0 + 6.0 * sin(_gag_t * 30.0 + i)
			c.draw_arc(ear_c, r, a - 0.25, a + 0.25, 6, Palette.CORAL, 3.0, true)
	var m := h + Vector2(96, 70)
	c.draw_arc(m, 18.0, -2.4, 0.6, 12, Color(SKIN_SHADE, 0.9), 3.0, true)
	# the spots
	for z: Array in ZONES:
		_draw_zone(String(z[0]), h + (z[1] as Vector2), float(z[2]))
	# gags
	if _gag == "top":
		var tip := h + Vector2(-6, -236 + 5.0 * sin(_gag_t * 8.0))
		var base := h + Vector2(-6, -160)
		var horn := PackedVector2Array([base + Vector2(-26, 0), tip, base + Vector2(26, 0)])
		_blob(c, horn, Color("#ffd23f"), 4.0)
		for i in 3:
			var y := lerpf(base.y - 30.0, tip.y + 40.0, i / 2.0)
			var w := 26.0 * (y - tip.y) / (base.y - tip.y)
			c.draw_line(Vector2(base.x - w, y + 10), Vector2(base.x + w, y - 10), Color("#ff9f1c"), 3.0, true)
		UiDraw.star(c, tip + Vector2(30, 20), 10.0 + 3.0 * sin(_gag_t * 12.0), Color("#ffd23f"))
	elif _gag == "nose":
		var s := 1.0 + 0.3 * absf(sin(_gag_t * 20.0))
		c.draw_circle(h + Vector2(-178, 4), 12.0 * s, Color("#ff6f59", 0.6))
	elif _gag == "jaw":
		for i in 4:
			c.draw_line(h + Vector2(-120 + i * 12, 96), h + Vector2(-124 + i * 12 + 6.0 * sin(_gag_t * 40.0 + i), 86), Palette.INK, 3.0, true)
	elif _gag == "bun":
		for i in 5:
			var a := TAU * i / 5.0 + _gag_t * 2.0
			c.draw_circle(bun_c + Vector2(cos(a), sin(a)) * (60.0 + 20.0 * _gag_t), 5.0, Color(Color.WHITE, maxf(0.0, 1.0 - _gag_t)))
	# the tray
	UiDraw.rounded_rect(c, Rect2(_osc_home - Vector2(70, 46), Vector2(140, 92)), Color("#e6d8bd"), 20, 3, Color(Palette.INK, 0.5))
	c.draw_string(f, _osc_home + Vector2(-56, 64), "BONE BUZZER", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_SOFT)


func _draw_zone(id: String, at: Vector2, r: float) -> void:
	if placed and id != "mastoid":
		return
	var hl := _hover == id or (_kb >= 0 and String(ZONES[_kb][0]) == id)
	var bad := wrong_spots.has(id)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0 + at.x * 0.03)
	if placed:
		_card.draw_circle(at, r + 6.0, Color(Palette.MINT, 0.5))
		return
	var col := Palette.CORAL if bad else Palette.SUNNY
	_card.draw_circle(at, r, Color(col, (0.06 + 0.08 * pulse) if not hl else 0.4))
	var segs := 12
	for i in segs:
		if i % 2 == 0:
			var a0 := TAU * i / segs + _t * 0.7
			_card.draw_arc(at, r - 2.0, a0, a0 + TAU / segs, 5, Palette.INK if hl else Color(Palette.INK, 0.25), 4.0 if hl else 2.0, true)
	if bad:
		UiDraw.cross(_card, at, 10.0, Color(Palette.CORAL.darkened(0.2), 0.8), 3.0)
	if hl:
		var f := UiKit.font(700)
		var spot_name: String = {"nose": "nose", "forehead": "forehead", "jaw": "jaw", "top": "top of head", "pinna": "ear flap", "mastoid": "behind the ear", "bun": "bun"}[id]
		var w := f.get_string_size(spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_card.draw_string_outline(f, at + Vector2(-w * 0.5, r + 20.0), spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Palette.PAPER)
		_card.draw_string(f, at + Vector2(-w * 0.5, r + 20.0), spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)


func _draw_osc() -> void:
	var o := _osc
	var c := o.size * 0.5
	var lifted := _dragging or (_accepting and not placed and _gag == "")
	if lifted and not placed:
		UiDraw.rounded_rect(o, Rect2(c - OSC * 0.5 + Vector2(0, 8), OSC), Color(0, 0, 0, 0.22), 14)
	var buzz := Vector2(sin(_t * 60.0), 0.0) * (1.5 if placed else 0.0)
	UiDraw.rounded_rect(o, Rect2(c - OSC * 0.5 + buzz, OSC), DEVICE, 14, 4, Palette.INK)
	UiDraw.rounded_rect(o, Rect2(c - OSC * 0.5 + Vector2(8, 8) + buzz, Vector2(OSC.x - 16, 14)), DEVICE.lightened(0.25), 6)
	o.draw_circle(c + Vector2(0, 10) + buzz, 9.0, Palette.SUNNY if placed else Color("#ffd23f", 0.55))
	o.draw_arc(c + Vector2(0, 10) + buzz, 9.0, 0, TAU, 16, Palette.INK, 2.0, true)
	if placed:
		for i in 2:
			var r := 36.0 + 8.0 * i + 4.0 * sin(_t * 18.0 + i)
			o.draw_arc(c, r, -0.5, 0.5, 6, Color(Palette.INK, 0.5), 2.5, true)
			o.draw_arc(c, r, PI - 0.5, PI + 0.5, 6, Color(Palette.INK, 0.5), 2.5, true)
	elif lifted and not _dragging:
		UiDraw.triangle(o, c + Vector2(0, -OSC.y * 0.5 - 14.0 - 4.0 * absf(sin(_t * 6.0))), 16.0, false, Palette.SUNNY)
