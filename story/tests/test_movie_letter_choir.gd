extends TestCase
## Day 4's explainer, Hoot's word movie "The Letter Choir" (story/explainers/movies/letter_choir.gd,
## its sets story/explainers/stages/letter_choir_sets.gd; docs/CHAPTER4.md §4, CONTRACTS.md §9.20).
## Tested by id: valid for the shared player with its own eight sets, Steve's lead-in on scene 1,
## every scene drawn at several moments with and without reduced motion, the cards-only fallback,
## and the facts it teaches pinned to SpeechRules. The level that plays it (and its announcement)
## belongs to Day 4's own branch and is tested there.

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const SETS_PATH := "res://story/explainers/stages/letter_choir_sets.gd"
const Sets := preload(SETS_PATH)

const ID := "letter_choir"
const SET_IDS: Array[StringName] = [&"choir", &"banana", &"curtain", &"mush", &"louder", &"crossing", &"count", &"tease"]
## (Steve) the lead-in, the shape of Day 2's masking movie
const MATINEE := "Hoot's Movie Matinee! Today's mystery:"
const QUESTION_MAX_CHARS := 30
const CARD_KEYS: Array[String] = ["heading", "lines", "icon", "tint"]
## Hoot never names a diagnosis.
const NEVER_SAID: Array[String] = ["tumour", "tumor", "neuroma"]
## Things a set must never do (a pure function of t; sounds only in the movie's cues).
const IMPURE: Array[String] = ["randf", "randi", "RandomNumberGenerator", "Time.", "create_tween", "add_child",
	"get_tree", "Sfx.", "AudioStream", "SpBanana", "res://ui/"]
const CARDS_ONLY_ID := "mv4_letter_choir_cards"


## The real stage, counting its transform pushes and pops and its draws: the stage clears its own
## stack after every set, so a set that leaves a push open would otherwise go unseen.
class CountingStage extends "res://story/explainers/explainer_stage.gd":
	var depth := 0
	var underflow := 0
	var draws := 0

	func _draw() -> void:
		draws += 1
		super()

	func _push(xf: Transform2D) -> void:
		depth += 1
		super(xf)

	func _pop_xf() -> void:
		if depth == 0:
			underflow += 1
		depth = maxi(0, depth - 1)
		super()


var _saved_motion: Variant = null


func before_each() -> void:
	_saved_motion = Game.settings.get("reduced_motion", false)


func after_each() -> void:
	Game.settings["reduced_motion"] = _saved_motion
	Movies.extra.erase(CARDS_ONLY_ID)


func _movie() -> Dictionary:
	return Movies.movie(ID)


func _scene(id: String) -> Dictionary:
	for sc: Dictionary in _movie()["scenes"]:
		if String(sc["id"]) == id:
			return sc
	return {}


## The set's own data of scene `id` (params.<set>).
func _data(id: String) -> Dictionary:
	var sc := _scene(id)
	return (sc.get("params", {}) as Dictionary).get(String(sc.get("set", "")), {})


