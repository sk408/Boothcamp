extends TestCase
## (Day 5) SinTest, the Party Noise Test's session mode (CONTRACTS.md §9.14, §9.15, §9.21, §9.24;
## docs/CHAPTER5.md §3, §5.3, §8, §14): the present / mark / flip / all-got / lock flow and its
## refusals, the walk's highlight, the per-chip checks and their lines, the coach's move, whose talker
## level it is (the player's, level_first, the practice, level_by_hoot), Hoot's sentences, the sheets,
## units and summary, party golf, the FOCUS benefit, and run_by_textbook on every Day 5 plan with no
## screen. Marco's stand-in profile comes from test_speech_sin_model.gd until his own lands; every
## session is seeded, so a failure replays. The model's statistics are in test_speech_sin_model.gd.

const Model := preload("res://core/tests/test_speech_sin_model.gd")
const LOST := ["Words? Gone, sorry.", "Only clatter here."]
## §9.14.3: the keys get_state().sin must hold.
const STATE_KEYS: PackedStringArray = ["condition", "condition_title", "programme", "slot", "list_id", "list_title",
	"list_n", "sentence_n", "snr", "babble_db", "talker_db", "level_by_hoot", "course", "courses", "key_words", "marks",
	"focus_key", "total_so_far", "lists", "avg_loss", "band", "level_locked", "practice_pending", "awaiting_lock"]
## §9.14.3: the keys a presented sentence carries.
const TRIAL_KEYS: PackedStringArray = ["n", "list_n", "list_id", "slot", "item_id", "text", "key_words", "snr",
	"babble_db", "said", "said_words", "heard", "traps", "marks", "count", "expected", "kind", "little_swap", "by_hoot",
	"delay_s", "practice", "locked"]
## §9.15.2: the keys of a party sheet and of each of its lists.
const SHEET_KEYS: PackedStringArray = ["ear", "slot", "test", "condition", "condition_title", "programme", "transducer",
	"level_db", "aided", "label", "lists", "lists_done", "snr_loss", "band", "band_name", "remedy", "true_loss",
	"true_band", "estimated_loss", "stored_db", "true_db", "key_words", "misscored", "accuracy", "units", "strokes",
	"par", "golf_strokes", "golf_par", "golf", "holes", "forks", "clean", "errors", "by_hoot", "coached", "seq"]
const LIST_KEYS: PackedStringArray = ["n", "list_id", "list_title", "seq", "total", "snr_loss", "player_sentences",
	"hoot_sentences", "slips", "by_hoot", "level_by_hoot", "unprompted", "tee_bonus", "golf_strokes", "golf_par", "golf",
	"sentences"]
const SENTENCE_KEYS: PackedStringArray = ["n", "item_id", "snr", "babble_db", "said", "said_words", "heard", "marks",
	"count", "kind", "little_swap", "by_hoot", "delay_s"]
## The diagnosis words no Hoot line may hold (§9.24).
const NO_DIAGNOSIS: PackedStringArray = ["tumour", "tumor", "neuroma", "schwannoma", "cancer", "growth", "stroke", "meniere"]

var _style := "otosuite"


func before_each() -> void:
	_style = Game.get_key_style()


func after_each() -> void:
	Game.set_key_style(_style)


# ---------------------------------------------------------------- helpers

static func _marco(speech: Dictionary = {}) -> PatientProfile:
	return Model._marco(speech)


## A Day 5 visit for Marco: one session, seeded, with Hoot's tones.
static func _visit(seed_value: int = 3, speech: Dictionary = {}) -> SpeechSession:
	var p := _marco(speech)
	var s := SpeechSession.new(p, seed_value)
	s.tone_results = SpeechSession.tone_results_from(p)
	return s


## Configures and begins one party list on `s` (a "sin" plan with the visit's tones).
static func _start(s: SpeechSession, plan: Dictionary, ear: String = "both", coached: bool = false) -> void:
	var p := {"test": "sin", "tones": s.tone_results}
	p.merge(plan, true)
	s.configure(p)
	s.begin(ear, coached)


## Every technique event a session emits: [kind, data].
static func _events(s: SpeechSession) -> Array:
	var out: Array = []
	s.technique.connect(func(kind: StringName, d: Dictionary) -> void: out.append([kind, d.duplicate(true)]))
	return out


static func _named(events: Array, kind: StringName) -> Array:
	var out: Array = []
	for e: Array in events:
		if e[0] == kind:
			out.append(e[1])
	return out


## Plays the started list to its end by the coach's moves, as whoever s.scoring says. `slips`:
## {sentence n: [chip indexes]} flipped wrong just before that sentence's LOCK IN.
static func _play(s: SpeechSession, slips: Dictionary = {}) -> Dictionary:
	var sheet := {}
	for step in 600:
		if s.is_done():
			break
		var rec := s.recommended_action()
		var action := StringName(rec["action"])
		match action:
			&"louder":
				s.step_level(1)
			&"softer":
				s.step_level(-1)
			&"present":
				s.present()
			&"lock":
				var n := int(s.current["n"])
				for i: int in slips.get(n, []):
					s.mode.act(&"flip_key", {"key": i + 1})
				var r := s.store()
				if bool(r.get("list_done", false)):
					sheet = (s.sheets[&"sin"] as Dictionary)[s.slot]
			&"none":
				break
			_:
				s.mode.do(action, rec)
	return sheet


## The six Day 5 party plans of §9.21 (quick visit on or off).
static func _day5_plans(tones: Dictionary, quick: bool) -> Array[Dictionary]:
	var plans: Array[Dictionary] = [
		{"list": "party_1", "condition": "unaided", "level": 50, "practice": "party_practice", "hide_loss": true, "lost_lines": LOST},
		{"list": "party_2", "condition": "unaided", "level_first": true, "lost_lines": LOST},
		{"list": "party_3", "condition": "omni", "programme": "A", "lost_lines": LOST},
		{"list": "party_4", "condition": "omni", "programme": "A", "hoot_only": true, "hoot_turn_after": 0},
		{"list": "party_5", "condition": "directional", "programme": "B", "compare_to": "aided_omni", "lost_lines": LOST},
		{"list": "party_6", "condition": "directional", "programme": "B", "compare_to": "aided_omni", "hoot_only": true,
			"hoot_turn_after": 0},
	]
	for p: Dictionary in plans:
		p["test"] = "sin"
		p["tones"] = tones
		if quick and p["list"] in ["party_2", "party_3", "party_5"]:
			p["hoot_first"] = 3
	return plans


## Marks the sentence on the card by the coach's moves, then locks it in; returns store()'s answer.
static func _lock_as_coached(s: SpeechSession) -> Dictionary:
	for step in 12:
		var rec := s.recommended_action()
		if rec["action"] == &"lock":
			return s.store()
		s.mode.do(StringName(rec["action"]), rec)
	return {}


