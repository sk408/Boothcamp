extends RefCounted
## ArcadeArt (arcade, story-internal): the chute pictures and their gags, drawn in code like every
## other picture in the game (no image files). Each draw takes the canvas, a centre, a size and,
## for the gags, t from 0 to 1.
##   ArcadeArt.picture(ci, &"notch", centre, 60.0)        # the chute's picture
##   ArcadeArt.gag(ci, &"notch", centre, 60.0, t)         # the payoff over the chute

const UiKit := preload("res://story/ui_kit.gd")

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
		&"tymp_a":
			_mountain(ci, c, s, 0.0, 1.0)
		&"tymp_b":
			_pancake(ci, c, s, 0.0)
		&"tymp_as":
			_mountain(ci, c, s, 0.0, 0.4)
		&"tymp_c":
			_mountain(ci, c + Vector2(s * 0.12, 0), s, 0.0, 1.0)
			UiDraw.arrow(ci, c + Vector2(-s * 0.42, -s * 0.38), s * 0.34, Vector2.LEFT, SKIER)
		&"tymp_ad":
			_tower(ci, c, s, 0.0)
		&"deg_mild":
			_clock(ci, c, s, 0.0)
		&"deg_moderate":
			_talk(ci, c, s, 0.0)
		&"deg_modsevere":
			_megaphone(ci, c, s, 0.0)
		&"deg_severe":
			_drum(ci, c, s, 0.0)
		&"deg_profound":
			_jet(ci, c, s, 0.0)
		&"flat_fluid":
			_drop(ci, c, s, 0.0)
		&"flat_wax":
			_plug(ci, c, s, 0.0)
		&"flat_hole":
			_donut(ci, c, s, 0.0)
		&"flat_peak":
			_mountain(ci, c, s, 0.0, 1.0)
		&"oto_clear":
			_pearl(ci, c, s, 0.0)
		&"oto_wax":
			_plug(ci, c, s, 0.0)
		&"oto_fluid":
			_drop(ci, c, s, 0.0)
		&"oto_hole":
			_donut(ci, c, s, 0.0)
		&"oto_object":
			_ladybird(ci, c, s, 0.0)
		&"mask_none":
			_face(ci, c, s, 0.0)
		&"mask_bone":
			_eye_mask(ci, c, s, 0.0, false)
		&"mask_both":
			_eye_mask(ci, c, s, 0.0, true)
		&"noise_under", &"noise_ok", &"noise_over", &"noise_dilemma":
			_bowl(ci, c, s, 0.0, shape)
		&"srt_agree":
			_scales(ci, c, s, 0.0, 0.0)
		&"srt_fair":
			_scales(ci, c, s, 0.0, 0.22)
		&"srt_good":
			_rocket(ci, c, s, 0.0)
		&"srt_poor":
			_anchor(ci, c, s, 0.0)


## The payoff: the skier zips down the hill, the cymbal crashes, the cookie gets chomped, the wave
## rolls over, the rainbow sparkles, the snail shell spins, the cork pops out; for the tympanograms
## the mountain's snow glints (the low hill gets a sheep), the pancake flips, the moved-left
## mountain slides, the skyscraper's windows light up; for the degrees the clock's hand sweeps,
## the speech bubble swells, the megaphone and the drum send out rings, the jet zooms on; for the
## flat tymps the drop splashes, the plug is yanked out on its chain, the doughnut spins and sheds
## sprinkles, and the PEAK mountain glints; for the looks in the ear the pearl gleams and the
## ladybird flies off (the plug, drop and doughnut as above); for the masks the bare face winks,
## the eye mask twirls on its ribbon and the masquerade mask's feathers wave and sparkle; the porridge
## bowls get a spoon (the big one slops over, the split one wobbles); for the SRT checks the scales
## rock and settle, the rocket blasts off and the anchor drops with a splash.
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
		&"tymp_a":
			_mountain(ci, c, s, t, 1.0)
		&"tymp_b":
			_pancake(ci, c, s, t)
		&"tymp_as":
			_mountain(ci, c, s, t, 0.4)
		&"tymp_c":
			_mountain(ci, c + Vector2(s * 0.12 - s * 0.4 * sin(t * PI), 0), s, t, 1.0)
			UiDraw.arrow(ci, c + Vector2(-s * 0.42, -s * 0.38), s * 0.34, Vector2.LEFT, SKIER)
		&"tymp_ad":
			_tower(ci, c, s, t)
		&"deg_mild":
			_clock(ci, c, s, t)
		&"deg_moderate":
			_talk(ci, c, s, t)
		&"deg_modsevere":
			_megaphone(ci, c, s, t)
		&"deg_severe":
			_drum(ci, c, s, t)
		&"deg_profound":
			_jet(ci, c, s, t)
		&"flat_fluid":
			_drop(ci, c, s, t)
		&"flat_wax":
			_plug(ci, c, s, t)
		&"flat_hole":
			_donut(ci, c, s, t)
		&"flat_peak":
			_mountain(ci, c, s, t, 1.0)
		&"oto_clear":
			_pearl(ci, c, s, t)
		&"oto_wax":
			_plug(ci, c, s, t)
		&"oto_fluid":
			_drop(ci, c, s, t)
		&"oto_hole":
			_donut(ci, c, s, t)
		&"oto_object":
			_ladybird(ci, c, s, t)
		&"mask_none":
			_face(ci, c, s, t)
		&"mask_bone":
			_eye_mask(ci, c, s, t, false)
		&"mask_both":
			_eye_mask(ci, c, s, t, true)
		&"noise_under", &"noise_ok", &"noise_over", &"noise_dilemma":
			_bowl(ci, c, s, t, shape)
		&"srt_agree":
			_scales(ci, c, s, t, 0.0)
		&"srt_fair":
			_scales(ci, c, s, t, 0.22)
		&"srt_good":
			_rocket(ci, c, s, t)
		&"srt_poor":
			_anchor(ci, c, s, t)


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


# ---------------------------------------------------------------- tympanograms (TYMP TOSS)

## The tympanogram's axes: pressure (daPa) across, admittance (mL) up.
const TYMP_P_FROM := -400.0
const TYMP_P_TO := 200.0
const TYMP_ML_MAX := 3.0


## Where a pressure / admittance lands in a plot rect.
static func tymp_xy(plot: Rect2, p: float, ml: float) -> Vector2:
	var x := plot.position.x + plot.size.x * (p - TYMP_P_FROM) / (TYMP_P_TO - TYMP_P_FROM)
	var y := plot.end.y - plot.size.y * clampf(ml / TYMP_ML_MAX, 0.0, 1.0)
	return Vector2(x, y)


