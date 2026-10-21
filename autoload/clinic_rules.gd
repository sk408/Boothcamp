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
## The octave frequencies.
const OCTAVE_FREQS: Array[int] = [250, 500, 1000, 2000, 4000, 8000]
## (Clinical review E1) The air frequencies every ear gets: the octaves plus 1.5, 3 and 6 kHz.
## ASHA (2005) lists 3 and 6 kHz in the standard order; 1.5 kHz is the dispensing habit (fitting
## software uses it). Only 750 Hz waits for the 20 dB rule (required_interoctaves()).
const ROUTINE_FREQS: Array[int] = [250, 500, 1000, 1500, 2000, 3000, 4000, 6000, 8000]
## Inter-octave frequency -> the two octave neighbours that trigger it.
const INTEROCTAVES: Dictionary[int, Array] = {750: [500, 1000], 1500: [1000, 2000], 3000: [2000, 4000], 6000: [4000, 8000]}
## Recommended order per ear. 1000 appears twice: the second is the 1 kHz retest (first air ear only).
const TEST_ORDER: Array[int] = [1000, 1500, 2000, 3000, 4000, 6000, 8000, 1000, 500, 250]

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
## (Clinical review E6) A gap shorter than the beep before it, and under this, breaks the combo
## (ASHA 2005: the interval between tones is "not shorter than the test tone").
const SHORT_GAP_S := 1.0
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

## Degree of loss (adult, dB HL, on the 500/1k/2k average): upper bound inclusive -> name. The
## scale is Goodman (1965): normal up to 25, without ASHA's "slight" band (clinical review E15).
## The audiogram's band labels use the same names and print DEGREE_SCALE_NOTE.
const DEGREE_BANDS: Array = [[25, "normal"], [40, "mild"], [55, "moderate"], [70, "moderately severe"], [90, "severe"]]
const DEGREE_TOP := "profound"
const DEGREE_SCALE_NOTE := "degrees: Goodman (1965)"

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


## (E1) Is this air frequency tested on every ear (an octave, 1.5k, 3k or 6k)?
static func is_routine(freq: int) -> bool:
	return ROUTINE_FREQS.has(freq)


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


## Which inter-octave frequencies the 20 dB rule flags, given the stored octave thresholds
## (Dictionary freq -> dB): both neighbours stored and differing by INTEROCTAVE_DIFF_DB or more.
## (E1) 1.5, 3 and 6 kHz are routine anyway, so for the test plan only a flagged 750 adds a stop.
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


# ================================================================ v3: bone conduction + masking
# Chapter 2 (docs/CHAPTER2.md section 7 lists every number). Sources (clinical review E14): ASHA
# (2005) manual pure-tone guidelines; BSA (2018) recommended procedure, 8.1 (interaural attenuation
# 40 dB with supra-aural phones, 55 dB with inserts) and 8.6 (when to mask); Hood (1960) and
# Yacullo (1996) plateau masking (start at the non-test ear's air + 10 dB, 5 dB steps, a 15 dB
# plateau); Goldstein and Newman (1985) occlusion effect. Teaching defaults: Steve reviews them.

## Tests: the conduction route plus the masked flag. Each one is its own results "sheet".
const TESTS: Array[StringName] = [&"ac", &"ac_masked", &"bc", &"bc_masked"]
## Transducers. "phones" = supra-aural headphones (the AudiOtron's default), "inserts" = insert
## earphones (a Day 2 shop upgrade), "bone" = the bone oscillator on the mastoid.
const TRANSDUCERS: Array[StringName] = [&"phones", &"inserts", &"bone"]

## Bone-conduction frequencies the oscillator can present (Hz).
const BC_FREQS: Array[int] = [250, 500, 750, 1000, 1500, 2000, 3000, 4000]
## Required bone frequencies, in the recommended order (250 is optional: loud low bone tones
## can be felt instead of heard).
const BC_REQUIRED: Array[int] = [1000, 2000, 4000, 500]
## Bone oscillator maximum output (dB HL). It runs out much sooner than headphones.
const BC_MAX_DB: Dictionary[int, int] = {250: 45, 500: 60, 750: 65, 1000: 70, 1500: 70, 2000: 70, 3000: 70, 4000: 65}
## Loud low bone tones are FELT (vibrotactile), not heard (clinical review E16: about 25 dB at
## 250 Hz, 55 at 500 and 70 at 1000 Hz). The tickle reaction and lesson only.
const VIBROTACTILE_DB: Dictionary[int, int] = {250: 25, 500: 55, 1000: 70}

