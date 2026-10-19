extends Control
## WaitingRoom (freestyle): the walk-in clinic's hub (docs/FREESTYLE.md §1). One card per walk-in
## (portrait, name and age, their complaint in a line, difficulty stars, best grade), every one open,
## plus Surprise me and Back. Picking a card starts res://story/freestyle/level_freestyle.tscn with
## that patient (FsData.set_next_case). Phase &"freestyle_room"; the pick is a standard `choice`
## beat (options = the cards' name labels; best = --freestyle=<id>, else the first card).
## Keys: arrows + Enter, Esc = Back. Mouse: click.

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const FsData := preload("res://story/freestyle/fs_data.gd")

const LEVEL_SCENE := "res://story/freestyle/level_freestyle.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const CLINIC_SCENE := "res://world/clinic.tscn"
const CARD_SIZE := Vector2(284, 236)
const CARD_GAP := 16.0
const COLUMNS := 4
const GRID_TOP := 104.0
const FOOTER_H := 46.0
const TINTS: Array[Color] = [Color("#dbe9ff"), Color("#ffe3c2"), Color("#d6f5e3"), Color("#f3e1ff"), Color("#ffe0d6"), Color("#fff1a8"), Color("#cfe3ff"), Color("#ffd9e8")]

var _cards: Array[Button] = []
var _buttons: Array[Button] = []   ## keyboard order: every card, then Surprise me, then Back
var _ids: PackedStringArray = []
var _hl := -1
var _t := 0.0
var _accepting := false
var _leaving := false
## Seconds since the last input: a room left alone goes back to the title (a booth display), like the paper.
var _idle := 0.0
const IDLE_S := 90.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("freestyle_waiting_room")
	FsData.register_speakers()
	if ResourceLoader.exists(CLINIC_SCENE):
		var clinic := (load(CLINIC_SCENE) as PackedScene).instantiate()
		add_child(clinic)
		if clinic.has_method("set_title_mode"):
			clinic.call("set_title_mode", true)
	_build()
	Sfx.music_start()
	_open.call_deferred()


## Boot hook for main.gd --scene=: nothing extra (the room opens by itself).
func demo_start() -> void:
	pass


func _process(delta: float) -> void:
	_t += delta
	if _accepting:
		_idle += delta
		if _idle > IDLE_S:
			_back()
	for b: Button in _cards:
		b.queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.CREAM, 0.86))
	draw_rect(Rect2(0, size.y - FOOTER_H, size.x, FOOTER_H), Color(Palette.INK, 0.78))


func _open() -> void:
	Events.phase_changed.emit(&"freestyle_room", {})
	_accepting = true
	var labels: Array[String] = []
	for b: Button in _cards:
		labels.append(String(b.get_meta("label")))
	var want := Game.cli_value("freestyle", "")
	var best := maxi(0, _ids.find(want))
	Events.awaiting_input.emit(&"choice", {"prompt": "Who's next?", "options": labels, "best": best}, func() -> void: _pick(best))


