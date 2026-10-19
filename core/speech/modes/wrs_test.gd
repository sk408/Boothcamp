class_name WrsTest
extends SpeechTestMode
## WrsTest: the word recognition score as a speech test mode (Day 4, CONTRACTS.md §9.13 and §9.15,
## with the clinical amendments A1-A4). One list per start_test: 25 one-syllable words from
## core/speech/material/words_<n>.json, in file order (D11), at ONE level with ONE noise set-up. The
## level and the noise lock at the first PRESENT, the list is dealt whole there (WrsModel, D4), and
## the list ends itself after its 25th score: no STORE. SpeechSession makes a fresh WrsTest on every
## configure(), so this object is one list; the ear's sheet (speech.wrs.<ear>) gathers every list on
## that ear across start_test calls (comfortable, redo, louder) from session.sheets.
##
## What a list teaches (docs/SPEECH.md §4, CHAPTER4 §8):
##   - the level: PTA + 35, never below 55 (wrs_level; 30-40 above is accepted); a louder list 20
##     above the comfortable one (15-25 accepted), never past 100
##   - noise in the other ear when level - IA reaches its best bone (D12, D17); the noise is level - 20
##     plus that ear's air-bone gap, clamped so it can never reach the test ear (D16, A4)
##   - whole words only: a rhyme, a plural, another word or silence is a miss; the word inside a
##     chatty line, or a self-correction's final answer, is a hit
##   - a list counts when its set-up was right and no later list redoes it; only counted lists give
##     the ear's score and its flags, and the verdicts wait for the ear's best (D13)
## Golf (D19): each player list is a hole, par = the player's words; misscores (and a confirmed wrong
## set-up) are slips, and only a solo list set up unprompted can birdie.

const TIPS: Dictionary[StringName, String] = {
	&"wrs_level": "Word lists go loud enough for every sound: {his} PTA plus 35, never below 55.",
	&"wrs_unmasked": "This loud, words can cross to the other ear. Noise on before the list!",
	&"rollover_level": "The louder list goes 20 dB above the comfy one, and never past 100.",
	&"wrs_good_start": "{db}: textbook! Loud enough for {him}, never uncomfortable, and noise in the good ear when needed.",
	&"wrs_mask_ok": "Noise in the other ear first. No ghost steals these words!",
	&"wrs_mask_capped": "Noise {mask}, not {naive}: any louder and it could reach {his} test ear too.",
	&"wrs_level_locked": "One level per list. A word score belongs to a single level.",
	&"wrs_noise_locked": "The noise stays as it is for the whole list. Same set-up, every word.",
	&"wrs_no_store": "No store needed: the list scores itself after word 25.",
	&"wrs_list_reused": "A fresh list every time, or {he} starts learning the words.",
	&"ghost_lurk": "The Ghost is lurking! At this level the other ear can hear these words.",
	&"ghost_word": "The other ear answered that one. It can't count for this ear.",
	&"audible_miss": "{Lens} says every sound arrived. Yet the word came out wrong.",
	&"boo": "BOO! At {db}, words can cross to {his} other ear.",
}
## misscored, by what the patient said (her answer's kind or style). ghost_word is no misscore: it is
## the line on a ghost word scored right (a clean speech_textbook carries it).
const MISSCORED_WRS: Dictionary[StringName, String] = {
	&"rhyme": "A rhyme is a miss. Only the exact word counts.",
	&"other": "A different word is a miss. Score it as missed.",
	&"silence": "No answer is a miss. Score only what {he} said.",
	&"trap": "'{said}' isn't '{word}'. Whole word, exactly: that's a miss.",
	&"correct": "{He} said it exactly! Score it as repeated.",
	&"chatty_hit": "{He} said '{word}' inside a sentence. The word is there: that's a hit.",
	&"self_correct": "{He} settled on '{word}'. The final answer counts: a hit.",
	&"ghost_word": "Right score: {he} did say it. But the Ghost helped. Noise next time!",
}
## The verdicts (wrs_done, wrs_verdict and the flag observations), held until the ear's best is
## final (D13). Rollover is A2's index and the ear compare A3's critical difference, so "a little
## lower" and "points apart" never flag on their own.
const VERDICTS: Dictionary[StringName, String] = {
	&"not_final": "{pct} percent: {band}. Is that {his} best?",
	&"as_predicted": "{pct} percent: {band}. About what {his} tones predict.",
	&"rollover": "{pct}%! Louder, and {he} got WORSE. That's rollover.",
	&"louder_same": "Louder didn't make it worse. No rollover here.",
	&"louder_lower": "{pct}%: lower, but under the rollover cut-off. Not a flag on its own.",
	&"redo_unmasked": "{pct}%? The Ghost helped, so this list can't count. Noise on, fresh list.",
	&"redo_level": "{pct}%, but at the wrong level, so this list can't count. Fresh list, right level.",
	&"redo_louder": "{pct}%, but not 20 dB louder, so this list can't count.",
	&"best_ok": "{His} best was {best} percent: about what {his} tones predict.",
	&"below_predicted": "{His} best was {best} percent. {His} tones predict at least {min}. A red flag.",
	&"asymmetric": "Right {r}, left {l}: too far apart for chance. 25-word lists wobble, but not this much.",
	&"rollover_found": "Most ears do better, or the same, when louder. Worse is a reason to look further.",
}
## Points for the clean kinds and a finished player list (wrs_done), times the combo multiplier.
const POINTS: Dictionary[StringName, int] = {&"speech_textbook": 10, &"wrs_good_start": 10, &"wrs_mask_ok": 20, &"wrs_done": 50}
## The Call it moments a plan may ask for (§9.17.5).
const CALL_IT_MOMENTS: Array[StringName] = [&"faint_hit", &"audible_miss"]
## Hoot's banner when he finishes a list at top speed (plan hoot_turn_text wins).
const HOOT_TURN_TEXT := "I'll score the rest at top speed!"

