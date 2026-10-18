extends Control
## Bone-oscillator placement micro-game (v3, Chapter 2). Bonnie in profile (her RIGHT side faces
## us). Put the bone oscillator on her MASTOID: the bony bump just behind the ear, not touching
## the ear itself. Wrong spots are played for laughs (a unicorn horn on the forehead, a feedback
## squeal on the ear flap, her long-lost glasses on top of her head, a nose boop...) and bounce
## back; every slip counts.
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

## The spots, in keyboard order (front of the face to the back). [id, centre (card), radius,
## Hoot line (<= 18 words), float text]. The one with id "mastoid" is the right one.
## ("top" is where her reading glasses are perched.)
const ZONES: Array = [
	["nose", Vector2(-166, 8), 24.0, "Boop! A nose is cartilage, not bone. Find the bony bump behind her ear.", "BOOP!"],
	["forehead", Vector2(-112, -62), 30.0, "A majestic unicorn! Forehead placement exists, but today: the mastoid, behind her right ear.", "UNICORN!"],
	["jaw", Vector2(-62, 112), 28.0, "She'd hear her teeth chatter! Higher and further back: the mastoid.", "Chatter chatter!"],
	["top", Vector2(-14, -146), 32.0, "Her lost glasses! Mystery solved. Glasses off before the headband; the buzzer goes behind the ear.", "My glasses!"],
	["pinna", Vector2(36, 6), 30.0, "Off the ear flap! Touching the pinna leaks buzz into the canal. Behind it, on bone.", "SQUEEEE!"],
	["mastoid", Vector2(96, 54), 28.0, "Perfect: on the mastoid bone, behind the ear, not touching it.", "Bone on bone!"],
	["bun", Vector2(74, -180), 40.0, "That's a bun, not a bone! Lovely bun though. Try behind her ear.", "Fresh bun!"],
]
## (integrator) The head is drawn facing RIGHT: a profile facing right shows the RIGHT ear (one
## facing left would show her left ear). ZONES and the drawing code below are written for a
## left-facing head; the drawing is mirrored about HEAD_C.x and _zoff() mirrors the zone offsets.
const MIRROR := true
const SPOT_NAMES: Dictionary = {"nose": "nose", "forehead": "forehead", "jaw": "jaw", "top": "glasses", "pinna": "ear flap", "mastoid": "behind the ear", "bun": "bun"}
const GLASSES := Color("#2fb3a3")
const BEIGE := Color("#e3d9c6")
const STEEL := Color("#b9c0cc")

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
var _face := &"smile"             # smile, o (surprised), happy


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
	_caption = UiKit.label("Put the bone oscillator on her MASTOID: the bony bump just behind the ear.", 26, Palette.PAPER, 700, 10, Palette.INK)
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
		hit.position = HEAD_C + _zoff(z) - Vector2(r, r)
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
	Hoot.clear_bubble_hint()


func _layout() -> void:
	_card.position = (size - CARD) * 0.5 + Vector2(0, 46)
	# (polish) Hoot's tips sit right of the card, not over its "BONNIE'S RIGHT SIDE" header
	var right := _card.position.x + CARD.x + 12.0
	if size.x - right >= 260.0:
		Hoot.set_bubble_hint(Rect2(Vector2(right, _card.position.y), Vector2(size.x - right - 12.0, 200.0)))
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
		_hints.add_child(UiKit.hint_panel(["Drag the oscillator, or click a spot   or", ["Left", "Right"], "+", ["Enter"]], 16))


## A zone's offset from HEAD_C as drawn (mirrored when the head faces right).
static func _zoff(z: Array) -> Vector2:
	var v: Vector2 = z[1]
	return Vector2(-v.x, v.y) if MIRROR else v


## Mirror an x offset that was tuned for the left-facing drawing.
static func _mx(v: Vector2) -> Vector2:
	return Vector2(-v.x, v.y) if MIRROR else v


func _zone(id: String) -> Array:
	for z: Array in ZONES:
		if String(z[0]) == id:
			return z
	return []


