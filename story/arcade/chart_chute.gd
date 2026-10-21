extends Control
## ChartChute (arcade, story-internal): the Chart Chute arcade mode (docs/ARCADE.md). Audiograms ride
## a belt; drop each one down the chute whose picture it looks like (SLOPE, NOTCH, COOKIE BITE,
## RISING, REVERSE BITE) as fast as you can read them. A run is three untimed warm-up charts, then 60 seconds where
## the next chart arrives the moment you sort one. A wrong drop jams the belt, shows the tell and
## sends the chart back three cards later; HOOT HELP shows the tell and sorts it for no points but
## keeps the streak. Every chart is labelled by ChartDeck.shape_of (ClinicRules.classify_shape plus
## the reverse cookie bite).
## Controls: keys 1-5 or click a chute; H or the HOOT HELP button; on the results, Enter or Space
## plays again and T goes back to the arcade hall. A key pressed while a chart is still sliding in is
## kept for a moment and used once it lands. Pausable game time throughout.
## The playfield is 1280x720, centred in wider or taller windows; the wall, floor and belt fill the
## rest. Story charts only ride the belt once their patient's Day is finished (ChartDeck.golden_pool).
## Beats (CONTRACTS.md §3.2): "chute_sort" (solver: the right chute; mouse: click "chute_<shape>"),
## "arcade_initials" (solver: enter BOT; mouse: click "arcade_initials_ok"), "arcade_results"
## (solver: back to the arcade hall). Never a visit: no Game.begin_visit, finish_visit or medals.
## Set seed_value (and autostart = false to drive it by hand) before adding it to the tree.
## belt = &"types" makes it AIR & BONE (air_bone.tscn, docs/ARCADE.md section 17): each chart shows
## one ear's air and bone, and the three chutes are SENSORINEURAL, CONDUCTIVE and MIXED
## (ClinicRules.hearing_type); its own board and runs under MODE_TYPES, no story charts.

