class_name SpeechRules
extends RefCounted
## SpeechRules: the speech-audiometry rulebook for Days 3-5 (pure data + pure functions, no state).
##
## SRT (speech recognition threshold, ASHA's preferred term), WRS and the Party Noise Test (speech in
## babble). Every number is a teaching default that Steve reviews; docs/SPEECH.md explains each one.
## Speech constants live HERE, not in ClinicRules (docs/ADDING_A_CHAPTER.md). Sources: ASHA (1988)
## speech-threshold guidelines; Carhart (1971) and Martin et al. on PTA/SRT agreement; Dubno et al.
## (1995) for WRS against PTA; Killion et al. (2004) for the SNR-loss arithmetic (in-game scores are
## unnormed).

const TESTS: Array[StringName] = [&"srt", &"wrs", &"sin"]
const TEST_TITLES: Dictionary[StringName, String] = {
	&"srt": "Speech recognition threshold", &"wrs": "Word score", &"sin": "Party Noise Test",
}
const MIN_DB := -10
const MAX_DB := 100            ## the AudiOtron's speech output limit (phones)
const LEVEL_STEP_DB := 5
## "No SRT yet" (never a level: every level sits on the 5 dB grid).
const NO_SRT := -1

# ---------------------------------------------------------------- PTA

const PTA_FREQS: Array[int] = [500, 1000, 2000]
const STEEP_RANGE_DB := 20     ## 500/1k/2k spread this much or more -> best-two (Fletcher) average


## The 3-frequency average (500/1k/2k). NAN if any is missing.
static func pta3(thresholds: Dictionary) -> float:
	var vals := _pta_vals(thresholds)
	if vals.size() < PTA_FREQS.size():
		return NAN
	return (vals[0] + vals[1] + vals[2]) / 3.0


## The mean of the best (lowest) two of 500/1k/2k. NAN if fewer than two exist.
static func pta_best2(thresholds: Dictionary) -> float:
	var vals := _pta_vals(thresholds)
	if vals.size() < 2:
		return NAN
	vals.sort()
	return (vals[0] + vals[1]) / 2.0


## The PTA speech tests compare against: the 3-frequency average, or the best two when the three
## spread STEEP_RANGE_DB or more (a steep loss). NAN when the tones are missing.
static func pta_for_speech(thresholds: Dictionary) -> float:
	var vals := _pta_vals(thresholds)
	if vals.size() < PTA_FREQS.size():
		return pta_best2(thresholds)
	if vals.max() - vals.min() >= STEEP_RANGE_DB:
		return pta_best2(thresholds)
	return pta3(thresholds)


## "best two" when the PTA used is the Fletcher average, else "three".
static func pta_method(thresholds: Dictionary) -> String:
	var vals := _pta_vals(thresholds)
	return "best two" if vals.size() == PTA_FREQS.size() and vals.max() - vals.min() >= STEEP_RANGE_DB else "three"


static func _pta_vals(thresholds: Dictionary) -> Array[float]:
	var out: Array[float] = []
	for f: int in PTA_FREQS:
		if thresholds.has(f):
			out.append(float(thresholds[f]))
	return out


## The ear with the lower (better) PTA; "right" on a tie or when unknown.
static func better_ear(pta_right: float, pta_left: float) -> String:
	if is_nan(pta_left):
		return "right"
	if is_nan(pta_right):
		return "left"
	return "left" if pta_left < pta_right else "right"


## Nearest multiple of 5 (halves round up), on the speech dB grid.
static func snap5(db: float) -> int:
	return int(floor(db / 5.0 + 0.5)) * 5


static func clamp_db(db: int) -> int:
	return clampi(db, MIN_DB, MAX_DB)

# ---------------------------------------------------------------- SRT (Day 3)
# The speech recognition threshold, with spondees: two-part words said with equal stress on both
# parts, chosen because they are about equally easy to hear.

const SRT_START_ABOVE_PTA_DB := 15
const SRT_START_MIN_DB := 10   ## first word at PTA + 10 ...
const SRT_START_MAX_DB := 25   ## ... to PTA + 25
const SRT_DOWN_DB := 10        ## repeated it -> down 10
const SRT_DOWN_TOLERATED_DB := 5   ## down 5 is tolerated (some clinics drop 5 after every correct word)
const SRT_UP_DB := 5           ## missed it -> up 5
const SRT_MAX_WORDS_PER_LEVEL := 4  ## more words at one level are fine up to this many there (per ear)
## An ascending start (plan low_start_ok) begins at least this far BELOW the PTA, so the dial's
## default (the PTA itself) is never mistaken for one.
const SRT_LOW_START_BELOW_PTA_DB := 10
const SRT_MIN_CORRECT := 2     ## SRT needs at least two correct words at that level ...
const SRT_MIN_FRACTION := 0.5  ## ... and at least half right there
const SRT_PAR_SLACK := 1       ## par = the textbook dance on a perfectly steady patient + this (real ones wobble)
const AGREE_GOOD_DB := 6
const AGREE_FAIR_DB := 12
const AGREEMENTS: Array[StringName] = [&"good", &"fair", &"poor"]
const AGREEMENT_TITLES: Dictionary[StringName, String] = {
	&"good": "Good agreement", &"fair": "Fair agreement", &"poor": "Poor agreement",
}

