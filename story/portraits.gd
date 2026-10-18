extends RefCounted
## Portraits: procedural 2D character portraits for the dialogue box and Hoot's bubble.
## Portraits.draw(ci, "Gus", center, radius, talk_open, blink)
## Speakers: "Gus", "Hoot", "Doris", "Bonnie" (v3), "You" (a clipboard), any case-file patient (cases:
## story/case_portraits.gd draws them from their case's "look"), anything else = narrator star.

const CasePortraits := preload("res://story/case_portraits.gd")

const BG: Dictionary = {"Gus": Color("#bfeee6"), "Hoot": Color("#ffe6a8"), "Doris": Color("#ffd9f2"), "Bonnie": Color("#ffe3c2"), "You": Color("#d9e6ff")}
const NAME_COLORS: Dictionary = {"Gus": Color("#2f8f88"), "Hoot": Color("#b9773f"), "Doris": Color("#c0479c"), "Bonnie": Color("#c46a1c"), "You": Color("#2d6cdf"), "": Color("#6b5e7e")}

const INK := Color("#2e2442")
const SKIN := Color("#ffcf9e")
const WHITE := Color("#fffdf8")


static func name_color(speaker: String) -> Color:
	if not NAME_COLORS.has(speaker) and CasePortraits.has(speaker):
		return CasePortraits.name_color(speaker)
	return NAME_COLORS.get(speaker, NAME_COLORS[""])


static func draw(ci: CanvasItem, who: String, c: Vector2, r: float, talk_open: bool = false, blink: bool = false, frame: bool = true) -> void:
	if frame:
		ci.draw_circle(c, r + 5.0, INK)
		ci.draw_circle(c, r, BG.get(who, CasePortraits.bg(who) if CasePortraits.has(who) else Color("#fff3dc")))
	match who:
		"Gus":
			_gus(ci, c, r, talk_open, blink)
		"Hoot":
			_hoot(ci, c, r, talk_open, blink)
		"Doris":
			_doris(ci, c, r, talk_open, blink)
		"Bonnie":
			_bonnie(ci, c, r, talk_open, blink)
		"You":
			_clipboard(ci, c, r)
		_:
			if CasePortraits.has(who):
				CasePortraits.draw(ci, who, c, r, talk_open, blink)
			else:
				UiDraw.star(ci, c, r * 0.6, Palette.SUNNY)


# ---------------------------------------------------------------- helpers

static func _ellipse(ci: CanvasItem, at: Vector2, radii: Vector2, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	ci.draw_colored_polygon(pts, col)


static func _outlined_ellipse(ci: CanvasItem, at: Vector2, radii: Vector2, col: Color, w: float, rot: float = 0.0) -> void:
	_ellipse(ci, at, radii + Vector2(w, w), INK, rot)
	_ellipse(ci, at, radii, col, rot)


## Shoulders: an ellipse clipped to the portrait circle.
static func _shoulders(ci: CanvasItem, c: Vector2, r: float, col: Color, top: float) -> void:
	var pts := PackedVector2Array()
	var center := c + Vector2(0, top + r * 0.55)
	for i in 40:
		var a := TAU * i / 40.0
		var p := center + Vector2(cos(a) * r * 0.85, sin(a) * r * 0.55)
		var d := p - c
		if d.length() > r - 1.0:
			p = c + d.normalized() * (r - 1.0)
		pts.append(p)
	ci.draw_colored_polygon(pts, col)


static func _eye(ci: CanvasItem, at: Vector2, er: float, blink: bool) -> void:
	if blink:
		ci.draw_line(at + Vector2(-er * 0.8, 0), at + Vector2(er * 0.8, 0), INK, maxf(2.0, er * 0.3), true)
		return
	ci.draw_circle(at, er, WHITE)
	ci.draw_circle(at + Vector2(0, er * 0.1), er * 0.55, INK)
	ci.draw_circle(at + Vector2(-er * 0.2, -er * 0.15), er * 0.2, WHITE)


# ---------------------------------------------------------------- characters

static func _gus(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	_shoulders(ci, c, r, Color("#3a9d96"), r * 0.42)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.16, r * 0.5), c + Vector2(r * 0.16, r * 0.5), c + Vector2(0, r * 0.82)]), Color("#fff3dc"))
	_ellipse(ci, c + Vector2(-r * 0.1, r * 0.52), Vector2(r * 0.11, r * 0.07), Color("#ff6f59"))
	_ellipse(ci, c + Vector2(r * 0.1, r * 0.52), Vector2(r * 0.11, r * 0.07), Color("#ff6f59"))
	var h := c + Vector2(0, -r * 0.08)
	var hr := r * 0.5
	for s: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, h + Vector2(hr * 0.98 * s, hr * 0.12), Vector2(hr * 0.17, hr * 0.24), SKIN, 2.5)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, SKIN)
	ci.draw_arc(h + Vector2(0, -hr * 1.08), hr * 0.12, PI * 0.2, PI * 1.9, 12, WHITE.darkened(0.08), 3.0, true)
	for s: float in [-1.0, 1.0]:
		for k in 3:
			var p := h + Vector2(hr * (0.86 + 0.08 * (k % 2)) * s, -hr * (0.32 - 0.22 * k))
			ci.draw_circle(p, hr * 0.17 + 2.0, INK)
		for k in 3:
			var p := h + Vector2(hr * (0.86 + 0.08 * (k % 2)) * s, -hr * (0.32 - 0.22 * k))
			ci.draw_circle(p, hr * 0.17, WHITE)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.38 * s, -hr * 0.12)
		_eye(ci, e, hr * 0.24, blink)
		ci.draw_arc(e, hr * 0.33, 0, TAU, 24, Color("#5a3d2b"), maxf(3.0, hr * 0.09), true)
		ci.draw_line(e + Vector2(-hr * 0.22, -hr * 0.47), e + Vector2(hr * 0.22, -hr * 0.47 - hr * 0.04 * s), WHITE, hr * 0.13, true)
	ci.draw_line(h + Vector2(-hr * 0.06, -hr * 0.12), h + Vector2(hr * 0.06, -hr * 0.12), Color("#5a3d2b"), 3.0, true)
	if talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.56), Vector2(hr * 0.2, hr * 0.17), Color("#7a2a3a"))
	_outlined_ellipse(ci, h + Vector2(-hr * 0.2, hr * 0.36), Vector2(hr * 0.26, hr * 0.13), WHITE, 2.5, 0.25)
	_outlined_ellipse(ci, h + Vector2(hr * 0.2, hr * 0.36), Vector2(hr * 0.26, hr * 0.13), WHITE, 2.5, -0.25)
	_outlined_ellipse(ci, h + Vector2(0, hr * 0.16), Vector2(hr * 0.2, hr * 0.18), Color("#f5a37f"), 2.5)


