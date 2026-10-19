extends TestCase
## (Days 4-5) The S0 seams that Day 4 (word scores) and Day 5 (the Party Noise Test) build on
## (CONTRACTS.md §9.10, §9.24). This part is S0a: SpeechSim's helpers and model facades,
## SpeechMaterial.tokens() and the new validate checks, the "lists" rules, the new keys, the Events
## block, the counselling phase and the CHAPTERS markers. Day 3 must not notice any of it.

const PROBE := "res://core/tests/probe_speech_model.gd"
const NOWHERE := "res://core/speech/models/__no_such_model__.gd"
const NORA_MARKER := "# (Day 4 marker) the nora entry replaces this line"
const MARCO_MARKER := "# (Day 5 marker) the marco entry replaces this line"
const SEPARATOR := "# Days 4-5: word recognition, then speech in noise. Keep this line between the two markers."

var _style := "otosuite"


func before_each() -> void:
	_style = Game.get_key_style()


func after_each() -> void:
	Game.set_key_style(_style)


func _mike() -> PatientProfile:
	return Game.load_patient("mike") as PatientProfile


func _sim(model_path: String, seed_value: int = 7) -> SpeechSim:
	var s := SpeechSim.new(_mike(), seed_value)
	s.wrs_model_path = model_path
	s.sin_model_path = model_path
	return s


static func _has_key(action: StringName, key: Key) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).keycode == key and not (ev as InputEventKey).shift_pressed:
			return true
	return false


# ---------------------------------------------------------------- SpeechSim

func test_sim_public_helpers() -> void:
	var p := _mike()
	var s := SpeechSim.new(p, 3)
	assert_eq(s.condition, &"unaided", "a fresh sim is unaided")
	assert_eq(s.ia(), float(p.get_ia(&"phones")), "ia() is the head's IA for phones")
	s.transducer = &"inserts"
	assert_eq(s.ia(), float(p.get_ia(&"inserts")), "ia() follows the transducer")
	var air := s.air("left")
	assert_eq(air, p.get_thresholds("left"), "air() is the ear's true thresholds")
	air[1000] = -99
	assert_ne(s.air("left")[1000], -99, "air() hands out a copy")
	for i in 50:
		var d := s.delay_for(0.5)
		assert_between(d, p.reaction_time_min_s, p.reaction_time_max_s + SpeechSim.NEAR_EXTRA_S, "delay_for")
	assert_eq(SpeechSim.WRS_MODEL_PATH, "res://core/speech/models/wrs_model.gd")
	assert_eq(SpeechSim.SIN_MODEL_PATH, "res://core/speech/models/sin_model.gd")


func test_facade_defaults_without_models() -> void:
	for path: String in [NOWHERE, ""]:
		var s := _sim(path)
		var before := s.rng.state
		assert_true(s.wrs_model() == null and s.sin_model() == null, "no model at '%s'" % path)
		assert_eq(s.true_wrs_max("right"), 0.0)
		assert_eq(s.p_wrs_test("right", 55), 0.0)
		assert_eq(s.p_wrs_cross("right", 55), 0.0)
		assert_eq(s.p_wrs("right", 55), 0.0)
		assert_eq(s.deal_wrs_list("right", 55, [{"id": "a"}], {"aside_by": 8}), {})
		assert_eq(s.respond_wrs("right", 55, {"id": "a", "text": "moon"}, &"test"), {})
		assert_eq(s.true_snr_loss(), 0.0)
		assert_eq(s.effective_snr_loss("left"), 0.0)
		assert_eq(s.p_key_word(10.0), 0.0)
		assert_eq(s.respond_sin(10, {"id": "x"}), {})
		assert_eq(s.rng.state, before, "a default draws nothing from the rng")


