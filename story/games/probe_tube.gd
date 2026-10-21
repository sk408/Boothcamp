extends Control
## ProbeTube (Day 14, docs/FITTING.md §1 beat 3): placing the real-ear probe tube. A cross-section of
## Gus's ear canal, the eardrum at the right; the thin tube slides in STEP_MM at a time. Its tip must
## sit within ZONE_MM of the eardrum before the aid goes in: too shallow and the high pitches read low
## (the mic sits in a dip in the sound, drawn live in the "what the probe mic reads" strip, which
## slides up the frequencies as the tube goes deeper); too deep touches the drum, and Gus says OW.
## Right / Up slides it in, Left / Down out, Enter locks it; with the mouse, the Out / In / Lock
## buttons.
## Story-internal:
##   var g := ProbeTube.new(); hud.add_game(g)
##   g.setup("right")
##   await g.run()                    # beat probe_tube; returns once the tube is locked in the zone
##   var r: Dictionary = g.result()   # {ear, depth, mistakes, shallow, touched}
## Signals: touched (the first touch only: the level takes a comfort point), mistake(kind) ("shallow"
## for a lock short of the zone, "touch" for the drum; every one counts).

signal touched
signal mistake(kind: String)
signal _finished

const UiKit := preload("res://story/ui_kit.gd")

## The canal's length from its opening to the eardrum, an adult's (mm).
const CANAL_MM := 25
## Where the tip starts: just inside the canal (mm from the eardrum).
const START_MM := 17
const STEP_MM := 3
## Lock anywhere from here to the drum (not touching): "within 5 mm of the eardrum".
const ZONE_MM := 5
## The furthest out the tube goes.
const MAX_MM := 20
## After a touch the tube springs back to here, one step outside the zone.
const RECOIL_MM := 8
## The speed of sound (mm/s): the tip sits in a dip at the quarter wavelength from the drum, c / 4d.
const SOUND_MM_S := 343000.0
const DIP_DB := 14.0
const TOUCH_LINE := "OW! That's my eardrum, not a doorbell!"
const SHALLOW_LINE := "Hoot, the tube's still waving at the door."
const START_TIP := "Slide the tube in until its tip sits within 5 mm of his eardrum, then lock it."
const SHALLOW_TIP := "Too shallow! The high pitches would read low. Slide it closer to the drum."
const TOUCH_TIP := "Never touch the eardrum! It hurts. Within 5 mm is close enough."

## Left of the fitting shot, like the target match, so Gus stays in view.
const PANEL := Rect2(14, 86, 620, 454)
## The canal: opening at the left, eardrum at the right (local to the panel).
const CANAL := Rect2(64, 112, 480, 80)
const MIC := Rect2(58, 296, 540, 60)
const F_MIN := 250.0
const F_MAX := 8000.0
const GREEN := Color("#5bc8a3")

var _ear := "right"
var _depth := START_MM
var _mistakes := 0
var _shallow := 0
var _touched := false
var _accepting := false
var _done := false
var _t := 0.0
var _say_t := 0.0
var _panel: Control
var _art: Control
var _bubble: Label
var _in_btn: Button
var _out_btn: Button
var _lock_btn: Button
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
	_out_btn = _button("< Out", &"", Vector2(290, 404), Vector2(96, 42))
	_out_btn.pressed.connect(_slide.bind(1))
	_in_btn = _button("In >", &"", Vector2(392, 404), Vector2(96, 42))
	_in_btn.pressed.connect(_slide.bind(-1))
	_lock_btn = _button("Lock it", &"AccentButton", Vector2(494, 404), Vector2(110, 42))
	_lock_btn.pressed.connect(_lock)
	visible = false


func _button(text: String, variation: StringName, at: Vector2, sz: Vector2) -> Button:
	var b := UiKit.button(text, variation, sz)
	b.position = at
	b.focus_mode = Control.FOCUS_NONE
	_panel.add_child(b)
	return b


func setup(ear: String) -> void:
	_ear = ear
	_depth = START_MM
	_mistakes = 0
	_shallow = 0
	_touched = false
	_art.queue_redraw()


## (coroutine) The player places the tube; returns once it is locked in the zone. Emits
## awaiting_input(probe_tube).
func run() -> void:
	visible = true
	Juice.bounce_in(_panel, 0.45)
	if UiKit.show_key_hints():
		_hints = UiKit.hint_panel(["Slide", ["Left"], ["Right"], " Lock", ["Enter"]], 15)
		_hints.position = Vector2(PANEL.position.x + 16, PANEL.end.y - 50)
		add_child(_hints)
	Hoot.say(START_TIP, Hoot.NORMAL, "", "probe_start")
	_accepting = true
	Events.awaiting_input.emit(&"probe_tube", {}, solve)
	if not _done:
		await _finished
	_accepting = false
	if _hints != null:
		_hints.queue_free()
		_hints = null


