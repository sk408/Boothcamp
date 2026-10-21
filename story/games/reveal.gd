extends Control
## Reveal: Gus's audiogram is drawn in with a little melody (quieter notes where he hears
## less), a dot hops along the right-ear line, then a skier zooms down the slope and the
## shape title lands. No input of its own (the level's dialogue follows).
## Story-internal:  var r := Reveal.new(); hud.add_game(r); await r.run(results)
## Anchor: "reveal_audiogram".

const UiKit := preload("res://story/ui_kit.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"

var results: Dictionary = {}
var ag: Audiogram
var _fx: Control
var _title: Label
var _chips: VBoxContainer
var _hop := -1.0          # index along the right-ear points (float), -1 = hidden
var _ski := -1.0          # 0..1 along the slope, -1 = hidden
var _snow: Array[Dictionary] = []
var _t := 0.0
var _card: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var deco := UiKit.full_rect()
	deco.draw.connect(func() -> void:
		if size.x < 10.0 or size.y < 10.0:
			return
		for i in 18:
			var x := fmod(i * 151.0, size.x)
			var y := fmod(i * 89.0 + 40.0, size.y)
			UiDraw.ear_symbol(deco, Vector2(x, y), "right" if i % 2 == 0 else "left", 22.0, 3.0, false, Color(Palette.ear_color("right" if i % 2 == 0 else "left"), 0.07)))
	add_child(deco)
	var head := VBoxContainer.new()
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.offset_top = 18
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var h := UiKit.label("GRANDPA GUS'S AUDIOGRAM", 34, Palette.INK, 700)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(h)
	var legend := UiKit.hint_row(["Right ear:", "red O", "   Left ear:", "blue X", "   Lower on the chart = needs louder beeps"], 17, Palette.INK_SOFT)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(legend)
	_card = UiKit.panel(Palette.PAPER, Palette.INK, 22)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -430
	_card.offset_right = 430
	_card.offset_top = -276
	_card.offset_bottom = 160
	add_child(_card)
	if ResourceLoader.exists(AUDIOGRAM_SCENE):
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Audiogram
		ag.ear = "both"
		ag.show_notes = true   # (E18) transducer, mastoids, reliability under the chart
		ag.true_aspect = true  # (E12) one octave as wide as 20 dB is tall
		ag.aspect_align = 1.0  # the plot on the right, the averages chips in the space on its left
		ag.notes_right = true  # clear of the averages chips (bottom-left)
		ag.custom_minimum_size = Vector2(820, 400)
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(ag)
		Hoot.register_anchor("reveal_audiogram", ag)
	_fx = UiKit.full_rect()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	# the shape title lands as a stamp in the chart's empty top-right corner; the averages sit
	# bottom-left (both areas are empty on a sloping audiogram)
	_title = UiKit.label("", 40, Palette.CORAL, 700, 14, Palette.INK)
	_title.visible = false
	add_child(_title)
	_chips = VBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chips)


## (coroutine) Draw the audiogram in, play the melody, ski the slope, land the title.
func run(p_results: Dictionary) -> void:
	results = p_results
	Juice.bounce_in(_card, 0.45)
	await get_tree().create_timer(0.5).timeout
	if ag == null:
		return
	ag.show_results(results, true)
	_play_melody()
	await ag.draw_finished
	await get_tree().create_timer(0.4).timeout
	await _ski_down()
	var shape: StringName = _ear_info("right").get("shape", &"unknown")
	var title: String = ClinicRules.SHAPE_TITLES.get(shape, "Gus's hearing")
	_title.text = title.replace(" high-frequency", "\nhigh-frequency") + "!"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.reset_size()
	var cr := _card.get_global_rect()
	var spot := _empty_title_rect(cr)
	_title.position = spot.get_center() - _title.size * 0.5
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = -0.07
	_title.visible = true
	Juice.pop(_title, 1.8, 0.45)
	_chips.position = Vector2(cr.position.x + 90.0, cr.end.y - 134.0)
	Sfx.play(&"fanfare")
	Events.screen_shake.emit(0.2, 0.15)
	for ear: String in ["right", "left"]:
		var info := _ear_info(ear)
		if info.is_empty():
			continue
		var pta := float(info.get("pta", NAN))
		if is_nan(pta):
			continue
		var chip := UiKit.panel(Palette.ear_tint(ear), Palette.ear_color(ear), 14)
		chip.add_child(UiKit.label(_degree_line(ear, pta), 15, Palette.INK, 600))
		_chips.add_child(chip)
		Juice.bounce_in(chip, 0.4)
	await get_tree().create_timer(0.8).timeout


