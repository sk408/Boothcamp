extends Node
## Dev gallery for Day 5 (developer tool, not part of the game flow): the SPEECH screen's PARTY mode
## on Marco, driven by the textbook (SpeechSession.recommended_action() through the screen's own
## controls), then Day 5's boards and paper, with a screenshot at each step:
##   tools/scene_shot.sh res://story/dev_marco.tscn /abs/dir "1" 200   (shots come from the script)
## Add -- --part=<part> after the quit time: screen (the default), board, seats, dinner, paper or
## all; add --reduced-motion to shoot the still versions. Marco is his patient file
## (core/patients/marco.tres), else a stand-in with the same numbers as the tests'
## (core/tests/test_speech_sin_model.gd).
## --part=screen:
##   day5_party_level    the coached list: the talker at 50, the coach's hand on LOUDER
##   day5_practice       Hoot's practice sentence at x1
##   day5_scoring        sentence 1: chips half marked, the focus ring
##   day5_lock_tray      LOCK IN: the misses ride off on the waiter's tray (reduced motion: greyed)
##   day5_noise_wins     Dessert at 0 dB: the bars meet, the room is packed
##   day5_list_done      the total lands on the courses
##   day5_soundfield     programme A in the sound field: the talker in front, the party behind
##   day5_focus_revealed programme B once the reveal names FOCUS: the front half bright
##   day5_hoot_turn      Hoot pours the first courses at x8
## --part=board (story/games/marco_board.gd on Hoot's textbook visit, every beat by its solver):
##   dev_day5_bill, dev_day5_band_wrong, dev_day5_band_paid, dev_day5_average, dev_day5_plates,
##   dev_day5_plate_wrong, dev_day5_both_true, dev_day5_pizza, dev_day5_pizza_focus,
##   dev_day5_switch, dev_day5_switch_b, dev_day5_reveal, dev_day5_reveal_luck
## --part=seats: dev_day5_seats, dev_day5_seat_<id> for each seat in order
## --part=dinner: dev_day5_dinner, dev_day5_married, dev_day5_tray_crash, dev_day5_review
## --part=paper: dev_day5_paper_<grade> for S, A (the benefit too small to call), C and Do-over
## --part=clinic (Marco in the 3D clinic): dev_day5_marco_desk, _face (his half-moon glasses on
##   their chain), _phones (the clinic takes them off for the earphones), _soundfield (the two booth
##   speakers), _standing (the glasses back on once his head is clear)

const SCREEN := "res://ui/speech/speech_screen.tscn"
const MARCO := "res://core/patients/marco.tres"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const LevelMarco := preload("res://story/level_marco.gd")
const MarcoBoard := preload("res://story/games/marco_board.gd")
const MarcoSeats := preload("res://story/games/marco_seats.gd")
const MarcoDinner := preload("res://story/games/marco_dinner.gd")
const PAPER_GRADES: Array[String] = ["S", "A", "C", "Do-over"]
const SEED := 5

var screen: SpeechScreen
var marco: PatientProfile
var _beats: Array = []


func _ready() -> void:
	Game.begin_visit("mike")
	if Game.cli_flag("reduced-motion"):
		Game.settings["reduced_motion"] = true
	marco = load(MARCO) as PatientProfile if ResourceLoader.exists(MARCO) else _stand_in()
	Events.awaiting_input.connect(func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		_beats.append({"beat": beat, "info": info, "solver": solver}))


func demo_start() -> void:
	var part := Game.cli_value("part", "screen")
	if part in ["all", "screen"]:
		await _screen_part()
	if part in ["all", "board"]:
		await _board_part()
	if part in ["all", "seats"]:
		await _seats_part()
	if part in ["all", "dinner"]:
		await _dinner_part()
	if part in ["all", "paper"]:
		await _paper_part()
	if part in ["all", "clinic"]:
		await _clinic_part()
	get_tree().quit()


# ---------------------------------------------------------------- Hoot's textbook visit

