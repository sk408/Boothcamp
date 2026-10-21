class_name SpLcd
extends Control
## SpLcd: the AudiOtron 3000's display in SPEECH mode (ui/speech only). Same bezel, screen and
## nameplate as the tone display (AoLcd), with a SPEECH tag.
##  Left: ear chip (RIGHT red / LEFT blue), mode chips (PHONE, SPEECH) and the test chip (SRT), the
##        list title and word count, the level in big digits (click the chevrons or scroll over the
##        level to step it) and the TALK lamp, lit while a word plays. The digits turn amber once
##        the level is well below the PTA ("he is still repeating words down here").
##  Right: the PTA (from the tone test), the "start = PTA + 15" chip, this level's tally
##        ("30 dB: 2 of 2") and the NOISE box (speech noise in the other ear, its level and ear).
## (Days 4-5) A test mode's optional view keys (CONTRACTS.md §9.10.7); a view without them draws
## exactly as before: test_chip (String, replaces "SRT"), ear_chip (String, replaces the ear's name;
## "BOTH" draws in ink, with no ear symbol), chips (Array of String, replaces PHONE / SPEECH),
## info_line (String, replaces the list-and-words line), big_caption (String, replaces "dB HL" by the
## big digits), aux (Array of {label, value}: a row in the THIS LEVEL line's place), start_chip
## (String, the START chip's text), noise_note (Array of String: a dim note in the NOISE box's place,
## for a test with no masking).

signal level_step(direction: int)

const OPTIONAL_KEYS: Array[String] = ["test_chip", "ear_chip", "chips", "info_line", "big_caption", "aux", "start_chip", "noise_note"]

var view: Dictionary = {
	"ear": "right", "db": 40, "talking": false, "test": "srt", "list_title": "", "word_n": 0, "words_left": 0,
	"transducer": "phones", "pta": NAN, "pta_method": "three", "start_db": 40, "started": false,
	"tally": [], "mask_on": false, "mask_db": -1, "mask_ear": "left", "masking_needed": false, "accepting": false,
}
var talk_glow: float = 0.0
## (Days 4-5) No THIS LEVEL line (a mode's hidden_base_widgets() names &"tally").
var hide_tally := false:
	set(v):
		hide_tally = v
		queue_redraw()
var _t := 0.0
var _hot: Dictionary = {}
var _hover := ""
var _bump := 0.0
var _deny := 0.0
var _wheel_acc := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func update_view(d: Dictionary) -> void:
	if int(d.get("db", 0)) != int(view.get("db", 0)):
		_bump = 1.0
	view.merge(d, true)
	queue_redraw()


## (Days 4-5) Drop every optional key: the Day 3 display again.
func clear_optional() -> void:
	for k: String in OPTIONAL_KEYS:
		view.erase(k)
	queue_redraw()


## Shake the level digits: "not now" (the level is locked while a word plays).
func deny() -> void:
	_deny = 1.0


func _process(delta: float) -> void:
	_t += delta
	_bump = maxf(0.0, _bump - delta * 4.0)
	_deny = maxf(0.0, _deny - delta * 3.0)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _hit((event as InputEventMouseMotion).position)
		if h != _hover:
			_hover = h
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != "" else Control.CURSOR_ARROW
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			match _hit(mb.position):
				"db_up":
					level_step.emit(1)
				"db_down":
					level_step.emit(-1)
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _hit(mb.position) in ["db_up", "db_down", "db"]:
				_wheel_acc += (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0) * (mb.factor if mb.factor > 0.0 else 1.0)
				while absf(_wheel_acc) >= 1.0:
					var d := int(signf(_wheel_acc))
					_wheel_acc -= signf(_wheel_acc)
					level_step.emit(d)
				accept_event()


func _hit(p: Vector2) -> String:
	for k: String in _hot:
		if (_hot[k] as Rect2).has_point(p):
			return k
	return ""


