extends CanvasLayer
## HootBubble (CanvasLayer 80): Professor Hoot's tip bubble + ghost hand. Instanced once by
## main.gd as an overlay. Display only: the Hoot autoload owns the queue (CONTRACTS.md §8).
## Listens to Events.hoot_tip_shown / hoot_tip_dismissed. Clicking the bubble calls
## Hoot.dismiss(id). Never blocks input elsewhere (only the bubble itself takes clicks).
## Placement: Hoot.bubble_rect_hint if a screen reserved one, else top-right at y = 176.

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const Voice := preload("res://story/voice.gd")

const DEFAULT_Y := 176.0
const CHARS_PER_SECOND := 55.0

var _root: Control
var _panel: PanelContainer
var _text: Label
var _avatar: Control
var _close: Control
var _hand: Control
var _voice: Node
var _tip: Dictionary = {}
var _t := 0.0
var _hand_t := 0.0
var _shown := 0.0
var _typing := false
var _placed_hint := Rect2(-1, -1, -1, -1)
var _beak_open := false
var _last_syl := 0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_voice = Voice.new()
	add_child(_voice)
	_build()
	_panel.visible = false
	Events.hoot_tip_shown.connect(_on_shown)
	Events.hoot_tip_dismissed.connect(_on_dismissed)
	Events.hoot_mastered.connect(_on_mastered)


func _on_shown(tip: Dictionary) -> void:
	_tip = tip
	_text.text = String(tip.get("text", ""))
	_text.visible_characters = 0
	_shown = 0.0
	_last_syl = 0
	_typing = true
	_panel.visible = true
	_close.visible = float(tip.get("duration", -1.0)) == 0.0
	_place()
	Juice.bounce_in(_panel, 0.4)
	Sfx.play(&"chirp", randf_range(1.2, 1.5), -10.0)
	_hand_t = 0.0


func _on_dismissed(id: int) -> void:
	if _tip.is_empty() or int(_tip.get("id", -1)) != id:
		return
	_tip = {}
	_typing = false
	var t := _panel.create_tween()
	t.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.1)
	t.parallel().tween_property(_panel, "modulate:a", 0.0, 0.1)
	t.tween_callback(func() -> void:
		if _tip.is_empty():
			_panel.visible = false
		_panel.scale = Vector2.ONE
		_panel.modulate.a = 1.0)


func _on_mastered(skill: StringName) -> void:
	Sfx.play(&"sparkle", 1.0, -6.0)
	var names := {&"earphones": "Earphone pro!", &"bracketing": "Bracket boss!"}
	var msg: String = names.get(skill, "Skill mastered!")
	var vp := _root.get_viewport_rect().size
	Juice.float_text(_root, msg, Vector2(vp.x * 0.5, 120.0), Palette.MINT, 34)


## Default spot: top-right below the HUD. Screens may reserve one with Hoot.set_bubble_hint().
func _place() -> void:
	var hint: Rect2 = Hoot.bubble_rect_hint
	_placed_hint = hint
	var vp := _root.get_viewport_rect().size
	if hint.size.x > 0.0:
		_text.custom_minimum_size.x = clampf(hint.size.x - 110.0, 140.0, 420.0)
		_panel.reset_size()
		_panel.position = hint.position
	else:
		_text.custom_minimum_size.x = 300.0
		_panel.reset_size()
		_panel.position = Vector2(vp.x - _panel.size.x - 16.0, DEFAULT_Y)


func _process(delta: float) -> void:
	_t += delta
	_hand_t += delta
	if _tip.is_empty():
		if _hand.visible:
			_hand.queue_redraw()
		return
	if Hoot.bubble_rect_hint != _placed_hint:
		_place()  # a screen reserved (or released) a spot after this tip appeared
	if _typing:
		_shown += delta * CHARS_PER_SECOND * maxf(0.25, float(Game.settings.get("text_speed", 1.0)))
		var n := mini(int(_shown), _text.get_total_character_count())
		_text.visible_characters = n
		if n / 4 > _last_syl:
			_last_syl = n / 4
			_beak_open = not _beak_open
			if _last_syl % 2 == 0:
				_voice.call("syllable", "Hoot", _last_syl, -4.0)
		if n >= _text.get_total_character_count():
			_typing = false
			_beak_open = false
			_text.visible_characters = -1
	_hand.queue_redraw()
	_avatar.queue_redraw()


