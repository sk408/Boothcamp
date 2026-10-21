class_name SpeechSession
extends RefCounted
## SpeechSession: pure logic of one patient's speech tests, both ears (CONTRACTS.md §9.4).
## No nodes and no clock: the SPEECH screen calls present(), score(), store() and the controls, and
## handles all timing (the word "plays", then the answer appears). It holds the speech simulator,
## the technique checker and the golf / combo / points scoring. Results shape: CONTRACTS.md §9.5.
##
## The SRT (speech recognition threshold) dance it teaches (SpeechRules has the numbers, docs/SPEECH.md §3):
##   - familiarise first; start at the PTA (rounded to 5) + 15 (up to + 40 is fine; or below it and
##     coming up, once the plan says a non-organic loss is suspected: low_start_ok)
##   - repeated it -> down 10 (5 tolerated); missed it -> up 5; another word at the same level is
##     fine, up to SRT_MAX_WORDS_PER_LEVEL words there
##   - score what the patient SAID: half a word, a different word or silence are all misses
##   - SRT = the softest level with 2+ right and half or more, the level 5 below scoring under half
##   - compare with the PTA: within 6 dB good, 7-12 fair, 13+ poor. An SRT much better than the PTA:
##     think non-organic, recheck; a worse one: instructions, language or word recognition
## Golf: each SRT is a hole; par = the textbook dance from the first word's level (srt_par).

signal technique(kind: StringName, data: Dictionary)
signal combo_changed(n: int, multiplier: int)
signal reaction(kind: StringName, data: Dictionary)
## One measurement was stored. sheet: CONTRACTS.md §9.5.
signal stored(ear: String, test: StringName, sheet: Dictionary)

## Hoot's one-liners per technique kind (original wording, 18 words max). {he} {his} {him} tokens.
const TIPS: Dictionary[StringName, String] = {
	&"srt_start": "Start at {his} PTA plus 15, plus 40 at most: easy words first, then work down.",
	&"srt_wrong_step": "Got it: down 10. Missed: up 5. Another word here is fine too!",
	&"srt_store_no_bracket": "Not bracketed yet! 5 dB below, {he} must get fewer than half right.",
	&"srt_store_wrong_level": "SRT: the softest level with two right and half or more. Check the trail!",
	&"misscored": "Score what {he} SAID. Half a word, a different word, or silence: all misses.",
	&"speech_marathon": "Long word lists tire patients out. Bracket quickly and store!",
	&"half_word": "Half a word is a miss. Lots of half-words can be a sign of a non-organic loss.",
	&"cross_heard_speech": "Loud speech can cross the skull to the other ear. Mask the other ear!",
	&"speech_mask_needed": "This loud, speech can cross to the other ear. Speech noise on: press M.",
	&"score_first": "Score that word first: did {he} say the whole word?",
	# a clean kind: the first step after a first word below the PTA, when it goes up, once the plan
	# allows that start (low_start_ok; clinical review S2: the praise waits for the ascent)
	&"srt_low_start": "Starting below {his} beeps and coming up: smart when answers look exaggerated.",
}
## misscored, by what the patient actually said.
const MISSCORED_TIPS: Dictionary[StringName, String] = {
	&"half": "Half a word is a miss. Only the whole word counts!",
	&"wrong": "That wasn't the word! A different word is a miss.",
	&"silence": "Silence is a miss. Score it as missed.",
	&"correct": "{He} said the whole word! Score it as correct.",
}
## Hoot's line on the PTA/SRT agreement after a store, by agreement and, when they disagree, by
## direction (agreement_tip()). {diff} = dB apart; {good} / {fair} = SpeechRules.AGREE_GOOD_DB / AGREE_FAIR_DB.
const AGREEMENT_TIPS: Dictionary[StringName, String] = {
	&"good": "A reliable SRT: within {good} dB of the PTA. The audiogram checks out!",
	&"fair_better": "SRT {diff} dB better than the PTA: fair agreement. Recheck the tones near 500 to 2000 Hz.",
	&"fair_worse": "SRT {diff} dB worse than the PTA: fair agreement. Check {he} understood, then recheck the tones.",
	&"poor_better": "SRT {diff} dB better than the PTA: POOR agreement! Think non-organic: re-instruct and recheck.",
	&"poor_worse": "SRT {diff} dB worse than the PTA: POOR agreement! Check instructions, language and word recognition.",
}
## Positive kinds and the points they are worth (times the combo multiplier).
const POINTS: Dictionary[StringName, int] = {&"speech_textbook": 10, &"srt_good_start": 10, &"srt_low_start": 10, &"srt_store_ok": 50}
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
## Speech noise in the other ear (it tracks the level: level - 20, plus the other ear's air-bone gap).
var mask_on: bool = false
var list_id: String = "spondee_a"
## The AudiOtron's results (§5.1) this visit: the PTA and the masking rule come from them.
var tone_results: Dictionary = {}
var coached: Dictionary = {"right": false, "left": false}
## false while Hoot runs the test (his words and stores are not scored).
var scoring: bool = true

