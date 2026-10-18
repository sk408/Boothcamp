extends RefCounted
## CaseData (cases, story-internal): loads and checks the case files, res://story/cases/<id>.json
## (docs/CASES.md, CONTRACTS.md §11). Story code preloads it by path:
##   const CaseData := preload("res://story/case_data.gd")
##   var c := CaseData.load_case("noise_notch")       # {} if missing or broken
##   var spec := CaseData.bean_spec(c)                # the clinic's patient_spec (colours, hair, extras)
##   var ids := CaseData.chapter_case_ids()           # every case Game.CHAPTERS registers
## A dialogue line in a case file is ["Speaker", "text"] or one action:
##   {"react": kind}  {"hoot": emote}  {"do": "hearing_aids" | "letter" | "boat" | "phone"}
##   {"choose": {"prompt", "options": [[text, points, Hoot's line]]}}   (repeats until the best pick)
## A case may name extra speakers in "voices" (Ginger's puppet, Chip): {name: {portrait, portrait_bg,
## name_color, voice}}. History options may end with that speaker's name to have them answer.

const CASES_DIR := "res://story/cases/"
const REQUIRED_KEYS: PackedStringArray = [
	"id", "patient_id", "speaker", "case_title", "look", "intro", "history", "red_flags", "otoscopy", "tymp",
	"instructions", "audiometry", "reveal", "evidence", "findings", "decision", "clue_pick", "payoff", "paper",
]
const PATTERNS: PackedStringArray = ["notch", "rising", "flat_one", "cookie"]   # each has a CaseBoard animation
const BURSTS: PackedStringArray = ["", "firework", "cymbal"]
const ACTIONS: PackedStringArray = ["react", "hoot", "do", "choose"]
const DOS: PackedStringArray = ["hearing_aids", "letter", "boat", "phone"]
const WHENS: PackedStringArray = ["", "symmetric", "asymmetric"]
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


## Every line of Hoot's in a case file (for the word-count test), as ["where", "text"].
static func hoot_lines(c: Dictionary) -> Array:
	var out: Array = []
	var scripts := {}
	for key: String in ["intro", "after_history", "instructions", "after_audiometry", "payoff"]:
		scripts[key] = c.get(key, [])
	scripts["otoscopy"] = (c.get("otoscopy", {}) as Dictionary).get("lines", [])
	scripts["tymp.after"] = (c.get("tymp", {}) as Dictionary).get("after", [])
	scripts["reveal.ask"] = (c.get("reveal", {}) as Dictionary).get("ask", [])
	scripts["reveal.lines"] = (c.get("reveal", {}) as Dictionary).get("lines", [])
	for key: String in scripts:
		for e: Variant in scripts[key]:
			if is_line(e) and String((e as Array)[0]) == "Hoot":
				out.append([key, String((e as Array)[1])])
			elif e is Dictionary and (e as Dictionary).has("choose"):
				for o: Variant in ((e as Dictionary)["choose"] as Dictionary).get("options", []):
					out.append([key + ".choose", String((o as Array)[2]) if (o as Array).size() > 2 else ""])
	for p: Variant in c.get("audiometry", []):
		var pd: Dictionary = p
		if pd.has("intro"):
			out.append(["audiometry.intro", String(pd["intro"])])
		for e: Variant in pd.get("before", []):
			if is_line(e) and String((e as Array)[0]) == "Hoot":
				out.append(["audiometry.before", String((e as Array)[1])])
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


