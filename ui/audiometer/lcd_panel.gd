class_name AoLcd
extends Control
## AoLcd: the AudiOtron 3000's big display (ui/ only). Left: ear chip, mode chips, frequency
## and level in big friendly digits, the TONE lamp. Right: the live staircase TRAIL of the
## current frequency (filled dot = heard, hollow = missed), strokes vs par, and a badge that
## lights up when a level has been heard twice on the way up ("STORE!").
## Mouse: the < > chevrons step the frequency, the up/down chevrons the level, the stimulus chip cycles.
## (v3) Mode chips follow the transducer (PHONE / INSERT / BONE) and the test (AC / BC); with the
## masking controls live a NOISE box shows the masker ear and level with the masking-help light,
## and on a masked test the trail becomes the PLATEAU graph (tone level against noise level:
## a flat line of heard dots = the plateau).
const MASK_COLORS: Dictionary[StringName, Color] = {
	&"off": Color("#5d5672"), &"needed": Color("#ff9f1c"), &"under": Color("#ff9f1c"),
	&"ok": Color("#9ee34b"), &"over": Color("#ff6f59"), &"impossible": Color("#8e5cc4"),
}
const MASK_WORDS: Dictionary[StringName, String] = {
	&"off": "off", &"needed": "MASK!", &"under": "too little", &"ok": "good", &"over": "too much", &"impossible": "dilemma",
}

signal freq_step(direction: int)
signal level_step(direction: int)
signal stimulus_cycle

const TRAIL_MAX := 13

var view: Dictionary = {
	"ear": "right", "freq": 1000, "db": 40, "tone_on": false, "stim": "TONE", "trail": [],
	"strokes": 0, "par": 0, "hits": {}, "candidate": -1, "accepting": false, "locked_level": false,
	# v3
	"transducer": "phones", "test": "ac", "mask": {}, "plateau": {},
}
var tone_glow: float = 0.0
var _t := 0.0
var _hot: Dictionary = {}       ## region name -> Rect2 (local) for mouse
var _hover := ""
var _bump := {"freq": 0.0, "db": 0.0}
var _deny := 0.0
## Fractional wheel steps (precision touchpads send many tiny events: factor ~0.08 each).
var _wheel_acc := 0.0
## Local position of the newest trail dot (for "HEARD!" chips), or Vector2.INF.
var _last_dot := Vector2.INF


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func update_view(d: Dictionary) -> void:
	if int(d.get("freq", 0)) != int(view.get("freq", 0)):
		_bump["freq"] = 1.0
	if int(d.get("db", 0)) != int(view.get("db", 0)):
		_bump["db"] = 1.0
	view.merge(d, true)
	queue_redraw()


## Shake the level digits: "not now" (e.g. changing level while the tone plays).
func deny() -> void:
	_deny = 1.0


func _process(delta: float) -> void:
	_t += delta
	_bump["freq"] = maxf(0.0, float(_bump["freq"]) - delta * 4.0)
	_bump["db"] = maxf(0.0, float(_bump["db"]) - delta * 4.0)
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
				"freq_down":
					freq_step.emit(-1)
				"freq_up":
					freq_step.emit(1)
				"db_up":
					level_step.emit(1)
				"db_down":
					level_step.emit(-1)
				"stim":
					stimulus_cycle.emit()
			accept_event()
		elif mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if _hit(mb.position) in ["db_up", "db_down", "db"]:
				# one 5 dB step per full wheel notch, however finely the device slices it
				_wheel_acc += (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0) * (mb.factor if mb.factor > 0.0 else 1.0)
				while absf(_wheel_acc) >= 1.0:
					var d := int(signf(_wheel_acc))
					_wheel_acc -= signf(_wheel_acc)
					level_step.emit(d)
				accept_event()


