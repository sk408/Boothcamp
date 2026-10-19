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


# ---------------------------------------------------------------- the word model (WrsModel, §9.12.1)

## A sim of `p` with this seed (seed 0 would be random: tests start at 1) and the noise at `mask` dB EM.
static func _sim(p: PatientProfile, seed_value: int, mask: int = -1) -> SpeechSim:
	var s := SpeechSim.new(p, seed_value)
	s.mask_db = mask
	return s


func test_the_model_loads_behind_the_facade() -> void:
	var s := _sim(_nora(), 1)
	assert_true(s.wrs_model() is WrsModel, "SpeechSim finds the word model by path")
	assert_true((s.wrs_model() as WrsModel).sim() == s, "it knows its sim")
	assert_true(s.sin_model() == null or not s.sin_model() is WrsModel, "the party model is another file")
	var refs := _dropped_sim()
	assert_true(refs[0].get_ref() == null and refs[1].get_ref() == null, "a dropped sim frees its word model (WeakRef)")
	# the chances are truth and draw nothing: the SRT replays exactly with them asked
	var before := s.rng.state
	s.p_wrs("left", 75)
	s.p_wrs_test("right", 55)
	s.p_wrs_cross("left", 95)
	s.true_wrs_max("left")
	assert_eq(s.rng.state, before, "chances never draw from the rng")


func _dropped_sim() -> Array[WeakRef]:
	var s := _sim(_nora(), 2)
	return [weakref(s), weakref(s.wrs_model())]


## Nora's chances (CHAPTER4 §2.1, Appendix A; truth, her real phones IA 50).
func test_nora_chances() -> void:
	var p := _nora()
	var s := _sim(p, 1)
	assert_eq(s.true_wrs_max("right"), 96.0)
	assert_eq(s.true_wrs_max("left"), 52.0)
	assert_near(s.p_wrs_test("right", 55), 0.956, 0.005, "right at 55, no noise")
	assert_true(s.p_wrs_cross("right", 55) < 0.001, "her poor left never steals the right's words")
	s.mask_db = 55
	assert_near(s.p_wrs_test("left", 75), 0.515, 0.005, "left at 75, noise 55")
	assert_eq(s.p_wrs_cross("left", 75), 0.0, "the noise covers her right: masked out")
	assert_near(s.p_wrs("left", 75), 0.515, 0.005)
	s.mask_db = 70
	assert_near(s.p_wrs_test("left", 95), 0.120, 0.005, "left at 95, noise 70: rollover takes 0.40")
	s.mask_db = -1
	assert_near(s.p_wrs_test("left", 75), 0.515, 0.005, "unmasked, her own ear is the same")
	assert_near(s.p_wrs_cross("left", 75), 0.385, 0.005, "but the right cochlea hears it 50 dB softer")
	assert_near(s.p_wrs("left", 75), 0.70, 0.02, "the Ghost helped")
	# too little noise: crossed words at 25 dB HL, noise 20 dB EM, so the Ghost still steals some
	s.mask_db = 20
	assert_true(s.p_wrs_cross("left", 75) > 0.1, "undermasked")
	s.mask_db = 25
	assert_eq(s.p_wrs_cross("left", 75), 0.0, "noise at the crossed level masks it out")
	# overmasking: noise loud enough to leak back to the test ear lowers its own chance
	s.mask_db = 100
	assert_true(s.p_wrs_test("left", 75) < 0.5, "noise 100 leaks back 50 dB softer")
	# a profile without wrs_max: the prediction from its TRUE thresholds
	var plain := PatientProfile.new()
	for f: int in ClinicRules.AC_FREQS:
		plain.thresholds_right[f] = 20
		plain.thresholds_left[f] = 20
	var ps := _sim(plain, 1)
	assert_eq(ps.true_wrs_max("left"), float(SpeechRules.predicted_wrs_max(plain.get_thresholds("left"))))


