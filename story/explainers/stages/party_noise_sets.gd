extends "res://story/explainers/explainer_sets.gd"
## The sets of Hoot's party movie, "The Party Problem" (story/explainers/movies/party_noise.gd, Day 5):
## the quiet cafe and the same cafe with a crowd, the kitchen balance whose tilt is the SNR, the
## volume knob beside a little SNR-O-METER, the split table of two diners (SNR loss), the menu of the
## Party Noise Test's six courses, the till receipt of a typical diner and the door where tonight's
## guest knocks.
## Numbers come from each scene's params (copied in as data from SpeechRules; story/tests/
## test_movie_party_noise.gd pins them): nothing here calls SpeechRules, the SPEECH screen or other
## Day 5 UI code.
## Same rules as every set: a pure function of t (no tweens, nodes or RNG), sounds only in the movie's
## cues; the crowd, the chatter and the loud knob are drawn, never played. Reduced motion
## (s._motion < 1): cuts and crossfades only, so things appear without a pop, the plates and the
## beam step instead of easing, no crumbling letters, no rolling peas, the waiter stands still and
## the receipt prints at once.

const SETS: Array[StringName] = [&"quiet", &"crowd", &"scale", &"knob", &"gap", &"menu", &"receipt", &"tonight"]

## The marquee (scene 1): the shape of the stage's own title card and the case movies' _marquee().
const CARD_C := Vector2(440, 226)
const CARD_SIZE := Vector2(640, 290)
const CARD_FILL := Color("#3a2f55")
const PROP_AT := Vector2(-222, 8)
const LINE_SHIFT := 40.0

## The cafe (scenes 1-2): the couple's table, their seats and her line's bubble.
const TABLE_AT := Vector2(440, 326)
const HER_AT := Vector2(300, 300)
const HIM_AT := Vector2(580, 300)
const BEAN_H := 140.0
const HER_BUBBLE := Vector2(232, 128)
const HIS_BUBBLE := Vector2(612, 168)
const FLOOR_Y := 392.0
const WINDOW := Rect2(690, 58, 148, 108)
## The crowd's tables: [where the table's foot stands, scale, pops in at (s)], the far ones first
## (drawn first: the couple sits in front of the first four, the last two stand in front of them).
const CROWD_TABLES: Array = [
	[Vector2(440, 236), 0.4, 1.5], [Vector2(800, 214), 0.38, 1.5],
	[Vector2(112, 300), 0.55, 0.8], [Vector2(768, 300), 0.55, 0.8],
	[Vector2(86, 452), 0.66, 2.2], [Vector2(794, 452), 0.66, 2.2],
]

## The kitchen balance (scene 3): the beam's pivot, its half length and how far a pan hangs.
const PIVOT := Vector2(440, 150)
const BEAM_HALF := 250.0
const PAN_DROP := 92.0
## Radians of tilt per dB the voice outweighs the party.
const TILT_PER_DB := 0.011
## One party plate per this many dB above PLATES_FROM (45 -> 2 plates, 55 -> 4, 65 -> 6).
const PLATE_DB := 5.0
const PLATES_FROM := 35.0

## The little SNR-O-METER (scene 4): bars from METER_BOTTOM up, METER_PX_PER_DB per dB.
const METER_BOTTOM := 384.0
const METER_PX_PER_DB := 3.0
const VOICE_X := 590.0
const PARTY_X := 714.0
const BAR_W := 70.0

## The split table (scene 5): the ruler between the diners, GAP_PX_PER_DB a dB of gap, 0 at GAP_ZERO_Y.
const GAP_ZERO_Y := 352.0
const GAP_PX_PER_DB := 20.0
const GAP_MAX_DB := 12.0

const HER := Color("#ffd9e6")
const HIM := Color("#bfe6ff")
const DINERS: Array[Color] = [Color("#d9d2e6"), Color("#c9d6dc"), Color("#e2d6cc"), Color("#cfc8dc")]
const CHATTER_BG := Color("#ece8f2")
const CHATTER_INK := Color("#857d96")
const PARTY_GREY := Color("#b3abc4")
const CLOTH := Color("#fff4f0")
const CLOTH_CHECK := Color("#ffc9bd")
const FLOOR_WOOD := Color("#e9c79c")
const NIGHT := Color("#3b4a7a")
const SILHOUETTE := Color("#3a2f55")
const PEA := Color("#7ccf6a")
const RECEIPT := Color("#fffdf7")


# ---------------------------------------------------------------- 1. quiet (the lead-in)

## The marquee holds while Hoot asks the question and names the answer (params.card_hold, the two
## params.questions chips), then it flips away on the quiet cafe: two beans, one crisp bubble, a happy
## tick. The cafe runs on the stage's clock shifted by card_hold - 2 s, the way the stage's
## _set_meet() does it (s.t, not this script's copy: every helper reads the stage's t). The cafe is
## drawn first so the card covers it while it holds.
func _set_quiet() -> void:
	var p: Dictionary = params.get("quiet", {})
	var hold := float(params.get("card_hold", 2.0))
	var real_t := s.t
	s.t = real_t - (hold - 2.0)
	t = s.t
	_quiet_cafe(p)
	s.t = real_t
	t = real_t
	var card_out := _k(hold, hold + 0.45)
	if card_out < 1.0:
		_marquee(String(p.get("title", scene_title)), String(p.get("starring", "")), card_out)
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
	# "The Party" over "Problem": the last word on its own line, like the masking movie's card
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


## A little cafe table with its candle, one crisp bubble and a grey chatter bubble over it.
func _marquee_prop(at: Vector2) -> void:
	var bob := sin(t * 3.0) * 3.0 * s._motion
	s._push(Stage2D._about(at + Vector2(0, 40), 0.0, Vector2.ONE * 0.42))
	_table(at + Vector2(0, 40), 200.0)
	_candle(at + Vector2(0, 14))
	s._pop_xf()
	_speech(at + Vector2(-20, -30 + bob), 70.0, 34.0, at + Vector2(-34, 4), Palette.PAPER, Stage2D.INK)
	s._text("hi!", at + Vector2(-20, -30 + bob), 17, Stage2D.INK, 700)
	_chatter(at + Vector2(36, -60 - bob), "blah", 1.0)


## The quiet cafe after the card: the room, the couple at their table, her line, his happy tick.
func _quiet_cafe(p: Dictionary) -> void:
	var line := String(p.get("line", "Shall we share the tiramisu?"))
	_room(_in(1.8, 0.4))
	var talk := t > 2.8 and t < 4.0
	_couple(_in(2.0, 0.45), _in(2.2, 0.45), {"mouth": absf(sin(t * 12.0)) * s._motion if talk else 0.0, "look": 1.0, "bow": true},
		{"look": -1.0, "mood": &"happy" if t > 4.2 else &"idle"})
	var bk := _in(2.8, 0.4)
	_her_bubble(line, bk)
	var tk := _in(4.2, 0.4)
	if tk > 0.01:
		_speech(HIS_BUBBLE, 96.0, 64.0, HIM_AT + Vector2(-10, -66), Palette.PAPER, Stage2D.INK, tk)
		_tick(HIS_BUBBLE, 20.0, tk)
	if t > 5.4:
		s._chip("One voice, no crowd: easy!", Vector2(440, 414), Palette.MINT, 20, Stage2D.INK, _in(5.4, 0.45))
	s._hoot(Vector2(70, 372), 34.0, {"pop": _in(2.4, 0.45), "mood": &"wave" if t > 3.0 and t < 5.6 else &"idle"})


# ---------------------------------------------------------------- 2. crowd

