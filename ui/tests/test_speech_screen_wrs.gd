extends TestCase
## (Day 4) The SPEECH screen's WORD mode (CONTRACTS.md §9.17, §9.19; docs/CHAPTER4.md §5): the layout
## and its anchors on screen and clear of Hoot's perch at 1280x720 and 1920x1080 (the hidden base
## widgets, the deck's groups, the Call it card); a word list by keys, by the mouse route of every
## beat and by the beat solvers (and a stale solver); no STORE, one level and one noise per list;
## Hoot's x8 turn (the time scale restored exactly, the Hoot-done key per list); the swapped key
## style (only the level swaps; the coach's lines name the right key in both styles); the two-press
## confirm with the BOO chip (solo) and the denial (coached), no lurking Ghost on a solo list; the
## lens (V and its button, the word always crisp, the alpha from the MEASURED thresholds, the Banana
## Board sliding in); no band ruler before a list ends; the Call it card at the right word with both
## keys and both buttons; the tea demo (nothing presented, nothing locked); asides never block;
## reduced motion; Day 3's SRT never reaching the mode; and every line the mode can say.
## Nora is the stand-in from core/tests/test_speech_wrs.gd until core/patients/nora.tres lands.

const SCREEN := "res://ui/speech/speech_screen.tscn"
const Wrs := preload("res://core/tests/test_speech_wrs.gd")
const SCRATCH_SAVE := "user://test_speech_screen_wrs_save.json"
const TEST_SPEED := 8.0
const RNG_SEED := 2468
const WORD_ANCHORS: Array[String] = ["speech_present_button", "speech_louder_button", "speech_softer_button", "speech_correct_button",
	"speech_incorrect_button", "speech_mask_button", "speech_lens_button", "speech_word_card", "speech_response", "speech_score_strip",
	"speech_banana", "speech_ghost", "speech_ear_compare", "call_it_yes_button", "call_it_no_button"]
## The anchors that only exist while their moment is on (the Call it card's two buttons).
const CALL_ANCHORS: Array[String] = ["call_it_yes_button", "call_it_no_button"]
const WORD_ONLY: Array[String] = ["speech_lens_button", "speech_score_strip", "speech_banana", "speech_ghost", "speech_ear_compare",
	"call_it_yes_button", "call_it_no_button"]
const DIAGNOSIS_WORDS: Array[String] = ["tumour", "tumor", "neuroma", "schwannoma", "cancer", "growth", "stroke", "meniere", "lesion",
	"disease", "deaf"]
## Her chatty-hit lines: each follows the word itself ("Sock! Like a good downbeat."; contract §9.12.1).
const CHATTER: Array[String] = ["Like a good downbeat.", "Lovely and clear, that {word}."]
const SILENCES: Array[String] = ["Sorry?", "Mm?"]
const TEA_DEMO := {
	"text": "Fancy a cup of tea?", "level": 50,
	"chunks": [["F", "f"], ["a", "vowel"], ["n", "n"], ["c", "s"], ["y", "vowel"], [" ", ""], ["a", "vowel"], [" ", ""], ["c", "k"],
		["u", "vowel"], ["p", "p"], [" ", ""], ["o", "vowel"], ["f", "v"], [" ", ""], ["t", "t"], ["ea", "vowel"], ["?", ""]],
	"lines": [["hoot", "This is chatting level, 50. Watch what reaches her left ear."], ["nora", "Candy... a canoe? At my age?"],
		["hoot", "That's her complaint: voices, but not words!"]],
}

var _saved_path := ""
var _saved_scale := 1.0
var _saved_quick := true
var _saved_hints := true
var _saved_reduced := false
var _saved_rng_state := 0
var _saved_size := Vector2i.ZERO
## Every awaiting_input of the test: [beat, info, solver].
var _beats: Array = []
var _on_beat_cb: Callable
## Every technique_event kind of the test.
var _techs: Array[StringName] = []
var _on_tech_cb: Callable


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
	_beats = []
	_on_beat_cb = func(beat: StringName, info: Dictionary, solver: Callable) -> void: _beats.append([beat, info.duplicate(true), solver])
	Events.awaiting_input.connect(_on_beat_cb)
	_techs = []
	_on_tech_cb = func(kind: StringName, _data: Dictionary) -> void: _techs.append(kind)
	Events.technique_event.connect(_on_tech_cb)


func after_each() -> void:
	if Events.awaiting_input.is_connected(_on_beat_cb):
		Events.awaiting_input.disconnect(_on_beat_cb)
	if Events.technique_event.is_connected(_on_tech_cb):
		Events.technique_event.disconnect(_on_tech_cb)
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
	Hoot.clear()
	super()


# ---------------------------------------------------------------- helpers

