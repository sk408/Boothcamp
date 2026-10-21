class_name SpSentenceCard
extends Control
## SpSentenceCard: the clinician's sentence card in PARTY mode (ui/speech only; CONTRACTS.md §9.18.1,
## docs/CHAPTER5.md §5.2-§5.3). It takes the word card's place: the sentence the next PRESENT will say
## (the patient never sees it), its five key words as chunky numbered chips (at least 96 x 56 px,
## wrapping to two rows) and the little words in plain small text between them.
##
## The chips wake only after the answer shows (state &"marking"): the focus chip wears the sunny ring,
## the footer names its keys ("-> got it . <- missed") and counts "3 / 5 so far". Got = mint, a tick
## and a bold word; missed = a coral outline, a cross and a struck-through word (colour is never the
## only cue). Each chip is a child Control named party_key_<n> (its Hoot anchor): a left click emits
## chip_pressed(n), a right click chip_right_pressed(n); the mode decides what they do.
## lock_in() turns blanks into crosses and sends the missed words back to the kitchen on a passing
## waiter's tray (reduced motion: they just grey out); the locked sentence stays up for LOCKED_HOLD_S,
## then the next one shows. Only marks are drawn: never the truth before LOCK IN.

signal chip_pressed(key: int)
signal chip_right_pressed(key: int)

const CHIP_MIN := Vector2(96.0, 56.0)
const CHIP_FONT := 26
const CHIP_FONT_MIN := 20
const LITTLE_FONT := 22
const HEAD_H := 28.0
const FOOT_H := 26.0
const ROW_GAP := 8.0
const TOKEN_GAP := 8.0
## The locked sentence stays on the card this long before the next one shows (unless PRESENT comes first).
const LOCKED_HOLD_S := 1.6
## The waiter's ride (seconds).
const TRAY_S := 1.5
const FLASH_S := 1.2

## &"empty", &"idle" (NEXT SENTENCE), &"talking" (NOW SAYING), &"listening", &"marking" (the chips are
## awake), &"locked" (billed: blanks are crosses), &"done" (the list is finished).
var state: StringName = &"empty":
	set(v):
		if v == state:
			return
		state = v
		if is_inside_tree():
			_sync_chips()
var list_title := ""
## The focus chip (0-4), -1 = none.
var focus := -1
## The footer's key chips: the walk ("[Right]", "[Left]") and the lock ("[S]").
var key_got := "[Right]"
var key_missed := "[Left]"
var key_lock := "[S]"
var show_keys := true
## Hoot marks this sentence (his turn): the footer says so and the chips do not take clicks.
var by_hoot := false
var done_text := ""
var done_sub := ""

var _text := ""
var _key_words: Array = []
var _marks: Array = []
var _n := 0
var _count := 6
var _course := ""
var _snr := 0
var _practice := false
## What the card will show when the locked hold ends.
var _pending: Dictionary = {}
var _hold := 0.0
var _tokens: Array = []      ## [{chip: int (-1 = little words), text, rect: Rect2, size: int}]
var _chip_font := CHIP_FONT
var _chips: Array[KeyChip] = []
var _t := 0.0
var _glow := 0.0
var _flip := 0.0
var _tray := -1.0
var _tray_words: Array = []  ## [{key, text, from: Vector2}]
var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _wiggle: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var _laid_size := Vector2.ZERO


## One chip's hit area and Hoot anchor (party_key_<n>). The card draws the chip itself.
class KeyChip:
	extends Control
	var key := 1
	var hover := false

	func _init(n: int) -> void:
		key = n
		name = "party_key_%d" % n
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _ready() -> void:
		mouse_entered.connect(_set_hover.bind(true))
		mouse_exited.connect(_set_hover.bind(false))

	func _set_hover(on: bool) -> void:
		hover = on
		var p := get_parent() as CanvasItem
		if p != null:
			p.queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb == null or not mb.pressed:
			return
		var card := get_parent() as SpSentenceCard
		if card == null:
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			card.chip_pressed.emit(key)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			card.chip_right_pressed.emit(key)
			accept_event()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in 5:
		var c := KeyChip.new(i + 1)
		c.visible = false
		add_child(c)
		_chips.append(c)
	resized.connect(_relayout)


## The chip Control for key 1-5 (null = none).
func chip(key: int) -> Control:
	return _chips[key - 1] if key >= 1 and key <= _chips.size() else null


