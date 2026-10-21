extends TestCase
## (Day 5) The SPEECH screen's PARTY mode (CONTRACTS.md §9.18, §9.19; docs/CHAPTER5.md §5): the layout
## and its anchors on screen and clear of Hoot's perch at 1280x720 and 1920x1080; a party list by keys
## (the walk, 1-5, G, LOCK IN, PRESENT refused before LOCK IN) and by mouse (chip clicks, a right
## click, every beat's mouse route); the beat, its key and info, its solver and a stale solver; the
## level locked mid-list and from the start (level_by_hoot), the swapped key style; Hoot's turns
## (hoot_first at x8, silent, the time scale restored exactly, handing back; the practice at x1;
## hoot_only; the Hoot-done key per list); reduced motion; the test changing (anchors and the SRT's layout back); the lines.
## Marco is the stand-in from test_speech_sin_model.gd (his patient file is not in yet).

const SCREEN := "res://ui/speech/speech_screen.tscn"
const Model := preload("res://core/tests/test_speech_sin_model.gd")
const SCRATCH_SAVE := "user://test_speech_screen_party_save.json"
const TEST_SPEED := 8.0
const RNG_SEED := 4321
const PARTY_ANCHORS: Array[String] = ["speech_present_button", "speech_louder_button", "speech_softer_button", "speech_correct_button",
	"speech_incorrect_button", "speech_response", "party_key_1", "party_key_2", "party_key_3", "party_key_4", "party_key_5",
	"party_all_got_button", "party_lock_button", "party_sentence_card", "party_courses", "party_snr_meter"]
const DIAGNOSIS_WORDS: Array[String] = ["tumour", "tumor", "neuroma", "cancer", "schwannoma", "otosclerosis", "meniere", "presbycusis",
	"lesion", "disease", "deaf"]

var _saved_path := ""
var _saved_scale := 1.0
var _saved_quick := true
var _saved_hints := true
var _saved_reduced := false
var _saved_rng_state := 0
var _saved_size := Vector2i.ZERO


func before_each() -> void:
	super()
	_saved_path = Game.save_path
	Game.save_path = SCRATCH_SAVE
	_saved_scale = Engine.time_scale
	_saved_quick = bool(Game.settings.get("quick_visit", true))
	_saved_hints = bool(Game.settings.get("show_key_hints", true))
	_saved_reduced = bool(Game.settings.get("reduced_motion", false))
	_saved_size = tree.root.size
	Game.begin_visit("mike")
	_saved_rng_state = Game.rng.state
	Game.rng.seed = RNG_SEED
	Engine.time_scale = TEST_SPEED
	Hoot.reset_visit()


func after_each() -> void:
	for n: Node in tree.get_nodes_in_group("speech_screen"):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
			n.queue_free()
	Engine.time_scale = _saved_scale
	tree.root.size = _saved_size
	Game.rng.state = _saved_rng_state
	Game.set_key_style("otosuite")
	Game.set_setting("quick_visit", _saved_quick)
	Game.set_setting("show_key_hints", _saved_hints)
	Game.set_setting("reduced_motion", _saved_reduced)
	Game.save_path = _saved_path
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	SpeechTestMode.path_override.clear()
	SpMode.path_override.clear()
	Hoot.clear()
	super()


# ---------------------------------------------------------------- helpers

