extends TestCase
## (Days 4-5) The S0 seams that Day 4 (word scores) and Day 5 (the Party Noise Test) build on
## (CONTRACTS.md §9.10, §9.24). S0a: SpeechSim's helpers and model facades, SpeechMaterial.tokens()
## and the new validate checks, the "lists" rules, the new keys, the Events block, the counselling
## phase, the CHAPTERS markers and the two stub movies (valid, hidden until their day, and the card
## hold of their scene-1 sets once they have them: probe_movie_stage.gd, probe_card_hold_sets.gd). S0b: the test modes, with probe word (wrs) and party (sin) modes
## from this folder (probe_test_mode.gd, probe_sp_mode.gd) on every session seam (C1-C23) and screen
## seam (H1-H28), a missing mode script, run_by_textbook / run_hidden, the Hoot-turn gate, key
## placeholders, and the Daily Decibel hook. Day 3 must not notice any of it: its goldens (written
## before the seams) still match, also with the probes loaded.

const PROBE := "res://core/tests/probe_speech_model.gd"
const NOWHERE := "res://core/speech/models/__no_such_model__.gd"
const NORA_MARKER := "# (Day 4 marker) the nora entry replaces this line"
const MARCO_MARKER := "# (Day 5 marker) the marco entry replaces this line"
const SEPARATOR := "# Days 4-5: word recognition, then speech in noise. Keep this line between the two markers."

var _style := "otosuite"


func before_each() -> void:
	_style = Game.get_key_style()
	_probes(PROBE_MODE, PROBE_UI)


func after_each() -> void:
	Game.set_key_style(_style)
	if _screen_on:
		_screen_down()
	SpeechTestMode.path_override.clear()
	SpMode.path_override.clear()
	ProbeMode.calls.clear()
	ProbeUi.calls.clear()
	ProbeUi.unclaimed.clear()
	ProbeUi.hand_back_after = -1
	ProbeUi.hold_beats = false
	for id: String in ProbeMode.LISTS:
		SpeechMaterial._cache.erase(id)


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
	# Days 3-5 stay before the cases (Days 6 onward)
	var cases_at := -1
	for i in lines.size():
		if lines[i].strip_edges().begins_with("{\"id\": \"rocco\""):
			cases_at = i
			break
	assert_true(cases_at > int(at["marco"]), "the Day 5 line sits before the first case (rocco)")


# ---------------------------------------------------------------- S0a: the two movies (§9.10.7, §9.20)

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
## The Days 4-5 movies and their chapters, registered after main's (S0a stubs until W5a / P5a).
const DAYS45_MOVIES: Dictionary = {"letter_choir": "nora", "party_noise": "marco"}


## Both are registered after main's movies, in order, and valid for the shared player: 45-110 s,
## captions of 18 words or fewer, card params on every scene, quiet Sfx cues. The sets are checked
## only once a movie has its sets script (its "stage" line, W5b / P5b): before that (the stub, then
## W5a / P5a's cards-only data) every scene plays as its card, so it validates with no known sets.
func test_days45_movies_registered() -> void:
	var ids := Movies.ids()
	var last := ids.find("masking_recap")
	assert_true(last >= 0, "main's movies stay")
	for id: String in DAYS45_MOVIES:
		assert_true(Movies.has(id), "%s is registered" % id)
		assert_true(ids.find(id) > last, "%s after the movies before it" % id)
		last = ids.find(id)
		var m := Movies.movie(id)
		var known: Array = []
		if m.has("stage"):
			known = Stage2D.SETS   # the full check: the stage's sets plus the movie's own (own_sets)
			var own := Movies.own_sets(id)
			assert_false(own.is_empty(), "%s: its sets script declares its sets" % id)
			for set_id: StringName in own:
				assert_false(Stage2D.SETS.has(set_id), "%s: its own set %s is not a stage set" % [id, set_id])
		var bad := Movies.validate(id, known)
		assert_true(bad.is_empty(), "validate %s: %s" % [id, ", ".join(bad)])
		assert_eq(String(m.get("chapter", "")), String(DAYS45_MOVIES[id]), "%s's day" % id)
		assert_between(Movies.total_s(id), Movies.MIN_TOTAL_S, Movies.MAX_TOTAL_S, "%s's length" % id)
		for sc: Dictionary in m["scenes"]:
			var p: Dictionary = sc.get("params", {})
			assert_true(String(p.get("heading", "")).length() <= 30, "%s/%s: a short heading" % [id, sc["id"]])
			var card_lines: Array = p.get("lines", [])
			assert_true(card_lines.size() <= Movies.CARD_MAX_LINES, "%s/%s: at most 4 card lines" % [id, sc["id"]])
			for ln: Variant in card_lines:
				assert_true(String(ln).length() <= Movies.CARD_MAX_CHARS, "%s/%s: card line %s" % [id, sc["id"], ln])
			assert_has(Stage2D.CARD_ICONS, String(p.get("icon", "")), "%s/%s: a card icon" % [id, sc["id"]])
			for c: Variant in sc["captions"]:
				assert_true(Movies.word_count(String(c)) <= 18, "%s: 18 words or fewer: %s" % [id, c])
			for cue: Dictionary in sc.get("cues", []):
				assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s/%s: a known Sfx" % [id, sc["id"]])
				assert_true(float(cue.get("vol_db", 0.0)) <= -8.0, "%s/%s: a quiet cue" % [id, sc["id"]])


## Before its day exists a movie is the S0a stub: three "card" scenes of 16 s, no sets script.
## (The day's builder replaces the stub and the chapter marker in the same step, W5a / P5a.)
func test_days45_movie_stubs() -> void:
	for id: String in DAYS45_MOVIES:
		if not Game.chapter(String(DAYS45_MOVIES[id])).is_empty():
			continue
		var m := Movies.movie(id)
		assert_false(m.has("stage"), "%s: no sets script yet" % id)
		var scenes: Array = m["scenes"]
		assert_eq(scenes.size(), 3, "%s: three scenes" % id)
		for sc: Dictionary in scenes:
			assert_eq(String(sc["set"]), "card", "%s/%s: a card" % [id, sc["id"]])
			assert_near(float(sc["duration"]), 16.0, 0.001, "%s/%s: 16 s" % [id, sc["id"]])
		assert_near(Movies.total_s(id), 48.0, 0.001, "%s: 48 s" % id)


const ProbeStage := preload("res://core/tests/probe_movie_stage.gd")
const HOLD_SETS := "res://core/tests/probe_card_hold_sets.gd"


