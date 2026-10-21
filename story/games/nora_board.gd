extends Control
## NoraBoard (Day 4): the Red-Flag Roll Call, then the stamp tray and the referral letter
## (docs/CHAPTER4.md §7). A new board: case_board.gd binds its beats to a case file and
## mike_board.gd is one OBJECTION drag, so neither fits; this one reuses CaseRules' decisions and
## stamps, and case_board.gd's STAMP_COLORS by reference (never a copy). No shared file changes.
##  1. The Roll Call: nine clue cards step onto a podium one at a time, between two choir risers:
##     RED FLAG (right) and FINE (left). Right (speech_correct, the key that scored "repeated") or
##     the RED FLAG button sends a card to the flag riser; Left (speech_incorrect) or FINE to the
##     fine riser. A right sort climbs one note up a scale drawn on a staff, with Hoot's caption for
##     that card; a wrong sort bounces the card back with a cracked note (drawn), Hoot's line, and
##     the first time Nora's wince. Every card is a decision: nothing completes by itself, and there
##     is no count of what is left.
##  2. The stamp tray: FIT / REFER / DOCTOR TODAY under Nora's file, the stock choice beat.
##  3. The letter: printed on a sheet of manuscript paper, signed with a baton flourish (a
##     treble-clef squiggle), then it slides into an envelope for the EAR DOCTOR (a fade with
##     reduced motion).
## Story-internal:
##   var b := NoraBoard.new(); b.setup(cards); hud.add_game(b)
##     # cards [{id, text, flag, src, right_line, wrong_line}], in roll-call order
##   await b.run_roll_call()            # beat flag_pick per card; b.slips, b.sorted
##   await b.open_tray()                # the roll call steps aside; Nora's file and the stamps
##   var i: int = await b.choose_stamp(prompt, best)   # beat "choice": index into CaseRules.DECISIONS
##   await b.slam(decision, right)      # right: it lands and stays; wrong: it bounces off, greyed
##   await b.show_letter(text)          # the signed score slides into its envelope
##   await b.fade_out()
## Beat flag_pick: info {card, remaining, mouse: {click: "flag_yes_button" | "flag_no_button"}} (the
## button of the right sort); the solver presses speech_correct or speech_incorrect.
## Anchors: flag_yes_button, flag_no_button, flag_podium, case_stamps, referral_letter.
## Every line keeps to 18 words; keys are named only through {key:<action>} (filled by _k()).
## Nothing here plays a sound louder than the shared Sfx; the scale and the cracked note are drawn.

signal _sorted(flag: bool)
signal _picked(index: int)

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const CaseBoard := preload("res://story/games/case_board.gd")

const TITLE := "RED-FLAG ROLL CALL"
const WINCE := "Ooh. A sour one."
const CARD_SIZE := Vector2(440, 132)
## The card's top-left on the podium, and where it waits in the wings.
const PODIUM_AT := Vector2(420, 250)
const WINGS_AT := Vector2(420, 760)
## The rising scale: a five-line staff; each right sort adds the next note up.
const STAFF := Rect2(410, 176, 470, 56)
const NOTE_STEP_X := 46.0
## Choir risers: four steps each, two singers (sorted cards, shrunk to tags) per step.
const RISER_FINE := Rect2(48, 282, 340, 216)
const RISER_FLAG := Rect2(892, 282, 340, 216)
const RISER_ROWS := 4
const TAG_SCALE := 0.36
const BUTTON_SIZE := Vector2(200, 76)
const BUTTONS_Y := 404.0
const CAPTION_Y := 556.0
const NORA_AT := Vector2(112, 190)
const NORA_R := 42.0
## A major scale, in semitones above the first note (the A flat is kept for the door).
const SCALE: Array[int] = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16]
const NOTE_HZ := 392.0
const FLAG_COLOR := Color("#e5383b")
const FINE_COLOR := Color("#2f9e73")
const WOOD := Color("#c98a3a")
const WOOD_DARK := Color("#8a5a24")
const SRC_TITLES: Dictionary = {"history": "SHE SAID", "tones": "AUDIOGRAM", "words": "WORD LISTS", "look": "OTOSCOPE", "srt": "SRT VS PTA"}
const SRC_COLORS: Dictionary = {"history": Color("#fff1a8"), "tones": Color("#ffd9e8"), "words": Color("#dbe9ff"), "look": Color("#d6f5e3"), "srt": Color("#e9e1ff")}
## Nora's file on the stamp tray: the flags the player raised, by card id.
const FLAG_NAMES: Dictionary = {"hiss": "one-sided hiss", "wobbly": "wobbly stairs", "tones": "tones asymmetric",
	"apart": "words far apart", "predicted": "words below prediction", "louder": "rollover"}
