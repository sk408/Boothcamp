extends Control
## FsClipboard (freestyle, story-internal): the visit's clipboard on the left of the clinic: every
## note the player has gathered (history answers, the otoscope, the tympanometer) and what the chart
## shows so far. No hints: only what the player found out.
##   var cb := FsClipboard.new(); hud.add_game(cb); cb.setup("PENNY NATTER, 41")
##   cb.add_note("No pain, drainage or dizziness")      # kind "flag" for a red flag the patient has
##   cb.set_tests(["Air: right 8 dB, left 7 dB"])        # the chart lines, replaced each time
## No line starts like a tray card or a question (the mouse bot clicks those by their text).

const UiKit := preload("res://story/ui_kit.gd")

const POS := Vector2(14, 92)
const WIDTH := 272.0
const MAX_NOTES := 9
## The board stops above the tray's prompt and the dialogue box: a long visit shrinks the writing,
## then drops the oldest plain notes (red flags stay).
const MAX_H := 420.0
const FONT_SIZES: Array[int] = [15, 14, 13]

var _panel: PanelContainer
var _title: Label
var _notes: VBoxContainer
var _tests_head: Label
var _tests: VBoxContainer
var _seen: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var sb := UiKit.style(Color("#fffdf3"), Palette.INK, 14, 4, 6, 12)
	sb.content_margin_top = 26
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.position = POS
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	_panel.draw.connect(_draw_clip)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = UiKit.label("", 17, Palette.INK, 700)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.custom_minimum_size = Vector2(WIDTH - 28, 0)
	v.add_child(_title)
	v.add_child(_rule())
	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 3)
	_notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_notes)
	_tests_head = UiKit.label("THE CHART", 13, Palette.INK_SOFT, 700)
	_tests_head.visible = false
	v.add_child(_tests_head)
	_tests = VBoxContainer.new()
	_tests.add_theme_constant_override("separation", 2)
	_tests.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_tests)
	_add_line(_notes, "Nothing yet: ask, look, test.", Palette.INK_SOFT, "empty")


func setup(title: String) -> void:
	_title.text = title


## A note (once per text). kind: "note", or "flag" for a red flag the patient really has.
func add_note(text: String, kind: String = "note") -> void:
	if text == "" or _seen.has(text):
		return
	_seen[text] = true
	for c in _notes.get_children():
		if c.has_meta("empty"):
			c.queue_free()
	while _notes.get_child_count() >= MAX_NOTES:
		var old := _notes.get_child(0)
		_notes.remove_child(old)
		old.queue_free()
	var row := _add_line(_notes, text, Palette.RIGHT_RED.darkened(0.1) if kind == "flag" else Palette.INK, kind)
	_fit()
	Juice.pop(row, 1.15, 0.25)
	Sfx.play(&"pen", 1.0, -8.0)


## The chart lines (replaces the previous ones).
func set_tests(lines: Array[String]) -> void:
	for c in _tests.get_children():
		c.queue_free()
	_tests_head.visible = not lines.is_empty()
	for l: String in lines:
		_add_line(_tests, l, Palette.INK, "test")
	_fit()


## Keep the board under MAX_H: smaller writing first, then the oldest plain notes go.
func _fit() -> void:
	for fs: int in FONT_SIZES:
		if _estimate(fs) <= MAX_H:
			_apply_font(fs)
			return
	_apply_font(FONT_SIZES[-1])
	while _estimate(FONT_SIZES[-1]) > MAX_H:
		var drop: Node = null
		for c in _notes.get_children():
			if not c.is_queued_for_deletion() and String(c.get_meta("kind", "")) == "note":
				drop = c
				break
		if drop == null:
			return
		_notes.remove_child(drop)
		drop.queue_free()


## The board's height with the writing at font size fs (wrapped lines measured with the real font).
func _estimate(fs: int) -> float:
	var h := 26.0 + 12.0 + 8.0   # top (under the clip) and bottom margins, borders
	h += _title.get_combined_minimum_size().y + 2.0 + 2.0 * 5.0
	var rows := 0
	for box: VBoxContainer in [_notes, _tests]:
		for row in box.get_children():
			if row.is_queued_for_deletion():
				continue
			var l := row.get_child(1) as Label
			var bold: bool = row.get_meta("kind", "") == "flag"
			h += UiKit.font(700 if bold else 500).get_multiline_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, WIDTH - 44, fs).y * 1.08 + 3.0
			rows += 1
	if _tests_head.visible:
		h += 13.0 * 1.4 + 5.0
	return h


func _apply_font(fs: int) -> void:
	for box: VBoxContainer in [_notes, _tests]:
		for row in box.get_children():
			(row.get_child(1) as Label).add_theme_font_size_override("font_size", fs)


func _add_line(box: VBoxContainer, text: String, color: Color, kind: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == "empty":
		h.set_meta("empty", true)
	h.set_meta("kind", kind)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(10, 18)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dc := Palette.RIGHT_RED if kind == "flag" else (Palette.LEFT_BLUE if kind == "test" else Palette.MINT)
	dot.draw.connect(func() -> void:
		if kind != "empty":
			dot.draw_circle(Vector2(5, 10), 4.0, dc))
	h.add_child(dot)
	var l := UiKit.label(text, 15, color, 500 if kind != "flag" else 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(WIDTH - 44, 0)
	h.add_child(l)
	box.add_child(h)
	return h


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(Palette.INK, 0.25)
	r.custom_minimum_size = Vector2(WIDTH - 28, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## The clip at the top of the board.
func _draw_clip() -> void:
	var w := _panel.size.x
	var r := Rect2(Vector2(w * 0.5 - 46, -12), Vector2(92, 28))
	UiDraw.rounded_rect(_panel, r, Color("#b8c4cc"), 8, 3, Palette.INK)
	_panel.draw_circle(r.get_center() + Vector2(0, -2), 5.0, Palette.INK)
