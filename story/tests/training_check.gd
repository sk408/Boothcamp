extends Node
## TrainingCheck (training, dev only; story/tests is never exported): plays one Masking School station
## end to end with a test bot and prints TRAINING_CHECK_RESULT {json} (docs/training/MASKING_TRAINER.md).
## The main autoplay bot ends every run on a visit's results, so the Training room gets this harness.
##   timeout 300 godot --headless --path . --fixed-fps 30 -- \
##     --scene=res://story/tests/training_check.tscn --fresh --policy=careful --speed=4 --seed=1
## Policies (--policy=):
##   careful  every beat's solver: the movie skipped, each Try it raised to the Ghost, every hole at par
##   keys     real key presses: Enter, the louder key, 1-3 for the right answer, Enter, T on the scorecard
##   mouse    real clicks only: Start, "Louder +5", Next, the right answer, "Back to the Training room"
##   guess    real keys, a wrong answer first on every hole: every hole a bogey, no star
##   hint     real keys, Hoot's hint (H) then the right answer: every hole a bogey, no star
## --via-title: start on the title, open the Training room from its Training button and pick station 1
## there (a click with --policy=mouse; Down arrows, Enter and the 1 key otherwise), as a player would.
## Every run ends back in the Training room, whose station 1 must then show its record.
## --shots=/abs/dir under xvfb: training_room, training_intro, training_try, training_try_boo,
## training_card, training_card_right, training_scorecard.
## Exit codes: 0 every check passed, 1 a check failed, 2 stalled, 3 overall timeout,
## 5 script errors were logged, 6 a mouse target was not found.

const TITLE_SCENE := "res://story/title_screen.tscn"
const ROOM_SCENE := "res://story/training/training_room.tscn"
const SCHOOL_SCENE := "res://story/training/masking/masking_school.tscn"
const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const MaskingSchool := preload("res://story/training/masking/masking_school.gd")


func demo_start() -> void:
	pass  # the driver below starts in _ready