func _zone_at(card_pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for z: Array in ZONES:
		var d := card_pos.distance_to(HEAD_C + _zoff(z))
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
	# ZONES run front (nose) to back; the arrow that walks towards the back of her head goes up
	var back_key := &"ui_left" if MIRROR else &"ui_right"
	var front_key := &"ui_right" if MIRROR else &"ui_left"
	if event.is_action_pressed(front_key) or event.is_action_pressed(&"freq_down" if not MIRROR else &"freq_up"):
		_kb = maxi(0, _kb - 1) if _kb >= 0 else ZONES.size() - 1
	elif event.is_action_pressed(back_key) or event.is_action_pressed(&"freq_up" if not MIRROR else &"freq_down"):
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
	var target: Vector2 = HEAD_C + _zoff(z) - _osc.size * 0.5
	var t := _osc.create_tween()
	t.tween_property(_osc, "position", target, 0.14).set_trans(Tween.TRANS_QUAD)
	t.tween_property(_osc, "scale", Vector2(1.25, 0.8), 0.06)
	t.tween_property(_osc, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var spot_at: Vector2 = _card.position + HEAD_C + _zoff(z)
	if id == "mastoid":
		placed = true
		_hover = ""
		_face = &"happy"
		Sfx.play(&"pop")
		Sfx.play(&"ding", 1.2, -8.0)
		Juice.float_text(self, String(z[4]), spot_at + _mx(Vector2(-70.0, 96.0)), Palette.MINT.darkened(0.3), 30)
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
	_face = &"o"
	match id:
		"top":
			Sfx.play(&"ding", 1.5, -10.0)
		"pinna":
			Sfx.play(&"squeak", 1.6, -12.0)   # the squeal is drawn, never played loud
		_:
			Sfx.play(&"boing", 1.1 + 0.05 * mistakes)
	Events.patient_reaction.emit(&"confused" if id != "pinna" else &"wince", {"ear": "right"})
	var float_at := spot_at + Vector2(0.0, -56.0)
	match id:
		"forehead":
			float_at = spot_at + _mx(Vector2(-96.0, -16.0))
		"pinna":
			float_at = spot_at + _mx(Vector2(-96.0, -70.0))
		"top":
			float_at = spot_at + _mx(Vector2(-160.0, 64.0))
	float_at.y = maxf(float_at.y, _card.position.y + 100.0)
	Juice.float_text(self, String(z[4]), float_at, Palette.CORAL if id != "top" else GLASSES.darkened(0.25), 30)
	Hoot.say(String(z[3]), Hoot.HIGH, "mastoid_target_right")
	await get_tree().create_timer(1.1, false).timeout
	_gag = ""
	_face = &"smile"
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
	var cap_x := CARD.x - 24.0 - 420.0 if MIRROR else 24.0
	var cap_al := HORIZONTAL_ALIGNMENT_RIGHT if MIRROR else HORIZONTAL_ALIGNMENT_LEFT
	c.draw_string(f, Vector2(cap_x, 40), "BONNIE'S RIGHT SIDE", cap_al, 420, 16, Palette.INK_SOFT)
	c.draw_string(UiKit.font(500), Vector2(cap_x, 62), "She faces %s: her right ear is the one you see." % ("right" if MIRROR else "left"), cap_al, 420, 14, Palette.INK_SOFT)
	var h := HEAD_C
	_flip(c, true)
	# shoulders + apron, neck
	_blob(c, PackedVector2Array([h + Vector2(-150, 236), h + Vector2(-120, 175), h + Vector2(-20, 150), h + Vector2(120, 160), h + Vector2(190, 236)]), Color("#f2a541"))
	_blob(c, PackedVector2Array([h + Vector2(-80, 236), h + Vector2(-60, 175), h + Vector2(40, 172), h + Vector2(70, 236)]), Color("#fffaf0"), 3.0)
	for p: Vector2 in [Vector2(-40, 200), Vector2(10, 215), Vector2(-20, 228)]:
		c.draw_circle(h + p, 4.0, Color(Color.WHITE, 0.9))
	_blob(c, PackedVector2Array([h + Vector2(-40, 110), h + Vector2(60, 120), h + Vector2(66, 176), h + Vector2(-34, 172)]), SKIN)
	# head (a bean in profile, drawn facing left, then mirrored by _flip to face right)
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
	var nose_col := SKIN
	if _gag == "nose":
		nose_col = SKIN.lerp(Color("#ff6f59"), 0.5 + 0.5 * absf(sin(_gag_t * 18.0)))
	c.draw_colored_polygon(nose, nose_col)
	c.draw_polyline(PackedVector2Array([nose[0], nose[1], nose[2], nose[3]]), Palette.INK, 4.0, true)
	# eye looking left, lashes, freckles, cheek, mouth (her face follows the game)
	var eye := h + Vector2(-100, -20)
	if _face == &"happy":
		c.draw_arc(eye + Vector2(0, 6), 10.0, PI + 0.4, TAU - 0.4, 10, Palette.INK, 4.0, true)
	else:
		var er := Vector2(13, 15) if _face == &"o" else Vector2(11, 13)
		_blob(c, _ellipse(eye, er, 0.0, TAU, 20), Color.WHITE, 3.0)
		c.draw_circle(eye + Vector2(-5, 2), 5.0 if _face == &"o" else 6.0, Palette.INK)
		c.draw_circle(eye + Vector2(-7, -1), 2.0, Color.WHITE)
	c.draw_line(eye + Vector2(-4, -14), eye + Vector2(-16, -24), Palette.INK, 3.0, true)
	c.draw_line(eye + Vector2(4, -14), eye + Vector2(-2, -27), Palette.INK, 3.0, true)
	for p: Vector2 in [Vector2(-96, 18), Vector2(-86, 26), Vector2(-104, 28), Vector2(-92, 34)]:
		c.draw_circle(h + p, 2.6, Color("#b06a44", 0.8))
	c.draw_circle(h + Vector2(-72, 40), 18.0, Color("#ff9aa2", 0.45))
	_blob(c, _ellipse(h + Vector2(-58, 52), Vector2(10, 5)), Color(Color.WHITE, 0.95), 0.0)
	if _face == &"o":
		_blob(c, _ellipse(h + Vector2(-120, 60), Vector2(8, 10)), Color("#7a2a3a"), 3.0)
	else:
		c.draw_polyline(_ellipse(h + Vector2(-116, 54), Vector2(20, 14), PI * 0.1, PI * 0.75, 10), Color("#c4453f"), 4.0, true)
	var bun_c := h + Vector2(74, -178)
	var spoon_a := bun_c + Vector2(-70, 34)
	var spoon_b := bun_c + Vector2(64, -40)
	c.draw_line(spoon_a, spoon_b, Palette.INK, 11.0, true)
	c.draw_line(spoon_a, spoon_b, WOOD, 6.0, true)
	_blob(c, _ellipse(bun_c, Vector2(52, 46)), HAIR)
	c.draw_arc(bun_c + Vector2(-6, -4), 26.0, -2.6, -0.6, 12, HAIR.lightened(0.25), 4.0, true)
	_blob(c, _ellipse(spoon_b + Vector2(10, -6), Vector2(16, 11)), WOOD, 3.0)
	# her reading glasses, perched on top of her head (she has been looking for them all morning)
	_draw_glasses(c, h + Vector2(-14, -146) + Vector2(0, -10.0 * absf(sin(_gag_t * 6.0)) if _gag == "top" else 0.0))
	# the ear (pinna): helix rim, a curl inside, the canal opening, a lobe
	var ear_c := h + Vector2(36, 6)
	var ear_wob := Vector2(2.0 * sin(_gag_t * 60.0), 0.0) if _gag == "pinna" else Vector2.ZERO
	_blob(c, _ellipse(ear_c + ear_wob, Vector2(23, 37)), SKIN)
	c.draw_arc(ear_c + ear_wob + Vector2(2, -6), 15.0, -2.8, 1.5, 16, SKIN_SHADE, 5.0, true)
	c.draw_circle(ear_c + ear_wob + Vector2(-3, 7), 6.0, SKIN_SHADE.darkened(0.15))
	c.draw_arc(ear_c + ear_wob + Vector2(-1, 26), 8.0, 0.2, 2.6, 8, SKIN_SHADE, 3.0, true)
	if _gag == "pinna":
		_draw_squeal(c, ear_c)
	# the mastoid: a little bony bump just behind the ear
	var m := h + Vector2(98, 70)
	c.draw_arc(m, 18.0, -2.4, 0.6, 12, Color(SKIN_SHADE, 0.9), 3.0, true)
	# the spots (unmirrored: their labels are text)
	_flip(c, false)
	for z: Array in ZONES:
		_draw_zone(String(z[0]), h + _zoff(z), float(z[2]))
	_flip(c, true)
	# gags
	if _gag == "forehead":
		_draw_unicorn(c, h + Vector2(-118, -78))
	elif _gag == "jaw":
		for i in 4:
			c.draw_line(h + Vector2(-120 + i * 12, 96), h + Vector2(-124 + i * 12 + 6.0 * sin(_gag_t * 40.0 + i), 86), Palette.INK, 3.0, true)
	elif _gag == "bun":
		for i in 6:
			var a := TAU * i / 6.0 + _gag_t * 2.0
			c.draw_circle(bun_c + Vector2(cos(a), sin(a)) * (50.0 + 40.0 * _gag_t), 7.0 - 3.0 * _gag_t, Color(Color.WHITE, maxf(0.0, 1.0 - _gag_t)))
	elif _gag == "top":
		for i in 3:
			UiDraw.star(c, h + Vector2(-14, -176) + Vector2(cos(i * 2.1 + _gag_t * 3.0), sin(i * 2.1 + _gag_t * 3.0)) * 46.0, 8.0, Palette.SUNNY)
	# the band over her head once it is on
	if placed:
		var top := h + Vector2(34, -176)
		var pts := PackedVector2Array()
		for i in 13:
			var k := i / 12.0
			pts.append(m.lerp(top, k) + Vector2(sin(k * PI) * 46.0, 0.0))
		c.draw_polyline(pts, Palette.INK, 9.0, true)
		c.draw_polyline(pts, STEEL, 5.0, true)
	_flip(c, false)
	# the tray
	UiDraw.rounded_rect(c, Rect2(_osc_home - Vector2(78, 50), Vector2(156, 100)), Color("#e6d8bd"), 20, 3, Color(Palette.INK, 0.5))
	var label_w := f.get_string_size("BONE OSCILLATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	c.draw_string(f, _osc_home + Vector2(-label_w * 0.5, 68), "BONE OSCILLATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)


## Mirror the head drawing about HEAD_C.x (on) or back to plain card coordinates (off).
func _flip(c: Control, on: bool) -> void:
	if on and MIRROR:
		c.draw_set_transform(Vector2(2.0 * HEAD_C.x, 0.0), 0.0, Vector2(-1.0, 1.0))
	else:
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_glasses(c: Control, at: Vector2) -> void:
	for side: int in [-1, 1]:
		var lc := at + Vector2(17.0 * side, 0.0)
		_blob(c, _ellipse(lc, Vector2(14, 10)), Color("#dff6ff"), 0.0)
		c.draw_arc(lc, 13.0, 0.0, TAU, 20, Palette.INK, 7.0, true)
		c.draw_arc(lc, 13.0, 0.0, TAU, 20, GLASSES, 4.0, true)
		c.draw_line(lc + Vector2(-6, -4), lc + Vector2(-1, -7), Color.WHITE, 2.5, true)
	c.draw_line(at + Vector2(-4, -1), at + Vector2(4, -1), GLASSES, 4.0, true)
	c.draw_line(at + Vector2(30, -2), at + Vector2(62, 8), Palette.INK, 6.0, true)
	c.draw_line(at + Vector2(30, -2), at + Vector2(62, 8), GLASSES, 3.0, true)


## A golden unicorn horn sprouting from the forehead, with sparkles.
func _draw_unicorn(c: Control, base: Vector2) -> void:
	var grow := clampf(_gag_t / 0.18, 0.0, 1.0)
	var dir := Vector2(-0.55, -1.0).normalized()
	var tip := base + dir * (150.0 * grow) + Vector2(0, 4.0 * sin(_gag_t * 8.0))
	var nrm := Vector2(-dir.y, dir.x)
	var horn := PackedVector2Array([base + nrm * 30.0, tip, base - nrm * 30.0])
	_blob(c, horn, Color("#ffd23f"), 4.0)
	for i in 3:
		var k := 0.25 + i * 0.22
		var p := base.lerp(tip, k)
		var w := 30.0 * (1.0 - k)
		c.draw_line(p + nrm * w, p - nrm * w + dir * 12.0, Color("#ff9f1c"), 3.0, true)
	if grow >= 1.0:
		var cols: Array[Color] = [Color("#ffd23f"), Color("#ff9aa2"), Color("#bfe6ff"), Color("#5bc8a3")]
		for i in 4:
			var a := _gag_t * 4.0 + i * TAU / 4.0
			UiDraw.star(c, tip + Vector2(cos(a), sin(a)) * 30.0, 7.0 + 2.0 * sin(_gag_t * 12.0 + i), cols[i])


## The feedback squeal (drawn only): jagged lines burst off the ear flap.
func _draw_squeal(c: Control, ear_c: Vector2) -> void:
	for i in 7:
		var a := -2.2 + i * 0.62
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x)
		var r0 := 44.0
		var pts := PackedVector2Array()
		for k in 5:
			var r := r0 + k * 9.0 + 4.0 * sin(_gag_t * 50.0 + i)
			pts.append(ear_c + d * r + n * (6.0 if k % 2 == 0 else -6.0))
		c.draw_polyline(pts, Palette.INK, 6.0, true)
		c.draw_polyline(pts, Palette.SUNNY if i % 2 == 0 else Palette.CORAL, 3.0, true)


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
		var spot_name: String = SPOT_NAMES.get(id, id)
		var w := f.get_string_size(spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_card.draw_string_outline(f, at + Vector2(-w * 0.5, r + 20.0), spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 6, Palette.PAPER)
		_card.draw_string(f, at + Vector2(-w * 0.5, r + 20.0), spot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)


## The bone oscillator: a beige transducer with its steel band stub (it matches the 3D one).
func _draw_osc() -> void:
	var o := _osc
	var c := o.size * 0.5
	var lifted := _dragging or (_accepting and not placed and _gag == "")
	if lifted and not placed:
		UiDraw.rounded_rect(o, Rect2(c - OSC * 0.5 + Vector2(0, 8), OSC), Color(0, 0, 0, 0.22), 14)
	var buzz := Vector2(sin(_t * 60.0), 0.0) * (1.5 if placed else 0.0)
	if not placed:
		# the band stub curling up out of the top
		o.draw_arc(c + Vector2(18, -OSC.y * 0.5) + buzz, 18.0, PI, PI * 1.6, 8, Palette.INK, 8.0, true)
		o.draw_arc(c + Vector2(18, -OSC.y * 0.5) + buzz, 18.0, PI, PI * 1.6, 8, STEEL, 4.0, true)
	UiDraw.rounded_rect(o, Rect2(c - OSC * 0.5 + buzz, OSC), BEIGE, 14, 4, Palette.INK)
	o.draw_circle(c + buzz, 15.0, Color("#8d94a6"))
	o.draw_arc(c + buzz, 15.0, 0, TAU, 18, Palette.INK, 3.0, true)
	o.draw_circle(c + buzz + Vector2(-4, -4), 4.0, Color(Color.WHITE, 0.6))
	o.draw_circle(c + Vector2(OSC.x * 0.3, -OSC.y * 0.34) + buzz, 4.0, Palette.PRESS_LIME if placed else Color("#9ee34b", 0.4))
	# the cable
	o.draw_line(c + Vector2(0, OSC.y * 0.5) + buzz, c + Vector2(-6, OSC.y * 0.5 + 12), Palette.INK, 3.0, true)
	if placed:
		for i in 2:
			var r := 36.0 + 8.0 * i + 4.0 * sin(_t * 18.0 + i)
			o.draw_arc(c, r, -0.5, 0.5, 6, Color(Palette.INK, 0.5), 2.5, true)
			o.draw_arc(c, r, PI - 0.5, PI + 0.5, 6, Color(Palette.INK, 0.5), 2.5, true)
	elif lifted and not _dragging:
		UiDraw.triangle(o, c + Vector2(0, -OSC.y * 0.5 - 22.0 - 4.0 * absf(sin(_t * 6.0))), 16.0, false, Palette.SUNNY)
