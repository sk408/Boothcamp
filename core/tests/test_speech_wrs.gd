extends TestCase
## Word recognition (Day 4, CONTRACTS.md §9.11-§9.15 and §9.24, with the clinical amendments A1-A4):
## the WRS rules, the four word lists and their originality guard, and the word model (WrsModel).
## Nora's numbers are CHAPTER4 §2's; where an amendment changed a pinned number, the test says so.
## Random tests use fixed seeds (SpeechSim.new(profile, seed)), so a failure replays.
## Word list 1 is CHAPTER4 §6's table (the targets, in order).
const LIST_1: PackedStringArray = ["sock", "sand", "price", "fox", "leaf", "thorn", "booth", "tub", "night", "cork",
	"hike", "shore", "chess", "zone", "van", "pear", "bunch", "dice", "gate", "mug", "nose", "lamb", "rope", "wave",
	"hut"]
## Words no list may hold: scary, medical, rude or alcohol (CHAPTER4 §6); the last row also bars foils.
const BANNED_TARGETS: PackedStringArray = ["lump", "pain", "scan", "pill", "drug", "blood", "dead", "death", "kill",
	"gun", "bomb", "grave", "tomb", "skull", "ghost", "germ", "sick", "cough", "flu", "cut"]
const BANNED_ANYWHERE: PackedStringArray = ["booze", "beer", "wine", "pub", "keg", "gin", "rum", "knob", "bum", "poo",
	"hell", "damn", "crap", "weed", "dope"]


## Nora (CHAPTER4 §2): core/patients/nora.tres once it exists, else the same truth built here.
func _nora() -> PatientProfile:
	if ResourceLoader.exists("res://core/patients/nora.tres"):
		return Game.load_patient("nora") as PatientProfile
	var p := PatientProfile.new()
	p.id = "nora"
	p.display_name = "Nora Nightingale"
	p.pronoun = "she"
	var r := [10, 10, 10, 15, 15, 20, 25, 30, 35, 40]
	var l := [30, 35, 35, 40, 45, 45, 50, 55, 55, 60]
	for i in ClinicRules.AC_FREQS.size():
		p.thresholds_right[ClinicRules.AC_FREQS[i]] = r[i]
		p.thresholds_left[ClinicRules.AC_FREQS[i]] = l[i]
	p.ia_phones_db = 50
	p.ia_inserts_db = 75
	p.speech = {"srt": {"right": 15, "left": 40}, "wrs_max": {"right": 96, "left": 52},
		"rollover": {"left": {"after": 75, "drop_per_10db": 20}}, "neural": {"left": true}}
	return p


## Nora's octave thresholds as Hoot charts them ({freq: dB}).
static func _octaves(ear: String) -> Dictionary:
	if ear == "right":
		return {250: 10, 500: 10, 1000: 15, 2000: 20, 4000: 30, 8000: 40}
	return {250: 30, 500: 35, 1000: 40, 2000: 45, 4000: 55, 8000: 60}


## Hoot's three Day 4 tone sheets (§5.1): right air, left air, left masked bone at 1k and 4k.
static func _nora_tones() -> Dictionary:
	var ears := {}
	for e: String in ["right", "left"]:
		var freqs := {}
		var t := _octaves(e)
		for f: int in t:
			freqs[f] = {"ear": e, "freq": f, "stored_db": t[f], "true_db": t[f], "error_db": 0.0, "by_hoot": true, "test": "ac"}
		ears[e] = {"freqs": freqs, "complete": true}
	ears["left"]["bc_masked"] = {
		1000: {"ear": "left", "freq": 1000, "stored_db": 40, "true_db": 40, "by_hoot": true, "test": "bc_masked"},
		4000: {"ear": "left", "freq": 4000, "stored_db": 55, "true_db": 55, "by_hoot": true, "test": "bc_masked"},
	}
	return {"patient_id": "nora", "ears": ears}


# ---------------------------------------------------------------- rules