## The patient model (docs/SPEECH.md §3).
const SRT_SLOPE_DB := 2.0      ## logistic scale of the spondee curve (steep: ~10 %/dB at the middle)
const SRT_BIAS_DB := 3.0       ## the 50 % point sits this far below the true SRT: a textbook search then stores
                               ## the true SRT about 2 times in 3, and 5 dB either side otherwise (like tones)
const HALF_WORDS_DEFAULT := 0.15


## Where an SRT should start: the PTA rounded to 5 dB, plus 15.
static func srt_start(pta: float) -> int:
	if is_nan(pta):
		return 40
	return clamp_db(snap5(pta) + SRT_START_ABOVE_PTA_DB)


## Is this a sensible first SRT word level for this PTA (PTA + 10 .. PTA + 25)?
static func srt_start_ok(db: int, pta: float) -> bool:
	if is_nan(pta):
		return true
	return float(db) >= pta + SRT_START_MIN_DB and float(db) <= pta + SRT_START_MAX_DB


## Is this first word an ascending start (as ASHA allows when answers look exaggerated): at least
## SRT_LOW_START_BELOW_PTA_DB below the PTA? false when the PTA is unknown.
static func srt_start_low(db: int, pta: float) -> bool:
	return not is_nan(pta) and float(db) <= pta - SRT_LOW_START_BELOW_PTA_DB


## The textbook next level after a word scored at `db`.
static func srt_next_level(db: int, correct: bool) -> int:
	return clamp_db(db - SRT_DOWN_DB if correct else db + SRT_UP_DB)


## Is `next_db` an acceptable step after a word at `db`? Returns &"textbook", &"tolerated" or &"wrong".
## `words_here` = the words already given at `db` in this ear (at least the one just scored): another
## word at the same level is tolerated, after a hit or a miss, while fewer than SRT_MAX_WORDS_PER_LEVEL
## were given there (SpeechSession._check_step counts them).
static func srt_step_verdict(db: int, correct: bool, next_db: int, words_here: int = 1) -> StringName:
	if next_db == srt_next_level(db, correct):
		return &"textbook"
	if correct and next_db == clamp_db(db - SRT_DOWN_TOLERATED_DB):
		return &"tolerated"
	# at the floor, staying put after a correct word is the only way down
	if correct and db <= MIN_DB and next_db == MIN_DB:
		return &"textbook"
	if next_db == db and words_here < SRT_MAX_WORDS_PER_LEVEL:
		return &"tolerated"
	return &"wrong"


## Per-level tallies from SRT trials: [{db, correct}] -> {db: [right, presented]}.
static func srt_tally(trials: Array) -> Dictionary:
	var out: Dictionary = {}
	for t: Dictionary in trials:
		var db := int(t["db"])
		var cell: Array = out.get(db, [0, 0])
		cell = [int(cell[0]) + (1 if bool(t["correct"]) else 0), int(cell[1]) + 1]
		out[db] = cell
	return out


static func _srt_level_passes(cell: Array) -> bool:
	return int(cell[0]) >= SRT_MIN_CORRECT and float(cell[0]) >= SRT_MIN_FRACTION * float(cell[1])


## The SRT the trials support right now: the lowest level with at least 2 correct and at least
## half correct, once the level 5 dB below it was tried and scored under half (the 50 % point is
## bracketed: "got it twice at 30, missed at 25: SRT 30"). -1 when there is none yet.
static func srt_candidate(trials: Array) -> int:
	var tally := srt_tally(trials)
	var levels: Array = tally.keys()
	levels.sort()
	for db: int in levels:
		if not _srt_level_passes(tally[db]):
			continue
		if db <= MIN_DB:
			return db   # nothing softer exists to bracket with
		var below := db - LEVEL_STEP_DB
		if tally.has(below):
			var c: Array = tally[below]
			if float(c[0]) < SRT_MIN_FRACTION * float(c[1]):
				return db
		return NO_SRT   # the lowest passing level is not bracketed yet
	return NO_SRT


## Same as srt_candidate, but ignores the bracket requirement: the lowest level that passes. -1 if none.
static func srt_lowest_passing(trials: Array) -> int:
	var tally := srt_tally(trials)
	var levels: Array = tally.keys()
	levels.sort()
	for db: int in levels:
		if _srt_level_passes(tally[db]):
			return db
	return NO_SRT


## Par for one SRT: the words a textbook dance needs from `start_db` on a perfectly steady patient
## (every word at or above the true SRT repeated, every softer one missed), plus SRT_PAR_SLACK.
static func srt_par(start_db: int, srt_true: int) -> int:
	return srt_textbook_words(start_db, srt_true) + SRT_PAR_SLACK


## The words a textbook SRT search takes on a steady patient, until srt_candidate() exists.
static func srt_textbook_words(start_db: int, srt_true: int) -> int:
	var trials: Array = []
	var db := clamp_db(start_db)
	for i in 60:
		var ok := db >= srt_true
		trials.append({"db": db, "correct": ok})
		if srt_candidate(trials) != NO_SRT:
			return trials.size()
		db = srt_next_level(db, ok)
	return trials.size()


## PTA/SRT agreement: |SRT - PTA| <= AGREE_GOOD_DB (6) good, <= AGREE_FAIR_DB (12) fair, else poor.
## The direction matters too (srt_pta_diff): an SRT much better than the PTA points to a non-organic
## loss; a worse one to the instructions, language or word recognition. (A steep slope can make words
## a little better than the three-tone average: pta_for_speech then uses the best two.)
static func agreement(srt: int, pta: float) -> StringName:
	if is_nan(pta) or srt == NO_SRT or srt < MIN_DB:
		return &""
	var d := absf(float(srt) - pta)
	if d <= AGREE_GOOD_DB:
		return &"good"
	if d <= AGREE_FAIR_DB:
		return &"fair"
	return &"poor"