## The same cafe fills up: six tables pop in two at a time, each with its grey chatter; a waiter
## weaves past. Her bubble does not change, but chatter crowds over it and he is puzzled.
func _set_crowd() -> void:
	var p: Dictionary = params.get("crowd", {})
	var line := String(p.get("line", "Shall we share the tiramisu?"))
	var chatter: Array = p.get("chatter", [])
	var n := mini(int(p.get("tables", CROWD_TABLES.size())), CROWD_TABLES.size())
	_room(1.0)
	# the back tables and the side tables first; the couple sits in front of them
	for i in mini(n, 4):
		var row: Array = CROWD_TABLES[i]
		_diner_table(row[0], float(row[1]), float(row[2]), i)
	var puzzled := t > 3.0
	_couple(1.0, 1.0, {"look": 1.0, "bow": true, "mouth": absf(sin(t * 12.0)) * s._motion if t > 0.4 and t < 1.6 else 0.0},
		{"look": -1.0, "mood": &"puzzled" if puzzled else &"idle"})
	for i in range(4, n):
		var row: Array = CROWD_TABLES[i]
		_diner_table(row[0], float(row[1]), float(row[2]), i)
	_her_bubble(line, 1.0)
	# each table's chatter, then two more bubbles crowding over hers
	for i in n:
		var row: Array = CROWD_TABLES[i]
		var foot: Vector2 = row[0]
		var sc := float(row[1])
		var t0 := float(row[2]) + 0.2
		for j in 2:
			var idx := (i * 2 + j) % maxi(1, chatter.size())
			var word := String(chatter[idx]) if not chatter.is_empty() else "haha"
			var wob := sin(t * 2.2 + i * 1.7 + j) * 3.0 * s._motion
			var at := foot + Vector2((-1.0 if j == 0 else 1.0) * 64.0 * sc, -160.0 * sc - 20.0 - 26.0 * j + wob)
			_chatter(at, word, _in(t0 + 0.15 * j, 0.35), sin(t * 1.6 + i + j) * 0.05 * s._motion)
	var cover: Array[Array] = [[Vector2(150, 156), "ha-ha!", 3.2], [Vector2(330, 100), "happy birthday!", 3.5], [Vector2(222, 182), "clink!", 3.8]]
	for cv: Array in cover:
		var at: Vector2 = cv[0]
		var wob2 := sin(t * 2.6 + float(cv[2])) * 2.0 * s._motion
		_chatter(at + Vector2(0, wob2), String(cv[1]), _in(float(cv[2]), 0.35), 0.0)
	if puzzled:
		var bounce := 0.0 if s._motion < 1.0 else absf(sin((t - 3.0) * 4.0)) * 14.0
		s._text("?", HIM_AT + Vector2(84, -80 - bounce), 46, Palette.CORAL, 700, 8, Palette.PAPER, 0.5, _in(3.0, 0.35))
	_waiter()
	if t > 4.4:
		s._chip("Her voice: the SAME", Vector2(310, 50), HER, 18, Stage2D.INK, _in(4.4, 0.4))
	if t > 5.0:
		s._chip("The noise: MORE", Vector2(584, 50), PARTY_GREY.lightened(0.3), 18, Stage2D.INK, _in(5.0, 0.4))


## One crowd table standing at `foot`: two grey diners chatting behind a small table, scaled by sc,
## popping in at t0.
func _diner_table(foot: Vector2, sc: float, t0: float, i: int) -> void:
	var k := _in(t0, 0.45)
	if k <= 0.01:
		return
	var c := foot - Vector2(0, 64)   # the table top, before scaling
	s._push(Stage2D._about(foot, 0.0, Vector2.ONE * sc * k))
	for j in 2:
		var side := -1.0 if j == 0 else 1.0
		var talking := s._motion >= 1.0 and fposmod(t * 0.8 + i * 0.37 + j * 0.5, 1.0) < 0.55
		_bean(c + Vector2(side * 118.0, -26.0), BEAN_H, DINERS[(i + j) % DINERS.size()],
			{"look": -side, "mouth": absf(sin(t * 11.0 + i)) if talking else 0.0, "mood": &"happy"})
	_table(c, 220.0)
	s._pop_xf()


## The waiter weaves across the front with a tray of glasses. He is only bustle, so with reduced
## motion he stays in the kitchen (standing still he would hide a table's chatter).
func _waiter() -> void:
	if t < 2.9 or s._motion < 1.0:
		return
	var x := lerpf(-70.0, 950.0, _k(2.9, 6.9))
	if x < -60.0 or x > 940.0:
		return
	var bob := absf(sin(t * 9.0)) * -5.0
	var c := Vector2(x, 346 + bob)
	_bean(c, 150.0, Palette.PAPER, {"look": 1.0, "mood": &"happy"})
	# a bow tie and the tray up on one hand
	var tie := c + Vector2(0, 30)
	s.draw_colored_polygon(PackedVector2Array([tie, tie + Vector2(-12, -7), tie + Vector2(-12, 7)]), Stage2D.INK)
	s.draw_colored_polygon(PackedVector2Array([tie, tie + Vector2(12, -7), tie + Vector2(12, 7)]), Stage2D.INK)
	var hand := c + Vector2(64, -64)
	s.draw_line(c + Vector2(48, -8), hand, Stage2D.INK, 9.0, true)
	s.draw_line(c + Vector2(48, -8), hand, Palette.PAPER, 5.0, true)
	s._rbox(Rect2(hand + Vector2(-46, -8), Vector2(92, 10)), Palette.LCD_DIM, 5, 3)
	for g in 3:
		var gx := hand.x - 28.0 + 28.0 * g
		s._rbox(Rect2(Vector2(gx - 7, hand.y - 34), Vector2(14, 26)), Color(Palette.SKY, 0.9), 4, 3)
		s.draw_rect(Rect2(Vector2(gx - 5, hand.y - 22), Vector2(10, 12)), Color(Palette.CORAL, 0.55))


# ---------------------------------------------------------------- 3. scale

## A kitchen balance: one voice plate on the left pan, the party's plates on the right. The voice
## outweighs the party by the SNR, so its pan sinks and the gold bracket between the two pans reads
## the gap; more party plates land, the party's pan sinks too, the beam levels and the gap shrinks.
func _set_scale() -> void:
	var p: Dictionary = params.get("scale", {})
	var voice := float(p.get("voice", 70))
	var party: Array = p.get("party", [45, 55, 65])
	var at: Array = p.get("at", [1.0, 3.6, 6.0])
	var still := s._motion < 1.0
	# where the party is now (it eases between its steps; reduced motion: it steps)
	var party_now := float(party[0])
	var plates_now := _plates_for(float(party[0]))
	var last_step := 0
	for i in range(1, mini(party.size(), at.size())):
		var e := 1.0 if (still and t >= float(at[i])) else (0.0 if still else Stage2D._ease_in_out(_k(float(at[i]), float(at[i]) + 0.5)))
		party_now = lerpf(party_now, float(party[i]), e)
		if t >= float(at[i]) - 0.35:
			plates_now = _plates_for(float(party[i]))
		if t >= float(at[i]):
			last_step = i
	var first_k := 1.0 if (still and t >= float(at[0])) else (0.0 if still else _k(float(at[0]) - 0.35, float(at[0])))
	# the heavier side sinks: the voice's pan (left) sits lower by the gap
	var tilt := -clampf((voice - party_now) * TILT_PER_DB, -0.45, 0.45)
	if t < float(at[0]):
		tilt = -0.45   # the voice plate alone: the beam tips all the way
	tilt += _ring(float(at[last_step]), 0.05, 14.0, 4.0)
	# the stand, the beam and its dial
	s._rbox(Rect2(PIVOT.x - 90, 384, 180, 24), Palette.WOOD.darkened(0.1), 10, 4)
	s.draw_line(PIVOT + Vector2(0, 8), Vector2(PIVOT.x, 386), Stage2D.INK, 14.0, true)
	s.draw_line(PIVOT + Vector2(0, 8), Vector2(PIVOT.x, 386), Palette.WOOD, 8.0, true)
	var dir := Vector2(cos(tilt), sin(tilt))
	var left_end := PIVOT - dir * BEAM_HALF
	var right_end := PIVOT + dir * BEAM_HALF
	s.draw_line(left_end, right_end, Stage2D.INK, 14.0, true)
	s.draw_line(left_end, right_end, Palette.SUNNY.darkened(0.15), 8.0, true)
	s._circ(PIVOT, 14.0, Palette.SUNNY, 4.0)
	var lp := left_end + Vector2(0, PAN_DROP)
	var rp := right_end + Vector2(0, PAN_DROP)
	_pan(left_end, lp)
	_pan(right_end, rp)
	# the voice plate, and the party's stack (new plates drop in; reduced motion: they appear)
	_plate(lp + Vector2(0, -10), 56.0, Palette.PAPER, Palette.MINT)
	var top_r := rp + Vector2(0, -10)
	for i in plates_now:
		var y := rp.y - 10.0 - 9.0 * i
		var drop := 0.0
		if not still:
			var land := _land_time(i, party, at)
			drop = -160.0 * pow(1.0 - _k(land - 0.35, land), 2.0)
			if t < land - 0.35:
				continue
		elif t < _land_time(i, party, at):
			continue
		_plate(Vector2(rp.x, y + drop), 52.0, PARTY_GREY.lightened(0.25), PARTY_GREY)
		top_r = Vector2(rp.x, y)
	# their tags
	s._chip("VOICE %d" % int(voice), lp + Vector2(0, -50), Palette.MINT, 18, Stage2D.INK, _in(0.4, 0.4))
	if first_k > 0.0:
		s._chip("PARTY %d" % int(roundf(party_now)), top_r + Vector2(0, -38), PARTY_GREY.lightened(0.3), 18, Stage2D.INK, _in(float(at[0]), 0.4))
	# the gap: dashed levels from both pans and the gold bracket between them
	var bk := _in(float(at[0]) + 0.3, 0.4)
	if bk > 0.01:
		var y_voice := lp.y - 14.0
		var y_party := rp.y - 14.0
		var bx := 440.0   # y_party is above y_voice: the beam tips to the voice
		s._dashed_curve(lp + Vector2(60, -14), Vector2((lp.x + bx) * 0.5 + 40, y_voice), Vector2(bx - 8, y_voice), Palette.INK_SOFT, 1.0)
		s._dashed_curve(rp + Vector2(-60, -14), Vector2((rp.x + bx) * 0.5 - 40, y_party), Vector2(bx + 8, y_party), Palette.INK_SOFT, 1.0)
		_bracket(bx, y_party, y_voice, "SNR %d dB" % int(roundf(voice - party_now)), bk)
	if t > 7.0:
		s._chip("Smaller gap: harder to follow", Vector2(570, 40), Palette.CORAL.lightened(0.35), 19, Stage2D.INK, _in(7.0, 0.45))
	s._hoot(Vector2(72, 372), 34.0, {"pop": _in(0.5, 0.45), "mood": &"cheer" if t > 7.0 else &"idle"})


