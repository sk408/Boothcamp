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


## The payoff: the skier zips down the hill, the cymbal crashes, the cookie gets chomped, the wave
## rolls over.
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
