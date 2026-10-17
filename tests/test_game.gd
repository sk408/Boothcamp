extends TestCase
## Game autoload: settings, key style, save/load, visit scoring.

var _saved_path := ""
var _saved_settings := {}
var _saved_progress := {}


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_settings = Game.settings.duplicate(true)
	_saved_progress = Game.progress.duplicate(true)
	Game.save_path = "user://test_save.json"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_save.json"))
	Game.save_path = _saved_path
	Game.settings = _saved_settings
	Game.progress = _saved_progress
	Game.apply_settings()


func _has_key(action: StringName, key: Key) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).keycode == key:
			return true
	return false


func test_input_actions_exist() -> void:
	for a in ["present_tone", "louder", "softer", "freq_up", "freq_down", "store", "no_response", "ear_right", "ear_left", "toggle_mask", "advance_dialogue", "pause"]:
		assert_true(InputMap.has_action(a), "action " + a)


func test_otosuite_default_keys() -> void:
	Game.settings["key_style"] = "otosuite"
	Game.apply_settings()
	assert_true(_has_key(&"louder", KEY_UP), "Up = louder")
	assert_true(_has_key(&"softer", KEY_DOWN), "Down = softer")
	assert_true(_has_key(&"present_tone", KEY_SPACE), "Space = tone")
	assert_true(_has_key(&"store", KEY_S), "S = store")
	assert_true(_has_key(&"no_response", KEY_N), "N = no response")
	assert_true(_has_key(&"freq_up", KEY_RIGHT), "Right = higher frequency")
	assert_eq(Game.key_label(&"louder"), "Up")


func test_affinity_swaps_up_down() -> void:
	Game.set_key_style("affinity")
	assert_true(_has_key(&"louder", KEY_DOWN), "Affinity: Down = louder")
	assert_true(_has_key(&"softer", KEY_UP), "Affinity: Up = softer")
	assert_false(_has_key(&"louder", KEY_UP))
	assert_eq(Game.key_label(&"softer"), "Up")
	Game.set_key_style("otosuite")
	assert_true(_has_key(&"louder", KEY_UP), "back to OTOsuite")


func test_save_load_roundtrip() -> void:
	Game.settings["key_style"] = "affinity"
	Game.progress["coins"] = 123
	(Game.progress["upgrades"] as Array).append("comfy_chair")
	assert_true(Game.save_game())
	Game.settings["key_style"] = "otosuite"
	Game.progress["coins"] = 0
	assert_true(Game.load_game())
	assert_eq(Game.settings["key_style"], "affinity")
	assert_eq(Game.progress["coins"], 123)
	assert_true(Game.has_upgrade("comfy_chair"))


func test_corrupt_save_falls_back_to_defaults() -> void:
	allow_errors()
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_false(Game.load_game())
	assert_eq(Game.settings["key_style"], "otosuite")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path + ".bak"))


func test_visit_scoring_and_comfort() -> void:
	Game.begin_visit("gus")
	assert_eq(Game.get_comfort(), 3)
	Game.lose_comfort("too_loud")
	assert_eq(Game.get_comfort(), 2)
	Game.set_audiometry_results({"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0})
	var coins_before: int = Game.progress["coins"]
	var s := Game.finish_visit()
	assert_near(float(s["score"]), 95.0, 0.01, "care 2/3 costs 5 points")
	assert_eq(s["grade"], "S")
	assert_true(int(s["coins_total"]) > coins_before)
	assert_has(Game.progress["patients"], "gus")


func test_load_patient() -> void:
	var p := Game.load_patient("gus")
	assert_true(p is PatientProfile, "gus.tres is a PatientProfile")
