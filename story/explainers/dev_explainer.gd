extends Node
## Dev scene for Hoot's movies (developer tool, never reachable from the game): plays one movie over
## a plain background and takes a screenshot in every scene, so builders can LOOK at each beat.
##   tools/scene_shot.sh res://story/explainers/dev_explainer.tscn /abs/dir "1" 200
## Options after --: --movie=<id> (default masking), --at=0.65 (the moment of each scene to shoot,
## as a share of the scene's duration; several: --at=0.2,0.5,0.9), --times=1.2,3.4 (shoot at these
## seconds of every scene instead), --from=<scene id or number> (start there), --only (stop after
## the first scene played), --menu (then the Day 2 pause menu: shoot it with its movie button
## (explainer_pause_menu), CLICK "Watch Hoot's masking movie" (a real mouse click), shoot the replay
## playing under the paused game (explainer_pause_replay), Space = next scene, Esc = skip, and shoot
## the menu back (explainer_pause_back); prints EXPLAINER_MENU {...}), --title (only the title's
## "Hoot's Movies" button: shoot it, click it, shoot the replay over the title, Esc, shoot the title
## back; prints EXPLAINER_TITLE {...}), --card-demo (only the generic "card" set with made-up data,
## each icon, and the fallback for an unknown set: explainer_card_*), --reduced-motion (the setting
## on, for this run only), --extra-movie=res://path/movie.gd[,...] (register more movie files for
## this run, e.g. res://tests/fixtures/fake_movie.gd with its own sets script; then --movie=<its id>),
## --list (only the "Hoot's Movies" list with five made-up movies: shoot it (explainer_movie_list),
## Down x4 (explainer_movie_list_down, scrolled), Enter plays the fifth, Esc, the list back
## (explainer_movie_list_back); prints EXPLAINER_LIST {...}).
## Add --speed=2 to halve the wait.
## The first shot of a scene is named explainer_<id>_<NN>_<scene> (CONTRACTS.md §7.3); extra ones
## add _t<seconds>.

const PLAYER := "res://story/explainers/explainer_player.tscn"
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const Movies := preload("res://story/explainers/movies.gd")


func demo_start() -> void:
	for path: String in Game.cli_value("extra-movie", "").split(",", false):
		var sc := load(path) as Script
		var m: Variant = sc.get_script_constant_map().get("MOVIE", {}) if sc != null else {}
		if m is Dictionary and (m as Dictionary).has("id"):
			Movies.extra[String((m as Dictionary)["id"])] = path
		else:
			push_warning("dev_explainer: --extra-movie=%s is not a movie file" % path)
	if Game.cli_flag("list"):
		await _list_path()
		Events.quit_requested.emit(0)
		return
	if Game.cli_flag("title"):
		await _title_path()
		Events.quit_requested.emit(0)
		return
	if Game.cli_flag("card-demo"):
		await _card_demo()
		Events.quit_requested.emit(0)
		return
	if Game.cli_flag("reduced-motion"):
		Game.save_path = "user://save_dev_reduced_motion.json"   # never leaks into other dev runs' save
		Game.settings["reduced_motion"] = true
	var id := Game.cli_value("movie", "masking")
	var ats: Array[float] = []
	for a: String in Game.cli_value("at", "0.65").split(",", false):
		ats.append(float(a))
	var times: Array[float] = []
	for a: String in Game.cli_value("times", "").split(",", false):
		times.append(float(a))
	var bg := ColorRect.new()
	bg.color = Palette.WALL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.add_child(bg)
	add_child(layer)
	var p: CanvasLayer = (load(PLAYER) as PackedScene).instantiate()
	add_child(p)
	var scenes: Array = Movies.movie(id).get("scenes", [])
	var from := Game.cli_value("from", "")
	if from != "":
		var idx := int(from) - 1 if from.is_valid_int() else -1
		for i in scenes.size():
			if String((scenes[i] as Dictionary).get("id", "")) == from:
				idx = i
		p.set("start_scene", maxi(0, idx))
	var only := Game.cli_flag("only")
	var first := [-1]
	var on_scene := func(mid: String, i: int, sid: String) -> void:
		if first[0] < 0:
			first[0] = i
		elif only:
			p.call("skip_all")
			return
		var dur := float((scenes[i] as Dictionary).get("duration", 4.0)) if i < scenes.size() else 4.0
		var marks: Array[float] = []
		marks.assign(times)
		if marks.is_empty():
			for a in ats:
				marks.append(dur * a)
		var prev := 0.0
		for j in marks.size():
			await get_tree().create_timer(maxf(0.0, marks[j] - prev), false).timeout
			prev = marks[j]
			if not is_instance_valid(p) or int(p.get("scene_index")) != i or not bool(p.call("is_playing")):
				return
			var shot := "explainer_%s_%02d_%s" % [mid, i + 1, sid]
			if j > 0 or not times.is_empty():
				shot += "_t%04.1f" % marks[j]
			Events.screenshot_requested.emit(shot)
	Events.explainer_scene.connect(on_scene)
	var r: Dictionary = await p.call("play", id, "dev")
	Events.explainer_scene.disconnect(on_scene)
	print("EXPLAINER_RESULT ", JSON.stringify(r))
	p.queue_free()
	await get_tree().create_timer(0.5, false).timeout
	if Game.cli_flag("menu"):
		# --menu: the pause menu as Day 2 shows it, with the "Watch Hoot's masking movie" button
		Game.current_chapter_id = "bonnie"
		var menu := get_tree().get_first_node_in_group("pause_menu")
		if menu != null:
			await _menu_path(menu)
	Events.quit_requested.emit(0)