func _screen() -> SpeechScreen:
	var s := (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	add_node(s)
	return s


func _marco() -> PatientProfile:
	return Model._marco()


func _plan(extra: Dictionary = {}) -> Dictionary:
	var p := {"test": "sin", "tones": SpeechSession.tone_results_from(_marco()), "list": "party_1", "condition": "unaided", "level": 70}
	p.merge(extra, true)
	return p


func _mode(s: SpeechScreen) -> SpMode:
	return s.get("_mode") as SpMode


func _sin(s: SpeechScreen) -> Dictionary:
	return s.get_state().get("sin", {})


func _wait_until(cond: Callable, max_real_s: float = 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_real_s * 1000.0):
			return false
		await wait_frames(1)
	return true


## The player's move: input live, nothing playing, and an answer (if any) is up.
static func _player_turn(s: SpeechScreen) -> bool:
	var st := s.get_state()
	if bool(st["finishing"]):
		return true
	return bool(st["accepting_input"]) and not bool(st["talking"]) and not bool(st["listening"]) \
		and (not bool(st["awaiting_score"]) or bool(st["answer_shown"]))


func _to_window(p: Vector2) -> Vector2:
	return tree.root.get_final_transform() * p


func _click_at(at_canvas: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var at := _to_window(at_canvas)
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await wait_frames(2)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = button
		ev.pressed = pressed
		ev.button_mask = (MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT) if pressed else 0
		Input.parse_input_event(ev)
		await wait_frames(2)


func _click_anchor(id: String, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	await _click_at(Hoot.anchor_screen_rect(id).get_center(), button)


## Play the rest of a list by the textbook: every move is recommended_action(), sent through the
## mode's input (keys) or its mouse route. Returns test_finished's results.
func _play_list(s: SpeechScreen, by_mouse: bool, max_moves: int = 200) -> Dictionary:
	var finished: Array = []
	var cb := func(r: Dictionary) -> void: finished.append(r)
	s.test_finished.connect(cb)
	var moves := 0
	var m := _mode(s)
	while finished.is_empty() and moves < max_moves:
		var ok: bool = await _wait_until(_player_turn.bind(s), 30.0)
		assert_true(ok, "the screen comes back to the player")
		if not ok:
			break
		if bool(s.get_state()["finishing"]):
			var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 30.0)
			assert_true(done, "test_finished after the list")
			break
		var rec := s.session.recommended_action()
		var act := StringName(String(rec["action"]))
		if by_mouse:
			var anchor := m.mouse_for(act, rec)
			if anchor == "":
				anchor = String(SpeechScreen.ACTION_BUTTONS.get(act, ""))
			assert_true(anchor != "", "a mouse route for %s" % act)
			await _click_anchor(anchor)
		else:
			var input := m.input_for(act, rec)
			if input == &"":
				input = SpeechScreen.ACTION_INPUTS.get(act, &"")
			assert_true(input != &"", "an input for %s" % act)
			await tap_action(input)
		moves += 1
	s.test_finished.disconnect(cb)
	return finished[0] if not finished.is_empty() else {}


## Wait for the next answer to be up (the chips awake).
func _await_answer(s: SpeechScreen) -> bool:
	return await _wait_until(func() -> bool:
		var st := s.get_state()
		return bool(_sin(s).get("awaiting_lock", false)) and bool(st["answer_shown"]) and not bool(st["talking"]) and not bool(st["listening"]), 30.0)


# ---------------------------------------------------------------- a list by keys

func test_party_list_by_keys() -> void:
	var s := _screen()
	var locked: Array = []
	var done: Array = []
	var on_locked := func(c: String, n: int, snr: int, count: int) -> void: locked.append([c, n, snr, count])
	var on_done := func(c: String, l: String, t: int, loss: float) -> void: done.append([c, l, t, loss])
	Events.party_sentence_locked.connect(on_locked)
	Events.party_list_done.connect(on_done)
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	var res := await _play_list(s, false)
	Events.party_sentence_locked.disconnect(on_locked)
	Events.party_list_done.disconnect(on_done)
	assert_false(res.is_empty(), "the list finished")
	var sheet: Dictionary = ((res.get("speech", {}) as Dictionary).get("sin", {}) as Dictionary).get("both", {})
	assert_eq(int(sheet.get("lists_done", 0)), 1, "one party list on the both-ears sheet")
	assert_eq(int(sheet.get("misscored", -1)), 0, "scored by the textbook: no slips")
	assert_eq(locked.size(), 6, "party_sentence_locked once a sentence")
	for i in locked.size():
		assert_eq(int(locked[i][1]), i + 1)
		assert_eq(int(locked[i][2]), SpeechRules.SIN_SNRS[i])
	assert_eq(done.size(), 1, "party_list_done once")
	if done.size() == 1:
		assert_eq(String(done[0][1]), "party_1")


# ---------------------------------------------------------------- more helpers

const Golden := preload("res://core/tests/speech_day3_golden.gd")
const PROBE_MODE := "res://core/tests/probe_test_mode.gd"
const PROBE_UI := "res://core/tests/probe_sp_mode.gd"
## The PARTY mode's own anchors (the base buttons stay registered in every test).
const PARTY_ONLY: Array[String] = ["party_key_1", "party_key_2", "party_key_3", "party_key_4", "party_key_5",
	"party_all_got_button", "party_lock_button", "party_sentence_card", "party_courses", "party_snr_meter"]


func _key(code: Key, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _press(code: Key) -> void:
	_key(code, true)
	await wait_frames(2)
	_key(code, false)
	await wait_frames(2)


## Every technique event the session emits from now on: [kind, data].
static func _kinds(sess: SpeechSession) -> Array:
	var out: Array = []
	sess.technique.connect(func(kind: StringName, d: Dictionary) -> void: out.append([kind, d.duplicate(true)]))
	return out


static func _count(events: Array, kind: StringName) -> int:
	var n := 0
	for e: Array in events:
		if e[0] == kind:
			n += 1
	return n


func _remove(s: SpeechScreen) -> void:
	if s.get_parent() != null:
		s.get_parent().remove_child(s)
	s.queue_free()
	await wait_frames(2)


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


func _srt_plan() -> Dictionary:
	return {"test": "srt", "tones": SpeechSession.tone_results_from(_mike())}


static func _list_of(res: Dictionary) -> Dictionary:
	var sheet: Dictionary = ((res.get("speech", {}) as Dictionary).get("sin", {}) as Dictionary).get("both", {})
	var lists: Array = sheet.get("lists", [])
	return lists.back() if not lists.is_empty() else {}


## Hoot's turn on, then off again (bounded); true once he handed back or the list finished.
func _hoot_turn_ends(s: SpeechScreen, max_real_s: float = 30.0) -> bool:
	return await _wait_until(func() -> bool: return not bool(s.get_state()["hoot_turn"]) and _player_turn(s), max_real_s)


# ---------------------------------------------------------------- the layout

func test_layout_and_anchors_at_1280_and_1920() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = size
		await wait_frames(2)
		var s := _screen()
		s.start_test(_marco(), "both", false, _plan())
		await wait_frames(4)
		var vp := Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)
		assert_near(vp.size.x / vp.size.y, 16.0 / 9.0, 0.01, "the logical screen stays 16:9 at %s" % size)
		var hint := Hoot.bubble_rect_hint
		assert_true(hint.size.x > 200.0 and hint.position.x >= 960.0, "Hoot's perch is the right column at %s: %s" % [size, hint])
		for a: String in PARTY_ANCHORS:
			assert_true(Hoot.has_anchor(a), "anchor %s at %s" % [a, size])
			var r := Hoot.anchor_screen_rect(a)
			assert_true(r.size.x > 20.0 and r.size.y > 20.0, "anchor %s has a size at %s" % [a, size])
			assert_true(vp.encloses(r), "anchor %s is on screen at %s: %s" % [a, size, r])
			assert_false(hint.intersects(r), "anchor %s is clear of Hoot's perch at %s" % [a, size])
		for k in range(1, 6):
			var r := Hoot.anchor_screen_rect("party_key_%d" % k)
			assert_true(r.size.x >= 96.0 and r.size.y >= 56.0, "chip %d is at least 96x56 at %s: %s" % [k, size, r.size])
			if k > 1:
				assert_false(r.intersects(Hoot.anchor_screen_rect("party_key_%d" % (k - 1))), "chips %d and %d apart" % [k - 1, k])
		var card := Hoot.anchor_screen_rect("party_sentence_card")
		var courses := Hoot.anchor_screen_rect("party_courses")
		var meter := Hoot.anchor_screen_rect("party_snr_meter")
		var bubble := Hoot.anchor_screen_rect("speech_response")
		for pair: Array in [[card, courses], [card, meter], [courses, meter], [bubble, card], [bubble, courses]]:
			assert_false((pair[0] as Rect2).intersects(pair[1] as Rect2), "the PARTY widgets do not overlap at %s: %s" % [size, pair])
		for c: Control in [s._ladder, s._meter, s._card, s._btn("speech_mask_button"), s._btn("speech_store_button")]:
			assert_false(c.visible, "hidden in the PARTY: %s" % c.name)
		assert_true(s._lcd.hide_tally, "no THIS LEVEL line")
		assert_eq(s._lcd.view.get("noise_note", []), SpModeParty.NOISE_NOTE_PHONES, "NO MASKING where the NOISE box was")
		assert_eq(s.bubble.idle_text, SpModeParty.IDLE_BUBBLE, "the bubble waits for a sentence")
		var titles: Array = []
		for g: Array in s._group_labels:
			titles.append(g[0])
		assert_eq(titles, ["LEVEL + SENTENCE", "KEY WORDS", "BILL"], "the deck's groups")
		var order: Array[String] = ["speech_softer_button", "speech_present_button", "speech_louder_button", "speech_incorrect_button",
			"speech_correct_button", "party_all_got_button", "party_lock_button"]
		for i in range(1, order.size()):
			assert_true(Hoot.anchor_screen_rect(order[i - 1]).end.x <= Hoot.anchor_screen_rect(order[i]).position.x,
				"%s left of %s" % [order[i - 1], order[i]])
		assert_eq([s.button(&"score_correct").text, s.button(&"score_missed").text], ["GOT IT", "MISSED"], "the walk's labels")
		assert_eq(String(s.button(&"store").name), "party_lock_button", "LOCK IN takes over STORE")
		await _remove(s)


# ---------------------------------------------------------------- keys

func test_keys_walk_flip_all_got_and_lock() -> void:
	var s := _screen()
	var locked: Array = []
	var on_locked := func(_c: String, n: int, _snr: int, count: int) -> void: locked.append([n, count])
	Events.party_sentence_locked.connect(on_locked)
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	var ev := _kinds(s.session)
	assert_eq(_sin(s)["marks"], [null, null, null, null, null], "five blank chips")
	await _press(KEY_SPACE)
	assert_true(await _await_answer(s), "sentence 1's answer is up")
	assert_eq(int(_sin(s)["focus_key"]), 0, "the focus starts on chip 1")
	# the walk: Right ticks the focus chip, Left misses the next
	await _press(KEY_RIGHT)
	await _press(KEY_LEFT)
	var sin := _sin(s)
	assert_eq((sin["marks"] as Array).slice(0, 3), [true, false, null], "Right got it, Left missed it")
	assert_eq(int(sin["focus_key"]), 2, "the focus walks on")
	# 3 flips chip 3 (blank -> got -> missed); the keypad's 3 is the same key
	await _press(KEY_3)
	assert_eq(_sin(s)["marks"][2], true, "3: chip 3 got")
	await tap_action(&"party_word_3")
	assert_eq(_sin(s)["marks"][2], false, "3 again: chip 3 missed")
	await _press(KEY_KP_5)
	assert_eq(_sin(s)["marks"][4], true, "keypad 5: chip 5")
	# Space before LOCK IN: refused (lock_first, once a list)
	var trials := s.session.trials_for().size()
	await _press(KEY_SPACE)
	await wait_frames(4)
	assert_eq(s.session.trials_for().size(), trials, "no second sentence over the first")
	assert_eq(_count(ev, &"lock_first"), 1, "lock_first")
	await _press(KEY_SPACE)
	assert_eq(_count(ev, &"lock_first"), 1, "said once a list")
	# G: all five got
	await _press(KEY_G)
	assert_eq(_sin(s)["marks"], [true, true, true, true, true], "G: ALL GOT")
	# S: LOCK IN
	await _press(KEY_S)
	assert_eq(locked.size(), 1, "S locks it in")
	if locked.size() == 1:
		assert_eq(locked[0], [1, 5], "the sentence billed as marked")
	assert_true(_mode(s).get("_courses").filled(1), "plate 1 filled")
	# the level stays where the first sentence put it (mid-list): Up between sentences
	var db := s.session.db
	assert_true(await _wait_until(_player_turn.bind(s), 10.0))
	await _press(KEY_UP)
	assert_eq(s.session.db, db, "the level is locked for the list")
	assert_eq(_count(ev, &"sin_level_locked"), 1, "and Hoot says why")
	# Enter locks in too; blanks bill as missed
	await _press(KEY_SPACE)
	assert_true(bool(s.get_state()["talking"]) or bool(s.get_state()["listening"]), "sentence 2 plays")
	await _press(KEY_DOWN)
	assert_eq(s.session.db, db, "locked while it plays")
	await _press(KEY_ENTER)
	assert_eq(locked.size(), 1, "no LOCK IN before the answer")
	assert_true(await _await_answer(s))
	await _press(KEY_ENTER)
	Events.party_sentence_locked.disconnect(on_locked)
	assert_eq(locked.size(), 2, "Enter locks it in")
	if locked.size() == 2:
		assert_eq(locked[1], [2, 0], "unticked words bill as missed")
	assert_eq(_count(ev, &"blanks"), 1, "the blanks note")


func test_level_set_by_hoot_from_the_start() -> void:
	var s := _screen()
	s.start_test(_marco(), "both", false, _plan({"condition": "omni", "programme": "A", "level": SpeechRules.SIN_AIDED_DB}))
	await wait_frames(3)
	var ev := _kinds(s.session)
	assert_eq(s.session.db, SpeechRules.SIN_AIDED_DB, "the aided talker level")
	assert_true(bool(_sin(s)["level_by_hoot"]), "set by Hoot")
	await tap_action(&"louder")
	await tap_action(&"softer")
	assert_eq(s.session.db, SpeechRules.SIN_AIDED_DB, "locked from the start")
	assert_eq(_count(ev, &"sin_aided_level"), 1, "the aided note, once")
	var view: Dictionary = s._lcd.view
	assert_eq(String(view.get("start_chip", "")), "AIDED: %d dB, set by Hoot" % SpeechRules.SIN_AIDED_DB)
	assert_eq((view.get("chips", []) as Array), ["SPEAKERS", "PROGRAMME A"], "blind: the programme, not its name")
	assert_eq(view.get("noise_note", []), SpModeParty.NOISE_NOTE_FIELD, "the speakers reach both ears: no masking")
	assert_true(_mode(s).get("_party_booth").aided, "the sound field on the booth")


func test_affinity_style_swaps_only_the_level() -> void:
	var s := _screen()
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	Game.set_key_style("affinity")
	await wait_frames(1)
	await _press(KEY_UP)
	assert_eq(s.session.db, 65, "affinity: Up = softer")
	await _press(KEY_DOWN)
	assert_eq(s.session.db, 70, "affinity: Down = louder")
	await _press(KEY_SPACE)
	assert_true(await _await_answer(s))
	await _press(KEY_RIGHT)
	assert_eq(_sin(s)["marks"][0], true, "Right still ticks")
	await _press(KEY_LEFT)
	assert_eq(_sin(s)["marks"][1], false, "Left still misses")
	await _press(KEY_4)
	assert_eq(_sin(s)["marks"][3], true, "4 still flips chip 4")
	await _press(KEY_G)
	assert_eq(_sin(s)["marks"], [true, true, true, true, true], "G still ticks all")
	await _press(KEY_S)
	assert_false(bool(_sin(s)["awaiting_lock"]), "S still locks in")
	# the card names the keys of the style in use
	assert_eq(_mode(s).get("_card").key_got, s.k(&"speech_correct"))


# ---------------------------------------------------------------- the mouse

func test_party_list_by_mouse_at_1920() -> void:
	tree.root.size = Vector2i(1920, 1080)
	await wait_frames(2)
	var s := _screen()
	s.start_test(_marco(), "both", false, _plan({"list": "party_2"}))
	await wait_frames(4)
	var res := await _play_list(s, true)
	assert_false(res.is_empty(), "the list finished by clicks")
	var list := _list_of(res)
	assert_eq(String(list.get("list_id", "")), "party_2")
	assert_eq(int(list.get("player_sentences", 0)), 6, "all six by the player")
	assert_eq(int(list.get("slips", -1)), 0, "clicked by the textbook: no slips")


func test_chip_clicks_and_the_mouse_buttons() -> void:
	var s := _screen()
	var locked: Array = []
	var on_locked := func(_c: String, n: int, _snr: int, count: int) -> void: locked.append([n, count])
	Events.party_sentence_locked.connect(on_locked)
	s.start_test(_marco(), "both", true, _plan())
	await wait_frames(4)
	await _click_anchor("speech_present_button")
	assert_true(await _await_answer(s), "PRESENT by click")
	# a chip click flips it, a second click flips it back
	await _click_anchor("party_key_2")
	assert_eq(_sin(s)["marks"][1], true, "click: chip 2 got")
	await _click_anchor("party_key_2")
	assert_eq(_sin(s)["marks"][1], false, "click again: chip 2 missed")
	await _click_anchor("party_key_4", MOUSE_BUTTON_RIGHT)
	assert_eq(_sin(s)["marks"][3], false, "a right click: missed")
	await _click_anchor("party_key_4", MOUSE_BUTTON_RIGHT)
	assert_eq(_sin(s)["marks"][3], false, "a right click never ticks")
	await _click_anchor("party_all_got_button")
	assert_eq(_sin(s)["marks"], [true, true, true, true, true], "ALL GOT")
	# put the chips right by the truth, by clicks: the beat's key_fix route is the chip
	var guard := 0
	while guard < 8:
		guard += 1
		var rec := s.session.recommended_action()
		if StringName(String(rec["action"])) != &"key_fix":
			break
		assert_eq(_mode(s).mouse_for(&"key_fix", rec), "party_key_%d" % int(rec["key"]))
		await _click_anchor(_mode(s).mouse_for(&"key_fix", rec))
	assert_ne(StringName(String(s.session.recommended_action()["action"])), &"key_fix", "the chips match what he said")
	# after a click, the coach talks mouse
	assert_eq(s.last_device(), &"mouse")
	var line: Array = s._coach_text(s.session.recommended_action())
	assert_eq(String(line[0]), s.say(SinTest.COACH_LINES[&"lock_mouse"]), "the coach's mouse line")
	await _click_anchor("party_lock_button")
	Events.party_sentence_locked.disconnect(on_locked)
	assert_eq(locked.size(), 1, "LOCK IN by click")
	assert_false(bool(_sin(s)["awaiting_lock"]))


## Before an answer is up the chips and the buttons refuse (a wiggle, a line once a visit).
func test_marks_refused_before_the_answer() -> void:
	var s := _screen()
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	Hoot.clear()   # the opening line
	await tap_action(&"party_word_1")
	await tap_action(&"party_all_got")
	await tap_action(&"store")
	assert_false(bool(_sin(s)["awaiting_lock"]), "nothing to mark yet")
	assert_eq(s.session.trials_for().size(), 0, "and nothing played")
	assert_eq(String(Hoot.current_tip().get("text", "")), _mode(s).call("_fill", s.say(SpModeParty.PLAY_FIRST)), "play a sentence first")


# ---------------------------------------------------------------- beats

func test_beats_info_solvers_and_a_stale_solver() -> void:
	var beats: Array = []
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"speech":
			beats.append([info.duplicate(true), solver])
	Events.awaiting_input.connect(cb)
	var finished: Array = []
	var s := _screen()
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	s.start_test(_marco(), "both", false, _plan({"list": "party_3"}))
	var got: bool = await _wait_until(func() -> bool: return not beats.is_empty(), 5.0)
	assert_true(got, "a beat when the screen waits")
	if not got:
		Events.awaiting_input.disconnect(cb)
		return
	var info: Dictionary = beats[0][0]
	for k: String in ["ear", "test", "action", "target_db", "mouse", "slot", "condition", "list", "list_n", "sentence_n", "key", "focus_key"]:
		assert_has(info, k)
	assert_eq([info["ear"], info["test"], info["slot"], info["action"], info["condition"], info["list"], info["list_n"], info["sentence_n"], info["focus_key"]],
		["both", "sin", "both", "present", "unaided", "party_3", 1, 1, 0])
	assert_eq(String((info["mouse"] as Dictionary)["click"]), "speech_present_button")
	var key := String(s.get("_beat_key"))
	assert_true(key.begins_with("sin|sin:both") and key.split("|").size() == 7, "the beat key: %s" % key)
	# a stale solver: the player moves on by key first
	var first: Callable = beats[0][1]
	await tap_action(&"present_tone")
	assert_true(await _await_answer(s))
	var moved: bool = await _wait_until(func() -> bool: return beats.size() >= 2, 5.0)
	assert_true(moved, "a new beat once the answer is up")
	var marks: Array = (_sin(s)["marks"] as Array).duplicate()
	first.call()
	await wait_frames(6)
	assert_eq(s.session.trials_for().size(), 1, "a stale solver presents nothing")
	assert_eq(_sin(s)["marks"], marks, "and marks nothing")
	var now: Dictionary = beats[beats.size() - 1][0]
	assert_has(["key_got", "key_missed"], String(now["action"]), "the walk")
	assert_eq(int(now["key"]), 1)
	assert_eq(int(now["focus_key"]), 1, "focus_key is 1-based")
	assert_eq(String((now["mouse"] as Dictionary)["click"]), "speech_correct_button" if now["action"] == "key_got" else "speech_incorrect_button")
	var walk: Callable = beats[beats.size() - 1][1]
	walk.call()
	walk.call()   # the same solver twice: one mark
	await wait_frames(6)
	var after: Array = _sin(s)["marks"]
	assert_true(after[0] != null and after[1] == null, "one mark")
	# a slip on purpose: the beat becomes key_fix on that chip, routed to the chip (mouse) and its key
	await tap_action(&"party_word_2")
	var fix: bool = await _wait_until(func() -> bool: return String((beats[beats.size() - 1][0] as Dictionary)["action"]) in ["key_fix", "key_got", "key_missed"], 5.0)
	assert_true(fix)
	var rec := s.session.recommended_action()
	if StringName(String(rec["action"])) == &"key_fix":
		var last: Dictionary = beats[beats.size() - 1][0]
		assert_eq([last["action"], last["key"], String((last["mouse"] as Dictionary)["click"])], ["key_fix", int(rec["key"]), "party_key_%d" % int(rec["key"])])
		assert_eq(_mode(s).input_for(&"key_fix", rec), StringName("party_word_%d" % int(rec["key"])))
	# the rest of the list by its solvers
	var used := beats.size()
	var calls := 0
	(beats[used - 1][1] as Callable).call()
	calls += 1
	var t0 := Time.get_ticks_msec()
	while finished.is_empty() and Time.get_ticks_msec() - t0 < 40000:
		if beats.size() > used:
			used = beats.size()
			(beats[used - 1][1] as Callable).call()
			calls += 1
		await wait_frames(1)
	Events.awaiting_input.disconnect(cb)
	assert_false(finished.is_empty(), "the solvers finish the list")
	if finished.is_empty():
		return
	var actions := {}
	for b: Array in beats:
		actions[String((b[0] as Dictionary)["action"])] = String(((b[0] as Dictionary)["mouse"] as Dictionary)["click"])
	assert_eq(actions.get("lock", ""), "party_lock_button", "LOCK IN's mouse route")
	assert_eq(actions.get("present", ""), "speech_present_button")
	assert_eq(int(_list_of(finished[0]).get("player_sentences", 0)), 6)


# ---------------------------------------------------------------- Hoot's turns

func test_hoot_first_three_courses_then_hands_back() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	var tips: Array = []
	var on_tip := func(t: Dictionary) -> void: tips.append(String(t["text"]))
	Events.hoot_tip_shown.connect(on_tip)
	var base := Engine.time_scale
	s.start_test(_marco(), "both", false, _plan({"hoot_first": 3}))
	var on: bool = await _wait_until(func() -> bool: return bool(s.get_state()["hoot_turn"]), 5.0)
	assert_true(on, "Hoot serves first")
	assert_has(tips, "My turn: I'll serve the first 3 courses at 8x. Watch the plates!")
	var fast: bool = await _wait_until(func() -> bool: return is_equal_approx(Engine.time_scale, base * SpeechScreen.HOOT_SPEED), 5.0)
	assert_true(fast, "x8")
	var loud := false
	var t0 := Time.get_ticks_msec()
	while bool(s.get_state()["hoot_turn"]) and Time.get_ticks_msec() - t0 < 30000:
		loud = loud or s.voice.is_babbling() or s.voice.is_playing()
		await wait_frames(1)
	Events.hoot_tip_shown.disconnect(on_tip)
	assert_false(bool(s.get_state()["hoot_turn"]), "he hands back")
	assert_false(loud, "his x8 turn is silent: no party, no talker")
	assert_eq(Engine.time_scale, base, "the time scale restored exactly")
	var sin := _sin(s)
	assert_eq([int(sin["sentence_n"]), bool(sin["awaiting_lock"])], [4, false], "at sentence 4, the Main course")
	assert_true(s.session.scoring, "scoring is back")
	var courses: Array = _mode(s).get("_courses").courses
	for i in 3:
		assert_true(bool((courses[i] as Dictionary).get("by_hoot", false)), "plate %d is Hoot's" % (i + 1))
	var res := await _play_list(s, false)
	var list := _list_of(res)
	assert_eq([int(list.get("player_sentences", 0)), int(list.get("hoot_sentences", 0))], [3, 3], "three each")


func test_level_first_then_hoot_first() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	s.start_test(_marco(), "both", false, _plan({"hoot_first": 2, "level_first": true, "level": 50}))
	await wait_frames(4)
	assert_false(bool(s.get_state()["hoot_turn"]), "the level is the player's first")
	for i in 4:
		await tap_action(&"louder")
	assert_eq(s.session.db, 70)
	await tap_action(&"present_tone")
	await wait_frames(2)
	assert_true(bool(s.get_state()["hoot_turn"]), "PRESENT hands the first courses to Hoot")
	assert_true(await _hoot_turn_ends(s), "he hands back")
	assert_eq(s.session.db, 70, "at the player's level")
	assert_eq(int(_sin(s)["sentence_n"]), 3, "after two courses")
	var res := await _play_list(s, false)
	var list := _list_of(res)
	assert_true(bool(list.get("level_mine", false)), "the level was the player's")
	assert_eq(int(list.get("player_sentences", 0)), 4)


func test_practice_by_hoot_at_x1() -> void:
	var s := _screen()
	var locked: Array = []
	var on_locked := func(_c: String, n: int, _snr: int, _count: int) -> void: locked.append(n)
	Events.party_sentence_locked.connect(on_locked)
	var base := Engine.time_scale
	s.start_test(_marco(), "both", true, _plan({"practice": "party_practice"}))
	await wait_frames(4)
	var line: Array = s._coach_text(s.session.recommended_action())
	assert_eq(String(line[2]), "practice", "the coach asks for the practice first")
	await tap_action(&"present_tone")
	await wait_frames(2)
	assert_true(bool(s.get_state()["hoot_turn"]), "Hoot plays the practice")
	var heard := false
	var at_x1 := true
	var t0 := Time.get_ticks_msec()
	while bool(s.get_state()["hoot_turn"]) and Time.get_ticks_msec() - t0 < 30000:
		heard = heard or s.voice.is_babbling()
		at_x1 = at_x1 and is_equal_approx(Engine.time_scale, base)
		await wait_frames(1)
	Events.party_sentence_locked.disconnect(on_locked)
	assert_false(bool(s.get_state()["hoot_turn"]), "he hands back after it")
	assert_true(heard, "the practice plays at x1, party and all")
	assert_true(at_x1, "never sped up")
	assert_eq(Engine.time_scale, base)
	assert_eq(locked.size(), 0, "the practice fills no plate")
	assert_eq(s.session.trials_for().size(), 0, "and is not a sentence of the list")
	var sin := _sin(s)
	assert_eq([int(sin["sentence_n"]), bool(sin["practice_pending"])], [1, false], "the Starter is next")
	assert_eq(s.bubble.aside, SpModeParty.ASIDE_PRACTICE, "Marco's aside")
	var line2: Array = s._coach_text(s.session.recommended_action())
	assert_eq([String(line2[0]), String(line2[2])], [SpModeParty.COACH_FIRST, "first"], "your turn")
	var res := await _play_list(s, false)
	assert_eq(int(_list_of(res).get("player_sentences", 0)), 6, "the player plays the whole list")


func test_hoot_only_runs_the_list() -> void:
	Game.set_setting("quick_visit", false)
	var s := _screen()
	s.quick_visit = false
	var beats: Array = []
	var cb := func(beat: StringName, _info: Dictionary, _solver: Callable) -> void:
		if beat == &"speech":
			beats.append(beat)
	Events.awaiting_input.connect(cb)
	var locked: Array = []
	var on_locked := func(_c: String, n: int, _snr: int, _count: int) -> void: locked.append(n)
	Events.party_sentence_locked.connect(on_locked)
	var finished: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	var base := Engine.time_scale
	s.start_test(_marco(), "both", false, _plan({"hoot_only": true, "hoot_turn_after": 0}))
	var on: bool = await _wait_until(func() -> bool: return bool(s.get_state()["hoot_turn"]), 5.0)
	assert_true(on, "hoot_only: Hoot takes it on a full visit too")
	var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 40.0)
	Events.awaiting_input.disconnect(cb)
	Events.party_sentence_locked.disconnect(on_locked)
	assert_true(done, "Hoot finishes the list")
	assert_eq(Engine.time_scale, base, "the time scale restored exactly")
	assert_eq(beats.size(), 0, "no player beats in his turn")
	assert_eq(locked, [1, 2, 3, 4, 5, 6], "six plates")
	if done:
		var list := _list_of(finished[0])
		assert_true(bool(list.get("by_hoot", false)), "Hoot's list")
		assert_eq(int(list.get("hoot_sentences", 0)), 6)


func test_hoot_turn_after_two_sentences() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	var tips: Array = []
	var on_tip := func(t: Dictionary) -> void: tips.append(String(t["text"]))
	Events.hoot_tip_shown.connect(on_tip)
	var finished: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	s.start_test(_marco(), "both", false, _plan({"hoot_turn_after": 2}))
	await wait_frames(3)
	assert_has(tips, "Both ears, all yours for 2 sentences! Then I'll take a turn.")
	var m := _mode(s)
	var moves := 0
	while int(m.call("_locked_count")) < 2 and moves < 40:
		var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
		assert_true(ok)
		if not ok:
			break
		assert_false(bool(s.get_state()["hoot_turn"]), "still the player's list")
		var rec := s.session.recommended_action()
		var input := m.input_for(StringName(String(rec["action"])), rec)
		await tap_action(input if input != &"" else SpeechScreen.ACTION_INPUTS[StringName(String(rec["action"]))])
		moves += 1
	await wait_frames(2)
	assert_true(bool(s.get_state()["hoot_turn"]), "Hoot takes over after two sentences")
	assert_has(tips, "Nice work! My turn: I'll finish this list at 8x. Watch the plates!")
	var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 40.0)
	Events.hoot_tip_shown.disconnect(on_tip)
	assert_true(done)
	if done:
		var list := _list_of(finished[0])
		assert_eq([int(list.get("player_sentences", 0)), int(list.get("hoot_sentences", 0))], [2, 4])


