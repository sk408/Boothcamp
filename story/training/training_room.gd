extends Control
## TrainingRoom (training, story-internal): Hoot's Training room, opened by the title's Training button
## (docs/training/MASKING_TRAINER.md §1). A cork board with one big lesson card per trainer (today:
## MASKING SCHOOL, its six stations as coloured chips with a star each), the cheat-sheet cards the
## player has earned pinned beside it, and a dimmed "More lessons soon" card. With all five cards
## earned that slot becomes the "Print view" tile (P): every card on one page (print_view.gd). The
## exam's diploma (diploma.gd) is stamped on the lesson card once Station 6 is finished.
## (practical) Two lesson tabs under the sign: MASKING SCHOOL and THE PRACTICAL (docs/training/PRACTICAL_EXAM.md,
## story/training/practical/); the lesson card, its chips (eight for The Practical, two columns of four) and
## the pinned cards follow the tab. Each lesson has its print view once all its cards are earned (The Practical's
## button sits on its pin board's header); Exam day's licence (practical/licence.gd) replaces the clipboard on the
## lesson card once the exam is finished.
## Controls: keys 1-6 (1-8) open a station; Tab or a click on a tab switches the lesson; Left / Right / Up / Down and Enter (or Space); the mouse hovers
## and clicks; P opens the print view (all cards earned); T or "Back to the title" goes home; Esc pauses, like everywhere. A station that is not
## built yet shows SOON and only says so.
## Beat (CONTRACTS.md §3.2): "training_room" {lesson, stations, built, mouse}; solver: open the first built
## station without a star (else station 1). A lesson switch resolves the beat and emits it again.

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")
const MaskingSchool := preload("res://story/training/masking/masking_school.gd")
const Diploma := preload("res://story/training/diploma.gd")
const PrintView := preload("res://story/training/print_view.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const PracticalSchool := preload("res://story/training/practical/practical_school.gd")
const Licence := preload("res://story/training/practical/licence.gd")
const TITLE_SCENE := "res://story/title_screen.tscn"
const SCHOOL_SCENE := "res://story/training/masking/masking_school.tscn"
const PRACTICAL_SCENE := "res://story/training/practical/practical_school.tscn"
## The lessons, in tab order: id, the tab's name, its colour.
const LESSONS: Array = [["masking", "MASKING SCHOOL", Color("#1f3a5f")], ["practical", "THE PRACTICAL", Color("#1f9aa5")]]

const FIELD := Vector2(1280, 720)
const CORK := Color("#c99a62")
const CORK_DARK := Color("#a97b46")
const FRAME := Color("#7a5230")
const LESSON_RECT := Rect2(36, 118, 780, 520)
const CHIP_SIZE := Vector2(360, 118)
## The Practical's eight chips are shorter (two columns of four).
const CHIP_SIZE_SMALL := Vector2(360, 86)
const PINS_RECT := Rect2(846, 118, 398, 520)
const TAB_SIZE := Vector2(276, 46)

## The station last opened this session: the room comes back with it selected.
static var last := 0
## The lesson on the board (a tab): "masking" or "practical".
static var lesson := "masking"

var _field: Control
var _bg: Control
var _chips: Array[StationChip] = []
var _sel := 0
var _leaving := false
var _hoot_line: Label
var _back_btn: Button
var _print_btn: Button
var _print: Control
var _layer: Control   # the lesson's chips, pins and print tile (rebuilt on a lesson switch)
var _deco: Control


## One station chip on the lesson card: its number, name, pitch, star, or SOON.
class StationChip extends Control:
	signal picked(i: int)
	signal hovered(i: int)
	var index := 0
	var st: Dictionary = {}
	var selected := false
	var star := false
	var best := -1
	var best_line := ""
	var small := false

	func _init(i: int, d: Dictionary, chip_size := CHIP_SIZE) -> void:
		index = i
		st = d
		small = chip_size.y < CHIP_SIZE.y
		size = chip_size
		custom_minimum_size = chip_size
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
		var dy := -13.0 if small else 0.0
		var rad := 23.0 if small else 26.0
		draw_circle(Vector2(44, 48 + dy), rad, Palette.PAPER)
		draw_arc(Vector2(44, 48 + dy), rad, 0.0, TAU, 24, Palette.INK, 3.0, true)
		draw_string(UiKit.font(700), Vector2(18, 58 + dy), str(int(st["num"])), HORIZONTAL_ALIGNMENT_CENTER, 52, 28, Palette.INK)
		draw_string(UiKit.font(700), Vector2(82, 44 + dy * 1.2), String(st["name"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 130, 24, ink)
		draw_string(UiKit.font(600), Vector2(82, 76 + dy * 1.6), String(st["pitch"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 96, 17 if small else 18, Color(ink, 0.9))
		if not built and small:
			# under the number disc, clear of the pitch line
			var s := Rect2(8, size.y - 26, 72, 22)
			UiDraw.rounded_rect(self, s, Palette.INK, 9)
			draw_string(UiKit.font(700), s.position + Vector2(0, 17), "SOON", HORIZONTAL_ALIGNMENT_CENTER, s.size.x, 15, Palette.SUNNY)
		elif not built:
			var s := Rect2(size.x - 92, 92, 80, 30)
			UiDraw.rounded_rect(self, s, Palette.INK, 12)
			draw_string(UiKit.font(700), s.position + Vector2(0, 22), "SOON", HORIZONTAL_ALIGNMENT_CENTER, s.size.x, 18, Palette.SUNNY)
		else:
			UiDraw.star(self, Vector2(size.x - 30, 34), 20.0, Palette.SUNNY if star else Color(ink, 0.25))
			var line := "New!" if best < 0 else ("Best: %s" % best_line)
			draw_string(UiKit.font(600), Vector2(82, size.y - 12 if small else 104), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(ink, 0.85))
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
	if _lesson_index(lesson) < 0:
		lesson = "masking"
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_select(clampi(last, 0, _chips.size() - 1), false)
	_emit_beat()


## The lesson's deck (MaskDeck or PracticalDeck: the same static API).
static func deck() -> GDScript:
	return PracticalDeck if lesson == "practical" else MaskDeck


static func _lesson_index(id: String) -> int:
	for i in LESSONS.size():
		if String(LESSONS[i][0]) == id:
			return i
	return -1


func _emit_beat() -> void:
	var d := deck()
	Events.phase_changed.emit(&"training_room", {"lesson": d.LESSON})
	var built: Array = []
	for s: Dictionary in d.STATIONS:
		if bool(s["built"]):
			built.append(String(s["id"]))
	Events.awaiting_input.emit(&"training_room", {"lesson": lesson, "stations": d.station_ids(), "built": built,
		"mouse": {"click": String(d.station(_solver_pick())["name"])}}, func() -> void: open_station(_index_of(_solver_pick())))


## The first built station without a star, else the first built one.
func _solver_pick() -> String:
	var d := deck()
	for s: Dictionary in d.STATIONS:
		if bool(s["built"]) and not TrainingProgress.station(d.LESSON, String(s["id"]))["star"]:
			return String(s["id"])
	return String(d.STATIONS[0]["id"])


func _index_of(id: String) -> int:
	return deck().station_ids().find(id)


## Show another lesson on the board (a tab click, Tab, or the bot).
func select_lesson(id: String) -> void:
	if _leaving or _print != null or id == lesson or _lesson_index(id) < 0:
		return
	Events.input_resolved.emit(&"training_room")
	lesson = id
	last = 0
	Sfx.play(&"pop", 1.1, -8.0)
	_build_lesson()
	_select(0, false)
	_hoot_line.text = _welcome()
	_deco.queue_redraw()
	for c in _field.get_children():
		if c is LessonTab:
			c.on = lesson == c.id
			c.queue_redraw()
	_emit_beat()


func next_lesson() -> void:
	select_lesson(String(LESSONS[(_lesson_index(lesson) + 1) % LESSONS.size()][0]))


## Open station i (keys, clicks and the solver all come here). Unbuilt stations only say SOON.
func open_station(i: int) -> void:
	if _leaving or i < 0 or i >= _chips.size():
		return
	_select(i, false)
	var st: Dictionary = deck().STATIONS[i]
	if not bool(st["built"]):
		Sfx.play(&"boing", 0.9, -10.0)
		Juice.shake(_chips[i], 5.0, 0.25)
		_hoot_line.text = "\"%s\" opens soon. Pick a station without SOON!" % String(st["name"])
		return
	_leaving = true
	last = i
	Sfx.play(&"ding", 1.2, -6.0)
	Juice.pop(_chips[i], 1.06, 0.15)
	Events.input_resolved.emit(&"training_room")
	if lesson == "practical":
		PracticalSchool.next_station = String(st["id"])
		Events.goto_scene.emit(PRACTICAL_SCENE)
	else:
		MaskingSchool.next_station = String(st["id"])
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


## The lesson's print view opens once every one of its cheat-sheet cards is earned.
func can_print() -> bool:
	var d := deck()
	for id: String in d.CARD_ORDER:
		if not TrainingProgress.has_card(d.LESSON, id):
			return false
	return true


func open_print() -> void:
	if _leaving or _print != null or not can_print():
		return
	Sfx.play(&"pop", 1.0, -8.0)
	_print = PrintView.new()
	_print.lesson = lesson
	_print.closed.connect(func() -> void: _print = null)
	_field.add_child(_print)


## The exam has been finished: the lesson card wears the diploma.
static func has_diploma() -> bool:
	return int(TrainingProgress.station(MaskDeck.LESSON, "exam")["best"]) >= 0


func _unhandled_input(event: InputEvent) -> void:
	if _print != null:
		return   # the print view takes the keys
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
		if code == KEY_P and can_print():
			open_print()
		elif code == KEY_TAB:
			next_lesson()
		elif code >= KEY_1 and code < KEY_1 + _chips.size():
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


## One lesson tab under the sign: its name, its colour; the shown lesson is raised and bright.
class LessonTab extends Control:
	signal picked(id: String)
	var id := ""
	var title := ""
	var col := Color.WHITE
	var on := false   # the lesson on the board

	func _init(lesson_id: String, t: String, c: Color) -> void:
		id = lesson_id
		title = t
		col = c
		size = TAB_SIZE
		custom_minimum_size = TAB_SIZE
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		# the bot clicks by text: an invisible label with the tab's name
		var l := UiKit.label(t, 22, Color(0, 0, 0, 0), 700)
		l.size = TAB_SIZE
		add_child(l)

	func _gui_input(event: InputEvent) -> void:
		var mb := event as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(id)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if on:
			UiDraw.rounded_rect(self, Rect2(r.position + Vector2(0, 5), r.size), Color(0, 0, 0, 0.3), 16)
		UiDraw.rounded_rect(self, r, col if on else col.lerp(Palette.PAPER, 0.6), 16, 4 if on else 3, Palette.INK)
		draw_string(UiKit.font(700), Vector2(0, 32), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Palette.PAPER if on else Color(Palette.INK, 0.75))


func _build() -> void:
	_bg = UiKit.full_rect()
	_bg.draw.connect(_draw_bg)
	add_child(_bg)
	_field = Control.new()
	_field.size = FIELD
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	_deco = UiKit.full_rect()
	_deco.draw.connect(_draw_board.bind(_deco))
	_field.add_child(_deco)
	# the lesson tabs, under the sign
	for i in LESSONS.size():
		var tab := LessonTab.new(String(LESSONS[i][0]), String(LESSONS[i][1]), LESSONS[i][2])
		tab.name = "tab_%s" % String(LESSONS[i][0])
		tab.position = Vector2(36 + i * (TAB_SIZE.x + 8), 64)
		tab.on = lesson == tab.id
		tab.picked.connect(select_lesson)
		_field.add_child(tab)
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
	_build_lesson()
	_back_btn = UiKit.button("Back to the title", &"", Vector2(260, 52))
	_back_btn.position = Vector2(36, FIELD.y - 70)
	_back_btn.add_theme_font_size_override("font_size", 22)
	_back_btn.pressed.connect(go_back)
	_field.add_child(_back_btn)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["1", "-", "8"], "station", ["Tab"], "lesson", ["Enter"], "open", ["T"], "title", ["Esc"], "pause"], 16, Palette.PAPER)
		hr.position = Vector2(320, FIELD.y - 56)
		_field.add_child(hr)


## The lesson's own nodes: the station chips, the pinned cheat-sheet cards, the print tile.
func _build_lesson() -> void:
	if _layer != null:
		_field.remove_child(_layer)
		_layer.queue_free()
	_chips.clear()
	_print_btn = null
	_layer = Control.new()
	_layer.name = "LessonLayer"
	_layer.size = FIELD
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field.add_child(_layer)
	_field.move_child(_layer, _deco.get_index() + 1)
	var d := deck()
	var stations: Array = d.STATIONS
	var small := stations.size() > 6
	var cs := CHIP_SIZE_SMALL if small else CHIP_SIZE
	var gap := 12.0 if small else 18.0
	# the station chips, two columns on the lesson card
	for i in stations.size():
		var st: Dictionary = stations[i]
		var c := StationChip.new(i, st, cs)
		c.name = "station_%s" % String(st["id"])
		var rec := TrainingProgress.station(d.LESSON, String(st["id"]))
		c.star = bool(rec["star"])
		c.best = int(rec["best"])
		c.best_line = d.round_name(c.best)
		if lesson == "practical" and String(st["id"]) == "exam" and c.best >= 0:
			c.best_line = "Grade %s%s" % [PracticalDeck.exam_grade(c.best), ", pass" if Licence.passed() else ""]
		c.position = LESSON_RECT.position + Vector2(24 + (i % 2) * (cs.x + 24), 104 + (i / 2) * (cs.y + gap))
		c.picked.connect(open_station)
		c.hovered.connect(func(j: int) -> void:
			if not _leaving and j != _sel:
				_select(j))
		_layer.add_child(c)
		_chips.append(c)
	# a station's name as a clickable label for the mouse bot: the chip draws its own text, so each
	# chip also carries an invisible-to-the-eye Label child with its name (the bot clicks by text)
	for c: StationChip in _chips:
		var l := UiKit.label(String(c.st["name"]), 24, Color(0, 0, 0, 0), 700)
		l.position = Vector2(82, 6 if c.small else 18)
		l.size = Vector2(cs.x - 130, 32)
		c.add_child(l)
	# the pinned cheat-sheet cards
	var got := TrainingProgress.cards(d.LESSON)
	var order: Array = d.CARD_ORDER
	for i in order.size():
		var id := String(order[i])
		var cc := CheatCard.new(d.cheat_card(id), got.has(id), 12 if small else 15)
		cc.name = "card_%s" % id
		cc.hint = "Station %d" % (PracticalDeck.card_station(id) if lesson == "practical" else i + 1)
		if small:
			cc.size = Vector2(182, 110)
			cc.position = PINS_RECT.position + Vector2(10 + (i % 2) * 196, 56 + (i / 2) * 115)
		else:
			cc.size = Vector2(182, 132)
			cc.position = PINS_RECT.position + Vector2(10 + (i % 2) * 196, 64 + (i / 2) * 148)
		cc.rotation = deg_to_rad([-2.0, 1.5, 1.0, -1.5, -1.0, 1.5, 1.0, -1.5][i % 8])
		_layer.add_child(cc)
	if can_print() and lesson == "practical":
		# every slot on the board is a card: the button takes the header's place
		_print_btn = UiKit.button("PRINT VIEW", &"", Vector2(250, 44))
		_print_btn.name = "print_view_button"
		_print_btn.add_theme_font_size_override("font_size", 20)
		_print_btn.position = PINS_RECT.position + Vector2((PINS_RECT.size.x - 250) * 0.5, 8)
		_print_btn.pressed.connect(open_print)
		if UiKit.show_key_hints():
			var kc := UiKit.key_chip("P", 14)
			kc.position = Vector2(8, 8)
			_print_btn.add_child(kc)
		_layer.add_child(_print_btn)
	elif can_print():
		_print_btn = UiKit.button("PRINT VIEW", &"", Vector2(182, 132))
		_print_btn.name = "print_view_button"
		_print_btn.add_theme_font_size_override("font_size", 22)
		_print_btn.position = PINS_RECT.position + Vector2(206, 362)
		_print_btn.rotation = deg_to_rad(1.5)
		_print_btn.pressed.connect(open_print)
		if UiKit.show_key_hints():
			var kc := UiKit.key_chip("P", 15)
			kc.position = Vector2(8, 8)
			_print_btn.add_child(kc)
		_layer.add_child(_print_btn)


func _welcome() -> String:
	if lesson == "practical":
		if TrainingProgress.data(PracticalDeck.LESSON)["stations"].is_empty():
			return "The practical: two rooms, one live ear, no notes. Let's make your hands remember."
		if can_print():
			return "All eight cards! Press P for the print view: one page to take with you."
		return "Back for more practice? Pick a station, or replay one for its star."
	if TrainingProgress.data(MaskDeck.LESSON)["stations"].is_empty():
		return "Welcome to my Training room! Short lessons, big ideas. Start with masking?"
	if can_print():
		return "Every card earned! Press P for the print view: all five on one page."
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
	var sign := Rect2(36, 12, 560, 44)
	UiDraw.rounded_rect(ci, Rect2(sign.position + Vector2(0, 5), sign.size), Color(0, 0, 0, 0.3), 14)
	UiDraw.rounded_rect(ci, sign, Palette.INK, 14, 4, FRAME)
	ci.draw_string(f, sign.position + Vector2(0, 33), "HOOT'S TRAINING ROOM", HORIZONTAL_ALIGNMENT_CENTER, sign.size.x, 28, Palette.SUNNY)
	# the lesson card
	var lc := LESSON_RECT
	var practical := lesson == "practical"
	var d := deck()
	UiDraw.rounded_rect(ci, Rect2(lc.position + Vector2(0, 8), lc.size), Color(0, 0, 0, 0.3), 26)
	UiDraw.rounded_rect(ci, lc, LESSONS[_lesson_index(lesson)][2], 26, 4, Palette.INK)
	ci.draw_string(f, lc.position + Vector2(30, 56), "THE PRACTICAL" if practical else "MASKING SCHOOL", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.PAPER)
	ci.draw_string(UiKit.font(600), lc.position + Vector2(32, 86), "California's two rooms, practised one station at a time." if practical
		else "Why, when and how much: and the occlusion effect.", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color(Palette.PAPER, 0.85))
	if practical and Licence.earned():
		Licence.draw(ci, lc.position + Vector2(lc.size.x - 74, 50), 0.5, Licence.grade(), Licence.passed())
	elif practical:
		_draw_clipboard(ci, lc.position + Vector2(lc.size.x - 84, 50), 1.0)
	elif has_diploma():
		Diploma.draw(ci, lc.position + Vector2(lc.size.x - 84, 46), 0.62, MaskDeck.exam_grade(int(TrainingProgress.station(MaskDeck.LESSON, "exam")["best"])))
	else:
		_draw_mask(ci, lc.position + Vector2(lc.size.x - 92, 50), 1.0)
	var stars := TrainingProgress.stars(d.LESSON)
	ci.draw_string(f, lc.position + Vector2(lc.size.x - 340, 52), "%d of %d stars" % [stars, d.STATIONS.size()], HORIZONTAL_ALIGNMENT_RIGHT, 200, 18, Palette.SUNNY)
	ci.draw_circle(lc.position + Vector2(lc.size.x * 0.5, 4), 9.0, Palette.CORAL)
	# the pin board for the cheat-sheet cards
	var pb := PINS_RECT
	UiDraw.rounded_rect(ci, pb, Color(FRAME, 0.35), 22, 4, FRAME)
	if not (practical and can_print()):   # The Practical's print button takes the header's place
		ci.draw_string(f, pb.position + Vector2(0, 42), "MY CHEAT SHEETS", HORIZONTAL_ALIGNMENT_CENTER, pb.size.x, 26, Palette.PAPER)
	# "More lessons soon", dimmed, under Masking School's cards (the print view's tile once every card is earned)
	if practical or can_print():
		return
	var soon := Rect2(pb.position + Vector2(206, 362), Vector2(182, 132))
	UiDraw.rounded_rect(ci, soon, Color(Palette.PAPER, 0.25), 14, 3, Color(Palette.INK, 0.4))
	ci.draw_string(f, soon.position + Vector2(0, 56), "More lessons", HORIZONTAL_ALIGNMENT_CENTER, soon.size.x, 20, Color(Palette.INK, 0.6))
	ci.draw_string(f, soon.position + Vector2(0, 84), "soon!", HORIZONTAL_ALIGNMENT_CENTER, soon.size.x, 20, Color(Palette.INK, 0.6))


## The Practical's clipboard with a little otoscope, on its lesson card.
static func _draw_clipboard(ci: CanvasItem, c: Vector2, k: float) -> void:
	var board := Rect2(c + Vector2(-34, -40) * k, Vector2(68, 86) * k)
	UiDraw.rounded_rect(ci, board, Palette.WOOD, 8, 3, Palette.INK)
	UiDraw.rounded_rect(ci, Rect2(c + Vector2(-26, -28) * k, Vector2(52, 66) * k), Palette.PAPER, 4)
	UiDraw.rounded_rect(ci, Rect2(c + Vector2(-16, -48) * k, Vector2(32, 14) * k), Color("#c9ccd6"), 4, 2, Palette.INK)
	for i in 3:
		UiDraw.check(ci, c + Vector2(-14, -12 + i * 18) * k, 7.0 * k, Palette.MINT, 3.0)
		ci.draw_line(c + Vector2(-2, -12 + i * 18) * k, c + Vector2(20, -12 + i * 18) * k, Color(Palette.INK, 0.5), 2.0, true)
	# the otoscope, leaning on it
	var o := c + Vector2(44, 10) * k
	UiDraw.rounded_rect(ci, Rect2(o + Vector2(-7, 0) * k, Vector2(14, 40) * k), Color("#3b3f52"), 4, 2, Palette.INK)
	var head := PackedVector2Array([o + Vector2(-13, 0) * k, o + Vector2(13, 0) * k, o + Vector2(4, -22) * k, o + Vector2(-4, -22) * k])
	ci.draw_colored_polygon(head, Color("#c9ccd6"))
	var ol := head.duplicate()
	ol.append(head[0])
	ci.draw_polyline(ol, Palette.INK, 2.0, true)


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
