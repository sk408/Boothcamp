class_name CaseRules
extends RefCounted
## CaseRules (cases): the patient cases' clinical numbers and pure functions (docs/CASES.md §8,
## CONTRACTS.md §11). Static, no node. Keep case constants here, not in ClinicRules.
## Teaching defaults: Steve reviews every number. Case data lives in res://story/cases/<id>.json.

## The three calls a case ends with, in the stamp tray's order. Which one is right:
##   fit    no red flag and no asymmetry, and a loss that hearing aids can help (+ counselling and
##          hearing protection). An asymmetry with a known cause, already checked by an ear doctor and
##          unchanged, is a fit too (Day 12's deaf ear; the case's decision.asymmetry_known_cause)
##   refer  any red flag or asymmetry with no known cause that is not an emergency: a doctor soon
##          (days to about two weeks), before any fitting (not same-day)
##   today  sudden hearing loss (came on over SUDDEN_ONSET_MAX_H hours or less, within the last
##          SUDDEN_REFER_TODAY_DAYS days) not explained by wax or the middle ear; it overrides refer.
##          A sudden loss longer ago than that is an urgent refer.
const DECISIONS: Array[StringName] = [&"fit", &"refer", &"today"]
## What each rubber stamp says (the stamp buttons' text starts with this).
const DECISION_STAMPS: Dictionary[StringName, String] = {&"fit": "FIT", &"refer": "REFER", &"today": "DOCTOR TODAY"}
## The longer meaning, for the case file and the paper.
const DECISION_TITLES: Dictionary[StringName, String] = {
	&"fit": "Fit hearing aids",
	&"refer": "Refer to a doctor first",
	&"today": "See a doctor TODAY",
}

## Red flags that mean "a doctor first, preferably an ear specialist", paraphrased from the US FDA
## prescription hearing aid labeling (21 CFR 801.422, since October 2022). The 2022 OTC rule removed
## the old rule that adults get a medical evaluation or sign a waiver before buying; these stay
## dispenser guidance and good practice. Under-18s still see a doctor first, and some states still
## require referral. Steve checks the wording.
const RED_FLAGS: Array[Dictionary] = [
	{"id": "deformity", "text": "A visible deformity of the ear, from birth or injury"},
	{"id": "drainage", "text": "Fluid, pus or blood from the ear in the last 6 months"},
	{"id": "pain", "text": "Ear pain or discomfort"},
	{"id": "wax", "text": "A lot of wax, or something stuck in the canal"},
	{"id": "dizziness", "text": "Dizziness, recent or long-standing"},
	{"id": "sudden", "text": "Sudden, quickly worsening or fluctuating hearing loss in the last 6 months"},
	{"id": "one_sided", "text": "Hearing loss or ringing in one ear only, or a clear difference between the ears"},
	{"id": "air_bone_gap", "text": "An air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz"},
]

## Asymmetry, the measurable test of the "difference between the ears" flag: the ears differ by at
## least ASYMMETRY_DB at ASYMMETRY_RUN or more neighbouring test frequencies. One common screening
## rule; clinics use several.
const ASYMMETRY_DB := 15
const ASYMMETRY_RUN := 2

## Sudden sensorineural hearing loss, by definition: 30 dB or more poorer at 3 or more neighbouring
## frequencies, coming on over SUDDEN_ONSET_MAX_H hours or less. This is how fast it came on, NOT a
## treatment deadline: treatment works best when it starts early, but doctors still treat for weeks,
## so a patient who comes in late still goes the same day. The game's hours clock only counts up.
const SUDDEN_ONSET_MAX_H := 72
const SUDDEN_MIN_DB := 30
const SUDDEN_MIN_FREQS := 3
## A sudden loss that started within this many days goes to a doctor the same day.
const SUDDEN_REFER_TODAY_DAYS := 30

# ---------------------------------------------------------------- tympanometry