static func _bools(a: Array) -> Array:
	var out: Array = []
	for v: Variant in a:
		out.append(v)
	return out


# ---------------------------------------------------------------- the mode, slots and state

func test_the_mode_loads_by_path() -> void:
	var s := _visit()
	_start(s, {"list": "party_1", "level": 70})
	assert_true(s.mode is SinTest and not s.mode_missing, "the real party mode")
	assert_eq(SpeechTestMode.script_path(&"sin"), "res://core/speech/modes/sin_test.gd")
	assert_eq(s.slot, "both")
	assert_eq(s.measure_key(), "sin:both:party_1")
	assert_eq(s.list_id, "party_1")
	var st := s.get_state()
	assert_eq(st["mode"], "sin")
	assert_eq(st["list_title"], "Party list 1")
	assert_eq(int(st["words_left"]), 6, "six sentences")
	assert_eq(int(st["recommended_start"]), 70, "sin_level(PTA): the talker at 70")
	var view: Dictionary = st["sin"]
	for k: String in STATE_KEYS:
		assert_true(view.has(k), "state key %s" % k)
	assert_eq(view["condition"], "unaided")
	assert_eq(view["course"], "Starter")
	assert_eq(int(view["snr"]), 25)
	assert_eq(int(view["babble_db"]), 45, "the party at 70 - 25")
	assert_eq((view["courses"] as Array).size(), 6)
	assert_eq(view["label"], "unaided, phones")
	# slots and transducers
	var m := s.mode
	assert_eq([m.slot_for("both"), m.slot_for("right"), m.slot_for("left")], ["both", "right", "left"])
	_start(s, {"list": "party_3", "condition": "omni"})
	assert_eq([s.slot, String(s.transducer)], ["aided_omni", "soundfield"], "aided: speakers")
	_start(s, {"list": "party_5", "condition": "directional"})
	assert_eq(s.slot, "aided_directional")
	_start(s, {"list": "party_2", "transducer": "inserts"})
	assert_eq(s.get_state()["sin"]["label"], "unaided, inserts")
	_start(s, {"list": "party_2", "condition": "nonsense"})
	assert_eq(s.get_state()["sin"]["condition"], "unaided", "an unknown condition is unaided")


func test_nothing_to_mask() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 70, "mask_on": true})
	assert_false(s.mask_on, "no noise in the other ear: the same mix reaches both")
	assert_false(s.masking_needed_here())
	assert_eq(s.mask_level(), -1)
	assert_false(s.set_mask(true), "refused")
	assert_false(s.toggle_mask())
	assert_eq(_named(ev, &"sin_no_mask").size(), 1, "said once")


func test_state_is_never_truth() -> void:
	var s := _visit()
	_start(s, {"list": "party_1", "level": 70})
	var tr := s.present()
	assert_false(tr.is_empty())
	for k: String in TRIAL_KEYS:
		assert_true(tr.has(k), "trial key %s" % k)
	var view: Dictionary = s.get_state()["sin"]
	for k: String in ["heard", "count", "expected", "said_kinds", "traps", "said_words"]:
		assert_false(view.has(k), "no truth in the state: %s" % k)
	assert_eq(view["marks"], [null, null, null, null, null], "blank chips until the player marks them")
	assert_eq(view["key_words"], tr["key_words"])
	assert_eq(view["text"], tr["text"], "the sentence on the card")
	assert_true(bool(view["awaiting_lock"]))
	assert_eq(int(view["focus_key"]), 0, "the highlight starts on chip 1")


# ---------------------------------------------------------------- one sentence

func test_present_mark_flip_all_got_lock() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 70})
	var tr := s.present()
	assert_eq([int(tr["n"]), int(tr["snr"]), int(tr["babble_db"]), int(tr["db"])], [1, 25, 45, 70])
	assert_eq([tr["list_id"], tr["slot"], tr["item_id"]], ["party_1", "both", "p1_1"])
	assert_false(bool(tr["practice"]) or bool(tr["locked"]) or bool(tr["by_hoot"]))
	assert_true(s.awaiting_score, "waiting for LOCK IN")
	# PRESENT is refused before LOCK IN, with the tip once per list
	assert_eq(s.present(), {})
	assert_eq(s.present(), {})
	assert_eq(_named(ev, &"lock_first").size(), 1)
	var m := s.mode
	var marks: Array = tr["marks"]
	# the walk
	s.score(true)
	assert_eq(_bools(marks), [true, null, null, null, null])
	s.score(false)
	assert_eq(_bools(marks), [true, false, null, null, null])
	assert_eq(int(m.state()["focus_key"]), 2)
	# the jump: 1-5 flip (blank or missed -> got, got -> missed) and move the highlight there
	m.act(&"flip_key", {"key": 1})
	assert_eq(_bools(marks), [false, false, null, null, null])
	assert_eq(int(m.state()["focus_key"]), 0)
	m.act(&"flip_key", {"key": 2})
	assert_eq(marks[1], true, "missed -> got")
	m.act(&"flip_key", {"key": 4})
	assert_eq(marks[3], true, "blank -> got")
	assert_eq(int(m.state()["focus_key"]), 3)
	# a right-click marks missed and moves on as the walk does
	m.act(&"mark_key", {"key": 4, "got": false})
	assert_eq(marks[3], false)
	assert_eq(int(m.state()["focus_key"]), 4, "the next blank after chip 4")
	m.act(&"focus_key", {"key": 3})
	assert_eq(int(m.state()["focus_key"]), 2, "a highlight move marks nothing")
	assert_eq(marks[2], null)
	assert_eq(m.act(&"flip_key", {"key": 0}), {}, "keys are 1-5")
	assert_eq(m.act(&"flip_key", {"key": 6}), {})
	# ALL GOT
	m.act(&"all_got")
	assert_eq(_bools(marks), [true, true, true, true, true])
	assert_eq(int(m.state()["focus_key"]), -1)
	assert_eq(s.score(true), {}, "nothing left to walk")
	# LOCK IN
	var locked := s.store()
	assert_true(bool(locked["locked"]) and not bool(locked["list_done"]))
	assert_eq(int(locked["count_billed"]), 5)
	assert_false(s.awaiting_score)
	assert_eq(s.score(false), {}, "marks cannot change after LOCK IN")
	assert_eq(m.act(&"flip_key", {"key": 1}), {})
	assert_eq(m.act(&"all_got"), {})
	assert_eq(s.store(), {}, "locked once")
	assert_eq(_bools(marks), [true, true, true, true, true])
	assert_eq(int(m.state()["courses"][0]["count"]), 5, "the plate")
	assert_eq(int(m.state()["total_so_far"]), 5)
	# the next sentence, one SNR step down
	var tr2 := s.present()
	assert_eq([int(tr2["n"]), int(tr2["snr"]), int(tr2["babble_db"])], [2, 20, 50])
	assert_eq(m.state()["course"], "Soup")


