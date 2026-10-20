extends Control
## ExplainerStage (v4, story-internal): draws and animates one scene "set" of a Hoot movie
## (story/explainers/movies/*.gd) on the cinema screen. The player calls show_scene(scene) when a
## scene starts and sets `t` (seconds into the scene) every frame; the stage redraws itself.
## Every drawing is a pure function of `t`, so a paused movie freezes, a screenshot is repeatable
## and a skipped scene leaves nothing behind (no tweens, no nodes, no RNG).
##
## The cast and props (all drawn here, in the game's palette with chunky ink outlines):
##   the big cartoon head seen from the FRONT (her RIGHT is on the screen's LEFT), with a window into
##   the skull; Righty (red snail-shell cochlea) and Lefty (blue); the brick "skull wall" with its toll
##   sign; the red / blue on-ear cups; the beige bone buzzer on its headband; music-note beeps; the
##   Cross-Hearing Ghost (Lefty under a bedsheet); the purple "shhh" noise cloud; the noise dial;
##   the plateau graph; a little Hoot; stage curtains and the title card.
##
## Sets for a new movie, three ways (docs/ADDING_A_CHAPTER.md, "Hoot's movies"):
##  1. the built-in sets below (SETS);
##  2. no code: the generic set "card" draws a chunky title card from DATA (params: heading, lines,
##     line_at, icon, hoot, tint; see _set_card());
##  3. the movie's OWN sets script, in its chapter's files: MOVIE.stage = "res://.../<id>_sets.gd",
##     extending story/explainers/explainer_sets.gd with its own `const SETS` and `_set_<id>()`
##     functions. use_movie() loads it; _draw() hands it any set this stage does not know, with the
##     same t / duration / params and this stage's palette and helpers (its `s`). Nothing here changes.
## A set nobody knows falls back to a card with the scene's title (never a blank screen).
## Built-in sets: a `_set_<id>()` function, its id in SETS and a branch in _draw()'s match. Use
## `_k(a, b)` (0..1 between two scene times), `_pop()`, `_ring()` and the helpers below; read
## numbers from `params`.
## Sounds are not played here: they are the scene's "cues" in the movie data (CONTRACTS.md §1.3:
## "too loud" and "too much noise" are only ever drawn).

const SETS: Array[StringName] = [&"meet", &"air", &"wall", &"bone", &"ghost", &"mask", &"under", &"over", &"plateau", &"outro", &"card"]
## The props the generic "card" set can show beside its lines (params.icon).
const CARD_ICONS: Array[String] = ["", "snails", "ghost", "cloud", "note", "dial", "hoot"]
const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")

const INK := Palette.INK
const NOISE := Color("#8e5cc4")
const NOISE_FILL := Color("#dccbf6")
const NOISE_DEEP := Color("#6d3fa6")
const BONE_GREY := Color("#b9c0cc")
const BUZZ_BEIGE := Color("#ecdfc4")
const BRICK := Color("#dd8f62")
const HAIR := Color("#8a4b2a")
const HAIR_LIGHT := Color("#a8623a")
const SKULL := Color("#fff8ec")
const RIGHTY_BODY := Color("#ffd2c9")
const LEFTY_BODY := Color("#cfe0ff")
const SHEET := Color("#f8f6ff")
const BACKDROP := Color("#2a2140")
const CANAL := Color("#f4a98c")
const CURTAIN := Color("#c4453f")
const CURTAIN_DARK := Color("#9e2f2b")
const GOLD := Color("#f6b73c")
const GRAPH_BG := Color("#fffbf2")

## The head and its insides (stage coordinates; the stage is 880 x 440).
const HEAD_C := Vector2(440, 258)
const HEAD_R := Vector2(256, 166)
const WIN_C := Vector2(440, 302)
const WIN_R := Vector2(226, 106)
const RIGHTY_AT := Vector2(282, 350)   # a snail's origin: the ground under its shell
const LEFTY_AT := Vector2(598, 350)
const WALL_X := 440.0
const WALL_W := 44.0
const WALL_TOP := 214.0
const WALL_BOTTOM := 402.0
const SIGN_AT := Vector2(440, 223)     # the toll sign sits on top of the wall, under her chin
const EAR_Y := 304.0
const CUP_R_AT := Vector2(160, 304)    # her RIGHT ear = the screen's LEFT (she faces you)
const CUP_L_AT := Vector2(720, 304)
const BUZZ_AT := Vector2(212, 372)     # the bony bump behind / below her right ear
const DIAL_AT := Vector2(790, 150)
const HOOT_AT := Vector2(80, 378)
const CLOUD_AT := Vector2(608, 300)    # the shhh cloud around Lefty
const GHOST_AWAY := Vector2(286, 168)  # where the Ghost hovers: just above Righty's nightcap, clear of her eyes
const BOO_AT := Vector2(100, 232)
const CALLOUT_AT := Vector2(440, 32)   # the scene's big one-line callout, top centre
const INSERTS_AT := Vector2(748, 116)
const STREAM_Y := 318.0                # the overmasking spill crosses the wall at this height
const SQUEEZE_Y := 322.0               # a crossing beep squeezes through the wall here, under the sign
const SKULL_C1 := Vector2(232, 210)    # the skull-shake path: from the right ear canal's mouth, over
const SKULL_C2 := Vector2(392, 214)    #   Righty (never out of Righty) to the wall (cubic control points)
const LEFTY_HEARS_AT := Vector2(770, 396)
const MATH_AT := Vector2(784, 236)     # "70 - 40 = 30" beside Lefty
## The toll sign once the bone buzzer is on: bone crosses the skull for (almost) free.
const BONE_SIGN: Array[String] = ["BONE: 0 dB lost", "(really 0-10)"]

var set_id: StringName = &"meet"
var params: Dictionary = {}
var scene_id := ""
## Optional "title" of the scene (the little clapper chip top-left) and its 1-based number.
var scene_title := ""
var scene_no := 0
## Seconds since the scene started (the player sets it every frame).
var t := 0.0
var duration := 1.0

var _xf := Transform2D.IDENTITY
var _xf_stack: Array[Transform2D] = []
var _motion := 1.0   # 1 = full motion; smaller with the reduced-motion setting
var _box_cache: Dictionary = {}
## (v4 hook) The playing movie's own sets (MOVIE.stage, an explainer_sets.gd), or null.
var _movie_sets: RefCounted = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


## The player calls this when a movie starts: load the movie's own sets script (MOVIE.stage), if any.
func use_movie(m: Dictionary) -> void:
	_movie_sets = load_sets(String(m.get("stage", "")))


## A movie's sets script (MOVIE.stage) as a fresh object, or null when there is none or it is not an
## explainer_sets.gd (Movies.validate() reports that).
static func load_sets(path: String) -> RefCounted:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var sc := load(path) as GDScript
	if sc == null or not sc.can_instantiate():
		return null
	var o: Variant = sc.new()
	if o is RefCounted and (o as Object).has_method("draw_set") and (o as Object).has_method("set_ids"):
		return o as RefCounted
	return null


## The movie's own set ids ([] without a sets script).
func movie_set_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	if _movie_sets != null:
		out.assign(_movie_sets.call("set_ids"))
	return out


func show_scene(scene: Dictionary) -> void:
	set_id = StringName(String(scene.get("set", "meet")))
	params = scene.get("params", {})
	scene_id = String(scene.get("id", ""))
	scene_title = String(scene.get("title", ""))
	duration = maxf(0.1, float(scene.get("duration", 1.0)))
	t = 0.0
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_motion = 0.35 if bool(Game.settings.get("reduced_motion", false)) else 1.0
	_xf_stack.clear()
	_xf = Transform2D.IDENTITY
	draw_set_transform_matrix(_xf)
	_screen()
	match set_id:
		&"meet":
			_set_meet()
		&"air":
			_set_air()
		&"wall":
			_set_wall()
		&"bone":
			_set_bone()
		&"ghost":
			_set_ghost()
		&"mask":
			_set_mask()
		&"under":
			_set_under()
		&"over":
			_set_over()
		&"plateau":
			_set_plateau()
		&"outro":
			_set_outro()
		_:
			if _movie_sets != null and bool(_movie_sets.call("has_set", set_id)):
				_movie_sets.call("draw_set", self, set_id)   # the movie's own set (MOVIE.stage)
			else:
				_set_card()   # "card", and the fallback for a set nobody knows
	_xf_stack.clear()
	_xf = Transform2D.IDENTITY
	draw_set_transform_matrix(_xf)
	if not _card_scene():
		_iris()
	_scene_chip()
	_frame()
	if OS.is_debug_build() and Game.cli.has("explainer-debug"):
		_text("set %s  t %.1f" % [set_id, t], Vector2(size.x - 90, size.y - 16), 14, Palette.INK_SOFT, 600)


# =============================================================== the ten sets

## 1. meet: curtains open on the title card; the head bounces in; Righty and Lefty pop in and wave.
func _set_meet() -> void:
	# (Steve) the title card holds while Hoot says what the movie is about (params.card_hold, its
	# question chips underneath), then everything below runs as before, card_hold - 2 s later
	var hold := float(params.get("card_hold", 2.0))
	var real_t := t
	var card_out := _k(hold, hold + 0.45)
	if card_out < 1.0:
		_title_card(1.0 - card_out * card_out * card_out, card_out * 0.5)
		var qs: Array = params.get("questions", [])
		for i in qs.size():
			var qk := _pop(2.0 + 2.6 * i, 0.4) * (1.0 - card_out)
			_chip(String(qs[i]), Vector2(240.0 + 400.0 * i, 404.0), Palette.SUNNY if i == 0 else Palette.SKY, 19, INK, qk)
	t = real_t - (hold - 2.0)
	var head_k := _elastic(_k(2.2, 3.1))
	if head_k > 0.01:
		_push(_about(Vector2(HEAD_C.x, 424), 0.0, Vector2(head_k, head_k)))
		_head({"look": Vector2(0, 0.3), "mood": &"smile"})
		var waving := t > 3.4
		_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"pop": _pop(2.6, 0.5), "squash": _ring(2.6, 0.22, 18.0, 6.0),
			"arm": _k(3.4, 3.7), "wave": waving, "mood": &"happy" if t > 3.4 else &"idle", "look": Vector2(1, -0.2)})
		_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"pop": _pop(3.0, 0.5), "squash": _ring(3.0, 0.22, 18.0, 6.0),
			"arm": _k(3.6, 3.9), "wave": waving, "mood": &"happy" if t > 3.6 else &"idle", "look": Vector2(1, -0.2)})
		_pop_xf()
		_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, _pop(2.8))
		_name_tag("LEFTY", LEFTY_AT, Palette.LEFT_BLUE, _pop(3.2))
	_pointer_label("her RIGHT\ncochlea", Vector2(92, 176), RIGHTY_AT + Vector2(-34, -70), Palette.RIGHT_RED, _pop(3.6))
	_pointer_label("her LEFT\ncochlea", Vector2(788, 176), LEFTY_AT + Vector2(34, -70), Palette.LEFT_BLUE, _pop(3.9))
	_chip("She faces you: her right is on YOUR left", CALLOUT_AT, Palette.PAPER, 17, INK, _pop(4.8))
	_hoot(HOOT_AT, 40.0, {"pop": _pop(4.2), "mood": &"wave"})
	t = real_t
	_curtains(_ease_out(_k(0.1, 1.2)))


## 2. air: a red on-ear cup on her right ear; music-note beeps hop down the canal to Righty, who
## rings a little bell. Lefty snoozes.
func _set_air() -> void:
	var launches: Array[float] = [0.9, 2.1, 3.3, 4.5, 5.7, 6.9]
	var hop := 0.7
	var last_hit := -10.0
	for t0: float in launches:
		if t >= t0 + hop:
			last_hit = t0 + hop
	var look := _ease_in_out(_k(0.5, 0.9))
	_head_open(0.0)
	_head({"look": Vector2(-0.9 * look, 0.1), "mood": &"smile"})
	var heard := t - last_hit < 0.7
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"alert" if heard else &"idle", "arm": _k(1.6, 2.0),
		"bell": true, "ring": heard, "squash": _ring(last_hit, 0.12, 20.0, 7.0), "look": Vector2(-1, -0.2)})
	_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"sleep"})
	_cup(CUP_R_AT, Palette.RIGHT_RED, "R", _pop(0.4), -1.0)
	_head_close()
	_zzz(LEFTY_AT + Vector2(-6, -104))
	for t0: float in launches:
		var k := _k(t0, t0 + hop)
		if t >= t0 and k < 1.0:
			# a low hop down the ear canal into Righty's shell
			var p := _bezier(CUP_R_AT + Vector2(26, -6), Vector2(222, 258), RIGHTY_AT + Vector2(-22, -40), k)
			_note(p, 1.45 * _pop(t0, 0.2), Palette.RIGHT_RED, sin(t * 9.0) * 0.2)
		if t >= t0 and t < t0 + 0.6:
			var bk := _k(t0, t0 + 0.6)
			var fade := 1.0 - bk * bk
			_text("beep!", CUP_R_AT + Vector2(-30, -80 - 24.0 * bk), 22, Color(Palette.RIGHT_RED.darkened(0.2), fade), 700, 7, Color(Palette.PAPER, fade))
	if heard:
		var dk := clampf(1.4 - (t - last_hit) * 2.0, 0.0, 1.0)
		_text("ding!", RIGHTY_AT + Vector2(158, -118), 24, Color(GOLD.darkened(0.3), dk), 700, 7, Color(Palette.PAPER, dk))
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	_name_tag("LEFTY", LEFTY_AT, Palette.LEFT_BLUE, 1.0)
	_chip("earphone: ONE ear", CUP_R_AT + Vector2(-4, -132), Palette.RIGHT_TINT, 16, INK, _pop(1.2))


