extends Control
## TargetMatch (Day 14, docs/FITTING.md §2): the real-ear graph. Frequency across, boost (insertion
## gain) up. The dashed line is the prescription target with a green zone (±ZONE_DB); the solid line
## is what the probe mic measures with the aid on. Three bands (MIDS 1k, HIGHS 2k, TOPS 4k): Left /
## Right picks one, Up / Down boosts it by STEP_DB (held keys repeat), Enter is Done once all three
## are in the green; with the mouse each band has + / - buttons, and a click on its column picks it.
## The "what Gus hears" strip drops the sounds of the bands not matched yet (heard()). A band
## OVER_DB or more over its target is an overshoot: Gus winces ("loud"), or at TOPS the open dome
## whistles ("whistle": feedback).
## Story-internal:
##   var g := TargetMatch.new(); hud.add_game(g)
##   g.setup("right", patient.get_thresholds("right"), line)
##   await g.run()                          # beat fitting_target; returns once Done
##   var r: Dictionary = g.result()         # {ear, bands, moves, par, overshoots, accuracy, efficiency}
##   await g.run_hoot("left", patient.get_thresholds("left"))   # Hoot matches the left ear (unscored)
## Signals: matched_changed(count) (the level colours the world), overshoot(kind) (first of each kind).
## The target is a public textbook formula (NAL-R, 1986) standing in for the fitting software's
## prescription; play never names it.

signal matched_changed(count: int)
signal overshoot(kind: String)
signal _finished

const UiKit := preload("res://story/ui_kit.gd")

## The bands the player tunes, low to high.
const BANDS: Array[int] = [1000, 2000, 4000]
const BAND_NAMES: Array[String] = ["MIDS", "HIGHS", "TOPS"]
const BAND_KHZ: Array[String] = ["1k", "2k", "4k"]
## The fitting software's first guess, dB under target per band (an average ear, short in the highs).
const START_UNDER: Array[int] = [6, 10, 14]
const STEP_DB := 2
const ZONE_DB := 5
## Within this of the target: a bullseye (full accuracy for the band).
const BULLSEYE_DB := 2
const OVER_DB := 6
const MAX_GAIN := 40
## NAL-R's correction k(f) per frequency (dB).
const NAL_K: Dictionary = {250: -17, 500: -8, 750: -3, 1000: 1, 1500: 1, 2000: -1, 3000: -2, 4000: -2, 6000: -2}
## The target line's points (Hz).
const CURVE_FREQS: Array[int] = [250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000]
## The sounds each band brings back in the strip, roughly after the familiar-sounds chart. Two-letter
## sounds are matched first, so "th" is one sound and "ck" one k.
const SOUNDS_BY_BAND: Array = [["ch", "sh"], ["ck", "k", "g", "p", "t"], ["th", "f", "s"]]
const LOUD_LINE := "Whoa! The fridge sounds like a jet engine!"
const WHISTLE_LINE := "Wheeeee! Is my ear... singing?"
const LOUD_TIP := "Over the target is too loud for Gus. Bring it back into the green."
const WHISTLE_TIP := "Too much top boost in an open dome whistles. That's feedback! Back it off."
const START_TIP := "Raise each band until the line sits in the green zone. Fewer moves, better golf!"

## Left of the fitting shot, so Gus (and the colour wave from his head) stays in view.
const PANEL := Rect2(14, 86, 620, 454)
const PLOT := Rect2(58, 128, 540, 156)
const F_MIN := 250.0
const F_MAX := 8000.0
const GREEN := Color("#5bc8a3")

