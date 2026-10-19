extends TestCase
## (Day 5) The Party Noise Test's rules and material (CONTRACTS.md §9.11.2, §9.14, §9.15.2, §9.23.1;
## docs/CHAPTER5.md §2, §5.5, §14): the SIN rules appended after the "lists" block, amendment A7's band
## names, Party lists 1-6 and the practice sentence, and the originality guard. The guard checks only
## our own material (every sentence was written fresh for the game; the lists' notes say so and name
## the published tests they must not copy): nothing repeats, nothing is its own mishear, the content
## rules of §9.11.2 hold. The party model's statistics are in test_speech_sin_model.gd.

const PARTY_LISTS: PackedStringArray = ["party_practice", "party_1", "party_2", "party_3", "party_4", "party_5", "party_6"]
## The published sentence tests the material must never copy, as each list's note names them.
const NOT_COPIED: PackedStringArray = ["HINT", "BKB", "IEEE/Harvard", "QuickSIN", "WIN", "BKB-SIN", "SPIN", "AzBio"]
## Homophones of our key words (CHAPTER5 §5.5: no mishear is a homophone of its key word, and no
## list holds a homophone of one of its key words: "hole" never stands in for "whole").
const HOMOPHONES: Dictionary = {
	"whole": ["hole"], "two": ["to", "too"], "red": ["read"], "new": ["knew", "gnu"], "meet": ["meat", "mete"],
	"bear": ["bare"], "stairs": ["stares"], "sells": ["cells"], "heard": ["herd"], "ceiling": ["sealing"],
	"morning": ["mourning"], "wore": ["war"], "ladder": ["latter"], "sail": ["sale"], "tail": ["tale"],
	"knight": ["night"], "night": ["knight"], "pair": ["pear", "pare"], "flower": ["flour"], "son": ["sun"],
	"sun": ["son"], "week": ["weak"], "road": ["rode", "rowed"], "hair": ["hare"], "deer": ["dear"],
}
## Words no party sentence or mishear may hold: a diagnosis (Hoot never names one), anything scary
## or violent, rude, or about alcohol.
const BANNED_WORDS: PackedStringArray = ["tumour", "tumor", "neuroma", "schwannoma", "cancer", "growth", "stroke",
	"meniere", "menieres", "blood", "bloody", "dead", "death", "die", "died", "kill", "killed", "gun", "guns",
	"knife", "bomb", "war", "stupid", "idiot", "damn", "hell", "beer", "wine", "vodka", "whisky", "whiskey",
	"drunk", "gin", "rum", "cider", "pub"]
## Food key words: the lists are "mostly not about food", so the restaurant theme never helps him guess.
const FOOD_WORDS: PackedStringArray = ["sausages", "turnip", "tomatoes", "tomato", "bread", "soup", "pizza", "cake",
	"cheese", "salt", "pasta", "pie", "jam", "toast", "apple", "apples", "egg", "eggs", "butter", "rice", "beans",
	"potato", "potatoes", "chips", "meat", "fish", "chicken", "carrot", "carrots", "tea", "coffee", "biscuit"]
## Fixed phrases a sentence may not hold (CHAPTER5 §5.5's own examples of what was rewritten).
const FIXED_PHRASES: PackedStringArray = ["pass the salt", "picnic basket", "birthday presents", "caught the ball",
	"once upon a time", "happy birthday", "good morning", "good night"]
## The Day 5 files that must never read SIN_BAND_TITLES or SIN_HELP (D22: they print SIN_BAND_NAMES and
## SIN_REMEDIES). Files a later step adds are checked as soon as they exist.
const DAY5_FILES: PackedStringArray = ["res://core/speech/models/sin_model.gd", "res://core/speech/speech_babble.gd",
	"res://core/speech/modes/sin_test.gd", "res://ui/speech/modes/sp_mode_party.gd",
	"res://ui/speech/sp_sentence_card.gd", "res://ui/speech/sp_courses.gd", "res://ui/speech/sp_snr_meter.gd",
	"res://ui/speech/sp_party_booth.gd", "res://story/level_marco.gd", "res://story/papers/paper_party_golf.gd",
	"res://story/explainers/movies/party_noise.gd", "res://story/explainers/stages/party_noise_sets.gd",
	"res://story/dev_marco.gd"]