signal _sorted(pick: StringName)

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const CasePortraits := preload("res://story/case_portraits.gd")
const ChartDeck := preload("res://story/arcade/chart_deck.gd")
const ChuteRules := preload("res://story/arcade/chute_rules.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const ArcadeArt := preload("res://story/arcade/arcade_art.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"
const HALL_SCENE := "res://story/arcade/arcade_hall.tscn"
const MODE := "chart_chute"
const MODE_TYPES := "chart_chute_types"

const FIELD := Vector2(1280, 720)
const TOP_H := 82.0
const CARD_RECT := Rect2(330, 92, 560, 368)
const PREVIEW_RECT := Rect2(912, 104, 352, 240)
const CHUTE_Y := 506.0
const CHUTE_SIZE := Vector2(250, 200)
## The patient's line after a right drop sits in the strip between the belt and the chutes.
const LINE_Y := 488.0
## Points float up in the empty corner under the NEXT card, clear of the chart and the streak.
const POINTS_AT := Vector2(1090, 404)
const CHUTE_GAP := 20.0
const CHUTE_MARGIN := 20.0   ## the least room left and right of the chute row
const HOOT_HINT := Rect2(16, 96, 300, 150)
## A key pressed this long before the chart is ready still counts (input buffer).
const BUFFER_S := 0.35
## The wait before a newly arrived chart takes a key.
const SETTLE_S := 0.2
## The results ignore keys this long after their buttons appear (the Enter that closed the
## initials must not also start a new run).
const RESULTS_KEY_GUARD_S := 0.3
const BELT := Color("#3b3550")
const FLOOR := Color("#e9d8c0")
const WALL := Color("#f7e7cf")
const TOP_BAND := Color("#2e2442")
const GOLD := Color("#f2b632")
## Hoot on the first two warm-up charts (a slope, then a notch), pointing at the right chute.
const WARMUP_HINTS: Dictionary = {
	&"sloping": "Drop each chart down the chute it matches. This one slopes down: SLOPE!",
	&"notch": "This one dips at 4k and comes back up: NOTCH!",
	&"sensorineural": "Each chart shows air AND bone. Here bone sits right on air: SENSORINEURAL!",
	&"conductive": "Bone is normal, but air is way down. A gap: CONDUCTIVE!",
}

var seed_value := -1
var autostart := true
## &"shapes" (Chart Chute) or &"types" (AIR & BONE): a key of ChartDeck.BELTS.
@export var belt: StringName = &"shapes"

var _ids: Array = ChartDeck.SHAPES   # the chutes, in key order
var _mode := MODE                    # the save key (ArcadeScores)

var _rng := RandomNumberGenerator.new()
var _phase := "intro"          # intro, warmup, countdown, run, tally, results
var _t := -1.0                 # seconds into the 60 s run (< 0 before it starts)
var _waiting := false          # a chart sits at the reading spot, waiting for a chute
var _busy := false             # a drop, jam or HOOT HELP is playing
var _pending: StringName = &"" # a key pressed while busy or sliding in (BUFFER_S)
var _pending_at := 0.0
var _score := 0
var _shown_score := 0.0
var _streak := 0
var _best_streak := 0
var _right := 0
var _oops := 0
var _helps := 0
var _cards := 0
var _serial := 0
var _beat_serial := 0
var _recent: Array = []
var _golden_left: Array = []
var _golden_seen := ""
var _next: Dictionary = {}
var _requeue: Array[Dictionary] = []   # [{"card", "due"}]
var _card: Dictionary = {}
var _said := {}
var _shots := {}
var _shot_queue: PackedStringArray = []
var _results_keys_at := -1.0   # Game.clock when the results buttons took keys (< 0: not yet)
var _again_btn: Button
var _back_btn: Button

var _bg: Control
var _field: Control             # the 1280x720 playfield, centred in the window
var _fields: Array[Control] = []
var _top: Control
var _side: Control
var _views: Array[CardView] = []
var _view_i := 0
var _preview: Control
var _chutes: Dictionary[StringName, ChuteView] = {}
var _help_btn: Button
var _lines: Control
var _banner: Label
var _banner_tw: Tween
var _banner_pop: Tween
var _results: Control


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


# ================================================================ card, chute and preview views

## One chart card: the patient, the ear tag and a real Audiogram; the tell glows over the chart.
class CardView extends Control:
	var card: Dictionary = {}
	var ag: Audiogram
	var tell: StringName = &""
	var tell_t := 0.0
	var ear_cue := false          # a two-ear card sorted by the other ear's shape
	var motion: Tween             # the card's one running move (slide, drop, nudge, fade)
	var _over: Control
	var _font: Font

	func _init() -> void:
		size = CARD_RECT.size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_font = UiKit.font(700)

	func setup() -> void:
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Audiogram
		ag.show_guides = false
		ag.show_title = false
		ag.position = Vector2(14, 74)
		ag.size = Vector2(size.x - 28, size.y - 88)
		add_child(ag)
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE   # after add_child: Audiogram._ready sets PASS
		_over = UiKit.full_rect()
		_over.draw.connect(_draw_tell)
		add_child(_over)

	## A fresh tween for the card's next move; the last one stops, so two moves never fight.
	func move() -> Tween:
		if motion != null and motion.is_valid():
			motion.kill()
		motion = create_tween()
		return motion

	func show_card(c: Dictionary) -> void:
		card = c
		tell = &""
		ear_cue = false
		ag.ear = String(c["ear"]) if String(c["ear"]) != "" else "both"
		ag.clear_points()
		for ear: String in (c["ac"] as Dictionary):
			var t: Dictionary = c["ac"][ear]
			for f: int in t:
				ag.set_point(ear, f, int(t[f]), false, false)
		for ear: String in (c.get("bc", {}) as Dictionary):
			var b: Dictionary = c["bc"][ear]
			var masked: Dictionary = (c.get("bc_masked", {}) as Dictionary).get(ear, {})
			for f: int in b:
				ag.set_point(ear, f, int(b[f]), false, false, &"bc_masked" if masked.has(f) else &"bc")
		ag.show_gap = false
		ag.dim = {}
		if String(c["ear"]) == "both":
			ag.dim = {("left" if String(c["sort_ear"]) == "right" else "right"): 0.45}
		queue_redraw()
		_over.queue_redraw()

	func show_tell(shape: StringName, other_ear := false) -> void:
		tell = shape
		tell_t = 0.0
		# an air-and-bone card's tell bridges the gaps, where there are any
		ag.show_gap = shape != &"" and card.has("bc")
		ear_cue = other_ear and shape != &""
		_over.queue_redraw()

	func _process(delta: float) -> void:
		if tell != &"":
			tell_t += delta
			_over.queue_redraw()
		if bool(card.get("golden", false)) and not bool(Game.settings.get("reduced_motion", false)):
			queue_redraw()

	func _tag_text() -> String:
		var ear := String(card.get("ear", "right"))
		var sort_ear := String(card.get("sort_ear", "right"))
		if ear == "right":
			return "RIGHT EAR  O"
		if ear == "left":
			return "LEFT EAR  X"
		return "SORT THE RED  O" if sort_ear == "right" else "SORT THE BLUE  X"

	func _tag_rect() -> Rect2:
		var tw := _font.get_string_size(_tag_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 28
		return Rect2(size.x - tw - 16, 18, tw, 38)

	func _draw() -> void:
		if card.is_empty():
			return
		var golden := bool(card.get("golden", false))
		var r := Rect2(Vector2.ZERO, size)
		UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, 8), r.size), Color(Palette.INK, 0.25), 22)
		UiDraw.rounded_rect(self, r, Palette.PAPER, 22, 5, GOLD if golden else Palette.INK)
		if golden:
			var glow := 0.5
			if not bool(Game.settings.get("reduced_motion", false)):
				glow = 0.5 + 0.5 * sin(Game.clock * 1000.0 / 260.0)
			draw_rect(r.grow(-9), Color(GOLD, 0.25 + 0.25 * glow), false, 4.0)
		var who := String(card.get("who", ""))
		Portraits.draw(self, who, Vector2(48, 40), 26.0, false, false, true)
		draw_string(_font, Vector2(86, 34), String(card.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, 250, 22, Palette.INK)
		draw_string(UiKit.font(500), Vector2(86, 58), "Lower on the chart = harder to hear", HORIZONTAL_ALIGNMENT_LEFT, 260, 14, Palette.INK_SOFT)
		var tag := _tag_rect()
		UiDraw.rounded_rect(self, tag, Palette.ear_color(String(card.get("sort_ear", "right"))), 19)
		draw_string(_font, tag.position + Vector2(14, 27), _tag_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.PAPER)
		if golden:
			var g := "STORY CHART  x%d" % ChuteRules.GOLDEN_FACTOR
			var gw := _font.get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 24
			UiDraw.rounded_rect(self, Rect2(size.x * 0.5 - gw * 0.5, -16, gw, 32), GOLD, 16, 3, Palette.INK)
			draw_string(_font, Vector2(size.x * 0.5 - gw * 0.5 + 12, 6), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)

	func _draw_tell() -> void:
		if tell == &"" or ag == null:
			return
		var steady := bool(Game.settings.get("reduced_motion", false))
		var info: Dictionary = ChartDeck.TELLS[tell]
		var gr := ag.get_region_global_rect(int(info["freq_lo"]), int(info["freq_hi"]))
		var inv := _over.get_global_transform_with_canvas().affine_inverse()
		var rr := Rect2(inv * gr.position, inv.basis_xform(gr.size)).abs()
		var pulse := 0.6 if steady else 0.5 + 0.5 * sin(tell_t * 9.0)
		_over.draw_rect(rr, Color(Palette.SUNNY, 0.18 + 0.14 * pulse))
		_over.draw_rect(rr, Color(Palette.SELECT_ORANGE, 0.7 + 0.3 * pulse), false, 4.0)
		# the caption names the chute, then where to look ("NOTCH: Dips at 3-6k, ...")
		var cap := "%s: %s" % [ChartDeck.CHUTE_WORDS[tell], String(info["text"])]
		var fs := 20
		var cw := _font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30
		while cw > size.x - 20 and fs > 14:
			fs -= 1
			cw = _font.get_string_size(cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30
		var at := Vector2(clampf(rr.get_center().x - cw * 0.5, 10, size.x - cw - 10), size.y - 54)
		UiDraw.rounded_rect(_over, Rect2(at, Vector2(cw, 40)), Palette.SUNNY, 20, 3, Palette.INK)
		_over.draw_string(_font, at + Vector2(15, 20 + fs * 0.4), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
		if tell == &"notch":
			# the up-arrow at 8k: "comes back up"
			var x := inv * Vector2(ag.get_global_transform_with_canvas() * Vector2(ag.freq_to_x(8000), 0))
			UiDraw.arrow(_over, Vector2(x.x, rr.position.y + rr.size.y * 0.35), 26.0, Vector2.UP, Palette.CORAL)
		if ear_cue:
			# the other ear has the shape that was picked: the tag flashes and says which colour to
			# sort (drawn over the tag row, so the chart's frequency labels stay clear)
			var tag := _tag_rect()
			var sort_ear := String(card.get("sort_ear", "right"))
			var say := "Other ear! Sort the %s" % ("RED O" if sort_ear == "right" else "BLUE X")
			var sw := maxf(_font.get_string_size(say, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 28, tag.size.x)
			var cue := Rect2(Vector2(tag.end.x - sw, tag.position.y), Vector2(sw, tag.size.y))
			var on := steady or fmod(tell_t, 0.5) < 0.3
			UiDraw.rounded_rect(_over, cue, Palette.CORAL if on else Palette.ear_color(sort_ear), 19, 3, Palette.INK)
			_over.draw_string(_font, cue.position + Vector2(14, 26), say, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.PAPER)


## One chute: its picture and word, its key, locked until its time, and the gag when a chart lands.
class ChuteView extends Control:
	signal picked(shape: StringName)
	var shape: StringName
	var key := 1
	var locked := false
	var pulse := false
	var gag_t := -1.0
	var line := ""
	var line_t := -1.0
	var flash := 0.0
	var _hover := false
	var _font: Font

	func _init(s: StringName, k: int) -> void:
		shape = s
		key = k
		size = CHUTE_SIZE
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_font = UiKit.font(700)
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(shape)
			accept_event()

	func play_gag(say: String) -> void:
		gag_t = 0.0
		line = say
		line_t = 0.0

	func _process(delta: float) -> void:
		var animating := pulse or gag_t >= 0.0 or line_t >= 0.0 or flash > 0.0
		if gag_t >= 0.0:
			gag_t += delta / 0.8
			if gag_t > 1.0:
				gag_t = -1.0
		if line_t >= 0.0:
			line_t += delta / 1.6
			if line_t > 1.0:
				line_t = -1.0
		flash = maxf(0.0, flash - delta * 2.5)
		if animating:
			queue_redraw()

	## The shape as a tiny chart (lower = harder to hear), so the picture links to the line.
	func _draw_mini_chart(box: Rect2) -> void:
		UiDraw.rounded_rect(self, box, Palette.PAPER, 8)
		# the normal band (25 dB HL and better), as on the big chart
		draw_rect(Rect2(box.position + Vector2(4, 3), Vector2(box.size.x - 8, 2 + (box.size.y - 10) * 25.0 / 70.0)), Color(Palette.MINT, 0.25))
		var typed := ChartDeck.TYPES.has(shape)
		var dbs: Array = ChartDeck.TYPE_ARCH[shape]["plain"][0][0] if typed else ChartDeck.ARCH[shape]["plain"][0]
		var pts := PackedVector2Array()
		for i in dbs.size():
			var x := box.position.x + 10 + (box.size.x - 20) * i / float(dbs.size() - 1)
			var y := box.position.y + 5 + (box.size.y - 10) * clampf(float(dbs[i]) / 70.0, 0.0, 1.0)
			pts.append(Vector2(x, y))
		draw_polyline(pts, Palette.INK, 3.0, true)
		for p: Vector2 in pts:
			draw_circle(p, 2.5, Palette.INK)
		if typed:
			# the bone marks, as little < carets left of the air line
			var bone: Array = ChartDeck.TYPE_ARCH[shape]["plain"][0][1]
			for i in ChartDeck.BONE_FREQS.size():
				var p := pts[ChartDeck.FREQS.find(ChartDeck.BONE_FREQS[i])]
				var y := box.position.y + 5 + (box.size.y - 10) * clampf(float(bone[i]) / 70.0, 0.0, 1.0)
				var tip := Vector2(p.x - 7, y)
				draw_polyline(PackedVector2Array([tip + Vector2(5, -4), tip, tip + Vector2(5, 4)]), Palette.SELECT_ORANGE, 2.5, true)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lift := -4.0 if _hover and not locked else 0.0
		UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, 8), r.size), Color(Palette.INK, 0.3), 26)
		UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, lift), r.size), Color("#4a4363"), 26, 5, Palette.INK)
		# the hopper mouth
		var mouth := Rect2(18, 14 + lift, size.x - 36, size.y - 74)
		UiDraw.rounded_rect(self, mouth, Color("#2b2440"), 18)
		var c := mouth.position + Vector2(mouth.size.x * 0.5, 40)
		if gag_t >= 0.0:
			ArcadeArt.gag(self, shape, c, 46.0, gag_t)
		else:
			ArcadeArt.picture(self, shape, c, 46.0)
		_draw_mini_chart(Rect2(mouth.position.x + 26, mouth.end.y - 42, mouth.size.x - 52, 36))
		var word := ChartDeck.CHUTE_WORDS[shape]
		var fs := 28
		while fs > 18 and _font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - 16:
			fs -= 1
		draw_string(_font, Vector2(0, size.y - 22 + lift), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Palette.PAPER)
		# the key chip
		UiDraw.rounded_rect(self, Rect2(8, 6 + lift, 34, 34), Palette.SUNNY, 10, 3, Palette.INK)
		draw_string(_font, Vector2(8, 32 + lift), str(key), HORIZONTAL_ALIGNMENT_CENTER, 34, 22, Palette.INK)
		if pulse:
			var p := 0.7
			if not bool(Game.settings.get("reduced_motion", false)):
				p = 0.5 + 0.5 * sin(Game.clock * 1000.0 / 140.0)
			draw_rect(r.grow(4.0 + 4.0 * p), Color(Palette.SUNNY, 0.6 + 0.4 * p), false, 6.0)
		if flash > 0.0:
			draw_rect(r, Color(Palette.MINT, flash * 0.5))
		if locked:
			UiDraw.rounded_rect(self, r, Color(Palette.INK, 0.72), 26)
			draw_string(_font, Vector2(0, size.y * 0.5 + 10), "SOON", HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color(Palette.PAPER, 0.8))

	## The patient's line, drawn by the scene's top layer (over the belt, under nothing).
	func draw_line_bubble(ci: CanvasItem) -> void:
		if line_t < 0.0 or line == "":
			return
		var a := clampf((1.0 - line_t) * 3.0, 0.0, 1.0)
		var lw := _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 26
		var cx := clampf(position.x + size.x * 0.5, lw * 0.5 + 8.0, FIELD.x - 8.0 - lw * 0.5)
		var at := Vector2(cx - lw * 0.5, LINE_Y - 17)
		UiDraw.rounded_rect(ci, Rect2(at, Vector2(lw, 34)), Color(Palette.PAPER, a), 17, 3, Color(Palette.INK, a))
		ci.draw_string(_font, at + Vector2(13, 23), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.INK, a))


