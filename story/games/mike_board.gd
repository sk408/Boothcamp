extends Control
## Day 3 board (Speech): three moments on one cream board.
##  1. Familiarise: twelve spondee word cards flip over, a highlight sweeps along as Mike reads
##     them, the one he has never heard of wobbles with a "?", and the player drops it (crossed out).
##  2. OBJECTION!: Mike's claim card ("I can't hear ANYTHING") and three clue cards. Drag the
##     strongest clue onto the claim (or click it, then the claim; or 1-3 + Enter). The right one
##     slams a big OBJECTION! across the claim with a screen shake; the others get a kind Hoot tip.
##  3. The referral: the clues step aside for the dialogue choices, then RECHECK + OBJECTIVE TESTS
##     is stamped across the claim card.
## Story-internal:
##   var b := MikeBoard.new(); hud.add_game(b)
##   await b.run_cards(items)            # SpeechMaterial items; the cards flip in (no input)
##   await b.read_along(0, 5, 2.4)       # the highlight sweeps cards 0..5 while Mike reads them
##   b.stumble("windmill")               # wobble + "?"
##   await b.run_drop("windmill")        # beat familiarize_cards (solver drops it); b.drop_slips
##   b.show_objection(claim, clues)      # claim {quote, who, verdict}; clues [{id, title, sub, best, why}]
##   await b.run_objection()             # beat objection_present (solver presents the best clue); b.picks
##   b.set_referral_mode(true)           # the clue column steps aside, the claim card shrinks left
##   await b.run_stamp()                 # beat referral_stamp (solver stamps)
## Anchors: word_card_<id> (every card), objection_claim, clue_<id> (every clue), referral_stamp.
## Every motion respects Game.settings.reduced_motion (Juice does; the slam and rays check it).

signal _dropped
signal _presented
signal _stamped

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const CARD := Vector2(220, 92)
const COLUMNS := 4
const GAP := 16
const CARD_BACK := Color("#bfe6ff")
## Every clue looks the same until hovered or picked (colour must not give the answer away).
const CLUE_NEUTRAL := Color("#fffaf0")
const CLUE_PICK := Color("#ffe9a8")
const CLAIM_POS := Vector2(56, 132)
const CLAIM_W := 520.0
const CLUE_X := 640.0
const CLUE_W := 584.0

## Familiarisation results.
var dropped: Array[String] = []
var drop_slips := 0
## The objection: clue ids in the order they were presented, and whether the best one landed.
var picks: Array[String] = []
var solved := false
var stamped := false

var _items: Array[Dictionary] = []
var _cards: Dictionary = {}          # item id -> Control
var _order: Array[String] = []
var _flip: Dictionary = {}           # item id -> 0..1 (0 = back, 1 = front)
var _wobble: Dictionary = {}         # item id -> 1..0
var _reading := -1.0
var _stumbled := ""
var _drop_target := ""
var _drop_accepting := false
var _kb := -1
var _hover := ""

var _head: Label
var _hints: HBoxContainer
var _grid: GridContainer
var _fx: Control
var _t := 0.0