## Draws scene `sc` of movie `m` on a probe stage half a second before its card hold ends, and says
## what is wrong with the hold (Steve's rule, the shape of main's _set_meet): the old content must
## read the STAGE's t shifted by card_hold - 2 s (that is the clock _k / _pop / _ring and every s._*
## helper read), and the stage's t must be back before the stage's _iris() and _scene_chip().
func _card_hold_problems(m: Dictionary, sc: Dictionary) -> PackedStringArray:
	var bad := PackedStringArray()
	var hold := float((sc.get("params", {}) as Dictionary).get("card_hold", 0.0))
	var st: Control = ProbeStage.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", m)
	st.call("show_scene", sc)
	var real_t := hold - 0.5
	st.set("t", real_t)
	(st.get("seen_t") as Array).clear()
	st.queue_redraw()
	await wait_frames(2)
	var seen: Array = st.get("seen_t")
	var shifted := real_t - (hold - 2.0)
	var reads_shifted := false
	for v: Variant in seen:
		if absf(float(v) - shifted) < 0.001:
			reads_shifted = true
	if seen.is_empty():
		bad.append("scene 1 was not drawn")
	elif not reads_shifted:
		bad.append("the old content does not read the stage's t shifted by card_hold - 2 s")
	if absf(float(st.get("t")) - real_t) > 0.001:
		bad.append("the stage's t is %.2f after the set, not %.2f" % [float(st.get("t")), real_t])
	st.queue_free()
	return bad


## Steve's card hold in a movie's OWN scene-1 set (choir, quiet) shifts the STAGE's clock for the
## old content and puts it back, the way main's _set_meet does. Proved on main's masking movie and
## on a right and a wrong probe set; each Days 4-5 movie is checked once it has its sets script
## (its "stage" line, W5b / P5b) and passes with nothing to draw before then.
func test_days45_movie_card_hold_draw() -> void:
	var masking := Movies.movie("masking")
	var meet: Dictionary = (masking["scenes"] as Array)[0]
	assert_eq(await _card_hold_problems(masking, meet), PackedStringArray(), "main's meet: the shape to copy")
	var probe := {"id": "s0_hold", "stage": HOLD_SETS}
	var right := {"id": "one", "set": "hold_right", "duration": 14.0, "params": {"card_hold": 8.0}}
	var wrong := {"id": "one", "set": "hold_wrong", "duration": 14.0, "params": {"card_hold": 8.0}}
	assert_eq(await _card_hold_problems(probe, right), PackedStringArray(), "s.t shifted and put back")
	var caught := await _card_hold_problems(probe, wrong)
	assert_has(caught, "the old content does not read the stage's t shifted by card_hold - 2 s",
		"a set that shifts only its own copy of t is caught")
	for id: String in DAYS45_MOVIES:
		var m := Movies.movie(id)
		if not m.has("stage"):
			continue   # the stub or the cards-only data: scene 1 plays as its card, no hold to draw
		var sc: Dictionary = (m["scenes"] as Array)[0]
		var p: Dictionary = sc.get("params", {})
		assert_true(float(p.get("card_hold", 0.0)) >= 6.0, "%s: scene 1 holds its card" % id)
		assert_has(Movies.own_sets(id), StringName(String(sc["set"])), "%s: scene 1 is its own set" % id)
		var bad := await _card_hold_problems(m, sc)
		assert_true(bad.is_empty(), "%s/%s card hold: %s" % [id, sc["id"], ", ".join(bad)])


## A registered movie whose day is not in Game.CHAPTERS yet is in no replay list (the title's
## "Hoot's Movies" and its Options, through Movies.replay_ids()): the stubs stay hidden until
## their day exists, and nothing a player sees changes before then.
func test_days45_movies_hidden_until_their_day() -> void:
	for id: String in DAYS45_MOVIES:
		var listed := Movies.replay_ids().has(id)
		if Game.chapter(String(DAYS45_MOVIES[id])).is_empty():
			assert_false(listed, "%s: no %s chapter yet, so not listed" % [id, DAYS45_MOVIES[id]])
			assert_false(Movies.for_chapter(Game.current_chapter_id).has(id), "%s: not in this day's pause menu" % id)
		else:
			assert_true(listed, "%s: its day exists, so it is listed" % id)
	assert_has(Movies.replay_ids(), "masking", "Day 2's movie stays listed")
	# the guard itself, on two made-up movies
	var here := Movies.movie("masking")
	here["id"] = "s0_here"
	var nowhere := here.duplicate(true)
	nowhere["id"] = "s0_nowhere"
	nowhere["chapter"] = "no_such_day"
	Movies.extra["s0_here"] = here
	Movies.extra["s0_nowhere"] = nowhere
	var ids := Movies.replay_ids()
	Movies.extra.erase("s0_here")
	Movies.extra.erase("s0_nowhere")
	assert_has(ids, "s0_here", "a movie of a real day is listed")
	assert_false(ids.has("s0_nowhere"), "a movie of a day that does not exist is not")


# ---------------------------------------------------------------- Day 3 goldens (S0b: written before the seams)

const Golden := preload("res://core/tests/speech_day3_golden.gd")


## The golden `name` matches `text` (with BC_WRITE_GOLDEN=1 it is rewritten instead).
func _check_golden(name: String, text: String) -> void:
	if Golden.writing():
		Golden.write_golden(name, text)
		return
	var want := Golden.golden(name)
	assert_true(want != "", "the golden %s exists" % name)
	if text == want:
		return
	# the first difference, with a little context, so a leak is easy to find
	var i := 0
	while i < mini(text.length(), want.length()) and text[i] == want[i]:
		i += 1
	fail("%s differs at %d: golden ...%s... got ...%s..." % [name, i, want.substr(maxi(0, i - 80), 200), text.substr(maxi(0, i - 80), 200)])


func test_day3_session_golden() -> void:
	_check_golden("day3_session", Golden.session_snapshot())


func test_day3_screen_golden() -> void:
	var saved_scale := Engine.time_scale
	var saved_state := Game.rng.state
	var saved_quick := bool(Game.settings.get("quick_visit", true))
	Game.begin_visit("mike")
	Game.rng.seed = 1234
	Engine.time_scale = 8.0
	var text: String = await Golden.screen_snapshot(self)
	for n: Node in tree.get_nodes_in_group("speech_screen"):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
			n.queue_free()
	Engine.time_scale = saved_scale
	Game.rng.state = saved_state
	Game.set_setting("quick_visit", saved_quick)
	Hoot.clear()
	_check_golden("day3_screen", text)


func test_day3_paper_golden() -> void:
	var mike := _mike()
	var tones := SpeechSession.tone_results_from(mike)
	var merged: Dictionary = str_to_var(Golden.session_snapshot())["merged"]
	_check_golden("day3_paper", Golden.paper_snapshot(self, merged))
	_check_golden("day1_paper", Golden.paper_snapshot(self, tones, "gus"))


# ---------------------------------------------------------------- S0b: the test modes (§9.10.3-§9.10.7)

