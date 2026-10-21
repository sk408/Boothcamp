extends RefCounted
## DeskRun (arcade, story-internal): the pure parts of an Ears, Please! shift (docs/ARCADE.md part
## 2): the warm-up files, what can be pointed at, keyboard steps between targets, and every word
## the desk says (slips, lessons, HOOT HELP, ranks). No nodes, so the tests read it directly.
##   const DeskRun := preload("res://story/arcade/desk_run.gd")
##   var t := DeskRun.targets(file, sh)            # [{kind: intake, id} | {kind: chart, freq}]
##   var j := DeskRun.step(centres, i, Vector2.RIGHT)
##   var s := DeskRun.slip(v, file, outcome, stamp)   # {title, line}
##   var h := DeskRun.history(file["sudden"])          # the alarm-clock card's fields (shift 3)

const DeskRules := preload("res://story/arcade/desk_rules.gd")
const DeskDeck := preload("res://story/arcade/desk_deck.gd")

## Shifts you can play: all three (shift 3, Clinic Lead, adds DOCTOR TODAY and the alarm clock).
const PLAYABLE := 3

## The untimed warm-up of each shift: [kind, intake id to tick]. "fit_masked" is a FIT file whose
## chart shows masked bone [ ] sitting on air ("the gap is the distance, not the bracket").
const WARMUP: Dictionary = {
	1: [["fit", ""], ["one_ear", ""], ["intake", "dizziness"]],
	2: [["gap_both", ""], ["fit_masked", ""], ["intake", "wax"]],
	3: [["today", ""], ["sudden_late", ""], ["fluctuating", ""]],
}

## Hoot in the warm-up: before the stamp, and (REFER) before the proof. Anchors in brackets are
## filled in by the scene: {stamp} the right stamp, {proof} the best target.
const WARMUP_LINES: Dictionary = {
	"fit": ["Nothing ticked, the ears match, bone sits on air. Aids can help: stamp FIT!", ""],
	"one_ear": ["See the red O and blue X split apart? One ear worse: stamp REFER!",
		"Now prove it! Point at a column where the lines split."],
	"intake": ["A YES on the intake is a red flag. Stamp REFER, then point at it.",
		"Point at the box that says YES."],
	"gap_both": ["The ears match on air. But bone sits way above air: a gap. REFER!",
		"Point at 500, 1k or 2k, where bone and air split."],
	"fit_masked": ["Brackets mean masked bone. Here it sits on air: no gap. FIT!", ""],
	"intake_wax": ["New LOOKED boxes, from the otoscope. Lots of wax? A doctor or nurse first. REFER!",
		"Point at the wax box."],
	"today": ["New: the alarm clock. Sudden, under a month ago? That can't wait: stamp DOCTOR TODAY!",
		"Point at the alarm clock: it's the only proof for TODAY."],
	"sudden_late": ["Sudden, but months ago. Still a red flag, just not a same-day one: REFER.",
		"Point at the alarm clock: that's your proof."],
	"fluctuating": ["Hearing that comes and goes is a red flag too. Stamp REFER!",
		"Point at the alarm clock again."],
}
const WARMUP_WRONG_STAMP := "Not quite! Look where I'm pointing, then stamp again."
const WARMUP_WRONG_PROOF := "Close! Point here instead."
const WARMUP_DONE := "Desk opens! Two minutes. Read first, stamp second."
const SHIFT_START: Dictionary = {
	1: "Check every file. Any red flag means a doctor first!",
	2: "Promotion! New rule: the air-bone gap. And two LOOKED boxes: wax and ear shape.",
	3: "Promotion! New stamp: DOCTOR TODAY. Read the alarm clock on every file.",
}