var _ear := "right"
var _line := ""
var _targets: Array[int] = []
## The target line's values at CURVE_FREQS (dB).
var _tcurve: Array[float] = []
var _start: Array[int] = []
var _gains: Array[int] = []
var _matched: Array[bool] = [false, false, false]
var _sel := 0
var _moves := 0
var _last_band := -1
var _last_dir := 0
var _over_now: Array[bool] = [false, false, false]
var _overshoots: Array[String] = []
var _accepting := false
var _done := false
var _hoot := false
var _t := 0.0
var _say_t := 0.0
var _panel: Control
var _art: Control
var _strip: Label
var _bubble: Label
var _moves_label: Label
var _done_btn: Button
var _up: Array[Button] = []
var _down: Array[Button] = []
var _hints: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Control.new()
	_panel.position = PANEL.position
	_panel.size = PANEL.size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.gui_input.connect(_on_panel_input)
	add_child(_panel)
	_art = UiKit.full_rect()
	_art.draw.connect(_draw_panel)
	_panel.add_child(_art)
	_moves_label = UiKit.label("", 18, Palette.INK, 700)
	_moves_label.position = Vector2(PANEL.size.x - 200, 14)
	_moves_label.size = Vector2(180, 26)
	_moves_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_panel.add_child(_moves_label)
	_strip = UiKit.label("", 21, Palette.INK, 700)
	_strip.position = Vector2(22, 64)
	_strip.size = Vector2(PANEL.size.x - 44, 30)
	_strip.clip_text = true
	_panel.add_child(_strip)
	_bubble = UiKit.label("", 17, Palette.CORAL.darkened(0.25), 700)
	_bubble.position = Vector2(22, 93)
	_bubble.size = Vector2(PANEL.size.x - 44, 24)
	_panel.add_child(_bubble)
	for i in BANDS.size():
		var x := _band_x(i)
		var up := _arrow_button("+", Vector2(x + 4, 354))
		up.pressed.connect(_press.bind(i, 1))
		_up.append(up)
		var down := _arrow_button("-", Vector2(x - 46, 354))
		down.pressed.connect(_press.bind(i, -1))
		_down.append(down)
	_done_btn = UiKit.button("Done", &"AccentButton", Vector2(150, 42))
	_done_btn.position = Vector2(PANEL.size.x - 166, 404)
	_done_btn.disabled = true
	_done_btn.pressed.connect(_finish)
	_panel.add_child(_done_btn)
	visible = false


func _arrow_button(text: String, at: Vector2) -> Button:
	var b := UiKit.button(text, &"", Vector2(42, 38))
	b.position = at
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 26)
	_panel.add_child(b)
	return b


## The ear, its thresholds (Hz -> dB HL) and the line Doris says ("" hides the strip).
func setup(ear: String, thresholds: Dictionary, line: String = "") -> void:
	_ear = ear
	_line = line
	_targets = targets(thresholds)
	_tcurve.clear()
	for f: int in CURVE_FREQS:
		_tcurve.append(target_gain(thresholds, f))
	_start.clear()
	_gains.clear()
	for i in BANDS.size():
		_start.append(clampi(_targets[i] - START_UNDER[i], 0, MAX_GAIN))
		_gains.append(_start[i])
	_moves = 0
	_last_band = -1
	_last_dir = 0
	_sel = 0
	_over_now = [false, false, false]
	_refresh(false)


## (coroutine) The player matches the bands; returns after Done. Emits awaiting_input(fitting_target).
func run() -> void:
	visible = true
	_hoot = false
	Juice.bounce_in(_panel, 0.45)
	if UiKit.show_key_hints():
		_hints = UiKit.hint_panel(["Band", ["Left"], ["Right"], " Boost", ["Up"], ["Down"], " Done", ["Enter"]], 15)
		_hints.position = Vector2(PANEL.position.x + 16, PANEL.end.y - 50)
		add_child(_hints)
	Hoot.say(START_TIP, Hoot.NORMAL, "", "fitting_start")
	_accepting = true
	Events.awaiting_input.emit(&"fitting_target", {}, solve)
	if not _done:
		await _finished
	_accepting = false
	if _hints != null:
		_hints.queue_free()
		_hints = null


## (coroutine) Hoot matches this ear at Hoot speed: unscored, no input.
func run_hoot(ear: String, thresholds: Dictionary) -> void:
	_hoot = true   # first: Hoot's ear never re-greys the world (no matched_changed)
	_accepting = false
	setup(ear, thresholds, _line)
	_done_btn.visible = false
	for b: Button in _up + _down:
		b.disabled = true
	visible = true
	await get_tree().create_timer(0.5, false).timeout
	for i in BANDS.size():
		_sel = i
		var from := _gains[i]
		var t := create_tween()
		t.tween_method(func(v: float) -> void:
			_gains[i] = int(round(v))
			_refresh(true), float(from), float(_targets[i]), 0.45).set_trans(Tween.TRANS_SINE)
		await t.finished
	await get_tree().create_timer(0.4, false).timeout


## The bot's solver: each band straight to its target, one move each, then Done.
func solve() -> void:
	if not _accepting:
		return
	for i in BANDS.size():
		var guard := 0
		while absi(_gains[i] - _targets[i]) >= STEP_DB and guard < 40:
			_change(i, signi(_targets[i] - _gains[i]))
			guard += 1
	_finish()


