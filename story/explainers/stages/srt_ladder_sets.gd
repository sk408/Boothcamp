extends "res://story/explainers/explainer_sets.gd"
## The sets of Hoot's spondee movie, "The Spondee Ladder" (story/explainers/movies/srt_ladder.gd, Day 3):
## the two-part word blocks on their balance beams, the soft word at the edge of hearing, the halfway
## board (one row per level, LOUDER at the top like the SPEECH screen's ladder), the wooden ladder Hoot
## hops down 10 and up 5, the practice easel that faces Hoot, the dB ruler where words check the beeps
## (soft at the TOP, as on an audiogram) and the recap tiles.
## Numbers come in as data (the scene's params; story/tests/test_movie_srt_ladder.gd pins them to
## SpeechRules); nothing here calls SpeechRules, SpeechMaterial or the SPEECH screen's code.
## Same rules as every set: a pure function of t (no tweens, nodes or RNG), sounds only in the movie's
## cues; every word is drawn, never played. Reduced motion (s._motion < 1): blocks, dots and markers
## fade in instead of dropping or popping, the beams never tip, Hoot slides between rungs instead of
## hopping and cuts between panels, nothing sways.

const SETS: Array[StringName] = [&"spondees", &"edge", &"half", &"ladder", &"practice", &"agree", &"mismatch", &"recap"]

## The marquee (scene 1): the shape of the stage's own title card and the Letter Choir's _marquee().
const CARD_C := Vector2(440, 226)
const CARD_SIZE := Vector2(640, 290)
const CARD_FILL := Color("#3a2f55")
const PROP_AT := Vector2(-222, 8)
const LINE_SHIFT := 40.0

## A word's two halves: the first warm, the second cool, the same size (equal stress).
const FIRST_COL := Color("#ffc9a8")
const SECOND_COL := Color("#bfe6ff")
const BLOCK_W := 112.0
const BLOCK_H := 64.0
const LISTENER := Color("#d9f0c2")
const BAND := Color("#5bc8a3")
## The halfway board and the ladder: LOUDER at the top, as on the SPEECH screen.
const BOARD := Rect2(120, 64, 560, 316)
const RAIL_L := 250.0
const RAIL_R := 330.0
const LADDER_TOP_Y := 74.0
const LADDER_BOTTOM_Y := 386.0
const TRAIL := Rect2(470, 60, 380, 340)
## The dB rulers (agree, mismatch): soft at the top.
const RULER_TOP_DB := 0.0
const RULER_BOTTOM_DB := 80.0


# ---------------------------------------------------------------- 1. spondees (the lead-in)

## The marquee holds while Hoot asks the question and names the answer (params.card_hold, the two
## params.questions chips), then two balance beams take two-part words, half by half. The beams run
## on the stage's clock shifted by card_hold - 2 s, the way the stage's _set_meet() does it (s.t, not
## this script's copy: every helper reads the stage's t).
func _set_spondees() -> void:
	var p: Dictionary = params.get("spondees", {})
	var hold := float(params.get("card_hold", 2.0))
	var real_t := s.t
	var card_out := _k(hold, hold + 0.45)
	if card_out < 1.0:
		_marquee(String(p.get("title", scene_title)), String(p.get("starring", "")), card_out)
	s.t = real_t - (hold - 2.0)
	t = s.t
	_balances(p.get("words", []))
	s.t = real_t
	t = real_t
	s._curtains(Stage2D._ease_out(_k(0.1, 1.2)))


func _marquee(title: String, starring: String, out: float) -> void:
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
	s._text("HOOT'S MOVIE MATINEE", c + Vector2(0, -88), 28, Palette.SUNNY, 700)
	# "The Spondee" over "Ladder": the last word on its own line, like the masking movie's card
	var cut := title.rfind(" ")
	var line1 := title.substr(0, cut) if cut > 0 else title
	var line2 := title.substr(cut + 1) if cut > 0 else ""
	s._text(line1, c + Vector2(LINE_SHIFT, -26), 50, Palette.PAPER, 700)
	if line2 != "":
		s._text(line2, c + Vector2(LINE_SHIFT, 34), 50, Palette.PAPER, 700)
	_marquee_prop(c + PROP_AT)
	s._text(starring, c + Vector2(0, 98), 19, Palette.SKY, 600)
	s._pop_xf()
	var qs: Array = params.get("questions", [])
	for i in qs.size():
		var qk := _pop(2.0 + 2.6 * i, 0.4) * (1.0 - out)
		s._chip(String(qs[i]), Vector2(240.0 + 400.0 * i, 404.0), Palette.SUNNY if i == 0 else Palette.SKY, 19, Stage2D.INK, qk)


## A little ladder on the card, two half-blocks climbing it.
func _marquee_prop(at: Vector2) -> void:
	var bob := sin(t * 3.0) * 3.0 * s._motion
	_ladder_shape(Vector2(at.x - 24, at.y - 64), Vector2(at.x + 24, at.y + 66), 5, 1.0, 0.7)
	_block(at + Vector2(-34, 30 + bob), "rain", FIRST_COL, {"w": 58.0, "h": 34.0, "px": 15})
	_block(at + Vector2(30, -12 - bob), "bow", SECOND_COL, {"w": 58.0, "h": 34.0, "px": 15})


