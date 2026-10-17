class_name AoDanceCard
extends Control
## AoDanceCard: the always-on "dance card" strip (ui/ only). Three chips that state the whole
## Hughson-Westlake rule, so a newcomer never has to remember Hoot's tips:
##   [HEARD -> down 10]  [MISSED -> up 5]  [2 hits going up -> STORE]
## While nothing has been heard yet at this pitch, the middle chip reads "NOTHING YET -> up 10"
## (the familiarisation climb). pulse(i) makes one chip bounce and glow: the screen pulses the
## chip that matches session.recommended_action() after every answer.

const CHIP_HEARD := 0
const CHIP_MISSED := 1
const CHIP_STORE := 2

var climbing: bool = true:
	set(v):
		if v != climbing:
			climbing = v
			queue_redraw()
## (v3) The masked (plateau) dance: [HEARD -> noise +5] [MISSED -> tone +5] [3 noise ups -> STORE].
var masked: bool = false:
	set(v):
		if v != masked:
			masked = v
			queue_redraw()
var _pulse: Array[float] = [0.0, 0.0, 0.0]
var _lit := -1
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Bounce chip i (0 heard, 1 missed, 2 store) and keep it lit until the next pulse or clear().
func pulse(i: int) -> void:
	if i < 0 or i > 2:
		return
	_pulse[i] = 1.0
	_lit = i
	queue_redraw()


func clear() -> void:
	_lit = -1
	queue_redraw()


func lit() -> int:
	return _lit


func _process(delta: float) -> void:
	_t += delta
	var busy := _lit >= 0
	for i in 3:
		if _pulse[i] > 0.0:
			_pulse[i] = maxf(0.0, _pulse[i] - delta * 1.6)
			busy = true
	if busy:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Color("#3b3154"), 16)
	var pad := 6.0
	var gap := 5.0
	var w := (r.size.x - pad * 2.0 - gap * 2.0) / 3.0
	var h := r.size.y - pad * 2.0 - 2.0
	var specs: Array = [
		["HEARD", "down 10", Palette.PRESS_LIME, 0],
		["NOTHING YET" if climbing else "MISSED", "up 10" if climbing else "up 5", Palette.LCD_TEXT, 1],
		["2x GOING UP", "STORE", Palette.MINT, 2],
	]
	if masked:
		specs = [
			["HEARD", "noise +5", Palette.PRESS_LIME, 0],
			["MISSED", "tone +5", Palette.LCD_TEXT, 1],
			["3 NOISE UPS", "STORE", Palette.MINT, 2],
		]
	for i in 3:
		var spec: Array = specs[i]
		var cell := Rect2(Vector2(pad + i * (w + gap), pad), Vector2(w, h))
		var p := _pulse[i]
		var on := _lit == i
		var s := 1.0 + 0.16 * sin(minf(1.0, (1.0 - p) * 2.0) * PI) * p
		var rc := Rect2(cell.get_center() - cell.size * 0.5 * s, cell.size * s)
		var glow := 0.5 + 0.5 * sin(_t * 6.0)
		if on:
			AoDraw.rbox(self, rc.grow(3.0 + 2.0 * glow), Color(Palette.SELECT_ORANGE, 0.35 + 0.3 * glow), 12)
		AoDraw.rbox(self, rc, Palette.LCD_BG.lerp(Palette.SELECT_ORANGE, 0.25) if on else Palette.LCD_BG, 10, 2, Palette.SELECT_ORANGE if on else Color(Palette.LCD_DIM, 0.9))
		# icon: filled lime dot (heard), hollow dot (missed), stamp-ish square (store)
		var ic := Vector2(rc.position.x + 13.0, rc.get_center().y)
		match int(spec[3]):
			0:
				draw_circle(ic, 6.0, Palette.PRESS_LIME)
			1:
				draw_arc(ic, 5.5, 0.0, TAU, 16, Palette.LCD_TEXT, 2.5, true)
			2:
				AoDraw.rbox(self, Rect2(ic - Vector2(6, 6), Vector2(12, 12)), Palette.MINT, 3)
		var tx := rc.position.x + 24.0
		var tw := rc.size.x - 27.0
		var top_fs := 11 if String(spec[0]).length() <= 9 else 10
		AoDraw.text_c(self, Vector2(tx + tw * 0.5, rc.position.y + rc.size.y * 0.3), String(spec[0]), top_fs, Color(Palette.LCD_TEXT, 0.8), AoDraw.FONT_BOLD)
		var arrow_col: Color = spec[2]
		var bottom := String(spec[1])
		var by := rc.position.y + rc.size.y * 0.72
		var bw := AoDraw.text_size(bottom, 14, AoDraw.FONT_BOLD).x
		var bx := tx + tw * 0.5 - (bw + 14.0) * 0.5
		if int(spec[3]) == 0:
			UiDraw.triangle(self, Vector2(bx + 5.0, by + 1.0), 9.0, masked, arrow_col)
		elif int(spec[3]) == 1:
			UiDraw.triangle(self, Vector2(bx + 5.0, by), 9.0, true, Palette.SUNNY)
		else:
			UiDraw.arrow(self, Vector2(bx + 5.0, by), 10.0, Vector2.RIGHT, arrow_col)
		AoDraw.text_l(self, Vector2(bx + 14.0, by), bottom, 14, Palette.SUNNY if int(spec[3]) == 1 else arrow_col, AoDraw.FONT_BOLD)
