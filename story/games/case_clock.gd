extends Control
## CaseClock (cases): the hours clock for a sudden hearing loss (docs/CASES.md §7.3). It sits in the
## top-right corner for the whole visit and counts UP the hours since the loss started, in real
## (unscaled, unpaused) minutes: "SINCE IT STARTED  30 h 05 min", captioned "Sooner is better". There is
## no end mark and no "too late": 72 hours is part of the definition of sudden (how fast it came on),
## not a deadline, and doctors still treat after that.
## Story-internal:
##   var k := CaseClock.new(); k.setup(30.0); hud.add_game(k)
##   k.ring()            # the alarm rings, out of one side only (he woke up to it in one ear)
##   k.hours()           # hours since onset right now

const UiKit := preload("res://story/ui_kit.gd")
const BOX := Rect2(1064, 8, 204, 74)

var onset_h := 0.0
var _real_s := 0.0
var _canvas: Control
var _ring_t := -1.0
var _t := 0.0
var _last_minute := -1


func setup(p_onset_h: float) -> void:
	onset_h = p_onset_h
	_real_s = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UiKit.full_rect()
	_canvas.draw.connect(_draw_clock)
	add_child(_canvas)
	Events.phase_changed.connect(func(p: StringName, _i: Dictionary) -> void:
		visible = p != &"audiometry" and p != &"results")


func hours() -> float:
	return CaseRules.hours_since_onset(onset_h, _real_s)


func ring() -> void:
	_ring_t = 0.0
	Sfx.play(&"error", 1.4, -6.0)


func _process(delta: float) -> void:
	_t += delta
	# real seconds: undo the game's speed-ups (Hoot's turns, autoplay); paused frames never get here
	_real_s += delta / maxf(Engine.time_scale, 0.001)
	if _ring_t >= 0.0:
		_ring_t += delta
		if _ring_t > 2.4:
			_ring_t = -1.0
	var m := int(hours() * 60.0)
	if m != _last_minute:
		if _last_minute >= 0 and visible:
			Sfx.play(&"blip", 0.7, -18.0)
		_last_minute = m
	_canvas.queue_redraw()


func _draw_clock() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var fr := UiKit.font(600)
	var ringing := _ring_t >= 0.0
	var shake := Vector2(sin(_t * 50.0) * 3.0, 0) if ringing else Vector2.ZERO
	var box := Rect2(BOX.position + shake, BOX.size)
	UiDraw.rounded_rect(c, Rect2(box.position + Vector2(0, 4), box.size), Color(Palette.INK, 0.2), 16)
	UiDraw.rounded_rect(c, box, Palette.PAPER, 16, 3, Palette.RIGHT_RED)
	# the little alarm clock
	var cc := box.position + Vector2(34, 40)
	var wob := sin(_t * 40.0) * 0.2 if ringing else 0.0
	c.draw_set_transform(cc, wob, Vector2.ONE)
	for s: float in [-1.0, 1.0]:
		c.draw_circle(Vector2(13 * s, -19), 7.0, Palette.INK)
		c.draw_circle(Vector2(13 * s, -19), 5.0, Palette.SUNNY)
	c.draw_circle(Vector2.ZERO, 21.0, Palette.INK)
	c.draw_circle(Vector2.ZERO, 18.0, Palette.CORAL)
	c.draw_circle(Vector2.ZERO, 13.0, Palette.PAPER)
	var a := hours() / 12.0 * TAU
	c.draw_line(Vector2.ZERO, Vector2(sin(a), -cos(a)) * 7.0, Palette.INK, 2.5, true)
	c.draw_line(Vector2.ZERO, Vector2(sin(a * 12.0), -cos(a * 12.0)) * 10.0, Palette.INK, 1.5, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ringing:
		# the ring only comes out of ONE side: he woke up to it in one ear
		for j in 3:
			var rr := 26.0 + 8.0 * j + fmod(_ring_t * 30.0, 8.0)
			c.draw_arc(cc, rr, PI - 0.5, PI + 0.5, 10, Color(Palette.SUNNY.darkened(0.2), 1.0 - j * 0.25), 3.0, true)
		c.draw_string_outline(f, cc + Vector2(-58, -26), "RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Palette.INK)
		c.draw_string(f, cc + Vector2(-58, -26), "RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.SUNNY)
	var h := hours()
	var whole := int(h)
	var mins := int((h - whole) * 60.0)
	c.draw_string(fr, box.position + Vector2(64, 20), "SINCE IT STARTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.INK_SOFT)
	c.draw_string(f, box.position + Vector2(64, 46), "%d h" % whole, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.RIGHT_RED)
	var hw := f.get_string_size("%d h" % whole, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	c.draw_string(f, box.position + Vector2(70 + hw, 46), "%02d min" % mins, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.RIGHT_RED)
	c.draw_string(fr, box.position + Vector2(64, 64), "Sooner is better", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK)
