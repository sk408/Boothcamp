extends Control
## MarcoSeats (Day 5): seat Marco at Trattoria Clatter (docs/CHAPTER5.md §7.1). A cream floor plan
## drawn in code: the bar, the kitchen's swing doors, a music speaker on the wall, the busy tables
## and Marco's guest (a heart). Four seats glow, each a flat Button whose Label starts with the
## option text, so the stock choice beat and the mouse bot handle it (keys 1-4 or a click). Fixed
## order (it is a map). sit() shows what each seat does: the kitchen doors CLANG, the speaker goes
## UNTZ UNTZ, the wrong-way booth points his mics' front half at the whole room, the right booth at
## his guest. Wrong seats grey out.
## Story-internal:
##   var s := MarcoSeats.new(); hud.add_game(s)
##   var i: int = await s.choose(prompt, texts, best)   # beat "choice"
##   await s.sit(id)                                    # "kitchen" | "speaker" | "facing" | "back"
##   await s.fade_out()
## Anchors: seat_kitchen, seat_speaker, seat_facing, seat_back. Nothing here plays louder than the
## shared Sfx; the clatter and the music are drawn.

signal _picked(index: int)

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")

const TITLE := "TRATTORIA CLATTER, SATURDAY"
const MAP := Rect2(40, 112, 1200, 424)
const FLOOR := Color("#fbefd9")
const WALL := Color("#8a5a24")
const TABLE := Color("#e9c89a")
const DINER := Color("#a9a2b8")
const GLOW := Color("#ffd23f")
## The seats in the level's fixed order: where Marco sits, which way he faces (radians, 0 = right),
## and where the seat's button sits.
const SEAT_IDS: Array[String] = ["kitchen", "speaker", "facing", "back"]
const SEAT_AT: Dictionary = {"kitchen": Vector2(100, 424), "speaker": Vector2(420, 192), "facing": Vector2(1176, 214), "back": Vector2(1036, 214)}
const SEAT_FACE: Dictionary = {"kitchen": 0.0, "speaker": PI * 0.5, "facing": PI, "back": 0.0}
const BUTTON_AT: Dictionary = {"kitchen": Vector2(80, 470), "speaker": Vector2(460, 166), "facing": Vector2(880, 352), "back": Vector2(880, 412)}
const BUTTON_SIZE := Vector2(352, 50)
const BOOTH := Rect2(960, 120, 272, 196)
const BOOTH_TABLE := Vector2(1106, 214)
const KITCHEN_DOORS := Rect2(44, 372, 18, 104)
const SPEAKER_AT := Vector2(420, 132)
## The busy room's tables (centre, seats around them).
const TABLES: Array[Vector2] = [Vector2(250, 270), Vector2(520, 330), Vector2(780, 300), Vector2(310, 420), Vector2(700, 440)]

var _buttons: Array[Button] = []
var _choosing := false
var _dead: Dictionary = {}
var _sat := ""
var _sat_t := -1.0
var _t := 0.0
var _art: Control
var _head: Label
var _hints: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_art = UiKit.full_rect()
	_art.name = "Art"
	_art.draw.connect(_draw_art)
	add_child(_art)
	_head = UiKit.label(TITLE, 30, Palette.INK, 700)
	_head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_head.offset_top = 70
	_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_head)
	_hints = HBoxContainer.new()
	_hints.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hints.offset_top = 556
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	for i in SEAT_IDS.size():
		_buttons.append(_make_seat(i))