func test_level_window_and_bands() -> void:
	assert_eq(SpeechRules.wrs_level(15.0), 55, "15 + 35 = 50, but never below 55")
	assert_eq(SpeechRules.wrs_level(40.0), 75)
	for db in [50, 55, 60]:
		assert_true(SpeechRules.wrs_level_ok(db, 15.0), "right window %d" % db)
	for db in [45, 65]:
		assert_false(SpeechRules.wrs_level_ok(db, 15.0), "outside the right window %d" % db)
	for db in [70, 75, 80]:
		assert_true(SpeechRules.wrs_level_ok(db, 40.0), "left window %d" % db)
	for db in [65, 85]:
		assert_false(SpeechRules.wrs_level_ok(db, 40.0), "outside the left window %d" % db)
	assert_eq(SpeechRules.wrs_band(52), &"very_poor")
	assert_eq(SpeechRules.wrs_band(56), &"poor")
	assert_eq(SpeechRules.wrs_band(96), &"excellent")
	var total := 0
	for k: String in SpeechRules.WRS_KEY_MIX:
		assert_true(SpeechRules.SOUND_CUES.has(k), "key sound %s is a SOUND_CUES id" % k)
		total += SpeechRules.WRS_KEY_MIX[k]
	assert_eq(total, SpeechRules.WRS_WORDS, "the key-sound mix fills a list")
	assert_eq(SpeechRules.WRS_LISTS, PackedStringArray(["words_1", "words_2", "words_3", "words_4"]))


## (A1, superseding §9.24's 88 / 80 / 76 / 74.67 / 72 pins) The interpolated predicted minimum on
## WRS_PREDICTED_MIN_25; the old step table stays for Day 3's tests only.
func test_predicted_min_interp() -> void:
	for pin: Array in [[15.0, 82.0], [35.0, 66.0], [40.0, 60.0], [45.0, 54.0], [50.0, 48.0], [0.0, 88.0], [80.0, 12.0]]:
		assert_near(SpeechRules.wrs_predicted_min_interp(pin[0]), pin[1], 0.001, "PTA %s" % pin[0])
	assert_near(SpeechRules.wrs_predicted_min_interp(41.67), 58.0, 0.01, "Nora's left PTA about 41.7")
	assert_near(SpeechRules.wrs_predicted_min_interp(-10.0), 88.0, 0.001, "clamped below 0")
	assert_near(SpeechRules.wrs_predicted_min_interp(95.0), 12.0, 0.001, "clamped above 80")
	assert_eq(SpeechRules.wrs_predicted_min_interp(NAN), 0.0, "no PTA, no prediction")
	# Nora's left best stays below it wherever Hoot's wobble puts her PTA (CHAPTER4 §2.2's rows): up
	# to 41.7 her comfortable list is 75 dB and scores 48-56; from 43.3 it is 80 dB and scores 36-44
	for row: Array in [[35.0, 56.0], [36.7, 56.0], [38.3, 56.0], [40.0, 56.0], [41.7, 56.0], [43.3, 44.0], [45.0, 44.0]]:
		assert_true(float(row[1]) < SpeechRules.wrs_predicted_min_interp(row[0]), "PTA %.1f" % row[0])
	# the old table and its function are untouched
	assert_eq(SpeechRules.wrs_predicted_min(40.0), 76)
	assert_eq(SpeechRules.wrs_predicted_min(41.7), 64)


## (A2, superseding D15's 20-point drop) Rollover is the index, with PBmin from a louder level.
func test_rollover_index() -> void:
	var r := SpeechRules.wrs_rollover([{"level_db": 75, "pct": 52}, {"level_db": 95, "pct": 12}])
	assert_near(float(r["index"]), 0.77, 0.005)
	assert_true(bool(r["rollover"]))
	assert_eq([float(r["pb_max"]), float(r["pb_min"])], [52.0, 12.0])
	r = SpeechRules.wrs_rollover([{"level_db": 75, "pct": 48}, {"level_db": 95, "pct": 16}])
	assert_near(float(r["index"]), 0.67, 0.005, "the worst deal")
	assert_true(bool(r["rollover"]))
	r = SpeechRules.wrs_rollover([{"level_db": 75, "pct": 52}, {"level_db": 95, "pct": 40}])
	assert_near(float(r["index"]), 0.23, 0.005)
	assert_false(bool(r["rollover"]))
	r = SpeechRules.wrs_rollover([{"level_db": 95, "pct": 52}, {"level_db": 75, "pct": 20}])
	assert_eq(float(r["pb_min"]), -1.0, "a lower score at a SOFTER level is no PBmin")
	assert_false(bool(r["rollover"]))
	r = SpeechRules.wrs_rollover([{"level_db": 75, "pct": 52}])
	assert_eq(float(r["pb_min"]), -1.0, "one list: no PBmin")
	assert_false(bool(r["rollover"]))
	assert_false(bool(SpeechRules.wrs_rollover([])["rollover"]))
	assert_eq(SpeechRules.rollover_index_of(0.0, 0.0), 0.0)
	assert_near(SpeechRules.rollover_index_of(50.0, 25.0), 0.5, 0.0001)
	assert_eq(SpeechRules.ROLLOVER_INDEX_CUTOFF, 0.45)
	# Day 3's old rules are unchanged (no day uses them)
	assert_true(SpeechRules.is_rollover(52, 12))
	assert_near(SpeechRules.rollover_index([52, 12]), 0.77, 0.005)


