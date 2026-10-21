extends TestCase
## Day 5's explainer, Hoot's party movie "The Party Problem" (story/explainers/movies/party_noise.gd,
## its sets story/explainers/stages/party_noise_sets.gd; docs/CHAPTER5.md §4, CONTRACTS.md §9.20).
## Tested by id: valid for the shared player with its own eight sets, Steve's lead-in on scene 1,
## every scene drawn at several moments with and without reduced motion, the cards-only fallback,
## and the facts it teaches pinned to SpeechRules (clinical review A7: the typical diner's band is
## "Near-normal", never "Small"). The level that plays it (and its announcement) belongs to Day 5's
## own branch and is tested there.

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const ProbeStage := preload("res://core/tests/probe_movie_stage.gd")
const SETS_PATH := "res://story/explainers/stages/party_noise_sets.gd"
const Sets := preload(SETS_PATH)

const ID := "party_noise"
const SET_IDS: Array[StringName] = [&"quiet", &"crowd", &"scale", &"knob", &"gap", &"menu", &"receipt", &"tonight"]
## (Steve) the lead-in, the shape of Day 2's masking movie
const MATINEE := "Hoot's Movie Matinee! Today's mystery:"
const QUESTION_MAX_CHARS := 30
const CARD_KEYS: Array[String] = ["heading", "lines", "icon", "tint"]
## Hoot never names a diagnosis, and never asks anyone to listen (text first).
const NEVER_SAID: Array[String] = ["tumour", "tumor", "neuroma", "listen", "hear the gap"]
## Published speech-in-noise tests the movie must never name or copy (whole words, case as written).
const PUBLISHED: Array[String] = ["QuickSIN", "HINT", "BKB", "WIN", "SPIN", "AzBio", "IEEE", "Harvard"]
## Things a set must never do (a pure function of t; sounds only in the movie's cues; numbers as data).
const IMPURE: Array[String] = ["randf", "randi", "RandomNumberGenerator", "Time.", "create_tween", "add_child",
	"get_tree", "Sfx.", "AudioStream", "AudioSafety", "SpeechRules", "SpeechVoice", "res://ui/"]
const CARDS_ONLY_ID := "mv5_party_noise_cards"
## The player's typing speed and reading pause (explainer_player.gd CHARS_PER_SECOND, READ_S).
const PLAYER := "res://story/explainers/explainer_player.gd"


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


# ---------------------------------------------------------------- the data

func test_party_noise_is_valid_with_its_own_sets() -> void:
	assert_true(Movies.has(ID), "registered")
	var bad := Movies.validate(ID, Stage2D.SETS)
	assert_true(bad.is_empty(), "validate with the stage's sets: %s" % ", ".join(bad))
	bad = Movies.validate(ID)
	assert_true(bad.is_empty(), "validate with no known sets: %s" % ", ".join(bad))
	var m := _movie()
	assert_eq(String(m["chapter"]), "marco", "Day 5's movie")
	assert_eq(String(m["narrator"]), "Hoot", "Hoot narrates")
	assert_eq(String(m["title"]), "Hoot's party movie", "its replay name")
	assert_eq(String(m["subtitle"]), "The Party Problem", "its subtitle")
	assert_eq(String(m.get("stage", "")), SETS_PATH, "the stage line points at its sets script")
	assert_between(Movies.total_s(ID), Movies.MIN_TOTAL_S, Movies.MAX_TOTAL_S, "45-110 s")
	assert_near(Movies.total_s(ID), 71.0, 0.001, "65 s plus the 6 s lead-in")
	assert_eq(int(roundf(Movies.total_s(ID) / 10.0) * 10.0), 70, "the replay offer reads 'about 70 s'")
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
	# seen means it reached the last scene (tonight carries the "why test the party" idea)
	var scenes: Array = m["scenes"]
	assert_eq(String(m.get("seen_at", (scenes[-1] as Dictionary)["id"])), "tonight", "seen at the last scene")


