extends RefCounted
## ArcadeArt (arcade, story-internal): the chute pictures and their gags, drawn in code like every
## other picture in the game (no image files). Each draw takes the canvas, a centre, a size and,
## for the gags, t from 0 to 1.
##   ArcadeArt.picture(ci, &"notch", centre, 60.0)        # the chute's picture
##   ArcadeArt.gag(ci, &"notch", centre, 60.0, t)         # the payoff over the chute

const INK := Color("#2e2442")
const SNOW := Color("#ffffff")
const BRASS := Color("#f2b632")
const COOKIE := Color("#d99a5b")
const CHIP := Color("#6b3f22")
const WAVE := Color("#36a3e7")
const SKIER := Color("#e5383b")
const SHELL := Color("#f4c7d8")
const CORK := Color("#c98d4f")
const PIPE := Color("#c9c4bb")
## The rainbow's bands, outside in.
const RAINBOW: Array[Color] = [Color("#e5383b"), Color("#ff9f1c"), Color("#f2d335"), Color("#5bc8a3"), Color("#36a3e7")]


static func picture(ci: CanvasItem, shape: StringName, c: Vector2, s: float) -> void:
	match shape:
		&"sloping":
			_slope(ci, c, s)
			_skier(ci, c + Vector2(-s * 0.2, -s * 0.12), s * 0.42, -0.45)
		&"notch":
			_cymbal(ci, c, s, 0.0)
		&"cookie_bite":
			_cookie(ci, c, s, 1.0)
		&"rising":
			_wave(ci, c, s, 0.0)
		&"reverse_bite":
			_rainbow(ci, c, s, 0.0)
		&"sensorineural":
			_snail(ci, c, s, 0.0)
		&"conductive":
			_cork(ci, c, s, 0.0)
		&"mixed":
			_cork(ci, c + Vector2(-s * 0.42, s * 0.05), s * 0.62, 0.0)
			_snail(ci, c + Vector2(s * 0.4, 0), s * 0.62, 0.0)


## The payoff: the skier zips down the hill, the cymbal crashes, the cookie gets chomped, the wave
## rolls over, the rainbow sparkles, the snail shell spins, the cork pops out.
static func gag(ci: CanvasItem, shape: StringName, c: Vector2, s: float, t: float) -> void:
	t = clampf(t, 0.0, 1.0)
	match shape:
		&"sloping":
			_slope(ci, c, s)
			var along := Vector2(-s * 0.45, -s * 0.3).lerp(Vector2(s * 0.45, s * 0.3), t)
			_skier(ci, c + along + Vector2(0, -s * 0.12), s * 0.42, -0.45 + sin(t * TAU * 2.0) * 0.1)
			for i in 6:
				var p := c + along + Vector2(-s * 0.18 - i * s * 0.06, -s * 0.05 + sin(i * 1.7) * s * 0.05)
				ci.draw_circle(p, s * 0.04 * (1.0 - i / 7.0), Color(SNOW, 0.9 * (1.0 - t * 0.5)))
		&"notch":
			_cymbal(ci, c, s, t)
			for i in 10:
				var a := i * TAU / 10.0 + 0.2
				var r0 := s * (0.55 + 0.1 * t)
				var r1 := s * (0.75 + 0.35 * t)
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r0, c + Vector2(cos(a), sin(a)) * r1, Color(BRASS, 1.0 - t), 4.0)
		&"cookie_bite":
			_cookie(ci, c, s, 1.0 + t * 1.6)
		&"rising":
			_wave(ci, c, s, t)
		&"reverse_bite":
			_rainbow(ci, c, s, t)
		&"sensorineural":
			_snail(ci, c, s, t)
		&"conductive":
			_cork(ci, c, s, t)
		&"mixed":
			_cork(ci, c + Vector2(-s * 0.42, s * 0.05), s * 0.62, t)
			_snail(ci, c + Vector2(s * 0.4, 0), s * 0.62, t)