## Hoot's whole Day 5 visit by the book (no screen): tones with bone, both SRTs, words in quiet
## (Word list 1 right, 2 left), then Party lists 1-6 with the level's own plans (quick visit).
static func textbook_results(p: PatientProfile, seed_value: int = SEED) -> Dictionary:
	var t := SpeechSession.tone_results_from(p)
	var s := SpeechSession.new(p, seed_value)
	for ear: String in ["right", "left"]:
		s.configure({"test": "srt", "tones": t})
		s.run_by_textbook(ear)
	s.configure({"test": "wrs", "tones": t, "list": SpeechRules.WRS_LISTS[0]})
	s.run_by_textbook("right")
	s.configure({"test": "wrs", "tones": t, "list": SpeechRules.WRS_LISTS[1]})
	s.run_by_textbook("left")
	var lv := LevelMarco.new()
	lv.tones = t
	for n in range(1, 7):
		s.configure(lv.party_plan(n, true))
		s.run_by_textbook("both")
	lv.free()
	return SpeechSession.merge_results(t, s.build_results())


## The textbook sheets made to look like a player's visit for the paper: lists 1, 2, 3 and 5 the
## player's (3, 5 with Hoot's first three courses), lists 4 and 6 Hoot's; par everywhere, list 2 a
## birdie, no slips.
static func as_player_visit(res: Dictionary) -> void:
	var sin: Dictionary = (res["speech"] as Dictionary).get("sin", {})
	for slot: Variant in sin:
		var sh: Dictionary = sin[slot]
		for v: Variant in sh.get("lists", []):
			var l: Dictionary = v
			var n := SpeechRules.SIN_LISTS.find(String(l.get("list_id", ""))) + 1
			var player := 0 if n == 4 or n == 6 else (3 if n == 3 or n == 5 else 6)
			l["player_sentences"] = player
			l["hoot_sentences"] = 6 - player
			l["by_hoot"] = player == 0
			l["golf"] = &"hoot" if player == 0 else (&"birdie" if n == 2 else &"par")
			l["key_words"] = player * 5
			l["matches"] = player * 5
		sh["forks"] = 3
		sh["units"] = 1 if String(slot) != "both" else 2
		sh["by_hoot"] = false
	(res["speech"] as Dictionary)["max_combo"] = 45


## A Daily Decibel summary for grade g on these results (the level's own headlines and column).
static func paper_summary(res: Dictionary, g: String) -> Dictionary:
	var score: float = {"S": 100.0, "A": 92.0, "C": 64.0, "Do-over": 38.0}.get(g, 80.0)
	var medal := "gold" if g == "S" else ("silver" if g == "A" else "bronze")
	var medals := {}
	for pair: Array in LevelMarco.MEDAL_BEATS:
		medals[pair[0]] = medal
	return {"patient_id": LevelMarco.PATIENT_ID, "score": score, "grade": g, "accuracy": score / 100.0, "technique": score / 100.0,
		"efficiency": score / 100.0, "care": 1.0, "comfort": 3, "medals": medals, "coins_earned": 80, "coins_total": 200,
		"audiometry": res, "chapter_id": LevelMarco.PATIENT_ID, "day": 5, "patient_name": "Marco Polenta", "next_chapter_id": "rocco",
		"headlines": LevelMarco.HEADLINES, "subheads": LevelMarco.SUBHEADS, "medal_beats": LevelMarco.MEDAL_BEATS,
		"weather": LevelMarco.WEATHER, "sports_script": LevelMarco.SPORTS_SCRIPT}


## The four plate cards from the textbook results, as the level builds them.
static func plate_cards_of(res: Dictionary) -> Array[Dictionary]:
	var lv := LevelMarco.new()
	lv.tones = SpeechSession.tone_results_from(Game.load_patient("marco") as PatientProfile)
	lv.results = res
	var cards := lv.plate_cards()
	lv.free()
	return cards


# ---------------------------------------------------------------- --part=board

func _solve_last(beat: StringName) -> void:
	for i in range(_beats.size() - 1, -1, -1):
		if _beats[i]["beat"] == beat:
			(_beats[i]["solver"] as Callable).call()
			return


