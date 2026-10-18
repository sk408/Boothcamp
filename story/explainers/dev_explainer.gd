extends Node
## Dev scene for Hoot's movies (developer tool, never reachable from the game): plays one movie over
## a plain background and takes a screenshot in every scene, so builders can LOOK at each beat.
##   tools/scene_shot.sh res://story/explainers/dev_explainer.tscn /abs/dir "1" 200
## Options after --: --movie=<id> (default masking), --at=0.65 (the moment of each scene to shoot,
## as a share of the scene's duration), --menu (then shoot the Day 2 pause menu with its movie
## button: explainer_pause_menu). Add --speed=2 to halve the wait.

const PLAYER := "res://story/explainers/explainer_player.tscn"


func demo_start() -> void:
	var id := Game.cli_value("movie", "masking")
	var at := float(Game.cli_value("at", "0.65"))
	var bg := ColorRect.new()
	bg.color = Palette.WALL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.add_child(bg)
	add_child(layer)
	var p: CanvasLayer = (load(PLAYER) as PackedScene).instantiate()
	add_child(p)
	Events.explainer_scene.connect(func(mid: String, i: int, sid: String) -> void:
		var scenes: Array = p.get("movie").get("scenes", [])
		var dur := float((scenes[i] as Dictionary).get("duration", 4.0)) if i < scenes.size() else 4.0
		await get_tree().create_timer(dur * at, false).timeout
		if int(p.get("scene_index")) == i:
			Events.screenshot_requested.emit("explainer_%s_%02d_%s" % [mid, i + 1, sid]))
	var r: Dictionary = await p.call("play", id, "dev")
	print("EXPLAINER_RESULT ", JSON.stringify(r))
	await get_tree().create_timer(0.5, false).timeout
	if Game.cli_flag("menu"):
		# --menu: the pause menu as Day 2 shows it, with the "Watch Hoot's masking movie" button
		Game.current_chapter_id = "bonnie"
		var menu := get_tree().get_first_node_in_group("pause_menu")
		if menu != null:
			menu.call("open")
			await get_tree().create_timer(0.8, true).timeout
			Events.screenshot_requested.emit("explainer_pause_menu")
			await get_tree().create_timer(0.5, true).timeout
			menu.call("close")
	Events.quit_requested.emit(0)
