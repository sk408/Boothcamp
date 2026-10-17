extends TestCase
## Clinic (world/): the §6.1 API, every reaction, cameras, ear projection, the fitting
## grey/muffled world (no bus effects), and the story extras. Runs headless; uses a sped-up clock for walks.

const CLINIC := "res://world/clinic.tscn"
const API: PackedStringArray = [
	"walk_in", "walk_to", "sit", "stand", "focus_camera", "put_on_earphones", "take_off_earphones",
	"play_patient_reaction", "set_world_saturation", "get_booth_texture", "set_booth_view_active",
	"get_ear_screen_position", "get_patient", "get_main_camera", "hoot_emote", "demo_start",
]
const EXTRAS: PackedStringArray = [
	"doris_enter", "doris_react", "gus_look", "set_title_mode", "play_birdsong", "get_head_screen_position",
	"take_off_glasses", "put_on_glasses", "put_on_hearing_aids", "get_muffle",
]

var _scale := 1.0


func before_each() -> void:
	_scale = Engine.time_scale


func after_each() -> void:
	Engine.time_scale = _scale


func _clinic() -> Node3D:
	var c: Node3D = (load(CLINIC) as PackedScene).instantiate()
	add_node(c)
	return c


func test_api_and_constants() -> void:
	var c := _clinic()
	await wait_frames(2)
	for m in API:
		assert_has_method(c, m)
	for m in EXTRAS:
		assert_has_method(c, m)
	var reactions: Array = c.get("REACTIONS")
	for k: StringName in [&"heard", &"missed", &"false_alarm", &"too_loud_blast", &"startle", &"grooving", &"bored", &"straining", &"squint", &"yawn", &"cheer", &"confused", &"point_wrong_way", &"nod", &"wince"]:
		assert_has(reactions, k)
	var shots: Array = c.get("SHOTS")
	for s: StringName in [&"wide", &"door", &"desk", &"booth", &"ear_right", &"ear_left", &"face", &"otoscope"]:
		assert_has(shots, s)
	var spots: Dictionary = c.get("SPOTS")
	for s: StringName in [&"door", &"desk", &"booth"]:
		assert_true(spots.has(s), "SPOTS has %s" % s)
	assert_true(Stage.has_clinic(), "clinic registers with Stage")
	assert_true(c.call("get_booth_texture") is Texture2D, "booth texture")
	assert_true(c.call("get_patient") is Node3D, "patient node")
	assert_true(c.call("get_main_camera") is Camera3D, "main camera")


func test_every_reaction_and_emote_is_safe() -> void:
	var c := _clinic()
	await wait_frames(2)
	for k: StringName in c.get("REACTIONS"):
		c.call("play_patient_reaction", k, {"ear": "right", "intensity": 0.8, "db": 60})
		await wait_frames(2)
	c.call("play_patient_reaction", &"no_such_reaction", {})
	Game.settings["no_startle"] = true
	c.call("play_patient_reaction", &"too_loud_blast", {})
	Game.settings["no_startle"] = false
	for e: StringName in [&"wing_up", &"facepalm", &"nod", &"hop", &"gasp", &"cheer"]:
		c.call("hoot_emote", e)
	Events.screen_shake.emit(0.5, 0.2)
	Events.dialogue_line.emit("Gus", "Everyone mumbles!")
	Events.dialogue_line.emit("Hoot", "Hoo!")
	await wait_seconds(0.5)
	assert_true(true)


func test_walk_in_sit_and_ear_positions() -> void:
	Engine.time_scale = 8.0
	var c := _clinic()
	await wait_frames(2)
	await c.call("walk_in")
	var gus: Node3D = c.call("get_patient")
	assert_true(gus.position.distance_to((c.get("SPOTS") as Dictionary)[&"desk"]) < 0.3, "Gus reached the desk")
	await c.call("sit")
	assert_true(bool(gus.get("seated")), "Gus is seated")
	await c.call("focus_camera", &"face", 0.0)
	await wait_frames(2)
	var r: Vector2 = c.call("get_ear_screen_position", "right")
	var l: Vector2 = c.call("get_ear_screen_position", "left")
	var vp := Vector2(c.get_viewport().get_visible_rect().size)
	assert_between(r.x, 0.0, vp.x, "right ear on screen")
	assert_between(l.x, 0.0, vp.x, "left ear on screen")
	assert_true(r.x < l.x, "facing us, his right ear is on the screen's left")
	c.call("put_on_earphones", true)
	await wait_seconds(0.3)
	c.call("take_off_earphones")
	await c.call("stand")
	assert_false(bool(gus.get("seated")), "stood up")


func test_world_saturation_grey_and_back() -> void:
	var c := _clinic()
	await wait_frames(2)
	var master := AudioServer.get_bus_index(&"Master")
	var effects := AudioServer.get_bus_effect_count(master)
	assert_eq(float(c.call("get_muffle")), 0.0, "full colour = not muffled")
	c.call("set_world_saturation", 0.0)
	assert_eq(float(c.call("get_muffle")), 1.0, "grey = fully muffled")
	c.call("set_world_saturation", 0.5)
	assert_between(float(c.call("get_muffle")), 0.4, 0.6)
	c.call("set_world_saturation", 1.0)
	await wait_frames(2)
	assert_eq(float(c.call("get_muffle")), 0.0, "colour back = clear")
	assert_eq(AudioServer.get_bus_effect_count(master), effects, "muffling never touches the bus effects")


func test_story_extras() -> void:
	Engine.time_scale = 8.0
	var c := _clinic()
	await wait_frames(2)
	c.call("set_title_mode", true)
	await wait_seconds(0.5)
	c.call("set_title_mode", false)
	await c.call("doris_enter")
	c.call("doris_react", &"nod")
	c.call("gus_look", &"doris")
	c.call("gus_look", &"hoot")
	c.call("take_off_glasses")
	c.call("put_on_glasses")
	c.call("put_on_hearing_aids")
	c.call("play_birdsong")
	for s: StringName in c.get("SHOTS"):
		await c.call("focus_camera", s, 0.0)
	var hp: Vector2 = c.call("get_head_screen_position")
	assert_true(is_finite(hp.x) and is_finite(hp.y), "head projects")
	await wait_seconds(0.3)