## 3. wall: the brick skull wall grows between them with its "-40 dB" toll sign. Every beep goes into
## Righty's ear AND shakes the skull: a skull-shake note runs from the cup along the skull, OVER
## Righty (the test cochlea never passes the sound on), to the wall. Soft ones lose 40 dB there and
## fizzle (below Lefty's threshold); the LOUD one (drawn big, the sound stays soft) squeezes through
## under the sign, counts down 70 -> 30 on a big chip and wakes Lefty: cross-hearing. A
## "70 - 40 = 30" chip holds beside Lefty while he wakes.
func _set_wall() -> void:
	var levels: Array = params.get("levels", [30, 35, 70])
	var ia := int(params.get("ia", 40))
	var lefty_hears := int(params.get("lefty_hears", 5))
	var shots: Array[float] = [2.4, 3.7, 5.7]
	var into := 0.3        # cup -> the ear canal's mouth
	var skull := 0.7       # the canal's mouth -> the wall, along the skull over Righty
	var squeeze := 0.6     # through the wall (the loud one)
	var cross := 7.8       # the loud beep reaches Lefty
	var mouth := CUP_R_AT + Vector2(46, -4)
	var wall_in := Vector2(WALL_X - WALL_W * 0.5 - 16.0, SQUEEZE_Y)
	_head_open(0.0)
	var look_x := -0.8
	if t > 6.6:
		look_x = lerpf(-0.8, 0.9, _ease_in_out(_k(6.6, 7.6)))
	_head({"look": Vector2(look_x, 0.1), "mood": &"wow" if t > cross else &"smile"})
	var grow := _back(_k(0.3, 1.1))
	_wall(grow, 1.0, false)
	if grow > 0.98:
		_dust(Vector2(WALL_X, WALL_BOTTOM - 4), 1.1)
	var r_hit := -10.0
	for s: float in shots:
		if t >= s + into + 0.35:
			r_hit = s + into + 0.35
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"alert" if t - r_hit < 0.6 else &"idle", "squash": _ring(r_hit, 0.12, 20.0, 7.0), "look": Vector2(-1, -0.1)})
	var lefty_up := t >= cross
	_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"alert" if lefty_up else &"sleep", "arm": _k(cross + 0.2, cross + 0.5),
		"squash": _ring(cross, 0.25, 18.0, 5.0), "look": Vector2(1, -0.3)})
	_cup(CUP_R_AT, Palette.RIGHT_RED, "R", 1.0, -1.0)
	_head_close()
	if not lefty_up:
		_zzz(LEFTY_AT + Vector2(-6, -104))
	else:
		_text("!", LEFTY_AT + Vector2(-26, -122 - 8.0 * _pop(cross)), 38, Palette.LEFT_BLUE, 700, 7)
	# Lefty's own threshold: what a crossed beep must reach
	_chip("Lefty hears from %d dB" % lefty_hears, LEFTY_HEARS_AT, Palette.LEFT_TINT, 15, INK, _pop(1.8))
	# the level meter on the cup
	var lvl_i := -1
	for i in shots.size():
		if t >= shots[i] - 0.4:
			lvl_i = i
	if lvl_i >= 0:
		var loud := lvl_i == shots.size() - 1
		_chip("%d dB" % int(levels[mini(lvl_i, levels.size() - 1)]), CUP_R_AT + Vector2(-26, -100), Palette.CORAL if loud else Palette.SUNNY,
			26 if loud else 20, INK, _pop(shots[lvl_i] - 0.4, 0.35))
		if loud and t < cross + 1.0:
			_loud_lines(CUP_R_AT + Vector2(-26, -100), 70.0)
	# the beeps
	for i in shots.size():
		var t0: float = shots[i]
		var lv := int(levels[mini(i, levels.size() - 1)])
		var big := 0.95 + 0.85 * clampf((lv - 30.0) / 40.0, 0.0, 1.0)
		var out := lv - ia
		var to_mouth := _k(t0, t0 + into)
		if t >= t0 and to_mouth < 1.0:
			_note(_bezier(CUP_R_AT + Vector2(10, -40), CUP_R_AT + Vector2(40, -70), mouth, to_mouth), big, Palette.RIGHT_RED, 0.0, str(lv))
		# into Righty's ear: the test ear hears it
		var ear_k := _k(t0 + into, t0 + into + 0.35)
		if to_mouth >= 1.0 and ear_k < 1.0:
			_note(mouth.lerp(RIGHTY_AT + Vector2(-26, -40), ear_k), big * 0.75, Palette.RIGHT_RED, 0.0)
		# and the skull shake: along the skull, over Righty, to the wall
		var sk := _k(t0 + into, t0 + into + skull)
		if to_mouth >= 1.0 and sk < 1.0:
			for d in 9:
				var u := sk * d / 8.0
				draw_circle(_cubic(mouth, SKULL_C1, SKULL_C2, wall_in, u), 3.5, Color(Palette.CORAL, 0.25 + 0.4 * d / 8.0), true, -1.0, true)
			# its level tag only over Righty: near the wall it would sit on the toll sign
			_note(_cubic(mouth, SKULL_C1, SKULL_C2, wall_in, sk), big * 0.9, Palette.RIGHT_RED, sin(t * 14.0) * 0.15, str(lv) if sk < 0.5 else "")
		var hit := t0 + into + skull
		if i < shots.size() - 1:
			# a soft one: squish and bonk on the wall; a faint wisp on the other side, too soft for Lefty
			if t >= hit and t < hit + 0.35:
				var sq := 1.0 - _k(hit, hit + 0.35)
				_push(_about(wall_in + Vector2(-6, 0), 0.0, Vector2(0.5 + 0.5 * sq, 1.3)))
				_note(wall_in + Vector2(-6, 0), big * 0.9 * sq, Palette.RIGHT_RED, 0.0)
				_pop_xf()
			_bonk(wall_in + Vector2(-2, -8), hit, Vector2(WALL_X - 70, SQUEEZE_Y + 46))
			if t >= hit:
				var w := _k(hit, hit + 1.1)
				if w < 1.0:
					var wp := Vector2(WALL_X + 40 + 8.0 * w, SQUEEZE_Y - 26.0 * w)
					_note(wp, 0.5, Color(Palette.RIGHT_RED, 0.65 * (1.0 - w)), 0.0)
					draw_circle(wp + Vector2(-8, 14), 9.0 * (1.0 - w) + 2.0, Color(Palette.PAPER.darkened(0.1), 1.0 - w), true, -1.0, true)
					# under the snails, clear of Lefty's face and the wall
					_text("%d - %d: fizzle!" % [lv, ia], Vector2(WALL_X + 90, SQUEEZE_Y + 70), 17, Color(INK, 1.0 - w), 700, 5, Color(Palette.PAPER, 1.0 - w))
		else:
			# the LOUD one squeezes through under the sign, 40 dB smaller: a big countdown chip
			var sq_k := _k(hit, hit + squeeze)
			if t >= hit and sq_k < 1.0:
				var nx := lerpf(wall_in.x, WALL_X + 30, sq_k)
				var thin := 1.0 - 0.55 * sin(sq_k * PI)
				_push(_about(Vector2(nx, SQUEEZE_Y), 0.0, Vector2(thin, 2.0 - thin)))
				_note(Vector2(nx, SQUEEZE_Y), lerpf(big * 0.9, 0.95, sq_k), Palette.RIGHT_RED, 0.0)
				_pop_xf()
			if t >= hit - 0.1 and t < cross + 0.4:
				var n := int(round(lerpf(lv, out, sq_k) / 5.0) * 5.0)
				_chip("%d" % n, Vector2(WALL_X, SQUEEZE_Y + 50), Palette.CORAL if sq_k < 1.0 else Palette.SUNNY, 24, INK, _pop(hit - 0.1, 0.3))
			var fly := _k(hit + squeeze, cross)
			var from := Vector2(WALL_X + 30, SQUEEZE_Y)
			var to := LEFTY_AT + Vector2(-64, -58)
			if t >= hit + squeeze and t < cross + 0.2:
				var np := from.lerp(to, fly) + Vector2(0, -sin(fly * PI) * 30.0)
				_note(np, 0.95, Palette.RIGHT_RED, sin(t * 10.0) * 0.2)   # its number is the countdown chip
			if t > cross:
				_chip("%d - %d = %d" % [lv, ia, out], MATH_AT, Palette.SUNNY, 24, INK, _pop(cross, 0.4), sin(t * 3.0) * 0.02 * _motion)
				_text("%d is above his %d!" % [out, lefty_hears], MATH_AT + Vector2(0, 38), 15, INK, 700, 5, Palette.PAPER, 0.5, _pop(cross + 0.5))
	# the toll sign (on top: a skull-shake note passes BEHIND it), and the inserts tag up in the corner
	var sign_k := _pop(1.2, 0.4)
	if sign_k > 0.01:
		_toll_sign(SIGN_AT, ["-%d dB" % ia, "on-ear phones: at least"], sign_k, _ring(1.2, 0.18, 9.0, 2.5), Palette.PAPER)
	var ins_k := _pop(2.0)
	if ins_k > 0.01:
		_dashed_curve(INSERTS_AT + Vector2(-70, 14), Vector2(600, 196), SIGN_AT + Vector2(80, -4), Palette.INK_SOFT, _k(2.0, 2.5))
		_chip("inserts: -%d dB or more" % int(params.get("inserts_ia", 55)), INSERTS_AT, Palette.SKY, 17, INK, ins_k)
	if t > cross + 0.6:
		# the burst first, so its stars fly out from BEHIND the words
		_sparkles(CALLOUT_AT, cross + 0.6, 10, 110.0, Palette.SUNNY)
		_chip("cross-hearing!", CALLOUT_AT, Palette.SUNNY, 22, INK, _pop(cross + 0.6), sin(t * 3.0) * 0.03 * _motion)
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	_name_tag("LEFTY", LEFTY_AT, Palette.LEFT_BLUE, 1.0)


## 4. bone: the cup pops off, the buzzer clicks onto the bump behind her right ear and the WHOLE head
## jiggles like jelly: both snails buzz the same. The toll sign flips to "0 dB lost", bricks see-through.
func _set_bone() -> void:
	var buzz := _k(1.4, 1.9)
	var flip := _k(5.0, 5.5)
	var see := _ease_in_out(_k(5.2, 5.9))
	_head_open(buzz)
	_head({"look": Vector2(sin(t * 7.0) * 0.4 * buzz, 0.1), "mood": &"wobble" if buzz > 0.0 else &"smile"})
	_wall(1.0, 1.0 - 0.72 * see, see > 0.5)
	var shake := Vector2(sin(t * 61.0), cos(t * 53.0)) * 2.4 * buzz * _motion
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"alert" if t > 1.8 else &"idle", "off": shake, "look": Vector2(0.4, -0.5)})
	_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"alert" if t > 1.8 else &"idle", "off": shake, "look": Vector2(0.4, -0.5)})
	var off_k := _k(0.15, 0.75)
	if off_k < 1.0:
		_push(_about(CUP_R_AT, -off_k * 2.2, Vector2.ONE * (1.0 - off_k * 0.6)))
		_cup(CUP_R_AT + Vector2(-140.0 * off_k, -120.0 * off_k + 160.0 * off_k * off_k), Palette.RIGHT_RED, "R", 1.0 - off_k * off_k, -1.0)
		_pop_xf()
	_buzzer(_pop(0.5, 0.35), buzz, _ring(0.5, 0.2, 22.0, 7.0))
	_head_close()
	if buzz > 0.0:
		_bzz(RIGHTY_AT + Vector2(0, -44), 56.0, buzz)
		_bzz(LEFTY_AT + Vector2(0, -44), 56.0, buzz)
		_text("bzz", BUZZ_AT + Vector2(-46, 34), 18, Color(INK, buzz), 700, 5)
		var spots: Array[Vector2] = [RIGHTY_AT, LEFTY_AT]
		var cols: Array[Color] = [Palette.RIGHT_RED, Palette.LEFT_BLUE]
		for i in 2:
			var jig := Vector2(sin(t * 47.0 + i), cos(t * 39.0 + i)) * 2.0 * _motion
			_text("bzz!", spots[i] + Vector2(0, -118) + jig, 20, Color(cols[i].darkened(0.2), buzz), 700, 6, Color(Palette.PAPER, buzz), 0.5, _pop(1.6 + 0.15 * i))
	if flip < 0.5:
		_toll_sign(SIGN_AT, ["-40 dB", "on-ear phones: at least"], 1.0, 0.0, Palette.PAPER, cos(flip * PI))
	else:
		_toll_sign(SIGN_AT, BONE_SIGN, 1.0, _ring(5.5, 0.12, 9.0, 3.0), Palette.MINT, -cos(flip * PI))
	if t > 5.5:
		_sparkles(SIGN_AT, 5.5, 8, 70.0, Palette.SUNNY)
	_chip("SAME buzz in both!", CALLOUT_AT, Palette.SUNNY, 20, INK, _pop(6.4))
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	_name_tag("LEFTY", LEFTY_AT, Palette.LEFT_BLUE, 1.0)


## 5. ghost: Righty (the poorer ear today) snoozes in a nightcap through a soft buzz. Lefty hears
## it, pulls a bedsheet over itself, floats over to Righty's side and waves "I HEARD IT!": BOO!
func _set_ghost() -> void:
	var buzz_on := t >= 1.2 and t < 2.6
	var drop := _k(2.4, 3.1)
	var landed := t >= 3.1
	var float_k := _ease_in_out(_k(3.3, 4.4))
	var home := LEFTY_AT + Vector2(0, -44)
	_head_open(0.3 if buzz_on else 0.0)
	_head({"look": Vector2(lerpf(0.6, -0.7, float_k), -0.2), "mood": &"wow" if t > 4.5 else &"smile"})
	_wall(1.0, 0.28, true)
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"sleep", "cap": _pop(0.3, 0.4), "squash": _ring(0.6, 0.15, 16.0, 6.0)})
	if not landed:
		_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"alert" if t > 1.5 else &"idle", "arm": _k(1.6, 1.9), "look": Vector2(1, -0.4)})
	else:
		_footprint(LEFTY_AT, Palette.LEFT_BLUE, _k(4.0, 4.6))
	_buzzer(1.0, 1.0 if buzz_on else 0.0, 0.0)
	_head_close()
	if buzz_on:
		_bzz(RIGHTY_AT + Vector2(0, -44), 52.0, 0.6)
		_bzz(LEFTY_AT + Vector2(0, -44), 52.0, 0.6)
		_text("soft bzz", BUZZ_AT + Vector2(-58, 34), 16, INK, 700, 5)
	_zzz(RIGHTY_AT + Vector2(-60, -66))
	_toll_sign(SIGN_AT, BONE_SIGN, 1.0, 0.0, Palette.MINT)
	_chip("poorer ear today", RIGHTY_AT + Vector2(-4, 54), Palette.RIGHT_TINT, 15, INK, _pop(0.7))
	if t > 1.5 and not landed:
		_text("!", LEFTY_AT + Vector2(-26, -122), 38, Palette.LEFT_BLUE, 700, 7)
	# the bedsheet flutters down onto Lefty, then the Ghost floats across
	if drop > 0.0 and not landed:
		var sy := lerpf(-70.0, home.y, _ease_in_out(drop))
		_ghost(Vector2(home.x, sy), 46.0, {"flutter": 1.0 - drop, "empty": true})
	if landed:
		var gp := home.lerp(GHOST_AWAY, float_k) + Vector2(0, -sin(float_k * PI) * 70.0 + sin(t * 3.0) * 5.0 * _motion)
		var sq := _ring(3.1, 0.25, 16.0, 5.0)
		_ghost(gp, 46.0, {"squash": sq, "flag": _k(4.3, 4.6), "flag_dir": -1.0, "boo": t > 4.5})
		if t > 4.6:
			_boo_bubble(BOO_AT, _pop(4.6, 0.4), gp + Vector2(-40, 10))
			_sparkles(BOO_AT, 4.6, 10, 80.0, Palette.SUNNY)
		if t > 5.8:
			_dashed_curve(CALLOUT_AT + Vector2(-80, 14), Vector2(330, 80), gp + Vector2(10, -66), Palette.LEFT_BLUE, _k(6.0, 6.5))
			_chip("it's LEFTY under there!", CALLOUT_AT, Palette.LEFT_TINT, 19, INK, _pop(6.0))
	_hoot(HOOT_AT, 40.0, {"mood": &"gasp" if t > 4.6 else &"idle", "squash": _ring(4.6, 0.2, 18.0, 5.0)})
	if t > 4.6:
		_text("!!", HOOT_AT + Vector2(42, -42), 26, Palette.CORAL, 700, 6)
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)