## One ear's tympanogram in `plot`: white ground, the shaded normal box (CaseRules' own numbers),
## the 0 daPa line and the curve (CaseRules.tymp_admittance) with its peak marked. labels: the axis
## numbers and units too (the big card), else just the picture (chutes, the NEXT card, the hall).
static func tymp_chart(ci: CanvasItem, plot: Rect2, tymp: Dictionary, color: Color, labels: bool, ear := "right") -> void:
	ci.draw_rect(plot, SNOW)
	var grid := Color(INK, 0.08)
	for p in range(-400, 201, 100):
		var x := tymp_xy(plot, p, 0.0).x
		ci.draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(INK, 0.25) if p == 0 else grid, 2.0 if p == 0 else 1.0)
	for i in 7:
		var y := tymp_xy(plot, 0.0, i * 0.5).y
		ci.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), grid, 1.0)
	var lo := tymp_xy(plot, CaseRules.TYMP_NORMAL_PRESSURE.x, CaseRules.TYMP_NORMAL_PEAK.x)
	var hi := tymp_xy(plot, CaseRules.TYMP_NORMAL_PRESSURE.y, CaseRules.TYMP_NORMAL_PEAK.y)
	var box := Rect2(Vector2(lo.x, hi.y), Vector2(hi.x - lo.x, lo.y - hi.y))
	ci.draw_rect(box, Color("#5bc8a3", 0.22))
	ci.draw_rect(box, Color("#3a9d96", 0.8), false, 2.0)
	var pts := PackedVector2Array()
	var p := TYMP_P_FROM
	while p <= TYMP_P_TO:
		pts.append(tymp_xy(plot, p, CaseRules.tymp_admittance(tymp, p)))
		p += 5.0
	ci.draw_polyline(pts, color, 4.0 if labels else 2.5, true)
	if String(tymp.get("type", "")) != "B":
		var peak := tymp_xy(plot, float(tymp.get("peak_daPa", 0)), float(tymp.get("peak_ml", 0.0)))
		if labels:
			UiDraw.ear_symbol(ci, peak, ear, 14.0, 3.0)
		else:
			ci.draw_circle(peak, 3.0, color)
	ci.draw_rect(plot, Color(INK, 0.5), false, 2.0)
	if not labels:
		return
	var f := UiKit.font(600)
	for q: int in [-400, -200, 0, 200]:
		var at := tymp_xy(plot, q, 0.0)
		ci.draw_string(f, Vector2(at.x - 30, plot.end.y + 18), ("+%d" % q) if q > 0 else str(q), HORIZONTAL_ALIGNMENT_CENTER, 60, 13, Color(INK, 0.7))
	ci.draw_string(f, Vector2(plot.end.x - 60, plot.end.y + 34), "daPa", HORIZONTAL_ALIGNMENT_RIGHT, 60, 12, Color(INK, 0.6))
	for i in 4:
		var at := tymp_xy(plot, TYMP_P_FROM, float(i))
		ci.draw_string(f, Vector2(plot.position.x - 30, at.y + 5), str(i), HORIZONTAL_ALIGNMENT_RIGHT, 24, 13, Color(INK, 0.7))
	ci.draw_string(f, Vector2(plot.position.x - 36, plot.position.y + 24), "mL", HORIZONTAL_ALIGNMENT_RIGHT, 30, 12, Color(INK, 0.6))


## A mountain (a tympanogram's peak). height 1 = a full mountain, less = a low hill (type As).
## t > 0: a sparkle on the snow, or a sheep hops over the hill.
static func _mountain(ci: CanvasItem, c: Vector2, s: float, t: float, height: float) -> void:
	var base := c.y + s * 0.42
	var top := Vector2(c.x, base - s * 0.85 * height)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - s * 0.62, base), top, Vector2(c.x + s * 0.62, base)]), Color("#7d8fa6") if height > 0.6 else Color("#7cc47f"))
	if height > 0.6:
		var k := 0.32
		ci.draw_colored_polygon(PackedVector2Array([top, top.lerp(Vector2(c.x + s * 0.62, base), k), top + Vector2(0, s * 0.12), top.lerp(Vector2(c.x - s * 0.62, base), k)]), SNOW)
		if t > 0.0:
			var g := top + Vector2(s * 0.06, s * 0.1)
			var r := s * 0.16 * sin(t * PI)
			ci.draw_line(g - Vector2(r, 0), g + Vector2(r, 0), BRASS, 3.0)
			ci.draw_line(g - Vector2(0, r), g + Vector2(0, r), BRASS, 3.0)
	else:
		var hop := Vector2(lerpf(-s * 0.4, s * 0.4, t), -absf(sin(t * PI)) * s * 0.3) if t > 0.0 else Vector2.ZERO
		var sheep := top + Vector2(0, -s * 0.08) + hop
		ci.draw_circle(sheep, s * 0.12, SNOW)
		ci.draw_circle(sheep + Vector2(s * 0.1, -s * 0.02), s * 0.06, INK)
	ci.draw_polyline(PackedVector2Array([Vector2(c.x - s * 0.62, base), top, Vector2(c.x + s * 0.62, base)]), INK, 3.0, true)


