extends "res://story/case_movies/case_movie_sets.gd"
## The sets of "Hoot's audiogram movie" (story/explainers/movies/shapes.gd): how to read the chart,
## the shapes the game names (ClinicRules.classify_shape: sloping, rising, flat, the noise notch,
## the cookie bite) and what bone adds (ClinicRules.hearing_type: sensorineural, conductive, mixed;
## the air-bone gap red flag, ABG_RED_FLAG_DB at 500, 1k and 2k). Every chart below classifies as
## the shape or type its scene names (story/tests/test_cases.gd checks them).

const SETS: Array[StringName] = [&"sh_open", &"sh_grid", &"sh_slopes", &"sh_notch", &"sh_cookie", &"sh_door", &"sh_bow"]

## The big chart, and the small one beside the house: 250 Hz to 8 kHz across (octaves evenly
## spaced), -10 to 120 dB HL down, like the game's audiogram.
const CHART := Rect2(200, 58, 500, 288)
const MINI := Rect2(528, 82, 312, 218)
const DB_TOP := -10.0
const DB_BOTTOM := 120.0
const OCTAVES: Array[float] = [250.0, 500.0, 1000.0, 2000.0, 4000.0, 8000.0]
const OCTAVE_NAMES: Array[String] = ["250", "500", "1k", "2k", "4k", "8k"]
## The charts, as Vector2(Hz, dB HL).
const GRID_RIGHT: Array[Vector2] = [Vector2(250, 10), Vector2(500, 15), Vector2(1000, 20), Vector2(2000, 40), Vector2(4000, 55), Vector2(8000, 65)]
const SLOPING: Array[Vector2] = [Vector2(250, 10), Vector2(500, 15), Vector2(1000, 25), Vector2(2000, 45), Vector2(4000, 60), Vector2(8000, 70)]
const RISING: Array[Vector2] = [Vector2(250, 55), Vector2(500, 45), Vector2(1000, 35), Vector2(2000, 25), Vector2(4000, 20), Vector2(8000, 20)]
const FLAT: Array[Vector2] = [Vector2(250, 40), Vector2(500, 40), Vector2(1000, 45), Vector2(2000, 45), Vector2(4000, 40), Vector2(8000, 45)]
const NOTCH_FROM: Array[Vector2] = [Vector2(250, 10), Vector2(500, 10), Vector2(1000, 15), Vector2(2000, 20), Vector2(3000, 20), Vector2(4000, 20), Vector2(6000, 20), Vector2(8000, 25)]
const NOTCH: Array[Vector2] = [Vector2(250, 10), Vector2(500, 10), Vector2(1000, 15), Vector2(2000, 20), Vector2(3000, 40), Vector2(4000, 55), Vector2(6000, 45), Vector2(8000, 25)]
const COOKIE_FROM: Array[Vector2] = [Vector2(250, 20), Vector2(500, 25), Vector2(1000, 25), Vector2(2000, 25), Vector2(4000, 25), Vector2(8000, 25)]
const COOKIE: Array[Vector2] = [Vector2(250, 20), Vector2(500, 25), Vector2(1000, 45), Vector2(2000, 50), Vector2(4000, 30), Vector2(8000, 25)]
## The house scene's right ear: air, then bone (500 to 4k), for each type of loss.
const SNHL_AIR: Array[Vector2] = [Vector2(250, 20), Vector2(500, 30), Vector2(1000, 40), Vector2(2000, 50), Vector2(4000, 60), Vector2(8000, 65)]
const SNHL_BONE: Array[Vector2] = [Vector2(500, 25), Vector2(1000, 40), Vector2(2000, 45), Vector2(4000, 60)]
const CONDUCTIVE_AIR: Array[Vector2] = [Vector2(250, 45), Vector2(500, 45), Vector2(1000, 40), Vector2(2000, 35), Vector2(4000, 40), Vector2(8000, 40)]
const CONDUCTIVE_BONE: Array[Vector2] = [Vector2(500, 5), Vector2(1000, 5), Vector2(2000, 10), Vector2(4000, 5)]
const MIXED_AIR: Array[Vector2] = [Vector2(250, 60), Vector2(500, 65), Vector2(1000, 65), Vector2(2000, 70), Vector2(4000, 75), Vector2(8000, 80)]
const MIXED_BONE: Array[Vector2] = [Vector2(500, 30), Vector2(1000, 35), Vector2(2000, 45), Vector2(4000, 50)]
## When the house scene changes type: sensorineural, conductive, mixed, then the red flag.
const DOOR_AT: Array[float] = [5.8, 8.6, 11.4, 14.0]
const NOTCH_HITS: Array[float] = [1.2, 1.9, 2.6, 3.3]