## Appendix A's rows by Nora's measured left PTA (CHAPTER4 §2.2): the comfortable list and the
## louder one 20 dB up, each with its noise (wrs_mask_level on her left best bone 35): the dealt count
## before the jitter, and so the score.
func test_nora_rows() -> void:
	var p := _nora()
	for row: Array in [[70, 13, 90, 5], [75, 13, 95, 3], [80, 10, 100, 0]]:
		var comfy := int(row[0])
		var louder := SpeechRules.wrs_louder_level(comfy)
		assert_eq(louder, int(row[2]))
		var s := _sim(p, 1, SpeechRules.wrs_mask_level(comfy, 35.0, &"phones"))
		assert_eq(roundi(s.p_wrs(String("left"), comfy) * 25.0), int(row[1]), "left at %d" % comfy)
		s.mask_db = SpeechRules.wrs_mask_level(louder, 35.0, &"phones")
		assert_eq(s.mask_db, 70, "the louder list's noise is capped at 70")
		assert_eq(roundi(s.p_wrs("left", louder) * 25.0), int(row[3]), "left at %d" % louder)
		# every row is rollover, from the worst deal too (A2's index: 0.45 or more)
		var worst := SpeechRules.wrs_rollover([{"level_db": comfy, "pct": SpeechRules.wrs_pct(int(row[1]) - 1)},
			{"level_db": louder, "pct": SpeechRules.wrs_pct(mini(25, int(row[3]) + 1))}])
		assert_true(bool(worst["rollover"]), "row %d: index %.2f" % [comfy, float(worst["index"])])
	# her right ear needs no noise at 55; her left does at 75 (CHAPTER4 §2.1)
	assert_false(SpeechRules.speech_masking_needed(55, 35.0, &"phones"))
	assert_true(SpeechRules.speech_masking_needed(75, 10.0, &"phones"))


## The four Appendix A cases: [ear, level, noise, list, the chance that counts (test ear, or either
## ear unmasked), whether cross hits are expected].
const DEAL_CASES: Array = [["right", 55, -1, "words_1", 0.956, false], ["left", 75, 55, "words_2", 0.515, false],
	["left", 95, 70, "words_3", 0.120, false], ["left", 75, -1, "words_2", 0.70, true]]


## List control (D4): over 4000 seeds per case the count is round(p x 25) give or take one, exactly it
## half the time, and right on average.
func test_list_control() -> void:
	var p := _nora()
	for c: Array in DEAL_CASES:
		var items := SpeechMaterial.items(String(c[3]))
		var exact := 0
		var sum := 0
		var worst := 0
		var target := -1
		for seed_value in range(1, 4001):
			var s := _sim(p, seed_value, int(c[2]))
			var d := s.deal_wrs_list(String(c[0]), int(c[1]), items)
			var k := int(d["k_total"])
			if target < 0:
				target = roundi(float(d["p_total"]) * 25.0)
				assert_eq(target, roundi(float(c[4]) * 25.0), "%s %d: the chance" % [c[0], c[1]])
			worst = maxi(worst, absi(k - target))
			if k == target:
				exact += 1
			sum += k
			if seed_value <= 200:
				_check_deal_shape(d, items.size())
		var label := "%s at %d (noise %d)" % [c[0], c[1], c[2]]
		assert_true(worst <= 1, "%s: a count %d off" % [label, worst])
		assert_near(float(exact) / 4000.0, 0.50, 0.03, label + ": exact half the time")
		assert_near(float(sum) / 4000.0, float(target), 0.08, label + ": right on average")


## A deal's outcomes add up to its counts.
func _check_deal_shape(d: Dictionary, n: int) -> void:
	var o: Array = d["outcomes"]
	assert_eq(o.size(), n)
	var tally := {&"test": 0, &"cross": 0, &"miss": 0}
	for x: StringName in o:
		assert_true(tally.has(x), "outcome %s" % x)
		tally[x] = int(tally[x]) + 1
	assert_eq(int(tally[&"test"]), int(d["k_test"]), "test hits")
	assert_eq(int(tally[&"test"]) + int(tally[&"cross"]), int(d["k_total"]), "all hits")
	assert_has(SpeechRules.WRS_DEAL_JITTER, int(d["jitter"]))
	for k: String in ["n", "k_test", "k_total", "jitter", "p_test", "p_cross", "p_total", "level", "mask_db", "neural",
			"audible_target", "aside_target"]:
		assert_true(d.has(k), "the deal has " + k)


