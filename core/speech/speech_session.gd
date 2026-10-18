class_name SpeechSession
extends RefCounted
## SpeechSession: pure logic of one patient's speech tests, both ears (CONTRACTS.md §9.4).
## No nodes and no clock: the SPEECH screen calls present(), score(), store() and the controls, and
## handles all timing (the word "plays", then the answer appears). It holds the speech simulator,
## the technique checker and the golf / combo / points scoring. Results shape: CONTRACTS.md §9.5.
##
## The SRT dance it teaches (SpeechRules has the numbers, docs/SPEECH.md §3):
##   - familiarise first; start at the PTA (rounded to 5) + 15
##   - repeated it -> down 10 (5 tolerated); missed it -> up 5
##   - score what the patient SAID: half a word, a different word or silence are all misses
##   - SRT = the softest level with 2+ right and half or more, the level 5 below scoring under half
##   - compare with the PTA: within 6 dB good, 7-12 fair, 13+ poor (recheck; think non-organic)
## Golf: each SRT is a hole; par = the textbook dance from the first word's level (srt_par).

signal technique(kind: StringName, data: Dictionary)
signal combo_changed(n: int, multiplier: int)
signal reaction(kind: StringName, data: Dictionary)
## One measurement was stored. sheet: CONTRACTS.md §9.5.
signal stored(ear: String, test: StringName, sheet: Dictionary)

## Hoot's one-liners per technique kind (original wording, 18 words max). {he} {his} {him} tokens.
const TIPS: Dictionary[StringName, String] = {
	&"srt_start": "Start at {his} PTA plus 15: easy words first, then work down.",
	&"srt_wrong_step": "Got it: down 10. Missed: up 5. Same dance as the beeps!",
	&"srt_store_no_bracket": "Not bracketed yet! 5 dB below, {he} must get fewer than half right.",
	&"srt_store_wrong_level": "SRT: the softest level with two right and half or more. Check the trail!",
	&"misscored": "Score what {he} SAID. Half a word, a different word, or silence: all misses.",
	&"speech_marathon": "Long word lists tire patients out. Bracket quickly and store!",
	&"half_word": "Half a word is a miss. Lots of half-words can be a sign of exaggerating.",
	&"cross_heard_speech": "Loud speech can cross the skull to the other ear. Mask the other ear!",
	&"speech_mask_needed": "This loud, speech can cross to the other ear. Speech noise on: press M.",
	&"score_first": "Score that word first: did {he} say the whole word?",
}
## misscored, by what the patient actually said.
const MISSCORED_TIPS: Dictionary[StringName, String] = {
	&"half": "Half a word is a miss. Only the whole word counts!",
	&"wrong": "That wasn't the word! A different word is a miss.",
	&"silence": "Silence is a miss. Score it as missed.",
	&"correct": "{He} said the whole word! Score it as correct.",
}
## Hoot's line on the PTA/SRT agreement after a store ({diff} = dB apart).
const AGREEMENT_TIPS: Dictionary[StringName, String] = {
	&"good": "SRT and PTA agree within 6 dB. The audiogram checks out!",
	&"fair": "{diff} dB apart: fair agreement. Re-check the tones near 500 to 2000 Hz.",
	&"poor": "{diff} dB apart: POOR agreement! Recheck, re-instruct, and think about why.",
}
## Positive kinds and the points they are worth (times the combo multiplier).
const POINTS: Dictionary[StringName, int] = {&"speech_textbook": 10, &"srt_good_start": 10, &"srt_store_ok": 50}
const GOLF_POINTS: Dictionary[StringName, int] = {&"albatross": 300, &"eagle": 200, &"birdie": 100, &"par": 50, &"bogey": 20}
## More words than this x par in one measurement: the patient tires (once per measurement).
const MARATHON_FACTOR := 3.0
## Default material per test.
const DEFAULT_LISTS: Dictionary[StringName, String] = {&"srt": "spondee_a"}
## In the visit score an SRT counts like this many tone stamps (merge_results).
const SHEET_WEIGHT := 3.0