var _objection: Control
var _claim: PanelContainer
var _claim_slot: Control
var _claim_data: Dictionary = {}
var _clue_box: VBoxContainer
var _clues: Array[Dictionary] = []
var _clue_panels: Array[PanelContainer] = []
var _selected := -1
var _dragging := -1
var _drag_ghost: PanelContainer
var _accepting := false
var _slam_t := -1.0
var _stamp_t := -1.0
var _stamp_btn: Button
var _stamp_accepting := false
var _referral := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var rays := UiKit.full_rect()
	rays.name = "Rays"
	rays.draw.connect(_draw_rays.bind(rays))
	add_child(rays)
	_head = UiKit.label("", 32, Palette.INK, 700)
	_head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_head.offset_top = 84
	_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_head)
	_hints = HBoxContainer.new()
	_hints.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hints.offset_top = 126
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", GAP)
	_grid.add_theme_constant_override("v_separation", GAP)
	_grid.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_grid.offset_top = 166
	_grid.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)
	_objection = UiKit.full_rect()
	_objection.name = "Objection"
	_objection.visible = false
	add_child(_objection)
	_stamp_btn = UiKit.button("  STAMP: RECHECK + OBJECTIVE TESTS  ", &"AccentButton", Vector2(0, 64))
	_stamp_btn.visible = false
	_stamp_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamp_btn.offset_top = -96
	_stamp_btn.offset_bottom = -32
	_stamp_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_stamp_btn.pressed.connect(_stamp)
	add_child(_stamp_btn)
	Hoot.register_anchor("referral_stamp", _stamp_btn)
	_fx = UiKit.full_rect()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _exit_tree() -> void:
	for id: String in _order:
		Hoot.unregister_anchor("word_card_" + id)
	for c: Dictionary in _clues:
		Hoot.unregister_anchor("clue_" + String(c.get("id", "")))
	for a: String in ["objection_claim", "referral_stamp"]:
		Hoot.unregister_anchor(a)
	Hoot.clear_bubble_hint()


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _set_hints(parts: Array) -> void:
	for c in _hints.get_children():
		c.queue_free()
	if not parts.is_empty():
		_hints.add_child(UiKit.hint_panel(parts, 16))


# ---------------------------------------------------------------- 1. the word cards

## (coroutine) Lay out one card per item (face down) and flip them over one by one.
func run_cards(items: Array[Dictionary], title: String = "SPONDEE LIST A") -> void:
	_items = items
	_head.text = "%s: GO THROUGH THE WORDS" % title.to_upper()
	Juice.pop(_head, 1.15, 0.3)
	for it: Dictionary in items:
		var id := String(it.get("id", ""))
		var card := Control.new()
		card.name = "Card_" + id
		card.custom_minimum_size = CARD
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.draw.connect(_draw_card.bind(card, id))
		card.gui_input.connect(_on_card_input.bind(id))
		card.mouse_entered.connect(func() -> void:
			_hover = id
			card.queue_redraw())
		card.mouse_exited.connect(func() -> void:
			if _hover == id:
				_hover = ""
			card.queue_redraw())
		_grid.add_child(card)
		_cards[id] = card
		_order.append(id)
		_flip[id] = 0.0
		Hoot.register_anchor("word_card_" + id, card)
	await get_tree().process_frame
	for i in _order.size():
		var id := _order[i]
		var card: Control = _cards[id]
		card.pivot_offset = card.size * 0.5
		var t := create_tween()
		t.tween_interval(0.07 * i)
		t.tween_method(_set_flip.bind(id), 0.0, 1.0, 0.0 if _reduced() else 0.28).set_trans(Tween.TRANS_SINE)
		t.tween_callback(Sfx.play.bind(&"blip", 1.1 + 0.03 * i, -12.0))
	await _wait(0.07 * _order.size() + 0.4)


func _set_flip(v: float, id: String) -> void:
	_flip[id] = v
	var card: Control = _cards.get(id)
	if card != null:
		card.scale.x = maxf(0.02, absf(cos(v * PI)))
		card.queue_redraw()


## (coroutine) A reading highlight sweeps from card `from` to card `to` over `seconds`.
func read_along(from: int, to: int, seconds: float) -> void:
	var t := create_tween()
	t.tween_method(_set_reading, float(from), float(to) + 0.99, maxf(0.05, seconds))
	await t.finished
	_set_reading(-1.0)


func _set_reading(v: float) -> void:
	var before := int(_reading)
	_reading = v
	if int(v) != before and v >= 0.0 and int(v) < _order.size():
		var card: Control = _cards[_order[int(v)]]
		Juice.pop(card, 1.06, 0.18)
		Sfx.play(&"pop", 1.3, -16.0)
	for c: Control in _cards.values():
		c.queue_redraw()


