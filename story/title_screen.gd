extends Control
## TitleScreen: the safety notice, then the title menu over a live 3D clinic backdrop.
## Phases: &"disclaimer" (beat disclaimer_ok) then &"title" (beat title_start).
## Play -> the next chapter (v3: Game.start_chapter(Game.next_chapter_id()): Day 1 on a fresh
## save, then the suggested day). Days -> the day picker (phase / beat &"chapter_select"): a
## scrolling grid with one card per chapter, any number of them. Every day is open (polish: no
## locks, any order); the suggested day wears an "UP NEXT" badge. Options opens the pause menu.
## Freestyle -> the walk-in clinic; Arcade -> the arcade hall (docs/ARCADE.md); Training -> Hoot's Training room
## (docs/training/MASKING_TRAINER.md).
## Quit quits. Keyboard: Up/Down + Enter/Space (Days: arrows move in the grid, Esc = Back).
## Mouse: click, wheel scrolls the grid. The notice shows once per session; the footer
## "This is a game, not a hearing test." is always on screen.
## (career-fair demo, docs/DEMO.md) In demo mode (Game.is_demo()) the menu is one Play button for
## the short demo level, the notice greets every visitor, and each title starts a fresh visitor.
## Nobody at the demo's title for ATTRACT_S seconds (in the menu or the notice) starts the booth's
## attract loop (story/demo_attract.gd); a key, click or mouse movement ends it and shows the notice.

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const LEVEL_SCENE := "res://story/level_gus.tscn"
const CLINIC_SCENE := "res://world/clinic.tscn"
const Movies := preload("res://story/explainers/movies.gd")
const FREESTYLE_SCENE := "res://story/freestyle/waiting_room.tscn"
## (arcade, docs/ARCADE.md) The arcade hall: a cabinet per game (Chart Chute, Ears, Please!).
const ARCADE_SCENE := "res://story/arcade/arcade_hall.tscn"
const TRAINING_SCENE := "res://story/training/training_room.tscn"
## (demo) The career-fair demo's level, and the line under its Play button.
const DEMO_SCENE := "res://story/level_demo.tscn"
const DEMO_TAGLINE := "Find out what Gus can't hear, then help him hear it. About 7 minutes."
const DemoAttract := preload("res://story/demo_attract.gd")
## (demo) Seconds with nobody at the title before the attract loop; --attract-after=N sets another.
const ATTRACT_S := 30.0

static var _notice_seen_this_session := false
## A title left alone this long (a booth / kiosk display) shows the safety notice again.
const IDLE_NOTICE_S := 90.0

var _clinic: Node
var _logo: Control
var _menu_card: PanelContainer
var _buttons: Array[Button] = []
var _hl := 0
var _notice_layer: Control
var _notice: PanelContainer
var _state := &"notice"
var _t := 0.0
var _font: Font
var _starting := false
var _idle := 0.0
var _reset_armed := false
## (demo) The booth's attract loop (never under autoplay) and the seconds with nobody at the title.
var _attract: Control
var _attract_idle := 0.0
## (v4) "Hoot's Movies": a small mouse shortcut to the cartoon explainers (keyboard: Options).
var _movies_btn: Button
# v3: the day picker (polish: a scrolling grid for any number of days)
var _days_card: PanelContainer
var _menu_buttons: Array[Button] = []
## The Days card's buttons in keyboard order: every day card (day order), then Back.
var _day_buttons: Array[Button] = []
var _day_cards: Array[Button] = []
var _days_note: Label
var _days_hint_plain: Control
var _days_hint_scroll: Control
var _days_scroll: ScrollContainer
var _days_grid: GridContainer
var _days_cols := 1
var _scroll_tween: Tween
## Dev scenes and tests only: a chapter list to show instead of Game.chapters() (set it before
## the title enters the tree). Never set in the game.
var chapters_override: Array = []
## Card size in the grid (the cards scale up when there are only a few days).
const CARD_SIZE := Vector2(256, 206)
const CARD_GAP := 18.0
const GRID_MARGIN := 12.0
const MAX_COLUMNS := 6
## The always-visible safety footer band at the bottom, and the Days card's chrome around the grid
## (panel margins, the header row, the footer row, separations).
const FOOTER_H := 46.0
const DAYS_CHROME_H := 24.0 + 40.0 + 48.0 + 2.0 * 10.0
## Who is on each day's card (a Portraits speaker) and the card's tint. A chapter without an entry
## here uses its own "face" / "tint" keys (Game.CHAPTERS), else a cream card with a star.
const DAY_FACES: Dictionary = {"gus": "Gus", "bonnie": "Bonnie"}
const DAY_TINTS: Dictionary = {"gus": Color("#bfeee6"), "bonnie": Color("#ffe3c2")}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_to_group("title_screen")
	_font = UiKit.font(700)
	if Game.is_demo():
		Game.reset_demo_visitor()   # (demo) every title is a new visitor
	if ResourceLoader.exists(CLINIC_SCENE):
		_clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
		add_child(_clinic)
		if _clinic.has_method("set_title_mode"):
			_clinic.call("set_title_mode", true)
	_build()
	if Game.is_demo() and not Game.is_autoplay():
		_attract = DemoAttract.new()
		_attract.set("tagline", DEMO_TAGLINE)
		add_child(_attract)
		_attract.connect("dismissed", _on_attract_dismissed)
	Sfx.music_start()
	if _notice_seen_this_session and not Game.is_demo():
		_notice_layer.visible = false
		_show_title.call_deferred()
	else:
		_show_disclaimer.call_deferred()


