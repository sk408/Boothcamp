extends "res://story/case_movies/case_movie_sets.gd"
## The sets of "Hoot's case files movie" (story/explainers/movies/case_files.gd): Hoot the detective,
## three rubber stamps with faces, red flags on a washing line, and the proof card that closes a case.
## Facts: core/cases/case_rules.gd (DECISIONS, RED_FLAGS); docs/CASES.md section 7.

const SETS: Array[StringName] = [&"cf_open", &"cf_detective", &"cf_stamps", &"cf_flags", &"cf_proof", &"cf_bow"]

const STAMP_WORDS: Array[String] = ["FIT", "REFER", "DOCTOR\nTODAY"]
const STAMP_COLS: Array[Color] = [Palette.MINT, Palette.SUNNY, Palette.CORAL]
const STAMP_MARKS: Array[String] = ["FIT", "REFER", "TODAY!"]
const STAMP_INFO: Array = [["No red flags", "aids can help"], ["A doctor soon", "days to 2 weeks"], ["New sudden loss", "not wax or fluid"]]
const STAMP_STARTS: Array[float] = [0.6, 5.6, 10.5]
const CLUES: Array = [["Ringing ears", Vector2(410, 122)], ["Loud job, 20 years", Vector2(590, 116)],
	["Both ears alike", Vector2(410, 238)], ["No pain, no dizzy", Vector2(590, 234)]]
## The red flags the game uses (CaseRules.RED_FLAGS), two short lines each, and when each one pops.
const FLAGS: Array = [
	["ODD-SHAPED EAR", "from birth or injury"], ["DRAINAGE", "in the last 6 months"],
	["EAR PAIN", "or discomfort"], ["LOTS OF WAX", "or something stuck"],
	["DIZZINESS", "now or long-standing"], ["CHANGING LOSS", "sudden or up and down"],
	["ONE EAR WORSE", "or ringing in one"], ["AIR-BONE GAP", "15+ dB at 500-2k"]]
const FLAG_AT: Array[float] = [0.8, 1.9, 3.0, 4.1, 7.4, 8.6, 9.8, 11.0]
const ROW_Y: Array[float] = [74.0, 204.0]
const PROOF_CARDS: Array[String] = ["Loves jazz", "Left ear only", "New cat at home"]
const SLOT := Vector2(450, 230)
const HAT := Color("#b98a52")
const HAT_DARK := Color("#94683a")
const CORK := Color("#d6a46c")
const FOLDER := Color("#f2c46d")


# ---------------------------------------------------------------- 1. the lead-in

func _set_cf_open() -> void:
	_marquee("HOOT'S CASE FILES", "Three Stamps", "& the Red Flags", "starring FIT, REFER and DOCTOR TODAY", _prop_stamps)
	var t0 := float(params.get("card_hold", 8.0)) + 0.3
	for i in 3:
		var hop := absf(sin((t - t0) * 6.0 + i)) * 14.0 * s._motion if t > t0 + 0.8 else 0.0
		_stamp(Vector2(250.0 + 190.0 * i, 372.0 - hop), STAMP_WORDS[i], STAMP_COLS[i], _pop(t0 + 0.25 * i, 0.5), &"happy")
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(t0 + 0.6), "mood": &"wave"})


func _prop_stamps(at: Vector2) -> void:
	s._push(Stage2D._about(at, 0.0, Vector2.ONE * 0.38))
	for i in 3:
		_stamp(at + Vector2(-135.0 + 135.0 * i, 70.0), STAMP_WORDS[i], STAMP_COLS[i], 1.0, &"happy")
	s._pop_xf()


# ---------------------------------------------------------------- 2. clue spotters

