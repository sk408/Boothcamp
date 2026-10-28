extends Node
## PracticalCheck (training, dev only; story/tests is never exported): plays one station of The Practical
## end to end with a test bot and prints PRACTICAL_CHECK_RESULT {json} (docs/training/PRACTICAL_EXAM.md).
##   timeout 300 godot --headless --path . --fixed-fps 30 -- \
##     --scene=res://story/tests/practical_check.tscn --fresh --policy=careful --speed=4 --seed=1
## --station=kit|hands|td picks the station (default kit). The room opens on Masking
## School, so the bot first switches to THE PRACTICAL (the tab's click with --policy=mouse, Tab with keys,
## select_lesson for careful), then opens the station.
## Policies (--policy=):
##   careful  every beat's solver: each Try it and hole answered right, at par
##   keys     real key presses: Enter, 1-4 for the right answer, Enter, T on the scorecard
##   mouse    real clicks only: the tab, the station, Start, the answers, Next, "Back to the Training room"
##   guess    real keys, a wrong answer first on every hole: every hole a bogey (an unsafe grip a STOP,
##            PracticalDeck.UNSAFE_STROKES over), no star
##   hint     real keys, Hoot's hint (H) then the right answer: every hole a bogey, no star
## --via-title: start on the title and open the Training room from its Training button, as a player would.
## Every run ends back in the Training room on THE PRACTICAL, whose station must then show its record
## and card(s). A first visit to a station with a movie (Station 2) starts it; the bot skips it. --shots=/abs/dir under xvfb: practical_room, practical_intro, practical_try, practical_card,
## practical_card_right, practical_scorecard, practical_room_after.
## Exit codes: 0 every check passed, 1 a check failed, 2 stalled, 3 overall timeout,
## 5 script errors were logged, 6 a mouse target was not found.

const TITLE_SCENE := "res://story/title_screen.tscn"
const ROOM_SCENE := "res://story/training/training_room.tscn"
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const PracticalSchool := preload("res://story/training/practical/practical_school.gd")


func demo_start() -> void:
	pass  # the driver below starts in _ready


func _ready() -> void:
	var d := Driver.new()
	d.name = "PracticalCheckDriver"
	get_tree().root.add_child.call_deferred(d)
	Events.goto_scene.emit.call_deferred(TITLE_SCENE if Game.cli_flag("via-title") else ROOM_SCENE)


class ErrorCounter extends Logger:
	var count := 0
	var messages: PackedStringArray = []
	var _m := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _n: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type != Logger.ERROR_TYPE_SCRIPT and error_type != Logger.ERROR_TYPE_ERROR:
			return
		_m.lock()
		count += 1
		if messages.size() < 20:
			messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_m.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