## --menu: the Day 2 pause menu's "Watch" button, by real mouse clicks and keys, under the paused game.
func _menu_path(menu: Node) -> void:
	var out := {"button": false, "started": "", "played_paused": false, "space_next": false, "skipped": false, "menu_back": false}
	menu.call("open")
	await _wait(0.8)
	Events.screenshot_requested.emit("explainer_pause_menu")
	await _wait(0.4)
	var b := _find_button(get_tree().root, "Watch ")
	out["button"] = b != null
	var started := [""]
	var on_start := func(_id: String, src: String) -> void: started[0] = src
	Events.explainer_started.connect(on_start)
	if b != null:
		await _click(b.get_global_rect().get_center())
	await _wait(2.4)
	var p := get_tree().get_first_node_in_group("explainer_player")
	out["started"] = started[0]
	out["played_paused"] = p != null and get_tree().paused and bool(p.call("is_playing")) and float(p.get("_age")) > 1.5
	Events.screenshot_requested.emit("explainer_pause_replay")
	await _wait(0.4)
	if p != null:
		# Space advances like dialogue: finish the caption, else the next one, else the next scene
		for i in 3:
			if int(p.get("scene_index")) >= 1:
				break
			await _tap(&"advance_dialogue")
			await _wait(0.3)
		out["space_next"] = int(p.get("scene_index")) == 1
		var done := [false]
		var on_done := func(_id: String, skipped: bool) -> void: done[0] = skipped
		Events.explainer_finished.connect(on_done)
		await _tap(&"ui_cancel")
		await _wait(0.3)
		Events.explainer_finished.disconnect(on_done)
		out["skipped"] = done[0]
	await _wait(0.8)
	out["menu_back"] = bool(menu.call("is_open")) and get_tree().paused and get_tree().get_first_node_in_group("explainer_player") == null
	Events.screenshot_requested.emit("explainer_pause_back")
	await _wait(0.4)
	Events.explainer_started.disconnect(on_start)
	menu.call("close")
	print("EXPLAINER_MENU ", JSON.stringify(out))


## --title: the title's "Hoot's Movies" button (mouse), the movie over the title, Esc, the title back.
func _title_path() -> void:
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_child(title)
	await _wait(0.5)
	title.call("_on_notice_ok")
	await _wait(1.2)
	Events.screenshot_requested.emit("explainer_title_button")
	await _wait(0.3)
	var out := {"button": false, "started": "", "playing": false, "skipped": false, "title_back": false}
	var b := _find_button(title, "Hoot's Movies")
	out["button"] = b != null and b.is_visible_in_tree()
	var started := [""]
	var finished := [false]
	var on_start := func(_id: String, src: String) -> void: started[0] = src
	var on_done := func(_id: String, skipped: bool) -> void: finished[0] = skipped
	Events.explainer_started.connect(on_start)
	Events.explainer_finished.connect(on_done)
	if b != null:
		await _click(b.get_global_rect().get_center())
	await _wait(3.0)
	var p := get_tree().get_first_node_in_group("explainer_player")
	out["started"] = started[0]
	out["playing"] = p != null and bool(p.call("is_playing")) and get_tree().paused
	Events.screenshot_requested.emit("explainer_title_replay")
	await _wait(0.4)
	await _tap(&"ui_cancel")
	await _wait(1.0)
	var pm := get_tree().get_first_node_in_group("pause_menu")
	out["skipped"] = finished[0]
	out["title_back"] = not get_tree().paused and pm != null and not bool(pm.call("is_open")) and b != null and b.is_visible_in_tree()
	Events.screenshot_requested.emit("explainer_title_back")
	await _wait(0.4)
	Events.explainer_started.disconnect(on_start)
	Events.explainer_finished.disconnect(on_done)
	print("EXPLAINER_TITLE ", JSON.stringify(out))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true).timeout   # runs under the paused tree too


func _find_button(root: Node, prefix: String) -> Button:
	for c in root.get_children():
		var f := _find_button(c, prefix)
		if f != null:
			return f
	if root is Button and (root as Button).is_visible_in_tree() and (root as Button).text.begins_with(prefix):
		return root as Button
	return null


func _click(at: Vector2) -> void:
	var mv := InputEventMouseMotion.new()
	mv.position = at
	mv.global_position = at
	Input.parse_input_event(mv)
	await _wait(0.1)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		Input.parse_input_event(ev)
		await _wait(0.1)


