extends CanvasLayer
## PauseMenu (CanvasLayer 90, process ALWAYS): pause + options overlay. Instanced once by
## main.gd. Toggle with the "pause" action (Esc / P), the little corner button, or open() from
## the title screen's Options button. Group "pause_menu": open() / close() / is_open().
## Holds the key-style toggle: "Up = LOUDER (default)" (setting "otosuite") or
## "Up = SOFTER (swapped)" (setting "affinity"). Player-facing text never names a vendor.
## Keyboard: Up/Down pick a row, Left/Right adjust, Enter toggles / presses, Esc closes. It opens
## on the Resume button, and Space does nothing here (a held beep key must never flip a setting).
## (v4) Replays of Hoot's movies (story/explainers/, CONTRACTS.md §3.4): one "Watch <title>" button
## per movie of the current chapter (in a level) or every movie (on the title's Options). The movie
## plays over the paused game (the player is our child, so it inherits PROCESS_MODE_ALWAYS); the menu
## comes back when it ends. Hidden while a movie is already playing.

const UiKit := preload("res://story/ui_kit.gd")
const Movies := preload("res://story/explainers/movies.gd")
const EXPLAINER_SCENE := "res://story/explainers/explainer_player.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const TEXT_SPEEDS: Array[float] = [0.6, 1.0, 1.6, 3.0]
const TEXT_SPEED_NAMES: Array[String] = ["Slow", "Normal", "Fast", "Zoom"]

var _root: Control
var _card: PanelContainer
var _title: Label
var _rows_box: VBoxContainer
var _rows: Array[Dictionary] = []
var _hl := 0
var _open := false
var _corner: Button
var _quit_title_btn: Button
var _hint_box: HBoxContainer
var _in_audiometry := false
var _opened_t := 0
var _btns: Array[Button] = []
var _btn_hl := 0
var _movie_btns: Dictionary = {}    # (v4) movie id -> its "Watch ..." button
var _movie_playing := false         # (v4) a replay is on screen (the menu waits, hidden)


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_build()
	_root.visible = false
	Events.scene_changed.connect(func(_p: String, _n: Node) -> void: _update_corner())
	Events.phase_changed.connect(func(p: StringName, _i: Dictionary) -> void:
		_in_audiometry = p == &"audiometry"
		_update_corner())
	Events.scene_changed.connect(func(_p: String, _n: Node) -> void: _in_audiometry = false)
	Events.key_style_changed.connect(func(_s: String) -> void: _refresh())
	_update_corner()


func _unhandled_input(event: InputEvent) -> void:
	if _movie_playing:
		return   # the movie has its own keys (Esc skips it); the menu comes back after
	if event.is_action_pressed(&"pause") and not event.is_echo():
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
		return
	if not _open or not event.is_pressed() or event.is_echo():
		return
	if Time.get_ticks_msec() - _opened_t < 250:
		get_viewport().set_input_as_handled()
		return  # the key that opened the menu (or a stray tap right after) does nothing
	var k := event as InputEventKey
	var enter := k != null and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER)
	if event.is_action_pressed(&"ui_down"):
		_set_hl((_hl + 1) % _rows.size())
	elif event.is_action_pressed(&"ui_up"):
		_set_hl((_hl - 1 + _rows.size()) % _rows.size())
	elif event.is_action_pressed(&"ui_left"):
		_adjust(-1)
	elif event.is_action_pressed(&"ui_right"):
		_adjust(1)
	elif enter:
		_activate()
	elif k != null and k.keycode == KEY_SPACE:
		pass  # swallowed: Space is the beep key, never a menu key
	else:
		return
	get_viewport().set_input_as_handled()


func open() -> void:
	if _open:
		return
	_open = true
	_root.visible = true
	var on_title := _on_title()
	_title.text = "Options" if on_title else "Paused"
	_quit_title_btn.visible = not on_title
	_update_movie_buttons()
	_refresh()
	_btn_hl = 0
	_set_hl(_rows.size() - 1, false)
	_opened_t = Time.get_ticks_msec()
	get_tree().paused = true
	Juice.bounce_in(_card, 0.35)
	Sfx.play(&"pop", 1.0, -6.0)
	_corner.visible = false
	Events.pause_toggled.emit(true)


func close() -> void:
	if not _open or _movie_playing:
		return
	_open = false
	_root.visible = false
	get_tree().paused = false
	Sfx.play(&"click", 0.9, -6.0)
	_update_corner()
	Events.pause_toggled.emit(false)


func is_open() -> bool:
	return _open


## (v4) The movies this menu offers: the current chapter's in a level, all of them on the title.
func movie_ids_here() -> Array[String]:
	if _on_title():
		return Movies.ids()
	if get_tree().get_first_node_in_group("explainer_player") != null:
		return [] as Array[String]   # one movie at a time (P during the day-start movie)
	return Movies.for_chapter(Game.current_chapter_id)


func _update_movie_buttons() -> void:
	var here := movie_ids_here()
	for id: String in _movie_btns:
		(_movie_btns[id] as Button).visible = here.has(id) and not _movie_playing