const TRAY_Y := 336.0
const STAMP_SIZE := Vector2(300, 112)
const FILE := Rect2(340, 140, 600, 168)
## The letter: the sheet, the signature's stroke, then the slide into the envelope.
const SHEET := Rect2(300, 136, 680, 326)
const ENVELOPE := Rect2(500, 470, 280, 150)
const SIGN_FROM_S := 0.5
const SIGN_S := 1.0
const SLIDE_AT_S := 2.4
const SLIDE_S := 0.9

## The Roll Call's results: wrong sorts, and the cards in the order they were sorted right.
var slips := 0
var sorted: Array[String] = []
var cards: Array[Dictionary] = []

var _stage: StringName = &"roll"
var _cur := -1
var _accepting := false
var _notes := 0
var _note_t := -1.0
var _crack_t := -1.0
var _wince_t := -1.0
var _winced := false
var _placed: Dictionary = {}       # side -> count of tags on that riser
var _nodes: Array[PanelContainer] = []
var _t := 0.0
var _mode := ""                     # "stamp" while waiting for a stamp
var _stamps: Array[Button] = []
var _stamp_dead: Dictionary = {}
var _slam: StringName = &""
var _slam_t := -1.0
var _letter_t := -1.0

var _art: Control
var _fx: Control
var _head: Label
var _hints: HBoxContainer
var _caption: Label
var _yes: Button
var _no: Button
var _podium_anchor: Control
var _cards_layer: Control
var _tray: Control
var _file_label: Label
var _letter: PanelContainer
var _letter_label: Label


func setup(p_cards: Array[Dictionary]) -> void:
	cards = p_cards.duplicate(true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_art = UiKit.full_rect()
	_art.name = "Art"
	_art.draw.connect(_draw_art)
	add_child(_art)
	_head = UiKit.label(TITLE, 34, Palette.INK, 700)
	_head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_head.offset_top = 84
	_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_head)
	_hints = HBoxContainer.new()
	_hints.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hints.offset_top = 128
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	_podium_anchor = Control.new()
	_podium_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podium_anchor.position = PODIUM_AT
	_podium_anchor.size = CARD_SIZE
	add_child(_podium_anchor)
	Hoot.register_anchor("flag_podium", _podium_anchor)
	_cards_layer = UiKit.full_rect()
	_cards_layer.name = "Cards"
	add_child(_cards_layer)
	_no = _make_button("flag_no_button", "FINE", FINE_COLOR, Vector2(640.0 - 12.0 - BUTTON_SIZE.x, BUTTONS_Y), &"speech_incorrect")
	_yes = _make_button("flag_yes_button", "RED FLAG", FLAG_COLOR, Vector2(640.0 + 12.0, BUTTONS_Y), &"speech_correct")
	_caption = UiKit.label("", 20, Palette.INK, 600)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(270, CAPTION_Y)
	_caption.size = Vector2(740, 60)
	add_child(_caption)
	_tray = UiKit.full_rect()
	_tray.name = "Tray"
	_tray.visible = false
	add_child(_tray)
	_build_tray()
	_build_letter()
	_fx = UiKit.full_rect()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_sync_buttons()


func _make_button(id: String, text: String, col: Color, at: Vector2, action: StringName) -> Button:
	var b := Button.new()
	b.name = id
	b.text = text + (("  " + _k(action)) if UiKit.show_key_hints() else "")
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.position = at
	b.size = BUTTON_SIZE
	b.custom_minimum_size = BUTTON_SIZE
	b.pivot_offset = BUTTON_SIZE * 0.5
	b.add_theme_font_override("font", UiKit.font(700))
	b.add_theme_font_size_override("font_size", 24)
	for st: String in ["normal", "focus"]:
		b.add_theme_stylebox_override(st, UiKit.style(col, Palette.INK, 18, 3, 6, 10))
	b.add_theme_stylebox_override("hover", UiKit.style(col.lightened(0.12), Palette.INK, 18, 3, 8, 10))
	b.add_theme_stylebox_override("pressed", UiKit.style(col.darkened(0.12), Palette.INK, 18, 3, 2, 10))
	b.add_theme_stylebox_override("disabled", UiKit.style(Color(col, 0.45), Color(Palette.INK, 0.5), 18, 3, 0, 10))
	for c: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Palette.PAPER)
	b.add_theme_color_override("font_disabled_color", Color(Palette.PAPER, 0.8))
	b.add_theme_constant_override("outline_size", 6)
	b.add_theme_color_override("font_outline_color", Color(Palette.INK, 0.55))
	b.pressed.connect(_press.bind(action))
	add_child(b)
	Hoot.register_anchor(id, b)
	return b