var _plan: Dictionary = {}
var _list_id := "words_1"
var _items: Array[Dictionary] = []
## The list's number in the visit's play order (1 = the first word list), set at begin().
var _n := 0
var _coached := false
var _louder_than := 0
var _lens_on := false
## This list's trials, in order.
var _trials: Array = []
## Words presented so far (the next item's index).
var _next_i := 0
var _started := false
var _done := false
## The deal (WrsModel.deal_wrs_list) and its outcomes, one per item.
var _deal: Dictionary = {}
var _outcomes: Array[StringName] = []
## The first PRESENT's set-up (level, noise, the checks' verdicts): the sheet's list record reads it.
var _setup: Dictionary = {}
var _seq := 0
## No confirm chip, no BOO and no level coach before the first word (the tee bonus needs it).
var _unprompted := true
## The first word was presented on a wrong set-up the player confirmed (a solo list).
var _confirmed_wrong := false
## The answer styles used so far (once per list each) and the player's dealt hits so far.
var _plural_used := false
var _self_used := false
var _player_hits := 0
## Call it: the moments whose word has been presented, the item indexes answered, the answers.
var _call_done: Dictionary = {}
var _call_answered: Dictionary = {}
var _call_its: Array = []


# ---------------------------------------------------------------- identity and lifecycle

func configure(plan: Dictionary) -> void:
	var s := session()
	_plan = plan
	_list_id = String(plan.get("list", SpeechRules.WRS_LISTS[0]))
	_items = SpeechMaterial.items(_list_id)
	_louder_than = int(plan.get("louder_than", 0))
	_lens_on = bool(plan.get("lens", false))
	if s != null:
		s.list_id = _list_id


func begin(_ear: String, coached: bool) -> void:
	_coached = coached
	_n = _lists_in_visit() + 1


## The plan's level; a louder list starts at its comfortable list's level; else the PTA rounded to 5.
func start_level() -> int:
	var s := session()
	if s == null:
		return 40
	if _plan.has("level"):
		return int(_plan["level"])
	if _louder_than > 0:
		return _comfy_db()
	var p := s.pta_for(s.ear)
	return SpeechRules.snap5(p) if not is_nan(p) else 40


func measure_key() -> String:
	var s := session()
	return "wrs:%s:%s" % [s.ear if s != null else "", _list_id]


# ---------------------------------------------------------------- queries

func next_item() -> Dictionary:
	return _items[_next_i] if not _done and _next_i < _items.size() else {}


func current_trials() -> Array:
	return _trials


func is_done() -> bool:
	return _done


func words_left() -> int:
	return 0 if _done else _items.size() - _next_i


## One level per list: the dial is free only before the first word.
func can_set_level() -> bool:
	return not _started


## The noise is free only before the first word, and never off on a lock_noise list.
func can_mask() -> bool:
	var s := session()
	return not _started and not (bool(_plan.get("lock_noise", false)) and s != null and s.mask_on)


## Noise is needed when level - IA reaches the other ear's best bone (D12, D17).
func masking_needed(level: int) -> bool:
	var s := session()
	if s == null:
		return false
	return SpeechRules.speech_masking_needed(level, s.nontest_best_bone(s.ear), s.transducer)


## The word-list noise (D16, A4): level - 20 plus the other ear's air-bone gap, clamped to
## [level - IA, the test ear's best bone + IA - 5].
func mask_level(level: int) -> int:
	var s := session()
	if s == null:
		return SpeechRules.speech_mask_level(level)
	return SpeechRules.wrs_mask_level(level, s.test_best_bone(s.ear), s.transducer, SpeechRules.nontest_largest_abg(s.tone_results, s.ear))


## The coach's and Hoot's next move (§9.13.4). Only the scoring moves and the Call it guess read the
## truth.
func recommended_action() -> Dictionary:
	var s := session()
	if s == null or _done or (not _started and s.used_lists.has(_list_id)):
		return {"action": &"none", "target_db": s.db if s != null else 0}
	var moment := _call_pending()
	if moment != &"":
		return {"action": &"call_it", "guess": _outcomes[_next_i] != &"miss", "moment": moment,
			"word": String(_items[_next_i].get("text", "")), "target_db": s.db}
	if s.awaiting_score:
		return {"action": &"score_correct" if bool(s.current.get("correct", false)) else &"score_missed", "target_db": s.db}
	if _next_i >= _items.size():
		return {"action": &"none", "target_db": s.db}
	var target := textbook_target()
	if not _started:
		if s.db < target:
			return {"action": &"louder", "target_db": target}
		if s.db > target:
			return {"action": &"softer", "target_db": target}
		if masking_needed(s.db) and not s.mask_on:
			return {"action": &"mask_toggle", "target_db": target}
	return {"action": &"present", "target_db": target}


## A comfortable list: wrs_level of the measured PTA. A louder list: 20 above its comfortable list.
func textbook_target() -> int:
	var s := session()
	if s == null:
		return SpeechRules.WRS_MIN_DB
	if _louder_than > 0:
		return SpeechRules.wrs_louder_level(_comfy_db())
	return SpeechRules.wrs_level(s.pta_for(s.ear))


# ---------------------------------------------------------------- controls

