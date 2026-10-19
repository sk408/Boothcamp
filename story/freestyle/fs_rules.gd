extends RefCounted
## FsRules (freestyle, story-internal): the walk-in clinic's rules (docs/FREESTYLE.md §4-§6).
## Static, no state. Clinical numbers come from ClinicRules and CaseRules; this file only adds what
## freestyle needs on top: the fourth call (no aids needed), the standard question deck, which tests
## a full workup of a case needs (from the patient's truth, or from the chart once it is measured),
## the "best" next tool (the solver's pick), and the medals.
##   const FsRules := preload("res://story/freestyle/fs_rules.gd")

## The calls, in the stamp tray's order. CaseRules.DECISIONS plus "clear": normal hearing in both
## ears, no red flag: no hearing aids needed (counsel, retest if anything changes).
const DECISIONS: Array[StringName] = [&"fit", &"refer", &"today", &"clear"]
## What each rubber stamp says (the stamp buttons' text starts with this).
const DECISION_STAMPS: Dictionary[StringName, String] = {
	&"fit": "FIT", &"refer": "REFER", &"today": "DOCTOR TODAY", &"clear": "NO AIDS NEEDED",
}
const DECISION_TITLES: Dictionary[StringName, String] = {
	&"fit": "Fit hearing aids",
	&"refer": "Refer to a doctor first",
	&"today": "See a doctor TODAY",
	&"clear": "No hearing aids needed",
}

## The standard case-history deck: every freestyle patient answers every question (their case file
## has a reply for each id). The button text starts with "text"; the first 18 characters are unique
## (the mouse bot clicks by them).
const QUESTIONS: Array[Dictionary] = [
	{"id": "which_ear", "text": "Is one ear better than the other?"},
	{"id": "onset", "text": "When did it start: slowly, or all of a sudden?"},
	{"id": "ringing", "text": "Any ringing or buzzing in your ears?"},
	{"id": "red_flags", "text": "Any ear pain, drainage or dizziness?"},
	{"id": "noise", "text": "Any loud noise: work, music, hobbies?"},
	{"id": "ear_history", "text": "Any ear infections, surgery or injuries?"},
	{"id": "family", "text": "Does hearing loss run in your family?"},
	{"id": "health", "text": "Any medicines or health problems?"},
	{"id": "aids", "text": "Have you worn hearing aids before?"},
	{"id": "hardest", "text": "Where is hearing hardest for you?"},
]
## The red-flag question every workup needs (pain, drainage, dizziness).
const RED_FLAG_QUESTION := "red_flags"
## Questions per visit: the waiting room is full, so ask what matters.
const CHAT_BUDGET := 5
const DONE_ASKING := "Done asking"

## The tools on the tray, in tray order. Speech joins once the speech screen is on main.
const TOOLS: Array[StringName] = [&"chat", &"otoscopy", &"tymp", &"air", &"bone", &"masking", &"speech", &"call"]
## Tool card labels (the cards' text starts with these; no case note may start with one).
const TOOL_LABELS: Dictionary[StringName, String] = {
	&"chat": "Ask questions", &"otoscopy": "Look in the ears", &"tymp": "Tympanometer",
	&"air": "Air tones", &"bone": "Bone conduction", &"masking": "Masking", &"speech": "Speech tests",
	&"call": "Make the call",
}
const SPEECH_SCREEN := "res://ui/speech/speech_screen.tscn"
const TYMP_GADGET := "res://story/games/case_tymp.gd"

## Bone conduction is part of a full workup when any air threshold is poorer than this (dB HL):
## the "normal" band's top (ClinicRules.DEGREE_BANDS).
const BONE_NEEDED_ABOVE_DB := 25
## Two ears whose pure-tone averages are this close count as "about the same" (either ear may go first).
const SAME_EARS_PTA_DB := 5.0

## The chart question: the type of hearing in each ear (ClinicRules.hearing_type ids).
const TYPE_CHOICES: Array[StringName] = [&"normal", &"sensorineural", &"conductive", &"mixed"]
const TYPE_LABELS: Dictionary[StringName, String] = {
	&"normal": "Normal hearing", &"sensorineural": "Sensorineural loss", &"conductive": "Conductive loss",
	&"mixed": "Mixed loss",
}
## The otoscope's canal words and the ear tip that seals each (the tymp question).
const CANAL_TIPS: Dictionary = {"narrow": &"small", "average-sized": &"medium", "roomy": &"large"}

## Masked sheets the masking tool offers, in the order a pro runs them (bone before air: masked
## bone can lower the other ear's bone estimate, so it changes which air tones need masking).
const MASK_SHEETS: Array[StringName] = [&"bc_masked", &"ac_masked"]