func _set_cf_detective() -> void:
	# the cork board of clues, pinned one by one, then the red string between them
	var bk := _pop(0.3, 0.5)
	if bk > 0.01:
		s._push(Stage2D._about(Vector2(500, 180), 0.0, Vector2.ONE * bk))
		s._rbox(Rect2(318, 64, 364, 234), WOOD_DARK, 14, 4)
		s._rbox(Rect2(330, 76, 340, 210), CORK, 8, 0)
		s._pop_xf()
	# the red string runs pin to pin, behind the cards
	var pts := PackedVector2Array()
	for i in CLUES.size():
		var cl: Array = CLUES[i]
		pts.append(Vector2(cl[1]))
	var order: Array[int] = [0, 1, 3, 2]
	var sk := _k(3.0, 4.4)
	for j in 3:
		var a := pts[order[j]] + Vector2(0, -22)
		var b := pts[order[j + 1]] + Vector2(0, -22)
		var u := clampf(sk * 3.0 - j, 0.0, 1.0)
		if u > 0.0:
			s.draw_line(a, a.lerp(b, u), FLAG_RED, 3.0, true)
	for i in CLUES.size():
		var cl: Array = CLUES[i]
		_card(pts[i], 160.0, [String(cl[0])], Palette.PAPER, _pop(0.8 + 0.6 * i, 0.35), sin(i * 2.1) * 0.06, 17)
		if t > 0.8 + 0.6 * i:
			s._circ(pts[i] + Vector2(0, -22), 6.0, Palette.CORAL, 2.5)
	# Hoot in his deerstalker, the magnifier sweeping over the clues
	var hc := Vector2(150, 296)
	var mood: StringName = &"cheer" if t > 4.4 and t < 5.2 else &"idle"
	s._hoot(hc, 58.0, {"pop": _pop(0.1), "mood": mood})
	if t > 0.1:
		_deerstalker(hc + Vector2(0, sin(t * 3.2) * 2.0 * s._motion), 58.0, _pop(0.1))
	var path: Array[Vector2] = [Vector2(236, 290), pts[0], pts[1], pts[3], pts[2], Vector2(236, 290)]
	var u2 := _k(1.0, 4.8) * (path.size() - 1)
	var seg := mini(int(u2), path.size() - 2)
	var glass := path[seg].lerp(path[seg + 1], Stage2D._ease_in_out(u2 - seg))
	_magnifier(glass, 34.0, 0.9, _pop(0.6))
	# who does what
	_doctor(Vector2(790, 286), _pop(5.0, 0.5))
	s._trail(Vector2(684, 190), Vector2(740, 150), Vector2(772, 232), Palette.SKY.darkened(0.2), _k(5.4, 6.2))
	s._chip("YOU: spot and send", Vector2(150, 404), Palette.SUNNY, 19, Stage2D.INK, _pop(5.0))
	s._chip("DOCTOR: names it", Vector2(780, 404), Palette.SKY, 19, Stage2D.INK, _pop(5.8))


# ---------------------------------------------------------------- 3. the three stamps

func _set_cf_stamps() -> void:
	_traffic_light(Vector2(440, 38))
	for i in 3:
		var t0 := STAMP_STARTS[i]
		var x := 180.0 + 260.0 * i
		var col: Color = STAMP_COLS[i]
		var pk := _pop(t0 - 0.2, 0.4)
		if pk > 0.01:
			s._push(Stage2D._about(Vector2(x, 318), 0.0, Vector2.ONE * pk))
			s._rbox(Rect2(Vector2(x - 80, 286), Vector2(160, 64)), Palette.PAPER, 6, 3)
			s._pop_xf()
		if t >= t0 + 1.4:
			_imprint(Vector2(x, 318), STAMP_MARKS[i], col.darkened(0.25), 1.0 + 0.4 * (1.0 - _k(t0 + 1.4, t0 + 1.6)), -0.08 + 0.05 * i)
		var down := _k(t0 + 1.15, t0 + 1.4) - _k(t0 + 1.5, t0 + 1.9)
		var mood: StringName = &"wow" if i == 2 else &"happy"
		_stamp(Vector2(x, 236.0 + 82.0 * Stage2D._ease_in_out(down)), STAMP_WORDS[i], col, _pop(t0, 0.5), mood, 0.0, 128.0, down)
		var info: Array = STAMP_INFO[i]
		_card(Vector2(x, 396), 200.0, info, Palette.PAPER, _pop(t0 + 2.0), 0.0, 19)
		var ik := _pop(t0 + 2.4, 0.4)
		var ic := Vector2(x + 96.0, 196.0 + sin(t * 3.0 + i) * 4.0 * s._motion)
		match i:
			0:
				_hearing_aid(ic, ik)
			1:
				_envelope(ic, ik)
			2:
				_alarm_clock(ic, ik)