## The coach's walk line follows the focus chip: its key names the focus, so the ghost hand moves along
## the card with each mark instead of staying on a chip already marked.
func test_the_walk_hand_follows_the_focus() -> void:
	var s := _screen()
	s.start_test(_marco(), "both", true, _plan())
	await wait_frames(3)
	await tap_action(&"present_tone")
	assert_true(await _await_answer(s))
	var first: Array = s._coach_text(s.session.recommended_action())
	assert_eq([String(first[1]), String(first[2])], ["party_key_1", "tick"], "the first line: chip 1")
	var m := _mode(s)
	for i in 3:
		var rec := s.session.recommended_action()
		await tap_action(m.input_for(StringName(String(rec["action"])), rec))
		var line: Array = s._coach_text(s.session.recommended_action())
		assert_eq([String(line[1]), String(line[2])], ["party_key_%d" % (i + 2), "walk%d" % (i + 1)], "the hand on the focus chip after mark %d" % (i + 1))
		assert_eq(int(_sin(s)["focus_key"]), i + 1)


## A slip outranks the gentle reminders: at LOCK IN the little-words tip on screen makes way, and Hoot
## names the first wrong chip at once (the others flash).
func test_a_slip_line_replaces_the_little_words_tip() -> void:
	var s := _screen()
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	await tap_action(&"present_tone")
	assert_true(await _await_answer(s))
	Hoot.clear()
	var hold := String(_mode(s).call("_fill", s.say(String(SinTest.TIPS[&"little_words"]))))
	Hoot.say(hold, Hoot.HIGH, "party_sentence_card", "", 4.0)
	assert_eq(String(Hoot.current_tip().get("text", "")), hold, "the little-words tip is up")
	# every chip the opposite of what he said: five slips
	var cur: Dictionary = s.session.current
	var heard: Array = cur["heard"]
	for i in heard.size():
		await tap_action(&"speech_incorrect" if bool(heard[i]) else &"speech_correct")
	await tap_action(&"store")
	await wait_frames(2)
	var first := SinTest.misscored_line(String(cur["key_words"][0]), String(cur["said_words"][0]), StringName(cur["said_kinds"][0]), not bool(heard[0]))
	assert_eq(String(Hoot.current_tip().get("text", "")), s.say(first), "Hoot names chip 1 now, not after the reminder")
	assert_eq(Hoot.queued_count(), 0, "and the other four slips only flash")


