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
	# v3 (Chapter 2): masker level, transducers. Shift+arrows are a second masker pair: the
	# AudiOtron checks mask_* BEFORE louder/softer, because Shift+Up also matches plain Up.
	"mask_louder": [KEY_PAGEUP, [KEY_UP, "shift"]],
	"mask_softer": [KEY_PAGEDOWN, [KEY_DOWN, "shift"]],
	"transducer_air": [KEY_A, KEY_6],
	"transducer_bone": [KEY_B, KEY_8],
	"toggle_key_hints": [KEY_H],
	# Speech (Days 3-5, CONTRACTS.md §9.7): score the word the patient said. Space presents the
	# word (present_tone), Up / Down set the level (louder / softer), S stores, M is speech noise.
	"speech_correct": [KEY_RIGHT, KEY_KP_ADD, KEY_EQUAL],
	"speech_incorrect": [KEY_LEFT, KEY_KP_SUBTRACT, KEY_MINUS],
	# Speech, Days 4-5 (CONTRACTS.md §9.19): V = the word lens; 1-5 (and the keypad) flip a party
	# sentence's key words, G = all got. Nothing is rebound: 6 and 8 stay the transducers.
	"toggle_lens": [KEY_V],
	"party_word_1": [KEY_1, KEY_KP_1],
	"party_word_2": [KEY_2, KEY_KP_2],
	"party_word_3": [KEY_3, KEY_KP_3],
	"party_word_4": [KEY_4, KEY_KP_4],
	"party_word_5": [KEY_5, KEY_KP_5],
	"party_all_got": [KEY_G],
	"advance_dialogue": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
	"pause": [KEY_ESCAPE, KEY_P],
}

func _initialize() -> void:
	for action: String in KEYS:
		var events: Array = []
		for k: Variant in KEYS[action]:
			var ev := InputEventKey.new()
			if k is Array:
				ev.keycode = int((k as Array)[0]) as Key
				ev.shift_pressed = (k as Array).has("shift")
			else:
				ev.keycode = int(k) as Key
			ev.device = -1
			events.append(ev)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
	var err := ProjectSettings.save()
	print("saved project settings: ", error_string(err))
	quit(0 if err == OK else 1)
