extends "res://story/case_movies/case_movie_sets.gd"
## The sets of "Hoot's tympanometer movie" (story/explainers/movies/tymp.gd): Drummy the eardrum
## trampoline, the probe and its tips, the pressure sweep that draws the curve, the five shapes, the
## canal-volume measuring cup, and both ears side by side.
## Numbers: core/cases/case_rules.gd (TYMP_SWEEP_FROM / _TO, TYMP_NORMAL_PRESSURE, TYMP_NORMAL_PEAK,
## TYMP_ADULT_ECV, TYMP_BLOCKED_ECV); the gadget is story/games/case_tymp.gd.

const SETS: Array[StringName] = [&"ty_open", &"ty_seal", &"ty_sweep", &"ty_types", &"ty_volume", &"ty_compare", &"ty_bow"]

const DRUM := Color("#c9c6cf")
const RIM := Color("#5b6fb3")
const BOUNCER := Palette.SUNNY
## The five shapes, as [name, word, peak daPa, peak mL, width daPa], in the order the movie shows them.
const SHAPES: Array = [["A", "a mountain", 0.0, 0.9, 70.0], ["As", "a hill: stiff", 0.0, 0.2, 80.0],
	["Ad", "a skyscraper", 0.0, 2.4, 50.0], ["C", "moved left", -220.0, 0.8, 75.0], ["B", "a pancake", 0.0, 0.0, 80.0]]
const SHAPE_AT: Array[float] = [0.4, 5.6, 7.2, 8.8, 10.8]
## The shapes graph: pressure -400..+200 daPa across, admittance 0..2.6 mL up.
const GRAPH := Rect2(200, 64, 480, 226)
## The measuring cup: 0..3 mL.
const CUP := Rect2(150, 72, 140, 308)
const VOLUME_CARDS: Array = [["TINY: under 0.6 mL", "wax, or the probe on the wall"],
	["NORMAL: 0.6 to 2.0 mL", "fluid behind the eardrum"], ["BIG: over 2.0 mL", "a hole, or an open ear tube"]]
const VOLUME_AT: Array[float] = [1.8, 7.0, 10.0]
const WAX := Color("#b07a2e")


# ---------------------------------------------------------------- 1. the lead-in

func _set_ty_open() -> void:
	_marquee("HOOT'S TYMPANOMETER MOVIE", "The Eardrum", "Trampoline", "starring Drummy and the Tymp-O-Matic", _prop_trampoline)
	var t0 := float(params.get("card_hold", 8.0)) + 0.3
	var k := _pop(t0, 0.5)
	var hop := absf(sin((t - t0) * 5.0)) * s._motion if t > t0 + 0.6 else 0.0
	_trampoline(Vector2(440, 330), 260.0, 14.0 * (1.0 - hop), k, &"happy")
	_bouncer(Vector2(440, 300 - 110.0 * hop), 22.0, _pop(t0 + 0.4), 0.0)
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(t0 + 0.6), "mood": &"wave"})


func _prop_trampoline(at: Vector2) -> void:
	var hop := absf(sin(t * 5.0)) * s._motion
	_trampoline(at + Vector2(0, 34), 110.0, 6.0 * (1.0 - hop), 1.0, &"happy")
	_bouncer(at + Vector2(0, 22 - 46.0 * hop), 11.0, 1.0, 0.0)


# ---------------------------------------------------------------- 2. look, then a gentle seal