static func _hoot(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	var b := c + Vector2(0, r * 0.12)
	var br := r * 0.66
	# lopsided tufts
	ci.draw_colored_polygon(PackedVector2Array([b + Vector2(br * 0.35, -br * 0.8), b + Vector2(br * 0.75, -br * 0.55), b + Vector2(br * 0.62, -br * 1.18)]), Color("#b9773f"))
	ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-br * 0.4, -br * 0.78), b + Vector2(-br * 0.78, -br * 0.5), b + Vector2(-br * 0.95, -br * 0.88)]), Color("#b9773f"))
	ci.draw_circle(b, br + 3.0, INK)
	ci.draw_circle(b, br, Color("#d9a066"))
	# heart-shaped face disc
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(b + Vector2(x, y) * br * 0.05 + Vector2(0, -br * 0.05))
	ci.draw_colored_polygon(pts, Color("#fff4e2"))
	for s: float in [-1.0, 1.0]:
		var e := b + Vector2(br * 0.33 * s, -br * 0.12)
		if blink:
			ci.draw_arc(e, br * 0.16, 0.3, PI - 0.3, 10, INK, 3.5, true)
		else:
			ci.draw_circle(e, br * 0.2, INK)
			ci.draw_circle(e + Vector2(-br * 0.06, -br * 0.07), br * 0.065, WHITE)
		ci.draw_arc(e + Vector2(0, br * 0.06), br * 0.24, 0.15, PI - 0.15, 12, Color("#ffd23f"), 3.0, true)
	var beak := b + Vector2(0, br * 0.1)
	ci.draw_colored_polygon(PackedVector2Array([beak + Vector2(-br * 0.1, 0), beak + Vector2(br * 0.1, 0), beak + Vector2(0, br * 0.2)]), Color("#ff9f1c"))
	if talk_open:
		ci.draw_colored_polygon(PackedVector2Array([beak + Vector2(-br * 0.07, br * 0.24), beak + Vector2(br * 0.07, br * 0.24), beak + Vector2(0, br * 0.34)]), Color("#e07a1c"))
	# graduation cap
	var cap := b + Vector2(br * 0.05, -br * 0.95)
	var board := PackedVector2Array([cap + Vector2(-br * 0.7, 0), cap + Vector2(0, -br * 0.28), cap + Vector2(br * 0.7, 0), cap + Vector2(0, br * 0.26)])
	ci.draw_colored_polygon(PackedVector2Array([cap + Vector2(-br * 0.36, br * 0.08), cap + Vector2(br * 0.36, br * 0.08), cap + Vector2(br * 0.3, br * 0.3), cap + Vector2(-br * 0.3, br * 0.3)]), INK)
	ci.draw_colored_polygon(board, INK)
	ci.draw_line(cap, cap + Vector2(br * 0.55, br * 0.05), Palette.SUNNY, 2.5, true)
	ci.draw_line(cap + Vector2(br * 0.55, br * 0.05), cap + Vector2(br * 0.57, br * 0.42), Palette.SUNNY, 2.5, true)
	ci.draw_circle(cap + Vector2(br * 0.57, br * 0.45), 4.0, Palette.SUNNY)


