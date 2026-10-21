extends Control
## MarcoBoard (Day 5): the bill, the band ruler, the two plates, the pizza, the blind switch and the
## reveal card (docs/CHAPTER5.md §5.7 and §6). A new board: nora_board.gd is a roll call and a
## letter, so it does not fit; its key-chip helpers are reused by reference (never a copy). No shared
## file changes.
##  1. The bill: a till receipt prints the player's own locked-in counts, course by course, and the
##     formula SNR LOSS = 25.5 - KEY WORDS RIGHT (not filled in). The level asks "What's the bill?" as
##     a stock choice; then the band ruler (the menu): a pointer moved with {key:speech_incorrect} /
##     {key:speech_correct} and confirmed with {key:advance_dialogue}, or a click on a band. The
##     receipt prints "{BAND} SNR LOSS" and a PAID stamp. After list 2 it reprints both lists and
##     their average, with no question.
##  2. The plates: Marco's two claims on two empty plates, four clue cards in one colour (colour
##     never gives the answer away). Keys 1-4 serve a card onto the glowing plate; or drag a card
##     onto a plate; or click a card, then a plate. BOTH TRUE! stamps across them (a shake unless
##     reduced motion), then the banner.
##  3. The pizza: top-down Marco between the TALKER (front) and the PARTY (behind); the whole pizza,
##     then the front half bright and the back half dimmed (FRONT / BACK labels; stills with reduced
##     motion).
##  4. The switch: a cartoon aid remote with a chunky A / B switch; Marco's eyes are closed.
##  5. The reveal card: A against B, the benefit arrow and whether it beats the critical difference.
## Story-internal:
##   var b := MarcoBoard.new(); hud.add_game(b)
##   await b.show_bill(list)                 # list: the newest party list record of the "both" sheet
##   var band: StringName = await b.pick_band(loss)   # beat band_pick, one per call
##   await b.pay(band)
##   await b.show_average(lists, avg, band)
##   await b.setup_plates(MarcoBoard.plate_cards(r, l, wband, pta, avg, sband)); await b.run_plates()
##     # beat plates_serve per plate; b.plate_slips, b.pta_used
##   await b.show_pizza(); b.pizza_focus(true)
##   await b.show_switch(); await b.flip_switch()   # beat focus_switch
##   await b.show_reveal(omni_sheet, focus_sheet, benefit, crit, real)
##   await b.fade_out()
## Beats: band_pick {loss, bands, pointer, best, mouse: {click: "band_<best>"}}; plates_serve {plate,
## cards, best, mouse: {drag: [clue_anchor, plate_anchor]}}; focus_switch {mouse: {click:
## "party_focus_switch"}}. Each has a solver.
## Anchors: band_normal, band_mild, band_moderate, band_severe, plate_quiet, plate_noisy,
## clue_words_quiet, clue_pta, clue_snr_loss, clue_canals, party_focus_switch.
## The receipt is drawn, never a Label: nothing on the board starts with "<n> dB", so the bill's
## choice stays the only text the mouse bot can match. Every line keeps to 18 words; keys are named
## only through {key:<action>}. Nothing here plays louder than the shared Sfx.

signal _band_picked(index: int)
signal _served_sig
signal _flipped

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const NoraBoard := preload("res://story/games/nora_board.gd")

## Every Hoot line of the board (18 words or fewer with tokens at their longest).
const LINES: Dictionary[String, String] = {
	"band_wrong": "Find {loss} on the ruler. Which band holds it?",
	"quiet_right": "{band} words in quiet. Claim one: true!",
	"quiet_pta": "True, near-normal beeps. Words in quiet prove it even better.",
	"noisy_right": "{band} SNR loss. Claim two: also true!",
	"distractor": "True, but it doesn't prove either claim. Try another card.",
	"other_plate": "True, but that card proves the other claim. Try the other plate.",
}
const BANDS: Array[StringName] = [&"normal", &"mild", &"moderate", &"severe"]
const PLATES: Array[String] = ["quiet", "noisy"]
const CLAIMS: Dictionary = {"quiet": "In quiet, I hear perfectly.", "noisy": "At a busy table, words turn to soup."}
const BAND_COLORS: Dictionary = {&"normal": Color("#5bc8a3"), &"mild": Color("#ffd23f"), &"moderate": Color("#ff9f1c"), &"severe": Color("#ff6f59")}

## The bill: the receipt on the left (clear of the dialogue's choices), the menu's ruler on the right.
const RECEIPT := Rect2(70, 118, 430, 418)
const RECEIPT_PAPER := Color("#fffdf6")
const RECEIPT_INK := Color("#3a3350")
const RULER := Rect2(530, 128, 690, 206)
const BAND_SIZE := Vector2(160, 118)
const PRINT_S := 1.1
## The plates and the clue cards.
const PLATE_R := 104.0
const PLATE_AT: Dictionary = {"quiet": Vector2(380, 292), "noisy": Vector2(900, 292)}
const CARD_SIZE := Vector2(282, 104)
const CARDS_Y := 420.0
const CARD_NEUTRAL := Color("#fffbf2")
const CARD_HOVER := Color("#fff1c8")
const CARD_PICK := Color("#ffd23f")
const CAPTION_Y := 534.0
## The pizza and the switch.
const PIZZA_AT := Vector2(640, 318)
const PIZZA_R := 130.0
const REMOTE := Rect2(520, 170, 420, 300)
const SWITCH_SIZE := Vector2(220, 92)

## The plates' results: wrong serves, and whether the PTA card went on the quiet plate.
var plate_slips := 0
var pta_used := false

var _stage: StringName = &"bill"
var _t := 0.0
var _rec: Dictionary = {}
var _avg_lists: Array = []
var _avg := 0.0
var _avg_band: StringName = &""
var _print_t := -1.0
var _paid: StringName = &""
var _paid_t := -1.0
var _pointer := 0
var _band_mode := false
var _armed_at := 0.0
var _dead_bands: Dictionary = {}
var _loss := 0.0
var _cards: Array[Dictionary] = []
var _card_nodes: Array[PanelContainer] = []
var _served: Dictionary = {}       # plate -> card index
var _used: Dictionary = {}         # card index -> plate
var _accepting := false
var _cur_plate := ""
var _selected := -1
var _hover := -1
var _dragging := -1
var _ghost: PanelContainer
var _both_t := -1.0
var _banner_t := -1.0
var _pizza_t := -1.0
var _focus_k := 0.0
var _switch_on := false
var _switch_mode := false
var _knob_k := 0.0
var _reveal: Dictionary = {}
var _reveal_t := -1.0

