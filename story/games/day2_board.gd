extends Control
## Day 2 board (v3): Bonnie's audiogram with air AND bone. The chart stamps in, then the
## air-bone gap lights up as a toll bridge: a plank road runs along the bone marks (bone drives
## straight past, a little bone car proves it), stone pillars drop to the air marks with the toll
## in dB on each one, and a toll booth with a bobbing barrier sits at the air end (air pays at the
## middle ear). Later: the Carhart notch callout, the type-of-loss badge, and the big
## "REFERRED TO ENT" stamp when the player presses it.
## Story-internal:
##   var b := Day2Board.new(); hud.add_game(b); await b.run_reveal(results)
##   await b.show_gap()            # the bridge, with the gap in dB at each bone frequency
##   b.set_compact(true)           # shrink to the top so the dialogue choices can sit below it
##   b.show_carhart(); b.show_type("Conductive loss")
##   await b.run_stamp()           # beat referral_stamp: click / Enter, solver = stamp it
## Anchors: "reveal_audiogram", "abg_bridge", "referral_stamp".

signal _stamped

const UiKit := preload("res://story/ui_kit.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"
const GAP_FREQS: Array[int] = [500, 1000, 2000, 4000]
const BRIDGE := Color("#ff9f1c")
const PLANK := Color("#c8874b")
const STONE := Color("#e6dccb")
const COMPACT_SCALE := 0.72

var results: Dictionary = {}
var ag: Audiogram
var stamped := false
var compact := false
var _card: PanelContainer
var _head: VBoxContainer
var _fx: Control
var _title: Label
var _title_spot := Vector2.ZERO     # where the gap title sits, in audiogram coordinates
var _gap := -1.0             # 0..1 the bridge drawing in, -1 hidden
var _carhart := -1.0         # 0.. the Carhart callout, -1 hidden
var _type_text := ""
var _type_t := -1.0
var _stamp_btn: Button
var _stamp_t := -1.0
var _accepting := false
var _t := 0.0
var _hints: HBoxContainer
var _card_home := Vector2.ZERO


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_head = VBoxContainer.new()
	_head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_head.offset_top = 18
	_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_head)
	var h := UiKit.label("BONNIE'S AUDIOGRAM", 34, Palette.INK, 700)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_child(h)
	var legend := Control.new()
	legend.custom_minimum_size = Vector2(900, 30)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.draw.connect(_draw_legend.bind(legend))
	_head.add_child(legend)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_head.add_child(_hints)
	_card = UiKit.panel(Palette.PAPER, Palette.INK, 22)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -430
	_card.offset_right = 430
	_card.offset_top = -262
	_card.offset_bottom = 170
	add_child(_card)
	if ResourceLoader.exists(AUDIOGRAM_SCENE):
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Audiogram
		ag.ear = "both"
		ag.custom_minimum_size = Vector2(820, 400)
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(ag)
		Hoot.register_anchor("reveal_audiogram", ag)
	_fx = UiKit.full_rect()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_title = UiKit.label("", 38, Palette.CORAL, 700, 14, Palette.INK)
	_title.visible = false
	add_child(_title)
	_stamp_btn = UiKit.button("  STAMP: REFER TO ENT  ", &"AccentButton", Vector2(0, 64))
	_stamp_btn.visible = false
	_stamp_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamp_btn.offset_top = -96
	_stamp_btn.offset_bottom = -32
	_stamp_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp_btn.pressed.connect(_stamp)
	add_child(_stamp_btn)
	Hoot.register_anchor("referral_stamp", _stamp_btn)
	var bridge_anchor := Control.new()
	bridge_anchor.name = "BridgeAnchor"
	bridge_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bridge_anchor)
	Hoot.register_anchor("abg_bridge", bridge_anchor)


func _exit_tree() -> void:
	for a: String in ["reveal_audiogram", "abg_bridge", "referral_stamp"]:
		Hoot.unregister_anchor(a)


## (coroutine) Stamp every mark in (air, bone, masked), low to high pitch.
func run_reveal(p_results: Dictionary) -> void:
	results = p_results
	Juice.bounce_in(_card, 0.45)
	await get_tree().create_timer(0.5).timeout
	if ag == null:
		return
	ag.show_results(results, true)
	await ag.draw_finished
	await get_tree().create_timer(0.3).timeout