## The key chip of an input action ("[Right]"), in the current bindings.
static func _k(action: StringName) -> String:
	var label := Game.key_label(action)
	return "[%s]" % ("SPACE" if label == "Space" else label)


## A line with every {key:<action>} filled by its key chip.
static func fill_keys(text: String) -> String:
	var at := text.find("{key:")
	while at >= 0:
		var end := text.find("}", at)
		if end < 0:
			break
		text = text.substr(0, at) + _k(StringName(text.substr(at + 5, end - at - 5))) + text.substr(end + 1)
		at = text.find("{key:")
	return text


func _sync_buttons() -> void:
	for b: Button in [_yes, _no]:
		b.disabled = not _accepting
		b.visible = _stage == &"roll"


func _set_hints(on: bool) -> void:
	for c in _hints.get_children():
		c.queue_free()
	if not on:
		return
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_panel([[Game.key_label(&"speech_correct")], "or click RED FLAG", "   ", [Game.key_label(&"speech_incorrect")], "or click FINE"], 16))
	else:
		_hints.add_child(UiKit.hint_panel(["Click RED FLAG or FINE"], 16))


# ---------------------------------------------------------------- 1. the Roll Call

## (coroutine) Nine flag_pick beats, one card at a time; a wrong sort bounces the card back.
func run_roll_call() -> void:
	_stage = &"roll"
	_set_hints(true)
	for i in cards.size():
		_cur = i
		var c: Dictionary = cards[i]
		var node := _make_card(c)
		await _step_up(node)
		var right := bool(c.get("flag", false))
		while true:
			_accepting = true
			_sync_buttons()
			Events.awaiting_input.emit(&"flag_pick", {"card": String(c.get("id", "")), "remaining": cards.size() - i,
				"mouse": {"click": "flag_yes_button" if right else "flag_no_button"}},
				_press.bind(&"speech_correct" if right else &"speech_incorrect"))
			var said: bool = await _sorted
			_accepting = false
			_sync_buttons()
			Events.input_resolved.emit(&"flag_pick")
			if said == right:
				await _sort_right(c, node)
				break
			slips += 1
			await _sort_wrong(c, node, said)
	_cur = -1
	_set_hints(false)


## RED FLAG (speech_correct) or FINE (speech_incorrect), by key, button or the beat's solver.
func _press(action: StringName) -> void:
	if not _accepting:
		return
	_accepting = false
	var flag := action == &"speech_correct"
	var b := _yes if flag else _no
	Juice.pop(b, 1.1, 0.18)
	Sfx.play(&"click", 1.0, -6.0)
	_sorted.emit(flag)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _accepting:
		if event.is_action_pressed(&"speech_correct"):
			_press(&"speech_correct")
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"speech_incorrect"):
			_press(&"speech_incorrect")
			get_viewport().set_input_as_handled()
		return
	if _mode != "stamp" or not (event is InputEventKey):
		return
	var k := (event as InputEventKey).keycode
	if k < KEY_1 or k > KEY_9:
		k = (event as InputEventKey).physical_keycode
	var i := -1
	if k >= KEY_1 and k <= KEY_9:
		i = k - KEY_1
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		i = k - KEY_KP_1
	if i >= 0 and i < _stamps.size():
		_pick(i)
		get_viewport().set_input_as_handled()


func _make_card(c: Dictionary) -> PanelContainer:
	var src := String(c.get("src", "history"))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.style(SRC_COLORS.get(src, Palette.PAPER), Palette.INK, 18, 3, 8, 14))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.custom_minimum_size = CARD_SIZE
	p.size = CARD_SIZE
	p.pivot_offset = CARD_SIZE * 0.5
	p.position = WINGS_AT
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var head := UiKit.label(String(SRC_TITLES.get(src, "CLUE")), 14, Palette.INK_SOFT, 700)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var l := UiKit.label(String(c.get("text", "")), 25, Palette.INK, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CARD_SIZE.x - 40.0, 0)
	v.add_child(l)
	_cards_layer.add_child(p)
	_nodes.append(p)
	return p


