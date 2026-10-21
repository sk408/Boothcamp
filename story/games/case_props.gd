extends Control
## CaseProps (cases): the 2D payoff props over the clinic: the referral letter that folds itself into
## an envelope and flies off, the letter that folds into a paper boat and sails to a little lighthouse
## marked EAR DOCTOR, and the big desk phone Hoot calls the ear doctor on (docs/CASES.md §3).
## Batch 2: the letter that folds into a paper plane, loops the loop and lands on an EAR DOCTOR runway,
## the jar of wax (EXHIBIT A), and the calendar card that stamps "A WEEK LATER" before a retest.
## Story-internal:
##   var p := CaseProps.new(); hud.add_game(p)
##   await p.play("letter")     # the letter writes, folds and flies away
##   await p.play("boat")       # the letter writes, folds into a boat and sails to the lighthouse
##   await p.play("plane")      # the letter writes, folds into a plane, loops and lands by EAR DOCTOR
##   await p.play("wax_jar")    # the plug in a jar bounces in, sparkles and slides away
##   await p.play("later", "A WEEK LATER")   # pages flip, the caption stamps on; returns as it goes
##   await p.play("phone")      # the phone rings in; it stays until p.hang_up()
##   p.hang_up()

const UiKit := preload("res://story/ui_kit.gd")
const LETTER_AT := Vector2(640, 300)
const PHONE_AT := Vector2(1080, 300)
const LIGHTHOUSE_AT := Vector2(1110, 330)
const SEA_Y := 380.0
const CAL_AT := Vector2(640, 280)
const CAL_FIRST_DAY := 12
## Pages the calendar crosses off (the wax retest's card says A WEEK LATER), one every LATER_STEP s
## from 0.25 s, so the last page turns just as the whoosh lands at 0.95 s.
const LATER_PAGES := 7
const LATER_STEP := 0.1
const JAR_AT := Vector2(640, 300)
const JAR_OUT_T := 2.2  ## when the jar slides away (it has landed by 0.6, then holds 1.6 s)
const JAR_SPARKLES: Array[Vector2] = [Vector2(-122, -70), Vector2(118, -104), Vector2(126, 36), Vector2(-116, 80), Vector2(8, -150)]
const WAX_AMBER := Color("#b8732e")
const WAX_DARK := Color("#7f4a1d")
const WAX_LIGHT := Color("#e6a75c")
const RUNWAY_Y := 420.0
const LOOP_AT := Vector2(760, 190)  ## the centre of the plane's loop-the-loop
const LOOP_R := 70.0
const PLANE_TOUCH := Vector2(960, RUNWAY_Y - 14.0)  ## where the plane touches down

var _kind := ""
var _text := ""
var _t := 0.0
var _out_t := -1.0
var _canvas: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UiKit.full_rect()
	_canvas.draw.connect(_draw_props)
	add_child(_canvas)