## 6. mask: a blue cup on her LEFT ear fills Lefty's corner with a "shhh" cloud. The Ghost is pulled
## home, the sheet slides off and Lefty dances in sunglasses, busy. The buzz comes again and Righty
## answers ALL BY ITSELF.
func _set_mask() -> void:
	var cloud_k := _back(_k(1.0, 1.8))
	var back_k := _ease_in_out(_k(1.3, 2.2))
	var sheet_off := _k(2.2, 2.9)
	var shades := _k(2.7, 3.1)
	var dancing := t > 3.1
	var buzz_on := t >= 4.6 and t < 6.6
	var answered := t >= 6.4
	var home := LEFTY_AT + Vector2(0, -44)
	_head_open(0.3 if buzz_on else 0.0)
	_head({"look": Vector2(0.6 if t < 4.5 else -0.6, 0.0), "mood": &"smile"})
	_wall(1.0, 0.28, true)
	if cloud_k > 0.01:
		_cloud(CLOUD_AT, 92.0 * cloud_k, {"patchy": 0.0})
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"alert" if answered else &"sleep", "cap": 1.0 - _k(6.4, 6.6),
		"arm": _k(6.4, 6.7), "squash": _ring(6.4, 0.25, 18.0, 5.0), "look": Vector2(0.3, -0.5)})
	if back_k >= 1.0 and sheet_off > 0.0:
		var dance := Vector2(sin(t * 7.0) * 8.0, -absf(sin(t * 7.0)) * 8.0) * _motion if dancing else Vector2.ZERO
		_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"happy" if dancing else &"idle", "shades": shades,
			"off": dance, "tilt": sin(t * 7.0) * 0.12 * _motion if dancing else 0.0, "arm": 0.7 if dancing else 0.0, "wave": dancing})
	_cup(CUP_L_AT, Palette.LEFT_BLUE, "L", _pop(0.5), 1.0)
	_buzzer(1.0, 1.0 if buzz_on else 0.0, 0.0)
	_head_close()
	if cloud_k > 0.5:
		_shhh_letters(CLOUD_AT, 92.0)
	# the Ghost is called home and loses its sheet
	if back_k < 1.0:
		_ghost(GHOST_AWAY.lerp(home, back_k) + Vector2(0, -sin(back_k * PI) * 60.0), 46.0, {"flag": 1.0 - _k(1.3, 1.6), "flag_dir": -1.0})
	elif sheet_off < 1.0:
		_ghost(home + Vector2(18.0 * sheet_off, 40.0 * sheet_off * sheet_off), 46.0, {"squash": -0.3 * sheet_off, "empty": sheet_off > 0.2, "alpha": 1.0 - sheet_off})
	if buzz_on:
		_bzz(RIGHTY_AT + Vector2(0, -44), 58.0, 1.0)
		_text("BZZ", BUZZ_AT + Vector2(-48, 34), 22, INK, 700, 5)
	# (polish) masking alone never makes Righty hear: the buzz is raised to Righty's own level
	if t >= 4.4:
		_chip("buzz turned UP to Righty's level", CALLOUT_AT, Palette.SUNNY, 18, INK, _pop(4.4) * (1.0 - _k(8.6, 8.9)))
	if not answered:
		_zzz(RIGHTY_AT + Vector2(-60, -66))
	else:
		_sparkles(RIGHTY_AT + Vector2(110, -70), 6.4, 10, 70.0, Palette.SUNNY)
		_chip("Righty's OWN answer!", RIGHTY_AT + Vector2(-34, -150), Palette.MINT, 17, INK, _pop(6.6))
	_toll_sign(SIGN_AT, BONE_SIGN, 1.0, 0.0, Palette.MINT)
	_chip("busy!", LEFTY_AT + Vector2(44, -162), Palette.PAPER, 17, NOISE_DEEP, _pop(3.4))
	_chip("TEST EAR", RIGHTY_AT + Vector2(-4, 48), Palette.RIGHT_RED, 16, Palette.PAPER, _pop(5.0))
	_chip("NON-TEST EAR: shhh", LEFTY_AT + Vector2(6, 48), NOISE, 16, Palette.PAPER, _pop(5.3))


## 7. under: too little noise. The cloud shrinks to a patchy puff; Lefty pulls the sheet back on and
## the Ghost leans out through a gap: "boo!". The noise dial sits in the yellow; +5, +5 and the gaps
## close, the sheet comes off and Lefty is busy again.
func _set_under() -> void:
	var mask_db := int(params.get("mask_db", 20))
	var step1 := 3.5
	var step2 := 4.7
	var db := mask_db + (5 if t >= step1 else 0) + (5 if t >= step2 else 0)
	var patchy := _k(0.0, 0.9)
	if t >= step1:
		patchy = lerpf(1.0, 0.55, _k(step1, step1 + 0.4))
	if t >= step2:
		patchy = lerpf(0.55, 0.0, _k(step2, step2 + 0.4))
	var drop := _k(1.0, 1.4)
	var lean := _ease_out(_k(1.4, 1.8)) * (1.0 - 0.5 * _ease_in_out(_k(step1, step1 + 0.4)))
	var sheet_off := _k(step2, step2 + 0.5)
	var ghosted := t >= 1.4 and sheet_off < 1.0
	var lefty_shown := t < 1.4 or t >= step2
	var home := LEFTY_AT + Vector2(0, -44)
	var cr := 92.0 * lerpf(1.0, 0.74, patchy)
	_head_open(0.0)
	_head({"look": Vector2(0.5, 0.0), "mood": &"worried" if t < step2 else &"smile"})
	_wall(1.0, 0.28, true)
	_cloud(CLOUD_AT, cr, {"patchy": patchy})
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"sleep", "cap": 1.0})
	if lefty_shown:
		var busy := t >= step2
		var shades := 1.0 - _k(0.3, 0.8)
		if busy:
			shades = _k(step2 + 0.4, step2 + 0.8)
		var dance := Vector2(sin(t * (7.0 if busy else 3.0)) * 6.0, -absf(sin(t * 7.0)) * 6.0 if busy else 0.0) * _motion
		_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"happy" if busy else &"idle", "shades": shades, "off": dance, "look": Vector2(1, -0.3)})
	_cup(CUP_L_AT, Palette.LEFT_BLUE, "L", 1.0, 1.0)
	_buzzer(1.0, 1.0 if t > 1.0 and t < 2.4 else 0.0, 0.0)
	_head_close()
	_shhh_letters(CLOUD_AT, cr, 1.0 - patchy * 0.7)
	# the sheet drops back onto Lefty, and the Ghost leans out through a gap
	if drop > 0.0 and t < 1.4:
		_ghost(Vector2(home.x, lerpf(120.0, home.y, _ease_in_out(drop))), 44.0, {"flutter": 1.0 - drop, "empty": true})
	if ghosted:
		var gp := home + Vector2(-54.0 * lean, -24.0 * lean + sin(t * 4.0) * 3.0 * _motion)
		_ghost(gp + Vector2(18.0 * sheet_off, 40.0 * sheet_off * sheet_off), 44.0, {"boo": lean > 0.5 and sheet_off <= 0.0,
			"squash": _ring(1.4, 0.2, 16.0, 5.0) - 0.3 * sheet_off, "empty": sheet_off > 0.2, "alpha": 1.0 - sheet_off})
		if sheet_off <= 0.0 and t > 1.6:
			_text("boo!", gp + Vector2(10, -84), 28, Palette.LEFT_BLUE, 700, 8, Palette.PAPER, 0.5, _pop(1.6))
			_text("still answering...", gp + Vector2(-6, 66), 15, NOISE_DEEP, 700, 5, Palette.PAPER, 0.5, _pop(2.0) * (1.0 - _k(step1 - 0.2, step1)))
	_toll_sign(SIGN_AT, BONE_SIGN, 1.0, 0.0, Palette.MINT)
	_dial(DIAL_AT, 50.0, float(db), _ring(step1, 4.0, 22.0, 6.0) + _ring(step2, 4.0, 22.0, 6.0))
	var plus := _pop(2.4) if t < step2 + 0.2 else 0.0
	_chip("+5", DIAL_AT + Vector2(-104, 8 - absf(sin(t * 5.0)) * 6.0 * _motion), Palette.SUNNY, 24, INK, plus)
	_chip("too little shhh!", DIAL_AT + Vector2(0, -100), Palette.SUNNY, 16, INK, _pop(0.9) * (1.0 - _k(step2, step2 + 0.2)))
	if t > step2 + 0.3:
		_chip("enough!", DIAL_AT + Vector2(0, -100), Palette.MINT, 17, INK, _pop(step2 + 0.3))
		_sparkles(DIAL_AT + Vector2(0, -20), step2 + 0.2, 8, 50.0, Palette.MINT)
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	_zzz(RIGHTY_AT + Vector2(-60, -66))


## 8. over: too much noise. The dial swings into the red, the cloud balloons, pays its 40 dB toll
## crossing the wall (80 -> 40) and still smothers Righty, whose hand drops. "TOO MUCH NOISE!" is
## a wobbling sign: nothing loud ever plays.
func _set_over() -> void:
	var mask_db := int(params.get("mask_db", 80))
	var ia := int(params.get("ia", 40))
	var swing := _ease_out(_k(1.0, 1.5))
	var db := lerpf(35.0, float(mask_db), swing)
	var balloon := _ease_in_out(_k(1.0, 2.4))
	var flip := _k(1.5, 2.0)
	var spill := _ease_in_out(_k(2.2, 3.4))
	var smother := _ease_in_out(_k(3.2, 4.0))
	_head_open(0.0)
	_head({"look": Vector2(lerpf(0.5, -0.6, spill), 0.0), "mood": &"wince" if t > 3.4 else &"smile"})
	_wall(1.0, lerpf(0.28, 1.0, flip), flip < 0.5)
	_cloud(CLOUD_AT, 92.0 * lerpf(1.0, 1.35, balloon), {"patchy": 0.0})
	# the spill runs behind the snails (Righty's drowning face stays readable on top of it)
	if spill > 0.0:
		_cloud_stream(spill)
	var drowned := t > 3.8
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"drown" if drowned else &"alert", "arm": 1.0 - _k(3.6, 4.0), "look": Vector2(1, -0.3),
		"off": Vector2(0, 3.0 * sin(t * 3.0)) if drowned else Vector2.ZERO})
	var wild := 7.0 + 6.0 * balloon
	_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"happy", "shades": 1.0, "off": Vector2(sin(t * wild) * 8.0, -absf(sin(t * wild)) * 8.0) * _motion,
		"tilt": sin(t * wild) * 0.15 * _motion, "arm": 0.8, "wave": true})
	if smother > 0.0:
		_cloud(RIGHTY_AT + Vector2(-22, -44), 64.0 * smother, {"patchy": 0.0, "alpha": 0.55})
	_cup(CUP_L_AT, Palette.LEFT_BLUE, "L", 1.0, 1.0)
	_buzzer(1.0, 1.0 if t < 3.8 else 0.0, 0.0)
	_head_close()
	_shhh_letters(CLOUD_AT, 92.0 * lerpf(1.0, 1.35, balloon), 1.0, 1.0 + balloon)
	if smother > 0.3:
		_shhh_letters(RIGHTY_AT + Vector2(-22, -44), 60.0, smother)
	if flip < 0.5:
		_toll_sign(SIGN_AT, BONE_SIGN, 1.0, 0.0, Palette.MINT, cos(flip * PI))
	else:
		_toll_sign(SIGN_AT, ["AIR: -%d dB" % ia, "noise comes by AIR"], 1.0, _ring(2.0, 0.12, 9.0, 3.0), Palette.PAPER, -cos(flip * PI))
	# the noise's tag pays the toll as it crosses
	if spill > 0.0:
		# the tag rides just above the stream's front and pays the toll inside the wall
		var front := lerpf(LEFTY_AT.x - 64.0, RIGHTY_AT.x + 10.0, spill)
		var cross_k := clampf((WALL_X + WALL_W * 0.5 - front) / WALL_W, 0.0, 1.0)
		var tag_db := int(round(lerpf(float(mask_db), float(mask_db - ia), cross_k) / 5.0) * 5.0)
		var tp := Vector2(clampf(front + 10.0, 330.0, 560.0), STREAM_Y - 48.0)
		_chip("shhh %d" % tag_db, tp, NOISE, 19, Palette.PAPER, 1.0)
	_dial(DIAL_AT, 50.0, db, _ring(1.5, 6.0, 18.0, 4.0))
	if t > 1.5:
		_chip("way too much!", DIAL_AT + Vector2(0, -100), Palette.CORAL, 16, INK, _pop(1.6))
	var sign_k := _pop(4.0, 0.45)
	if sign_k > 0.01:
		_big_sign("TOO MUCH NOISE!", Vector2(440, 70), sign_k, sin(t * 6.0) * 0.08 * _motion)
	if drowned:
		_text("glub", RIGHTY_AT + Vector2(-62, -104 - 8.0 * sin(t * 4.0)), 20, NOISE_DEEP, 700, 6)
	_hoot(HOOT_AT, 40.0, {"mood": &"cover" if t > 3.8 else &"idle"})
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)


