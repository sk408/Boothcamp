extends Control
## ExplainerStage (v4, story-internal): draws and animates one scene "set" of a Hoot movie
## (story/explainers/movies/*.gd) on the cinema screen. The player calls show_scene(scene) when a
## scene starts and sets `t` (seconds into the scene) every frame; the stage redraws itself.
## A set is a reusable little cartoon (the head with two snail cochleas, a cup, the skull wall, the
## buzzer, the Ghost, the noise cloud, the plateau graph). Later movies reuse sets or add new ones:
## add the id to SETS and a branch in _draw_set() (docs/ADDING_A_CHAPTER.md, "Hoot's movies").
##
## INTEGRATOR STUB: simple placeholder drawings (head, snails, one prop per set) so the movie plays
## end to end. Builder B owns the real animation: follow each scene's "board" brief in the movie file.

const SETS: Array[StringName] = [&"meet", &"air", &"wall", &"bone", &"ghost", &"mask", &"under", &"over", &"plateau", &"outro"]
const UiKit := preload("res://story/ui_kit.gd")
const NOISE := Color("#8e5cc4")
const BONE_GREY := Color("#b9c0cc")

var set_id: StringName = &"meet"
var params: Dictionary = {}
var scene_id := ""
## Seconds since the scene started (the player sets it every frame).
var t := 0.0
var duration := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_scene(scene: Dictionary) -> void:
	set_id = StringName(String(scene.get("set", "meet")))
	params = scene.get("params", {})
	scene_id = String(scene.get("id", ""))
	duration = maxf(0.1, float(scene.get("duration", 1.0)))
	t = 0.0
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


# ---------------------------------------------------------------- drawing (stub)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	UiDraw.rounded_rect(self, r, Palette.CREAM, 26, 4, Palette.INK)
	if set_id == &"plateau":
		_draw_plateau(r)
		return
	var c := r.get_center() + Vector2(0, 10)
	var hr := minf(r.size.x * 0.26, r.size.y * 0.38)
	var jiggle := Vector2.ZERO
	if set_id == &"bone" and t > 1.2:
		jiggle = Vector2(sin(t * 38.0) * 3.0, cos(t * 31.0) * 2.0)
	_draw_head(c + jiggle, hr)
	var rp := c + jiggle + Vector2(-hr * 0.52, hr * 0.08)   # Righty: the head's right = the screen's left
	var lp := c + jiggle + Vector2(hr * 0.52, hr * 0.08)
	var ghosting := set_id == &"ghost" and t > 2.4
	_draw_snail(rp, hr * 0.2, Palette.RIGHT_RED, "RIGHTY", set_id == &"ghost" and t < 6.0)
	if not ghosting:
		_draw_snail(lp, hr * 0.2, Palette.LEFT_BLUE, "LEFTY", set_id == &"air")
	match set_id:
		&"meet":
			if t < 2.4:
				_title_card(r)
		&"air":
			_cup(c + Vector2(-hr * 1.02, 0), hr, Palette.RIGHT_RED)
			_notes(c + Vector2(-hr * 0.98, 0), rp, 3, 0.0)
		&"wall":
			_cup(c + Vector2(-hr * 1.02, 0), hr, Palette.RIGHT_RED)
			_wall(c, hr, "-%d dB" % int(params.get("ia", 40)))
			var lv: Array = params.get("levels", [30, 50, 70])
			var k := clampi(int(t / (duration / maxf(1.0, lv.size()))), 0, lv.size() - 1)
			_chip("%d dB" % int(lv[k]), c + Vector2(-hr * 1.02, -hr * 0.5), Palette.SUNNY)
		&"bone":
			_buzzer(rp + Vector2(-hr * 0.42, hr * 0.36), hr)
			_wall(c, hr, "-0 dB", 0.35)
		&"ghost":
			_buzzer(rp + Vector2(-hr * 0.42, hr * 0.36), hr)
			if ghosting:
				var k2 := clampf((t - 2.4) / 2.0, 0.0, 1.0)
				_ghost(lp.lerp(rp + Vector2(0, -hr * 0.42), k2), hr * 0.24)
				if k2 >= 1.0:
					_chip("BOO!", rp + Vector2(0, -hr * 0.85), Palette.PAPER, 34)
		&"mask", &"under", &"over":
			_buzzer(rp + Vector2(-hr * 0.42, hr * 0.36), hr)
			_cup(c + Vector2(hr * 1.02, 0), hr, Palette.LEFT_BLUE)
			var big := 1.0 if set_id == &"mask" else (0.55 if set_id == &"under" else 1.7)
			_cloud(lp, hr * 0.42 * big * clampf(t / 1.2, 0.2, 1.0))
			if set_id == &"under" and t > 1.4:
				_ghost(lp + Vector2(0, -hr * 0.2), hr * 0.16)
			if set_id == &"over":
				_wall(c, hr, "-40 dB")
				if t > 2.5:
					_cloud(rp, hr * 0.32 * clampf((t - 2.5) / 1.5, 0.1, 1.0))
					_chip("TOO MUCH NOISE!", c + Vector2(0, -hr * 1.05), Palette.CORAL, 28)
		&"outro":
			if t > 1.2:
				_chip("THE END?", c + Vector2(0, -hr * 1.08), Palette.SUNNY, 34)
	if OS.is_debug_build() and Game.cli.has("explainer-debug"):
		draw_string(UiKit.font(600), Vector2(16, 26), "set %s  t %.1f" % [set_id, t], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_SOFT)