func _set_ty_seal() -> void:
	var ek := _pop(0.1, 0.5)
	if ek > 0.01:
		s._push(Stage2D._about(Vector2(500, 250), 0.0, Vector2.ONE * ek))
		s._rbox(Rect2(330, 150, 380, 200), Palette.SKIN, 40, 4)
		s._blob(Vector2(330, 250), Vector2(46, 118), Palette.SKIN, 4.0)
		s.draw_rect(Rect2(330, 222, 312, 56), Stage2D.CANAL)
		s.draw_rect(Rect2(646, 214, 50, 72), Color(Palette.PAPER, 0.7))
		s._blob(Vector2(642, 250), Vector2(7, 34), DRUM, 3.0)
		s._pop_xf()
	# the probe and its tip (drawn before the canal's walls, so a seated tip sits inside them)
	var st := _probe_state()
	var r: float = st[0]
	var x: float = st[1]
	var seated: bool = st[2]
	var pk := _pop(2.8, 0.4)
	if pk > 0.01:
		_probe(Vector2(x, 250), r, seated, pk)
	if ek > 0.01:
		s._push(Stage2D._about(Vector2(500, 250), 0.0, Vector2.ONE * ek))
		s.draw_line(Vector2(334, 222), Vector2(642, 222), Stage2D.INK, 4.0, true)
		s.draw_line(Vector2(334, 278), Vector2(642, 278), Stage2D.INK, 4.0, true)
		s._pop_xf()
	s._pointer_label("ear canal", Vector2(500, 120), Vector2(500, 230), Palette.INK_SOFT, _pop(0.6) * (1.0 - _k(5.6, 5.9)))
	s._pointer_label("eardrum", Vector2(760, 150), Vector2(650, 226), Palette.INK_SOFT, _pop(0.9) * (1.0 - _k(5.6, 5.9)))
	# look first: the otoscope's light in the canal
	var ok := _pop(0.4, 0.4) * (1.0 - _k(2.3, 2.7))
	if ok > 0.01:
		var oc := Vector2(lerpf(150.0, 268.0, Stage2D._ease_out(_k(0.4, 1.0))), 250)
		if t > 1.0 and t < 2.3:
			s.draw_colored_polygon(PackedVector2Array([oc + Vector2(50, -6), Vector2(640, 228), Vector2(640, 272), oc + Vector2(50, 6)]), Color(Palette.SUNNY, 0.35))
		_otoscope(oc, ok)
		s._chip("Look first!", Vector2(260, 116), Palette.SUNNY, 20, Stage2D.INK, _pop(1.2) * (1.0 - _k(2.3, 2.7)))
	if t > 3.6 and t < 5.6:
		s._chip("Gentle: just the entrance", Vector2(250, 116), Palette.SKY, 19, Stage2D.INK, _pop(3.6) * (1.0 - _k(5.2, 5.6)))
	# too small: hisss
	if t > 6.6 and t < 7.7:
		for sd: float in [-1.0, 1.0]:
			for i in 3:
				var u := fposmod(t * 1.6 + i / 3.0, 1.0)
				var p := Vector2(330.0 - 70.0 * u, 250.0 + sd * (22.0 + 26.0 * u))
				s.draw_arc(p, 8.0 + 6.0 * u, PI * 0.6, PI * 1.4, 8, Color(Palette.SKY.darkened(0.3), 1.0 - u), 3.0, true)
		s._text("hisss!", Vector2(230, 170), 26, Palette.INK_SOFT, 700, 6, Palette.PAPER, 0.5, _pop(6.6, 0.3))
	# too big: bonk
	s._bonk(Vector2(284, 250), 8.5, Vector2(250, 176))
	if t > 8.6 and t < 9.3:
		s._text("won't fit!", Vector2(250, 330), 22, Palette.CORAL.darkened(0.2), 700, 6, Palette.PAPER, 0.5, _pop(8.6, 0.3))
	# just right
	if t > 9.8:
		s.draw_arc(Vector2(334, 250), 40.0 + 3.0 * sin(t * 6.0) * s._motion, 0.0, TAU, 32, Color(Palette.MINT, 0.9), 4.0, true)
		s._chip("SEALED!", Vector2(250, 330), Palette.MINT, 24, Stage2D.INK, _pop(10.0))


## [tip radius, tip x, seated]: the medium tip shows the gentle seal, then small (leaks), large
## (won't go in) and medium again (sealed).
func _probe_state() -> Array:
	var park := 120.0
	if t < 5.6:
		var x1 := lerpf(park, 336.0, Stage2D._ease_in_out(_k(3.0, 4.4)))
		return [30.0, lerpf(x1, park, Stage2D._ease_in_out(_k(5.0, 5.6))), t > 4.4 and t < 5.0]
	if t < 8.0:
		var x2 := lerpf(park, 334.0, Stage2D._ease_in_out(_k(5.9, 6.5)))
		return [16.0, lerpf(x2, park, Stage2D._ease_in_out(_k(7.5, 8.0))), false]
	if t < 9.3:
		var x3 := lerpf(park, 284.0, Stage2D._ease_in_out(_k(8.0, 8.5))) - _ring(8.5, 6.0, 20.0, 6.0)
		return [44.0, lerpf(x3, park, Stage2D._ease_in_out(_k(9.0, 9.3))), false]
	return [30.0, lerpf(park, 336.0, Stage2D._ease_in_out(_k(9.3, 9.8))), t > 9.8]


