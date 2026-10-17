extends Control
## TitleScreen: the safety notice, then the title menu over a live 3D clinic backdrop.
## Phases: &"disclaimer" (beat disclaimer_ok) then &"title" (beat title_start).
## Play -> the next chapter (v3: Game.start_chapter(Game.next_chapter_id()): Day 1 on a fresh
## save, then the first open day not yet done). Days -> the day picker (phase / beat
## &"chapter_select"): one card per chapter, locked days say how to open them, and the career-fair
## toggle "Unlock all days (demo)". Options opens the pause menu. Quit quits.
## Keyboard: Up/Down + Enter/Space. Mouse: click. The notice shows once per session; the
## footer "This is a game, not a hearing test." is always on screen.

const UiKit := preload("res://story/ui_kit.gd")
const LEVEL_SCENE := "res://story/level_gus.tscn"
const CLINIC_SCENE := "res://world/clinic.tscn"

static var _notice_seen_this_session := false
## A title left alone this long (a booth / kiosk display) shows the safety notice again.
const IDLE_NOTICE_S := 90.0

var _clinic: Node
var _logo: Control
var _menu_card: PanelContainer
var _buttons: Array[Button] = []
var _hl := 0
var _notice_layer: Control
var _notice: PanelContainer
var _state := &"notice"
var _t := 0.0
var _font: Font
var _starting := false
var _idle := 0.0
var _reset_armed := false
# v3: the day picker
var _days_card: PanelContainer
var _menu_buttons: Array[Button] = []
var _day_buttons: Array[Button] = []
var _days_note: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("title_screen")
	_font = UiKit.font(700)
	if ResourceLoader.exists(CLINIC_SCENE):
		_clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
		add_child(_clinic)
		if _clinic.has_method("set_title_mode"):
			_clinic.call("set_title_mode", true)
	_build()
	Sfx.music_start()
	if _notice_seen_this_session:
		_notice_layer.visible = false
		_show_title.call_deferred()
	else:
		_show_disclaimer.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _state == &"menu" and not get_tree().paused:
		_idle += delta
		if _idle > IDLE_NOTICE_S:
			_idle = 0.0
			_notice_layer.modulate.a = 1.0
			_show_disclaimer()
	_logo.queue_redraw()
	queue_redraw()


func _draw() -> void:
	# soft cream wash on the left so the logo and menu read over the 3D clinic
	var w := size.x
	var h := size.y
	var cols := PackedColorArray([Color(Palette.CREAM, 0.94), Color(Palette.CREAM, 0.0), Color(Palette.CREAM, 0.0), Color(Palette.CREAM, 0.94)])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.62, 0), Vector2(w * 0.62, h), Vector2(0, h)]), cols)
	draw_rect(Rect2(0, h - 46, w, 46), Color(Palette.INK, 0.78))


func _show_disclaimer() -> void:
	_state = &"notice"
	Events.phase_changed.emit(&"disclaimer", {})
	_menu_card.visible = false
	_notice_layer.visible = true
	Juice.bounce_in(_notice, 0.5)
	Events.awaiting_input.emit(&"disclaimer_ok", {}, _on_notice_ok)


func _on_notice_ok() -> void:
	if _state != &"notice":
		return
	_state = &"busy"
	Sfx.play(&"ding")
	_notice_seen_this_session = true
	Game.progress["seen_disclaimer"] = true
	Game.save_game()
	Events.input_resolved.emit(&"disclaimer_ok")
	var t := create_tween()
	t.tween_property(_notice_layer, "modulate:a", 0.0, 0.2)
	await t.finished
	_notice_layer.visible = false
	_show_title()


func _show_title() -> void:
	_state = &"menu"
	Events.phase_changed.emit(&"title", {})
	_menu_card.visible = true
	Juice.bounce_in(_menu_card, 0.5)
	_set_hl(0, false)
	Events.awaiting_input.emit(&"title_start", {}, _on_start)


