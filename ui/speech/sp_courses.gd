class_name SpCourses
extends Control
## SpCourses: the six courses of a party list (ui/speech only; CONTRACTS.md §9.18.1, docs/CHAPTER5.md
## §5.2). Six plates labelled with their SNR and course (SpeechRules.SIN_COURSES: Starter 25 down to
## Dessert 0). A plate fills with five peas as its sentence is locked in (green = ticked, grey =
## missed; Hoot's plates dimmer, with his H). Above them a dining-room strip fills with diners as the
## gap falls (2, 4, 7, 11, 16 and 24) and the clatter words crowd in; at Dessert the birthday cake
## comes out and a conga line wobbles by (reduced motion: a still, busy picture). Under the plates:
## the running total and the SNR-loss line (blank with hide_loss; aided lists say "aided, sound
## field", never a band). Everything is drawn: the party is never played loud.

const DINERS: Array[int] = [2, 4, 7, 11, 16, 24]
## The clatter that crowds in as the room fills (one more word per course).
const CLATTER: Array[String] = ["clink", "haha", "more bread?", "cheers!", "BIRTHDAY!", "clatter", "ooh!", "HAHA", "pass the salt", "clink clink"]
const HEAD_H := 26.0
const STRIP_H := 40.0
## Room under the plates for their two label lines, and for the total line.
const LABELS_H := 30.0
const TOTAL_H := 26.0
const PEA_DROP_S := 0.5

var list_title := ""
## [{n, snr, course, count (billed, -1 = not yet), by_hoot, locked}] x 6 (SinTest.state().courses).
var courses: Array = []
## The course on the card (1-6; 0 = the practice; 7 = the list is done).
var current := 1
var total := 0
## The line under the total ("SNR loss: ____", "SNR loss 6.5 dB . aided, sound field").
var loss_line := ""
var loss_blank := false
## The diners in the room (the sentence playing or next; 0 before the list starts).
var room := 1
var _marks: Dictionary = {}       ## n -> marks (true / false per chip) as locked
var _drop: Dictionary = {}        ## n -> seconds since the plate was filled
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(d: Dictionary) -> void:
	list_title = String(d.get("list_title", list_title))
	courses = (d.get("courses", courses) as Array).duplicate(true)
	current = int(d.get("current", current))
	total = int(d.get("total", total))
	loss_line = String(d.get("loss_line", loss_line))
	loss_blank = bool(d.get("loss_blank", loss_blank))
	room = int(d.get("room", room))
	queue_redraw()


## A new list: empty plates, an empty room.
func reset() -> void:
	_marks.clear()
	_drop.clear()
	courses = []
	current = 1
	total = 0
	room = 1
	loss_line = ""
	queue_redraw()


## Sentence n is locked in: its peas drop onto its plate (at once with reduced motion).
func fill(n: int, marks: Array) -> void:
	_marks[n] = marks.duplicate()
	_drop[n] = PEA_DROP_S if _reduced() else 0.0
	queue_redraw()


func filled(n: int) -> bool:
	return _marks.has(n)


## Plate n's centre in canvas coordinates (callouts land here).
func plate_global(n: int) -> Vector2:
	return get_global_transform_with_canvas() * _plate_center(clampi(n, 1, 6))


func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _process(delta: float) -> void:
	_t += delta
	for n: Variant in _drop.keys():
		_drop[n] = float(_drop[n]) + delta
	queue_redraw()


## The plates' band: under the room strip, over the labels and the total line.
func _plates_rect() -> Rect2:
	var top := HEAD_H + STRIP_H + 8.0
	return Rect2(Vector2(10.0, top), Vector2(size.x - 20.0, maxf(24.0, size.y - top - LABELS_H - TOTAL_H)))


func _plate_center(n: int) -> Vector2:
	var pr := _plates_rect()
	var w := pr.size.x / 6.0
	return Vector2(pr.position.x + w * (n - 0.5), pr.position.y + pr.size.y * 0.5)