# ---------------------------------------------------------------- 3. the sweep draws the curve

func _set_ty_sweep() -> void:
	var p := _sweep_p()
	var adm := _adm(p, 0.0, 0.9, 70.0)
	var sweeping := t > 4.0
	var bounce := (adm / 0.9) * absf(sin(t * 7.0)) * s._motion if sweeping else 0.0
	# Drummy, bouncing with how easily the drum moves at this pressure
	_trampoline(Vector2(250, 312), 250.0, 10.0 + 22.0 * bounce, _pop(0.1, 0.5), &"wow" if adm > 0.7 and sweeping else &"happy")
	_bouncer(Vector2(250, 284 - 120.0 * bounce), 22.0, _pop(0.3), 0.0)
	# the probe hums 226 Hz at it
	_probe(Vector2(78, 300), 22.0, false, _pop(0.6), 0.0)
	for i in 3:
		var u := fposmod(t * 0.8 + i / 3.0, 1.0)
		if t > 0.9:
			s._note(Vector2(110.0 + 70.0 * u, 270.0 - 30.0 * u), 0.7, Palette.TONE_CYAN.darkened(0.2), sin(t * 3.0 + i) * 0.2)
	s._chip("226 Hz probe tone", Vector2(150, 200), Palette.SKY, 18, Stage2D.INK, _pop(1.0))
	# the pressures on both sides of the drum
	var canal := int(round(p / 5.0) * 5.0)
	var match_now := absi(canal) <= 25 and sweeping
	var ck := _pop(2.4)
	s._chip("canal %s%d daPa" % ["+" if canal > 0 else "", canal], Vector2(150, 404), Palette.MINT if match_now else Palette.PAPER, 18, Stage2D.INK, ck)
	s._chip("middle ear 0", Vector2(350, 404), Palette.MINT if match_now else Palette.PAPER, 18, Stage2D.INK, ck)
	if match_now:
		s._text("MATCH!", Vector2(250, 360), 24, Palette.MINT.darkened(0.3), 700, 7, Palette.PAPER)
	# the tympanogram traces right to left as the pressure falls from +200 to -400
	var gr := Rect2(470, 70, 370, 250)
	var gk := _pop(0.5, 0.5)
	if gk <= 0.01:
		return
	s._push(Stage2D._about(gr.get_center(), 0.0, Vector2.ONE * gk))
	_axes(gr, 1.6)
	if sweeping:
		var pts := PackedVector2Array()
		var q := 200.0
		while q >= p:
			pts.append(_gpt(gr, q, _adm(q, 0.0, 0.9, 70.0), 1.6))
			q -= 10.0
		pts.append(_gpt(gr, p, adm, 1.6))
		if pts.size() >= 2:
			s.draw_polyline(pts, Palette.RIGHT_RED, 5.0, true)
		s._circ(_gpt(gr, p, adm, 1.6), 8.0, Palette.SUNNY, 3.0)
	s._pop_xf()
	var peak := _gpt(gr, 0.0, 0.9, 1.6)
	s._pointer_label("PEAK: the\npressures match", Vector2(gr.position.x + 62.0, gr.position.y + 34.0), peak + Vector2(-8, -10), Palette.MINT.darkened(0.35), _pop(7.4))


## The pump: +200 daPa down to -400 between 4.0 and 12.4 s (CaseRules.TYMP_SWEEP_FROM / _TO).
func _sweep_p() -> float:
	return lerpf(200.0, -400.0, _k(4.0, 12.4))


# ---------------------------------------------------------------- 4. the five shapes

