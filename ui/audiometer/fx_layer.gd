class_name AoFx
extends Control
## AoFx: lightweight particles and bouncy callouts drawn on top of the AudiOtron (ui/ only).
## Positions are canvas coordinates (this layer sits at the origin of the screen's CanvasLayer).
## Respects reduced motion (fewer, slower particles; smaller callouts).

var _parts: Array[Dictionary] = []
var _calls: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _chips: Array[Dictionary] = []
## The patient's speech bubble (one at a time): {"text", "rect": Rect2, "tail": Vector2, "t", "max"}
var _speech: Dictionary = {}
## Name on the speech bubble's tab (the screen sets it from PatientProfile.short_name()).
var speaker := "Gus"
## (v3) The Cross-Hearing Ghost in flight: {"from", "to", "t", "max", "text", "sub", "said", "at"} or {}.
var _ghost: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = 99


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


## A burst of round particles (press lamp, combo).
func burst(at: Vector2, color: Color, count: int = 10, speed: float = 240.0, size_px: float = 6.0) -> void:
	if _reduced():
		count = maxi(3, count / 3)
	for i in count:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * speed * _rng.randf_range(0.45, 1.0)
		_parts.append({"pos": at, "vel": v, "life": 0.0, "max": _rng.randf_range(0.35, 0.6), "color": color,
			"size": size_px * _rng.randf_range(0.6, 1.2), "kind": 0, "rot": 0.0, "spin": 0.0, "grav": 300.0})


## Confetti that tumbles and falls (stamps, birdies, ear complete).
func confetti(at: Vector2, count: int = 24, spread: float = 320.0) -> void:
	if _reduced():
		count = maxi(4, count / 3)
	var cols := [Palette.SUNNY, Palette.CORAL, Palette.MINT, Palette.SKY, Palette.PLUM, Palette.SELECT_ORANGE]
	for i in count:
		var a := -PI * 0.5 + _rng.randf_range(-1.1, 1.1)
		var v := Vector2(cos(a), sin(a)) * spread * _rng.randf_range(0.5, 1.0)
		_parts.append({"pos": at, "vel": v, "life": 0.0, "max": _rng.randf_range(0.9, 1.4), "color": cols[i % cols.size()],
			"size": _rng.randf_range(5.0, 9.0), "kind": 1, "rot": _rng.randf() * TAU, "spin": _rng.randf_range(-12.0, 12.0), "grav": 520.0})


## Little stars (eagle, combo milestones).
func stars(at: Vector2, count: int = 8, color: Color = Palette.SUNNY) -> void:
	if _reduced():
		count = maxi(3, count / 2)
	for i in count:
		var a := _rng.randf() * TAU
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(120.0, 260.0)
		_parts.append({"pos": at, "vel": v, "life": 0.0, "max": _rng.randf_range(0.5, 0.8), "color": color,
			"size": _rng.randf_range(7.0, 11.0), "kind": 2, "rot": 0.0, "spin": _rng.randf_range(-6.0, 6.0), "grav": 120.0})


func ring(at: Vector2, color: Color, radius: float = 60.0) -> void:
	_rings.append({"pos": at, "t": 0.0, "max": 0.45, "color": color, "r": radius})


## A big bouncy word ("Birdie!", "Textbook!") that pops, wobbles, rises and fades.
func callout(text: String, at: Vector2, color: Color = Palette.SUNNY, size_px: int = 46, sub: String = "", rot_deg: float = -4.0, life: float = 1.3) -> void:
	if _reduced():
		size_px = int(size_px * 0.8)
	# (v3, integrator) two callouts in quick succession at the same spot stack instead of overlapping,
	# and a long one ("Hughson would be proud!") is nudged in from the screen edge instead of clipped
	var pos := at
	if is_inside_tree():
		var half := AoDraw.FONT_BOLD.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x * 0.5 + 18.0
		var vw := get_viewport_rect().size.x
		pos.x = clampf(pos.x, half, maxf(half, vw - half))
		at.x = pos.x
	var step := size_px * 1.25
	for _i in 4:
		var clash := false
		for c: Dictionary in _calls:
			if float(c["t"]) < float(c["max"]) * 0.8 and absf((c["pos"] as Vector2).y - pos.y) < step * 0.9 \
					and absf((c["pos"] as Vector2).x - pos.x) < 260.0:
				clash = true
				break
		if not clash:
			break
		pos.y += -step if at.y - step > size_px else step
	_calls.append({"text": text, "pos": pos, "t": 0.0, "max": life, "color": color, "size": size_px, "sub": sub, "rot": deg_to_rad(rot_deg)})


