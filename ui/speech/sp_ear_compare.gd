class_name SpEarCompare
extends Control
## SpEarCompare: the two ears' word scores side by side (ui/speech only; CONTRACTS.md §9.17.1 with
## amendment A3). It appears once both ears have a counted list. Each ear gets a bar to its best
## counted score and, behind it, the band of scores chance alone could give on a list that long
## (SpeechRules.wrs_same_range, the 25-word critical difference): bands that do not overlap are the
## picture. Once both bests are final the verdict lands: too far apart for chance, or within it.

## {pct, words, final} per ear ({} = no counted list yet).
var right: Dictionary = {}
var left: Dictionary = {}
var _verdict_t := 0.0
var _had_verdict := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_ears(r: Dictionary, l: Dictionary) -> void:
	right = r.duplicate()
	left = l.duplicate()
	var v := verdict()
	if v != &"" and not _had_verdict:
		_verdict_t = 0.0
	_had_verdict = v != &""
	queue_redraw()


func ready_to_show() -> bool:
	return int(right.get("pct", -1)) >= 0 and int(left.get("pct", -1)) >= 0


## &"differ" (too far apart for chance), &"same" (within it), or &"" until both bests are final.
func verdict() -> StringName:
	if not ready_to_show() or not bool(right.get("final", false)) or not bool(left.get("final", false)):
		return &""
	var differ := SpeechRules.wrs_differ(float(right["pct"]), int(right.get("words", SpeechRules.WRS_WORDS)),
		float(left["pct"]), int(left.get("words", SpeechRules.WRS_WORDS)))
	return &"differ" if differ else &"same"


## The same-range band of one ear (lo, hi in %).
func band_of(d: Dictionary) -> Vector2i:
	return SpeechRules.wrs_same_range(float(d.get("pct", 0)), int(d.get("words", SpeechRules.WRS_WORDS)))


func _process(delta: float) -> void:
	_verdict_t += delta
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Palette.PAPER, 16)
	AoDraw.text_l(self, Vector2(14, 15), "EAR COMPARE", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	AoDraw.text_r(self, Vector2(r.size.x - 14, 15), "band = chance", 10, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	var x0 := 40.0
	var x1 := r.size.x - 18.0
	var rows := [["right", right], ["left", left]]
	# header 26, two rows, the 0 / 50 / 100 scale (14) and the verdict pill (28) at the bottom
	var top := 26.0
	var row_h := clampf((r.size.y - top - 14.0 - 28.0 - 10.0) / 2.0, 14.0, 30.0)
	for i in 2:
		var e := String(rows[i][0])
		var d: Dictionary = rows[i][1]
		var y := top + i * (row_h + 5.0)
		var track := Rect2(Vector2(x0, y), Vector2(x1 - x0, row_h))
		AoDraw.rbox(self, track, Color(Palette.INK, 0.05), 6, 1, Color(Palette.INK, 0.2))
		draw_circle(Vector2(20, y + row_h * 0.5), 10.0, Palette.ear_color(e))
		AoDraw.text_c(self, Vector2(20, y + row_h * 0.5), "R" if e == "right" else "L", 12, Palette.PAPER, AoDraw.FONT_BOLD)
		if int(d.get("pct", -1)) < 0:
			AoDraw.text_c(self, track.get_center(), "no counted list yet", 11, Palette.INK_SOFT, AoDraw.FONT_SEMI)
			continue
		var b := band_of(d)
		var bx0 := lerpf(x0, x1, b.x / 100.0)
		var bx1 := lerpf(x0, x1, b.y / 100.0)
		AoDraw.rbox(self, Rect2(Vector2(bx0, y + 2.0), Vector2(maxf(4.0, bx1 - bx0), row_h - 4.0)), Color(Palette.ear_color(e), 0.22), 5, 2,
			Color(Palette.ear_color(e), 0.55))
		var px := lerpf(x0, x1, clampf(float(d["pct"]) / 100.0, 0.0, 1.0))
		draw_line(Vector2(px, y - 2.0), Vector2(px, y + row_h + 2.0), Palette.ear_color(e), 4.0)
		var label := "%d%%" % int(d["pct"])
		var lx := px + 6.0 if px < x1 - 40.0 else px - 6.0 - AoDraw.text_size(label, 13, AoDraw.FONT_BOLD).x
		AoDraw.text_l(self, Vector2(lx, y + row_h * 0.5), label, 13, Palette.INK, AoDraw.FONT_BOLD)
	# the scale
	var sy := top + 2.0 * row_h + 5.0
	for p: int in [0, 50, 100]:
		AoDraw.text_c(self, Vector2(lerpf(x0, x1, p / 100.0), sy + 6.0), "%d" % p, 9, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	var v := verdict()
	var vy := r.size.y - 18.0
	if v == &"":
		AoDraw.text_c(self, Vector2(r.size.x * 0.5, vy), "Is each ear's best final yet?", 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		return
	var k := 1.0 if AoFx._reduced() else clampf(_verdict_t / 0.3, 0.0, 1.0)
	var col := Palette.CORAL if v == &"differ" else Palette.MINT
	var txt := "Too far apart for chance" if v == &"differ" else "Within chance: no flag"
	var w := AoDraw.text_size(txt, 13, AoDraw.FONT_BOLD).x + 22.0
	var vr := Rect2(Vector2(r.size.x * 0.5 - w * 0.5, vy - 12.0), Vector2(w, 24.0))
	AoDraw.rbox(self, vr, Color(col, k), 12, 2, Color(Palette.INK, k))
	AoDraw.text_c(self, vr.get_center(), txt, 13, Color(Palette.INK, k), AoDraw.FONT_BOLD)