## A pancake (flat: type B), with a pat of butter. t > 0: it flips.
static func _pancake(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var lift := -sin(t * PI) * s * 0.5
	var squash := absf(cos(t * PI)) if t > 0.0 else 1.0
	var at := c + Vector2(0, s * 0.18 + lift)
	ci.draw_set_transform(at, 0.0, Vector2(1.0, 0.32 * maxf(squash, 0.15)))
	ci.draw_circle(Vector2.ZERO, s * 0.6 + 3.0, INK)
	ci.draw_circle(Vector2.ZERO, s * 0.6, Color("#e8b56a"))
	ci.draw_circle(Vector2.ZERO, s * 0.45, Color("#f0c77f"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if squash > 0.5:
		ci.draw_rect(Rect2(at + Vector2(-s * 0.1, -s * 0.12), Vector2(s * 0.2, s * 0.12)), Color("#fff1a8"))
	# the plate
	ci.draw_line(c + Vector2(-s * 0.7, s * 0.36), c + Vector2(s * 0.7, s * 0.36), Color("#c9c4bb"), 4.0)


## A skyscraper (a sky-high peak: type Ad). t > 0: its windows light up floor by floor.
static func _tower(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var r := Rect2(c + Vector2(-s * 0.2, -s * 0.62), Vector2(s * 0.4, s * 1.06))
	ci.draw_rect(r.grow(3.0), INK)
	ci.draw_rect(r, Color("#6c7a96"))
	ci.draw_line(Vector2(c.x, r.position.y), Vector2(c.x, r.position.y - s * 0.16), INK, 3.0)
	for row in 6:
		for col in 2:
			var lit := t > 0.0 and (5 - row) <= int(t * 7.0)
			var w := Rect2(r.position + Vector2(s * 0.06 + col * s * 0.17, s * 0.08 + row * s * 0.16), Vector2(s * 0.1, s * 0.09))
			ci.draw_rect(w, BRASS if lit else Color("#c9d6ea"))


# ---------------------------------------------------------------- degrees (DEGREE DROP)

## Rings of sound from a point, for the gags (t 0..1).
static func _rings(ci: CanvasItem, at: Vector2, s: float, t: float, a0: float, a1: float) -> void:
	if t <= 0.0:
		return
	for i in 3:
		var r := s * (0.2 + 0.25 * i + 0.3 * t)
		ci.draw_arc(at, r, a0, a1, 16, Color(BRASS, (1.0 - t) * (1.0 - i * 0.25)), 3.0, true)


## A ticking clock (a quiet sound: MILD). t > 0: the second hand sweeps round.
static func _clock(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var r := s * 0.45
	ci.draw_circle(c, r + 3.0, INK)
	ci.draw_circle(c, r, SNOW)
	for i in 12:
		var a := i * TAU / 12.0
		ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.8, c + Vector2(cos(a), sin(a)) * r * 0.92, INK, 2.0)
	var hand := -PI * 0.5 + t * TAU
	ci.draw_line(c, c + Vector2(cos(hand), sin(hand)) * r * 0.75, SKIER, 3.0)
	ci.draw_line(c, c + Vector2(0.0, -r * 0.5).rotated(0.9), INK, 4.0)
	ci.draw_circle(c, 3.0, INK)


## A speech bubble (talking: MODERATE). t > 0: it swells.
static func _talk(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var k := 1.0 + 0.25 * sin(t * PI)
	var r := Rect2(c + Vector2(-s * 0.55, -s * 0.38) * k, Vector2(s * 1.1, s * 0.62) * k)
	ci.draw_colored_polygon(PackedVector2Array([r.position + Vector2(s * 0.2, r.size.y - 4), r.position + Vector2(s * 0.45, r.size.y - 4), r.position + Vector2(s * 0.1, r.size.y + s * 0.24)]), INK)
	UiDraw.rounded_rect(ci, r, SNOW, int(s * 0.2), 3, INK)
	for i in 3:
		ci.draw_circle(r.get_center() + Vector2((i - 1) * s * 0.25, 0), s * 0.07, INK)


## A megaphone (a shout: MOD-SEVERE). t > 0: rings of sound.
static func _megaphone(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var cone := PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.12), c + Vector2(s * 0.3, -s * 0.38), c + Vector2(s * 0.3, s * 0.38), c + Vector2(-s * 0.4, s * 0.12)])
	ci.draw_colored_polygon(cone, SKIER)
	var ring := cone.duplicate()
	ring.append(cone[0])
	ci.draw_polyline(ring, INK, 3.0, true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.1), Vector2(s * 0.16, s * 0.2)), Color("#c9c4bb"))
	_rings(ci, c + Vector2(s * 0.3, 0), s, t, -0.7, 0.7)


## A bass drum (loud: SEVERE). t > 0: the stick hits and rings go out.
static func _drum(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var r := s * 0.42
	ci.draw_circle(c, r + 3.0, INK)
	ci.draw_circle(c, r, Color("#c0479c"))
	ci.draw_circle(c, r * 0.72, SNOW)
	var hit := sin(t * PI)
	var tip := c + Vector2(-s * 0.05, -s * 0.15 + hit * s * 0.05)
	ci.draw_line(c + Vector2(s * 0.3, -s * 0.6 + hit * s * 0.2), tip, Color("#b07d12"), 4.0)
	ci.draw_circle(tip, s * 0.07, INK)
	_rings(ci, c, s, t, 0.0, TAU)


## A jet plane (very loud: PROFOUND). t > 0: it zooms on, with speed lines.
static func _jet(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var at := c + Vector2(s * 0.4 * sin(t * PI), 0)
	var wing := Color("#6c7a96")
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.05, 0), at + Vector2(-s * 0.3, -s * 0.42), at + Vector2(-s * 0.15, -s * 0.42), at + Vector2(s * 0.15, 0)]), wing)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.05, 0), at + Vector2(-s * 0.3, s * 0.42), at + Vector2(-s * 0.15, s * 0.42), at + Vector2(s * 0.15, 0)]), wing)
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-s * 0.5, 0), at + Vector2(-s * 0.62, -s * 0.24), at + Vector2(-s * 0.5, -s * 0.24), at + Vector2(-s * 0.4, 0)]), wing)
	var body := PackedVector2Array([at + Vector2(-s * 0.55, -s * 0.07), at + Vector2(s * 0.45, -s * 0.08), at + Vector2(s * 0.62, 0), at + Vector2(s * 0.45, s * 0.08), at + Vector2(-s * 0.55, s * 0.07)])
	ci.draw_colored_polygon(body, Color("#dfe7f2"))
	var ring := body.duplicate()
	ring.append(body[0])
	ci.draw_polyline(ring, INK, 2.5, true)
	if t > 0.0:
		for i in 3:
			var y := (i - 1) * s * 0.12
			ci.draw_line(at + Vector2(-s * 0.7, y), at + Vector2(-s * (0.9 + 0.3 * t), y), Color(SNOW, 1.0 - t), 3.0)


# ---------------------------------------------------------------- canal volume (FLAT OUT)

## The volume gauge's scale (mL) and its parts: TINY, NORMAL, BIG (CaseRules' adult lines).
const GAUGE_MAX_ML := 3.5
const GAUGE_PARTS: Array = [["TINY", 0.0, CaseRules.TYMP_BLOCKED_ECV, Color("#ff8a80")],
	["NORMAL", CaseRules.TYMP_BLOCKED_ECV, CaseRules.TYMP_ADULT_ECV.y, Color("#5bc8a3")], ["BIG", CaseRules.TYMP_ADULT_ECV.y, GAUGE_MAX_ML, Color("#7fb8f0")]]