## A small rounded label that pops, floats up a little and fades ("HEARD!", "...").
func chip(text: String, at: Vector2, fill: Color, text_color: Color = Palette.INK, size_px: int = 18, life: float = 0.9) -> void:
	_chips.append({"text": text, "pos": at, "t": 0.0, "max": life, "fill": fill, "ink": text_color, "size": size_px})


## (v3) The Cross-Hearing Ghost: a little sheet ghost pops up at `from` (the test ear's chart),
## swoops over to `to` (the other ear, which really heard the beep) and shouts its text there.
## callout_at: where its shout goes (default: above `to`); keep it clear of the chart's symbols.
func ghost(from: Vector2, to: Vector2, text: String = "BOO!", sub: String = "", callout_at: Vector2 = Vector2.INF) -> void:
	var at := callout_at if callout_at != Vector2.INF else to + Vector2(0, -92)
	_ghost = {"from": from, "to": to, "t": 0.0, "max": 2.0 if not _reduced() else 1.6, "text": text, "sub": sub, "said": false, "at": at}
	queue_redraw()


## A comic speech bubble whose tail points at tail_to (the patient's booth quips). Replaces any other.
func speech(text: String, rect: Rect2, tail_to: Vector2, life: float = 3.2) -> void:
	_speech = {"text": text, "rect": rect, "tail": tail_to, "t": 0.0, "max": life}
	queue_redraw()


func clear_speech() -> void:
	if not _speech.is_empty() and float(_speech["t"]) < float(_speech["max"]) - 0.2:
		_speech["t"] = float(_speech["max"]) - 0.2  # quick fade-out
	queue_redraw()


func has_speech() -> bool:
	return not _speech.is_empty()


## Coffee splash (the hair-blast gag): brown drops that arc and fall.
func splash(at: Vector2, count: int = 14) -> void:
	if _reduced():
		count = maxi(4, count / 3)
	var cols := [Color("#6f4a2e"), Color("#8a5a35"), Color("#a8744a")]
	for i in count:
		var a := -PI * 0.5 + _rng.randf_range(-1.3, 1.3)
		var v := Vector2(cos(a), sin(a)) * _rng.randf_range(160.0, 340.0)
		_parts.append({"pos": at, "vel": v, "life": 0.0, "max": _rng.randf_range(0.6, 0.95), "color": cols[i % cols.size()],
			"size": _rng.randf_range(4.0, 8.0), "kind": 0, "rot": 0.0, "spin": 0.0, "grav": 900.0})


func busy() -> bool:
	return not (_parts.is_empty() and _calls.is_empty() and _rings.is_empty() and _chips.is_empty() and _speech.is_empty() and _ghost.is_empty())