## The first clean call of each kind in a run teaches its rule (the note holds the clock).
const LESSONS: Dictionary = {
	"fit": "Ears alike, no red flags, a loss aids can help: FIT. The goal sticker is the aim.",
	"one_ear": "One ear 15 dB worse at two pitches in a row, no known cause: a doctor checks why.",
	"one_sided": "Ringing in one ear only: a doctor checks it before any aids.",
	"drainage": "A leaking ear: a doctor first. It could be an infection.",
	"pain": "Ear pain: a doctor first. Never fit over a sore ear.",
	"dizziness": "Dizzy spells: a doctor first. Balance lives in the inner ear too.",
	"wax": "Lots of wax: a doctor or nurse clears it first, then test again.",
	"deformity": "An odd ear shape: a doctor first, before any fitting.",
	"gap": "Bone 15+ better than air at 500, 1k and 2k: the middle ear. A doctor first.",
	"today": "A sudden loss that started under a month ago: a doctor TODAY. Treatment works best started early.",
	"sudden_refer": "A loss that comes and goes, or a sudden one months ago: still a red flag. REFER.",
}
const VIP_LINE := "A VIP! Very Insistent Patient. Read the file, not the pleading."
const INCIDENT_LINE := "A same-day patient went home! One more, and the desk closes."

## The results' breakdown rows, in order: what each kind of file teaches.
const ROWS: Dictionary = {
	"fit": "CLEAR FILE: FIT",
	"tick": "A TICKED BOX",
	"one_ear": "ONE EAR WORSE",
	"gap": "AIR-BONE GAP",
	"sudden": "THE ALARM CLOCK",
}
const ROW_TIPS: Dictionary = {
	"fit": "No ticks, ears alike, no gap: aids can help.",
	"tick": "Read every box: any YES means a doctor first.",
	"one_ear": "Watch for the red O and blue X splitting.",
	"gap": "Bone 15+ above air at 500, 1k and 2k.",
	"sudden": "Sudden, under a month ago: TODAY. Older, or comes and goes: REFER.",
}

const RANK_LINES: Dictionary = {
	"Desk Legend": "Not a single red flag got past you.",
	"Red Flag Radar": "Safe and sharp.",
	"Learning the Ropes": "No flag got past, with Hoot's help. Next time, read them yourself!",
	"Better Safe Than Sorry": "No flag got past you, but some patients who only needed aids were sent away.",
	"Show Your Working": "Safe calls! Now point at what proves them.",
	"One Got Away": "One red flag slipped past. Read every box before you stamp.",
	"Red Flags Got Through": "Read every box and both lines before you stamp.",
	"Incident Report": "A same-day patient went home.",
	"Desk Closed": "Sudden loss can't wait.",
	"Coffee Break": "No files stamped.",
}


## (seeded) One warm-up file.
static func warmup_file(rng: RandomNumberGenerator, sh: Dictionary, step: Array, serial: int) -> Dictionary:
	var kind := String(step[0])
	if kind == "fit_masked":
		for i in 40:
			var f := DeskDeck.make_kind(rng, sh, "fit", serial)
			if has_masked_bone(f):
				f["warm"] = kind
				return f
		kind = "fit"
	var f := DeskDeck.make_kind(rng, sh, kind, serial, String(step[1]))
	f["warm"] = "intake_wax" if String(step[1]) == "wax" else kind
	return f


static func has_masked_bone(f: Dictionary) -> bool:
	for ear: String in ClinicRules.EARS:
		if not (f.get("bc_masked", {}).get(ear, {}) as Dictionary).is_empty():
			return true
	return false


