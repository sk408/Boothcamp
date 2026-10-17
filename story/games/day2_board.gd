extends Control
## Day 2 board (v3): Bonnie's audiogram with air AND bone. The chart stamps in, then the
## air-bone gap lights up as a toll bridge (air pays a toll at the middle ear, bone skips it),
## and at the end the big "REFERRED TO ENT" stamp lands when the player presses it.
## Story-internal:
##   var b := Day2Board.new(); hud.add_game(b); await b.run_reveal(results)
##   await b.show_gap()            # the bridge, with the gap in dB at each bone frequency
##   await b.run_stamp()           # beat referral_stamp: click / Enter, solver = stamp it
## Anchors: "reveal_audiogram", "abg_bridge", "referral_stamp".

signal _stamped

const UiKit := preload("res://story/ui_kit.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"
const GAP_FREQS: Array[int] = [500, 1000, 2000, 4000]
const BRIDGE := Color("#ff9f1c")

var results: Dictionary = {}
var ag: Audiogram
var stamped := false
var _card: PanelContainer
var _fx: Control
var _title: Label
var _gap := -1.0             # 0..1 the bridge drawing in, -1 hidden
var _stamp_btn: Button
var _stamp_t := -1.0
var _accepting := false
var _t := 0.0
var _hints: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var head := VBoxContainer.new()
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.offset_top = 18
	head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(head)
	var h := UiKit.label("BONNIE'S AUDIOGRAM", 34, Palette.INK, 700)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(h)
	var legend := Control.new()
	legend.custom_minimum_size = Vector2(860, 30)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.draw.connect(_draw_legend.bind(legend))
	head.add_child(legend)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_hints)
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
	var xf := ag.get_global_transform_with_canvas()
	var spot := xf * Vector2((ag.freq_to_x(1000) + ag.freq_to_x(4000)) * 0.5, ag.db_to_y(88.0))
	_title.position = spot - _title.size * 0.5
	_title.pivot_offset = _title.size * 0.5
	_title.rotation = -0.06
	_title.visible = true
	Juice.pop(_title, 1.7, 0.45)
	Sfx.play(&"fanfare")
	Events.screen_shake.emit(0.2, 0.15)
	await get_tree().create_timer(0.6).timeout


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
	_fx.queue_redraw()


func _ear_info(ear: String) -> Dictionary:
	return (results.get("ears", {}) as Dictionary).get(ear, {})


## [freq, air point, bone point] in canvas coordinates for each gap frequency of the right ear.
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


func _draw_legend(c: Control) -> void:
	var f := UiKit.font(600)
	var x := 20.0
	var items := [["right", &"ac", "Right air"], ["right", &"ac_masked", "masked"], ["right", &"bc_masked", "Right bone, masked"], ["left", &"ac", "Left air"]]
	for it: Array in items:
		UiDraw.audiogram_symbol(c, Vector2(x + 10.0, 15.0), String(it[0]), it[1], 14.0, 3.0)
		c.draw_string(f, Vector2(x + 26.0, 21.0), String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)
		x += 44.0 + f.get_string_size(String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	c.draw_string(f, Vector2(x + 6.0, 21.0), "Bone marks are never joined.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)


func _to_fx(p: Vector2) -> Vector2:
	return _fx.get_global_transform_with_canvas().affine_inverse() * p


func _draw_fx() -> void:
	if ag == null:
		return
	if _gap >= 0.0:
		_draw_bridge()
	if _stamp_t >= 0.0:
		_draw_stamp()


func _draw_bridge() -> void:
	var pts := _gap_points()
	if pts.is_empty():
		return
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
	if top.size() >= 2:
		var poly := top.duplicate()
		for i in range(bot.size() - 1, -1, -1):
			poly.append(bot[i])
		_fx.draw_colored_polygon(poly, Color(BRIDGE, 0.22))
		# the bridge deck along the bone marks (thin, so the [ marks stay readable), posts down to air
		_fx.draw_polyline(top, Color(Palette.INK, 0.8), 5.0, true)
		_fx.draw_polyline(top, BRIDGE, 2.5, true)
	var f := UiKit.font(700)
	for i in mini(n, top.size()):
		var a := top[i]
		var b := bot[i]
		_fx.draw_dashed_line(a + Vector2(0, 14), b - Vector2(0, 14), Color(Palette.INK, 0.55), 3.0, 8.0)
		var gap := int(pts[i][3])
		var s := "%d dB" % gap
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var mid := (a + b) * 0.5 + Vector2(14, 6)
		UiDraw.rounded_rect(_fx, Rect2(mid - Vector2(6, 18), Vector2(w + 12, 24)), Palette.PAPER, 8, 2, BRIDGE.darkened(0.3))
		_fx.draw_string(f, mid, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)
	# the toll booth at the left end: air pays here, bone drives straight past
	if k >= 0.99 and n > 0:
		var p := _to_fx(pts[0][1]) + Vector2(-46, 22)
		UiDraw.rounded_rect(_fx, Rect2(p, Vector2(40, 34)), Color("#fff1a8"), 6, 3, Palette.INK)
		_fx.draw_string(f, p + Vector2(4, 22), "TOLL", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK)
		var arm := p + Vector2(40, 30)
		var lift := 0.25 * sin(_t * 3.0)
		var tip := arm + Vector2(cos(-0.15 + lift), sin(-0.15 + lift)) * 46.0
		_fx.draw_line(arm, tip, Palette.INK, 7.0, true)
		_fx.draw_line(arm, tip, Palette.CORAL, 3.5, true)


func _draw_stamp() -> void:
	var cr := _card.get_global_rect()
	var c := _to_fx(cr.get_center() + Vector2(120, 40))
	var land := clampf(_stamp_t / 0.18, 0.0, 1.0)
	var sc := lerpf(2.6, 1.0, land * land)
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
