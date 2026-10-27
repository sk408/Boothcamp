extends Control
## MaskingSchool (training, story-internal): one Masking School station, played on Hoot's movie stage
## (docs/training/MASKING_TRAINER.md). The Training room sets `next_station` and opens this scene;
## the station runs its loop and comes back to the room:
##   1. Hoot's card (what the station is for; on a first visit to station 1 or 5, its Hoot movie plays after Start)
##   2. Try it (guided cards: nothing can go wrong)
##   3. Your round (MaskDeck.ROUND_HOLES holes, instant feedback, golf strokes)
##   4. The scorecard (holes, the round, the star, a new cheat-sheet card)
## Stations built so far: 1 "Why mask?" (who heard the beep?), 2 "When to mask?" (mask bone, air,
## both or neither?), 3 "How much to start?" (set the noise dial), 4 "The plateau walk" (shhh up, beep
## up, store, or no safe level, one presentation at a time), 5 "The occlusion effect" (the plug lab, six "Does
## it count?" cards, then the pocket card filled from memory: one beat per tile).
## Controls: keys 1-3 answer, H hint (a stroke), Enter / Space go on, Up / Down (the louder / softer
## keys, either key style) move the beep or the dial, Enter sets the dial, R plays again on the
## scorecard, T leaves for the room; Esc pauses, like everywhere. Everything clicks too. Playable with
## sound off: every answer is drawn.
## Beats (CONTRACTS.md §3.2; solvers go through the same code as a click):
##   training_intro {station}                       solver: Start
##   training_try {station, step, target, mouse}    solver: step up to the target, then Next
##   training_card {station, hole, options, best, mouse}  solver: the right answer (station 3: best is
##     the start level in dB EM, start the dial's first level, options empty; turn the dial, Set it;
##     station 4: one beat per move of the walk, with its step)
##   training_next {station, hole}                  solver: Next
##   training_scorecard {station, over_par, star}   solver: back to the room
## The movie's own beat (explainer) plays in between on a first visit to station 1 (the masking movie) or
## 5 ("The Plugged Ear").

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const PLAYER_SCENE := "res://story/explainers/explainer_player.tscn"
const ROOM_SCENE := "res://story/training/training_room.tscn"
const SETS_PATH := "res://story/training/masking/school_sets.gd"

const FIELD := Vector2(1280, 720)
const STAGE_AT := Vector2(24, 84)
const SIDE_X := 924.0
const SIDE_W := 332.0
const BG := Color("#f3e3c3")
const HOLE_COLORS: Array[Color] = [Color("#5bc8a3"), Color("#ffd23f"), Color("#ff6f59"), Color("#8e5cc4")]

## The station the room opens next (a room button sets it before goto_scene).
static var next_station := "why"
## The last finished round, for the tests and the bot: {station, strokes, over_par, star, new_card}.
static var last_result: Dictionary = {}

var station_id := "why"
var info: Dictionary = {}
var strokes: Array[int] = []
var rng := RandomNumberGenerator.new()

var _field: Control
var _stage: Stage2D
var _stage_t := 0.0
var _hoot_face: Control
var _hoot_label: Label
var _top_label: Label
var _score_label: Label
var _answers: VBoxContainer
var _next_btn: Button
var _hint_btn: Button
var _feedback: Label
var _feedback_panel: PanelContainer
var _overlay: Control
var _leave_btn: Button
var _state: StringName = &"busy"
var _leaving := false
var _talk := 0.0

# the live card or try
var _card: Dictionary = {}
var _answer: StringName = &""
var _hole_strokes := 1
var _hinted := false
var _picked: Dictionary = {}   # answers already tried on this hole
var _drill := false             # station 5: placing pocket-card tiles (the options are the tiles)
var _cells: Dictionary = {}     # station 5: the pocket card so far, "row|freq" -> dB
var _blank_count := 0           # station 5: cells left blank at the start of this visit's card

signal _go(what: StringName)


func demo_start() -> void:
	pass   # boots straight into next_station (--scene=res://story/training/masking/masking_school.tscn)


func _ready() -> void:
	add_to_group("masking_school")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Hoot.clear()
	station_id = Game.cli_value("station", next_station) if Game.cli.has("station") else next_station
	if MaskDeck.station(station_id).is_empty() or not bool(MaskDeck.station(station_id)["built"]):
		station_id = "why"
	info = MaskDeck.station(station_id)
	rng.seed = int(Game.cli.get("seed", Time.get_ticks_usec()))
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_run.call_deferred()


func _process(delta: float) -> void:
	_stage_t += delta
	_stage.t = _stage_t
	_talk = maxf(0.0, _talk - delta)
	_hoot_face.queue_redraw()


# ================================================================ the flow

func _run() -> void:
	Events.phase_changed.emit(&"training", {"lesson": MaskDeck.LESSON, "station": station_id})
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
	_say("%s %s" % [String(info["pitch"]), "Let's go!"])
	Events.awaiting_input.emit(&"training_intro", {"station": station_id, "mouse": {"click": "Start"}}, start)
	var what: StringName = await _go
	Events.input_resolved.emit(&"training_intro")
	if what == &"movie":
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


# ---------------------------------------------------------------- station helpers

func _is_dial() -> bool:
	return station_id == "start"


func _is_walk() -> bool:
	return station_id == "plateau"


const TILES: Array[StringName] = [&"t0", &"t10", &"t15"]


func _tile_db(a: StringName) -> int:
	return MaskDeck.OE_TILES[TILES.find(a)]


## The answers of a pick-one station, in key order.
func _options() -> Array[StringName]:
	match station_id:
		"when":
			return MaskDeck.CALLS
		"plateau":
			return MaskDeck.MOVES
		"occlusion":
			return TILES if _drill else MaskDeck.COUNTS
	return MaskDeck.WHO


