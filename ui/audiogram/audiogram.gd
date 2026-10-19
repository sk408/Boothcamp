class_name Audiogram
extends Control
## Audiogram: the reusable chart widget (builder A, CONTRACTS.md §4.6).
## Used by the AudiOtron screen (one card per ear) and by story/ for the reveal and evidence.
## Public API (keep stable):
##   ear                      "right", "left" or "both" (which points are drawn)
##   show_title               draws an ear title strip above the plot
##   set_point(ear, freq, db, no_response := false, animate := true, test := &"ac", no_plateau := false)
##   clear_points()
##   show_results(results, animate := false)   # results = CONTRACTS.md §5.1; emits draw_finished
##   set_cursor(freq, db, visible)
##   freq_to_x(freq) / db_to_y(db)             # local coordinates
##   get_point_global_position(ear, freq, test := &"ac") -> Vector2
##   get_region_global_rect(freq_lo, freq_hi, db_lo := -10, db_hi := 120) -> Rect2
##   signal draw_finished
## Extras (ui-internal): signal freq_clicked(freq), play_melody(ear), point_count(ear).
## Look: log-frequency axis 125 Hz - 8 kHz (octaves + inter-octaves), -10 dB at the top down to
## 120, a faint normal band and speech banana, shading beyond the AudiOtron's maximum output,
## ASHA symbols (right = red O, left = blue X, no response = arrow) that STAMP on with a
## hit-stop and an ink splat, and connecting lines drawn in like a pen.
## (v3) Bone and masked layers (test = &"bc" < >, &"bc_masked" [ ], &"ac_masked" triangle /
## square): a masked air symbol replaces the plain one at its frequency and the air line runs
## through it; a masked bone symbol replaces the unmasked one; bone symbols sit beside the
## frequency line and are never connected (ASHA).
## (Clinical review E9) A masked stamp stored with no plateau (the safe window filled first, or a
## masking dilemma) carries a small purple "?" badge: the true threshold may be poorer. A legend
## pill explains it when no other legend is showing.
## (v3, builder A) Three optional teaching overlays, all off by default (Day 1 never sets them):
##   attention    test -> ear -> freq -> true: those symbols BLINK with an amber halo ("masking
##                needed here", the masking assistant) and a legend pill appears
##   show_gap     the air-bone gap as a bridge: posts from bone up to air with the gap in dB where
##                it is over 10 dB (dashed and amber while the bone is unmasked: "suspicious";
##                solid orange on masked bone), a short cap on each post (bone marks are never joined)
##   masker_view  {} or {"freq", "db", "role": &"noise" | &"leak", "hot": bool}: on the masked
##                ear's chart a purple noise curtain down to the masker level "[35]"; on the test
##                ear's chart the noise leaking back (masker - rule IA), coral when it overmasks
## (v4, builder A) bone_range  ear -> freq -> [lo_db, hi_db]: the poorer ear's bone before it is
##                masked. Unmasked bone (from either mastoid) is the BETTER cochlea, so this ear's
##                cochlea sits somewhere between it (lo) and this ear's air (hi): a dashed, softly
##                blinking "?" capsule on the bone side of the frequency line ("mask to find it")

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
## (E9) The "plateau not reached" badge: the AudiOtron's masking-dilemma purple.
const NO_PLATEAU_COLOR := Color("#8e5cc4")

@export var ear: String = "right"
@export var show_title: bool = false
## Show the speech banana and degree labels (on by default; turn off for tiny charts).
@export var show_guides: bool = true

## ear -> freq -> {"db": int, "no_response": bool, "age": float (seconds since stamped, -1 = static), "seed": int}
var points: Dictionary = {"right": {}, "left": {}}
## (v3) The other tests: test -> ear -> freq -> the same point Dictionary.
var layers: Dictionary = {}
## (v3) The cursor ghost's symbol (the AudiOtron sets it to the current test).
var cursor_test: StringName = &"ac"
## (v3) Which maximum-output line to shade: &"phones" (air) or &"bone".
var max_output_transducer: StringName = &"phones"
## (v3) Masking assistant: test -> ear -> freq -> true (blinking symbols). See the header.
var attention: Dictionary = {}:
	set(v):
		attention = v
		queue_redraw()