## The next word at the dial level. The first one checks the set-up (when scoring), deals the whole
## list and locks the level and the noise. Refused ({}) while a word awaits its score, once the
## list is done, or for a list this visit already used.
func present() -> Dictionary:
	var s := session()
	if s == null or _done:
		return {}
	if s.awaiting_score:
		s.observe_once("score_first:" + measure_key(), &"score_first", _d({}))
		return {}
	if not _started and s.used_lists.has(_list_id):
		s.observe_once("wrs_list_reused:" + measure_key(), &"wrs_list_reused", _d({}))
		return {}
	if _next_i >= _items.size():
		return {}
	if not _started:
		_start_list()
	var i := _next_i
	var it := _items[i]
	var moment := _call_moment(i)
	if moment != &"":
		_call_done[moment] = true
	var style := _style_for(i, moment != &"")
	var ans := s.sim.respond_wrs(s.ear, s.db, it, _outcomes[i], _items, _strings("silences"), style, _strings("chatter"))
	if ans.is_empty():
		return {}
	var trial := {
		"n": i + 1, "list_n": _n, "list_id": _list_id, "slot": s.slot, "db": s.db, "item_id": String(it.get("id", "")),
		"word": String(it.get("text", "")), "said": String(ans["text"]), "kind": ans["kind"], "rhyme": bool(ans["rhyme"]),
		"trap": bool(ans["trap"]), "style": ans["style"], "aside": String(ans["aside"]), "correct": bool(ans["correct"]),
		"scored": null, "mask_db": s.mask_level(), "by_hoot": not s.scoring, "delay_s": float(ans["delay_s"]),
		"heard_by": ans["heard_by"], "audible": SpeechRules.word_fully_audible(it, float(s.db), s.measured_thresholds(s.ear)),
		"call_it": moment,
	}
	_trials.append(trial)
	((s.trials[&"wrs"] as Dictionary)[s.slot] as Array).append(trial)
	s.current = trial
	s.awaiting_score = true
	_next_i += 1
	if s.scoring:
		s.presentations += 1
	else:
		s.hoot_presentations += 1
	if trial["heard_by"] == &"cross":
		s.reaction.emit(&"cross_heard", {"ear": s.ear, "via": "speech", "db": s.db, "masked": s.mask_on})
		s.observe_once("ghost_word:" + measure_key(), &"ghost_word", _d({"n": i + 1, "word": trial["word"]}))
		s.observe_once("cross:" + s.ear, &"cross_heard_speech", _d({}))
	return trial


## Score the waiting word: correct = the player says she repeated the whole word. After the 25th
## score the list ends itself (the sheet goes out through the session's `stored`), and the trial
## comes back with list_done: true.
func score(correct: bool) -> Dictionary:
	var s := session()
	if s == null or not s.awaiting_score or s.current.is_empty() or s.current.get("scored") != null:
		return {}
	var tr := s.current
	tr["scored"] = correct
	s.awaiting_score = false
	if s.scoring:
		_check_score(tr, correct)
	if bool(_plan.get("audible_stamp", false)) and bool(tr["audible"]) and not bool(tr["correct"]):
		s.observe_once("audible_miss:" + measure_key(), &"audible_miss", _d({"n": tr["n"], "word": tr["word"], "said": tr["said"]}))
	if _scored_count() >= _items.size():
		_finish()
		tr["list_done"] = true
	return tr


## No STORE: the list scores itself after word 25.
func store() -> Dictionary:
	var s := session()
	if s != null:
		s.observe_once("wrs_no_store:" + measure_key(), &"wrs_no_store", _d({}))
	return {}


## Mode-only controls:
##   toggle_lens {on?}  the lens (the screen owns it; the mode mirrors it): {lens_on}
##   call_it {guess}    a Call it answer, unscored (guess true = "she'll get it"): {word, guess, outcome, moment}
##   confirm_chip {why} the screen showed the two-press confirm chip (why: &"level" / &"unmasked", the
##                      BOO): the set-up was prompted; the BOO observes `boo`
##   prompted           any other chip or coach before the first word: the set-up was prompted
##   ghost_lurk         the lurking Ghost is showing (coached lists): the lesson, once per list
func act(action: StringName, args: Dictionary = {}) -> Dictionary:
	var s := session()
	if s == null:
		return {}
	match action:
		&"toggle_lens":
			_lens_on = bool(args["on"]) if args.has("on") else not _lens_on
			return {"lens_on": _lens_on}
		&"call_it":
			return _answer_call_it(bool(args.get("guess", true)))
		&"confirm_chip":
			if _started:
				return {}
			_unprompted = false
			var why := StringName(String(args.get("why", _setup_problem())))
			if why == &"unmasked":
				s.observe_once("boo:" + measure_key(), &"boo", _d({"level": s.db}))
			return {"confirm_needed": why}
		&"prompted":
			if not _started:
				_unprompted = false
			return {"unprompted": _unprompted}
		&"ghost_lurk":
			if _started or s.mask_on or not masking_needed(s.db):
				return {}
			s.observe_once("ghost_lurk:" + measure_key(), &"ghost_lurk", _d({"level": s.db}))
			return {"ghost_alpha": _ghost_alpha()}
	return {}


## run_by_textbook: the mode-only move of recommended_action() (the Call it guess).
func do(action: StringName, rec: Dictionary) -> Dictionary:
	if action == &"call_it":
		return _answer_call_it(bool(rec.get("guess", true)))
	return {}


# ---------------------------------------------------------------- views and words

## get_state().wrs (§9.13.3): what the player can see. call_it_pending says a Call it is due (its
## guess stays in recommended_action()).
func state() -> Dictionary:
	var s := session()
	if s == null:
		return {}
	var right := 0
	var scored := 0
	for tr: Dictionary in _trials:
		if tr["scored"] != null:
			scored += 1
			if bool(tr["scored"]):
				right += 1
	var sheet := _sheet_of(s.ear)
	var louder := _louder_than > 0
	var comfy := _comfy_db() if louder else textbook_target()
	var win := _window()
	var moment := _call_pending()
	return {
		"list_id": _list_id, "list_title": SpeechMaterial.title(_list_id), "list_n": _n,
		"word_n": _next_i, "words": _items.size(), "scored": scored, "right_so_far": right,
		"pct_so_far": SpeechRules.wrs_pct(right, maxi(1, _items.size())),
		"level_locked": not can_set_level(), "noise_locked": not can_mask(),
		"comfy_db": comfy, "window": [win.x, win.y], "louder_than": _louder_than,
		"louder_target": SpeechRules.wrs_louder_level(comfy) if louder else -1,
		"predicted_min": _predicted_min(s.ear), "best_final": bool(sheet.get("best_final", false)),
		"lens_on": _lens_on, "masking_needed": masking_needed(s.db), "nontest_best_bone": s.nontest_best_bone(s.ear),
		"mask_level": mask_level(s.db), "ghost_alpha": _ghost_alpha(), "ghost_lurk": bool(_plan.get("ghost_lurk", _coached)),
		"lists_done": (sheet.get("lists", []) as Array).size(), "confirm_needed": _setup_problem(),
		"confirm_wrong_setup": _confirm_setup(), "call_it_pending": moment,
		"call_it_word": String(_items[_next_i].get("text", "")) if moment != &"" else "",
		"call_it_chunk": _faint_chunk(_next_i) if moment == &"faint_hit" else "",
		"started": _started, "done": _done, "coached": _coached, "unprompted": _unprompted,
		"confirmed_wrong": _confirmed_wrong, "audible_stamp": bool(_plan.get("audible_stamp", false)),
		"loud_bubble": bool(_plan.get("loud_bubble", false)), "hoot_turn_text": String(_plan.get("hoot_turn_text", HOOT_TURN_TEXT)),
	}