## Green, then amber, then red: the light follows the stamp being shown.
func _traffic_light(c: Vector2) -> void:
	var k := _pop(0.1, 0.4)
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	s._rbox(Rect2(c - Vector2(70, 22), Vector2(140, 44)), Stage2D.INK, 22, 0)
	var cur := -1
	for i in 3:
		if t >= STAMP_STARTS[i] + 0.3:
			cur = i
	for i in 3:
		var col: Color = STAMP_COLS[i]
		s.draw_circle(c + Vector2(-44.0 + 44.0 * i, 0), 15.0, col if i == cur else col.darkened(0.65), true, -1.0, true)
		if i == cur:
			s.draw_arc(c + Vector2(-44.0 + 44.0 * i, 0), 19.0 + 2.0 * sin(t * 6.0) * s._motion, 0.0, TAU, 24, Color(col, 0.6), 3.0, true)
	s._pop_xf()


# ---------------------------------------------------------------- 4. red flags on the line

func _set_cf_flags() -> void:
	for pole_x: float in [30.0, 850.0]:
		s.draw_line(Vector2(pole_x, ROW_Y[0] - 14.0), Vector2(pole_x, 432), Stage2D.INK, 11.0, true)
		s.draw_line(Vector2(pole_x, ROW_Y[0] - 14.0), Vector2(pole_x, 432), WOOD_DARK, 6.0, true)
	for row in 2:
		var line := PackedVector2Array()
		for i in 21:
			var u := i / 20.0
			line.append(Vector2(lerpf(30.0, 850.0, u), ROW_Y[row] + 16.0 * sin(PI * u)))
		s.draw_polyline(line, Stage2D.INK, 3.0, true)
	for i in FLAGS.size():
		var row := floori(i / 4.0)
		var x := 145.0 + 190.0 * (i % 4)
		var top := Vector2(x, ROW_Y[row] + 16.0 * sin(PI * (x - 30.0) / 820.0))
		var k := _pop(FLAG_AT[i], 0.4)
		if k <= 0.01:
			continue
		var f: Array = FLAGS[i]
		s._push(Stage2D._about(top, sin(t * 2.0 + i * 1.3) * 0.05 * s._motion, Vector2(1.0, k)))
		s._rbox(Rect2(top + Vector2(-82, 0), Vector2(164, 70)), FLAG_RED, 8, 3)
		for sd: float in [-1.0, 1.0]:
			s._rbox(Rect2(top + Vector2(sd * 52.0 - 5.0, -10), Vector2(10, 22)), Palette.WOOD, 3, 2)
		s._text(String(f[0]), top + Vector2(0, 24), 16, Palette.PAPER, 700)
		s._text(String(f[1]), top + Vector2(0, 48), 13, Color(Palette.PAPER, 0.92), 600)
		s._pop_xf()
	s._hoot(Vector2(80, 380), 32.0, {"pop": _pop(0.2), "mood": &"cheer" if t > 12.4 else &"idle"})
	s._chip("Any flag: REFER", Vector2(330, 372), Palette.SUNNY, 21, Stage2D.INK, _pop(12.6))
	s._chip("New sudden drop: TODAY", Vector2(620, 372), Palette.CORAL, 21, Stage2D.INK, _pop(13.6))


# ---------------------------------------------------------------- 5. the proof card