func _on_start() -> void:
	_start_chapter(Game.next_chapter_id(), &"title_start")


## (v3) Start a chapter (falls back to Day 1's scene if it is locked or missing).
func _start_chapter(id: String, beat: StringName) -> void:
	if _starting:
		return
	_starting = true
	_state = &"busy"
	Sfx.play(&"fanfare")
	if not _buttons.is_empty():
		Juice.pop(_buttons[clampi(_hl, 0, _buttons.size() - 1)], 1.15, 0.25)
	Events.input_resolved.emit(beat)
	if not Game.start_chapter(id):
		Events.goto_scene.emit(LEVEL_SCENE)


# ---------------------------------------------------------------- v3: day picker

func _on_days() -> void:
	if _state != &"menu":
		return
	_state = &"days"
	Events.input_resolved.emit(&"title_start")
	Events.phase_changed.emit(&"chapter_select", {"unlocked": Game.unlocked_chapter_ids()})
	_menu_card.visible = false
	_refresh_days()
	_days_card.visible = true
	Juice.bounce_in(_days_card, 0.4)
	_buttons = _day_buttons
	_set_hl(0, false)
	Sfx.play(&"whoosh", 1.2, -8.0)
	Events.awaiting_input.emit(&"chapter_select", {"chapters": Game.unlocked_chapter_ids(), "next": Game.next_chapter_id()},
		func() -> void: _start_chapter(Game.next_chapter_id(), &"chapter_select"))


func _days_back() -> void:
	if _state != &"days":
		return
	Events.input_resolved.emit(&"chapter_select")
	_days_card.visible = false
	_buttons = _menu_buttons
	_show_title()


func _pick_day(id: String, b: Button) -> void:
	if _state != &"days":
		return
	if not Game.is_chapter_unlocked(id):
		Juice.shake(b, 6.0, 0.25)
		Sfx.play(&"error", 1.0, -8.0)
		_days_note.text = "Finish the day before to open this one, or switch on \"Unlock all days\"."
		return
	_start_chapter(id, &"chapter_select")


func _toggle_unlock_all() -> void:
	Game.set_setting("unlock_all_days", not bool(Game.settings.get("unlock_all_days", false)))
	Sfx.play(&"click", 1.1, -4.0)
	_refresh_days()
	_set_hl(_hl, false)


func _refresh_days() -> void:
	var pats: Dictionary = Game.progress.get("patients", {})
	for b: Button in _day_buttons:
		var id := String(b.get_meta("chapter", ""))
		if id == "":
			continue
		var ch := Game.chapter(id)
		var label := String(ch["title"])
		if not Game.is_chapter_unlocked(id):
			label += "  (locked)"
		else:
			var best := String((pats.get(String(ch["patient_id"]), {}) as Dictionary).get("best_grade", ""))
			if Game.is_chapter_done(id) and best != "":
				label += "  [%s]" % best
		b.set_meta("label", label)
		b.tooltip_text = String(ch.get("teaches", ""))
	for b: Button in _day_buttons:
		if String(b.get_meta("toggle", "")) == "unlock":
			b.set_meta("label", "Unlock all days (demo): %s" % ("ON" if bool(Game.settings.get("unlock_all_days", false)) else "OFF"))
	if _days_note != null:
		_days_note.text = "New days open when you finish the one before."


func _on_options() -> void:
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm:
		pm.call("open")


func _on_quit() -> void:
	Events.quit_requested.emit(0)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event.is_pressed():
		_idle = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _state == &"notice":
		if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
			_on_notice_ok()
			get_viewport().set_input_as_handled()
		return
	if _state == &"days" and event.is_action_pressed(&"ui_cancel"):
		_days_back()
		get_viewport().set_input_as_handled()
		return
	if _state != &"menu" and _state != &"days":
		return
	if event.is_action_pressed(&"ui_down"):
		_set_hl((_hl + 1) % _buttons.size())
	elif event.is_action_pressed(&"ui_up"):
		_set_hl((_hl - 1 + _buttons.size()) % _buttons.size())
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		_buttons[_hl].pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _set_hl(i: int, sound: bool = true) -> void:
	_hl = i
	for j in _buttons.size():
		var b := _buttons[j]
		var on := j == i
		b.theme_type_variation = &"AccentButton" if on else &""
		b.text = ("> " if on else "") + String(b.get_meta("label")) + ("  <" if on else "")
	if sound:
		Sfx.play(&"blip", 1.3, -10.0)