## Canvas position of the newest trail dot (or the trail's centre when it is empty).
func last_dot_global() -> Vector2:
	var p := _last_dot if _last_dot != Vector2.INF else Vector2(size.x * 0.72, size.y * 0.55)
	return get_global_transform_with_canvas() * p


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
	# scanline sheen
	AoDraw.rbox(self, Rect2(screen.position + Vector2(8, 6), Vector2(screen.size.x - 16, 16)), Color(1, 1, 1, 0.035), 8)
	# nameplate on the bezel
	var plate := Rect2(Vector2(26, -12), Vector2(176, 26))
	AoDraw.rbox(self, Rect2(plate.position + Vector2(0, 3), plate.size), Color(Palette.INK, 0.4), 13)
	AoDraw.rbox(self, plate, Palette.CORAL, 13, 3, Palette.INK)
	var lw := AoDraw.text_l(self, Vector2(plate.position.x + 14, plate.get_center().y), "AudiOtron", 17, Palette.PAPER, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(plate.position.x + 18 + lw, plate.get_center().y), "3000", 17, Palette.SUNNY, AoDraw.FONT_BOLD)
	var split := screen.position.x + minf(330.0, screen.size.x * 0.5)
	_draw_readout(Rect2(screen.position, Vector2(split - screen.position.x, screen.size.y)))
	draw_line(Vector2(split, screen.position.y + 12), Vector2(split, screen.end.y - 12), Color(Palette.LCD_DIM, 0.6), 2.0)
	_draw_trail(Rect2(Vector2(split + 10, screen.position.y), Vector2(screen.end.x - split - 14, screen.size.y)))