## How many party plates a level puts on the pan.
static func _plates_for(party_db: float) -> int:
	return maxi(1, int(roundf((party_db - PLATES_FROM) / PLATE_DB)))


## When plate i lands: the first step's plates at its time, each later step's new plates at theirs.
static func _land_time(i: int, party: Array, at: Array) -> float:
	for step in mini(party.size(), at.size()):
		if i < _plates_for(float(party[step])):
			return float(at[step])
	return float(at[-1])


## A balance pan hanging from the beam's end on two chains.
func _pan(end: Vector2, c: Vector2) -> void:
	for sd: float in [-1.0, 1.0]:
		s.draw_line(end, c + Vector2(sd * 62.0, -4.0), Stage2D.INK, 3.0, true)
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		pts.append(c + Vector2(cos(a) * 76.0, sin(a) * 18.0))
	s.draw_colored_polygon(pts, Palette.SKY.darkened(0.12))
	pts.append(pts[0])
	s.draw_polyline(pts, Stage2D.INK, 4.0, true)


## A dinner plate seen from the side: an ellipse with a coloured rim.
func _plate(c: Vector2, r: float, fill: Color, rim: Color) -> void:
	s._blob(c, Vector2(r, r * 0.2), rim, 3.0)
	s._ell(c + Vector2(0, -1), Vector2(r * 0.72, r * 0.12), fill)


## The gold SNR bracket from y_top to y_bottom at x, with its chip on it (none when label is "").
func _bracket(x: float, y_top: float, y_bottom: float, label: String, k: float) -> void:
	if k <= 0.01:
		return
	var col := Stage2D.GOLD
	var a := Vector2(x, y_top)
	var b := Vector2(x, y_bottom)
	for w: float in [9.0, 5.0]:
		var cc := Stage2D.INK if w > 6.0 else col
		s.draw_line(a, b, cc, w, true)
		s.draw_line(a + Vector2(-12, 0), a + Vector2(12, 0), cc, w, true)
		s.draw_line(b + Vector2(-12, 0), b + Vector2(12, 0), cc, w, true)
	if label != "":
		s._chip(label, Vector2(x, (y_top + y_bottom) * 0.5), Palette.SUNNY, 19, Stage2D.INK, k)


# ---------------------------------------------------------------- 4. knob

## Hoot cranks a giant volume knob: the voice and the party bars both grow 10 dB (drawn loud-lines;
## nothing gets louder) and the gold bracket rides up between their tops, still 5 dB.
func _set_knob() -> void:
	var p: Dictionary = params.get("knob", {})
	var voice: Array = p.get("voice", [70, 80])
	var party: Array = p.get("party", [65, 75])
	var still := s._motion < 1.0
	var e := (1.0 if t >= 1.0 else 0.0) if still else Stage2D._ease_in_out(_k(1.0, 1.8))
	var v := lerpf(float(voice[0]), float(voice[1]), e)
	var pa := lerpf(float(party[0]), float(party[1]), e)
	# the knob and Hoot at it
	var turn := lerpf(-0.9, 0.7, e) + _ring(1.0, 0.12, 22.0, 7.0) + _ring(1.6, 0.12, 22.0, 7.0)
	_knob(Vector2(214, 214), 82.0, turn)
	s._hoot(Vector2(86, 366), 38.0, {"pop": _in(0.3, 0.45), "mood": &"cheer" if t > 1.0 and t < 2.4 else &"idle"})
	if t > 1.0 and t < 2.6:
		s._text("crank!", Vector2(214, 96), 24, Palette.CORAL, 700, 7, Palette.PAPER, 0.5, _in(1.0, 0.3))
	# the meter
	var mk := _in(0.2, 0.45)
	if mk > 0.01:
		var panel := Rect2(500, 52, 330, 360)
		s._push(Stage2D._about(panel.get_center(), 0.0, Vector2.ONE * mk))
		s._rbox(Rect2(panel.position + Vector2(0, 6), panel.size), Color(Stage2D.INK, 0.22), 22, 0)
		s._rbox(panel, Palette.LCD_BG, 22, 4)
		s._text("SNR-O-METER", Vector2(panel.get_center().x, 74), 16, Palette.SUNNY, 700)
		for db in range(0, 91, 10):
			var y := METER_BOTTOM - db * METER_PX_PER_DB
			s.draw_line(Vector2(516, y), Vector2(528, y), Palette.LCD_DIM, 2.0, true)
			if db % 30 == 0:
				s._text(str(db), Vector2(540, y), 12, Palette.LCD_DIM, 700, 0, Palette.PAPER, 0.0)
		_bar(VOICE_X, v, Palette.MINT)
		_bar(PARTY_X, pa, PARTY_GREY)
		# where both bars were before the crank: each grew by the same step
		if e > 0.5:
			for pair: Array in [[VOICE_X, float(voice[0])], [PARTY_X, float(party[0])]]:
				var y0 := METER_BOTTOM - float(pair[1]) * METER_PX_PER_DB
				for d in 5:
					var x := float(pair[0]) - BAR_W * 0.5 + 4.0 + d * 14.0
					s.draw_line(Vector2(x, y0), Vector2(x + 8.0, y0), Color(Palette.PAPER, 0.85), 3.0, true)
		s._text("VOICE %d" % int(roundf(v)), Vector2(VOICE_X, 400), 15, Palette.MINT, 700)
		s._text("PARTY %d" % int(roundf(pa)), Vector2(PARTY_X, 400), 15, PARTY_GREY.lightened(0.3), 700)
		s._pop_xf()
		var yv := METER_BOTTOM - v * METER_PX_PER_DB
		var yp := METER_BOTTOM - pa * METER_PX_PER_DB
		var bx := (VOICE_X + PARTY_X) * 0.5
		s.draw_line(Vector2(VOICE_X + BAR_W * 0.5, yv), Vector2(bx, yv), Color(Palette.SUNNY, mk), 2.0, true)
		s.draw_line(Vector2(PARTY_X - BAR_W * 0.5, yp), Vector2(bx, yp), Color(Palette.SUNNY, mk), 2.0, true)
		_bracket(bx, yv, yp, "", mk)
		s._chip("SNR %d dB" % int(roundf(v - pa)), Vector2(bx, yv - 30), Palette.SUNNY, 18, Stage2D.INK, mk)
		if t > 1.0 and t < 3.2 and not still:
			s._loud_lines(Vector2(VOICE_X, yv + 20), 40.0)
			s._loud_lines(Vector2(PARTY_X + 50, yp + 20), 40.0)
	if t > 2.6:
		s._chip("Both up 10 dB", Vector2(214, 330), Palette.PAPER, 20, Stage2D.INK, _in(2.6, 0.4))
	if t > 4.2:
		s._big_sign("STILL 5 dB!", Vector2(300, 400), _in(4.2, 0.45), sin(t * 3.0) * 0.03 * s._motion, Palette.SUNNY)


## One meter bar from the bottom up to db.
func _bar(x: float, db: float, col: Color) -> void:
	var h := db * METER_PX_PER_DB
	s._rbox(Rect2(x - BAR_W * 0.5, METER_BOTTOM - h, BAR_W, h), col, 8, 3, Palette.PAPER)


