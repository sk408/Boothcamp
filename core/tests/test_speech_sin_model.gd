extends TestCase
## (Day 5) The party model: SinModel behind SpeechSim's SIN facade (CONTRACTS.md §9.12.2, §9.24 and
## Appendix A; docs/CHAPTER5.md §2, §5.6, §14). Marco's numbers, the dithered counts over thousands of
## seeded lists, two lists and the bands, the FOCUS benefit, which key words go first, and what he
## says. Every random test runs SpeechSim.new(profile, seed) over fixed seeds (1..N), so a failure
## replays. Marco's profile comes with his level; until then a stand-in holds his truth table.

## Noise-wins lines for the tests (the patient's own come from the level's plan).
const LOST := ["Lost it, sorry.", "Only clatter.", "Something about a hat?"]


## Marco's truth table (CHAPTER5 §2): a mild sloping loss, both ears alike, SNR loss 9.0, and
## FOCUS (vented domes) winning back 4.0 dB.
static func _marco(speech: Dictionary = {}) -> PatientProfile:
	var p := PatientProfile.new()
	p.id = "marco_standin"
	p.display_name = "Marco Polenta"
	var right: Dictionary[int, int] = {250: 10, 500: 15, 750: 15, 1000: 20, 1500: 25, 2000: 30, 3000: 35, 4000: 40,
		6000: 40, 8000: 35}
	var left: Dictionary[int, int] = {250: 10, 500: 15, 750: 15, 1000: 25, 1500: 25, 2000: 30, 3000: 35, 4000: 40,
		6000: 45, 8000: 40}
	p.thresholds_right = right
	p.thresholds_left = left
	p.reaction_time_min_s = 0.7
	p.reaction_time_max_s = 1.3
	p.psychometric_slope_db = 2.5
	p.attention = 0.95
	p.speech = {"wrs_max": {"right": 96, "left": 92}, "snr_loss": 9.0, "directional_benefit": 4.0}
	if not speech.is_empty():
		p.speech = speech
	return p


## One list's total key words (the truth: what he really got), sentence n at SIN_SNRS[n - 1].
static func _list_total(sim: SpeechSim, items: Array[Dictionary], level: int) -> int:
	var total := 0
	for n in items.size():
		var a := sim.respond_sin(SpeechRules.SIN_SNRS[n], items[n], level)
		total += int(a["count"])
	return total


static func _loss(total: int) -> float:
	return SpeechRules.snr_loss(total)


# ---------------------------------------------------------------- truth

func test_marco_numbers() -> void:
	var sim := SpeechSim.new(_marco(), 1)
	assert_near(SpeechRules.pta_for_speech(sim.air("right")), 21.67, 0.01, "PTA right")
	assert_near(SpeechRules.pta_for_speech(sim.air("left")), 23.33, 0.01, "PTA left")
	assert_eq(SpeechRules.pta_method(sim.air("right")), SpeechRules.pta_method(sim.air("left")), "both ears alike")
	var m := sim.sin_model()
	assert_true(m is SinModel, "the real party model loads by path")
	assert_eq(String(m.call("better_ear")), "right")
	assert_eq(sim.true_snr_loss(), 9.0)
	assert_eq(sim.true_snr_loss("left"), 9.0, "a number applies to both ears")
	assert_eq(sim.effective_snr_loss(), 9.0, "unaided")
	sim.condition = &"omni"
	assert_eq(sim.effective_snr_loss(), 9.0, "OMNI wins nothing in this much noise")
	sim.condition = &"directional"
	assert_eq(sim.effective_snr_loss(), 5.0, "FOCUS wins back 4.0 dB")
	assert_near(sim.p_key_word(10.0), SpeechRules.sin_expected_words(10.0, 5.0) / 5.0, 0.0001)
	# the audiogram's own rough estimate is stored for tests only (CHAPTER5 §2.2)
	assert_near(SpeechRules.estimated_snr_loss(sim.air("right")), 2.8, 0.001)
	assert_near(SpeechRules.estimated_snr_loss(sim.air("left")), 3.1, 0.001)