func _word(a: StringName) -> String:
	match station_id:
		"when":
			return String(MaskDeck.CALL_WORDS[a])
		"plateau":
			return String(MaskDeck.MOVE_WORDS[a])
		"occlusion":
			return "+%d" % _tile_db(a) if _drill else String(MaskDeck.COUNT_WORDS[a])
	return String(MaskDeck.WHO_WORDS[a])


func _verdict(a: StringName) -> String:
	if station_id == "occlusion":
		return ("Add it: +%d" % MaskDeck.boom(_card)) if a == &"add" else "Not this time: +0"
	return String((MaskDeck.CALL_VERDICTS if station_id == "when" else MaskDeck.WHO_VERDICTS)[a])


func _tries() -> Array:
	match station_id:
		"when":
			return MaskDeck.WHEN_TRIES
		"start":
			return MaskDeck.START_TRIES
		"plateau":
			return MaskDeck.WALK_TRIES
		"occlusion":
			return MaskDeck.PLUG_TRIES
	return MaskDeck.WHY_TRIES


func _deal() -> Array[Dictionary]:
	match station_id:
		"when":
			return MaskDeck.when_round(rng)
		"start":
			return MaskDeck.start_round(rng)
		"plateau":
			return MaskDeck.walk_round(rng)
		"occlusion":
			var cards := MaskDeck.count_round(rng)
			cards.append({"drill": true})
			return cards
	return MaskDeck.who_heard_round(rng)


func _right_answer(card: Dictionary) -> StringName:
	match station_id:
		"when":
			return MaskDeck.mask_call(card)
		"occlusion":
			return MaskDeck.count_answer(card)
	return MaskDeck.who_heard(card)


# ---------------------------------------------------------------- try it

func _try_it() -> void:
	_set_top("Try it")
	var tries := _tries()
	for i in tries.size():
		var tr: Dictionary = (tries[i] as Dictionary).duplicate()
		match station_id:
			"when":
				tr["step"] = 0
			"start":
				tr["dial"] = int(tr["other_air"])
				tr["target"] = MaskDeck.start_level(tr)
			"plateau":
				tr["records"] = MaskDeck.walk_first(tr)
				tr["moves"] = 0
			"occlusion":
				tr["cur_cover"] = String(tr["start_cover"])
				tr["cur_freq"] = int(tr["start_freq"])
		_card = tr
		_show_card(tr, false, true)
		_say(String(tr["line"]))
		_try_buttons()
		_feedback_text(_try_status())
		_state = &"try"
		var mouse := {"click": _try_click()}
		if station_id == "occlusion":
			mouse["then"] = MaskDeck.oe_freq_word(int(tr["freq"]))
		Events.awaiting_input.emit(&"training_try", {"station": station_id, "step": i, "target": _try_target(),
			"mouse": mouse}, _solve_try)
		await _go
		Events.input_resolved.emit(&"training_try")
		if _leaving:
			return


## What Try it is waiting for: the beep that reaches Lefty, both checks done, or Hoot's dial level.
func _try_target() -> int:
	match station_id:
		"when":
			return 2
		"start":
			return MaskDeck.start_level(_card)
		"plateau":
			return int(MaskDeck.walk_textbook(_card)["moves"])
		"occlusion":
			return 1
	return MaskDeck.try_target(_card)


## The live Try it value the target is matched against (the tests and the bot read it).
func try_value() -> int:
	match station_id:
		"when":
			return int(_card.get("step", 0))
		"start":
			return int(_card.get("dial", 0))
		"plateau":
			return int(_card.get("moves", 0))
		"occlusion":
			return 1 if _plug_matched() else 0
	return int(_card.get("tone", 0))


func _try_click() -> String:
	match station_id:
		"when":
			return "Check it"
		"start":
			return "Shhh up +5"
		"plateau":
			return "Next step"
		"occlusion":
			return String(MaskDeck.COVER_WORDS[String(_card["cover"])])
	return "Louder +5"


## One Try it step: the beep up (+1) or down (-1), the next check (station 2), or the dial (station 3).
func try_step(dir: int) -> void:
	if _state != &"try":
		return
	match station_id:
		"when":
			_try_check(dir)
		"start":
			_try_dial(dir)
		"plateau":
			_try_walk(dir)
		"occlusion":
			# one step toward Hoot's setting: the cover first, then the pitch
			if String(_card["cur_cover"]) != String(_card["cover"]):
				plug_cover(String(_card["cover"]))
			else:
				var i := MaskDeck.OE_FREQS.find(int(_card["cur_freq"]))
				var j := MaskDeck.OE_FREQS.find(int(_card["freq"]))
				plug_freq(MaskDeck.OE_FREQS[i + signi(j - i)])
		_:
			_try_beep(dir)


func _try_beep(dir: int) -> void:
	var tone := clampi(int(_card["tone"]) + dir * MaskDeck.TRY_STEP_DB, 0, MaskDeck.try_max(_card))
	if tone == int(_card["tone"]):
		return
	_card["tone"] = tone
	Sfx.play(&"blip", 1.0 + tone / 200.0, -10.0)
	_stage.params["tone"] = tone
	_feedback_text(_try_status())
	if MaskDeck.other_hears(_card):
		_stage.params["boo_at"] = _stage_t
		Sfx.play(&"boing", 1.1, -8.0)
		_try_done()
	else:
		_say(String(_card["line"]))


