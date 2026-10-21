extends Control
## EarsPlease (arcade, story-internal): the Ears, Please! arcade cabinet (docs/ARCADE.md part 2).
## You run the front desk of a hearing clinic. Each patient's file lands on the desk: an intake
## card (ASKED and LOOKED boxes, each NO or YES) and the chart. Stamp it FIT (fit hearing aids),
## REFER (a doctor first) or (Shift 3) DOCTOR TODAY, and for REFER or TODAY point at the proof: the
## ticked box, a column where one ear is worse, (Shift 2) a column with an air-bone gap, or (Shift
## 3) the alarm-clock card that says how and when the loss came on. Every call comes from
## DeskRules.decide(). Two missed same-day patients close the desk early.
## A shift is an untimed warm-up with Hoot, then 120 seconds. A slip shows a note that holds the
## clock until you go on (reading the lesson never costs time); a missed red flag costs two clean
## calls. HOOT HELP stamps and points for you, scores nothing and counts as not clean.
## Controls: keys 1-3 (or click a stamp); in PROVE IT the arrows move the pointer and Enter or
## Space points (or click); H for HOOT HELP; Enter or Space closes a note; on the results, Enter
## or Space plays again, S picks a shift and T goes back to the arcade. Pausable game time.
## The playfield is 1280x720, centred in wider or taller windows; the wall and desk fill the rest.
## Shifts: 1 Trainee (ticks and one ear worse), 2 Dispenser (+ the air-bone gap, wax and ear
## shape), 3 Clinic Lead (+ DOCTOR TODAY and the alarm clock), each opened by a safe shift of 8
## files or more on the one before.
## Beats (CONTRACTS.md §3.2): "desk_shift" (solver: start the highlighted shift), "desk_stamp"
## (solver: the right stamp; mouse: click "desk_stamp_<decision>"), "desk_prove" (solver: point at
## the best proof; mouse: click its anchor), "desk_note" (solver: go on; mouse: click
## "desk_note_ok"), "arcade_initials" and "arcade_results" (as in Chart Chute). Never a visit.
## Set seed_value (and autostart = false to drive it by hand) before adding it to the tree.

signal _stamped(stamp: StringName)
signal _pointed(target: Dictionary)
signal _note_closed
signal _shift_picked(id: int)

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const CasePortraits := preload("res://story/case_portraits.gd")
const DeskRules := preload("res://story/arcade/desk_rules.gd")
const DeskDeck := preload("res://story/arcade/desk_deck.gd")
const DeskRun := preload("res://story/arcade/desk_run.gd")
const DeskArt := preload("res://story/arcade/desk_art.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"
const HALL_SCENE := "res://story/arcade/arcade_hall.tscn"
const MODE := "ears_please"

const FIELD := Vector2(1280, 720)
const TOP_H := 82.0
const DESK_Y := 258.0
const WINDOW_RECT := Rect2(16, 92, 300, 160)
const CARD_SLOTS: Array[String] = ["tick", "one_ear", "gap", "sudden"]
const CARD_Y := 112.0
const CARD_SIZE := Vector2(178, 140)
const CLOCK_C := Vector2(1177, 172)
const CLOCK_R := 62.0
const FILE_RECT := Rect2(330, 262, 746, 450)
const RIGHT_COL := Rect2(1090, 262, 174, 444)
const STAMP_SIZE := Vector2(174, 136)
const HOOT_HINT := Rect2(16, 358, 300, 128)
const POINTS_AT := Vector2(1177, 238)
## A newly landed file takes stamps after this (no early-key buffer: a stamp is final).
const SETTLE_S := 0.2
## A note (a slip or a lesson) holds the clock: it takes a key after NOTE_MIN_S and goes by itself
## after NOTE_MAX_S.
const NOTE_MIN_S := 1.0
const NOTE_MAX_S := 6.0
const HELP_S := 1.6
const RESULTS_KEY_GUARD_S := 0.3
const WALL := Color("#f7e7cf")
const DESK := Color("#d9a066")
const DESK_EDGE := Color("#b9824a")
const TOP_BAND := Color("#2e2442")
const MANILA := Color("#f3d89a")
const GOLD := Color("#f2b632")
## The stamps' rubber (Freestyle's tray colours) and their ink.
const STAMP_FACE: Dictionary = {&"fit": Color("#c9f2dd"), &"refer": Color("#ffe1a8"), &"today": Color("#ffc9c0")}
const STAMP_INK: Dictionary = {&"fit": Color("#2f9e75"), &"refer": Color("#d98200"), &"today": Color("#d6336c")}
const STAMP_ORDER: Array[StringName] = [&"fit", &"refer", &"today"]

## Play again keeps the shift (and the check scene picks one); 0 = the latest open shift.
static var again_shift := 0

var seed_value := -1
var autostart := true

var _rng := RandomNumberGenerator.new()
var _phase := "intro"          # intro, picker, warmup, countdown, run, tally, results
var _step := ""                # per file: slide, stamp, prove, busy, note
var _t := -1.0                 # seconds into the 120 s shift (< 0 before it starts)
var _held := false             # a note is up: the shift clock stops
var _shift_id := 1
var _sh: Dictionary = {}
var _file: Dictionary = {}
var _v: Dictionary = {}
var _stamp_ready_at := INF
var _line: Array[StringName] = []
var _line_i := 0
var _serial := 0
var _beat_serial := 0
var _boss_done := false
var _taught := {}
var _shots := {}
# the tally
var _files := 0
var _counts := {}
var _helps := 0
var _score := 0
var _shown_score := 0.0
var _combo := 0
var _best_combo := 0
var _boss_seen := false
var _boss_clean := false
var _closed := false
var _marks := {}               # breakdown row -> ["clean" | "half" | "miss" | "help"]
var _promoted_now := false
# PROVE IT
var _targets: Array[Dictionary] = []
var _cursor := 0
# the note
var _note_at := 0.0
var _note_title := ""
var _note_line := ""
var _note_lesson := ""
var _note_points := 0
var _note_color := Palette.INK
# results
var _results_keys_at := -1.0
var _again_btn: Button
var _shifts_btn: Button
var _back_btn: Button
var _picker_pick := 1

var _bg: Control
var _field: Control
var _fields: Array[Control] = []
var _top: Control
var _wall: Control
var _side: Control
var _views: Array[FileView] = []
var _view_i := 0
var _view: FileView
var _stamps: Dictionary[StringName, StampView] = {}
var _panel: Control
var _note_btn: Button
var _help_btn: Button
var _skip_btn: Button           # the warm-up's Skip, once this shift has been warmed up on
var _fx: Control
var _banner: Label
var _banner_tw: Tween
var _banner_pop: Tween
var _card_fx := {}             # wall card id -> {"t", "col"}
var _window_fx := {}           # "aids", "sparkle", "wave" -> t (0..1, counting up)
var _results: Control


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


static func _font(w := 700) -> Font:
	return UiKit.font(w)


# ================================================================ views

## A click / hover target over the active file: an intake box or a chart column.
class HitBox extends Control:
	signal hovered(t: Dictionary)
	signal clicked(t: Dictionary)
	var target: Dictionary = {}

	func _init(t: Dictionary) -> void:
		target = t
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: hovered.emit(target))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(target)
			accept_event()


