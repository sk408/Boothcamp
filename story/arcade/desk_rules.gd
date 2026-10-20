extends RefCounted
## DeskRules (arcade, story-internal): the rules of Ears, Please!, the front-desk arcade cabinet
## (docs/ARCADE.md part 2). A patient file arrives; the player stamps FIT, REFER or DOCTOR TODAY and
## points at the proof. Pure and static: every clinical call comes from CaseRules and ClinicRules,
## so the arcade and the case files can't disagree. The few numbers kept here are game tuning
## (shift length, points) or are named below with their source. Steve reviews decide().
##   const DeskRules := preload("res://story/arcade/desk_rules.gd")
##   var v := DeskRules.decide(file)         # {decision, proofs, reasons}
##   DeskRules.proof_ok(v, target)           # target: {kind: intake|chart|sudden, id | freq}
##   var r := DeskRules.score_call(v, stamp, proof_right, combo, boss)
## The file (DeskDeck.make_file builds them): {"name", "age", "ac": {ear: {freq: dB}},
##   "ac_masked": {ear: {freq: true}}, "bc": {ear: {freq: dB}}, "bc_masked": {ear: {freq: true}},
##   "intake": {flag_id: bool}, "sudden": {} | {"pattern", "came_on_h", "days_ago", "ear"}, ...}
## ac and bc hold the FINAL chart, as a clinician records it: masked where the rules needed masking,
## so any gap on the chart is real. Every patient is an adult (the deck only builds adults; under-18s
## see a doctor first, CaseRules.RED_FLAGS, and no stamp covers that).

## The chart's test frequencies. 1.5, 3 and 6 kHz are routine and 750 Hz is added only where
## ClinicRules.required_interoctaves asks for it (Steve's E1 in docs/CLINICAL_REVIEW.md; the desk
## follows that decision ahead of the engine, which still treats 1.5k as conditional).
const FREQS: Array[int] = [250, 500, 1000, 1500, 2000, 3000, 4000, 6000, 8000]
## Bone is tested at these: ClinicRules.BC_REQUIRED in pitch order (a test checks they match).
const BONE_FREQS: Array[int] = [500, 1000, 2000, 4000]
## "In the last 6 months" (CaseRules.RED_FLAGS: drainage, and a sudden or changing loss).
const RED_FLAG_RECENT_DAYS := 182

## The intake card's boxes: CaseRules.RED_FLAGS ids, each with the words printed on its tile.
## ASKED boxes come from the patient's answers; LOOKED boxes from looking in the ear (otoscopy).
## "sudden" is its own card (the alarm clock), and the two measured flags (one ear worse, the
## air-bone gap) are read off the chart.
const INTAKE_WORDS: Dictionary[String, String] = {
	"drainage": "Ear leaking", "pain": "Ear pain", "dizziness": "Dizzy spells", "one_sided": "Ringing in ONE ear",
	"wax": "Lots of wax", "deformity": "Odd ear shape",
}
const ASKED: Array[String] = ["drainage", "pain", "dizziness", "one_sided"]
const LOOKED: Array[String] = ["wax", "deformity"]

## The wall's picture rules: what each one sends where. The first three are red flags (a doctor
## first, CaseRules.RED_FLAGS); SUDDEN + RECENT is the same-day exception.
const RULES: Dictionary[String, Dictionary] = {
	"tick": {"title": "A TICKED BOX", "sub": "Any YES on the intake", "stamp": &"refer"},
	"one_ear": {"title": "ONE EAR WORSE", "sub": "No known cause", "stamp": &"refer"},
	"gap": {"title": "AIR-BONE GAP", "sub": "Gap 15+ at 500, 1k, 2k", "stamp": &"refer"},
	"sudden": {"title": "SUDDEN + RECENT", "sub": "Came on in 3 days, this month", "stamp": &"today"},
}
const RED_FLAG_RULES: Array[String] = ["tick", "one_ear", "gap"]