## (A3, superseding the fixed 20 points) Ear differences use the 25-word critical difference.
func test_wrs_differ_and_same_range() -> void:
	# Thornton & Raffin (1978) 95% ranges for 44%: 20-68 on 25 words, 26-62 on 50 words
	assert_false(SpeechRules.wrs_differ(44, 25, 20, 25))
	assert_true(SpeechRules.wrs_differ(44, 25, 16, 25))
	assert_false(SpeechRules.wrs_differ(44, 25, 68, 25))
	assert_true(SpeechRules.wrs_differ(44, 25, 72, 25))
	assert_false(SpeechRules.wrs_differ(44, 50, 26, 50))
	assert_true(SpeechRules.wrs_differ(44, 50, 24, 50))
	assert_false(SpeechRules.wrs_differ(44, 50, 62, 50))
	assert_true(SpeechRules.wrs_differ(44, 50, 64, 50))
	assert_eq(SpeechRules.wrs_same_range(44, 25), Vector2i(20, 68))
	assert_eq(SpeechRules.wrs_same_range(44, 50), Vector2i(26, 62))
	# Nora's ears
	assert_true(SpeechRules.wrs_differ(96, 25, 52, 25), "96 vs 52")
	assert_true(SpeechRules.wrs_differ(92, 25, 56, 25), "the worst deal, 92 vs 56")
	assert_false(SpeechRules.wrs_differ(96, 25, 88, 25), "96 vs 88: chance")
	assert_false(SpeechRules.wrs_differ(52, 25, 40, 25), "52 vs 40: chance")
	var r96 := SpeechRules.wrs_same_range(96, 25)
	var r52 := SpeechRules.wrs_same_range(52, 25)
	assert_true(r96.x > r52.y, "the bands do not overlap: %s vs %s" % [r96, r52])
	assert_false(SpeechRules.wrs_differ(52, 0, 96, 25), "no list, no verdict")
	# the old fixed rule stays for Day 3's tests only
	assert_true(SpeechRules.wrs_asymmetric(96, 52))
	assert_true(SpeechRules.wrs_asymmetric(92, 56))


func test_best_bone_on_nora() -> void:
	var t := _nora_tones()
	assert_eq(SpeechRules.ear_best_bone(t, "left"), {500: 35, 1000: 40, 2000: 45, 4000: 55}, "masked bone, else air")
	assert_eq(SpeechRules.ear_best_bone(t, "right"), {500: 10, 1000: 15, 2000: 20, 4000: 30}, "no bone: air")
	assert_eq(SpeechRules.nontest_best_bone(t, "right"), 35.0, "testing the right: the left's best")
	assert_eq(SpeechRules.nontest_best_bone(t, "left"), 10.0, "testing the left: the right's best")
	# the SRT's rule is unchanged: bone sheets only, else air
	assert_eq(SpeechRules.nontest_best_threshold(t, "right"), 40.0)
	assert_eq(SpeechRules.nontest_best_threshold(t, "left"), 10.0)
	assert_true(is_nan(SpeechRules.nontest_best_bone({}, "left")), "nothing measured")