func _board_part() -> void:
	var res := textbook_results(marco)
	var sin: Dictionary = (res["speech"] as Dictionary)["sin"]
	var both: Dictionary = sin["both"]
	var b := MarcoBoard.new()
	add_child(b)
	await get_tree().process_frame
	var rec: Dictionary = (both["lists"] as Array)[0]
	await b.show_bill(rec)
	await _wait(1.4)
	await _shot("dev_day5_bill")
	var loss := SpeechRules.snr_loss(int(rec["total"]))
	var got := [&""]
	var pick := func() -> void:
		got[0] = await b.pick_band(loss)
	pick.call()
	await _wait(0.3)
	# a wrong band first (the pointer starts on NEAR-NORMAL), then the solver
	b.call("_confirm_band")
	await _wait(0.4)
	await _shot("dev_day5_band_wrong")
	await _wait(0.6)
	pick.call()
	await _wait(0.3)
	_solve_last(&"band_pick")
	await _wait(0.5)
	await b.pay(got[0] as StringName)
	await _shot("dev_day5_band_paid")
	await b.show_average(both["lists"], float(both["snr_loss"]), StringName(String(both["band"])))
	await _wait(0.4)
	await _shot("dev_day5_average")
	await b.setup_plates(plate_cards_of(res))
	var plates := func() -> void:
		await b.run_plates()
	plates.call()
	await _wait(0.8)
	await _shot("dev_day5_plates")
	b.call("_serve", 2, "quiet")   # the canals card: true, but proves neither claim
	await _wait(0.5)
	await _shot("dev_day5_plate_wrong")
	await _wait(0.8)
	for k in 2:
		_solve_last(&"plates_serve")
		await _wait(1.2)
	await _wait(0.9)
	await _shot("dev_day5_both_true")
	await _wait(1.0)
	await b.show_pizza()
	await _wait(0.4)
	await _shot("dev_day5_pizza")
	b.pizza_focus(true)
	await _wait(0.9)
	await _shot("dev_day5_pizza_focus")
	await b.show_switch()
	await _wait(0.3)
	await _shot("dev_day5_switch")
	var flip := func() -> void:
		await b.flip_switch()
	flip.call()
	await _wait(0.2)
	_solve_last(&"focus_switch")
	await _wait(0.6)
	await _shot("dev_day5_switch_b")
	var omni: Dictionary = sin["aided_omni"]
	var focus: Dictionary = sin["aided_directional"]
	await b.show_reveal(omni, focus, float(focus["benefit_db"]), float(focus["crit_diff_db"]), true)
	await _wait(0.4)
	await _shot("dev_day5_reveal")
	await b.show_reveal(omni, focus, 1.5, 2.7, false)
	await _wait(0.4)
	await _shot("dev_day5_reveal_luck")
	b.queue_free()
	await _wait(0.2)


# ---------------------------------------------------------------- --part=seats

func _seats_part() -> void:
	var s := MarcoSeats.new()
	add_child(s)
	await get_tree().process_frame
	var texts: Array[String] = []
	for seat: Dictionary in LevelMarco.SEATS:
		texts.append(String(seat["text"]))
	for i in LevelMarco.SEATS.size():
		var got := [-1]
		var choose := func() -> void:
			got[0] = await s.choose(LevelMarco.line("seat_prompt"), texts, 3)
		choose.call()
		await _wait(0.6)
		if i == 0:
			await _shot("dev_day5_seats")
		(s.get("_buttons")[i] as Button).pressed.emit()
		await _wait(0.1)
		await s.sit(String(LevelMarco.SEATS[i]["id"]))
		await _shot("dev_day5_seat_" + String(LevelMarco.SEATS[i]["id"]))
	s.queue_free()
	await _wait(0.2)


# ---------------------------------------------------------------- --part=dinner

func _dinner_part() -> void:
	var d := MarcoDinner.new()
	add_child(d)
	await d.open()
	await _shot("dev_day5_dinner")
	d.cheer()
	await _wait(0.8)
	await _shot("dev_day5_married")
	d.tray_crash()
	await _wait(0.3)
	await _shot("dev_day5_tray_crash")
	await d.write_review()
	await _shot("dev_day5_review")
	d.queue_free()
	await _wait(0.2)