func _build() -> void:
	var root := UiKit.full_rect()
	add_child(root)
	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.position = Vector2(56, 22)
	_logo.size = Vector2(700, 240)
	_logo.draw.connect(_draw_logo)
	root.add_child(_logo)

	_menu_card = UiKit.panel(Color(Palette.PAPER, 0.97), Palette.INK, 26)
	_menu_card.position = Vector2(92, 326)
	_menu_card.custom_minimum_size = Vector2(380, 0)
	root.add_child(_menu_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_menu_card.add_child(v)
	var specs: Array = [["Play", _on_start], ["Days", _on_days], ["Options", _on_options]]
	if _has_progress():
		specs.append(["New player", _on_new_player])
	specs.append(["Quit", _on_quit])
	for spec: Array in specs:
		var b := UiKit.button(spec[0], &"", Vector2(340, 58))
		b.set_meta("label", spec[0])
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(spec[1])
		var idx := _buttons.size()
		b.mouse_entered.connect(func() -> void:
			if _state == &"menu" and _hl != idx:
				_set_hl(idx))
		v.add_child(b)
		_buttons.append(b)
	_menu_buttons = _buttons.duplicate()
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["Up", "Down"], "+", ["Enter"], "or click"], 15)
		hr.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(hr)
	var stats := _stats_text()
	if stats != "":
		var sl := UiKit.label(stats, 16, Palette.INK_SOFT, 500)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(340, 0)
		v.add_child(sl)

	_build_days(root)

	var foot := UiKit.label("This is a game, not a hearing test.  All beeps are quiet and every dB is make-believe.", 18, Palette.PAPER, 600)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -38
	foot.offset_bottom = -10
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(foot)

	# the safety notice (first title of the session)
	_notice_layer = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	root.add_child(_notice_layer)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_layer.add_child(cc)
	_notice = UiKit.panel(Palette.PAPER, Palette.INK, 28)
	_notice.custom_minimum_size = Vector2(680, 0)
	cc.add_child(_notice)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 14)
	_notice.add_child(nv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	nv.add_child(head)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(52, 52)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		badge.draw_circle(Vector2(26, 26), 25, Palette.INK)
		badge.draw_circle(Vector2(26, 26), 21, Palette.SUNNY)
		badge.draw_string(_font, Vector2(19, 39), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.INK))
	head.add_child(badge)
	var h := UiKit.label("This is a game, not a hearing test.", 30, Palette.INK, 700)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(h)
	var body := UiKit.label("", 21, Palette.INK, 500)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "The beeps are quiet and pretend, and you never need to hear them: every beep and every answer lights up on screen."
	nv.add_child(body)
	var small := UiKit.label("Worried about your hearing? See a licensed hearing professional.", 17, Palette.INK_SOFT, 500)
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(small)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	nv.add_child(row)
	if UiKit.show_key_hints():
		var hr2 := UiKit.hint_row([["Enter"], "or click"], 15)
		hr2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hr2)
	var ok := UiKit.button("Got it!", &"AccentButton", Vector2(200, 56))
	ok.pressed.connect(_on_notice_ok)
	row.add_child(ok)


