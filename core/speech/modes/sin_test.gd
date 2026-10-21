class_name SinTest
extends SpeechTestMode
## SinTest: the Party Noise Test as a speech test mode (CONTRACTS.md §9.14, §9.15.2; docs/CHAPTER5.md
## §5.3, §8). SpeechTestMode.make() loads it by path for a plan with test "sin", so no shared file
## names this class.
##
## One list per start_test: six sentences, sentence n at SIN_SNRS[n - 1] (25 dB down to 0), the talker
## at one level for the whole list and the party (babble) stepping up beneath it. After each answer
## the player marks the five key words of what the patient SAID (the walk: score(), the jump:
## flip_key, ALL GOT), then locks the sentence in with store(): blanks count as missed. Nothing is
## checked before LOCK IN; then every chip is checked against what he really said. The list's billed
## total gives its SNR loss (SpeechRules.snr_loss: 25.5 - total, or key words missed - 4.5), and the
## slot's sheet averages its lists: one list is a rough guess, two make it solid.
##
## Slots (SpeechRules.sin_slot): unaided "both" (or an ear), "aided_omni", "aided_directional". Aided
## lists play in the sound field at SIN_AIDED_DB, set by Hoot (level_by_hoot): no level check, no tee
## bonus and no band (the bands are unaided earphone norms, D21). A plan's compare_to gives the
## benefit over another slot and whether it beats the critical difference (real_change).
##
## The session is kept between lists, so a slot's second list joins its first list's sheet; this mode
## is made fresh for every list and reads the earlier ones from session.sheets. The truth (heard,
## count) lives in the trials, the checks and the sheets; state() never shows it.

## Hoot's lines (§9.14.5; 18 words or fewer with tokens at their longest). {he} and friends:
## PatientProfile.say(); {key:<action>}: the screen's _k() (D10); {target}, {aided}, {total},
## {loss}: this mode (tip() fills the first two from the list's state).
const TIPS: Dictionary[StringName, String] = {
	&"sin_level": "Party test: talker at {target} dB HL. The party levels follow by themselves.",
	&"sin_good_level": "Talker at {target}: just right. The party steps up by itself.",
	&"sin_aided_level": "Aided tests go at a chatting level: {aided}. The aids add their own boost.",
	&"sin_level_locked": "The talker stays at one level for the whole list.",
	&"sin_no_mask": "Both ears hear the same mix, so there's nothing to mask.",
	&"lock_first": "Lock in that sentence first: {key:store}. Then play the next one.",
	&"blanks": "Unticked key words count as missed when you lock in.",
	&"little_words": "Little words don't count, either way. Only the five key words.",
	&"noise_won": "Zero gap: the party is as loud as the talker. Score what {he} said.",
	&"chef_kiss": "Every key word scored as {he} said it. Chef's kiss!",
	&"sin_list_reused": "Fresh lists every time, or {he} learns the sentences.",
	&"practice": "A practice sentence first. I'll score it; you watch the chips.",
	&"sin_done": "List done: {total} key words. SNR loss {loss} dB.",
	# hide_loss: the loss waits for the story's bill
	&"sin_done_hidden": "List done: {total} key words.",
	&"misscored": "Score what {he} SAID: only the exact key words count.",
}
## misscored, one per wrong chip at LOCK IN, by what he said for that key word (MISSCORED_SIN).
## A trap is any changed ending (SpeechRules.is_trap): plurals and tenses, but also "smell" for
## "smelly", so its line names endings.
const MISSCORED_SIN: Dictionary[StringName, String] = {
	&"mishear": "{He} said '{said}'. Close isn't correct!",
	&"trap": "'{said}' isn't '{word}'. Word endings must match, plurals and tenses too.",
	&"filler": "{He} didn't say '{word}'. Untick it: only exact words count.",
	&"heard": "{He} did say '{word}'! Tick it.",
}
## sin_benefit, once the compared slots have two lists each ({benefit}, {crit}: dB). Written for FOCUS
## against OMNI; a plan with another compare_to passes its own benefit_lines (the same keys).
const BENEFIT_LINES: Dictionary[StringName, String] = {
	&"real": "Programme B was FOCUS: {benefit} dB better, two lists each. Real, not luck.",
	&"small": "Programme B was FOCUS: {benefit} dB better. Under {crit}, that could be luck.",
	&"none": "Programme B was FOCUS: no better this time. Run another list each.",
}
## The screen's coach lines for marking (SpModeParty picks lock_mouse after a mouse click).
const COACH_LINES: Dictionary[StringName, String] = {
	&"lock_keys": "Happy with the ticks? Lock it in: {key:store}.",
	&"lock_mouse": "Click each key word {he} got, then LOCK IN. Unticked words count as missed.",
	&"walk": "{key:speech_correct} if {he} got it, {key:speech_incorrect} if {he} missed it. Or click the chips.",
}
## Clean kinds and the points they are worth (times the combo multiplier); chef_kiss is paid flat
## at the end of a clean list (or a clean player part of one), as golf is.
const POINTS: Dictionary[StringName, int] = {&"speech_textbook": 10, &"sin_good_level": 10, &"sin_lock_ok": 20, &"chef_kiss": 100}
## The course name of the practice sentence (the amuse-bouche before the Starter).
const PRACTICE_COURSE := "Practice"