static func _slope(ci: CanvasItem, c: Vector2, s: float) -> void:
	var hill := PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.42), c + Vector2(s * 0.6, s * 0.36), c + Vector2(s * 0.6, s * 0.5), c + Vector2(-s * 0.6, s * 0.5)])
	ci.draw_colored_polygon(hill, Color("#dff1ff"))
	ci.draw_polyline(PackedVector2Array([hill[0], hill[1]]), INK, 4.0, true)


static func _skier(ci: CanvasItem, at: Vector2, s: float, lean: float) -> void:
	var up := Vector2(sin(lean), -cos(lean))
	ci.draw_line(at + Vector2(-s * 0.5, s * 0.32).rotated(lean), at + Vector2(s * 0.55, s * 0.32).rotated(lean), INK, 4.0)
	ci.draw_line(at + up * s * 0.05 + Vector2(0, s * 0.25), at + up * s * 0.5, SKIER, s * 0.22)
	ci.draw_circle(at + up * s * 0.68, s * 0.16, Color("#ffcf9e"))
	ci.draw_circle(at + up * s * 0.78, s * 0.12, SKIER)


## A crash cymbal on its stand (loud noise is what leaves a notch). The stand is light so it shows
## on the dark chute.
static func _cymbal(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var wob := sin(t * TAU * 3.0) * 0.18 * (1.0 - t)
	var stand := Color("#c9c4bb")
	var foot := c + Vector2(0, s * 0.62)
	ci.draw_line(c + Vector2(0, -s * 0.05), foot, stand, 4.0)
	ci.draw_line(foot, foot + Vector2(-s * 0.3, s * 0.12), stand, 4.0)
	ci.draw_line(foot, foot + Vector2(s * 0.3, s * 0.12), stand, 4.0)
	ci.draw_set_transform(c, -0.18 + wob, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, s * 0.55, BRASS)
	ci.draw_arc(Vector2.ZERO, s * 0.55, 0.0, TAU, 40, Color("#b07d12"), 4.0)
	ci.draw_arc(Vector2.ZERO, s * 0.3, 0.0, TAU, 32, Color("#b07d12", 0.6), 2.5)
	ci.draw_circle(Vector2.ZERO, s * 0.1, stand)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## bite: 1 = one bite out of the top, more = chomped further
static func _cookie(ci: CanvasItem, c: Vector2, s: float, bite: float) -> void:
	var r := s * 0.5
	ci.draw_circle(c, r + 3.0, INK)
	ci.draw_circle(c, r, COOKIE)
	for p: Vector2 in [Vector2(-0.25, 0.1), Vector2(0.2, 0.25), Vector2(0.05, -0.15), Vector2(-0.1, 0.35), Vector2(0.3, -0.05)]:
		ci.draw_circle(c + p * s, s * 0.06, CHIP)
	# the bite: scallops out of the top edge, cut with the background colour of a chute
	var n := int(clampf(bite * 2.0, 2.0, 5.0))
	for i in n:
		var a := -PI * 0.5 + (i - (n - 1) * 0.5) * 0.42
		ci.draw_circle(c + Vector2(cos(a), sin(a)) * r * 1.02, r * 0.3, Color("#2b2440"))


static func _wave(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var pts := PackedVector2Array()
	var shift := t * s * 0.6
	for i in 25:
		var x := -s * 0.6 + i * s * 1.2 / 24.0
		var y := sin((x + shift) / (s * 0.22)) * s * 0.12 - s * 0.05
		pts.append(c + Vector2(x, y))
	var fill := pts.duplicate()
	fill.append(c + Vector2(s * 0.6, s * 0.5))
	fill.append(c + Vector2(-s * 0.6, s * 0.5))
	ci.draw_colored_polygon(fill, Color(WAVE, 0.85))
	ci.draw_polyline(pts, SNOW, 4.0, true)


## A rainbow: high in the middle, down at both ends, like a reverse bite on the chart (better in
## the middle). t > 0: it brightens and sparkles from end to end.
static func _rainbow(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var base := c + Vector2(0, s * 0.32)
	var band := s * 0.09
	for i in RAINBOW.size():
		var r := s * 0.62 - i * band
		ci.draw_arc(base, r, PI, TAU, 32, RAINBOW[i], band + 1.0, true)
	# a cloud at each foot
	for side: float in [-1.0, 1.0]:
		var foot := base + Vector2(side * s * 0.5, s * 0.02)
		for p: Vector2 in [Vector2(-0.14, 0.02), Vector2(0.0, -0.05), Vector2(0.14, 0.02)]:
			ci.draw_circle(foot + p * s, s * 0.12, SNOW)
	if t > 0.0:
		for i in 5:
			var a := PI + PI * clampf(t * 1.2 - i * 0.05, 0.0, 1.0) * (i + 1) / 5.0
			var p := base + Vector2(cos(a), sin(a)) * s * 0.52
			var k := s * 0.07 * (1.0 - t * 0.6)
			ci.draw_line(p - Vector2(k, 0), p + Vector2(k, 0), Color(SNOW, 1.0 - t * 0.5), 3.0)
			ci.draw_line(p - Vector2(0, k), p + Vector2(0, k), Color(SNOW, 1.0 - t * 0.5), 3.0)


## A snail shell: the cochlea, the inner ear. t > 0: it spins a turn and sends out ripples.
static func _snail(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var r := s * 0.5
	ci.draw_circle(c, r + 3.0, INK)
	ci.draw_circle(c, r, SHELL)
	var spin := -TAU * t
	var pts := PackedVector2Array()
	for i in 49:
		var a := spin + i * TAU * 2.5 / 48.0
		var k := r * (0.9 - 0.82 * i / 48.0)
		pts.append(c + Vector2(cos(a), sin(a)) * k)
	ci.draw_polyline(pts, INK, 3.0, true)
	if t > 0.0:
		for i in 2:
			var rr := r * (1.15 + 0.5 * t + i * 0.25)
			ci.draw_arc(c, rr, -0.6, 0.6, 12, Color(SNOW, (1.0 - t) * 0.9), 3.0, true)
			ci.draw_arc(c, rr, PI - 0.6, PI + 0.6, 12, Color(SNOW, (1.0 - t) * 0.9), 3.0, true)


## A cork stuck in a tube: something blocking the way to the inner ear (the middle ear). t > 0:
## the cork pops out and spins away.
static func _cork(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var tube := Rect2(c + Vector2(-s * 0.6, -s * 0.2), Vector2(s * 1.2, s * 0.4))
	ci.draw_rect(tube.grow(3.0), INK)
	ci.draw_rect(tube, PIPE)
	ci.draw_rect(Rect2(tube.position + Vector2(0, s * 0.06), Vector2(tube.size.x, s * 0.08)), Color(SNOW, 0.5))
	var at := c + Vector2(-s * 0.15, 0) + Vector2(-s * 0.9, -s * 0.5) * t
	var turn := -TAU * 0.75 * t
	var w := s * 0.3
	var h := s * 0.46
	var poly := PackedVector2Array()
	for v: Vector2 in [Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.42), Vector2(w * 0.5, h * 0.42), Vector2(-w * 0.5, h * 0.5)]:
		poly.append(at + v.rotated(turn))
	var ring := poly.duplicate()
	ring.append(poly[0])
	ci.draw_polyline(ring, INK, 6.0, true)
	ci.draw_colored_polygon(poly, CORK)
	for d: Vector2 in [Vector2(-0.05, -0.12), Vector2(0.06, 0.05), Vector2(-0.04, 0.14)]:
		ci.draw_circle(at + (d * s).rotated(turn), s * 0.03, CHIP)
	if t > 0.0 and t < 0.6:
		var k := t / 0.6
		for i in 5:
			var a := PI + (i - 2) * 0.35
			var o := c + Vector2(-s * 0.55, 0)
			ci.draw_line(o + Vector2(cos(a), sin(a)) * s * (0.1 + 0.2 * k), o + Vector2(cos(a), sin(a)) * s * (0.25 + 0.3 * k), Color(BRASS, 1.0 - k), 3.0)
