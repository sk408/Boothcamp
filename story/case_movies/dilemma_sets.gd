extends "res://story/case_movies/case_movie_sets.gd"
## The sets of "Hoot's dilemma movie" (story/explainers/movies/dilemma.gd): Day 2's head with Righty and
## Lefty, a cork in each ear canal (both middle ears stiff), the shhh that has to be loud and crosses
## back, the masking window that turns upside down, the inserts that make room, and Bev's chart with
## its purple ?. Every number comes from the scene's params (the movie file says where they come from).

const SETS: Array[StringName] = [&"dl_open", &"dl_corks", &"dl_loud", &"dl_window", &"dl_inserts", &"dl_question", &"dl_bow"]

const CORK := Color("#c8955a")
const CORK_DARK := Color("#94683a")
const FOAM := Color("#ffc46b")
## The purple ? on a stamp with no room for a plateau.
const QUESTION := Color("#8e5cc4")
## Each cork sits in its ear canal, between the ear and the cochlea.
const RIGHT_CORK_AT := Vector2(234, 308)
const LEFT_CORK_AT := Vector2(646, 308)
## The window chart's noise ruler: RULER_LO..RULER_HI dB EM across RULER_X0..RULER_X1.
const RULER_X0 := 190.0
const RULER_X1 := 790.0
const RULER_LO := 40.0
const RULER_HI := 90.0
const ROW_H := 34.0
## The window chart's rows: Lefty's noise, Righty's noise, where both are fine (the brace's label
## stays clear of the ruler).
const ROW_LEFTY_Y := 140.0
const ROW_RIGHTY_Y := 210.0
const ROW_BOTH_Y := 270.0
## Bev's chart (the "question" scene): the four bone frequencies and the dB range shown.
const CHART := Rect2(190, 74, 520, 290)
const CHART_FREQS: Array[String] = ["500", "1k", "2k", "4k"]
const CHART_TOP := -10.0
const CHART_BOTTOM := 80.0


# ---------------------------------------------------------------- 1. the lead-in

func _set_dl_open() -> void:
	_marquee("HOOT'S DILEMMA MOVIE", "The Masking", "Dilemma", "starring Righty, Lefty and two stubborn corks", _prop_corks)
	var t0 := float(params.get("card_hold", 8.0)) + 0.3
	var k := Stage2D._elastic(_k(t0, t0 + 0.9))
	if k > 0.01:
		s._push(Stage2D._about(Vector2(Stage2D.HEAD_C.x, 424), 0.0, Vector2.ONE * k))
		_cast({"mood": &"worried", "corks": _pop(t0 + 0.7), "r_st": {"pop": _pop(t0 + 0.3, 0.5)}, "l_st": {"pop": _pop(t0 + 0.5, 0.5)}})
		s._head_close()
		s._pop_xf()
	s._hoot(Stage2D.HOOT_AT, 40.0, {"pop": _pop(t0 + 0.6), "mood": &"wave"})


func _prop_corks(at: Vector2) -> void:
	for i in 2:
		var hop := absf(sin(t * 4.0 + i * 1.6)) * 6.0 * s._motion
		_cork(at + Vector2(-18.0 + 36.0 * i, 6.0 - hop), 1.6)


# ---------------------------------------------------------------- 2. two stubborn corks

