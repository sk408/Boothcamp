extends RefCounted
## Licence (training, story-internal): the Booth Camp Practical licence, earned by finishing Station 8, "Exam
## day" (docs/training/PRACTICAL_EXAM.md §3.8). A game licence, clearly not a board one: a little ID card with
## Hoot's photo, the best grade and PASS once a sitting passed (B or better, no STOP). Drawn on any CanvasItem:
## the exam's scorecard, the Training room's lesson card and the print view all use it. Its save sits beside
## the exam's station record: Game.progress["training"]["practical"]["licence"] = {"pass": bool}.
##   Licence.draw(ci, Vector2(120, 80), 1.0, "A", true)
##   Licence.earned() / Licence.grade() / Licence.passed()

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")

const CARD := Color("#1f9aa5")
const SIZE := Vector2(220, 136)


## The lesson's save, read only (the title asks too: nothing is created by looking).
static func _saved() -> Dictionary:
	var tr: Variant = Game.progress.get("training", {})
	var d: Variant = (tr as Dictionary).get(PracticalDeck.LESSON, {}) if tr is Dictionary else {}
	return d if d is Dictionary else {}


## The exam's fewest points lost (-1 = never finished).
static func best() -> int:
	var st: Variant = _saved().get("stations", {})
	var ex: Variant = (st as Dictionary).get("exam", {}) if st is Dictionary else {}
	return int((ex as Dictionary).get("best", -1)) if ex is Dictionary else -1


## The exam has been finished at least once.
static func earned() -> bool:
	return best() >= 0


## The best sitting's grade ("" before the first).
static func grade() -> String:
	return PracticalDeck.exam_grade(best()) if best() >= 0 else ""


## A sitting has passed (once passed, always passed).
static func passed() -> bool:
	var l: Variant = _saved().get("licence", {})
	return l is Dictionary and bool((l as Dictionary).get("pass", false))


## Save a finished sitting's pass. Returns true when this is the first pass. Saves.
static func record_pass(pass_now: bool) -> bool:
	if not pass_now or passed():
		return false
	TrainingProgress.data(PracticalDeck.LESSON)["licence"] = {"pass": true}
	Game.save_game()
	return true


## The licence card, centred on c, scaled by k, tilted a touch.
static func draw(ci: CanvasItem, c: Vector2, k: float, grade_text: String, pass_now: bool) -> void:
	var f := UiKit.font(700)
	ci.draw_set_transform(c, -0.05, Vector2.ONE * k)
	var r := Rect2(-SIZE * 0.5, SIZE)
	UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.25), 14)
	UiDraw.rounded_rect(ci, r, CARD, 14, 3, Palette.INK)
	ci.draw_string(f, r.position + Vector2(0, 22), "BOOTH CAMP", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Palette.SUNNY)
	ci.draw_string(f, r.position + Vector2(0, 40), "PRACTICAL LICENCE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Palette.PAPER)
	# Hoot's photo
	var photo := Rect2(r.position + Vector2(12, 50), Vector2(64, 70))
	UiDraw.rounded_rect(ci, photo, Palette.PAPER, 8, 2, Palette.INK)
	Portraits.draw(ci, "Hoot", photo.get_center(), 26.0, false, false, false)
	# the lines and the grade
	var x := r.position.x + 88
	for i in 2:
		ci.draw_line(Vector2(x, r.position.y + 64 + i * 14), Vector2(r.end.x - 14, r.position.y + 64 + i * 14), Color(Palette.PAPER, 0.5), 2.0)
	var g := grade_text if grade_text != "" else "-"
	ci.draw_circle(Vector2(r.end.x - 34, r.end.y - 30), 20.0, Palette.grade_color(g) if grade_text != "" else Palette.PAPER)
	ci.draw_arc(Vector2(r.end.x - 34, r.end.y - 30), 20.0, 0.0, TAU, 28, Palette.INK, 2.0, true)
	ci.draw_string(f, Vector2(r.end.x - 54, r.end.y - 21), g, HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Palette.INK)
	var word := "PASS" if pass_now else "PRACTICE"
	var col: Color = Palette.MINT if pass_now else Palette.SUNNY
	UiDraw.rounded_rect(ci, Rect2(Vector2(x, r.end.y - 44), Vector2(76, 26)), col, 6, 2, Palette.INK)
	ci.draw_string(f, Vector2(x, r.end.y - 25), word, HORIZONTAL_ALIGNMENT_CENTER, 76, 14 if pass_now else 12, Palette.INK)
	ci.draw_string(UiKit.font(600), r.position + Vector2(0, r.size.y + 18), "A game licence, not a board one", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12,
		Color(Palette.INK, 0.7))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