func _process(delta: float) -> void:
	_t += delta
	if _state == &"menu" and not get_tree().paused and not _attract_running():
		_idle += delta
		if _idle > IDLE_NOTICE_S:
			_idle = 0.0
			_notice_layer.modulate.a = 1.0
			_show_disclaimer()
	if _attract != null and not _attract_running() and (_state == &"menu" or _state == &"notice") and not get_tree().paused:
		_attract_idle += delta
		if _attract_idle > attract_after():
			_attract.call("start")
			_menu_card.visible = false
			_notice_layer.visible = false
	_logo.queue_redraw()
	queue_redraw()
	if _movies_btn != null:
		_movies_btn.visible = _state == &"menu"
	if _state == &"days":
		for b: Button in _day_cards:
			b.queue_redraw()


func _draw() -> void:
	# soft cream wash on the left so the logo and menu read over the 3D clinic
	var w := size.x
	var h := size.y
	var cols := PackedColorArray([Color(Palette.CREAM, 0.94), Color(Palette.CREAM, 0.0), Color(Palette.CREAM, 0.0), Color(Palette.CREAM, 0.94)])
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w * 0.62, 0), Vector2(w * 0.62, h), Vector2(0, h)]), cols)
	draw_rect(Rect2(0, h - 46, w, 46), Color(Palette.INK, 0.78))


func _show_disclaimer() -> void:
	_state = &"notice"
	Events.phase_changed.emit(&"disclaimer", {})
	_menu_card.visible = false
	_notice_layer.visible = true
	Juice.bounce_in(_notice, 0.5)
	Events.awaiting_input.emit(&"disclaimer_ok", {}, _on_notice_ok)


func _on_notice_ok() -> void:
	if _state != &"notice":
		return
	_state = &"busy"
	Sfx.play(&"ding")
	_notice_seen_this_session = true
	Game.progress["seen_disclaimer"] = true
	Game.save_game()
	Events.input_resolved.emit(&"disclaimer_ok")
	var t := create_tween()
	t.tween_property(_notice_layer, "modulate:a", 0.0, 0.2)
	await t.finished
	_notice_layer.visible = false
	_show_title()


func _show_title() -> void:
	_state = &"menu"
	Events.phase_changed.emit(&"title", {})
	_menu_card.visible = true
	Juice.bounce_in(_menu_card, 0.5)
	_set_hl(0, false)
	Events.awaiting_input.emit(&"title_start", {}, _on_demo_start if Game.is_demo() else _on_start)


func _on_start() -> void:
	_start_chapter(Game.next_chapter_id(), &"title_start")


## (demo) Play: the career-fair demo level.
func _on_demo_start() -> void:
	if _starting:
		return
	_starting = true
	_state = &"busy"
	Sfx.play(&"fanfare")
	if not _buttons.is_empty():
		Juice.pop(_buttons[0], 1.15, 0.25)
	Events.input_resolved.emit(&"title_start")
	Events.goto_scene.emit(DEMO_SCENE)


## (demo) Seconds with nobody at the title before the attract loop starts.
static func attract_after() -> float:
	return float(Game.cli.get("attract-after", ATTRACT_S))


func _attract_running() -> bool:
	return _attract != null and bool(_attract.call("is_running"))


## (demo) A visitor walked up: the attract loop is gone, and the safety notice greets them.
func _on_attract_dismissed() -> void:
	_idle = 0.0
	_attract_idle = 0.0
	_notice_layer.modulate.a = 1.0
	_show_disclaimer()


## (v3) Start a chapter (falls back to Day 1's scene if it is unknown or missing).
func _start_chapter(id: String, beat: StringName) -> void:
	if _starting:
		return
	_starting = true
	_state = &"busy"
	Sfx.play(&"fanfare")
	if not _buttons.is_empty():
		Juice.pop(_buttons[clampi(_hl, 0, _buttons.size() - 1)], 1.15, 0.25)
	Events.input_resolved.emit(beat)
	if not Game.start_chapter(id):
		Events.goto_scene.emit(LEVEL_SCENE)


# ---------------------------------------------------------------- v3: day picker

func _on_days() -> void:
	if _state != &"menu":
		return
	_state = &"days"
	Events.input_resolved.emit(&"title_start")
	Events.phase_changed.emit(&"chapter_select", {"unlocked": _list_ids(), "suggested": _suggested_id()})
	_menu_card.visible = false
	_refresh_days()
	_layout_days()
	_days_card.visible = true
	Juice.bounce_in(_days_card, 0.4)
	_logo.create_tween().tween_property(_logo, "modulate:a", 0.0, 0.2)
	_buttons = _day_buttons
	# start on the suggested day (Day 1 on a fresh save)
	var start := 0
	var sug := _suggested_id()
	for i in _day_cards.size():
		if String(_day_cards[i].get_meta("chapter", "")) == sug:
			start = i
	_days_scroll.scroll_vertical = 0
	_set_hl(start, false)
	_settle_scroll(start)
	Sfx.play(&"whoosh", 1.2, -8.0)
	Events.awaiting_input.emit(&"chapter_select", {"chapters": _list_ids(), "next": Game.next_chapter_id(), "suggested": sug},
		func() -> void: _start_chapter(Game.next_chapter_id(), &"chapter_select"))


func _days_back() -> void:
	if _state != &"days":
		return
	Events.input_resolved.emit(&"chapter_select")
	_days_card.visible = false
	_logo.create_tween().tween_property(_logo, "modulate:a", 1.0, 0.25)
	_buttons = _menu_buttons
	_show_title()


## Every day is open (polish): a card always starts its chapter.
func _pick_day(id: String, _b: Button = null) -> void:
	if _state != &"days":
		return
	_start_chapter(id, &"chapter_select")


