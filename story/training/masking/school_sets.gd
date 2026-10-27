extends "res://story/explainers/explainer_sets.gd"
## SchoolSets (training, story-internal): the Masking School's boards, drawn on Hoot's movie stage
## through its sets hook (CONTRACTS.md §3.4), so the trainer looks like the Cross-Hearing Ghost movie:
## the same head, Righty (the test ear, red) and Lefty (blue), the skull wall and its toll sign.
## The trainer sets the stage's `t` and these params every frame (a pure function of both):
##   who_heard: transducer ("phones", "inserts", "bone"), tone, test_thr, other_thr (dB),
##     reveal (bool: draw who hears it), live (bool: "Try it": the answer follows the beep as it moves),
##     boo_at (stage time the Ghost popped up, or -1), verdict ("" or the callout).
##   when_card: transducer ("phones", "inserts"), freq, air (Righty's air), bone (the unmasked bone),
##     other_air (Lefty's air), show_bone / show_air (bool: draw each check), verdict, verdict_at.
##   start_dial: test ("ac", "bc"), freq, other_air, other_gap, masker ("phones", "inserts"), dial (dB EM),
##     target (dB EM, or -1: "Try it" shows Hoot's level), reveal (bool: the sum on the dial), verdict, verdict_at.
##   plateau_walk: the patient (freq, t_test, t_other, gap_other, masker, kind), records (the presentations so
##     far: db, mask_db, responded), step_at (stage time of the latest), reveal (bool: the walk is over), verdict.

const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const SETS: Array[StringName] = [&"who_heard", &"when_card", &"start_dial", &"plateau_walk"]

const FOAM := Color("#f6c453")
const TUBE := Color("#9aa3b5")