## "Right: mild at 500-2k (avg 28), sloping to moderate at 4-8k": the low/mid average and
## where the high pitches end up, so the chip never says "normal" about a sloping ear.
func _degree_line(ear: String, pta: float) -> String:
	var line := "%s: %s at 500-2k (avg %d)" % [ear.capitalize(), ClinicRules.degree_name(pta), int(round(pta))]
	var freqs: Dictionary = _ear_info(ear).get("freqs", {})
	var hi := 0.0
	var n := 0
	for f: int in [4000, 8000]:
		if freqs.has(f):
			hi += float((freqs[f] as Dictionary).get("stored_db", 0))
			n += 1
	if n > 0:
		hi /= n
		var hi_name := ClinicRules.degree_name(hi)
		if hi_name != ClinicRules.degree_name(pta):
			line += "\n%s %s at 4-8k" % ["sloping to" if hi > pta else "rising to", hi_name]
	return line


## The emptiest place for the shape stamp: a grid search over the plot for the title-sized
## rect that covers the fewest plotted points / line samples (and never the average chips),
## then the one farthest from the data. Works for any audiogram shape, not only Gus's.
func _empty_title_rect(card_rect: Rect2) -> Rect2:
	var ts := _title.size
	var plot := ag.get_region_global_rect(250, 8000, -10, 120).grow_individual(-6.0, -6.0, -6.0, -22.0)
	var chips := Rect2(card_rect.position + Vector2(80.0, card_rect.size.y - 140.0), Vector2(370.0, 140.0))
	# (E12) a true-proportion plot leaves room on its left: the stamp goes there, above the chips
	var side := Rect2(card_rect.position.x + 30.0, card_rect.position.y + 30.0,
		ag.plot_rect().position.x + ag.global_position.x - card_rect.position.x - 80.0, chips.position.y - card_rect.position.y - 40.0)
	if side.size.x >= ts.x and side.size.y >= ts.y:
		return Rect2(side.get_center() - ts * 0.5, ts)
	var samples: Array[Vector2] = []
	for ear: String in ["right", "left"]:
		var fl: Dictionary = _ear_info(ear).get("freqs", {})
		var fs: Array[int] = []
		for f: Variant in fl:
			fs.append(int(f))
		fs.sort()
		var prev := Vector2.INF
		for f: int in fs:
			var pt := ag.get_point_global_position(ear, f)
			samples.append(pt)
			if prev != Vector2.INF:
				for k in range(1, 8):
					samples.append(prev.lerp(pt, k / 8.0))
			prev = pt
	var best := Rect2(Vector2(card_rect.end.x - ts.x - 60.0, card_rect.position.y + 50.0), ts)
	var best_hits := 1 << 30
	var best_clear := -1.0
	var nx := 14
	var ny := 10
	for iy in ny:
		for ix in nx:
			var c := Vector2(lerpf(plot.position.x + ts.x * 0.5, plot.end.x - ts.x * 0.5, ix / float(nx - 1)),
				lerpf(plot.position.y + ts.y * 0.5, plot.end.y - ts.y * 0.5, iy / float(ny - 1)))
			var r := Rect2(c - ts * 0.5, ts)
			if r.intersects(chips):
				continue
			var hits := 0
			var clear := INF
			for sp: Vector2 in samples:
				if r.grow(14.0).has_point(sp):
					hits += 1
				clear = minf(clear, c.distance_to(sp))
			if hits < best_hits or (hits == best_hits and clear > best_clear):
				best_hits = hits
				best_clear = clear
				best = r
	return best


func _ear_info(ear: String) -> Dictionary:
	return (results.get("ears", {}) as Dictionary).get(ear, {})


func _right_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var freqs: Array = (_ear_info("right").get("freqs", {}) as Dictionary).keys()
	freqs.sort()
	for f: int in freqs:
		out.append(ag.get_point_global_position("right", f))
	return out