## The chapters the picker shows: Game.chapters(), or the dev / test override.
func _chapter_list() -> Array:
	return chapters_override if not chapters_override.is_empty() else Game.chapters()


func _list_ids() -> Array[String]:
	var out: Array[String] = []
	for ch: Dictionary in _chapter_list():
		out.append(String(ch.get("id", "")))
	return out


## The day with the "UP NEXT" badge (Game.suggested_chapter_id() over the shown list).
func _suggested_id() -> String:
	return Game.suggested_from(_chapter_list(), Game.progress.get("chapters_done", []) as Array)


## A card's portrait speaker: DAY_FACES, else the chapter's own "face" key, else "".
static func card_face(ch: Dictionary) -> String:
	var id := String(ch.get("id", ""))
	if DAY_FACES.has(id):
		return String(DAY_FACES[id])
	return String(ch.get("face", ""))


## A card's tint: DAY_TINTS, else the chapter's "tint" (a Color or a "#rrggbb" string), else cream.
static func card_tint(ch: Dictionary) -> Color:
	var id := String(ch.get("id", ""))
	if DAY_TINTS.has(id):
		return DAY_TINTS[id]
	var t: Variant = ch.get("tint", null)
	if t is Color:
		return t
	if t is String and Color.html_is_valid(String(t)):
		return Color.html(String(t))
	return Palette.CREAM


func _refresh_days() -> void:
	var pats: Dictionary = Game.progress.get("patients", {})
	var sug := _suggested_id()
	for b: Button in _day_cards:
		var ch: Dictionary = b.get_meta("ch", {})
		var id := String(ch.get("id", ""))
		var label := String(ch.get("title", id))
		var rec: Dictionary = pats.get(String(ch.get("patient_id", id)), {})
		var best := String(rec.get("best_grade", ""))
		var done := Game.is_chapter_done(id)
		if done and best != "":
			label += "  [%s]" % best
		b.set_meta("label", label)
		b.set_meta("best", best if done else "")
		b.set_meta("suggested", id == sug)
		b.tooltip_text = "%s: %s" % [String(ch.get("title", "")), String(ch.get("teaches", ""))]
		var status := b.get_node_or_null("Status") as Label
		if status != null:
			var plays := int(rec.get("plays", 0))
			if plays > 0:
				status.text = "Played %d time%s" % [plays, "" if plays == 1 else "s"]
			else:
				status.text = "New!"
		b.queue_redraw()
	if _days_note != null:
		_days_note.text = "Every day is open: play them in any order."


## Size the grid for the screen: as many columns as fit (at most MAX_COLUMNS), as many rows as fit
## above the safety footer; more days than that scroll. Called on open and on every resize.
func _layout_days() -> void:
	if _days_card == null:
		return
	var vp := get_viewport_rect().size
	var k := _card_scale()
	var cs := CARD_SIZE * k
	for b: Button in _day_cards:
		b.custom_minimum_size = cs
		_layout_card(b)
	var g := grid_geometry(vp, _day_cards.size(), k)
	_days_cols = int(g["cols"])
	_days_grid.columns = _days_cols
	var scrolls := bool(g["scrolls"])
	_days_scroll.custom_minimum_size = g["scroll_size"]
	_days_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if scrolls else ScrollContainer.SCROLL_MODE_DISABLED
	if _days_hint_scroll != null and _days_hint_plain != null:
		_days_hint_scroll.visible = scrolls
		_days_hint_plain.visible = not scrolls
	# centred above the footer band
	var sz := _days_card.get_combined_minimum_size()
	_days_card.size = sz
	_days_card.position = Vector2(floor((vp.x - sz.x) * 0.5), floor(maxf(10.0, (vp.y - FOOTER_H - sz.y) * 0.5)))


## The grid's shape for n days on a screen of logical size vp (k = card scale): {cols, rows,
## vis_rows, scrolls, scroll_size}. Pure, so tests can check any screen without resizing one.
static func grid_geometry(vp: Vector2, n: int, k: float = 1.0) -> Dictionary:
	var cs := CARD_SIZE * k
	n = maxi(1, n)
	var avail_w := vp.x - 2.0 * 40.0 - 32.0 - 16.0 - 2.0 * GRID_MARGIN
	var avail_h := vp.y - FOOTER_H - 2.0 * 12.0 - DAYS_CHROME_H - 2.0 * GRID_MARGIN
	var cols := clampi(int(floor((avail_w + CARD_GAP) / (cs.x + CARD_GAP))), 1, mini(n, MAX_COLUMNS))
	var rows := int(ceil(float(n) / cols))
	var vis_rows := clampi(int(floor((avail_h + CARD_GAP) / (cs.y + CARD_GAP))), 1, rows)
	var scrolls := rows > vis_rows
	var grid_w := cols * cs.x + (cols - 1) * CARD_GAP + 2.0 * GRID_MARGIN
	var grid_h := vis_rows * cs.y + (vis_rows - 1) * CARD_GAP + 2.0 * GRID_MARGIN
	return {"cols": cols, "rows": rows, "vis_rows": vis_rows, "scrolls": scrolls,
		"scroll_size": Vector2(grid_w + (16.0 if scrolls else 0.0), grid_h)}