func _set_who_heard() -> void:
	var tr := String(params.get("transducer", "phones"))
	var card := {"transducer": tr, "tone": int(params.get("tone", 40)), "test_thr": int(params.get("test_thr", 20)),
		"other_thr": int(params.get("other_thr", 10))}
	var shown := bool(params.get("reveal", false)) or bool(params.get("live", false))
	var righty := MaskDeck.test_hears(card) and shown
	var lefty := MaskDeck.other_hears(card) and shown
	var bone := tr == "bone"
	var boo_at := float(params.get("boo_at", -1.0))
	var ghost := lefty and not righty
	_head_open(0.25 if bone and shown else 0.0)
	s._head({"look": Vector2(0.8 if lefty else -0.6, -0.1), "mood": &"wow" if lefty else &"smile"})
	s._wall(1.0, 0.28 if bone else 1.0, bone)
	s._snail(Stage2D.RIGHTY_AT, 1.0, Palette.RIGHT_RED, Stage2D.RIGHTY_BODY,
		{"mood": &"alert" if righty else (&"sleep" if shown else &"idle"), "arm": 1.0 if righty else 0.0, "look": Vector2(-1, -0.2)})
	if ghost and boo_at >= 0.0:
		s._footprint(Stage2D.LEFTY_AT, Palette.LEFT_BLUE, 1.0)
	else:
		s._snail(Stage2D.LEFTY_AT, -1.0, Palette.LEFT_BLUE, Stage2D.LEFTY_BODY,
			{"mood": &"alert" if lefty else &"sleep", "arm": 1.0 if lefty else 0.0, "look": Vector2(1, -0.3)})
	match tr:
		"inserts":
			_insert()
		"bone":
			s._buzzer(1.0, 1.0 if shown else 0.4, 0.0)
		_:
			s._cup(Stage2D.CUP_R_AT, Palette.RIGHT_RED, "R", 1.0, -1.0)
	_head_close()
	if shown and not righty:
		s._zzz(Stage2D.RIGHTY_AT + Vector2(-60, -66))
	if shown and not lefty:
		s._zzz(Stage2D.LEFTY_AT + Vector2(-6, -104))
	# each cochlea's own hearing: what a beep must reach
	s._chip("Righty hears from %d dB" % int(card["test_thr"]), Stage2D.RIGHTY_AT + Vector2(-4, 56), Palette.RIGHT_TINT, 15)
	s._chip("Lefty hears from %d dB" % int(card["other_thr"]), Stage2D.LEFTY_HEARS_AT, Palette.LEFT_TINT, 15)
	# the beep on the test ear
	var beep_at := (Stage2D.BUZZ_AT + Vector2(-70, -40)) if bone else (Stage2D.CUP_R_AT + Vector2(-26, -100))
	s._chip("BEEP %d dB" % int(card["tone"]), beep_at, Palette.SUNNY, 20)
	# the toll sign: what the wall takes off
	var w := MaskDeck.wall(tr)
	if bone:
		s._toll_sign(Stage2D.SIGN_AT, Stage2D.BONE_SIGN, 1.0, 0.0, Palette.MINT)
	else:
		s._toll_sign(Stage2D.SIGN_AT, ["-%d dB" % w, "%s: at least" % ("inserts" if tr == "inserts" else "on-ear phones")], 1.0, 0.0,
			Palette.SKY if tr == "inserts" else Palette.PAPER)
	if shown:
		var into := Stage2D.LEFTY_AT + Vector2(-64, -58)
		s._note(Vector2(Stage2D.WALL_X + 34, Stage2D.SQUEEZE_Y), 0.9, Palette.RIGHT_RED if lefty else Color(Palette.RIGHT_RED, 0.35))
		var sum := "%d - %d = %d" % [int(card["tone"]), w, MaskDeck.crossed(card)] if w > 0 else "%d across" % int(card["tone"])
		s._chip(sum, Stage2D.MATH_AT, Palette.SUNNY if lefty else Palette.PAPER, 22)
		s._text("reaches Lefty!" if lefty else "too soft for Lefty", Stage2D.MATH_AT + Vector2(0, 36), 16, Stage2D.INK, 700, 5)
		if lefty and not ghost:
			s._text("!", into + Vector2(38, -66), 38, Palette.LEFT_BLUE, 700, 7)
	if ghost and boo_at >= 0.0:
		var k := _k(boo_at, boo_at + 0.8)
		var home := Stage2D.LEFTY_AT + Vector2(0, -44)
		var gp := home.lerp(Stage2D.GHOST_AWAY, Stage2D._ease_in_out(k)) + Vector2(0, -sin(k * PI) * 60.0)
		s._ghost(gp, 46.0, {"squash": _ring(boo_at, 0.25, 16.0, 5.0), "boo": k >= 1.0, "flag": _k(boo_at + 0.8, boo_at + 1.1), "flag_dir": -1.0})
		if k >= 1.0:
			s._boo_bubble(Stage2D.BOO_AT, _pop(boo_at + 0.8, 0.4), gp + Vector2(-40, 10))
	var verdict := String(params.get("verdict", ""))
	if verdict != "":
		s._chip(verdict, Stage2D.CALLOUT_AT, Palette.SUNNY, 22, Stage2D.INK, _pop(float(params.get("verdict_at", 0.0))))
	s._name_tag("RIGHTY", Stage2D.RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	s._name_tag("LEFTY", Stage2D.LEFTY_AT, Palette.LEFT_BLUE, 1.0)


func _head_open(jelly: float) -> void:
	s._head_open(jelly)


func _head_close() -> void:
	s._head_close()


## A foam insert tip squeezed into her right ear canal, with its sound tube.
func _insert() -> void:
	_insert_at(Stage2D.CUP_R_AT + Vector2(22, 0), 1.0, "R", Palette.RIGHT_RED)


# ---------------------------------------------------------------- station 2: mask it?

const CHART := Rect2(20, 20, 360, 400)
const PLOT_TOP := 84.0
const PLOT_BOTTOM := 354.0
const COL_X := 215.0
const SIDE_C := 630.0


func _db_y(db: float) -> float:
	return lerpf(PLOT_TOP, PLOT_BOTTOM, (db + 10.0) / 130.0)


func _set_when_card() -> void:
	var card := {"transducer": String(params.get("transducer", "phones")), "freq": int(params.get("freq", 1000)),
		"air": int(params.get("air", 40)), "bone": int(params.get("bone", 20)), "other_air": int(params.get("other_air", 25))}
	var show_bone := bool(params.get("show_bone", false))
	var show_air := bool(params.get("show_air", false))
	var w := MaskDeck.wall(String(card["transducer"]))
	var air := int(card["air"])
	var bone := int(card["bone"])
	# the chart: one frequency lit
	s._panel(CHART, Stage2D.GRAPH_BG, 18)
	s._text("%d Hz" % int(card["freq"]), Vector2(COL_X, 48), 22, Stage2D.INK, 700)
	for db in range(-10, 121, 10):
		var y := _db_y(db)
		s.draw_line(Vector2(76, y), Vector2(CHART.end.x - 18, y), Color(Stage2D.INK, 0.25 if db % 20 == 0 else 0.1), 2.0 if db == 0 else 1.0)
		if db % 20 == 0:
			s._text(str(db), Vector2(56, y), 14, Palette.INK_SOFT, 600)
	s.draw_line(Vector2(COL_X, PLOT_TOP), Vector2(COL_X, PLOT_BOTTOM), Color(Palette.SUNNY, 0.6), 22.0)
	s._text("dB HL", Vector2(52, PLOT_TOP - 22), 12, Palette.INK_SOFT, 600)
	# the symbols: O Righty's air, < the unmasked bone, X Lefty's air
	_sym_x(Vector2(COL_X + 34, _db_y(int(card["other_air"]))), Palette.LEFT_BLUE)
	_sym_bone(Vector2(COL_X - 30, _db_y(bone)), Palette.RIGHT_RED)
	s.draw_arc(Vector2(COL_X, _db_y(air)), 11.0, 0.0, TAU, 28, Palette.RIGHT_RED, 4.0, true)
	var ly := CHART.end.y - 32
	s.draw_arc(Vector2(44, ly), 8.0, 0.0, TAU, 20, Palette.RIGHT_RED, 3.0, true)
	s._text("Righty air", Vector2(58, ly), 14, Stage2D.INK, 700, 0, Palette.PAPER, 0.0)
	_sym_bone(Vector2(160, ly), Palette.RIGHT_RED, 7.0)
	s._text("bone", Vector2(172, ly), 14, Stage2D.INK, 700, 0, Palette.PAPER, 0.0)
	_sym_x(Vector2(240, ly), Palette.LEFT_BLUE, 7.0)
	s._text("Lefty air", Vector2(254, ly), 14, Stage2D.INK, 700, 0, Palette.PAPER, 0.0)
	# the checks drawn on the chart
	if show_bone:
		var x := 128.0
		s.draw_line(Vector2(x, _db_y(bone)), Vector2(x, _db_y(air)), Stage2D.INK, 3.0, true)
		for y: float in [_db_y(bone), _db_y(air)]:
			s.draw_line(Vector2(x - 8, y), Vector2(x + 8, y), Stage2D.INK, 3.0, true)
		s._chip("gap %d" % MaskDeck.gap(card), Vector2(x, (_db_y(bone) + _db_y(air)) * 0.5), Palette.CORAL if MaskDeck.mask_bone(card) else Palette.MINT, 14)
	if show_air:
		var x := 300.0
		var crossed := maxi(air - w, -10)   # the chart stops at -10
		var hit := MaskDeck.mask_air(card)
		_dashed(Vector2(COL_X + 54, _db_y(bone)), Vector2(CHART.end.x - 18, _db_y(bone)), Palette.RIGHT_RED)
		_arrow(Vector2(x, _db_y(air)), Vector2(x, _db_y(crossed)), Palette.INK)
		s._text("-%d" % w, Vector2(x + 30, (_db_y(air) + _db_y(crossed)) * 0.5), 16, Stage2D.INK, 700, 4)
		s._circ(Vector2(x, _db_y(crossed)), 9.0, Palette.CORAL if hit else Palette.MINT, 3.0)
	# the side: who's tested, the earphone, the numbers
	s._chip("RIGHTY IS THE TEST EAR", Vector2(SIDE_C, 40), Palette.RIGHT_RED, 18, Palette.PAPER)
	var tr_word := "Inserts: wall %d" % w if String(card["transducer"]) == "inserts" else "Headphones: wall %d" % w
	s._chip(tr_word, Vector2(SIDE_C, 90), Palette.SKY if String(card["transducer"]) == "inserts" else Palette.PAPER, 18)
	s._chip("Righty AIR  %d" % air, Vector2(SIDE_C - 110, 146), Palette.RIGHT_TINT, 20)
	s._chip("BONE  %d" % bone, Vector2(SIDE_C + 110, 146), Palette.RIGHT_TINT, 20)
	s._text("bone, no masking: the better cochlea", Vector2(SIDE_C, 182), 14, Palette.INK_SOFT, 600)
	s._chip("Lefty AIR  %d" % int(card["other_air"]), Vector2(SIDE_C, 220), Palette.LEFT_TINT, 18)
	# the two checks
	if show_bone:
		var yes := MaskDeck.mask_bone(card)
		s._chip("Bone: %d - %d = gap %d" % [air, bone, MaskDeck.gap(card)], Vector2(SIDE_C - 70, 282), Palette.PAPER, 18)
		s._chip("MASK BONE" if yes else "NO", Vector2(SIDE_C + 150, 282), Palette.CORAL if yes else Palette.MINT, 17)
	if show_air:
		var yes := MaskDeck.mask_air(card)
		s._chip("Air: %d - %d = %d vs bone %d" % [air, w, air - w, bone], Vector2(SIDE_C - 70, 334), Palette.PAPER, 18)
		s._chip("MASK AIR" if yes else "SAFE", Vector2(SIDE_C + 150, 334), Palette.CORAL if yes else Palette.MINT, 17)
	var verdict := String(params.get("verdict", ""))
	if verdict != "":
		s._chip(verdict, Vector2(SIDE_C, 396), Palette.SUNNY, 19, Stage2D.INK, _pop(float(params.get("verdict_at", 0.0))))


## The audiogram's X (left air).
func _sym_x(c: Vector2, col: Color, r: float = 10.0) -> void:
	s.draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 4.0, true)
	s.draw_line(c + Vector2(-r, r), c + Vector2(r, -r), col, 4.0, true)