func _set_ty_types() -> void:
	var cur := 0
	for i in SHAPES.size():
		if t >= SHAPE_AT[i]:
			cur = i
	var prev := maxi(0, cur - 1)
	var u := Stage2D._ease_in_out(_k(SHAPE_AT[cur] - 0.2, SHAPE_AT[cur] + 0.3)) if cur > 0 else 1.0
	var a: Array = SHAPES[prev]
	var b: Array = SHAPES[cur]
	var p0 := lerpf(float(a[2]), float(b[2]), u)
	var h := lerpf(float(a[3]), float(b[3]), u)
	var w := lerpf(float(a[4]), float(b[4]), u)
	var gk := _pop(0.1, 0.5)
	if gk > 0.01:
		s._push(Stage2D._about(GRAPH.get_center(), 0.0, Vector2.ONE * gk))
		_axes(GRAPH, 2.6)
		# the normal box: -100 to +50 daPa, 0.3 to 1.7 mL
		var b0 := _gpt(GRAPH, -100.0, 1.7, 2.6)
		var b1 := _gpt(GRAPH, 50.0, 0.3, 2.6)
		s.draw_rect(Rect2(b0, b1 - b0), Color(Palette.MINT, 0.18))
		s.draw_rect(Rect2(b0, b1 - b0), Palette.MINT.darkened(0.25), false, 3.0)
		s._text("normal box", Vector2((b0.x + b1.x) * 0.5, b1.y + 16.0), 14, Palette.MINT.darkened(0.4), 700)
		var pts := PackedVector2Array()
		var q := -400.0
		while q <= 200.0:
			pts.append(_gpt(GRAPH, q, _adm(q, p0, h, w), 2.6))
			q += 8.0
		s.draw_polyline(pts, Palette.RIGHT_RED, 5.0, true)
		s._pop_xf()
	# a cartoon touch for each shape
	var top := _gpt(GRAPH, p0, _adm(p0, p0, h, w), 2.6)
	var fk := _pop(SHAPE_AT[cur] + 0.3, 0.4)
	match String(b[0]):
		"A":
			s.draw_line(top, top + Vector2(0, -40), Stage2D.INK, 3.0, true)
			s.draw_colored_polygon(PackedVector2Array([top + Vector2(0, -40), top + Vector2(26, -32), top + Vector2(0, -24)]), Palette.CORAL)
		"As":
			s._chip("stiff", top + Vector2(0, -34), Palette.SKY, 18, Stage2D.INK, fk)
		"Ad":
			for row in 4:
				for col in 2:
					s._rbox(Rect2(top + Vector2(-12.0 + 14.0 * col, 30.0 + 26.0 * row), Vector2(9, 12)), Palette.SUNNY, 2, 0)
			s._chip("floppy", top + Vector2(70, 10), Palette.SKY, 18, Stage2D.INK, fk)
		"C":
			var z := _gpt(GRAPH, 0.0, 1.9, 2.6)
			if fk > 0.01:
				s._trail(z, z + Vector2(-40, -20), Vector2(top.x + 20.0, z.y), Palette.LEFT_BLUE, _k(SHAPE_AT[cur] + 0.3, SHAPE_AT[cur] + 1.0))
			s._chip("negative pressure", Vector2(top.x - 10.0, z.y - 30.0), Palette.SKY, 17, Stage2D.INK, fk)
		"B":
			var pc := _gpt(GRAPH, -100.0, 0.0, 2.6) + Vector2(0, -14)
			if fk > 0.01:
				s._push(Stage2D._about(pc, 0.0, Vector2.ONE * fk))
				s._blob(pc, Vector2(58, 12), Color("#e8b56a"), 3.0)
				s._rbox(Rect2(pc + Vector2(-12, -18), Vector2(24, 10)), Palette.SUNNY, 3, 2)
				s._pop_xf()
	# the five thumbnails: each lights as the curve becomes it
	for i in SHAPES.size():
		var sh: Array = SHAPES[i]
		var tk := _pop(SHAPE_AT[i], 0.4)
		if tk <= 0.01:
			continue
		var c := Vector2(116.0 + 162.0 * i, 362.0)
		var lit := i == cur
		s._push(Stage2D._about(c, 0.0, Vector2.ONE * tk * (1.06 if lit else 1.0)))
		s._rbox(Rect2(c - Vector2(72, 46), Vector2(144, 92)), Palette.SUNNY if lit else Palette.PAPER, 14, 3)
		var mini := Rect2(c + Vector2(-60, -38), Vector2(56, 52))
		var mp := PackedVector2Array()
		var q2 := -400.0
		while q2 <= 200.0:
			mp.append(_gpt(mini, q2, _adm(q2, float(sh[2]), float(sh[3]), float(sh[4])), 2.6))
			q2 += 25.0
		s.draw_polyline(mp, Palette.RIGHT_RED, 3.0, true)
		s.draw_line(mini.position + Vector2(0, mini.size.y), mini.end, Color(Stage2D.INK, 0.5), 2.0, true)
		s._text(String(sh[0]), c + Vector2(30, -16), 30, Stage2D.INK, 700)
		s._text(String(sh[1]), c + Vector2(0, 28), 15, Stage2D.INK, 700)
		s._pop_xf()