# ---------------------------------------------------------------- --part=clinic

func _clinic_part() -> void:
	var clinic: Node3D = (load("res://world/clinic.tscn") as PackedScene).instantiate()
	clinic.set("patient_id", "marco")
	add_child(clinic)
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.3)
	await clinic.call("walk_in")
	await clinic.call("focus_camera", &"desk", 0.6)
	await _shot("dev_day5_marco_desk")
	await clinic.call("focus_camera", &"face", 0.6)
	await _wait(0.3)
	await _shot("dev_day5_marco_face")
	await clinic.call("focus_camera", &"booth", 0.6)
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.6)
	clinic.call("put_on_earphones", true)
	await _wait(0.8)
	await _shot("dev_day5_marco_phones")
	clinic.call("take_off_earphones")
	clinic.call("put_on_hearing_aids")
	await clinic.call("focus_camera", &"booth", 0.6)
	clinic.call("show_soundfield", true)
	await _wait(1.4)
	await _shot("dev_day5_marco_soundfield")
	clinic.call("show_soundfield", false)
	await clinic.call("stand")
	await clinic.call("focus_camera", &"face", 0.6)
	await _wait(0.4)
	await _shot("dev_day5_marco_standing")
	clinic.queue_free()
	await _wait(0.2)


# ---------------------------------------------------------------- --part=paper

func _paper_part() -> void:
	var res := textbook_results(marco)
	as_player_visit(res)
	for g: String in PAPER_GRADES:
		var r := res.duplicate(true)
		if g == "A":
			var sm: Dictionary = (r["speech"] as Dictionary)["sin_summary"]
			sm.merge({"benefit_db": 1.5, "real_change": false, "benefit_unsure": true}, true)
		var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
		add_child(paper)
		paper.call_deferred("show_summary", paper_summary(r, g))
		await _wait(2.5)
		await _shot("dev_day5_paper_" + g)
		paper.queue_free()
		await _wait(0.2)