## The card Mike stumbles on: a wobble and a "?".
func stumble(id: String) -> void:
	_stumbled = id
	_wobble[id] = 1.0
	Sfx.play(&"boing", 1.0, -8.0)


func is_dropped(id: String) -> bool:
	return dropped.has(id)


## (coroutine) Beat familiarize_cards: wait until the player drops `target` (a click on its card,
## or arrows + Enter). Other cards are slips (counted in drop_slips, with a kind Hoot tip).
func run_drop(target: String) -> void:
	_drop_target = target
	_drop_accepting = true
	_kb = -1
	if UiKit.show_key_hints():
		_set_hints(["Click the word he doesn't know   or", ["Left", "Right", "Up", "Down"], "+", ["Enter"]])
	else:
		_set_hints(["Click the word he doesn't know"])
	Hoot.set_bubble_hint(Rect2(Vector2(800, 486), Vector2(440, 70)))
	var anchor := "word_card_" + target
	Events.awaiting_input.emit(&"familiarize_cards", {"targets": [anchor], "mouse": {"click": anchor}}, _solve_drop)
	while not dropped.has(target):
		await _dropped
	_drop_accepting = false
	Events.input_resolved.emit(&"familiarize_cards")
	_set_hints([])
	Hoot.clear_bubble_hint()
	await _wait(0.6)


func _solve_drop() -> void:
	_try_drop(_drop_target)


func _try_drop(id: String) -> void:
	if not _drop_accepting or dropped.has(id) or not _cards.has(id):
		return
	var card: Control = _cards[id]
	if id != _drop_target:
		drop_slips += 1
		Juice.shake(card, 6.0, 0.25)
		Sfx.play(&"boing", 1.3, -8.0)
		Hoot.say("He read that one fine! Drop the word he didn't know.", Hoot.HIGH, "word_card_" + _drop_target)
		_dropped.emit()
		return
	dropped.append(id)
	_wobble[id] = 0.0
	_stumbled = ""
	Hoot.dismiss_current()
	Juice.squash(card, 0.25, 0.3)
	Sfx.play(&"stamp", 1.2, -4.0)
	card.queue_redraw()
	_dropped.emit()


func _on_card_input(event: InputEvent, id: String) -> void:
	if not _drop_accepting:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_try_drop(id)
		accept_event()


func _draw_card(card: Control, id: String) -> void:
	var r := Rect2(Vector2.ZERO, card.size)
	var front := float(_flip.get(id, 0.0)) >= 0.5
	var i := _order.find(id)
	var is_drop := dropped.has(id)
	var reading := _reading >= 0.0 and int(_reading) == i
	var hl := (_drop_accepting and (_hover == id or _kb == i)) or reading
	if hl:
		UiDraw.rounded_rect(card, r.grow(5.0), Palette.SUNNY if reading else Palette.SKY.darkened(0.15), 18)
	UiDraw.rounded_rect(card, Rect2(r.position + Vector2(0, 5), r.size), Color(Palette.INK, 0.16), 16)
	if not front:
		UiDraw.rounded_rect(card, r, CARD_BACK, 16, 3, Palette.INK)
		for k in 5:
			card.draw_circle(r.get_center() + Vector2(-60 + 30 * k, 0), 7.0, Color(Color.WHITE, 0.55))
		return
	UiDraw.rounded_rect(card, r, Color("#f1ece2") if is_drop else Palette.PAPER, 16, 3, Palette.INK)
	var it: Dictionary = _items[i] if i >= 0 and i < _items.size() else {}
	var f := UiKit.font(700)
	var word := String(it.get("text", id))
	var fs := 28
	while fs > 18 and f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x - 40.0:
		fs -= 1
	var col := Palette.INK_SOFT if is_drop else Palette.INK
	card.draw_string(f, Vector2(0, 46), word, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, col)
	var parts: Array = it.get("parts", [])
	if parts.size() == 2:
		card.draw_string(UiKit.font(600), Vector2(0, 74), "%s  -  %s" % [parts[0], parts[1]], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Palette.INK_SOFT)
	card.draw_string(UiKit.font(700), Vector2(12, 22), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Palette.INK, 0.4))
	if is_drop:
		UiDraw.cross(card, r.get_center(), 44.0, Color(Palette.RIGHT_RED, 0.85), 6.0)
		card.draw_set_transform(r.get_center() + Vector2(50, -24), -0.2, Vector2.ONE)
		UiDraw.rounded_rect(card, Rect2(Vector2(-46, -14), Vector2(92, 28)), Color(Palette.PAPER, 0.9), 6, 3, Palette.RIGHT_RED)
		card.draw_string(f, Vector2(-46, 7), "DROPPED", HORIZONTAL_ALIGNMENT_CENTER, 92, 16, Palette.RIGHT_RED)
		card.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif id == _stumbled:
		var bob := 0.0 if _reduced() else sin(_t * 5.0) * 3.0
		var at := Vector2(r.size.x - 18, 4 + bob)
		card.draw_circle(at, 17.0, Palette.INK)
		card.draw_circle(at, 14.0, Palette.LEFT_BLUE)
		card.draw_string(f, at + Vector2(-14, 8), "?", HORIZONTAL_ALIGNMENT_CENTER, 28, 22, Palette.PAPER)