const DAY5_RULES_MARKER := "# ---------------------------------------------------------------- party lists (Day 5)"


# ---------------------------------------------------------------- rules

func test_sin_rules_as_written() -> void:
	assert_eq(SpeechRules.snr_loss(16), 9.5)
	assert_eq(SpeechRules.snr_loss(20), 5.5)
	assert_eq(SpeechRules.snr_loss(25), 0.5, "the typical diner")
	for t in 31:
		assert_eq(SpeechRules.snr_loss(t), float(30 - t) - 4.5, "SNR loss = key words missed - 4.5 (total %d)" % t)
	var bands := {3.0: &"normal", 3.5: &"mild", 7.0: &"mild", 7.5: &"moderate", 15.0: &"moderate", 15.5: &"severe"}
	for loss: float in bands:
		assert_eq(SpeechRules.sin_band(loss), bands[loss], "band at %.1f" % loss)
	assert_eq(SpeechRules.sin_level(21.7), 70, "Marco's talker level")
	assert_eq(SpeechRules.SIN_AIDED_DB, 50)
	assert_eq([SpeechRules.wrs_level(21.7), SpeechRules.wrs_level(23.3)], [55, 60], "Marco's word levels")
	assert_eq(SpeechRules.SIN_PRACTICE_SNR, 25)
	assert_eq(SpeechRules.SIN_LISTS_PER_CONDITION, 2)
	assert_eq(SpeechRules.SIN_LISTS.size(), SpeechRules.SIN_CONDITIONS.size() * SpeechRules.SIN_LISTS_PER_CONDITION,
		"two lists for each condition")
	assert_eq(SpeechRules.SIN_LISTS, ["party_1", "party_2", "party_3", "party_4", "party_5", "party_6"])
	assert_eq(SpeechRules.SIN_PRACTICE_LIST, "party_practice")


func test_band_names_and_remedies() -> void:
	var ids: Array[StringName] = []
	for b: Array in SpeechRules.SIN_BANDS:
		ids.append(b[1])
	ids.append(SpeechRules.SIN_BAND_TOP)
	assert_eq(SpeechRules.SIN_BAND_NAMES.keys(), ids, "a name for every band, in order")
	assert_eq(SpeechRules.SIN_REMEDIES.keys(), ids, "a remedy for every band, in order")
	assert_eq(SpeechRules.SIN_BAND_NAMES[&"normal"], "Near-normal", "amendment A7: 0-3 dB is normal or near-normal")
	for id: StringName in ids:
		assert_ne(SpeechRules.SIN_BAND_NAMES[id], "Small", "never \"Small\"")
	assert_eq(SpeechRules.SIN_BAND_NAMES[SpeechRules.sin_band(SpeechRules.snr_loss(25))], "Near-normal",
		"the typical diner's 0.5 dB")
	assert_eq(SpeechRules.SIN_BAND_NAMES[&"moderate"], "Moderate")
	assert_eq(SpeechRules.SIN_REMEDIES[&"moderate"], "+ directional mics")
	assert_eq(SpeechRules.SIN_REMEDIES[&"severe"], "+ a remote mic")
	# the shared titles stay as they were, for the old code only
	assert_eq(SpeechRules.SIN_BAND_TITLES.keys(), ids)
	assert_eq(SpeechRules.SIN_HELP.keys(), ids)


func test_no_day5_file_reads_the_old_band_titles() -> void:
	var files := PackedStringArray()
	for p: String in DAY5_FILES:
		if FileAccess.file_exists(p):
			files.append(p)
	for p: String in _glob("res://story/games/", "marco_", ".gd"):
		files.append(p)
	assert_true(files.size() >= 2, "the party model and the babble are checked at least")
	for p: String in files:
		var code := _code_only(FileAccess.get_file_as_string(p))
		for name: String in ["SIN_BAND_TITLES", "SIN_HELP"]:
			assert_false(code.contains(name), "%s reads %s" % [p.get_file(), name])
	# and the Day 5 rules block itself (only its comments may name them)
	var rules := FileAccess.get_file_as_string("res://core/speech/speech_rules.gd")
	var at := rules.find(DAY5_RULES_MARKER)
	assert_true(at > 0, "the Day 5 rules block is in speech_rules.gd")
	assert_true(at > rules.find("const LIST_CONFIRM_SLIP"), "after the S0a lists block")
	var block := _code_only(rules.substr(at))
	for name: String in ["SIN_BAND_TITLES", "SIN_HELP"]:
		assert_false(block.contains(name), "the Day 5 rules read %s" % name)