func test_blanks_lock_as_missed() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 70})
	var tr := s.present()
	s.score(true)
	var r := s.store()
	assert_eq(_bools(tr["marks"]), [true, false, false, false, false], "blanks flip to crosses")
	assert_eq(int(r["count_billed"]), 1)
	assert_eq(_named(ev, &"blanks").size(), 1)
	s.present()
	s.store()
	assert_eq(_named(ev, &"blanks").size(), 1, "once per visit")


## The walk's highlight: the next blank chip after the one just marked, wrapping, or none.
func test_the_walk_wraps() -> void:
	assert_eq(SinTest._next_blank([true, null, true, null, null], 3), 4)
	assert_eq(SinTest._next_blank([true, null, true, null, false], 3), 1, "wrapping")
	assert_eq(SinTest._next_blank([true, true, true, true, null], 4), 4, "the chip itself comes last")
	assert_eq(SinTest._next_blank([true, true, false, true, true], 1), -1, "none blank")
	var s := _visit()
	_start(s, {"list": "party_1", "level": 70})
	s.present()
	var m := s.mode
	m.act(&"flip_key", {"key": 3})
	m.act(&"flip_key", {"key": 5})
	m.act(&"focus_key", {"key": 4})
	s.score(true)
	assert_eq(int(m.state()["focus_key"]), 0, "after chip 4: chip 5 is marked, so chip 1")


## Every chip is checked at LOCK IN against what he said, with the line for what went wrong.
func test_per_chip_checks_and_lines() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 70})
	var tr := s.present()
	# what he said, made exact for the test: one word right, a sound-alike, a trap, a filler, nothing
	tr["heard"] = [true, false, false, false, false]
	tr["said_words"] = ["sleepy", "coat", "chews", "something", ""]
	tr["said_kinds"] = [&"heard", &"mishear", &"trap", &"filler", &"drop"]
	var checks := s.checks
	s.mode.act(&"all_got")
	s.store()
	assert_eq(s.checks - checks, 5, "one check per chip")
	var wrong := _named(ev, &"misscored")
	assert_eq(wrong.size(), 4, "every ticked miss")
	assert_eq(_named(ev, &"speech_textbook").size(), 1)
	assert_eq(_named(ev, &"sin_lock_ok").size(), 0)
	var want := [
		s.say(SinTest.misscored_line("goat", "coat", &"mishear", true)),
		s.say(SinTest.misscored_line("chewed", "chews", &"trap", true)),
		s.say(SinTest.misscored_line("paper", "something", &"filler", true)),
		s.say(SinTest.misscored_line("crown", "", &"drop", true)),
	]
	for i in 4:
		assert_eq(wrong[i]["message"], want[i])
		assert_eq(int(wrong[i]["key"]), i + 2)
		assert_eq(wrong[i]["marked"], true)
		assert_eq(int(wrong[i]["sentence_n"]), 1, "the sentence just locked")
		assert_eq([wrong[i]["ear"], wrong[i]["slot"], wrong[i]["test"], wrong[i]["condition"], wrong[i]["list_id"]],
			["both", "both", "sin", "unaided", "party_1"])
	assert_eq(want[0], "He said 'coat'. Close isn't correct!")
	assert_eq(want[1], "'chews' isn't 'chewed'. Word endings must match, plurals and tenses too.")
	assert_eq(want[2], "He didn't say 'paper'. Untick it: only exact words count.")
	assert_eq(want[3], "He didn't say 'crown'. Untick it: only exact words count.")
	assert_eq(s.errors.size(), 4)
	for e: Dictionary in s.errors:
		assert_eq([e["kind"], e["slot"], e["said_kind"] != &"heard", e["scored"]], ["misscored", "both", true, true])
	assert_eq(s.combo, 0, "a slip breaks the combo")
	# a heard word left unticked
	var tr2 := s.present()
	tr2["heard"] = [true, true, true, true, true]
	s.mode.act(&"all_got")
	s.mode.act(&"flip_key", {"key": 3})
	s.store()
	var last: Dictionary = _named(ev, &"misscored").back()
	assert_eq(last["message"], s.say(SinTest.misscored_line(String(tr2["key_words"][2]), "", &"heard", false)))
	assert_true(String(last["message"]).ends_with("! Tick it."))
	# all five right: a clean LOCK IN
	var tr3 := s.present()
	for i in 5:
		s.score(bool(tr3["heard"][i]))
	var before := _named(ev, &"sin_lock_ok").size()
	s.store()
	assert_eq(_named(ev, &"sin_lock_ok").size(), before + 1)


func test_the_coach_fixes_wrong_marks() -> void:
	var s := _visit()
	_start(s, {"list": "party_1", "level": 50})
	assert_eq(s.recommended_action(), {"action": &"louder", "target_db": 70})
	for i in 4:
		s.step_level(1)
	assert_eq(s.recommended_action()["action"], &"present")
	var tr := s.present()
	var heard: Array = tr["heard"]
	# chip 3 marked the wrong way
	s.mode.act(&"mark_key", {"key": 3, "got": not bool(heard[2])})
	var rec := s.recommended_action()
	assert_eq([rec["action"], int(rec["key"])], [&"key_fix", 3], "the first wrong chip")
	s.mode.do(&"key_fix", rec)
	assert_eq(tr["marks"][2], heard[2], "one flip fixes it")
	# then the walk from the highlight, from the truth
	rec = s.recommended_action()
	assert_eq(rec["action"], &"key_got" if bool(heard[2]) else &"key_missed")
	for step in 8:
		rec = s.recommended_action()
		if rec["action"] == &"lock":
			break
		s.mode.do(StringName(rec["action"]), rec)
	assert_eq(s.recommended_action()["action"], &"lock")
	assert_eq(_bools(tr["marks"]), _bools(heard), "every chip as he said")
	var r: Dictionary = s.mode.do(&"lock", {})
	assert_true(bool(r["locked"]))


# ---------------------------------------------------------------- the talker level

