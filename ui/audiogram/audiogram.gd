class_name Audiogram
extends Control
## Audiogram: the reusable chart widget (builder A, CONTRACTS.md §4.6).
## Used by the AudiOtron screen (one card per ear) and by story/ for the reveal and evidence.
## Public API (keep stable):
##   ear                      "right", "left" or "both" (which points are drawn)
##   show_title               draws an ear title strip above the plot
##   set_point(ear, freq, db, no_response := false, animate := true)
##   clear_points()
##   show_results(results, animate := false)   # results = CONTRACTS.md §5.1; emits draw_finished
##   set_cursor(freq, db, visible)
##   freq_to_x(freq) / db_to_y(db)             # local coordinates
##   get_point_global_position(ear, freq) -> Vector2
##   get_region_global_rect(freq_lo, freq_hi, db_lo := -10, db_hi := 120) -> Rect2
##   signal draw_finished
## Extras (ui-internal): signal freq_clicked(freq), play_melody(ear), point_count(ear).
## Look: log-frequency axis 125 Hz - 8 kHz (octaves + inter-octaves), -10 dB at the top down to
## 120, a faint normal band and speech banana, shading beyond the AudiOtron's maximum output,
## ASHA symbols (right = red O, left = blue X, no response = arrow) that STAMP on with a
## hit-stop and an ink splat, and connecting lines drawn in like a pen.

signal draw_finished
## The player clicked the plot near a test frequency (AudiOtron uses it to jump there).
signal freq_clicked(freq: int)

const AXIS_FREQS: Array[int] = [125, 250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000]
const FREQ_LABELS: Dictionary[int, String] = {125: "125", 250: "250", 500: "500", 1000: "1k", 2000: "2k", 4000: "4k", 8000: "8k"}
const MINOR_LABELS: Dictionary[int, String] = {750: "750", 1500: "1.5k", 3000: "3k", 6000: "6k"}
const DB_TOP := -10
const DB_BOTTOM := 120
const LOW_HZ := 125.0
const OCTAVES := 6.0
## Speech banana (dB HL), soft and loud edges per frequency. Teaching sketch, not a norm.
## Speech banana [freq, top dB, bottom dB]: loud vowels low and wide, the soft high consonants
## (s, sh, f, th) up at 10-40 dB at 4-6 kHz, which is why a sloping loss scrambles them.
const BANANA: Array = [[250, 24, 52], [500, 20, 56], [1000, 18, 56], [2000, 16, 52], [3000, 14, 46], [4000, 12, 38], [6000, 10, 32]]
const DEGREES: Array = [[-10, 25, "normal"], [25, 40, "mild"], [40, 55, "moderate"], [55, 70, "mod-severe"], [70, 90, "severe"], [90, 120, "profound"]]
const STAMP_IN_S := 0.09
const HIT_STOP_S := 0.07
const STAMP_SETTLE_S := 0.2
const PEN_S := 0.32

@export var ear: String = "right"
@export var show_title: bool = false
## Show the speech banana and degree labels (on by default; turn off for tiny charts).
@export var show_guides: bool = true

## ear -> freq -> {"db": int, "no_response": bool, "age": float (seconds since stamped, -1 = static), "seed": int}
var points: Dictionary = {"right": {}, "left": {}}
var cursor_freq: int = 1000
var cursor_db: int = 40
var cursor_visible: bool = false
## Ear whose symbol the cursor ghost shows (defaults to this chart's ear).
var cursor_ear: String = ""
var _reveal: float = 1.0
var _segments: Dictionary = {}   ## "ear:f1:f2" -> draw progress 0..1
var _bounce: Dictionary = {}     ## "ear:freq" -> seconds left of a melody bounce
var _animating := false
var _font: Font
var _hover_freq := -1


func _ready() -> void:
	_font = AoDraw.FONT_SEMI
	resized.connect(queue_redraw)
	custom_minimum_size = custom_minimum_size.max(Vector2(240, 180))
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func() -> void:
		_hover_freq = -1
		queue_redraw())


# ---------------------------------------------------------------- public API

func set_point(p_ear: String, freq: int, db: int, no_response: bool = false, animate: bool = true) -> void:
	if not points.has(p_ear):
		points[p_ear] = {}
	var pts: Dictionary = points[p_ear]
	pts[freq] = {"db": db, "no_response": no_response, "age": 0.0 if animate else -1.0, "seed": freq * 7 + (1 if p_ear == "right" else 2)}
	_refresh_segments(p_ear, freq, animate)
	_animating = _animating or animate
	queue_redraw()


