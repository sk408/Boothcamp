extends "res://story/case_movies/case_movie_sets.gd"
## The sets of "Hoot's tune-up movie" (story/explainers/movies/tuneup.gd): Gus's brain meeting loud
## everyday sounds and filing them away, the aid's diary of hours worn, the whistle loop and the
## feedback test, the forward cone in a noisy hall, and the curtain call. The diary's numbers come
## from the scene's params (the movie file says where they come from).

const Portraits := preload("res://story/portraits.gd")

const SETS: Array[StringName] = [&"tu_open", &"tu_brain", &"tu_diary", &"tu_whistle", &"tu_crowd", &"tu_bow"]

const BRAIN := Color("#ffb3c7")
const BRAIN_DARK := Color("#e07a98")
const AID := Color("#d9dde4")
const AID_DARK := Color("#9aa3b0")
const LOOP := Color("#ff9f1c")
const BRAIN_AT := Vector2(440, 236)
const ICON_AT: Array[Vector2] = [Vector2(210, 150), Vector2(670, 150), Vector2(440, 92)]


# ---------------------------------------------------------------- 1. the lead-in

func _set_tu_open() -> void:
	_marquee("HOOT'S TUNE-UP MOVIE", "The", "Tune-Up", "starring Gus's brain and two tiny hearing aids", _prop_aid)
	var t0 := float(params.get("card_hold", 8.0)) + 0.3
	var k := Stage2D._elastic(_k(t0, t0 + 0.9))
	if k > 0.01:
		_brain(BRAIN_AT, 74.0 * k, &"happy", 0.0)
		s._chip("Gus's brain", BRAIN_AT + Vector2(0, 110), Palette.PAPER, 20, Stage2D.INK, _pop(t0 + 0.8))
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(t0 + 0.6), "mood": &"wave"})


func _prop_aid(at: Vector2) -> void:
	var tilt := sin(t * 3.0) * 0.12 * s._motion
	_aid(at + Vector2(0, -4), 1.2, tilt)
	# a little spanner
	var sp := at + Vector2(30, 20)
	s.draw_line(sp, sp + Vector2(22, -22), Stage2D.INK, 7.0, true)
	s.draw_line(sp, sp + Vector2(22, -22), AID_DARK, 4.0, true)
	s._circ(sp + Vector2(25, -25), 7.0, AID_DARK, 3.0)


# ---------------------------------------------------------------- 2. loud at first

func _set_tu_brain() -> void:
	var names: Array = params.get("sounds", ["FRIDGE", "PAPER", "TEASPOON"])
	var weeks := int(params.get("weeks", 3))
	var calm := _k(5.4, 5.4 + 0.8 * weeks)
	var wide := t > 0.6 and calm < 0.5
	_brain(BRAIN_AT + Vector2(0, 20), 74.0, &"wow" if wide else &"happy", s._ring(0.6, 0.12) + s._ring(1.3, 0.12) + s._ring(2.0, 0.12))
	for i in names.size():
		var k := _pop(0.6 + 0.7 * i)
		if k <= 0.01:
			continue
		var at: Vector2 = ICON_AT[i].lerp(Vector2(440 + (i - 1) * 70.0, 372), _k(5.4 + 0.8 * i, 6.2 + 0.8 * i))
		var sc := lerpf(1.0, 0.45, _k(5.4 + 0.8 * i, 6.2 + 0.8 * i)) * k
		_sound_icon(i, String(names[i]), at, sc, 1.0 - _k(5.4 + 0.8 * i, 6.2 + 0.8 * i))
	# the calendar flips a page a week
	if t > 5.0:
		var page := clampi(int((t - 5.4) / 0.8) + 1, 1, weeks)
		var ck := _pop(5.0)
		var c := Vector2(760, 300)
		s._push(Stage2D._about(c, 0.0, Vector2.ONE * ck))
		s._rbox(Rect2(c - Vector2(56, 48), Vector2(112, 100)), Palette.PAPER, 12, 3)
		s._rbox(Rect2(c - Vector2(56, 48), Vector2(112, 30)), Palette.CORAL, 12, 3)
		s._text("WEEK", c + Vector2(0, -33), 16, Palette.PAPER, 700)
		s._text(str(page), c + Vector2(0, 16), 44, Stage2D.INK, 700)
		s._pop_xf()
		if calm > 0.6:
			s._rbox(Rect2(Vector2(318, 346), Vector2(244, 52)), Color(Stage2D.INK, 0.12), 10, 3)
			s._text("normal sounds", Vector2(440, 410), 14, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, _pop(7.4))
	if t > 9.6:
		_sliders(Vector2(210, 236), _k(10.4, 11.0))
	s._hoot(Stage2D.HOOT_AT + Vector2(-20, 0), 34.0, {"pop": _pop(9.6), "mood": &"idle"})