func _build() -> void:
	var head := UiKit.label("THE WALK-IN CLINIC", 40, Palette.INK, 700, 10, Palette.PAPER)
	head.position = Vector2(48, 18)
	add_child(head)
	var sub := UiKit.label("Freestyle: no script, no hints. Pick a patient, run any test in any order, then make the call.", 18, Palette.INK_SOFT, 600)
	sub.position = Vector2(52, 70)
	add_child(sub)
	_ids = FsData.case_ids()
	var x0 := (1280.0 - (COLUMNS * CARD_SIZE.x + (COLUMNS - 1) * CARD_GAP)) * 0.5
	for i in _ids.size():
		var c := FsData.load_case(_ids[i])
		if c.is_empty():
			continue
		var b := _card(c, i)
		b.position = Vector2(x0 + (i % COLUMNS) * (CARD_SIZE.x + CARD_GAP), GRID_TOP + (i / COLUMNS) * (CARD_SIZE.y + CARD_GAP))
		add_child(b)
		_cards.append(b)
		_add_button(b)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	foot.position = Vector2(x0, GRID_TOP + 2.0 * (CARD_SIZE.y + CARD_GAP) + 2.0)
	add_child(foot)
	var surprise := UiKit.button("Surprise me", &"AccentButton", Vector2(220, 50))
	surprise.set_meta("label", "Surprise me")
	surprise.pressed.connect(_surprise)
	foot.add_child(surprise)
	_add_button(surprise)
	var back := UiKit.button("Back to the title", &"", Vector2(240, 50))
	back.set_meta("label", "Back to the title")
	back.pressed.connect(_back)
	foot.add_child(back)
	_add_button(back)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["Left", "Right", "Up", "Down"], "+", ["Enter"], "or click.", ["Esc"], "back"], 15)
		foot.add_child(hr)
	var safety := UiKit.label("This is a game, not a hearing test.  All beeps are quiet and every dB is make-believe.", 18, Palette.PAPER, 600)
	safety.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	safety.offset_top = -38
	safety.offset_bottom = -10
	safety.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(safety)


func _add_button(b: Button) -> void:
	var idx := _buttons.size()
	b.mouse_entered.connect(func() -> void:
		if _accepting and _hl != idx:
			_set_hl(idx))
	_buttons.append(b)


func _card(c: Dictionary, i: int) -> Button:
	var p := FsData.patient_for(c)
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CARD_SIZE
	b.size = CARD_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var label := "%s, %d" % [p.display_name, p.age] if p != null else String(c["speaker"])
	b.set_meta("label", label)
	b.set_meta("case", c)
	b.set_meta("tint", TINTS[i % TINTS.size()])
	var rec: Dictionary = (Game.progress.get("patients", {}) as Dictionary).get(String(c["patient_id"]), {})
	b.set_meta("best", String(rec.get("fs_best_grade", "")))
	b.draw.connect(_draw_card.bind(b))
	var idx := i
	b.pressed.connect(func() -> void: _pick(idx))
	var name_l := UiKit.label(label, 20, Palette.INK, 700)
	name_l.position = Vector2(10, 112)
	name_l.size = Vector2(CARD_SIZE.x - 20, 28)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_child(name_l)
	var teaser := UiKit.label("\"%s\"" % String(c["teaser"]), 15, Palette.INK_SOFT, 500)
	teaser.position = Vector2(16, 142)
	teaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teaser.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	teaser.custom_minimum_size = Vector2(CARD_SIZE.x - 32, 0)
	b.add_child(teaser)
	# sized once it is in the tree (sized before, it keeps the unwrapped line's width and spills off the card)
	teaser.set_deferred("size", Vector2(CARD_SIZE.x - 32, 56))
	return b