## The audiogram's < (right bone, unmasked).
func _sym_bone(c: Vector2, col: Color, r: float = 10.0) -> void:
	s.draw_polyline(PackedVector2Array([c + Vector2(r * 0.7, -r), c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.7, r)]), col, 4.0, true)


func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(a.distance_to(b) / 12.0)
	for i in n:
		if i % 2 == 0:
			s.draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), col, 2.5, true)


## An arrow drawn, not typed (the web font has no arrow glyphs).
func _arrow(a: Vector2, b: Vector2, col: Color) -> void:
	if a.distance_to(b) < 2.0:
		return
	var d := (b - a).normalized()
	s.draw_line(a, b - d * 8.0, col, 4.0, true)
	var n := Vector2(-d.y, d.x)
	s.draw_colored_polygon(PackedVector2Array([b, b - d * 14.0 + n * 8.0, b - d * 14.0 - n * 8.0]), col)


# ---------------------------------------------------------------- station 3: set the dial

const MINI_AT := Vector2(230, 236)
const MINI_SCALE := 0.62
const DIAL_C := Vector2(640, 200)
const DIAL_R := 110.0


func _mini() -> Transform2D:
	return Transform2D(0.0, Vector2.ONE * MINI_SCALE, 0.0, MINI_AT) * Transform2D(0.0, Vector2.ONE, 0.0, -Stage2D.HEAD_C)


