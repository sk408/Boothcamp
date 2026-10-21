class_name SpGhost
extends Control
## SpGhost: the Cross-Hearing Ghost in the booth window (ui/speech only; CONTRACTS.md §9.17.1,
## CHAPTER4 §5.4). The screen lays it over AoBoothWindow.glass_rect(), on the side of the ear that
## is NOT being tested (the patient faces us: her right ear is on the viewer's left).
##   - lurk: on coached lists, while noise is needed and off, it hovers at `lurk` alpha
##     (SpeechRules.ghost_alpha: faint from the first level that needs noise, bold 20 dB above)
##   - pop(): on a solo list, the BOO with the confirm chip (it stays out until the noise goes on
##     or the list starts)
##   - bust(): the noise went on; the screen's AoFx.ghost() carries it off ("GHOST BUSTED!")
## Reduced motion: it fades in and out instead of floating, and the BOO pops without a bounce.

## Which side of the glass it peeks from: -1 = the viewer's left, +1 = the right.
var side := 1.0
## The lurking alpha the screen asks for (0 = gone).
var lurk := 0.0
var _boo := false
var _boo_t := 0.0
var _alpha := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## BOO! (a solo list's unmasked PRESENT).
func pop() -> void:
	_boo = true
	_boo_t = 0.0
	queue_redraw()


func is_booing() -> bool:
	return _boo


## The noise went on: it leaves at once. Returns its centre (canvas) for the AoFx ghost.
func bust() -> Vector2:
	var at := center_global()
	_boo = false
	lurk = 0.0
	_alpha = 0.0
	queue_redraw()
	return at


## Gone without a fuss (the list started, or a new list).
func reset() -> void:
	_boo = false
	lurk = 0.0
	_alpha = 0.0
	queue_redraw()


## The alpha it is drawn at now (the tests read it).
func shown_alpha() -> float:
	return _alpha


func center_global() -> Vector2:
	return get_global_transform_with_canvas() * _center()


func _center() -> Vector2:
	var x := size.x * (0.5 + 0.34 * side)
	return Vector2(x, size.y * 0.52)


func _process(delta: float) -> void:
	_t += delta
	_boo_t += delta
	var target := 1.0 if _boo else lurk
	_alpha = move_toward(_alpha, target, delta * (4.0 if AoFx._reduced() else 2.5))
	queue_redraw()


func _draw() -> void:
	if _alpha <= 0.01:
		return
	var reduced := AoFx._reduced()
	var c := _center()
	if not reduced:
		c.y += sin(_t * 2.4) * 5.0
		c.x += sin(_t * 1.1) * 3.0
	var s := 1.0
	if _boo and not reduced:
		# pops out with a little overshoot (back-out easing from half size)
		var e := clampf(_boo_t / 0.3, 0.0, 1.0) - 1.0
		s = 0.5 + 0.5 * (1.0 + 2.70158 * e * e * e + 1.70158 * e * e)
	_draw_ghost(c, s * minf(1.2, size.y / 120.0), _alpha)
	if _boo:
		var at := c + Vector2(-side * 46.0, -40.0)
		AoDraw.rbox(self, Rect2(at - Vector2(34, 15), Vector2(68, 30)), Color(Palette.PAPER, _alpha), 12, 3, Color(Palette.INK, _alpha))
		AoDraw.text_c(self, at, "BOO!", 18, Color(Palette.CORAL.darkened(0.2), _alpha), AoDraw.FONT_BOLD)


## The sheet ghost (the same little fellow AoFx flies on Day 2).
func _draw_ghost(c: Vector2, scale: float, alpha: float) -> void:
	draw_set_transform(c, 0.0, Vector2.ONE * scale)
	var body := Color(1, 1, 1, alpha)
	var ink := Color(Palette.INK, alpha)
	var shape := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		shape.append(Vector2(cos(a), sin(a)) * 24.0 + Vector2(0, -6))
	for i in 7:
		var x := 24.0 - 48.0 * i / 6.0
		var wav := 0.0 if AoFx._reduced() else 6.0 * sin(_t * 8.0 + i * 1.6)
		shape.append(Vector2(x, 22.0 + (8.0 if i % 2 == 0 else 0.0) + wav * 0.4))
	draw_colored_polygon(shape, Color(Palette.PLUM.lightened(0.6), 0.5 * alpha))
	var inner := PackedVector2Array()
	for p: Vector2 in shape:
		inner.append(p * 0.9 + Vector2(0, -1))
	draw_colored_polygon(inner, body)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, ink, 3.0, true)
	draw_circle(Vector2(-8, -8), 4.5, ink)
	draw_circle(Vector2(8, -8), 4.5, ink)
	draw_circle(Vector2(-6.5, -9.5), 1.5, body)
	draw_circle(Vector2(9.5, -9.5), 1.5, body)
	if _boo:
		draw_arc(Vector2(0, 6), 6.0, 0.0, TAU, 16, ink, 3.0, true)
	else:
		draw_arc(Vector2(0, 7), 4.0, PI * 1.1, PI * 1.9, 8, ink, 2.5, true)
	draw_circle(Vector2(-15, 1), 3.5, Color(Palette.CORAL, 0.45 * alpha))
	draw_circle(Vector2(15, 1), 3.5, Color(Palette.CORAL, 0.45 * alpha))
	draw_set_transform(Vector2.ZERO)