# (Days 4-5) the test modes (CONTRACTS.md §9.10.4). test "srt" has no mode, and every seam below
# starts with `if mode != null`, so a Day 3 session never reaches the new code.
## The WRS or SIN test (SpeechTestMode.make(), by path; a fresh one every configure()). null for the SRT.
var mode: SpeechTestMode = null
## The plan's test is wrs or sin but its mode script is missing: present() is refused.
var mode_missing := false
## The sheet slot being measured: the ear, or a party slot ("both", "aided_omni", "aided_directional").
var slot := "right"
## A running number for the lists and sentences of the visit (next_seq()).
var seq := 0
## The list ids used so far, in play order (the modes append them; D25).
var used_lists: Array[String] = []

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
var _low_start: Dictionary = {}      ## "test:ear" -> true: a low first word waits for its first step
var _once: Dictionary = {}


func _init(p: PatientProfile, seed_value: int = 0) -> void:
	patient = p
	sim = SpeechSim.new(p, seed_value)
	for t: StringName in SpeechRules.TESTS:
		trials[t] = {"right": [], "left": []}
		sheets[t] = {}


## Plan keys (all optional, §9.4): test, list, words (item ids to use), exclude (ids to drop),
## tones (§5.1 results), transducer, level (the dial's starting level), low_start_ok (bool, default
## false: a first word at least SRT_LOW_START_BELOW_PTA_DB below the PTA is a clean start, not an
## srt_start error, and the first step after it, when it goes up, is the clean &"srt_low_start"; the
## level sets it once suspicion of a non-organic loss is on screen).
func configure(p: Dictionary) -> void:
	plan = p.duplicate(true)
	test = StringName(String(plan.get("test", "srt")))
	list_id = String(plan.get("list", DEFAULT_LISTS.get(test, "spondee_a")))
	transducer = StringName(String(plan.get("transducer", "phones")))
	sim.transducer = transducer
	if plan.has("tones"):
		tone_results = plan["tones"]
	# (Days 4-5) C2: the old mode is dropped; a mode owns its list, so the base items stay empty
	mode = SpeechTestMode.make(self, test)
	mode_missing = test != &"srt" and mode == null
	if mode == null and not mode_missing:
		_load_items()
	else:
		_items.clear()
		_queue.clear()
		_next = {}
	if mode != null:
		mode.configure(plan)


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
## (Days 4-5) With a mode: the slot is mode.slot_for(e), the dial mode.start_level(), and the mode
## picks the first item (mode.begin()).
func begin(e: String, coach: bool = false) -> void:
	ear = e
	slot = mode.slot_for(e) if mode != null else e
	ensure_slot(slot)
	coached[e] = coach
	coached[slot] = coach
	awaiting_score = false
	current = {}
	if mode != null:
		db = SpeechRules.clamp_db(mode.start_level())
	else:
		var p := pta_for(e)
		db = SpeechRules.clamp_db(int(plan.get("level", SpeechRules.snap5(p) if not is_nan(p) else 40)))
	mask_on = bool(plan.get("mask_on", false))
	_apply_condition()
	if mode != null:
		mode.begin(e, coach)
	elif _next.is_empty():
		_pick_next()


## (Days 4-5) An empty trial list for slot `s` in every test (Day 3's "right" / "left" exist already).
func ensure_slot(s: String) -> void:
	for t: StringName in SpeechRules.TESTS:
		var per: Dictionary = trials[t]
		if not per.has(s):
			per[s] = []


# ---------------------------------------------------------------- PTA and masking

