extends Control
## PracticalSchool (training, story-internal): one station of The Practical, the Training room's second
## lesson (docs/training/PRACTICAL_EXAM.md). The room sets `next_station` and opens this scene; the
## station runs Masking School's loop and comes back to the room:
##   1. Hoot's card (what the station is for, the lesson's disclaimer; on a first visit to a station
##      with a movie, Hoot's movie plays after Start)
##   2. Try it (Hoot's guided cards: only the right answer is open)
##   3. Your round (PracticalDeck.ROUND_HOLES pick-one cards, instant feedback, golf strokes)
##   4. The scorecard (holes, the round, the star, a new cheat-sheet card)
## Stations built so far: 1 "Pack the bag" (what stays home, the calibration sticker, the listening
## check, the subject); 2 "Steady hands" (the safe grip, a grip to judge, hygiene, three looks to go
## ahead or refer by California's eight; its movie "The Steady Hand"). An unsafe pick (a grip that
## isn't braced) is the lesson's one STOP: it costs PracticalDeck.UNSAFE_STROKES, not one.
## Controls: keys 1-4 answer, H hint (a stroke), Enter / Space go on, R plays again on the scorecard,
## T leaves for the room; Esc pauses, like everywhere. Everything clicks too. Playable with sound off:
## every answer is drawn, and no tone is ever played to test the player.
## Beats (CONTRACTS.md §3.2; solvers go through the same code as a click):
##   practical_intro {station}                                solver: Start
##   explainer (the station's movie, first visit)             solver: skip
##   practical_try {station, step, best, options, mouse}      solver: the right answer, then Next
##   practical_card {station, hole, kind, best, options, unsafe, mouse}  solver: the right answer
##   practical_next {station, hole}                           solver: Next
##   practical_scorecard {station, over_par, star}            solver: back to the room

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const PracticalArt := preload("res://story/training/practical/practical_art.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")
const ROOM_SCENE := "res://story/training/training_room.tscn"
const PLAYER_SCENE := "res://story/explainers/explainer_player.tscn"

const FIELD := Vector2(1280, 720)
const STAGE_AT := Vector2(24, 84)
const STAGE_SIZE := Vector2(880, 440)
const SIDE_X := 924.0
const SIDE_W := 332.0
const BG := Color("#e3f1ee")
const HOLE_COLORS: Array[Color] = [Color("#5bc8a3"), Color("#ffd23f"), Color("#ff6f59"), Color("#8e5cc4")]

## The station the room opens next (a room chip sets it before goto_scene).
static var next_station := "kit"
## The last finished round, for the tests and the bot: {station, strokes, over_par, star, new_card, best}.
static var last_result: Dictionary = {}

var station_id := "kit"
var info: Dictionary = {}
var strokes: Array[int] = []
var rng := RandomNumberGenerator.new()

var _field: Control
var _stage: Control
var _stage_t := 0.0
var _hoot_face: Control
var _hoot_label: Label
var _top_label: Label
var _score_label: Label
var _answers: VBoxContainer
var _next_btn: Button
var _hint_btn: Button
var _feedback: Label
var _overlay: Control
var _state: StringName = &"busy"
var _leaving := false
var _talk := 0.0

# the live card
var _card: Dictionary = {}
var _reveal := false
var _wrong: Array[int] = []
var _hole_strokes := 1
var _hinted := false
var _guided := false   # a Try it card: only the right answer is open

signal _go(what: StringName)


func demo_start() -> void:
	pass   # boots straight into next_station (--scene=res://story/training/practical/practical_school.tscn)


func _ready() -> void:
	add_to_group("practical_school")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hoot.clear()
	station_id = Game.cli_value("station", next_station) if Game.cli.has("station") else next_station
	if PracticalDeck.station(station_id).is_empty() or not bool(PracticalDeck.station(station_id)["built"]):
		station_id = "kit"
	info = PracticalDeck.station(station_id)
	rng.seed = int(Game.cli.get("seed", Time.get_ticks_usec()))
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_run.call_deferred()


