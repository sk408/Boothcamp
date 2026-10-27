extends Control
## CheatCard (training, story-internal): one cheat-sheet card (MaskDeck.cheat_card()), drawn as a
## chunky coloured index card with a pin. Unearned, it is a dashed outline with "Earn me!" and the
## station that earns it. The Training room pins them small; the scorecard shows a new one big.

const UiKit := preload("res://story/ui_kit.gd")

var card: Dictionary = {}
var earned := true
var hint := ""     ## unearned: where it comes from ("Station 1")
var px := 18       ## line size; the title is px + 4


func _init(c: Dictionary = {}, is_earned := true, size_px := 18) -> void:
	card = c
	earned = is_earned
	px = size_px
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if not earned:
		var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
		for i in pts.size() - 1:
			var a := pts[i]
			var b := pts[i + 1]
			var n := int(a.distance_to(b) / 14.0)
			for j in range(0, n, 2):
				draw_line(a.lerp(b, j / float(n)), a.lerp(b, (j + 1) / float(n)), Color(Palette.PAPER, 0.55), 3.0, true)
		draw_string(UiKit.font(700), Vector2(0, size.y * 0.5 - 2), "Earn me!", HORIZONTAL_ALIGNMENT_CENTER, size.x, px + 2, Color(Palette.PAPER, 0.8))
		if hint != "":
			draw_string(UiKit.font(600), Vector2(0, size.y * 0.5 + px + 4), hint, HORIZONTAL_ALIGNMENT_CENTER, size.x, px - 2, Color(Palette.PAPER, 0.65))
		return
	var col: Color = card.get("color", Palette.SUNNY)
	var ink: Color = card.get("ink", Palette.INK)
	UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.3), 14)
	UiDraw.rounded_rect(self, r, col, 14, 3, Palette.INK)
	# the title band
	var band := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, px + 16))
	UiDraw.rounded_rect(self, band, Color(Palette.PAPER, 0.9), 10)
	draw_string(UiKit.font(700), band.position + Vector2(0, px + 5), String(card.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, band.size.x, px + 2, Palette.INK)
	var y := band.end.y + px + 6
	for line: String in card.get("lines", []):
		draw_string(UiKit.font(600), Vector2(12, y), line, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, px, ink)
		y += px + 6
	# the pin
	draw_circle(Vector2(size.x * 0.5, 2), 8.0, Palette.CORAL)
	draw_arc(Vector2(size.x * 0.5, 2), 8.0, 0.0, TAU, 16, Palette.INK, 2.5, true)