## The chips' anchors: party_key_1 .. party_key_5.
func chip_anchors() -> Dictionary:
	var out := {}
	for c: KeyChip in _chips:
		out[String(c.name)] = c
	return out


## The sentence on the card. n = its number (0 = the practice), count = sentences in the list.
## While the locked hold runs a new sentence waits (it shows when the hold ends) unless `now`.
func show_sentence(text: String, key_words: Array, marks: Array, n: int, count: int, course: String, snr: int, practice: bool, now: bool = false) -> void:
	var d := {"text": text, "key_words": key_words.duplicate(), "marks": marks.duplicate(), "n": n, "count": count,
		"course": course, "snr": snr, "practice": practice}
	if now:
		_hold = 0.0
		_pending = {}
	elif _hold > 0.0 and (text != _text or n != _n):
		_pending = d
		return
	_apply(d)


## The talker starts (cancels the locked hold: the new sentence shows at once).
func cancel_hold() -> void:
	_hold = 0.0
	if not _pending.is_empty():
		_apply(_pending)
		_pending = {}


## LOCK IN: the billed marks (blanks are missed now). The missed words ride off on the waiter's tray.
func lock_in(marks: Array) -> void:
	_marks = marks.duplicate()
	state = &"locked"
	focus = -1
	_hold = LOCKED_HOLD_S
	_pending = {}
	_tray_words.clear()
	if not _reduced():
		for t: Dictionary in _tokens:
			var k := int(t["chip"])
			if k >= 0 and k < _marks.size() and _marks[k] != true:
				_tray_words.append({"key": k, "text": String(t["text"]), "from": (t["rect"] as Rect2).get_center()})
		_tray = 0.0 if not _tray_words.is_empty() else -1.0
	queue_redraw()


## A chip judged wrong at LOCK IN flashes (three slow flashes: never faster than 3 a second).
func flash(key: int) -> void:
	if key >= 1 and key <= 5:
		_flash[key - 1] = FLASH_S


## "Not now": the chip shakes (reduced motion: a short ring instead).
func wiggle_chip(key: int) -> void:
	if key >= 1 and key <= 5:
		_wiggle[key - 1] = 0.35


func marks() -> Array:
	return _marks.duplicate()


func shown_text() -> String:
	return _text


func shown_n() -> int:
	return _n


## The chip's centre in canvas coordinates (callouts, the plate's peas start here).
func chip_global(key: int) -> Vector2:
	var c := chip(key)
	return c.get_global_rect().get_center() if c != null and c.visible else get_global_rect().get_center()


func tray_running() -> bool:
	return _tray >= 0.0


func _apply(d: Dictionary) -> void:
	var changed := String(d["text"]) != _text or int(d["n"]) != _n
	if changed and _text != "" and state != &"done" and not _reduced():
		_flip = 1.0
	_text = String(d["text"])
	_key_words = (d["key_words"] as Array).duplicate()
	_marks = (d["marks"] as Array).duplicate()
	_n = int(d["n"])
	_count = int(d["count"])
	_course = String(d["course"])
	_snr = int(d["snr"])
	_practice = bool(d["practice"])
	if changed:
		_tray = -1.0
		_tray_words.clear()
		for i in 5:
			_flash[i] = 0.0
	_relayout()


func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _process(delta: float) -> void:
	_t += delta
	_glow = move_toward(_glow, 1.0 if state == &"talking" else 0.0, delta * 6.0)
	_flip = maxf(0.0, _flip - delta * 3.2)
	for i in 5:
		_flash[i] = maxf(0.0, _flash[i] - delta)
		_wiggle[i] = maxf(0.0, _wiggle[i] - delta)
	if _tray >= 0.0:
		_tray += delta / TRAY_S
		if _tray >= 1.0:
			_tray = -1.0
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_hold = 0.0
			if not _pending.is_empty():
				var d := _pending
				_pending = {}
				state = &"idle"
				_apply(d)
	if size != _laid_size:
		_relayout()
	queue_redraw()


# ---------------------------------------------------------------- layout