const COOKIE_DOUGH := Color("#d9a35b")
const COOKIE_CHIP := Color("#5a3a1e")
## What shows through a bite out of a cookie on the stage (the screen's cream).
const STAGE_BG := Color("#fbf1df")
const JAR := Color("#bfe3f2")


# ---------------------------------------------------------------- 1. the lead-in

func _set_sh_open() -> void:
	_marquee("HOOT'S AUDIOGRAM MOVIE", "Slopes, Notches", "& Cookie Bites", "starring the Os, the Xs and a cookie", _prop_cookie)
	var t0 := float(params.get("card_hold", 8.0)) + 0.3
	var hop := func(ph: float) -> float: return -absf(sin((t - t0) * 5.0 + ph)) * 22.0 * s._motion if t > t0 + 0.6 else 0.0
	_mascot_o(Vector2(300, 240 + hop.call(0.0)), 60.0, _pop(t0, 0.5), &"happy", sin(t * 3.0) * 0.08 * s._motion)
	_cookie(Vector2(440, 300 + hop.call(1.0)), 44.0, _pop(t0 + 0.5, 0.5), 1.0, STAGE_BG, &"wow")
	_mascot_x(Vector2(580, 240 + hop.call(2.0)), 60.0, _pop(t0 + 0.25, 0.5), &"happy", -sin(t * 3.0) * 0.08 * s._motion)
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(t0 + 0.6), "mood": &"wave"})


func _prop_cookie(at: Vector2) -> void:
	_cookie(at, 46.0, 1.0, 1.0, CARD_FILL, &"happy")


# ---------------------------------------------------------------- 2. how to read the chart

func _set_sh_grid() -> void:
	var gk := _pop(0.1, 0.5)
	_chart(CHART, gk, _k(10.4, 11.2))
	if gk < 0.99:
		return
	# pitch: low to high, left to right
	var ak := _k(0.8, 1.8)
	_arrow(Vector2(300, 386), Vector2(600, 386), Palette.INK_SOFT, Stage2D._ease_out(ak))
	s._text("low pitch", Vector2(288, 386), 17, Palette.INK_SOFT, 700, 0, Palette.PAPER, 1.0, _pop(0.8))
	s._text("high pitch", Vector2(612, 386), 17, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.0, _pop(1.6))
	s._note(Vector2(190, 406), 1.2 * _pop(1.0), Palette.TONE_CYAN.darkened(0.2), -0.2)
	s._note(Vector2(724, 406), 0.7 * _pop(1.8), Palette.TONE_CYAN.darkened(0.2), 0.2)
	# loudness: soft at the top, loud below
	_arrow(Vector2(120, 96), Vector2(120, 290), Palette.INK_SOFT, Stage2D._ease_out(_k(2.8, 3.8)))
	s._chip("soft", Vector2(120, 76), Palette.PAPER, 16, Stage2D.INK, _pop(2.8))
	s._chip("LOUD", Vector2(120, 312), Palette.CORAL, 18, Stage2D.INK, _pop(3.8))
	# the right ear's Os, then the left ear's Xs
	_plot(CHART, GRID_RIGHT, "right", &"ac", 5.8, 0.25)
	_plot(CHART, SLOPING, "left", &"ac", 7.2, 0.25)
	s._chip("O = right ear", Vector2(330, 262), Color(Palette.RIGHT_RED, 0.25).blend(Color(Palette.PAPER, 0.75)), 17, Palette.RIGHT_RED.darkened(0.25), _pop(5.8))
	s._chip("X = left ear", Vector2(330, 300), Color(Palette.LEFT_BLUE, 0.25).blend(Color(Palette.PAPER, 0.75)), 17, Palette.LEFT_BLUE.darkened(0.25), _pop(7.2))
	var p8 := _ax(CHART, 8000.0, 70.0)
	s._pointer_label("lower = a\nbigger loss", Vector2(560, 306), p8 + Vector2(-10, 12), Palette.CORAL.darkened(0.3), _pop(8.8))
	# the normal band
	var nk := _pop(10.6)
	if nk > 0.01:
		s._chip("normal: down to 25 dB", Vector2(590, _ax(CHART, 250.0, 7.0).y), Palette.MINT, 17, Stage2D.INK, nk)


# ---------------------------------------------------------------- 3. sloping, rising, flat

