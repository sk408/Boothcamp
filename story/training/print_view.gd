extends Control
## PrintView (training, story-internal): the Training room's "Print view" (docs/training/MASKING_TRAINER.md
## §4, question 8): all five Masking School cheat-sheet cards on one paper page, with the diploma stamp
## once the exam is done. "Save picture" writes the page as a PNG for printing: into Documents/BoothCamp
## on a PC (user:// when Documents can't be written), a browser download on the web. The room opens it
## once every card is earned; Close, Enter or P shuts it.
##   var pv := PrintView.new(); room.add_child(pv); pv.closed.connect(...)

const UiKit := preload("res://story/ui_kit.gd")
const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")
const Diploma := preload("res://story/training/diploma.gd")

const PAGE := Rect2(90, 24, 1100, 672)
const FILE_NAME := "masking-cheat-sheets.png"

signal closed

## Where the last "Save picture" went ("" = not saved; "download" on the web), for the tests.
var saved_to := ""
var _page: Control
var _buttons: HBoxContainer
var _note: Label
var _busy := false


func _ready() -> void:
	name = "PrintView"
	add_to_group("print_view")
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := UiKit.full_rect()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.draw.connect(func() -> void: dim.draw_rect(Rect2(Vector2(-2000, -2000), Vector2(6000, 6000)), Color(Palette.INK, 0.55)))
	add_child(dim)
	_page = Control.new()
	_page.position = PAGE.position
	_page.size = PAGE.size
	_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page.draw.connect(_draw_page)
	add_child(_page)
	var got := TrainingProgress.cards(MaskDeck.LESSON)
	for i in MaskDeck.CARD_ORDER.size():
		var id: String = MaskDeck.CARD_ORDER[i]
		var cc := CheatCard.new(MaskDeck.cheat_card(id), got.has(id), 19)
		cc.name = "print_%s" % id
		cc.size = Vector2(330, 172)
		cc.position = Vector2(30 + (i % 3) * 354, 104 + (i / 3) * 200)
		_page.add_child(cc)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	_buttons.position = PAGE.position + Vector2(PAGE.size.x - 470, PAGE.size.y - 76)
	add_child(_buttons)
	var save := UiKit.button("Save picture", &"", Vector2(220, 56))
	save.add_theme_font_size_override("font_size", 22)
	save.pressed.connect(save_picture)
	_buttons.add_child(save)
	var close := UiKit.button("Close", &"", Vector2(200, 56))
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(close_view)
	_buttons.add_child(close)
	_note = UiKit.label("", 16, Palette.INK_SOFT, 600)
	_note.position = PAGE.position + Vector2(30, PAGE.size.y - 112)
	_note.size = Vector2(PAGE.size.x - 520, 50)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_note)
	Juice.bounce_in(_page)


func _draw_page() -> void:
	var r := Rect2(Vector2.ZERO, PAGE.size)
	_page.draw_rect(Rect2(r.position + Vector2(0, 8), r.size), Color(0, 0, 0, 0.3))
	_page.draw_rect(r, Palette.PAPER)
	_page.draw_rect(r, Palette.INK, false, 4.0)
	var f := UiKit.font(700)
	_page.draw_string(f, Vector2(30, 56), "MASKING SCHOOL: MY CHEAT SHEETS", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.INK)
	_page.draw_string(UiKit.font(600), Vector2(32, 86), "Why, when and how much to mask, and the occlusion effect. Five cards, one page.",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_SOFT)
	var exam := TrainingProgress.station(MaskDeck.LESSON, "exam")
	var slot := Vector2(30 + 2 * 354 + 165, 104 + 200 + 86)
	if int(exam["best"]) >= 0:
		Diploma.draw(_page, slot, 1.25, MaskDeck.exam_grade(int(exam["best"])))
	else:
		_page.draw_string(f, slot + Vector2(-165, -6), "The exam's diploma", HORIZONTAL_ALIGNMENT_CENTER, 330, 20, Palette.INK_SOFT)
		_page.draw_string(UiKit.font(600), slot + Vector2(-165, 20), "stamps here (Station 6)", HORIZONTAL_ALIGNMENT_CENTER, 330, 17, Palette.INK_SOFT)
	_page.draw_string(UiKit.font(600), Vector2(30, r.size.y - 20), "Booth Camp: a learning game. The real rules come from your training and your clinic.",
		HORIZONTAL_ALIGNMENT_LEFT, PAGE.size.x - 520, 14, Palette.INK_SOFT)


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and (k.keycode == KEY_P or k.physical_keycode == KEY_P):
		close_view()
	elif event.is_action_pressed(&"ui_accept"):
		close_view()
	else:
		return
	get_viewport().set_input_as_handled()


func close_view() -> void:
	if _busy or not is_inside_tree():
		return
	Sfx.play(&"click")
	closed.emit()
	queue_free()


## The page as a PNG: the buttons step aside for one drawn frame, then the page's pixels are saved.
func save_picture() -> void:
	if _busy:
		return
	_busy = true
	Sfx.play(&"click")
	_buttons.visible = false
	_note.text = ""
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image() if is_inside_tree() else null
	_buttons.visible = true
	_busy = false
	if img == null or img.is_empty():
		_note.text = "This screen can't take pictures here. A screenshot works too!"
		return
	var vp := get_viewport_rect().size
	var scale := Vector2(img.get_size()) / vp
	var at := (get_global_transform_with_canvas() * PAGE.position) * scale
	var crop := Rect2i(Vector2i(at), Vector2i(PAGE.size * scale)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var page := img.get_region(crop)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(page.save_png_to_buffer(), FILE_NAME, "image/png")
		saved_to = "download"
		_note.text = "Downloaded %s: open it and print!" % FILE_NAME
		return
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join("BoothCamp")
	if dir == "BoothCamp" or DirAccess.make_dir_recursive_absolute(dir) != OK:
		dir = OS.get_user_data_dir()
	var path := dir.path_join(FILE_NAME)
	if page.save_png(path) != OK:
		path = OS.get_user_data_dir().path_join(FILE_NAME)
		if page.save_png(path) != OK:
			_note.text = "Couldn't save the picture. A screenshot works too!"
			return
	saved_to = path
	_note.text = "Saved: %s" % path
	Sfx.play(&"ding", 1.2, -8.0)