## A big volume knob: a dial face with tick marks and a pointer at `turn` (radians from up).
func _knob(c: Vector2, r: float, turn: float) -> void:
	s._circ(c + Vector2(0, 8), r + 12.0, Color(Stage2D.INK, 0.2), 0.0)
	s._circ(c, r + 12.0, Palette.PAPER, 4.0)
	for i in 11:
		var ang := -PI * 0.5 + lerpf(-1.3, 1.3, i / 10.0)
		var col := Palette.MINT if i < 7 else Palette.CORAL
		s.draw_line(c + Vector2(cos(ang), sin(ang)) * (r + 1.0), c + Vector2(cos(ang), sin(ang)) * (r + 9.0), col.darkened(0.2), 4.0, true)
	s._circ(c, r * 0.84, Color("#4a3d66"), 4.0)
	for i in 12:
		var ga := TAU * i / 12.0 + turn
		s.draw_circle(c + Vector2(cos(ga), sin(ga)) * r * 0.84, 5.0, Color("#4a3d66"), true, -1.0, true)
	var ang := -PI * 0.5 + turn
	s.draw_line(c, c + Vector2(cos(ang), sin(ang)) * r * 0.7, Palette.SUNNY, 8.0, true)
	s._circ(c + Vector2(cos(ang), sin(ang)) * r * 0.62, r * 0.1, Palette.SUNNY, 3.0)
	s._text("VOLUME", c + Vector2(0, r * 0.42), 15, Palette.PAPER, 700)


# ---------------------------------------------------------------- 5. gap

## Split screen: a diner with typical ears follows half the words at a small gap; the other diner's
## words crumble at that gap and come back only when his gap is much bigger. The ruler between them
## is the gap each needs for half the words; the stretch from one to the other is SNR LOSS.
func _set_gap() -> void:
	var p: Dictionary = params.get("gap", {})
	var typical := float(p.get("typical_snr50", 2))
	var other := float(p.get("other_snr50", 10))
	var words: Array = p.get("words", ["Try", "the", "lemon", "cake!"])
	var crisp: Array = p.get("crisp", [0, 2])
	var still := s._motion < 1.0
	s._chip("TYPICAL EARS", Vector2(200, 76), Palette.MINT, 17, Stage2D.INK, _in(0.3, 0.4))
	s._chip("OTHER EARS", Vector2(680, 76), Palette.SKY, 17, Stage2D.INK, _in(0.6, 0.4))
	# the other diner's gap widens from the typical one to his own
	var widen := (1.0 if t >= 4.4 else 0.0) if still else Stage2D._ease_in_out(_k(4.4, 5.0))
	var other_now := lerpf(typical, other, widen)
	# the diners, each with his word tiles in a bubble
	var lk := _in(0.4, 0.45)
	var rk := _in(0.8, 0.45)
	var lost := t > 2.6 and t < 5.0
	var left_at := Vector2(130, 322)
	var right_at := Vector2(750, 322)
	if lk > 0.01:
		s._push(Stage2D._about(left_at + Vector2(0, 60), 0.0, Vector2.ONE * lk))
		_bean(left_at, 120.0, HIM, {"look": 1.0, "mood": &"happy" if t > 1.4 else &"idle"})
		s._pop_xf()
		_speech(Vector2(206, 190), 300.0, 64.0, left_at + Vector2(16, -56), Palette.PAPER, Stage2D.INK, lk)
	if rk > 0.01:
		s._push(Stage2D._about(right_at + Vector2(0, 60), 0.0, Vector2.ONE * rk))
		_bean(right_at, 120.0, Palette.SUNNY.lightened(0.45), {"look": -1.0, "mood": &"puzzled" if lost else (&"happy" if t > 5.0 else &"idle")})
		s._pop_xf()
		_speech(Vector2(690, 190), 300.0, 64.0, right_at + Vector2(-16, -56), Palette.PAPER, Stage2D.INK, rk)
	_tiles(Vector2(206, 190), words, crisp, _in(1.2, 0.35), 1.2, lk)
	var right_crumble := _k(2.6, 3.2) if not still else (1.0 if t >= 2.6 else 0.0)
	_tiles_other(Vector2(690, 190), words, crisp, right_crumble, _in(5.0, 0.35), rk)
	s._chip("%d dB gap: half the words" % int(typical), Vector2(200, 418), Palette.PAPER, 16, Stage2D.INK, _in(1.4, 0.4))
	if t > 5.0:
		s._chip("needs %d dB for half" % int(other), Vector2(680, 418), Palette.PAPER, 16, Stage2D.INK, _in(5.0, 0.4))
	elif t > 2.6:
		s._chip("%d dB gap: words crumble" % int(typical), Vector2(680, 418), Palette.CORAL.lightened(0.4), 16, Stage2D.INK, _in(2.6, 0.4))
	# the ruler: the gap each needs for half the words, a marker from each side
	var gk := _in(0.6, 0.45)
	if gk <= 0.01:
		return
	s._push(Stage2D._about(Vector2(440, GAP_ZERO_Y), 0.0, Vector2(1.0, gk)))
	var top := _gap_y(GAP_MAX_DB) - 10.0
	s._rbox(Rect2(424, top, 32, GAP_ZERO_Y + 10.0 - top), Palette.SUNNY.lightened(0.35), 6, 3)
	# the extra stretch (typical to his), lit up once the ruler has measured it
	var lit := _in(5.8, 0.4)
	if lit > 0.01:
		var ya := _gap_y(typical)
		var yb := _gap_y(other)
		s._rbox(Rect2(426, yb, 28, ya - yb), Color(Palette.CORAL, 0.75 * minf(1.0, lit)), 4, 0)
	for db in int(GAP_MAX_DB) + 1:
		var y := _gap_y(db)
		s.draw_line(Vector2(424, y), Vector2(434 if db % 2 == 0 else 430, y), Stage2D.INK, 2.0, true)
		if db % 2 == 0:
			s._text(str(db), Vector2(446, y), 12, Stage2D.INK, 700)
	s._pop_xf()
	s._text("gap for half", Vector2(440, GAP_ZERO_Y + 24), 13, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, gk)
	_gap_marker(Vector2(396, _gap_y(typical)), "%d dB" % int(typical), Palette.MINT, -1.0, _in(1.4, 0.4))
	_gap_marker(Vector2(484, _gap_y(other_now)), "%d dB" % int(roundf(other_now)), Palette.SKY, 1.0, _in(1.8, 0.4))
	if lit > 0.01:
		s._chip("+%d dB = SNR LOSS" % int(other - typical), Vector2(440, 72), Palette.CORAL, 19, Palette.PAPER, lit)
		if not still:
			s._sparkles(Vector2(440, 72), 5.8, 10, 90.0, Palette.SUNNY)


## Where `db` of gap sits on the ruler.
static func _gap_y(db: float) -> float:
	return GAP_ZERO_Y - db * GAP_PX_PER_DB


## A marker chip beside the ruler with a little pointer to its mark (side -1: from the left).
func _gap_marker(at: Vector2, label: String, col: Color, side: float, k: float) -> void:
	if k <= 0.01:
		return
	var tip := Vector2(440.0 + side * 18.0, at.y)
	s.draw_line(at, tip, Stage2D.INK, 3.0, true)
	s.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(side * 10.0, -7), tip + Vector2(side * 10.0, 7)]), Stage2D.INK)
	s._chip(label, at + Vector2(side * 12.0, 0), col, 16, Stage2D.INK, k)


## The typical diner's four word tiles: half crisp, half crumbs (from `state` on).
func _tiles(c: Vector2, words: Array, crisp: Array, state: float, t0: float, k: float) -> void:
	if k <= 0.01:
		return
	var xs := _tile_xs(c, words)
	for i in words.size():
		var good := crisp.has(i)
		if state < 0.5 or good:
			_tile(Vector2(xs[i], c.y), String(words[i]), 1.0, 0.0)
		else:
			_tile(Vector2(xs[i], c.y), String(words[i]), 0.0, _k(t0, t0 + 0.6) if s._motion >= 1.0 else 1.0)


## The other diner's tiles: all crumble at the small gap, half come back at his own gap.
func _tiles_other(c: Vector2, words: Array, crisp: Array, crumble: float, back: float, k: float) -> void:
	if k <= 0.01:
		return
	var xs := _tile_xs(c, words)
	for i in words.size():
		var good := crisp.has(i) and back > 0.01
		if good:
			_tile(Vector2(xs[i], c.y), String(words[i]), back, 0.0)
		elif crumble <= 0.0:
			_tile(Vector2(xs[i], c.y), String(words[i]), 1.0, 0.0)
		else:
			_tile(Vector2(xs[i], c.y), String(words[i]), 0.0, crumble)