func _draw_head(c: Vector2, hr: float) -> void:
	draw_circle(c + Vector2(0, 10), hr, Color(Palette.INK, 0.18))
	draw_circle(c, hr, Palette.SKIN)
	draw_arc(c, hr, 0.0, TAU, 64, Palette.INK, 5.0, true)
	# the see-through window into the skull
	_ellipse(c + Vector2(0, hr * 0.08), Vector2(hr * 0.86, hr * 0.5), Color("#fff6ea"))
	draw_polyline(_ellipse_pts(c + Vector2(0, hr * 0.08), Vector2(hr * 0.86, hr * 0.5)), Color(Palette.INK, 0.35), 3.0, true)
	# ears and a smile, so it reads as a friendly head
	for s: float in [-1.0, 1.0]:
		_ellipse(c + Vector2(s * hr * 0.98, 0), Vector2(hr * 0.12, hr * 0.2), Palette.SKIN)
		draw_polyline(_ellipse_pts(c + Vector2(s * hr * 0.98, 0), Vector2(hr * 0.12, hr * 0.2)), Palette.INK, 4.0, true)
	for s: float in [-1.0, 1.0]:
		draw_circle(c + Vector2(s * hr * 0.26, -hr * 0.55), hr * 0.06, Palette.INK)
	draw_arc(c + Vector2(0, -hr * 0.42), hr * 0.16, 0.3, PI - 0.3, 12, Palette.INK, 4.0, true)


func _draw_snail(at: Vector2, r: float, col: Color, tag: String, perky: bool) -> void:
	var bob := sin(t * 3.0 + at.x * 0.01) * 3.0
	var p := at + Vector2(0, bob)
	# body + eye stalks
	_ellipse(p + Vector2(0, r * 0.8), Vector2(r * 1.3, r * 0.38), col.lightened(0.55))
	for s: float in [-0.3, 0.3]:
		var tip := p + Vector2(r * (0.9 + s), -r * (0.2 + (0.25 if perky else 0.0)))
		draw_line(p + Vector2(r * 0.8, r * 0.5), tip, Palette.INK, 3.0, true)
		draw_circle(tip, r * 0.12, Palette.INK)
	# the shell: a spiral
	draw_circle(p, r, col)
	draw_arc(p, r, 0.0, TAU, 40, Palette.INK, 4.0, true)
	var pts := PackedVector2Array()
	for i in 60:
		var a := i * 0.28
		pts.append(p + Vector2(cos(a), sin(a)) * r * (0.92 - i * 0.014))
	draw_polyline(pts, Color(Palette.INK, 0.8), 3.0, true)
	var f := UiKit.font(700)
	var w := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	draw_string_outline(f, p + Vector2(-w * 0.5, r * 1.75), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 6, Palette.PAPER)
	draw_string(f, p + Vector2(-w * 0.5, r * 1.75), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col.darkened(0.2))


func _cup(at: Vector2, hr: float, col: Color) -> void:
	var rr := Rect2(at - Vector2(hr * 0.14, hr * 0.26), Vector2(hr * 0.28, hr * 0.52))
	UiDraw.rounded_rect(self, rr, col, 18, 4, Palette.INK)


func _buzzer(at: Vector2, hr: float) -> void:
	var rr := Rect2(at - Vector2(hr * 0.1, hr * 0.13), Vector2(hr * 0.2, hr * 0.26))
	UiDraw.rounded_rect(self, rr, Color("#e3d9c6"), 10, 4, Palette.INK)
	if t > 1.0:
		for i in 2:
			var rad := hr * (0.2 + 0.07 * i) + 3.0 * sin(t * 18.0 + i)
			draw_arc(at, rad, PI * 0.6, PI * 1.4, 8, Color(Palette.INK, 0.5), 3.0, true)


func _wall(c: Vector2, hr: float, sign_text: String, alpha: float = 1.0) -> void:
	var rr := Rect2(c + Vector2(-hr * 0.07, -hr * 0.36), Vector2(hr * 0.14, hr * 0.88))
	UiDraw.rounded_rect(self, rr, Color(Color("#d98b5f"), alpha), 6, 3, Color(Palette.INK, alpha))
	for i in 5:
		var y := rr.position.y + rr.size.y * (i + 1) / 6.0
		draw_line(Vector2(rr.position.x, y), Vector2(rr.end.x, y), Color(Palette.INK, 0.4 * alpha), 2.0)
	_chip(sign_text, c + Vector2(0, -hr * 0.5), Palette.PAPER, 22)