func _process(delta: float) -> void:
	if not busy():
		return
	for p: Dictionary in _parts:
		p["life"] = float(p["life"]) + delta
		var v: Vector2 = p["vel"]
		v.y += float(p["grav"]) * delta
		v *= 1.0 - 1.8 * delta
		p["vel"] = v
		p["pos"] = (p["pos"] as Vector2) + v * delta
		p["rot"] = float(p["rot"]) + float(p["spin"]) * delta
	_parts = _parts.filter(func(p: Dictionary) -> bool: return float(p["life"]) < float(p["max"]))
	for c: Dictionary in _calls:
		c["t"] = float(c["t"]) + delta
	_calls = _calls.filter(func(c: Dictionary) -> bool: return float(c["t"]) < float(c["max"]))
	for r: Dictionary in _rings:
		r["t"] = float(r["t"]) + delta
	_rings = _rings.filter(func(r: Dictionary) -> bool: return float(r["t"]) < float(r["max"]))
	for c: Dictionary in _chips:
		c["t"] = float(c["t"]) + delta
	_chips = _chips.filter(func(c: Dictionary) -> bool: return float(c["t"]) < float(c["max"]))
	if not _speech.is_empty():
		_speech["t"] = float(_speech["t"]) + delta
		if float(_speech["t"]) >= float(_speech["max"]):
			_speech = {}
	if not _ghost.is_empty():
		_ghost["t"] = float(_ghost["t"]) + delta
		var gk := float(_ghost["t"]) / float(_ghost["max"])
		if gk >= 0.42 and not bool(_ghost["said"]):
			_ghost["said"] = true
			var to: Vector2 = _ghost["to"]
			callout(String(_ghost["text"]), _ghost["at"], Color("#efeaf7"), 44 if String(_ghost["text"]).length() <= 6 else 32, String(_ghost["sub"]), 5.0, 1.5)
			stars(to, 8, Palette.PLUM.lightened(0.4))
		if gk >= 1.0:
			_ghost = {}
	queue_redraw()


func _draw() -> void:
	for r: Dictionary in _rings:
		var k := float(r["t"]) / float(r["max"])
		draw_arc(r["pos"], float(r["r"]) * (0.3 + 0.7 * k), 0.0, TAU, 40, Color(r["color"], 0.7 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
	for p: Dictionary in _parts:
		var k := float(p["life"]) / float(p["max"])
		var col: Color = p["color"]
		col.a = 1.0 - k * k
		var pos: Vector2 = p["pos"]
		var s := float(p["size"])
		match int(p["kind"]):
			0:
				draw_circle(pos, s * (1.0 - 0.5 * k), col)
			1:
				draw_set_transform(pos, float(p["rot"]), Vector2(1.0, absf(cos(float(p["rot"]) * 1.7)) * 0.8 + 0.2))
				draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), col)
				draw_set_transform(Vector2.ZERO)
			2:
				draw_set_transform(pos, float(p["rot"]))
				UiDraw.star(self, Vector2.ZERO, s * (1.0 - 0.4 * k), col)
				draw_set_transform(Vector2.ZERO)
	for c: Dictionary in _calls:
		_draw_callout(c)
	for c: Dictionary in _chips:
		_draw_chip(c)
	if not _speech.is_empty():
		_draw_speech()
	if not _ghost.is_empty():
		_draw_ghost()


func _draw_chip(c: Dictionary) -> void:
	var t := float(c["t"])
	var life := float(c["max"])
	var k := t / life
	var pop := 1.0 + 0.45 * maxf(0.0, 1.0 - t / 0.12) if t < 0.12 else 1.0 + 0.12 * sin(minf(1.0, (t - 0.12) / 0.2) * PI)
	var alpha := clampf((life - t) / (life * 0.35), 0.0, 1.0)
	var pos: Vector2 = (c["pos"] as Vector2) + Vector2(0, -26.0 * k)
	var size_px := int(c["size"])
	var text: String = c["text"]
	var ts := AoDraw.text_size(text, size_px, AoDraw.FONT_BOLD)
	draw_set_transform(pos, 0.0, Vector2.ONE * pop)
	var r := Rect2(Vector2(-ts.x * 0.5 - 10.0, -ts.y * 0.5 - 3.0), Vector2(ts.x + 20.0, ts.y + 6.0))
	AoDraw.rbox(self, Rect2(r.position + Vector2(0, 3), r.size), Color(Palette.INK, 0.35 * alpha), int(r.size.y * 0.5))
	AoDraw.rbox(self, r, Color(c["fill"], alpha), int(r.size.y * 0.5), 3, Color(Palette.INK, alpha))
	AoDraw.text_c(self, Vector2(0, -1), text, size_px, Color(c["ink"], alpha), AoDraw.FONT_BOLD)
	draw_set_transform(Vector2.ZERO)