## The bot's solver: straight in to the zone, then lock.
func solve() -> void:
	if not _accepting:
		return
	while _depth > ZONE_MM:
		_slide(-1)
	_lock()


func result() -> Dictionary:
	return {"ear": _ear, "depth": _depth, "mistakes": _mistakes, "shallow": _shallow, "touched": _touched}


func depth() -> int:
	return _depth


## (bot, mouse) Clicks on In to reach the zone from here.
func presses_needed() -> int:
	return maxi(0, ceili(float(_depth - ZONE_MM) / float(STEP_MM)))


func in_button() -> Button:
	return _in_btn


func lock_button() -> Button:
	return _lock_btn


# ---------------------------------------------------------------- the rules (static, tested)

## "shallow", "zone" or "touch" for a tip this far from the eardrum (mm).
static func zone_of(mm: int) -> String:
	if mm <= 0:
		return "touch"
	return "zone" if mm <= ZONE_MM else "shallow"


## The frequency of the dip the probe mic sits in, a quarter wavelength from the drum (Hz).
static func dip_hz(mm: int) -> float:
	return SOUND_MM_S / (4.0 * float(maxi(1, mm)))


## How far off the probe mic reads at freq with the tip this far from the drum (dB, 0 or less): a dip
## centred on dip_hz(), its lower side reaching down toward the highs.
static func reading_error(mm: int, freq: float) -> float:
	var x := log(freq / dip_hz(mm)) / log(2.0)   # octaves from the dip
	return -DIP_DB * exp(-x * x / 0.18)


## Whether the strip shows the highs reading low (more than 2 dB down anywhere from 4k to 8k).
static func highs_read_low(mm: int) -> bool:
	for f: float in [4000.0, 6000.0, 8000.0]:
		if reading_error(mm, f) < -2.0:
			return true
	return false


# ---------------------------------------------------------------- input

## dir -1 slides the tube in (toward the drum), +1 out.
func _slide(dir: int) -> void:
	if not _accepting:
		return
	var d := clampi(_depth + dir * STEP_MM, -STEP_MM, MAX_MM)
	if d == _depth:
		return
	_depth = d
	Sfx.play(&"blip", 0.8 + 0.04 * float(MAX_MM - _depth), -12.0)
	if zone_of(_depth) == "touch":
		_on_touch()
	_art.queue_redraw()


func _on_touch() -> void:
	_mistakes += 1
	Sfx.play(&"boing", 0.8, -10.0)
	_gus_says(TOUCH_LINE)
	Events.patient_reaction.emit(&"startle", {})
	Juice.shake(_panel, 6.0, 0.3)
	_depth = RECOIL_MM
	mistake.emit("touch")
	if not _touched:
		_touched = true
		Hoot.say(TOUCH_TIP, Hoot.HIGH, "", "probe_touch")
		touched.emit()


func _lock() -> void:
	if not _accepting or _done:
		return
	if zone_of(_depth) == "shallow":
		_mistakes += 1
		_shallow += 1
		Sfx.play(&"error", 1.0, -10.0)
		_gus_says(SHALLOW_LINE)
		Hoot.say(SHALLOW_TIP, Hoot.HIGH, "", "probe_shallow")
		mistake.emit("shallow")
		return
	_done = true
	_accepting = false
	Sfx.play(&"ding", 1.2, -4.0)
	Events.input_resolved.emit(&"probe_tube")
	_finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed():
		return
	if event.is_action_pressed(&"ui_right", true) or event.is_action_pressed(&"ui_up", true):
		_slide(-1)
	elif event.is_action_pressed(&"ui_left", true) or event.is_action_pressed(&"ui_down", true):
		_slide(1)
	elif event.is_echo():
		return
	elif event.is_action_pressed(&"ui_accept"):
		_lock()
	else:
		return
	get_viewport().set_input_as_handled()


func _gus_says(text: String) -> void:
	_bubble.text = "Gus: " + text
	_say_t = 2.8
	Juice.pop(_bubble, 1.1, 0.25)


func _process(delta: float) -> void:
	_t += delta
	if _say_t > 0.0:
		_say_t -= delta
		if _say_t <= 0.0:
			_bubble.text = ""
	if visible:
		_art.queue_redraw()


# ---------------------------------------------------------------- drawing

## The x of a point this far from the drum (mm) in the canal drawing.
func _mx(mm: float) -> float:
	return CANAL.end.x - CANAL.size.x * mm / float(CANAL_MM)


func _fx(f: float) -> float:
	return MIC.position.x + MIC.size.x * log(f / F_MIN) / log(F_MAX / F_MIN)