# ---------------------------------------------------------------- 5. the canal-volume cup

func _set_ty_volume() -> void:
	var level := 0.0
	level = lerpf(level, 0.4, Stage2D._ease_in_out(_k(1.5, 2.5)))
	level = lerpf(level, 1.2, Stage2D._ease_in_out(_k(6.6, 7.4)))
	level = lerpf(level, 2.8, Stage2D._ease_in_out(_k(9.6, 10.4)))
	var zone := 0 if level < 0.6 else (1 if level <= 2.0 else 2)
	var ck := _pop(0.1, 0.5)
	if ck > 0.01:
		s._push(Stage2D._about(CUP.get_center(), 0.0, Vector2.ONE * ck))
		# zone bands, the current one tinted
		var bands: Array = [[0.0, 0.6], [0.6, 2.0], [2.0, 3.0]]
		for i in 3:
			var band: Array = bands[i]
			var y0 := _cup_y(float(band[1]))
			var y1 := _cup_y(float(band[0]))
			s.draw_rect(Rect2(CUP.position.x, y0, CUP.size.x, y1 - y0), Color(Palette.SUNNY, 0.35) if i == zone else Color(Palette.PAPER, 0.6))
		var wob := sin(t * 4.0) * 3.0 * s._motion * minf(1.0, level * 4.0)
		var ly := _cup_y(level)
		if level > 0.05:
			s.draw_colored_polygon(PackedVector2Array([Vector2(CUP.position.x, ly + wob), Vector2(CUP.end.x, ly - wob), CUP.end, Vector2(CUP.position.x, CUP.end.y)]), Color(Palette.SKY.darkened(0.15), 0.85))
		s._rbox(CUP, Color(0, 0, 0, 0), 16, 4)
		for ml: float in [0.6, 2.0]:
			var y := _cup_y(ml)
			s.draw_line(Vector2(CUP.position.x - 10.0, y), Vector2(CUP.end.x + 10.0, y), Stage2D.INK, 3.0, true)
			s._text("%.1f" % ml, Vector2(CUP.end.x + 36.0, y), 18, Stage2D.INK, 700)
		s._text("mL", Vector2(CUP.end.x + 34.0, CUP.position.y + 14.0), 16, Palette.INK_SOFT, 700)
		s._text("%.1f mL" % level, Vector2(CUP.get_center().x, CUP.end.y + 22.0), 18, Stage2D.INK, 700)
		s._pop_xf()
	s._chip("Flat B?", Vector2(390, 62), Palette.SKY, 20, Stage2D.INK, _pop(0.6))
	for i in 3:
		var lines: Array = VOLUME_CARDS[i]
		var c := Vector2(626, 130.0 + 104.0 * i)
		_card(c, 380.0, lines, Palette.SUNNY if i == zone and t > VOLUME_AT[i] else Palette.PAPER, _pop(VOLUME_AT[i]), 0.0, 20)
		var ik := _pop(VOLUME_AT[i] + 0.3, 0.4)
		var ic := Vector2(392, c.y)
		match i:
			0:
				if ik > 0.01:
					s._blob(ic, Vector2(26 * ik, 20 * ik), WAX, 3.0, 0.3)
			1:
				_mini_drum(ic, ik, false)
				for j in 3:
					var bu := fposmod(t * 0.7 + j / 3.0, 1.0)
					if ik > 0.5:
						s._circ(ic + Vector2(14.0 + 4.0 * j, 18.0 - 30.0 * bu), 3.0 + j, Color(Palette.SKY, 1.0 - bu), 1.5)
			2:
				_mini_drum(ic, ik, true)


