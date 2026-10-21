extends RefCounted
## Portraits: procedural 2D character portraits for the dialogue box and Hoot's bubble.
## Portraits.draw(ci, "Gus", center, radius, talk_open, blink)
## Speakers: "Gus", "Hoot", "Doris", "Bonnie" (v3), "Mike" (Speech), "Nora", "Marco", "Rosa" (Days 4-5), "You" (a clipboard), any case-file patient
## (cases: story/case_portraits.gd draws them from their case's "look"), anything else = narrator star.

const CasePortraits := preload("res://story/case_portraits.gd")

const BG: Dictionary = {"Gus": Color("#bfeee6"), "Hoot": Color("#ffe6a8"), "Doris": Color("#ffd9f2"), "Bonnie": Color("#ffe3c2"), "Mike": Color("#fff0a6"), "Nora": Color("#d8f0e4"), "Marco": Color("#ffe1b8"), "Rosa": Color("#e3ecff"), "You": Color("#d9e6ff")}
const NAME_COLORS: Dictionary = {"Gus": Color("#2f8f88"), "Hoot": Color("#b9773f"), "Doris": Color("#c0479c"), "Bonnie": Color("#c46a1c"), "Mike": Color("#a3333d"), "Nora": Color("#2f7d5b"), "Marco": Color("#b5652a"), "Rosa": Color("#3e5fa8"), "You": Color("#2d6cdf"), "": Color("#6b5e7e")}

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
		var bg: Color = BG[who] if BG.has(who) else (CasePortraits.bg(who) if CasePortraits.has(who) else Color("#fff3dc"))
		ci.draw_circle(c, r, bg)
	match who:
		"Gus":
			_gus(ci, c, r, talk_open, blink)
		"Hoot":
			_hoot(ci, c, r, talk_open, blink)
		"Doris":
			_doris(ci, c, r, talk_open, blink)
		"Bonnie":
			_bonnie(ci, c, r, talk_open, blink)
		"Mike":
			_mike(ci, c, r, talk_open, blink)
		"Nora":
			_nora(ci, c, r, talk_open, blink)
		"Marco":
			_marco(ci, c, r, talk_open, blink)
		"Rosa":
			_rosa(ci, c, r, talk_open, blink)
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


