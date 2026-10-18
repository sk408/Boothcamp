extends Control
## CaseProps (cases): the 2D payoff props over the clinic: the referral letter that folds itself into
## an envelope and flies off, the letter that folds into a paper boat and sails to a little lighthouse
## marked EAR DOCTOR, and the big desk phone Hoot calls the ear doctor on (docs/CASES.md §3).
## Story-internal:
##   var p := CaseProps.new(); hud.add_game(p)
##   await p.play("letter")     # the letter writes, folds and flies away
##   await p.play("boat")       # the letter writes, folds into a boat and sails to the lighthouse
##   await p.play("phone")      # the phone rings in; it stays until p.hang_up()
##   p.hang_up()

const UiKit := preload("res://story/ui_kit.gd")
const LETTER_AT := Vector2(640, 300)
const PHONE_AT := Vector2(1080, 300)
const LIGHTHOUSE_AT := Vector2(1110, 330)
const SEA_Y := 380.0

var _kind := ""
var _t := 0.0
var _out_t := -1.0
var _canvas: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UiKit.full_rect()
	_canvas.draw.connect(_draw_props)
	add_child(_canvas)


## (coroutine) Show a prop. "letter" returns once it has flown away; "phone" once it has rung in.
func play(kind: String) -> void:
	_kind = kind
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
		"phone":
			for i in 2:
				Sfx.play(&"chirp", 1.6, -6.0)
				await get_tree().create_timer(0.25, false).timeout
				Sfx.play(&"chirp", 1.4, -6.0)
				await get_tree().create_timer(0.35, false).timeout
			Sfx.play(&"click", 0.8, -4.0)


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
