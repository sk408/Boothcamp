extends Control
## LoudCheck (Day 14, docs/FITTING.md §1 beat 5): the loud-sound check. The aid's LOUD LIMIT (its
## output limit) is a dial with NOTCHES notches; Doris drops a pan and a meter shows how the clang
## lands for Gus. Loud sounds must be loud but never painful: too high a limit stings or hurts (OUCH),
## too low squashes every loud sound flat (SQUASHED). The software's first guess (START_NOTCH) stings
## on the first drop, which plays by itself; then Left / Right (or Down / Up) turn the dial and Enter
## drops the pan again, until it lands JUST RIGHT (RIGHT_NOTCH). Mouse: the - / + / Drop buttons.
## The clang always plays at the same quiet level: how loud it is for Gus is only drawn (AudioSafety:
## never play a loud sound to make a joke).
## Story-internal:
##   var g := LoudCheck.new(); hud.add_game(g)
##   await g.run()                    # beat loud_check; returns once a drop lands just right
##   var r: Dictionary = g.result()   # {notch, drops, squashed, ouch}
## Signals: ouch (the first painful drop only: the level takes a comfort point), dropped(notch).

signal ouch
signal dropped(notch: int)
signal _finished

const UiKit := preload("res://story/ui_kit.gd")

const NOTCHES := 5
const START_NOTCH := 4
const RIGHT_NOTCH := 3
## How loud the clang lands for Gus at each notch, 0..1 on the meter.
const READING: Array[float] = [0.3, 0.5, 0.71, 0.87, 0.98]
## The meter's zones: SQUASHED below SQUASH_TOP, JUST RIGHT up to OUCH_FROM, OUCH above.
const SQUASH_TOP := 0.6
const OUCH_FROM := 0.8
## What Gus says about each notch's clang.
const LINES: Array[String] = [
	"Was that a pan or a pillow?",
	"Hmm. Sounds like a pan full of socks.",
	"CLANG! Loud... but fine. Now THAT's a pan.",
	"Ooh! That one stings a bit.",
	"YOWCH! My fillings rattled!",
]
const START_TIP := "Loud should be loud, never painful. Turn the limit down and drop it again."
const SQUASH_TIP := "Too low squashes loud sounds flat. Go for loud but comfortable."
const OUCH_TIP := "Never above his comfort! Loud sounds must not hurt. Turn the limit down."

## Left of the fitting shot, like the target match, so Gus stays in view.
const PANEL := Rect2(14, 86, 620, 454)
const DIAL_C := Vector2(150, 290)
const DIAL_R := 96.0
## The dial's sweep, notch 1 to notch NOTCHES (radians, screen angles: up is -PI/2).
const DIAL_FROM := PI * 1.15
const DIAL_TO := PI * 1.85
const METER := Rect2(476, 96, 40, 258)
const PAN_C := Vector2(350, 210)
const GREEN := Color("#5bc8a3")

var _notch := START_NOTCH
var _drops := 0
var _squashed := 0
var _ouch := false
var _accepting := false
var _done := false
var _reading := 0.0
var _shown := 0.0
var _wobble := 0.0
var _t := 0.0
var _say_t := 0.0
var _panel: Control
var _art: Control
var _bubble: Label
var _minus: Button
var _plus: Button
var _drop_btn: Button
var _hints: Control


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
	_bubble = UiKit.label("", 17, Palette.CORAL.darkened(0.25), 700)
	_bubble.position = Vector2(22, 54)
	_bubble.size = Vector2(PANEL.size.x - 44, 24)
	_panel.add_child(_bubble)
	_minus = _button("-", &"", Vector2(290, 404), Vector2(60, 42))
	_minus.add_theme_font_size_override("font_size", 26)
	_minus.pressed.connect(_turn.bind(-1))
	_plus = _button("+", &"", Vector2(356, 404), Vector2(60, 42))
	_plus.add_theme_font_size_override("font_size", 26)
	_plus.pressed.connect(_turn.bind(1))
	_drop_btn = _button("Drop the pan", &"AccentButton", Vector2(424, 404), Vector2(180, 42))
	_drop_btn.pressed.connect(_drop)
	visible = false


func _button(text: String, variation: StringName, at: Vector2, sz: Vector2) -> Button:
	var b := UiKit.button(text, variation, sz)
	b.position = at
	b.focus_mode = Control.FOCUS_NONE
	_panel.add_child(b)
	return b