## Signed difference SRT - PTA, rounded (negative = SRT better than the tones).
static func srt_pta_diff(srt: int, pta: float) -> int:
	return int(round(float(srt) - pta)) if not is_nan(pta) else 0

# ---------------------------------------------------------------- speech masking (all tests)

const SPEECH_IA_DB: Dictionary[StringName, int] = {&"phones": 40, &"inserts": 55}
const SPEECH_MASK_BELOW_DB := 20   ## speech noise at the presentation level minus 20 (rule of thumb)
## The air-bone gap that lifts the speech noise is the non-test ear's largest over these.
const SPEECH_ABG_FREQS: Array[int] = [500, 1000, 2000, 4000]


## Does speech at `level` in the test ear risk crossing to the other ear? `nontest_best` is the
## other ear's best bone threshold (or best air when no bone was measured) over 500-4000 Hz.
## Without bone results the rule uses air only: a temporary stand-in (docs/SPEECH.md §3).
static func speech_masking_needed(level: int, nontest_best: float, transducer: StringName = &"phones") -> bool:
	if is_nan(nontest_best):
		return false
	return float(level - int(SPEECH_IA_DB.get(transducer, 40))) >= nontest_best


## Speech noise (dB EM) for the other ear: the presentation level minus 20, plus the non-test ear's
## largest air-bone gap (`nontest_abg`, nontest_largest_abg(); 0 = no gap, or no bone measured),
## since a gap there needs that much more noise to reach its cochlea. Clamped to the masker's range.
## Without bone results the rule uses air only (no gap): a temporary stand-in.
static func speech_mask_level(level: int, nontest_abg: int = 0) -> int:
	return clampi(level - SPEECH_MASK_BELOW_DB + maxi(0, nontest_abg), ClinicRules.MASK_MIN_DB, ClinicRules.MASK_MAX_DB)


## The other ear's largest air-bone gap (best air minus best bone, masked where measured) over
## SPEECH_ABG_FREQS, from tone results §5.1. 0 when no bone was measured there (or no gap).
static func nontest_largest_abg(tone_results: Dictionary, test_ear: String) -> int:
	var other := "left" if test_ear == "right" else "right"
	var ac := ClinicRules.best_thresholds(tone_results, other, false)
	var bc := ClinicRules.best_thresholds(tone_results, other, true)
	var gap := 0
	for f: int in SPEECH_ABG_FREQS:
		if ac.has(f) and bc.has(f):
			gap = maxi(gap, ClinicRules.air_bone_gap(int(ac[f]), int(bc[f])))
	return gap


## The other ear's best bone (bone sheets) or else best air over 500-4000 Hz, from tone results §5.1.
## (The air-only fallback is a temporary stand-in until the speech days measure bone.)
static func nontest_best_threshold(tone_results: Dictionary, test_ear: String) -> float:
	var other := "left" if test_ear == "right" else "right"
	var best := INF
	for test: StringName in [&"bc_masked", &"bc"]:
		var t := ClinicRules.sheet_thresholds(tone_results, other, test)
		for f: int in t:
			if f >= 500 and f <= 4000:
				best = minf(best, float(t[f]))
	if best == INF:
		var ac := ClinicRules.sheet_thresholds(tone_results, other, &"ac")
		for f: int in ac:
			if f >= 500 and f <= 4000:
				best = minf(best, float(ac[f]))
	return best if best != INF else NAN

# ---------------------------------------------------------------- WRS (Day 4)

const WRS_ABOVE_PTA_DB := 35
const WRS_WINDOW_DB := 5        ## PTA + 30 .. PTA + 40
const WRS_MIN_DB := 55
const WRS_MIN_OK_DB := 50
const WRS_WORDS := 25
const WRS_BANDS: Array = [[90, &"excellent"], [78, &"good"], [66, &"fair"], [54, &"poor"]]
const WRS_BAND_BOTTOM: StringName = &"very_poor"
const WRS_BAND_TITLES: Dictionary[StringName, String] = {
	&"excellent": "Excellent", &"good": "Good", &"fair": "Fair", &"poor": "Poor", &"very_poor": "Very poor",
}
## (Day 3's tests only; no day uses it: Days 4-5 compare ears with wrs_differ.)
const WRS_ASYMMETRY_PCT := 20
## [PTA up to, minimum WRS expected]: a score below it is worse than the audiogram predicts.
## (Day 3's tests only; no day uses it: Days 4-5 read WRS_PREDICTED_MIN_25 through
## wrs_predicted_min_interp.)
const WRS_PREDICTED_MIN: Array = [[25, 88], [40, 76], [55, 64], [70, 48], [200, 0]]
const ROLLOVER_STEP_DB := 20
## (Not used by Days 4-5: they flag rollover by its index, ROLLOVER_INDEX_CUTOFF.)
const ROLLOVER_DROP_PCT := 20
## (Not used by Days 4-5.)
const ROLLOVER_INDEX_FLAG := 0.25
## WRS patient model (docs/SPEECH.md §4): whole-word audibility A(L) = logistic((L - (SRT + 12)) / 5).
const WRS_AUDIBLE_ABOVE_SRT_DB := 12.0
const WRS_AUDIBLE_SLOPE_DB := 5.0