func test_facade_forwards_to_the_models() -> void:
	var s := _sim(PROBE)
	var w := s.wrs_model()
	assert_true(w != null, "the word model loads by path")
	assert_true(s.wrs_model() == w, "and only once")
	assert_true(s.sin_model() != null and s.sin_model() != w, "the party model is its own instance")
	assert_true(w.call("sim") == s, "a model knows its sim")
	assert_eq(s.true_wrs_max("left"), 70.0)
	assert_eq(s.true_wrs_max("right"), 90.0)
	assert_near(s.p_wrs_test("left", 75), 0.075, 0.0001)
	assert_near(s.p_wrs_cross("left", 80), 0.04, 0.0001)
	assert_near(s.p_wrs("left", 60), 0.6, 0.0001)
	var deal := s.deal_wrs_list("left", 75, [{}, {}, {}], {"ensure_audible_miss_by": 6})
	assert_eq(deal, {"ear": "left", "level": 75, "n": 3, "opts": {"ensure_audible_miss_by": 6}})
	var said := s.respond_wrs("left", 75, {"id": "w2_07"}, &"miss", [{}, {}], PackedStringArray(["Hmm?"]),
			&"plural_trap", PackedStringArray(["Lovely!"]))
	assert_eq(said, {"ear": "left", "level": 75, "id": "w2_07", "outcome": &"miss", "n": 2,
		"silences": PackedStringArray(["Hmm?"]), "style": &"plural_trap", "chatter": PackedStringArray(["Lovely!"])})
	assert_eq(s.true_snr_loss(), 9.0, "the party ear defaults to both")
	assert_eq(s.true_snr_loss("right"), 8.0)
	assert_eq(s.effective_snr_loss(), 9.0)
	s.condition = &"directional"
	assert_eq(s.effective_snr_loss(), 5.0, "a model reads the sim's condition")
	assert_near(s.p_key_word(5.0), 0.2, 0.0001)
	assert_eq(s.respond_sin(15, {"id": "p1_3"}), {"snr": 15, "id": "p1_3", "level": SpeechRules.SIN_LEVEL_DB,
		"ear": "both", "opts": {}})
	assert_eq(s.respond_sin(0, {"id": "p1_6"}, 50, "left", {"lost_lines": ["Eh?"]}),
		{"snr": 0, "id": "p1_6", "level": 50, "ear": "left", "opts": {"lost_lines": ["Eh?"]}})


func test_freeing_a_sim_frees_its_models() -> void:
	var refs := _dropped_sim()
	assert_true(refs[0].get_ref() == null, "the sim is freed: its models hold it only weakly")
	assert_true(refs[1].get_ref() == null, "the word model goes with it")
	assert_true(refs[2].get_ref() == null, "the party model goes with it")


## A sim with both models loaded, dropped on return (its own frame holds the only strong refs).
func _dropped_sim() -> Array[WeakRef]:
	var s := _sim(PROBE)
	var out: Array[WeakRef] = [weakref(s), weakref(s.wrs_model()), weakref(s.sin_model())]
	assert_true(out[1].get_ref() != null and out[2].get_ref() != null, "both models are alive with the sim")
	return out


## The new calls never touch the SRT: the same seed gives the same answers with or without them.
func test_srt_answers_ignore_the_new_calls() -> void:
	var others := SpeechMaterial.items("spondee_a")
	var it: Dictionary = others[0]
	var plain := SpeechSim.new(_mike(), 31)
	var busy := _sim("", 31)
	for i in 60:
		var level := 15 + (i % 7) * 5
		busy.ia()
		busy.air("right")
		busy.true_wrs_max("right")
		busy.p_wrs("right", level)
		busy.respond_wrs("right", level, it, &"test")
		busy.p_key_word(float(level))
		busy.respond_sin(5, it)
		assert_eq(busy.respond_srt("right", level, it, others), plain.respond_srt("right", level, it, others), "word %d" % i)


# ---------------------------------------------------------------- SpeechMaterial

