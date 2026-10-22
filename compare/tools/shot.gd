extends SceneTree
## Renders the page and saves screenshots. Run under xvfb:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 -s res://tools/shot.gd -- --out=/abs/dir
## Extras: --scroll=px (page scroll), --detail (Full specs), --needs=iphone,telecoil, --open=viewer:<aid> (--style=<button text>)|cell:<aid>:<row>|quiz

var out := "/tmp"
var args := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	out = args.get("out", out)
	DirAccess.make_dir_recursive_absolute(out)
	var main: Control = load("res://main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)
	if args.has("detail"):
		main._set_mode(true)
	if args.has("needs"):
		main._set_needs(Array(args.needs.split(",")))
	await _frames(10)
	if args.has("scroll"):
		main._scroll.scroll_vertical = int(args.scroll)
	var open: String = args.get("open", "")
	if open.begins_with("viewer:"):
		main._open_viewer(open.split(":")[1])
		if args.has("style"):
			await _frames(2)
			# Press the style's button in the viewer, like a click.
			for b in main._overlay.find_children("*", "Button", true, false):
				if b.text.contains(args.style):
					b.emit_signal("pressed")
	elif open.begins_with("cell:"):
		var p := open.split(":")
		main._open_detail(p[1], p[2])
	elif open == "quiz":
		main._open_quiz()
	await _frames(40)
	var img := root.get_texture().get_image()
	var name: String = args.get("name", "page")
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", out.path_join(name + ".png"))
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame
