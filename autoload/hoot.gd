extends Node
## Hoot: Professor Hoot's tip queue (autoload "Hoot"). Logic only, no visuals.
##
## Anyone requests a tip with Events.hoot_say.emit(text, priority, target) or Hoot.say(...).
## This node owns the queue: one tip on screen at a time, priority order, URGENT interrupts,
## once-per-visit keys, mastery counters, and a timeout so a missing view never blocks it.
## Every Events.phase_changed clears all tips (current and queued): tips are about "now".
## The view (res://story/hoot_bubble.tscn, story-owned) listens to Events.hoot_tip_shown /
## hoot_tip_dismissed and calls Hoot.dismiss(id) when the player clicks the bubble.
## Ghost-hand targets are anchor ids that UI/world register with register_anchor().
## Rules from the design notes §2.8: 18 words max, triggered by events, quiet once mastered.

const LOW := 0
const NORMAL := 1
const HIGH := 2
const URGENT := 3
const MAX_WORDS := 18
const MASTERY_CLEAN_USES := 3
const MAX_QUEUE := 4

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _current_left: float = 0.0
var _next_id: int = 1
var _said_keys: Dictionary = {}
var _anchors: Dictionary = {}
var _mastered_announced: Dictionary = {}
## Where the bubble view should place itself (viewport coords). Rect2() = the view's default.
## A screen sets it while it is open (e.g. the AudiOtron reserves a spot) and clears it on exit.
var bubble_rect_hint: Rect2 = Rect2()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	Events.hoot_say.connect(func(text: String, priority: int, target: String) -> void: say(text, priority, target))
	Events.level_started.connect(func(_id: String) -> void: reset_visit())
	Events.phase_changed.connect(func(_p: StringName, _i: Dictionary) -> void: clear())


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	if float(_current["duration"]) <= 0.0:
		return  # sticky until dismissed / replaced
	_current_left -= delta
	if _current_left <= 0.0:
		dismiss(int(_current["id"]))


## Queue a tip. Returns the tip id, or -1 if it was suppressed (duplicate key or mastered skill).
## duration_s: < 0 = automatic from word count, 0 = sticky until dismissed or replaced.
## key: optional; a tip with a key is shown at most once per visit.
## skill: optional; once Hoot.is_mastered(skill) the tip is suppressed.
func say(text: String, priority: int = NORMAL, target: String = "", key: String = "", duration_s: float = -1.0, skill: StringName = &"") -> int:
	var words := text.split(" ", false).size()
	if words > MAX_WORDS:
		push_warning("Hoot tip has %d words (max %d): %s" % [words, MAX_WORDS, text])
	if key != "":
		if _said_keys.has(key):
			return -1
		_said_keys[key] = true
	if skill != &"" and is_mastered(skill):
		return -1
	var dur := duration_s if duration_s >= 0.0 else clampf(1.8 + 0.33 * words, 3.0, 8.0)
	var tip := {"id": _next_id, "text": text, "priority": clampi(priority, LOW, URGENT), "target": target, "key": key, "duration": dur}
	_next_id += 1
	if _current.is_empty():
		_show(tip)
	elif int(tip["priority"]) >= URGENT or int(tip["priority"]) > int(_current["priority"]) + 1:
		_hide_current()
		_show(tip)
	else:
		_enqueue(tip)
	return int(tip["id"])


## Same as say() with a key: a gag lesson that fires once per visit.
func say_once(key: String, text: String, priority: int = NORMAL, target: String = "") -> bool:
	return say(text, priority, target, key) >= 0


## Remove the tip with this id (current or queued). Idempotent.
func dismiss(tip_id: int) -> void:
	if not _current.is_empty() and int(_current["id"]) == tip_id:
		_hide_current()
		_show_next()
		return
	for i in range(_queue.size() - 1, -1, -1):
		if int(_queue[i]["id"]) == tip_id:
			_queue.remove_at(i)


func dismiss_current() -> void:
	if not _current.is_empty():
		dismiss(int(_current["id"]))


