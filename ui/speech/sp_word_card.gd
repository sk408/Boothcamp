class_name SpWordCard
extends Control
## SpWordCard: the clinician's word card (ui/speech only). A ruled index card showing the word the
## next PRESENT will say (the patient never sees it), split into its two parts ("CUP . CAKE").
## States: &"idle" (NEXT WORD), &"talking" (NOW SAYING, glowing), &"listening" (waiting for his
## answer), &"score" (SCORE IT: compare the card with what he said), &"done" (the SRT is stored),
## &"empty" (no word list yet). A new word arrives with a quick card flip.

var list_title: String = ""
var ear: String = "right"
var state: StringName = &"empty"
var number: int = 0
var words_left: int = 0
## Shown after the ear is done ("SRT 30 dB").
var done_text: String = ""
var _word := ""
var _parts: Array = []
var _shown_word := ""
var _shown_parts: Array = []
var _shown_number := 0
var _flip := 0.0
var _t := 0.0
var _glow := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The target word. A change flips the card (the new word appears at the flip's midpoint).
func set_word(word: String, parts: Array, n: int, left: int) -> void:
	words_left = left
	if word == _word and n == number:
		return
	var had := _shown_word != ""
	_word = word
	_parts = parts.duplicate()
	number = n
	if had and word != _shown_word:
		_flip = 1.0
	else:
		_shown_word = word
		_shown_parts = _parts.duplicate()
		_shown_number = n
	queue_redraw()


func shown_word() -> String:
	return _shown_word


func _process(delta: float) -> void:
	_t += delta
	_glow = move_toward(_glow, 1.0 if state == &"talking" else 0.0, delta * 6.0)
	if _flip > 0.0:
		var was := _flip
		_flip = maxf(0.0, _flip - delta * 3.2)
		if was > 0.5 and _flip <= 0.5:
			_shown_word = _word
			_shown_parts = _parts.duplicate()
			_shown_number = number
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# flip: squash vertically around the centre
	var sy := absf(cos(_flip * PI)) if _flip > 0.0 else 1.0
	draw_set_transform(Vector2(0, r.size.y * 0.5 * (1.0 - sy)), 0.0, Vector2(1.0, maxf(0.04, sy)))
	var border := Palette.INK
	if _glow > 0.0:
		for i in 3:
			AoDraw.rbox(self, r.grow(4.0 + i * 5.0), Color(Palette.TONE_CYAN, 0.2 * _glow / (i + 1)), 18 + i * 5)
	if state == &"score":
		var p := 0.5 + 0.5 * sin(_t * 6.0)
		AoDraw.ring(self, r.grow(4.0 + 2.0 * p), Color(Palette.SELECT_ORANGE, 0.45 + 0.4 * p), 18, 4)
	AoDraw.card(self, r, Palette.PAPER, 14)
	# ruled lines and the red margin
	var head_h := 30.0
	var y := head_h + 26.0
	while y < r.size.y - 8.0:
		draw_line(Vector2(8, y), Vector2(r.size.x - 8, y), Color(Palette.SKY.darkened(0.08), 0.7), 1.5)
		y += 24.0
	draw_line(Vector2(30, 6), Vector2(30, r.size.y - 6), Color(Palette.CORAL, 0.45), 2.0)
	# header
	AoDraw.rbox(self, Rect2(Vector2(4, 4), Vector2(r.size.x - 8, head_h - 4)), Color(Palette.ear_tint(ear), 1.0), 10)
	AoDraw.text_l(self, Vector2(40, head_h * 0.5 + 2.0), "CLINICIAN'S CARD", 12, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	if list_title != "":
		AoDraw.text_r(self, Vector2(r.size.x - 14, head_h * 0.5 + 2.0), list_title, 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	var c := Vector2(r.size.x * 0.5 + 12.0, head_h + (r.size.y - head_h) * 0.44)
	if state == &"empty" or _shown_word == "":
		AoDraw.text_c(self, c, "no word list yet" if state == &"empty" else "out of words!", 18, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	elif state == &"done":
		AoDraw.text_c(self, c + Vector2(0, -8), done_text if done_text != "" else "SRT STORED", 30, Palette.ear_color(ear), AoDraw.FONT_BOLD)
		AoDraw.text_c(self, c + Vector2(0, 26), "ear done: nice work!", 14, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	else:
		_draw_word(c, r.size.x - 60.0)
	# status line
	var sl := Vector2(r.size.x * 0.5 + 12.0, r.size.y - 22.0)
	var dots := ".".repeat(1 + int(_t * 3.0) % 3)
	match state:
		&"idle":
			var t := "NEXT WORD  #%d" % _shown_number
			if words_left > 1:
				t += "   (%d left)" % (words_left - 1)
			AoDraw.text_c(self, sl, t, 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
		&"talking":
			AoDraw.text_c(self, sl, "NOW SAYING" + dots, 15, Palette.TONE_CYAN.darkened(0.35), AoDraw.FONT_BOLD)
		&"listening":
			AoDraw.text_c(self, sl, "LISTENING FOR THE ANSWER" + dots, 14, Palette.INK_SOFT, AoDraw.FONT_BOLD)
		&"score":
			AoDraw.text_c(self, sl, "SCORE IT: same word as the card?", 14, Palette.SELECT_ORANGE.darkened(0.25), AoDraw.FONT_BOLD)
	draw_set_transform(Vector2.ZERO)


## The word in big letters, its two parts split by a dot (shrinks to fit).
func _draw_word(c: Vector2, max_w: float) -> void:
	var parts: Array = _shown_parts if _shown_parts.size() >= 2 else [_shown_word]
	var fs := 40
	var gap := 22.0
	var total := 0.0
	while fs > 18:
		total = 0.0
		for p: Variant in parts:
			total += AoDraw.text_size(String(p).to_upper(), fs, AoDraw.FONT_BOLD).x
		total += gap * (parts.size() - 1)
		if total <= max_w:
			break
		fs -= 2
		gap = fs * 0.55
	var x := c.x - total * 0.5
	for i in parts.size():
		var txt := String(parts[i]).to_upper()
		var w := AoDraw.text_l(self, Vector2(x, c.y), txt, fs, Palette.INK, AoDraw.FONT_BOLD)
		x += w
		if i < parts.size() - 1:
			draw_circle(Vector2(x + gap * 0.5, c.y + 1.0), maxf(3.0, fs * 0.09), Palette.CORAL)
			x += gap