func _cup_y(ml: float) -> float:
	return CUP.end.y - ml / 3.0 * CUP.size.y


# ---------------------------------------------------------------- 6. both ears, and what a tymp is

func _set_ty_compare() -> void:
	var ears: Array = [["RIGHT EAR", Palette.RIGHT_RED, 0.0, 0.9, 70.0, Rect2(96, 92, 300, 200)],
		["LEFT EAR", Palette.LEFT_BLUE, 0.0, 0.0, 80.0, Rect2(484, 92, 300, 200)]]
	for i in 2:
		var e: Array = ears[i]
		var r: Rect2 = e[5]
		var k := _pop(0.3 + 0.5 * i, 0.5)
		if k <= 0.01:
			continue
		s._push(Stage2D._about(r.get_center(), 0.0, Vector2.ONE * k))
		s._rbox(r.grow(14), Palette.PAPER, 16, 3)
		_axes(r, 1.6)
		var pts := PackedVector2Array()
		var q := -400.0
		while q <= 200.0:
			pts.append(_gpt(r, q, _adm(q, float(e[2]), float(e[3]), float(e[4])), 1.6))
			q += 10.0
		var col: Color = e[1]
		s.draw_polyline(pts, col, 5.0, true)
		s._text(String(e[0]), Vector2(r.get_center().x, r.position.y + 14.0), 20, col.darkened(0.15), 700)
		s._pop_xf()
	s._text("vs", Vector2(440, 192), 30, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, _pop(1.4))
	s._hoot(Vector2(440, 356), 34.0, {"pop": _pop(0.2), "mood": &"gasp" if t > 1.6 and t < 3.0 else &"idle"})
	var sk := _pop(4.6, 0.45)
	if sk > 0.01:
		s._big_sign("MOVES, not HEARS!", Vector2(440, 360), sk, sin(t * 3.0) * 0.03 * s._motion, Palette.SUNNY)


# ---------------------------------------------------------------- 7. the curtain call

func _set_ty_bow() -> void:
	_curtain_call(_bow_cast, false)


func _bow_cast(bow: float) -> void:
	s._push(Stage2D._about(Vector2(440, 380), bow * 0.2, Vector2.ONE))
	_trampoline(Vector2(440, 330), 260.0, 14.0, 1.0, &"happy")
	_bouncer(Vector2(440, 290), 22.0, 1.0, bow * 0.5)
	s._pop_xf()


# ---------------------------------------------------------------- props and graphs

## Drummy: the eardrum as a trampoline with a face. c: the middle of the frame's top; dip: how far
## the mat sags (bigger = a bigger bounce).
func _trampoline(c: Vector2, w: float, dip: float, k: float, mood: StringName) -> void:
	if k <= 0.01:
		return
	var rh := w * 0.2
	s._push(Stage2D._about(c + Vector2(0, rh + 50.0), 0.0, Vector2.ONE * k))
	for sd: float in [-1.0, 1.0]:
		s.draw_line(c + Vector2(sd * w * 0.42, rh * 0.3), c + Vector2(sd * w * 0.46, rh + 52.0), Stage2D.INK, 7.0, true)
	s._blob(c, Vector2(w * 0.5, rh), RIM, 4.0)
	s._blob(c + Vector2(0, dip * 0.5), Vector2(w * 0.43, rh * 0.72), DRUM, 3.0)
	for i in 10:
		var a := TAU * i / 10.0
		var p0 := c + Vector2(cos(a) * w * 0.43, sin(a) * rh * 0.72 + dip * 0.5)
		var p1 := c + Vector2(cos(a) * w * 0.5, sin(a) * rh)
		s.draw_line(p0, p1, Color(Stage2D.INK, 0.55), 2.0, true)
	_face(c + Vector2(0, dip * 0.5 + 2.0), rh * 0.55, mood)
	s._pop_xf()