func test_slots_levels_and_snrs() -> void:
	assert_eq(SpeechRules.sin_slot(&"unaided"), "both")
	assert_eq(SpeechRules.sin_slot(&"unaided", "both"), "both")
	assert_eq(SpeechRules.sin_slot(&"unaided", "right"), "right")
	assert_eq(SpeechRules.sin_slot(&"unaided", "left"), "left")
	assert_eq(SpeechRules.sin_slot(&"omni"), "aided_omni")
	assert_eq(SpeechRules.sin_slot(&"omni", "left"), "aided_omni", "aided tests are both ears in the sound field")
	assert_eq(SpeechRules.sin_slot(&"directional"), "aided_directional")
	for c: StringName in SpeechRules.SIN_CONDITIONS:
		for e: String in ["both", "right", "left"]:
			assert_has(SpeechRules.SIN_SLOTS, SpeechRules.sin_slot(c, e))
		assert_true(SpeechRules.SIN_CONDITION_TITLES.has(c), "a title for %s" % c)
	assert_eq(SpeechRules.SIN_CONDITION_TITLES[&"directional"], "FOCUS")
	assert_eq(SpeechRules.SIN_CONDITION_TITLES[&"omni"], "OMNI")
	var unaided: Array[int] = []
	var aided: Array[int] = []
	for n in range(1, 7):
		assert_eq(SpeechRules.sin_snr_for(n), SpeechRules.SIN_SNRS[n - 1], "sentence %d" % n)
		unaided.append(SpeechRules.sin_babble_level(70, SpeechRules.sin_snr_for(n)))
		aided.append(SpeechRules.sin_babble_level(SpeechRules.SIN_AIDED_DB, SpeechRules.sin_snr_for(n)))
	assert_eq(unaided, [45, 50, 55, 60, 65, 70], "the party steps up under a 70 dB talker")
	assert_eq(aided, [25, 30, 35, 40, 45, 50], "and under the aided 50")
	assert_eq(SpeechRules.sin_snr_for(0), SpeechRules.SIN_PRACTICE_SNR, "0 = the practice sentence")
	assert_eq(SpeechRules.sin_snr_for(9), 0, "past the end stays at the last step")
	assert_eq(SpeechRules.SIN_COURSES, ["Starter", "Soup", "Fish", "Main", "Cheese", "Dessert"])
	assert_eq(SpeechRules.SIN_COURSES.size(), SpeechRules.SIN_SNRS.size(), "one course per step")


func test_dithered_count() -> void:
	for e: float in [0.0, 0.03, 0.31, 1.94, 2.5, 4.3, 4.92, 4.99, 5.0]:
		var sum := 0
		var steps := 1000
		for i in steps:
			var u := (float(i) + 0.5) / float(steps)
			var c := SpeechRules.sin_count(e, u)
			assert_true(absf(float(c) - e) < 1.0, "count %d is within one of %.2f" % [c, e])
			assert_between(float(c), 0.0, 5.0, "a count is 0..5")
			sum += c
		assert_near(float(sum) / float(steps), e, 0.002, "averages exactly to %.2f" % e)
	assert_eq(SpeechRules.sin_count(-1.0, 0.0), 0, "clamped below")
	assert_eq(SpeechRules.sin_count(5.0, 0.999), 5, "clamped above")


func test_key_word_sounds() -> void:
	var cases := {"socks": ["s", "k"], "phone": ["f"], "watched": ["ch"], "city": ["s", "t"], "six": ["s", "k"],
		"three": ["th"], "moon": [], "giraffe": ["f"], "quietly": ["k", "t"], "fence": ["f", "s"],
		"shiny": ["sh"], "trophy": ["t", "f"], "zebra": ["z"], "velvet": ["v", "t"]}
	for w: String in cases:
		assert_eq(SpeechRules.key_word_sounds(w), PackedStringArray(cases[w]), w)
	assert_eq(SpeechRules.key_word_sounds("SOCKS"), PackedStringArray(["s", "k"]), "case does not matter")
	for s: String in SpeechRules.SIN_KEY_SOUNDS:
		assert_true(SpeechRules.SOUND_CUES.has(s), "%s is a sound cue" % s)


