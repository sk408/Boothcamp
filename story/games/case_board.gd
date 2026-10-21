extends Control
## CaseBoard (cases): the case file. First the audiogram stamps in; once the player has named the
## shape, its pattern comes alive (a crash cymbal, or a firework, out of a noise notch; a wave over a
## low-pitch loss; an alarm clock by a one-sided loss; a cookie bite out of the middle pitches; an
## air-bone gap plugged by a waxy cork, or filled with water and a rubber duck), with any earlier
## chart on file ("previous") dashed behind it. The board-internal "retest" pattern (the runner builds
## its case dict) dashes the first visit's chart behind today's, with mint arrows showing the climb.
## Then the file opens: the chart on the left, the clue cards on the right, and three rubber stamps
## underneath: FIT / REFER / DOCTOR TODAY.
## The player stamps the call, then presents the clue card that proves it (docs/CASES.md §3, §6, §7).
## The stamps and the cards are ordinary `choice` beats (same info as DialogueBox.choose), and their
## labels start with the option text, so the autoplay bot plays them by keys or by mouse with no route.
## Story-internal:
##   var b := CaseBoard.new(); b.setup(case_dict); hud.add_game(b)
##   await b.run_reveal(results)        # every mark stamps in
##   await b.show_pattern()             # the case's "reveal" pattern + its title
##   b.set_compact(true)                # the chart shrinks to the top (dialogue choices go below)
##   b.show_type("Sensorineural loss")  # a badge on the chart
##   await b.open_file(clues)           # [{tag, text, kind, src}]: the case-file layout
##   var d: int = await b.choose_stamp(prompt, best)   # index into CaseRules.DECISIONS
##   await b.slam(decision, right)      # the stamp lands (right) or bounces off (wrong)
##   var i: int = await b.choose_clue(prompt, best)    # index into the clue cards
##   b.mark_card(i, right)
##   await b.fade_out()
## Anchors: "reveal_audiogram", "case_stamps", "case_clues".

signal _picked(index: int)

const UiKit := preload("res://story/ui_kit.gd")
const CaseData := preload("res://story/case_data.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"
const COMPACT_SCALE := 0.72
const FILE_SCALE := 0.56
const FILE_CHART_AT := Vector2(22, 86)
const GRID := Rect2(528, 86, 730, 276)
const GRID_COLS := 3
const MAX_CARDS := CaseData.MAX_CARDS
const TRAY_Y := 384.0
const STAMP_SIZE := Vector2(300, 112)
const STAMP_COLORS: Dictionary[StringName, Color] = {&"fit": Color("#2f9e73"), &"refer": Color("#2d6cdf"), &"today": Color("#e5383b")}
const CARD_COLORS: Array[Color] = [Color("#fff1a8"), Color("#ffd9e8"), Color("#d6f5e3"), Color("#dbe9ff")]
const SRC_TITLES: Dictionary = {"history": "THEY SAID", "flag": "RED-FLAG CHECK", "look": "OTOSCOPE", "tymp": "TYMP", "test": "AUDIOGRAM", "note": "CASE NOTE"}
const WAVE := Color("#36a3e7")
const COOKIE := Color("#d99a5b")
const WAX := Color("#c98a3a")
const WAX_DARK := Color("#8a5a24")
const BONE := Color("#f4ead2")
const STIFF_TAG := Color("#dccbf2")
const GAP_STEPS := 24                   # samples along the gap band (500-4k)

var case_data: Dictionary = {}
var results: Dictionary = {}
var ag: Audiogram
var compact := false
var clues: Array[Dictionary] = []
var _card: PanelContainer
var _head: VBoxContainer
var _head_title: Label
var _fx: Control
var _title: Label
var _title_spot := Vector2.ZERO
var _pattern := ""
var _pattern_t := -1.0
var _type_text := ""
var _type_t := -1.0
var _t := 0.0
var _card_home := Vector2.ZERO
var _banner: PanelContainer
var _banner_label: Label
var _tray: Control
var _stamps: Array[Button] = []
var _stamp_dead: Dictionary = {}
var _cards: Array[Button] = []
var _card_state: Dictionary = {}       # card index -> "wrong" / "right"
var _mode := ""                         # "stamp" / "clue" while waiting for a pick
var _slam: StringName = &""
var _slam_right := false
var _slam_t := -1.0
var _hints: HBoxContainer
var _backdrop: Control


func setup(p_case: Dictionary) -> void:
	case_data = p_case


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(Palette.CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_backdrop = UiKit.full_rect()
	_backdrop.draw.connect(_draw_backdrop.bind(_backdrop))
	add_child(_backdrop)
	_head = VBoxContainer.new()
	_head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_head.offset_top = 18
	_head.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_head)
	var who := String(case_data.get("speaker", "Patient")).to_upper()
	_head_title = UiKit.label("%s'S AUDIOGRAM" % who if not who.ends_with("S") else "%s' AUDIOGRAM" % who, 34, Palette.INK, 700)
	_head_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_child(_head_title)
	var legend := Control.new()
	legend.custom_minimum_size = Vector2(980, 30)
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.draw.connect(_draw_legend.bind(legend))
	_head.add_child(legend)
	_card = UiKit.panel(Palette.PAPER, Palette.INK, 22)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.offset_left = -430
	_card.offset_right = 430
	_card.offset_top = -262
	_card.offset_bottom = 170
	add_child(_card)
	if ResourceLoader.exists(AUDIOGRAM_SCENE):
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Audiogram
		ag.ear = "both"
		ag.show_notes = true   # (E18) transducer, mastoids, reliability under the chart
		ag.custom_minimum_size = Vector2(820, 400)
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_card.add_child(ag)
		Hoot.register_anchor("reveal_audiogram", ag)
	# the case file's clue cards and stamp tray (shown by open_file)
	_tray = UiKit.full_rect()
	_tray.visible = false
	add_child(_tray)
	_fx = UiKit.full_rect()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_title = UiKit.label("", 38, Palette.CORAL, 700, 14, Palette.INK)
	_title.visible = false
	add_child(_title)
	_banner = UiKit.panel(Palette.PAPER, Palette.INK, 18)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 12
	_banner.visible = false
	add_child(_banner)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 0)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(bv)
	var case_title := UiKit.label(String(case_data.get("case_title", "THE CASE")), 13, Palette.INK_SOFT, 700)
	case_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(case_title)
	_banner_label = UiKit.label("", 24, Palette.INK, 700)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(_banner_label)
	_hints = HBoxContainer.new()
	_hints.alignment = BoxContainer.ALIGNMENT_CENTER
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hints.position = Vector2(0, TRAY_Y + STAMP_SIZE.y + 10)
	_hints.size = Vector2(1280, 30)
	add_child(_hints)


func _exit_tree() -> void:
	for a: String in ["reveal_audiogram", "case_stamps", "case_clues"]:
		Hoot.unregister_anchor(a)


## (coroutine) Stamp every mark in, low to high pitch.
func run_reveal(p_results: Dictionary) -> void:
	results = p_results
	Juice.bounce_in(_card, 0.45)
	await get_tree().create_timer(0.5, false).timeout
	if ag == null:
		return
	ag.show_results(results, true)
	await ag.draw_finished
	await get_tree().create_timer(0.3, false).timeout


