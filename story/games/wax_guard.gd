extends Control
## WaxGuard (Day 15 part 2, docs/TUNEUP.md §5): the listening check. Gus's right aid "went quiet on
## Tuesday". The panel shows the aid big, a listening tube on it and the sound coming through (weak and
## muffled). The player picks the part to check (Battery, Mic cover, Wax guard): a wrong part is fine
## and greyed; the wax guard shows its yellow plug. Then "Click in a new guard": the old one pops off,
## a clean white one clicks in, and the sound through the tube comes back clear.
## Story-internal:
##   var g := WaxGuard.new(); hud.add_game(g)
##   var part: String = await g.pick()     # beat wax_guard {step: "find"}; returns a PARTS id
##   g.mark_checked(part)                   # a wrong part: greyed
##   await g.swap()                         # beat wax_guard {step: "swap"}; the new guard clicks in
##   g.result()                             # {tries, wrong: [part ids]}
## The lines are Hoot lines or patient lines: 18 words or fewer.

signal _clicked(id: String)

const UiKit := preload("res://story/ui_kit.gd")

## [id, button label, the finding (Hoot), right]. The right part is the wax guard.
const PARTS: Array = [
	["battery", "Battery", "Battery's charged: ninety percent. Not that.", false],
	["mic", "Mic cover", "Mic cover's clean. The sound gets in fine.", false],
	["guard", "Wax guard", "There it is: the wax guard's plugged. Sound can't get out.", true],
]
const RIGHT_PART := "guard"
const SWAP_LABEL := "Click in a new guard"
const PANEL := Rect2(14, 86, 620, 454)
## The aid, big, in the panel (local coordinates).
const AID_AT := Vector2(200, 210)
const TIP_AT := Vector2(420, 250)
const BUTTON_Y := 372.0
const WAX := Color("#e0a640")
const AID := Color("#d9dde4")

var _tries := 0
var _wrong: Array[String] = []
var _found := false
var _swapped := false
var _swap_t := -1.0
var _accepting := ""
var _t := 0.0
var _panel: Control
var _art: Control
var _buttons: Array[Button] = []
var _swap_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Control.new()
	_panel.position = PANEL.position
	_panel.size = PANEL.size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_art = UiKit.full_rect()
	_art.draw.connect(_draw_panel)
	_panel.add_child(_art)
	for i in PARTS.size():
		var b := UiKit.button(String(PARTS[i][1]), &"", Vector2(180, 50))
		b.position = Vector2(22 + 196 * i, BUTTON_Y)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_click.bind(String(PARTS[i][0])))
		_panel.add_child(b)
		_buttons.append(b)
	_swap_btn = UiKit.button(SWAP_LABEL, &"", Vector2(300, 50))
	_swap_btn.position = Vector2(160, BUTTON_Y)
	_swap_btn.focus_mode = Control.FOCUS_NONE
	_swap_btn.pressed.connect(_click.bind("swap"))
	_swap_btn.visible = false
	_panel.add_child(_swap_btn)
	_set_enabled(false)
	Juice.bounce_in(_panel, 0.45)


## (coroutine) Waits for the part to check (beat wax_guard, step find) and returns its id.
func pick() -> String:
	_accepting = "find"
	_set_enabled(true)
	Events.awaiting_input.emit(&"wax_guard", {"step": "find"}, solve)
	var id: String = await _clicked
	return id


## (coroutine) Waits for "Click in a new guard" (beat wax_guard, step swap), then plays the swap.
func swap() -> void:
	for b in _buttons:
		b.visible = false
	_swap_btn.visible = true
	_accepting = "swap"
	_set_enabled(true)
	Events.awaiting_input.emit(&"wax_guard", {"step": "swap"}, solve)
	await _clicked
	_swap_t = 0.0
	Sfx.play(&"pop", 1.2, -10.0)
	await get_tree().create_timer(0.5, false).timeout
	_swapped = true
	Sfx.play(&"click", 1.0, -8.0)
	Sfx.play(&"ding", 1.3, -12.0)
	await get_tree().create_timer(0.7, false).timeout


## The bot's solver: the wax guard, then the swap.
func solve() -> void:
	_click(RIGHT_PART if _accepting == "find" else "swap")


func part_button(id: String) -> Button:
	return _swap_btn if id == "swap" else _buttons[part_index(id)]


static func part_index(id: String) -> int:
	for i in PARTS.size():
		if String(PARTS[i][0]) == id:
			return i
	return -1


static func finding(id: String) -> String:
	var i := part_index(id)
	return String(PARTS[i][2]) if i >= 0 else ""


static func is_right(id: String) -> bool:
	return id == RIGHT_PART


func mark_checked(id: String) -> void:
	_buttons[part_index(id)].disabled = true
	if not _wrong.has(id):
		_wrong.append(id)


func result() -> Dictionary:
	return {"tries": _tries, "wrong": _wrong.duplicate()}


func _set_enabled(on: bool) -> void:
	for i in _buttons.size():
		_buttons[i].disabled = not on or _wrong.has(String(PARTS[i][0])) or _found
	_swap_btn.disabled = not on