# ================================================================ lifecycle

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = seed_value if seed_value >= 0 else Game.rng.randi()
	_ids = ChartDeck.BELTS[belt]
	_mode = MODE_TYPES if belt == &"types" else MODE
	_build()
	Hoot.clear()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if autostart:
		_run.call_deferred()


func _exit_tree() -> void:
	Hoot.clear_bubble_hint()
	Hoot.clear()
	for s: StringName in _ids:
		Hoot.unregister_anchor("chute_" + String(s))
	Hoot.unregister_anchor("chute_help")
	Hoot.unregister_anchor("arcade_initials_ok")


func demo_start() -> void:
	pass  # starts itself in _ready (also when reached from the title)


## Centre the playfield (and the results card) in the window; the background fills the rest.
func _layout() -> void:
	var vp := get_viewport_rect().size
	var off := ((vp - FIELD) * 0.5).floor()
	off = Vector2(maxf(off.x, 0.0), maxf(off.y, 0.0))
	for f: Control in _fields:
		if is_instance_valid(f):
			f.position = off
	Hoot.set_bubble_hint(Rect2(HOOT_HINT.position + off, HOOT_HINT.size))
	_bg.queue_redraw()


func _process(delta: float) -> void:
	if _phase == "run":
		_t += delta
		if _t >= ChuteRules.RUN_S:
			_t = ChuteRules.RUN_S
			_phase = "tally"
			_preview.queue_redraw()   # the NEXT card leaves the belt with the clock
			if _waiting:
				_sorted.emit(&"")
		_refresh_locks()
	if absf(_shown_score - _score) > 0.5:
		_shown_score = move_toward(_shown_score, _score, maxf(40.0, absf(_score - _shown_score) * 6.0) * delta)
	else:
		_shown_score = _score
	_top.queue_redraw()
	_side.queue_redraw()
	if _phase == "run":
		_bg.queue_redraw()   # the belt rollers turn while the clock runs
	_lines.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	if _phase == "results":
		if _results_keys_at < 0.0 or Game.clock - _results_keys_at < RESULTS_KEY_GUARD_S:
			return
		if code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
			_results_keys_at = -1.0   # once: a second press never starts a second scene change
			_again_btn.pressed.emit()
			get_viewport().set_input_as_handled()
		elif code == KEY_T:
			_results_keys_at = -1.0
			_back_btn.pressed.emit()
			get_viewport().set_input_as_handled()
		return
	var digit := code
	if (digit < KEY_1 or digit > KEY_9) and (digit < KEY_KP_1 or digit > KEY_KP_9):
		digit = k.physical_keycode   # AZERTY and friends: the digit row by position
	var n := _ids.size()
	if digit >= KEY_1 and digit < KEY_1 + n:
		sort_into(_ids[digit - KEY_1])
		get_viewport().set_input_as_handled()
	elif digit >= KEY_KP_1 and digit < KEY_KP_1 + n:
		sort_into(_ids[digit - KEY_KP_1])
		get_viewport().set_input_as_handled()
	elif code == KEY_H:
		press_help()
		get_viewport().set_input_as_handled()


## Drop the waiting chart down a chute (keys, clicks and the solver all come here). A locked chute
## shakes; a press while the chart is still landing is kept for BUFFER_S.
func sort_into(shape: StringName) -> void:
	if not _chutes.has(shape):
		return
	if _chutes[shape].locked:
		if _phase == "warmup" or _phase == "run":
			Juice.shake(_chutes[shape], 5.0, 0.2)
			Sfx.play(&"click", 0.7, -10.0)
		return
	if not _waiting or _busy:
		_buffer(shape)
		return
	_waiting = false
	_sorted.emit(shape)


