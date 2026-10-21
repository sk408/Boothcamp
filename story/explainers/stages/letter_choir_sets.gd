extends "res://story/explainers/explainer_sets.gd"
## The sets of Hoot's word movie, "The Letter Choir" (story/explainers/movies/letter_choir.gd, Day 4):
## the letter singers on their choir risers, the speech banana on an audiogram (soft at the TOP, as on
## a real chart), the velvet hearing curtain that hangs from the top down to the threshold line, the
## cafe table where words turn to mush, the volume knob that slides the banana down, the masking
## movie's head and Ghost for the crossing, the 25-tile score board and the humming door.
## Numbers are copied in as data: CUES holds SpeechRules.SOUND_CUES positions (story/tests/
## test_movie_letter_choir.gd pins them), the chart maths is the Banana Board's own (log pitch across,
## dB HL down); nothing here calls SpBanana or other Day 4 UI code.
## Same rules as every set: a pure function of t (no tweens, nodes or RNG), sounds only in the movie's
## cues; the loud knob, the loud word and the speech noise are drawn, never played. Reduced motion
## (s._motion < 1): the singers and the curtain fade instead of hopping or dropping, the banana
## crossfades down, the tiles change without flipping, nothing sways.

const SETS: Array[StringName] = [&"choir", &"banana", &"curtain", &"mush", &"louder", &"crossing", &"count", &"tease"]

## The marquee (scene 1): the shape of the stage's own title card and the case movies' _marquee().
const CARD_C := Vector2(440, 226)
const CARD_SIZE := Vector2(640, 290)
const CARD_FILL := Color("#3a2f55")
const PROP_AT := Vector2(-222, 8)
const LINE_SHIFT := 40.0

## The singers on the chart: [frequency of the sound's cue (Hz), dB below the voice] for the sounds the
## movie shows, copied from SpeechRules.SOUND_CUES (the test checks every one). Fourteen of the
## table's sounds, so no two singers overlap on the stage; "vowel" is drawn as a big "o".
const CUES: Dictionary = {
	"m": [500, -15], "n": [500, -15], "l": [750, -12], "vowel": [750, -5],
	"b": [1000, -20], "r": [1000, -12], "d": [1500, -20], "p": [1500, -25],
	"sh": [2000, -15], "k": [2000, -22], "t": [3000, -25],
	"s": [4000, -25], "f": [4000, -32], "th": [4000, -35],
}
## The softest, highest three (they go first behind a high-pitch loss).
const HIGH_SOFT: Array[String] = ["s", "f", "th"]
## The audiogram: 250 Hz to 8 kHz across (log), -10 to 100 dB HL down (soft at the top).
const CHART := Rect2(140, 70, 598, 300)
const F_LO := 250.0
const F_HI := 8000.0
const DB_TOP := -10.0
const DB_BOTTOM := 100.0
## Singers at one frequency stand this far apart, side by side.
const FAN := 26.0
## The "too loud" strip at the bottom of the chart (louder scene), from this level down.
const TOO_LOUD_DB := 95.0

const VOWEL_COL := Color("#ffd23f")
const LOW_COL := Color("#bdebd9")
const MID_COL := Color("#bfe6ff")
const HIGH_COL := Color("#e3d3fb")
const VELVET := Color("#7b4bb0")
const VELVET_DARK := Color("#5c3489")
const HIM := Color("#bfe6ff")
const HER := Color("#ffd9e6")
const TILE_BACK := Color("#fff4d6")
## The choir's music staff (scene 1): five lines, high notes at the top.
const STAFF_X0 := 180.0
const STAFF_X1 := 700.0
const STAFF_TOP := 140.0
const STAFF_GAP := 12.0


# ---------------------------------------------------------------- 1. choir (the lead-in)

## The marquee holds while Hoot asks the question and names the answer (params.card_hold, the two
## params.questions chips), then the word SOFT steps forward as four singers on the choir risers and
## they sing in turn. The choir runs on the stage's clock shifted by card_hold - 2 s, the way the
## stage's _set_meet() does it (s.t, not this script's copy: every helper reads the stage's t).
func _set_choir() -> void:
	var p: Dictionary = params.get("choir", {})
	var hold := float(params.get("card_hold", 2.0))
	var real_t := s.t
	var card_out := _k(hold, hold + 0.45)
	if card_out < 1.0:
		_marquee(String(p.get("title", scene_title)), String(p.get("starring", "")), card_out)
	s.t = real_t - (hold - 2.0)
	t = s.t
	_choir(p)
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
	# "The Letter" over "Choir": the last word on its own line, like the masking movie's card
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


## A big "o" and a little "s" singing on the card.
func _marquee_prop(at: Vector2) -> void:
	var bob := sin(t * 3.0) * 3.0 * s._motion
	_singer(at + Vector2(-26, 10 + bob), "o", 30.0, VOWEL_COL, {"sing": 0.6 + 0.4 * absf(sin(t * 2.0))})
	_singer(at + Vector2(34, 22 - bob), "s", 17.0, HIGH_COL, {"sing": 0.3})
	_note_a(at + Vector2(-58, -36 + bob), 1.0, Palette.CORAL, 1.0, -0.2)
	_note_a(at + Vector2(52, -22 - bob), 0.5, Palette.LEFT_BLUE, 1.0, 0.2)


## The choir: risers, the word's letter tiles, a music staff, four singers popping in and singing in
## turn (each puts its note on the staff: the vowel's big and LOW, a consonant's tiny and HIGH), then
## all together.
func _choir(p: Dictionary) -> void:
	var still := s._motion < 1.0
	var word := String(p.get("word", "SOFT"))
	var singers: Array = p.get("singers", [])
	var n := singers.size()
	var xs: Array[float] = []
	for i in n:
		xs.append(STAFF_X0 + 40.0 + ((STAFF_X1 - STAFF_X0 - 80.0) / maxf(1.0, n - 1.0)) * i)
	# the risers
	var rk := _pop(2.2, 0.4)
	if rk > 0.01:
		s._push(Stage2D._about(Vector2(440, 360), 0.0, Vector2(1.0, rk)))
		s._rbox(Rect2(160, 336, 560, 26), Palette.WOOD, 8, 4)
		s._rbox(Rect2(136, 360, 608, 26), Palette.WOOD.darkened(0.12), 8, 4)
		for x: float in [220.0, 330.0, 440.0, 550.0, 660.0]:
			s.draw_line(Vector2(x, 342), Vector2(x, 356), Color(Stage2D.INK, 0.25), 3.0, true)
		s._pop_xf()
	# the staff: high notes sit at the top, low ones at the bottom
	var sk := _k(2.3, 2.8)
	if sk > 0.0:
		for j in 5:
			var y := STAFF_TOP + j * STAFF_GAP
			s.draw_line(Vector2(STAFF_X0, y), Vector2(lerpf(STAFF_X0, STAFF_X1, sk), y), Color(Stage2D.INK, 0.35), 2.0, true)
		s._text("high", Vector2(STAFF_X0 - 30, STAFF_TOP), 14, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, sk)
		s._text("low", Vector2(STAFF_X0 - 30, STAFF_TOP + 4.0 * STAFF_GAP), 14, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.5, sk)
	# who sings when: each in turn, left to right, then everyone together
	var sing_at: Array[float] = [4.6, 5.3, 6.1, 6.7]
	var sing_len: Array[float] = [0.7, 0.8, 0.6, 0.6]
	var all_at := 7.5
	for i in n:
		var pair: Array = singers[i]
		var label := String(pair[0])
		var key := String(pair[1])
		var vowel := key == "vowel"
		var r := 50.0 if vowel else 30.0
		var t0 := 2.6 + 0.5 * i
		var x := xs[i]
		var base := Vector2(x, 336.0 - r)
		var in_k := _k(t0, t0 + 0.45) if still else _pop(t0, 0.45)
		if in_k <= 0.01:
			continue
		var sing := 0.0
		var i_sing := i < sing_at.size() and t >= sing_at[i] and t < sing_at[i] + sing_len[i]
		if i_sing or t >= all_at:
			sing = 0.6 + 0.4 * absf(sin(t * (5.0 if vowel else 9.0)))
		var hop := 0.0 if still else -absf(sin(t * 6.0)) * 6.0 * sing
		var a := in_k if still else 1.0
		var scale := 1.0 if still else in_k
		s._push(Stage2D._about(base + Vector2(0, r), 0.0, Vector2.ONE * scale))
		_singer(base + Vector2(0, hop), label, r, VOWEL_COL if vowel else HIGH_COL, {"sing": sing, "alpha": a})
		s._pop_xf()
		if sing > 0.0:
			var voice := "ooo!" if vowel else label + label + label
			if vowel:
				s._text(voice, base + Vector2(r + 12, -r + 6), 28, Stage2D.INK, 700, 6, Palette.PAPER)
			else:
				s._text(voice, base + Vector2(r + 14, -r + 6), 14, Color(Stage2D.INK, 0.6), 700, 5, Palette.PAPER)
		# its note on the staff: once sung it stays (vowel big and low, consonant tiny and high)
		var first := sing_at[i] if i < sing_at.size() else all_at
		var nk := _k(first, first + 0.25) if still else _pop(first, 0.35)
		if nk > 0.01:
			var cue: Array = CUES.get(key, [1000, -20])
			var hi := clampf((float(cue[0]) - 750.0) / 3250.0, 0.0, 1.0)
			var ny := STAFF_TOP + 4.0 * STAFF_GAP * (1.0 - hi)
			var wob := sin(t * 8.0) * 0.12 * sing * s._motion
			_note_a(Vector2(x - 8.0, ny), (1.55 if vowel else 0.6) * (nk if not still else 1.0), Palette.CORAL if vowel else Palette.LEFT_BLUE, nk if still else 1.0, wob)
		# the word's letter tile above, lit while its singer sings
		var tk := _pop(t0 + 0.1, 0.4)
		if tk > 0.01:
			var tc := Vector2(x, 92)
			s._push(Stage2D._about(tc, 0.0, Vector2.ONE * tk * (1.0 + 0.12 * sing)))
			var lit := sing > 0.0
			s._rbox(Rect2(tc - Vector2(26, 26), Vector2(52, 52)), Palette.SUNNY if lit else Palette.PAPER, 12, 4)
			var ch := word.substr(i, 1) if i < word.length() else label.to_upper()
			s._text(ch, tc, 34, Stage2D.INK, 700)
			s._pop_xf()
	if t > sing_at[0] + 0.9:
		s._chip("vowels: low and LOUD", Vector2(300, 408), VOWEL_COL, 18, Stage2D.INK, _pop(sing_at[0] + 0.9))
	if t > sing_at[2] + 0.4:
		s._chip("consonants: high and soft", Vector2(600, 408), HIGH_COL, 18, Stage2D.INK, _pop(sing_at[2] + 0.4))
	s._hoot(Vector2(80, 372), 36.0, {"pop": _pop(2.4), "mood": &"wave" if t > 4.4 else &"idle"})


