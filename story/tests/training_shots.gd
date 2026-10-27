extends Node
## TrainingShots (training, dev only; story/tests is never exported): screenshots of Masking School's
## extras on a made-up save with every card and the exam done (grade A): the Training room with its
## diploma, the print view (and its "Save picture" PNG), and the AudiOtron's OE chip with the pocket card
## open on Bonnie's bone test. Prints TRAINING_SHOTS {saved, chip} and quits.
##   timeout 300 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/tests/training_shots.tscn --fresh --shots=/abs/dir

const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"


func demo_start() -> void:
	pass


func _ready() -> void:
	var stations := {}
	for id: String in MaskDeck.station_ids():
		stations[id] = {"best": 2 if id == "exam" else 0, "star": id != "exam", "plays": 1}
	Game.progress["training"] = {"masking": {"stations": stations, "cards": Array(MaskDeck.CARD_ORDER)}}
	var d := Driver.new()   # the scene change frees this node: the driver lives on the root
	d.name = "TrainingShotsDriver"
	get_tree().root.add_child.call_deferred(d)


class Driver extends Node:
	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS
		_run()


	func _wait(s: float) -> void:
		await get_tree().create_timer(s).timeout


	func _shot(n: String) -> void:
		Events.screenshot_requested.emit(n)
		await _wait(0.4)


	func _run() -> void:
		var out := {}
		Events.goto_scene.emit("res://story/training/training_room.tscn")
		await _wait(1.2)
		await _shot("room_diploma")
		var room := get_tree().get_first_node_in_group("training_room")
		room.call("open_print")
		await _wait(0.8)
		await _shot("print_view")
		var pv := get_tree().get_first_node_in_group("print_view")
		await pv.call("save_picture")
		await _wait(0.3)
		out["saved"] = String(pv.get("saved_to"))
		out["saved_exists"] = FileAccess.file_exists(out["saved"])
		await _shot("print_view_saved")
		pv.call("close_view")
		room.queue_free()
		var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
		get_tree().root.add_child(screen)
		await _wait(0.3)
		screen.call("start_test", Game.load_patient("bonnie"), "right", false, {"test": "bc_masked", "hoot_turn_after": 99})
		await _wait(1.0)
		var chip: Control = screen.find_child("oe_chip", true, false)
		out["chip"] = chip != null and chip.visible
		await _shot("audiotron_oe_chip")
		if chip != null:
			chip.call("open_card")
		await _wait(0.5)
		await _shot("audiotron_oe_card")
		print("TRAINING_SHOTS " + JSON.stringify(out))
		get_tree().quit(0)