## (coroutine) The first drop plays by itself at the software's first guess; then the player turns the
## dial and drops until a clang lands just right. Emits awaiting_input(loud_check).
func run() -> void:
	visible = true
	Juice.bounce_in(_panel, 0.45)
	await get_tree().create_timer(0.8, false).timeout
	_clang()
	Hoot.say(START_TIP, Hoot.NORMAL, "", "loud_start")
	if UiKit.show_key_hints():
		_hints = UiKit.hint_panel(["Limit", ["Left"], ["Right"], " Drop", ["Enter"]], 15)
		_hints.position = Vector2(PANEL.position.x + 16, PANEL.end.y - 50)
		add_child(_hints)
	_accepting = true
	Events.awaiting_input.emit(&"loud_check", {}, solve)
	if not _done:
		await _finished
	_accepting = false
	if _hints != null:
		_hints.queue_free()
		_hints = null


## The bot's solver: the dial straight to the right notch, then one drop.
func solve() -> void:
	if not _accepting:
		return
	while _notch != RIGHT_NOTCH:
		_turn(signi(RIGHT_NOTCH - _notch))
	_drop()


func result() -> Dictionary:
	return {"notch": _notch, "drops": _drops, "squashed": _squashed, "ouch": _ouch}


func notch() -> int:
	return _notch


## (bot, mouse) Turns to the right notch: + up, - down.
func presses_needed() -> int:
	return RIGHT_NOTCH - _notch


func turn_button(up: bool) -> Button:
	return _plus if up else _minus


func drop_button() -> Button:
	return _drop_btn


# ---------------------------------------------------------------- the rules (static, tested)

## "squashed", "right" or "ouch" for a drop at this notch.
static func verdict(n: int) -> String:
	var r := READING[clampi(n, 1, NOTCHES) - 1]
	if r >= OUCH_FROM:
		return "ouch"
	return "right" if r >= SQUASH_TOP else "squashed"


# ---------------------------------------------------------------- input

func _turn(dir: int) -> void:
	if not _accepting:
		return
	var n := clampi(_notch + dir, 1, NOTCHES)
	if n == _notch:
		return
	_notch = n
	Sfx.play(&"click", 0.8 + 0.1 * float(n), -10.0)
	_art.queue_redraw()


## The player's drop: counts, and a clang that lands just right finishes the check.
func _drop() -> void:
	if not _accepting or _done:
		return
	_drops += 1
	var v := _clang()
	match v:
		"squashed":
			_squashed += 1
			Hoot.say(SQUASH_TIP, Hoot.HIGH, "", "loud_squash")
		"ouch":
			if _notch == NOTCHES and not _ouch:
				_ouch = true
				Hoot.say(OUCH_TIP, Hoot.HIGH, "", "loud_ouch")
				ouch.emit()
		"right":
			_done = true
			_accepting = false
			Sfx.play(&"ding", 1.2, -4.0)
			Events.input_resolved.emit(&"loud_check")
			_finished.emit()


## Drops the pan at the current notch: the clang (always quiet), the meter, Gus's line. Returns the verdict.
func _clang() -> String:
	var v := verdict(_notch)
	_reading = READING[_notch - 1]
	_wobble = 1.0
	Sfx.play(&"thunk", 0.7, -12.0)
	Sfx.play(&"ding", 0.55, -14.0)
	_gus_says(LINES[_notch - 1])
	Events.patient_reaction.emit({"ouch": &"wince", "squashed": &"confused", "right": &"nod"}[v], {})
	if v == "ouch":
		Juice.shake(_panel, 4.0 + 4.0 * float(_notch - RIGHT_NOTCH), 0.3)
	dropped.emit(_notch)
	return v


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_up"):
		_turn(1)
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_down"):
		_turn(-1)
	elif event.is_action_pressed(&"ui_accept"):
		_drop()
	else:
		return
	get_viewport().set_input_as_handled()


func _gus_says(text: String) -> void:
	_bubble.text = "Gus: " + text
	_say_t = 2.8
	Juice.pop(_bubble, 1.1, 0.25)


func _process(delta: float) -> void:
	_t += delta
	_shown = move_toward(_shown, _reading, delta * 2.5)
	_wobble = maxf(0.0, _wobble - delta * 1.6)
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t <= 0.0:
			_bubble.text = ""
	if visible:
		_art.queue_redraw()


# ---------------------------------------------------------------- drawing

func _notch_angle(n: float) -> float:
	return lerpf(DIAL_FROM, DIAL_TO, (n - 1.0) / float(NOTCHES - 1))


func _meter_y(v: float) -> float:
	return METER.end.y - METER.size.y * clampf(v, 0.0, 1.0)