func _draw_speech() -> void:
	var t := float(_speech["t"])
	var life := float(_speech["max"])
	var alpha := clampf(minf(t / 0.12, (life - t) / 0.25), 0.0, 1.0)
	var r: Rect2 = _speech["rect"]
	var tail: Vector2 = _speech["tail"]
	var s := 1.0
	if t < 0.3:
		var k := t / 0.3
		s = 1.0 + 0.18 * sin(k * PI) * (1.0 - k) - 0.25 * (1.0 - minf(1.0, k * 3.0))
	var c := r.get_center()
	draw_set_transform(c, 0.0, Vector2.ONE * s)
	var lr := Rect2(r.position - c, r.size)
	var base_x := clampf(tail.x - c.x, lr.position.x + 26.0, lr.end.x - 40.0)
	var top := lr.position.y if tail.y < c.y else lr.end.y
	var dir := -1.0 if tail.y < c.y else 1.0
	var tip := tail - c
	var tri := PackedVector2Array([Vector2(base_x - 14.0, top - dir * 2.0), Vector2(base_x + 16.0, top - dir * 2.0), tip])
	draw_colored_polygon(PackedVector2Array([tri[0] + Vector2(0, -dir * 4.0), tri[1] + Vector2(0, -dir * 4.0), tri[2] + Vector2(0, dir * 4.0)]), Color(Palette.INK, alpha))
	AoDraw.rbox(self, Rect2(lr.position + Vector2(0, 4), lr.size), Color(Palette.INK, 0.3 * alpha), 18)
	AoDraw.rbox(self, lr, Color(Palette.PAPER, alpha), 18, 4, Color(Palette.INK, alpha))
	draw_colored_polygon(tri, Color(Palette.PAPER, alpha))
	var name_w := maxf(54.0, AoDraw.text_size(speaker, 14, AoDraw.FONT_BOLD).x + 22.0)
	var name_r := Rect2(lr.position + Vector2(14, -12), Vector2(name_w, 22))
	AoDraw.rbox(self, name_r, Color(Palette.SELECT_ORANGE, alpha), 11, 3, Color(Palette.INK, alpha))
	AoDraw.text_c(self, name_r.get_center(), speaker, 14, Color(Palette.INK, alpha), AoDraw.FONT_BOLD)
	var lines := _wrap(String(_speech["text"]), 17, lr.size.x - 28.0)
	var y := lr.position.y + 16.0 + (lr.size.y - 16.0) * 0.5 - (lines.size() - 1) * 11.0
	for line: String in lines:
		AoDraw.text_c(self, Vector2(0, y), line, 17, Color(Palette.INK, alpha), AoDraw.FONT_SEMI)
		y += 22.0
	draw_set_transform(Vector2.ZERO)