## The next card walks out of the wings onto the podium.
func _step_up(node: PanelContainer) -> void:
	var t := node.create_tween()
	if _reduced():
		node.position = PODIUM_AT
		node.modulate.a = 0.0
		t.tween_property(node, "modulate:a", 1.0, 0.2)
	else:
		t.tween_property(node, "position", PODIUM_AT, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"whoosh", 1.2, -14.0)
	await t.finished


## Where the next tag on a riser stands (top-left of the shrunk card).
func _slot(flag: bool) -> Vector2:
	var side := "flag" if flag else "fine"
	var n := int(_placed.get(side, 0))
	_placed[side] = n + 1
	var r := RISER_FLAG if flag else RISER_FINE
	var row := mini(n / 2, RISER_ROWS - 1)
	var col := n % 2
	var tag := CARD_SIZE * TAG_SCALE
	var step_h := r.size.y / RISER_ROWS
	var y := r.position.y + step_h * row + step_h - tag.y - 6.0
	var x := r.position.x + 14.0 + col * (tag.x + 10.0)
	# the card scales about its centre: its top-left sits off by the shrink
	return Vector2(x, y) - CARD_SIZE * (1.0 - TAG_SCALE) * 0.5


func _sort_right(c: Dictionary, node: PanelContainer) -> void:
	var flag := bool(c.get("flag", false))
	sorted.append(String(c.get("id", "")))
	var to := _slot(flag)
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "position", to, 0.3 if _reduced() else 0.42).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE * TAG_SCALE, 0.3 if _reduced() else 0.42)
	Sfx.play(&"note", NOTE_HZ * pow(2.0, SCALE[mini(_notes, SCALE.size() - 1)] / 12.0) / Sfx.NOTE_BASE_HZ, -10.0)
	_notes += 1
	_note_t = 0.0
	_show_caption(String(c.get("right_line", "")), FINE_COLOR.darkened(0.2) if not flag else FLAG_COLOR.darkened(0.2))
	await t.finished
	await _wait(0.25)


func _sort_wrong(c: Dictionary, node: PanelContainer, said_flag: bool) -> void:
	_crack_t = 0.0
	Sfx.play(&"thunk", 0.55, -8.0)
	_show_caption(String(c.get("wrong_line", "")), Palette.INK)
	if not _winced:
		_winced = true
		_wince_t = 0.0
	if _reduced():
		node.modulate.a = 0.5
		var tr := node.create_tween()
		tr.tween_property(node, "modulate:a", 1.0, 0.3)
		await tr.finished
	else:
		var lean := Vector2(150.0 if said_flag else -150.0, 40.0)
		var t := node.create_tween()
		t.tween_property(node, "position", PODIUM_AT + lean, 0.16).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "position", PODIUM_AT, 0.36).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await t.finished
	await _wait(0.5)


func _show_caption(text: String, col: Color) -> void:
	_caption.text = "HOOT: " + fill_keys(text)
	_caption.add_theme_color_override("font_color", col)
	Juice.pop(_caption, 1.05, 0.2)


# ---------------------------------------------------------------- 2. the stamp tray

## (coroutine) The roll call steps aside: Nora's file with the flags raised, and the three stamps.
func open_tray() -> void:
	var raised: PackedStringArray = []
	for c: Dictionary in cards:
		if bool(c.get("flag", false)) and FLAG_NAMES.has(String(c.get("id", ""))):
			raised.append(String(FLAG_NAMES[String(c["id"])]))
	_file_label.text = "NORA NIGHTINGALE, 58  -  CHOIR DIRECTOR\nLeft ear: voices, but not words.\nRED FLAGS: %s" % (", ".join(raised) if not raised.is_empty() else "none")
	var t := create_tween().set_parallel(true)
	for n: Control in _nodes + [_yes, _no, _caption]:
		t.tween_property(n, "modulate:a", 0.0, 0.25)
	await t.finished
	for n: Control in _nodes:
		n.visible = false
	_caption.text = ""
	_caption.modulate.a = 1.0
	_stage = &"tray"
	_sync_buttons()
	_tray.visible = true
	_head.text = "YOUR CALL"
	for s: Button in _stamps:
		Juice.bounce_in(s, 0.35)
	Sfx.play(&"pen", 1.0, -12.0)
	await _wait(0.4)