func _plate_r() -> float:
	var pr := _plates_rect()
	return clampf(minf(pr.size.x / 6.0 * 0.38, pr.size.y * 0.5 - 2.0), 10.0, 32.0)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Palette.PAPER, 16)
	AoDraw.text_l(self, Vector2(16, HEAD_H * 0.5 + 1.0), "THE SIX COURSES", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	if list_title != "":
		AoDraw.text_r(self, Vector2(r.size.x - 16, HEAD_H * 0.5 + 1.0), list_title, 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	_draw_room(Rect2(Vector2(10, HEAD_H), Vector2(r.size.x - 20, STRIP_H)))
	for i in 6:
		_draw_plate(i + 1)
	# the running total and the loss line
	var y := r.size.y - TOTAL_H * 0.5 - 4.0
	var lw := AoDraw.text_l(self, Vector2(16, y), "TOTAL SO FAR", 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(16 + lw + 8.0, y), "%d key words" % total, 16, Palette.INK, AoDraw.FONT_BOLD)
	var lx := r.size.x * 0.5 + 6.0
	var lw2 := AoDraw.text_l(self, Vector2(lx, y), "SNR LOSS", 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	if loss_blank or loss_line == "":
		AoDraw.dashed(self, Vector2(lx + lw2 + 8.0, y + 7.0), Vector2(r.size.x - 18.0, y + 7.0), Color(Palette.INK, 0.35), 2.0, 6.0, 4.0)
	else:
		AoDraw.text_l(self, Vector2(lx + lw2 + 8.0, y), loss_line, 14, Palette.INK, AoDraw.FONT_BOLD)


## The dining room: the wall, the tables and the diners (more as the gap falls), the clatter words.
func _draw_room(a: Rect2) -> void:
	AoDraw.rbox(self, a, Palette.WALL, 10, 2, Color(Palette.INK, 0.35))
	var k := clampi(room, 0, 6)
	var diners := DINERS[k - 1] if k >= 1 else 1
	var still := _reduced()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	var floor_y := a.end.y - 4.0
	# tables along the floor
	for i in 4:
		var tx := a.position.x + a.size.x * (0.14 + 0.24 * i)
		AoDraw.rbox(self, Rect2(Vector2(tx - 22.0, floor_y - 7.0), Vector2(44.0, 5.0)), Palette.WOOD, 2)
	# diners: heads in two staggered rows, packing in as the room fills
	for i in diners:
		var fx := (float(i) + 0.5) / diners
		var x := a.position.x + 10.0 + (a.size.x - 20.0) * fx
		var bob := 0.0 if still else sin(_t * (2.0 + rng.randf()) + i) * (0.6 + k * 0.25)
		var hy := floor_y - 15.0 - (i % 2) * 5.0 + bob
		var shade := Palette.SKIN if i % 3 != 2 else Palette.SKIN_SHADE
		var body: Color = [Palette.SKY, Palette.CORAL, Palette.MINT, Palette.PLUM, Palette.SUNNY][i % 5]
		AoDraw.rbox(self, Rect2(Vector2(x - 5.5, hy + 4.0), Vector2(11.0, floor_y - hy - 4.0)), Color(body, 0.9), 4)
		draw_circle(Vector2(x, hy), 5.0, shade)
		draw_arc(Vector2(x, hy), 5.0, 0.0, TAU, 14, Color(Palette.INK, 0.7), 1.5, true)
		rng.randf()
	# Dessert: the cake (candles never flash faster than 3 a second) and the conga line
	if k >= 6:
		var cc := Vector2(a.position.x + a.size.x * 0.5, floor_y - 18.0)
		AoDraw.rbox(self, Rect2(cc - Vector2(14, 0), Vector2(28, 12)), Palette.PAPER, 3, 2, Palette.INK)
		for j in 3:
			var cx := cc.x - 8.0 + j * 8.0
			draw_line(Vector2(cx, cc.y), Vector2(cx, cc.y - 6.0), Palette.CORAL, 2.0)
			var lit := still or fmod(_t * 1.2 + j * 0.3, 1.0) < 0.75
			if lit:
				draw_circle(Vector2(cx, cc.y - 8.0), 2.2, Palette.SUNNY)
		if not still:
			var cx0 := a.position.x + fmod(_t * 40.0, a.size.x + 80.0) - 40.0
			for j in 4:
				var px := cx0 - j * 14.0
				if px > a.position.x + 4.0 and px < a.end.x - 4.0:
					draw_circle(Vector2(px, a.position.y + 12.0 + sin(_t * 8.0 + j) * 2.0), 4.5, Palette.SKIN_SHADE)
	# clatter words along the top: more of them as the gap falls (they drift unless reduced motion)
	var words := mini(CLATTER.size(), maxi(0, k - 1) * 2)
	for i in words:
		var span := a.size.x - 80.0
		var wx := a.position.x + 8.0 + fmod(span * (float(i) / maxf(1.0, words)) + (0.0 if still else _t * (5.0 + i)), span)
		var wy := a.position.y + 7.0 + float(i % 2) * 4.0
		AoDraw.text_l(self, Vector2(wx, wy), CLATTER[i], 10, Color(Palette.INK, 0.45), AoDraw.FONT_BOLD)


func _draw_plate(n: int) -> void:
	var c := _plate_center(n)
	var pr := _plate_r()
	var info: Dictionary = courses[n - 1] if n - 1 < courses.size() else {}
	var snr := int(info.get("snr", SpeechRules.SIN_SNRS[n - 1]))
	var course := String(info.get("course", SpeechRules.SIN_COURSES[n - 1]))
	var locked := bool(info.get("locked", false))
	var hoot := bool(info.get("by_hoot", false))
	var here := n == current and not locked
	if here:
		var p := 0.5 + 0.5 * sin(_t * 4.0)
		draw_circle(c, pr + 7.0 + 2.0 * p, Color(Palette.SUNNY, 0.45))
	draw_circle(c + Vector2(0, 3), pr, Color(Palette.INK, 0.2))
	draw_circle(c, pr, Palette.PAPER)
	draw_arc(c, pr, 0.0, TAU, 32, Palette.INK, 3.0, true)
	draw_arc(c, pr * 0.72, 0.0, TAU, 28, Color(Palette.INK, 0.18), 2.0, true)
	if locked:
		var marks: Array = _marks.get(n, [])
		var count := int(info.get("count", 0))
		if marks.is_empty():
			for i in 5:
				marks.append(i < count)
		var since := float(_drop.get(n, PEA_DROP_S))
		var dim := 0.55 if hoot else 1.0
		for i in mini(5, marks.size()):
			var a := -PI * 0.5 + TAU * i / 5.0
			var at := c + Vector2(cos(a), sin(a)) * pr * 0.42
			var k := clampf((since - i * 0.06) / maxf(0.01, PEA_DROP_S - 0.3), 0.0, 1.0)
			if k <= 0.0:
				continue
			var drop := at + Vector2(0, -pr * 1.6 * (1.0 - k) * (1.0 - k))
			var col := Palette.MINT.darkened(0.12) if marks[i] == true else Color("#a9a3b6")
			draw_circle(drop, pr * 0.2, Color(col, dim))
			draw_arc(drop, pr * 0.2, 0.0, TAU, 12, Color(Palette.INK, 0.6 * dim), 1.5, true)
		if hoot:
			AoDraw.text_c(self, c + Vector2(-pr * 0.85, -pr * 0.8), "H", 12, Palette.HOOT_BROWN.darkened(0.2), AoDraw.FONT_BOLD)
	# labels: the gap and the course; the count on a tag at the plate's rim
	var ly := c.y + pr + 10.0
	AoDraw.text_c(self, Vector2(c.x, ly), "%d dB" % snr if snr > 0 else "0 dB!", 13, Palette.INK if here else Palette.INK_SOFT, AoDraw.FONT_BOLD)
	AoDraw.text_c(self, Vector2(c.x, ly + 15.0), course, 11, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	if locked:
		var count := int(info.get("count", 0))
		var tag := Rect2(c + Vector2(pr * 0.55, -pr - 2.0), Vector2(24.0, 18.0))
		AoDraw.rbox(self, tag, Palette.INK if not hoot else Color(Palette.INK, 0.6), 8)
		AoDraw.text_c(self, tag.get_center(), "%d" % count, 12, Palette.PAPER, AoDraw.FONT_BOLD)