func test_key_word_miss_weight() -> void:
	# Marco's better ear at each frequency (CHAPTER5 §2), talker at 70
	var thr := {250: 10, 500: 15, 750: 15, 1000: 20, 1500: 25, 2000: 30, 3000: 35, 4000: 40, 6000: 40, 8000: 35}
	assert_eq(SpeechRules.key_word_miss_weight("moon", PackedStringArray(), thr, 70.0), 1.0, "no soft high sound")
	assert_eq(SpeechRules.key_word_miss_weight("bear", PackedStringArray(), thr, 70.0), 1.0)
	# s sits 5 dB over his 4 kHz threshold (under the 15 dB window); k is 18 dB clear
	assert_eq(SpeechRules.key_word_miss_weight("six", PackedStringArray(), thr, 70.0), 2.0, "s near, k clear")
	assert_eq(SpeechRules.key_word_miss_weight("shiny", PackedStringArray(), thr, 70.0), 1.0, "sh is 25 dB clear")
	assert_eq(SpeechRules.key_word_miss_weight("x", PackedStringArray(["s", "f", "th", "t", "z"]), thr, 70.0),
		1.0 + float(SpeechRules.SIN_PICK_CAP), "capped at SIN_PICK_CAP extra")
	assert_eq(SpeechRules.key_word_miss_weight("school", PackedStringArray(["s"]), thr, 70.0), 2.0,
		"key_sounds override the letters")
	assert_eq(SpeechRules.key_word_miss_weight("six", PackedStringArray(), thr, 95.0), 1.0, "loud enough: nothing near")


func test_traps() -> void:
	var traps := [["streets", "street"], ["drop", "dropped"], ["leaves", "leaf"], ["sit", "sat"], ["sleeps", "slept"],
		["hear", "heard"], ["chews", "chewed"], ["keeps", "kept"], ["puppy", "puppies"], ["hugs", "hugged"],
		["slips", "slipped"], ["polished", "polishes"], ["draw", "drew"], ["lend", "lent"], ["sing", "sang"],
		["shake", "shook"], ["ponies", "pony"], ["Streets", "street"]]
	for p: Array in traps:
		assert_true(SpeechRules.is_trap(p[0], p[1]), "'%s' is a trap for '%s'" % p)
	var alikes := [["cloud", "loud"], ["lift", "left"], ["shoed", "chewed"], ["potted", "spotted"], ["actor", "tractor"],
		["grandma", "grandpa"], ["feeling", "ceiling"], ["sipped", "slipped"], ["sank", "sang"], ["drip", "drift"],
		["slept", "kept"], ["hit", "hid"], ["street", "street"], ["", "street"], ["ink", "pink"]]
	for p: Array in alikes:
		assert_false(SpeechRules.is_trap(p[0], p[1]), "'%s' is not a trap for '%s'" % p)


func test_averages_and_real_change() -> void:
	assert_eq(SpeechRules.sin_average([]), -1.0, "-1 before a list")
	assert_eq(SpeechRules.sin_average([9.5]), 9.5)
	assert_eq(SpeechRules.sin_average([9.5, 8.5]), 9.0)
	assert_eq(SpeechRules.sin_crit_diff(1), 3.9)
	assert_eq(SpeechRules.sin_crit_diff(2), 2.7)
	assert_eq(SpeechRules.sin_crit_diff(0), 3.9, "clamped to one list")
	assert_eq(SpeechRules.sin_crit_diff(4), 2.7, "clamped to two lists")
	assert_true(SpeechRules.sin_real_change(4.0, 2), "4 dB with two lists each is real")
	assert_true(SpeechRules.sin_real_change(2.8, 2))
	assert_false(SpeechRules.sin_real_change(2.7, 2), "at the critical difference it could be luck")
	assert_false(SpeechRules.sin_real_change(3.5, 1), "one list each needs 3.9")
	assert_false(SpeechRules.sin_real_change(-4.0, 2), "a loss of benefit never counts")