const PROBE_MODE := "res://core/tests/probe_test_mode.gd"
const PROBE_UI := "res://core/tests/probe_sp_mode.gd"
const PROBE_SPORTS := "res://core/tests/probe_sports.gd"
const NO_MODE := "res://core/speech/modes/__no_such_mode__.gd"
const SCREEN := "res://ui/speech/speech_screen.tscn"
const PAPER := "res://story/daily_decibel.tscn"
const ProbeMode := preload("res://core/tests/probe_test_mode.gd")
const ProbeUi := preload("res://core/tests/probe_sp_mode.gd")
## The screen tests run the clock fast (game time); every wait is bounded in real time.
const TEST_SPEED := 8.0

var _screen_on := false
var _saved_scale := 1.0
var _saved_quick := true
var _saved_rng := 0
var _saved_path := ""


## Both tests' modes (core and screen) at these scripts ("" = the game's own paths).
func _probes(core_path: String, ui_path: String) -> void:
	SpeechTestMode.path_override.clear()
	SpMode.path_override.clear()
	for t: StringName in [&"wrs", &"sin"]:
		if core_path != "":
			SpeechTestMode.path_override[t] = core_path
		if ui_path != "":
			SpMode.path_override[t] = ui_path


func _tones() -> Dictionary:
	return SpeechSession.tone_results_from(_mike())


func _session(plan: Dictionary, seed_value: int = 5) -> SpeechSession:
	var s := SpeechSession.new(_mike(), seed_value)
	var p := {"tones": _tones()}
	p.merge(plan, true)
	s.configure(p)
	return s


## Every technique event a session emits: [kind, data].
func _kinds(s: SpeechSession) -> Array:
	var out: Array = []
	s.technique.connect(func(kind: StringName, d: Dictionary) -> void: out.append([kind, d.duplicate(true)]))
	return out


static func _named(events: Array, kind: StringName) -> Array:
	var out: Array = []
	for e: Array in events:
		if e[0] == kind:
			out.append(e[1])
	return out


static func _called(calls: Array, what: String) -> bool:
	for c: Array in calls:
		if what in c:
			return true
	return false


func test_srt_has_no_mode() -> void:
	var s := _session({"test": "srt"})
	assert_true(s.mode == null and not s.mode_missing, "the SRT has no mode")
	s.begin("left", true)
	var st := s.get_state()
	for k: String in Golden.SESSION_STATE_KEYS:
		assert_true(st.has(k), "Day 3 key %s" % k)
	assert_eq(st["slot"], "left", "slot = the ear")
	assert_eq(st["mode"], "", "no mode")
	assert_false(st.has("wrs") or st.has("sin"), "no mode view")
	assert_eq(s.measure_key(), "srt:left")
	assert_true(SpeechTestMode.make(s, &"srt") == null and SpMode.make(&"srt") == null, "make() gives no SRT mode")


## C1-C16, C19, C21, C22 on one word list: the probe mode owns the items, the controls, the coach's
## move, the state, the tips, the points and the level / noise locks.
func test_session_seams_on_a_word_list() -> void:
	var s := _session({"test": "wrs", "level": 45, "target": 55})
	var ev := _kinds(s)
	assert_true(s.mode != null and not s.mode_missing, "a wrs plan has a mode")
	assert_eq(s.mode.get_script().resource_path, PROBE_MODE, "loaded by path")
	assert_true(s.mode.session() == s, "the mode knows its session")
	assert_eq(s.mode.test_id(), &"wrs")
	assert_eq(s.list_id, "probe_w1", "the mode picks its list")
	assert_eq(s.used_lists, ["probe_w1"] as Array[String])
	assert_true(_called(ProbeMode.calls, "configure"), "configure() reaches the mode")
	s.begin("left", true)
	assert_eq(s.slot, "left", "C3: the slot")
	assert_true(bool(s.coached["left"]), "coached by ear and slot")
	assert_eq(s.db, 45, "C3: the dial at mode.start_level()")
	assert_eq(s.measure_key(), "wrs:left:probe_w1", "C5: the mode's key")
	assert_eq(s.next_item()["id"], "pw1_1", "C8")
	assert_eq(s.recommended_action()["action"], &"probe_ready", "C13: the mode's move")
	assert_eq(s.textbook_target(), 55)
	assert_eq(s.recommended_start(), 55)
	assert_eq(s.candidate(), SpeechRules.NO_SRT, "C12")
	assert_true(s.masking_needed_here(70) and not s.masking_needed_here(60), "C14")
	var st := s.get_state()
	assert_eq([st["slot"], st["mode"], st["words_left"], st["recommended_start"]], ["left", "wrs", 3, 55], "C19")
	assert_eq((st["wrs"] as Dictionary)["list_id"], "probe_w1", "C19: the mode's view")
	# the noise is free before the first word, at the mode's level
	assert_true(s.set_mask(true), "the noise goes on before the list starts")
	assert_eq(s.mask_level(), 45 - 25, "the mode's noise rule")
	assert_true(s.set_mask(false))
	# a mode-only move, its tip and the slot in the event
	assert_eq(s.mode.act(&"probe_ready"), {"ready": true})
	var ready := _named(ev, &"probe_ready_ok")
	assert_eq(ready.size(), 1, "an observation")
	assert_eq(String(ready[0]["message"]), ProbeMode.TIPS[&"probe_ready_ok"], "C21: the mode's tip (keys filled by the screen)")
	assert_eq(ready[0]["slot"], "left", "C22: the slot in every event")
	assert_true(s.step_level(1) and s.step_level(1), "to 55")
	var t1 := s.present()
	assert_eq([t1["slot"], t1["list_id"], t1["n"]], ["left", "probe_w1", 1], "C9: the trial")
	assert_true(s.trials_for() == s.mode.current_trials() and s.trials_for().size() == 1, "C6")
	assert_eq(s.present(), {}, "one word at a time")
	# C15 / C16: locked once the list starts, said once per list
	assert_false(s.set_level(70), "the level is locked")
	assert_false(s.step_level(1), "and again")
	assert_false(s.set_mask(true), "the noise is locked")
	assert_eq(_named(ev, &"probe_level_locked").size(), 1, "once")
	assert_eq(_named(ev, &"probe_mask_locked").size(), 1, "once")
	assert_eq(s.db, 55)
	var sc := s.score(true)
	assert_eq(sc["scored"], true, "C10")
	assert_eq(int(_named(ev, &"probe_clean")[0]["points"]), 7, "C21: the mode's points")
	assert_eq(s.points, 7)
	s.present()
	s.score(true)   # item 2 is a miss: a slip
	var slips := _named(ev, &"probe_slip")
	assert_eq(slips.size(), 1)
	assert_eq(String(slips[0]["message"]), ProbeMode.TIPS[&"probe_slip"])
	assert_eq(s.errors.size(), 1)
	assert_eq([s.errors[0]["kind"], s.errors[0]["slot"]], ["probe_slip", "left"], "C22: errors[] carry the slot")
	assert_eq(s.slips(), [&"probe_slip"], "slips per list (the mode's key)")
	assert_false(s.is_done(), "C7")
	var got: Array = []
	s.stored.connect(func(e: String, t: StringName, sh: Dictionary) -> void: got.append([e, t, sh]))
	s.present()
	s.score(true)
	assert_true(s.is_done(), "the list ends itself")
	assert_eq(got.size(), 1)
	assert_eq([got[0][0], got[0][1], (got[0][2] as Dictionary)["slot"]], ["left", &"wrs", "left"], "the sheet carries its slot")
	assert_eq(s.store(), {}, "C11: wrs refuses STORE")
	assert_eq(_named(ev, &"probe_no_store").size(), 1)
	var res := s.build_results()
	assert_eq(res["tests"], ["wrs"] as Array[String])
	assert_eq(res["scored_sheets"], 1, "C20: one unit")
	assert_near(float(res["accuracy"]), 2.0 / 3.0, 0.0001, "the player's matches")
	assert_eq(res["wrs_summary"], {"slots": ["left"], "lists": 1}, "C20: summarize() on a throwaway mode")