func _screen(quick: bool = false) -> SpeechScreen:
	var s := (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	add_node(s)
	s.quick_visit = quick
	return s


func _nora() -> PatientProfile:
	return (Wrs.new() as Object).call("_nora") as PatientProfile


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


## Word list 1 on her right, as Day 4 plays it (CONTRACTS.md §9.21), plus `extra`.
func _plan_1(extra: Dictionary = {}) -> Dictionary:
	var p := {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_1", "lens_try_after": 2, "call_it": [&"faint_hit"], "chatter": CHATTER}
	p.merge(extra, true)
	return p


## Word list 2 on her left (solo), without the tea demo unless `extra` brings it.
func _plan_2(extra: Dictionary = {}) -> Dictionary:
	var p := {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_2", "level": SpeechRules.CHAT_DB, "ensure_audible_miss_by": 6,
		"audible_stamp": true, "call_it": [&"audible_miss"], "aside_by": 8, "self_correct": true, "chatter": CHATTER, "silences": SILENCES,
		"confirmed_wrong_hoot_after": 3}
	p.merge(extra, true)
	return p


func _srt_plan() -> Dictionary:
	return {"test": "srt", "tones": SpeechSession.tone_results_from(_mike())}


func _mode(s: SpeechScreen) -> SpModeWord:
	return s.get("_mode") as SpModeWord


func _wrs(s: SpeechScreen) -> Dictionary:
	return s.get_state().get("wrs", {})


func _wait_until(cond: Callable, max_real_s: float = 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_real_s * 1000.0):
			return false
		await wait_frames(1)
	return true


## Canvas position -> window position (the stretch scales the canvas).
func _to_window(p: Vector2) -> Vector2:
	return tree.root.get_final_transform() * p


func _click_anchor(id: String) -> void:
	var at := _to_window(Hoot.anchor_screen_rect(id).get_center())
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await wait_frames(2)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)
		await wait_frames(2)


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_frames(2)


## The input that does a beat's move: the mode's own (V, the Call it guess), else the screen's.
static func _input_of(s: SpeechScreen, info: Dictionary) -> StringName:
	var act := StringName(String(info.get("action", "none")))
	var args := {"guess": String(info.get("best", "call_it_yes_button")) == "call_it_yes_button"}
	var m := s.get("_mode") as SpMode
	var input: StringName = m.input_for(act, args) if m != null else &""
	if input == &"":
		input = SpeechScreen.ACTION_INPUTS.get(act, &"")
	return input


## Plays the list from its beats until test_finished: how = "keys" (the move's input), "mouse" (a
## click on the beat's mouse route) or "solver" (the beat's own solver). Returns the results.
func _play_list(s: SpeechScreen, how: String, max_moves: int = 260) -> Dictionary:
	var finished: Array = []
	var cb := func(r: Dictionary) -> void: finished.append(r)
	s.test_finished.connect(cb)
	var seen := 0
	var moves := 0
	while finished.is_empty() and moves < max_moves:
		var ok: bool = await _wait_until(func() -> bool: return _beats.size() > seen or not finished.is_empty() \
			or bool(s.get_state()["finishing"]), 25.0)
		if not ok:
			fail("the screen stalled after %d moves (%s): %s" % [moves, how, s.get_state().get("wrs", {})])
			break
		if not finished.is_empty() or bool(s.get_state()["finishing"]):
			await _wait_until(func() -> bool: return not finished.is_empty(), 25.0)
			break
		seen = _beats.size()
		var b: Array = _beats[seen - 1]
		var info: Dictionary = b[1]
		match how:
			"keys":
				var input := _input_of(s, info)
				assert_ne(input, &"", "a key for %s" % info.get("action", ""))
				await tap_action(input)
			"mouse":
				var click := String((info["mouse"] as Dictionary).get("click", ""))
				assert_true(Hoot.has_anchor(click), "the mouse route %s is an anchor" % click)
				await _click_anchor(click)
			_:
				(b[2] as Callable).call()
		moves += 1
	s.test_finished.disconnect(cb)
	return finished[0] if not finished.is_empty() else {}


## Plays (by the solvers) until `cond` holds or the list ends. The newest beat may still be live
## (the screen waits on it), so it is solved too; a stale solver is a no-op.
func _play_until(s: SpeechScreen, cond: Callable, max_real_s: float = 25.0) -> bool:
	var seen := maxi(0, _beats.size() - 1)
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_real_s * 1000.0) or bool(s.get_state()["finishing"]):
			return bool(cond.call())
		if _beats.size() > seen:
			seen = _beats.size()
			await wait_frames(1)
			if bool(cond.call()):
				return true
			(_beats[seen - 1][2] as Callable).call()
		await wait_frames(1)
	return true


## Taps LOUDER / SOFTER (by keys) until the dial reads `db`.
func _dial_to(s: SpeechScreen, db: int) -> void:
	var guard := 0
	while s.session.db != db and guard < 30:
		guard += 1
		await tap_action(&"louder" if s.session.db < db else &"softer")


## How many times the session told the screen `kind` (technique_event).
func _kinds(_sess: SpeechSession, kind: StringName) -> int:
	return _techs.count(kind)


func _remove(s: SpeechScreen) -> void:
	if s.get_parent() != null:
		s.get_parent().remove_child(s)
	s.queue_free()
	await wait_frames(2)


static func _sheet_of(res: Dictionary, ear: String) -> Dictionary:
	return (((res.get("speech", {}) as Dictionary).get("wrs", {}) as Dictionary).get(ear, {}) as Dictionary)


# ---------------------------------------------------------------- layout

func test_layout_and_anchors_at_1280_and_1920() -> void:
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		tree.root.size = size
		await wait_frames(2)
		var s := _screen()
		s.start_test(_nora(), "right", true, _plan_1())
		s.memory["compare_shown"] = true   # the ear compare's slot, as it is once both ears have a list
		s._layout()
		await wait_frames(4)
		var vp := Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size)
		assert_near(vp.size.x / vp.size.y, 16.0 / 9.0, 0.01, "the logical screen stays 16:9 at %s" % size)
		var hint := Hoot.bubble_rect_hint
		assert_true(hint.size.x > 200.0 and hint.position.x >= 960.0, "Hoot's perch is the right column at %s: %s" % [size, hint])
		for a: String in WORD_ANCHORS:
			assert_true(Hoot.has_anchor(a), "anchor %s at %s" % [a, size])
			if a in CALL_ANCHORS:
				continue
			var r := Hoot.anchor_screen_rect(a)
			assert_true(r.size.x > 20.0 and r.size.y > 20.0, "anchor %s has a size at %s: %s" % [a, size, r])
			assert_true(vp.encloses(r), "anchor %s is on screen at %s: %s" % [a, size, r])
			assert_false(hint.intersects(r), "anchor %s is clear of Hoot's perch at %s" % [a, size])
		var m := _mode(s)
		var areas: Array = [["strip", m.strip.get_global_rect()], ["banana", m.banana.get_global_rect()],
			["compare", m.compare.get_global_rect()], ["card", s._card.get_global_rect()], ["bubble", s._bubble.get_global_rect()]]
		for i in areas.size():
			for j in range(i + 1, areas.size()):
				assert_false((areas[i][1] as Rect2).intersects(areas[j][1] as Rect2), "%s and %s apart at %s" % [areas[i][0], areas[j][0], size])
		assert_true(s._card.size.y >= SpModeWord.CARD_MIN_H - 0.5, "the card is tall enough for the lens row")
		for c: Control in [s._ladder, s._meter, s._btn("speech_store_button")]:
			assert_false(c.visible, "hidden in WORD mode: %s" % c.name)
		assert_true(s._lcd.hide_tally, "no THIS LEVEL line")
		assert_true(s._btn("speech_mask_button").visible, "NOISE stays")
		var titles: Array = []
		for g: Array in s._group_labels:
			titles.append(g[0])
		assert_eq(titles, ["LEVEL + WORD", "SCORE THE WHOLE WORD", "NORA-VISION", "NOISE"], "the deck's groups")
		var order: Array[String] = ["speech_softer_button", "speech_present_button", "speech_louder_button", "speech_incorrect_button",
			"speech_correct_button", "speech_lens_button", "speech_mask_button"]
		for i in range(1, order.size()):
			assert_true(Hoot.anchor_screen_rect(order[i - 1]).end.x <= Hoot.anchor_screen_rect(order[i]).position.x,
				"%s left of %s" % [order[i - 1], order[i]])
		assert_eq([s.button(&"score_correct").text, s.button(&"score_missed").text], ["REPEATED", "MISSED"], "the scoring labels")
		assert_eq(s._card.carrier, "LIST SAYS:")
		# the Call it card: inside the middle area, its buttons inside it, apart, on screen, clear of Hoot
		var call: Rect2 = m.get("_call_rect")
		assert_true(vp.encloses(call), "the Call it card is on screen at %s" % size)
		assert_false(hint.intersects(call), "the Call it card is clear of Hoot's perch")
		var yes := m.get("_yes") as Control
		var no := m.get("_no") as Control
		for b: Control in [yes, no]:
			assert_true(call.encloses(b.get_global_rect()), "%s inside the card at %s" % [b.name, size])
			assert_true(b.size.x >= 150.0 and b.size.y >= 90.0, "%s is a big target: %s" % [b.name, b.size])
		assert_false(yes.get_global_rect().intersects(no.get_global_rect()), "the two answers apart")
		assert_true(no.get_global_rect().end.x <= yes.get_global_rect().position.x, "miss it on the left, get it on the right")
		await _remove(s)