## The head, shrunk to the left: Righty tested (bone buzzer, or her earphone), Lefty under the shhh
## (a cloud sized by the masker). Returns the transform, to place chips over it.
func _mini_head(bone: bool, inserts: bool, mask_db: int, mood: StringName = &"idle") -> Transform2D:
	var xf := _mini()
	s._push(xf)
	s._head_open(0.0)
	s._head({"look": Vector2(0.5, -0.1), "mood": &"smile" if mood == &"idle" else mood})
	s._wall(1.0, 0.28 if bone else 1.0, bone)
	var cloud_r := lerpf(34.0, 104.0, clampf(mask_db / 100.0, 0.0, 1.0))
	s._cloud(Stage2D.CLOUD_AT, cloud_r, {"patchy": 0.0})
	s._snail(Stage2D.RIGHTY_AT, 1.0, Palette.RIGHT_RED, Stage2D.RIGHTY_BODY, {"mood": &"alert", "look": Vector2(-1, -0.2)})
	s._snail(Stage2D.LEFTY_AT, -1.0, Palette.LEFT_BLUE, Stage2D.LEFTY_BODY, {"mood": &"idle", "look": Vector2(1, -0.3)})
	if bone:
		s._buzzer(1.0, 0.6, 0.0)
	elif inserts:
		_insert_at(Stage2D.CUP_R_AT + Vector2(22, 0), 1.0, "R", Palette.RIGHT_RED)
	else:
		s._cup(Stage2D.CUP_R_AT, Palette.RIGHT_RED, "R", 1.0, -1.0)
	if inserts:
		_insert_at(Stage2D.CUP_L_AT + Vector2(-22, 0), -1.0, "L", Palette.LEFT_BLUE)
	else:
		s._cup(Stage2D.CUP_L_AT, Palette.LEFT_BLUE, "L", 1.0, 1.0)
	s._head_close()
	s._shhh_letters(Stage2D.CLOUD_AT, cloud_r)
	s._pop_xf()
	return xf