## (coroutine) Beat "choice": pick a rubber stamp (click, keys 1-3). Returns the CaseRules.DECISIONS index.
func choose_stamp(prompt: String, best: int) -> int:
	_head.text = prompt.to_upper()
	var opts: Array[String] = []
	for d: StringName in CaseRules.DECISIONS:
		opts.append(CaseRules.DECISION_STAMPS[d])
	for c in _hints.get_children():
		c.queue_free()
	_hints.add_child(UiKit.hint_panel([["1"], "-", [str(opts.size())], "or click a stamp"] if UiKit.show_key_hints() else ["Click a stamp"], 16))
	_mode = "stamp"
	Events.awaiting_input.emit(&"choice", {"prompt": prompt, "options": opts, "best": best}, func() -> void: _pick(best))
	var i: int = await _picked
	Events.input_resolved.emit(&"choice")
	return i


func _pick(i: int) -> void:
	if _mode != "stamp" or i < 0 or i >= _stamps.size() or _stamp_dead.has(i):
		return
	_mode = ""
	Sfx.play(&"click")
	for c in _hints.get_children():
		c.queue_free()
	Juice.pop(_stamps[i], 1.08, 0.15)
	_picked.emit(i)


## (coroutine) The stamp comes down on Nora's file: right = it lands and stays, wrong = it bounces
## off with a "?" and that stamp goes grey.
func slam(decision: StringName, right: bool) -> void:
	_slam = decision
	_slam_t = 0.0
	var i := CaseRules.DECISIONS.find(decision)
	if not right and i >= 0:
		_stamp_dead[i] = true
		_stamps[i].disabled = true
		Sfx.play(&"boing", 0.9, -6.0)
	else:
		Sfx.play(&"stamp", 0.7, 0.0)
	await _wait(0.7)
	if not right:
		_slam = &""
		_slam_t = -1.0


func _build_tray() -> void:
	var file := UiKit.panel(Palette.PAPER, Palette.INK, 16)
	file.mouse_filter = Control.MOUSE_FILTER_IGNORE
	file.position = FILE.position
	file.custom_minimum_size = FILE.size
	file.size = FILE.size
	_tray.add_child(file)
	_file_label = UiKit.label("", 19, Palette.INK, 600)
	_file_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_file_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	file.add_child(_file_label)
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total := STAMP_SIZE.x * 3 + 30.0 * 2
	anchor.position = Vector2((1280.0 - total) * 0.5, TRAY_Y)
	anchor.size = Vector2(total, STAMP_SIZE.y)
	_tray.add_child(anchor)
	Hoot.register_anchor("case_stamps", anchor)
	for i in CaseRules.DECISIONS.size():
		var d: StringName = CaseRules.DECISIONS[i]
		var col: Color = CaseBoard.STAMP_COLORS[d]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = anchor.position + Vector2(i * (STAMP_SIZE.x + 30.0), 0)
		b.size = STAMP_SIZE
		b.pivot_offset = STAMP_SIZE * 0.5
		b.draw.connect(_draw_stamp_button.bind(b, i))
		b.pressed.connect(func() -> void:
			if _mode == "stamp":
				_pick(i))
		var big := UiKit.label(CaseRules.DECISION_STAMPS[d], 34 if i < 2 else 26, col, 700)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.position = Vector2(0, 26)
		big.size = Vector2(STAMP_SIZE.x, 40)
		b.add_child(big)
		var sub := UiKit.label(CaseRules.decision_title(d), 15, Palette.INK_SOFT, 600)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.position = Vector2(0, 72)
		sub.size = Vector2(STAMP_SIZE.x, 22)
		b.add_child(sub)
		_tray.add_child(b)
		_stamps.append(b)


func _draw_stamp_button(b: Button, i: int) -> void:
	var d: StringName = CaseRules.DECISIONS[i]
	var col: Color = CaseBoard.STAMP_COLORS[d]
	var dead := _stamp_dead.has(i)
	var r := Rect2(Vector2.ZERO, STAMP_SIZE)
	UiDraw.rounded_rect(b, r.grow(-4), Color(Palette.PAPER, 0.96) if not dead else Color("#e6e1d6"), 16, 4,
		col if not dead else Color(Palette.INK, 0.3))
	if b.is_hovered() and not dead and _mode == "stamp":
		UiDraw.rounded_rect(b, r.grow(-10), Color(col, 0.08), 12, 2, Color(col, 0.5))


