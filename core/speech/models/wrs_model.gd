class_name WrsModel
extends RefCounted
## WrsModel: how the patient repeats one-syllable words (Day 4, CONTRACTS.md §9.12.1, docs/SPEECH.md
## §4). SpeechSim loads it by path (wrs_model()) and forwards its WRS facade here, so no shared file
## names this class. It holds the sim through a WeakRef (no reference cycle) and reads only the sim's
## profile, rng, transducer, mask_db, true_srt(), cochlear_srt(), ia(), air() and delay_for(): every
## random draw uses sim.rng, so a seed replays a visit exactly.
##
## The chance of a word at level L (truth):
##   test ear:  wrs_max x wrs_audibility(L, srt_eff) - rollover_drop(L), srt_eff = max(SRT, noise - IA)
##              (the noise term only matters when the noise crosses back to the test ear: overmasking)
##   other ear: the same at L - IA, against its cochlear SRT, or the noise when it is masked (0 once
##              the noise reaches the crossed level: masked out)
##   either:    1 - (1 - test) x (1 - cross)
## A list is dealt whole at its first word (D4): round(p x 25) words, plus -1, 0, 0 or +1 (one draw
## per list), for the test ear alone and for either ear, so an unmasked list is as repeatable as a
## masked one. A cochlear ear misses the words whose key sound sits lowest under its TRUE thresholds
## (the banana); a neural ear misses at random. A miss sounds like a rhyme (a foil), silence, or, for
## a neural ear, another word of the list. The answer styles (D20) change only what she says, never
## the deal or the count.

## Lines for a chatty hit when the plan gives none ({word} is filled; 6 words or fewer).
const CHATTER: PackedStringArray = ["That one came through.", "Easy one!", "Clear as day."]
## The answer styles respond_wrs() knows. chatty_hit, plural_trap and self_correct are D20's (the
## mode passes them for the player's words only); aside forces the aside foil on the word the deal
## named aside_target (aside_by), so Hoot's side line always lands.
const STYLES: Array[StringName] = [&"chatty_hit", &"plural_trap", &"self_correct", &"aside"]

var _sim: WeakRef


func _init(s: SpeechSim) -> void:
	_sim = weakref(s)


## The sim this model belongs to, or null once it is gone.
func sim() -> SpeechSim:
	return _sim.get_ref() as SpeechSim


static func _other(ear: String) -> String:
	return "left" if ear == "right" else "right"


# ---------------------------------------------------------------- truth

## The ear's word score ceiling in quiet at a fully audible level (0..100): speech.wrs_max, else
## predicted_wrs_max of the ear's TRUE thresholds.
func true_wrs_max(ear: String) -> float:
	var s := sim()
	if s == null or s.profile == null:
		return 0.0
	var given: Variant = s.profile.speech_value("wrs_max", ear)
	if given != null:
		return clampf(float(given), 0.0, 100.0)
	return float(SpeechRules.predicted_wrs_max(s.air(ear)))


## The test ear's own chance of a word at `level` (0..1).
func p_wrs_test(ear: String, level: int) -> float:
	var s := sim()
	if s == null or s.profile == null:
		return 0.0
	var a := SpeechRules.wrs_audibility(float(level), _srt_eff(s, ear))
	return clampf(true_wrs_max(ear) / 100.0 * a - SpeechRules.rollover_drop(_rollover(s, ear), float(level)), 0.0, 1.0)


## The other cochlea's chance of the same word: crossed speech arrives IA softer, and the noise in
## that ear (dB EM) lifts its threshold to the noise level. Noise at or above the crossed level masks
## the word out (0): effective masking X dB EM covers speech at X dB HL, so a list masked by the rule
## never has a word stolen (without this cut a tiny leftover chance can tip a list's rounding: Nora's
## left at 100 with noise 70).
func p_wrs_cross(ear: String, level: int) -> float:
	var s := sim()
	if s == null or s.profile == null:
		return 0.0
	var o := _other(ear)
	var lx := float(level) - s.ia()
	var srt_x := s.cochlear_srt(o)
	if s.mask_db >= 0:
		if float(s.mask_db) >= lx:
			return 0.0
		srt_x = maxf(srt_x, float(s.mask_db))
	var a := SpeechRules.wrs_audibility(lx, srt_x)
	return clampf(true_wrs_max(o) / 100.0 * a - SpeechRules.rollover_drop(_rollover(s, o), lx), 0.0, 1.0)