## The tokens in reading order: little-word runs and the key words (matched in order, case and
## punctuation ignored), flowed into the rows the card has room for; the chip font shrinks (to
## CHIP_FONT_MIN) before the sentence takes another row.
func _relayout() -> void:
	_laid_size = size
	var raw := _raw_tokens(_text, _key_words)
	var area := _rows_rect()
	var max_rows := maxi(1, int((area.size.y + ROW_GAP) / (CHIP_MIN.y + ROW_GAP)))
	var font := CHIP_FONT
	var placed: Array = []
	while true:
		placed = _flow(raw, font, area.size.x)
		if _rows_of(placed) <= max_rows or font <= CHIP_FONT_MIN:
			break
		font -= 2
	_chip_font = font
	# rows centred in the area, each row centred across it
	var rows_n := _rows_of(placed)
	var row_h := CHIP_MIN.y
	var total_h := rows_n * row_h + maxf(0.0, rows_n - 1) * ROW_GAP
	var y0 := area.position.y + maxf(0.0, (area.size.y - total_h) * 0.5)
	var row_w: Array[float] = []
	row_w.resize(rows_n)
	for p: Dictionary in placed:
		var r := int(p["row"])
		row_w[r] = maxf(row_w[r], float(p["x"]) + float(p["w"]))
	_tokens.clear()
	for p: Dictionary in placed:
		var r := int(p["row"])
		var x := area.position.x + (area.size.x - row_w[r]) * 0.5 + float(p["x"])
		var y := y0 + r * (row_h + ROW_GAP)
		_tokens.append({"chip": int(p["chip"]), "text": String(p["text"]), "rect": Rect2(Vector2(x, y), Vector2(float(p["w"]), row_h))})
	_sync_chips()


## The rows a sentence needs on a card `width` px wide, at the smallest chip font: the mode sizes the
## card for its list's longest sentence.
static func rows_needed(text: String, key_words: Array, width: float) -> int:
	return _rows_of(_flow(_raw_tokens(text, key_words), CHIP_FONT_MIN, maxf(10.0, width - 28.0)))


## A card's height for `rows` rows of chips.
static func height_for(rows: int) -> float:
	return HEAD_H + FOOT_H + 18.0 + rows * CHIP_MIN.y + maxf(0.0, rows - 1) * ROW_GAP


static func _rows_of(placed: Array) -> int:
	var rows := 0
	for p: Dictionary in placed:
		rows = maxi(rows, int(p["row"]) + 1)
	return rows


## [chip index (-1 = little words), text] in reading order.
static func _raw_tokens(text: String, key_words: Array) -> Array:
	var raw: Array = []
	var next := 0
	var run := ""
	for w: String in text.split(" ", false):
		if next < key_words.size() and _bare(w) == _bare(String(key_words[next])):
			# punctuation before or after the key word stays little text
			var lead := ""
			var tail := ""
			var core := w
			while core.length() > 0 and not _is_letter(core.unicode_at(0)):
				lead += core.substr(0, 1)
				core = core.substr(1)
			while core.length() > 0 and not _is_letter(core.unicode_at(core.length() - 1)):
				tail = core.substr(core.length() - 1) + tail
				core = core.substr(0, core.length() - 1)
			run += lead
			if run.strip_edges() != "":
				raw.append([-1, run.strip_edges()])
			raw.append([next, core])
			next += 1
			run = tail
		else:
			run += (" " if run != "" else "") + w
	if run.strip_edges() != "":
		raw.append([-1, run.strip_edges()])
	# key words the sentence text does not hold (a material slip) still get their chip, at the end
	while next < key_words.size():
		raw.append([next, String(key_words[next])])
		next += 1
	return raw


static func _flow(raw: Array, font: int, width: float) -> Array:
	var out: Array = []
	var x := 0.0
	var row := 0
	for it: Array in raw:
		var k := int(it[0])
		var text := String(it[1])
		var w := _chip_w(text, font) if k >= 0 else AoDraw.text_size(text, LITTLE_FONT, AoDraw.FONT_SEMI).x
		if x > 0.0 and x + w > width:
			row += 1
			x = 0.0
		out.append({"chip": k, "text": text, "x": x, "w": w, "row": row})
		x += w + TOKEN_GAP
	return out


## The chip Controls sit on their tokens (hidden with no sentence, or once the list is done).
func _sync_chips() -> void:
	for c: KeyChip in _chips:
		c.visible = false
	if state == &"done" or state == &"empty":
		queue_redraw()
		return
	for t: Dictionary in _tokens:
		var k := int(t["chip"])
		if k >= 0 and k < _chips.size():
			var c := _chips[k]
			c.position = (t["rect"] as Rect2).position
			c.size = (t["rect"] as Rect2).size
			c.visible = true
	queue_redraw()


