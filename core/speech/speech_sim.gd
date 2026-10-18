class_name SpeechSim
extends RefCounted
## SpeechSim: how the patient answers speech (CONTRACTS.md §9.3, docs/SPEECH.md §3-5).
## It reads only the PatientProfile (thresholds and its `speech` truth) and never the player's ears.
##
## SRT (spondees): a word is repeated with probability
##   logistic((level - (SRT_true - SpeechRules.SRT_BIAS_DB)) / SpeechRules.SRT_SLOPE_DB)
## The true SRT is speech.srt[ear], or the ear's PTA (5 dB grid) + speech.srt_offset[ear].
## A miss is silence, half the word ("...bow?") or a wrong word (the item's own mishear, or
## another word of the list). speech.half_words sets how many misses are half words.
## Cross-hearing: unmasked speech also reaches the other cochlea, IA (the head's real one) softer;
## speech noise in the other ear (dB EM) lifts that cochlea's threshold to the noise level.

## Silence and "I didn't get that" answers (the bubble text).
const SILENCES: PackedStringArray = ["...", "Huh?", "Pardon?", "(shrugs)", "Sorry?"]
## Below this probability the word is lost completely: silence, or (rarely) half a word.
const LOST_P := 0.05
## Share of the misses that are a wrong word rather than silence (once half words are taken out).
const WRONG_SHARE := 0.55
## Extra hesitation near the SRT (seconds).
const NEAR_EXTRA_S := 0.35

var profile: PatientProfile
var rng := RandomNumberGenerator.new()
## The test condition, set by the session before each item.
var transducer: StringName = &"phones"
## Speech noise in the non-test ear (dB EM); -1 = off.
var mask_db: int = -1
## Which cochlea answered the last item: &"test", &"cross" or &"" (not heard). Truth: reactions and
## Hoot only, never shown to the player as data.
var last_heard_by: StringName = &""


func _init(p: PatientProfile, seed_value: int = 0) -> void:
	profile = p
	rng.seed = seed_value if seed_value != 0 else randi()


# ---------------------------------------------------------------- truth

## The ear's true SRT (dB HL, 5 dB grid). Scoring and the reveal only.
func true_srt(ear: String) -> int:
	if profile == null:
		return 0
	var given: Variant = profile.speech_value("srt", ear)
	if given != null:
		return int(given)
	var pta := SpeechRules.pta_for_speech(_air(ear))
	var offset := int(profile.speech_value("srt_offset", ear, 0))
	return SpeechRules.clamp_db(SpeechRules.snap5(pta) + offset)


## The SRT of the ear's cochlea (its air SRT minus the average air-bone gap at 500/1k/2k), for
## cross-hearing: crossed speech arrives by bone.
func cochlear_srt(ear: String) -> float:
	var gap := 0.0
	if profile != null and profile.has_bone_data():
		var n := 0
		for f: int in SpeechRules.PTA_FREQS:
			gap += float(profile.get_threshold(ear, f) - profile.get_bc_threshold(ear, f))
			n += 1
		gap /= maxf(1.0, float(n))
	return float(true_srt(ear)) - gap


func half_word_share() -> float:
	if profile == null:
		return SpeechRules.HALF_WORDS_DEFAULT
	return clampf(float(profile.speech_value("half_words", "", SpeechRules.HALF_WORDS_DEFAULT)), 0.0, 1.0)


func _air(ear: String) -> Dictionary:
	var out: Dictionary = {}
	if profile == null:
		return out
	var t := profile.get_thresholds(ear)
	for f: int in t:
		out[f] = t[f]
	return out


func _ia() -> float:
	return float(profile.get_ia(transducer)) if profile != null else 60.0


# ---------------------------------------------------------------- SRT

## Probability that the TEST ear's cochlea repeats a spondee at `level`.
func p_srt_test(ear: String, level: int) -> float:
	var srt := float(true_srt(ear))
	# overmasking: the noise in the other ear leaks back IA softer and lifts the test ear too
	if mask_db >= 0:
		srt = maxf(srt, float(mask_db) - _ia())
	return _logistic(float(level) - (srt - SpeechRules.SRT_BIAS_DB), SpeechRules.SRT_SLOPE_DB)