## Two lists on one ear: separate trials, slips and measure keys; the second joins the slot's sheet.
func test_two_lists_on_one_ear() -> void:
	var s := _session({"test": "wrs", "level": 55, "target": 55, "ready": true})
	s.begin("left", false)
	var first: WeakRef = weakref(s.mode)
	while not s.is_done():
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				s.present()
			&"score_correct":
				s.score(true)
			&"score_missed":
				s.score(false)
	var p := {"test": "wrs", "level": 55, "target": 55, "ready": true, "list": "probe_w2", "tones": _tones()}
	s.configure(p)
	assert_true(first.get_ref() == null, "re-configuring drops the old mode")
	s.begin("left", false)
	assert_eq(s.measure_key(), "wrs:left:probe_w2")
	assert_false(s.is_done(), "a new list on the same ear")
	assert_eq(s.trials_for().size(), 0, "its own trials")
	assert_eq(s.used_lists, ["probe_w1", "probe_w2"] as Array[String], "play order")
	s.present()
	s.score(false)   # item 1 of probe_w2 is a hit: scored as a miss
	s.present()
	s.score(false)
	assert_true(s.is_done())
	var sh: Dictionary = s.sheets[&"wrs"]["left"]
	assert_eq((sh["lists"] as Array).size(), 2, "one sheet per slot, with lists")
	assert_eq(sh["units"], 2)
	assert_eq(((s.trials[&"wrs"] as Dictionary)["left"] as Array).size(), 5, "the slot keeps every list's trials")
	var res := s.build_results()
	assert_eq(res["scored_sheets"], 2, "units count, not sheets")
	assert_near(float(res["accuracy"]), 0.5, 0.0001, "the sheet's accuracy weighs its units")


## C17, C18, C4: "both", per-frequency minima and the best bone.
func test_both_ears_and_the_best_bone() -> void:
	var s := _session({"test": "srt"})
	var r := s.pta_for("right")
	var l := s.pta_for("left")
	assert_eq(s.pta_for("both"), minf(r, l), "the better PTA")
	var both := s.measured_thresholds("both")
	var tr := s.measured_thresholds("right")
	var tl := s.measured_thresholds("left")
	for f: Variant in both:
		assert_eq(int(both[f]), mini(int(tr.get(f, 999)), int(tl.get(f, 999))), "min at %s" % f)
	assert_true(is_nan(s.nontest_best_bone("both")), "no ear is free on a party test")
	assert_eq(s.nontest_best_bone("right"), SpeechRules.nontest_best_bone(s.tone_results, "right"))
	var lo := INF
	for f: int in SpeechRules.ear_best_bone(s.tone_results, "left"):
		lo = minf(lo, float(SpeechRules.ear_best_bone(s.tone_results, "left")[f]))
	assert_eq(s.test_best_bone("left"), lo)
	var empty := SpeechSession.new(_mike(), 1)
	assert_true(is_nan(empty.pta_for("both")) and is_nan(empty.test_best_bone("both")), "NAN with no tones")
	s.ensure_slot("both")
	for t: StringName in SpeechRules.TESTS:
		assert_eq(((s.trials[t] as Dictionary)["both"] as Array).size(), 0, "a both slot for %s" % t)
		assert_true((s.trials[t] as Dictionary).has("right") and (s.trials[t] as Dictionary).has("left"), "Day 3's slots stay")


## C20 with fake sheets: an SRT sheet weighs 1, a sheet with units weighs them, Hoot's weighs 0.
func test_build_results_units() -> void:
	_probes("", "")
	var s := _session({"test": "srt"})
	s.sheets[&"srt"]["right"] = {"accuracy": 1.0, "strokes": 10, "par": 8, "by_hoot": false}
	s.sheets[&"wrs"]["left"] = {"accuracy": 0.5, "units": 2, "strokes": 25, "par": 25, "by_hoot": false}
	s.sheets[&"sin"]["both"] = {"accuracy": 0.0, "units": 0, "strokes": 0, "par": 0, "by_hoot": true}
	s.sheets[&"srt"]["left"] = {"accuracy": 0.2, "strokes": 3, "par": 3, "by_hoot": true}
	var res := s.build_results()
	assert_eq(res["tests"], ["srt", "wrs", "sin"] as Array[String])
	assert_eq(res["scored_sheets"], 3)
	assert_near(float(res["accuracy"]), (1.0 + 0.5 * 2.0) / 3.0, 0.0001)
	assert_near(float(res["efficiency"]), 33.0 / 35.0, 0.0001, "Hoot's strokes stay out")
	assert_false(res.has("wrs_summary") or res.has("sin_summary"), "no summary without a mode script")
	var merged := SpeechSession.merge_results(_tones(), res)
	assert_eq(int((merged["speech"] as Dictionary)["scored_sheets"]), 3, "merge_results weighs the units")


## Freeing a session frees its mode (the mode holds it only weakly).
func test_freeing_a_session_frees_its_mode() -> void:
	var refs := _dropped_session()
	assert_true(refs[0].get_ref() == null, "the session is freed")
	assert_true(refs[1].get_ref() == null, "its mode goes with it")


func _dropped_session() -> Array[WeakRef]:
	var s := _session({"test": "sin"})
	assert_true(s.mode != null)
	return [weakref(s), weakref(s.mode)]