## 9. plateau: the AudiOtron's plateau graph as a cartoon, the same way up (louder answers LOWER,
## like an audiogram). Hoot hops along the answers: first they sink with the noise (the Ghost
## chases it), then three 5 dB hops stay flat (PLATEAU!), then, far later, too much noise makes
## them sink again (overmasking). params: rise / flat / over ([[noise, answer], ...]), start (the
## starting noise: the other ear's air + 10).
func _set_plateau() -> void:
	var rise: Array = params.get("rise", [])
	var flat: Array = params.get("flat", [])
	var over: Array = params.get("over", [])
	var start_m := int(params.get("start", int(rise[0][0]) if rise.size() > 0 else 15))
	var pts: Array = []
	var times: Array[float] = []
	var kinds: Array[StringName] = []
	for i in rise.size():
		pts.append(rise[i])
		times.append(3.2 - 0.8 * (rise.size() - 1 - i))   # the last Ghost answer at 3.2 s
		kinds.append(&"rise")
	for i in flat.size():
		pts.append(flat[i])
		times.append(7.0 + 0.8 * i)
		kinds.append(&"flat")
	for i in over.size():
		pts.append(over[i])
		times.append(10.6 + 0.6 * i)
		kinds.append(&"over")
	var g := Rect2(150, 88, 640, 248)
	var draw_k := _ease_out(_k(0.0, 0.7))
	# the graph card
	_panel(Rect2(60, 60, 760, 352), GRAPH_BG, 18)
	var gx0 := 10.0
	var gx1 := 80.0
	var gap_lo := 45.0
	var gap_hi := 65.0
	var db_top := 5.0
	var db_bot := 45.0
	var to_px := func(p: Array) -> Vector2:
		var x := float(p[0])
		var u := 0.0
		var span := (gap_lo - gx0) + (gx1 - gap_hi) + 6.0
		if x <= gap_lo:
			u = (x - gx0) / span
		else:
			u = (gap_lo - gx0 + 6.0 + (x - gap_hi)) / span
		return Vector2(g.position.x + g.size.x * u, g.position.y + g.size.y * (float(p[1]) - db_top) / (db_bot - db_top))
	# grid and axes: dB HL grows DOWNWARD, like the AudiOtron's plateau graph and the audiogram
	for db: int in [10, 20, 30, 40]:
		var y: float = (to_px.call([gx0, db]) as Vector2).y
		draw_dashed_line(Vector2(g.position.x, y), Vector2(g.position.x + g.size.x * draw_k, y), Color(INK, 0.12), 2.0, 8.0)
		_text("%d" % db, Vector2(g.position.x - 22, y), 16, Palette.INK_SOFT, 700)
	draw_line(Vector2(g.position.x, g.end.y), Vector2(g.position.x + g.size.x * draw_k, g.end.y), INK, 4.0, true)
	draw_line(Vector2(g.position.x, g.position.y), Vector2(g.position.x, g.position.y + g.size.y * draw_k), INK, 4.0, true)
	for x: int in [20, 30, 40, 70, 80]:
		var px := Vector2((to_px.call([x, db_bot]) as Vector2).x, g.end.y)
		if px.x <= g.position.x + g.size.x * draw_k:
			draw_line(px, px + Vector2(0, 8), INK, 3.0)
			_text("%d" % x, px + Vector2(0, 22), 16, Palette.INK_SOFT, 700)
	# the starting noise (the other ear's air + 10), like the AudiOtron's "start" line
	var sk := _pop(0.6)
	if sk > 0.01:
		var sx := (to_px.call([start_m, db_bot]) as Vector2).x
		draw_dashed_line(Vector2(sx, g.position.y), Vector2(sx, g.end.y), Color(NOISE, 0.55), 2.5, 7.0)
		_text("start %d" % start_m, Vector2(sx, g.end.y + 22), 15, NOISE_DEEP, 700, 0, Palette.PAPER, 0.5, sk)
	# the axis break sits in the skipped stretch (between gap_lo and gap_hi)
	var gap_span := (gap_lo - gx0) + (gx1 - gap_hi) + 6.0
	var gap_px := Vector2(g.position.x + g.size.x * (gap_lo - gx0 + 3.0) / gap_span, g.end.y)
	if draw_k > 0.6:
		for s: float in [-6.0, 6.0]:
			draw_line(gap_px + Vector2(s - 5, 10), gap_px + Vector2(s + 5, -10), INK, 3.0, true)
	_text("more shhh in the other ear (dB EM)", Vector2(g.get_center().x, g.end.y + 50), 18, INK, 700)
	_push(_xform(Vector2(g.position.x - 58, g.get_center().y), -PI * 0.5))
	_text("the answer (dB HL)", Vector2.ZERO, 18, INK, 700)
	_pop_xf()
	_text("louder", Vector2(g.position.x - 24, g.end.y - 12), 12, Palette.INK_SOFT, 700)
	UiDraw.arrow(self, Vector2(g.position.x - 24, g.end.y + 8), 10.0, Vector2(0, 1), Palette.INK_SOFT)
	# the line so far
	var shown := 0
	for i in pts.size():
		if t >= times[i]:
			shown = i + 1
	var plateau_t := 7.0 + 0.8 * maxf(0.0, flat.size() - 1.0) + 0.4
	var found := t >= plateau_t
	var gone_t := times[rise.size()] if flat.size() > 0 and rise.size() > 0 else plateau_t
	# found: the true threshold, a dashed line back to the side axis
	if found and flat.size() > 0:
		var fy: Vector2 = to_px.call(flat[-1])
		var lk := _k(plateau_t + 0.6, plateau_t + 1.0)
		draw_dashed_line(Vector2(fy.x, fy.y), Vector2(lerpf(fy.x, g.position.x, lk), fy.y), Color(Palette.MINT.darkened(0.35), 0.9), 3.0, 8.0)
		_chip("%d" % int(flat[-1][1]), Vector2(g.position.x - 22, fy.y), Palette.MINT, 16, INK, _pop(plateau_t + 0.9))
	for i in range(1, shown):
		var a: Vector2 = to_px.call(pts[i - 1])
		var b: Vector2 = to_px.call(pts[i])
		var kind: StringName = kinds[i]
		if kinds[i] == &"over" and kinds[i - 1] != &"over":
			draw_dashed_line(a, a.lerp(b, _k(times[i] - 0.4, times[i])), Color(INK, 0.35), 3.0, 8.0)
			continue
		var col := Palette.CORAL
		if kind == &"flat":
			col = Palette.MINT
		var seg := _k(times[i], times[i] + 0.3)
		var w := 7.0
		if kind == &"flat" and found:
			w = 9.0 + 2.0 * sin(t * 6.0) * _motion
		draw_line(a, a.lerp(b, seg), col, w, true)
	for i in shown:
		var p: Vector2 = to_px.call(pts[i])
		var k := _pop(times[i], 0.3)
		draw_circle(p, 10.0 * k, Palette.RIGHT_RED, true, -1.0, true)
		draw_arc(p, 10.0 * k, 0.0, TAU, 24, INK, 3.0, true)
	# the Ghost chases the noise with the first answers, and poofs once the noise keeps Lefty busy
	if rise.size() >= 2 and t > times[rise.size() - 1] + 0.4:
		var ga := 1.0 - _k(gone_t, gone_t + 0.4)
		var r1: Vector2 = to_px.call(rise[rise.size() / 2])
		var gp := r1 + Vector2(64, -58 + sin(t * 3.0) * 4.0 * _motion)
		if ga > 0.0:
			_ghost(gp, 26.0 * (1.0 + 0.3 * (1.0 - ga)), {"boo": true, "alpha": ga})
			_chip("GHOST: the answer chases the noise", gp + Vector2(190, -6), Palette.CORAL, 16, INK, _pop(times[rise.size() - 1] + 0.4) * ga)
		_dust(gp + Vector2(0, 10), gone_t)
		_sparkles(gp, gone_t, 8, 50.0, NOISE_FILL)
	if found and flat.size() > 0:
		var start: Array = rise[-1] if rise.size() > 0 else flat[0]
		var f0: Vector2 = to_px.call(start)
		var f1: Vector2 = to_px.call(flat[-1])
		_brace(Vector2(f0.x, f0.y + 24), Vector2(f1.x, f1.y + 24), "+%d dB of shhh, same answer" % int(float(flat[-1][0]) - float(start[0])), _k(plateau_t, plateau_t + 0.4))
		var sign_at := Vector2(lerpf(f0.x, f1.x, 0.5), f0.y - 84)
		_big_sign("PLATEAU!", sign_at, _pop(plateau_t, 0.5), sin(t * 4.0) * 0.05 * _motion, Palette.MINT)
		_sparkles(sign_at, plateau_t, 14, 120.0, Palette.SUNNY)
		_chip("Righty's TRUE threshold: %d dB" % int(flat[-1][1]), Vector2((f0.x + f1.x) * 0.5, f0.y + 90), Palette.PAPER, 16, INK, _pop(plateau_t + 0.6))
	if over.size() > 0 and shown == pts.size() and t > times[-1] + 0.3:
		var o1: Vector2 = to_px.call(over[-1])
		var oc := Vector2(o1.x - 30, o1.y - 74)
		_dashed_curve(oc + Vector2(10, 16), oc + Vector2(24, 40), o1 + Vector2(-6, -14), Palette.CORAL.darkened(0.2), _k(times[-1] + 0.3, times[-1] + 0.6))
		_chip("TOO MUCH: overmasking", oc, Palette.CORAL, 16, INK, _pop(times[-1] + 0.3))
	# Hoot hops from answer to answer
	var at_i := maxi(0, shown - 1)
	var hp: Vector2 = to_px.call(pts[at_i]) if pts.size() > 0 else g.get_center()
	if shown >= 1 and at_i + 1 <= pts.size() - 1:
		var nt := times[at_i + 1]
		var hk := _k(nt - 0.35, nt)
		if hk > 0.0:
			var np: Vector2 = to_px.call(pts[at_i + 1])
			hp = hp.lerp(np, hk) + Vector2(0, -sin(hk * PI) * 46.0)
	if shown >= 1 or t > 0.4:
		var mood: StringName = &"idle"
		if found and at_i < rise.size() + flat.size():
			mood = &"cheer"
		elif at_i >= rise.size() + flat.size():
			mood = &"gasp"
		_hoot(hp + Vector2(0, -38), 26.0, {"mood": mood, "squash": _ring(times[at_i], 0.2, 20.0, 7.0) if shown >= 1 else 0.0, "pop": _pop(0.4)})


## card (generic, any movie, data only): a chunky title card. Its lines pop in one by one beside an
## optional prop, and Hoot waves from the corner. params: heading (default: the scene's title),
## lines [String] (short: about 34 characters each), line_at [s] (optional; default spread over the
## first 60% of the scene), icon (one of CARD_ICONS), hoot (default true), tint ("#rrggbb" card colour).
func _set_card() -> void:
	var heading := String(params.get("heading", scene_title))
	var lines: Array = params.get("lines", [])
	var at: Array = params.get("line_at", [])
	var icon := String(params.get("icon", ""))
	var tint := Color.from_string(String(params.get("tint", "")), Palette.PAPER)
	var n := lines.size()
	if at.size() != n:
		at = []
		for i in n:
			at.append(0.8 + duration * 0.6 * i / maxf(1.0, n))
	var k := _pop(0.05, 0.5)
	_push(_about(Vector2(440, 236), 0.0, Vector2.ONE * maxf(0.02, k)))
	_panel(Rect2(70, 66, 740, 334), tint, 26)
	_pop_xf()
	if k < 0.6:
		return
	var text_w := 700.0 if icon == "" else 470.0
	var x0 := 112.0
	_text(heading, Vector2(x0, 124), 34, INK, 700, 0, Palette.PAPER, 0.0, _pop(0.3))
	draw_line(Vector2(x0, 156), Vector2(x0 + text_w * _ease_out(_k(0.4, 0.9)), 156), Color(Palette.SUNNY.darkened(0.1), 0.9), 6.0, true)
	for i in n:
		var lk := _pop(float(at[i]), 0.35)
		if lk <= 0.01:
			continue
		var y := 204.0 + i * 50.0
		_push(_about(Vector2(x0 + 14, y), 0.0, Vector2.ONE * lk))
		UiDraw.star(self, Vector2(x0 + 14, y), 12.0, Palette.SUNNY)
		_text(String(lines[i]), Vector2(x0 + 40, y), 24, INK, 600, 0, Palette.PAPER, 0.0)
		_pop_xf()
	var ic := Vector2(676, 262)
	var bob := Vector2(0, sin(t * 2.6) * 6.0 * _motion)
	var ik := _pop(0.5, 0.5)
	if ik > 0.01 and icon != "":
		_push(_about(ic, sin(t * 1.7) * 0.04 * _motion, Vector2.ONE * ik))
		match icon:
			"snails":
				# shell to shell, waving outwards (her right on your left, as always)
				var mid := ic + Vector2(-18, 0)
				_push(_about(mid, 0.0, Vector2.ONE * 0.74))
				_snail(mid + Vector2(-44, 76) + bob, -1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"happy", "arm": 0.8, "wave": true})
				_snail(mid + Vector2(44, 76) - bob, 1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"happy", "arm": 0.8, "wave": true})
				_pop_xf()
			"ghost":
				_ghost(ic + bob, 60.0, {"boo": true})
			"cloud":
				_cloud(ic, 96.0, {"patchy": 0.0})
				_shhh_letters(ic, 96.0)
			"note":
				_note(ic + Vector2(-10, 40) + bob, 2.6, Palette.RIGHT_RED, sin(t * 3.0) * 0.15)
			"dial":
				_dial(ic + Vector2(0, 10), 62.0, 45.0 + 25.0 * sin(t * 1.3), 0.0)
			"hoot":
				_hoot(ic + bob, 70.0, {"mood": &"cheer"})
		_pop_xf()
	if bool(params.get("hoot", true)) and icon != "hoot":
		_hoot(Vector2(60, 384), 30.0, {"pop": _pop(0.6), "mood": &"wave" if t < 2.5 else &"idle"})