func _draw_readout(a: Rect2) -> void:
	var e: String = view["ear"]
	var ec := Palette.ear_color(e)
	# ear chip
	var chip := Rect2(a.position + Vector2(12, 12), Vector2(98, 28))
	AoDraw.rbox(self, chip, ec, 14)
	draw_circle(chip.position + Vector2(15, 14), 9.0, Palette.PAPER)
	UiDraw.ear_symbol(self, chip.position + Vector2(15, 14), e, 10.0, 2.5)
	AoDraw.text_l(self, chip.position + Vector2(30, 14), e.to_upper(), 16, Palette.PAPER, AoDraw.FONT_BOLD)
	# mode chips (orange outline, like a real audiometer's mode lights)
	var x := chip.end.x + 8.0
	var tr := String(view.get("transducer", "phones"))
	var mode_labels: Array[String] = ["BONE" if tr == "bone" else ("INSERT" if tr == "inserts" else "PHONE"), "BC" if tr == "bone" else "AC"]
	for label: String in mode_labels:
		var w := AoDraw.text_size(label, 12, AoDraw.FONT_BOLD).x + 14.0
		var cr := Rect2(Vector2(x, chip.position.y + 3), Vector2(w, 22))
		AoDraw.ring(self, cr, Palette.SELECT_ORANGE, 11, 2)
		AoDraw.text_c(self, cr.get_center(), label, 12, Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
		x += w + 6.0
	var stim: String = view["stim"]
	var sw := AoDraw.text_size(stim, 12, AoDraw.FONT_BOLD).x + 26.0
	var sr := Rect2(Vector2(x, chip.position.y + 3), Vector2(sw, 22))
	AoDraw.rbox(self, sr, Palette.SELECT_ORANGE if _hover != "stim" else Palette.SUNNY, 11)
	AoDraw.text_c(self, sr.get_center() + Vector2(-5, 0), stim, 12, Palette.LCD_BG, AoDraw.FONT_BOLD)
	UiDraw.triangle(self, sr.get_center() + Vector2(sw * 0.5 - 10, 1), 7.0, false, Palette.LCD_BG)
	_hot["stim"] = sr
	# frequency row
	var fy := a.position.y + 70.0
	var ftxt := "%d" % int(view["freq"])
	var fs := 40
	var fb := float(_bump["freq"])
	var fw := AoDraw.text_size(ftxt, fs, AoDraw.FONT_BOLD).x
	var fx := a.position.x + 44.0
	AoDraw.text_l(self, Vector2(fx, fy - fb * 4.0), ftxt, fs, Palette.LCD_TEXT, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(fx + fw + 6.0, fy + 6.0), "Hz", 18, Color(Palette.LCD_TEXT, 0.7), AoDraw.FONT_SEMI)
	_chevron(Rect2(Vector2(a.position.x + 10, fy - 15), Vector2(28, 30)), Vector2.LEFT, "freq_down")
	_chevron(Rect2(Vector2(fx + fw + 36.0, fy - 15), Vector2(28, 30)), Vector2.RIGHT, "freq_up")
	# level row
	var ly := a.position.y + a.size.y - 40.0
	var ltxt := "%d" % int(view["db"])
	var ls := 60
	var lb := float(_bump["db"])
	var shake := sin(_t * 70.0) * 7.0 * _deny
	var lx := a.position.x + 44.0 + shake
	var lcol := Palette.LCD_TEXT if not bool(view["tone_on"]) else Palette.TONE_CYAN.lerp(Palette.LCD_TEXT, 0.3)
	var lwid := AoDraw.text_size(ltxt, ls, AoDraw.FONT_BOLD).x
	AoDraw.text_l(self, Vector2(lx, ly - lb * 5.0), ltxt, ls, lcol, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(lx + lwid + 8.0, ly + 10.0), "dB HL", 19, Color(Palette.LCD_TEXT, 0.7), AoDraw.FONT_SEMI)
	_chevron(Rect2(Vector2(a.position.x + 10, ly - 30), Vector2(28, 26)), Vector2.UP, "db_up")
	_chevron(Rect2(Vector2(a.position.x + 10, ly + 4), Vector2(28, 26)), Vector2.DOWN, "db_down")
	_hot["db"] = Rect2(Vector2(lx, ly - 30), Vector2(lwid + 70.0, 60))
	# TONE lamp
	var lc := Vector2(a.end.x - 40.0, ly - 2.0)
	var g := tone_glow
	if g > 0.0:
		for i in 3:
			var rr := 26.0 + 9.0 * i + 6.0 * fmod(_t * 2.5 + i * 0.33, 1.0)
			draw_arc(lc, rr, -0.9, 0.9, 18, Color(Palette.TONE_CYAN, 0.5 * g * (1.0 - i * 0.28)), 3.0, true)
			draw_arc(lc, rr, PI - 0.9, PI + 0.9, 18, Color(Palette.TONE_CYAN, 0.5 * g * (1.0 - i * 0.28)), 3.0, true)
		draw_circle(lc, 30.0, Color(Palette.TONE_CYAN, 0.18 * g))
	draw_circle(lc, 22.0, Palette.INK)
	draw_circle(lc, 18.0, Palette.LCD_DIM.lerp(Palette.TONE_CYAN, g))
	draw_circle(lc + Vector2(-6, -6), 5.0, Color(1, 1, 1, 0.25 + 0.4 * g))
	AoDraw.text_c(self, lc + Vector2(0, -34), "TONE", 12, Palette.LCD_TEXT.lerp(Palette.TONE_CYAN, g), AoDraw.FONT_BOLD)
	var mask: Dictionary = view.get("mask", {})
	if bool(mask.get("enabled", false)):
		_draw_masker(Rect2(Vector2(a.end.x - 122.0, fy - 22.0), Vector2(114.0, 46.0)), mask)


## (v3) The NOISE box: masker ear, level (dB EM) and the masking-help light. Lit while on.
func _draw_masker(r: Rect2, m: Dictionary) -> void:
	var on := bool(m.get("on", false))
	var status := StringName(String(m.get("status", "off")))
	var light: Color = MASK_COLORS.get(status, Palette.LCD_DIM)
	var me := String(m.get("ear", "left"))
	AoDraw.rbox(self, r, Color(Palette.PLUM, 0.28 if on else 0.08), 10, 2, Palette.PLUM if on else Palette.LCD_DIM)
	var head := "NOISE %s" % ("L" if me == "left" else "R")
	AoDraw.text_l(self, r.position + Vector2(8, 11), head, 11, Palette.LCD_TEXT if on else Color(Palette.LCD_TEXT, 0.5), AoDraw.FONT_BOLD)
	var lv := "%d" % int(m.get("db", 0))
	var lw := AoDraw.text_l(self, r.position + Vector2(8, 31), lv, 22, Palette.LCD_TEXT if on else Color(Palette.LCD_TEXT, 0.45), AoDraw.FONT_BOLD)
	AoDraw.text_l(self, r.position + Vector2(12 + lw, 34), "dB EM", 10, Color(Palette.LCD_TEXT, 0.6), AoDraw.FONT_SEMI)
	var lc := Vector2(r.end.x - 14.0, r.position.y + 12.0)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0) if status in [&"needed", &"under", &"over"] else 1.0
	draw_circle(lc, 7.0, Palette.INK)
	draw_circle(lc, 5.5, light.lerp(Palette.LCD_BG, 0.0 if pulse > 0.5 else 0.4))
	AoDraw.text_r(self, Vector2(r.end.x - 6.0, r.end.y - 9.0), String(MASK_WORDS.get(status, "")), 10, light, AoDraw.FONT_BOLD)
	if on:
		for i in 4:
			var xx := r.position.x + 64.0 + i * 5.0
			var hh := 4.0 + 5.0 * absf(sin(_t * 17.0 + i * 1.3))
			draw_line(Vector2(xx, r.position.y + 11.0 - hh * 0.5), Vector2(xx, r.position.y + 11.0 + hh * 0.5), Color(Palette.PLUM.lightened(0.4), 0.9), 2.0)