## The banana: a cochlear ear misses the words whose key sound sits lowest (Nora's right at 55 loses s,
## f and th words), a neural ear misses at random (her left).
func test_banana_and_the_neural_smear() -> void:
	var p := _nora()
	var high := ["s", "f", "th"]
	var low := ["m", "n", "l", "r"]
	for c: Array in [["right", 55, -1, "words_1"], ["left", 75, 55, "words_2"]]:
		var items := SpeechMaterial.items(String(c[3]))
		var missed := {"high": 0, "low": 0}
		var words := {"high": 0, "low": 0}
		for it: Dictionary in items:
			var key := String(it["key_sound"])
			if high.has(key):
				words["high"] = int(words["high"]) + 1
			elif low.has(key):
				words["low"] = int(words["low"]) + 1
		for seed_value in range(1, 2001):
			var d := _sim(p, seed_value, int(c[2])).deal_wrs_list(String(c[0]), int(c[1]), items)
			var o: Array = d["outcomes"]
			for i in items.size():
				if o[i] == &"test":
					continue
				var key := String(items[i]["key_sound"])
				if high.has(key):
					missed["high"] = int(missed["high"]) + 1
				elif low.has(key):
					missed["low"] = int(missed["low"]) + 1
		var rate_high := float(missed["high"]) / float(words["high"] * 2000)
		var rate_low := float(missed["low"]) / float(words["low"] * 2000)
		if c[0] == "right":
			assert_true(rate_high >= 4.0 * rate_low, "cochlear right: s / f / th %.4f vs m / n / l / r %.4f" % [rate_high, rate_low])
		else:
			assert_true(rate_low > 0.0 and rate_high / rate_low <= 1.25, "neural left: %.4f vs %.4f" % [rate_high, rate_low])
			assert_true(rate_high / rate_low >= 0.8, "neural left: no reverse banana either")


## Cross-hearing (D4): masked lists never cross; unmasked, the other cochlea takes exactly the deal's
## share of the test ear's misses (round(p_wrs x 25) + j, never below the test-ear count).
func test_cross_hits() -> void:
	var p := _nora()
	var items := SpeechMaterial.items("words_2")
	for seed_value in range(1, 301):
		var masked := _sim(p, seed_value, 55).deal_wrs_list("left", 75, items)
		assert_false((masked["outcomes"] as Array).has(&"cross"), "seed %d: a masked list crossed" % seed_value)
		var open := _sim(p, seed_value).deal_wrs_list("left", 75, items)
		var j := int(open["jitter"])
		var k_test := clampi(roundi(float(open["p_test"]) * 25.0) + j, 0, 25)
		var k_total := clampi(roundi(float(open["p_total"]) * 25.0) + j, k_test, 25)
		assert_eq([int(open["k_test"]), int(open["k_total"])], [k_test, k_total], "seed %d" % seed_value)
		assert_eq((open["outcomes"] as Array).count(&"cross"), k_total - k_test)
		assert_eq(k_total - k_test, 5, "Nora unmasked at 75: 18 - 13 words crossed")
	# a crossed word comes back right, heard by the other ear
	var s := _sim(p, 4)
	var a := s.respond_wrs("left", 75, items[0], &"cross", items)
	assert_eq([a["correct"], a["kind"], a["heard_by"]], [true, &"correct", &"cross"])


## The same seed replays a deal exactly.
func test_a_seed_replays_the_deal() -> void:
	var p := _nora()
	var items := SpeechMaterial.items("words_2")
	var opts := {"ensure_audible_miss_by": 6, "aside_by": 8, "audible_thresholds": _octaves("left")}
	assert_eq(_sim(p, 77, 55).deal_wrs_list("left", 75, items, opts), _sim(p, 77, 55).deal_wrs_list("left", 75, items, opts))