## The Hoot-done key is the list (H17), not the ear: a second party list on the same "both" slot gets
## its own takeover after the player's share.
func test_second_list_on_both_gets_its_own_hoot_turn() -> void:
	Game.set_setting("quick_visit", true)
	var s := _screen()
	s.quick_visit = true
	for list_id: String in ["party_1", "party_2"]:
		var finished: Array = []
		var cb := func(r: Dictionary) -> void: finished.append(r)
		s.test_finished.connect(cb)
		s.start_test(_marco(), "both", false, _plan({"list": list_id, "hoot_turn_after": 1}))
		await wait_frames(3)
		var m := _mode(s)
		var key := s.session.measure_key()
		var moves := 0
		while int(m.call("_locked_count")) < 1 and moves < 20:
			var ok: bool = await _wait_until(_player_turn.bind(s), 10.0)
			assert_true(ok)
			if not ok:
				break
			var rec := s.session.recommended_action()
			var input := m.input_for(StringName(String(rec["action"])), rec)
			await tap_action(input if input != &"" else SpeechScreen.ACTION_INPUTS[StringName(String(rec["action"]))])
			moves += 1
		await wait_frames(2)
		assert_true(bool(s.get_state()["hoot_turn"]), "Hoot takes over %s after one sentence" % list_id)
		var done: bool = await _wait_until(func() -> bool: return not finished.is_empty(), 40.0)
		s.test_finished.disconnect(cb)
		assert_true(done, "%s finished" % list_id)
		if done:
			var list := _list_of(finished[0])
			assert_eq(String(list.get("list_id", "")), list_id)
			assert_eq([int(list.get("player_sentences", 0)), int(list.get("hoot_sentences", 0))], [1, 5], "one for the player, five for Hoot")
		assert_true((s.get("_hoot_done_ears") as Dictionary).has(key), "the Hoot-done key is the list: %s" % key)
	assert_eq((s.get("_hoot_done_ears") as Dictionary).size(), 2, "one Hoot-done key per list on the same slot")
	assert_eq(s.session.slot, "both")


