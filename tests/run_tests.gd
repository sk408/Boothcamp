extends SceneTree
## Headless unit-test runner. Exit code 0 = all green, 1 = failures, 2 = nothing found.
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --filter=hoot --verbose
## Discovers every test_*.gd under SEARCH_DIRS (recursively). Each test method gets a fresh
## instance. Script errors logged during a test fail it (captured with a Logger).
## NOTE: this file runs as the main loop, so it must not name autoloads directly
## (they are not compile-time globals in -s mode). Test files can.

const SEARCH_DIRS: PackedStringArray = ["res://tests", "res://core/tests", "res://ui/tests", "res://world/tests", "res://story/tests"]


class ErrorCounter extends Logger:
	var count := 0
	var messages: PackedStringArray = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		_mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


var _filter := ""
var _verbose := false


func _initialize() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			_filter = a.substr(9)
		elif a == "--verbose":
			_verbose = true
	_run.call_deferred()


func _run() -> void:
	await process_frame  # let autoloads finish _ready()
	# Never touch the player's real save: tests get their own file and start from default settings.
	var game: Node = root.get_node_or_null("Game")
	if game != null:
		game.set("save_path", "user://save_tests.json")
		game.call("reset_save")
		game.call("apply_settings")
	var files: PackedStringArray = []
	for d in SEARCH_DIRS:
		_collect(d, files)
	files.sort()
	if files.is_empty():
		print("run_tests: no test files found")
		quit(2)
		return
	var errors := ErrorCounter.new()
	OS.add_logger(errors)
	var passed := 0
	var failed := 0
	var failed_names: PackedStringArray = []
	var t0 := Time.get_ticks_msec()
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("FAIL %s (does not load/compile)" % path)
			failed += 1
			failed_names.append(path)
			continue
		var methods: PackedStringArray = []
		for m: Dictionary in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not methods.has(n):
				if _filter == "" or path.contains(_filter) or n.contains(_filter):
					methods.append(n)
		for m in methods:
			var inst: Object = script.new()
			inst.set("tree", self)
			var before := errors.count
			if inst.has_method("before_each"):
				await inst.call("before_each")
			await inst.call(m)
			if inst.has_method("after_each"):
				await inst.call("after_each")
			if inst.has_method("_cleanup"):
				inst.call("_cleanup")
			await process_frame
			var fails: PackedStringArray = inst.get("failures") if inst.get("failures") != null else PackedStringArray()
			var new_errors := errors.count - before
			if new_errors > 0 and not bool(inst.get("errors_allowed")):
				for i in range(before, errors.count):
					fails.append("script/engine error: " + errors.messages[i])
			var name := "%s::%s" % [path.trim_prefix("res://"), m]
			if fails.is_empty():
				passed += 1
				if _verbose:
					print("  ok   ", name)
			else:
				failed += 1
				failed_names.append(name)
				print("FAIL ", name)
				for f in fails:
					print("       ", f)
	print("\n%d passed, %d failed  (%d files, %.1f s)" % [passed, failed, files.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	if failed > 0:
		print("Failed: ", ", ".join(failed_names))
	OS.remove_logger(errors)
	quit(1 if failed > 0 else 0)


func _collect(dir: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			_collect(dir.path_join(sub), out)
