extends TestCase
## Every .gd file in the project must compile (catches errors in scenes no test opens).


func test_every_script_compiles() -> void:
	var files: PackedStringArray = []
	_collect("res://", files)
	assert_true(files.size() > 10, "found scripts")
	for f in files:
		var s: GDScript = load(f)
		assert_true(s != null and s.can_instantiate(), "compiles: " + f)


func test_every_scene_loads() -> void:
	var files: PackedStringArray = []
	_collect("res://", files, ".tscn")
	for f in files:
		var p: PackedScene = load(f)
		assert_true(p != null and p.can_instantiate(), "loads: " + f)


func _collect(dir: String, out: PackedStringArray, ext: String = ".gd") -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with(".") and sub != "build" and not _other_project(dir.path_join(sub)):
			_collect(dir.path_join(sub), out, ext)


## A folder with its own project.godot (compare/) is a separate project, not part of the game.
func _other_project(dir: String) -> bool:
	return FileAccess.file_exists(dir.path_join("project.godot"))