func test_tokens() -> void:
	assert_eq(SpeechMaterial.tokens("The red kite drifted, slowly... over the QUIET harbour!"),
		PackedStringArray(["the", "red", "kite", "drifted", "slowly", "over", "the", "quiet", "harbour"]))
	assert_eq(SpeechMaterial.tokens("Don't drop Nan’s x-ray."), PackedStringArray(["don't", "drop", "nan's", "x-ray"]))
	assert_eq(SpeechMaterial.tokens("'Twelve' - she said -"), PackedStringArray(["twelve", "she", "said"]))
	assert_eq(SpeechMaterial.tokens("  ?!  "), PackedStringArray())


func test_validate_keeps_every_list() -> void:
	assert_eq(SpeechMaterial.validate(SpeechMaterial.load_list("spondee_a")), PackedStringArray(), "spondee_a unchanged")
	for id: String in SpeechMaterial.list_ids():
		assert_eq(SpeechMaterial.validate(SpeechMaterial.load_list(id)), PackedStringArray(), id)


func _word(extra: Dictionary = {}) -> Dictionary:
	var it := {"id": "t_01", "text": "moon", "key_sound": "m", "foils": ["noon", "soon", "loon"]}
	it.merge(extra, true)
	return it


func _words(items: Array) -> Dictionary:
	return {"id": "words_t", "title": "Test words", "kind": "monosyllable", "original": true, "items": items}


func _problems(list: Dictionary, has: String, msg: String) -> void:
	var out := SpeechMaterial.validate(list)
	assert_true(out.size() > 0 and ", ".join(out).contains(has), "%s: wanted '%s', got %s" % [msg, has, out])


func test_validate_word_extras() -> void:
	var good := _word({"plural": "moons", "chunks": [["m", "m"], ["oo", "vowel"], ["n", "n"]],
		"asides": {"soon": "Soon? Patience, the list is long."}})
	var plain := {"id": "t_02", "text": "shell", "key_sound": "sh", "foils": ["bell", "well", "tell"]}
	var silent := {"id": "t_03", "text": "bike", "key_sound": "b", "foils": ["hike", "like", "pike"],
		"chunks": [["b", "b"], ["i", "vowel"], ["k", "k"], ["e", ""]]}
	assert_eq(SpeechMaterial.validate(_words([good, plain, silent])), PackedStringArray(), "good words, old shape and a silent letter")
	_problems(_words([_word({"chunks": [["m", "m"], ["o", "vowel"], ["n", "n"]]})]), "chunks spell", "chunks that do not spell")
	_problems(_words([_word({"chunks": [["m", "mm"], ["oo", "vowel"], ["n", "n"]]})]), "unknown chunk sound", "a bad sound id")
	_problems(_words([_word({"chunks": [["m", "n"], ["oo", "vowel"], ["n", "n"]]})]), "carries the key sound", "no key-sound chunk")
	_problems(_words([_word({"chunks": [["m"], ["oon", "vowel"]]})]), "not [letters, sound]", "a chunk without a sound")
	_problems(_words([_word({"chunks": []})]), "chunks must be", "empty chunks")
	_problems(_words([_word({"asides": {"spoon": "Spoon?"}})]), "not a foil", "an aside on a non-foil")
	_problems(_words([_word({"asides": {"Soon": "Soon?"}})]), "not a foil in lowercase", "an aside key in capitals")
	_problems(_words([_word({"asides": {"soon": 3}})]), "is not text", "an aside that is not text")
	_problems(_words([_word({"asides": ["soon"]})]), "asides must be", "asides as a list")
	_problems(_words([_word({"plural": "Moon"})]), "repeats the word", "a plural equal to the word")
	_problems(_words([_word({"plural": "soon"})]), "repeats the word or a foil", "a plural equal to a foil")
	_problems(_words([_word({"plural": 2})]), "plural must be", "a plural that is not a word")