# ---------------------------------------------------------------- 2. banana

## The singers hop up to their spots on the chart in three groups (low, middle, high pitches) and a
## yellow banana draws itself around them.
func _set_banana() -> void:
	var dial := float((params.get("banana", {}) as Dictionary).get("dial", 50))
	var still := s._motion < 1.0
	_chart(Stage2D._ease_out(_k(0.0, 0.6)))
	var outline := Stage2D._ease_in_out(_k(3.8, 5.0))
	_banana(dial, outline, _k(4.6, 5.2), 1.0)
	var i := 0
	for key: String in CUES:
		var t0 := 1.0 + float(_group(key)) + 0.07 * (i % 6)
		var home := _spot(key, dial)
		var k := _k(t0, t0 + 0.5)
		i += 1
		if k <= 0.0:
			continue
		if still:
			_chart_singer(key, home, {"alpha": k})
			continue
		var from := Vector2(home.x, CHART.end.y + 50.0)
		var e := Stage2D._ease_out(k)
		var pos := from.lerp(home, e) + Vector2(0, -sin(k * PI) * 46.0)
		_chart_singer(key, pos, {"squash": _ring(t0 + 0.5, 0.25, 18.0, 6.0)})
	if t > 5.0:
		s._sparkles(Vector2(520, 326), 5.0, 12, 120.0, Palette.SUNNY)
		s._big_sign("THE SPEECH BANANA!", Vector2(520, 326), _pop(5.0, 0.45), sin(t * 3.0) * 0.03 * s._motion, Palette.SUNNY)
	var vk := _pop(5.7)
	if vk > 0.01:
		var v := _spot("vowel", dial)
		s._dashed_curve(Vector2(250, 262), Vector2(280, 240), v + Vector2(-8, 16), Palette.INK_SOFT, _k(5.7, 6.1))
		s._chip("vowels: low and LOUD", Vector2(230, 276), VOWEL_COL, 17, Stage2D.INK, vk)
	var hk := _pop(6.3)
	if hk > 0.01:
		var hs := _spot("f", dial)
		s._dashed_curve(Vector2(560, 102), Vector2(590, 96), hs + Vector2(-6, -16), Palette.INK_SOFT, _k(6.3, 6.7))
		s._chip("s, f, th: high and soft", Vector2(470, 102), HIGH_COL, 17, Stage2D.INK, hk)


# ---------------------------------------------------------------- 3. curtain

## A made-up high-pitch loss draws its line across the chart; a velvet curtain drops from the top of
## the chart down to the line and hides every singer above it (s, f and th first: their tiny feet
## show under the hem). Reduced motion: the curtain fades in.
func _set_curtain() -> void:
	var p: Dictionary = params.get("curtain", {})
	var th: Dictionary = p.get("thresholds", {})
	var dial := float(p.get("dial", 50))
	var still := s._motion < 1.0
	_chart(1.0)
	_banana(dial, 1.0, 1.0, 1.0)
	for key: String in CUES:
		_chart_singer(key, _spot(key, dial), {"sing": 0.5 + 0.5 * absf(sin(t * 5.0 + _spot(key, dial).x * 0.03)) if t > 3.0 and not _hidden(key, dial, th) else 0.0})
	var drop := Stage2D._ease_in_out(_k(1.0, 2.6))
	var land := _ring(2.6, 5.0, 16.0, 6.0) if not still else 0.0
	var line := _line_points(th)
	if still:
		_curtain(line, 1.0, _k(1.0, 2.6), 0.0)
	else:
		_curtain(line, drop, 1.0, land)
	if drop >= 1.0 or still:
		_feet(line, dial, th, _k(2.6, 3.0))
	_threshold_line(line, _k(0.3, 0.9))
	if line.size() >= 2:
		s._chip("her hearing line", line[line.size() - 1] + Vector2(-50, 30), Palette.PAPER, 15, Palette.RIGHT_RED.darkened(0.2), _pop(1.0))
	if t > 3.4:
		s._chip("s, f, th: hidden!", Vector2(600, 104), Palette.PAPER, 18, VELVET_DARK, _pop(3.4))
	if t > 4.4:
		var v := _spot("vowel", dial)
		s._chip("vowels still sing", v + Vector2(-60, 62), VOWEL_COL, 17, Stage2D.INK, _pop(4.4))


# ---------------------------------------------------------------- 4. mush