## ensure_audible_miss_by 6 (Lists 2 and 3, CHAPTER4 §6): at 70, 75 and 80 on her neural left, one
## dealt miss in places 2-6 is a word whose every sound reaches her (on the MEASURED thresholds), in
## every one of 1000 seeds; it is the deal's audible_target, and the counts never change.
func test_ensure_audible_miss() -> void:
	var p := _nora()
	var left := _octaves("left")
	for id: String in ["words_2", "words_3"]:
		var items := SpeechMaterial.items(id)
		for level: int in [70, 75, 80]:
			var mask := SpeechRules.wrs_mask_level(level, 35.0, &"phones")
			var landed := 0
			for seed_value in range(1, 1001):
				var plain := _sim(p, seed_value, mask).deal_wrs_list("left", level, items)
				var d := _sim(p, seed_value, mask).deal_wrs_list("left", level, items,
					{"ensure_audible_miss_by": 6, "audible_thresholds": left})
				assert_eq([d["k_test"], d["k_total"], d["jitter"]], [plain["k_test"], plain["k_total"], plain["jitter"]],
					"%s %d seed %d: the counts" % [id, level, seed_value])
				var t := int(d["audible_target"])
				var o: Array = d["outcomes"]
				if t >= 1 and t <= 5 and o[t] == &"miss" and SpeechRules.word_fully_audible(items[t], float(level), left):
					landed += 1
				if seed_value <= 100:
					_check_deal_shape(d, items.size())
			assert_eq(landed, 1000, "%s at %d: an audible miss in places 2-6" % [id, level])
	# no audible word in the window: nothing moves
	var none := _sim(p, 3, 55).deal_wrs_list("left", 75, SpeechMaterial.items("words_1"),
		{"ensure_audible_miss_by": 3, "audible_thresholds": left})
	var plain1 := _sim(p, 3, 55).deal_wrs_list("left", 75, SpeechMaterial.items("words_1"))
	assert_eq(none["outcomes"], plain1["outcomes"], "sand and price never reach her left at 75")
	assert_eq(int(none["audible_target"]), -1)


## aside_by: the aside word (bike in places 1-8 of List 2, hook in places 1-5 of List 3) is a miss,
## its answer is the aside foil with Hoot's side line, and the counts never change.
func test_aside_by() -> void:
	var p := _nora()
	for c: Array in [["words_2", 8, "bike", "Mike?", "mike"], ["words_3", 5, "hook", "Hoot?", "hoot"]]:
		var items := SpeechMaterial.items(String(c[0]))
		var at := -1
		for i in items.size():
			if String(items[i]["text"]) == c[2]:
				at = i
		for seed_value in range(1, 501):
			var opts := {"aside_by": int(c[1]), "ensure_audible_miss_by": 6, "audible_thresholds": _octaves("left")}
			var plain := _sim(p, seed_value, 55).deal_wrs_list("left", 75, items)
			var s := _sim(p, seed_value, 55)
			var d := s.deal_wrs_list("left", 75, items, opts)
			assert_eq([d["k_test"], d["k_total"]], [plain["k_test"], plain["k_total"]], "seed %d: the counts" % seed_value)
			assert_eq(int(d["aside_target"]), at, "%s is the aside word" % c[2])
			assert_eq((d["outcomes"] as Array)[at], &"miss")
			assert_ne(int(d["audible_target"]), at, "the Call it word is another word")
			if int(d["audible_target"]) >= 0:
				assert_eq((d["outcomes"] as Array)[int(d["audible_target"])], &"miss", "both named words stay misses")
			if seed_value <= 50:
				var a := s.respond_wrs("left", 75, items[at], &"miss", items, PackedStringArray(), &"aside")
				assert_eq(String(a["text"]), String(c[3]))
				assert_eq([a["kind"], a["rhyme"], a["correct"], a["style"]], [&"wrong", true, false, &"aside"])
				assert_eq(String(a["aside"]), String((items[at]["asides"] as Dictionary)[c[4]]))
	assert_eq(int(_sim(p, 1, 55).deal_wrs_list("left", 75, SpeechMaterial.items("words_1"), {"aside_by": 25})["aside_target"]),
		-1, "a list without asides has no aside word")