func _draw_card(b: Button) -> void:
	var c: Dictionary = b.get_meta("case", {})
	var i := _cards.find(b)
	var hl := i >= 0 and i == _hl
	var r := Rect2(Vector2.ZERO, b.size)
	var tint: Color = b.get_meta("tint", Palette.PAPER)
	if hl:
		UiDraw.rounded_rect(b, r.grow(6.0), Palette.SUNNY, 26)
	UiDraw.rounded_rect(b, Rect2(r.position + Vector2(0, 5), r.size), Color(Palette.INK, 0.18), 22)
	UiDraw.rounded_rect(b, r, Palette.PAPER, 22, 4, Palette.INK)
	var top := Rect2(Vector2(4, 4), Vector2(b.size.x - 8, 100))
	UiDraw.rounded_rect(b, top, tint, 18)
	var bob := sin(_t * 2.4 + i * 1.7) * (3.0 if hl else 0.0)
	Portraits.draw(b, String(c.get("speaker", "")), Vector2(b.size.x * 0.5, 56 + bob), 40.0, false, fmod(_t + i * 0.9, 4.2) < 0.12)
	# difficulty stars
	var stars := int(c.get("stars", 1))
	for k in 3:
		var sc := Vector2(22 + k * 24, 22)
		UiDraw.star(b, sc, 10.0, Palette.SUNNY if k < stars else Color(Palette.INK, 0.15))
	# best grade
	var best := String(b.get_meta("best", ""))
	if best != "":
		var f := UiKit.font(700)
		var bc := Vector2(b.size.x - 32, 32)
		b.draw_circle(bc + Vector2(0, 3), 21.0, Color(Palette.INK, 0.25))
		b.draw_circle(bc, 21.0, Palette.grade_color(best))
		b.draw_arc(bc, 21.0, 0, TAU, 32, Palette.INK, 3.5, true)
		var gs := 24 if best.length() <= 1 else 13
		var gw := f.get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		b.draw_string(f, bc + Vector2(-gw * 0.5, gs * 0.36), best, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Palette.INK)
	b.draw_line(Vector2(40, 204), Vector2(b.size.x - 40, 204), Color(Palette.INK, 0.12), 2.0)
	var f2 := UiKit.font(600)
	var tag := "NEW PATIENT" if best == "" else "SEEN BEFORE"
	var tw := f2.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	b.draw_string(f2, Vector2((b.size.x - tw) * 0.5, 226), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)


func _set_hl(i: int, sound: bool = true) -> void:
	_hl = i
	for j in _buttons.size():
		var b := _buttons[j]
		if _cards.has(b):
			if j == i:
				b.pivot_offset = b.size * 0.5
				Juice.pop(b, 1.03, 0.18)
			continue
		b.theme_type_variation = &"AccentButton" if (j == i or (j == _cards.size() and i < 0)) else &""
	if sound:
		Sfx.play(&"blip", 1.3, -10.0)


func _pick(i: int) -> void:
	if not _accepting or _leaving or i < 0 or i >= _cards.size():
		return
	_leaving = true
	_accepting = false
	Sfx.play(&"fanfare")
	var b := _cards[i]
	b.pivot_offset = b.size * 0.5
	Juice.pop(b, 1.1, 0.25)
	Events.input_resolved.emit(&"choice")
	FsData.set_next_case(_ids[i])
	Events.goto_scene.emit(LEVEL_SCENE)


## A random walk-in, preferring one not seen yet (Game.rng: --seed makes it repeatable).
func _surprise() -> void:
	if not _accepting:
		return
	var fresh: Array[int] = []
	for i in _cards.size():
		if String(_cards[i].get_meta("best", "")) == "":
			fresh.append(i)
	var pool: Array[int] = fresh
	if pool.is_empty():
		for i in _cards.size():
			pool.append(i)
	_pick(pool[Game.rng.randi_range(0, pool.size() - 1)])


func _back() -> void:
	if _leaving:
		return
	_leaving = true
	_accepting = false
	Sfx.play(&"click")
	Events.input_resolved.emit(&"choice")
	Events.goto_scene.emit(TITLE_SCENE)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event.is_pressed():
		_idle = 0.0
	# Esc means Back here, before the pause menu turns it into Paused (as on the title's Days card)
	if _accepting and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm == null or not bool(pm.call("is_open")):
			_back()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	var n := _buttons.size()
	var nc := _cards.size()
	if event.is_action_pressed(&"ui_right"):
		_set_hl((_hl + 1) % n)
	elif event.is_action_pressed(&"ui_left"):
		_set_hl((_hl - 1 + n) % n if _hl >= 0 else n - 1)
	elif event.is_action_pressed(&"ui_down"):
		_set_hl(mini(_hl + COLUMNS, nc) if _hl >= 0 and _hl < nc else (0 if _hl < 0 else _hl))
	elif event.is_action_pressed(&"ui_up"):
		_set_hl(maxi(_hl - COLUMNS, 0) if _hl >= COLUMNS and _hl < nc else (nc - 1 if _hl >= nc else _hl))
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _hl < 0:
			_set_hl(0)
		else:
			_buttons[_hl].pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
