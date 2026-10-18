extends CanvasLayer
## Story HUD (CanvasLayer 10): visit step tracker, comfort hearts, case-notes stickies.
## Story-internal. The level creates it and calls set_step / add_clue / show_red_flags.
## Mini-games are added on top through add_game(control) so they share layer 10.

const UiKit := preload("res://story/ui_kit.gd")

const STEPS: Array[StringName] = [&"chat", &"peek", &"explain", &"phones", &"beep_r", &"beep_l", &"reveal", &"evidence", &"fit"]
const STEP_LABELS: Dictionary = {
	&"chat": "Chat", &"peek": "Peek", &"explain": "Explain", &"phones": "Phones", &"beep_r": "Beep R",
	&"beep_l": "Beep L", &"reveal": "Reveal", &"evidence": "Evidence", &"fit": "Fit",
}
const STEP_COLORS: Dictionary = {&"beep_r": Palette.RIGHT_RED, &"beep_l": Palette.LEFT_BLUE}
const NOTE_COLORS: Array[Color] = [Color("#fff1a8"), Color("#ffd9e8"), Color("#d6f5e3"), Color("#dbe9ff")]

var tracker: Control
var notes_box: VBoxContainer
var games: Control
var _current := -1
## (v3) The visit's steps and labels: Day 1 uses STEPS / STEP_LABELS; other days call set_steps().
var _steps: Array[StringName] = STEPS.duplicate()
var _labels: Dictionary = STEP_LABELS.duplicate()
var _colors: Dictionary = STEP_COLORS.duplicate()
var _title := "GRANDPA GUS'S VISIT"
var _done: Dictionary = {}
var _hearts := ClinicRules.MAX_COMFORT
var _heart_flash := 0.0
var _t := 0.0
var _font: Font
var _note_count := 0


func _ready() -> void:
	layer = 10
	_font = UiKit.font(600)
	var root := UiKit.full_rect()
	add_child(root)
	tracker = Control.new()
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker.position = Vector2(14, 12)
	tracker.size = Vector2(900, 70)
	tracker.draw.connect(_draw_tracker)
	root.add_child(tracker)
	notes_box = VBoxContainer.new()
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_box.position = Vector2(14, 92)
	notes_box.custom_minimum_size = Vector2(236, 0)
	notes_box.add_theme_constant_override("separation", 8)
	root.add_child(notes_box)
	games = UiKit.full_rect()
	add_child(games)
	_hearts = Game.get_comfort()
	Events.comfort_changed.connect(_on_comfort)
	Events.phase_changed.connect(_on_phase)


func add_game(c: Control) -> void:
	games.add_child(c)


## (v3) Replace the step tracker (a chapter other than Day 1). labels: {step: text};
## colors: {step: Color} for ear-coloured steps; title: the small caption above the pills.
func set_steps(steps: Array, labels: Dictionary, title: String = "", colors: Dictionary = {}) -> void:
	_steps.clear()
	for s in steps:
		_steps.append(StringName(s))
	_labels = labels.duplicate()
	_colors = colors.duplicate()
	if title != "":
		_title = title
	_current = -1
	_done.clear()
	tracker.queue_redraw()


func set_step(step: StringName) -> void:
	var i := _steps.find(step)
	if i < 0:
		return
	for j in i:
		_done[_steps[j]] = true
	_current = i
	tracker.queue_redraw()


func complete_step(step: StringName) -> void:
	_done[step] = true
	tracker.queue_redraw()
	Sfx.play(&"ding", 1.4, -10.0)