func result() -> Dictionary:
	var bands: Array = []
	for i in BANDS.size():
		bands.append({"freq": BANDS[i], "target": _targets[i], "start": _start[i], "final": _gains[i], "err": _gains[i] - _targets[i]})
	return {"ear": _ear, "bands": bands, "moves": _moves, "par": par(), "overshoots": _overshoots.duplicate(),
		"accuracy": accuracy_of(_gains, _targets), "efficiency": efficiency(_moves, par())}


## Bands that start outside the green: each needs at least one move.
func par() -> int:
	var n := 0
	for i in BANDS.size():
		if absi(_start[i] - _targets[i]) > ZONE_DB:
			n += 1
	return n


func gains() -> Array[int]:
	return _gains.duplicate()


func band_targets() -> Array[int]:
	return _targets.duplicate()


func matched_count() -> int:
	return _matched.count(true)


## (bot, mouse) Presses this band needs to reach its target: + up, - down.
func presses_needed(i: int) -> int:
	return int(round(float(_targets[i] - _gains[i]) / float(STEP_DB)))


func arrow_button(i: int, up: bool) -> Button:
	return _up[i] if up else _down[i]


func done_button() -> Button:
	return _done_btn


# ---------------------------------------------------------------- the rules (static, tested)

## The prescription's insertion gain at freq (dB, never below 0): 0.31 H(f) + 0.05 (H500 + H1k + H2k) + k(f).
static func target_gain(th: Dictionary, freq: int) -> float:
	var x := 0.05 * float(int(th.get(500, 0)) + int(th.get(1000, 0)) + int(th.get(2000, 0)))
	return maxf(0.0, 0.31 * float(int(th.get(freq, 0))) + x + float(NAL_K.get(freq, 0)))


## The band targets, rounded to whole dB.
static func targets(th: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for f: int in BANDS:
		out.append(int(round(target_gain(th, f))))
	return out


static func in_zone(gain: int, target: int) -> bool:
	return absi(gain - target) <= ZONE_DB


## A band's accuracy: 1.0 within BULLSEYE_DB, then 0.05 less per dB (0.85 at the zone's edge), and
## 0.1 less per dB past it.
static func band_accuracy(err: int) -> float:
	var e := absi(err)
	if e <= BULLSEYE_DB:
		return 1.0
	if e <= ZONE_DB:
		return 1.0 - 0.05 * float(e - BULLSEYE_DB)
	return maxf(0.0, 0.85 - 0.1 * float(e - ZONE_DB))


static func accuracy_of(g: Array[int], t: Array[int]) -> float:
	var sum := 0.0
	for i in t.size():
		sum += band_accuracy(g[i] - t[i])
	return sum / float(maxi(1, t.size()))


## 1.0 at or under par, 0.12 less per extra move, never below 0.3.
static func efficiency(moves: int, p: int) -> float:
	return clampf(1.0 - 0.12 * float(moves - p), 0.3, 1.0)


## The line as Gus hears it: the sounds of the bands not matched yet become "_".
static func heard(line: String, matched: Array) -> String:
	var low := line.to_lower()
	var out := ""
	var i := 0
	while i < line.length():
		var took := 0
		for n: int in [2, 1]:
			if took > 0 or i + n > line.length():
				continue
			var piece := low.substr(i, n)
			for b in SOUNDS_BY_BAND.size():
				if (SOUNDS_BY_BAND[b] as Array).has(piece):
					out += line.substr(i, n) if bool(matched[b]) else "_"
					took = n
					break
		if took == 0:
			out += line[i]
			took = 1
		i += took
	return out


## The measured boost at any frequency from the three band gains: from 0 at 250 Hz up to MIDS at 1k
## (an open dome lets the lows in naturally), between the bands in log frequency, flat from 4k to 6k.
static func curve_at(f: float, g: Array[int]) -> float:
	var pts: Array[Vector2] = [Vector2(250, 0), Vector2(1000, g[0]), Vector2(2000, g[1]), Vector2(4000, g[2]), Vector2(6000, g[2])]
	if f <= pts[0].x:
		return pts[0].y
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		if f <= b.x:
			var u := log(f / a.x) / log(b.x / a.x)
			return lerpf(a.y, b.y, u)
	return pts[-1].y


# ---------------------------------------------------------------- input

func _press(i: int, dir: int) -> void:
	if not _accepting:
		return
	_sel = i
	_change(i, dir)


func _change(i: int, dir: int) -> void:
	var g := clampi(_gains[i] + dir * STEP_DB, 0, MAX_GAIN)
	if g == _gains[i]:
		return
	if i != _last_band or dir != _last_dir:
		_moves += 1
	_last_band = i
	_last_dir = dir
	_gains[i] = g
	Sfx.play(&"blip", 0.9 + 0.12 * float(g) / 10.0, -10.0)
	_refresh(true)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed():
		return
	if event.is_action_pressed(&"ui_up", true) or event.is_action_pressed(&"louder", true):
		_change(_sel, 1)
	elif event.is_action_pressed(&"ui_down", true) or event.is_action_pressed(&"softer", true):
		_change(_sel, -1)
	elif event.is_echo():
		return
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"freq_down"):
		_sel = maxi(0, _sel - 1)
		_art.queue_redraw()
	elif event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"freq_up"):
		_sel = mini(BANDS.size() - 1, _sel + 1)
		_art.queue_redraw()
	elif event.is_action_pressed(&"ui_accept"):
		_finish()
	else:
		return
	get_viewport().set_input_as_handled()