var patient: PatientProfile
var sim: SpeechSim
var plan: Dictionary = {}
var test: StringName = &"srt"
var ear: String = "right"
## The level dial (dB HL).
var db: int = 50
var transducer: StringName = &"phones"
## Speech noise in the other ear (it tracks the level: level - 20).
var mask_on: bool = false
var list_id: String = "spondee_a"
## The AudiOtron's results (§5.1) this visit: the PTA and the masking rule come from them.
var tone_results: Dictionary = {}
var coached: Dictionary = {"right": false, "left": false}
## false while Hoot runs the test (his words and stores are not scored).
var scoring: bool = true

## true between present() and score(): the patient has answered and the word needs a score.
var awaiting_score: bool = false
## The last presented trial (a reference into trials).
var current: Dictionary = {}

var trials: Dictionary = {}          ## test -> ear -> Array of trial dictionaries
var sheets: Dictionary = {}          ## test -> ear -> stored sheet
var errors: Array[Dictionary] = []
var checks: int = 0
var clean_checks: int = 0
var combo: int = 0
var max_combo: int = 0
var points: int = 0
var presentations: int = 0
var hoot_presentations: int = 0

var _items: Array[Dictionary] = []
var _queue: Array[Dictionary] = []
var _next: Dictionary = {}
var _last_item_id := ""
var _meas_errors: Dictionary = {}    ## "test:ear" -> Array of error kinds
var _once: Dictionary = {}


func _init(p: PatientProfile, seed_value: int = 0) -> void:
	patient = p
	sim = SpeechSim.new(p, seed_value)
	for t: StringName in SpeechRules.TESTS:
		trials[t] = {"right": [], "left": []}
		sheets[t] = {}


## Plan keys (all optional, §9.4): test, list, words (item ids to use), exclude (ids to drop),
## tones (§5.1 results), transducer, level (the dial's starting level).
func configure(p: Dictionary) -> void:
	plan = p.duplicate(true)
	test = StringName(String(plan.get("test", "srt")))
	list_id = String(plan.get("list", DEFAULT_LISTS.get(test, "spondee_a")))
	transducer = StringName(String(plan.get("transducer", "phones")))
	sim.transducer = transducer
	if plan.has("tones"):
		tone_results = plan["tones"]
	_load_items()


func _load_items() -> void:
	_items.clear()
	var all := SpeechMaterial.items(list_id)
	var want: Array = plan.get("words", [])
	var drop: Array = plan.get("exclude", [])
	for it: Dictionary in all:
		var id := String(it.get("id", ""))
		if not want.is_empty() and not want.has(id):
			continue
		if drop.has(id):
			continue
		_items.append(it)
	_queue.clear()
	_next = {}


## Start (or continue) testing one ear: the dial goes to the plan's level, else the ear's PTA
## rounded to 5 dB (the player adds the 15).
func begin(e: String, coach: bool = false) -> void:
	ear = e
	coached[e] = coach
	awaiting_score = false
	current = {}
	var p := pta_for(e)
	db = SpeechRules.clamp_db(int(plan.get("level", SpeechRules.snap5(p) if not is_nan(p) else 40)))
	mask_on = bool(plan.get("mask_on", false))
	_apply_condition()
	if _next.is_empty():
		_pick_next()


# ---------------------------------------------------------------- PTA and masking

## The ear's PTA from the tone results (best air, masked where measured). NAN when missing.
func pta_for(e: String) -> float:
	return SpeechRules.pta_for_speech(_tone_thresholds(e))


func _tone_thresholds(e: String) -> Dictionary:
	if tone_results.is_empty():
		return {}
	return ClinicRules.best_thresholds(tone_results, e, false)


func recommended_start(e: String = "") -> int:
	return SpeechRules.srt_start(pta_for(ear if e == "" else e))


func mask_level() -> int:
	return SpeechRules.speech_mask_level(db) if mask_on else -1


