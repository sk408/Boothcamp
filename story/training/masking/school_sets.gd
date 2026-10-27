extends "res://story/explainers/explainer_sets.gd"
## SchoolSets (training, story-internal): the Masking School's boards, drawn on Hoot's movie stage
## through its sets hook (CONTRACTS.md §3.4), so the trainer looks like the Cross-Hearing Ghost movie:
## the same head, Righty (the test ear, red) and Lefty (blue), the skull wall and its toll sign.
## The trainer sets the stage's `t` and these params every frame (a pure function of both):
##   who_heard: transducer ("phones", "inserts", "bone"), tone, test_thr, other_thr (dB),
##     reveal (bool: draw who hears it), live (bool: "Try it": the answer follows the beep as it moves),
##     boo_at (stage time the Ghost popped up, or -1), verdict ("" or the callout).

const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const SETS: Array[StringName] = [&"who_heard"]

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
	var at := Stage2D.CUP_R_AT + Vector2(22, 0)
	var tube := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		tube.append(at + Vector2(-20.0 - 50.0 * u, 8.0 + 90.0 * u * u))
	s.draw_polyline(tube, Stage2D.INK, 9.0, true)
	s.draw_polyline(tube, TUBE, 4.0, true)
	s._blob(at, Vector2(20, 15), FOAM, 4.0)
	s._text("R", at + Vector2(-2, 1), 16, Palette.RIGHT_RED, 700)