func test_the_players_level_is_checked() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 50}, "both", true)
	assert_true(s.set_level(70))
	s.present()
	var good := _named(ev, &"sin_good_level")
	assert_eq(good.size(), 1)
	assert_eq([int(good[0]["target"]), int(good[0]["got"])], [70, 70])
	assert_near(float(good[0]["pta"]), 21.67, 0.01)
	assert_eq(good[0]["message"], "Talker at 70: just right. The party steps up by itself.")
	assert_eq(s.points, SinTest.POINTS[&"sin_good_level"], "a clean check's points")
	# one level per list
	assert_false(s.mode.can_set_level())
	assert_false(s.set_level(75))
	assert_false(s.step_level(-1))
	assert_eq(_named(ev, &"sin_level_locked").size(), 1, "said once per list")
	assert_true(bool(s.get_state()["sin"]["level_locked"]))
	# a talker off the target
	var w := _visit()
	var wev := _events(w)
	_start(w, {"list": "party_1", "level": 65})
	w.present()
	var bad := _named(wev, &"sin_level")
	assert_eq(bad.size(), 1)
	assert_eq([int(bad[0]["target"]), int(bad[0]["got"])], [70, 65])
	assert_eq(bad[0]["message"], "Party test: talker at 70 dB HL. The party levels follow by themselves.")
	assert_eq(w.errors[0]["kind"], "sin_level")
	assert_eq(_named(wev, &"sin_good_level").size(), 0)
	# a per-ear unaided test: the ear's own slot and PTA
	var e := _visit()
	_start(e, {"list": "party_1"}, "right")
	assert_eq(e.slot, "right")
	assert_eq(e.db, 20, "snap5 of his right PTA")
	assert_eq(e.recommended_action(), {"action": &"louder", "target_db": SpeechRules.sin_level(e.pta_for("right"))})


## The practice: Hoot plays it at the player's level, never scores, stores or plates it; the level
## locks there and the player's first sentence checks it.
func test_the_practice() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 50, "practice": "party_practice"}, "both", true)
	assert_eq(String(s.next_item()["id"]), "pp_1", "the practice comes first")
	var view: Dictionary = s.get_state()["sin"]
	assert_true(bool(view["practice_pending"]))
	assert_eq([int(view["sentence_n"]), view["course"]], [0, "Practice"])
	assert_eq(int(s.get_state()["words_left"]), 6, "not one of the six")
	assert_eq(s.recommended_action()["action"], &"louder", "the coach sets the talker before the practice")
	for i in 4:
		s.step_level(1)
	assert_eq(s.recommended_action()["action"], &"present")
	# Hoot's practice turn (scoring off)
	s.scoring = false
	var checks := s.checks
	var pr := s.present()
	assert_true(bool(pr["practice"]) and bool(pr["by_hoot"]))
	assert_eq([int(pr["n"]), int(pr["snr"])], [0, SpeechRules.SIN_PRACTICE_SNR])
	assert_true(s.trials_for().is_empty() and ((s.trials[&"sin"] as Dictionary)["both"] as Array).is_empty(), "not a trial of the list")
	assert_false(s.mode.can_set_level(), "the level locks at the practice")
	var r := _lock_as_coached(s)
	assert_true(bool(r["practice"]) and not bool(r["list_done"]))
	assert_eq(_named(ev, &"practice_done").size(), 1)
	assert_eq(s.checks, checks, "never scored")
	assert_eq(_named(ev, &"sin_good_level").size(), 0, "not yet: Hoot played it")
	assert_false(bool(s.get_state()["sin"]["practice_pending"]))
	# the player's first sentence checks the level the player set
	s.scoring = true
	var tr := s.present()
	assert_eq([int(tr["n"]), int(tr["snr"])], [1, 25])
	assert_eq(_named(ev, &"sin_good_level").size(), 1)
	_play(s)
	var sheet: Dictionary = (s.sheets[&"sin"] as Dictionary)["both"]
	var sentences: Array = sheet["lists"][0]["sentences"]
	assert_eq(sentences.size(), 6, "the practice is never stored")
	for x: Dictionary in sentences:
		assert_ne(x["item_id"], "pp_1")
	assert_eq(int(sheet["lists"][0]["player_sentences"]), 6)
	# a practice Hoot plays at the level the player left: he never moves it
	var w := _visit()
	var wev := _events(w)
	_start(w, {"list": "party_1", "level": 50, "practice": "party_practice"}, "both", true)
	w.scoring = false
	assert_eq(w.recommended_action()["action"], &"present", "Hoot leaves the player's dial alone")
	w.present()
	assert_eq(w.db, 50)
	_lock_as_coached(w)
	assert_false(w.mode.is_done())
	w.scoring = true
	w.present()
	assert_eq(_named(wev, &"sin_level").size(), 1, "the player's level, checked at the player's first sentence")


## hoot_first with level_first (Day 5's second list on a quick visit): the player sets the talker,
## Hoot pours courses 1-3 unscored at that level, the player scores 4-6; Hoot's sentences are billed
## by the truth.
func test_hoot_first_and_level_first() -> void:
	var s := _visit(5)
	var ev := _events(s)
	_start(s, {"list": "party_2", "level_first": true, "hoot_first": 3})
	assert_eq(s.db, 20, "the dial at snap5(PTA)")
	while s.db < 70:
		s.step_level(1)
	s.scoring = false
	for n in 3:
		assert_eq(s.recommended_action()["action"], &"present")
		var tr := s.present()
		assert_true(bool(tr["by_hoot"]))
		# a wrong mark from Hoot's hand is billed by the truth anyway
		s.mode.act(&"all_got")
		s.store()
		assert_eq(_bools(tr["marks"]), _bools(tr["heard"]), "Hoot's sentences: the truth")
	assert_eq(s.checks, 0, "nothing of Hoot's is scored")
	assert_true(s.errors.is_empty())
	s.scoring = true
	_play(s)
	assert_eq(_named(ev, &"sin_good_level").size(), 1, "the player's level")
	var l: Dictionary = (s.sheets[&"sin"] as Dictionary)["both"]["lists"][0]
	assert_eq([int(l["player_sentences"]), int(l["hoot_sentences"])], [3, 3])
	assert_eq(int(l["tee_bonus"]), SpeechRules.LIST_TEE_BONUS, "set unprompted at the textbook level")
	assert_eq(l["golf"], &"birdie", "a clean solo list: the day's birdie")
	assert_eq([int(l["golf_par"]), int(l["golf_strokes"])], [3, 1])
	var total := 0
	for x: Dictionary in l["sentences"]:
		total += int(x["count"])
		assert_eq(int(x["count"]), SinTest._billed(x["marks"]))
	assert_eq(int(l["total"]), total)
	# the player leaves the talker at 65: Hoot pours at 65, and the slip is the player's
	var w := _visit(5)
	var wev := _events(w)
	_start(w, {"list": "party_2", "level_first": true, "hoot_first": 3})
	while w.db < 65:
		w.step_level(1)
	w.scoring = false
	for n in 3:
		assert_eq(w.recommended_action()["action"], &"present", "Hoot never moves the player's level")
		w.present()
		_lock_as_coached(w)
	w.scoring = true
	_play(w)
	assert_eq(_named(wev, &"sin_level").size(), 1)
	assert_eq(int(_named(wev, &"sin_level")[0]["got"]), 65)
	var wl: Dictionary = (w.sheets[&"sin"] as Dictionary)["both"]["lists"][0]
	assert_eq([int(wl["level_db"]), int(wl["tee_bonus"])], [65, 0])
	assert_eq(wl["golf"], &"par")


