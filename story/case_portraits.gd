extends RefCounted
## CasePortraits (cases, story-internal): dialogue portraits for the case-file patients, drawn from
## the "look" in their case file (story/cases/<id>.json), so a new case needs no portrait code.
## Portraits.draw() falls back to this for any speaker a case file names:
##   if CasePortraits.has("Rocco"): CasePortraits.draw(ci, "Rocco", center, radius, talk_open, blink)
## Look keys used: skin, nose, cardigan, shirt, accent, hair, hair_style (tufts / bun / beehive / none),
## mustache, brows, glasses (round / cateye / perched / none), glasses_color, face (doris and bonnie
## faces get lashes and a pearl necklace), extras (headband, cap, captain_cap, drumsticks, pizza_box,
## spiky_hair, band_tee, puppet, beekeeper_hat, bee, pillbox_hat, neck_scarf), portrait_bg, name_color,
## and a colour per extra (e.g. "headband", "beekeeper_hat", "pillbox_hat", "neck_scarf").
## A case's extra speakers ("voices", e.g. Chip) can ask for "portrait": "cookie" instead.

const CaseData := preload("res://story/case_data.gd")

const INK := Color("#2e2442")
const WHITE := Color("#fffdf8")

static var _looks: Dictionary = {}   # speaker -> look ({} when no case names them)


static func look(who: String) -> Dictionary:
	if not _looks.has(who):
		_looks[who] = CaseData.look_for_speaker(who)
	return _looks[who]


static func has(who: String) -> bool:
	return who != "" and not look(who).is_empty()


static func bg(who: String) -> Color:
	return _col(look(who), "portrait_bg", Color("#fff3dc"))


static func name_color(who: String) -> Color:
	return _col(look(who), "name_color", Color("#6b5e7e"))


