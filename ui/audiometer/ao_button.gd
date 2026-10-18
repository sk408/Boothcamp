class_name AoButton
extends Control
## AoButton: the AudiOtron 3000's chunky toy button (ui/ only).
## A coloured face on a darker base (press depth), thick ink outline, glossy highlight, an icon
## and a label, and a keycap chip underneath showing the current key (Game.key_label).
## Mouse: left press / release (hold the TONE pad), right click (TONE = no response).
## Never takes keyboard focus (Space must never "click" a focused button).

signal pressed_down
signal released
signal clicked
signal right_clicked
## (v4) A click on a locked button (it wiggles): the screen may say why.
signal denied

enum Icon { NONE, TRI_UP, TRI_DOWN, ARROW_LEFT, ARROW_RIGHT, STAMP, NO_RESP, EAR_RIGHT, EAR_LEFT, WAVES, KEYS, SWAP }

const KEYCAP_H := 28.0

var text: String = ""
var sub_text: String = ""
var icon: Icon = Icon.NONE
var face_color: Color = Palette.SUNNY
var text_color: Color = Palette.INK
var action: StringName = &""
var depth: float = 7.0
var radius: int = 18
var font_size: int = 22
var icon_size: float = 30.0
## 0..1 cyan glow while the tone plays.
var glow: float = 0.0
## Combo flame height in px above the face (0 = none). Set by the screen.
var flame_px: float = 0.0
var flame_heat: float = 0.0
## Orange "selected" ring (the active ear).
var selected: bool = false
## Dimmed and refuses clicks (wiggles instead).
var locked: bool = false
var show_keycap: bool = true
## Compact pill (options row): no keycap strip below; the key chip sits inside, on the right.
var pill: bool = false
## A soft pulsing ring that says "press me" (coach).
var beckon: bool = false
## TONE pad only: draw the hold timer ring (fills cyan over 1 s, green 1-2 s, orange past 2.5 s).
var hold_ring: bool = false
## Seconds the tone has been held (-1 = not playing). Set by the screen every frame.
var hold_s: float = -1.0
## (Polish) A state lamp on the left of the face: -1 none, 0 off (dark), 1 on (lamp_color, glowing).
var lamp: int = -1
var lamp_color: Color = Palette.PLUM

var _hover := false
var _held := false
var _press := 0.0
var _press_tween: Tween
var _t := 0.0
var _wiggle := 0.0


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	resized.connect(func() -> void: pivot_offset = Vector2(size.x * 0.5, body_rect().size.y * 0.5))


func body_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size.x, size.y - (KEYCAP_H if show_keycap and not pill else 0.0)))


## The face rect as drawn now (moves down while pressed).
func face_rect() -> Rect2:
	var b := body_rect()
	var off := depth * _press
	return Rect2(b.position + Vector2(0, off), Vector2(b.size.x, b.size.y - depth))


func is_held() -> bool:
	return _held


## Forget a mouse hold whose release never arrived (pause menu, alt-tab, focus loss).
func cancel_hold() -> void:
	_held = false
	_animate_press(0.0)


## Show a press triggered from the keyboard (down = true on key press, false on release).
func show_press(down: bool) -> void:
	_animate_press(1.0 if down else 0.0)


## Quick down-up flash (a tap from the keyboard).
func flash_press() -> void:
	_animate_press(1.0, 0.05)
	get_tree().create_timer(0.09).timeout.connect(func() -> void:
		if not _held:
			_animate_press(0.0))


func wiggle() -> void:
	_wiggle = 1.0


