class_name SpBanana
extends Control
## SpBanana: the Banana Board (ui/speech only; CONTRACTS.md §9.17.1, CHAPTER4 §5.2). A mini
## audiogram (250 Hz to 8 kHz across, -10 to 100 dB HL down, soft at the top) of the test ear's
## MEASURED thresholds (O or X in the ear colour, joined by a line), with a velvet curtain from the
## top of the chart down to that line. The speech-sound letters (SpeechRules.SOUND_CUES) sit at
## (cue frequency, dial + cue offset) and move with the dial; letters behind the curtain fade by
## SpeechRules.lens_alpha(), the lens's own arithmetic. A CHAT 50 tick marks chatting level.
## Once the ear's best is final: a "tones predict at least {min}%" bar beside her best, with a
## red-flag pin when the best is lower. After the louder list: her scores as a playground slide,
## a music note riding from the comfortable list over the top and down to the louder one.
## It slides in at the first lens press (reveal()); before that a dashed space says how to call it.
## Reduced motion: it slides in steps, the curtain does not sway, and the note moves in two steps.

const F_LO := 250.0
const F_HI := 8000.0
const DB_TOP := -10.0
const DB_BOTTOM := 100.0
const IN_S := 0.45
## The slide's note: up the ladder, over the top and down, then a rest (seconds; loops).
const SLIDE_S := 2.4

var ear := "right"
## The test ear's measured thresholds {freq: dB} (never the truth).
var thresholds: Dictionary = {}
var dial_db := 50
## The placeholder's line before the reveal ("NORA-VISION [V]").
var hint := ""
var predicted_min := -1
var best := -1
var best_final := false
## The slide: [[level_db, pct], ...] in level order (comfortable, then louder); [] = none.
var slide: Array = []
var _shown := false
var _in := 1.0
var _slide_t := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Slide in (the first lens press); `animate` false shows it at once (a later list of the visit).
func reveal(animate: bool = true) -> void:
	if _shown:
		return
	_shown = true
	_in = 0.0 if animate else 1.0
	queue_redraw()


func is_revealed() -> bool:
	return _shown


func set_slide(points: Array) -> void:
	if points != slide:
		slide = points.duplicate(true)
		_slide_t = 0.0
	queue_redraw()


## How far the slide-in has come (0..1; reduced motion: in three steps).
func slide_in() -> float:
	if AoFx._reduced():
		return floorf(_in * 3.0) / 3.0
	var e := clampf(_in, 0.0, 1.0)
	return 1.0 - pow(1.0 - e, 3.0)