func press_help() -> void:
	if not _waiting or _busy:
		_buffer(&"help")
		return
	_waiting = false
	_sorted.emit(&"help")


func _buffer(pick: StringName) -> void:
	if _phase == "warmup" or _phase == "run":
		_pending = pick
		_pending_at = Game.clock


## (deferred, once a chart is waiting) Use a key pressed a moment before it was ready.
func _apply_pending() -> void:
	var p := _pending
	_pending = &""
	if p == &"" or Game.clock - _pending_at > BUFFER_S or not _waiting or _busy:
		return
	if p == &"help":
		press_help()
	else:
		sort_into(p)


## The tally so far (the check scene and the results card read it).
func stats() -> Dictionary:
	return {"right": _right, "oops": _oops, "helps": _helps, "score": _score, "best_streak": _best_streak,
		"cards": _cards, "accuracy": snappedf(ChuteRules.accuracy(_right, _oops), 0.001), "golden": _golden_seen,
		"fluent": ChuteRules.fluent(_right, _oops), "rank": ChuteRules.rank(_right, _oops), "phase": _phase}


# ================================================================ the run

func _run() -> void:
	Sfx.music_start()
	_phase = "warmup"
	var warm: Array = [_ids[0], _ids[1], _ids[1] if _rng.randf() < 0.5 else _ids[0]]
	for i in ChuteRules.WARMUP_CARDS:
		await _serve(ChartDeck.make_card(_rng, warm[i], {"ear": "right"}, _next_serial()), i < 2)
	_phase = "countdown"
	await _countdown()
	_pending = &""   # a key mashed during the countdown is not a read
	_phase = "run"
	_t = 0.0
	# story charts: only patients whose Day is finished, and the ones not found yet first
	_golden_left = ChartDeck.golden_pool(ArcadeScores.found(_mode)) if belt == &"shapes" else []
	_next = _deal()
	while _phase == "run":
		var c := _next
		_next = _deal()   # one ahead, so the NEXT card up the belt is the real next chart
		await _serve(c, false)
	await _tally()


func _next_serial() -> int:
	_serial += 1
	return _serial


func _push_recent(shape: StringName) -> void:
	_recent.append(shape)
	if _recent.size() > 4:
		_recent.pop_front()


## The next chart: a sent-back one when it is due (held a card if it would make three of a shape
## running), otherwise a fresh one for this point of the run.
func _deal() -> Dictionary:
	for r: Dictionary in _requeue:
		r["due"] = int(r["due"]) - 1
	for i in _requeue.size():
		if int(_requeue[i]["due"]) > 0:
			continue
		var back: Dictionary = _requeue[i]["card"]
		if _recent.size() >= 2 and _recent[-1] == back["shape"] and _recent[-2] == back["shape"]:
			continue
		_requeue.remove_at(i)
		_push_recent(back["shape"])
		return back
	var spec := ChuteRules.next_spec(_rng, _t, _recent, _golden_left, belt)
	var card: Dictionary = {}
	if bool(spec["golden"]):
		card = ChartDeck.golden_card(spec["shape"], _next_serial())
		_golden_left = []
	if card.is_empty():
		card = ChartDeck.make_card(_rng, spec["shape"], {"ear": spec["ear"] if String(spec["ear"]) != "" else "right", "lookalike": spec["lookalike"]}, _next_serial())
	_push_recent(card["shape"])
	return card


## A chute just opened: its first chart is the NEXT one, as the banner says. The card that was
## waiting up the belt goes back (a sent-back chart comes round straight after).
func _meet_new_chute(s: StringName) -> void:
	if _next.is_empty() or bool(_next.get("golden", false)) or _next["shape"] == s:
		return
	if bool(_next.get("requeued", false)):
		_requeue.append({"card": _next, "due": 1})
	if not _recent.is_empty() and _recent[-1] == _next["shape"]:
		_recent.pop_back()
	_next = ChartDeck.make_card(_rng, s, {"ear": "right"}, _next_serial())
	_push_recent(s)
	_preview.queue_redraw()


## One chart at the reading spot until it is sorted (or the clock runs out).
func _serve(card: Dictionary, hint: bool) -> void:
	_card = card
	# a key kept from the last chart's drop, jam or help was meant for that chart, not this one
	# (only a press while this chart lands carries over; a warm-up retry stays on its own chart)
	_pending = &""
	if _phase == "run":
		_cards += 1
	if not bool(card.get("golden", false)) and not (card.get("look", {}) as Dictionary).is_empty():
		CasePortraits.register(String(card["who"]), card["look"])
	var view := _views[_view_i]
	_view_i = 1 - _view_i
	view.show_card(card)
	_slide_in(view)
	_preview.queue_redraw()
	_ramp_tips(card)
	await get_tree().create_timer(SETTLE_S, false).timeout
	for n: String in _shot_queue:
		_shot_once(n)
	_shot_queue.clear()
	while true:
		if _phase != "run" and _phase != "warmup":
			_park(view)
			return
		var open := ChuteRules.unlocked(_t if _phase == "run" else -1.0, belt)
		var shape: StringName = card["shape"]
		if hint:
			_chutes[shape].pulse = true
			Hoot.say(String(WARMUP_HINTS.get(shape, "Drop it down the chute it looks like!")), Hoot.URGENT, "chute_" + String(shape), "", 6.0)
		_beat_serial += 1
		var serial := _beat_serial
		_waiting = true
		var words: Array = open.map(func(s: StringName) -> String: return ChartDeck.CHUTE_WORDS[s])
		Events.awaiting_input.emit(&"chute_sort", {"shape": shape, "options": words, "best": open.find(shape),
			"mouse": {"click": "chute_" + String(shape)}}, func() -> void:
				if serial == _beat_serial:
					sort_into(shape))
		if _pending != &"":
			_apply_pending.call_deferred()
		var pick: StringName = await _sorted
		_waiting = false
		_beat_serial += 1
		Events.input_resolved.emit(&"chute_sort")
		for s: StringName in _chutes:
			_chutes[s].pulse = false
		if hint:
			Hoot.dismiss_target("chute_" + String(shape))   # a hint never outlives its chart
		if pick == &"":
			_park(view)
			return
		if pick == &"help":
			await _help(view, card)
			return
		if pick == shape:
			await _right_drop(view, card)
			return
		await _wrong_drop(view, card, pick)
		if _phase == "warmup":
			continue
		if _phase == "run":
			card["requeued"] = true
			_requeue.append({"card": card, "due": ChuteRules.REQUEUE_AFTER})
		_send_back(view)
		return


func _right_drop(view: CardView, card: Dictionary) -> void:
	_busy = true
	var shape: StringName = card["shape"]
	var chute := _chutes[shape]
	var golden := bool(card.get("golden", false))
	if _phase == "run":
		_right += 1
		_streak += 1
		_best_streak = maxi(_best_streak, _streak)
		var pts := ChuteRules.points(_streak, golden)
		_score += pts
		var mult := ClinicRules.combo_multiplier(_streak) * (ChuteRules.GOLDEN_FACTOR if golden else 1)
		Juice.float_text(_field, "+%d%s" % [pts, ("  x%d" % mult) if mult > 1 else ""], POINTS_AT, Palette.MINT if not golden else GOLD, 30)
		if golden:
			ArcadeScores.mark_found(_mode, String(shape))
			_golden_seen = String(card["who"])
			Sfx.play(&"sparkle", 1.0, -4.0)
	Sfx.play(&"thunk", 1.0 + 0.04 * mini(_streak, 10), -2.0)
	chute.play_gag(String(card.get("line", "")))
	chute.flash = 1.0
	Juice.pop(chute, 1.08, 0.2)
	_drop_into(view, chute)
	await get_tree().create_timer(0.3, false).timeout
	_busy = false