func _screen_part() -> void:
	screen = (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	add_child(screen)
	var tones := SpeechSession.tone_results_from(marco)
	# Party list 1: coached, the practice first, the dial at 50
	screen.start_test(marco, "both", true, {"test": "sin", "tones": tones, "list": "party_1", "condition": "unaided", "level": 50,
		"practice": "party_practice", "hide_loss": true, "intro": "Party time! Both ears together, like a real dinner. His ears match."})
	await _wait(5.0)
	await _shot("day5_party_level")
	while screen.session.db < screen.session.textbook_target():
		screen.do_action(&"louder")
		await _wait(0.25)
	screen.do_action(&"present")   # Hoot's practice turn
	await _until(func() -> bool: return bool(screen.get_state()["answer_shown"]) and screen.hoot_running(), 30.0)
	await _wait(1.0)
	await _shot("day5_practice")
	await _until(func() -> bool: return not screen.hoot_running() and screen.idle(), 30.0)
	await _wait(1.2)
	# sentence 1 by the player: two chips marked, then the shot
	screen.do_action(&"present")
	await _until(_marking, 30.0)
	for i in 2:
		_textbook_mark()
		await _wait(0.3)
	await _wait(0.6)
	await _shot("day5_scoring")
	# a slip on purpose so the tray carries something: chip 5 ticked whatever he said, then lock
	while int(_sin().get("focus_key", -1)) >= 0 and int(_sin().get("focus_key", -1)) < 4:
		_textbook_mark()
		await _wait(0.2)
	screen.do_action(&"score_missed")
	await _wait(0.3)
	screen.do_action(&"lock")
	await _wait(0.55)
	await _shot("day5_lock_tray")
	await _wait(2.0)
	# sentences 2-5 by the textbook, fast; then Dessert
	Engine.time_scale = 6.0
	while int(_sin().get("sentence_n", 1)) < 6 or not bool(_sin().get("awaiting_lock", false)):
		await _until(func() -> bool: return screen.idle() or bool(screen.get_state()["finishing"]), 30.0)
		if bool(screen.get_state()["finishing"]):
			break
		if int(_sin().get("sentence_n", 1)) == 6 and not bool(_sin().get("awaiting_lock", false)):
			screen.do_action(&"present")
			await _until(_marking, 30.0)
			break
		var rec := screen.session.recommended_action()
		screen.do_action(StringName(String(rec["action"])), rec)
		await _wait(0.2)
	Engine.time_scale = 1.0
	await _wait(0.8)
	await _shot("day5_noise_wins")
	await _finish_by_textbook()
	await _wait(0.9)
	await _shot("day5_list_done")
	await _until(func() -> bool: return not bool(screen.get_state()["finishing"]) or not screen.is_inside_tree(), 8.0)
	await _wait(3.5)
	# programme A in the sound field (set by Hoot), then B once FOCUS is revealed
	screen.start_test(marco, "both", false, {"test": "sin", "tones": tones, "list": "party_3", "condition": "omni", "programme": "A"})
	await _wait(1.0)
	screen.do_action(&"present")
	await _wait(1.6)
	await _shot("day5_soundfield")
	await _until(_marking, 30.0)
	await _finish_by_textbook()
	await _wait(5.0)
	screen.start_test(marco, "both", false, {"test": "sin", "tones": tones, "list": "party_5", "condition": "directional", "programme": "B",
		"compare_to": "aided_omni", "revealed": true, "hoot_first": 3, "hoot_only": true})
	await _wait(2.6)
	await _shot("day5_hoot_turn")
	await _until(func() -> bool: return not screen.hoot_running() and screen.idle(), 60.0)
	screen.do_action(&"present")
	await _wait(1.6)
	await _shot("day5_focus_revealed")


## Lock in what is on the card by the textbook, then the rest of the list.
func _finish_by_textbook() -> void:
	Engine.time_scale = 6.0
	var guard := 0
	while not bool(screen.get_state()["finishing"]) and guard < 200:
		guard += 1
		await _until(func() -> bool: return screen.idle() or bool(screen.get_state()["finishing"]), 30.0)
		if bool(screen.get_state()["finishing"]):
			break
		var rec := screen.session.recommended_action()
		screen.do_action(StringName(String(rec["action"])), rec)
		await _wait(0.15)
	Engine.time_scale = 1.0


func _textbook_mark() -> void:
	var rec := screen.session.recommended_action()
	screen.do_action(StringName(String(rec["action"])), rec)


func _marking() -> bool:
	var st := screen.get_state()
	return bool(_sin().get("awaiting_lock", false)) and bool(st["answer_shown"]) and not bool(st["talking"]) and not bool(st["listening"])


func _sin() -> Dictionary:
	return screen.get_state().get("sin", {})


func _until(cond: Callable, max_s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()) and Time.get_ticks_msec() - t0 < int(max_s * 1000.0):
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n + ("_still" if bool(Game.settings.get("reduced_motion", false)) else ""))
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


## Marco until his patient file is in: the numbers the Day 5 tests pin (a mild sloping loss, ears
## alike, an SNR loss of 9 dB and a FOCUS benefit of 4).
static func _stand_in() -> PatientProfile:
	var p := PatientProfile.new()
	p.id = "marco_standin"
	p.display_name = "Marco Polenta"
	var right: Dictionary[int, int] = {250: 10, 500: 15, 750: 15, 1000: 20, 1500: 25, 2000: 30, 3000: 35, 4000: 40, 6000: 40, 8000: 35}
	var left: Dictionary[int, int] = {250: 10, 500: 15, 750: 15, 1000: 25, 1500: 25, 2000: 30, 3000: 35, 4000: 40, 6000: 45, 8000: 40}
	p.thresholds_right = right
	p.thresholds_left = left
	p.reaction_time_min_s = 0.7
	p.reaction_time_max_s = 1.3
	p.psychometric_slope_db = 2.5
	p.attention = 0.95
	p.speech = {"wrs_max": {"right": 96, "left": 92}, "snr_loss": 9.0, "directional_benefit": 4.0}
	return p