## (D16, A4) The word-list noise: level - 20 (+ the other ear's gap), clamped to [level - IA, best
## bone + IA - 5].
func test_wrs_mask_level() -> void:
	assert_eq(SpeechRules.wrs_mask_level(75, 35.0, &"phones"), 55)
	assert_eq(SpeechRules.wrs_mask_level(95, 35.0, &"phones"), 70, "75 capped at 35 + 40 - 5")
	assert_eq(SpeechRules.wrs_mask_level(90, 35.0, &"phones"), 70)
	assert_eq(SpeechRules.wrs_mask_level(100, 35.0, &"phones"), 70)
	assert_eq(SpeechRules.wrs_mask_level(75, 35.0, &"phones", 10), 65, "(A4) the other ear's gap adds")
	assert_eq(SpeechRules.wrs_mask_level(95, 35.0, &"phones", 10), 70, "still capped")
	assert_eq(SpeechRules.wrs_mask_level(75, 35.0, &"inserts"), 55)
	assert_eq(SpeechRules.wrs_mask_level(95, NAN, &"phones"), 75, "no bone: no ceiling")
	assert_eq(SpeechRules.wrs_mask_level(100, 10.0, &"phones"), 45, "the dilemma: the ceiling wins")
	assert_true(SpeechRules.wrs_mask_capped(95, 35.0, &"phones"))
	assert_false(SpeechRules.wrs_mask_capped(75, 35.0, &"phones"))
	# the SRT's rule is unchanged
	assert_eq(SpeechRules.speech_mask_level(75), 55)
	assert_eq(SpeechRules.speech_mask_level(95), 75)
	assert_eq(SpeechRules.speech_mask_level(75, 10), 65)


func test_louder_rollover_and_counts() -> void:
	assert_eq(SpeechRules.wrs_louder_level(75), 95)
	assert_eq(SpeechRules.wrs_louder_level(85), 100, "never past the limit")
	for db in [90, 95, 100]:
		assert_true(SpeechRules.wrs_louder_ok(db, 75), "louder %d" % db)
	for db in [85, 80, 75]:
		assert_false(SpeechRules.wrs_louder_ok(db, 75), "not louder enough %d" % db)
	assert_true(SpeechRules.wrs_louder_ok(100, 90), "the textbook level always is")
	var entry := {"after": 75, "drop_per_10db": 20}
	assert_near(SpeechRules.rollover_drop(entry, 95.0), 0.40, 0.0001)
	assert_near(SpeechRules.rollover_drop(entry, 80.0), 0.10, 0.0001)
	assert_eq(SpeechRules.rollover_drop(entry, 75.0), 0.0)
	assert_eq(SpeechRules.rollover_drop({}, 95.0), 0.0, "no rollover entry")
	assert_eq([SpeechRules.wrs_pct(24), SpeechRules.wrs_pct(13), SpeechRules.wrs_pct(3), SpeechRules.wrs_pct(5, 10)], [96, 52, 12, 50])
	assert_eq(SpeechRules.wrs_deal_count(0.515, 25, 0), 13)
	assert_eq(SpeechRules.wrs_deal_count(0.956, 25, 1), 25)
	assert_eq(SpeechRules.wrs_deal_count(0.12, 25, -1), 2)
	assert_eq(SpeechRules.wrs_deal_count(0.0, 25, -1), 0, "never below 0")
	assert_eq(SpeechRules.wrs_deal_count(1.0, 25, 1), 25, "never above the list")
	assert_eq(SpeechRules.wrs_deal_count(0.48, 25, -1, 13), 13, "never below lo (the test-ear count)")