func _ready() -> void:
	var d := Driver.new()
	d.name = "TrainingCheckDriver"
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
	const MAX_S := 400.0
	const Progress := preload("res://story/training/training_progress.gd")

	var policy := "careful"
	var errors := ErrorCounter.new()
	var misses: PackedStringArray = []
	var problems: PackedStringArray = []
	var beats := {}
	var school: Node
	var rooms := 0
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
		Events.awaiting_input.connect(_on_awaiting)
		Events.scene_changed.connect(func(path: String, node: Node) -> void:
			_last = _clock
			if path == SCHOOL_SCENE:
				school = node)
		print("TrainingCheck: policy %s, speed x%s" % [policy, str(Engine.time_scale)])

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

	func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
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
				rooms += 1
				await _wait(0.6)
				await _shoot("training_room")
				if rooms > 1:
					_check_room()
					return
				if policy == "careful":
					solver.call()
				elif policy == "mouse":
					await _click_text("Why mask?")
				elif Game.cli_flag("via-title"):
					await _key(KEY_1)
				else:
					await _action(&"ui_accept")
			&"training_intro":
				await _wait(READ_S)
				await _shoot("training_intro")
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text("Start")
					_:
						await _action(&"ui_accept")
			&"explainer":
				await _wait(0.6)
				solver.call()   # skip Hoot's movie (the movie's own harness checks it)
			&"training_try":
				await _wait(READ_S)
				await _shoot("training_try")
				await _try(info, solver)
			&"training_card":
				await _wait(READ_S)
				await _shoot("training_card")
				await _card(info, solver)
			&"training_next":
				await _wait(0.4)
				await _shoot("training_card_right")
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text(String((info.get("mouse", {}) as Dictionary).get("click", "Next")))
					_:
						await _action(&"ui_accept")
			&"training_scorecard":
				await _wait(0.6)
				await _shoot("training_scorecard")
				result = MaskingSchool.last_result
				_check_result(info)
				match policy:
					"careful":
						solver.call()
					"mouse":
						await _click_text("Back to the Training room")
					"keys":
						await _key(KEY_T)
					_:
						await _action(&"ui_accept")

	func _try(info: Dictionary, solver: Callable) -> void:
		var target := int(info["target"])
		if policy == "careful":
			solver.call()
			return
		for i in 30:
			if _school_state() != &"try":
				break
			if policy == "mouse":
				await _click_text("Louder +5")
			else:
				await _action(&"louder")
			await _wait(0.1)
		await _shoot("training_try_boo")
		var tone := int((school.get("_card") as Dictionary).get("tone", -1)) if is_instance_valid(school) else -1
		if tone != target or _school_state() != &"try_done":
			problems.append("Try it %d: the Ghost answered at %d, expected %d" % [int(info["step"]), tone, target])
		if policy == "mouse":
			await _click_text("Next")
		else:
			await _action(&"ui_accept")

	func _card(info: Dictionary, solver: Callable) -> void:
		var best := int(info["best"])
		match policy:
			"careful":
				solver.call()
			"mouse":
				await _click_text(String((info["options"] as Array)[best]))
			"keys":
				await _key(KEY_1 + best)
			"guess":
				await _key(KEY_1 + (best + 1) % MaskDeck.WHO.size())
				await _wait(0.2)
				await _key(KEY_1 + best)
			"hint":
				await _key(KEY_H)
				await _wait(0.2)
				await _key(KEY_1 + best)

	func _school_state() -> StringName:
		return StringName(school.get("_state")) if is_instance_valid(school) else &""

	func _check_result(info: Dictionary) -> void:
		var strokes: Array = result.get("strokes", [])
		var over := int(result.get("over_par", -1))
		if strokes.size() != MaskDeck.ROUND_HOLES:
			problems.append("%d holes, expected %d" % [strokes.size(), MaskDeck.ROUND_HOLES])
		var want := 0 if policy in ["careful", "keys", "mouse"] else MaskDeck.ROUND_HOLES
		if over != want:
			problems.append("%s run finished %d over par, expected %d (strokes %s)" % [policy, over, want, str(strokes)])
		if bool(info.get("star", false)) != (want == 0):
			problems.append("the scorecard's star is %s" % str(info.get("star")))
		if int(beats.get("explainer", 0)) != 1:
			problems.append("Hoot's masking movie started %d times on a fresh save (expected once)" % int(beats.get("explainer", 0)))
		if int(beats.get("training_try", 0)) != MaskDeck.WHY_TRIES.size():
			problems.append("%d Try it steps, expected %d" % [int(beats.get("training_try", 0)), MaskDeck.WHY_TRIES.size()])

	func _check_room() -> void:
		var rec: Dictionary = Progress.station(MaskDeck.LESSON, "why")
		if int(rec["plays"]) != 1:
			problems.append("station 1 saved %d plays" % int(rec["plays"]))
		if bool(rec["star"]) != (int(result.get("over_par", -1)) == 0):
			problems.append("station 1's saved star is %s" % str(rec["star"]))
		if not Progress.has_card(MaskDeck.LESSON, "skull_wall"):
			problems.append("the Skull Wall card was not earned")
		var room := get_tree().get_first_node_in_group("training_room")
		var card := room.find_child("card_skull_wall", true, false) if room != null else null
		if card == null or not bool(card.get("earned")):
			problems.append("the room does not pin the Skull Wall card")
		var code := 0
		if not problems.is_empty():
			code = 1
		if errors.count > 0:
			code = 5
		elif not misses.is_empty():
			code = 6
		print("TRAINING_CHECK_RESULT " + JSON.stringify({"policy": policy, "result": result, "beats": beats, "problems": problems,
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
			print("TRAINING_CHECK FAIL (%d): %s" % [code, why])
		else:
			print("TRAINING_CHECK PASS")
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

	func _find_text(prefix: String, root: Node = null) -> Control:
		if root == null:
			root = get_tree().root
		for c in root.get_children():
			var found := _find_text(prefix, c)
			if found != null:
				return found
		if root is Control and (root as Control).is_visible_in_tree():
			var t := ""
			if root is Button:
				t = (root as Button).text
				if (root as Button).disabled:
					t = ""
			elif root is Label:
				t = (root as Label).text
			if t != "" and t.strip_edges().begins_with(prefix):
				return root as Control
		return null

	func _click_text(prefix: String) -> void:
		var c := _find_text(prefix)
		if c == null:
			misses.append("text '%s'" % prefix)
			return
		await _click(c.get_global_rect().get_center())