## Jerger tympanogram types.
const TYMP_TYPES: Array[StringName] = [&"A", &"As", &"Ad", &"B", &"C"]
const TYMP_TITLES: Dictionary[StringName, String] = {
	&"A": "Type A: a normal peak",
	&"As": "Type As: a shallow peak (stiff)",
	&"Ad": "Type Ad: a very tall peak (floppy)",
	&"B": "Type B: flat, no peak",
	&"C": "Type C: a peak at negative pressure",
}
## The words the gadget uses for each shape.
const TYMP_SHAPES: Dictionary[StringName, String] = {
	&"A": "a normal mountain", &"As": "a shallow hill", &"Ad": "a skyscraper", &"B": "flat as a pancake",
	&"C": "a mountain moved left",
}
## Normal box: peak pressure (daPa) and peak compensated admittance (mL).
const TYMP_NORMAL_PRESSURE := Vector2i(-100, 50)
const TYMP_NORMAL_PEAK := Vector2(0.3, 1.7)
## Typical adult ear canal volume (mL): the printed normal band, and the "hole" ceiling. Smaller with
## a wax plug, bigger with a hole in the eardrum. The lower edge is BSA's 0.6 (many women's canals
## are 0.7-0.9 mL; 0.9 is a male lower edge), so it meets TYMP_BLOCKED_ECV: no grey zone.
const TYMP_ADULT_ECV := Vector2(0.6, 2.0)
## Below this a flat tymp reads "blocked" (wax, or the probe against the canal wall).
const TYMP_BLOCKED_ECV := 0.6
## The pressure sweep, positive to negative (daPa).
const TYMP_SWEEP_FROM := 200
const TYMP_SWEEP_TO := -400
## Peak half-width (daPa) for drawing the curve: the curve is at half height this far either side of
## the peak, so the tympanometric width (full width at half height) is twice this. A: TW 75 (mid
## normal for adults, about 50-115), C: TW 90, As: TW 80, Ad: TW 60 (a narrow skyscraper).
const TYMP_WIDTH: Dictionary[StringName, float] = {&"A": 37.5, &"C": 45.0, &"As": 40.0, &"Ad": 30.0, &"B": 300.0}
## Peak admittance below this reads as flat (type B).
const TYMP_FLAT_ML := 0.1
## Ear tip sizes for the seal.
const TIP_SIZES: Array[StringName] = [&"small", &"medium", &"large"]


## Compensated admittance (mL, canal volume removed) at a pressure, for drawing the curve.
## tymp: {"type", "peak_daPa", "peak_ml"} as in a case's JSON.
static func tymp_admittance(tymp: Dictionary, pressure: float) -> float:
	var kind := StringName(String(tymp.get("type", "A")))
	var peak := float(tymp.get("peak_ml", 0.8))
	if kind == &"B":
		# flat: a gentle tilt, no peak
		return maxf(0.02, peak * 0.5 + (pressure - TYMP_SWEEP_TO) / float(TYMP_SWEEP_FROM - TYMP_SWEEP_TO) * 0.05)
	var w: float = TYMP_WIDTH.get(kind, 37.5)
	var d := (pressure - float(tymp.get("peak_daPa", 0))) / w
	return peak / (1.0 + d * d)


## The Jerger type a measured tympanogram falls into.
static func tymp_type(peak_daPa: int, peak_ml: float) -> StringName:
	if peak_ml < TYMP_FLAT_ML:
		return &"B"
	if peak_daPa < TYMP_NORMAL_PRESSURE.x:
		return &"C"
	if peak_ml < TYMP_NORMAL_PEAK.x:
		return &"As"
	if peak_ml > TYMP_NORMAL_PEAK.y:
		return &"Ad"
	return &"A"


## The type a case's tympanogram data really shows (B stays B whatever its numbers).
static func tymp_type_of(tymp: Dictionary) -> StringName:
	if String(tymp.get("type", "")) == "B":
		return &"B"
	return tymp_type(int(tymp.get("peak_daPa", 0)), float(tymp.get("peak_ml", 0.0)))


