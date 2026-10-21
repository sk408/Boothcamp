extends TestCase
## Day 3's explainer, Hoot's spondee movie "The Spondee Ladder" (story/explainers/movies/srt_ladder.gd,
## its sets story/explainers/stages/srt_ladder_sets.gd; clinical review S7 / A3, CONTRACTS.md §3.4 and
## §9.20). Tested by id, the shape of test_movie_letter_choir.gd: valid for the shared player with its
## own eight sets, Steve's lead-in on scene 1, every scene drawn at several moments with and without
## reduced motion, the cards-only fallback, only our own spondees, and the facts it teaches pinned to
## SpeechRules. The level that plays it (and its announcement) comes in a later step on Day 3's line.

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const ProbeStage := preload("res://core/tests/probe_movie_stage.gd")
## The published spondee lists already guarded there (never copied into another file).
const SpeechCore := preload("res://core/tests/test_speech_core.gd")
const SETS_PATH := "res://story/explainers/stages/srt_ladder_sets.gd"
const Sets := preload(SETS_PATH)

const ID := "srt_ladder"
const SET_IDS: Array[StringName] = [&"spondees", &"edge", &"half", &"ladder", &"practice", &"agree", &"mismatch", &"recap"]
## (Steve) the lead-in, the shape of Day 2's masking movie
const MATINEE := "Hoot's Movie Matinee! Today's mystery:"
const QUESTION_MAX_CHARS := 30
const CARD_KEYS: Array[String] = ["heading", "lines", "icon", "tint"]
## Hoot never names a diagnosis, never accuses, and never asks anyone to listen (text first).
const NEVER_SAID: Array[String] = ["tumour", "tumor", "neuroma", "non-organic", "malinger", "faking", "liar", "lying", "fib", "listen"]
## Published speech tests the movie must never name (whole words, case as written).
const PUBLISHED: Array[String] = ["NU-6", "W-22", "CID", "PB-50", "AB", "NU-CHIPS", "WIPI", "MRT", "HINT", "BKB", "IEEE",
	"Harvard", "QuickSIN", "WIN", "BKB-SIN", "SPIN", "AzBio"]
## A few of our own spondees at most.
const MAX_WORDS := 3
## Things a set must never do (a pure function of t; sounds only in the movie's cues; numbers as data).
const IMPURE: Array[String] = ["randf", "randi", "RandomNumberGenerator", "Time.", "create_tween", "add_child",
	"get_tree", "Sfx.", "AudioStream", "SpeechRules", "SpeechMaterial", "SpeechVoice", "SpLadder", "res://ui/"]
const CARDS_ONLY_ID := "mv3_srt_ladder_cards"
const LIST_ID := "spondee_a"


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


func _caps(id: String) -> Array:
	return _scene(id).get("captions", [])


## Every string in v (keys and values, all the way down).
static func _strings(v: Variant, out: PackedStringArray) -> void:
	if v is String or v is StringName:
		out.append(String(v))
	elif v is Array:
		for x: Variant in v:
			_strings(x, out)
	elif v is Dictionary:
		for k: Variant in v:
			_strings(k, out)
			_strings((v as Dictionary)[k], out)


static func _has_word(text: String, word: String) -> bool:
	var re := RegEx.create_from_string("\\b%s\\b" % word)
	return re.search(text) != null


static func _code_of(path: String) -> String:
	var code := ""   # the code only: comments may name what the sets do not use
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		var cut := line.find(" # ")
		code += (line.substr(0, cut) if cut >= 0 else line) + "\n"
	return code


## The string literals of a script's code.
static func _literals(code: String) -> PackedStringArray:
	var out := PackedStringArray()
	var re := RegEx.create_from_string("\"([^\"\\\\]*)\"")
	for m: RegExMatch in re.search_all(code):
		out.append(m.get_string(1))
	return out