var _condition: StringName = &"unaided"
var _programme := ""
var _list_id := ""
var _items: Array[Dictionary] = []
## The practice sentence (plan practice): played before sentence 1, never scored, stored or plated.
var _practice: Dictionary = {}
var _practice_pending := false
var _level_by_hoot := false
var _level_first := false
var _hide_loss := false
var _compare_to := ""
var _lost_lines: Array = []
## The list was used before this visit's list: everything is refused (sin_list_reused).
var _reused := false
var _coached := false
## begin() came with scoring off: Hoot's off-screen run (run_by_textbook), so the level is his.
var _hidden := false
## This list's number on its slot (1, then 2) and its place in the visit (session.next_seq()).
var _list_n := 1
var _seq := 0
## This list's sentences as presented (the practice is not one of them).
var _trials: Array = []
## The sentence on the card: waiting for LOCK IN until its "locked" is true.
var _cur: Dictionary = {}
## The highlighted chip (0-4; -1 = none): the walk marks it.
var _focus := -1
var _level_locked := false
## The talker level is the player's decision (not Hoot's): it is checked, and it may earn the tee bonus.
var _level_mine := false
var _level_checked := false
var _start_db := -1
var _start_ok := false
## No set-up hint before the first sentence (act(&"prompt") clears it).
var _unprompted := true
## The player's chips at LOCK IN on this list: judged, right, wrong.
var _judged := 0
var _matches := 0
var _slips := 0
var _done := false


# ---------------------------------------------------------------- identity and lifecycle

## Plan keys (§9.14.2): list, condition, transducer, level, level_by_hoot, programme, practice,
## level_first, hide_loss, compare_to, benefit_lines, lost_lines, lens (hoot_only, hoot_first,
## hoot_turn_after, hoot_speed and the screen texts are the screen's).
func configure(plan: Dictionary) -> void:
	var c := StringName(String(plan.get("condition", "unaided")))
	_condition = c if SpeechRules.SIN_CONDITIONS.has(c) else &"unaided"
	_programme = String(plan.get("programme", ""))
	_list_id = String(plan.get("list", SpeechRules.SIN_LISTS[0]))
	_items = SpeechMaterial.items(_list_id)
	var practice_id := String(plan.get("practice", ""))
	if practice_id != "":
		var p := SpeechMaterial.items(practice_id)
		_practice = p[0] if not p.is_empty() else {}
	_practice_pending = not _practice.is_empty()
	_level_by_hoot = bool(plan.get("level_by_hoot", _aided()))
	_level_first = bool(plan.get("level_first", false))
	_hide_loss = bool(plan.get("hide_loss", false))
	_compare_to = String(plan.get("compare_to", ""))
	var lost: Variant = plan.get("lost_lines", [])
	_lost_lines = (lost as Array).duplicate() if lost is Array else []
	var s := session()
	if s == null:
		return
	_reused = s.used_lists.has(_list_id)
	s.list_id = _list_id
	# the aids are tested through speakers: earphones would cover their microphones
	if _aided() and not plan.has("transducer"):
		s.transducer = &"soundfield"
	s.sim.transducer = s.transducer
	s.sim.condition = _condition


func slot_for(ear: String) -> String:
	return SpeechRules.sin_slot(_condition, ear)


func begin(_ear: String, coached: bool) -> void:
	var s := session()
	if s == null:
		return
	_coached = coached
	_hidden = not s.scoring
	# the same mix reaches both ears (or the speakers): nothing to mask
	s.mask_on = false
	s.sim.mask_db = -1
	s.sim.condition = _condition
	if not _level_locked:
		var old: Dictionary = (s.sheets[&"sin"] as Dictionary).get(s.slot, {})
		_list_n = (old.get("lists", []) as Array).size() + 1


## The plan's level; else aided SIN_AIDED_DB, unaided the PTA rounded to 5 (the player adds the rest).
func start_level() -> int:
	if _level_locked:
		return _start_db
	var s := session()
	if s != null and s.plan.has("level"):
		return int(s.plan["level"])
	if _aided():
		return SpeechRules.SIN_AIDED_DB
	return super.start_level()


func measure_key() -> String:
	var s := session()
	return "sin:%s:%s" % [s.slot if s != null else "", _list_id]


# ---------------------------------------------------------------- queries