## §9.10.2: a wrs / sin plan whose script is missing: no mode, present() refused, no hidden run.
func test_missing_mode_script() -> void:
	_probes(NO_MODE, NO_MODE)
	var s := _session({"test": "wrs"})
	assert_true(s.mode == null and s.mode_missing, "mode_missing")
	s.begin("right", false)
	assert_eq(s.present(), {}, "refused")
	assert_eq(s.run_by_textbook("left"), {}, "nothing to run")
	assert_true((s.sheets[&"wrs"] as Dictionary).is_empty(), "no sheet")
	assert_eq(s.get_state()["mode"], "", "no mode in the state")
	var srt := _session({"test": "srt"})
	assert_false(srt.mode_missing, "the SRT is never missing")


## C23: Hoot's off-screen list, with the mode-only move through do(); Hoot's work counts 0.
func test_run_by_textbook() -> void:
	var s := _session({"test": "wrs", "level": 45, "target": 55})
	var stored: Array = []
	s.stored.connect(func(_e: String, _t: StringName, sh: Dictionary) -> void: stored.append(sh))
	var sheet := s.run_by_textbook("right")
	assert_false(sheet.is_empty(), "a stored sheet")
	assert_eq(stored.size(), 1, "the usual signal")
	assert_true(bool(sheet["by_hoot"]) and int(sheet["units"]) == 0, "Hoot's work")
	assert_eq(int(sheet["stored_db"]), 55, "louder through the session's own controls")
	assert_true(_called(ProbeMode.calls, "do"), "the mode-only move went through do()")
	assert_true(s.scoring, "scoring is back on")
	assert_eq([s.presentations, s.hoot_presentations], [0, 3], "his words")
	assert_true(s.errors.is_empty() and s.points == 0, "never scored")
	assert_eq(s.build_results()["scored_sheets"], 0)
	# a party slot
	var p := _session({"test": "sin", "slot": "aided_omni", "ready": true})
	var ps := p.run_by_textbook("both")
	assert_eq([ps["slot"], ps["ear"], ps["test"]], ["aided_omni", "both", "sin"], "the slot names the sheet")
	assert_true((p.sheets[&"sin"] as Dictionary).has("aided_omni"))
	assert_true(p.mode.state()["at"] == 2, "both sentences locked in through store()")
	# and the SRT, with no mode
	var srt := _session({"test": "srt"})
	var ss := srt.run_by_textbook("right")
	assert_true(not ss.is_empty() and bool(ss["by_hoot"]), "an SRT by the book, Hoot's")
	assert_true(bool(ss["bracketed"]), "stored at its bracket")


# ---------------------------------------------------------------- the screen (H1-H28)

func _screen_up() -> SpeechScreen:
	_screen_on = true
	_saved_path = Game.save_path
	Game.save_path = "user://test_speech_seams_save.json"
	_saved_scale = Engine.time_scale
	_saved_quick = bool(Game.settings.get("quick_visit", true))
	Game.begin_visit("mike")
	_saved_rng = Game.rng.state
	Game.rng.seed = 1234
	Engine.time_scale = TEST_SPEED
	var s := (load(SCREEN) as PackedScene).instantiate() as SpeechScreen
	add_node(s)
	return s


func _screen_down() -> void:
	_screen_on = false
	for n: Node in tree.get_nodes_in_group("speech_screen"):
		if n.get_parent() != null:
			n.get_parent().remove_child(n)
			n.queue_free()
	Engine.time_scale = _saved_scale
	Game.rng.state = _saved_rng
	Game.set_setting("quick_visit", _saved_quick)
	if FileAccess.file_exists(Game.save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.save_path))
	Game.save_path = _saved_path
	Hoot.clear()


func _wplan(extra: Dictionary = {}) -> Dictionary:
	var p := {"test": "wrs", "tones": _tones(), "level": 45, "target": 55}
	p.merge(extra, true)
	return p


func _until(cond: Callable, max_real_s: float = 20.0) -> bool:
	var t0 := Time.get_ticks_msec()
	while not bool(cond.call()):
		if Time.get_ticks_msec() - t0 > int(max_real_s * 1000.0):
			return false
		await wait_frames(1)
	return true


## Hoot's line on screen and the ones queued behind it.
static func _hoot_texts() -> Array:
	var out: Array = []
	var cur := Hoot.current_tip()
	if not cur.is_empty():
		out.append(String(cur["text"]))
	for t: Dictionary in (Hoot.get("_queue") as Array):
		out.append(String(t["text"]))
	return out


## Plays the list by its beats (any beat id) until test_finished: [[beat, info], ...], the results and
## every callout and Hoot line seen on the way.
func _play(s: SpeechScreen, start: Callable, max_real_s: float = 40.0) -> Dictionary:
	var beats: Array = []
	var tips: Array = []
	var callouts: Dictionary = {}
	var finished: Array = []
	var on_beat := func(beat: StringName, info: Dictionary, solver: Callable) -> void: beats.append([beat, info.duplicate(true), solver])
	var on_fin := func(r: Dictionary) -> void: finished.append(r)
	Events.awaiting_input.connect(on_beat)
	s.test_finished.connect(on_fin)
	start.call()
	var used := 0
	var t0 := Time.get_ticks_msec()
	while finished.is_empty() and Time.get_ticks_msec() - t0 < int(max_real_s * 1000.0):
		for c: Dictionary in (s.fx.get("_calls") as Array):
			callouts[String(c["text"])] = c["pos"]
		for t: String in _hoot_texts():
			if not tips.has(t):
				tips.append(t)
		if beats.size() > used:
			used = beats.size()
			await wait_frames(1)
			(beats[used - 1][2] as Callable).call()
		await wait_frames(1)
	Events.awaiting_input.disconnect(on_beat)
	s.test_finished.disconnect(on_fin)
	return {"beats": beats, "tips": tips, "callouts": callouts, "results": finished[0] if not finished.is_empty() else {}}


