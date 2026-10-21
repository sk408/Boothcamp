class_name SpScoreStrip
extends Control
## SpScoreStrip: the WORD mode's word-score strip (ui/speech only; CONTRACTS.md §9.17.1, CHAPTER4
## §5.1). 25 tiles, 5 x 5 in list order, fill in as words are scored: a mint tile with a tick, a
## coral tile with a cross and what the patient said in small type, Hoot's tiles brown (as on Day
## 3's golf card). The running line counts the marks ("13 right x 4% = 52%"); there is no live pace
## marker. The band ruler (90 / 78 / 66 / 54, WRS_BAND_TITLES) appears only once a list has ended,
## with a sunny tick at the predicted minimum once the ear's best is final; the band chip lands at
## the end of a list. Reduced motion: the tiles flip without bouncing and the chip fades in.

const COLS := 5
const ROWS := 5
## The band ruler shows scores from here to 100 (a lower score sits at its left end, its number shown).
const RULER_FROM := 30
const BAND_COLORS: Dictionary[StringName, Color] = {
	&"excellent": Palette.MINT, &"good": Palette.PRESS_LIME, &"fair": Palette.SUNNY, &"poor": Palette.SELECT_ORANGE,
	&"very_poor": Palette.CORAL,
}
const BAND_SHORT: Dictionary[StringName, String] = {
	&"excellent": "Exc.", &"good": "Good", &"fair": "Fair", &"poor": "Poor", &"very_poor": "V. poor",
}
const FLIP_S := 0.32

var title := ""
var ear := "right"
var words := SpeechRules.WRS_WORDS
## This list's tiles in order: {n, mark (true / false / null = not scored yet), hoot, said, live}.
var tiles: Array[Dictionary] = []
var right := 0
var pct_so_far := 0
var show_ruler := false
## The sunny tick on the ruler (< 0 = none: only once the ear's best is final).
var predicted_min := -1
## The finished list's score on the ruler (< 0 = the list is still going).
var list_pct := -1
var _band: StringName = &""
var _band_t := 0.0
var _flips: Dictionary = {}   ## n -> seconds since its tile flipped
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The view from the screen: the list's trials (each {n, scored, by_hoot, said}) and its numbers.
func set_view(d: Dictionary) -> void:
	title = String(d.get("title", title))
	ear = String(d.get("ear", ear))
	words = maxi(1, int(d.get("words", words)))
	right = int(d.get("right", 0))
	pct_so_far = int(d.get("pct_so_far", 0))
	show_ruler = bool(d.get("show_ruler", false))
	predicted_min = int(d.get("predicted_min", -1))
	list_pct = int(d.get("list_pct", list_pct))
	var next: Array[Dictionary] = []
	for v: Variant in d.get("trials", []):
		var tr: Dictionary = v
		var n := int(tr.get("n", next.size() + 1))
		var mark: Variant = tr.get("scored")
		var old := _tile(n)
		if mark != null and (old.is_empty() or old.get("mark") == null):
			_flips[n] = 0.0
		next.append({"n": n, "mark": mark, "hoot": bool(tr.get("by_hoot", false)), "said": String(tr.get("said", "")),
			"live": mark == null})
	tiles = next
	queue_redraw()


## A new list: every tile empty, no chip.
func reset() -> void:
	tiles.clear()
	_flips.clear()
	_band = &""
	list_pct = -1
	right = 0
	pct_so_far = 0
	queue_redraw()


## The band chip lands (the end of a list).
func land_band(band: StringName, pct: int) -> void:
	_band = band
	_band_t = 0.0
	list_pct = pct
	queue_redraw()


func band() -> StringName:
	return _band


func flash() -> void:
	_flash = 1.0


## Canvas position just right of the running line (the golf and points callouts land here).
func running_line_global() -> Vector2:
	var g := _geometry()
	return get_global_transform_with_canvas() * (Vector2(size.x * 0.5, (g["line_y"] as float)) + Vector2(0, -34))


## The drawn scale of tile n now (1.0 at rest; a flip squashes it, and only full motion overshoots).
func tile_scale(n: int) -> float:
	if not _flips.has(n):
		return 1.0
	var k := clampf(float(_flips[n]) / FLIP_S, 0.0, 1.0)
	if k < 0.5:
		return cos(k * PI)   # the card turns edge-on
	var e := (k - 0.5) * 2.0
	if AoFx._reduced():
		return e
	# back out: a little overshoot, then it settles (the bounce)
	var c1 := 1.70158
	return 1.0 + (c1 + 1.0) * pow(e - 1.0, 3.0) + c1 * pow(e - 1.0, 2.0)


func _tile(n: int) -> Dictionary:
	for t: Dictionary in tiles:
		if int(t["n"]) == n:
			return t
	return {}