## Minimum interaural attenuation the masking RULES assume (conservative, flat). The patient
## simulator uses each patient's own, larger, real IA (PatientProfile.ia_*_db).
const IA_RULE_DB: Dictionary[StringName, int] = {&"phones": 40, &"inserts": 55, &"bone": 0}
## Safety pad on top of the non-test ear's AC threshold for the initial masking level.
const MASK_SAFETY_DB := 10
## Occlusion-effect allowance (dB) for BONE tests: covering a normal non-test ear with the masking
## earphone makes low bone tones louder in it, so initial masking adds this. 2 kHz and up: 0.
const OCCLUSION_DB: Dictionary[StringName, Dictionary] = {
	&"phones": {250: 15, 500: 15, 750: 10, 1000: 10},
	&"inserts": {250: 0, 500: 0, 750: 0, 1000: 0},   # deep insertion: negligible (teaching default)
}
## The covered ear only shows an occlusion effect when its own middle ear is normal (gap <= this).
const OCCLUSION_MAX_GAP_DB := 10
## Masker steps (dB) and the plateau: the same tone level heard on PLATEAU_STEPS consecutive
## masker raises of MASK_STEP_DB (3 x 5 = 15 dB of masking) is the masked threshold.
const MASK_STEP_DB := 5
const PLATEAU_STEPS := 3
## Narrow-band masker range (dB EM).
const MASK_MIN_DB := 0
const MASK_MAX_DB := 100
## Air-bone gap: more than this = a conductive component (10 dB or less = no real gap).
const ABG_CONDUCTIVE_DB := 10
## (Clinical review E5) Bone masking: an air-bone gap of this or MORE asks for masked bone (ASHA
## 2005; BSA 2018 8.6.2 rule 2: "better ... by 10 dB or more"). Naming the type of loss still uses
## ABG_CONDUCTIVE_DB (over 10), so a 10 dB gap is masked but still reads as no real gap.
const BC_MASK_GAP_DB := 10
## Referral red flag: a gap of at least this at EACH of these frequencies.
const ABG_RED_FLAG_DB := 15
const ABG_RED_FLAG_FREQS: Array[int] = [500, 1000, 2000]
## Carhart notch: masked bone at 2 kHz at least this much poorer than the better of 500 and 4 kHz.
const CARHART_FREQ := 2000
const CARHART_MIN_DIP_DB := 10
## Hearing types from air vs bone (classify with hearing_type()).
const HEARING_TYPES: Array[StringName] = [&"normal", &"conductive", &"sensorineural", &"mixed", &"unknown"]
const HEARING_TYPE_TITLES: Dictionary[StringName, String] = {
	&"normal": "Normal hearing",
	&"conductive": "Conductive loss",
	&"sensorineural": "Sensorineural loss",
	&"mixed": "Mixed loss",
	&"unknown": "Needs bone conduction",
}
## Masking-help light (CONTRACTS.md §4.3 "mask_status"): grey off, amber needed / too little /
## too much, green ok, purple impossible (masking dilemma).
const MASK_STATUSES: Array[StringName] = [&"off", &"needed", &"under", &"ok", &"over", &"impossible"]


static func test_id(bone: bool, masked: bool) -> StringName:
	if bone:
		return &"bc_masked" if masked else &"bc"
	return &"ac_masked" if masked else &"ac"


static func test_is_bone(test: StringName) -> bool:
	return test == &"bc" or test == &"bc_masked"


static func test_is_masked(test: StringName) -> bool:
	return test == &"ac_masked" or test == &"bc_masked"


## &"bc_masked" -> &"bc", &"ac_masked" -> &"ac".
static func unmasked_test(test: StringName) -> StringName:
	return &"bc" if test_is_bone(test) else &"ac"


## The frequencies a test can use (AC: 250-8k; bone: 250-4k).
static func test_freqs(test: StringName) -> Array[int]:
	return BC_FREQS.duplicate() if test_is_bone(test) else AC_FREQS.duplicate()


## Maximum output for a frequency on a transducer (bone runs out early).
static func max_db_for(freq: int, transducer: StringName) -> int:
	if transducer == &"bone":
		return BC_MAX_DB.get(freq, 60)
	return max_db(freq)