## What the next present() will say: the practice while it is pending, else the next sentence.
func next_item() -> Dictionary:
	if _practice_pending:
		return _practice
	return _items[_trials.size()] if _trials.size() < _items.size() else {}


func current_trials() -> Array:
	return _trials


func is_done() -> bool:
	return _done


## Sentences still to present (the practice is not counted).
func words_left() -> int:
	return maxi(0, _items.size() - _trials.size())


## One level per list: locked at the first presentation (practice included), and from the start
## when Hoot sets it.
func can_set_level() -> bool:
	return not (_level_locked or _level_by_hoot or _done or _reused)


func can_mask() -> bool:
	return false


func masking_needed(_level: int) -> bool:
	return false


func mask_level(_level: int) -> int:
	return -1


func recommended_start() -> int:
	return textbook_target()


## The talker level by the book: unaided sin_level(PTA) (the better ear's for "both"), aided
## SIN_AIDED_DB (a level Hoot sets stays his).
func textbook_target() -> int:
	var s := session()
	if s == null:
		return SpeechRules.SIN_LEVEL_DB
	if _level_by_hoot and s.plan.has("level"):
		return int(s.plan["level"])
	if _aided():
		return SpeechRules.SIN_AIDED_DB
	return SpeechRules.sin_level(s.pta_for(s.ear))


## The coach's and Hoot's next move (§9.14.4). Marks are fixed from the truth (key_fix, then the
## walk), then locked in. Before the list starts, the talker level comes first, then the practice:
## the coach sets the level before Hoot plays the practice at it. On the screen Hoot never moves a
## level the player owns (level_first, or the player's practice); off-screen he sets his own.
func recommended_action() -> Dictionary:
	var s := session()
	if s == null:
		return {"action": &"none", "target_db": 0}
	if _done or _reused:
		return {"action": &"none", "target_db": s.db}
	if _waiting():
		var marks: Array = _cur["marks"]
		var heard: Array = _cur["heard"]
		for i in marks.size():
			if marks[i] != null and bool(marks[i]) != bool(heard[i]):
				return {"action": &"key_fix", "key": i + 1, "target_db": s.db}
		if _focus >= 0:
			return {"action": &"key_got" if bool(heard[_focus]) else &"key_missed", "key": _focus + 1, "target_db": s.db}
		return {"action": &"lock", "target_db": s.db}
	if next_item().is_empty():
		return {"action": &"none", "target_db": s.db}
	var target := textbook_target()
	var hoots_turn := not s.scoring and not _hidden
	if can_set_level() and s.db != target and not (hoots_turn and (_level_first or _practice_pending)):
		return {"action": &"louder" if s.db < target else &"softer", "target_db": target}
	return {"action": &"present", "target_db": target}


# ---------------------------------------------------------------- controls

## Plays the next sentence (or the practice) at its SNR. Refused for a reused list, once the list is
## done, and while a sentence waits for LOCK IN (lock_first, once per list).
func present() -> Dictionary:
	var s := session()
	if s == null or _done:
		return {}
	if _reused:
		s.observe_once("sin_list_reused:" + measure_key(), &"sin_list_reused", _info({}))
		return {}
	if s.awaiting_score:
		s.observe_once("lock_first:" + measure_key(), &"lock_first", _info({}))
		return {}
	var practice := _practice_pending
	var it := next_item()
	if it.is_empty():
		return {}
	var n := 0 if practice else _trials.size() + 1
	var snr := SpeechRules.sin_snr_for(n)
	s.sim.condition = _condition
	var answer := s.sim.respond_sin(snr, it, s.db, s.ear, {"lost_lines": _lost_lines})
	if answer.is_empty():
		push_warning("SinTest: no answer to %s (is the party model missing?)" % String(it.get("id", "")))
		return {}
	if not _level_locked:
		_lock_level(practice)
	# the level is checked once, at the player's first sentence (Hoot may have played the practice
	# or the first courses at the level the player set)
	if s.scoring and not practice and _level_mine and not _level_checked:
		_check_level()
	var by_hoot := practice or not s.scoring
	var words: Array = it.get("key_words", [])
	var marks: Array = []
	marks.resize(words.size())
	var trial := {
		"n": n, "list_n": _list_n, "list_id": _list_id, "slot": s.slot, "condition": String(_condition),
		"item_id": String(it.get("id", "")), "text": String(it.get("text", "")), "word": String(it.get("text", "")),
		"key_words": words.duplicate(), "db": s.db, "snr": snr, "babble_db": SpeechRules.sin_babble_level(s.db, snr),
		"said": String(answer["text"]), "said_words": answer["said_words"], "said_kinds": answer["said_kinds"],
		"heard": answer["heard"], "traps": answer["traps"], "marks": marks, "count": int(answer["count"]),
		"expected": float(answer["expected"]), "kind": answer["kind"], "little_swap": bool(answer["little_swap"]),
		"by_hoot": by_hoot, "delay_s": float(answer["delay_s"]), "practice": practice, "locked": false,
	}
	if practice:
		_practice_pending = false
	else:
		_trials.append(trial)
		((s.trials[&"sin"] as Dictionary)[s.slot] as Array).append(trial)
	_cur = trial
	s.current = trial
	s.awaiting_score = true
	_focus = 0
	if by_hoot:
		s.hoot_presentations += 1
	else:
		s.presentations += 1
	if s.scoring and not practice:
		if bool(trial["little_swap"]):
			s.observe_once("sin:little_words", &"little_words", _info({}))
		if snr == 0:
			s.observe_once("sin:noise_won", &"noise_won", _info({}))
	return trial


