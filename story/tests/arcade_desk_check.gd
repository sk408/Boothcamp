extends Node
## ArcadeDeskCheck (arcade, dev only; story/tests is never exported): plays one Ears, Please! shift
## end to end with a test bot and prints ARCADE_RESULT {json} (the main autoplay bot ends every run
## on a visit's results, so the arcade cabinets get their own harness, like arcade_chute_check).
##   timeout 300 godot --headless --path . --fixed-fps 30 -- \
##     --scene=res://story/tests/arcade_desk_check.tscn --fresh --policy=careful --speed=4 --seed=1 --shift=1
## Policies (--policy=):
##   careful           the beats' solvers after a short reading pause: every file clean, promotion
##                     (shift 1), the VIP handled, the board
##   keys              real keys: 1-3 to stamp, the arrows and Enter to point (it walks the pointer
##                     to the proof), Enter for notes, K E Y for the initials, T back to the arcade
##   mouse             real clicks only: the stamp, the proof, Next, the initials' + and OK,
##                     "Back to the arcade"
##   fit_everything    key 1 on every file: missed red flags, a negative raw score, never the board
##                     (shift 3: the second same-day patient sent home closes the desk instead)
##   refer_everything  key 2 and Enter on every file (points at the first box): no flag missed, many
##                     extra referrals, never the board (shift 3: a same-day patient sent home)
##   today_everything  key 3 on every file (shift 3 only): nobody sent home, but many files sent
##                     too fast, never the board
##   guess             a random stamp and a random target: never the board
##   help              HOOT HELP every time: no files, no points, no board
## The warm-up is played by the solver for every policy except keys and mouse.
## --shift=N: play shift N (opens it in the save first). --via-title: start on the title, open the
## Arcade and pick the Ears, Please! cabinet, as a player would. --picker: pick shift N (2 or 3) in the
## shift picker (by key, or a click with the mouse policy) instead of going straight to it.
## Exit codes: 0 every check passed, 1 a check failed, 2 stalled, 3 overall timeout,
## 5 script errors were logged, 6 a mouse target was not found.

const DESK_SCENE := "res://story/arcade/ears_please.tscn"
const HALL_SCENE := "res://story/arcade/arcade_hall.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const EarsPlease := preload("res://story/arcade/ears_please.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const DeskRules := preload("res://story/arcade/desk_rules.gd")
const DeskRun := preload("res://story/arcade/desk_run.gd")


func demo_start() -> void:
	pass  # the driver below starts in _ready