func _try_check(dir: int) -> void:
	if dir <= 0:
		return
	_card["step"] = int(_card["step"]) + 1
	Sfx.play(&"pop", 1.0 + 0.1 * int(_card["step"]), -8.0)
	_stage.params["show_bone"] = true
	_feedback_text(_try_status())
	if int(_card["step"]) == 1:
		var g := MaskDeck.gap(_card)
		_say("Gap %d. %s Now the air check." % [g, "10 or more: mask bone!" if MaskDeck.mask_bone(_card) else "Under 10: bone is fine."])
		return
	_stage.params["show_air"] = true
	_stage.params["verdict"] = _verdict(MaskDeck.mask_call(_card))
	_stage.params["verdict_at"] = _stage_t
	Sfx.play(&"ding", 1.1, -8.0)
	_try_done()


func _try_dial(dir: int) -> void:
	var dial := clampi(int(_card["dial"]) + dir * MaskDeck.DIAL_STEP_DB, ClinicRules.MASK_MIN_DB, ClinicRules.MASK_MAX_DB)
	if dial == int(_card["dial"]):
		return
	_card["dial"] = dial
	Sfx.play(&"blip", 0.8 + dial / 250.0, -12.0)
	_stage.params["dial"] = dial
	_feedback_text(_try_status())
	if dial == int(_card["target"]):
		_stage.params["reveal"] = true
		_stage.params["verdict_at"] = _stage_t
		Sfx.play(&"ding", 1.1, -8.0)
		_try_done()


## Hoot plays the textbook move for the next presentation, naming it.
func _try_walk(dir: int) -> void:
	if dir <= 0:
		return
	var records: Array = _card["records"]
	var m := MaskDeck.walk_move(_card, records)
	_card["moves"] = int(_card["moves"]) + 1
	if m == &"store" or m == &"nosafe":
		_walk_reveal()
		Sfx.play(&"ding", 1.1, -8.0)
		_try_done()
		return
	MaskDeck.walk_apply(_card, records, m)
	_walk_step_shown()
	var heard := bool((records.back() as Dictionary)["responded"])
	_say("%s %s" % ["Heard, so shhh up 5." if m == &"shhh" else "Missed, so beep up 5.", "Heard again!" if heard else "No answer now."])


## The plug lab: put a cover on (OPEN, HEADPHONE, DEEP INSERT).
func plug_cover(c: String) -> void:
	if _state != &"try" or station_id != "occlusion" or c == String(_card["cur_cover"]):
		return
	_card["cur_cover"] = c
	Sfx.play(&"pop", 1.0, -10.0)
	_plug_changed()


## The plug lab: pick a pitch.
func plug_freq(f: int) -> void:
	if _state != &"try" or station_id != "occlusion" or f == int(_card["cur_freq"]):
		return
	_card["cur_freq"] = f
	Sfx.play(&"blip", 0.8 + MaskDeck.OE_FREQS.find(f) * 0.1, -12.0)
	_plug_changed()


func plug_freq_step(dir: int) -> void:
	var i := MaskDeck.OE_FREQS.find(int(_card["cur_freq"]))
	plug_freq(MaskDeck.OE_FREQS[clampi(i + dir, 0, MaskDeck.OE_FREQS.size() - 1)])


func _plug_matched() -> bool:
	return String(_card.get("cur_cover", "")) == String(_card.get("cover", "-")) and int(_card.get("cur_freq", -1)) == int(_card.get("freq", -2))


func _plug_changed() -> void:
	_stage.params["cover"] = String(_card["cur_cover"])
	_stage.params["freq"] = int(_card["cur_freq"])
	_feedback_text(_try_status())
	if _plug_matched():
		Sfx.play(&"ding", 1.1, -8.0)
		_try_done()


func _try_done() -> void:
	_state = &"try_done"
	_say(_try_payoff())
	for b in _answers.find_children("*", "Button", true, false):
		(b as Button).disabled = true
	_show_next("Next")


func _try_status() -> String:
	match station_id:
		"when":
			var lines := MaskDeck.when_lines(_card)
			match int(_card["step"]):
				0:
					return "Righty's air %d, bone %d. %s: the wall is %d." % [int(_card["air"]), int(_card["bone"]),
						MaskDeck.TRANSDUCER_WORDS[String(_card["transducer"])], MaskDeck.wall(String(_card["transducer"]))]
				1:
					return lines[0]
			return "%s\n%s" % [lines[0], lines[1]]
		"start":
			return "Shhh at %d dB. Hoot's level: %d. Up or down 5 at a time." % [int(_card["dial"]), int(_card["target"])]
		"plateau":
			return _walk_status()
		"occlusion":
			var b := MaskDeck.oe_boost(String(_card["cur_cover"]), int(_card["cur_freq"]))
			return "%s at %s Hz: bone tones get %s." % [String(MaskDeck.COVER_WORDS[String(_card["cur_cover"])]).capitalize(),
				MaskDeck.oe_freq_word(int(_card["cur_freq"])), "+%d dB louder" % b if b > 0 else "no louder"]
	var w := MaskDeck.wall(String(_card["transducer"]))
	var tone := int(_card["tone"])
	if w == 0:
		return "Beep %d. Bone has no wall: Lefty gets all %d. Lefty hears from %d." % [tone, tone, int(_card["other_thr"])]
	return "Beep %d. Through the wall: %d - %d = %d. Lefty hears from %d." % [tone, tone, w, tone - w, int(_card["other_thr"])]