func clear_points() -> void:
	points = {"right": {}, "left": {}}
	_segments.clear()
	_bounce.clear()
	queue_redraw()


func point_count(p_ear: String) -> int:
	return (points.get(p_ear, {}) as Dictionary).size()


## Load every stored threshold from a results Dictionary (§5.1). animate = stamp them on one
## by one from low to high pitch with the lines drawing in, then emit draw_finished.
func show_results(results: Dictionary, animate: bool = false) -> void:
	clear_points()
	var ears: Dictionary = results.get("ears", {})
	var queue: Array = []
	for e: String in ears:
		var freqs: Dictionary = (ears[e] as Dictionary).get("freqs", {})
		var fl: Array = freqs.keys()
		fl.sort()
		for f: int in fl:
			var info: Dictionary = freqs[f]
			queue.append([e, f, int(info["stored_db"]), bool(info.get("no_response", false))])
	if not animate:
		for q: Array in queue:
			set_point(q[0], q[1], q[2], q[3], false)
		_reveal = 1.0
		queue_redraw()
		draw_finished.emit.call_deferred()
		return
	_reveal = 1.0
	queue.sort_custom(func(a: Array, b: Array) -> bool: return a[1] < b[1] if a[1] != b[1] else a[0] == "right")
	var t := create_tween()
	for q: Array in queue:
		t.tween_callback(func() -> void:
			set_point(q[0], q[1], q[2], q[3], true)
			Sfx.play(&"stamp", randf_range(0.95, 1.08), -4.0)
			Sfx.play_note(Sfx.audiogram_note_hz(int(q[1])), -8.0))
		t.tween_interval(0.16)
	t.tween_interval(PEN_S + 0.25)
	t.tween_callback(draw_finished.emit)


func set_cursor(freq: int, db: int, p_visible: bool) -> void:
	if freq == cursor_freq and db == cursor_db and p_visible == cursor_visible:
		return
	cursor_freq = freq
	cursor_db = db
	cursor_visible = p_visible
	queue_redraw()


## Bounce each symbol of an ear in pitch order (the musical audiogram). Returns the duration.
func play_melody(p_ear: String, step_s: float = 0.2) -> float:
	var pts: Dictionary = points.get(p_ear, {})
	var fl: Array = pts.keys()
	fl.sort()
	var t := create_tween()
	for f: int in fl:
		t.tween_callback(func() -> void:
			_bounce["%s:%d" % [p_ear, f]] = 0.35
			_animating = true
			Sfx.play_note(Sfx.audiogram_note_hz(f), -4.0))
		t.tween_interval(step_s)
	return step_s * fl.size()


func title_height() -> float:
	return 30.0 if show_title else 0.0


func plot_rect() -> Rect2:
	var top := 26.0 + title_height()
	var left := 40.0
	return Rect2(left, top, maxf(10.0, size.x - left - 12.0), maxf(10.0, size.y - top - 12.0))


func freq_to_x(freq: int) -> float:
	var r := plot_rect()
	var oct := log(float(freq) / LOW_HZ) / log(2.0)
	return r.position.x + r.size.x * (0.035 + 0.93 * oct / OCTAVES)


func db_to_y(db: float) -> float:
	var r := plot_rect()
	return r.position.y + r.size.y * (db - DB_TOP) / float(DB_BOTTOM - DB_TOP)


func get_point_global_position(p_ear: String, freq: int) -> Vector2:
	var pts: Dictionary = points.get(p_ear, {})
	var db: float = float(pts[freq]["db"]) if pts.has(freq) else 0.0
	return get_global_transform_with_canvas() * Vector2(freq_to_x(freq), db_to_y(db))


func get_region_global_rect(freq_lo: int, freq_hi: int, db_lo: float = DB_TOP, db_hi: float = DB_BOTTOM) -> Rect2:
	var a := Vector2(freq_to_x(freq_lo) - 14.0, db_to_y(db_lo))
	var b := Vector2(freq_to_x(freq_hi) + 14.0, db_to_y(db_hi))
	var xf := get_global_transform_with_canvas()
	return Rect2(xf * a, (xf * b) - (xf * a)).abs()