## One patient file on the desk: the tab, the intake card, the chart (under the alarm-clock card
## from shift 3) and the marks drawn over them (the PROVE IT pointer, the pin, the tell, a cross on
## a wrong pick, the ink and the goal sticker).
class FileView extends Control:
	const TILE := Vector2(104, 90)
	const CARD := Rect2(14, 38, 228, 400)
	const CHART := Rect2(256, 38, 476, 366)
	## Shift 3: the alarm-clock card across the top of the chart column, and the chart under it.
	const HISTORY := Rect2(256, 36, 476, 46)
	const CHART_LOW := Rect2(256, 94, 476, 310)
	const LEGEND := Rect2(256, 406, 476, 30)
	const PRINT_AT := Vector2(470, -12)
	var file: Dictionary = {}
	var sh: Dictionary = {}
	var ag: Audiogram
	var hits: Array[HitBox] = []
	var cursor: Dictionary = {}
	var pin: Dictionary = {}
	var wrong: Dictionary = {}
	var ring: Dictionary = {}
	var tell: Dictionary = {}       # a proof from DeskRules.decide
	var tell_t := 0.0
	var ink: StringName = &""
	var ink_word := ""
	var goal := ""
	var motion: Tween
	var _over: Control

	func _init() -> void:
		size = FILE_RECT.size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup() -> void:
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Audiogram
		ag.show_guides = false
		ag.show_title = false
		ag.ear = "both"
		ag.position = CHART.position
		ag.size = CHART.size
		add_child(ag)
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE   # after add_child: Audiogram._ready sets PASS
		_over = UiKit.full_rect()
		_over.draw.connect(_draw_marks)
		add_child(_over)

	func move() -> Tween:
		if motion != null and motion.is_valid():
			motion.kill()
		motion = create_tween()
		return motion

	## The chart's rect: lower from shift 3, where the alarm-clock card sits above it.
	func chart_rect() -> Rect2:
		return CHART_LOW if bool(sh.get("sudden", false)) else CHART

	func place_chart() -> void:
		ag.position = chart_rect().position
		ag.size = chart_rect().size

	func show_file(f: Dictionary, s: Dictionary, on_hover: Callable, on_click: Callable) -> void:
		file = f
		sh = s
		place_chart()
		cursor = {}
		pin = {}
		wrong = {}
		ring = {}
		tell = {}
		ink = &""
		ink_word = ""
		goal = ""
		ag.clear_points()
		ag.show_gap = false
		for ear: String in ClinicRules.EARS:
			var a: Dictionary = f["ac"][ear]
			for fr: int in a:
				ag.set_point(ear, fr, int(a[fr]), false, false)
			for fr: int in (f["ac_masked"][ear] as Dictionary):
				ag.set_point(ear, fr, int(a[fr]), false, false, &"ac_masked")
			var b: Dictionary = f["bc"][ear]
			for fr: int in b:
				var masked := bool((f["bc_masked"][ear] as Dictionary).get(fr, false))
				ag.set_point(ear, fr, int(b[fr]), false, false, &"bc_masked" if masked else &"bc")
		for h: HitBox in hits:
			h.queue_free()
		hits.clear()
		for t: Dictionary in DeskRun.targets(f, s):
			var h := HitBox.new(t)
			var r := target_rect(t)
			h.position = r.position
			h.size = r.size
			h.hovered.connect(on_hover)
			h.clicked.connect(on_click)
			add_child(h)
			move_child(h, _over.get_index())   # under the marks layer, over the chart
			hits.append(h)
		queue_redraw()
		_over.queue_redraw()

	func hit_for(t: Dictionary) -> HitBox:
		for h: HitBox in hits:
			if DeskRun.same_target(h.target, t):
				return h
		return null

	func tile_rect(id: String) -> Rect2:
		var i := DeskRules.ASKED.find(id)
		if i >= 0:
			return Rect2(CARD.position + Vector2(6 + (i % 2) * (TILE.x + 8), 52 + (i / 2) * (TILE.y + 6)), TILE)
		i = DeskRules.LOOKED.find(id)
		return Rect2(CARD.position + Vector2(6 + i * (TILE.x + 8), 278), TILE)

	func column_rect(freq: int) -> Rect2:
		var cols: Array = (file["ac"]["right"] as Dictionary).keys()
		cols.sort()
		var i := cols.find(freq)
		var x := ag.freq_to_x(freq)
		var lo := ag.freq_to_x(int(cols[i - 1])) if i > 0 else x - 40.0
		var hi := ag.freq_to_x(int(cols[i + 1])) if i >= 0 and i < cols.size() - 1 else x + 40.0
		var half_l := maxf(9.0, (x - lo) * 0.5)
		var half_r := maxf(9.0, (hi - x) * 0.5)
		var pr := ag.plot_rect()
		return Rect2(chart_rect().position + Vector2(x - half_l, pr.position.y - 22), Vector2(half_l + half_r, pr.size.y + 22))

	func target_rect(t: Dictionary) -> Rect2:
		match String(t.get("kind", "")):
			"intake":
				return tile_rect(String(t["id"]))
			"chart":
				return column_rect(int(t["freq"]))
			"sudden":
				return HISTORY
		return Rect2(CHART.position, Vector2(60, 40))

	func _process(delta: float) -> void:
		if not cursor.is_empty() or not tell.is_empty() or not ring.is_empty():
			tell_t += delta
		if visible and not file.is_empty():
			_over.queue_redraw()   # the marks change from many places (ink, pin, goal): redraw them every frame

	func _draw() -> void:
		if file.is_empty():
			return
		var f := UiKit.font(700)
		var boss := String(file.get("boss", "")) != ""
		# the folder: a tab and the body, with a shadow under both
		var tab := Rect2(0, 0, 380, 34)
		var body := Rect2(0, 26, size.x, size.y - 26)
		UiDraw.rounded_rect(self, Rect2(body.position + Vector2(0, 8), body.size), Color(Palette.INK, 0.22), 18)
		UiDraw.rounded_rect(self, tab, GOLD if boss else MANILA, 12, 4, Palette.INK)
		UiDraw.rounded_rect(self, body, MANILA, 18, 4, Palette.INK)
		draw_rect(Rect2(4, 26, tab.size.x - 8, 10), MANILA)
		var tab_text := "No. %d  ·  %s, %d" % [int(file.get("serial", 0)), String(file.get("name", "")), int(file.get("age", 0))]
		draw_string(f, Vector2(14, 25), tab_text, HORIZONTAL_ALIGNMENT_LEFT, 300, 18, Palette.INK)
		if boss:
			UiDraw.rounded_rect(self, Rect2(318, 4, 54, 24), Palette.CORAL, 12, 2, Palette.INK)
			draw_string(f, Vector2(318, 23), "VIP x2", HORIZONTAL_ALIGNMENT_CENTER, 54, 14, Palette.PAPER)
		# the intake card
		UiDraw.rounded_rect(self, CARD, Palette.PAPER, 14, 3, Palette.INK)
		draw_string(f, CARD.position + Vector2(12, 26), "INTAKE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Palette.INK)
		draw_string(UiKit.font(600), CARD.position + Vector2(0, 26), "NO or YES", HORIZONTAL_ALIGNMENT_RIGHT, CARD.size.x - 12, 14, Palette.INK_SOFT)
		draw_string(UiKit.font(600), CARD.position + Vector2(12, 46), "ASKED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)
		var looked_y := CARD.position.y + 258
		var looked_open := (sh.get("intake", []) as Array).has("wax")
		DeskArt.otoscope(self, Vector2(CARD.position.x + 22, looked_y + 12), 18.0)
		draw_string(UiKit.font(600), Vector2(CARD.position.x + 38, looked_y + 18), "LOOKED (otoscope)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)
		for id: String in DeskRules.ASKED + DeskRules.LOOKED:
			var open := (sh.get("intake", []) as Array).has(id)
			if not open and DeskRules.LOOKED.has(id):
				continue   # under the "From Shift 2" cover
			_draw_tile(id, tile_rect(id), open, bool((file.get("intake", {}) as Dictionary).get(id, false)))
		if not looked_open:
			var lr := Rect2(CARD.position + Vector2(6, 278), Vector2(CARD.size.x - 12, TILE.y))
			UiDraw.rounded_rect(self, lr, Color(Palette.INK, 0.78), 12)
			draw_string(f, lr.position + Vector2(0, 40), "From Shift 2", HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 18, Color(Palette.PAPER, 0.85))
			draw_string(UiKit.font(500), lr.position + Vector2(0, 64), "wax and ear shape", HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 15, Color(Palette.PAPER, 0.7))
		# the chart's card and its legend, and from shift 3 the alarm-clock card above them
		var cr := chart_rect()
		UiDraw.rounded_rect(self, Rect2(cr.position - Vector2(4, 4), cr.size + Vector2(8, 38)), Color("#ffffff"), 14, 3, Palette.INK)
		_draw_legend()
		if bool(sh.get("sudden", false)):
			_draw_history()

	## The alarm-clock card: how the loss came on, when it started, which ear (DeskRun.history).
	## The same clock on every file, whatever it says, so only reading it tells the call.
	func _draw_history() -> void:
		var r := HISTORY
		UiDraw.rounded_rect(self, Rect2(r.position - Vector2(4, 2), r.size + Vector2(8, 4)), Palette.PAPER, 12, 3, Palette.INK)
		DeskArt.alarm_clock(self, r.position + Vector2(24, 24), 30.0)
		var xs: Array[float] = [52.0, 262.0, 400.0]
		var fields := DeskRun.history(file.get("sudden", {}))
		for i in fields.size():
			var fd: Array = fields[i]
			var at := r.position + Vector2(xs[i], 0)
			var w := (xs[i + 1] if i + 1 < xs.size() else r.size.x) - xs[i] - 8.0
			draw_string(UiKit.font(600), at + Vector2(0, 16), String(fd[0]), HORIZONTAL_ALIGNMENT_LEFT, w, 12, Palette.INK_SOFT)
			var ear := String(fd[2])
			var col := Palette.INK if ear == "" else Palette.ear_color(ear)
			draw_string(UiKit.font(700), at + Vector2(0, 38), String(fd[1]), HORIZONTAL_ALIGNMENT_LEFT, w, 18, col)

	func _draw_tile(id: String, r: Rect2, open: bool, yes: bool) -> void:
		UiDraw.rounded_rect(self, r, Color("#fffdf6") if open else Color("#efe7d6"), 12, 2, Color(Palette.INK, 0.5))
		DeskArt.intake(self, id, r.position + Vector2(30, 36), 26.0)
		# the answer chip, top right: NO, or YES with a tick (a word as well as a colour)
		var chip := Rect2(r.position + Vector2(r.size.x - 50, 6), Vector2(44, 26))
		if yes:
			UiDraw.rounded_rect(self, chip, Palette.SUNNY, 8, 3, Palette.INK)
			draw_string(UiKit.font(700), chip.position + Vector2(3, 19), "YES", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
			UiDraw.check(self, chip.position + Vector2(37, 13), 12.0, Palette.INK, 3.0)
		else:
			UiDraw.rounded_rect(self, chip, Color("#ffffff"), 8, 2, Color(Palette.INK, 0.4))
			draw_string(UiKit.font(600), chip.position + Vector2(0, 19), "NO", HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 15, Palette.INK_SOFT)
		draw_multiline_string(UiKit.font(600), r.position + Vector2(4, 70), DeskRules.INTAKE_WORDS[id], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 15, 2, Palette.INK)

	func _draw_legend() -> void:
		var f := UiKit.font(600)
		var y := LEGEND.position.y + 16
		var x := LEGEND.position.x + 10
		# both ears' symbols for bone and masking, so a blue ] or a blue square is never a mystery
		var items := [[["right"], &"ac", "right"], [["left"], &"ac", "left"], [["right", "left"], &"bc", "bone"],
			[["right", "left"], &"bc_masked", "masked bone"], [["right", "left"], &"ac_masked", "masked air"]]
		for it: Array in items:
			var sx := x + 8
			for ear: String in it[0]:
				UiDraw.audiogram_symbol(self, Vector2(sx, y - 4), ear, it[1], 13.0, 2.5)
				sx += 15
			draw_string(f, Vector2(sx - 2, y + 2), String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK_SOFT)
			x = sx + 6 + f.get_string_size(String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x

	func _draw_marks() -> void:
		if file.is_empty():
			return
		var steady := bool(Game.settings.get("reduced_motion", false))
		var pulse := 0.6 if steady else 0.5 + 0.5 * sin(tell_t * 8.0)
		# the tell: the proof glows (a box, or the columns of a split or a gap)
		if not tell.is_empty():
			var rects: Array[Rect2] = []
			if String(tell.get("kind", "")) == "intake":
				rects.append(tile_rect(String(tell["id"])))
			elif String(tell.get("kind", "")) == "sudden":
				rects.append(HISTORY.grow(2))
			elif String(tell.get("kind", "")) == "chart":
				for fr: int in tell.get("freqs", []):
					rects.append(column_rect(fr))
			for r: Rect2 in rects:
				_over.draw_rect(r, Color(Palette.SUNNY, 0.2 + 0.14 * pulse))
				_over.draw_rect(r, Color(Palette.SELECT_ORANGE, 0.7 + 0.3 * pulse), false, 4.0)
			if String(tell.get("rule", "")) == "gap":
				ag.show_gap = true
		if not ring.is_empty():
			var rr := target_rect(ring).grow(5)
			if String(ring.get("kind", "")) == "sudden":
				# the card is wide: a circle would cross the desk. A box, just outside the tell's glow on the card.
				UiDraw.rounded_rect(_over, target_rect(ring).grow(9), Color(0, 0, 0, 0), 14, 5, Palette.MINT)
			else:
				_over.draw_arc(rr.get_center(), maxf(rr.size.x, rr.size.y * 0.55) * 0.62, 0.0, TAU, 40, Palette.MINT, 5.0)
		if not wrong.is_empty():
			var wr := target_rect(wrong)
			UiDraw.cross(_over, wr.get_center(), 26.0, Palette.CORAL, 6.0)
		if not cursor.is_empty():
			var cr := target_rect(cursor).grow(3)
			_over.draw_rect(cr, Color(Palette.SUNNY, 0.12))
			UiDraw.rounded_rect(_over, cr, Color(0, 0, 0, 0), 10, 4, Color(Palette.SELECT_ORANGE, 0.75 + 0.25 * pulse))
			var kind := String(cursor.get("kind", ""))
			if kind == "sudden":
				UiDraw.arrow(_over, Vector2(HISTORY.position.x + 24, cr.position.y - 16), 24.0, Vector2.DOWN, Palette.SELECT_ORANGE)   # over the clock face, clear of the ink
			elif kind == "chart" and bool(sh.get("sudden", false)):
				UiDraw.arrow(_over, Vector2(cr.get_center().x, cr.position.y - 7), 14.0, Vector2.DOWN, Palette.SELECT_ORANGE)   # short: the alarm clock sits just above
			else:
				UiDraw.arrow(_over, Vector2(cr.get_center().x, cr.position.y - 16), 24.0, Vector2.DOWN, Palette.SELECT_ORANGE)
		if not pin.is_empty():
			var pr := target_rect(pin)
			DeskArt.pin(_over, pr.get_center() + Vector2(0, 8), 22.0)
		if ink != &"":
			_draw_ink()
		if goal != "":
			var g := "GOAL: " + goal
			var gw := UiKit.font(700).get_string_size(g, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 26
			var cr := chart_rect()
			var at := Vector2(cr.position.x + cr.size.x - gw - 10, cr.position.y + 30)
			_over.draw_set_transform(at + Vector2(gw * 0.5, 17), -0.05, Vector2.ONE)
			UiDraw.rounded_rect(_over, Rect2(Vector2(-gw * 0.5, -17), Vector2(gw, 34)), Palette.MINT, 10, 3, Palette.INK)
			_over.draw_string(UiKit.font(700), Vector2(-gw * 0.5 + 13, 7), g, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)
			_over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_ink() -> void:
		var word := ink_word if ink_word != "" else CaseRules.DECISION_STAMPS[ink]
		var col: Color = STAMP_INK[ink] if ink_word == "" else Color(Palette.INK_SOFT)
		var f := UiKit.font(700)
		var short := word.length() <= 6
		var fs := 30 if short else 24   # DOCTOR TODAY stays on the folder
		var w := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 30
		# a long stamp tilts less and sits a little lower, so its far end stays off the wall card's chips
		_over.draw_set_transform(PRINT_AT + Vector2(w * 0.5, 22.0 if short else 26.0), -0.1 if short else -0.06, Vector2.ONE)
		var r := Rect2(Vector2(-w * 0.5, -22), Vector2(w, 44))
		UiDraw.rounded_rect(_over, r, Color(col, 0.12), 8, 4, col)
		_over.draw_string(f, Vector2(-w * 0.5 + 15, fs * 0.36), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		_over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## One rubber stamp in the right column: the knob, the rubber face, its icon and word, its key.
class StampView extends Control:
	signal picked(stamp: StringName)
	var stamp: StringName
	var key := 1
	var locked := false
	var lock_text := ""
	var pulse := false:
		set(v):
			pulse = v
			queue_redraw()   # _process only redraws while one is on: clear the last frame too
	var wobble := false:
		set(v):
			wobble = v
			queue_redraw()
	var _hover := false

	func _init(s: StringName, k: int) -> void:
		stamp = s
		key = k
		size = STAMP_SIZE
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			_hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hover = false
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(stamp)
			accept_event()

	func _process(_delta: float) -> void:
		if pulse or wobble:
			queue_redraw()

	func _draw() -> void:
		var f := UiKit.font(700)
		var lift := -4.0 if _hover and not locked else 0.0
		var steady := bool(Game.settings.get("reduced_motion", false))
		if wobble and not steady:
			draw_set_transform(size * 0.5 + Vector2(-size.x * 0.5, -size.y * 0.5).rotated(sin(Game.clock * 1000.0 / 150.0) * 0.07), sin(Game.clock * 1000.0 / 150.0) * 0.07, Vector2.ONE)
		# the knob and the block
		UiDraw.rounded_rect(self, Rect2(size.x * 0.5 - 30, 4 + lift, 60, 30), Palette.WOOD, 14, 3, Palette.INK)
		UiDraw.rounded_rect(self, Rect2(10, 30 + lift, size.x - 20, 22), Color("#8a5a33"), 6, 3, Palette.INK)
		var face := Rect2(4, 50 + lift, size.x - 8, size.y - 56)
		UiDraw.rounded_rect(self, Rect2(face.position + Vector2(0, 5), face.size), Color(Palette.INK, 0.3), 14)
		UiDraw.rounded_rect(self, face, STAMP_FACE[stamp], 14, 4, Palette.INK)
		var word: String = CaseRules.DECISION_STAMPS[stamp]
		if not locked:   # a locked stamp shows only its cover
			DeskArt.stamp_icon(self, stamp, face.position + Vector2(30, face.size.y * 0.5 - 4), 22.0)
			var fs := 24 if word.length() <= 5 else 17
			if word.length() > 5:
				draw_multiline_string(f, face.position + Vector2(56, face.size.y * 0.5 - 8), word.replace(" ", "\n"), HORIZONTAL_ALIGNMENT_LEFT, face.size.x - 60, fs, 2, Palette.INK)
			else:
				draw_string(f, face.position + Vector2(56, face.size.y * 0.5 + 9), word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if UiKit.show_key_hints() and not locked:
			UiDraw.rounded_rect(self, Rect2(4, 4 + lift, 32, 32), Palette.SUNNY, 9, 3, Palette.INK)
			draw_string(f, Vector2(4, 28 + lift), str(key), HORIZONTAL_ALIGNMENT_CENTER, 32, 20, Palette.INK)
		if pulse:
			var p := 0.7 if steady else 0.5 + 0.5 * sin(Game.clock * 1000.0 / 140.0)
			draw_rect(Rect2(Vector2.ZERO, size).grow(3.0 + 3.0 * p), Color(Palette.SUNNY, 0.6 + 0.4 * p), false, 5.0)
		if wobble and steady:
			UiDraw.rounded_rect(self, Rect2(size.x - 92, 2, 88, 24), Palette.CORAL, 10, 2, Palette.INK)
			draw_string(f, Vector2(size.x - 92, 20), "PICK ME?", HORIZONTAL_ALIGNMENT_CENTER, 88, 14, Palette.PAPER)
		if locked:
			UiDraw.rounded_rect(self, Rect2(Vector2(0, 0), size), Color(Palette.INK, 0.74), 16)
			draw_string(f, Vector2(0, size.y * 0.5 - 2), word, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(Palette.PAPER, 0.8))
			draw_string(f, Vector2(0, size.y * 0.5 + 24), lock_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(Palette.SUNNY, 0.9))


## A little picture that flies across the desk (the referral letter).
class Glyph extends Control:
	var stamp: StringName

	func _init(s: StringName) -> void:
		stamp = s
		size = Vector2(60, 44)
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		DeskArt.stamp_icon(self, stamp, size * 0.5, 34.0)


# ================================================================ lifecycle

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.seed = seed_value if seed_value >= 0 else Game.rng.randi()
	for o: StringName in DeskRules.OUTCOMES:
		_counts[o] = 0
	_build()
	Hoot.clear()
	get_viewport().size_changed.connect(_layout)
	_layout()
	if autostart:
		_run.call_deferred()


func _exit_tree() -> void:
	Hoot.clear_bubble_hint()
	Hoot.clear()
	for id: String in _anchor_ids():
		Hoot.unregister_anchor(id)


func _anchor_ids() -> PackedStringArray:
	var out := PackedStringArray(["desk_help", "desk_note_ok", "arcade_initials_ok", "desk_shift_1", "desk_shift_2", "desk_shift_3"])
	for s: StringName in STAMP_ORDER:
		out.append("desk_stamp_" + String(s))
	for id: String in DeskRules.INTAKE_WORDS:
		out.append("desk_intake_" + id)
	for f: int in ClinicRules.AC_FREQS:
		out.append("desk_chart_%d" % f)
	out.append("desk_sudden")
	return out


func demo_start() -> void:
	pass  # starts itself in _ready (also when reached from the arcade)


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
	_skip_btn.visible = _phase == "warmup" and not _skip_warmup and _can_skip()
	if _phase == "run" and not _held:
		_t += delta
		if _t >= DeskRules.SHIFT_S:
			_t = DeskRules.SHIFT_S
			_end_shift()
	if absf(_shown_score - _score) > 0.5:
		_shown_score = move_toward(_shown_score, _score, maxf(60.0, absf(_score - _shown_score) * 6.0) * delta)
	else:
		_shown_score = _score
	for k: String in _card_fx.keys():
		_card_fx[k]["t"] = float(_card_fx[k]["t"]) - delta / 1.2
		if float(_card_fx[k]["t"]) <= 0.0:
			_card_fx.erase(k)
	for k: String in _window_fx.keys():
		_window_fx[k] = float(_window_fx[k]) + delta / 1.0
		if float(_window_fx[k]) >= 1.0:
			_window_fx.erase(k)
	_top.queue_redraw()
	_wall.queue_redraw()
	_side.queue_redraw()
	_panel.queue_redraw()


## The clock ran out: the file in hand is parked, uncounted.
func _end_shift() -> void:
	_phase = "tally"
	match _step:
		"stamp":
			_stamped.emit(&"")
		"prove":
			_pointed.emit({})


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	var enter := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	if _phase == "results":
		if _results_keys_at < 0.0 or Game.clock - _results_keys_at < RESULTS_KEY_GUARD_S:
			return
		var btn: Button = null
		if enter:
			btn = _again_btn
		elif code == KEY_S and _shifts_btn != null and _shifts_btn.visible:
			btn = _shifts_btn
		elif code == KEY_T:
			btn = _back_btn
		if btn != null:
			_results_keys_at = -1.0   # once: a second press never starts a second scene change
			btn.pressed.emit()
			get_viewport().set_input_as_handled()
		return
	if _phase == "picker":
		_picker_key(code, k.physical_keycode)
		get_viewport().set_input_as_handled()
		return
	if code == KEY_S and _phase == "warmup" and _can_skip():
		skip_warmup()
		get_viewport().set_input_as_handled()
		return
	if _step == "note":
		if enter:
			close_note()
		get_viewport().set_input_as_handled()
		return
	if _step == "prove":
		var dir := Vector2.ZERO
		match code:
			KEY_LEFT:
				dir = Vector2.LEFT
			KEY_RIGHT:
				dir = Vector2.RIGHT
			KEY_UP:
				dir = Vector2.UP
			KEY_DOWN:
				dir = Vector2.DOWN
		if dir != Vector2.ZERO:
			move_cursor(dir)
			get_viewport().set_input_as_handled()
		elif enter:
			point(_targets[_cursor])
			get_viewport().set_input_as_handled()
		elif _digit(k) > 0 or code == KEY_H:
			_flash_right("Point first!")
			get_viewport().set_input_as_handled()
		return
	var d := _digit(k)
	if d >= 1 and d <= STAMP_ORDER.size():
		stamp(STAMP_ORDER[d - 1])
		get_viewport().set_input_as_handled()
	elif code == KEY_H:
		press_help()
		get_viewport().set_input_as_handled()


## 1-9 from the digit row (by position on any layout) or the keypad; 0 for anything else.
static func _digit(k: InputEventKey) -> int:
	var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	if (code < KEY_1 or code > KEY_9) and (code < KEY_KP_1 or code > KEY_KP_9):
		code = k.physical_keycode   # AZERTY and friends: the digit row by position
	if code >= KEY_1 and code <= KEY_9:
		return code - KEY_0
	if code >= KEY_KP_1 and code <= KEY_KP_9:
		return code - KEY_KP_0
	return 0


# ================================================================ public (keys, clicks, the solver)

## Stamp the file on the desk. A locked stamp shakes; a stamp before the file has landed, or
## while a note is up, is ignored (a stamp is final, so it never comes from a key meant earlier).
func stamp(s: StringName) -> void:
	if not _stamps.has(s):
		return
	if _stamps[s].locked:
		if _step == "stamp" or _step == "slide":
			Juice.shake(_stamps[s], 5.0, 0.2)
			Sfx.play(&"click", 0.7, -10.0)
			_flash_right(_stamps[s].lock_text)
		return
	if _step != "stamp" or Game.clock < _stamp_ready_at:
		return
	_step = "busy"
	_stamped.emit(s)


## Point at a target during PROVE IT (a click, Enter, or the solver).
func point(t: Dictionary) -> void:
	if _step != "prove":
		if _step == "stamp":
			_flash_right("Stamp first!")
		return
	_step = "busy"
	_pointed.emit(t)


func move_cursor(dir: Vector2) -> void:
	if _step != "prove" or _targets.is_empty():
		return
	var centres: Array[Vector2] = []
	for t: Dictionary in _targets:
		centres.append(_view.target_rect(t).get_center())
	_cursor = DeskRun.step(centres, _cursor, dir)
	_view.cursor = _targets[_cursor]
	Sfx.play(&"click", 1.3, -16.0)


## S or the Skip button, once this shift's warm-up has been played: the file in hand is parked
## whatever it is waiting for (a stamp, a proof or a note), and the countdown starts.
func skip_warmup() -> void:
	if _phase != "warmup" or _skip_warmup or not _can_skip():
		return
	_skip_warmup = true
	match _step:
		"stamp":
			_stamped.emit(&"")
		"prove":
			_step = "busy"
			_pointed.emit({})
		"note":
			_note_at = -INF
			close_note()


func press_help() -> void:
	if _step == "prove":
		_flash_right("Point first!")   # as the H key says
		return
	if _step != "stamp" or Game.clock < _stamp_ready_at:
		return
	_step = "busy"
	_stamped.emit(&"help")


func close_note() -> void:
	if _step != "note" or Game.clock - _note_at < NOTE_MIN_S:
		return
	_step = "busy"
	_note_closed.emit()


func prove_cursor() -> Dictionary:
	if _step != "prove" or _targets.is_empty():
		return {}
	return _targets[_cursor]


func pick_shift(id: int) -> void:
	if _phase != "picker":
		return
	if id < 1 or id > _unlocked() or id > DeskRun.PLAYABLE:
		Sfx.play(&"click", 0.7, -10.0)
		return
	_picker_pick = id
	_shift_picked.emit(id)


## The tally so far (the check scene and the results card read it).
func stats() -> Dictionary:
	var st := {"files": _files, "helps": _helps, "score": maxi(0, _score), "raw_score": _score, "best_combo": _best_combo,
		"shift": _shift_id, "t": _t, "phase": _phase, "step": _step, "closed": _closed, "boss": _boss_seen,
		"boss_clean": _boss_clean, "promoted": _promoted_now}
	for o: StringName in DeskRules.OUTCOMES:
		st[String(o)] = int(_counts[o])
	st["incidents"] = int(_counts[DeskRules.MISSED_TODAY])
	st["accuracy"] = DeskRules.accuracy(st)
	st["safe"] = DeskRules.safe(st)
	st["rank"] = DeskRules.rank(st)
	return st


# ================================================================ the shift

var _skip_warmup := false


static func _unlocked() -> int:
	var d := ArcadeScores.data(MODE)
	return clampi(int(d.get("unlocked", 1)), 1, DeskRules.SHIFTS.size())


static func _warmed(id: int) -> bool:
	var w: Variant = ArcadeScores.data(MODE).get("warmed", [])
	return w is Array and ((w as Array).has(id) or (w as Array).has(float(id)))


func _can_skip() -> bool:
	return _warmed(_shift_id)


func _run() -> void:
	var open := mini(_unlocked(), DeskRun.PLAYABLE)
	var again := again_shift
	again_shift = 0   # a one-shot request from Play again: the next visit from the hall picks afresh
	if again >= 1 and again <= open:
		_shift_id = again
	elif open > 1:
		_shift_id = await _picker(open)
	else:
		_shift_id = 1
	_sh = DeskRules.shift(_shift_id)
	_setup_shift()
	Sfx.music_start()
	_phase = "warmup"
	if not _skip_warmup:
		await _warmup()
	if _skip_warmup:
		Hoot.clear()
	_phase = "countdown"
	_step = ""
	await _countdown()
	_phase = "run"
	_t = 0.0
	_line = DeskDeck.make_line(_rng, _sh, 80)
	Hoot.say(String(DeskRun.SHIFT_START.get(_shift_id, "")), Hoot.NORMAL, "", "", 3.5)
	while _phase == "run":
		await _serve(_next_file(), [])
	await _tally()


func _setup_shift() -> void:
	for s: StringName in _stamps:
		var sv := _stamps[s]
		sv.locked = not (_sh["stamps"] as Array).has(s)
		sv.lock_text = "SHIFT 3"
		sv.queue_redraw()
	_prove_ask.text = "Point at the reason: a YES box, a column on the chart, or the alarm clock." if bool(_sh.get("sudden", false)) \
		else "Point at the reason: a YES box, or a column on the chart."
	_wall.queue_redraw()


func _next_serial() -> int:
	_serial += 1
	return _serial


func _next_file() -> Dictionary:
	if not _boss_done and _t >= DeskRules.SHIFT_S - DeskRules.BOSS_AT_LEFT_S:
		_boss_done = true
		var b := DeskDeck.make_boss(_rng, _sh, _next_serial())
		if not b.is_empty():
			return b
	if _line_i >= _line.size():
		_line.append_array(DeskDeck.make_line(_rng, _sh, 40))
	var want := _line[_line_i]
	_line_i += 1
	return DeskDeck.make_file(_rng, _sh, want, _next_serial())


func _warmup() -> void:
	var steps: Array = DeskRun.WARMUP.get(_shift_id, [])
	for st: Array in steps:
		if _skip_warmup:
			return
		await _serve(DeskRun.warmup_file(_rng, _sh, st, _next_serial()), st)
	if not _skip_warmup:
		var w: Array = ArcadeScores.data(MODE).get("warmed", []) if ArcadeScores.data(MODE).get("warmed", []) is Array else []
		if not _warmed(_shift_id):
			w.append(_shift_id)
		ArcadeScores.data(MODE)["warmed"] = w
		Game.save_game()
		Hoot.say(DeskRun.WARMUP_DONE, Hoot.URGENT, "", "", 2.5)


## One file on the desk until it is stamped (and proved) or the clock runs out. warm: the warm-up
## step ([] in the shift): Hoot guides, nothing scores, and a wrong call is tried again.
func _serve(f: Dictionary, warm: Array) -> void:
	_file = f
	_v = DeskRules.decide(f)
	var boss := String(f.get("boss", "")) != ""
	if not (f.get("look", {}) as Dictionary).is_empty():
		CasePortraits.register(String(f["who"]), f["look"])
	_view = _views[_view_i]
	_view_i = 1 - _view_i
	_view.show_file(f, _sh, _on_hover, point)
	_register_file_anchors()
	_window_fx.clear()
	_step = "slide"
	_slide_in(_view)
	if boss:
		_boss_seen = true
		Sfx.play(&"door", 1.0, -4.0)
		_flash_banner("VIP!", GOLD, 0.8)
		_stamps[&"fit"].wobble = true
		_say_once("vip", DeskRun.VIP_LINE)
		_shot_once("desk_vip")
	await get_tree().create_timer(0.3 + SETTLE_S, false).timeout
	if _serial == 2 and not warm.is_empty():
		_shot_once("desk_warmup")
	var warm_kind := String(f.get("warm", ""))
	while true:
		if _phase != "run" and _phase != "warmup":
			_park(_view)
			return
		if _skip_warmup and not warm.is_empty():
			_park(_view)
			return
		var want: StringName = _v["decision"]
		if not warm.is_empty():
			var lines: Array = DeskRun.WARMUP_LINES.get(warm_kind, ["", ""])
			_stamps[want].pulse = true
			Hoot.say(String(lines[0]), Hoot.URGENT, "desk_stamp_" + String(want), "", 30.0)
		_step = "stamp"
		_stamp_ready_at = Game.clock
		_beat_serial += 1
		var serial := _beat_serial
		var words: Array = (_sh["stamps"] as Array).map(func(s: StringName) -> String: return CaseRules.DECISION_STAMPS[s])
		Events.awaiting_input.emit(&"desk_stamp", {"file": int(f["serial"]), "options": words,
			"best": (_sh["stamps"] as Array).find(want), "decision": String(want), "kind": String(f["kind"]),
			"boss": boss, "warmup": not warm.is_empty(), "mouse": {"click": "desk_stamp_" + String(want)}}, func() -> void:
				if serial == _beat_serial:
					stamp(want))
		var s: StringName = await _stamped
		_beat_serial += 1
		Events.input_resolved.emit(&"desk_stamp")
		for k: StringName in _stamps:
			_stamps[k].pulse = false
		_stamps[&"fit"].wobble = false
		Hoot.dismiss_target("desk_stamp_" + String(want))
		if s == &"":
			_park(_view)
			return
		if s == &"help":
			await _help(f, boss)
			return
		await _stamp_down(s)
		if _phase != "run" and _phase != "warmup":   # the bell rang under the stamp: parked, uncounted
			_park(_view)
			return
		var target := {}
		if DeskRules.needs_proof(s):
			target = await _prove(f, s, warm_kind if not warm.is_empty() and s == want else "")
			if target.is_empty():   # the clock ran out mid-proof
				_park(_view)
				return
		var right_proof := DeskRules.proof_ok(_v, target) if not target.is_empty() else false
		var r := DeskRules.score_call(_v, s, right_proof, _combo, boss)
		var outcome: StringName = r["outcome"]
		if not warm.is_empty():
			if outcome == DeskRules.CLEAN:
				await _clean_feedback(f, s, 0, true)
				_slide_out(_view)
				return
			await _slip_feedback(f, s, target, outcome, 0, true)
			_view.show_file(f, _sh, _on_hover, point)   # the ink wipes off: stamp it again
			_register_file_anchors()
			continue
		_files += 1
		_counts[outcome] = int(_counts[outcome]) + 1
		_combo = int(r["combo"])
		_best_combo = maxi(_best_combo, _combo)
		_score += int(r["points"])
		_mark(DeskRun.row(f), outcome)
		if outcome == DeskRules.CLEAN:
			if boss:
				_boss_clean = true
			await _clean_feedback(f, s, int(r["points"]), false)
		else:
			if outcome == DeskRules.MISSED_TODAY and int(_counts[outcome]) < DeskRules.MAX_INCIDENTS:
				Hoot.say(DeskRun.INCIDENT_LINE, Hoot.URGENT, "", "", 4.0)
			await _slip_feedback(f, s, target, outcome, int(r["points"]), false)
		_slide_out(_view)
		if int(_counts[DeskRules.MISSED_TODAY]) >= DeskRules.MAX_INCIDENTS and _phase == "run":
			_closed = true   # two same-day patients sent home: the desk shuts early
			_end_shift()
		return


## PROVE IT: the pointer starts on the first intake box every file; returns what was pointed at
## ({} when the clock ran out).
func _prove(f: Dictionary, s: StringName, warm_kind: String) -> Dictionary:
	_targets = DeskRun.targets(f, _sh)
	_cursor = 0
	_view.cursor = _targets[0]
	_step = "prove"
	_show_right("prove")
	var best := DeskRules.best_target(_v)
	if warm_kind != "":
		var lines: Array = DeskRun.WARMUP_LINES.get(warm_kind, ["", ""])
		if String(lines[1]) != "":
			Hoot.say(String(lines[1]), Hoot.URGENT, DeskRun.anchor(best), "", 30.0)
	_shot_once("desk_prove")
	_beat_serial += 1
	var serial := _beat_serial
	var aim := best if not best.is_empty() else _targets[0]
	Events.awaiting_input.emit(&"desk_prove", {"file": int(f["serial"]), "stamp": String(s), "target": best,
		"anchor": DeskRun.anchor(aim), "count": _targets.size(), "mouse": {"click": DeskRun.anchor(aim)}}, func() -> void:
			if serial == _beat_serial:
				point(aim))
	var t: Dictionary = await _pointed
	_beat_serial += 1
	Events.input_resolved.emit(&"desk_prove")
	_show_right("stamps")
	if not best.is_empty():
		Hoot.dismiss_target(DeskRun.anchor(best))   # an empty anchor would clear every untargeted tip
	_view.cursor = {}
	if not t.is_empty():
		_view.pin = t
		Sfx.play(&"pen", 1.2, -6.0)
	return t


func _on_hover(t: Dictionary) -> void:
	if _step != "prove":
		return
	var i := DeskRun.target_index(_targets, t)
	if i >= 0:
		_cursor = i
		_view.cursor = t


## Stamp travels down onto the file, ink appears.
func _stamp_down(s: StringName) -> void:
	var sv := _stamps[s]
	_view.ink = s
	_view.ink_word = ""
	Sfx.play(&"stamp", 1.0, -2.0)
	Juice.squash(sv, 0.18, 0.2)
	Juice.shake(_view, 4.0, 0.15)
	_flash_word("KA-CHUNK!", _view.position + FileView.PRINT_AT + Vector2(80, 70))
	_shot_once("desk_stamp_" + String(s))
	await get_tree().create_timer(0.18, false).timeout


func _clean_feedback(f: Dictionary, s: StringName, pts: int, warm: bool) -> void:
	var proof := DeskRules.best_proof(_v)
	if pts > 0:
		var mult := ClinicRules.combo_multiplier(_combo)
		Juice.float_text(_field, "+%s%s" % [_thousands(pts), ("  x%d" % mult) if mult > 1 else ""], POINTS_AT, Palette.MINT, 30)
	if s == &"fit":
		# aids pop in at the window, a sparkle, and the goal the fitting aims at
		_window_fx["aids"] = 0.0
		_window_fx["sparkle"] = 0.0
		_view.goal = String(f.get("goal", ""))
		for id: String in DeskRules.RED_FLAG_RULES:
			if (_sh["rules"] as Array).has(id):
				_card_fx[id] = {"t": 1.0, "col": Palette.MINT, "mark": "none"}
		Sfx.play(&"sparkle", 1.0, -6.0)
		_shot_once("desk_fit_goal")
	else:
		var card := DeskRules.card_for(proof)
		_card_fx[card] = {"t": 1.0, "col": Palette.MINT, "mark": "check", "row": StringName(_v["decision"])}
		_view.tell = proof
		_send_letter(s)
		if s == &"today":
			_flash_word("SEEN TODAY!", WINDOW_RECT.get_center() + Vector2(0, -50))
		Sfx.play(&"whoosh", 1.1, -6.0)
		_window_fx["wave"] = 0.0
		_shot_once("desk_letter")
	await get_tree().create_timer(0.75, false).timeout
	_view.tell = {}
	var key := DeskRun.lesson(f)
	if not warm and DeskRun.LESSONS.has(key) and not _taught.has(key):
		_taught[key] = true
		await _note("NICE!", "", String(DeskRun.LESSONS[key]), 0, Palette.MINT)


func _slip_feedback(f: Dictionary, s: StringName, target: Dictionary, outcome: StringName, pts: int, warm: bool) -> void:
	var proof := DeskRules.best_proof(_v)
	var slip := DeskRun.slip(_v, f, outcome, s)
	if not target.is_empty() and not DeskRules.proof_ok(_v, target):
		_view.wrong = target
	if not proof.is_empty():
		_view.ring = DeskRules.best_target(_v)
		_view.tell = proof
		var card := DeskRules.card_for(proof)
		_card_fx[card] = {"t": 1.0, "col": Palette.CORAL, "mark": "none", "row": StringName(_v["decision"])}
	elif outcome == DeskRules.OVER:
		for id: String in DeskRules.RED_FLAG_RULES:
			if (_sh["rules"] as Array).has(id):
				_card_fx[id] = {"t": 1.0, "col": Palette.MINT, "mark": "none"}
	var col := Palette.CORAL if outcome == DeskRules.MISSED_FLAG or outcome == DeskRules.MISSED_TODAY else Palette.SELECT_ORANGE
	Sfx.play(&"error" if col == Palette.CORAL else &"squeak", 1.0, -4.0)
	if pts != 0:
		Juice.float_text(_field, ("+%s" if pts > 0 else "%s") % _thousands(pts), POINTS_AT, Palette.MINT if pts > 0 else Palette.CORAL, 30)
	var lesson := ""
	var key := DeskRun.lesson(f)
	if outcome != DeskRules.OVER and DeskRun.LESSONS.has(key) and not _taught.has(key):
		_taught[key] = true
		lesson = String(DeskRun.LESSONS[key])
	if warm:
		var best := DeskRules.best_target(_v)
		var aim := DeskRun.anchor(best) if outcome == DeskRules.WRONG_REASON else "desk_stamp_" + String(_v["decision"])
		Hoot.say(DeskRun.WARMUP_WRONG_PROOF if outcome == DeskRules.WRONG_REASON else DeskRun.WARMUP_WRONG_STAMP, Hoot.URGENT, aim, "", 4.0)
	_shot_once("desk_" + String(outcome))
	await _note(String(slip["title"]), String(slip["line"]), lesson, pts, col)
	_view.tell = {}
	_view.ring = {}
	_view.wrong = {}


## A note in the right column, holding the shift clock until a key, a click or NOTE_MAX_S.
func _note(title: String, line: String, lesson: String, pts: int, col: Color) -> void:
	_note_title = title
	_note_line = line
	_note_lesson = lesson
	_note_points = pts
	_note_color = col
	_note_at = Game.clock
	_held = true
	_step = "note"
	_show_right("note")
	Juice.pop(_panel_box, 1.08, 0.2)
	_beat_serial += 1
	var serial := _beat_serial
	Events.awaiting_input.emit(&"desk_note", {"title": title, "mouse": {"click": "desk_note_ok"}}, func() -> void:
		if serial == _beat_serial:
			_note_at = -INF
			close_note())
	var timer := get_tree().create_timer(NOTE_MAX_S, false)
	timer.timeout.connect(func() -> void:
		if serial == _beat_serial and _step == "note":
			_note_at = -INF
			close_note())
	await _note_closed
	_beat_serial += 1
	Events.input_resolved.emit(&"desk_note")
	_held = false
	_show_right("stamps")


## HOOT HELP: Hoot shows the proof, then stamps and points for you. No points, not a file, and
## counted as not clean; the combo is kept for the first HELPS_KEEP_COMBO helps.
func _help(f: Dictionary, boss: bool) -> void:
	if _phase == "run":
		_helps += 1
		_mark(DeskRun.row(f), &"help")
		if _helps > DeskRules.HELPS_KEEP_COMBO:
			_combo = 0
	var want: StringName = _v["decision"]
	var best := DeskRules.best_target(_v)
	_stamps[want].pulse = true
	_view.tell = DeskRules.best_proof(_v)
	Sfx.play(&"chirp", 1.0, -6.0)
	Hoot.say(DeskRun.help_line(_v, f), Hoot.URGENT, DeskRun.anchor(best) if not best.is_empty() else "desk_stamp_" + String(want), "", HELP_S + 0.6)
	await get_tree().create_timer(HELP_S, false).timeout
	_stamps[want].pulse = false
	_view.ink = want
	_view.ink_word = "HELPED"
	if not best.is_empty():
		_view.pin = best
	Sfx.play(&"pop", 0.9, -4.0)
	await get_tree().create_timer(0.6, false).timeout
	_view.tell = {}
	_slide_out(_view)


func _mark(row: String, outcome: StringName) -> void:
	if not _marks.has(row):
		_marks[row] = []
	var m := "half"
	match outcome:
		DeskRules.CLEAN:
			m = "clean"
		DeskRules.MISSED_FLAG, DeskRules.MISSED_TODAY:
			m = "miss"
		DeskRules.OVER, DeskRules.TOO_URGENT:
			m = "extra"
		&"help":
			m = "help"
	(_marks[row] as Array).append(m)


func _countdown() -> void:
	for n: String in ["3", "2", "1", "DESK OPEN!"]:
		_flash_banner(n, Palette.SUNNY if n.length() == 1 else Palette.MINT, 0.5)
		Sfx.play(&"blip" if n.length() == 1 else &"ding", 1.0 if n.length() == 1 else 1.3, -6.0)
		await get_tree().create_timer(0.55, false).timeout


func _tally() -> void:
	_phase = "tally"
	_step = ""
	Hoot.clear()
	Sfx.play(&"fanfare", 1.0, -4.0)
	_flash_banner("DESK CLOSED!" if _closed else "CLOSING TIME!", Palette.CORAL, 1.2)
	await get_tree().create_timer(1.3, false).timeout
	var st := stats()
	_promoted_now = DeskRules.promoted(st) and _shift_id < DeskRules.SHIFTS.size() and _unlocked() <= _shift_id
	if DeskRules.promoted(st):
		var d := ArcadeScores.data(MODE)
		d["unlocked"] = maxi(_unlocked(), _shift_id + 1)
	ArcadeScores.add_run(MODE, {"right": int(st["clean"]), "oops": int(st["files"]) - int(st["clean"]), "score": int(st["score"]),
		"shift": _shift_id, "files": int(st["files"]), "missed_flag": int(st["missed_flag"]), "over": int(st["over"]), "helps": _helps})
	_phase = "results"
	await _show_results()


func _say_once(key: String, text: String) -> void:
	if _taught.has("say:" + key):
		return
	_taught["say:" + key] = true
	Hoot.say(text, Hoot.NORMAL, "", "", 3.5)


func _shot_once(n: String) -> void:
	if _shots.has(n):
		return
	_shots[n] = true
	# a frame later, so the marks set this frame (the ink, the goal) are drawn in the shot
	get_tree().process_frame.connect(func() -> void: Events.screenshot_requested.emit(n), CONNECT_ONE_SHOT)


func _register_file_anchors() -> void:
	for h: HitBox in _view.hits:
		Hoot.register_anchor(DeskRun.anchor(h.target), h)


# ================================================================ the shift picker

func _picker(open: int) -> int:
	_phase = "picker"
	_picker_pick = open
	var layer := _new_field()
	_layout()
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.5)
	dim.size = FIELD
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(dim)
	var panel := UiKit.panel(Palette.PAPER, Palette.INK, 28)
	panel.position = Vector2(150, 110)
	panel.custom_minimum_size = Vector2(980, 0)
	layer.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(UiKit.label("EARS, PLEASE!", 44, Palette.CORAL, 700))
	col.add_child(UiKit.label("Pick a shift. Stamp each file, then prove it.", 20, Palette.INK_SOFT, 600))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)
	var tiles: Array[Button] = []
	for sh: Dictionary in DeskRules.SHIFTS:
		var id := int(sh["id"])
		var playable := id <= open
		var best := ArcadeScores.table(MODE, DeskRun.board(id))
		var mine := _best_score(id)
		var text := "%d  %s\n%s\n%s" % [id, String(sh["title"]).to_upper(), _shift_blurb(id),
			("Your best lately: %s" % _thousands(mine)) if mine > 0 else ("Top: %s %s" % [best[0]["initials"], _thousands(int(best[0]["score"]))])]
		if not playable:
			text = "%d  %s\n%s" % [id, String(sh["title"]).to_upper(), _lock_text(id)]
		var b := UiKit.button(text, &"AccentButton" if id == _picker_pick else &"", Vector2(300, 170))
		b.disabled = not playable
		b.pressed.connect(pick_shift.bind(id))
		row.add_child(b)
		tiles.append(b)
		Hoot.register_anchor("desk_shift_%d" % id, b)
	panel.position.x = (FIELD.x - panel.get_combined_minimum_size().x) * 0.5   # centred, however wide the tiles came out
	var hints := UiKit.show_key_hints()
	var keys := "1 or 2" if open == 2 else "1 to %d" % open
	col.add_child(UiKit.label(("Keys %s, or click a shift.   T: back to the arcade" % keys) if hints else "Click a shift.", 17, Palette.INK_SOFT, 500))
	Juice.bounce_in(panel)
	_beat_serial += 1
	var serial := _beat_serial
	var opts: Array = DeskRules.SHIFTS.map(func(s: Dictionary) -> String: return String(s["title"]))
	var opened: Array = DeskRules.SHIFTS.map(func(s: Dictionary) -> bool: return int(s["id"]) <= open)
	Events.awaiting_input.emit(&"desk_shift", {"options": opts, "open": opened, "best": _picker_pick - 1,
		"mouse": {"click": "desk_shift_%d" % _picker_pick}}, func() -> void:
			if serial == _beat_serial:
				pick_shift(_picker_pick))
	_shot_once("desk_picker")
	var id: int = await _shift_picked
	_beat_serial += 1
	Events.input_resolved.emit(&"desk_shift")
	layer.queue_free()
	_fields.erase(layer)
	_phase = "intro"
	return id


func _picker_key(code: int, physical: int) -> void:
	if code == KEY_T or code == KEY_ESCAPE:
		Events.goto_scene.emit(HALL_SCENE)
		return
	var d := code
	if (d < KEY_1 or d > KEY_9) and (d < KEY_KP_1 or d > KEY_KP_9):
		d = physical
	if d >= KEY_1 and d <= KEY_3:
		pick_shift(d - KEY_0)
	elif d >= KEY_KP_1 and d <= KEY_KP_3:
		pick_shift(d - KEY_KP_0)
	elif code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE:
		pick_shift(_picker_pick)


static func _lock_text(id: int) -> String:
	return "Coming soon" if id > DeskRun.PLAYABLE else "Finish Shift %d safely\n(8+ files)" % (id - 1)


static func _shift_blurb(id: int) -> String:
	match id:
		1:
			return "Ticks and one ear worse"
		2:
			return "+ the air-bone gap,\nwax, ear shape"
	return "+ DOCTOR TODAY\nand the alarm clock"


static func _best_score(id: int) -> int:
	var best := 0
	for r: Variant in ArcadeScores.data(MODE).get("runs", []):
		if r is Dictionary and int((r as Dictionary).get("shift", 1)) == id:
			best = maxi(best, int((r as Dictionary).get("score", 0)))
	return best


# ================================================================ motion

func _slide_in(view: FileView) -> void:
	view.visible = true
	view.modulate.a = 1.0
	view.scale = Vector2.ONE
	view.rotation = 0.0
	view.position = FILE_RECT.position + Vector2(-260, -120)
	view.modulate.a = 0.0
	var tw := view.move().set_parallel(true)
	var trans := Tween.TRANS_SINE if _reduced() else Tween.TRANS_BACK
	tw.tween_property(view, "position", FILE_RECT.position, 0.3).set_trans(trans).set_ease(Tween.EASE_OUT)
	tw.tween_property(view, "modulate:a", 1.0, 0.15)
	Sfx.play(&"whoosh", 1.4, -16.0)


func _slide_out(view: FileView) -> void:
	var tw := view.move().set_parallel(true)
	tw.tween_property(view, "position", FILE_RECT.position + Vector2(160, 380), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(view, "modulate:a", 0.0, 0.25).set_delay(0.05)
	tw.chain().tween_callback(view.hide)


func _park(view: FileView) -> void:
	_step = ""
	var tw := view.move()
	tw.tween_property(view, "modulate:a", 0.0, 0.3)
	tw.tween_callback(view.hide)


## The referral letter (or, for DOCTOR TODAY, the phone call) flies from the file out of the window.
func _send_letter(s: StringName = &"refer") -> void:
	var g := Glyph.new(s)
	_fx.add_child(g)
	var from := _view.position + FileView.PRINT_AT + Vector2(40, 40)
	g.position = from
	var to := WINDOW_RECT.get_center() + Vector2(60, -40) - g.size * 0.5
	var tw := g.create_tween().set_parallel(true)
	if _reduced():
		g.position = to
		g.modulate.a = 0.0
		tw.tween_property(g, "modulate:a", 1.0, 0.2)
		tw.chain().tween_property(g, "modulate:a", 0.0, 0.3)
	else:
		tw.tween_property(g, "position", to, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(g, "rotation", -0.6, 0.5)
		tw.tween_property(g, "modulate:a", 0.0, 0.2).set_delay(0.4)
	tw.chain().tween_callback(g.queue_free)


func _flash_word(text: String, at: Vector2) -> void:
	var l := UiKit.label(text, 28, Palette.SUNNY, 700, 10, Palette.INK)
	_fx.add_child(l)
	l.reset_size()
	l.position = at - l.size * 0.5
	l.rotation = -0.08
	if not _reduced():
		Juice.pop(l, 1.5, 0.2)
	var tw := l.create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(l, "modulate:a", 0.0, 0.15)
	tw.tween_callback(l.queue_free)


## A short message over the stamps (a locked stamp, a key at the wrong moment): words, not just a
## shake, so it reads with reduced motion and the sound off.
func _flash_right(text: String) -> void:
	var l := UiKit.label(text, 18, Palette.PAPER, 700, 8, Palette.INK)
	_fx.add_child(l)
	l.reset_size()
	l.position = Vector2(RIGHT_COL.get_center().x - l.size.x * 0.5, RIGHT_COL.position.y - 6)
	var tw := l.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _flash_banner(text: String, color: Color, hold := 0.6, at := Vector2(-1, -1)) -> void:
	if at.x < 0.0:
		at = FILE_RECT.get_center()
	for tw: Tween in [_banner_tw, _banner_pop]:
		if tw != null and tw.is_valid():
			tw.kill()
	var long := text.length() > 5
	var pop := 1.2 if long else 1.6
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.add_theme_font_size_override("font_size", 64 if long else 84)
	_banner.visible = true
	_banner.modulate.a = 1.0
	_banner.scale = Vector2.ONE
	_banner.reset_size()
	var grow := _banner.size.x * (pop - 1.0) * 0.5
	_banner.position = Vector2(clampf(at.x - _banner.size.x * 0.5, 8.0 + grow, FIELD.x - 8.0 - grow - _banner.size.x), at.y - _banner.size.y * 0.5)
	_banner.pivot_offset = _banner.size * 0.5
	_banner_pop = Juice.pop(_banner, pop, 0.25)
	_banner_tw = _banner.create_tween()
	_banner_tw.tween_interval(hold)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.25)


# ================================================================ building

var _panel_box: PanelContainer
var _note_title_l: Label
var _note_points_l: Label
var _note_line_l: Label
var _note_lesson_l: Label
var _prove_box: VBoxContainer
var _prove_ask: Label
var _note_box: VBoxContainer


func _build() -> void:
	_bg = UiKit.full_rect()
	_bg.draw.connect(_draw_bg.bind(_bg))
	add_child(_bg)
	_field = _new_field()
	_top = UiKit.full_rect()
	_top.draw.connect(_draw_top)
	_field.add_child(_top)
	_wall = UiKit.full_rect()
	_wall.draw.connect(_draw_wall)
	_field.add_child(_wall)
	_side = UiKit.full_rect()
	_side.draw.connect(_draw_side)
	_field.add_child(_side)
	for i in 2:
		var v := FileView.new()
		v.visible = false
		_field.add_child(v)
		v.setup()
		_views.append(v)
	_view = _views[0]
	for i in STAMP_ORDER.size():
		var s := STAMP_ORDER[i]
		var sv := StampView.new(s, i + 1)
		sv.position = RIGHT_COL.position + Vector2(0, i * (STAMP_SIZE.y + 12))
		sv.picked.connect(stamp)
		_field.add_child(sv)
		_stamps[s] = sv
		Hoot.register_anchor("desk_stamp_" + String(s), sv)
	_panel = UiKit.full_rect()
	_field.add_child(_panel)
	_build_right_panel()
	_help_btn = UiKit.button("HOOT HELP  [H]" if UiKit.show_key_hints() else "HOOT HELP", &"", Vector2(300, 54))
	_help_btn.position = Vector2(16, 652)
	_help_btn.size = Vector2(300, 54)
	_help_btn.pressed.connect(press_help)
	_field.add_child(_help_btn)
	Hoot.register_anchor("desk_help", _help_btn)
	_skip_btn = UiKit.button("Skip  [S]" if UiKit.show_key_hints() else "Skip warm-up", &"", Vector2(150, 34))
	_skip_btn.add_theme_font_size_override("font_size", 16)
	_skip_btn.position = Vector2(736, 24)
	_skip_btn.size = Vector2(150, 34)
	_skip_btn.visible = false
	_skip_btn.pressed.connect(skip_warmup)
	_field.add_child(_skip_btn)
	_fx = UiKit.full_rect()
	_field.add_child(_fx)
	_banner = UiKit.label("", 84, Palette.SUNNY, 700, 18, Palette.INK)
	_banner.visible = false
	_field.add_child(_banner)


## The right column's PROVE IT and note panels (the stamps hide while one is up).
func _build_right_panel() -> void:
	_panel_box = UiKit.panel(Palette.PAPER, Palette.INK, 18)
	_panel_box.add_theme_stylebox_override("panel", UiKit.style(Palette.PAPER, Palette.INK, 18, 4, 6, 12))
	_panel_box.position = RIGHT_COL.position
	_panel_box.custom_minimum_size = RIGHT_COL.size
	_panel_box.size = RIGHT_COL.size
	_panel_box.visible = false
	_panel.add_child(_panel_box)
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_box.add_child(stack)
	_prove_box = VBoxContainer.new()
	_prove_box.add_theme_constant_override("separation", 10)
	_prove_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_prove_box)
	_prove_box.add_child(UiKit.label("PROVE IT!", 28, Palette.CORAL, 700))
	_prove_ask = UiKit.label("Point at the reason: a YES box, or a column on the chart.", 17, Palette.INK, 600)
	_prove_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prove_ask.custom_minimum_size = Vector2(146, 0)
	_prove_box.add_child(_prove_ask)
	if UiKit.show_key_hints():
		# arrow keys as words: the game font has no arrow glyphs (the web build can't fall back)
		_prove_box.add_child(UiKit.hint_row([["Left"], ["Right"]], 15))
		_prove_box.add_child(UiKit.hint_row([["Up"], ["Down"]], 15))
		_prove_box.add_child(UiKit.label("move", 15, Palette.INK_SOFT, 500))
		_prove_box.add_child(UiKit.hint_row([["Enter"]], 15))
		_prove_box.add_child(UiKit.label("point (or click)", 15, Palette.INK_SOFT, 500))
	_note_box = VBoxContainer.new()
	_note_box.add_theme_constant_override("separation", 8)
	_note_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_note_box)
	_note_title_l = UiKit.label("", 21, Palette.CORAL, 700)
	_note_title_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_title_l.custom_minimum_size = Vector2(146, 0)
	_note_box.add_child(_note_title_l)
	_note_points_l = UiKit.label("", 30, Palette.CORAL, 700)
	_note_box.add_child(_note_points_l)
	_note_line_l = UiKit.label("", 17, Palette.INK, 600)
	_note_line_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_line_l.custom_minimum_size = Vector2(146, 0)
	_note_box.add_child(_note_line_l)
	_note_lesson_l = UiKit.label("", 15, Palette.INK_SOFT, 600)
	_note_lesson_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_lesson_l.custom_minimum_size = Vector2(146, 0)
	_note_box.add_child(_note_lesson_l)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_note_box.add_child(spacer)
	_note_btn = UiKit.button("Next  [Enter]" if UiKit.show_key_hints() else "Next", &"AccentButton", Vector2(146, 50))
	_note_btn.add_theme_font_size_override("font_size", 17)   # fits the 150 px column with its margins
	_note_btn.pressed.connect(func() -> void:
		_note_at = -INF
		close_note())
	_note_box.add_child(_note_btn)
	Hoot.register_anchor("desk_note_ok", _note_btn)


func _show_right(mode: String) -> void:
	for s: StringName in _stamps:
		_stamps[s].visible = mode == "stamps"
	_panel_box.visible = mode != "stamps"
	_prove_box.visible = mode == "prove"
	_note_box.visible = mode == "note"
	if mode == "note":
		_note_title_l.text = _note_title
		_note_title_l.add_theme_color_override("font_color", _note_color)
		_note_points_l.visible = _note_points != 0
		_note_points_l.text = ("+%s" if _note_points > 0 else "%s") % _thousands(_note_points)
		_note_points_l.add_theme_color_override("font_color", Palette.MINT if _note_points > 0 else Palette.CORAL)
		_note_line_l.text = _note_line
		_note_line_l.visible = _note_line != ""
		_note_lesson_l.text = ("Hoot: " + _note_lesson) if _note_lesson != "" and _note_line != "" else _note_lesson
		_note_lesson_l.add_theme_font_size_override("font_size", 15 if _note_line != "" else 18)
		_note_lesson_l.add_theme_color_override("font_color", Palette.INK_SOFT if _note_line != "" else Palette.INK)
		_note_lesson_l.visible = _note_lesson != ""


func _new_field() -> Control:
	var f := Control.new()
	f.size = FIELD
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	_fields.append(f)
	return f


## The wall, the desk and the top band, across the whole window.
func _draw_bg(ci: Control) -> void:
	var full := ci.size
	var o := _field.position
	ci.draw_rect(Rect2(Vector2.ZERO, full), WALL)
	ci.draw_rect(Rect2(0, o.y + DESK_Y, full.x, full.y - o.y - DESK_Y), DESK)
	ci.draw_rect(Rect2(0, o.y + DESK_Y, full.x, 6), Palette.INK)
	for i in 6:
		var y := o.y + DESK_Y + 60 + i * 80
		if y < full.y:
			ci.draw_line(Vector2(0, y), Vector2(full.x, y + 6), DESK_EDGE, 2.0)
	ci.draw_rect(Rect2(0, 0, full.x, o.y + TOP_H), TOP_BAND)


func _draw_top() -> void:
	var f := _font()
	_top.draw_string(f, Vector2(22, 46), "EARS, PLEASE!", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.SUNNY)
	if not _sh.is_empty():
		_top.draw_string(UiKit.font(600), Vector2(24, 72), "SHIFT %d · %s" % [_shift_id, String(_sh["title"]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(Palette.PAPER, 0.75))
	var bar := Rect2(330, 24, 560, 34)
	UiDraw.rounded_rect(_top, bar, Color("#4a4363"), 17)
	if _phase == "run" or _phase == "tally" or _phase == "results":
		var left := maxf(0.0, DeskRules.SHIFT_S - maxf(_t, 0.0))
		var frac := left / DeskRules.SHIFT_S
		var col := Palette.MINT if left > 15.0 else Palette.CORAL
		if frac > 0.0:
			UiDraw.rounded_rect(_top, Rect2(bar.position, Vector2(maxf(34.0, bar.size.x * frac), bar.size.y)), col, 17)
		var secs := ("%d" % ceili(left)) + ("   CLOCK STOPPED: read the note" if _held else "")
		var at := bar.position + Vector2(0, 26)
		_top.draw_string_outline(f, at, secs, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 22, 6, Palette.INK)
		_top.draw_string(f, at, secs, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x, 22, Palette.PAPER)
	else:
		var room := bar.size.x - (156.0 if _skip_btn.visible else 0.0)   # the Skip button sits at the bar's right end
		_top.draw_string(f, bar.position + Vector2(0, 25), "WARM-UP: THE DESK ISN'T OPEN YET", HORIZONTAL_ALIGNMENT_CENTER, room, 19, Palette.PAPER)
	_top.draw_string(UiKit.font(600), Vector2(906, 34), "SCORE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.PAPER, 0.7))
	_top.draw_string(f, Vector2(906, 68), _thousands(maxi(0, int(_shown_score))), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Palette.PAPER)
	var clean := int(_counts.get(DeskRules.CLEAN, 0))
	_top.draw_string(UiKit.font(600), Vector2(1046, 34), "CLEAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.MINT, 0.9))
	_top.draw_string(f, Vector2(1046, 68), str(clean), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Palette.MINT)
	_top.draw_string(UiKit.font(600), Vector2(1130, 34), "SLIPS", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(Palette.CORAL, 0.9))
	_top.draw_string(f, Vector2(1130, 68), str(_files - clean), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Palette.CORAL)


## The window with the patient, the wall's rule cards and the wall clock.
func _draw_wall() -> void:
	var f := _font()
	# the window
	var boss := String(_file.get("boss", "")) != ""
	UiDraw.rounded_rect(_wall, WINDOW_RECT.grow(8), GOLD if boss else Palette.WOOD, 16, 3, Palette.INK)
	_wall.draw_rect(WINDOW_RECT, Color("#d9e6ff"))
	for i in 7:
		_wall.draw_line(WINDOW_RECT.position + Vector2(i * 50, 0), WINDOW_RECT.position + Vector2(i * 50, WINDOW_RECT.size.y), Color("#c9d8f5"), 6.0)
	if not _file.is_empty() and _step != "":
		var c := WINDOW_RECT.get_center() + Vector2(0, 14)
		var r := 54.0
		if _window_fx.has("wave") and not _reduced():
			c.x += sin(float(_window_fx["wave"]) * TAU * 2.0) * 6.0
		Portraits.draw(_wall, String(_file.get("who", "")), c, r, false, false, true)
		if _window_fx.has("aids") or (_step == "busy" and _view != null and _view.goal != ""):
			var k := clampf(float(_window_fx.get("aids", 1.0)) * 3.0, 0.0, 1.0)
			for side in [-1.0, 1.0]:
				DeskArt.aid(_wall, c + Vector2(side * r * 0.92, -r * 0.1), 18.0 * (k if not _reduced() else 1.0), DeskArt.INK, side > 0.0)
		if _window_fx.has("sparkle"):
			var t := float(_window_fx["sparkle"])
			var rr := r + 10.0 + (0.0 if _reduced() else 30.0 * t)
			for i in 8:
				var a := i * TAU / 8.0 + (0.0 if _reduced() else t)
				UiDraw.star(_wall, c + Vector2(cos(a), sin(a)) * rr, 7.0, Color(Palette.SUNNY, 1.0 - t * 0.7))
	# the rule cards
	var open: Array = _sh.get("rules", ["tick", "one_ear"])
	var hx := 330.0
	UiDraw.rounded_rect(_wall, Rect2(hx, 88, CARD_SIZE.x * 3 + 22, 22), Palette.CORAL, 8, 2, Palette.INK)
	_wall.draw_string(f, Vector2(hx, 105), "RED FLAGS: A DOCTOR FIRST, SO REFER", HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x * 3 + 22, 16, Palette.PAPER)
	if open.has("sudden"):
		var sx := 330.0 + 3 * (CARD_SIZE.x + 11)
		UiDraw.rounded_rect(_wall, Rect2(sx, 88, CARD_SIZE.x, 22), STAMP_INK[&"today"], 8, 2, Palette.INK)
		_wall.draw_string(f, Vector2(sx, 105), "THE ALARM CLOCK", HORIZONTAL_ALIGNMENT_CENTER, CARD_SIZE.x, 16, Palette.PAPER)
	for i in CARD_SLOTS.size():
		var id := CARD_SLOTS[i]
		var r := Rect2(Vector2(330 + i * (CARD_SIZE.x + 11), CARD_Y), CARD_SIZE)
		var info: Dictionary = DeskRules.RULES[id]
		if not open.has(id):
			UiDraw.rounded_rect(_wall, r, Color("#4a4363"), 14, 3, Palette.INK)
			_wall.draw_string(f, r.position + Vector2(0, 58), "?", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 40, Color(Palette.PAPER, 0.5))
			_wall.draw_string(f, r.position + Vector2(0, 92), String(info["title"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(Palette.PAPER, 0.7))
			_wall.draw_string(f, r.position + Vector2(0, 118), "SHIFT 2" if id == "gap" else "SHIFT 3", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Palette.SUNNY)
			continue
		var fx: Dictionary = _card_fx.get(id, {})
		UiDraw.rounded_rect(_wall, r, Palette.PAPER, 14, 3, Palette.INK)
		if not fx.is_empty():
			var k := clampf(float(fx["t"]), 0.0, 1.0)
			UiDraw.rounded_rect(_wall, r, Color(fx["col"], 0.35 * k), 14, 5, Color(fx["col"], k))
		if id == "sudden":
			_draw_sudden_card(r, info, fx)
			continue
		DeskArt.rule(_wall, id, r.position + Vector2(r.size.x * 0.5 - 14, 38), 28.0)
		_wall.draw_string(f, r.position + Vector2(0, 88), String(info["title"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 17, Palette.INK)
		_wall.draw_string(UiKit.font(600), r.position + Vector2(0, 108), String(info["sub"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14 if String(info["sub"]).length() > 22 else 15, Palette.INK_SOFT)
		var stamp_id: StringName = info["stamp"]
		var cw := maxf(104.0, f.get_string_size(CaseRules.DECISION_STAMPS[stamp_id], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0)
		var chip := Rect2(r.position + Vector2(r.size.x * 0.5 - cw * 0.5, 116), Vector2(cw, 20))
		UiDraw.rounded_rect(_wall, chip, STAMP_FACE[stamp_id], 8, 2, Palette.INK)
		_wall.draw_string(f, chip.position + Vector2(0, 16), CaseRules.DECISION_STAMPS[stamp_id], HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 14, Palette.INK)
		if String(fx.get("mark", "")) == "check":
			UiDraw.check(_wall, r.position + Vector2(r.size.x - 22, 22), 22.0, Palette.MINT, 5.0)
	# the wall clock: 9:00 to 11:00 over the shift (one second a clock minute)
	var t := clampf(_t, 0.0, DeskRules.SHIFT_S) if _phase == "run" or _phase == "tally" or _phase == "results" else 0.0
	var late := _phase == "run" and DeskRules.SHIFT_S - t <= 15.0
	_wall.draw_circle(CLOCK_C, CLOCK_R + 6, Palette.CORAL if late else Palette.INK)
	_wall.draw_circle(CLOCK_C, CLOCK_R, Palette.PAPER)
	for i in 12:
		var a := i * TAU / 12.0
		_wall.draw_line(CLOCK_C + Vector2(sin(a), -cos(a)) * (CLOCK_R - 10), CLOCK_C + Vector2(sin(a), -cos(a)) * (CLOCK_R - 3), Palette.INK, 3.0)
	var minutes := 9.0 * 60.0 + t
	var ha := fmod(minutes / 60.0, 12.0) / 12.0 * TAU
	var ma := fmod(minutes, 60.0) / 60.0 * TAU
	_wall.draw_line(CLOCK_C, CLOCK_C + Vector2(sin(ha), -cos(ha)) * CLOCK_R * 0.5, Palette.INK, 6.0)
	_wall.draw_line(CLOCK_C, CLOCK_C + Vector2(sin(ma), -cos(ma)) * CLOCK_R * 0.8, Palette.INK, 4.0)
	_wall.draw_circle(CLOCK_C, 5.0, Palette.CORAL)
	var clock_txt := "%d:%02d" % [int(minutes / 60.0), int(fmod(minutes, 60.0))]
	_wall.draw_string(f, CLOCK_C + Vector2(-40, 34), clock_txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 15, Palette.INK_SOFT)


## The SUDDEN LOSS card: the clock and its title, then both calls the alarm clock can make, each with its
## stamp (DeskRules.SUDDEN_ROWS). A lit card marks the line that fits the file.
func _draw_sudden_card(r: Rect2, info: Dictionary, fx: Dictionary) -> void:
	var f := _font()
	DeskArt.alarm_clock(_wall, r.position + Vector2(28, 30), 28.0)
	_wall.draw_string(f, r.position + Vector2(48, 28), String(info["title"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 54, 16, Palette.INK)
	_wall.draw_string(UiKit.font(600), r.position + Vector2(48, 45), String(info["sub"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 54, 13, Palette.INK_SOFT)
	for i in DeskRules.SUDDEN_ROWS.size():
		var row: Array = DeskRules.SUDDEN_ROWS[i]
		var stamp_id: StringName = row[1]
		var y := 66.0 + i * 42.0
		_wall.draw_string(UiKit.font(600), r.position + Vector2(0, y), String(row[0]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Palette.INK)
		var word: String = CaseRules.DECISION_STAMPS[stamp_id]
		var cw := maxf(104.0, f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0)
		var chip := Rect2(r.position + Vector2(r.size.x * 0.5 - cw * 0.5, y + 5), Vector2(cw, 19))
		var lit := not fx.is_empty() and StringName(fx.get("row", &"")) == stamp_id
		if lit:
			UiDraw.rounded_rect(_wall, chip.grow(3), Color(0, 0, 0, 0), 10, 3, Color(fx["col"], clampf(float(fx["t"]), 0.0, 1.0)))
		UiDraw.rounded_rect(_wall, chip, STAMP_FACE[stamp_id], 8, 2, Palette.INK)
		_wall.draw_string(f, chip.position + Vector2(0, 15), word, HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 14, Palette.INK)
		if lit and String(fx.get("mark", "")) == "check":
			UiDraw.check(_wall, Vector2(chip.end.x + 14, chip.get_center().y), 18.0, Palette.MINT, 4.0)


## The left column under the window: name, the patient's line, the combo.
func _draw_side() -> void:
	var f := _font()
	if not _file.is_empty() and _step != "":
		var plate := Rect2(36, 262, 260, 30)
		UiDraw.rounded_rect(_side, plate, Palette.PAPER, 10, 3, Palette.INK)
		_side.draw_string(f, plate.position + Vector2(0, 22), "%s, %d" % [String(_file.get("name", "")), int(_file.get("age", 0))], HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 17, Palette.INK)
		var boss := String(_file.get("boss", "")) != ""
		var bubble := Rect2(16, 298, 300, 54)
		UiDraw.rounded_rect(_side, bubble, Palette.PAPER, 16, 3, GOLD if boss else Palette.INK)
		_side.draw_multiline_string(UiKit.font(600), bubble.position + Vector2(12, 22), "\"%s\"" % String(_file.get("line", "")), HORIZONTAL_ALIGNMENT_LEFT, bubble.size.x - 24, 15, 2, Palette.INK)
	var box := Rect2(16, 494, 300, 100)
	UiDraw.rounded_rect(_side, box, Palette.PAPER, 18, 4, Palette.INK)
	var mult := ClinicRules.combo_multiplier(_combo)
	_side.draw_string(UiKit.font(600), box.position + Vector2(18, 30), "COMBO", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK_SOFT)
	_side.draw_string(f, box.position + Vector2(18, 82), str(_combo), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Palette.INK)
	if mult > 1:
		var flame := box.position + Vector2(220, 56)
		var wob := 0.0 if _reduced() else sin(Game.clock * 1000.0 / 90.0) * 3.0
		_side.draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -36 - wob), flame + Vector2(26, 0), flame + Vector2(16, 28), flame + Vector2(-16, 28), flame + Vector2(-26, 0)]), Palette.SELECT_ORANGE)
		_side.draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -14 - wob), flame + Vector2(12, 8), flame + Vector2(0, 26), flame + Vector2(-12, 8)]), Palette.SUNNY)
		_side.draw_string(f, flame + Vector2(-40, 42), "x%d" % mult, HORIZONTAL_ALIGNMENT_CENTER, 80, 24, Palette.INK)
	else:
		_side.draw_string(UiKit.font(500), box.position + Vector2(110, 62), "3 clean in a row = x2", HORIZONTAL_ALIGNMENT_LEFT, 180, 16, Palette.INK_SOFT)
	var missed := int(_counts.get(DeskRules.MISSED_FLAG, 0))
	if bool(_sh.get("sudden", false)):
		# shift 3: red flags missed, and same-day patients sent home (the second closes the desk)
		var today := int(_counts.get(DeskRules.MISSED_TODAY, 0))
		for i in 2:
			var b := Rect2(16 + i * 154, 602, 146, 40)
			var n := missed if i == 0 else today
			UiDraw.rounded_rect(_side, b, Color(Palette.PAPER, 0.8), 12, 2, Color(Palette.INK, 0.4))
			_side.draw_string(UiKit.font(600), b.position + Vector2(10, 26), "FLAGS MISSED" if i == 0 else "TODAY MISSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_SOFT)
			_side.draw_string(f, b.position + Vector2(0, 28), str(n) if i == 0 else "%d/%d" % [n, DeskRules.MAX_INCIDENTS], HORIZONTAL_ALIGNMENT_RIGHT, b.size.x - 10, 20, Palette.CORAL if n > 0 else Palette.INK_SOFT)
		return
	var inc := Rect2(16, 602, 300, 40)
	UiDraw.rounded_rect(_side, inc, Color(Palette.PAPER, 0.8), 12, 2, Color(Palette.INK, 0.4))
	_side.draw_string(UiKit.font(600), inc.position + Vector2(14, 27), "RED FLAGS MISSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)
	_side.draw_string(f, inc.position + Vector2(0, 29), str(missed), HORIZONTAL_ALIGNMENT_RIGHT, inc.size.x - 16, 24, Palette.CORAL if missed > 0 else Palette.INK_SOFT)


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
	for s: StringName in _stamps:
		_stamps[s].visible = false
	_panel_box.visible = false
	var st := stats()
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := _new_field()
	_layout()
	var panel := UiKit.panel(Palette.PAPER, Palette.INK, 28)
	panel.position = Vector2(130, 24)
	panel.custom_minimum_size = Vector2(1020, 0)
	layer.add_child(panel)
	_results = panel
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	col.add_child(head)
	head.add_child(UiKit.label("TWO WENT HOME!" if _closed else "CLOSING TIME!", 42, Palette.CORAL, 700))   # the rank says "Desk Closed"
	var rank := String(st["rank"])
	var rank_col := VBoxContainer.new()
	rank_col.add_child(UiKit.label(rank, 32, Palette.INK, 700))
	rank_col.add_child(UiKit.label(String(DeskRun.RANK_LINES.get(rank, "")), 17, Palette.INK_SOFT, 500))
	head.add_child(rank_col)
	var nums := HBoxContainer.new()
	nums.add_theme_constant_override("separation", 30)
	col.add_child(nums)
	var clean := int(st["clean"])
	var acc := float(st["accuracy"])
	nums.add_child(_stat("FILES", str(_files), Palette.INK))
	nums.add_child(_stat("CLEAN", ("%d  (%d%%)" % [clean, roundi(acc * 100.0)]) if acc >= 0.0 else "–", Palette.MINT))
	nums.add_child(_stat("RED FLAGS MISSED", str(int(st["missed_flag"])), Palette.CORAL))
	if bool(_sh.get("sudden", false)):
		nums.add_theme_constant_override("separation", 22)
		nums.add_child(_stat("TODAY MISSED", str(int(st["missed_today"])), Palette.CORAL))
	nums.add_child(_stat("EXTRA REFERRALS", str(int(st["over"])), Palette.SELECT_ORANGE))
	nums.add_child(_stat("BEST COMBO", str(_best_combo), Palette.INK))
	nums.add_child(_stat("SCORE", _thousands(int(st["score"])), Palette.INK))
	var gate := ""
	var gate_col := Palette.INK_SOFT
	if _promoted_now and _shift_id < DeskRun.PLAYABLE:
		gate = "PROMOTED! Shift %d, %s, is open." % [_shift_id + 1, String(DeskRules.shift(_shift_id + 1)["title"])]
		gate_col = Palette.MINT
		Sfx.play(&"kaching", 1.0, -4.0)
	elif _shift_id < DeskRun.PLAYABLE and _unlocked() <= _shift_id:
		gate = "Promotion to Shift %d needs %s." % [_shift_id + 1, DeskRun.promotion_needs(st)]
	elif not bool(st["safe"]) and _files > 0:
		if bool(_sh.get("sudden", false)):
			gate = "The board takes shifts with no red flag or same-day patient missed, 3 in 4 clean."
		else:
			gate = "The board takes shifts with no red flag missed and 3 in 4 calls clean."
		gate_col = Palette.CORAL
	if gate != "":
		col.add_child(UiKit.label(gate, 20, gate_col, 700))
	if _helps > 0:
		col.add_child(UiKit.label("Hoot helped %d time%s (no points; a helped file is not a clean read)." % [_helps, "" if _helps == 1 else "s"], 17, Palette.INK_SOFT, 500))
	if _boss_seen:
		col.add_child(UiKit.label("VIP: %s" % ("handled by the book. Read the file, not the pleading!" if _boss_clean else "they talked you round. Read the file, not the pleading."), 17, Palette.INK_SOFT, 500))
	var mid := HBoxContainer.new()
	mid.add_theme_constant_override("separation", 30)
	col.add_child(mid)
	var miss := Control.new()
	var rows := DeskRun.ROWS.keys().filter(func(r: String) -> bool: return _marks.has(r)).size()
	miss.custom_minimum_size = Vector2(500, 30 + rows * 38 + 64)   # rows, a two-line tip, the legend
	miss.draw.connect(_draw_breakdown.bind(miss))
	mid.add_child(miss)
	var board := VBoxContainer.new()
	board.custom_minimum_size = Vector2(440, 200)
	mid.add_child(board)
	col.add_child(UiKit.label("Practice, not a qualification. Real clinics follow their own referral rules, and a doctor makes the diagnosis.", 16, Palette.INK_SOFT, 500))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	col.add_child(buttons)
	var hints := UiKit.show_key_hints()
	_again_btn = UiKit.button("Play again  [Enter]" if hints else "Play again", &"AccentButton", Vector2(250, 54))
	_shifts_btn = UiKit.button("Shifts  [S]" if hints else "Shifts", &"", Vector2(170, 54))
	_back_btn = UiKit.button("Back to the arcade  [T]" if hints else "Back to the arcade", &"", Vector2(300, 54))
	buttons.add_child(_again_btn)
	buttons.add_child(_shifts_btn)
	buttons.add_child(_back_btn)
	_again_btn.pressed.connect(func() -> void:
		again_shift = _shift_id
		Events.goto_scene.emit(scene_file_path))
	_shifts_btn.pressed.connect(func() -> void:
		again_shift = 0
		Events.goto_scene.emit(scene_file_path))
	_back_btn.pressed.connect(func() -> void: Events.goto_scene.emit(HALL_SCENE))
	for b: Button in [_again_btn, _shifts_btn, _back_btn]:
		b.visible = false
	Juice.bounce_in(panel)
	await get_tree().create_timer(0.6, false).timeout
	_shot_once("desk_results")
	var placed := -1
	var key := DeskRun.board(_shift_id)
	if bool(st["safe"]) and ArcadeScores.qualifies(MODE, int(st["score"]), key):
		var initials: String = await _enter_initials(board)
		placed = ArcadeScores.add_score(MODE, initials, int(st["score"]), maxf(0.0, acc), key)
	_fill_board(board, placed, key)
	_again_btn.visible = true
	_shifts_btn.visible = mini(_unlocked(), DeskRun.PLAYABLE) > 1
	_back_btn.visible = true
	_results_keys_at = Game.clock
	await get_tree().create_timer(0.3, false).timeout
	_shot_once("desk_board")
	Events.awaiting_input.emit(&"arcade_results", {"options": ["Play again", "Shifts", "Back to the arcade"], "best": 2,
		"mouse": {"text": "Back to the arcade"}}, func() -> void: Events.goto_scene.emit(HALL_SCENE))


func _stat(label: String, value: String, color: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(UiKit.label(label, 15, Palette.INK_SOFT, 600))
	v.add_child(UiKit.label(value, 36, color, 700))
	return v


func _fill_board(board: VBoxContainer, placed: int, key: String) -> void:
	board.add_child(UiKit.label("HIGH SCORES · SHIFT %d" % _shift_id, 20, Palette.INK, 700))
	var t := ArcadeScores.table(MODE, key)
	for i in mini(t.size(), 5):
		var row: Dictionary = t[i]
		var mine := i == placed
		board.add_child(UiKit.label("%d.  %s   %s   %d%%" % [i + 1, row["initials"], _thousands(int(row["score"])), roundi(float(row["accuracy"]) * 100.0)],
			20, Palette.SELECT_ORANGE if mine else Palette.INK, 700 if mine else 600))
	if placed >= 5:
		board.add_child(UiKit.label("%d.  %s   %s" % [placed + 1, t[placed]["initials"], _thousands(int(t[placed]["score"]))], 20, Palette.SELECT_ORANGE, 700))


## WHAT YOU MISSED (EVERY FILE on a clean shift): one row per kind of file met this shift, a mark per file (a tick clean, ~ wrong
## proof, + extra referral, a cross missed, ? helped) and the row with the most trouble tinted,
## with its tip. The tick and cross are drawn, not typed: the game font has no such glyphs.
func _draw_breakdown(c: Control) -> void:
	var f := _font()
	var y := 30.0
	var worst := ""
	var worst_n := 0
	for row: String in DeskRun.ROWS:
		var bad := 0
		for m: String in _marks.get(row, []):
			if m != "clean":
				bad += 1
		if bad > worst_n:
			worst_n = bad
			worst = row
	c.draw_string(f, Vector2(0, 18), "WHAT YOU MISSED" if worst != "" else "EVERY FILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK)
	for row: String in DeskRun.ROWS:
		var marks: Array = _marks.get(row, [])
		if marks.is_empty():
			continue
		var r := Rect2(0, y, c.size.x, 32)
		UiDraw.rounded_rect(c, r, Color(Palette.CORAL, 0.14) if row == worst else Color("#ffffff"), 10, 2, Color(Palette.INK, 0.25))
		c.draw_string(f, r.position + Vector2(10, 22), String(DeskRun.ROWS[row]), HORIZONTAL_ALIGNMENT_LEFT, 170, 15, Palette.INK)
		var x := 186.0
		var good := marks.count("clean")
		for m: String in marks.slice(0, 12):
			_draw_mark(c, m, Vector2(x, r.get_center().y))
			x += 18.0
		if marks.size() > 12:
			c.draw_string(f, Vector2(x - 6, r.position.y + 22), "…", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.INK_SOFT)
		c.draw_string(f, Vector2(r.end.x - 70, r.position.y + 22), "%d of %d" % [good, marks.size()], HORIZONTAL_ALIGNMENT_RIGHT, 60, 15, Palette.INK_SOFT)
		y += 38.0
	if worst != "":
		c.draw_multiline_string(UiKit.font(600), Vector2(0, y + 16), "Blind spot: %s. %s" % [String(DeskRun.ROWS[worst]), String(DeskRun.ROW_TIPS[worst])], HORIZONTAL_ALIGNMENT_LEFT, c.size.x, 15, 2, Palette.CORAL)
	elif _files > 0:
		c.draw_string(UiKit.font(600), Vector2(0, y + 16), "Every file by the book. Nice reading!", HORIZONTAL_ALIGNMENT_LEFT, c.size.x, 15, Palette.MINT)
	var lx := 8.0
	for it: Array in [["clean", "clean"], ["half", "wrong proof"], ["extra", "extra referral"], ["miss", "missed"], ["help", "helped"]]:
		_draw_mark(c, String(it[0]), Vector2(lx, c.size.y - 9), 0.8)
		var w := String(it[1])
		c.draw_string(UiKit.font(500), Vector2(lx + 10, c.size.y - 4), w, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.INK_SOFT)
		lx += 30.0 + UiKit.font(500).get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x


## One breakdown mark: a tick (clean), ~ (right stamp, wrong proof), + (extra referral), a cross
## (a missed red flag) or ? (Hoot helped).
func _draw_mark(c: Control, m: String, at: Vector2, k := 1.0) -> void:
	var f := _font()
	match m:
		"clean":
			UiDraw.check(c, at, 14.0 * k, Palette.MINT, 3.5 * k)
		"miss":
			UiDraw.cross(c, at, 12.0 * k, Palette.CORAL, 3.5 * k)
		"help":
			c.draw_string(f, at + Vector2(-5, 6) * k, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * k), Palette.INK_SOFT)
		"extra":
			c.draw_string(f, at + Vector2(-6, 7) * k, "+", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * k), Palette.SELECT_ORANGE)
		_:
			c.draw_string(f, at + Vector2(-6, 7) * k, "~", HORIZONTAL_ALIGNMENT_LEFT, -1, int(22 * k), Palette.SELECT_ORANGE)


## (coroutine) Three letters: type them, or click the arrows; Enter or OK. Returns the initials.
func _enter_initials(board: VBoxContainer) -> String:
	var box := VBoxContainer.new()
	board.add_child(box)
	box.add_child(UiKit.label("NEW HIGH SCORE! Your initials:", 20, Palette.SELECT_ORANGE, 700))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var letters: Array[String] = []
	for ch in ArcadeScores.last_initials(MODE):
		letters.append(ch)
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


static func _step_letter(ch: String, d: int) -> String:
	var i := ArcadeScores.LETTERS.find(ch)
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
