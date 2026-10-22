extends Control
## ArcadeHall (arcade, story-internal): the arcade's front room (docs/ARCADE.md). The title's Arcade
## button opens it; each cabinet opens its game, and every game's results come back here.
## Two cabinets: Chart Chute (sort audiograms by shape) and Ears, Please! (the front desk: catch the
## red flags before you fit). Each shows its name, a little picture, its pitch and the top score.
## Controls: keys 1-2 open a cabinet; Left/Right and Enter (or Space); the mouse hovers and clicks;
## T or "Back to the title" goes home; Esc pauses, like everywhere.
## The playfield is 1280x720, centred in wider or taller windows; the floor fills the rest.
## Beat (CONTRACTS.md §3.2): "arcade_hall" (solver: open Ears, Please!; mouse: click
## "arcade_cabinet_<id>"). Never a visit.

const UiKit := preload("res://story/ui_kit.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const ArcadeArt := preload("res://story/arcade/arcade_art.gd")
const DeskArt := preload("res://story/arcade/desk_art.gd")
const EarsPlease := preload("res://story/arcade/ears_please.gd")
const TITLE_SCENE := "res://story/title_screen.tscn"

const FIELD := Vector2(1280, 720)
const CAB_SIZE := Vector2(420, 480)
const CAB_Y := 134.0
const CAB_GAP := 40.0
const CAB_MARGIN := 24.0   ## the least room left and right of the cabinet row
## Narrower than this, a cabinet is drawn at this width and scaled down whole (four and up).
const CAB_MIN_W := 395.0
const FLOOR := Color("#2e2442")
const CARPET := Color("#3b3550")
const GOLD := Color("#f2b632")
## The cabinets, in key order. id is the game's save key (ArcadeScores) and its anchor suffix.
const CABINETS: Array[Dictionary] = [
	{"id": "chart_chute", "name": "CHART CHUTE", "scene": "res://story/arcade/chart_chute.tscn",
		"pitch": "Sort the charts by shape before the clock runs out.", "body": Color("#3a7bd5")},
	{"id": "ears_please", "name": "EARS, PLEASE!", "scene": "res://story/arcade/ears_please.tscn",
		"pitch": "Catch the red flags before you fit.", "body": Color("#e5383b")},
	{"id": "chart_chute_types", "name": "AIR & BONE", "scene": "res://story/arcade/air_bone.tscn",
		"pitch": "Air or bone? Find where the loss lives.", "body": Color("#3a9d96")},
	{"id": "chart_chute_tymps", "name": "TYMP TOSS", "scene": "res://story/arcade/tymp_toss.tscn",
		"pitch": "Read the eardrum's peak. Which type?", "body": Color("#7b2cbf")},
]

## The cabinet last opened this session: the hall comes back with it selected.
static var last := 0

var _field: Control
var _fields: Array[Control] = []
var _bg: Control
var _cabs: Array[Cabinet] = []
var _sel := 0
var _leaving := false
var _back_btn: Button


## One cabinet: the marquee, the screen with its picture, the pitch, the top score and its key.
class Cabinet extends Control:
	signal picked(i: int)
	signal hovered(i: int)
	var index := 0
	var info: Dictionary = {}
	var selected := false
	var top_line := ""
	var extra := ""
	var fresh := false

	func _init(i: int, d: Dictionary) -> void:
		index = i
		info = d
		size = CAB_SIZE
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void: hovered.emit(index))

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(index)
			accept_event()

	func _process(_delta: float) -> void:
		if selected:
			queue_redraw()

	## The PLAY sign hangs below the cabinet: it clicks too.
	func _has_point(p: Vector2) -> bool:
		return Rect2(Vector2.ZERO, size).has_point(p) or (selected and _sign_rect().has_point(p))

	func _sign_rect() -> Rect2:
		return Rect2(size.x * 0.5 - 90, size.y - 22, 180, 40)

	func _draw() -> void:
		var f := UiKit.font(700)
		var steady := bool(Game.settings.get("reduced_motion", false))
		var pulse := 0.7 if steady else 0.5 + 0.5 * sin(Game.clock * 1000.0 / 160.0)
		var body: Color = info["body"]
		if selected:
			UiDraw.rounded_rect(self, Rect2(Vector2.ZERO, size).grow(6.0 + 3.0 * pulse), Color(Palette.SUNNY, 0.5 + 0.4 * pulse), 30)
		UiDraw.rounded_rect(self, Rect2(Vector2(0, 10), size), Color(0, 0, 0, 0.35), 26)
		UiDraw.rounded_rect(self, Rect2(Vector2.ZERO, size), body, 26, 4, Palette.INK)
		# the marquee
		var marquee := Rect2(16, 14, size.x - 32, 62)
		UiDraw.rounded_rect(self, marquee, Palette.INK, 16)
		draw_string_outline(f, marquee.position + Vector2(0, 45), String(info["name"]), HORIZONTAL_ALIGNMENT_CENTER, marquee.size.x, 36, 8, Color("#1d1830"))
		draw_string(f, marquee.position + Vector2(0, 45), String(info["name"]), HORIZONTAL_ALIGNMENT_CENTER, marquee.size.x, 36, Palette.SUNNY)
		# the screen and its picture
		var screen := Rect2(30, 90, size.x - 60, 200)
		UiDraw.rounded_rect(self, screen.grow(6), Color("#1d1830"), 18, 3, Palette.INK)
		UiDraw.rounded_rect(self, screen, Color("#fff3dc"), 12)
		if String(info["id"]) == "chart_chute":
			_draw_chute_screen(screen)
		elif String(info["id"]) == "chart_chute_types":
			_draw_types_screen(screen)
		elif String(info["id"]) == "chart_chute_tymps":
			_draw_tymps_screen(screen)
		else:
			_draw_desk_screen(screen)
		# the pitch, the top score, the play sign
		draw_multiline_string(UiKit.font(600), Vector2(24, 326), String(info["pitch"]), HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 20, 2, Palette.PAPER)
		var plate := Rect2(40, 378, size.x - 80, 34)
		UiDraw.rounded_rect(self, plate, Color(Palette.INK, 0.35), 12)
		draw_string(f, plate.position + Vector2(0, 24), top_line, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, 18, Palette.PAPER)
		if extra != "":
			draw_string(UiKit.font(600), Vector2(0, 436), extra, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(Palette.PAPER, 0.85))
		if selected:
			var sign := _sign_rect()
			UiDraw.rounded_rect(self, sign, Palette.SUNNY, 14, 3, Palette.INK)
			var tip := sign.position + Vector2(34, 20)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -10), tip + Vector2(10, 0), tip + Vector2(-7, 10)]), Palette.INK)
			draw_string(f, sign.position + Vector2(18, 29), "PLAY", HORIZONTAL_ALIGNMENT_CENTER, sign.size.x - 18, 24, Palette.INK)
		if UiKit.show_key_hints():
			UiDraw.rounded_rect(self, Rect2(-10, -10, 40, 40), Palette.SUNNY, 10, 3, Palette.INK)
			draw_string(f, Vector2(-10, 20), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 24, Palette.INK)
		if fresh:
			draw_set_transform(Vector2(size.x - 34, 26), 0.25, Vector2.ONE)
			UiDraw.star(self, Vector2.ZERO, 40.0, Palette.CORAL, 10)
			draw_string(f, Vector2(-30, 7), "NEW!", HORIZONTAL_ALIGNMENT_CENTER, 60, 18, Palette.PAPER)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	## A chart card with a sloping line over the five chute pictures.
	func _draw_chute_screen(r: Rect2) -> void:
		var card := Rect2(r.position + Vector2(r.size.x * 0.5 - 90, 12), Vector2(180, 96))
		UiDraw.rounded_rect(self, card, Color("#ffffff"), 10, 3, Palette.INK)
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(card.position + Vector2(20 + i * 28, 26 + i * i * 2.2))
		draw_polyline(pts, Palette.RIGHT_RED, 3.0, true)
		for p: Vector2 in pts:
			UiDraw.ear_symbol(self, p, "right", 9.0, 2.5)
		var shapes := [&"sloping", &"notch", &"cookie_bite", &"rising", &"reverse_bite"]
		for i in shapes.size():
			ArcadeArt.picture(self, shapes[i], r.position + Vector2(44 + i * (r.size.x - 88) / (shapes.size() - 1.0), 152), 30.0)

	## A chart card with an air line high above its bone marks (a gap), over the three chute pictures.
	func _draw_types_screen(r: Rect2) -> void:
		var card := Rect2(r.position + Vector2(r.size.x * 0.5 - 90, 12), Vector2(180, 96))
		UiDraw.rounded_rect(self, card, Color("#ffffff"), 10, 3, Palette.INK)
		var pts := PackedVector2Array()
		for i in 5:
			pts.append(card.position + Vector2(24 + i * 33, 62 + (i % 2) * 4))
		draw_polyline(pts, Palette.RIGHT_RED, 3.0, true)
		for i in pts.size():
			UiDraw.ear_symbol(self, pts[i], "right", 9.0, 2.5)
			if i > 0 and i < 4:
				UiDraw.audiogram_symbol(self, pts[i] + Vector2(-7, -36), "right", &"bc", 11.0, 2.5)
		var types := [&"sensorineural", &"conductive", &"mixed"]
		for i in types.size():
			ArcadeArt.picture(self, types[i], r.position + Vector2(64 + i * (r.size.x - 128) / 2.0, 152), 34.0)

	## A tympanogram card with its peak in the normal box, over the five type pictures.
	func _draw_tymps_screen(r: Rect2) -> void:
		var card := Rect2(r.position + Vector2(r.size.x * 0.5 - 90, 12), Vector2(180, 96))
		UiDraw.rounded_rect(self, card, Color("#ffffff"), 10, 3, Palette.INK)
		ArcadeArt.tymp_chart(self, card.grow(-10.0), {"type": "A", "peak_daPa": -10, "peak_ml": 0.9}, Palette.RIGHT_RED, false)
		var tymps := [&"tymp_a", &"tymp_b", &"tymp_as", &"tymp_c", &"tymp_ad"]
		for i in tymps.size():
			ArcadeArt.picture(self, tymps[i], r.position + Vector2(44 + i * (r.size.x - 88) / (tymps.size() - 1.0), 152), 30.0)

	## A manila file with a REFER print, a ticked intake box with the pin in it, and the two stamps.
	func _draw_desk_screen(r: Rect2) -> void:
		var file := Rect2(r.position + Vector2(20, 16), Vector2(176, 112))
		UiDraw.rounded_rect(self, Rect2(file.position, Vector2(70, 22)), EarsPlease.MANILA, 6, 3, Palette.INK)
		UiDraw.rounded_rect(self, Rect2(file.position + Vector2(0, 14), file.size - Vector2(0, 14)), EarsPlease.MANILA, 10, 3, Palette.INK)
		for i in 3:
			draw_line(file.position + Vector2(18, 44 + i * 20), file.position + Vector2(124 - i * 22, 44 + i * 20), Color(Palette.INK, 0.35), 4.0)
		draw_set_transform(file.position + Vector2(116, 90), -0.15, Vector2.ONE)
		var ink: Color = EarsPlease.STAMP_INK[&"refer"]
		UiDraw.rounded_rect(self, Rect2(-52, -18, 104, 36), Color(ink, 0.12), 8, 3, ink)
		draw_string(UiKit.font(700), Vector2(-52, 10), "REFER", HORIZONTAL_ALIGNMENT_CENTER, 104, 24, ink)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# the intake box: dizzy spells, YES, with the pin that proves the call
		var tile := Rect2(r.position + Vector2(r.size.x - 128, 18), Vector2(108, 92))
		UiDraw.rounded_rect(self, tile, Color("#fffdf6"), 12, 2, Color(Palette.INK, 0.5))
		DeskArt.intake(self, "dizziness", tile.position + Vector2(30, 40), 28.0)
		var chip := Rect2(tile.position + Vector2(tile.size.x - 50, 6), Vector2(44, 26))
		UiDraw.rounded_rect(self, chip, Palette.SUNNY, 8, 3, Palette.INK)
		draw_string(UiKit.font(700), chip.position + Vector2(0, 19), "YES", HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 15, Palette.INK)
		draw_string(UiKit.font(600), tile.position + Vector2(0, 82), "Dizzy spells", HORIZONTAL_ALIGNMENT_CENTER, tile.size.x, 14, Palette.INK)
		DeskArt.pin(self, tile.position + Vector2(70, 52), 20.0)
		# the stamps
		for i in 2:
			var s: StringName = [&"fit", &"refer"][i]
			var c := r.position + Vector2(r.size.x * 0.5 - 70 + i * 140, 166)
			UiDraw.rounded_rect(self, Rect2(c + Vector2(-16, -30), Vector2(32, 16)), Palette.WOOD, 7, 2, Palette.INK)
			var face := Rect2(c + Vector2(-56, -16), Vector2(112, 36))
			UiDraw.rounded_rect(self, face, EarsPlease.STAMP_FACE[s], 10, 3, Palette.INK)
			draw_string(UiKit.font(700), face.position + Vector2(0, 27), CaseRules.DECISION_STAMPS[s], HORIZONTAL_ALIGNMENT_CENTER, face.size.x, 22, Palette.INK)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hoot.clear()
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_select(clampi(last, 0, CABINETS.size() - 1))
	Events.awaiting_input.emit(&"arcade_hall", {"options": CABINETS.map(func(c: Dictionary) -> String: return String(c["name"])),
		"best": 1, "mouse": {"click": "arcade_cabinet_ears_please"}}, func() -> void: open_cabinet(1))