## The walk: marks the highlighted chip (correct = he got it) and moves the highlight to the next
## blank chip after it (wrapping), or -1 when none is blank. Returns the trial ({} = refused).
func score(correct: bool) -> Dictionary:
	if not _waiting() or _focus < 0:
		return {}
	var marks: Array = _cur["marks"]
	marks[_focus] = correct
	_focus = _next_blank(marks, _focus)
	return _cur


## LOCK IN: blanks become missed; the player's chips are checked against what he said (Hoot's are
## billed by the truth). Sentence 6 finishes the list. Returns the trial plus {count_billed, list_done}
## ({} = refused).
func store() -> Dictionary:
	var s := session()
	if s == null or not _waiting():
		return {}
	var tr := _cur
	var marks: Array = tr["marks"]
	var heard: Array = tr["heard"]
	var blanks := marks.has(null)
	for i in marks.size():
		if marks[i] == null:
			marks[i] = false
	var practice := bool(tr["practice"])
	var player := s.scoring and not bool(tr["by_hoot"])
	tr["by_hoot"] = not player
	tr["locked"] = true
	s.awaiting_score = false
	_focus = -1
	# the events name the sentence just locked, not the next one
	var at := {"n": tr["n"], "sentence_n": tr["n"]}
	if practice:
		s.observe(&"practice_done", _info(at.merged({"item_id": tr["item_id"]})))
		return _locked(tr, false)
	if player:
		if blanks:
			s.observe_once("sin:blanks", &"blanks", _info(at))
		var right := 0
		var words: Array = tr["key_words"]
		var said: Array = tr["said_words"]
		var kinds: Array = tr["said_kinds"]
		for i in marks.size():
			var d := _info(at.merged({"key": i + 1, "word": String(words[i]), "said": String(said[i]),
				"said_kind": kinds[i], "marked": marks[i], "scored": marks[i]}))
			_judged += 1
			if bool(marks[i]) == bool(heard[i]):
				_matches += 1
				right += 1
				s.clean(&"speech_textbook", d)
			else:
				_slips += 1
				s.fail(&"misscored", d, misscored_line(String(words[i]), String(said[i]), StringName(kinds[i]), bool(marks[i])))
		if right == marks.size():
			s.clean(&"sin_lock_ok", _info(at))
	else:
		for i in marks.size():
			marks[i] = bool(heard[i])
	if _trials.size() >= _items.size():
		_finish()
		return _locked(tr, true)
	return _locked(tr, false)


## Mode-only controls (§9.14.3); keys are 1-5:
##   flip_key {key}: blank or missed -> got, got -> missed; the highlight moves there.
##   mark_key {key, got}: sets that chip (a right-click is got: false); the highlight moves on.
##   all_got: all five got; no highlight.   focus_key {key}: moves the highlight only.
##   lock: store().   prompt: the screen showed a set-up hint before the first sentence (no tee bonus).
func act(action: StringName, args: Dictionary = {}) -> Dictionary:
	match action:
		&"lock":
			return store()
		&"prompt":
			if _level_locked:
				return {}
			_unprompted = false
			return {"unprompted": false}
	if not _waiting():
		return {}
	var marks: Array = _cur["marks"]
	match action:
		&"all_got":
			marks.fill(true)
			_focus = -1
			return _cur
	var i := int(args.get("key", 0)) - 1
	if i < 0 or i >= marks.size():
		return {}
	match action:
		&"flip_key":
			marks[i] = marks[i] != true
			_focus = i
		&"mark_key":
			marks[i] = bool(args.get("got", true))
			_focus = _next_blank(marks, i)
		&"focus_key":
			_focus = i
		_:
			return {}
	return _cur


## run_by_textbook's mode-only moves: key_got / key_missed (the walk), key_fix {key}, all_got, lock.
func do(action: StringName, rec: Dictionary) -> Dictionary:
	match action:
		&"key_got":
			return score(true)
		&"key_missed":
			return score(false)
		&"key_fix":
			return act(&"flip_key", {"key": int(rec.get("key", 0))})
		&"all_got":
			return act(&"all_got")
		&"lock":
			return store()
	return {}