## The mode's lines, with its live tokens filled: {db} (the dial), {mask} / {naive} (the capped
## noise and the uncapped rule), {Lens} ("Nora-vision"). The session adds the pronouns; the screen
## fills {key:...}.
func tip(kind: StringName) -> String:
	if not TIPS.has(kind):
		return ""
	var s := session()
	var t := String(TIPS[kind])
	if s == null:
		return t
	var naive := s.db - SpeechRules.SPEECH_MASK_BELOW_DB + maxi(0, SpeechRules.nontest_largest_abg(s.tone_results, s.ear))
	return t.replace("{db}", str(s.db)).replace("{mask}", str(mask_level(s.db))).replace("{naive}", str(naive)) \
		.replace("{Lens}", _lens_name())


func points(kind: StringName) -> int:
	return int(POINTS.get(kind, -1))


func on_level_refused() -> void:
	var s := session()
	if s != null:
		s.observe_once("wrs_level_locked:" + measure_key(), &"wrs_level_locked", _d({}))


func on_mask_refused() -> void:
	var s := session()
	if s != null:
		s.observe_once("wrs_noise_locked:" + measure_key(), &"wrs_noise_locked", _d({}))


## speech.wrs_summary (§9.15.3) from the ear sheets (a throwaway mode: only the sheets are read).
func summarize(speech: Dictionary) -> void:
	var s := session()
	if s == null:
		return
	var per: Dictionary = s.sheets.get(&"wrs", {})
	var best := {}
	var final := {}
	var below := {}
	var asym := false
	for e: String in ClinicRules.EARS:
		var sh: Dictionary = per.get(e, {})
		best[e] = int(sh.get("pb_max", -1))
		final[e] = bool(sh.get("best_final", false))
		below[e] = bool(sh.get("below_predicted", false))
		asym = asym or bool(sh.get("asymmetric", false))
	var roll := {"ear": "", "comfy_pct": -1, "louder_pct": -1, "drop": 0, "index": 0.0, "flag": false}
	for e: String in ClinicRules.EARS:
		var sh: Dictionary = per.get(e, {})
		if int(sh.get("louder_pct", -1)) < 0 or (bool(roll["flag"]) and not bool(sh.get("rollover", false))):
			continue
		roll = {"ear": e, "comfy_pct": int(sh.get("pct", -1)), "louder_pct": int(sh.get("louder_pct", -1)),
			"drop": int(sh.get("rollover_drop", 0)), "index": float(sh.get("rollover_index", 0.0)),
			"flag": bool(sh.get("rollover", false))}
	var flags: Array[StringName] = []
	if asym:
		flags.append(&"asymmetric")
	if bool(below["right"]) or bool(below["left"]):
		flags.append(&"below_predicted")
	if bool(below["right"]) and bool(below["left"]):
		flags.append(&"below_predicted_both")
	if bool(roll["flag"]):
		flags.append(&"rollover")
	var both := int(best["right"]) >= 0 and int(best["left"]) >= 0
	speech["wrs_summary"] = {
		"best": best, "final": final, "diff": absi(int(best["right"]) - int(best["left"])) if both else -1,
		"asymmetric": asym, "below_predicted": below, "rollover": roll, "flags": flags,
		"referral": SpeechRules.wrs_referral(asym, bool(below["right"]), bool(below["left"]), bool(roll["flag"])),
	}


# ---------------------------------------------------------------- the list

## The first PRESENT: the set-up checks (scoring only), the deal, the locks.
func _start_list() -> void:
	var s := session()
	var problem := _setup_problem()
	_confirmed_wrong = problem != &"" and _confirm_setup() and s.scoring
	if _confirmed_wrong:
		_unprompted = false
	s.sim.transducer = s.transducer
	s.sim.mask_db = s.mask_level()
	var needed := masking_needed(s.db)
	var louder := _louder_than > 0
	var comfy := _comfy_db()
	var louder_ok := not louder or SpeechRules.wrs_louder_ok(s.db, comfy)
	var abg := SpeechRules.nontest_largest_abg(s.tone_results, s.ear)
	var capped := s.mask_on and SpeechRules.wrs_mask_capped(s.db, s.test_best_bone(s.ear), s.transducer, abg)
	_setup = {
		"level_db": s.db, "mask_db": s.mask_level(), "masked": s.mask_on, "masking_needed": needed,
		"start_ok": louder_ok if louder else SpeechRules.wrs_level_ok(s.db, s.pta_for(s.ear)),
		"textbook_start": s.db == textbook_target(), "louder_ok": louder_ok, "mask_capped": capped,
		"comfy_db": comfy if louder else -1,
	}
	if s.scoring:
		if louder:
			if louder_ok:
				s.clean(&"wrs_good_start", _d({"expected": textbook_target(), "got": s.db}))
			else:
				s.fail(&"rollover_level", _d({"expected": textbook_target(), "got": s.db, "comfy_db": comfy}))
		elif bool(_setup["start_ok"]):
			s.clean(&"wrs_good_start", _d({"expected": textbook_target(), "got": s.db}))
		else:
			s.fail(&"wrs_level", _d({"expected": textbook_target(), "got": s.db, "pta": s.pta_for(s.ear)}))
		if needed:
			if s.mask_on:
				s.clean(&"wrs_mask_ok", _d({"mask": s.mask_level()}))
			else:
				s.fail(&"wrs_unmasked", _d({"nontest_best": s.nontest_best_bone(s.ear), "level": s.db}))
	if capped:
		s.observe_once("wrs_mask_capped:" + measure_key(), &"wrs_mask_capped",
			_d({"mask": s.mask_level(), "naive": s.db - SpeechRules.SPEECH_MASK_BELOW_DB + maxi(0, abg)}))
	_seq = s.next_seq()
	_deal = s.sim.deal_wrs_list(s.ear, s.db, _items, {
		"ensure_audible_miss_by": int(_plan.get("ensure_audible_miss_by", 0)), "aside_by": int(_plan.get("aside_by", 0)),
		"audible_thresholds": s.measured_thresholds(s.ear)})
	_outcomes.clear()
	for o: Variant in _deal.get("outcomes", []):
		_outcomes.append(StringName(o))
	while _outcomes.size() < _items.size():
		_outcomes.append(&"miss")   # no word model: nothing is heard
	s.used_lists.append(_list_id)
	_started = true