func _process(delta: float) -> void:
	_stage_t += delta
	_talk = maxf(0.0, _talk - delta)
	_hoot_face.queue_redraw()
	_stage.queue_redraw()


# ================================================================ the flow

func _run() -> void:
	Events.phase_changed.emit(&"training", {"lesson": PracticalDeck.LESSON, "station": station_id})
	if not await _intro():
		return
	if _movie() != "" and not Game.is_movie_seen(_movie()):
		await _play_movie()
	if _leaving:
		return
	await _try_it()
	if _leaving:
		return
	await _round()
	if _leaving:
		return
	await _scorecard()


## Hoot's card. Returns false when the player left from it.
func _intro() -> bool:
	_state = &"intro"
	_show_overlay(_intro_panel())
	_say("%s Let's go!" % String(info["pitch"]))
	Events.awaiting_input.emit(&"practical_intro", {"station": station_id, "mouse": {"click": "Start"}}, start)
	var what: StringName = await _go
	Events.input_resolved.emit(&"practical_intro")
	if what == &"movie":
		_hide_overlay()
		await _play_movie()
		return await _intro()
	_hide_overlay()
	return what == &"start"


func start() -> void:
	if _state == &"intro":
		_state = &"busy"
		Sfx.play(&"click")
		_go.emit(&"start")


func rewatch() -> void:
	if _state == &"intro":
		_state = &"busy"
		Sfx.play(&"click")
		_go.emit(&"movie")


## The station's lead-in movie ("" for none).
func _movie() -> String:
	return String(info.get("movie", ""))


func _play_movie() -> void:
	_say("A quick cartoon first: Hoot's movie!")
	var player: Node = (load(PLAYER_SCENE) as PackedScene).instantiate()
	add_child(player)
	await player.call("play", _movie(), "training")
	player.queue_free()


# ---------------------------------------------------------------- try it

func _try_it() -> void:
	var tries := PracticalDeck.tries(station_id)
	_guided = true
	for i in tries.size():
		_set_top("Try it %d of %d" % [i + 1, tries.size()])
		_deal_card(tries[i])
		_say(String(_card["line"]))
		_feedback_text("Hoot shows you this one. Pick the answer he points at.")
		_answer_buttons()
		_state = &"card"
		var opts: Array = _card["options"]
		var best := int(_card["answer"])
		Events.awaiting_input.emit(&"practical_try", {"station": station_id, "step": i, "best": best, "options": opts,
			"mouse": {"click": String(opts[best])}}, func() -> void: pick(best))
		await _go
		Events.input_resolved.emit(&"practical_try")
		if _leaving:
			return
		_state = &"next"
		_show_next("Next" if i < tries.size() - 1 else "Your round")
		Events.awaiting_input.emit(&"practical_next", {"station": station_id, "hole": -1 - i, "mouse": {"click": _next_btn.text}}, press_next)
		await _go
		Events.input_resolved.emit(&"practical_next")
		if _leaving:
			return
	_guided = false


# ---------------------------------------------------------------- the round

func _round() -> void:
	strokes.clear()
	_update_score()
	var cards := PracticalDeck.deal(station_id, rng)
	for h in cards.size():
		_set_top("Hole %d of %d" % [h + 1, cards.size()])
		_deal_card(cards[h])
		_say(_ask_line())
		_feedback_text(_ask_feedback())
		_answer_buttons()
		_state = &"card"
		var opts: Array = _card["options"]
		var best := int(_card["answer"])
		Events.awaiting_input.emit(&"practical_card", {"station": station_id, "hole": h, "kind": String(_card["kind"]), "best": best,
			"options": opts, "unsafe": (_card.get("unsafe", []) as Array).duplicate(), "mouse": {"click": String(opts[best])}},
			func() -> void: pick(best))
		await _go
		Events.input_resolved.emit(&"practical_card")
		if _leaving:
			return
		strokes.append(_hole_strokes)
		_update_score()
		_state = &"next"
		_show_next("Next hole" if h < cards.size() - 1 else "Scorecard")
		Events.awaiting_input.emit(&"practical_next", {"station": station_id, "hole": h, "mouse": {"click": _next_btn.text}}, press_next)
		await _go
		Events.input_resolved.emit(&"practical_next")
		if _leaving:
			return