## Drop queued tips (the one on screen stays until its timeout).
func clear_queue() -> void:
	_queue.clear()


## Drop everything, including the tip on screen.
func clear() -> void:
	_queue.clear()
	_hide_current()


func current_tip() -> Dictionary:
	return _current.duplicate()


func is_showing() -> bool:
	return not _current.is_empty()


func queued_count() -> int:
	return _queue.size()


func reset_visit() -> void:
	_said_keys.clear()
	clear()


## Ask the bubble view to sit inside this rect (viewport coordinates). Rect2() resets.
func set_bubble_hint(rect: Rect2) -> void:
	bubble_rect_hint = rect


func clear_bubble_hint() -> void:
	bubble_rect_hint = Rect2()


# ---------------------------------------------------------------- mastery

## Count one clean use of a skill (e.g. &"hw_step", &"store", &"earphones").
func note_clean_use(skill: StringName) -> void:
	var m := _mastery()
	m[String(skill)] = int(m.get(String(skill), 0)) + 1
	if int(m[String(skill)]) == MASTERY_CLEAN_USES and not _mastered_announced.has(skill):
		_mastered_announced[skill] = true
		Events.hoot_mastered.emit(skill)


func is_mastered(skill: StringName) -> bool:
	return int(_mastery().get(String(skill), 0)) >= MASTERY_CLEAN_USES


func _mastery() -> Dictionary:
	var game: Node = get_node_or_null("/root/Game")
	if game == null:
		return {}
	var progress: Dictionary = game.get("progress")
	if not progress.has("hoot_mastery"):
		progress["hoot_mastery"] = {}
	return progress["hoot_mastery"]


# ---------------------------------------------------------------- ghost-hand anchors

## Register a node the ghost hand can point at. Control, Node2D or Node3D (unprojected
## through the active 3D camera). Re-registering an id replaces it. Ids: CONTRACTS.md §8.
func register_anchor(id: String, node: Node) -> void:
	_anchors[id] = weakref(node)


func unregister_anchor(id: String) -> void:
	_anchors.erase(id)


func has_anchor(id: String) -> bool:
	return _anchor_node(id) != null


## Screen-space rect of an anchor (viewport coordinates). Rect2() if unknown.
func anchor_screen_rect(id: String) -> Rect2:
	var n := _anchor_node(id)
	if n == null:
		return Rect2()
	if n is Control:
		var c := n as Control
		return Rect2(c.get_global_transform_with_canvas().origin, c.size * c.get_global_transform_with_canvas().get_scale())
	if n is Node2D:
		return Rect2((n as Node2D).get_global_transform_with_canvas().origin, Vector2.ZERO)
	if n is Node3D:
		var cam := get_viewport().get_camera_3d()
		if cam != null and not cam.is_position_behind((n as Node3D).global_position):
			return Rect2(cam.unproject_position((n as Node3D).global_position), Vector2.ZERO)
	return Rect2()


func _anchor_node(id: String) -> Node:
	if not _anchors.has(id):
		return null
	var n: Object = (_anchors[id] as WeakRef).get_ref()
	if n == null or not is_instance_valid(n) or not (n as Node).is_inside_tree():
		return null
	return n as Node


# ---------------------------------------------------------------- internals

func _enqueue(tip: Dictionary) -> void:
	_queue.append(tip)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["priority"]) != int(b["priority"]):
			return int(a["priority"]) > int(b["priority"])
		return int(a["id"]) < int(b["id"]))
	while _queue.size() > MAX_QUEUE:
		_queue.pop_back()


func _show(tip: Dictionary) -> void:
	_current = tip
	_current_left = float(tip["duration"])
	Events.hoot_tip_shown.emit(tip.duplicate())


func _hide_current() -> void:
	if _current.is_empty():
		return
	var id := int(_current["id"])
	_current = {}
	Events.hoot_tip_dismissed.emit(id)


func _show_next() -> void:
	if _current.is_empty() and not _queue.is_empty():
		_show(_queue.pop_front())