## Either cochlea: 1 - (1 - test) x (1 - cross).
func p_wrs(ear: String, level: int) -> float:
	return 1.0 - (1.0 - p_wrs_test(ear, level)) * (1.0 - p_wrs_cross(ear, level))


## The test ear's SRT as the word sees it: the noise in the other ear leaks back IA softer.
static func _srt_eff(s: SpeechSim, ear: String) -> float:
	var srt := float(s.true_srt(ear))
	if s.mask_db >= 0:
		srt = maxf(srt, float(s.mask_db) - s.ia())
	return srt


static func _rollover(s: SpeechSim, ear: String) -> Dictionary:
	var r: Variant = s.profile.speech_value("rollover", ear, {})
	return r if r is Dictionary else {}


func _neural(s: SpeechSim, ear: String) -> bool:
	return bool(s.profile.speech_value("neural", ear, false))


# ---------------------------------------------------------------- the deal

## One whole list's outcomes at `level` (dealt at its first PRESENT; the level and the noise are
## locked from then on). `items` are the list's words in play order. opts:
##   ensure_audible_miss_by a: one dealt miss in places 2..a lands on a word that is fully audible on
##     opts.audible_thresholds (the MEASURED thresholds the lens uses; the true ones when missing),
##     by swapping the first audible hit there with the last miss outside: the Call it word;
##   aside_by b: the first word in places 1..b with `asides` is a miss (swapped with the last miss
##     after place b that is not the audible word): its answer is the aside foil (style &"aside").
## Neither changes a count. Returns {outcomes: Array[StringName] (&"test" / &"cross" / &"miss", one
## per item), n, k_test, k_total, jitter, p_test, p_cross, p_total, level, mask_db, neural,
## audible_target (item index, -1 none), aside_target (-1 none)}.
func deal_wrs_list(ear: String, level: int, items: Array, opts: Dictionary = {}) -> Dictionary:
	var s := sim()
	var n := items.size()
	var pt := p_wrs_test(ear, level)
	var pc := p_wrs_cross(ear, level)
	var p := 1.0 - (1.0 - pt) * (1.0 - pc)
	var outcomes: Array[StringName] = []
	outcomes.resize(n)
	outcomes.fill(&"test")
	var out := {"outcomes": outcomes, "n": n, "k_test": n, "k_total": n, "jitter": 0, "p_test": pt, "p_cross": pc,
		"p_total": p, "level": level, "mask_db": s.mask_db if s != null else -1, "neural": false,
		"audible_target": -1, "aside_target": -1}
	if s == null or s.profile == null or n == 0:
		return out
	var jitter := SpeechRules.WRS_DEAL_JITTER[s.rng.randi_range(0, SpeechRules.WRS_DEAL_JITTER.size() - 1)]
	var k_test := SpeechRules.wrs_deal_count(pt, n, jitter)
	var k_total := SpeechRules.wrs_deal_count(p, n, jitter, k_test)
	var neural := _neural(s, ear)
	# which words the test ear misses: by weight, without replacement
	var truth := s.air(ear)
	var weights: Array[float] = []
	for it: Variant in items:
		var key := String((it as Dictionary).get("key_sound", "")) if it is Dictionary else ""
		weights.append(1.0 if neural else SpeechRules.wrs_miss_weight(SpeechRules.sound_margin(key, float(level), truth)))
	var pool: Array[int] = []
	for i in n:
		pool.append(i)
	for _m in n - k_test:
		var total := 0.0
		for i: int in pool:
			total += weights[i]
		var r := s.rng.randf() * total
		var pick := pool.size() - 1
		for j in pool.size():
			r -= weights[pool[j]]
			if r < 0.0:
				pick = j
				break
		outcomes[pool[pick]] = &"miss"
		pool.remove_at(pick)
	var aside_i := _aside_item(items, int(opts.get("aside_by", 0)))
	var audible := _ensure_audible_miss(outcomes, items, level, opts, truth, aside_i)
	var aside := _ensure_aside_miss(outcomes, aside_i, int(opts.get("aside_by", 0)), audible)
	# cross hits: some test-ear misses the other cochlea catches (never the two named words)
	var misses: Array[int] = []
	for i in n:
		if outcomes[i] == &"miss" and i != audible and i != aside:
			misses.append(i)
	var crossed := mini(k_total - k_test, misses.size())
	for _c in crossed:
		var pick := s.rng.randi_range(0, misses.size() - 1)
		outcomes[misses[pick]] = &"cross"
		misses.remove_at(pick)
	out.merge({"k_test": k_test, "k_total": k_test + crossed, "jitter": jitter, "neural": neural,
		"audible_target": audible, "aside_target": aside}, true)
	return out