func test_party_noise_scenes_keep_the_house_rules() -> void:
	var consts: Dictionary = (load(PLAYER) as GDScript).get_script_constant_map()
	var cue_max := float(consts["CUE_MAX_DB"])
	var cps := float(consts["CHARS_PER_SECOND"])
	var read_s := float(consts["READ_S"])
	for sc: Dictionary in _movie()["scenes"]:
		var sid := String(sc["id"])
		var d := float(sc["duration"])
		assert_true(String(sc.get("teaches", "")) != "", "%s teaches one idea" % sid)
		assert_true(String(sc.get("board", "")) != "", "%s has its art brief" % sid)
		assert_true(String(sc.get("title", "")) != "", "%s has its chip title" % sid)
		var caps: Array = sc["captions"]
		var at: Array = sc.get("caption_at", [])
		assert_eq(at.size(), caps.size(), "%s: a start time per caption" % sid)
		for i in caps.size():
			var c := String(caps[i])
			assert_true(Movies.word_count(c) <= Movies.MAX_CAPTION_WORDS, "%s: 18 words or fewer: %s" % [sid, c])
			for w: String in NEVER_SAID:
				assert_false(c.to_lower().contains(w), "%s: never says %s" % [sid, w])
			assert_false(c.contains("{key:"), "%s: no key named in a caption" % sid)
			assert_between(float(at[i]), 0.0, d, "%s: caption %d starts inside the scene" % [sid, i])
			# a slow reader finishes each caption before the next one starts, and inside the scene
			var done := float(at[i]) + c.length() / cps + read_s
			var next := float(at[i + 1]) if i + 1 < caps.size() else d
			assert_true(done <= next + 0.001, "%s: caption %d is typed and read in time (%.1f > %.1f)" % [sid, i, done, next])
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


## Nothing the movie says names a published test, a vendor or Marco's own results; the A7 band name
## is the only band it prints; the bill's constant never shows.
func test_party_noise_says_only_our_own_words() -> void:
	var all := PackedStringArray()
	_strings(_movie(), all)
	var code := _code_of(SETS_PATH)
	var said := "\n".join(all)
	for w: String in PUBLISHED:
		assert_false(_has_word(said, w), "the movie never names %s" % w)
		assert_false(_has_word(code, w), "the sets never draw %s" % w)
	var bill := PackedStringArray()
	_strings(_scene("receipt"), bill)
	assert_false("\n".join(bill).to_lower().contains("small"), "A7: the typical diner's band is never 'Small'")
	assert_false(_has_word(said, "Small") or _has_word(said, "SMALL"), "A7: no 'Small' band anywhere")
	assert_false(said.contains(str(SpeechRules.SIN_CONSTANT)), "the bill's constant stays the player's to find")
	assert_false(code.contains(str(SpeechRules.SIN_CONSTANT)), "the sets never print the constant")
	assert_false(said.contains("Marco"), "the movie never shows Marco's numbers or name")
	assert_true(said.contains("The Party Noise Test"), "the test has its in-game name")
	for band: StringName in [&"mild", &"moderate", &"severe"]:
		assert_false(said.contains(SpeechRules.SIN_BAND_NAMES[band].to_upper()), "no band beyond the typical diner's: %s" % band)


## (Steve) Scene 1 opens like Day 2's movie: the marquee holds while Hoot asks the question (caption 1)
## and names the answer and why we need it (caption 2), two short question chips under it; then the
## quiet cafe, about 6 s longer than the scene was without the hold.
func test_party_noise_lead_in() -> void:
	var scenes: Array = _movie()["scenes"]
	var first: Dictionary = scenes[0]
	var p: Dictionary = first["params"]
	var hold := float(p.get("card_hold", 0.0))
	assert_true(hold >= 6.0, "scene 1 holds its card (%.1f s)" % hold)
	assert_near(hold, 8.0, 0.001, "the 8 s hold of Day 2's movie")
	assert_has(Movies.own_sets(ID), StringName(String(first["set"])), "scene 1 is the movie's own set")
	var qs: Array = p.get("questions", [])
	assert_eq(qs.size(), 2, "two question chips")
	for q: Variant in qs:
		assert_true(String(q).length() <= QUESTION_MAX_CHARS, "a short chip: %s" % q)
		assert_true(String(q).ends_with("?"), "a question: %s" % q)
	var caps: Array = first["captions"]
	assert_eq(caps.size(), 3, "question, answer, then the scene's own caption")
	assert_true(String(caps[0]).begins_with(MATINEE), "caption 1 opens the matinee: %s" % caps[0])
	assert_true(String(caps[0]).ends_with("?"), "caption 1 asks: %s" % caps[0])
	assert_true(String(caps[0]).contains("quiet") and String(caps[0]).contains("busy table"), "the mystery: fine in quiet, lost at a busy table")
	assert_true(String(caps[1]).contains("SNR LOSS"), "caption 2 names the answer: %s" % caps[1])
	assert_true(String(caps[1]).contains("so we test words in noise"), "caption 2 says why we need it: %s" % caps[1])
	assert_false(String(caps[2]).begins_with("Hoot's Movie Matinee"), "the old caption lost its opener")
	var at: Array = first["caption_at"]
	assert_true(float(at[1]) < hold, "the answer is said while the card holds")
	assert_true(float(at[2]) >= hold - 0.5, "the cafe's caption comes with the cafe")
	assert_true(float(first["duration"]) >= hold + 6.0, "the cafe still has its own time after the hold")
	for i in range(1, scenes.size()):
		assert_false(((scenes[i] as Dictionary)["params"] as Dictionary).has("card_hold"), "only scene 1 holds a card")
	# the stage enters it like Day 2's: curtains, no iris, the scene chip after the card
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", _movie())
	for sc: Dictionary in scenes:
		st.call("show_scene", sc)
		assert_eq(bool(st.call("_card_scene")), sc == first, "%s: only scene 1 is a title-card scene" % sc["id"])
	st.queue_free()
	# the cafe runs on the STAGE's clock shifted by card_hold - 2 s, and the clock comes back
	var probe: Control = ProbeStage.new()
	probe.size = Vector2(880, 440)
	add_node(probe)
	probe.call("use_movie", _movie())
	probe.call("show_scene", first)
	var real_t := hold - 0.5
	probe.set("t", real_t)
	(probe.get("seen_t") as Array).clear()
	probe.queue_redraw()
	await wait_frames(2)
	var shifted := real_t - (hold - 2.0)
	var reads_shifted := false
	for v: Variant in probe.get("seen_t"):
		reads_shifted = reads_shifted or absf(float(v) - shifted) < 0.001
	assert_true(reads_shifted, "the cafe reads the stage's t shifted by card_hold - 2 s")
	assert_near(float(probe.get("t")), real_t, 0.0001, "the stage's t is put back")
	probe.queue_free()