static func _doris(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	_shoulders(ci, c, r, Color("#c77dba"), r * 0.42)
	for i in 7:
		var a := lerpf(-1.0, 1.0, i / 6.0)
		ci.draw_circle(c + Vector2(sin(a) * r * 0.3, r * 0.52 + cos(a) * r * 0.06), r * 0.045, WHITE)
	var h := c + Vector2(0, -r * 0.02)
	var hr := r * 0.44
	var hair := Color("#c9d3ea")
	for p: Array in [[Vector2(0, -hr * 1.35), hr * 0.62], [Vector2(0, -hr * 1.9), hr * 0.42], [Vector2(-hr * 0.85, -hr * 0.3), hr * 0.38], [Vector2(hr * 0.85, -hr * 0.3), hr * 0.38]]:
		ci.draw_circle(h + p[0], float(p[1]) + 3.0, INK)
	for p: Array in [[Vector2(0, -hr * 1.35), hr * 0.62], [Vector2(0, -hr * 1.9), hr * 0.42], [Vector2(-hr * 0.85, -hr * 0.3), hr * 0.38], [Vector2(hr * 0.85, -hr * 0.3), hr * 0.38]]:
		ci.draw_circle(h + p[0], float(p[1]), hair)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, Color("#ffd6b0"))
	_ellipse(ci, h + Vector2(0, -hr * 0.8), Vector2(hr * 0.85, hr * 0.32), hair)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.38 * s, -hr * 0.05)
		_eye(ci, e, hr * 0.2, blink)
		ci.draw_arc(e, hr * 0.3, 0, TAU, 20, Color("#e5383b"), 3.5, true)
		ci.draw_line(e + Vector2(hr * 0.28 * s, -hr * 0.12), e + Vector2(hr * 0.42 * s, -hr * 0.32), Color("#e5383b"), 3.5, true)
		_ellipse(ci, h + Vector2(hr * 0.55 * s, hr * 0.35), Vector2(hr * 0.15, hr * 0.08), Color(1, 0.5, 0.5, 0.5))
	_ellipse(ci, h + Vector2(0, hr * 0.15), Vector2(hr * 0.12, hr * 0.1), Color("#f7b593"))
	if talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.52), Vector2(hr * 0.17, hr * 0.15), Color("#7a2a3a"))
		ci.draw_arc(h + Vector2(0, hr * 0.52), hr * 0.17, 0, TAU, 16, Color("#d9465f"), 3.0, true)
	else:
		ci.draw_arc(h + Vector2(0, hr * 0.32), hr * 0.25, 0.5, PI - 0.5, 12, Color("#d9465f"), 4.0, true)
	ci.draw_circle(h + Vector2(hr * 0.5, -hr * 1.25), hr * 0.14, Color("#ff6f59"))


