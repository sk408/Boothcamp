extends RefCounted
## CaseData (cases, story-internal): loads and checks the case files, res://story/cases/<id>.json
## (docs/CASES.md, CONTRACTS.md §11). Story code preloads it by path:
##   const CaseData := preload("res://story/case_data.gd")
##   var c := CaseData.load_case("noise_notch")       # {} if missing or broken
##   var spec := CaseData.bean_spec(c)                # the clinic's patient_spec (colours, hair, extras)
##   var ids := CaseData.chapter_case_ids()           # every case Game.CHAPTERS registers
## A dialogue line in a case file is ["Speaker", "text"] or one action:
##   {"react": kind}  {"hoot": emote}  {"do": "hearing_aids" | "letter" | "boat" | "phone" | "wax_jar" | "plane"}
##   {"choose": {"prompt", "options": [[text, points, Hoot's line]]}}   (repeats until the best pick)
## A case may name extra speakers in "voices" (Ginger's puppet, Chip): {name: {portrait, portrait_bg,
## name_color, voice}}. History options may end with that speaker's name to have them answer.

const CASES_DIR := "res://story/cases/"
const REQUIRED_KEYS: PackedStringArray = [
	"id", "patient_id", "speaker", "case_title", "look", "intro", "history", "red_flags", "otoscopy", "tymp",
	"instructions", "audiometry", "reveal", "evidence", "findings", "decision", "clue_pick", "payoff", "paper",
]
const PATTERNS: PackedStringArray = ["notch", "rising", "flat_one", "cookie", "gap", "shadow"]   # each has a CaseBoard animation
## What fills a "gap" pattern's air-bone gap on the board: a waxy cork, or water and a rubber duck.
const PLUGS: PackedStringArray = ["wax", "fluid"]
const BURSTS: PackedStringArray = ["", "firework", "cymbal"]
const ACTIONS: PackedStringArray = ["react", "hoot", "do", "choose"]
const DOS: PackedStringArray = ["hearing_aids", "letter", "boat", "phone", "wax_jar", "plane"]
## A finding's "when": always, or only when the chart (the truth when unmeasured) is symmetric,
## asymmetric, conductive on the case ear, or shows the air-bone-gap red flag there; "shadow" when
## the case ear answered unmasked but not masked (the other ear heard it across the head), and
## "no_response" when its masked bone and masked air found nothing at the audiometer's limits.
const WHENS: PackedStringArray = ["", "symmetric", "asymmetric", "conductive", "abg_flag", "shadow", "no_response"]
## The otoscope's look (CaseOtoscopy): a healthy drum, a wax plug, or fluid behind the drum.
const VIEWS: PackedStringArray = ["clear", "wax", "fluid"]
## A clue card's colour: a plain clue or a red flag.
const KINDS: PackedStringArray = ["clue", "flag"]
## The case file's card limit (CaseBoard.MAX_CARDS reads this): the proof cards and decoys must fit.
const MAX_CARDS := 9
## The owl's emotes (mirrors world/characters/owl.gd emote(); world is asked for a constant).
const HOOT_EMOTES: PackedStringArray = ["hop", "cheer", "wing_up", "facepalm", "nod", "gasp"]
## Plan keys a case test step may pass straight to the AudiOtron (audiometer_screen.gd start_test).
const PLAN_KEYS: PackedStringArray = ["montage", "skip_hoot_retest"]
## The type of every top-level key validate() reads (required keys first, then optional ones).
## TYPE_FLOAT also accepts whole numbers.
const TOP_TYPES: Dictionary = {
	"id": TYPE_STRING, "patient_id": TYPE_STRING, "speaker": TYPE_STRING, "case_title": TYPE_STRING,
	"look": TYPE_DICTIONARY, "intro": TYPE_ARRAY, "history": TYPE_ARRAY, "red_flags": TYPE_DICTIONARY,
	"otoscopy": TYPE_DICTIONARY, "tymp": TYPE_DICTIONARY, "instructions": TYPE_ARRAY, "audiometry": TYPE_ARRAY,
	"reveal": TYPE_DICTIONARY, "evidence": TYPE_DICTIONARY, "findings": TYPE_ARRAY, "decision": TYPE_DICTIONARY,
	"clue_pick": TYPE_DICTIONARY, "payoff": TYPE_ARRAY, "paper": TYPE_DICTIONARY,
	"voice": TYPE_DICTIONARY, "voices": TYPE_DICTIONARY, "always_clues": TYPE_ARRAY, "joke_line": TYPE_STRING,
	"after_history": TYPE_ARRAY, "after_audiometry": TYPE_ARRAY, "sudden_clock": TYPE_DICTIONARY,
	"retest": TYPE_DICTIONARY,
}
## Sub-keys the runner reads directly, with their types (ANY_TEXT: a line or a list of lines).
const ANY_TEXT := -1
const SUB_KEYS: Dictionary = {
	"red_flags": {"tag": TYPE_STRING, "ask_line": TYPE_STRING, "answer": ANY_TEXT, "clue": TYPE_STRING, "card": TYPE_STRING},
	"otoscopy": {"caption": TYPE_STRING, "clue": TYPE_STRING, "tag": TYPE_STRING},
	"tymp": {"tip": TYPE_STRING, "right": TYPE_DICTIONARY, "left": TYPE_DICTIONARY, "clue": TYPE_STRING, "tag": TYPE_STRING},
	"evidence": {"prompt": TYPE_STRING, "options": TYPE_ARRAY, "answer": TYPE_FLOAT},
	"decision": {"prompt": TYPE_STRING, "answer": TYPE_STRING, "lines": TYPE_DICTIONARY},
	"clue_pick": {"prompt": TYPE_STRING, "answers": TYPE_ARRAY, "wrong_line": TYPE_STRING, "right_line": TYPE_STRING},
	"reveal": {"pattern": TYPE_STRING, "title": TYPE_STRING},
	"paper": {"headlines": TYPE_DICTIONARY},
}
## Where a clue card came from (its header on the case board, CaseBoard.SRC_TITLES).
const CLUE_SOURCES: PackedStringArray = ["history", "note", "look", "tymp", "flag", "test"]
## Hoot's coaching lines stay short (house style).
const HOOT_MAX_WORDS := 18
const LOOK_NAMES: PackedStringArray = ["face", "hair_style", "glasses", "prop"]
const GRADES: PackedStringArray = ["S", "A", "B", "C", "Do-over"]