func test_no_takeover_without_quick_visit() -> void:
	Game.set_setting("quick_visit", false)
	var s := _screen()
	s.quick_visit = false
	var tips: Array = []
	var on_tip := func(t: Dictionary) -> void: tips.append(String(t["text"]))
	Events.hoot_tip_shown.connect(on_tip)
	s.start_test(_marco(), "both", false, _plan({"hoot_turn_after": 0}))
	await wait_frames(10)
	Events.hoot_tip_shown.disconnect(on_tip)
	assert_false(bool(s.get_state()["hoot_turn"]), "a full visit: the player runs the list")
	assert_true(bool(s.get_state()["accepting_input"]))
	assert_has(tips, "Both ears, all on your own! I'll only chime in if something goes wrong.")


# ---------------------------------------------------------------- reduced motion

func test_reduced_motion_is_still() -> void:
	# the widgets on their own: the meter's meet shake and the waiter's tray
	var meter := SpSnrMeter.new()
	add_node(meter)
	var card := SpSentenceCard.new()
	card.size = Vector2(900, 120)
	add_node(card)
	card.show_sentence("Six purple geese sang under the moon.", ["Six", "purple", "geese", "sang", "moon"], [null, null, null, null, null], 1, 6, "Starter", 25, false, true)
	meter.set_view({"snr": 5})
	meter.set_view({"snr": 0})
	assert_true(float(meter.get("_meet")) > 0.0, "the bars shake when they meet")
	card.state = &"marking"
	card.lock_in([true, false, false, true, false])
	assert_true(card.tray_running(), "the misses ride off on the tray")
	Game.set_setting("reduced_motion", true)
	meter.reset()
	meter.set_view({"snr": 5})
	meter.set_view({"snr": 0})
	assert_eq(float(meter.get("_meet")), 0.0, "reduced motion: no shake")
	card.show_sentence("Six purple geese sang under the moon.", ["Six", "purple", "geese", "sang", "moon"], [null, null, null, null, null], 2, 6, "Soup", 20, false, true)
	card.state = &"marking"
	card.lock_in([true, false, false, true, false])
	assert_false(card.tray_running(), "reduced motion: the misses just grey out")
	# on the screen: the peas land at once
	var s := _screen()
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	await tap_action(&"present_tone")
	assert_true(await _await_answer(s))
	await tap_action(&"store")
	var courses: SpCourses = _mode(s).get("_courses")
	assert_true(courses.filled(1))
	assert_true(float((courses.get("_drop") as Dictionary).get(1, -1.0)) >= SpCourses.PEA_DROP_S, "the peas are down at once")
	assert_false((_mode(s).get("_card") as SpSentenceCard).tray_running(), "no tray on the screen either")