func _set_start_dial() -> void:
	var card := {"test": String(params.get("test", "bc")), "freq": int(params.get("freq", 500)), "other_air": int(params.get("other_air", 15)),
		"other_gap": int(params.get("other_gap", 0)), "masker": String(params.get("masker", "phones"))}
	var dial := int(params.get("dial", 0))
	var reveal := bool(params.get("reveal", false))
	var target := int(params.get("target", -1))
	var bone := MaskDeck.is_bone_test(card)
	var inserts := String(card["masker"]) == "inserts"
	var boom := MaskDeck.boom(card)
	var xf := _mini_head(bone, inserts, dial)
	if reveal and boom > 0:
		s._chip("BOOM +%d" % boom, xf * (Stage2D.LEFTY_AT + Vector2(10, -200)), Palette.SELECT_ORANGE, 18, Stage2D.INK, _pop(float(params.get("verdict_at", 0.0))), 0.08)
	s._name_tag("RIGHTY", xf * Stage2D.RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	s._name_tag("LEFTY", xf * Stage2D.LEFTY_AT, Palette.LEFT_BLUE, 1.0)
	var test_word := "BONE" if bone else "AIR"
	s._chip("TEST: Righty's %s at %d Hz" % [test_word, int(card["freq"])], Vector2(MINI_AT.x, 372), Palette.RIGHT_TINT, 17)
	s._chip("Shhh: %s on Lefty" % MaskDeck.MASKER_WORDS[String(card["masker"])], Vector2(MINI_AT.x, 414), Stage2D.NOISE_FILL, 17)
	# the dial
	_noise_dial(dial, target, card, reveal)
	s._chip("Lefty's AIR  %d" % int(card["other_air"]), Vector2(DIAL_C.x, 300), Palette.LEFT_TINT, 19)
	var gap := int(card["other_gap"])
	var gap_word := "Lefty's gap %d: normal middle ear" % gap if gap <= ClinicRules.OCCLUSION_MAX_GAP_DB else "Lefty's gap %d: blocked middle ear" % gap
	s._chip(gap_word, Vector2(DIAL_C.x, 344), Palette.PAPER, 16)
	if reveal:
		var lvl := MaskDeck.start_level(card)
		var sum := "%d + %d = %d" % [int(card["other_air"]), ClinicRules.MASK_SAFETY_DB, lvl]
		if boom > 0:
			sum = "%d + %d + %d = %d" % [int(card["other_air"]), ClinicRules.MASK_SAFETY_DB, boom, lvl]
		s._chip(sum, Vector2(DIAL_C.x, 392), Palette.SUNNY, 22)
	var verdict := String(params.get("verdict", ""))
	if verdict != "":
		s._chip(verdict, Vector2(440, 26), Palette.SUNNY, 19, Stage2D.INK, _pop(float(params.get("verdict_at", 0.0))))


## The grey noise dial, 0-100 dB EM. Revealed: the sum as slices (Lefty's air grey-blue, +10 mint, the
## occlusion boom orange) and the right level as a gold tick. target >= 0 marks Hoot's level in Try it.
func _noise_dial(dial: int, target: int, card: Dictionary, reveal: bool) -> void:
	var c := DIAL_C
	var r := DIAL_R
	s._panel(Rect2(c - Vector2(r + 40, r + 34), Vector2((r + 40) * 2.0, r + 102)), Palette.PAPER, 22)
	s.draw_arc(c, r - 10.0, PI, TAU, 40, Color("#c9ccd6"), 18.0, true)
	if reveal or target >= 0:
		var air := float(card["other_air"])
		var lvl := float(MaskDeck.start_level(card))
		var boom := float(MaskDeck.boom(card))
		_slice(0.0, air, Palette.LEFT_TINT.darkened(0.15))
		_slice(air, lvl - boom, Palette.MINT)
		if boom > 0.0:
			_slice(lvl - boom, lvl, Palette.SELECT_ORANGE)
		_tick(lvl, Stage2D.GOLD, 26.0)
	s.draw_arc(c, r, PI, TAU, 40, Stage2D.INK, 3.0, true)
	for db in range(0, 101, 10):
		var a := PI + PI * db / 100.0
		var dir := Vector2(cos(a), sin(a))
		s.draw_line(c + dir * (r - 2.0), c + dir * (r + (10.0 if db % 20 == 0 else 5.0)), Stage2D.INK, 2.0, true)
		if db % 20 == 0:
			s._text(str(db), c + dir * (r + 22.0), 13, Palette.INK_SOFT, 600)
	var ang := PI + PI * clampf(dial / 100.0, 0.0, 1.0)
	s.draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 6.0), Stage2D.INK, 6.0, true)
	s.draw_circle(c, 9.0, Stage2D.INK, true, -1.0, true)
	s._text("SHHH %d" % dial, c + Vector2(0, 30), 26, Stage2D.NOISE_DEEP, 700)
	s._text("dB EM", c + Vector2(0, 52), 13, Palette.INK_SOFT, 600)