## (Speech) Mike Lenders: hi-vis vest over a cherry bowling shirt, a foam neck brace, a slick quiff
## with sunglasses pushed up on it, stubble and a big show-off grin.
static func _mike(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	var lime := Color("#d6ef3a")
	var hair := Color("#3a2a22")
	var skin := Color("#d9a07a")
	_shoulders(ci, c, r, Color("#a3333d"), r * 0.42)
	# the vest panels with their silver band, the shirt's cream camp collar between them
	for s: float in [-1.0, 1.0]:
		var panel := PackedVector2Array([c + Vector2(r * 0.2 * s, r * 0.5), c + Vector2(r * 0.72 * s, r * 0.62), c + Vector2(r * 0.86 * s, r), c + Vector2(r * 0.16 * s, r)])
		var clipped := PackedVector2Array()
		for p: Vector2 in panel:
			var d := p - c
			clipped.append(c + d.normalized() * minf(d.length(), r - 1.0))
		ci.draw_colored_polygon(clipped, lime)
		ci.draw_line(c + Vector2(r * 0.18 * s, r * 0.78), c + Vector2(r * 0.6 * s, r * 0.78), Color("#eef2f7"), r * 0.09, true)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.04 * s, r * 0.44), c + Vector2(r * 0.34 * s, r * 0.47), c + Vector2(r * 0.18 * s, r * 0.62)]), Color("#fff3dc"))
	var h := c + Vector2(0, -r * 0.06)
	var hr := r * 0.44
	# the foam neck brace under the chin
	UiDraw.rounded_rect(ci, Rect2(c + Vector2(-hr * 0.78, hr * 0.62), Vector2(hr * 1.56, hr * 0.5)), INK, int(hr * 0.22))
	UiDraw.rounded_rect(ci, Rect2(c + Vector2(-hr * 0.72, hr * 0.66), Vector2(hr * 1.44, hr * 0.42)), Color("#f4ecdc"), int(hr * 0.2))
	ci.draw_line(c + Vector2(-hr * 0.12, hr * 0.87), c + Vector2(hr * 0.12, hr * 0.87), Color("#b9c0cc"), 3.0, true)
	# ears, head, sideburns
	for s: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, h + Vector2(hr * 0.98 * s, hr * 0.08), Vector2(hr * 0.15, hr * 0.22), skin, 2.5)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, skin)
	for s: float in [-1.0, 1.0]:
		ci.draw_rect(Rect2(h + Vector2(hr * 0.82 * s - hr * 0.09, -hr * 0.45), Vector2(hr * 0.18, hr * 0.45)), hair)
	# stubble along the jaw
	for i in 15:
		var a := lerpf(0.35, PI - 0.35, i / 14.0)
		for k in 2:
			var p := h + Vector2(cos(a), sin(a)) * hr * (0.78 - 0.13 * k) + Vector2(0, hr * 0.08)
			ci.draw_circle(p, maxf(1.0, hr * 0.035), Color("#5a3d2b", 0.45))
	# the quiff
	_ellipse(ci, h + Vector2(0, -hr * 0.72), Vector2(hr * 1.0, hr * 0.42), hair)
	_outlined_ellipse(ci, h + Vector2(hr * 0.12, -hr * 1.08), Vector2(hr * 0.78, hr * 0.36), hair, 3.0, -0.12)
	ci.draw_arc(h + Vector2(hr * 0.1, -hr * 1.1), hr * 0.45, -2.7, -1.2, 10, hair.lightened(0.3), 3.0, true)
	# the sunglasses, pushed up on the hairline
	for s: float in [-1.0, 1.0]:
		var lc := h + Vector2(hr * 0.3 * s, -hr * 0.66)
		_outlined_ellipse(ci, lc, Vector2(hr * 0.26, hr * 0.15), Color("#26394a"), 3.5)
		ci.draw_line(lc + Vector2(-hr * 0.12, -hr * 0.04), lc + Vector2(-hr * 0.02, -hr * 0.09), Color(1, 1, 1, 0.85), 2.0, true)
	ci.draw_line(h + Vector2(-hr * 0.06, -hr * 0.7), h + Vector2(hr * 0.06, -hr * 0.7), INK, 3.5, true)
	# eyes and bushy brows (one cocked: a showman)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.37 * s, -hr * 0.08)
		_eye(ci, e, hr * 0.19, blink)
		var lift := hr * (0.1 if s > 0.0 else 0.0)
		ci.draw_line(e + Vector2(-hr * 0.2, -hr * 0.3 - lift), e + Vector2(hr * 0.2, -hr * 0.34 - lift * 0.5 - hr * 0.04 * s), hair, hr * 0.12, true)
	_ellipse(ci, h + Vector2(0, hr * 0.14), Vector2(hr * 0.13, hr * 0.11), Color("#cf8f69"))
	if talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.5), Vector2(hr * 0.22, hr * 0.17), Color("#7a2a3a"))
		_ellipse(ci, h + Vector2(0, hr * 0.42), Vector2(hr * 0.18, hr * 0.05), WHITE)
	else:
		# a big toothy show-off grin
		var pts := PackedVector2Array()
		for i in 13:
			var a := lerpf(0.15, PI - 0.15, i / 12.0)
			pts.append(h + Vector2(hr * 0.02, hr * 0.34) + Vector2(cos(a) * hr * 0.32, sin(a) * hr * 0.2))
		ci.draw_colored_polygon(pts, WHITE)
		pts.append(pts[0])
		ci.draw_polyline(pts, INK, 3.0, true)


