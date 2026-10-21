extends Control
## BingoNight (Day 15, docs/TUNEUP.md §1 beat 5): the payoff, a drawn scene over the clinic. Saturday at
## Bev's hall: Bev calls from the stage, the crowd chatters behind Gus, and with the noisy-places
## program on, a cone from Gus's aids points at Bev while the chatter behind him fades. A ball pops,
## Gus daubs his card, BINGO. Not interactive; the level plays the lines between the calls.
## Story-internal:
##   var b := BingoNight.new(); hud.add_game(b)
##   await b.open()            # the hall fades in
##   b.set_program(true)       # the forward cone on, the chatter behind dimmed
##   b.call_ball(22)           # a ball rolls out of the cage
##   await b.bingo()           # the daub, the BINGO burst and confetti
##   await b.close()           # fades out and frees itself

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")

## Drawn DOWN px lower than these coordinates, below the HUD bar.
const HALL := Rect2(90, 64, 1100, 430)
const DOWN := 24.0
const BEV_AT := Vector2(640, 168)
const CAGE_AT := Vector2(780, 178)
const GUS_AT := Vector2(560, 376)
const DORIS_AT := Vector2(700, 388)
const CARD_AT := Rect2(470, 420, 180, 64)
## The crowd behind and beside Gus: [position, hair colour index].
const CROWD: Array = [
	[Vector2(200, 300), 0], [Vector2(290, 330), 1], [Vector2(380, 300), 2], [Vector2(240, 400), 3],
	[Vector2(340, 420), 1], [Vector2(880, 300), 2], [Vector2(970, 330), 0], [Vector2(1060, 300), 3],
	[Vector2(920, 400), 1], [Vector2(1030, 420), 2],
]
const HAIR: Array[Color] = [Color("#7a5236"), Color("#d9d4cc"), Color("#2e2442"), Color("#c46a1c")]
const WALL := Color("#ffe8c7")
const FLOOR := Color("#e9c79b")
const CONE := Color("#5bc8a3")

var _t := 0.0
var _program := 0.0
var _program_on := false
var _ball := -1
var _ball_t := 0.0
var _bingo_t := -1.0
var _canvas: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas = UiKit.full_rect()
	_canvas.draw.connect(_draw_hall)
	add_child(_canvas)
	modulate.a = 0.0


## (coroutine) The hall fades in.
func open() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.4)
	Sfx.play(&"whoosh", 0.9, -14.0)
	await t.finished


func set_program(on: bool) -> void:
	_program_on = on
	if on:
		Sfx.play(&"ding", 1.4, -14.0)


func call_ball(n: int) -> void:
	_ball = n
	_ball_t = 0.0
	Sfx.play(&"click", 0.7, -10.0)


## (coroutine) Gus daubs the number: the BINGO burst.
func bingo() -> void:
	_bingo_t = 0.0
	Sfx.play(&"stamp", 1.0, -8.0)
	Sfx.play(&"ding", 1.0, -10.0)
	await get_tree().create_timer(1.0, false).timeout


## (coroutine) Fades out and frees itself.
func close() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished
	queue_free()


func is_program_on() -> bool:
	return _program_on


