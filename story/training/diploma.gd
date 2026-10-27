extends RefCounted
## Diploma (training, story-internal): the Masking School diploma stamp, earned by finishing the exam
## (Station 6, docs/training/MASKING_TRAINER.md §3.6). A round purple stamp with Hoot in a mortarboard
## and the exam's best grade on a ribbon. Drawn on any CanvasItem: the exam's scorecard, the Training
## room's lesson card and the print view all use it.
##   Diploma.draw(ci, Vector2(75, 60), 1.0, "A")

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")

const STAMP := Color("#8e5cc4")


static func draw(ci: CanvasItem, c: Vector2, k: float, grade: String) -> void:
	var r := 52.0 * k
	ci.draw_circle(c + Vector2(0, 4 * k), r, Color(0, 0, 0, 0.25))
	ci.draw_circle(c, r, STAMP)
	ci.draw_arc(c, r, 0.0, TAU, 40, Palette.INK, 3.0 * k, true)
	ci.draw_arc(c, r - 7 * k, 0.0, TAU, 40, Color(Palette.PAPER, 0.7), 2.0 * k, true)
	# Hoot, and his mortarboard
	Portraits.draw(ci, "Hoot", c + Vector2(0, -2 * k), 26.0 * k)
	var top := c + Vector2(0, -27 * k)
	var board := PackedVector2Array([top + Vector2(-24, 0) * k, top + Vector2(0, -9) * k, top + Vector2(24, 0) * k, top + Vector2(0, 9) * k])
	ci.draw_rect(Rect2(top + Vector2(-11, 1) * k, Vector2(22, 9) * k), Palette.INK)
	ci.draw_colored_polygon(board, Palette.INK)
	ci.draw_line(top, top + Vector2(17, 6) * k, Palette.SUNNY, 2.0 * k, true)
	ci.draw_line(top + Vector2(17, 6) * k, top + Vector2(17, 18) * k, Palette.SUNNY, 2.0 * k, true)
	ci.draw_circle(top + Vector2(17, 19) * k, 3.0 * k, Palette.SUNNY)
	# the ribbon with the grade
	var rib := Rect2(c + Vector2(-46, 26) * k, Vector2(92, 26) * k)
	ci.draw_rect(Rect2(rib.position + Vector2(0, 3 * k), rib.size), Color(0, 0, 0, 0.25))
	ci.draw_rect(rib, Palette.SUNNY)
	ci.draw_rect(rib, Palette.INK, false, 2.0 * k)
	var label := "DIPLOMA %s" % grade if grade != "" else "DIPLOMA"
	ci.draw_string(UiKit.font(700), rib.position + Vector2(0, 19 * k), label, HORIZONTAL_ALIGNMENT_CENTER, rib.size.x, int(15 * k), Palette.INK)
