extends TestCase
## Integrator checks: seams between modules that no single owner's tests cover.

const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const PAUSE_MENU := "res://story/pause_menu.tscn"


## Mouse-only players need the pause menu mid-test (the story hides its corner button there).
func test_audiotron_pause_button_opens_pause_menu() -> void:
	var menu: Node = add_node((load(PAUSE_MENU) as PackedScene).instantiate())
	var screen: Node = add_node((load(AUDIOMETER) as PackedScene).instantiate())
	await wait_frames(2)
	Game.begin_visit("gus")
	screen.call("start_test", Game.load_patient("gus"), "right", true)
	await wait_frames(2)
	var btn: Control = screen.find_child("pause_button", true, false) as Control
	assert_true(btn != null, "AudiOtron has a pause button")
	assert_true(btn.get_global_rect().size.x > 20.0, "pause button is laid out")
	assert_true((btn.call("face_rect") as Rect2).size.y >= 24.0, "pause button face is a real button, not a sliver")
	assert_false((menu.get("_corner") as Control).visible, "only one pause button: the story corner one hides under the AudiOtron")
	btn.emit_signal("clicked")
	await wait_frames(1)
	assert_true(bool(menu.call("is_open")), "clicking it opens the pause menu")
	assert_false(bool(screen.call("get_state")["tone_on"]), "no tone left playing under the menu")
	menu.call("close")
	await wait_frames(1)
	assert_false(tree.paused, "closing resumes")
	Hoot.clear()


## The results paper shows the real (dynamic) par range, not the old constant 7.
func test_results_par_caption_uses_dynamic_par() -> void:
	var paper: Node = (load("res://story/daily_decibel.gd") as GDScript).new()
	var res := {"ears": {
		"right": {"freqs": {1000: {"par": 9}, 2000: {"par": 11}}},
		"left": {"freqs": {1000: {"par": 8}}},
	}}
	var cap: String = paper.call("_par_caption", res)
	assert_true(cap.contains("8-11"), "caption names the par range (got '%s')" % cap)
	paper.free()


## A grabbed earphone cup is scaled up; dragging must still keep it under the cursor.
func test_earphone_cup_follows_the_mouse() -> void:
	var g: Control = (load("res://story/games/earphones.gd") as GDScript).new()
	add_node(g)
	await wait_frames(2)
	g.call("_layout")
	g.set("_accepting", true)
	var cup: Control = (g.get("_cups") as Dictionary)["right"]
	var start := cup.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = cup.size * 0.5
	g.call("_on_cup_input", press, "right")
	assert_near(cup.scale.x, 1.12, 0.01, "grabbed cup pops up")
	var move := InputEventMouseMotion.new()
	move.relative = Vector2(-200, -300) / cup.scale.x   # gui_input delivers relative in the cup's local space
	g.call("_on_cup_input", move, "right")
	var moved := cup.get_global_rect().get_center() - start
	assert_near(moved.x, -200.0, 1.0, "cup tracks the cursor horizontally")
	assert_near(moved.y, -300.0, 1.0, "cup tracks the cursor vertically")
	Hoot.clear()