## Two beans at a cafe table. His words fly to her ear, the consonants dropping off on the way, and
## arrive with dotted gaps; she guesses, and a question mark bounces.
func _set_mush() -> void:
	var p: Dictionary = params.get("mush", {})
	var said := String(p.get("said", "Let's meet at six!"))
	var heard := String(p.get("heard", said))
	var reply := String(p.get("reply", "...?"))
	var still := s._motion < 1.0
	var him := Vector2(220, 316)
	var her := Vector2(660, 316)
	# the table, two cups
	s._rbox(Rect2(300, 330, 280, 20), Palette.WOOD, 8, 4)
	s.draw_line(Vector2(330, 350), Vector2(320, 410), Stage2D.INK, 9.0, true)
	s.draw_line(Vector2(330, 350), Vector2(320, 410), Palette.WOOD, 4.0, true)
	s.draw_line(Vector2(550, 350), Vector2(560, 410), Stage2D.INK, 9.0, true)
	s.draw_line(Vector2(550, 350), Vector2(560, 410), Palette.WOOD, 4.0, true)
	for cx: float in [372.0, 508.0]:
		s._rbox(Rect2(cx - 14, 304, 28, 26), Palette.PAPER, 6, 3)
		s.draw_arc(Vector2(cx + 16, 316), 7.0, -PI * 0.5, PI * 0.5, 8, Stage2D.INK, 3.0, true)
	var talk := t > 0.6 and t < 1.6
	var puzzled := t > 3.0
	_bean(him, 130.0, HIM, {"mouth": absf(sin(t * 12.0)) if talk else 0.0, "look": 1.0})
	_bean(her, 130.0, HER, {"look": -1.0, "mood": &"puzzled" if puzzled else &"idle", "ear": true, "bow": true})
	# his bubble: what he said
	var sk := _pop(0.8, 0.4)
	if sk > 0.01:
		_bubble(Vector2(250, 120), 300.0, 64.0, him + Vector2(10, -70), sk, Palette.PAPER)
		s._text(said, Vector2(250, 120), 26, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, sk)
		s._chip("what he says", Vector2(250, 76), HIM, 14, Stage2D.INK, sk)
	# the trip to her ear: consonants fall off on the way
	var fly := _k(1.6, 2.8)
	var ear := her + Vector2(-44, -64)
	if fly > 0.0 and fly < 1.0:
		var from := Vector2(450, 186)
		var pos := from.lerp(ear + Vector2(-40, -40), Stage2D._ease_in_out(fly)) + Vector2(0, -sin(fly * PI) * (0.0 if still else 40.0))
		s._rbox(Rect2(pos - Vector2(100, 20), Vector2(200, 40)), Color(Palette.PAPER, 0.92), 20, 3)
		var swap := clampf((fly - 0.3) * 5.0, 0.0, 1.0)
		if swap < 1.0:
			s._text(said, pos, 18, Color(Stage2D.INK, 1.0 - swap), 700)
		if swap > 0.0:
			_gappy(heard, pos, 18, swap)
		# the lost consonants tumble off below it
		if not still:
			var lost := _lost_letters(said, heard)
			for li in lost.size():
				var dk := clampf((fly - 0.3) * 1.9 - li * 0.06, 0.0, 1.0)
				var dp := pos + Vector2(-60.0 + li * 24.0, 26.0 + 90.0 * dk * dk)
				s._text(lost[li], dp, 17, Color(Palette.CORAL.darkened(0.2), sin(dk * PI)), 700, 4, Palette.PAPER)
	# what reaches her
	var hk := _pop(2.8, 0.4)
	if hk > 0.01:
		_bubble(Vector2(640, 120), 300.0, 64.0, ear + Vector2(-6, -8), hk, Palette.PAPER)
		_gappy(heard, Vector2(640, 120), 26, 1.0, hk)
		s._chip("what reaches her", Vector2(640, 76), HER, 14, Stage2D.INK, hk)
	# her guess, and the bouncing question mark
	var rk := _pop(3.4, 0.4)
	if rk > 0.01:
		_bubble(Vector2(640, 214), 250.0, 50.0, her + Vector2(-30, -60), rk, HER.lightened(0.4))
		s._text(reply, Vector2(640, 214), 22, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, rk)
		var bounce := 0.0 if still else absf(sin((t - 3.4) * 4.0)) * 16.0
		s._text("?", Vector2(792, 210 - bounce), 46, Palette.CORAL, 700, 8, Palette.PAPER, 0.5, rk)
	if t > 4.8:
		s._chip("voices, not words", Vector2(440, 266), Palette.SKY, 24, Stage2D.INK, _pop(4.8, 0.45), sin(t * 3.0) * 0.03 * s._motion)


# ---------------------------------------------------------------- 5. louder

## Hoot turns the volume knob: the whole banana slides DOWN the chart (louder), out from under the
## curtain; most singers step out and bow, f and th still hide. Reduced motion: it crossfades.
func _set_louder() -> void:
	var p: Dictionary = params.get("louder", {})
	var th: Dictionary = p.get("thresholds", {})
	var d0 := float(p.get("from_dial", 50))
	var d1 := float(p.get("to_dial", 85))
	var still := s._motion < 1.0
	var slide := Stage2D._ease_in_out(_k(0.9, 2.6))
	var dial := lerpf(d0, d1, slide)
	_chart(1.0)
	# the "too loud" strip stays empty: never uncomfortable
	var tl := Rect2(CHART.position.x, _fy(TOO_LOUD_DB), CHART.size.x, CHART.end.y - _fy(TOO_LOUD_DB))
	s.draw_rect(tl, Color(Palette.CORAL, 0.28))
	var hx := tl.position.x + 6.0
	while hx < tl.end.x - 6.0:
		s.draw_line(Vector2(hx, tl.end.y - 1), Vector2(hx + 10, tl.position.y + 1), Color(Palette.CORAL.darkened(0.2), 0.5), 2.0, true)
		hx += 14.0
	s._text("too loud: never down here", Vector2(tl.end.x - 8, tl.get_center().y), 11, Palette.CORAL.darkened(0.45), 700, 4, Palette.PAPER, 1.0)
	var line := _line_points(th)
	var bow := sin(_k(3.4, 4.4) * PI)
	if still:
		var cross := _k(0.9, 2.6)
		_banana(d0, 1.0, 1.0, 1.0 - cross)
		_banana(d1, 1.0, 1.0, cross)
		for key: String in CUES:
			_chart_singer(key, _spot(key, d0), {"alpha": 1.0 - cross})
			_chart_singer(key, _spot(key, d1), {"alpha": cross, "tilt": bow * 0.3 if not _hidden(key, d1, th) else 0.0})
		dial = d1 if cross >= 0.5 else d0
	else:
		_banana(dial, 1.0, 1.0, 1.0)
		for key: String in CUES:
			var out := not _hidden(key, dial, th)
			var sq := _ring(_out_time(key, d0, d1, th), 0.3, 18.0, 6.0) if out else 0.0
			_chart_singer(key, _spot(key, dial), {"squash": sq, "tilt": bow * 0.3 if out else 0.0, "sing": 0.4 if out and t > 2.8 else 0.0})
	_curtain(line, 1.0, 1.0, 0.0)
	_feet(line, dial, th, 1.0)
	_threshold_line(line, 1.0)
	# the knob and Hoot
	var knob := Vector2(818, 156)
	var turn := lerpf(-0.9, 0.9, slide)
	_knob(knob, 40.0, turn, _ring(0.8, 0.08, 20.0, 6.0) + _ring(1.4, 0.08, 20.0, 6.0) + _ring(2.0, 0.08, 20.0, 6.0))
	s._chip("+%d dB" % int(round(d1 - d0)), knob + Vector2(0, 76), Palette.SUNNY, 18, Stage2D.INK, _pop(2.6))
	s._hoot(Vector2(818, 352), 34.0, {"mood": &"cheer" if t > 3.4 else &"wave", "squash": _ring(3.4, 0.2, 18.0, 5.0)})
	# the dial line marks the voice's level as it slides
	var dy := _fy(dial)
	s.draw_dashed_line(Vector2(CHART.position.x, dy), Vector2(CHART.end.x, dy), Color(Palette.SELECT_ORANGE, 0.8), 2.0, 8.0)
	s._text("the voice", Vector2(CHART.end.x - 6, dy - 10), 12, Palette.SELECT_ORANGE.darkened(0.35), 700, 4, Palette.PAPER, 1.0)
	if t > 3.6:
		s._sparkles(Vector2(330, 290), 3.4, 12, 120.0, Palette.SUNNY)
		s._chip("most singers step out!", Vector2(330, 104), Palette.MINT, 19, Stage2D.INK, _pop(3.6))
	if t > 4.6:
		s._chip("f, th: still hiding", Vector2(620, 160), Palette.PAPER, 17, VELVET_DARK, _pop(4.6))


## When a singer comes out from under the curtain as the voice slides from d0 to d1 (for its little
## jump); a time far back when it was never behind it.
func _out_time(key: String, d0: float, d1: float, th: Dictionary) -> float:
	if not _hidden(key, d0, th):
		return -10.0
	for i in 41:
		var tt := 0.9 + i * (1.7 / 40.0)
		var dd := lerpf(d0, d1, Stage2D._ease_in_out(clampf((tt - 0.9) / 1.7, 0.0, 1.0)))
		if not _hidden(key, dd, th):
			return tt
	return -10.0


# ---------------------------------------------------------------- 6. crossing