## (coroutine) Show a prop. "letter" returns once it has flown away; "phone" once it has rung in;
## "plane" once it has landed; "wax_jar" once it has slid away; "later" as the card slides away.
## text: the later card's caption ("LATER" when empty); the other props ignore it.
func play(kind: String, text: String = "") -> void:
	_kind = kind
	_text = text
	_t = 0.0
	_out_t = -1.0
	visible = true
	match kind:
		"letter":
			Sfx.play(&"pen", 1.0, -6.0)
			await get_tree().create_timer(1.1, false).timeout
			Sfx.play(&"whoosh", 1.2, -6.0)
			await get_tree().create_timer(0.9, false).timeout
			Sfx.play(&"door", 1.6, -14.0)
			_kind = ""
		"boat":
			Sfx.play(&"pen", 1.0, -6.0)
			await get_tree().create_timer(1.1, false).timeout
			Sfx.play(&"whoosh", 1.0, -8.0)
			await get_tree().create_timer(0.4, false).timeout
			Sfx.play(&"note", 0.8, -14.0)
			await get_tree().create_timer(1.7, false).timeout
			Sfx.play(&"ding", 1.3, -6.0)
			await get_tree().create_timer(0.7, false).timeout
			_kind = ""
		"plane":
			Sfx.play(&"pen", 1.0, -6.0)
			await get_tree().create_timer(1.1, false).timeout
			Sfx.play(&"whoosh", 1.0, -8.0)
			await get_tree().create_timer(0.75, false).timeout
			Sfx.play(&"whoosh", 1.5, -10.0)
			await get_tree().create_timer(1.55, false).timeout
			Sfx.play(&"ding", 1.3, -6.0)
			await get_tree().create_timer(0.6, false).timeout
			_kind = ""
		"wax_jar":
			Sfx.play(&"whoosh", 0.9, -10.0)
			await get_tree().create_timer(0.22, false).timeout
			Sfx.play(&"boing", 1.0, -8.0)
			await get_tree().create_timer(0.38, false).timeout
			Sfx.play(&"sparkle", 1.0, -6.0)
			await get_tree().create_timer(JAR_OUT_T - 0.6, false).timeout
			Sfx.play(&"whoosh", 1.3, -10.0)
			await get_tree().create_timer(0.35, false).timeout
			_kind = ""
		"later":
			Sfx.play(&"pop", 0.8, -8.0)
			# each sound waits for the prop's own clock, so the timers' frame overruns can't add up:
			# a pen stroke as each page's X starts, the whoosh and the stamp at 0.95 s and 1.07 s
			# (the times _draw_later draws them)
			for i in LATER_PAGES:
				await _until(0.25 + LATER_STEP * i)
				Sfx.play(&"pen", 1.0 + 0.06 * i, -8.0)
			await _until(0.95)
			Sfx.play(&"whoosh", 1.5, -10.0)
			await _until(1.07)
			Sfx.play(&"stamp", 1.0, -2.0)
			await _until(1.6)
			# it slides away and _process clears it; the runner moves on (and takes its shot of the
			# stamped card) while it goes
			_out_t = 0.0
		"phone":
			for i in 2:
				Sfx.play(&"chirp", 1.6, -6.0)
				await get_tree().create_timer(0.25, false).timeout
				Sfx.play(&"chirp", 1.4, -6.0)
				await get_tree().create_timer(0.35, false).timeout
			Sfx.play(&"click", 0.8, -4.0)


## Waits until the prop's clock (_t, which play() resets) reaches `at` seconds.
func _until(at: float) -> void:
	await get_tree().create_timer(maxf(0.0, at - _t), false).timeout


## The phone slides away.
func hang_up() -> void:
	if _kind == "phone":
		_out_t = 0.0
		Sfx.play(&"click", 0.7, -6.0)


func _process(delta: float) -> void:
	_t += delta
	if _out_t >= 0.0:
		_out_t += delta
		if _out_t > 0.4:
			_kind = ""
			_out_t = -1.0
	_canvas.queue_redraw()


func _draw_props() -> void:
	match _kind:
		"letter":
			_draw_letter()
		"boat":
			_draw_boat()
		"phone":
			_draw_phone()
		"plane":
			_draw_plane()
		"wax_jar":
			_draw_wax_jar()
		"later":
			_draw_later()


