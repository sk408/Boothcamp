class_name SpLadder
extends Control
## SpLadder: the SRT ladder (ui/speech only). One dot per word: level on the y axis (LOUDER at the
## top, softer at the bottom, so the descent reads as climbing down), word number on the x axis.
## A mint dot with a tick = the player scored it "repeated"; a coral dot with a cross = "missed";
## a pulsing ring = the word still waiting for its score; Hoot's words are dimmer. A dashed purple
## line marks the PTA from the tone test, an orange ring the level the next word will play at, and
## once the scores bracket an SRT a mint band and bracket show it ("SRT 30"). The right-hand column
## tallies every level ("2 of 2"). Everything shown is what the player scored, never the truth.

const ROW_DB := 5
const MIN_SPAN_DB := 50

var ear: String = "right"
## [{db, scored (true / false / null), by_hoot}]
var trail: Array = []
var dial_db: int = 40
var pta: float = NAN
var candidate: int = -1
var talking: bool = false
var accepting: bool = false
## The softest level the player scored "repeated" (-1 = none): the gap wash under the PTA line.
var provisional: int = -1
var _lo := 20.0
var _hi := 100.0
var _t := 0.0
var _stamp_db := -1
var _stamp_t := -1.0
var _plot := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(d: Dictionary) -> void:
	ear = String(d.get("ear", ear))
	trail = d.get("trail", trail)
	dial_db = int(d.get("db", dial_db))
	pta = float(d.get("pta", pta))
	candidate = int(d.get("candidate_db", candidate))
	talking = bool(d.get("talking", talking))
	accepting = bool(d.get("accepting", accepting))
	provisional = int(d.get("provisional", provisional))
	queue_redraw()


## The stored SRT: a rubber stamp lands on its row.
func stamp(db: int) -> void:
	_stamp_db = db
	_stamp_t = 0.0


func clear_stamp() -> void:
	_stamp_db = -1
	_stamp_t = -1.0


## Canvas position of the newest dot (or the next-word cursor when there is none).
func last_dot_global() -> Vector2:
	var p := _dot_pos(maxi(0, trail.size() - 1), int((trail[trail.size() - 1] as Dictionary)["db"]) if not trail.is_empty() else dial_db)
	return get_global_transform_with_canvas() * p


func row_global(db: int) -> Vector2:
	return get_global_transform_with_canvas() * Vector2(_plot.get_center().x, _y(float(db)))


func _process(delta: float) -> void:
	_t += delta
	var want := _target_range()
	_lo = move_toward(_lo, want.x, maxf(20.0, absf(_lo - want.x) * 5.0) * delta)
	_hi = move_toward(_hi, want.y, maxf(20.0, absf(_hi - want.y) * 5.0) * delta)
	if _stamp_t >= 0.0:
		_stamp_t += delta
	queue_redraw()


func _target_range() -> Vector2:
	var lo := float(dial_db)
	var hi := float(dial_db)
	for tr: Dictionary in trail:
		lo = minf(lo, float(int(tr["db"])))
		hi = maxf(hi, float(int(tr["db"])))
	if not is_nan(pta):
		lo = minf(lo, pta)
		hi = maxf(hi, pta)
	hi = ceilf((hi + 8.0) / 10.0) * 10.0
	lo = floorf((lo - 8.0) / 10.0) * 10.0
	if hi - lo < MIN_SPAN_DB:
		lo = hi - MIN_SPAN_DB
	lo = maxf(float(SpeechRules.MIN_DB), lo)
	hi = minf(float(SpeechRules.MAX_DB) + 5.0, maxf(hi, lo + MIN_SPAN_DB))
	return Vector2(lo, hi)


func _y(db: float) -> float:
	var k := (db - _lo) / maxf(1.0, _hi - _lo)
	return _plot.end.y - k * _plot.size.y


func _slots() -> int:
	return maxi(trail.size() + 1, 10)


func _col_w() -> float:
	return clampf(_plot.size.x / _slots(), 9.0, 28.0)