# ---------------------------------------------------------------- the patient's truth

## True air thresholds of one ear (freq -> dB HL, every AC frequency).
static func truth_air(p: PatientProfile, ear: String) -> Dictionary:
	var out := {}
	if p == null:
		return out
	var t := p.get_thresholds(ear)
	for f: int in t:
		out[f] = int(t[f])
	return out


## True bone (cochlear) thresholds of one ear at the bone frequencies.
static func truth_bone(p: PatientProfile, ear: String) -> Dictionary:
	var out := {}
	if p == null:
		return out
	for f: int in ClinicRules.BC_FREQS:
		out[f] = p.get_bc_threshold(ear, f)
	return out


## The type of hearing an ear really has (what the chart question grades against).
static func truth_type(p: PatientProfile, ear: String) -> StringName:
	return ClinicRules.hearing_type(truth_air(p, ear), truth_bone(p, ear))


## The better cochlea's bone threshold at freq: what unmasked bone measures from either mastoid.
static func better_cochlea(p: PatientProfile, freq: int) -> int:
	return mini(p.get_bc_threshold("right", freq), p.get_bc_threshold("left", freq))


## The better ear by pure-tone average ("" when within SAME_EARS_PTA_DB).
static func better_ear(right: Dictionary, left: Dictionary) -> String:
	var r := ClinicRules.pta(right)
	var l := ClinicRules.pta(left)
	if is_nan(r) or is_nan(l) or absf(r - l) <= SAME_EARS_PTA_DB:
		return ""
	return "right" if r < l else "left"


## Any air threshold in either ear poorer than BONE_NEEDED_ABOVE_DB.
static func truth_needs_bone(p: PatientProfile) -> bool:
	for ear: String in ClinicRules.EARS:
		for f: int in p.get_thresholds(ear):
			if int(p.get_thresholds(ear)[f]) > BONE_NEEDED_ABOVE_DB:
				return true
	return false


## Masked bone from the truth: the bone frequencies where this ear's air sits more than 10 dB above
## the better cochlea (unmasked bone would show a gap that may be the other cochlea answering).
static func truth_masked_bone(p: PatientProfile, ear: String) -> Array[int]:
	var out: Array[int] = []
	for f: int in ClinicRules.BC_REQUIRED:
		if ClinicRules.bc_masking_needed(p.get_threshold(ear, f), better_cochlea(p, f)):
			out.append(f)
	return out


## Masked air from the truth, the way the rule reads a measured chart: air - IA >= the non-test
## ear's bone estimate (the better cochlea where bone is measured, else the other ear's air).
static func truth_masked_air(p: PatientProfile, ear: String, transducer: StringName = &"phones") -> Array[int]:
	var out: Array[int] = []
	var other := "left" if ear == "right" else "right"
	for f: int in ClinicRules.AC_FREQS:
		var est := better_cochlea(p, f) if ClinicRules.BC_REQUIRED.has(f) else p.get_threshold(other, f)
		if ClinicRules.ac_masking_needed(p.get_threshold(ear, f), est, transducer, f):
			out.append(f)
	return out


# ---------------------------------------------------------------- the measured chart

## Unmasked bone stamps of either mastoid, lowest per frequency (both read the better cochlea).
static func unmasked_bone(results: Dictionary) -> Dictionary:
	var out := {}
	for ear: String in ClinicRules.EARS:
		var t := ClinicRules.sheet_thresholds(results, ear, &"bc")
		for f: int in t:
			out[f] = mini(int(out.get(f, 999)), int(t[f]))
	return out


## Masked bone the chart asks for on one ear: wherever its air sits more than 10 dB above the
## unmasked bone (from either mastoid). Empty until some unmasked bone is stamped.
static func masked_bone_needed(results: Dictionary, ear: String) -> Array[int]:
	var out: Array[int] = []
	var ub := unmasked_bone(results)
	var ac := ClinicRules.best_thresholds(results, ear, false)
	var order: Array[int] = ClinicRules.BC_REQUIRED.duplicate()
	for f: int in ClinicRules.BC_FREQS:
		if not order.has(f):
			order.append(f)
	for f: int in order:
		if ub.has(f) and ac.has(f) and ClinicRules.bc_masking_needed(int(ac[f]), int(ub[f])):
			out.append(f)
	return out


## Masked air the chart asks for on one ear (the AudiOtron's own rule).
static func masked_air_needed(results: Dictionary, ear: String, transducer: StringName = &"phones") -> Array[int]:
	return ClinicRules.masked_freqs_needed(results, ear, &"ac_masked", transducer)


## Any stamps on a sheet of one ear.
static func has_sheet(results: Dictionary, ear: String, test: StringName) -> bool:
	return not ClinicRules.sheet_thresholds(results, ear, test).is_empty()