## (v3) The day picker card: a button per chapter, the demo unlock toggle, Back.
func _build_days(root: Control) -> void:
	_days_card = UiKit.panel(Color(Palette.PAPER, 0.97), Palette.INK, 26)
	_days_card.position = Vector2(92, 300)
	_days_card.custom_minimum_size = Vector2(460, 0)
	_days_card.visible = false
	root.add_child(_days_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_days_card.add_child(v)
	var head := UiKit.label("Pick a day", 26, Palette.INK, 700)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	for ch: Dictionary in Game.chapters():
		var id := String(ch["id"])
		var b := UiKit.button(String(ch["title"]), &"", Vector2(420, 54))
		b.set_meta("label", String(ch["title"]))
		b.set_meta("chapter", id)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(func() -> void: _pick_day(id, b))
		_add_day_button(v, b)
	var t := UiKit.button("Unlock all days (demo): OFF", &"", Vector2(420, 44))
	t.set_meta("label", "Unlock all days (demo): OFF")
	t.set_meta("toggle", "unlock")
	t.add_theme_font_size_override("font_size", 17)
	t.pressed.connect(_toggle_unlock_all)
	_add_day_button(v, t)
	var back := UiKit.button("Back", &"", Vector2(420, 44))
	back.set_meta("label", "Back")
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(_days_back)
	_add_day_button(v, back)
	_days_note = UiKit.label("New days open when you finish the one before.", 15, Palette.INK_SOFT, 500)
	_days_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_days_note.custom_minimum_size = Vector2(420, 0)
	_days_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_days_note)


func _add_day_button(v: VBoxContainer, b: Button) -> void:
	var idx := _day_buttons.size()
	b.mouse_entered.connect(func() -> void:
		if _state == &"days" and _hl != idx:
			_set_hl(idx))
	v.add_child(b)
	_day_buttons.append(b)


func _has_progress() -> bool:
	return int(Game.progress.get("plays", 0)) > 0 or int(Game.progress.get("coins", 0)) > 0 \
		or not (Game.progress.get("patients", {}) as Dictionary).is_empty()


## "New player": wipe coins, upgrades, records and Hoot's mastery (settings stay). Two presses.
func _on_new_player() -> void:
	var b: Button = null
	for x: Button in _buttons:
		if String(x.get_meta("label")) in ["New player", "Sure? Press again"]:
			b = x
	if not _reset_armed:
		_reset_armed = true
		if b != null:
			b.set_meta("label", "Sure? Press again")
			_set_hl(_buttons.find(b), false)
		Sfx.play(&"error", 1.0, -8.0)
		return
	_reset_armed = false
	for k: String in ["coins", "upgrades", "patients", "plays", "hoot_mastery", "chapters_done", "last_chapter"]:
		var d: Variant = Game.DEFAULT_PROGRESS[k]
		Game.progress[k] = d.duplicate(true) if (d is Dictionary or d is Array) else d
	Game.save_game()
	Sfx.play(&"whoosh")
	Events.goto_scene.emit("res://story/title_screen.tscn")


func _stats_text() -> String:
	var parts: PackedStringArray = []
	var any := false
	for ch: Dictionary in Game.chapters():
		var rec: Dictionary = (Game.progress.get("patients", {}) as Dictionary).get(String(ch["patient_id"]), {})
		if not rec.is_empty():
			any = true
		if not rec.is_empty() and String(rec.get("best_grade", "")) != "":
			parts.append("Day %d best: %s" % [int(ch["day"]), String(rec["best_grade"])])
	var coins := int(Game.progress.get("coins", 0))
	if coins > 0 or any:
		parts.append("%d Decibucks" % coins)
	if Game.has_upgrade("comfy_chair"):
		parts.append("Comfy chair owned")
	if Game.has_upgrade("insert_earphones"):
		parts.append("Insert earphones owned")
	return "  -  ".join(parts)


# ---------------------------------------------------------------- logo