func _make_seat(i: int) -> Button:
	var id := SEAT_IDS[i]
	var b := Button.new()
	b.name = "seat_" + id
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = BUTTON_AT[id]
	b.size = BUTTON_SIZE
	b.custom_minimum_size = BUTTON_SIZE
	b.pivot_offset = BUTTON_SIZE * 0.5
	b.draw.connect(_draw_seat_button.bind(b, i))
	b.pressed.connect(func() -> void: _pick(i))
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = Vector2(12, 8)
	h.size = BUTTON_SIZE - Vector2(24, 16)
	h.add_theme_constant_override("separation", 8)
	b.add_child(h)
	# room for the seat's number badge (drawn), the same number as its glow on the map
	var pad := Control.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.custom_minimum_size = Vector2(30, 0)
	h.add_child(pad)
	var l := UiKit.label("", 19, Palette.INK, 700)
	l.name = "Text"
	h.add_child(l)
	b.visible = false
	add_child(b)
	Hoot.register_anchor("seat_" + id, b)
	return b


## (coroutine) Beat "choice": pick a seat (keys 1-4 or a click). Returns its index.
func choose(prompt: String, texts: Array[String], best: int) -> int:
	_head.text = prompt
	for i in _buttons.size():
		var l := _buttons[i].find_child("Text", true, false) as Label
		l.text = texts[i] if i < texts.size() else ""
		_buttons[i].visible = i < texts.size()
		_buttons[i].disabled = _dead.has(i)
	if UiKit.show_key_hints():
		_set_hints([["1"], "-", [str(texts.size())], "or click a seat"])
	else:
		_set_hints(["Click a seat"])
	_choosing = true
	Events.awaiting_input.emit(&"choice", {"prompt": prompt, "options": texts, "best": best}, func() -> void: _pick(best))
	var i: int = await _picked
	Events.input_resolved.emit(&"choice")
	_set_hints([])
	return i


func _pick(i: int) -> void:
	if not _choosing or i < 0 or i >= _buttons.size() or _dead.has(i):
		return
	_choosing = false
	Sfx.play(&"click")
	Juice.pop(_buttons[i], 1.06, 0.15)
	_picked.emit(i)


## (coroutine) Marco takes the seat and the room answers; a wrong seat greys out afterwards.
func sit(id: String) -> void:
	_sat = id
	_sat_t = 0.0
	match id:
		"kitchen":
			Sfx.play(&"thunk", 0.5, -6.0)
		"speaker":
			Sfx.play(&"note", 0.6, -12.0)
		"facing":
			Sfx.play(&"boing", 0.9, -10.0)
		_:
			Sfx.play(&"ding", 1.2, -8.0)
	await _wait(0.4 if _reduced() else 1.2)
	var i := SEAT_IDS.find(id)
	if id != "back" and i >= 0:
		_dead[i] = true
		_buttons[i].disabled = true


func _set_hints(parts: Array) -> void:
	for c in _hints.get_children():
		c.queue_free()
	if not parts.is_empty():
		_hints.add_child(UiKit.hint_panel(parts, 16))


func _unhandled_input(event: InputEvent) -> void:
	if not _choosing or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k < KEY_1 or k > KEY_9:
		k = (event as InputEventKey).physical_keycode
	var i := -1
	if k >= KEY_1 and k <= KEY_9:
		i = k - KEY_1
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		i = k - KEY_KP_1
	if i >= 0 and i < _buttons.size() and _buttons[i].visible:
		_pick(i)
		get_viewport().set_input_as_handled()


## (coroutine) Fade the whole board away.
func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished


# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	_t += delta
	if _sat_t >= 0.0:
		_sat_t += delta
	_art.queue_redraw()
	for b: Button in _buttons:
		b.queue_redraw()


func _draw_seat_button(b: Button, i: int) -> void:
	var dead := _dead.has(i)
	var r := Rect2(Vector2.ZERO, BUTTON_SIZE)
	var col := Color("#e6e1d6") if dead else Palette.PAPER
	UiDraw.rounded_rect(b, r, col, 16, 3, Color(Palette.INK, 0.35) if dead else Palette.INK)
	if b.is_hovered() and not dead and _choosing:
		UiDraw.rounded_rect(b, r.grow(-5), Color(GLOW, 0.25), 12, 0)
	_badge(b, Vector2(26, BUTTON_SIZE.y * 0.5), i, dead)
	var l := b.find_child("Text", true, false) as Label
	if l != null:
		l.add_theme_color_override("font_color", Color(Palette.INK, 0.45) if dead else Palette.INK)