func _draw_panel() -> void:
	var ci := _art
	var ear_col := Palette.RIGHT_RED if _ear == "right" else Palette.LEFT_BLUE
	var f := UiKit.font(700)
	var f5 := UiKit.font(500)
	UiDraw.rounded_rect(ci, Rect2(Vector2(0, 8), PANEL.size), Color(Palette.INK, 0.3), 22)
	UiDraw.rounded_rect(ci, Rect2(Vector2.ZERO, PANEL.size), Palette.PAPER, 22, 4, Palette.INK)
	ci.draw_circle(Vector2(30, 28), 9.0, ear_col)
	ci.draw_string(f, Vector2(48, 36), "PROBE TUBE  ·  %s EAR" % _ear.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	# the canal: skin walls, the green zone by the drum, the eardrum, the tube
	var mid := CANAL.get_center().y
	var wall := Palette.SKIN
	UiDraw.rounded_rect(ci, Rect2(CANAL.position.x - 40, CANAL.position.y - 26, CANAL.size.x + 64, CANAL.size.y + 52), wall, 26)
	UiDraw.rounded_rect(ci, Rect2(CANAL.position.x - 40, CANAL.position.y - 26, CANAL.size.x + 64, CANAL.size.y + 52), Color(0, 0, 0, 0), 26, 3, Palette.SKIN_SHADE)
	UiDraw.rounded_rect(ci, CANAL, Color("#fff6ea"), 30)
	var zone := Rect2(_mx(ZONE_MM), CANAL.position.y + 6, _mx(0.4) - _mx(ZONE_MM), CANAL.size.y - 12)
	UiDraw.rounded_rect(ci, zone, Color(GREEN, 0.3 + 0.08 * sin(_t * 4.0)), 10, 2, Color(GREEN, 0.8))
	var drum_x := _mx(0)
	ci.draw_line(Vector2(drum_x, CANAL.position.y + 4), Vector2(drum_x, CANAL.end.y - 4), Palette.SKIN_SHADE.darkened(0.2), 7.0, true)
	ci.draw_line(Vector2(drum_x, CANAL.position.y + 4), Vector2(drum_x, CANAL.end.y - 4), Color("#ffb3a7"), 4.0, true)
	ci.draw_string(f5, Vector2(drum_x - 36, CANAL.end.y + 44), "EARDRUM", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	ci.draw_string(f5, Vector2(CANAL.position.x - 30, CANAL.end.y + 44), "CANAL OPENING", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	ci.draw_string(f5, Vector2(zone.position.x - 2, CANAL.position.y - 6), "5 mm", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GREEN.darkened(0.35))
	var tip := Vector2(_mx(maxf(0.0, float(_depth))), mid + 8)
	ci.draw_line(Vector2(10, mid + 8), tip, Color(Palette.INK, 0.35), 7.0, true)
	ci.draw_line(Vector2(10, mid + 8), tip, Color("#e8f4ff"), 4.0, true)
	ci.draw_circle(tip, 5.0, Palette.INK)
	ci.draw_circle(tip, 3.0, ear_col)
	# the readout
	var z := zone_of(_depth)
	var chip: Array = {"shallow": ["TOO SHALLOW", Palette.INK_SOFT], "zone": ["IN THE ZONE", GREEN.darkened(0.35)], "touch": ["TOUCHING!", Palette.CORAL.darkened(0.2)]}[z]
	ci.draw_string(f, Vector2(22, 272), "%d mm to the eardrum" % maxi(0, _depth), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.INK)
	ci.draw_string(f, Vector2(300, 272), String(chip[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, chip[1] as Color)
	# what the probe mic reads: flat is right; a dip in the highs means the tip is too far out
	UiDraw.rounded_rect(ci, MIC.grow(6), Color("#fffaf0"), 10, 2, Color(Palette.INK, 0.35))
	ci.draw_string(f5, Vector2(MIC.position.x + 6, MIC.position.y + 14), "WHAT THE PROBE MIC READS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_SOFT)
	var base_y := MIC.position.y + 26.0
	ci.draw_dashed_line(Vector2(MIC.position.x, base_y), Vector2(MIC.end.x, base_y), Color(Palette.INK, 0.4), 2.0, 8.0)
	var pts := PackedVector2Array()
	var steps := 48
	for s in steps + 1:
		var fr := F_MIN * pow(F_MAX / F_MIN, float(s) / float(steps))
		var e := reading_error(maxi(1, _depth), fr)
		pts.append(Vector2(_fx(fr), base_y - e * (MIC.size.y - 30.0) / DIP_DB))
	ci.draw_polyline(pts, ear_col, 4.0, true)
	for pair: Array in [[500, "500"], [1000, "1k"], [2000, "2k"], [4000, "4k"], [8000, "8k"]]:
		var x := _fx(float(pair[0]))
		ci.draw_string(f5, Vector2(x - 12, MIC.end.y + 20), String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_SOFT)
	if z == "shallow" and highs_read_low(_depth):
		ci.draw_string(f, Vector2(MIC.end.x - 160, MIC.position.y + 14), "HIGHS READ LOW", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.CORAL.darkened(0.2))
