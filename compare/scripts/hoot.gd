extends Control
## Professor Hoot, the game's owl, as a round portrait that blinks now and then. Drawn in code.

const INK := Color("#2e2442")
const WHITE := Color("#fffdf8")
const SUNNY := Color("#ffd23f")

var talking := false
var _blink := 0.0
var _next := 2.5
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	_next -= delta
	if _next <= 0.0:
		_blink = 0.14
		_next = randf_range(2.5, 5.0)
		queue_redraw()
	elif _blink > 0.0:
		_blink -= delta
		if _blink <= 0.0:
			queue_redraw()


func _draw() -> void:
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var c := size * 0.5
	draw_circle(c, r + 4.0, INK)
	draw_circle(c, r, Color("#ffe6a8"))
	_owl(c, r, _blink > 0.0)


func _owl(c: Vector2, r: float, blink: bool) -> void:
	var b := c + Vector2(0, r * 0.12)
	var br := r * 0.66
	draw_colored_polygon(PackedVector2Array([b + Vector2(br * 0.35, -br * 0.8), b + Vector2(br * 0.75, -br * 0.55), b + Vector2(br * 0.62, -br * 1.18)]), Color("#b9773f"))
	draw_colored_polygon(PackedVector2Array([b + Vector2(-br * 0.4, -br * 0.78), b + Vector2(-br * 0.78, -br * 0.5), b + Vector2(-br * 0.95, -br * 0.88)]), Color("#b9773f"))
	draw_circle(b, br + 3.0, INK)
	draw_circle(b, br, Color("#d9a066"))
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(b + Vector2(x, y) * br * 0.05 + Vector2(0, -br * 0.05))
	draw_colored_polygon(pts, Color("#fff4e2"))
	for s: float in [-1.0, 1.0]:
		var e := b + Vector2(br * 0.33 * s, -br * 0.12)
		if blink:
			draw_arc(e, br * 0.16, 0.3, PI - 0.3, 10, INK, 3.5, true)
		else:
			draw_circle(e, br * 0.2, INK)
			draw_circle(e + Vector2(-br * 0.06, -br * 0.07), br * 0.065, WHITE)
		draw_arc(e + Vector2(0, br * 0.06), br * 0.24, 0.15, PI - 0.15, 12, SUNNY, 3.0, true)
	var beak := b + Vector2(0, br * 0.1)
	draw_colored_polygon(PackedVector2Array([beak + Vector2(-br * 0.1, 0), beak + Vector2(br * 0.1, 0), beak + Vector2(0, br * 0.2)]), Color("#ff9f1c"))
	var cap := b + Vector2(br * 0.05, -br * 0.95)
	var board := PackedVector2Array([cap + Vector2(-br * 0.7, 0), cap + Vector2(0, -br * 0.28), cap + Vector2(br * 0.7, 0), cap + Vector2(0, br * 0.26)])
	draw_colored_polygon(PackedVector2Array([cap + Vector2(-br * 0.36, br * 0.08), cap + Vector2(br * 0.36, br * 0.08), cap + Vector2(br * 0.3, br * 0.3), cap + Vector2(-br * 0.3, br * 0.3)]), INK)
	draw_colored_polygon(board, INK)
	draw_line(cap, cap + Vector2(br * 0.55, br * 0.05), SUNNY, 2.5, true)
	draw_line(cap + Vector2(br * 0.55, br * 0.05), cap + Vector2(br * 0.57, br * 0.42), SUNNY, 2.5, true)
	draw_circle(cap + Vector2(br * 0.57, br * 0.45), 4.0, SUNNY)