## The comfortable WRS level: PTA + 35 rounded to 5 dB, at least 55, at most MAX_DB.
static func wrs_level(pta: float) -> int:
	if is_nan(pta):
		return WRS_MIN_DB
	return clampi(maxi(WRS_MIN_DB, snap5(pta + WRS_ABOVE_PTA_DB)), WRS_MIN_DB, MAX_DB)


## Is `db` inside the comfortable window (PTA + 30..40, at least 50)? The textbook level always is.
static func wrs_level_ok(db: int, pta: float) -> bool:
	if db == wrs_level(pta):
		return true
	if is_nan(pta):
		return db >= WRS_MIN_OK_DB and db <= 70
	var lo := maxf(float(WRS_MIN_OK_DB), pta + WRS_ABOVE_PTA_DB - WRS_WINDOW_DB)
	var hi := maxf(float(WRS_MIN_DB) + WRS_WINDOW_DB, pta + WRS_ABOVE_PTA_DB + WRS_WINDOW_DB)
	return float(db) >= lo and float(db) <= hi


static func wrs_band(pct: float) -> StringName:
	for b: Array in WRS_BANDS:
		if pct >= float(b[0]):
			return b[1]
	return WRS_BAND_BOTTOM


## The lowest score the PTA predicts (teaching table; check against your clinic's norms).
## (Day 3's tests only; no day uses it: Days 4-5 use wrs_predicted_min_interp.)
static func wrs_predicted_min(pta: float) -> int:
	if is_nan(pta):
		return 0
	for row: Array in WRS_PREDICTED_MIN:
		if pta <= float(row[0]):
			return int(row[1])
	return 0


## (Day 3's tests only; no day uses it.)
static func wrs_below_predicted(pct: float, pta: float) -> bool:
	return pct < float(wrs_predicted_min(pta))


## (Day 3's tests only; no day uses it: Days 4-5 use wrs_differ.)
static func wrs_asymmetric(pct_right: float, pct_left: float) -> bool:
	return absf(pct_right - pct_left) >= WRS_ASYMMETRY_PCT


## Rollover index (PBmax - PBmin) / PBmax over two or more scores; 0 when PBmax is 0.
## (Not used by Days 4-5: wrs_rollover takes PBmin only from a level above PBmax's.)
static func rollover_index(scores: Array) -> float:
	if scores.is_empty():
		return 0.0
	var mx := -INF
	var mn := INF
	for s: Variant in scores:
		mx = maxf(mx, float(s))
		mn = minf(mn, float(s))
	return (mx - mn) / mx if mx > 0.0 else 0.0


## Rollover: the louder score fell ROLLOVER_DROP_PCT points or more below the comfortable one.
## (Not used by Days 4-5: they flag rollover by its index, wrs_rollover.)
static func is_rollover(pct_comfortable: float, pct_louder: float) -> bool:
	return pct_comfortable - pct_louder >= ROLLOVER_DROP_PCT


## A whole word's audibility at a level for an ear with this SRT (0..1).
static func wrs_audibility(level: float, srt: float) -> float:
	return 1.0 / (1.0 + exp(-(level - (srt + WRS_AUDIBLE_ABOVE_SRT_DB)) / WRS_AUDIBLE_SLOPE_DB))


## The speech banana, simplified: each key sound -> [frequency of its cue (Hz), level below the overall
## speech level (dB)]. A sound is heard when level + offset reaches the threshold at its frequency.
const SOUND_CUES: Dictionary = {
	"s": [4000, -25], "f": [4000, -32], "th": [4000, -35], "z": [3000, -25], "v": [2000, -28],
	"sh": [2000, -15], "ch": [2000, -18], "j": [1500, -20],
	"t": [3000, -25], "k": [2000, -22], "p": [1500, -25], "h": [1500, -30],
	"b": [1000, -20], "d": [1500, -20], "g": [1500, -20],
	"m": [500, -15], "n": [500, -15], "ng": [500, -18],
	"l": [750, -12], "r": [1000, -12], "w": [500, -12], "y": [1000, -15],
	"vowel": [750, -5],
}


## How audible a key sound is (dB above the patient's threshold at its cue; negative = not heard).
static func sound_margin(sound: String, level: float, thresholds: Dictionary) -> float:
	var cue: Array = SOUND_CUES.get(sound, SOUND_CUES["vowel"])
	return level + float(cue[1]) - interp_threshold(thresholds, int(cue[0]))


## Threshold at any frequency, log-interpolated between the stored ones (nearest at the ends).
static func interp_threshold(thresholds: Dictionary, freq: int) -> float:
	if thresholds.has(freq):
		return float(thresholds[freq])
	var fs: Array = thresholds.keys()
	if fs.is_empty():
		return 0.0
	fs.sort()
	if freq <= int(fs[0]):
		return float(thresholds[fs[0]])
	if freq >= int(fs[fs.size() - 1]):
		return float(thresholds[fs[fs.size() - 1]])
	for i in fs.size() - 1:
		var a: int = fs[i]
		var b: int = fs[i + 1]
		if freq > a and freq < b:
			var k := (log(float(freq)) - log(float(a))) / (log(float(b)) - log(float(a)))
			return lerpf(float(thresholds[a]), float(thresholds[b]), k)
	return 0.0