## The masking movie's head: a loud word goes into Lefty's side (the test ear, the poorer one today);
## a smaller copy squeezes through the skull wall to Righty, who throws on the Ghost's sheet. Speech
## noise in her right phone fills Righty's corner; the next crossing word bonks off it and the sheet
## slides off. Visual only: no noise plays.
func _set_crossing() -> void:
	var p: Dictionary = params.get("crossing", {})
	var ia := int(p.get("ia", 40))
	var level := int(p.get("level", 80))
	var word := String(p.get("word", "word!"))
	var still := s._motion < 1.0
	var mouth := Stage2D.CUP_L_AT + Vector2(-46, -4)
	var wall_out := Vector2(Stage2D.WALL_X + Stage2D.WALL_W * 0.5 + 16.0, Stage2D.SQUEEZE_Y)
	var cloud_c := Vector2(2.0 * Stage2D.WALL_X - Stage2D.CLOUD_AT.x, Stage2D.CLOUD_AT.y)
	var ghost_home := Stage2D.RIGHTY_AT + Vector2(0, -44)
	var sheet_on := t >= 3.0 and t < 6.4
	var sheet_off := _k(5.8, 6.4)
	var noise_k := Stage2D._back(_k(4.4, 5.0))
	var busy := t >= 5.8
	s._head_open(0.0)
	s._head({"look": Vector2(0.7 if t < 2.0 else -0.7, 0.1), "mood": &"wow" if t > 3.2 and t < 5.6 else &"smile"})
	s._wall(1.0, 1.0, false)
	if noise_k > 0.01:
		s._cloud(cloud_c, 88.0 * noise_k, {"patchy": 0.0})
	var r_hit := t >= 2.8 and t < 3.0
	if not sheet_on or sheet_off > 0.0:
		var dance := Vector2(sin(t * 7.0) * 6.0, -absf(sin(t * 7.0)) * 6.0) * s._motion if busy else Vector2.ZERO
		s._snail(Stage2D.RIGHTY_AT, 1.0, Palette.RIGHT_RED, Stage2D.RIGHTY_BODY, {"mood": &"happy" if busy else (&"alert" if r_hit else &"idle"),
			"shades": _k(6.0, 6.4), "off": dance, "look": Vector2(1, -0.2)})
	var l_hit := t >= 1.8 and t < 2.6
	s._snail(Stage2D.LEFTY_AT, -1.0, Palette.LEFT_BLUE, Stage2D.LEFTY_BODY, {"mood": &"alert" if l_hit or t > 6.4 else &"idle", "cap": 1.0 - _k(6.4, 6.7),
		"arm": _k(6.5, 6.8), "look": Vector2(1, -0.3)})
	s._cup(Stage2D.CUP_L_AT, Palette.LEFT_BLUE, "L", _pop(0.4), 1.0)
	s._cup(Stage2D.CUP_R_AT, Palette.RIGHT_RED, "R", _pop(4.0), -1.0)
	s._head_close()
	if noise_k > 0.5:
		s._shhh_letters(cloud_c, 88.0)
		s._chip("SPEECH NOISE", cloud_c + Vector2(0, -104), Stage2D.NOISE, 16, Palette.PAPER, _pop(4.6))
	s._toll_sign(Stage2D.SIGN_AT, ["-%d dB" % ia, "on-ear phones: at least"], _pop(0.2, 0.4), 0.0, Palette.PAPER)
	# the loud word: from beside the cup into Lefty's ear
	var w_in := _k(1.0, 1.8)
	if t >= 1.0 and w_in < 1.0:
		var wp := (Stage2D.CUP_L_AT + Vector2(40, -150)).lerp(mouth, Stage2D._ease_in_out(w_in))
		_word_bubble(wp, word, 1.0, "%d dB" % level)
	if t > 0.6 and t < 1.0:
		_word_bubble(Stage2D.CUP_L_AT + Vector2(40, -150), word, _pop(0.6, 0.3), "%d dB" % level)
	# a smaller copy crosses the skull: through the wall, 40 dB smaller, to Righty
	var w_x := _k(1.8, 2.8)
	if t >= 1.8 and w_x < 1.0:
		var xp := wall_out.lerp(ghost_home + Vector2(30, -10), Stage2D._ease_in_out(w_x)) + Vector2(0, -sin(w_x * PI) * (0.0 if still else 26.0))
		var thin := 1.0 - 0.45 * sin(_k(1.8, 2.3) * PI)
		s._push(Stage2D._about(xp, 0.0, Vector2(thin, 2.0 - thin)))
		_word_bubble(xp, word, 0.7, "%d" % (level - ia))
		s._pop_xf()
	if t >= 2.0 and t < 4.2:
		s._chip("%d - %d = %d" % [level, ia, level - ia], Vector2(Stage2D.WALL_X, Stage2D.SQUEEZE_Y + 56), Palette.SUNNY, 20, Stage2D.INK, _pop(2.0, 0.3))
	# the Ghost: Righty under the sheet, waving "I HEARD IT!"
	if sheet_on:
		var gp := ghost_home + Vector2(18.0 * sheet_off, 40.0 * sheet_off * sheet_off + sin(t * 3.0) * 4.0 * s._motion * (1.0 - sheet_off))
		_red_ghost(gp, 46.0, {"flag": _k(3.2, 3.5) * (1.0 - _k(4.4, 4.7)), "alpha": 1.0 - sheet_off, "squash": _ring(3.0, 0.25, 16.0, 5.0), "boo": t > 3.2 and t < 5.6})
		if t > 3.2 and t < 4.4:
			s._sparkles(ghost_home + Vector2(90, -90), 3.2, 10, 70.0, Palette.SUNNY)
	# the next crossing word bonks off the noise
	var w2 := _k(5.0, 5.6)
	if t >= 5.0 and w2 < 1.0:
		var bp := wall_out.lerp(cloud_c + Vector2(70, 0), w2)
		_word_bubble(bp, word, 0.7, "%d" % (level - ia))
	s._bonk(cloud_c + Vector2(64, -6), 5.6, Vector2(Stage2D.WALL_X - 60, Stage2D.SQUEEZE_Y + 52))
	s._chip("TEST EAR", Stage2D.LEFTY_AT + Vector2(6, 48), Palette.LEFT_BLUE, 16, Palette.PAPER, _pop(0.8))
	s._chip("good ear" if t < 4.6 else "good ear: speech noise", Stage2D.RIGHTY_AT + Vector2(-4, 48), Palette.RIGHT_TINT if t < 4.6 else Stage2D.NOISE,
		16, Stage2D.INK if t < 4.6 else Palette.PAPER, _pop(0.8))
	if t > 6.6:
		s._chip("only the TEST ear answers now", Stage2D.CALLOUT_AT, Palette.LEFT_TINT, 18, Stage2D.INK, _pop(6.6))
	elif t > 3.3 and t < 5.6:
		s._chip("the GOOD ear answered!", Stage2D.CALLOUT_AT, Palette.SUNNY, 18, Stage2D.INK, _pop(3.3) * (1.0 - _k(5.4, 5.6)))


# ---------------------------------------------------------------- 7. count

