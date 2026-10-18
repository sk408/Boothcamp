class_name SpAgreementMeter
extends Control
## SpAgreementMeter: the PTA/SRT agreement meter (ui/speech only), the SPEECH screen's "lie
## detector" gag. A big analogue needle over GOOD (green, 6 dB or less apart), FAIR (amber, 7-12)
## and POOR (red, 13 or more), reading |SRT - PTA|, with a polygraph-style paper trace scrolling
## underneath and a warning bulb on the bezel.
##  - While testing it reads the agreement so far: the softest level scored "repeated" is a
##    provisional SRT, and every word repeated BELOW the PTA pushes the needle right (a provisional
##    level above the PTA says nothing yet: the SRT may still come down). It wobbles while it works.
##  - lock_in() on store: the needle swings to the stored SRT's reading, clunks into place, a
##    verdict stamp lands and `clunked` fires (the screen adds the shake, sound and callout).
##    Past the end of the scale (Mike: 42 dB apart) it slams into the stop pin and bounces.

signal clunked(agreement: StringName)

const MAX_DIFF := 45.0
## Where the band edges sit on the dial (0 = left stop, 1 = right stop).
const K_GOOD := 0.28
const K_FAIR := 0.5
const K_STOP := 1.04
const LOCK_SWING_S := 0.55
const BAND_COLORS: Dictionary[StringName, Color] = {&"good": Color("#5bc8a3"), &"fair": Color("#ffb627"), &"poor": Color("#ff6f59")}
const BAND_WORDS: Dictionary[StringName, String] = {&"good": "GOOD", &"fair": "FAIR", &"poor": "POOR"}

var pta: float = NAN
var provisional: int = SpeechRules.NO_SRT
var testing: bool = false
var srt: int = SpeechRules.NO_SRT
var agreement: StringName = &""
var _needle := 0.0
var _vel := 0.0
var _locking := false
var _locked := false
var _lock_t := 0.0
var _clunk := 0.0
var _stamp_t := -1.0
var _trace := PackedFloat32Array()
var _trace_acc := 0.0
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 7


## A fresh ear: needle at rest, no verdict (the trace keeps scrolling).
func reset() -> void:
	srt = SpeechRules.NO_SRT
	provisional = SpeechRules.NO_SRT
	agreement = &""
	testing = false
	_locking = false
	_locked = false
	_stamp_t = -1.0
	_clunk = 0.0


func set_reading(p_pta: float, p_provisional: int, p_testing: bool) -> void:
	if _locking or _locked:
		return
	if p_provisional != provisional and p_provisional != SpeechRules.NO_SRT:
		_vel += _rng.randf_range(-1.6, 1.6)   # a new word: the needle twitches
	pta = p_pta
	provisional = p_provisional
	testing = p_testing


## The store: swing to the stored SRT's reading, then clunk (emits `clunked`).
func lock_in(p_srt: int, p_pta: float, p_agreement: StringName) -> void:
	srt = p_srt
	pta = p_pta
	agreement = p_agreement
	_locking = true
	_locked = false
	_lock_t = 0.0
	_vel += 2.5


func is_locked() -> bool:
	return _locked


## The dB difference the needle is heading for.
func reading_db() -> float:
	if is_nan(pta):
		return 0.0
	if _locking or _locked:
		return absf(float(srt) - pta) if srt != SpeechRules.NO_SRT else 0.0
	if provisional != SpeechRules.NO_SRT:
		return maxf(0.0, pta - float(provisional))
	return 0.0


## The band a reading falls in (&"" without a PTA).
func band_for(v: float) -> StringName:
	if is_nan(pta):
		return &""
	if v <= SpeechRules.AGREE_GOOD_DB:
		return &"good"
	if v <= SpeechRules.AGREE_FAIR_DB:
		return &"fair"
	return &"poor"


static func value_to_k(v: float) -> float:
	var g := float(SpeechRules.AGREE_GOOD_DB)
	var f := float(SpeechRules.AGREE_FAIR_DB)
	if v <= g:
		return K_GOOD * maxf(0.0, v) / g
	if v <= f:
		return K_GOOD + (K_FAIR - K_GOOD) * (v - g) / (f - g)
	return K_FAIR + (1.0 - K_FAIR) * (v - f) / (MAX_DIFF - f)


func needle_k() -> float:
	return _needle