## A sticky note with a case-history clue. kind: "clue" or "flag" (red flag card).
func add_clue(text: String, kind: String = "clue") -> void:
	var p := PanelContainer.new()
	var col: Color = NOTE_COLORS[_note_count % NOTE_COLORS.size()]
	var border := Palette.INK
	if kind == "flag":
		col = Color("#fff4f2")
		border = Palette.RIGHT_RED
	var sb := UiKit.style(col, border, 6, 3 if kind == "flag" else 2, 4, 10)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = Vector2(236, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := UiKit.label("RED FLAGS" if kind == "flag" else "CASE NOTE", 12, Palette.RIGHT_RED if kind == "flag" else Palette.INK_SOFT, 700)
	v.add_child(head)
	var l := UiKit.label(text, 15, Palette.INK, 500)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(212, 0)
	while notes_box.get_child_count() >= 4:
		var old := notes_box.get_child(0)
		notes_box.remove_child(old)
		old.queue_free()
	v.add_child(l)
	notes_box.add_child(p)
	_note_count += 1
	p.rotation = deg_to_rad(-2.0 + 4.0 * float(_note_count % 2))
	Juice.bounce_in(p, 0.4)
	Sfx.play(&"pen", 1.0, -6.0)


func clear_notes() -> void:
	for c in notes_box.get_children():
		c.queue_free()
	_note_count = 0


func set_notes_visible(on: bool) -> void:
	notes_box.visible = on


func _on_phase(phase: StringName, _info: Dictionary) -> void:
	var hide_all := phase == &"audiometry" or phase == &"speech" or phase == &"results"   # (Speech) under the SPEECH screen
	tracker.visible = not hide_all
	notes_box.visible = not hide_all and phase in [&"history", &"otoscopy", &"instructions", &"earphones"]


func _on_comfort(hearts: int, reason: String) -> void:
	if hearts < _hearts:
		_heart_flash = 1.0
		Juice.shake(tracker, 6.0, 0.3)
		var msg := "-1 comfort"
		if reason == "no_instructions":
			msg = "-1 comfort: confused patient"
		elif reason == "too_loud":
			msg = "-1 comfort: too loud!"
		Juice.float_text(get_child(0), msg, tracker.position + Vector2(_tracker_width() + 60.0, 50.0), Palette.CORAL, 24)
	_hearts = hearts
	tracker.queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _heart_flash > 0.0:
		_heart_flash = maxf(0.0, _heart_flash - delta)
	if tracker.visible:
		tracker.queue_redraw()


func _pill_width(i: int) -> float:
	var s: String = String(_labels.get(_steps[i], String(_steps[i])))
	return _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + (40.0 if _done.has(_steps[i]) else 24.0)


func _tracker_width() -> float:
	var w := 18.0
	for i in _steps.size():
		w += _pill_width(i) + 6.0
	return w


func _draw_tracker() -> void:
	var w := _tracker_width()
	var bg := Rect2(Vector2.ZERO, Vector2(w + 120.0, 64.0))
	UiDraw.rounded_rect(tracker, Rect2(bg.position + Vector2(0, 4), bg.size), Color(Palette.INK, 0.2), 18)
	UiDraw.rounded_rect(tracker, bg, Palette.PAPER, 18, 3, Palette.INK)
	tracker.draw_string(_font, Vector2(14, 20), _title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_SOFT)
	var x := 10.0
	for i in _steps.size():
		var id := _steps[i]
		var pw := _pill_width(i)
		var done := _done.has(id)
		var cur := i == _current and not done
		var y := 27.0 - (absf(sin(_t * 4.0)) * 3.0 if cur else 0.0)
		var r := Rect2(Vector2(x, y), Vector2(pw, 28))
		var accent: Color = _colors.get(id, Palette.SUNNY)
		var fill := Palette.PAPER
		var text_col := Palette.INK_SOFT
		if done:
			fill = Palette.MINT
			text_col = Palette.INK
		elif cur:
			fill = accent if _colors.has(id) else Palette.SUNNY
			text_col = Color.WHITE if _colors.has(id) else Palette.INK
		UiDraw.rounded_rect(tracker, r, fill, 14, 2, Palette.INK if (done or cur) else Color(Palette.INK, 0.35))
		var tx := x + 12.0
		if done:
			UiDraw.check(tracker, Vector2(x + 15.0, y + 14.0), 12.0, Palette.INK, 3.0)
			tx = x + 28.0
		tracker.draw_string(_font, Vector2(tx, y + 20.0), String(_labels.get(id, String(id))), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_col)
		x += pw + 6.0
	# comfort hearts
	var hx := x + 14.0
	tracker.draw_string(_font, Vector2(hx - 2.0, 20), "COMFORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_SOFT)
	for i in ClinicRules.MAX_COMFORT:
		var full := i < _hearts
		var c := Vector2(hx + 14.0 + i * 30.0, 42.0)
		var col := Palette.CORAL if full else Color(Palette.INK, 0.18)
		if not full and i == _hearts and _heart_flash > 0.0:
			c += Vector2(randf_range(-2, 2), randf_range(-2, 2))
			col = Palette.CORAL.lerp(Color(Palette.INK, 0.18), 1.0 - _heart_flash)
		UiDraw.heart(tracker, c, 24.0, col)
