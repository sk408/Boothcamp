class_name ClinicRules
extends RefCounted
## ClinicRules: the shared clinical rulebook (pure data + pure functions, no state).
##
## One source of truth for numbers that more than one module needs: frequencies, test order,
## Hughson-Westlake steps, scoring weights, grade bands, degree names, shape classification.
## core/ (technique checker, scoring), ui/ (audiogram), story/ (reveal, results) and the
## autoplay bot all read from here. Teaching defaults; Steve reviews clinical numbers.
## Sources: ASHA (2005) pure-tone guidelines; Carhart & Jerger (1959); design notes §2.2.

const EARS: PackedStringArray = ["right", "left"]

## Every air-conduction frequency the AudiOtron can present (Hz).
const AC_FREQS: Array[int] = [250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000]
## The octave frequencies that are always required.
const OCTAVE_FREQS: Array[int] = [250, 500, 1000, 2000, 4000, 8000]
## Inter-octave frequency -> the two octave neighbours that trigger it.
const INTEROCTAVES: Dictionary[int, Array] = {750: [500, 1000], 1500: [1000, 2000], 3000: [2000, 4000], 6000: [4000, 8000]}
## Recommended order per ear. 1000 appears twice: the second is the 1 kHz retest.
const TEST_ORDER: Array[int] = [1000, 2000, 4000, 8000, 1000, 500, 250]

const START_FREQ := 1000
const START_DB := 40            ## "start at 1 kHz, about 40 dB HL"
const LEVEL_STEP_DB := 5        ## one press of louder / softer
const DOWN_AFTER_HIT_DB := 10   ## heard -> down 10
const UP_AFTER_MISS_DB := 5     ## missed -> up 5
const UP_SEARCH_DB := 10        ## nothing heard yet at this frequency -> up 10 (5 is tolerated)
const MIN_DB := -10
const MAX_START_DB := 70        ## never start above 70-80 dB HL
const ASCENDING_HITS_NEEDED := 2  ## threshold = lowest level heard on 2 of 3 ascending runs
const INTEROCTAVE_DIFF_DB := 20   ## adjacent octaves differ by >= 20 dB -> test the half-octave
const RETEST_TOLERANCE_DB := 5    ## 1 kHz retest must agree within 5 dB

## Supra-aural headphone maximum output per frequency (dB HL). A game value, not a spec sheet.
const MAX_DB: Dictionary[int, int] = {250: 90, 500: 110, 750: 115, 1000: 120, 1500: 120, 2000: 120, 3000: 120, 4000: 120, 6000: 110, 8000: 100}

## Tone timing (game-time seconds).
const TONE_TOO_SHORT_S := 0.5
const TONE_IDEAL_MIN_S := 1.0
const TONE_IDEAL_MAX_S := 2.0
const TONE_TOO_LONG_S := 3.0
## A press up to this long after the tone ends still counts as a response to it.
## (Gus answers 0.4-1.2 s after tone onset, and tones last 1-2 s, so 1.5 s after the end is plenty.)
const RESPONSE_WINDOW_S := 1.5
## Rhythm detector: the last N gaps between tones vary by less than this share of their mean
## -> "rhythmic" (or the patient actually presses on the beat; see AudiometrySession).
const RHYTHM_WINDOW := 6
const RHYTHM_MAX_SPREAD_S := 0.3
const RHYTHM_REL_SPREAD := 0.15
## A tone this far above the true threshold triggers the (visual-only) hair-blast gag.
const TOO_LOUD_SL_DB := 45

## Golf: fallback par (expected expert presentations) per measurement. The session computes a
## dynamic par per measurement (median textbook search from that start level, typically 7-13).
const PAR_PER_MEASUREMENT := 7
## More than this many times par at one frequency = "marathon" (fatigue gag).
const MARATHON_FACTOR := 3.0

## Visit score weights (sum 1.0). Accuracy, technique and efficiency come from audiometry;
## care = comfort hearts / 3 (Game.visit.comfort).
const SCORE_WEIGHTS: Dictionary[String, float] = {"accuracy": 0.40, "technique": 0.30, "efficiency": 0.15, "care": 0.15}
const MAX_COMFORT := 3
## Grade bands on 0..100. Below the last band = "Do-over" (patient comes back tomorrow).
const GRADE_BANDS: Array = [["S", 95.0], ["A", 85.0], ["B", 70.0], ["C", 55.0]]
const GRADE_FAIL := "Do-over"

## Degree of loss (adult, dB HL): upper bound inclusive -> name.
const DEGREE_BANDS: Array = [[25, "normal"], [40, "mild"], [55, "moderate"], [70, "moderately severe"], [90, "severe"]]
const DEGREE_TOP := "profound"

## Audiogram shapes recognised by classify_shape(). Each gets a reveal mascot (design notes §2.9).
const SHAPES: Array[StringName] = [&"normal", &"flat", &"sloping", &"rising", &"cookie_bite", &"notch", &"unknown"]
const SHAPE_TITLES: Dictionary[StringName, String] = {
	&"normal": "Normal hearing",
	&"flat": "Flat loss",
	&"sloping": "Sloping high-frequency loss",
	&"rising": "Rising (low-frequency) loss",
	&"cookie_bite": "Cookie-bite (mid-frequency) loss",
	&"notch": "Noise notch",
	&"unknown": "Not enough points yet",
}


static func max_db(freq: int) -> int:
	return MAX_DB.get(freq, 100)