func _set_sh_slopes() -> void:
	var curve := _slope_curve()
	_chart(CHART, _pop(0.0, 0.4), 0.0)
	_plot(CHART, curve, "right", &"ac", 0.2, 0.06)
	var shape := "SLOPING" if t < 6.3 else ("RISING" if t < 9.3 else "FLAT")
	var col := Palette.SUNNY if t < 6.3 else (Palette.SKY if t < 9.3 else Palette.MINT)
	var since := 0.4 if t < 6.3 else (6.3 if t < 9.3 else 9.3)
	s._chip(shape, Vector2(450, 84), col, 24, Stage2D.INK, _pop(since, 0.4))
	# the skier: down the slope, back down the rising line (leftwards), then a slow glide on the flat
	var u := 0.0
	var dir := 1.0
	if t < 6.0:
		u = pow(_k(1.0, 5.0), 1.6)
	elif t < 9.0:
		u = 1.0 - pow(_k(7.0, 8.8), 1.6)
		dir = -1.0 if t > 6.8 else 1.0
	else:
		u = 0.5 * _k(9.8, 11.8)
	var f := 250.0 * pow(32.0, u)
	var p := _ax(CHART, f, _db_at(curve, f))
	var f2 := minf(f * 1.08, 8000.0)
	var f1 := f2 / 1.08
	var ang := (_ax(CHART, f2, _db_at(curve, f2)) - _ax(CHART, f1, _db_at(curve, f1))).angle()
	_skier(p + Vector2(0, -4), ang, dir, _pop(0.6))
	if t > 4.6 and t < 6.2:
		s._text("WHEEE!", p + Vector2(-40, -70), 26, Palette.CORAL.darkened(0.15), 700, 7, Palette.PAPER, 0.5, _pop(4.6, 0.3))
	if t < 6.0:
		s._pointer_label("good lows", Vector2(300, 200), _ax(CHART, 350.0, 12.0) + Vector2(0, 14), Palette.MINT.darkened(0.4), _pop(2.0))
		s._pointer_label("poor highs", Vector2(560, 318), _ax(CHART, 8000.0, 70.0) + Vector2(-8, 14), Palette.CORAL.darkened(0.3), _pop(3.0))
	elif t < 9.0:
		s._pointer_label("poor lows", Vector2(320, 300), _ax(CHART, 250.0, 55.0) + Vector2(4, 14), Palette.CORAL.darkened(0.3), _pop(6.6))
		s._pointer_label("better highs", Vector2(590, 290), _ax(CHART, 8000.0, 20.0) + Vector2(-6, 14), Palette.MINT.darkened(0.4), _pop(7.2))
	else:
		s._chip("about the same everywhere", Vector2(450, 270), Palette.PAPER, 18, Stage2D.INK, _pop(9.6))


## Sloping, then (6.0 to 6.6) rising, then (9.0 to 9.6) flat.
func _slope_curve() -> Array[Vector2]:
	var c := _mix(SLOPING, RISING, Stage2D._ease_in_out(_k(6.0, 6.6)))
	return _mix(c, FLAT, Stage2D._ease_in_out(_k(9.0, 9.6)))


# ---------------------------------------------------------------- 4. the noise notch

func _set_sh_notch() -> void:
	var depth := 0.0
	var last_hit := -1.0
	for h: float in NOTCH_HITS:
		depth += Stage2D._ease_out(_k(h, h + 0.18)) / NOTCH_HITS.size()
		if t >= h:
			last_hit = h
	var curve := _mix(NOTCH_FROM, NOTCH, depth)
	_chart(CHART, _pop(0.1, 0.5), 0.0, true)
	_plot(CHART, curve, "left", &"ac", 0.3, 0.06)
	# the drum, and the noise it throws at 3 to 6k
	var drum := Vector2(790, 214)
	var dk := _pop(0.4, 0.5)
	var hit := 0.0
	if last_hit >= 0.0 and t < 7.4:
		hit = 1.0 - _k(last_hit, last_hit + 0.25)
	_drum(drum, dk, hit)
	for h: float in NOTCH_HITS:
		if t > h and t < h + 0.8:
			var w := _k(h, h + 0.7)
			for j in 2:
				var rr := 40.0 + 200.0 * w - 26.0 * j
				if rr > 30.0:
					s.draw_arc(drum, rr, PI - 0.42, PI + 0.42, 16, Color(Stage2D.NOISE, (1.0 - w) * 0.9), 6.0, true)
	if last_hit >= 0.0 and t < last_hit + 0.6 and t < 4.2:
		s._text("BOOM!", drum + Vector2(0, -96), 30, Palette.SUNNY, 700, 9, Stage2D.INK, 0.5, _pop(last_hit, 0.25))
	var dip := _ax(CHART, 4000.0, _db_at(curve, 4000.0))
	s._chip("NOISE NOTCH", dip + Vector2(-10, 56), Palette.SUNNY, 22, Stage2D.INK, _pop(4.2))
	s._pointer_label("back up at 8k!", Vector2(600, 74), _ax(CHART, 8000.0, 25.0) + Vector2(-6, -16), Palette.MINT.darkened(0.4), _pop(5.0))
	# earplugs: protect what's left
	var ek := _pop(8.4, 0.5)
	if ek > 0.01:
		for i in 2:
			_earplug(Vector2(778.0 + 44.0 * i, 344.0), ek, (i * 2 - 1) * 0.35)
		s._chip("EARPLUGS!", Vector2(800, 396), Palette.MINT, 18, Stage2D.INK, _pop(8.8))
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(0.3), "mood": &"gasp" if t > 1.2 and t < 3.8 else (&"cheer" if t > 8.6 else &"idle")})