func _wrong_drop(view: CardView, card: Dictionary, pick: StringName) -> void:
	_busy = true
	if _phase == "run":
		_oops += 1
	_streak = 0
	var shape: StringName = card["shape"]
	var chute := _chutes[pick]
	Sfx.play(&"boing", 0.9, -4.0)
	var home := CARD_RECT.position
	var toward := home + (chute.position + chute.size * 0.5 - (home + CARD_RECT.size * 0.5)) * 0.25
	var tw := view.move()
	tw.tween_property(view, "position", toward, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(view, "position", home, 0.22).set_trans(Tween.TRANS_SINE if _reduced() else Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Juice.shake(chute, 6.0, 0.25)
	# stamped on the streak box (the streak just broke), clear of the chart, the name and the ear tag
	_flash_banner("JAM!", Palette.CORAL, 0.6, Vector2(165, 326))
	var other_ear := String(card["ear"]) == "both" and pick == StringName(card.get("other_shape", &""))
	view.show_tell(shape, other_ear)
	_chutes[shape].pulse = true   # where it should have gone
	for s: StringName in _chutes:
		_chutes[s].line_t = -1.0   # the last patient's line gives way to the tell
	_shot_once("chute_jam_tell")
	await get_tree().create_timer(ChuteRules.JAM_S, false).timeout
	view.show_tell(&"")
	_chutes[shape].pulse = false
	_busy = false


func _help(view: CardView, card: Dictionary) -> void:
	_busy = true
	if _phase == "run":
		_helps += 1
	var shape: StringName = card["shape"]
	view.show_tell(shape)
	_chutes[shape].pulse = true
	Sfx.play(&"chirp", 1.0, -6.0)
	Hoot.say("Look here: " + String(ChartDeck.TELLS[shape]["text"]).to_lower() + ".", Hoot.URGENT, "chute_" + String(shape), "", ChuteRules.HELP_S + 0.4)
	await get_tree().create_timer(ChuteRules.HELP_S, false).timeout
	view.show_tell(&"")
	_chutes[shape].pulse = false
	Sfx.play(&"pop", 0.9, -4.0)
	_drop_into(view, _chutes[shape])
	await get_tree().create_timer(0.3, false).timeout
	_busy = false


func _ramp_tips(card: Dictionary) -> void:
	if _phase == "warmup" and _serial == 2:
		_shot_queue.append("chute_warmup")   # the second warm-up card: past the scene's fade-in
	if _phase != "run":
		return
	if String(card["ear"]) == "left":
		_say("left", "Blue X is the left ear. Its bone marks face the other way." if card.has("bc") else "Blue X is the left ear. Same shapes!", "")
	elif String(card["ear"]) == "both":
		_say("both", "Two ears? Sort the colour on the tag.", "")
		_shot_queue.append("chute_both_ears")
	if bool(card.get("golden", false)):
		_say("golden", "A story patient's chart! Triple points!", "")
		_shot_queue.append("chute_golden")


func _refresh_locks() -> void:
	var open := ChuteRules.unlocked(_t if _phase == "run" or _phase == "tally" else -1.0, belt)
	for s: StringName in _chutes:
		var c := _chutes[s]
		var lock := not open.has(s)
		if c.locked and not lock:
			c.locked = false
			Juice.pop(c, 1.25, 0.4)
			Sfx.play(&"pop", 1.2, -4.0)
			_flash_banner("NEW CHUTE!", Palette.SUNNY, 0.8, Vector2(c.position.x + c.size.x * 0.5, CHUTE_Y - 40))
			_say("unlock_" + String(s), "New chute: %s. %s." % [ChartDeck.CHUTE_WORDS[s].to_lower(), ChartDeck.TELLS[s]["text"]], "")
			_shot_once("chute_unlock_" + String(s))
			if _phase == "run":
				_meet_new_chute(s)
		c.locked = lock
		c.queue_redraw()


func _countdown() -> void:
	for n: String in ["3", "2", "1", "GO!"]:
		_flash_banner(n, Palette.SUNNY if n != "GO!" else Palette.MINT, 0.5)
		Sfx.play(&"blip" if n != "GO!" else &"ding", 1.0 if n != "GO!" else 1.3, -6.0)
		await get_tree().create_timer(0.55, false).timeout


func _tally() -> void:
	_phase = "tally"
	_waiting = false
	_pending = &""
	_preview.queue_redraw()
	Hoot.clear()
	Sfx.play(&"fanfare", 1.0, -4.0)
	_flash_banner("TIME!", Palette.CORAL, 1.2)
	await get_tree().create_timer(1.3, false).timeout
	ArcadeScores.add_run(_mode, {"right": _right, "oops": _oops, "score": _score})
	_phase = "results"
	await _show_results()


func _say(key: String, text: String, anchor: String) -> void:
	if _said.has(key):
		return
	_said[key] = true
	Hoot.say(text, Hoot.NORMAL, anchor, "", 3.5)


func _shot_once(n: String) -> void:
	if _shots.has(n):
		return
	_shots[n] = true
	Events.screenshot_requested.emit(n)


# ================================================================ motion

func _slide_in(view: CardView) -> void:
	view.visible = true
	view.modulate.a = 1.0
	view.position = PREVIEW_RECT.position + Vector2(40, 0)
	view.scale = Vector2.ONE * 0.55
	var tw := view.move().set_parallel(true)
	if _reduced():
		# reduced motion: an even glide, no overshoot
		tw.tween_property(view, "position", CARD_RECT.position, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(view, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(view, "position", CARD_RECT.position, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(view, "scale", Vector2.ONE, 0.2)
	Sfx.play(&"whoosh", 1.4, -16.0)


func _drop_into(view: CardView, chute: Control) -> void:
	var target := chute.position + chute.size * 0.5 - CARD_RECT.size * 0.5 + Vector2(0, 30)
	var tw := view.move().set_parallel(true)
	tw.tween_property(view, "position", target, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "scale", Vector2.ONE * 0.18, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "modulate:a", 0.0, 0.26).set_delay(0.08)
	tw.chain().tween_callback(view.hide)   # a gone card never sits invisibly over a chute


## A wrongly sorted chart slides back up the belt (it returns a few cards later).
func _send_back(view: CardView) -> void:
	var tw := view.move().set_parallel(true)
	tw.tween_property(view, "position", PREVIEW_RECT.position + Vector2(80, 30), 0.22)
	tw.tween_property(view, "scale", Vector2.ONE * 0.4, 0.22)
	tw.tween_property(view, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(view.hide)


## The clock ran out with a chart on the belt: it just fades.
func _park(view: CardView) -> void:
	var tw := view.move()
	tw.tween_property(view, "modulate:a", 0.0, 0.3)
	tw.tween_callback(view.hide)


## A big word that pops and fades, centred on `at` (default: the reading spot). A new banner
## stops the last one's tweens, so a quick JAM after NEW CHUTE never fades out early.
func _flash_banner(text: String, color: Color, hold := 0.6, at := Vector2(-1, -1)) -> void:
	if at.x < 0.0:
		at = CARD_RECT.get_center()
	for tw: Tween in [_banner_tw, _banner_pop]:
		if tw != null and tw.is_valid():
			tw.kill()
	var long := text.length() > 5
	var pop := 1.25 if long else 1.6
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.add_theme_font_size_override("font_size", 64 if long else 84)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE
	_banner.reset_size()
	# keep the popped banner (not just its resting size) inside the playfield
	var grow := _banner.size.x * (pop - 1.0) * 0.5
	_banner.position = Vector2(clampf(at.x - _banner.size.x * 0.5, 8.0 + grow, FIELD.x - 8.0 - grow - _banner.size.x), at.y - _banner.size.y * 0.5)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_pop = Juice.pop(_banner, pop, 0.25)
	_banner_tw = _banner.create_tween()
	_banner_tw.tween_interval(hold)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.25)


# ================================================================ building

func _build() -> void:
	_bg = UiKit.full_rect()
	_bg.draw.connect(_draw_bg.bind(_bg))
	add_child(_bg)
	_field = _new_field()
	_top = UiKit.full_rect()
	_top.draw.connect(_draw_top)
	_field.add_child(_top)
	_side = UiKit.full_rect()
	_side.draw.connect(_draw_side)
	_field.add_child(_side)
	_preview = UiKit.full_rect()
	_preview.draw.connect(_draw_preview)
	_field.add_child(_preview)
	# the chutes share the width: 4 at full size, 5 a little narrower with a smaller gap
	var n := _ids.size()
	var gap := CHUTE_GAP if n <= 4 else CHUTE_GAP * 0.7
	var w := minf(CHUTE_SIZE.x, (FIELD.x - 2.0 * CHUTE_MARGIN - gap * (n - 1)) / n)
	var x0 := (FIELD.x - (w * n + gap * (n - 1))) * 0.5
	for i in n:
		var s: StringName = _ids[i]
		var c := ChuteView.new(s, i + 1)
		c.size = Vector2(w, CHUTE_SIZE.y)
		c.pivot_offset = c.size * 0.5
		c.position = Vector2(x0 + i * (w + gap), CHUTE_Y)
		c.locked = not ChuteRules.unlocked(-1.0, belt).has(s)
		c.picked.connect(sort_into)
		_field.add_child(c)
		_chutes[s] = c
		Hoot.register_anchor("chute_" + String(s), c)
	for i in 2:
		var v := CardView.new()
		v.visible = false
		_field.add_child(v)
		v.setup()
		_views.append(v)
	_help_btn = UiKit.button("HOOT HELP  [H]" if UiKit.show_key_hints() else "HOOT HELP", &"", Vector2(290, 58))
	_help_btn.position = Vector2(20, 404)
	_help_btn.size = Vector2(290, 58)
	_help_btn.pressed.connect(press_help)
	_field.add_child(_help_btn)
	Hoot.register_anchor("chute_help", _help_btn)
	_lines = UiKit.full_rect()
	_lines.draw.connect(func() -> void:
		for s: StringName in _chutes:
			_chutes[s].draw_line_bubble(_lines))
	_field.add_child(_lines)
	_banner = UiKit.label("", 84, Palette.SUNNY, 700, 18, Palette.INK)
	_banner.visible = false
	_field.add_child(_banner)


## A 1280x720 layer that _layout() keeps centred in the window.
func _new_field() -> Control:
	var f := Control.new()
	f.size = FIELD
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	_fields.append(f)
	return f


## The wall, the floor, the top band and the belt, across the whole window.
func _draw_bg(ci: Control) -> void:
	var full := ci.size
	var o := _field.position
	ci.draw_rect(Rect2(Vector2.ZERO, full), WALL)
	ci.draw_rect(Rect2(0, o.y + 470, full.x, full.y - o.y - 470), FLOOR)
	ci.draw_rect(Rect2(0, 0, full.x, o.y + TOP_H), TOP_BAND)
	# the belt under the reading spot and the preview, running off the right edge
	var belt := Rect2(o.x + 320, o.y + CARD_RECT.end.y - 24, full.x - o.x - 320 + 24, 34)
	UiDraw.rounded_rect(ci, belt, BELT, 17)
	var roll := 0.0
	if _phase == "run" and not _reduced():
		roll = fmod(Game.clock * 1000.0 / 18.0, 40.0)
	var n := ceili(belt.size.x / 40.0) + 1
	for i in n:
		var x := belt.position.x + 14 + i * 40 - roll
		if x > belt.position.x + 6 and x < full.x + 10:
			ci.draw_circle(Vector2(x, belt.get_center().y), 9.0, Color("#6b6385"))


func _draw_top() -> void:
	var f := UiKit.font(700)
	_top.draw_string(f, Vector2(22, 52), "AIR & BONE" if belt == &"types" else "CHART CHUTE", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.SUNNY)
	# the clock bar
	var bar := Rect2(330, 24, 560, 34)
	UiDraw.rounded_rect(_top, bar, Color("#4a4363"), 17)
	if _phase == "warmup" or _phase == "intro":
		_top.draw_string(f, bar.position + Vector2(0, 26), "WARM-UP: NO CLOCK YET", HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 22, Palette.PAPER)
	else:
		var left := maxf(0.0, ChuteRules.RUN_S - maxf(_t, 0.0))
		var frac := left / ChuteRules.RUN_S
		var col := Palette.MINT if left > 10.0 else Palette.CORAL
		if frac > 0.0:
			UiDraw.rounded_rect(_top, Rect2(bar.position, Vector2(maxf(34.0, bar.size.x * frac), bar.size.y)), col, 17)
		# light numbers with a dark edge read on the green, the coral and the empty bar alike
		var at := bar.position + Vector2(0, 26)
		var secs := "%d" % ceili(left)
		_top.draw_string_outline(f, at, secs, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 24, 6, Palette.INK)
		_top.draw_string(f, at, secs, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 24, Palette.PAPER)
	# (the pause button sits at the top right corner, so the numbers stop short of it)
	_top.draw_string(UiKit.font(600), Vector2(906, 34), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.PAPER, 0.7))
	_top.draw_string(f, Vector2(906, 68), _thousands(int(_shown_score)), HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.PAPER)
	_top.draw_string(UiKit.font(600), Vector2(1056, 34), "RIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.MINT, 0.9))
	_top.draw_string(f, Vector2(1056, 68), str(_right), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.MINT)
	_top.draw_string(UiKit.font(600), Vector2(1136, 34), "OOPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.CORAL, 0.9))
	_top.draw_string(f, Vector2(1136, 68), str(_oops), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.CORAL)


func _draw_side() -> void:
	var f := UiKit.font(700)
	var box := Rect2(20, 262, 290, 128)
	UiDraw.rounded_rect(_side, box, Palette.PAPER, 20, 4, Palette.INK)
	var mult := ClinicRules.combo_multiplier(_streak)
	_side.draw_string(UiKit.font(600), box.position + Vector2(18, 34), "STREAK", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK_SOFT)
	_side.draw_string(f, box.position + Vector2(18, 92), str(_streak), HORIZONTAL_ALIGNMENT_LEFT, -1, 56, Palette.INK)
	if mult > 1:
		var flame := box.position + Vector2(214, 70)
		var wob := 0.0 if _reduced() else sin(Game.clock * 1000.0 / 90.0) * 3.0
		var pts := PackedVector2Array([flame + Vector2(0, -44 - wob), flame + Vector2(30, 0), flame + Vector2(18, 32), flame + Vector2(-18, 32), flame + Vector2(-30, 0)])
		_side.draw_colored_polygon(pts, Palette.SELECT_ORANGE)
		_side.draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -18 - wob), flame + Vector2(14, 8), flame + Vector2(0, 30), flame + Vector2(-14, 8)]), Palette.SUNNY)
		_side.draw_string(f, flame + Vector2(-40, 50), "x%d" % mult, HORIZONTAL_ALIGNMENT_CENTER, 80, 26, Palette.INK)
	else:
		_side.draw_string(UiKit.font(500), box.position + Vector2(120, 70), "3 in a row = x2", HORIZONTAL_ALIGNMENT_LEFT, 160, 16, Palette.INK_SOFT)


## The next chart waiting up the belt, as a small card: the ear to sort bold, the other one faint.
func _draw_preview() -> void:
	if _next.is_empty() or _phase != "run":
		return
	var r := Rect2(PREVIEW_RECT.position + Vector2(40, 40), Vector2(260, 168))
	UiDraw.rounded_rect(_preview, r, Color(Palette.PAPER, 0.85), 16, 3, GOLD if bool(_next.get("golden", false)) else Color(Palette.INK, 0.6))
	var f := UiKit.font(700)
	_preview.draw_string(UiKit.font(600), r.position + Vector2(14, 26), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_SOFT)
	var sort_ear := String(_next.get("sort_ear", "right"))
	if String(_next.get("ear", "right")) == "both":
		var tag := "RED O" if sort_ear == "right" else "BLUE X"
		_preview.draw_string(f, Vector2(r.position.x, r.position.y + 26), tag, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 14, 18, Palette.ear_color(sort_ear))
	var plot := Rect2(r.position + Vector2(16, 40), Vector2(r.size.x - 32, r.size.y - 54))
	_preview.draw_rect(plot, Color("#ffffff"))
	for ear: String in (_next["ac"] as Dictionary):
		var t: Dictionary = _next["ac"][ear]
		var keys: Array = t.keys()
		keys.sort()
		var pts := PackedVector2Array()
		for fr: int in keys:
			var x := plot.position.x + plot.size.x * (log(float(fr) / 125.0) / log(2.0)) / 6.0
			var y := plot.position.y + plot.size.y * (float(t[fr]) + 10.0) / 130.0
			pts.append(Vector2(x, y))
		if pts.size() > 1:
			_preview.draw_polyline(pts, Color(Palette.ear_color(ear), 0.85 if ear == sort_ear else 0.25), 3.0, true)
	for ear: String in (_next.get("bc", {}) as Dictionary):
		var b: Dictionary = _next["bc"][ear]
		for fr: int in b:
			var x := plot.position.x + plot.size.x * (log(float(fr) / 125.0) / log(2.0)) / 6.0
			var y := plot.position.y + plot.size.y * (float(b[fr]) + 10.0) / 130.0
			var side := -6.0 if ear == "right" else 6.0
			var tip := Vector2(x + side, y)
			_preview.draw_polyline(PackedVector2Array([tip + Vector2(-side * 0.7, -5), tip, tip + Vector2(-side * 0.7, 5)]), Color(Palette.ear_color(ear), 0.85), 2.5, true)


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ================================================================ results

func _show_results() -> void:
	_help_btn.visible = false
	var st := stats()
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # the whole window, not just the field
	var layer := _new_field()
	_layout()
	var panel := UiKit.panel(Palette.PAPER, Palette.INK, 28)
	panel.position = Vector2(170, 60)
	panel.custom_minimum_size = Vector2(940, 0)
	layer.add_child(panel)
	_results = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	head.add_child(UiKit.label("TIME!", 46, Palette.CORAL, 700))
	head.add_child(UiKit.label(String(st["rank"]), 34, Palette.INK, 700))
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 34)
	col.add_child(nums)
	nums.add_child(_stat("RIGHT / MIN", str(_right), Palette.MINT))
	nums.add_child(_stat("OOPS / MIN", str(_oops), Palette.CORAL))
	var acc := "%d%%" % roundi(float(st["accuracy"]) * 100.0) if _right + _oops > 0 else "–"
	nums.add_child(_stat("ACCURACY", acc, Palette.INK))
	nums.add_child(_stat("BEST STREAK", str(_best_streak), Palette.SELECT_ORANGE))
	nums.add_child(_stat("SCORE", _thousands(_score), Palette.INK))
	var badge := ""
	if bool(st["fluent"]):
		badge = "FLUENT! You read the shapes at a glance."
	else:
		badge = "FLUENT means %d right a minute with %d slip or fewer." % [int(ChuteRules.FLUENT_RIGHT_PM), ChuteRules.FLUENT_MAX_OOPS]
	col.add_child(UiKit.label(badge, 22, Palette.MINT if bool(st["fluent"]) else Palette.INK_SOFT, 600))
	if _helps > 0:
		col.add_child(UiKit.label("Hoot helped %d time%s (no points, streak kept)." % [_helps, "" if _helps == 1 else "s"], 18, Palette.INK_SOFT, 500))
	col.add_child(UiKit.label(_story_line(), 18, Palette.INK_SOFT, 500))
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 30)
	col.add_child(mid)
	var spark := Control.new()
	spark.custom_minimum_size = Vector2(380, 190)
	spark.draw.connect(_draw_speed_chart.bind(spark))
	mid.add_child(spark)
	var board := VBoxContainer.new()
	board.custom_minimum_size = Vector2(440, 190)
	mid.add_child(board)
	col.add_child(UiKit.label("Practice, not a qualification. Hearing care professionals read charts like these every day.", 17, Palette.INK_SOFT, 500))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	col.add_child(buttons)
	var hints := UiKit.show_key_hints()
	_again_btn = UiKit.button("Play again  [Enter]" if hints else "Play again", &"AccentButton", Vector2(260, 56))
	_back_btn = UiKit.button("Back to the arcade  [T]" if hints else "Back to the arcade", &"", Vector2(300, 56))
	buttons.add_child(_again_btn)
	buttons.add_child(_back_btn)
	_again_btn.pressed.connect(func() -> void: Events.goto_scene.emit(scene_file_path))
	_back_btn.pressed.connect(func() -> void: Events.goto_scene.emit(HALL_SCENE))
	_again_btn.visible = false
	_back_btn.visible = false
	Juice.bounce_in(panel)
	await get_tree().create_timer(0.6, false).timeout
	_shot_once("chute_results")
	var placed := -1
	if ChuteRules.on_board(_right, _oops) and ArcadeScores.qualifies(_mode, _score):
		var initials: String = await _enter_initials(board)
		placed = ArcadeScores.add_score(_mode, initials, _score, float(st["accuracy"]))
	elif _right > 0 and not ChuteRules.on_board(_right, _oops):
		board.add_child(UiKit.label("The board takes runs %d%% accurate or better." % roundi(ChuteRules.BOARD_MIN_ACCURACY * 100.0), 17, Palette.CORAL, 600))
	_fill_board(board, placed)
	_again_btn.visible = true
	_back_btn.visible = true
	_results_keys_at = Game.clock
	await get_tree().create_timer(0.3, false).timeout
	_shot_once("chute_board")
	Events.awaiting_input.emit(&"arcade_results", {"options": ["Play again", "Back to the arcade"], "best": 1,
		"mouse": {"text": "Back to the arcade"}}, func() -> void: Events.goto_scene.emit(HALL_SCENE))


