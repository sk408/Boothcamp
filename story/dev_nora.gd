extends "res://story/level_nora.gd"
## Dev scene for Day 4 (developer tool, not part of the game flow): Nora's level started at one
## beat, with Hoot's textbook results filled in for everything before it, so a beat can be looked
## at (or shot) without playing up to it. Everything from that beat on is the level's own code.
##   godot --path . -- --scene=res://story/dev_nora.tscn --from=flags            (play it yourself)
##   godot --path . -- --scene=res://story/dev_nora.tscn --from=words_l --autoplay --shots=/abs/dir
##   tools/scene_shot.sh res://story/dev_nora.tscn /abs/dir "1" 16 -- --from=paper
## --from (FROM): movie (the default: the whole visit), intro, history, otoscopy, instructions,
## tones, srt, words_r, words_l, louder, flags, call, payoff; or paper: four Daily Decibels and no
## level (S; A with a redone list; C; Do-over), shot as dev_day4_paper_<grade>.
## --boo (with --from=words_l, without --autoplay): a scripted unmasked PRESENT on List 2 at the
## comfortable level, then MASK, for the level's day4_boo and day4_ghostbuster shots (the bot always
## masks first, so it never meets the BOO); the scene quits after them.
## The textbook results: Hoot's tones from core/patients/nora.tres (air, unmasked bone at 1k and 4k
## on the right, masked bone there on the left), then his SRTs and word lists, by the book.

const FROM: Array[StringName] = [&"movie", &"intro", &"history", &"otoscopy", &"instructions", &"tones", &"srt",
	&"words_r", &"words_l", &"louder", &"flags", &"call", &"payoff", &"paper"]
## The HUD step each skipped beat completes.
const STEP_OF: Dictionary = {&"history": &"chat", &"otoscopy": &"peek", &"instructions": &"explain", &"tones": &"beeps",
	&"srt": &"srt", &"words_r": &"words_r", &"words_l": &"words_l", &"louder": &"louder", &"flags": &"flags", &"call": &"call"}
## The gold medal a skipped beat would have earned on a textbook visit.
const MEDAL_OF: Dictionary = {&"history": "history", &"otoscopy": "otoscopy", &"instructions": "instructions",
	&"words_l": "masking", &"flags": "evidence", &"call": "referral"}
const PAPER_GRADES: Array[String] = ["S", "A", "C", "Do-over"]
const SEED := 4


func _run() -> void:
	var from := StringName(Game.cli_value("from", "movie"))
	var at := FROM.find(from)
	if at < 0:
		push_warning("dev_nora: no beat %s (beats: %s)" % [from, ", ".join(FROM)])
		at = 0
	if FROM[at] == &"paper":
		await _papers()
		return
	_skip_before(at)
	if at <= _i(&"movie"):
		await _masking_offer()
		await _movie()
	if at <= _i(&"intro"):
		await _intro()
	else:
		clinic.call("focus_camera", &"desk", 0.0)
		await clinic.call("walk_in")
	if at <= _i(&"history"):
		await _history()
	if at <= _i(&"otoscopy"):
		await _otoscopy()
	if at <= _i(&"instructions"):
		await _instructions()
	if at <= _i(&"tones"):
		await _tones()
	else:
		await clinic.call("sit")
		tones = textbook_tones(patient)
		results = tones
		Game.set_audiometry_results(results)
	if at <= _i(&"louder"):
		await _speech_from(at)
	else:
		results = textbook_results(patient, tones)
		Game.set_audiometry_results(results)
		_lists_given = 3
	var board: Control
	if at <= _i(&"flags"):
		board = await _evidence()
	else:
		var b := NoraBoard.new()
		b.setup(roll_call_cards(results))
		hud.call("add_game", b)
		board = b
	if at <= _i(&"call"):
		await _referral(board)
	await _payoff(board)
	await _results()


func _i(beat: StringName) -> int:
	return FROM.find(beat)