func masking_needed_here(level: int = -999) -> bool:
	var lv := db if level == -999 else level
	return SpeechRules.speech_masking_needed(lv, SpeechRules.nontest_best_threshold(tone_results, ear), transducer)


func masker_ear() -> String:
	return "left" if ear == "right" else "right"


func _apply_condition() -> void:
	sim.transducer = transducer
	sim.mask_db = mask_level()


# ---------------------------------------------------------------- controls

func step_level(direction: int) -> bool:
	return set_level(db + SpeechRules.LEVEL_STEP_DB * signi(direction))


func set_level(level: int) -> bool:
	var v := SpeechRules.clamp_db(level)
	if v == db:
		return false
	db = v
	_apply_condition()
	return true


func set_mask(on: bool) -> bool:
	if on == mask_on:
		return false
	mask_on = on
	_apply_condition()
	return true


func toggle_mask() -> bool:
	return set_mask(not mask_on)


## The word the next present() will use ({} when the list is empty).
func next_item() -> Dictionary:
	if _next.is_empty():
		_pick_next()
	return _next


func _pick_next() -> void:
	if _items.is_empty():
		_next = {}
		return
	if _queue.is_empty():
		_queue = _items.duplicate()
		# Fisher-Yates with the session's seeded rng (reproducible in autoplay)
		for i in range(_queue.size() - 1, 0, -1):
			var j := sim.rng.randi_range(0, i)
			var tmp: Dictionary = _queue[i]
			_queue[i] = _queue[j]
			_queue[j] = tmp
		if _queue.size() > 1 and String(_queue[0].get("id", "")) == _last_item_id:
			_queue.push_back(_queue.pop_front())
	_next = _queue.pop_front()


func trials_for(e: String = "", t: StringName = &"") -> Array:
	var tt := test if t == &"" else t
	return ((trials[tt] as Dictionary)[ear if e == "" else e] as Array)


func is_done(e: String = "", t: StringName = &"") -> bool:
	return (sheets[test if t == &"" else t] as Dictionary).has(ear if e == "" else e)


## Present the next word at the dial level. Returns the trial ({} when refused: a word is
## waiting for its score, the ear is done, or there are no words). The answer is in trial.answer.
func present() -> Dictionary:
	if awaiting_score:
		_observe_once("score_first", &"score_first", {})
		return {}
	if is_done() or next_item().is_empty():
		return {}
	var it := next_item()
	var list := trials_for()
	_apply_condition()
	if scoring:
		if list.is_empty():
			_check_start()
		else:
			_check_step(list[list.size() - 1])
	var answer := sim.respond_srt(ear, db, it, _items)
	var trial := {
		"n": list.size() + 1, "db": db, "item_id": String(it.get("id", "")), "word": String(it.get("text", "")),
		"said": String(answer["text"]), "kind": answer["kind"], "correct": bool(answer["correct"]),
		"scored": null, "mask_db": mask_level(), "by_hoot": not scoring, "delay_s": float(answer["delay_s"]),
		"heard_by": answer["heard_by"],
	}
	list.append(trial)
	current = trial
	awaiting_score = true
	_last_item_id = trial["item_id"]
	_next = {}
	if scoring:
		presentations += 1
	else:
		hoot_presentations += 1
	if trial["kind"] == &"half":
		_observe_once("half_word", &"half_word", {"db": db})
	if trial["heard_by"] == &"cross":
		reaction.emit(&"cross_heard", {"ear": ear, "via": "speech", "db": db, "masked": mask_on})
		_observe_once("cross:" + ear, &"cross_heard_speech", {"db": db})
	elif not mask_on and masking_needed_here():
		_observe_once("maskneed:" + ear, &"speech_mask_needed", {"db": db})
	_check_marathon()
	return trial