## A seat's number in a little disc: on its button and on its glow, so the map and the list match.
static func _badge(ci: CanvasItem, at: Vector2, i: int, dead: bool) -> void:
	ci.draw_circle(at, 14.0, Palette.INK)
	ci.draw_circle(at, 12.0, Color("#e6e1d6") if dead else GLOW)
	var f := UiKit.font(700)
	var n := str(i + 1)
	var tw := f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	ci.draw_string(f, at + Vector2(-tw * 0.5, 6.0), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.INK)


func _draw_art() -> void:
	var a := _art
	UiDraw.rounded_rect(a, MAP, FLOOR, 14, 6, WALL)
	var f := UiKit.font(700)
	# the bar along the bottom wall
	var bar := Rect2(MAP.position.x + 420, MAP.end.y - 44, 360, 34)
	UiDraw.rounded_rect(a, bar, Color("#a8743a"), 8, 2, WALL)
	_text(a, f, "BAR", bar.get_center() + Vector2(0, 7), 18, Palette.PAPER)
	# the kitchen's swing doors (they swing open when Marco sits beside them)
	var swing := 0.0
	if _sat == "kitchen" and not _reduced():
		swing = absf(sin(_sat_t * 6.0)) * 0.9 * clampf(2.0 - _sat_t, 0.0, 1.0)
	elif _sat == "kitchen":
		swing = 0.6
	for k in 2:
		var hinge := Vector2(KITCHEN_DOORS.end.x, KITCHEN_DOORS.position.y + (0.0 if k == 0 else KITCHEN_DOORS.size.y))
		var dir := Vector2(0, 1 if k == 0 else -1).rotated((-1.0 if k == 0 else 1.0) * swing)
		a.draw_line(hinge, hinge + dir * KITCHEN_DOORS.size.y * 0.5, WALL, 8.0)
	_text(a, f, "KITCHEN", Vector2(KITCHEN_DOORS.end.x + 52, KITCHEN_DOORS.position.y - 10), 16, WALL)
	# the music speaker on the top wall
	UiDraw.rounded_rect(a, Rect2(SPEAKER_AT - Vector2(34, 14), Vector2(68, 30)), Palette.INK, 6, 0)
	a.draw_circle(SPEAKER_AT + Vector2(-12, 1), 9.0, Color("#8d94a6"))
	a.draw_circle(SPEAKER_AT + Vector2(14, 1), 6.0, Color("#8d94a6"))
	_text(a, f, "MUSIC", SPEAKER_AT + Vector2(-82, 7), 15, Palette.INK_SOFT)
	# the busy tables: grey diners round each, little chatter marks
	for tc: Vector2 in TABLES:
		a.draw_circle(tc, 30.0, WALL)
		a.draw_circle(tc, 27.0, TABLE)
		for k in 4:
			var d := tc + Vector2.from_angle(PI * 0.25 + k * PI * 0.5) * 44.0
			a.draw_circle(d, 12.0, DINER)
		_text(a, UiKit.font(600), "blah", tc + Vector2(26, -36), 13, Color(Palette.INK, 0.35))
	# the corner booth: an L-shaped bench and its table, Marco's guest at the table
	UiDraw.rounded_rect(a, Rect2(BOOTH.position + Vector2(0, 0), Vector2(BOOTH.size.x, 26)), Color("#b5652a"), 8, 2, WALL)
	UiDraw.rounded_rect(a, Rect2(Vector2(BOOTH.end.x - 26, BOOTH.position.y), Vector2(26, BOOTH.size.y)), Color("#b5652a"), 8, 2, WALL)
	UiDraw.rounded_rect(a, Rect2(BOOTH_TABLE - Vector2(40, 40), Vector2(80, 80)), TABLE, 10, 3, WALL)
	_text(a, f, "CORNER BOOTH", Vector2(BOOTH.get_center().x - 20, BOOTH.end.y + 2), 15, WALL)
	var guest := _guest_at()
	UiDraw.heart(a, guest, 15.0, Color("#e5383b"))
	_text(a, UiKit.font(600), "guest", guest + Vector2(0, 30), 13, Palette.INK_SOFT)
	# the seats' glow (pulsing while choosing; steady with reduced motion)
	for i in SEAT_IDS.size():
		var id := SEAT_IDS[i]
		var at: Vector2 = SEAT_AT[id]
		if _dead.has(i):
			_badge(a, at, i, true)
			continue
		var pulse := 0.5 if _reduced() or not _choosing else 0.35 + 0.3 * sin(_t * 4.0 + i)
		a.draw_circle(at, 24.0, Color(GLOW, pulse))
		if _sat != id:
			_badge(a, at, i, false)
	if _sat != "":
		_draw_marco_seated(a, f)


