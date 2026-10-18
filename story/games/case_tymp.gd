extends Control
## CaseTymp (cases): the Tymp-O-Matic, a chunky cartoon tympanometer (docs/CASES.md §5).
## It seals the ear canal, sweeps the air pressure from +200 to -400 daPa and draws how easily the
## eardrum moves: a peak where it moves best. The shaded box is the normal range.
## The level asks the questions (DialogueBox.choose); this only shows the device. It sits in the top
## part of the screen, so the dialogue choices fit underneath.
## Story-internal:
##   var g := CaseTymp.new(); hud.add_game(g)
##   g.show_tips(&"medium")              # the ear-tip tray (the patient's right size, for the gag)
##   await g.try_tip(&"small")           # the leak / too-big / pop gag; returns true when it seals
##   await g.measure("right", data)      # the sweep: the curve draws itself, the readouts fill in
##   g.reveal_type("right")              # the type badge (after the quiz); a flat (B) ear also gets
##                                       # a ribbon reading its canal volume ("... = BLOCKED")
## data: {"type", "peak_daPa", "peak_ml", "ecv_ml"} as in a case file. ecv_ml (the canal volume) also
## gives the readout's chip (CaseRules.ecv_band: TINY / LOW / NORMAL / LARGE).
## Anchor: "tymp_screen".

const UiKit := preload("res://story/ui_kit.gd")
## Sits between the step tracker (top) and the dialogue choices (they stack up from y ~344).
const DEVICE := Rect2(240, 84, 800, 262)
const SCREEN := Rect2(268, 106, 520, 222)
const PLOT_PAD := Vector2(46, 22)     # room for the axis labels inside the screen
const Y_MAX_ML := 2.0
const SWEEP_S := 1.8
const LCD := Color("#1d2b33")
const LCD_GRID := Color("#2f4652")
const LCD_TEXT := Color("#d7f5ee")
const BODY := Color("#ffd166")
const TIP_COLORS: Dictionary = {&"small": Color("#7bdff2"), &"medium": Color("#b2f7ef"), &"large": Color("#f7d6e0")}
## Canal volume bands (CaseRules.ecv_band): the chip's word and colour, and what a flat line means with it.
const ECV_WORDS: Dictionary = {&"tiny": "TINY", &"low": "LOW", &"normal": "NORMAL", &"large": "LARGE"}
const ECV_COLORS: Dictionary = {&"tiny": Palette.CORAL, &"low": Palette.SELECT_ORANGE, &"normal": Palette.MINT, &"large": Palette.SKY}
const FLAT_READINGS: Dictionary = {
	&"tiny": "FLAT + TINY CANAL = BLOCKED", &"low": "FLAT + LOW CANAL = LOOK AGAIN",
	&"normal": "FLAT + NORMAL CANAL = FLUID?", &"large": "FLAT + BIG CANAL = HOLE?",
}
const RIBBON_GAP := 40.0          # px between stacked ribbons (both ears flat)

var _curves: Dictionary = {}      # ear -> {"data": Dictionary, "k": 0..1 drawn so far}
var _revealed: Dictionary = {}    # ear -> true once the type badge is shown
var _ribbons: Dictionary = {}     # ear -> {"row": stack slot, "k": 0..1 popped in}: flat ears, after the quiz
var _tips_visible := false
var _right_tip: StringName = &"medium"
var _tip: StringName = &""        # the tip on the probe
var _sealed := false
var _gag := ""                    # "leak", "big", "seal": the current callout
var _gag_t := -1.0
var _t := 0.0
var _canvas: Control
var _anchor: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UiKit.full_rect()
	_canvas.draw.connect(_draw_device)
	add_child(_canvas)
	_anchor = Control.new()
	_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor.position = SCREEN.position
	_anchor.size = SCREEN.size
	add_child(_anchor)
	Hoot.register_anchor("tymp_screen", _anchor)
	Juice.bounce_in(_canvas, 0.4)
	Sfx.play(&"whoosh", 1.1, -8.0)


func _exit_tree() -> void:
	Hoot.unregister_anchor("tymp_screen")


func _process(delta: float) -> void:
	_t += delta
	if _gag_t >= 0.0:
		_gag_t += delta
	_canvas.queue_redraw()


## Show the three ear tips. right_tip is the size that seals for this patient.
func show_tips(right_tip: StringName) -> void:
	_right_tip = right_tip
	_tips_visible = true
	Sfx.play(&"pop", 1.3, -8.0)