## The answer style for item i (D20): the deal's aside word always takes its aside foil; on the
## player's words (plan styles), the second dealt hit self-corrects (plan self_correct), about 1 hit
## in 3 comes back chatty (never on a Call it word), and the first dealt miss whose word has a
## plural comes back as the plural trap. Hoot's words never take a style.
func _style_for(i: int, call_word: bool) -> StringName:
	var s := session()
	if i == int(_deal.get("aside_target", -1)):
		return &"aside"
	if not s.scoring or not bool(_plan.get("styles", true)):
		return &""
	if _outcomes[i] != &"miss":
		_player_hits += 1
		if call_word:
			return &""
		if bool(_plan.get("self_correct", false)) and not _self_used and _player_hits >= 2:
			_self_used = true
			return &"self_correct"
		return &"chatty_hit" if s.sim.rng.randf() < SpeechRules.WRS_CHATTY_SHARE else &""
	if not _plural_used and String(_items[i].get("plural", "")) != "" and i != int(_deal.get("audible_target", -1)):
		_plural_used = true
		return &"plural_trap"
	return &""


## The player's score against what she said: speech_textbook, or misscored with the line for what
## she said. A ghost word scored right gets the Ghost's line.
func _check_score(tr: Dictionary, correct: bool) -> void:
	var s := session()
	if correct == bool(tr["correct"]):
		var extra := _d({"n": tr["n"], "word": tr["word"]})
		if tr["heard_by"] == &"cross":
			extra["message"] = s.say(String(MISSCORED_WRS[&"ghost_word"]))
		s.clean(&"speech_textbook", extra)
		return
	var why := &"correct"
	if correct:
		if bool(tr["trap"]):
			why = &"trap"
		elif bool(tr["rhyme"]):
			why = &"rhyme"
		elif tr["kind"] == &"silence":
			why = &"silence"
		else:
			why = &"other"
	elif tr["style"] in [&"chatty_hit", &"self_correct"]:
		why = StringName(tr["style"])
	var said := String(tr["said"]).rstrip("?!. ")
	var line := String(MISSCORED_WRS[why]).replace("{said}", said).replace("{word}", String(tr["word"]).to_lower())
	s.fail(&"misscored", _d({"n": tr["n"], "word": tr["word"], "said": tr["said"], "said_kind": tr["kind"],
		"rhyme": tr["rhyme"], "trap": tr["trap"], "style": tr["style"], "scored": correct, "why": why}), line)


func _scored_count() -> int:
	var n := 0
	for tr: Dictionary in _trials:
		if tr["scored"] != null:
			n += 1
	return n


## The list is done: its record joins the ear's sheet (a redo stops the list it replaces from
## counting), both ears' sheets are recomputed (the ear compare reads both), the sheet goes out
## through `stored`, and the verdicts and the golf follow.
func _finish() -> void:
	var s := session()
	_done = true
	var ear := s.ear
	var per: Dictionary = s.sheets[&"wrs"]
	var other := "left" if ear == "right" else "right"
	var before := _sheet_of(ear)
	var other_before := _sheet_of(other)
	var lists: Array = (before.get("lists", []) as Array).duplicate(true)
	var redo := int(_plan.get("redo_of", 0))
	var other_lists: Array = (other_before.get("lists", []) as Array).duplicate(true)
	if redo > 0:
		for l: Dictionary in lists + other_lists:
			if int(l["n"]) == redo:
				l["counts"] = false
				l["redone_by"] = _n
	var rec := _list_record()
	lists.append(rec)
	var mine := _numbers(ear, lists)
	var theirs := _numbers(other, other_lists)
	per[ear] = _sheet(ear, lists, mine, theirs)
	if not other_before.is_empty():
		per[other] = _sheet(other, other_lists, theirs, mine)
	var sheet: Dictionary = per[ear]
	s.stored.emit(ear, &"wrs", sheet)
	_observe_done(rec, sheet, before, other_before)