## Score the waiting word: correct = the player says the patient repeated the whole word.
func score(correct: bool) -> Dictionary:
	if not awaiting_score or current.is_empty():
		return {}
	current["scored"] = correct
	awaiting_score = false
	if scoring:
		if correct == bool(current["correct"]):
			_clean(&"speech_textbook")
		else:
			_error(&"misscored", {"db": int(current["db"]), "said": current["said"], "said_kind": current["kind"], "scored": correct}, true, MISSCORED_TIPS.get(current["kind"], ""))
	return current


## The SRT the scored words support now (-1 = not bracketed yet).
func candidate(e: String = "", t: StringName = &"") -> int:
	return SpeechRules.srt_candidate(_scored(trials_for(e, t)))


static func _scored(list: Array) -> Array:
	var out: Array = []
	for tr: Dictionary in list:
		if tr["scored"] != null:
			out.append({"db": int(tr["db"]), "correct": bool(tr["scored"])})
	return out


## Store the dial level as this ear's SRT. Returns the sheet ({} when refused).
func store() -> Dictionary:
	if awaiting_score or is_done() or trials_for().is_empty():
		return {}
	var cand := candidate()
	var errs: Array[StringName] = []
	if scoring:
		if cand == SpeechRules.NO_SRT:
			errs.append(&"srt_store_no_bracket")
			_error(&"srt_store_no_bracket", {"db": db}, true)
		elif db != cand:
			errs.append(&"srt_store_wrong_level")
			_error(&"srt_store_wrong_level", {"db": db, "candidate": cand}, true)
		else:
			_clean(&"srt_store_ok")
	var sheet := _make_sheet(cand)
	(sheets[test] as Dictionary)[ear] = sheet
	stored.emit(ear, test, sheet)
	_observe(&"srt_stored", {"db": db, "agreement": sheet["agreement"], "diff": sheet["diff"], "pta": sheet["pta"]})
	if StringName(sheet["agreement"]) != &"":
		var tip := String(AGREEMENT_TIPS.get(StringName(sheet["agreement"]), "")).replace("{diff}", str(absi(int(sheet["diff"]))))
		_emit_kind(&"srt_agreement", {"db": db, "agreement": sheet["agreement"], "diff": sheet["diff"], "pta": sheet["pta"]}, _say(tip))
	if scoring and not bool(sheet["by_hoot"]) and GOLF_POINTS.has(StringName(sheet["golf"])):
		var g := StringName(sheet["golf"])
		if g in [&"birdie", &"eagle", &"albatross"]:
			_observe(g, {"db": db})
		points += int(GOLF_POINTS[g])
	return sheet


func _make_sheet(cand: int) -> Dictionary:
	var list := trials_for()
	var truth := sim.true_srt(ear)
	var p := pta_for(ear)
	var player_words := 0
	for tr: Dictionary in list:
		if not bool(tr["by_hoot"]):
			player_words += 1
	var start := int((list[0] as Dictionary)["db"])
	var par := SpeechRules.srt_par(start, truth)
	var errs: Array = _meas_errors.get(_mkey(), [])
	var clean := errs.is_empty()
	var by_hoot := not scoring
	var half := 0
	for tr: Dictionary in list:
		if tr["kind"] == &"half":
			half += 1
	var err := absf(float(db - truth))
	return {
		"ear": ear, "test": String(test), "list_id": list_id,
		"stored_db": db, "true_db": truth, "error_db": err,
		"accuracy": ClinicRules.accuracy_for_error(err),
		"candidate_db": cand,
		"pta": p, "pta_method": SpeechRules.pta_method(_tone_thresholds(ear)),
		"agreement": SpeechRules.agreement(db, p), "diff": SpeechRules.srt_pta_diff(db, p),
		"start_db": start, "recommended_start": SpeechRules.srt_start(p),
		"strokes": player_words, "words": list.size(), "par": par,
		"golf": ClinicRules.fair_golf(player_words, par, clean) if not by_hoot else &"hoot",
		"golf_raw": player_words - par,
		"clean": clean, "errors": errs.duplicate(),
		"trials": list.duplicate(true),
		"masked": mask_on, "mask_db": mask_level(), "transducer": String(transducer),
		"by_hoot": by_hoot, "coached": bool(coached.get(ear, false)),
		"half_words": half,
	}