func _set_dl_corks() -> void:
	var air := int(params.get("air", 55))
	var bone := int(params.get("bone", 10))
	var soft := int(params.get("soft", 30))
	var soft_t := 0.9
	var loud_t := 2.6
	var heard := loud_t + 1.4
	var bone_t := 6.6
	var buzz := t >= bone_t + 0.6 and t < duration - 0.5
	var r_heard := t >= heard and t < heard + 1.8
	var r_arm := 0.6 if buzz else _k(heard, heard + 0.3) * (1.0 - _k(heard + 1.5, heard + 1.8))
	_cast({"jelly": 0.3 if buzz else 0.0, "look": Vector2(-0.8, 0.1), "mood": &"wow" if r_heard or buzz else &"smile",
		"r_mood": &"alert" if r_heard or buzz else &"idle", "l_mood": &"alert" if buzz else &"sleep",
		"r_st": {"arm": r_arm, "squash": _ring(heard, 0.2, 18.0, 6.0) + _ring(bone_t + 0.6, 0.15, 18.0, 6.0)},
		"l_st": {"arm": 0.6 if buzz else 0.0, "squash": _ring(bone_t + 0.6, 0.15, 18.0, 6.0)}})
	s._cup(Stage2D.CUP_R_AT, Palette.RIGHT_RED, "R", _pop(0.3) * (1.0 - _k(6.0, 6.3)), -1.0)
	s._buzzer(_k(bone_t, bone_t + 0.4), 1.0 if buzz else 0.0, 0.0)
	s._head_close()
	_beep_at_cork(soft_t, soft, false)
	_beep_at_cork(loud_t, air, true)
	if not buzz:
		s._zzz(Stage2D.LEFTY_AT + Vector2(-6, -104))
	else:
		s._bzz(Stage2D.RIGHTY_AT + Vector2(0, -44), 58.0, 1.0)
		s._bzz(Stage2D.LEFTY_AT + Vector2(0, -44), 58.0, 1.0)
	s._pointer_label("stiff, like\na cork", Vector2(96, 176), RIGHT_CORK_AT + Vector2(-6, -18), CORK_DARK, _pop(0.6))
	s._pointer_label("this one\ntoo", Vector2(790, 176), LEFT_CORK_AT + Vector2(6, -18), CORK_DARK, _pop(1.0))
	if t < bone_t:
		s._chip("AIR: needs %d dB to get in" % air, Stage2D.CALLOUT_AT, Palette.SUNNY, 19, Stage2D.INK, _pop(heard + 0.2) * (1.0 - _k(bone_t - 0.3, bone_t)))
	else:
		s._chip("BONE: %d dB. The cochleas are fine!" % bone, Stage2D.CALLOUT_AT, Palette.MINT, 19, Stage2D.INK, _pop(bone_t + 1.0))
		s._chip("bone skips the corks", Vector2(440, 70), Palette.PAPER, 15, Stage2D.INK, _pop(bone_t + 1.6))
	s._name_tag("RIGHTY", Stage2D.RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	s._name_tag("LEFTY", Stage2D.LEFTY_AT, Palette.LEFT_BLUE, 1.0)


## A beep from the right cup down the canal to the cork: a soft one bonks off it, a loud one
## squeezes through to Righty (t0 + 1.4).
func _beep_at_cork(t0: float, db: int, through: bool) -> void:
	if t < t0:
		return
	var mouth := Stage2D.CUP_R_AT + Vector2(46, -4)
	var cork_in := RIGHT_CORK_AT + Vector2(-16, 0)
	var big := 0.95 + 0.85 * clampf((db - 30.0) / 40.0, 0.0, 1.0)
	var u1 := _k(t0, t0 + 0.35)
	var u2 := _k(t0 + 0.35, t0 + 0.7)
	if u1 < 1.0:
		s._note(Stage2D._bezier(Stage2D.CUP_R_AT + Vector2(10, -40), Stage2D.CUP_R_AT + Vector2(40, -70), mouth, u1), big, Palette.RIGHT_RED, 0.0, str(db))
	elif u2 < 1.0:
		s._note(mouth.lerp(cork_in, u2), big * 0.8, Palette.RIGHT_RED, 0.0, str(db))
	var hit := t0 + 0.7
	if not through:
		if t >= hit and t < hit + 0.35:
			var sq := 1.0 - _k(hit, hit + 0.35)
			s._push(Stage2D._about(cork_in, 0.0, Vector2(0.5 + 0.5 * sq, 1.3)))
			s._note(cork_in, big * 0.8 * sq, Palette.RIGHT_RED, 0.0)
			s._pop_xf()
		s._bonk(cork_in + Vector2(-2, -8), hit, cork_in + Vector2(-26, 64))
		return
	var u3 := _k(hit, hit + 0.4)
	var u4 := _k(hit + 0.4, hit + 0.7)
	if t >= hit and u3 < 1.0:
		var thin := 1.0 - 0.55 * sin(u3 * PI)
		var p := cork_in.lerp(RIGHT_CORK_AT + Vector2(18, 0), u3)
		s._push(Stage2D._about(p, 0.0, Vector2(thin, 2.0 - thin)))
		s._note(p, big * 0.8, Palette.RIGHT_RED, 0.0)
		s._pop_xf()
	elif u3 >= 1.0 and u4 < 1.0:
		s._note((RIGHT_CORK_AT + Vector2(18, 0)).lerp(Stage2D.RIGHTY_AT + Vector2(-26, -40), u4), big * 0.7, Palette.RIGHT_RED, 0.0)
	if t >= hit and t < hit + 1.6:
		s._loud_lines(Stage2D.CUP_R_AT + Vector2(-26, -100), 40.0)


# ---------------------------------------------------------------- 3. the shhh has to be loud

func _set_dl_loud() -> void:
	var air := int(params.get("air", 55))
	var bone := int(params.get("bone", 10))
	var ia := int(params.get("ia", 40))
	var safety := int(params.get("safety", 10))
	var start := air + safety
	var across := start - ia
	var climb := Stage2D._ease_out(_k(1.2, 3.4))
	var db := lerpf(30.0, float(start), climb)
	var cloud_r := 92.0 * Stage2D._back(_k(1.2, 2.6)) * lerpf(0.8, 1.15, climb)
	var spill := Stage2D._ease_in_out(_k(6.4, 7.8))
	var smother := Stage2D._ease_in_out(_k(7.8, 8.6))
	var drowned := t > 8.4
	_cast({"look": Vector2(lerpf(0.6, -0.6, spill), 0.0), "mood": &"wince" if drowned else &"smile",
		"wall": 1.0, "cloud": cloud_r, "spill": spill,
		"r_mood": &"drown" if drowned else &"alert", "l_mood": &"happy",
		"r_st": {"arm": 0.0, "off": Vector2(0, 3.0 * sin(t * 3.0)) if drowned else Vector2.ZERO},
		"l_st": {"shades": _k(2.6, 3.0), "off": Vector2(sin(t * 7.0) * 6.0, -absf(sin(t * 7.0)) * 6.0) * s._motion if t > 3.0 else Vector2.ZERO}})
	if smother > 0.0:
		s._cloud(Stage2D.RIGHTY_AT + Vector2(-22, -44), 64.0 * smother, {"patchy": 0.0, "alpha": 0.55})
	s._cup(Stage2D.CUP_L_AT, Palette.LEFT_BLUE, "L", _pop(0.6), 1.0)
	s._buzzer(1.0, 1.0 if t < 8.4 else 0.0, 0.0)
	s._head_close()
	if cloud_r > 40.0:
		s._shhh_letters(Stage2D.CLOUD_AT, cloud_r)
	if smother > 0.3:
		s._shhh_letters(Stage2D.RIGHTY_AT + Vector2(-22, -44), 60.0, smother)
	s._dial(Stage2D.DIAL_AT, 50.0, db, _ring(3.4, 4.0, 18.0, 5.0))
	s._chip("%d + %d = %d" % [air, safety, start], Stage2D.MATH_AT, Palette.SUNNY, 22, Stage2D.INK, _pop(3.2))
	s._text("Lefty's air + %d" % safety, Stage2D.MATH_AT + Vector2(0, 36), 15, Stage2D.INK, 700, 5, Palette.PAPER, 0.5, _pop(3.6))
	var sign_k := _pop(5.8, 0.4)
	if sign_k > 0.01:
		s._toll_sign(Stage2D.SIGN_AT, ["AIR: -%d dB" % ia, "headphones: at least"], sign_k, _ring(5.8, 0.18, 9.0, 2.5), Palette.PAPER)
	if spill > 0.0:
		# the noise's tag pays the toll inside the wall (as in Day 2's "too much shhh")
		var front := lerpf(Stage2D.LEFTY_AT.x - 64.0, Stage2D.RIGHTY_AT.x + 10.0, spill)
		var cross_k := clampf((Stage2D.WALL_X + Stage2D.WALL_W * 0.5 - front) / Stage2D.WALL_W, 0.0, 1.0)
		var tag_db := int(round(lerpf(float(start), float(across), cross_k) / 5.0) * 5.0)
		s._chip("shhh %d" % tag_db, Vector2(clampf(front + 10.0, 330.0, 560.0), Stage2D.STREAM_Y - 48.0), Stage2D.NOISE, 19, Palette.PAPER, 1.0)
	if t < 8.6:
		s._chip("Righty hears from %d dB" % bone, Stage2D.CALLOUT_AT, Palette.RIGHT_TINT, 18, Stage2D.INK, _pop(4.2) * (1.0 - _k(8.3, 8.6)))
	else:
		s._sparkles(Stage2D.CALLOUT_AT, 8.7, 8, 90.0, Palette.CORAL)
		s._chip("%d is over %d: Righty is hushed!" % [across, bone], Stage2D.CALLOUT_AT, Palette.CORAL, 20, Palette.PAPER, _pop(8.7))
	if drowned:
		s._text("glub", Stage2D.RIGHTY_AT + Vector2(-62, -104 - 8.0 * sin(t * 4.0)), 20, Stage2D.NOISE_DEEP, 700, 6)
	s._hoot(Stage2D.HOOT_AT, 40.0, {"mood": &"cover" if drowned else &"idle"})
	s._name_tag("RIGHTY", Stage2D.RIGHTY_AT, Palette.RIGHT_RED, 1.0)


# ---------------------------------------------------------------- 4. the window turns upside down

func _set_dl_window() -> void:
	var enough := int(params.get("enough", 65))
	var hushed := int(params.get("hushed", 50))
	_ruler(_pop(0.2))
	s._chip(String(params.get("transducer", "HEADPHONES")), Vector2(440, 74), Palette.SKY, 18, Stage2D.INK, _pop(0.4))
	_row(ROW_LEFTY_Y, "LEFTY", float(enough), Palette.SUNNY, Palette.MINT, "too little: the Ghost!", "enough: busy", _k(1.0, 1.8))
	_row(ROW_RIGHTY_Y, "RIGHTY", float(hushed), Palette.MINT, Palette.CORAL, "safe", "too much: hushed", _k(3.2, 4.0))
	if t > 1.9 and t < 6.4:
		s._ghost(Vector2(_rx(enough) - 46.0, ROW_LEFTY_Y - 52.0 + sin(t * 4.0) * 3.0 * s._motion), 20.0, {"boo": true})
	_window_row(ROW_BOTH_Y, float(enough), float(hushed), _k(7.0, 7.4), 7.6)
	s._hoot(Stage2D.HOOT_AT, 40.0, {"mood": &"gasp" if t > 7.6 else &"idle", "pop": _pop(0.6)})


# ---------------------------------------------------------------- 5. inserts make room

func _set_dl_inserts() -> void:
	var ia_p := int(params.get("ia_phones", 40))
	var ia_i := int(params.get("ia_inserts", 55))
	var air := int(params.get("air", 45))
	var bone := int(params.get("bone", 25))
	var freq := int(params.get("freq", 2000))
	var cut := 6.4
	if t < cut:
		var out := _k(cut - 0.3, cut)
		s._push(Stage2D._about(Vector2(Stage2D.HEAD_C.x, 424), 0.0, Vector2.ONE * (1.0 - out)))
		var thick := Stage2D._back(_k(3.4, 4.0))
		_cast({"mood": &"grin" if t > 4.2 else &"smile", "wall": 1.0, "thick": thick, "r_mood": &"happy" if t > 4.2 else &"idle", "l_mood": &"happy" if t > 4.2 else &"idle"})
		var cups := 1.0 - _k(0.4, 0.7)
		s._cup(Stage2D.CUP_R_AT, Palette.RIGHT_RED, "R", cups, -1.0)
		s._cup(Stage2D.CUP_L_AT, Palette.LEFT_BLUE, "L", cups, 1.0)
		_insert(-1.0, _k(0.9, 1.8), _k(1.8, 2.2))
		_insert(1.0, _k(1.1, 2.0), _k(2.0, 2.4))
		s._head_close()
		var flip := _k(3.6, 4.1)
		if flip < 0.5:
			s._toll_sign(Stage2D.SIGN_AT, ["AIR: -%d dB" % ia_p, "headphones: at least"], 1.0, 0.0, Palette.PAPER, cos(flip * PI))
		else:
			s._toll_sign(Stage2D.SIGN_AT, ["AIR: -%d dB" % ia_i, "inserts: at least"], 1.0, _ring(4.1, 0.12, 9.0, 3.0), Palette.SKY, -cos(flip * PI))
		s._chip("foam tips seal deep", Stage2D.CALLOUT_AT, Palette.PAPER, 18, Stage2D.INK, _pop(2.2) * (1.0 - out))
		s._pop_xf()
		return
	var enough := air + 10
	var slide := Stage2D._ease_in_out(_k(9.4, 10.4))
	var hushed := lerpf(float(bone + ia_p), float(bone + ia_i), slide)
	var k := _pop(cut, 0.4)
	_ruler(k)
	s._chip("%s Hz: %s" % [str(freq), "HEADPHONES" if slide < 0.5 else "INSERTS"], Vector2(440, 74), Palette.SKY, 18, Stage2D.INK, k)
	_row(ROW_LEFTY_Y, "LEFTY", float(enough), Palette.SUNNY, Palette.MINT, "too little", "enough", k)
	_row(ROW_RIGHTY_Y, "RIGHTY", hushed, Palette.MINT, Palette.CORAL, "safe", "hushed", k)
	_window_row(ROW_BOTH_Y, float(enough), hushed, k, 99.0)
	if slide > 0.0 and slide < 1.0:
		s._chip("+%d" % (ia_i - ia_p), Vector2(_rx(hushed) + 10.0, ROW_RIGHTY_Y - 46.0), Palette.SKY, 18, Stage2D.INK, 1.0)
	if t > 10.6:
		s._sparkles(Vector2(_rx(enough + 10.0), ROW_BOTH_Y), 10.6, 10, 80.0, Palette.MINT)
	s._hoot(Stage2D.HOOT_AT, 40.0, {"mood": &"cheer" if t > 10.6 else &"idle", "pop": k})


# ---------------------------------------------------------------- 6. the purple ?

func _set_dl_question() -> void:
	var air: Array = params.get("air", [55, 55, 45, 35])
	var bone: Array = params.get("bone", [10, 10, 25, 15])
	var room: Array = params.get("room", [false, false, true, true])
	var k := _pop(0.1, 0.5)
	if k <= 0.01:
		return
	s._push(Stage2D._about(CHART.get_center(), 0.0, Vector2.ONE * k))
	s._rbox(Rect2(CHART.position + Vector2(0, 6), CHART.size), Color(Stage2D.INK, 0.18), 14, 0)
	s._rbox(CHART, Stage2D.GRAPH_BG, 14, 4)
	var db := CHART_TOP
	while db <= CHART_BOTTOM:
		var y := _cy(db)
		s.draw_line(Vector2(CHART.position.x + 12, y), Vector2(CHART.end.x - 12, y), Color(Stage2D.INK, 0.12 if int(db) % 20 != 0 else 0.22), 2.0, true)
		if int(db) % 20 == 0:
			s._text(str(int(db)), Vector2(CHART.position.x - 22, y), 14, Palette.INK_SOFT, 600)
		db += 10.0
	s.draw_line(Vector2(CHART.position.x + 12, _cy(25.0)), Vector2(CHART.end.x - 12, _cy(25.0)), Color(Palette.MINT.darkened(0.2), 0.5), 3.0, true)
	for i in CHART_FREQS.size():
		var x := _cx(i)
		s._text(CHART_FREQS[i], Vector2(x, CHART.end.y + 18), 16, Stage2D.INK, 700)
		var ay := _cy(float(air[i]))
		s.draw_arc(Vector2(x - 12, ay), 9.0, 0.0, TAU, 18, Palette.RIGHT_RED, 4.0, true)
		s.draw_line(Vector2(x + 4, ay - 9), Vector2(x + 22, ay + 9), Palette.LEFT_BLUE, 4.0, true)
		s.draw_line(Vector2(x + 22, ay - 9), Vector2(x + 4, ay + 9), Palette.LEFT_BLUE, 4.0, true)
		var by := _cy(float(bone[i]))
		_bracket(Vector2(x - 34, by), 1.0, Palette.RIGHT_RED)
		_bracket(Vector2(x + 34, by), -1.0, Palette.LEFT_BLUE)
		if bool(room[i]):
			var tk := _pop(1.4 + 0.4 * (i - 2), 0.35)
			s._chip("plateau", Vector2(x, by - 34), Palette.MINT, 13, Stage2D.INK, tk)
		else:
			var qk := _pop(3.6 + 0.4 * i, 0.35)
			for sd: float in [-1.0, 1.0]:
				s._text("?", Vector2(x + sd * 34.0, by - 30.0 - 4.0 * sin(t * 4.0 + i) * s._motion), 30, QUESTION, 700, 6, Palette.PAPER, 0.5, qk)
	s._pop_xf()
	s._chip("O X air    [ ] masked bone", Stage2D.CALLOUT_AT, Palette.PAPER, 15, Stage2D.INK, _pop(0.4))
	s._chip("the test's limit, not her ears'", Vector2(440, 412), QUESTION, 18, Palette.PAPER, _pop(5.8))
	s._hoot(Stage2D.HOOT_AT, 40.0, {"mood": &"idle", "pop": _pop(0.6)})


# ---------------------------------------------------------------- 7. the curtain call

func _set_dl_bow() -> void:
	_curtain_call(_bow_cast, false)


func _bow_cast(bow: float) -> void:
	for i in 2:
		var at := Vector2(320.0 + 240.0 * i, 350.0)
		var dir := 1.0 if i == 0 else -1.0
		s._snail(at, dir, Palette.RIGHT_RED if i == 0 else Palette.LEFT_BLUE, Stage2D.RIGHTY_BODY if i == 0 else Stage2D.LEFTY_BODY,
			{"mood": &"happy", "tilt": bow * 0.35, "arm": 0.8})
		var hand := at + Vector2(dir * 112.0, -60.0 + bow * 20.0)
		s._rbox(Rect2(hand - Vector2(9, 12), Vector2(18, 24)), FOAM, 8, 3)


# ---------------------------------------------------------------- shared drawing

## Day 2's head with both cochleas and a cork in each ear canal; the caller draws its cups, clouds and
## buzzer, then calls s._head_close(). o: jelly, look, mood (the face), corks (their pop-in, 0..1),
## wall (0..1), thick (the inserts' second layer of bricks), cloud (Lefty's shhh radius), spill (the
## overmasking stream, 0..1), r_mood / l_mood and r_st / l_st (more snail state).
func _cast(o: Dictionary) -> void:
	s._head_open(float(o.get("jelly", 0.0)))
	s._head({"look": o.get("look", Vector2.ZERO), "mood": o.get("mood", &"smile")})
	var wall := float(o.get("wall", 0.0))
	if wall > 0.0:
		var thick := float(o.get("thick", 0.0))
		if thick > 0.01:
			for sd: float in [-1.0, 1.0]:
				s._push(Stage2D._xform(Vector2(sd * Stage2D.WALL_W * 0.5 * thick, 0)))
				s._wall(wall, 1.0, false)
				s._pop_xf()
		s._wall(wall, 1.0, false)
	var cloud := float(o.get("cloud", 0.0))
	if cloud > 4.0:
		s._cloud(Stage2D.CLOUD_AT, cloud, {"patchy": 0.0})
	var spill := float(o.get("spill", 0.0))
	if spill > 0.0:
		s._cloud_stream(spill)
	var ck := float(o.get("corks", 1.0))
	_cork(RIGHT_CORK_AT, ck)
	_cork(LEFT_CORK_AT, ck)
	var rs: Dictionary = {"mood": o.get("r_mood", &"idle"), "look": Vector2(-1, -0.1)}
	rs.merge(o.get("r_st", {}), true)
	var ls: Dictionary = {"mood": o.get("l_mood", &"idle"), "look": Vector2(1, -0.1)}
	ls.merge(o.get("l_st", {}), true)
	s._snail(Stage2D.RIGHTY_AT, 1.0, Palette.RIGHT_RED, Stage2D.RIGHTY_BODY, rs)
	s._snail(Stage2D.LEFTY_AT, -1.0, Palette.LEFT_BLUE, Stage2D.LEFTY_BODY, ls)


## A cork stuck in an ear canal (a stiff middle ear).
func _cork(at: Vector2, k: float) -> void:
	if k <= 0.01:
		return
	s._push(Stage2D._about(at, 0.0, Vector2.ONE * k))
	s._rbox(Rect2(at - Vector2(11, 14), Vector2(22, 28)), CORK, 6, 3)
	for i in 3:
		s.draw_circle(at + Vector2(-5.0 + 5.0 * i, -6.0 + 7.0 * (i % 2)), 1.8, CORK_DARK, true, -1.0, true)
	s._pop_xf()


## A foam insert earphone sliding into an ear canal (side -1: her right ear, on the screen's left).
## k: how far in (0 outside, 1 seated), puff: the foam swelling to seal.
func _insert(side: float, k: float, puff: float) -> void:
	if k <= 0.0:
		return
	var mouth := Vector2(Stage2D.HEAD_C.x + side * (Stage2D.HEAD_R.x - 18.0), Stage2D.EAR_Y + 4.0)
	var at := (mouth + Vector2(side * 80.0, 0)).lerp(mouth + Vector2(-side * 14.0, 0), Stage2D._ease_out(k))
	var box := mouth + Vector2(side * 70.0, -130.0)
	var tube := PackedVector2Array([at + Vector2(side * 12.0, 0), at + Vector2(side * 46.0, -16.0), box + Vector2(0, 12)])
	s.draw_polyline(tube, Stage2D.INK, 8.0, true)
	s.draw_polyline(tube, Stage2D.BONE_GREY, 4.0, true)
	s._rbox(Rect2(box - Vector2(18, 12), Vector2(36, 24)), Palette.RIGHT_RED if side < 0.0 else Palette.LEFT_BLUE, 8, 3)
	var h := 16.0 * (1.0 + 0.3 * puff)
	s._rbox(Rect2(at - Vector2(13, h * 0.5), Vector2(26, h)), FOAM, 8, 3)


## The window chart's noise ruler.
func _ruler(k: float) -> void:
	if k <= 0.01:
		return
	var y := 360.0
	var col := Color(Stage2D.INK, k)
	s.draw_line(Vector2(RULER_X0, y), Vector2(RULER_X1, y), col, 4.0, true)
	var db := RULER_LO
	while db <= RULER_HI:
		var x := _rx(db)
		s.draw_line(Vector2(x, y - 8), Vector2(x, y + 8), col, 3.0, true)
		s._text(str(int(db)), Vector2(x, y + 22), 15, col, 700)
		db += 10.0
	s._text("noise, dB", Vector2(RULER_X1 + 10.0, y), 14, Color(Palette.INK_SOFT, k), 700, 0, Palette.PAPER, 0.0)


func _rx(db: float) -> float:
	return lerpf(RULER_X0, RULER_X1, (db - RULER_LO) / (RULER_HI - RULER_LO))


## One row of the window chart: the bar from the ruler's low end, below_col under `at` dB and
## above_col from it, growing in from the left with k.
func _row(y: float, label: String, at: float, below_col: Color, above_col: Color, below_txt: String, above_txt: String, k: float) -> void:
	if k <= 0.01:
		return
	var xe := lerpf(RULER_X0, RULER_X1, clampf(k, 0.0, 1.0))
	var xa := clampf(_rx(at), RULER_X0, RULER_X1)
	s._text(label, Vector2(RULER_X0 - 14.0, y), 18, Stage2D.INK, 700, 0, Palette.PAPER, 1.0)
	var x1 := minf(xa, xe)
	if x1 - RULER_X0 > 6.0:
		s._rbox(Rect2(RULER_X0, y - ROW_H * 0.5, x1 - RULER_X0, ROW_H), below_col, 10, 3)
		if xe >= xa:
			s._text(below_txt, Vector2((RULER_X0 + xa) * 0.5, y), 15, Stage2D.INK, 700)
	if xe - xa > 6.0:
		s._rbox(Rect2(xa, y - ROW_H * 0.5, xe - xa, ROW_H), above_col, 10, 3)
		if k >= 1.0:
			s._text(above_txt, Vector2((xa + RULER_X1) * 0.5, y), 15, Stage2D.INK if above_col != Palette.CORAL else Palette.PAPER, 700)
	if xe >= xa:
		s._chip(str(int(round(at))), Vector2(xa, y - ROW_H * 0.5 - 14.0), Palette.PAPER, 14, Stage2D.INK, 1.0)


## The window row: where the shhh is both enough and safe (from `enough` up to 5 below `hushed`). None:
## a NO ROOM! sign (from no_room_t). Room for three 5 dB steps or more: a brace, room for a plateau.
func _window_row(y: float, enough: float, hushed: float, k: float, no_room_t: float) -> void:
	if k <= 0.01:
		return
	s._text("BOTH OK?", Vector2(RULER_X0 - 14.0, y), 18, Stage2D.INK, 700, 0, Palette.PAPER, 1.0)
	var top := hushed - 5.0
	if top < enough:
		var dash := Rect2(RULER_X0, y - ROW_H * 0.5, RULER_X1 - RULER_X0, ROW_H)
		s.draw_dashed_line(dash.position, Vector2(dash.end.x, dash.position.y), Color(Stage2D.INK, 0.4 * k), 3.0, 10.0)
		s.draw_dashed_line(Vector2(dash.position.x, dash.end.y), dash.end, Color(Stage2D.INK, 0.4 * k), 3.0, 10.0)
		var nk := _pop(no_room_t, 0.45)
		if nk > 0.01:
			s._big_sign("NO ROOM!", Vector2(490, y), nk, sin(t * 6.0) * 0.06 * s._motion)
		return
	var x0 := _rx(enough)
	var x1 := maxf(_rx(top), x0 + 14.0)
	s._rbox(Rect2(x0, y - ROW_H * 0.5, (x1 - x0) * k, ROW_H), Palette.MINT, 10, 3)
	var steps := int((top - enough) / 5.0)
	if steps >= 3:
		s._brace(Vector2(x0, y + ROW_H * 0.5 + 2.0), Vector2(x1, y + ROW_H * 0.5 + 2.0), "ROOM FOR A PLATEAU: %d to %d" % [int(enough), int(top)], k)
	else:
		s._text("room for %d step%s" % [steps, "" if steps == 1 else "s"], Vector2(x1 + 12.0, y), 15, Stage2D.INK, 700, 5, Palette.PAPER, 0.0, k)


## A masked bone bracket: "[" for her right ear (open side right, dir 1), "]" for her left (dir -1).
func _bracket(at: Vector2, dir: float, col: Color) -> void:
	var pts := PackedVector2Array([at + Vector2(dir * 8.0, -12), at + Vector2(-dir * 2.0, -12), at + Vector2(-dir * 2.0, 12), at + Vector2(dir * 8.0, 12)])
	s.draw_polyline(pts, col, 4.0, true)


func _cx(i: int) -> float:
	return CHART.position.x + CHART.size.x * (i + 0.5) / CHART_FREQS.size()


func _cy(db: float) -> float:
	return CHART.position.y + 18.0 + (db - CHART_TOP) / (CHART_BOTTOM - CHART_TOP) * (CHART.size.y - 36.0)