# ---------------------------------------------------------------- views and words

## get_state().sin (CHAPTER5 §12). The sentence on the card is the one waiting for LOCK IN, else the
## next one. Never truth: no heard, count or expected.
func state() -> Dictionary:
	var s := session()
	if s == null:
		return {}
	var waiting := _waiting()
	var n := _sentence_n()
	var snr := SpeechRules.sin_snr_for(n)
	var card := _cur if waiting else next_item()
	var marks: Array = []
	if waiting:
		marks = (_cur["marks"] as Array).duplicate()
	else:
		marks.resize((card.get("key_words", []) as Array).size())
	var courses: Array = []
	var total := 0
	for i in SpeechRules.SIN_SNRS.size():
		var tr: Dictionary = _trials[i] if i < _trials.size() else {}
		var locked := bool(tr.get("locked", false))
		var billed := _billed(tr["marks"]) if locked else -1
		if locked:
			total += billed
		courses.append({"n": i + 1, "snr": SpeechRules.SIN_SNRS[i], "course": SpeechRules.SIN_COURSES[i],
			"count": billed, "by_hoot": bool(tr.get("by_hoot", false)), "locked": locked})
	var sheet: Dictionary = (s.sheets[&"sin"] as Dictionary).get(s.slot, {})
	var lists: Array = []
	for l: Dictionary in sheet.get("lists", []):
		lists.append({"list_id": l["list_id"], "total": l["total"], "snr_loss": -1.0 if _hide_loss else float(l["snr_loss"])})
	var avg := -1.0 if _hide_loss or sheet.is_empty() else float(sheet["snr_loss"])
	var band: StringName = &"" if _aided() or avg < 0.0 else SpeechRules.sin_band(avg)
	return {
		"condition": String(_condition), "condition_title": String(SpeechRules.SIN_CONDITION_TITLES[_condition]),
		"programme": _programme, "slot": s.slot, "list_id": _list_id, "list_title": SpeechMaterial.title(_list_id),
		"list_n": _list_n, "sentence_n": n, "sentences": SpeechRules.SIN_SNRS.size(), "snr": snr,
		"babble_db": SpeechRules.sin_babble_level(s.db, snr), "talker_db": s.db, "target_db": textbook_target(),
		"level_by_hoot": _level_by_hoot, "level_locked": not can_set_level(),
		"course": PRACTICE_COURSE if n == 0 else SpeechRules.SIN_COURSES[n - 1], "courses": courses,
		"text": String(card.get("text", "")), "key_words": (card.get("key_words", []) as Array).duplicate(),
		"marks": marks, "focus_key": _focus if waiting else -1, "total_so_far": total,
		"lists": lists, "avg_loss": avg, "band": band, "loss_hidden": _hide_loss,
		"practice_pending": _practice_pending, "practice": waiting and bool(_cur.get("practice", false)),
		"awaiting_lock": waiting, "done": _done, "reused": _reused, "aided": _aided(), "label": _label(),
		"transducer": String(s.transducer), "compare_to": _compare_to, "lens": bool(s.plan.get("lens", false)),
		"slips": _slips,
	}


## The line for a kind ("" = SpeechSession.TIPS), with {target} and {aided} filled.
func tip(kind: StringName) -> String:
	if not TIPS.has(kind):
		return ""
	return _fill(TIPS[kind], {"target": textbook_target(), "aided": SpeechRules.SIN_AIDED_DB})


func points(kind: StringName) -> int:
	return int(POINTS.get(kind, -1))


func on_level_refused() -> void:
	var s := session()
	if s == null:
		return
	var kind := &"sin_aided_level" if _level_by_hoot and _aided() else &"sin_level_locked"
	s.observe_once("%s:%s" % [kind, measure_key()], kind, _info({}))


func on_mask_refused() -> void:
	var s := session()
	if s != null:
		s.observe_once("sin:no_mask", &"sin_no_mask", _info({}))