func _process(delta: float) -> void:
	_t += delta
	var target := value_to_k(reading_db())
	if _locking:
		_lock_t += delta
		_spring(target, 120.0, 7.0, delta)
		if _lock_t >= LOCK_SWING_S:
			_locking = false
			_locked = true
			_clunk = 1.0
			_stamp_t = 0.0
			_vel = 0.0
			_needle = minf(target, K_STOP)
			clunked.emit(agreement)
	elif _locked:
		_clunk = maxf(0.0, _clunk - delta * 2.2)
		var pegged := target >= K_STOP
		_needle = minf(target, K_STOP) - (0.025 * absf(sin(_t * 30.0)) * _clunk if pegged else 0.0) + sin(_t * 40.0) * 0.012 * _clunk
	else:
		var wob := 0.0
		if testing:
			wob = 0.018 * sin(_t * 7.3) + 0.012 * sin(_t * 13.1 + 1.3) + 0.006 * sin(_t * 29.0)
			if _rng.randf() < delta * 1.5:
				_vel += _rng.randf_range(-0.6, 0.6)
		else:
			wob = 0.006 * sin(_t * 2.1)
		_spring(target + wob, 55.0, 6.5, delta)
	if _stamp_t >= 0.0:
		_stamp_t += delta
	_trace_acc += delta
	while _trace_acc >= 0.06:
		_trace_acc -= 0.06
		_trace.append(_needle)
		if _trace.size() > 160:
			_trace = _trace.slice(_trace.size() - 160)
	queue_redraw()


func _spring(target: float, k: float, damp: float, delta: float) -> void:
	var dt := minf(delta, 0.05)
	_vel += ((target - _needle) * k - _vel * damp) * dt
	_needle += _vel * dt
	if _needle > K_STOP:
		_needle = K_STOP
		_vel = -absf(_vel) * 0.45   # the stop pin: bounce back
	elif _needle < -0.02:
		_needle = -0.02
		_vel = absf(_vel) * 0.3


