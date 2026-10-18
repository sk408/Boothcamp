extends TestCase
## (Speech) Contract checks for CONTRACTS.md §9: the speech signals, actions, patient field, the
## SPEECH screen's API, anchors and beat, and the Day 3 chapter.

const SPEECH_SCREEN := "res://ui/speech/speech_screen.tscn"
const SPEECH_SIGNALS := ["speech_started", "speech_presented", "speech_response", "speech_scored", "speech_stored",
	"speech_state_changed", "speech_finished"]
const SCREEN_STATE_KEYS := ["test", "ear", "db", "pta", "recommended_start", "candidate_db", "trail", "awaiting_score",
	"current", "mask_on", "masking_needed", "done", "combo", "points", "scoring",
	"accepting_input", "talking", "answer_shown", "hoot_turn", "coached", "patient_id", "quick_visit"]
const ANCHORS := ["speech_present_button", "speech_correct_button", "speech_incorrect_button", "speech_louder_button",
	"speech_softer_button", "speech_store_button", "speech_mask_button", "speech_word_card", "speech_response",
	"speech_ladder", "agreement_meter"]


func test_signals() -> void:
	for s: String in SPEECH_SIGNALS:
		assert_has_signal(Events, s, "Events")


func test_actions_and_keys() -> void:
	for a: StringName in [&"speech_correct", &"speech_incorrect"]:
		assert_true(InputMap.has_action(a), "action " + String(a))
	assert_has(Game.key_labels(&"speech_correct"), "Right")
	assert_has(Game.key_labels(&"speech_incorrect"), "Left")


func test_patient_speech_field() -> void:
	var p := Game.load_patient("mike") as PatientProfile
	assert_eq(p.validate(), PackedStringArray())
	assert_eq(int(p.speech_value("srt", "right")), 30)
	assert_eq(p.speech_value("nope", "", 7), 7)
	var bad := Game.load_patient("gus").duplicate() as PatientProfile
	bad.speech = {"srt_ofset": {}}
	assert_true(bad.validate().size() > 0, "unknown speech keys are rejected")


func test_chapter_and_phases() -> void:
	var c := Game.chapter("mike")
	assert_eq(int(c["day"]), 3)
	assert_eq(String(c["requires"]), "bonnie")
	assert_true(ResourceLoader.exists(String(c["scene"])), "level_mike scene")
	assert_has(Game.PHASES, &"familiarize")
	assert_has(Game.PHASES, &"speech")


func test_speech_screen_api() -> void:
	assert_true(ResourceLoader.exists(SPEECH_SCREEN))
	var screen := (load(SPEECH_SCREEN) as PackedScene).instantiate()
	assert_true(screen is CanvasLayer)
	assert_eq((screen as CanvasLayer).layer, 20)
	for m: String in ["start_test", "get_state", "get_results", "demo_start"]:
		assert_has_method(screen, m)
	assert_has_signal(screen, "test_finished")
	var beats: Array = []
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"speech":
			beats.append([info, solver])
	Events.awaiting_input.connect(cb)
	var started := [false]
	var cb2 := func(_p: String, _e: String, _c: bool) -> void: started[0] = true
	Events.audiometry_started.connect(cb2)
	add_node(screen)
	var mike := Game.load_patient("mike") as PatientProfile
	screen.call("start_test", mike, "right", true, {"test": "srt", "tones": SpeechSession.tone_results_from(mike)})
	await wait_frames(10)
	assert_true(Stage.audiometer == null, "the SPEECH screen is not the AudiOtron")
	assert_false(started[0], "no audiometry_started")
	assert_true(screen.is_in_group("speech_screen"))
	var st: Dictionary = screen.call("get_state")
	for k: String in SCREEN_STATE_KEYS:
		assert_has(st, k)
	for a: String in ANCHORS:
		assert_true(Hoot.has_anchor(a), "anchor " + a)
	assert_true(beats.size() > 0, "the screen emits a speech beat when it waits")
	if beats.size() > 0:
		var info: Dictionary = beats[beats.size() - 1][0]
		assert_has(info, "action")
		assert_has(info, "mouse")
		assert_true((beats[beats.size() - 1][1] as Callable).is_valid())
	Events.awaiting_input.disconnect(cb)
	Events.audiometry_started.disconnect(cb2)