## 25 tiles flip one by one, ticks and crosses; "sock" came back as "lock", a rhyme, so a miss; the
## ticks add up to the score. Reduced motion: the tiles change without flipping.
func _set_count() -> void:
	var p: Dictionary = params.get("count", {})
	var n := int(p.get("tiles", 25))
	var misses: Array = p.get("misses", [])
	var example: Array = p.get("example", ["sock", "lock"])
	var right := int(p.get("right", n - misses.size()))
	var still := s._motion < 1.0
	var cols := 5
	var tile := 56.0
	var gap := 8.0
	var origin := Vector2(96, 78)
	var step := 3.84 / maxf(1.0, n - 1.0)
	var ok_so_far := 0
	var flipped := 0
	for i in n:
		var c := origin + Vector2((i % cols) * (tile + gap), (i / cols) * (tile + gap)) + Vector2(tile, tile) * 0.5
		var t0 := 1.0 + step * i
		var fk := _k(t0, t0 + 0.14)
		var miss := misses.has(i)
		var face_up := fk >= 0.5
		var sx := 1.0 if still else absf(cos(fk * PI))
		s._push(Stage2D._about(c, 0.0, Vector2(maxf(0.04, sx), 1.0)))
		var rr := Rect2(c - Vector2(tile, tile) * 0.5, Vector2(tile, tile))
		s._rbox(Rect2(rr.position + Vector2(0, 4), rr.size), Color(Stage2D.INK, 0.2), 10, 0)
		if not face_up:
			s._rbox(rr, TILE_BACK, 10, 3)
			s._text("?", c, 24, Palette.INK_SOFT, 700)
		elif miss:
			s._rbox(rr, Palette.CORAL, 10, 3)
			UiDraw.cross(s, c + Vector2(0, -4), 15.0, Palette.PAPER, 5.0)
		else:
			s._rbox(rr, Palette.MINT, 10, 3)
			UiDraw.check(s, c + Vector2(0, -4), 17.0, Palette.PAPER, 5.0)
		if face_up and miss and i == int(misses[0]) and example.size() > 1:
			s._text(String(example[1]), c + Vector2(0, 18), 13, Palette.PAPER, 700)
		s._pop_xf()
		if face_up:
			flipped += 1
			if not miss:
				ok_so_far += 1
	# the example: sock came back as lock
	var first_miss := int(misses[0]) if not misses.is_empty() else 0
	var mc := origin + Vector2((first_miss % cols) * (tile + gap), (first_miss / cols) * (tile + gap)) + Vector2(tile, tile) * 0.5
	var ck := _pop(1.6, 0.4)
	if ck > 0.01:
		s._dashed_curve(mc + Vector2(0, -30), Vector2(410, 20), Vector2(450, 120), Palette.INK_SOFT, _k(1.6, 2.0))
		var cc := Vector2(640, 146)
		s._push(Stage2D._about(cc, -0.02, Vector2.ONE * ck))
		s._rbox(Rect2(cc - Vector2(190, 62) + Vector2(0, 5), Vector2(380, 124)), Color(Stage2D.INK, 0.2), 14, 0)
		s._rbox(Rect2(cc - Vector2(190, 62), Vector2(380, 124)), Palette.PAPER, 14, 3)
		s._text("Hoot said:", cc + Vector2(-172, -30), 17, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.0)
		s._text(String(example[0]), cc + Vector2(-78, -30), 26, Stage2D.INK, 700, 0, Palette.PAPER, 0.0)
		s._text("she said:", cc + Vector2(-172, 18), 17, Palette.INK_SOFT, 700, 0, Palette.PAPER, 0.0)
		s._text(String(example[1]) if example.size() > 1 else "?", cc + Vector2(-78, 18), 26, Palette.CORAL.darkened(0.25), 700, 0, Palette.PAPER, 0.0)
		s._pop_xf()
		# the stamp lands
		var stk := _k(2.4, 2.6)
		if stk > 0.0:
			var sc := cc + Vector2(96, 0)
			var big := 1.0 if still else lerpf(1.6, 1.0, Stage2D._ease_out(stk))
			s._push(Stage2D._about(sc, -0.16, Vector2.ONE * big))
			var a := minf(1.0, stk * 2.0)
			s._rbox(Rect2(sc - Vector2(80, 30), Vector2(160, 60)), Color(Palette.CORAL, 0.15 * a), 10, 4, Color(Palette.CORAL.darkened(0.15), a))
			s._text("A RHYME", sc + Vector2(0, -12), 19, Color(Palette.CORAL.darkened(0.2), a), 700)
			s._text("IS A MISS", sc + Vector2(0, 12), 19, Color(Palette.CORAL.darkened(0.2), a), 700)
			s._pop_xf()
	s._chip("each word: %d%%" % int(round(100.0 / maxf(1.0, n))), Vector2(650, 250), Palette.SKY, 19, Stage2D.INK, _pop(3.0))
	# the running count, then the score
	if t < 5.6:
		s._chip("clear so far: %d" % ok_so_far, Vector2(650, 314), Palette.PAPER, 18, Stage2D.INK, _pop(1.0) if flipped > 0 else 0.0)
	else:
		var score := "%d of %d = %d%%" % [right, n, int(round(100.0 * right / maxf(1.0, n)))]
		s._sparkles(Vector2(650, 330), 5.6, 14, 140.0, Palette.SUNNY)
		s._big_sign(score, Vector2(650, 330), _pop(5.6, 0.45), sin(t * 3.0) * 0.03 * s._motion, Palette.MINT)
	s._hoot(Vector2(820, 384), 30.0, {"pop": _pop(0.4), "mood": &"cheer" if t > 5.6 else &"idle"})


# ---------------------------------------------------------------- 8. tease

## The knob turns again and a question mark pops on it; the stage door opens a crack and a hum floats
## in as notes on a staff; Hoot perks up; the curtains close.
func _set_tease() -> void:
	var notes := int((params.get("tease", {}) as Dictionary).get("notes", 3))
	var still := s._motion < 1.0
	var knob := Vector2(330, 214)
	var turn := lerpf(0.4, 1.3, Stage2D._ease_out(_k(0.6, 1.0)))
	_knob(knob, 76.0, turn, _ring(0.6, 0.1, 20.0, 6.0))
	var qk := _pop(1.2, 0.5)
	if qk > 0.01:
		s._text("?", knob + Vector2(0, -16), 84, Palette.CORAL, 700, 12, Palette.PAPER, 0.5, qk)
	s._chip("louder... but clearer?", knob + Vector2(0, 140), Palette.SUNNY, 22, Stage2D.INK, _pop(1.8))
	# the door: a crack of light, then the hum floats in
	var door := Rect2(690, 96, 126, 300)
	s._rbox(Rect2(door.position - Vector2(10, 10), door.size + Vector2(20, 10)), Palette.WOOD.darkened(0.3), 10, 4)
	var open := Stage2D._ease_out(_k(3.0, 3.5)) * 0.22
	if open > 0.0:
		s.draw_colored_polygon(PackedVector2Array([door.position, door.position + Vector2(0, door.size.y),
			door.position + Vector2(-150, door.size.y + 30), door.position + Vector2(-120, -10)]), Color(Palette.SUNNY, 0.32 * open / 0.22))
		s._rbox(door, Color("#fff1c4"), 6, 0)
	s._push(Stage2D._about(Vector2(door.end.x, door.get_center().y), 0.0, Vector2(1.0 - open, 1.0)))
	s._rbox(door, Palette.WOOD, 6, 4)
	s._rbox(Rect2(door.position + Vector2(16, 20), Vector2(door.size.x - 32, 110)), Palette.WOOD.lightened(0.12), 6, 3)
	s._rbox(Rect2(door.position + Vector2(16, 150), Vector2(door.size.x - 32, 120)), Palette.WOOD.lightened(0.12), 6, 3)
	s._circ(door.position + Vector2(22, 156), 7.0, Palette.SUNNY, 3.0)
	s._pop_xf()
	s._chip("STAGE DOOR", Vector2(door.get_center().x, door.position.y - 30), Palette.PAPER, 14, Stage2D.INK, 1.0)
	# the hum: notes on a staff, drifting in from the crack
	var sk := _k(3.4, 3.8)
	if sk > 0.0:
		var x0 := 470.0
		var x1 := 690.0
		for j in 5:
			var y := 140.0 + j * 12.0
			s.draw_line(Vector2(x0 + (x1 - x0) * (1.0 - sk), y), Vector2(x1, y), Color(Stage2D.INK, 0.4), 2.0, true)
		for i in notes:
			var t0 := 3.6 + 0.4 * i
			var nk := _k(t0, t0 + 0.6)
			if nk <= 0.0:
				continue
			var drift := 0.0 if still else 8.0 * sin(t * 3.0 + i)
			var p := Vector2(lerpf(x1 - 10.0, 640.0 - 60.0 * i, Stage2D._ease_out(nk)), 182.0 - 12.0 * i + drift)
			_note_a(p, 0.9, Palette.PLUM, 1.0, 0.0)
		s._text("hmm, hmm, hmmm...", Vector2(580, 214), 16, Palette.PLUM.darkened(0.2), 700, 5, Palette.PAPER, 0.5, _pop(4.4))
	var perk := t >= 3.6
	s._hoot(Stage2D.HOOT_AT, 40.0, {"mood": &"gasp" if perk else &"idle", "squash": _ring(3.6, 0.25, 18.0, 5.0)})
	if perk:
		s._text("!", Stage2D.HOOT_AT + Vector2(44, -48), 30, Palette.CORAL, 700, 6, Palette.PAPER, 0.5, _pop(3.6))
	s._curtains(1.0 - Stage2D._ease_in_out(_k(5.0, 6.2)))
	if t > 6.1:
		s._chip("Places, trainee: someone's here!", Vector2(440, 300), Palette.PAPER, 22, Stage2D.INK, _pop(6.1))