## The WRS a cochlear ear should reach at a comfortable level when the profile gives none: full marks
## minus a share for every key sound that stays below threshold there (teaching estimate).
static func predicted_wrs_max(thresholds: Dictionary) -> int:
	var pta := pta_for_speech(thresholds)
	var level := float(wrs_level(pta))
	var lost := 0.0
	for s: String in SOUND_CUES:
		var m := sound_margin(s, level, thresholds)
		if m < 0.0:
			lost += clampf(-m / 15.0, 0.0, 1.0)
	return clampi(int(round(100.0 - lost * 4.0)), 30, 100)


## (Days 4-5) One ear's best bone per frequency over SPEECH_ABG_FREQS (D17): masked bone, else
## unmasked bone, else air (masked air where measured). {freq: dB}; a frequency with nothing
## measured is left out. The WRS noise rules read it: nontest_best_bone() for "is noise needed" and
## its lowest value on the test ear for the noise ceiling.
static func ear_best_bone(tone_results: Dictionary, ear: String) -> Dictionary:
	var masked := ClinicRules.sheet_thresholds(tone_results, ear, &"bc_masked")
	var bone := ClinicRules.sheet_thresholds(tone_results, ear, &"bc")
	var air := ClinicRules.best_thresholds(tone_results, ear, false)
	var out := {}
	for f: int in SPEECH_ABG_FREQS:
		if masked.has(f):
			out[f] = int(masked[f])
		elif bone.has(f):
			out[f] = int(bone[f])
		elif air.has(f):
			out[f] = int(air[f])
	return out


## (Days 4-5) The non-test ear's lowest best bone (D17): "is noise needed" for word lists (the SRT
## keeps nontest_best_threshold). NAN when nothing was measured there.
static func nontest_best_bone(tone_results: Dictionary, test_ear: String) -> float:
	var best := INF
	var t := ear_best_bone(tone_results, "left" if test_ear == "right" else "right")
	for f: int in t:
		best = minf(best, float(t[f]))
	return best if best != INF else NAN

# (Day 4) Word lists (CONTRACTS.md §9.11-§9.15, with the clinical amendments A1-A4). Four lists of
# 25 one-syllable words (core/speech/material/words_<n>.json), each with the same mix of key sounds,
# played in file order and handed out in play order. The word model (WrsModel) deals a whole list at
# its first word: round(p x 25) give or take one.

## The word lists, in play order (D25): right, left, then the next left list (redo or louder).
const WRS_LISTS: PackedStringArray = ["words_1", "words_2", "words_3", "words_4"]
## The key sounds of every list (25 words): high, soft sounds three and two times, the rest once.
const WRS_KEY_MIX: Dictionary[String, int] = {
	"s": 3, "f": 2, "th": 2, "t": 2, "k": 2, "sh": 1, "ch": 1, "z": 1, "v": 1, "p": 1, "b": 1, "d": 1, "g": 1,
	"m": 1, "n": 1, "l": 1, "r": 1, "w": 1, "h": 1,
}
## One draw per list: the dealt count is round(p x N) plus one of these (1/4, 1/2, 1/4).
const WRS_DEAL_JITTER: Array[int] = [-1, 0, 0, 1]
## Which words a cochlear ear misses: weight 1 / (1 + exp(margin / 4)) + 0.05 on its key sound.
const WRS_MISS_SCALE_DB := 4.0
const WRS_MISS_FLOOR := 0.05
## What a miss sounds like: a rhyme (foil), silence, or (a neural ear) another word of the list.
const WRS_MISS_COCHLEAR: Dictionary[StringName, float] = {&"foil": 0.80, &"silence": 0.20}
const WRS_MISS_NEURAL: Dictionary[StringName, float] = {&"foil": 0.60, &"silence": 0.25, &"other": 0.15}
## The louder list: 20 dB above the counted comfortable one (15-25 accepted), never past MAX_DB.
const WRS_LOUDER_DB := 20
const WRS_LOUDER_TOLERANCE_DB := 5
## A sound "reaches" the ear at 3 dB or more above its threshold; 0-3 dB is "only just" (D18).
const WRS_AUDIBLE_MARGIN_DB := 3.0
## The answer styles on the player's words (D20): about 1 hit in 3 comes back chatty, with at most
## this many words around the word; a self-correction counts its final answer.
const WRS_CHATTY_SHARE := 0.33
const WRS_CHATTY_MAX_WORDS := 6
const WRS_SELF_CORRECT_COUNTS := true
## The "chatting level" mark on the dial (the tea demo).
const CHAT_DB := 50
## The lens: a lost sound fades to LENS_MIN_ALPHA over LENS_FADE_DB below its threshold.
const LENS_FADE_DB := 15.0
const LENS_MIN_ALPHA := 0.15
## The lurking Ghost: GHOST_ALPHA_FLOOR at the first level that needs noise, plus 1 / 25 per dB above it.
const GHOST_ALPHA_FLOOR := 0.2
const GHOST_ALPHA_SPAN_DB := 25.0
## (A1) The lowest best-word-score (25-word list) that still fits the tones, by 3-frequency PTA: below it the score is
## disproportionately poor. A game approximation of Dubno et al. (1995)'s 95% lower limits, anchored on their 50-word
## value of 48% at a PTA of 50 dB; Steve replaces the rows with the published 25-word limits (CHAPTER4 open questions).
const WRS_PREDICTED_MIN_25: Array = [[0, 88], [20, 80], [30, 72], [40, 60], [50, 48], [60, 36], [70, 24], [80, 12]]
## (A2) Rollover: (PBmax - PBmin) / PBmax at this or more, with PBmin from a level above PBmax's
## (Jerger & Jerger's classic cut-off; Steve may lower it for his recorded list).
const ROLLOVER_INDEX_CUTOFF := 0.45
## (A3) Two word scores differ when their arcsine-transformed gap passes this z (95%): the
## critical differences of Thornton & Raffin (1978).
const WRS_CRIT_Z := 1.96