## clamp_db() for any transducer.
static func clamp_db_for(db: int, freq: int, transducer: StringName) -> int:
	var snapped := int(round(db / float(LEVEL_STEP_DB))) * LEVEL_STEP_DB
	return clampi(snapped, MIN_DB, max_db_for(freq, transducer))


static func clamp_mask_db(db: int) -> int:
	var snapped := int(round(db / float(MASK_STEP_DB))) * MASK_STEP_DB
	return clampi(snapped, MASK_MIN_DB, MASK_MAX_DB)


## Rule IA (dB) for a transducer. freq is accepted for a future frequency-specific table.
static func ia_rule(transducer: StringName, _freq: int = 1000) -> int:
	return IA_RULE_DB.get(transducer, 40)


## Occlusion-effect allowance at a frequency when the masker sits on a normal ear.
static func occlusion_effect(freq: int, masker: StringName = &"phones") -> int:
	var table: Dictionary = OCCLUSION_DB.get(masker, OCCLUSION_DB[&"phones"])
	return int(table.get(freq, 0))


static func air_bone_gap(ac: int, bc: int) -> int:
	return ac - bc


## Gap > 10 dB: a conductive component.
static func is_conductive_gap(gap: int) -> bool:
	return gap > ABG_CONDUCTIVE_DB


## Referral red flag: AC - BC >= 15 dB at 500, 1000 AND 2000 Hz (all three must be measured).
## ac, bc: freq -> dB (use the best available, i.e. masked where measured).
static func abg_red_flag(ac: Dictionary, bc: Dictionary) -> bool:
	for f: int in ABG_RED_FLAG_FREQS:
		if not ac.has(f) or not bc.has(f):
			return false
		if int(ac[f]) - int(bc[f]) < ABG_RED_FLAG_DB:
			return false
	return true


## Type of loss from one ear's air and bone thresholds (freq -> dB; best available values).
## normal: air 25 or better everywhere measured; conductive: a gap > 10 dB at 2+ of 500-4k with
## bone normal (its average over those frequencies 25 or better: one 5 dB wobble or a Carhart
## notch does not make it mixed); mixed: the same gaps with poorer bone; sensorineural: no real
## gap. unknown: no bone at 500-4k.
static func hearing_type(ac: Dictionary, bc: Dictionary) -> StringName:
	var both: Array[int] = []
	for f: int in [500, 1000, 2000, 4000]:
		if ac.has(f) and bc.has(f):
			both.append(f)
	var ac_normal := not ac.is_empty()
	for f: int in ac:
		if int(ac[f]) > 25:
			ac_normal = false
	if ac_normal:
		return &"normal"
	if both.is_empty():
		return &"unknown"
	var gaps := 0
	var bc_sum := 0
	for f: int in both:
		if is_conductive_gap(int(ac[f]) - int(bc[f])):
			gaps += 1
		bc_sum += int(bc[f])
	var bc_normal := float(bc_sum) / both.size() <= 25.0
	if gaps >= mini(2, both.size()):
		return &"conductive" if bc_normal else &"mixed"
	return &"sensorineural"


## Carhart notch (masked bone): 2 kHz at least CARHART_MIN_DIP_DB poorer than the better of 500 and
## 4000 Hz, poorer than 4 kHz (a notch, not a slope) and the bottom of the dip. A mechanical effect
## of the stiff stapes (the cochlea is fine); it often recovers after surgery.
static func has_carhart_notch(bc: Dictionary) -> bool:
	if not (bc.has(CARHART_FREQ) and bc.has(4000)):
		return false
	var dip := int(bc[CARHART_FREQ])
	# the reference is the better of 500 and 4000 Hz: 1 kHz often dips a little too in a Carhart
	# pattern, so it only stands in when 500 was not measured
	var ref := int(bc[4000])
	if bc.has(500):
		ref = mini(ref, int(bc[500]))
	elif bc.has(1000):
		ref = mini(ref, int(bc[1000]))
	if dip - ref < CARHART_MIN_DIP_DB:
		return false
	if dip - int(bc[4000]) < 5:
		return false  # 2 kHz no poorer than 4 kHz: a sloping loss, not a notch
	return not bc.has(1000) or dip >= int(bc[1000])  # 2 kHz is the bottom of the dip


## AC masking rule: test-ear AC level - IA >= the non-test ear's (best) BC.
static func ac_masking_needed(test_ac: int, nontest_bc: int, transducer: StringName = &"phones", freq: int = 1000) -> bool:
	return test_ac - ia_rule(transducer, freq) >= nontest_bc


