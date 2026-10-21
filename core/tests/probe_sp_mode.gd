extends SpMode
## A stand-in WORD (wrs) and PARTY (sin) screen mode for test_speech_seams.gd (not a test file
## itself, never in the game). SpMode.path_override points both tests here; the session's test picks
## the behaviour (one instance per test, as the screen makes them). It answers every screen seam
## (H1-H28) with something a test can see: its own panel (an anchor), a READY button (WORD) or a LOCK
## IN button that takes over STORE (PARTY), its own deck, a relabelled PRESENT button, LCD keys,
## dance chips, a mouse route and an input for its mode-only move, key placeholders in its lines,
## and its own end-of-list show (WORD) or the SRT's (PARTY). Every call is written to `calls`.

## Every seam call, in order: [test, name, extra] (cleared by the tests).
static var calls: Array = []
## Actions the probe pretends not to claim (the MUST_CLAIM test).
static var unclaimed: Array[StringName] = []
## hoot_step() hands the list back (-2) after this many of Hoot's steps (-1 = never).
static var hand_back_after := -1
## beat_action() answers {action: none} (no beat now, as while a confirm chip is up).
static var hold_beats := false
## on_present()'s wait: the seconds the item takes.
const WAIT_S := 0.35
const CALLOUT_AT := Vector2(420, 300)

var test: StringName = &""
var panel: Control
var rects: Dictionary = {}
var last_state: Dictionary = {}
var celebrated: Dictionary = {}
var voice_calls := 0
## screen.clock() at each on_present() and on_answer().
var present_at: Array[float] = []
var answer_at: Array[float] = []
var _hoot_steps := 0


func _log(what: String, extra: Variant = null) -> void:
	calls.append([String(test), what, extra])


func _party() -> bool:
	return test == &"sin"


func panel_id() -> String:
	return "probe_%s_panel" % String(test)


func setup(s: SpeechScreen) -> void:
	super(s)
	test = s.session.test
	panel = Control.new()
	panel.name = "Probe%sPanel" % String(test).capitalize()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.ui_root().add_child(panel)
	_log("setup")


func enter(plan: Dictionary) -> void:
	_log("enter", String(plan.get("list", "")))
	panel.visible = true
	_hoot_steps = 0
	screen.memory["probe_entries"] = int(screen.memory.get("probe_entries", 0)) + 1
	# a mode may relabel a base button; the SRT gets it back
	var b := screen.button(&"present") as SpButton
	b.text = "SAY IT"
	b.glyph = SpButton.Glyph.EYE
	screen.card.carrier = "Say the word"
	screen.bubble.aside = "probe aside"


func exit() -> void:
	_log("exit")
	panel.visible = false


func hidden_base_widgets() -> Array[StringName]:
	if _party():
		return [&"ladder", &"meter", &"mask_button"]
	return [&"ladder", &"meter", &"tally", &"store_button"]


func layout(r: Dictionary) -> void:
	rects = r
	panel.position = (r["mid"] as Rect2).position
	panel.size = (r["mid"] as Rect2).size


func deck_groups() -> Array[Dictionary]:
	if _party():
		return [{"title": "PARTY", "buttons": [{"action": &"present", "width": 180.0}, {"action": &"score_missed", "width": 110.0},
			{"action": &"score_correct", "width": 110.0}, {"action": &"store", "width": 160.0}]}]
	return [{"title": "WORD", "buttons": [{"action": &"present", "width": 200.0}, {"id": "speech_incorrect_button", "width": [120.0, 140.0]},
		{"id": "speech_correct_button", "width": 130.0}]}, {"title": "GET READY", "buttons": [{"action": &"probe_ready", "width": 150.0}]}]


func make_buttons() -> Dictionary:
	if _party():
		return {&"store": screen.make_button("probe_sin_lock_button", "LOCK IN", AoButton.Icon.NONE, SpButton.Glyph.LOCK, Palette.MINT, &"store", &"store")}
	return {&"probe_ready": screen.make_button("probe_wrs_ready_button", "READY", AoButton.Icon.NONE, SpButton.Glyph.EYE, Palette.SKY,
		&"toggle_lens", &"probe_ready")}


func input_for(action: StringName, _args: Dictionary = {}) -> StringName:
	return &"toggle_lens" if action == &"probe_ready" else &""


func mouse_for(action: StringName, _args: Dictionary = {}) -> String:
	return panel_id() if action == &"probe_ready" else ""


func handle_input(event: InputEvent) -> bool:
	if not _party() and event.is_action_pressed(&"toggle_lens") and screen.player_ok():
		_log("handle_input", "toggle_lens")
		screen.do_action(&"probe_ready")
		return true
	return false