## Two balance beams, one per word: the first half lands and tips the beam, the second lands and it
## settles dead level (both halves weigh the same); then every half thumps its beat, DUM!, all the
## same size, and Hoot conducts.
func _balances(words: Array) -> void:
	var still := s._motion < 1.0
	var beat_at := 5.4
	for i in mini(words.size(), 2):
		var pair: Array = words[i]
		var c := Vector2(340.0 + 330.0 * i, 318.0)
		var t0 := 2.4 + 1.6 * i
		var land1 := t0 + 0.4
		var land2 := t0 + 0.8
		var bk := _k(t0 - 0.2, t0 + 0.2) if still else _pop(t0 - 0.2, 0.4)
		if bk <= 0.01:
			continue
		var tilt := 0.0
		if not still and t >= land1:
			tilt = -0.14 * _k(land1, land1 + 0.15) * (1.0 - _k(land2, land2 + 0.25)) + _ring(land2 + 0.25, 0.04, 12.0, 4.0)
		# the stand (it never tips), then the plank and its two halves in the plank's own space
		s._push(Stage2D._about(c + Vector2(0, 60), 0.0, Vector2(1.0, bk)))
		s.draw_colored_polygon(PackedVector2Array([c + Vector2(0, 4), c + Vector2(-34, 62), c + Vector2(34, 62)]), Palette.WOOD.darkened(0.15))
		s.draw_polyline(PackedVector2Array([c + Vector2(0, 4), c + Vector2(-34, 62), c + Vector2(34, 62), c + Vector2(0, 4)]), Stage2D.INK, 4.0, true)
		s._pop_xf()
		s._push(Stage2D._about(c, tilt, Vector2(bk, bk)))
		s._rbox(Rect2(c + Vector2(-140, -8), Vector2(280, 16)), Palette.WOOD, 8, 4)
		for h in 2:
			var land := land1 if h == 0 else land2
			var drop := _k(land - 0.4, land)
			if drop <= 0.0:
				continue
			var home := c + Vector2(-70.0 + 140.0 * h, -8.0 - BLOCK_H * 0.5)
			var y_off := 0.0 if still else -170.0 * (1.0 - drop * drop)
			var beat := beat_at + 0.4 * (2 * i + h)
			var sq := 0.0 if still else _ring(land, 0.18, 18.0, 6.0) + _ring(beat, 0.16, 18.0, 6.0)
			_block(home + Vector2(0, y_off), String(pair[h]), FIRST_COL if h == 0 else SECOND_COL, {"alpha": drop if still else 1.0, "squash": sq})
			# the same accent over every half: both halves are stressed alike
			if drop >= 1.0:
				_accent(home + Vector2(0, -BLOCK_H * 0.5 - 20.0), _pop(land, 0.3))
		s._pop_xf()
		# its beats, then the whole word under the beam
		for h in 2:
			var beat := beat_at + 0.4 * (2 * i + h)
			var bt := _k(beat, beat + 0.6)
			if t >= beat and bt < 1.0:
				var bp := c + Vector2(-70.0 + 140.0 * h, -122.0 - 18.0 * bt * s._motion)
				s._text("DUM!", bp, 26, Color(Stage2D.INK, 1.0 - bt * bt), 700, 6, Color(Palette.PAPER, 1.0 - bt * bt))
		if t > land2 + 0.3:
			s._chip("%s-%s" % [String(pair[0]), String(pair[1])], c + Vector2(0, 92), Palette.PAPER, 18, Stage2D.INK, _pop(land2 + 0.3))
	if t > 7.2:
		s._chip("equal stress: both halves strong", Vector2(505, 70), Palette.SUNNY, 20, Stage2D.INK, _pop(7.2), sin(t * 3.0) * 0.02 * s._motion)
	s._hoot(Vector2(84, 360), 36.0, {"pop": _pop(2.2), "mood": &"wave" if t > beat_at else &"idle"})


# ---------------------------------------------------------------- 2. edge

## The slider slides almost to soft (the edge of hearing); the word floats from Hoot to the listener,
## both halves fading alike; the listener squints, then guesses it right.
func _set_edge() -> void:
	var p: Dictionary = params.get("edge", {})
	var word: Array = p.get("word", ["light", "house"])
	var guess := String(p.get("guess", "?"))
	var still := s._motion < 1.0
	# the slider: LOUD at the left, soft at the right, the edge zone at the soft end
	var x0 := 250.0
	var x1 := 690.0
	var y := 92.0
	var edge_x := lerpf(x0, x1, 0.82)
	s._rbox(Rect2(Vector2(edge_x, y - 22), Vector2(x1 - edge_x + 18, 44)), Color(Palette.PLUM, 0.12), 12, 0)
	s.draw_dashed_line(Vector2(edge_x, y - 24), Vector2(edge_x, y + 24), Palette.PLUM, 3.0, 8.0)
	s._rbox(Rect2(Vector2(x0, y - 7), Vector2(x1 - x0, 14)), Palette.PAPER, 7, 3)
	s._text("LOUD", Vector2(x0 - 40, y), 17, Stage2D.INK, 700)
	s._text("soft", Vector2(x1 + 40, y), 17, Stage2D.INK, 700)
	var slide := Stage2D._ease_in_out(_k(0.8, 1.8))
	var kx := lerpf(lerpf(x0, x1, 0.25), lerpf(x0, x1, 0.9), slide)
	s._circ(Vector2(kx, y), 16.0, Palette.SUNNY, 4.0)
	if t > 1.6:
		s._chip("the edge of hearing", Vector2(edge_x + 40, y + 46), Palette.PAPER, 15, Palette.PLUM.darkened(0.2), _pop(1.6))
	# Hoot says it; the listener at the right
	var hoot_at := Vector2(124, 318)
	var ear_at := Vector2(700, 300)
	s._hoot(hoot_at, 44.0, {"pop": _pop(0.2), "mood": &"wave" if t > 1.9 and t < 3.4 else &"idle"})
	var puzzled := t > 3.4 and t < 4.2
	var got := t >= 4.2
	_bean(ear_at, 140.0, LISTENER, {"look": -1.0, "mood": &"puzzled" if puzzled else (&"happy" if got else &"idle"), "ear": true, "pop": _pop(0.4)})
	# the word floats across, both halves fading together
	var fly := _k(2.0, 3.4)
	var faint := lerpf(1.0, 0.32, fly)
	if t >= 2.0:
		var from := hoot_at + Vector2(120, -70)
		var to := Vector2(430, 196)
		var pos := from.lerp(to, Stage2D._ease_in_out(fly)) + Vector2(0, -sin(fly * PI) * (0.0 if still else 30.0))
		for h in 2:
			var bc := pos + Vector2(-60.0 + 120.0 * h, 0)
			_block(bc, String(word[h]), FIRST_COL if h == 0 else SECOND_COL, {"alpha": faint, "face": false})
			if fly >= 1.0:
				_fuzz(bc, BLOCK_W * 0.5 + 6.0, BLOCK_H * 0.5 + 6.0)
		if fly >= 1.0:
			s._chip("both halves equally soft", to + Vector2(0, 56), Palette.PAPER, 16, Stage2D.INK, _pop(3.4))
	# the guess: a squint, then the whole word, right
	if puzzled:
		s._text("...?", ear_at + Vector2(-30, -112), 30, Palette.INK_SOFT, 700, 6, Palette.PAPER)
	var gk := _pop(4.2, 0.4)
	if gk > 0.01:
		_bubble(Vector2(700, 196), 220.0, 54.0, ear_at + Vector2(-20, -70), gk, LISTENER.lightened(0.4))
		s._text(guess, Vector2(700, 196), 26, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, gk)
		_tick(Vector2(826, 180), true, _pop(4.4, 0.35))
	if t > 5.2:
		s._sparkles(Vector2(700, 196), 5.2, 12, 110.0, Palette.SUNNY)
		s._chip("easy to guess right", Vector2(430, 330), Palette.MINT, 20, Stage2D.INK, _pop(5.2), sin(t * 3.0) * 0.02 * s._motion)