var _art: Control
var _fx: Control
var _head: Label
var _hints: HBoxContainer
var _caption: Label
var _ruler: Control
var _band_btns: Array[Button] = []
var _plate_nodes: Dictionary = {}
var _switch: Button


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
	_head = UiKit.label("THE BILL", 32, Palette.INK, 700)
	_head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_head.offset_top = 76
	_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_head)
	_hints = HBoxContainer.new()
	_hints.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_hints.offset_top = 600
	_hints.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hints)
	_build_ruler()
	_build_plates()
	_build_switch()
	_caption = UiKit.label("", 20, Palette.INK, 600)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.position = Vector2(240, CAPTION_Y)
	_caption.size = Vector2(800, 56)
	add_child(_caption)
	_fx = UiKit.full_rect()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


func _set_hints(parts: Array) -> void:
	for c in _hints.get_children():
		c.queue_free()
	if not parts.is_empty():
		_hints.add_child(UiKit.hint_panel(parts, 16))


func _show_caption(text: String, col: Color = Palette.INK) -> void:
	_caption.text = "HOOT: " + NoraBoard.fill_keys(text) if text != "" else ""
	_caption.add_theme_color_override("font_color", col)
	if text != "":
		Juice.pop(_caption, 1.05, 0.2)


## One of the board's lines with its tokens filled.
static func line(key: String, tokens: Dictionary = {}) -> String:
	var s := String(LINES.get(key, key))
	for k: Variant in tokens:
		s = s.replace("{%s}" % String(k), str(tokens[k]))
	return s


# ---------------------------------------------------------------- 1. the bill

## The receipt's rows for one party list: [left, right] pairs, a "" left for a rule.
static func receipt_rows(rec: Dictionary) -> Array:
	var rows: Array = []
	var counts: Array[int] = []
	for s: Variant in rec.get("sentences", []):
		counts.append(int((s as Dictionary).get("count", 0)))
	for i in SpeechRules.SIN_COURSES.size():
		var snr: int = SpeechRules.SIN_SNRS[i]
		rows.append(["%s (%d dB)" % [SpeechRules.SIN_COURSES[i], snr], str(counts[i]) if i < counts.size() else "-"])
	rows.append(["", ""])
	rows.append(["KEY WORDS RIGHT", str(int(rec.get("total", 0)))])
	return rows


func _build_ruler() -> void:
	_ruler = UiKit.full_rect()
	_ruler.name = "Ruler"
	add_child(_ruler)
	for i in BANDS.size():
		var b: StringName = BANDS[i]
		var btn := Button.new()
		btn.name = "band_" + String(b)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.position = RULER.position + Vector2(16.0 + i * (BAND_SIZE.x + 10.0), 62.0)
		btn.size = BAND_SIZE
		btn.custom_minimum_size = BAND_SIZE
		btn.pivot_offset = BAND_SIZE * 0.5
		btn.draw.connect(_draw_band_button.bind(btn, i))
		btn.pressed.connect(func() -> void:
			if _band_mode and not _dead_bands.has(i):
				_pointer = i
				_confirm_band())
		btn.mouse_entered.connect(func() -> void:
			if _band_mode and not _dead_bands.has(i):
				_pointer = i)
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.position = Vector2(8, 10)
		v.size = BAND_SIZE - Vector2(16, 20)
		v.add_theme_constant_override("separation", 0)
		btn.add_child(v)
		var name_l := UiKit.label(String(SpeechRules.SIN_BAND_NAMES[b]).to_upper(), 19, Palette.INK, 700)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(name_l)
		var range_l := UiKit.label(band_range(b), 16, Palette.INK_SOFT, 700)
		range_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(range_l)
		var rem := UiKit.label(String(SpeechRules.SIN_REMEDIES[b]), 15, Palette.INK, 600)
		rem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rem.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rem.custom_minimum_size = Vector2(BAND_SIZE.x - 16.0, 0)
		v.add_child(rem)
		_ruler.add_child(btn)
		_band_btns.append(btn)
		Hoot.register_anchor("band_" + String(b), btn)


## The band's span as the menu prints it: "0-3 dB", "3-7 dB", "7-15 dB", "over 15 dB" (upper bounds
## inclusive, as sin_band reads them).
static func band_range(b: StringName) -> String:
	var lo := 0
	for row: Array in SpeechRules.SIN_BANDS:
		if StringName(row[1]) == b:
			return "%d-%d dB" % [lo, int(row[0])]
		lo = int(row[0])
	return "over %d dB" % lo


## (coroutine) The receipt prints with a ka-ching (at once with reduced motion).
func show_bill(rec: Dictionary) -> void:
	_stage = &"bill"
	_rec = rec.duplicate(true)
	_avg_lists = []
	_head.text = "THE BILL"
	_print_t = PRINT_S if _reduced() else 0.0
	Sfx.play(&"kaching", 1.0, -8.0)
	await _wait(0.2 if _reduced() else PRINT_S + 0.2)


## (coroutine) Beat band_pick: the pointer on the menu's ruler (keys or a click). Returns the band
## picked; a wrong one gets Hoot's caption and greys out, and the level asks again.
func pick_band(loss: float) -> StringName:
	_loss = loss
	var best := BANDS.find(SpeechRules.sin_band(loss))
	if _dead_bands.has(_pointer):
		for k in BANDS.size():
			if not _dead_bands.has(k):
				_pointer = k
				break
	_band_mode = true
	_armed_at = _t
	if UiKit.show_key_hints():
		_set_hints([[Game.key_label(&"speech_incorrect")], [Game.key_label(&"speech_correct")], "move", "   ",
			[Game.key_label(&"advance_dialogue")], "pick", "   or click a band"])
	else:
		_set_hints(["Click the band that holds the SNR loss"])
	var bands: Array[String] = []
	for b: StringName in BANDS:
		bands.append(String(b))
	Events.awaiting_input.emit(&"band_pick", {"loss": loss, "bands": bands, "pointer": _pointer, "best": best,
		"mouse": {"click": "band_" + String(BANDS[best])}}, _solve_band.bind(best))
	var i: int = await _band_picked
	Events.input_resolved.emit(&"band_pick")
	_band_mode = false
	_set_hints([])
	if i != best:
		_dead_bands[i] = true
		Sfx.play(&"boing", 0.9, -6.0)
		_show_caption(line("band_wrong", {"loss": "%.1f" % loss}))
		if not _reduced():
			Juice.shake(_band_btns[i], 6.0, 0.3)
		await _wait(0.7)
	else:
		_show_caption("")
		Sfx.play(&"ding", 1.2, -8.0)
		Juice.pop(_band_btns[i], 1.1, 0.2)
	return BANDS[i]


