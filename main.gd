extends Node
## Main: app root and scene router (owned by foundation/integrator; CONTRACTS.md §3).
##  - Boots the entry scene (story title), or --scene=res://... for direct testing.
##  - Swaps top-level scenes on Events.goto_scene with a short fade.
##  - Hosts the always-on overlays: Hoot bubble and pause menu (story-owned scenes).
##  - Attaches the autoplay bot (--autoplay) and the screenshot service (--shots=DIR).

const ENTRY_SCENE := "res://story/title_screen.tscn"
const OVERLAY_SCENES: PackedStringArray = ["res://story/hoot_bubble.tscn", "res://story/pause_menu.tscn"]
const BOT_SCRIPT := "res://tools/autoplay_bot.gd"
const SHOTS_SCRIPT := "res://tools/screenshot_service.gd"

var current: Node
var current_path: String = ""
var _host: Node
var _fade: ColorRect
var _switching := false


func _ready() -> void:
	get_window().title = "Booth Camp"
	get_tree().auto_accept_quit = false  # the window's close button goes through _on_quit (save, silence)
	_host = Node.new()
	_host.name = "SceneHost"
	add_child(_host)
	for p: String in OVERLAY_SCENES:
		if ResourceLoader.exists(p):
			add_child((load(p) as PackedScene).instantiate())
	var fade_layer := CanvasLayer.new()
	fade_layer.layer = 120
	add_child(fade_layer)
	_fade = ColorRect.new()
	_fade.color = Palette.INK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	fade_layer.add_child(_fade)
	Events.goto_scene.connect(goto)
	Events.quit_requested.connect(_on_quit)
	if Game.cli.has("shots") or Game.is_autoplay() or Game.cli.has("quit-at"):
		var shots: Node = (load(SHOTS_SCRIPT) as GDScript).new()
		shots.name = "ScreenshotService"
		add_child(shots)
	if Game.is_autoplay():
		var bot: Node = (load(BOT_SCRIPT) as GDScript).new()
		bot.name = "AutoplayBot"
		add_child(bot)
	var first := Game.cli_value("scene", ENTRY_SCENE)
	goto(first, false)


## Replace the top-level scene. Scenes booted with --scene may implement demo_start().
func goto(path: String, fade: bool = true) -> void:
	if _switching:
		push_warning("Main.goto: already switching, ignoring " + path)
		return
	if not ResourceLoader.exists(path):
		push_error("Main.goto: no such scene " + path)
		return
	_switching = true
	if fade and current != null:
		var t := create_tween()
		t.tween_property(_fade, "modulate:a", 1.0, 0.25)
		await t.finished
	if current != null:
		current.queue_free()
		await current.tree_exited
	get_tree().paused = false
	Hoot.clear()
	var node: Node = (load(path) as PackedScene).instantiate()
	current = node
	current_path = path
	_host.add_child(node)
	Events.scene_changed.emit(path, node)
	if path == Game.cli_value("scene", "") and node.has_method("demo_start"):
		node.call_deferred("demo_start")
	if fade:
		var t2 := create_tween()
		t2.tween_property(_fade, "modulate:a", 0.0, 0.3)
	else:
		_fade.modulate.a = 0.0
	_switching = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_on_quit(0)


var _quitting := false


func _on_quit(code: int) -> void:
	if _quitting:
		return
	_quitting = true
	Engine.time_scale = 1.0
	Game.save_game()
	Sfx.stop_all()
	for n: Node in get_tree().root.find_children("*", "AudioStreamPlayer", true, false):
		(n as AudioStreamPlayer).stop()
	# two frames for the audio driver to drain silence (no click or stuck tone on exit)
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(code)