## (coroutine) The case's pattern comes alive on the chart, then its title pops.
func show_pattern() -> void:
	var rv: Dictionary = case_data.get("reveal", {})
	_pattern = String(rv.get("pattern", ""))
	_pattern_t = 0.0
	match _pattern:
		"notch":
			Sfx.play(&"whoosh", 0.7, -6.0)
			var cymbal := String(rv.get("burst", "")) == "cymbal"
			get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
				if cymbal:
					Sfx.play(&"thunk", 0.8, -4.0)
					Sfx.play(&"sparkle", 0.6, -4.0)
				else:
					Sfx.play(&"fanfare", 1.2, -4.0)
				Events.screen_shake.emit(0.35, 0.2))
		"rising":
			Sfx.play(&"whoosh", 0.55, -4.0)
		"flat_one":
			Sfx.play(&"error", 1.3, -6.0)
		"cookie":
			get_tree().create_timer(0.55, false).timeout.connect(func() -> void:
				Sfx.play(&"thunk", 1.5, -2.0)
				Events.screen_shake.emit(0.25, 0.15))
		"gap":
			# the Audiogram's own bridge posts, and the other ear fades so the eye compares bone with air
			# (both ears stay bright when the gap is in both, Day 13)
			if ag != null:
				var other := "left" if _focus_ear() == "right" else "right"
				ag.show_gap = true
				if String(rv.get("ear", "right")) != "both":
					create_tween().tween_method(func(a: float) -> void: ag.dim = {other: a}, 1.0, 0.3, 0.5)
			if String(rv.get("plug", "wax")) == "stiff":
				Sfx.play(&"whoosh", 0.6, -6.0)
				get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
					Sfx.play(&"thunk", 0.55, -2.0)
					Events.screen_shake.emit(0.3, 0.15))
				get_tree().create_timer(0.75, false).timeout.connect(func() -> void: Sfx.play(&"blip", 1.7, -4.0))
			elif String(rv.get("plug", "wax")) == "fluid":
				Sfx.play(&"whoosh", 0.45, -6.0)
				for i in 3:
					var pitch := 1.0 + 0.25 * i
					get_tree().create_timer(0.4 + 0.2 * i, false).timeout.connect(func() -> void: Sfx.play(&"blip", pitch, -6.0))
			else:
				Sfx.play(&"whoosh", 0.7, -6.0)
				get_tree().create_timer(0.45, false).timeout.connect(func() -> void:
					Sfx.play(&"thunk", 0.7, -2.0)
					Sfx.play(&"pop", 0.8, -4.0)
					Events.screen_shake.emit(0.45, 0.2))
		"shadow":
			# (Day 12) a low whoosh as the shadow draws, then a ghostly blip as the ghost pops up
			Sfx.play(&"whoosh", 0.45, -6.0)
			get_tree().create_timer(1.2, false).timeout.connect(func() -> void: Sfx.play(&"blip", 0.6, -6.0))
		"retest":
			Sfx.play(&"pop", 1.0, -4.0)
			# the fanfare lands with the arrows (they shoot up once the earlier chart has drawn)
			get_tree().create_timer(1.2, false).timeout.connect(func() -> void:
				Sfx.play(&"fanfare", 1.0, -4.0)
				Sfx.play(&"sparkle", 1.0, -4.0))
	await get_tree().create_timer(1.0, false).timeout
	_title.text = String(rv.get("title", ""))
	_title.reset_size()
	_title_spot = _title_home()
	_title.pivot_offset = _title.size * 0.5
	_place_title()
	_title.visible = _title.text != ""
	# pop, but settle at the chart's scale (Juice.pop would settle at 1.0, too big on a compact chart)
	var sc := _sc()
	_title.scale = Vector2.ONE * sc * (lerpf(1.0, 1.7, 0.3) if Juice._reduced() else 1.7)
	create_tween().tween_property(_title, "scale", Vector2.ONE * sc, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"ding", 1.0, -4.0)
	await get_tree().create_timer(0.6, false).timeout


## Shrink the chart to the top of the screen (dialogue choices go below it), or restore it.
func set_compact(on: bool) -> void:
	if compact == on:
		return
	compact = on
	_remember_home()
	var vis := Vector2((size.x - _card.size.x * COMPACT_SCALE) * 0.5, 12.0)
	_move_card(COMPACT_SCALE if on else 1.0, vis if on else Vector2.INF)
	var t := create_tween()
	t.tween_property(_head, "modulate:a", 0.0 if on else 1.0, 0.2)


## A badge naming the type of loss on the chart.
func show_type(text: String) -> void:
	_type_text = text.to_upper()
	_type_t = 0.0
	Sfx.play(&"stamp", 1.4, -10.0)


## (coroutine) The case-file layout: the chart slides to the left, the clue cards deal in on the
## right, and the stamp tray rises. clues: [{tag, text, kind ("clue" / "flag"), src}].
func open_file(p_clues: Array[Dictionary]) -> void:
	clues.assign(p_clues.slice(0, MAX_CARDS))
	if ag != null:
		ag.dim = {}   # a "gap" reveal faded one ear: the case file shows both
	compact = true
	_remember_home()
	_move_card(FILE_SCALE, FILE_CHART_AT)
	var th := create_tween()
	th.tween_property(_head, "modulate:a", 0.0, 0.2)
	_build_cards()
	_build_tray()
	_tray.visible = true
	_banner.visible = true
	_backdrop.queue_redraw()
	await get_tree().create_timer(0.3, false).timeout
	for i in _cards.size():
		Juice.bounce_in(_cards[i], 0.3 + 0.05 * i)
		Sfx.play(&"pen", 1.0 + 0.05 * i, -12.0)
		await get_tree().create_timer(0.07, false).timeout
	for i in _stamps.size():
		Juice.bounce_in(_stamps[i], 0.35)
	await get_tree().create_timer(0.4, false).timeout


## (coroutine) Beat "choice": pick a rubber stamp (click, keys 1-3). Returns the CaseRules.DECISIONS index.
func choose_stamp(prompt: String, best: int) -> int:
	_set_prompt(prompt)
	var opts: Array[String] = []
	for d: StringName in CaseRules.DECISIONS:
		opts.append(CaseRules.DECISION_STAMPS[d])
	_show_hints(opts.size(), "Click a stamp")
	_mode = "stamp"
	Events.awaiting_input.emit(&"choice", {"prompt": prompt, "options": opts, "best": best}, func() -> void: _pick(best))
	var i: int = await _picked
	Events.input_resolved.emit(&"choice")
	return i


## (coroutine) The stamp comes down on the file: right = it lands and stays, wrong = it bounces off
## with a "?" and that stamp goes grey.
func slam(decision: StringName, right: bool) -> void:
	_slam = decision
	_slam_right = right
	_slam_t = 0.0
	var i := CaseRules.DECISIONS.find(decision)
	if not right and i >= 0:
		_stamp_dead[i] = true
		_stamps[i].queue_redraw()
		Sfx.play(&"boing", 0.9, -6.0)
	else:
		Sfx.play(&"stamp", 0.7, 0.0)
		Events.screen_shake.emit(0.6, 0.3)
	await get_tree().create_timer(0.7, false).timeout
	if not right:
		_slam = &""
		_slam_t = -1.0


## (coroutine) Beat "choice": present a clue card (click, keys 1-9). Returns the card index.
func choose_clue(prompt: String, best: int) -> int:
	_set_prompt(prompt)
	for s in _stamps:
		var t := s.create_tween()
		t.tween_property(s, "modulate:a", 0.0, 0.25)
		t.tween_callback(func() -> void: s.visible = false)
	var opts: Array[String] = []
	for c: Dictionary in clues:
		opts.append(String(c["text"]))
	_show_hints(opts.size(), "Click a clue card")
	_mode = "clue"
	Events.awaiting_input.emit(&"choice", {"prompt": prompt, "options": opts, "best": best}, func() -> void: _pick(best))
	var i: int = await _picked
	Events.input_resolved.emit(&"choice")
	return i


## A clue card's verdict: right = it glows and gets "EXHIBIT A", wrong = it shakes and dims.
func mark_card(i: int, right: bool) -> void:
	if i < 0 or i >= _cards.size():
		return
	_card_state[i] = "right" if right else "wrong"
	if right:
		Juice.pop(_cards[i], 1.18, 0.3)
		Sfx.play(&"kaching", 1.0, -6.0)
	else:
		Juice.shake(_cards[i], 7.0, 0.3)
		Sfx.play(&"error", 1.0, -10.0)
	_cards[i].queue_redraw()


## (coroutine) Fade the whole board away.
func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished


# ---------------------------------------------------------------- input

func _pick(i: int) -> void:
	if _mode == "":
		return
	if _mode == "stamp" and (i < 0 or i >= _stamps.size() or _stamp_dead.has(i)):
		return
	if _mode == "clue" and (i < 0 or i >= _cards.size() or _card_state.get(i, "") == "wrong"):
		return
	var was := _mode
	_mode = ""
	Sfx.play(&"click")
	for c in _hints.get_children():
		c.queue_free()
	if was == "clue":
		Juice.pop(_cards[i], 1.08, 0.15)
	else:
		Juice.pop(_stamps[i], 1.08, 0.15)
	_picked.emit(i)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == "" or not (event is InputEventKey) or not event.is_pressed() or event.is_echo():
		return
	var k := (event as InputEventKey).keycode
	if k < KEY_1 or k > KEY_9:
		k = (event as InputEventKey).physical_keycode
	var n := _stamps.size() if _mode == "stamp" else _cards.size()
	var i := -1
	if k >= KEY_1 and k <= KEY_9:
		i = k - KEY_1
	elif k >= KEY_KP_1 and k <= KEY_KP_9:
		i = k - KEY_KP_1
	if i >= 0 and i < n:
		_pick(i)
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- building

func _remember_home() -> void:
	if _card_home == Vector2.ZERO:
		_card_home = _card.position


## Tween the chart card to a scale with its visible top-left corner at `visible_at`
## (Vector2.INF = back home at scale 1).
func _move_card(sc: float, visible_at: Vector2) -> void:
	var target_pos := _card_home
	if visible_at != Vector2.INF:
		target_pos = visible_at - _card.pivot_offset * (1.0 - sc)
	var t := create_tween().set_parallel(true)
	t.tween_property(_card, "scale", Vector2.ONE * sc, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_card, "position", target_pos, 0.35).set_trans(Tween.TRANS_SINE)
	t.tween_property(_title, "scale", Vector2.ONE * sc, 0.35)