# ---------------------------------------------------------------- a whole list

func test_list_by_keys_ends_itself_at_1280() -> void:
	tree.root.size = Vector2i(1280, 720)
	await wait_frames(2)
	var stored: Array = []
	var cb := func(e: String, t: StringName, sh: Dictionary) -> void: stored.append([e, t, sh])
	Events.speech_stored.connect(cb)
	var s := _screen()
	s.start_test(_nora(), "right", true, _plan_1())
	await wait_frames(3)
	assert_false(_mode(s).strip.show_ruler, "no band ruler before a list ends")
	var res := await _play_list(s, "keys")
	Events.speech_stored.disconnect(cb)
	assert_false(res.is_empty(), "keys finish Word list 1")
	if res.is_empty():
		return
	var sheet := _sheet_of(res, "right")
	assert_false(sheet.is_empty(), "the right ear's word sheet")
	var lists: Array = sheet.get("lists", [])
	assert_eq(lists.size(), 1)
	var rec: Dictionary = lists[0]
	assert_eq([rec["list_id"], rec["level_db"], rec["masked"], rec["counts"]], ["words_1", 55, false, true], "the textbook set-up")
	assert_eq(int(rec["player_words"]), 25, "no Hoot turn without quick visit")
	assert_true((sheet.get("errors", []) as Array).is_empty(), "no slips on the textbook path")
	assert_eq(stored.size(), 1, "one speech_stored, with no STORE")
	for tr: Dictionary in rec.get("trials", []):
		assert_false(String(tr.get("said", "")).contains("{"), "her answers carry no token: %s" % tr.get("said", ""))
	assert_eq(String(stored[0][2].get("slot", "")), "right")
	var m := _mode(s)
	# the LCD: the WORDS chip, the COMFY counter (it follows the dial) and the coached NOISE chip
	var view: Dictionary = s._lcd.view
	assert_eq(String(view.get("test_chip", "")), "WORDS")
	assert_eq(String(view.get("start_chip", "")), "PTA 15 + 40 = 55 · min 55", "the COMFY counter")
	var aux: Array = view.get("aux", [])
	assert_eq(aux.size(), 1)
	if aux.size() == 1:
		assert_eq([String(aux[0]["label"]), String(aux[0]["value"])], ["55 - 40 = 15 < 35:", "NO NOISE"], "the NOISE chip's sum")
	assert_false(bool(s.get_state()["compare_shown"]), "one ear: no ear compare yet")
	assert_true(m.strip.show_ruler, "the band ruler after the list")
	assert_ne(m.strip.band(), &"", "the band chip landed")
	assert_eq(m.strip.tiles.size(), 25, "25 tiles")
	var actions := {}
	for b: Array in _beats:
		actions[String((b[1] as Dictionary)["action"])] = true
		assert_eq(String((b[1] as Dictionary).get("test", "")), "wrs")
	for a: String in ["louder", "present", "lens_toggle", "call_it"]:
		assert_has(actions, a, "a %s beat" % a)
	assert_false(actions.has("store"), "never a STORE beat")


func test_list_by_mouse_routes_at_1920() -> void:
	tree.root.size = Vector2i(1920, 1080)
	await wait_frames(2)
	var s := _screen()
	s.start_test(_nora(), "right", true, _plan_1())
	await wait_frames(3)
	var res := await _play_list(s, "mouse")
	assert_false(res.is_empty(), "the mouse route of every beat finishes the list")
	if res.is_empty():
		return
	var rec: Dictionary = (_sheet_of(res, "right").get("lists", []) as Array)[0]
	assert_eq([rec["level_db"], rec["counts"], int(rec["player_words"])], [55, true, 25])
	assert_eq((rec.get("call_its", []) as Array).size(), 1, "the Call it was answered by a click")
	var routes := {}
	for b: Array in _beats:
		routes[String((b[1] as Dictionary)["action"])] = String(((b[1] as Dictionary)["mouse"] as Dictionary)["click"])
	assert_eq(routes.get("lens_toggle", ""), "speech_lens_button")
	assert_true(String(routes.get("call_it", "")) in ["call_it_yes_button", "call_it_no_button"], "the Call it's route")
	assert_eq(routes.get("present", ""), "speech_present_button")
	assert_eq(routes.get("louder", ""), "speech_louder_button")
	assert_true(routes.has("score_correct") or routes.has("score_missed"))


func test_beats_info_solvers_and_a_stale_solver() -> void:
	var s := _screen()
	s.start_test(_nora(), "right", true, _plan_1())
	var got: bool = await _wait_until(func() -> bool: return not _beats.is_empty(), 5.0)
	assert_true(got, "a beat when the screen waits")
	if not got:
		return
	var b0: Array = _beats[0]
	var info: Dictionary = b0[1]
	assert_eq(b0[0], &"speech")
	for k: String in ["ear", "slot", "test", "action", "target_db", "mouse", "list", "list_n", "word_n", "louder_than"]:
		assert_has(info, k, "beat info " + k)
	assert_eq([info["ear"], info["slot"], info["test"], info["action"], info["target_db"], info["list"], info["list_n"], info["word_n"]],
		["right", "right", "wrs", "louder", 55, "words_1", 1, 0])
	assert_eq(s._beat_key, "wrs|wrs:right:words_1|0|louder|15|false|false", "the beat key")
	# a stale solver (the state moved on) does nothing
	await tap_action(&"louder")
	await wait_frames(2)
	assert_eq(s.session.db, 20)
	(b0[2] as Callable).call()
	await wait_frames(4)
	assert_eq(s.session.db, 20, "a stale solver is a no-op")
	var finished: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: finished.append(r))
	var lens_try := 0
	var call_its: Array = []
	var used := 0  # the stale b0; any later beat is live
	var t0 := Time.get_ticks_msec()
	while finished.is_empty() and Time.get_ticks_msec() - t0 < 40000:
		if _beats.size() > used + 1:
			used = _beats.size() - 1
			var b: Array = _beats[used]
			if b[0] == &"lens_try":
				lens_try += 1
				assert_eq(String((b[1] as Dictionary)["action"]), "lens_toggle")
			elif b[0] == &"call_it":
				call_its.append(b[1])
			(b[2] as Callable).call()
		await wait_frames(1)
	assert_false(finished.is_empty(), "the solvers finish the list")
	assert_eq(lens_try, 1, "lens_try once")
	assert_eq(call_its.size(), 1, "one Call it beat")
	if call_its.size() == 1:
		var ci: Dictionary = call_its[0]
		for k: String in ["word", "prompt", "options", "best"]:
			assert_has(ci, k, "call_it info " + k)
		assert_eq((ci["options"] as Array).size(), 2)
		assert_eq(String((ci["mouse"] as Dictionary)["click"]), String(ci["best"]), "the mouse clicks the best answer")
		assert_true(int(ci["word_n"]) >= 1, "never place 1")
	# one beat per idle point
	var keys := {}
	for b: Array in _beats:
		var k := "%s|%s|%s" % [b[0], (b[1] as Dictionary)["word_n"], (b[1] as Dictionary)["action"]]
		if (b[1] as Dictionary)["action"] in ["louder", "softer"]:
			continue
		assert_false(keys.has(k), "no doubled beat: %s" % k)
		keys[k] = true