func test_miss_weight_lens_and_ghost() -> void:
	assert_near(SpeechRules.wrs_miss_weight(0.0), 0.55, 0.0001)
	assert_near(SpeechRules.wrs_miss_weight(40.0), SpeechRules.WRS_MISS_FLOOR, 0.001, "a clear sound: the floor")
	assert_near(SpeechRules.wrs_miss_weight(-40.0), 1.0 + SpeechRules.WRS_MISS_FLOOR, 0.001, "a lost sound")
	assert_true(SpeechRules.wrs_miss_weight(-5.0) > SpeechRules.wrs_miss_weight(5.0))
	assert_eq(SpeechRules.lens_alpha(0.0), 1.0)
	assert_near(SpeechRules.lens_alpha(-15.0), 0.15, 0.0001)
	assert_near(SpeechRules.lens_alpha(-30.0), 0.15, 0.0001)
	assert_near(SpeechRules.lens_alpha(-7.5), 0.575, 0.0001)
	assert_eq(SpeechRules.lens_alpha(5.0), 1.0)
	assert_near(SpeechRules.ghost_alpha(50, &"phones", 10.0), 0.2, 0.0001, "faint from the first level that needs noise")
	assert_near(SpeechRules.ghost_alpha(60, &"phones", 10.0), 0.6, 0.0001)
	assert_eq(SpeechRules.ghost_alpha(75, &"phones", 10.0), 1.0, "bold by 70")
	assert_eq(SpeechRules.ghost_alpha(45, &"phones", 10.0), 0.0, "words cannot cross: no Ghost")
	assert_eq(SpeechRules.ghost_alpha(75, &"phones", NAN), 0.0)
	assert_eq(SpeechRules.CHAT_DB, 50)


## (D18) Audible means every chunk 3 dB or more above the measured threshold.
func test_word_audibility() -> void:
	var sock := {"text": "sock", "key_sound": "s", "chunks": [["s", "s"], ["o", "vowel"], ["ck", "k"]]}
	var right := _octaves("right")
	assert_near(SpeechRules.word_min_margin(sock, 55.0, right), 0.0, 0.0001, "s is 0 dB on her right at 55")
	assert_false(SpeechRules.word_fully_audible(sock, 55.0, right), "only just is not audible")
	assert_true(SpeechRules.word_fully_audible(sock, 58.0, right))
	var silent := {"text": "?", "chunks": [["?", ""]]}
	assert_eq(SpeechRules.word_min_margin(silent, 50.0, right), INF, "nothing to hear")
	assert_eq(SpeechRules.chunk_sounds(sock), sock["chunks"], "the item's own chunks")
	# a word without chunks gets a letter guess that still spells it
	for w: String in ["sock", "zone", "thorn", "night", "shell", "watch", "fudge", "cage", "Tea"]:
		var guess := SpeechRules.chunk_sounds({"text": w})
		var spelled := ""
		for c: Array in guess:
			spelled += String(c[0])
			assert_true(String(c[1]) == "" or SpeechRules.SOUND_CUES.has(String(c[1])), "%s: %s" % [w, c])
		assert_eq(spelled, w)
	assert_eq(SpeechRules.chunk_sounds({"text": "zone"}), [["z", "z"], ["o", "vowel"], ["n", "n"], ["e", ""]])
	assert_eq(SpeechRules.chunk_sounds({"text": "cage"})[0], ["c", "k"])
	assert_eq(SpeechRules.chunk_sounds({"text": "dice"})[2], ["c", "s"], "a soft c")


## (D27) When word scores refer.
func test_referral() -> void:
	assert_eq(SpeechRules.wrs_referral(true, false, false, false), &"refer", "asymmetric")
	assert_eq(SpeechRules.wrs_referral(false, false, false, true), &"refer", "rollover")
	assert_eq(SpeechRules.wrs_referral(false, false, true, false), &"refer", "below in one ear")
	assert_eq(SpeechRules.wrs_referral(false, true, false, false), &"refer", "below in the other ear")
	assert_eq(SpeechRules.wrs_referral(false, true, true, false), &"", "below in both, nothing else: no referral")
	assert_eq(SpeechRules.wrs_referral(false, false, false, false), &"")
	assert_eq(SpeechRules.wrs_referral(true, true, true, true), &"refer")


# ---------------------------------------------------------------- material