## This list as the sheet keeps it (§9.15.1 `list`).
func _list_record() -> Dictionary:
	var s := session()
	var player := 0
	var hoot := 0
	var matches := 0
	var right := 0
	var true_right := 0
	var ghost := 0
	var audible_misses := 0
	var trials: Array = []
	for tr: Dictionary in _trials:
		var mark: bool = tr["scored"] if tr["scored"] != null else bool(tr["correct"])
		if bool(tr["by_hoot"]):
			hoot += 1
			mark = bool(tr["correct"])
		else:
			player += 1
			if mark == bool(tr["correct"]):
				matches += 1
		if mark:
			right += 1
		if bool(tr["correct"]):
			true_right += 1
		if tr["heard_by"] == &"cross":
			ghost += 1
		if bool(tr["audible"]) and not bool(tr["correct"]):
			audible_misses += 1
		var t := {}
		for k: String in ["n", "item_id", "word", "said", "kind", "rhyme", "trap", "style", "correct", "scored", "heard_by", "audible", "by_hoot", "delay_s"]:
			t[k] = tr[k]
		trials.append(t)
	var errs := s.slips()
	var misscored := player - matches
	var slips := misscored + (SpeechRules.LIST_CONFIRM_SLIP if _confirmed_wrong else 0)
	var needed := bool(_setup["masking_needed"])
	var masked := bool(_setup["masked"])
	var tee := SpeechRules.LIST_TEE_BONUS if player > 0 and not _coached and bool(_setup["textbook_start"]) \
		and masked == needed and _unprompted and not _confirmed_wrong else 0
	var words := _items.size()
	var pct := SpeechRules.wrs_pct(right, maxi(1, words))
	var p_total := float(_deal.get("p_total", 0.0))
	return {
		"n": _n, "list_id": _list_id, "list_title": SpeechMaterial.title(_list_id), "seq": _seq,
		"level_db": int(_setup["level_db"]), "mask_db": int(_setup["mask_db"]), "mask_capped": bool(_setup["mask_capped"]),
		"masked": masked, "masking_needed": needed, "start_ok": bool(_setup["start_ok"]),
		"textbook_start": bool(_setup["textbook_start"]), "unprompted": _unprompted,
		"louder_than": _louder_than, "louder_ok": bool(_setup["louder_ok"]), "comfy_db": int(_setup["comfy_db"]),
		"counts": bool(_setup["start_ok"]) and (masked or not needed) and bool(_setup["louder_ok"]),
		"confirmed_wrong": _confirmed_wrong, "words": words,
		"right": right, "pct": pct, "band": SpeechRules.wrs_band(pct),
		"true_right": true_right, "true_pct": SpeechRules.wrs_pct(true_right, maxi(1, words)), "expected_pct": roundi(p_total * 100.0),
		"deal": {"k_test": int(_deal.get("k_test", 0)), "k_total": int(_deal.get("k_total", 0)), "jitter": int(_deal.get("jitter", 0)),
			"p_test": float(_deal.get("p_test", 0.0)), "p_cross": float(_deal.get("p_cross", 0.0))},
		"player_words": player, "hoot_words": hoot, "matches": matches, "misscored": misscored,
		"accuracy": float(matches) / player if player > 0 else 0.0,
		"slips": slips, "tee_bonus": tee, "golf_strokes": player + slips - tee if player > 0 else 0, "golf_par": player,
		"golf": ClinicRules.fair_golf(player + slips - tee, player, slips == 0) if player > 0 else &"hoot",
		"ghost_words": ghost, "audible_misses": audible_misses, "call_its": _call_its.duplicate(true),
		"by_hoot": player == 0, "coached": _coached, "errors": errs, "trials": trials,
	}


## One ear's numbers from its lists: the counted comfortable list, the best, its finality, the
## louder list, rollover (A2) and the prediction (A1).
func _numbers(ear: String, lists: Array) -> Dictionary:
	var s := session()
	var comfy := {}
	var louder := {}
	var counted: Array = []
	for l: Dictionary in lists:
		if not bool(l.get("counts", false)):
			continue
		counted.append({"level_db": int(l["level_db"]), "pct": int(l["pct"])})
		if int(l.get("louder_than", 0)) > 0:
			louder = l
		else:
			comfy = l
	var roll := SpeechRules.wrs_rollover(counted)
	var pb_max := int(roll["pb_max"])
	var best_words := SpeechRules.WRS_WORDS
	for l: Dictionary in lists:
		if bool(l.get("counts", false)) and int(l["pct"]) == pb_max:
			best_words = int(l.get("words", SpeechRules.WRS_WORDS))
			break
	var predicted := _predicted_min(ear)
	var final := not louder.is_empty() or (not comfy.is_empty() and int(comfy["pct"]) >= predicted)
	return {"comfy": comfy, "louder": louder, "pb_max": pb_max, "pb_words": best_words, "final": final, "roll": roll,
		"predicted": predicted, "pta": s.pta_for(ear)}


## The ear's sheet (§9.15.1) from its lists, with `theirs` (the other ear's numbers) for the compare.
func _sheet(ear: String, lists: Array, mine: Dictionary, theirs: Dictionary) -> Dictionary:
	var s := session()
	var comfy: Dictionary = mine["comfy"]
	var louder: Dictionary = mine["louder"]
	var roll: Dictionary = mine["roll"]
	var final := bool(mine["final"])
	var pb_max := int(mine["pb_max"])
	var pta := float(mine["pta"])
	var predicted := int(mine["predicted"])
	var pct := int(comfy.get("pct", -1))
	# the level on the sheet: the counted comfortable list's, else the newest comfortable list's
	# (a louder list never sets it), else the newest list's
	var shown: Dictionary = comfy
	if shown.is_empty():
		shown = lists.back()
		for l: Dictionary in lists:
			if int(l.get("louder_than", 0)) == 0:
				shown = l
	var level := int(shown.get("level_db", -1))
	var true_db := SpeechRules.wrs_level(SpeechRules.pta_for_speech(s.sim.air(ear)))
	var other_best := int(theirs["pb_max"])
	var both_final := final and bool(theirs["final"]) and pb_max >= 0 and other_best >= 0
	var asym := both_final and SpeechRules.wrs_differ(float(pb_max), int(mine["pb_words"]), float(other_best), int(theirs["pb_words"]))
	var units := 0
	var player := 0
	var matches := 0
	var misscored := 0
	var errors: Array = []
	var holes: Array = []
	var newest := {}
	for l: Dictionary in lists:
		if bool(l.get("counts", false)) and int(l["player_words"]) > 0:
			units += 1
		player += int(l["player_words"])
		matches += int(l["matches"])
		misscored += int(l["misscored"])
		errors.append_array(l.get("errors", []))
		holes.append({"list_id": l["list_id"], "golf": l["golf"]})
		if int(l["player_words"]) > 0:
			newest = l
	var last: Dictionary = lists.back()
	var louder_pct := int(louder.get("pct", -1))
	return {
		"ear": ear, "slot": ear, "test": "wrs", "list_id": String(last["list_id"]),
		"pct": pct, "level_db": level, "band": SpeechRules.wrs_band(pct) if pct >= 0 else &"",
		"pta": pta, "pta_method": SpeechRules.pta_method(s.measured_thresholds(ear)), "recommended_level": SpeechRules.wrs_level(pta),
		"pb_max": pb_max, "pb_min": int(roll["pb_min"]), "best_final": final,
		"predicted_min": predicted, "below_predicted": final and pb_max >= 0 and pb_max < predicted,
		"predicted_max": SpeechRules.predicted_wrs_max(s.measured_thresholds(ear)),
		"louder_pct": louder_pct, "louder_level_db": int(louder.get("level_db", -1)),
		"rollover_drop": pct - louder_pct if pct >= 0 and louder_pct >= 0 else 0,
		"rollover_index": float(roll["index"]), "rollover": final and bool(roll["rollover"]),
		"other_pct": other_best, "diff_pct": absi(pb_max - other_best) if pb_max >= 0 and other_best >= 0 else -1,
		"asymmetric": asym,
		"stored_db": level, "true_db": true_db, "error_db": level - true_db,
		"units": units, "strokes": player, "par": player,
		"golf_strokes": int(newest.get("golf_strokes", 0)), "golf_par": int(newest.get("golf_par", 0)),
		"golf": newest.get("golf", &"hoot"), "holes": holes,
		"accuracy": float(matches) / player if player > 0 else 0.0,
		"misscored": misscored, "clean": errors.is_empty(), "errors": errors,
		"coached": bool(last.get("coached", false)), "by_hoot": units == 0, "seq": int((lists[0] as Dictionary)["seq"]),
		"masked": bool(last["masked"]), "mask_db": int(last["mask_db"]), "transducer": String(s.transducer),
		"words": lists.reduce(func(a: int, l: Dictionary) -> int: return a + (l["trials"] as Array).size(), 0),
		"lists": lists,
	}