func _set_cf_proof() -> void:
	var fk := _pop(0.2, 0.5)
	if fk > 0.01:
		s._push(Stage2D._about(Vector2(450, 190), 0.0, Vector2.ONE * fk))
		s._rbox(Rect2(268, 46, 120, 30), FOLDER.darkened(0.08), 10, 3)
		s._text("CASE FILE", Vector2(328, 60), 15, Stage2D.INK, 700)
		s._rbox(Rect2(250, 64, 400, 250), FOLDER, 14, 4)
		for i in 4:
			var y := 104.0 + 26.0 * i
			s.draw_line(Vector2(282, y), Vector2(282.0 + (200.0 if i % 2 == 0 else 150.0), y), Color(Stage2D.INK, 0.3), 3.0, true)
		s._pop_xf()
	# the REFER stamp lands on the file
	if t >= 1.4:
		_imprint(Vector2(560, 116), "REFER", Palette.SUNNY.darkened(0.35), 1.0 + 0.4 * (1.0 - _k(1.4, 1.6)), -0.18)
	var down := _k(1.0, 1.4) - _k(1.5, 1.9)
	if t > 0.8 and t < 2.4:
		_stamp(Vector2(560, 46.0 + 86.0 * Stage2D._ease_in_out(down)), "REFER", Palette.SUNNY, _pop(0.8, 0.3) * (1.0 - _k(2.0, 2.4)), &"happy", 0.0, 128.0, down)
	# the empty proof slot: which card shows WHY?
	var slot_k := _pop(2.2, 0.4)
	if slot_k > 0.01:
		var rr := Rect2(SLOT - Vector2(112, 34), Vector2(224, 68))
		var dash := 12.0
		var per := 2.0 * (rr.size.x + rr.size.y)
		var off := fposmod(t * 30.0, dash * 2.0) * s._motion
		var d := 0.0
		while d < per:
			s.draw_line(Stage2D._rect_perimeter(rr, d + off), Stage2D._rect_perimeter(rr, minf(d + off + dash, per + off)), Color(Stage2D.INK, 0.6 * slot_k), 3.0, true)
			d += dash * 2.0
		if t < 8.6:
			s._text("PROOF?", SLOT, 24, Color(Stage2D.INK, 0.45 * slot_k), 700)
	# three clue cards: the wrong one bounces off, the right one stays and shines
	for i in 3:
		var home := Vector2(230.0 + 240.0 * i, 392.0)
		var pos := home
		var rot := sin(i * 1.7) * 0.05
		if i == 0:
			var go := Stage2D._ease_in_out(_k(6.9, 7.4))
			var back := Stage2D._ease_in_out(_k(7.4, 8.0))
			pos = home.lerp(SLOT + Vector2(0, 40), go).lerp(home, back)
			rot += _ring(7.4, 0.35, 14.0, 4.0)
		elif i == 1:
			pos = home.lerp(SLOT, Stage2D._ease_in_out(_k(8.6, 9.2)))
		var glow := i == 1 and t > 9.2
		_card(pos, 200.0, [PROOF_CARDS[i]], Palette.MINT.lightened(0.55) if glow else Palette.PAPER, _pop(0.9 + 0.2 * i, 0.4), rot, 20)
	if t > 7.5 and t < 8.8:
		s._text("?", Vector2(318, 330 + sin(t * 8.0) * 4.0 * s._motion), 46, Palette.CORAL, 700, 8, Palette.PAPER, 0.5, _pop(7.5, 0.3))
	s._sparkles(SLOT, 9.2, 14, 130.0, Palette.MINT)
	s._chip("PROOF!", Vector2(622, 196), Palette.MINT, 22, Stage2D.INK, _pop(9.4), -0.12)
	var mood: StringName = &"idle"
	if t > 7.4 and t < 8.4:
		mood = &"gasp"
	elif t > 9.2:
		mood = &"cheer"
	s._hoot(Vector2(66, 380), 32.0, {"pop": _pop(0.3), "mood": mood})
	var ck := _pop(10.2, 0.45)
	if ck > 0.01:
		s._big_sign("CASE CLOSED!", Vector2(420, 118), ck, -0.06 + sin(t * 3.0) * 0.03 * s._motion, Palette.SUNNY)