func _draw() -> void:
	_hot.clear()
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Color("#3b3154"), 24)
	var screen := r.grow(-12.0)
	screen.position.y += 6.0
	screen.size.y -= 4.0
	AoDraw.rbox(self, screen, Palette.LCD_BG, 14)
	AoDraw.rbox(self, Rect2(screen.position + Vector2(8, 6), Vector2(screen.size.x - 16, 16)), Color(1, 1, 1, 0.035), 8)
	# nameplate on the bezel, plus the SPEECH mode tag
	var plate := Rect2(Vector2(26, -12), Vector2(176, 26))
	AoDraw.rbox(self, Rect2(plate.position + Vector2(0, 3), plate.size), Color(Palette.INK, 0.4), 13)
	AoDraw.rbox(self, plate, Palette.CORAL, 13, 3, Palette.INK)
	var lw := AoDraw.text_l(self, Vector2(plate.position.x + 14, plate.get_center().y), "AudiOtron", 17, Palette.PAPER, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(plate.position.x + 18 + lw, plate.get_center().y), "3000", 17, Palette.SUNNY, AoDraw.FONT_BOLD)
	var tag := Rect2(Vector2(plate.end.x + 8, -10), Vector2(86, 22))
	AoDraw.rbox(self, Rect2(tag.position + Vector2(0, 3), tag.size), Color(Palette.INK, 0.4), 11)
	AoDraw.rbox(self, tag, Palette.SUNNY, 11, 3, Palette.INK)
	AoDraw.text_c(self, tag.get_center(), "SPEECH", 13, Palette.INK, AoDraw.FONT_BOLD)
	var split := screen.position.x + minf(330.0, screen.size.x * 0.52)
	_draw_readout(Rect2(screen.position, Vector2(split - screen.position.x, screen.size.y)))
	draw_line(Vector2(split, screen.position.y + 12), Vector2(split, screen.end.y - 12), Color(Palette.LCD_DIM, 0.6), 2.0)
	_draw_info(Rect2(Vector2(split + 12, screen.position.y), Vector2(screen.end.x - split - 16, screen.size.y)))


