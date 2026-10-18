extends Control
## FsDebrief (freestyle, story-internal): the workup card after the call (docs/FREESTYLE.md §4.5).
## One row per step a pro would run, in order, ticked or crossed against the player's visit, plus
## any extra tests (marked "extra", never a slip). It sits above the dialogue box while Hoot explains.
##   var card := FsDebrief.new(); hud.add_game(card)
##   card.show_rows("PENNY'S WORKUP", rows)   # rows: [{"tool", "text", "state": "ok"|"miss"|"extra"|"slip"}]
##   card.hide_card()

const UiKit := preload("res://story/ui_kit.gd")
const FsTray := preload("res://story/freestyle/fs_tray.gd")

const WIDTH := 660.0
const ROW_H := 40.0

var _panel: PanelContainer
var _title: Label
var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_panel = UiKit.panel(Color(Palette.PAPER, 0.98), Palette.INK, 22)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = UiKit.label("", 22, Palette.INK, 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_title)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_list)


func show_rows(title: String, rows: Array[Dictionary]) -> void:
	_title.text = title
	for c in _list.get_children():
		c.queue_free()
	for r: Dictionary in rows:
		_list.add_child(_row(r))
	visible = true
	_panel.reset_size()
	var vp := get_viewport_rect().size
	var h := _panel.get_combined_minimum_size().y
	_panel.position = Vector2((vp.x - WIDTH) * 0.5 + 40.0, maxf(78.0, (vp.y - 210.0 - h) * 0.5))
	Juice.bounce_in(_panel, 0.45)
	Sfx.play(&"whoosh", 1.1, -8.0)


func hide_card() -> void:
	if not visible:
		return
	var t := create_tween()
	t.tween_property(_panel, "modulate:a", 0.0, 0.25)
	await t.finished
	visible = false
	_panel.modulate.a = 1.0


func _row(r: Dictionary) -> Control:
	var state := String(r.get("state", "ok"))
	var row := Control.new()
	row.custom_minimum_size = Vector2(WIDTH - 32, ROW_H)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tool := StringName(String(r.get("tool", "")))
	row.draw.connect(func() -> void:
		var bg := Color("#eefaf3") if state == "ok" else (Color("#fff0ee") if state in ["miss", "slip"] else Color("#f3f0ea"))
		UiDraw.rounded_rect(row, Rect2(Vector2.ZERO, row.size), bg, 10)
		if tool != &"":
			FsTray.draw_icon(row, tool, Vector2(26, ROW_H * 0.5 + 2), 0.55)
		var mc := Vector2(row.size.x - 22, ROW_H * 0.5)
		if state == "ok":
			row.draw_circle(mc, 12.0, Palette.MINT)
			UiDraw.check(row, mc, 11.0, Color.WHITE, 3.0)
		elif state == "miss" or state == "slip":
			row.draw_circle(mc, 12.0, Palette.CORAL)
			UiDraw.cross(row, mc, 9.0, Color.WHITE, 3.0)
		else:
			row.draw_circle(mc, 12.0, Color(Palette.INK, 0.25))
			row.draw_string(UiKit.font(700), mc + Vector2(-4, 6), "+", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE))
	var l := UiKit.label(String(r.get("text", "")), 17, Palette.INK if state != "extra" else Palette.INK_SOFT, 600 if state != "extra" else 500)
	l.position = Vector2(54, 0)
	l.size = Vector2(WIDTH - 32 - 54 - 44, ROW_H)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_constant_override("line_spacing", -2)
	row.add_child(l)
	return row