## Lower case, letters only (the guard's match ignores case, spaces and hyphens).
static func _plain(w: String) -> String:
	var out := ""
	for ch: String in w.to_lower():
		if ch >= "a" and ch <= "z":
			out += ch
	return out


## Every word of `text`, and every two neighbours joined ("light house", "LIGHT-HOUSE" -> lighthouse).
static func _word_keys(text: String) -> PackedStringArray:
	var words := PackedStringArray()
	var cur := ""
	for ch: String in text.to_lower():
		if ch >= "a" and ch <= "z":
			cur += ch
		elif cur != "":
			words.append(cur)
			cur = ""
	if cur != "":
		words.append(cur)
	var out := words.duplicate()
	for i in words.size() - 1:
		out.append(words[i] + words[i + 1])
	return out


## The SRT dots of the halfway board as trials ({db, correct}), row by row.
func _half_trials() -> Array:
	var trials: Array = []
	for row: Array in _data("half")["rows"]:
		var marks := String(row[1])
		for j in marks.length():
			trials.append({"db": int(row[0]), "correct": marks.substr(j, 1) == "Y"})
	return trials


# ---------------------------------------------------------------- the data

func test_srt_ladder_is_valid_with_its_own_sets() -> void:
	assert_true(Movies.has(ID), "registered")
	var bad := Movies.validate(ID, Stage2D.SETS)
	assert_true(bad.is_empty(), "validate with the stage's sets: %s" % ", ".join(bad))
	bad = Movies.validate(ID)
	assert_true(bad.is_empty(), "validate with no known sets: %s" % ", ".join(bad))
	var m := _movie()
	assert_eq(String(m["chapter"]), "mike", "Day 3's movie")
	assert_eq(String(m["narrator"]), "Hoot", "Hoot narrates")
	assert_eq(String(m["title"]), "Hoot's spondee movie", "its replay name")
	assert_eq(String(m["subtitle"]), "The Spondee Ladder", "its subtitle")
	assert_eq(String(m.get("stage", "")), SETS_PATH, "the stage line points at its sets script")
	assert_between(Movies.total_s(ID), Movies.MIN_TOTAL_S, Movies.MAX_TOTAL_S, "45-110 s")
	assert_near(Movies.total_s(ID), 80.0, 0.001, "80 s, the 6 s lead-in included")
	assert_false(Movies.is_short(ID), "a full movie, not a recap")
	# exactly its eight sets, none of them a stage set, one scene each
	assert_eq(Movies.own_sets(ID), SET_IDS, "own_sets is exactly the eight sets")
	var probe: Object = Sets.new()
	for sid: StringName in SET_IDS:
		assert_false(Stage2D.SETS.has(sid), "%s is not a stage set" % sid)
		assert_true(probe.has_method("_set_%s" % sid), "_set_%s()" % sid)
	var used: Array[StringName] = []
	for sc: Dictionary in m["scenes"]:
		used.append(StringName(String(sc["set"])))
	assert_eq(used, SET_IDS, "one scene per set, in the movie's order")
	var seen_at_found := false
	for sc: Dictionary in m["scenes"]:
		seen_at_found = seen_at_found or String(sc["id"]) == String(m.get("seen_at", ""))
	assert_true(seen_at_found, "seen_at is a scene")


## Mike's chapter exists, so the movie is in the replay lists and in Day 3's pause menu, labelled Day 3.
func test_srt_ladder_is_listed_for_day_3() -> void:
	assert_false(Game.chapter("mike").is_empty(), "Day 3 exists")
	assert_has(Movies.replay_ids(), ID, "on the title's Hoot's Movies list")
	var only: Array[String] = [ID]
	assert_eq(Movies.for_chapter("mike"), only, "Day 3's pause menu offers it")
	assert_eq(Movies.day_label(ID), "Day 3", "its day chip")
	var ids := Movies.ids()
	assert_true(ids.find(ID) > ids.find("masking") and ids.find(ID) < ids.find("letter_choir"), "listed between Day 2's and Day 4's")