## The test frequency nearest to a local x (or -1 outside the plot).
func freq_at(local_x: float) -> int:
	var r := plot_rect()
	if local_x < r.position.x - 10.0 or local_x > r.end.x + 10.0:
		return -1
	var best := -1
	var best_d := 1e9
	for f: int in ClinicRules.AC_FREQS:
		var d := absf(freq_to_x(f) - local_x)
		if d < best_d:
			best_d = d
			best = f
	return best if best_d < 30.0 else -1


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if not freq_clicked.has_connections():
		return
	if event is InputEventMouseMotion:
		var f := freq_at((event as InputEventMouseMotion).position.x)
		if f != _hover_freq:
			_hover_freq = f
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if f > 0 else Control.CURSOR_ARROW
			queue_redraw()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			var f := freq_at(mb.position.x)
			if f > 0:
				freq_clicked.emit(f)
				accept_event()


# ---------------------------------------------------------------- animation

func _process(delta: float) -> void:
	if not _animating:
		return
	var busy := false
	for e: String in points:
		for f: int in points[e]:
			var p: Dictionary = points[e][f]
			if float(p["age"]) >= 0.0:
				p["age"] = float(p["age"]) + delta
				if float(p["age"]) < STAMP_IN_S + HIT_STOP_S + STAMP_SETTLE_S + 0.6:
					busy = true
				else:
					p["age"] = -1.0
	for k: String in _segments.keys():
		var v: float = _segments[k]
		if v < 1.0:
			_segments[k] = minf(1.0, v + delta / PEN_S) if _segment_ready(k) else v
			busy = true
	for k: String in _bounce.keys():
		_bounce[k] = float(_bounce[k]) - delta
		if float(_bounce[k]) <= 0.0:
			_bounce.erase(k)
		else:
			busy = true
	_animating = busy
	queue_redraw()


## A segment starts drawing once both of its end points have landed.
func _segment_ready(key: String) -> bool:
	var parts := key.split(":")
	var pts: Dictionary = points.get(parts[0], {})
	for i in [1, 2]:
		var f := int(parts[i])
		if pts.has(f) and float(pts[f]["age"]) >= 0.0 and float(pts[f]["age"]) < STAMP_IN_S + HIT_STOP_S:
			return false
	return true


func _refresh_segments(p_ear: String, freq: int, animate: bool) -> void:
	var pts: Dictionary = points[p_ear]
	var fl: Array = []
	for f: int in pts:
		if not bool(pts[f]["no_response"]):
			fl.append(f)
	fl.sort()
	var keep: Dictionary = {}
	for i in fl.size() - 1:
		var key := "%s:%d:%d" % [p_ear, fl[i], fl[i + 1]]
		keep[key] = true
		if not _segments.has(key):
			_segments[key] = 0.0 if animate else 1.0
		elif (fl[i] == freq or fl[i + 1] == freq) and animate:
			_segments[key] = 0.0
	for k: String in _segments.keys():
		if k.begins_with(p_ear + ":") and not keep.has(k):
			_segments.erase(k)


## Symbol scale during a stamp: big and fast in, frozen (hit-stop), then a springy settle.
static func stamp_scale(age: float) -> float:
	if age < 0.0:
		return 1.0
	if age < STAMP_IN_S:
		return lerpf(2.6, 0.82, age / STAMP_IN_S)
	if age < STAMP_IN_S + HIT_STOP_S:
		return 0.82
	var k := clampf((age - STAMP_IN_S - HIT_STOP_S) / STAMP_SETTLE_S, 0.0, 1.0)
	var back := 1.0 + 2.7 * pow(k - 1.0, 3) + 1.7 * pow(k - 1.0, 2)  # ease-out-back 0..1
	return lerpf(0.82, 1.0, back)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var r := plot_rect()
	var tint := Palette.ear_tint(ear) if ear != "both" else Palette.PAPER
	AoDraw.rbox(self, Rect2(Vector2.ZERO, size), tint, 16)
	if show_title:
		var tr := Rect2(Vector2(0, 0), Vector2(size.x, title_height()))
		AoDraw.rbox(self, tr, Palette.ear_color(ear) if ear != "both" else Palette.INK, 14)
		var title := "RIGHT EAR" if ear == "right" else ("LEFT EAR" if ear == "left" else "BOTH EARS")
		AoDraw.text_c(self, tr.get_center(), title, 18, Palette.PAPER, AoDraw.FONT_BOLD)
	AoDraw.rbox(self, r.grow(2.0), Palette.PAPER, 6)
	# normal band
	draw_rect(Rect2(r.position.x, db_to_y(DB_TOP), r.size.x, db_to_y(25) - db_to_y(DB_TOP)), Color(Palette.MINT, 0.13))
	if show_guides:
		_draw_banana()
	_draw_max_output(r)
	_draw_grid(r)
	if show_guides and r.size.x > 330.0:
		for d: Array in DEGREES:
			var y := (db_to_y(float(d[0])) + db_to_y(float(d[1]))) * 0.5
			AoDraw.text_r(self, Vector2(r.end.x - 4.0, y), String(d[2]), 11, Color(Palette.INK_SOFT, 0.55), AoDraw.FONT_MED)
	if _hover_freq > 0:
		var hx := freq_to_x(_hover_freq)
		draw_rect(Rect2(hx - 9.0, r.position.y, 18.0, r.size.y), Color(Palette.SELECT_ORANGE, 0.1))
	if cursor_visible:
		_draw_cursor(r)
	for e: String in ["right", "left"]:
		if ear != "both" and ear != e:
			continue
		_draw_ear(e)
	AoDraw.ring(self, r.grow(2.0), Color(Palette.INK, 0.55), 6, 2)