func test_loss_sources() -> void:
	var none := SpeechSim.new(_marco({"wrs_max": {"right": 96, "left": 92}}), 1)
	assert_near(none.true_snr_loss(), 2.8, 0.001, "no snr_loss: the better ear's estimate")
	assert_near(none.true_snr_loss("left"), 3.1, 0.001, "or the ear's own")
	none.condition = &"directional"
	assert_near(none.effective_snr_loss(), 0.0, 0.0001, "the default benefit, never below 0")
	var ears := SpeechSim.new(_marco({"snr_loss": {"right": 6.0, "left": 10.0}}), 1)
	assert_eq(ears.true_snr_loss(), 6.0, "both ears: the lower")
	assert_eq(ears.true_snr_loss("right"), 6.0)
	assert_eq(ears.true_snr_loss("left"), 10.0)
	ears.condition = &"directional"
	assert_eq(ears.effective_snr_loss("left"), 10.0 - SpeechRules.SIN_DIRECTIONAL_BENEFIT_DB, "the default benefit")
	var one := SpeechSim.new(_marco({"snr_loss": {"right": 1.0}}), 1)
	assert_near(one.true_snr_loss("left"), 3.1, 0.001, "a missing ear falls back to its estimate")
	assert_eq(one.true_snr_loss(), 1.0)
	var big := SpeechSim.new(_marco({"snr_loss": 3.0, "directional_benefit": 6.0}), 1)
	big.condition = &"directional"
	assert_eq(big.effective_snr_loss(), 0.0, "never below 0")
	assert_eq(SpeechSim.new(null, 1).true_snr_loss(), 0.0, "no profile, no loss")


## Appendix A: Marco's expected key words per sentence, unaided and with FOCUS, and the typical diner.
func test_expected_words_appendix_a() -> void:
	var sim := SpeechSim.new(_marco(), 1)
	var unaided := [4.99, 4.92, 4.30, 1.94, 0.31, 0.03]
	var focus := [5.00, 4.99, 4.87, 3.98, 1.44, 0.20]
	var sum_u := 0.0
	var sum_f := 0.0
	for i in SpeechRules.SIN_SNRS.size():
		var snr := float(SpeechRules.SIN_SNRS[i])
		sim.condition = &"unaided"
		var u := sim.p_key_word(snr) * 5.0
		sim.condition = &"directional"
		var f := sim.p_key_word(snr) * 5.0
		assert_near(snappedf(u, 0.01), unaided[i], 0.0001, "unaided at SNR %d" % snr)
		assert_near(snappedf(f, 0.01), focus[i], 0.0001, "FOCUS at SNR %d" % snr)
		sum_u += u
		sum_f += f
	assert_near(snappedf(sum_u, 0.01), 16.49, 0.0001, "unaided total")
	assert_near(snappedf(sum_f, 0.01), 20.47, 0.0001, "FOCUS total")
	assert_near(SpeechRules.SIN_CONSTANT - sum_u, 9.0, 0.01, "the expected list gives back his 9.0 dB")
	assert_near(SpeechRules.SIN_CONSTANT - sum_f, 5.0, 0.04, "and FOCUS its 5.0")
	assert_eq(SpeechRules.sin_band(SpeechRules.SIN_CONSTANT - sum_u), &"moderate")
	# a typical diner (loss 0) gets about 25 right: 0.5 dB, near-normal
	var diner := 0.0
	for snr: int in SpeechRules.SIN_SNRS:
		diner += SpeechRules.sin_expected_words(float(snr), 0.0)
	assert_eq(roundi(diner), 25)
	assert_eq(SpeechRules.SIN_BAND_NAMES[SpeechRules.sin_band(_loss(roundi(diner)))], "Near-normal")


# ---------------------------------------------------------------- statistics (seeded)

## 4000 seeded lists: the dithered counts average to the expected 16.49 and no sentence lands more
## than one key word from its expected count. 16 and 17 are the usual totals (46% and 38%).
func test_dithered_counts_4000_lists() -> void:
	var p := _marco()
	var lists := 4000
	var sum := 0
	var hist := {}
	var far := 0
	var material: Array = []
	for id: String in SpeechRules.SIN_LISTS:
		material.append(SpeechMaterial.items(id))
	for seed_value in range(1, lists + 1):
		var sim := SpeechSim.new(p, seed_value)
		var items: Array[Dictionary] = material[seed_value % 6]
		var total := 0
		for n in items.size():
			var a := sim.respond_sin(SpeechRules.SIN_SNRS[n], items[n], 70)
			if absf(float(a["count"]) - float(a["expected"])) >= 1.0:
				far += 1
			total += int(a["count"])
		sum += total
		hist[total] = int(hist.get(total, 0)) + 1
	assert_eq(far, 0, "no sentence lands a whole key word from its expected count")
	assert_near(float(sum) / float(lists), 16.49, 0.1, "4000 lists average the expected total")
	assert_near(float(hist.get(16, 0)) / float(lists), 0.46, 0.035, "16 right (9.5 dB) in about 46%")
	assert_near(float(hist.get(17, 0)) / float(lists), 0.38, 0.035, "17 right (8.5 dB) in about 38%")