func _dot_pos(i: int, db: int) -> Vector2:
	var cw := _col_w()
	var first := maxi(0, trail.size() + 1 - int(floor(_plot.size.x / maxf(1.0, cw))))
	return Vector2(_plot.position.x + cw * (i - first + 0.5), _y(float(db)))


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Palette.PAPER, 22)
	var ec := Palette.ear_color(ear)
	# header: title, ear chip, legend
	AoDraw.text_l(self, Vector2(18, 22), "SRT LADDER", 16, Palette.INK, AoDraw.FONT_BOLD)
	var chip := Rect2(Vector2(124, 11), Vector2(64, 22))
	AoDraw.rbox(self, chip, ec, 11)
	AoDraw.text_c(self, chip.get_center(), ear.to_upper(), 12, Palette.PAPER, AoDraw.FONT_BOLD)
	var lx := r.end.x - 16.0
	for spec: Array in [[false, "missed"], [true, "got it"]]:
		var w := AoDraw.text_size(String(spec[1]), 12, AoDraw.FONT_SEMI).x
		lx -= w
		AoDraw.text_l(self, Vector2(lx, 22), String(spec[1]), 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		lx -= 14.0
		_dot(Vector2(lx, 22), 7.0, bool(spec[0]), false, 1.0)
		lx -= 16.0
	var tally_w := 58.0
	_plot = Rect2(Vector2(46, 44), Vector2(r.size.x - 46 - tally_w - 14, r.size.y - 44 - 30))
	AoDraw.rbox(self, _plot.grow(4.0), Color(Palette.CREAM, 0.9), 10)
	# rows and dB labels
	var top_db := int(floor(_hi / ROW_DB)) * ROW_DB
	var db := top_db
	while float(db) >= _lo - 0.1:
		var y := _y(float(db))
		if y >= _plot.position.y - 2.0 and y <= _plot.end.y + 2.0:
			var major := db % 10 == 0
			draw_line(Vector2(_plot.position.x, y), Vector2(_plot.end.x, y), Color(Palette.INK, 0.09 if major else 0.04), 2.0 if major else 1.0)
			if major:
				AoDraw.text_r(self, Vector2(_plot.position.x - 8.0, y), "%d" % db, 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		db -= ROW_DB
	# louder / softer labels
	UiDraw.triangle(self, Vector2(_plot.position.x + 10.0, _plot.position.y + 9.0), 9.0, true, Color(Palette.INK, 0.35))
	AoDraw.text_l(self, Vector2(_plot.position.x + 18.0, _plot.position.y + 9.0), "louder", 11, Color(Palette.INK, 0.4), AoDraw.FONT_BOLD)
	UiDraw.triangle(self, Vector2(_plot.position.x + 10.0, _plot.end.y - 9.0), 9.0, false, Color(Palette.INK, 0.35))
	AoDraw.text_l(self, Vector2(_plot.position.x + 18.0, _plot.end.y - 9.0), "softer", 11, Color(Palette.INK, 0.4), AoDraw.FONT_BOLD)
	AoDraw.text_c(self, Vector2(_plot.position.x - 24.0, _plot.position.y - 12.0), "dB HL", 10, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var row_h := absf(_y(0.0) - _y(float(ROW_DB)))
	# the gap between the beeps and the words (the non-organic tell): a soft coral wash
	if provisional >= 0 and not is_nan(pta) and pta - float(provisional) > float(SpeechRules.AGREE_FAIR_DB):
		var ya := clampf(_y(pta), _plot.position.y, _plot.end.y)
		var yb := clampf(_y(float(provisional)), _plot.position.y, _plot.end.y)
		draw_rect(Rect2(Vector2(_plot.position.x, ya), Vector2(_plot.size.x, yb - ya)), Color(Palette.CORAL, 0.09))
	# the bracketed SRT
	if candidate >= 0:
		var yc := _y(float(candidate))
		AoDraw.rbox(self, Rect2(Vector2(_plot.position.x, yc - row_h * 0.5), Vector2(_plot.size.x, row_h)), Color(Palette.MINT, 0.22), 4)
	# PTA line
	if not is_nan(pta):
		var yp := _y(pta)
		if yp >= _plot.position.y and yp <= _plot.end.y:
			AoDraw.dashed(self, Vector2(_plot.position.x, yp), Vector2(_plot.end.x, yp), Palette.PLUM, 3.0, 9.0, 6.0)
			var ptxt := "PTA %d" % int(round(pta))
			var pw := AoDraw.text_size(ptxt, 12, AoDraw.FONT_BOLD).x + 14.0
			var pr := Rect2(Vector2(_plot.end.x - pw - 4.0, yp - 10.0), Vector2(pw, 20.0))
			AoDraw.rbox(self, pr, Palette.PLUM, 10, 2, Palette.INK)
			AoDraw.text_c(self, pr.get_center(), ptxt, 12, Palette.PAPER, AoDraw.FONT_BOLD)
	# the trail
	var cw := _col_w()
	var dot_r := clampf(cw * 0.36, 5.0, 9.0)
	var first := maxi(0, trail.size() + 1 - int(floor(_plot.size.x / maxf(1.0, cw))))
	var prev := Vector2.INF
	for i in range(first, trail.size()):
		var tr: Dictionary = trail[i]
		var p := _dot_pos(i, int(tr["db"]))
		if prev != Vector2.INF:
			draw_line(prev, p, Color(Palette.INK, 0.22), 2.0, true)
		prev = p
	for i in range(first, trail.size()):
		var tr: Dictionary = trail[i]
		var p := _dot_pos(i, int(tr["db"]))
		var a := 0.45 if bool(tr.get("by_hoot", false)) else 1.0
		var sc: Variant = tr.get("scored", null)
		if sc == null:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			if talking and i == trail.size() - 1:
				for k in 2:
					var rr := dot_r + 4.0 + 7.0 * fmod(_t * 2.0 + k * 0.5, 1.0)
					draw_arc(p, rr, 0.0, TAU, 24, Color(Palette.TONE_CYAN, 0.6 * (1.0 - fmod(_t * 2.0 + k * 0.5, 1.0))), 3.0, true)
			draw_circle(p, dot_r + 2.0, Color(Palette.INK, a))
			draw_circle(p, dot_r - 0.5, Color(Palette.TONE_CYAN.lerp(Palette.PAPER, 0.35 + 0.3 * pulse), a))
			AoDraw.text_c(self, p + Vector2(0, -1), "?", int(dot_r * 1.5), Color(Palette.INK, a), AoDraw.FONT_BOLD)
		else:
			_dot(p, dot_r, bool(sc), bool(tr.get("by_hoot", false)), a)
	# the next word's level
	var waiting := not trail.is_empty() and (trail[trail.size() - 1] as Dictionary).get("scored", null) == null
	if accepting and not waiting and not talking:
		var np := _dot_pos(trail.size(), dial_db)
		if np.y >= _plot.position.y - 4.0 and np.y <= _plot.end.y + 4.0:
			var pulse2 := 0.5 + 0.5 * sin(_t * 5.0)
			draw_arc(np, dot_r + 2.0 + pulse2 * 2.0, 0.0, TAU, 24, Palette.SELECT_ORANGE, 3.0, true)
			if prev != Vector2.INF:
				AoDraw.dashed(self, prev, np, Color(Palette.SELECT_ORANGE, 0.6), 2.0, 5.0, 4.0)
	# tally column
	var tx := _plot.end.x + 10.0
	var tally := _tally()
	AoDraw.text_c(self, Vector2(tx + tally_w * 0.5, _plot.position.y - 12.0), "TALLY", 10, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	for lvl: int in tally:
		var y := _y(float(lvl))
		if y < _plot.position.y - 6.0 or y > _plot.end.y + 6.0:
			continue
		var cell: Array = tally[lvl]
		var right := int(cell[0])
		var total := int(cell[1])
		var fill := Palette.CREAM
		if right >= SpeechRules.SRT_MIN_CORRECT and float(right) >= SpeechRules.SRT_MIN_FRACTION * total:
			fill = Palette.MINT.lightened(0.35)
		elif float(right) < SpeechRules.SRT_MIN_FRACTION * total:
			fill = Palette.CORAL.lightened(0.45)
		var h := minf(18.0, maxf(12.0, row_h - 1.0))
		var cr := Rect2(Vector2(tx, y - h * 0.5), Vector2(tally_w, h))
		AoDraw.rbox(self, cr, fill, int(h * 0.5), 2, Color(Palette.INK, 0.6))
		AoDraw.text_c(self, cr.get_center(), "%d of %d" % [right, total], 11 if h >= 15.0 else 10, Palette.INK, AoDraw.FONT_BOLD)
	# the SRT bracket and label
	if candidate >= 0:
		var y1 := _y(float(candidate))
		var y2 := _y(float(candidate - ROW_DB))
		var bx := _plot.end.x + 4.0
		draw_line(Vector2(bx, y1), Vector2(bx, y2), Palette.MINT.darkened(0.25), 3.0)
		draw_line(Vector2(bx - 5.0, y1), Vector2(bx, y1), Palette.MINT.darkened(0.25), 3.0)
		draw_line(Vector2(bx - 5.0, y2), Vector2(bx, y2), Palette.MINT.darkened(0.25), 3.0)
		if _stamp_db < 0:   # once stored, the stamp says it
			var lt := "SRT %d" % candidate
			var lw := AoDraw.text_size(lt, 13, AoDraw.FONT_BOLD).x + 16.0
			var lr := Rect2(Vector2(_plot.position.x + 66.0, y1 - row_h * 0.5 - 22.0), Vector2(lw, 20.0))
			if lr.position.y < _plot.position.y:
				lr.position.y = y1 + row_h * 0.5 + 2.0
			AoDraw.rbox(self, lr, Palette.MINT, 10, 2, Palette.INK)
			AoDraw.text_c(self, lr.get_center(), lt, 13, Palette.INK, AoDraw.FONT_BOLD)
	# x axis
	AoDraw.text_r(self, Vector2(_plot.position.x - 8.0, r.end.y - 14.0), "word", 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var step := 1 if cw >= 18.0 else (2 if cw >= 10.0 else 5)
	for i in range(first, trail.size() + 1):
		if (i + 1) % step != 0 and i != first:
			continue
		var px := _dot_pos(i, 0).x
		AoDraw.text_c(self, Vector2(px, r.end.y - 14.0), "%d" % (i + 1), 11, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	# the stored SRT's stamp
	if _stamp_db >= 0 and _stamp_t >= 0.0:
		_draw_stamp()


func _dot(p: Vector2, rad: float, ok: bool, hoot: bool, a: float) -> void:
	var fill := Palette.MINT if ok else Palette.CORAL
	draw_circle(p + Vector2(0, 2), rad + 2.0, Color(Palette.INK, 0.25 * a))
	draw_circle(p, rad + 2.0, Color(Palette.INK, a))
	draw_circle(p, rad - 0.5, Color(fill, a))
	if ok:
		UiDraw.check(self, p, rad * 1.1, Color(Palette.PAPER, a), 2.5)
	else:
		UiDraw.cross(self, p, rad * 0.8, Color(Palette.PAPER, a), 2.5)
	if hoot:
		draw_arc(p, rad + 4.0, 0.0, TAU, 20, Color(Palette.HOOT_BROWN, 0.5 * a), 1.5, true)


func _tally() -> Dictionary:
	var out: Dictionary = {}
	for tr: Dictionary in trail:
		var sc: Variant = tr.get("scored", null)
		if sc == null:
			continue
		var lvl := int(tr["db"])
		var cell: Array = out.get(lvl, [0, 0])
		out[lvl] = [int(cell[0]) + (1 if bool(sc) else 0), int(cell[1]) + 1]
	return out


func _draw_stamp() -> void:
	var k := clampf(_stamp_t / 0.18, 0.0, 1.0)
	var s := lerpf(2.2, 1.0, k * k)
	var a := clampf(_stamp_t / 0.08, 0.0, 1.0)
	var c := Vector2(_plot.position.x + _plot.size.x * 0.3, _y(float(_stamp_db)))
	var txt := "SRT %d dB" % _stamp_db
	var w := AoDraw.text_size(txt, 26, AoDraw.FONT_BOLD).x + 30.0
	draw_set_transform(c, deg_to_rad(-7.0), Vector2.ONE * s)
	var rr := Rect2(Vector2(-w * 0.5, -22.0), Vector2(w, 44.0))
	AoDraw.rbox(self, Rect2(rr.position + Vector2(0, 4), rr.size), Color(Palette.INK, 0.25 * a), 12)
	AoDraw.rbox(self, rr, Color(Palette.PAPER, 0.92 * a), 12, 4, Color(Palette.RIGHT_RED if ear == "right" else Palette.LEFT_BLUE, a))
	AoDraw.text_c(self, Vector2.ZERO, txt, 26, Color(Palette.ear_color(ear), a), AoDraw.FONT_BOLD)
	draw_set_transform(Vector2.ZERO)