static func _vowels(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text.substr(i, 1).to_lower()
		if "aeiou".contains(ch):
			out += ch
	return out


static func _letters(text: String) -> String:
	var out := ""
	for i in text.length():
		var ch := text.substr(i, 1).to_lower()
		if ch >= "a" and ch <= "z":
			out += ch
	return out


## Is `part` a subsequence of `whole` (letters kept in order, some dropped)?
static func _subsequence(part: String, whole: String) -> bool:
	var j := 0
	for i in whole.length():
		if j < part.length() and whole[i] == part[j]:
			j += 1
	return j == part.length()


# ---------------------------------------------------------------- the data

func test_letter_choir_is_valid_with_its_own_sets() -> void:
	assert_true(Movies.has(ID), "registered")
	var bad := Movies.validate(ID, Stage2D.SETS)
	assert_true(bad.is_empty(), "validate with the stage's sets: %s" % ", ".join(bad))
	bad = Movies.validate(ID)
	assert_true(bad.is_empty(), "validate with no known sets: %s" % ", ".join(bad))
	var m := _movie()
	assert_eq(String(m["chapter"]), "nora", "Day 4's movie")
	assert_eq(String(m["narrator"]), "Hoot", "Hoot narrates")
	assert_eq(String(m.get("stage", "")), SETS_PATH, "the stage line points at its sets script")
	assert_between(Movies.total_s(ID), Movies.MIN_TOTAL_S, Movies.MAX_TOTAL_S, "45-110 s")
	assert_false(Movies.is_short(ID), "a full movie, not a recap")
	# exactly its eight sets, none of them a stage set, one scene each
	assert_eq(Movies.own_sets(ID), SET_IDS, "own_sets is exactly the eight sets")
	for sid: StringName in SET_IDS:
		assert_false(Stage2D.SETS.has(sid), "%s is not a stage set" % sid)
		assert_true(Sets.new().has_method("_set_%s" % sid), "_set_%s()" % sid)
	var used: Array[StringName] = []
	for sc: Dictionary in m["scenes"]:
		used.append(StringName(String(sc["set"])))
	assert_eq(used, SET_IDS, "one scene per set, in the movie's order")
	var seen_at_found := false
	for sc: Dictionary in m["scenes"]:
		seen_at_found = seen_at_found or String(sc["id"]) == String(m.get("seen_at", ""))
	assert_true(seen_at_found, "seen_at is a scene")


func test_letter_choir_scenes_keep_the_house_rules() -> void:
	var cue_max := float((load("res://story/explainers/explainer_player.gd") as GDScript).get_script_constant_map()["CUE_MAX_DB"])
	for sc: Dictionary in _movie()["scenes"]:
		var sid := String(sc["id"])
		var d := float(sc["duration"])
		assert_true(String(sc.get("teaches", "")) != "", "%s teaches one idea" % sid)
		assert_true(String(sc.get("board", "")) != "", "%s has its art brief" % sid)
		var caps: Array = sc["captions"]
		var at: Array = sc.get("caption_at", [])
		assert_eq(at.size(), caps.size(), "%s: a start time per caption" % sid)
		for i in caps.size():
			var c := String(caps[i])
			assert_true(Movies.word_count(c) <= Movies.MAX_CAPTION_WORDS, "%s: 18 words or fewer: %s" % [sid, c])
			for w: String in NEVER_SAID:
				assert_false(c.to_lower().contains(w), "%s: Hoot never names a diagnosis" % sid)
			assert_false(c.contains("{key:"), "%s: no key named in a caption" % sid)
			assert_between(float(at[i]), 0.0, d, "%s: caption %d starts inside the scene" % [sid, i])
			if i > 0:
				assert_true(float(at[i]) > float(at[i - 1]), "%s: captions in order" % sid)
		# its card (the fallback when the set is not drawn), and its own data under its set's key
		var p: Dictionary = sc.get("params", {})
		assert_true(String(p.get("heading", "")).length() <= 30, "%s: a short card heading" % sid)
		var lines: Array = p.get("lines", [])
		assert_between(lines.size(), 1, Movies.CARD_MAX_LINES, "%s: 1-4 card lines" % sid)
		for ln: Variant in lines:
			assert_true(String(ln).length() <= Movies.CARD_MAX_CHARS, "%s: card line %s" % [sid, ln])
		assert_has(Stage2D.CARD_ICONS, String(p.get("icon", "?")), "%s: a card icon" % sid)
		assert_true(Color.html_is_valid(String(p.get("tint", ""))), "%s: a card tint" % sid)
		var own: Variant = p.get(String(sc["set"]), null)
		assert_true(own is Dictionary and not (own as Dictionary).is_empty(), "%s: its data under params.%s" % [sid, sc["set"]])
		if own is Dictionary:
			for k: String in CARD_KEYS:
				assert_false((own as Dictionary).has(k), "%s: card key %s stays on the card" % [sid, k])
		for cue: Dictionary in sc.get("cues", []):
			assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s: a known Sfx" % sid)
			assert_true(float(cue.get("vol_db", 0.0)) <= -8.0, "%s: %s is quiet" % [sid, cue["sfx"]])
			assert_true(float(cue.get("vol_db", 0.0)) <= cue_max, "%s: under the player's cap" % sid)
			assert_between(float(cue["t"]), 0.0, d, "%s: %s fires inside the scene" % [sid, cue["sfx"]])


## (Steve) Scene 1 opens like Day 2's movie: the marquee holds while Hoot asks the question (caption 1)
## and names the answer and why we need it (caption 2), two short question chips under it; then the
## choir, about 6 s longer than the scene was without the hold.
func test_letter_choir_lead_in() -> void:
	var scenes: Array = _movie()["scenes"]
	var first: Dictionary = scenes[0]
	var p: Dictionary = first["params"]
	var hold := float(p.get("card_hold", 0.0))
	assert_true(hold >= 6.0, "scene 1 holds its card (%.1f s)" % hold)
	assert_has(Movies.own_sets(ID), StringName(String(first["set"])), "scene 1 is the movie's own set")
	var qs: Array = p.get("questions", [])
	assert_eq(qs.size(), 2, "two question chips")
	for q: Variant in qs:
		assert_true(String(q).length() <= QUESTION_MAX_CHARS, "a short chip: %s" % q)
		assert_true(String(q).ends_with("?"), "a question: %s" % q)
	var caps: Array = first["captions"]
	assert_true(caps.size() >= 3, "question, answer, then the scene's own caption")
	assert_true(String(caps[0]).begins_with(MATINEE), "caption 1 opens the matinee: %s" % caps[0])
	assert_true(String(caps[0]).ends_with("?"), "caption 1 asks: %s" % caps[0])
	assert_true(String(caps[1]).contains("WORD SCORE"), "caption 2 names the answer: %s" % caps[1])
	assert_true(String(caps[1]).contains("because"), "caption 2 says why we need it: %s" % caps[1])
	var at: Array = first["caption_at"]
	assert_true(float(at[1]) < hold, "the answer is said while the card holds")
	assert_true(float(at[2]) >= hold - 0.5, "the choir's caption comes with the choir")
	assert_true(float(first["duration"]) >= hold + 6.0, "the choir still has its own time after the hold")
	# the stage enters it like Day 2's: curtains, no iris, the scene chip after the card
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", _movie())
	for sc: Dictionary in scenes:
		st.call("show_scene", sc)
		assert_eq(bool(st.call("_card_scene")), sc == first, "%s: only scene 1 is a title-card scene" % sc["id"])
	st.queue_free()


## Before its sets script existed (W5a's cards-only data) every scene played as its card: the same data
## without the "stage" line still validates with no known sets and draws, every scene as its card.
func test_letter_choir_cards_only_fallback() -> void:
	var m := _movie()
	m.erase("stage")
	m["id"] = CARDS_ONLY_ID
	Movies.extra[CARDS_ONLY_ID] = m
	var bad := Movies.validate(CARDS_ONLY_ID)
	assert_true(bad.is_empty(), "cards-only validates: %s" % ", ".join(bad))
	assert_false(Movies.validate(CARDS_ONLY_ID, Stage2D.SETS).is_empty(), "without its sets script the stage does not know the sets")
	assert_true(Movies.own_sets(CARDS_ONLY_ID).is_empty(), "no own sets")
	var st := CountingStage.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.use_movie(m)
	assert_true(st._movie_sets == null, "no sets script loaded")
	for sc: Dictionary in m["scenes"]:
		st.show_scene(sc)
		for tt: float in [0.5, float(sc["duration"]) * 0.6]:
			st.t = tt
			st.depth = 0
			var before := st.draws
			st.queue_redraw()
			await wait_frames(1)
			assert_true(st.draws > before, "%s drawn as its card" % sc["id"])
			assert_eq(st.depth, 0, "%s: card pushes and pops match" % sc["id"])
	Movies.extra.erase(CARDS_ONLY_ID)
	st.queue_free()


# ---------------------------------------------------------------- the drawing

## Every scene draws through its own set at many moments (scene 1 also around the end of its card
## hold), with full and with reduced motion: no script error, every push popped, and the stage's t
## put back after the choir runs on the shifted clock.
func test_letter_choir_draws_every_scene() -> void:
	var m := _movie()
	var st := CountingStage.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.use_movie(m)
	assert_true(st._movie_sets != null, "its sets script is loaded")
	for reduced: bool in [false, true]:
		Game.settings["reduced_motion"] = reduced
		for sc: Dictionary in m["scenes"]:
			st.show_scene(sc)
			var sid := String(sc["id"])
			assert_true(bool(st._movie_sets.call("has_set", StringName(String(sc["set"])))), "%s: its own set draws it" % sid)
			var d := float(sc["duration"])
			var times: Array[float] = [0.0, 0.4, d * 0.2, d * 0.4, d * 0.6, d * 0.8, d - 0.05, d + 1.5]
			var hold := float((sc["params"] as Dictionary).get("card_hold", 0.0))
			if hold > 0.0:
				times.append_array([hold - 0.5, hold + 0.2, hold + 2.5, hold + 4.5])
			for tt: float in times:
				st.t = tt
				st.depth = 0
				st.underflow = 0
				var before := st.draws
				st.queue_redraw()
				await wait_frames(1)
				var tag := "%s at %.1f s%s" % [sid, tt, " (reduced motion)" if reduced else ""]
				assert_true(st.draws > before, "%s: drawn" % tag)
				assert_eq(st.depth, 0, "%s: every push popped" % tag)
				assert_eq(st.underflow, 0, "%s: no pop without a push" % tag)
				assert_near(st.t, tt, 0.0001, "%s: the stage's t put back" % tag)
	st.queue_free()


## The sets are a pure function of t: no randomness, clocks, tweens, nodes or sounds of their own,
## and no Day 4 UI code (the numbers are copied in as data and pinned below).
func test_letter_choir_sets_are_pure() -> void:
	var src := FileAccess.get_file_as_string(SETS_PATH)
	assert_true(src.length() > 0, "the sets script reads")
	var code := ""   # the code only: comments may name what the sets do not use
	for line: String in src.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var cut := line.find(" # ")
		code += (line.substr(0, cut) if cut >= 0 else line) + "\n"
	for word: String in IMPURE:
		assert_false(code.contains(word), "the sets never use %s" % word)


# ---------------------------------------------------------------- the facts it teaches

## The singers stand where SpeechRules puts the sounds, and the curtain hides exactly the sounds the
## word test's own maths says a threshold hides.
func test_letter_choir_banana_is_speech_rules() -> void:
	for key: String in Sets.CUES:
		assert_has(SpeechRules.SOUND_CUES, key, "%s is a SpeechRules sound" % key)
		var want: Array = SpeechRules.SOUND_CUES.get(key, [])
		var got: Array = Sets.CUES[key]
		assert_eq([int(got[0]), int(got[1])], [int(want[0]), int(want[1])], "%s sits at its SOUND_CUES spot" % key)
	for key: String in Sets.HIGH_SOFT:
		assert_has(Sets.CUES, key, "%s is on the chart" % key)
	var dial := float(_data("banana")["dial"])
	assert_eq(int(dial), SpeechRules.CHAT_DB, "the banana is a chatting voice")
	assert_eq(int(_data("curtain")["dial"]), SpeechRules.CHAT_DB, "the curtain's banana is the same one")
	var th: Dictionary = _data("curtain")["thresholds"]
	assert_eq(_data("louder")["thresholds"], th, "the louder scene keeps the same curtain")
	var fs: Array = th.keys()
	fs.sort()
	for i in fs.size() - 1:
		assert_true(int(th[fs[i + 1]]) >= int(th[fs[i]]), "a high-pitch loss: the line slopes down to the right")
	for d: float in [50.0, 60.0, 70.0, 85.0]:
		for key: String in Sets.CUES:
			var hidden := SpeechRules.sound_margin(key, d, th) < 0.0
			assert_eq(Sets._hidden(key, d, th), hidden, "%s at %d dB: behind the curtain as SpeechRules says" % [key, int(d)])
	for key: String in Sets.HIGH_SOFT:
		assert_true(Sets._hidden(key, dial, th), "%s hides behind the curtain (the chip says so)" % key)
	assert_false(Sets._hidden("vowel", dial, th), "the vowels still sing")


## Louder: the slide is the word test's own step above the PTA, most singers come out but f and th
## stay hidden (the chips say so), and nothing reaches the "too loud" strip.
func test_letter_choir_louder_is_loud_enough_never_too_loud() -> void:
	var p := _data("louder")
	var d0 := int(p["from_dial"])
	var d1 := int(p["to_dial"])
	assert_eq(d0, SpeechRules.CHAT_DB, "it starts from the chatting voice")
	assert_eq(d1 - d0, SpeechRules.WRS_ABOVE_PTA_DB, "the slide is WRS_ABOVE_PTA_DB")
	assert_true(d1 >= SpeechRules.WRS_MIN_DB, "at least the word test's lowest level")
	var th: Dictionary = p["thresholds"]
	var out := 0
	for key: String in Sets.CUES:
		if not Sets._hidden(key, d1, th):
			out += 1
		assert_true(d1 + int((Sets.CUES[key] as Array)[1]) < Sets.TOO_LOUD_DB, "%s stays out of the too-loud strip" % key)
	assert_true(out * 2 > Sets.CUES.size(), "most singers step out (%d of %d)" % [out, Sets.CUES.size()])
	assert_true(out < Sets.CUES.size(), "most, not all")
	assert_true(Sets._hidden("f", d1, th) and Sets._hidden("th", d1, th), "f and th still hide")
	assert_false(Sets._hidden("s", d1, th), "s steps out")
	assert_true(Sets.TOO_LOUD_DB > d1, "the voice never reaches the strip")


func test_letter_choir_choir_and_mush() -> void:
	var c := _data("choir")
	var word := String(c["word"])
	var spelled := ""
	var vowels := 0
	for pair: Array in c["singers"]:
		spelled += String(pair[0])
		var key := String(pair[1])
		assert_has(SpeechRules.SOUND_CUES, key, "singer %s is a SpeechRules sound" % pair[0])
		assert_has(Sets.CUES, key, "singer %s has its spot on the staff" % pair[0])
		if key == "vowel":
			vowels += 1
			assert_true("aeiou".contains(String(pair[0])), "the vowel singer is a vowel")
		else:
			assert_true(int((Sets.CUES[key] as Array)[0]) > int((Sets.CUES["vowel"] as Array)[0]), "%s sings higher than the vowel" % key)
			assert_true(int((Sets.CUES[key] as Array)[1]) < int((Sets.CUES["vowel"] as Array)[1]), "%s sings softer than the vowel" % key)
	assert_eq(spelled.to_upper(), word, "the singers spell the word")
	assert_eq(vowels, 1, "one big vowel")
	var m := _data("mush")
	var said := String(m["said"])
	var heard := String(m["heard"])
	assert_eq(_vowels(heard), _vowels(said), "every vowel gets through")
	var lost := Sets._lost_letters(said, heard)
	assert_eq(heard.count("_"), lost.size(), "one gap per lost consonant")
	assert_true(lost.size() > 0, "some consonants are lost")
	for ch: String in lost:
		assert_false("aeiou".contains(ch), "only consonants are lost: %s" % ch)
	assert_true(_subsequence(_letters(heard), _letters(said)), "what reaches her is his line with letters dropped")


func test_letter_choir_crossing_and_count() -> void:
	var x := _data("crossing")
	assert_eq(int(x["ia"]), SpeechRules.SPEECH_IA_DB[&"phones"], "on-ear phones: the game's interaural attenuation")
	assert_true(String(x["test_ear"]) in ["left", "right"] and String(x["mask_ear"]) in ["left", "right"], "two real ears")
	assert_true(String(x["test_ear"]) != String(x["mask_ear"]), "the noise goes in the other ear")
	assert_true(SpeechRules.speech_masking_needed(int(x["level"]), 0.0, &"phones"), "the crossing copy reaches a good ear")
	var n := _data("count")
	var tiles := int(n["tiles"])
	var misses: Array = n["misses"]
	assert_eq(tiles, SpeechRules.WRS_WORDS, "the word test's 25 words")
	var distinct: Dictionary = {}
	for i: Variant in misses:
		assert_between(int(i), 0, tiles - 1, "a miss on the board")
		distinct[int(i)] = true
	assert_eq(distinct.size(), misses.size(), "each miss once")
	assert_eq(int(n["right"]), tiles - misses.size(), "the ticks add up")
	assert_eq(int(round(100.0 * int(n["right"]) / tiles)), 88, "22 of 25 is 88%")
	assert_eq(int(round(100.0 / tiles)), 4, "each word is 4%")
	var ex: Array = n["example"]
	assert_eq(ex.size(), 2, "said and heard")
	assert_true(String(ex[0]) != String(ex[1]) and String(ex[0]).right(3) == String(ex[1]).right(3), "the miss is a rhyme")