## Before its sets script existed (the cards-only step) every scene played as its card: the same data
## without the "stage" line still validates with no known sets and draws, every scene as its card.
func test_party_noise_cards_only_fallback() -> void:
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
## put back after the cafe runs on the shifted clock.
func test_party_noise_draws_every_scene() -> void:
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
			for cue: Dictionary in sc.get("cues", []):
				times.append(float(cue["t"]) + 0.1)
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
## and no Day 5 rules or UI code (the numbers are copied in as data and pinned below).
func test_party_noise_sets_are_pure() -> void:
	var code := _code_of(SETS_PATH)
	assert_true(code.length() > 0, "the sets script reads")
	for word: String in IMPURE:
		assert_false(code.contains(word), "the sets never use %s" % word)


# ---------------------------------------------------------------- the facts it teaches

## The scale: the voice is the party test's own level and each gap it shows is one of the test's
## SNRs, shrinking; the knob turns both up by the same step and the gap does not move.
func test_party_noise_scale_and_knob() -> void:
	var sc := _data("scale")
	var voice := int(sc["voice"])
	assert_eq(voice, SpeechRules.SIN_LEVEL_DB, "the voice talks at the party test's level")
	var party: Array = sc["party"]
	var at: Array = sc["at"]
	assert_eq(at.size(), party.size(), "a landing time per step")
	var last := 999
	for i in party.size():
		var gap := voice - int(party[i])
		assert_has(SpeechRules.SIN_SNRS, gap, "SNR %d is one of the test's" % gap)
		assert_true(gap < last, "the gap shrinks as the plates land")
		last = gap
		assert_has(String((_scene("scale")["params"] as Dictionary)["lines"][i]), "SNR %d" % gap, "the card says SNR %d" % gap)
		assert_between(float(at[i]), 0.0, float(_scene("scale")["duration"]), "step %d lands inside the scene" % i)
	var kn := _data("knob")
	var v: Array = kn["voice"]
	var p: Array = kn["party"]
	assert_eq(int(v[0]) - int(p[0]), int(v[1]) - int(p[1]), "turning both up keeps the gap")
	assert_eq(int(v[1]) - int(v[0]), int(p[1]) - int(p[0]), "both go up by the same step")
	assert_true(int(v[1]) > int(v[0]), "louder")
	assert_eq(int(v[0]), SpeechRules.SIN_LEVEL_DB, "it starts at the party test's level")
	assert_has(SpeechRules.SIN_SNRS, int(v[0]) - int(p[0]), "the knob's gap is one of the test's SNRs")
	var lines: Array = (_scene("knob")["params"] as Dictionary)["lines"]
	assert_has(String(lines[-1]), str(int(v[0]) - int(p[0])), "the card names the gap that stays")