## The shifts, one new rule each (a promotion). "mix": the share of each right call in the line.
## "refer_kinds": how a REFER file is made, by weight (DeskDeck.make_kind).
const SHIFTS: Array[Dictionary] = [
	{"id": 1, "title": "Trainee", "stamps": [&"fit", &"refer"], "rules": ["tick", "one_ear"],
		"intake": ["drainage", "pain", "dizziness", "one_sided"], "gap": false, "sudden": false,
		"mix": {&"fit": 0.5, &"refer": 0.5}, "refer_kinds": {"one_ear": 0.45, "intake": 0.55}, "boss": "wedding"},
	{"id": 2, "title": "Dispenser", "stamps": [&"fit", &"refer"], "rules": ["tick", "one_ear", "gap"],
		"intake": ["drainage", "pain", "dizziness", "one_sided", "wax", "deformity"], "gap": true, "sudden": false,
		"mix": {&"fit": 0.45, &"refer": 0.55}, "refer_kinds": {"one_ear": 0.25, "intake": 0.35, "gap": 0.15, "gap_both": 0.25}, "boss": "plane"},
	{"id": 3, "title": "Clinic Lead", "stamps": [&"fit", &"refer", &"today"], "rules": ["tick", "one_ear", "gap", "sudden"],
		"intake": ["drainage", "pain", "dizziness", "one_sided", "wax", "deformity"], "gap": true, "sudden": true,
		"mix": {&"fit": 0.4, &"refer": 0.42, &"today": 0.18},
		"refer_kinds": {"one_ear": 0.2, "intake": 0.3, "gap": 0.1, "gap_both": 0.1, "sudden_late": 0.15, "fluctuating": 0.15}, "boss": "wax"},
]

## Shift length (game seconds); the wall clock runs 9:00 to 11:00 over it.
const SHIFT_S := 120.0
## The boss arrives with this many seconds left (the next file after that point).
const BOSS_AT_LEFT_S := 25.0
## Two missed DOCTOR TODAY calls close the desk.
const MAX_INCIDENTS := 2
## HOOT HELP keeps the combo this many times a shift; after that it resets it like a slip.
const HELPS_KEEP_COMBO := 2

## Points. Lopsided on purpose: a missed red flag can hurt a patient, an extra referral costs one
## visit. Right call + right proof scores BASE x the combo multiplier (ClinicRules.combo_multiplier).
## A missed flag costs two clean calls, so stamping FIT on everything loses points.
const POINTS_BASE := 300
const POINTS_WRONG_REASON := 100
const POINTS_OVER := -100
const POINTS_MISSED_FLAG := -600
const POINTS_MISSED_TODAY := -900
const BOSS_FACTOR := 2

## Outcomes of one call.
const CLEAN := &"clean"                 ## right stamp (and right proof, if it needs one)
const WRONG_REASON := &"wrong_reason"   ## right stamp, wrong proof
const OVER := &"over"                   ## REFER or TODAY on a file that could be fitted
const TOO_URGENT := &"too_urgent"       ## TODAY on a file that needs a normal referral
const MISSED_FLAG := &"missed_flag"     ## FIT on a file with a red flag
const MISSED_TODAY := &"missed_today"   ## FIT or REFER on a same-day file: an incident
const OUTCOMES: Array[StringName] = [CLEAN, WRONG_REASON, OVER, TOO_URGENT, MISSED_FLAG, MISSED_TODAY]

## A shift counts for the board and for promotion when nothing dangerous got through and at least
## this share of calls was clean (HOOT HELP calls count as not clean).
const SAFE_CLEAN := 0.75
const PROMOTE_FILES := 8


static func shift(id: int) -> Dictionary:
	for s: Dictionary in SHIFTS:
		if int(s["id"]) == id:
			return s
	return SHIFTS[0]