func _build() -> void:
	_root = UiKit.full_rect()
	add_child(_root)
	_hand = UiKit.full_rect()
	_hand.draw.connect(_draw_hand)
	_root.add_child(_hand)
	_panel = PanelContainer.new()
	var sb := UiKit.style(Palette.PAPER, Palette.HOOT_BROWN, 22, 4, 8, 12)
	sb.content_margin_right = 16
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and not _tip.is_empty():
			get_viewport().set_input_as_handled()
			if _typing:
				_typing = false
				_text.visible_characters = -1
				return
			Hoot.dismiss(int(_tip["id"])))
	_root.add_child(_panel)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(h)
	_avatar = Control.new()
	_avatar.custom_minimum_size = Vector2(70, 70)
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_avatar.draw.connect(_draw_owl)
	h.add_child(_avatar)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var who := UiKit.label("Professor Hoot", 15, Palette.HOOT_BROWN, 700)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	_close = UiKit.label("click to close", 12, Palette.INK_SOFT, 500)
	top.add_child(_close)
	_text = UiKit.label("", 20, Palette.INK, 500)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(300, 0)
	v.add_child(_text)


func _draw_owl() -> void:
	var blink := fmod(_t, 3.3) < 0.12
	var bob := -absf(sin(_t * 9.0)) * 3.0 if _typing else sin(_t * 2.0) * 1.5
	Portraits.draw(_avatar, "Hoot", Vector2(35, 37 + bob), 31.0, _beak_open, blink)


func _draw_hand() -> void:
	if _tip.is_empty() or String(_tip.get("target", "")) == "" or not _panel.visible:
		return
	var r := Hoot.anchor_screen_rect(String(_tip["target"]))
	if r.size == Vector2.ZERO and r.position == Vector2.ZERO:
		return
	var target := r.get_center()
	# a short hop in from just above-right of the control, then mostly tapping on it
	var start := target + Vector2(90, -110)
	var cycle := fmod(_hand_t, 1.6) / 1.6
	var travel := clampf(cycle / 0.35, 0.0, 1.0)
	var pos := start.lerp(target, ease(travel, -2.0))
	var tap := 0.0
	if cycle > 0.35:
		tap = sin((cycle - 0.35) / 0.65 * PI * 3.0) * 0.5 + 0.5
	var col := Color(1, 1, 1, 0.9)
	var outline := Color(Palette.INK, 0.75)
	var s := 1.3 * (1.0 - 0.15 * tap)
	if tap > 0.3:
		_hand.draw_arc(target, 20 + 14 * tap, 0, TAU, 28, Color(Palette.TONE_CYAN, 0.9 * (1.0 - tap) + 0.1), 4)
	# a cartoon glove: palm, three fingers curled, pointing finger at pos
	var palm := pos + Vector2(18, 30) * s
	_hand.draw_circle(palm, 19 * s, outline)
	_hand.draw_line(pos, pos + Vector2(8, 22) * s, outline, 14 * s, true)
	_hand.draw_circle(pos, 7 * s, outline)
	_hand.draw_circle(palm, 16 * s, col)
	_hand.draw_line(pos, pos + Vector2(8, 22) * s, col, 10 * s, true)
	_hand.draw_circle(pos, 5 * s, col)
	for k in 3:
		_hand.draw_arc(palm + Vector2(10, -6 + k * 8) * s, 5 * s, -PI * 0.5, PI * 0.5, 8, outline, 2.0, true)