## (A1) The predicted minimum best score for this PTA, interpolated linearly between the rows of
## WRS_PREDICTED_MIN_25 and clamped outside them (PTA 41.67 -> 58.0). Lines say "{his} tones predict
## at least {min}%", never a source. 0 when the PTA is unknown (nothing to compare with).
static func wrs_predicted_min_interp(pta: float) -> float:
	if is_nan(pta):
		return 0.0
	var rows := WRS_PREDICTED_MIN_25
	if pta <= float(rows[0][0]):
		return float(rows[0][1])
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		if pta <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (pta - float(a[0])) / (float(b[0]) - float(a[0])))
	return float(rows[rows.size() - 1][1])


## Word-list noise (dB EM) for the other ear (D16, A4): the level minus 20, plus the other ear's
## largest air-bone gap, clamped to [level - IA, test-ear best bone + IA - 5] (IA = SPEECH_IA_DB of
## the transducer): enough to cover crossed words, never enough to cross back to the test ear. When
## the two limits cross (the masking dilemma), the ceiling wins. `bc_te_best` NAN: no ceiling.
static func wrs_mask_level(level: int, bc_te_best: float, transducer: StringName = &"phones", nontest_abg: int = 0) -> int:
	var ia := int(SPEECH_IA_DB.get(transducer, 40))
	var db := level - SPEECH_MASK_BELOW_DB + maxi(0, nontest_abg)
	db = maxi(db, level - ia)
	if not is_nan(bc_te_best):
		db = mini(db, int(floor(bc_te_best)) + ia - 5)
	return clampi(db, ClinicRules.MASK_MIN_DB, ClinicRules.MASK_MAX_DB)


## Was the word-list noise held below level - 20 (+ gap) by the ceiling (the wrs_mask_capped tip)?
static func wrs_mask_capped(level: int, bc_te_best: float, transducer: StringName = &"phones", nontest_abg: int = 0) -> bool:
	return wrs_mask_level(level, bc_te_best, transducer, nontest_abg) < level - SPEECH_MASK_BELOW_DB + maxi(0, nontest_abg)


## The louder list's level: 20 dB above the comfortable list, never past MAX_DB.
static func wrs_louder_level(comfy_db: int) -> int:
	return mini(MAX_DB, comfy_db + WRS_LOUDER_DB)


## Is `db` an acceptable louder list (15-25 dB above the comfortable list)? The textbook level always is.
static func wrs_louder_ok(db: int, comfy_db: int) -> bool:
	if db == wrs_louder_level(comfy_db):
		return true
	return absi(db - comfy_db - WRS_LOUDER_DB) <= WRS_LOUDER_TOLERANCE_DB


## The share of words a rollover ear loses at `level` (0..1): above `after` dB HL it loses
## `drop_per_10db` points per 10 dB. `entry` is speech.rollover[ear] ({} = no rollover).
static func rollover_drop(entry: Dictionary, level: float) -> float:
	if entry.is_empty():
		return 0.0
	var after := float(entry.get("after", MAX_DB))
	return maxf(0.0, level - after) / 10.0 * float(entry.get("drop_per_10db", 0)) / 100.0


## A list's percentage: each of `words` words is worth 100 / words (25 words: right x 4).
static func wrs_pct(right: int, words: int = WRS_WORDS) -> int:
	return roundi(float(right) * 100.0 / float(maxi(1, words)))


## The dealt count of a list: round(p x n) plus the list's jitter, kept within [lo, n].
static func wrs_deal_count(p: float, n: int, jitter: int, lo: int = 0) -> int:
	return clampi(roundi(p * float(n)) + jitter, mini(lo, n), n)


## How likely a cochlear ear is to miss a word whose key sound has this margin (dB above threshold):
## a sound below threshold weighs about 1, a clear one the floor (WRS_MISS_FLOOR).
static func wrs_miss_weight(margin: float) -> float:
	return 1.0 / (1.0 + exp(margin / WRS_MISS_SCALE_DB)) + WRS_MISS_FLOOR


## The lens alpha of a sound with this margin: full ink from 0 dB up, fading to LENS_MIN_ALPHA
## LENS_FADE_DB below its threshold.
static func lens_alpha(margin: float) -> float:
	return lerpf(1.0, LENS_MIN_ALPHA, clampf(-margin / LENS_FADE_DB, 0.0, 1.0))


## How visible the lurking Ghost is while the noise is off (0 when words cannot cross at `level`):
## 0.2 at the first level that needs noise, rising 1 / 25 per dB: bold 20 dB above it (Nora: 50, 70).
static func ghost_alpha(level: int, transducer: StringName, nontest_best: float) -> float:
	if not speech_masking_needed(level, nontest_best, transducer):
		return 0.0
	var over := float(level - int(SPEECH_IA_DB.get(transducer, 40))) - nontest_best
	return clampf(GHOST_ALPHA_FLOOR + over / GHOST_ALPHA_SPAN_DB, GHOST_ALPHA_FLOOR, 1.0)