## The ear's PTA from the tone results (best air, masked where measured). NAN when missing.
## (Days 4-5) "both": the lower (better) of the two ears' PTAs.
func pta_for(e: String) -> float:
	if e == "both":
		var r := pta_for("right")
		var l := pta_for("left")
		if is_nan(r):
			return l
		return r if is_nan(l) else minf(r, l)
	return SpeechRules.pta_for_speech(_tone_thresholds(e))


func _tone_thresholds(e: String) -> Dictionary:
	if tone_results.is_empty():
		return {}
	return ClinicRules.best_thresholds(tone_results, e, false)


## (Days 4-5) The ear's measured thresholds (best air, masked where measured; §5.1); "both" takes the
## lower of the two ears at each frequency.
func measured_thresholds(e: String) -> Dictionary:
	if e != "both":
		return _tone_thresholds(e)
	var out := _tone_thresholds("right")
	var l := _tone_thresholds("left")
	for f: Variant in l:
		if not out.has(f) or float(l[f]) < float(out[f]):
			out[f] = l[f]
	return out


## (Days 4-5) The non-test ear's lowest best bone (D17: masked bone, else bone, else air). NAN when
## nothing was measured there, or for "both" (no ear is free).
func nontest_best_bone(e: String) -> float:
	return NAN if e == "both" else SpeechRules.nontest_best_bone(tone_results, e)


## (Days 4-5) The test ear's lowest best bone (D17; "both": over both ears). NAN when none.
func test_best_bone(e: String) -> float:
	var best := INF
	for side: String in (["right", "left"] if e == "both" else [e]):
		var t := SpeechRules.ear_best_bone(tone_results, side)
		for f: int in t:
			best = minf(best, float(t[f]))
	return best if best != INF else NAN


func recommended_start(e: String = "") -> int:
	if mode != null and e == "":
		return mode.recommended_start()
	return SpeechRules.srt_start(pta_for(ear if e == "" else e))


## Speech noise in the other ear (dB EM; -1 = off): level - 20 plus that ear's largest air-bone gap
## from the tone results (0 without bone results: the air-only stand-in). (Days 4-5) A mode's rule.
func mask_level() -> int:
	if mode != null:
		return mode.mask_level(db) if mask_on else -1
	return SpeechRules.speech_mask_level(db, SpeechRules.nontest_largest_abg(tone_results, ear)) if mask_on else -1


func masking_needed_here(level: int = -999) -> bool:
	var lv := db if level == -999 else level
	if mode != null:
		return mode.masking_needed(lv)
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
	if mode != null and not mode.can_set_level():
		mode.on_level_refused()
		return false
	var v := SpeechRules.clamp_db(level)
	if v == db:
		return false
	db = v
	_apply_condition()
	return true


func set_mask(on: bool) -> bool:
	if mode != null and not mode.can_mask():
		mode.on_mask_refused()
		return false
	if on == mask_on:
		return false
	mask_on = on
	_apply_condition()
	return true


func toggle_mask() -> bool:
	return set_mask(not mask_on)


## The word the next present() will use ({} when the list is empty).
func next_item() -> Dictionary:
	if mode != null:
		return mode.next_item()
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


## (Days 4-5) With a mode and no arguments: the mode's list (mode.current_trials()).
func trials_for(e: String = "", t: StringName = &"") -> Array:
	if mode != null and e == "" and t == &"":
		return mode.current_trials()
	var tt := test if t == &"" else t
	return ((trials[tt] as Dictionary)[ear if e == "" else e] as Array)


func is_done(e: String = "", t: StringName = &"") -> bool:
	if mode != null and e == "" and t == &"":
		return mode.is_done()
	return (sheets[test if t == &"" else t] as Dictionary).has(ear if e == "" else e)


## Present the next word at the dial level. Returns the trial ({} when refused: a word is
## waiting for its score, the ear is done, or there are no words). The answer is in trial.answer.
func present() -> Dictionary:
	if mode_missing:
		return {}
	if mode != null:
		return mode.present()
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
	if mode != null:
		return mode.score(correct)
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
	if mode != null and e == "" and t == &"":
		return mode.candidate()
	return SpeechRules.srt_candidate(_scored(trials_for(e, t)))