# ---------------------------------------------------------------- 5. the cookie bite

func _set_sh_cookie() -> void:
	var chomp := Stage2D._ease_out(_k(2.0, 2.35))
	var curve := _mix(COOKIE_FROM, COOKIE, chomp)
	_chart(CHART, _pop(0.1, 0.5), 0.0)
	# the bite marks: where the line was, scalloped down to where it is now
	if chomp > 0.01:
		for f: float in [1000.0, 1414.0, 2000.0]:
			var top := _ax(CHART, f, _db_at(COOKIE_FROM, f))
			var r := (_ax(CHART, f, _db_at(curve, f)).y - top.y) * 0.92
			if r > 4.0:
				var half := PackedVector2Array()
				for i in 13:
					var a := PI * i / 12.0
					half.append(top + Vector2(cos(a), sin(a)) * r)
				s.draw_colored_polygon(half, Color(Palette.SUNNY, 0.3))
				s.draw_arc(top, r, 0.0, PI, 16, Color(Stage2D.INK, 0.45), 2.5, true)
		for i in 7:
			var u := _k(2.0 + 0.08 * i, 3.4 + 0.08 * i)
			if u > 0.0 and u < 1.0:
				var c0 := _ax(CHART, 1000.0 * pow(2.0, Stage2D._hash(i, 7)), 30.0)
				s.draw_circle(c0 + Vector2((Stage2D._hash(i, 8) - 0.5) * 50.0, 150.0 * u * u), 4.0, Color(COOKIE_DOUGH.darkened(0.2), 1.0 - u), true, -1.0, true)
	_plot(CHART, curve, "right", &"ac", 0.3, 0.06)
	if t > 2.0 and t < 3.4:
		s._text("CHOMP!", _ax(CHART, 1414.0, 0.0), 40, Palette.CORAL, 700, 10, Stage2D.INK, 0.5, _pop(2.0, 0.25))
	# the cookie that matches the chart's bite
	var cx := lerpf(960.0, 796.0, Stage2D._ease_out(_k(0.6, 1.3)))
	var bite := 1.0 if t >= 2.0 else 0.0
	_cookie(Vector2(cx, 262 + _ring(2.0, 8.0, 14.0, 6.0)), 50.0, 1.0 if t > 0.6 else 0.0, bite, STAGE_BG, &"wow" if t > 2.0 and t < 3.4 else &"happy")
	s._chip("COOKIE BITE!", Vector2(796, 338), Palette.SUNNY, 19, Stage2D.INK, _pop(2.6))
	# runs in families; the middle pitches carry lots of speech
	_family(Vector2(796, 120), _pop(6.0, 0.5))
	s._pointer_label("lots of speech\nlives here!", Vector2(450, 300), _ax(CHART, 1414.0, 48.0) + Vector2(0, 16), Palette.PLUM, _pop(8.0))
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(0.3), "mood": &"gasp" if t > 2.0 and t < 3.2 else &"idle"})


# ---------------------------------------------------------------- 6. what bone adds: the house