# ---------------------------------------------------------------- 6. the curtain call

func _set_cf_bow() -> void:
	_curtain_call(_bow_stamps, true)


func _bow_stamps(bow: float) -> void:
	for i in 3:
		_stamp(Vector2(250.0 + 190.0 * i, 372.0), STAMP_WORDS[i], STAMP_COLS[i], 1.0, &"happy", bow * 0.35)


# ---------------------------------------------------------------- props

## A rubber stamp with a face: a wooden knob (the face), a neck and the coloured block with its word.
## c: the middle of the rubber's bottom edge (where it meets the paper). press 0..1 squashes it.
func _stamp(c: Vector2, label: String, col: Color, k: float, mood: StringName, tilt: float = 0.0, w: float = 128.0, press: float = 0.0) -> void:
	if k <= 0.01:
		return
	var sq := 0.12 * clampf(press, 0.0, 1.0)
	s._push(Stage2D._about(c, tilt, Vector2(k * (1.0 + sq), k * (1.0 - sq))))
	var lines := label.split("\n")
	var bh := 30.0 + lines.size() * 18.0
	var block := Rect2(c + Vector2(-w * 0.5, -bh - 8.0), Vector2(w, bh))
	s._rbox(Rect2(c + Vector2(-w * 0.5 + 6.0, -12.0), Vector2(w - 12.0, 12.0)), col.darkened(0.4), 4, 3)
	s._rbox(block, col, 10, 4)
	for i in lines.size():
		var y := block.position.y + bh * 0.5 + (i - (lines.size() - 1) * 0.5) * 20.0
		s._text(lines[i], Vector2(c.x, y), 20, Stage2D.INK, 700)
	var neck_top := block.position.y - 24.0
	s._rbox(Rect2(Vector2(c.x - 12.0, neck_top), Vector2(24, 28)), WOOD_DARK, 6, 3)
	var knob := Vector2(c.x, neck_top - 22.0)
	s._circ(knob, 28.0, Palette.WOOD, 4.0)
	_face(knob, 28.0, mood)
	s._pop_xf()


## The mark a stamp leaves: its word in a rounded frame, in the stamp's ink.
func _imprint(c: Vector2, word: String, col: Color, scl: float, rot: float) -> void:
	s._push(Stage2D._about(c, rot, Vector2.ONE * scl))
	var w := 30.0 + word.length() * 15.0
	s._rbox(Rect2(c - Vector2(w * 0.5, 22), Vector2(w, 44)), Color(col, 0.08), 8, 4, col)
	s._text(word, c, 24, col, 700)
	s._pop_xf()


## Hoot's deerstalker, on a head of radius r centred at c.
func _deerstalker(c: Vector2, r: float, k: float) -> void:
	if k <= 0.01:
		return
	var top := c + Vector2(0, -r * 0.8)
	s._push(Stage2D._about(top, 0.0, Vector2.ONE * k))
	for sd: float in [-1.0, 1.0]:
		s._blob(top + Vector2(sd * r * 0.7, r * 0.26), Vector2(r * 0.34, r * 0.12), HAT_DARK, 3.0, -sd * 0.3)
	s._blob(top, Vector2(r * 0.74, r * 0.4), HAT, 4.0)
	for i in 3:
		var x := (i - 1) * r * 0.36
		s.draw_line(top + Vector2(x - r * 0.08, -r * 0.34), top + Vector2(x + r * 0.08, r * 0.34), Color(HAT_DARK, 0.8), 2.5, true)
	s.draw_line(top + Vector2(-r * 0.64, r * 0.02), top + Vector2(r * 0.64, r * 0.02), Color(HAT_DARK, 0.8), 2.5, true)
	s._circ(top + Vector2(0, -r * 0.4), r * 0.08, HAT_DARK, 2.5)
	s._pop_xf()