## A little bouncing buddy (c: its middle).
func _bouncer(c: Vector2, r: float, k: float, tilt: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, tilt, Vector2.ONE * k))
	s._circ(c, r, BOUNCER, 3.5)
	_face(c, r, &"happy")
	s._pop_xf()


## The probe: a handle on a cable with a soft tip of radius r at tip (pointing right). seated: the
## tip squeezes snugly into the canal's entrance.
func _probe(tip: Vector2, r: float, seated: bool, k: float, rot: float = 0.0) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(tip, rot, Vector2.ONE * k))
	var back := tip.x - r * 0.7 - 6.0
	var cable := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		cable.append(Vector2(back - 96.0, tip.y).lerp(Vector2(back - 150.0, tip.y + 170.0), u) + Vector2(-30.0 * sin(u * PI), 0))
	s.draw_polyline(cable, Stage2D.INK, 7.0, true)
	s._rbox(Rect2(Vector2(back - 100.0, tip.y - 20.0), Vector2(96, 40)), Stage2D.BONE_GREY, 14, 4)
	s._rbox(Rect2(Vector2(back - 8.0, tip.y - 7.0), Vector2(14, 14)), Stage2D.INK, 3, 0)
	var col := Palette.SUNNY if r < 20.0 else (Palette.SKY if r > 40.0 else Palette.MINT)
	var rx := r * (0.62 if seated else 0.7)
	var ry := minf(r, 27.0) if seated else r
	s._blob(Vector2(back + rx, tip.y), Vector2(rx, ry), col, 3.5)
	s._pop_xf()


## An otoscope pointing right, its speculum tip at c + (56, 0).
func _otoscope(c: Vector2, k: float) -> void:
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._rbox(Rect2(c + Vector2(-20, 6), Vector2(26, 90)), Stage2D.BONE_GREY, 10, 4)
	s._circ(c, 24.0, Stage2D.BONE_GREY, 4.0)
	s.draw_colored_polygon(PackedVector2Array([c + Vector2(18, -12), c + Vector2(56, -5), c + Vector2(56, 5), c + Vector2(18, 12)]), Stage2D.INK)
	s._circ(c, 9.0, Palette.SKY, 3.0)
	s._pop_xf()


## A small round eardrum (hole: with a hole and a tiny ear tube in it).
func _mini_drum(c: Vector2, k: float, hole: bool) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._circ(c, 26.0, DRUM, 3.0)
	if hole:
		s._circ(c + Vector2(-6, 2), 8.0, Stage2D.INK, 0.0)
		s._rbox(Rect2(c + Vector2(6, -8), Vector2(10, 16)), Palette.LEFT_BLUE, 3, 2)
	s._pop_xf()


## A tympanogram's admittance (mL) at pressure p: a bell of height h at p0 on a low floor.
func _adm(p: float, p0: float, h: float, w: float) -> float:
	return 0.05 + h * exp(-pow((p - p0) / w, 2.0))


## A point on a tympanogram drawn in r: pressure -400..+200 daPa across, 0..top mL up.
func _gpt(r: Rect2, p: float, ml: float, top: float) -> Vector2:
	return Vector2(r.position.x + (p + 400.0) / 600.0 * r.size.x, r.end.y - clampf(ml / top, 0.0, 1.05) * r.size.y)


## The axes of a tympanogram in r, with its pressure labels.
func _axes(r: Rect2, top: float) -> void:
	s.draw_rect(r, Stage2D.GRAPH_BG)
	for p: float in [-400.0, -200.0, 0.0, 200.0]:
		var x := _gpt(r, p, 0.0, top).x
		s.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(Stage2D.INK, 0.15 if p != 0.0 else 0.35), 2.0, true)
		s._text("%s%d" % ["+" if p > 0.0 else "", int(p)], Vector2(x, r.end.y + 14.0), 13, Palette.INK_SOFT, 700)
	s.draw_line(r.position + Vector2(0, r.size.y), r.end, Stage2D.INK, 3.0, true)
	s.draw_line(r.position, r.position + Vector2(0, r.size.y), Stage2D.INK, 3.0, true)
	s._text("daPa", Vector2(r.end.x - 4.0, r.end.y + 30.0), 12, Palette.INK_SOFT, 600, 0, Palette.PAPER, 1.0)