func _ready() -> void:
	var shift := clampi(int(Game.cli_value("shift", "1")), 1, DeskRun.PLAYABLE)
	ArcadeScores.data("ears_please")["unlocked"] = shift
	if not Game.cli_flag("picker"):
		EarsPlease.again_shift = shift   # --picker: open the shift picker and pick shift N there
	var d := Driver.new()
	d.name = "ArcadeDeskDriver"
	d.shift = shift
	get_tree().root.add_child.call_deferred(d)
	Events.goto_scene.emit.call_deferred(TITLE_SCENE if Game.cli_flag("via-title") else DESK_SCENE)


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
	const READ_S := 0.35        ## game seconds the bot "reads" before each stamp and proof
	const STALL_S := 30.0
	const MAX_S := 500.0

	var policy := "careful"
	var shift := 1
	var errors := ErrorCounter.new()
	var misses: PackedStringArray = []
	var problems: PackedStringArray = []
	var beats := {}
	var desk: Node
	var at_hall := false
	var _rng := RandomNumberGenerator.new()
	var _last := 0.0
	var _clock := 0.0
	var _done := false
	var _mouse_pos := Vector2(640, 360)
	var _bosses := {}
	var _after_end := 0

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		OS.add_logger(errors)
		policy = Game.cli_value("policy", "careful")
		_rng.seed = int(Game.cli.get("seed", 1))
		Events.awaiting_input.connect(_on_awaiting)
		Events.scene_changed.connect(func(path: String, node: Node) -> void:
			_last = _clock
			if path == DESK_SCENE:
				desk = node
			elif path == HALL_SCENE:
				at_hall = true)
		print("ArcadeDeskCheck: policy %s, shift %d, speed x%s, seed %d" % [policy, shift, str(Engine.time_scale), _rng.seed])

	func _process(delta: float) -> void:
		_clock += delta
		if _done:
			return
		if _clock - _last > STALL_S:
			_finish(2, "stalled (beats so far %s, desk %s)" % [str(beats), str(desk.call("stats")) if is_instance_valid(desk) else "-"])
		elif _clock > MAX_S:
			_finish(3, "overall timeout")

	func _wait(s: float) -> void:
		await get_tree().create_timer(s, false).timeout

	func _frames(n: int) -> void:
		for i in n:
			await get_tree().process_frame

	func _warm() -> bool:
		return is_instance_valid(desk) and String(desk.get("_phase")) == "warmup"

	func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
		_last = _clock
		beats[String(beat)] = int(beats.get(String(beat), 0)) + 1
		match beat:
			&"desk_shift":
				await _wait(0.5)
				if policy == "mouse":
					await _click(_anchor("desk_shift_%d" % shift))
				else:
					await _key(KEY_0 + shift)
			&"desk_stamp":
				if is_instance_valid(desk) and String(desk.get("_phase")) == "tally":
					_after_end += 1
				if bool(info.get("boss", false)):
					_bosses[int(info["file"])] = true
				await _wait(READ_S)
				await _stamp(info, solver)
			&"desk_prove":
				await _wait(READ_S)
				await _prove(info, solver)
			&"desk_note":
				await _wait(0.2)
				await _note(solver)
			&"arcade_initials":
				await _wait(0.5)
				await _initials(solver)
			&"arcade_results":
				await _wait(0.8)
				await _results()
			&"disclaimer_ok":
				await _wait(0.5)
				if policy == "mouse":
					await _click_text("Got it")
				else:
					solver.call()
			&"title_start":
				await _wait(0.8)
				await _open_arcade()
			&"arcade_hall":
				if desk != null:
					return   # back at the hall after the results: the shift is over
				await _wait(0.6)
				if policy == "mouse":
					await _click(_anchor("arcade_cabinet_ears_please"))
				else:
					await _key(KEY_2)

	func _open_arcade() -> void:
		if policy == "mouse":
			if _find_text("Arcade") == null:
				_finish(6, "the title has no Arcade button")
				return
			await _click_text("Arcade")
			return
		for i in 10:
			if _find_text("> Arcade") != null:
				await _action(&"ui_accept")
				return
			await _action(&"ui_down")
		_finish(1, "Down never highlighted the title's Arcade button")

	func _action(a: StringName) -> void:
		for pressed: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = a
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)

	func _stamp(info: Dictionary, solver: Callable) -> void:
		var decision := String(info["decision"])
		var right_key: Key = [KEY_1, KEY_2, KEY_3][["fit", "refer", "today"].find(decision)]
		if bool(info.get("warmup", false)) and policy != "keys" and policy != "mouse":
			solver.call()
			return
		match policy:
			"careful":
				solver.call()
			"keys":
				await _key(right_key)
			"mouse":
				await _click(_anchor(String((info["mouse"] as Dictionary)["click"])))
			"fit_everything":
				await _key(KEY_1)
			"refer_everything":
				await _key(KEY_2)
			"today_everything":
				await _key(KEY_3)
			"guess":
				await _key(KEY_1 + _rng.randi() % (info["options"] as Array).size())
			"help":
				await _key(KEY_H)

	func _prove(info: Dictionary, solver: Callable) -> void:
		if _warm() and policy != "keys" and policy != "mouse":
			solver.call()
			return
		match policy:
			"careful":
				solver.call()
			"keys":
				await _walk_to(info.get("target", {}))
				await _key(KEY_ENTER)
			"mouse":
				await _click(_anchor(String((info["mouse"] as Dictionary)["click"])))
			"refer_everything":
				await _key(KEY_ENTER)
			"guess":
				for i in _rng.randi() % 3:
					await _key(KEY_DOWN)
				for i in _rng.randi() % 10:
					await _key(KEY_RIGHT)
				await _key(KEY_ENTER)
			_:
				solver.call()

	## Walk the PROVE IT pointer to a target with the arrow keys, toward it on the longer axis.
	func _walk_to(target: Dictionary) -> void:
		if target.is_empty() or not is_instance_valid(desk):
			return
		var view: Object = desk.get("_view")
		var aim: Vector2 = (view.call("target_rect", target) as Rect2).get_center()
		for i in 30:
			var at: Dictionary = desk.call("prove_cursor")
			if at.is_empty() or DeskRun.same_target(at, target):
				return
			var here: Vector2 = (view.call("target_rect", at) as Rect2).get_center()
			var d := aim - here
			var k: Key = (KEY_RIGHT if d.x > 0 else KEY_LEFT) if absf(d.x) >= absf(d.y) else (KEY_DOWN if d.y > 0 else KEY_UP)
			await _key(k)
			if DeskRun.same_target(desk.call("prove_cursor"), at):
				# that way is blocked: try the other axis
				k = (KEY_DOWN if d.y > 0 else KEY_UP) if absf(d.x) >= absf(d.y) else (KEY_RIGHT if d.x > 0 else KEY_LEFT)
				await _key(k)
		misses.append("the arrows never reached %s" % str(target))

	func _note(solver: Callable) -> void:
		match policy:
			"keys":
				await _wait(EarsPlease.NOTE_MIN_S + 0.1)
				await _key(KEY_ENTER)
			"mouse":
				await _wait(0.4)
				await _click(_anchor("desk_note_ok"))
			_:
				solver.call()

	func _initials(solver: Callable) -> void:
		match policy:
			"keys":
				for k: Key in [KEY_K, KEY_E, KEY_Y]:
					await _key(k)
				await _key(KEY_ENTER)
			"mouse":
				var plus := _find_text("+")
				if plus == null:
					misses.append("initials +")
				else:
					await _click(plus.get_global_rect().get_center())
				await _click(_anchor("arcade_initials_ok"))
			_:
				solver.call()

	func _results() -> void:
		var st: Dictionary = desk.call("stats") if is_instance_valid(desk) else {}
		var board := DeskRun.board(shift)
		var table := ArcadeScores.table("ears_please", board)
		var files := int(st.get("files", 0))
		var clean := int(st.get("clean", 0))
		var on_board := int(beats.get("arcade_initials", 0)) > 0
		var unlocked := int(ArcadeScores.data("ears_please").get("unlocked", 1))
		var closed := bool(st.get("closed", false))
		var sum := 0
		for o: StringName in DeskRules.OUTCOMES:
			sum += int(st.get(String(o), 0))
		if sum != files:
			problems.append("outcomes add up to %d for %d files" % [sum, files])
		if int(st.get("score", -1)) < 0:
			problems.append("a negative score was shown")
		if int(st.get("missed_today", 0)) >= DeskRules.MAX_INCIDENTS and not closed:
			problems.append("%d same-day patients went home and the desk stayed open" % int(st.get("missed_today", 0)))
		if not closed and absf(float(st.get("t", 0.0)) - DeskRules.SHIFT_S) > 0.5:
			problems.append("the shift ended at %.1f s" % float(st.get("t", 0.0)))
		if _after_end > 0:
			problems.append("%d stamp beats after the clock ran out" % _after_end)
		if _bosses.size() > 1:
			problems.append("%d VIP files in one shift" % _bosses.size())
		if int(beats.get("desk_prove", 0)) > int(beats.get("desk_stamp", 0)):
			problems.append("more proofs than stamps")
		if Game.cli_flag("picker") and shift >= 2 and int(beats.get("desk_shift", 0)) < 1:
			problems.append("--picker never reached the shift picker")
		match policy:
			"careful", "keys", "mouse":
				if clean != files:
					problems.append("a reading bot made %d slips" % (files - clean))
				if files < (24 if policy == "careful" else 12):
					problems.append("only %d files in a shift" % files)
				if not on_board:
					problems.append("a perfect shift never reached the initials")
				if policy == "careful":
					if _bosses.is_empty() or not bool(st.get("boss_clean", false)):
						problems.append("the VIP never came, or was not handled clean")
					if String(st.get("rank", "")) != "Desk Legend":
						problems.append("a perfect shift ranked %s" % st.get("rank", ""))
					if shift < DeskRun.PLAYABLE and unlocked < shift + 1:
						problems.append("a perfect shift did not open shift %d" % (shift + 1))
			"fit_everything":
				var missed := int(st.get("missed_flag", 0)) + int(st.get("missed_today", 0))
				if closed:
					# shift 3: the second same-day patient sent home ends the shift, however few files came first
					if int(st.get("missed_today", 0)) != DeskRules.MAX_INCIDENTS:
						problems.append("the desk closed after %d same-day misses" % int(st.get("missed_today", 0)))
				elif missed * 4 < files:
					problems.append("FIT on everything missed only %d flags in %d files" % [missed, files])
				if int(st.get("over", 0)) != 0:
					problems.append("FIT on everything made extra referrals")
				if not closed and int(st.get("raw_score", 0)) >= 0:
					problems.append("FIT on everything did not lose points (%d)" % int(st.get("raw_score", 0)))
				if on_board or bool(st.get("promoted", false)):
					problems.append("FIT on everything reached the board or a promotion")
			"refer_everything":
				if int(st.get("missed_flag", 0)) != 0:
					problems.append("REFER on everything missed a flag")
				if closed:
					if int(st.get("missed_today", 0)) != DeskRules.MAX_INCIDENTS or int(st.get("too_urgent", 0)) != 0:
						problems.append("the desk closed after %d same-day misses, %d too urgent" % [int(st.get("missed_today", 0)), int(st.get("too_urgent", 0))])
				elif int(st.get("over", 0)) * 4 < files:
					problems.append("REFER on everything made only %d extra referrals" % int(st.get("over", 0)))
				if float(st.get("accuracy", 1.0)) >= 0.5:
					problems.append("REFER on everything was %.0f%% clean" % (float(st.get("accuracy", 0.0)) * 100.0))
				if on_board or bool(st.get("promoted", false)):
					problems.append("REFER on everything reached the board or a promotion")
				if shift >= 3 and int(st.get("missed_today", 0)) == 0:
					problems.append("REFER on everything never sent a same-day patient home")
			"today_everything":
				if int(st.get("missed_flag", 0)) + int(st.get("missed_today", 0)) != 0:
					problems.append("TODAY on everything missed a flag")
				if (int(st.get("over", 0)) + int(st.get("too_urgent", 0))) * 2 < files:
					problems.append("TODAY on everything sent only %d files too fast in %d" % [int(st.get("over", 0)) + int(st.get("too_urgent", 0)), files])
				if on_board or bool(st.get("promoted", false)):
					problems.append("TODAY on everything reached the board or a promotion")
			"guess":
				if float(st.get("accuracy", 1.0)) >= 0.6:
					problems.append("guessing was %.0f%% clean" % (float(st.get("accuracy", 0.0)) * 100.0))
				if on_board:
					problems.append("a guessing shift reached the board")
			"help":
				if files != 0 or int(st.get("score", -1)) != 0:
					problems.append("HOOT HELP scored (%d files, %d points)" % [files, int(st.get("score", 0))])
				if int(st.get("helps", 0)) < 10:
					problems.append("only %d helps" % int(st.get("helps", 0)))
				if on_board:
					problems.append("an all-help shift reached the board")
		if policy == "keys" and on_board and not table.any(func(r: Dictionary) -> bool: return r["initials"] == "KEY"):
			problems.append("typed initials KEY are not on the board")
		if policy == "mouse" and on_board and not table.any(func(r: Dictionary) -> bool: return r["initials"] == "BAA"):
			problems.append("clicked initials BAA are not on the board")
		if policy == "mouse" or policy == "keys":
			at_hall = false
			if policy == "mouse":
				await _click_text("Back to the arcade")
			else:
				await _key(KEY_T)
			for i in 90:
				if at_hall:
					break
				await _frames(1)
			if not at_hall:
				problems.append("%s did not reach the arcade" % ("Back to the arcade" if policy == "mouse" else "The T key"))
		var code := 0
		if not problems.is_empty():
			code = 1
		if errors.count > 0:
			code = 5
		elif not misses.is_empty():
			code = 6
		print("ARCADE_RESULT " + JSON.stringify({"policy": policy, "shift": shift, "stats": st, "beats": beats, "problems": problems,
			"errors": errors.count, "error_messages": errors.messages, "misses": misses, "board": table.slice(0, 5)}))
		_finish(code, "; ".join(problems))

	func _finish(code: int, why: String) -> void:
		if _done:
			return
		_done = true
		if code != 0:
			print("ARCADE_CHECK FAIL (%d): %s" % [code, why])
			if errors.count > 0:
				print("  errors: %s" % "\n  ".join(errors.messages))
		else:
			print("ARCADE_CHECK PASS")
		Events.quit_requested.emit(code)

	# ---------------------------------------------------------------- real input

	func _key(code: Key) -> void:
		for pressed: bool in [true, false]:
			var ev := InputEventKey.new()
			ev.keycode = code
			ev.physical_keycode = code
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)

	func _anchor(id: String) -> Vector2:
		var r := Hoot.anchor_screen_rect(id)
		if r == Rect2():
			misses.append("anchor " + id)
		return r.get_center()

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