func test_srt_ladder_scenes_keep_the_house_rules() -> void:
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
				assert_false(_has_word(c.to_lower(), w), "%s: Hoot never says %s" % [sid, w])
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
## balance beams, about 6 s longer than the scene was without the hold.
func test_srt_ladder_lead_in() -> void:
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
	assert_true(String(caps[0]).contains("beeps") and String(caps[0]).contains("words"), "the mystery: words when we have beeps")
	assert_true(String(caps[1]).contains("SRT"), "caption 2 names the answer: %s" % caps[1])
	assert_true(String(caps[1]).contains("because"), "caption 2 says why we need it: %s" % caps[1])
	var at: Array = first["caption_at"]
	assert_true(float(at[1]) < hold, "the answer is said while the card holds")
	assert_true(float(at[2]) >= hold - 0.5, "the beams' caption comes with the beams")
	assert_true(float(first["duration"]) >= hold + 6.0, "the beams still have their own time after the hold")
	# the stage enters it like Day 2's: curtains, no iris, the scene chip after the card
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", _movie())
	for sc: Dictionary in scenes:
		st.call("show_scene", sc)
		assert_eq(bool(st.call("_card_scene")), sc == first, "%s: only scene 1 is a title-card scene" % sc["id"])
	st.queue_free()


## The hold shifts the STAGE's clock for the beams (what _k / _pop / _ring and every s._* helper read)
## by card_hold - 2 s, and puts it back before the stage's iris and scene chip (the check of
## core/tests/test_speech_seams.gd on Days 4-5's movies).
func test_srt_ladder_card_hold_shifts_the_stage_clock() -> void:
	var m := _movie()
	var sc: Dictionary = (m["scenes"] as Array)[0]
	var hold := float((sc["params"] as Dictionary)["card_hold"])
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
		reads_shifted = reads_shifted or absf(float(v) - shifted) < 0.001
	assert_false(seen.is_empty(), "scene 1 was drawn")
	assert_true(reads_shifted, "the beams read the stage's t shifted by card_hold - 2 s")
	assert_near(float(st.get("t")), real_t, 0.001, "the stage's t is put back")
	st.queue_free()


## Without its sets script every scene plays as its card: the same data without the "stage" line still
## validates with no known sets and draws, every scene as its card.
func test_srt_ladder_cards_only_fallback() -> void:
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


# ---------------------------------------------------------------- our own words only

## Every word it shows is one of spondee_a.json's own (a few at most, the two halves as the list splits
## them); nothing in the data or the sets' strings is a word of a published spondee list (the guard's
## lists in core/tests/test_speech_core.gd), and no published test is named.
func test_srt_ladder_says_only_our_own_words() -> void:
	var ours: Dictionary = {}
	for it: Dictionary in SpeechMaterial.items(LIST_ID):
		ours[String(it["text"])] = it.get("parts", [])
	var shown: Dictionary = {}
	for pair: Array in _data("spondees")["words"]:
		var w := String(pair[0]) + String(pair[1])
		assert_has(ours, w, "%s is one of ours" % w)
		assert_eq(pair, ours.get(w, []), "%s split as the list splits it" % w)
		shown[w] = true
	var edge: Array = _data("edge")["word"]
	var ew := String(edge[0]) + String(edge[1])
	assert_has(ours, ew, "the soft word is one of ours")
	assert_eq(edge, ours.get(ew, []), "split as the list splits it")
	assert_eq(_plain(String(_data("edge")["guess"])), ew, "the guess is the whole word")
	shown[ew] = true
	for w: Variant in _data("practice")["words"]:
		assert_has(ours, String(w), "%s is one of ours" % w)
		shown[String(w)] = true
	# the captions' hyphenated words too (LIGHT-HOUSE)
	var hy := RegEx.create_from_string("([A-Za-z]+)-([A-Za-z]+)")
	for sc: Dictionary in _movie()["scenes"]:
		for c: Variant in sc["captions"]:
			for mt: RegExMatch in hy.search_all(String(c)):
				var joined := _plain(mt.get_string(1) + mt.get_string(2))
				if ours.has(joined):
					shown[joined] = true
	assert_true(shown.size() <= MAX_WORDS, "a few words at most: %s" % [shown.keys()])
	# nothing from a published list, and no published test by name
	var banned: Dictionary = {}
	for words: PackedStringArray in [SpeechCore.ASHA_A, SpeechCore.ASHA_B, SpeechCore.ASHA_C, SpeechCore.CID_W1]:
		for w: String in words:
			banned[_plain(w)] = w
	assert_true(banned.size() > 50, "the guard's lists are there")
	var all := PackedStringArray()
	_strings(_movie(), all)
	var code := _code_of(SETS_PATH)
	all.append_array(_literals(code))
	for text: String in all:
		for key: String in _word_keys(text):
			assert_false(banned.has(key), "%s is a published spondee: %s" % [key, text])
	var said := "\n".join(all)
	for w: String in PUBLISHED:
		assert_false(_has_word(said, w), "the movie never names %s" % w)
		assert_false(_has_word(code, w), "the sets never draw %s" % w)