func _try_payoff() -> String:
	match station_id:
		"when":
			match MaskDeck.mask_call(_card):
				&"both":
					return "Air crosses too. Big gap, thin wall: mask both!"
				&"bone":
					if String(_card["transducer"]) == "inserts":
						return "The thicker insert wall saved the air test. Mask bone only."
					return "Mask bone only. Air can't reach."
			return "No gap, no crossing. No masking. Easy!"
		"start":
			if MaskDeck.boom(_card) > 0:
				return "Spot on! The orange slice is the occlusion boom."
			if MaskDeck.is_bone_test(_card):
				return "Spot on! Inserts sit deep: no boom, no orange slice."
			return "Spot on! Air test: Lefty's air plus 10, nothing more."
		"plateau":
			return "The beep chased the shhh, then held flat for 15. That's the plateau!"
		"occlusion":
			if String(_card["cover"]) == "insert":
				return "Plus 0. A deep insert leaves no air to boom."
			if int(_card["freq"]) >= 2000:
				return "Nothing at 2k. High pitches don't boom."
			return "Plus 15! A covered normal ear booms at the low pitches."
	var tone := int(_card["tone"])
	var w := MaskDeck.wall(String(_card["transducer"]))
	match String(_card["transducer"]):
		"inserts":
			return "BOO at %d! The thicker wall (%d) held longer. Inserts mean fewer Ghosts." % [tone, w]
		"bone":
			return "BOO at just %d! Bone shakes the whole skull: no wall at all." % tone
	return "BOO at %d! %d - %d = %d: Lefty heard it. That's cross-hearing." % [tone, tone, w, tone - w]


func _solve_try() -> void:
	for i in 40:
		if _state != &"try":
			break
		try_step(1)
	press_next()


# ---------------------------------------------------------------- the round

func _round() -> void:
	strokes.clear()
	var cards := _deal()
	for h in cards.size():
		_card = cards[h]
		_hole_strokes = 1
		_hinted = false
		_picked.clear()
		_set_top("Hole %d of %d" % [h + 1, cards.size()])
		_show_card(_card, false, false)
		if _is_walk():
			if not await _walk_hole(h):
				return
		elif _card.has("drill"):
			if not await _drill_hole(h):
				return
		elif _is_dial():
			_card["dial"] = int(_card["other_air"])
			_stage.params["dial"] = int(_card["dial"])
			_say("Masking on Lefty. Turn the shhh to the start level, then Set it.")
			_feedback_text(_dial_status())
			_dial_buttons()
			_state = &"dial"
			var best := MaskDeck.start_level(_card)
			Events.awaiting_input.emit(&"training_card", {"station": station_id, "hole": h, "best": best, "start": int(_card["dial"]),
				"options": [], "mouse": {"click": "Set it"}}, _solve_dial.bind(best))
		else:
			_answer = _right_answer(_card)
			if station_id == "occlusion":
				_say("Does the occlusion add-on count here? Check all four things.")
				_feedback_text("The masker covers this ear. Bone or air? Which pitch? Normal ear? Headphone or insert?")
			elif station_id == "when":
				_say("Righty is tested. Which tests need masking? Pick one.")
				_feedback_text("%s at %d Hz. Gap check first, then the air check." % [MaskDeck.TRANSDUCER_WORDS[String(_card["transducer"])], int(_card["freq"])])
			else:
				_say("Who could answer this beep? Pick one.")
				_feedback_text("%s on the right ear. Read the numbers, then pick." % MaskDeck.TRANSDUCER_WORDS[String(_card["transducer"])])
			_answer_buttons()
			_state = &"card"
			var opts := _options()
			Events.awaiting_input.emit(&"training_card", {"station": station_id, "hole": h, "best": opts.find(_answer),
				"options": opts.map(func(a: StringName) -> String: return _word(a)),
				"mouse": {"click": _word(_answer)}}, func() -> void: pick(_answer))
		if not _is_walk() and not _card.has("drill"):
			await _go
			Events.input_resolved.emit(&"training_card")
		if _leaving:
			return
		strokes.append(_hole_strokes)
		_update_score()
		_state = &"next"
		_show_next("Next hole" if h < cards.size() - 1 else "Scorecard")
		Events.awaiting_input.emit(&"training_next", {"station": station_id, "hole": h, "mouse": {"click": _next_btn.text}}, press_next)
		await _go
		Events.input_resolved.emit(&"training_next")
		if _leaving:
			return


## One plateau walk: a beat per move until STORE IT or NO SAFE LEVEL. Returns false when the player left.
func _walk_hole(h: int) -> bool:
	_card["records"] = MaskDeck.walk_first(_card)
	_stage.params["records"] = _card["records"]
	_say("Masking's on at the start level. Watch the hand, then pick a move.")
	var step := 0
	while true:
		_walk_step_shown()
		_answer = MaskDeck.walk_move(_card, _card["records"])
		_picked.clear()
		_answer_buttons()
		_state = &"card"
		var opts := _options()
		Events.awaiting_input.emit(&"training_card", {"station": station_id, "hole": h, "step": step, "best": opts.find(_answer),
			"options": opts.map(func(a: StringName) -> String: return _word(a)),
			"mouse": {"click": _word(_answer)}}, func() -> void: pick(_answer))
		var what: StringName = await _go
		Events.input_resolved.emit(&"training_card")
		if _leaving:
			return false
		if what == &"right":
			return true
		step += 1
	return true


func _walk_step_shown() -> void:
	_stage.params["records"] = _card["records"]
	_stage.params["step_at"] = _stage_t
	_feedback_text(_walk_status())


func _walk_status() -> String:
	var last: Dictionary = (_card["records"] as Array).back()
	var run := ClinicRules.plateau_run(_card["records"])
	var held := ""
	if bool(last["responded"]) and int(run["steps"]) > 0:
		held = " Held through %d raise%s." % [int(run["steps"]), "" if int(run["steps"]) == 1 else "s"]
	return "Beep %d, shhh %d: %s%s" % [int(last["db"]), int(last["mask_db"]), "HEARD." if bool(last["responded"]) else "no answer.", held]