## 10. outro: everyone bows, the curtains close, THE END? ... and two soft knocks: the next patient.
func _set_outro() -> void:
	var bow := sin(_k(0.4, 1.6) * PI)
	_head_open(0.0)
	_head({"look": Vector2(0, 0.3), "mood": &"grin"})
	_snail(RIGHTY_AT, 1.0, Palette.RIGHT_RED, RIGHTY_BODY, {"mood": &"happy", "tilt": bow * 0.35})
	_snail(LEFTY_AT, -1.0, Palette.LEFT_BLUE, LEFTY_BODY, {"mood": &"happy", "tilt": bow * 0.35})
	_head_close()
	_name_tag("RIGHTY", RIGHTY_AT, Palette.RIGHT_RED, 1.0)
	_name_tag("LEFTY", LEFTY_AT, Palette.LEFT_BLUE, 1.0)
	_hoot(HOOT_AT, 40.0, {"mood": &"bow", "tilt": bow * 0.4})
	if t > 0.5 and t < 2.4:
		_sparkles(Vector2(440, 120), 0.5, 16, 200.0, Palette.SUNNY)
	var knock := _ring(3.6, 5.0, 40.0, 9.0) + _ring(3.9, 5.0, 40.0, 9.0)
	_push(_xform(Vector2(knock, 0)))
	_curtains(1.0 - _ease_in_out(_k(2.0, 3.0)))
	_pop_xf()
	var end_k := _pop(2.9, 0.45)
	if end_k > 0.01:
		_big_sign("THE END?", Vector2(440, 196), end_k, sin(t * 3.0) * 0.04 * _motion, Palette.SUNNY)
	for kt: float in [3.6, 3.9]:
		if t >= kt and t < kt + 1.4:
			var a := 1.0 - _k(kt + 0.8, kt + 1.4)
			var p := Vector2(770, 120 + (kt - 3.6) * 200.0)
			_text("KNOCK!", p + Vector2(sin(t * 40.0) * 3.0 * _motion, 0), 30, Color(Palette.PAPER, a), 700, 9, Color(INK, a), 0.5, _pop(kt, 0.25))
	if t > 4.4:
		_chip("Places, trainee: a patient!", Vector2(440, 300), Palette.PAPER, 22, INK, _pop(4.4))


# =============================================================== the cast and props

## Begins the head group: everything until _head_close() moves with the head (the jelly wobble).
func _head_open(jelly: float) -> void:
	var j := jelly * _motion
	var sk := sin(t * 21.0) * 0.07 * j
	var sq := sin(t * 16.0) * 0.03 * j
	_push(_about(Vector2(HEAD_C.x, 428), 0.0, Vector2(1.0 + sq, 1.0 - sq), sk))


func _head_close() -> void:
	_pop_xf()


## The big friendly head seen from the front, with the skull window and both ear canals.
## o: look (Vector2, -1..1), mood (smile, wow, wince, worried, wobble, grin).
func _head(o: Dictionary) -> void:
	var look: Vector2 = o.get("look", Vector2.ZERO)
	var mood: StringName = o.get("mood", &"smile")
	# floor shadow, bun with its wooden spoon, ears
	_ell(Vector2(HEAD_C.x, 432), Vector2(210, 14), Color(INK, 0.12))
	var bun := Vector2(HEAD_C.x, HEAD_C.y - HEAD_R.y - 6)
	draw_line(bun + Vector2(-58, 22), bun + Vector2(52, -26), Palette.WOOD.darkened(0.2), 9.0, true)
	draw_line(bun + Vector2(-58, 22), bun + Vector2(52, -26), Palette.WOOD, 5.0, true)
	_blob(bun + Vector2(56, -28), Vector2(10, 7), Palette.WOOD, 3.0, -0.42)
	_circ(bun, 30.0, HAIR, 4.0)
	draw_arc(bun + Vector2(-4, -4), 18.0, PI * 1.1, PI * 1.7, 10, HAIR_LIGHT, 4.0, true)
	for s: float in [-1.0, 1.0]:
		var ear := Vector2(HEAD_C.x + s * (HEAD_R.x + 2.0), EAR_Y)
		_blob(ear, Vector2(24, 40), Palette.SKIN, 4.0)
		draw_arc(ear + Vector2(-s * 4.0, 0), 20.0, PI * 0.6 if s < 0 else -PI * 0.4, PI * 1.4 if s < 0 else PI * 0.4, 12, Palette.SKIN_SHADE, 4.0, true)
	# the head
	_blob(HEAD_C, HEAD_R, Palette.SKIN, 5.0)
	_hair()
	# the face sits above the skull window
	var ec := Vector2(HEAD_C.x, 148)
	for s: float in [-1.0, 1.0]:
		var e := ec + Vector2(s * 50.0, 0)
		_ell(e + Vector2(s * 26.0, 22), Vector2(16, 9), Color(Palette.CORAL, 0.35))
		if mood == &"wince":
			var d := -s
			draw_polyline(PackedVector2Array([e + Vector2(-10 * d, -6), e + Vector2(8 * d, 0), e + Vector2(-10 * d, 6)]), INK, 4.0, true)
			continue
		if mood == &"grin":
			# happy closed eyes, low enough to sit on skin (not on the dark hairline)
			draw_arc(e + Vector2(0, 14), 11.0, PI * 1.12, PI * 1.88, 10, INK, 5.0, true)
			continue
		var blink := fposmod(t + 0.7, 3.3) < 0.12
		if blink:
			draw_line(e + Vector2(-11, 0), e + Vector2(11, 0), INK, 4.0, true)
			continue
		var er := Vector2(14, 16) * (1.18 if mood == &"wow" else 1.0)
		_blob(e, er, Palette.PAPER, 3.5)
		var pupil := e + Vector2(look.x * 5.0, look.y * 5.0)
		if mood == &"wobble":
			pupil += Vector2(sin(t * 13.0 + s), cos(t * 11.0)) * 3.0 * _motion
		draw_circle(pupil, 6.5 if mood != &"wow" else 5.0, INK, true, -1.0, true)
		draw_circle(pupil + Vector2(-2, -2.5), 2.2, Palette.PAPER, true, -1.0, true)
		if mood == &"worried":
			draw_line(e + Vector2(-12 * s, -24), e + Vector2(10 * s, -30), INK, 4.0, true)
	var m := Vector2(HEAD_C.x, 178)
	match mood:
		&"wow":
			_blob(m, Vector2(8, 10), Color("#7a2a3a"), 3.0)
		&"wince":
			draw_polyline(PackedVector2Array([m + Vector2(-16, 2), m + Vector2(-8, -3), m + Vector2(0, 2), m + Vector2(8, -3), m + Vector2(16, 2)]), INK, 4.0, true)
		&"worried":
			draw_arc(m + Vector2(0, 10), 12.0, PI * 1.2, PI * 1.8, 10, INK, 4.0, true)
		&"wobble":
			var pts := PackedVector2Array()
			for i in 9:
				pts.append(m + Vector2(-16 + 4 * i, sin(i * 1.6 + t * 9.0) * 3.0 * _motion))
			draw_polyline(pts, INK, 4.0, true)
		&"grin":
			# a big open D-shaped grin (kept above the skull window)
			var grin := PackedVector2Array([m + Vector2(-17, -9)])
			for i in 11:
				var a := lerpf(0.0, PI, i / 10.0)
				grin.append(m + Vector2(cos(a) * 17.0, -9.0 + sin(a) * 15.0))
			draw_colored_polygon(grin, Color("#7a2a3a"))
			_ell(m + Vector2(0, 2), Vector2(8, 3.5), Palette.CORAL)
			grin.append(grin[0])
			draw_polyline(grin, INK, 3.5, true)
		_:
			draw_arc(m + Vector2(0, -10), 14.0, PI * 0.22, PI * 0.78, 12, INK, 4.0, true)
	# the window into the skull
	_blob(WIN_C, WIN_R + Vector2(7, 7), Palette.SKIN_SHADE, 0.0)
	_blob(WIN_C, WIN_R, SKULL, 4.0)
	var dash := _ell_pts(WIN_C, WIN_R - Vector2(12, 12), 48)
	for i in range(0, dash.size() - 1, 2):
		draw_line(dash[i], dash[i + 1], Color(Palette.SKIN_SHADE, 0.45), 2.0, true)
	# glass glints, so the window reads as a peek-in window (not a mouth)
	for g: Array in [[Vector2(-176, -36), 44.0, 9.0], [Vector2(-146, -54), 24.0, 5.0]]:
		var gc: Vector2 = WIN_C + Vector2(g[0])
		var half := Vector2(float(g[1]) * 0.5, 0).rotated(-0.9)
		draw_line(gc - half, gc + half, Color(Palette.SKY, 0.55), float(g[2]), true)
	# ear canals from each ear to its cochlea
	for s: float in [-1.0, 1.0]:
		var from := Vector2(HEAD_C.x + s * (HEAD_R.x - 18.0), EAR_Y + 4)
		var to := Vector2((RIGHTY_AT.x if s < 0 else LEFTY_AT.x) + s * 30.0, EAR_Y + 4)
		draw_line(from, to, INK, 17.0, true)
		draw_line(from, to, CANAL, 10.0, true)
		draw_circle(from, 6.0, Color("#b4614a"), true, -1.0, true)


func _hair() -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var a0 := deg_to_rad(196.0)
	var a1 := deg_to_rad(344.0)
	for i in 25:
		var a := lerpf(a0, a1, i / 24.0)
		outer.append(HEAD_C + Vector2(cos(a) * (HEAD_R.x + 3.0), sin(a) * (HEAD_R.y + 3.0)))
	for i in 25:
		var a := lerpf(a1, a0, i / 24.0)
		var scallop := 12.0 * absf(sin(i * PI / 4.0))
		inner.append(HEAD_C + Vector2(cos(a) * (HEAD_R.x - 18.0 - scallop * 0.6), sin(a) * (HEAD_R.y - 44.0 - scallop)))
	var poly := outer + inner
	draw_colored_polygon(poly, HAIR)
	draw_polyline(inner, INK, 4.0, true)
	var shine := PackedVector2Array()
	for i in 9:
		var a := lerpf(deg_to_rad(232.0), deg_to_rad(262.0), i / 8.0)
		shine.append(HEAD_C + Vector2(cos(a) * (HEAD_R.x - 16.0), sin(a) * (HEAD_R.y - 16.0)))
	draw_polyline(shine, HAIR_LIGHT, 6.0, true)