## What a miss sounds like (§9.12.1): a cochlear ear says a foil (80%) or nothing; a neural ear also
## says other words of the list (15%); a word too soft to make out gets more silences.
func test_miss_answers() -> void:
	assert_eq(WrsModel.miss_shares(false, 0.99), {&"foil": 0.80, &"silence": 0.20})
	var soft := WrsModel.miss_shares(false, 0.4)
	assert_near(float(soft[&"silence"]), 0.6, 0.0001, "silence at least 1 - A")
	assert_near(float(soft[&"foil"]), 0.4, 0.0001)
	var smear := WrsModel.miss_shares(true, 0.3)
	assert_near(float(smear[&"silence"]), 0.7, 0.0001)
	assert_near(float(smear[&"foil"]) + float(smear[&"other"]), 0.3, 0.0001, "the rest shrink in proportion")
	assert_near(float(smear[&"foil"]) / float(smear[&"other"]), 4.0, 0.0001)
	var p := _nora()
	for c: Array in [["right", 55, -1, "words_1", 0.80, 0.0], ["left", 75, 55, "words_2", 0.60, 0.15],
			["right", 25, -1, "words_1", 0.40, 0.0]]:
		var items := SpeechMaterial.items(String(c[3]))
		var s := _sim(p, 9, int(c[2]))
		var kinds := {"foil": 0, "other": 0, "silence": 0}
		var n := 0
		for it: Dictionary in items:
			var foils := {}
			for f: Variant in it["foils"]:
				foils[SpeechSim.as_question(String(f))] = String(f).to_lower()
			for i in 60:
				var a := s.respond_wrs(String(c[0]), int(c[1]), it, &"miss", items)
				n += 1
				assert_false(bool(a["correct"]))
				assert_eq(a["heard_by"], &"")
				var t := String(a["text"])
				match a["kind"]:
					&"wrong":
						if bool(a["rhyme"]):
							kinds["foil"] = int(kinds["foil"]) + 1
							assert_true(foils.has(t), "%s: a rhyme from its foils, not %s" % [it["text"], t])
							var line := String((it.get("asides", {}) as Dictionary).get(String(foils.get(t, "")), ""))
							assert_eq(String(a["aside"]), line, "an aside only on its own foil")
						else:
							kinds["other"] = int(kinds["other"]) + 1
							var other := t.trim_suffix("?").to_lower()
							assert_ne(other, String(it["text"]).to_lower(), "never the word itself")
							assert_false(foils.values().has(other), "never one of its foils")
							var in_list := false
							for o: Dictionary in items:
								in_list = in_list or String(o["text"]).to_lower() == other
							assert_true(in_list, "another word of the list: " + t)
							assert_eq(String(a["aside"]), "")
					&"silence":
						kinds["silence"] = int(kinds["silence"]) + 1
						assert_has(SpeechSim.SILENCES, t)
					_:
						fail("a miss answered %s" % a["kind"])
		var label := "%s at %d" % [c[0], c[1]]
		assert_near(float(kinds["foil"]) / n, float(c[4]), 0.05, label + ": foils")
		assert_near(float(kinds["other"]) / n, float(c[5]), 0.04, label + ": other words")
	# the plan's silences replace the default ones
	var s2 := _sim(p, 5)
	for i in 40:
		var a := s2.respond_wrs("right", 25, SpeechMaterial.items("words_1")[0], &"miss", [], PackedStringArray(["Mm?"]))
		if a["kind"] == &"silence":
			assert_eq(String(a["text"]), "Mm?")