## sin_summary (§9.15.3): {unaided: {slot, snr_loss, band, band_name, remedy, lists}, ears (per-ear
## unaided sheets), omni / directional: {slot, snr_loss, lists}, benefit_db, crit_diff_db,
## real_change, benefit_unsure, estimated_loss, lists_used}. Missing conditions are left out.
func summarize(speech: Dictionary) -> void:
	var s := session()
	if s == null:
		return
	# only whole party sheets (a stand-in sheet from another test file is skipped)
	var sheets := {}
	for slot: Variant in s.sheets[&"sin"]:
		var sh: Variant = (s.sheets[&"sin"] as Dictionary)[slot]
		if sh is Dictionary and (sh as Dictionary).has_all(["slot", "snr_loss", "lists_done", "lists", "label"]):
			sheets[slot] = sh
	if sheets.is_empty():
		return
	var out := {}
	var ears := {}
	for e: String in ["right", "left"]:
		if sheets.has(e):
			ears[e] = _brief(sheets[e], true)
	var unaided: Dictionary = sheets.get("both", {})
	if unaided.is_empty() and not ears.is_empty():
		# per-ear tests only: the better (lower) loss stands for the patient
		var r: Dictionary = sheets.get("right", {})
		var l: Dictionary = sheets.get("left", {})
		unaided = r if l.is_empty() or (not r.is_empty() and float(r["snr_loss"]) <= float(l["snr_loss"])) else l
	if not unaided.is_empty():
		out["unaided"] = _brief(unaided, true)
		out["estimated_loss"] = float(unaided.get("estimated_loss", 0.0))
	if not ears.is_empty():
		out["ears"] = ears
	var omni: Dictionary = sheets.get("aided_omni", {})
	var focus: Dictionary = sheets.get("aided_directional", {})
	if not omni.is_empty():
		out["omni"] = _brief(omni, false)
	if not focus.is_empty():
		out["directional"] = _brief(focus, false)
	if not omni.is_empty() and not focus.is_empty():
		var n := mini(int(omni["lists_done"]), int(focus["lists_done"]))
		var benefit := float(omni["snr_loss"]) - float(focus["snr_loss"])
		var real := SpeechRules.sin_real_change(benefit, n)
		out["benefit_db"] = benefit
		out["crit_diff_db"] = SpeechRules.sin_crit_diff(n)
		out["real_change"] = real
		out["benefit_unsure"] = not real
	if not out.has("estimated_loss"):
		out["estimated_loss"] = float((sheets.values()[0] as Dictionary).get("estimated_loss", 0.0))
	# every list played, in play order
	var played: Array = []
	for slot: String in sheets:
		for l: Dictionary in (sheets[slot] as Dictionary).get("lists", []):
			played.append([int(l.get("seq", 0)), String(l["list_id"])])
	played.sort()
	var used: Array[String] = []
	for p: Array in played:
		used.append(String(p[1]))
	out["lists_used"] = used
	speech["sin_summary"] = out


## The misscored line for one chip: a ticked miss by what he said instead, or a heard word left
## unticked.
static func misscored_line(word: String, said: String, said_kind: StringName, marked: bool) -> String:
	var key: StringName = &"heard"
	if marked:
		key = &"mishear" if said_kind == &"mishear" else (&"trap" if said_kind == &"trap" else &"filler")
	return MISSCORED_SIN[key].replace("{said}", said).replace("{word}", word)


# ---------------------------------------------------------------- internals

func _aided() -> bool:
	return _condition != &"unaided"


## A sentence (or the practice) is on the card and not locked in yet.
func _waiting() -> bool:
	var s := session()
	return s != null and s.awaiting_score and not _cur.is_empty() and not bool(_cur.get("locked", false))


## The sentence on the card (0 = the practice), else the next one; 6 once the list is done.
func _sentence_n() -> int:
	if _waiting():
		return int(_cur["n"])
	if _practice_pending:
		return 0
	return clampi(_trials.size() + 1, 1, maxi(1, _items.size())) if not _done else _items.size()


## The first presentation locks the level. It is the player's unless Hoot sets it (level_by_hoot,
## an off-screen run, or his screen turn at the start of a list he sets up himself).
func _lock_level(practice: bool) -> void:
	var s := session()
	_level_locked = true
	_start_db = s.db
	_start_ok = s.db == textbook_target()
	_level_mine = not _level_by_hoot and not _hidden and (s.scoring or practice or _level_first)
	_seq = s.next_seq()
	if not s.used_lists.has(_list_id):
		s.used_lists.append(_list_id)


func _check_level() -> void:
	var s := session()
	_level_checked = true
	var target := textbook_target()
	var d := _info({"target": target, "got": _start_db, "pta": s.pta_for(s.ear)})
	if _start_ok:
		s.clean(&"sin_good_level", d)
	else:
		s.fail(&"sin_level", d, _fill(TIPS[&"sin_level"], {"target": target}))


## The technique data every SIN kind carries (§9.14.6): the slot as the ear, the condition, the list
## and the sentence. The session adds freq, test, db and slot.
func _info(extra: Dictionary) -> Dictionary:
	var s := session()
	var slot := s.slot if s != null else ""
	var d := {"ear": slot, "slot": slot, "condition": String(_condition), "list_id": _list_id, "list_n": _list_n,
		"sentence_n": _sentence_n()}
	d.merge(extra, true)
	return d


func _locked(tr: Dictionary, list_done: bool) -> Dictionary:
	var out := tr.duplicate()
	out["count_billed"] = _billed(tr["marks"])
	out["list_done"] = list_done
	return out