func _sentence(extra: Dictionary = {}) -> Dictionary:
	var it := {"id": "pt_1", "text": "The red kite drifted over the quiet harbour.",
		"key_words": ["red", "kite", "drifted", "quiet", "harbour"]}
	it.merge(extra, true)
	return it


func _sentences(items: Array) -> Dictionary:
	return {"id": "party_t", "title": "Test party", "kind": "sentence", "original": true, "items": items}


func test_validate_sentence_extras() -> void:
	var good := _sentence({"mishears": [["bed"], ["kit", "night"], ["lifted", "drifting"], ["white"], ["harbours"]],
		"key_sounds": [["r"], ["k", "t"], ["f", "t"], ["k", "t"], []]})
	var plain := {"id": "pt_2", "text": "Six damp towels hung by the back door.",
		"key_words": ["six", "damp", "towels", "hung", "door"]}
	assert_eq(SpeechMaterial.validate(_sentences([good, plain])), PackedStringArray(), "a full sentence and the old shape")
	_problems(_sentences([_sentence({"key_words": ["red", "kite", "floated", "quiet", "harbour"]})]),
		"not in the sentence", "a key word that is not there")
	_problems(_sentences([_sentence({"key_words": ["kite", "red", "drifted", "quiet", "harbour"]})]),
		"not in the sentence (in order)", "key words out of order")
	_problems(_sentences([_sentence({"key_words": ["red", "kite", "drifted", "quiet"]})]), "needs 5 key words", "four key words")
	_problems(_sentences([_sentence({"mishears": [["bed"], ["kit"], ["lifted"], ["white"]]})]),
		"needs 5 mishear groups", "four mishear groups")
	_problems(_sentences([_sentence({"mishears": [["Red"], ["kit"], ["lifted"], ["white"], ["harbours"]]})]),
		"repeats its key word", "a mishear equal to its key word")
	_problems(_sentences([_sentence({"mishears": [["bed"], [], ["lifted"], ["white"], ["harbours"]]})]),
		"needs a word", "an empty mishear group")
	_problems(_sentences([_sentence({"key_sounds": [["r"], ["kk"], ["f"], ["k"], ["h"]]})]),
		"unknown key sound", "a bad key sound")
	_problems(_sentences([_sentence({"key_sounds": [["r"], ["k"], ["f"], ["k"]]})]),
		"needs 5 key_sounds groups", "four key-sound groups")


# ---------------------------------------------------------------- rules, keys, events, story

func test_lists_rules_block() -> void:
	assert_eq(SpeechRules.LIST_TEE_BONUS, 2)
	assert_eq(SpeechRules.LIST_CONFIRM_SLIP, 3)


func test_days45_keys() -> void:
	Game.set_key_style("otosuite")
	assert_true(_has_key(&"toggle_lens", KEY_V), "V = the lens")
	assert_eq(Game.key_label(&"toggle_lens"), "V")
	for i in 5:
		var a := StringName("party_word_%d" % (i + 1))
		assert_true(_has_key(a, (KEY_1 + i) as Key), "%d flips key word %d" % [i + 1, i + 1])
		assert_true(_has_key(a, (KEY_KP_1 + i) as Key), "keypad %d too" % (i + 1))
		assert_true(ProjectSettings.has_setting("input/" + String(a)), "%s in project.godot" % a)
	assert_true(_has_key(&"party_all_got", KEY_G), "G = all got")
	for a: String in ["toggle_lens", "party_all_got"]:
		assert_true(ProjectSettings.has_setting("input/" + a), "%s in project.godot" % a)
	# nothing is rebound: 6 and 8 stay the transducers, and no older action takes a new key
	assert_true(_has_key(&"transducer_air", KEY_6) and _has_key(&"transducer_bone", KEY_8), "6 and 8 are the transducers")
	var keys: Dictionary = (load("res://tools/setup_input_map.gd") as GDScript).get_script_constant_map()["KEYS"]
	var fresh := [KEY_V, KEY_G, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5]
	for action: String in keys:
		assert_true(InputMap.has_action(action), "project action " + action)
		if action == "toggle_lens" or action.begins_with("party_"):
			continue
		for k: int in fresh:
			assert_false(_has_key(StringName(action), k as Key), "%s does not take a Days 4-5 key" % action)
	# the swap-arrows style swaps only the level pairs
	Game.set_key_style("affinity")
	assert_true(_has_key(&"louder", KEY_DOWN), "affinity: Down = louder")
	assert_true(_has_key(&"toggle_lens", KEY_V) and _has_key(&"party_all_got", KEY_G), "the new keys stay put")
	assert_true(_has_key(&"party_word_1", KEY_1) and _has_key(&"party_word_5", KEY_KP_5), "the party keys stay put")