# ---------------------------------------------------------------- 2. OBJECTION!

## Build the objection board (the word cards go away). claim: {quote, who, verdict};
## clues: [{id, title, sub, best: bool, why: String}] in display order.
func show_objection(claim: Dictionary, clues: Array[Dictionary]) -> void:
	_claim_data = claim
	_clues = clues
	_grid.visible = false
	_set_hints([])
	_head.text = "WHICH CLUE CHECKS THE CLAIM?"
	Juice.pop(_head, 1.15, 0.3)
	_objection.visible = true
	_claim = UiKit.panel(Color("#fffdf3"), Palette.INK, 14)
	_claim.position = CLAIM_POS
	_claim.custom_minimum_size = Vector2(CLAIM_W, 0)
	_claim.rotation = -0.015
	_claim.mouse_filter = Control.MOUSE_FILTER_STOP
	_claim.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_claim.gui_input.connect(_on_claim_input)
	_objection.add_child(_claim)
	Hoot.register_anchor("objection_claim", _claim)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_claim.add_child(cv)
	cv.add_child(UiKit.label("THE CLAIM", 16, Palette.RIGHT_RED, 700))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(row)
	var face := Control.new()
	face.custom_minimum_size = Vector2(112, 112)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(func() -> void:
		Portraits.draw(face, String(claim.get("speaker", "Mike")), Vector2(56, 56), 50.0, false, fmod(_t, 3.9) < 0.12))
	row.add_child(face)
	var qv := VBoxContainer.new()
	qv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	qv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(qv)
	var q := UiKit.label("\"%s\"" % String(claim.get("quote", "")), 30, Palette.INK, 700)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(340, 0)
	qv.add_child(q)
	qv.add_child(UiKit.label(String(claim.get("who", "")), 16, Palette.INK_SOFT, 600))
	_claim_slot = Control.new()
	_claim_slot.custom_minimum_size = Vector2(CLAIM_W - 32, 120)
	_claim_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_claim_slot.draw.connect(_draw_slot)
	cv.add_child(_claim_slot)
	_clue_box = VBoxContainer.new()
	_clue_box.position = Vector2(CLUE_X, CLAIM_POS.y)
	_clue_box.custom_minimum_size = Vector2(CLUE_W, 0)
	_clue_box.add_theme_constant_override("separation", 14)
	_clue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_objection.add_child(_clue_box)
	for i in clues.size():
		var p := _make_clue(i)
		_clue_box.add_child(p)
		_clue_panels.append(p)
		Hoot.register_anchor("clue_" + String(clues[i].get("id", "")), p)
	# Hoot's notes go under the clues, not over the claim
	Hoot.set_bubble_hint(Rect2(Vector2(CLUE_X, 520), Vector2(CLUE_W, 70)))