## Probability that the OTHER cochlea repeats it (cross-hearing; 0 when the noise covers it).
func p_srt_cross(ear: String, level: int) -> float:
	var other := "left" if ear == "right" else "right"
	var srt := cochlear_srt(other)
	if mask_db >= 0:
		srt = maxf(srt, float(mask_db))
	return _logistic(float(level) - _ia() - (srt - SpeechRules.SRT_BIAS_DB), SpeechRules.SRT_SLOPE_DB)


func p_srt(ear: String, level: int) -> float:
	var a := p_srt_test(ear, level)
	var b := p_srt_cross(ear, level)
	return 1.0 - (1.0 - a) * (1.0 - b)


## The patient's answer to one spondee at `level` in `ear`.
## Returns {text, correct, kind (&"correct" / &"half" / &"wrong" / &"silence"), heard_by, delay_s}.
## `others` is the rest of the list (wrong-word answers come from it or from the item's mishears).
func respond_srt(ear: String, level: int, it: Dictionary, others: Array = []) -> Dictionary:
	var pa := p_srt_test(ear, level)
	var pb := p_srt_cross(ear, level)
	var p := 1.0 - (1.0 - pa) * (1.0 - pb)
	var heard := rng.randf() < p
	var out := {"correct": heard, "heard_by": &"", "p": p}
	if heard:
		# which cochlea got it (for the Ghost and the lesson): the test ear whenever it would have
		# heard the word itself; "cross" only for a word the other cochlea alone caught
		# (P = (1 - pa) * pb / p), since crossed speech only matters when the test ear missed
		last_heard_by = &"cross" if rng.randf() * p >= pa else &"test"
		out["heard_by"] = last_heard_by
		out["kind"] = &"correct"
		out["text"] = String(it.get("text", "?")).capitalize() + ("!" if p > 0.9 else ".")
	else:
		last_heard_by = &""
		var half := half_word_share()
		var r := rng.randf()
		if p < LOST_P:
			if r < half * 0.5:
				out["kind"] = &"half"
			else:
				out["kind"] = &"silence"
		elif r < half:
			out["kind"] = &"half"
		elif rng.randf() < WRONG_SHARE:
			out["kind"] = &"wrong"
		else:
			out["kind"] = &"silence"
		match out["kind"]:
			&"half":
				out["text"] = SpeechMaterial.half_word(it, rng.randf() < 0.4)
			&"wrong":
				out["text"] = _wrong_word(it, others)
			_:
				out["text"] = SILENCES[rng.randi_range(0, SILENCES.size() - 1)]
	out["delay_s"] = _delay(p)
	return out


func _wrong_word(it: Dictionary, others: Array) -> String:
	var mis: Array = it.get("mishears", [])
	if not mis.is_empty() and (others.is_empty() or rng.randf() < 0.7):
		return as_question(String(mis[rng.randi_range(0, mis.size() - 1)]))
	var pool: Array = []
	for o: Variant in others:
		if o is Dictionary and String((o as Dictionary).get("id", "")) != String(it.get("id", "")):
			pool.append(o)
	if pool.is_empty():
		return "Hmm?"
	var pick: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return as_question(String(pick.get("text", "")))


## A wrong word as the patient asks it: only the first letter up, and one "?" ("light... mouse?" ->
## "Light... mouse?", never "Light... Mouse??").
static func as_question(said: String) -> String:
	var t := said.strip_edges()
	if t.is_empty():
		return "?"
	t = t.left(1).to_upper() + t.substr(1)
	return t if t.ends_with("?") else t + "?"


## Seconds from the end of the word to the answer (the profile's reaction range, slower near SRT).
func _delay(p: float) -> float:
	var lo := profile.reaction_time_min_s if profile != null else 0.6
	var hi := profile.reaction_time_max_s if profile != null else 1.2
	var d := rng.randf_range(lo, maxf(lo, hi))
	if p > 0.2 and p < 0.85:
		d += NEAR_EXTRA_S
	return d


static func _logistic(x: float, slope: float) -> float:
	return 1.0 / (1.0 + exp(-x / maxf(0.1, slope)))