## The walk is over: the board shows the plateau (or the shut window) and the lines say why.
func _walk_reveal() -> void:
	_stage.params["reveal"] = true
	var dilemma := MaskDeck.walk_dilemma(_card)
	_stage.params["verdict"] = "No safe level: store nothing" if dilemma else "Masked bone: %d dB" % int(_card["t_test"])
	_stage.params["verdict_at"] = _stage_t
	var lines := MaskDeck.walk_lines(_card)
	_feedback_text("%s\n%s" % [lines[0], lines[1]])


## A move in the walk: right moves play on (or end the walk), wrong ones cost a stroke.
func _walk_pick(a: StringName) -> void:
	_picked[a] = true
	if a != _answer:
		_hole_strokes += 1
		Sfx.play(&"error", 1.0, -10.0)
		_say(MaskDeck.walk_nudge(_answer))
		for b: Button in _answer_list():
			if StringName(String(b.get_meta("answer", ""))) == a:
				b.disabled = true
				b.text = "Not this one"
				Juice.shake(b, 5.0, 0.25)
		return
	_state = &"busy"
	if a == &"store" or a == &"nosafe":
		Sfx.play(&"ding", 1.1, -6.0)
		_walk_reveal()
		_say(_hole_line())
		for b: Button in _answer_list():
			b.disabled = true
		if _hint_btn != null:
			_hint_btn.disabled = true
		_go.emit(&"right")
		return
	Sfx.play(&"blip", 1.0 if a == &"beep" else 0.8, -10.0)
	MaskDeck.walk_apply(_card, _card["records"], a)
	_go.emit(&"step")


## The pocket card (station 5's last hole): a beat per blank cell; the card earns its star only when
## filled from blank (later visits start with fewer helper cells). Returns false when the player left.
func _drill_hole(h: int) -> bool:
	var plays := int(TrainingProgress.station(MaskDeck.LESSON, station_id)["plays"])
	var blanks := MaskDeck.oe_blanks(rng, MaskDeck.oe_prefilled(plays))
	_blank_count = blanks.size()
	_cells.clear()
	for row: String in MaskDeck.OE_ROWS:
		for f: int in MaskDeck.OE_FREQS:
			_cells["%s|%d" % [row, f]] = MaskDeck.oe_cell(row, f)
	for c: Dictionary in blanks:
		_cells.erase("%s|%d" % [String(c["row"]), int(c["freq"])])
	_drill = true
	_hinted = false
	_stage_t = 0.0
	_stage.show_scene({"id": "pocket", "set": "pocket_card", "duration": 9999.0, "params": {"cells": _cells, "focus": {}}})
	if _blank_count < MaskDeck.OE_FREQS.size() * MaskDeck.OE_ROWS.size():
		_say("Fill the blanks from memory. Next visit, fewer helpers!")
	else:
		_say("A blank card! Fill every cell from memory.")
	for step in blanks.size():
		_card = {"drill": true, "row": String(blanks[step]["row"]), "freq": int(blanks[step]["freq"])}
		_answer = TILES[MaskDeck.OE_TILES.find(MaskDeck.oe_cell(String(_card["row"]), int(_card["freq"])))]
		_stage.params["focus"] = {"row": _card["row"], "freq": _card["freq"]}
		_stage.params["bounce"] = -1
		_feedback_text("%s at %s Hz: how much louder? Pick a tile." % ["Headphone" if _card["row"] == "phones" else "Insert", MaskDeck.oe_freq_word(int(_card["freq"]))])
		_picked.clear()
		_answer_buttons()
		_state = &"card"
		Events.awaiting_input.emit(&"training_card", {"station": station_id, "hole": h, "step": step, "best": TILES.find(_answer),
			"options": TILES.map(func(a: StringName) -> String: return _word(a)), "mouse": {"click": _word(_answer)}},
			func() -> void: pick(_answer))
		await _go
		Events.input_resolved.emit(&"training_card")
		if _leaving:
			_drill = false
			return false
	_drill = false
	_stage.params["focus"] = {}
	_feedback_text("Pocket card complete! 250 +15, 500 +15, 750 +10, 1k +10, 2k up 0. Inserts 0.")
	_say("Pocket card complete! Fifteen, fifteen, ten, ten, then nothing. You've got it.")
	_clear_answers()
	return true


func _drill_pick(a: StringName) -> void:
	_picked[a] = true
	if a != _answer:
		_hole_strokes += 1
		Sfx.play(&"boing", 1.0, -10.0)
		_stage.params["bounce"] = _tile_db(a)
		_stage.params["bounce_at"] = _stage_t
		_say(MaskDeck.oe_reason(String(_card["row"]), int(_card["freq"])))
		for b: Button in _answer_list():
			if StringName(String(b.get_meta("answer", ""))) == a:
				b.disabled = true
				Juice.shake(b, 5.0, 0.25)
		return
	_state = &"busy"
	Sfx.play(&"ding", 1.2, -8.0)
	_cells["%s|%d" % [String(_card["row"]), int(_card["freq"])]] = _tile_db(a)
	_stage.params["cells"] = _cells
	_go.emit(&"right")


