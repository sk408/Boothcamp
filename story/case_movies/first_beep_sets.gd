extends "res://story/case_movies/case_movie_sets.gd"
## The sets of Hoot's Day 1 movie, "The First Beep" (story/explainers/movies/first_beep.gd, clinical
## review D1-8): the path a beep takes into the ear (the masking movie's built-in "air" scene, with
## its stops named), how to read the audiogram (borrowed from the shapes movie's chart scene), look
## before you beep, and the down 10, up 5 search with two answers going up. The ladder's numbers
## come from the scene's params.

const ShapesSets := preload("res://story/case_movies/shapes_sets.gd")

const SETS: Array[StringName] = [&"fb_open", &"fb_path", &"fb_chart", &"fb_look", &"fb_ladder", &"fb_bow"]

const CANAL := Color("#f4b7a6")
const DRUM := Color("#d9d2e9")
const SCOPE := Color("#4d4d5c")
const VIEW_C := Vector2(560, 232)
const VIEW_R := 132.0
const TRAIL_X0 := 250.0
const TRAIL_DX := 74.0

var _shapes: RefCounted   # the shapes movie's sets, borrowed for the chart scene


# ---------------------------------------------------------------- 1. the lead-in

func _set_fb_open() -> void:
	var out := _marquee("HOOT'S FIRST MOVIE", "The", "First Beep", "starring Righty, Lefty and one little beep", _prop_note)
	var t0 := float(params.get("card_hold", 8.0)) + 0.3
	if out >= 1.0:
		s._chip("Today: Grandpa Gus", Vector2(440, 226), Palette.SUNNY, 28, Stage2D.INK, _pop(t0 + 0.4))
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(t0 + 0.2), "mood": &"wave"})


func _prop_note(at: Vector2) -> void:
	s._note(at, 1.7, Palette.TONE_CYAN.darkened(0.2), sin(t * 3.0) * 0.15 * s._motion)


# ---------------------------------------------------------------- 2. the beep's path

func _set_fb_path() -> void:
	s._set_air()
	var stops: Array = params.get("stops", ["earphone", "ear canal", "eardrum", "cochlea", "brain"])
	for i in stops.size():
		var k := _pop(1.0 + 0.9 * i)
		var c := Vector2(280.0 + 130.0 * i, 34)
		if i > 0 and k > 0.01:
			s._text(">", c + Vector2(-70, 0), 20, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, k)
		s._chip(String(stops[i]), c, Palette.SKY if i < stops.size() - 1 else Palette.SUNNY, 16, Stage2D.INK, k)


# ---------------------------------------------------------------- 3. reading the chart

func _set_fb_chart() -> void:
	if _shapes == null:
		_shapes = ShapesSets.new()
	_shapes.set("s", s)
	_shapes.set("t", t)
	_shapes.set("duration", duration)
	_shapes.set("params", {})
	_shapes.call("_set_sh_grid")


# ---------------------------------------------------------------- 4. look before you beep

func _set_fb_look() -> void:
	var k := _pop(0.2, 0.5)
	# the otoscope: a handle and a cone pointing at the view (drawn around oc; scaled by k)
	var oc := Vector2(250, 250)
	if k > 0.01:
		s._push(Stage2D._about(oc, -0.5 + sin(t * 2.0) * 0.04 * s._motion, Vector2.ONE * k))
		s._rbox(Rect2(oc + Vector2(-22, 0), Vector2(44, 150)), SCOPE, 14, 3)
		var cone := PackedVector2Array([oc + Vector2(-30, 0), oc + Vector2(30, 0), oc + Vector2(12, -70), oc + Vector2(-12, -70)])
		s.draw_colored_polygon(cone, Palette.PAPER)
		cone.append(cone[0])
		s.draw_polyline(cone, Stage2D.INK, 3.0, true)
		s._circ(oc + Vector2(0, 40), 9.0, Palette.SUNNY, 3.0)
		s._pop_xf()
	# what it sees: the canal, the eardrum and its cone of light
	var vk := _pop(1.2, 0.5)
	if vk > 0.01:
		var c := VIEW_C
		s._push(Stage2D._about(c, 0.0, Vector2.ONE * vk))
		s.draw_circle(c, VIEW_R + 8.0, Stage2D.INK, true, -1.0, true)
		s.draw_circle(c, VIEW_R, CANAL, true, -1.0, true)
		s.draw_circle(c + Vector2(6, 4), VIEW_R * 0.55, DRUM, true, -1.0, true)
		s.draw_colored_polygon(PackedVector2Array([c + Vector2(10, 10), c + Vector2(40, 52), c + Vector2(24, 58)]), Color(Palette.PAPER, 0.9))
		s._pop_xf()
	var checks: Array = params.get("checks", ["Canal clear?", "Eardrum OK?"])
	for i in checks.size():
		var ck := _pop(3.0 + 1.6 * i)
		var at := Vector2(VIEW_C.x + 210, 150 + 70.0 * i)
		s._chip(String(checks[i]), at, Palette.PAPER, 18, Stage2D.INK, ck)
		if t > 3.8 + 1.6 * i:
			_tick(at + Vector2(86, 0), 11.0 * _pop(3.8 + 1.6 * i), Palette.MINT.darkened(0.2))
	s._chip("Look before you beep!", Vector2(440, 420), Palette.SUNNY, 24, Stage2D.INK, _pop(7.0))
	s._hoot(Stage2D.HOOT_AT, 34.0, {"pop": _pop(6.6), "mood": &"idle"})