## 2000 seeded visits, each with the day's six lists: two unaided lists land within 1.5 dB of 9.0 and
## in the moderate band; OMNI the same; FOCUS within 1.5 dB of 5.0; and the two-against-two benefit
## clears the 2.7 dB critical difference in at least 93% (95.0% exactly, from the count spread).
func test_two_lists_bands_and_benefit() -> void:
	var p := _marco()
	var lists := {}
	for id: String in SpeechRules.SIN_LISTS:
		lists[id] = SpeechMaterial.items(id)
	var visits := 2000
	var unaided_ok := 0
	var moderate := 0
	var omni_ok := 0
	var focus_ok := 0
	var real := 0
	for seed_value in range(1, visits + 1):
		var sim := SpeechSim.new(p, seed_value)
		sim.condition = &"unaided"
		var u := SpeechRules.sin_average([_loss(_list_total(sim, lists["party_1"], 70)),
			_loss(_list_total(sim, lists["party_2"], 70))])
		sim.condition = &"omni"
		var a := SpeechRules.sin_average([_loss(_list_total(sim, lists["party_3"], SpeechRules.SIN_AIDED_DB)),
			_loss(_list_total(sim, lists["party_4"], SpeechRules.SIN_AIDED_DB))])
		sim.condition = &"directional"
		var b := SpeechRules.sin_average([_loss(_list_total(sim, lists["party_5"], SpeechRules.SIN_AIDED_DB)),
			_loss(_list_total(sim, lists["party_6"], SpeechRules.SIN_AIDED_DB))])
		unaided_ok += int(absf(u - 9.0) <= 1.5)
		moderate += int(SpeechRules.sin_band(u) == &"moderate")
		omni_ok += int(absf(a - 9.0) <= 1.5)
		focus_ok += int(absf(b - 5.0) <= 1.5)
		real += int(SpeechRules.sin_real_change(a - b, 2))
	var n := float(visits)
	assert_true(unaided_ok / n >= 0.99, "two unaided lists within 1.5 dB of 9.0: %.4f" % (unaided_ok / n))
	assert_true(moderate / n >= 0.995, "the unaided band is moderate: %.4f" % (moderate / n))
	assert_true(omni_ok / n >= 0.99, "two OMNI lists within 1.5 dB of 9.0: %.4f" % (omni_ok / n))
	assert_true(focus_ok / n >= 0.99, "two FOCUS lists within 1.5 dB of 5.0: %.4f" % (focus_ok / n))
	assert_true(real / n >= 0.93, "the FOCUS benefit is real (over 2.7 dB): %.4f" % (real / n))
	assert_true(real / n <= 0.98, "and sometimes it is not (the honest path): %.4f" % (real / n))


## Key words with soft, high sounds near his thresholds are missed first: over 2000 sentences their
## miss rate is at least 1.5 times that of the words without (one or two misses per sentence).
func test_heavier_key_words_go_first() -> void:
	var p := _marco()
	var sentences: Array[Dictionary] = []
	for id: String in SpeechRules.SIN_LISTS:
		sentences.append_array(SpeechMaterial.items(id))
	var heavy := [0, 0]   # [missed, offered]
	var light := [0, 0]
	for seed_value in range(1, 2001):
		var sim := SpeechSim.new(p, seed_value)
		var it := sentences[seed_value % sentences.size()]
		var weights: Array[float] = sim.sin_model().call("miss_weights", it, 70, "both")
		var a := sim.respond_sin(15, it, 70)
		var heard: Array = a["heard"]
		for i in weights.size():
			var row := heavy if weights[i] > 1.0 else light
			row[0] += int(not heard[i])
			row[1] += 1
	assert_true(heavy[1] > 2000 and light[1] > 2000, "both kinds of key word are common (%d / %d)" % [heavy[1], light[1]])
	var rate_heavy := float(heavy[0]) / float(heavy[1])
	var rate_light := float(light[0]) / float(light[1])
	assert_true(rate_light > 0.0, "light words are missed sometimes")
	assert_true(rate_heavy / rate_light >= 1.5, "soft, high words go first: %.3f vs %.3f" % [rate_heavy, rate_light])
	var keep := SpeechSim.new(p, 1)
	var m: SinModel = keep.sin_model()
	var six := m.miss_weights(SpeechMaterial.item("party_2", "p2_5"), 70, "both")[1]
	var bear := m.miss_weights(SpeechMaterial.item("party_2", "p2_6"), 70, "both")[1]
	assert_eq(bear, 1.0, "\"bear\" has no soft, high sound")
	assert_true(six > bear, "so \"six\" goes before it")