func _tile_xs(c: Vector2, words: Array) -> Array[float]:
	var f := Stage2D.UiKit.font(700)
	var ws: Array[float] = []
	var total := 0.0
	for w: Variant in words:
		var ww := f.get_string_size(String(w), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 18.0
		ws.append(ww)
		total += ww + 8.0
	var xs: Array[float] = []
	var x := c.x - (total - 8.0) * 0.5
	for ww: float in ws:
		xs.append(x + ww * 0.5)
		x += ww + 8.0
	return xs


## A word tile: crisp (k) in ink on paper, or crumbled (crumb 0..1: its letters fall as breadcrumbs
## and a dotted outline stays; reduced motion: just the outline and a few crumbs).
func _tile(c: Vector2, word: String, k: float, crumb: float) -> void:
	var f := Stage2D.UiKit.font(700)
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 18.0
	var rr := Rect2(c - Vector2(w * 0.5, 18), Vector2(w, 36))
	if k > 0.01:
		s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
		s._rbox(rr, Palette.PAPER, 10, 3)
		s._text(word, c, 20, Stage2D.INK, 700)
		s._pop_xf()
		return
	# the outline it leaves, dotted
	var per := 2.0 * (rr.size.x + rr.size.y)
	for i in 18:
		s.draw_circle(Stage2D._rect_perimeter(rr, per * i / 18.0), 1.8, Color(Palette.INK_SOFT, 0.7), true, -1.0, true)
	var crumbs := 5
	for i in crumbs:
		var fall := 0.0 if s._motion < 1.0 else 34.0 * crumb * crumb * (0.6 + 0.4 * Stage2D._hash(i, word.length()))
		var px := c + Vector2(-w * 0.35 + w * 0.7 * i / (crumbs - 1.0), 10.0 + fall)
		s._blob(px, Vector2(4.0, 3.0), Palette.WOOD, 2.0, i * 0.7)
	if crumb < 1.0 and s._motion >= 1.0:
		# the letters on their way down
		s._text(word, c + Vector2(0, 22.0 * crumb), 20, Color(Palette.WOOD.darkened(0.25), 1.0 - crumb), 700)


# ---------------------------------------------------------------- 6. menu

## The menu of the Party Noise Test: six courses, each at its SNR with five green peas for its key
## words; tiny diners crowd the margins more with every course.
func _set_menu() -> void:
	var p: Dictionary = params.get("menu", {})
	var courses: Array = p.get("courses", [])
	var peas := int(p.get("key_words", 5))
	var still := s._motion < 1.0
	var open := (1.0 if t >= 0.6 else 0.0) if still else Stage2D._ease_out(_k(0.6, 1.1))
	if open <= 0.01:
		s._rbox(Rect2(430, 58, 20, 360), Palette.PAPER, 6, 4)
		return
	var card := Rect2(262, 54, 356, 368)
	s._push(Stage2D._about(card.get_center(), 0.0, Vector2(open, 1.0)))
	s._rbox(Rect2(card.position + Vector2(0, 7), card.size), Color(Stage2D.INK, 0.2), 18, 0)
	s._rbox(card, Palette.PAPER, 18, 4)
	s._rbox(card.grow(-10), Palette.PAPER, 12, 2, Stage2D.GOLD)
	s._text(String(p.get("title", "THE PARTY NOISE TEST")), Vector2(card.get_center().x, 86), 22, Stage2D.INK, 700)
	s._text("six courses, one sentence each", Vector2(card.get_center().x, 110), 14, Palette.INK_SOFT, 600)
	s._pop_xf()
	if open < 0.95:
		return
	for i in courses.size():
		var row: Array = courses[i]
		var y := 138.0 + 44.0 * i
		var rk := _in(1.0 + 0.42 * i, 0.35)
		if rk <= 0.01:
			continue
		s._push(Stage2D._about(Vector2(440, y), 0.0, Vector2.ONE * rk))
		s._text(String(row[0]), Vector2(282, y), 20, Stage2D.INK, 700, 0, Palette.PAPER, 0.0)
		for j in peas:
			s._circ(Vector2(402.0 + 18.0 * j, y), 7.0, PEA, 2.5)
		s._text("SNR %d" % int(row[1]), Vector2(600, y), 20, Palette.CORAL.darkened(0.15), 700, 0, Palette.PAPER, 1.0)
		s._pop_xf()
		# the crowd in the margins: one more tiny diner on each side every course
		for j in i + 1:
			var bob := sin(t * 5.0 + i + j * 1.3) * 2.0 * s._motion
			_head(Vector2(236.0 - 20.0 * j, y + bob), 9.0, DINERS[(i + j) % DINERS.size()], rk)
			_head(Vector2(644.0 + 20.0 * j, y - bob), 9.0, DINERS[(i + j + 1) % DINERS.size()], rk)
	if t > 4.6:
		s._chip("%d key words each" % peas, Vector2(440, 394), PEA.lightened(0.35), 16, Stage2D.INK, _in(4.6, 0.4))
	var ak := _in(5.2, 0.45)
	if ak > 0.01:
		var x := 818.0
		var grow := 1.0 if still else _k(5.2, 5.9)
		s.draw_line(Vector2(x, 140), Vector2(x, 140 + 230 * grow), Palette.CORAL, 6.0, true)
		if grow >= 1.0:
			UiDraw.arrow(s, Vector2(x, 372), 30.0, Vector2.DOWN, Palette.CORAL)
		s._chip("the party grows", Vector2(770, 410), Palette.CORAL.lightened(0.35), 16, Stage2D.INK, ak)
	s._hoot(Vector2(64, 384), 30.0, {"pop": _in(0.4, 0.45), "mood": &"wave" if t < 2.4 else &"idle"})


## A tiny diner's head for the menu's margins.
func _head(c: Vector2, r: float, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	s._circ(c, r * k, col, 2.5)
	for sd: float in [-1.0, 1.0]:
		s.draw_circle(c + Vector2(sd * r * 0.38, -r * 0.1) * k, 1.8 * k, Stage2D.INK, true, -1.0, true)


# ---------------------------------------------------------------- 7. receipt

## A till prints the bill of a diner with typical hearing: his key words per course, the total, the
## SNR loss and its band stamp. Beside it, his last two plates: each missed pea rolls off into a
## "+1 dB" tag. Reduced motion: the receipt prints at once and the peas do not roll.
func _set_receipt() -> void:
	var p: Dictionary = params.get("receipt", {})
	var counts: Array = p.get("counts", [])
	var total := int(p.get("total", 0))
	var loss := float(p.get("loss", 0.0))
	var band := String(p.get("band_name", ""))
	var courses: Array = p.get("courses", [])
	var per := int(p.get("key_words", 5))
	var still := s._motion < 1.0
	# the receipt's lines, top to bottom
	var lines: Array[Array] = [["TYPICAL DINER", "", 0]]
	for i in counts.size():
		lines.append([String(courses[i]) if i < courses.size() else "Course %d" % (i + 1), "%d / %d" % [int(counts[i]), per], 1])
	lines.append(["KEY WORDS RIGHT", str(total), 2])
	lines.append(["SNR LOSS", "%.1f dB" % loss, 2])
	var line_h := 22.0
	var slot_y := 336.0
	var stamp_h := 44.0
	var printed := lines.size() if (still and t >= 1.0) else 0
	if not still:
		for i in lines.size():
			if t >= 1.0 + 0.3 * i:
				printed = i + 1
	# the till
	var till := Rect2(560, slot_y - 4, 220, 96)
	s._rbox(Rect2(till.position + Vector2(0, 6), till.size), Color(Stage2D.INK, 0.2), 16, 0)
	s._rbox(till, Palette.CORAL.lightened(0.2), 16, 4)
	s._rbox(Rect2(till.position + Vector2(18, 22), Vector2(80, 34)), Palette.LCD_BG, 6, 3)
	s._text(str(total) if printed >= lines.size() - 1 else "...", till.position + Vector2(58, 40), 18, Palette.LCD_TEXT, 700)
	for r in 2:
		for c in 4:
			s._rbox(Rect2(till.position + Vector2(112 + 24 * c, 22 + 26 * r), Vector2(18, 18)), Palette.PAPER, 4, 2)
	s._rbox(Rect2(till.position + Vector2(18, 64), Vector2(184, 20)), Palette.WOOD, 6, 3)
	if printed > 0:
		var x0 := 580.0
		var w := 180.0
		# once every line is out, the paper feeds a little more for the stamp
		var feed := 0.0
		if printed >= lines.size():
			feed = stamp_h * (1.0 if still else _k(4.2, 4.6))
		var h := 22.0 + printed * line_h + feed
		var top := slot_y - h
		# the paper, with a zigzag top edge
		var paper := Rect2(x0, top, w, h + 4)
		s.draw_rect(paper, RECEIPT)
		var zig := PackedVector2Array()
		for i in 13:
			zig.append(Vector2(x0 + w * i / 12.0, top + (0.0 if i % 2 == 0 else -6.0)))
		zig.append(Vector2(x0 + w, top + 6))
		zig.append(Vector2(x0, top + 6))
		s.draw_colored_polygon(zig, RECEIPT)
		s.draw_line(Vector2(x0, top), Vector2(x0, slot_y), Stage2D.INK, 3.0, true)
		s.draw_line(Vector2(x0 + w, top), Vector2(x0 + w, slot_y), Stage2D.INK, 3.0, true)
		for i in printed:
			var ln: Array = lines[i]
			var y := top + 20.0 + i * line_h
			var kind := int(ln[2])
			var col := Stage2D.INK if kind != 1 else Palette.INK_SOFT
			var px := 14 if kind == 1 else 15
			if kind == 2 and i == lines.size() - 2:
				s.draw_line(Vector2(x0 + 10, y - 12), Vector2(x0 + w - 10, y - 12), Color(Stage2D.INK, 0.4), 2.0, true)
			if String(ln[1]) == "":
				s._text(String(ln[0]), Vector2(x0 + w * 0.5, y), px, col, 700)
			else:
				s._text(String(ln[0]), Vector2(x0 + 12, y), px, col, 700, 0, Palette.PAPER, 0.0)
				s._text(String(ln[1]), Vector2(x0 + w - 12, y), px, col, 700, 0, Palette.PAPER, 1.0)
		# the band stamp
		var sk := _in(4.8, 0.3)
		if sk > 0.01 and band != "":
			var sc := Vector2(x0 + w * 0.5, top + 20.0 + (lines.size() - 1) * line_h + 32.0)
			s._push(Stage2D._about(sc, -0.12, Vector2.ONE * (1.0 + 0.6 * (1.0 - sk)) if not still else Vector2.ONE))
			s._rbox(Rect2(sc - Vector2(84, 18), Vector2(168, 36)), Color(Palette.MINT, 0.18), 8, 4, Palette.MINT.darkened(0.25))
			s._text(band, sc, 20, Palette.MINT.darkened(0.35), 700)
			s._pop_xf()
	if t > 4.0 and t < 5.2 and not still:
		s._text("ka-ching!", Vector2(500, 380), 22, Palette.CORAL.darkened(0.1), 700, 6, Palette.PAPER, 0.5, _in(4.0, 0.25))
	# his last two plates: the missed peas roll off, each into a "+1 dB" tag
	var plates: Array[Array] = []
	for i in counts.size():
		if int(counts[i]) < per:
			plates.append([String(courses[i]) if i < courses.size() else "", int(counts[i])])
	var tag_no := 0
	for pl in plates.size():
		var row: Array = plates[pl]
		var c := Vector2(170, 170 + 150 * pl)
		var pk := _in(0.4 + 0.3 * pl, 0.4)
		if pk <= 0.01:
			continue
		s._push(Stage2D._about(c, 0.0, Vector2.ONE * pk))
		s._blob(c, Vector2(96, 30), Palette.PAPER, 4.0)
		s._ell(c, Vector2(70, 19), Palette.SKY.lightened(0.5))
		s._pop_xf()
		s._chip(String(row[0]), c + Vector2(0, -50), Palette.PAPER, 15, Stage2D.INK, pk)
		var got := int(row[1])
		for j in per:
			var home := c + Vector2(-48 + 24 * j, -2)
			if j < got:
				s._circ(home, 9.0, PEA, 2.5)
				continue
			var t0 := 2.2 + 0.35 * tag_no
			var roll := 0.0 if still else _k(t0, t0 + 0.6)
			# each tag lands in a row beside its own plate
			var tag_at := Vector2(320 + 60 * (j - got), c.y)
			if still or roll >= 1.0:
				if t >= t0:
					s._chip("+1 dB", tag_at, Palette.CORAL.lightened(0.2), 15, Stage2D.INK, 1.0 if still else _pop(t0 + 0.6, 0.3))
				else:
					s._circ(home, 9.0, PEA, 2.5)
			elif roll > 0.0:
				var pos := home.lerp(tag_at, Stage2D._ease_in_out(roll)) + Vector2(0, -sin(roll * PI) * 40.0)
				s._circ(pos, 9.0, PEA, 2.5)
			else:
				s._circ(home, 9.0, PEA, 2.5)
			tag_no += 1
	if t > 5.6:
		s._chip("Most ears miss 4 or 5 anyway", Vector2(250, 418), Palette.SKY, 16, Stage2D.INK, _in(5.6, 0.4))


# ---------------------------------------------------------------- 8. tonight

## Beeps in a silent booth on the left, the noisy table on the right, a question mark hopping
## between them; two knocks, the door swings open on tonight's guest (a napkin and a raised fork),
## and the curtains close.
func _set_tonight() -> void:
	var p: Dictionary = params.get("tonight", {})
	var still := s._motion < 1.0
	# the audiogram card: beeps, tested in silence
	var ak := _in(0.2, 0.4)
	if ak > 0.01:
		var c := Vector2(160, 236)
		s._push(Stage2D._about(c, -0.04, Vector2.ONE * ak))
		var card := Rect2(c - Vector2(110, 96), Vector2(220, 192))
		s._rbox(Rect2(card.position + Vector2(0, 6), card.size), Color(Stage2D.INK, 0.2), 14, 0)
		s._rbox(card, Palette.PAPER, 14, 4)
		var chart := Rect2(card.position + Vector2(22, 40), Vector2(176, 110))
		s.draw_rect(chart, Color(Palette.SKY, 0.35))
		for i in 6:
			var x := chart.position.x + chart.size.x * i / 5.0
			s.draw_line(Vector2(x, chart.position.y), Vector2(x, chart.end.y), Color(Stage2D.INK, 0.15), 1.5, true)
		for i in 5:
			var y := chart.position.y + chart.size.y * i / 4.0
			s.draw_line(Vector2(chart.position.x, y), Vector2(chart.end.x, y), Color(Stage2D.INK, 0.15), 1.5, true)
		var prev := Vector2.ZERO
		for i in 6:
			var pt := Vector2(chart.position.x + chart.size.x * i / 5.0, chart.position.y + 20.0 + 6.0 * i)
			if i > 0:
				s.draw_line(prev, pt, Palette.RIGHT_RED, 3.0, true)
			prev = pt
		for i in 6:
			var pt := Vector2(chart.position.x + chart.size.x * i / 5.0, chart.position.y + 20.0 + 6.0 * i)
			s.draw_arc(pt, 7.0, 0.0, TAU, 16, Palette.RIGHT_RED, 3.0, true)
		s._text("BEEPS", c + Vector2(0, -74), 20, Stage2D.INK, 700)
		s._text("tested in a silent booth", c + Vector2(0, 78), 14, Palette.INK_SOFT, 700)
		s._pop_xf()
		s._chip("shh", c + Vector2(92, -96), Palette.SKY, 16, Stage2D.INK, ak)
	# the noisy table
	var tk := _in(0.5, 0.4)
	if tk > 0.01:
		var foot := Vector2(724, 396)
		_diner_table(foot, 0.6, 0.5, 2)
		var words: Array[String] = ["haha", "clink!", "more bread?"]
		for i in words.size():
			var wob := sin(t * 2.4 + i) * 3.0 * s._motion
			_chatter(foot + Vector2(-70 + 70 * i, -126 - 26 * (i % 2) + wob), words[i], tk, 0.0)
		s._text("DINNER", foot + Vector2(0, -186), 20, Stage2D.INK, 700, 6, Palette.PAPER, 0.5, tk)
	# the question mark hops between them, twice
	if t > 0.4 and t < 2.6:
		var q := Vector2(440, 96)
		if not still:
			var u := fposmod((t - 0.4) / 1.1, 1.0)
			var leg := int((t - 0.4) / 1.1) % 2
			var a := Vector2(290, 120)
			var b := Vector2(590, 120)
			var from := a if leg == 0 else b
			var to := b if leg == 0 else a
			q = from.lerp(to, u) + Vector2(0, -sin(u * PI) * 60.0)
		s._text("?", q, 56, Palette.CORAL, 700, 9, Palette.PAPER, 0.5, _in(0.4, 0.3))
	# the door at the back: two knocks, then it swings open on tonight's guest
	var door := Rect2(386, 150, 108, 200)
	var dk := _in(0.3, 0.4)
	if dk > 0.01:
		s._push(Stage2D._about(Vector2(440, 350), 0.0, Vector2.ONE * dk))
		s._rbox(door.grow(10), Palette.WOOD.darkened(0.2), 10, 4)
		s.draw_rect(door, Palette.SUNNY.lightened(0.35))
		s.draw_rect(Rect2(door.position + Vector2(0, door.size.y - 30), Vector2(door.size.x, 30)), Palette.SUNNY.darkened(0.05))
		s._pop_xf()
		var open := (1.0 if t >= 3.3 else 0.0) if still else Stage2D._ease_out(_k(3.3, 3.8))
		if open > 0.05:
			_guest(Vector2(440, 278), _in(3.4, 0.45))
		var knock := _ring(2.6, 4.0, 40.0, 9.0) + _ring(2.9, 4.0, 40.0, 9.0)
		var panel_w := door.size.x * (1.0 - 0.82 * open)
		s._push(Stage2D._xform(Vector2(knock, 0)))
		s._rbox(Rect2(door.position, Vector2(panel_w, door.size.y)), Palette.WOOD, 6, 4)
		if panel_w > 40.0:
			s._circ(door.position + Vector2(panel_w - 16, door.size.y * 0.55), 6.0, Palette.SUNNY, 3.0)
			s._rbox(Rect2(door.position + Vector2(14, 18), Vector2(panel_w - 28, 60)), Palette.WOOD.lightened(0.12), 4, 2)
		s._pop_xf()
		for kt: float in [2.6, 2.9]:
			if t >= kt and t < kt + 1.2:
				var a := 1.0 - _k(kt + 0.7, kt + 1.2)
				var kp := Vector2(560, 186 + (kt - 2.6) * 120.0)
				s._text("KNOCK!", kp, 26, Color(Palette.PAPER, a), 700, 8, Color(Stage2D.INK, a), 0.5, _in(kt, 0.25))
		if t > 3.6:
			s._big_sign(String(p.get("sign", "TONIGHT")), Vector2(440, 112), _in(3.6, 0.45), sin(t * 3.0) * 0.03 * s._motion, Palette.SUNNY)
	s._hoot(Vector2(70, 384), 30.0, {"pop": _in(0.6, 0.4), "mood": &"bow" if t > 4.4 else &"idle", "tilt": sin(_k(4.4, 5.4) * PI) * 0.4})
	s._curtains(1.0 - Stage2D._ease_in_out(_k(4.6, 5.4)))
	if t > 5.6:
		s._chip(String(p.get("chip", "Places, trainee: a guest!")), Vector2(440, 300), Palette.PAPER, 22, Stage2D.INK, _in(5.6, 0.4))


## Tonight's guest in the doorway: a dark silhouette with a white napkin tucked in and a fork up.
func _guest(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c + Vector2(0, 70), 0.0, Vector2.ONE * k))
	s._blob(c, Vector2(40, 66), SILHOUETTE, 3.0)
	for sd: float in [-1.0, 1.0]:
		s._ell(c + Vector2(sd * 13.0, -30.0), Vector2(5, 7), Palette.PAPER)
	# the napkin, tucked in under the chin
	var n := c + Vector2(0, -4)
	s.draw_colored_polygon(PackedVector2Array([n + Vector2(-22, 0), n + Vector2(22, 0), n + Vector2(0, 34)]), Palette.PAPER)
	s.draw_polyline(PackedVector2Array([n + Vector2(-22, 0), n + Vector2(22, 0), n + Vector2(0, 34), n + Vector2(-22, 0)]), Stage2D.INK, 3.0, true)
	# the raised fork
	var hand := c + Vector2(30, -42)
	s.draw_line(c + Vector2(30, 6), hand, SILHOUETTE, 10.0, true)
	s.draw_line(hand, hand + Vector2(0, -36), Palette.LCD_DIM.lightened(0.4), 4.0, true)
	for i in 3:
		s.draw_line(hand + Vector2(-7 + 7 * i, -36), hand + Vector2(-7 + 7 * i, -50), Palette.LCD_DIM.lightened(0.4), 3.0, true)
	s.draw_line(hand + Vector2(-7, -36), hand + Vector2(7, -36), Palette.LCD_DIM.lightened(0.4), 3.0, true)
	s._pop_xf()


# ---------------------------------------------------------------- the cafe and its people

## The room: the floor, a night window with the moon, the lamp over the couple's table. k pops it in.
func _room(k: float) -> void:
	if k <= 0.01:
		return
	s.draw_rect(Rect2(0, FLOOR_Y, s.size.x, s.size.y - FLOOR_Y), Color(FLOOR_WOOD, k))
	for i in 9:
		s.draw_line(Vector2(i * 110.0, FLOOR_Y), Vector2(i * 110.0 - 30.0, s.size.y), Color(Palette.WOOD, 0.4 * k), 2.0, true)
	s.draw_line(Vector2(0, FLOOR_Y), Vector2(s.size.x, FLOOR_Y), Color(Stage2D.INK, 0.6 * k), 3.0, true)
	s._push(Stage2D._about(WINDOW.get_center(), 0.0, Vector2.ONE * k))
	s._rbox(WINDOW.grow(8), Palette.WOOD, 8, 4)
	s.draw_rect(WINDOW, NIGHT)
	var moon := WINDOW.position + Vector2(108, 34)
	s.draw_circle(moon, 18.0, Palette.SUNNY, true, -1.0, true)
	s.draw_circle(moon + Vector2(-8, -5), 15.0, NIGHT, true, -1.0, true)
	for i in 3:
		var tw := 4.0 + 1.5 * sin(t * 2.0 + i * 2.1) * s._motion
		UiDraw.star(s, WINDOW.position + Vector2(24 + 30 * i, 26 + 22 * (i % 2) + 30), tw, Palette.PAPER)
	s.draw_line(Vector2(WINDOW.get_center().x, WINDOW.position.y), Vector2(WINDOW.get_center().x, WINDOW.end.y), Palette.WOOD, 5.0, true)
	s.draw_line(Vector2(WINDOW.position.x, WINDOW.get_center().y), Vector2(WINDOW.end.x, WINDOW.get_center().y), Palette.WOOD, 5.0, true)
	s._pop_xf()
	# the lamp, its warm glow on the table
	var swing := sin(t * 1.3) * 0.03 * s._motion
	s._push(Stage2D._about(Vector2(TABLE_AT.x, 0), swing, Vector2.ONE))
	s.draw_colored_polygon(PackedVector2Array([Vector2(404, 104), Vector2(476, 104), Vector2(TABLE_AT.x + 150, TABLE_AT.y - 6), Vector2(TABLE_AT.x - 150, TABLE_AT.y - 6)]), Color(Palette.SUNNY, 0.13 * k))
	s.draw_line(Vector2(TABLE_AT.x, 0), Vector2(TABLE_AT.x, 72), Stage2D.INK, 3.0, true)
	var shade := PackedVector2Array([Vector2(412, 72), Vector2(468, 72), Vector2(488, 104), Vector2(392, 104)])
	s.draw_colored_polygon(shade, Palette.CORAL)
	shade.append(shade[0])
	s.draw_polyline(shade, Stage2D.INK, 3.0, true)
	s.draw_circle(Vector2(TABLE_AT.x, 108), 8.0, Palette.SUNNY, true, -1.0, true)
	s._pop_xf()


## The couple at their table (her on the left, him on the right), each popping in with its k.
func _couple(her_k: float, his_k: float, her_st: Dictionary, his_st: Dictionary) -> void:
	if her_k > 0.01:
		s._push(Stage2D._about(HER_AT + Vector2(0, 70), 0.0, Vector2.ONE * her_k))
		_bean(HER_AT, BEAN_H, HER, her_st)
		s._pop_xf()
	if his_k > 0.01:
		s._push(Stage2D._about(HIM_AT + Vector2(0, 70), 0.0, Vector2.ONE * his_k))
		_bean(HIM_AT, BEAN_H, HIM, his_st)
		s._pop_xf()
	var tk := maxf(her_k, his_k)
	if tk > 0.01:
		s._push(Stage2D._about(TABLE_AT + Vector2(0, 66), 0.0, Vector2.ONE * minf(1.0, tk)))
		_table(TABLE_AT, 250.0)
		for sd: float in [-1.0, 1.0]:
			_tiramisu(TABLE_AT + Vector2(sd * 62.0, -10.0))
		_candle(TABLE_AT + Vector2(0, -12))
		s._pop_xf()


## Her line, big and crisp over her head (two lines).
func _her_bubble(line: String, k: float) -> void:
	if k <= 0.01:
		return
	_speech(HER_BUBBLE, 276.0, 88.0, HER_AT + Vector2(14, -64), Palette.PAPER, Stage2D.INK, k)
	var cut := line.find(" ", int(line.length() * 0.45))
	var a := line.substr(0, cut) if cut > 0 else line
	var b := line.substr(cut + 1) if cut > 0 else ""
	s._text(a, HER_BUBBLE + Vector2(0, -15 if b != "" else 0), 24, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, k)
	if b != "":
		s._text(b, HER_BUBBLE + Vector2(0, 16), 24, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, k)


## A cafe table: its cloth (with a check border), the pedestal and its foot. c: the middle of the top.
func _table(c: Vector2, w: float) -> void:
	s.draw_line(c + Vector2(0, 20), c + Vector2(0, 62), Stage2D.INK, 12.0, true)
	s.draw_line(c + Vector2(0, 20), c + Vector2(0, 62), Palette.WOOD.darkened(0.2), 6.0, true)
	s._blob(c + Vector2(0, 64), Vector2(w * 0.2, 6), Palette.WOOD.darkened(0.2), 3.0)
	var cloth := PackedVector2Array([c + Vector2(-w * 0.5, -8), c + Vector2(w * 0.5, -8), c + Vector2(w * 0.5 + 6, 22), c + Vector2(-w * 0.5 - 6, 22)])
	s.draw_colored_polygon(cloth, CLOTH)
	var n := int(w / 22.0)
	for i in n:
		if i % 2 == 0:
			var x0 := -w * 0.5 - 6.0 + (w + 12.0) * i / n
			var x1 := -w * 0.5 - 6.0 + (w + 12.0) * (i + 1) / n
			s.draw_rect(Rect2(c + Vector2(x0, 12), Vector2(x1 - x0, 10)), CLOTH_CHECK)
	cloth.append(cloth[0])
	s.draw_polyline(cloth, Stage2D.INK, 3.5, true)


func _candle(c: Vector2) -> void:
	s._rbox(Rect2(c + Vector2(-6, -22), Vector2(12, 24)), Palette.PAPER, 3, 2)
	var flick := 1.0 + 0.12 * sin(t * 13.0) * s._motion
	s._blob(c + Vector2(0, -30), Vector2(5, 9 * flick), Palette.SUNNY, 2.0)
	s.draw_circle(c + Vector2(0, -28), 14.0, Color(Palette.SUNNY, 0.18), true, -1.0, true)


func _tiramisu(c: Vector2) -> void:
	s._blob(c + Vector2(0, 4), Vector2(30, 6), Palette.PAPER, 2.5)
	var r := Rect2(c + Vector2(-16, -18), Vector2(32, 20))
	s.draw_rect(r, Color("#f3e3c4"))
	s.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(32, 5)), Color("#9a6a43"))
	s.draw_rect(Rect2(r.position, Vector2(32, 3)), Color("#6e4a2f"))
	s.draw_rect(r, Stage2D.INK, false, 2.0)