static func _scored(list: Array) -> Array:
	var out: Array = []
	for tr: Dictionary in list:
		if tr["scored"] != null:
			out.append({"db": int(tr["db"]), "correct": bool(tr["scored"])})
	return out


## Store the dial level as this ear's SRT. Returns the sheet ({} when refused).
func store() -> Dictionary:
	if mode != null:
		return mode.store()
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
		var tip := agreement_tip(StringName(sheet["agreement"]), int(sheet["diff"]))
		_emit_kind(&"srt_agreement", {"db": db, "agreement": sheet["agreement"], "diff": sheet["diff"], "pta": sheet["pta"]}, tip)
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
		# stored at the bracketed SRT (the UI and story praise only these)
		"bracketed": cand != SpeechRules.NO_SRT and db == cand,
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
	if mode != null:
		return mode.recommended_action()
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
	if mode != null:
		return mode.textbook_target()
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

## The screen's view (§9.4). (Days 4-5) Also "slot", "mode" and, with a mode, its own view under
## the test's name (get_state()["wrs"]); the mode's trials may leave out SRT keys.
func get_state() -> Dictionary:
	var list := trials_for()
	var trail: Array = []
	for tr: Dictionary in list:
		if mode != null:
			trail.append({"db": tr.get("db", db), "scored": tr.get("scored"), "kind": tr.get("kind", &""), "by_hoot": tr.get("by_hoot", false)})
		else:
			trail.append({"db": tr["db"], "scored": tr["scored"], "kind": tr["kind"], "by_hoot": tr["by_hoot"]})
	var p := pta_for(ear)
	var nxt := next_item()
	var sheet: Dictionary = (sheets[test] as Dictionary).get(slot if mode != null else ear, {})
	var cur := {}
	if not current.is_empty():
		if mode != null:
			cur = {"word": current.get("word", ""), "said": current.get("said", ""), "db": current.get("db", db), "scored": current.get("scored")}
		else:
			cur = {"word": current["word"], "said": current["said"], "db": current["db"], "scored": current["scored"]}
	var out := {
		"test": test, "ear": ear, "db": db, "min_db": SpeechRules.MIN_DB, "max_db": SpeechRules.MAX_DB,
		"list_id": list_id, "list_title": list_id if mode_missing else SpeechMaterial.title(list_id),
		"next_word": String(nxt.get("text", "")),
		"words_left": mode.words_left() if mode != null else _queue.size() + (0 if nxt.is_empty() else 1),
		"pta": p, "pta_right": pta_for("right"), "pta_left": pta_for("left"),
		"recommended_start": mode.recommended_start() if mode != null else SpeechRules.srt_start(p),
		"candidate_db": candidate(),
		"trail": trail, "strokes": list.size(),
		"awaiting_score": awaiting_score,
		"current": cur,
		"mask_on": mask_on, "mask_db": mask_level(), "mask_ear": masker_ear(),
		"masking_needed": masking_needed_here(),
		"transducer": transducer,
		"done": is_done(), "stored_db": int(sheet.get("stored_db", -1)),
		"agreement": sheet.get("agreement", &""), "diff": int(sheet.get("diff", 0)),
		"combo": combo, "multiplier": ClinicRules.combo_multiplier(combo), "points": points,
		"presentations": presentations, "scoring": scoring,
	}
	out["slot"] = slot
	out["mode"] = String(test) if mode != null else ""
	if mode != null:
		out[String(test)] = mode.state()
	return out


## Speech results for the visit (§9.5). (Days 4-5) A sheet weighs its "units" (counted player lists;
## an SRT sheet 1, Hoot's 0), and each test with sheets adds its summary (SpeechTestMode.summarize()).
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
			var by_hoot := bool(sh.get("by_hoot", false))
			var units := int(sh.get("units", 0 if by_hoot else 1))
			if units > 0:
				acc += float(sh.get("accuracy", 0.0)) * units
				n += units
			if by_hoot:
				continue
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
	# (Days 4-5) C20: a fresh, throwaway mode per test reads the sheets for wrs_summary / sin_summary
	for t: StringName in [&"wrs", &"sin"]:
		if not (sheets[t] as Dictionary).is_empty():
			var m := SpeechTestMode.make(self, t)
			if m != null:
				m.summarize(out)
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

