class_name SinModel
extends RefCounted
## SinModel: how the patient answers one party sentence in babble (CONTRACTS.md §9.12.2,
## docs/CHAPTER5.md §5.6). SpeechSim loads it by path on first use (sin_model()) and forwards its SIN
## facade calls here, so no shared file names this class. It holds the sim through a WeakRef (no
## reference cycle) and reads only the sim's profile, rng, condition, air() and delay_for(); every
## random draw uses sim.rng, so a seed replays a visit exactly.
##
## How many key words: expected = SpeechRules.sin_expected_words(snr, effective SNR loss), dithered by
## sin_count (never more than one away, exact on average). Which ones: misses are drawn by
## key_word_miss_weight, so words with soft, high sounds near the patient's thresholds go first. What
## he says: the sentence with each heard key word as written and each missed one a mishear from the
## item, a filler or nothing. When the noise wins, half the answers are one of the plan's lost lines.
## heard, count, expected and loss_eff are truth: checks, the reveal and Hoot only, never shown as data.

## What a missed key word may become instead of a mishear ("The sleepy something chewed...").
const FILLERS: PackedStringArray = ["something", "mm", "whatsit"]
## A mishear group with both a trap (a plural or tense change) and a sound-alike gives the trap this
## often (a group of traps only always gives a trap).
const TRAP_SHARE := 0.2
## A dropped key word reads as this in the answer.
const DROPPED := "..."
## The words of a sentence, as SpeechMaterial.tokens() finds them (with their places in the text).
const WORD_PATTERN := "[a-z0-9]+(?:['-][a-z0-9]+)*"

var _sim: WeakRef
## The lost line said last (never twice in a row); -1 = none yet.
var _last_lost := -1
## Per sentence, talker level and ear: the key words' miss weights on the true thresholds. Truth is
## fixed for a visit, so each is worked out once ({"<sentence hash>|<level>|<ear>": Array[float]}).
var _weights: Dictionary = {}
## The true thresholds the weights read, per ear ("right", "left", "both").
var _thresholds: Dictionary = {}
## Per sentence (by its content hash): what only the item decides, shared by every model (_sentence).
static var _sentences: Dictionary = {}
static var _word_re: RegEx = null


func _init(s: SpeechSim) -> void:
	_sim = weakref(s)


## The sim that made this model, or null once it is gone.
func sim() -> SpeechSim:
	return _sim.get_ref() as SpeechSim


# ---------------------------------------------------------------- truth

## The unaided SNR loss (dB). speech.snr_loss: a number for both ears, or {ear: dB} ("both" = the
## lower ear). Missing: estimated_snr_loss of the ear's true thresholds ("both": the better ear's).
func true_snr_loss(ear: String = "both") -> float:
	var s := sim()
	if s == null or s.profile == null:
		return 0.0
	var given: Variant = s.profile.speech_value("snr_loss")
	if given is float or given is int:
		return maxf(0.0, float(given))
	var one := ear == "right" or ear == "left"
	if given is Dictionary:
		var d: Dictionary = given
		if one:
			return float(d[ear]) if d.has(ear) else _estimated(ear)
		var r := float(d["right"]) if d.has("right") else _estimated("right")
		var l := float(d["left"]) if d.has("left") else _estimated("left")
		return maxf(0.0, minf(r, l))
	return _estimated(ear if one else better_ear())


## The SNR loss in the sim's condition: the unaided loss, minus speech.directional_benefit
## (SIN_DIRECTIONAL_BENEFIT_DB by default) under &"directional", never below 0. OMNI wins nothing.
func effective_snr_loss(ear: String = "both") -> float:
	var loss := true_snr_loss(ear)
	var s := sim()
	if s != null and s.condition == &"directional":
		var benefit := SpeechRules.SIN_DIRECTIONAL_BENEFIT_DB
		if s.profile != null:
			benefit = float(s.profile.speech_value("directional_benefit", "", benefit))
		loss = maxf(0.0, loss - benefit)
	return loss


## The chance of one key word at this SNR: sin_expected_words(snr, effective loss) / 5.
func p_key_word(snr: float, ear: String = "both") -> float:
	return SpeechRules.sin_expected_words(snr, effective_snr_loss(ear)) / float(SpeechRules.SIN_KEY_WORDS)


## The ear with the better (lower) true speech PTA ("right" on a tie).
func better_ear() -> String:
	var s := sim()
	if s == null:
		return "right"
	return SpeechRules.better_ear(SpeechRules.pta_for_speech(s.air("right")), SpeechRules.pta_for_speech(s.air("left")))