## A diner bean (the story's bean people, drawn for the stage). st: look (-1..1), mood (&"idle",
## &"happy", &"puzzled"), mouth (0..1, talking), bow (a hair bow).
func _bean(c: Vector2, h: float, col: Color, st: Dictionary) -> void:
	var look := float(st.get("look", 0.0))
	var mood: StringName = st.get("mood", &"idle")
	var r := Vector2(h * 0.36, h * 0.5)
	var breathe := sin(t * 2.4 + c.x * 0.01) * 0.02 * s._motion
	s._push(Stage2D._about(c + Vector2(0, r.y), 0.0, Vector2(1.0 - breathe, 1.0 + breathe)))
	s._blob(c, r, col, 4.0)
	s._ell(c + Vector2(-r.x * 0.35, -r.y * 0.45), Vector2(r.x * 0.22, r.y * 0.14), Color(Palette.PAPER, 0.5))
	var eyes := c + Vector2(look * r.x * 0.22, -r.y * 0.36)
	var er := h * 0.064
	for sd: float in [-1.0, 1.0]:
		var e := eyes + Vector2(sd * r.x * 0.36, 0)
		s.draw_circle(e, er, Palette.PAPER, true, -1.0, true)
		s.draw_arc(e, er, 0.0, TAU, 16, Stage2D.INK, 3.0, true)
		s.draw_circle(e + Vector2(look * er * 0.33, 1.0), er * 0.47, Stage2D.INK, true, -1.0, true)
		if mood == &"puzzled":
			s.draw_line(e + Vector2(-er, -er * 1.8 - sd * 3.0), e + Vector2(er, -er * 1.8 + sd * 3.0), Stage2D.INK, 3.5, true)
	s._ell(eyes + Vector2(-r.x * 0.55, er * 1.8), Vector2(er * 0.9, er * 0.55), Color(Palette.CORAL, 0.4))
	s._ell(eyes + Vector2(r.x * 0.55, er * 1.8), Vector2(er * 0.9, er * 0.55), Color(Palette.CORAL, 0.4))
	var m := eyes + Vector2(0, er * 2.9)
	var talk := float(st.get("mouth", 0.0))
	if talk > 0.05:
		s._ell(m, Vector2(er * 0.9, er * (0.35 + 0.8 * talk)), Color("#7a2a3a"))
	elif mood == &"puzzled":
		s.draw_polyline(PackedVector2Array([m + Vector2(-er, 1), m + Vector2(-er * 0.33, -2), m + Vector2(er * 0.33, 2), m + Vector2(er, -1)]), Stage2D.INK, 3.0, true)
	elif mood == &"happy":
		s.draw_arc(m + Vector2(0, -er * 0.9), er * 1.25, PI * 0.12, PI * 0.88, 10, Stage2D.INK, 3.0, true)
	else:
		s.draw_arc(m + Vector2(0, -er * 0.66), er, PI * 0.2, PI * 0.8, 8, Stage2D.INK, 3.0, true)
	if bool(st.get("bow", false)):
		var bc := c + Vector2(r.x * 0.3, -r.y * 0.92)
		for sd: float in [-1.0, 1.0]:
			s.draw_colored_polygon(PackedVector2Array([bc, bc + Vector2(sd * 18, -10), bc + Vector2(sd * 18, 10)]), Palette.CORAL)
			s.draw_polyline(PackedVector2Array([bc, bc + Vector2(sd * 18, -10), bc + Vector2(sd * 18, 10), bc]), Stage2D.INK, 3.0, true)
		s._circ(bc, 5.0, Palette.CORAL.darkened(0.1), 3.0)
	s._pop_xf()