## The right call for a file, every proof that would justify it, and short reasons for the slip.
## proofs: [{"kind": "intake", "id"}, {"kind": "chart", "rule": "one_ear" | "gap", "freqs", "ear"?},
## {"kind": "sudden"}]. A TODAY call is proved only by the sudden card.
static func decide(file: Dictionary) -> Dictionary:
	var proofs: Array[Dictionary] = []
	var reasons: PackedStringArray = []
	var intake: Dictionary = file.get("intake", {})
	for id: String in INTAKE_WORDS:
		if bool(intake.get(id, false)):
			proofs.append({"kind": "intake", "id": id})
			reasons.append(INTAKE_WORDS[id])
	var ac: Dictionary = file.get("ac", {})
	var bc: Dictionary = file.get("bc", {})
	var right: Dictionary = ac.get("right", {})
	var left: Dictionary = ac.get("left", {})
	if CaseRules.is_asymmetric(right, left):
		proofs.append({"kind": "chart", "rule": "one_ear", "freqs": run_freqs(right, left)})
		reasons.append("One ear worse, no known cause")
	for ear: String in ClinicRules.EARS:
		if ClinicRules.abg_red_flag(ac.get(ear, {}), bc.get(ear, {})):
			proofs.append({"kind": "chart", "rule": "gap", "ear": ear, "freqs": gap_freqs(ac.get(ear, {}), bc.get(ear, {}))})
			reasons.append("Air-bone gap, %s ear" % ear.to_upper())
	var s: Dictionary = file.get("sudden", {})
	if sudden_today(file):
		var only: Array[Dictionary] = [{"kind": "sudden"}]
		return {"decision": &"today", "proofs": only, "reasons": PackedStringArray([sudden_words(s)])}
	if sudden_flag(s):
		proofs.append({"kind": "sudden"})
		reasons.append(sudden_words(s))
	if not proofs.is_empty():
		return {"decision": &"refer", "proofs": proofs, "reasons": reasons}
	return {"decision": &"fit", "proofs": proofs, "reasons": reasons}