func _deal_card(c: Dictionary) -> void:
	_card = c
	_reveal = false
	_wrong.clear()
	_hole_strokes = 1
	_hinted = false
	_stage_t = 0.0


func _ask_line() -> String:
	match String(_card["kind"]):
		"tray":
			return "Three of these go in the clear bag. Which one stays home?"
		"sticker":
			return "Only an audiometer calibrated within the last %d months can come. Which one?" % PracticalDeck.CAL_MONTHS
		"listen":
			return "Your listening check, before the subject sits down. What do you do?"
		"subject":
			return "The board approves your subject first. Can this person be yours?"
		"grip":
			return "Four ways to hold it. Only one is safe support. Which?"
		"brace":
			return "Hands set. Look at both of them before you go in."
		"wash":
			return "Clean hands, clean tools. What now?"
		"look":
			return "Look in the ear and read the card. Go ahead, or a doctor first?"
	return "Pick one."


func _ask_feedback() -> String:
	match String(_card["kind"]):
		"tray":
			return "Check the type, the size, the date, and whether it belongs in an exam room at all."
		"sticker":
			return "Exam day: %s. Count back to each sticker." % String(_card["exam"])
		"listen":
			return String(_card["symptom"])
		"subject":
			return "%s: %s" % [String(_card["who"]), String(_card["about"])]
		"grip", "brace":
			return "Safe support: a bridge hand on the head, the instrument hand braced on it. An unsafe pick is a STOP (+%d)." % PracticalDeck.UNSAFE_STROKES
		"wash":
			return "Hygiene counts at both exam stations: hands, tools, every contact."
		"look":
			return "California's list, from the law: deformity, drainage, sudden loss, dizziness, one-sided loss, a big gap, wax, pain."
	return ""


## Answer the live card (keys 1-4, a click or the solver).
func pick(i: int) -> void:
	if _state != &"card" or _wrong.has(i) or i < 0 or i >= (_card["options"] as Array).size():
		return
	if _guided and i != int(_card["answer"]):
		return
	if i == int(_card["answer"]):
		_state = &"busy"
		_reveal = true
		if not _card.has("sneeze_at"):
			_card["sneeze_at"] = _stage_t   # a grip card: now let them sneeze
		Sfx.play(&"ding", 1.1, -6.0)
		var lines: Array = _card["lines"]
		_feedback_text("%s\n%s" % [String(lines[0]), String(lines[1])])
		if not _guided:
			_say(_hole_line())
		for b: Button in _answer_list():
			var mine := int(b.get_meta("answer", -1)) == i
			b.disabled = not mine
			if mine:
				b.text = "  " + String((_card["options"] as Array)[i]) + "  "
		if _hint_btn != null:
			_hint_btn.disabled = true
		_go.emit(&"right")
		return
	_wrong.append(i)
	var unsafe := (_card.get("unsafe", []) as Array).has(i)
	_hole_strokes += PracticalDeck.UNSAFE_STROKES if unsafe else 1
	Sfx.play(&"error", 1.0, -10.0)
	if unsafe:
		_say("STOP! That's the one they stop you for. Brace first, then go in.")
		if not _card.has("sneeze_at"):
			_card["sneeze_at"] = _stage_t
	else:
		_say("Not quite. %s" % String(_card["hint"]))
	for b: Button in _answer_list():
		if int(b.get_meta("answer", -1)) == i:
			b.disabled = true
			b.text = "STOP: unsafe" if unsafe else "Not quite"
			Juice.shake(b, 5.0, 0.25)