static func _chip_w(text: String, font: int) -> float:
	return maxf(CHIP_MIN.x, AoDraw.text_size(text, font, AoDraw.FONT_BOLD).x + 58.0)


func _rows_rect() -> Rect2:
	return Rect2(Vector2(14.0, HEAD_H + 6.0), Vector2(maxf(10.0, size.x - 28.0), maxf(10.0, size.y - HEAD_H - FOOT_H - 10.0)))


static func _bare(w: String) -> String:
	var out := ""
	for i in w.length():
		var c := w.unicode_at(i)
		if _is_letter(c) or c == 39:   # keep apostrophes ("don't")
			out += w.substr(i, 1)
	return out.to_lower()


static func _is_letter(c: int) -> bool:
	return (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c > 127


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var sy := absf(cos(_flip * PI)) if _flip > 0.0 else 1.0
	draw_set_transform(Vector2(0, r.size.y * 0.5 * (1.0 - sy)), 0.0, Vector2(1.0, maxf(0.04, sy)))
	if _glow > 0.0:
		for i in 3:
			AoDraw.rbox(self, r.grow(4.0 + i * 5.0), Color(Palette.TONE_CYAN, 0.2 * _glow / (i + 1)), 18 + i * 5)
	if state == &"marking" and not by_hoot:
		var p := 0.5 + 0.5 * sin(_t * 4.0)
		AoDraw.ring(self, r.grow(3.0 + 2.0 * p), Color(Palette.SELECT_ORANGE, 0.35 + 0.3 * p), 18, 3)
	AoDraw.card(self, r, Palette.PAPER, 14)
	# the header: whose card, the list, the course and its gap
	AoDraw.rbox(self, Rect2(Vector2(4, 4), Vector2(r.size.x - 8, HEAD_H - 4)), Color("#e9e2ff"), 10)
	AoDraw.text_l(self, Vector2(16, HEAD_H * 0.5 + 2.0), "CLINICIAN'S CARD", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var right := list_title
	if _practice:
		right = "Practice sentence"
	elif _n > 0 and _course != "":
		right = "%s  .  %s, SNR %d" % [list_title, _course, _snr] if list_title != "" else "%s, SNR %d" % [_course, _snr]
	if right != "":
		AoDraw.text_r(self, Vector2(r.size.x - 16, HEAD_H * 0.5 + 2.0), right, 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	if state == &"done":
		var c := Vector2(r.size.x * 0.5, HEAD_H + (r.size.y - HEAD_H) * 0.45)
		AoDraw.text_c(self, c + Vector2(0, -10), done_text if done_text != "" else "LIST DONE", 30, Palette.INK, AoDraw.FONT_BOLD)
		if done_sub != "":
			AoDraw.text_c(self, c + Vector2(0, 24), done_sub, 14, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		draw_set_transform(Vector2.ZERO)
		return
	if state == &"empty" or _text == "":
		AoDraw.text_c(self, r.get_center(), "no party list yet" if state == &"empty" else "out of sentences!", 18, Palette.INK_SOFT)
		draw_set_transform(Vector2.ZERO)
		return
	for t: Dictionary in _tokens:
		var k := int(t["chip"])
		if k < 0:
			var tr: Rect2 = t["rect"]
			AoDraw.text_l(self, Vector2(tr.position.x, tr.get_center().y + 2.0), String(t["text"]), LITTLE_FONT, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		else:
			_draw_chip(k, t["rect"], String(t["text"]))
	_draw_footer(r)
	if _tray >= 0.0:
		_draw_tray(r)
	draw_set_transform(Vector2.ZERO)


func _draw_chip(k: int, rect: Rect2, word: String) -> void:
	var awake := state == &"marking"
	var locked := state == &"locked"
	var m: Variant = _marks[k] if k < _marks.size() else null
	var got: bool = m is bool and m == true
	var missed: bool = m is bool and m == false
	var hover := awake and not by_hoot and k < _chips.size() and _chips[k].hover
	var r := rect
	if _wiggle[k] > 0.0 and not _reduced():
		r.position.x += sin(_wiggle[k] * 60.0) * 5.0 * (_wiggle[k] / 0.35)
	# on the tray: the word has left its chip
	var riding := locked and _tray >= 0.0 and _on_tray(k)
	var fill := Palette.CREAM
	var border := Color(Palette.INK, 0.45)
	var bw := 3
	var word_col := Palette.INK_SOFT
	var font := AoDraw.FONT_SEMI
	if awake or locked:
		fill = Palette.PAPER
		border = Palette.INK
		word_col = Palette.INK
	if got:
		fill = Palette.MINT.lightened(0.35)
		border = Palette.INK
		word_col = Palette.INK
		font = AoDraw.FONT_BOLD
	elif missed:
		fill = Palette.PAPER if not locked else Color("#ece8f2")
		border = Palette.CORAL
		bw = 4
		word_col = Palette.INK if not locked else Palette.INK_SOFT
	if hover and not got:
		fill = fill.lerp(Palette.SUNNY, 0.18)
	# the focus ring (sunny) and a misscored flash (coral, three slow pulses)
	if awake and k == focus:
		var p := 0.5 + 0.5 * sin(_t * 5.0)
		AoDraw.rbox(self, r.grow(7.0 + 2.0 * p), Color(Palette.SUNNY, 0.35 + 0.25 * p), 18)
		AoDraw.ring(self, r.grow(4.0), Palette.SELECT_ORANGE, 15, 4)
	if _flash[k] > 0.0:
		var on := fmod(FLASH_S - _flash[k], 0.4) < 0.24
		if on:
			AoDraw.rbox(self, r.grow(8.0), Color(Palette.CORAL, 0.55), 18)
	AoDraw.rbox(self, Rect2(r.position + Vector2(0, 4), r.size), Color(Palette.INK, 0.22), 13)
	AoDraw.rbox(self, r, fill, 13, bw, border)
	# the number badge (also its key: 1-5)
	var bc := r.position + Vector2(15.0, 15.0)
	draw_circle(bc, 11.0, Palette.INK if (awake or locked) else Color(Palette.INK, 0.45))
	AoDraw.text_c(self, bc + Vector2(0, 1), "%d" % (k + 1), 13, Palette.PAPER, AoDraw.FONT_BOLD)
	if riding:
		AoDraw.dashed(self, r.position + Vector2(30, r.size.y * 0.5), r.end - Vector2(14, r.size.y * 0.5), Color(Palette.INK, 0.25), 2.0, 5.0, 5.0)
	else:
		var wc := r.get_center() + Vector2(7.0, 2.0)
		AoDraw.text_c(self, wc, word, _chip_font, word_col, font)
		if missed:
			var tw := AoDraw.text_size(word, _chip_font, font).x
			draw_line(wc + Vector2(-tw * 0.5 - 2.0, 1.0), wc + Vector2(tw * 0.5 + 2.0, 1.0), Color(Palette.CORAL, 0.9), 3.0, true)
	# the verdict icon in the top-right corner
	var ic := Vector2(r.end.x - 14.0, r.position.y + 14.0)
	if got:
		draw_circle(ic, 10.0, Palette.INK)
		UiDraw.check(self, ic + Vector2(0, 1), 11.0, Palette.MINT.lightened(0.3), 3.0)
	elif missed:
		draw_circle(ic, 10.0, Palette.CORAL)
		UiDraw.cross(self, ic, 6.5, Palette.PAPER, 3.0)


func _draw_footer(r: Rect2) -> void:
	var y := r.size.y - FOOT_H * 0.5 - 4.0
	var x0 := 16.0
	var dots := "..." if bool(Game.settings.get("reduced_motion", false)) else ".".repeat(1 + int(_t * 3.0) % 3)
	var got := 0
	var blanks := 0
	for m: Variant in _marks:
		if m == true:
			got += 1
		elif m == null:
			blanks += 1
	match state:
		&"idle":
			var t := "PRACTICE SENTENCE: not scored" if _practice else "NEXT SENTENCE  %d of %d" % [_n, _count]
			if not _practice and _course != "":
				t += "  .  %s" % _course
			AoDraw.text_c(self, Vector2(r.size.x * 0.5, y), t, 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
		&"talking":
			AoDraw.text_c(self, Vector2(r.size.x * 0.5, y), "NOW SAYING" + dots, 15, Palette.TONE_CYAN.darkened(0.35), AoDraw.FONT_BOLD)
		&"listening":
			AoDraw.text_c(self, Vector2(r.size.x * 0.5, y), "LISTENING FOR THE ANSWER" + dots, 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
		&"marking":
			var lw := AoDraw.text_l(self, Vector2(x0, y), "%d / %d" % [got, _marks.size()], 18, Palette.INK, AoDraw.FONT_BOLD)
			AoDraw.text_l(self, Vector2(x0 + lw + 6.0, y + 1.0), "so far", 13, Palette.INK_SOFT, AoDraw.FONT_SEMI)
			var hint := ""
			if by_hoot:
				hint = "Hoot is ticking" + dots
			elif focus >= 0:
				hint = "chip %d:  %s got it  .  %s missed" % [focus + 1, key_got, key_missed] if show_keys else "chip %d: got it or missed?" % (focus + 1)
			elif blanks == 0:
				hint = "all ticked: %s locks it in" % key_lock if show_keys else "all ticked: LOCK IN"
			else:
				hint = "blanks count as missed"
			AoDraw.text_r(self, Vector2(r.size.x - 16.0, y), hint, 14, Palette.SELECT_ORANGE.darkened(0.3), AoDraw.FONT_BOLD)
		&"locked":
			if _tray < 0.0:
				var t := "PRACTICE DONE: no plate for this one" if _practice else "LOCKED IN: %d / %d billed" % [got, _marks.size()]
				AoDraw.text_c(self, Vector2(r.size.x * 0.5, y), t, 14, Palette.INK, AoDraw.FONT_BOLD)


func _on_tray(k: int) -> bool:
	for w: Dictionary in _tray_words:
		if int(w["key"]) == k:
			return _tray_x(size) >= float((w["from"] as Vector2).x)
	return false


func _tray_x(sz: Vector2) -> float:
	return lerpf(-110.0, sz.x + 110.0, clampf(_tray, 0.0, 1.0))


## The waiter crosses the card's foot; each missed word hops onto his tray as he passes its chip.
func _draw_tray(r: Rect2) -> void:
	var x := _tray_x(r.size)
	var y := r.size.y - 10.0
	# the waiter: a bean with a bow tie, one arm up holding the tray
	var head := Vector2(x - 34.0, y - 34.0)
	AoDraw.rbox(self, Rect2(head + Vector2(-13, 10), Vector2(26, 26)), Palette.INK, 9)
	draw_circle(head, 13.0, Palette.SKIN)
	draw_arc(head, 13.0, 0.0, TAU, 20, Palette.INK, 2.0, true)
	draw_circle(head + Vector2(-4, -2), 1.8, Palette.INK)
	draw_circle(head + Vector2(4, -2), 1.8, Palette.INK)
	var bow := head + Vector2(0, 16)
	draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(-7, -4), bow + Vector2(-7, 4)]), Palette.CORAL)
	draw_colored_polygon(PackedVector2Array([bow, bow + Vector2(7, -4), bow + Vector2(7, 4)]), Palette.CORAL)
	draw_line(head + Vector2(10, 18), Vector2(x - 6.0, y - 20.0), Palette.INK, 4.0, true)
	# the tray and its load
	var tray := Rect2(Vector2(x - 20.0, y - 24.0), Vector2(118.0, 8.0))
	AoDraw.rbox(self, tray, Color("#c9c4d6"), 4, 2, Palette.INK)
	var stack := 0
	# the pile stays under the card's header: the dishes overlap when there are many
	var step := minf(18.0, (tray.position.y - 12.0 - (HEAD_H + 12.0)) / maxf(1.0, _tray_words.size() - 1.0))
	for w: Dictionary in _tray_words:
		var from: Vector2 = w["from"]
		if x < from.x:
			continue
		var at := Vector2(tray.get_center().x, tray.position.y - 12.0 - stack * step)
		var k := clampf((x - from.x) / 60.0, 0.0, 1.0)
		var p := from.lerp(at, k)
		var txt := String(w["text"])
		var tw := AoDraw.text_size(txt, 13, AoDraw.FONT_BOLD).x + 14.0
		AoDraw.rbox(self, Rect2(p - Vector2(tw * 0.5, 9.0), Vector2(tw, 18.0)), Palette.PAPER, 8, 2, Palette.CORAL)
		AoDraw.text_c(self, p, txt, 13, Palette.INK_SOFT, AoDraw.FONT_BOLD)
		stack += 1
	if stack > 0:
		# the label trails behind him once the card's right edge is near
		var say := "back to the kitchen!"
		var lw := AoDraw.text_size(say, 12, AoDraw.FONT_BOLD).x
		var lx := tray.end.x + 6.0 if tray.end.x + 6.0 + lw <= r.size.x - 8.0 else head.x - 20.0 - lw
		AoDraw.text_l(self, Vector2(lx, y - 20.0), say, 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