## Dotted fuzz round a faint word: it is right at the edge.
func _fuzz(c: Vector2, rx: float, ry: float) -> void:
	for i in 14:
		var ang := TAU * i / 14.0 + t * 0.6 * s._motion
		var p := c + Vector2(cos(ang) * rx, sin(ang) * ry)
		s.draw_circle(p, 2.5, Color(Palette.PLUM, 0.45), true, -1.0, true)


# ---------------------------------------------------------------- 3. half

## One row per level, LOUDER at the top: four word dots pop along each row, a tally at its end; the
## softest row with about half right lights up and the SRT stamp lands beside it.
func _set_half() -> void:
	var p: Dictionary = params.get("half", {})
	var rows: Array = p.get("rows", [])
	var srt := int(p.get("srt", -1))
	var still := s._motion < 1.0
	s._panel(BOARD, Stage2D.GRAPH_BG, 18)
	s._text("LOUDER", Vector2(BOARD.position.x + 54, BOARD.position.y + 24), 15, Stage2D.INK, 700)
	s._text("softer", Vector2(BOARD.position.x + 54, BOARD.end.y - 22), 15, Stage2D.INK, 700)
	UiDraw.arrow(s, Vector2(BOARD.position.x + 54, BOARD.end.y - 48), 10.0, Vector2(0, 1), Palette.INK_SOFT)
	s.draw_line(Vector2(BOARD.position.x + 54, BOARD.position.y + 44), Vector2(BOARD.position.x + 54, BOARD.end.y - 54), Palette.INK_SOFT, 3.0, true)
	s._text("each dot: one word", Vector2(BOARD.get_center().x + 40, BOARD.position.y + 24), 15, Palette.INK_SOFT, 700)
	var n := rows.size()
	var row_h := 62.0
	var y0 := BOARD.position.y + 76.0
	var srt_row := -1
	for r in n:
		var row: Array = rows[r]
		var db := int(row[0])
		var marks := String(row[1])
		var y := y0 + row_h * r
		if db == srt:
			srt_row = r
			var lit := _k(4.8, 5.1)
			if lit > 0.0:
				s._rbox(Rect2(Vector2(BOARD.position.x + 92, y - 26), Vector2(BOARD.size.x - 110, 52)), Color(BAND, 0.3 * lit), 14, 0)
		var rk := _k(0.6 + 0.9 * r, 0.9 + 0.9 * r)
		s._text("%d dB" % db, Vector2(BOARD.position.x + 128, y), 20, Color(Stage2D.INK, maxf(0.25, rk)), 700)
		s.draw_dashed_line(Vector2(BOARD.position.x + 170, y), Vector2(BOARD.end.x - 120, y), Color(Palette.INK_SOFT, 0.35), 2.0, 6.0)
		var right := 0
		var shown := 0
		for j in marks.length():
			var t0 := 0.8 + 0.9 * r + 0.18 * j
			var dk := _k(t0, t0 + 0.2) if still else _pop(t0, 0.3)
			if dk <= 0.01:
				continue
			var ok := marks.substr(j, 1) == "Y"
			shown += 1
			right += 1 if ok else 0
			_tick(Vector2(BOARD.position.x + 220 + 64.0 * j, y), ok, dk)
		if shown == marks.length():
			s._text("%d of %d" % [right, marks.length()], Vector2(BOARD.end.x - 62, y), 19, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, _pop(0.8 + 0.9 * r + 0.18 * marks.length()))
	if srt_row >= 0:
		var sy := y0 + row_h * srt_row
		_stamp(Vector2(772, sy), ["SRT", "%d dB" % srt], _k(5.0, 5.2), -0.14)
		if t > 5.6:
			s._chip("the softest level with about half right", Vector2(BOARD.get_center().x + 40, BOARD.end.y + 30), Palette.MINT, 17, Stage2D.INK, _pop(5.6))
		if srt_row + 1 < n and t > 6.2:
			s._chip("too soft", Vector2(772, y0 + row_h * (srt_row + 1) + 4), Palette.PAPER, 16, Palette.CORAL.darkened(0.25), _pop(6.2))
	s._hoot(Vector2(796, 120), 32.0, {"pop": _pop(0.3), "mood": &"cheer" if t > 5.0 else &"idle", "squash": _ring(5.0, 0.2, 18.0, 5.0)})


# ---------------------------------------------------------------- 4. ladder

