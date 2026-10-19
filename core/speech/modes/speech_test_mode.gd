class_name SpeechTestMode
extends RefCounted
## SpeechTestMode: the base of a speech test that is not the SRT (CONTRACTS.md §9.10.3). Day 4's word
## lists (WrsTest, core/speech/modes/wrs_test.gd) and Day 5's Party Noise Test (SinTest,
## core/speech/modes/sin_test.gd) each extend it in their own file, so SpeechSession never names a
## Day 4 or Day 5 class and Day 3's SRT stays on its old path: test "srt" has no mode at all.
##
## SpeechSession makes a fresh mode on every configure() (make(), by path) and hands it every seam
## (C1-C24, §9.10.4): items, present / score / store, the coach's move, the state, the tips and the
## results summary. A mode holds its session through a WeakRef (no reference cycle) and reports
## through the session's public helpers (clean, fail, observe, observe_once, emit_kind, data, say),
## so combo, points, checks and `technique` work exactly as for the SRT.
##
## Every method here is a safe no-op ({}, [], false, -1, ""), except where a comment says otherwise:
## the level and the noise stay free (can_set_level, can_mask) and the noise level follows the SRT
## rule (mask_level) until a mode says otherwise.

## The test's script, by test id. "srt" has none: the SRT is SpeechSession's own code.
const PATHS: Dictionary[StringName, String] = {
	&"wrs": "res://core/speech/modes/wrs_test.gd", &"sin": "res://core/speech/modes/sin_test.gd"}

## Tests point a test id at another script here, read before PATHS ("" = no script): probes, or
## a path to nowhere for the missing-mode path. Empty in the game.
static var path_override: Dictionary = {}

var _session: WeakRef
## The test this mode was made for (make() sets it; test_id() reads it).
var _made_for: StringName = &""


## A new mode of test `t` for session `s`: null for the SRT, or while the script is missing (the
## session then sets mode_missing).
static func make(s: SpeechSession, t: StringName) -> SpeechTestMode:
	if t == &"srt":
		return null
	var path := script_path(t)
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		return null
	var m := script.new(s) as SpeechTestMode
	if m != null:
		m._made_for = t
	return m


## Where test `t`'s mode script is ("" = none).
static func script_path(t: StringName) -> String:
	if path_override.has(t):
		return String(path_override[t])
	return String(PATHS.get(t, ""))


## Keep _init side-effect free: build_results() also makes a throwaway mode for summarize().
func _init(s: SpeechSession) -> void:
	_session = weakref(s)


## The session this mode belongs to, or null once it is gone.
func session() -> SpeechSession:
	return _session.get_ref() as SpeechSession


# ---------------------------------------------------------------- identity and lifecycle

## &"wrs" / &"sin": the test make() made this mode for (else the session's test).
func test_id() -> StringName:
	if _made_for != &"":
		return _made_for
	var s := session()
	return s.test if s != null else &""


## Called at the end of the session's configure(plan), after the common keys (test, list,
## transducer, tones) are read. The base items are not loaded for a mode: the mode owns its list.
func configure(_plan: Dictionary) -> void:
	pass


## The sheet slot for a test ear: the ear (WRS), or "both" / "aided_omni" / "aided_directional" (SIN).
func slot_for(ear: String) -> String:
	return ear


## Called at the end of the session's begin(): the slot, the dial (start_level()) and the noise are
## set; pick the first item here.
func begin(_ear: String, _coached: bool) -> void:
	pass


## The dial at begin: the plan's level, else the mode's default (the base: the PTA rounded to 5,
## as the SRT's begin does).
func start_level() -> int:
	var s := session()
	if s == null:
		return 40
	var p := s.pta_for(s.ear)
	return int(s.plan.get("level", SpeechRules.snap5(p) if not is_nan(p) else 40))


## The measurement's key (slips, once-per-measurement observations, Hoot's turn): "<test>:<slot>";
## a list-based mode adds the list ("wrs:<ear>:<list_id>").
func measure_key() -> String:
	var s := session()
	return "%s:%s" % [test_id(), s.slot if s != null else ""]