## Everything that can be pointed at during PROVE IT, in reading order: every intake box of the
## shift (ticked or not), then every charted column. The full list every time, so the targets
## never hint at the answer.
static func targets(file: Dictionary, sh: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in sh["intake"]:
		out.append({"kind": "intake", "id": id})
	if bool(sh.get("sudden", false)):
		out.append({"kind": "sudden"})
	var cols: Array = (file["ac"]["right"] as Dictionary).keys()
	for f: int in (file["ac"]["left"] as Dictionary):
		if not cols.has(f):
			cols.append(f)
	cols.sort()
	for f: int in cols:
		out.append({"kind": "chart", "freq": int(f)})
	return out


static func same_target(a: Dictionary, b: Dictionary) -> bool:
	if String(a.get("kind", "")) != String(b.get("kind", "")):
		return false
	match String(a.get("kind", "")):
		"intake":
			return String(a.get("id", "")) == String(b.get("id", ""))
		"chart":
			return int(a.get("freq", -1)) == int(b.get("freq", -2))
	return true


static func target_index(list: Array[Dictionary], t: Dictionary) -> int:
	for i in list.size():
		if same_target(list[i], t):
			return i
	return -1


## The anchor id of a target (Hoot points at it; the mouse bot clicks it).
static func anchor(t: Dictionary) -> String:
	match String(t.get("kind", "")):
		"intake":
			return "desk_intake_" + String(t["id"])
		"chart":
			return "desk_chart_%d" % int(t["freq"])
		"sudden":
			return "desk_sudden"
	return ""


## Keyboard steps: from target i, the nearest target in direction dir (arrows). Along the
## direction counts once and off to the side twice, so Right moves along a row and Down moves down
## a column; a target further off to the side than along is not in that direction at all (Up and
## Down on a chart column stay put rather than jump to the intake card). Stays put at an edge.
static func step(centres: Array[Vector2], i: int, dir: Vector2) -> int:
	if i < 0 or i >= centres.size():
		return 0
	var best := i
	var best_score := INF
	for j in centres.size():
		if j == i:
			continue
		var d := centres[j] - centres[i]
		var along := d.dot(dir)
		if along <= 4.0:
			continue
		var across := absf(d.cross(dir))
		if across > along:
			continue
		var score := along + 2.0 * across
		if score < best_score:
			best_score = score
			best = j
	return best


## "2k", "1.5k", "500".
static func freq_word(f: int) -> String:
	if f < 1000:
		return str(f)
	if f % 1000 == 0:
		return "%dk" % (f / 1000)
	return "%sk" % String.num(f / 1000.0, 1)


## "2k-4k" for a run of columns, "2k" for one.
static func freq_span(freqs: Array) -> String:
	if freqs.is_empty():
		return ""
	var lo := int(freqs.min())
	var hi := int(freqs.max())
	return freq_word(lo) if lo == hi else "%s-%s" % [freq_word(lo), freq_word(hi)]


## What a proof shows, in a few words ("Dizzy spells: YES", "One ear worse at 2k-4k").
static func reason(proof: Dictionary, file: Dictionary = {}) -> String:
	match String(proof.get("kind", "")):
		"intake":
			return "%s: YES" % DeskRules.INTAKE_WORDS[String(proof["id"])]
		"sudden":
			return DeskRules.sudden_words(file.get("sudden", {}))
		"chart":
			if String(proof.get("rule", "")) == "gap":
				return "Air-bone gap, %s ear" % String(proof.get("ear", "")).to_upper()
			return "One ear worse at %s" % freq_span(proof.get("freqs", []))
	return ""


## The best proof's words, with "both ears" when both ears carry the gap.
static func best_reason(v: Dictionary, file: Dictionary) -> String:
	var p := DeskRules.best_proof(v)
	if String(p.get("rule", "")) == "gap":
		var ears := 0
		for q: Dictionary in v.get("proofs", []):
			if String(q.get("rule", "")) == "gap":
				ears += 1
		if ears == 2:
			return "Air-bone gap, both ears"
	return reason(p, file)


## The feedback note after a call that was not clean: {title, line}.
static func slip(v: Dictionary, file: Dictionary, outcome: StringName, stamp: StringName = &"") -> Dictionary:
	var why := best_reason(v, file)
	match outcome:
		DeskRules.MISSED_FLAG:
			return {"title": "CITATION", "line": "%s. A doctor first: REFER." % why}
		DeskRules.OVER:
			return {"title": "EXTRA REFERRAL", "line": "%s: aids can help. FIT." % _fit_words(file)}
		DeskRules.WRONG_REASON:
			if stamp == &"today":
				return {"title": "RIGHT STAMP, WRONG PROOF", "line": "The proof for TODAY is the alarm clock: %s." % why}
			return {"title": "RIGHT STAMP, WRONG PROOF", "line": "The proof: %s." % why}
		DeskRules.TOO_URGENT:
			return {"title": "TOO URGENT", "line": "%s. A red flag, but not a same-day one: REFER." % why}
		DeskRules.MISSED_TODAY:
			return {"title": "INCIDENT", "line": "%s: a doctor TODAY." % why}
	return {"title": "", "line": ""}


## The lesson key of a file: the rule its right call rests on.
static func lesson(file: Dictionary) -> String:
	var kind := String(file.get("kind", "fit"))
	match kind:
		"fit":
			return "fit"
		"intake":
			for id: String in (file.get("intake", {}) as Dictionary):
				if bool(file["intake"][id]):
					return id
			return "one_sided"
		"gap", "gap_both":
			return "gap"
		"today":
			return "today"
		"sudden_late", "fluctuating":
			return "sudden_refer"
	return kind


## The breakdown row a file belongs to (ROWS).
static func row(file: Dictionary) -> String:
	match String(file.get("kind", "fit")):
		"fit":
			return "fit"
		"intake":
			return "tick"
		"gap", "gap_both":
			return "gap"
		"one_ear":
			return "one_ear"
	return "sudden"


## "Nothing ticked, ears alike, no gap" (and, with an alarm clock on the file, "a slow loss"): a
## FIT file in words.
static func _fit_words(file: Dictionary) -> String:
	if (file.get("sudden", {}) as Dictionary).is_empty():
		return "Nothing ticked, ears alike, no gap"
	return "Nothing ticked, ears alike, no gap, a slow loss"


## HOOT HELP: what Hoot says before stamping and pointing for you.
static func help_line(v: Dictionary, file: Dictionary) -> String:
	if v["decision"] == &"fit":
		return "%s: FIT!" % _fit_words(file)
	var p := DeskRules.best_proof(v)
	if v["decision"] == &"today":
		return "%s: DOCTOR TODAY! Point at the alarm clock." % reason(p, file)
	match String(p.get("kind", "")):
		"intake":
			return "%s. A red flag: REFER, then point at it." % reason(p)
		"sudden":
			return "%s: a red flag. REFER, then point at the alarm clock." % reason(p, file)
	if String(p.get("rule", "")) == "gap":
		return "Bone well above air at 500, 1k and 2k: REFER, point there."
	return "The ears split apart at %s: REFER, then point there." % freq_span(p.get("freqs", []))


## The alarm-clock card's fields (shift 3), each [label, value, ear]: how the loss came on, when it
## started and the ear it hit (ear "" names none). Only what the patient says: never the stamp, so
## the reading is the player's.
static func history(s: Dictionary) -> Array:
	var h := int(s.get("came_on_h", 0))
	var how := "Slowly, over years"
	var ear := ""
	match String(s.get("pattern", "")):
		"sudden":
			how = "Suddenly, overnight" if h <= 12 else ("Suddenly, in a day" if h <= 36 else "Suddenly, in %d days" % roundi(h / 24.0))
			ear = String(s.get("ear", ""))
		"fluctuating":
			how = "Comes and goes"
	var when := DeskRules.when_words(int(s.get("days_ago", 0)))
	return [["CAME ON", how, ""], ["STARTED", when.left(1).to_upper() + when.substr(1), ""],
		["EAR", ear.to_upper() if ear != "" else "–", ear]]


## The high-score board of a shift (ArcadeScores board key).
static func board(shift_id: int) -> String:
	return "table" if shift_id <= 1 else "table_%d" % shift_id


## What promotion still needs, or "" when promoted.
static func promotion_needs(stats: Dictionary) -> String:
	if DeskRules.promoted(stats):
		return ""
	var need: PackedStringArray = []
	if int(stats.get("missed_flag", 0)) > 0:
		need.append("no red flag missed")
	if DeskRules.accuracy(stats) < DeskRules.SAFE_CLEAN:
		need.append("3 in 4 calls clean")
	if int(stats.get("files", 0)) < DeskRules.PROMOTE_FILES:
		need.append("%d+ files" % DeskRules.PROMOTE_FILES)
	return ", ".join(need)