# ---------------------------------------------------------------- what he says

## Over 300 visits of every sentence: heard key words appear as written, misses become a mishear from
## their own group, a filler or nothing, traps are misses, and the shares follow SIN_MISS_SHARES.
func test_answers_keep_what_he_heard() -> void:
	var p := _marco()
	var lists: Array[String] = [SpeechRules.SIN_PRACTICE_LIST]
	lists.append_array(SpeechRules.SIN_LISTS)
	var misses := {&"mishear": 0, &"trap": 0, &"filler": 0, &"drop": 0}
	var both_kinds := [0, 0]   # [traps, mishears] where a group offers both
	var swaps := [0, 0]        # [little swaps, answers]
	var kinds := {}
	for seed_value in range(1, 301):
		var sim := SpeechSim.new(p, seed_value)
		for id: String in lists:
			var items := SpeechMaterial.items(id)
			for n in items.size():
				var it := items[n]
				var snr: int = SpeechRules.SIN_SNRS[(n + seed_value) % 6]
				var a := sim.respond_sin(snr, it, 70, "both", {"lost_lines": LOST})
				var where := "%s seed %d" % [it["id"], seed_value]
				kinds[a["kind"]] = true
				var heard: Array = a["heard"]
				var said: Array = a["said_words"]
				var said_kinds: Array = a["said_kinds"]
				var traps: Array = a["traps"]
				assert_eq([heard.size(), said.size(), said_kinds.size(), traps.size()], [5, 5, 5, 5], where)
				assert_eq(heard.count(true), int(a["count"]), "%s: count = the heard key words" % where)
				if a["kind"] == &"lost":
					assert_true(LOST.has(a["text"]), "%s: a lost line is a whole line" % where)
					continue
				var count := int(a["count"])
				assert_eq(a["kind"], &"all" if count == 5 else (&"none" if count == 0 else &"partial"), where)
				var toks := SpeechMaterial.tokens(String(a["text"]))
				var kws: Array = it["key_words"]
				for i in 5:
					var w := String(kws[i])
					if heard[i]:
						assert_eq(said[i], w, "%s: a heard word is said as written" % where)
						assert_eq(said_kinds[i], &"heard", where)
						assert_has(toks, w, "%s: '%s' is in the answer" % [where, w])
						continue
					misses[said_kinds[i]] += 1
					assert_eq(traps[i], said_kinds[i] == &"trap", "%s: traps are flagged" % where)
					match said_kinds[i]:
						&"mishear", &"trap":
							assert_has(it["mishears"][i], said[i], "%s: '%s' is from its own group" % [where, said[i]])
							assert_eq(SpeechRules.is_trap(said[i], w), said_kinds[i] == &"trap", where)
							assert_has(toks, String(said[i]).to_lower(), "%s: the mishear is in the answer" % where)
							if _offers_both(it["mishears"][i], w):
								both_kinds[0 if said_kinds[i] == &"trap" else 1] += 1
						&"filler":
							assert_has(SinModel.FILLERS, said[i], where)
						&"drop":
							assert_eq(said[i], "", where)
							assert_true(String(a["text"]).contains(SinModel.DROPPED), "%s: a dropped word shows as ..." % where)
						_:
							fail("%s: unknown kind %s" % [where, said_kinds[i]])
				assert_eq(String(a["text"]).ends_with("?"), count < 5, "%s: unsure answers are questions" % where)
				swaps[0] += int(a["little_swap"])
				swaps[1] += 1
				if count == 5 and not a["little_swap"]:
					assert_eq(a["text"], it["text"], "%s: all heard, said back exactly" % where)
	for k: StringName in [&"all", &"partial", &"none", &"lost"]:
		assert_true(kinds.has(k), "answers of kind %s" % k)
	var total_misses := 0
	for k: StringName in misses:
		total_misses += int(misses[k])
	assert_true(total_misses > 5000, "%d misses" % total_misses)
	var mishear_share := float(misses[&"mishear"] + misses[&"trap"]) / float(total_misses)
	assert_near(mishear_share, SpeechRules.SIN_MISS_SHARES[&"mishear"], 0.03, "mishears")
	assert_near(float(misses[&"filler"]) / float(total_misses), SpeechRules.SIN_MISS_SHARES[&"filler"], 0.03, "fillers")
	assert_near(float(misses[&"drop"]) / float(total_misses), SpeechRules.SIN_MISS_SHARES[&"drop"], 0.03, "drops")
	assert_near(float(both_kinds[0]) / float(both_kinds[0] + both_kinds[1]), SinModel.TRAP_SHARE, 0.04,
		"a group with both kinds gives its trap 1 time in 5")
	assert_near(float(swaps[0]) / float(swaps[1]), SpeechRules.SIN_LITTLE_SWAP_SHARE, 0.02, "one answer in 5 swaps a little word")