## BC masking rule: the test ear's air-bone gap (AC - unmasked BC) is 10 dB or more (BC_MASK_GAP_DB).
static func bc_masking_needed(test_ac: int, bc_unmasked: int) -> bool:
	return test_ac - bc_unmasked >= BC_MASK_GAP_DB


## Initial masking level (dB EM) in the non-test ear: its AC threshold + 10, plus the occlusion
## allowance for bone tests at 250-1000 Hz when that ear has a normal middle ear.
static func initial_masking(nontest_ac: int, freq: int, test: StringName, nontest_gap: int = 0, masker: StringName = &"phones") -> int:
	var lvl := nontest_ac + MASK_SAFETY_DB
	if test_is_bone(test) and nontest_gap <= OCCLUSION_MAX_GAP_DB:
		lvl += occlusion_effect(freq, masker)
	return clamp_mask_db(lvl)


## Masker level at which overmasking starts: the noise crosses back (masker - IA) to the test
## cochlea's level. Bone: tone_db + IA. Air: tone_db - the test ear's gap + IA.
## Overmasked when mask_db >= this.
static func overmask_limit(tone_db: int, test: StringName, test_gap: int = 0, masker: StringName = &"phones") -> int:
	var cochlear := tone_db if test_is_bone(test) else tone_db - maxi(0, test_gap)
	return cochlear + ia_rule(masker)


static func is_overmasked(mask_db: int, tone_db: int, test: StringName, test_gap: int = 0, masker: StringName = &"phones") -> bool:
	return mask_db >= overmask_limit(tone_db, test, test_gap, masker)


## Masking dilemma: the initial masking already reaches the overmasking limit (no safe window).
static func masking_dilemma(initial_db: int, limit_db: int) -> bool:
	return initial_db >= limit_db or initial_db > MASK_MAX_DB


## The masking-help light (see MASK_STATUSES).
static func mask_status(on: bool, needed: bool, mask_db: int, initial_db: int, limit_db: int) -> StringName:
	if not on:
		return &"needed" if needed else &"off"
	if masking_dilemma(initial_db, limit_db):
		return &"impossible"
	if mask_db < initial_db:
		return &"under"
	if mask_db >= limit_db:
		return &"over"
	return &"ok"


## The textbook next step of the plateau dance after a masked presentation at (tone_db, mask_db):
## heard -> same tone, masker +5; missed -> tone +5, same masker. Returns Vector2i(tone, masker).
static func next_mask_step(tone_db: int, mask_db: int, heard: bool) -> Vector2i:
	if heard:
		return Vector2i(tone_db, mask_db + MASK_STEP_DB)
	return Vector2i(tone_db + LEVEL_STEP_DB, mask_db)


## The current plateau run in a masked measurement. records: presentations in order, each with
## "db", "mask_db" and "responded" (only those with a verdict). The run = the latest heard level,
## walking back over heard presentations at that SAME level, each 5 dB less masker than the next.
## Returns {"db": level or -1, "steps": masker raises held, "start_mask": masker at the run start}.
## Plateau found = steps >= PLATEAU_STEPS and start_mask >= the initial masking level.
static func plateau_run(records: Array) -> Dictionary:
	var n := records.size()
	if n == 0 or not bool((records[n - 1] as Dictionary).get("responded", false)):
		return {"db": -1, "steps": 0, "start_mask": -1}
	var last: Dictionary = records[n - 1]
	var level := int(last["db"])
	var m := int(last.get("mask_db", -1))
	var steps := 0
	var i := n - 2
	while i >= 0:
		var r: Dictionary = records[i]
		if not bool(r.get("responded", false)) or int(r["db"]) != level or int(r.get("mask_db", -1)) != m - MASK_STEP_DB:
			break
		steps += 1
		m = int(r.get("mask_db", -1))
		i -= 1
	return {"db": level, "steps": steps, "start_mask": m}


## Stored thresholds of one ear and test from a results Dictionary (§5.1): freq -> dB.
## test &"ac" reads ears[ear].freqs; the others read ears[ear][test].
static func sheet_thresholds(results: Dictionary, ear: String, test: StringName) -> Dictionary:
	var e: Dictionary = (results.get("ears", {}) as Dictionary).get(ear, {})
	var sheet: Dictionary = e.get("freqs" if test == &"ac" else String(test), {})
	var out := {}
	for f: int in sheet:
		out[f] = int((sheet[f] as Dictionary).get("stored_db", 0))
	return out