func _solve_band(best: int) -> void:
	if not _band_mode:
		return
	_pointer = best
	_confirm_band()


func _move_pointer(step: int) -> void:
	var p := _pointer
	for k in BANDS.size():
		p = clampi(p + step, 0, BANDS.size() - 1)
		if not _dead_bands.has(p):
			break
	if not _dead_bands.has(p) and p != _pointer:
		_pointer = p
		Sfx.play(&"blip", 1.2, -10.0)


func _confirm_band() -> void:
	if not _band_mode:
		return
	_band_mode = false
	Sfx.play(&"click")
	_band_picked.emit(_pointer)


## (coroutine) The receipt prints "{BAND} SNR LOSS" and the PAID stamp lands.
func pay(band: StringName) -> void:
	_paid = band
	_paid_t = 0.0
	_pointer = BANDS.find(band)
	_dead_bands.clear()
	Sfx.play(&"stamp", 0.8, -4.0)
	await _wait(0.9)


## (coroutine) After list 2: the receipt reprints both lists and their average (no question).
func show_average(lists: Array, avg: float, band: StringName) -> void:
	_stage = &"bill"
	_avg_lists = lists.duplicate(true)
	_avg = avg
	_avg_band = band
	_paid = &""
	_pointer = maxi(0, BANDS.find(band))
	_head.text = "THE BILL, TWO LISTS"
	_show_caption("")
	_print_t = PRINT_S if _reduced() else 0.0
	Sfx.play(&"kaching", 1.1, -8.0)
	await _wait(0.2 if _reduced() else PRINT_S + 0.2)
	_paid = band
	_paid_t = 0.0
	Sfx.play(&"stamp", 0.8, -6.0)
	await _wait(0.6)


# ---------------------------------------------------------------- 2. the plates

## The four clue cards with this visit's numbers (CHAPTER5 §5.7), in their fixed order: {id, head,
## text, fits ("quiet", "noisy" or ""), best, right_line, wrong_line}.
static func plate_cards(r_pct: int, l_pct: int, wband: String, pta: int, avg: float, sband: String) -> Array[Dictionary]:
	return [
		{"id": "pta", "head": "AUDIOGRAM", "text": "PTA about %d: near-normal beeps" % pta, "fits": "quiet", "best": false,
			"right_line": line("quiet_pta"), "wrong_line": line("other_plate")},
		{"id": "snr_loss", "head": "PARTY TEST", "text": "Party test: SNR loss %.1f dB" % avg, "fits": "noisy", "best": true,
			"right_line": line("noisy_right", {"band": sband}), "wrong_line": line("other_plate")},
		{"id": "canals", "head": "OTOSCOPE", "text": "Canals clear, eardrums healthy", "fits": "", "best": false,
			"right_line": "", "wrong_line": line("distractor")},
		{"id": "words_quiet", "head": "WORD LISTS", "text": "Words in quiet: %d%% and %d%%" % [r_pct, l_pct], "fits": "quiet", "best": true,
			"right_line": line("quiet_right", {"band": wband}), "wrong_line": line("other_plate")},
	]


func _build_plates() -> void:
	for p: String in PLATES:
		var c := Control.new()
		c.name = "plate_" + p
		c.mouse_filter = Control.MOUSE_FILTER_STOP
		c.position = (PLATE_AT[p] as Vector2) - Vector2.ONE * PLATE_R
		c.size = Vector2.ONE * PLATE_R * 2.0
		c.visible = false
		c.gui_input.connect(_on_plate_input.bind(p))
		add_child(c)
		_plate_nodes[p] = c
		Hoot.register_anchor("plate_" + p, c)


## (coroutine) The bill steps aside; the two plates and the four cards come in.
func setup_plates(cards: Array[Dictionary]) -> void:
	_cards = cards.duplicate(true)
	var t := create_tween().set_parallel(true)
	t.tween_property(_ruler, "modulate:a", 0.0, 0.25)
	await t.finished
	_ruler.visible = false
	_stage = &"plates"
	_head.text = "TWO CLAIMS, TWO PLATES"
	for p: String in PLATES:
		(_plate_nodes[p] as Control).visible = true
	var total := CARD_SIZE.x * _cards.size() + 18.0 * (_cards.size() - 1)
	for i in _cards.size():
		var node := _make_card(i)
		node.position = Vector2((1280.0 - total) * 0.5 + i * (CARD_SIZE.x + 18.0), CARDS_Y)
		Juice.bounce_in(node, 0.3)
	# the stamp and the captions draw over the cards
	move_child(_caption, -1)
	move_child(_fx, -1)
	Sfx.play(&"whoosh", 1.1, -12.0)
	await _wait(0.4)


func _make_card(i: int) -> PanelContainer:
	var c: Dictionary = _cards[i]
	var p := PanelContainer.new()
	p.name = "clue_" + String(c["id"])
	p.add_theme_stylebox_override("panel", UiKit.style(CARD_NEUTRAL, Palette.INK, 14, 3, 6, 12))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.custom_minimum_size = CARD_SIZE
	p.size = CARD_SIZE
	p.pivot_offset = CARD_SIZE * 0.5
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(top)
	if UiKit.show_key_hints():
		top.add_child(UiKit.key_chip(str(i + 1), 13))
	top.add_child(UiKit.label("  " + String(c["head"]), 13, Palette.INK_SOFT, 700))
	var l := UiKit.label(String(c["text"]), 21, Palette.INK, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CARD_SIZE.x - 30.0, 0)
	v.add_child(l)
	p.gui_input.connect(_on_card_input.bind(i))
	p.mouse_entered.connect(func() -> void:
		_hover = i
		_restyle())
	p.mouse_exited.connect(func() -> void:
		if _hover == i:
			_hover = -1
		_restyle())
	add_child(p)
	_card_nodes.append(p)
	Hoot.register_anchor("clue_" + String(c["id"]), p)
	return p


func _restyle() -> void:
	for j in _card_nodes.size():
		var col := CARD_PICK if j == _selected else (CARD_HOVER if j == _hover and _accepting and not _used.has(j) else CARD_NEUTRAL)
		_card_nodes[j].add_theme_stylebox_override("panel", UiKit.style(col, Palette.INK, 14, 4 if j == _selected else 3, 6, 12))


