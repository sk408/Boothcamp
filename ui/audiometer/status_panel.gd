class_name AoStatus
extends Control
## AoStatus: score, combo flame and comfort hearts (ui/ only). The score counts up, the combo
## flame grows with the multiplier (x1 -> x2 -> x3 -> x5) and the hearts break when comfort drops.

var points: int = 0
var combo: int = 0
var multiplier: int = 1
var hearts: int = 3
var _shown_points := 0.0
var _t := 0.0
var _combo_pop := 0.0
var _heart_break := -1
var _heart_t := 0.0
var _snuff := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_points(p: int) -> void:
	points = p


func set_combo(n: int, mult: int) -> void:
	if n == 0 and combo > 0:
		_snuff = 1.0
	if mult > multiplier or (n > combo and n > 0):
		_combo_pop = 1.0
	combo = n
	multiplier = mult


func set_hearts(h: int) -> void:
	if h < hearts:
		_heart_break = h
		_heart_t = 1.0
	hearts = h


func _process(delta: float) -> void:
	_t += delta
	_shown_points = move_toward(_shown_points, float(points), maxf(30.0, absf(points - _shown_points) * 6.0) * delta)
	_combo_pop = maxf(0.0, _combo_pop - delta * 3.0)
	_heart_t = maxf(0.0, _heart_t - delta * 1.2)
	_snuff = maxf(0.0, _snuff - delta * 1.5)
	queue_redraw()


## The next combo milestone (3, 6, 10) and the previous one, for the pip bar.
static func combo_window(n: int) -> Array[int]:
	if n >= 10:
		return [10, 10]
	if n >= 6:
		return [6, 10]
	if n >= 3:
		return [3, 6]
	return [0, 3]


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Palette.PAPER, 22)
	var x0 := 18.0
	# score
	AoDraw.text_l(self, Vector2(x0, 26), "SCORE", 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	UiDraw.star(self, Vector2(x0 + 12, 60), 13.0, Palette.SUNNY)
	draw_arc(Vector2(x0 + 12, 60), 13.5, 0, TAU, 20, Color(Palette.INK, 0.0), 1.0)
	var pts_txt := _thousands(int(round(_shown_points)))
	AoDraw.text_l(self, Vector2(x0 + 32, 58), pts_txt, 36, Palette.INK, AoDraw.FONT_BOLD)
	# combo
	var cy := 112.0
	AoDraw.text_l(self, Vector2(x0, cy - 22), "COMBO", 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var flame_h := 0.0 if combo == 0 else 14.0 + 3.5 * multiplier
	var fbase := Vector2(x0 + 14, cy + 16)
	if flame_h > 0.0:
		AoDraw.flame(self, fbase, flame_h * (1.0 + 0.25 * _combo_pop), _t, clampf((multiplier - 1) / 4.0, 0.0, 1.0))
	else:
		# an unlit wick, and a little smoke puff right after the flame is snuffed out
		draw_line(fbase + Vector2(0, -2), fbase + Vector2(1, -10), Color(Palette.INK_SOFT, 0.5), 2.5, true)
		if _snuff > 0.0:
			for i in 3:
				draw_circle(fbase + Vector2(4 * i - 4, -12 - 26.0 * (1.0 - _snuff) - i * 6), 4.0 + i, Color(Palette.INK_SOFT, 0.4 * _snuff))
	var mtxt := "x%d" % multiplier
	var ms := int(30 + 10 * _combo_pop)
	var mcol := Palette.INK if multiplier == 1 else Palette.SELECT_ORANGE.lerp(Palette.CORAL, (multiplier - 2) / 3.0)
	var mw := AoDraw.text_l(self, Vector2(x0 + 34, cy + 2), mtxt, ms, mcol, AoDraw.FONT_BOLD, 0)
	# pips toward the next multiplier
	var win := combo_window(combo)
	var n := win[1] - win[0]
	var px := x0 + 44 + mw
	if n > 0:
		for i in n:
			var c := Vector2(px + i * 17.0, cy + 4)
			var filled := combo - win[0] > i
			draw_circle(c, 6.5, Palette.INK)
			draw_circle(c, 4.5, Palette.SUNNY if filled else Palette.CREAM)
		AoDraw.text_l(self, Vector2(px + n * 17.0 + 2, cy + 4), "x%d" % ClinicRules.combo_multiplier(win[1]), 13, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	else:
		AoDraw.text_l(self, Vector2(px, cy + 4), "MAX!", 16, Palette.CORAL, AoDraw.FONT_BOLD)
	# comfort hearts
	var hy := r.end.y - 26.0
	AoDraw.text_l(self, Vector2(x0, hy), "COMFORT", 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	for i in ClinicRules.MAX_COMFORT:
		var c := Vector2(x0 + 104 + i * 36.0, hy + 1)
		var full := i < hearts
		var s := 26.0
		if i == _heart_break and _heart_t > 0.0:
			c += Vector2(sin(_t * 50.0) * 4.0 * _heart_t, -10.0 * _heart_t)
			s *= 1.0 + 0.3 * _heart_t
		UiDraw.heart(self, c + Vector2(0, 2), s + 4.0, Palette.INK)
		UiDraw.heart(self, c, s, Palette.CORAL if full else Palette.CREAM.darkened(0.08))
		if not full and i == _heart_break and _heart_t > 0.0:
			draw_line(c + Vector2(-2, -8), c + Vector2(3, 0), Palette.INK, 2.5)
			draw_line(c + Vector2(3, 0), c + Vector2(-3, 6), Palette.INK, 2.5)


static func _thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