## H1-H27 on a WORD list: the mode's look, deck, anchors, beats, solver input, mouse route, coach,
## key placeholders, present / answer / score / store hooks, complete_list and celebrate.
func test_screen_word_mode() -> void:
	var s := _screen_up()
	s.quick_visit = false
	var presented: Array = []
	var stored: Array = []
	var on_p := func(_e: String, _t: StringName, _db: int, it: Dictionary) -> void: presented.append(it.duplicate())
	var on_s := func(_e: String, _t: StringName, sh: Dictionary) -> void: stored.append(sh)
	Events.speech_presented.connect(on_p)
	Events.speech_stored.connect(on_s)
	var run := await _play(s, func() -> void: s.start_test(_mike(), "right", true, _wplan()))
	Events.speech_presented.disconnect(on_p)
	Events.speech_stored.disconnect(on_s)
	var m := s._mode as ProbeUi
	assert_true(m != null and m.test == &"wrs", "H2: the WORD probe")
	assert_eq(s.memory.get("probe_entries", 0), 1, "H1: memory")
	# the first beat is the mode's own, with its mouse route, the slot and the probe's key
	var first: Array = run["beats"][0]
	assert_eq(first[0], &"probe_beat", "H19: the mode's beat id")
	var info: Dictionary = first[1]
	assert_eq([info["action"], (info["mouse"] as Dictionary)["click"], info["slot"], info["probe"]],
		["probe_ready", "probe_wrs_panel", "right", "wrs"], "H19 / H21: mouse_for, slot, beat_info")
	assert_true(_called(ProbeUi.calls, "handle_input"), "H3 / H20: the solver sent input_for()'s action")
	var kinds: Array = []
	for b: Array in run["beats"]:
		kinds.append(String((b[1] as Dictionary)["action"]))
	assert_eq(kinds, ["probe_ready", "louder", "louder", "present", "score_correct", "present", "score_missed", "present", "score_correct"],
		"every beat in order")
	# the coach's lines and the tips have their keys filled (D10)
	var tips: Array = run["tips"]
	assert_has(tips, "Get ready first: press %s." % s.k(&"toggle_lens"), "H22: a coach line")
	assert_has(tips, "Ready! Press %s for the first word." % s.k(&"present_tone"), "H9: a technique message")
	assert_has(tips, "Say the next one: press %s." % s.k(&"present_tone"))
	for t: String in tips:
		assert_false(t.contains("{key:"), "no placeholder left: " + t)
	# present, answer, score, store
	assert_eq(m.voice_calls, 3, "H5: the mode owns the voice call")
	assert_eq(m.answer_at.size(), 3)
	for i in m.answer_at.size():
		# the mode's wait (0.35 s) plus the patient's pause (0.3 s); the SRT card would take 0.8 s + 0.3 s
		assert_between(m.answer_at[i] - m.present_at[i], ProbeUi.WAIT_S + 0.3 - 0.01, 1.0, "H5: the answer follows the mode's wait")
	assert_eq(presented.size(), 3)
	for it: Dictionary in presented:
		assert_eq([it["slot"], it["list_id"]], ["right", "probe_w1"], "D26: speech_presented carries the slot")
	assert_true(_called(ProbeUi.calls, "on_answer") and _called(ProbeUi.calls, "on_scored"), "H6 / H7")
	assert_eq(s.bubble.style, &"loud", "the mode showed the answer")
	assert_true(_called(ProbeUi.calls, "on_stored"), "H8")
	assert_eq(stored.size(), 1, "complete_list emitted speech_stored once")
	assert_eq(stored[0]["slot"], "right")
	assert_eq(m.celebrated.get("slot", ""), "right", "H11: celebrate() got the slot's sheet")
	var res: Dictionary = run["results"]
	assert_true(((res["speech"] as Dictionary)["wrs"] as Dictionary).has("right"), "test_finished with the sheet")
	assert_true((run["callouts"] as Dictionary).has("+7"), "H12: the mode's points callout")
	assert_eq((run["callouts"] as Dictionary).get("+7", Vector2.ZERO), ProbeUi.CALLOUT_AT, "H12: at callout_point()")
	assert_true(Hoot.is_mastered(&"probe_skill") or int((Game.progress.get("hoot_mastery", {}) as Dictionary).get("probe_skill", 0)) > 0,
		"H13: the mode's mastery skill")
	assert_true(m.last_state.has("wrs"), "H23: refresh() gets the state")


## H2, H24-H26: the WORD look, then PARTY (the WORD anchors go), then the SRT again (every base
## label, glyph, widget and hook back, the Day 3 deck and anchors as in the golden).
func test_screen_mode_switches() -> void:
	var s := _screen_up()
	s.quick_visit = false
	s.start_test(_mike(), "right", false, _wplan())
	await wait_frames(3)
	var w := s._mode as ProbeUi
	assert_true(s.get_node_or_null("ModeWrs") == w, "the mode is the screen's child")
	for wid: Control in [s._ladder, s._meter, s._btn("speech_store_button"), s._btn("speech_mask_button"), s._btn("speech_louder_button")]:
		assert_false(wid.visible, "hidden or not placed: " + wid.name)
	assert_true(s._lcd.hide_tally, "&\"tally\" hides the LCD line")
	assert_true(s._btn("keys_toggle").visible and s._btn("style_toggle").visible and s._btn("pause_button").visible, "the pills stay")
	var k := clampf((s._deck.size.x - 1256.0) / 600.0, 0.0, 1.0)
	assert_eq(s._btn("speech_present_button").size.x, 200.0, "H25: widths from the entries")
	assert_near(s._btn("speech_incorrect_button").size.x, lerpf(120.0, 140.0, k), 0.01, "[narrow, wide]")
	assert_eq(s._btn("probe_wrs_ready_button").size.x, 150.0, "a mode button placed by its action")
	assert_true(s._btn("probe_wrs_ready_button").visible)
	assert_true(s._btn("speech_present_button").position.x < s._btn("speech_incorrect_button").position.x
		and s._btn("speech_correct_button").position.x < s._btn("probe_wrs_ready_button").position.x, "left to right")
	var titles: Array = []
	for g: Array in s._group_labels:
		titles.append(g[0])
	assert_eq(titles, ["WORD", "GET READY"])
	for key: String in ["bubble", "card", "mid", "meter", "perch", "dance", "deck", "booth"]:
		assert_true(w.rects.has(key), "H25: rect " + key)
	assert_true(Hoot.has_anchor("probe_wrs_panel") and Hoot.has_anchor("probe_wrs_ready_button"), "H26")
	assert_eq(s._lcd.view.get("test_chip", ""), "PROBE WRS", "H23: the LCD keys")
	assert_eq(s._dance._specs.size(), 3, "H24: the dance chips")
	var st := s.get_state()
	assert_eq([st["mode"], st["slot"], st["words_left"], st["recommended_start"], st["lens_on"], st["probe"]],
		["wrs", "right", 3, 55, false, "wrs"], "H27: the state")
	assert_eq(String(s.button(&"probe_ready").name), "probe_wrs_ready_button", "button(): the mode's own")
	assert_eq([s._btn("speech_present_button").text, s._btn("speech_present_button").glyph], ["SAY IT", SpButton.Glyph.EYE], "relabelled")
	# PARTY: WORD leaves
	s.start_test(_mike(), "both", false, {"test": "sin", "tones": _tones(), "ready": true})
	await wait_frames(3)
	var p := s._mode as ProbeUi
	assert_true(p != null and p != w and p.test == &"sin", "a second mode for the second test")
	assert_false(Hoot.has_anchor("probe_wrs_panel") or Hoot.has_anchor("probe_wrs_ready_button"), "H26: WORD's anchors went")
	assert_true(Hoot.has_anchor("probe_sin_panel") and Hoot.has_anchor("probe_sin_lock_button"))
	assert_true(_called(ProbeUi.calls, "exit") and _called(ProbeUi.calls, "restore_base"), "the old mode left")
	assert_false(s._btn("probe_wrs_ready_button").visible, "its button hides")
	assert_eq(String(s.button(&"store").name), "probe_sin_lock_button", "LOCK IN takes over STORE")
	assert_false(s._btn("speech_store_button").visible, "the base STORE is not placed")
	assert_eq(s._lcd.view.get("ear_chip", ""), "BOTH")
	assert_eq(s.get_state()["slot"], "both")
	# back to the SRT
	s.start_test(_mike(), "right", false, {"test": "srt", "tones": _tones()})
	await wait_frames(3)
	assert_true(s._mode == null, "no mode")
	assert_false(Hoot.has_anchor("probe_sin_panel") or Hoot.has_anchor("probe_sin_lock_button"))
	assert_eq([s._btn("speech_present_button").text, s._btn("speech_present_button").glyph], ["PRESENT", SpButton.Glyph.TALK],
		"the base label and glyph are back")
	assert_true(s._ladder.visible and s._meter.visible and not s._lcd.hide_tally, "the base widgets are back")
	assert_eq([s.card.carrier, s.card.hide_word, s.card.word_drawer.is_valid(), s.bubble.style, s.bubble.aside], ["", false, false, &"normal", ""],
		"the widget hooks are off")
	for key: String in SpLcd.OPTIONAL_KEYS:
		assert_false(s._lcd.view.has(key), "no LCD key " + key)
	assert_eq(s._dance._specs.size(), 0, "the SRT's chips")
	assert_false(s._btn("probe_sin_lock_button").visible)
	var golden: Dictionary = str_to_var(Golden.golden("day3_screen"))
	var want: Dictionary = golden["layout"]
	var now := Golden._layout(s)
	for id: String in want:
		assert_eq(now.get(id), want[id], "the Day 3 layout: " + id)
	var anchors: Array = []
	for a: Array in Golden._anchors(s):
		anchors.append(a)
	assert_eq(anchors, golden["anchors"], "the Day 3 anchors")


