class_name AoQuest
extends Control
## AoQuest: the test plan for the current ear as a grid of tokens (ui/ only), in textbook order:
## 1k, 2k, 4k, 8k, 1k retest, 500, 250, plus any half-octave the audiogram asks for. Done tokens
## show the stored level; the current one glows; newly required half-octaves pop in with "NEW".
## Clicking a token jumps to that frequency.

signal token_clicked(freq: int)

const TOKEN := Vector2(52, 40)
const GAP := 5.0

var ear: String = "right"
## [{"freq", "label", "done", "db", "current", "retest", "nr", "new"}]
var items: Array = []
var done_count: int = 0
var total_count: int = 7
var _t := 0.0
var _pop: Dictionary = {}     ## token key -> seconds of pop left
var _hot: Array = []          ## [Rect2, freq]
var _hover := -1
var _complete_t := 0.0


## (v3) Header text: "TEST PLAN" for air, the AudiOtron sets e.g. "MASKED BONE" on Day 2.
var title: String = "TEST PLAN":
	set(v):
		if v != title:
			title = v
			queue_redraw()
## (v3) The sheet the tokens belong to: done tokens wear its audiogram symbol (O, <, [, triangle...).
var test: StringName = &"ac":
	set(v):
		if v != test:
			test = v
			queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_plan(p_ear: String, p_items: Array, done: int, total: int) -> void:
	var old_keys := {}
	for it: Dictionary in items:
		old_keys[_key(it)] = it
	for it: Dictionary in p_items:
		var k := _key(it)
		if not old_keys.has(k) and p_ear == ear and not items.is_empty():
			_pop[k] = 0.6
			it["new"] = true
		elif old_keys.has(k) and bool(it["done"]) and not bool((old_keys[k] as Dictionary)["done"]):
			_pop[k] = 0.45
	if done == total and total > 0 and done_count != done:
		_complete_t = 1.5
	ear = p_ear
	items = p_items
	done_count = done
	total_count = total
	queue_redraw()


static func _key(it: Dictionary) -> String:
	return "%d%s" % [int(it["freq"]), "r" if bool(it.get("retest", false)) else ""]


func _process(delta: float) -> void:
	_t += delta
	for k: String in _pop.keys():
		_pop[k] = float(_pop[k]) - delta
		if float(_pop[k]) <= 0.0:
			_pop.erase(k)
	_complete_t = maxf(0.0, _complete_t - delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var f := _hit((event as InputEventMouseMotion).position)
		if f != _hover:
			_hover = f
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if f > 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var f := _hit(mb.position)
			if f > 0:
				token_clicked.emit(f)
				accept_event()


func _hit(p: Vector2) -> int:
	for h: Array in _hot:
		if (h[0] as Rect2).has_point(p):
			return int(h[1])
	return -1


func _draw() -> void:
	_hot.clear()
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Palette.PAPER, 22)
	var col := Palette.ear_color(ear)
	# header: title + progress bar
	var tw := AoDraw.text_l(self, Vector2(16, 20), title, 15, Palette.INK, AoDraw.FONT_BOLD)
	var bx := maxf(112.0, 16.0 + tw + 10.0)
	var bar := Rect2(Vector2(bx, 12), Vector2(maxf(20.0, size.x - bx - 52), 16))
	AoDraw.rbox(self, bar, Palette.CREAM.darkened(0.06), 8, 2, Palette.INK)
	var k := float(done_count) / maxf(1.0, float(total_count))
	if k > 0.0:
		AoDraw.rbox(self, Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4) * k, bar.size.y - 4)), Palette.MINT if k < 1.0 else Palette.SUNNY, 6)
	AoDraw.text_r(self, Vector2(size.x - 14, 20), "%d%%" % int(round(k * 100.0)), 14, Palette.INK, AoDraw.FONT_BOLD)
	# tokens
	var per_row := maxi(1, int((size.x - 20.0 + GAP) / (TOKEN.x + GAP)))
	var row_w := per_row * TOKEN.x + (per_row - 1) * GAP
	var x0 := (size.x - row_w) * 0.5
	var y0 := 36.0
	# a third row (several half-octaves) squeezes the tokens instead of spilling out of the card
	var rows := maxi(1, ceili(float(items.size()) / per_row))
	var tok := Vector2(TOKEN.x, clampf((size.y - y0 - 8.0 - (rows - 1) * GAP) / rows, 28.0, TOKEN.y))
	for i in items.size():
		var it: Dictionary = items[i]
		var cell := Rect2(Vector2(x0 + (i % per_row) * (TOKEN.x + GAP), y0 + (i / per_row) * (tok.y + GAP)), tok)
		var pop := float(_pop.get(_key(it), 0.0))
		var s := 1.0 + 0.35 * sin(clampf(pop / 0.6, 0.0, 1.0) * PI)
		var done := bool(it["done"])
		var cur := bool(it["current"])
		var fill := Palette.CREAM
		if done:
			fill = Palette.ear_tint(ear)
		if cur:
			fill = Palette.SUNNY
		var rc := Rect2(cell.get_center() - cell.size * 0.5 * s, cell.size * s)
		if cur:
			var p := 0.5 + 0.5 * sin(_t * 5.0)
			AoDraw.ring(self, rc.grow(3.0 + 2.0 * p), Color(Palette.SELECT_ORANGE, 0.6), 12, 3)
		if _hover == int(it["freq"]) and not cur:
			fill = fill.lightened(0.2)
		AoDraw.rbox(self, Rect2(rc.position + Vector2(0, 3), rc.size), Color(Palette.INK, 0.2), 10)
		AoDraw.rbox(self, rc, fill, 10, 2 if not cur else 3, Palette.INK)
		var label: String = it["label"]
		AoDraw.text_c(self, rc.get_center() + Vector2(0, -8), label, 15, Palette.INK, AoDraw.FONT_BOLD)
		if done:
			var sc := rc.get_center() + Vector2(-10, 10)
			UiDraw.audiogram_symbol(self, sc, ear, test, 9.0, 2.0, bool(it.get("nr", false)))
			AoDraw.text_l(self, sc + Vector2(9, 0), "NR" if bool(it.get("nr", false)) else str(int(it["db"])), 12, col.darkened(0.2), AoDraw.FONT_BOLD)
		elif cur:
			UiDraw.triangle(self, rc.get_center() + Vector2(0, 11), 9.0, false, Palette.INK)
		else:
			draw_circle(rc.get_center() + Vector2(0, 10), 3.0, Palette.INK_SOFT)
		if bool(it.get("new", false)) and not done:
			var nr := Rect2(rc.position + Vector2(rc.size.x - 30, -8), Vector2(34, 15))
			AoDraw.rbox(self, nr, Palette.CORAL, 7, 2, Palette.INK)
			AoDraw.text_c(self, nr.get_center(), "NEW", 10, Palette.PAPER, AoDraw.FONT_BOLD)
		_hot.append([cell, int(it["freq"])])
	if _complete_t > 0.0:
		var a := clampf(_complete_t / 0.4, 0.0, 1.0)
		AoDraw.text_c(self, Vector2(size.x * 0.5, size.y - 18), "100%  ALL STAMPED!", 16, Color(Palette.SELECT_ORANGE, a), AoDraw.FONT_BOLD, 6, Color(Palette.PAPER, a))