## The TRUE thresholds the misses are weighed on: the ear's, or for "both" the better of the two
## ears at each frequency.
func thresholds_for(ear: String) -> Dictionary:
	var s := sim()
	if s == null:
		return {}
	if ear == "right" or ear == "left":
		return s.air(ear)
	var r := s.air("right")
	var l := s.air("left")
	var out := {}
	for f: int in r:
		out[f] = mini(int(r[f]), int(l[f])) if l.has(f) else int(r[f])
	for f: int in l:
		if not out.has(f):
			out[f] = int(l[f])
	return out


## Each key word's miss weight in this sentence for this ear and talker level (truth: tests and
## the reveal only); empty once the sim is gone.
func miss_weights(item: Dictionary, level: int = SpeechRules.SIN_LEVEL_DB, ear: String = "both") -> Array[float]:
	var out: Array[float] = []
	var sent := _sentence(item)
	if sim() != null and not sent.is_empty():
		out.assign(_weights_for(sent, level, ear))
	return out


func _estimated(ear: String) -> float:
	var s := sim()
	return SpeechRules.estimated_snr_loss(s.air(ear)) if s != null else 0.0


# ---------------------------------------------------------------- one sentence

## The patient's answer to one party sentence at `snr` with the talker at `level` dB HL. opts:
## lost_lines (Array of String, the patient's noise-wins lines). Returns {text, heard (5), said_words
## (5, "" when dropped), said_kinds (5: &"heard" / &"mishear" / &"trap" / &"filler" / &"drop"), count,
## expected, kind (&"all" / &"partial" / &"none" / &"lost"), delay_s, snr, loss_eff, little_swap,
## traps (5)}; {} for an item without key words.
func respond_sin(snr: int, item: Dictionary, level: int = SpeechRules.SIN_LEVEL_DB,
		ear: String = "both", opts: Dictionary = {}) -> Dictionary:
	var s := sim()
	if s == null:
		return {}
	var sent := _sentence(item)
	if sent.is_empty():
		return {}
	var words: Array[String] = sent["words"]
	var n := words.size()
	var loss := effective_snr_loss(ear)
	var expected := SpeechRules.sin_expected_words(float(snr), loss)
	var count := mini(SpeechRules.sin_count(expected, s.rng.randf()), n)
	var out := {"snr": snr, "loss_eff": loss, "expected": expected, "count": count, "little_swap": false}
	# the noise wins: half the time a whole line of the patient's own instead of the sentence
	var lost: Array = opts.get("lost_lines", [])
	if count == 0 and expected < SpeechRules.SIN_LOST_EXPECTED and not lost.is_empty() \
			and s.rng.randf() < SpeechRules.SIN_LOST_SHARE:
		var pick := _pick_lost(lost.size(), s.rng)
		_last_lost = pick
		out.merge(_blank(n), true)
		out["text"] = String(lost[pick])
		out["kind"] = &"lost"
		out["delay_s"] = s.delay_for(expected / float(SpeechRules.SIN_KEY_WORDS))
		return out
	# which key words he misses: the soft, high ones near his thresholds first
	var missed := _draw_misses(_weights_for(sent, level, ear), n - count, s.rng)
	# what he says for each key word
	var heard: Array[bool] = []
	var said: Array[String] = []
	var kinds: Array[StringName] = []
	var traps: Array[bool] = []
	var groups: Array[Dictionary] = sent["groups"]
	var share_mishear := float(SpeechRules.SIN_MISS_SHARES[&"mishear"])
	var share_filler := float(SpeechRules.SIN_MISS_SHARES[&"filler"])
	for i in n:
		var said_kind: StringName = &"heard"
		var said_word := words[i]
		if missed[i]:
			var group := groups[i]
			var r := s.rng.randf()
			if r < share_mishear and int(group["size"]) > 0:
				var trap_words: Array[String] = group["traps"]
				var others: Array[String] = group["others"]
				var as_trap := not trap_words.is_empty() and (others.is_empty() or s.rng.randf() < TRAP_SHARE)
				var pool := trap_words if as_trap else others
				said_word = pool[s.rng.randi_range(0, pool.size() - 1)]
				said_kind = &"trap" if as_trap else &"mishear"
			elif r < share_mishear + share_filler:
				# (an item without mishears gives a filler instead)
				said_word = FILLERS[s.rng.randi_range(0, FILLERS.size() - 1)]
				said_kind = &"filler"
			else:
				said_word = ""
				said_kind = &"drop"
		heard.append(not missed[i])
		said.append(said_word)
		kinds.append(said_kind)
		traps.append(said_kind == &"trap")
	var built := _answer_text(sent, said, kinds, s.rng)
	out["text"] = String(built["text"])
	out["little_swap"] = bool(built["little_swap"])
	out["heard"] = heard
	out["said_words"] = said
	out["said_kinds"] = kinds
	out["traps"] = traps
	out["kind"] = &"all" if count == n else (&"none" if count == 0 else &"partial")
	out["delay_s"] = s.delay_for(expected / float(SpeechRules.SIN_KEY_WORDS))
	return out