## (Days 4-5) Nora Nightingale: a silver bob with a tuning-fork pin, a forest-green cardigan, a navy
## scarf printed with cream music notes, and pearl opera glasses on a gold chain.
static func _nora(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	var hair := Color("#d7dbe3")
	var skin := Color("#f2c4a0")
	var navy := Color("#1f2f5c")
	var cream := Color("#f6ecd2")
	var gold := Color("#e0b84f")
	_shoulders(ci, c, r, Color("#2f6b4f"), r * 0.42)
	# the opera glasses on their chain, below the scarf
	for s: float in [-1.0, 1.0]:
		ci.draw_line(c + Vector2(r * 0.22 * s, r * 0.5), c + Vector2(r * 0.1 * s, r * 0.8), gold, 2.0, true)
	for s: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(r * 0.09 * s, r * 0.84), r * 0.075 + 2.5, INK)
		ci.draw_circle(c + Vector2(r * 0.09 * s, r * 0.84), r * 0.075, Color("#f4efe6"))
		ci.draw_arc(c + Vector2(r * 0.09 * s, r * 0.84), r * 0.045, 0, TAU, 12, gold, 2.0, true)
	# the scarf: a navy band under the chin, a knot and its notes
	var scarf := PackedVector2Array()
	for i in 17:
		var a := lerpf(0.15, PI - 0.15, i / 16.0)
		scarf.append(c + Vector2(cos(a) * r * 0.42, r * 0.36 + sin(a) * r * 0.2))
	for i in 17:
		var a := lerpf(PI - 0.15, 0.15, i / 16.0)
		scarf.append(c + Vector2(cos(a) * r * 0.34, r * 0.3 + sin(a) * r * 0.1))
	ci.draw_colored_polygon(scarf, navy)
	_outlined_ellipse(ci, c + Vector2(-r * 0.16, r * 0.56), Vector2(r * 0.08, r * 0.07), navy.lightened(0.08), 2.0)
	for p: Vector2 in [Vector2(-0.3, 0.44), Vector2(0.05, 0.53), Vector2(0.28, 0.45)]:
		var at := c + p * r
		_ellipse(ci, at, Vector2(r * 0.03, r * 0.022), cream, -0.4)
		ci.draw_line(at + Vector2(r * 0.026, 0), at + Vector2(r * 0.026, -r * 0.08), cream, 1.5, true)
	var h := c + Vector2(0, -r * 0.04)
	var hr := r * 0.44
	# the bob: a rounded helmet that falls to the jaw, behind the face
	ci.draw_circle(h + Vector2(0, -hr * 0.2), hr * 1.12 + 3.0, INK)
	ci.draw_circle(h + Vector2(0, -hr * 0.2), hr * 1.12, hair)
	for s: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, h + Vector2(hr * 0.86 * s, hr * 0.38), Vector2(hr * 0.3, hr * 0.42), hair, 3.0)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, skin)
	# the side-swept fringe and a soft highlight
	_ellipse(ci, h + Vector2(hr * 0.12, -hr * 0.74), Vector2(hr * 0.95, hr * 0.36), hair, -0.12)
	ci.draw_arc(h + Vector2(-hr * 0.2, -hr * 0.95), hr * 0.5, -2.6, -1.3, 10, Color(1, 1, 1, 0.7), 3.0, true)
	# the tuning-fork pin over her left temple (the viewer's right)
	var pin := h + Vector2(hr * 0.62, -hr * 0.82)
	var steel := Color("#c3ccd6")
	ci.draw_line(pin + Vector2(-hr * 0.16, hr * 0.2), pin, INK, 5.0, true)
	ci.draw_line(pin + Vector2(-hr * 0.16, hr * 0.2), pin, steel, 3.0, true)
	for s: float in [-1.0, 1.0]:
		var base := pin + Vector2(hr * 0.06 * s, hr * 0.02)
		ci.draw_line(base, base + Vector2(hr * 0.12, -hr * 0.2), INK, 4.5, true)
		ci.draw_line(base, base + Vector2(hr * 0.12, -hr * 0.2), steel, 2.5, true)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.38 * s, -hr * 0.04)
		_eye(ci, e, hr * 0.19, blink)
		# a gently raised, theatrical brow and a lash flick
		ci.draw_arc(e + Vector2(0, hr * 0.02), hr * 0.36, -PI * 0.8, -PI * 0.2, 10, Color("#9aa1ad"), 3.0, true)
		ci.draw_line(e + Vector2(hr * 0.17 * s, -hr * 0.1), e + Vector2(hr * 0.29 * s, -hr * 0.19), INK, 2.5, true)
		_ellipse(ci, h + Vector2(hr * 0.55 * s, hr * 0.33), Vector2(hr * 0.15, hr * 0.08), Color(1, 0.5, 0.5, 0.45))
	_ellipse(ci, h + Vector2(0, hr * 0.14), Vector2(hr * 0.12, hr * 0.1), Color("#e9ab88"))
	if talk_open:
		# mid-song: a round open "oh"
		_ellipse(ci, h + Vector2(0, hr * 0.52), Vector2(hr * 0.15, hr * 0.17), Color("#7a2a3a"))
		ci.draw_arc(h + Vector2(0, hr * 0.52), hr * 0.16, 0, TAU, 16, Color("#c4506a"), 3.0, true)
	else:
		ci.draw_arc(h + Vector2(0, hr * 0.32), hr * 0.25, 0.5, PI - 0.5, 12, Color("#c4506a"), 4.0, true)