func _click(id: String) -> void:
	if _accepting == "" or (_accepting == "find" and (id == "swap" or _wrong.has(id))) or (_accepting == "swap" and id != "swap"):
		return
	if _accepting == "find":
		_tries += 1
		if is_right(id):
			_found = true
	_accepting = ""
	_set_enabled(false)
	Sfx.play(&"click", 0.9, -10.0)
	Events.input_resolved.emit(&"wax_guard")
	_clicked.emit(id)


func _process(delta: float) -> void:
	_t += delta
	if _swap_t >= 0.0:
		_swap_t += delta
	if visible:
		_art.queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_panel() -> void:
	var ci := _art
	var f := UiKit.font(700)
	UiDraw.rounded_rect(ci, Rect2(Vector2(0, 8), PANEL.size), Color(Palette.INK, 0.3), 22)
	UiDraw.rounded_rect(ci, Rect2(Vector2.ZERO, PANEL.size), Palette.PAPER, 22, 4, Palette.INK)
	ci.draw_string(f, Vector2(22, 36), "LISTENING CHECK  ·  RIGHT AID", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	UiDraw.rounded_rect(ci, Rect2(22, 56, 576, 296), Color("#eef6ff"), 16, 3, Palette.INK)
	_draw_aid(ci)
	_draw_tube_and_sound(ci, f)


func _draw_aid(ci: CanvasItem) -> void:
	var ink := Palette.INK
	# the case behind the ear, the wire, the receiver and its dome
	var pts := PackedVector2Array()
	for k in 24:
		var a := TAU * k / 24.0
		pts.append(AID_AT + Vector2(cos(a) * 46.0, sin(a) * 96.0).rotated(0.35))
	ci.draw_colored_polygon(pts, AID)
	pts.append(pts[0])
	ci.draw_polyline(pts, ink, 4.0, true)
	ci.draw_circle(AID_AT + Vector2(-10, -60), 5.0, ink)
	var wire := PackedVector2Array()
	for k in 13:
		var u := k / 12.0
		var a := AID_AT + Vector2(30, -80)
		var b := TIP_AT + Vector2(-46, 0)
		wire.append(a.lerp(b, u) + Vector2(0, -sin(u * PI) * 70.0))
	ci.draw_polyline(wire, Color("#9aa3b0"), 6.0, true)
	UiDraw.rounded_rect(ci, Rect2(TIP_AT + Vector2(-50, -18), Vector2(52, 36)), AID, 10, 4, ink)
	# the wax guard at the tip: plugged (yellow wax) until swapped, a clean white one after
	var off := Vector2.ZERO
	if _swap_t >= 0.0 and not _swapped:
		off = Vector2(60, -80) * clampf(_swap_t / 0.5, 0.0, 1.0)
	var g := TIP_AT + Vector2(10, 0)
	if not _swapped:
		ci.draw_circle(g + off, 15.0, ink)
		ci.draw_circle(g + off, 12.0, Palette.PAPER)
		ci.draw_circle(g + off, 9.0, WAX if _found else Color("#f4e6c8"))
		if _found and off == Vector2.ZERO:
			ci.draw_arc(g, 26.0 + sin(_t * 6.0) * 3.0, 0.0, TAU, 24, Palette.CORAL, 4.0, true)
	else:
		var k := clampf((_swap_t - 0.5) / 0.25, 0.0, 1.0)
		ci.draw_circle(g + Vector2(30 * (1.0 - k), 0), 15.0, ink)
		ci.draw_circle(g + Vector2(30 * (1.0 - k), 0), 12.0, Palette.PAPER)
		ci.draw_circle(g, 6.0, Color("#ffffff"))
	# the open dome over the tip
	ci.draw_arc(TIP_AT + Vector2(26, 0), 22.0, -PI * 0.5, PI * 0.5, 14, Color(ink, 0.6), 4.0, true)


func _draw_tube_and_sound(ci: CanvasItem, f: Font) -> void:
	# the listening tube from the dome up to a little earpiece
	var a := TIP_AT + Vector2(48, 0)
	var b := Vector2(540, 110)
	var tube := PackedVector2Array()
	for k in 13:
		var u := k / 12.0
		tube.append(a.lerp(b, u) + Vector2(sin(u * PI) * 40.0, 0))
	ci.draw_polyline(tube, Color("#7fb3e0"), 8.0, true)
	ci.draw_circle(b, 16.0, Palette.INK)
	ci.draw_circle(b, 12.0, Color("#7fb3e0"))
	var clear := _swapped
	var col := Palette.MINT.darkened(0.15) if clear else Color(Palette.INK, 0.3)
	for k in 3:
		var r := 22.0 + 14.0 * k + fmod(_t * 20.0, 14.0)
		ci.draw_arc(b + Vector2(0, 0), r, -PI * 0.9, -PI * 0.3, 10, col, 5.0 if clear else 3.0, true)
	var word := "CLEAR!" if clear else "mmf... mmf..."
	var c := Palette.MINT.darkened(0.3) if clear else Palette.INK_SOFT
	ci.draw_string(f, Vector2(420, 84), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 22 if clear else 18, c)