func _make_clue(i: int) -> PanelContainer:
	var spec: Dictionary = _clues[i]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.style(CLUE_NEUTRAL, Palette.INK, 12, 3, 4, 12))
	p.custom_minimum_size = Vector2(CLUE_W, 104)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UiKit.key_chip(str(i + 1), 14))
	top.add_child(UiKit.label("  CLUE %s" % char(65 + i), 14, Palette.INK_SOFT, 700))
	v.add_child(UiKit.label(String(spec.get("title", "")), 24, Palette.INK, 700))
	var sub := UiKit.label(String(spec.get("sub", "")), 16, Palette.INK_SOFT, 500)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	p.gui_input.connect(_on_clue_input.bind(i))
	p.mouse_entered.connect(func() -> void:
		if _accepting and _dragging < 0:
			_select(i, false))
	return p


## (coroutine) Beat objection_present: returns once the strongest clue lands on the claim.
func run_objection() -> void:
	await get_tree().process_frame
	_accepting = true
	_selected = -1
	if UiKit.show_key_hints():
		_set_hints(["Drag the strongest clue onto the claim   or", ["1"], ["2"], ["3"], "then", ["Enter"]])
	else:
		_set_hints(["Drag the strongest clue onto the claim"])
	var best := "clue_" + _best_id()
	Events.awaiting_input.emit(&"objection_present", {"targets": ["objection_claim"], "mouse": {"drag": [best, "objection_claim"]}}, _solve_objection)
	while not solved:
		await _presented
	_accepting = false
	Events.input_resolved.emit(&"objection_present")
	_set_hints([])


func _best_id() -> String:
	for c: Dictionary in _clues:
		if bool(c.get("best", false)):
			return String(c.get("id", ""))
	return String(_clues[0].get("id", "")) if not _clues.is_empty() else ""


func _solve_objection() -> void:
	for i in _clues.size():
		if bool(_clues[i].get("best", false)):
			_present(i)
			return


func _select(i: int, sound: bool = true) -> void:
	_selected = i
	for j in _clue_panels.size():
		var on := j == i
		_clue_panels[j].add_theme_stylebox_override("panel", UiKit.style(CLUE_PICK if on else CLUE_NEUTRAL, Palette.INK, 12, 4 if on else 3, 8 if on else 4, 12))
	if sound:
		Sfx.play(&"blip", 1.3, -8.0)


func _on_clue_input(event: InputEvent, i: int) -> void:
	if not _accepting:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = i
			_select(i)
			_make_ghost(i, mb.global_position)
		else:
			var at := mb.global_position
			_dragging = -1
			_free_ghost()
			if _claim.get_global_rect().grow(16.0).has_point(at):
				_present(i)
		accept_event()
	elif event is InputEventMouseMotion and _dragging == i and _drag_ghost:
		_drag_ghost.position = (event as InputEventMouseMotion).global_position - _drag_ghost.size * 0.5


func _on_claim_input(event: InputEvent) -> void:
	if not _accepting:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _selected >= 0:
			_present(_selected)
		accept_event()


func _make_ghost(i: int, at: Vector2) -> void:
	_free_ghost()
	_drag_ghost = UiKit.panel(CLUE_PICK, Palette.INK, 12)
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.add_child(UiKit.label("CLUE %s: %s" % [char(65 + i), String(_clues[i].get("title", ""))], 18, Palette.INK, 700))
	_drag_ghost.rotation = -0.05
	add_child(_drag_ghost)
	_drag_ghost.reset_size()
	_drag_ghost.position = at - _drag_ghost.size * 0.5