## The answer styles (D20) change the words she says, never whether the word counts.
func test_answer_styles() -> void:
	var p := _nora()
	var s := _sim(p, 12)
	var items := SpeechMaterial.items("words_1")
	var sock: Dictionary = items[0]
	var chess := SpeechMaterial.item("words_1", "w1_13")
	var plain := s.respond_wrs("right", 55, sock, &"test", items)
	assert_eq(String(plain["text"]), "Sock!", "a plain hit: the word, first letter up")
	assert_eq([plain["correct"], plain["kind"], plain["heard_by"], plain["style"], plain["trap"]], [true, &"correct", &"test", &"", false])
	for k: String in ["text", "correct", "kind", "heard_by", "delay_s", "p", "rhyme", "trap", "style", "key_sound", "margin_db", "aside"]:
		assert_true(plain.has(k), "an answer has " + k)
	assert_eq(String(plain["key_sound"]), "s")
	assert_near(float(plain["margin_db"]), 0.0, 0.0001, "s is 0 dB on her right at 55 (truth)")
	assert_between(float(plain["delay_s"]), p.reaction_time_min_s, p.reaction_time_max_s + SpeechSim.NEAR_EXTRA_S)
	# chatty hits: the word as a whole token plus 6 words or fewer of chatter
	var mine := PackedStringArray(["Like the ones I knit.", "A {word} for every foot!"])
	for lines: PackedStringArray in [mine, PackedStringArray()]:
		for i in 30:
			var a := s.respond_wrs("right", 55, sock, &"test", items, PackedStringArray(), &"chatty_hit", lines)
			var t := String(a["text"])
			assert_eq([a["correct"], a["kind"], a["style"]], [true, &"correct", &"chatty_hit"], t)
			var toks := SpeechMaterial.tokens(t)
			assert_eq(toks[0], "sock", t)
			assert_true(toks.size() - 1 <= SpeechRules.WRS_CHATTY_MAX_WORDS, "6 words or fewer of chatter: " + t)
			assert_false(t.contains("{"), t)
	for line: String in WrsModel.CHATTER:
		assert_true(SpeechMaterial.tokens(line).size() <= SpeechRules.WRS_CHATTY_MAX_WORDS, line)
	assert_eq(String(_sim(p, 3).respond_wrs("right", 55, sock, &"test", items, PackedStringArray(), &"chatty_hit",
		PackedStringArray(["Like the ones I knit."]))["text"]), "Sock! Like the ones I knit.")
	# the plural trap: a miss, asked as a question
	var trap := s.respond_wrs("right", 55, sock, &"miss", items, PackedStringArray(), &"plural_trap")
	assert_eq(String(trap["text"]), "Socks?")
	assert_eq([trap["correct"], trap["kind"], trap["trap"], trap["style"]], [false, &"wrong", true, &"plural_trap"])
	var no_plural := s.respond_wrs("right", 55, chess, &"miss", items, PackedStringArray(), &"plural_trap")
	assert_eq([no_plural["trap"], no_plural["style"]], [false, &""], "chess has no plural: an ordinary miss")
	# the self-correction: a foil, then the word; the final answer counts
	var fix := s.respond_wrs("right", 55, sock, &"test", items, PackedStringArray(), &"self_correct")
	var t2 := String(fix["text"])
	assert_true(t2.ends_with("... no, SOCK!"), t2)
	var first := t2.get_slice("...", 0).to_lower()
	assert_has(["lock", "rock", "dock"], first, t2)
	assert_eq([fix["correct"], fix["kind"], fix["style"]], [true, &"correct", &"self_correct"])
	# a style that does not fit the outcome is ignored
	var odd := s.respond_wrs("right", 55, sock, &"miss", items, PackedStringArray(), &"chatty_hit")
	assert_eq([odd["correct"], odd["style"]], [false, &""])
	odd = s.respond_wrs("right", 55, sock, &"test", items, PackedStringArray(), &"plural_trap")
	assert_eq([String(odd["text"]), odd["style"]], ["Sock!", &""])
	odd = s.respond_wrs("right", 55, sock, &"miss", items, PackedStringArray(), &"aside")
	assert_eq([odd["style"], odd["aside"]], [&"", ""], "sock has no aside")
	assert_eq(WrsModel.STYLES, [&"chatty_hit", &"plural_trap", &"self_correct", &"aside"])