## The three loud sounds: 0 the fridge, 1 the paper, 2 the teaspoon. loud 1 = big, red, zigzags.
func _sound_icon(i: int, label: String, c: Vector2, sc: float, loud: float) -> void:
	var col := Palette.CORAL.lerp(Stage2D.BONE_GREY, 1.0 - loud)
	s._push(Stage2D._about(c, sin(t * 14.0 + i) * 0.06 * loud * s._motion, Vector2.ONE * sc))
	match i:
		0:
			s._rbox(Rect2(c - Vector2(30, 44), Vector2(60, 88)), Palette.PAPER, 10, 4)
			s.draw_line(c + Vector2(-30, -8), c + Vector2(30, -8), Stage2D.INK, 3.0)
			s.draw_line(c + Vector2(18, -32), c + Vector2(18, -18), Stage2D.INK, 4.0)
		1:
			s._rbox(Rect2(c - Vector2(36, 40), Vector2(72, 80)), Palette.PAPER, 6, 4)
			for k in 4:
				s.draw_line(c + Vector2(-24, -24 + 15 * k), c + Vector2(24, -24 + 15 * k), Color(Stage2D.INK, 0.5), 3.0)
		2:
			s.draw_line(c + Vector2(-10, 36), c + Vector2(12, -18), Stage2D.INK, 9.0, true)
			s.draw_line(c + Vector2(-10, 36), c + Vector2(12, -18), AID, 5.0, true)
			s._blob(c + Vector2(15, -28), Vector2(14, 18), AID, 4.0, 0.4)
	if loud > 0.05:
		for k in 4:
			var a := -0.9 + 0.6 * k + PI * (0.0 if k < 2 else 1.0)
			var p0 := c + Vector2(cos(a), sin(a)) * 54.0
			var p1 := c + Vector2(cos(a), sin(a)) * (70.0 + sin(t * 20.0 + k) * 4.0 * s._motion)
			s.draw_line(p0, p1, Color(col, loud), 5.0, true)
	s._pop_xf()
	s._chip(label, c + Vector2(0, 66 * sc), col if loud > 0.5 else Palette.PAPER, 16, Stage2D.INK, sc)


## The tune-up panel: LOUD HIGHS dips a notch (a green tick), WHOLE AID stays put.
func _sliders(c: Vector2, dip: float) -> void:
	var k := _pop(9.8)
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._rbox(Rect2(c - Vector2(110, 80), Vector2(220, 160)), Palette.PAPER, 14, 3)
	for j in 2:
		var x := c.x - 50.0 + 100.0 * j
		s.draw_line(Vector2(x, c.y - 50), Vector2(x, c.y + 40), Stage2D.INK, 4.0)
		var y := c.y - 20.0 + (24.0 * dip if j == 0 else 0.0)
		s._rbox(Rect2(Vector2(x - 18, y - 9), Vector2(36, 18)), Palette.SUNNY if j == 0 else Stage2D.BONE_GREY, 6, 3)
		s._text("LOUD HIGHS" if j == 0 else "WHOLE AID", Vector2(x, c.y + 60), 13, Stage2D.INK, 700)
	if dip > 0.9:
		_tick(Vector2(c.x - 50, c.y - 64), 12.0, Palette.MINT.darkened(0.2))
	s._pop_xf()