func _free_ghost() -> void:
	if _drag_ghost:
		_drag_ghost.queue_free()
		_drag_ghost = null


func _present(i: int) -> void:
	if solved or not _accepting or i < 0 or i >= _clues.size():
		return
	var spec: Dictionary = _clues[i]
	picks.append(String(spec.get("id", "")))
	if bool(spec.get("best", false)):
		solved = true
		Hoot.dismiss_current()
		_select(i, false)
		_slam_t = 0.0
		Sfx.play(&"stamp", 0.8, 0.0)
		get_tree().create_timer(0.2, false).timeout.connect(Sfx.play.bind(&"fanfare", 1.0, -4.0))
		Events.screen_shake.emit(0.7, 0.35)
		Juice.shake(_claim, 12.0, 0.35)
		_claim_slot.set_meta("filled", i)
		_claim_slot.queue_redraw()
		_presented.emit()
		return
	# a real clue, just not the strongest one: a gentle nudge, then try again
	Juice.shake(_clue_panels[i], 6.0, 0.25)
	Sfx.play(&"boing", 1.1, -8.0)
	_clue_panels[i].modulate = Color(1, 1, 1, 0.7)
	Hoot.say(String(spec.get("why", "Good clue! Is there a stronger one?")), Hoot.HIGH, "clue_" + _best_id())
	_presented.emit()


