extends Control
## OeChip (training, story-internal): the small orange "OE" chip on the AudiOtron's MASKING group
## (docs/training/MASKING_TRAINER.md question 7). It shows on the story days once the player has earned
## the Occlusion Pocket Card in Masking School; a click (or tap) opens the card above the deck, another
## click closes it. A reminder, not an answer: it never reads the live test, so the start level is still
## the player's to set. The AudiOtron adds it (ui/audiometer/audiometer_screen.gd, additive) and places
## it at the right end of the MASKING label.

const UiKit := preload("res://story/ui_kit.gd")
const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")

const CHIP := Vector2(46, 20)
const CARD := Vector2(330, 160)

var _card: CheatCard


## The Occlusion Pocket Card is earned (read without touching the save).
static func earned() -> bool:
	var tr: Variant = Game.progress.get("training", {})
	if not tr is Dictionary or not (tr as Dictionary).get(MaskDeck.LESSON, null) is Dictionary:
		return false
	var cards: Variant = ((tr as Dictionary)[MaskDeck.LESSON] as Dictionary).get("cards", [])
	return cards is Array and (cards as Array).has("occlusion")


func _ready() -> void:
	name = "oe_chip"
	size = CHIP
	custom_minimum_size = CHIP
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = ""
	visibility_changed.connect(func() -> void:
		if not visible:
			close_card())


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, 2), r.size), Color(0, 0, 0, 0.3), 10)
	UiDraw.rounded_rect(self, r, Color("#ff9f1c") if not is_open() else Palette.SUNNY, 10, 2, Palette.INK)
	draw_string(UiKit.font(700), Vector2(0, 15), "OE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Palette.INK)


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()


func is_open() -> bool:
	return _card != null and is_instance_valid(_card)


func toggle() -> void:
	if is_open():
		close_card()
	else:
		open_card()


## The pocket card, above the chip and inside the window.
func open_card() -> void:
	if is_open():
		return
	Sfx.play(&"pop", 1.1, -10.0)
	_card = CheatCard.new(MaskDeck.cheat_card("occlusion"), true, 18)
	_card.name = "oe_card"
	_card.size = CARD
	_card.top_level = true
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_card)
	var at := global_position + Vector2(size.x * 0.5 - CARD.x * 0.5, -CARD.y - 14)
	var vp := get_viewport_rect().size
	_card.global_position = Vector2(clampf(at.x, 8, vp.x - CARD.x - 8), maxf(8, at.y))
	queue_redraw()


func close_card() -> void:
	if is_open():
		_card.queue_free()
	_card = null
	queue_redraw()
