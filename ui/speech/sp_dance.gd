class_name SpDance
extends Control
## SpDance: the SRT "dance card" strip (ui/speech only), the speech twin of AoDanceCard.
## Three chips state the whole rule so nobody has to remember Hoot's tips:
##   [GOT IT -> down 10]  [MISSED -> up 5]  [BRACKETED -> STORE]
## pulse(i) bounces one chip and keeps it lit. The screen lights the chip for the player's LAST
## score (never while a word waits for its score, so it cannot give the answer away).

const CHIP_GOT := 0
const CHIP_MISSED := 1
const CHIP_STORE := 2

var _pulse: Array[float] = [0.0, 0.0, 0.0]
var _lit := -1
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func pulse(i: int) -> void:
	if i < 0 or i > 2:
		return
	if i != _lit:
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
	for i in 3:
		_pulse[i] = maxf(0.0, _pulse[i] - delta * 1.6)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Color("#3b3154"), 16)
	var pad := 6.0
	var gap := 5.0
	var w := (r.size.x - pad * 2.0 - gap * 2.0) / 3.0
	var h := r.size.y - pad * 2.0 - 2.0
	var specs: Array = [
		["GOT IT", "down 10", Palette.PRESS_LIME],
		["MISSED", "up 5", Palette.SUNNY],
		["BRACKETED", "STORE", Palette.MINT],
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
		AoDraw.rbox(self, rc, Palette.LCD_BG.lerp(Palette.SELECT_ORANGE, 0.25) if on else Palette.LCD_BG, 10, 2,
			Palette.SELECT_ORANGE if on else Color(Palette.LCD_DIM, 0.9))
		var ic := Vector2(rc.position.x + 13.0, rc.get_center().y)
		var col: Color = spec[2]
		match i:
			CHIP_GOT:
				draw_circle(ic, 7.0, Palette.MINT)
				UiDraw.check(self, ic + Vector2(0, 1), 8.0, Palette.INK, 2.2)
			CHIP_MISSED:
				draw_circle(ic, 7.0, Palette.CORAL)
				UiDraw.cross(self, ic, 5.0, Palette.PAPER, 2.2)
			CHIP_STORE:
				AoDraw.rbox(self, Rect2(ic - Vector2(6, 6), Vector2(12, 12)), Palette.MINT, 3)
		var tx := rc.position.x + 24.0
		var tw := rc.size.x - 27.0
		var top := String(spec[0])
		AoDraw.text_c(self, Vector2(tx + tw * 0.5, rc.position.y + rc.size.y * 0.3), top, 11 if top.length() <= 7 else 10,
			Color(Palette.LCD_TEXT, 0.8), AoDraw.FONT_BOLD)
		var bottom := String(spec[1])
		var by := rc.position.y + rc.size.y * 0.72
		var bw := AoDraw.text_size(bottom, 14, AoDraw.FONT_BOLD).x
		var bx := tx + tw * 0.5 - (bw + 14.0) * 0.5
		match i:
			CHIP_GOT:
				UiDraw.triangle(self, Vector2(bx + 5.0, by + 1.0), 9.0, false, col)
			CHIP_MISSED:
				UiDraw.triangle(self, Vector2(bx + 5.0, by), 9.0, true, col)
			CHIP_STORE:
				UiDraw.arrow(self, Vector2(bx + 5.0, by), 10.0, Vector2.RIGHT, col)
		AoDraw.text_l(self, Vector2(bx + 14.0, by), bottom, 14, col, AoDraw.FONT_BOLD)