static func draw(ci: CanvasItem, who: String, c: Vector2, r: float, talk_open: bool, blink: bool) -> void:
	var lk := look(who)
	if String(lk.get("portrait", "")) == "cookie":
		_draw_cookie_puppet(ci, c, r, talk_open, blink, bg(who))
		return
	var extras: Array = lk.get("extras", [])
	var skin := _col(lk, "skin", Color("#ffcf9e"))
	var hair := _col(lk, "hair", Color("#5a3d2b"))
	var style := String(lk.get("hair_style", "tufts"))
	var lady := String(lk.get("face", "gus")) != "gus"
	_shoulders(ci, c, r, _col(lk, "cardigan", Color("#3a9d96")), r * 0.42)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.16, r * 0.5), c + Vector2(r * 0.16, r * 0.5), c + Vector2(0, r * 0.82)]), _col(lk, "shirt", WHITE))
	if extras.has("band_tee"):
		# a sleeveless band tee: bare shoulders, a lightning bolt on the chest
		for sd: float in [-1.0, 1.0]:
			_ellipse(ci, c + Vector2(r * 0.62 * sd, r * 0.62), Vector2(r * 0.2, r * 0.16), skin)
		var bolt := PackedVector2Array([c + Vector2(-r * 0.05, r * 0.6), c + Vector2(r * 0.1, r * 0.6), c + Vector2(r * 0.02, r * 0.7),
			c + Vector2(r * 0.12, r * 0.7), c + Vector2(-r * 0.08, r * 0.88), c + Vector2(-r * 0.01, r * 0.75), c + Vector2(-r * 0.1, r * 0.75)])
		ci.draw_colored_polygon(bolt, _col(lk, "accent", Color("#e5383b")))
	elif extras.has("neck_scarf"):
		_draw_neck_scarf(ci, c, r, _col(lk, "neck_scarf", Color("#ff7a59")))
	elif lady:
		for i in 7:
			var a := lerpf(-1.0, 1.0, i / 6.0)
			ci.draw_circle(c + Vector2(sin(a) * r * 0.3, r * 0.52 + cos(a) * r * 0.06), r * 0.045, WHITE)
	else:
		var acc := _col(lk, "accent", Color("#ff6f59"))
		_ellipse(ci, c + Vector2(-r * 0.1, r * 0.52), Vector2(r * 0.11, r * 0.07), acc)
		_ellipse(ci, c + Vector2(r * 0.1, r * 0.52), Vector2(r * 0.11, r * 0.07), acc)
	if extras.has("pizza_box"):
		var box := Rect2(c + Vector2(r * 0.18, r * 0.42), Vector2(r * 0.62, r * 0.2))
		UiDraw.rounded_rect(ci, box.grow(2.5), INK, 4)
		UiDraw.rounded_rect(ci, box, Color("#f2d4a2"), 3)
		ci.draw_circle(box.get_center(), r * 0.06, Color("#e5383b"))
	var h := c + Vector2(0, -r * 0.04)
	var hr := r * 0.46
	if extras.has("spiky_hair"):
		for i in 7:
			var a := lerpf(-1.15, 1.15, i / 6.0)
			var base := h + Vector2(sin(a), -cos(a)) * hr * 0.8
			var tip := h + Vector2(sin(a), -cos(a)) * hr * (1.5 + 0.12 * (i % 2))
			var side := Vector2(cos(a), sin(a)) * hr * 0.2
			var spike := PackedVector2Array([base - side, tip, base + side])
			ci.draw_colored_polygon(spike, hair)
			ci.draw_polyline(spike, INK, 3.0, true)
	# hair behind the head
	match style:
		"bun":
			ci.draw_circle(h + Vector2(0, -hr * 1.3), hr * 0.5 + 3.0, INK)
			ci.draw_circle(h + Vector2(0, -hr * 1.3), hr * 0.5, hair)
		"beehive":
			for p: Array in [[Vector2(0, -hr * 1.3), hr * 0.66], [Vector2(0, -hr * 1.95), hr * 0.44], [Vector2(-hr * 0.85, -hr * 0.3), hr * 0.38], [Vector2(hr * 0.85, -hr * 0.3), hr * 0.38]]:
				ci.draw_circle(h + p[0], float(p[1]) + 3.0, INK)
			for p: Array in [[Vector2(0, -hr * 1.3), hr * 0.66], [Vector2(0, -hr * 1.95), hr * 0.44], [Vector2(-hr * 0.85, -hr * 0.3), hr * 0.38], [Vector2(hr * 0.85, -hr * 0.3), hr * 0.38]]:
				ci.draw_circle(h + p[0], float(p[1]), hair)
			ci.draw_circle(h + Vector2(hr * 0.55, -hr * 1.35), hr * 0.14, Color("#ff6f59"))
	# ears, head
	for s: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, h + Vector2(hr * 0.98 * s, hr * 0.1), Vector2(hr * 0.17, hr * 0.24), skin, 2.5)
	ci.draw_circle(h, hr + 3.0, INK)
	ci.draw_circle(h, hr, skin)
	# hair on the head
	match style:
		"tufts":
			for s: float in [-1.0, 1.0]:
				for k in 3:
					var p := h + Vector2(hr * (0.84 + 0.08 * (k % 2)) * s, -hr * (0.34 - 0.2 * k))
					ci.draw_circle(p, hr * 0.17 + 2.0, INK)
				for k in 3:
					var p := h + Vector2(hr * (0.84 + 0.08 * (k % 2)) * s, -hr * (0.34 - 0.2 * k))
					ci.draw_circle(p, hr * 0.17, hair)
			_ellipse(ci, h + Vector2(0, -hr * 0.8), Vector2(hr * 0.75, hr * 0.28), hair)
		"bun", "beehive":
			_ellipse(ci, h + Vector2(0, -hr * 0.78), Vector2(hr * 0.9, hr * 0.34), hair)
		_:
			# bald: a shine
			ci.draw_arc(h + Vector2(-hr * 0.25, -hr * 0.55), hr * 0.22, PI * 1.1, PI * 1.6, 8, Color(1, 1, 1, 0.65), 3.0, true)
	# hats and bands go over the hair
	if extras.has("headband"):
		var band := _col(lk, "headband", Color("#e5383b"))
		ci.draw_line(h + Vector2(-hr * 1.02, -hr * 0.42), h + Vector2(hr * 1.02, -hr * 0.42), INK, hr * 0.32, true)
		ci.draw_line(h + Vector2(-hr * 0.98, -hr * 0.42), h + Vector2(hr * 0.98, -hr * 0.42), band, hr * 0.22, true)
		for s: float in [-1.0, 1.0]:
			ci.draw_line(h + Vector2(hr * 1.0, -hr * 0.42), h + Vector2(hr * (1.25 + 0.1 * s), -hr * (0.15 + 0.2 * s)), band, hr * 0.12, true)
	if extras.has("cap"):
		var capc := _col(lk, "cap", Color("#e5383b"))
		var dome := PackedVector2Array()
		for i in 17:
			var a := PI + PI * i / 16.0
			dome.append(h + Vector2(cos(a) * hr * 0.98, -hr * 0.3 + sin(a) * hr * 0.82))
		_poly_outlined(ci, dome, capc)
		_outlined_ellipse(ci, h + Vector2(hr * 0.55, -hr * 0.3), Vector2(hr * 0.62, hr * 0.13), capc.darkened(0.15), 2.5)
		ci.draw_circle(h + Vector2(0, -hr * 1.12), hr * 0.08, capc.darkened(0.2))
	if extras.has("captain_cap"):
		var top := Rect2(h + Vector2(-hr * 0.95, -hr * 1.25), Vector2(hr * 1.9, hr * 0.62))
		UiDraw.rounded_rect(ci, top.grow(3.0), INK, 10)
		UiDraw.rounded_rect(ci, top, WHITE, 8)
		ci.draw_rect(Rect2(top.position + Vector2(0, top.size.y * 0.62), Vector2(top.size.x, top.size.y * 0.38)), Color("#1f3a5f"))
		_outlined_ellipse(ci, h + Vector2(0, -hr * 0.6), Vector2(hr * 0.86, hr * 0.13), INK.lightened(0.15), 2.0)
		UiDraw.star(ci, h + Vector2(0, -hr * 1.0), hr * 0.16, Palette.SUNNY)
	if extras.has("beekeeper_hat"):
		_draw_beekeeper_hat(ci, h, hr, _col(lk, "beekeeper_hat", Color("#efe9d2")))
	if extras.has("pillbox_hat"):
		_draw_pillbox_hat(ci, h, hr, _col(lk, "pillbox_hat", Color("#0f766e")))
	# face
	for s: float in [-1.0, 1.0]:
		var e := h + Vector2(hr * 0.36 * s, -hr * 0.04)
		_eye(ci, e, hr * 0.2, blink)
		if lady:
			ci.draw_line(e + Vector2(hr * 0.12 * s, -hr * 0.2), e + Vector2(hr * 0.26 * s, -hr * 0.3), INK, 2.5, true)
		_ellipse(ci, h + Vector2(hr * 0.55 * s, hr * 0.35), Vector2(hr * 0.15, hr * 0.08), Color(1, 0.45, 0.45, 0.4))
		if bool(lk.get("brows", false)) and not extras.has("cap"):
			ci.draw_line(e + Vector2(-hr * 0.17, -hr * 0.34 - hr * 0.03 * s), e + Vector2(hr * 0.17, -hr * 0.34 + hr * 0.03 * s), hair.darkened(0.1), hr * 0.1, true)
	_draw_glasses(ci, lk, h, hr)
	_ellipse(ci, h + Vector2(0, hr * 0.15), Vector2(hr * 0.13, hr * 0.11), _col(lk, "nose", skin.darkened(0.1)))
	if bool(lk.get("mustache", false)):
		_outlined_ellipse(ci, h + Vector2(-hr * 0.2, hr * 0.37), Vector2(hr * 0.26, hr * 0.12), hair, 2.5, 0.25)
		_outlined_ellipse(ci, h + Vector2(hr * 0.2, hr * 0.37), Vector2(hr * 0.26, hr * 0.12), hair, 2.5, -0.25)
		if talk_open:
			_ellipse(ci, h + Vector2(0, hr * 0.58), Vector2(hr * 0.18, hr * 0.14), Color("#7a2a3a"))
	elif talk_open:
		_ellipse(ci, h + Vector2(0, hr * 0.52), Vector2(hr * 0.17, hr * 0.15), Color("#7a2a3a"))
		ci.draw_arc(h + Vector2(0, hr * 0.52), hr * 0.17, 0, TAU, 16, Color("#d9465f") if lady else INK, 3.0, true)
	else:
		ci.draw_arc(h + Vector2(0, hr * 0.32), hr * 0.25, 0.5, PI - 0.5, 12, Color("#d9465f") if lady else INK, 4.0, true)
	if extras.has("puppet"):
		_draw_cookie_puppet(ci, c + Vector2(r * 0.6, r * 0.62), r * 0.36, false, false, bg(who))
	if extras.has("drumsticks"):
		for s: float in [-1.0, 1.0]:
			var a := c + Vector2(r * (0.55 + 0.12 * s), r * 0.85)
			var b := a + Vector2(r * 0.18 * s - r * 0.1, -r * 0.62)
			ci.draw_line(a, b, INK, 7.0, true)
			ci.draw_line(a, b, Color("#e9c48a"), 4.0, true)
			ci.draw_circle(b, 4.5, INK)
			ci.draw_circle(b, 3.0, Color("#f6e1b3"))
	if extras.has("bee"):
		_draw_bee(ci, h + Vector2(hr * 1.32, 0.0), r)