## The wooden ladder, one rung per 5 dB, LOUDER at the top: Hoot hops down two rungs after a right
## word and climbs one after a miss; each word lands as a dot on the trail beside it, level by level.
func _set_ladder() -> void:
	var p: Dictionary = params.get("ladder", {})
	var top := int(p.get("top", 55))
	var bottom := int(p.get("bottom", 15))
	var down := int(p.get("down", 10))
	var up := int(p.get("up", 5))
	var answers: Array = p.get("answers", [])
	var still := s._motion < 1.0
	var levels: Array[int] = [int(p.get("start", 50))]
	for a: Variant in answers:
		levels.append(levels[-1] - down if bool(a) else levels[-1] + up)
	# the ladder and its rungs' levels
	_ladder_shape(Vector2(RAIL_L, LADDER_TOP_Y - 14), Vector2(RAIL_R, LADDER_BOTTOM_Y + 14), 0, _k(0.0, 0.5), 1.0)
	var db := top
	while db >= bottom:
		var y := _ly(db, top, bottom)
		s.draw_line(Vector2(RAIL_L, y), Vector2(RAIL_R, y), Stage2D.INK, 9.0, true)
		s.draw_line(Vector2(RAIL_L, y), Vector2(RAIL_R, y), Palette.WOOD.lightened(0.1), 5.0, true)
		s._text(str(db), Vector2(RAIL_L - 26, y), 15, Palette.INK_SOFT, 700)
		db -= 5
	s._text("LOUDER", Vector2((RAIL_L + RAIL_R) * 0.5 + 110, LADDER_TOP_Y - 4), 15, Stage2D.INK, 700)
	s._text("softer", Vector2((RAIL_L + RAIL_R) * 0.5 + 110, LADDER_BOTTOM_Y), 15, Stage2D.INK, 700)
	# the trail: the same words as dots, lined up with the rungs
	s._panel(TRAIL, Stage2D.GRAPH_BG, 16)
	s._text("each dot: one word", Vector2(TRAIL.get_center().x, TRAIL.position.y + 22), 15, Palette.INK_SOFT, 700)
	var gap := 1.1
	var prev := Vector2.ZERO
	for i in answers.size():
		var w_t := 1.0 + gap * i
		var dk := _k(w_t + 0.35, w_t + 0.55) if still else _pop(w_t + 0.35, 0.3)
		if dk <= 0.01:
			continue
		var dp := Vector2(TRAIL.position.x + 50.0 + 54.0 * i, _ly(levels[i], top, bottom))
		if i > 0:
			s.draw_line(prev, dp, Color(Palette.INK_SOFT, 0.6 * dk), 3.0, true)
		_tick(dp, bool(answers[i]), dk)
		prev = dp
	# Hoot on the ladder: hop (or slide) from rung to rung
	var at_level := float(levels[0])
	var hop_k := 0.0
	for i in answers.size():
		var w_t := 1.0 + gap * i
		var hk := _k(w_t + 0.55, w_t + 0.95)
		if hk <= 0.0:
			break
		at_level = lerpf(float(levels[i]), float(levels[i + 1]), Stage2D._ease_in_out(hk))
		hop_k = hk if hk < 1.0 else 0.0
	var hx := (RAIL_L + RAIL_R) * 0.5
	var hy := _ly(at_level, top, bottom) - 14.0 - sin(hop_k * PI) * (0.0 if still else 34.0)
	var miss_now := false
	for i in answers.size():
		var w_t := 1.0 + gap * i
		if t >= w_t and t < w_t + 1.0:
			miss_now = not bool(answers[i])
			# the word bubble beside Hoot, then its tick or cross
			var bk := _pop(w_t, 0.3) * (1.0 - _k(w_t + 0.9, w_t + 1.0))
			var bp := Vector2(RAIL_R + 64, _ly(levels[i], top, bottom))
			s._chip("word %d" % (i + 1), bp, Palette.PAPER, 15, Stage2D.INK, bk)
			if t >= w_t + 0.35:
				_tick(bp + Vector2(56, 0), bool(answers[i]), bk)
			if t >= w_t + 0.5:
				var step := "-%d" % down if bool(answers[i]) else "+%d" % up
				s._chip(step, Vector2(RAIL_L - 70, (_ly(levels[i], top, bottom) + _ly(levels[i + 1], top, bottom)) * 0.5),
					Palette.MINT if bool(answers[i]) else Palette.CORAL, 18, Stage2D.INK, bk)
	s._hoot(Vector2(hx, hy), 28.0, {"pop": _pop(0.4), "mood": &"gasp" if miss_now else (&"cheer" if hop_k > 0.0 else &"idle")})
	var last_t := 1.0 + gap * answers.size()
	if t > last_t + 0.2:
		s._chip("one common way", Vector2(112, 190), Palette.SUNNY, 17, Stage2D.INK, _pop(last_t + 0.2))
	if t > last_t + 1.0:
		s._chip("not the only one", Vector2(112, 236), Palette.SKY, 17, Stage2D.INK, _pop(last_t + 1.0))


## The y of a level on the ladder and its trail (LOUDER at the top: the top rung is the loudest).
static func _ly(db: float, top: float, bottom: float) -> float:
	return lerpf(LADDER_TOP_Y, LADDER_BOTTOM_Y, (top - db) / maxf(1.0, top - bottom))


## A wooden ladder between two corners: two rails and `rungs` evenly spaced rungs (0: the caller draws
## its own). k grows it upward; a fades it.
func _ladder_shape(top_left: Vector2, bottom_right: Vector2, rungs: int, k: float, a: float) -> void:
	if k <= 0.01 or a <= 0.01:
		return
	var y_top := lerpf(bottom_right.y, top_left.y, Stage2D._ease_out(k))
	for x: float in [top_left.x, bottom_right.x]:
		s.draw_line(Vector2(x, y_top), Vector2(x, bottom_right.y), Color(Stage2D.INK, a), 12.0, true)
		s.draw_line(Vector2(x, y_top), Vector2(x, bottom_right.y), Color(Palette.WOOD, a), 7.0, true)
	for i in rungs:
		var y := lerpf(top_left.y, bottom_right.y, (i + 0.5) / float(rungs))
		if y >= y_top:
			s.draw_line(Vector2(top_left.x, y), Vector2(bottom_right.x, y), Color(Stage2D.INK, a), 7.0, true)
			s.draw_line(Vector2(top_left.x, y), Vector2(bottom_right.x, y), Color(Palette.WOOD.lightened(0.1), a), 3.5, true)


# ---------------------------------------------------------------- 5. practice

## Hoot's easel faces Hoot (its back to the patient: no peeking). Hoot says each word, the listener
## says it back, a tick pops; then "by ear", a crossed-out eye, and the ribbon.
func _set_practice() -> void:
	var p: Dictionary = params.get("practice", {})
	var words: Array = p.get("words", [])
	var still := s._motion < 1.0
	var hoot_at := Vector2(150, 300)
	var ear_at := Vector2(720, 300)
	# the easel: legs, the card's back toward the patient, its sign
	var ec := Vector2(300, 268)
	s.draw_line(ec + Vector2(-34, 40), ec + Vector2(-50, 130), Stage2D.INK, 7.0, true)
	s.draw_line(ec + Vector2(34, 40), ec + Vector2(50, 130), Stage2D.INK, 7.0, true)
	s._rbox(Rect2(ec - Vector2(56, 64), Vector2(112, 128)), Color("#7b6aa8"), 10, 4)
	for j in 3:
		for i in 3:
			UiDraw.star(s, ec + Vector2(-30 + 30 * i, -34 + 34 * j), 6.0, Color(Palette.PAPER, 0.5))
	s._chip("no peeking!", ec + Vector2(0, -88), Palette.PAPER, 14, Stage2D.INK, _pop(0.3))
	var talk := false
	var said_i := -1
	var repeated := 0
	for i in words.size():
		var w_t := 0.8 + 1.4 * i
		if t >= w_t:
			said_i = i
		if t >= w_t and t < w_t + 0.5:
			talk = true
		if t >= w_t + 0.9:
			repeated += 1
	s._hoot(hoot_at, 46.0, {"pop": _pop(0.1), "mood": &"wave" if talk else &"idle"})
	var answering := said_i >= 0 and t >= 0.8 + 1.4 * said_i + 0.6 and t < 0.8 + 1.4 * said_i + 1.2
	_bean(ear_at, 140.0, LISTENER, {"look": -1.0, "mouth": absf(sin(t * 12.0)) if answering else 0.0, "ear": true, "pop": _pop(0.4), "mood": &"happy" if t > 4.6 else &"idle"})
	# the word in turn: Hoot's bubble, then the listener's, then a tick
	if said_i >= 0:
		var w := String(words[said_i]).capitalize() + "!"
		var w_t := 0.8 + 1.4 * said_i
		var hk := _k(w_t, w_t + 0.25) if still else _pop(w_t, 0.3)
		_bubble(Vector2(260, 92), 220.0, 56.0, hoot_at + Vector2(30, -54), hk, Palette.PAPER)
		s._text(w, Vector2(260, 92), 26, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, hk)
		var rk := _k(w_t + 0.6, w_t + 0.85) if still else _pop(w_t + 0.6, 0.3)
		_bubble(Vector2(640, 92), 220.0, 56.0, ear_at + Vector2(-20, -70), rk, LISTENER.lightened(0.4))
		s._text(w, Vector2(640, 92), 26, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, rk)
		_tick(Vector2(770, 70), true, _pop(w_t + 0.9, 0.3))
	s._chip("said back: %d of %d" % [repeated, words.size()], Vector2(450, 40), Palette.PAPER, 15, Palette.INK_SOFT, _pop(0.8))
	# by ear, never by reading
	var ek := _pop(5.0, 0.4)
	if ek > 0.01:
		_ear_icon(Vector2(400, 236), 26.0, ek)
		s._chip("by ear", Vector2(400, 296), Palette.MINT, 18, Stage2D.INK, ek)
	var nk := _pop(5.5, 0.4)
	if nk > 0.01:
		_eye_crossed(Vector2(540, 236), 26.0, nk)
		s._chip("not by reading", Vector2(540, 296), Palette.PAPER, 18, Palette.CORAL.darkened(0.25), nk)
	if t > 6.2:
		s._sparkles(Vector2(520, 380), 6.2, 12, 120.0, Palette.SUNNY)
		s._chip("hearing, not vocabulary", Vector2(520, 380), Palette.SUNNY, 22, Stage2D.INK, _pop(6.2), sin(t * 3.0) * 0.02 * s._motion)