func _draw_logo() -> void:
	var size_px := 112
	var base := Vector2(8, 150)
	var x := base.x
	var pieces: Array = ["B", "cupR", "cupL", "T", "H"]
	var cup_r := size_px * 0.36
	var cup_centers: Array[Vector2] = []
	var wiggle := sin(_t * 2.2) * 0.04
	_logo.draw_set_transform(Vector2.ZERO, wiggle * 0.25, Vector2.ONE)
	for p: String in pieces:
		if p.begins_with("cup"):
			var c := Vector2(x + cup_r + 4, base.y - size_px * 0.34 + sin(_t * 3.0 + (0.0 if p == "cupR" else PI)) * 4.0)
			cup_centers.append(c)
			x += cup_r * 2.0 + 10.0
		else:
			_letter(p, Vector2(x, base.y), size_px, Palette.SUNNY)
			x += _font.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x - 4.0
	# headband over the two cups
	var mid := (cup_centers[0] + cup_centers[1]) * 0.5
	var band_r := (cup_centers[1].x - cup_centers[0].x) * 0.5 + 6.0
	_logo.draw_arc(mid + Vector2(0, 4), band_r, PI * 1.05, PI * 1.95, 24, Palette.INK, 22, true)
	_logo.draw_arc(mid + Vector2(0, 4), band_r, PI * 1.07, PI * 1.93, 24, Color("#6b5e7e"), 12, true)
	UiDraw.rounded_rect(_logo, Rect2(mid + Vector2(-22, -band_r - 8), Vector2(44, 20)), Palette.SUNNY, 8, 3, Palette.INK)
	for i in 2:
		var c := cup_centers[i]
		var col := Palette.RIGHT_RED if i == 0 else Palette.LEFT_BLUE
		_logo.draw_circle(c, cup_r + 6, Palette.INK)
		_logo.draw_circle(c, cup_r, col)
		_logo.draw_circle(c, cup_r * 0.62, Palette.INK)
		_logo.draw_circle(c, cup_r * 0.42, Color("#4a3f5e"))
		_logo.draw_circle(c + Vector2(-cup_r * 0.42, -cup_r * 0.42), cup_r * 0.16, Color(1, 1, 1, 0.55))
		_logo.draw_string(_font, c + Vector2(-9, 10), "R" if i == 0 else "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		# little beep waves
		var phase := fmod(_t * 0.9 + i * 0.5, 1.0)
		var dir := -1.0 if i == 0 else 1.0
		for k in 2:
			var rr := cup_r + 10.0 + (phase + k * 0.5) * 30.0
			var a := 1.0 - fmod(phase + k * 0.5, 1.0)
			var ang := PI if i == 0 else 0.0
			_logo.draw_arc(c, rr, ang - 0.5 * dir, ang + 0.5 * dir, 10, Color(Palette.TONE_CYAN, a), 5, true)
	# CAMP, on a second line
	var x2 := 60.0
	var y2 := base.y + 84.0
	for ch: String in ["C", "A", "M", "P"]:
		var bob := sin(_t * 3.0 + x2 * 0.02) * 3.0
		_letter(ch, Vector2(x2, y2 + bob), 92, Palette.CORAL)
		x2 += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x - 2.0
	_logo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tag := "Beep. Bracket. Be a hearing hero."
	var tf := UiKit.font(600)
	var tp := Vector2(64.0, y2 + 40.0)
	var ts := tf.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
	var asc := tf.get_ascent(24)
	UiDraw.rounded_rect(_logo, Rect2(tp + Vector2(-14.0, -asc - 5.0), Vector2(ts.x + 28.0, ts.y + 10.0)), Color(Palette.PAPER, 0.94), 20, 3, Color(Palette.INK, 0.85))
	_logo.draw_string(tf, tp, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.INK_SOFT)


func _letter(ch: String, at: Vector2, px: int, fill: Color) -> void:
	_logo.draw_string_outline(_font, at + Vector2(0, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 22, Color(Palette.INK, 0.35))
	_logo.draw_string_outline(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 20, Palette.INK)
	_logo.draw_string(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fill)
	_logo.draw_string(_font, at + Vector2(3, -4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(fill.lightened(0.35), 0.0))