## The asymmetric frequencies that sit in a run of CaseRules.ASYMMETRY_RUN or more neighbours (the
## chart columns that prove "one ear worse").
static func run_freqs(right: Dictionary, left: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var run: Array[int] = []
	for f: int in ClinicRules.AC_FREQS:
		if not right.has(f) or not left.has(f):
			continue
		if absi(int(right[f]) - int(left[f])) >= CaseRules.ASYMMETRY_DB:
			run.append(f)
		else:
			if run.size() >= CaseRules.ASYMMETRY_RUN:
				out.append_array(run)
			run.clear()
	if run.size() >= CaseRules.ASYMMETRY_RUN:
		out.append_array(run)
	return out


## Every bone column of one ear where the gap is ClinicRules.ABG_RED_FLAG_DB or more (any of them
## shows the gap; the red flag itself needs 500, 1k and 2k).
static func gap_freqs(ac: Dictionary, bc: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for f: int in BONE_FREQS:
		if ac.has(f) and bc.has(f) and int(ac[f]) - int(bc[f]) >= ClinicRules.ABG_RED_FLAG_DB:
			out.append(f)
	return out


## The card's ear is CaseRules.SUDDEN_MIN_DB or more worse than the other ear at
## CaseRules.SUDDEN_MIN_FREQS or more neighbouring frequencies: the chart's stand-in for "dropped
## since last time" (there is no earlier chart at the desk). ear "": either ear.
static func sudden_drop(ac: Dictionary, ear: String) -> bool:
	var r: Dictionary = ac.get("right", {})
	var l: Dictionary = ac.get("left", {})
	var run := 0
	for f: int in ClinicRules.AC_FREQS:
		if not r.has(f) or not l.has(f):
			continue
		var d := int(r[f]) - int(l[f])
		if ear == "left":
			d = -d
		elif ear == "":
			d = absi(d)
		if d >= CaseRules.SUDDEN_MIN_DB:
			run += 1
			if run >= CaseRules.SUDDEN_MIN_FREQS:
				return true
		else:
			run = 0
	return false


## "Sudden, quickly worsening or fluctuating hearing loss in the last 6 months" (CaseRules.RED_FLAGS):
## any card that is not a slow, gradual loss, within RED_FLAG_RECENT_DAYS.
static func sudden_flag(s: Dictionary) -> bool:
	if s.is_empty() or int(s.get("days_ago", 9999)) > RED_FLAG_RECENT_DAYS:
		return false
	return String(s.get("pattern", "gradual")) != "gradual"


## Same-day referral (CaseRules header): a sudden loss (on over SUDDEN_ONSET_MAX_H hours or less,
## with the drop on the chart) that started within SUDDEN_REFER_TODAY_DAYS days, not explained by
## wax or the middle ear. Wax blocks air, not bone, so the sudden ear's own chart settles it
## (story/cases/sudden.json: "bone settles it"): a ticked wax box alone never cancels TODAY.
static func sudden_today(file: Dictionary) -> bool:
	var s: Dictionary = file.get("sudden", {})
	if s.is_empty() or String(s.get("pattern", "")) != "sudden":
		return false
	if int(s.get("came_on_h", 9999)) > CaseRules.SUDDEN_ONSET_MAX_H or int(s.get("days_ago", 9999)) > CaseRules.SUDDEN_REFER_TODAY_DAYS:
		return false
	var ac: Dictionary = file.get("ac", {})
	var bc: Dictionary = file.get("bc", {})
	var ear := String(s.get("ear", ""))
	if not sudden_drop(ac, ear):
		return false
	var ears: Array = [ear] if ear != "" else ["right", "left"]
	for e: String in ears:
		var a: Dictionary = ac.get(e, {})
		var b: Dictionary = bc.get(e, {})
		if ClinicRules.abg_red_flag(a, b) or ClinicRules.hearing_type(a, b) in [&"conductive", &"mixed"]:
			return false
	return true


## What the slip and the wall say about a sudden card.
static func sudden_words(s: Dictionary) -> String:
	var days := int(s.get("days_ago", 0))
	var when := "yesterday" if days == 1 else "%d days ago" % days
	match String(s.get("pattern", "")):
		"fluctuating":
			return "Comes and goes, %s" % when
		"sudden":
			if days > CaseRules.SUDDEN_REFER_TODAY_DAYS:
				return "Sudden, but %s" % when
			return "Sudden, %s" % when
	return "Worse lately, %s" % when


## Does the thing the player pointed at prove the call? target: {"kind": "intake", "id"} |
## {"kind": "chart", "freq"} | {"kind": "sudden"}.
static func proof_ok(verdict: Dictionary, target: Dictionary) -> bool:
	for p: Dictionary in verdict.get("proofs", []):
		if String(p["kind"]) != String(target.get("kind", "")):
			continue
		match String(p["kind"]):
			"intake":
				if String(p["id"]) == String(target.get("id", "")):
					return true
			"chart":
				if (p["freqs"] as Array).has(int(target.get("freq", -1))):
					return true
			"sudden":
				return true
	return false


## The proof Hoot points at (a slip's circle, HOOT HELP): a tick, then the alarm card, then the
## gap (it explains a split between the ears), then the split. {} when nothing proves the call.
static func best_proof(verdict: Dictionary) -> Dictionary:
	var proofs: Array = verdict.get("proofs", [])
	for want: String in ["intake", "sudden", "gap", "one_ear"]:
		for p: Dictionary in proofs:
			if String(p["kind"]) == want or String(p.get("rule", "")) == want:
				return p
	return {}


## best_proof as a target to point at (a chart proof: its middle column).
static func best_target(verdict: Dictionary) -> Dictionary:
	var p := best_proof(verdict)
	if p.is_empty():
		return {}
	match String(p["kind"]):
		"intake":
			return {"kind": "intake", "id": p["id"]}
		"chart":
			var fr: Array = p["freqs"]
			return {"kind": "chart", "freq": int(fr[(fr.size() - 1) / 2])}
	return {"kind": "sudden"}


## Which wall card a proof belongs to: "tick", "one_ear", "gap" or "sudden".
static func card_for(proof: Dictionary) -> String:
	match String(proof.get("kind", "")):
		"intake":
			return "tick"
		"sudden":
			return "sudden"
		"chart":
			return String(proof.get("rule", "one_ear"))
	return ""


## Does this call need the player to prove it?
static func needs_proof(decision: StringName) -> bool:
	return decision != &"fit"


## Score one call. stamp: the player's stamp; proof_right: did their proof hold (ignored when the
## stamp was wrong or needs none); combo: clean calls in a row before this one.
## Returns {"outcome", "points", "combo", "incident"}.
static func score_call(verdict: Dictionary, stamp: StringName, proof_right: bool, combo: int, boss: bool = false) -> Dictionary:
	var want: StringName = verdict["decision"]
	var outcome: StringName
	if stamp == want:
		outcome = CLEAN if (not needs_proof(want) or proof_right) else WRONG_REASON
	elif want == &"today":
		outcome = MISSED_TODAY
	elif want == &"refer":
		outcome = MISSED_FLAG if stamp == &"fit" else TOO_URGENT
	else:
		outcome = OVER
	var points := 0
	var new_combo := 0
	match outcome:
		CLEAN:
			new_combo = combo + 1
			points = POINTS_BASE * ClinicRules.combo_multiplier(new_combo)
		WRONG_REASON:
			points = POINTS_WRONG_REASON
		OVER, TOO_URGENT:
			points = POINTS_OVER
		MISSED_FLAG:
			points = POINTS_MISSED_FLAG
		MISSED_TODAY:
			points = POINTS_MISSED_TODAY
	if boss and points > 0:
		points *= BOSS_FACTOR
	return {"outcome": outcome, "points": points, "combo": new_combo, "incident": outcome == MISSED_TODAY}


## Clean calls over every call, HOOT HELP included (a helped file is not a clean read).
## stats: {"files", "clean", "helps"}. -1 when nothing was called.
static func accuracy(stats: Dictionary) -> float:
	var calls := int(stats.get("files", 0)) + int(stats.get("helps", 0))
	if calls <= 0:
		return -1.0
	return float(stats.get("clean", 0)) / calls


## Nothing dangerous got through, and SAFE_CLEAN of the calls were clean.
static func safe(stats: Dictionary) -> bool:
	return int(stats.get("files", 0)) > 0 and int(stats.get("missed_flag", 0)) == 0 \
		and int(stats.get("missed_today", 0)) == 0 and accuracy(stats) >= SAFE_CLEAN


## A safe shift of PROMOTE_FILES files or more opens the next shift.
static func promoted(stats: Dictionary) -> bool:
	return safe(stats) and int(stats.get("files", 0)) >= PROMOTE_FILES


## The rank on the results card, from the shift's tally.
## stats: {"files", "clean", "helps", "missed_flag", "missed_today", "over", "wrong_reason", "closed"}.
static func rank(stats: Dictionary) -> String:
	var files := int(stats.get("files", 0))
	if files == 0:
		return "Coffee Break"
	if bool(stats.get("closed", false)):
		return "Desk Closed"
	if int(stats.get("missed_today", 0)) > 0:
		return "Incident Report"
	var acc := accuracy(stats)
	var missed := int(stats.get("missed_flag", 0))
	if missed == 0 and acc >= 0.9 and files >= 10:
		return "Desk Legend"
	if missed == 0 and acc >= SAFE_CLEAN:
		return "Red Flag Radar"
	if missed == 0:
		if int(stats.get("over", 0)) >= int(stats.get("wrong_reason", 0)):
			return "Better Safe Than Sorry"
		return "Show Your Working"
	if missed == 1:
		return "Safe Hands"
	return "Red Flags Got Through"
