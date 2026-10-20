extends "res://story/explainers/explainer_sets.gd"
## Shared drawing for Hoot's case movies (clinical review C12: story/explainers/movies/case_files.gd,
## tymp.gd and shapes.gd). Each movie's sets script extends this one and draws its own scenes.
##   _marquee(): the opening lead-in (Steve: every movie opens with one). Curtains open on a title
##     card that holds params.card_hold seconds (default 8) with params.questions as two chips under
##     it while Hoot asks the question the movie answers and names the answer; then it flips away.
##   _curtain_call(): the last scene. The cast bows, the curtains close, THE END?, then two knocks
##     (the next patient, for a movie that plays before the patient arrives) or "Back to our
##     patient!" (for one that plays mid-visit).
## Same rules as every set: a pure function of t (no tweens, nodes or RNG), sounds only in the cues.

const CARD_C := Vector2(440, 226)
const CARD_SIZE := Vector2(640, 290)
const CARD_FILL := Color("#3a2f55")
## Where a card's little picture sits: left of the two title lines (which shift right to make room).
const PROP_AT := Vector2(-226, 6)
const LINE_SHIFT := 34.0
const WOOD_DARK := Color("#9c6431")
const FLAG_RED := Color("#e0464b")


## The opening marquee. prop(at: Vector2) draws the card's picture around `at`. Returns how far the
## card has gone (0 = showing, 1 = gone), so the set can bring its cast in after it.
func _marquee(header: String, line1: String, line2: String, starring: String, prop: Callable) -> float:
	var hold := float(params.get("card_hold", 8.0))
	var out := _k(hold, hold + 0.45)
	if out < 1.0:
		var k := 1.0 - out * out * out
		var c := CARD_C
		s._push(Stage2D._about(c, out * 0.5, Vector2.ONE * k))
		var rr := Rect2(c - CARD_SIZE * 0.5, CARD_SIZE)
		s._rbox(Rect2(rr.position + Vector2(0, 10), rr.size), Color(Stage2D.INK, 0.3), 28, 0)
		s._rbox(rr, Stage2D.INK, 28, 0)
		s._rbox(rr.grow(-16), CARD_FILL, 20, 3, Palette.SUNNY)
		var bulbs := rr.grow(-8)
		var per := 2.0 * (bulbs.size.x + bulbs.size.y)
		for i in 36:
			var lit := (i + int(t * 6.0)) % 3 != 0
			s.draw_circle(Stage2D._rect_perimeter(bulbs, per * i / 36.0), 5.0, Palette.SUNNY if lit else Palette.LCD_DIM, true, -1.0, true)
		s._text(header, c + Vector2(0, -88), 26, Palette.SUNNY, 700)
		s._text(line1, c + Vector2(LINE_SHIFT, -26), 48, Palette.PAPER, 700)
		s._text(line2, c + Vector2(LINE_SHIFT, 32), 48, Palette.PAPER, 700)
		prop.call(c + PROP_AT)
		s._text(starring, c + Vector2(0, 98), 19, Palette.SKY, 600)
		s._pop_xf()
		var qs: Array = params.get("questions", [])
		for i in qs.size():
			var qk := _pop(2.0 + 2.6 * i, 0.4) * (1.0 - out)
			s._chip(String(qs[i]), Vector2(240.0 + 400.0 * i, 404.0), Palette.SUNNY if i == 0 else Palette.SKY, 19, Stage2D.INK, qk)
	s._curtains(Stage2D._ease_out(_k(0.1, 1.2)))
	return out


