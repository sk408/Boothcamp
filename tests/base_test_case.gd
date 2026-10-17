class_name TestCase
extends RefCounted
## Base class for unit tests (res://tests/base_test_case.gd). Put files named test_*.gd under res://tests/ (or a module's
## own res://<module>/tests/ folder), extend TestCase, and write methods named test_*().
## A test may be a coroutine (use await). Any script error during a test fails it too,
## unless the test calls allow_errors(). Run: godot --headless --path . -s res://tests/run_tests.gd

var tree: SceneTree
var failures: PackedStringArray = []
var errors_allowed := false
var _nodes: Array[Node] = []


## Override for per-test setup / teardown (may be coroutines).
func before_each() -> void:
	pass


func after_each() -> void:
	pass


func allow_errors() -> void:
	errors_allowed = true


func fail(msg: String) -> void:
	var where := ""
	for frame: Dictionary in get_stack():
		var src: String = frame.get("source", "")
		if not src.ends_with("base_test_case.gd"):
			where = "%s:%d" % [src.get_file(), int(frame.get("line", 0))]
			break
	failures.append("%s %s" % [where, msg])


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		fail("%s expected %s (%s), got %s (%s)" % [msg, var_to_str(expected), type_string(typeof(expected)), var_to_str(actual), type_string(typeof(actual))])
	elif actual != expected:
		fail("%s expected %s, got %s" % [msg, var_to_str(expected), var_to_str(actual)])


func assert_ne(actual: Variant, unexpected: Variant, msg: String = "") -> void:
	if actual == unexpected:
		fail("%s did not expect %s" % [msg, var_to_str(actual)])


func assert_near(actual: float, expected: float, tolerance: float, msg: String = "") -> void:
	if absf(actual - expected) > tolerance:
		fail("%s expected %f +/- %f, got %f" % [msg, expected, tolerance, actual])


func assert_between(actual: float, lo: float, hi: float, msg: String = "") -> void:
	if actual < lo or actual > hi:
		fail("%s expected in [%f, %f], got %f" % [msg, lo, hi, actual])


func assert_has(container: Variant, item: Variant, msg: String = "") -> void:
	var ok := false
	if container is Dictionary:
		ok = (container as Dictionary).has(item)
	elif container is Array or container is PackedStringArray or container is PackedInt32Array:
		ok = container.has(item)
	elif container is String:
		ok = (container as String).contains(str(item))
	if not ok:
		fail("%s expected to contain %s" % [msg, var_to_str(item)])


func assert_has_method(obj: Object, method: String, msg: String = "") -> void:
	if obj == null or not obj.has_method(method):
		fail("%s missing method %s" % [msg, method])


func assert_has_signal(obj: Object, sig: String, msg: String = "") -> void:
	if obj == null or not obj.has_signal(sig):
		fail("%s missing signal %s" % [msg, sig])


## Add a node to the tree for this test; it is freed after the test.
func add_node(n: Node) -> Node:
	tree.root.add_child(n)
	_nodes.append(n)
	return n


func autoload(name: String) -> Node:
	return tree.root.get_node_or_null(name)


func wait_frames(n: int = 1) -> void:
	for i in n:
		await tree.process_frame


func wait_seconds(s: float) -> void:
	await tree.create_timer(s).timeout


## Send an input action the way the player (or the autoplay bot) does: parse_input_event,
## delivered to _unhandled_input on the next frame.
func send_action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


## Press and release an action, waiting for both to be delivered.
func tap_action(action: StringName) -> void:
	send_action(action, true)
	await wait_frames(2)
	send_action(action, false)
	await wait_frames(2)


func _cleanup() -> void:
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()


func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
