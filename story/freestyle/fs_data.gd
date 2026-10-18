extends RefCounted
## FsData (freestyle, story-internal): loads and checks the walk-in clinic's case files,
## res://story/freestyle/cases/<id>.json (docs/FREESTYLE.md §3). Freestyle patients are their own
## deck: never chapters, never in Game.CHAPTERS, and the story days never see them.
##   const FsData := preload("res://story/freestyle/fs_data.gd")
##   var c := FsData.load_case("fs_penny")    # {} if missing or broken
##   FsData.validate(c)                       # problems (empty = playable)
##   FsData.case_ids()                        # every walk-in, in waiting-room order
##   FsData.register_speakers()               # portraits and voices for every walk-in
##   FsData.set_next_case(id); FsData.next_case()   # the waiting room's pick, for the clinic scene
## A dialogue entry is ["Speaker", "text"] or one action, as in the story cases (CaseData):
##   {"react": kind}  {"hoot": emote}  {"do": "hearing_aids" | "letter" | "boat" | "phone"}

const CaseData := preload("res://story/case_data.gd")
const CasePortraits := preload("res://story/case_portraits.gd")
const Voice := preload("res://story/voice.gd")
const FsRules := preload("res://story/freestyle/fs_rules.gd")

const CASES_DIR := "res://story/freestyle/cases/"
## Every walk-in, in waiting-room order (a test checks that every case file is listed here; a list,
## not a folder scan, so exported builds find them all).
const CASE_IDS: PackedStringArray = [
	"fs_penny", "fs_mabel", "fs_sid", "fs_viola", "fs_buck", "fs_melody", "fs_skyler",
]
const REQUIRED_KEYS: PackedStringArray = [
	"id", "patient_id", "speaker", "stars", "teaser", "look", "voice", "hello", "answers", "key_questions",
	"otoscopy", "tymp", "decision", "decision_lines", "why", "debrief", "goodbye", "paper",
]
## What the otoscope can show on main. Earwax and fluid views join with the conductive days.
const OTO_VIEWS: PackedStringArray = ["clear"]
const TEASER_MAX := 64
const NOTE_MAX := 48
const WHY_MIN_OPTIONS := 3
## The bot clicks a choice by its first characters (tools/autoplay_bot.gd).
const PREFIX := 18
const META_KEY := &"freestyle_next_case"

static var _cache: Dictionary = {}