func _draw_letter() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var fr := UiKit.font(600)
	var rise := clampf(_t / 0.3, 0.0, 1.0)
	var fold := clampf((_t - 1.0) / 0.35, 0.0, 1.0)
	var fly := clampf((_t - 1.35) / 0.6, 0.0, 1.0)
	var at := LETTER_AT + Vector2(0, (1.0 - rise) * 300.0) + Vector2(fly * 760.0, -fly * 260.0)
	var sc := lerpf(1.0, 0.45, fold) * lerpf(1.0, 0.5, fly)
	c.draw_set_transform(at, -0.05 - fly * 0.6, Vector2.ONE * sc)
	if fold < 1.0:
		var h := lerpf(260.0, 120.0, fold)
		var r := Rect2(Vector2(-110, -h * 0.5), Vector2(220, h))
		UiDraw.rounded_rect(c, Rect2(r.position + Vector2(0, 6), r.size), Color(Palette.INK, 0.25), 8)
		UiDraw.rounded_rect(c, r, Palette.PAPER, 8, 3, Palette.INK)
		if fold < 0.4:
			c.draw_string(f, r.position + Vector2(16, 30), "REFERRAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.RIGHT_RED)
			c.draw_string(fr, r.position + Vector2(16, 56), "Dear Doctor,", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK)
			var lines := int(clampf(_t / 0.12, 0.0, 7.0))
			for i in lines:
				var w := 150.0 - 30.0 * float(i % 3)
				c.draw_line(r.position + Vector2(16, 78 + i * 18), r.position + Vector2(16 + w, 78 + i * 18), Palette.INK_SOFT, 3.0, true)
			if _t > 0.85:
				c.draw_string(f, r.position + Vector2(120, h - 18), "- Hoot", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
	else:
		var r2 := Rect2(Vector2(-110, -60), Vector2(220, 120))
		UiDraw.rounded_rect(c, r2, Color("#fff1d6"), 6, 3, Palette.INK)
		c.draw_polyline(PackedVector2Array([r2.position, r2.get_center() + Vector2(0, 8), Vector2(r2.end.x, r2.position.y)]), Palette.INK, 3.0, true)
		c.draw_circle(r2.get_center() + Vector2(0, 8), 14.0, Palette.RIGHT_RED)
		c.draw_rect(Rect2(r2.end - Vector2(46, 40), Vector2(32, 28)), Palette.SKY)
		c.draw_rect(Rect2(r2.end - Vector2(46, 40), Vector2(32, 28)), Palette.INK, false, 2.0)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The letter folds into a paper boat and sails over a drawn sea to a lighthouse marked EAR DOCTOR.
func _draw_boat() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var appear := clampf((_t - 1.0) / 0.4, 0.0, 1.0)
	# the sea and the lighthouse fade in while the letter is folding
	if appear > 0.0:
		var a := appear
		var wave := PackedVector2Array()
		for i in 49:
			var x := lerpf(420.0, 1240.0, i / 48.0)
			wave.append(Vector2(x, SEA_Y + sin(x * 0.04 + _t * 3.0) * 6.0))
		var sea := wave.duplicate()
		sea.append(Vector2(1240, SEA_Y + 60))
		sea.append(Vector2(420, SEA_Y + 60))
		c.draw_colored_polygon(sea, Color(Palette.SKY, 0.55 * a))
		c.draw_polyline(wave, Color(Palette.INK, 0.6 * a), 3.0, true)
		var lh := LIGHTHOUSE_AT
		var tower := PackedVector2Array([lh + Vector2(-26, 50), lh + Vector2(-16, -70), lh + Vector2(16, -70), lh + Vector2(26, 50)])
		c.draw_colored_polygon(tower, Color(Palette.PAPER, a))
		for k in 3:
			var y0 := 30.0 - k * 40.0
			var band := PackedVector2Array([lh + Vector2(-25 + k * 3.3, y0), lh + Vector2(-23 + k * 3.3, y0 - 18), lh + Vector2(23 - k * 3.3, y0 - 18), lh + Vector2(25 - k * 3.3, y0)])
			c.draw_colored_polygon(band, Color(Palette.RIGHT_RED, a))
		var ring := tower.duplicate()
		ring.append(tower[0])
		c.draw_polyline(ring, Color(Palette.INK, a), 3.0, true)
		UiDraw.rounded_rect(c, Rect2(lh + Vector2(-20, -96), Vector2(40, 26)), Color(Palette.SUNNY, a), 6, 3, Color(Palette.INK, a))
		c.draw_colored_polygon(PackedVector2Array([lh + Vector2(-24, -96), lh + Vector2(0, -116), lh + Vector2(24, -96)]), Color(Palette.INK, a))
		var sweep := sin(_t * 2.0)
		for s: float in [-1.0, 1.0]:
			var beam := PackedVector2Array([lh + Vector2(0, -83), lh + Vector2(160 * s * absf(sweep), -110), lh + Vector2(160 * s * absf(sweep), -56)])
			c.draw_colored_polygon(beam, Color(Palette.SUNNY, 0.28 * a))
		var tag := "EAR DOCTOR"
		var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		UiDraw.rounded_rect(c, Rect2(lh + Vector2(-w * 0.5 - 10, 58), Vector2(w + 20, 26)), Color(Palette.PAPER, a), 10, 3, Color(Palette.INK, a))
		c.draw_string(f, lh + Vector2(-w * 0.5, 77), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(Palette.INK, a))
	if _t < 1.0:
		_draw_letter()
		return
	# the paper boat: it folds out of the letter, then bobs across to the lighthouse
	var fold := clampf((_t - 1.0) / 0.35, 0.0, 1.0)
	var sail := clampf((_t - 1.4) / 1.7, 0.0, 1.0)
	var ease := sail * sail * (3.0 - 2.0 * sail)
	var start := Vector2(LETTER_AT.x, lerpf(LETTER_AT.y, SEA_Y - 22.0, fold))
	var at := start.lerp(Vector2(LIGHTHOUSE_AT.x - 90.0, SEA_Y - 22.0), ease)
	at.y += sin(_t * 4.0) * 4.0 * sail
	c.draw_set_transform(at, sin(_t * 3.0) * 0.08 * sail, Vector2.ONE * lerpf(1.3, 1.0, fold))
	var hull := PackedVector2Array([Vector2(-60, 0), Vector2(60, 0), Vector2(38, 26), Vector2(-38, 26)])
	c.draw_colored_polygon(hull, Palette.PAPER)
	c.draw_polyline(PackedVector2Array([hull[0], hull[1], hull[2], hull[3], hull[0]]), Palette.INK, 3.0, true)
	var sail_pts := PackedVector2Array([Vector2(-34, 0), Vector2(0, -56), Vector2(34, 0)])
	c.draw_colored_polygon(sail_pts, Palette.PAPER.darkened(0.05))
	c.draw_polyline(PackedVector2Array([sail_pts[0], sail_pts[1], sail_pts[2]]), Palette.INK, 3.0, true)
	for i in 3:
		c.draw_line(Vector2(-18 + i * 4, -8 - i * 9), Vector2(10 - i * 4, -8 - i * 9), Palette.INK_SOFT, 2.0, true)
	c.draw_string(f, Vector2(-30, 18), "REFERRAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.RIGHT_RED)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_phone() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var come := clampf(_t / 0.3, 0.0, 1.0)
	var go := clampf(_out_t / 0.35, 0.0, 1.0) if _out_t >= 0.0 else 0.0
	var at := PHONE_AT + Vector2((1.0 - come) * 300.0 + go * 300.0, 0)
	var ringing := _t < 1.2
	var wob := sin(_t * 45.0) * 0.12 if ringing else 0.0
	c.draw_set_transform(at, wob, Vector2.ONE)
	# body
	var body := PackedVector2Array([Vector2(-70, 40), Vector2(-52, -20), Vector2(52, -20), Vector2(70, 40)])
	c.draw_colored_polygon(body, Palette.CORAL)
	c.draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3], body[0]]), Palette.INK, 4.0, true)
	c.draw_circle(Vector2(0, 12), 22.0, Palette.INK)
	c.draw_circle(Vector2(0, 12), 19.0, Palette.PAPER)
	for i in 8:
		var a := TAU * i / 8.0
		c.draw_circle(Vector2(0, 12) + Vector2(cos(a), sin(a)) * 12.0, 3.0, Palette.INK_SOFT)
	# the handset: on the cradle while ringing, lifted after
	var lift := 0.0 if ringing else -1.0
	c.draw_set_transform(at + Vector2(0, -34 + lift * 30.0), wob + lift * 0.35, Vector2.ONE)
	UiDraw.rounded_rect(c, Rect2(Vector2(-78, -12), Vector2(156, 22)), Palette.CORAL, 10, 4, Palette.INK)
	for s: float in [-1.0, 1.0]:
		UiDraw.rounded_rect(c, Rect2(Vector2(-82 + (s + 1.0) * 62.0, -2), Vector2(40, 24)), Palette.CORAL, 10, 4, Palette.INK)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ringing:
		for s: float in [-1.0, 1.0]:
			for j in 2:
				c.draw_arc(at + Vector2(0, -20), 92.0 + 14.0 * j, -0.4 + (PI if s < 0 else 0.0), 0.4 + (PI if s < 0 else 0.0), 8, Palette.SUNNY, 4.0, true)
		c.draw_string_outline(f, at + Vector2(-64, -96), "RING RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 8, Palette.INK)
		c.draw_string(f, at + Vector2(-64, -96), "RING RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.SUNNY)
	elif _out_t < 0.0:
		var tag := "EAR DOCTOR"
		var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		UiDraw.rounded_rect(c, Rect2(at + Vector2(-w * 0.5 - 10, 54), Vector2(w + 20, 28)), Palette.PAPER, 10, 3, Palette.INK)
		c.draw_string(f, at + Vector2(-w * 0.5, 74), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)


## The letter folds into a paper plane, loops the loop and lands on a little runway marked EAR DOCTOR.
func _draw_plane() -> void:
	var c := _canvas
	var appear := clampf((_t - 1.0) / 0.4, 0.0, 1.0)
	# the runway and its sign fade in while the letter is folding
	if appear > 0.0:
		_draw_runway(appear)
	if _t < 1.0:
		_draw_letter()
		return
	# a puff of paper as it folds
	var puff := clampf((_t - 1.0) / 0.25, 0.0, 1.0)
	if puff < 1.0:
		for i in 6:
			var dir := Vector2.from_angle(TAU * i / 6.0 + 0.3)
			var at := LETTER_AT + dir * lerpf(50.0, 120.0, puff)
			c.draw_circle(at, 12.0 * (1.0 - puff), Color(Palette.PAPER, 1.0 - puff))
			c.draw_arc(at, 12.0 * (1.0 - puff), 0.0, TAU, 12, Color(Palette.INK, 1.0 - puff), 2.0, true)
	# a dotted trail behind it while it flies
	if _t > 1.4 and _t < 3.45:
		for k in range(1, 15):
			var tt := _t - k * 0.045
			if tt < 1.35:
				break
			c.draw_circle(_plane_at(tt), 3.5, Color(Palette.INK_SOFT, 0.55 * (1.0 - k / 15.0)))
	var open := clampf((_t - 1.0) / 0.35, 0.0, 1.0)
	var p := _plane_at(_t)
	var q := _plane_at(_t + 0.02)
	var ang := (q - p).angle() if p.distance_squared_to(q) > 0.01 else 0.0
	c.draw_set_transform(p, ang, Vector2(lerpf(1.4, 1.0, open), lerpf(0.15, 1.0, open)))
	var keel := PackedVector2Array([Vector2(52, 0), Vector2(-28, 0), Vector2(-44, 14)])
	c.draw_colored_polygon(keel, Palette.PAPER.darkened(0.12))
	c.draw_polyline(PackedVector2Array([keel[0], keel[1], keel[2], keel[0]]), Palette.INK, 3.0, true)
	var wing := PackedVector2Array([Vector2(52, 0), Vector2(-44, -24), Vector2(-28, 0)])
	c.draw_colored_polygon(wing, Palette.PAPER)
	c.draw_polyline(PackedVector2Array([wing[0], wing[1], wing[2], wing[0]]), Palette.INK, 3.0, true)
	# a red stripe: it is still the referral
	c.draw_line(Vector2(26, -5), Vector2(-30, -17), Palette.RIGHT_RED, 3.0, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the plane is at time tt: it launches from the letter, loops the loop, glides down to the
## runway and rolls to a stop just short of the sign.
func _plane_at(tt: float) -> Vector2:
	var entry := LOOP_AT + Vector2(0, LOOP_R)
	if tt < 1.35:
		return LETTER_AT
	if tt < 1.85:
		var a := (tt - 1.35) / 0.5
		return LETTER_AT.lerp(entry, a * a)
	if tt < 2.7:
		var th := PI * 0.5 - TAU * (tt - 1.85) / 0.85
		return LOOP_AT + Vector2(cos(th), sin(th)) * LOOP_R
	if tt < 3.4:
		var g := (tt - 2.7) / 0.7
		return entry.bezier_interpolate(entry + Vector2(110, 0), PLANE_TOUCH - Vector2(120, 0), PLANE_TOUCH, g)
	var r := clampf((tt - 3.4) / 0.4, 0.0, 1.0)
	return PLANE_TOUCH + Vector2(80.0 * (1.0 - (1.0 - r) * (1.0 - r)), 0)


## The runway: a windsock, the strip with chasing lights, and the EAR DOCTOR sign at the far end.
func _draw_runway(a: float) -> void:
	var c := _canvas
	var f := UiKit.font(700)
	# the sign stands behind the strip
	var sx := 1160.0
	var tag := "EAR DOCTOR"
	var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	for s: float in [-1.0, 1.0]:
		var px := sx + s * (w * 0.5 - 6.0)
		c.draw_line(Vector2(px, RUNWAY_Y + 6), Vector2(px, RUNWAY_Y - 52), Color(Palette.INK, a), 4.0, true)
	UiDraw.rounded_rect(c, Rect2(Vector2(sx - w * 0.5 - 12, RUNWAY_Y - 84), Vector2(w + 24, 34)), Color(Palette.SUNNY, a), 8, 3, Color(Palette.INK, a))
	c.draw_string(f, Vector2(sx - w * 0.5, RUNWAY_Y - 61), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.INK, a))
	# the windsock flaps, just short of the strip and clear of the glide path
	var wx := 828.0
	c.draw_line(Vector2(wx, RUNWAY_Y + 4), Vector2(wx, RUNWAY_Y - 62), Color(Palette.INK, a), 3.0, true)
	var flap := sin(_t * 9.0) * 3.0
	var sock := PackedVector2Array([Vector2(wx, RUNWAY_Y - 62), Vector2(wx - 44, RUNWAY_Y - 56 + flap), Vector2(wx - 44, RUNWAY_Y - 48 + flap), Vector2(wx, RUNWAY_Y - 42)])
	c.draw_colored_polygon(sock, Color(Palette.CORAL, a))
	var band := PackedVector2Array([sock[0].lerp(sock[1], 0.35), sock[0].lerp(sock[1], 0.65), sock[3].lerp(sock[2], 0.65), sock[3].lerp(sock[2], 0.35)])
	c.draw_colored_polygon(band, Color(Palette.PAPER, a))
	c.draw_polyline(PackedVector2Array([sock[0], sock[1], sock[2], sock[3], sock[0]]), Color(Palette.INK, a), 2.0, true)
	# the strip, its centre dashes and the lights chasing towards the sign
	UiDraw.rounded_rect(c, Rect2(Vector2(840, RUNWAY_Y), Vector2(390, 24)), Color(Palette.LCD_DIM, a), 8, 3, Color(Palette.INK, a))
	for i in 7:
		c.draw_rect(Rect2(Vector2(862 + i * 52, RUNWAY_Y + 10), Vector2(28, 4)), Color(Palette.PAPER, a))
	var lit := int(_t * 10.0) % 9
	for i in 9:
		c.draw_circle(Vector2(852 + i * 46, RUNWAY_Y + 2), 4.0, Color(Palette.SUNNY if i == lit else Palette.PAPER, a))


## EXHIBIT A: a honey-lidded glass jar holding the lumpy wax plug (with a tiny wick). It bounces in,
## sparkles, holds, then slides away to the right.
func _draw_wax_jar() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var land := _bounce_out(clampf(_t / 0.6, 0.0, 1.0))
	var go := clampf((_t - JAR_OUT_T) / 0.35, 0.0, 1.0)
	var shine := clampf((_t - 0.5) / 0.2, 0.0, 1.0) * (1.0 - go)
	var at := JAR_AT + Vector2(go * go * 780.0, (land - 1.0) * 420.0)
	c.draw_set_transform(at, go * 0.3, Vector2.ONE)
	# a soft spotlight: the star exhibit
	if shine > 0.0:
		c.draw_circle(Vector2(0, 8), 150.0 + sin(_t * 4.0) * 6.0, Color(Palette.SUNNY, 0.22 * shine))
	UiDraw.rounded_rect(c, Rect2(Vector2(-84, 104), Vector2(168, 18)), Color(Palette.INK, 0.2), 9)
	var glass := Rect2(Vector2(-80, -78), Vector2(160, 190))
	UiDraw.rounded_rect(c, glass, Color(Palette.SKY, 0.5), 26)
	# the plug: a lumpy amber-brown blob resting on the bottom, with darker flecks and a shine
	var plug := PackedVector2Array()
	for i in 28:
		var ang := TAU * i / 28.0
		var r := 1.0 + 0.12 * sin(ang * 3.0 + 0.7) + 0.07 * sin(ang * 5.0 + 2.1) + 0.04 * sin(ang * 8.0)
		plug.append(Vector2(0, 60) + Vector2(cos(ang) * 56.0, sin(ang) * 38.0) * r)
	c.draw_colored_polygon(plug, WAX_AMBER)
	var fleck := 0
	for spot: Vector2 in [Vector2(-24, 52), Vector2(20, 72), Vector2(30, 50), Vector2(-6, 84), Vector2(-38, 74)]:
		c.draw_circle(spot, 4.0 + (fleck % 3) * 2.0, WAX_DARK)
		fleck += 1
	c.draw_arc(Vector2(-12, 50), 24.0, PI * 1.05, PI * 1.45, 8, WAX_LIGHT, 5.0, true)
	var ring := plug.duplicate()
	ring.append(plug[0])
	c.draw_polyline(ring, Palette.INK, 3.0, true)
	# the tiny wick on top (it is wax, after all)
	var top := plug[21]
	c.draw_polyline(PackedVector2Array([top + Vector2(0, 2), top + Vector2(1, -8), top + Vector2(6, -15), top + Vector2(3, -21)]), Palette.INK, 3.0, true)
	c.draw_circle(top + Vector2(3, -21), 2.5, Palette.INK)
	# the glass front: a faint tint, two shines, the outline, then the lid and the label
	UiDraw.rounded_rect(c, glass, Color(Palette.SKY, 0.15), 26, 4, Palette.INK)
	c.draw_line(Vector2(-60, -50), Vector2(-60, 78), Color(Palette.PAPER, 0.8), 7.0, true)
	c.draw_line(Vector2(-44, -50), Vector2(-44, -22), Color(Palette.PAPER, 0.8), 4.0, true)
	UiDraw.rounded_rect(c, Rect2(Vector2(-70, -104), Vector2(140, 30)), Palette.SUNNY, 8, 4, Palette.INK)
	for i in 9:
		var x := -56.0 + i * 14.0
		c.draw_line(Vector2(x, -98), Vector2(x, -80), Color(Palette.INK, 0.35), 2.0)
	var tag := "EXHIBIT A"
	var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	UiDraw.rounded_rect(c, Rect2(Vector2(-w * 0.5 - 10, -64), Vector2(w + 20, 30)), Palette.PAPER, 6, 3, Palette.INK)
	c.draw_string(f, Vector2(-w * 0.5, -43), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.RIGHT_RED)
	# twinkles
	if shine > 0.0:
		for i in JAR_SPARKLES.size():
			var tw := maxf(0.0, sin(_t * 7.0 + i * 1.9))
			if tw > 0.05:
				var rad := (6.0 + 10.0 * tw) * shine
				UiDraw.star(c, JAR_SPARKLES[i], rad + 3.0, Palette.INK, 4)
				UiDraw.star(c, JAR_SPARKLES[i], rad, Palette.SUNNY, 4)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A bouncy landing curve (0..1 -> 0..1): drops, then two smaller hops.
func _bounce_out(p: float) -> float:
	var q := p
	if q < 1.0 / 2.75:
		return 7.5625 * q * q
	if q < 2.0 / 2.75:
		q -= 1.5 / 2.75
		return 7.5625 * q * q + 0.75
	if q < 2.5 / 2.75:
		q -= 2.25 / 2.75
		return 7.5625 * q * q + 0.9375
	q -= 2.625 / 2.75
	return 7.5625 * q * q + 0.984375


## The time-skip card: a desk calendar drops in, LATER_PAGES pages get a red X and flip up, then the
## caption (_text, or "LATER") stamps on with a jolt; it slides up and away once _out_t runs.
func _draw_later() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var drop := 1.0 - pow(1.0 - clampf(_t / 0.25, 0.0, 1.0), 3.0)
	var go := clampf(_out_t / 0.35, 0.0, 1.0) if _out_t >= 0.0 else 0.0
	var thud := clampf((_t - 1.07) / 0.25, 0.0, 1.0)
	var jolt := sin(thud * TAU * 2.0) * 6.0 * (1.0 - thud) if _t > 1.07 else 0.0
	var at := CAL_AT + Vector2(0, (drop - 1.0) * 400.0 + jolt - go * go * 560.0)
	c.draw_set_transform(at, 0.0, Vector2.ONE)
	UiDraw.rounded_rect(c, Rect2(Vector2(-100, -84), Vector2(200, 214)), Color(Palette.INK, 0.25), 14)
	UiDraw.rounded_rect(c, Rect2(Vector2(-100, -92), Vector2(200, 214)), Palette.PAPER.darkened(0.15), 14, 4, Palette.INK)
	for i in 3:
		c.draw_line(Vector2(-86, 106 + i * 5), Vector2(86, 106 + i * 5), Palette.INK_SOFT, 2.0, true)
	# the top page gets its X, then flips up to the rings and shows the next day under it
	var done := 0
	for i in LATER_PAGES:
		if _t >= 0.25 + LATER_STEP * (i + 1):
			done += 1
	# each page: the X takes the first 40% of its step, the flip the rest
	var start := 0.25 + LATER_STEP * done
	var turn := clampf((_t - start - 0.4 * LATER_STEP) / (0.6 * LATER_STEP), 0.0, 1.0) if done < LATER_PAGES else 0.0
	var scrawl := clampf((_t - start) / (0.4 * LATER_STEP), 0.0, 1.0) if done < LATER_PAGES else 0.0
	if turn > 0.0:
		_draw_cal_page(at, CAL_FIRST_DAY + done + 1, 0.0, 1.0, 0.0)
	_draw_cal_page(at, CAL_FIRST_DAY + done, scrawl, 1.0 - turn, turn)
	c.draw_set_transform(at, 0.0, Vector2.ONE)
	UiDraw.rounded_rect(c, Rect2(Vector2(-100, -92), Vector2(200, 50)), Palette.RIGHT_RED, 14, 4, Palette.INK)
	for s: float in [-1.0, 1.0]:
		UiDraw.rounded_rect(c, Rect2(Vector2(s * 50.0 - 7.0, -104), Vector2(14, 30)), Palette.PAPER, 7, 3, Palette.INK)
	# the stamp falls from big to its size, then lands with a ring of impact ticks
	var fall := clampf((_t - 0.95) / 0.12, 0.0, 1.0)
	if fall > 0.0:
		var cap := _text if _text != "" else "LATER"
		var fs := 54
		var tw := f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > 760.0:
			fs = int(fs * 760.0 / tw)
			tw = f.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var hgt := f.get_height(fs)
		var box := Rect2(Vector2(-tw * 0.5 - 22, -hgt * 0.5 - 8), Vector2(tw + 44, hgt + 16))
		c.draw_set_transform(at + Vector2(0, 34), -0.1, Vector2.ONE * lerpf(2.0, 1.0, fall))
		UiDraw.rounded_rect(c, box, Color(Palette.PAPER, 0.92 * fall), 14, 6, Color(Palette.RIGHT_RED, fall))
		UiDraw.rounded_rect(c, box.grow(-8), Color(0, 0, 0, 0), 9, 2, Color(Palette.RIGHT_RED, fall))
		c.draw_string(f, Vector2(-tw * 0.5, -hgt * 0.5 + f.get_ascent(fs)), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Palette.RIGHT_RED, fall))
		if thud > 0.0 and thud < 1.0:
			var rim := Vector2(box.size.x * 0.5 + 12.0 + thud * 26.0, box.size.y * 0.5 + 12.0 + thud * 18.0)
			for i in 12:
				var dir := Vector2.from_angle(TAU * i / 12.0)
				c.draw_line(dir * rim, dir * rim + dir * 18.0, Color(Palette.INK, 1.0 - thud), 4.0, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One calendar page, hung from the binding at at + (0, -44). scrawl: how much of its red X is drawn;
## squash: its height (1 = flat on the pad, 0 = flipped up out of sight); shade: darkens it as it turns.
func _draw_cal_page(at: Vector2, day: int, scrawl: float, squash: float, shade: float) -> void:
	var c := _canvas
	var f := UiKit.font(700)
	c.draw_set_transform(at + Vector2(0, -44), 0.0, Vector2(1.0, maxf(squash, 0.02)))
	var r := Rect2(Vector2(-90, 0), Vector2(180, 144))
	UiDraw.rounded_rect(c, r, Palette.PAPER, 6, 3, Palette.INK)
	var num := str(day)
	var w := f.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 84).x
	c.draw_string(f, Vector2(-w * 0.5, 104), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 84, Palette.INK)
	if scrawl > 0.0:
		var one := clampf(scrawl * 2.0, 0.0, 1.0)
		var two := clampf(scrawl * 2.0 - 1.0, 0.0, 1.0)
		c.draw_line(Vector2(-54, 26), Vector2(-54, 26).lerp(Vector2(54, 122), one), Palette.RIGHT_RED, 7.0, true)
		if two > 0.0:
			c.draw_line(Vector2(54, 26), Vector2(54, 26).lerp(Vector2(-54, 122), two), Palette.RIGHT_RED, 7.0, true)
	if shade > 0.0:
		UiDraw.rounded_rect(c, r, Color(Palette.INK, 0.35 * shade), 6)