func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(0.1)


## --card-demo: the generic "card" set (data only) at a few moments, every icon, and an unknown set.
func _card_demo() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#2a2140")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var stage: Control = Stage2D.new()
	stage.position = Vector2(200, 64)
	stage.size = Vector2(880, 440)
	add_child(stage)
	var lines := ["Speech uses WORDS, not beeps", "Find the softest words heard", "It should match the beeps"]
	var shots := [
		["", 0.3], ["", 1.6], ["", 4.5], ["snails", 4.5], ["ghost", 4.5], ["cloud", 4.5], ["note", 4.5], ["dial", 4.5], ["hoot", 4.5],
	]
	for sh: Array in shots:
		var icon := String(sh[0])
		stage.call("show_scene", {"id": "demo", "set": "card", "title": "A card scene", "duration": 6.0,
			"params": {"heading": "Speech check", "lines": lines, "icon": icon, "tint": "#fff4dc" if icon == "" else ""}})
		stage.set("scene_no", 3)
		stage.set("t", float(sh[1]))
		await _wait(0.15)
		Events.screenshot_requested.emit("explainer_card_%s_t%.1f" % [icon if icon != "" else "plain", float(sh[1])])
		await _wait(0.25)
	stage.call("show_scene", {"id": "demo", "set": "nope", "title": "Unknown set", "duration": 4.0, "params": {}})
	stage.set("t", 2.0)
	await _wait(0.15)
	Events.screenshot_requested.emit("explainer_card_fallback")
	await _wait(0.25)


## --list: the pause menu's "Hoot's Movies" list as a later game will show it (five made-up movies
## on two days), by keys: Down x4 scrolls, Enter plays the fifth over the paused game, Esc skips it,
## the list comes back, Esc returns to the menu.
func _list_path() -> void:
	var base := Movies.movie("masking")
	var fakes := [["gus", "Hoot's air movie", "Beeps and snails"], ["gus", "Hoot's otoscope movie", "Look before you beep"],
		["bonnie", "Hoot's bone movie", "Good vibrations"], ["bonnie", "Hoot's plateau movie", "Flat is where it's at"],
		["bonnie", "Hoot's overmasking movie", "Too much shhh"]]
	for i in fakes.size():
		var m := base.duplicate(true)
		m["id"] = "fake_%d" % i
		m["chapter"] = fakes[i][0]
		m["title"] = fakes[i][1]
		m["subtitle"] = fakes[i][2]
		m.erase("seen_at")
		Movies.extra[String(m["id"])] = m
	Game.current_chapter_id = "bonnie"
	var out := {"rows": 0, "button": "", "fits": true, "down_hl": -1, "played": "", "back": false, "menu_back": false}
	var menu := get_tree().get_first_node_in_group("pause_menu")
	if menu == null:
		print("EXPLAINER_LIST ", JSON.stringify(out))
		return
	var bg := ColorRect.new()
	bg.color = Palette.WALL
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	menu.call("open")
	await _wait(0.6)
	var mb: Button = menu.call("movie_button")
	out["button"] = mb.text if mb != null else ""
	Events.screenshot_requested.emit("explainer_movie_list_menu")
	await _wait(0.3)
	if mb != null:
		await _click(mb.get_global_rect().get_center())
	await _wait(0.6)
	var rows: Array = menu.call("movie_list_rows")
	out["rows"] = rows.size()
	var vp := get_viewport().get_visible_rect()
	for r: Dictionary in rows:
		var rc := (r["row"] as Control).get_global_rect()
		out["fits"] = bool(out["fits"]) and rc.size.x <= vp.size.x and rc.position.x >= 0.0 and rc.end.x <= vp.end.x
	Events.screenshot_requested.emit("explainer_movie_list")
	await _wait(0.3)
	for i in 4:
		await _key(KEY_DOWN)
	await _wait(0.4)
	out["down_hl"] = int(menu.get("_list_hl"))
	Events.screenshot_requested.emit("explainer_movie_list_down")
	await _wait(0.3)
	var started := [""]
	var on_start := func(id: String, _src: String) -> void: started[0] = id
	Events.explainer_started.connect(on_start)
	await _key(KEY_ENTER)
	await _wait(1.5)
	out["played"] = started[0]
	Events.explainer_started.disconnect(on_start)
	await _tap(&"ui_cancel")
	await _wait(0.8)
	out["back"] = bool(menu.call("is_movie_list_open"))
	Events.screenshot_requested.emit("explainer_movie_list_back")
	await _wait(0.3)
	await _tap(&"ui_cancel")
	await _wait(0.5)
	out["menu_back"] = bool(menu.call("is_open")) and not bool(menu.call("is_movie_list_open"))
	menu.call("close")
	Movies.extra.clear()
	print("EXPLAINER_LIST ", JSON.stringify(out))


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _wait(0.1)