## A word's spelling pieces with their sound ids ("" = silent): the item's own `chunks`, else a
## letter guess (digraphs such as th, sh, ch, ck, ng and ph; vowel runs; a silent final e).
static func chunk_sounds(item: Dictionary) -> Array:
	var given: Variant = item.get("chunks", null)
	if given is Array and not (given as Array).is_empty():
		return (given as Array).duplicate(true)
	return _guess_chunks(String(item.get("text", "")))


const _DIGRAPHS: Dictionary = {
	"tch": "ch", "dge": "j", "th": "th", "sh": "sh", "ch": "ch", "ph": "f", "ng": "ng", "ck": "k", "qu": "k",
	"wh": "w", "wr": "r", "kn": "n", "gh": "",
}
const _LETTERS: Dictionary = {
	"b": "b", "d": "d", "f": "f", "g": "g", "h": "h", "j": "j", "k": "k", "l": "l", "m": "m", "n": "n", "p": "p",
	"q": "k", "r": "r", "s": "s", "t": "t", "v": "v", "w": "w", "x": "s", "z": "z",
}


static func _guess_chunks(text: String) -> Array:
	var low := text.to_lower()
	var out: Array = []
	var i := 0
	while i < low.length():
		var ch := low[i]
		var took := false
		for n: int in [3, 2]:
			var piece := low.substr(i, n)
			if piece.length() == n and _DIGRAPHS.has(piece):
				out.append([text.substr(i, n), String(_DIGRAPHS[piece])])
				i += n
				took = true
				break
		if took:
			continue
		if "aeiou".contains(ch) or (ch == "y" and i > 0):
			var j := i + 1
			while j < low.length() and ("aeiou".contains(low[j]) or (low[j] in ["w", "y"] and (j + 1 >= low.length() or not "aeiou".contains(low[j + 1])))):
				j += 1
			# a final e after a consonant, with a vowel before it, is silent ("zone", "dice")
			var silent := ch == "e" and j == low.length() and j - i == 1 and not out.is_empty() \
				and String((out[out.size() - 1] as Array)[1]) != "vowel" and _has_vowel(out)
			out.append([text.substr(i, j - i), "" if silent else "vowel"])
			i = j
			continue
		if ch == "y":
			out.append([text.substr(i, 1), "y"])
			i += 1
			continue
		if _LETTERS.has(ch):
			var j := i + 1
			while j < low.length() and low[j] == ch:
				j += 1   # a doubled letter is one sound ("shell", "chess")
			out.append([text.substr(i, j - i), String(_LETTERS[ch])])
			i = j
			continue
		if ch == "c":
			var soft := i + 1 < low.length() and "eiy".contains(low[i + 1])
			out.append([text.substr(i, 1), "s" if soft else "k"])
			i += 1
			continue
		out.append([text.substr(i, 1), ""])
		i += 1
	return out


static func _has_vowel(chunks: Array) -> bool:
	for c: Array in chunks:
		if String(c[1]) == "vowel":
			return true
	return false


## The weakest sound of a word at `level` against `thresholds` (dB above threshold; silent pieces
## are skipped). INF for a word with no sound at all.
static func word_min_margin(item: Dictionary, level: float, thresholds: Dictionary) -> float:
	var lo := INF
	for c: Variant in chunk_sounds(item):
		var sound := String((c as Array)[1]) if c is Array and (c as Array).size() == 2 else ""
		if sound != "":
			lo = minf(lo, sound_margin(sound, level, thresholds))
	return lo


## Does every sound of the word reach the ear (each WRS_AUDIBLE_MARGIN_DB or more above threshold)?
## The lens, the "audible, but missed" stamp and the deal's audible target read MEASURED thresholds.
static func word_fully_audible(item: Dictionary, level: float, thresholds: Dictionary) -> bool:
	return word_min_margin(item, level, thresholds) >= WRS_AUDIBLE_MARGIN_DB


## (A2) The rollover index (PBmax - PBmin) / PBmax; 0 when PBmax is 0.
static func rollover_index_of(pb_max: float, pb_min: float) -> float:
	return (pb_max - pb_min) / pb_max if pb_max > 0.0 else 0.0


## (A2) Rollover over an ear's counted lists [{level_db, pct}]: PBmax is the best score (the softest
## level on a tie), PBmin the lowest score at a level ABOVE PBmax's. Without one (a single list, or
## nothing louder) there is no PBmin and no rollover. {pb_max, pb_min (-1: none), index, rollover}.
static func wrs_rollover(lists: Array) -> Dictionary:
	var out := {"pb_max": -1.0, "pb_min": -1.0, "index": 0.0, "rollover": false}
	var best := -1.0
	var best_db := 0
	for l: Variant in lists:
		var d: Dictionary = l
		var pct := float(d.get("pct", -1))
		var db := int(d.get("level_db", 0))
		if pct > best or (pct == best and db < best_db):
			best = pct
			best_db = db
	if best < 0.0:
		return out
	out["pb_max"] = best
	var lo := INF
	for l: Variant in lists:
		var d: Dictionary = l
		if int(d.get("level_db", 0)) > best_db:
			lo = minf(lo, float(d.get("pct", 0)))
	if lo == INF:
		return out
	out["pb_min"] = lo
	out["index"] = rollover_index_of(best, lo)
	out["rollover"] = float(out["index"]) >= ROLLOVER_INDEX_CUTOFF
	return out