# ---------------------------------------------------------------- Hoot's turn

func test_hoot_turn_x8_restored_and_keyed_per_list() -> void:
	var s := _screen(true)
	s.start_test(_nora(), "right", true, _plan_1({"hoot_turn_after": 2, "lens_try_after": 0, "call_it": []}))
	var saw_turn: Array = [false]
	var scale_in_turn: Array = [0.0]
	var on := await _play_until(s, func() -> bool:
		if s.hoot_running():
			saw_turn[0] = true
		return s.hoot_running(), 20.0)
	assert_true(on, "Hoot takes over after 2 player words")
	await wait_frames(1)
	var r: bool = await _wait_until(func() -> bool:
		scale_in_turn[0] = maxf(float(scale_in_turn[0]), Engine.time_scale)
		return not s.hoot_running(), 30.0)
	assert_true(r, "Hoot finishes the list")
	assert_near(float(scale_in_turn[0]), TEST_SPEED * SpeechScreen.HOOT_SPEED, 0.001, "x8 in his turn")
	assert_eq(Engine.time_scale, TEST_SPEED, "the time scale is restored exactly")
	var done: bool = await _wait_until(func() -> bool: return bool(s.get_state()["done"]), 10.0)
	assert_true(done)
	assert_true((s.get("_hoot_done_ears") as Dictionary).has("wrs:right:words_1"), "the Hoot-done key is the list's")
	var sheet: Dictionary = (s.session.sheets[&"wrs"] as Dictionary)["right"]
	var rec: Dictionary = (sheet["lists"] as Array)[0]
	assert_eq([int(rec["player_words"]), int(rec["hoot_words"])], [2, 23], "his words are his")
	# a second list in the same visit gets its own turn
	await _wait_until(func() -> bool: return bool(s.get_state()["finishing"]) and not s.hoot_running(), 5.0)
	await wait_seconds(4.5)
	s.start_test(_nora(), "left", true, _plan_2({"hoot_turn_after": 1, "confirm_wrong_setup": false, "level": 75, "mask_on": true}))
	var on2 := await _play_until(s, func() -> bool: return s.hoot_running(), 20.0)
	assert_true(on2, "the next list gets its own Hoot turn")
	await _wait_until(func() -> bool: return not s.hoot_running(), 30.0)
	assert_eq(Engine.time_scale, TEST_SPEED, "restored again")


# ---------------------------------------------------------------- keys

func test_affinity_swaps_only_the_level_and_the_coach_follows() -> void:
	var s := _screen()
	s.start_test(_nora(), "right", true, _plan_1())
	await wait_frames(3)
	var m := _mode(s)
	var lines := {}
	for style: String in ["otosuite", "affinity"]:
		Game.set_key_style(style)
		await wait_frames(2)
		var up := s.k(&"louder")
		var tip := s._coach_text(s.session.recommended_action())
		var filled := s._fill_keys(String(tip[0]))
		assert_true(filled.contains(up), "%s: the level line names %s: %s" % [style, up, filled])
		lines[style] = filled
		# every line with a key renders the chip of its action in this style
		for key: String in SpModeWord.LINES:
			var raw := String(SpModeWord.LINES[key])
			var t := String(m.call("_fill", raw))
			var at := raw.find("{key:")
			while at >= 0:
				var end := raw.find("}", at)
				var action := StringName(raw.substr(at + 5, end - at - 5))
				assert_true(InputMap.has_action(action), "%s names a real action: %s" % [key, action])
				assert_true(t.contains(s.k(action)), "%s (%s) shows %s" % [key, style, s.k(action)])
				at = raw.find("{key:", end)
	assert_ne(lines["otosuite"], lines["affinity"], "the level line changes with the style")
	for action: StringName in [&"present_tone", &"speech_correct", &"speech_incorrect", &"toggle_lens", &"toggle_mask"]:
		Game.set_key_style("otosuite")
		var a := s.k(action)
		Game.set_key_style("affinity")
		assert_eq(s.k(action), a, "%s is not swapped" % action)
	# Up is softer in the swapped style
	Game.set_key_style("affinity")
	await wait_frames(1)
	var db0 := s.session.db
	await _key(KEY_DOWN)
	assert_eq(s.session.db, db0 + 5, "affinity: Down = louder")
	await _key(KEY_UP)
	assert_eq(s.session.db, db0, "affinity: Up = softer")


# ---------------------------------------------------------------- WORD rules

func test_no_store_and_one_level_per_list() -> void:
	var s := _screen()
	s.start_test(_nora(), "right", true, _plan_1({"lens_try_after": 0, "call_it": []}))
	await wait_frames(3)
	assert_false(s._btn("speech_store_button").visible, "no STORE button")
	await tap_action(&"store")
	await wait_frames(2)
	assert_eq(_kinds(s.session, &"wrs_no_store"), 1, "S says the list scores itself")
	assert_true(s.session.trials_for().is_empty())
	await _dial_to(s, 55)
	await tap_action(&"present_tone")
	await _wait_until(func() -> bool: return s.answer_shown(), 10.0)
	await tap_action(&"speech_correct" if bool(s.session.current["correct"]) else &"speech_incorrect")
	await _wait_until(func() -> bool: return s.idle(), 5.0)
	assert_true(bool(_wrs(s)["level_locked"]) and bool(_wrs(s)["noise_locked"]), "level and noise lock after word 1")
	await tap_action(&"louder")
	await tap_action(&"toggle_mask")
	await tap_action(&"louder")
	await wait_frames(2)
	assert_eq(s.session.db, 55, "the dial stays")
	assert_false(s.session.mask_on, "the noise stays")
	assert_eq(_kinds(s.session, &"wrs_level_locked"), 1, "the level chip's lesson once")
	assert_eq(_kinds(s.session, &"wrs_noise_locked"), 1, "the noise chip's lesson once")