func _set_sh_door() -> void:
	var phase := 0
	for i in DOOR_AT.size():
		if t >= DOOR_AT[i]:
			phase = i + 1
	var blocked := phase >= 2
	var tired := phase == 1 or phase >= 3
	var hk := _pop(0.1, 0.5)
	_house(hk, blocked, tired)
	if hk < 0.99:
		return
	# air beeps: in at the front door, through to the back room (or stopped by the jar)
	if t > 0.8:
		var path := PackedVector2Array([Vector2(-10, 296), Vector2(60, 296), Vector2(206, 296), Vector2(286, 288)])
		for i in 3:
			var u := fposmod((t - 0.8) * 0.42 + i / 3.0, 1.0)
			var a := 1.0
			if blocked:
				u *= 0.2
				a = 1.0 - u / 0.2
			var c := _along(path, u)
			s._note(c + Vector2(0, -10.0 * sin(u * TAU * 2.0) * s._motion), 0.9, Color(Palette.TONE_CYAN.darkened(0.2), a), sin(t * 3.0 + i) * 0.2)
	s._chip("AIR: the front door", Vector2(150, 380), Palette.SKY, 18, Stage2D.INK, _pop(0.8))
	# bone beeps: the buzzer on the wall shakes straight through to the cochlea
	var bk := _pop(2.6, 0.4)
	if bk > 0.01:
		var vib := Vector2(448, 240)
		s._rbox(Rect2(vib - Vector2(10, 20) * bk, Vector2(28, 40) * bk), Stage2D.BONE_GREY, 6, 3)
		if t > 2.9:
			for j in 3:
				var w := fposmod((t - 2.9) * 0.9 + j / 3.0, 1.0)
				s.draw_arc(vib, 22.0 + 104.0 * w, PI - 0.5, PI + 0.5, 12, Color(Palette.PLUM, (1.0 - w) * 0.85), 4.0, true)
		s._chip("BONE: through the wall", Vector2(366, 380), Palette.PLUM, 18, Palette.PAPER, _pop(2.6))
	# the chart beside the house
	var mk := _pop(5.6, 0.5)
	_chart(MINI, mk, 0.0, false, 12)
	if mk < 0.99:
		return
	var air := _mix(_mix(SNHL_AIR, CONDUCTIVE_AIR, Stage2D._ease_in_out(_k(DOOR_AT[1], DOOR_AT[1] + 0.6))), MIXED_AIR, Stage2D._ease_in_out(_k(DOOR_AT[2], DOOR_AT[2] + 0.6)))
	var bone := _mix(_mix(SNHL_BONE, CONDUCTIVE_BONE, Stage2D._ease_in_out(_k(DOOR_AT[1], DOOR_AT[1] + 0.6))), MIXED_BONE, Stage2D._ease_in_out(_k(DOOR_AT[2], DOOR_AT[2] + 0.6)))
	var gk := _k(DOOR_AT[1] + 0.6, DOOR_AT[1] + 1.0)
	if gk > 0.0:
		for b: Vector2 in bone:
			var y0 := _ax(MINI, b.x, b.y).y + 11.0
			var y1 := _ax(MINI, b.x, _db_at(air, b.x)).y - 11.0
			if y1 - y0 > 6.0:
				var x := _ax(MINI, b.x, 0.0).x
				s.draw_line(Vector2(x, y0), Vector2(x, y1), Color(Palette.SUNNY, 0.85 * gk), 9.0, true)
		var g1 := _ax(MINI, 1000.0, (_db_at(bone, 1000.0) + _db_at(air, 1000.0)) * 0.5)
		s._text("gap", g1 + Vector2(-26, 0), 14, Color(Palette.INK_SOFT, gk), 700, 4, Palette.PAPER, 1.0)
	_plot(MINI, air, "right", &"ac", 5.9, 0.1, 18.0)
	_plot(MINI, bone, "right", &"bc", 6.6, 0.12, 18.0)
	s._chip("O air    < bone", Vector2(684, 54), Palette.PAPER, 16, Stage2D.INK, _pop(5.9))
	var types: Array = [["SENSORINEURAL: the inner ear", Palette.SKY], ["CONDUCTIVE: something blocks", Palette.SUNNY], ["MIXED: both", Palette.CORAL]]
	var ti := clampi(phase - 1, 0, 2)
	var ty: Array = types[ti]
	s._chip(String(ty[0]), Vector2(684, 346), ty[1], 18, Stage2D.INK, _pop(DOOR_AT[ti] + (0.0 if ti == 0 else 0.4)))
	# a big gap at 500, 1k and 2k: red flag
	var fk := _pop(DOOR_AT[3], 0.4)
	if fk > 0.01:
		var base := _ax(MINI, 1000.0, _db_at(bone, 1000.0)) + Vector2(6, -14)
		_flag(base, fk)
		s._chip("15+ gap at 500, 1k, 2k: RED FLAG", Vector2(684, 394), Palette.PAPER, 16, FLAG_RED.darkened(0.2), _pop(DOOR_AT[3] + 0.3))


# ---------------------------------------------------------------- 7. the curtain call

func _set_sh_bow() -> void:
	_curtain_call(_bow_cast, false)


func _bow_cast(bow: float) -> void:
	s._push(Stage2D._about(Vector2(440, 380), bow * 0.2, Vector2.ONE))
	_mascot_o(Vector2(290, 240), 62.0, 1.0, &"happy", bow * 0.3)
	_cookie(Vector2(440, 290), 48.0, 1.0, 1.0, STAGE_BG, &"happy")
	_mascot_x(Vector2(590, 240), 62.0, 1.0, &"happy", -bow * 0.3)
	s._pop_xf()


# ---------------------------------------------------------------- the chart

## Where (Hz, dB HL) sits on chart r.
func _ax(r: Rect2, f: float, db: float) -> Vector2:
	var pad := r.size.x * 0.06
	return Vector2(r.position.x + pad + log(f / 250.0) / log(32.0) * (r.size.x - 2.0 * pad),
		r.position.y + (db - DB_TOP) / (DB_BOTTOM - DB_TOP) * r.size.y)