func _chevron(rect: Rect2, dir: Vector2, id: String) -> void:
	_hot[id] = rect.grow(4.0)
	var hot := _hover == id
	if hot:
		AoDraw.rbox(self, rect, Color(Palette.SELECT_ORANGE, 0.25), 8)
	if dir == Vector2.UP:
		UiDraw.triangle(self, rect.get_center(), 14.0, true, Color(Palette.SELECT_ORANGE, 0.9))
	elif dir == Vector2.DOWN:
		UiDraw.triangle(self, rect.get_center(), 14.0, false, Color(Palette.SELECT_ORANGE, 0.9))
	elif dir == Vector2.LEFT or dir == Vector2.RIGHT:
		var c := rect.get_center()
		var s := 9.0 * dir.x
		draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(-s, -10), c + Vector2(-s, 10)]), Color(Palette.SELECT_ORANGE, 0.9))


func _draw_trail(a: Rect2) -> void:
	if not (view.get("plateau", {}) as Dictionary).is_empty():
		_draw_plateau(a, view["plateau"])
		return
	var trail: Array = view["trail"]
	var cur_db := int(view["db"])
	var head_y := a.position.y + 20.0
	AoDraw.text_l(self, Vector2(a.position.x + 4, head_y), "TRAIL", 14, Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(a.position.x + 56, head_y), "%d Hz" % int(view["freq"]), 14, Color(Palette.LCD_TEXT, 0.7), AoDraw.FONT_SEMI)
	var par := int(view["par"])
	var strokes := int(view["strokes"])
	var golf := "STROKES %d" % strokes + ("   PAR %d" % par if par > 0 else "")
	var gcol := Palette.LCD_TEXT if par <= 0 or strokes <= par else Palette.CORAL
	AoDraw.text_r(self, Vector2(a.end.x - 4, head_y), golf, 14, gcol, AoDraw.FONT_BOLD)
	var plot := Rect2(a.position + Vector2(30, 38), Vector2(a.size.x - 40, a.size.y - 50))
	# level range
	var lo := cur_db
	var hi := cur_db
	var start := maxi(0, trail.size() - TRAIL_MAX + 1)
	for i in range(start, trail.size()):
		lo = mini(lo, int(trail[i]["db"]))
		hi = maxi(hi, int(trail[i]["db"]))
	var mid := (lo + hi) / 2.0
	var span := maxf(30.0, float(hi - lo) + 15.0)
	var top_db := mid - span * 0.5
	var bot_db := mid + span * 0.5
	var to_y := func(db: float) -> float: return plot.position.y + plot.size.y * (db - top_db) / (bot_db - top_db)
	# grid
	var g0 := int(ceil(top_db / 5.0)) * 5
	for lvl in range(g0, int(bot_db) + 1, 5):
		var y: float = to_y.call(float(lvl))
		var major := lvl % 10 == 0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(Palette.LCD_DIM, 0.55 if major else 0.25), 1.0)
		if major:
			AoDraw.text_r(self, Vector2(plot.position.x - 6, y), str(lvl), 11, Color(Palette.LCD_TEXT, 0.55), AoDraw.FONT_MED)
	var hits: Dictionary = view["hits"]
	var cand := int(view["candidate"])
	# ascending-hit badges per level (side by side when two levels sit close together)
	var used: Array[Rect2] = []
	var lvls: Array = hits.keys()
	lvls.sort()
	for lvl: int in lvls:
		var n := int(hits[lvl])
		if n <= 0 or float(lvl) < top_db or float(lvl) > bot_db:
			continue
		var y: float = to_y.call(float(lvl))
		var is_cand := lvl == cand
		if is_cand:
			var p := 0.5 + 0.5 * sin(_t * 6.0)
			draw_rect(Rect2(plot.position.x, y - 7, plot.size.x, 14), Color(Palette.PRESS_LIME, 0.12 + 0.12 * p))
		var txt := "STORE!" if is_cand else "%d/2" % mini(n, 2)
		var bw := AoDraw.text_size(txt, 11, AoDraw.FONT_BOLD).x + 12.0
		var br := Rect2(Vector2(plot.end.x - bw, y - 9), Vector2(bw, 18))
		for u: Rect2 in used:
			if u.grow(1.0).intersects(br):
				br.position.x = u.position.x - bw - 4.0
		used.append(br)
		AoDraw.rbox(self, br, Palette.PRESS_LIME if is_cand else Palette.SELECT_ORANGE, 9)
		AoDraw.text_c(self, br.get_center(), txt, 11, Palette.LCD_BG, AoDraw.FONT_BOLD)
	# dots
	var step_x := plot.size.x / float(TRAIL_MAX + 0.5)
	var pts := PackedVector2Array()
	for i in range(start, trail.size()):
		pts.append(Vector2(plot.position.x + step_x * (i - start + 0.6), to_y.call(float(trail[i]["db"]))))
	_last_dot = pts[pts.size() - 1] if pts.size() > 0 else Vector2.INF
	if pts.size() >= 2:
		draw_polyline(pts, Color(Palette.LCD_TEXT, 0.35), 2.0, true)
	for i in range(start, trail.size()):
		var rec: Dictionary = trail[i]
		var c := pts[i - start]
		if bool(rec["responded"]):
			draw_circle(c, 8.0, Palette.PRESS_LIME)
			draw_arc(c, 8.0, 0.0, TAU, 20, Palette.LCD_BG, 2.0, true)
		elif not bool(rec["closed"]):
			var p := 0.5 + 0.5 * sin(_t * 10.0)
			draw_arc(c, 7.0 + 2.0 * p, 0.0, TAU, 20, Palette.TONE_CYAN, 3.0, true)
		else:
			draw_circle(c, 7.0, Palette.LCD_BG)
			draw_arc(c, 7.0, 0.0, TAU, 20, Palette.LCD_TEXT, 2.5, true)
	# next tone marker at the dial level
	if bool(view["accepting"]):
		var nx := plot.position.x + step_x * (trail.size() - start + 0.6)
		var ny: float = to_y.call(float(cur_db))
		if nx < plot.end.x - 20.0:
			var p2 := 0.5 + 0.5 * sin(_t * 4.0)
			draw_arc(Vector2(nx, ny), 8.0, 0.0, TAU, 20, Color(Palette.SELECT_ORANGE, 0.5 + 0.5 * p2), 2.5, true)
			AoDraw.dashed(self, Vector2(plot.position.x, ny), Vector2(nx - 10.0, ny), Color(Palette.SELECT_ORANGE, 0.35), 1.5, 4.0, 4.0)
	if trail.is_empty():
		AoDraw.text_c(self, plot.get_center() + Vector2(0, 14), "beeps show up here", 13, Color(Palette.LCD_TEXT, 0.35), AoDraw.FONT_SEMI)
		AoDraw.text_c(self, plot.get_center() - Vector2(0, 8), "filled = heard   hollow = missed", 12, Color(Palette.LCD_TEXT, 0.3), AoDraw.FONT_MED)