func test_two_press_confirm_level_and_boo_on_a_solo_list() -> void:
	var s := _screen()
	s.start_test(_nora(), "left", false, _plan_2())
	await wait_frames(3)
	var m := _mode(s)
	assert_eq(s.session.db, 50)
	assert_eq(String(_wrs(s)["confirm_needed"]), "level")
	await tap_action(&"present_tone")
	await wait_frames(2)
	var st := s.get_state()
	assert_true(bool(st["confirm_pending"]), "the level chip is up")
	assert_eq(String(st["confirm_why"]), "level")
	assert_true(s.session.trials_for().is_empty(), "nothing presented")
	assert_false(bool(_wrs(s)["unprompted"]), "a chip before the first word: prompted")
	var chip := m.call("_confirm_lines") as PackedStringArray
	assert_true(chip[0].contains("75") and chip[1].contains("50") and chip[1].contains(s.k(&"present_tone")), "the chip: %s" % [chip])
	# the chip lapses after 4 s: nothing tests
	await wait_seconds(SpModeWord.CONFIRM_S + 0.2)
	assert_false(bool(s.get_state()["confirm_pending"]), "the chip lapses")
	# the level right, noise off: BOO
	await _dial_to(s, 75)
	assert_true(bool(_wrs(s)["masking_needed"]))
	assert_eq(m.ghost.lurk, 0.0, "no lurking Ghost on a solo list")
	await wait_frames(4)
	assert_true(m.ghost.shown_alpha() < 0.01, "the Ghost is not out yet")
	await tap_action(&"present_tone")
	await wait_frames(3)
	assert_eq(String(s.get_state()["confirm_why"]), "unmasked")
	assert_true(m.ghost.is_booing(), "BOO! out of the window")
	assert_eq(_kinds(s.session, &"boo"), 1, "the boo observation")
	assert_true(s.session.trials_for().is_empty())
	# M: noise on, the Ghost is busted, Nora's aside
	await tap_action(&"toggle_mask")
	await wait_frames(3)
	assert_false(m.ghost.is_booing(), "GHOST BUSTED!")
	assert_true(s.session.mask_on)
	assert_false(bool(s.get_state()["confirm_pending"]), "the BOO chip goes with the Ghost")
	assert_eq(s._bubble.aside, "Is that the sopranos warming up?", "her aside on the first M of a list that needs noise")
	await tap_action(&"present_tone")
	await _wait_until(func() -> bool: return not s.session.trials_for().is_empty(), 5.0)
	assert_eq(s.session.trials_for().size(), 1, "the set-up is right now: it tests")
	assert_false(bool(_wrs(s)["confirmed_wrong"]))


func test_second_press_tests_anyway_and_hoot_finishes() -> void:
	var s := _screen(false)
	s.start_test(_nora(), "left", false, _plan_2())
	await wait_frames(3)
	await tap_action(&"present_tone")
	await wait_frames(2)
	assert_true(bool(s.get_state()["confirm_pending"]))
	await tap_action(&"present_tone")
	await _wait_until(func() -> bool: return not s.session.trials_for().is_empty(), 5.0)
	assert_eq(s.session.trials_for().size(), 1, "the second press tests anyway")
	assert_true(bool(_wrs(s)["confirmed_wrong"]), "the list records it")
	var turn := await _play_until(s, func() -> bool: return s.hoot_running(), 25.0)
	assert_true(turn, "after 3 player words Hoot finishes the list (outside the quick-visit gate)")
	var pw := 0
	for tr: Dictionary in s.session.trials_for():
		if not bool(tr["by_hoot"]):
			pw += 1
	assert_eq(pw, 3, "three player words")