## Chip: a chocolate-chip cookie puppet with a bite out of his head, googly eyes and a felt mouth.
## bite_col: the background showing through the bite.
static func _draw_cookie_puppet(ci: CanvasItem, c: Vector2, r: float, talk_open: bool, blink: bool, bite_col: Color) -> void:
	var cookie := Color("#d99a5b")
	var cr := r * 0.78
	var cc := c + Vector2(0, r * 0.08)
	ci.draw_circle(cc, cr + 3.0, INK)
	ci.draw_circle(cc, cr, cookie)
	for p: Vector2 in [Vector2(-0.5, -0.1), Vector2(0.45, 0.25), Vector2(-0.15, 0.55), Vector2(0.2, -0.35), Vector2(-0.55, 0.35)]:
		ci.draw_circle(cc + p * cr, cr * 0.09, Color("#5a3d2b"))
	# the bite out of the top-right of his head
	for p: Vector2 in [Vector2(0.45, -0.8), Vector2(0.78, -0.5), Vector2(0.15, -0.98)]:
		ci.draw_circle(cc + p * cr, cr * 0.24, bite_col)
	# googly eyes
	for sd: float in [-1.0, 1.0]:
		var e := cc + Vector2(cr * 0.3 * sd, -cr * 0.18)
		ci.draw_circle(e, cr * 0.2, INK)
		ci.draw_circle(e, cr * 0.17, WHITE)
		if blink:
			ci.draw_line(e + Vector2(-cr * 0.14, 0), e + Vector2(cr * 0.14, 0), INK, 3.0, true)
		else:
			ci.draw_circle(e + Vector2(cr * 0.05 * sd, cr * 0.05), cr * 0.08, INK)
	# the felt mouth: a hinge that drops open when he talks
	if talk_open:
		_ellipse(ci, cc + Vector2(0, cr * 0.36), Vector2(cr * 0.34, cr * 0.2), Color("#7a2a3a"))
		_ellipse(ci, cc + Vector2(0, cr * 0.44), Vector2(cr * 0.16, cr * 0.08), Color("#ff6f8a"))
	else:
		ci.draw_arc(cc + Vector2(0, cr * 0.16), cr * 0.34, 0.4, PI - 0.4, 12, INK, 4.0, true)