static func _offers_both(group: Array, w: String) -> bool:
	var traps := 0
	for m: Variant in group:
		traps += int(SpeechRules.is_trap(String(m), w))
	return traps > 0 and traps < group.size()


## When the noise wins (count 0, under 0.25 key words expected) half the answers are a lost line,
## never the same one twice in a row; with more expected, or no lines in the plan, never.
func test_lost_lines() -> void:
	var p := _marco()
	var it := SpeechMaterial.item("party_1", "p1_6")
	var zero := 0
	var lost := 0
	for seed_value in range(1, 41):
		var sim := SpeechSim.new(p, seed_value)
		var last := ""
		for k in 25:
			var a := sim.respond_sin(0, it, 70, "both", {"lost_lines": LOST})
			if a["kind"] == &"lost":
				assert_eq(int(a["count"]), 0, "lost lines only with count 0")
				assert_true(float(a["expected"]) < SpeechRules.SIN_LOST_EXPECTED)
				assert_ne(a["text"], last, "never the same lost line twice in a row")
				assert_eq(a["heard"], [false, false, false, false, false])
				last = String(a["text"])
				lost += 1
			if int(a["count"]) == 0:
				zero += 1
			var b := sim.respond_sin(5, it, 70, "both", {"lost_lines": LOST})
			assert_ne(b["kind"], &"lost", "0.31 expected at SNR 5: he still tries")
			var c := sim.respond_sin(0, it, 70)
			assert_ne(c["kind"], &"lost", "no lines in the plan, no lost line")
	assert_near(float(lost) / float(zero), SpeechRules.SIN_LOST_SHARE, 0.06, "half of the count-0 answers")


func test_answer_text() -> void:
	var quiet := _no_swap_rng()
	var bear := SinModel._sentence(SpeechMaterial.item("party_2", "p2_6"))
	assert_eq(_said(bear, ["angry", "bear", "opened", "green", "suitcase"], [&"mishear", &"heard", &"heard", &"heard", &"heard"], quiet),
		"An angry bear opened the green suitcase?", "\"a\" becomes \"an\" before a changed vowel")
	var balloon := SinModel._sentence(SpeechMaterial.item("party_3", "p3_3"))
	assert_eq(_said(balloon, ["watched", "whatsit", "balloon", "drift", "hills"], [&"heard", &"filler", &"heard", &"heard", &"heard"], quiet),
		"We watched a whatsit balloon drift over the hills?", "and \"an\" becomes \"a\"")
	var fence := SinModel._sentence(SpeechMaterial.item("party_1", "p1_6"))
	assert_eq(_said(fence, ["two", "puppies", "carried", "turnip", ""], [&"heard", &"heard", &"heard", &"heard", &"drop"], quiet),
		"Two puppies carried a turnip past the ...?", "a dropped last word")
	assert_eq(_said(fence, ["few", "puppy", "carried", "turnip", "fence"], [&"mishear", &"trap", &"heard", &"heard", &"heard"], quiet),
		"Few puppy carried a turnip past the fence?", "the first word keeps its capital")
	var monday := SinModel._sentence(SpeechMaterial.item("party_1", "p1_5"))
	assert_eq(_said(monday, ["train", "left", "early", "rainy", "Sunday"], [&"heard", &"heard", &"heard", &"heard", &"mishear"], quiet),
		"The train left early on a rainy Sunday?")
	assert_eq(_said(monday, ["train", "left", "early", "rainy", "monday"], [&"heard", &"heard", &"heard", &"heard", &"heard"], quiet),
		"The train left early on a rainy Monday.", "all heard: said back exactly")
	var canoe := SinModel._sentence(SpeechMaterial.item("party_3", "p3_2"))
	assert_eq(_said(canoe, ["cousin", "sells", "shiny", "shoes", "Peru"], [&"heard", &"heard", &"heard", &"heard", &"mishear"], quiet),
		"My cousin sells shiny shoes from a Peru?", "a name keeps its capital")
	# a little-word swap changes only a word that never counts
	var swapped := 0
	var said: Array[String] = ["hungry", "bear", "opened", "green", "suitcase"]
	var heard: Array[StringName] = [&"heard", &"heard", &"heard", &"heard", &"heard"]
	for seed_value in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var r: Dictionary = SinModel._answer_text(bear, said, heard, rng)
		if r["little_swap"]:
			swapped += 1
			var toks := SpeechMaterial.tokens(String(r["text"]))
			for w: String in ["hungry", "bear", "opened", "green", "suitcase"]:
				assert_has(toks, w, "a swap never touches a key word")
			assert_ne(r["text"], "A hungry bear opened the green suitcase.")
	assert_true(swapped > 10, "swaps happen (%d)" % swapped)