## (Days 4-5) Marco Polenta: silver hair swept back, a grand curled moustache, half-moon glasses low
## on his nose on a gold chain, a tomato-red cravat, a mustard waistcoat and his napkin tucked in.
static func _marco(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	var hair := Color("#dfe3ea")
	var skin := Color("#e9b48c")
	var gold := Color("#b88a3a")
	var red := Color("#e2412f")
	_shoulders(ci, c, r, Color("#d9a23a"), r * 0.42)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.2, r * 0.48), c + Vector2(r * 0.2, r * 0.48), c + Vector2(0, r * 0.8)]), Color("#fbf1dc"))
	# the napkin, tucked in under the cravat
	var nap := PackedVector2Array([c + Vector2(-r * 0.3, r * 0.6), c + Vector2(r * 0.3, r * 0.6), c + Vector2(0, r * 0.98)])
	ci.draw_colored_polygon(nap, WHITE)
	nap.append(nap[0])
	ci.draw_polyline(nap, INK, 2.5, true)
	_outlined_ellipse(ci, c + Vector2(0, r * 0.54), Vector2(r * 0.14, r * 0.08), red, 2.0)
	var h := c + Vector2(0, -r * 0.06)
	var hr := r * 0.47
	for s: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, h + Vector2(hr * 0.98 * s, hr * 0.12), Vector2(hr * 0.16, hr * 0.23), skin, 2.5)
	# the hair, swept back: a silver cap behind the head, full at the sides
	ci.draw_circle(h + Vector2(0, -hr * 0.18), hr * 1.04 + 3.0, INK)
	ci.draw_circle(h + Vector2(0, -hr * 0.18), hr * 1.04, hair)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, skin)
	_ellipse(ci, h + Vector2(0, -hr * 0.8), Vector2(hr * 0.86, hr * 0.32), hair)
	for k in 3:
		var x := (k - 1) * hr * 0.3
		ci.draw_line(h + Vector2(x, -hr * 0.66), h + Vector2(x * 1.15, -hr * 1.02), hair.darkened(0.18), 2.0, true)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.36 * s, -hr * 0.16)
		_eye(ci, e, hr * 0.19, blink)
		ci.draw_line(e + Vector2(-hr * 0.2, -hr * 0.3), e + Vector2(hr * 0.2, -hr * 0.34), hair.darkened(0.25), hr * 0.11, true)
		# a half-moon lens below the eye: he looks over it
		var lc := e + Vector2(0, hr * 0.12)
		ci.draw_arc(lc, hr * 0.22, 0.05, PI - 0.05, 12, gold, 3.0, true)
		ci.draw_line(lc + Vector2(-hr * 0.22, 0), lc + Vector2(hr * 0.22, 0), gold, 2.5, true)
	# the chain from the glasses down past the jaw
	for s: float in [-1.0, 1.0]:
		ci.draw_line(h + Vector2(hr * 0.58 * s, -hr * 0.04), h + Vector2(hr * 0.86 * s, hr * 0.86), Color("#e0b84f"), 1.5, true)
	_outlined_ellipse(ci, h + Vector2(0, hr * 0.1), Vector2(hr * 0.13, hr * 0.12), Color("#e09f7a"), 2.0)
	if talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.58), Vector2(hr * 0.17, hr * 0.15), Color("#7a2a3a"))
	else:
		ci.draw_arc(h + Vector2(0, hr * 0.4), hr * 0.2, 0.6, PI - 0.6, 10, Color("#a8503f"), 3.0, true)
	# the grand moustache: two wings with curled tips
	for s: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, h + Vector2(hr * 0.2 * s, hr * 0.32), Vector2(hr * 0.26, hr * 0.1), hair, 2.5, -0.25 * s)
		ci.draw_arc(h + Vector2(hr * 0.48 * s, hr * 0.2), hr * 0.1, -PI * 0.5 if s > 0 else PI * 1.5, PI * 0.9 if s > 0 else PI * 0.1, 10, INK, 4.5, true)
		ci.draw_arc(h + Vector2(hr * 0.48 * s, hr * 0.2), hr * 0.1, -PI * 0.5 if s > 0 else PI * 1.5, PI * 0.9 if s > 0 else PI * 0.1, 10, hair, 2.5, true)