## Answer the live card (keys 1-4, a click or the solver).
func pick(a: StringName) -> void:
	if _state != &"card" or _picked.has(a):
		return
	if _is_walk():
		_walk_pick(a)
		return
	if _drill:
		_drill_pick(a)
		return
	_picked[a] = true
	if a == _answer:
		_state = &"busy"
		Sfx.play(&"ding", 1.1, -6.0)
		var lines: Array[String] = []
		if station_id == "occlusion":
			_stage.params["reveal"] = true
			lines = [MaskDeck.boom_line(_card), "Pocket card: only bone, only a covered NORMAL ear, only low pitches."]
		elif station_id == "when":
			_stage.params["show_bone"] = true
			_stage.params["show_air"] = true
			lines = MaskDeck.when_lines(_card)
		else:
			_stage.params["reveal"] = true
			if _answer == &"ghost":
				_stage.params["boo_at"] = _stage_t
			lines = MaskDeck.why_lines(_card)
		_stage.params["verdict"] = _verdict(_answer)
		_stage.params["verdict_at"] = _stage_t
		_feedback_text("%s\n%s" % [lines[0], lines[1]])
		_say(_hole_line())
		for b: Button in _answer_list():
			b.disabled = true
			if StringName(String(b.get_meta("answer", ""))) == a:
				b.disabled = false
				b.modulate = Color(1, 1, 1)
				b.text = "  " + _word(a) + "  "
		_go.emit(&"right")
		return
	_hole_strokes += 1
	Sfx.play(&"error", 1.0, -10.0)
	if station_id == "occlusion":
		_say("Not quite. Bone, low pitch, normal ear, headphone: it needs all four.")
	elif station_id == "when":
		_say("Not quite. Gap check first, then air minus the wall.")
	else:
		_say("Not quite. Check both numbers: the test ear's, and what crosses the wall.")
	for b: Button in _answer_list():
		if StringName(String(b.get_meta("answer", ""))) == a:
			b.disabled = true
			b.text = "Not quite"
			Juice.shake(b, 5.0, 0.25)


## Turn the noise dial one step (station 3's round).
func nudge(dir: int) -> void:
	if _state != &"dial":
		return
	var dial := clampi(int(_card["dial"]) + dir * MaskDeck.DIAL_STEP_DB, ClinicRules.MASK_MIN_DB, ClinicRules.MASK_MAX_DB)
	if dial == int(_card["dial"]):
		return
	_card["dial"] = dial
	Sfx.play(&"blip", 0.8 + dial / 250.0, -12.0)
	_stage.params["dial"] = dial
	_feedback_text(_dial_status())


## Lock the dial in: on the dot is par, one step off a bogey, more a double bogey.
func set_dial() -> void:
	if _state != &"dial":
		return
	_state = &"busy"
	var want := MaskDeck.start_level(_card)
	var dial := int(_card["dial"])
	_hole_strokes += MaskDeck.dial_strokes(dial, _card) - 1
	Sfx.play(&"ding" if dial == want else &"error", 1.1, -6.0 if dial == want else -10.0)
	_stage.params["reveal"] = true
	_stage.params["verdict"] = ("Spot on: %d!" % want) if dial == want else ("You set %d. Start at %d." % [dial, want])
	_stage.params["verdict_at"] = _stage_t
	var lines := MaskDeck.start_lines(_card)
	_feedback_text("%s\n%s" % [lines[0], lines[1]])
	_say(_hole_line() if dial == want else ("Close: one step off. A bogey." if absi(dial - want) <= MaskDeck.DIAL_STEP_DB
		else "Read the sum on the dial: air, plus 10, plus any boom."))
	for b: Button in _answer_list():
		b.disabled = true
	if _hint_btn != null:
		_hint_btn.disabled = true
	_go.emit(&"right")


func _solve_dial(best: int) -> void:
	for i in 40:
		if _state != &"dial" or int(_card["dial"]) == best:
			break
		nudge(1 if best > int(_card["dial"]) else -1)
	set_dial()


func _dial_status() -> String:
	return "Shhh at %d dB. Test: Righty's %s at %d Hz." % [int(_card["dial"]), "bone" if MaskDeck.is_bone_test(_card) else "air", int(_card["freq"])]


func hint() -> void:
	if _state not in [&"card", &"dial"] or _hinted:
		return
	_hinted = true
	_hole_strokes += 1
	Sfx.play(&"pop", 1.0, -8.0)
	match station_id:
		"when":
			_say(MaskDeck.when_hint(_card))
		"start":
			_say(MaskDeck.start_hint(_card))
		"plateau":
			_say(MaskDeck.walk_hint(_card))
		"occlusion":
			_say(MaskDeck.oe_reason(String(_card["row"]), int(_card["freq"])) if _drill else MaskDeck.count_hint(_card))
		_:
			_say(MaskDeck.hint_line(_card))
	_hint_btn.disabled = true


func _hole_line() -> String:
	match _hole_strokes:
		1:
			return "Spot on! Par."
		2:
			return "Got there. A bogey: one extra stroke."
	return "Got it in the end. Read both numbers first next time."


func press_next() -> void:
	if _state in [&"next", &"try_done"]:
		_state = &"busy"
		Sfx.play(&"click")
		_go.emit(&"next")


# ---------------------------------------------------------------- the scorecard

func _scorecard() -> void:
	var total := 0
	for s: int in strokes:
		total += s
	var over := total - strokes.size()
	var star_ok := _star_ok()
	var star := over == 0 and star_ok
	var rec := TrainingProgress.record_round(MaskDeck.LESSON, station_id, over, String(info["card"]), star_ok)
	last_result = {"station": station_id, "strokes": strokes.duplicate(), "over_par": over, "star": star,
		"new_card": bool(rec["new_card"]), "best": int(rec["best"]), "star_ok": star_ok}
	print("TRAINING_RESULT %s" % JSON.stringify(last_result))
	_state = &"score"
	_show_overlay(_score_panel(over, rec))
	if star:
		Sfx.play(&"fanfare", 1.0, -8.0)
		_say(_star_line())
	elif over == 0:
		Sfx.play(&"ding", 1.2, -8.0)
		_say("Even par! The star needs a blank pocket card: next visit has fewer helpers.")
	else:
		_say("%s. Play again for the star, or head back to the room." % MaskDeck.round_name(over))
	Events.awaiting_input.emit(&"training_scorecard", {"station": station_id, "over_par": over, "star": star,
		"mouse": {"click": "Back to the Training room"}}, leave)
	var what: StringName = await _go
	Events.input_resolved.emit(&"training_scorecard")
	if what == &"again":
		_hide_overlay()
		await _round()
		if not _leaving:
			await _scorecard()