# ---------------------------------------------------------------- the chart

static func _fx(freq: float) -> float:
	return CHART.position.x + CHART.size.x * log(clampf(freq, F_LO, F_HI) / F_LO) / log(F_HI / F_LO)


static func _fy(db: float) -> float:
	return CHART.position.y + CHART.size.y * clampf((db - DB_TOP) / (DB_BOTTOM - DB_TOP), 0.0, 1.0)


## Where a singer stands for a voice at `dial`: its cue's frequency across (side by side with the
## others at that frequency), dial + its offset down.
static func _spot(key: String, dial: float) -> Vector2:
	var cue: Array = CUES[key]
	var same: Array[String] = []
	for k: String in CUES:
		if int((CUES[k] as Array)[0]) == int(cue[0]):
			same.append(k)
	var i := same.find(key)
	return Vector2(_fx(float(cue[0])) + (i - (same.size() - 1) * 0.5) * FAN, _fy(dial + float(cue[1])))


## 0 = low pitches (500-750 Hz), 1 = the middle (1-2 kHz), 2 = high (3-4 kHz).
static func _group(key: String) -> int:
	var f := int((CUES[key] as Array)[0])
	return 0 if f <= 750 else (1 if f <= 2000 else 2)


## The threshold at any frequency, log-interpolated between the chart's own points (the
## SpeechRules.interp_threshold maths, copied).
static func _thr_at(th: Dictionary, freq: float) -> float:
	var fs: Array = th.keys()
	if fs.is_empty():
		return DB_TOP
	fs.sort()
	if freq <= float(fs[0]):
		return float(th[fs[0]])
	if freq >= float(fs[fs.size() - 1]):
		return float(th[fs[fs.size() - 1]])
	for i in fs.size() - 1:
		var a := float(fs[i])
		var b := float(fs[i + 1])
		if freq >= a and freq <= b:
			return lerpf(float(th[fs[i]]), float(th[fs[i + 1]]), (log(freq) - log(a)) / (log(b) - log(a)))
	return DB_TOP


## Behind the curtain: the sound reaches her ear softer than her threshold at its pitch.
static func _hidden(key: String, dial: float, th: Dictionary) -> bool:
	if th.is_empty():
		return false
	var cue: Array = CUES[key]
	return dial + float(cue[1]) < _thr_at(th, float(cue[0]))