## The grid sorts its cards a frame after it opens: then bring the highlighted card into view.
func _settle_scroll(i: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _state == &"days" and i < _day_cards.size() and _hl == i:
		_scroll_to_card(_day_cards[i], false)


## Few days get big cards; many get the compact grid.
func _card_scale() -> float:
	return 1.25 if _day_cards.size() <= 3 else 1.0


func _on_viewport_resized() -> void:
	if _state == &"days":
		_layout_days()
		if _hl >= 0 and _hl < _day_cards.size():
			_scroll_to_card.call_deferred(_day_cards[_hl], false)


## Keep a highlighted card (and its glow ring) inside the scroll window.
func _scroll_to_card(b: Button, smooth: bool = true) -> void:
	if _days_scroll == null or not _days_scroll.is_visible_in_tree() or not _day_cards.has(b):
		return
	var top := b.position.y           # the grid sits GRID_MARGIN inside the scrolled content
	var bot := b.position.y + b.size.y + 2.0 * GRID_MARGIN
	var cur := float(_days_scroll.scroll_vertical)
	var h := _days_scroll.size.y
	var target := cur
	if top < cur:
		target = top
	elif bot > cur + h:
		target = bot - h
	if is_equal_approx(target, cur):
		return
	if _scroll_tween != null and _scroll_tween.is_valid():
		_scroll_tween.kill()
	if not smooth or bool(Game.settings.get("reduced_motion", false)):
		_days_scroll.scroll_vertical = int(target)
		return
	_scroll_tween = create_tween()
	_scroll_tween.tween_property(_days_scroll, "scroll_vertical", int(target), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Arrow keys on the Days card: Left / Right step through every button (cards, then Back, wrapping);
## Up / Down move a row in the grid, past the last row to Back, from Back to the last card.
func _days_nav(dx: int, dy: int) -> void:
	var n := _day_cards.size()
	var total := _buttons.size()
	if total == 0:
		return
	if dx != 0:
		_set_hl((_hl + dx + total) % total)
		return
	var back := n  # Back comes right after the cards
	var row := int(_hl / _days_cols)
	var last_row := int((n - 1) / _days_cols)
	if dy > 0:
		if _hl >= n:
			_set_hl(0)
		elif _hl + _days_cols < n:
			_set_hl(_hl + _days_cols)
		elif row < last_row:
			_set_hl(n - 1)    # a short last row: its last card
		else:
			_set_hl(back)
	elif dy < 0:
		if _hl >= n:
			_set_hl(n - 1)
		elif _hl - _days_cols >= 0:
			_set_hl(_hl - _days_cols)
		else:
			_set_hl(back)


## (freestyle, docs/FREESTYLE.md) The walk-in clinic: practice outside the story.
func _on_freestyle() -> void:
	if _state != &"menu" or _starting:
		return
	_starting = true
	_state = &"busy"
	Sfx.play(&"click")
	Events.goto_scene.emit(FREESTYLE_SCENE)


## (arcade, docs/ARCADE.md) The arcade hall, where the player picks a cabinet.
func _on_arcade() -> void:
	if _state != &"menu" or _starting:
		return
	_starting = true
	_state = &"busy"
	Sfx.play(&"click")
	Events.goto_scene.emit(ARCADE_SCENE)


## (training, docs/training/MASKING_TRAINER.md) Hoot's Training room: short lessons (Masking School).
func _on_training() -> void:
	if _state != &"menu" or _starting:
		return
	_starting = true
	_state = &"busy"
	Sfx.play(&"click")
	Events.goto_scene.emit(TRAINING_SCENE)


func _on_options() -> void:
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm:
		pm.call("open")


func _on_quit() -> void:
	Events.quit_requested.emit(0)


## (v4) Hoot's Movies: with one movie it plays right away (through the pause menu, so the title
## waits paused and Esc skips it), then the title is back; with several, the pause menu's movie
## list opens on its own (day, title, length per row; Back or Esc returns to the title).
func _on_movies() -> void:
	if _state != &"menu":
		return
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm == null:
		return
	_idle = 0.0
	var ids := Movies.replay_ids()
	if ids.size() == 1:
		pm.call("open")
		await pm.call("play_movie", ids[0])
		if is_inside_tree():
			pm.call("close")
	elif ids.size() > 1:
		pm.call("open_movie_list", true)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event.is_pressed():
		_idle = 0.0
		_attract_idle = 0.0
	# (polish) Esc on the Days card means Back (before the pause menu turns it into Options)
	if _state == &"days" and event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm == null or not bool(pm.call("is_open")):
			_days_back()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _state == &"notice":
		if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
			_on_notice_ok()
			get_viewport().set_input_as_handled()
		return
	if _state == &"days" and event.is_action_pressed(&"ui_cancel"):
		_days_back()
		get_viewport().set_input_as_handled()
		return
	if _state != &"menu" and _state != &"days":
		return
	if _state == &"days" and (event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_left")):
		_days_nav(1 if event.is_action_pressed(&"ui_right") else -1, 0)
	elif _state == &"days" and (event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_up")):
		_days_nav(0, 1 if event.is_action_pressed(&"ui_down") else -1)
	elif event.is_action_pressed(&"ui_down") or event.is_action_pressed(&"ui_right"):
		_set_hl((_hl + 1) % _buttons.size())
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_left"):
		_set_hl((_hl - 1 + _buttons.size()) % _buttons.size())
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		_buttons[_hl].pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()


func _set_hl(i: int, sound: bool = true) -> void:
	_hl = i
	for j in _buttons.size():
		var b := _buttons[j]
		var on := j == i
		if b.has_meta("chapter"):
			# a day card: a glowing ring and a little lift instead of "> text <"
			var was := bool(b.get_meta("hl", false))
			b.set_meta("hl", on)
			if on and not was:
				b.pivot_offset = b.size * 0.5
				Juice.pop(b, 1.04, 0.2)
				_scroll_to_card(b)
			b.queue_redraw()
			continue
		b.theme_type_variation = &"AccentButton" if on else &""
		b.text = ("> " if on else "") + String(b.get_meta("label")) + ("  <" if on else "")
	if sound:
		Sfx.play(&"blip", 1.3, -10.0)


func _build() -> void:
	var root := UiKit.full_rect()
	add_child(root)
	_logo = Control.new()
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.position = Vector2(56, 22)
	_logo.size = Vector2(700, 240)
	_logo.draw.connect(_draw_logo)
	root.add_child(_logo)

	_menu_card = UiKit.panel(Color(Palette.PAPER, 0.97), Palette.INK, 26)
	_menu_card.position = Vector2(92, 284)  # (polish) five rows + stats fit above the footer
	_menu_card.custom_minimum_size = Vector2(380, 0)
	root.add_child(_menu_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_menu_card.add_child(v)
	# (polish) once you have played, Play says which day it starts
	var play_txt := "Play"
	if _has_progress():
		play_txt = "Play: %s" % String(Game.chapter(Game.next_chapter_id()).get("title", "Day 1")).get_slice(":", 0).strip_edges()
	var specs: Array = [[play_txt, _on_start], ["Days", _on_days], ["Training", _on_training], ["Freestyle", _on_freestyle], ["Arcade", _on_arcade]]
	if _has_progress():
		specs.append(["New player", _on_new_player])
	specs.append(["Options", _on_options])
	specs.append(["Quit", _on_quit])
	if Game.is_demo():
		specs = [["Play", _on_demo_start]]   # (demo) nothing else: no days, no quitting the booth
	# (freestyle) Options and Quit share the last row, so a returning player's six buttons still
	# clear the safety footer (Up/Down still walk them in order)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	# (arcade) Freestyle and Arcade share a row the same way
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	# (training) Days and Training share a row too
	var learn := HBoxContainer.new()
	learn.add_theme_constant_override("separation", 6)
	for spec: Array in specs:
		var paired := String(spec[0]) in ["Options", "Quit"]
		var learn_pair := String(spec[0]) in ["Days", "Training"]
		var mode_pair := String(spec[0]) in ["Freestyle", "Arcade"] or learn_pair
		var b := UiKit.button(spec[0], &"", Vector2(167 if paired or mode_pair else 340, 48))
		b.set_meta("label", spec[0])
		b.add_theme_font_size_override("font_size", 22 if paired or mode_pair else 24)
		b.pressed.connect(spec[1])
		var idx := _buttons.size()
		b.mouse_entered.connect(func() -> void:
			if _state == &"menu" and _hl != idx:
				_set_hl(idx))
		if paired:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			pair.add_child(b)
		elif learn_pair:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if learn.get_parent() == null:
				v.add_child(learn)
			learn.add_child(b)
		elif mode_pair:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if modes.get_parent() == null:
				v.add_child(modes)
			modes.add_child(b)
		else:
			v.add_child(b)
		_buttons.append(b)
	v.add_child(pair)
	_menu_buttons = _buttons.duplicate()
	if Game.is_demo():
		var tag := UiKit.label(DEMO_TAGLINE, 18, Palette.INK_SOFT, 600)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tag.custom_minimum_size = Vector2(340, 0)
		v.add_child(tag)
	if not Movies.replay_ids().is_empty() and not Game.is_demo():
		_movies_btn = UiKit.button("Hoot's Movies", &"", Vector2(214, 46))
		_movies_btn.name = "MoviesButton"
		_movies_btn.add_theme_font_size_override("font_size", 20)
		_movies_btn.focus_mode = Control.FOCUS_NONE
		_movies_btn.tooltip_text = "Replay Hoot's cartoon explainers (also under Options)"
		_movies_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_movies_btn.offset_left = -240.0
		_movies_btn.offset_right = -26.0
		_movies_btn.offset_top = -FOOTER_H - 62.0
		_movies_btn.offset_bottom = -FOOTER_H - 16.0
		_movies_btn.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_movies_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_movies_btn.pressed.connect(_on_movies)
		_movies_btn.visible = false
		root.add_child(_movies_btn)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["Up", "Down"], "+", ["Enter"], "or click"], 15)
		hr.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(hr)
	var stats := "" if Game.is_demo() else _stats_text()
	if stats != "":
		var sl := UiKit.label(stats, 15, Palette.INK_SOFT, 500)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(340, 0)
		v.add_child(sl)

	_build_days(root)

	var foot := UiKit.label("This is a game, not a hearing test.  All beeps are quiet and every dB is make-believe.", 18, Palette.PAPER, 600)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	foot.offset_top = -38
	foot.offset_bottom = -10
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(foot)

	# the safety notice (first title of the session)
	_notice_layer = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	root.add_child(_notice_layer)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice_layer.add_child(cc)
	_notice = UiKit.panel(Palette.PAPER, Palette.INK, 28)
	_notice.custom_minimum_size = Vector2(680, 0)
	cc.add_child(_notice)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 14)
	_notice.add_child(nv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	nv.add_child(head)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(52, 52)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.draw.connect(func() -> void:
		badge.draw_circle(Vector2(26, 26), 25, Palette.INK)
		badge.draw_circle(Vector2(26, 26), 21, Palette.SUNNY)
		badge.draw_string(_font, Vector2(19, 39), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Palette.INK))
	head.add_child(badge)
	var h := UiKit.label("This is a game, not a hearing test.", 30, Palette.INK, 700)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(h)
	var body := UiKit.label("", 21, Palette.INK, 500)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.text = "The beeps are quiet and pretend, and you never need to hear them: every beep and every answer lights up on screen."
	nv.add_child(body)
	var small := UiKit.label("Worried about your hearing? See a licensed hearing professional.", 17, Palette.INK_SOFT, 500)
	small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nv.add_child(small)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	nv.add_child(row)
	if UiKit.show_key_hints():
		var hr2 := UiKit.hint_row([["Enter"], "or click"], 15)
		hr2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(hr2)
	var ok := UiKit.button("Got it!", &"AccentButton", Vector2(200, 56))
	ok.pressed.connect(_on_notice_ok)
	row.add_child(ok)


## (v3) The day picker. (Polish) A scrolling grid with one card per chapter, any number of them:
## the columns and visible rows follow the screen (_layout_days), the rest scrolls (mouse wheel,
## the scroll bar, or the arrow keys, which keep the highlighted card in view). Then Back.
func _build_days(root: Control) -> void:
	_days_card = UiKit.panel(Color(Palette.PAPER, 0.97), Palette.INK, 26)
	_days_card.name = "DaysCard"
	_days_card.visible = false
	root.add_child(_days_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_days_card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	v.add_child(head)
	var title := UiKit.label("Pick a day", 32, Palette.INK, 700)
	head.add_child(title)
	_days_note = UiKit.label("Every day is open: play them in any order.", 16, Palette.INK_SOFT, 600)
	_days_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_days_note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_days_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_days_note)
	_days_scroll = ScrollContainer.new()
	_days_scroll.name = "DaysScroll"
	_days_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_days_scroll.follow_focus = false
	v.add_child(_days_scroll)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(GRID_MARGIN))
	_days_scroll.add_child(margin)
	_days_grid = GridContainer.new()
	_days_grid.name = "DaysGrid"
	_days_grid.add_theme_constant_override("h_separation", int(CARD_GAP))
	_days_grid.add_theme_constant_override("v_separation", int(CARD_GAP))
	_days_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(_days_grid)
	for ch: Dictionary in _chapter_list():
		var id := String(ch.get("id", ""))
		var b := _day_card(ch)
		b.pressed.connect(func() -> void: _pick_day(id, b))
		_add_day_button(_days_grid, b)
		_day_cards.append(b)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 14)
	v.add_child(foot)
	if UiKit.show_key_hints():
		# two versions of the hint: "wheel scrolls" only when there are more days than fit (_layout_days)
		for scroll_hint: bool in [false, true]:
			var hr := UiKit.hint_row([["Arrows"], "+", ["Enter"], "   ", ["Esc"],
				"back    wheel scrolls    or click" if scroll_hint else "back    or click"], 15)
			hr.name = "HintScroll" if scroll_hint else "HintPlain"
			hr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hr.visible = not scroll_hint
			foot.add_child(hr)
			if scroll_hint:
				_days_hint_scroll = hr
			else:
				_days_hint_plain = hr
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(spacer)
	var back := UiKit.button("Back", &"", Vector2(180, 48))
	back.set_meta("label", "Back")
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_days_back)
	_add_day_button(foot, back)
	get_viewport().size_changed.connect(_on_viewport_resized)