func test_par_and_forks() -> void:
	assert_eq(SpeechRules.sin_par(3), 3)
	assert_eq(SpeechRules.sin_par(6), 6)
	assert_eq(SpeechRules.sin_par(-1), 0)
	var forks := {0: 3, 1: 2, 2: 1, 3: 1, 4: 0, 9: 0}
	for slips: int in forks:
		assert_eq(SpeechRules.sin_forks(slips), forks[slips], "%d slips" % slips)


func test_model_constants() -> void:
	var sum := 0.0
	for k: StringName in SpeechRules.SIN_MISS_SHARES:
		sum += SpeechRules.SIN_MISS_SHARES[k]
	assert_near(sum, 1.0, 0.0001, "the miss shares add up")
	assert_eq(SpeechRules.SIN_MISS_SHARES.keys(), [&"mishear", &"filler", &"drop"])
	assert_eq([SpeechRules.SIN_PICK_WINDOW_DB, SpeechRules.SIN_PICK_CAP], [15.0, 3])
	assert_eq([SpeechRules.SIN_LITTLE_SWAP_SHARE, SpeechRules.SIN_LOST_EXPECTED, SpeechRules.SIN_LOST_SHARE],
		[0.2, 0.25, 0.5])
	for w: String in SpeechRules.SIN_LITTLE_WORDS:
		var to := String(SpeechRules.SIN_LITTLE_WORDS[w])
		assert_ne(to, w, "%s swaps to another word" % w)
		assert_true(SpeechRules.SIN_LITTLE_WORDS.has(to), "%s swaps to a little word" % w)


# ---------------------------------------------------------------- material

func test_party_lists_shape() -> void:
	var key_words := 0
	for id: String in PARTY_LISTS:
		var list := SpeechMaterial.load_list(id)
		assert_eq(SpeechMaterial.validate(list), PackedStringArray(), id)
		assert_eq(String(list.get("id", "")), id)
		assert_eq(String(list.get("kind", "")), "sentence", id)
		assert_eq(list.get("original", false), true, id)
		var items := SpeechMaterial.items(id)
		var practice := id == "party_practice"
		assert_eq(String(list.get("title", "")), "Practice sentence" if practice else "Party list %s" % id.right(1))
		assert_eq(items.size(), 1 if practice else SpeechRules.SIN_SNRS.size(), "%s sentences" % id)
		for n in items.size():
			var it := items[n]
			var want := "pp_1" if practice else "p%s_%d" % [id.right(1), n + 1]
			assert_eq(String(it.get("id", "")), want, "item ids in play order")
			var words := SpeechMaterial.tokens(String(it.get("text", "")))
			assert_between(float(words.size()), 6.0, 9.0, "%s has 6-9 words" % want)
			var kws: Array = it.get("key_words", [])
			assert_eq(kws.size(), SpeechRules.SIN_KEY_WORDS, "%s: five key words" % want)
			assert_eq((it.get("mishears", []) as Array).size(), SpeechRules.SIN_KEY_WORDS, "%s: five mishear groups" % want)
			for w: Variant in kws:
				assert_eq(String(w), String(w).to_lower(), "%s: key words are written as the scorer compares them" % want)
			var text := String(it.get("text", ""))
			assert_true(text.ends_with("."), "%s ends with a full stop" % want)
			assert_eq(text.left(1), text.left(1).to_upper(), "%s starts with a capital" % want)
			if not practice:
				key_words += kws.size()
	assert_eq(key_words, 180, "30 key words a list, 180 over the six")


func test_party_notes_say_written_fresh() -> void:
	for id: String in PARTY_LISTS:
		var note := String(SpeechMaterial.load_list(id).get("note", ""))
		assert_true(note.contains("written fresh for Booth Camp"), "%s says it was written fresh" % id)
		for name: String in NOT_COPIED:
			assert_true(note.contains(name), "%s names %s as a test it must not copy" % [id, name])