func test_four_lists_of_25() -> void:
	var ids := {}
	var seen := {}
	for n in SpeechRules.WRS_LISTS.size():
		var id := SpeechRules.WRS_LISTS[n]
		var list := SpeechMaterial.load_list(id)
		assert_eq(SpeechMaterial.validate(list), PackedStringArray(), id)
		assert_eq(String(list.get("title", "")), "Word list %d" % (n + 1))
		assert_eq(SpeechMaterial.kind(id), &"monosyllable")
		assert_true(bool(list.get("original", false)), id)
		var its := SpeechMaterial.items(id)
		assert_eq(its.size(), SpeechRules.WRS_WORDS, id)
		var mix := {}
		var targets := {}
		for it: Dictionary in its:
			targets[String(it["text"]).to_lower()] = true
		for i in its.size():
			var it: Dictionary = its[i]
			var iid := String(it["id"])
			var word := String(it["text"])
			assert_eq(iid, "w%d_%02d" % [n + 1, i + 1], "ids in order")
			assert_false(ids.has(iid), "unique id " + iid)
			ids[iid] = true
			assert_false(seen.has(word.to_lower()), "%s is in two lists" % word)
			seen[word.to_lower()] = id
			assert_false(word.contains(" "), "one word: " + word)
			var key := String(it["key_sound"])
			mix[key] = int(mix.get(key, 0)) + 1
			# chunks: required for word lists; they spell the word, with one carrying the key sound
			assert_true(it.has("chunks"), "%s has chunks" % word)
			var spelled := ""
			var carries := false
			for c: Array in it.get("chunks", []):
				spelled += String(c[0])
				carries = carries or String(c[1]) == key
			assert_eq(spelled, word, "%s's chunks" % word)
			assert_true(carries, "%s: a chunk carries %s" % [word, key])
			# foils: 3 or more distinct rhymes, never the word, never a target of this list
			var foils: Array = it["foils"]
			assert_true(foils.size() >= 3, word)
			var fs := {}
			for f: Variant in foils:
				var fl := String(f).to_lower()
				assert_false(fs.has(fl), "%s: foil %s twice" % [word, f])
				fs[fl] = true
				assert_ne(fl, word.to_lower())
				assert_false(targets.has(fl), "%s: foil %s is a target of %s" % [word, f, id])
			if it.has("plural"):
				var pl := String(it["plural"]).to_lower()
				assert_false(pl == word.to_lower() or fs.has(pl), "%s: plural %s" % [word, pl])
		assert_eq(mix, SpeechRules.WRS_KEY_MIX, "%s keeps the key-sound mix" % id)
	assert_eq(seen.size(), 100, "100 different target words")


## Word list 1 is CHAPTER4 §6's table; the faint f and th come early (the coached right ear).
func test_word_list_1_is_the_design() -> void:
	var words := PackedStringArray()
	for it: Dictionary in SpeechMaterial.items("words_1"):
		words.append(String(it["text"]))
	assert_eq(words, LIST_1)
	var fox := SpeechMaterial.item("words_1", "w1_04")
	assert_eq(String(fox["text"]), "fox", "Call it #1 on her right")
	# fox has a lost chunk on her right at 55: the faint-letter Call it has a word to land on
	assert_true(SpeechRules.word_min_margin(fox, 55.0, _octaves("right")) < 0.0)


## The audible-word rule (CHAPTER4 §6): Lists 2 and 3 each have at least two words in places 2-6
## whose every sound reaches Nora's left (her octaves) at 70, 75 and 80 dB, built only from sounds
## that clear 8 dB at 70 so Hoot's 5 dB wobble keeps them audible.
func test_audible_word_rule() -> void:
	var left := _octaves("left")
	for id: String in ["words_2", "words_3"]:
		var its := SpeechMaterial.items(id)
		for level in [70, 75, 80]:
			var n := 0
			var robust := 0
			for i in range(1, 6):
				if SpeechRules.word_fully_audible(its[i], float(level), left):
					n += 1
					if level == 70 and SpeechRules.word_min_margin(its[i], 70.0, left) >= 8.0:
						robust += 1
			assert_true(n >= 2, "%s at %d: %d audible words in places 2-6" % [id, level, n])
			if level == 70:
				assert_true(robust >= 2, "%s: %d words clear 8 dB at 70" % [id, robust])


