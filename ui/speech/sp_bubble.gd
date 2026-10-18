class_name SpBubble
extends Control
## SpBubble: the patient's answer, in a big comic speech bubble under the booth window (ui/speech
## only). Only the words he said ("Rainbow!", "...bow?", "Huh?"): it never says whether that was
## right. listen() shows thinking dots while he answers, show_answer() pops the text in, mark()
## adds a small tick or cross badge: what the PLAYER scored. The tail points up at the booth.

const TAIL_H := 18.0

var speaker: String = "Mike"
var state: StringName = &"idle"
var text: String = ""
## Local x the tail's tip points at (the patient in the booth window above).
var tail_x: float = 120.0
var _pop := 0.0
var _mark := 0
var _mark_t := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	state = &"idle"
	text = ""
	_mark = 0
	queue_redraw()


func listen() -> void:
	state = &"listening"
	text = ""
	_mark = 0
	queue_redraw()


func show_answer(said: String) -> void:
	state = &"shown"
	text = said
	_pop = 1.0
	_mark = 0
	queue_redraw()


## The player's verdict: +1 = scored "repeated" (tick), -1 = scored "missed" (cross).
func mark(correct: bool) -> void:
	state = &"scored"
	_mark = 1 if correct else -1
	_mark_t = 0.0
	queue_redraw()


func badge_global() -> Vector2:
	return get_global_transform_with_canvas() * Vector2(size.x - 34.0, TAIL_H + 30.0)


func _process(delta: float) -> void:
	_t += delta
	_pop = maxf(0.0, _pop - delta * 3.5)
	_mark_t += delta
	queue_redraw()


func _draw() -> void:
	var body := Rect2(Vector2(0, TAIL_H), Vector2(size.x, size.y - TAIL_H))
	var s := 1.0 + 0.12 * sin(_pop * PI) * _pop
	var c := body.get_center()
	draw_set_transform(c, 0.0, Vector2.ONE * s)
	var lr := Rect2(body.position - c, body.size)
	var tx := clampf(tail_x, 40.0, size.x - 40.0) - c.x
	var tri := PackedVector2Array([Vector2(tx - 16.0, lr.position.y + 3.0), Vector2(tx + 14.0, lr.position.y + 3.0), Vector2(tx - 22.0, lr.position.y - TAIL_H + 2.0)])
	draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(-4, 0), tri[1] + Vector2(4, 0), tri[2] + Vector2(-2, -4)]), Palette.INK)
	AoDraw.rbox(self, Rect2(lr.position + Vector2(0, 5), lr.size), Color(Palette.INK, 0.25), 24)
	var dim := state == &"scored"
	AoDraw.rbox(self, lr, Palette.PAPER if state != &"idle" else Palette.PAPER.lerp(Palette.CREAM, 0.6), 24, 4, Palette.INK)
	draw_colored_polygon(tri, Palette.PAPER if state != &"idle" else Palette.PAPER.lerp(Palette.CREAM, 0.6))
	# name tab
	var who := "%s says" % speaker
	var nw := AoDraw.text_size(who, 14, AoDraw.FONT_BOLD).x + 22.0
	var nr := Rect2(lr.position + Vector2(lr.size.x - nw - 16.0, -11.0), Vector2(nw, 22.0))
	AoDraw.rbox(self, nr, Palette.SELECT_ORANGE, 11, 3, Palette.INK)
	AoDraw.text_c(self, nr.get_center(), who, 14, Palette.INK, AoDraw.FONT_BOLD)
	var mid := Vector2(0, lr.position.y + lr.size.y * 0.54)
	match state:
		&"idle":
			AoDraw.text_c(self, mid, "(waiting for a word)", 15, Color(Palette.INK_SOFT, 0.7), AoDraw.FONT_SEMI)
		&"listening":
			for i in 3:
				var b := absf(sin(_t * 6.0 - i * 0.8)) * 8.0
				draw_circle(mid + Vector2((i - 1) * 26.0, -b), 7.0, Palette.INK_SOFT)
		&"shown", &"scored":
			_draw_text(mid, lr.size.x - 40.0, Color(Palette.INK, 0.55 if dim else 1.0))
	draw_set_transform(Vector2.ZERO)
	if _mark != 0:
		_draw_badge(Vector2(size.x - 34.0, TAIL_H + 30.0))


func _draw_text(mid: Vector2, max_w: float, col: Color) -> void:
	var fs := 34
	var lines := PackedStringArray([text])
	while fs > 16:
		lines = AoFx._wrap(text, fs, max_w)
		var widest := 0.0
		for ln: String in lines:
			widest = maxf(widest, AoDraw.text_size(ln, fs, AoDraw.FONT_BOLD).x)
		if lines.size() <= 2 and widest <= max_w:
			break
		fs -= 2
	var lh := fs * 1.15
	var y := mid.y - (lines.size() - 1) * lh * 0.5
	for ln: String in lines:
		AoDraw.text_c(self, Vector2(mid.x, y), ln, fs, col, AoDraw.FONT_BOLD)
		y += lh


func _draw_badge(c: Vector2) -> void:
	var k := clampf(_mark_t / 0.22, 0.0, 1.0)
	var s := 1.0 + 0.6 * (1.0 - k) * (1.0 - k)
	var ok := _mark > 0
	var fill := Palette.MINT if ok else Palette.CORAL
	draw_set_transform(c, deg_to_rad(-8.0 * (1.0 - k)), Vector2.ONE * s)
	draw_circle(Vector2(0, 3), 21.0, Color(Palette.INK, 0.3))
	draw_circle(Vector2.ZERO, 21.0, Palette.INK)
	draw_circle(Vector2.ZERO, 17.5, fill)
	if ok:
		UiDraw.check(self, Vector2.ZERO, 20.0, Palette.PAPER, 4.5)
	else:
		UiDraw.cross(self, Vector2.ZERO, 14.0, Palette.PAPER, 4.5)
	draw_set_transform(Vector2.ZERO)