# ---------------------------------------------------------------- the drawing

## Every scene draws through its own set at many moments (scene 1 also around the end of its card
## hold), with full and with reduced motion: no script error, every push popped, and the stage's t
## put back after the beams run on the shifted clock.
func test_srt_ladder_draws_every_scene() -> void:
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
## and no speech rules or SPEECH screen code (the numbers are copied in as data and pinned below).
func test_srt_ladder_sets_are_pure() -> void:
	var code := _code_of(SETS_PATH)
	assert_true(code.length() > 0, "the sets script reads")
	for word: String in IMPURE:
		assert_false(code.contains(word), "the sets never use %s" % word)


# ---------------------------------------------------------------- the facts it teaches

## Spondees and familiarisation say what the day does: two-part words with equal stress, said aloud
## first, by ear.
func test_srt_ladder_spondees_and_familiarising() -> void:
	var c := String(_caps("spondees")[2])
	assert_true(c.contains("two-part") and c.contains("equally"), "spondees: two parts, equal stress: %s" % c)
	assert_true(String(_caps("edge")[0]).contains("edge of hearing"), "easy to guess at the edge of hearing")
	var f := " ".join(PackedStringArray(_caps("practice")))
	assert_true(f.contains("familiarise") and f.contains("aloud"), "Hoot says each word aloud first: %s" % f)
	assert_true(f.contains("By ear") and f.contains("never by reading"), "by ear, not by reading (clinical review S3)")


## The halfway board: the SRT it stamps is what SpeechRules finds in its dots (the softest level with
## at least two right and at least half, bracketed by a level under half), and caption 2 reads it.
func test_srt_ladder_half_is_speech_rules() -> void:
	var h := _data("half")
	var srt := int(h["srt"])
	var rows: Array = h["rows"]
	assert_eq(SpeechRules.srt_candidate(_half_trials()), srt, "the stamp is the SRT the dots support")
	var below := -1
	for r in rows.size():
		var row: Array = rows[r]
		if r > 0:
			assert_eq(int(row[0]), int((rows[r - 1] as Array)[0]) - SpeechRules.LEVEL_STEP_DB, "one row per 5 dB, louder at the top")
		if int(row[0]) == srt:
			var marks := String(row[1])
			assert_true(marks.count("Y") * 2 == marks.length(), "about half: exactly half right at the SRT")
			below = r + 1
	assert_true(below > 0 and below < rows.size(), "a softer row brackets it")
	var cap := String(_caps("half")[1])
	assert_true(cap.contains("at %d dB" % srt) and cap.ends_with("the SRT is %d." % srt), "caption 2 reads the stamp: %s" % cap)
	assert_true(cap.contains("at %d:" % int((rows[below] as Array)[0])), "and the row under it: %s" % cap)
	assert_true(String(_caps("half")[0]).contains("about half"), "the definition says about half")