## Everything wrong with a case file (empty = playable). Tests run this on every case.
static func validate(c: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in REQUIRED_KEYS:
		if not c.has(k):
			out.append("missing " + k)
	if not out.is_empty():
		return out
	var pid := String(c["patient_id"])
	if not ResourceLoader.exists(Game.PATIENT_DIR + pid + ".tres"):
		out.append("no patient " + pid)
	for key: String in ["intro", "instructions", "payoff"]:
		out.append_array(_check_script(c[key], key))
	var speakers := {String(c["speaker"]): true, "Hoot": true}
	for v: String in (c.get("voices", {}) as Dictionary):
		speakers[v] = true
	for key: String in ["after_history", "after_audiometry"]:
		if c.has(key):
			out.append_array(_check_script(c[key], key))
	var tags := {}
	for cl: Variant in c.get("always_clues", []):
		tags[String((cl as Dictionary).get("tag", ""))] = true
	var rounds: Array = c["history"]
	if rounds.is_empty():
		out.append("history has no rounds")
	var asked_red_flags := false
	for rd: Variant in rounds:
		var opts: Array = (rd as Dictionary).get("options", [])
		if opts.size() < 2:
			out.append("a history round needs 2+ options")
		for o: Variant in opts:
			var a: Array = o
			if a.size() < 5:
				out.append("history option needs [text, points, reply, clue, tag]: %s" % str(a))
				continue
			if a.size() > 6 and String(a[6]) != "" and not speakers.has(String(a[6])):
				out.append("history option answered by unknown speaker %s" % a[6])
			if String(a[4]) == String(c["red_flags"].get("tag", "")):
				asked_red_flags = true
	if not asked_red_flags:
		out.append("no history option asks the red-flag question (tag %s)" % c["red_flags"].get("tag", ""))
	tags[String(c["red_flags"].get("tag", ""))] = true
	for ex: Variant in c["red_flags"].get("extra_clues", []):
		tags[String((ex as Dictionary).get("tag", ""))] = true
	tags[String(c["otoscopy"].get("tag", ""))] = true
	tags[String(c["tymp"].get("tag", ""))] = true
	for f: Variant in c["findings"]:
		var fd: Dictionary = f
		if not WHENS.has(String(fd.get("when", ""))):
			out.append("finding %s: when must be symmetric or asymmetric" % fd.get("tag", ""))
		elif String(fd.get("when", "")) == "":
			tags[String(fd.get("tag", ""))] = true
		if not CLUE_SOURCES.has(String(fd.get("src", "test"))):
			out.append("finding %s: src must be one of %s" % [fd.get("tag", ""), ", ".join(CLUE_SOURCES)])
	var tymp: Dictionary = c["tymp"]
	if not CaseRules.TIP_SIZES.has(StringName(String(tymp.get("tip", "")))):
		out.append("tymp tip must be small, medium or large")
	if tymp.get("quiz", null) is Dictionary:
		var rights := 0
		for o: Variant in (tymp["quiz"] as Dictionary).get("options", []):
			if (o as Array).size() >= 2 and bool((o as Array)[1]):
				rights += 1
		if rights != 1:
			out.append("tymp quiz needs exactly one right option")
	for ear: String in ["right", "left"]:
		var t: Dictionary = tymp.get(ear, {})
		if not CaseRules.TYMP_TYPES.has(StringName(String(t.get("type", "")))):
			out.append("tymp %s: unknown type" % ear)
		elif CaseRules.tymp_type_of(t) != StringName(String(t["type"])):
			out.append("tymp %s: numbers say %s, not %s" % [ear, CaseRules.tymp_type_of(t), t["type"]])
	var plan: Array = c["audiometry"]
	var ears_ac := {}
	for p: Variant in plan:
		var pd: Dictionary = p
		if not ["right", "left"].has(String(pd.get("ear", ""))):
			out.append("audiometry step needs ear right/left")
		if not ["ac", "bc"].has(String(pd.get("test", ""))):
			out.append("audiometry steps are ac or bc (masked tests are added by the rules)")
		if String(pd.get("test", "")) == "ac":
			ears_ac[String(pd["ear"])] = true
	if ears_ac.size() < 2:
		out.append("audiometry must test air in both ears")
	var rv: Dictionary = c["reveal"]
	if not PATTERNS.has(String(rv.get("pattern", ""))):
		out.append("reveal pattern must be one of " + ", ".join(PATTERNS))
	if not BURSTS.has(String(rv.get("burst", ""))):
		out.append("reveal burst must be firework or cymbal")
	var ev: Dictionary = c["evidence"]
	if int(ev.get("answer", -1)) < 0 or int(ev.get("answer", -1)) >= (ev.get("options", []) as Array).size():
		out.append("evidence answer out of range")
	var dec: Dictionary = c["decision"]
	if not CaseRules.DECISIONS.has(StringName(String(dec.get("answer", "")))):
		out.append("decision answer must be fit, refer or today")
	for d: StringName in CaseRules.DECISIONS:
		if not (dec.get("lines", {}) as Dictionary).has(String(d)):
			out.append("decision line missing for " + String(d))
	var guaranteed := false
	for a: Variant in c["clue_pick"].get("answers", []):
		if tags.has(String(a)):
			guaranteed = true
	if not guaranteed:
		out.append("no clue_pick answer is always on the board (always_clues, red flags, otoscopy, tymp, findings)")
	for g: String in GRADES:
		if not (c["paper"].get("headlines", {}) as Dictionary).has(g):
			out.append("paper headline missing for " + g)
	return out


static func _check_script(lines: Variant, where: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not lines is Array:
		out.append(where + " is not a list")
		return out
	for e: Variant in lines:
		if is_line(e):
			continue
		if e is Dictionary:
			var d: Dictionary = e
			var ok := false
			for k: String in ACTIONS:
				if d.has(k):
					ok = true
					if k == "do" and not DOS.has(String(d[k])):
						out.append("%s: unknown do %s" % [where, d[k]])
					if k == "choose":
						var opts: Array = (d[k] as Dictionary).get("options", []) if d[k] is Dictionary else []
						if opts.size() < 2:
							out.append("%s: a choose needs 2+ options" % where)
						for o: Variant in opts:
							if not o is Array or (o as Array).size() < 3:
								out.append("%s: choose option needs [text, points, line]" % where)
			if ok:
				continue
		out.append("%s: bad entry %s" % [where, str(e)])
	return out