func _draw_panel() -> void:
	var ci := _art
	var f := UiKit.font(700)
	var f5 := UiKit.font(500)
	UiDraw.rounded_rect(ci, Rect2(Vector2(0, 8), PANEL.size), Color(Palette.INK, 0.3), 22)
	UiDraw.rounded_rect(ci, Rect2(Vector2.ZERO, PANEL.size), Palette.PAPER, 22, 4, Palette.INK)
	ci.draw_string(f, Vector2(22, 36), "LOUD-SOUND CHECK  ·  BOTH AIDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	# the dial
	ci.draw_circle(DIAL_C, DIAL_R + 14.0, Color(Palette.INK, 0.08))
	ci.draw_arc(DIAL_C, DIAL_R, DIAL_FROM - 0.12, DIAL_TO + 0.12, 40, Palette.INK, 6.0, true)
	for n in range(1, NOTCHES + 1):
		var a := _notch_angle(float(n))
		var dir := Vector2(cos(a), sin(a))
		var col: Color = {"squashed": Palette.INK_SOFT, "right": GREEN.darkened(0.3), "ouch": Palette.CORAL.darkened(0.2)}[verdict(n)]
		ci.draw_line(DIAL_C + dir * (DIAL_R - 14.0), DIAL_C + dir * (DIAL_R + 6.0), col, 5.0, true)
		var label := str(n)
		var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		ci.draw_string(f, DIAL_C + dir * (DIAL_R + 28.0) + Vector2(-w * 0.5, 8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.INK)
	var na := _notch_angle(float(_notch))
	var tip := DIAL_C + Vector2(cos(na), sin(na)) * (DIAL_R - 22.0)
	ci.draw_line(DIAL_C, tip, Palette.INK, 9.0, true)
	ci.draw_line(DIAL_C, tip, Palette.SUNNY, 5.0, true)
	ci.draw_circle(DIAL_C, 16.0, Palette.INK)
	ci.draw_circle(DIAL_C, 11.0, Palette.SUNNY)
	var cap := "LOUD LIMIT: %d" % _notch
	var cw := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	ci.draw_string(f, Vector2(DIAL_C.x - cw * 0.5, DIAL_C.y + 52), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	# the pan, wobbling after a drop
	var rot := sin(_t * 26.0) * 0.18 * _wobble
	ci.draw_set_transform(PAN_C, rot, Vector2.ONE)
	ci.draw_line(Vector2(40, 0), Vector2(100, -8), Palette.INK, 14.0, true)
	ci.draw_line(Vector2(40, 0), Vector2(100, -8), Palette.WOOD, 9.0, true)
	ci.draw_circle(Vector2.ZERO, 54.0, Palette.INK)
	ci.draw_circle(Vector2.ZERO, 49.0, Color("#9aa3ad"))
	ci.draw_circle(Vector2(-6, -6), 34.0, Color("#c3cad1"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _wobble > 0.0:
		for k in 3:
			var r := 70.0 + 16.0 * float(k) + 30.0 * (1.0 - _wobble)
			ci.draw_arc(PAN_C, r, -0.6, 0.6, 12, Color(Palette.INK, 0.5 * _wobble), 3.0, true)
			ci.draw_arc(PAN_C, r, PI - 0.6, PI + 0.6, 12, Color(Palette.INK, 0.5 * _wobble), 3.0, true)
	ci.draw_string(f5, Vector2(PAN_C.x - 46, PAN_C.y + 84), "DORIS'S PAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	# the meter: how loud the clang lands for Gus
	UiDraw.rounded_rect(ci, METER.grow(4), Palette.PAPER, 10, 3, Palette.INK)
	var zones: Array = [[0.0, SQUASH_TOP, Color(Palette.INK_SOFT, 0.18), "SQUASHED"], [SQUASH_TOP, OUCH_FROM, Color(GREEN, 0.35), "JUST RIGHT"], [OUCH_FROM, 1.0, Color(Palette.CORAL, 0.3), "OUCH"]]
	for z: Array in zones:
		var top := _meter_y(float(z[1]))
		var bottom := _meter_y(float(z[0]))
		ci.draw_rect(Rect2(METER.position.x, top, METER.size.x, bottom - top), z[2] as Color)
		ci.draw_string(f, Vector2(METER.end.x + 10, (top + bottom) * 0.5 + 5), String(z[3]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.INK_SOFT)
	if _shown > 0.0:
		var y := _meter_y(_shown)
		ci.draw_rect(Rect2(METER.position.x + 10, y, METER.size.x - 20, METER.end.y - y), Palette.INK)
		ci.draw_line(Vector2(METER.position.x - 4, y), Vector2(METER.end.x + 4, y), Palette.SUNNY, 4.0)
	ci.draw_string(f5, Vector2(METER.position.x - 8, METER.end.y + 22), "FOR GUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