## (coroutine) The toll bridge: the band between bone (top) and air (bottom) on the right ear.
func show_gap() -> void:
	if ag == null or _gap_points().is_empty():
		return
	_place_bridge_anchor()
	Sfx.play(&"whoosh", 0.8, -6.0)
	var t := create_tween()
	t.tween_property(self, "_gap", 1.0, 1.2).from(0.0).set_trans(Tween.TRANS_SINE)
	await t.finished
	var avg := _avg_gap()
	_title.text = "AIR-BONE GAP: ~%d dB" % avg
	_title.reset_size()
	# the empty lower part of the chart (the severe-profound rows)
	_title_spot = Vector2((ag.freq_to_x(1000) + ag.freq_to_x(4000)) * 0.5, ag.db_to_y(90.0))
	_title.pivot_offset = _title.size * 0.5
	_place_title()
	_title.visible = true
	Juice.pop(_title, 1.7, 0.45)
	Sfx.play(&"fanfare")
	Events.screen_shake.emit(0.2, 0.15)
	await get_tree().create_timer(0.6).timeout


## Shrink the board to the top of the screen (dialogue choices go below it), or restore it.
func set_compact(on: bool) -> void:
	if compact == on:
		return
	compact = on
	if _card_home == Vector2.ZERO:
		_card_home = _card.position
	var target_scale := Vector2.ONE * (COMPACT_SCALE if on else 1.0)
	# the card scales around its pivot, so aim its visible top-left corner, not its position
	var visible_at := Vector2((size.x - _card.size.x * COMPACT_SCALE) * 0.5, 12.0)
	var target_pos := visible_at - _card.pivot_offset * (1.0 - COMPACT_SCALE) if on else _card_home
	var t := create_tween().set_parallel(true)
	t.tween_property(_card, "scale", target_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "position", target_pos, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(_head, "modulate:a", 0.0 if on else 1.0, 0.2)
	t.tween_property(_title, "scale", target_scale, 0.35)


## The Carhart notch: a ring around the 2 kHz bone mark and a label.
func show_carhart() -> void:
	_carhart = 0.0
	Sfx.play(&"ding", 0.9, -6.0)


## A badge naming the type of loss ("Conductive loss"), next to the chart.
func show_type(text: String) -> void:
	_type_text = text.to_upper()
	_type_t = 0.0
	Sfx.play(&"stamp", 1.4, -10.0)


## (coroutine) The referral stamp: waits for a click / Enter. Beat referral_stamp (solver stamps).
func run_stamp() -> void:
	_stamp_btn.visible = true
	_stamp_btn.add_theme_font_size_override("font_size", 26)
	Juice.bounce_in(_stamp_btn, 0.4)
	for c in _hints.get_children():
		c.queue_free()
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_panel(["Click the stamp   or", ["Enter"]], 16))
	_accepting = true
	Events.awaiting_input.emit(&"referral_stamp", {"targets": ["referral_stamp"]}, _stamp)
	while not stamped:
		await _stamped
	await get_tree().create_timer(1.0).timeout


func _stamp() -> void:
	if stamped:
		return
	stamped = true
	_accepting = false
	_stamp_btn.visible = false
	_stamp_t = 0.0
	var tt := _title.create_tween()
	tt.tween_property(_title, "modulate:a", 0.0, 0.15)
	Sfx.play(&"stamp", 0.7, 0.0)
	Events.screen_shake.emit(0.6, 0.3)
	_stamped.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		_stamp()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if _stamp_t >= 0.0:
		_stamp_t += delta
	if _carhart >= 0.0:
		_carhart += delta
	if _type_t >= 0.0:
		_type_t += delta
	if _title.visible:
		_place_title()
	_fx.queue_redraw()


func _place_title() -> void:
	if ag == null:
		return
	var spot := ag.get_global_transform_with_canvas() * _title_spot
	_title.position = spot - _title.size * 0.5
	_title.rotation = -0.06


func _ear_info(ear: String) -> Dictionary:
	return (results.get("ears", {}) as Dictionary).get(ear, {})


## [freq, air point, bone point, gap] in canvas coordinates for each gap frequency of the right ear.
func _gap_points() -> Array:
	var out: Array = []
	if ag == null:
		return out
	var air := ClinicRules.best_thresholds(results, "right", false)
	var bone := ClinicRules.best_thresholds(results, "right", true)
	var xf := ag.get_global_transform_with_canvas()
	for f: int in GAP_FREQS:
		if air.has(f) and bone.has(f):
			out.append([f, xf * Vector2(ag.freq_to_x(f), ag.db_to_y(float(air[f]))), xf * Vector2(ag.freq_to_x(f), ag.db_to_y(float(bone[f]))), int(air[f]) - int(bone[f])])
	return out