func _slice(from_db: float, to_db: float, col: Color) -> void:
	if to_db <= from_db:
		return
	s.draw_arc(DIAL_C, DIAL_R - 10.0, PI + PI * from_db / 100.0, PI + PI * to_db / 100.0, 16, col, 18.0, true)


func _tick(db: float, col: Color, len: float) -> void:
	var a := PI + PI * clampf(db / 100.0, 0.0, 1.0)
	var dir := Vector2(cos(a), sin(a))
	s.draw_line(DIAL_C + dir * (DIAL_R - len), DIAL_C + dir * (DIAL_R + 6.0), Stage2D.INK, 8.0, true)
	s.draw_line(DIAL_C + dir * (DIAL_R - len + 2.0), DIAL_C + dir * (DIAL_R + 4.0), col, 4.0, true)


## A foam insert tip in an ear canal (side 1: her right ear, the screen's left; -1: her left).
func _insert_at(at: Vector2, side: float, letter: String, col: Color) -> void:
	var tube := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		tube.append(at + Vector2(side * (-20.0 - 50.0 * u), 8.0 + 90.0 * u * u))
	s.draw_polyline(tube, Stage2D.INK, 9.0, true)
	s.draw_polyline(tube, TUBE, 4.0, true)
	s._blob(at, Vector2(20, 15), FOAM, 4.0)
	s._text(letter, at + Vector2(-2 * side, 1), 16, col, 700)