## Best available thresholds of one ear for air (masked where measured, else unmasked) or bone.
static func best_thresholds(results: Dictionary, ear: String, bone: bool) -> Dictionary:
	var out := sheet_thresholds(results, ear, &"bc" if bone else &"ac")
	var masked := sheet_thresholds(results, ear, &"bc_masked" if bone else &"ac_masked")
	for f: int in masked:
		out[f] = masked[f]
	return out


## Lowest bone threshold known for the NON-test ear at freq: its masked bone, or any unmasked bone
## (unmasked bone is the better cochlea, so it is a safe lower bound); else its air threshold.
## Returns null when nothing is known at freq.
static func nontest_bone_estimate(results: Dictionary, test_ear: String, freq: int) -> Variant:
	var other := "left" if test_ear == "right" else "right"
	var cands: Array[int] = []
	for src: Array in [[other, &"bc_masked"], [other, &"bc"], [test_ear, &"bc"]]:
		var t := sheet_thresholds(results, String(src[0]), src[1])
		if t.has(freq):
			cands.append(int(t[freq]))
	if cands.is_empty():
		var ac := sheet_thresholds(results, other, &"ac")
		return ac[freq] if ac.has(freq) else null
	return cands.min()


## (v4) Unmasked bone at freq, wherever the oscillator sat: bone crosses the skull for free
## (IA about 0 dB), so an unmasked bone answer is the BETTER cochlea's, whichever mastoid the
## oscillator was on. The lower of both ears' unmasked bone stamps (Steve: test bone on the better
## ear first; the poorer ear then compares its air with that). null when neither ear has one.
static func unmasked_bone(results: Dictionary, freq: int) -> Variant:
	var cands: Array[int] = []
	for e: String in EARS:
		var t := sheet_thresholds(results, e, &"bc")
		if t.has(freq):
			cands.append(int(t[freq]))
	return null if cands.is_empty() else cands.min()


## Frequencies that need a masked measurement for one ear, from the stored results (§5.1), in the
## recommended order. test = &"bc_masked": wherever the ear's air-bone gap (best AC - unmasked BC)
## is 10 dB or more (E5); (v4) the unmasked BC may come from either mastoid (unmasked_bone()), so testing
## unmasked bone on the better ear only is enough to see the poorer ear's gap.
## test = &"ac_masked": wherever AC - IA(phones) >= the non-test ear's bone estimate. (Day 13) A stamp that
## records its own air transducer ("phones" / "inserts") is judged with that one: air measured through
## headphones before the inserts were lent still needs masking by the headphones' rule.
static func masked_freqs_needed(results: Dictionary, ear: String, test: StringName, phones: StringName = &"phones") -> Array[int]:
	var out: Array[int] = []
	if test == &"bc_masked":
		var ac := best_thresholds(results, ear, false)
		var order: Array[int] = BC_REQUIRED.duplicate()
		for f: int in BC_FREQS:
			if not order.has(f):
				order.append(f)
		for f: int in order:
			var ub: Variant = unmasked_bone(results, f)
			if ub != null and ac.has(f) and bc_masking_needed(int(ac[f]), int(ub)):
				out.append(f)
	elif test == &"ac_masked":
		var ac2 := sheet_thresholds(results, ear, &"ac")
		var sheet2: Dictionary = ((results.get("ears", {}) as Dictionary).get(ear, {}) as Dictionary).get("freqs", {})
		var order2: Array[int] = [1000, 1500, 2000, 3000, 4000, 6000, 8000, 750, 500, 250]
		for f: int in order2:
			if not ac2.has(f):
				continue
			var tr := stamp_air_transducer(sheet2[f] as Dictionary, phones)
			var nb: Variant = nontest_bone_estimate(results, ear, f)
			if nb != null and ac_masking_needed(int(ac2[f]), int(nb), tr, f):
				out.append(f)
	return out


## (Day 13) The air transducer an air stamp records ("phones" / "inserts"), else the fallback.
static func stamp_air_transducer(stamp: Dictionary, fallback: StringName) -> StringName:
	var rec := String(stamp.get("transducer", ""))
	if rec == "phones" or rec == "inserts":
		return StringName(rec)
	return fallback


