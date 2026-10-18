class_name CaseRules
extends RefCounted
## CaseRules (cases): the patient cases' clinical numbers and pure functions (docs/CASES.md §8,
## CONTRACTS.md §11). Static, no node. Keep case constants here, not in ClinicRules.
## Teaching defaults: Steve reviews every number. Case data lives in res://story/cases/<id>.json.

## The three calls a case ends with, in the stamp tray's order.
const DECISIONS: Array[StringName] = [&"fit", &"refer", &"today"]
## What each rubber stamp says (the stamp buttons' text starts with this).
const DECISION_STAMPS: Dictionary[StringName, String] = {&"fit": "FIT", &"refer": "REFER", &"today": "DOCTOR TODAY"}
## The longer meaning, for the case file and the paper.
const DECISION_TITLES: Dictionary[StringName, String] = {
	&"fit": "Fit hearing aids",
	&"refer": "Refer to a doctor first",
	&"today": "See a doctor TODAY",
}

## Red flags that mean "a doctor first", paraphrased from the long-standing US list for hearing aid
## dispensers. Since the 2022 OTC rule adults no longer need a medical evaluation to buy hearing aids,
## but these stay good practice (and some state rules). Steve checks the wording.
const RED_FLAGS: Array[Dictionary] = [
	{"id": "deformity", "text": "A visible deformity of the ear"},
	{"id": "drainage", "text": "Drainage from the ear in the last 90 days"},
	{"id": "sudden", "text": "Sudden or quickly worsening hearing loss in the last 90 days"},
	{"id": "dizziness", "text": "Dizziness, sudden or ongoing"},
	{"id": "one_sided", "text": "Sudden or recent hearing loss in one ear"},
	{"id": "air_bone_gap", "text": "An air-bone gap of 15 dB or more at 500, 1000 and 2000 Hz"},
	{"id": "wax", "text": "Lots of wax or something stuck in the canal"},
	{"id": "pain", "text": "Ear pain or discomfort"},
]

## Asymmetry: the ears differ by at least ASYMMETRY_DB at ASYMMETRY_RUN or more neighbouring test
## frequencies. One common screening rule; clinics use several.
const ASYMMETRY_DB := 15
const ASYMMETRY_RUN := 2

## Sudden loss: the case board's clock. Treatment tends to work best when it starts early, so the game
## counts the hours since onset against this window. It is a teaching prop, not a deadline.
const SUDDEN_CLOCK_H := 72

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
## Typical adult ear canal volume (mL). Smaller with a wax plug, bigger with a hole in the eardrum.
const TYMP_ADULT_ECV := Vector2(0.9, 2.0)
## The pressure sweep, positive to negative (daPa).
const TYMP_SWEEP_FROM := 200
const TYMP_SWEEP_TO := -400
## Peak half-width (daPa) for drawing the curve.
const TYMP_WIDTH: Dictionary[StringName, float] = {&"A": 70.0, &"C": 70.0, &"As": 55.0, &"Ad": 90.0, &"B": 300.0}
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
	var w: float = TYMP_WIDTH.get(kind, 70.0)
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


## Hours since a sudden loss began: the case's onset plus the game time spent on the visit.
static func hours_since_onset(onset_h: float, visit_seconds: float, hours_per_game_minute: float = 1.0) -> float:
	return onset_h + visit_seconds / 60.0 * hours_per_game_minute


static func decision_title(decision: StringName) -> String:
	return DECISION_TITLES.get(decision, String(decision))