func test_coached_denial_and_the_lurking_ghost() -> void:
	var s := _screen()
	s.start_test(_nora(), "left", true, {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_3", "level": 75})
	await wait_frames(3)
	var m := _mode(s)
	assert_true(bool(_wrs(s)["masking_needed"]))
	assert_false(bool(_wrs(s)["confirm_wrong_setup"]), "coached: no anyway")
	await wait_seconds(0.4)
	assert_true(m.ghost.lurk >= 0.99, "the Ghost lurks bold at 75 on a coached list: %s" % m.ghost.lurk)
	assert_eq(_kinds(s.session, &"ghost_lurk"), 1, "the lurk lesson")
	await tap_action(&"present_tone")
	await wait_frames(3)
	assert_true(s.session.trials_for().is_empty(), "denied")
	assert_true(bool(s.get_state()["deny_pending"]))
	assert_false(bool(s.get_state()["confirm_pending"]), "no chip, no anyway")
	var tip := s._coach_text(s.session.recommended_action())
	assert_eq(String(tip[0]), s.session.tip_text(&"wrs_unmasked"), "the matching tip in the coach's place")
	assert_eq(String(tip[1]), "speech_mask_button")
	await wait_seconds(SpModeWord.DENY_S + 0.3)
	var back := s._coach_text(s.session.recommended_action())
	assert_eq(String(back[2]), "mask", "then the coach repeats the step")
	# a lower level: fainter
	await tap_action(&"softer")
	await tap_action(&"softer")
	await tap_action(&"softer")
	await tap_action(&"softer")
	await wait_frames(2)
	assert_near(m.ghost.lurk, SpeechRules.ghost_alpha(55, &"phones", 10.0), 0.001, "fainter at 55")
	await tap_action(&"softer")
	await wait_frames(2)
	assert_near(m.ghost.lurk, SpeechRules.GHOST_ALPHA_FLOOR, 0.001, "the floor at 50, the first level that needs noise")
	await tap_action(&"softer")
	await wait_frames(2)
	assert_eq(m.ghost.lurk, 0.0, "45 needs no noise: no Ghost")
	await tap_action(&"louder")
	await wait_frames(2)
	await tap_action(&"toggle_mask")
	await wait_frames(2)
	assert_eq(m.ghost.lurk, 0.0, "noise on: gone")


# ---------------------------------------------------------------- the lens

func test_lens_v_button_alpha_on_measured_thresholds() -> void:
	var toggles: Array = []
	var cb := func(ear: String, on: bool) -> void: toggles.append([ear, on])
	Events.speech_lens_toggled.connect(cb)
	var nora := _nora()
	var s := _screen()
	s.start_test(nora, "left", true, {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_3", "level": 50})
	await wait_frames(3)
	var m := _mode(s)
	assert_false(m.banana.is_revealed(), "the Banana Board waits for the lens")
	assert_false(s._card.word_drawer.is_valid(), "no lens row with the lens off")
	await tap_action(&"toggle_lens")
	await wait_frames(2)
	assert_true(bool(s.get_state()["lens_on"]), "V turns it on")
	assert_true(bool(s.memory["lens_on"]))
	assert_true(m.banana.is_revealed(), "the Banana Board slides in at the first press")
	assert_true(s._card.word_drawer.is_valid(), "the lens row is drawn")
	assert_false(s._card.hide_word, "the word is never hidden")
	var word := String(s.session.next_item()["text"])
	assert_eq(s._card.shown_word(), word, "the word itself stays on the card")
	# its alpha: lens_alpha of each chunk's margin on her MEASURED thresholds
	var item := s.session.next_item()
	var measured := s.session.measured_thresholds("left")
	var row := m.lens_row(item, 50.0)
	assert_eq(row.size(), SpeechRules.chunk_sounds(item).size())
	for p: Dictionary in row:
		if String(p["sound"]) == "":
			assert_eq(float(p["alpha"]), 1.0, "a silent letter is plain ink")
			continue
		var margin := SpeechRules.sound_margin(String(p["sound"]), 50.0, measured)
		assert_near(float(p["alpha"]), SpeechRules.lens_alpha(margin), 0.0001, "the chunk's alpha")
		var want := &"lost" if margin < 0.0 else (&"just" if margin < 3.0 else &"clear")
		assert_eq(p["style"], want)
	# the truth is never read: change it, the row stays
	for f: Variant in nora.thresholds_left:
		nora.thresholds_left[f] = 100
	assert_eq(m.lens_row(item, 50.0), row, "the lens ignores the truth")
	# the button toggles too
	await _click_anchor("speech_lens_button")
	assert_false(bool(s.get_state()["lens_on"]), "the button turns it off")
	assert_false(s._card.word_drawer.is_valid())
	await _click_anchor("speech_lens_button")
	assert_true(bool(s.get_state()["lens_on"]))
	Events.speech_lens_toggled.disconnect(cb)
	assert_eq(toggles, [["left", true], ["left", false], ["left", true]], "speech_lens_toggled each time")
	assert_eq(s._btn("speech_lens_button").text, "LENS ON")
	# it stays as the player left it for the visit
	s.start_test(nora, "left", true, {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_4", "level": 75})
	await wait_frames(2)
	assert_true(bool(s.get_state()["lens_on"]) and m.banana.is_revealed(), "the next list keeps the lens and the board")
	# the lens works in Hoot's turn too (it is only a view)
	s.hoot_turn()
	await wait_frames(2)
	assert_true(s.hoot_running())
	await tap_action(&"toggle_lens")
	assert_false(bool(s.get_state()["lens_on"]), "V in Hoot's turn")


func test_lens_row_turns_into_her_answer_only_on_a_miss() -> void:
	var s := _screen()
	s.start_test(_nora(), "left", true, {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_3", "level": 75, "mask_on": true,
		"chatter": CHATTER})
	await wait_frames(3)
	var m := _mode(s)
	await tap_action(&"toggle_lens")
	var saw := {"miss": false, "hit": false}
	for i in 12:
		await _wait_until(func() -> bool: return s.idle(), 10.0)
		await tap_action(&"present_tone")
		await _wait_until(func() -> bool: return s.answer_shown(), 10.0)
		await wait_frames(1)
		var cur := s.session.current
		var scr: Dictionary = m.get("_scramble")
		if bool(cur["correct"]):
			saw["hit"] = true
			assert_true(scr.is_empty(), "a hit keeps the lens row: %s" % cur["said"])
		elif SpModeWord._norm(String(cur["said"])) != SpModeWord._norm(String(cur["word"])):
			saw["miss"] = true
			assert_eq(String(scr.get("to", "")), String(cur["said"]), "a miss turns the row into what she said")
		await tap_action(&"speech_correct" if bool(cur["correct"]) else &"speech_incorrect")
		if saw["miss"] and saw["hit"]:
			break
	assert_true(saw["miss"] and saw["hit"], "both seen")


# ---------------------------------------------------------------- Call it

## The Call it card before the chosen word, answered four ways: Right, Left, and the two buttons.
func test_call_it_card_keys_and_buttons() -> void:
	for way: String in ["right", "left", "yes", "no"]:
		Hoot.reset_visit()
		_beats.clear()
		var s := _screen()
		s.start_test(_nora(), "right", true, _plan_1({"lens_try_after": 0, "lens": true}))
		s.memory["lens_on"] = true
		await wait_frames(3)
		var up := await _play_until(s, func() -> bool: return bool(s.get_state()["call_it_card"]), 25.0)
		assert_true(up, "%s: the Call it card comes up" % way)
		if not up:
			await _remove(s)
			continue
		var w := _wrs(s)
		var n := int(w["word_n"])
		assert_true(n >= 1, "never before the first word")
		var item := s.session.next_item()
		assert_eq(String(w["call_it_word"]), String(item["text"]), "the card asks about the next word")
		assert_eq(StringName(w["call_it_pending"]), &"faint_hit")
		var row := _mode(s).lens_row(item, float(s.session.db))
		var lost := false
		for p: Dictionary in row:
			lost = lost or StringName(p["style"]) == &"lost"
		assert_true(lost, "a faint chunk on the lens row")
		for id: String in CALL_ANCHORS:
			assert_true(s.get("_mode").get("_yes").visible and s.get("_mode").get("_no").visible, "both answers show")
			assert_true(Rect2(Vector2.ZERO, s.get_viewport().get_visible_rect().size).encloses(Hoot.anchor_screen_rect(id)), id + " on screen")
		# the card shows on the refresh after the score; its beat follows on the deferred emit
		var beat_up: bool = await _wait_until(func() -> bool: return not _beats.is_empty() and _beats.back()[0] == &"call_it", 3.0)
		assert_true(beat_up, "%s: the call_it beat" % way)
		# PRESENT waits for the call
		await tap_action(&"present_tone")
		assert_eq(int(_wrs(s)["word_n"]), n, "PRESENT waits for the call")
		match way:
			"right":
				await tap_action(&"speech_correct")
			"left":
				await tap_action(&"speech_incorrect")
			"yes":
				await _click_anchor("call_it_yes_button")
			"no":
				await _click_anchor("call_it_no_button")
		await wait_frames(2)
		assert_false(bool(s.get_state()["call_it_card"]), "%s answers the card" % way)
		assert_false(s.session.awaiting_score, "nothing was scored")
		var calls: Array = s.session.mode.get("_call_its")
		assert_eq(calls.size(), 1)
		if calls.size() == 1:
			assert_eq(bool(calls[0]["guess"]), way in ["right", "yes"], "%s: the guess" % way)
		await _remove(s)


# ---------------------------------------------------------------- the tea demo and the asides

func test_tea_demo_neither_presents_nor_locks() -> void:
	var tips: Array = []
	var on_tip := func(tip: Dictionary) -> void: tips.append(String(tip["text"]))
	Events.hoot_tip_shown.connect(on_tip)
	var lines: Array = []
	var on_line := func(who: String, t: String) -> void: lines.append([who, t])
	Events.dialogue_line.connect(on_line)
	var s := _screen(true)
	s.start_test(_nora(), "left", false, _plan_2({"chat_demo": TEA_DEMO, "level": 75, "hoot_turn_after": 8}))
	await wait_frames(3)
	assert_true(s.hoot_running(), "the demo is a Hoot turn")
	assert_eq(s.session.db, SpeechRules.CHAT_DB, "the dial parks at chatting level")
	assert_true(bool(s.get_state()["demo"]))
	assert_true(s._card.hide_word and s._card.word_drawer.is_valid(), "the card shows the demo's line and what reaches her")
	assert_true(_beats.is_empty(), "no beat during the demo")
	var done: bool = await _wait_until(func() -> bool: return not s.hoot_running(), 30.0)
	Events.hoot_tip_shown.disconnect(on_tip)
	Events.dialogue_line.disconnect(on_line)
	assert_true(done, "the demo hands back")
	assert_eq(Engine.time_scale, TEST_SPEED, "x1, restored")
	assert_true(s.session.trials_for().is_empty(), "nothing presented")
	assert_false(bool(_wrs(s)["started"]) or bool(_wrs(s)["level_locked"]), "nothing dealt or locked")
	assert_eq(s.session.db, SpeechRules.CHAT_DB, "the dial stays at 50 for the player")
	assert_false(s._card.hide_word, "the card is the list's again")
	var hoot_lines := [TEA_DEMO["lines"][0][1], TEA_DEMO["lines"][2][1]]
	var at := []
	for t: String in hoot_lines:
		at.append(tips.find(t))
	assert_true(int(at[0]) >= 0 and int(at[1]) > int(at[0]), "Hoot's demo lines show, in order: %s" % [tips])
	assert_true(lines.has(["Nora", "Candy... a canoe? At my age?"]), "her line is spoken: %s" % [lines])
	assert_true(tips.back() == "Left ear, all yours for 8 words! Then I'll take a turn.", "the list's intro comes back: %s" % [tips])
	await wait_frames(2)
	assert_true(s.idle(), "the player's turn")
	await tap_action(&"louder")
	assert_eq(s.session.db, SpeechRules.CHAT_DB + 5, "the level is still free")


func test_asides_never_block() -> void:
	var s := _screen()
	s.start_test(_nora(), "right", true, _plan_1({"lens_try_after": 0, "call_it": []}))
	await wait_frames(4)
	var n := _beats.size()
	var key := s._beat_key
	s.session.observe_once("aside:test", &"aside", {"text": "Ooh, that's LOUD."})
	await wait_frames(4)
	assert_eq(s._bubble.aside, "Ooh, that's LOUD.", "the aside is a side note in her bubble")
	assert_eq(_beats.size(), n, "no beat for an aside")
	assert_eq(s._beat_key, key)
	assert_true(s.idle(), "the player's turn goes on")
	# her answer on a louder list: the loud style, and the aside once
	var stored: Array = []
	s.test_finished.connect(func(r: Dictionary) -> void: stored.append(r))
	s.start_test(_nora(), "left", true, {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_4", "louder_than": 1, "level": 95, "mask_on": true,
		"lock_noise": true, "loud_bubble": true})
	await wait_frames(3)
	await tap_action(&"present_tone")
	await _wait_until(func() -> bool: return s.answer_shown(), 10.0)
	await wait_frames(1)
	assert_eq(s._bubble.style, &"loud", "the loud bubble")
	assert_eq(s._bubble.aside, "Ooh, that's LOUD.")
	assert_true(s.session.awaiting_score, "the score beat waits as usual")
	assert_eq(String(_beats.back()[1]["action"]).begins_with("score_"), true)


# ---------------------------------------------------------------- the ear compare

## The ear compare waits until both ears have a counted list (Hoot's lists off-screen here), and its
## verdict until both bests are final (her left needs the louder list first).
func test_ear_compare_waits_for_both_ears() -> void:
	var s := _screen()
	var right := await s.run_hidden(_nora(), "right", {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_1"})
	assert_false(right.is_empty(), "Hoot's right list")
	var m := _mode(s)
	assert_false(bool(s.get_state()["compare_shown"]), "one ear: no ear compare")
	assert_false(m.compare.visible)
	var left := await s.run_hidden(_nora(), "left", {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_2"})
	assert_false(left.is_empty(), "Hoot's left list")
	assert_true(bool(s.get_state()["compare_shown"]), "both ears: the ear compare")
	assert_true(m.compare.visible)
	assert_true(m.compare.ready_to_show())
	assert_eq(m.compare.verdict(), &"", "no verdict while her left's best is not final")
	var shown := Hoot.anchor_screen_rect("speech_ear_compare")
	assert_true(shown.size.x > 100.0 and not shown.intersects(Hoot.anchor_screen_rect("speech_banana")), "its own slot under the board")


# ---------------------------------------------------------------- reduced motion, widgets

func test_reduced_motion_and_the_widgets() -> void:
	Game.set_setting("reduced_motion", true)
	assert_eq(SpModeWord.scramble_style(), &"fade", "the lens row crossfades")
	var strip := SpScoreStrip.new()
	add_node(strip)
	strip.size = Vector2(320, 300)
	strip.set_view({"words": 25, "trials": [{"n": 1, "scored": true}]})
	strip.set_view({"words": 25, "trials": [{"n": 1, "scored": true}]})
	var top := 0.0
	for i in 12:
		strip._process(0.03)
		top = maxf(top, strip.tile_scale(1))
	assert_true(top <= 1.0001, "a tile flips without bouncing: %s" % top)
	var ban := SpBanana.new()
	add_node(ban)
	ban.reveal(true)
	assert_true(ban.slide_in() in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0], "the board slides in steps")
	assert_true(ban.note_k(0.3) in [0.0, 1.0] and ban.note_k(1.9) in [0.0, 1.0], "the note moves in two steps")
	Game.set_setting("reduced_motion", false)
	assert_eq(SpModeWord.scramble_style(), &"scramble")
	strip.reset()
	strip.set_view({"words": 25, "trials": [{"n": 1, "scored": false, "said": "Sack?"}]})
	top = 0.0
	for i in 12:
		strip._process(0.03)
		top = maxf(top, strip.tile_scale(1))
	assert_true(top > 1.0, "full motion bounces")
	# the strip's running line, the ruler only after a list
	strip.set_view({"words": 25, "right": 13, "pct_so_far": 52, "trials": []})
	assert_false(strip.show_ruler)
	strip.set_view({"words": 25, "right": 13, "pct_so_far": 52, "trials": [], "show_ruler": true, "predicted_min": 58})
	assert_true(strip.show_ruler and strip.predicted_min == 58)
	# the Banana Board's letters: the lens's own arithmetic on the given (measured) thresholds
	ban.thresholds = Wrs._octaves("left")
	ban.dial_db = 75
	for snd: String in ["s", "m", "th", "vowel"]:
		assert_near(ban.letter_alpha(snd), SpeechRules.lens_alpha(SpeechRules.sound_margin(snd, 75.0, ban.thresholds)), 0.0001, snd)
	# the ear compare: same-range bands (A3) and the verdict once both bests are final
	var cmp := SpEarCompare.new()
	add_node(cmp)
	cmp.set_ears({"pct": 96, "words": 25, "final": true}, {"pct": 52, "words": 25, "final": false})
	assert_eq(cmp.verdict(), &"", "no verdict before both bests are final")
	cmp.set_ears({"pct": 96, "words": 25, "final": true}, {"pct": 52, "words": 25, "final": true})
	assert_eq(cmp.verdict(), &"differ", "96 vs 52: too far apart for chance")
	assert_eq(cmp.band_of({"pct": 52, "words": 25}), SpeechRules.wrs_same_range(52.0, 25))
	cmp.set_ears({"pct": 96, "words": 25, "final": true}, {"pct": 88, "words": 25, "final": true})
	assert_eq(cmp.verdict(), &"same", "96 vs 88: within chance")
	var b1 := cmp.band_of({"pct": 96, "words": 25})
	var b2 := cmp.band_of({"pct": 52, "words": 25})
	assert_true(b2.y < b1.x, "the bands of 96 and 52 do not overlap: %s %s" % [b1, b2])


# ---------------------------------------------------------------- Day 3 regression

func test_day3_srt_never_reaches_the_word_mode() -> void:
	var a := _screen()
	a.start_test(_mike(), "right", true, _srt_plan())
	await wait_frames(3)
	assert_true(a.get("_mode") == null, "no mode")
	assert_true((a.get("_modes") as Dictionary).is_empty(), "no mode made at all")
	assert_true(a.find_child("SpeechScoreStrip", true, false) == null, "no WORD widget built")
	for id: String in WORD_ONLY:
		assert_false(Hoot.has_anchor(id), "no word anchor " + id)
	var snap := _deck_snapshot(a)
	var st := a.get_state()
	assert_false(bool(st["lens_on"]) or bool(st["confirm_pending"]) or bool(st["practice"]))
	await _remove(a)
	# SRT -> WRS -> SRT on one screen: the SRT's deck, labels, anchors and widgets come back exactly
	var s := _screen()
	s.start_test(_mike(), "right", true, _srt_plan())
	await wait_frames(2)
	assert_eq(_deck_snapshot(s), snap, "the same Day 3 deck")
	s.start_test(_nora(), "right", true, _plan_1())
	await wait_frames(3)
	assert_true(_mode(s) != null)
	s.start_test(_mike(), "left", true, _srt_plan())
	await wait_frames(3)
	assert_true(s.get("_mode") == null, "back to no mode")
	var back := _deck_snapshot(s)
	for k: String in ["groups", "buttons", "labels", "visible"]:
		assert_eq(back[k], snap[k], "Day 3's %s again" % k)
	for id: String in WORD_ONLY:
		assert_false(Hoot.has_anchor(id), "the word anchor %s is gone" % id)
	for id: String in SpeechScreen.ANCHORS:
		assert_true(Hoot.has_anchor(id), "Day 3 anchor " + id)
	assert_true(s._ladder.visible and s._meter.visible and s._btn("speech_store_button").visible, "the SRT's widgets")
	assert_false(s._card.word_drawer.is_valid() or s._card.hide_word or s._card.carrier != "", "the card is Day 3's")
	assert_eq([s._bubble.style, s._bubble.aside, s._bubble.text_inset], [&"normal", "", 0.0], "the bubble is Day 3's")
	var wm := (s.get("_modes") as Dictionary).get(&"wrs") as SpModeWord
	assert_true(wm != null, "the word mode is kept for the visit")
	for w: Control in [wm.strip, wm.banana, wm.ghost, wm.compare]:
		assert_false(w.visible, "%s is hidden on Day 3's deck" % w.name)


func _deck_snapshot(s: SpeechScreen, _with_ear: bool = true) -> Dictionary:
	var groups: Array = []
	for g: Array in s._group_labels:
		groups.append([g[0], g[1]])
	var buttons := {}
	var labels := {}
	var visible := {}
	for id: String in SpeechScreen.ACTION_BUTTONS.values():
		var b := s._btn(id)
		buttons[id] = Rect2(b.position, b.size)
		labels[id] = [b.text, b.sub_text, b.glyph, b.face_color, b.font_size]
		visible[id] = b.visible
	return {"groups": groups, "buttons": buttons, "labels": labels, "visible": visible}


# ---------------------------------------------------------------- the lines

## Every line the WORD mode (and WrsTest) can say, filled as the screen fills it (tokens at their
## longest, both key styles): 18 words or fewer, no token left, every key a {key:...} chip, no
## diagnosis, no blame, no "listen".
func test_lines_fit_and_never_name_a_diagnosis() -> void:
	var s := _screen()
	s.start_test(_nora(), "left", true, {"test": "wrs", "tones": Wrs._nora_tones(), "list": "words_3", "level": 75})
	await wait_frames(3)
	var m := _mode(s)
	var raw: Array[String] = []
	for t: String in SpModeWord.LINES.values():
		raw.append(t)
	for t: String in SpModeWord.DEFAULT_ASIDES.values():
		raw.append(t)
	raw.append_array([SpModeWord.CHIP_LEVEL_LOCKED, SpModeWord.CHIP_NOISE_LOCKED, WrsTest.HOOT_TURN_TEXT])
	for t: String in WrsTest.TIPS.values():
		raw.append(t)
	for t: String in WrsTest.MISSCORED_WRS.values():
		raw.append(t)
	for t: String in WrsTest.VERDICTS.values():
		raw.append(t)
	for r: String in raw:
		assert_false(r.contains("[") or r.contains("]"), "a key is named only as {key:...}: %s" % r)
		for bare: String in ["Space", "SPACE", "press V", "press M", "Right arrow", "Left arrow"]:
			assert_false(r.contains(bare), "no bare key name: %s" % r)
	var long := {"{pta}": "100", "{sum}": "135", "{target}": "100", "{n}": "4", "{db}": "100", "{chunk}": "ea", "{word}": "thorn",
		"{said}": "strawberries", "{mask}": "100", "{naive}": "100", "{pct}": "100", "{band}": "very poor", "{best}": "100", "{min}": "88",
		"{r}": "100", "{l}": "100", "{ear}": "right"}
	for style: String in ["otosuite", "affinity"]:
		Game.set_key_style(style)
		await wait_frames(1)
		for r: String in raw:
			var t := r
			for tok: String in long:
				t = t.replace(tok, long[tok])
			t = String(m.call("_fill", t))
			_check_line(t, style)
	# and every tip Hoot shows on a coached list, by keys (a fresh screen: the left list above is not
	# finished, and its coach's sticky line would hold the perch)
	Game.set_key_style("otosuite")
	await _remove(s)
	Hoot.reset_visit()
	s = _screen()
	var tips: Array = []
	var on_tip := func(tip: Dictionary) -> void: tips.append(String(tip["text"]))
	Events.hoot_tip_shown.connect(on_tip)
	s.start_test(_nora(), "right", true, _plan_1())
	var res := await _play_list(s, "keys")
	Events.hoot_tip_shown.disconnect(on_tip)
	assert_false(res.is_empty(), "the coached list finished")
	assert_true(tips.size() >= 4, "the coach spoke: %s" % [tips])
	for t: String in tips:
		_check_line(t, "shown")


func _check_line(t: String, where: String) -> void:
	assert_true(t.split(" ", false).size() <= Hoot.MAX_WORDS, "18 words or fewer (%s): %s" % [where, t])
	assert_false(t.contains("{") or t.contains("}"), "no token left (%s): %s" % [where, t])
	var low := t.to_lower()
	for w: String in DIAGNOSIS_WORDS:
		assert_false(low.contains(w), "no diagnosis (%s): %s" % [where, t])
	for w: String in ["you failed", "wrong again", "careless", "lazy", "hear the gap", "listen to"]:
		assert_false(low.contains(w), "no blame, no listening (%s): %s" % [where, t])