## A magnifying glass: the lens centred at c, the handle pointing down-left.
func _magnifier(c: Vector2, r: float, rot: float, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.0, Vector2.ONE * k))
	var dir := Vector2(-cos(rot), sin(rot))
	s.draw_line(c + dir * r, c + dir * (r + 46.0), Stage2D.INK, 14.0, true)
	s.draw_line(c + dir * (r + 4.0), c + dir * (r + 42.0), WOOD_DARK, 8.0, true)
	s.draw_circle(c, r, Color(Palette.SKY, 0.35), true, -1.0, true)
	s.draw_arc(c, r, 0.0, TAU, 36, Stage2D.INK, 8.0, true)
	s.draw_arc(c, r, 0.0, TAU, 36, Stage2D.BONE_GREY, 4.0, true)
	s.draw_arc(c, r * 0.62, PI * 1.1, PI * 1.45, 8, Color(Palette.PAPER, 0.8), 4.0, true)
	s._pop_xf()


## A friendly ear doctor in a white coat (c: the top of the coat).
func _doctor(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c + Vector2(0, 70), 0.0, Vector2.ONE * k))
	s._rbox(Rect2(c + Vector2(-40, 0), Vector2(80, 72)), Palette.PAPER, 22, 4)
	s.draw_line(c + Vector2(0, 6), c + Vector2(0, 68), Stage2D.INK, 3.0, true)
	s.draw_arc(c + Vector2(0, 8), 22.0, 0.25, PI - 0.25, 12, Stage2D.INK, 4.0, true)
	s._circ(c + Vector2(16, 36), 6.0, Stage2D.BONE_GREY, 3.0)
	var head := c + Vector2(0, -26)
	s._circ(head, 26.0, Palette.SKIN, 4.0)
	_face(head, 26.0, &"happy")
	s.draw_line(head + Vector2(-26, -12), head + Vector2(26, -12), Stage2D.INK, 4.0, true)
	s._circ(head + Vector2(0, -14), 9.0, Stage2D.BONE_GREY, 3.0)
	s._pop_xf()


## A behind-the-ear hearing aid: the body, its little tube and the dome.
func _hearing_aid(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, -0.3, Vector2.ONE * k))
	s._blob(c, Vector2(14, 30), Palette.SKIN.lightened(0.2), 4.0, 0.2)
	s.draw_arc(c + Vector2(20, -22), 18.0, PI, PI * 1.9, 10, Stage2D.INK, 4.0, true)
	s._circ(c + Vector2(36, -18), 7.0, Palette.PAPER, 3.0)
	s._pop_xf()


func _envelope(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(c, 0.12, Vector2.ONE * k))
	var rr := Rect2(c - Vector2(30, 20), Vector2(60, 40))
	s._rbox(rr, Palette.PAPER, 4, 3)
	s.draw_polyline(PackedVector2Array([rr.position, c + Vector2(0, 4), rr.position + Vector2(rr.size.x, 0)]), Stage2D.INK, 3.0, true)
	s.draw_circle(c + Vector2(0, 6), 5.0, FLAG_RED, true, -1.0, true)
	s._pop_xf()


func _alarm_clock(c: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	var jig := sin(t * 40.0) * 0.08 * s._motion
	s._push(Stage2D._about(c, jig, Vector2.ONE * k))
	for sd: float in [-1.0, 1.0]:
		s._circ(c + Vector2(sd * 18.0, -24.0), 9.0, Palette.CORAL, 3.0)
	s._circ(c, 26.0, Palette.PAPER, 4.0)
	s.draw_line(c, c + Vector2(0, -16), Stage2D.INK, 4.0, true)
	s.draw_line(c, c + Vector2(12, 4), Stage2D.INK, 4.0, true)
	s._pop_xf()