## A snail-shell cochlea with a face, facing dir (+1 = towards the screen's right).
## st: pop, squash, tilt, off, mood (idle, sleep, alert, happy, drown), arm 0..1, wave, bell, ring,
## cap (nightcap 0..1), shades (sunglasses 0..1), look (Vector2).
func _snail(at: Vector2, dir: float, shell_col: Color, body_col: Color, st: Dictionary) -> void:
	var k := float(st.get("pop", 1.0))
	if k <= 0.01:
		return
	var sq := float(st.get("squash", 0.0)) * _motion
	var tilt := float(st.get("tilt", 0.0))
	var off: Vector2 = st.get("off", Vector2.ZERO)
	var mood: StringName = st.get("mood", &"idle")
	var breathe := sin(t * (1.6 if mood == &"sleep" else 3.0) + at.x * 0.01) * (0.035 if mood == &"sleep" else 0.02) * _motion
	_push(_xform(at + off, tilt * dir, Vector2(dir * k * (1.0 + sq + breathe), k * (1.0 - sq - breathe))))
	# body and head: one outline around both
	_ell(Vector2(14, -12), Vector2(62, 17), INK)
	draw_circle(Vector2(64, -26), 22.0, INK, true, -1.0, true)
	_ell(Vector2(14, -12), Vector2(58, 13), body_col)
	draw_circle(Vector2(64, -26), 18.0, body_col, true, -1.0, true)
	_ell(Vector2(8, -4), Vector2(46, 4), Color(Palette.PAPER, 0.5))
	# the arm: from the chin, raised up in front of the face ("I heard it!")
	var arm := clampf(float(st.get("arm", 0.0)), 0.0, 1.0)
	var shoulder := Vector2(78, -8)
	var hand := Vector2(90, 2).lerp(Vector2(114, -62), _ease_out(arm))
	var waving := bool(st.get("wave", false)) and arm > 0.5
	if waving:
		hand = shoulder + (hand - shoulder).rotated(sin(t * 10.0) * 0.35 * _motion)
	# the shell (cochlea)
	var sc := Vector2(-2, -44)
	draw_circle(sc, 40.0, INK, true, -1.0, true)
	draw_circle(sc, 36.0, shell_col, true, -1.0, true)
	var spiral := PackedVector2Array()
	for i in 46:
		var a := -PI * 0.5 + i * 0.3
		spiral.append(sc + Vector2(cos(a), sin(a)) * (31.0 - i * 0.62))
	draw_polyline(spiral, shell_col.darkened(0.35), 5.0, true)
	draw_arc(sc, 28.0, PI * 1.1, PI * 1.45, 8, Color(Palette.PAPER, 0.55), 5.0, true)
	# nightcap
	var cap := float(st.get("cap", 0.0))
	if cap > 0.01:
		var cy := -30.0 * (1.0 - cap)
		var base_l := sc + Vector2(-30, -22 + cy)
		var base_r := sc + Vector2(26, -30 + cy)
		var tip := sc + Vector2(-48, -2 + cy) + Vector2(sin(t * 2.0) * 3.0, 0)
		draw_colored_polygon(PackedVector2Array([base_l, sc + Vector2(-6, -66 + cy), base_r]), Palette.SKY)
		draw_polyline(PackedVector2Array([base_l, sc + Vector2(-6, -66 + cy), base_r]), INK, 3.5, true)
		draw_colored_polygon(PackedVector2Array([base_l, sc + Vector2(-16, -58 + cy), tip]), Palette.SKY.darkened(0.1))
		draw_polyline(PackedVector2Array([base_l, sc + Vector2(-16, -58 + cy), tip]), INK, 3.5, true)
		draw_line(base_l, base_r, Palette.PAPER, 8.0, true)
		_circ(tip, 7.0, Palette.PAPER, 3.0)
	# eye stalks and eyes
	var stretch := 10.0 if mood == &"alert" else 0.0
	var eyes: Array[Vector2] = [Vector2(54, -70 - stretch), Vector2(80, -66 - stretch)]
	draw_line(Vector2(60, -40), eyes[0], INK, 4.0, true)
	draw_line(Vector2(70, -40), eyes[1], INK, 4.0, true)
	var look: Vector2 = st.get("look", Vector2(1, 0))
	var shades := clampf(float(st.get("shades", 0.0)), 0.0, 1.0)
	for e: Vector2 in eyes:
		match mood:
			&"sleep":
				draw_circle(e, 10.0, body_col, true, -1.0, true)
				draw_arc(e, 10.0, 0.0, TAU, 20, INK, 3.0, true)
				draw_arc(e + Vector2(0, -2), 6.0, 0.25, PI - 0.25, 8, INK, 3.0, true)
			&"happy":
				draw_circle(e, 10.0, Palette.PAPER, true, -1.0, true)
				draw_arc(e, 10.0, 0.0, TAU, 20, INK, 3.0, true)
				draw_arc(e + Vector2(0, 4), 6.0, PI + 0.3, TAU - 0.3, 8, INK, 3.5, true)
			&"drown":
				draw_circle(e, 10.0, Palette.PAPER, true, -1.0, true)
				draw_arc(e, 10.0, 0.0, TAU, 20, INK, 3.0, true)
				var sp := PackedVector2Array()
				for i in 14:
					var a := i * 0.75 + t * 6.0
					sp.append(e + Vector2(cos(a), sin(a)) * (1.0 + i * 0.5))
				draw_polyline(sp, NOISE_DEEP, 2.0, true)
			_:
				var big := 12.0 if mood == &"alert" else 10.0
				var blink := mood == &"idle" and fposmod(t + at.x * 0.013, 2.9) < 0.12
				if blink:
					draw_line(e + Vector2(-8, 0), e + Vector2(8, 0), INK, 3.5, true)
				else:
					draw_circle(e, big, Palette.PAPER, true, -1.0, true)
					draw_arc(e, big, 0.0, TAU, 20, INK, 3.0, true)
					var pr := 3.5 if mood == &"alert" else 5.0
					var lk := look.normalized() * (big - pr - 2.0) * minf(1.0, look.length())
					draw_circle(e + lk, pr, INK, true, -1.0, true)
	if shades > 0.01:
		var dy := -26.0 * (1.0 - shades)
		for e: Vector2 in eyes:
			_blob(e + Vector2(0, 1 + dy), Vector2(13, 9), Color(INK, shades), 0.0)
			draw_line(e + Vector2(-6, -2 + dy), e + Vector2(-1, -5 + dy), Color(Palette.PAPER, 0.7 * shades), 2.5, true)
		draw_line(eyes[0] + Vector2(12, dy), eyes[1] + Vector2(-12, dy), Color(INK, shades), 3.0, true)
	# mouth and cheek
	var m := Vector2(72, -22)
	_ell(Vector2(60, -16), Vector2(6, 4), Color(Palette.CORAL, 0.45))
	match mood:
		&"sleep":
			draw_circle(m, 3.5, INK, true, -1.0, true)
		&"alert":
			_blob(m + Vector2(0, 1), Vector2(4.5, 6), Color("#7a2a3a"), 2.5)
		&"happy":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-7, -3), m + Vector2(7, -3), m + Vector2(4, 4), m + Vector2(-4, 4)]), Color("#7a2a3a"))
			draw_line(m + Vector2(-8, -3), m + Vector2(8, -3), INK, 3.0, true)
		&"drown":
			draw_polyline(PackedVector2Array([m + Vector2(-7, 0), m + Vector2(-3, -3), m + Vector2(1, 0), m + Vector2(5, -3), m + Vector2(8, 0)]), INK, 3.0, true)
		_:
			draw_arc(m + Vector2(0, -5), 7.0, PI * 0.2, PI * 0.8, 8, INK, 3.0, true)
	# the arm on top when raised
	if arm > 0.01:
		var dirv := (hand - shoulder).normalized()
		draw_circle(shoulder, 7.5, INK, true, -1.0, true)
		draw_line(shoulder, hand, INK, 15.0, true)
		draw_circle(shoulder, 4.5, body_col, true, -1.0, true)
		draw_line(shoulder, hand, body_col, 9.0, true)
		_blob(hand + dirv * 4.0, Vector2(12, 11), body_col, 3.5, dirv.angle())
		_blob(hand + dirv * 2.0 + dirv.rotated(-PI * 0.5) * 11.0, Vector2(5.5, 4.5), body_col, 3.0, dirv.angle() - 0.6)
		var has_bell := bool(st.get("bell", false)) and arm > 0.6
		if arm > 0.9 and (waving or mood == &"alert") and not has_bell:
			for i in 2:
				var a0 := dirv.angle() - PI * 0.5
				draw_arc(hand + dirv * 4.0, 20.0 + i * 7.0, a0 - 0.5, a0 + 0.5, 6, Color(INK, 0.5), 2.5, true)
				draw_arc(hand + dirv * 4.0, 20.0 + i * 7.0, a0 + PI - 0.5, a0 + PI + 0.5, 6, Color(INK, 0.5), 2.5, true)
		if has_bell:
			# a big brass hand bell, ringing when Righty hears the beep
			var ringing := bool(st.get("ring", false))
			var swing := sin(t * 24.0) * 0.45 * _motion if ringing else 0.0
			_push(_xform(hand + dirv * 8.0 + Vector2(0, -6), swing))
			var bell := PackedVector2Array([Vector2(-9, -34), Vector2(9, -34), Vector2(14, -16), Vector2(20, 0), Vector2(-20, 0), Vector2(-14, -16)])
			draw_colored_polygon(bell, GOLD)
			bell.append(bell[0])
			draw_polyline(bell, INK, 3.5, true)
			draw_line(Vector2(-9, -26), Vector2(-14, -6), Color(Palette.PAPER, 0.7), 3.0, true)
			_circ(Vector2(0, -38), 5.0, Palette.WOOD, 3.0)
			_circ(Vector2(sin(t * 24.0) * 6.0 * _motion if ringing else 0.0, 5.0), 5.5, INK.lightened(0.15), 0.0)
			_pop_xf()
			if ringing:
				var bc := hand + dirv * 8.0 + Vector2(0, -26)
				for i in 3:
					var ang := -PI * 0.5 + (i - 1) * 0.55
					var rr := 34.0 + 4.0 * sin(t * 20.0 + i) * _motion
					draw_line(bc + Vector2(cos(ang), sin(ang)) * rr, bc + Vector2(cos(ang), sin(ang)) * (rr + 12.0), GOLD.darkened(0.3), 4.0, true)
	_pop_xf()


## Name tag under a snail.
func _name_tag(text: String, at: Vector2, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	_text(text, at + Vector2(0, 22), 19, col.darkened(0.15), 700, 7, Palette.PAPER, 0.5, k)


## Where Lefty usually sits (dotted outline) while the Ghost is out.
func _footprint(at: Vector2, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	var pts := _ell_pts(at + Vector2(0, -36), Vector2(44, 34), 30)
	for i in range(0, pts.size() - 1, 2):
		draw_line(pts[i], pts[i + 1], Color(col, 0.6 * k), 3.0, true)
	_text("?", at + Vector2(0, -38), 30, Color(col, 0.7 * k), 700)


## The Cross-Hearing Ghost: Lefty under a bedsheet (eye holes, Lefty's blue eyes peeking out).
## st: squash, flag (0..1: the "I HEARD IT!" flag), boo (open mouth), flutter, empty (no eyes), alpha.
func _ghost(c: Vector2, r: float, st: Dictionary) -> void:
	if r < 2.0:
		return
	var a := float(st.get("alpha", 1.0))
	var sq := float(st.get("squash", 0.0)) * _motion
	var flutter := float(st.get("flutter", 0.0))
	_push(_xform(c, sin(t * 2.5) * 0.06 * _motion + flutter * sin(t * 14.0) * 0.25, Vector2(1.0 + sq, 1.0 - sq)))
	# flag
	var flag := clampf(float(st.get("flag", 0.0)), 0.0, 1.0)
	if flag > 0.01:
		var fd := float(st.get("flag_dir", 1.0))   # +1: the flag flies to the right, -1: to the left
		var base := Vector2(fd * r * 0.9, r * 0.2)
		var top := base + Vector2(fd * r * 0.5, -r * 2.0 * flag)
		draw_line(base, top, Color(INK, a), 4.0, true)
		var wv := sin(t * 9.0) * 6.0 * _motion
		var fw := r * 2.7 * fd
		var fp := PackedVector2Array([top, top + Vector2(fw, wv), top + Vector2(fw, r * 0.9 + wv), top + Vector2(0, r * 0.9)])
		draw_colored_polygon(fp, Color(Palette.SUNNY, a))
		fp.append(top)
		draw_polyline(fp, Color(INK, a), 3.0, true)
		_text("I HEARD IT!", top + Vector2(fw * 0.5, r * 0.45 + wv * 0.5), int(r * 0.36), Color(INK, a), 700)
	# eye-stalk bumps under the sheet
	for s: float in [-1.0, 1.0]:
		draw_circle(Vector2(s * r * 0.3, -r * 0.95), r * 0.2 + 3.0, Color(INK, a), true, -1.0, true)
		draw_circle(Vector2(s * r * 0.3, -r * 0.95), r * 0.2, Color(SHEET, a), true, -1.0, true)
	var pts := PackedVector2Array()
	for i in 17:
		var ang := PI + PI * i / 16.0
		pts.append(Vector2(cos(ang), sin(ang)) * r)
	pts.append(Vector2(r * 1.05, r * 0.8))
	for i in 7:
		var x := r * 1.05 - 2.1 * r * i / 6.0
		pts.append(Vector2(x, r * (1.15 if i % 2 == 0 else 0.92) + sin(t * 6.0 + i) * r * 0.05 * _motion))
	pts.append(Vector2(-r * 1.05, r * 0.8))
	draw_colored_polygon(pts, Color(SHEET, a))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(INK, a), 4.0, true)
	draw_arc(Vector2(-r * 0.45, -r * 0.35), r * 0.35, PI * 1.1, PI * 1.4, 6, Color(Palette.LEFT_TINT, a), 4.0, true)
	if not bool(st.get("empty", false)):
		for s: float in [-1.0, 1.0]:
			var e := Vector2(s * r * 0.32, -r * 0.18)
			_ell(e, Vector2(r * 0.14, r * 0.19), Color(INK, a))
			draw_circle(e + Vector2(0, r * 0.03), r * 0.07, Color(Palette.LEFT_BLUE.lightened(0.3), a), true, -1.0, true)
		if bool(st.get("boo", false)):
			_ell(Vector2(0, r * 0.3), Vector2(r * 0.14, r * 0.18), Color(INK, a))
		else:
			draw_arc(Vector2(0, r * 0.18), r * 0.16, PI * 0.2, PI * 0.8, 8, Color(INK, a), 3.0, true)
	else:
		for s: float in [-1.0, 1.0]:
			_ell(Vector2(s * r * 0.32, -r * 0.18), Vector2(r * 0.14, r * 0.19), Color(INK, a * 0.35))
	_pop_xf()


## The spiky "BOO!" shout bubble, its tail pointing at the speaker (tail_to).
func _boo_bubble(c: Vector2, k: float, tail_to: Vector2) -> void:
	if k <= 0.01:
		return
	_push(_about(c, sin(t * 5.0) * 0.06 * _motion, Vector2.ONE * k))
	var d := (tail_to - c).normalized()
	var tail := PackedVector2Array([c + d.rotated(0.35) * 40.0, tail_to, c + d.rotated(-0.35) * 40.0])
	draw_colored_polygon(tail, Palette.PAPER)
	draw_polyline(PackedVector2Array([tail[0], tail[1], tail[2]]), INK, 4.0, true)
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		var rr := 54.0 if i % 2 == 0 else 43.0
		pts.append(c + Vector2(cos(ang) * rr * 1.25, sin(ang) * rr * 0.85))
	draw_colored_polygon(pts, Palette.PAPER)
	var o := pts.duplicate()
	o.append(pts[0])
	draw_polyline(o, INK, 4.0, true)
	_text("BOO!", c, 42, Palette.LEFT_BLUE, 700, 8, Palette.PAPER)
	_pop_xf()


## The purple "shhh" masking noise cloud. st: patchy (0..1: gaps where the Ghost sneaks through), alpha.
func _cloud(c: Vector2, r: float, st: Dictionary) -> void:
	if r < 4.0:
		return
	var patchy := clampf(float(st.get("patchy", 0.0)), 0.0, 1.0)
	var a := float(st.get("alpha", 0.92))
	var puffs: Array = []
	var n := 9
	for i in n:
		var ang := TAU * i / n + 0.35
		var pr := r * 0.42 * (1.0 + 0.07 * sin(t * 3.0 + i * 1.7) * _motion) * (1.0 - patchy * 0.35)
		if _hash(i, 7) > patchy * 0.75:
			puffs.append([c + Vector2(cos(ang), sin(ang) * 0.82) * r * 0.58, pr])
	puffs.append([c, r * 0.5 * (1.0 - patchy * 0.45)])
	for p: Array in puffs:
		draw_circle(p[0], float(p[1]) + 4.0, Color(NOISE, a), true, -1.0, true)
	for p: Array in puffs:
		draw_circle(p[0], float(p[1]), Color(NOISE_FILL, a), true, -1.0, true)
	for j in 3:
		var sp := PackedVector2Array()
		var y := c.y - r * 0.3 + j * r * 0.3
		for i in 14:
			var x := c.x - r * 0.55 + i * r * 0.085
			sp.append(Vector2(x, y + sin(i * 1.3 + t * 5.0 + j) * 4.0 * _motion))
		draw_polyline(sp, Color(NOISE, 0.45 * a * (1.0 - patchy * 0.6)), 2.5, true)


## The drifting "shhh" letters of a cloud (drawn on top of whatever sits inside it).
func _shhh_letters(c: Vector2, r: float, alpha: float = 1.0, speed: float = 1.0) -> void:
	for i in 4:
		var k := fposmod(t * 0.35 * speed + i * 0.25, 1.0)
		var ang := i * 1.9 + 0.4
		var p := c + Vector2(cos(ang) * r * 0.5, sin(ang) * r * 0.4) + Vector2(0, -k * 26.0)
		var fade := sin(k * PI) * alpha
		_text("shhh", p, int(clampf(r * 0.22, 14.0, 26.0)), Color(NOISE_DEEP, fade), 700, 4, Color(Palette.PAPER, fade * 0.8))


## The overmasking spill: a stream of puffs from Lefty's cloud squeezing THROUGH the skull wall (like
## the loud beep in "wall") to Righty, thinner after the wall: it lost its 40 dB toll, and is still
## enough to smother Righty.
func _cloud_stream(k: float) -> void:
	var a := Vector2(LEFTY_AT.x - 64.0, STREAM_Y)
	var b := Vector2(RIGHTY_AT.x + 10.0, STREAM_Y)
	var n := 12
	for pass_i in 2:
		for i in n:
			var u := float(i) / (n - 1)
			if u > k:
				break
			var p := a.lerp(b, u) + Vector2(0, sin(u * TAU * 1.5 + t * 5.0) * 7.0 * _motion)
			var in_wall := absf(p.x - WALL_X) < WALL_W * 0.7
			var pr := (24.0 if p.x > WALL_X else 17.0) * (0.55 if in_wall else 1.0) * (1.0 + 0.08 * sin(t * 4.0 + i))
			if pass_i == 0:
				draw_circle(p, pr + 4.0, NOISE, true, -1.0, true)
			else:
				draw_circle(p, pr, NOISE_FILL, true, -1.0, true)


## The brick skull wall between the cochleas. grow 0..1 (rises from the floor), alpha (see-through
## for bone), dashed outline when see-through.
func _wall(grow: float, alpha: float, dashed: bool) -> void:
	if grow <= 0.01:
		return
	var h := (WALL_BOTTOM - WALL_TOP) * grow
	var top := WALL_BOTTOM - h
	var x0 := WALL_X - WALL_W * 0.5
	var row_h := 19.0
	var rows := int(ceil(h / row_h))
	for r in rows:
		var y1 := WALL_BOTTOM - r * row_h
		var y0 := maxf(top, y1 - row_h)
		var offs := 0.0 if r % 2 == 0 else WALL_W * 0.25
		var x := x0 - offs
		var b := 0
		while x < x0 + WALL_W:
			var bx0 := maxf(x0, x)
			var bx1 := minf(x0 + WALL_W, x + WALL_W * 0.5)
			if bx1 - bx0 > 2.0:
				var tint := 0.08 * (_hash(r * 7 + b, 3) - 0.5)
				draw_rect(Rect2(bx0 + 1.5, y0 + 1.5, bx1 - bx0 - 3.0, y1 - y0 - 3.0), Color(BRICK.lightened(tint), alpha))
			x += WALL_W * 0.5
			b += 1
	var rect := Rect2(x0, top, WALL_W, h)
	if dashed:
		draw_dashed_line(rect.position, Vector2(rect.position.x, rect.end.y), Color(INK, 0.55), 3.0, 8.0)
		draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, Color(INK, 0.55), 3.0, 8.0)
		draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), Color(INK, 0.55), 3.0, 8.0)
	else:
		draw_rect(rect, Color(INK, alpha), false, 4.0)


