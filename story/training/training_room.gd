extends Control
## TrainingRoom (training, story-internal): Hoot's Training room, opened by the title's Training button
## (docs/training/MASKING_TRAINER.md §1). A cork board with one big lesson card per trainer (today:
## MASKING SCHOOL, its six stations as coloured chips with a star each), the cheat-sheet cards the
## player has earned pinned beside it, and a dimmed "More lessons soon" card.
## Controls: keys 1-6 open a station; Left / Right / Up / Down and Enter (or Space); the mouse hovers
## and clicks; T or "Back to the title" goes home; Esc pauses, like everywhere. A station that is not
## built yet shows SOON and only says so.
## Beat (CONTRACTS.md §3.2): "training_room" {stations, built, mouse}; solver: open the first built
## station without a star (else station 1).

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")
const MaskingSchool := preload("res://story/training/masking/masking_school.gd")
const TITLE_SCENE := "res://story/title_screen.tscn"
const SCHOOL_SCENE := "res://story/training/masking/masking_school.tscn"

const FIELD := Vector2(1280, 720)
const CORK := Color("#c99a62")
const CORK_DARK := Color("#a97b46")
const FRAME := Color("#7a5230")
const LESSON_RECT := Rect2(36, 118, 780, 520)
const CHIP_SIZE := Vector2(360, 118)
const PINS_RECT := Rect2(846, 118, 398, 520)

## The station last opened this session: the room comes back with it selected.
static var last := 0

var _field: Control
var _bg: Control
var _chips: Array[StationChip] = []
var _sel := 0
var _leaving := false
var _hoot_line: Label
var _back_btn: Button