## A canal volume gauge in `r`: three coloured parts and a pointer on `ecv_ml`. labels: the part
## names over the bar and the reading under the pointer (the big card); else the part the pointer
## is in is lit and the others pale (the chutes).
static func volume_gauge(ci: CanvasItem, r: Rect2, ecv_ml: float, labels: bool) -> void:
	var f := UiKit.font(700)
	if labels:
		UiDraw.rounded_rect(ci, r, Color(SNOW, 0.94), 10, 2, Color(INK, 0.35))
	var bar := Rect2(r.position.x + 12, r.position.y + (20.0 if labels else r.size.y * 0.3), r.size.x - 24, 16.0 if labels else r.size.y * 0.32)
	var x_of := func(ml: float) -> float: return bar.position.x + bar.size.x * clampf(ml / GAUGE_MAX_ML, 0.0, 1.0)
	for part: Array in GAUGE_PARTS:
		var x0: float = x_of.call(float(part[1]))
		var x1: float = x_of.call(float(part[2]))
		var on := labels or (ecv_ml >= float(part[1]) and ecv_ml < float(part[2]))
		ci.draw_rect(Rect2(x0, bar.position.y, x1 - x0, bar.size.y), part[3] if on else Color(part[3], 0.25))
		if labels:
			ci.draw_string(f, Vector2(x0, bar.position.y - 5), String(part[0]), HORIZONTAL_ALIGNMENT_CENTER, x1 - x0, 12, Color(INK, 0.75))
	for edge: float in [CaseRules.TYMP_BLOCKED_ECV, CaseRules.TYMP_ADULT_ECV.y]:
		var xe: float = x_of.call(edge)
		ci.draw_line(Vector2(xe, bar.position.y), Vector2(xe, bar.end.y), INK, 2.0)
	ci.draw_rect(bar, INK, false, 2.0)
	var xp: float = x_of.call(ecv_ml)
	var tip := Vector2(xp, bar.end.y + 1.0)
	var k := 8.0 if labels else maxf(5.0, r.size.y * 0.18)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-k * 0.7, k), tip + Vector2(k * 0.7, k)]), INK)
	if labels:
		var v := "%.1f mL" % ecv_ml
		ci.draw_string(f, Vector2(clampf(xp - 40, r.position.x, r.end.x - 80), r.end.y - 5), v, HORIZONTAL_ALIGNMENT_CENTER, 80, 14, INK)