# ---------------------------------------------------------------- station 4: the plateau walk

const BOARD := Rect2(420, 16, 444, 408)
const PX0 := 478.0      # masker 0 dB EM
const PX1 := 838.0      # masker 100
const PY0 := 352.0      # beep -10 dB
const PY1 := 64.0       # beep 70 dB


func _bx(mask_db: float) -> float:
	return lerpf(PX0, PX1, clampf(mask_db / 100.0, 0.0, 1.0))


func _by(tone_db: float) -> float:
	return lerpf(PY0, PY1, clampf((tone_db + 10.0) / 80.0, 0.0, 1.0))


func _set_plateau_walk() -> void:
	var p := {"kind": String(params.get("kind", "shift")), "freq": int(params.get("freq", 1000)), "t_test": int(params.get("t_test", 30)),
		"t_other": int(params.get("t_other", 10)), "gap_other": int(params.get("gap_other", 0)), "masker": String(params.get("masker", "phones"))}
	var records: Array = params.get("records", [])
	var reveal := bool(params.get("reveal", false))
	var step_at := float(params.get("step_at", 0.0))
	var last: Dictionary = records.back() if not records.is_empty() else {"db": MaskDeck.walk_start_tone(p), "mask_db": MaskDeck.walk_initial(p), "responded": false}
	var tone := int(last["db"])
	var mask := int(last["mask_db"])
	var heard := bool(last["responded"])
	# the patient (a cartoon), under the shhh
	var xf := _mini_head(true, false, mask, &"wow" if heard else &"idle")
	var top := xf * (Stage2D.HEAD_C + Vector2(0, -230))
	if heard:
		s._chip("YES! (hand up)", top, Palette.MINT, 20, Stage2D.INK, _pop(step_at), sin(t * 6.0) * 0.04 * s._motion)
	else:
		s._chip("... no answer", top, Palette.PAPER, 18, Palette.INK_SOFT, _pop(step_at))
	s._name_tag("RIGHTY", xf * Stage2D.RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	s._name_tag("LEFTY", xf * Stage2D.LEFTY_AT, Palette.LEFT_BLUE, 1.0)
	s._chip("BEEP %d dB: Righty's bone, %d Hz" % [tone, int(p["freq"])], Vector2(MINI_AT.x, 372), Palette.RIGHT_TINT, 17)
	s._chip("SHHH %d dB EM on Lefty" % mask, Vector2(MINI_AT.x, 414), Stage2D.NOISE_FILL, 17)
	# the plateau board: shhh across, beep up
	s._panel(BOARD, Stage2D.GRAPH_BG, 18)
	for db in range(-10, 71, 10):
		var y := _by(db)
		s.draw_line(Vector2(PX0, y), Vector2(PX1, y), Color(Stage2D.INK, 0.2 if db % 20 == 10 else 0.1), 1.0)
		if db % 20 == 10:
			s._text(str(db), Vector2(PX0 - 22, y), 13, Palette.INK_SOFT, 600)
	for m in range(0, 101, 20):
		s._text(str(m), Vector2(_bx(m), PY0 + 16), 13, Palette.INK_SOFT, 600)
	s._text("BEEP", Vector2(PX0 - 24, PY1 - 30), 13, Palette.RIGHT_RED, 700)
	s._text("SHHH (dB EM)", Vector2((PX0 + PX1) * 0.5, PY0 + 33), 14, Stage2D.NOISE_DEEP, 700)
	# the window for the current beep: too little, just right, too much
	var lo := MaskDeck.walk_initial(p)
	var hi := MaskDeck.walk_limit(p, tone)
	var band_y := PY0 + 46.0
	var dilemma := MaskDeck.walk_dilemma(p)
	var bh := 16.0
	s.draw_rect(Rect2(PX0, band_y, _bx(mini(lo, hi)) - PX0, bh), Palette.SUNNY)
	if not dilemma:
		s.draw_rect(Rect2(_bx(lo), band_y, _bx(hi) - _bx(lo), bh), Palette.MINT)
	s.draw_rect(Rect2(_bx(hi), band_y, PX1 - _bx(hi), bh), Palette.CORAL)
	s.draw_rect(Rect2(PX0, band_y, PX1 - PX0, bh), Stage2D.INK, false, 2.0)
	var mid := band_y + bh * 0.5
	if _bx(mini(lo, hi)) - PX0 >= 70:
		s._text("too little", Vector2((PX0 + _bx(mini(lo, hi))) * 0.5, mid), 12, Stage2D.INK, 700)
	if PX1 - _bx(hi) >= 70:
		s._text("too much", Vector2((_bx(hi) + PX1) * 0.5, mid), 12, Stage2D.INK, 700)
	if dilemma:
		s._chip("? no safe window", Vector2(_bx((lo + hi) * 0.5), PY0 - 20), Palette.PLUM, 15, Palette.PAPER)
	elif _bx(hi) - _bx(lo) >= 66:
		s._text("just right", Vector2(_bx((lo + hi) * 0.5), mid), 12, Stage2D.INK, 700)
	# the plateau run so far
	var run := ClinicRules.plateau_run(records)
	if int(run["steps"]) >= 1:
		var ry := _by(int(run["db"]))
		var x0 := _bx(int(run["start_mask"]))
		var x1 := _bx(int(run["start_mask"]) + int(run["steps"]) * ClinicRules.MASK_STEP_DB)
		var gold := int(run["steps"]) >= ClinicRules.PLATEAU_STEPS
		s.draw_line(Vector2(x0 - 12, ry), Vector2(x1 + 12, ry), Color(Stage2D.GOLD, 0.9 if gold else 0.45), 16.0, true)
		if gold:
			s._chip("PLATEAU %d dB" % int(run["db"]), Vector2((x0 + x1) * 0.5, ry - 34), Stage2D.GOLD, 16, Stage2D.INK, _pop(step_at))
	# the presentations: filled = heard, hollow = missed, joined in order
	var pts := PackedVector2Array()
	for r: Dictionary in records:
		pts.append(Vector2(_bx(int(r["mask_db"])), _by(int(r["db"]))))
	if pts.size() > 1:
		s.draw_polyline(pts, Color(Stage2D.INK, 0.45), 2.5, true)
	for i in records.size():
		var r: Dictionary = records[i]
		var c := pts[i]
		var newest := i == records.size() - 1
		var rad := 9.0 + (_ring(step_at, 4.0, 10.0, 4.0) if newest else 0.0)
		if bool(r["responded"]):
			s._circ(c, rad, Palette.MINT, 3.0)
		else:
			s.draw_circle(c, rad, Palette.PAPER, true, -1.0, true)
			s.draw_arc(c, rad, 0.0, TAU, 24, Palette.CORAL, 3.5, true)
	var verdict := String(params.get("verdict", ""))
	if verdict != "" and reveal:
		s._chip(verdict, Vector2(MINI_AT.x, 26), Palette.SUNNY, 18, Stage2D.INK, _pop(float(params.get("verdict_at", 0.0))))