## The empty chart (k: pops in; band: the normal band, -10 to 25 dB; halves: the 3k and 6k lines).
func _chart(r: Rect2, k: float, band: float, halves: bool = false, px: int = 14) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(r.get_center(), 0.0, Vector2.ONE * k))
	s._rbox(r.grow(8), Palette.PAPER, 12, 3)
	s.draw_rect(r, Stage2D.GRAPH_BG)
	if band > 0.01:
		var top := r.position.y
		var y25 := _ax(r, 250.0, 25.0).y
		s.draw_rect(Rect2(r.position.x, top, r.size.x, y25 - top), Color(Palette.MINT, 0.3 * band))
		s.draw_line(Vector2(r.position.x, y25), Vector2(r.end.x, y25), Color(Palette.MINT.darkened(0.3), band), 3.0, true)
	var db := DB_TOP
	while db <= DB_BOTTOM:
		var y := _ax(r, 250.0, db).y
		s.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Stage2D.INK, 0.1), 1.5, true)
		if int(db) % 20 == 0:
			s._text(str(int(db)), Vector2(r.position.x - 8.0, y), px, Palette.INK_SOFT, 700, 0, Palette.PAPER, 1.0)
		db += 10.0
	for i in OCTAVES.size():
		var x := _ax(r, OCTAVES[i], 0.0).x
		s.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(Stage2D.INK, 0.16), 2.0, true)
		s._text(OCTAVE_NAMES[i], Vector2(x, r.end.y + px + 2.0), px, Palette.INK_SOFT, 700)
	if halves:
		for f: float in [3000.0, 6000.0]:
			var xh := _ax(r, f, 0.0).x
			s.draw_dashed_line(Vector2(xh, r.position.y), Vector2(xh, r.end.y), Color(Stage2D.INK, 0.16), 1.5, 6.0, true, true)
			s._text("%dk" % int(f / 1000.0), Vector2(xh, r.end.y + px + 2.0), px - 2, Palette.INK_SOFT, 600)
	s._text("dB", Vector2(r.position.x - 8.0, r.position.y - 16.0), px - 1, Palette.INK_SOFT, 600, 0, Palette.PAPER, 1.0)
	s._text("Hz", Vector2(r.end.x + 4.0, r.end.y + px + 2.0), px - 1, Palette.INK_SOFT, 600, 0, Palette.PAPER, 0.0)
	s._pop_xf()


## One ear's results: test &"ac" (joined by a line) or &"bc" (symbols beside the frequency line, not
## joined). Point i pops at t0 + gap * i.
func _plot(r: Rect2, curve: Array[Vector2], ear: String, test: StringName, t0: float, gap: float, px: float = 22.0) -> void:
	var pts := PackedVector2Array()
	var ks: Array[float] = []
	for i in curve.size():
		var k := _pop(t0 + gap * i, 0.35)
		if k <= 0.01:
			break
		ks.append(k)
		pts.append(_ax(r, curve[i].x, curve[i].y))
	if test == &"ac" and pts.size() >= 2:
		s.draw_polyline(pts, Palette.ear_color(ear), 3.5, true)
	for i in pts.size():
		var c := pts[i] + UiDraw.symbol_offset(ear, test, px)
		s._push(Stage2D._about(c, 0.0, Vector2.ONE * ks[i]))
		if test == &"ac" and ear != "left":
			s.draw_circle(c, px * 0.5, Stage2D.GRAPH_BG, true, -1.0, true)
		UiDraw.audiogram_symbol(s, c, ear, test, px, 3.5)
		s._pop_xf()


## dB at any frequency along a chart (straight between its points on the octave scale).
func _db_at(curve: Array[Vector2], f: float) -> float:
	for i in curve.size() - 1:
		var a := curve[i]
		var b := curve[i + 1]
		if f <= b.x:
			return lerpf(a.y, b.y, clampf(log(f / a.x) / log(b.x / a.x), 0.0, 1.0))
	return curve[curve.size() - 1].y


## Two charts with the same frequencies, part way from a to b.
func _mix(a: Array[Vector2], b: Array[Vector2], u: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in a.size():
		out.append(Vector2(a[i].x, lerpf(a[i].y, b[i].y, u)))
	return out


## A point u (0..1) of the way along a path.
func _along(path: PackedVector2Array, u: float) -> Vector2:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	var d := u * total
	for i in path.size() - 1:
		var seg := path[i].distance_to(path[i + 1])
		if d <= seg:
			return path[i].lerp(path[i + 1], d / seg)
		d -= seg
	return path[path.size() - 1]


func _arrow(a: Vector2, b: Vector2, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	var e := a.lerp(b, k)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	s.draw_line(a, e - d * 4.0, col, 4.0, true)
	s.draw_colored_polygon(PackedVector2Array([e + d * 8.0, e - d * 8.0 + n * 9.0, e - d * 8.0 - n * 9.0]), col)


# ---------------------------------------------------------------- the cast and props

## A big red O (the right ear's symbol) with a face in its middle.
func _mascot_o(c: Vector2, r: float, k: float, mood: StringName, tilt: float = 0.0) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, tilt, Vector2.ONE * k))
	s._circ(c, r, Palette.RIGHT_RED, 4.0)
	s._circ(c, r * 0.6, Palette.PAPER, 4.0)
	_face(c, r * 0.52, mood)
	s._pop_xf()