# ---------------------------------------------------------------- the test changing

func test_srt_party_srt_restores_the_layout() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", false, _srt_plan())
	await wait_frames(3)
	var layout0 := Golden._layout(s)
	var anchors0 := Golden._anchors(s)
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	assert_true(_mode(s) is SpModeParty, "the PARTY mode")
	for a: String in PARTY_ONLY:
		assert_true(Hoot.has_anchor(a), "party anchor " + a)
	s.start_test(_mike(), "right", false, _srt_plan())
	await wait_frames(3)
	assert_true(_mode(s) == null, "no mode for the SRT")
	var now := Golden._layout(s)
	for id: String in layout0:
		assert_eq(now.get(id), layout0[id], "the SRT layout is back: " + id)
	assert_eq(Golden._anchors(s), anchors0, "the SRT anchors are back")
	for a: String in PARTY_ONLY:
		assert_false(Hoot.has_anchor(a), "party anchor gone: " + a)
	for n: String in ["PartySentenceCard", "PartyCourses", "PartySnrMeter", "PartyBooth"]:
		var w := s.find_child(n, true, false) as Control
		assert_true(w != null and not w.visible, "%s hidden" % n)
	assert_eq(s.bubble.aside, "")
	assert_eq(s.bubble.idle_text, SpBubble.IDLE_TEXT, "the bubble waits for a word again")
	assert_false(s._lcd.view.has("noise_note"), "the NOISE box is back")
	assert_false(s.voice.is_babbling())