## A beekeeper's straw hat: a wide brim, a woven dome, and the mesh veil rolled up round the crown.
static func _draw_beekeeper_hat(ci: CanvasItem, h: Vector2, hr: float, straw: Color) -> void:
	var weave := straw.darkened(0.15)
	var brim := h + Vector2(0, -hr * 0.66)
	_outlined_ellipse(ci, brim, Vector2(hr * 1.55, hr * 0.22), straw, 2.5)
	var ring := PackedVector2Array()
	for i in 13:
		var a := PI * i / 12.0
		ring.append(brim + Vector2(cos(a) * hr * 1.2, sin(a) * hr * 0.13))
	ci.draw_polyline(ring, weave, 2.0, true)
	var dc := h + Vector2(0, -hr * 0.72)
	var dr := Vector2(hr * 0.72, hr * 0.78)
	var dome := PackedVector2Array()
	for i in 17:
		var a := PI + PI * i / 16.0
		dome.append(dc + Vector2(cos(a) * dr.x, sin(a) * dr.y))
	_poly_outlined(ci, dome, straw)
	for k: float in [0.3, 0.55]:
		var half := dr.x * sqrt(1.0 - k * k) - 3.0
		ci.draw_line(dc + Vector2(-half, -dr.y * k), dc + Vector2(half, -dr.y * k), weave, 2.0, true)
	# the veil, rolled up: a puffy grey band with a mesh of dots
	var roll := Rect2(h + Vector2(-hr * 0.84, -hr * 0.92), Vector2(hr * 1.68, hr * 0.3))
	UiDraw.rounded_rect(ci, roll.grow(2.5), INK, int(hr * 0.16))
	UiDraw.rounded_rect(ci, roll, Color("#cfd4da"), int(hr * 0.14))
	for ix in 9:
		for iy in 2:
			var p := roll.position + Vector2(roll.size.x * (ix + 0.5 + 0.5 * iy) / 9.5, roll.size.y * (0.32 + 0.38 * iy))
			ci.draw_circle(p, maxf(1.0, hr * 0.035), Color("#8f979f"))