func _draw_grid(r: Rect2) -> void:
	var step := 10 if r.size.y > 200.0 else 20
	for db in range(DB_TOP, DB_BOTTOM + 1, 10):
		var y := db_to_y(db)
		var strong := db % 20 == 0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Palette.INK, 0.16 if strong else 0.07), 1.0 if db != 0 else 2.0)
		if db % step == 0:
			AoDraw.text_r(self, Vector2(r.position.x - 6.0, y), str(db), 12, Palette.INK_SOFT, AoDraw.FONT_MED)
	for f: int in AXIS_FREQS:
		var x := freq_to_x(f)
		var octave := FREQ_LABELS.has(f)
		if octave:
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(Palette.INK, 0.17), 1.0)
			AoDraw.text_c(self, Vector2(x, r.position.y - 13.0), FREQ_LABELS[f], 13, Palette.INK_SOFT, AoDraw.FONT_SEMI)
		else:
			AoDraw.dashed(self, Vector2(x, r.position.y), Vector2(x, r.end.y), Color(Palette.INK, 0.08), 1.0, 4.0, 4.0)
			if r.size.x > 330.0 and MINOR_LABELS.has(f):
				AoDraw.text_c(self, Vector2(x, r.position.y - 12.0), MINOR_LABELS[f], 10, Color(Palette.INK_SOFT, 0.6), AoDraw.FONT_MED)


func _draw_banana() -> void:
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	for b: Array in BANANA:
		top.append(Vector2(freq_to_x(int(b[0])), db_to_y(float(b[1]))))
		bottom.append(Vector2(freq_to_x(int(b[0])), db_to_y(float(b[2]))))
	var poly := PackedVector2Array()
	poly.append_array(_smooth(top))
	var back := _smooth(bottom)
	back.reverse()
	poly.append_array(back)
	draw_colored_polygon(poly, Color(Palette.SUNNY, 0.2))
	var mid := (top[2] + bottom[2]) * 0.5
	if plot_rect().size.x > 300.0:
		AoDraw.text_c(self, mid + Vector2(28, 0), "speech", 11, Color(Palette.SELECT_ORANGE, 0.75), AoDraw.FONT_SEMI)


## Catmull-Rom-ish smoothing of a polyline (for the banana).
static func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for s in 6:
			var t := s / 6.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


func _draw_max_output(r: Rect2) -> void:
	if r.size.x < 8.0 or r.size.y < 8.0:
		return
	var line := PackedVector2Array()
	for f: int in ClinicRules.AC_FREQS:
		var p := Vector2(freq_to_x(f), minf(db_to_y(float(ClinicRules.max_db(f)) + 2.5), r.end.y - 1.0))
		if line.is_empty() and p.x > r.position.x + 0.5:
			line.append(Vector2(r.position.x, p.y))
		if line.is_empty() or p.distance_to(line[line.size() - 1]) > 0.5:
			line.append(p)
	if line[line.size() - 1].x < r.end.x - 0.5:
		line.append(Vector2(r.end.x, line[line.size() - 1].y))
	# fill the strip below the line, one quad per segment (never a degenerate polygon)
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		if b.x - a.x < 0.5:
			continue
		draw_colored_polygon(PackedVector2Array([a, b, Vector2(b.x, r.end.y), Vector2(a.x, r.end.y)]), Color(Palette.INK, 0.07))
	for i in line.size() - 1:
		AoDraw.dashed(self, line[i], line[i + 1], Color(Palette.INK, 0.25), 1.5, 5.0, 4.0)