func hint() -> void:
	if _state != &"card" or _hinted or _guided:
		return
	_hinted = true
	_hole_strokes += 1
	Sfx.play(&"pop", 1.0, -8.0)
	_say(String(_card["hint"]))
	if _hint_btn != null:
		_hint_btn.disabled = true


func _hole_line() -> String:
	match _hole_strokes:
		1:
			return "Spot on! Par."
		2:
			return "Got there. A bogey: one extra stroke."
	return "Got it in the end. Read the card twice next time."


func press_next() -> void:
	if _state == &"next":
		_state = &"busy"
		Sfx.play(&"click")
		_go.emit(&"next")


# ---------------------------------------------------------------- the scorecard

func _scorecard() -> void:
	var total := 0
	for s: int in strokes:
		total += s
	var over := total - strokes.size()
	var star := over == 0
	var rec := TrainingProgress.record_round(PracticalDeck.LESSON, station_id, over, String(info["card"]))
	# Station 2 earns a second card (California's Refer 8) with the first
	var card2 := String(info.get("card2", ""))
	rec["new_card2"] = card2 != "" and TrainingProgress.earn_card(PracticalDeck.LESSON, card2)
	last_result = {"station": station_id, "strokes": strokes.duplicate(), "over_par": over, "star": star,
		"new_card": bool(rec["new_card"]), "best": int(rec["best"])}
	print("PRACTICAL_RESULT %s" % JSON.stringify(last_result))
	_state = &"score"
	_show_overlay(_score_panel(over, rec))
	if star:
		Sfx.play(&"fanfare", 1.0, -8.0)
		_say(String(info.get("star_line", "Even par! That's a star.")))
	else:
		_say("%s. Play again for the star, or head back to the room." % PracticalDeck.round_name(over))
	Events.awaiting_input.emit(&"practical_scorecard", {"station": station_id, "over_par": over, "star": star,
		"mouse": {"click": "Back to the Training room"}}, leave)
	var what: StringName = await _go
	Events.input_resolved.emit(&"practical_scorecard")
	if what == &"again":
		_hide_overlay()
		await _round()
		if not _leaving:
			await _scorecard()


func play_again() -> void:
	if _state == &"score":
		_state = &"busy"
		Sfx.play(&"click")
		_go.emit(&"again")


## Back to the Training room (from anywhere in the station).
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	_state = &"busy"
	Sfx.play(&"click")
	_go.emit(&"leave")
	Events.goto_scene.emit(ROOM_SCENE)


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var k := event as InputEventKey
	var code := KEY_NONE
	if k != null:
		code = k.keycode if k.keycode != KEY_NONE else k.physical_keycode
	var n := (_card.get("options", []) as Array).size()
	var handled := true
	if code == KEY_T:
		leave()
	elif _state == &"card" and code >= KEY_1 and code < KEY_1 + n:
		pick(code - KEY_1)
	elif _state == &"card" and code >= KEY_KP_1 and code < KEY_KP_1 + n:
		pick(code - KEY_KP_1)
	elif _state == &"card" and code == KEY_H:
		hint()
	elif _state == &"score" and code == KEY_R:
		play_again()
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		match _state:
			&"intro":
				start()
			&"next":
				press_next()
			&"score":
				leave()
			_:
				handled = false
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()


# ================================================================ building