## The two in-jokes (CHAPTER4 §6): "bike" in places 1-8 of List 2 with "Mike", "hook" in places 1-5
## of List 3 with exactly Hoot, hoof and hood (its last sound changes, never its first: the
## first-sound rhymes of "hook" are a published rhyme set).
func test_asides() -> void:
	var bike := {}
	var its := SpeechMaterial.items("words_2")
	for i in 8:
		if String(its[i]["text"]) == "bike":
			bike = its[i]
	assert_false(bike.is_empty(), "bike in places 1-8 of Word list 2")
	assert_has(bike["foils"], "Mike")
	assert_eq(String((bike["asides"] as Dictionary).get("mike", "")), "Mike? He's in the break room. With donuts.")
	var hook := {}
	its = SpeechMaterial.items("words_3")
	for i in 5:
		if String(its[i]["text"]) == "hook":
			hook = its[i]
	assert_false(hook.is_empty(), "hook in places 1-5 of Word list 3")
	assert_eq(hook["foils"], ["Hoot", "hoof", "hood"], "hook's foils keep its first sound")
	for f: Variant in hook["foils"]:
		assert_true(String(f).to_lower().begins_with("hoo"), String(f))
	assert_eq(String((hook["asides"] as Dictionary).get("hoot", "")), "Present!")
	# every aside is a short side line, keyed by one of its own foils
	for id: String in SpeechRules.WRS_LISTS:
		for it: Dictionary in SpeechMaterial.items(id):
			for k: Variant in it.get("asides", {}):
				var line := String(it["asides"][k])
				assert_true(line.split(" ", false).size() <= Hoot.MAX_WORDS, line)
				assert_false(line.contains("{"), line)


func test_content_rules() -> void:
	for id: String in SpeechRules.WRS_LISTS:
		for it: Dictionary in SpeechMaterial.items(id):
			var word := String(it["text"]).to_lower()
			assert_false(BANNED_TARGETS.has(word) or BANNED_ANYWHERE.has(word), "%s: %s" % [id, word])
			for f: Variant in it["foils"]:
				assert_false(BANNED_ANYWHERE.has(String(f).to_lower()), "%s: %s's foil %s" % [id, word, f])
			assert_false(BANNED_ANYWHERE.has(String(it.get("plural", "")).to_lower()))


## The originality guard (CONTRACTS.md §9.11.1, as amended on 2026-10-19). It checks only our own
## material: the repo never holds a published test's words, so nothing here compares with one. Every
## list says it was written fresh for the game and names the published tests it must not copy; no
## target repeats within or across the lists (test_four_lists_of_25); no target is its own foil or a
## foil of its own list; and no two items share more than two words of their rhyme sets (the target
## and its foils), so no set is reused with a word swapped.
func test_originality_guard() -> void:
	var sets: Array = []
	for id: String in SpeechRules.WRS_LISTS:
		var note := String(SpeechMaterial.load_list(id).get("note", ""))
		assert_true(note.begins_with("Written fresh for Booth Camp"), id + ": " + note)
		for name: String in ["NU-6", "W-22", "CID W-1", "PB-50", "Boothroyd", "NU-CHIPS", "WIPI", "Modified Rhyme Test"]:
			assert_has(note, name, "%s names %s" % [id, name])
		var targets := {}
		for it: Dictionary in SpeechMaterial.items(id):
			targets[String(it["text"]).to_lower()] = true
		for it: Dictionary in SpeechMaterial.items(id):
			var word := String(it["text"]).to_lower()
			var set := {word: true}
			for f: Variant in it["foils"]:
				var fl := String(f).to_lower()
				assert_ne(fl, word, "%s is its own foil" % word)
				assert_false(targets.has(fl), "%s: foil %s is a target of %s" % [word, fl, id])
				assert_false(fl.contains(" "), "%s: one-word foils (%s)" % [word, fl])
				set[fl] = true
			assert_eq(set.size(), 1 + (it["foils"] as Array).size(), "%s: distinct foils" % word)
			sets.append([String(it["id"]), set])
	assert_eq(sets.size(), 4 * SpeechRules.WRS_WORDS)
	for a in sets.size():
		for b in range(a + 1, sets.size()):
			var shared := _shared_words(sets[a][1], sets[b][1])
			assert_true(shared <= 2, "%s and %s share %d rhyme words" % [sets[a][0], sets[b][0], shared])
	# the check catches a reused set (two made-up sets with one word swapped)
	assert_eq(_shared_words({"moon": true, "noon": true, "soon": true, "loon": true},
		{"spoon": true, "noon": true, "soon": true, "loon": true}), 3)


static func _shared_words(a: Dictionary, b: Dictionary) -> int:
	var n := 0
	for w: Variant in a:
		if b.has(w):
			n += 1
	return n