## (v4, coroutine) Replay a movie from the menu. Returns the player's result.
func play_movie(id: String) -> Dictionary:
	if _movie_playing or not Movies.has(id):
		return {}
	_movie_playing = true
	_root.visible = false
	_corner.visible = false
	var player: Node = (load(EXPLAINER_SCENE) as PackedScene).instantiate()
	add_child(player)
	var r: Dictionary = await player.call("play", id, "title" if _on_title() else "pause")
	player.queue_free()
	_movie_playing = false
	if _open:
		_root.visible = true
		_update_movie_buttons()
		_refresh()
		_opened_t = Time.get_ticks_msec()   # the key that ended the movie does nothing here
		Juice.bounce_in(_card, 0.3)
	_update_corner()
	return r


func _on_title() -> bool:
	return get_tree().get_first_node_in_group("title_screen") != null


func _update_corner() -> void:
	if _corner == null:
		return
	# hidden on the title (it has Options) and while the AudiOtron is up (it has its own
	# pause button; Esc / P still pause there). Stage.audiometer also covers the standalone
	# --scene demo, where no story phase is announced.
	var ao_up := Stage.audiometer != null and is_instance_valid(Stage.audiometer)
	_corner.visible = not _open and not _on_title() and not _in_audiometry and not ao_up and not _movie_playing \
		and get_tree().get_first_node_in_group("explainer_player") == null


## The AudiOtron can appear without a phase or scene change (standalone demo, tests), so
## keep the corner button in sync every frame; it is one cheap check.
func _process(_delta: float) -> void:
	_update_corner()


# ---------------------------------------------------------------- rows

func _refresh() -> void:
	for r: Dictionary in _rows:
		var kind: String = r["kind"]
		var c: Control = r["control"]
		match kind:
			"style":
				var aff := Game.get_key_style() == "affinity"
				(c as Button).text = "Arrow keys: Up = SOFTER (swapped)" if aff else "Arrow keys: Up = LOUDER (default)"
			"slider":
				(c as HSlider).set_value_no_signal(float(Game.settings.get(r["key"], 0.8)))
			"toggle":
				(c as CheckButton).set_pressed_no_signal(bool(Game.settings.get(r["key"], false)))
			"speed":
				(c as Button).text = TEXT_SPEED_NAMES[_speed_index()]
	for c in _hint_box.get_children():
		c.queue_free()
	if UiKit.show_key_hints():
		_hint_box.add_child(UiKit.hint_row([["Up", "Down"], "choose", ["Left", "Right"], "adjust", ["Enter"], "press", [Game.key_label(&"pause")], "close"], 14))


func _speed_index() -> int:
	var cur := float(Game.settings.get("text_speed", 1.0))
	var best := 1
	for i in TEXT_SPEEDS.size():
		if absf(TEXT_SPEEDS[i] - cur) < absf(TEXT_SPEEDS[best] - cur):
			best = i
	return best


func _set_hl(i: int, sound: bool = true) -> void:
	_hl = i
	for j in _rows.size():
		var row: PanelContainer = _rows[j]["row"]
		var on := j == i
		row.add_theme_stylebox_override("panel", UiKit.style(Color("#fff1b8") if on else Color(1, 1, 1, 0), Palette.INK if on else Color(0, 0, 0, 0), 14, 3 if on else 0, 0, 10))
	_style_buttons()
	if sound:
		Sfx.play(&"blip", 1.4, -12.0)


## The bottom row: the keyboard-picked button wears the accent style.
func _style_buttons() -> void:
	var on_row := not _rows.is_empty() and String(_rows[_hl]["kind"]) == "buttons"
	var visible_btns := _visible_buttons()
	for b: Button in _btns:
		var on := on_row and visible_btns.find(b) == _btn_hl
		b.theme_type_variation = &"AccentButton" if on else &""


func _visible_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for b: Button in _btns:
		if b.visible:
			out.append(b)
	return out


func _adjust(dir: int) -> void:
	var r: Dictionary = _rows[_hl]
	match String(r["kind"]):
		"slider":
			var sl: HSlider = r["control"]
			sl.value = clampf(sl.value + 0.1 * dir, 0.0, 1.0)
			Game.save_game()
		"toggle":
			_activate()
		"style":
			(r["control"] as Button).pressed.emit()
		"speed":
			_cycle_speed(dir)
		"buttons":
			var vb := _visible_buttons()
			_btn_hl = clampi(_btn_hl + dir, 0, vb.size() - 1)
			_style_buttons()
			Sfx.play(&"blip", 1.4, -12.0)


func _activate() -> void:
	var r: Dictionary = _rows[_hl]
	match String(r["kind"]):
		"style":
			pass  # Left / Right or a click flips the arrows (Enter alone never does)
		"toggle":
			var cb: CheckButton = r["control"]
			cb.button_pressed = not cb.button_pressed
		"speed":
			_cycle_speed(1)
		"buttons":
			var vb := _visible_buttons()
			if _btn_hl >= 0 and _btn_hl < vb.size():
				vb[_btn_hl].pressed.emit()
			else:
				close()