# ---------------------------------------------------------------- 6. agree

## The ruler (soft at the top): the beep drops in at the tone average, the word at the SRT; the band
## grows params.agree.within (6 dB, AGREE_GOOD_DB) either side of the beep, a dashed line joins them,
## THEY AGREE!
func _set_agree() -> void:
	var p: Dictionary = params.get("agree", {})
	var pta := float(p.get("pta", 40))
	var srt := float(p.get("srt", 40))
	var within := float(p.get("within", 10))
	var still := s._motion < 1.0
	var col := Rect2(400, 70, 80, 320)
	_ruler(col, _k(0.0, 0.6))
	var bandk := Stage2D._ease_out(_k(2.6, 3.2))
	_band(col, pta, within * bandk, bandk)
	if bandk > 0.5:
		s._chip("within %d dB" % int(within), Vector2(col.end.x + 120, _ry(col, pta + within) + 40), BAND, 16, Stage2D.INK, _pop(3.0))
	var bp := Vector2(col.position.x - 90, _ry(col, pta))
	var wp := Vector2(col.end.x + 100, _ry(col, srt))
	_beep_marker(bp, col.position.x, _marker_k(0.8, still), "tone average: %d" % int(pta), -1.0, 1.5)
	_word_marker(wp, col.end.x, _marker_k(1.6, still), "SRT: %d" % int(srt), 1.0, 1.4)
	var jk := _k(3.4, 3.9)
	if jk > 0.0:
		s.draw_dashed_line(Vector2(col.position.x, bp.y), Vector2(col.end.x, wp.y), Palette.SELECT_ORANGE, 3.0, 8.0)
		s._chip("%d dB apart" % int(absf(pta - srt)), Vector2(col.get_center().x, _ry(col, pta - within) - 24), Palette.PAPER, 15, Stage2D.INK, _pop(3.5))
	if t > 4.4:
		s._sparkles(Vector2(440, 60), 4.4, 14, 140.0, Palette.SUNNY)
		s._big_sign("THEY AGREE!", Vector2(670, 360), _pop(4.4, 0.45), sin(t * 3.0) * 0.03 * s._motion, Palette.MINT)
	s._hoot(Vector2(120, 340), 46.0, {"pop": _pop(0.3), "mood": &"cheer" if t > 4.4 else &"idle", "squash": _ring(4.4, 0.2, 18.0, 5.0)})


func _marker_k(t0: float, still: bool) -> float:
	return _k(t0, t0 + 0.35) if still else _pop(t0, 0.4)


# ---------------------------------------------------------------- 7. mismatch