## (coroutine) Put a tip on the probe and try the seal. Returns true when it seals.
func try_tip(size: StringName) -> bool:
	_tip = size
	var ok := size == _right_tip
	var too_small := CaseRules.TIP_SIZES.find(size) < CaseRules.TIP_SIZES.find(_right_tip)
	_gag = "seal" if ok else ("leak" if too_small else "big")
	_gag_t = 0.0
	match _gag:
		"seal":
			Sfx.play(&"pop", 0.9, -4.0)
		"leak":
			Sfx.play(&"whoosh", 1.6, -10.0)
		_:
			Sfx.play(&"boing", 1.0, -8.0)
	await get_tree().create_timer(1.1, false).timeout
	if ok:
		_sealed = true
		_tips_visible = false
	else:
		_tip = &""
	_gag = ""
	_gag_t = -1.0
	return ok


## (coroutine) Sweep one ear: the curve draws from +200 to -400 daPa, then the readouts fill in.
func measure(ear: String, data: Dictionary) -> void:
	_curves[ear] = {"data": data, "k": 0.0}
	Sfx.play(&"squeak", 0.8, -12.0)
	var t := create_tween()
	t.tween_method(func(k: float) -> void: (_curves[ear] as Dictionary)["k"] = k, 0.0, 1.0, SWEEP_S)
	await t.finished
	Sfx.play(&"ding", 1.3 if ear == "right" else 1.1, -8.0)
	await get_tree().create_timer(0.3, false).timeout


## The type badge on an ear's readout (after the player names it).
func reveal_type(ear: String) -> void:
	_revealed[ear] = true
	Sfx.play(&"stamp", 1.4, -10.0)
	_pop_ribbon(ear)