func _draw_readout(a: Rect2) -> void:
	var e := String(view["ear"])
	var ec := Palette.ear_color(e)
	var chip := Rect2(a.position + Vector2(12, 12), Vector2(98, 28))
	if view.has("ear_chip"):
		# (Days 4-5) a mode's ear chip: "BOTH" (or no single ear) in ink, with no ear symbol
		var et := String(view["ear_chip"])
		var one := e in ["right", "left"] and et != "BOTH"
		AoDraw.rbox(self, chip, ec if one else Palette.BOTH_INK, 14)
		if one:
			draw_circle(chip.position + Vector2(15, 14), 9.0, Palette.PAPER)
			UiDraw.ear_symbol(self, chip.position + Vector2(15, 14), e, 10.0, 2.5)
			AoDraw.text_l(self, chip.position + Vector2(30, 14), et, 16, Palette.PAPER, AoDraw.FONT_BOLD)
		else:
			AoDraw.text_c(self, chip.get_center(), et, 16, Palette.PAPER, AoDraw.FONT_BOLD)
	else:
		AoDraw.rbox(self, chip, ec, 14)
		draw_circle(chip.position + Vector2(15, 14), 9.0, Palette.PAPER)
		UiDraw.ear_symbol(self, chip.position + Vector2(15, 14), e, 10.0, 2.5)
		AoDraw.text_l(self, chip.position + Vector2(30, 14), e.to_upper(), 16, Palette.PAPER, AoDraw.FONT_BOLD)
	var x := chip.end.x + 8.0
	var tr := String(view.get("transducer", "phones"))
	var labels: Array = (view["chips"] as Array) if view.has("chips") else ["INSERT" if tr == "inserts" else "PHONE", "SPEECH"]
	for lv: Variant in labels:
		var label := String(lv)
		var w := AoDraw.text_size(label, 12, AoDraw.FONT_BOLD).x + 14.0
		var cr := Rect2(Vector2(x, chip.position.y + 3), Vector2(w, 22))
		AoDraw.ring(self, cr, Palette.SELECT_ORANGE, 11, 2)
		AoDraw.text_c(self, cr.get_center(), label, 12, Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
		x += w + 6.0
	var test_txt := String(view["test_chip"]) if view.has("test_chip") else String(view.get("test", "srt")).to_upper()
	var tw := AoDraw.text_size(test_txt, 13, AoDraw.FONT_BOLD).x + 18.0
	var trr := Rect2(Vector2(x, chip.position.y + 3), Vector2(tw, 22))
	if trr.end.x <= a.end.x - 2.0:
		AoDraw.rbox(self, trr, Palette.SELECT_ORANGE, 11)
		AoDraw.text_c(self, trr.get_center(), test_txt, 13, Palette.LCD_BG, AoDraw.FONT_BOLD)
	# list and word
	var title := String(view.get("list_title", ""))
	var n := int(view.get("word_n", 0))
	var left := int(view.get("words_left", 0))
	var sub := title
	if n > 0:
		sub += "   %d word%s" % [n, "" if n == 1 else "s"]
	if left > 0:
		sub += ", %d left" % left
	if view.has("info_line"):
		sub = String(view["info_line"])
	AoDraw.text_l(self, a.position + Vector2(14, 58), sub, 14, Color(Palette.LCD_TEXT, 0.72), AoDraw.FONT_SEMI)
	# level row
	var ly := a.position.y + a.size.y - 40.0
	var ltxt := "%d" % int(view["db"])
	var ls := 60
	var shake := sin(_t * 70.0) * 7.0 * _deny
	var lx := a.position.x + 44.0 + shake
	var pta := float(view.get("pta", NAN))
	var lcol := Palette.LCD_TEXT
	if not is_nan(pta) and float(int(view["db"])) < pta - float(SpeechRules.AGREE_GOOD_DB):
		lcol = Palette.SUNNY   # well below the beeps: amber
	if bool(view.get("talking", false)):
		lcol = Palette.TONE_CYAN.lerp(Palette.LCD_TEXT, 0.3)
	var lwid := AoDraw.text_size(ltxt, ls, AoDraw.FONT_BOLD).x
	AoDraw.text_l(self, Vector2(lx, ly - _bump * 5.0), ltxt, ls, lcol, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(lx + lwid + 8.0, ly + 10.0), String(view.get("big_caption", "dB HL")), 19, Color(Palette.LCD_TEXT, 0.7), AoDraw.FONT_SEMI)
	_chevron(Rect2(Vector2(a.position.x + 10, ly - 30), Vector2(28, 26)), Vector2.UP, "db_up")
	_chevron(Rect2(Vector2(a.position.x + 10, ly + 4), Vector2(28, 26)), Vector2.DOWN, "db_down")
	_hot["db"] = Rect2(Vector2(lx, ly - 30), Vector2(lwid + 70.0, 60))
	# TALK lamp
	var lc := Vector2(a.end.x - 38.0, ly - 2.0)
	var lr := 22.0
	var g := talk_glow
	if g > 0.0:
		for i in 3:
			var rr := lr + 4.0 + 9.0 * i + 6.0 * fmod(_t * 2.5 + i * 0.33, 1.0)
			draw_arc(lc, rr, -0.9, 0.9, 18, Color(Palette.TONE_CYAN, 0.5 * g * (1.0 - i * 0.28)), 3.0, true)
			draw_arc(lc, rr, PI - 0.9, PI + 0.9, 18, Color(Palette.TONE_CYAN, 0.5 * g * (1.0 - i * 0.28)), 3.0, true)
		draw_circle(lc, lr + 8.0, Color(Palette.TONE_CYAN, 0.18 * g))
	draw_circle(lc, lr, Palette.INK)
	draw_circle(lc, lr - 4.0, Palette.LCD_DIM.lerp(Palette.TONE_CYAN, g))
	draw_circle(lc + Vector2(-6, -6), 5.0, Color(1, 1, 1, 0.25 + 0.4 * g))
	AoDraw.text_c(self, lc + Vector2(0, -lr - 12.0), "TALK", 12, Palette.LCD_TEXT.lerp(Palette.TONE_CYAN, g), AoDraw.FONT_BOLD)


func _draw_info(a: Rect2) -> void:
	var pta := float(view.get("pta", NAN))
	# PTA block
	var x0 := a.position.x + 4.0
	var y0 := a.position.y
	AoDraw.text_l(self, Vector2(x0, y0 + 16), "PTA", 12, Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
	var method := "best two" if String(view.get("pta_method", "three")) == "best two" else "500-1k-2k"
	AoDraw.text_l(self, Vector2(x0 + 34, y0 + 16), method, 11, Color(Palette.LCD_TEXT, 0.5), AoDraw.FONT_SEMI)
	var ptxt := "--" if is_nan(pta) else "%d" % int(round(pta))
	var pw := AoDraw.text_l(self, Vector2(x0, y0 + 46), ptxt, 36, Palette.LCD_TEXT, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(x0 + pw + 6.0, y0 + 52), "dB HL", 14, Color(Palette.LCD_TEXT, 0.6), AoDraw.FONT_SEMI)
	AoDraw.text_l(self, Vector2(x0, y0 + 74), "from the beeps", 11, Color(Palette.LCD_TEXT, 0.45), AoDraw.FONT_SEMI)
	# NOISE box (speech noise in the other ear)
	var bw := minf(126.0, a.size.x * 0.48)
	if view.has("noise_note"):
		_draw_noise_note(Rect2(Vector2(a.end.x - bw, y0 + 8.0), Vector2(bw, 76.0)), view["noise_note"])
	else:
		_draw_noise(Rect2(Vector2(a.end.x - bw, y0 + 8.0), Vector2(bw, 76.0)))
	# start chip: PTA + 15
	var start := int(view.get("start_db", 40))
	var at_start := int(view["db"]) == start and not bool(view.get("started", false))
	# the PTA rounded to the dial's 5 dB steps, so the sum on the chip adds up (PTA 72 -> 70 + 15 = 85)
	var base := SpeechRules.snap5(pta) if not is_nan(pta) else 0
	var stxt := "START: no PTA yet"
	if not is_nan(pta):
		stxt = "START = %d + 15 = %d" % [base, start] if base + SpeechRules.SRT_START_ABOVE_PTA_DB == start else "START = %d dB" % start
	if view.has("start_chip"):
		stxt = String(view["start_chip"])
	var sw := minf(a.size.x, AoDraw.text_size(stxt, 12, AoDraw.FONT_BOLD).x + 22.0)
	var sr := Rect2(Vector2(x0 - 2.0, y0 + 92.0), Vector2(sw, 22.0))
	if at_start:
		AoDraw.rbox(self, sr, Palette.SELECT_ORANGE, 11)
		AoDraw.text_c(self, sr.get_center(), stxt, 12, Palette.LCD_BG, AoDraw.FONT_BOLD)
	else:
		AoDraw.ring(self, sr, Color(Palette.SELECT_ORANGE, 0.75), 11, 2)
		AoDraw.text_c(self, sr.get_center(), stxt, 12, Color(Palette.SELECT_ORANGE, 0.9), AoDraw.FONT_BOLD)
	# this level's tally
	var tally: Array = view.get("tally", [])
	var ty := y0 + 132.0
	if hide_tally or view.has("aux"):
		_draw_aux(Vector2(x0, ty), a.end.x)
		return
	var lw := AoDraw.text_l(self, Vector2(x0, ty), "THIS LEVEL", 11, Color(Palette.LCD_TEXT, 0.55), AoDraw.FONT_BOLD)
	var right := int(tally[0]) if tally.size() >= 2 else 0
	var total := int(tally[1]) if tally.size() >= 2 else 0
	var ttxt := "%d dB: %d of %d" % [int(view["db"]), right, total] if total > 0 else "%d dB: no words yet" % int(view["db"])
	var tcol := Palette.LCD_TEXT
	if total > 0 and right >= SpeechRules.SRT_MIN_CORRECT and float(right) >= SpeechRules.SRT_MIN_FRACTION * total:
		tcol = Palette.PRESS_LIME
	elif total > 0 and float(right) < SpeechRules.SRT_MIN_FRACTION * total:
		tcol = Palette.CORAL.lightened(0.15)
	AoDraw.text_l(self, Vector2(x0 + lw + 10.0, ty), ttxt, 17, tcol, AoDraw.FONT_BOLD)


## (Days 4-5) A mode's aux row ({label, value} pairs) where the tally was.
func _draw_aux(at: Vector2, right: float) -> void:
	var x := at.x
	for it: Variant in view.get("aux", []):
		var d: Dictionary = it if it is Dictionary else {}
		var lw := AoDraw.text_size(String(d.get("label", "")), 11, AoDraw.FONT_BOLD).x
		var vw := AoDraw.text_size(String(d.get("value", "")), 17, AoDraw.FONT_BOLD).x
		if x + lw + 8.0 + vw > right:
			break
		AoDraw.text_l(self, Vector2(x, at.y), String(d.get("label", "")), 11, Color(Palette.LCD_TEXT, 0.55), AoDraw.FONT_BOLD)
		AoDraw.text_l(self, Vector2(x + lw + 8.0, at.y), String(d.get("value", "")), 17, Palette.LCD_TEXT, AoDraw.FONT_BOLD)
		x += lw + vw + 22.0


## (Days 4-5) A mode's note where the NOISE box was (the party test: one mix in both ears, no masking).
func _draw_noise_note(r: Rect2, note: Variant) -> void:
	var lines: Array = note if note is Array else [String(note)]
	AoDraw.rbox(self, r, Color(Palette.PLUM, 0.08), 12, 2, Palette.LCD_DIM)
	for i in mini(3, lines.size()):
		var px := 11 if i == 0 else 10
		var col := Color(Palette.LCD_TEXT, 0.6) if i == 0 else Color(Palette.LCD_TEXT, 0.45)
		AoDraw.text_l(self, Vector2(r.position.x + 8.0, r.position.y + 15.0 + i * 20.0), String(lines[i]), px, col, AoDraw.FONT_BOLD)


func _draw_noise(r: Rect2) -> void:
	var on := bool(view.get("mask_on", false))
	var need := bool(view.get("masking_needed", false)) and not on
	var me := String(view.get("mask_ear", "left"))
	var blink := 0.5 + 0.5 * sin(_t * 7.0)
	AoDraw.rbox(self, r, Color(Palette.PLUM, 0.3 if on else 0.08), 12, 2, Palette.PLUM.lightened(0.25) if on else (Color(Palette.SELECT_ORANGE, 0.5 + 0.5 * blink) if need else Palette.LCD_DIM))
	var txt_col := Palette.LCD_TEXT if on else Color(Palette.LCD_TEXT, 0.5)
	var hx := r.position.x + 8.0
	var hy := r.position.y + 13.0
	var hw := AoDraw.text_l(self, Vector2(hx, hy), "NOISE", 11, txt_col, AoDraw.FONT_BOLD)
	var ec := Palette.ear_color(me)
	var chip := Rect2(Vector2(hx + hw + 4.0, hy - 8.0), Vector2(18.0, 16.0))
	AoDraw.rbox(self, chip, ec if on else Color(ec, 0.4), 8)
	AoDraw.text_c(self, chip.get_center(), "L" if me == "left" else "R", 11, Palette.PAPER, AoDraw.FONT_BOLD)
	if chip.end.x + 50.0 <= r.end.x:
		AoDraw.text_l(self, Vector2(chip.end.x + 5.0, hy), "speech", 10, Color(Palette.PLUM.lightened(0.55), 1.0 if on else 0.5), AoDraw.FONT_BOLD)
	var lv := "[%d]" % int(view.get("mask_db", 0)) if on else "[ -- ]"
	var lcol := Palette.PLUM.lightened(0.6) if on else Color(Palette.LCD_TEXT, 0.35)
	AoDraw.text_l(self, Vector2(hx - 2.0, r.position.y + 42.0), lv, 26, lcol, AoDraw.FONT_BOLD)
	var foot := "dB EM" if on else ("MASK?" if need else "off")
	var fcol := Color(Palette.LCD_TEXT, 0.6)
	if need:
		fcol = Color(Palette.SELECT_ORANGE, 0.55 + 0.45 * blink)
	AoDraw.text_l(self, Vector2(hx + 1.0, r.position.y + 64.0), foot, 11, fcol, AoDraw.FONT_BOLD)
	if on:
		for i in 4:
			var xx := r.end.x - 34.0 + i * 6.0
			var hh := 5.0 + 6.0 * absf(sin(_t * 17.0 + i * 1.3))
			draw_line(Vector2(xx, r.position.y + 50.0 - hh * 0.5), Vector2(xx, r.position.y + 50.0 + hh * 0.5), Color(Palette.PLUM.lightened(0.4), 0.9), 2.5)


func _chevron(r: Rect2, dir: Vector2, id: String) -> void:
	_hot[id] = r
	var on := _hover == id and bool(view.get("accepting", false))
	if on:
		AoDraw.rbox(self, r, Color(Palette.SELECT_ORANGE, 0.25), 8)
	UiDraw.arrow(self, r.get_center(), 16.0, dir, Palette.SELECT_ORANGE if on else Color(Palette.SELECT_ORANGE, 0.75))
