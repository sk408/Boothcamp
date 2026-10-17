extends Control
## Otoscopy I-spy: a peek down Gus's ear canal through the otoscope.
## Move the light (mouse, or arrow keys) and click / press Enter on anything odd.
## Hidden: a sesame seed (since 1987). Healthy landmarks give tiny lessons when clicked.
## Story-internal. Usage:
##   var g := Otoscopy.new(); hud.add_game(g); await g.run_find()   # beat otoscopy_find
##   await g.sneeze_out(); await g.show_left_clear()
## Anchor: "otoscope_seed".

signal _found_sig

const UiKit := preload("res://story/ui_kit.gd")
const VIEW_R := 245.0
const LIGHT_R := 92.0
const KEY_SPEED := 430.0

const SPOT_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 view_center = vec2(640.0, 340.0);
uniform float view_radius = 245.0;
uniform vec2 light_pos = vec2(640.0, 340.0);
uniform float light_radius = 92.0;
uniform float ambient = 0.3;
void fragment() {
	vec2 p = UV * rect_size;
	float dv = distance(p, view_center);
	float dl = distance(p, light_pos);
	float lit = 1.0 - smoothstep(light_radius * 0.55, light_radius, dl);
	float inside = 1.0 - smoothstep(view_radius - 3.0, view_radius, dv);
	float dark = mix(1.0, 1.0 - max(lit, ambient), inside);
	COLOR = vec4(0.06, 0.04, 0.09, dark * 0.96);
}
"""

var _found_label: Label
var ear := "right"
var found := false
var view_center := Vector2(640, 336)
var light := Vector2(640, 336)
var seed_offset := Vector2(138, 62)
var seed_visible := true
var _canal: Control
var _dark: ColorRect
var _mat: ShaderMaterial
var _seed_anchor: Control
var _slide_x := 0.0
var _rim: Control
var _caption: Label
var _hints: HBoxContainer
var _t := 0.0
var _start_clock := 0.0
var _accepting := false
var _wrong_clicks := 0
var _hint_given := false
var _examined: Dictionary = {}
var _seed_fly := 0.0
var _shake := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_canal = UiKit.full_rect()
	_canal.draw.connect(_draw_canal)
	add_child(_canal)
	_dark = ColorRect.new()
	_dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SPOT_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_dark.material = _mat
	add_child(_dark)
	var rim := UiKit.full_rect()
	_rim = rim
	rim.draw.connect(func() -> void:
		rim.draw_arc(view_center, VIEW_R + 10.0, 0, TAU, 72, Color("#3d3554"), 22.0, true)
		rim.draw_arc(view_center, VIEW_R + 22.0, 0, TAU, 72, Palette.INK, 6.0, true)
		rim.draw_arc(view_center, VIEW_R + 1.0, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.25), 6.0, true))
	add_child(rim)
	_seed_anchor = Control.new()
	_seed_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seed_anchor.size = Vector2(44, 44)
	add_child(_seed_anchor)
	Hoot.register_anchor("otoscope_seed", _seed_anchor)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 14
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(top)
	_caption = UiKit.label("", 30, Palette.PAPER, 700, 10, Palette.INK)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_caption)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hints)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	view_center = Vector2(size.x * 0.5 + _slide_x, size.y * 0.47)
	if not _accepting:
		light = view_center + Vector2(-60, -40)
	_seed_anchor.position = view_center + seed_offset - _seed_anchor.size * 0.5


## (coroutine) The I-spy. Emits awaiting_input(otoscopy_find). Returns when the seed is found.
func run_find() -> void:
	ear = "right"
	found = false
	seed_visible = true
	_caption.text = "Peek inside Gus's RIGHT ear. Spot anything odd?"
	_set_hints(true)
	_start_clock = Game.clock
	_accepting = true
	Juice.bounce_in(_caption, 0.4)
	Events.awaiting_input.emit(&"otoscopy_find", {"target": "otoscope_seed"}, _solve)
	while not found:
		await _found_sig
	_accepting = false


## Slide the whole view sideways (offset from centre, px) so a choice list can sit beside it.
func slide_aside(offset_x: float, dur := 0.35) -> void:
	if _found_label != null and is_instance_valid(_found_label):
		_found_label.queue_free()  # it would float over the choice list
	_found_label = null
	var t := create_tween()
	t.tween_method(_set_slide, _slide_x, offset_x, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _set_slide(x: float) -> void:
	var dx := x - _slide_x
	_slide_x = x
	view_center.x += dx
	light.x += dx
	_seed_anchor.position = view_center + seed_offset - _seed_anchor.size * 0.5
	if _canal:
		_canal.queue_redraw()
	if _rim:
		_rim.queue_redraw()


func elapsed() -> float:
	return Game.clock - _start_clock


func wrong_clicks() -> int:
	return _wrong_clicks


## (coroutine) Gus sneezes; the seed shoots out of the canal.
func sneeze_out() -> void:
	_caption.text = "Ah... ah... AH-CHOO!"
	Juice.pop(_caption, 1.4, 0.3)
	_shake = 0.6
	Sfx.play(&"whoosh", 0.8, -4.0)
	Sfx.play(&"pop", 0.7, -4.0)
	var t := create_tween()
	t.tween_property(self, "_seed_fly", 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	seed_visible = false
	_canal.queue_redraw()
	_caption.text = "Canal clear. Eardrum pearly and shiny!"
	Juice.pop(_caption, 1.2, 0.3)
	await get_tree().create_timer(0.6).timeout


## (coroutine) A quick look at the left ear: all clear, no input needed.
func show_left_clear() -> void:
	ear = "left"
	seed_visible = false
	_seed_fly = 0.0
	_set_hints(false)
	light = view_center
	_caption.text = "Left ear: all clear!"
	Juice.pop(_caption, 1.2, 0.3)
	Sfx.play(&"ding", 1.2, -6.0)
	var t := create_tween()
	t.tween_property(self, "light", view_center + Vector2(40, 20), 0.6).set_trans(Tween.TRANS_SINE)
	t.tween_property(self, "light", view_center + Vector2(-50, -20), 0.6).set_trans(Tween.TRANS_SINE)
	await t.finished
	await get_tree().create_timer(0.5).timeout


func _solve() -> void:
	if found:
		return
	light = view_center + seed_offset
	_examine(view_center + seed_offset)


func _set_hints(on: bool) -> void:
	for c in _hints.get_children():
		c.queue_free()
	if on and UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_row(["Move the light:", "mouse or", ["Left", "Right", "Up", "Down"], "  Look closer:", "click or", ["Enter"]], 16, Palette.PAPER))


func _gui_input(event: InputEvent) -> void:
	if not _accepting:
		return
	if event is InputEventMouseMotion:
		light = _clamp_light((event as InputEventMouseMotion).position)
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := (event as InputEventMouseButton).position
		light = _clamp_light(p)
		_examine(p)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting:
		return
	if (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue")) and not event.is_echo():
		_examine(light)
		get_viewport().set_input_as_handled()


func _clamp_light(p: Vector2) -> Vector2:
	var d := p - view_center
	if d.length() > VIEW_R - 30.0:
		d = d.normalized() * (VIEW_R - 30.0)
	return view_center + d


func _examine(p: Vector2) -> void:
	if found:
		return
	var local := p - view_center
	if local.distance_to(seed_offset) < 34.0:
		found = true
		_accepting = false
		Sfx.play(&"sparkle")
		_found_label = Juice.float_text(self, "A sesame seed?!", p + Vector2(0, -50), Palette.SUNNY, 40)
		_caption.text = "Found it: a sesame seed!"
		Juice.pop(_caption, 1.3, 0.3)
		_set_hints(false)
		Hoot.dismiss_current()
		_found_sig.emit()
		return
	var what := ""
	var key := ""
	if local.distance_to(Vector2(-6, 6)) < 95.0:
		key = "drum"
		what = "Eardrum: pearly grey and shiny. Healthy!"
		if local.distance_to(Vector2(30, 52)) < 30.0:
			key = "cone"
			what = "Cone of light points toward the nose: 5 o'clock in a right ear."
	elif local.length() > 175.0:
		key = "hairs"
		what = "Canal hairs: totally normal. Gus calls them 'the welcome mat'."
	else:
		key = "wall"
		what = "Just healthy canal skin. Keep looking!"
	_examined[key] = true
	_wrong_clicks += 1
	Sfx.play(&"blip", 1.2, -8.0)
	Juice.float_text(self, what, p + Vector2(0, -40), Palette.PAPER, 22)
	if not _hint_given and (_wrong_clicks >= 3 or elapsed() > 14.0):
		_hint_given = true
		Hoot.say("Psst: check the canal wall, near the eardrum. Low and to the right.", Hoot.HIGH, "otoscope_seed")


func _process(delta: float) -> void:
	_t += delta
	if _accepting:
		var dir := Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
		if dir != Vector2.ZERO:
			light = _clamp_light(light + dir * KEY_SPEED * delta)
		if not _hint_given and elapsed() > 14.0:
			_hint_given = true
			Hoot.say("Psst: check the canal wall, near the eardrum. Low and to the right.", Hoot.HIGH, "otoscope_seed")
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 10.0 * _shake if not bool(Game.settings.get("reduced_motion", false)) else Vector2.ZERO
	_mat.set_shader_parameter("rect_size", size)
	_mat.set_shader_parameter("view_center", view_center + off)
	_mat.set_shader_parameter("view_radius", VIEW_R)
	_mat.set_shader_parameter("light_pos", light + off)
	_mat.set_shader_parameter("light_radius", LIGHT_R if _accepting else VIEW_R * 1.6)
	_canal.position = off
	_canal.queue_redraw()


func _draw_canal() -> void:
	var c := view_center
	var flip := -1.0 if ear == "left" else 1.0
	# canal walls: rings from the entrance (edge) to the deep canal
	var rings := [[VIEW_R, Color("#f2b2a2")], [VIEW_R * 0.86, Color("#eda393")], [VIEW_R * 0.72, Color("#e79586")], [VIEW_R * 0.58, Color("#df8a7d")]]
	for r: Array in rings:
		_canal.draw_circle(c + Vector2(6 * flip, 4), float(r[0]), r[1])
	# soft highlights on the canal wall
	for i in 5:
		var a := 0.6 + i * 1.1
		_canal.draw_arc(c, VIEW_R * (0.66 + 0.05 * i), a, a + 0.5, 10, Color(1, 1, 1, 0.12), 6.0, true)
	# little canal hairs at the entrance
	for i in 22:
		var a := TAU * i / 22.0 + 0.13
		var p0 := c + Vector2(cos(a), sin(a)) * (VIEW_R - 6.0)
		var p1 := c + Vector2(cos(a + 0.08), sin(a + 0.08)) * (VIEW_R - 34.0 - 8.0 * (i % 3))
		_canal.draw_line(p0, p1, Color("#7a4a3a"), 2.0, true)
	# eardrum: pearly grey oval, tilted
	var drum := c + Vector2(-6 * flip, 6)
	var pts := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		pts.append(drum + Vector2(cos(a) * 112.0, sin(a) * 98.0).rotated(-0.25 * flip))
	_canal.draw_colored_polygon(pts, Color("#c9c6cf"))
	pts.append(pts[0])
	_canal.draw_polyline(pts, Color("#a59fb0"), 4.0, true)
	_canal.draw_circle(drum + Vector2(-18 * flip, -16), 46.0, Color(1, 1, 1, 0.12))
	# malleus handle (umbo in the middle) and the cone of light (5 o'clock right, 7 o'clock left)
	# the handle runs from the top, tipped toward the nose, down to the umbo at the centre
	_canal.draw_line(drum + Vector2(22 * flip, -70), drum + Vector2(-2 * flip, 2), Color("#f4ece0"), 10.0, true)
	_canal.draw_circle(drum + Vector2(-2 * flip, 2), 6.0, Color("#f4ece0"))
	var cone := PackedVector2Array([drum + Vector2(8 * flip, 8), drum + Vector2(56 * flip, 74), drum + Vector2(26 * flip, 84)])
	_canal.draw_colored_polygon(cone, Color(1, 1, 0.94, 0.85))
	# the sesame seed, lodged on the canal wall
	if seed_visible:
		var sp := c + seed_offset
		var s := 1.0 + _seed_fly * 4.0
		sp = sp.lerp(c + Vector2(260, -230), _seed_fly * 0.6)
		var seed_pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			var rr := 1.0 - 0.35 * maxf(0.0, cos(a))
			seed_pts.append(sp + Vector2(cos(a) * 15.0 * rr, sin(a) * 9.0).rotated(0.6 + _seed_fly * 6.0) * s)
		_canal.draw_colored_polygon(seed_pts, Color("#f6e7b8"))
		seed_pts.append(seed_pts[0])
		_canal.draw_polyline(seed_pts, Color("#b89a60"), 2.5, true)
		_canal.draw_line(sp + Vector2(-6, -2).rotated(0.6) * s, sp + Vector2(6, 2).rotated(0.6) * s, Color(1, 1, 1, 0.6), 2.0, true)