func _avg_gap() -> int:
	var pts := _gap_points()
	var s := 0
	for p: Array in pts:
		s += int(p[3])
	return int(round(float(s) / maxf(1.0, pts.size()) / 5.0)) * 5


func _place_bridge_anchor() -> void:
	var pts := _gap_points()
	var a: Control = get_node("BridgeAnchor")
	if pts.is_empty():
		return
	var top := Vector2(INF, INF)
	var bot := Vector2(-INF, -INF)
	for p: Array in pts:
		for v: Vector2 in [p[1], p[2]]:
			top = Vector2(minf(top.x, v.x), minf(top.y, v.y))
			bot = Vector2(maxf(bot.x, v.x), maxf(bot.y, v.y))
	a.global_position = top
	a.size = bot - top


## Which symbols the chart shows, so the legend only lists those.
func _has_sheet(test: String) -> bool:
	var ear := _ear_info("right")
	if test == "ac":
		return not (ear.get("freqs", {}) as Dictionary).is_empty()
	return not (ear.get(test, {}) as Dictionary).is_empty()


func _draw_legend(c: Control) -> void:
	var f := UiKit.font(600)
	var items: Array = [["right", &"ac", "Right air"]]
	if results.is_empty() or _has_sheet("ac_masked"):
		items.append(["right", &"ac_masked", "masked air"])
	if not results.is_empty() and _has_sheet("bc") and not _has_sheet("bc_masked"):
		items.append(["right", &"bc", "Right bone"])
	if results.is_empty() or _has_sheet("bc_masked"):
		items.append(["right", &"bc_masked", "Right bone, masked"])
	items.append(["left", &"ac", "Left air"])
	var total := 0.0
	for it: Array in items:
		total += 44.0 + f.get_string_size(String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var note := "Bone marks are never joined."
	total += f.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 6.0
	var x := maxf(0.0, (c.size.x - total) * 0.5)
	for it: Array in items:
		UiDraw.audiogram_symbol(c, Vector2(x + 10.0, 15.0), String(it[0]), it[1], 14.0, 3.0)
		c.draw_string(f, Vector2(x + 26.0, 21.0), String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)
		x += 44.0 + f.get_string_size(String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(f, Vector2(x + 6.0, 21.0), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)


func _to_fx(p: Vector2) -> Vector2:
	return _fx.get_global_transform_with_canvas().affine_inverse() * p


func _draw_fx() -> void:
	if ag == null:
		return
	if _gap >= 0.0:
		_draw_bridge()
	if _carhart >= 0.0:
		_draw_carhart()
	if _type_t >= 0.0:
		_draw_type()
	if _stamp_t >= 0.0:
		_draw_stamp()


func _sc() -> float:
	return _card.scale.x


func _draw_bridge() -> void:
	var pts := _gap_points()
	if pts.is_empty():
		return
	var s := _sc()
	var n := pts.size()
	var k := clampf(_gap, 0.0, 1.0)
	var upto := k * (n - 1) if n > 1 else 1.0
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in n:
		if float(i) > upto + 0.001 and n > 1:
			var u := upto - floorf(upto)
			var j := int(floorf(upto))
			top.append(_to_fx((pts[j][2] as Vector2).lerp(pts[j + 1][2], u)))
			bot.append(_to_fx((pts[j][1] as Vector2).lerp(pts[j + 1][1], u)))
			break
		top.append(_to_fx(pts[i][2]))
		bot.append(_to_fx(pts[i][1]))
	var lift := 17.0 * s     # the deck rides just above the bone marks, so the [ stay readable
	var deck := PackedVector2Array()
	for p in top:
		deck.append(p - Vector2(0, lift))
	if top.size() >= 2:
		# the gap itself, the "river" the bridge spans
		var poly := top.duplicate()
		for i in range(bot.size() - 1, -1, -1):
			poly.append(bot[i])
		_fx.draw_colored_polygon(poly, Color(BRIDGE, 0.2))
	var f := UiKit.font(700)
	# stone pillars from the deck down to the air marks, the toll in dB hanging on each
	for i in mini(n, top.size()):
		var a := deck[i]
		var b := bot[i] - Vector2(0, 14.0 * s)
		if b.y - a.y < 8.0:
			continue
		var w := 9.0 * s
		var pr := Rect2(Vector2(a.x - w * 0.5, a.y), Vector2(w, b.y - a.y))
		_fx.draw_rect(pr, STONE)
		_fx.draw_rect(pr, Color(Palette.INK, 0.75), false, 2.0)
		var gap := int(pts[i][3])
		var txt := "%d dB" % gap
		var fs := int(16.0 * s + 0.5)
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mid := (a + b) * 0.5 + Vector2(10.0 * s, 6.0 * s)
		var sway := 2.0 * sin(_t * 2.0 + i)
		_fx.draw_line(Vector2(a.x, mid.y - 18.0 * s), mid + Vector2(4.0 * s, -18.0 * s + sway), Color(Palette.INK, 0.6), 2.0, true)
		UiDraw.rounded_rect(_fx, Rect2(mid + Vector2(-6.0 * s, -18.0 * s + sway), Vector2(tw + 12.0 * s, 24.0 * s)), Palette.PAPER, 8, 2, BRIDGE.darkened(0.3))
		_fx.draw_string(f, mid + Vector2(0, sway), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	if deck.size() >= 2:
		# the plank road and its railing
		_fx.draw_polyline(deck, Palette.INK, 11.0 * s, true)
		_fx.draw_polyline(deck, PLANK, 7.0 * s, true)
		for i in deck.size() - 1:
			var p0 := deck[i]
			var p1 := deck[i + 1]
			var steps := maxi(2, int(p0.distance_to(p1) / (14.0 * s)))
			for j in steps:
				var p := p0.lerp(p1, float(j) / steps)
				_fx.draw_line(p + Vector2(0, -3.0 * s), p + Vector2(0, 3.0 * s), PLANK.darkened(0.35), 2.0, true)
		var rail := PackedVector2Array()
		for p in deck:
			rail.append(p - Vector2(0, 11.0 * s))
		_fx.draw_polyline(rail, Color(Palette.INK, 0.7), 2.5, true)
		for p in deck:
			_fx.draw_line(p, p - Vector2(0, 11.0 * s), Color(Palette.INK, 0.7), 2.5, true)
	if k < 0.99 or n == 0:
		return
	# the toll booth at the air end of the first pillar: air pays here
	var base := _to_fx(pts[0][1]) + Vector2(-58.0 * s, -6.0 * s)
	_draw_toll_booth(base, s)
	# a little bone car drives straight across the deck, no toll
	if deck.size() >= 2:
		var lap := fmod(_t * 0.22, 1.0)
		var seg := lap * (deck.size() - 1)
		var j := mini(int(seg), deck.size() - 2)
		var cp := deck[j].lerp(deck[j + 1], seg - j)
		_draw_bone_car(cp - Vector2(0, 6.0 * s), s, (deck[j + 1] - deck[j]).angle())


func _draw_toll_booth(base: Vector2, s: float) -> void:
	var f := UiKit.font(700)
	var body := Rect2(base + Vector2(-20.0, -40.0) * s, Vector2(40.0, 40.0) * s)
	UiDraw.rounded_rect(_fx, body, Color("#fff1a8"), 5, 3, Palette.INK)
	UiDraw.rounded_rect(_fx, Rect2(base + Vector2(-13.0, -33.0) * s, Vector2(26.0, 14.0) * s), Palette.SKY, 3, 2, Palette.INK)
	var roof := PackedVector2Array([base + Vector2(-27.0, -40.0) * s, base + Vector2(0.0, -58.0) * s, base + Vector2(27.0, -40.0) * s])
	_fx.draw_colored_polygon(roof, Palette.CORAL)
	_fx.draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), Palette.INK, 3.0, true)
	var fs := int(11.0 * s + 0.5)
	var tw := f.get_string_size("TOLL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_fx.draw_string(f, base + Vector2(-tw * 0.5, -6.0 * s), "TOLL", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	# the barrier arm, striped, bobbing up and down
	var pivot := base + Vector2(20.0, -14.0) * s
	var ang := -0.2 - 0.35 * (0.5 + 0.5 * sin(_t * 2.4))
	var tip := pivot + Vector2(cos(ang), sin(ang)) * 44.0 * s
	_fx.draw_line(pivot, tip, Palette.INK, 8.0 * s, true)
	for i in 4:
		var a := pivot.lerp(tip, i / 4.0)
		var b := pivot.lerp(tip, (i + 0.5) / 4.0)
		_fx.draw_line(a, b, Palette.CORAL if i % 2 == 0 else Palette.PAPER, 5.0 * s, true)
	_fx.draw_circle(pivot, 4.0 * s, Palette.INK)


## A dog-bone shaped car on two wheels (bone conduction skips the toll).
func _draw_bone_car(at: Vector2, s: float, angle: float) -> void:
	_fx.draw_set_transform(at, angle, Vector2.ONE * s)
	var bone := Color("#fffbf2")
	for x: float in [-14.0, 14.0]:
		_fx.draw_circle(Vector2(x, 6), 4.5, Palette.INK)
		_fx.draw_circle(Vector2(x, 6), 2.0, Palette.INK_SOFT)
	_fx.draw_rect(Rect2(Vector2(-12, -6), Vector2(24, 8)), Palette.INK)
	for p: Vector2 in [Vector2(-14, -5), Vector2(-14, 1), Vector2(14, -5), Vector2(14, 1)]:
		_fx.draw_circle(p, 5.5, Palette.INK)
	_fx.draw_rect(Rect2(Vector2(-12, -4.5), Vector2(24, 5)), bone)
	for p: Vector2 in [Vector2(-14, -5), Vector2(-14, 1), Vector2(14, -5), Vector2(14, 1)]:
		_fx.draw_circle(p, 4.0, bone)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_carhart() -> void:
	var bone := ClinicRules.best_thresholds(results, "right", true)
	if not bone.has(2000) or ag == null:
		return
	var s := _sc()
	var xf := ag.get_global_transform_with_canvas()
	var p := _to_fx(xf * Vector2(ag.freq_to_x(2000), ag.db_to_y(float(bone[2000]))))
	var grow := clampf(_carhart / 0.3, 0.0, 1.0)
	var r := (22.0 + 3.0 * sin(_t * 5.0)) * s * grow
	_fx.draw_arc(p + Vector2(-8.0 * s, 0), r, 0.0, TAU, 28, Color(Palette.PLUM, 0.9), 4.0, true)
	if grow < 1.0:
		return
	var f := UiKit.font(700)
	var fs := int(17.0 * s + 0.5)
	var txt := "Carhart notch"
	var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	# the label sits in the empty rows under the air line, a little right of 2 kHz
	var air := ClinicRules.best_thresholds(results, "right", false)
	var below := float(air.get(2000, float(bone[2000]) + 30.0)) + 12.0
	var lp := _to_fx(xf * Vector2(ag.freq_to_x(2000), ag.db_to_y(below))) + Vector2(18.0, 30.0) * s
	_fx.draw_line(p + Vector2(4.0, r), lp + Vector2(4.0 * s, -20.0 * s), Palette.PLUM, 3.0, true)
	UiDraw.rounded_rect(_fx, Rect2(lp + Vector2(-8.0 * s, -20.0 * s), Vector2(tw + 16.0 * s, 28.0 * s)), Palette.PLUM, 10, 2, Palette.INK)
	_fx.draw_string(f, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PAPER)


func _draw_type() -> void:
	if _type_text == "":
		return
	var cr := _card.get_global_rect()
	var s := _sc()
	var f := UiKit.font(700)
	var fs := int(22.0 * s + 0.5)
	var tw := f.get_string_size(_type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pop := 1.0 + 0.4 * maxf(0.0, 1.0 - _type_t / 0.25)
	# top-left of the plot: the quiet, low-pitch corner where nothing else is drawn
	var at := _to_fx(cr.position + Vector2(62.0, 66.0) * s)
	_fx.draw_set_transform(at, -0.06, Vector2.ONE * pop)
	var box := Rect2(Vector2(-4.0 * s, -26.0 * s), Vector2(tw + 24.0 * s, 36.0 * s))
	UiDraw.rounded_rect(_fx, box, Palette.MINT, 12, 3, Palette.INK)
	_fx.draw_string(f, Vector2(8.0 * s, 0), _type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stamp() -> void:
	var cr := _card.get_global_rect()
	var c := _to_fx(cr.get_center() + Vector2(120, 40) * _sc())
	var land := clampf(_stamp_t / 0.18, 0.0, 1.0)
	var sc := lerpf(2.6, 1.0, land * land) * _sc()
	var alpha := clampf(_stamp_t / 0.12, 0.0, 1.0)
	_fx.draw_set_transform(c, -0.18, Vector2.ONE * sc)
	var col := Color(Palette.RIGHT_RED, 0.9 * alpha)
	var f := UiKit.font(700)
	var s1 := "REFERRED"
	var s2 := "TO ENT"
	var w1 := f.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x
	var w2 := f.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44).x
	var box := Rect2(Vector2(-w1 * 0.5 - 24, -64), Vector2(w1 + 48, 124))
	_fx.draw_rect(box, Color(Palette.PAPER, 0.75 * alpha))
	_fx.draw_rect(box, col, false, 7.0)
	_fx.draw_rect(box.grow(-9.0), col, false, 2.5)
	_fx.draw_string(f, Vector2(-w1 * 0.5, -6), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 56, col)
	_fx.draw_string(f, Vector2(-w2 * 0.5, 44), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, col)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