func act(action: StringName, args: Dictionary = {}) -> bool:
	_log("act", action)
	if action in unclaimed:
		return false
	match action:
		&"probe_ready":
			screen.session.mode.act(action, args)
			screen.refresh()
			return true
		&"score_correct", &"score_missed":
			if _party():
				if not screen.session.score(action == &"score_correct").is_empty():
					screen.refresh()
			else:
				screen.score_word(action == &"score_correct")
			return true
		&"store":
			if _party():
				var r := screen.session.store()
				if not r.is_empty() and not screen.session.is_done():
					screen.check_hoot_after()
					screen.refresh()
			else:
				screen.session.store()   # refused: the list ends itself
				screen.deny(screen.button(&"store"), "Lists end themselves: no {key:store} needed.")
			return true
	return super(action, args)


func on_present(trial: Dictionary) -> float:
	_log("on_present", int(trial.get("n", 0)))
	var it := SpeechMaterial.item(screen.session.list_id, String(trial["item_id"]))
	screen.voice.play_item(screen.session.ear, screen.session.list_id, it, float(int(trial["db"])))
	voice_calls += 1
	present_at.append(screen.clock())
	screen.card.state = &"talking"
	screen.card.set_word(String(trial["word"]), [], int(trial["n"]), screen.session.mode.words_left())
	return WAIT_S


func on_answer(trial: Dictionary) -> bool:
	_log("on_answer", String(trial.get("said", "")))
	answer_at.append(screen.clock())
	if _party():
		return false
	screen.bubble.style = &"loud"
	screen.bubble.show_answer(String(trial.get("said", "")))
	return true


func on_scored(trial: Dictionary) -> void:
	_log("on_scored", trial.get("scored"))


func on_stored(sheet: Dictionary) -> bool:
	_log("on_stored", String(sheet.get("slot", "")))
	if _party():
		return false
	screen.after(0.3, screen.complete_list.bind(sheet))
	return true


func on_technique(kind: StringName, data: Dictionary) -> bool:
	_log("on_technique", kind)
	return kind == &"probe_quiet" or (kind == &"probe_ready_ok" and data.has("quiet"))


func kind_class(kind: StringName) -> StringName:
	match kind:
		&"probe_slip":
			return &"repeat"
		&"probe_clean", &"probe_lock":
			return &"clean"
		&"probe_no_store", &"probe_level_locked", &"probe_mask_locked":
			return &"error"
	return &""


func target_for(kind: StringName, _data: Dictionary) -> String:
	return panel_id() if kind == &"probe_slip" else ""


func coach_text(rec: Dictionary) -> Array:
	match StringName(String(rec.get("action", ""))):
		&"probe_ready":
			return ["Get ready first: press {key:toggle_lens}.", "probe_wrs_ready_button", "ready"]
		&"present":
			return ["Say the next one: press {key:present_tone}.", "speech_present_button",
				"present%d" % screen.session.trials_for().size()]
	return []


func beat_id(rec: Dictionary) -> StringName:
	return &"probe_beat" if StringName(String(rec.get("action", ""))) == &"probe_ready" else &"speech"


func beat_action(_rec: Dictionary) -> Dictionary:
	return {"action": &"none"} if hold_beats else {}


func beat_info(info: Dictionary) -> Dictionary:
	info["probe"] = String(test)
	return info


func hoot_step() -> float:
	_hoot_steps += 1
	_log("hoot_step", _hoot_steps)
	if hand_back_after >= 0 and _hoot_steps > hand_back_after:
		return -2.0
	return -1.0


func hoot_turn_text() -> String:
	return "My turn on the probe list: watch {key:present_tone}!"


func lcd_view(view: Dictionary) -> Dictionary:
	view["test_chip"] = "PROBE " + String(test).to_upper()
	view["info_line"] = "%d items left" % int(view.get("words_left", 0))
	view["aux"] = [{"label": "ITEMS", "value": str(int(view.get("words_left", 0)))}]
	if _party():
		view["ear_chip"] = "BOTH"
		view["big_caption"] = "dB SNR"
	return view


func dance_specs() -> Array[Dictionary]:
	return [{"title": "HEARD", "sub": "tick"}, {"title": "LOST", "sub": "cross"}, {"title": "DONE", "sub": "next", "icon": &"stamp"}]


func refresh(state: Dictionary) -> void:
	last_state = state


func celebrate(sheet: Dictionary) -> bool:
	_log("celebrate", String(sheet.get("slot", "")))
	celebrated = sheet
	return not _party()


func callout_point() -> Vector2:
	return CALLOUT_AT if not _party() else Vector2.ZERO


func mastery_skill(kind: StringName) -> StringName:
	return &"probe_skill" if kind == &"probe_clean" else &""


func anchors() -> Dictionary:
	return {panel_id(): panel}


func restore_base() -> void:
	_log("restore_base")


func extra_state() -> Dictionary:
	return {"lens_on": false, "confirm_pending": false, "practice": _party(), "probe": String(test)}


func montage(sheet: Dictionary) -> float:
	_log("montage", String(sheet.get("slot", "")))
	return 0.25