func _build() -> void:
	var bg := UiKit.full_rect()
	bg.draw.connect(func() -> void: bg.draw_rect(Rect2(Vector2.ZERO, bg.size), BG))
	add_child(bg)
	_field = Control.new()
	_field.size = FIELD
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_field)
	# the top bar: the lesson chip, the station, the hole, the strokes, Leave
	var chip := UiKit.panel(info["color"], Palette.INK, 16)
	chip.position = Vector2(24, 16)
	chip.add_child(UiKit.label("THE PRACTICAL  %d: %s" % [int(info["num"]), String(info["name"])], 22, Palette.PAPER, 700))
	_field.add_child(chip)
	_top_label = UiKit.label("", 22, Palette.INK, 700)
	_top_label.position = Vector2(500, 26)
	_field.add_child(_top_label)
	_score_label = UiKit.label("", 20, Palette.INK_SOFT, 600)
	_score_label.position = Vector2(670, 28)
	_field.add_child(_score_label)
	var leave_btn := UiKit.button("Back to the room", &"", Vector2(232, 48))
	leave_btn.position = Vector2(FIELD.x - 88 - 232, 14)   # clear of the pause button in the corner
	leave_btn.add_theme_font_size_override("font_size", 20)
	leave_btn.pressed.connect(leave)
	_field.add_child(leave_btn)
	# the stage: the live card, drawn
	_stage = Control.new()
	_stage.name = "PracticalStage"
	_stage.position = STAGE_AT
	_stage.size = STAGE_SIZE
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.draw.connect(func() -> void:
		if not _card.is_empty():
			PracticalArt.draw_card(_stage, _stage.size, _card, _reveal, _wrong, _stage_t))
	_field.add_child(_stage)
	# Hoot's corner
	var hoot := UiKit.panel(Palette.PAPER, Palette.INK, 20)
	hoot.position = Vector2(SIDE_X, 84)
	hoot.custom_minimum_size = Vector2(SIDE_W, 172)
	hoot.size = Vector2(SIDE_W, 172)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	hoot.add_child(hh)
	_hoot_face = Control.new()
	_hoot_face.custom_minimum_size = Vector2(86, 86)
	_hoot_face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_hoot_face.draw.connect(func() -> void:
		Portraits.draw(_hoot_face, "Hoot", Vector2(43, 43), 38.0, _talk > 0.0 and fmod(_talk, 0.25) > 0.12))
	hh.add_child(_hoot_face)
	_hoot_label = UiKit.label("", 19, Palette.INK, 600)
	_hoot_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hoot_label.custom_minimum_size = Vector2(SIDE_W - 130, 0)
	_hoot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(_hoot_label)
	_field.add_child(hoot)
	# the answer buttons, the hint and Next
	_answers = VBoxContainer.new()
	_answers.position = Vector2(SIDE_X, 272)
	_answers.custom_minimum_size = Vector2(SIDE_W, 0)
	_answers.add_theme_constant_override("separation", 10)
	_field.add_child(_answers)
	# the feedback card under the stage
	var fp := UiKit.panel(Palette.PAPER, Palette.INK, 18)
	fp.position = Vector2(24, 540)
	fp.custom_minimum_size = Vector2(880, 120)
	fp.size = Vector2(880, 120)
	_feedback = UiKit.label("", 20, Palette.INK, 600)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fp.add_child(_feedback)
	_field.add_child(fp)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["1", "2", "3", "4"], "answer", ["H"], "hint", ["Enter"], "next", ["T"], "room", ["Esc"], "pause"], 16)
		hr.position = Vector2(24, 676)
		_field.add_child(hr)
	_overlay = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	_overlay.visible = false
	add_child(_overlay)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var off := ((vp - FIELD) * 0.5).floor()
	_field.position = Vector2(maxf(off.x, 0.0), maxf(off.y, 0.0))


func _say(text: String) -> void:
	_hoot_label.text = text
	_talk = minf(2.0, text.length() / 30.0)
	Events.dialogue_line.emit("Hoot", text)


func _set_top(text: String) -> void:
	_top_label.text = text


func _update_score() -> void:
	if strokes.is_empty():
		_score_label.text = ""
		return
	var total := 0
	for s: int in strokes:
		total += s
	_score_label.text = "Strokes %d (%s)" % [total, PracticalDeck.round_name(total - strokes.size())]


func _feedback_text(text: String) -> void:
	_feedback.text = text


func _clear_answers() -> void:
	for c in _answers.get_children():
		c.queue_free()
		_answers.remove_child(c)
	_next_btn = null
	_hint_btn = null


