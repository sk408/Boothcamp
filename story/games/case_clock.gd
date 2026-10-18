extends Control
## CaseClock (cases): the "hours since it started" alarm clock for a sudden hearing loss (docs/CASES.md
## §7.3). It sits in the top-right corner for the whole visit and ticks with game time, one hour per
## game minute: a teaching prop, not a deadline. The bar fills toward CaseRules.SUDDEN_CLOCK_H.
## Story-internal:
##   var k := CaseClock.new(); k.setup(30.0, Game.clock); hud.add_game(k)
##   k.ring()            # the alarm rings (the reveal)
##   k.hours()           # hours since onset right now

const UiKit := preload("res://story/ui_kit.gd")
const BOX := Rect2(1080, 8, 188, 74)

var onset_h := 0.0
var started_at := 0.0
var _canvas: Control
var _ring_t := -1.0
var _t := 0.0
var _last_hour := -1


func setup(p_onset_h: float, p_started_at: float) -> void:
	onset_h = p_onset_h
	started_at = p_started_at


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UiKit.full_rect()
	_canvas.draw.connect(_draw_clock)
	add_child(_canvas)
	Events.phase_changed.connect(func(p: StringName, _i: Dictionary) -> void:
		visible = p != &"audiometry" and p != &"results")


func hours() -> float:
	return CaseRules.hours_since_onset(onset_h, Game.clock - started_at)


func ring() -> void:
	_ring_t = 0.0
	Sfx.play(&"error", 1.4, -6.0)


func _process(delta: float) -> void:
	_t += delta
	if _ring_t >= 0.0:
		_ring_t += delta
		if _ring_t > 2.4:
			_ring_t = -1.0
	var h := int(hours())
	if h != _last_hour:
		if _last_hour >= 0 and visible:
			Sfx.play(&"blip", 0.7, -16.0)
		_last_hour = h
	_canvas.queue_redraw()


func _draw_clock() -> void:
	var c := _canvas
	var f := UiKit.font(700)
	var fr := UiKit.font(600)
	var shake := Vector2(sin(_t * 50.0) * 3.0, 0) if _ring_t >= 0.0 else Vector2.ZERO
	var box := Rect2(BOX.position + shake, BOX.size)
	UiDraw.rounded_rect(c, Rect2(box.position + Vector2(0, 4), box.size), Color(Palette.INK, 0.2), 16)
	UiDraw.rounded_rect(c, box, Palette.PAPER, 16, 3, Palette.RIGHT_RED)
	# the little alarm clock
	var cc := box.position + Vector2(34, 40)
	var wob := sin(_t * 40.0) * 0.2 if _ring_t >= 0.0 else 0.0
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
	c.draw_string(fr, box.position + Vector2(64, 20), "SINCE IT STARTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.INK_SOFT)
	var h := int(hours())
	c.draw_string(f, box.position + Vector2(64, 48), "%d h" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Palette.RIGHT_RED)
	# the bar toward the 72-hour mark
	var bar := Rect2(box.position + Vector2(64, 56), Vector2(box.size.x - 76, 9))
	UiDraw.rounded_rect(c, bar, Color(Palette.INK, 0.12), 4)
	var k := clampf(hours() / float(CaseRules.SUDDEN_CLOCK_H), 0.0, 1.0)
	UiDraw.rounded_rect(c, Rect2(bar.position, Vector2(bar.size.x * k, bar.size.y)), Palette.CORAL, 4)
	c.draw_string(fr, bar.end + Vector2(-22, 12), "%dh" % CaseRules.SUDDEN_CLOCK_H, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.INK_SOFT)
