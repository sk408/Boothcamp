extends Node
## ArcadeChuteCheck (arcade, dev only; story/tests is never exported): plays one Chart Chute run
## end to end with a test bot and prints ARCADE_RESULT {json}. The main autoplay bot ends every
## run on a results_continue beat (a visit), so the arcade modes get this harness instead.
##   timeout 300 godot --headless --path . --fixed-fps 30 -- \
##     --scene=res://story/tests/arcade_chute_check.tscn --fresh --policy=careful --speed=4 --seed=1
## Policies (--policy=):
##   careful  the beat's solver, after a short reading pause: every chart right, high-score board
##   keys     real key presses: 1-4 for the right chute, letters and Enter for the initials
##   mouse    real clicks only: the chute, the initials' + button and OK, "Back to the arcade"
##   guess    a random open chute every time (real keys): far fewer points, never on the board
##   help     HOOT HELP every time (the H key): no points, no slips, no board
##   slip     real keys; on each two-ear card, first the OTHER ear's shape (a JAM with the
##            "Other ear!" cue, shot chute_jam_tell), then the right one when it comes back
## --via-title: start on the title, open the arcade from its Arcade button and pick the Chart Chute
## cabinet in the hall (a click with --policy=mouse, Down arrows, Enter and key 1 otherwise), as a
## player would.
## --belt=types: play AIR & BONE (air_bone.tscn, the hall's third cabinet) instead; --belt=tymps
## plays TYMP TOSS (tymp_toss.tscn, the fourth), --belt=degrees DEGREE DROP (the fifth), --belt=flats
## FLAT OUT (the sixth), --belt=otos OTO SPOT (the seventh). None has two-ear cards, so the slip bot slips
## each left-ear card once (first a wrong open chute) and no story chart ever rides them.
## --days-done: mark every Day finished first, so story charts can ride the belt (a careful run
## then has to sort one); without it no story chart may appear.
## The results are left with a click on "Back to the arcade" (mouse) or the T key (keys); the arcade
## hall must come up.
## Exit codes: 0 every check passed, 1 a check failed, 2 stalled, 3 overall timeout,
## 5 script errors were logged, 6 a mouse target was not found.

const CHUTE_SCENE := "res://story/arcade/chart_chute.tscn"
const TYPES_SCENE := "res://story/arcade/air_bone.tscn"
const TYMPS_SCENE := "res://story/arcade/tymp_toss.tscn"
## Per belt: the scene, the save key and the hall cabinet's key.
const BELT_RUNS: Dictionary = {
	"shapes": {"scene": CHUTE_SCENE, "mode": "chart_chute", "key": KEY_1},
	"types": {"scene": TYPES_SCENE, "mode": "chart_chute_types", "key": KEY_3},
	"tymps": {"scene": TYMPS_SCENE, "mode": "chart_chute_tymps", "key": KEY_4},
	"degrees": {"scene": "res://story/arcade/degree_drop.tscn", "mode": "chart_chute_degrees", "key": KEY_5},
	"flats": {"scene": "res://story/arcade/flat_out.tscn", "mode": "chart_chute_flats", "key": KEY_6},
	"otos": {"scene": "res://story/arcade/oto_spot.tscn", "mode": "chart_chute_otos", "key": KEY_7},
}
const TITLE_SCENE := "res://story/title_screen.tscn"
const HALL_SCENE := "res://story/arcade/arcade_hall.tscn"
const ChartDeck := preload("res://story/arcade/chart_deck.gd")


func demo_start() -> void:
	pass  # the driver below starts in _ready