## (A3) Do two word scores differ by more than chance (95%)? With theta = 2 asin(sqrt(p)), true when
## |theta_a - theta_b| > WRS_CRIT_Z x sqrt(1 / n_a + 1 / n_b). On 25 words 44% is the same as 20%-68%.
static func wrs_differ(pct_a: float, n_a: int, pct_b: float, n_b: int) -> bool:
	if n_a <= 0 or n_b <= 0:
		return false
	var ta := 2.0 * asin(sqrt(clampf(pct_a / 100.0, 0.0, 1.0)))
	var tb := 2.0 * asin(sqrt(clampf(pct_b / 100.0, 0.0, 1.0)))
	return absf(ta - tb) > WRS_CRIT_Z * sqrt(1.0 / float(n_a) + 1.0 / float(n_b))


## (A3) The lowest and highest whole-word scores (in 100 / n steps) that wrs_differ calls the same
## as `pct` on a list of `n`: the band the ear compare draws (44% on 25 words: 20-68).
static func wrs_same_range(pct: float, n: int) -> Vector2i:
	if n <= 0:
		return Vector2i(0, 100)
	var lo := 100
	var hi := 0
	for k in n + 1:
		var p := roundi(100.0 * float(k) / float(n))
		if not wrs_differ(pct, n, float(p), n):
			lo = mini(lo, p)
			hi = maxi(hi, p)
	return Vector2i(lo, hi) if lo <= hi else Vector2i(roundi(pct), roundi(pct))


## When word scores refer (D27): ears that differ (asymmetric), rollover, or a best score below its
## prediction in exactly one ear give &"refer" (a doctor's check soon, before any fitting). Both ears
## below with nothing else gives &"" (the summary adds the flag below_predicted_both). Never &"today":
## word scores alone never send a patient to a doctor today.
static func wrs_referral(asymmetric: bool, below_right: bool, below_left: bool, rollover: bool) -> StringName:
	return &"refer" if asymmetric or rollover or below_right != below_left else &""

# ---------------------------------------------------------------- Party Noise Test (Day 5)

const SIN_LEVEL_DB := 70
const SIN_PTA_LIMIT_DB := 45        ## above this PTA use "loud but OK"
const SIN_LOUD_ABOVE_PTA_DB := 25
const SIN_LOUD_MAX_DB := 90
const SIN_SNRS: Array[int] = [25, 20, 15, 10, 5, 0]
const SIN_KEY_WORDS := 5
const SIN_CONSTANT := 25.5          ## SNR loss = 25.5 - total key words right
const SIN_NORMAL_SNR50_DB := 2.0
const SIN_SLOPE_DB := 2.2
const SIN_DIRECTIONAL_BENEFIT_DB := 4.0
const SIN_CRIT_DIFF_DB: Dictionary[int, float] = {1: 3.9, 2: 2.7}
## [upper bound (inclusive), band]; over 15 is severe.
const SIN_BANDS: Array = [[3.0, &"normal"], [7.0, &"mild"], [15.0, &"moderate"]]
const SIN_BAND_TOP: StringName = &"severe"
const SIN_BAND_TITLES: Dictionary[StringName, String] = {
	&"normal": "Normal / near normal", &"mild": "Mild SNR loss", &"moderate": "Moderate SNR loss", &"severe": "Severe SNR loss",
}
const SIN_HELP: Dictionary[StringName, String] = {
	&"normal": "No new technology needed: good communication habits.",
	&"mild": "Hearing aids help in most noisy places.",
	&"moderate": "Hearing aids with directional microphones.",
	&"severe": "A remote microphone the talker wears.",
}


static func sin_level(pta: float) -> int:
	if is_nan(pta) or pta <= SIN_PTA_LIMIT_DB:
		return SIN_LEVEL_DB
	return clampi(snap5(pta + SIN_LOUD_ABOVE_PTA_DB), SIN_LEVEL_DB, SIN_LOUD_MAX_DB)


## SNR loss for one list from its total key words right (0-30).
static func snr_loss(total_correct: int) -> float:
	return SIN_CONSTANT - float(total_correct)


static func sin_band(loss: float) -> StringName:
	for b: Array in SIN_BANDS:
		if loss <= float(b[0]):
			return b[1]
	return SIN_BAND_TOP


## The SNR loss an audiogram suggests when the profile gives none (a rough teaching estimate:
## noise trouble grows with the high-frequency loss).
static func estimated_snr_loss(thresholds: Dictionary) -> float:
	var hf := 0.0
	var n := 0
	for f: int in [1000, 2000, 4000]:
		if thresholds.has(f):
			hf += float(thresholds[f])
			n += 1
	if n == 0:
		return 1.0
	return clampf(1.0 + maxf(0.0, hf / n - 20.0) * 0.18, 0.0, 25.0)


## Expected key words right (0..5) in one sentence at this SNR for this SNR loss.
static func sin_expected_words(snr: float, loss: float) -> float:
	var snr50 := SIN_NORMAL_SNR50_DB + loss
	return float(SIN_KEY_WORDS) / (1.0 + exp(-(snr - snr50) / SIN_SLOPE_DB))

# ---------------------------------------------------------------- lists (Days 4-5)
# Golf on a fixed list (word lists and party lists, CONTRACTS.md §9.15, D19). Each player list is a
# hole: golf_strokes = golf_par + slips - tee_bonus. Both test modes read these.

## Strokes off a solo list whose set-up the player made unprompted (the textbook level, and noise
## exactly when needed): the only way a clean list becomes a birdie.
const LIST_TEE_BONUS := 2
## Slips added when the player confirms a wrong set-up ("test at this level anyway").
const LIST_CONFIRM_SLIP := 3