## The toll sign nailed onto the wall: lines[0] big, lines[1] small. flip_x animates a flip (-1..1).
func _toll_sign(at: Vector2, lines: Array, k: float, rot: float, bg: Color, flip_x: float = 1.0) -> void:
	if k <= 0.01:
		return
	var f := UiKit.font(700)
	var small := String(lines[1]) if lines.size() > 1 else ""
	var w := maxf(f.get_string_size(String(lines[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x, f.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x) + 26.0
	var hh := 54.0 if small != "" else 38.0
	_push(_xform(at, rot * _motion, Vector2(k * maxf(0.02, absf(flip_x)), k)))
	var rr := Rect2(-w * 0.5, -hh * 0.5, w, hh)
	_rbox(Rect2(rr.position + Vector2(0, 5), rr.size), Color(INK, 0.25), 12, 0)
	_rbox(rr, bg, 12, 4)
	for s: float in [-1.0, 1.0]:
		draw_circle(Vector2(s * (w * 0.5 - 9.0), -hh * 0.5 + 9.0), 3.0, Color(INK, 0.55), true, -1.0, true)
	_text(String(lines[0]), Vector2(0, -hh * 0.5 + 19), 22, INK, 700)
	if small != "":
		_text(small, Vector2(0, hh * 0.5 - 13), 14, Palette.INK_SOFT, 700)
	_pop_xf()


## An on-ear earphone cup with a stub of its headband. side: -1 = on the screen's left ear.
func _cup(at: Vector2, col: Color, letter: String, k: float, side: float) -> void:
	if k <= 0.01:
		return
	_push(_about(at, 0.0, Vector2.ONE * k))
	var band := PackedVector2Array()
	for i in 9:
		var u := i / 8.0
		band.append(at + Vector2(-side * 60.0 * u * u, -48.0 - 100.0 * u))
	draw_polyline(band, INK, 12.0, true)
	draw_polyline(band, BONE_GREY, 6.0, true)
	var rr := Rect2(at - Vector2(23, 50), Vector2(46, 100))
	_rbox(rr, col, 20, 4)
	_rbox(Rect2(at + Vector2(-side * 30.0 - 9.0, -38), Vector2(18, 76)), col.darkened(0.3), 9, 3)
	_text(letter, at + Vector2(side * 2.0, 0), 26, Palette.PAPER, 700)
	_pop_xf()


## The bone buzzer (oscillator) behind her right ear, with its steel headband over the head.
## k: pop-in, buzz 0..1 (the rings), sq: squash.
func _buzzer(k: float, buzz: float, sq: float) -> void:
	if k <= 0.01:
		return
	var band := PackedVector2Array()
	for i in 25:
		var a := lerpf(deg_to_rad(150.0), deg_to_rad(388.0), i / 24.0)
		band.append(HEAD_C + Vector2(cos(a) * (HEAD_R.x + 10.0), sin(a) * (HEAD_R.y + 10.0)))
	var shown := int(ceil(band.size() * clampf(k, 0.0, 1.0)))
	if shown >= 2:
		var b2 := band.slice(0, shown)
		draw_polyline(b2, INK, 11.0, true)
		draw_polyline(b2, BONE_GREY, 5.0, true)
	if k >= 1.0:
		_blob(band[band.size() - 1] + Vector2(-4, 0), Vector2(10, 16), BONE_GREY, 3.5)
	var jit := Vector2(sin(t * 70.0), cos(t * 63.0)) * 1.6 * buzz * _motion
	_push(_xform(BUZZ_AT + jit, 0.0, Vector2(k * (1.0 + sq), k * (1.0 - sq))))
	_rbox(Rect2(-22, -26, 44, 52), BUZZ_BEIGE, 12, 4)
	draw_circle(Vector2(0, 2), 11.0, BUZZ_BEIGE.darkened(0.15), true, -1.0, true)
	draw_arc(Vector2(0, 2), 11.0, 0.0, TAU, 20, INK, 3.0, true)
	draw_circle(Vector2(12, -15), 3.5, Palette.MINT if buzz > 0.0 else Palette.LCD_DIM, true, -1.0, true)
	_pop_xf()
	if buzz > 0.0:
		_bzz(BUZZ_AT, 34.0, buzz)


## A music-note beep. s: size, label: its dB tag.
func _note(c: Vector2, s: float, col: Color, rot: float = 0.0, label: String = "") -> void:
	if s <= 0.02:
		return
	_push(_xform(c, rot, Vector2.ONE * s))
	_blob(Vector2.ZERO, Vector2(11, 8), col, 3.5, -0.4)
	draw_line(Vector2(9, -3), Vector2(9, -34), INK, 4.0, true)
	draw_polyline(PackedVector2Array([Vector2(9, -34), Vector2(20, -26), Vector2(22, -16)]), INK, 4.0, true)
	_pop_xf()
	if label != "":
		_text(label, c + Vector2(-6 * s, -44.0 * s - 6.0), int(clampf(16.0 * s, 14.0, 26.0)), INK, 700, 5)


## Motion lines around something LOUD (drawn: the sound itself stays quiet).
func _loud_lines(c: Vector2, r: float) -> void:
	for i in 6:
		var ang := -PI * 0.15 + i * PI * 0.26 + PI
		var d := r + 6.0 * sin(t * 18.0 + i) * _motion
		draw_line(c + Vector2(cos(ang), sin(ang)) * d, c + Vector2(cos(ang), sin(ang)) * (d + 16.0), Palette.CORAL, 4.0, true)


## Buzz rings: zigzag arcs either side of a point.
func _bzz(c: Vector2, r: float, strength: float) -> void:
	if strength <= 0.0:
		return
	for j in 2:
		var rr := r + j * 11.0 + 2.0 * sin(t * 30.0 + j) * _motion
		for side: float in [0.0, PI]:
			var pts := PackedVector2Array()
			for i in 9:
				var ang := side - 0.55 + 1.1 * i / 8.0
				var z := rr + (4.0 if i % 2 == 0 else -4.0) * strength
				pts.append(c + Vector2(cos(ang), sin(ang)) * z)
			draw_polyline(pts, Color(INK, 0.65 * strength), 3.0, true)


func _zzz(at: Vector2) -> void:
	for i in 3:
		var k := fposmod(t * 0.5 + i / 3.0, 1.0)
		var p := at + Vector2(-k * 22.0, -k * 40.0)
		_text("z", p, int(14 + 12 * k), Color(Palette.INK_SOFT, sin(k * PI)), 700, 4, Color(Palette.PAPER, sin(k * PI)))


## The noise dial: 0-100 dB EM, yellow too little, green enough (anywhere on the plateau), coral too much.
func _dial(c: Vector2, r: float, db: float, wobble: float) -> void:
	_rbox(Rect2(c - Vector2(r + 18, r + 18), Vector2((r + 18) * 2.0, r + 76)), Palette.PAPER, 18, 4)
	var zones: Array = [[0.0, 27.5, Palette.SUNNY], [27.5, 62.5, Palette.MINT], [62.5, 100.0, Palette.CORAL]]
	for z: Array in zones:
		draw_arc(c, r - 8.0, PI + PI * float(z[0]) / 100.0, PI + PI * float(z[1]) / 100.0, 16, z[2], 16.0, true)
	draw_arc(c, r, PI, TAU, 32, INK, 3.0, true)
	var ang := PI + PI * clampf((db + wobble) / 100.0, 0.0, 1.0)
	draw_line(c, c + Vector2(cos(ang), sin(ang)) * (r - 6.0), INK, 5.0, true)
	draw_circle(c, 7.0, INK, true, -1.0, true)
	_text("NOISE %d" % int(round(db / 5.0) * 5.0), c + Vector2(0, 22), 17, INK, 700)
	_text("dB EM", c + Vector2(0, 40), 12, Palette.INK_SOFT, 600)


## A little Hoot for the stage. st: mood (idle, wave, gasp, cover, bow, cheer), pop, squash, tilt.
func _hoot(c: Vector2, r: float, st: Dictionary) -> void:
	var k := float(st.get("pop", 1.0))
	if k <= 0.01:
		return
	var mood: StringName = st.get("mood", &"idle")
	var sq := float(st.get("squash", 0.0)) * _motion
	var tilt := float(st.get("tilt", 0.0))
	var bob := sin(t * 3.2) * 2.0 * _motion
	_push(_about(c + Vector2(0, r * 0.9), tilt, Vector2(k * (1.0 + sq), k * (1.0 - sq))))
	var body := c + Vector2(0, r * 0.12 + bob)
	var br := r * 0.66
	for s: float in [-1.0, 1.0]:
		_blob(c + Vector2(s * br * 0.38, r * 0.86), Vector2(br * 0.22, br * 0.1), Palette.SELECT_ORANGE, 2.5)
	for s: float in [-1.0, 1.0]:
		var wing_rot := s * 0.35
		var wing_at := body + Vector2(s * br * 0.92, br * 0.25)
		match mood:
			&"wave":
				if s > 0:
					wing_rot = -1.9 + sin(t * 9.0) * 0.4 * _motion
					wing_at = body + Vector2(br * 1.0, -br * 0.3)
			&"gasp", &"cheer":
				wing_rot = s * 2.3 + (sin(t * 12.0) * 0.2 * _motion if mood == &"cheer" else 0.0)
				wing_at = body + Vector2(s * br * 0.95, -br * 0.4)
			&"cover":
				wing_rot = s * 2.7
				wing_at = body + Vector2(s * br * 0.75, -br * 0.75)
		_blob(wing_at, Vector2(br * 0.28, br * 0.55), Palette.HOOT_BROWN.darkened(0.08), 3.0, wing_rot)
	Portraits.draw(self, "Hoot", c + Vector2(0, bob), r, mood == &"gasp" or mood == &"cheer" or (mood == &"wave" and fposmod(t, 0.5) < 0.25), mood == &"bow", false)
	_pop_xf()


## A wobbling cartoon sign (TOO MUCH NOISE!, PLATEAU!, THE END?).
func _big_sign(text: String, c: Vector2, k: float, rot: float, bg: Color = Palette.CORAL) -> void:
	if k <= 0.01:
		return
	var f := UiKit.font(700)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x + 46.0
	_push(_about(c, rot, Vector2.ONE * k))
	var rr := Rect2(c - Vector2(w * 0.5, 34), Vector2(w, 68))
	_rbox(Rect2(rr.position + Vector2(0, 7), rr.size), Color(INK, 0.3), 22, 0)
	_rbox(rr, bg, 22, 5)
	_text(text, c, 38, INK if bg != Palette.CORAL else Palette.PAPER, 700, 0)
	_pop_xf()


## A label beside the stage with a dashed pointer to what it names. text may hold "\n".
func _pointer_label(text: String, at: Vector2, to: Vector2, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	var ctrl := Vector2((at.x + to.x) * 0.5, at.y - 30.0)
	_dashed_curve(at + Vector2(0, 30), ctrl, to, col, k)
	var lines := text.split("\n")
	_push(_about(at, 0.0, Vector2.ONE * k))
	for i in lines.size():
		_text(lines[i], at + Vector2(0, i * 22.0 - 10.0), 19, col.darkened(0.1), 700, 6, Palette.PAPER)
	_pop_xf()


## A chunky dashed path with an arrowhead (where a sound went), drawn as it grows with k.
func _trail(a: Vector2, ctrl: Vector2, b: Vector2, col: Color, k: float) -> void:
	if k <= 0.01:
		return
	var n := 14
	for i in n:
		if i % 2 == 1:
			continue
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		if u0 > k:
			break
		var p0 := _bezier(a, ctrl, b, u0)
		var p1 := _bezier(a, ctrl, b, minf(u1, k))
		draw_line(p0, p1, INK, 9.0, true)
		draw_line(p0, p1, col, 5.0, true)
	if k >= 1.0:
		UiDraw.arrow(self, b, 22.0, b - _bezier(a, ctrl, b, 0.9), INK)


func _dashed_curve(a: Vector2, ctrl: Vector2, b: Vector2, col: Color, k: float) -> void:
	var n := 16
	for i in n:
		if i % 2 == 1:
			continue
		var u0 := float(i) / n
		var u1 := float(i + 1) / n
		if u0 > k:
			break
		draw_line(_bezier(a, ctrl, b, u0), _bezier(a, ctrl, b, minf(u1, k)), col, 3.0, true)


## A curly brace under a span with its label.
func _brace(a: Vector2, b: Vector2, label: String, k: float) -> void:
	if k <= 0.01:
		return
	var m := (a + b) * 0.5
	var col := Color(Palette.MINT.darkened(0.3), k)
	draw_polyline(PackedVector2Array([a, a + Vector2(6, 10), m + Vector2(-6, 10), m + Vector2(0, 18), m + Vector2(6, 10), b + Vector2(-6, 10), b]), col, 4.0, true)
	_text(label, m + Vector2(0, 36), 16, Color(INK, k), 700, 5)


# =============================================================== effects

func _sparkles(c: Vector2, t0: float, n: int, dist: float, col: Color) -> void:
	var k := _k(t0, t0 + 0.9)
	if t < t0 or k >= 1.0:
		return
	for i in n:
		var ang := TAU * i / n + _hash(i, 11) * 0.6
		var d := dist * _ease_out(k) * (0.6 + 0.4 * _hash(i, 5))
		var s := 9.0 * (1.0 - k) * (0.6 + 0.6 * _hash(i, 2))
		if s > 0.5:
			UiDraw.star(self, c + Vector2(cos(ang), sin(ang)) * d, s, col if i % 3 != 0 else Palette.PAPER)


## Stars bursting off a hit at c, and a "bonk!" at text_at.
func _bonk(c: Vector2, t0: float, text_at: Vector2) -> void:
	var k := _k(t0, t0 + 0.7)
	if t < t0 or k >= 1.0:
		return
	for i in 5:
		var ang := PI + (i - 2) * 0.5
		var d := 10.0 + 28.0 * _ease_out(k)
		UiDraw.star(self, c + Vector2(cos(ang) * d, sin(ang) * d * 0.7 - 10.0), 9.0 * (1.0 - k), Palette.SUNNY)
	var a := 1.0 - k * k
	_text("bonk!", text_at + Vector2(0, -10.0 * k), 22, Color(INK, a), 700, 7, Color(Palette.PAPER, a), 0.5, _pop(t0, 0.2))


func _dust(c: Vector2, t0: float) -> void:
	var k := _k(t0, t0 + 0.7)
	if t < t0 or k >= 1.0:
		return
	for s: float in [-1.0, 1.0]:
		for i in 3:
			draw_circle(c + Vector2(s * (16.0 + 26.0 * k + i * 10.0), -i * 6.0 * k), (8.0 - i * 2.0) * (1.0 - k) + 2.0, Color(Palette.PAPER.darkened(0.08), 1.0 - k), true, -1.0, true)


## The cartoon iris-in at the start of a scene.
func _iris() -> void:
	var k := _k(0.0, 0.45)
	if k >= 1.0:
		return
	var c := size * 0.5
	var far := size.length() * 0.6
	var r := far * _ease_out(k)
	var w := far * 1.2 - r
	draw_arc(c, r + w * 0.5, 0.0, TAU, 64, BACKDROP, w, true)
	if r > 2.0:
		draw_arc(c, r, 0.0, TAU, 64, INK, 6.0, true)


func _curtains(open_k: float) -> void:
	if open_k >= 0.999:
		return
	var half := size.x * 0.5
	var w := half * (1.0 - open_k) + 24.0 * open_k
	var sway := sin(t * 2.0) * 6.0 * (1.0 - open_k) * _motion
	for side: float in [-1.0, 1.0]:
		var x0 := 0.0 if side < 0 else size.x
		var inner := x0 - side * w
		var pts := PackedVector2Array([Vector2(x0, 0), Vector2(inner, 0), Vector2(inner + side * (10.0 - sway), size.y * 0.6), Vector2(inner - side * 6.0, size.y), Vector2(x0, size.y)])
		if side > 0:
			pts.reverse()
		draw_colored_polygon(pts, CURTAIN)
		var folds := int(w / 36.0)
		for i in folds:
			var fx := x0 - side * (18.0 + 36.0 * i)
			draw_line(Vector2(fx, 0), Vector2(fx - side * sway * 0.5, size.y), CURTAIN_DARK, 7.0, true)
		draw_line(Vector2(inner, 0), Vector2(inner + side * (10.0 - sway), size.y * 0.6), INK, 4.0, true)
		draw_line(Vector2(inner + side * (10.0 - sway), size.y * 0.6), Vector2(inner - side * 6.0, size.y), INK, 4.0, true)
	var n := int(size.x / 70.0) + 1
	for i in n:
		draw_circle(Vector2(i * 70.0 + 35.0, 0), 28.0, CURTAIN_DARK, true, -1.0, true)


## The title card behind the opening curtains, with blinking marquee bulbs.
func _title_card(k: float, rot: float) -> void:
	if k <= 0.01:
		return
	var c := size * 0.5 + Vector2(0, 6)
	var w := 640.0
	var h := 290.0
	_push(_about(c, rot, Vector2.ONE * k))
	var rr := Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	_rbox(Rect2(rr.position + Vector2(0, 10), rr.size), Color(INK, 0.3), 28, 0)
	_rbox(rr, INK, 28, 0)
	_rbox(rr.grow(-16), Color("#3a2f55"), 20, 3, Palette.SUNNY)
	var per := 2.0 * (w + h - 16.0)
	var nb := 36
	for i in nb:
		var p := _rect_perimeter(rr.grow(-8), per * i / nb)
		var lit := (i + int(t * 6.0)) % 3 != 0
		draw_circle(p, 5.0, Palette.SUNNY if lit else Palette.LCD_DIM, true, -1.0, true)
	_text("HOOT'S MOVIE MATINEE", c + Vector2(0, -88), 28, Palette.SUNNY, 700)
	_text("The Cross-Hearing", c + Vector2(0, -26), 52, Palette.PAPER, 700, 0)
	_text("Ghost", c + Vector2(40, 34), 52, Palette.PAPER, 700, 0)
	_ghost(c + Vector2(-90, 38), 28.0, {"boo": true})
	_text("starring Righty & Lefty", c + Vector2(0, 98), 19, Palette.SKY, 600)
	_pop_xf()


## An opening that holds a title card (Day 2's "meet", or a movie's own set with params.card_hold,
## like the case movies' marquee): the curtains are its entrance (no iris), and the scene chip
## waits until the card has gone.
func _card_scene() -> bool:
	return set_id == &"meet" or params.has("card_hold")


func _scene_chip() -> void:
	var card_end := float(params.get("card_hold", 2.0)) + 0.4
	if scene_title == "" or (_card_scene() and t < card_end):
		return
	var k := _pop(0.35 if not _card_scene() else card_end, 0.4)
	if k <= 0.01:
		return
	var f := UiKit.font(700)
	var label := scene_title.to_upper()
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	_push(_about(Vector2(22, 32), 0.0, Vector2.ONE * k))
	var rr := Rect2(Vector2(14, 14), Vector2(w + 64.0, 36))
	_rbox(rr, Color(INK, 0.92), 18, 0)
	draw_circle(Vector2(32, 32), 13.0, Palette.SUNNY, true, -1.0, true)
	_text(str(scene_no) if scene_no > 0 else "*", Vector2(32, 32), 16, INK, 700)
	_text(label, Vector2(52, 32), 16, Palette.PAPER, 700, 0, Palette.PAPER, 0.0)
	_pop_xf()


func _panel(r: Rect2, bg: Color, radius: int) -> void:
	_rbox(Rect2(r.position + Vector2(0, 6), r.size), Color(INK, 0.18), radius, 0)
	_rbox(r, bg, radius, 4)


func _screen() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Palette.CREAM)
	# a soft projector glow in the middle, warmer edges
	var c := size * 0.5
	var n := 24
	var far := size.length() * 0.6
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := c + Vector2(cos(a0), sin(a0)) * far
		var p1 := c + Vector2(cos(a1), sin(a1)) * far
		draw_polygon(PackedVector2Array([c, p0, p1]), PackedColorArray([Color(Palette.PAPER, 0.55), Color(Palette.SKIN_SHADE, 0.16), Color(Palette.SKIN_SHADE, 0.16)]))


func _frame() -> void:
	var rad := 26.0
	var corners: Array = [[Vector2.ZERO, Vector2(rad, rad), PI, PI * 1.5], [Vector2(size.x, 0), Vector2(size.x - rad, rad), PI * 1.5, TAU],
		[size, size - Vector2(rad, rad), 0.0, PI * 0.5], [Vector2(0, size.y), Vector2(rad, size.y - rad), PI * 0.5, PI]]
	for cr: Array in corners:
		var pts := PackedVector2Array([cr[0]])
		for i in 9:
			var a := lerpf(float(cr[2]), float(cr[3]), i / 8.0)
			pts.append(Vector2(cr[1]) + Vector2(cos(a), sin(a)) * rad)
		draw_colored_polygon(pts, BACKDROP)
	var sb := _style(Color(0, 0, 0, 0), int(rad), 4, INK)
	sb.draw_center = false
	draw_style_box(sb, Rect2(Vector2.ZERO, size))


# =============================================================== helpers

func _k(a: float, b: float) -> float:
	return clampf((t - a) / maxf(0.0001, b - a), 0.0, 1.0)


func _pop(t0: float, dur: float = 0.45) -> float:
	return _back(_k(t0, t0 + dur))


## A damped wobble after t0 (for squash and stretch).
func _ring(t0: float, amp: float, freq: float = 16.0, decay: float = 5.0) -> float:
	if t < t0:
		return 0.0
	var d := t - t0
	return amp * sin(d * freq) * exp(-d * decay) * _motion


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)


static func _ease_in_out(x: float) -> float:
	var y := clampf(x, 0.0, 1.0)
	return y * y * (3.0 - 2.0 * y)


static func _back(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


static func _elastic(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * x) * sin((x * 10.0 - 0.75) * TAU / 3.0) + 1.0


static func _hash(i: int, salt: int = 0) -> float:
	var v := sin(float(i) * 12.9898 + float(salt) * 78.233) * 43758.5453
	return v - floor(v)


static func _bezier(a: Vector2, ctrl: Vector2, b: Vector2, u: float) -> Vector2:
	return a.lerp(ctrl, u).lerp(ctrl.lerp(b, u), u)


static func _cubic(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, u: float) -> Vector2:
	return a.bezier_interpolate(c1, c2, b, clampf(u, 0.0, 1.0))


static func _xform(pos: Vector2, rot: float = 0.0, scl: Vector2 = Vector2.ONE, skew: float = 0.0) -> Transform2D:
	return Transform2D(rot, scl, skew, pos)


## A transform that rotates / scales / skews about the point p (in the current space).
static func _about(p: Vector2, rot: float, scl: Vector2, skew: float = 0.0) -> Transform2D:
	return Transform2D(rot, scl, skew, p) * Transform2D(0.0, Vector2.ONE, 0.0, -p)


func _push(xf: Transform2D) -> void:
	_xf_stack.append(_xf)
	_xf = _xf * xf
	draw_set_transform_matrix(_xf)


func _pop_xf() -> void:
	if _xf_stack.is_empty():
		_xf = Transform2D.IDENTITY
	else:
		_xf = _xf_stack.pop_back()
	draw_set_transform_matrix(_xf)


func _ell_pts(c: Vector2, r: Vector2, n: int = 36, rot: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


func _ell(c: Vector2, r: Vector2, col: Color, rot: float = 0.0) -> void:
	draw_colored_polygon(_ell_pts(c, r, 36, rot), col)


## A filled ellipse with an ink outline.
func _blob(c: Vector2, r: Vector2, fill: Color, ow: float = 4.0, rot: float = 0.0) -> void:
	var pts := _ell_pts(c, r, 40, rot)
	draw_colored_polygon(pts, fill)
	if ow > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, INK, ow, true)


func _circ(c: Vector2, r: float, fill: Color, ow: float = 4.0) -> void:
	draw_circle(c, r, fill, true, -1.0, true)
	if ow > 0.0:
		draw_arc(c, r, 0.0, TAU, 40, INK, ow, true)


## Text centred on `at` (align 0.5; 0 = left-aligned at at.x). outline > 0 draws a halo. k pops it.
func _text(s: String, at: Vector2, px: int, col: Color, weight: int = 700, outline: int = 0, ocol: Color = Palette.PAPER, align: float = 0.5, k: float = 1.0) -> void:
	if k <= 0.01 or col.a <= 0.01:
		return
	var f := UiKit.font(weight)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var p := Vector2(at.x - w * align, at.y + (f.get_ascent(px) - f.get_descent(px)) * 0.5)
	var scaled := k < 0.999 or k > 1.001
	if scaled:
		_push(_about(at, 0.0, Vector2.ONE * k))
	if outline > 0:
		draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, outline, ocol)
	draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)
	if scaled:
		_pop_xf()


## A rounded label chip, popping in with k.
func _chip(s: String, at: Vector2, bg: Color, px: int = 20, fg: Color = INK, k: float = 1.0, rot: float = 0.0) -> void:
	if k <= 0.01:
		return
	var f := UiKit.font(700)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var h := px * 1.25 + 10.0
	_push(_about(at, rot, Vector2.ONE * k))
	var rr := Rect2(at - Vector2(w * 0.5 + 14.0, h * 0.5), Vector2(w + 28.0, h))
	_rbox(Rect2(rr.position + Vector2(0, 4), rr.size), Color(INK, 0.22), int(h * 0.5), 0)
	_rbox(rr, bg, int(h * 0.5), 3)
	_text(s, at, px, fg, 700)
	_pop_xf()


func _rbox(r: Rect2, bg: Color, radius: int, border: int, border_col: Color = INK) -> void:
	draw_style_box(_style(bg, radius, border, border_col), r)


## StyleBoxFlat cache (one per look), so drawing every frame does not allocate.
func _style(bg: Color, radius: int, border: int, border_col: Color) -> StyleBoxFlat:
	var key := "%s|%d|%d|%s" % [bg.to_html(), radius, border, border_col.to_html()]
	if _box_cache.has(key):
		return _box_cache[key]
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_col
	sb.anti_aliasing = true
	if _box_cache.size() > 400:
		_box_cache.clear()
	_box_cache[key] = sb
	return sb


static func _rect_perimeter(r: Rect2, d: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	var per := 2.0 * (w + h)
	var x := fposmod(d, per)
	if x < w:
		return r.position + Vector2(x, 0)
	x -= w
	if x < h:
		return r.position + Vector2(w, x)
	x -= h
	if x < w:
		return r.position + Vector2(w - x, h)
	x -= w
	return r.position + Vector2(0, h - x)