## The patient's response threshold (dial dB) for one tone, from the cross-hearing model
## (docs/CHAPTER2.md section 7). Inputs are TRUE thresholds (the simulator's business only):
##   t_ac / t_bc   test ear air / bone (cochlea) thresholds
##   n_ac / n_bc   non-test ear air / bone thresholds
##   bone          tone through the bone oscillator (else through the air transducer)
##   mask_db       narrow-band masker (dB EM) in the non-test ear, < 0 = off
##   ia_test       the patient's real IA for the tone's transducer (bone ~0, phones ~55-65)
##   ia_masker     the patient's real IA for the masking earphone (crossing back = overmasking)
##   oe            occlusion effect in the covered non-test ear (bone tests with the masker on;
##                 ignored when that ear has a conductive gap)
## A tone is heard when EITHER cochlea hears it:
##   test cochlea:  threshold max(t_bc, mask - ia_masker), reached at dial + (air ? t_gap : 0)
##   other cochlea: threshold max(n_bc, mask - n_gap), reached across the head at dial - ia_test
##                  (+ oe for an occluded ear during bone tests)
## Returns {"threshold": dial level, "test": via the test cochlea, "cross": via the other cochlea,
##          "by": &"test" or &"cross" (which cochlea answers first)}.
static func response_threshold(t_ac: int, t_bc: int, n_ac: int, n_bc: int, bone: bool, mask_db: int, ia_test: int, ia_masker: int, oe: int = 0) -> Dictionary:
	var t_gap := maxi(0, t_ac - t_bc)
	var n_gap := maxi(0, n_ac - n_bc)
	var masked := mask_db >= 0
	var t_cochlea := t_bc
	var n_cochlea := n_bc
	if masked:
		t_cochlea = maxi(t_bc, mask_db - ia_masker)
		n_cochlea = maxi(n_bc, mask_db - n_gap)
	var via_test := t_cochlea + (0 if bone else t_gap)
	var occl := oe if (bone and masked and n_gap <= OCCLUSION_MAX_GAP_DB) else 0
	var via_cross := n_cochlea + ia_test - occl
	return {"threshold": mini(via_test, via_cross), "test": via_test, "cross": via_cross, "by": &"test" if via_test <= via_cross else &"cross"}


# ---------------------------------------------------------------- (E18) chart notes

## (E18) The notes strip under a finished audiogram (ASHA 2005 record keeping; BSA 2018, 10.4 and
## 10.5): the air transducer, the mastoids the bone oscillator sat on, and how reliable the answers
## looked, from the 1 kHz retest and the patient's false alarms per minute of testing.
const RELIABILITY_POOR_RETEST_DB := 10   ## a retest off by more than this: poor (more than RETEST_TOLERANCE_DB: fair)
const RELIABILITY_FAIR_FA_PER_MIN := 1.0
const RELIABILITY_POOR_FA_PER_MIN := 2.0


## "good", "fair" or "poor" for a session's results (AudiometrySession.results()).
static func reliability(results: Dictionary) -> String:
	var worst := 0
	var ears: Dictionary = results.get("ears", {})
	for e: String in ears:
		var rt: Dictionary = (ears[e] as Dictionary).get("retest_1k", {})
		if not rt.is_empty():
			worst = maxi(worst, absi(int(rt.get("diff", 0))))
	var minutes := maxf(1.0, float(results.get("duration_s", 0.0)) / 60.0)
	var fa_rate := float(results.get("false_alarms", 0)) / minutes
	if worst > RELIABILITY_POOR_RETEST_DB or fa_rate >= RELIABILITY_POOR_FA_PER_MIN:
		return "poor"
	if worst > RETEST_TOLERANCE_DB or fa_rate >= RELIABILITY_FAIR_FA_PER_MIN:
		return "fair"
	return "good"


## The one-line chart note, e.g. "Headphones  ·  Bone on the left mastoid  ·  Reliability: good".
static func chart_notes(results: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("Insert earphones" if String(results.get("air_transducer", "phones")) == "inserts" else "Headphones")
	var ears: Dictionary = results.get("ears", {})
	var mastoids: Array[String] = []
	for e: String in ["right", "left"]:
		var ear: Dictionary = ears.get(e, {})
		if not (ear.get("bc", {}) as Dictionary).is_empty() or not (ear.get("bc_masked", {}) as Dictionary).is_empty():
			mastoids.append(e)
	if mastoids.size() == 2:
		parts.append("Bone on both mastoids")
	elif mastoids.size() == 1:
		parts.append("Bone on the %s mastoid" % mastoids[0])
	parts.append("Reliability: %s" % reliability(results))
	return "  \u00b7  ".join(parts)