## A click in the plot or the band row picks the nearest band.
func _on_panel_input(ev: InputEvent) -> void:
	if not _accepting or not (ev is InputEventMouseButton) or not ev.pressed:
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or mb.position.y < PLOT.position.y:
		return
	var best := 0
	for i in BANDS.size():
		if absf(mb.position.x - _band_x(i)) < absf(mb.position.x - _band_x(best)):
			best = i
	_sel = best
	_art.queue_redraw()


func _finish() -> void:
	if not _accepting or _done or matched_count() < BANDS.size():
		return
	_done = true
	_accepting = false
	Sfx.play(&"ding", 1.2, -4.0)
	Events.input_resolved.emit(&"fitting_target")
	_finished.emit()


# ---------------------------------------------------------------- state and drawing

func _refresh(react: bool) -> void:
	var before := matched_count()
	for i in BANDS.size():
		var was := _matched[i]
		_matched[i] = in_zone(_gains[i], _targets[i])
		if react and _matched[i] and not was:
			Sfx.play(&"ding", 1.0 + 0.15 * float(i), -6.0)
			Juice.pop(_up[i], 1.15, 0.2)
		var over := _gains[i] - _targets[i] >= OVER_DB
		if react and over and not _over_now[i] and not _hoot:
			_on_over(i)
		_over_now[i] = over
	if _line != "":
		_strip.text = heard(_line, _matched)
	_moves_label.text = "" if _hoot else "Moves %d  ·  Par %d" % [_moves, par()]
	_done_btn.disabled = matched_count() < BANDS.size()
	if matched_count() != before and not _hoot:
		matched_changed.emit(matched_count())
	_art.queue_redraw()


func _on_over(i: int) -> void:
	var kind := "whistle" if i == BANDS.size() - 1 else "loud"
	if kind == "whistle":
		Sfx.play(&"squeak", 2.4, -8.0)
		_gus_says(WHISTLE_LINE)
	else:
		Sfx.play(&"boing", 0.7, -8.0)
		_gus_says(LOUD_LINE)
	Events.patient_reaction.emit(&"wince", {})
	if not _overshoots.has(kind):
		_overshoots.append(kind)
		Hoot.say(WHISTLE_TIP if kind == "whistle" else LOUD_TIP, Hoot.HIGH, "", "fitting_" + kind)
		overshoot.emit(kind)


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


func _band_x(i: int) -> float:
	return _fx(float(BANDS[i]))


func _fx(f: float) -> float:
	return PLOT.position.x + PLOT.size.x * log(f / F_MIN) / log(F_MAX / F_MIN)


func _gy(db: float) -> float:
	return PLOT.end.y - PLOT.size.y * clampf(db, 0.0, float(MAX_GAIN)) / float(MAX_GAIN)


