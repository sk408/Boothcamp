extends SceneTree
## Renders the page and saves screenshots. Run under xvfb:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --path . --rendering-driver opengl3 -s res://tools/shot.gd -- --out=/abs/dir
## Extras: --scroll=px (page scroll), --detail (Full specs), --needs=iphone,telecoil, --dpr=3 (phone pixel ratio),
## --open=viewer:<aid> (--style=<button text>)|card:<aid>|quiz[:step]|results (--answers=0,1,0,0,1), --scroll-to=<anchor>

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
	elif open.begins_with("card:"):
		main._toggle_expand(open.split(":")[1])
		await _frames(4)
		if args.has("scroll"):
			main._scroll.scroll_vertical = int(args.scroll)
	elif open.begins_with("quiz"):
		var p := open.split(":")
		main._open_quiz(int(p[1]) if p.size() > 1 else 0)
	elif open == "results":
		var ans: Array = []
		for x: String in String(args.get("answers", "0,0,0,0,0")).split(","):
			ans.append(int(x))
		main.quiz_answers = ans
		main._apply_quiz()
		main._open_results()
	if args.has("scroll-to"):
		await _frames(4)
		main._scroll_to(args["scroll-to"])
	await _frames(40)
	if args.has("widest"):
		_widest(root, main.W)
	var img := root.get_texture().get_image()
	var name: String = args.get("name", "page")
	img.save_png(out.path_join(name + ".png"))
	print("SHOT ", out.path_join(name + ".png"))
	quit(0)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


## Prints the controls wider than the page, deepest first (for finding what pushes a phone page sideways).
func _widest(n: Node, w: float) -> void:
	for c in n.get_children():
		_widest(c, w)
	if n is Control and not (n is ScrollContainer) and (n as Control).get_combined_minimum_size().x > w - 28:
		var c := n as Control
		var t: String = c.get("text") if c.get("text") is String else ""
		print("WIDE %d %s %s %s" % [c.get_combined_minimum_size().x, c.get_class(), c.get_path(), t.left(40)])