func _set_prompt(prompt: String) -> void:
	_banner_label.text = prompt
	_banner.reset_size()
	# reset_size grows to the right only: centre it again (read the width first: setting
	# offset_left changes size)
	var w := _banner.size.x
	_banner.offset_left = -w / 2.0
	_banner.offset_right = w / 2.0
	Juice.pop(_banner, 1.06, 0.2)


func _show_hints(n: int, mouse_text: String) -> void:
	for c in _hints.get_children():
		c.queue_free()
	var parts: Array = [["1"], "-", [str(n)], "or", mouse_text.to_lower()] if UiKit.show_key_hints() else [mouse_text]
	_hints.add_child(UiKit.hint_panel(parts, 16))


func _build_cards() -> void:
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.position = GRID.position
	anchor.size = GRID.size
	_tray.add_child(anchor)
	Hoot.register_anchor("case_clues", anchor)
	var rows := ceili(clues.size() / float(GRID_COLS))
	var w := (GRID.size.x - 12.0 * (GRID_COLS - 1)) / GRID_COLS
	var h := minf(84.0, (GRID.size.y - 10.0 * (rows - 1)) / maxf(1.0, rows))
	for i in clues.size():
		var c: Dictionary = clues[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = GRID.position + Vector2((i % GRID_COLS) * (w + 12.0), (i / GRID_COLS) * (h + 10.0))
		b.size = Vector2(w, h)
		b.pivot_offset = b.size * 0.5
		b.draw.connect(_draw_card.bind(b, i))
		b.pressed.connect(func() -> void:
			if _mode == "clue":
				_pick(i))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		var l := UiKit.label(String(c["text"]).replace("\n", " "), 15, Palette.INK, 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.position = Vector2(30, 22)
		l.size = Vector2(w - 40, h - 26)
		l.add_theme_constant_override("line_spacing", -2)
		b.add_child(l)
		_tray.add_child(b)
		_cards.append(b)


func _build_tray() -> void:
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total := STAMP_SIZE.x * 3 + 30.0 * 2
	anchor.position = Vector2((1280.0 - total) * 0.5, TRAY_Y)
	anchor.size = Vector2(total, STAMP_SIZE.y)
	_tray.add_child(anchor)
	Hoot.register_anchor("case_stamps", anchor)
	for i in CaseRules.DECISIONS.size():
		var d: StringName = CaseRules.DECISIONS[i]
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.position = anchor.position + Vector2(i * (STAMP_SIZE.x + 30.0), 0)
		b.size = STAMP_SIZE
		b.pivot_offset = STAMP_SIZE * 0.5
		b.draw.connect(_draw_stamp_button.bind(b, i))
		b.pressed.connect(func() -> void:
			if _mode == "stamp":
				_pick(i))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		var big := UiKit.label(CaseRules.DECISION_STAMPS[d], 34 if i < 2 else 26, STAMP_COLORS[d], 700)
		big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big.position = Vector2(0, 40)
		big.size = Vector2(STAMP_SIZE.x, 40)
		b.add_child(big)
		var sub := UiKit.label(CaseRules.decision_title(d), 15, Palette.INK_SOFT, 600)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.position = Vector2(0, 82)
		sub.size = Vector2(STAMP_SIZE.x, 22)
		b.add_child(sub)
		_tray.add_child(b)
		_stamps.append(b)


# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	_t += delta
	if _pattern_t >= 0.0:
		_pattern_t += delta
	if _type_t >= 0.0:
		_type_t += delta
	if _slam_t >= 0.0:
		_slam_t += delta
	if _title.visible:
		_place_title()
	_fx.queue_redraw()
	if _mode != "":
		for b in _cards:
			b.queue_redraw()
	for i in _stamps.size():
		var b := _stamps[i]
		var lift := _stamp_lift(i)
		(b.get_child(0) as Control).position.y = 40.0 + lift
		(b.get_child(1) as Control).position.y = 82.0 + lift
		b.modulate = Color(1, 1, 1, b.modulate.a) if not _stamp_dead.has(i) else Color(0.85, 0.85, 0.85, b.modulate.a)
		b.queue_redraw()


## How far a stamp floats up under the mouse (0 when not hovered or not choosing).
func _stamp_lift(i: int) -> float:
	if _mode != "stamp" or _stamp_dead.has(i) or not _stamps[i].is_hovered():
		return 0.0
	return -6.0 + 2.0 * sin(_t * 6.0)


func _title_home() -> Vector2:
	if ag == null:
		return Vector2.ZERO
	var x := (ag.freq_to_x(500) + ag.freq_to_x(1000)) * 0.5
	if _pattern == "rising":
		x = (ag.freq_to_x(2000) + ag.freq_to_x(4000)) * 0.5
	return Vector2(x, ag.db_to_y(95.0))


func _place_title() -> void:
	if ag == null:
		return
	var spot := ag.get_global_transform_with_canvas() * _title_spot
	_title.position = spot - _title.size * 0.5
	_title.rotation = -0.06


func _sc() -> float:
	return _card.scale.x


func _to_fx(p: Vector2) -> Vector2:
	return _fx.get_global_transform_with_canvas().affine_inverse() * p


## A chart point (freq, dB) in fx coordinates.
func _pt(freq: int, db: float) -> Vector2:
	return _to_fx(ag.get_global_transform_with_canvas() * Vector2(ag.freq_to_x(freq), ag.db_to_y(db)))


func _air(ear: String) -> Dictionary:
	return ClinicRules.best_thresholds(results, ear, false)


func _bone(ear: String) -> Dictionary:
	return ClinicRules.best_thresholds(results, ear, true)


## The ear a pattern points at ("both" = the poorer ear at the case's frequency).
func _focus_ear() -> String:
	var rv: Dictionary = case_data.get("reveal", {})
	var ear := String(rv.get("ear", "right"))
	if ear != "both":
		return ear
	var f := int(rv.get("freq", 4000))
	return "left" if int(_air("left").get(f, 0)) > int(_air("right").get(f, 0)) else "right"


# ---------------------------------------------------------------- drawing

func _draw_backdrop(c: Control) -> void:
	if not _tray.visible:
		return
	# the manila folder behind the case file
	var r := Rect2(Vector2(8, 70), Vector2(1264, 440))
	UiDraw.rounded_rect(c, Rect2(r.position + Vector2(0, 6), r.size), Color(Palette.INK, 0.15), 20)
	UiDraw.rounded_rect(c, r, Color("#f4d58d"), 20, 3, Color(Palette.INK, 0.6))
	UiDraw.rounded_rect(c, Rect2(Vector2(40, 52), Vector2(220, 30)), Color("#f4d58d"), 10, 3, Color(Palette.INK, 0.6))
	c.draw_string(UiKit.font(700), Vector2(56, 74), "CASE FILE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)


func _draw_legend(c: Control) -> void:
	var f := UiKit.font(600)
	var items: Array = []
	for ear: String in ["right", "left"]:
		var e: Dictionary = (results.get("ears", {}) as Dictionary).get(ear, {})
		var side := "Right" if ear == "right" else "Left"
		if results.is_empty() or not (e.get("freqs", {}) as Dictionary).is_empty():
			items.append([ear, &"ac", side + " air"])
		for pair: Array in [["bc", "bone"], ["bc_masked", "bone, masked"], ["ac_masked", "air, masked"]]:
			if not (e.get(String(pair[0]), {}) as Dictionary).is_empty():
				items.append([ear, StringName(pair[0]), side + " " + String(pair[1])])
	var total := 0.0
	for it: Array in items:
		total += 44.0 + f.get_string_size(String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var x := maxf(0.0, (c.size.x - total) * 0.5)
	for it: Array in items:
		UiDraw.audiogram_symbol(c, Vector2(x + 10.0, 15.0), String(it[0]), it[1], 14.0, 3.0)
		c.draw_string(f, Vector2(x + 26.0, 21.0), String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)
		x += 44.0 + f.get_string_size(String(it[2]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x


func _draw_fx() -> void:
	if ag == null:
		return
	if _pattern_t >= 0.0:
		match _pattern:
			"notch":
				_draw_notch()
			"rising":
				_draw_rising()
			"flat_one":
				_draw_flat_one()
			"cookie":
				_draw_cookie()
			"gap":
				_draw_gap()
			"shadow":
				_draw_shadow()
			"retest":
				_draw_previous([500, 1000, 2000, 4000] as Array[int], true)
	if _type_t >= 0.0:
		_draw_type()
	if _slam_t >= 0.0 and _slam != &"":
		_draw_slam()


## A firework bursts out of the dip (or, with "burst": "cymbal", a crash cymbal drops into it and
## leaves a dent); an arrow shows the climb back up at 8k.
func _draw_notch() -> void:
	var s := _sc()
	var f := int((case_data.get("reveal", {}) as Dictionary).get("freq", 4000))
	var f_font := UiKit.font(700)
	var cymbal := String((case_data.get("reveal", {}) as Dictionary).get("burst", "")) == "cymbal"
	var bang := "TSSSH!" if cymbal else "KA-BOOM!"
	for ear: String in ["right", "left"]:
		var air := _air(ear)
		if not air.has(f):
			continue
		var p := _pt(f, float(air[f]))
		var col := Palette.ear_color(ear)
		if cymbal:
			_fx.draw_arc(p, 18.0 * s, 0, TAU, 24, Color(col, 0.8), 3.0, true)
			if ear == _focus_ear():
				_draw_cymbal(p, s)
			continue
		# the burst repeats every 2.4 s, the two ears a little out of step
		var lap := fmod(_pattern_t + (0.0 if ear == "right" else 0.35), 2.4)
		var k := clampf(lap / 0.9, 0.0, 1.0)
		if lap < 1.2:
			for i in 12:
				var a := TAU * i / 12.0 + (0.0 if ear == "right" else 0.26)
				var r0 := (8.0 + 40.0 * k) * s
				var r1 := (16.0 + 70.0 * k) * s
				var c2: Color = [Palette.SUNNY, Palette.CORAL, col][i % 3]
				c2.a = 1.0 - k
				_fx.draw_line(p + Vector2(cos(a), sin(a)) * r0, p + Vector2(cos(a), sin(a)) * r1, c2, 4.0 * s, true)
		_fx.draw_arc(p, 18.0 * s, 0, TAU, 24, Color(col, 0.8), 3.0, true)
	var ear2 := _focus_ear()
	var air2 := _air(ear2)
	if air2.has(f) and air2.has(8000) and _pattern_t > 0.5:
		var a0 := _pt(f, float(air2[f])) + Vector2(14, 22) * s
		var a1 := _pt(8000, float(air2[8000])) + Vector2(-6, 26) * s
		var mid := (a0 + a1) * 0.5 + Vector2(0, 46) * s
		var pts := PackedVector2Array()
		for i in 13:
			var u := i / 12.0
			pts.append(a0.lerp(mid, u).lerp(mid.lerp(a1, u), u))
		_fx.draw_polyline(pts, Palette.MINT.darkened(0.2), 4.0 * s, true)
		UiDraw.arrow(_fx, a1, 14.0 * s, (a1 - pts[10]).normalized(), Palette.MINT.darkened(0.2))
		_fx.draw_string(f_font, mid + Vector2(-48, 26) * s, "back up at 8k", HORIZONTAL_ALIGNMENT_LEFT, -1, int(17 * s + 0.5), Palette.MINT.darkened(0.3))
		if _pattern_t < 2.2:
			var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - (_pattern_t - 0.5) / 0.3)
			var kp := _pt(f, float(air2[f])) + Vector2(-110, -64) * s
			_fx.draw_set_transform(kp, -0.12, Vector2.ONE * pop * s)
			_fx.draw_string_outline(f_font, Vector2.ZERO, bang, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 9, Palette.INK)
			_fx.draw_string(f_font, Vector2.ZERO, bang, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.SUNNY)
			_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A crash cymbal drops onto a chart point, lands with a wobble and shimmers.
func _draw_cymbal(p: Vector2, s: float) -> void:
	var k := clampf(_pattern_t / 0.45, 0.0, 1.0)
	var since := maxf(0.0, _pattern_t - 0.45)
	var at := p + Vector2(0, -18.0 * s - (1.0 - k) * (1.0 - k) * 170.0 * s)
	var wob := sin(since * 26.0) * exp(-since * 2.5) * 0.3 if k >= 1.0 else -0.15
	_fx.draw_set_transform(at, wob, Vector2.ONE * s)
	var rim := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		rim.append(Vector2(cos(a) * 52.0, sin(a) * 13.0))
	var shadow := PackedVector2Array()
	for q: Vector2 in rim:
		shadow.append(q + Vector2(0, 5))
	_fx.draw_colored_polygon(shadow, Color(Palette.INK, 0.25))
	_fx.draw_colored_polygon(rim, Color("#e9b949"))
	_fx.draw_polyline(rim, Palette.INK, 3.0, true)
	for rr: float in [0.72, 0.45]:
		var g := PackedVector2Array()
		for q: Vector2 in rim:
			g.append(q * rr)
		_fx.draw_polyline(g, Color("#b8860b", 0.7), 1.5, true)
	_fx.draw_circle(Vector2(0, -3), 7.0, Palette.INK)
	_fx.draw_circle(Vector2(0, -3), 5.0, Color("#f6d27a"))
	_fx.draw_line(Vector2(0, -8), Vector2(0, -60), Palette.INK_SOFT, 3.0, true)
	if k >= 1.0 and since < 1.6:
		for side: float in [-1.0, 1.0]:
			for j in 2:
				var x := (62.0 + 10.0 * j) * side
				_fx.draw_line(Vector2(x, -8), Vector2(x + 6.0 * side, 8), Color(Palette.SUNNY.darkened(0.2), 1.0 - since / 1.6), 3.0, true)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## An earlier chart on file (the case's reveal "previous"), dashed in the ear's colour behind
## today's, with its label; coral arrows show the drop at freqs. With improve (the retest board),
## mint arrows show the climb instead, wherever the earlier chart was 10 dB or more poorer.
func _draw_previous(freqs: Array[int], improve := false) -> void:
	var s := _sc()
	var rv: Dictionary = case_data.get("reveal", {})
	var prev: Dictionary = rv.get("previous", {})
	if prev.is_empty():
		return
	var ear := String(prev.get("ear", rv.get("ear", "right")))
	if ear == "both":
		ear = "right"
	var col := Palette.ear_color(ear)
	var air := _air(ear)
	var f_font := UiKit.font(700)
	var pth := CaseData.thresholds(prev.get("thresholds", {}))
	var keys: Array = pth.keys()
	keys.sort()
	var reveal_k := clampf(_pattern_t / 1.2, 0.0, 1.0)
	var last_x := INF
	for i in keys.size() - 1:
		var p0 := _pt(int(keys[i]), float(pth[keys[i]]))
		var p1 := _pt(int(keys[i + 1]), float(pth[keys[i + 1]]))
		if float(i) / maxf(1.0, keys.size() - 1) > reveal_k:
			break
		var dl := p0.distance_to(p1)
		var n := maxi(1, int(dl / (12.0 * s)))
		for j in n:
			if j % 2 == 0:
				_fx.draw_line(p0.lerp(p1, float(j) / n), p0.lerp(p1, float(j + 1) / n), Color(col, 0.55), 3.0 * s, true)
		last_x = p1.x
	for fk: Variant in keys:
		var pp := _pt(int(fk), float(pth[fk]))
		if pp.x <= last_x + 1.0:
			_fx.draw_circle(pp, 4.0 * s, Color(col, 0.5))
	if keys.size() > 0 and reveal_k >= 1.0:
		var lp := _pt(int(keys[0]), float(pth[keys[0]])) + Vector2(-8, -18) * s
		_fx.draw_string(f_font, lp, String(prev.get("label", "BEFORE")), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s + 0.5), Color(col, 0.8))
		for fq: int in freqs:
			if improve:
				if air.has(fq) and pth.has(fq) and int(pth[fq]) - int(air[fq]) >= 10:
					_draw_gain(_pt(fq, float(air[fq])), _pt(fq, float(pth[fq])), int(pth[fq]) - int(air[fq]))
			elif air.has(fq) and pth.has(fq):
				var top := _pt(fq, float(pth[fq])) + Vector2(10, 6) * s
				var bot := _pt(fq, float(air[fq])) + Vector2(10, -14) * s
				if bot.y - top.y > 10.0:
					_fx.draw_line(top, bot, Palette.CORAL, 3.0 * s, true)
					UiDraw.arrow(_fx, bot, 11.0 * s, Vector2.DOWN, Palette.CORAL)
					_fx.draw_string(f_font, (top + bot) * 0.5 + Vector2(8, 5) * s, "-%d" % (int(air[fq]) - int(pth[fq])), HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * s + 0.5), Palette.CORAL)


## A mint arrow from an earlier, poorer point up to today's, labelled with the dB gained. It shoots
## up once the earlier chart has drawn in, and a star twinkles where it lands.
func _draw_gain(today: Vector2, before: Vector2, gained: int) -> void:
	var s := _sc()
	# tight offsets so even a 10 dB climb (about 28 px at full size) still gets its arrow
	var hi := today + Vector2(10, 12) * s
	var lo := before + Vector2(10, -4) * s
	var grow := clampf((_pattern_t - 1.2) / 0.35, 0.0, 1.0)
	if lo.y - hi.y <= 4.0 * s or grow <= 0.0:
		return
	var tip := lo.lerp(hi, grow)
	var col := Palette.MINT.darkened(0.2)
	_fx.draw_line(lo, tip, col, 3.0 * s, true)
	UiDraw.arrow(_fx, tip, 11.0 * s, Vector2.UP, col)
	var f_font := UiKit.font(700)
	var fs := int(17 * s + 0.5)
	var lp := (lo + tip) * 0.5 + Vector2(8, 5) * s
	var txt := "+%d" % gained
	_fx.draw_string_outline(f_font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Palette.PAPER)
	_fx.draw_string(f_font, lp, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.MINT.darkened(0.3))
	var since := _pattern_t - 1.55
	# stops while it is still a pixel wide (a vanishing polygon fails to triangulate)
	if since > 0.0 and since < 0.7:
		UiDraw.star(_fx, tip + Vector2(0, -12) * s, 8.0 * s * (1.0 - since / 0.8), Palette.SUNNY)


## A wave rolls over the low pitches; last spring's line sits above today's, dashed.
func _draw_rising() -> void:
	var s := _sc()
	var rv: Dictionary = case_data.get("reveal", {})
	var ear := String(rv.get("ear", "left"))
	var air := _air(ear)
	_draw_previous([250, 500] as Array[int])
	# the wave: a crest rolls in from the left over 250-1k, then bobs
	if air.has(500):
		var roll := clampf(_pattern_t / 1.0, 0.0, 1.0)
		var x0 := _pt(250, 0).x - 30.0 * s
		var x1 := lerpf(x0, _pt(1000, 0).x + 20.0 * s, roll)
		var pts := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var x := lerpf(x0, x1, float(i) / n)
			var base_db := float(air.get(500, 40)) - 12.0
			var y := _pt(500, base_db).y + sin(x * 0.05 / s + _t * 3.0) * 6.0 * s
			pts.append(Vector2(x, y))
		var poly := pts.duplicate()
		poly.append(Vector2(x1, _pt(500, -10).y))
		poly.append(Vector2(x0, _pt(500, -10).y))
		_fx.draw_colored_polygon(poly, Color(WAVE, 0.18))
		_fx.draw_polyline(pts, Color(WAVE, 0.9), 4.0 * s, true)
		for i in range(2, n, 4):
			var q := pts[i]
			_fx.draw_arc(q + Vector2(0, -6) * s, 6.0 * s, PI, TAU, 8, Color.WHITE, 2.5 * s, true)


## An alarm clock rings beside the one-sided loss; the gap between the ears is shaded.
func _draw_flat_one() -> void:
	var s := _sc()
	var rv: Dictionary = case_data.get("reveal", {})
	var ear := String(rv.get("ear", "right"))
	var other := "left" if ear == "right" else "right"
	var a := _air(ear)
	var b := _air(other)
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for fq: int in ClinicRules.AC_FREQS:
		if a.has(fq) and b.has(fq):
			top.append(_pt(fq, float(b[fq])))
			bot.append(_pt(fq, float(a[fq])))
	var k := clampf(_pattern_t / 0.8, 0.0, 1.0)
	if top.size() >= 2:
		var poly := top.duplicate()
		for i in range(bot.size() - 1, -1, -1):
			poly.append(bot[i])
		_fx.draw_colored_polygon(poly, Color(Palette.ear_color(ear), 0.14 * k))
	if not a.has(8000):
		return
	var cc := _pt(8000, float(a[8000])) + Vector2(56, -10) * s
	var ring := _pattern_t < 2.6 or fmod(_pattern_t, 3.0) < 0.6
	var wob := sin(_t * 40.0) * 0.14 if ring else 0.0
	_fx.draw_set_transform(cc, wob, Vector2.ONE * s)
	for side: float in [-1.0, 1.0]:
		_fx.draw_circle(Vector2(18 * side, -26), 10.0, Palette.INK)
		_fx.draw_circle(Vector2(18 * side, -26), 7.0, Palette.SUNNY)
		_fx.draw_line(Vector2(14 * side, 22), Vector2(20 * side, 32), Palette.INK, 5.0, true)
	_fx.draw_circle(Vector2.ZERO, 30.0, Palette.INK)
	_fx.draw_circle(Vector2.ZERO, 26.0, Palette.CORAL)
	_fx.draw_circle(Vector2.ZERO, 20.0, Palette.PAPER)
	var hours := fmod(_t * 0.5, TAU)
	_fx.draw_line(Vector2.ZERO, Vector2(cos(hours - PI / 2), sin(hours - PI / 2)) * 10.0, Palette.INK, 3.0, true)
	_fx.draw_line(Vector2.ZERO, Vector2(cos(hours * 12.0 - PI / 2), sin(hours * 12.0 - PI / 2)) * 15.0, Palette.INK, 2.0, true)
	if ring:
		# the ring only comes out of one side: he woke up to it in one ear
		for j in 2:
			_fx.draw_arc(Vector2.ZERO, 38.0 + 8.0 * j, PI - 0.5, PI + 0.5, 8, Palette.CORAL, 3.0, true)
		_fx.draw_string_outline(UiKit.font(700), Vector2(-30, -48), "RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 7, Palette.INK)
		_fx.draw_string(UiKit.font(700), Vector2(-30, -48), "RING!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.SUNNY)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## (Day 12) The shadow curve: the case ear's unmasked air, which the other ear heard across the head,
## draws as a dashed line of open circles (the Audiogram shows the masked no-response marks in its
## place), then the Cross-Hearing Ghost bobs beside it with a "SHADOW" sticker.
func _draw_shadow() -> void:
	var s := _sc()
	var ear := _focus_ear()
	var col := Palette.ear_color(ear)
	var sheet: Dictionary = ((results.get("ears", {}) as Dictionary).get(ear, {}) as Dictionary).get("freqs", {})
	var keys: Array = []
	for f: int in sheet:
		if not bool((sheet[f] as Dictionary).get("no_response", false)):
			keys.append(f)
	keys.sort()
	if keys.is_empty():
		return
	var pts := PackedVector2Array()
	for f: int in keys:
		pts.append(_pt(f, float((sheet[f] as Dictionary).get("stored_db", 0))))
	var k := clampf(_pattern_t / 1.2, 0.0, 1.0)
	var span := maxf(1.0, pts.size() - 1)
	for i in pts.size() - 1:
		if float(i) / span > k:
			break
		var n := maxi(1, int(pts[i].distance_to(pts[i + 1]) / (12.0 * s)))
		for j in n:
			if j % 2 == 0:
				_fx.draw_line(pts[i].lerp(pts[i + 1], float(j) / n), pts[i].lerp(pts[i + 1], float(j + 1) / n), Color(col, 0.55), 3.0 * s, true)
	for i in pts.size():
		if float(i) / span <= k + 0.001:
			_fx.draw_arc(pts[i], 7.0 * s, 0.0, TAU, 16, Color(col, 0.65), 2.5 * s, true)
	if k < 1.0:
		return
	var mid := pts[pts.size() / 2]
	_draw_ghost(mid + Vector2(34.0, -46.0 + sin(_t * 3.0) * 4.0) * s, s, minf(1.0, (_pattern_t - 1.2) / 0.3))
	_draw_sticker(pts[0] + Vector2(-4, -34) * s, "SHADOW", Palette.PAPER, _pattern_t - 1.2)


## The Cross-Hearing Ghost (as on Day 2's AudiOtron, fx_layer.gd), small, at c; grow 0..1 pops it in.
func _draw_ghost(c: Vector2, s: float, grow: float) -> void:
	if grow <= 0.0:
		return
	_fx.draw_set_transform(c, sin(_t * 2.0) * 0.08, Vector2.ONE * s * (0.6 + 0.4 * grow))
	var shape := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		shape.append(Vector2(cos(a), sin(a)) * 22.0 + Vector2(0, -6))
	for i in 7:
		var x := 22.0 - 44.0 * i / 6.0
		shape.append(Vector2(x, 20.0 + (7.0 if i % 2 == 0 else 0.0) + 2.0 * sin(_t * 10.0 + i * 1.6)))
	_fx.draw_colored_polygon(shape, Color(1, 1, 1, 0.92))
	var outline := shape.duplicate()
	outline.append(shape[0])
	_fx.draw_polyline(outline, Palette.INK, 3.0, true)
	_fx.draw_circle(Vector2(-7, -8), 4.0, Palette.INK)
	_fx.draw_circle(Vector2(7, -8), 4.0, Palette.INK)
	_fx.draw_arc(Vector2(0, 4), 4.5, 0.0, TAU, 14, Palette.INK, 3.0, true)
	_fx.draw_circle(Vector2(-14, 0), 3.0, Color(Palette.CORAL, 0.45))
	_fx.draw_circle(Vector2(14, 0), 3.0, Color(Palette.CORAL, 0.45))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A giant cookie takes a bite out of the middle pitches; crumbs fall into the dip.
func _draw_cookie() -> void:
	var s := _sc()
	_draw_previous([] as Array[int])
	var air := _air("right")
	var air_l := _air("left")
	var dip := maxf(float(air.get(1500, air.get(2000, 50))), float(air_l.get(1500, air_l.get(2000, 50))))
	var center := Vector2((_pt(1000, 0).x + _pt(2000, 0).x) * 0.5, _pt(1000, maxf(-5.0, dip - 52.0)).y)
	var r := 46.0 * s
	var land := clampf(_pattern_t / 0.5, 0.0, 1.0)
	var c := center + Vector2(0, (1.0 - land) * -120.0 * s)
	_fx.draw_circle(c + Vector2(0, 4) * s, r, Color(Palette.INK, 0.2))
	_fx.draw_circle(c, r + 3.0, Palette.INK)
	_fx.draw_circle(c, r, COOKIE)
	for p: Vector2 in [Vector2(-0.4, -0.3), Vector2(0.3, -0.45), Vector2(0.05, 0.05), Vector2(-0.3, 0.35), Vector2(0.45, 0.2)]:
		_fx.draw_circle(c + p * r, r * 0.11, Color("#5a3d2b"))
	if _pattern_t > 0.55:
		# the bite, out of the bottom (toward the dip)
		for p: Vector2 in [Vector2(-0.32, 0.92), Vector2(0.0, 1.02), Vector2(0.32, 0.92)]:
			_fx.draw_circle(c + p * r, r * 0.26, Color(Palette.CREAM.lerp(Palette.PAPER, 0.5)))
		var fall := _pattern_t - 0.55
		for i in 7:
			var cx := (float(i) - 3.0) * 7.0 * s + sin(i * 2.3) * 4.0 * s
			var cy := r + fmod(fall * 70.0 + i * 13.0, 90.0) * s
			_fx.draw_circle(c + Vector2(cx, cy), (2.5 + (i % 3)) * s, COOKIE.darkened(0.15))
		if _pattern_t < 2.0:
			var f_font := UiKit.font(700)
			_fx.draw_string_outline(f_font, c + Vector2(r + 8.0, -r * 0.4), "CHOMP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * s + 0.5), 8, Palette.INK)
			_fx.draw_string(f_font, c + Vector2(r + 8.0, -r * 0.4), "CHOMP!", HORIZONTAL_ALIGNMENT_LEFT, -1, int(26 * s + 0.5), Palette.SUNNY)


## The air-bone gap on the focus ear: the band between the bone line and the air line (500-4k)
## shades in, red dots sit on the posts where the gap is 15 or more, and what made the gap shows up
## in it: a lumpy wax cork slams in between 1k and 2k ("plug": "wax"), water rises with bubbles
## and a rubber duck ("plug": "fluid"), or (Day 13) the tiny stirrup bone drops in and a padlock snaps
## onto it ("plug": "stiff"). The sticker gives the measured average gap, rounded to 5.
func _draw_gap() -> void:
	var s := _sc()
	var rv: Dictionary = case_data.get("reveal", {})
	var ear := _focus_ear()
	var air := _air(ear)
	var bone := _bone(ear)
	var air_line := _gap_line(air)
	if air_line.is_empty():
		return
	var bone_line := _gap_line(bone)
	var fluid := String(rv.get("plug", "wax")) == "fluid"
	var stiff := String(rv.get("plug", "wax")) == "stiff"
	# the band's sample positions: where both lines were measured
	var xs := PackedFloat32Array()
	if air_line.size() >= 2 and bone_line.size() >= 2:
		var x0 := maxf(air_line[0].x, bone_line[0].x)
		var x1 := minf(air_line[air_line.size() - 1].x, bone_line[bone_line.size() - 1].x)
		if x1 - x0 > 10.0:
			for i in GAP_STEPS + 1:
				xs.append(lerpf(x0, x1, float(i) / GAP_STEPS))
	var k := clampf(_pattern_t / 0.8, 0.0, 1.0)
	if xs.size() >= 2 and k > 0.0:
		# the shade grows down from the bone line to the air line
		var tops := PackedVector2Array()
		var bots := PackedVector2Array()
		for x: float in xs:
			var yb := _line_y(bone_line, x)
			var ya := _line_y(air_line, x)
			tops.append(Vector2(x, minf(yb, ya)))
			bots.append(Vector2(x, lerpf(minf(yb, ya), maxf(yb, ya), k)))
		_draw_strip(tops, bots, Color(Palette.SUNNY, 0.3))
	# a little past halfway, so the cork clears the Audiogram's dB tag right of the 1k post
	var x_plug := lerpf(_pt(1000, 0).x, _pt(2000, 0).x, 0.6)
	var y_air := _line_y(air_line, x_plug)
	var y_bone := _line_y(bone_line, x_plug) if not bone_line.is_empty() else y_air - 60.0 * s
	if fluid:
		_draw_water(xs, air_line, bone_line, x_plug)
	elif stiff:
		_draw_stirrup(Vector2(x_plug, (y_air + y_bone) * 0.5), y_air - y_bone)
	else:
		_draw_cork(Vector2(x_plug, (y_air + y_bone) * 0.5), y_air - y_bone)
	# the red flag, visible: a dot on each post at 500, 1k and 2k with a gap of 15 or more
	var gaps := CaseRules.air_bone_gaps(air, bone)
	var shown := 0
	for fq: int in [500, 1000, 2000]:
		if int(gaps.get(fq, 0)) < 15:
			continue
		var appear := clampf((_pattern_t - 0.7 - 0.15 * shown) / 0.2, 0.0, 1.0)
		shown += 1
		if appear <= 0.0:
			continue
		var r := 6.0 * s * appear * (1.0 + 0.4 * sin(appear * PI) + 0.08 * sin(_t * 5.0))
		var dp := _pt(fq, float(bone[fq])) + Vector2(0, 18) * s
		_fx.draw_circle(dp, r + 2.0 * s, Palette.INK)
		_fx.draw_circle(dp, r, Palette.RIGHT_RED)
		_fx.draw_circle(dp + Vector2(-0.3, -0.3) * r, r * 0.3, Color(1, 1, 1, 0.6))
	# the sticker, under the air line (no number when the ear has no bone to measure a gap from)
	var avg := _avg_gap(gaps)
	var word := "BLUB!" if fluid else ("STUCK!" if stiff else "PLUGGED!")
	var txt := word if avg < 0 else "%s ~%d dB" % [word, avg]
	var since := _pattern_t - (1.0 if fluid else (0.85 if stiff else 0.5))
	if since > 0.0:
		_draw_sticker(Vector2(x_plug, y_air + 46.0 * s), txt, Palette.SKY if fluid else (STIFF_TAG if stiff else Palette.CORAL), since)


## One ear's thresholds as chart points, left to right, at 500-4k.
func _gap_line(th: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for fq: int in ClinicRules.AC_FREQS:
		if fq >= 500 and fq <= 4000 and th.has(fq):
			out.append(_pt(fq, float(th[fq])))
	return out


## The height of a line (points left to right, at least one) at x; flat past either end.
func _line_y(line: PackedVector2Array, x: float) -> float:
	if x <= line[0].x:
		return line[0].y
	for i in range(1, line.size()):
		if x <= line[i].x:
			return lerpf(line[i - 1].y, line[i].y, (x - line[i - 1].x) / maxf(0.001, line[i].x - line[i - 1].x))
	return line[line.size() - 1].y


## A filled strip between two lines sampled at the same x positions (top above bottom), kept at
## least a pixel thick so the polygon never folds.
func _draw_strip(top_pts: PackedVector2Array, bot_pts: PackedVector2Array, col: Color) -> void:
	if top_pts.size() < 2 or top_pts.size() != bot_pts.size():
		return
	var poly := top_pts.duplicate()
	for i in range(bot_pts.size() - 1, -1, -1):
		poly.append(Vector2(bot_pts[i].x, maxf(bot_pts[i].y, top_pts[i].y + 1.0)))
	_fx.draw_colored_polygon(poly, col)


## The average of an ear's measured air-bone gaps (CaseRules.air_bone_gaps), rounded to 5;
## -1 when there are none (no bone measured).
func _avg_gap(gaps: Dictionary) -> int:
	if gaps.is_empty():
		return -1
	var total := 0
	for fq: int in gaps:
		total += int(gaps[fq])
	return maxi(0, roundi(float(total) / gaps.size() / 5.0) * 5)


## A lumpy wax cork with a tiny wick drops into the gap at `rest` and squashes on landing (THUNK).
## gap_px: the gap's height there, so the cork wedges in.
func _draw_cork(rest: Vector2, gap_px: float) -> void:
	var s := _sc()
	var ry := clampf((gap_px / s - 10.0) * 0.5, 12.0, 22.0)
	var rx := ry * 1.25
	var k := clampf(_pattern_t / 0.45, 0.0, 1.0)
	var since := maxf(0.0, _pattern_t - 0.45)
	var at := rest + Vector2(0, -(1.0 - k) * (1.0 - k) * 190.0 * s)
	# stretched as it falls, then a squash that wobbles out
	var sq := cos(since * 24.0) * exp(-since * 5.0) * 0.3 if k >= 1.0 else -0.12
	if k >= 1.0 and since < 0.45:
		for side: float in [-1.0, 1.0]:
			_fx.draw_circle(rest + Vector2(side * (rx + 6.0 + since * 50.0), ry * 0.6) * s, (5.0 - since * 9.0) * s, Color(Palette.INK_SOFT, 0.5 * (1.0 - since / 0.45)))
	_fx.draw_set_transform(at, 0.0, Vector2(1.0 + sq, 1.0 - sq) * s)
	var lump := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var bumpy := 1.0 + 0.08 * sin(i * 2.7) + 0.05 * cos(i * 5.3)
		# a little narrower at the bottom, like a plug pushed into a canal
		lump.append(Vector2(cos(a) * rx * bumpy * (1.0 - 0.15 * sin(a)), sin(a) * ry * bumpy))
	var shadow := PackedVector2Array()
	for q: Vector2 in lump:
		shadow.append(q + Vector2(0, 4))
	_fx.draw_colored_polygon(shadow, Color(Palette.INK, 0.22))
	_fx.draw_colored_polygon(lump, WAX)
	var outline := lump.duplicate()
	outline.append(lump[0])
	_fx.draw_polyline(outline, Palette.INK, 3.0, true)
	for p: Vector2 in [Vector2(-0.45, 0.25), Vector2(0.3, 0.4), Vector2(0.1, -0.15)]:
		_fx.draw_circle(Vector2(p.x * rx, p.y * ry), ry * 0.16, Color(WAX_DARK, 0.55))
	_fx.draw_arc(Vector2(-rx * 0.3, -ry * 0.35), ry * 0.35, PI + 0.3, TAU - 0.6, 8, Color(1, 1, 1, 0.5), 3.0, true)
	# the tiny wick
	_fx.draw_polyline(PackedVector2Array([Vector2(0, -ry * 0.9), Vector2(-2, -ry - 5.0), Vector2(2, -ry - 9.0), Vector2(0, -ry - 13.0)]), Palette.INK, 2.5, true)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## (Day 13) What sticks in an otosclerosis-like gap: the stirrup, the smallest bone in the body,
## stiffened in place. It drops in like the cork, then a padlock snaps onto its footplate.
func _draw_stirrup(rest: Vector2, gap_px: float) -> void:
	var s := _sc()
	var u := clampf((gap_px / s - 10.0) * 0.5, 12.0, 22.0)
	var k := clampf(_pattern_t / 0.45, 0.0, 1.0)
	var at := rest + Vector2(0, -(1.0 - k) * (1.0 - k) * 190.0 * s)
	var lock_t := _pattern_t - 0.75
	var shake := sin(lock_t * 40.0) * exp(-lock_t * 8.0) * 0.12 if lock_t > 0.0 else 0.0
	_fx.draw_set_transform(at, shake, Vector2.ONE * s)
	var foot_y := u * 0.9
	# the two legs: an arch from the footplate up to the head and down again
	var arch := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		arch.append(Vector2(cos(a) * u * 0.75, foot_y + sin(a) * u * 1.6))
	_fx.draw_polyline(arch, Palette.INK, 9.0, true)
	_fx.draw_polyline(arch, BONE, 5.0, true)
	# the head on top, where the next bone meets it, and the footplate in the oval window
	UiDraw.rounded_rect(_fx, Rect2(Vector2(-u * 0.3, foot_y - u * 2.1), Vector2(u * 0.6, u * 0.6)), BONE, 5, 2, Palette.INK)
	UiDraw.rounded_rect(_fx, Rect2(Vector2(-u * 1.0, foot_y - u * 0.1), Vector2(u * 2.0, u * 0.4)), BONE, 5, 2, Palette.INK)
	if lock_t > 0.0:
		var pop := 1.0 + 0.5 * maxf(0.0, 1.0 - lock_t / 0.2)
		_fx.draw_set_transform(at + Vector2(u * 0.75, foot_y + u * 0.3) * s, shake, Vector2.ONE * s * pop)
		_fx.draw_arc(Vector2(0, -u * 0.3), u * 0.26, PI, TAU, 10, Palette.INK_SOFT, 4.0, true)
		UiDraw.rounded_rect(_fx, Rect2(Vector2(-u * 0.4, -u * 0.32), Vector2(u * 0.8, u * 0.64)), Palette.PLUM, 4, 2, Palette.INK)
		_fx.draw_circle(Vector2(0, -u * 0.06), u * 0.1, Palette.INK)
		_fx.draw_line(Vector2(0, -u * 0.04), Vector2(0, u * 0.16), Palette.INK, 3.0, true)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Water from the air line up to just under the bone symbols, with a wobbly surface, bubbles that rise
## and pop, and a rubber duck riding the surface up. xs: the band's sample positions (may be empty).
func _draw_water(xs: PackedFloat32Array, air_line: PackedVector2Array, bone_line: PackedVector2Array, x_duck: float) -> void:
	var s := _sc()
	var rise := clampf((_pattern_t - 0.15) / 1.1, 0.0, 1.0)
	if rise <= 0.0:
		return
	var surf := PackedVector2Array()
	var bed := PackedVector2Array()
	if xs.size() >= 2:
		for x: float in xs:
			var ya := _line_y(air_line, x)
			# just under the bone symbols: half a bracket (8.5) + its stroke (2) + the wobble (4.5) + the surface line (1.5)
			var yb := minf(_line_y(bone_line, x) + 17.0 * s, ya)
			var wob := (sin(x * 0.07 / s + _t * 3.0) * 3.0 + sin(x * 0.15 / s - _t * 2.2) * 1.5) * s * rise
			surf.append(Vector2(x, minf(lerpf(ya, yb, rise) + wob, ya - 1.0)))
			bed.append(Vector2(x, ya))
		_draw_strip(surf, bed, Color(WAVE, 0.28))
		_fx.draw_polyline(surf, Color(WAVE, 0.9), 3.0 * s, true)
		if rise > 0.35:
			for j in 8:
				var bx := lerpf(xs[0], xs[xs.size() - 1], (j + 0.5) / 8.0) + sin(_t * 1.7 + j * 1.9) * 4.0 * s
				var y_bed := _line_y(bed, bx) - 6.0 * s
				var y_top := _line_y(surf, bx) + 4.0 * s
				if y_bed - y_top < 10.0 * s:
					continue
				var cyc := fmod(_pattern_t * 0.6 + j * 0.37, 1.0)
				var r := (2.5 + j % 3) * s * (0.8 + 0.5 * cyc)
				if cyc < 0.88:
					var bp := Vector2(bx, lerpf(y_bed, y_top, cyc / 0.88))
					_fx.draw_arc(bp, r, 0, TAU, 12, Color(1, 1, 1, 0.9), 1.5 * s, true)
					_fx.draw_circle(bp + Vector2(-0.35, -0.35) * r, r * 0.3, Color(1, 1, 1, 0.8))
				else:
					# pop at the surface
					var pk := (cyc - 0.88) / 0.12
					_fx.draw_arc(Vector2(bx, y_top), r * (1.0 + pk * 1.5), 0, TAU, 12, Color(1, 1, 1, 0.8 * (1.0 - pk)), 1.5 * s, true)
	var y_duck := _line_y(surf, x_duck) if surf.size() >= 2 else _line_y(air_line, x_duck)
	_draw_duck(Vector2(x_duck, y_duck), minf(1.0, rise * 4.0))


## A rubber duck bobbing with its water line at `at`; grow 0..1 pops it in.
func _draw_duck(at: Vector2, grow: float) -> void:
	var s := _sc()
	_fx.draw_set_transform(at + Vector2(0, sin(_t * 2.6) * 1.5 * s), sin(_t * 1.9) * 0.12, Vector2.ONE * s * grow)
	var tail := PackedVector2Array([Vector2(-14, -13), Vector2(-26, -22), Vector2(-18, -6)])
	_fx.draw_colored_polygon(tail, Palette.SUNNY)
	var tail_line := tail.duplicate()
	tail_line.append(tail[0])
	_fx.draw_polyline(tail_line, Palette.INK, 2.5, true)
	var body := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		body.append(Vector2(cos(a) * 19.0, sin(a) * 11.0 - 7.0))
	_fx.draw_colored_polygon(body, Palette.SUNNY)
	var body_line := body.duplicate()
	body_line.append(body[0])
	_fx.draw_polyline(body_line, Palette.INK, 2.5, true)
	_fx.draw_arc(Vector2(-3, -10), 8.0, 0.25, PI - 0.25, 8, Palette.SUNNY.darkened(0.3), 2.5, true)
	# the part under the water line, tinted
	var under := PackedVector2Array()
	var a0 := asin(7.0 / 11.0)
	for i in 9:
		var a := lerpf(a0, PI - a0, i / 8.0)
		under.append(Vector2(cos(a) * 19.0, sin(a) * 11.0 - 7.0))
	_fx.draw_colored_polygon(under, Color(WAVE, 0.5))
	_fx.draw_circle(Vector2(10, -24), 11.5, Palette.INK)
	_fx.draw_circle(Vector2(10, -24), 9.0, Palette.SUNNY)
	var beak := PackedVector2Array([Vector2(17, -27), Vector2(28, -23), Vector2(17, -19)])
	_fx.draw_colored_polygon(beak, Palette.SELECT_ORANGE)
	var beak_line := beak.duplicate()
	beak_line.append(beak[0])
	_fx.draw_polyline(beak_line, Palette.INK, 2.0, true)
	_fx.draw_circle(Vector2(12, -27), 2.2, Palette.INK)
	_fx.draw_circle(Vector2(12.8, -27.8), 0.8, Color.WHITE)
	for side: float in [-1.0, 1.0]:
		_fx.draw_arc(Vector2(25.0 * side, 2.0), 4.0 + sin(_t * 4.0), PI + 0.5, TAU - 0.5, 6, Color(1, 1, 1, 0.8), 2.0, true)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A sticker slapped onto the chart at `at`: it pops in (since: seconds since it landed) and sits askew.
func _draw_sticker(at: Vector2, txt: String, fill: Color, since: float) -> void:
	var f_font := UiKit.font(700)
	var fs := 20
	var tw := f_font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pop := 1.0 + 0.6 * maxf(0.0, 1.0 - since / 0.25)
	_fx.draw_set_transform(at, -0.07, Vector2.ONE * _sc() * pop)
	var box := Rect2(Vector2(-tw * 0.5 - 14.0, -21.0), Vector2(tw + 28.0, 34.0))
	UiDraw.rounded_rect(_fx, Rect2(box.position + Vector2(0, 4), box.size), Color(Palette.INK, 0.2), 12)
	UiDraw.rounded_rect(_fx, box, fill, 12, 3, Palette.INK)
	_fx.draw_line(box.position + Vector2(12, 7), box.position + Vector2(34, 7), Color(1, 1, 1, 0.6), 3.0, true)
	_fx.draw_string(f_font, Vector2(-tw * 0.5, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_type() -> void:
	if _type_text == "":
		return
	var cr := _card.get_global_rect()
	var s := _sc()
	var f := UiKit.font(700)
	var fs := int(22.0 * s + 0.5)
	var tw := f.get_string_size(_type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pop := 1.0 + 0.4 * maxf(0.0, 1.0 - _type_t / 0.25)
	# bottom-right of the plot: the profound, high-pitch corner where nothing else is drawn
	var at := _to_fx(cr.end - Vector2(tw + 84.0 * s, 40.0 * s))
	_fx.draw_set_transform(at, -0.04, Vector2.ONE * pop)
	var box := Rect2(Vector2(-4.0 * s, -26.0 * s), Vector2(tw + 24.0 * s, 36.0 * s))
	UiDraw.rounded_rect(_fx, box, Palette.MINT, 12, 3, Palette.INK)
	_fx.draw_string(f, Vector2(8.0 * s, 0), _type_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.INK)
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_card(b: Button, i: int) -> void:
	var c: Dictionary = clues[i]
	var state := String(_card_state.get(i, ""))
	var flag := String(c.get("kind", "clue")) == "flag"
	var hover := b.is_hovered() and _mode == "clue" and state != "wrong"
	var r := Rect2(Vector2.ZERO, b.size)
	var lift := -3.0 if hover else 0.0
	r.position.y += lift
	var fill: Color = Color("#fff4f2") if flag else CARD_COLORS[i % CARD_COLORS.size()]
	if state == "wrong":
		fill = fill.lerp(Color("#d8d2c8"), 0.6)
	if state == "right":
		UiDraw.rounded_rect(b, r.grow(6.0), Palette.MINT, 14)
	elif hover:
		UiDraw.rounded_rect(b, r.grow(5.0), Palette.SUNNY, 14)
	UiDraw.rounded_rect(b, Rect2(r.position + Vector2(0, 4), r.size), Color(Palette.INK, 0.18), 10)
	UiDraw.rounded_rect(b, r, fill, 10, 3 if flag else 2, Palette.RIGHT_RED if flag else Palette.INK)
	var f := UiKit.font(700)
	var src := String(c.get("src", "note"))
	var head := String(SRC_TITLES.get(src, "CASE NOTE"))
	b.draw_string(f, r.position + Vector2(30, 17), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Palette.RIGHT_RED if flag else Palette.INK_SOFT)
	# the number key
	var kc := r.position + Vector2(15, 15)
	b.draw_circle(kc, 10.0, Palette.INK)
	var n := str(i + 1)
	b.draw_string(f, kc + Vector2(-f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x * 0.5, 5), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.PAPER)
	if state == "right":
		var ex := "EXHIBIT A!"
		var w := f.get_string_size(ex, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		UiDraw.rounded_rect(b, Rect2(r.end - Vector2(w + 18, r.size.y + 8), Vector2(w + 12, 20)), Palette.MINT, 8, 2, Palette.INK)
		b.draw_string(f, r.end - Vector2(w + 12, r.size.y - 7), ex, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK)
	elif state == "wrong":
		UiDraw.cross(b, r.end - Vector2(16, r.size.y - 14), 9.0, Color(Palette.RIGHT_RED, 0.7), 3.0)
	# a strip of tape
	var tape := Rect2(Vector2(r.size.x * 0.5 - 22, r.position.y - 6), Vector2(44, 12))
	b.draw_rect(tape, Color(1, 1, 1, 0.55))


func _draw_stamp_button(b: Button, i: int) -> void:
	var d: StringName = CaseRules.DECISIONS[i]
	var col: Color = STAMP_COLORS[d]
	var dead := _stamp_dead.has(i)
	if dead:
		col = Color("#b9b3a8")
	var lift := _stamp_lift(i)
	var hover := lift != 0.0
	var base := Rect2(Vector2(10, 34 + lift), Vector2(b.size.x - 20, b.size.y - 38))
	# handle: a wooden knob on a neck
	var knob := Vector2(b.size.x * 0.5, 10 + lift)
	b.draw_rect(Rect2(knob + Vector2(-9, 4), Vector2(18, 22)), Palette.INK)
	b.draw_rect(Rect2(knob + Vector2(-6, 4), Vector2(12, 22)), Color("#c8874b").darkened(0.15 if not dead else 0.0))
	b.draw_circle(knob, 16.0, Palette.INK)
	b.draw_circle(knob, 13.0, Color("#c8874b") if not dead else Color("#d8d2c8"))
	b.draw_circle(knob + Vector2(-4, -4), 4.0, Color(1, 1, 1, 0.4))
	if hover:
		UiDraw.rounded_rect(b, base.grow(5.0), Palette.SUNNY, 18)
	UiDraw.rounded_rect(b, Rect2(base.position + Vector2(0, 5), base.size), Color(Palette.INK, 0.2), 14)
	UiDraw.rounded_rect(b, base, Palette.PAPER, 14, 4, col)
	UiDraw.rounded_rect(b, base.grow(-6.0), Color(0, 0, 0, 0), 10, 2, Color(col, 0.6))
	var f := UiKit.font(700)
	var n := str(i + 1)
	var kc := base.position + Vector2(20, 18)
	b.draw_circle(kc, 11.0, Palette.INK)
	b.draw_string(f, kc + Vector2(-f.get_string_size(n, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, 5), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Palette.PAPER)


## The stamp lands on the file (right) or bounces off with a question mark (wrong).
func _draw_slam() -> void:
	var col: Color = STAMP_COLORS.get(_slam, Palette.RIGHT_RED)
	var cr := _card.get_global_rect()
	var c := _to_fx(cr.get_center() + Vector2(60, 10) * _sc())
	var f := UiKit.font(700)
	var txt := CaseRules.DECISION_STAMPS.get(_slam, "") as String
	var land := clampf(_slam_t / 0.18, 0.0, 1.0)
	var sc := lerpf(2.6, 1.0, land * land) * maxf(_sc(), 0.6)
	var alpha := clampf(_slam_t / 0.12, 0.0, 1.0)
	if not _slam_right:
		var up := clampf((_slam_t - 0.2) / 0.4, 0.0, 1.0)
		sc *= 1.0 + up * 0.3
		alpha *= 1.0 - up
		c += Vector2(0, -80.0 * up)
	_fx.draw_set_transform(c, -0.16, Vector2.ONE * sc)
	var fs := 56 if txt.length() < 8 else 44
	var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(Vector2(-w * 0.5 - 22, -48), Vector2(w + 44, 72))
	var ink := Color(col, 0.9 * alpha)
	_fx.draw_rect(box, Color(Palette.PAPER, 0.75 * alpha))
	_fx.draw_rect(box, ink, false, 7.0)
	_fx.draw_rect(box.grow(-9.0), ink, false, 2.5)
	_fx.draw_string(f, Vector2(-w * 0.5, 4), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
	if not _slam_right and _slam_t > 0.2:
		_fx.draw_string_outline(f, Vector2(w * 0.5 + 10, -30), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, 10, Color(Palette.INK, alpha))
		_fx.draw_string(f, Vector2(w * 0.5 + 10, -30), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color(Palette.SUNNY, alpha))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