static func _wrap(text: String, size_px: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var cur := ""
	for w: String in text.split(" ", false):
		var trial := w if cur == "" else cur + " " + w
		if cur != "" and AoDraw.text_size(trial, size_px, AoDraw.FONT_SEMI).x > width:
			out.append(cur)
			cur = w
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


func _draw_callout(c: Dictionary) -> void:
	var t := float(c["t"])
	var life := float(c["max"])
	var size_px := int(c["size"])
	# elastic pop in, then rise and fade
	var pop := 1.0
	if t < 0.35:
		var k := t / 0.35
		pop = pow(2.0, -10.0 * k) * sin((k * 10.0 - 0.75) * TAU / 3.0) + 1.0 if k > 0.0 else 0.0
		pop = clampf(pop, 0.0, 1.6)
	var rise := maxf(0.0, t - life * 0.55) * 60.0
	var alpha := clampf((life - t) / (life * 0.3), 0.0, 1.0)
	var pos: Vector2 = c["pos"]
	pos.y -= rise
	var wob := sin(t * 14.0) * 0.04 * maxf(0.0, 1.0 - t * 2.0)
	draw_set_transform(pos, float(c["rot"]) + wob, Vector2.ONE * pop)
	var text: String = c["text"]
	var col: Color = c["color"]
	AoDraw.text_c(self, Vector2(3, 5), text, size_px, Color(Palette.INK, 0.5 * alpha), AoDraw.FONT_BOLD, 14, Color(Palette.INK, 0.5 * alpha))
	AoDraw.text_c(self, Vector2.ZERO, text, size_px, Color(col, alpha), AoDraw.FONT_BOLD, 14, Color(Palette.INK, alpha))
	var sub: String = c["sub"]
	if sub != "":
		AoDraw.text_c(self, Vector2(0, size_px * 0.78), sub, int(size_px * 0.42), Color(Palette.INK, alpha), AoDraw.FONT_BOLD, 8, Color(Palette.PAPER, alpha))
	draw_set_transform(Vector2.ZERO)


## (v3) The Cross-Hearing Ghost: pops up, swoops along an arc to the other ear, hovers, fades.
func _draw_ghost() -> void:
	var k := float(_ghost["t"]) / float(_ghost["max"])
	var from: Vector2 = _ghost["from"]
	var to: Vector2 = _ghost["to"]
	var fly := clampf((k - 0.08) / 0.34, 0.0, 1.0)
	var e := fly * fly * (3.0 - 2.0 * fly)
	var mid := (from + to) * 0.5 + Vector2(0, -110)
	var pos := from.lerp(mid, e).lerp(mid.lerp(to, e), e)
	pos.y += sin(float(_ghost["t"]) * 9.0) * 5.0
	var pop := clampf(k / 0.08, 0.0, 1.0)
	var scale := (0.4 + 0.75 * pop) if k < 0.08 else 1.15 - 0.15 * clampf((k - 0.08) / 0.1, 0.0, 1.0)
	var alpha := 1.0 if k < 0.8 else clampf((1.0 - k) / 0.2, 0.0, 1.0)
	var lean := (to.x - from.x) * 0.0006 * (1.0 - fly) if fly < 1.0 else 0.0
	# a wispy trail behind it
	for i in 5:
		var tk := clampf(e - 0.07 * (i + 1), 0.0, 1.0)
		var tp := from.lerp(mid, tk).lerp(mid.lerp(to, tk), tk)
		draw_circle(tp, 9.0 - i * 1.4, Color(1, 1, 1, 0.35 * alpha * (1.0 - i / 5.0)))
	draw_set_transform(pos, lean, Vector2.ONE * scale)
	var body := Color(1, 1, 1, alpha)
	var ink := Color(Palette.INK, alpha)
	var shape := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		shape.append(Vector2(cos(a), sin(a)) * 24.0 + Vector2(0, -6))
	for i in 7:
		var x := 24.0 - 48.0 * i / 6.0
		var wav := 6.0 * sin(float(_ghost["t"]) * 12.0 + i * 1.6)
		shape.append(Vector2(x, 22.0 + (8.0 if i % 2 == 0 else 0.0) + wav * 0.4))
	draw_colored_polygon(shape, Color(Palette.PLUM.lightened(0.6), 0.5 * alpha))
	var inner := PackedVector2Array()
	for p: Vector2 in shape:
		inner.append(p * 0.9 + Vector2(0, -1))
	draw_colored_polygon(inner, body)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, ink, 3.0, true)
	draw_circle(Vector2(-8, -8), 4.5, ink)
	draw_circle(Vector2(8, -8), 4.5, ink)
	draw_circle(Vector2(-6.5, -9.5), 1.5, body)
	draw_circle(Vector2(9.5, -9.5), 1.5, body)
	draw_arc(Vector2(0, 5), 5.0, 0.0, TAU, 16, ink, 3.0, true)
	draw_circle(Vector2(-15, 1), 3.5, Color(Palette.CORAL, 0.45 * alpha))
	draw_circle(Vector2(15, 1), 3.5, Color(Palette.CORAL, 0.45 * alpha))
	draw_set_transform(Vector2.ZERO)