func _draw_cursor(r: Rect2) -> void:
	var x := freq_to_x(cursor_freq)
	var y := db_to_y(cursor_db)
	var ce := cursor_ear if cursor_ear != "" else (ear if ear != "both" else "right")
	var col := Palette.ear_color(ce)
	draw_rect(Rect2(x - 11.0, r.position.y, 22.0, r.size.y), Color(Palette.SELECT_ORANGE, 0.16))
	AoDraw.dashed(self, Vector2(r.position.x, y), Vector2(r.end.x, y), Color(Palette.SELECT_ORANGE, 0.7), 2.0, 7.0, 5.0)
	draw_circle(Vector2(x, y), 15.0, Color(Palette.SELECT_ORANGE, 0.25))
	UiDraw.ear_symbol(self, Vector2(x, y), ce, 16.0, 3.0, false, Color(col, 0.5))
	var tag := "%d" % cursor_db
	var tw := AoDraw.text_size(tag, 13, AoDraw.FONT_BOLD).x + 12.0
	var tr := Rect2(Vector2(x + 16.0, y - 11.0), Vector2(tw, 20.0))
	if tr.end.x > r.end.x:
		tr.position.x = x - 16.0 - tw
	AoDraw.rbox(self, tr, Palette.SELECT_ORANGE, 8)
	AoDraw.text_c(self, tr.get_center(), tag, 13, Palette.PAPER, AoDraw.FONT_BOLD)


func _draw_ear(e: String) -> void:
	var pts: Dictionary = points.get(e, {})
	if pts.is_empty():
		return
	var col := Palette.ear_color(e)
	# ink splats under freshly stamped symbols
	for f: int in pts:
		var p: Dictionary = pts[f]
		var age := float(p["age"])
		if age >= STAMP_IN_S:
			var fade := clampf(1.0 - (age - STAMP_IN_S) / 0.6, 0.0, 1.0)
			AoDraw.splat(self, Vector2(freq_to_x(f), db_to_y(float(p["db"]))), 17.0, Color(col, 0.22 * fade), int(p["seed"]))
	# pen lines
	for k: String in _segments:
		if not k.begins_with(e + ":"):
			continue
		var parts := k.split(":")
		var f1 := int(parts[1])
		var f2 := int(parts[2])
		if not pts.has(f1) or not pts.has(f2):
			continue
		var a := Vector2(freq_to_x(f1), db_to_y(float(pts[f1]["db"])))
		var b := Vector2(freq_to_x(f2), db_to_y(float(pts[f2]["db"])))
		var prog: float = _segments[k] * _reveal
		if prog <= 0.0:
			continue
		var ia := a + (b - a).normalized() * 9.0
		var ib := b - (b - a).normalized() * 9.0
		if a.distance_to(b) < 20.0:
			continue
		var end := ia.lerp(ib, prog)
		draw_line(ia, end, Color(col, 0.9), 3.0, true)
		if prog < 1.0:
			draw_circle(end, 4.0, Palette.INK)
	# symbols
	for f: int in pts:
		var p: Dictionary = pts[f]
		var c := Vector2(freq_to_x(f), db_to_y(float(p["db"])))
		var age := float(p["age"])
		var s := 17.0 * stamp_scale(age)
		var bkey := "%s:%d" % [e, f]
		if _bounce.has(bkey):
			var k := float(_bounce[bkey]) / 0.35
			c.y -= sin(k * PI) * 12.0
			s *= 1.0 + 0.3 * sin(k * PI)
		if age >= 0.0 and age < STAMP_IN_S:
			draw_circle(c, s * 0.7, Color(col, 0.18))
		if age >= STAMP_IN_S and age < STAMP_IN_S + 0.4:
			var k2 := (age - STAMP_IN_S) / 0.4
			draw_arc(c, 12.0 + 26.0 * k2, 0.0, TAU, 32, Color(col, 0.6 * (1.0 - k2)), 3.0, true)
		UiDraw.ear_symbol(self, c + Vector2(1.5, 2.0), e, s, 4.0, bool(p["no_response"]), Color(Palette.INK, 0.25))
		UiDraw.ear_symbol(self, c, e, s, 4.0, bool(p["no_response"]))
