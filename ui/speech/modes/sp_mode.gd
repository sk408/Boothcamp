class_name SpMode
extends Node
## SpMode: the SPEECH screen's look and controls for a test that is not the SRT (CONTRACTS.md
## §9.10.5). Day 4's WORD mode (SpModeWord, ui/speech/modes/sp_mode_word.gd) and Day 5's PARTY mode
## (SpModeParty, ui/speech/modes/sp_mode_party.gd) each extend it in their own file, so
## speech_screen.gd never names a Day 4 or Day 5 class and Day 3's SRT layout stays as it is: test
## "srt" has no mode.
##
## The screen makes one mode per test on first use (make(), by path), adds it as its child, calls
## setup() and make_buttons() once, and enter() on every start_test of that test. Every screen seam
## (H1-H28, §9.10.6) asks the mode first; the base answers below mean "do what the screen does for
## the SRT", so a mode overrides only what it changes. The screen's public helpers (player_ok,
## idle, busy, refresh, after, make_button, button, say, tip, deny, k, do_action, score_word,
## check_hoot_after, hoot_turn, hoot_running, answer_shown, clock, last_device, ui_root,
## complete_list, memory) and its read-only members (session, fx, voice, booth, lcd, card, bubble,
## dance) are what a mode works with.

## The mode's script, by test id. "srt" has none: the SRT is the screen's own layout.
const PATHS: Dictionary[StringName, String] = {
	&"wrs": "res://ui/speech/modes/sp_mode_word.gd", &"sin": "res://ui/speech/modes/sp_mode_party.gd"}
## Base actions every mode MUST claim in act(), so the SRT handlers never run on a WRS or SIN list (a test).
const MUST_CLAIM: Array[StringName] = [&"store", &"score_correct", &"score_missed"]

## Tests point a test id at another script here, read before PATHS ("" = no script). Empty in the game.
static var path_override: Dictionary = {}

## The screen this mode draws on (its parent). Set by setup().
var screen: SpeechScreen