static func _line_points(th: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var fs: Array = th.keys()
	fs.sort()
	for f: Variant in fs:
		pts.append(Vector2(_fx(float(f)), _fy(float(th[f]))))
	return pts


static func _line_y_at(line: PackedVector2Array, x: float) -> float:
	if line.is_empty():
		return CHART.position.y
	if x <= line[0].x:
		return line[0].y
	for i in line.size() - 1:
		if x >= line[i].x and x <= line[i + 1].x:
			return lerpf(line[i].y, line[i + 1].y, (x - line[i].x) / maxf(0.001, line[i + 1].x - line[i].x))
	return line[line.size() - 1].y


## The audiogram card: grid, dB down the side (soft at the top), pitch across. k draws it in.
func _chart(k: float) -> void:
	s._panel(Rect2(46, 58, 722, 372), Stage2D.GRAPH_BG, 18)
	var c := CHART
	s.draw_rect(c, Palette.CREAM.lightened(0.45))
	var grid := Color(Palette.SKY.darkened(0.18), 0.7)
	for db in range(0, 101, 20):
		var y := _fy(db)
		s.draw_line(Vector2(c.position.x, y), Vector2(c.position.x + c.size.x * k, y), grid, 2.0, true)
		s._text(str(db), Vector2(c.position.x - 8, y), 14, Palette.INK_SOFT, 700, 0, Palette.PAPER, 1.0)
	for f: int in [250, 500, 1000, 2000, 4000, 8000]:
		var x := _fx(f)
		if x <= c.position.x + c.size.x * k + 1.0:
			s.draw_line(Vector2(x, c.position.y), Vector2(x, c.end.y), grid, 2.0, true)
			s._text(("%dk" % (f / 1000)) if f >= 1000 else str(f), Vector2(x, c.end.y + 14), 14, Palette.INK_SOFT, 700)
	s.draw_rect(c, Stage2D.INK, false, 3.0)
	s._text("pitch: low to high (Hz)", Vector2(c.get_center().x, c.end.y + 38), 16, Stage2D.INK, 700)
	s._text("soft", Vector2(84, c.position.y + 8), 15, Stage2D.INK, 700)
	s._text("LOUD", Vector2(84, c.end.y - 8), 15, Stage2D.INK, 700)
	UiDraw.arrow(s, Vector2(84, c.get_center().y + 40), 12.0, Vector2(0, 1), Palette.INK_SOFT)
	s.draw_line(Vector2(84, c.position.y + 24), Vector2(84, c.get_center().y + 30), Palette.INK_SOFT, 3.0, true)
	s._text("dB", Vector2(84, c.get_center().y - 30), 13, Palette.INK_SOFT, 700, 4, Stage2D.GRAPH_BG)


## The speech banana around the singers' spots for a voice at `dial`: the soft edge over the softest
## sound at each pitch, the loud edge under the loudest, rounded. outline 0..1 draws its edge in;
## fill 0..1 its yellow; a fades the whole banana (the reduced-motion crossfade).
func _banana(dial: float, outline: float, fill: float, a: float) -> void:
	if a <= 0.01 or (outline <= 0.0 and fill <= 0.0):
		return
	var by_f: Dictionary = {}
	for key: String in CUES:
		var f := int((CUES[key] as Array)[0])
		var p := _spot(key, dial)
		if not by_f.has(f):
			by_f[f] = [p.x, p.x, p.y, p.y]
		var e: Array = by_f[f]
		by_f[f] = [minf(float(e[0]), p.x), maxf(float(e[1]), p.x), minf(float(e[2]), p.y), maxf(float(e[3]), p.y)]
	var fs: Array = by_f.keys()
	fs.sort()
	var pad := 24.0
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var first: Array = by_f[fs[0]]
	var last: Array = by_f[fs[fs.size() - 1]]
	top.append(Vector2(float(first[0]) - pad - 10.0, (float(first[2]) + float(first[3])) * 0.5))
	for f: Variant in fs:
		var e: Array = by_f[f]
		top.append(Vector2((float(e[0]) + float(e[1])) * 0.5, float(e[2]) - pad))
		bottom.append(Vector2((float(e[0]) + float(e[1])) * 0.5, float(e[3]) + pad))
	top.append(Vector2(float(last[1]) + pad + 10.0, (float(last[2]) + float(last[3])) * 0.5))
	bottom.reverse()
	var ring := top + bottom
	for _i in 3:
		ring = _chaikin(ring)
	if fill > 0.0:
		s.draw_colored_polygon(ring, Color(Palette.SUNNY, 0.32 * fill * a))
	if outline > 0.0:
		var n := int(ring.size() * clampf(outline, 0.0, 1.0))
		if n >= 2:
			var edge := ring.slice(0, n)
			if outline >= 1.0:
				edge.append(ring[0])
			s.draw_polyline(edge, Color(Palette.SUNNY.darkened(0.25), a), 6.0, true)


## Corner cutting on a closed polygon (rounds the banana).
static func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	return out


## The velvet curtain from the top of the chart down to the threshold line. drop 0..1 lowers the hem
## from the top to the line; a fades it (reduced motion); land: a little bounce at the hem.
func _curtain(line: PackedVector2Array, drop: float, a: float, land: float) -> void:
	if line.size() < 2 or drop <= 0.0 or a <= 0.01:
		return
	var top := CHART.position.y
	var hem := PackedVector2Array()
	var x := CHART.position.x
	while x < CHART.end.x:
		hem.append(Vector2(x, lerpf(top, _line_y_at(line, x), drop) + land * sin(x * 0.05)))
		x += 10.0
	hem.append(Vector2(CHART.end.x, lerpf(top, _line_y_at(line, CHART.end.x), drop) + land * sin(CHART.end.x * 0.05)))
	var poly := PackedVector2Array([Vector2(CHART.end.x, top), Vector2(CHART.position.x, top)])
	poly.append_array(hem)
	s.draw_colored_polygon(poly, Color(VELVET, 0.93 * a))
	var sway := sin(t * 1.4) * 2.0 * s._motion
	var fx := CHART.position.x + 12.0
	while fx < CHART.end.x - 6.0:
		var by := _line_y_at(hem, fx)
		if by > top + 8.0:
			s.draw_line(Vector2(fx, top + 2.0), Vector2(fx + sway, by - 4.0), Color(VELVET_DARK, 0.8 * a), 5.0, true)
		fx += 22.0
	s.draw_polyline(hem, Color(Palette.SUNNY, a), 6.0, true)
	var bx := CHART.position.x + 8.0
	while bx < CHART.end.x:
		s.draw_circle(Vector2(bx, _line_y_at(hem, bx) + 6.0), 4.0, Color(Palette.SUNNY.darkened(0.15), a), true, -1.0, true)
		bx += 18.0
	s.draw_line(Vector2(CHART.position.x, top), Vector2(CHART.end.x, top), Color(VELVET_DARK, a), 8.0, true)


## The tiny feet of the hidden high, soft singers (s, f, th) poking out under the hem.
func _feet(line: PackedVector2Array, dial: float, th: Dictionary, k: float) -> void:
	if k <= 0.01:
		return
	for i in HIGH_SOFT.size():
		var key := HIGH_SOFT[i]
		if not _hidden(key, dial, th):
			continue
		var x := _spot(key, dial).x
		var y := _line_y_at(line, x) + 10.0
		var wig := sin(t * 6.0 + i * 1.7) * 3.0 * s._motion
		for sd: float in [-1.0, 1.0]:
			var fp := Vector2(x + sd * 7.0, y + (wig if sd > 0 else -wig) * 0.5)
			s._ell(fp, Vector2(8.0, 5.0) * k, Stage2D.INK, sd * 0.25)
			s._ell(fp + Vector2(0, -0.5), Vector2(5.5, 3.0) * k, HIGH_COL.darkened(0.1), sd * 0.25)


## The made-up ear's threshold line, drawn left to right with its O marks.
func _threshold_line(line: PackedVector2Array, k: float) -> void:
	if line.size() < 2 or k <= 0.0:
		return
	var x_end := lerpf(line[0].x, line[line.size() - 1].x, k)
	var pts := PackedVector2Array()
	for p: Vector2 in line:
		if p.x <= x_end:
			pts.append(p)
	pts.append(Vector2(x_end, _line_y_at(line, x_end)))
	if pts.size() >= 2:
		s.draw_polyline(pts, Stage2D.INK, 7.0, true)
		s.draw_polyline(pts, Palette.RIGHT_RED, 4.0, true)
	for p: Vector2 in line:
		if p.x <= x_end:
			s.draw_circle(p, 9.0, Palette.PAPER, true, -1.0, true)
			s.draw_arc(p, 9.0, 0.0, TAU, 20, Palette.RIGHT_RED, 3.5, true)


## A singer on the chart. st: alpha, squash, tilt (a bow), sing.
func _chart_singer(key: String, at: Vector2, st: Dictionary) -> void:
	var vowel := key == "vowel"
	var cols: Array[Color] = [LOW_COL, MID_COL, HIGH_COL]
	var col: Color = VOWEL_COL if vowel else cols[_group(key)]
	var r := 17.0 if vowel else 11.5
	var sq := float(st.get("squash", 0.0))
	var tilt := float(st.get("tilt", 0.0))
	s._push(Stage2D._about(at + Vector2(0, r), tilt, Vector2(1.0 + sq, 1.0 - sq)))
	_singer(at, "o" if vowel else key, r, col, st)
	s._pop_xf()


# ---------------------------------------------------------------- the cast and props

## A letter singer: a round body with its letter, two eyes and a mouth (open while it sings), tiny
## feet. st: sing 0..1, alpha.
func _singer(c: Vector2, label: String, r: float, col: Color, st: Dictionary) -> void:
	var a := float(st.get("alpha", 1.0))
	if a <= 0.01:
		return
	var sing := float(st.get("sing", 0.0))
	var ink := Color(Stage2D.INK, a)
	for sd: float in [-1.0, 1.0]:
		var fp := c + Vector2(sd * r * 0.42, r * 0.98)
		s._ell(fp, Vector2(r * 0.26 + 2.0, r * 0.13 + 2.0), ink)
		s._ell(fp, Vector2(r * 0.26, r * 0.13), Color(col.darkened(0.15), a))
	s.draw_circle(c, r + 3.0, ink, true, -1.0, true)
	s.draw_circle(c, r, Color(col, a), true, -1.0, true)
	s.draw_arc(c + Vector2(-r * 0.3, -r * 0.3), r * 0.5, PI * 1.05, PI * 1.45, 8, Color(Palette.PAPER, 0.6 * a), maxf(2.0, r * 0.12), true)
	if r >= 24.0:
		# a big singer: eyes and a mouth above the letter on its belly
		for sd: float in [-1.0, 1.0]:
			var e := c + Vector2(sd * r * 0.3, -r * 0.42)
			s.draw_circle(e, r * 0.13, Color(Palette.PAPER, a), true, -1.0, true)
			s.draw_arc(e, r * 0.13, 0.0, TAU, 16, ink, 2.5, true)
			s.draw_circle(e + Vector2(0, -r * 0.02), r * 0.065, ink, true, -1.0, true)
		var m := c + Vector2(0, -r * 0.12)
		if sing > 0.0:
			s._ell(m, Vector2(r * 0.14, r * (0.06 + 0.12 * sing)), Color("#7a2a3a", a))
		else:
			s.draw_arc(m + Vector2(0, -r * 0.08), r * 0.14, PI * 0.2, PI * 0.8, 8, ink, 2.5, true)
		s._text(label, c + Vector2(0, r * 0.42), int(r * 0.7), ink, 700)
	else:
		# a small one: the letter is its face, two dot eyes on top
		for sd: float in [-1.0, 1.0]:
			s.draw_circle(c + Vector2(sd * r * 0.34, -r * 0.58), maxf(1.6, r * 0.12), ink, true, -1.0, true)
		s._text(label, c + Vector2(0, r * 0.12), int(r * (1.05 if label.length() == 1 else 0.85)), ink, 700)
		if sing > 0.0:
			s._ell(c + Vector2(r * 0.72, -r * 0.1), Vector2(r * 0.12, r * (0.08 + 0.1 * sing)), Color("#7a2a3a", a))


## A music note that can fade (the stage's _note() has no alpha).
func _note_a(c: Vector2, sz: float, col: Color, a: float, rot: float) -> void:
	if sz <= 0.02 or a <= 0.01:
		return
	s._push(Stage2D._xform(c, rot, Vector2.ONE * sz))
	var pts := s._ell_pts(Vector2.ZERO, Vector2(11, 8), 24, -0.4)
	s.draw_colored_polygon(pts, Color(col, a))
	pts.append(pts[0])
	s.draw_polyline(pts, Color(Stage2D.INK, a), 3.5, true)
	s.draw_line(Vector2(9, -3), Vector2(9, -34), Color(Stage2D.INK, a), 4.0, true)
	s.draw_polyline(PackedVector2Array([Vector2(9, -34), Vector2(20, -26), Vector2(22, -16)]), Color(Stage2D.INK, a), 4.0, true)
	s._pop_xf()


## A bean at the cafe table, standing behind it. st: mouth 0..1 (talking), look (-1 left, +1 right),
## mood (idle, puzzled), ear (draw her ear on the side facing him), bow (a hair bow).
func _bean(c: Vector2, h: float, col: Color, st: Dictionary) -> void:
	var look := float(st.get("look", 0.0))
	var mood: StringName = st.get("mood", &"idle")
	var r := Vector2(h * 0.36, h * 0.5)
	var breathe := sin(t * 2.4 + c.x * 0.01) * 0.02 * s._motion
	s._push(Stage2D._about(c + Vector2(0, r.y), 0.0, Vector2(1.0 - breathe, 1.0 + breathe)))
	s._blob(c, r, col, 4.0)
	s._ell(c + Vector2(-r.x * 0.35, -r.y * 0.45), Vector2(r.x * 0.22, r.y * 0.14), Color(Palette.PAPER, 0.5))
	if bool(st.get("ear", false)):
		var ec := c + Vector2(-r.x * 0.98, -r.y * 0.2)
		s._blob(ec, Vector2(10, 16), col, 3.5)
		s.draw_arc(ec + Vector2(2, 0), 8.0, PI * 0.6, PI * 1.4, 8, Color(Stage2D.INK, 0.6), 3.0, true)
	var eyes := c + Vector2(look * r.x * 0.22, -r.y * 0.36)
	for sd: float in [-1.0, 1.0]:
		var e := eyes + Vector2(sd * r.x * 0.36, 0)
		s.draw_circle(e, 9.0, Palette.PAPER, true, -1.0, true)
		s.draw_arc(e, 9.0, 0.0, TAU, 16, Stage2D.INK, 3.0, true)
		s.draw_circle(e + Vector2(look * 3.0, 1.0), 4.2, Stage2D.INK, true, -1.0, true)
		if mood == &"puzzled":
			s.draw_line(e + Vector2(-8, -16 - sd * 3.0), e + Vector2(8, -16 + sd * 3.0), Stage2D.INK, 3.5, true)
	s._ell(eyes + Vector2(-r.x * 0.55, 16), Vector2(8, 5), Color(Palette.CORAL, 0.4))
	s._ell(eyes + Vector2(r.x * 0.55, 16), Vector2(8, 5), Color(Palette.CORAL, 0.4))
	var m := eyes + Vector2(0, 26)
	var talk := float(st.get("mouth", 0.0))
	if talk > 0.05:
		s._ell(m, Vector2(8, 3.0 + 7.0 * talk), Color("#7a2a3a"))
	elif mood == &"puzzled":
		s.draw_polyline(PackedVector2Array([m + Vector2(-9, 1), m + Vector2(-3, -2), m + Vector2(3, 2), m + Vector2(9, -1)]), Stage2D.INK, 3.0, true)
	else:
		s.draw_arc(m + Vector2(0, -6), 9.0, PI * 0.2, PI * 0.8, 8, Stage2D.INK, 3.0, true)
	if bool(st.get("bow", false)):
		var bc := c + Vector2(r.x * 0.3, -r.y * 0.92)
		for sd: float in [-1.0, 1.0]:
			s.draw_colored_polygon(PackedVector2Array([bc, bc + Vector2(sd * 18, -10), bc + Vector2(sd * 18, 10)]), Palette.CORAL)
			s.draw_polyline(PackedVector2Array([bc, bc + Vector2(sd * 18, -10), bc + Vector2(sd * 18, 10), bc]), Stage2D.INK, 3.0, true)
		s._circ(bc, 5.0, Palette.CORAL.darkened(0.1), 3.0)
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


## A line as it reaches her: each "_" is a lost consonant, drawn as a dotted gap the width of a
## letter. a fades it; k pops it.
func _gappy(text: String, c: Vector2, px: int, a: float, k: float = 1.0) -> void:
	if a <= 0.01 or k <= 0.01:
		return
	var f := Stage2D.UiKit.font(700)
	var gap_w := f.get_string_size("n", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var total := 0.0
	for i in text.length():
		var ch := text.substr(i, 1)
		total += gap_w + 2.0 if ch == "_" else f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	var x := c.x - total * 0.5
	for i in text.length():
		var ch := text.substr(i, 1)
		if ch == "_":
			var box := Rect2(Vector2(x + 1.0, c.y - px * 0.4), Vector2(gap_w, px * 0.8))
			s.draw_rect(box, Color(Palette.CORAL, 0.14 * a))
			for j in 3:
				var u0 := j / 3.0
				s.draw_line(Vector2(box.position.x + box.size.x * u0 + 1.0, box.end.y), Vector2(box.position.x + box.size.x * (u0 + 0.2) + 1.0, box.end.y), Color(Palette.CORAL.darkened(0.1), a), 3.0, true)
			x += gap_w + 2.0
		else:
			s._text(ch, Vector2(x, c.y), px, Color(Stage2D.INK, a), 700, 0, Palette.PAPER, 0.0)
			x += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	s._pop_xf()


## The consonants of `said` that never reach her: every consonant letter beyond the ones `heard`
## keeps, in order (they tumble off the flying bubble).
static func _lost_letters(said: String, heard: String) -> Array[String]:
	var kept: Dictionary = {}
	for i in heard.length():
		var ch := heard.substr(i, 1).to_lower()
		kept[ch] = int(kept.get(ch, 0)) + 1
	var out: Array[String] = []
	for i in said.length():
		var ch := said.substr(i, 1).to_lower()
		if ch < "a" or ch > "z" or "aeiou".contains(ch):
			continue
		if int(kept.get(ch, 0)) > 0:
			kept[ch] = int(kept[ch]) - 1
		else:
			out.append(ch)
	return out


## A chunky word bubble with its level tag (the loud word; drawn, never played).
func _word_bubble(c: Vector2, word: String, k: float, tag: String) -> void:
	if k <= 0.01:
		return
	var f := Stage2D.UiKit.font(700)
	var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 30.0
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	var rr := Rect2(c - Vector2(w * 0.5, 22), Vector2(w, 44))
	s._rbox(Rect2(rr.position + Vector2(0, 5), rr.size), Color(Stage2D.INK, 0.25), 22, 0)
	s._rbox(rr, Palette.PAPER, 22, 4)
	s._text(word, c, 24, Palette.LEFT_BLUE.darkened(0.2), 700)
	if tag != "":
		s._chip(tag, c + Vector2(w * 0.5 + 4, -26), Palette.CORAL, 14, Stage2D.INK, 1.0)
	s._pop_xf()


## The Ghost: Righty under the bedsheet (the stage's _ghost() with its own eye holes empty), with
## Righty's eyes peeking out in red, so it is plainly the GOOD ear answering.
func _red_ghost(c: Vector2, r: float, st: Dictionary) -> void:
	var a := float(st.get("alpha", 1.0))
	if a <= 0.01:
		return
	s._ghost(c, r, {"empty": true, "alpha": a, "flag": float(st.get("flag", 0.0)), "flag_dir": 1.0, "squash": float(st.get("squash", 0.0))})
	var sq := float(st.get("squash", 0.0)) * s._motion
	s._push(Stage2D._xform(c, sin(t * 2.5) * 0.06 * s._motion, Vector2(1.0 + sq, 1.0 - sq)))
	for sd: float in [-1.0, 1.0]:
		var e := Vector2(sd * r * 0.32, -r * 0.18)
		s._ell(e, Vector2(r * 0.14, r * 0.19), Color(Stage2D.INK, a))
		s.draw_circle(e + Vector2(0, r * 0.03), r * 0.07, Color(Palette.RIGHT_RED.lightened(0.35), a), true, -1.0, true)
	if bool(st.get("boo", false)):
		s._ell(Vector2(0, r * 0.3), Vector2(r * 0.14, r * 0.18), Color(Stage2D.INK, a))
	s._pop_xf()


## A big volume knob: a dark dial face with tick marks and a pointer at `turn` (radians from up).
## wobble: the click.
func _knob(c: Vector2, r: float, turn: float, wobble: float) -> void:
	s._circ(c + Vector2(0, 6), r + 10.0, Color(Stage2D.INK, 0.2), 0.0)
	s._circ(c, r + 10.0, Palette.PAPER, 4.0)
	for i in 9:
		var ang := -PI * 0.5 + lerpf(-1.2, 1.4, i / 8.0)
		var col := Palette.MINT if i < 6 else Palette.CORAL
		s.draw_line(c + Vector2(cos(ang), sin(ang)) * (r + 2.0), c + Vector2(cos(ang), sin(ang)) * (r + 8.0), col.darkened(0.2), 4.0, true)
	s._circ(c, r * 0.82, Color("#4a3d66"), 4.0)
	var ang := -PI * 0.5 + turn + wobble
	s.draw_line(c, c + Vector2(cos(ang), sin(ang)) * r * 0.7, Palette.SUNNY, 7.0, true)
	s._circ(c + Vector2(cos(ang), sin(ang)) * r * 0.62, r * 0.1, Palette.SUNNY, 3.0)
	s._text("VOLUME", c + Vector2(0, r * 0.5), int(clampf(r * 0.22, 10.0, 16.0)), Palette.PAPER, 700)