## Sentence 6 is locked: the list joins its slot's sheet, the sheet goes out (stored), then the
## list's observations, the golf and chef's-kiss points and, when compared, the benefit.
func _finish() -> void:
	var s := session()
	_done = true
	var list := _list_record()
	var old: Dictionary = (s.sheets[&"sin"] as Dictionary).get(s.slot, {})
	var lists: Array = (old.get("lists", []) as Array).duplicate(true)
	lists.append(list)
	var sheet := _sheet(lists)
	(s.sheets[&"sin"] as Dictionary)[s.slot] = sheet
	s.stored.emit(s.ear, &"sin", sheet)
	var total := int(list["total"])
	var loss := float(list["snr_loss"])
	var shown := not _hide_loss
	var d := _info({"total": total, "snr_loss": loss if shown else -1.0,
		"band": SpeechRules.sin_band(loss) if shown and not _aided() else &""})
	s.emit_kind(&"sin_done", d, s.say(_fill(TIPS[&"sin_done" if shown else &"sin_done_hidden"], {"total": total, "loss": "%.1f" % loss})))
	var player := int(list["player_sentences"])
	if player > 0 and int(list["slips"]) == 0:
		s.observe(&"chef_kiss", _info({}))
		s.points += POINTS[&"chef_kiss"]
	var g := StringName(list["golf"])
	if player > 0 and SpeechSession.GOLF_POINTS.has(g):
		if g in [&"birdie", &"eagle", &"albatross"]:
			s.observe(g, _info({}))
		s.points += int(SpeechSession.GOLF_POINTS[g])
	if sheet.has("benefit_db") and int(sheet["compared_lists"]) >= SpeechRules.SIN_LISTS_PER_CONDITION:
		var benefit := float(sheet["benefit_db"])
		var crit := float(sheet["crit_diff_db"])
		var real := bool(sheet["real_change"])
		var key: StringName = &"real" if real else (&"small" if benefit > 0.0 else &"none")
		var line := BENEFIT_LINES[key]
		var given: Variant = s.plan.get("benefit_lines", {})
		if given is Dictionary:
			for k: Variant in [key, String(key)]:
				if (given as Dictionary).has(k):
					line = String((given as Dictionary)[k])
					break
		s.emit_kind(&"sin_benefit", _info({"benefit": benefit, "crit": crit, "real": real, "compared_to": _compare_to}),
			s.say(_fill(line, {"benefit": "%.1f" % benefit, "crit": "%.1f" % crit})))


## This list as the sheet keeps it (§9.15.2): the bill, who scored what, and its golf (D19).
func _list_record() -> Dictionary:
	var s := session()
	var total := 0
	var true_total := 0
	var player := 0
	var sentences: Array = []
	for tr: Dictionary in _trials:
		var billed := _billed(tr["marks"])
		total += billed
		true_total += int(tr["count"])
		if not bool(tr["by_hoot"]):
			player += 1
		sentences.append({"n": tr["n"], "item_id": tr["item_id"], "snr": tr["snr"], "babble_db": tr["babble_db"],
			"said": tr["said"], "said_words": (tr["said_words"] as Array).duplicate(), "heard": (tr["heard"] as Array).duplicate(),
			"marks": (tr["marks"] as Array).duplicate(), "count": billed, "true_count": tr["count"], "expected": tr["expected"],
			"kind": tr["kind"], "little_swap": tr["little_swap"], "by_hoot": tr["by_hoot"], "delay_s": tr["delay_s"]})
	var unprompted := _unprompted and not _coached
	# a birdie needs a solo list whose talker the player set unprompted, at the textbook level
	var tee := SpeechRules.LIST_TEE_BONUS if player > 0 and not _coached and _level_mine and _start_ok and unprompted else 0
	var par := SpeechRules.sin_par(player)
	var strokes := par + _slips - tee
	return {
		"n": _list_n, "list_id": _list_id, "list_title": SpeechMaterial.title(_list_id), "seq": _seq,
		"condition": String(_condition), "programme": _programme, "level_db": _start_db,
		"total": total, "snr_loss": SpeechRules.snr_loss(total), "true_total": true_total,
		"player_sentences": player, "hoot_sentences": _trials.size() - player,
		"key_words": _judged, "matches": _matches, "slips": _slips,
		"accuracy": float(_matches) / _judged if _judged > 0 else 0.0,
		"by_hoot": player == 0, "coached": _coached, "level_by_hoot": _level_by_hoot, "level_mine": _level_mine,
		"start_ok": _start_ok, "unprompted": unprompted, "tee_bonus": tee,
		"golf_strokes": strokes, "golf_par": par, "golf": ClinicRules.fair_golf(strokes, par, _slips == 0) if player > 0 else &"hoot",
		"errors": s.slips(), "sentences": sentences,
	}