# ---------------------------------------------------------------- 3. the letter

func _build_letter() -> void:
	_letter = PanelContainer.new()
	var sb := UiKit.style(Color("#fffdf6"), Palette.INK, 10, 3, 10, 26)
	sb.content_margin_top = 34
	sb.content_margin_bottom = 64
	_letter.add_theme_stylebox_override("panel", sb)
	_letter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letter.position = SHEET.position
	_letter.custom_minimum_size = SHEET.size
	_letter.size = SHEET.size
	_letter.pivot_offset = SHEET.size * 0.5
	_letter.visible = false
	_letter.draw.connect(_draw_manuscript)
	add_child(_letter)
	Hoot.register_anchor("referral_letter", _letter)
	_letter_label = UiKit.label("", 17, Palette.INK, 600)
	_letter_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_letter_label.custom_minimum_size = Vector2(SHEET.size.x - 52.0, 0)
	_letter.add_child(_letter_label)


## (coroutine) The letter on manuscript paper; Nora signs it with a baton flourish, and it slides
## into the EAR DOCTOR envelope (a fade with reduced motion).
func show_letter(text: String) -> void:
	_letter_label.text = text
	_letter.visible = true
	_letter.modulate.a = 0.0
	_letter.scale = Vector2.ONE
	_letter.position = SHEET.position
	_tray.visible = false
	_head.text = "THE REFERRAL"
	_stage = &"letter"
	_letter_t = 0.0
	var t := _letter.create_tween()
	t.tween_property(_letter, "modulate:a", 1.0, 0.3)
	await _wait(SIGN_FROM_S)
	Sfx.play(&"pen", 1.2, -10.0)
	await _wait(SLIDE_AT_S - SIGN_FROM_S)
	var into := ENVELOPE.get_center() - SHEET.size * 0.5
	var s := _letter.create_tween().set_parallel(true)
	if _reduced():
		s.tween_property(_letter, "modulate:a", 0.0, SLIDE_S)
	else:
		s.tween_property(_letter, "position", into, SLIDE_S).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		s.tween_property(_letter, "scale", Vector2.ONE * 0.22, SLIDE_S).set_trans(Tween.TRANS_SINE)
	Sfx.play(&"whoosh", 0.9, -12.0)
	await s.finished
	_letter.visible = false
	Sfx.play(&"stamp", 1.3, -10.0)
	await _wait(0.8)