## What only the sentence decides, built once per item content: {hash, words (lowercase), sounds (each
## key word's: key_sounds, else its letters), groups [{traps, others, size}], text, toks [[start, end,
## lowercase]], key_at (the token of each key word, -1 when missing), little (the tokens a little-word
## swap may change)}. {} without key words.
static func _sentence(item: Dictionary) -> Dictionary:
	var h := item.hash()
	if _sentences.has(h):
		return _sentences[h]
	var words := _key_words(item)
	if words.is_empty():
		return {}
	var text := String(item.get("text", ""))
	var sounds: Array[PackedStringArray] = []
	var groups: Array[Dictionary] = []
	var given: Variant = item.get("mishears", [])
	var mishears: Array = given if given is Array else []
	for i in words.size():
		var own := _sounds(item, i)
		sounds.append(own if not own.is_empty() else SpeechRules.key_word_sounds(words[i]))
		var trap_words: Array[String] = []
		var others: Array[String] = []
		if i < mishears.size() and mishears[i] is Array:
			for m: Variant in mishears[i]:
				var t := String(m).strip_edges()
				if t.is_empty():
					continue
				if SpeechRules.is_trap(t, words[i]):
					trap_words.append(t)
				else:
					others.append(t)
		groups.append({"traps": trap_words, "others": others, "size": trap_words.size() + others.size()})
	if _word_re == null:
		_word_re = RegEx.create_from_string(WORD_PATTERN)
	var toks: Array = []
	for m: RegExMatch in _word_re.search_all(text.to_lower().replace("’", "'")):
		toks.append([m.get_start(), m.get_end(), m.get_string()])
	# the token each key word sits at (in order, as SpeechMaterial.validate finds them)
	var key_at: Array[int] = []
	var is_key := {}
	var at := 0
	for w: String in words:
		var found := -1
		for j in range(at, toks.size()):
			if String(toks[j][2]) == w:
				found = j
				at = j + 1
				break
		key_at.append(found)
		if found >= 0:
			is_key[found] = true
	var little: Array[int] = []
	for j in toks.size():
		if not is_key.has(j) and SpeechRules.SIN_LITTLE_WORDS.has(String(toks[j][2])):
			little.append(j)
	var sent := {"hash": h, "words": words, "sounds": sounds, "groups": groups, "text": text, "toks": toks,
		"key_at": key_at, "little": little}
	_sentences[h] = sent
	return sent


## The key words' miss weights for this sentence at this talker level, on the ear's true thresholds
## (key_word_miss_weight), worked out once per visit.
func _weights_for(sent: Dictionary, level: int, ear: String) -> Array[float]:
	var key := "%d|%d|%s" % [int(sent["hash"]), level, ear]
	if _weights.has(key):
		return _weights[key]
	if not _thresholds.has(ear):
		_thresholds[ear] = thresholds_for(ear)
	var thr: Dictionary = _thresholds[ear]
	var words: Array[String] = sent["words"]
	var sounds: Array[PackedStringArray] = sent["sounds"]
	var out: Array[float] = []
	for i in words.size():
		out.append(SpeechRules.key_word_miss_weight(words[i], sounds[i], thr, float(level)))
	_weights[key] = out
	return out