## The PARTY probe: LOCK IN through STORE, the base end-of-list path naming the slot.
func test_screen_party_mode() -> void:
	var s := _screen_up()
	s.quick_visit = false
	var run := await _play(s, func() -> void: s.start_test(_mike(), "both", false, {"test": "sin", "tones": _tones(), "ready": true}))
	var kinds: Array = []
	for b: Array in run["beats"]:
		kinds.append(String((b[1] as Dictionary)["action"]))
	assert_eq(kinds, ["present", "score_correct", "store", "present", "score_missed", "store"], "marked, then locked in")
	var res: Dictionary = run["results"]
	assert_true(((res["speech"] as Dictionary)["sin"] as Dictionary).has("both"), "the party sheet")
	var titled := false
	for t: String in (run["callouts"] as Dictionary):
		if t.begins_with("BOTH EAR"):
			titled = true
	assert_true(titled, "H11: the base celebration names the slot")
	assert_eq((run["beats"][0][1] as Dictionary)["slot"], "both")


## SpMode.MUST_CLAIM: the probes claim them; an unclaimed one never reaches the SRT handler.
func test_must_claim() -> void:
	var s := _screen_up()
	s.quick_visit = false
	s.start_test(_mike(), "right", false, _wplan({"ready": true, "level": 55}))
	await wait_frames(2)
	for a: StringName in SpMode.MUST_CLAIM:
		assert_true(s._mode.act(a), "the probe claims %s" % a)
	var base := SpMode.new()
	for a: StringName in SpMode.MUST_CLAIM:
		assert_true(base.act(a), "the base claims %s too" % a)
	base.free()
	# H18: the mode holds the beat back (a confirm chip), then lets it go
	var beats: Array = []
	var on_beat := func(beat: StringName, info: Dictionary, _solver: Callable) -> void: beats.append([beat, info])
	Events.awaiting_input.connect(on_beat)
	ProbeUi.hold_beats = true
	s._beat_key = ""
	s.refresh()
	await wait_frames(3)
	assert_eq(beats.size(), 0, "H18: no beat while the mode says none")
	ProbeUi.hold_beats = false
	s.refresh()
	await wait_frames(3)
	Events.awaiting_input.disconnect(on_beat)
	assert_eq(beats.size(), 1, "then the session's move")
	assert_eq(String((beats[0][1] as Dictionary)["action"]), "present")
	# H9 / H10: a kind the mode claims shows nothing; the mode's ghost-hand target
	Hoot.clear()
	s.session.emit_kind(&"probe_quiet", {}, "A quiet probe line.")
	assert_false(_hoot_texts().has("A quiet probe line."), "H9: claimed by the mode")
	s.session.emit_kind(&"probe_loud", {}, "A loud probe line, {key:louder} to go up.")
	assert_has(_hoot_texts(), "A loud probe line, %s to go up." % s.k(&"louder"), "H9: the rest are shown, keys filled")
	assert_eq(s._target_for(&"probe_slip", {}), "probe_wrs_panel", "H10")
	allow_errors()
	ProbeUi.unclaimed.append(&"store")
	s._act(&"store")
	assert_eq(s._store_warns, 0, "the SRT store never ran")
	assert_true((s.session.sheets[&"srt"] as Dictionary).is_empty())


## §9.10.2 on the screen: a missing mode script ends the test at once, with no sheet for it.
func test_screen_missing_mode() -> void:
	_probes(NO_MODE, NO_MODE)
	var s := _screen_up()
	var run := await _play(s, func() -> void: s.start_test(_mike(), "right", false, _wplan()), 10.0)
	var res: Dictionary = run["results"]
	assert_false(res.is_empty(), "test_finished came")
	assert_true(((res["speech"] as Dictionary).get("wrs", {}) as Dictionary).is_empty(), "no sheet")
	assert_true(s._mode == null)
	assert_eq((run["beats"] as Array).size(), 0, "no beat")