## Aided lists: the sound field at SIN_AIDED_DB, set by Hoot and locked from the start; no level
## check, no tee bonus, no band and no remedy (D21).
func test_level_by_hoot_on_aided_lists() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_3", "condition": "omni", "programme": "A"})
	assert_eq(s.db, SpeechRules.SIN_AIDED_DB)
	assert_false(s.mode.can_set_level(), "locked from the start")
	assert_false(s.set_level(55))
	assert_false(s.set_level(60))
	var aided := _named(ev, &"sin_aided_level")
	assert_eq(aided.size(), 1)
	assert_eq(aided[0]["message"], "Aided tests go at a chatting level: 50. The aids add their own boost.")
	assert_eq(aided[0]["ear"], "aided_omni", "the slot is the event's ear")
	var view: Dictionary = s.get_state()["sin"]
	assert_true(bool(view["level_by_hoot"]) and bool(view["level_locked"]))
	assert_eq(s.recommended_action()["action"], &"present")
	var sheet := _play(s)
	assert_eq(_named(ev, &"sin_good_level").size() + _named(ev, &"sin_level").size(), 0, "no level check")
	assert_eq(int(sheet["level_db"]), 50)
	assert_eq([sheet["band"], sheet["band_name"], sheet["remedy"], sheet["true_band"]], [&"", "", "", &""])
	assert_eq(sheet["label"], "aided, sound field")
	assert_true(bool(sheet["aided"]))
	assert_eq(sheet["transducer"], "soundfield")
	var l: Dictionary = sheet["lists"][0]
	assert_true(bool(l["level_by_hoot"]))
	assert_eq(int(l["tee_bonus"]), 0)
	assert_eq(l["golf"], &"par", "a clean list whose level Hoot set tops out at par")
	assert_eq(int(sheet["forks"]), 3)
	assert_eq(String(s.get_state()["sin"]["band"]), "", "no band on screen either")


# ---------------------------------------------------------------- sheets, units, results

func test_unaided_sheet_and_units() -> void:
	var s := _visit(7)
	var stored: Array = []
	s.stored.connect(func(e: String, t: StringName, sh: Dictionary) -> void: stored.append([e, t, sh["slot"]]))
	_start(s, {"list": "party_1", "level": 50, "practice": "party_practice", "hide_loss": true}, "both", true)
	_play(s)
	_start(s, {"list": "party_2", "level_first": true})
	var sheet := _play(s, {5: [0]})
	assert_eq(stored, [["both", &"sin", "both"], ["both", &"sin", "both"]], "one sheet per slot, sent after each list")
	for k: String in SHEET_KEYS:
		assert_true(sheet.has(k), "sheet key %s" % k)
	assert_eq([sheet["ear"], sheet["slot"], sheet["test"], sheet["condition"]], ["both", "both", "sin", "unaided"])
	assert_eq(int(sheet["lists_done"]), 2)
	var losses: Array = []
	for l: Dictionary in sheet["lists"]:
		for k: String in LIST_KEYS:
			assert_true(l.has(k), "list key %s" % k)
		var total := 0
		for x: Dictionary in l["sentences"]:
			for k: String in SENTENCE_KEYS:
				assert_true(x.has(k), "sentence key %s" % k)
			total += SinTest._billed(x["marks"])
		assert_eq(int(l["total"]), total, "the bill is the ticked chips")
		assert_eq(float(l["snr_loss"]), SpeechRules.snr_loss(total))
		losses.append(float(l["snr_loss"]))
	assert_eq(float(sheet["snr_loss"]), SpeechRules.sin_average(losses), "two lists averaged")
	assert_eq(int(sheet["stored_db"]), roundi(float(sheet["snr_loss"])))
	assert_eq(float(sheet["true_loss"]), 9.0)
	assert_eq(int(sheet["true_db"]), 9)
	assert_eq(sheet["band"], SpeechRules.sin_band(float(sheet["snr_loss"])))
	assert_eq(sheet["band_name"], SpeechRules.SIN_BAND_NAMES[sheet["band"]])
	assert_eq(sheet["remedy"], SpeechRules.SIN_REMEDIES[sheet["band"]])
	assert_near(float(sheet["estimated_loss"]), 2.8, 0.001, "the better ear's rough estimate, for tests only")
	assert_eq([int(sheet["units"]), int(sheet["strokes"]), int(sheet["par"])], [2, 12, 12], "two player lists")
	assert_eq([int(sheet["key_words"]), int(sheet["misscored"])], [60, 1])
	assert_near(float(sheet["accuracy"]), 59.0 / 60.0, 0.0001)
	assert_eq(int(sheet["forks"]), SpeechRules.sin_forks(1))
	assert_false(bool(sheet["clean"]))
	assert_eq(sheet["errors"], [&"misscored"] as Array)
	assert_true(bool(sheet["coached"]), "list 1 was coached")
	assert_false(bool(sheet["by_hoot"]))
	assert_eq(int(sheet["seq"]), int(sheet["lists"][0]["seq"]))
	assert_true(int(sheet["lists"][1]["seq"]) > int(sheet["lists"][0]["seq"]))
	assert_eq(sheet["holes"], [{"list_id": "party_1", "golf": &"par"}, {"list_id": "party_2", "golf": &"par"}],
		"coached list 1 tops out at par; list 2's slip costs the birdie")
	assert_eq(sheet["golf"], &"par", "the newest player list's")
	# the visit's results: units weigh SHEET_WEIGHT tone stamps
	var res := s.build_results()
	assert_eq(res["tests"], ["sin"] as Array[String])
	assert_eq(int(res["scored_sheets"]), 2)
	assert_near(float(res["accuracy"]), 59.0 / 60.0, 0.0001)
	assert_near(float(res["efficiency"]), 1.0, 0.0001, "fixed lists: efficiency 1.0")
	assert_true(res.has("sin_summary"))
	var tones := {"ears": {"right": {"freqs": {1000: {"by_hoot": false}, 2000: {"by_hoot": false}}}}, "accuracy": 0.5,
		"technique": 0.5, "efficiency": 0.5}
	var merged := SpeechSession.merge_results(tones, res)
	var ns := 2.0 * SpeechSession.SHEET_WEIGHT
	assert_near(float(merged["accuracy"]), (0.5 * 2.0 + float(res["accuracy"]) * ns) / (2.0 + ns), 0.0001)


func test_hoot_lists_count_no_units() -> void:
	var s := _visit()
	_start(s, {"list": "party_3", "condition": "omni"})
	_play(s, {})
	s.configure({"test": "sin", "tones": s.tone_results, "list": "party_4", "condition": "omni", "hoot_only": true})
	var sheet := s.run_by_textbook("both")
	assert_eq(int(sheet["lists_done"]), 2)
	assert_eq(int(sheet["units"]), 1, "Hoot's list adds no unit")
	assert_eq([int(sheet["strokes"]), int(sheet["par"])], [6, 6], "only the player's sentences")
	assert_eq(sheet["holes"][1], {"list_id": "party_4", "golf": &"hoot"})
	assert_eq(sheet["golf"], sheet["lists"][0]["golf"], "the newest PLAYER list's golf")
	assert_true(bool(sheet["lists"][1]["by_hoot"]))
	assert_eq(int(s.build_results()["scored_sheets"]), 1)