## Open a cabinet by its index (keys, clicks and the solver all come here); once per visit.
func open_cabinet(i: int) -> void:
	if _leaving or i < 0 or i >= CABINETS.size():
		return
	_leaving = true
	_select(i)
	last = i
	Sfx.play(&"ding", 1.2, -6.0)
	Juice.pop(_cabs[i], 1.06, 0.15)
	Events.input_resolved.emit(&"arcade_hall")
	Events.goto_scene.emit(String(CABINETS[i]["scene"]))


func go_back() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play(&"click")
	Events.input_resolved.emit(&"arcade_hall")
	Events.goto_scene.emit(TITLE_SCENE)


func selected() -> int:
	return _sel


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		var digit := code if (code >= KEY_1 and code <= KEY_9) or (code >= KEY_KP_1 and code <= KEY_KP_9) else k.physical_keycode
		if digit >= KEY_1 and digit < KEY_1 + CABINETS.size():
			open_cabinet(digit - KEY_1)
		elif digit >= KEY_KP_1 and digit < KEY_KP_1 + CABINETS.size():
			open_cabinet(digit - KEY_KP_1)
		elif code == KEY_T:
			go_back()
		else:
			_nav(event)
			return
		get_viewport().set_input_as_handled()
		return
	_nav(event)


func _nav(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_left"):
		_select(maxi(_sel - 1, 0))
	elif event.is_action_pressed(&"ui_right"):
		_select(mini(_sel + 1, CABINETS.size() - 1))
	elif event.is_action_pressed(&"ui_accept"):
		open_cabinet(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


func _select(i: int) -> void:
	if i != _sel and not _cabs.is_empty():
		Sfx.play(&"blip", 1.1, -12.0)
	_sel = i
	for c: Cabinet in _cabs:
		c.selected = c.index == i
		c.queue_redraw()


func _build() -> void:
	_bg = UiKit.full_rect()
	_bg.draw.connect(_draw_bg.bind(_bg))
	add_child(_bg)
	_field = Control.new()
	_field.size = FIELD
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	_fields.append(_field)
	var sign := UiKit.full_rect()
	sign.draw.connect(_draw_sign.bind(sign))
	_field.add_child(sign)
	# the cabinets share the width: two at full size, three a little narrower and closer
	var n := CABINETS.size()
	var gap := CAB_GAP if n <= 2 else CAB_GAP * 0.7
	var w := minf(CAB_SIZE.x, (FIELD.x - 2.0 * CAB_MARGIN - gap * (n - 1)) / n)
	var x0 := (FIELD.x - w * n - gap * (n - 1)) * 0.5
	# each cabinet stands in a holder, which scales it down whole when the row is too narrow
	var k := minf(1.0, w / CAB_MIN_W)
	for i in n:
		var d: Dictionary = CABINETS[i]
		var c := Cabinet.new(i, d)
		c.size = Vector2(w / k, CAB_SIZE.y)
		c.pivot_offset = c.size * 0.5
		var holder := Control.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.position = Vector2(x0 + i * (w + gap), CAB_Y + CAB_SIZE.y * (1.0 - k) * 0.5)
		holder.scale = Vector2(k, k)
		_field.add_child(holder)
		c.top_line = _top_line(String(d["id"]))
		c.extra = _extra_line(String(d["id"]))
		c.fresh = ArcadeScores.runs(String(d["id"])).is_empty()
		c.picked.connect(open_cabinet)
		c.hovered.connect(_select)
		holder.add_child(c)
		_cabs.append(c)
		Hoot.register_anchor("arcade_cabinet_" + String(d["id"]), c)
	var hints := UiKit.show_key_hints()
	_back_btn = UiKit.button("Back to the title  [T]" if hints else "Back to the title", &"", Vector2(300, 54))
	_back_btn.position = Vector2((FIELD.x - 300) * 0.5, 648)
	_back_btn.pressed.connect(go_back)
	_field.add_child(_back_btn)


## "HIGH SCORE  HOO 24,000": the top of the cabinet's first board, seed rows included.
static func _top_line(mode: String) -> String:
	var t := ArcadeScores.table(mode)
	if t.is_empty():
		return ""
	return "HIGH SCORE   %s  %s" % [String(t[0]["initials"]), _thousands(int(t[0]["score"]))]


static func _extra_line(mode: String) -> String:
	var runs := ArcadeScores.runs(mode)
	if runs.is_empty():
		return "Never played: go on!"
	var best := 0
	for r: Dictionary in runs:
		best = maxi(best, int(r["score"]))
	var line := "Your best lately: %s" % _thousands(best)
	if mode == EarsPlease.MODE and EarsPlease._unlocked() >= 2:
		line += "  ·  Shift %d open" % EarsPlease._unlocked()
	return line


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _layout() -> void:
	var vp := get_viewport_rect().size
	var off := ((vp - FIELD) * 0.5).floor()
	off = Vector2(maxf(off.x, 0.0), maxf(off.y, 0.0))
	for f: Control in _fields:
		f.position = off
	_bg.queue_redraw()


## The dark hall and its carpet, across the whole window.
func _draw_bg(ci: Control) -> void:
	var full := ci.size
	var o := _field.position
	ci.draw_rect(Rect2(Vector2.ZERO, full), FLOOR)
	ci.draw_rect(Rect2(0, o.y + 560, full.x, full.y - o.y - 560), CARPET)
	# the carpet's confetti, in a fixed pattern
	var h := maxf(1.0, full.y - o.y - 580)
	for i in 70:
		var p := Vector2(_hash(i * 2) * full.x, o.y + 574 + _hash(i * 2 + 1) * h)
		ci.draw_circle(p, 4.0, [Palette.SUNNY, Palette.MINT, Palette.CORAL, Palette.LEFT_BLUE][i % 4])


## 0..1, the same for the same n (a scatter that never moves).
static func _hash(n: int) -> float:
	var x := sin(float(n) * 12.9898 + 4.1) * 43758.5453
	return x - floorf(x)


## The neon sign over the cabinets.
func _draw_sign(ci: Control) -> void:
	var f := UiKit.font(700)
	var r := Rect2(FIELD.x * 0.5 - 260, 18, 520, 76)
	UiDraw.rounded_rect(ci, r, Color("#1d1830"), 20, 4, GOLD)
	ci.draw_string_outline(f, r.position + Vector2(0, 58), "THE ARCADE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 54, 10, Color(Palette.CORAL, 0.6))
	ci.draw_string(f, r.position + Vector2(0, 58), "THE ARCADE", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 54, Palette.SUNNY)
	ci.draw_string(UiKit.font(600), Vector2(0, 122), "Quick reads, high scores, no beeps. Pick a cabinet!", HORIZONTAL_ALIGNMENT_CENTER, FIELD.x, 19, Color(Palette.PAPER, 0.8))