# ---------------------------------------------------------------- 3. the aid's diary

func _set_tu_diary() -> void:
	var hours: Array = params.get("hours", [])
	var goal := float(params.get("goal", 12.0))
	var top := float(params.get("max", 14.0))
	var chart := Rect2(220, 90, 560, 240)
	var k := _pop(0.3)
	s._push(Stage2D._about(chart.get_center(), 0.0, Vector2.ONE * k))
	s._rbox(chart.grow(16), Palette.PAPER, 16, 3)
	s._text("THE AID'S DIARY: HOURS WORN", Vector2(chart.get_center().x, chart.position.y + 6), 17, Stage2D.INK, 700)
	var base := chart.end.y - 10.0
	var hy := func(h: float) -> float: return base - (chart.size.y - 50.0) * h / top
	var gy: float = hy.call(goal)
	var dash_k := _k(4.0, 4.6)
	if dash_k > 0.0:
		var x1 := lerpf(chart.position.x + 10, chart.end.x - 10, dash_k)
		s.draw_dashed_line(Vector2(chart.position.x + 10, gy), Vector2(x1, gy), Palette.MINT.darkened(0.2), 4.0, 12.0)
		s._text("ALL WAKING HOURS", Vector2(chart.end.x - 90, gy - 14), 13, Palette.MINT.darkened(0.35), 700, 0, Palette.PAPER, 0.5, _pop(4.4))
	var n := hours.size()
	var w := (chart.size.x - 20.0) / maxf(1.0, float(n))
	var sum := 0.0
	for d in n:
		var h := float(hours[d])
		sum += h
		var grow := _k(0.8 + 0.18 * d, 1.1 + 0.18 * d)
		var x := chart.position.x + 10.0 + w * d + 4.0
		var ytop: float = hy.call(h * grow)
		if h > 0.0 and grow > 0.0:
			s._rbox(Rect2(x, ytop, w - 8.0, base - ytop), Palette.SKY, 4, 2)
		elif grow > 0.5:
			s._text("0", Vector2(x + (w - 8.0) * 0.5, base - 12), 14, Palette.CORAL, 700)
	s.draw_line(Vector2(chart.position.x + 10, base), Vector2(chart.end.x - 10, base), Stage2D.INK, 3.0)
	s._pop_xf()
	if n > 0:
		s._chip("Average: %.1f hours a day" % (sum / float(n)), Vector2(440, 372), Palette.SUNNY, 20, Stage2D.INK, _pop(3.6))
	# the brain jogs: faster once the goal line shows
	var jog := t * (6.0 if t < 5.4 else 11.0)
	var bc := Vector2(120, 300 + absf(sin(jog)) * -10.0 * s._motion)
	_brain(bc, 40.0, &"happy" if t > 5.4 else &"sleepy", 0.0)
	_aid(Vector2(820, 200), 1.6, sin(t * 2.0) * 0.1 * s._motion)


# ---------------------------------------------------------------- 4. the whistle