# ---------------------------------------------------------------- the coach

## The textbook next action from what the player can see (scores, the trail, the PTA):
## {action: &"score_correct" | &"score_missed" | &"louder" | &"softer" | &"mask_toggle" | &"present" |
##  &"store" | &"none", target_db}. Hoot's turn and the coach both follow it.
func recommended_action() -> Dictionary:
	if is_done() or next_item().is_empty():
		return {"action": &"none", "target_db": db}
	if awaiting_score:
		return {"action": &"score_correct" if bool(current.get("correct", false)) else &"score_missed", "target_db": db}
	var target := textbook_target()
	var cand := candidate()
	if cand != SpeechRules.NO_SRT and target == cand:
		if db == cand:
			return {"action": &"store", "target_db": cand}
	if db < target:
		return {"action": &"louder", "target_db": target}
	if db > target:
		return {"action": &"softer", "target_db": target}
	if masking_needed_here() and not mask_on:
		return {"action": &"mask_toggle", "target_db": target}
	return {"action": &"present", "target_db": target}


## Where the next word (or the store) should be: the start level, the textbook step after the
## last scored word, or the SRT once it is bracketed.
func textbook_target() -> int:
	var list := trials_for()
	if list.is_empty():
		return recommended_start()
	var cand := candidate()
	if cand != SpeechRules.NO_SRT:
		return cand
	var last: Dictionary = list[list.size() - 1]
	var ok: bool = last["scored"] if last["scored"] != null else bool(last["correct"])
	return SpeechRules.srt_next_level(int(last["db"]), ok)


# ---------------------------------------------------------------- state and results

## The screen's view (§9.4).
func get_state() -> Dictionary:
	var list := trials_for()
	var trail: Array = []
	for tr: Dictionary in list:
		trail.append({"db": tr["db"], "scored": tr["scored"], "kind": tr["kind"], "by_hoot": tr["by_hoot"]})
	var p := pta_for(ear)
	var nxt := next_item()
	var sheet: Dictionary = (sheets[test] as Dictionary).get(ear, {})
	return {
		"test": test, "ear": ear, "db": db, "min_db": SpeechRules.MIN_DB, "max_db": SpeechRules.MAX_DB,
		"list_id": list_id, "list_title": SpeechMaterial.title(list_id),
		"next_word": String(nxt.get("text", "")), "words_left": _queue.size() + (0 if nxt.is_empty() else 1),
		"pta": p, "pta_right": pta_for("right"), "pta_left": pta_for("left"),
		"recommended_start": SpeechRules.srt_start(p),
		"candidate_db": candidate(),
		"trail": trail, "strokes": list.size(),
		"awaiting_score": awaiting_score,
		"current": {} if current.is_empty() else {"word": current["word"], "said": current["said"], "db": current["db"], "scored": current["scored"]},
		"mask_on": mask_on, "mask_db": mask_level(), "mask_ear": masker_ear(),
		"masking_needed": masking_needed_here(),
		"transducer": transducer,
		"done": is_done(), "stored_db": int(sheet.get("stored_db", -1)),
		"agreement": sheet.get("agreement", &""), "diff": int(sheet.get("diff", 0)),
		"combo": combo, "multiplier": ClinicRules.combo_multiplier(combo), "points": points,
		"presentations": presentations, "scoring": scoring,
	}