## Story charts found, and how the rest join the belt (each once its patient's Day is finished).
func _story_line() -> String:
	if belt == &"types":
		return "Bone shows the inner ear. The gap between air and bone shows the middle ear."
	var found := ArcadeScores.found(_mode)
	var total := ChartDeck.GOLDEN.size()
	var line := "Story charts found: %d of %d" % [found.size(), total]
	if _golden_seen != "":
		line += "  (%s today!)" % _golden_seen
	var days_left: Array[int] = []
	for s: StringName in ChartDeck.GOLDEN:
		var id := String(ChartDeck.GOLDEN[s]["patient"])
		if not Game.is_chapter_done(id):
			days_left.append(_day_of(id))
	days_left.sort()
	var waiting := PackedStringArray(days_left.map(func(d: int) -> String: return str(d)))
	if waiting.is_empty():
		return line + "."
	var days := ", ".join(waiting.slice(0, -1)) + " or " + waiting[-1] if waiting.size() > 1 else waiting[0]
	if waiting.size() == total:
		return "Story charts (x3): finish Day %s and that patient's own chart joins the belt." % days
	return line + ". Finish Day %s for more." % days


static func _day_of(chapter_id: String) -> int:
	for c: Dictionary in Game.CHAPTERS:
		if String(c["id"]) == chapter_id:
			return int(c.get("day", 0))
	return 0