## A big blue X (the left ear's symbol) with a face where its bars cross.
func _mascot_x(c: Vector2, r: float, k: float, mood: StringName, tilt: float = 0.0) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, tilt, Vector2.ONE * k))
	for a: float in [PI * 0.25, -PI * 0.25]:
		s._push(Stage2D._about(c, a, Vector2.ONE))
		s._rbox(Rect2(c - Vector2(r * 1.15, r * 0.28), Vector2(r * 2.3, r * 0.56)), Palette.LEFT_BLUE, int(r * 0.2), 4)
		s._pop_xf()
	s._circ(c, r * 0.5, Palette.PAPER, 4.0)
	_face(c, r * 0.44, mood)
	s._pop_xf()


## A choc-chip cookie with a face. bite (0 or 1): a chomp out of its top right, showing bg.
func _cookie(c: Vector2, r: float, k: float, bite: float, bg: Color, mood: StringName) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._circ(c, r, COOKIE_DOUGH, 4.0)
	for i in 7:
		var a := TAU * (i + 0.5 * Stage2D._hash(i, 3)) / 7.0
		s._ell(c + Vector2(cos(a), sin(a)) * r * (0.62 + 0.18 * Stage2D._hash(i, 4)), Vector2(r * 0.1, r * 0.075), COOKIE_CHIP, a)
	if bite > 0.5:
		var bites: Array[Vector2] = []
		for j in 3:
			var a := -1.15 + 0.55 * j
			bites.append(c + Vector2(cos(a), sin(a)) * r * 1.0)
		for bc: Vector2 in bites:
			s.draw_circle(bc, r * 0.3, bg, true, -1.0, true)
		for bc: Vector2 in bites:
			var inward := (c - bc).angle()
			s.draw_arc(bc, r * 0.3, inward - 1.05, inward + 1.05, 12, Stage2D.INK, 3.0, true)
	_face(c + Vector2(-r * 0.08, r * 0.06), r * 0.5, mood)
	s._pop_xf()


## A little skier standing at c (where the skis touch), skis along angle ang, facing dir (+1 right).
func _skier(c: Vector2, ang: float, dir: float, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._xform(c, ang, Vector2(dir * k, k) * 1.35))
	s.draw_line(Vector2(-24, 0), Vector2(22, 0), Stage2D.INK, 4.0, true)
	s.draw_line(Vector2(22, 0), Vector2(29, -6), Stage2D.INK, 4.0, true)
	s.draw_line(Vector2(-2, -2), Vector2(2, -12), Stage2D.INK, 4.0, true)
	s.draw_line(Vector2(9, -20), Vector2(20, 2), Stage2D.INK, 2.5, true)
	s._circ(Vector2(2, -24), 13.0, Palette.SUNNY, 3.0)
	_face(Vector2(4, -23), 10.0, &"happy")
	var hat := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		hat.append(Vector2(2, -27) + Vector2(cos(a), sin(a)) * 13.5)
	s.draw_colored_polygon(hat, Palette.CORAL)
	s.draw_circle(Vector2(2, -42), 4.5, Palette.PAPER, true, -1.0, true)
	s._pop_xf()


## A bass drum with a beater (hit 1 = just struck: the skin squashes).
func _drum(c: Vector2, k: float, hit: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2(1.0 + 0.06 * hit * s._motion, 1.0 - 0.06 * hit * s._motion) * k))
	s._circ(c, 62.0, Palette.CORAL, 5.0)
	s._circ(c, 48.0, Palette.PAPER, 3.0)
	s._circ(c, 10.0, Palette.CORAL, 0.0)
	for i in 8:
		var a := TAU * i / 8.0
		s.draw_circle(c + Vector2(cos(a), sin(a)) * 56.0, 3.0, Palette.SUNNY, true, -1.0, true)
	s.draw_line(c + Vector2(-40, 56), c + Vector2(-60, 92), Stage2D.INK, 5.0, true)
	s.draw_line(c + Vector2(40, 56), c + Vector2(60, 92), Stage2D.INK, 5.0, true)
	# the beater: its grip up and to the right, its head on the drum's middle when it strikes
	var grip := c + Vector2(66, -66)
	var aim := (c - grip).angle() + 0.9 * (1.0 - hit)
	var head := grip + Vector2(cos(aim), sin(aim)) * 72.0
	s.draw_line(grip + Vector2(cos(aim), sin(aim)) * -14.0, head, WOOD_DARK, 6.0, true)
	s._circ(head, 11.0, Palette.PAPER, 3.0)
	s._pop_xf()