## (Days 4-5) Rosa Polenta, 28: curly dark hair, a denim jacket and a new sparkly ring.
static func _rosa(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	var hair := Color("#3a2620")
	var skin := Color("#e2a983")
	_shoulders(ci, c, r, Color("#4f74b8"), r * 0.42)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.15, r * 0.5), c + Vector2(r * 0.15, r * 0.5), c + Vector2(0, r * 0.78)]), Color("#fff3dc"))
	var h := c + Vector2(0, -r * 0.06)
	var hr := r * 0.44
	# the curls: a ring of round puffs behind the head
	for k in 11:
		var a := lerpf(-PI * 1.05, PI * 0.05, k / 10.0)
		var p := h + Vector2(cos(a), sin(a)) * hr * 1.0 + Vector2(0, hr * 0.08)
		ci.draw_circle(p, hr * 0.3 + 3.0, INK)
		ci.draw_circle(p, hr * 0.3, hair)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, skin)
	for k in 4:
		var p := h + Vector2((k - 1.5) * hr * 0.42, -hr * 0.82)
		ci.draw_circle(p, hr * 0.24, hair)
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.37 * s, -hr * 0.06)
		_eye(ci, e, hr * 0.19, blink)
		ci.draw_line(e + Vector2(hr * 0.16 * s, -hr * 0.12), e + Vector2(hr * 0.27 * s, -hr * 0.2), INK, 2.5, true)
		_ellipse(ci, h + Vector2(hr * 0.55 * s, hr * 0.32), Vector2(hr * 0.14, hr * 0.08), Color(1, 0.5, 0.5, 0.45))
	_ellipse(ci, h + Vector2(0, hr * 0.14), Vector2(hr * 0.11, hr * 0.09), Color("#d9946e"))
	if talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.5), Vector2(hr * 0.18, hr * 0.15), Color("#7a2a3a"))
	else:
		ci.draw_arc(h + Vector2(0, hr * 0.32), hr * 0.25, 0.5, PI - 0.5, 12, Color("#c4506a"), 4.0, true)
	# the ring, held up: a little hand with a sparkle
	var hand := c + Vector2(r * 0.52, r * 0.56)
	_outlined_ellipse(ci, hand, Vector2(r * 0.11, r * 0.13), skin, 2.0)
	ci.draw_circle(hand + Vector2(-r * 0.02, -r * 0.11), r * 0.045, Color("#f2c94c"))
	UiDraw.star(ci, hand + Vector2(-r * 0.02, -r * 0.18), r * 0.07, Color("#bfe6ff"))


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