func _draw_panel() -> void:
	var ci := _art
	var ear_col := Palette.RIGHT_RED if _ear == "right" else Palette.LEFT_BLUE
	var f := UiKit.font(700)
	var f5 := UiKit.font(500)
	UiDraw.rounded_rect(ci, Rect2(Vector2(0, 8), PANEL.size), Color(Palette.INK, 0.3), 22)
	UiDraw.rounded_rect(ci, Rect2(Vector2.ZERO, PANEL.size), Palette.PAPER, 22, 4, Palette.INK)
	ci.draw_circle(Vector2(30, 28), 9.0, ear_col)
	var title := "REAL-EAR CHECK  ·  %s EAR%s" % [_ear.to_upper(), "  ·  HOOT SPEED" if _hoot else ""]
	ci.draw_string(f, Vector2(48, 36), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	if _line != "":
		ci.draw_string(f5, Vector2(22, 64), "WHAT GUS HEARS", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	# the plot: grid, axes, the green zone, the dashed target, the measured line
	UiDraw.rounded_rect(ci, PLOT.grow(6), Color("#fffaf0"), 10, 2, Color(Palette.INK, 0.35))
	for db in range(0, MAX_GAIN + 1, 10):
		var y := _gy(db)
		ci.draw_line(Vector2(PLOT.position.x, y), Vector2(PLOT.end.x, y), Color(Palette.INK, 0.12), 1.0)
		ci.draw_string(f5, Vector2(PLOT.position.x - 30, y + 5), str(db), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	for pair: Array in [[250, "250"], [500, "500"], [1000, "1k"], [2000, "2k"], [4000, "4k"], [8000, "8k"]]:
		var x := _fx(float(pair[0]))
		ci.draw_line(Vector2(x, PLOT.position.y), Vector2(x, PLOT.end.y), Color(Palette.INK, 0.1), 1.0)
		ci.draw_string(f5, Vector2(x - 12, PLOT.end.y + 20), String(pair[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	ci.draw_string(f5, Vector2(PLOT.position.x + 8, PLOT.position.y + 16), "BOOST (dB)", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	if _targets.is_empty():
		return
	var th_pts := PackedVector2Array()
	var hi := PackedVector2Array()
	var lo := PackedVector2Array()
	for k in CURVE_FREQS.size():
		var x := _fx(float(CURVE_FREQS[k]))
		th_pts.append(Vector2(x, _gy(_tcurve[k])))
		hi.append(Vector2(x, _gy(_tcurve[k] + ZONE_DB)))
		lo.append(Vector2(x, _gy(maxf(0.0, _tcurve[k] - ZONE_DB))))
	var zone := hi.duplicate()
	for k in range(lo.size() - 1, -1, -1):
		zone.append(lo[k])
	ci.draw_colored_polygon(zone, Color(GREEN, 0.28))
	ci.draw_polyline(hi, Color(GREEN, 0.7), 2.0, true)
	ci.draw_polyline(lo, Color(GREEN, 0.7), 2.0, true)
	for k in th_pts.size() - 1:
		ci.draw_dashed_line(th_pts[k], th_pts[k + 1], Palette.INK, 3.0, 10.0)
	var line := PackedVector2Array()
	var steps := 48
	for s in steps + 1:
		var fr := F_MIN * pow(6000.0 / F_MIN, float(s) / float(steps))
		line.append(Vector2(_fx(fr), _gy(curve_at(fr, _gains))))
	ci.draw_polyline(line, Color(Palette.INK, 0.35), 8.0, true)
	ci.draw_polyline(line, ear_col, 5.0, true)
	ci.draw_string(f5, Vector2(PLOT.end.x - 150, PLOT.position.y + 16), "- - -  his target", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK)
	# the handles and the band row
	for i in BANDS.size():
		var x := _band_x(i)
		var p := Vector2(x, _gy(_gains[i]))
		var sel := i == _sel and not _hoot
		if sel:
			ci.draw_circle(p, 17.0 + 2.0 * sin(_t * 5.0), Color(Palette.SUNNY, 0.6))
		ci.draw_circle(p, 11.0, Palette.INK)
		ci.draw_circle(p, 8.0, Palette.PAPER if not _matched[i] else GREEN)
		var col_rect := Rect2(x - 51, 314, 102, 84)
		UiDraw.rounded_rect(ci, col_rect, Color(Palette.SUNNY, 0.35) if sel else Color(Palette.INK, 0.05), 12, 3 if sel else 0, Palette.INK)
		var name := "%s %s" % [BAND_NAMES[i], BAND_KHZ[i]]
		var w := f.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		ci.draw_string(f, Vector2(x - w * 0.5, 332), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
		var chip := _chip(i)
		var cw := f.get_string_size(String(chip[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		ci.draw_string(f, Vector2(x - cw * 0.5, 348), String(chip[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, chip[1] as Color)


## The band's status chip: [text, colour].
func _chip(i: int) -> Array:
	var err := _gains[i] - _targets[i]
	if err >= OVER_DB:
		return ["TOO MUCH", Palette.CORAL.darkened(0.2)]
	if absi(err) <= BULLSEYE_DB:
		return ["BULLSEYE", GREEN.darkened(0.35)]
	if absi(err) <= ZONE_DB:
		return ["MATCHED", GREEN.darkened(0.35)]
	return ["%d dB LOW" % (-err), Palette.INK_SOFT]