## The first item in places 1..b that has asides (-1: none, or b is 0).
static func _aside_item(items: Array, b: int) -> int:
	for i in mini(b, items.size()):
		var it: Variant = items[i]
		if it is Dictionary and not ((it as Dictionary).get("asides", {}) as Dictionary).is_empty():
			return i
	return -1


## ensure_audible_miss_by: returns the audible miss in places 2..a (-1: no audible word there).
static func _ensure_audible_miss(outcomes: Array[StringName], items: Array, level: int, opts: Dictionary,
		truth: Dictionary, skip: int) -> int:
	var a := mini(int(opts.get("ensure_audible_miss_by", 0)), outcomes.size())
	if a < 2:
		return -1
	var given: Variant = opts.get("audible_thresholds", {})
	var thr: Dictionary = given if given is Dictionary and not (given as Dictionary).is_empty() else truth
	var hit := -1
	for i in range(1, a):
		if i == skip or not SpeechRules.word_fully_audible(items[i], float(level), thr):
			continue
		if outcomes[i] == &"miss":
			return i
		if hit < 0:
			hit = i
	if hit < 0:
		return -1
	# swap with the last miss outside the window (else the last one inside it: none is audible)
	var swap := -1
	for i in range(outcomes.size() - 1, -1, -1):
		if outcomes[i] == &"miss" and (i < 1 or i >= a) and i != skip:
			swap = i
			break
	if swap < 0:
		for i in range(a - 1, 0, -1):
			if outcomes[i] == &"miss" and i != skip:
				swap = i
				break
	if swap < 0:
		return -1
	outcomes[swap] = &"test"
	outcomes[hit] = &"miss"
	return hit


## aside_by: makes the aside word a miss; returns it (-1: none, or no miss to trade with).
static func _ensure_aside_miss(outcomes: Array[StringName], aside_i: int, b: int, audible: int) -> int:
	if aside_i < 0:
		return -1
	if outcomes[aside_i] == &"miss":
		return aside_i
	var swap := -1
	for i in range(outcomes.size() - 1, -1, -1):
		if outcomes[i] == &"miss" and i != audible and i >= b:
			swap = i
			break
	if swap < 0:
		for i in range(outcomes.size() - 1, -1, -1):
			if outcomes[i] == &"miss" and i != audible:
				swap = i
				break
	if swap < 0:
		return -1
	outcomes[swap] = &"test"
	outcomes[aside_i] = &"miss"
	return aside_i


# ---------------------------------------------------------------- one answer

## The shares of a miss (foil / silence / other): WRS_MISS_COCHLEAR or WRS_MISS_NEURAL. A word too
## soft to make out (audibility under 0.5) is met with silence at least 1 - A of the time; the other
## shares shrink in proportion.
static func miss_shares(neural: bool, audibility: float) -> Dictionary:
	var out: Dictionary = (SpeechRules.WRS_MISS_NEURAL if neural else SpeechRules.WRS_MISS_COCHLEAR).duplicate()
	if audibility < 0.5:
		var sil := maxf(float(out[&"silence"]), 1.0 - audibility)
		var rest := 1.0 - float(out[&"silence"])
		for k: StringName in out:
			if k != &"silence":
				out[k] = float(out[k]) / rest * (1.0 - sil) if rest > 0.0 else 0.0
		out[&"silence"] = sil
	return out


