extends Node
## Dev gallery for the title's day picker (developer tool, never part of the game and left out of
## the export): the scrolling Days grid with 11 MADE-UP days (fake ids, never shipped), so the
## layout can be checked before the speech and case chapters land. Shots: the top of the grid,
## the keyboard walk to the last card (scrolled), the mouse wheel back up, then the real 2 days.
##   tools/scene_shot.sh res://story/dev_days.tscn /abs/dir "30" 30
## Full HD: the same command line with --resolution 1920x1080 before "--" and a 1920x1080 xvfb screen.

const FACES := ["Gus", "Bonnie", "Hoot", "Doris", "You", ""]
const TINTS: Array = [Color("#cfe3ff"), "#ffd9c7", null, "#f3e1ff", Color("#e3f5d0"), null]

var _title: Control
var _keep_progress: Dictionary


func demo_start() -> void:
	_keep_progress = Game.progress.duplicate(true)
	Game.progress["chapters_done"] = ["fake1", "fake2", "fake4"]
	Game.progress["patients"] = {
		"fake1": {"best_score": 97.0, "best_grade": "S", "last_grade": "S", "plays": 3},
		"fake2": {"best_score": 84.0, "best_grade": "A", "last_grade": "B", "plays": 2},
		"fake4": {"best_score": 71.0, "best_grade": "B", "last_grade": "B", "plays": 1},
	}
	var fake: Array = []
	var names := ["Grandpa Gus", "Bonnie Bunsworth", "Speech Day One", "Speech Day Two", "Speech in Noise",
		"Rocco Rimshot", "Captain Marina Gale", "Dash Delgado", "Ginger Snapp", "A Very Long Patient Name Indeed", "Mystery Guest"]
	var teaches := ["Air conduction", "Bone conduction + masking", "Speech threshold", "Word recognition",
		"Speech in noise", "Case file: ringing ears", "Case file: the ferry captain", "Case file: the pizza rush",
		"Case file: the ventriloquist", "A lesson with a rather long description", "Surprise!"]
	for i in 11:
		var ch := {"id": "fake%d" % (i + 1), "day": i + 1, "title": "Day %d: %s" % [i + 1, names[i]],
			"patient_id": "fake%d" % (i + 1), "teaches": teaches[i], "scene": "res://nope.tscn",
			"requires": "" if i == 0 else "fake%d" % i, "face": FACES[i % FACES.size()]}
		if TINTS[i % TINTS.size()] != null:
			ch["tint"] = TINTS[i % TINTS.size()]
		fake.append(ch)
	_title = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	_title.set("chapters_override", fake)
	add_child(_title)
	await _wait(0.6)
	_title.call("_on_notice_ok")
	await _wait(0.8)
	_title.call("_on_days")
	await _wait(0.9)
	await _shot("dev_days_grid_top")
	# the keyboard walk: Right, then Down to the last row (the grid scrolls with the highlight)
	_tap(&"ui_right")
	await _wait(0.3)
	for i in 2:
		_tap(&"ui_down")
		await _wait(0.35)
	await _wait(0.4)
	await _shot("dev_days_grid_scrolled")
	_tap(&"ui_down")
	await _wait(0.4)
	await _shot("dev_days_grid_back")
	# the mouse wheel over the grid scrolls back up
	var sc: ScrollContainer = _title.get("_days_scroll")
	var at := sc.get_global_rect().get_center()
	for i in 6:
		_wheel(at, false)
		await _wait(0.1)
	await _wait(0.3)
	await _shot("dev_days_grid_wheel_up")
	Game.progress = _keep_progress


func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)


func _wheel(at: Vector2, down: bool) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP
		ev.pressed = pressed
		ev.factor = 1.0
		get_viewport().push_input(ev)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