func _answer_list() -> Array[Button]:
	var out: Array[Button] = []
	for c in _answers.get_children():
		if c is Button and c.has_meta("answer"):
			out.append(c as Button)
	return out


func _answer_buttons() -> void:
	_clear_answers()
	var opts: Array = _card["options"]
	for i in opts.size():
		var b := _side_button(String(opts[i]), str(i + 1), Vector2(SIDE_W, 56 if opts.size() > 3 else 64))
		b.set_meta("answer", i)
		b.pressed.connect(pick.bind(i))
		if _guided and i != int(_card["answer"]):
			b.disabled = true
		_answers.add_child(b)
	if not _guided:
		_hint_btn = _side_button("Hoot's hint (+1)", "H", Vector2(SIDE_W, 50))
		_hint_btn.pressed.connect(hint)
		_answers.add_child(_hint_btn)


func _show_next(text: String) -> void:
	_next_btn = _side_button(text, "Enter")
	_next_btn.pressed.connect(press_next)
	_answers.add_child(_next_btn)
	Juice.pop(_next_btn, 1.08, 0.2)


## A wide side-column button with its key chip drawn at the left.
func _side_button(text: String, key: String, min_size := Vector2(SIDE_W, 64)) -> Button:
	var b := UiKit.button(text, &"", min_size)
	b.add_theme_font_size_override("font_size", 19)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.clip_text = true
	if UiKit.show_key_hints() and key != "":
		var kc := UiKit.key_chip(key, 15)
		kc.position = Vector2(8, 8)
		b.add_child(kc)
	return b


# ---------------------------------------------------------------- overlays

func _show_overlay(panel: Control) -> void:
	for c in _overlay.get_children():
		c.queue_free()
	var dim := UiKit.full_rect()
	dim.draw.connect(func() -> void: dim.draw_rect(Rect2(Vector2.ZERO, dim.size), Color(Palette.INK, 0.35)))
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	center.add_child(panel)
	_overlay.visible = true
	Juice.bounce_in(panel)


func _hide_overlay() -> void:
	_overlay.visible = false
	for c in _overlay.get_children():
		c.queue_free()


func _intro_panel() -> Control:
	var p := UiKit.panel(info["color"], Palette.INK, 28)
	p.custom_minimum_size = Vector2(740, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var light := (info["color"] as Color).get_luminance() > 0.55
	var ink: Color = Palette.INK if light else Palette.PAPER
	var accent: Color = Palette.INK if light else Palette.SUNNY
	var num := UiKit.label("THE PRACTICAL: STATION %d" % int(info["num"]), 20, accent, 700)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)
	var title := UiKit.label(String(info["name"]), 44, ink, 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var body := UiKit.panel(Palette.PAPER, Palette.INK, 20)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 14)
	body.add_child(bh)
	var face := Control.new()
	face.custom_minimum_size = Vector2(96, 96)
	face.draw.connect(func() -> void: Portraits.draw(face, "Hoot", Vector2(48, 48), 42.0))
	bh.add_child(face)
	var lines := UiKit.label(String(info["intro"]), 20, Palette.INK, 600)
	lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lines.custom_minimum_size = Vector2(560, 0)
	bh.add_child(lines)
	v.add_child(body)
	var card := PracticalDeck.cheat_card(String(info["card"]))
	var card2 := PracticalDeck.cheat_card(String(info.get("card2", "")))
	if not card.is_empty():
		var earn := UiKit.label("You'll earn: the %s card" % String(card["title"]) if card2.is_empty()
			else "You'll earn: the %s and %s cards" % [String(card["title"]), String(card2["title"])], 20, accent, 700)
		earn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(earn)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var go := UiKit.button("Start", &"", Vector2(220, 60))
	go.add_theme_font_size_override("font_size", 26)
	go.pressed.connect(start)
	row.add_child(go)
	if _movie() != "" and Game.is_movie_seen(_movie()):
		var mv := UiKit.button("Rewatch the movie", &"", Vector2(240, 60))
		mv.add_theme_font_size_override("font_size", 20)
		mv.pressed.connect(rewatch)
		row.add_child(mv)
	var back := UiKit.button("Back to the room", &"", Vector2(220, 60))
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(leave)
	row.add_child(back)
	if _movie() != "" and not Game.is_movie_seen(_movie()):
		var mnote := UiKit.label("First time here: Hoot's movie plays after Start (Esc skips it).", 17, Color(ink, 0.85), 600)
		mnote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(mnote)
	var note := UiKit.label(PracticalDeck.DISCLAIMER, 16, Color(ink, 0.85), 600)
	note.name = "disclaimer"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(680, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)
	return p