## A rounded speech bubble with a tail to the speaker, popping in with k.
func _speech(c: Vector2, w: float, h: float, tail_to: Vector2, bg: Color, border: Color, k: float = 1.0) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	var d := (tail_to - c).normalized()
	var side := Vector2(d.y, -d.x) * 12.0
	var base := c + Vector2(clampf(d.x * w * 0.5, -w * 0.3, w * 0.3), h * 0.4 * signf(d.y))
	s.draw_colored_polygon(PackedVector2Array([base + side, tail_to, base - side]), border)
	var rr := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	s._rbox(Rect2(rr.position + Vector2(0, 5), rr.size), Color(Stage2D.INK, 0.2), int(minf(h, 60.0) * 0.5), 0)
	s._rbox(rr, bg, int(minf(h, 60.0) * 0.5), 4, border)
	var inner := PackedVector2Array([base + side * 0.55, tail_to + (base - tail_to).normalized() * 7.0, base - side * 0.55])
	s.draw_colored_polygon(inner, bg)
	s._pop_xf()


## A grey chatter bubble (the party's talk: drawn, never played).
func _chatter(c: Vector2, text: String, k: float, rot: float = 0.0) -> void:
	if k <= 0.01:
		return
	var f := Stage2D.UiKit.font(700)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 24.0
	c.x = clampf(c.x, w * 0.5 + 10.0, s.size.x - w * 0.5 - 10.0)   # never cut off by the frame
	s._push(Stage2D._about(c, rot, Vector2.ONE * k))
	var rr := Rect2(c - Vector2(w * 0.5, 15), Vector2(w, 30))
	var tip := c + Vector2(-w * 0.25, 26)
	s.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.32, 12), tip, c + Vector2(-w * 0.12, 12)]), CHATTER_INK)
	s._rbox(rr, CHATTER_BG, 15, 3, CHATTER_INK)
	s.draw_colored_polygon(PackedVector2Array([c + Vector2(-w * 0.29, 11), tip + Vector2(1, -5), c + Vector2(-w * 0.15, 11)]), CHATTER_BG)
	s._text(text, c, 16, CHATTER_INK, 700)
	s._pop_xf()


## A mint "got it" tick in a circle.
func _tick(c: Vector2, r: float, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._circ(c, r, Palette.MINT, 3.0)
	UiDraw.check(s, c, r * 1.2, Palette.PAPER, 5.0)
	s._pop_xf()


## A pop-in from t0, or (reduced motion) a cut: there from t0 on, no overshoot.
func _in(t0: float, dur: float = 0.45) -> float:
	if s._motion < 1.0:
		return 1.0 if t >= t0 else 0.0
	return _pop(t0, dur)