## H16 (D24): hoot_only opens Hoot's turn with quick visit off; hoot_first through the same gate, at
## the first PRESENT with level_first; H15 hand-back; H14 speed and text; H17 the key per list.
func test_hoot_gate() -> void:
	var s := _screen_up()
	s.quick_visit = false
	s.start_test(_mike(), "right", false, {"test": "srt", "tones": _tones(), "hoot_turn_after": 0})
	await wait_frames(3)
	assert_false(bool(s.get_state()["hoot_turn"]), "quick visit off: no turn")
	s.start_test(_mike(), "right", false, {"test": "srt", "tones": _tones(), "hoot_turn_after": 0, "hoot_only": true, "hoot_speed": 4.0})
	assert_true(await _until(func() -> bool: return bool(s.get_state()["hoot_turn"]) and s._ff_on), "hoot_only: Hoot's turn")
	assert_near(Engine.time_scale, TEST_SPEED * 4.0, 0.001, "H14: plan hoot_speed")
	assert_true(await _until(func() -> bool: return not bool(s.get_state()["hoot_turn"]), 30.0), "he finishes")
	assert_near(Engine.time_scale, TEST_SPEED, 0.001, "restored exactly")
	assert_true(s._hoot_done_ears.has("srt:right"), "H17: keyed by the measurement")
	# H7: hoot_turn_after counts the player's scored words on this list
	s.start_test(_mike(), "right", false, _wplan({"hoot_only": true, "hoot_turn_after": 1, "ready": true, "level": 55, "list": "probe_w2"}))
	await wait_frames(2)
	s.do_action(&"present")
	assert_true(await _until(func() -> bool: return s.answer_shown()), "the answer")
	assert_false(bool(s.get_state()["hoot_turn"]), "a presented word is not yet a unit")
	s.do_action(&"score_correct")
	assert_true(await _until(func() -> bool: return bool(s.get_state()["hoot_turn"])), "one scored word: Hoot's turn")
	assert_true(await _until(func() -> bool: return not bool(s.get_state()["hoot_turn"]), 30.0), "he finishes the list")
	assert_true(s._hoot_done_ears.has("wrs:right:probe_w2"), "H17: done for this list")
	# hoot_first on a mode list, with the hand-back
	ProbeUi.hand_back_after = 2
	s.start_test(_mike(), "left", false, _wplan({"hoot_first": 1, "hoot_only": true}))
	assert_true(await _until(func() -> bool: return bool(s.get_state()["hoot_turn"])), "hoot_first through the gate")
	assert_true(await _until(func() -> bool: return not bool(s.get_state()["hoot_turn"])), "H15: -2 hands back")
	assert_false(s._hoot_done_ears.has(s.session.measure_key()), "the list keeps its own turn")
	assert_true(s.get_state()["accepting_input"], "the player's again")
	var turn_texts := 0
	# level_first: no turn until the player's first PRESENT
	ProbeUi.hand_back_after = 0
	Hoot.clear()
	s.start_test(_mike(), "left", false, _wplan({"hoot_first": 1, "hoot_only": true, "level_first": true, "list": "probe_w2", "ready": true}))
	await wait_frames(4)
	assert_false(bool(s.get_state()["hoot_turn"]), "level_first: the player sets the level first")
	s.do_action(&"present")
	assert_true(bool(s.get_state()["hoot_turn"]), "the first PRESENT starts it")
	for t: String in _hoot_texts():
		if t.begins_with("My turn on the probe list"):
			turn_texts += 1
			assert_false(t.contains("{key:"), "keys filled")
	assert_eq(turn_texts, 1, "H14: the mode's turn text")
	s.quick_visit = true


## H28: run_hidden on the SRT and on a mode: the sheet joins the visit, no beat, no Hoot turn.
func test_run_hidden() -> void:
	var s := _screen_up()
	s.quick_visit = true
	var beats: Array = []
	var stored: Array = []
	var on_beat := func(beat: StringName, _info: Dictionary, _solver: Callable) -> void: beats.append(beat)
	var on_s := func(_e: String, _t: StringName, sh: Dictionary) -> void: stored.append(sh)
	Events.awaiting_input.connect(on_beat)
	Events.speech_stored.connect(on_s)
	var srt: Dictionary = await s.run_hidden(_mike(), "right", {"test": "srt", "tones": _tones()})
	assert_true(not srt.is_empty() and bool(srt["by_hoot"]), "Hoot's SRT")
	assert_false(bool(s.get_state()["hoot_turn"]), "no Hoot turn")
	var wrs: Dictionary = await s.run_hidden(_mike(), "left", _wplan())
	assert_true(not wrs.is_empty() and bool(wrs["by_hoot"]) and int(wrs["units"]) == 0, "Hoot's list")
	assert_true(_called(ProbeUi.calls, "montage"), "the mode's montage")
	await wait_frames(3)
	Events.awaiting_input.disconnect(on_beat)
	Events.speech_stored.disconnect(on_s)
	assert_eq(beats.size(), 0, "no beats")
	assert_eq(stored.size(), 2, "speech_stored for each")
	var res := s.get_results()
	assert_true((((res["speech"] as Dictionary)["srt"]) as Dictionary).has("right") and (((res["speech"] as Dictionary)["wrs"]) as Dictionary).has("left"),
		"both join this visit's results")
	assert_eq(int((res["speech"] as Dictionary)["scored_sheets"]), 0, "Hoot's work is not scored")
	assert_false(s._hidden_run)


# ---------------------------------------------------------------- the Daily Decibel (D8)

func test_paper_is_speech_for_any_test() -> void:
	var dd := load("res://story/daily_decibel.gd") as GDScript
	assert_true(bool(dd.call("_is_speech", {"speech": {"wrs": {"left": {"stored_db": 75}}}})), "word lists only")
	assert_true(bool(dd.call("_is_speech", {"speech": {"sin": {"both": {"stored_db": 9}}}})), "party lists only")
	assert_true(bool(dd.call("_is_speech", {"speech": {"srt": {"right": {"stored_db": 30}}}})), "Day 3")
	assert_false(bool(dd.call("_is_speech", {"speech": {"srt": {}, "wrs": {}, "sin": {}}})), "no sheets")
	assert_false(bool(dd.call("_is_speech", {})), "a tones day")


func test_paper_takes_the_day_from_the_summary() -> void:
	var paper: Node = (load(PAPER) as PackedScene).instantiate()
	add_node(paper)
	var aud := {"speech": {"tests": ["wrs"], "wrs": {"left": {"stored_db": 75}}}}
	var summary := {"patient_id": "mike", "score": 74.0, "grade": "C", "accuracy": 0.8, "technique": 0.8, "efficiency": 1.0, "care": 1.0,
		"comfort": 3, "medals": {}, "coins_earned": 10, "coins_total": 10, "audiometry": aud, "chapter_id": "mike", "day": 4,
		"patient_name": "Probe Person", "patient_short": "Probe", "weather": "Weather: a light drizzle of probe words",
		"subheads": {"C": "A probe subhead for a C."}, "sports_script": PROBE_SPORTS}
	paper.call("_build", summary)
	var texts: Array = []
	Golden._labels(paper, texts)
	assert_has(texts, "Weather: a light drizzle of probe words", "the summary's weather")
	assert_has(texts, "A probe subhead for a C.", "the summary's subheads, also for a C")
	assert_has(texts, "SPORTS: THE PROBE CARD", "the summary's sports column")
	assert_has(texts, "tests wrs, day 4", "build(c2, audiometry, summary)")
	assert_false(texts.has("SPORTS: THE WORD GOLF CARD"), "instead of the SRT card")


# ---------------------------------------------------------------- Day 3 with the probes loaded

func test_day3_session_golden_without_overrides() -> void:
	_probes("", "")
	_check_golden("day3_session", Golden.session_snapshot())