func _play_melody() -> void:
	var freqs: Array = (_ear_info("right").get("freqs", {}) as Dictionary).keys()
	freqs.sort()
	var n := freqs.size()
	if n == 0:
		return
	var step := 1.6 / float(maxi(1, n))
	for i in n:
		var f: int = freqs[i]
		var db := int((_ear_info("right")["freqs"] as Dictionary)[f].get("stored_db", 0))
		var vol := -3.0 - 0.14 * float(clampi(db, 0, 100))
		get_tree().create_timer(step * i).timeout.connect(func() -> void:
			Sfx.play_note(Sfx.audiogram_note_hz(f), vol)
			_hop = float(i))
	get_tree().create_timer(step * n + 0.3).timeout.connect(func() -> void: _hop = -1.0)


func _ski_down() -> void:
	var pts := _right_points()
	if pts.size() < 2:
		return
	Sfx.play(&"whoosh", 0.9, -6.0)
	if Game.cli.has("shots"):
		get_tree().create_timer(1.3).timeout.connect(func() -> void: Events.screenshot_requested.emit("story_reveal_ski"))
	var t := create_tween()
	t.tween_property(self, "_ski", 1.0, 2.0).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	Sfx.play(&"boing", 1.3, -8.0)
	await get_tree().create_timer(0.3).timeout
	_ski = -1.0


func _process(delta: float) -> void:
	_t += delta
	for s: Dictionary in _snow:
		s["p"] = (s["p"] as Vector2) + (s["v"] as Vector2) * delta
		s["v"] = (s["v"] as Vector2) + Vector2(0, 160) * delta
		s["life"] = float(s["life"]) - delta
	_snow = _snow.filter(func(s: Dictionary) -> bool: return float(s["life"]) > 0.0)
	_fx.queue_redraw()


func _point_along(pts: Array[Vector2], k: float) -> Array:
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var d := k * total
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if d <= seg or i == pts.size() - 2:
			var u := clampf(d / maxf(seg, 0.001), 0.0, 1.0)
			return [pts[i].lerp(pts[i + 1], u), (pts[i + 1] - pts[i]).normalized()]
		d -= seg
	return [pts[pts.size() - 1], Vector2.RIGHT]


func _draw_fx() -> void:
	if ag == null:
		return
	if _hop >= 0.0:
		var pts := _right_points()
		var i := int(_hop)
		if i < pts.size():
			var bounce := absf(sin(_t * 12.0)) * 18.0
			_fx.draw_circle(pts[i] + Vector2(0, -26 - bounce), 9.0, Palette.INK)
			_fx.draw_circle(pts[i] + Vector2(0, -26 - bounce), 6.0, Palette.SUNNY)
	for s: Dictionary in _snow:
		_fx.draw_circle(s["p"], 3.0, Color(1, 1, 1, clampf(float(s["life"]) * 2.0, 0.0, 1.0)))
		_fx.draw_arc(s["p"], 3.5, 0, TAU, 8, Color(Palette.SKY.darkened(0.2), 0.6), 1.0)
	if _ski >= 0.0:
		var pts2 := _right_points()
		if pts2.size() < 2:
			return
		var pd := _point_along(pts2, _ski)
		var p: Vector2 = pd[0]
		var dir: Vector2 = pd[1]
		var ang := dir.angle()
		if Game.rng.randf() < 0.7:
			_snow.append({"p": p + Vector2(-8, 0), "v": Vector2(Game.rng.randf_range(-90, -20), Game.rng.randf_range(-120, -40)), "life": 0.6})
		_fx.draw_set_transform(p, ang, Vector2.ONE)
		# skis
		_fx.draw_line(Vector2(-26, 2), Vector2(24, 2), Palette.INK, 6.0, true)
		_fx.draw_line(Vector2(-24, 2), Vector2(22, 2), Palette.CORAL, 3.0, true)
		_fx.draw_arc(Vector2(24, -4), 6.0, -PI * 0.1, PI * 0.5, 6, Palette.INK, 4.0, true)
		# bean body leaning into the slope
		_fx.draw_circle(Vector2(0, -20), 15.0, Palette.INK)
		_fx.draw_circle(Vector2(0, -20), 12.0, Color("#3a9d96"))
		_fx.draw_circle(Vector2(4, -40), 11.0, Palette.INK)
		_fx.draw_circle(Vector2(4, -40), 8.5, Palette.SKIN)
		_fx.draw_line(Vector2(-6, -30), Vector2(-26, -36), Palette.CORAL, 5.0, true)  # scarf
		_fx.draw_line(Vector2(10, -24), Vector2(22, -10), Palette.INK, 3.0, true)     # pole
		_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