func _notes(from: Vector2, to: Vector2, n: int, delay: float) -> void:
	for i in n:
		var k := fposmod((t - delay) * 0.45 - i * 0.33, 1.0)
		var p := from.lerp(to, k) + Vector2(0, -sin(k * PI) * 30.0)
		draw_circle(p, 7.0, Palette.INK)
		draw_line(p + Vector2(6, 0), p + Vector2(6, -22), Palette.INK, 3.0)


func _ghost(at: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		pts.append(at + Vector2(cos(a), sin(a)) * r)
	for i in 7:
		var x := r - 2.0 * r * i / 6.0
		pts.append(at + Vector2(x, r * (1.1 if i % 2 == 0 else 0.8)))
	draw_colored_polygon(pts, Color("#f4f1ff"))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Palette.INK, 4.0, true)
	for s: float in [-0.35, 0.35]:
		draw_circle(at + Vector2(s * r, -r * 0.1), r * 0.12, Palette.INK)


func _cloud(at: Vector2, r: float) -> void:
	for i in 7:
		var a := TAU * i / 7.0 + t * 0.6
		draw_circle(at + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.42, Color(NOISE, 0.35))
	var f := UiKit.font(700)
	draw_string(f, at + Vector2(-r * 0.45, r * 0.12), "shhh", HORIZONTAL_ALIGNMENT_LEFT, -1, int(clampf(r * 0.4, 14.0, 34.0)), NOISE.darkened(0.3))


func _chip(text: String, at: Vector2, bg: Color, px: int = 24) -> void:
	var f := UiKit.font(700)
	var s := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px)
	var rr := Rect2(at - Vector2(s.x * 0.5 + 14.0, s.y * 0.5 + 4.0), Vector2(s.x + 28.0, s.y + 8.0))
	UiDraw.rounded_rect(self, rr, bg, 14, 3, Palette.INK)
	draw_string(f, Vector2(rr.position.x + 14.0, rr.position.y + 4.0 + f.get_ascent(px)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Palette.INK)


func _title_card(r: Rect2) -> void:
	UiDraw.rounded_rect(self, r.grow(-18), Color(Palette.INK, 0.92), 22)
	var f := UiKit.font(700)
	for row: Array in [["HOOT'S MOVIE MATINEE", 26, Palette.SUNNY, -40.0], ["The Cross-Hearing Ghost", 44, Palette.PAPER, 18.0]]:
		var w := f.get_string_size(String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(row[1])).x
		draw_string(f, r.get_center() + Vector2(-w * 0.5, float(row[3])), String(row[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, int(row[1]), row[2])


func _draw_plateau(r: Rect2) -> void:
	var g := r.grow(-60)
	g.position.y += 10
	draw_line(g.position + Vector2(0, g.size.y), g.end, Palette.INK, 4.0)
	draw_line(g.position, g.position + Vector2(0, g.size.y), Palette.INK, 4.0)
	var f := UiKit.font(600)
	draw_string(f, Vector2(g.get_center().x - 90, g.end.y + 34), "more shhh (dB EM) ->", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_SOFT)
	draw_string(f, g.position + Vector2(10, 4), "answer (dB HL)", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_SOFT)
	var pts: Array = (params.get("rise", []) as Array) + (params.get("flat", []) as Array) + (params.get("over", []) as Array)
	var shown := clampi(int(t / (duration * 0.8) * pts.size()) + 1, 1, pts.size())
	var to_px := func(p: Array) -> Vector2:
		return Vector2(g.position.x + g.size.x * (float(p[0]) - 5.0) / 75.0, g.end.y - g.size.y * float(p[1]) / 45.0)
	var prev := Vector2.INF
	for i in shown:
		var p: Vector2 = to_px.call(pts[i])
		var flat := (params.get("flat", []) as Array).has(pts[i]) or (i == (params.get("rise", []) as Array).size() - 1)
		if prev != Vector2.INF:
			draw_line(prev, p, Palette.MINT if flat else Palette.CORAL, 6.0, true)
		draw_circle(p, 9.0, Palette.RIGHT_RED)
		draw_arc(p, 9.0, 0.0, TAU, 16, Palette.INK, 3.0, true)
		prev = p
	if shown >= (params.get("rise", []) as Array).size() + (params.get("flat", []) as Array).size():
		_chip("PLATEAU! 15 dB", Vector2(g.get_center().x, g.position.y + g.size.y * 0.25), Palette.MINT, 26)


func _ellipse_pts(c: Vector2, rr: Vector2, n: int = 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rr.x, sin(a) * rr.y))
	return pts


func _ellipse(c: Vector2, rr: Vector2, col: Color) -> void:
	draw_colored_polygon(_ellipse_pts(c, rr), col)