## The HUD steps, medals and flags of every beat before `at`, as a textbook visit leaves them.
func _skip_before(at: int) -> void:
	for i in at:
		var beat := FROM[i]
		if STEP_OF.has(beat):
			hud.call("complete_step", STEP_OF[beat])
		if MEDAL_OF.has(beat):
			Game.record_medal(String(MEDAL_OF[beat]), "gold")
	if at > _i(&"instructions"):
		Game.set_visit_flag("instructed", true)
		Game.set_visit_flag("instructed_first_try", true)
	if at > _i(&"movie"):
		Game.set_visit_flag("movie_watched", false)


## The SPEECH part of the level from `at` (srt, words_r, words_l or louder): Hoot runs what comes
## before it off-screen, by the book, then the level's own beats take over.
func _speech_from(at: int) -> void:
	clinic.call("put_on_earphones", true)
	clinic.call("hold_response_button", false)
	clinic.call("focus_camera", &"face", 0.0)
	var cam: Camera3D = clinic.call("get_main_camera")
	screen = (load(SPEECH_SCENE) as PackedScene).instantiate() as CanvasLayer
	add_child(screen)
	cam.current = false
	_speech_on = true
	if at <= _i(&"srt"):
		await _srt()
	else:
		for ear: String in ["right", "left"]:
			await _hidden(ear, {"test": "srt", "tones": tones})
	if at <= _i(&"words_r"):
		await _list_right()
	else:
		await _hidden("right", {"test": "wrs", "tones": tones, "list": next_list()})
	var comfy: Dictionary
	if at <= _i(&"words_l"):
		comfy = await _list_left()
		comfy = await _redo_if_needed(comfy)
		hud.call("complete_step", &"words_l")
	else:
		await _hidden("left", {"test": "wrs", "tones": tones, "list": next_list()})
		comfy = newest_list("left")
	await _louder(comfy)
	_speech_on = false
	screen.queue_free()
	screen = null
	cam.current = true
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"face", 0.6)


func _list_left() -> Dictionary:
	if Game.cli_flag("boo"):
		_boo_driver.call_deferred()
	return await super()


## The unmasked press the BOO needs, as a player who forgot the noise would make it.
func _boo_driver() -> void:
	var sc := screen as SpeechScreen
	await _until(func() -> bool: return sc.session != null and sc.session.test == &"wrs" and sc.session.ear == "left", 20.0)
	await _wait(0.5)
	await _until(func() -> bool: return not sc.hoot_running() and sc.idle(), 40.0)
	await _wait(0.3)
	var guard := 0
	while guard < 30:
		guard += 1
		var target := int(sc.session.mode.call("textbook_target"))
		if sc.session.db == target:
			break
		sc.do_action(&"louder" if sc.session.db < target else &"softer")
		await _wait(0.1)
	await _wait(0.5)
	sc.do_action(&"present")
	await _wait(1.2)
	sc.do_action(&"mask_toggle")
	await _wait(2.0)
	get_tree().quit()


func _until(cond: Callable, max_s: float) -> void:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_s * 1000.0):
			push_warning("dev_nora: timed out waiting")
			return
		await get_tree().process_frame


func _hidden(ear: String, plan: Dictionary) -> void:
	plan["transducer"] = String(_air_transducer())
	await screen.call("run_hidden", patient, ear, plan, false)
	results = (screen as SpeechScreen).get_results()
	Game.set_audiometry_results(results)


## Hoot's tones by the book: air from the profile, unmasked bone at 1k and 4k on the right and
## masked bone there on the left (her bone equals her air: no gaps).
static func textbook_tones(p: PatientProfile) -> Dictionary:
	var res := SpeechSession.tone_results_from(p)
	var ears: Dictionary = res["ears"]
	for pair: Array in [["right", "bc"], ["left", "bc_masked"]]:
		var e := String(pair[0])
		var sheet := {}
		for f: int in BONE_FREQS:
			var t := p.get_threshold(e, f)
			sheet[f] = {"ear": e, "freq": f, "stored_db": t, "true_db": t, "error_db": 0.0, "by_hoot": true, "test": String(pair[1])}
		(ears[e] as Dictionary)[String(pair[1])] = sheet
	return res