## One day's card: a flat button that draws itself (_draw_day_card); its labels are children, so
## the title text ("Day 2: Bonnie Bunsworth") is what a click or a screen reader finds. The label
## meta is the full title; the card shows the DAY chip and the name.
func _day_card(ch: Dictionary) -> Button:
	var id := String(ch.get("id", ""))
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_filter = Control.MOUSE_FILTER_PASS   # clicks stop here; the wheel reaches the scroll
	b.custom_minimum_size = CARD_SIZE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.set_meta("label", String(ch.get("title", id)))
	b.set_meta("chapter", id)
	b.set_meta("ch", ch)
	b.draw.connect(_draw_day_card.bind(b))
	var full := String(ch.get("title", id))
	var name_part := full.get_slice(":", 1).strip_edges() if full.contains(":") else full
	var title := UiKit.label(name_part, 21, Palette.INK, 700)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	b.add_child(title)
	var teach := UiKit.label(String(ch.get("teaches", "")), 15, Palette.INK_SOFT, 600)
	teach.name = "Teaches"
	teach.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	teach.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	teach.clip_text = true
	b.add_child(teach)
	var status := UiKit.label("", 15, Palette.INK_SOFT, 700)
	status.name = "Status"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(status)
	_layout_card(b)
	return b


## Place a card's labels for its size (compact or big).
func _layout_card(b: Button) -> void:
	var sz := b.custom_minimum_size
	var k := sz.y / CARD_SIZE.y
	var w := sz.x - 20.0
	var t := b.get_node("Title") as Label
	t.position = Vector2(10, 108.0 * k)
	t.size = Vector2(w, 30.0 * k)
	t.add_theme_font_size_override("font_size", int(21.0 * k))
	var te := b.get_node("Teaches") as Label
	te.position = Vector2(10, 137.0 * k)
	te.size = Vector2(w, 24.0 * k)
	te.add_theme_font_size_override("font_size", int(15.0 * k))
	var st := b.get_node("Status") as Label
	st.position = Vector2(10, 173.0 * k)
	st.size = Vector2(w, 24.0 * k)
	st.add_theme_font_size_override("font_size", int(15.0 * k))