## (v3) The air-bone gap bridge (see the header).
var show_gap: bool = false:
	set(v):
		if v != show_gap:
			show_gap = v
			queue_redraw()
## (v3) The masker on this chart (see the header).
var masker_view: Dictionary = {}:
	set(v):
		if v != masker_view:
			masker_view = v
			queue_redraw()
## (v4) ear -> freq -> [lo_db, hi_db]: the poorer ear's unknown bone (see the header). {} = off.
var bone_range: Dictionary = {}:
	set(v):
		if v != bone_range:
			bone_range = v
			queue_redraw()
## (Polish) ear -> alpha 0..1: fade one ear's line and symbols (the Day 2 board's bridge dims the
## left ear so the eye compares right air with right bone). {} = both at full strength.
var dim: Dictionary = {}:
	set(v):
		if v != dim:
			dim = v
			queue_redraw()
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
var _t := 0.0


func _ready() -> void:
	_font = AoDraw.FONT_SEMI
	resized.connect(queue_redraw)
	custom_minimum_size = custom_minimum_size.max(Vector2(240, 180))
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_exited.connect(func() -> void:
		_hover_freq = -1
		queue_redraw())


# ---------------------------------------------------------------- public API

func set_point(p_ear: String, freq: int, db: int, no_response: bool = false, animate: bool = true, test: StringName = &"ac", no_plateau: bool = false) -> void:
	var pt := {"db": db, "no_response": no_response, "age": 0.0 if animate else -1.0, "seed": freq * 7 + (1 if p_ear == "right" else 2),
		"no_plateau": no_plateau}
	if test != &"ac" and test != &"":
		_layer(test, p_ear)[freq] = pt
		if test == &"ac_masked":
			_refresh_segments(p_ear, freq, animate)  # the air line now runs through the masked level
		_animating = _animating or animate
		queue_redraw()
		return
	if not points.has(p_ear):
		points[p_ear] = {}
	var pts: Dictionary = points[p_ear]
	pts[freq] = pt
	_refresh_segments(p_ear, freq, animate)
	_animating = _animating or animate
	queue_redraw()


func clear_points() -> void:
	points = {"right": {}, "left": {}}
	layers.clear()
	_segments.clear()
	_bounce.clear()
	queue_redraw()


func point_count(p_ear: String, test: StringName = &"ac") -> int:
	if test != &"ac" and test != &"":
		return _layer(test, p_ear).size()
	return (points.get(p_ear, {}) as Dictionary).size()


func _layer(test: StringName, p_ear: String) -> Dictionary:
	if not layers.has(test):
		layers[test] = {"right": {}, "left": {}}
	var l: Dictionary = layers[test]
	if not l.has(p_ear):
		l[p_ear] = {}
	return l[p_ear]


## The air level the line runs through at f: masked where measured.
func _ac_db(p_ear: String, f: int) -> float:
	var m := _layer(&"ac_masked", p_ear)
	if m.has(f):
		return float(m[f]["db"])
	return float((points[p_ear][f] as Dictionary)["db"])


## The reveal's stamp order for queue entries [ear, freq, db, no_response, test]: by frequency,
## right ear first, then the order they were queued (air, masked air, bone, masked bone). Appends
## each entry's queue index so the order is strict: Day 2 has several marks per ear at one frequency.
static func sort_reveal(queue: Array) -> void:
	for i in queue.size():
		(queue[i] as Array).append(i)
	queue.sort_custom(reveal_before)


## The strict "stamps first" test behind sort_reveal (entries carry their queue index at [5]).
static func reveal_before(a: Array, b: Array) -> bool:
	if int(a[1]) != int(b[1]):
		return int(a[1]) < int(b[1])
	if String(a[0]) != String(b[0]):
		return String(a[0]) == "right"
	return int(a[5]) < int(b[5])