## A cabin-crew pillbox hat, tilted on one side of the head in front of the bun, with a darker band
## and a little gold wings badge.
static func _draw_pillbox_hat(ci: CanvasItem, h: Vector2, hr: float, col: Color) -> void:
	var tilt := -0.3
	var p := h + Vector2(-hr * 0.3, -hr * 1.02)
	var w := hr * 0.5
	var side := hr * 0.4
	var ey := hr * 0.14
	# the side: down the left, round the front, up the right, back over the top
	var body := PackedVector2Array()
	for i in 13:
		var a := PI - PI * i / 12.0
		body.append(p + Vector2(cos(a) * w, side * 0.5 + sin(a) * ey).rotated(tilt))
	for i in 13:
		var a := -PI * i / 12.0
		body.append(p + Vector2(cos(a) * w, -side * 0.5 + sin(a) * ey).rotated(tilt))
	ci.draw_colored_polygon(body, col)
	var band := PackedVector2Array()
	for i in 13:
		var a := PI - PI * i / 12.0
		band.append(p + Vector2(cos(a) * w, side * 0.5 + sin(a) * ey).rotated(tilt))
	for i in 13:
		var a := PI * i / 12.0
		band.append(p + Vector2(cos(a) * w, side * 0.18 + sin(a) * ey).rotated(tilt))
	ci.draw_colored_polygon(band, col.darkened(0.25))
	# the outline last, so the band doesn't eat half of it along the bottom
	var rim := body.duplicate()
	rim.append(body[0])
	ci.draw_polyline(rim, INK, 3.0, true)
	_ellipse(ci, p + Vector2(0, -side * 0.5).rotated(tilt), Vector2(w * 0.94, ey * 0.75), col.lightened(0.12), tilt)
	# the wings badge
	var badge := p + Vector2(0, hr * 0.08).rotated(tilt)
	var gold := Color("#ffd23f")
	for sd: float in [-1.0, 1.0]:
		_ellipse(ci, badge + Vector2(hr * 0.12 * sd, -hr * 0.01).rotated(tilt), Vector2(hr * 0.11, hr * 0.04), gold, tilt - 0.25 * sd)
	ci.draw_circle(badge, hr * 0.07 + 1.5, INK)
	ci.draw_circle(badge, hr * 0.07, gold)