func _draw_day_card(b: Button) -> void:
	var ch: Dictionary = b.get_meta("ch", {})
	var hl := bool(b.get_meta("hl", false))
	var k := b.size.y / CARD_SIZE.y
	var day := int(ch.get("day", 0))
	var r := Rect2(Vector2.ZERO, b.size)
	var tint := card_tint(ch)
	if hl:
		UiDraw.rounded_rect(b, r.grow(6.0), Palette.SUNNY, 26)
	UiDraw.rounded_rect(b, Rect2(r.position + Vector2(0, 5), r.size), Color(Palette.INK, 0.18), 22)
	UiDraw.rounded_rect(b, r, Palette.PAPER, 22, 4, Palette.INK)
	# the tinted top with the patient's portrait
	var top := Rect2(Vector2(4, 4), Vector2(b.size.x - 8, 96.0 * k))
	UiDraw.rounded_rect(b, top, tint.lerp(Palette.PAPER, 0.3), 18)
	for i in 5:
		var x := 22.0 * k + i * (b.size.x - 44.0 * k) / 4.0
		b.draw_circle(Vector2(x, 24.0 * k + 14.0 * k * float(i % 2)), 4.0 * k, Color(Color.WHITE, 0.45))
	var pc := Vector2(b.size.x * 0.5, 56.0 * k)
	var bob := sin(_t * 2.4 + day * 1.7) * (3.0 if hl else 0.0)
	Portraits.draw(b, card_face(ch), pc + Vector2(0, bob), 38.0 * k, false, fmod(_t + day * 0.9, 4.2) < 0.12)
	# the DAY chip
	var f := UiKit.font(700)
	var fs := int(16.0 * k)
	var chip := "DAY %d" % day
	var cw := f.get_string_size(chip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	UiDraw.rounded_rect(b, Rect2(Vector2(12, 12) * k, Vector2(cw + 20.0 * k, 28.0 * k)), Palette.INK, 12)
	b.draw_string(f, Vector2(22.0 * k, 32.0 * k), chip, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.PAPER)
	# best grade badge (a finished day)
	var best := String(b.get_meta("best", ""))
	if best != "":
		var bc := Vector2(b.size.x - 34.0 * k, 34.0 * k)
		var br := 21.0 * k
		b.draw_circle(bc + Vector2(0, 3), br, Color(Palette.INK, 0.25))
		b.draw_circle(bc, br, Palette.grade_color(best))
		b.draw_arc(bc, br, 0, TAU, 32, Palette.INK, 3.5, true)
		var gs := int(24.0 * k)
		var gw := f.get_string_size(best, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
		b.draw_string(f, bc + Vector2(-gw * 0.5, 9.0 * k), best, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Palette.INK)
		var bs := int(11.0 * k)
		var bw := f.get_string_size("BEST", HORIZONTAL_ALIGNMENT_LEFT, -1, bs).x
		b.draw_string(f, bc + Vector2(-bw * 0.5, br + 13.0 * k), "BEST", HORIZONTAL_ALIGNMENT_LEFT, -1, bs, Palette.INK_SOFT)
	# the suggested day: a little UP NEXT ribbon (a hint, never a lock)
	if bool(b.get_meta("suggested", false)):
		var us := int(13.0 * k)
		var txt := "UP NEXT"
		var uw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, us).x + 18.0 * k
		var wob := sin(_t * 3.0) * 1.5 if hl else 0.0
		var ur := Rect2(Vector2(b.size.x - uw - 10.0 * k, 12.0 * k + wob), Vector2(uw, 24.0 * k))
		UiDraw.rounded_rect(b, Rect2(ur.position + Vector2(0, 3), ur.size), Color(Palette.INK, 0.25), 10)
		UiDraw.rounded_rect(b, ur, Palette.SUNNY, 10, 3, Palette.INK)
		b.draw_string(f, ur.position + Vector2(9.0 * k, 17.0 * k), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, us, Palette.INK)
	# a divider above the status line
	b.draw_line(Vector2(50, 168.0 * k), Vector2(b.size.x - 50, 168.0 * k), Color(Palette.INK, 0.12), 2.0)


func _add_day_button(v: Container, b: Button) -> void:
	var idx := _day_buttons.size()
	b.mouse_entered.connect(func() -> void:
		if _state == &"days" and _hl != idx:
			_set_hl(idx))
	v.add_child(b)
	_day_buttons.append(b)


func _has_progress() -> bool:
	return int(Game.progress.get("plays", 0)) > 0 or int(Game.progress.get("coins", 0)) > 0 \
		or not (Game.progress.get("patients", {}) as Dictionary).is_empty()


## "New player": wipe coins, upgrades, records and Hoot's mastery (settings stay). Two presses.
func _on_new_player() -> void:
	var b: Button = null
	for x: Button in _buttons:
		if String(x.get_meta("label")) in ["New player", "Sure? Press again"]:
			b = x
	if not _reset_armed:
		_reset_armed = true
		if b != null:
			b.set_meta("label", "Sure? Press again")
			_set_hl(_buttons.find(b), false)
		Sfx.play(&"error", 1.0, -8.0)
		return
	_reset_armed = false
	for k: String in ["coins", "upgrades", "patients", "plays", "hoot_mastery", "chapters_done", "last_chapter", "training"]:
		var d: Variant = Game.DEFAULT_PROGRESS[k]
		Game.progress[k] = d.duplicate(true) if (d is Dictionary or d is Array) else d
	Game.save_game()
	Sfx.play(&"whoosh")
	Events.goto_scene.emit("res://story/title_screen.tscn")


func _stats_text() -> String:
	var parts: PackedStringArray = []
	var any := false
	var bests: PackedStringArray = []
	for ch: Dictionary in Game.chapters():
		var rec: Dictionary = (Game.progress.get("patients", {}) as Dictionary).get(String(ch["patient_id"]), {})
		if not rec.is_empty():
			any = true
		if not rec.is_empty() and String(rec.get("best_grade", "")) != "":
			bests.append("Day %d best: %s" % [int(ch["day"]), String(rec["best_grade"])])
	# (polish) many days: one short line instead of a best grade per day (the Days card shows them)
	if bests.size() <= 2:
		parts.append_array(bests)
	else:
		parts.append("%d of %d days done" % [(Game.progress.get("chapters_done", []) as Array).size(), Game.chapters().size()])
	var coins := int(Game.progress.get("coins", 0))
	if coins > 0 or any:
		parts.append("%d Decibucks" % coins)
	if Game.has_upgrade("comfy_chair"):
		parts.append("Comfy chair owned")
	if Game.has_upgrade("insert_earphones"):
		parts.append("Insert earphones owned")
	# (training) the Masking School diploma (the exam finished), with its best grade
	var best := -1
	var tr: Variant = Game.progress.get("training", {})
	if tr is Dictionary and (tr as Dictionary).get("masking", null) is Dictionary:
		var st: Variant = ((tr as Dictionary)["masking"] as Dictionary).get("stations", {})
		if st is Dictionary and (st as Dictionary).get("exam", null) is Dictionary:
			best = int(((st as Dictionary)["exam"] as Dictionary).get("best", -1))
	if best >= 0:
		parts.append("Masking diploma: %s" % load("res://story/training/masking/mask_deck.gd").exam_grade(best))
	# (practical) the Booth Camp Practical licence (Exam day finished), its best grade and a pass
	var lic: Script = load("res://story/training/practical/licence.gd")
	if lic.earned():
		parts.append("Practical: %s%s" % [lic.grade(), " (pass)" if lic.passed() else ""])
	return "  -  ".join(parts)


# ---------------------------------------------------------------- logo

func _draw_logo() -> void:
	var size_px := 112
	var base := Vector2(8, 150)
	var x := base.x
	var pieces: Array = ["B", "cupR", "cupL", "T", "H"]
	var cup_r := size_px * 0.36
	var cup_centers: Array[Vector2] = []
	var wiggle := sin(_t * 2.2) * 0.04
	_logo.draw_set_transform(Vector2.ZERO, wiggle * 0.25, Vector2.ONE)
	for p: String in pieces:
		if p.begins_with("cup"):
			var c := Vector2(x + cup_r + 4, base.y - size_px * 0.34 + sin(_t * 3.0 + (0.0 if p == "cupR" else PI)) * 4.0)
			cup_centers.append(c)
			x += cup_r * 2.0 + 10.0
		else:
			_letter(p, Vector2(x, base.y), size_px, Palette.SUNNY)
			x += _font.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x - 4.0
	# headband over the two cups
	var mid := (cup_centers[0] + cup_centers[1]) * 0.5
	var band_r := (cup_centers[1].x - cup_centers[0].x) * 0.5 + 6.0
	_logo.draw_arc(mid + Vector2(0, 4), band_r, PI * 1.05, PI * 1.95, 24, Palette.INK, 22, true)
	_logo.draw_arc(mid + Vector2(0, 4), band_r, PI * 1.07, PI * 1.93, 24, Color("#6b5e7e"), 12, true)
	UiDraw.rounded_rect(_logo, Rect2(mid + Vector2(-22, -band_r - 8), Vector2(44, 20)), Palette.SUNNY, 8, 3, Palette.INK)
	for i in 2:
		var c := cup_centers[i]
		var col := Palette.RIGHT_RED if i == 0 else Palette.LEFT_BLUE
		_logo.draw_circle(c, cup_r + 6, Palette.INK)
		_logo.draw_circle(c, cup_r, col)
		_logo.draw_circle(c, cup_r * 0.62, Palette.INK)
		_logo.draw_circle(c, cup_r * 0.42, Color("#4a3f5e"))
		_logo.draw_circle(c + Vector2(-cup_r * 0.42, -cup_r * 0.42), cup_r * 0.16, Color(1, 1, 1, 0.55))
		_logo.draw_string(_font, c + Vector2(-9, 10), "R" if i == 0 else "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		# little beep waves
		var phase := fmod(_t * 0.9 + i * 0.5, 1.0)
		var dir := -1.0 if i == 0 else 1.0
		for k in 2:
			var rr := cup_r + 10.0 + (phase + k * 0.5) * 30.0
			var a := 1.0 - fmod(phase + k * 0.5, 1.0)
			var ang := PI if i == 0 else 0.0
			_logo.draw_arc(c, rr, ang - 0.5 * dir, ang + 0.5 * dir, 10, Color(Palette.TONE_CYAN, a), 5, true)
	# CAMP, on a second line
	var x2 := 60.0
	var y2 := base.y + 84.0
	for ch: String in ["C", "A", "M", "P"]:
		var bob := sin(_t * 3.0 + x2 * 0.02) * 3.0
		_letter(ch, Vector2(x2, y2 + bob), 92, Palette.CORAL)
		x2 += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, 92).x - 2.0
	_logo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# (polish) the tagline sits beside CAMP: the taller menu card (five buttons) covers the space below
	var tag := "Beep. Bracket.\nBe a hearing hero."
	var tf := UiKit.font(600)
	var tfs := 22
	var tp := Vector2(x2 + 34.0, y2 - 52.0)
	var ts := tf.get_multiline_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs)
	var asc := tf.get_ascent(tfs)
	var tilt := -0.05 + sin(_t * 1.6) * 0.01
	_logo.draw_set_transform(tp, tilt, Vector2.ONE)
	UiDraw.rounded_rect(_logo, Rect2(Vector2(-16.0, -asc - 8.0), Vector2(ts.x + 32.0, ts.y + 14.0)), Color(Palette.PAPER, 0.94), 20, 3, Color(Palette.INK, 0.85))
	_logo.draw_multiline_string(tf, Vector2.ZERO, tag, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs, -1, Palette.INK_SOFT)
	_logo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _letter(ch: String, at: Vector2, px: int, fill: Color) -> void:
	_logo.draw_string_outline(_font, at + Vector2(0, 7), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 22, Color(Palette.INK, 0.35))
	_logo.draw_string_outline(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, 20, Palette.INK)
	_logo.draw_string(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, fill)
	_logo.draw_string(_font, at + Vector2(3, -4), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(fill.lightened(0.35), 0.0))