static func tymp_normal(tymp: Dictionary) -> bool:
	return tymp_type_of(tymp) == &"A"


## What a flat (type B) tympanogram means, read with the canal volume (mL): normal volume = fluid
## behind the eardrum (&"fluid"); tiny (under TYMP_BLOCKED_ECV) = wax or the probe against the canal
## wall (&"blocked"); large = a hole in the eardrum or an open ear tube (&"hole"). Compare with the
## other ear.
static func tymp_b_reading(ecv_ml: float) -> StringName:
	if ecv_ml < TYMP_BLOCKED_ECV:
		return &"blocked"
	if ecv_ml > TYMP_ADULT_ECV.y:
		return &"hole"
	return &"fluid"


## Where a canal volume (mL) sits: &"tiny" (under TYMP_BLOCKED_ECV, the adult band's lower edge),
## &"normal" (inside TYMP_ADULT_ECV) or &"large" (above it).
static func ecv_band(ecv_ml: float) -> StringName:
	if ecv_ml < TYMP_BLOCKED_ECV:
		return &"tiny"
	if ecv_ml > TYMP_ADULT_ECV.y:
		return &"large"
	return &"normal"


# ---------------------------------------------------------------- audiogram findings

## Frequencies (sorted) where the ears differ by ASYMMETRY_DB or more. right / left: freq -> dB.
static func asymmetric_freqs(right: Dictionary, left: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for f: int in ClinicRules.AC_FREQS:
		if right.has(f) and left.has(f) and absi(int(right[f]) - int(left[f])) >= ASYMMETRY_DB:
			out.append(f)
	return out


## Asymmetric: ASYMMETRY_RUN or more NEIGHBOURING test frequencies differ by ASYMMETRY_DB or more
## (neighbours in ClinicRules.AC_FREQS order, among the frequencies both ears have).
static func is_asymmetric(right: Dictionary, left: Dictionary) -> bool:
	var run := 0
	for f: int in ClinicRules.AC_FREQS:
		if not right.has(f) or not left.has(f):
			continue
		if absi(int(right[f]) - int(left[f])) >= ASYMMETRY_DB:
			run += 1
			if run >= ASYMMETRY_RUN:
				return true
		else:
			run = 0
	return false


## Air minus bone at the frequencies both have, 500-4000 Hz (freq -> dB): the air-bone gap.
static func air_bone_gaps(air: Dictionary, bone: Dictionary) -> Dictionary:
	var out := {}
	for f: int in [500, 1000, 2000, 4000]:
		if air.has(f) and bone.has(f):
			out[f] = int(air[f]) - int(bone[f])
	return out


## The poorer ear by PTA ("right", "left", or "" when within 5 dB).
static func poorer_ear(right: Dictionary, left: Dictionary) -> String:
	var r := ClinicRules.pta(right)
	var l := ClinicRules.pta(left)
	if is_nan(r) or is_nan(l) or absf(r - l) <= 5.0:
		return ""
	return "right" if r > l else "left"


## The biggest between-ear difference and where it is: {"freq", "diff"} ({} if no shared freq).
static func biggest_gap(right: Dictionary, left: Dictionary) -> Dictionary:
	var best := {}
	for f: int in ClinicRules.AC_FREQS:
		if right.has(f) and left.has(f):
			var d := absi(int(right[f]) - int(left[f]))
			if best.is_empty() or d > int(best["diff"]):
				best = {"freq": f, "diff": d}
	return best


## Hours since a sudden loss began: the case's onset plus the real (unscaled, unpaused) seconds the
## visit has taken so far.
static func hours_since_onset(onset_h: float, real_seconds: float) -> float:
	return onset_h + maxf(0.0, real_seconds) / 3600.0


static func decision_title(decision: StringName) -> String:
	return DECISION_TITLES.get(decision, String(decision))
