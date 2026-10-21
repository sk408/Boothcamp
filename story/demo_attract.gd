extends Control
## DemoAttract (career-fair demo, docs/DEMO.md): the booth's attract loop. The demo's title starts
## it when nobody has touched the game for a while: over the clinic backdrop, Professor Hoot waves
## and talks through the visit one teaser line at a time, round and round, next to Gus, with "Press
## a key or click to play" pulsing below. Any key, click or real mouse movement ends it and emits
## dismissed (the title then greets the visitor with the safety notice). Silent: the title's music
## plays on. Leaves the title's safety footer uncovered.
##   var a := DemoAttract.new(); a.tagline = TitleScreen.DEMO_TAGLINE; add_child(a)
##   start() / stop() / is_running(); line_index() (which teaser is showing)

signal dismissed

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")

## Hoot's teasers, one every LINE_S seconds, round and round (18 words or fewer each).
const LINES: Array[String] = [
	"Psst! Grandpa Gus says his wife mumbles. Does she? Come find out!",
	"Peek in his ear. Something has been hiding in there since 1987!",
	"Then beep his hearing, one quiet tone at a time.",
	"His chart shows which sounds slip past him. Can you spot them?",
	"Fit his hearing aids, then listen: does he finally hear Doris?",
	"Hearing care pros solve puzzles like this every day. Want to try?",
]
const PROMPT := "Press a key or click to play"
const LINE_S := 4.5
const CHARS_PER_SECOND := 40.0
const FADE_S := 0.5
## Mouse movement shorter than this (screen px, one event) is a nudge on the table, not a visitor.
const MOTION_MIN_PX := 6.0
## Kept clear at the bottom for the title's safety footer (TitleScreen.FOOTER_H).
const FOOTER_H := 46.0

## The line under the prompt (set before the node enters the tree).
var tagline := ""
var _running := false
var _t := 0.0
var _line := 0
var _line_t := 0.0
var _motion := 1.0
var _bubble: PanelContainer
var _text: Label
var _prompt: Label
var _hoot: Control
var _gus: Control
var _tween: Tween


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_bottom = -FOOTER_H
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func start() -> void:
	if _running:
		return
	_running = true
	_motion = 0.35 if bool(Game.settings.get("reduced_motion", false)) else 1.0
	_line = 0
	_show_line()
	visible = true
	modulate.a = 0.0
	_fade(1.0, FADE_S)


func stop() -> void:
	if not _running:
		return
	_running = false
	_fade(0.0, 0.25)
	await _tween.finished
	if not _running:
		visible = false


func is_running() -> bool:
	return _running


func line_index() -> int:
	return _line


func _fade(to: float, s: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", to, s)


func _show_line() -> void:
	_line_t = 0.0
	_text.text = LINES[_line]
	_text.visible_characters = 0
	Juice.bounce_in(_bubble, 0.35)


func _process(delta: float) -> void:
	if not _running:
		return
	_t += delta
	_line_t += delta
	_text.visible_characters = mini(int(_line_t * CHARS_PER_SECOND), _text.text.length())
	if _line_t >= LINE_S:
		_line = (_line + 1) % LINES.size()
		_show_line()
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	_prompt.modulate.a = lerpf(1.0, 0.55 + 0.45 * pulse, _motion)
	_prompt.scale = Vector2.ONE * (1.0 + 0.04 * pulse * _motion)
	_hoot.queue_redraw()
	_gus.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _running:
		return
	var wake := false
	if event is InputEventMouseMotion:
		wake = (event as InputEventMouseMotion).screen_relative.length() >= MOTION_MIN_PX
	elif event.is_pressed() and not event.is_echo():
		wake = true
	if not wake:
		return
	get_viewport().set_input_as_handled()
	stop()
	dismissed.emit()


func _typing() -> bool:
	return _text.visible_characters < _text.text.length()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 26)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	cc.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_hoot = Control.new()
	_hoot.custom_minimum_size = Vector2(230, 230)
	_hoot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hoot.draw.connect(_draw_hoot)
	row.add_child(_hoot)
	_bubble = UiKit.panel(Palette.PAPER, Palette.INK, 26)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.custom_minimum_size = Vector2(520, 150)
	_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_bubble)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	_bubble.add_child(bv)
	bv.add_child(UiKit.label("Professor Hoot", 18, Portraits.name_color("Hoot"), 700))
	_text = UiKit.label("", 30, Palette.INK, 600)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(480, 0)
	bv.add_child(_text)
	_gus = Control.new()
	_gus.custom_minimum_size = Vector2(190, 230)
	_gus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gus.draw.connect(_draw_gus)
	row.add_child(_gus)
	_prompt = UiKit.label(PROMPT, 46, Palette.SUNNY, 700, 10, Palette.INK)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.custom_minimum_size = Vector2(900, 0)
	_prompt.resized.connect(func() -> void: _prompt.pivot_offset = _prompt.size * 0.5)
	v.add_child(_prompt)
	var tag := UiKit.label(tagline, 24, Palette.PAPER, 600)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)


## Hoot bobs, talks while his line types out, and waves a wing from behind his frame.
func _draw_hoot() -> void:
	var c := Vector2(112, 118 + sin(_t * 2.2) * 4.0 * _motion)
	var wave := sin(_t * 7.0) * 0.55 * _motion
	var shoulder := c + Vector2(70, 34)
	var tip := shoulder + Vector2(0, -62).rotated(0.55 + wave)
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(shoulder.lerp(tip, 0.5) + Vector2(cos(a) * 18.0, sin(a) * 38.0).rotated(0.55 + wave))
	_outline(_hoot, pts, Palette.INK, 4.0)
	_hoot.draw_colored_polygon(pts, Color("#b9773f"))
	Portraits.draw(_hoot, "Hoot", c, 88.0, _typing() and fmod(_t, 0.24) < 0.12, fmod(_t, 3.3) < 0.12)


## Gus, puzzled, with a question mark that bobs over him.
func _draw_gus() -> void:
	var c := Vector2(95, 138)
	Portraits.draw(_gus, "Gus", c, 72.0, false, fmod(_t + 1.1, 3.7) < 0.12)
	var q := Vector2(150, 54 + sin(_t * 3.0) * 6.0 * _motion)
	var f := UiKit.font(700)
	_gus.draw_string_outline(f, q, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, 10, Palette.INK)
	_gus.draw_string(f, q, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 64, Palette.SUNNY)


## A polygon's outline as a thick closed line (drawn under its fill).
static func _outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, w, true)