func test_word_probe_then_party_drops_its_anchors() -> void:
	SpeechTestMode.path_override[&"wrs"] = PROBE_MODE
	SpMode.path_override[&"wrs"] = PROBE_UI
	var s := _screen()
	s.quick_visit = false
	s.start_test(_mike(), "right", false, {"test": "wrs", "tones": SpeechSession.tone_results_from(_mike()), "level": 45, "target": 55})
	await wait_frames(3)
	assert_true(Hoot.has_anchor("probe_wrs_panel"), "the WORD probe's anchor")
	s.start_test(_marco(), "both", false, _plan())
	await wait_frames(3)
	assert_true(_mode(s) is SpModeParty, "the PARTY mode")
	assert_false(Hoot.has_anchor("probe_wrs_panel") or Hoot.has_anchor("probe_wrs_ready_button"), "the probe's anchors went")
	for a: String in PARTY_ONLY:
		assert_true(Hoot.has_anchor(a), "party anchor " + a)
	assert_eq(String(s.button(&"store").name), "party_lock_button")


func test_day3_srt_never_reaches_the_party_mode() -> void:
	var s := _screen()
	s.start_test(_mike(), "right", true, _srt_plan())
	await wait_frames(3)
	assert_true(_mode(s) == null, "no mode")
	assert_true((s.get("_modes") as Dictionary).is_empty(), "no mode made at all")
	assert_true(s.find_child("PartySentenceCard", true, false) == null, "no PARTY widget built")
	for a: String in PARTY_ONLY:
		assert_false(Hoot.has_anchor(a), "no party anchor " + a)