## Where the guest sits: across the booth table from Marco (wall side unless he took it).
func _guest_at() -> Vector2:
	return SEAT_AT["back"] if _sat == "facing" else SEAT_AT["facing"]


## Marco from above in his seat, his mics' front half drawn as a bright wedge ahead of him, the
## back half dim behind; plus what the seat does to him.
func _draw_marco_seated(a: Control, f: Font) -> void:
	var at: Vector2 = SEAT_AT[_sat]
	var face: float = SEAT_FACE[_sat]
	var k := 1.0 if _reduced() else clampf(_sat_t / 0.4, 0.0, 1.0)
	var r := 150.0 * k
	var front := PackedVector2Array([at])
	var back := PackedVector2Array([at])
	for j in 25:
		front.append(at + Vector2.from_angle(face - PI * 0.5 + PI * j / 24.0) * r)
		back.append(at + Vector2.from_angle(face + PI * 0.5 + PI * j / 24.0) * r * 0.7)
	a.draw_colored_polygon(back, Color("#9aa0b0", 0.18))
	a.draw_colored_polygon(front, Color(GLOW, 0.35))
	a.draw_circle(at, 22.0, Palette.INK)
	a.draw_circle(at, 19.0, Color("#dfe3ea"))
	a.draw_colored_polygon(PackedVector2Array([at + Vector2.from_angle(face) * 30.0,
		at + Vector2.from_angle(face + 0.5) * 18.0, at + Vector2.from_angle(face - 0.5) * 18.0]), Color("#e9b48c"))
	match _sat:
		"kitchen":
			if _sat_t > 0.3:
				_pop_word(a, f, "CLANG!", at + Vector2(60, -60), Color("#d1433a"))
		"speaker":
			if _sat_t > 0.2:
				# the beat: slower than 3 flashes a second, still with reduced motion
				var on := _reduced() or fmod(_sat_t, 0.8) < 0.5
				if on:
					_pop_word(a, f, "UNTZ UNTZ", SPEAKER_AT + Vector2(110, 10), Palette.PLUM)
		"facing":
			if _sat_t > 0.3:
				_pop_word(a, f, "the whole room, in front", Vector2(760, 140), Palette.INK)
		"back":
			if _sat_t > 0.3:
				UiDraw.check(a, at + Vector2(-40, -40), 18.0, Color("#2f9e73"), 5.0)


func _pop_word(a: Control, f: Font, text: String, at: Vector2, col: Color) -> void:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var r := Rect2(at - Vector2(tw * 0.5 + 12.0, 22.0), Vector2(tw + 24.0, 38.0))
	UiDraw.rounded_rect(a, r, Palette.PAPER, 12, 3, col)
	a.draw_string(f, Vector2(r.position.x + 12.0, r.position.y + 28.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col)


static func _text(a: Control, f: Font, text: String, centre: Vector2, size: int, col: Color) -> void:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	a.draw_string(f, Vector2(centre.x - tw * 0.5, centre.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