static var _cache: Dictionary = {}


## The case file as a Dictionary ({} with an error if it is missing or not an object).
static func load_case(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := CASES_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("CaseData: no case file " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("CaseData: %s is not a JSON object" % path)
		return {}
	_cache[id] = parsed
	return parsed


## Every case id registered in Game.CHAPTERS (entries with a "case" key), in chapter order.
static func chapter_case_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for c: Dictionary in Game.chapters():
		var cid := String(c.get("case", ""))
		if cid != "":
			out.append(cid)
	return out


## The case a chapter plays ("" when the chapter is not a case).
static func case_for_chapter(chapter_id: String) -> String:
	return String(Game.chapter(chapter_id).get("case", ""))


## The case whose patient (or one of its "voices") speaks as `speaker` ({} if none). For portraits.
static func case_for_speaker(speaker: String) -> Dictionary:
	if speaker == "":
		return {}
	for cid: String in chapter_case_ids():
		var c := load_case(cid)
		if String(c.get("speaker", "")) == speaker or (c.get("voices", {}) as Dictionary).has(speaker):
			return c
	return {}


## The portrait look for a speaker: the patient's "look", or a voice's own entry ({} if none).
static func look_for_speaker(speaker: String) -> Dictionary:
	var c := case_for_speaker(speaker)
	if c.is_empty():
		return {}
	var voices: Dictionary = c.get("voices", {})
	if voices.has(speaker):
		return voices[speaker]
	return c.get("look", {})


## A patient's true air thresholds for one ear (freq -> dB), for when the chart has gaps.
static func truth(patient: PatientProfile, ear: String) -> Dictionary:
	var out := {}
	if patient == null:
		return out
	var t := patient.get_thresholds(ear)
	for f: int in t:
		out[f] = int(t[f])
	return out


## The type of loss the case teaches for an ear, from the patient's truth (bone = air without bone data).
static func truth_type(patient: PatientProfile, ear: String) -> StringName:
	if patient == null:
		return &"unknown"
	var air := truth(patient, ear)
	var bone := {}
	for f: int in air:
		bone[f] = patient.get_bc_threshold(ear, f)
	return ClinicRules.hearing_type(air, bone)


## An ear's bone as the chart shows it (masked replaces unmasked), without its no-response stamps:
## a stamp at the limit only says bone sits there or past it, so it cannot show a gap.
static func answered_bone(res: Dictionary, ear: String) -> Dictionary:
	var e: Dictionary = (res.get("ears", {}) as Dictionary).get(ear, {})
	var un: Dictionary = e.get("bc", {})
	var masked: Dictionary = e.get("bc_masked", {})
	var bone := {}
	for f: int in un:
		if not masked.has(f) and not bool((un[f] as Dictionary).get("no_response", false)):
			bone[f] = int((un[f] as Dictionary).get("stored_db", 0))
	for f: int in masked:
		if not bool((masked[f] as Dictionary).get("no_response", false)):
			bone[f] = int((masked[f] as Dictionary).get("stored_db", 0))
	return bone


## The ear's type as the chart shows it (results ears[ear].hearing_type), except that no-response
## bone drops out (answered_bone). With no bone left and air outside normal the ear is
## sensorineural: Morgan's deaf ear, whose raw stamps fake a 50 dB "gap" between the air and bone
## limits.
static func measured_type(res: Dictionary, ear: String) -> StringName:
	var e: Dictionary = (res.get("ears", {}) as Dictionary).get(ear, {})
	var kind: StringName = e.get("hearing_type", &"unknown")
	var bone := answered_bone(res, ear)
	if bone.size() == ClinicRules.best_thresholds(res, ear, true).size():
		return kind
	var air := ClinicRules.best_thresholds(res, ear, false)
	var typed := ClinicRules.hearing_type(air, bone)
	if typed == &"unknown" and not air.is_empty():
		return &"sensorineural"
	return typed


## True when an ear's sheet (&"ac_masked", &"bc_masked") has stamps and every one is no response.
static func all_no_response(res: Dictionary, ear: String, sheet: StringName) -> bool:
	var e: Dictionary = (res.get("ears", {}) as Dictionary).get(ear, {})
	var t: Dictionary = e.get(String(sheet), {})
	if t.is_empty():
		return false
	for f: int in t:
		if not bool((t[f] as Dictionary).get("no_response", false)):
			return false
	return true


## True when the ear hears nothing the audiometer can reach: air and bone past their limits at every
## bone frequency (the truth Morgan's right ear holds).
static func dead_truth(p: PatientProfile, ear: String) -> bool:
	if p == null:
		return false
	for f: int in ClinicRules.BC_REQUIRED:
		if p.get_threshold(ear, f) <= ClinicRules.max_db(f) or p.get_bc_threshold(ear, f) <= ClinicRules.max_db_for(f, &"bone"):
			return false
	return true


## The finding "shadow": the case ear answered unmasked, yet its masked air found nothing, at most of
## its masked frequencies (the other ear heard those beeps across the head). res = {} reads the
## truth: a dead ear whose other ear's bone plus the real phones IA stays on the dial.
static func shadow_shows(res: Dictionary, p: PatientProfile, ear: String) -> bool:
	if not res.has("ears"):
		if not dead_truth(p, ear):
			return false
		var other := "left" if ear == "right" else "right"
		for f: int in ClinicRules.BC_REQUIRED:
			if p.get_bc_threshold(other, f) + p.get_ia(&"phones") > ClinicRules.max_db(f):
				return false
		return true
	var e: Dictionary = (res.get("ears", {}) as Dictionary).get(ear, {})
	var masked: Dictionary = e.get("ac_masked", {})
	var un: Dictionary = e.get("freqs", {})
	var hits := 0
	for f: int in masked:
		if bool((masked[f] as Dictionary).get("no_response", false)) and un.has(f) \
				and not bool((un[f] as Dictionary).get("no_response", false)):
			hits += 1
	return not masked.is_empty() and hits * 2 > masked.size()


## The finding "no_response": masked bone (when run) and masked air found nothing on the case ear.
## res = {} reads the truth (dead_truth).
static func no_response_shows(res: Dictionary, p: PatientProfile, ear: String) -> bool:
	if not res.has("ears"):
		return dead_truth(p, ear)
	var e: Dictionary = (res.get("ears", {}) as Dictionary).get(ear, {})
	if not (e.get("bc_masked", {}) as Dictionary).is_empty() and not all_no_response(res, ear, &"bc_masked"):
		return false
	return all_no_response(res, ear, &"ac_masked")


## Every playable script in a case file, as [["where", script], ...]: the top-level scripts, the
## sections' lines, each test step's "before" and the retest's. The one walker for hoot_lines() and
## validate(). Missing or mistyped sections are skipped (validate reports them).
static func scripts(c: Dictionary) -> Array:
	var out: Array = []
	for key: String in ["intro", "after_history", "instructions", "after_audiometry", "payoff"]:
		if c.has(key):
			out.append([key, c[key]])
	_section_scripts(c, "", out)
	var rt: Variant = c.get("retest", null)
	if rt is Dictionary:
		for key: String in ["intro", "before", "instructions", "payoff"]:
			if (rt as Dictionary).has(key):
				out.append(["retest." + key, (rt as Dictionary)[key]])
		_section_scripts(rt, "retest.", out)
	return out


## The scripts inside a case's (or its retest's) sections: otoscopy.lines, tymp.after, each test
## step's before, reveal.ask and reveal.lines.
static func _section_scripts(c: Dictionary, prefix: String, out: Array) -> void:
	for pair: Array in [["otoscopy", "lines"], ["tymp", "after"], ["reveal", "ask"], ["reveal", "lines"]]:
		var sec: Variant = c.get(String(pair[0]), null)
		if sec is Dictionary and (sec as Dictionary).has(String(pair[1])):
			out.append(["%s%s.%s" % [prefix, pair[0], pair[1]], (sec as Dictionary)[String(pair[1])]])
	var plan: Variant = c.get("audiometry", null)
	if plan is Array:
		for p: Variant in plan:
			if p is Dictionary and (p as Dictionary).has("before"):
				out.append([prefix + "audiometry.before", (p as Dictionary)["before"]])
			if p is Dictionary and (p as Dictionary).get("if_tested", null) is Dictionary:
				for f: Variant in (p as Dictionary)["if_tested"]:
					out.append(["%saudiometry.if_tested.%s" % [prefix, f], (p as Dictionary)["if_tested"][f]])


## Every line of Hoot's in a case file (for the word-count test), as ["where", "text"].
static func hoot_lines(c: Dictionary) -> Array:
	var out: Array = []
	for pair: Array in scripts(c):
		var where := String(pair[0])
		if not pair[1] is Array:
			continue
		for e: Variant in pair[1]:
			if is_line(e) and String((e as Array)[0]) == "Hoot":
				out.append([where, String((e as Array)[1])])
			elif e is Dictionary and (e as Dictionary).get("choose", null) is Dictionary:
				for o: Variant in ((e as Dictionary)["choose"] as Dictionary).get("options", []):
					if o is Array and (o as Array).size() > 2:
						out.append([where + ".choose", String((o as Array)[2])])
	for plan: Variant in [c.get("audiometry", []), (c.get("retest", {}) as Dictionary).get("audiometry", []) if c.get("retest", null) is Dictionary else []]:
		if not plan is Array:
			continue
		for p: Variant in plan:
			if p is Dictionary and (p as Dictionary).has("intro"):
				out.append(["audiometry.intro", String((p as Dictionary)["intro"])])
	for rd: Variant in c.get("history", []):
		for o: Variant in (rd as Dictionary).get("options", []):
			var a: Array = o
			if a.size() > 5 and String(a[5]) != "":
				out.append(["history", String(a[5])])
	for key: String in ["joke_line"]:
		if c.has(key):
			out.append([key, String(c[key])])
	out.append(["red_flags.ask_line", String((c.get("red_flags", {}) as Dictionary).get("ask_line", ""))])
	var quiz: Variant = (c.get("tymp", {}) as Dictionary).get("quiz", null)
	if quiz is Dictionary:
		for o: Variant in (quiz as Dictionary).get("options", []):
			out.append(["tymp.quiz", String((o as Array)[2]) if (o as Array).size() > 2 else ""])
	var ev: Dictionary = c.get("evidence", {})
	for w: Variant in ev.get("wrong", []):
		out.append(["evidence.wrong", String(w)])
	out.append(["evidence.right", String(ev.get("right", ""))])
	for d: Variant in (c.get("decision", {}) as Dictionary).get("lines", {}).values():
		out.append(["decision", String(d)])
	var cp: Dictionary = c.get("clue_pick", {})
	for key: String in ["wrong_line", "right_line"]:
		out.append(["clue_pick." + key, String(cp.get(key, ""))])
	for key: String in ["wrong_lines", "right_lines"]:
		for v: Variant in (cp.get(key, {}) as Dictionary).values():
			out.append(["clue_pick." + key, String(v)])
	return out.filter(func(x: Array) -> bool: return String(x[1]) != "")


## The clinic's patient_spec from a case's "look": colours become Color, names become StringName.
static func bean_spec(c: Dictionary) -> Dictionary:
	var look: Dictionary = c.get("look", {})
	var out := {"name": String(c.get("speaker", "Patient"))}
	for k: String in look:
		var v: Variant = look[k]
		if LOOK_NAMES.has(k):
			out[k] = StringName(String(v))
		elif v is String and String(v).begins_with("#"):
			out[k] = Color(String(v))
		else:
			out[k] = v
	return out


## A case's dialogue entry is a line (["Speaker", "text"]).
static func is_line(entry: Variant) -> bool:
	return entry is Array and (entry as Array).size() == 2


## Thresholds from JSON ({"250": 25, ...}) as freq -> int.
static func thresholds(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		out[int(String(k))] = int(d[k])
	return out


## Everything wrong with a case file (empty = playable). Tests run this on every case. A malformed
## file (a missing key, a wrong type anywhere) returns problems and never raises a script error.
static func validate(c: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in REQUIRED_KEYS:
		if not c.has(k):
			out.append("missing " + k)
	for k: String in TOP_TYPES:
		if c.has(k) and not _is_type(c[k], int(TOP_TYPES[k])):
			out.append("%s has the wrong type" % k)
	if not out.is_empty():
		return out
	for sec: String in SUB_KEYS:
		var d: Dictionary = c[sec]
		var subs: Dictionary = SUB_KEYS[sec]
		for k: String in subs:
			if not d.has(k):
				out.append("%s: missing %s" % [sec, k])
			elif not _is_type(d[k], int(subs[k])):
				out.append("%s.%s has the wrong type" % [sec, k])
	if not out.is_empty():
		return out
	var pid := String(c["patient_id"])
	if not ResourceLoader.exists(Game.PATIENT_DIR + pid + ".tres"):
		out.append("no patient " + pid)
	var speakers := {String(c["speaker"]): true, "Hoot": true}
	var voices: Dictionary = c.get("voices", {})
	for v: Variant in voices:
		speakers[String(v)] = true
		if not voices[v] is Dictionary:
			out.append("voice %s is not an object" % v)
	for pair: Array in scripts(c):
		out.append_array(_check_script(pair[1], String(pair[0]), speakers))
	# the tags of the cards every visit deals (the runner skips a card with empty text)
	var tags := {}
	for cl: Variant in c.get("always_clues", []):
		if not cl is Dictionary or not (cl as Dictionary).get("text", null) is String:
			out.append("always_clues: each needs a text")
			continue
		_deal(tags, (cl as Dictionary).get("tag", ""), (cl as Dictionary)["text"])
		out.append_array(_check_kind((cl as Dictionary).get("kind", "clue"), "always_clues"))
	var rf: Dictionary = c["red_flags"]
	out.append_array(_check_history(c, speakers, String(rf["tag"])))
	_deal(tags, rf["tag"], rf["clue"])
	out.append_array(_check_kind(rf.get("card_kind", "clue"), "red_flags.card_kind"))
	if rf.has("clue_kind"):
		out.append_array(_check_kind(rf["clue_kind"], "red_flags.clue_kind"))
	var extras: Variant = rf.get("extra_clues", [])
	if not extras is Array:
		out.append("red_flags.extra_clues must be a list")
		extras = []
	for ex: Variant in extras:
		if not ex is Dictionary or not (ex as Dictionary).get("text", null) is String:
			out.append("red_flags.extra_clues: each needs a text")
			continue
		_deal(tags, (ex as Dictionary).get("tag", ""), (ex as Dictionary)["text"])
		out.append_array(_check_kind((ex as Dictionary).get("kind", "clue"), "red_flags.extra_clues"))
	var oto: Dictionary = c["otoscopy"]
	_deal(tags, oto["tag"], oto["clue"])
	out.append_array(_check_otoscopy(oto, "otoscopy"))
	out.append_array(_check_kind(oto.get("kind", "clue"), "otoscopy"))
	var ty: Dictionary = c["tymp"]
	_deal(tags, ty["tag"], ty["clue"])
	out.append_array(_check_tymp(ty, "tymp"))
	if ty.get("quiz", null) is Dictionary:
		var rights := 0
		var qopts: Variant = (ty["quiz"] as Dictionary).get("options", [])
		for o: Variant in (qopts if qopts is Array else []):
			if not o is Array or (o as Array).size() < 2:
				out.append("tymp quiz option needs [text, right, line]")
			elif not (o as Array)[1] is bool:
				out.append("tymp quiz option: right must be true or false")
			elif (o as Array)[1]:
				rights += 1
		if rights != 1:
			out.append("tymp quiz needs exactly one right option")
	for f: Variant in c["findings"]:
		if not f is Dictionary:
			out.append("findings: each must be an object")
			continue
		var fd: Dictionary = f
		if not fd.get("tag", null) is String or not fd.get("text", null) is String:
			out.append("finding needs a tag and a text")
			continue
		var when := String(fd.get("when", ""))
		if not WHENS.has(when):
			out.append("finding %s: when must be one of %s" % [fd["tag"], ", ".join(WHENS)])
		elif when == "":
			_deal(tags, fd["tag"], fd["text"])
		if not CLUE_SOURCES.has(String(fd.get("src", "test"))):
			out.append("finding %s: src must be one of %s" % [fd["tag"], ", ".join(CLUE_SOURCES)])
		out.append_array(_check_kind(fd.get("kind", "clue"), "finding " + String(fd["tag"])))
	var rv: Dictionary = c["reveal"]
	var plan_problems := _check_plan(c["audiometry"], "audiometry", false)
	out.append_array(plan_problems)
	if plan_problems.is_empty():
		var ears_ac := plan_ears(c["audiometry"], "ac")
		if ears_ac.size() < 2:
			out.append("audiometry must test air in both ears")
		var case_ear := String(rv.get("ear", "right"))
		if case_ear == "right" or case_ear == "left":
			# Steve: unmasked bone goes on the better ear; the runner then masks bone on the reveal ear
			# wherever its air sits over that bone (masked_bone_ears), as on Day 2
			var better := "left" if case_ear == "right" else "right"
			if plan_ears(c["audiometry"], "bc") != PackedStringArray([better]):
				out.append("unmasked bone goes on the better ear (%s) only; masked bone on the reveal ear (%s) follows" % [better, case_ear])
	var pattern := String(rv["pattern"])
	if not PATTERNS.has(pattern):
		out.append("reveal pattern must be one of " + ", ".join(PATTERNS))
	if not BURSTS.has(String(rv.get("burst", ""))):
		out.append("reveal burst must be firework or cymbal")
	if pattern == "gap" and not PLUGS.has(String(rv.get("plug", ""))):
		out.append("a gap reveal needs plug: " + ", ".join(PLUGS))
	elif pattern != "gap" and rv.has("plug"):
		out.append("plug only goes with the gap pattern")
	if not ["right", "left", "both"].has(String(rv.get("ear", "right"))):
		out.append("reveal ear must be right, left or both")
	var ev: Dictionary = c["evidence"]
	var ev_opts: Array = ev["options"]
	if int(ev["answer"]) < 0 or int(ev["answer"]) >= ev_opts.size():
		out.append("evidence answer out of range")
	if ev.has("wrong") and not ev["wrong"] is Array:
		out.append("evidence.wrong must be a list")
	if ev.has("answer_from_type"):
		if not ["right", "left"].has(String(ev["answer_from_type"])):
			out.append("evidence answer_from_type must be right or left")
		if ev_opts.size() != 3:
			out.append("answer_from_type needs exactly 3 options: sensorineural, conductive, mixed")
	var dec: Dictionary = c["decision"]
	var answer := String(dec["answer"])
	if not CaseRules.DECISIONS.has(StringName(answer)):
		out.append("decision answer must be fit, refer or today")
	for d: StringName in CaseRules.DECISIONS:
		if not (dec["lines"] as Dictionary).get(String(d), null) is String:
			out.append("decision line missing for " + String(d))
	if dec.has("asymmetry_known_cause") and not dec["asymmetry_known_cause"] is bool:
		out.append("decision.asymmetry_known_cause must be true or false")
	var cp: Dictionary = c["clue_pick"]
	var guaranteed := false
	for a: Variant in cp["answers"]:
		if tags.has(String(a)):
			guaranteed = true
	if not guaranteed:
		out.append("no clue_pick answer is always on the board (always_clues, red flags, otoscopy, tymp, findings)")
	for key: String in ["wrong_lines", "right_lines"]:
		if cp.has(key) and not cp[key] is Dictionary:
			out.append("clue_pick.%s must be an object" % key)
	if cp.has("decoys") and not cp["decoys"] is Array:
		out.append("clue_pick.decoys must be a list")
	elif (cp["answers"] as Array).size() + (cp.get("decoys", []) as Array).size() > MAX_CARDS:
		out.append("clue_pick: answers + decoys fit on the board (%d cards at most)" % MAX_CARDS)
	var paper: Dictionary = c["paper"]
	for g: String in GRADES:
		if not (paper["headlines"] as Dictionary).get(g, null) is String:
			out.append("paper headline missing for " + g)
	if paper.has("subheads") and not paper["subheads"] is Dictionary:
		out.append("paper subheads must be an object")
	out.append_array(_check_wrong_first(paper.get("wrong_first", null), answer))
	if c.has("retest"):
		out.append_array(_check_retest(c["retest"], pid))
	return out


## A card the runner deals on every visit: its tag counts for the clue pick (empty text never shows).
static func _deal(tags: Dictionary, tag: Variant, text: Variant) -> void:
	if text is String and String(text) != "":
		tags[String(tag)] = true


## v is the JSON type t (TYPE_FLOAT also takes a whole number; ANY_TEXT a String or a list).
static func _is_type(v: Variant, t: int) -> bool:
	if t == ANY_TEXT:
		return v is String or v is Array
	if t == TYPE_FLOAT:
		return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT
	return typeof(v) == t


static func _check_kind(kind: Variant, where: String) -> PackedStringArray:
	if kind is String and KINDS.has(String(kind)):
		return PackedStringArray()
	return PackedStringArray(["%s: kind must be clue or flag" % where])


## The history rounds: options [text, points, reply, clue, tag, Hoot's line?, answered by?], and one
## option must ask the red-flag question (its tag).
static func _check_history(c: Dictionary, speakers: Dictionary, red_tag: String) -> PackedStringArray:
	var out := PackedStringArray()
	var rounds: Array = c["history"]
	if rounds.is_empty():
		out.append("history has no rounds")
	var asked_red_flags := false
	for rd: Variant in rounds:
		var opts: Variant = (rd as Dictionary).get("options", null) if rd is Dictionary else null
		if not opts is Array or (opts as Array).size() < 2:
			out.append("a history round needs 2+ options")
			continue
		for o: Variant in opts:
			if not o is Array or (o as Array).size() < 5:
				out.append("history option needs [text, points, reply, clue, tag]: %s" % str(o))
				continue
			var a: Array = o
			if not a[0] is String or not _is_type(a[1], TYPE_FLOAT) or not _is_type(a[2], ANY_TEXT) \
					or not a[3] is String or not a[4] is String:
				out.append("history option has a wrong type: %s" % str(a))
				continue
			if a.size() > 6 and String(a[6]) != "" and not speakers.has(String(a[6])):
				out.append("history option answered by unknown speaker %s" % a[6])
			if String(a[4]) == red_tag:
				asked_red_flags = true
	if not asked_red_flags:
		out.append("no history option asks the red-flag question (tag %s)" % red_tag)
	return out


## A look in the ear: a known view (and a caption, where the runner shows one).
static func _check_otoscopy(oto: Dictionary, where: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not VIEWS.has(String(oto.get("view", "clear"))):
		out.append("%s: view must be one of %s" % [where, ", ".join(VIEWS)])
	if not ["right", "left"].has(String(oto.get("ear", "right"))):
		out.append("%s: ear must be right or left" % where)
	if not oto.get("caption", "") is String:
		out.append("%s: caption must be text" % where)
	return out


## Both ears' tympanograms: a known type whose numbers agree, and a canal volume that reads right.
## A flat (B) tymp has no peak (under TYMP_FLAT_ML), read with its volume (CaseRules.tymp_b_reading);
## every other type sits inside the adult band.
static func _check_tymp(ty: Dictionary, where: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not CaseRules.TIP_SIZES.has(StringName(String(ty.get("tip", "")))):
		out.append("%s tip must be small, medium or large" % where)
	for ear: String in ["right", "left"]:
		if not ty.get(ear, null) is Dictionary:
			out.append("%s %s: missing" % [where, ear])
			continue
		var t: Dictionary = ty[ear]
		if not t.get("type", null) is String or not CaseRules.TYMP_TYPES.has(StringName(String(t["type"]))):
			out.append("%s %s: unknown type" % [where, ear])
			continue
		var bad_number := false
		for k: String in ["peak_daPa", "peak_ml", "ecv_ml"]:
			if not _is_type(t.get(k, null), TYPE_FLOAT):
				out.append("%s %s: %s must be a number" % [where, ear, k])
				bad_number = true
		if bad_number:
			continue
		var kind := StringName(String(t["type"]))
		var ecv := float(t["ecv_ml"])
		if kind == &"B":
			if float(t["peak_ml"]) >= CaseRules.TYMP_FLAT_ML:
				out.append("%s %s: a flat tymp has no peak (peak_ml under %s)" % [where, ear, CaseRules.TYMP_FLAT_ML])
		else:
			if CaseRules.tymp_type_of(t) != kind:
				out.append("%s %s: numbers say %s, not %s" % [where, ear, CaseRules.tymp_type_of(t), kind])
			if ecv < CaseRules.TYMP_ADULT_ECV.x or ecv > CaseRules.TYMP_ADULT_ECV.y:
				out.append("%s %s: canal volume %s is outside the adult band" % [where, ear, ecv])
	return out


## A test plan: steps {ear, test, hoot_turn_after?, intro?, before?, montage?, skip_hoot_retest?,
## if_tested? (air steps: {"750": script}, said once the stamps asked for that half-octave and it
## is on the ear's chart)}.
## Masked tests are never listed: the rules add them. air_only: the retest's plan (air tests only).
static func _check_plan(plan: Array, where: String, air_only: bool) -> PackedStringArray:
	var out := PackedStringArray()
	if plan.is_empty():
		out.append(where + " has no steps")
	for p: Variant in plan:
		if not p is Dictionary:
			out.append(where + ": each step must be an object")
			continue
		var pd: Dictionary = p
		if not ["right", "left"].has(String(pd.get("ear", ""))):
			out.append(where + " step needs ear right/left")
		var tests: Array = ["ac"] if air_only else ["ac", "bc"]
		if not tests.has(String(pd.get("test", ""))):
			out.append(where + (" steps are air (ac) only" if air_only
				else " steps are ac or bc (masked tests are added by the rules)"))
		if not _is_type(pd.get("hoot_turn_after", 0), TYPE_FLOAT):
			out.append(where + ": hoot_turn_after must be a number")
		elif pd.get("montage", false) is bool and pd.get("montage", false) and int(pd.get("hoot_turn_after", 0)) != 0:
			out.append(where + ": montage is Hoot's alone (hoot_turn_after 0)")
		for k: String in PLAN_KEYS:
			if pd.has(k) and not pd[k] is bool:
				out.append("%s: %s must be true or false" % [where, k])
		if pd.has("intro") and not pd["intro"] is String:
			out.append(where + ": intro must be text")
		if pd.has("if_tested"):
			if not pd["if_tested"] is Dictionary or String(pd.get("test", "")) != "ac" or air_only:
				out.append(where + ": if_tested is for the first visit's air steps: {\"750\": script}")
			else:
				for f: Variant in pd["if_tested"]:
					# (E1) 1.5k, 3k and 6k are routine, so only 750 is ever added by the 20 dB rule
					if not ClinicRules.INTEROCTAVES.has(int(String(f))) or ClinicRules.is_routine(int(String(f))):
						out.append("%s: if_tested %s is not a half-octave the 20 dB rule adds (750)" % [where, f])
	return out


## The ears a plan runs a test on, in plan order.
static func plan_ears(plan: Array, test: String) -> PackedStringArray:
	var out := PackedStringArray()
	for p: Variant in plan:
		if p is Dictionary and String((p as Dictionary).get("test", "")) == test:
			var ear := String((p as Dictionary).get("ear", ""))
			if not out.has(ear):
				out.append(ear)
	return out


## The ears the runner checks for masked bone after a case's plan, in order: the plan's bone ears, then
## every other air-tested ear. Unmasked bone on the better ear alone shows the poorer ear's gap
## (ClinicRules.unmasked_bone), so a one-sided case gets its masked bone on the case ear. Masked air
## then follows on each air-tested ear (plan_ears(plan, "ac")). Used by level_case.gd and tools/monkey.gd.
static func masked_bone_ears(plan: Array) -> PackedStringArray:
	var out := plan_ears(plan, "bc")
	for ear: String in plan_ears(plan, "ac"):
		if not out.has(ear):
			out.append(ear)
	return out


## A case's first-visit look found a canal full of wax (the otoscopy view "wax"): air goes through
## headphones, since inserts go deep and could push the wax further.
static func canal_blocked(c: Dictionary) -> bool:
	return c.get("otoscopy", null) is Dictionary and String((c["otoscopy"] as Dictionary).get("view", "clear")) == "wax"


## The air transducer for a case's tests: the inserts once owned, else headphones; always headphones
## while the canal is blocked. Used by level_case.gd, tools/autoplay_bot.gd and tools/monkey.gd.
static func air_transducer(blocked: bool) -> StringName:
	return &"inserts" if Game.has_upgrade("insert_earphones") and not blocked else &"phones"


## paper.wrong_first: {decision: {headline, subhead?}} for each wrong first stamp (never the answer).
static func _check_wrong_first(wf: Variant, answer: String) -> PackedStringArray:
	var out := PackedStringArray()
	if wf == null:
		return out
	if not wf is Dictionary:
		out.append("paper.wrong_first must be an object")
		return out
	for k: Variant in wf:
		var key := String(k)
		if not CaseRules.DECISIONS.has(StringName(key)) or key == answer:
			out.append("paper.wrong_first: %s is not a wrong call" % key)
		var e: Variant = (wf as Dictionary)[k]
		if not e is Dictionary or not (e as Dictionary).get("headline", null) is String \
				or String((e as Dictionary)["headline"]) == "":
			out.append("paper.wrong_first.%s needs a headline" % key)
		elif (e as Dictionary).has("subhead") and not (e as Dictionary)["subhead"] is String:
			out.append("paper.wrong_first.%s: subhead must be text" % key)
	return out


## The retest after treatment: {patient_id, card?, intro?, otoscopy?, tymp?, before?, instructions?,
## audiometry (air only), reveal {ear, label?, title?, lines?}, payoff?}. Its patient is a truth table
## of its own (the ear after treatment) that no chapter registers.
static func _check_retest(rt: Dictionary, case_pid: String) -> PackedStringArray:
	var out := PackedStringArray()
	var rpid: Variant = rt.get("patient_id", null)
	if not rpid is String:
		out.append("retest needs a patient_id")
	elif String(rpid) == case_pid:
		out.append("retest patient must differ from the visit's")
	elif not ResourceLoader.exists(Game.PATIENT_DIR + String(rpid) + ".tres"):
		out.append("no retest patient " + String(rpid))
	elif not Game.chapter_for_patient(String(rpid)).is_empty():
		out.append("retest patient %s belongs to a chapter" % rpid)
	if rt.has("card") and not rt["card"] is String:
		out.append("retest card must be text")
	if not rt.get("audiometry", null) is Array:
		out.append("retest needs an audiometry list")
		return out
	var plan_problems := _check_plan(rt["audiometry"], "retest.audiometry", true)
	out.append_array(plan_problems)
	if not rt.get("reveal", null) is Dictionary:
		out.append("retest needs a reveal")
	else:
		var rv: Dictionary = rt["reveal"]
		var ear := String(rv.get("ear", ""))
		if not ["right", "left"].has(ear):
			out.append("retest reveal ear must be right or left")
		elif plan_problems.is_empty() and not plan_ears(rt["audiometry"], "ac").has(ear):
			out.append("retest reveal ear %s has no air test" % ear)
		for k: String in ["label", "title"]:
			if rv.has(k) and not rv[k] is String:
				out.append("retest reveal %s must be text" % k)
	if rt.has("otoscopy"):
		if rt["otoscopy"] is Dictionary:
			out.append_array(_check_otoscopy(rt["otoscopy"], "retest otoscopy"))
		else:
			out.append("retest otoscopy must be an object")
	if rt.has("tymp"):
		if rt["tymp"] is Dictionary:
			var ty: Dictionary = (rt["tymp"] as Dictionary).duplicate()
			if not ty.has("tip"):
				ty["tip"] = "medium"   # the visit's tip stands in
			out.append_array(_check_tymp(ty, "retest tymp"))
		else:
			out.append("retest tymp must be an object")
	return out


## One script: lines ["Speaker", "text"] by the patient, Hoot or a voice, and actions {"react": kind},
## {"hoot": emote}, {"do": prop}, {"choose": {"prompt", "options": [[text, points, line]]}}.
static func _check_script(lines: Variant, where: String, speakers: Dictionary = {}) -> PackedStringArray:
	var out := PackedStringArray()
	if not lines is Array:
		out.append(where + " is not a list")
		return out
	for e: Variant in lines:
		if is_line(e):
			var a: Array = e
			if not a[0] is String or not a[1] is String:
				out.append("%s: a line is [speaker, text]: %s" % [where, str(e)])
			elif not speakers.is_empty() and not speakers.has(String(a[0])):
				out.append("%s: unknown speaker %s" % [where, a[0]])
			continue
		if e is Dictionary:
			var d: Dictionary = e
			var ok := false
			for k: String in ACTIONS:
				if d.has(k):
					ok = true
					if k == "react" and not d[k] is String:
						out.append("%s: react must be a name" % where)
					if k == "hoot" and not HOOT_EMOTES.has(str(d[k])):
						out.append("%s: unknown hoot emote %s" % [where, d[k]])
					if k == "do" and not DOS.has(str(d[k])):
						out.append("%s: unknown do %s" % [where, d[k]])
					if k == "choose":
						var opts: Variant = (d[k] as Dictionary).get("options", []) if d[k] is Dictionary else []
						if not opts is Array or (opts as Array).size() < 2:
							out.append("%s: a choose needs 2+ options" % where)
							continue
						for o: Variant in opts:
							if not o is Array or (o as Array).size() < 3 or not (o as Array)[0] is String \
									or not _is_type((o as Array)[1], TYPE_FLOAT) or not (o as Array)[2] is String:
								out.append("%s: choose option needs [text, points, line]" % where)
			if ok:
				continue
		out.append("%s: bad entry %s" % [where, str(e)])
	return out