## A flat (type B) ear's ribbon: what the flat line means with this canal volume. Only from
## reveal_type, so it never gives the quiz away. A second flat ear stacks under the first.
func _pop_ribbon(ear: String) -> void:
	if _ribbons.has(ear) or not _curves.has(ear):
		return
	var d: Dictionary = (_curves[ear] as Dictionary)["data"]
	if String(d.get("type", "")) != "B" or not d.has("ecv_ml"):
		return
	var row := _ribbons.size()
	_ribbons[ear] = {"row": row, "k": 0.0}
	var t := create_tween()
	t.tween_interval(0.15 + 0.2 * row)    # just after the stamp; the second ribbon a beat later
	t.tween_callback(func() -> void: Sfx.play(&"pop", 1.2 - 0.1 * row, -8.0))
	t.tween_method(func(k: float) -> void: (_ribbons[ear] as Dictionary)["k"] = k, 0.0, 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func is_sealed() -> bool:
	return _sealed


# ---------------------------------------------------------------- drawing

func _p2x(p: float) -> float:
	var plot := _plot()
	return plot.position.x + (p - CaseRules.TYMP_SWEEP_TO) / float(CaseRules.TYMP_SWEEP_FROM - CaseRules.TYMP_SWEEP_TO) * plot.size.x


func _ml2y(ml: float) -> float:
	var plot := _plot()
	return plot.end.y - clampf(ml, 0.0, Y_MAX_ML) / Y_MAX_ML * plot.size.y


func _plot() -> Rect2:
	return Rect2(SCREEN.position + Vector2(PLOT_PAD.x, 12), SCREEN.size - Vector2(PLOT_PAD.x + 14, 12 + PLOT_PAD.y + 8))


func _draw_device() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var fr := UiKit.font(600)
	# body + handle
	UiDraw.rounded_rect(c, Rect2(DEVICE.position + Vector2(0, 8), DEVICE.size), Color(Palette.INK, 0.2), 30)
	UiDraw.rounded_rect(c, DEVICE, BODY, 30, 4, Palette.INK)
	c.draw_string(f, DEVICE.position + Vector2(30, 20), "TYMP-O-MATIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
	# the printed canal-volume norm, above the screen's right end (the readout chips are read against it)
	var norm := "Adult canal: about %.1f-%.1f mL" % [CaseRules.TYMP_ADULT_ECV.x, CaseRules.TYMP_ADULT_ECV.y]
	c.draw_string(fr, Vector2(SCREEN.end.x - 240, DEVICE.position.y + 20), norm, HORIZONTAL_ALIGNMENT_RIGHT, 220, 12, Palette.INK_SOFT)
	# the screen
	UiDraw.rounded_rect(c, SCREEN, LCD, 14, 4, Palette.INK)
	var plot := _plot()
	var nb := Rect2(Vector2(_p2x(CaseRules.TYMP_NORMAL_PRESSURE.x), _ml2y(CaseRules.TYMP_NORMAL_PEAK.y)),
		Vector2(_p2x(CaseRules.TYMP_NORMAL_PRESSURE.y) - _p2x(CaseRules.TYMP_NORMAL_PRESSURE.x), _ml2y(CaseRules.TYMP_NORMAL_PEAK.x) - _ml2y(CaseRules.TYMP_NORMAL_PEAK.y)))
	c.draw_rect(nb, Color(Palette.MINT, 0.22))
	c.draw_rect(nb, Color(Palette.MINT, 0.7), false, 2.0)
	c.draw_string(fr, nb.position + Vector2(4, 14), "normal", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Palette.MINT, 0.9))
	for p: int in [-400, -300, -200, -100, 0, 100, 200]:
		var x := _p2x(p)
		c.draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), LCD_GRID, 1.0)
		var s := ("+%d" % p) if p > 0 else str(p)
		c.draw_string(fr, Vector2(x - 14, plot.end.y + 16), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LCD_TEXT)
	for ml: float in [0.0, 0.5, 1.0, 1.5, 2.0]:
		var y := _ml2y(ml)
		c.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), LCD_GRID, 1.0)
		c.draw_string(fr, Vector2(SCREEN.position.x + 8, y + 4), "%.1f" % ml, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, LCD_TEXT)
	# units in the plot's top corners, where no curve reaches
	c.draw_string(fr, Vector2(plot.position.x + 6, plot.position.y + 14), "mL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(LCD_TEXT, 0.7))
	c.draw_string(fr, Vector2(plot.end.x - 60, plot.position.y + 14), "daPa", HORIZONTAL_ALIGNMENT_RIGHT, 54, 11, Color(LCD_TEXT, 0.7))
	for ear: String in ["right", "left"]:
		if _curves.has(ear):
			_draw_curve(ear)
	if _curves.is_empty():
		var msg := "Seal the ear to begin" if not _sealed else "Sealed! Sweeping..."
		c.draw_string(f, Vector2(plot.position.x, plot.get_center().y), msg, HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, 22, Color(LCD_TEXT, 0.55 + 0.25 * sin(_t * 4.0)))
	_draw_ribbons()
	# right-hand side: readouts, or the tip tray
	var side := Rect2(Vector2(SCREEN.end.x + 16, SCREEN.position.y), Vector2(DEVICE.end.x - SCREEN.end.x - 40, SCREEN.size.y))
	if _tips_visible:
		_draw_tips(side)
	else:
		_draw_readouts(side)
	_draw_probe()
	if _gag_t >= 0.0 and _gag != "":
		_draw_gag()


func _draw_curve(ear: String) -> void:
	var c := _canvas
	var cv: Dictionary = _curves[ear]
	var data: Dictionary = cv["data"]
	var k := float(cv["k"])
	var col := Palette.ear_color(ear)
	var pts := PackedVector2Array()
	var n := 90
	var last := int(round(n * k))
	for i in last + 1:
		var p := lerpf(CaseRules.TYMP_SWEEP_FROM, CaseRules.TYMP_SWEEP_TO, float(i) / n)
		pts.append(Vector2(_p2x(p), _ml2y(CaseRules.tymp_admittance(data, p))))
	if pts.size() >= 2:
		c.draw_polyline(pts, Color(col, 0.35), 9.0, true)
		c.draw_polyline(pts, col.lightened(0.25), 3.5, true)
	if k >= 1.0 and String(data.get("type", "")) != "B":
		var peak := Vector2(_p2x(float(data.get("peak_daPa", 0))), _ml2y(float(data.get("peak_ml", 0))))
		c.draw_circle(peak, 6.0, col.lightened(0.3))
		c.draw_arc(peak, 6.0, 0, TAU, 16, LCD, 2.0, true)
		var lbl := "R" if ear == "right" else "L"
		c.draw_string(UiKit.font(700), peak + Vector2(-5, -12), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col.lightened(0.35))


func _draw_readouts(side: Rect2) -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var fr := UiKit.font(600)
	var y := side.position.y + 4
	for ear: String in ["right", "left"]:
		var col := Palette.ear_color(ear)
		var box := Rect2(Vector2(side.position.x, y), Vector2(side.size.x, 106))
		UiDraw.rounded_rect(c, box, Color(Palette.PAPER, 0.92), 14, 3, Palette.INK)
		UiDraw.rounded_rect(c, Rect2(box.position, Vector2(box.size.x, 26)), col, 12)
		c.draw_string(f, box.position + Vector2(10, 19), "RIGHT" if ear == "right" else "LEFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.PAPER)
		if _curves.has(ear) and float((_curves[ear] as Dictionary)["k"]) >= 1.0:
			var d: Dictionary = (_curves[ear] as Dictionary)["data"]
			var flat := String(d.get("type", "")) == "B"
			c.draw_string(fr, box.position + Vector2(10, 45), "Canal vol  %.1f mL" % float(d.get("ecv_ml", 1.2)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)
			if d.has("ecv_ml"):
				_draw_ecv_chip(box, CaseRules.ecv_band(float(d["ecv_ml"])))
			c.draw_string(fr, box.position + Vector2(10, 64), "Peak at  %s" % ("none" if flat else "%+d daPa" % int(d.get("peak_daPa", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)
			c.draw_string(fr, box.position + Vector2(10, 83), "Peak  %s" % ("flat" if flat else "%.1f mL" % float(d.get("peak_ml", 0))), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)
			var ty := String(d.get("type", "?")) if _revealed.has(ear) else "?"
			var tc := Vector2(box.end.x - 30, box.position.y + 58)
			c.draw_circle(tc, 22.0, Palette.SUNNY if _revealed.has(ear) else Color("#e6e0d6"))
			c.draw_arc(tc, 22.0, 0, TAU, 24, Palette.INK, 3.0, true)
			var w := f.get_string_size(ty, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			c.draw_string(f, tc + Vector2(-w * 0.5, 8), ty, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.INK)
			c.draw_string(fr, tc + Vector2(-17, 37), "TYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.INK_SOFT)
		else:
			c.draw_string(fr, box.position + Vector2(10, 62), "waiting...", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_SOFT)
		y += 114


## The canal-volume chip, right-aligned in an ear's readout header: "canal [NORMAL]". (The "Canal vol"
## row has no room left of the type badge, so it sits on the header bar just above it.)
func _draw_ecv_chip(box: Rect2, band: StringName) -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var word := ECV_WORDS.get(band, "?") as String
	var col: Color = ECV_COLORS.get(band, Palette.PAPER)
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 14
	var chip := Rect2(Vector2(box.end.x - 8 - w, box.position.y + 4), Vector2(w, 18))
	UiDraw.rounded_rect(c, chip, col, 9, 2, Palette.INK)
	c.draw_string(f, chip.position + Vector2(7, 13), word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.INK)
	c.draw_string(UiKit.font(600), Vector2(chip.position.x - 64, box.position.y + 18), "canal", HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Palette.PAPER)


## The flat ears' ribbons, stacked in the plot's empty top-left (clear of the "normal" box label and
## of the other ear's peak). Each pops in from reveal_type.
func _draw_ribbons() -> void:
	var plot := _plot()
	for ear: String in _ribbons:
		var rb: Dictionary = _ribbons[ear]
		var k := float(rb["k"])
		if k <= 0.0:
			continue
		var d: Dictionary = (_curves[ear] as Dictionary)["data"]
		var top_left := plot.position + Vector2(22, 52 + RIBBON_GAP * int(rb["row"]))
		_draw_ribbon(ear, CaseRules.ecv_band(float(d["ecv_ml"])), top_left, k)


## One swallowtail ribbon: the ear's R / L tag, then the reading, in the canal chip's colour.
## k: the pop (0..1, overshoots a little).
func _draw_ribbon(ear: String, band: StringName, top_left: Vector2, k: float) -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var txt := FLAT_READINGS.get(band, "") as String
	var col: Color = ECV_COLORS.get(band, Palette.PAPER)
	var dims := Vector2(f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 46, 26)
	var sc := lerpf(0.8 if Juice._reduced() else 0.3, 1.0, k)
	c.draw_set_transform(top_left + dims * 0.5, -0.02, Vector2.ONE * sc)
	var r := Rect2(-dims * 0.5, dims)
	var hw := dims.x * 0.5
	UiDraw.rounded_rect(c, Rect2(r.position + Vector2(0, 4), r.size), Color(Palette.INK, 0.2), 8)
	# the forked ends, tucked behind the band and a little lower
	for dir: float in [-1.0, 1.0]:
		var tail := PackedVector2Array([Vector2(dir * (hw - 10), -6), Vector2(dir * (hw + 14), -6),
			Vector2(dir * (hw + 6), 7), Vector2(dir * (hw + 14), 20), Vector2(dir * (hw - 10), 20)])
		c.draw_colored_polygon(tail, col.darkened(0.3))
		tail.append(tail[0])
		c.draw_polyline(tail, Palette.INK, 3.0, true)
	UiDraw.rounded_rect(c, r, col, 8, 3, Palette.INK)
	var tag := Vector2(r.position.x + 17, 0)
	var lbl := "R" if ear == "right" else "L"
	c.draw_circle(tag, 10.0, Palette.ear_color(ear))
	c.draw_arc(tag, 10.0, 0, TAU, 20, Palette.INK, 2.5, true)
	c.draw_string(f, tag + Vector2(-f.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 5), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.PAPER)
	c.draw_string(f, Vector2(r.position.x + 34, 5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)
	c.draw_set_transform(Vector2.ZERO)


func _draw_tips(side: Rect2) -> void:
	var c := _canvas
	var f := UiKit.font(700)
	c.draw_string(f, side.position + Vector2(0, 18), "EAR TIPS", HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 16, Palette.INK)
	var labels := {&"small": "S", &"medium": "M", &"large": "L"}
	for i in CaseRules.TIP_SIZES.size():
		var s: StringName = CaseRules.TIP_SIZES[i]
		var r := 14.0 + 7.0 * i
		var cc := Vector2(side.position.x + side.size.x * (0.2 + 0.3 * i), side.position.y + 88)
		if s == _tip:
			cc.y -= 12.0 + 4.0 * sin(_t * 10.0)
		c.draw_circle(cc + Vector2(0, 4), r, Color(Palette.INK, 0.2))
		c.draw_circle(cc, r, TIP_COLORS[s])
		c.draw_arc(cc, r, 0, TAU, 24, Palette.INK, 3.0, true)
		c.draw_circle(cc, r * 0.35, Color(Palette.INK, 0.5))
		var w := f.get_string_size(labels[s], HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		c.draw_string(f, Vector2(cc.x - w * 0.5, side.position.y + 146), labels[s], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)
	c.draw_string(UiKit.font(600), side.position + Vector2(0, 184), "Snug, no gaps", HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 14, Palette.INK_SOFT)


func _draw_probe() -> void:
	var c := _canvas
	# the probe dangles under the device's left end on a curly cable (left of the dialogue choices)
	var base := DEVICE.position + Vector2(60, DEVICE.size.y)
	var tipc := base + Vector2(30, 34)
	var pts := PackedVector2Array()
	for i in 13:
		var k := i / 12.0
		pts.append(base.lerp(tipc, k) + Vector2(sin(k * TAU * 3.0) * 5.0, 0))
	c.draw_polyline(pts, Palette.INK, 3.0, true)
	UiDraw.rounded_rect(c, Rect2(tipc + Vector2(-12, -6), Vector2(24, 30)), Color("#e6e0d6"), 8, 3, Palette.INK)
	if _tip != &"":
		c.draw_circle(tipc + Vector2(0, 30), 8.0 + 3.0 * CaseRules.TIP_SIZES.find(_tip), TIP_COLORS[_tip])
		c.draw_arc(tipc + Vector2(0, 30), 8.0 + 3.0 * CaseRules.TIP_SIZES.find(_tip), 0, TAU, 20, Palette.INK, 2.5, true)
	if _sealed:
		c.draw_circle(DEVICE.position + Vector2(DEVICE.size.x - 34, 20), 7.0, Palette.MINT if fmod(_t, 0.8) < 0.6 else Palette.MINT.darkened(0.3))
		c.draw_string(UiKit.font(700), DEVICE.position + Vector2(DEVICE.size.x - 110, 25), "SEAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)


func _draw_gag() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var txt := {"seal": "pop! SEALED", "leak": "hisss... LEAK!", "big": "OOF! TOO BIG"}.get(_gag, "") as String
	var col: Color = Palette.MINT.darkened(0.2) if _gag == "seal" else Palette.CORAL
	var k := clampf(_gag_t / 0.25, 0.0, 1.0)
	var at := SCREEN.get_center() + Vector2(0, -10)
	if _gag == "big":
		at.y += sin(_gag_t * 18.0) * 6.0 * (1.0 - k * 0.5)
	elif _gag == "leak":
		at.x += sin(_gag_t * 30.0) * 4.0
	var size := int(lerpf(18.0, 40.0, k))
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	c.draw_string_outline(f, at - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Palette.INK)
	c.draw_string(f, at - Vector2(w * 0.5, 0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if _gag == "leak":
		for i in 5:
			var a := _t * 6.0 + i * 1.3
			var p := DEVICE.position + Vector2(90, DEVICE.size.y + 64) + Vector2(cos(a) * 26.0, sin(a) * 10.0 - fmod(_gag_t * 40.0 + i * 9.0, 40.0))
			c.draw_arc(p, 5.0, 0, PI, 8, Color(Palette.SKY, 0.8), 2.0)