## SNR loss: typical ears follow half the words at SIN_NORMAL_SNR50_DB; the other diner needs his own
## bigger gap for half, and the party model agrees on both; the extra is his SNR loss.
func test_party_noise_gap() -> void:
	var g := _data("gap")
	var typical := float(g["typical_snr50"])
	var other := float(g["other_snr50"])
	assert_near(typical, SpeechRules.SIN_NORMAL_SNR50_DB, 0.001, "typical ears: half the words at 2 dB")
	assert_true(other > typical, "the other diner needs a bigger gap")
	var half := SpeechRules.SIN_KEY_WORDS * 0.5
	assert_near(SpeechRules.sin_expected_words(typical, 0.0), half, 0.001, "the model: typical ears get half at their gap")
	assert_near(SpeechRules.sin_expected_words(other, other - typical), half, 0.001, "the model: his SNR loss is the extra gap")
	assert_true(SpeechRules.sin_expected_words(typical, other - typical) < 1.0, "at the typical gap his words crumble")
	var words: Array = g["words"]
	var crisp: Array = g["crisp"]
	assert_eq(crisp.size() * 2, words.size(), "half the word tiles stay crisp")
	for i: Variant in crisp:
		assert_between(int(i), 0, words.size() - 1, "a crisp tile is a tile")
	var lines: Array = (_scene("gap")["params"] as Dictionary)["lines"]
	assert_has(String(lines[1]), "%d dB" % int(typical), "the card says the typical gap")


## The menu is the Party Noise Test as the SPEECH screen runs it: its courses at its SNRs, five key
## words each.
func test_party_noise_menu() -> void:
	var mn := _data("menu")
	var names: Array[String] = []
	var snrs: Array[int] = []
	for row: Array in mn["courses"]:
		names.append(String(row[0]))
		snrs.append(int(row[1]))
	assert_eq(names, SpeechRules.SIN_COURSES, "the six courses")
	assert_eq(snrs, SpeechRules.SIN_SNRS, "at the test's SNRs, 25 down to 0")
	assert_eq(int(mn["key_words"]), SpeechRules.SIN_KEY_WORDS, "five key words each")
	assert_eq(String(mn["title"]), "THE PARTY NOISE TEST", "its in-game name")
	var parts: PackedStringArray = []
	for snr: int in SpeechRules.SIN_SNRS:
		parts.append(str(snr))
	var lines: Array = (_scene("menu")["params"] as Dictionary)["lines"]
	assert_eq(String(lines[2]), "SNR " + ", ".join(parts), "the card lists the SNRs")
	assert_has(String(lines[0]), "%d sentences, %d key words" % [SpeechRules.SIN_SNRS.size(), SpeechRules.SIN_KEY_WORDS], "the card counts them")


## The bill of a diner with typical hearing: what the party model expects of him plate by plate,
## 25 right, snr_loss(25) = 0.5, band sin_band(0.5), printed as SIN_BAND_NAMES (A7: "Near-normal").
func test_party_noise_receipt() -> void:
	var r := _data("receipt")
	var courses: Array[String] = []
	courses.assign(r["courses"])
	assert_eq(courses, SpeechRules.SIN_COURSES, "the receipt's courses")
	assert_eq(int(r["key_words"]), SpeechRules.SIN_KEY_WORDS, "out of five")
	var counts: Array = r["counts"]
	var loss := float(r["loss"])
	assert_eq(counts.size(), SpeechRules.SIN_SNRS.size(), "one count per course")
	var total := 0
	for i in counts.size():
		var n := int(counts[i])
		total += n
		assert_between(n, 0, SpeechRules.SIN_KEY_WORDS, "a count of key words")
		var want := roundi(SpeechRules.sin_expected_words(SpeechRules.SIN_SNRS[i], loss))
		assert_eq(n, want, "course %d: what the party model expects of a typical diner" % (i + 1))
		if i > 0:
			assert_true(n <= int(counts[i - 1]), "fewer as the party grows")
	assert_eq(total, int(r["total"]), "the total adds up")
	assert_eq(total, 25, "a typical diner: 25 of 30")
	assert_near(loss, SpeechRules.snr_loss(total), 0.001, "the bottom line is snr_loss(25)")
	assert_near(loss, 0.5, 0.001, "0.5 dB")
	var band := StringName(String(r["band"]))
	assert_eq(band, SpeechRules.sin_band(loss), "its band is sin_band(0.5)")
	assert_eq(band, &"normal", "the normal band")
	assert_eq(String(r["band_name"]), SpeechRules.SIN_BAND_NAMES[band].to_upper(), "the stamp prints SIN_BAND_NAMES")
	assert_eq(String(r["band_name"]), "NEAR-NORMAL", "A7: NEAR-NORMAL, never SMALL")
	var lines: Array = (_scene("receipt")["params"] as Dictionary)["lines"]
	assert_has(String(lines[2]), "%.1f dB" % loss, "the card says the loss")
	assert_has(String(lines[2]).to_lower(), SpeechRules.SIN_BAND_NAMES[band].to_lower(), "the card says the band's name")
	assert_has(String(lines[1]), "%d of %d" % [total, SpeechRules.SIN_KEY_WORDS * SpeechRules.SIN_SNRS.size()], "the card says 25 of 30")
