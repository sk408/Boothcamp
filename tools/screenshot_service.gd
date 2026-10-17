extends Node
## ScreenshotService: saves PNGs of the game window on request (added by main.gd when the
## game runs with -- --shots=/abs/dir or --autoplay). Anyone can ask for a shot with
## Events.screenshot_requested.emit("name"); the bot uses take() directly.
## Does nothing in --headless runs (no framebuffer).
## Timed shots for iterating on one scene:  --shot-at=1.5,4  (game seconds)  --quit-at=5

var dir := ""
var enabled := false
var count := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	dir = Game.cli_value("shots", "")
	if dir != "" and dir.is_relative_path():
		dir = OS.get_environment("PWD").path_join(dir)
	enabled = dir != "" and DisplayServer.get_name() != "headless"
	if enabled:
		DirAccess.make_dir_recursive_absolute(dir)
		print("ScreenshotService: saving to ", dir)
	Events.screenshot_requested.connect(func(n: String) -> void: take(n))
	for t: String in Game.cli_value("shot-at", "").split(",", false):
		_timed_shot(float(t))
	var quit_at := float(Game.cli_value("quit-at", "0"))
	if quit_at > 0.0:
		await get_tree().create_timer(quit_at).timeout
		get_tree().quit(0)


func _timed_shot(at_s: float) -> void:
	await get_tree().create_timer(at_s).timeout
	await take("t%05.1f" % at_s)


## (coroutine) Capture the next drawn frame. Returns the file path, or "" when disabled.
func take(shot_name: String) -> String:
	if not enabled:
		return ""
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		return ""
	count += 1
	var path := dir.path_join("%02d_%s.png" % [count, shot_name.validate_filename()])
	var err := img.save_png(path)
	print("SHOT ", path, " ", error_string(err))
	return path