func _process(delta: float) -> void:
	_t += delta
	_band_t += delta
	_flash = maxf(0.0, _flash - delta * 1.6)
	for n: Variant in _flips.keys():
		_flips[n] = float(_flips[n]) + delta
		if float(_flips[n]) > FLIP_S + 0.05:
			_flips.erase(n)
	queue_redraw()


func _geometry() -> Dictionary:
	var pad := 12.0
	var head := 30.0
	var ruler_h := 50.0 if show_ruler else 0.0
	var line_h := 30.0
	var grid := Rect2(Vector2(pad, head + 4.0), Vector2(size.x - pad * 2.0, maxf(40.0, size.y - head - 4.0 - line_h - ruler_h - pad)))
	return {"grid": grid, "line_y": grid.end.y + line_h * 0.5 + 2.0, "ruler": Rect2(Vector2(pad + 6.0, grid.end.y + line_h + 6.0),
		Vector2(size.x - pad * 2.0 - 12.0, ruler_h - 12.0))}


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Palette.PAPER, 16)
	var g := _geometry()
	# header: the list and the ear
	AoDraw.rbox(self, Rect2(Vector2(4, 4), Vector2(r.size.x - 8, 24)), Palette.ear_tint(ear), 10)
	AoDraw.text_l(self, Vector2(14, 16), "WORD SCORES", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	if title != "":
		AoDraw.text_r(self, Vector2(r.size.x - 14, 16), title, 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	_draw_grid(g["grid"])
	_draw_line(float(g["line_y"]))
	if show_ruler:
		_draw_ruler(g["ruler"])
	if _flash > 0.0:
		AoDraw.rbox(self, r.grow(-3.0), Color(Palette.SUNNY, 0.35 * _flash), 14)


func _draw_grid(grid: Rect2) -> void:
	var gap := 5.0
	var tw := (grid.size.x - gap * (COLS - 1)) / COLS
	var th := (grid.size.y - gap * (ROWS - 1)) / ROWS
	for i in mini(words, COLS * ROWS):
		var cell := Rect2(grid.position + Vector2((i % COLS) * (tw + gap), (i / COLS) * (th + gap)), Vector2(tw, th))
		var t := _tile(i + 1)
		if t.is_empty() or t.get("mark") == null:
			var live := not t.is_empty()
			var col := Color(Palette.SELECT_ORANGE, 0.55 + 0.35 * sin(_t * 5.0)) if live else Color(Palette.INK, 0.18)
			_dashed_rect(cell.grow(-1.0), col)
			AoDraw.text_c(self, cell.get_center(), "?" if live else str(i + 1), 14 if live else 11,
				Color(Palette.INK, 0.6 if live else 0.25), AoDraw.FONT_BOLD)
			continue
		var s := tile_scale(i + 1)
		var c := cell.get_center()
		var shown := Rect2(c - Vector2(cell.size.x * 0.5, cell.size.y * 0.5 * s), Vector2(cell.size.x, cell.size.y * s))
		var hit := bool(t["mark"])
		var hoot := bool(t["hoot"])
		var fill := Palette.HOOT_BROWN if hoot else (Palette.MINT if hit else Palette.CORAL)
		AoDraw.rbox(self, Rect2(shown.position + Vector2(0, 2), shown.size), Color(Palette.INK, 0.2), 8)
		AoDraw.rbox(self, shown, fill, 8, 2, Palette.INK)
		if s < 0.35:
			continue
		var said := String(t["said"])
		var sym_c := c if hit or said == "" else c + Vector2(0, -th * 0.18)
		var sz := minf(th * 0.42, 18.0)
		if hit:
			UiDraw.check(self, sym_c + Vector2(0, 1), sz, Palette.PAPER if hoot else Palette.INK, 3.0)
		else:
			UiDraw.cross(self, sym_c, sz * 0.62, Palette.PAPER, 3.0)
			if said != "":
				AoDraw.text_c(self, c + Vector2(0, th * 0.27), _fit(said, 10, tw - 6.0), 10, Palette.PAPER if not hoot else Palette.INK,
					AoDraw.FONT_SEMI)


func _draw_line(y: float) -> void:
	var step := roundi(100.0 / float(words))
	var txt := "%d right x %d%% = %d%%" % [right, step, pct_so_far]
	var w := AoDraw.text_l(self, Vector2(16, y), txt, 17, Palette.INK, AoDraw.FONT_BOLD)
	if _band == &"":
		return
	# the band chip lands
	var k := clampf(_band_t / 0.3, 0.0, 1.0)
	var label := String(SpeechRules.WRS_BAND_TITLES.get(_band, "")).to_upper()
	var fs := 14
	var cw := AoDraw.text_size(label, fs, AoDraw.FONT_BOLD).x + 22.0
	var cx := maxf(16.0 + w + 14.0 + cw * 0.5, size.x - 14.0 - cw * 0.5)
	var s := 1.0 if AoFx._reduced() else 1.0 + 0.6 * (1.0 - k) * (1.0 - k)
	var a := k if AoFx._reduced() else 1.0
	draw_set_transform(Vector2(cx, y), deg_to_rad(-4.0 * (1.0 - k)), Vector2.ONE * s)
	var cr := Rect2(Vector2(-cw * 0.5, -13.0), Vector2(cw, 26.0))
	AoDraw.rbox(self, Rect2(cr.position + Vector2(0, 3), cr.size), Color(Palette.INK, 0.3 * a), 13)
	AoDraw.rbox(self, cr, Color(BAND_COLORS.get(_band, Palette.PAPER), a), 13, 2, Color(Palette.INK, a))
	AoDraw.text_c(self, Vector2.ZERO, label, fs, Color(Palette.INK, a), AoDraw.FONT_BOLD)
	draw_set_transform(Vector2.ZERO)


## The band ruler: RULER_FROM..100 with the band ticks, the list's score and (once final) the
## predicted minimum.
func _draw_ruler(rr: Rect2) -> void:
	var bar := Rect2(Vector2(rr.position.x, rr.position.y + rr.size.y - 12.0), Vector2(rr.size.x, 10.0))
	var edges: Array[int] = [RULER_FROM]
	var names: Array[StringName] = [SpeechRules.WRS_BAND_BOTTOM]
	for i in range(SpeechRules.WRS_BANDS.size() - 1, -1, -1):
		edges.append(int((SpeechRules.WRS_BANDS[i] as Array)[0]))
		names.append(StringName((SpeechRules.WRS_BANDS[i] as Array)[1]))
	edges.append(100)
	for i in names.size():
		var x0 := _rx(bar, edges[i])
		var x1 := _rx(bar, edges[i + 1])
		var seg := Rect2(Vector2(x0, bar.position.y), Vector2(x1 - x0, bar.size.y))
		AoDraw.rbox(self, seg.grow(-0.5), Color(BAND_COLORS.get(names[i], Palette.PAPER), 0.85), 3)
		var label := String(SpeechRules.WRS_BAND_TITLES.get(names[i], ""))
		if AoDraw.text_size(label, 10, AoDraw.FONT_SEMI).x > seg.size.x - 4.0:
			label = String(BAND_SHORT.get(names[i], label))
		AoDraw.text_c(self, Vector2(seg.get_center().x, bar.position.y - 9.0), label, 10, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		if i > 0:
			draw_line(Vector2(x0, bar.position.y - 2.0), Vector2(x0, bar.end.y + 2.0), Palette.INK, 2.0)
			AoDraw.text_c(self, Vector2(x0, bar.end.y + 8.0), str(edges[i]), 9, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	AoDraw.ring(self, bar, Palette.INK, 3, 2)
	if predicted_min >= 0:
		var px := _rx(bar, predicted_min)
		draw_colored_polygon(PackedVector2Array([Vector2(px - 6, bar.end.y + 9), Vector2(px + 6, bar.end.y + 9), Vector2(px, bar.end.y + 1)]), Palette.SUNNY)
		draw_polyline(PackedVector2Array([Vector2(px - 6, bar.end.y + 9), Vector2(px + 6, bar.end.y + 9), Vector2(px, bar.end.y + 1),
			Vector2(px - 6, bar.end.y + 9)]), Palette.INK, 1.5, true)
	if list_pct >= 0:
		# the list's score: an ear-coloured bead on the bar (the running line and the chip say the number)
		var mc := Vector2(_rx(bar, list_pct), bar.get_center().y)
		draw_circle(mc, 8.0, Palette.INK)
		draw_circle(mc, 6.0, Palette.ear_color(ear))
		draw_circle(mc + Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.7))


func _rx(bar: Rect2, pct: int) -> float:
	var k := clampf(float(pct - RULER_FROM) / float(100 - RULER_FROM), 0.0, 1.0)
	return bar.position.x + bar.size.x * k


func _dashed_rect(rc: Rect2, col: Color) -> void:
	var p := [rc.position, Vector2(rc.end.x, rc.position.y), rc.end, Vector2(rc.position.x, rc.end.y)]
	for i in 4:
		AoDraw.dashed(self, p[i], p[(i + 1) % 4], col, 1.5, 5.0, 4.0)


## `text` cut to fit `width` at `fs` (with an ellipsis).
static func _fit(text: String, fs: int, width: float) -> String:
	if AoDraw.text_size(text, fs, AoDraw.FONT_SEMI).x <= width:
		return text
	var t := text
	while t.length() > 1 and AoDraw.text_size(t + "...", fs, AoDraw.FONT_SEMI).x > width:
		t = t.substr(0, t.length() - 1)
	return t + "..."