## The list's done line, then (when this list made them so) rollover, the ear's final best and the
## ear compare, then the golf. Points: wrs_done and the golf, on player lists only.
func _observe_done(rec: Dictionary, sheet: Dictionary, before: Dictionary, other_before: Dictionary) -> void:
	var s := session()
	var tok := {"pct": rec["pct"], "band": String(SpeechRules.WRS_BAND_TITLES[rec["band"]]).to_lower(),
		"best": sheet["pb_max"], "min": sheet["predicted_min"]}
	var key := &"not_final"
	if not bool(rec["counts"]):
		if int(rec["louder_than"]) > 0:
			key = &"redo_louder"
		elif not bool(rec["start_ok"]):
			key = &"redo_level"
		else:
			key = &"redo_unmasked"
	elif int(rec["louder_than"]) > 0:
		key = &"rollover" if bool(sheet["rollover"]) else (&"louder_lower" if int(rec["pct"]) < int(sheet["pct"]) else &"louder_same")
	elif bool(sheet["best_final"]):
		key = &"as_predicted"
	var player := int(rec["player_words"]) > 0
	var gained := 0
	if player:
		gained = POINTS[&"wrs_done"] * ClinicRules.combo_multiplier(s.combo)
		s.points += gained
	s.emit_kind(&"wrs_done", _d({"pct": rec["pct"], "band": rec["band"], "counts": rec["counts"], "right": rec["right"],
		"words": rec["words"], "points": gained}), _line(key, tok))
	if bool(sheet["rollover"]) and not bool(before.get("rollover", false)):
		s.emit_kind(&"rollover_found", _d({"comfy_pct": sheet["pct"], "louder_pct": sheet["louder_pct"],
			"index": sheet["rollover_index"], "drop": sheet["rollover_drop"]}), _line(&"rollover_found", tok))
	# the ears can differ only once both bests are final, so this list's ear has just made it so
	var asym_new := bool(sheet["asymmetric"]) and not bool(before.get("asymmetric", false)) \
		and not bool(other_before.get("asymmetric", false))
	var right_pct := int(sheet["pb_max"]) if s.ear == "right" else int(sheet["other_pct"])
	var left_pct := int(sheet["other_pct"]) if s.ear == "right" else int(sheet["pb_max"])
	var asym_line := _line(&"asymmetric", tok.merged({"r": right_pct, "l": left_pct}, true))
	if bool(sheet["best_final"]) and not bool(before.get("best_final", false)):
		var lines: PackedStringArray = [_line(&"below_predicted" if bool(sheet["below_predicted"]) else &"best_ok", tok)]
		if asym_new:
			lines.append(asym_line)
		s.emit_kind(&"wrs_verdict", _d({"best": sheet["pb_max"], "predicted_min": sheet["predicted_min"],
			"below_predicted": sheet["below_predicted"], "asymmetric": sheet["asymmetric"], "diff": sheet["diff_pct"],
			"lines": lines}), lines[0])
		if bool(sheet["below_predicted"]):
			s.emit_kind(&"wrs_below_predicted", _d({"best": sheet["pb_max"], "predicted_min": sheet["predicted_min"]}), lines[0])
	if asym_new:
		s.emit_kind(&"wrs_asymmetry", _d({"right": right_pct, "left": left_pct, "diff": sheet["diff_pct"]}), asym_line)
	if player:
		var g := StringName(rec["golf"])
		var gp := int(SpeechSession.GOLF_POINTS.get(g, 0))
		s.points += gp
		s.observe(g, _d({"golf": g, "golf_strokes": rec["golf_strokes"], "golf_par": rec["golf_par"],
			"slips": rec["slips"], "tee_bonus": rec["tee_bonus"], "points": gp}))


# ---------------------------------------------------------------- Call it (§9.17.5)

## The Call it moment of item i, or &"": the deal's audible_target (audible_miss), or (with the lens
## on) the first player word with a lost chunk that is dealt a test hit (faint_hit). Never place 1,
## never Hoot's words, once per moment per list.
func _call_moment(i: int) -> StringName:
	var s := session()
	if s == null or not _started or _done or not s.scoring or i <= 0 or i >= _items.size():
		return &""
	var asked: Array = _plan.get("call_it", [])
	var names: Array[String] = []
	for m: Variant in asked:
		names.append(String(m))
	if names.has("audible_miss") and not _call_done.has(&"audible_miss") and i == int(_deal.get("audible_target", -1)):
		return &"audible_miss"
	if names.has("faint_hit") and not _call_done.has(&"faint_hit") and _lens_on and _outcomes[i] == &"test" \
			and _faint_chunk(i) != "":
		return &"faint_hit"
	return &""