func _set_tu_whistle() -> void:
	var ear := Vector2(330, 230)
	var test_t := 8.4
	var cut := _k(10.6, 10.9)
	# a big cartoon ear with the aid behind it
	s._blob(ear, Vector2(86, 130), Palette.SKIN, 5.0)
	s._blob(ear + Vector2(10, 10), Vector2(46, 80), Palette.SKIN_SHADE, 0.0)
	s._circ(ear + Vector2(20, 30), 18.0, Stage2D.CANAL, 3.0)
	_aid(ear + Vector2(-90, -70), 2.4, -0.4)
	s.draw_line(ear + Vector2(-70, -110), ear + Vector2(20, 30), Stage2D.INK, 4.0, true)
	s._circ(ear + Vector2(20, 30), 10.0, Palette.PAPER, 3.0)
	# the cap swings down over the ear (more sound bounces back)
	var cap := _k(4.8, 5.6) * (1.0 - _k(8.0, 8.6))
	if cap > 0.01:
		var cy := lerpf(-60.0, 92.0, Stage2D._ease_out(cap))
		s._blob(Vector2(ear.x - 40, cy), Vector2(150, 50), Palette.LEFT_BLUE, 5.0)
		s._rbox(Rect2(Vector2(ear.x + 60, cy + 10), Vector2(120, 22)), Palette.LEFT_BLUE.darkened(0.2), 10, 4)
	# the loop: out of the dome, round the outside and back into the mic on top
	var mic := ear + Vector2(-96, -120)
	var dome := ear + Vector2(20, 30)
	var ctrl := ear + Vector2(240, -40)
	var speed := 1.0 + 1.5 * _k(1.0, 4.0) + 2.0 * cap
	var loud := (1.0 - cut) * _k(0.6, 1.4)
	if loud > 0.01:
		var thick := 4.0 + 6.0 * cap
		for j in 6:
			var u := fmod(t * 0.4 * speed + j / 6.0, 1.0)
			var p := _loop_at(dome, ctrl, mic, u)
			s.draw_circle(p, thick, Color(LOOP, loud), true, -1.0, true)
		var letters := "WHEEE!"
		for i in letters.length():
			var wob := sin(t * 18.0 + i) * 6.0 * s._motion
			s._text(letters[i], Vector2(560 + i * 36, 120 + wob), 40, Color(LOOP.darkened(0.15), loud), 700, 6, Color(Palette.PAPER, loud))
	# the feedback test: a chirp, the loop traced in blue, then a red X and SILENCE
	if t > test_t:
		var trace := _k(test_t + 0.4, test_t + 2.0)
		var pts := PackedVector2Array()
		for i in int(24 * trace) + 1:
			pts.append(_loop_at(dome, ctrl, mic, float(i) / 24.0))
		if pts.size() > 1:
			s.draw_polyline(pts, Palette.LEFT_BLUE, 5.0, true)
		s._chip("FEEDBACK TEST", Vector2(640, 330), Palette.SKY, 20, Stage2D.INK, _pop(test_t))
		if cut > 0.0:
			var xc := _loop_at(dome, ctrl, mic, 0.5)
			var xk := _pop(10.6, 0.3) * 30.0
			s.draw_line(xc + Vector2(-xk, -xk), xc + Vector2(xk, xk), Palette.RIGHT_RED, 10.0, true)
			s.draw_line(xc + Vector2(-xk, xk), xc + Vector2(xk, -xk), Palette.RIGHT_RED, 10.0, true)
			s._chip("Silence!", Vector2(640, 390), Palette.MINT, 22, Stage2D.INK, _pop(11.2))


func _loop_at(dome: Vector2, ctrl: Vector2, mic: Vector2, u: float) -> Vector2:
	return Stage2D._cubic(dome, dome + Vector2(200, 160), ctrl + Vector2(40, -200), mic, u)


# ---------------------------------------------------------------- 5. a noisy hall