## One station chip on the lesson card: its number, name, pitch, star, or SOON.
class StationChip extends Control:
	signal picked(i: int)
	signal hovered(i: int)
	var index := 0
	var st: Dictionary = {}
	var selected := false
	var star := false
	var best := -1

	func _init(i: int, d: Dictionary) -> void:
		index = i
		st = d
		size = CHIP_SIZE
		custom_minimum_size = CHIP_SIZE
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

	func _draw() -> void:
		var built := bool(st["built"])
		var col: Color = st["color"]
		if not built:
			col = col.lerp(Palette.PAPER, 0.55)
		var r := Rect2(Vector2.ZERO, size)
		if selected:
			var pulse := 0.7 if bool(Game.settings.get("reduced_motion", false)) else 0.5 + 0.5 * sin(Game.clock * 1000.0 / 160.0)
			UiDraw.rounded_rect(self, r.grow(5.0 + 3.0 * pulse), Color(Palette.SUNNY, 0.55 + 0.35 * pulse), 24)
		UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.25), 20)
		UiDraw.rounded_rect(self, r, col, 20, 4, Palette.INK)
		var light := col.get_luminance() > 0.55
		var ink := Palette.INK if light else Palette.PAPER
		# the number disc
		draw_circle(Vector2(44, 48), 26.0, Palette.PAPER)
		draw_arc(Vector2(44, 48), 26.0, 0.0, TAU, 24, Palette.INK, 3.0, true)
		draw_string(UiKit.font(700), Vector2(18, 58), str(int(st["num"])), HORIZONTAL_ALIGNMENT_CENTER, 52, 28, Palette.INK)
		draw_string(UiKit.font(700), Vector2(82, 44), String(st["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 24, ink)
		draw_string(UiKit.font(600), Vector2(82, 76), String(st["pitch"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 96, 18, Color(ink, 0.9))
		if not built:
			var s := Rect2(size.x - 92, 92, 80, 30)
			UiDraw.rounded_rect(self, s, Palette.INK, 12)
			draw_string(UiKit.font(700), s.position + Vector2(0, 22), "SOON", HORIZONTAL_ALIGNMENT_CENTER, s.size.x, 18, Palette.SUNNY)
		else:
			UiDraw.star(self, Vector2(size.x - 30, 34), 20.0, Palette.SUNNY if star else Color(ink, 0.25))
			var line := "New!" if best < 0 else ("Best: %s" % MaskDeck.round_name(best))
			draw_string(UiKit.font(600), Vector2(82, 104), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(ink, 0.85))
		if UiKit.show_key_hints():
			UiDraw.rounded_rect(self, Rect2(-10, -10, 34, 34), Palette.SUNNY, 9, 3, Palette.INK)
			draw_string(UiKit.font(700), Vector2(-10, 15), str(index + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Palette.INK)


func demo_start() -> void:
	pass


func _ready() -> void:
	add_to_group("training_room")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hoot.clear()
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_select(clampi(last, 0, _chips.size() - 1), false)
	Events.phase_changed.emit(&"training_room", {"lesson": MaskDeck.LESSON})
	var built: Array = []
	for s: Dictionary in MaskDeck.STATIONS:
		if bool(s["built"]):
			built.append(String(s["id"]))
	Events.awaiting_input.emit(&"training_room", {"stations": MaskDeck.station_ids(), "built": built,
		"mouse": {"click": String(MaskDeck.station(_solver_pick())["name"])}}, func() -> void: open_station(_index_of(_solver_pick())))


## The first built station without a star, else the first built one.
func _solver_pick() -> String:
	for s: Dictionary in MaskDeck.STATIONS:
		if bool(s["built"]) and not TrainingProgress.station(MaskDeck.LESSON, String(s["id"]))["star"]:
			return String(s["id"])
	return "why"


func _index_of(id: String) -> int:
	return MaskDeck.station_ids().find(id)


## Open station i (keys, clicks and the solver all come here). Unbuilt stations only say SOON.
func open_station(i: int) -> void:
	if _leaving or i < 0 or i >= _chips.size():
		return
	_select(i, false)
	var st: Dictionary = MaskDeck.STATIONS[i]
	if not bool(st["built"]):
		Sfx.play(&"boing", 0.9, -10.0)
		Juice.shake(_chips[i], 5.0, 0.25)
		_hoot_line.text = "\"%s\" opens soon. Station 1 is ready now!" % String(st["name"])
		return
	_leaving = true
	last = i
	Sfx.play(&"ding", 1.2, -6.0)
	Juice.pop(_chips[i], 1.06, 0.15)
	MaskingSchool.next_station = String(st["id"])
	Events.input_resolved.emit(&"training_room")
	Events.goto_scene.emit(SCHOOL_SCENE)


func go_back() -> void:
	if _leaving:
		return
	_leaving = true
	Sfx.play(&"click")
	Events.input_resolved.emit(&"training_room")
	Events.goto_scene.emit(TITLE_SCENE)


func selected() -> int:
	return _sel


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code >= KEY_1 and code < KEY_1 + _chips.size():
			open_station(code - KEY_1)
		elif code >= KEY_KP_1 and code < KEY_KP_1 + _chips.size():
			open_station(code - KEY_KP_1)
		elif code == KEY_T:
			go_back()
		else:
			_nav(event)
			return
		get_viewport().set_input_as_handled()
		return
	_nav(event)


## Two columns: Left / Right across, Up / Down a row.
func _nav(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_left"):
		_select(maxi(_sel - 1, 0))
	elif event.is_action_pressed(&"ui_right"):
		_select(mini(_sel + 1, _chips.size() - 1))
	elif event.is_action_pressed(&"ui_up"):
		_select(maxi(_sel - 2, 0) if _sel >= 2 else _sel)
	elif event.is_action_pressed(&"ui_down"):
		_select(mini(_sel + 2, _chips.size() - 1))
	elif event.is_action_pressed(&"ui_accept"):
		open_station(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


func _select(i: int, sound := true) -> void:
	if i != _sel and sound:
		Sfx.play(&"blip", 1.1, -12.0)
	_sel = i
	for c: StationChip in _chips:
		c.selected = c.index == i
		c.queue_redraw()


func _build() -> void:
	_bg = UiKit.full_rect()
	_bg.draw.connect(_draw_bg)
	add_child(_bg)
	_field = Control.new()
	_field.size = FIELD
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	var deco := UiKit.full_rect()
	deco.draw.connect(_draw_board.bind(deco))
	_field.add_child(deco)
	# Hoot's welcome, top right
	var hp := UiKit.panel(Palette.PAPER, Palette.INK, 20)
	hp.position = Vector2(620, 18)
	hp.custom_minimum_size = Vector2(560, 84)   # clear of the pause button in the corner
	hp.size = Vector2(560, 84)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hp.add_child(hh)
	var face := Control.new()
	face.custom_minimum_size = Vector2(60, 60)
	face.draw.connect(func() -> void: Portraits.draw(face, "Hoot", Vector2(30, 30), 26.0))
	hh.add_child(face)
	_hoot_line = UiKit.label(_welcome(), 19, Palette.INK, 600)
	_hoot_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hoot_line.custom_minimum_size = Vector2(460, 0)
	_hoot_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(_hoot_line)
	_field.add_child(hp)
	# the station chips, two columns of three on the lesson card
	for i in MaskDeck.STATIONS.size():
		var st: Dictionary = MaskDeck.STATIONS[i]
		var c := StationChip.new(i, st)
		c.name = "station_%s" % String(st["id"])
		var rec := TrainingProgress.station(MaskDeck.LESSON, String(st["id"]))
		c.star = bool(rec["star"])
		c.best = int(rec["best"])
		c.position = LESSON_RECT.position + Vector2(24 + (i % 2) * (CHIP_SIZE.x + 24), 104 + (i / 2) * (CHIP_SIZE.y + 18))
		c.picked.connect(open_station)
		c.hovered.connect(func(j: int) -> void:
			if not _leaving and j != _sel:
				_select(j))
		_field.add_child(c)
		_chips.append(c)
	# a station's name as a clickable label for the mouse bot: the chip draws its own text, so each
	# chip also carries an invisible-to-the-eye Label child with its name (the bot clicks by text)
	for c: StationChip in _chips:
		var l := UiKit.label(String(c.st["name"]), 24, Color(0, 0, 0, 0), 700)
		l.position = Vector2(82, 18)
		l.size = Vector2(CHIP_SIZE.x - 130, 32)
		c.add_child(l)
	# the pinned cheat-sheet cards
	var got := TrainingProgress.cards(MaskDeck.LESSON)
	for i in MaskDeck.CARD_ORDER.size():
		var id: String = MaskDeck.CARD_ORDER[i]
		var cc := CheatCard.new(MaskDeck.cheat_card(id), got.has(id), 15)
		cc.name = "card_%s" % id
		cc.hint = "Station %d" % (i + 1)
		cc.size = Vector2(182, 132)
		cc.position = PINS_RECT.position + Vector2(10 + (i % 2) * 196, 64 + (i / 2) * 148)
		cc.rotation = deg_to_rad([-2.0, 1.5, 1.0, -1.5, -1.0][i])
		_field.add_child(cc)
	_back_btn = UiKit.button("Back to the title", &"", Vector2(260, 52))
	_back_btn.position = Vector2(36, FIELD.y - 70)
	_back_btn.add_theme_font_size_override("font_size", 22)
	_back_btn.pressed.connect(go_back)
	_field.add_child(_back_btn)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["1", "-", "6"], "station", ["Enter"], "open", ["T"], "title", ["Esc"], "pause"], 16, Palette.PAPER)
		hr.position = Vector2(320, FIELD.y - 56)
		_field.add_child(hr)


func _welcome() -> String:
	if TrainingProgress.data(MaskDeck.LESSON)["stations"].is_empty():
		return "Welcome to my Training room! Short lessons, big ideas. Start with masking?"
	return "Welcome back! Pick a station, or replay one for its star."


func _layout() -> void:
	var vp := get_viewport_rect().size
	var off := ((vp - FIELD) * 0.5).floor()
	_field.position = Vector2(maxf(off.x, 0.0), maxf(off.y, 0.0))
	_bg.queue_redraw()


## The cork wall across the whole window, in a fixed speckle.
func _draw_bg() -> void:
	_bg.draw_rect(Rect2(Vector2.ZERO, _bg.size), CORK)
	for i in 260:
		var p := Vector2(_hash(i * 2) * _bg.size.x, _hash(i * 2 + 1) * _bg.size.y)
		_bg.draw_circle(p, 1.5 + 2.0 * _hash(i * 7), CORK_DARK)


## The sign, the lesson card and the pin board's frame (in field coordinates).
func _draw_board(ci: Control) -> void:
	var f := UiKit.font(700)
	# the sign
	var sign := Rect2(36, 22, 560, 74)
	UiDraw.rounded_rect(ci, Rect2(sign.position + Vector2(0, 6), sign.size), Color(0, 0, 0, 0.3), 18)
	UiDraw.rounded_rect(ci, sign, Palette.INK, 18, 4, FRAME)
	ci.draw_string(f, sign.position + Vector2(0, 50), "HOOT'S TRAINING ROOM", HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 38, Palette.SUNNY)
	# the lesson card
	var lc := LESSON_RECT
	UiDraw.rounded_rect(ci, Rect2(lc.position + Vector2(0, 8), lc.size), Color(0, 0, 0, 0.3), 26)
	UiDraw.rounded_rect(ci, lc, Color("#1f3a5f"), 26, 4, Palette.INK)
	ci.draw_string(f, lc.position + Vector2(30, 56), "MASKING SCHOOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.PAPER)
	ci.draw_string(UiKit.font(600), lc.position + Vector2(32, 86), "Why, when and how much: and the occlusion effect.", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Palette.PAPER, 0.85))
	_draw_mask(ci, lc.position + Vector2(lc.size.x - 92, 50), 1.0)
	var stars := TrainingProgress.stars(MaskDeck.LESSON)
	ci.draw_string(f, lc.position + Vector2(lc.size.x - 340, 52), "%d of %d stars" % [stars, MaskDeck.STATIONS.size()], HORIZONTAL_ALIGNMENT_RIGHT, 200, 18, Palette.SUNNY)
	ci.draw_circle(lc.position + Vector2(lc.size.x * 0.5, 4), 9.0, Palette.CORAL)
	# the pin board for the cheat-sheet cards
	var pb := PINS_RECT
	UiDraw.rounded_rect(ci, pb, Color(FRAME, 0.35), 22, 4, FRAME)
	ci.draw_string(f, pb.position + Vector2(0, 42), "MY CHEAT SHEETS", HORIZONTAL_ALIGNMENT_CENTER, pb.size.x, 26, Palette.PAPER)
	# "More lessons soon", dimmed, under the cards
	var soon := Rect2(pb.position + Vector2(206, 362), Vector2(182, 132))
	UiDraw.rounded_rect(ci, soon, Color(Palette.PAPER, 0.25), 14, 3, Color(Palette.INK, 0.4))
	ci.draw_string(f, soon.position + Vector2(0, 56), "More lessons", HORIZONTAL_ALIGNMENT_CENTER, soon.size.x, 20, Color(Palette.INK, 0.6))
	ci.draw_string(f, soon.position + Vector2(0, 84), "soon!", HORIZONTAL_ALIGNMENT_CENTER, soon.size.x, 20, Color(Palette.INK, 0.6))


## The masquerade mask on the lesson card.
static func _draw_mask(ci: CanvasItem, c: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		pts.append(c + Vector2(cos(a) * 62.0, sin(a) * 26.0 + 6.0) * k)
	for i in 21:
		var a := PI * i / 20.0
		var dip := 10.0 * sin(a * 2.0)
		pts.append(c + Vector2(cos(a) * 62.0, sin(a) * 24.0 + 6.0 - dip) * k)
	ci.draw_colored_polygon(pts, Palette.SUNNY)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, Palette.INK, 3.0, true)
	for s: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(s * 26.0, 6.0) * k, 11.0 * k, Palette.INK)
	ci.draw_line(c + Vector2(50, -10) * k, c + Vector2(66, -40) * k, Palette.CORAL, 4.0, true)
	ci.draw_circle(c + Vector2(66, -40) * k, 6.0 * k, Palette.CORAL)


static func _hash(n: int) -> float:
	var x := sin(float(n) * 12.9898 + 4.1) * 43758.5453
	return x - floorf(x)