func _ready() -> void:
	if Game.cli_flag("days-done"):
		Game.progress["chapters_done"] = Game.CHAPTERS.map(func(c: Dictionary) -> String: return String(c["id"]))
	var d := Driver.new()
	d.name = "ArcadeChuteDriver"
	get_tree().root.add_child.call_deferred(d)
	var scene: String = BELT_RUNS[Game.cli_value("belt", "shapes")]["scene"]
	Events.goto_scene.emit.call_deferred(TITLE_SCENE if Game.cli_flag("via-title") else scene)


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
	const READ_S := 0.35        ## game seconds the bot "reads" a chart before it acts
	const STALL_S := 30.0
	const MAX_S := 400.0

	var policy := "careful"
	var belt: StringName = &"shapes"
	var scene := CHUTE_SCENE
	var mode := "chart_chute"
	var ids: Array = ChartDeck.SHAPES
	var errors := ErrorCounter.new()
	var misses: PackedStringArray = []
	var beats := {}
	var chute: Node
	var at_hall := false
	var _rng := RandomNumberGenerator.new()
	var _last := 0.0
	var _clock := 0.0
	var _done := false
	var _mouse_pos := Vector2(640, 360)
	var _slipped := {}   # card serials the slip bot already jammed

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		OS.add_logger(errors)
		policy = Game.cli_value("policy", "careful")
		belt = StringName(Game.cli_value("belt", "shapes"))
		scene = BELT_RUNS[String(belt)]["scene"]
		mode = BELT_RUNS[String(belt)]["mode"]
		ids = ChartDeck.BELTS[belt]
		_rng.seed = int(Game.cli.get("seed", 1))
		Events.awaiting_input.connect(_on_awaiting)
		Events.scene_changed.connect(func(path: String, node: Node) -> void:
			_last = _clock
			if path == scene:
				chute = node
			elif path == HALL_SCENE:
				at_hall = true)
		print("ArcadeChuteCheck: policy %s, belt %s, speed x%s, seed %d" % [policy, belt, str(Engine.time_scale), _rng.seed])

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

	func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
		_last = _clock
		beats[String(beat)] = int(beats.get(String(beat), 0)) + 1
		match beat:
			&"chute_sort":
				await _wait(READ_S)
				await _sort(info, solver)
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
				if chute != null:
					return   # back at the hall after the results: the run is over
				await _wait(0.6)
				Events.screenshot_requested.emit("arcade_hall")
				await _wait(0.2)
				if policy == "mouse":
					await _click(_anchor("arcade_cabinet_" + mode))
				else:
					await _key(BELT_RUNS[String(belt)]["key"])
				for i in 90:
					if is_instance_valid(chute):
						return
					await _frames(1)
				_finish(1, "the hall's %s cabinet never opened it" % mode)

	## The title's Arcade button, like a player: a click, or Down until it is highlighted and Enter.
	func _open_arcade() -> void:
		if policy == "mouse":
			if _find_text("Arcade") == null:
				_finish(6, "the title has no Arcade button")
				return
			await _click_text("Arcade")
		else:
			var lit := false
			for i in 10:
				if _find_text("> Arcade") != null:
					lit = true
					break
				await _action(&"ui_down")
			if not lit:
				_finish(1, "Down never highlighted the title's Arcade button")
				return
			await _wait(0.4)
			Events.screenshot_requested.emit("title_arcade")
			await _wait(0.2)
			await _action(&"ui_accept")
		for i in 90:
			if at_hall:
				return
			await _frames(1)
		_finish(1, "the title's Arcade button never opened the arcade hall")

	func _action(a: StringName) -> void:
		for pressed: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = a
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await _frames(2)

	func _sort(info: Dictionary, solver: Callable) -> void:
		var shape: StringName = info["shape"]
		match policy:
			"careful":
				solver.call()
			"keys":
				await _key(KEY_1 + ids.find(shape))
			"mouse":
				await _click(_anchor(String((info["mouse"] as Dictionary)["click"])))
			"guess":
				var words: Array = info["options"]
				var w: String = words[_rng.randi() % words.size()]
				await _key(KEY_1 + ids.find(_id_of(w, ids)))
			"help":
				await _key(KEY_H)
			"slip":
				var card: Dictionary = chute.get("_card") if is_instance_valid(chute) else {}
				var other: StringName = card.get("other_shape", &"")
				var serial := int(card.get("serial", -1))
				if belt != &"shapes" and String(card.get("ear", "")) == "left":
					var wrong: Array = (info["options"] as Array).filter(func(w: String) -> bool: return w != ChartDeck.CHUTE_WORDS[shape])
					other = _id_of(wrong[0], ids) if not wrong.is_empty() else &""
					if other != &"" and not _slipped.has(serial):
						var was := int(chute.get("_oops"))
						await _key(KEY_1 + ids.find(other))
						await _frames(2)
						if String(chute.get("_phase")) == "run" or int(chute.get("_oops")) > was:
							_slipped[serial] = true
					else:
						await _key(KEY_1 + ids.find(shape))
				elif String(card.get("ear", "")) == "both" and other != &"" and not _slipped.has(serial) and (info["options"] as Array).has(ChartDeck.CHUTE_WORDS[other]):
					var before := int(chute.get("_oops"))
					await _key(KEY_1 + ids.find(other))
					await _frames(2)
					# a slip counts as planned unless the clock ran out under the key
					if String(chute.get("_phase")) == "run" or int(chute.get("_oops")) > before:
						_slipped[serial] = true
				else:
					await _key(KEY_1 + ids.find(shape))

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
		var st: Dictionary = chute.call("stats") if is_instance_valid(chute) else {}
		var table := ArcadeScoresRef.table(mode)
		var problems: PackedStringArray = []
		var right := int(st.get("right", 0))
		var oops := int(st.get("oops", 0))
		var helps := int(st.get("helps", 0))
		var on_board := int(beats.get("arcade_initials", 0)) > 0
		match policy:
			"careful", "keys", "mouse":
				if oops != 0:
					problems.append("a reading bot made %d slips" % oops)
				if right < 20:
					problems.append("only %d right in a minute" % right)
				if not on_board:
					problems.append("a perfect run never reached the initials")
			"guess":
				if float(st.get("accuracy", 1.0)) > 0.7:
					problems.append("guessing was %.0f%% accurate" % (float(st.get("accuracy", 0.0)) * 100.0))
				if on_board:
					problems.append("a guessing run reached the high-score board")
			"slip":
				if oops == 0:
					problems.append("the slip bot never jammed a card")
				if oops != _slipped.size():
					problems.append("%d slips for %d planned (a key landed on the wrong chart?)" % [oops, _slipped.size()])
			"help":
				if right != 0 or oops != 0 or int(st.get("score", -1)) != 0:
					problems.append("HOOT HELP scored or slipped (%d right, %d oops)" % [right, oops])
				if helps < 10:
					problems.append("only %d helps" % helps)
				if on_board:
					problems.append("an all-help run reached the board")
		if policy == "keys" and on_board and not table.any(func(r: Dictionary) -> bool: return r["initials"] == "KEY"):
			problems.append("typed initials KEY are not on the board")
		if policy == "mouse" and on_board and not table.any(func(r: Dictionary) -> bool: return r["initials"] == "BAA"):
			problems.append("clicked initials BAA are not on the board")
		var golden := String(st.get("golden", ""))
		if belt != &"shapes":
			if golden != "":
				problems.append("story chart %s rode the %s belt" % [golden, belt])
			if not st.has("right"):
				problems.append("no stats")
		elif Game.cli_flag("days-done"):
			if policy == "careful" and golden == "":
				problems.append("every Day was done, but no story chart was sorted")
		elif golden != "":
			problems.append("story chart %s rode the belt before its Day was finished" % golden)
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
				problems.append("%s did not reach the arcade hall" % ("Back to the arcade" if policy == "mouse" else "The T key"))
		var code := 0
		if not problems.is_empty():
			code = 1
		if errors.count > 0:
			code = 5
		elif not misses.is_empty():
			code = 6
		print("ARCADE_RESULT " + JSON.stringify({"policy": policy, "stats": st, "beats": beats, "problems": problems,
			"errors": errors.count, "error_messages": errors.messages, "misses": misses, "board": table.slice(0, 5)}))
		_finish(code, "; ".join(problems))

	func _finish(code: int, why: String) -> void:
		if _done:
			return
		_done = true
		if code != 0:
			print("ARCADE_CHECK FAIL (%d): %s" % [code, why])
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


	## The chute on this belt with word w (two belts may share a word: FLAT OUT's and OTO SPOT's WAX).
	static func _id_of(w: String, ids: Array) -> StringName:
		for id: StringName in ids:
			if ChartDeck.CHUTE_WORDS[id] == w:
				return id
		return &""


## The high-score table, read the way the results card reads it.
class ArcadeScoresRef:
	const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")

	static func table(mode: String) -> Array[Dictionary]:
		return ArcadeScores.table(mode)

