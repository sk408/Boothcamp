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
## isn't braced) is the lesson's one STOP: it costs PracticalDeck.UNSAFE_STROKES, not one. 4 "Too loud?"
## (the seat, the first pitch, the TD routine's rules, two ladder walks: one call per rung of beep pairs,
## the face drawn, nothing loud ever played). 3 "Station A: the tones" (phones, first ear, bone, the masking call,
## a symbol, and booth holes on the real AudiOtron with a practice subject who answers by the rules: the
## player's first stamps, then Hoot's montage). 5 "One good impression" (the steps, one rung at a time with four
## choices each; the dam's size or depth; the syringe tip or the fill; the cure or the way out; two impressions
## to judge). 6 "Delivery day" (the retube, the RIC's wire and dome, three of Gus's first-week questions). 7 "The
## bench" (three aids with a ticket and a find, the whistle, the test box, fix / send / replace). 8 "Exam day"
## (the mock exam: no Try it, Room A then Room B, each opened by a room card; an examiner reads a prompt card
## per task and says nothing else; no hints; points on the score sheet, an unsafe pick a STOP that ends the
## task; the grade, Practical pass and the Booth Camp Practical licence, licence.gd).
## Controls: keys 1-4 answer, H hint (a stroke), Enter / Space go on, R plays again on the scorecard,
## T leaves for the room; Esc pauses, like everywhere. Everything clicks too. Playable with sound off:
## every answer is drawn, and no tone is ever played to test the player.
## Beats (CONTRACTS.md §3.2; solvers go through the same code as a click):
##   practical_intro {station}                                solver: Start
##   explainer (the station's movie, first visit)             solver: skip
##   practical_try {station, step, best, options, mouse}      solver: the right answer, then Next
##   practical_card {station, hole, kind, sub, best, options, unsafe, mouse}  solver: the right answer
##     (a ladder card asks again per rung: sub 0, 1, 2...; so does a guided ladder's practical_try)
##   practical_next {station, hole}                           solver: Next
##     (Exam day's room cards: practical_next {station, hole: -1, room: "A" / "B"})
##   (Exam day's practical_card also carries room, task, points; there is no hint)
##   practical_booth {station, hole, kind, test, ear}         solver: the textbook until Hoot's montage
##   practical_scorecard {station, over_par, star}            solver: back to the room

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const PracticalArt := preload("res://story/training/practical/practical_art.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const CheatCard := preload("res://story/training/cheat_card.gd")
const Licence := preload("res://story/training/practical/licence.gd")
const ROOM_SCENE := "res://story/training/training_room.tscn"
const PLAYER_SCENE := "res://story/explainers/explainer_player.tscn"
const AUDIOMETER_SCENE := "res://ui/audiometer/audiometer_screen.tscn"
const CLINIC_SCENE := "res://world/clinic.tscn"
const Bean := preload("res://world/characters/bean.gd")

const FIELD := Vector2(1280, 720)
const STAGE_AT := Vector2(24, 84)
const STAGE_SIZE := Vector2(880, 440)
const SIDE_X := 924.0
const SIDE_W := 332.0
const BG := Color("#e3f1ee")
const HOLE_COLORS: Array[Color] = [Color("#5bc8a3"), Color("#ffd23f"), Color("#ff6f59"), Color("#8e5cc4")]

## The station the room opens next (a room chip sets it before goto_scene).
static var next_station := "kit"
## The last finished round, for the tests and the bot: {station, strokes, over_par, star, new_card, best};
## Exam day adds points, max, grade, pass, stops, tasks ([{room, task, kind, points, got, stop}]), first_pass.
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
# Station 3's booth: one AudiOtron (and the clinic behind its window) per round, hidden between holes
var _screen: AudiometerScreen
var _clinic: Node3D
var _subject: PatientProfile
# Exam day: who is talking (the examiner in the rooms), each task's points and its STOP
var _speaker := "Hoot"
var _stopped := false
var _got: Array[int] = []
var _stops: Array[bool] = []
var _cards: Array[Dictionary] = []

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
	if not _is_exam():   # the exam has no Try it: it is the test
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
		await _ask(&"practical_try", {"station": station_id, "step": i})
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
	_got.clear()
	_stops.clear()
	var cards := PracticalDeck.deal(station_id, rng)
	if station_id == "tones" and Game.cli.has("subject"):
		cards = PracticalDeck.tone_round(rng, String(Game.cli["subject"]))   # bots and tests: one subject
	_cards = cards
	_update_score()
	var room := ""
	for h in cards.size():
		if _is_exam() and String(cards[h]["room"]) != room:
			room = String(cards[h]["room"])
			await _room_card(room)
			if _leaving:
				return
		if _is_exam():
			_set_top("Room %s: task %d of %d" % [room, int(cards[h]["task"]), (PracticalDeck.EXAM_ROOMS[room] as Array).size()])
		else:
			_set_top("Hole %d of %d" % [h + 1, cards.size()])
		_deal_card(cards[h])
		if _card.has("subject") and _screen != null and not _is_exam():
			_card["chart"] = _chart_marks()
		if String(_card["kind"]) == "booth":
			await _booth_hole(h)
		else:
			var base := {"station": station_id, "hole": h, "kind": String(_card["kind"])}
			if _is_exam():
				_say(String(_card["prompt"]), "Examiner")
				_feedback_text("%s\nWorth %d point%s on the score sheet. No hints in the exam." % [_ask_line(), int(_card["points"]),
					"" if int(_card["points"]) == 1 else "s"])
				base.merge({"room": room, "task": int(_card["task"]), "points": int(_card["points"])})
			else:
				_say(_ask_line())
				_feedback_text(_ask_feedback())
			_answer_buttons()
			_state = &"card"
			await _ask(&"practical_card", base)
		if _leaving:
			return
		strokes.append(_hole_strokes)
		if _is_exam():
			_got.append(PracticalDeck.exam_task_points(int(_card["points"]), _hole_strokes, _stopped))
			_stops.append(_stopped)
		_update_score()
		_state = &"next"
		_show_next(("Next task" if h < cards.size() - 1 else "The score sheet") if _is_exam() else ("Next hole" if h < cards.size() - 1 else "Scorecard"))
		Events.awaiting_input.emit(&"practical_next", {"station": station_id, "hole": h, "mouse": {"click": _next_btn.text}}, press_next)
		await _go
		Events.input_resolved.emit(&"practical_next")
		if _leaving:
			return
	_close_booth()
	_speaker = "Hoot"


## Exam day: the room's card (its tasks, the real room's minutes, no clock here), Hoot waiting outside.
func _room_card(room: String) -> void:
	_close_booth()   # Room A's booth stays in Room A
	_card = {}
	_clear_answers()
	_set_top("")
	_say("No owls in the exam room. You've got this!" if room == "A" else "Room A done! Deep breath. Room B: impressions, fittings, the bench.")
	_feedback_text("")
	_state = &"next"
	_show_overlay(_room_panel(room))
	Events.awaiting_input.emit(&"practical_next", {"station": station_id, "hole": -1, "room": room, "mouse": {"click": "Enter Room %s" % room}}, press_next)
	await _go
	Events.input_resolved.emit(&"practical_next")
	_hide_overlay()


func _room_panel(room: String) -> Control:
	var p := UiKit.panel(info["color"], Palette.INK, 28)
	p.custom_minimum_size = Vector2(760, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := UiKit.label("ROOM %s" % room, 52, Palette.PAPER, 700)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var sub := UiKit.label(("Station A: the tones. %d minutes in the real exam; no clock here." if room == "A"
		else "Station B: hands on. %d minutes in the real exam; no clock here.") % int(PracticalDeck.EXAM_MINUTES[room]), 20, Palette.SUNNY, 700)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	flow.custom_minimum_size = Vector2(700, 0)
	for c: Dictionary in _cards:
		if String(c["room"]) != room:
			continue
		var chip := UiKit.panel(Palette.PAPER, Palette.INK, 12)
		chip.add_child(UiKit.label("%d. %s  (%d)" % [int(c["task"]), PracticalDeck.exam_task_name(c), int(c["points"])], 17, Palette.INK, 700))
		flow.add_child(chip)
	v.add_child(flow)
	var rules := UiKit.label("The examiner reads a prompt card and says nothing else. A miss costs a point; an unsafe move is a STOP: "
		+ "that task ends with its points lost, and the room goes on.", 18, Palette.PAPER, 600)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.custom_minimum_size = Vector2(700, 0)
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(rules)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var go := UiKit.button("Enter Room %s" % room, &"", Vector2(260, 60))
	go.add_theme_font_size_override("font_size", 24)
	go.pressed.connect(press_next)
	row.add_child(go)
	return p


func _is_exam() -> bool:
	return station_id == "exam"


## Emit the live card's beat and wait for its answer. A ladder card ("answers", Station 4) asks once per
## rung: the beat comes again with the next rung's best ("sub" counts the rungs).
func _ask(beat: StringName, base: Dictionary) -> void:
	var sub := 0
	while true:
		var opts: Array = _card["options"]
		var best := int(_card["answer"])
		var data := base.duplicate()
		data.merge({"best": best, "options": opts, "sub": sub, "unsafe": (_card.get("unsafe", []) as Array).duplicate(),
			"mouse": {"click": String(opts[best])}}, true)
		Events.awaiting_input.emit(beat, data, func() -> void: pick(best))
		var what: StringName = await _go
		Events.input_resolved.emit(beat)
		if what != &"step" or _leaving:
			return
		sub += 1


func _deal_card(c: Dictionary) -> void:
	_card = c
	_reveal = false
	_wrong.clear()
	_hole_strokes = 1
	_hinted = false
	_stopped = false
	_stage_t = 0.0


# ---------------------------------------------------------------- Station 3: the booth

## A booth hole: the card, "Into the booth", the real AudiOtron with the practice subject (the player's
## first stamps, then Hoot's montage), then the tally. Strokes: par 1, plus one per technique slip or stamp
## BOOTH_OFF_DB or more off the subject's answer, at most BOOTH_MAX_EXTRA.
func _booth_hole(h: int) -> void:
	var test := String(_card["test"])
	var ear := String(_card["ear"])
	_clear_answers()
	if _is_exam():
		_say("%s Your first %d stamps; the rest is filled for you." % [String(_card["prompt"]), int(_card["stamps"])], "Examiner")
	else:
		_say("%s, %s ear. Your first %d stamp%s: then I'll fill the rest." % [PracticalDeck.TEST_WORDS[test], ear, int(_card["stamps"]),
			"" if int(_card["stamps"]) == 1 else "s"])
	_feedback_text(_booth_feedback(test))
	_state = &"next"
	_show_next("Into the booth")
	Events.awaiting_input.emit(&"practical_next", {"station": station_id, "hole": h, "booth": true, "mouse": {"click": _next_btn.text}}, press_next)
	await _go
	Events.input_resolved.emit(&"practical_next")
	if _leaving:
		return
	_clear_answers()
	_state = &"booth"
	_open_booth(String(_card["subject"]))
	_dress(test, ear)
	var plan := {"test": test, "air_transducer": "phones", "hoot_turn_after": int(_card["stamps"]), "montage_after": true,
		"hoot_turn_text": "Nice! I'll fill in the rest of this ear.", "done_title": "%s DONE!" % String(_card["title"]).to_upper()}
	if test == "bc" or test == "bc_masked":
		plan["bc_freqs"] = ClinicRules.BC_REQUIRED.duplicate()
	if test != "ac":
		plan["masking_controls"] = true
	Events.phase_changed.emit(&"audiometry", {})   # clears Hoot's tips, like the days
	_screen.process_mode = Node.PROCESS_MODE_INHERIT
	_screen.visible = true
	_screen.start_test(_subject, ear, false, plan)
	var errs0 := _screen.session.errors.size()
	Events.awaiting_input.emit(&"practical_booth", {"station": station_id, "hole": h, "kind": "booth", "test": test, "ear": ear}, solve_booth)
	await _screen.test_finished
	Events.input_resolved.emit(&"practical_booth")
	if _leaving or _screen == null:
		return
	_screen.visible = false
	_screen.process_mode = Node.PROCESS_MODE_DISABLED   # hidden between holes: its keys (H, 1-4...) are the card's
	Stage.set_booth_view_active(false)
	Hoot.clear()
	var mine := 0
	var hoots := 0
	var off := 0
	var st: Dictionary = (_screen.session.sheet(StringName(test))["stored"] as Dictionary)[ear]
	for f: int in st:
		var inf: Dictionary = st[f]
		if bool(inf.get("by_hoot", false)):
			hoots += 1
			continue
		mine += 1
		if not bool(inf.get("no_response", false)) and absf(float(inf.get("error_db", 0.0))) >= PracticalDeck.BOOTH_OFF_DB:
			off += 1
	var slips := _screen.session.errors.size() - errs0
	_card.merge({"mine": mine, "hoots": hoots, "off": off, "slips": slips, "chart": _chart_marks()}, true)
	_hole_strokes = 1 + mini(PracticalDeck.BOOTH_MAX_EXTRA, slips + off)
	_reveal = true
	_wrong.clear()
	if _hole_strokes == 1:
		Sfx.play(&"ding", 1.1, -6.0)
	_feedback_text("%s\n%s" % [String(_card["lines"][0]), String(_card["lines"][1]) if _hole_strokes == 1 else
		"%d slip%s, %d stamp%s off: %s%d. The AudiOtron's tips name each one." % [slips, "" if slips == 1 else "s", off, "" if off == 1 else "s",
			"-" if _is_exam() else "+", _hole_strokes - 1]])
	_say(_hole_line(), _speaker)


func _booth_feedback(test: String) -> String:
	match test:
		"ac":
			return "Air: 1 kHz first, down 10 after a yes, up 5 after a no; two yeses going up is the threshold."
		"bc":
			return "Bone on the better ear's mastoid, phones off. Unmasked bone stands for the better cochlea."
		"bc_masked":
			return "Noise in the other ear, then the plateau: heard, noise up 5; missed, tone up 5; three steps that hold."
	return "Masked air: noise in the other ear and the same plateau walk. On the chart: triangle right, square left."


## The AudiOtron and the 3D clinic behind its booth window, made once a round for the round's subject.
func _open_booth(subject_id: String) -> void:
	if _screen != null:
		return
	var s := PracticalDeck.tone_subject(subject_id)
	_subject = PracticalDeck.tone_patient(s)
	Game.begin_visit(_subject.id)
	Game.set_visit_flag("instructed", true)
	if ResourceLoader.exists(CLINIC_SCENE):
		_clinic = (load(CLINIC_SCENE) as PackedScene).instantiate() as Node3D
		_clinic.set("patient_spec", _subject_look(s))
		add_child(_clinic)
		var cam: Camera3D = _clinic.call("get_main_camera") if _clinic.has_method("get_main_camera") else null
		if cam != null:
			cam.current = false
		var c: Variant = _clinic
		c.gus.position = c.SPOTS[&"booth"]   # already in the chair: no walk in from the hallway
		_clinic.call("sit")
	_screen = (load(AUDIOMETER_SCENE) as PackedScene).instantiate() as AudiometerScreen
	add_child(_screen)


## The subject's bean: Grandpa Gus's build in their own colours, no walker.
func _subject_look(s: Dictionary) -> Dictionary:
	var look: Dictionary = Bean.GUS.duplicate()
	var seed := String(s["id"]).hash()
	look["name"] = String(s["name"])
	look["face"] = &"doris" if String(s["pronoun"]) == "she" else &"gus"
	look["walker"] = false
	look["mustache"] = false
	look["glasses"] = &""
	look["cardigan"] = [Color("#3a9d96"), Color("#c77dba"), Color("#f2a541"), Color("#5b7fc7")][posmod(seed, 4)]
	look["hair"] = [Color("#5a3a22"), Color("#c9ccd6"), Color("#2e2442"), Color("#e0a940")][posmod(seed >> 3, 4)]
	look["hair_style"] = &"bun" if String(s["pronoun"]) == "she" else &"quiff"
	return look


## Put the right transducers on the subject in the booth (the window shows it).
func _dress(test: String, ear: String) -> void:
	if _clinic == null:
		return
	match test:
		"ac", "ac_masked":
			_clinic.call("take_off_bone_oscillator")
			_clinic.call("put_on_earphones", true, false)
		"bc":
			_clinic.call("take_off_earphones")
			_clinic.call("put_on_bone_oscillator", ear)
		"bc_masked":
			_clinic.call("take_off_earphones")
			_clinic.call("put_on_bone_oscillator", ear)
			_clinic.call("put_on_masking_phone", PracticalDeck.other_ear(ear), false)


func _close_booth() -> void:
	for n: Node in [_screen, _clinic]:
		if n != null:
			remove_child(n)   # out of the tree now: the booth view and the Stage registrations go with it
			n.queue_free()
	_screen = null
	_clinic = null
	_subject = null


## The chart so far as mini-chart marks: [ear, test, freq, db, no_response], air before masked air.
func _chart_marks() -> Array:
	var out: Array = []
	if _screen == null or _screen.session == null:
		return out
	for t: StringName in [&"ac", &"bc", &"bc_masked", &"ac_masked"]:
		var sh: Dictionary = _screen.session.sheet(t)
		if sh.is_empty():
			continue
		for e: String in ["right", "left"]:
			var st: Dictionary = (sh["stored"] as Dictionary)[e]
			for f: int in st:
				if bool((st[f] as Dictionary).get("retest", false)):
					continue
				out.append([e, String(t), f, int(st[f]["stored_db"]), bool(st[f].get("no_response", false))])
	return out


## The booth's solver (tests, bots): the textbook through the session, the way the AudiOtron's own tests
## drive it, until Hoot's montage takes over or the ear is done; the screen then finishes as in play.
func solve_booth() -> void:
	if _state != &"booth" or _screen == null:
		return
	var s := _screen.session
	var ear := String(_card["ear"])
	var guard := 0
	var n := 0
	while guard < 600 and not s.is_ear_complete(ear) and not bool(_screen.get("_auto_running")) and not bool(_screen.get("_finishing")):
		guard += 1
		var rem := s.required_remaining(ear)
		if s.test == s.goal_test and s.measurement(ear, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
			s.set_freq(rem[0])
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				# Hoot's own varied gaps and beep lengths: never a steady rhythm
				_tick(s, AoAutoTester.GAPS[n % AoAutoTester.GAPS.size()])
				_screen._hold_add("solver")
				_tick(s, AoAutoTester.DURATIONS[n % AoAutoTester.DURATIONS.size()])
				n += 1
				_screen._hold_remove("solver")
				_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"mask_louder", &"mask_softer":
				s.set_mask_level(int(a["target_mask"]))
			&"mask_toggle":
				s.toggle_mask()
			&"transducer":
				s.set_transducer(a["target"])
			&"store":
				_screen._store(false)
			&"no_response":
				_screen._store(true)
			_:
				_tick(s, 0.1)
	_screen._refresh()


static func _tick(s: AudiometrySession, seconds: float) -> void:
	for i in int(round(seconds / 0.05)):
		s.advance(0.05)


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
		"seat":
			return "From the audiometer you must see their face the whole time. Which chair?"
		"order":
			return "Your chart's ready. Which pitch does the TD start on?"
		"rule":
			return String(_card["ask"])
		"walk":
			return _rung_line()
		"phones":
			return "Phones on. Which cup goes on their %s ear?" % String(_card["ear"]).to_upper()
		"first":
			return "Air comes first. Which ear do you test first?"
		"bone":
			return "Air's done on both ears. Where does the bone oscillator sit?"
		"mask":
			return "Air on both ears, bone on the better one. What does the chart need now?"
		"symbol":
			return "Record it. Which symbol goes on the chart?"
		"steps":
			return _rung_line()
		"dam":
			return "This is a %s canal. Which dam?" % String(_card["canal"])
		"depth":
			return "Dam picked. How deep does it go?"
		"tip":
			return "Material mixed and loaded. Which syringe is ready to fill?"
		"fill":
			return "Dam placed and checked. How do you fill?"
		"cure":
			return "%d minutes in. Fingernail test on the leftover: cured?" % int(_card["minutes"])
		"out":
			return "It's out. What now?" if bool(_card["after"]) else "Cured. How does it come out?"
		"judge":
			return "Here's the impression. Send it, or what's wrong?"
		"tube":
			return "The old tube is hard and yellow. Which new tube is right?"
		"wire":
			return "Same RIC on three wire lengths. Which one fits this ear?"
		"dome":
			return "Wire's right. Which dome for this canal?"
		"counsel":
			return "Gus is back for his week-one chat. What do you say?"
		"bench":
			return "Read the ticket and the find. What's the fix?"
		"box":
			return "Easy fixes done, still not right. Which measure is off?"
		"whistle":
			return "It whistles. What kind of whistle is it?"
		"fate":
			return "Fix it here, send it to the maker, or replace it?"
	return "Pick one."


## The ladder's live rung, in words: what the face does (the answer is the player's to call).
func _rung_line() -> String:
	var step := int(_card.get("step", 0))
	if String(_card["kind"]) == "steps":
		var done := int(_card["from"]) + step - 1
		return "What comes first?" if done < 0 else "Done: %s. What comes next?" % PracticalDeck.IMP_STEPS[done].to_lower()
	var db := int((_card["levels"] as Array)[step])
	var face := String((_card["faces"] as Array)[step])
	var words := {"calm": "a calm face.", "frown": "a little frown.", "finger": "a finger goes up.", "hand": "the whole hand goes up!"}
	if db >= PracticalDeck.TD_LIMIT_DB and face != "hand":
		return "%d dB, the limit: %s No hand." % [db, words[face]]
	return "%d dB, a pair of bursts: %s" % [db, words[face]]


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
		"seat", "order", "rule", "walk":
			return "The board's suggested TD routine: face in view, top pitch first, %d dB, pairs, up %d, finger, hand, arrow at %d." % [
				PracticalDeck.TD_START_DB, PracticalDeck.TD_STEP_DB, PracticalDeck.TD_LIMIT_DB]
		"phones", "first", "bone":
			return "Station A, before the first beep: the right cup on the right ear, the better ear first, bone on the mastoid."
		"mask":
			return "Your subject's chart from the booth. The rules are drawn on the right."
		"symbol":
			return "The board marks every symbol: right red, left blue, the right shape for each test."
		"tube", "wire", "dome":
			return "Station B's delivery: retube with pre-bent #13 tubing, fit the RIC to the ear, then orient a new user."
		"counsel":
			return "Realistic expectations, wearing time, care: answer true AND kind."
		"bench", "box", "whistle", "fate":
			return "The bench tree: look, listen, test, fix. Can't fix it? Send it in. Can't send it? Replace."
		"steps", "dam", "depth", "tip", "fill", "cure", "out", "judge":
			return "One impression only. Safe support for the light and the syringe; an unsafe pick is a STOP (+%d)." % PracticalDeck.UNSAFE_STROKES
	return ""


## Answer the live card (keys 1-4, a click or the solver).
func pick(i: int) -> void:
	if _state != &"card" or _wrong.has(i) or i < 0 or i >= (_card["options"] as Array).size():
		return
	if _guided and i != int(_card["answer"]):
		return
	var answers: Array = _card.get("answers", [])
	var step := int(_card.get("step", 0))
	if i == int(_card["answer"]) and step < answers.size() - 1:
		# a ladder rung, right: the next pair (a soft tick and a drawn wave; nothing loud ever plays)
		_card["step"] = step + 1
		_card["answer"] = int(answers[step + 1])
		if _card.has("rung_options"):   # Station 5's steps: each rung has its own four
			_card["options"] = (_card["rung_options"][step + 1] as Array).duplicate()
		_card["rung_at"] = _stage_t
		_wrong.clear()
		Sfx.play(&"click", 1.3, -14.0)
		_say(_rung_line())
		_answer_buttons()
		_go.emit(&"step")
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
			_say(_hole_line(), _speaker)
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
	if unsafe and _is_exam():
		_stop_task(i)
		return
	if _is_exam():
		_say("Noted.", "Examiner")   # the examiner says nothing else
	elif unsafe:
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


## Exam day's STOP: an unsafe pick ends the task with its points lost; the right answer is shown, the room goes on.
func _stop_task(i: int) -> void:
	_stopped = true
	_state = &"busy"
	_reveal = true
	if not _card.has("sneeze_at"):
		_card["sneeze_at"] = _stage_t
	_say("Stop. Thank you. We'll move on.", "Examiner")
	_feedback_text("STOP: unsafe. This task's %d point%s are lost; the room goes on.\n%s" % [int(_card["points"]),
		"" if int(_card["points"]) == 1 else "s", String(_card["lines"][0])])
	for b: Button in _answer_list():
		b.disabled = true
		if int(b.get_meta("answer", -1)) == i:
			b.text = "STOP: unsafe"
			Juice.shake(b, 5.0, 0.25)
	_go.emit(&"stop")


func hint() -> void:
	if _state != &"card" or _hinted or _guided or _is_exam():
		return
	_hinted = true
	_hole_strokes += 1
	Sfx.play(&"pop", 1.0, -8.0)
	_say(String(_card["hint"]))
	if _hint_btn != null:
		_hint_btn.disabled = true


func _hole_line() -> String:
	if _is_exam():
		return "Thank you."
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
	var exam := {}
	if _is_exam():
		exam = _exam_sheet()
		over = int(exam["max"]) - int(exam["points"])   # the exam's record keeps the fewest points lost
	var star := over == 0
	var rec := TrainingProgress.record_round(PracticalDeck.LESSON, station_id, over, String(info["card"]))
	# Station 2 earns a second card (California's Refer 8) with the first
	var card2 := String(info.get("card2", ""))
	rec["new_card2"] = card2 != "" and TrainingProgress.earn_card(PracticalDeck.LESSON, card2)
	last_result = {"station": station_id, "strokes": strokes.duplicate(), "over_par": over, "star": star,
		"new_card": bool(rec["new_card"]), "best": int(rec["best"])}
	if _is_exam():
		exam["first_pass"] = Licence.record_pass(bool(exam["pass"]))
		last_result.merge(exam, true)
	print("PRACTICAL_RESULT %s" % JSON.stringify(last_result))
	_state = &"score"
	_show_overlay(_exam_panel(exam, rec) if _is_exam() else _score_panel(over, rec))
	if _is_exam():
		Sfx.play(&"fanfare" if bool(exam["pass"]) else &"ding", 1.0, -8.0)
		_say(String(info["star_line"]) if star else ("Grade %s, and a pass! The licence says so." % String(exam["grade"]) if bool(exam["pass"])
			else "Grade %s. %s Play again: every sitting is practice." % [String(exam["grade"]),
				"A STOP means no pass this time, whatever the points." if int(exam["stops"]) > 0 else "A pass needs a B: %d%%." % int(PracticalDeck.EXAM_GRADES[2][0])]))
	elif star:
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


## Exam day's score sheet: {points, max, grade, pass, stops, tasks}.
func _exam_sheet() -> Dictionary:
	var got := 0
	var mx := 0
	var stops := 0
	var tasks: Array = []
	for i in _got.size():
		var c: Dictionary = _cards[i]
		got += _got[i]
		mx += int(c["points"])
		stops += 1 if _stops[i] else 0
		tasks.append({"room": String(c["room"]), "task": int(c["task"]), "kind": String(c["kind"]), "points": int(c["points"]), "got": _got[i], "stop": _stops[i]})
	var lost := mx - got
	return {"points": got, "max": mx, "grade": PracticalDeck.exam_grade(lost), "pass": PracticalDeck.exam_passed(lost, stops), "stops": stops, "tasks": tasks}


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
	if _state == &"booth":
		return   # the AudiOtron has the keys
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
	_score_label.position = Vector2(760 if _is_exam() else 670, 28)   # the exam's top line is longer
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
			PracticalArt.draw_card(_stage, _stage.size, _card, _reveal, _wrong, _stage_t)
			if _is_exam():
				PracticalArt.draw_task_tag(_stage, _card, _stopped))
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
		var open := _talk > 0.0 and fmod(_talk, 0.25) > 0.12
		if _speaker == "Examiner":
			PracticalArt.draw_examiner(_hoot_face, Vector2(43, 43), 38.0, open)
		else:
			Portraits.draw(_hoot_face, "Hoot", Vector2(43, 43), 38.0, open))
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
		var hr := UiKit.hint_row([["1", "2", "3", "4"], "answer", ["Enter"], "next", ["T"], "room", ["Esc"], "pause"] if _is_exam()
			else [["1", "2", "3", "4"], "answer", ["H"], "hint", ["Enter"], "next", ["T"], "room", ["Esc"], "pause"], 16)
		hr.position = Vector2(24, 676)
		_field.add_child(hr)
	_overlay = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	_overlay.visible = false
	add_child(_overlay)


func _layout() -> void:
	var vp := get_viewport_rect().size
	var off := ((vp - FIELD) * 0.5).floor()
	_field.position = Vector2(maxf(off.x, 0.0), maxf(off.y, 0.0))


func _say(text: String, who := "Hoot") -> void:
	_speaker = who
	_hoot_label.text = text
	_talk = minf(2.0, text.length() / 30.0)
	Events.dialogue_line.emit(who, text)


func _set_top(text: String) -> void:
	_top_label.text = text


func _update_score() -> void:
	if strokes.is_empty():
		_score_label.text = ""
		return
	var total := 0
	for s: int in strokes:
		total += s
	if _is_exam():
		var got := 0
		var asked := 0
		for i in _got.size():
			got += _got[i]
			asked += int(_cards[i]["points"])
		_score_label.text = "Points %d of %d" % [got, asked]
		return
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
		_hint_btn = _side_button("No hints in the exam" if _is_exam() else "Hoot's hint (+1)", "" if _is_exam() else "H", Vector2(SIDE_W, 50))
		_hint_btn.pressed.connect(hint)
		_hint_btn.disabled = _hinted or _is_exam()
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


## Exam day's scorecard: the score sheet by room (each task's points, a STOP in red), the total, the grade, pass
## or not yet, and the licence.
func _exam_panel(exam: Dictionary, rec: Dictionary) -> Control:
	var p := UiKit.panel(Palette.PAPER, Palette.INK, 28)
	p.custom_minimum_size = Vector2(980, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := UiKit.label("EXAM DAY: THE SCORE SHEET", 30, Palette.INK, 700)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	v.add_child(body)
	var rooms := VBoxContainer.new()
	rooms.add_theme_constant_override("separation", 8)
	body.add_child(rooms)
	for room: String in ["A", "B"]:
		var rl := UiKit.label("Room %s" % room, 18, Palette.INK_SOFT, 700)
		rooms.add_child(rl)
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		flow.custom_minimum_size = Vector2(640, 0)
		for t: Dictionary in exam["tasks"]:
			if String(t["room"]) != room:
				continue
			var full := int(t["got"]) == int(t["points"])
			var col: Color = Palette.MINT if full else (PracticalArt.RED if bool(t["stop"]) else Palette.SUNNY)
			var chip := UiKit.panel(col, Palette.INK, 10)
			chip.custom_minimum_size = Vector2(152, 0)
			var cv := VBoxContainer.new()
			chip.add_child(cv)
			var n := UiKit.label(PracticalDeck.exam_task_name(t), 14, Palette.PAPER if bool(t["stop"]) else Palette.INK, 600)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(n)
			var g := UiKit.label("STOP  0/%d" % int(t["points"]) if bool(t["stop"]) else "%d/%d" % [int(t["got"]), int(t["points"])], 17,
				Palette.PAPER if bool(t["stop"]) else Palette.INK, 700)
			g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(g)
			flow.add_child(chip)
		rooms.add_child(flow)
	# the grade badge and the licence
	var side := Control.new()
	side.name = "exam_grade"
	side.custom_minimum_size = Vector2(280, 300)
	var grade := String(exam["grade"])
	var passed := bool(exam["pass"])
	side.draw.connect(func() -> void:
		var f := UiKit.font(700)
		side.draw_string(f, Vector2(0, 30), "%d of %d points" % [int(exam["points"]), int(exam["max"])], HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 24, Palette.INK)
		var c := Vector2(side.size.x * 0.5, 82)
		side.draw_circle(c + Vector2(0, 3), 36.0, Color(0, 0, 0, 0.25))
		side.draw_circle(c, 36.0, Palette.grade_color(grade))
		side.draw_arc(c, 36.0, 0.0, TAU, 32, Palette.INK, 3.0, true)
		side.draw_string(f, c + Vector2(-36, 15), grade, HORIZONTAL_ALIGNMENT_CENTER, 72, 42, Palette.INK)
		var word := "PRACTICAL PASS" if passed else ("STOP: NOT YET" if int(exam["stops"]) > 0 else "NOT YET: B PASSES")
		side.draw_string(f, Vector2(0, 148), word, HORIZONTAL_ALIGNMENT_CENTER, side.size.x, 20, Palette.MINT.darkened(0.3) if passed else PracticalArt.RED)
		Licence.draw(side, Vector2(side.size.x * 0.5, 232), 0.9, Licence.grade(), Licence.passed()))
	body.add_child(side)
	var star := Control.new()
	star.custom_minimum_size = Vector2(0, 44)
	star.draw.connect(func() -> void:
		var c := Vector2(star.size.x * 0.5 - 120, 22)
		UiDraw.star(star, c + Vector2(0, 3), 20.0, Color(Palette.INK, 0.3))
		UiDraw.star(star, c, 20.0, Palette.SUNNY if bool(rec["star"]) else Color(Palette.INK_SOFT, 0.25))
		var t := "Star earned!" if int(exam["points"]) == int(exam["max"]) else ("Star kept from before" if bool(rec["star"]) else "Every point earns the star")
		star.draw_string(UiKit.font(700), c + Vector2(30, 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK))
	v.add_child(star)
	if bool(exam.get("first_pass", false)) or int(TrainingProgress.station(PracticalDeck.LESSON, "exam")["plays"]) == 1:
		var nl := UiKit.label("Your Booth Camp Practical licence is on the lesson card!", 20, Palette.CORAL, 700)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var again := UiKit.button("Sit it again", &"", Vector2(200, 56))
	again.add_theme_font_size_override("font_size", 22)
	again.pressed.connect(play_again)
	row.add_child(again)
	var back := UiKit.button("Back to the Training room", &"", Vector2(340, 56))
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(leave)
	row.add_child(back)
	if UiKit.show_key_hints():
		var hr := UiKit.hint_row([["R"], "sit again", ["Enter"], "back to the room"], 16)
		hr.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(hr)
	return p