## The item's key words in lowercase (the scorer's form).
static func _key_words(item: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var given: Variant = item.get("key_words", [])
	if given is Array:
		for w: Variant in given:
			out.append(String(w).strip_edges().to_lower())
	return out


## The item's key_sounds for key word i, or empty (key_word_miss_weight then reads the letters).
static func _sounds(item: Dictionary, i: int) -> PackedStringArray:
	var groups: Variant = item.get("key_sounds", [])
	if groups is Array and i < (groups as Array).size() and (groups as Array)[i] is Array:
		return PackedStringArray((groups as Array)[i])
	return PackedStringArray()


## k of the words marked missed, drawn by weight without replacement.
static func _draw_misses(weights: Array[float], k: int, rng: RandomNumberGenerator) -> Array[bool]:
	var missed: Array[bool] = []
	missed.resize(weights.size())
	missed.fill(false)
	for m in mini(k, weights.size()):
		var total := 0.0
		for i in weights.size():
			if not missed[i]:
				total += weights[i]
		var r := rng.randf() * total
		var pick := -1
		for i in weights.size():
			if missed[i]:
				continue
			pick = i
			r -= weights[i]
			if r < 0.0:
				break
		missed[pick] = true
	return missed


## Which lost line to say: any of `size`, never the last one twice in a row.
func _pick_lost(size: int, rng: RandomNumberGenerator) -> int:
	if size <= 1:
		return 0
	if _last_lost < 0 or _last_lost >= size:
		return rng.randi_range(0, size - 1)
	var pick := rng.randi_range(0, size - 2)
	return pick + 1 if pick >= _last_lost else pick


## The fields of an answer in which nothing was heard (the lost lines).
static func _blank(n: int) -> Dictionary:
	var heard: Array[bool] = []
	var said: Array[String] = []
	var kinds: Array[StringName] = []
	var traps: Array[bool] = []
	for i in n:
		heard.append(false)
		said.append("")
		kinds.append(&"drop")
		traps.append(false)
	return {"heard": heard, "said_words": said, "said_kinds": kinds, "traps": traps}


## The answer: the sentence with each key word replaced by what he said for it (a heard one stays as
## written), and SIN_LITTLE_SWAP_SHARE of the time one little word swapped; "a" / "an" follow a
## changed next word ("an angry bear", "a whatsit balloon"). An answer with a miss ends as a
## question. Returns {text, little_swap}.
static func _answer_text(sent: Dictionary, said: Array[String], kinds: Array[StringName],
		rng: RandomNumberGenerator) -> Dictionary:
	var text := String(sent["text"])
	var toks: Array = sent["toks"]
	var key_at: Array[int] = sent["key_at"]
	var repl := {}
	for i in key_at.size():
		var j := key_at[i]
		if j < 0 or kinds[i] == &"heard":
			continue
		if kinds[i] == &"drop":
			repl[j] = DROPPED
		elif kinds[i] == &"filler":
			repl[j] = said[i]
		else:
			repl[j] = _match_case(said[i], _orig(text, toks[j]))
	# one little word swapped now and then: little words never count, either way
	var swapped := false
	if rng.randf() < SpeechRules.SIN_LITTLE_SWAP_SHARE:
		var spots: Array[int] = sent["little"]
		if not spots.is_empty():
			var j := spots[rng.randi_range(0, spots.size() - 1)]
			var little := String(SpeechRules.SIN_LITTLE_WORDS[String(toks[j][2])])
			repl[j] = _match_case(little, _orig(text, toks[j]))
			swapped = true
	# "a" or "an" before a word that changed
	for j in toks.size() - 1:
		if not repl.has(j) and not repl.has(j + 1):
			continue
		var art := String(repl.get(j, toks[j][2])).to_lower()
		var next := String(repl.get(j + 1, toks[j + 1][2])).to_lower()
		if (art != "a" and art != "an") or next == DROPPED or next.is_empty():
			continue
		var want := "an" if "aeiou".contains(next.left(1)) else "a"
		if want != art:
			repl[j] = _match_case(want, String(repl.get(j, _orig(text, toks[j]))))
	# stitch the answer together
	var out := ""
	var pos := 0
	var skip_dot := false
	for j in toks.size():
		var gap := text.substr(pos, int(toks[j][0]) - pos)
		if skip_dot and gap.begins_with("."):
			gap = gap.substr(1)
		skip_dot = false
		out += gap
		if repl.has(j):
			out += String(repl[j])
			skip_dot = String(repl[j]) == DROPPED
		else:
			out += _orig(text, toks[j])
		pos = int(toks[j][1])
	var tail := text.substr(pos)
	if skip_dot and tail.begins_with("."):
		tail = tail.substr(1)
	out += tail
	out = out.strip_edges()
	if kinds.has(&"mishear") or kinds.has(&"trap") or kinds.has(&"filler") or kinds.has(&"drop"):
		# unsure: the full stop becomes a question mark ("...past the ...?")
		if out.ends_with(".") and not out.ends_with(DROPPED):
			out = out.left(out.length() - 1)
		out = SpeechSim.as_question(out)
	return {"text": out, "little_swap": swapped}


## A token as written in the text.
static func _orig(text: String, tok: Array) -> String:
	return text.substr(int(tok[0]), int(tok[1]) - int(tok[0]))


## `word` with its first letter up when `like` starts with a capital ("Monday" -> "Sunday"); else as
## written (so "Peru" keeps its capital).
static func _match_case(word: String, like: String) -> String:
	if word.is_empty() or like.is_empty():
		return word
	var first := like.left(1)
	if first != first.to_lower():
		return word.left(1).to_upper() + word.substr(1)
	return word