func _process(delta: float) -> void:
	_t += delta
	_ball_t += delta
	_program = move_toward(_program, 1.0 if _program_on else 0.0, delta * 2.5)
	if _bingo_t >= 0.0:
		_bingo_t += delta
	_canvas.queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_hall() -> void:
	var ci := _canvas
	var f := UiKit.font(700)
	ci.draw_set_transform(Vector2(0, DOWN))
	UiDraw.rounded_rect(ci, Rect2(HALL.position + Vector2(0, 8), HALL.size), Color(Palette.INK, 0.3), 24)
	UiDraw.rounded_rect(ci, HALL, WALL, 24, 4, Palette.INK)
	ci.draw_rect(Rect2(HALL.position.x + 4, 270, HALL.size.x - 8, HALL.end.y - 274), FLOOR)
	# bunting along the top
	for k in 22:
		var x := HALL.position.x + 30 + 48.0 * float(k)
		var col: Color = [Palette.CORAL, Palette.SUNNY, Palette.SKY, CONE][k % 4]
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x, 78), Vector2(x + 36, 78), Vector2(x + 18, 104)]), col)
	ci.draw_string(f, Vector2(HALL.position.x + 28, 136), "TOWN HALL BINGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.INK)
	ci.draw_string(f, Vector2(HALL.position.x + 28, 160), "SATURDAY NIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)
	# the stage and Bev
	UiDraw.rounded_rect(ci, Rect2(BEV_AT.x - 150, 222, 340, 30), Color("#b8732e"), 8, 3, Palette.INK)
	Portraits.draw(ci, "Bev", BEV_AT, 50.0, fmod(_t, 0.5) < 0.25 and _ball >= 0 and _ball_t < 1.5, fmod(_t, 3.0) < 0.12)
	_draw_cage(ci, f)
	_draw_cone(ci)
	_draw_crowd(ci)
	Portraits.draw(ci, "Doris", DORIS_AT, 40.0, false, fmod(_t + 1.0, 3.4) < 0.12)
	Portraits.draw(ci, "Gus", GUS_AT, 44.0, _bingo_t >= 0.0, fmod(_t, 2.8) < 0.12)
	_draw_card(ci, f)
	if _bingo_t >= 0.0:
		_draw_bingo(ci, f)


func _draw_cage(ci: CanvasItem, f: Font) -> void:
	var spin := _t * 3.0
	ci.draw_circle(CAGE_AT, 34.0, Color(Palette.PAPER, 0.7))
	for k in 6:
		var a := spin + TAU * float(k) / 6.0
		ci.draw_line(CAGE_AT + Vector2(cos(a), sin(a) * 0.3) * 34.0, CAGE_AT - Vector2(cos(a), sin(a) * 0.3) * 34.0, Color(Palette.INK, 0.5), 2.0)
	ci.draw_arc(CAGE_AT, 34.0, 0.0, TAU, 32, Palette.INK, 3.0, true)
	if _ball < 0:
		return
	var k := clampf(_ball_t / 0.5, 0.0, 1.0)
	var c := CAGE_AT.lerp(CAGE_AT + Vector2(90, 30), k) + Vector2(0, -sin(k * PI) * 40.0)
	var r := 26.0 + 4.0 * sin(clampf(_ball_t, 0.0, 1.0) * PI)
	ci.draw_circle(c, r + 3.0, Palette.INK)
	ci.draw_circle(c, r, Palette.SUNNY)
	ci.draw_circle(c, r * 0.62, Palette.PAPER)
	var s := str(_ball)
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	ci.draw_string(f, c + Vector2(-sw * 0.5, 8), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.INK)


## The noisy-places program: a cone from Gus toward Bev (the mics focus forward).
func _draw_cone(ci: CanvasItem) -> void:
	if _program <= 0.01:
		return
	var tip := GUS_AT + Vector2(0, -30)
	var a := Color(CONE, 0.28 * _program)
	ci.draw_colored_polygon(PackedVector2Array([tip, BEV_AT + Vector2(-110, 40), BEV_AT + Vector2(110, 40)]), a)
	for k in 3:
		var u := fmod(_t * 0.8 + float(k) / 3.0, 1.0)
		var p := tip.lerp(BEV_AT + Vector2(0, 40), u)
		ci.draw_arc(p, 22.0 + 50.0 * u, -PI * 0.5 - 0.5, -PI * 0.5 + 0.5, 10, Color(CONE.darkened(0.3), 0.7 * _program * (1.0 - u)), 3.0, true)


func _draw_crowd(ci: CanvasItem) -> void:
	var calm := 1.0 - 0.7 * _program
	for k in CROWD.size():
		var p: Vector2 = CROWD[k][0]
		var bob := sin(_t * 5.0 + float(k)) * 3.0
		var c := p + Vector2(0, bob)
		ci.draw_circle(c + Vector2(0, 46), 34.0, Color("#9fb8d9").darkened(0.08 * float(k % 3)))
		ci.draw_circle(c, 26.0, Palette.INK)
		ci.draw_circle(c, 23.0, Color("#ffcf9e"))
		ci.draw_arc(c + Vector2(0, -4), 23.0, PI, TAU, 16, HAIR[int(CROWD[k][1])], 9.0, true)
		# chatter squiggles, faded when the program is on
		var sq := Color(Palette.CORAL, 0.75 * calm)
		var side := -1.0 if p.x < 640.0 else 1.0
		var o := c + Vector2(side * 30.0, -26.0)
		var pts := PackedVector2Array()
		for j in 7:
			pts.append(o + Vector2(side * 4.0 * float(j), sin(_t * 12.0 + float(j + k)) * 4.0 - 3.0 * float(j)))
		ci.draw_polyline(pts, sq, 3.0, true)


func _draw_card(ci: CanvasItem, f: Font) -> void:
	UiDraw.rounded_rect(ci, CARD_AT, Palette.PAPER, 8, 3, Palette.INK)
	var nums: Array[int] = [7, 22, 41, 58, 63]
	for k in nums.size():
		var c := CARD_AT.position + Vector2(20 + 35 * k, 34)
		var s := str(nums[k])
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var daubed := k != 1 or _bingo_t >= 0.0
		if daubed:
			ci.draw_circle(c, 14.0, Color(Palette.CORAL, 0.55))
		ci.draw_string(f, c + Vector2(-sw * 0.5, 6), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)


func _draw_bingo(ci: CanvasItem, f: Font) -> void:
	var k := clampf(_bingo_t / 0.3, 0.0, 1.0)
	var sc := lerpf(0.3, 1.0, k) + 0.05 * sin(_bingo_t * 8.0)
	var c := Vector2(640, 300)
	# confetti
	for j in 28:
		var a := TAU * float(j) / 28.0
		var d := 60.0 + 260.0 * clampf(_bingo_t / 1.2, 0.0, 1.0)
		var p := c + Vector2(cos(a), sin(a) * 0.6) * d + Vector2(0, 60.0 * _bingo_t * _bingo_t)
		var col: Color = [Palette.CORAL, Palette.SUNNY, Palette.SKY, CONE][j % 4]
		ci.draw_rect(Rect2(p, Vector2(8, 12)), col)
	ci.draw_set_transform(c + Vector2(0, DOWN), -0.08, Vector2.ONE * sc)
	var s := "BINGO!"
	var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72).x
	UiDraw.rounded_rect(ci, Rect2(-sw * 0.5 - 24, -66, sw + 48, 90), Palette.SUNNY, 18, 5, Palette.INK)
	ci.draw_string(f, Vector2(-sw * 0.5, 4), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 72, Palette.INK)
	ci.draw_set_transform(Vector2(0, DOWN))