## The patient's answer to one word with its dealt `outcome` (&"test" / &"cross" = she repeats it,
## anything else = a miss). `list_items` are the list's words (a neural "other" word comes from
## them), `silences` her "no answer" lines (else SpeechSim.SILENCES), `style` one of STYLES or &""
## (a style that does not fit the outcome or the item is ignored), `chatter` her chatty-hit lines.
## Returns {text, correct, kind (&"correct" / &"wrong" / &"silence"), heard_by, delay_s, p, rhyme,
## trap, style, key_sound, margin_db, aside}; correct, kind, heard_by and margin_db are truth.
func respond_wrs(ear: String, level: int, item: Dictionary, outcome: StringName, list_items: Array = [],
		silences: PackedStringArray = PackedStringArray(), style: StringName = &"",
		chatter: PackedStringArray = PackedStringArray()) -> Dictionary:
	var s := sim()
	if s == null or s.profile == null:
		return {}
	var p := p_wrs(ear, level)
	var word := String(item.get("text", "?"))
	var key := String(item.get("key_sound", ""))
	var foils: Array = item.get("foils", [])
	var out := {"text": "", "correct": false, "kind": &"silence", "heard_by": &"", "delay_s": 0.0, "p": p,
		"rhyme": false, "trap": false, "style": &"", "key_sound": key,
		"margin_db": SpeechRules.sound_margin(key, float(level), s.air(ear)), "aside": ""}
	if outcome == &"test" or outcome == &"cross":
		out.merge({"correct": true, "kind": &"correct", "heard_by": outcome}, true)
		out["text"] = _up(word) + ("!" if p > 0.9 else ".")
		if style == &"chatty_hit":
			var lines := chatter if not chatter.is_empty() else CHATTER
			var line := lines[s.rng.randi_range(0, lines.size() - 1)].replace("{word}", word.to_lower())
			out.merge({"text": "%s! %s" % [_up(word), line], "style": style}, true)
		elif style == &"self_correct" and not foils.is_empty():
			var foil := String(foils[s.rng.randi_range(0, foils.size() - 1)])
			out.merge({"text": "%s... no, %s!" % [_up(foil), word.to_upper()], "style": style}, true)
	else:
		var asides: Dictionary = item.get("asides", {})
		var plural := String(item.get("plural", ""))
		if style == &"plural_trap" and not plural.is_empty():
			out.merge({"text": SpeechSim.as_question(plural), "kind": &"wrong", "trap": true, "style": style}, true)
		elif style == &"aside" and not _aside_foil(foils, asides).is_empty():
			var foil := _aside_foil(foils, asides)
			out.merge({"text": SpeechSim.as_question(foil), "kind": &"wrong", "rhyme": true, "style": style,
				"aside": String(asides[foil.to_lower()])}, true)
		else:
			_miss(s, ear, level, item, list_items, silences, out)
	out["delay_s"] = s.delay_for(p)
	return out


## A plain miss: a foil, silence or (a neural ear) another word of the list, by miss_shares().
func _miss(s: SpeechSim, ear: String, level: int, item: Dictionary, list_items: Array,
		silences: PackedStringArray, out: Dictionary) -> void:
	var shares := miss_shares(_neural(s, ear), SpeechRules.wrs_audibility(float(level), _srt_eff(s, ear)))
	var foils: Array = item.get("foils", [])
	var r := s.rng.randf()
	var kind := &"silence"
	if r < float(shares.get(&"foil", 0.0)):
		kind = &"foil"
	elif r < float(shares.get(&"foil", 0.0)) + float(shares.get(&"other", 0.0)):
		kind = &"other"
	var others: Array[String] = []
	if kind == &"other":
		var banned := {String(item.get("text", "")).to_lower(): true}
		for f: Variant in foils:
			banned[String(f).to_lower()] = true
		for o: Variant in list_items:
			var t := String((o as Dictionary).get("text", "")) if o is Dictionary else ""
			if not t.is_empty() and not banned.has(t.to_lower()):
				others.append(t)
		if others.is_empty():
			kind = &"foil"
	if kind == &"foil" and foils.is_empty():
		kind = &"silence"
	match kind:
		&"foil":
			var foil := String(foils[s.rng.randi_range(0, foils.size() - 1)])
			var asides: Dictionary = item.get("asides", {})
			out.merge({"text": SpeechSim.as_question(foil), "kind": &"wrong", "rhyme": true,
				"aside": String(asides.get(foil.to_lower(), ""))}, true)
		&"other":
			out.merge({"text": SpeechSim.as_question(others[s.rng.randi_range(0, others.size() - 1)]),
				"kind": &"wrong"}, true)
		_:
			var lines := silences if not silences.is_empty() else SpeechSim.SILENCES
			out.merge({"text": lines[s.rng.randi_range(0, lines.size() - 1)], "kind": &"silence"}, true)


## The foil with an aside line (as written in foils), or "".
static func _aside_foil(foils: Array, asides: Dictionary) -> String:
	for f: Variant in foils:
		if asides.has(String(f).to_lower()):
			return String(f)
	return ""


static func _up(w: String) -> String:
	return w.left(1).to_upper() + w.substr(1)