## Two panels, each with its own short ruler over a strip for Hoot's notes. Words much BETTER: the word
## floats far above the band, Hoot re-instructs kindly, the rechecked beep slides up into agreement,
## "never accuse". Words much WORSE: the word sinks below; "instructions clear?", "their language?".
func _set_mismatch() -> void:
	var p: Dictionary = params.get("mismatch", {})
	var better: Dictionary = p.get("better", {})
	var worse: Dictionary = p.get("worse", {})
	var within := float(p.get("within", 10))
	var still := s._motion < 1.0
	var left := Rect2(36, 62, 396, 340)
	var right := Rect2(448, 62, 396, 340)
	# left: words much better than the beeps
	s._panel(left, Stage2D.GRAPH_BG, 18)
	s._chip("words much BETTER", Vector2(left.get_center().x, left.position.y + 2), Palette.SUNNY, 17, Stage2D.INK, 1.0)
	var lc := _panel_ruler(left)
	_ruler(lc, 1.0, true)
	var pta0 := float(better.get("pta", 45))
	var recheck := float(better.get("recheck", pta0))
	var lsrt := float(better.get("srt", pta0))
	var lpta := lerpf(pta0, recheck, Stage2D._ease_in_out(_k(3.4, 4.4)))
	_band(lc, lpta, within, 1.0)
	var lw := Vector2(lc.end.x + 70, _ry(lc, lsrt))
	_beep_marker(Vector2(lc.position.x - 70, _ry(lc, lpta)), lc.position.x, _marker_k(0.4, still), "tones: %d" % int(round(lpta)), -1.0)
	_word_marker(lw, lc.end.x, _marker_k(0.8, still), "SRT: %d" % int(lsrt), 1.0)
	if t > 1.6 and t < 3.6:
		var bounce := 0.0 if still else absf(sin((t - 1.6) * 4.0)) * 10.0
		s._text("?", lw + Vector2(62, -bounce), 42, Palette.CORAL, 700, 8, Palette.PAPER, 0.5, _pop(1.6))
	if t > 4.6:
		_tick(lw + Vector2(62, 0), true, _pop(4.6, 0.3))
	# Hoot's notes in the strip: the kind card, then "never accuse"
	var strip_x := left.position.x + 214.0
	var card := _pop(2.2, 0.4) * (1.0 - _k(5.4, 5.8))
	if card > 0.01:
		s._chip("Every beep, even the faint ones!", Vector2(strip_x, left.end.y - 52), Palette.PAPER, 15, Stage2D.INK, card, -0.02)
		s._chip("re-instruct, kindly", Vector2(strip_x, left.end.y - 18), Palette.MINT, 15, Stage2D.INK, _pop(2.6) * (1.0 - _k(5.4, 5.8)))
	var hk := _pop(5.8)
	if hk > 0.01:
		UiDraw.heart(s, Vector2(strip_x - 74, left.end.y - 36), 11.0 * hk, Palette.CORAL)
		s._chip("never accuse", Vector2(strip_x + 10, left.end.y - 36), Palette.PAPER, 17, Stage2D.INK, hk)
	# right: words much worse than the beeps
	var rk := _k(6.0, 6.35) if still else _pop(6.0, 0.45)
	if rk > 0.01:
		var a := rk if still else 1.0
		s._push(Stage2D._about(right.get_center(), 0.0, Vector2.ONE * (1.0 if still else rk)))
		s._panel(right, Color(Stage2D.GRAPH_BG, a), 18)
		s._chip("words much WORSE", Vector2(right.get_center().x, right.position.y + 2), Palette.SKY, 17, Stage2D.INK, a)
		var rc := _panel_ruler(right)
		_ruler(rc, a, true)
		var rpta := float(worse.get("pta", 40))
		var rsrt := float(worse.get("srt", rpta))
		var rw := Vector2(rc.end.x + 70, _ry(rc, rsrt))
		_band(rc, rpta, within, a)
		_beep_marker(Vector2(rc.position.x - 70, _ry(rc, rpta)), rc.position.x, _marker_k(6.3, still) * a, "tones: %d" % int(rpta), -1.0)
		_word_marker(rw, rc.end.x, _marker_k(6.7, still) * a, "SRT: %d" % int(rsrt), 1.0)
		s._pop_xf()
		if t > 7.0:
			var bounce := 0.0 if still else absf(sin((t - 7.0) * 4.0)) * 10.0
			s._text("?", rw + Vector2(62, -bounce), 42, Palette.CORAL, 700, 8, Palette.PAPER, 0.5, _pop(7.0))
		var rx := right.position.x + 182.0
		s._chip("instructions clear?", Vector2(rx, right.end.y - 52), Palette.PAPER, 15, Stage2D.INK, _pop(7.6))
		s._chip("words in their language?", Vector2(rx, right.end.y - 18), Palette.PAPER, 15, Stage2D.INK, _pop(8.4))
	# Hoot: kind in the left panel's corner, then over to the right one's
	var cross := Stage2D._ease_in_out(_k(6.0, 6.6))
	if still:
		cross = 1.0 if t >= 6.3 else 0.0
	var hp := Vector2(72, 368).lerp(Vector2(808, 368), cross) + Vector2(0, -sin(cross * PI) * (0.0 if still else 60.0))
	s._hoot(hp, 26.0, {"pop": _pop(2.0), "mood": &"wave" if t > 2.2 and t < 3.4 else (&"cheer" if t > 4.6 and t < 6.0 else &"idle")})


## A panel's short ruler: centred, over the strip at the bottom where Hoot's notes go.
static func _panel_ruler(panel: Rect2) -> Rect2:
	return Rect2(panel.get_center().x - 22, panel.position.y + 50, 44, 196)


# ---------------------------------------------------------------- 8. recap

## Four numbered tiles pop up in a row; Hoot bows; the curtains close: "Your turn, trainee!"
func _set_recap() -> void:
	var p: Dictionary = params.get("recap", {})
	var tiles: Array = p.get("tiles", [])
	var still := s._motion < 1.0
	for i in tiles.size():
		var c := Vector2(190.0 + 170.0 * i, 196.0)
		var t0 := 0.6 + 0.6 * i
		var k := _k(t0, t0 + 0.35) if still else _pop(t0, 0.45)
		if k <= 0.01:
			continue
		s._push(Stage2D._about(c, (-0.04 + 0.03 * i) * s._motion, Vector2.ONE * (1.0 if still else k)))
		var a := k if still else 1.0
		var rr := Rect2(c - Vector2(76, 104), Vector2(152, 208))
		s._rbox(Rect2(rr.position + Vector2(0, 6), rr.size), Color(Stage2D.INK, 0.2 * a), 16, 0)
		s._rbox(rr, Color(Palette.PAPER, a), 16, 4, Color(Stage2D.INK, a))
		s.draw_circle(rr.position + Vector2(20, 20), 14.0, Color(Palette.SUNNY, a), true, -1.0, true)
		s._text(str(i + 1), rr.position + Vector2(20, 20), 16, Color(Stage2D.INK, a), 700)
		_recap_icon(i, c + Vector2(0, -18), a)
		s._text(String(tiles[i]), c + Vector2(0, 72), 16, Color(Stage2D.INK, a), 700)
		s._pop_xf()
	s._hoot(Stage2D.HOOT_AT, 34.0, {"pop": _pop(0.2), "mood": &"bow" if t > 3.4 and t < 5.6 else &"wave"})
	s._curtains(1.0 - Stage2D._ease_in_out(_k(5.6, 6.8)))
	if t > 6.7:
		s._chip("Your turn, trainee!", Vector2(440, 300), Palette.PAPER, 24, Stage2D.INK, _pop(6.7))


## The tiles' pictures: two half-blocks, an ear, a little ladder, a beep beside a word block.
func _recap_icon(i: int, c: Vector2, a: float) -> void:
	match i:
		0:
			_block(c + Vector2(-30, 0), "light", FIRST_COL, {"w": 58.0, "h": 36.0, "px": 14, "alpha": a, "face": false})
			_block(c + Vector2(30, 0), "house", SECOND_COL, {"w": 58.0, "h": 36.0, "px": 14, "alpha": a, "face": false})
		1:
			_ear_icon(c, 30.0, a)
		2:
			_ladder_shape(c + Vector2(-20, -50), c + Vector2(20, 50), 5, 1.0, a)
			s._text("-10", c + Vector2(-48, -20), 15, Color(Palette.MINT.darkened(0.3), a), 700)
			s._text("+5", c + Vector2(46, 20), 15, Color(Palette.CORAL.darkened(0.2), a), 700)
		_:
			s._note(c + Vector2(-30, 10), 1.1 * a, Palette.LEFT_BLUE)
			_block(c + Vector2(30, 4), "word", SECOND_COL, {"w": 58.0, "h": 36.0, "px": 14, "alpha": a, "face": false})
			s._text("~10 dB", c + Vector2(0, 46), 14, Color(Palette.INK_SOFT, a), 700)