# ---------------------------------------------------------------- 5. down 10, up 5

func _set_fb_ladder() -> void:
	var start := int(params.get("start", 40))
	var heard: Array = params.get("heard", [])
	var levels: Array[int] = [start]
	for h: Variant in heard:
		levels.append(levels[-1] - 10 if bool(h) else levels[-1] + 5)
	# the dB scale: softer at the top, louder below, as on the chart
	var gk := _pop(0.1, 0.4)
	for db in range(10, 55, 10):
		s._text("%d dB" % db, Vector2(TRAIL_X0 - 70, _y(db)), 15, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, gk)
		s.draw_line(Vector2(TRAIL_X0 - 36, _y(db)), Vector2(TRAIL_X0 + TRAIL_DX * heard.size(), _y(db)), Color(Palette.INK_SOFT, 0.18 * gk), 2.0, true)
	s._chip("filled = heard   hollow = missed", Vector2(560, 56), Palette.PAPER, 15, Stage2D.INK, gk)
	var ups := 0
	var stored := -1
	for i in heard.size():
		var t0 := 1.0 + 1.0 * i
		var dk := _pop(t0, 0.3)
		if dk <= 0.01:
			continue
		var p := Vector2(TRAIL_X0 + TRAIL_DX * i, _y(levels[i]))
		var yes := bool(heard[i])
		# heard on the way up: after a miss (or two), climbing back
		var going_up := yes and i > 0 and not bool(heard[i - 1])
		if i > 0:
			var q := Vector2(TRAIL_X0 + TRAIL_DX * (i - 1), _y(levels[i - 1]))
			s.draw_line(q, p, Color(Palette.INK_SOFT, 0.5 * dk), 3.0, true)
			s._text("-10" if bool(heard[i - 1]) else "+5", (p + q) * 0.5 + Vector2(0, -14), 14, Palette.INK_SOFT, 700, 4, Palette.PAPER, 0.5, dk)
		s.draw_circle(p, 13.0 * dk, Palette.RIGHT_RED if yes else Palette.PAPER, true, -1.0, true)
		s.draw_arc(p, 13.0 * dk, 0.0, TAU, 24, Palette.RIGHT_RED, 3.0, true)
		if going_up:
			ups += 1
			s._chip("up #%d" % ups, p + Vector2(0, 34), Stage2D.GOLD, 14, Stage2D.INK, _pop(t0 + 0.2))
			if ups == 2:
				stored = levels[i]
	if stored >= 0:
		var sk := _pop(1.0 + heard.size() + 0.4)
		s._chip("Heard twice going up: STORE %d dB!" % stored, Vector2(560, 410), Palette.MINT, 22, Stage2D.INK, sk)
	s._hoot(Stage2D.HOOT_AT, 34.0, {"pop": _pop(0.4), "mood": &"idle"})


func _y(db: int) -> float:
	return 110.0 + (float(db) - 10.0) * 6.6


# ---------------------------------------------------------------- 6. curtain call

func _set_fb_bow() -> void:
	_curtain_call(_bow_cast, true)


func _bow_cast(bow: float) -> void:
	s._push(Stage2D._about(Vector2(440, 330), bow * 0.3, Vector2.ONE))
	s._note(Vector2(440, 270), 2.6, Palette.TONE_CYAN.darkened(0.2), -bow * 0.4)
	s._pop_xf()


func _tick(c: Vector2, r: float, col: Color) -> void:
	s.draw_polyline(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.3, r * 0.7), c + Vector2(r, -r * 0.8)]), col, 5.0, true)