## A foam earplug, rolled and ready.
func _earplug(c: Vector2, k: float, rot: float) -> void:
	s._push(Stage2D._about(c, rot, Vector2.ONE * k))
	s._rbox(Rect2(c - Vector2(13, 26), Vector2(26, 52)), Palette.SUNNY, 12, 3)
	_face(c + Vector2(0, -4), 10.0, &"happy")
	s._pop_xf()


## A framed family portrait: three matching smiles (cookie bites often run in families).
func _family(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._rbox(Rect2(c - Vector2(74, 50), Vector2(148, 100)), WOOD_DARK, 10, 3)
	s._rbox(Rect2(c - Vector2(62, 38), Vector2(124, 76)), Palette.PAPER, 6, 2)
	var faces: Array = [[Vector2(-34, 0), 17.0], [Vector2(34, 0), 17.0], [Vector2(0, 10), 13.0]]
	for fc: Array in faces:
		var p: Vector2 = c + fc[0]
		s._circ(p, fc[1], Palette.SKIN, 3.0)
		_face(p, fc[1] * 0.9, &"happy")
	s._text("runs in families", c + Vector2(0, 66), 15, Palette.INK_SOFT, 700, 5, Palette.PAPER)
	s._pop_xf()


## The house: the front room is the outer and middle ear (its front door lets air beeps in), the
## back room holds the cochlea. blocked: a jam jar stuck in the door; tired: the cochlea is worn.
func _house(k: float, blocked: bool, tired: bool) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(Vector2(246, 240), 0.0, Vector2.ONE * k))
	s.draw_colored_polygon(PackedVector2Array([Vector2(36, 134), Vector2(246, 52), Vector2(456, 134)]), Palette.CORAL)
	s.draw_polyline(PackedVector2Array([Vector2(36, 134), Vector2(246, 52), Vector2(456, 134), Vector2(36, 134)]), Stage2D.INK, 4.0, true)
	s._rbox(Rect2(56, 134, 380, 206), Palette.PAPER, 4, 4)
	s.draw_rect(Rect2(206, 134, 230, 206), Color(Palette.SKY, 0.18))
	# the front door (a gap in the left wall, the door swung open) and the inner doorway
	s.draw_rect(Rect2(50, 256, 14, 80), Palette.PAPER)
	s.draw_colored_polygon(PackedVector2Array([Vector2(56, 256), Vector2(30, 248), Vector2(30, 344), Vector2(56, 336)]), Palette.WOOD)
	s.draw_polyline(PackedVector2Array([Vector2(56, 256), Vector2(30, 248), Vector2(30, 344), Vector2(56, 336)]), Stage2D.INK, 3.0, true)
	s.draw_line(Vector2(206, 134), Vector2(206, 254), Stage2D.INK, 4.0, true)
	s._text("outer + middle ear", Vector2(131, 160), 15, Palette.INK_SOFT, 700)
	s._text("inner ear", Vector2(321, 160), 15, Palette.INK_SOFT, 700)
	s._push(Stage2D._about(Vector2(330, 300), 0.0, Vector2.ONE * 0.7))
	s._snail(Vector2(330, 300), -1.0, Palette.RIGHT_RED, Stage2D.RIGHTY_BODY, {"mood": &"sleep" if tired else &"happy"})
	s._pop_xf()
	s._text("cochlea", Vector2(330, 326), 14, Palette.RIGHT_RED.darkened(0.2), 700, 4, Palette.PAPER)
	if blocked:
		var jk := _pop(DOOR_AT[1], 0.4)
		var jc := Vector2(56, 300)
		s._push(Stage2D._about(jc, 0.0, Vector2.ONE * jk))
		s._rbox(Rect2(jc - Vector2(26, 30), Vector2(52, 66)), Color(JAR, 0.92), 10, 3)
		s._rbox(Rect2(jc - Vector2(29, 44), Vector2(58, 16)), Palette.CORAL, 4, 3)
		s._text("JAM", jc + Vector2(0, 6), 15, Stage2D.INK, 700)
		s._pop_xf()
	s._pop_xf()


## A red flag on a little pole planted at base.
func _flag(base: Vector2, k: float) -> void:
	s._push(Stage2D._about(base, 0.0, Vector2.ONE * k))
	s.draw_line(base, base + Vector2(0, -54), Stage2D.INK, 3.5, true)
	var wv := sin(t * 6.0) * 4.0 * s._motion
	s.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -54), base + Vector2(34, -46 + wv), base + Vector2(0, -36)]), FLAG_RED)
	s._pop_xf()