## The originality guard, on our own material only.
func test_party_material_is_our_own() -> void:
	var seen_sentences := {}
	var all_key_sets: Array = []
	for id: String in PARTY_LISTS:
		var list_keys := {}
		var list_tokens := {}
		var food := 0
		for it: Dictionary in SpeechMaterial.items(id):
			var iid := String(it.get("id", ""))
			var toks := SpeechMaterial.tokens(String(it.get("text", "")))
			var plain := " ".join(toks)
			assert_false(seen_sentences.has(plain), "%s repeats %s" % [iid, seen_sentences.get(plain, "")])
			seen_sentences[plain] = iid
			for t: String in toks:
				list_tokens[t] = true
			for phrase: String in FIXED_PHRASES:
				assert_false((" %s " % plain).contains(" %s " % phrase), "%s holds a fixed phrase" % iid)
			var kws: Array = it.get("key_words", [])
			var groups: Array = it.get("mishears", [])
			var has_food := false
			for i in kws.size():
				var w := String(kws[i])
				assert_false(list_keys.has(w), "%s: key word '%s' is already in %s" % [iid, w, list_keys.get(w, "")])
				list_keys[w] = iid
				has_food = has_food or FOOD_WORDS.has(w)
				var group: Array = groups[i]
				var in_group := {}
				for m: Variant in group:
					var said := String(m).to_lower()
					assert_ne(said, w, "%s: '%s' is its own mishear" % [iid, w])
					assert_false(in_group.has(said), "%s: mishear '%s' twice" % [iid, said])
					in_group[said] = true
					assert_eq(SpeechMaterial.tokens(said).size(), 1, "%s: a mishear is one word ('%s')" % [iid, said])
					assert_false((HOMOPHONES.get(w, []) as Array).has(said), "%s: '%s' is a homophone of '%s'" % [iid, said, w])
					list_tokens[said] = true
			food += int(has_food)
			for other: Dictionary in all_key_sets:
				var shared := 0
				for w: Variant in kws:
					shared += int((other["keys"] as Array).has(w))
				assert_true(shared <= 2, "%s shares %d key words with %s" % [iid, shared, other["id"]])
			all_key_sets.append({"id": iid, "keys": kws})
		assert_true(food <= 1, "%s is mostly not about food (%d food sentences)" % [id, food])
		for w: String in list_keys:
			for h: String in HOMOPHONES.get(w, []):
				assert_false(list_tokens.has(h), "%s holds '%s', a homophone of its key word '%s'" % [id, h, w])
		for t: String in list_tokens:
			assert_false(BANNED_WORDS.has(t), "%s holds the banned word '%s'" % [id, t])
	assert_eq(seen_sentences.size(), 37, "36 sentences and the practice, all different")


func test_party_lists_teach_traps() -> void:
	for id: String in SpeechRules.SIN_LISTS:
		var traps := 0
		var alikes := 0
		for it: Dictionary in SpeechMaterial.items(id):
			var kws: Array = it["key_words"]
			for i in kws.size():
				var has_trap := false
				var has_alike := false
				for m: Variant in it["mishears"][i]:
					if SpeechRules.is_trap(String(m), String(kws[i])):
						has_trap = true
					else:
						has_alike = true
				traps += int(has_trap)
				alikes += int(has_alike)
		assert_true(traps >= 10, "%s offers plural and tense traps (%d)" % [id, traps])
		assert_true(alikes >= 25, "%s offers sound-alikes for most key words (%d)" % [id, alikes])


func test_key_sounds_overrides() -> void:
	var overrides := 0
	for id: String in PARTY_LISTS:
		for it: Dictionary in SpeechMaterial.items(id):
			if not it.has("key_sounds"):
				continue
			var groups: Array = it["key_sounds"]
			var kws: Array = it["key_words"]
			var differs := false
			for i in groups.size():
				differs = differs or PackedStringArray(groups[i]) != SpeechRules.key_word_sounds(String(kws[i]))
			assert_true(differs, "%s: key_sounds only where the letters mislead" % it["id"])
			overrides += 1
	assert_true(overrides >= 1, "the spelling-misleads overrides are used")


# ---------------------------------------------------------------- helpers

## A script's text with its comments removed (a "#" outside a string starts one).
static func _code_only(text: String) -> String:
	var out := PackedStringArray()
	for line: String in text.split("\n"):
		var in_str := false
		var cut := line.length()
		for i in line.length():
			var ch := line[i]
			if ch == "\"" and (i == 0 or line[i - 1] != "\\"):
				in_str = not in_str
			elif ch == "#" and not in_str:
				cut = i
				break
		out.append(line.left(cut))
	return "\n".join(out)


static func _glob(dir: String, prefix: String, ext: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.begins_with(prefix) and f.ends_with(ext):
			out.append(dir.path_join(f))
	return out