## Speech results for the visit (§9.5).
func build_results() -> Dictionary:
	var out := {}
	var acc := 0.0
	var n := 0
	var strokes := 0
	var par := 0
	var tests_done: Array[String] = []
	for t: StringName in SpeechRules.TESTS:
		var per: Dictionary = {}
		for e: String in (sheets[t] as Dictionary):
			var sh: Dictionary = (sheets[t] as Dictionary)[e]
			per[e] = sh.duplicate(true)
			if not tests_done.has(String(t)):
				tests_done.append(String(t))
			if bool(sh.get("by_hoot", false)):
				continue
			acc += float(sh["accuracy"])
			n += 1
			strokes += int(sh["strokes"])
			par += int(sh["par"])
		out[String(t)] = per
	var accuracy := acc / n if n > 0 else 0.0
	var tech := float(clean_checks) / checks if checks > 0 else 0.0
	var eff := clampf(float(par) / strokes, 0.0, 1.0) if strokes > 0 else 0.0
	var w := ClinicRules.SCORE_WEIGHTS
	var part: float = w["accuracy"] + w["technique"] + w["efficiency"]
	var score: float = 100.0 * (w["accuracy"] * accuracy + w["technique"] * tech + w["efficiency"] * eff) / part
	out["pta"] = {"right": pta_for("right"), "left": pta_for("left")}
	out["tests"] = tests_done
	out["scored_sheets"] = n
	out["presentations"] = presentations
	out["hoot_presentations"] = hoot_presentations
	out["max_combo"] = max_combo
	out["points"] = points
	out["technique_errors"] = errors.duplicate(true)
	out["checks"] = checks
	out["clean_checks"] = clean_checks
	out["accuracy"] = accuracy
	out["technique"] = tech
	out["efficiency"] = eff
	out["score"] = score
	out["grade"] = ClinicRules.grade_for_score(score)
	return out


## The visit's results: the tone results (§5.1) with "speech" added and accuracy / technique /
## efficiency / score / grade recomputed over the scored tone stamps AND the scored speech sheets
## (an SRT weighs SHEET_WEIGHT tone stamps). The tone-only numbers stay under "tone_scores".
static func merge_results(tones: Dictionary, speech: Dictionary) -> Dictionary:
	var out := tones.duplicate(true)
	out["speech"] = speech.duplicate(true)
	var nt := float(scored_tone_stamps(tones))
	var ns := float(int(speech.get("scored_sheets", 0))) * SHEET_WEIGHT
	out["tone_scores"] = {
		"accuracy": float(tones.get("accuracy", 0.0)), "technique": float(tones.get("technique", 0.0)),
		"efficiency": float(tones.get("efficiency", 0.0)), "stamps": int(nt),
	}
	if nt + ns <= 0.0:
		return out
	for k: String in ["accuracy", "technique", "efficiency"]:
		out[k] = (float(tones.get(k, 0.0)) * nt + float(speech.get(k, 0.0)) * ns) / (nt + ns)
	var w := ClinicRules.SCORE_WEIGHTS
	var part: float = w["accuracy"] + w["technique"] + w["efficiency"]
	var score: float = 100.0 * (w["accuracy"] * float(out["accuracy"]) + w["technique"] * float(out["technique"]) + w["efficiency"] * float(out["efficiency"])) / part
	out["score"] = score
	out["grade"] = ClinicRules.grade_for_score(score)
	return out


## Tone results (§5.1 shape, air only, every stamp by Hoot) straight from a profile's thresholds:
## for demo scenes and tests that start on the SPEECH screen without running the AudiOtron.
static func tone_results_from(p: PatientProfile) -> Dictionary:
	var ears := {}
	for e: String in ClinicRules.EARS:
		var freqs := {}
		for f: int in ClinicRules.AC_FREQS:
			var t := p.get_threshold(e, f)
			freqs[f] = {"ear": e, "freq": f, "stored_db": t, "true_db": t, "error_db": 0.0, "by_hoot": true, "test": "ac"}
		ears[e] = {"freqs": freqs, "complete": true, "pta": ClinicRules.pta(p.get_thresholds(e))}
	return {"patient_id": p.id, "patient_name": p.display_name, "ears": ears, "accuracy": 0.0, "technique": 0.0, "efficiency": 0.0}