## The case file as a Dictionary ({} with an error if it is missing or not an object).
static func load_case(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var path := CASES_DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_error("FsData: no case file " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("FsData: %s is not a JSON object" % path)
		return {}
	_cache[id] = parsed
	return parsed


static func case_ids() -> PackedStringArray:
	return CASE_IDS


## The patient behind a case (null if missing).
static func patient_for(c: Dictionary) -> PatientProfile:
	var pid := String(c.get("patient_id", ""))
	if pid == "" or not ResourceLoader.exists(Game.PATIENT_DIR + pid + ".tres"):
		return null
	return Game.load_patient(pid) as PatientProfile


## Give every walk-in a dialogue portrait and a voice (the waiting room and the clinic call this).
static func register_speakers() -> void:
	for id: String in CASE_IDS:
		var c := load_case(id)
		if c.is_empty():
			continue
		var who := String(c.get("speaker", ""))
		CasePortraits.register(who, c.get("look", {}))
		if c.get("voice", null) is Dictionary:
			Voice.register(who, c["voice"])


## The waiting room's pick, kept for the clinic scene (scene changes free every node, so it rides
## on the Engine's metadata). --freestyle=<id> on the command line wins.
static func set_next_case(id: String) -> void:
	Engine.set_meta(META_KEY, id)


static func next_case() -> String:
	var id := Game.cli_value("freestyle", "")
	if id == "" and Engine.has_meta(META_KEY):
		id = String(Engine.get_meta(META_KEY))
	if not CASE_IDS.has(id):
		id = CASE_IDS[0]
	return id


## A patient's reply to one deck question, as lines.
static func answer_lines(c: Dictionary, qid: String) -> Array[String]:
	var out: Array[String] = []
	var a: Variant = (c.get("answers", {}) as Dictionary).get(qid, {})
	var say: Variant = (a as Dictionary).get("say", "") if a is Dictionary else ""
	if say is Array:
		for s: Variant in say:
			out.append(String(s))
	elif String(say) != "":
		out.append(String(say))
	return out


static func answer_note(c: Dictionary, qid: String) -> String:
	var a: Variant = (c.get("answers", {}) as Dictionary).get(qid, {})
	return String((a as Dictionary).get("note", "")) if a is Dictionary else ""


## The ear tip that seals this patient's canals (from the otoscope's canal word).
static func tip_for(c: Dictionary) -> StringName:
	return FsRules.CANAL_TIPS.get(String((c.get("otoscopy", {}) as Dictionary).get("canal", "")), &"medium")


## Every line Hoot says in a case file, as ["where", "text"] (for the word-count test).
static func hoot_lines(c: Dictionary) -> Array:
	var out: Array = []
	for key: String in ["hello", "debrief", "goodbye"]:
		for e: Variant in c.get(key, []):
			if CaseData.is_line(e) and String((e as Array)[0]) == "Hoot":
				out.append([key, String((e as Array)[1])])
	var dl: Dictionary = c.get("decision_lines", {})
	for d: Variant in dl:
		out.append(["decision_lines." + String(d), String(dl[d])])
	for o: Variant in (c.get("why", {}) as Dictionary).get("options", []):
		if o is Array and (o as Array).size() > 2:
			out.append(["why", String((o as Array)[2])])
	return out


## Everything wrong with a case file (empty = playable). Tests run this on every case.
static func validate(c: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in REQUIRED_KEYS:
		if not c.has(k):
			out.append("missing " + k)
	if not out.is_empty():
		return out
	var id := String(c["id"])
	var p := patient_for(c)
	if p == null:
		out.append("no patient " + String(c["patient_id"]))
	else:
		for pr: String in p.validate():
			out.append("patient: " + pr)
	var stars := int(c["stars"])
	if stars < 1 or stars > 3:
		out.append("stars must be 1 to 3")
	var teaser := String(c["teaser"])
	if teaser == "" or teaser.length() > TEASER_MAX:
		out.append("teaser must be 1 to %d characters" % TEASER_MAX)
	var speaker := String(c["speaker"])
	if speaker == "" or speaker == "Hoot":
		out.append("bad speaker")
	for key: String in ["hello", "debrief", "goodbye"]:
		out.append_array(_check_script(c[key], key, speaker))
	# the question deck: a reply to every question
	var answers: Dictionary = c["answers"]
	for q: Dictionary in FsRules.QUESTIONS:
		var qid := String(q["id"])
		if not answers.has(qid):
			out.append("answers: missing " + qid)
			continue
		if answer_lines(c, qid).is_empty():
			out.append("answers.%s: no reply" % qid)
		if answer_note(c, qid).length() > NOTE_MAX:
			out.append("answers.%s: note over %d characters" % [qid, NOTE_MAX])
	for a: Variant in answers:
		if not _deck_ids().has(String(a)):
			out.append("answers: unknown question " + String(a))
	var keys: Array = c["key_questions"]
	if not keys.has(FsRules.RED_FLAG_QUESTION):
		out.append("key_questions must include " + FsRules.RED_FLAG_QUESTION)
	if keys.size() > FsRules.CHAT_BUDGET:
		out.append("key_questions: more than the %d a visit allows" % FsRules.CHAT_BUDGET)
	for k: Variant in keys:
		if not _deck_ids().has(String(k)):
			out.append("key_questions: unknown " + String(k))
	# the otoscope
	var oto: Dictionary = c["otoscopy"]
	if not FsRules.CANAL_TIPS.has(String(oto.get("canal", ""))):
		out.append("otoscopy.canal must be one of " + ", ".join(PackedStringArray(FsRules.CANAL_TIPS.keys())))
	for ear: String in ClinicRules.EARS:
		var v: Variant = oto.get(ear, null)
		if not v is Dictionary or not OTO_VIEWS.has(String((v as Dictionary).get("view", ""))) or String((v as Dictionary).get("caption", "")) == "":
			out.append("otoscopy.%s needs a view (%s) and a caption" % [ear, ", ".join(OTO_VIEWS)])
	if String(oto.get("note", "")) == "":
		out.append("otoscopy: no note")
	# the tympanometer
	var ty: Dictionary = c["tymp"]
	for ear: String in ClinicRules.EARS:
		var t: Variant = ty.get(ear, null)
		if not t is Dictionary:
			out.append("tymp: no " + ear)
			continue
		var td: Dictionary = t
		for k: String in ["type", "peak_daPa", "peak_ml", "ecv_ml"]:
			if not td.has(k):
				out.append("tymp.%s: missing %s" % [ear, k])
		if td.has("peak_daPa") and td.has("peak_ml") and td.has("ecv_ml") \
				and CaseRules.tymp_type_of(td) != StringName(String(td.get("type", ""))):
			out.append("tymp.%s: numbers read as type %s, not %s" % [ear, CaseRules.tymp_type_of(td), td.get("type", "")])
	if String(ty.get("note", "")) == "":
		out.append("tymp: no note")
	# the call
	var dec := StringName(String(c["decision"]))
	if not FsRules.DECISIONS.has(dec):
		out.append("decision must be one of " + ", ".join(PackedStringArray(FsRules.DECISIONS)))
	var dl: Dictionary = c["decision_lines"]
	for d: StringName in FsRules.DECISIONS:
		if String(dl.get(String(d), "")) == "":
			out.append("decision_lines: no line for " + String(d))
	var why: Dictionary = c["why"]
	var wopts: Array = why.get("options", [])
	var rights := 0
	var prefixes := {}
	if String(why.get("prompt", "")) == "":
		out.append("why: no prompt")
	if wopts.size() < WHY_MIN_OPTIONS:
		out.append("why: needs %d+ options" % WHY_MIN_OPTIONS)
	for o: Variant in wopts:
		if not o is Array or (o as Array).size() != 3 or not (o as Array)[1] is bool:
			out.append("why: an option is [text, right (true/false), Hoot's line]")
			continue
		var oa: Array = o
		if bool(oa[1]):
			rights += 1
		var pre := String(oa[0]).substr(0, PREFIX)
		if prefixes.has(pre):
			out.append("why: two options start with '%s'" % pre)
		prefixes[pre] = true
	if rights == 0:
		out.append("why: no right option")
	# the paper
	var paper: Dictionary = c["paper"]
	for part: String in ["headlines", "subheads"]:
		var d: Dictionary = paper.get(part, {})
		for g: String in CaseData.GRADES:
			if String(d.get(g, "")) == "":
				out.append("paper.%s: no %s" % [part, g])
	for hl: Array in hoot_lines(c):
		if String(hl[1]).split(" ", false).size() > CaseData.HOOT_MAX_WORDS:
			out.append("%s: Hoot's line is over %d words: %s" % [hl[0], CaseData.HOOT_MAX_WORDS, hl[1]])
	if id != "" and not CASE_IDS.has(id):
		out.append("not listed in FsData.CASE_IDS")
	return out


static func _deck_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for q: Dictionary in FsRules.QUESTIONS:
		out.append(String(q["id"]))
	return out


static func _check_script(lines: Variant, where: String, speaker: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not lines is Array or (lines as Array).is_empty():
		out.append(where + " needs at least one line")
		return out
	for e: Variant in lines:
		if CaseData.is_line(e):
			var who := String((e as Array)[0])
			if who != speaker and who != "Hoot":
				out.append("%s: unknown speaker %s" % [where, who])
			continue
		if e is Dictionary:
			var d: Dictionary = e
			var ok := false
			for k: String in ["react", "hoot", "do"]:
				if d.has(k):
					ok = true
					if k == "do" and not CaseData.DOS.has(String(d[k])):
						out.append("%s: unknown do %s" % [where, d[k]])
			if ok:
				continue
		out.append("%s: bad entry %s" % [where, str(e)])
	return out