## Load every stored threshold from a results Dictionary (§5.1). animate = stamp them on one
## by one from low to high pitch with the lines drawing in, then emit draw_finished.
func show_results(results: Dictionary, animate: bool = false) -> void:
	clear_points()
	var ears: Dictionary = results.get("ears", {})
	var queue: Array = []
	var unsure := {}   # "ear:freq:test" -> true: masked stamps stored with no plateau (E9)
	for e: String in ears:
		for key: String in ["freqs", "ac_masked", "bc", "bc_masked"]:
			var freqs: Dictionary = (ears[e] as Dictionary).get(key, {})
			var fl: Array = freqs.keys()
			fl.sort()
			for f: int in fl:
				var info: Dictionary = freqs[f]
				var t: StringName = &"ac" if key == "freqs" else StringName(key)
				queue.append([e, f, int(info["stored_db"]), bool(info.get("no_response", false)), t])
				if bool(info.get("plateau_not_reached", false)):
					unsure["%s:%d:%s" % [e, f, t]] = true
	if not animate:
		for q: Array in queue:
			set_point(q[0], q[1], q[2], q[3], false, q[4], unsure.has("%s:%d:%s" % [q[0], q[1], q[4]]))
		_reveal = 1.0
		queue_redraw()
		draw_finished.emit.call_deferred()
		return
	_reveal = 1.0
	sort_reveal(queue)
	var t := create_tween()
	for q: Array in queue:
		t.tween_callback(func() -> void:
			set_point(q[0], q[1], q[2], q[3], true, q[4], unsure.has("%s:%d:%s" % [q[0], q[1], q[4]]))
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


func get_point_global_position(p_ear: String, freq: int, test: StringName = &"ac") -> Vector2:
	var pts: Dictionary = points.get(p_ear, {}) if test == &"ac" or test == &"" else _layer(test, p_ear)
	var db: float = float(pts[freq]["db"]) if pts.has(freq) else 0.0
	var off := UiDraw.symbol_offset(p_ear, test, 17.0)
	return get_global_transform_with_canvas() * (Vector2(freq_to_x(freq), db_to_y(db)) + off)


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
	_t += delta
	if not attention.is_empty() or not masker_view.is_empty() or not bone_range.is_empty():
		queue_redraw()  # blinking symbols, the wobbling noise curtain, the "?" bone range
	if not _animating:
		return
	var busy := false
	var sets: Array = [points]
	for t: StringName in layers:
		sets.append(layers[t])
	for set_: Dictionary in sets:
		for e: String in set_:
			for f: int in set_[e]:
				var p: Dictionary = set_[e][f]
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
	if not masker_view.is_empty() and StringName(masker_view.get("role", &"")) == &"noise":
		_draw_noise_curtain(r)
	if cursor_visible:
		_draw_cursor(r)
	if not masker_view.is_empty() and StringName(masker_view.get("role", &"")) == &"leak":
		_draw_leak(r)
	for e: String in ["right", "left"]:
		if ear != "both" and ear != e:
			continue
		if show_gap:
			_draw_gap(e)
		_draw_bone_range(e)
		_draw_ear(e)
	if _attention_count() > 0:
		_draw_attention_legend(r)
	elif _bone_range_count() > 0:
		_draw_bone_range_legend(r)
	elif _no_plateau_count() > 0:
		_draw_no_plateau_legend(r)
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
	var fs: Array[int] = ClinicRules.BC_FREQS if max_output_transducer == &"bone" else ClinicRules.AC_FREQS
	for f: int in fs:
		var p := Vector2(freq_to_x(f), minf(db_to_y(float(ClinicRules.max_db_for(f, max_output_transducer)) + 2.5), r.end.y - 1.0))
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
	UiDraw.audiogram_symbol(self, Vector2(x, y) + UiDraw.symbol_offset(ce, cursor_test, 16.0), ce, cursor_test, 16.0, 3.0, false, Color(col, 0.5))
	var tag := "%d" % cursor_db
	var tw := AoDraw.text_size(tag, 13, AoDraw.FONT_BOLD).x + 12.0
	var tr := Rect2(Vector2(x + 16.0, y - 11.0), Vector2(tw, 20.0))
	if tr.end.x > r.end.x:
		tr.position.x = x - 16.0 - tw
	AoDraw.rbox(self, tr, Palette.SELECT_ORANGE, 8)
	AoDraw.text_c(self, tr.get_center(), tag, 13, Palette.PAPER, AoDraw.FONT_BOLD)


func _draw_ear(e: String) -> void:
	var pts: Dictionary = points.get(e, {})
	_draw_layers(e)
	if pts.is_empty():
		return
	var fade_e := float(dim.get(e, 1.0))
	var col := Color(Palette.ear_color(e), fade_e)
	var masked_ac := _layer(&"ac_masked", e)
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
		var a := Vector2(freq_to_x(f1), db_to_y(_ac_db(e, f1)))
		var b := Vector2(freq_to_x(f2), db_to_y(_ac_db(e, f2)))
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
		if masked_ac.has(f):
			continue  # the masked symbol replaces it (_draw_layers)
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
		var blink := _blink(&"ac", e, f)
		if blink >= 0.0:
			_draw_halo(c, blink)
		var a := 1.0 if blink < 0.0 else 0.3 + 0.7 * blink
		UiDraw.ear_symbol(self, c + Vector2(1.5, 2.0), e, s, 4.0, bool(p["no_response"]), Color(Palette.INK, 0.25 * a * fade_e))
		UiDraw.ear_symbol(self, c, e, s, 4.0, bool(p["no_response"]), Color(col, a * fade_e))


## (v3) Masked air, unmasked bone and masked bone symbols (no connecting lines for bone).
func _draw_layers(e: String) -> void:
	var masked_bc := _layer(&"bc_masked", e)
	for test: StringName in [&"bc", &"bc_masked", &"ac_masked"]:
		var pts := _layer(test, e)
		var fade_l := float(dim.get(e, 1.0))
		var col := Color(Palette.ear_color(e), fade_l)
		for f: int in pts:
			if test == &"bc" and masked_bc.has(f):
				continue  # masked bone replaces unmasked bone at that frequency
			var p: Dictionary = pts[f]
			var age := float(p["age"])
			var s := 17.0 * stamp_scale(age)
			var c := Vector2(freq_to_x(f), db_to_y(float(p["db"]))) + UiDraw.symbol_offset(e, test, 17.0)
			if age >= STAMP_IN_S:
				var fade := clampf(1.0 - (age - STAMP_IN_S) / 0.6, 0.0, 1.0)
				AoDraw.splat(self, c, 15.0, Color(col, 0.22 * fade), int(p["seed"]) + 3)
			if age >= STAMP_IN_S and age < STAMP_IN_S + 0.4:
				var k2 := (age - STAMP_IN_S) / 0.4
				draw_arc(c, 12.0 + 26.0 * k2, 0.0, TAU, 32, Color(col, 0.6 * (1.0 - k2)), 3.0, true)
			var blink := _blink(test, e, f)
			if blink >= 0.0:
				_draw_halo(c, blink)
			var a := 1.0 if blink < 0.0 else 0.3 + 0.7 * blink
			UiDraw.audiogram_symbol(self, c + Vector2(1.5, 2.0), e, test, s, 4.0, bool(p["no_response"]), Color(Palette.INK, 0.25 * a * fade_l))
			UiDraw.audiogram_symbol(self, c, e, test, s, 4.0, bool(p["no_response"]), Color(col, a * fade_l))
			if bool(p.get("no_plateau", false)) and (age < 0.0 or age >= STAMP_IN_S):
				_draw_no_plateau_badge(c + Vector2(12.0, -12.0), fade_l)


# ---------------------------------------------------------------- v3 overlays (builder A)

## Blink phase 0..1 for a symbol the masking assistant flags, or -1 when it is not flagged.
func _blink(test: StringName, e: String, f: int) -> float:
	var by_ear: Dictionary = attention.get(test, {})
	if not (by_ear.get(e, {}) as Dictionary).has(f):
		return -1.0
	if bool(Game.settings.get("reduced_motion", false)):
		return 0.75
	return 0.5 + 0.5 * sin(_t * 6.5)


func _attention_count() -> int:
	var n := 0
	for t: Variant in attention:
		var by_ear: Dictionary = attention[t]
		for e: String in by_ear:
			if ear == "both" or e == ear:
				n += (by_ear[e] as Dictionary).size()
	return n


func _draw_halo(c: Vector2, k: float) -> void:
	draw_circle(c, 15.0 + 3.0 * k, Color(Palette.SELECT_ORANGE, 0.12 + 0.2 * k))
	draw_arc(c, 15.0 + 3.0 * k, 0.0, TAU, 28, Color(Palette.SELECT_ORANGE, 0.35 + 0.45 * k), 2.5, true)


## "blinking = mask me": the masking assistant's legend, bottom-left inside the plot. (polish) When
## only bone symbols blink it gives the reason too: the air-bone gap is 10 dB or more.
func _draw_attention_legend(r: Rect2) -> void:
	var txt := "blinking = needs masking"
	var bone_only := not attention.is_empty()
	for t: Variant in attention:
		if not ClinicRules.test_is_bone(StringName(t)):
			bone_only = false
	if bone_only:
		txt = "blinking = air-bone gap of 10+: mask it"
	var w := AoDraw.text_size(txt, 11, AoDraw.FONT_BOLD).x + 30.0
	var lr := Rect2(Vector2(r.position.x + 6.0, r.end.y - 26.0), Vector2(w, 20.0))
	AoDraw.rbox(self, lr, Color(Palette.PAPER, 0.92), 10, 2, Palette.SELECT_ORANGE)
	var k := 0.5 + 0.5 * sin(_t * 6.5)
	draw_circle(lr.position + Vector2(12, 10), 5.0, Color(Palette.SELECT_ORANGE, 0.4 + 0.6 * k))
	AoDraw.text_l(self, lr.position + Vector2(22, 10), txt, 11, Palette.INK, AoDraw.FONT_BOLD)


## The best bone of an ear on this chart: masked where stamped, else unmasked. freq -> [db, masked]
func _best_bone(e: String) -> Dictionary:
	var out := {}
	var un := _layer(&"bc", e)
	for f: int in un:
		if not bool(un[f]["no_response"]):
			out[f] = [int(un[f]["db"]), false]
	var m := _layer(&"bc_masked", e)
	for f: int in m:
		if not bool(m[f]["no_response"]):
			out[f] = [int(m[f]["db"]), true]
	return out


## The air-bone gap as a little bridge (see the header). Posts only where the gap is over 10 dB.
func _draw_gap(e: String) -> void:
	var bone := _best_bone(e)
	var air: Dictionary = points.get(e, {})
	var fl: Array = bone.keys()
	fl.sort()
	for f: int in fl:
		if not air.has(f) or bool((air[f] as Dictionary)["no_response"]):
			continue
		var a_db := _ac_db(e, f)
		var b_db := float((bone[f] as Array)[0])
		var masked := bool((bone[f] as Array)[1])
		var gap := int(a_db - b_db)
		if not ClinicRules.is_conductive_gap(gap):
			continue
		var x := freq_to_x(f)
		var top := Vector2(x, db_to_y(b_db) + 10.0)
		var bot := Vector2(x, db_to_y(a_db) - 12.0)
		if bot.y - top.y < 8.0:
			continue
		var col := Palette.SELECT_ORANGE if masked else Color(Palette.SELECT_ORANGE, 0.55)
		var band := Rect2(Vector2(x - 5.0, top.y), Vector2(10.0, bot.y - top.y))
		AoDraw.rbox(self, band, Color(Palette.SUNNY, 0.38 if masked else 0.16), 5)
		if masked:
			draw_line(top, bot, Color(col, 0.9), 2.0, true)
		else:
			AoDraw.dashed(self, top, bot, col, 2.0, 5.0, 4.0)
		var tag := "%d" % gap if masked else "%d?" % gap
		var tw := AoDraw.text_size(tag, 11, AoDraw.FONT_BOLD).x + 10.0
		var tr := Rect2(Vector2(x + 6.0, (top.y + bot.y) * 0.5 - 9.0), Vector2(tw, 18.0))
		AoDraw.rbox(self, tr, Palette.SELECT_ORANGE if masked else Color(Palette.PAPER, 0.95), 8, 0 if masked else 2, col)
		AoDraw.text_c(self, tr.get_center(), tag, 11, Palette.PAPER if masked else Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
		# (polish) a short cap per post, never a line along the bone marks (bone is never joined)
		draw_line(top + Vector2(-9.0, 0), top + Vector2(9.0, 0), Color(col, 0.9), 3.0, true)


## (v4) The poorer ear's unknown bone (bone_range): a dashed capsule from the unmasked bone (the
## better cochlea: the lowest this cochlea could be) down to this ear's air (bone is never poorer
## than air), on the bone side of the frequency line, with a "?" tag. It breathes softly.
func _draw_bone_range(e: String) -> void:
	var by_f: Dictionary = bone_range.get(e, {})
	if by_f.is_empty():
		return
	var k := 0.75 if bool(Game.settings.get("reduced_motion", false)) else 0.5 + 0.5 * sin(_t * 4.0)
	var col := Palette.SELECT_ORANGE
	var fade := float(dim.get(e, 1.0))
	for f: int in by_f:
		var span: Array = by_f[f]
		var lo := float(span[0])
		var hi := float(span[1])
		if hi - lo < 10.0:
			continue
		var x := freq_to_x(f) + UiDraw.symbol_offset(e, &"bc_masked", 17.0).x
		var top := db_to_y(lo)
		var bot := db_to_y(hi) - 11.0   # stop above the air mark
		if bot - top < 16.0:
			continue
		var w := 14.0
		AoDraw.rbox(self, Rect2(Vector2(x - w * 0.5, top - w * 0.5), Vector2(w, bot - top + w)), Color(Palette.SUNNY, (0.18 + 0.14 * k) * fade), 7)
		var lc := Color(col, (0.5 + 0.4 * k) * fade)
		for sx: float in [-w * 0.5, w * 0.5]:
			AoDraw.dashed(self, Vector2(x + sx, top), Vector2(x + sx, bot), lc, 2.0, 5.0, 4.0)
		draw_arc(Vector2(x, top), w * 0.5, PI, TAU, 10, lc, 2.0, true)
		draw_arc(Vector2(x, bot), w * 0.5, 0.0, PI, 10, lc, 2.0, true)
		var c := Vector2(x, (top + bot) * 0.5)
		draw_circle(c, 10.0 + 1.5 * k, Color(Palette.PAPER, fade))
		draw_arc(c, 10.0 + 1.5 * k, 0.0, TAU, 24, Color(col, fade), 2.5, true)
		AoDraw.text_c(self, c + Vector2(0, 1), "?", 15, Color(col.darkened(0.15), fade), AoDraw.FONT_BOLD)


func _bone_range_count() -> int:
	var n := 0
	for e: String in bone_range:
		if ear == "both" or e == ear:
			n += (bone_range[e] as Dictionary).size()
	return n


## "? = bone unknown: mask to find it", bottom-left inside the plot (like the assistant's legend).
func _draw_bone_range_legend(r: Rect2) -> void:
	var txt := "? = bone hiding here: mask to find it"
	var w := AoDraw.text_size(txt, 11, AoDraw.FONT_BOLD).x + 30.0
	var lr := Rect2(Vector2(r.position.x + 6.0, r.end.y - 26.0), Vector2(w, 20.0))
	AoDraw.rbox(self, lr, Color(Palette.PAPER, 0.92), 10, 2, Palette.SELECT_ORANGE)
	draw_circle(lr.position + Vector2(12, 10), 6.0, Palette.PAPER)
	draw_arc(lr.position + Vector2(12, 10), 6.0, 0.0, TAU, 16, Palette.SELECT_ORANGE, 2.0, true)
	AoDraw.text_c(self, lr.position + Vector2(12, 10.5), "?", 10, Palette.SELECT_ORANGE, AoDraw.FONT_BOLD)
	AoDraw.text_l(self, lr.position + Vector2(22, 10), txt, 11, Palette.INK, AoDraw.FONT_BOLD)


## (E9) The "plateau not reached" badge beside a masked symbol: a purple disc with a "?".
func _draw_no_plateau_badge(c: Vector2, fade: float) -> void:
	draw_circle(c, 7.5, Color(Palette.PAPER, fade))
	draw_circle(c, 6.5, Color(NO_PLATEAU_COLOR, fade))
	AoDraw.text_c(self, c + Vector2(0, 0.5), "?", 10, Color(Palette.PAPER, fade), AoDraw.FONT_BOLD)


func _no_plateau_count() -> int:
	var n := 0
	for t: StringName in [&"bc_masked", &"ac_masked"]:
		for e: String in ["right", "left"]:
			if ear != "both" and e != ear:
				continue
			for f: int in _layer(t, e):
				if bool((_layer(t, e)[f] as Dictionary).get("no_plateau", false)):
					n += 1
	return n


## "? = no plateau: the true threshold may be poorer", bottom-left inside the plot.
func _draw_no_plateau_legend(r: Rect2) -> void:
	var txt := "? = no plateau: true threshold may be poorer"
	var w := AoDraw.text_size(txt, 11, AoDraw.FONT_BOLD).x + 30.0
	var lr := Rect2(Vector2(r.position.x + 6.0, r.end.y - 26.0), Vector2(w, 20.0))
	AoDraw.rbox(self, lr, Color(Palette.PAPER, 0.92), 10, 2, NO_PLATEAU_COLOR)
	_draw_no_plateau_badge(lr.position + Vector2(12, 10), 1.0)
	AoDraw.text_l(self, lr.position + Vector2(22, 10), txt, 11, Palette.INK, AoDraw.FONT_BOLD)


## The masked ear's chart: a purple noise curtain at the test frequency down to the masker level.
func _draw_noise_curtain(r: Rect2) -> void:
	var f := int(masker_view.get("freq", 1000))
	var db := float(masker_view.get("db", 0))
	var x := freq_to_x(f)
	var y0 := r.position.y
	var y1 := clampf(db_to_y(db), r.position.y, r.end.y)
	var w := 34.0
	var col := Palette.PLUM
	if y1 > y0 + 2.0:
		draw_rect(Rect2(Vector2(x - w * 0.5, y0), Vector2(w, y1 - y0)), Color(col, 0.16))
		# hissy wavy bottom edge and static specks: it's noise
		var pts := PackedVector2Array()
		for i in 9:
			var px := x - w * 0.5 + w * i / 8.0
			pts.append(Vector2(px, y1 + sin(_t * 18.0 + i * 1.9) * 2.5))
		draw_polyline(pts, Color(col, 0.85), 3.0, true)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 12.0)
		for i in 10:
			var sp := Vector2(x + rng.randf_range(-w * 0.45, w * 0.45), rng.randf_range(y0 + 4.0, y1 - 4.0))
			draw_circle(sp, 1.6, Color(col, 0.5))
	var tag := "[%d]" % int(db)
	var tw := AoDraw.text_size(tag, 13, AoDraw.FONT_BOLD).x + 12.0
	var tr := Rect2(Vector2(x + w * 0.5 + 3.0, y1 - 10.0), Vector2(tw, 20.0))
	if tr.end.x > r.end.x:
		tr.position.x = x - w * 0.5 - 3.0 - tw
	AoDraw.rbox(self, tr, col, 9)
	AoDraw.text_c(self, tr.get_center(), tag, 13, Palette.PAPER, AoDraw.FONT_BOLD)


## The test ear's chart: how loud the masker is by the time it leaks back across the head
## (masker - the rule IA). Coral when it reaches what we are measuring: overmasking.
func _draw_leak(r: Rect2) -> void:
	var f := int(masker_view.get("freq", 1000))
	var db := float(masker_view.get("db", 0))
	if db < float(DB_TOP):
		return
	var hot := bool(masker_view.get("hot", false))
	var x := freq_to_x(f)
	var y := db_to_y(db)
	var col := Palette.CORAL if hot else Color(Palette.PLUM, 0.75)
	var half := 26.0
	var pts := PackedVector2Array()
	for i in 11:
		var px := x - half + 2.0 * half * i / 10.0
		pts.append(Vector2(px, y + sin(_t * 14.0 + i * 1.3) * 2.0))
	draw_polyline(pts, col, 3.0 if hot else 2.0, true)
	var tag := "TOO MUCH!" if hot else "leak"
	var tw := AoDraw.text_size(tag, 10, AoDraw.FONT_BOLD).x
	var lx := x + half + 4.0
	if lx + tw > r.end.x - 2.0:
		lx = x - half - 4.0 - tw
	AoDraw.text_l(self, Vector2(lx, y), tag, 10, col, AoDraw.FONT_BOLD)