## (coroutine) One plates_serve beat per empty plate, quiet first; a card on the wrong plate (or the
## distractor anywhere) bounces back with Hoot's caption.
func run_plates() -> void:
	await get_tree().process_frame
	if UiKit.show_key_hints():
		_set_hints([["1"], "-", ["4"], "serve the glowing plate", "   or drag a card onto a plate"])
	else:
		_set_hints(["Drag a card onto a plate, or click a card, then a plate"])
	for p: String in PLATES:
		while not _served.has(p):
			_cur_plate = p
			_accepting = true
			var best := _best_for(p)
			var ids: Array[String] = []
			for c: Dictionary in _cards:
				ids.append(String(c["id"]))
			Events.awaiting_input.emit(&"plates_serve", {"plate": p, "cards": ids, "best": ids[best],
				"mouse": {"drag": ["clue_" + ids[best], "plate_" + p]}}, _serve.bind(best, p))
			await _served_sig
			Events.input_resolved.emit(&"plates_serve")
	_accepting = false
	_cur_plate = ""
	_set_hints([])
	await _wait(0.3)
	var fade := create_tween().set_parallel(true)
	for i in _card_nodes.size():
		if not _used.has(i):
			fade.tween_property(_card_nodes[i], "modulate:a", 0.0, 0.25)
	_both_t = 0.0
	Sfx.play(&"stamp", 0.7, 0.0)
	if not _reduced():
		Juice.shake(self, 10.0, 0.35)
	await _wait(0.9)
	_banner_t = 0.0
	Sfx.play(&"fanfare", 1.0, -12.0)
	_show_caption("")
	await _wait(1.0)


func _best_for(plate: String) -> int:
	for i in _cards.size():
		if String(_cards[i]["fits"]) == plate and bool(_cards[i]["best"]) and not _used.has(i):
			return i
	for i in _cards.size():
		if String(_cards[i]["fits"]) == plate and not _used.has(i):
			return i
	return 0