## A water drop (fluid behind the eardrum). t > 0: it lands with a splash.
static func _drop(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var fall := s * 0.25 * sin(t * PI * 0.5) if t > 0.0 else 0.0
	var at := c + Vector2(0, s * 0.12 + fall)
	var r := s * 0.32
	# a circle and the point above it, tangent to it
	var poly := PackedVector2Array([at + Vector2(0, -r * 2.1)])
	for i in 19:
		var a := -PI * 0.5 + 0.5 + i * (TAU - 1.0) / 18.0
		poly.append(at + Vector2(cos(a), sin(a)) * r)
	var ring := poly.duplicate()
	ring.append(poly[0])
	ci.draw_colored_polygon(poly, WAVE)
	ci.draw_polyline(ring, INK, 3.0, true)
	ci.draw_circle(at + Vector2(-r * 0.4, -r * 0.2), r * 0.2, Color(SNOW, 0.8))
	if t > 0.5:
		var k := (t - 0.5) * 2.0
		for i in 4:
			var a := PI + 0.4 + i * 0.75
			var o := c + Vector2(0, s * 0.45)
			ci.draw_circle(o + Vector2(cos(a), sin(a)) * s * (0.3 + 0.35 * k), s * 0.06 * (1.0 - k), WAVE)


## A bath plug on its chain (a canal blocked by wax). t > 0: the chain yanks it out.
static func _plug(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var lift := Vector2(0, -s * 0.45 * sin(t * PI)) if t > 0.0 else Vector2.ZERO
	# the plughole
	ci.draw_set_transform(c + Vector2(0, s * 0.36), 0.0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, s * 0.6, Color("#c9c4bb"))
	ci.draw_circle(Vector2.ZERO, s * 0.44, INK)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var top := c + Vector2(0, s * 0.02) + lift
	var body := Rect2(top + Vector2(-s * 0.42, 0), Vector2(s * 0.84, s * 0.32))
	UiDraw.rounded_rect(ci, body, Color("#5a4f75"), 8, 3, INK)
	ci.draw_rect(Rect2(body.position + Vector2(s * 0.1, s * 0.07), Vector2(s * 0.3, s * 0.06)), Color(SNOW, 0.35))
	# the ring and the chain up to the corner
	var ring := top + Vector2(0, -s * 0.1)
	ci.draw_arc(ring, s * 0.1, 0.0, TAU, 14, INK, 4.0)
	var hook := c + Vector2(s * 0.6, -s * 0.6)
	var n := 6
	for i in n:
		var p := ring.lerp(hook, (i + 1.0) / (n + 1.0))
		ci.draw_circle(p, s * 0.06 + 1.5, INK)
		ci.draw_circle(p, s * 0.06, BRASS)
	ci.draw_circle(hook, s * 0.08, INK)


## A doughnut (a hole). t > 0: it spins and sheds sprinkles.
static func _donut(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var spin := t * TAU
	ci.draw_circle(c, s * 0.5 + 3.0, INK)
	ci.draw_circle(c, s * 0.5, COOKIE)
	ci.draw_circle(c, s * 0.42, Color("#f4a6c7"))
	var cols := [SKIER, Color("#2d6cdf"), BRASS, Color("#5bc8a3"), SNOW]
	for i in 10:
		var a := spin + i * TAU / 10.0 + 0.3
		var p := c + Vector2(cos(a), sin(a)) * s * (0.3 + 0.06 * (i % 2))
		var d := Vector2(cos(a + 1.2), sin(a + 1.2)) * s * 0.05
		ci.draw_line(p - d, p + d, cols[i % cols.size()], 3.0)
	ci.draw_circle(c, s * 0.18 + 3.0, INK)
	ci.draw_circle(c, s * 0.18, Color("#fff3dc"))
	if t > 0.0:
		for i in 6:
			var a := i * TAU / 6.0 + 0.5
			var o := c + Vector2(cos(a), sin(a)) * s * (0.6 + 0.4 * t) + Vector2(0, s * 0.3 * t * t)
			ci.draw_line(o, o + Vector2(s * 0.06, s * 0.03), Color(cols[i % cols.size()], 1.0 - t), 3.0)


# ---------------------------------------------------------------- the look in the ear (OTO SPOT)

const CANAL := Color("#e6a596")
const CANAL_DEEP := Color("#c27d70")
const DRUM := Color("#c9c6cf")
const DRUM_RIM := Color("#a39eab")
const EAR_WAX := Color("#b5762b")
const EAR_WAX_DARK := Color("#3f2716")
const FLUID_AMBER := Color("#e0a64a")
const DRUM_TILT := -0.25


## One ear down the otoscope in `r`: the dark round of the speculum, the pink canal, the grey drum
## with its malleus handle and cone of light, then the look on top. oto: {"view": &"clear" | &"wax" |
## &"fluid" | &"hole" | &"object", "lookalike": bool, "variant": int}. A left ear is the right one
## mirrored (its cone of light at 7 o'clock). still: no bobbing bubbles (the chutes, the NEXT card).
static func oto_view(ci: CanvasItem, r: Rect2, oto: Dictionary, ear := "right", t := 0.0) -> void:
	var c := r.get_center()
	var R := minf(r.size.x, r.size.y) * 0.5
	var flip := -1.0 if ear == "left" else 1.0
	var view := StringName(oto.get("view", &"clear"))
	var trap := bool(oto.get("lookalike", false))
	var v := int(oto.get("variant", 0))
	ci.draw_circle(c, R, Color("#1d1414"))
	ci.draw_circle(c, R * 0.93, CANAL_DEEP)
	ci.draw_circle(c + Vector2(-R * 0.06 * flip, -R * 0.06), R * 0.8, CANAL)
	# the drum: a tilted oval, a little down and toward the front
	var dc := c + Vector2(-R * 0.05 * flip, R * 0.05)
	var drx := R * 0.55
	var dry := R * 0.48
	var drum := _tilted_oval(dc, drx, dry, DRUM_TILT * flip, 36)
	ci.draw_colored_polygon(drum, DRUM)
	var ring := drum.duplicate()
	ring.append(drum[0])
	ci.draw_polyline(ring, DRUM_RIM, maxf(2.0, R * 0.03), true)
	# the malleus handle, top down to the umbo, and the cone of light from the umbo outward
	var umbo := dc + Vector2(R * 0.04 * flip, R * 0.06)
	var cone := PackedVector2Array([umbo + Vector2(R * 0.03 * flip, R * 0.03), umbo + Vector2(R * 0.3 * flip, R * 0.34), umbo + Vector2(R * 0.13 * flip, R * 0.4)])
	if view == &"clear" or view == &"object":
		ci.draw_colored_polygon(cone, Color(SNOW, 0.9))
	ci.draw_line(dc + Vector2(-R * 0.12 * flip, -R * 0.36), umbo, Color("#f3efe6"), maxf(3.0, R * 0.07), true)
	match view:
		&"clear":
			if trap:
				# dry flakes on the canal wall, nowhere near the drum
				for f: Vector3 in [Vector3(0.7, -0.45, 0.07), Vector3(-0.72, 0.3, 0.06), Vector3(0.35, 0.78, 0.08)]:
					var fc := c + Vector2(f.x * flip, f.y) * R
					ci.draw_colored_polygon(_tilted_oval(fc, R * f.z, R * f.z * 0.6, 0.6 + f.x, 8), Color("#d39a4c"))
		&"wax":
			var col := EAR_WAX_DARK if trap else EAR_WAX
			var plug := PackedVector2Array()
			for i in 40:
				var a := TAU * i / 40.0
				var k := 1.0 + 0.06 * sin(5.0 * a + v) + 0.04 * sin(9.0 * a + 2.0 * v)
				plug.append(dc + Vector2(cos(a), sin(a)) * Vector2(drx, dry) * 1.18 * k)
			ci.draw_colored_polygon(plug, col)
			var edge := plug.duplicate()
			edge.append(plug[0])
			ci.draw_polyline(edge, col.darkened(0.3), maxf(2.0, R * 0.04), true)
			for lump: Vector3 in [Vector3(-0.3, -0.25, 0.2), Vector3(0.25, -0.2, 0.18), Vector3(0.05, 0.25, 0.22)]:
				ci.draw_circle(dc + Vector2(lump.x * flip, lump.y) * R, lump.z * R, col.lightened(0.08))
			ci.draw_arc(dc + Vector2(-R * 0.1 * flip, -R * 0.12), R * 0.3, PI * 1.1, PI * 1.45, 10, Color(Color("#f0c27a") if not trap else Color("#8a6a50"), 0.85), maxf(2.0, R * 0.05))
		&"fluid":
			ci.draw_colored_polygon(drum, Color(FLUID_AMBER, 0.6))
			var line := PackedVector2Array()
			for i in 13:
				var x := -0.9 + i * 0.15
				var p := dc + Vector2(x * drx, -dry * 0.3 + R * 0.04 * (1.0 - x * x))
				line.append(p)
			ci.draw_polyline(line, Color("#c98a2e"), maxf(2.0, R * 0.04), true)
			if not trap:
				for b: Vector3 in [Vector3(-0.35, 0.05, 0.07), Vector3(0.3, 0.2, 0.06), Vector3(-0.1, 0.4, 0.08), Vector3(0.4, -0.05, 0.05)]:
					var bp := dc + Vector2(b.x * flip, b.y) * R + Vector2(0, sin(t * 2.0 + b.x * 9.0) * R * 0.015)
					ci.draw_arc(bp, b.z * R, 0.0, TAU, 14, Color(SNOW, 0.9), maxf(1.5, R * 0.02), true)
		&"hole":
			var hr := R * (0.1 if trap else 0.2)
			var hc := dc + Vector2((0.18 if v % 2 == 0 else -0.2) * flip, 0.2) * R
			var hole := _tilted_oval(hc, hr * 1.2, hr, DRUM_TILT * flip, 20)
			ci.draw_colored_polygon(hole, Color("#4a1a1a"))
			var hring := hole.duplicate()
			hring.append(hole[0])
			ci.draw_polyline(hring, Color("#e7e2ea"), maxf(2.0, R * 0.03), true)
		&"object":
			var oc := c + Vector2(R * 0.32 * flip, R * 0.38)
			var kind := 2 if trap else v % 2
			match kind:
				0:   # a bead
					var bead: Color = [Color("#e5383b"), Color("#2d6cdf"), Color("#5bc8a3")][v % 3]
					ci.draw_circle(oc, R * 0.2 + 2.0, INK)
					ci.draw_circle(oc, R * 0.2, bead)
					ci.draw_circle(oc, R * 0.05, bead.darkened(0.5))
					ci.draw_circle(oc + Vector2(-R * 0.07, -R * 0.07), R * 0.05, Color(SNOW, 0.8))
				1:   # a beetle
					for i in 3:
						for side: float in [-1.0, 1.0]:
							var leg := oc + Vector2(side * R * 0.1, (i - 1) * R * 0.08)
							ci.draw_line(leg, leg + Vector2(side * R * 0.12, (i - 1) * R * 0.05), INK, maxf(1.5, R * 0.025))
					ci.draw_set_transform(oc, 0.0, Vector2(0.8, 1.0))
					ci.draw_circle(Vector2.ZERO, R * 0.17, Color("#2a3b2a"))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
					ci.draw_circle(oc + Vector2(0, -R * 0.17), R * 0.07, INK)
					ci.draw_line(oc + Vector2(0, -R * 0.12), oc + Vector2(0, R * 0.16), Color(SNOW, 0.35), 1.5)
				_:   # a cotton-bud tip, fluffy and white
					for p: Vector3 in [Vector3(0, 0, 0.13), Vector3(-0.09, 0.05, 0.09), Vector3(0.09, 0.04, 0.1), Vector3(0.02, -0.09, 0.09)]:
						ci.draw_circle(oc + Vector2(p.x, p.y) * R, p.z * R, Color("#f4f1ea"))
					ci.draw_arc(oc, R * 0.16, 0.0, TAU, 16, Color(INK, 0.35), 1.5)
	# the speculum's rim shadow over everything
	ci.draw_arc(c, R * 0.93, 0.0, TAU, 48, Color("#1d1414"), maxf(3.0, R * 0.08), true)


static func _tilted_oval(c: Vector2, rx: float, ry: float, tilt: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt))
	return pts


## A pearl (a clear, pearly grey drum). t > 0: it gleams.
static func _pearl(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	ci.draw_set_transform(c + Vector2(0, s * 0.3), 0.0, Vector2(1.0, 0.4))
	ci.draw_circle(Vector2.ZERO, s * 0.55, Color("#e85d75"))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(c, s * 0.36 + 3.0, INK)
	ci.draw_circle(c, s * 0.36, Color("#e9e6ef"))
	ci.draw_circle(c + Vector2(s * 0.06, s * 0.08), s * 0.24, Color("#d4d0dc"))
	ci.draw_circle(c + Vector2(-s * 0.12, -s * 0.12), s * 0.08, SNOW)
	if t > 0.0:
		var g := c + Vector2(-s * 0.12, -s * 0.12)
		var k := s * 0.3 * sin(t * PI)
		ci.draw_line(g - Vector2(k, 0), g + Vector2(k, 0), BRASS, 3.0)
		ci.draw_line(g - Vector2(0, k), g + Vector2(0, k), BRASS, 3.0)


## A ladybird (something that doesn't belong in an ear). t > 0: it opens its wings and flies off.
static func _ladybird(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var at := c + Vector2(s * 0.5, -s * 0.5) * t * t
	var open := 0.5 * sin(t * PI) if t > 0.0 else 0.0
	ci.draw_circle(at + Vector2(0, -s * 0.3), s * 0.16 + 2.0, INK)
	for side: float in [-1.0, 1.0]:
		var wing := PackedVector2Array()
		for i in 13:
			var a := -PI * 0.5 + side * (i / 12.0) * PI
			wing.append(at + Vector2(cos(a), sin(a)).rotated(side * open) * s * 0.36)
		wing.append(at)
		ci.draw_colored_polygon(wing, SKIER)
		var edge := wing.duplicate()
		edge.append(wing[0])
		ci.draw_polyline(edge, INK, 3.0, true)
		for d: Vector2 in [Vector2(0.17, -0.1), Vector2(0.2, 0.14)]:
			ci.draw_circle(at + Vector2(side * d.x, d.y).rotated(side * open) * s, s * 0.06, INK)
	ci.draw_line(at + Vector2(0, -s * 0.36), at + Vector2(0, s * 0.36), INK, 3.0)


# ---------------------------------------------------------------- the masks (MASQUERADE)

const MASK_SKIN := Color("#ffcf9e")
const MASK_RED := Color("#e5383b")   ## the plain eye mask: red, so it shows in the dark chute
const MASK_PURPLE := Color("#7b2cbf")
const FEATHERS: Array[Color] = [Color("#e5383b"), Color("#f2b632"), Color("#5bc8a3")]


## A bare, smiling face (no mask). t > 0: it winks.
static func _face(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	ci.draw_circle(c, s * 0.5 + 3.0, INK)
	ci.draw_circle(c, s * 0.5, MASK_SKIN)
	var wink := t > 0.2 and t < 0.8
	ci.draw_circle(c + Vector2(-s * 0.18, -s * 0.1), s * 0.06, INK)
	if wink:
		ci.draw_line(c + Vector2(s * 0.1, -s * 0.1), c + Vector2(s * 0.26, -s * 0.1), INK, 3.0)
	else:
		ci.draw_circle(c + Vector2(s * 0.18, -s * 0.1), s * 0.06, INK)
	ci.draw_arc(c + Vector2(0, s * 0.04), s * 0.24, 0.35, PI - 0.35, 14, INK, 3.0)
	ci.draw_circle(c + Vector2(-s * 0.3, s * 0.1), s * 0.07, Color("#f4a6c7", 0.8))
	ci.draw_circle(c + Vector2(s * 0.3, s * 0.1), s * 0.07, Color("#f4a6c7", 0.8))


## An eye mask on a ribbon (mask bone); fancy adds the masquerade mask's purple, gold trim, a stick
## and three feathers (mask both). t > 0: the eye mask twirls; the feathers wave and sparkle.
static func _eye_mask(ci: CanvasItem, c: Vector2, s: float, t: float, fancy: bool) -> void:
	var tilt := 0.0
	if t > 0.0 and not fancy:
		tilt = sin(t * TAU) * 0.35
	if fancy:
		# the stick, down and to the right
		ci.draw_line(c + Vector2(s * 0.3, s * 0.08), c + Vector2(s * 0.55, s * 0.6), INK, 6.0)
		ci.draw_line(c + Vector2(s * 0.3, s * 0.08), c + Vector2(s * 0.55, s * 0.6), BRASS, 3.0)
		for i in FEATHERS.size():
			var sway := sin(t * TAU * 2.0 + i) * 0.18 if t > 0.0 else 0.0
			var a := -PI * 0.5 + (i - 1) * 0.42 + sway
			var root := c + Vector2(-s * 0.3 + i * s * 0.08, -s * 0.18)
			var tip := root + Vector2(cos(a), sin(a)) * s * 0.55
			var side := Vector2(-(tip - root).y, (tip - root).x).normalized() * s * 0.08
			var mid := (root + tip) * 0.5
			ci.draw_colored_polygon(PackedVector2Array([root, mid + side, tip, mid - side]), FEATHERS[i])
			ci.draw_polyline(PackedVector2Array([root, mid + side, tip, mid - side, root]), INK, 2.0, true)
	ci.draw_set_transform(c, tilt, Vector2.ONE)
	if not fancy:
		# the ribbon tails behind
		ci.draw_line(Vector2(-s * 0.48, 0), Vector2(-s * 0.68, s * 0.22), MASK_RED, 4.0)
		ci.draw_line(Vector2(s * 0.48, 0), Vector2(s * 0.68, s * 0.22), MASK_RED, 4.0)
	var body := PackedVector2Array()
	for i in 25:
		var a := i * TAU / 24.0
		# a wide lens shape with a dip over the nose
		var r := Vector2(cos(a) * s * 0.52, sin(a) * s * 0.24)
		if sin(a) > 0.0 and absf(cos(a)) < 0.3:
			r.y -= sin(a) * s * 0.14
		body.append(r)
	var ring := body.duplicate()
	ring.append(body[0])
	ci.draw_colored_polygon(body, MASK_PURPLE if fancy else MASK_RED)
	ci.draw_polyline(ring, BRASS if fancy else INK, 3.0, true)
	for side in [-1.0, 1.0]:
		ci.draw_set_transform(c + Vector2(side * s * 0.22, -s * 0.02).rotated(tilt), tilt, Vector2(1.0, 0.6))
		ci.draw_circle(Vector2.ZERO, s * 0.12, SNOW)
		ci.draw_arc(Vector2.ZERO, s * 0.12, 0.0, TAU, 14, BRASS if fancy else INK, 2.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if fancy and t > 0.0:
		for i in 5:
			var a := i * TAU / 5.0 + t * 3.0
			var p := c + Vector2(cos(a), sin(a)) * s * (0.55 + 0.2 * t)
			ci.draw_circle(p, s * 0.05 * (1.0 - t), BRASS)


# ---------------------------------------------------------------- the noise dial (GOLDILOCKS)

const PORRIDGE := Color("#f3e3c3")
const BOWL := Color("#e5383b")
const DIAL_MAX_DB := 100.0
const WINDOW_OK := Color("#5bc8a3")


## A porridge bowl per noise chute: small and nearly empty (too little), middle and steaming (just
## right), big and spilling over (too much), cracked in two (dilemma). t > 0: a spoon dips in.
static func _bowl(ci: CanvasItem, c: Vector2, s: float, t: float, shape: StringName) -> void:
	var k := {&"noise_under": 0.62, &"noise_ok": 0.82, &"noise_over": 1.0, &"noise_dilemma": 0.82}[shape] as float
	var w := s * 0.62 * k
	var top := c.y + s * 0.02
	var split := shape == &"noise_dilemma"
	var gap := s * 0.08 * (1.0 + 0.6 * sin(t * TAU * 3.0)) if split else 0.0
	for side in ([-1.0, 1.0] if split else [0.0]):
		var off := Vector2(side * gap, 0)
		var body := PackedVector2Array()
		for i in 17:
			var a := PI * i / 16.0
			if split and ((side < 0.0 and a < PI * 0.5) or (side > 0.0 and a > PI * 0.5)):
				continue
			body.append(Vector2(c.x + cos(a) * w, top + sin(a) * w * 0.8) + off)
		if split:
			body.append(Vector2(c.x, top) + off)
		ci.draw_colored_polygon(body, BOWL)
		var ring := body.duplicate()
		ring.append(body[0])
		ci.draw_polyline(ring, INK, 3.0, true)
		ci.draw_line(Vector2(c.x - (w if side <= 0.0 else 0.0), top) + off, Vector2(c.x + (w if side >= 0.0 else 0.0), top) + off, INK, 3.0)
	# the porridge: a thin skim, a heap, or a heap spilling down the side
	if shape == &"noise_under":
		ci.draw_circle(Vector2(c.x, top - 2), s * 0.04, PORRIDGE)
	elif not split:
		ci.draw_set_transform(Vector2(c.x, top), 0.0, Vector2(1.0, 0.45))
		ci.draw_circle(Vector2.ZERO, w * 0.9, PORRIDGE)
		ci.draw_arc(Vector2.ZERO, w * 0.9, PI, TAU, 16, INK, 2.5)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if shape == &"noise_over":
			ci.draw_circle(Vector2(c.x + w * 0.95, top + w * 0.25), s * 0.08, PORRIDGE)
			ci.draw_circle(Vector2(c.x + w * 0.9, top + w * 0.55 + s * 0.1 * t), s * 0.06, PORRIDGE)
		else:
			for i in 3:
				var x := c.x + (i - 1) * s * 0.16
				var wob := sin(i * 2.0 + t * TAU) * s * 0.03
				ci.draw_polyline(PackedVector2Array([Vector2(x, top - s * 0.14), Vector2(x + wob + s * 0.04, top - s * 0.24), Vector2(x - wob, top - s * 0.34)]), Color(SNOW, 0.85), 2.5, true)
	if t > 0.0:
		var dip := s * 0.12 * sin(t * PI)
		var tip := Vector2(c.x + w * 0.3, top - s * 0.05 + dip)
		ci.draw_line(tip, tip + Vector2(s * 0.3, -s * 0.42), PIPE, 5.0)
		ci.draw_circle(tip, s * 0.07, PIPE)


## Where a noise card's dial sits inside panel r, and the x of a level on it.
static func dial_rect(r: Rect2) -> Rect2:
	return Rect2(r.position.x + 24, r.position.y + 150, r.size.x - 48, 34)


static func dial_x(dial: Rect2, db: float) -> float:
	return dial.position.x + dial.size.x * clampf(db / DIAL_MAX_DB, 0.0, 1.0)


## A GOLDILOCKS card's face in r: two number tiles (the other ear's air in its colour, the bone tone in
## the test ear's) and the noise dial, 0 to 100 dB, with its needle on the noise.
## n: {"freq", "other_air", "tone", "mask", "other_ear"}; ear: the test ear.
static func noise_panel(ci: CanvasItem, r: Rect2, n: Dictionary, ear: String) -> void:
	var f := UiKit.font(700)
	var other := String(n.get("other_ear", "left"))
	var hz := "%dk" % (int(n.get("freq", 2000)) / 1000)
	var tw := (r.size.x - 60) * 0.5
	var tiles := [[Rect2(r.position.x + 20, r.position.y, tw, 104), "OTHER EAR'S AIR", int(n.get("other_air", 0)), other],
		[Rect2(r.position.x + 40 + tw, r.position.y, tw, 104), "BONE TONE, %s" % hz, int(n.get("tone", 0)), ear]]
	for tile: Array in tiles:
		var tr: Rect2 = tile[0]
		var col := Palette.ear_color(String(tile[3]))
		UiDraw.rounded_rect(ci, tr, Color(col, 0.12), 14, 3, col)
		ci.draw_string(f, tr.position + Vector2(0, 28), String(tile[1]), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 17, col)
		ci.draw_string(f, tr.position + Vector2(0, 86), "%d dB" % int(tile[2]), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 46, INK)
	var dial := dial_rect(r)
	ci.draw_string(f, Vector2(dial.position.x, dial.position.y - 12), "NOISE IN THE OTHER EAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(INK, 0.7))
	UiDraw.rounded_rect(ci, dial, Color(SNOW, 0.95), 10, 2, Color(INK, 0.45))
	var uf := UiKit.font(600)
	for db in range(0, 101, 10):
		var x := dial_x(dial, db)
		ci.draw_line(Vector2(x, dial.end.y - (12 if db % 20 == 0 else 7)), Vector2(x, dial.end.y), Color(INK, 0.5), 2.0)
		if db % 20 == 0:
			ci.draw_string(uf, Vector2(x - 20, dial.end.y + 18), str(db), HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color(INK, 0.7))
	var m := float(n.get("mask", 0))
	var nx := dial_x(dial, m)
	ci.draw_rect(Rect2(dial.position.x + 4, dial.position.y + 8, nx - dial.position.x - 4, 10), Color(Palette.ear_color(other), 0.55))
	var tip := Vector2(nx, dial.position.y + 4)
	ci.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9, -14), tip + Vector2(9, -14)]), INK)
	var lab := "%d dB" % int(m)
	var lw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 16
	var lx := clampf(nx - lw * 0.5, dial.position.x, dial.end.x - lw)
	UiDraw.rounded_rect(ci, Rect2(lx, tip.y - 42, lw, 26), INK, 9)
	ci.draw_string(f, Vector2(lx, tip.y - 22), lab, HORIZONTAL_ALIGNMENT_CENTER, lw, 18, SNOW)


# ---------------------------------------------------------------- the cross-check (CROSS CHECK)

const ROCKET := Color("#f4f1ea")
const FLAME := Color("#ff9f1c")
const ANCHOR := Color("#5a6b80")


## A balance: level for AGREES, tipped by `tilt` (radians) for FAIR. t > 0: it rocks and settles.
static func _scales(ci: CanvasItem, c: Vector2, s: float, t: float, tilt: float) -> void:
	var rock := tilt + (sin(t * TAU * 2.0) * 0.25 * (1.0 - t) if t > 0.0 else 0.0)
	var pivot := c + Vector2(0, -s * 0.25)
	ci.draw_line(pivot, c + Vector2(0, s * 0.45), INK, 5.0)
	ci.draw_line(c + Vector2(-s * 0.25, s * 0.45), c + Vector2(s * 0.25, s * 0.45), INK, 5.0)
	var arm := Vector2(cos(rock), sin(rock)) * s * 0.55
	ci.draw_line(pivot - arm, pivot + arm, BRASS, 5.0)
	for end: Vector2 in [pivot - arm, pivot + arm]:
		ci.draw_line(end, end + Vector2(-s * 0.16, s * 0.3), Color(INK, 0.7), 2.0)
		ci.draw_line(end, end + Vector2(s * 0.16, s * 0.3), Color(INK, 0.7), 2.0)
		ci.draw_set_transform(end + Vector2(0, s * 0.3), 0.0, Vector2(1.0, 0.35))
		ci.draw_circle(Vector2.ZERO, s * 0.2, BRASS)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(pivot, s * 0.06, INK)


## A little rocket, nose up (words better than tones). t > 0: it blasts off.
static func _rocket(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var at := c + Vector2(0, -s * 0.5 * t * t)
	if t > 0.0:
		for i in 3:
			ci.draw_circle(at + Vector2((i - 1) * s * 0.08, s * (0.5 + 0.12 * i)), s * (0.1 - 0.02 * i), Color(FLAME, 1.0 - 0.25 * i))
	var body := PackedVector2Array([at + Vector2(0, -s * 0.5), at + Vector2(s * 0.18, -s * 0.2), at + Vector2(s * 0.18, s * 0.32),
		at + Vector2(-s * 0.18, s * 0.32), at + Vector2(-s * 0.18, -s * 0.2)])
	for side in [-1.0, 1.0]:
		var fin := PackedVector2Array([at + Vector2(side * s * 0.18, s * 0.08), at + Vector2(side * s * 0.36, s * 0.4), at + Vector2(side * s * 0.18, s * 0.32)])
		ci.draw_colored_polygon(fin, SKIER)
		ci.draw_polyline(PackedVector2Array([fin[0], fin[1], fin[2]]), INK, 2.5, true)
	ci.draw_colored_polygon(body, ROCKET)
	var ring := body.duplicate()
	ring.append(body[0])
	ci.draw_polyline(ring, INK, 3.0, true)
	ci.draw_circle(at + Vector2(0, -s * 0.06), s * 0.09, WAVE)
	ci.draw_arc(at + Vector2(0, -s * 0.06), s * 0.09, 0.0, TAU, 14, INK, 2.0)


## An anchor (words worse than tones). t > 0: it drops, with a splash.
static func _anchor(ci: CanvasItem, c: Vector2, s: float, t: float) -> void:
	var at := c + Vector2(0, s * 0.2 * sin(t * PI * 0.5) if t > 0.0 else 0.0)
	ci.draw_arc(at + Vector2(0, -s * 0.42), s * 0.1, 0.0, TAU, 14, ANCHOR, 5.0)
	ci.draw_line(at + Vector2(0, -s * 0.32), at + Vector2(0, s * 0.38), ANCHOR, 6.0)
	ci.draw_line(at + Vector2(-s * 0.2, -s * 0.18), at + Vector2(s * 0.2, -s * 0.18), ANCHOR, 6.0)
	ci.draw_arc(at + Vector2(0, s * 0.05), s * 0.36, 0.35, PI - 0.35, 16, ANCHOR, 6.0)
	for side in [-1.0, 1.0]:
		var tip := at + Vector2(side * s * 0.34, s * 0.17)
		ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(side * s * 0.08, -s * 0.06), tip + Vector2(-side * s * 0.05, -s * 0.1), tip + Vector2(0, s * 0.06)]), ANCHOR)
	if t > 0.5:
		var k := (t - 0.5) * 2.0
		for i in 4:
			var a := PI + 0.4 + i * 0.75
			ci.draw_circle(c + Vector2(0, s * 0.55) + Vector2(cos(a), sin(a)) * s * (0.3 + 0.3 * k), s * 0.05 * (1.0 - k), WAVE)
