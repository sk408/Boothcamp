class_name AoEarCard
extends Control
## AoEarCard: one ear's audiogram card on the AudiOtron (ui/ only): a sticker-style card with a
## coloured header (ear name, ASHA symbol, progress pips, "TESTING" badge) and the Audiogram.

const HEADER_H := 40.0
const AUDIOGRAM_SCENE := preload("res://ui/audiogram/audiogram.tscn")

var ear: String = "right"
var active: bool = false:
	set(v):
		if v != active:
			active = v
			queue_redraw()
var progress_done: int = 0
var progress_total: int = 7
var audiogram: Audiogram
var _t := 0.0
var _flash := 0.0


func _init(p_ear: String = "right") -> void:
	ear = p_ear


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	audiogram = AUDIOGRAM_SCENE.instantiate() as Audiogram
	audiogram.ear = ear
	audiogram.custom_minimum_size = Vector2.ZERO
	add_child(audiogram)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if audiogram == null:
		return
	audiogram.position = Vector2(8, HEADER_H + 6)
	audiogram.size = Vector2(maxf(10.0, size.x - 16.0), maxf(10.0, size.y - HEADER_H - 14.0))


## A short celebratory flash of the header (ear complete).
func flash() -> void:
	_flash = 1.0


func set_progress(done: int, total: int) -> void:
	if done == progress_done and total == progress_total:
		return
	progress_done = done
	progress_total = total
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(0.0, _flash - delta * 0.8)
	if active or _flash > 0.0:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var col := Palette.ear_color(ear)
	if active:
		var p := 0.5 + 0.5 * sin(_t * 3.0)
		AoDraw.ring(self, r.grow(6.0), Color(Palette.SELECT_ORANGE, 0.45 + 0.35 * p), 24, 5)
	AoDraw.card(self, r, Palette.ear_tint(ear), 20)
	var hr := Rect2(Vector2(4, 4), Vector2(size.x - 8, HEADER_H - 2))
	AoDraw.rbox(self, hr, col.lerp(Palette.SUNNY, _flash * 0.6), 16)
	draw_line(Vector2(4, HEADER_H + 2), Vector2(size.x - 4, HEADER_H + 2), Palette.INK, 3.0)
	# symbol roundel + title
	var sc := Vector2(30, hr.get_center().y)
	draw_circle(sc, 15.0, Palette.PAPER)
	UiDraw.ear_symbol(self, sc, ear, 15.0, 3.5)
	var title := "RIGHT EAR" if ear == "right" else "LEFT EAR"
	var tw := AoDraw.text_l(self, Vector2(54, sc.y), title, 21, Palette.PAPER, AoDraw.FONT_BOLD)
	if active:
		var br := Rect2(Vector2(62 + tw, sc.y - 11), Vector2(78, 22))
		AoDraw.rbox(self, br, Palette.SUNNY, 11, 2, Palette.INK)
		AoDraw.text_c(self, br.get_center(), "TESTING", 12, Palette.INK, AoDraw.FONT_BOLD)
	elif progress_total > 0 and progress_done >= progress_total:
		var bd := Rect2(Vector2(62 + tw, sc.y - 11), Vector2(64, 22))
		AoDraw.rbox(self, bd, Palette.MINT, 11, 2, Palette.INK)
		AoDraw.text_c(self, bd.get_center(), "DONE", 12, Palette.INK, AoDraw.FONT_BOLD)
	# progress pips, right aligned
	var n := maxi(progress_total, 1)
	var pip := 12.0
	var gap := 5.0
	var total_w := n * pip + (n - 1) * gap
	var x0 := size.x - 18.0 - total_w
	var label := "%d/%d" % [progress_done, progress_total]
	AoDraw.text_r(self, Vector2(x0 - 8.0, sc.y), label, 15, Palette.PAPER, AoDraw.FONT_BOLD)
	for i in n:
		var c := Vector2(x0 + pip * 0.5 + i * (pip + gap), sc.y)
		if i < progress_done:
			draw_circle(c, pip * 0.5, Palette.PAPER)
			draw_circle(c, pip * 0.28, Palette.MINT)
		else:
			draw_arc(c, pip * 0.5 - 1.0, 0.0, TAU, 16, Color(Palette.PAPER, 0.7), 2.0, true)