func _set_tu_crowd() -> void:
	var gus := Vector2(440, 300)
	var talker := Vector2(440, 96)
	var on := _k(2.6, 3.6)
	# the crowd behind Gus (drawn lower, on both sides)
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var j := i % 4
		var p := Vector2(440 + side * (130 + 80 * j), 250 + 44 * (j % 2) + sin(t * 4.0 + i) * 3.0 * s._motion)
		s._circ(p + Vector2(0, 40), 30.0, Color("#9fb8d9"), 3.0)
		s._circ(p, 22.0, Palette.SKIN, 3.0)
		var chat_a := (1.0 - 0.5 * on) * _pop(0.4 + 0.1 * i)
		s._chip(["haha", "more tea?", "no way!", "and then...", "cheers!", "really?", "mmm", "my cousin..."][i],
			p + Vector2(side * 10, -46), Color(Stage2D.BONE_GREY, chat_a), 13, Color(Stage2D.INK, chat_a), chat_a)
	# the forward cone from Gus's aids to the talker
	if on > 0.01:
		var a := Color(Palette.MINT, 0.3 * on)
		s.draw_colored_polygon(PackedVector2Array([gus + Vector2(0, -40), talker + Vector2(-110, 30), talker + Vector2(110, 30)]), a)
	Portraits.draw(s, "Gus", gus, 50.0, false, fposmod(t, 3.0) < 0.12)
	Portraits.draw(s, "Bev", talker, 40.0, fposmod(t, 0.5) < 0.25, false)
	s._chip("Talker in FRONT", talker + Vector2(150, 0), Palette.SUNNY, 16, Stage2D.INK, _pop(1.2))
	s._chip("Crowd BEHIND", Vector2(440, 410), Stage2D.BONE_GREY, 16, Stage2D.INK, _pop(1.6))
	if t > 7.0:
		s._big_sign("Helps! Not magic.", Vector2(700, 200), _pop(7.0), sin(t * 3.0) * 0.04 * s._motion, Palette.MINT)


# ---------------------------------------------------------------- 6. the curtain call

func _set_tu_bow() -> void:
	_curtain_call(_bow_cast, true)


func _bow_cast(bow: float) -> void:
	s._push(Stage2D._about(Vector2(340, 330), bow * 0.3, Vector2.ONE))
	_brain(Vector2(340, 280), 56.0, &"happy", 0.0)
	s._pop_xf()
	s._push(Stage2D._about(Vector2(560, 330), -bow * 0.3, Vector2.ONE))
	_aid(Vector2(560, 270), 2.6, -bow * 0.5)
	s._pop_xf()


# ---------------------------------------------------------------- the cast

## Gus's brain: a pink blob with folds and a face. squash: a startle wobble.
func _brain(c: Vector2, r: float, mood: StringName, squash: float) -> void:
	if r <= 1.0:
		return
	var sq := squash * s._motion
	s._push(Stage2D._about(c, 0.0, Vector2(1.0 + sq, 1.0 - sq)))
	s._blob(c, Vector2(r * 1.25, r), BRAIN, 5.0)
	for i in 3:
		var y := c.y - r * 0.45 + r * 0.3 * i
		s.draw_arc(Vector2(c.x - r * 0.5, y), r * 0.28, PI * 1.1, PI * 1.9, 8, BRAIN_DARK, 3.0, true)
		s.draw_arc(Vector2(c.x + r * 0.5, y), r * 0.28, PI * 1.1, PI * 1.9, 8, BRAIN_DARK, 3.0, true)
	_face(c + Vector2(0, r * 0.1), r * 0.7, mood)
	s._pop_xf()


## A behind-the-ear hearing aid: the case, a thin wire and an open dome. sc 1 = about 40 px tall.
func _aid(c: Vector2, sc: float, rot: float) -> void:
	s._push(Stage2D._about(c, rot, Vector2.ONE * sc))
	s._blob(c, Vector2(9, 20), AID, 3.0, 0.3)
	s.draw_circle(c + Vector2(-2, -14), 2.5, Stage2D.INK, true, -1.0, true)
	var wire := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		wire.append(Stage2D._bezier(c + Vector2(4, -18), c + Vector2(26, -30), c + Vector2(22, 10), u))
	s.draw_polyline(wire, AID_DARK, 2.0, true)
	s._circ(c + Vector2(22, 12), 5.0, Palette.PAPER, 2.0)
	s._pop_xf()


func _tick(c: Vector2, r: float, col: Color) -> void:
	s.draw_polyline(PackedVector2Array([c + Vector2(-r, 0), c + Vector2(-r * 0.3, r * 0.7), c + Vector2(r, -r * 0.8)]), col, 5.0, true)