## Serve card i onto a plate (keys, a drop, click-then-click, or the solver).
func _serve(i: int, plate: String) -> void:
	if not _accepting or i < 0 or i >= _cards.size() or _used.has(i) or _served.has(plate):
		return
	_accepting = false
	_selected = -1
	var c: Dictionary = _cards[i]
	var node := _card_nodes[i]
	if String(c["fits"]) == plate:
		_served[plate] = i
		_used[i] = plate
		if String(c["id"]) == "pta":
			pta_used = true
		_show_caption(String(c["right_line"]), Color("#1f7a55"))
		Sfx.play(&"ding", 1.1 if plate == "quiet" else 1.3, -8.0)
		var to: Vector2 = (PLATE_AT[plate] as Vector2) - CARD_SIZE * 0.5 + Vector2(0, 8)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := node.create_tween().set_parallel(true)
		t.tween_property(node, "position", to, 0.25 if _reduced() else 0.4).set_trans(Tween.TRANS_SINE)
		t.tween_property(node, "scale", Vector2.ONE * 0.72, 0.25 if _reduced() else 0.4)
		t.tween_property(node, "rotation", -0.05 if plate == "quiet" else 0.05, 0.25 if _reduced() else 0.4)
		_restyle()
		await t.finished
	else:
		plate_slips += 1
		_show_caption(String(c["wrong_line"]))
		Sfx.play(&"thunk", 0.6, -8.0)
		_restyle()
		if _reduced():
			node.modulate.a = 0.5
			var tr := node.create_tween()
			tr.tween_property(node, "modulate:a", 1.0, 0.3)
			await tr.finished
		else:
			var home := node.position
			var t := node.create_tween()
			t.tween_property(node, "position", home + Vector2(0, -40), 0.14).set_trans(Tween.TRANS_SINE)
			t.tween_property(node, "position", home, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			await t.finished
	await _wait(0.3)
	_served_sig.emit()


func _on_card_input(event: InputEvent, i: int) -> void:
	if not _accepting or _used.has(i):
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_dragging = i
			_make_ghost(i, mb.global_position)
		else:
			var at := mb.global_position
			_dragging = -1
			_free_ghost()
			var dropped := ""
			for p: String in PLATES:
				if at.distance_to(PLATE_AT[p] as Vector2) <= PLATE_R + 20.0:
					dropped = p
			if dropped != "":
				_serve(i, dropped)
			elif _card_nodes[i].get_global_rect().has_point(at):
				# a click: select it, then click a plate
				_selected = i
				Sfx.play(&"blip", 1.3, -8.0)
				_restyle()
		accept_event()
	elif event is InputEventMouseMotion and _dragging == i and _ghost:
		_ghost.position = (event as InputEventMouseMotion).global_position - _ghost.size * 0.5


func _on_plate_input(event: InputEvent, plate: String) -> void:
	if not _accepting:
		return
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if _selected >= 0:
			_serve(_selected, plate)
		accept_event()


func _make_ghost(i: int, at: Vector2) -> void:
	_free_ghost()
	_ghost = UiKit.panel(CARD_PICK, Palette.INK, 12)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.add_child(UiKit.label(String(_cards[i]["text"]), 17, Palette.INK, 700))
	_ghost.rotation = -0.05
	add_child(_ghost)
	_ghost.reset_size()
	_ghost.position = at - _ghost.size * 0.5


func _free_ghost() -> void:
	if _ghost:
		_ghost.queue_free()
		_ghost = null


# ---------------------------------------------------------------- 3-4. the pizza and the switch

## (coroutine) Top-down Marco between the speakers; the whole pizza appears round his head.
func show_pizza() -> void:
	_hide_plates()
	_stage = &"pizza"
	_head.text = "THE PIZZA OF SOUND"
	_show_caption("")
	_focus_k = 0.0
	_pizza_t = 1.0 if _reduced() else 0.0
	Sfx.play(&"pop", 1.0, -10.0)
	await _wait(0.9)


## The front half stays bright and the back half dims (never removed); a cut with reduced motion.
func pizza_focus(on: bool) -> void:
	if _reduced():
		_focus_k = 1.0 if on else 0.0
		return
	var t := create_tween()
	t.tween_property(self, "_focus_k", 1.0 if on else 0.0, 0.6).set_trans(Tween.TRANS_SINE)


func _hide_plates() -> void:
	for p: String in PLATES:
		(_plate_nodes[p] as Control).visible = false
	for n: PanelContainer in _card_nodes:
		n.visible = false
	_both_t = -1.0
	_banner_t = -1.0


func _build_switch() -> void:
	_switch = Button.new()
	_switch.name = "party_focus_switch"
	_switch.flat = true
	_switch.focus_mode = Control.FOCUS_NONE
	_switch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_switch.size = SWITCH_SIZE
	_switch.custom_minimum_size = SWITCH_SIZE
	_switch.position = REMOTE.get_center() - SWITCH_SIZE * 0.5 + Vector2(0, 30)
	_switch.visible = false
	_switch.draw.connect(_draw_switch)
	_switch.pressed.connect(_flip)
	add_child(_switch)
	Hoot.register_anchor("party_focus_switch", _switch)


## (coroutine) The aid remote, switch on A; Marco's eyes closed.
func show_switch() -> void:
	_stage = &"switch"
	_head.text = "BLIND TASTING"
	_switch_on = false
	_knob_k = 0.0
	_switch.visible = true
	Juice.bounce_in(_switch, 0.3)
	await _wait(0.35)


## (coroutine) Beat focus_switch: flip to programme B ({key:advance_dialogue} or a click).
func flip_switch() -> void:
	_switch_mode = true
	_armed_at = _t
	if UiKit.show_key_hints():
		_set_hints([[Game.key_label(&"advance_dialogue")], "or click the switch"])
	else:
		_set_hints(["Click the switch"])
	Events.awaiting_input.emit(&"focus_switch", {"mouse": {"click": "party_focus_switch"}}, _flip)
	while not _switch_on:
		await _flipped
	Events.input_resolved.emit(&"focus_switch")
	_set_hints([])
	if _reduced():
		_knob_k = 1.0
	else:
		var t := create_tween()
		t.tween_property(self, "_knob_k", 1.0, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await t.finished
	await _wait(0.3)


func _flip() -> void:
	if not _switch_mode or _switch_on:
		return
	_switch_mode = false
	_switch_on = true
	Sfx.play(&"click", 0.8, -2.0)
	_flipped.emit()


# ---------------------------------------------------------------- 5. the reveal card

## (coroutine) A against B: each programme's two list totals and average SNR loss, the arrow, and
## whether the difference beats the critical difference. The chips turn into A: OMNI and B: FOCUS.
func show_reveal(omni: Dictionary, focus: Dictionary, benefit: float, crit: float, real: bool) -> void:
	_switch.visible = false
	_stage = &"reveal"
	_head.text = "THE REVEAL"
	_reveal = {"a": _column(omni), "b": _column(focus), "benefit": benefit, "crit": crit, "real": real, "named": false}
	_reveal_t = 0.0
	Sfx.play(&"whoosh", 1.0, -12.0)
	await _wait(0.7)
	_reveal["named"] = true
	Sfx.play(&"ding", 1.0, -8.0)
	await _wait(0.4)


## One reveal column: [[list title, total, by Hoot]], the average SNR loss.
static func _column(sheet: Dictionary) -> Dictionary:
	var rows: Array = []
	for v: Variant in sheet.get("lists", []):
		var l: Dictionary = v
		rows.append([String(l.get("list_title", "")), int(l.get("total", 0)), int(l.get("hoot_sentences", 0)) > 0])
	return {"rows": rows, "loss": float(sheet.get("snr_loss", 0.0))}


## (coroutine) Fade the whole board away.
func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _band_mode:
		if event.is_action_pressed(&"speech_incorrect"):
			_move_pointer(-1)
		elif event.is_action_pressed(&"speech_correct"):
			_move_pointer(1)
		elif (event.is_action_pressed(&"advance_dialogue") or event.is_action_pressed(&"store")) and _t - _armed_at > 0.15:
			_confirm_band()
		else:
			return
		get_viewport().set_input_as_handled()
	elif _accepting and _stage == &"plates":
		for i in mini(4, _cards.size()):
			if event.is_action_pressed(StringName("party_word_%d" % (i + 1))):
				_serve(i, _cur_plate)
				get_viewport().set_input_as_handled()
				return
	elif _switch_mode and event.is_action_pressed(&"advance_dialogue") and _t - _armed_at > 0.15:
		_flip()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawing

func _process(delta: float) -> void:
	_t += delta
	for v: String in ["_print_t", "_paid_t", "_both_t", "_banner_t", "_pizza_t", "_reveal_t"]:
		var x: float = get(v)
		if x >= 0.0:
			set(v, x + delta)
	_art.queue_redraw()
	_fx.queue_redraw()
	for b: Button in _band_btns:
		b.queue_redraw()
	if _switch.visible:
		_switch.queue_redraw()


func _draw_art() -> void:
	match _stage:
		&"bill":
			_draw_receipt()
			if _ruler.visible:
				_draw_ruler()
		&"plates":
			_draw_plates()
		&"pizza":
			_draw_pizza()
		&"switch":
			_draw_remote()
		&"reveal":
			_draw_reveal()


## The till receipt: a zigzag-edged strip of paper, rows with dotted leaders, the formula, then the
## band line once paid. Rows print top to bottom over PRINT_S.
func _draw_receipt() -> void:
	var r := RECEIPT
	var pts := PackedVector2Array()
	pts.append(r.position)
	pts.append(Vector2(r.end.x, r.position.y))
	var teeth := 18
	for k in teeth + 1:
		var x := r.end.x - r.size.x * k / float(teeth)
		pts.append(Vector2(x, r.end.y - (0.0 if k % 2 == 0 else 10.0)))
	_art.draw_colored_polygon(pts, Color(Palette.INK, 0.18))
	var shifted := PackedVector2Array()
	for p in pts:
		shifted.append(p - Vector2(4, 6))
	_art.draw_colored_polygon(shifted, RECEIPT_PAPER)
	_art.draw_polyline(shifted + PackedVector2Array([shifted[0]]), Color(Palette.INK, 0.6), 2.0, true)
	var f := UiKit.font(600)
	var fb := UiKit.font(700)
	var x0 := r.position.x + 18.0
	var x1 := r.end.x - 26.0
	var rows: Array = []   # [left, right, size, bold, centred]
	if _avg_lists.is_empty():
		rows.append(["TRATTORIA BOOTH CAMP", "", 19, true, true])
		rows.append(["TABLE 5 . %s" % String(_rec.get("list_title", "Party list 1")).to_upper(), "", 15, false, true])
		rows.append(["", "", 8, false, false])
		for row: Array in receipt_rows(_rec):
			rows.append([String(row[0]), String(row[1]), 17, String(row[0]) == "KEY WORDS RIGHT", false])
		rows.append(["SNR LOSS = 25.5 - KEY WORDS RIGHT", "", 16, true, true])
	else:
		rows.append(["TRATTORIA BOOTH CAMP", "", 19, true, true])
		rows.append(["TABLE 5 . TWO PARTY LISTS", "", 15, false, true])
		rows.append(["", "", 8, false, false])
		for v: Variant in _avg_lists:
			var l: Dictionary = v
			rows.append([String(l.get("list_title", "")).to_upper(), "", 17, true, false])
			rows.append(["  key words right", str(int(l.get("total", 0))), 16, false, false])
			rows.append(["  SNR loss", "%.1f dB" % float(l.get("snr_loss", 0.0)), 16, false, false])
		rows.append(["", "", 8, false, false])
		rows.append(["AVERAGE OF 2 LISTS", "%.1f dB" % _avg, 18, true, false])
	var shown := rows.size() if _print_t < 0.0 else int(ceil(rows.size() * clampf(_print_t / PRINT_S, 0.0, 1.0)))
	var y := r.position.y + 30.0
	for i in mini(shown, rows.size()):
		var row: Array = rows[i]
		var size := int(row[2])
		var ff := fb if bool(row[3]) else f
		var left := String(row[0])
		var right := String(row[1])
		if left == "" and right == "":
			_art.draw_dashed_line(Vector2(x0, y - 4.0), Vector2(x1, y - 4.0), Color(RECEIPT_INK, 0.5), 1.5, 6.0)
			y += size + 6.0
			continue
		if bool(row[4]):
			var tw := ff.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			_art.draw_string(ff, Vector2((x0 + x1 - tw) * 0.5, y + size), left, HORIZONTAL_ALIGNMENT_LEFT, -1, size, RECEIPT_INK)
		else:
			_art.draw_string(ff, Vector2(x0, y + size), left, HORIZONTAL_ALIGNMENT_LEFT, -1, size, RECEIPT_INK)
			if right != "":
				var rw := ff.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				_art.draw_string(ff, Vector2(x1 - rw, y + size), right, HORIZONTAL_ALIGNMENT_LEFT, -1, size, RECEIPT_INK)
				var lw := ff.get_string_size(left, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
				var dot_from := x0 + lw + 8.0
				var dot_to := x1 - rw - 8.0
				var dx := dot_from
				while dx < dot_to:
					_art.draw_circle(Vector2(dx, y + size - 4.0), 1.2, Color(RECEIPT_INK, 0.5))
					dx += 7.0
		y += size + 9.0
	var band := _paid if _paid != &"" else &""
	if band != &"" and shown >= rows.size():
		var text := "%s SNR LOSS" % String(SpeechRules.SIN_BAND_NAMES.get(band, "")).to_upper()
		var tw := fb.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var box := Rect2(Vector2((x0 + x1 - tw) * 0.5 - 12.0, y + 2.0), Vector2(tw + 24.0, 34.0))
		UiDraw.rounded_rect(_art, box, Color(BAND_COLORS.get(band, Palette.SUNNY) as Color, 0.35), 8, 2, RECEIPT_INK)
		_art.draw_string(fb, Vector2(box.position.x + 12.0, box.position.y + 26.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, RECEIPT_INK)


## The menu's ruler: its panel and title, and the pointer over the band it points at.
func _draw_ruler() -> void:
	UiDraw.rounded_rect(_art, RULER, Palette.PAPER, 18, 3, Palette.INK)
	var f := UiKit.font(700)
	var title := "THE MENU: SNR LOSS BANDS"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_art.draw_string(f, Vector2(RULER.get_center().x - tw * 0.5, RULER.position.y + 34.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	if _band_mode or _paid != &"":
		var b := _band_btns[_pointer]
		var c := Vector2(b.position.x + BAND_SIZE.x * 0.5, b.position.y - 4.0)
		var bob := 0.0 if _reduced() or not _band_mode else sin(_t * 5.0) * 3.0
		UiDraw.triangle(_art, c + Vector2(0, -6.0 + bob), 22.0, false, Palette.SELECT_ORANGE)


func _draw_band_button(btn: Button, i: int) -> void:
	var b: StringName = BANDS[i]
	var col: Color = BAND_COLORS[b]
	var r := Rect2(Vector2.ZERO, BAND_SIZE)
	var dead := _dead_bands.has(i)
	var on := (_band_mode or _paid != &"") and _pointer == i
	UiDraw.rounded_rect(btn, r, Color(col, 0.18 if dead else 0.5), 14, 4 if on else 2, Palette.SELECT_ORANGE if on else Color(Palette.INK, 0.5 if dead else 1.0))
	if on and _paid != &"":
		UiDraw.check(btn, Vector2(BAND_SIZE.x - 18.0, 16.0), 12.0, Palette.INK, 3.0)


func _draw_plates() -> void:
	var f := UiKit.font(700)
	for p: String in PLATES:
		var c: Vector2 = PLATE_AT[p]
		var glow := _accepting and _cur_plate == p
		_art.draw_circle(c + Vector2(0, 8), PLATE_R + 4.0, Color(Palette.INK, 0.15))
		_art.draw_circle(c, PLATE_R + 4.0, Palette.INK)
		_art.draw_circle(c, PLATE_R, Color("#ffffff"))
		_art.draw_arc(c, PLATE_R * 0.72, 0.0, TAU, 48, Color("#d9dde6"), 3.0, true)
		if glow:
			var a := 0.55 if _reduced() else 0.4 + 0.25 * sin(_t * 4.0)
			_art.draw_arc(c, PLATE_R + 12.0, 0.0, TAU, 64, Color(Palette.SUNNY, a), 8.0, true)
		# the claim, in a speech bubble above the plate
		var claim := String(CLAIMS[p])
		var tw := f.get_string_size(claim, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var box := Rect2(Vector2(c.x - tw * 0.5 - 16.0, c.y - PLATE_R - 52.0), Vector2(tw + 32.0, 38.0))
		UiDraw.rounded_rect(_art, box, Palette.PAPER, 14, 3, Palette.INK)
		_art.draw_string(f, Vector2(box.position.x + 16.0, box.position.y + 27.0), claim, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Palette.INK)
		if not _served.has(p):
			var hint := "CLAIM " + ("ONE" if p == "quiet" else "TWO")
			var hw := f.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
			_art.draw_string(f, Vector2(c.x - hw * 0.5, c.y + 6.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.INK, 0.35))
	# Marco between the plates, a little portrait
	Portraits.draw(_art, "Marco", Vector2(640, 280), 50.0, fmod(_t, 0.6) < 0.3 and _accepting, false)


func _draw_pizza() -> void:
	var f := UiKit.font(700)
	var c := PIZZA_AT
	# the speakers: TALKER in front (up), PARTY behind (down)
	_draw_speaker(c + Vector2(0, -PIZZA_R - 40.0), "TALKER", Color("#2f9e73"), true)
	_draw_speaker(c + Vector2(0, PIZZA_R + 40.0), "PARTY", Color("#e07a2f"), false)
	var grow := 1.0 if _pizza_t < 0.0 else clampf(_pizza_t / 0.6, 0.0, 1.0)
	var r := PIZZA_R * (1.0 if _reduced() else ease(grow, -2.0))
	if r > 2.0:
		var back_a := lerpf(1.0, 0.32, _focus_k)
		# the back half (behind him, down) then the front half
		_draw_half(c, r, PI * 0.0, PI, back_a)
		_draw_half(c, r, PI, TAU, 1.0)
		_art.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), Color(Palette.INK, 0.6), 3.0)
		var front := "FRONT"
		var back := "BACK"
		var fw := f.get_string_size(front, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var bw := f.get_string_size(back, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		_art.draw_string(f, Vector2(c.x - fw * 0.5 - r * 0.5, c.y - r * 0.45), front, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.INK)
		_art.draw_string(f, Vector2(c.x - bw * 0.5 - r * 0.5, c.y + r * 0.6), back, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Palette.INK, back_a))
	# Marco from above: head, ears, nose pointing to the front, the napkin's corner
	_art.draw_circle(c, 40.0, Palette.INK)
	_art.draw_circle(c, 36.0, Color("#dfe3ea"))
	_art.draw_circle(c + Vector2(-38, 4), 9.0, Palette.SKIN)
	_art.draw_circle(c + Vector2(38, 4), 9.0, Palette.SKIN)
	_art.draw_colored_polygon(PackedVector2Array([c + Vector2(-9, -34), c + Vector2(9, -34), c + Vector2(0, -50)]), Palette.SKIN)
	# the two programmes' names at the side
	var side: Array[String] = ["OMNI: the whole pizza", "FOCUS: front bright, back dimmed"]
	for k in side.size():
		var on := (k == 0 and _focus_k < 0.5) or (k == 1 and _focus_k >= 0.5)
		_art.draw_string(f, Vector2(c.x + PIZZA_R + 60.0, c.y - 20.0 + k * 40.0), side[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Palette.INK if on else Color(Palette.INK, 0.35))


func _draw_half(c: Vector2, r: float, a0: float, a1: float, alpha: float) -> void:
	var crust := Color("#d8913d", alpha)
	var cheese := Color("#ffd966", alpha)
	var pts := PackedVector2Array([c])
	for k in 25:
		pts.append(c + Vector2.from_angle(lerpf(a0, a1, k / 24.0)) * r)
	_art.draw_colored_polygon(pts, crust)
	var inner := PackedVector2Array([c])
	for k in 25:
		inner.append(c + Vector2.from_angle(lerpf(a0, a1, k / 24.0)) * (r - 14.0))
	_art.draw_colored_polygon(inner, cheese)
	# pepperoni, fixed spots
	for k in 5:
		var a := lerpf(a0, a1, (k + 0.5) / 5.0)
		var rr := r * (0.62 if k % 2 == 0 else 0.8)
		_art.draw_circle(c + Vector2.from_angle(a) * rr, r * 0.075, Color("#d1433a", alpha))


func _draw_speaker(at: Vector2, text: String, col: Color, front: bool) -> void:
	var box := Rect2(at - Vector2(46, 26), Vector2(92, 52))
	UiDraw.rounded_rect(_art, box, Palette.INK, 10, 0)
	_art.draw_circle(at + Vector2(-16, 0), 15.0, Color("#8d94a6"))
	_art.draw_circle(at + Vector2(22, 0), 9.0, Color("#8d94a6"))
	var f := UiKit.font(700)
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	_art.draw_string(f, Vector2(at.x + 60.0, at.y + 7.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, col)
	if not front:
		var sub := "the party, behind him"
		_art.draw_string(UiKit.font(600), Vector2(at.x + 60.0 + tw + 10.0, at.y + 7.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)
	else:
		var sub := "the voice, in front"
		_art.draw_string(UiKit.font(600), Vector2(at.x + 60.0 + tw + 10.0, at.y + 7.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)


## The aid remote, Marco with his eyes closed (and his napkin), and the programme chip.
func _draw_remote() -> void:
	var r := REMOTE
	UiDraw.rounded_rect(_art, r.grow(6), Color(Palette.INK, 0.18), 40, 0)
	UiDraw.rounded_rect(_art, r, Color("#3b3f52"), 40, 4, Palette.INK)
	var f := UiKit.font(700)
	var title := "MARCO'S AIDS"
	var tw := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	_art.draw_string(f, Vector2(r.get_center().x - tw * 0.5, r.position.y + 44.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.LCD_TEXT)
	var chip := "PROGRAMME B" if _switch_on else "PROGRAMME A"
	var cw := f.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var cr := Rect2(Vector2(r.get_center().x - cw * 0.5 - 14.0, r.position.y + 62.0), Vector2(cw + 28.0, 32.0))
	UiDraw.rounded_rect(_art, cr, Palette.LCD_BG, 10, 2, Palette.SELECT_ORANGE)
	_art.draw_string(f, Vector2(cr.position.x + 14.0, cr.position.y + 23.0), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.SELECT_ORANGE)
	# Marco, eyes closed, beside the remote
	var mc := Vector2(330, 320)
	Portraits.draw(_art, "Marco", mc, 80.0, false, true)
	var zz := "eyes closed"
	_art.draw_string(UiKit.font(600), mc + Vector2(-44, 118), zz, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_SOFT)


func _draw_switch() -> void:
	var s := SWITCH_SIZE
	var f := UiKit.font(700)
	var track := Rect2(Vector2(50, 18), Vector2(s.x - 100, s.y - 36))
	UiDraw.rounded_rect(_switch, track, Palette.LCD_BG, 28, 3, Palette.LCD_TEXT)
	var kx := lerpf(track.position.x + 28.0, track.end.x - 28.0, _knob_k)
	var knob_col := Palette.SUNNY if _switch_mode and fmod(_t, 1.0) < 0.5 and not _reduced() else Palette.MINT if _switch_on else Palette.SUNNY
	_switch.draw_circle(Vector2(kx, s.y * 0.5), 26.0, Palette.INK)
	_switch.draw_circle(Vector2(kx, s.y * 0.5), 23.0, knob_col)
	_switch.draw_string(f, Vector2(8, s.y * 0.5 + 12.0), "A", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Palette.LCD_TEXT if not _switch_on else Palette.LCD_DIM)
	_switch.draw_string(f, Vector2(s.x - 30, s.y * 0.5 + 12.0), "B", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Palette.LCD_TEXT if _switch_on else Palette.LCD_DIM)


func _draw_reveal() -> void:
	if _reveal.is_empty():
		return
	var f := UiKit.font(700)
	var fr := UiKit.font(600)
	var named := bool(_reveal["named"])
	var cols: Array = [["a", "A: OMNI" if named else "PROGRAMME A", Palette.SUNNY, Rect2(150, 130, 380, 300)],
		["b", "B: FOCUS" if named else "PROGRAMME B", Palette.MINT, Rect2(750, 130, 380, 300)]]
	for col: Array in cols:
		var r: Rect2 = col[3]
		var data: Dictionary = _reveal[String(col[0])]
		UiDraw.rounded_rect(_art, r, Palette.PAPER, 18, 3, Palette.INK)
		var chip := String(col[1])
		var cw := f.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var cr := Rect2(Vector2(r.get_center().x - cw * 0.5 - 16.0, r.position.y + 16.0), Vector2(cw + 32.0, 38.0))
		UiDraw.rounded_rect(_art, cr, col[2] as Color, 12, 3, Palette.INK)
		_art.draw_string(f, Vector2(cr.position.x + 16.0, cr.position.y + 28.0), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Palette.INK)
		var y := r.position.y + 90.0
		for row: Array in data["rows"]:
			var left := "%s%s" % [String(row[0]), "*" if bool(row[2]) else ""]
			var right := "%d key words" % int(row[1])
			_art.draw_string(fr, Vector2(r.position.x + 24.0, y), left, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Palette.INK)
			var rw := fr.get_string_size(right, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			_art.draw_string(fr, Vector2(r.end.x - 24.0 - rw, y), right, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Palette.INK)
			y += 34.0
		var loss := "SNR loss %.1f dB" % float(data["loss"])
		var lw := f.get_string_size(loss, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		_art.draw_string(f, Vector2(r.get_center().x - lw * 0.5, r.position.y + 210.0), loss, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.INK)
		var sub := "aided, sound field"
		var sw := fr.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		_art.draw_string(fr, Vector2(r.get_center().x - sw * 0.5, r.position.y + 244.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.INK_SOFT)
		var star := "* Hoot scored some of that list."
		var any_star := false
		for row: Array in data["rows"]:
			any_star = any_star or bool(row[2])
		if any_star:
			var stw := fr.get_string_size(star, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			_art.draw_string(fr, Vector2(r.get_center().x - stw * 0.5, r.end.y - 16.0), star, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_SOFT)
	# the arrow between them, and the verdict under it
	var k := 1.0 if _reduced() else clampf(_reveal_t / 0.5, 0.0, 1.0)
	var a0 := Vector2(548, 270)
	var a1 := Vector2(lerpf(548, 732, k), 270)
	_art.draw_line(a0, a1, Palette.INK, 10.0)
	if k > 0.9:
		UiDraw.arrow(_art, a1 + Vector2(-6, 0), 26.0, Vector2.RIGHT, Palette.INK)
	var better := "%.1f dB better" % float(_reveal["benefit"])
	var bw := f.get_string_size(better, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	_art.draw_string(f, Vector2(640 - bw * 0.5, 240), better, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.INK)
	var real := bool(_reveal["real"])
	var verdict := "2 lists each: %.1f dB needed. %s" % [float(_reveal["crit"]), "REAL." if real else "Could be luck."]
	var vw := f.get_string_size(verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	var vr := Rect2(Vector2(640 - vw * 0.5 - 18.0, 452), Vector2(vw + 36.0, 44.0))
	UiDraw.rounded_rect(_art, vr, Color(Palette.MINT, 0.35) if real else Color(Palette.SUNNY, 0.35), 14, 3, Palette.INK)
	_art.draw_string(f, Vector2(vr.position.x + 18.0, vr.position.y + 31.0), verdict, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.INK)


func _draw_fx() -> void:
	var f := UiKit.font(700)
	if _stage == &"bill" and _paid != &"" and _paid_t >= 0.0:
		var k := 1.0
		if _paid_t < 0.18 and not _reduced():
			k = 1.0 + 1.2 * (1.0 - _paid_t / 0.18)
		var fs := int(56 * k)
		var text := "PAID"
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var c := RECEIPT.get_center() + Vector2(70, 40)
		var col := Color("#d1433a")
		_fx.draw_set_transform(c, -0.22, Vector2.ONE)
		var box := Rect2(Vector2(-tw * 0.5 - 16.0, -fs * 0.62), Vector2(tw + 32.0, fs * 1.1))
		_fx.draw_rect(box, Color(col, 0.1))
		_fx.draw_rect(box, col, false, 5.0)
		_fx.draw_string(f, Vector2(-tw * 0.5, fs * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _stage == &"plates" and _both_t >= 0.0:
		var k := 1.0
		if _both_t < 0.18 and not _reduced():
			k = 1.0 + 1.0 * (1.0 - _both_t / 0.18)
		var fs := int(84 * k)
		var text := "BOTH TRUE!"
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var col := Color("#2f9e73")
		_fx.draw_set_transform(Vector2(640, 292), -0.1, Vector2.ONE)
		var box := Rect2(Vector2(-tw * 0.5 - 22.0, -fs * 0.62), Vector2(tw + 44.0, fs * 1.1))
		_fx.draw_rect(box, Color(Palette.PAPER, 0.85))
		_fx.draw_rect(box, col, false, 7.0)
		_fx.draw_string(f, Vector2(-tw * 0.5, fs * 0.3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _stage == &"plates" and _banner_t >= 0.0:
		var a := 1.0 if _reduced() else clampf(_banner_t / 0.3, 0.0, 1.0)
		var text := "THE AUDIOGRAM ISN'T THE WHOLE STORY"
		var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		var r := Rect2(Vector2(640 - tw * 0.5 - 26.0, 432), Vector2(tw + 52.0, 52.0))
		UiDraw.rounded_rect(_fx, r, Color(Palette.INK, a), 16, 0)
		_fx.draw_string(f, Vector2(r.position.x + 26.0, r.position.y + 37.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(Palette.SUNNY, a))


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