# ---------------------------------------------------------------- party golf

func test_party_golf() -> void:
	# list 2, solo, the talker set unprompted at 70, clean: a birdie (and a chef's kiss)
	var s := _visit(9)
	var ev := _events(s)
	_start(s, {"list": "party_2", "level_first": true})
	s.set_level(70)
	var points := s.points
	var l: Dictionary = _play(s)["lists"][0]
	assert_eq([l["golf"], int(l["tee_bonus"]), int(l["golf_par"]), int(l["golf_strokes"])], [&"birdie", 2, 6, 4])
	assert_eq(_named(ev, &"birdie").size(), 1)
	assert_eq(_named(ev, &"chef_kiss").size(), 1)
	assert_eq(_named(ev, &"chef_kiss")[0]["message"], "Every key word scored as he said it. Chef's kiss!")
	assert_true(s.points - points >= SpeechSession.GOLF_POINTS[&"birdie"] + SinTest.POINTS[&"chef_kiss"], "golf and chef's kiss points")
	# one slip, even with the tee bonus: par
	assert_eq(_golf({"list": "party_2"}, false, {2: [1]}), &"par")
	# a set-up hint before the first sentence costs the tee bonus
	var p := _visit(9)
	_start(p, {"list": "party_2"})
	p.set_level(70)
	assert_eq(p.mode.act(&"prompt"), {"unprompted": false})
	var pl: Dictionary = _play(p)["lists"][0]
	assert_eq([pl["golf"], int(pl["tee_bonus"]), pl["unprompted"]], [&"par", 0, false])
	assert_eq(p.mode.act(&"prompt"), {}, "too late once the list has started")
	# coached lists and lists whose level Hoot set top out at par; slips without the tee bonus
	assert_eq(_golf({"list": "party_1"}, true, {}), &"par", "coached list 1")
	assert_eq(_golf({"list": "party_3", "condition": "omni"}, false, {}), &"par", "list 3")
	assert_eq(_golf({"list": "party_5", "condition": "directional"}, false, {}), &"par", "list 5")
	assert_eq(_golf({"list": "party_1"}, true, {3: [0]}), &"par", "one slip is still par")
	assert_eq(_golf({"list": "party_1"}, true, {3: [0, 1]}), &"bogey", "two")
	assert_eq(_golf({"list": "party_1"}, true, {3: [0, 1], 4: [2]}), &"bogey", "three")
	assert_eq(_golf({"list": "party_1"}, true, {3: [0, 1], 4: [2, 3]}), &"double_bogey", "four")
	assert_eq(_golf({"list": "party_1"}, true, {1: [0, 1, 2, 3, 4]}), &"double_bogey", "five")
	# a clean list never reads worse than par, a slip never better
	for g: StringName in [&"birdie", &"eagle", &"albatross"]:
		assert_ne(_golf({"list": "party_2"}, false, {6: [4]}), g)


## The golf of one player list at the textbook talker level (slips as in _play).
func _golf(plan: Dictionary, coached: bool, slips: Dictionary) -> StringName:
	var s := _visit(9)
	_start(s, plan, "both", coached)
	if s.mode.can_set_level():
		s.set_level(s.mode.textbook_target())
	return StringName(_play(s, slips)["lists"][0]["golf"])


# ---------------------------------------------------------------- the blind tasting: OMNI against FOCUS

func test_the_focus_benefit() -> void:
	var real_lines := 0
	for seed_value in range(1, 21):
		var s := _visit(seed_value)
		var ev := _events(s)
		var plans := _day5_plans(s.tone_results, true)
		for i in range(2, 6):
			s.configure(plans[i])
			var sh := s.run_by_textbook("both")
			if i == 4:
				# one list each so far: compared at the one-list critical difference, nothing said yet
				assert_eq(float(sh["crit_diff_db"]), SpeechRules.sin_crit_diff(1))
				assert_eq(_named(ev, &"sin_benefit").size(), 0)
		var omni: Dictionary = (s.sheets[&"sin"] as Dictionary)["aided_omni"]
		var focus: Dictionary = (s.sheets[&"sin"] as Dictionary)["aided_directional"]
		var benefit := float(omni["snr_loss"]) - float(focus["snr_loss"])
		assert_eq(float(focus["benefit_db"]), benefit)
		assert_eq(focus["compared_to"], "aided_omni")
		assert_eq(float(focus["crit_diff_db"]), 2.7)
		var real := benefit > 2.7
		assert_eq(bool(focus["real_change"]), real, "seed %d" % seed_value)
		var said := _named(ev, &"sin_benefit")
		assert_eq(said.size(), 1, "said once both have two lists")
		assert_eq(bool(said[0]["real"]), real)
		var key: StringName = &"real" if real else (&"small" if benefit > 0.0 else &"none")
		assert_eq(said[0]["message"], SinTest.BENEFIT_LINES[key].replace("{benefit}", "%.1f" % benefit).replace("{crit}", "2.7"))
		var sum: Dictionary = s.build_results()["sin_summary"]
		assert_eq(float(sum["benefit_db"]), benefit)
		assert_eq([bool(sum["real_change"]), bool(sum["benefit_unsure"])], [real, not real])
		assert_eq(float(sum["crit_diff_db"]), 2.7)
		if real:
			real_lines += 1
	assert_true(real_lines >= 15, "Marco's 4.0 dB is real in most visits (%d of 20)" % real_lines)
	# a big benefit is always real; none is never real
	for seed_value in range(1, 11):
		assert_true(_benefit_real(seed_value, 12.0), "12 dB, seed %d" % seed_value)
		assert_false(_benefit_real(seed_value, 0.0), "0 dB, seed %d" % seed_value)
	# a plan's own lines
	var o := _visit(2)
	var oev := _events(o)
	var plans := _day5_plans(o.tone_results, false)
	for i in range(2, 6):
		if i >= 4:
			plans[i]["benefit_lines"] = {"real": "Real: {benefit}.", "small": "Small: {benefit} under {crit}.", "none": "None."}
		o.configure(plans[i])
		o.run_by_textbook("both")
	assert_true(String(_named(oev, &"sin_benefit")[0]["message"]) in ["None."] \
		or String(_named(oev, &"sin_benefit")[0]["message"]).begins_with("Real: ") \
		or String(_named(oev, &"sin_benefit")[0]["message"]).begins_with("Small: "))