func _angle(k: float) -> float:
	return lerpf(PI + 0.42, TAU - 0.42, clampf(k, -0.03, 1.06))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Color("#3b3154"), 24)
	# nameplate and warning bulb
	var plate := Rect2(Vector2(18, -12), Vector2(minf(200.0, r.size.x - 74.0), 26))
	AoDraw.rbox(self, Rect2(plate.position + Vector2(0, 3), plate.size), Color(Palette.INK, 0.4), 13)
	AoDraw.rbox(self, plate, Palette.CORAL, 13, 3, Palette.INK)
	AoDraw.text_c(self, plate.get_center(), "AGREEMENT METER", 14 if plate.size.x >= 170.0 else 12, Palette.PAPER, AoDraw.FONT_BOLD)
	_draw_bulb(Vector2(r.end.x - 30.0, 1.0))
	var face_h := clampf(r.size.y * 0.6, 120.0, 214.0)
	var face := Rect2(Vector2(12, 22), Vector2(r.size.x - 24, face_h))
	AoDraw.rbox(self, face, Color("#fff6e2"), 16, 3, Palette.INK)
	AoDraw.text_c(self, Vector2(face.get_center().x, face.position.y + 15.0), "PTA  vs  SRT", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var pivot := Vector2(face.get_center().x, face.end.y - 30.0)
	var rad := minf(face.size.x * 0.5 - 30.0, face_h - 70.0)
	# bands
	var bw := clampf(rad * 0.16, 10.0, 18.0)
	draw_arc(pivot, rad, _angle(0.0), _angle(K_GOOD), 24, BAND_COLORS[&"good"], bw, true)
	draw_arc(pivot, rad, _angle(K_GOOD), _angle(K_FAIR), 20, BAND_COLORS[&"fair"], bw, true)
	draw_arc(pivot, rad, _angle(K_FAIR), _angle(1.0), 36, BAND_COLORS[&"poor"], bw, true)
	draw_arc(pivot, rad + bw * 0.5 + 1.0, _angle(0.0), _angle(1.0), 48, Palette.INK, 2.0, true)
	draw_arc(pivot, rad - bw * 0.5 - 1.0, _angle(0.0), _angle(1.0), 48, Color(Palette.INK, 0.5), 1.5, true)
	# ticks and numbers
	for v: float in [0.0, 3.0, 6.0, 9.0, 12.0, 20.0, 30.0, 40.0, 45.0]:
		var a := _angle(value_to_k(v))
		var dir := Vector2(cos(a), sin(a))
		var major := v in [0.0, 6.0, 12.0, 20.0, 30.0, 40.0]
		draw_line(pivot + dir * (rad - bw * 0.5), pivot + dir * (rad + bw * 0.5 + (6.0 if major else 2.0)), Palette.INK, 2.5 if major else 1.5, true)
		if major:
			AoDraw.text_c(self, pivot + dir * (rad + bw * 0.5 + 16.0), "40+" if v == 40.0 else "%d" % int(v), 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	for spec: Array in [[&"good", K_GOOD * 0.5], [&"fair", (K_GOOD + K_FAIR) * 0.5], [&"poor", 0.76]]:
		var a2 := _angle(float(spec[1]))
		var p := pivot + Vector2(cos(a2), sin(a2)) * (rad - bw - 14.0)
		AoDraw.text_c(self, p, BAND_WORDS[StringName(spec[0])], 12 if rad > 80.0 else 10, (BAND_COLORS[StringName(spec[0])] as Color).darkened(0.35), AoDraw.FONT_BOLD)
	# the stop pin
	var pa := _angle(K_STOP + 0.01)
	draw_circle(pivot + Vector2(cos(pa), sin(pa)) * (rad - 4.0), 4.0, Palette.INK)
	# needle (shadow, body, red tip) and hub
	var na := _angle(_needle)
	var nd := Vector2(cos(na), sin(na))
	var tip := pivot + nd * (rad + 2.0)
	var tail := pivot - nd * 16.0
	draw_line(tail + Vector2(3, 4), tip + Vector2(3, 4), Color(Palette.INK, 0.22), 5.0, true)
	draw_line(tail, tip, Palette.INK, 4.5, true)
	draw_line(pivot + nd * (rad * 0.7), tip, Palette.CORAL.darkened(0.1), 3.0, true)
	draw_circle(pivot, 13.0, Palette.INK)
	draw_circle(pivot, 9.0, Palette.SELECT_ORANGE)
	draw_circle(pivot + Vector2(-2, -2), 3.0, Color(1, 1, 1, 0.6))
	# glass sheen
	draw_colored_polygon(PackedVector2Array([face.position + Vector2(10, 8), face.position + Vector2(face.size.x * 0.45, 8), face.position + Vector2(face.size.x * 0.25, face.size.y * 0.45), face.position + Vector2(10, face.size.y * 0.55)]), Color(1, 1, 1, 0.16))
	# status line under the hub
	var status := ""
	if _locked:
		status = "%d dB apart" % int(round(reading_db()))
	elif _locking:
		status = "..."
	elif is_nan(pta):
		status = "no PTA yet"
	elif provisional == SpeechRules.NO_SRT:
		status = "waiting for words"
	else:
		status = "testing" + ".".repeat(1 + int(_t * 3.0) % 3)
	AoDraw.text_c(self, Vector2(pivot.x, face.end.y - 9.0), status, 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	if _stamp_t >= 0.0 and agreement != &"":
		_draw_stamp(Vector2(face.get_center().x, face.position.y + face_h * 0.5))
	# readouts
	var cy := face.end.y + 8.0
	var ch := 40.0
	if cy + ch <= r.end.y - 10.0:
		var cw := (face.size.x - 12.0) / 3.0
		var srt_txt := "--"
		if _locking or _locked:
			srt_txt = "%d" % srt
		elif provisional != SpeechRules.NO_SRT:
			srt_txt = "~%d" % provisional
		var apart := "--" if is_nan(pta) or (provisional == SpeechRules.NO_SRT and not _locked and not _locking) else "%d" % int(round(reading_db()))
		var band := band_for(reading_db()) if _locked else &""
		var cells: Array = [["PTA", "--" if is_nan(pta) else "%d" % int(round(pta)), Palette.LCD_TEXT],
			["SRT", srt_txt, Palette.LCD_TEXT],
			["APART", apart, BAND_COLORS.get(band, Palette.LCD_TEXT)]]
		for i in 3:
			var cell: Array = cells[i]
			var cr := Rect2(Vector2(face.position.x + i * (cw + 6.0), cy), Vector2(cw, ch))
			AoDraw.rbox(self, cr, Palette.LCD_BG, 10, 2, Color(Palette.INK, 0.8))
			AoDraw.text_c(self, Vector2(cr.get_center().x, cr.position.y + 10.0), String(cell[0]), 9, Color(Palette.LCD_TEXT, 0.5), AoDraw.FONT_BOLD)
			AoDraw.text_c(self, Vector2(cr.get_center().x, cr.position.y + 27.0), String(cell[1]), 19, cell[2] as Color, AoDraw.FONT_BOLD)
		_draw_trace(Rect2(Vector2(face.position.x, cy + ch + 8.0), Vector2(face.size.x, r.end.y - 14.0 - (cy + ch + 8.0))))


## The polygraph strip: paper scrolling left, the pen following the needle.
func _draw_trace(s: Rect2) -> void:
	if s.size.y < 22.0:
		return
	AoDraw.rbox(self, s, Palette.PAPER, 8, 2, Color(Palette.INK, 0.8))
	var inner := s.grow(-4.0)
	var scroll := fmod(_t * 18.0, 10.0)
	var x := inner.end.x - scroll
	while x > inner.position.x:
		draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(Palette.SKY, 0.6), 1.0)
		x -= 10.0
	for spec: Array in [[K_GOOD, &"good"], [K_FAIR, &"fair"]]:
		var yy := inner.end.y - float(spec[0]) * inner.size.y
		AoDraw.dashed(self, Vector2(inner.position.x, yy), Vector2(inner.end.x, yy), Color(BAND_COLORS[StringName(spec[1])], 0.8), 1.5, 4.0, 4.0)
	var n := _trace.size()
	if n >= 2:
		var pts := PackedVector2Array()
		var step := inner.size.x / 150.0
		for i in n:
			var px := inner.end.x - (n - 1 - i) * step
			if px < inner.position.x:
				continue
			pts.append(Vector2(px, inner.end.y - clampf(_trace[i], 0.0, 1.0) * inner.size.y))
		if pts.size() >= 2:
			draw_polyline(pts, Palette.INK, 2.0, true)
		var pen := Vector2(inner.end.x, inner.end.y - clampf(_needle, 0.0, 1.0) * inner.size.y)
		draw_line(pen, Vector2(s.end.x + 2.0, s.position.y - 2.0), Color(Palette.INK, 0.6), 2.0, true)
		draw_circle(pen, 3.5, Palette.CORAL)


func _draw_bulb(c: Vector2) -> void:
	var col := Palette.LCD_DIM
	var lit := 0.0
	if _locked and agreement != &"":
		col = BAND_COLORS.get(agreement, Palette.LCD_DIM)
		lit = 1.0 if agreement != &"poor" else 0.55 + 0.45 * sin(_t * 9.0)
	elif testing and not is_nan(pta) and provisional != SpeechRules.NO_SRT:
		col = BAND_COLORS.get(band_for(reading_db()), Palette.LCD_DIM)
		lit = 0.45
	if lit > 0.0:
		draw_circle(c, 18.0, Color(col, 0.25 * lit))
		if agreement == &"poor" and _locked:
			for i in 8:
				var a := TAU * i / 8.0 + _t
				draw_line(c + Vector2(cos(a), sin(a)) * 15.0, c + Vector2(cos(a), sin(a)) * (20.0 + 3.0 * lit), Color(col, 0.6 * lit), 2.0, true)
	draw_circle(c + Vector2(0, 2), 12.0, Color(Palette.INK, 0.4))
	draw_circle(c, 12.0, Palette.INK)
	draw_circle(c, 9.0, Palette.LCD_DIM.lerp(col, maxf(0.2, lit)) if lit > 0.0 else Palette.LCD_DIM)
	draw_circle(c + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.35 + 0.4 * lit))


func _draw_stamp(c: Vector2) -> void:
	var k := clampf(_stamp_t / 0.16, 0.0, 1.0)
	var s := lerpf(2.4, 1.0, k * k)
	var a := clampf(_stamp_t / 0.06, 0.0, 1.0)
	var col: Color = BAND_COLORS.get(agreement, Palette.INK)
	var word: String = BAND_WORDS.get(agreement, "")
	var ink := col.darkened(0.15)
	draw_set_transform(c, deg_to_rad(-9.0), Vector2.ONE * s)
	var w := AoDraw.text_size(word, 34, AoDraw.FONT_BOLD).x + 40.0
	var rr := Rect2(Vector2(-w * 0.5, -30.0), Vector2(w, 56.0))
	AoDraw.rbox(self, rr, Color(Palette.PAPER, 0.88 * a), 10, 4, Color(ink, a))
	AoDraw.text_c(self, Vector2(0, -7.0), word, 34, Color(ink, a), AoDraw.FONT_BOLD)
	AoDraw.text_c(self, Vector2(0, 16.0), "AGREEMENT", 11, Color(ink, a), AoDraw.FONT_BOLD)
	draw_set_transform(Vector2.ZERO)