static func _said(sent: Dictionary, said: Array, kinds: Array, rng: RandomNumberGenerator) -> String:
	var s: Array[String] = []
	s.assign(said)
	var k: Array[StringName] = []
	k.assign(kinds)
	var state := rng.state
	var r: Dictionary = SinModel._answer_text(sent, s, k, rng)
	rng.state = state
	return String(r["text"])


## An rng whose next randf() is at least SIN_LITTLE_SWAP_SHARE (so _answer_text swaps nothing).
static func _no_swap_rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for seed_value in range(1, 100):
		rng.seed = seed_value
		var state := rng.state
		if rng.randf() >= SpeechRules.SIN_LITTLE_SWAP_SHARE:
			rng.state = state
			return rng
	return rng


# ---------------------------------------------------------------- the sim

func test_same_seed_replays_a_visit() -> void:
	var p := _marco()
	var runs: Array = []
	for seed_value: int in [42, 42, 43]:
		var sim := SpeechSim.new(p, seed_value)
		var said: Array = []
		for id: String in SpeechRules.SIN_LISTS:
			sim.condition = &"directional" if id == "party_5" or id == "party_6" else &"unaided"
			var items := SpeechMaterial.items(id)
			for n in items.size():
				var a := sim.respond_sin(SpeechRules.SIN_SNRS[n], items[n], 70, "both", {"lost_lines": LOST})
				said.append([a["text"], a["count"], a["delay_s"]])
		runs.append(said)
	assert_eq(runs[0], runs[1], "the same seed replays every answer")
	assert_ne(runs[0], runs[2], "another seed plays another visit")


func test_per_ear_and_both() -> void:
	var sim := SpeechSim.new(_marco({"snr_loss": {"right": 6.0, "left": 10.0}}), 3)
	var m: SinModel = sim.sin_model()
	var it := SpeechMaterial.item("party_1", "p1_4")
	assert_eq(float(sim.respond_sin(10, it, 70, "left")["loss_eff"]), 10.0, "a per-ear test uses that ear's loss")
	assert_eq(float(sim.respond_sin(10, it, 70, "right")["loss_eff"]), 6.0)
	assert_eq(float(sim.respond_sin(10, it, 70)["loss_eff"]), 6.0, "both ears: the lower")
	var both := m.thresholds_for("both")
	assert_eq(both[1000], 20, "both: the better ear at each frequency")
	assert_eq(both[6000], 40)
	assert_eq(m.thresholds_for("left")[6000], 45)
	assert_eq(sim.respond_sin(10, {"id": "x", "text": "No key words here."}), {}, "an item without key words")


func test_the_model_holds_its_sim_weakly() -> void:
	var m := _orphan_model()
	assert_true(m != null, "the model outlives its sim")
	assert_true(m.sim() == null, "the sim is gone")
	assert_eq(m.respond_sin(10, SpeechMaterial.item("party_1", "p1_1")), {}, "no sim, no answer")
	assert_true(m.miss_weights(SpeechMaterial.item("party_1", "p1_1")).is_empty(), "no sim, no weights")
	assert_eq(m.true_snr_loss(), 0.0)


static func _orphan_model() -> SinModel:
	var sim := SpeechSim.new(_marco(), 5)
	return sim.sin_model() as SinModel