## The curtain call. cast(bow: float) draws the movie's cast bowing (bow 0..1..0). knock: two
## knocks and "Places, trainee: a patient!" (a movie before the patient arrives); otherwise "Back
## to our patient!".
func _curtain_call(cast: Callable, knock: bool) -> void:
	var bow := sin(_k(0.4, 1.6) * PI)
	cast.call(bow)
	s._hoot(Stage2D.HOOT_AT, 40.0, {"mood": &"bow", "tilt": bow * 0.4})
	if t > 0.5 and t < 2.4:
		s._sparkles(Vector2(440, 120), 0.5, 16, 200.0, Palette.SUNNY)
	var shake := 0.0
	if knock:
		shake = _ring(3.6, 5.0, 40.0, 9.0) + _ring(3.9, 5.0, 40.0, 9.0)
	s._push(Stage2D._xform(Vector2(shake, 0)))
	s._curtains(1.0 - Stage2D._ease_in_out(_k(2.0, 3.0)))
	s._pop_xf()
	var end_k := _pop(2.9, 0.45)
	if end_k > 0.01:
		s._big_sign("THE END?", Vector2(440, 196), end_k, sin(t * 3.0) * 0.04 * s._motion, Palette.SUNNY)
	if not knock:
		if t > 3.6:
			s._chip("Back to our patient!", Vector2(440, 300), Palette.PAPER, 22, Stage2D.INK, _pop(3.6))
		return
	for kt: float in [3.6, 3.9]:
		if t >= kt and t < kt + 1.4:
			var a := 1.0 - _k(kt + 0.8, kt + 1.4)
			var p := Vector2(770, 120 + (kt - 3.6) * 200.0)
			s._text("KNOCK!", p + Vector2(sin(t * 40.0) * 3.0 * s._motion, 0), 30, Color(Palette.PAPER, a), 700, 9, Color(Stage2D.INK, a), 0.5, _pop(kt, 0.25))
	if t > 4.4:
		s._chip("Places, trainee: a patient!", Vector2(440, 300), Palette.PAPER, 22, Stage2D.INK, _pop(4.4))


## A small paper card with one or two lines of text (clue cards, captions on the stage).
func _card(c: Vector2, w: float, lines: Array, bg: Color, k: float, rot: float = 0.0, px: int = 18) -> void:
	if k <= 0.01:
		return
	var h := 22.0 + lines.size() * (px + 6.0)
	s._push(Stage2D._about(c, rot, Vector2.ONE * k))
	var rr := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	s._rbox(Rect2(rr.position + Vector2(0, 5), rr.size), Color(Stage2D.INK, 0.2), 12, 0)
	s._rbox(rr, bg, 12, 3)
	for i in lines.size():
		var y := c.y - (lines.size() - 1) * (px + 6.0) * 0.5 + i * (px + 6.0)
		s._text(String(lines[i]), Vector2(c.x, y), px if i == 0 else px - 3, Stage2D.INK if i == 0 else Palette.INK_SOFT, 700 if i == 0 else 600)
	s._pop_xf()


## Two cartoon eyes and a mouth (for props with faces). mood: &"happy", &"wow", &"sleepy", &"worried".
func _face(c: Vector2, r: float, mood: StringName) -> void:
	for sd: float in [-1.0, 1.0]:
		var e := c + Vector2(sd * r * 0.42, -r * 0.12)
		if mood == &"sleepy":
			s.draw_arc(e, r * 0.16, 0.15, PI - 0.15, 8, Stage2D.INK, 3.0, true)
		else:
			s._ell(e, Vector2(r * 0.13, r * 0.18), Stage2D.INK)
			s.draw_circle(e + Vector2(r * 0.03, -r * 0.06), r * 0.05, Palette.PAPER, true, -1.0, true)
	match mood:
		&"wow":
			s._ell(c + Vector2(0, r * 0.38), Vector2(r * 0.14, r * 0.18), Stage2D.INK)
		&"worried":
			s.draw_arc(c + Vector2(0, r * 0.55), r * 0.24, PI * 1.2, PI * 1.8, 8, Stage2D.INK, 3.0, true)
		&"sleepy":
			s.draw_line(c + Vector2(-r * 0.16, r * 0.4), c + Vector2(r * 0.16, r * 0.4), Stage2D.INK, 3.0, true)
		_:
			s.draw_arc(c + Vector2(0, r * 0.2), r * 0.3, PI * 0.15, PI * 0.85, 10, Stage2D.INK, 3.0, true)
