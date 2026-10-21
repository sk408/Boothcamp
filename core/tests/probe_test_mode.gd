extends SpeechTestMode
## A stand-in word-list (wrs) and party (sin) test mode for test_speech_seams.gd (not a test file
## itself, never in the game). SpeechTestMode.path_override points both tests here; the test id
## picks the behaviour. It is the smallest mode that touches every session seam (C1-C23): its own
## tiny lists (registered in SpeechMaterial's cache, so no file is read), a mode-only first move
## (probe_ready, through do() off-screen), a list that ends itself (wrs) or sentences that are marked
## and then locked in with store() (sin), a level and noise locked once the list starts, its own
## tips, points and summary. Every seam call is written to `calls` for the tests to read.
##
## Its lists and lines are made up for the test; none is game material.

const LISTS: Dictionary = {
	"probe_w1": {"id": "probe_w1", "title": "Probe words 1", "kind": "monosyllable", "original": true, "items": [
		{"id": "pw1_1", "text": "moon", "key_sound": "m", "foils": ["noon", "soon", "loon"]},
		{"id": "pw1_2", "text": "ship", "key_sound": "sh", "foils": ["chip", "sip", "tip"]},
		{"id": "pw1_3", "text": "lamp", "key_sound": "l", "foils": ["ramp", "camp", "damp"]}]},
	"probe_w2": {"id": "probe_w2", "title": "Probe words 2", "kind": "monosyllable", "original": true, "items": [
		{"id": "pw2_1", "text": "fog", "key_sound": "f", "foils": ["dog", "log", "hog"]},
		{"id": "pw2_2", "text": "bell", "key_sound": "b", "foils": ["well", "tell", "sell"]}]},
	"probe_p1": {"id": "probe_p1", "title": "Probe party 1", "kind": "sentence", "original": true, "items": [
		{"id": "pp1_1", "text": "The red kite drifted over the quiet harbour.",
			"key_words": ["red", "kite", "drifted", "quiet", "harbour"]},
		{"id": "pp1_2", "text": "Six damp towels hung by the back door.",
			"key_words": ["six", "damp", "towels", "hung", "door"]}]},
}
## Its tips (D10: keys as {key:<action>} placeholders, filled by the screen).
const TIPS: Dictionary = {
	&"probe_slip": "Not that one: press {key:speech_correct} when the whole word comes back.",
	&"probe_ready_ok": "Ready! Press {key:present_tone} for the first word.",
	&"probe_level_locked": "The level is locked once a list starts.",
	&"probe_mask_locked": "The noise is locked once a list starts.",
	&"probe_no_store": "Word lists end themselves: no {key:store} needed.",
}
const POINTS: Dictionary = {&"probe_clean": 7, &"probe_lock": 9}

## Every seam call, in order: [name, ...] (cleared by the tests).
static var calls: Array = []

var _items: Array[Dictionary] = []
var _i := 0
var _trials: Array = []
var _ready_done := false
var _stored := false


func _log(what: String, extra: Variant = null) -> void:
	calls.append([what, extra])


func _party() -> bool:
	return test_id() == &"sin"


func configure(plan: Dictionary) -> void:
	_log("configure", plan.get("list", ""))
	for id: String in LISTS:
		SpeechMaterial._cache[id] = (LISTS[id] as Dictionary).duplicate(true)
	var s := session()
	s.list_id = String(plan.get("list", "probe_p1" if _party() else "probe_w1"))
	s.used_lists.append(s.list_id)
	_items = SpeechMaterial.items(s.list_id)
	_ready_done = bool(plan.get("ready", false))


func slot_for(ear: String) -> String:
	_log("slot_for", ear)
	if _party():
		return String(session().plan.get("slot", "both"))
	return ear


func begin(ear: String, coached: bool) -> void:
	_log("begin", [ear, coached])
	_i = 0


func start_level() -> int:
	_log("start_level")
	return int(session().plan.get("level", 70 if _party() else 50))


func measure_key() -> String:
	var s := session()
	return "%s:%s:%s" % [String(s.test), s.slot, s.list_id]


func next_item() -> Dictionary:
	return _items[_i] if _i < _items.size() else {}


func current_trials() -> Array:
	return _trials


func is_done() -> bool:
	return _stored


func words_left() -> int:
	return _items.size() - _i


func can_set_level() -> bool:
	return _trials.is_empty()


func can_mask() -> bool:
	return _trials.is_empty()


func masking_needed(level: int) -> bool:
	return not _party() and level >= 70


func mask_level(level: int) -> int:
	return level - 25


func recommended_start() -> int:
	return 70 if _party() else 55


func textbook_target() -> int:
	return int(session().plan.get("target", recommended_start()))


func recommended_action() -> Dictionary:
	var s := session()
	var target := textbook_target()
	if _stored or (next_item().is_empty() and not s.awaiting_score):
		return {"action": &"none", "target_db": s.db}
	if not _ready_done:
		return {"action": &"probe_ready", "target_db": target}
	if _trials.is_empty() and s.db != target:
		return {"action": &"louder" if s.db < target else &"softer", "target_db": target}
	if s.awaiting_score:
		if s.current.get("scored") == null:
			return {"action": &"score_correct" if bool(s.current["correct"]) else &"score_missed", "target_db": s.db}
		return {"action": &"store", "target_db": s.db}   # sin: lock the marked sentence in
	return {"action": &"present", "target_db": s.db}