## (v3) The plateau graph of a masked measurement: noise level (dB EM) across, tone level (dB HL)
## down, one dot per presentation (filled = heard). The heard run that survives the noise raises is
## joined by a thick line: flat = plateau. "PLATEAU n/3" (or "STORE!") shows the count.
func _draw_plateau(a: Rect2, pl: Dictionary) -> void:
	var trail: Array = view["trail"]
	var head_y := a.position.y + 20.0
	AoDraw.text_l(self, Vector2(a.position.x + 4, head_y), "PLATEAU", 14, Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, Vector2(a.position.x + 78, head_y), "%d Hz" % int(view["freq"]), 14, Color(Palette.LCD_TEXT, 0.7), AoDraw.FONT_SEMI)
	var steps := int(pl.get("steps", 0))
	var needed := int(pl.get("needed", 3))
	var found := bool(pl.get("found", false))
	var badge := "STORE!" if found else "%d/%d noise ups" % [mini(steps, needed), needed]
	var bw := AoDraw.text_size(badge, 12, AoDraw.FONT_BOLD).x + 14.0
	var br := Rect2(Vector2(a.end.x - 4 - bw, head_y - 10), Vector2(bw, 20))
	AoDraw.rbox(self, br, Palette.PRESS_LIME if found else Palette.SELECT_ORANGE, 10)
	AoDraw.text_c(self, br.get_center(), badge, 12, Palette.LCD_BG, AoDraw.FONT_BOLD)
	var plot := Rect2(a.position + Vector2(30, 40), Vector2(a.size.x - 40, a.size.y - 62))
	var m_lo := int(pl.get("initial", 0)) - 10
	var m_hi := m_lo + 40
	var t_lo := int(view["db"])
	var t_hi := t_lo
	for rec: Dictionary in trail:
		var m := int(rec.get("mask_db", -1))
		if m >= 0:
			m_lo = mini(m_lo, m - 5)
			m_hi = maxi(m_hi, m + 5)
		t_lo = mini(t_lo, int(rec["db"]))
		t_hi = maxi(t_hi, int(rec["db"]))
	var mid := (t_lo + t_hi) / 2.0
	var span := maxf(30.0, float(t_hi - t_lo) + 15.0)
	var top_db := mid - span * 0.5
	var to_x := func(m: float) -> float: return plot.position.x + plot.size.x * (m - m_lo) / maxf(1.0, float(m_hi - m_lo))
	var to_y := func(db: float) -> float: return plot.position.y + plot.size.y * (db - top_db) / span
	for lvl in range(int(ceil(top_db / 10.0)) * 10, int(top_db + span) + 1, 10):
		var y: float = to_y.call(float(lvl))
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(Palette.LCD_DIM, 0.45), 1.0)
		AoDraw.text_r(self, Vector2(plot.position.x - 6, y), str(lvl), 11, Color(Palette.LCD_TEXT, 0.55), AoDraw.FONT_MED)
	var init := int(pl.get("initial", 0))
	var ix: float = to_x.call(float(init))
	AoDraw.dashed(self, Vector2(ix, plot.position.y), Vector2(ix, plot.end.y), Color(Palette.PLUM.lightened(0.3), 0.8), 1.5, 4.0, 4.0)
	AoDraw.text_c(self, Vector2(ix, plot.end.y + 10.0), "start %d" % init, 10, Palette.PLUM.lightened(0.4), AoDraw.FONT_BOLD)
	AoDraw.text_r(self, Vector2(plot.end.x, plot.end.y + 10.0), "noise dB EM >", 10, Color(Palette.LCD_TEXT, 0.5), AoDraw.FONT_SEMI)
	# the plateau run: same tone level, rising noise
	var run_db := int(pl.get("db", -1))
	if run_db >= 0 and steps > 0:
		var end_m := 0
		for rec: Dictionary in trail:
			if bool(rec["responded"]) and int(rec["db"]) == run_db:
				end_m = maxi(end_m, int(rec.get("mask_db", -1)))
		var start_m := int(pl.get("start_mask", end_m))
		var y0: float = to_y.call(float(run_db))
		var col := Palette.PRESS_LIME if found else Palette.SUNNY
		draw_line(Vector2(to_x.call(float(start_m)), y0), Vector2(to_x.call(float(end_m)), y0), Color(col, 0.55), 9.0, true)
		if found:
			AoDraw.text_c(self, Vector2((to_x.call(float(start_m)) + to_x.call(float(end_m))) * 0.5, y0 - 16.0), "FLAT LINE!", 12, Palette.PRESS_LIME, AoDraw.FONT_BOLD)
	_last_dot = Vector2.INF
	for rec: Dictionary in trail:
		var m2 := int(rec.get("mask_db", -1))
		if m2 < 0:
			continue
		var c := Vector2(to_x.call(float(m2)), to_y.call(float(rec["db"])))
		_last_dot = c
		if bool(rec["responded"]):
			draw_circle(c, 7.0, Palette.PRESS_LIME)
			draw_arc(c, 7.0, 0.0, TAU, 20, Palette.LCD_BG, 2.0, true)
		elif not bool(rec["closed"]):
			draw_arc(c, 7.0 + 2.0 * (0.5 + 0.5 * sin(_t * 10.0)), 0.0, TAU, 20, Palette.TONE_CYAN, 3.0, true)
		else:
			draw_circle(c, 6.0, Palette.LCD_BG)
			draw_arc(c, 6.0, 0.0, TAU, 20, Palette.LCD_TEXT, 2.5, true)
	# the next beep: dial tone level at the dial noise level
	var mk: Dictionary = view.get("mask", {})
	if bool(view["accepting"]) and bool(mk.get("on", false)):
		var nc := Vector2(to_x.call(float(mk.get("db", 0))), to_y.call(float(view["db"])))
		if plot.grow(10.0).has_point(nc):
			draw_arc(nc, 9.0, 0.0, TAU, 20, Color(Palette.SELECT_ORANGE, 0.6 + 0.4 * sin(_t * 4.0)), 2.5, true)
	if trail.is_empty():
		AoDraw.text_c(self, plot.get_center(), "heard: noise +5   missed: tone +5", 12, Color(Palette.LCD_TEXT, 0.35), AoDraw.FONT_MED)