## (Clinical review S5) The ladder is the game's own steps, and Hoot calls it one common way.
func test_srt_ladder_ladder_is_the_games_steps() -> void:
	var l := _data("ladder")
	assert_eq(int(l["down"]), SpeechRules.SRT_DOWN_DB, "down 10 after a right word")
	assert_eq(int(l["up"]), SpeechRules.SRT_UP_DB, "up 5 after a miss")
	var top := int(l["top"])
	var bottom := int(l["bottom"])
	assert_true(top % SpeechRules.LEVEL_STEP_DB == 0 and bottom % SpeechRules.LEVEL_STEP_DB == 0, "rungs on the 5 dB steps")
	var db := int(l["start"])
	var ups := 0
	var downs := 0
	for a: Variant in l["answers"]:
		assert_between(db, bottom, top, "Hoot stays on the ladder (%d)" % db)
		var next := SpeechRules.srt_next_level(db, bool(a))
		assert_eq(SpeechRules.srt_step_verdict(db, bool(a), next), &"textbook", "a textbook step from %d" % db)
		ups += 1 if next > db else 0
		downs += 1 if next < db else 0
		db = next
	assert_between(db, bottom, top, "and ends on it (%d)" % db)
	assert_true(ups > 0 and downs > 0, "both kinds of step are shown")
	var caps: Array = _caps("ladder")
	assert_true(String(caps[0]).contains("down %d dB" % SpeechRules.SRT_DOWN_DB) and String(caps[0]).contains("up %d" % SpeechRules.SRT_UP_DB), "caption 1 says the steps: %s" % caps[0])
	assert_true(String(caps[1]).contains("one common way") and String(caps[1]).contains("not the only one"), "one common way, not the only one: %s" % caps[1])


## Agreement within 6 dB (the game's own band, AGREE_GOOD_DB, as beat 7b and the paper grade it); better
## words than beeps (poor) re-instructed and rechecked until they agree, kindly; worse words (poor) mean
## checking the instructions and the language.
func test_srt_ladder_agreement_is_speech_rules() -> void:
	var a := _data("agree")
	var within := int(a["within"])
	assert_eq(within, SpeechRules.AGREE_GOOD_DB, "the game's good band")
	assert_true(absi(int(a["srt"]) - int(a["pta"])) <= within, "the agreeing pair sits inside the band")
	assert_has([&"good", &"fair"], SpeechRules.agreement(int(a["srt"]), float(a["pta"])), "SpeechRules agrees they agree")
	assert_true(String(_caps("agree")[0]).contains("within %d dB" % within), "the caption says it")
	var m := _data("mismatch")
	assert_eq(int(m["within"]), within, "the same band")
	var b: Dictionary = m["better"]
	assert_true(int(b["srt"]) < int(b["pta"]), "better words: a lower (softer) SRT than the tone average")
	assert_eq(SpeechRules.agreement(int(b["srt"]), float(b["pta"])), &"poor", "much better: poor agreement")
	assert_true(absi(int(b["srt"]) - int(b["recheck"])) <= within, "the recheck agrees")
	assert_true(SpeechRules.agreement(int(b["srt"]), float(b["recheck"])) != &"poor", "SpeechRules agrees the recheck agrees")
	var w: Dictionary = m["worse"]
	assert_true(int(w["srt"]) > int(w["pta"]), "worse words: a higher SRT")
	assert_eq(SpeechRules.agreement(int(w["srt"]), float(w["pta"])), &"poor", "much worse: poor agreement")
	var caps: Array = _caps("mismatch")
	assert_true(String(caps[0]).contains("re-instruct") and String(caps[0]).contains("recheck") and String(caps[0]).contains("Never accuse"), "kindly, never accuse: %s" % caps[0])
	assert_true(String(caps[1]).contains("instructions") and String(caps[1]).contains("language"), "instructions and language: %s" % caps[1])