func _cycle_speed(dir: int) -> void:
	var i := (_speed_index() + dir + TEXT_SPEEDS.size()) % TEXT_SPEEDS.size()
	Game.set_setting("text_speed", TEXT_SPEEDS[i])
	Sfx.play(&"click")
	_refresh()


func _add_row(kind: String, label_text: String, control: Control, key: String = "") -> void:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	if label_text != "":
		var l := UiKit.label(label_text, 19, Palette.INK, 500)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(l)
	else:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(control)
	_rows_box.add_child(row)
	var idx := _rows.size()
	row.mouse_entered.connect(func() -> void:
		if _hl != idx:
			_set_hl(idx, false))
	_rows.append({"kind": kind, "row": row, "control": control, "key": key})


func _section(text: String) -> void:
	var l := UiKit.label(text, 14, Palette.INK_SOFT, 700)
	_rows_box.add_child(l)


func _build() -> void:
	_root = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	_card = UiKit.panel(Palette.PAPER, Palette.INK, 28)
	_card.custom_minimum_size = Vector2(980, 0)
	center.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)
	_title = UiKit.label("Paused", 34, Palette.INK, 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	# two columns so everything fits a 720p window: controls + sound | comfort
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var bottom := VBoxContainer.new()
	v.add_child(bottom)
	_rows_box = left

	_section("CONTROLS")
	var style_btn := UiKit.button("", &"", Vector2(0, 42))
	style_btn.pressed.connect(func() -> void:
		Game.set_key_style("otosuite" if Game.get_key_style() == "affinity" else "affinity")
		Sfx.play(&"click")
		_refresh())
	_add_row("style", "", style_btn)
	_section("SOUND (beeps are always capped quiet)")
	for pair: Array in [["master_volume", "Volume"], ["tone_volume", "Beep volume"], ["sfx_volume", "Effects and voices"], ["music_volume", "Music"]]:
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.custom_minimum_size = Vector2(200, 30)
		s.focus_mode = Control.FOCUS_NONE
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var key: String = pair[0]
		s.value = float(Game.settings.get(key, 0.8))
		s.value_changed.connect(func(val: float) -> void:
			# apply live; the save file is written when the drag ends (not on every step)
			Game.settings[key] = val
			Game.apply_settings()
			if key != "tone_volume":
				Sfx.play(&"blip", 1.0, -8.0))
		s.drag_ended.connect(func(_changed: bool) -> void: Game.save_game())
		_add_row("slider", pair[1], s, key)
	_rows_box = right
	_section("COMFORT")
	var speed := UiKit.button("Normal", &"", Vector2(160, 36))
	speed.pressed.connect(func() -> void: _cycle_speed(1))
	_add_row("speed", "Text speed", speed)
	for pair: Array in [["quick_visit", "Quick visit (Hoot runs the repeats)"], ["show_key_hints", "Show key hints"], ["reduced_motion", "Reduced motion"], ["no_startle", "Gentle gags (no startle)"], ["fullscreen", "Fullscreen (F11)"]]:
		var cb := CheckButton.new()
		cb.focus_mode = Control.FOCUS_NONE
		var key: String = pair[0]
		cb.button_pressed = bool(Game.settings.get(key, key == "quick_visit"))
		cb.toggled.connect(func(on: bool) -> void:
			Game.set_setting(key, on)
			Sfx.play(&"click")
			_refresh())
		_add_row("toggle", pair[1], cb, key)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var resume := UiKit.button("Resume", &"AccentButton", Vector2(180, 52))
	resume.pressed.connect(close)
	row.add_child(resume)
	_btns.append(resume)
	for id: String in Movies.ids():
		var mb := UiKit.button("Watch %s" % Movies.title(id), &"", Vector2(300, 52))
		mb.tooltip_text = "%s (about %d s; Esc skips it)" % [Movies.title(id), int(Movies.total_s(id))]
		mb.pressed.connect(func() -> void: play_movie(id))
		mb.visible = false
		row.add_child(mb)
		_btns.append(mb)
		_movie_btns[id] = mb
	_quit_title_btn = UiKit.button("Quit to title", &"", Vector2(180, 52))
	_quit_title_btn.pressed.connect(func() -> void:
		close()
		Events.goto_scene.emit(TITLE_SCENE))
	row.add_child(_quit_title_btn)
	_btns.append(_quit_title_btn)
	_rows_box = bottom
	_add_row("buttons", "", row)
	_hint_box = HBoxContainer.new()
	_hint_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_hint_box)

	# small always-on pause button for mouse players (hidden on the title screen)
	_corner = UiKit.button("II", &"GhostButton", Vector2(46, 46))
	_corner.tooltip_text = "Pause / options"
	_corner.anchor_left = 1.0
	_corner.anchor_right = 1.0
	_corner.offset_left = -58
	_corner.offset_right = -12
	_corner.offset_top = 12
	_corner.offset_bottom = 58
	_corner.add_theme_font_override("font", UiKit.font(700))
	_corner.add_theme_font_size_override("font_size", 20)
	_corner.pressed.connect(open)
	add_child(_corner)