# ---------------------------------------------------------------- the rulers

## The y of a level on a ruler drawn in `col` (soft at the top).
static func _ry(col: Rect2, db: float) -> float:
	return col.position.y + col.size.y * clampf((db - RULER_TOP_DB) / (RULER_BOTTOM_DB - RULER_TOP_DB), 0.0, 1.0)


## A tall dB ruler: ticks every 10 dB with their labels, "soft" at the top and "LOUD" at the bottom.
## k draws it in; small: tighter labels for the mismatch panels.
func _ruler(col: Rect2, k: float, small: bool = false) -> void:
	if k <= 0.01:
		return
	s._rbox(col, Color(Palette.CREAM.lightened(0.4), k), 10, 3, Color(Stage2D.INK, k))
	var db := RULER_TOP_DB
	while db <= RULER_BOTTOM_DB:
		var y := _ry(col, db)
		s.draw_line(Vector2(col.position.x, y), Vector2(col.position.x + 14, y), Color(Stage2D.INK, k), 3.0, true)
		s._text(str(int(db)), Vector2(col.end.x - 4, y), 12 if small else 14, Color(Palette.INK_SOFT, k), 700, 0, Palette.PAPER, 1.0)
		db += 10.0
	s._text("soft", Vector2(col.get_center().x, col.position.y - 20), 14, Color(Stage2D.INK, k), 700)
	s._text("LOUD", Vector2(col.get_center().x, col.end.y + 20), 14, Color(Stage2D.INK, k), 700)


## The agreement band: `half` dB either side of the tone average, across the ruler.
func _band(col: Rect2, pta: float, half: float, a: float) -> void:
	if a <= 0.01 or half <= 0.0:
		return
	var y0 := _ry(col, pta - half)
	var y1 := _ry(col, pta + half)
	s._rbox(Rect2(Vector2(col.position.x - 18, y0), Vector2(col.size.x + 36, y1 - y0)), Color(BAND, 0.35 * a), 8, 3, Color(BAND.darkened(0.2), a))


## The beep: a music note on its side of the ruler, a pointer to the ruler's edge, its label.
func _beep_marker(at: Vector2, edge_x: float, k: float, label: String, side: float, size: float = 1.0) -> void:
	if k <= 0.01:
		return
	s.draw_line(at + Vector2(-side * 22.0 * size, 0), Vector2(edge_x, at.y), Color(Palette.LEFT_BLUE, k), 3.0, true)
	s._note(at + Vector2(0, 10 * size), 1.2 * size * k, Palette.LEFT_BLUE)
	s._chip(label, at + Vector2(0, 22 + 12 * size), Palette.LEFT_TINT, 14, Stage2D.INK, k)


## The word: a two-block word on its side of the ruler, a pointer to the ruler's edge, its label.
func _word_marker(at: Vector2, edge_x: float, k: float, label: String, side: float, size: float = 1.0) -> void:
	if k <= 0.01:
		return
	s.draw_line(Vector2(edge_x, at.y), at + Vector2(-side * 30.0 * size, 0), Color(Palette.CORAL.darkened(0.1), k), 3.0, true)
	_block(at + Vector2(-14, 0) * size, "", FIRST_COL, {"w": 28.0 * size, "h": 30.0 * size, "alpha": k, "face": false})
	_block(at + Vector2(14, 0) * size, "", SECOND_COL, {"w": 28.0 * size, "h": 30.0 * size, "alpha": k, "face": false})
	s._chip(label, at + Vector2(0, 22 + 12 * size), Palette.RIGHT_TINT, 14, Stage2D.INK, k)


# ---------------------------------------------------------------- the cast and props

## A half-word block: a chunky toy block with its syllable, two dot eyes and a smile. st: w, h, px
## (the text size), alpha, squash (a bounce), face (default true).
func _block(c: Vector2, text: String, col: Color, st: Dictionary) -> void:
	var a := float(st.get("alpha", 1.0))
	if a <= 0.01:
		return
	var w := float(st.get("w", BLOCK_W))
	var h := float(st.get("h", BLOCK_H))
	var sq := float(st.get("squash", 0.0))
	var face := bool(st.get("face", true))
	s._push(Stage2D._about(c + Vector2(0, h * 0.5), 0.0, Vector2(1.0 + sq, 1.0 - sq)))
	var rr := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	s._rbox(Rect2(rr.position + Vector2(0, 5), rr.size), Color(Stage2D.INK, 0.22 * a), 12, 0)
	s._rbox(rr, Color(col, a), int(minf(12.0, h * 0.3)), 4 if h >= 40.0 else 3, Color(Stage2D.INK, a))
	s.draw_line(rr.position + Vector2(10, 8), rr.position + Vector2(w * 0.4, 8), Color(Palette.PAPER, 0.6 * a), 3.0, true)
	var ty := 0.0
	if face and h >= 40.0:
		ty = h * 0.14
		for sd: float in [-1.0, 1.0]:
			s.draw_circle(c + Vector2(sd * 13.0, -h * 0.2), 3.2, Color(Stage2D.INK, a), true, -1.0, true)
	if text != "":
		var px := int(st.get("px", 24))
		s._text(text.to_upper(), c + Vector2(0, ty), px, Color(Stage2D.INK, a), 700)
	s._pop_xf()