## (Days 4-5) The measurement's key (slips, once-per-measurement checks, Hoot's turn): "<test>:<ear>",
## or the mode's (per list for wrs / sin).
func measure_key() -> String:
	if mode != null:
		return mode.measure_key()
	return "%s:%s" % [test, ear]


func _mkey() -> String:
	return measure_key()


## The slips (error kinds) on this ear's measurement so far: what its sheet's "errors" will hold.
func slips() -> Array:
	return (_meas_errors.get(_mkey(), []) as Array).duplicate()


func _check_start() -> void:
	var p := pta_for(ear)
	if SpeechRules.srt_start_ok(db, p):
		_clean(&"srt_good_start")
	elif bool(plan.get("low_start_ok", false)) and SpeechRules.srt_start_low(db, p):
		# an ascending start: clean now, Hoot's praise once the dial really comes up (_check_step)
		_clean(&"srt_good_start")
		_low_start[_mkey()] = true
	else:
		_error(&"srt_start", {"db": db, "expected": SpeechRules.srt_start(p), "pta": p}, false)


func _check_step(prev: Dictionary) -> void:
	var ok: bool = prev["scored"] if prev["scored"] != null else bool(prev["correct"])
	var here := _words_at(int(prev["db"]))
	var v := SpeechRules.srt_step_verdict(int(prev["db"]), ok, db, here)
	# the first step after a low first word, when it goes up: the ascent earns the praise (a wrong step
	# spends it)
	var ascent := db > int(prev["db"]) and _low_start.has(_mkey())
	# a step down first is a descending search, not an ascending start: it spends the praise
	if ascent or db < int(prev["db"]):
		_low_start.erase(_mkey())
	if v == &"wrong":
		# staying put once a level has its words gets its own line (the plain tip says "another word here is fine")
		var full := db == int(prev["db"]) and here >= SpeechRules.SRT_MAX_WORDS_PER_LEVEL
		var msg := "%d words at one level is plenty. Got it: down 10. Missed: up 5." % SpeechRules.SRT_MAX_WORDS_PER_LEVEL if full else ""
		_error(&"srt_wrong_step", {"db": db, "expected": SpeechRules.srt_next_level(int(prev["db"]), ok), "got": db, "prev_db": prev["db"], "prev_correct": ok, "words_here": here}, false, msg)
	else:
		_clean(&"srt_low_start" if ascent else &"speech_textbook")


## Words already given at `level` in this ear (Hoot's too).
func _words_at(level: int) -> int:
	var n := 0
	for tr: Dictionary in trials_for():
		if int(tr["db"]) == level:
			n += 1
	return n


func _check_marathon() -> void:
	var list := trials_for()
	if list.is_empty() or not scoring:
		return
	var par := SpeechRules.srt_par(int((list[0] as Dictionary)["db"]), sim.true_srt(ear))
	if float(list.size()) > MARATHON_FACTOR * par and not _once.has("marathon:" + _mkey()):
		_once["marathon:" + _mkey()] = true
		_error(&"speech_marathon", {"words": list.size(), "par": par}, false)


func _clean(kind: StringName, extra: Dictionary = {}) -> void:
	if not scoring:
		technique.emit(kind, _with_tip(kind, _data(extra.merged({"combo": 0, "multiplier": 1, "points": 0, "auto": true}, true))))
		return
	checks += 1
	clean_checks += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	var mult := ClinicRules.combo_multiplier(combo)
	var base: int = POINTS.get(kind, 0)
	if mode != null and mode.points(kind) != -1:
		base = mode.points(kind)
	var gained: int = base * mult
	points += gained
	combo_changed.emit(combo, mult)
	technique.emit(kind, _with_tip(kind, _data(extra.merged({"combo": combo, "multiplier": mult, "points": gained}, true))))


## A clean kind with a Hoot line (srt_low_start) carries it as data.message, like the errors.
func _with_tip(kind: StringName, d: Dictionary) -> Dictionary:
	if TIPS.has(kind) or (mode != null and mode.tip(kind) != ""):
		d["message"] = tip_text(kind)
	return d


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
	var entry := {"kind": String(kind), "ear": ear, "freq": -1, "test": String(test), "db": db, "message": d["message"]}
	if mode != null:
		entry["slot"] = slot
	# a misscore keeps which way it went: the player's score and what was said (the paper names it)
	for k: String in ["scored", "said_kind"]:
		if data.has(k):
			entry[k] = data[k]
	errors.append(entry)
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
	if mode != null:
		d["slot"] = slot
	d.merge(extra, true)
	return d