## The manuscript paper: faint staves behind the text, and the signature's stroke.
func _draw_manuscript() -> void:
	var w := SHEET.size.x
	for st in 4:
		var y0 := 40.0 + st * 74.0
		for k in 5:
			var y := y0 + k * 7.0
			_letter.draw_line(Vector2(18, y), Vector2(w - 18, y), Color("#9fb6d9", 0.35), 1.0)
	var sign_k := clampf((_letter_t - SIGN_FROM_S) / SIGN_S, 0.0, 1.0)
	if sign_k > 0.0:
		var pts := _signature_points(Vector2(w - 230, SHEET.size.y - 46), 1.0)
		var n := maxi(2, int(pts.size() * sign_k))
		_letter.draw_polyline(pts.slice(0, n), Color("#1f2f5c"), 3.0, true)
		_letter.draw_string(UiKit.font(600), Vector2(w - 170, SHEET.size.y - 22), "Nora Nightingale", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#1f2f5c", sign_k))


## A treble-clef squiggle: a spiral round the staff's G line, a loop up, then a tail with a dot.
static func _signature_points(at: Vector2, s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 40:
		var a := lerpf(0.0, TAU * 1.6, i / 39.0)
		var rad := lerpf(4.0, 18.0, i / 39.0) * s
		pts.append(at + Vector2(cos(a) * rad, sin(a) * rad))
	var top := at + Vector2(10, -44) * s
	for i in 16:
		var k := i / 15.0
		pts.append(pts[pts.size() - 1].lerp(top, 0.25) if i == 0 else at.lerp(top, k) + Vector2(sin(k * PI) * 16.0, 0) * s)
	for i in 14:
		var k := i / 13.0
		pts.append(top.lerp(at + Vector2(-4, 34) * s, k) + Vector2(-sin(k * PI) * 10.0, 0) * s)
	# the flourish: a long underline swish to the right
	for i in 12:
		var k := i / 11.0
		pts.append(at + Vector2(-4 + k * 150.0, 34 + sin(k * PI) * 6.0) * s)
	return pts


## (coroutine) Fade the whole board away.
func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished


# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	_t += delta
	for v: String in ["_note_t", "_crack_t", "_wince_t", "_slam_t", "_letter_t"]:
		var x: float = get(v)
		if x >= 0.0:
			set(v, x + delta)
	_art.queue_redraw()
	_fx.queue_redraw()
	if _letter.visible:
		_letter.queue_redraw()
	for b: Button in _stamps:
		b.queue_redraw()


func _draw_art() -> void:
	if _stage == &"roll":
		_draw_staff()
		_draw_riser(RISER_FINE, false)
		_draw_riser(RISER_FLAG, true)
		_draw_podium()
		_draw_nora()
	elif _stage == &"letter":
		_draw_envelope()


func _draw_staff() -> void:
	var gap := STAFF.size.y / 4.0
	for k in 5:
		var y := STAFF.position.y + k * gap
		_art.draw_line(Vector2(STAFF.position.x, y), Vector2(STAFF.end.x, y), Color(Palette.INK, 0.55), 2.0)
	# a little clef curl at the left
	var c := Vector2(STAFF.position.x + 22, STAFF.position.y + gap * 3)
	_art.draw_polyline(_signature_points(c, 0.55), Palette.INK, 2.5, true)
	for i in _notes:
		_draw_note(i, Palette.INK, i == _notes - 1)
	if _crack_t >= 0.0 and _crack_t < 1.4:
		_draw_cracked(_notes)


## Note i of the scale: one half-gap higher than the last.
func _note_pos(i: int) -> Vector2:
	var half := STAFF.size.y / 8.0
	return Vector2(STAFF.position.x + 70.0 + i * NOTE_STEP_X, STAFF.end.y + half * 1.0 - i * half)


func _draw_note(i: int, col: Color, fresh: bool) -> void:
	var p := _note_pos(i)
	var sc := 1.0
	if fresh and _note_t >= 0.0 and _note_t < 0.3 and not _reduced():
		sc = 1.0 + 0.5 * (1.0 - _note_t / 0.3)
	var rx := 9.0 * sc
	var ry := 6.5 * sc
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(p + Vector2(cos(a) * rx, sin(a) * ry).rotated(-0.35))
	_art.draw_colored_polygon(pts, col)
	_art.draw_line(p + Vector2(rx - 1.0, -1.0), p + Vector2(rx - 1.0, -34.0 * sc), col, 2.5)
	# a ledger line for notes off the staff
	if p.y > STAFF.end.y + 1.0:
		_art.draw_line(p + Vector2(-14, 0), p + Vector2(14, 0), Color(Palette.INK, 0.55), 2.0)


## The cracked note: grey, with a zigzag through the head, and a drawn "clunk".
func _draw_cracked(i: int) -> void:
	var p := _note_pos(i) + Vector2(0, 10)
	var col := Color("#8a8f99")
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(p + Vector2(cos(a) * 10.0, sin(a) * 7.0).rotated(-0.35))
	_art.draw_colored_polygon(pts, col)
	_art.draw_line(p + Vector2(9.0, -1.0), p + Vector2(14.0, -30.0), col, 2.5)
	_art.draw_polyline(PackedVector2Array([p + Vector2(-6, -7), p + Vector2(-1, -1), p + Vector2(-5, 2), p + Vector2(2, 8)]), Palette.PAPER, 2.0, true)
	_art.draw_string(UiKit.font(700), p + Vector2(20, -12), "CLUNK", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(col, clampf(1.4 - _crack_t, 0.0, 1.0)))


## A choir riser: four wooden steps climbing to the outside, its sign at the foot.
func _draw_riser(r: Rect2, flag: bool) -> void:
	var step_h := r.size.y / RISER_ROWS
	for row in RISER_ROWS:
		# the top step (row 0) is the narrowest, toward the outer edge
		var inset := (RISER_ROWS - 1 - row) * 0.0
		var sr := Rect2(r.position.x + inset, r.position.y + step_h * row + step_h - 12.0, r.size.x - inset, 14.0)
		UiDraw.rounded_rect(_art, sr, WOOD if row % 2 == 0 else WOOD.lightened(0.08), 5, 2, WOOD_DARK)
	var col := FLAG_COLOR if flag else FINE_COLOR
	var sign := Rect2(r.position.x + r.size.x * 0.5 - 92.0, r.end.y + 6.0, 184.0, 40.0)
	UiDraw.rounded_rect(_art, sign, col, 12, 3, Palette.INK)
	var f := UiKit.font(700)
	var text := "RED FLAG" if flag else "FINE"
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var icon_w := 26.0
	var x0 := sign.get_center().x - (tw + icon_w) * 0.5
	_art.draw_string(f, Vector2(x0 + icon_w, sign.position.y + 29.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.PAPER)
	var ic := Vector2(x0 + 8.0, sign.get_center().y)
	if flag:
		# a little flag on a pole
		_art.draw_line(ic + Vector2(0, 12), ic + Vector2(0, -12), Palette.PAPER, 3.0)
		_art.draw_colored_polygon(PackedVector2Array([ic + Vector2(1, -12), ic + Vector2(15, -7), ic + Vector2(1, -2)]), Palette.PAPER)
	else:
		# a tick
		_art.draw_polyline(PackedVector2Array([ic + Vector2(-4, 0), ic + Vector2(2, 7), ic + Vector2(14, -8)]), Palette.PAPER, 4.0, true)


func _draw_podium() -> void:
	var top := PODIUM_AT + Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y + 4.0)
	var pts := PackedVector2Array([top + Vector2(-120, 0), top + Vector2(120, 0), top + Vector2(96, 20), top + Vector2(-96, 20)])
	_art.draw_colored_polygon(pts, WOOD)
	_art.draw_polyline(pts + PackedVector2Array([pts[0]]), WOOD_DARK, 2.0, true)


## Nora at the corner of the stage, and her wince after the first wrong sort.
func _draw_nora() -> void:
	var talking := _wince_t >= 0.0 and _wince_t < 2.4
	Portraits.draw(_art, "Nora", NORA_AT, NORA_R, talking and fmod(_t, 0.3) < 0.15, false)
	if not talking:
		return
	var f := UiKit.font(700)
	var tw := f.get_string_size(WINCE, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	var r := Rect2(NORA_AT + Vector2(NORA_R + 14.0, -26.0), Vector2(tw + 26.0, 40.0))
	UiDraw.rounded_rect(_art, r, Palette.PAPER, 14, 3, Palette.INK)
	_art.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, 16), r.position + Vector2(-12, 26), r.position + Vector2(0, 28)]), Palette.INK)
	_art.draw_string(f, r.position + Vector2(13, 27), WINCE, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Palette.INK)