## A new mode for test `t`: null for the SRT, or while the script is missing.
static func make(t: StringName) -> SpMode:
	if t == &"srt":
		return null
	var path := String(path_override[t]) if path_override.has(t) else String(PATHS.get(t, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	return script.new() as SpMode


## Once: build the mode's widgets under s.ui_root().
func setup(s: SpeechScreen) -> void:
	screen = s


## Every start_test of this test (a new list): read the plan, reset the widgets.
func enter(_plan: Dictionary) -> void:
	pass


## The screen leaves this mode (another test, or the screen exits): stop sounds, clear overlays,
## hide the mode's own widgets.
func exit() -> void:
	pass


## Base widgets this mode hides: any of &"ladder", &"meter", &"card", &"tally" (the LCD's THIS LEVEL
## line), &"mask_button", &"store_button". The screen shows them again when the test changes.
func hidden_base_widgets() -> Array[StringName]:
	return []


## The screen's areas this layout ({bubble, card, mid, meter, perch, dance, deck, booth}: Rect2),
## for the mode's own widgets. Called from every _layout().
func layout(_rects: Dictionary) -> void:
	pass


## The deck, left to right: [{title, buttons: [{action, id, width}]}]. id names a base button
## ("speech_present_button") or one of make_buttons(); without an id, action picks the button.
## width is px, or [narrow, wide] (lerped by the window's width). A button that is not placed is
## hidden, except the utility pills. [] = the SRT deck.
func deck_groups() -> Array[Dictionary]:
	return []


## Called once, after setup(): the mode's own buttons, action -> SpButton (made with
## screen.make_button(), named by their anchor id). They join the screen's button map.
func make_buttons() -> Dictionary:
	return {}


## The input action that does `action` (the beat solver sends it). &"" = the SRT mapping.
func input_for(_action: StringName, _args: Dictionary = {}) -> StringName:
	return &""


## The anchor a mouse clicks for `action` (the beat's mouse route). "" = the button's own anchor.
func mouse_for(_action: StringName, _args: Dictionary = {}) -> String:
	return ""


## Runs before the screen's own key handling, even in Hoot's turn. true = consumed.
func handle_input(_event: InputEvent) -> bool:
	return false


## A control (from a key, a button, the beat solver or Hoot). true = handled; the screen's SRT
## handler runs only on false. MUST_CLAIM actions are always claimed (the base claims them and
## does nothing): a WORD list scores through screen.score_word(), a PARTY list marks and locks
## through its own session calls.
func act(action: StringName, _args: Dictionary = {}) -> bool:
	return action in MUST_CLAIM


## The item was presented (session.present() made `trial`): show it AND start its sound
## (screen.voice.play_item(...), or the babble and the talker). Returns the seconds the item takes
## before the patient's pause (the answer then follows trial.delay_s); < 0 = the SRT card and voice.
func on_present(_trial: Dictionary) -> float:
	return -1.0


## The patient's answer is due. true = the mode shows it (the screen still marks it shown, emits
## Events.speech_response and shows the held tips); false = the SRT bubble.
func on_answer(_trial: Dictionary) -> bool:
	return false


## A word was scored through screen.score_word().
func on_scored(_trial: Dictionary) -> void:
	pass


## The session stored a sheet. true = the mode runs its own end-of-list show, and then MUST call
## screen.complete_list(sheet); false = the SRT stamp, meter and card.
func on_stored(_sheet: Dictionary) -> bool:
	return false


## A technique event. true = claimed (the screen shows nothing for it).
func on_technique(_kind: StringName, _data: Dictionary) -> bool:
	return false


## How the screen treats a kind: &"error" (a slip, shown once per visit), &"repeat" (a slip that
## repeats with a cooldown), &"hold" (held until the answer shows), &"clean" (a combo step: the
## note, the points and the combo callouts), &"" = the SRT lists.
func kind_class(_kind: StringName) -> StringName:
	return &""


## Hoot's ghost-hand target for a tip. "" = the SRT targets.
func target_for(_kind: StringName, _data: Dictionary) -> String:
	return ""


## The coach's line for `rec`: [text, anchor, key] ({key:<action>} placeholders are filled by the
## screen; key dedupes the line). [] = the SRT coach.
func coach_text(_rec: Dictionary) -> Array:
	return []


## The beat id for this idle point: &"speech", or a mode beat (&"call_it", &"lens_try").
func beat_id(_rec: Dictionary) -> StringName:
	return &"speech"


## A replacement for the session's move at this idle point ({} = keep it; {action: &"none"} =
## no beat now, e.g. while a confirm chip is up).
func beat_action(_rec: Dictionary) -> Dictionary:
	return {}


## The beat's info with the mode's keys added (the screen has put "slot" in already).
func beat_info(info: Dictionary) -> Dictionary:
	return info


## The beat's dedupe key ("" = the screen's own key plus the measure key and the action).
func beat_key(_rec: Dictionary) -> String:
	return ""


## One step of Hoot's turn: -1 = the screen's step (recommended_action() through do_action),
## -2 = hand back to the player, >= 0 = wait that long (the mode acted itself).
func hoot_step() -> float:
	return -1.0


## The line Hoot says as his turn starts ("" = the plan's hoot_turn_text, else the screen's).
func hoot_turn_text() -> String:
	return ""


## The LCD view with the mode's keys (SpLcd's optional keys: test_chip, ear_chip, chips, info_line,
## big_caption, aux, start_chip).
func lcd_view(view: Dictionary) -> Dictionary:
	return view


## The dance card's three chips, [{title, sub}] x 3. [] = the SRT's.
func dance_specs() -> Array[Dictionary]:
	return []


## After every screen refresh (state = get_state()): update the mode's widgets; asides may pop here.
func refresh(_state: Dictionary) -> void:
	pass


## The finished list's celebration (1.2 s after complete_list). true = handled.
func celebrate(_sheet: Dictionary) -> bool:
	return false


## Where the golf and points callouts land (Vector2.ZERO = by the SRT ladder).
func callout_point() -> Vector2:
	return Vector2.ZERO


## The Hoot mastery skill a clean kind counts towards (&"" = none).
func mastery_skill(_kind: StringName) -> StringName:
	return &""


## Ghost-hand anchors of the mode's own widgets, id -> Control (the buttons of make_buttons() are
## registered by their names anyway). Registered while the mode is active.
func anchors() -> Dictionary:
	return {}


## Put back every base label, glyph and visibility the mode changed (the test changes to another).
func restore_base() -> void:
	pass


## Extra keys for the screen's get_state(): lens_on, confirm_pending, practice ({} = the defaults).
func extra_state() -> Dictionary:
	return {}


## run_hidden's montage of a sheet Hoot ran off-screen (the strip stamps in finished, the band chip
## lands). Returns its length in seconds (< 0 = nothing shown).
func montage(_sheet: Dictionary) -> float:
	return -1.0