## The stress mark over a stressed half (a music accent, ">"), popping in with k.
func _accent(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	var pts := PackedVector2Array([c + Vector2(-16, -9), c + Vector2(14, 0), c + Vector2(-16, 9)])
	s.draw_polyline(pts, Stage2D.INK, 9.0, true)
	s.draw_polyline(pts, Palette.CORAL, 5.0, true)
	s._pop_xf()


## A listener bean. st: look (-1 left, +1 right), mood (idle, puzzled, happy), mouth 0..1 (talking),
## ear (an ear on the side facing the speaker), pop.
func _bean(c: Vector2, h: float, col: Color, st: Dictionary) -> void:
	var k := float(st.get("pop", 1.0))
	if k <= 0.01:
		return
	var look := float(st.get("look", 0.0))
	var mood: StringName = st.get("mood", &"idle")
	var r := Vector2(h * 0.36, h * 0.5)
	var breathe := sin(t * 2.4 + c.x * 0.01) * 0.02 * s._motion
	s._push(Stage2D._about(c + Vector2(0, r.y), 0.0, Vector2(k * (1.0 - breathe), k * (1.0 + breathe))))
	s._blob(c, r, col, 4.0)
	s._ell(c + Vector2(-r.x * 0.35, -r.y * 0.45), Vector2(r.x * 0.22, r.y * 0.14), Color(Palette.PAPER, 0.5))
	if bool(st.get("ear", false)):
		var ec := c + Vector2(look * r.x * 0.98, -r.y * 0.2)
		s._blob(ec, Vector2(10, 16), col, 3.5)
		s.draw_arc(ec + Vector2(-look * 2.0, 0), 8.0, PI * 0.6 if look < 0 else -PI * 0.4, PI * 1.4 if look < 0 else PI * 0.4, 8, Color(Stage2D.INK, 0.6), 3.0, true)
	var eyes := c + Vector2(look * r.x * 0.22, -r.y * 0.36)
	for sd: float in [-1.0, 1.0]:
		var e := eyes + Vector2(sd * r.x * 0.36, 0)
		if mood == &"puzzled":
			# a squint: both eyes narrowed to lines
			s.draw_line(e + Vector2(-8, 0), e + Vector2(8, 0), Stage2D.INK, 4.0, true)
			continue
		s.draw_circle(e, 9.0, Palette.PAPER, true, -1.0, true)
		s.draw_arc(e, 9.0, 0.0, TAU, 16, Stage2D.INK, 3.0, true)
		s.draw_circle(e + Vector2(look * 3.0, 1.0), 4.2, Stage2D.INK, true, -1.0, true)
	s._ell(eyes + Vector2(-r.x * 0.55, 16), Vector2(8, 5), Color(Palette.CORAL, 0.4))
	s._ell(eyes + Vector2(r.x * 0.55, 16), Vector2(8, 5), Color(Palette.CORAL, 0.4))
	var m := eyes + Vector2(0, 26)
	var talk := float(st.get("mouth", 0.0))
	if talk > 0.05:
		s._ell(m, Vector2(8, 3.0 + 7.0 * talk), Color("#7a2a3a"))
	elif mood == &"puzzled":
		s.draw_polyline(PackedVector2Array([m + Vector2(-9, 1), m + Vector2(-3, -2), m + Vector2(3, 2), m + Vector2(9, -1)]), Stage2D.INK, 3.0, true)
	elif mood == &"happy":
		s.draw_arc(m + Vector2(0, -8), 12.0, PI * 0.15, PI * 0.85, 10, Stage2D.INK, 3.5, true)
	else:
		s.draw_arc(m + Vector2(0, -6), 9.0, PI * 0.2, PI * 0.8, 8, Stage2D.INK, 3.0, true)
	s._pop_xf()


## A rounded speech bubble with a tail to the speaker, popping in with k.
func _bubble(c: Vector2, w: float, h: float, tail_to: Vector2, k: float, bg: Color) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	var d := (tail_to - c).normalized()
	var side := Vector2(d.y, -d.x) * 14.0
	var base := c + Vector2(clampf(d.x * w * 0.5, -w * 0.3, w * 0.3), h * 0.4 * signf(d.y))
	var tail := PackedVector2Array([base + side, tail_to, base - side])
	s.draw_colored_polygon(tail, Stage2D.INK)
	var inner := PackedVector2Array([base + side * 0.6, tail_to + (base - tail_to).normalized() * 6.0, base - side * 0.6])
	var rr := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	s._rbox(Rect2(rr.position + Vector2(0, 5), rr.size), Color(Stage2D.INK, 0.2), int(h * 0.5), 0)
	s._rbox(rr, bg, int(h * 0.5), 4)
	s.draw_colored_polygon(inner, bg)
	s._pop_xf()


## A round mint tick (repeated) or coral cross (missed), popping in with k.
func _tick(c: Vector2, ok: bool, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._circ(c, 17.0, Palette.MINT if ok else Palette.CORAL, 3.0)
	if ok:
		UiDraw.check(s, c, 10.0, Palette.PAPER, 4.0)
	else:
		UiDraw.cross(s, c, 9.0, Palette.PAPER, 4.0)
	s._pop_xf()


## A rubber stamp: two lines in a tilted coral frame, landing big then settling (k 0..1).
func _stamp(c: Vector2, lines: Array, k: float, rot: float) -> void:
	if k <= 0.0:
		return
	var big := 1.0 if s._motion < 1.0 else lerpf(1.6, 1.0, Stage2D._ease_out(k))
	var a := minf(1.0, k * 2.0)
	s._push(Stage2D._about(c, rot, Vector2.ONE * big))
	s._rbox(Rect2(c - Vector2(74, 40), Vector2(148, 80)), Color(Palette.CORAL, 0.15 * a), 10, 4, Color(Palette.CORAL.darkened(0.15), a))
	for i in lines.size():
		s._text(String(lines[i]), c + Vector2(0, -15 + 30 * i), 24, Color(Palette.CORAL.darkened(0.2), a), 700)
	s._pop_xf()


## A cartoon ear (the outer curl and the inner fold), fading with a.
func _ear_icon(c: Vector2, r: float, a: float) -> void:
	if a <= 0.01:
		return
	s._blob(c, Vector2(r * 0.78, r), Color(Palette.SKIN, a), 4.0)
	s.draw_arc(c + Vector2(-r * 0.05, -r * 0.1), r * 0.5, PI * 1.1, PI * 2.25, 14, Color(Palette.SKIN_SHADE.darkened(0.2), a), 5.0, true)
	s.draw_circle(c + Vector2(r * 0.05, r * 0.28), r * 0.14, Color(Palette.SKIN_SHADE.darkened(0.3), a), true, -1.0, true)


## An eye with a coral slash through it: no reading.
func _eye_crossed(c: Vector2, r: float, a: float) -> void:
	if a <= 0.01:
		return
	var pts := PackedVector2Array()
	for i in 17:
		var u := float(i) / 16.0
		pts.append(c + Vector2(lerpf(-r, r, u), -sin(u * PI) * r * 0.62))
	for i in 17:
		var u := float(i) / 16.0
		pts.append(c + Vector2(lerpf(r, -r, u), sin(u * PI) * r * 0.62))
	s.draw_colored_polygon(pts, Color(Palette.PAPER, a))
	pts.append(pts[0])
	s.draw_polyline(pts, Color(Stage2D.INK, a), 3.5, true)
	s.draw_circle(c, r * 0.34, Color(Palette.LEFT_BLUE, a), true, -1.0, true)
	s.draw_circle(c, r * 0.16, Color(Stage2D.INK, a), true, -1.0, true)
	s.draw_line(c + Vector2(-r * 0.95, r * 0.8), c + Vector2(r * 0.95, -r * 0.8), Color(Stage2D.INK, a), 9.0, true)
	s.draw_line(c + Vector2(-r * 0.95, r * 0.8), c + Vector2(r * 0.95, -r * 0.8), Color(Palette.CORAL, a), 5.0, true)