## The Call it due before the next PRESENT (&"" = none, or it is answered).
func _call_pending() -> StringName:
	var s := session()
	if s == null or s.awaiting_score or _call_answered.has(_next_i):
		return &""
	return _call_moment(_next_i)


func _answer_call_it(guess: bool) -> Dictionary:
	var s := session()
	var moment := _call_pending()
	if moment == &"":
		return {}
	var i := _next_i
	_call_answered[i] = true
	var rec := {"word": String(_items[i].get("text", "")), "guess": guess,
		"outcome": &"hit" if _outcomes[i] != &"miss" else &"miss", "moment": moment}
	_call_its.append(rec)
	s.observe(&"call_it", _d(rec.merged({"n": i + 1}, true)))
	return rec


## The first spelling chunk of item i that the lens draws as lost (margin below 0 on the MEASURED
## thresholds), or "".
func _faint_chunk(i: int) -> String:
	var s := session()
	if s == null or i < 0 or i >= _items.size():
		return ""
	var thr := s.measured_thresholds(s.ear)
	for c: Variant in SpeechRules.chunk_sounds(_items[i]):
		var piece: Array = c
		var sound := String(piece[1])
		if sound != "" and SpeechRules.sound_margin(sound, float(s.db), thr) < 0.0:
			return String(piece[0])
	return ""


# ---------------------------------------------------------------- helpers

## A plan key's lines (silences, chatter) as a PackedStringArray.
func _strings(key: String) -> PackedStringArray:
	var out := PackedStringArray()
	var given: Variant = _plan.get(key, [])
	if given is Array or given is PackedStringArray:
		for t: Variant in given:
			out.append(String(t))
	return out


## The technique data every WRS kind carries (the session adds ear, slot, freq, test, db).
func _d(extra: Dictionary) -> Dictionary:
	var d := {"list_id": _list_id, "list_n": _n}
	d.merge(extra, true)
	return d


## A verdict line with its tokens and the patient's pronouns.
func _line(key: StringName, tok: Dictionary) -> String:
	var s := session()
	var t := String(VERDICTS[key])
	for k: String in tok:
		t = t.replace("{%s}" % k, str(tok[k]))
	return s.say(t) if s != null else t


## Is the dial a right start for this list (the comfortable window, or 15-25 above the comfy list)?
func _level_ok(db: int) -> bool:
	var s := session()
	if _louder_than > 0:
		return SpeechRules.wrs_louder_ok(db, _comfy_db())
	return SpeechRules.wrs_level_ok(db, s.pta_for(s.ear))


## What is wrong with the set-up before the first word: &"level", &"unmasked" or &"" (none, or
## the list has started). The screen's two-press confirm (solo lists) or its denial (coached) reads it.
func _setup_problem() -> StringName:
	var s := session()
	if s == null or _started or _done:
		return &""
	if not _level_ok(s.db):
		return &"level"
	if masking_needed(s.db) and not s.mask_on:
		return &"unmasked"
	return &""


## The two-press confirm is on for solo lists (plan confirm_wrong_setup, default not coached).
func _confirm_setup() -> bool:
	return bool(_plan.get("confirm_wrong_setup", not _coached))


## The accepted levels of this list: the comfortable window, or 15-25 above the comfy list.
func _window() -> Vector2i:
	var s := session()
	if _louder_than > 0:
		var c := _comfy_db()
		return Vector2i(mini(SpeechRules.MAX_DB, c + SpeechRules.WRS_LOUDER_DB - SpeechRules.WRS_LOUDER_TOLERANCE_DB),
			mini(SpeechRules.MAX_DB, c + SpeechRules.WRS_LOUDER_DB + SpeechRules.WRS_LOUDER_TOLERANCE_DB))
	return SpeechRules.wrs_window(s.pta_for(s.ear))


## How visible the lurking Ghost is now (0 with the noise on, or once the list has started).
func _ghost_alpha() -> float:
	var s := session()
	if s == null or s.mask_on or _started:
		return 0.0
	return SpeechRules.ghost_alpha(s.db, s.transducer, s.nontest_best_bone(s.ear))


## The ear's predicted minimum best score (A1), rounded.
func _predicted_min(ear: String) -> int:
	var s := session()
	return roundi(SpeechRules.wrs_predicted_min_interp(s.pta_for(ear))) if s != null else 0


## The comfortable list a louder list builds on: list `louder_than` on this ear, else the ear's
## newest counted comfortable list ({} = none).
func _comfy_list() -> Dictionary:
	var s := session()
	if s == null or _louder_than <= 0:
		return {}
	var lists: Array = _sheet_of(s.ear).get("lists", [])
	for l: Dictionary in lists:
		if int(l["n"]) == _louder_than:
			return l
	for i in range(lists.size() - 1, -1, -1):
		var l: Dictionary = lists[i]
		if bool(l.get("counts", false)) and int(l.get("louder_than", 0)) == 0:
			return l
	return {}


## The comfortable list's level (else the textbook comfortable level).
func _comfy_db() -> int:
	var c := _comfy_list()
	if not c.is_empty():
		return int(c["level_db"])
	var s := session()
	return SpeechRules.wrs_level(s.pta_for(s.ear)) if s != null else SpeechRules.WRS_MIN_DB


func _sheet_of(ear: String) -> Dictionary:
	var s := session()
	return (s.sheets[&"wrs"] as Dictionary).get(ear, {}) if s != null else {}


## Word lists finished this visit, both ears.
func _lists_in_visit() -> int:
	var s := session()
	var n := 0
	if s == null:
		return 0
	for e: Variant in (s.sheets[&"wrs"] as Dictionary):
		n += (((s.sheets[&"wrs"] as Dictionary)[e] as Dictionary).get("lists", []) as Array).size()
	return n


## {Lens}: the patient's short name plus "-vision" ("Nora-vision").
func _lens_name() -> String:
	var s := session()
	var who := s.patient.short_name() if s != null and s.patient != null else "Patient"
	return who + "-vision"