## (Days 4-5) A mode's line (mode.tip()) comes first.
func tip_text(kind: StringName) -> String:
	if mode != null and mode.tip(kind) != "":
		return _say(mode.tip(kind))
	return _say(String(TIPS.get(kind, "")))


## Hoot's agreement line for a stored SRT: `diff` = SRT - PTA (negative = the SRT is better). Poor and
## fair lines depend on the direction; "" when there is no agreement yet.
func agreement_tip(agreement: StringName, diff: int) -> String:
	var key := agreement
	if agreement != &"good" and diff != 0:
		key = StringName("%s_%s" % [agreement, "better" if diff < 0 else "worse"])
	var t := String(AGREEMENT_TIPS.get(key, ""))
	t = t.replace("{diff}", str(absi(diff))).replace("{good}", str(SpeechRules.AGREE_GOOD_DB)).replace("{fair}", str(SpeechRules.AGREE_FAIR_DB))
	return _say(t)


func _say(t: String) -> String:
	return patient.say(t) if patient != null else PatientProfile.pronouns(t, "he")


# ---------------------------------------------------------------- (Days 4-5) for the test modes (C22, C23)

## A clean kind: a check, the combo, the points (mode.points() first) and its tip.
func clean(kind: StringName, extra: Dictionary = {}) -> void:
	_clean(kind, extra)


## A slip: a failed check that breaks the combo; `message` replaces the kind's tip.
func fail(kind: StringName, extra: Dictionary, message: String = "") -> void:
	_error(kind, extra, false, message)


## An observation (no check): the kind with its tip.
func observe(kind: StringName, extra: Dictionary) -> void:
	_observe(kind, extra)


## An observation once per `key` for the session.
func observe_once(key: String, kind: StringName, extra: Dictionary) -> void:
	_observe_once(key, kind, extra)


## A technique event with its own message (no check).
func emit_kind(kind: StringName, extra: Dictionary, message: String) -> void:
	_emit_kind(kind, extra, message)


## The event data every kind carries (ear, freq, test, db and, with a mode, slot) plus `extra`.
func data(extra: Dictionary = {}) -> Dictionary:
	return _data(extra)


## The next number of the visit's running count (lists, sentences).
func next_seq() -> int:
	seq += 1
	return seq


## `t` with the patient's pronouns.
func say(t: String) -> String:
	return _say(t)


## Hoot runs one whole measurement with no screen (D23): scoring off, begin(e), then the textbook
## move (recommended_action()) step by step until &"none" or a stored sheet. Base moves go through the
## session's own controls, mode-only ones through mode.do() (a refusal ends the run with a warning).
## The usual signals fire. Returns the stored sheet ({} = none, or the mode script is missing). It is
## Hoot's work: the sheet is by_hoot, with units 0.
func run_by_textbook(e: String, max_steps: int = 4000) -> Dictionary:
	if mode_missing:
		return {}
	var got: Array[Dictionary] = []
	var grab := func(_ear: String, _test: StringName, sheet: Dictionary) -> void: got.append(sheet)
	var was := scoring
	scoring = false
	stored.connect(grab)
	begin(e, false)
	var steps := 0
	while steps < max_steps:
		steps += 1
		var rec := recommended_action()
		var action := StringName(String(rec.get("action", "none")))
		if action == &"none":
			break
		var done := false
		match action:
			&"louder":
				done = step_level(1)
			&"softer":
				done = step_level(-1)
			&"mask_toggle":
				done = toggle_mask()
			&"present":
				done = not present().is_empty()
			&"score_correct":
				done = not score(true).is_empty()
			&"score_missed":
				done = not score(false).is_empty()
			&"store":
				done = not store().is_empty() or not got.is_empty()
			_:
				done = mode != null and not mode.do(action, rec).is_empty()
		if not got.is_empty():
			break
		if not done:
			push_warning("SpeechSession.run_by_textbook: %s refused" % action)
			break
	if steps >= max_steps and got.is_empty():
		push_warning("SpeechSession.run_by_textbook: no sheet after %d steps" % max_steps)
	stored.disconnect(grab)
	scoring = was
	return got[got.size() - 1] if not got.is_empty() else {}