func _benefit_real(seed_value: int, benefit_db: float) -> bool:
	var s := _visit(seed_value, {"wrs_max": {"right": 96, "left": 92}, "snr_loss": 9.0, "directional_benefit": benefit_db})
	var plans := _day5_plans(s.tone_results, false)
	for i in range(2, 6):
		s.configure(plans[i])
		s.run_by_textbook("both")
	return bool((s.sheets[&"sin"] as Dictionary)["aided_directional"]["real_change"])


# ---------------------------------------------------------------- Hoot's off-screen lists (C23)

## run_by_textbook reaches a stored sheet for every Day 5 party plan of §9.21, with no screen, and the
## visit holds what the bot checks (§9.22).
func test_run_by_textbook_every_day5_plan() -> void:
	for quick: bool in [true, false]:
		for seed_value in range(1, 6):
			var s := _visit(seed_value)
			var plans := _day5_plans(s.tone_results, quick)
			for plan: Dictionary in plans:
				s.configure(plan)
				var sh := s.run_by_textbook("both")
				assert_false(sh.is_empty(), "%s: a stored sheet" % plan["list"])
				assert_true(bool(sh["by_hoot"]) and int(sh["units"]) == 0, "Hoot's work")
				assert_true(s.mode.is_done())
			assert_true(s.scoring, "scoring back on")
			assert_true(s.errors.is_empty() and s.points == 0 and s.checks == 0, "never scored")
			var sheets: Dictionary = s.sheets[&"sin"]
			assert_eq(sheets.keys(), ["both", "aided_omni", "aided_directional"])
			var ids: Array[String] = []
			for slot: String in sheets:
				var sh: Dictionary = sheets[slot]
				assert_eq(int(sh["lists_done"]), 2, slot)
				assert_true(absf(float(sh["snr_loss"]) - float(sh["true_loss"])) <= 3.0, "%s within 3 dB" % slot)
				assert_true(absi(int(sh["stored_db"]) - int(sh["true_db"])) <= 10, "the bot's 10 dB check")
				for l: Dictionary in sh["lists"]:
					ids.append(String(l["list_id"]))
					assert_eq((l["sentences"] as Array).size(), 6, "six sentences, no practice")
					var total := 0
					for x: Dictionary in l["sentences"]:
						total += SinTest._billed(x["marks"])
						assert_eq(_bools(x["marks"]), _bools(x["heard"]), "Hoot bills the truth")
					assert_eq(int(l["total"]), total)
					assert_eq(l["golf"], &"hoot")
			assert_eq(ids, SpeechRules.SIN_LISTS, "six distinct lists in play order")
			assert_eq(sheets["both"]["band"], &"moderate", "seed %d" % seed_value)
			for slot: String in ["aided_omni", "aided_directional"]:
				assert_eq([int(sheets[slot]["level_db"]), sheets[slot]["band"]], [SpeechRules.SIN_AIDED_DB, &""])
			assert_eq(s.used_lists, SpeechRules.SIN_LISTS)
			var sum: Dictionary = s.build_results()["sin_summary"]
			for k: String in ["unaided", "omni", "directional", "benefit_db", "crit_diff_db", "real_change", "benefit_unsure",
					"estimated_loss", "lists_used"]:
				assert_true(sum.has(k), "sin_summary key %s" % k)
			assert_eq(sum["unaided"]["band_name"], "Moderate")
			assert_eq(sum["unaided"]["remedy"], "+ directional mics")
			assert_eq(sum["lists_used"], SpeechRules.SIN_LISTS)
			assert_false((sum["omni"] as Dictionary).has("band"), "aided: compared, never banded")


## A whole Day 5 visit on one session, as the level's run_hidden and start_test calls make it (§9.21):
## Hoot's SRTs and word lists off-screen, right first, then the six party lists. The word lists reach a
## sheet once Day 4's WRS mode is in; until then they are refused (mode_missing) and the day goes on.
func test_a_whole_day5_visit_on_one_session() -> void:
	var wrs_in := ResourceLoader.exists(SpeechTestMode.script_path(&"wrs"))
	for quick: bool in [true, false]:
		var s := _visit(2)
		var t := s.tone_results
		for e: String in ["right", "left"]:
			s.configure({"test": "srt", "tones": t})
			var srt := s.run_by_textbook(e)
			assert_false(srt.is_empty(), "Hoot's SRT, %s" % e)
			assert_true(bool(srt["by_hoot"]) and s.mode == null, "the SRT has no mode")
		for pair: Array in [["right", "words_1"], ["left", "words_2"]]:
			s.configure({"test": "wrs", "tones": t, "list": pair[1]})
			var w := s.run_by_textbook(String(pair[0]))
			if wrs_in:
				assert_false(w.is_empty(), "Hoot's word list, %s" % pair[0])
			else:
				assert_true(w.is_empty() and s.mode_missing, "no WRS mode yet: nothing to run")
		for plan: Dictionary in _day5_plans(t, quick):
			s.configure(plan)
			assert_false(s.run_by_textbook("both").is_empty(), "%s after the montage" % plan["list"])
		assert_eq((s.sheets[&"srt"] as Dictionary).keys(), ["right", "left"], "the SRT sheets stay")
		assert_eq((s.sheets[&"sin"] as Dictionary).keys(), ["both", "aided_omni", "aided_directional"])
		var res := s.build_results()
		var want: Array[String] = ["srt", "sin"]
		if wrs_in:
			want.insert(1, "wrs")
		assert_eq(res["tests"], want)
		assert_eq(int(res["scored_sheets"]), 0, "all of it Hoot's")
		assert_eq(res["sin_summary"]["unaided"]["band"], &"moderate")
		assert_eq(res["sin_summary"]["lists_used"], SpeechRules.SIN_LISTS)


func test_a_list_is_used_once() -> void:
	var s := _visit()
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 70})
	_play(s)
	_start(s, {"list": "party_1", "level": 70})
	assert_eq(s.present(), {}, "refused")
	assert_eq(s.present(), {})
	assert_eq(_named(ev, &"sin_list_reused").size(), 1, "once per list")
	assert_eq(s.recommended_action()["action"], &"none")
	assert_false(s.mode.can_set_level())
	s.configure({"test": "sin", "tones": s.tone_results, "list": "party_1"})
	assert_eq(s.run_by_textbook("both"), {}, "nothing to run")
	assert_eq(int((s.sheets[&"sin"] as Dictionary)["both"]["lists_done"]), 1, "the sheet keeps its one list")


# ---------------------------------------------------------------- once-per-visit moments