func present() -> Dictionary:
	var s := session()
	_log("present")
	if s.awaiting_score or _stored or next_item().is_empty():
		return {}
	var it := next_item()
	var correct := _i % 2 == 0   # the probe patient gets every other item
	var trial := {"n": _trials.size() + 1, "db": s.db, "item_id": String(it["id"]), "word": String(it["text"]),
		"said": String(it["text"]) if correct else "Hmm?", "kind": &"correct" if correct else &"silence",
		"correct": correct, "scored": null, "by_hoot": not s.scoring, "delay_s": 0.3,
		"slot": s.slot, "list_id": s.list_id}
	_trials.append(trial)
	((s.trials[s.test] as Dictionary)[s.slot] as Array).append(trial)
	s.current = trial
	s.awaiting_score = true
	if s.scoring:
		s.presentations += 1
	else:
		s.hoot_presentations += 1
	return trial


func score(correct: bool) -> Dictionary:
	var s := session()
	_log("score", correct)
	if not s.awaiting_score or s.current.is_empty() or s.current.get("scored") != null:
		return {}
	var tr := s.current
	tr["scored"] = correct
	if s.scoring:
		if correct == bool(tr["correct"]):
			s.clean(&"probe_clean", {"n": int(tr["n"])})
		else:
			s.fail(&"probe_slip", {"n": int(tr["n"]), "scored": correct})
	if not _party():
		s.awaiting_score = false
		_i += 1
		if _i >= _items.size():
			_store_sheet()
	return tr


func store() -> Dictionary:
	var s := session()
	_log("store")
	if not _party():
		s.observe_once("probe_store:" + measure_key(), &"probe_no_store", {})
		return {}
	if not s.awaiting_score or s.current.get("scored") == null:
		return {}
	s.current["locked"] = true
	s.awaiting_score = false
	_i += 1
	if s.scoring:
		s.clean(&"probe_lock")
	if _i >= _items.size():
		return _store_sheet()
	return s.current


func act(action: StringName, args: Dictionary = {}) -> Dictionary:
	_log("act", action)
	if action == &"probe_ready" and not _ready_done:
		_ready_done = true
		session().observe(&"probe_ready_ok", args)
		return {"ready": true}
	return {}


func do(action: StringName, rec: Dictionary) -> Dictionary:
	_log("do", action)
	return act(action, {"target_db": int(rec.get("target_db", 0))})


func state() -> Dictionary:
	var s := session()
	return {"list_id": s.list_id if s != null else "", "ready": _ready_done, "items": _items.size(), "at": _i}


func tip(kind: StringName) -> String:
	return String(TIPS.get(kind, ""))


func points(kind: StringName) -> int:
	return int(POINTS.get(kind, -1))


func on_level_refused() -> void:
	_log("level_refused")
	session().observe_once("level:" + measure_key(), &"probe_level_locked", {})


func on_mask_refused() -> void:
	_log("mask_refused")
	session().observe_once("mask:" + measure_key(), &"probe_mask_locked", {})


func summarize(speech: Dictionary) -> void:
	var t := test_id()
	var sh: Dictionary = session().sheets[t]
	_log("summarize", t)
	var lists := 0
	for slot: String in sh:
		lists += ((sh[slot] as Dictionary).get("lists", []) as Array).size()
	speech["%s_summary" % t] = {"slots": sh.keys(), "lists": lists}


## One list's sheet on the slot: a second list on the slot joins the first one's sheet (lists, units).
func _store_sheet() -> Dictionary:
	var s := session()
	var by_hoot := not s.scoring
	var player := 0
	var matches := 0
	for tr: Dictionary in _trials:
		if not bool(tr["by_hoot"]):
			player += 1
			if tr["scored"] == tr["correct"]:
				matches += 1
	var list := {"list_id": s.list_id, "seq": s.next_seq(), "level_db": s.db, "player_words": player,
		"accuracy": float(matches) / player if player > 0 else 0.0, "by_hoot": player == 0, "trials": _trials.duplicate(true)}
	var old: Dictionary = (s.sheets[s.test] as Dictionary).get(s.slot, {})
	var lists: Array = (old.get("lists", []) as Array).duplicate(true)
	lists.append(list)
	var units := int(old.get("units", 0)) + (1 if player > 0 else 0)
	var sheet := {"ear": s.ear, "slot": s.slot, "test": String(s.test), "list_id": s.list_id,
		"stored_db": s.db, "true_db": s.db, "error_db": 0.0, "accuracy": float(list["accuracy"]),
		"strokes": player, "par": player, "golf": &"hoot" if player == 0 else &"par",
		"units": units, "by_hoot": units == 0, "errors": s.slips(), "lists": lists, "seq": int(old.get("seq", list["seq"]))}
	(s.sheets[s.test] as Dictionary)[s.slot] = sheet
	_stored = true
	s.awaiting_score = false
	s.stored.emit(s.ear, s.test, sheet)
	return sheet