## Hoot's speech by the book on top of `t`: both SRTs, Word list 1 on the right, Word list 2 on the
## left (masked), then Word list 3 twenty louder; merged with the tones (§9.5).
static func textbook_results(p: PatientProfile, t: Dictionary) -> Dictionary:
	var s := SpeechSession.new(p, SEED)
	for ear: String in ["right", "left"]:
		s.configure({"test": "srt", "tones": t})
		s.run_by_textbook(ear)
	s.configure({"test": "wrs", "tones": t, "list": SpeechRules.WRS_LISTS[0]})
	s.run_by_textbook("right")
	s.configure({"test": "wrs", "tones": t, "list": SpeechRules.WRS_LISTS[1]})
	s.run_by_textbook("left")
	var lists: Array = ((s.sheets[&"wrs"] as Dictionary).get("left", {}) as Dictionary).get("lists", [])
	var n := int((lists.back() as Dictionary).get("n", 2)) if not lists.is_empty() else 2
	s.configure({"test": "wrs", "tones": t, "list": SpeechRules.WRS_LISTS[2], "louder_than": n, "mask_on": true, "lock_noise": true})
	s.run_by_textbook("left")
	return SpeechSession.merge_results(t, s.build_results())


# ---------------------------------------------------------------- --from=paper

func _papers() -> void:
	clinic.visible = false
	hud.visible = false
	var t := textbook_tones(patient)
	var res := textbook_results(patient, t)
	for g: String in PAPER_GRADES:
		var r := res.duplicate(true)
		if g == "A":
			with_redone_list(r)
		var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
		add_child(paper)
		paper.call_deferred("show_summary", paper_summary(r, g))
		await _wait(2.5)
		await _dev_shot("dev_day4_paper_" + g.to_lower().replace("-", ""))
		paper.queue_free()
		await _wait(0.2)


## A summary as _results() builds it, for grade `g`.
static func paper_summary(res: Dictionary, g: String) -> Dictionary:
	var score: float = {"S": 100.0, "A": 92.0, "C": 64.0, "Do-over": 38.0}.get(g, 80.0)
	var medal := "gold" if g == "S" else ("silver" if g == "A" else "bronze")
	var medals := {}
	for pair: Array in MEDAL_BEATS:
		medals[pair[0]] = medal
	return {"patient_id": PATIENT_ID, "score": score, "grade": g, "accuracy": score / 100.0, "technique": score / 100.0,
		"efficiency": score / 100.0, "care": 1.0, "comfort": 3, "medals": medals, "coins_earned": 80, "coins_total": 200,
		"audiometry": res, "chapter_id": PATIENT_ID, "day": 4, "patient_name": "Nora Nightingale", "next_chapter_id": "rocco",
		"headlines": HEADLINES, "subheads": subheads(res), "medal_beats": MEDAL_BEATS, "weather": WEATHER,
		"sports_script": SPORTS_SCRIPT, "roll_call": {"cards": ROLL_CALL_ORDER.size(), "slips": 0 if g == "S" else 2}}


## The paper's redone row: List 2 tested unmasked (the Ghost's words lifted it), redone on List 3,
## the louder list on List 4.
static func with_redone_list(res: Dictionary) -> void:
	var left: Dictionary = (((res["speech"] as Dictionary)["wrs"] as Dictionary)["left"] as Dictionary)
	var lists: Array = left["lists"]
	if lists.is_empty():
		return
	for i in lists.size():
		var l: Dictionary = lists[i]
		var id := SpeechRules.WRS_LISTS[mini(2 + i, SpeechRules.WRS_LISTS.size() - 1)]
		l["list_id"] = id
		l["list_title"] = SpeechMaterial.title(id)
		l["n"] = int(l["n"]) + 1
		l["seq"] = int(l["seq"]) + 1
	var ghost := (lists[0] as Dictionary).duplicate(true)
	ghost.merge({"n": int(ghost["n"]) - 1, "seq": int(ghost["seq"]) - 1, "list_id": SpeechRules.WRS_LISTS[1],
		"list_title": SpeechMaterial.title(SpeechRules.WRS_LISTS[1]), "masked": false, "mask_db": -1, "pct": 72,
		"band": SpeechRules.wrs_band(72), "counts": false, "redone_by": int((lists[0] as Dictionary)["n"]), "golf": &"bogey"}, true)
	lists.insert(0, ghost)


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _dev_shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