# ---------------------------------------------------------------- queries (what the player can see,
# except where a mode marks truth)

## The item the next present() will use ({} = none).
func next_item() -> Dictionary:
	return {}


## This list's trials (SpeechSession.trials_for() with no arguments).
func current_trials() -> Array:
	return []


## This list is finished (SpeechSession.is_done() with no arguments).
func is_done() -> bool:
	return false


## Items still to present in this list.
func words_left() -> int:
	return 0


## false once the list has started: SpeechSession.set_level() then refuses (on_level_refused()).
func can_set_level() -> bool:
	return true


## false when the noise may not change: SpeechSession.set_mask() then refuses (on_mask_refused()).
func can_mask() -> bool:
	return true


func masking_needed(_level: int) -> bool:
	return false


## The noise in the other ear (dB EM) at dial `level` while it is on (SpeechSession.mask_level()).
## The base is the SRT rule: level - 20 plus the other ear's largest air-bone gap.
func mask_level(level: int) -> int:
	var s := session()
	return SpeechRules.speech_mask_level(level, SpeechRules.nontest_largest_abg(s.tone_results, s.ear) if s != null else 0)


## The textbook start level (the LCD's start chip).
func recommended_start() -> int:
	return textbook_target()


## The coach's and Hoot's next move: {action, target_db, ...}. Base actions are louder, softer,
## mask_toggle, present, score_correct, score_missed and store; anything else is mode-only and goes
## through do() (run_by_textbook) or SpMode.act() (the screen). {action: &"none"} = nothing to do.
## Only a scoring action may read the truth.
func recommended_action() -> Dictionary:
	var s := session()
	return {"action": &"none", "target_db": s.db if s != null else 0}


## Where the dial should be for the next item.
func textbook_target() -> int:
	var s := session()
	return s.db if s != null else 0


## The SRT the scores support (SpeechRules.NO_SRT: not an SRT test).
func candidate() -> int:
	return SpeechRules.NO_SRT


# ---------------------------------------------------------------- controls

## Present the next item. Returns the trial ({} = refused). Put "slot" and "list_id" in it, and set
## the session's `current` (the trial; its "delay_s" times the answer) and `awaiting_score`, as the
## SRT does: the screen reads both.
func present() -> Dictionary:
	return {}


## Score the waiting item (or mark a key word). Returns the trial ({} = refused).
func score(_correct: bool) -> Dictionary:
	return {}


## Store (WRS refuses: the list ends itself; SIN: LOCK IN). Returns the result ({} = refused). A
## stored sheet goes out through the session's `stored` signal, with "slot" in it.
func store() -> Dictionary:
	return {}


## A mode-only control (toggle_lens, call_it, flip_key, mark_key, all_got, focus_key, ...).
## Returns its result ({} = refused).
func act(_action: StringName, _args: Dictionary = {}) -> Dictionary:
	return {}


## run_by_textbook: one mode-only action of recommended_action() (`rec` is that dictionary).
## Returns its result ({} = refused, which ends the run).
func do(_action: StringName, _rec: Dictionary) -> Dictionary:
	return {}


# ---------------------------------------------------------------- views and words

## get_state()[test]: the mode's own view (never truth).
func state() -> Dictionary:
	return {}


## Hoot's line for a technique kind ("" = SpeechSession.TIPS). {key:<action>} placeholders are
## filled by the screen.
func tip(_kind: StringName) -> String:
	return ""


## Points for a clean kind (-1 = SpeechSession.POINTS), times the combo multiplier.
func points(_kind: StringName) -> int:
	return -1


## set_level() was refused (can_set_level() false): a once-per-list observation, say.
func on_level_refused() -> void:
	pass


## set_mask() was refused (can_mask() false).
func on_mask_refused() -> void:
	pass


## Adds the test's summary (wrs_summary / sin_summary) to build_results()' `speech`. Called on a
## fresh, throwaway mode, so read everything from the session's sheets.
func summarize(_speech: Dictionary) -> void:
	pass