## (v3) Bonnie Bunsworth: chestnut bun with a wooden spoon, mustard top, flour-dusted apron bib.
static func _bonnie(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	_shoulders(ci, c, r, Color("#f2a541"), r * 0.42)
	var bib := Rect2(c + Vector2(-r * 0.24, r * 0.5), Vector2(r * 0.48, r * 0.5))
	UiDraw.rounded_rect(ci, bib, Color("#fffaf0"), 6)
	ci.draw_circle(c + Vector2(-r * 0.08, r * 0.66), r * 0.03, Color("#e6d8bd"))
	ci.draw_circle(c + Vector2(r * 0.1, r * 0.74), r * 0.025, Color("#e6d8bd"))
	var h := c + Vector2(0, -r * 0.02)
	var hr := r * 0.44
	var hair := Color("#8a4f2a")
	# the wooden spoon through the bun, then the bun and the hair cap
	ci.draw_line(h + Vector2(-hr * 0.9, -hr * 1.05), h + Vector2(hr * 0.9, -hr * 1.75), INK, 7.0, true)
	ci.draw_line(h + Vector2(-hr * 0.9, -hr * 1.05), h + Vector2(hr * 0.9, -hr * 1.75), Color("#d9a066"), 4.0, true)
	_outlined_ellipse(ci, h + Vector2(hr * 1.0, -hr * 1.8), Vector2(hr * 0.2, hr * 0.13), Color("#d9a066"), 2.5, -0.35)
	ci.draw_circle(h + Vector2(0, -hr * 1.3), hr * 0.5 + 3.0, INK)
	ci.draw_circle(h + Vector2(0, -hr * 1.3), hr * 0.5, hair)
	ci.draw_arc(h + Vector2(-hr * 0.05, -hr * 1.35), hr * 0.28, -2.6, -0.8, 10, hair.lightened(0.25), 3.0, true)
	ci.draw_circle(h + Vector2(0, -hr * 0.3), hr * 0.98 + 3.0, INK)
	ci.draw_circle(h + Vector2(0, -hr * 0.3), hr * 0.98, hair)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, Color("#e8b088"))
	_ellipse(ci, h + Vector2(0, -hr * 0.78), Vector2(hr * 0.9, hr * 0.34), hair)
	# her "lost" reading glasses, perched on top of her head all along
	var teal := Color("#2fb3a3")
	for s: float in [-1.0, 1.0]:
		var lc := h + Vector2(hr * 0.24 * s, -hr * 0.86)
		ci.draw_circle(lc, hr * 0.17, Color("#dff6ff"))
		ci.draw_arc(lc, hr * 0.17, 0, TAU, 16, INK, 4.5, true)
		ci.draw_arc(lc, hr * 0.17, 0, TAU, 16, teal, 2.5, true)
		ci.draw_line(lc + Vector2(-hr * 0.07, -hr * 0.06), lc + Vector2(-hr * 0.02, -hr * 0.1), Color(1, 1, 1, 0.9), 1.5, true)
	ci.draw_line(h + Vector2(-hr * 0.07, -hr * 0.88), h + Vector2(hr * 0.07, -hr * 0.88), teal, 2.5, true)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.38 * s, -hr * 0.02)
		for k in 3:
			ci.draw_circle(h + Vector2(hr * (0.42 + 0.1 * k) * s, hr * (0.22 + 0.05 * (k % 2))), maxf(1.2, hr * 0.03), Color("#b0703f"))
		_eye(ci, e, hr * 0.2, blink)
		# (polish) lashes flick up and OUT from the outer corner, and a soft arched brow above:
		# the old single stroke read as a cross eyebrow
		ci.draw_line(e + Vector2(hr * 0.17 * s, -hr * 0.1), e + Vector2(hr * 0.3 * s, -hr * 0.2), INK, 2.5, true)
		ci.draw_line(e + Vector2(hr * 0.1 * s, -hr * 0.17), e + Vector2(hr * 0.19 * s, -hr * 0.29), INK, 2.0, true)
		ci.draw_arc(e + Vector2(0, hr * 0.02), hr * 0.36, -PI * 0.78, -PI * 0.22, 10, hair.darkened(0.2), 3.0, true)
		_ellipse(ci, h + Vector2(hr * 0.55 * s, hr * 0.35), Vector2(hr * 0.15, hr * 0.08), Color(1, 0.45, 0.45, 0.45))
	ci.draw_circle(h + Vector2(-hr * 0.5, hr * 0.12), hr * 0.06, Color(1, 1, 1, 0.7))  # a dab of flour
	_ellipse(ci, h + Vector2(0, hr * 0.15), Vector2(hr * 0.12, hr * 0.1), Color("#dd9670"))
	if talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.52), Vector2(hr * 0.17, hr * 0.15), Color("#7a2a3a"))
		ci.draw_arc(h + Vector2(0, hr * 0.52), hr * 0.17, 0, TAU, 16, Color("#d9465f"), 3.0, true)
	else:
		ci.draw_arc(h + Vector2(0, hr * 0.32), hr * 0.25, 0.5, PI - 0.5, 12, Color("#d9465f"), 4.0, true)


static func _clipboard(ci: CanvasItem, c: Vector2, r: float) -> void:
	var board := Rect2(c + Vector2(-r * 0.45, -r * 0.55), Vector2(r * 0.9, r * 1.15))
	UiDraw.rounded_rect(ci, board.grow(3), INK, 10)
	UiDraw.rounded_rect(ci, board, Color("#c8874b"), 8)
	UiDraw.rounded_rect(ci, Rect2(board.position + Vector2(r * 0.1, r * 0.15), board.size - Vector2(r * 0.2, r * 0.25)), WHITE, 4)
	UiDraw.rounded_rect(ci, Rect2(c + Vector2(-r * 0.2, -r * 0.68), Vector2(r * 0.4, r * 0.22)), Color("#6b5e7e"), 6)
	for i in 3:
		var y := c.y - r * 0.12 + i * r * 0.2
		UiDraw.check(ci, Vector2(c.x - r * 0.2, y), r * 0.16, Palette.MINT, 3.0)
		ci.draw_line(Vector2(c.x - r * 0.05, y), Vector2(c.x + r * 0.27, y), Palette.INK_SOFT, 3.0, true)