## The clue column steps aside (the dialogue's choices sit on the right) and the claim card
## shrinks to the left, or both come back.
func set_referral_mode(on: bool) -> void:
	if _referral == on or _claim == null:
		return
	_referral = on
	_claim.pivot_offset = Vector2.ZERO
	var t := create_tween().set_parallel(true)
	t.tween_property(_clue_box, "modulate:a", 0.0 if on else 1.0, 0.25)
	t.tween_property(_claim, "scale", Vector2.ONE * (0.8 if on else 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_claim, "position", Vector2(36, 96) if on else CLAIM_POS, 0.35).set_trans(Tween.TRANS_SINE)
	_clue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for p: PanelContainer in _clue_panels:
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE if on else Control.MOUSE_FILTER_STOP
	_head.text = "WHAT'S NEXT FOR MIKE?" if on else "WHICH CLUE CHECKS THE CLAIM?"
	_head.offset_left = 120.0 if on else 0.0


## (coroutine) Beat referral_stamp: click the stamp (or Enter); the solver stamps it.
func run_stamp() -> void:
	_stamp_btn.visible = true
	_stamp_btn.add_theme_font_size_override("font_size", 26)
	Juice.bounce_in(_stamp_btn, 0.4)
	if UiKit.show_key_hints():
		_set_hints(["Click the stamp   or", ["Enter"]])
	_stamp_accepting = true
	Events.awaiting_input.emit(&"referral_stamp", {"targets": ["referral_stamp"]}, _stamp)
	while not stamped:
		await _stamped
	Events.input_resolved.emit(&"referral_stamp")
	_set_hints([])
	await _wait(1.0)


func _stamp() -> void:
	if stamped:
		return
	stamped = true
	_stamp_accepting = false
	_stamp_btn.visible = false
	_stamp_t = 0.0
	Sfx.play(&"stamp", 0.7, 0.0)
	Events.screen_shake.emit(0.6, 0.3)
	_stamped.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _drop_accepting:
		_drop_keys(event)
	elif _accepting:
		_objection_keys(event)
	elif _stamp_accepting and (event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue")):
		_stamp()
		get_viewport().set_input_as_handled()


func _drop_keys(event: InputEvent) -> void:
	var n := _order.size()
	if n == 0:
		return
	if event.is_action_pressed(&"ui_right"):
		_kb = (_kb + 1) % n
	elif event.is_action_pressed(&"ui_left"):
		_kb = (_kb - 1 + n) % n if _kb >= 0 else n - 1
	elif event.is_action_pressed(&"ui_down"):
		_kb = (_kb + COLUMNS) % n if _kb >= 0 else 0
	elif event.is_action_pressed(&"ui_up"):
		_kb = (_kb - COLUMNS + n) % n if _kb >= 0 else n - 1
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _kb >= 0:
			_try_drop(_order[_kb])
		else:
			_kb = 0
	else:
		return
	Sfx.play(&"blip", 1.4, -12.0)
	for c: Control in _cards.values():
		c.queue_redraw()
	get_viewport().set_input_as_handled()


func _objection_keys(event: InputEvent) -> void:
	var n := _clue_panels.size()
	if n == 0:
		return
	if event is InputEventKey:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k < KEY_1 + n:
			_select(k - KEY_1)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		_select((_selected + 1) % n)
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		_select((_selected - 1 + n) % n if _selected >= 0 else n - 1)
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		if _selected >= 0:
			_present(_selected)
		else:
			_select(0)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if _slam_t >= 0.0:
		_slam_t += delta
	if _stamp_t >= 0.0:
		_stamp_t += delta
	for id: String in _wobble:
		var w := float(_wobble[id])
		var card: Control = _cards.get(id)
		if card == null:
			continue
		if w > 0.0:
			_wobble[id] = maxf(0.0, w - delta * 0.7)
		card.rotation = 0.0 if _reduced() else sin(_t * 18.0) * 0.06 * float(_wobble[id])
	if _stumbled != "" and _cards.has(_stumbled):
		(_cards[_stumbled] as Control).queue_redraw()
	if _claim_slot != null:
		_claim_slot.queue_redraw()
	_fx.queue_redraw()
	if not _reduced():
		(get_node("Rays") as Control).queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_rays(c: Control) -> void:
	if not _objection.visible:
		return
	# courtroom-drama rays behind the claim card (slowly turning; still under reduced motion)
	var center := CLAIM_POS + Vector2(CLAIM_W * 0.5, 170)
	var spin := 0.0 if _reduced() else _t * 0.05
	var far := c.size.length()
	for i in 18:
		var a0 := spin + TAU * i / 18.0
		var a1 := a0 + TAU / 36.0
		c.draw_colored_polygon(PackedVector2Array([center, center + Vector2(cos(a0), sin(a0)) * far, center + Vector2(cos(a1), sin(a1)) * far]), Color(Palette.SUNNY, 0.16))


func _draw_slot() -> void:
	var s := _claim_slot
	var r := Rect2(Vector2(4, 8), s.size - Vector2(8, 12))
	if s.has_meta("filled"):
		var i: int = s.get_meta("filled")
		var spec: Dictionary = _clues[i]
		UiDraw.rounded_rect(s, r, CLUE_PICK, 12, 3, Palette.INK)
		var f := UiKit.font(700)
		s.draw_string(f, r.position + Vector2(16, 34), "CLUE %s: %s" % [char(65 + i), String(spec.get("title", ""))], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 22, Palette.INK)
		var verdict := String(_claim_data.get("verdict", ""))
		if verdict != "":
			s.draw_string(UiKit.font(700), r.position + Vector2(16, 70), verdict, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 19, Palette.RIGHT_RED.darkened(0.1))
		var note := String(_claim_data.get("note", ""))
		if note != "":
			s.draw_string(UiKit.font(600), r.position + Vector2(16, 98), note, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 32, 15, Palette.INK_SOFT)
		return
	var pulse := 0.5 + (0.0 if _reduced() else 0.5 * sin(_t * 4.0))
	var segs := 30
	var per := (r.size.x * 2.0 + r.size.y * 2.0) / segs
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
	for k in 4:
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var n := int(a.distance_to(b) / per)
		for j in n:
			if j % 2 == 0:
				s.draw_line(a.lerp(b, float(j) / n), a.lerp(b, float(j + 1) / n), Color(Palette.INK, 0.35 + 0.3 * pulse), 3.0)
	s.draw_string(UiKit.font(600), r.position + Vector2(0, r.size.y * 0.5 + 8), "Drop the strongest clue here", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 20, Palette.INK_SOFT)


func _to_fx(p: Vector2) -> Vector2:
	return _fx.get_global_transform_with_canvas().affine_inverse() * p


func _draw_fx() -> void:
	if _claim == null:
		return
	if _slam_t >= 0.0:
		_draw_objection()
	if _stamp_t >= 0.0:
		_draw_stamp()


## OBJECTION!: slams in big over the claim (a starburst and shaking letters), then settles into
## a sticker on the claim card's corner (so the referral stamp has room later).
func _draw_objection() -> void:
	var cr := _claim.get_global_rect()
	var big := _to_fx(cr.get_center() + Vector2(0, -20))
	var corner := _to_fx(cr.position + Vector2(cr.size.x - 70.0, 16.0))
	var settle := clampf((_slam_t - 1.5) / 0.4, 0.0, 1.0)
	var at := big.lerp(corner, settle)
	var land := clampf(_slam_t / 0.16, 0.0, 1.0)
	var sc := 1.0 if _reduced() else lerpf(2.4, 1.0, land * land)
	sc *= lerpf(1.0, 0.36, settle)
	var alpha := clampf(_slam_t / (0.25 if _reduced() else 0.08), 0.0, 1.0)
	var jitter := Vector2.ZERO
	if not _reduced() and _slam_t < 0.5:
		jitter = Vector2(sin(_t * 90.0), cos(_t * 77.0)) * 4.0 * (1.0 - _slam_t / 0.5)
	_fx.draw_set_transform(at + jitter, -0.12, Vector2.ONE * sc)
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var rad := 170.0 if i % 2 == 0 else 118.0
		pts.append(Vector2(cos(a) * rad * 1.45, sin(a) * rad * 0.62))
	_fx.draw_colored_polygon(pts, Color(Palette.CORAL, alpha))
	pts.append(pts[0])
	_fx.draw_polyline(pts, Color(Palette.INK, alpha), 6.0, true)
	var f := UiKit.font(700)
	var txt := "OBJECTION!"
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 66).x
	_fx.draw_string_outline(f, Vector2(-w * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 66, 14, Color(Palette.INK, alpha))
	_fx.draw_string(f, Vector2(-w * 0.5, 22), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 66, Color(Palette.PAPER, alpha))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_stamp() -> void:
	var cr := _claim.get_global_rect()
	var c := _to_fx(cr.get_center() + Vector2(10, 10))
	var land := clampf(_stamp_t / 0.18, 0.0, 1.0)
	var k := _claim.scale.x
	var sc := (1.0 if _reduced() else lerpf(2.6, 1.0, land * land)) * k
	var alpha := clampf(_stamp_t / 0.12, 0.0, 1.0)
	_fx.draw_set_transform(c, -0.16, Vector2.ONE * sc)
	var col := Color(Palette.RIGHT_RED, 0.92 * alpha)
	var f := UiKit.font(700)
	var s1 := "RECHECK +"
	var s2 := "OBJECTIVE TESTS"
	var w1 := f.get_string_size(s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 50).x
	var w2 := f.get_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	var bw := maxf(w1, w2) + 48.0
	var box := Rect2(Vector2(-bw * 0.5, -62), Vector2(bw, 122))
	_fx.draw_rect(box, Color(Palette.PAPER, 0.8 * alpha))
	_fx.draw_rect(box, col, false, 7.0)
	_fx.draw_rect(box.grow(-9.0), col, false, 2.5)
	_fx.draw_string(f, Vector2(-w1 * 0.5, -8), s1, HORIZONTAL_ALIGNMENT_LEFT, -1, 50, col)
	_fx.draw_string(f, Vector2(-w2 * 0.5, 40), s2, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, col)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
