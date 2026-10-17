extends SceneTree
## One-off generator: writes the InputMap (OTOsuite-style defaults) into project.godot.
## Run: godot --headless --path . -s res://tools/setup_input_map.gd
## Safe to re-run; it overwrites only the input/* entries listed here.

const KEYS := {
	"present_tone": [KEY_SPACE],
	"louder": [KEY_UP],
	"softer": [KEY_DOWN],
	"freq_up": [KEY_RIGHT],
	"freq_down": [KEY_LEFT],
	"store": [KEY_S, KEY_ENTER, KEY_KP_ENTER],
	"no_response": [KEY_N],
	"ear_right": [KEY_R],
	"ear_left": [KEY_L],
	"toggle_mask": [KEY_M],
	"toggle_key_hints": [KEY_H],
	"advance_dialogue": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"pause": [KEY_ESCAPE, KEY_P],
}

func _initialize() -> void:
	for action: String in KEYS:
		var events: Array = []
		for k: int in KEYS[action]:
			var ev := InputEventKey.new()
			ev.keycode = k as Key
			ev.device = -1
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err := ProjectSettings.save()
	print("saved project settings: ", error_string(err))
	quit(0 if err == OK else 1)