class Driver extends Node:
	const READ_S := 0.35
	const STALL_S := 40.0
	const MAX_S := 300.0
	const Progress := preload("res://story/training/training_progress.gd")
	const SCHOOL_SCENE := "res://story/training/practical/practical_school.tscn"

	var policy := "careful"
	var station := "kit"
	var info: Dictionary = {}
	var errors := ErrorCounter.new()
	var misses: PackedStringArray = []
	var problems: PackedStringArray = []
	var beats := {}
	var school: Node
	var visits := 0
	var expect_over := 0   # what this run's misses and hints should cost
	var tries_seen := 0    # Try it cards (a guided ladder asks once per rung)
	var result: Dictionary = {}
	var _clock := 0.0
	var _last := 0.0
	var _done := false
	var _mouse_pos := Vector2(640, 360)
	var _shot := {}

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		OS.add_logger(errors)
		policy = Game.cli_value("policy", "careful")
		station = Game.cli_value("station", "kit")
		info = PracticalDeck.station(station)
		if info.is_empty() or not bool(info["built"]):
			_finish.call_deferred(1, "no built station '%s'" % station)
			return
		Events.awaiting_input.connect(_on_awaiting)
		Events.scene_changed.connect(func(path: String, node: Node) -> void:
			_last = _clock
			if path == SCHOOL_SCENE:
				school = node)
		print("PracticalCheck: policy %s, speed x%s" % [policy, str(Engine.time_scale)])

	func _process(delta: float) -> void:
		_clock += delta
		if _done:
			return
		if _clock - _last > STALL_S:
			_finish(2, "stalled (beats so far %s)" % str(beats))
		elif _clock > MAX_S:
			_finish(3, "overall timeout")

	func _wait(s: float) -> void:
		await get_tree().create_timer(s, false).timeout

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _shoot(n: String) -> void:
		if _shot.has(n):
			return
		_shot[n] = true
		Events.screenshot_requested.emit(n)
		await _wait(0.2)

	func _on_awaiting(beat: StringName, data: Dictionary, solver: Callable) -> void:
		_last = _clock
		beats[String(beat)] = int(beats.get(String(beat), 0)) + 1
		match beat:
			&"disclaimer_ok":
				await _wait(0.5)
				if policy == "mouse":
					await _click_text("Got it")
				else:
					solver.call()
			&"title_start":
				await _wait(0.8)
				await _open_training()
			&"training_room":
				await _wait(0.6)
				if String(data.get("lesson", "")) != "practical":
					await _switch_lesson()
					return
				visits += 1
				if visits > 1:
					await _shoot("practical_room_after")
					_check_room()
					return
				await _shoot("practical_room")
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text(String(info["name"]))
					_:
						await _key(KEY_1 + int(info["num"]) - 1)
			&"practical_intro":
				await _wait(READ_S)
				await _shoot("practical_intro")
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text("Start")
					_:
						await _action(&"ui_accept")
			&"practical_try":
				if int(data.get("sub", 0)) == 0:
					tries_seen += 1
				await _wait(READ_S)
				await _shoot("practical_try")
				await _answer(data, solver, false)
			&"explainer":
				await _wait(0.6)
				solver.call()   # skip Hoot's movie (test_training_practical checks it)
			&"practical_card":
				await _wait(READ_S)
				await _shoot("practical_card")
				await _shoot("practical_card_%s" % String(data.get("kind", "")))
				var n := (data["options"] as Array).size()
				if policy == "guess":   # a wrong pick on every rung of a ladder too
					expect_over += PracticalDeck.UNSAFE_STROKES if (data.get("unsafe", []) as Array).has((int(data["best"]) + 1) % n) else 1
				elif policy == "hint" and int(data.get("sub", 0)) == 0:   # one hint a hole
					expect_over += 1
				await _answer(data, solver, true)
			&"practical_next":
				await _wait(0.4)
				await _shoot("practical_card_right")
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text(String((data.get("mouse", {}) as Dictionary).get("click", "Next")))
					_:
						await _action(&"ui_accept")
			&"practical_scorecard":
				await _wait(0.6)
				await _shoot("practical_scorecard")
				result = PracticalSchool.last_result
				_check_result(data)
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text("Back to the Training room")
					"keys":
						await _key(KEY_T)
					_:
						await _action(&"ui_accept")

	## The room opens on Masking School: switch to THE PRACTICAL like a player.
	func _switch_lesson() -> void:
		var room := get_tree().get_first_node_in_group("training_room")
		match policy:
			"careful":
				room.call("select_lesson", "practical")
			"mouse":
				await _click_text("THE PRACTICAL")
			_:
				await _key(KEY_TAB)

	func _answer(beat: Dictionary, solver: Callable, round_card: bool) -> void:
		var best := int(beat["best"])
		var n := (beat["options"] as Array).size()
		var mode := policy if round_card or policy in ["careful", "mouse"] else "keys"
		match mode:
			"careful":
				solver.call()
			"mouse":
				await _click_text(String((beat["options"] as Array)[best]), true)   # the button, not Hoot's line
			"keys":
				await _key(KEY_1 + best)
			"guess":
				await _key(KEY_1 + (best + 1) % n)
				await _wait(0.2)
				await _key(KEY_1 + best)
			"hint":
				await _key(KEY_H)
				await _wait(0.2)
				await _key(KEY_1 + best)

	func _check_result(score: Dictionary) -> void:
		var strokes: Array = result.get("strokes", [])
		var over := int(result.get("over_par", -1))
		var holes := PracticalDeck.ROUND_HOLES
		if strokes.size() != holes:
			problems.append("%d holes, expected %d" % [strokes.size(), holes])
		var want := expect_over
		if over != want:
			problems.append("%s run finished %d over par, expected %d (strokes %s)" % [policy, over, want, str(strokes)])
		if bool(score.get("star", false)) != (want == 0):
			problems.append("the scorecard's star is %s" % str(score.get("star")))
		var tries := PracticalDeck.tries(station).size()
		if tries_seen != tries:
			problems.append("%d Try it cards, expected %d" % [tries_seen, tries])

	func _check_room() -> void:
		var rec: Dictionary = Progress.station(PracticalDeck.LESSON, station)
		if int(rec["plays"]) != 1:
			problems.append("station %s saved %d plays" % [station, int(rec["plays"])])
		if bool(rec["star"]) != bool(result.get("star", false)):
			problems.append("station %s's saved star is %s" % [station, str(rec["star"])])
		var room := get_tree().get_first_node_in_group("training_room")
		for card_id: String in [String(info["card"]), String(info.get("card2", ""))]:
			if card_id == "":
				continue
			if not Progress.has_card(PracticalDeck.LESSON, card_id):
				problems.append("the %s card was not earned" % card_id)
			var card := room.find_child("card_" + card_id, true, false) if room != null else null
			if card == null or not bool(card.get("earned")):
				problems.append("the room does not pin the %s card" % card_id)
		if Progress.stars("masking") != 0 or not Progress.cards("masking").is_empty():
			problems.append("The Practical wrote into Masking School's save")
		var code := 0
		if not problems.is_empty():
			code = 1
		if errors.count > 0:
			code = 5
		elif not misses.is_empty():
			code = 6
		print("PRACTICAL_CHECK_RESULT " + JSON.stringify({"policy": policy, "station": station, "result": result, "beats": beats, "problems": problems,
			"errors": errors.count, "error_messages": errors.messages, "misses": misses}))
		_finish(code, "; ".join(problems + misses + errors.messages))

	## The title's Training button, like a player: a click, or Down until it is highlighted and Enter.
	func _open_training() -> void:
		if policy == "mouse":
			await _click_text("Training")
			return
		for i in 10:
			if _find_text("> Training") != null:
				await _wait(0.3)
				await _action(&"ui_accept")
				return
			await _action(&"ui_down")
		_finish(1, "Down never highlighted the title's Training button")

	func _finish(code: int, why: String) -> void:
		if _done:
			return
		_done = true
		if code != 0:
			print("PRACTICAL_CHECK FAIL (%d): %s" % [code, why])
		else:
			print("PRACTICAL_CHECK PASS")
		Events.quit_requested.emit(code)

	# ---------------------------------------------------------------- real input

	func _action(a: StringName) -> void:
		for pressed: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = a
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)

	func _key(code: Key) -> void:
		for pressed: bool in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = code
			ev.physical_keycode = code
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)

	func _to_window(p: Vector2) -> Vector2:
		return get_viewport().get_final_transform() * p

	func _click(at: Vector2) -> void:
		var mv := InputEventMouseMotion.new()
		mv.position = _to_window(at)
		mv.global_position = mv.position
		mv.relative = mv.position - _to_window(_mouse_pos)
		Input.parse_input_event(mv)
		_mouse_pos = at
		await _frames(2)
		for pressed: bool in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.position = _to_window(at)
			ev.global_position = ev.position
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = pressed
			ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
			Input.parse_input_event(ev)
			await _frames(2)

	func _find_text(prefix: String, root: Node = null, buttons := false) -> Control:
		if root == null:
			root = get_tree().root
		for c in root.get_children():
			var found := _find_text(prefix, c, buttons)
			if found != null:
				return found
		if root is Control and (root as Control).is_visible_in_tree():
			var t := ""
			if root is Button:
				t = (root as Button).text
				if (root as Button).disabled:
					t = ""
			elif root is Label and not buttons:
				t = (root as Label).text
			if t != "" and t.strip_edges().begins_with(prefix):
				return root as Control
		return null

	func _click_text(prefix: String, buttons := false) -> void:
		var c := _find_text(prefix, null, buttons)
		if c == null:
			misses.append("text '%s'" % prefix)
			return
		await _click(c.get_global_rect().get_center())