static func is_octave(freq: int) -> bool:
	return OCTAVE_FREQS.has(freq)


## Snap any level to the 5 dB grid and the legal range for that frequency.
static func clamp_db(db: int, freq: int) -> int:
	var snapped := int(round(db / float(LEVEL_STEP_DB))) * LEVEL_STEP_DB
	return clampi(snapped, MIN_DB, max_db(freq))


## Accuracy credit for one threshold. Within 5 dB is normal test-retest wobble and gets full
## credit (real tests wobble that much); 10 dB -> 0.4, more than 10 dB -> 0 (linear between).
const TEST_RETEST_DB := 5.0
static func accuracy_for_error(err_db: float) -> float:
	var e := absf(err_db)
	if e <= TEST_RETEST_DB:
		return 1.0
	if e <= 10.0:
		return lerpf(1.0, 0.4, (e - TEST_RETEST_DB) / 5.0)
	return 0.0


## Golf callout for one hole, with the fairness rules (fun review): a hole with NO technique
## errors is never worse than par (Gus wobbled, not the player); a hole WITH errors is never
## better than par (no fanfare for blasting him at 95 dB). The raw strokes stay on the card.
static func fair_golf(strokes: int, par: int, clean: bool) -> StringName:
	var g := golf_name(strokes, par)
	if clean and g in [&"bogey", &"double_bogey", &"triple_bogey"]:
		return &"par"
	if not clean and g in [&"birdie", &"eagle", &"albatross"]:
		return &"par"
	return g


## Golf callout for one frequency. Bands are about one ascending run wide (an extra run costs
## 2-3 presentations), so a textbook search on a wobbly patient still reads as "par":
## d = strokes - par: <= -6 albatross, -5..-4 eagle, -3..-2 birdie, -1..+1 par,
## +2..+3 bogey, +4..+5 double bogey, >= +6 triple bogey.
static func golf_name(strokes: int, par: int) -> StringName:
	var d := strokes - par
	if d <= -6:
		return &"albatross"
	if d <= -4:
		return &"eagle"
	if d <= -2:
		return &"birdie"
	if d <= 1:
		return &"par"
	if d <= 3:
		return &"bogey"
	if d <= 5:
		return &"double_bogey"
	return &"triple_bogey"


static func grade_for_score(score: float) -> String:
	for band: Array in GRADE_BANDS:
		if score >= float(band[1]):
			return band[0]
	return GRADE_FAIL


## Textbook combo multiplier: x1 -> x2 -> x3 -> x5.
static func combo_multiplier(n: int) -> int:
	if n >= 10:
		return 5
	if n >= 6:
		return 3
	if n >= 3:
		return 2
	return 1


static func degree_name(db: float) -> String:
	for band: Array in DEGREE_BANDS:
		if db <= float(band[0]):
			return band[1]
	return DEGREE_TOP


## Pure-tone average of 500/1k/2k (missing frequencies are skipped). Returns NAN if none.
static func pta(thresholds: Dictionary) -> float:
	var total := 0.0
	var n := 0
	for f: int in [500, 1000, 2000]:
		if thresholds.has(f):
			total += float(thresholds[f])
			n += 1
	return total / n if n > 0 else NAN


## Which inter-octave frequencies are required, given the stored octave thresholds
## (Dictionary freq -> dB). An inter-octave is required when both neighbours are stored and
## differ by INTEROCTAVE_DIFF_DB or more.
static func required_interoctaves(thresholds: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for f: int in INTEROCTAVES:
		var pair: Array = INTEROCTAVES[f]
		if thresholds.has(pair[0]) and thresholds.has(pair[1]):
			if absi(int(thresholds[pair[0]]) - int(thresholds[pair[1]])) >= INTEROCTAVE_DIFF_DB:
				out.append(f)
	return out


## Classify an audiogram's configuration from freq -> dB thresholds (one ear).
## Needs at least 500, 1000, 2000 and 4000. Heuristic and teaching-grade.
static func classify_shape(thresholds: Dictionary) -> StringName:
	for f: int in [500, 1000, 2000, 4000]:
		if not thresholds.has(f):
			return &"unknown"
	var t := func(f: int, fallback: int) -> float: return float(thresholds.get(f, thresholds[fallback]))
	var t250: float = t.call(250, 500)
	var t500: float = t.call(500, 500)
	var t1k: float = t.call(1000, 1000)
	var t2k: float = t.call(2000, 2000)
	var t3k: float = t.call(3000, 2000)
	var t4k: float = t.call(4000, 4000)
	var t6k: float = t.call(6000, 4000)
	var t8k: float = t.call(8000, 4000)
	# Noise notch: 3-6 kHz dips at least 15 dB below 2 kHz and recovers 10+ dB at 8 kHz.
	var notch_floor := maxf(t3k, maxf(t4k, t6k))
	if notch_floor - t2k >= 15.0 and notch_floor - t8k >= 10.0:
		return &"notch"
	var worst := 0.0
	for v: float in [t250, t500, t1k, t2k, t4k, t8k]:
		worst = maxf(worst, v)
	if worst <= 25.0:
		return &"normal"
	var low := (t250 + t500 + t1k) / 3.0
	var high := (t2k + t4k + t8k) / 3.0
	var mid := (t1k + t2k) / 2.0
	if mid - t500 >= 15.0 and mid - maxf(t4k, t8k) >= 10.0:
		return &"cookie_bite"
	if high - low >= 15.0:
		return &"sloping"
	if low - high >= 15.0:
		return &"rising"
	return &"flat"