## Tone stamps the player made (not Hoot's) over every sheet of both ears.
static func scored_tone_stamps(tones: Dictionary) -> int:
	var n := 0
	var ears: Dictionary = tones.get("ears", {})
	for e: Variant in ears:
		var er: Dictionary = ears[e]
		for key: String in ["freqs", "bc", "bc_masked", "ac_masked"]:
			var sh: Dictionary = er.get(key, {})
			for f: Variant in sh:
				if not bool((sh[f] as Dictionary).get("by_hoot", false)):
					n += 1
	return n


# ---------------------------------------------------------------- technique internals

func _mkey() -> String:
	return "%s:%s" % [test, ear]


func _check_start() -> void:
	var p := pta_for(ear)
	if SpeechRules.srt_start_ok(db, p):
		_clean(&"srt_good_start")
	else:
		_error(&"srt_start", {"db": db, "expected": SpeechRules.srt_start(p), "pta": p}, false)


func _check_step(prev: Dictionary) -> void:
	var ok: bool = prev["scored"] if prev["scored"] != null else bool(prev["correct"])
	var v := SpeechRules.srt_step_verdict(int(prev["db"]), ok, db)
	if v == &"wrong":
		_error(&"srt_wrong_step", {"db": db, "expected": SpeechRules.srt_next_level(int(prev["db"]), ok), "got": db, "prev_db": prev["db"], "prev_correct": ok}, false)
	else:
		_clean(&"speech_textbook")


func _check_marathon() -> void:
	var list := trials_for()
	if list.is_empty() or not scoring:
		return
	var par := SpeechRules.srt_par(int((list[0] as Dictionary)["db"]), sim.true_srt(ear))
	if float(list.size()) > MARATHON_FACTOR * par and not _once.has("marathon:" + _mkey()):
		_once["marathon:" + _mkey()] = true
		_error(&"speech_marathon", {"words": list.size(), "par": par}, false)


func _clean(kind: StringName) -> void:
	if not scoring:
		technique.emit(kind, _data({"combo": 0, "multiplier": 1, "points": 0, "auto": true}))
		return
	checks += 1
	clean_checks += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	var mult := ClinicRules.combo_multiplier(combo)
	var gained: int = POINTS.get(kind, 0) * mult
	points += gained
	combo_changed.emit(combo, mult)
	technique.emit(kind, _data({"combo": combo, "multiplier": mult, "points": gained}))


## An error: always a check (a failed one), breaks the combo, lowers technique.
## counts_as_check is kept for symmetry with AudiometrySession: every speech error is one check.
func _error(kind: StringName, data: Dictionary, _counts_as_check: bool, message: String = "") -> void:
	var d := _data(data)
	d["message"] = _say(message) if message != "" else tip_text(kind)
	if not scoring:
		d["auto"] = true
		technique.emit(kind, d)
		return
	checks += 1
	var mk := _mkey()
	var list: Array = _meas_errors.get(mk, [])
	list.append(kind)
	_meas_errors[mk] = list
	errors.append({"kind": String(kind), "ear": ear, "freq": -1, "test": String(test), "db": db, "message": d["message"]})
	if combo > 0:
		combo = 0
		combo_changed.emit(0, 1)
	technique.emit(kind, d)


func _observe(kind: StringName, data: Dictionary) -> void:
	_emit_kind(kind, data, tip_text(kind))


func _observe_once(key: String, kind: StringName, data: Dictionary) -> void:
	if _once.has(key):
		return
	_once[key] = true
	_observe(kind, data)


func _emit_kind(kind: StringName, data: Dictionary, message: String) -> void:
	var d := _data(data)
	d["message"] = message
	if not scoring:
		d["auto"] = true
	technique.emit(kind, d)


func _data(extra: Dictionary) -> Dictionary:
	var d := {"ear": ear, "freq": -1, "test": String(test), "db": db}
	d.merge(extra, true)
	return d


func tip_text(kind: StringName) -> String:
	return _say(String(TIPS.get(kind, "")))


func _say(t: String) -> String:
	return patient.say(t) if patient != null else PatientProfile.pronouns(t, "he")