func _animate_press(target: float, dur: float = -1.0) -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	if target > _press:
		_press_tween.tween_method(_set_press, _press, target, dur if dur > 0.0 else 0.05)
	else:
		_press_tween.tween_method(_set_press, _press, target, dur if dur > 0.0 else 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_press(v: float) -> void:
	_press = v
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if locked:
					wiggle()
					Sfx.play(&"error", 1.0, -10.0)
					denied.emit()
				else:
					_held = true
					_animate_press(1.0)
					pressed_down.emit()
			elif _held:
				_held = false
				_animate_press(0.0)
				released.emit()
				if Rect2(Vector2.ZERO, size).has_point(mb.position):
					clicked.emit()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			right_clicked.emit()
			accept_event()


func _process(delta: float) -> void:
	_t += delta
	_wiggle = maxf(0.0, _wiggle - delta * 3.0)
	if glow > 0.0 or flame_px > 0.0 or beckon or _wiggle > 0.0 or hold_s >= 0.0 or lamp > 0:
		queue_redraw()


func _draw() -> void:
	var b := body_rect()
	var wig := Vector2(sin(_t * 60.0) * 6.0 * _wiggle, 0)
	draw_set_transform(wig)
	var base_col := face_color.darkened(0.38)
	var face := face_color
	if locked:
		face = face.lerp(Palette.CREAM, 0.55)
		base_col = base_col.lerp(Palette.CREAM, 0.5)
	elif _hover:
		face = face.lightened(0.1)
	# glow behind (tone on)
	if glow > 0.0:
		for i in 3:
			var g := 6.0 + i * 7.0 + 3.0 * sin(_t * 10.0)
			AoDraw.rbox(self, b.grow(g), Color(Palette.TONE_CYAN, 0.22 * glow / (i + 1)), radius + int(g))
		face = face.lerp(Palette.TONE_CYAN, 0.55 * glow)
	if beckon and not locked:
		var p := 0.5 + 0.5 * sin(_t * 5.0)
		AoDraw.ring(self, b.grow(5.0 + 4.0 * p), Color(Palette.SELECT_ORANGE, 0.35 + 0.4 * p), radius + 6, 4)
	if selected:
		AoDraw.ring(self, b.grow(5.0), Palette.SELECT_ORANGE, radius + 5, 5)
	# drop shadow, base, face
	AoDraw.rbox(self, Rect2(b.position + Vector2(0, 5), b.size), Color(Palette.INK, 0.25), radius)
	AoDraw.rbox(self, b, base_col, radius, AoDraw.OUTLINE, Palette.INK)
	var f := face_rect()
	AoDraw.rbox(self, f, face, radius, AoDraw.OUTLINE, Palette.INK)
	# glossy highlight
	var hl := Rect2(f.position + Vector2(10, 7), Vector2(f.size.x - 20, minf(12.0, f.size.y * 0.18)))
	AoDraw.rbox(self, hl, Color(1, 1, 1, 0.38 if not locked else 0.2), 6)
	# content
	var c := f.get_center()
	var col := text_color if not locked else Color(text_color, 0.45)
	var has_icon := icon != Icon.NONE
	var has_text := text != ""
	var icon_c := c
	var text_y := c.y
	if has_icon and has_text:
		icon_c = c + Vector2(0, -f.size.y * 0.16)
		text_y = c.y + f.size.y * 0.24
	if has_icon:
		_draw_icon(icon_c, icon_size, col)
	var inline_key := pill and show_keycap and action != &""
	if inline_key:
		c.x -= 13.0
	if lamp >= 0:
		var lc := Vector2(f.position.x + 15.0, f.get_center().y)
		if lamp > 0 and not locked:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			draw_circle(lc, 11.0 + 2.0 * pulse, Color(lamp_color.lightened(0.3), 0.35))
		draw_circle(lc, 8.0, Palette.INK)
		draw_circle(lc, 6.0, lamp_color.lightened(0.15) if lamp > 0 else Color("#6b6478"))
		if lamp > 0:
			draw_circle(lc + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.7))
		c.x += 9.0
	if has_text:
		var fs := font_size if has_icon else font_size + 2
		AoDraw.text_c(self, Vector2(c.x, text_y if has_icon else c.y - (6.0 if sub_text != "" else 0.0)), text, fs, col, AoDraw.FONT_BOLD)
		if sub_text != "" and not has_icon:
			AoDraw.text_c(self, Vector2(c.x, c.y + fs * 0.62), sub_text, 13, Color(col, 0.7), AoDraw.FONT_SEMI)
	if hold_ring:
		_draw_hold_ring(Vector2(f.position.x + 30.0, f.get_center().y + 2.0), 15.0)
	# combo flame on top of the face
	if flame_px > 1.0:
		AoDraw.flame(self, Vector2(f.end.x - 30.0, f.position.y + 8.0), flame_px, _t, flame_heat)
	if inline_key:
		_draw_keycap(Vector2(f.end.x - 22.0, f.get_center().y), true)
	draw_set_transform(Vector2.ZERO)
	if show_keycap and action != &"" and not pill:
		_draw_keycap(Vector2(size.x * 0.5, b.end.y + KEYCAP_H * 0.5 + 2.0))


## The hold timer: an empty ring at rest; while the tone plays it fills cyan over the first
## second, glows green from 1 to 2 s (the sweet spot), then turns orange past 2.5 s (too long).
func _draw_hold_ring(c: Vector2, r: float) -> void:
	draw_circle(c, r + 3.0, Color(Palette.INK, 0.55))
	draw_circle(c, r, Color(Palette.LCD_BG, 0.85))
	var h := hold_s
	if h < 0.0:
		draw_arc(c, r - 3.0, 0.0, TAU, 28, Color(Palette.LCD_TEXT, 0.25), 3.0, true)
		AoDraw.text_c(self, c, "1-2s", 9, Color(Palette.LCD_TEXT, 0.7), AoDraw.FONT_BOLD)
		return
	var k := clampf(h / ClinicRules.TONE_IDEAL_MIN_S, 0.0, 1.0)
	var col := Palette.TONE_CYAN
	if h >= ClinicRules.TONE_IDEAL_MIN_S:
		col = Palette.PRESS_LIME
	if h >= 2.5:
		col = Palette.SELECT_ORANGE
	elif h > ClinicRules.TONE_IDEAL_MAX_S:
		col = Palette.PRESS_LIME.lerp(Palette.SELECT_ORANGE, (h - ClinicRules.TONE_IDEAL_MAX_S) / 0.5)
	draw_arc(c, r - 3.0, 0.0, TAU, 28, Color(Palette.LCD_TEXT, 0.15), 3.0, true)
	draw_arc(c, r - 3.0, -PI * 0.5, -PI * 0.5 + TAU * k, 28, col, 5.0, true)
	if h >= ClinicRules.TONE_IDEAL_MIN_S:
		var pulse := 0.5 + 0.5 * sin(_t * 14.0)
		draw_circle(c, r * 0.45, Color(col, 0.6 + 0.4 * pulse))
		draw_arc(c, r + 5.0 + 2.0 * pulse, 0.0, TAU, 28, Color(col, 0.45), 3.0, true)
	else:
		AoDraw.text_c(self, c, "%.1f" % h, 9, Palette.LCD_TEXT, AoDraw.FONT_BOLD)