## A silk scarf round the collar (it hides the pearls), knotted to one side with two tails.
static func _draw_neck_scarf(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var band := PackedVector2Array()
	var stripe := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		band.append(c + Vector2(lerpf(-r * 0.34, r * 0.34, t), r * (0.44 + 0.02 * sin(PI * t))))
		stripe.append(c + Vector2(lerpf(-r * 0.33, r * 0.33, t), r * (0.5 + 0.05 * sin(PI * t))))
	for i in 9:
		var t := 1.0 - i / 8.0
		band.append(c + Vector2(lerpf(-r * 0.34, r * 0.34, t), r * (0.56 + 0.08 * sin(PI * t))))
	_poly_outlined(ci, band, col)
	ci.draw_polyline(stripe, col.lightened(0.4), 2.0, true)
	var knot := c + Vector2(r * 0.15, r * 0.6)
	_outlined_ellipse(ci, knot + Vector2(r * 0.09, r * 0.14), Vector2(r * 0.055, r * 0.13), col.darkened(0.08), 2.5, -0.45)
	_outlined_ellipse(ci, knot + Vector2(-r * 0.01, r * 0.16), Vector2(r * 0.055, r * 0.13), col.darkened(0.08), 2.5, 0.2)
	_outlined_ellipse(ci, knot, Vector2(r * 0.075, r * 0.065), col, 2.5)


## Gerald the bee, hovering by the head: a striped body, buzzing wings, a stinger and a dotted trail.
static func _draw_bee(ci: CanvasItem, at: Vector2, r: float) -> void:
	var still := bool(Game.settings.get("reduced_motion", false))
	var t := 0.0 if still else Time.get_ticks_msec() / 1000.0
	var p := at + Vector2(cos(t * 2.2) * r * 0.05, sin(t * 4.4) * r * 0.035)
	var body := Vector2(r * 0.13, r * 0.095)
	var black := Color("#2b2b2b")
	for k in 3:
		ci.draw_circle(p + Vector2(r * (0.2 + 0.08 * k), r * (0.04 + 0.03 * sin(k * 1.7 + t * 3.0))), maxf(1.0, r * 0.018), Color(INK, 0.35))
	# stinger at the back (he faces the head, on the left)
	var sting := PackedVector2Array([p + Vector2(body.x * 0.8, -body.y * 0.3), p + Vector2(body.x * 1.35, 0), p + Vector2(body.x * 0.8, body.y * 0.3)])
	ci.draw_colored_polygon(sting, black)
	var flap := 0.55 + 0.45 * absf(sin(t * 30.0))
	for sd: float in [-1.0, 1.0]:
		_outlined_ellipse(ci, p + Vector2(r * 0.03 * sd, -body.y * 1.15), Vector2(r * 0.065, r * 0.1 * flap), Color("#eaf6ff"), 2.0, 0.45 * sd)
	_outlined_ellipse(ci, p, body, Color("#ffd23f"), 2.0)
	for k: float in [-0.1, 0.4]:
		_ellipse(ci, p + Vector2(body.x * k, 0), Vector2(body.x * 0.16, body.y * 0.92), black)
	var head := p + Vector2(-body.x * 1.05, -body.y * 0.1)
	ci.draw_circle(head, body.y * 0.78, black)
	ci.draw_circle(head + Vector2(-body.y * 0.25, -body.y * 0.2), maxf(1.0, body.y * 0.22), WHITE)
	for sd: float in [-1.0, 1.0]:
		var base := head + Vector2(body.y * 0.2 * sd, -body.y * 0.6)
		ci.draw_line(base, base + Vector2(-body.y * (0.5 - 0.3 * sd), -body.y * 0.75), black, 1.5, true)


static func _draw_glasses(ci: CanvasItem, lk: Dictionary, h: Vector2, hr: float) -> void:
	var kind := String(lk.get("glasses", "none"))
	if kind == "none" or kind == "":
		return
	var col := _col(lk, "glasses_color", Color("#5a3d2b"))
	var y := -hr * 0.04 if kind != "perched" else -hr * 0.86
	var rr := hr * (0.3 if kind != "perched" else 0.17)
	for s: float in [-1.0, 1.0]:
		var lc := h + Vector2(hr * (0.36 if kind != "perched" else 0.24) * s, y)
		if kind == "perched":
			ci.draw_circle(lc, rr, Color("#dff6ff"))
		ci.draw_arc(lc, rr, 0, TAU, 20, INK, 5.0, true)
		ci.draw_arc(lc, rr, 0, TAU, 20, col, 3.0, true)
		if kind == "cateye":
			ci.draw_line(lc + Vector2(rr * 0.9 * s, -rr * 0.4), lc + Vector2(rr * 1.4 * s, -rr * 1.05), col, 3.5, true)
	ci.draw_line(h + Vector2(-hr * 0.07, y), h + Vector2(hr * 0.07, y), col, 3.0, true)


# ---------------------------------------------------------------- helpers

static func _col(lk: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = lk.get(key, null)
	if v is Color:
		return v
	if v is String and String(v).begins_with("#"):
		return Color(String(v))
	return fallback


static func _ellipse(ci: CanvasItem, at: Vector2, radii: Vector2, col: Color, rot: float = 0.0) -> void:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y).rotated(rot))
	ci.draw_colored_polygon(pts, col)


static func _outlined_ellipse(ci: CanvasItem, at: Vector2, radii: Vector2, col: Color, w: float, rot: float = 0.0) -> void:
	_ellipse(ci, at, radii + Vector2(w, w), INK, rot)
	_ellipse(ci, at, radii, col, rot)


static func _poly_outlined(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var ring := pts.duplicate()
	ring.append(pts[0])
	ci.draw_polyline(ring, INK, 3.0, true)


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