## Station 5's star needs the pocket card filled from blank; the others only need par.
func _star_ok() -> bool:
	return station_id != "occlusion" or _blank_count >= MaskDeck.OE_FREQS.size() * MaskDeck.OE_ROWS.size()


func _star_line() -> String:
	match station_id:
		"when":
			return "Even par! You spotted every risk. That's a star."
		"start":
			return "Even par! Every dial spot on. That's a star."
		"plateau":
			return "Even par! Every walk textbook. That's a star."
		"occlusion":
			return "Even par, from a blank card! That's a star."
	return "Even par! You caught every Ghost. That's a star."


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
	var handled := true
	if code == KEY_T:
		leave()
	elif _state == &"card" and code >= KEY_1 and code < KEY_1 + _options().size():
		pick(_options()[code - KEY_1])
	elif _state == &"card" and code >= KEY_KP_1 and code < KEY_KP_1 + _options().size():
		pick(_options()[code - KEY_KP_1])
	elif _state in [&"card", &"dial"] and code == KEY_H:
		hint()
	elif _state == &"try" and station_id == "occlusion" and code >= KEY_1 and code < KEY_1 + MaskDeck.COVERS.size():
		plug_cover(MaskDeck.COVERS[code - KEY_1])
	elif _state == &"try" and station_id == "occlusion" and event.is_action_pressed(&"ui_right"):
		plug_freq_step(1)
	elif _state == &"try" and station_id == "occlusion" and event.is_action_pressed(&"ui_left"):
		plug_freq_step(-1)
	elif _state == &"try" and event.is_action_pressed(&"louder"):
		try_step(1)
	elif _state == &"try" and event.is_action_pressed(&"softer"):
		try_step(-1)
	elif _state == &"dial" and event.is_action_pressed(&"louder"):
		nudge(1)
	elif _state == &"dial" and event.is_action_pressed(&"softer"):
		nudge(-1)
	elif _state == &"score" and code == KEY_R:
		play_again()
	elif event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"advance_dialogue"):
		match _state:
			&"intro":
				start()
			&"try":
				if station_id in ["when", "plateau"]:
					try_step(1)
				else:
					handled = false
			&"dial":
				set_dial()
			&"next", &"try_done":
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
	var chip_l := UiKit.label("MASKING SCHOOL  %d: %s" % [int(info["num"]), String(info["name"])], 22, Palette.PAPER, 700)
	chip.add_child(chip_l)
	_field.add_child(chip)
	_top_label = UiKit.label("", 22, Palette.INK, 700)
	_top_label.position = Vector2(496, 26)
	_field.add_child(_top_label)
	_score_label = UiKit.label("", 20, Palette.INK_SOFT, 600)
	_score_label.position = Vector2(660, 28)
	_field.add_child(_score_label)
	_leave_btn = UiKit.button("Back to the room", &"", Vector2(232, 48))
	_leave_btn.position = Vector2(FIELD.x - 88 - 232, 14)   # clear of the pause button in the corner
	_leave_btn.add_theme_font_size_override("font_size", 20)
	_leave_btn.pressed.connect(leave)
	_field.add_child(_leave_btn)
	# the stage
	_stage = Stage2D.new()
	_stage.size = Vector2(880, 440)
	_stage.position = STAGE_AT
	_stage.use_movie({"stage": SETS_PATH})
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
	_feedback_panel = UiKit.panel(Palette.PAPER, Palette.INK, 18)
	_feedback_panel.position = Vector2(24, 540)
	_feedback_panel.custom_minimum_size = Vector2(880, 120)
	_feedback_panel.size = Vector2(880, 120)
	_feedback = UiKit.label("", 20, Palette.INK, 600)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_panel.add_child(_feedback)
	_field.add_child(_feedback_panel)
	if UiKit.show_key_hints():
		var keys: Array = [["1", "2", "3"], "answer", ["H"], "hint", ["Enter"], "next", ["T"], "room", ["Esc"], "pause"]
		if station_id == "occlusion":
			keys = [["1", "2", "3"], "answer / cover", ["Left", "Right"], "pitch", ["H"], "hint", ["Enter"], "next", ["T"], "room", ["Esc"], "pause"]
		elif _is_walk():
			keys = [["1", "2", "3", "4"], "move", ["H"], "hint", ["Enter"], "next", ["T"], "room", ["Esc"], "pause"]
		elif _is_dial():
			keys = [[Game.key_label(&"louder"), Game.key_label(&"softer")], "dial", ["Enter"], "set it / next", ["H"], "hint", ["T"], "room", ["Esc"], "pause"]
		var hr := UiKit.hint_row(keys, 16)
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
	_update_score()


func _update_score() -> void:
	if strokes.is_empty():
		_score_label.text = ""
		return
	var total := 0
	for s: int in strokes:
		total += s
	_score_label.text = "Strokes %d (%s)" % [total, MaskDeck.round_name(total - strokes.size())]


func _feedback_text(text: String) -> void:
	_feedback.text = text