func _draw_keycap(center: Vector2, small: bool = false) -> void:
	var labels := Game.key_labels(action)
	var label := labels[0] if labels.size() > 0 else "?"
	label = _short_key(label)
	var fs := 13 if small else 15
	var h := 18.0 if small else 22.0
	var w := maxf(h + 6.0, AoDraw.text_size(label, fs, AoDraw.FONT_BOLD).x + 14.0)
	var r := Rect2(center - Vector2(w * 0.5, h * 0.5), Vector2(w, h))
	AoDraw.rbox(self, Rect2(r.position + Vector2(0, 3), r.size), Color(Palette.INK, 0.55), 7)
	AoDraw.rbox(self, r, Palette.PAPER, 7, 2, Palette.INK)
	if label in ["Up", "Down", "Left", "Right"]:
		var dir := Vector2.UP
		match label:
			"Down":
				dir = Vector2.DOWN
			"Left":
				dir = Vector2.LEFT
			"Right":
				dir = Vector2.RIGHT
		UiDraw.arrow(self, r.get_center(), 13.0, dir, Palette.INK)
	else:
		AoDraw.text_c(self, r.get_center() + Vector2(0, -1), label, fs, Palette.INK, AoDraw.FONT_BOLD)


static func _short_key(k: String) -> String:
	match k:
		"Space":
			return "SPACE"
		"Enter", "Kp Enter":
			return "ENTER"
	return k


func _draw_icon(c: Vector2, s: float, col: Color) -> void:
	match icon:
		Icon.TRI_UP:
			UiDraw.triangle(self, c, s, true, col)
		Icon.TRI_DOWN:
			UiDraw.triangle(self, c, s, false, col)
		Icon.ARROW_LEFT:
			UiDraw.arrow(self, c, s, Vector2.LEFT, col)
		Icon.ARROW_RIGHT:
			UiDraw.arrow(self, c, s, Vector2.RIGHT, col)
		Icon.STAMP:
			# a rubber stamp: handle knob, neck, block, ink line
			draw_circle(c + Vector2(0, -s * 0.36), s * 0.2, col)
			draw_rect(Rect2(c + Vector2(-s * 0.09, -s * 0.24), Vector2(s * 0.18, s * 0.3)), col)
			AoDraw.rbox(self, Rect2(c + Vector2(-s * 0.42, s * 0.04), Vector2(s * 0.84, s * 0.26)), col, 4)
			draw_line(c + Vector2(-s * 0.5, s * 0.46), c + Vector2(s * 0.5, s * 0.46), col, 3.0, true)
		Icon.NO_RESP:
			UiDraw.arrow(self, c, s * 0.95, Vector2(1, 1), col)
		Icon.EAR_RIGHT:
			UiDraw.ear_symbol(self, c, "right", s * 0.8, 5.0, false, col)
		Icon.EAR_LEFT:
			UiDraw.ear_symbol(self, c, "left", s * 0.8, 5.0, false, col)
		Icon.WAVES:
			draw_circle(c + Vector2(-s * 0.42, 0), s * 0.13, col)
			for i in 3:
				var r := s * (0.32 + 0.24 * i)
				var a := 0.75 + (0.15 * sin(_t * 12.0 - i) if glow > 0.0 else 0.0)
				draw_arc(c + Vector2(-s * 0.42, 0), r, -a, a, 16, col, 4.0, true)
		Icon.KEYS:
			AoDraw.rbox(self, Rect2(c - Vector2(s * 0.5, s * 0.3), Vector2(s, s * 0.6)), Color(col, 0.0), 5, 3, col)
			for i in 3:
				draw_rect(Rect2(c + Vector2(-s * 0.36 + i * s * 0.26, -s * 0.14), Vector2(s * 0.18, s * 0.12)), col)
			draw_rect(Rect2(c + Vector2(-s * 0.26, s * 0.06), Vector2(s * 0.52, s * 0.1)), col)
		Icon.SWAP:
			UiDraw.arrow(self, c + Vector2(-s * 0.2, 0), s * 0.7, Vector2.UP, col)
			UiDraw.arrow(self, c + Vector2(s * 0.2, 0), s * 0.7, Vector2.DOWN, col)