## Where the slide's note is along its ride (0 = the comfortable score, 1 = the louder one).
## Reduced motion: two steps, no whoosh.
func note_k(t: float = -1.0) -> float:
	var tt := fmod(_slide_t if t < 0.0 else t, SLIDE_S)
	if AoFx._reduced():
		return 0.0 if tt < SLIDE_S * 0.5 else 1.0
	return clampf((tt - 0.5) / 1.1, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _shown and _in < 1.0:
		_in = minf(1.0, _in + delta / IN_S)
	if not slide.is_empty():
		_slide_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if not _shown:
		_draw_placeholder(r)
		return
	var k := slide_in()
	draw_set_transform(Vector2((1.0 - k) * size.x * 0.7, 0.0))
	AoDraw.card(self, r, Palette.PAPER, 16)
	AoDraw.rbox(self, Rect2(Vector2(4, 4), Vector2(r.size.x - 8, 24)), Palette.ear_tint(ear), 10)
	AoDraw.text_l(self, Vector2(14, 16), "BANANA BOARD", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	AoDraw.text_r(self, Vector2(r.size.x - 14, 16), ear.to_upper() + " EAR", 12, Palette.ear_color(ear), AoDraw.FONT_BOLD)
	var side := 64.0 if best_final and best >= 0 and predicted_min >= 0 else 0.0
	var chart := Rect2(Vector2(36, 40), Vector2(r.size.x - 48 - side, r.size.y - 62))
	_draw_chart(chart)
	if side > 0.0:
		_draw_prediction(Rect2(Vector2(chart.end.x + 8.0, chart.position.y), Vector2(side - 6.0, chart.size.y)))
	if slide.size() >= 2:
		# top right, over the curtain's high-pitch corner (the loud dial's letters sit lower down)
		var iw := minf(150.0, maxf(110.0, chart.size.x * 0.66))
		var ih := minf(92.0, maxf(66.0, chart.size.y * 0.46))
		_draw_slide(Rect2(Vector2(chart.end.x - iw - 2.0, chart.position.y + 2.0), Vector2(iw, ih)))
	draw_set_transform(Vector2.ZERO)


func _draw_placeholder(r: Rect2) -> void:
	var rc := r.grow(-4.0)
	var col := Color(Palette.INK, 0.2)
	var p := [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]
	for i in 4:
		AoDraw.dashed(self, p[i], p[(i + 1) % 4], col, 2.0, 8.0, 6.0)
	var c := rc.get_center()
	var w := 30.0
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for j in 13:
		var t := -1.0 + j / 6.0
		top.append(c + Vector2(t * w, -24.0 - (1.0 - t * t) * 14.0))
		bottom.append(c + Vector2(t * w, -24.0 + (1.0 - t * t) * 14.0))
	draw_polyline(top, Color(Palette.INK, 0.25), 3.0, true)
	draw_polyline(bottom, Color(Palette.INK, 0.25), 3.0, true)
	draw_circle(c + Vector2(0, -24), 7.0, Color(Palette.INK, 0.2))
	AoDraw.text_c(self, c + Vector2(0, 14), "Banana Board", 15, Color(Palette.INK, 0.38), AoDraw.FONT_BOLD)
	if hint != "":
		AoDraw.text_c(self, c + Vector2(0, 36), hint, 13, Color(Palette.INK, 0.38), AoDraw.FONT_SEMI)


func fx_of(freq: float, chart: Rect2) -> float:
	var k := log(clampf(freq, F_LO, F_HI) / F_LO) / log(F_HI / F_LO)
	return chart.position.x + chart.size.x * k


func fy_of(db: float, chart: Rect2) -> float:
	return chart.position.y + chart.size.y * clampf((db - DB_TOP) / (DB_BOTTOM - DB_TOP), 0.0, 1.0)


func _draw_chart(chart: Rect2) -> void:
	AoDraw.rbox(self, chart.grow(2.0), Palette.CREAM.lightened(0.4), 6)
	# grid
	for db in range(0, 101, 20):
		var y := fy_of(db, chart)
		draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), Color(Palette.SKY.darkened(0.15), 0.6), 1.0)
		AoDraw.text_r(self, Vector2(chart.position.x - 5.0, y), str(db), 10, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	for f: int in [250, 500, 1000, 2000, 4000, 8000]:
		var x := fx_of(f, chart)
		draw_line(Vector2(x, chart.position.y), Vector2(x, chart.end.y), Color(Palette.SKY.darkened(0.15), 0.6), 1.0)
		var lab := ("%dk" % (f / 1000)) if f >= 1000 else str(f)
		AoDraw.text_c(self, Vector2(x, chart.end.y + 10.0), lab, 10, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	# the curtain: from the top of the chart down to her threshold line
	var line := _threshold_points(chart)
	if line.size() >= 2:
		var poly := PackedVector2Array([Vector2(chart.position.x, chart.position.y), Vector2(chart.end.x, chart.position.y)])
		for i in range(line.size() - 1, -1, -1):
			poly.append(line[i])
		draw_colored_polygon(poly, Color(Palette.PLUM.darkened(0.2), 0.26))
		# folds (they sway a little; not with reduced motion)
		var sway := 0.0 if AoFx._reduced() else sin(_t * 1.3) * 2.0
		var x := chart.position.x + 9.0
		while x < chart.end.x - 4.0:
			var bottom_y := _line_y_at(line, x)
			if bottom_y > chart.position.y + 6.0:
				draw_line(Vector2(x, chart.position.y + 1.0), Vector2(x + sway, bottom_y - 2.0), Color(Palette.PLUM.darkened(0.45), 0.18), 3.0)
			x += 14.0
		draw_polyline(line, Palette.ear_color(ear), 3.0, true)
		for f: Variant in _sorted_freqs():
			var pt := Vector2(fx_of(float(f), chart), fy_of(float(thresholds[f]), chart))
			UiDraw.audiogram_symbol(self, pt, ear, &"ac", 9.0, 2.5)
	# chatting level and the dial
	var cy := fy_of(SpeechRules.CHAT_DB, chart)
	draw_line(Vector2(chart.position.x - 4.0, cy), Vector2(chart.position.x + 8.0, cy), Palette.INK, 2.0)
	# a narrow chart (the prediction column is in) says only CHAT, clear of the vowels at 750 Hz
	var chat := "CHAT %d" % SpeechRules.CHAT_DB if chart.size.x > 220.0 else "CHAT"
	AoDraw.text_l(self, Vector2(chart.position.x + 10.0, cy), chat, 9, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var dy := fy_of(dial_db, chart)
	AoDraw.dashed(self, Vector2(chart.position.x, dy), Vector2(chart.end.x, dy), Color(Palette.SELECT_ORANGE, 0.8), 2.0, 6.0, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(chart.position.x - 14.0, dy - 6.0), Vector2(chart.position.x - 14.0, dy + 6.0),
		Vector2(chart.position.x - 4.0, dy)]), Palette.SELECT_ORANGE)
	AoDraw.text_r(self, Vector2(chart.end.x - 2.0, dy + 9.0), "dial %d" % dial_db, 9, Palette.SELECT_ORANGE.darkened(0.3), AoDraw.FONT_BOLD)
	_draw_letters(chart)


## The speech-sound letters at (cue frequency, dial + offset); those at one frequency fan out
## sideways so they stay readable.
func _draw_letters(chart: Rect2) -> void:
	var by_freq: Dictionary = {}
	for s: String in SpeechRules.SOUND_CUES:
		var f := int((SpeechRules.SOUND_CUES[s] as Array)[0])
		if not by_freq.has(f):
			by_freq[f] = []
		(by_freq[f] as Array).append(s)
	for f: Variant in by_freq:
		var list: Array = by_freq[f]
		for i in list.size():
			var s := String(list[i])
			var cue: Array = SpeechRules.SOUND_CUES[s]
			var x := fx_of(float(f), chart) + (i - (list.size() - 1) * 0.5) * 13.0
			var y := fy_of(float(dial_db) + float(cue[1]), chart)
			var a := letter_alpha(s)
			var label := "aeiou" if s == "vowel" else s
			AoDraw.text_c(self, Vector2(x, y), label, 12 if s != "vowel" else 10, Color(Palette.INK, a), AoDraw.FONT_BOLD)


## A letter's ink on the board: SpeechRules.lens_alpha of its margin on the measured thresholds.
func letter_alpha(sound: String) -> float:
	return SpeechRules.lens_alpha(SpeechRules.sound_margin(sound, float(dial_db), thresholds))


func _sorted_freqs() -> Array:
	var fs: Array = []
	for f: Variant in thresholds:
		if float(f) >= F_LO and float(f) <= F_HI:
			fs.append(f)
	fs.sort()
	return fs


func _threshold_points(chart: Rect2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if thresholds.is_empty():
		return pts
	pts.append(Vector2(chart.position.x, fy_of(SpeechRules.interp_threshold(thresholds, int(F_LO)), chart)))
	for f: Variant in _sorted_freqs():
		if float(f) > F_LO and float(f) < F_HI:
			pts.append(Vector2(fx_of(float(f), chart), fy_of(float(thresholds[f]), chart)))
	pts.append(Vector2(chart.end.x, fy_of(SpeechRules.interp_threshold(thresholds, int(F_HI)), chart)))
	return pts


static func _line_y_at(line: PackedVector2Array, x: float) -> float:
	for i in line.size() - 1:
		if x >= line[i].x and x <= line[i + 1].x:
			var k := (x - line[i].x) / maxf(0.001, line[i + 1].x - line[i].x)
			return lerpf(line[i].y, line[i + 1].y, k)
	return line[line.size() - 1].y if not line.is_empty() else 0.0


## The prediction column: "tones predict at least {min}%" beside her best, a pin when it is lower.
func _draw_prediction(col: Rect2) -> void:
	var top := col.position.y + 26.0
	var bottom := col.end.y - 16.0
	var h := bottom - top
	var bw := (col.size.x - 10.0) * 0.5
	var bars := [[predicted_min, Palette.SUNNY, "MIN"], [best, Palette.ear_color(ear), "BEST"]]
	AoDraw.text_c(self, Vector2(col.get_center().x, col.position.y + 4.0), "tones", 9, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	AoDraw.text_c(self, Vector2(col.get_center().x, col.position.y + 14.0), "predict", 9, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	for i in 2:
		var b: Array = bars[i]
		var v := clampf(float(b[0]) / 100.0, 0.0, 1.0)
		var x := col.position.x + 2.0 + i * (bw + 6.0)
		var frame := Rect2(Vector2(x, top), Vector2(bw, h))
		AoDraw.rbox(self, frame, Color(Palette.INK, 0.06), 4, 1, Color(Palette.INK, 0.3))
		var fill := Rect2(Vector2(x, bottom - h * v), Vector2(bw, h * v))
		AoDraw.rbox(self, fill, b[1], 4, 2, Palette.INK)
		AoDraw.text_c(self, Vector2(x + bw * 0.5, fill.position.y - 8.0), "%d" % int(b[0]), 11, Palette.INK, AoDraw.FONT_BOLD)
		AoDraw.text_c(self, Vector2(x + bw * 0.5, bottom + 8.0), String(b[2]), 9, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	if best < predicted_min:
		# the red-flag pin on her best
		var x := col.position.x + 2.0 + bw + 6.0 + bw * 0.5
		var y := bottom - h * clampf(float(best) / 100.0, 0.0, 1.0) - 18.0
		draw_line(Vector2(x, y), Vector2(x, y - 26.0), Palette.INK, 2.5)
		draw_colored_polygon(PackedVector2Array([Vector2(x, y - 26.0), Vector2(x + 15.0, y - 21.0), Vector2(x, y - 16.0)]), Palette.RIGHT_RED)
		draw_circle(Vector2(x, y), 3.0, Palette.INK)


## The playground slide: score (up) by level (across), a ladder up to the first list and a slide
## down to the louder one; a music note rides it.
func _draw_slide(box: Rect2) -> void:
	AoDraw.rbox(self, Rect2(box.position + Vector2(0, 3), box.size), Color(Palette.INK, 0.2), 10)
	AoDraw.rbox(self, box, Palette.PAPER, 10, 2, Palette.INK)
	AoDraw.text_l(self, box.position + Vector2(8, 10), "LOUDER?", 10, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var plot := Rect2(box.position + Vector2(10, 22), box.size - Vector2(20, 38))
	var lo_db := float((slide[0] as Array)[0])
	var hi_db := float((slide[slide.size() - 1] as Array)[0])
	var pts := PackedVector2Array()
	for p: Variant in slide:
		var a: Array = p
		var kx := (float(a[0]) - lo_db) / maxf(1.0, hi_db - lo_db)
		pts.append(Vector2(plot.position.x + 14.0 + (plot.size.x - 28.0) * kx, plot.end.y - plot.size.y * clampf(float(a[1]) / 100.0, 0.0, 1.0)))
	# the ladder up to the first score
	var foot := Vector2(pts[0].x - 10.0, plot.end.y)
	draw_line(foot, pts[0] + Vector2(-10, 0), Palette.WOOD, 2.5)
	draw_line(foot + Vector2(8, 0), pts[0] + Vector2(-2, 0), Palette.WOOD, 2.5)
	var rung := plot.end.y - 7.0
	while rung > pts[0].y + 3.0:
		draw_line(Vector2(foot.x, rung), Vector2(foot.x + 8.0, rung), Palette.WOOD, 2.0)
		rung -= 8.0
	# the slide itself (a gentle curve between the scores)
	var curve := PackedVector2Array()
	for i in pts.size() - 1:
		for j in 11:
			var u := j / 10.0
			var e := u * u * (3.0 - 2.0 * u)
			curve.append(Vector2(lerpf(pts[i].x, pts[i + 1].x, u), lerpf(pts[i].y, pts[i + 1].y, e)))
	draw_polyline(curve, Palette.SKY.darkened(0.25), 6.0, true)
	draw_polyline(curve, Palette.SKY, 3.0, true)
	for i in pts.size():
		var a: Array = slide[i]
		draw_circle(pts[i], 3.5, Palette.INK)
		AoDraw.text_c(self, pts[i] + Vector2(0, -11), "%d%%" % int(a[1]), 10, Palette.INK, AoDraw.FONT_BOLD)
		AoDraw.text_c(self, Vector2(pts[i].x, plot.end.y + 9.0), "%d" % int(a[0]), 9, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	# the note rides from the first score to the last
	var k := note_k()
	var at := curve[clampi(roundi(k * (curve.size() - 1)), 0, curve.size() - 1)]
	_note(at + Vector2(0, -6))


func _note(c: Vector2) -> void:
	draw_circle(c + Vector2(-2, 3), 4.0, Palette.PLUM)
	draw_line(c + Vector2(1.5, 3), c + Vector2(1.5, -9), Palette.PLUM, 2.0)
	draw_line(c + Vector2(1.5, -9), c + Vector2(6, -6), Palette.PLUM, 2.0)