func test_moments_once_per_visit() -> void:
	var s := _visit(4)
	var ev := _events(s)
	# Hoot's list first: his zero-gap sentence and swaps say nothing
	s.configure({"test": "sin", "tones": s.tone_results, "list": "party_3", "condition": "omni"})
	s.run_by_textbook("both")
	assert_eq(_named(ev, &"noise_won").size() + _named(ev, &"little_words").size(), 0, "only the player's sentences")
	var swaps: Array = []
	for list_id: String in ["party_1", "party_2"]:
		_start(s, {"list": list_id, "level": 70})
		for n in 6:
			var tr := s.present()
			if bool(tr["little_swap"]):
				swaps.append([list_id, int(tr["n"])])
				if swaps.size() == 1:
					assert_eq(_named(ev, &"little_words").size(), 1, "the first swap brings the tip")
			if int(tr["snr"]) == 0 and list_id == "party_1":
				assert_eq(_named(ev, &"noise_won").size(), 1, "the first zero gap")
			s.mode.act(&"all_got")
			s.store()
	assert_eq(_named(ev, &"little_words").size(), mini(1, swaps.size()), "once per visit")
	assert_eq(_named(ev, &"noise_won").size(), 1, "once per visit")
	assert_eq(_named(ev, &"noise_won")[0]["message"], "Zero gap: the party is as loud as the talker. Score what he said.")


func test_hidden_loss() -> void:
	var s := _visit(6)
	var ev := _events(s)
	_start(s, {"list": "party_1", "level": 70, "hide_loss": true})
	_play(s)
	var view: Dictionary = s.get_state()["sin"]
	assert_eq([float(view["avg_loss"]), view["band"], bool(view["loss_hidden"])], [-1.0, &"", true])
	assert_eq(float(view["lists"][0]["snr_loss"]), -1.0, "the bill reveals it")
	var done: Dictionary = _named(ev, &"sin_done")[0]
	var sheet: Dictionary = (s.sheets[&"sin"] as Dictionary)["both"]
	assert_eq(done["message"], "List done: %d key words." % int(sheet["lists"][0]["total"]))
	assert_eq([float(done["snr_loss"]), done["band"]], [-1.0, &""])
	assert_true(float(sheet["snr_loss"]) >= 0.0 and sheet["band"] != &"", "the sheet keeps the numbers")
	# the next list shows them
	_start(s, {"list": "party_2", "level": 70})
	view = s.get_state()["sin"]
	assert_eq(float(view["lists"][0]["snr_loss"]), float(sheet["snr_loss"]))
	assert_eq(float(view["avg_loss"]), float(sheet["snr_loss"]))
	assert_eq(view["band"], sheet["band"])
	_play(s)
	var shown: Dictionary = _named(ev, &"sin_done")[1]
	var l2: Dictionary = (s.sheets[&"sin"] as Dictionary)["both"]["lists"][1]
	assert_eq(shown["message"], "List done: %d key words. SNR loss %.1f dB." % [int(l2["total"]), float(l2["snr_loss"])])


# ---------------------------------------------------------------- summary, per ear

func test_summary_per_ear() -> void:
	var s := _visit(8, {"wrs_max": {"right": 96, "left": 92}, "snr_loss": {"right": 4.0, "left": 12.0}})
	_start(s, {"list": "party_1"}, "right")
	s.set_level(s.mode.textbook_target())
	_play(s)
	_start(s, {"list": "party_2"}, "left")
	s.set_level(s.mode.textbook_target())
	_play(s)
	var sheets: Dictionary = s.sheets[&"sin"]
	assert_eq(sheets.keys(), ["right", "left"])
	assert_eq(float(sheets["right"]["true_loss"]), 4.0, "each ear its own loss")
	assert_eq(float(sheets["left"]["true_loss"]), 12.0)
	var sum: Dictionary = s.build_results()["sin_summary"]
	assert_eq((sum["ears"] as Dictionary).keys(), ["right", "left"])
	assert_eq(sum["unaided"]["slot"], "right", "the better ear stands for the patient")
	assert_false(sum.has("omni") or sum.has("benefit_db"), "missing conditions are left out")
	assert_eq(sum["lists_used"], ["party_1", "party_2"] as Array[String])


# ---------------------------------------------------------------- lines

func test_lines_fit_and_name_keys() -> void:
	var longest_said := "something"
	var longest_word := ""
	for list_id: String in SpeechRules.SIN_LISTS:
		for it: Dictionary in SpeechMaterial.items(list_id):
			for w: Variant in it["key_words"]:
				if String(w).length() > longest_word.length():
					longest_word = String(w)
			for g: Variant in it.get("mishears", []):
				for w: Variant in g:
					if String(w).length() > longest_said.length():
						longest_said = String(w)
	var lines: Array[String] = []
	for d: Dictionary in [SinTest.TIPS, SinTest.MISSCORED_SIN, SinTest.BENEFIT_LINES, SinTest.COACH_LINES]:
		for k: Variant in d:
			lines.append(String(d[k]))
	var tokens := {"target": "90", "aided": "50", "total": "30", "loss": "-24.5", "benefit": "-25.5", "crit": "3.9",
		"said": longest_said, "word": longest_word}
	for style: String in Game.KEY_STYLES:
		Game.set_key_style(style)
		for line: String in lines:
			for bad: String in ["Space", "Enter", "arrow", "[S]", "[G]", "press S", "press G"]:
				assert_false(line.contains(bad), "keys only as {key:...}: %s" % line)
			var t := line
			for k: String in tokens:
				t = t.replace("{%s}" % k, String(tokens[k]))
			var at := t.find("{key:")
			while at >= 0:
				var end := t.find("}", at)
				var action := t.substr(at + 5, end - at - 5)
				assert_true(InputMap.has_action(action), "a real input: %s" % action)
				t = t.substr(0, at) + "[%s]" % Game.key_label(StringName(action)) + t.substr(end + 1)
				at = t.find("{key:")
			for who: String in ["he", "she", "they"]:
				var filled := PatientProfile.pronouns(t, who)
				assert_false(filled.contains("{"), "every token filled: %s" % filled)
				assert_true(filled.split(" ", false).size() <= Hoot.MAX_WORDS, "%d words: %s" % [filled.split(" ", false).size(), filled])
			var low := line.to_lower()
			for w: String in NO_DIAGNOSIS:
				assert_false(low.contains(w), "no diagnosis: %s" % line)
	assert_true(SinTest.MISSCORED_SIN[&"trap"].contains("endings"), "a trap is any changed ending (smell for smelly too)")


## Freeing a session frees its party mode; a new list frees the old one (WeakRef, no cycle).
func test_the_mode_is_freed_with_its_session() -> void:
	var refs := _orphan_mode()
	assert_true((refs[0] as WeakRef).get_ref() == null, "the session is gone")
	assert_true((refs[1] as WeakRef).get_ref() == null, "and its mode")
	var s := _visit()
	_start(s, {"list": "party_1", "level": 70})
	var old: WeakRef = weakref(s.mode)
	_start(s, {"list": "party_2", "level": 70})
	assert_true(old.get_ref() == null, "a fresh mode per list")


static func _orphan_mode() -> Array:
	var s := _visit()
	_start(s, {"list": "party_1", "level": 70})
	s.present()
	return [weakref(s), weakref(s.mode)]