## The slot's sheet over all its lists (§9.15.2).
func _sheet(lists: Array) -> Dictionary:
	var s := session()
	var losses: Array = []
	var units := 0
	var player := 0
	var judged := 0
	var matches := 0
	var slips := 0
	var coached := false
	var errors: Array = []
	var holes: Array = []
	var newest: Dictionary = {}
	for l: Dictionary in lists:
		losses.append(float(l["snr_loss"]))
		var p := int(l["player_sentences"])
		player += p
		if p > 0:
			units += 1
			newest = l
		judged += int(l["key_words"])
		matches += int(l["matches"])
		slips += int(l["slips"])
		coached = coached or bool(l["coached"])
		errors.append_array(l["errors"])
		holes.append({"list_id": l["list_id"], "golf": l["golf"]})
	var loss := SpeechRules.sin_average(losses)
	var aided := _aided()
	var band: StringName = &"" if aided else SpeechRules.sin_band(loss)
	s.sim.condition = _condition
	var true_loss := s.sim.effective_snr_loss(s.ear)
	var sheet := {
		"ear": s.ear, "slot": s.slot, "test": "sin", "condition": String(_condition),
		"condition_title": String(SpeechRules.SIN_CONDITION_TITLES[_condition]), "programme": _programme,
		"transducer": String(s.transducer), "level_db": int((lists.back() as Dictionary)["level_db"]), "aided": aided,
		"label": _label(), "lists": lists, "lists_done": lists.size(), "snr_loss": loss,
		"band": band, "band_name": String(SpeechRules.SIN_BAND_NAMES[band]) if not aided else "",
		"remedy": String(SpeechRules.SIN_REMEDIES[band]) if not aided else "",
		"true_loss": true_loss, "true_band": &"" if aided else SpeechRules.sin_band(true_loss),
		"estimated_loss": _estimated_loss(),
		"stored_db": roundi(loss), "true_db": roundi(true_loss), "error_db": absf(loss - true_loss),
		"key_words": judged, "misscored": slips, "accuracy": float(matches) / judged if judged > 0 else 0.0,
		"units": units, "strokes": player, "par": player,
		"golf_strokes": int(newest.get("golf_strokes", 0)), "golf_par": int(newest.get("golf_par", 0)),
		"golf": StringName(newest.get("golf", &"hoot")), "holes": holes,
		"forks": SpeechRules.sin_forks(slips) if player > 0 else -1,
		"clean": errors.is_empty(), "errors": errors, "by_hoot": units == 0, "coached": coached,
		"seq": int((lists[0] as Dictionary)["seq"]),
	}
	if _compare_to != "":
		var other: Dictionary = (s.sheets[&"sin"] as Dictionary).get(_compare_to, {})
		if int(other.get("lists_done", 0)) > 0:
			var n := mini(int(other["lists_done"]), lists.size())
			var benefit := float(other["snr_loss"]) - loss
			sheet["benefit_db"] = benefit
			sheet["compared_to"] = _compare_to
			sheet["compared_lists"] = n
			sheet["crit_diff_db"] = SpeechRules.sin_crit_diff(n)
			sheet["real_change"] = SpeechRules.sin_real_change(benefit, n)
	return sheet


## The sheet's label: "unaided, phones" / "unaided, inserts" / "aided, sound field".
func _label() -> String:
	if _aided():
		return "aided, sound field"
	var s := session()
	var t: StringName = s.transducer if s != null else &"phones"
	return "unaided, " + ("sound field" if t == &"soundfield" else String(t))


## The audiogram's own rough estimate (estimated_snr_loss) on the better ear's measured thresholds
## (a per-ear test: that ear's). Tests only: no line prints it.
func _estimated_loss() -> float:
	var s := session()
	var e := s.ear
	if e != "right" and e != "left":
		e = SpeechRules.better_ear(s.pta_for("right"), s.pta_for("left"))
	return SpeechRules.estimated_snr_loss(s.measured_thresholds(e))


static func _brief(sh: Dictionary, with_band: bool) -> Dictionary:
	var out := {"slot": sh["slot"], "snr_loss": float(sh["snr_loss"]), "lists": int(sh["lists_done"]), "label": sh["label"]}
	if with_band:
		out["band"] = sh["band"]
		out["band_name"] = sh["band_name"]
		out["remedy"] = sh["remedy"]
	return out


## The key words billed: the ticked chips.
static func _billed(marks: Array) -> int:
	var n := 0
	for m: Variant in marks:
		if m == true:
			n += 1
	return n


## The next blank chip after `after` (wrapping; `after` itself last), or -1 when none is blank.
static func _next_blank(marks: Array, after: int) -> int:
	for k in range(1, marks.size() + 1):
		var j := (after + k) % marks.size()
		if marks[j] == null:
			return j
	return -1


static func _fill(line: String, tokens: Dictionary) -> String:
	for k: String in tokens:
		line = line.replace("{%s}" % k, str(tokens[k]))
	return line