func _draw_envelope() -> void:
	var r := ENVELOPE
	UiDraw.rounded_rect(_art, r, Color("#f3e3c3"), 8, 3, Palette.INK)
	var closed := not _letter.visible
	var flap_tip := r.position + Vector2(r.size.x * 0.5, r.size.y * (0.55 if closed else -0.35))
	var flap := PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), flap_tip])
	_art.draw_colored_polygon(flap, Color("#e8d2a6"))
	_art.draw_polyline(flap + PackedVector2Array([flap[0]]), Palette.INK, 2.5, true)
	var f := UiKit.font(700)
	var text := "EAR DOCTOR"
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_art.draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.end.y - 22.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.INK)


func _draw_fx() -> void:
	if _slam == &"" or _stage != &"tray":
		return
	var col: Color = CaseBoard.STAMP_COLORS.get(_slam, FLAG_COLOR)
	var k := 1.0
	if _slam_t < 0.18 and not _reduced():
		k = 1.0 + 1.2 * (1.0 - _slam_t / 0.18)
	var text := String(CaseRules.DECISION_STAMPS.get(_slam, ""))
	var f := UiKit.font(700)
	var fs := int(54 * k)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var c := FILE.get_center() + Vector2(150, 18)
	_fx.draw_set_transform(c, -0.16, Vector2.ONE)
	var box := Rect2(Vector2(-tw * 0.5 - 18.0, -fs * 0.62), Vector2(tw + 36.0, fs * 1.1))
	_fx.draw_rect(box, Color(col, 0.12))
	_fx.draw_rect(box, col, false, 5.0)
	_fx.draw_string(f, Vector2(-tw * 0.5, fs * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