func _stat(label: String, value: String, color: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UiKit.label(label, 16, Palette.INK_SOFT, 600))
	v.add_child(UiKit.label(value, 44, color, 700))
	return v


func _fill_board(board: VBoxContainer, placed: int) -> void:
	board.add_child(UiKit.label("HIGH SCORES", 20, Palette.INK, 700))
	var t := ArcadeScores.table(_mode)
	for i in mini(t.size(), 5):
		var row: Dictionary = t[i]
		var mine := i == placed
		var l := UiKit.label("%d.  %s   %s   %d%%" % [i + 1, row["initials"], _thousands(int(row["score"])), roundi(float(row["accuracy"]) * 100.0)],
			20, Palette.SELECT_ORANGE if mine else Palette.INK, 700 if mine else 600)
		board.add_child(l)
	if placed >= 5:
		board.add_child(UiKit.label("%d.  %s   %s" % [placed + 1, t[placed]["initials"], _thousands(int(t[placed]["score"]))], 20, Palette.SELECT_ORANGE, 700))


## The last runs: right (green) and oops (coral) a minute, so the climb shows.
func _draw_speed_chart(c: Control) -> void:
	var f := UiKit.font(600)
	var r := Rect2(Vector2(0, 26), c.size - Vector2(0, 30))
	c.draw_string(UiKit.font(700), Vector2(0, 18), "YOUR SPEED CHART", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)
	UiDraw.rounded_rect(c, r, Color("#ffffff"), 12, 2, Color(Palette.INK, 0.3))
	var runs := ArcadeScores.runs(_mode)
	if runs.is_empty():
		return
	if runs.size() < 2:
		# low in the plot, under the FLUENT line and clear of a first run's dots
		c.draw_string(f, Vector2(r.position.x + 40, r.end.y - 16), "Play again to see your climb.", HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 60, 16, Palette.INK_SOFT)
	var top := maxf(ChuteRules.FLUENT_RIGHT_PM + 5.0, 10.0)
	for rr: Dictionary in runs:
		top = maxf(top, float(rr["right"]) + 5.0)
	var aim_y := r.end.y - 10 - (r.size.y - 20) * ChuteRules.FLUENT_RIGHT_PM / top
	c.draw_dashed_line(Vector2(r.position.x + 8, aim_y), Vector2(r.end.x - 8, aim_y), Color(Palette.MINT, 0.6), 2.0, 8.0)
	c.draw_string(f, Vector2(r.end.x - 70, aim_y - 6), "FLUENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.MINT)
	for key: String in ["right", "oops"]:
		var pts := PackedVector2Array()
		for i in runs.size():
			var x := r.position.x + 20 + (r.size.x - 40) * (float(i) / maxf(1.0, runs.size() - 1))
			var y := r.end.y - 10 - (r.size.y - 20) * float(runs[i][key]) / top
			pts.append(Vector2(x, y))
		var col := Palette.MINT if key == "right" else Palette.CORAL
		if pts.size() > 1:
			c.draw_polyline(pts, col, 4.0, true)
		for p: Vector2 in pts:
			c.draw_circle(p, 5.0, col)


## (coroutine) Three letters: type them, or click the arrows; Enter or OK. Returns the initials.
func _enter_initials(board: VBoxContainer) -> String:
	var box := VBoxContainer.new()
	board.add_child(box)
	box.add_child(UiKit.label("NEW HIGH SCORE! Your initials:", 20, Palette.SELECT_ORANGE, 700))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var letters: Array[String] = []
	for c in ArcadeScores.last_initials(_mode):
		letters.append(c)
	var labels: Array[Label] = []
	var cursor := [0]
	var refresh := func() -> void:
		for i in 3:
			labels[i].text = letters[i]
			labels[i].add_theme_color_override("font_color", Palette.SELECT_ORANGE if i == cursor[0] else Palette.INK)
	for i in 3:
		var slot := VBoxContainer.new()
		var up := UiKit.button("+", &"GhostButton", Vector2(54, 34))
		var l := UiKit.label(letters[i], 40, Palette.INK, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var down := UiKit.button("-", &"GhostButton", Vector2(54, 34))
		var idx := i
		up.pressed.connect(func() -> void:
			cursor[0] = idx
			letters[idx] = _step_letter(letters[idx], 1)
			refresh.call())
		down.pressed.connect(func() -> void:
			cursor[0] = idx
			letters[idx] = _step_letter(letters[idx], -1)
			refresh.call())
		slot.add_child(up)
		slot.add_child(l)
		slot.add_child(down)
		row.add_child(slot)
		labels.append(l)
	var ok := UiKit.button("OK", &"AccentButton", Vector2(90, 56))
	row.add_child(ok)
	Hoot.register_anchor("arcade_initials_ok", ok)
	refresh.call()
	var done := [false]
	var finish := func() -> void:
		if not done[0]:
			done[0] = true
			ok.pressed.emit()
	var keys := _InitialsKeys.new()
	keys.on_letter = func(ch: String) -> void:
		letters[cursor[0]] = ch
		cursor[0] = mini(cursor[0] + 1, 2)
		refresh.call()
	keys.on_back = func() -> void:
		cursor[0] = maxi(cursor[0] - 1, 0)
		refresh.call()
	keys.on_step = func(d: int) -> void:
		letters[cursor[0]] = _step_letter(letters[cursor[0]], d)
		refresh.call()
	keys.on_enter = finish
	add_child(keys)
	var serial := _beat_serial + 1
	_beat_serial = serial
	Events.awaiting_input.emit(&"arcade_initials", {"mouse": {"click": "arcade_initials_ok"}}, func() -> void:
		if serial == _beat_serial:
			letters.assign(["B", "O", "T"])
			refresh.call()
			finish.call())
	await ok.pressed
	done[0] = true
	_beat_serial += 1
	Events.input_resolved.emit(&"arcade_initials")
	keys.queue_free()
	box.queue_free()
	Sfx.play(&"kaching", 1.0, -4.0)
	return "".join(letters)


static func _step_letter(c: String, d: int) -> String:
	var i := ArcadeScores.LETTERS.find(c)
	return ArcadeScores.LETTERS[posmod(i + d, ArcadeScores.LETTERS.length())]


## Keyboard for the initials: letters, Backspace, Up / Down, Enter. It reads keys in _input, ahead
## of the pause menu, so a P typed as an initial is a letter, not a pause (Esc still pauses).
class _InitialsKeys extends Node:
	var on_letter: Callable
	var on_back: Callable
	var on_step: Callable
	var on_enter: Callable

	func _input(event: InputEvent) -> void:
		var k := event as InputEventKey
		if k == null or not k.pressed or k.echo or k.alt_pressed or k.ctrl_pressed or k.meta_pressed:
			return
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code >= KEY_A and code <= KEY_Z:
			on_letter.call(char(code))
		elif code == KEY_BACKSPACE:
			on_back.call()
		elif code == KEY_UP:
			on_step.call(1)
		elif code == KEY_DOWN:
			on_step.call(-1)
		elif code == KEY_ENTER or code == KEY_KP_ENTER:
			on_enter.call()
		else:
			return
		get_viewport().set_input_as_handled()