func _score_panel(over: int, rec: Dictionary) -> Control:
	var p := UiKit.panel(Palette.PAPER, Palette.INK, 28)
	p.custom_minimum_size = Vector2(820, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := UiKit.label("STATION %d SCORECARD" % int(info["num"]), 30, Palette.INK, 700)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var holes := HBoxContainer.new()
	holes.alignment = BoxContainer.ALIGNMENT_CENTER
	holes.add_theme_constant_override("separation", 8)
	v.add_child(holes)
	for i in strokes.size():
		var s := strokes[i]
		var hp := UiKit.panel(HOLE_COLORS[clampi(s - 1, 0, HOLE_COLORS.size() - 1)], Palette.INK, 14)
		hp.custom_minimum_size = Vector2(118, 0)
		var hv := VBoxContainer.new()
		hp.add_child(hv)
		var n := UiKit.label("Hole %d" % (i + 1), 16, Palette.INK, 600)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hv.add_child(n)
		var g := UiKit.label(PracticalDeck.hole_name(s), 18 if s < 3 else 14, Palette.INK, 700)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hv.add_child(g)
		holes.add_child(hp)
	var total := UiKit.label("Round: %s" % PracticalDeck.round_name(over), 34, Palette.grade_color("S") if over == 0 else Palette.INK, 700)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(total)
	var star := Control.new()
	star.custom_minimum_size = Vector2(0, 64)
	star.draw.connect(func() -> void:
		var c := Vector2(star.size.x * 0.5, 32)
		UiDraw.star(star, c + Vector2(0, 3), 30.0, Color(Palette.INK, 0.3))
		UiDraw.star(star, c, 30.0, Palette.SUNNY if bool(rec["star"]) else Color(Palette.INK_SOFT, 0.25))
		var t := "Star earned!" if over == 0 else ("Star kept from before" if bool(rec["star"]) else "Even par earns the star")
		star.draw_string(UiKit.font(700), c + Vector2(44, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK))
	v.add_child(star)
	var fresh: Array[String] = []
	if bool(rec["new_card"]):
		fresh.append(String(info["card"]))
	if bool(rec.get("new_card2", false)):
		fresh.append(String(info["card2"]))
	if not fresh.is_empty():
		var nc := UiKit.label("New card%s for your Training room!" % ("s" if fresh.size() > 1 else ""), 22, Palette.CORAL, 700)
		nc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nc)
		var holder := HBoxContainer.new()
		holder.alignment = BoxContainer.ALIGNMENT_CENTER
		holder.add_theme_constant_override("separation", 16)
		for id: String in fresh:
			var cc := CheatCard.new(PracticalDeck.cheat_card(id), true, 18 if fresh.size() == 1 else 16)
			cc.custom_minimum_size = Vector2(420, 180) if fresh.size() == 1 else Vector2(380, 170)
			holder.add_child(cc)
		v.add_child(holder)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := UiKit.button("Play again", &"", Vector2(200, 58))
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(play_again)
	row.add_child(again)
	var back := UiKit.button("Back to the Training room", &"", Vector2(340, 58))
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(leave)
	row.add_child(back)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["R"], "play again", ["Enter"], "back to the room"], 16)
		hr.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(hr)
	return p