func _show_card(card: Dictionary, reveal: bool, live: bool) -> void:
	_stage_t = 0.0
	var p := card.duplicate()
	p["reveal"] = reveal
	p["live"] = live
	p["boo_at"] = -1.0
	p["verdict"] = ""
	p["show_bone"] = false
	p["show_air"] = false
	p["target"] = int(card.get("target", -1))
	var set_id := {"when": "when_card", "start": "start_dial", "plateau": "plateau_walk",
		"occlusion": "pe_ear" if live else "oe_count"}.get(station_id, "who_heard") as String
	if station_id == "occlusion" and live:
		p["cover"] = String(card.get("cur_cover", "open"))
		p["freq"] = int(card.get("cur_freq", 250))
	_stage.show_scene({"id": station_id, "set": set_id, "duration": 9999.0, "params": p})


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
	var opts := _options()
	for i in opts.size():
		var a: StringName = opts[i]
		var b := _side_button(_word(a), str(i + 1), Vector2(SIDE_W, 56 if opts.size() > 3 else 64))
		b.set_meta("answer", String(a))
		b.pressed.connect(pick.bind(a))
		_answers.add_child(b)
	_hint_btn = _side_button("Hoot's hint (+1)", "H", Vector2(SIDE_W, 50))
	_hint_btn.disabled = _hinted
	_hint_btn.pressed.connect(hint)
	_answers.add_child(_hint_btn)


func _try_buttons() -> void:
	_clear_answers()
	if station_id == "occlusion":
		for i in MaskDeck.COVERS.size():
			var c: String = MaskDeck.COVERS[i]
			var b := _side_button(String(MaskDeck.COVER_WORDS[c]), str(i + 1), Vector2(SIDE_W, 54))
			b.pressed.connect(plug_cover.bind(c))
			_answers.add_child(b)
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		for f: int in MaskDeck.OE_FREQS:
			var fb := UiKit.button(MaskDeck.oe_freq_word(f), &"", Vector2((SIDE_W - 16) / 3.0, 50))
			fb.add_theme_font_size_override("font_size", 20)
			fb.pressed.connect(plug_freq.bind(f))
			grid.add_child(fb)
		_answers.add_child(grid)
		return
	if station_id in ["when", "plateau"]:
		var check := _side_button(_try_click(), "Enter")
		check.pressed.connect(try_step.bind(1))
		_answers.add_child(check)
		return
	var up := _side_button(_try_click(), Game.key_label(&"louder"))
	up.pressed.connect(try_step.bind(1))
	_answers.add_child(up)
	var down := _side_button("Shhh down -5" if _is_dial() else "Softer -5", Game.key_label(&"softer"), Vector2(SIDE_W, 54))
	down.pressed.connect(try_step.bind(-1))
	_answers.add_child(down)


func _dial_buttons() -> void:
	_clear_answers()
	var up := _side_button("Shhh up +5", Game.key_label(&"louder"))
	up.set_meta("answer", "up")
	up.pressed.connect(nudge.bind(1))
	_answers.add_child(up)
	var down := _side_button("Shhh down -5", Game.key_label(&"softer"), Vector2(SIDE_W, 54))
	down.set_meta("answer", "down")
	down.pressed.connect(nudge.bind(-1))
	_answers.add_child(down)
	var set_btn := _side_button("Set it", "Enter")
	set_btn.set_meta("answer", "set")
	set_btn.pressed.connect(set_dial)
	_answers.add_child(set_btn)
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
	b.add_theme_font_size_override("font_size", 20)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	p.custom_minimum_size = Vector2(720, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var light := (info["color"] as Color).get_luminance() > 0.55
	var ink: Color = Palette.INK if light else Palette.PAPER
	var accent: Color = Palette.INK if light else Palette.SUNNY
	var num := UiKit.label("STATION %d" % int(info["num"]), 20, accent, 700)
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
	lines.custom_minimum_size = Vector2(540, 0)
	bh.add_child(lines)
	v.add_child(body)
	var card := MaskDeck.cheat_card(String(info["card"]))
	if not card.is_empty():
		var earn := UiKit.label("You'll earn: the %s card" % String(card["title"]), 20, accent, 700)
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
		var note := UiKit.label("First time here: Hoot's movie plays after Start (Esc skips it).", 17, Color(ink, 0.85), 600)
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
		hp.custom_minimum_size = Vector2(118 if strokes.size() <= 6 else 100, 0)
		var hv := VBoxContainer.new()
		hp.add_child(hv)
		var n := UiKit.label("Hole %d" % (i + 1), 16, Palette.INK, 600)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hv.add_child(n)
		var g := UiKit.label(MaskDeck.hole_name(s), 18 if s < 3 else 15, Palette.INK, 700)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hv.add_child(g)
		holes.add_child(hp)
	var total := UiKit.label("Round: %s" % MaskDeck.round_name(over), 34, Palette.grade_color("S") if over == 0 else Palette.INK, 700)
	total.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(total)
	var star := Control.new()
	star.custom_minimum_size = Vector2(0, 64)
	star.draw.connect(func() -> void:
		var c := Vector2(star.size.x * 0.5, 32)
		UiDraw.star(star, c + Vector2(0, 3), 30.0, Color(Palette.INK, 0.3))
		UiDraw.star(star, c, 30.0, Palette.SUNNY if bool(rec["star"]) else Color(Palette.INK_SOFT, 0.25))
		var earned := over == 0 and _star_ok()
		var t := "Star earned!" if earned else ("Star kept from before" if bool(rec["star"]) else
			("Par! A blank card earns the star" if over == 0 else "Even par earns the star"))
		star.draw_string(UiKit.font(700), c + Vector2(44, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK))
	v.add_child(star)
	if bool(rec["new_card"]):
		var nc := UiKit.label("New card for your Training room!", 22, Palette.CORAL, 700)
		nc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nc)
		var holder := CenterContainer.new()
		var cc := CheatCard.new(MaskDeck.cheat_card(String(info["card"])), true, 20)
		cc.custom_minimum_size = Vector2(400, 170)
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