static func air_done(results: Dictionary) -> bool:
	return has_sheet(results, "right", &"ac") and has_sheet(results, "left", &"ac")


static func bone_done(results: Dictionary) -> bool:
	return not unmasked_bone(results).is_empty()


# ---------------------------------------------------------------- the workup

## Whether a case needs the tympanometer: its "needs_tymp" when given, else when either ear has a
## conductive part (conductive or mixed) or either tympanogram is not type A.
static func needs_tymp(c: Dictionary, p: PatientProfile) -> bool:
	if c.has("needs_tymp"):
		return bool(c["needs_tymp"])
	for ear: String in ClinicRules.EARS:
		if truth_type(p, ear) in [&"conductive", &"mixed"]:
			return true
		var t: Dictionary = (c.get("tymp", {}) as Dictionary).get(ear, {})
		if not t.is_empty() and CaseRules.tymp_type_of(t) != &"A":
			return true
	return false


## The steps a full workup of this case needs, in the order a pro runs them:
## [{"id": "chat" | "otoscopy" | "tymp" | "air" | "bone" | "bc_masked" | "ac_masked", "ear": "" or
## "right" / "left"}]. Masking follows the measured chart once its data is stamped (bone for masked
## bone, air for masked air), else the truth.
static func workup(c: Dictionary, p: PatientProfile, results: Dictionary, transducer: StringName = &"phones") -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"id": "chat", "ear": ""}, {"id": "otoscopy", "ear": ""}]
	if needs_tymp(c, p):
		out.append({"id": "tymp", "ear": ""})
	out.append({"id": "air", "ear": ""})
	if truth_needs_bone(p):
		out.append({"id": "bone", "ear": ""})
		for ear: String in ClinicRules.EARS:
			var need := masked_bone_needed(results, ear) if bone_done(results) else truth_masked_bone(p, ear)
			if not need.is_empty():
				out.append({"id": "bc_masked", "ear": ear})
	for ear: String in ClinicRules.EARS:
		var need2 := masked_air_needed(results, ear, transducer) if air_done(results) else truth_masked_air(p, ear, transducer)
		if not need2.is_empty():
			out.append({"id": "ac_masked", "ear": ear})
	return out


## The workup step a tool covers ("bc_masked" / "ac_masked" belong to the masking tool).
static func tool_for_step(step_id: String) -> StringName:
	if step_id == "bc_masked" or step_id == "ac_masked":
		return &"masking"
	return StringName(step_id)


## Whether a workup step is done: done = {tool id: true} for the plain tools; a masked step is done
## once that ear's masked sheet has a stamp, or once the player ran it ({"bc_masked:right": true}:
## the AudiOtron's own rule may find nothing to mask on the measured chart).
static func step_done(step: Dictionary, done: Dictionary, results: Dictionary) -> bool:
	var id := String(step["id"])
	if id == "bc_masked" or id == "ac_masked":
		var ear := String(step["ear"])
		return has_sheet(results, ear, StringName(id)) or bool(done.get(StringName("%s:%s" % [id, ear]), false))
	return bool(done.get(StringName(id), false))


## The key questions this case still needs (in deck order).
static func keys_left(c: Dictionary, asked: Array) -> Array[String]:
	var out: Array[String] = []
	for q: Dictionary in QUESTIONS:
		var id := String(q["id"])
		if (c.get("key_questions", []) as Array).has(id) and not asked.has(id):
			out.append(id)
	return out


## The tool a pro would pick next (the solver's pick): the first workup step not done (chat stays
## next while key questions remain and questions are left), else the call.
static func best_tool(c: Dictionary, p: PatientProfile, results: Dictionary, done: Dictionary, asked: Array, transducer: StringName = &"phones") -> StringName:
	for step: Dictionary in workup(c, p, results, transducer):
		var id := String(step["id"])
		if id == "chat":
			if not keys_left(c, asked).is_empty() and asked.size() < CHAT_BUDGET:
				return &"chat"
			continue
		if not step_done(step, done, results):
			return tool_for_step(id)
	return &"call"


# ---------------------------------------------------------------- medals

## "gold" with no slips, "silver" with one, "bronze" with more.
## The Chat medal from the key questions not asked: gold none, silver one, bronze more or the red flags.
static func chat_medal(keys_missed: Array) -> String:
	if keys_missed.has(RED_FLAG_QUESTION) or keys_missed.size() >= 2:
		return "bronze"
	return "silver" if keys_missed.size() == 1 else "gold"


static func medal_for_slips(slips: int) -> String:
	return "gold" if slips <= 0 else ("silver" if slips == 1 else "bronze")