# ---------------------------------------------------------------- the lines

## Every line the PARTY mode can say, filled as the screen fills it (the patient's words at their
## longest, both key styles): 18 words or fewer, no token left, no diagnosis, no blame.
func test_lines_fit_and_never_name_a_diagnosis() -> void:
	var s := _screen()
	s.start_test(_marco(), "both", true, _plan({"practice": "party_practice"}))
	await wait_frames(3)
	var raw: Array[String] = [SpModeParty.ASIDE_PRACTICE, SpModeParty.ASIDE_LOUDER_SOUP, SpModeParty.COACH_TICK,
		SpModeParty.COACH_FIX % [5, 5], SpModeParty.COACH_LEVEL % [90, "louder"], SpModeParty.COACH_LEVEL % [90, "softer"],
		SpModeParty.COACH_PRACTICE, SpModeParty.COACH_FIRST, SpModeParty.COACH_MAIN, SpModeParty.COACH_LISTEN, SpModeParty.WAIT_ANSWER,
		SpModeParty.PLAY_FIRST, "My turn: I'll serve the first 3 courses at 8x. Watch the plates!",
		"Nice work! My turn: I'll finish this list at 8x. Watch the plates!", "My turn! I'll run this list at 8x. Watch the plates!",
		"Both ears, all yours for 12 sentences! Then I'll take a turn.", "Both ears, all on your own! I'll only chime in if something goes wrong."]
	for t: String in SinTest.TIPS.values():
		raw.append(t)
	for t: String in SinTest.MISSCORED_SIN.values():
		raw.append(t)
	for t: String in SinTest.BENEFIT_LINES.values():
		raw.append(t)
	for t: String in SinTest.COACH_LINES.values():
		raw.append(t)
	var long := {"{said}": "strawberries", "{word}": "strawberries", "{target}": "90", "{aided}": "50", "{total}": "30",
		"{loss}": "12.5", "{benefit}": "12.5", "{crit}": "3.5"}
	for style: String in ["otosuite", "affinity"]:
		Game.set_key_style(style)
		await wait_frames(1)
		for r: String in raw:
			var t := r
			for tok: String in long:
				t = t.replace(tok, long[tok])
			t = String(_mode(s).call("_fill", s.say(t)))
			_check_line(t, style)
	# and every tip Hoot shows on a coached list with its practice, by keys
	Game.set_key_style("otosuite")
	var tips: Array = []
	var on_tip := func(tip: Dictionary) -> void: tips.append(String(tip["text"]))
	Events.hoot_tip_shown.connect(on_tip)
	var res := await _play_list(s, false)
	Events.hoot_tip_shown.disconnect(on_tip)
	assert_false(res.is_empty(), "the coached list finished")
	assert_true(tips.size() >= 4, "the coach spoke")
	for t: String in tips:
		_check_line(t, "shown")


func _check_line(t: String, where: String) -> void:
	assert_true(t.split(" ", false).size() <= Hoot.MAX_WORDS, "18 words or fewer (%s): %s" % [where, t])
	assert_false(t.contains("{") or t.contains("}"), "no token left (%s): %s" % [where, t])
	var low := t.to_lower()
	for w: String in DIAGNOSIS_WORDS:
		assert_false(low.contains(w), "no diagnosis (%s): %s" % [where, t])
	for w: String in ["you failed", "wrong again", "careless", "lazy"]:
		assert_false(low.contains(w), "no blame (%s): %s" % [where, t])