func test_events_days45_block() -> void:
	var want := {
		"speech_lens_toggled": [["ear", TYPE_STRING], ["on", TYPE_BOOL]],
		"party_sentence_locked": [["condition", TYPE_STRING], ["n", TYPE_INT], ["snr", TYPE_INT], ["count", TYPE_INT]],
		"party_list_done": [["condition", TYPE_STRING], ["list_id", TYPE_STRING], ["total", TYPE_INT], ["snr_loss", TYPE_FLOAT]],
	}
	var found := {}
	for sig: Dictionary in Events.get_signal_list():
		var name := String(sig["name"])
		if not want.has(name):
			continue
		var args: Array = []
		for a: Dictionary in sig["args"]:
			args.append([String(a["name"]), int(a["type"])])
		assert_eq(args, want[name], name)
		found[name] = true
	assert_eq(found.size(), want.size(), "all three Days 4-5 signals")
	for s: String in ["speech_presented", "speech_scored", "speech_stored"]:
		assert_has_signal(Events, s, "the Day 3 speech signals stay")


func test_counselling_phase() -> void:
	assert_has(Game.PHASES, &"counselling")
	for p: StringName in [&"familiarize", &"speech", &"tymp", &"decision", &"results"]:
		assert_has(Game.PHASES, p, "kept")


## Each builder replaces only its own marker (CONTRACTS.md §9.23.1). Until then, the two markers sit
## right after mike with the separator alone between them; afterwards each entry takes its marker's place.
func test_chapter_markers() -> void:
	var lines := FileAccess.get_file_as_string("res://autoload/game.gd").split("\n")
	var at := {}
	for i in lines.size():
		var l := lines[i].strip_edges()
		for k: String in ["mike", "nora", "marco"]:
			if not at.has(k) and l.begins_with("{\"id\": \"%s\"" % k):
				at[k] = i
		if l.begins_with(NORA_MARKER):
			at["nora"] = i
			at["nora_marker"] = true
		elif l.begins_with(MARCO_MARKER):
			at["marco"] = i
			at["marco_marker"] = true
		elif l == SEPARATOR:
			at["sep"] = i
	var all_found := true
	for k: String in ["mike", "nora", "sep", "marco"]:
		assert_true(at.has(k), "found %s" % k)
		all_found = all_found and at.has(k)
	if not all_found:
		return
	assert_true(int(at["mike"]) < int(at["nora"]) and int(at["nora"]) < int(at["sep"]) and int(at["sep"]) < int(at["marco"]),
		"mike, the Day 4 marker, the separator, the Day 5 marker, in that order")
	if at.has("nora_marker"):
		assert_eq(int(at["sep"]), int(at["nora"]) + 1, "the Day 4 marker sits right above the separator")
		assert_true(Game.chapter("nora").is_empty(), "no nora chapter while its marker stands")
	if at.has("marco_marker"):
		assert_eq(int(at["marco"]), int(at["sep"]) + 1, "the Day 5 marker sits right below the separator")
		assert_true(Game.chapter("marco").is_empty(), "no marco chapter while its marker stands")
