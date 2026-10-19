class_name AudiometrySession
extends RefCounted
## AudiometrySession: pure logic of one patient's air-conduction test, both ears (builder A).
## No nodes and no real clock: the screen calls advance(delta) and the control methods.
## It holds the patient simulator, the technique checker (teaching Hughson-Westlake simply)
## and the golf / combo / points scoring. Results shape: CONTRACTS.md §5.1.
##
## The rules it teaches (ClinicRules has the numbers):
##   - start at 1000 Hz around 40 dB HL; nothing heard yet -> up 10 (5 and 20 tolerated)
##   - heard -> DOWN 10; missed -> UP 5
##   - threshold = the lowest level heard on at least 2 ascending runs, and on at least half of
##     them ("2 of 3"; the coached ear accepts 2 of 2, which the same rule already does)
##   - order 1k, 2k, 4k, 8k, retest 1k (within 5 dB), 500, 250; the half-octave in between
##     whenever neighbouring octaves differ by 20 dB or more
##   - tones 1-2 s, varied gaps, never start above 70 dB, never blast far above threshold
## Golf: each measurement is a hole. Par = the presentations a textbook search needs from the
## measurement's start level, on average, for this patient (expected_presentations()).
##
## (v3, Chapter 2, docs/CHAPTER2.md) Bone conduction and masking. The session keeps one results
## SHEET per test (ClinicRules.TESTS: ac, ac_masked, bc, bc_masked); the controls pick the sheet:
## the transducer (air phones / inserts, or the bone oscillator) and the masking switch. The vars
## stored / retest / order point at the current sheet, so the air-only code reads unchanged.
##   - unmasked sheets: the Hughson-Westlake dance above (bone: 250-4000 Hz, lower maximum)
##   - masked sheets (plateau / Hood): start at the unmasked threshold with the initial masking
##     level in the other ear; heard -> noise up 5; missed -> tone up 5; the threshold is the tone
##     level heard through PLATEAU_STEPS noise raises in a row (15 dB of masking), at or above the
##     initial level and below overmasking
##   - configure(plan) sets the GOAL sheet: what "complete" means and where the coach steers.

signal responded(ear: String, freq: int, db: int, tone_related: bool)
signal technique(kind: StringName, data: Dictionary)
signal combo_changed(n: int, multiplier: int)
signal stored_point(ear: String, freq: int, db: int, info: Dictionary)
signal reaction(kind: StringName, data: Dictionary)
## A presentation got its verdict (responded or missed). rec = public_record() shape.
signal presentation_closed(ear: String, freq: int, rec: Dictionary)

## Hoot's one-liners per technique kind (original wording, 18 words max, CONTRACTS.md §4.5).
## {He} {he} {his} {His} {him} are the patient's pronouns: tip_text() fills them in.
const TIPS: Dictionary[StringName, String] = {
	&"wrong_step": "Heard it? Down 10. Missed it? Up 5. That's the whole dance!",
	&"start_too_high": "Start around 40 dB and work down. Ears aren't pinatas!",
	&"store_without_bracket": "Store only after two answers on the way UP at the same level.",
	&"store_wrong_level": "Threshold is the LOWEST level heard twice on the way up. Check your trail!",
	&"tone_too_short": "Was that a mosquito? Hold each beep for 1 to 2 seconds.",
	&"tone_too_long": "Long beeps make patients sleepy. 1 to 2 seconds is the sweet spot.",
	&"rhythmic": "{He}'s learned your groove and presses on the beat! Vary the gaps between beeps.",
	&"too_loud": "Hair blast! Way above {his} threshold. Come back down gently.",
	&"retest_mismatch": "Retest is off by more than 5 dB: re-instruct {him} and recheck the earlier pitches.",
	&"start_not_1k": "Start each ear at 1000 Hz, the friendliest pitch in town.",
	&"missed_retest": "Before the low pitches, re-check 1000 Hz. Trust, but verify!",
	&"nr_too_early": "No response is only for a miss at the AudiOtron's loudest level.",
	&"marathon": "Tired patients guess. Bracket quickly and store!",
	&"store_far_off": "That stamp is far from {his} real hearing. Bracket carefully before you store.",
	&"not_instructed": "{He}'s pressing for the air-con hum! Always say: press for EVERY beep.",
	&"phones_swapped": "{He}'s pointing at the other ear. Red = Right!",
	&"short_gap": "Leave at least a beep's worth of quiet between beeps, or {he} guesses.",
	# v3: bone conduction and masking (docs/CHAPTER2.md section 5)
	&"mask_wrong_step": "Masked dance: heard? Noise up 5. Missed? Tone up 5. Nothing else moves!",
	&"mask_too_low": "Start the noise at the other ear's air threshold + 10, plus occlusion for low bone.",
	&"mask_start": "Begin the masked search at the unmasked threshold, with the noise at its starting level.",
	&"overmasked": "Past the safe limit! This much noise could cross back and mask the test ear too.",
	&"store_no_plateau": "No plateau yet! Store once the answer survives three noise raises in a row.",
	&"cross_hearing": "Bone has zero IA: that beep may have crossed to the OTHER cochlea. Meet the Ghost!",
	&"undermasked": "The Ghost answered! Not enough noise yet: heard means noise up 5.",
	&"plateau_found": "Flat line! Same answer through 15 dB more noise: that's the true threshold. Store it!",
	# clinical review E9: the masking dilemma and an unreached plateau (BSA 2018, 8.8 and 8.9)
	&"masking_dilemma": "Masking dilemma! Enough noise crosses back; safe noise is too weak. Inserts help. Else mark it ?",
	&"plateau_not_reached": "No room left! More noise would cross back to this ear. Store it: plateau not reached.",
	&"vibrotactile": "Loud low bone tones get FELT, not heard. A tickle is not a threshold!",
	# clinical review E8: tinnitus confuses steady tones (ASHA 2005; the lesson itself is the cases' C8)
	&"tinnitus_steady": "Steady beeps hide in {his} ringing! Switch the beep type to PULSED or WARBLE.",
}
## Positive kinds and the points they are worth (times the combo multiplier).
const POINTS: Dictionary[StringName, int] = {&"good_start": 10, &"textbook_step": 10, &"store_ok": 50}
const GOLF_POINTS: Dictionary[StringName, int] = {&"albatross": 300, &"eagle": 200, &"birdie": 100, &"par": 50, &"bogey": 20}
## Par = typical expert presentations + this slack. Tune in playtests.
const PAR_SLACK := 0
## Monte Carlo runs behind each par value (fixed seed, cached).
const PAR_RUNS := 400
## "Above 90 dB for nothing": a tone above this level, at least TOO_LOUD_HIGH_SL above threshold.
const TOO_LOUD_HIGH_DB := 90
const TOO_LOUD_HIGH_SL := 25
## Inside this many dB of threshold the patient visibly strains (reaction only).
const STRAIN_BELOW_DB := 3
const STRAIN_ABOVE_DB := 4
## (v3) The masker dial's level when a session starts (dB EM): low on purpose, the player sets it.
const MASK_DIAL_START_DB := 10
## (v3) Masked par = the textbook plateau dance on a consistent patient + this (real patients
## wobble at threshold, which costs a run).
const MASK_PAR_SLACK := 2
## (v3) A masked search may start this far from the unmasked threshold.
const MASK_START_TOLERANCE_DB := 10
## (v3) Plateau grace for accuracy: a masked stamp ABOVE the truth gets this much extra room before
## the usual test-retest tolerance (true_db unchanged). (Polish) 0: the simulator now calibrates
## masked answers instead (PatientSim.MASKED_BIAS_DB), so a by-the-book plateau lands on the
## profile threshold most of the time and masked stamps are scored like unmasked ones.
const MASKED_GRACE_DB := 0
## (Polish) Hoot's montage (instant_measure): varied silent gaps and tone lengths, never a rhythm.
const INSTANT_GAPS: Array[float] = [0.9, 1.6, 1.2, 2.0, 1.0, 1.8, 1.4, 2.2]
const INSTANT_DURATIONS: Array[float] = [1.3, 1.6, 1.2, 1.5, 1.7, 1.4]

var patient: PatientProfile
var sim: PatientSim
var ear: String = "right"
var freq: int = ClinicRules.START_FREQ
var db: int = ClinicRules.START_DB
var coached: Dictionary = {"right": false, "left": false}
var time: float = 0.0

var tone_on: bool = false
var tone_start_t: float = 0.0
var last_tone_end_t: float = -100.0
var window_end_t: float = -100.0

## ear -> freq -> stored info (§4.4) of the measurement that counts (first or redo)
var stored: Dictionary = {"right": {}, "left": {}}
## ear -> {stored_db, diff, strokes, par} of the 1 kHz retest
var retest: Dictionary = {"right": {}, "left": {}}
## ear -> store order (1000 twice = retest)
var order: Dictionary = {"right": [], "left": []}
var errors: Array[Dictionary] = []
var checks: int = 0
var clean_checks: int = 0
var combo: int = 0
var max_combo: int = 0
var points: int = 0
var presentations: int = 0
var false_alarms: int = 0
## presses during or right after a tone the patient did NOT hear (guess / on-the-beat)
var false_hits: int = 0
## false while Hoot runs the "watch the dance" fast-forward (quick visit): nothing he does
## scores (points, combo, technique, golf, efficiency, accuracy). His stamps still count as data.
var scoring: bool = true
## Presentations made while scoring was off (Hoot's turn).
var auto_presentations: int = 0
## true right after a too-short beep was thrown away (nothing heard): the coach says "hold longer".
var last_short: bool = false

## ear -> freq -> Array of records: the open (not yet stored) measurement
var _open: Dictionary = {"right": {}, "left": {}}
## ear -> Array of {freq, strokes, par, kind}: every finished measurement (for totals)
var _archive: Dictionary = {"right": [], "left": []}
var _cur: Dictionary = {}           ## the last presentation (record)
var _cur_ear: String = "right"
var _cur_freq: int = 1000
var _pending_press_t: float = -1.0
var _pending_rec: Dictionary = {}
var _anticip_t: float = -1.0
var _gaps: Array[float] = []
var _once: Dictionary = {}
var _loud_hit: Dictionary = {}      ## "ear:freq" -> true once a blast cost comfort this measurement
var _marathon_hit: Dictionary = {}
var _meas_errors: Dictionary = {}   ## "ear:freq" -> technique errors in the open measurement
var _start_ref: Dictionary = {}     ## "ear:freq" -> recommended start, fixed when the measurement opens

# ---- v3: tests, transducers, masking
## The current sheet: ClinicRules.test_id(transducer == &"bone", mask_on). Read-only outside.
var test: StringName = &"ac"
## The plan's goal sheet (configure()): what is_ear_complete() / required_remaining() mean and
## where recommended_action() steers. &"ac" = the Chapter 1 air test.
var goal_test: StringName = &"ac"
## The air transducer (&"phones" or &"inserts"); the masking earphone is the same kind.
var air_transducer: StringName = &"phones"
## The transducer the tone goes through: air_transducer or &"bone".
var transducer: StringName = &"phones"
## (E8) The tone is steady, not pulsed or warble (set_steady_tone(); E7: the screen starts pulsed).
## Near the patient's tinnitus pitch a steady tone is harder to hear (PatientSim.tinnitus_confuses).
var steady_tone: bool = false
## Masking noise (narrow band at the test frequency) in the NON-test ear.
var mask_on: bool = false
## The masker dial (dB EM). Kept while masking is off (it can be preset).
var mask_db: int = MASK_DIAL_START_DB
## The plan given to configure() (CONTRACTS.md §4.2 v3).
var plan: Dictionary = {}
var _sheets: Dictionary = {}        ## test -> {stored, retest, order, open, archive}
var _bc_freqs: Array[int] = []      ## plan "bc_freqs": required unmasked bone frequencies
var _overmask_hit: Dictionary = {}  ## measurement key -> true once overmasking was flagged
## (Polish) Ears whose 1 kHz air retest is not required (Day 2: Hoot skips it, Day 1 taught it).
var retest_waived: Dictionary = {}
var _instant_n := 0


func _init(p: PatientProfile, seed_value: int = 0) -> void:
	patient = p
	sim = PatientSim.new(p, seed_value)
	_bc_freqs = ClinicRules.BC_REQUIRED.duplicate()
	for t: StringName in ClinicRules.TESTS:
		_sheets[t] = {"stored": {"right": {}, "left": {}}, "retest": {"right": {}, "left": {}},
			"order": {"right": [], "left": []}, "open": {"right": {}, "left": {}}, "archive": {"right": [], "left": []}}
	_activate_sheet()


## (v3) Set the test plan (CONTRACTS.md §4.2 v3). Keys (all optional):
##   "test": StringName  goal sheet (default &"ac"); the transducer follows (bone for bc tests)
##   "air_transducer": &"phones" | &"inserts"
##   "bc_freqs": Array[int]  required unmasked bone frequencies (default ClinicRules.BC_REQUIRED)
##   "mask_on": bool  start with the masker on (default: off; the player presses M)
##   "mask_db": int  masker dial start level
## Never call it while a tone plays.
func configure(p: Dictionary) -> void:
	plan = p.duplicate(true)
	goal_test = StringName(String(plan.get("test", "ac")))
	if not ClinicRules.TESTS.has(goal_test):
		goal_test = &"ac"
	var at := StringName(String(plan.get("air_transducer", String(air_transducer))))
	if at == &"phones" or at == &"inserts":
		air_transducer = at
	if plan.has("bc_freqs"):
		_bc_freqs.clear()
		for f: Variant in plan["bc_freqs"]:
			_bc_freqs.append(int(f))
	transducer = &"bone" if ClinicRules.test_is_bone(goal_test) else air_transducer
	mask_on = bool(plan.get("mask_on", false))
	if plan.has("mask_db"):
		mask_db = ClinicRules.clamp_mask_db(int(plan["mask_db"]))
	if not ClinicRules.test_freqs(test_for(transducer, mask_on)).has(freq):
		freq = ClinicRules.START_FREQ
	db = _clamp_level(db)
	_activate_sheet()


## (v3) The test a transducer / masking combination records on.
static func test_for(tr: StringName, masked: bool) -> StringName:
	return ClinicRules.test_id(tr == &"bone", masked)


## Point stored / retest / order / the open measurements at the sheet the controls select.
func _activate_sheet() -> void:
	test = test_for(transducer, mask_on)
	var sh: Dictionary = _sheets[test]
	stored = sh["stored"]
	retest = sh["retest"]
	order = sh["order"]
	_open = sh["open"]
	_archive = sh["archive"]


## The sheet Dictionary of a test: {stored, retest, order, open, archive} (read-only use).
func sheet(t: StringName) -> Dictionary:
	return _sheets.get(t, {})


## Measurement key for the per-measurement bookkeeping (Chapter 1 keys stay "ear:freq").
func _mkey(e: String, f: int) -> String:
	return "%s:%d" % [e, f] if test == &"ac" else "%s:%s:%d" % [test, e, f]


func _top(f: int = -1) -> int:
	return ClinicRules.max_db_for(freq if f < 0 else f, transducer)


func _clamp_level(level: int, f: int = -1) -> int:
	return ClinicRules.clamp_db_for(level, freq if f < 0 else f, transducer)


static func other_ear(e: String) -> String:
	return "left" if e == "right" else "right"


# ---------------------------------------------------------------- controls

## Returns false if the ear did not change (tone on, or same ear).
func set_ear(e: String) -> bool:
	if tone_on or e == ear or not ClinicRules.EARS.has(e):
		return false
	ear = e
	return true


func step_freq(direction: int) -> bool:
	var fs := ClinicRules.test_freqs(test)
	var i := fs.find(freq)
	var j := clampi(i + direction, 0, fs.size() - 1)
	return set_freq(fs[j])


func set_freq(f: int) -> bool:
	if tone_on or not ClinicRules.test_freqs(test).has(f) or f == freq:
		return false
	freq = f
	db = _clamp_level(db)
	return true


## direction +1 = louder (higher dB HL), -1 = softer. Blocked while a tone plays: present
## discrete beeps and change the level between them. Returns false if nothing changed.
func step_level(direction: int) -> bool:
	if tone_on:
		return false
	var before := db
	db = _clamp_level(db + direction * ClinicRules.LEVEL_STEP_DB)
	return db != before


func set_level(level: int) -> bool:
	if tone_on:
		return false
	var before := db
	db = _clamp_level(level)
	return db != before


## (v3) Switch the tone's transducer: &"phones", &"inserts" or &"bone". Moving to bone above
## 4 kHz lands on 4 kHz; the level is clamped to the new maximum. Returns false if unchanged.
func set_transducer(tr: StringName) -> bool:
	if tone_on or not ClinicRules.TRANSDUCERS.has(tr) or tr == transducer:
		return false
	if tr != &"bone":
		air_transducer = tr
	transducer = tr
	var fs := ClinicRules.test_freqs(test_for(tr, mask_on))
	if not fs.has(freq):
		var best := fs[0]
		for f: int in fs:
			if absi(f - freq) < absi(best - freq):
				best = f
		freq = best
	db = _clamp_level(db)
	_activate_sheet()
	return true


## (v3) Masking noise on / off (in the non-test ear). Returns false if unchanged or a tone plays.
func set_mask(on: bool) -> bool:
	if tone_on or on == mask_on:
		return false
	mask_on = on
	_activate_sheet()
	return true


func toggle_mask() -> bool:
	return set_mask(not mask_on)


## (v3) Masker dial up (+1) or down (-1) one MASK_STEP_DB step. Works while masking is off.
func step_mask(direction: int) -> bool:
	if tone_on:
		return false
	var before := mask_db
	mask_db = ClinicRules.clamp_mask_db(mask_db + direction * ClinicRules.MASK_STEP_DB)
	return mask_db != before


func set_mask_level(level: int) -> bool:
	if tone_on:
		return false
	var before := mask_db
	mask_db = ClinicRules.clamp_mask_db(level)
	return mask_db != before


## The ear the masking noise goes to (the non-test ear).
func masker_ear() -> String:
	return other_ear(ear)


func tone_down() -> void:
	if tone_on:
		return
	_close_current()
	last_short = false
	var recs := _measurement_for_write(ear, freq)
	var first := recs.is_empty()
	if first:
		_start_ref[_mkey(ear, freq)] = _compute_start(ear, freq)
	var gap := time - last_tone_end_t if last_tone_end_t > -50.0 else -1.0
	if recs.is_empty() and not sim.instructed and not _once.has("not_instructed"):
		_once["not_instructed"] = true
		_observe(&"not_instructed", {"db": db})
	if ClinicRules.test_is_masked(test):
		_check_mask_step(recs)
	else:
		_check_step(recs)
	_check_rhythm(gap)
	tone_on = true
	tone_start_t = time
	if scoring:
		presentations += 1
	else:
		auto_presentations += 1
	_apply_condition()
	if scoring and sim.tinnitus_confuses(freq) and not _once.has("tinnitus_steady"):
		_once["tinnitus_steady"] = true
		_observe(&"tinnitus_steady", {"tinnitus_hz": patient.tinnitus_hz})
	var decision := sim.on_tone_start(ear, freq, db, gap)
	var rec := {
		"i": recs.size(), "db": db, "t": time, "duration": 0.0, "responded": false, "closed": false,
		"ascending": _any_response(recs) and int(recs[-1]["db"]) < db and not bool(recs[-1]["responded"]),
		"heard": bool(decision["heard"]), "guess": bool(decision["guess"]), "anticipated": false,
		# v3: the masker during this tone (-1 = off) and which cochlea heard it (truth, reactions only)
		"mask_db": mask_db if mask_on else -1, "by": sim.last_heard_by, "test": test,
	}
	recs.append(rec)
	_cur = rec
	_cur_ear = ear
	_cur_freq = freq
	if bool(decision["press"]):
		_pending_press_t = time + float(decision["latency_s"])
		_pending_rec = rec
	var sl := sim.sensation_level(ear, freq, db)
	# A first tone at or below MAX_START_DB is a legal start (same rule as start_too_high), so it
	# never counts as a blast: the coach must never walk the player into a penalty.
	var legal_start := first and db <= ClinicRules.MAX_START_DB
	if not legal_start and (sl >= ClinicRules.TOO_LOUD_SL_DB or (db > TOO_LOUD_HIGH_DB and sl >= TOO_LOUD_HIGH_SL)):
		var key := _mkey(ear, freq)
		first = not _loud_hit.has(key)
		_loud_hit[key] = true
		_error(&"too_loud", {"db": db, "sl": sl, "comfort_loss": 1 if first and scoring else 0}, false)
		reaction.emit(&"too_loud_blast", {"ear": ear, "db": db, "intensity": clampf(float(sl) / 80.0, 0.3, 1.0)})
	elif sl >= -STRAIN_BELOW_DB and sl <= STRAIN_ABOVE_DB:
		reaction.emit(&"straining", {"ear": ear, "db": db, "intensity": 0.6})
	var strokes := recs.size()
	var marathon_at := int(ceil(par_for(ear, freq) * ClinicRules.MARATHON_FACTOR)) + 1
	if scoring and strokes == marathon_at and not _marathon_hit.has(_mkey(ear, freq)):
		_marathon_hit[_mkey(ear, freq)] = true
		_error(&"marathon", {"strokes": strokes}, false)
		reaction.emit(&"bored", {"ear": ear})
	# v3: bone and masking gags and lessons
	if transducer == &"bone" and ClinicRules.VIBROTACTILE_DB.has(freq) and db >= int(ClinicRules.VIBROTACTILE_DB[freq]):
		reaction.emit(&"tickle", {"ear": ear, "db": db})
		if not _once.has("vibrotactile"):
			_once["vibrotactile"] = true
			_observe(&"vibrotactile", {"db": db})
	if mask_on and ClinicRules.test_is_masked(test) and mask_db >= overmask_limit_db(ear, freq, db):
		reaction.emit(&"overmasked", {"ear": ear, "masker_ear": masker_ear(), "mask_db": mask_db})
		if not _overmask_hit.has(_mkey(ear, freq)):
			_overmask_hit[_mkey(ear, freq)] = true
			_error(&"overmasked", {"mask_db": mask_db, "limit_db": overmask_limit_db(ear, freq, db)}, false)


## (v3) Tell the patient simulator what this tone goes through and what the other ear hears.
func _apply_condition() -> void:
	sim.transducer = transducer
	sim.masker_db = mask_db if mask_on else -1
	sim.masker_transducer = air_transducer
	sim.steady_tone = steady_tone


## (E8) The screen's tone type: steady (true) or pulsed / warble (false, the E7 default).
func set_steady_tone(on: bool) -> void:
	steady_tone = on
	if sim != null:
		sim.steady_tone = on


func tone_up() -> void:
	if not tone_on:
		return
	tone_on = false
	var dur := time - tone_start_t
	_cur["duration"] = dur
	last_tone_end_t = time
	window_end_t = time + ClinicRules.RESPONSE_WINDOW_S
	if _pending_rec == _cur and _pending_press_t > time and not bool(_cur["guess"]):
		if not sim.keeps_press_after_short_tone(_cur_ear, _cur_freq, int(_cur["db"]), dur):
			_cancel_pending()
	if dur < ClinicRules.TONE_TOO_SHORT_S:
		# A blip too short to hear (and not answered) is thrown away: the same level gets a proper
		# beep next, without counting as a step, a miss or a run.
		var pending := _pending_rec == _cur and _pending_press_t >= 0.0
		if not bool(_cur["responded"]) and not pending:
			_void_current()
		_error(&"tone_too_short", {"duration_s": dur}, false)
		reaction.emit(&"squint", {"ear": ear})
	elif dur > ClinicRules.TONE_TOO_LONG_S:
		_error(&"tone_too_long", {"duration_s": dur}, false)
		reaction.emit(&"yawn", {"ear": ear})
	var ad := sim.anticipation_delay()
	if ad >= 0.0:
		_anticip_t = time + ad
	if not _cur.is_empty() and bool(_cur["responded"]):
		_cur["closed"] = true
		_emit_closed()


## Advance the session clock; fires presses, closes response windows, makes false alarms.
func advance(delta: float) -> void:
	time += delta
	if _pending_press_t >= 0.0 and time >= _pending_press_t:
		var guess := not _pending_rec.is_empty() and bool(_pending_rec.get("guess", false))
		_pending_press_t = -1.0
		_pending_rec = {}
		_press(&"guess" if guess else &"response")
	if _anticip_t >= 0.0 and time >= _anticip_t:
		_anticip_t = -1.0
		_press(&"anticipated")
	if not _cur.is_empty() and not bool(_cur["closed"]) and not tone_on and time > window_end_t and _pending_press_t < 0.0:
		_close_current()
	sim.dialled_freq = freq   # (E8) a steady tone near the tinnitus pitch: more presses for nothing
	if not tone_on and time > window_end_t and sim.false_alarm_tick(delta):
		_press(&"false_alarm")


## Store the current level as threshold. Returns the info dict (CONTRACTS.md §4.4).
func store() -> Dictionary:
	if tone_on:
		return {}
	_settle_before_store()
	var recs := measurement(ear, freq)
	var errs: Array[StringName] = []
	var masked := ClinicRules.test_is_masked(test)
	var candidate: Variant = store_candidate(ear, freq)
	if candidate == null:
		errs.append(&"store_no_plateau" if masked else &"store_without_bracket")
	elif int(candidate) != db:
		errs.append(&"store_wrong_level")
	var kind := measurement_kind(ear, freq)
	var st: Dictionary = stored[ear]
	if test == &"ac" and kind == &"first" and st.is_empty() and freq != ClinicRules.START_FREQ:
		errs.append(&"start_not_1k")
	if test == &"ac" and kind == &"first" and (freq == 500 or freq == 250) and st.has(1000) and (retest[ear] as Dictionary).is_empty() and not retest_waived.has(ear):
		errs.append(&"missed_retest")
	if kind == &"retest":
		var diff := absi(db - int(st[1000]["stored_db"]))
		if diff > ClinicRules.RETEST_TOLERANCE_DB:
			errs.append(&"retest_mismatch")
	var info := _make_info(recs, errs, false, kind, candidate)
	_finish_store(info, errs)
	return info


## Store "no response" (only right after a miss at the maximum level).
func store_no_response() -> Dictionary:
	if tone_on:
		return {}
	_settle_before_store()
	var recs := measurement(ear, freq)
	var errs: Array[StringName] = []
	var top := _top()
	var maxed := false
	for rec: Dictionary in recs:
		if int(rec["db"]) >= top and bool(rec["closed"]) and not bool(rec["responded"]):
			maxed = true
	if not maxed:
		errs.append(&"nr_too_early")
	db = top
	var info := _make_info(recs, errs, true, measurement_kind(ear, freq), null)
	_finish_store(info, errs)
	return info


## (Polish) Hoot's montage ("I did her left while you chatted"): the whole textbook measurement at
## (e, f) on the current sheet in no time. It follows recommended_action() like Hoot's x8 turn,
## and the patient simulator answers every tone (varied gaps and lengths, no audio, no clock for
## the player), then the threshold is stored. Only while scoring is off (Hoot's holes, never the
## player's). Returns the store info, {} if nothing was stored.
func instant_measure(e: String, f: int) -> Dictionary:
	if tone_on or scoring:
		return {}
	set_ear(e)
	if freq != f and not set_freq(f):
		return {}
	var guard := 0
	while guard < 80:
		guard += 1
		var a := recommended_action()
		match a["action"]:
			&"store":
				return store()
			&"no_response":
				return store_no_response()
			&"louder", &"softer":
				set_level(int(a["target_db"]))
			&"mask_louder", &"mask_softer":
				set_mask_level(int(a.get("target_mask", mask_db)))
			&"transducer":
				set_transducer(StringName(a.get("target", &"bone")))
			&"mask_toggle":
				toggle_mask()
			&"wait":
				advance(0.25)
			&"present":
				advance(INSTANT_GAPS[_instant_n % INSTANT_GAPS.size()])
				tone_down()
				advance(INSTANT_DURATIONS[_instant_n % INSTANT_DURATIONS.size()])
				tone_up()
				advance(ClinicRules.RESPONSE_WINDOW_S + 0.05)
				_instant_n += 1
			_:
				return {}
		if freq != f or ear != e:
			return {}
	return {}


# ---------------------------------------------------------------- queries

## The open measurement's records at (e, f) (empty if none). Read-only use, please.
func measurement(e: String, f: int) -> Array:
	return (_open[e] as Dictionary).get(f, [])


## Public view of the open measurement: [{i, db, responded, closed, ascending, duration}].
## No hidden truth ("heard") in it, so UI and bots may read it.
func trail(e: String, f: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rec: Dictionary in measurement(e, f):
		out.append(public_record(rec))
	return out


static func public_record(rec: Dictionary) -> Dictionary:
	return {"i": rec["i"], "db": rec["db"], "responded": rec["responded"], "closed": rec["closed"],
		"ascending": rec["ascending"], "duration": rec["duration"], "mask_db": int(rec.get("mask_db", -1))}


## (v3) The level store() would accept now: the ascending threshold, or on a masked sheet the
## plateau level once the plateau is complete (or once the safe window is full, window_full()).
## null = nothing to store yet.
func store_candidate(e: String, f: int) -> Variant:
	if ClinicRules.test_is_masked(test):
		var pl := plateau_info(e, f)
		return int(pl["db"]) if bool(pl["found"]) or window_full(e, f) else null
	return ascending_threshold(e, f)


## (v3) The masked measurement at (e, f) holds a heard level with the noise at or above the
## initial masking, and one more 5 dB noise step would overmask: the plateau cannot be finished
## safely, so the held level is the answer, stored as "plateau not reached" (E9). In a masking
## dilemma (the initial level would already overmask) the noise only has to sit at the safe
## maximum, safe_mask_max_db().
func window_full(e: String, f: int) -> bool:
	var pl := plateau_info(e, f)
	var recs := measurement(e, f)
	if int(pl["db"]) < 0 or recs.is_empty():
		return false
	var last: Dictionary = recs[-1]
	var m := int(last.get("mask_db", -1))
	if not bool(last["responded"]) or m < mini(int(pl["initial"]), safe_mask_max_db(e, f, int(pl["db"]))):
		return false
	return m + ClinicRules.MASK_STEP_DB >= overmask_limit_db(e, f, int(pl["db"]))


## first / retest (1 kHz again after other frequencies) / redo (anything stored again).
func measurement_kind(e: String, f: int) -> StringName:
	var st: Dictionary = stored[e]
	if not st.has(f):
		return &"first"
	if test == &"ac" and f == ClinicRules.START_FREQ and (retest[e] as Dictionary).is_empty() and (order[e] as Array).size() >= 2 and not retest_waived.has(e):
		return &"retest"
	return &"redo"


## Ascending runs per level in the open measurement: {level: [hits, trials]}.
## An ascending trial is a presentation that comes up from a miss at a lower level, once the
## threshold search has begun (after the first response). The familiarisation climb in 10 dB
## steps before any response does not count: it jumps past threshold and would bias it upward.
func ascending_counts(e: String, f: int) -> Dictionary:
	var recs := measurement(e, f)
	var out: Dictionary = {}
	var searching := false
	for i in recs.size():
		var rec: Dictionary = recs[i]
		var was_searching := searching
		if bool(rec["responded"]):
			searching = true
		if i == 0 or not was_searching:
			continue
		var prev: Dictionary = recs[i - 1]
		if not (int(prev["db"]) < int(rec["db"]) and not bool(prev["responded"])):
			continue
		if not bool(rec["responded"]) and not bool(rec["closed"]):
			continue  # verdict pending
		var lvl := int(rec["db"])
		var c: Array = out.get(lvl, [0, 0])
		c[1] = int(c[1]) + 1
		if bool(rec["responded"]):
			c[0] = int(c[0]) + 1
		out[lvl] = c
	return out


## Lowest level heard on at least 2 ascending runs (and on at least half of them), or null.
## (polish) The bottom of the scale: heard twice at MIN_DB (-10 dB HL) there is nothing softer to
## bracket from, so -10 is the answer (a clinic records a response at the audiometer's floor).
func ascending_threshold(e: String, f: int) -> Variant:
	var counts := ascending_counts(e, f)
	var best: Variant = null
	for lvl: int in counts:
		var c: Array = counts[lvl]
		if int(c[0]) >= ClinicRules.ASCENDING_HITS_NEEDED and int(c[0]) * 2 >= int(c[1]):
			if best == null or lvl < int(best):
				best = lvl
	if best == null:
		var floor_hits := 0
		for rec: Dictionary in measurement(e, f):
			if bool(rec["responded"]) and int(rec["db"]) <= ClinicRules.MIN_DB:
				floor_hits += 1
		if floor_hits >= ClinicRules.ASCENDING_HITS_NEEDED:
			best = ClinicRules.MIN_DB
	return best


## Ascending hits at a level in the open measurement (for "1 of 2" badges).
func ascending_hits(e: String, f: int, level: int) -> int:
	var c: Array = ascending_counts(e, f).get(level, [0, 0])
	return int(c[0])


## The textbook next level after these records (Hughson-Westlake), or -1 with no records.
## top: the maximum output (v3: bone runs out sooner); -1 = the headphone maximum at f.
static func expected_next_db(recs: Array, f: int, top: int = -1) -> int:
	if recs.is_empty():
		return -1
	var last: Dictionary = recs[-1]
	var lvl := int(last["db"])
	if bool(last["responded"]):
		return maxi(lvl - ClinicRules.DOWN_AFTER_HIT_DB, ClinicRules.MIN_DB)
	var any_hit := false
	for r: Dictionary in recs:
		if bool(r["responded"]):
			any_hit = true
	var up := ClinicRules.UP_AFTER_MISS_DB if any_hit else ClinicRules.UP_SEARCH_DB
	return mini(lvl + up, ClinicRules.max_db(f) if top < 0 else top)


## What a textbook clinician would do next at the current ear/frequency (coach and hints).
## {"action": &"present" | &"softer" | &"louder" | &"store" | &"no_response" | &"wait" | &"release",
##  "target_db": int, "then": StringName}
## (v3) also &"transducer" (switch to "target": &"bone" or the air transducer), &"mask_toggle"
## (turn the masker on / off), &"mask_louder" / &"mask_softer" (towards "target_mask"); masked
## sheets add "target_mask" to every answer.
func recommended_action() -> Dictionary:
	if tone_on:
		return {"action": &"release", "target_db": db, "then": &""}
	if test != goal_test:
		var want_bone := ClinicRules.test_is_bone(goal_test)
		if want_bone != (transducer == &"bone"):
			return {"action": &"transducer", "target": &"bone" if want_bone else air_transducer, "target_db": db, "then": &""}
		return {"action": &"mask_toggle", "target_db": db, "target_mask": initial_mask_db(), "then": &""}
	if ClinicRules.test_is_masked(test):
		return _recommended_masked()
	var recs := measurement(ear, freq)
	if recs.is_empty():
		var start := recommended_start(ear, freq)
		if db > ClinicRules.MAX_START_DB or db >= start + 20:
			return {"action": &"softer", "target_db": start, "then": &"present"}
		return {"action": &"present", "target_db": db, "then": &""}
	var last: Dictionary = recs[-1]
	if not bool(last["closed"]) and not bool(last["responded"]):
		return {"action": &"wait", "target_db": db, "then": &""}
	var cand: Variant = ascending_threshold(ear, freq)
	if cand != null:
		if int(cand) != db:
			return {"action": &"louder" if int(cand) > db else &"softer", "target_db": int(cand), "then": &"store"}
		return {"action": &"store", "target_db": int(cand), "then": &""}
	var top := _top()
	if int(last["db"]) >= top and not bool(last["responded"]):
		return {"action": &"no_response", "target_db": top, "then": &""}
	var want := expected_next_db(recs, freq, top)
	if want != db:
		return {"action": &"louder" if want > db else &"softer", "target_db": want, "then": &"present"}
	return {"action": &"present", "target_db": want, "then": &""}


## The plateau dance's next move on a masked sheet (see recommended_action()).
func _recommended_masked() -> Dictionary:
	var recs := measurement(ear, freq)
	if recs.is_empty():
		var start := recommended_start(ear, freq)
		# (E9) in a masking dilemma the noise starts one step short of overmasking
		var init := start_mask_db(ear, freq, start)
		if mask_db != init:
			# the textbook begins at the initial level (more is allowed, but eats the safe window)
			return {"action": &"mask_louder" if init > mask_db else &"mask_softer", "target_db": start, "target_mask": init, "then": &"present"}
		if db != start:
			return {"action": &"louder" if start > db else &"softer", "target_db": start, "target_mask": mask_db, "then": &"present"}
		return {"action": &"present", "target_db": db, "target_mask": mask_db, "then": &""}
	var last: Dictionary = recs[-1]
	if not bool(last["closed"]) and not bool(last["responded"]):
		return {"action": &"wait", "target_db": db, "target_mask": mask_db, "then": &""}
	var pl := plateau_info(ear, freq)
	if bool(pl["found"]):
		var at := int(pl["db"])
		if at != db:
			return {"action": &"louder" if at > db else &"softer", "target_db": at, "target_mask": mask_db, "then": &"store"}
		return {"action": &"store", "target_db": at, "target_mask": mask_db, "then": &""}
	var top := _top()
	if int(last["db"]) >= top and not bool(last["responded"]):
		return {"action": &"no_response", "target_db": top, "target_mask": mask_db, "then": &""}
	if window_full(ear, freq):
		# one more noise step would overmask: the held level is the best answer this window allows
		var held := int(pl["db"])
		if held != db:
			return {"action": &"louder" if held > db else &"softer", "target_db": held, "target_mask": mask_db, "then": &"store"}
		return {"action": &"store", "target_db": held, "target_mask": mask_db, "then": &""}
	var nxt := _next_masked(recs)
	if mask_db != nxt.y:
		return {"action": &"mask_louder" if nxt.y > mask_db else &"mask_softer", "target_db": nxt.x, "target_mask": nxt.y, "then": &"present"}
	if db != nxt.x:
		return {"action": &"louder" if nxt.x > db else &"softer", "target_db": nxt.x, "target_mask": nxt.y, "then": &"present"}
	return {"action": &"present", "target_db": nxt.x, "target_mask": nxt.y, "then": &""}


## Textbook (tone, masker) after these masked records: ClinicRules.next_mask_step(), with the
## noise lifted to the initial level if it was below it (catching up is never a wrong step), and
## (E9) never at or past the overmasking limit for the next tone (capped = false skips that last cap).
func _next_masked(recs: Array, capped := true) -> Vector2i:
	var last: Dictionary = recs[-1]
	var m := int(last.get("mask_db", -1))
	var init := initial_mask_db()
	var nxt := ClinicRules.next_mask_step(int(last["db"]), maxi(m, 0), bool(last["responded"]))
	if m < init:
		# (E9) catching up stops one step short of overmasking: a dilemma never lifts the noise past it
		var tone := int(last["db"]) if bool(last["responded"]) else nxt.x
		nxt = Vector2i(tone, maxi(m, mini(init, safe_mask_max_db(ear, freq, mini(tone, _top())))))
	nxt.x = mini(nxt.x, _top())
	nxt.y = mini(nxt.y, ClinicRules.MASK_MAX_DB)
	# (E9) never recommend a presentation that overmasks: drop to one step under the limit. After a
	# heard tone this only bites when the window is full, and then the advice is to store instead.
	if capped and nxt.y >= overmask_limit_db(ear, freq, nxt.x):
		nxt.y = safe_mask_max_db(ear, freq, nxt.x)
	return nxt


## (v3) The plateau in the open masked measurement at (e, f) (defaults: current ear / freq):
## {"db": plateau tone level or -1, "steps": masker raises held at or above the initial level,
##  "needed": PLATEAU_STEPS, "found": bool, "start_mask", "initial": initial masking,
##  "points": masker dB -> lowest tone level heard with it (the plateau graph)}.
func plateau_info(e: String = "", f: int = -1) -> Dictionary:
	var ee := ear if e == "" else e
	var ff := freq if f < 0 else f
	var recs: Array = []
	for r: Dictionary in measurement(ee, ff):
		if bool(r["closed"]) or bool(r["responded"]):
			recs.append(r)
	var init := initial_mask_db(ee, ff)
	var run := _plateau_steps(recs, init)
	var pts := {}
	for r: Dictionary in recs:
		var m := int(r.get("mask_db", -1))
		if bool(r["responded"]) and m >= 0:
			pts[m] = mini(int(pts.get(m, 999)), int(r["db"]))
	return {"db": int(run["db"]), "steps": int(run["steps"]), "needed": ClinicRules.PLATEAU_STEPS,
		"found": int(run["steps"]) >= ClinicRules.PLATEAU_STEPS, "start_mask": int(run["start_mask"]),
		"initial": init, "points": pts}


## ClinicRules.plateau_run() counting only the raises at or above the initial masking level.
static func _plateau_steps(recs: Array, init: int) -> Dictionary:
	var run := ClinicRules.plateau_run(recs)
	if int(run["db"]) < 0:
		return run
	var end_mask := int((recs[-1] as Dictionary).get("mask_db", -1))
	var from := maxi(int(run["start_mask"]), init)
	var steps := maxi(0, (end_mask - from) / ClinicRules.MASK_STEP_DB) if end_mask >= from else 0
	return {"db": int(run["db"]), "steps": steps, "start_mask": from}


## (v3) Initial masking (dB EM) for a masked test at (e, f): the non-test ear's best air threshold
## + 10, plus the occlusion allowance for bone at 250-1000 Hz when that ear's middle ear looks
## normal. The non-test air threshold comes from this visit's stamps (0 if not measured).
func initial_mask_db(e: String = "", f: int = -1) -> int:
	var ee := ear if e == "" else e
	var ff := freq if f < 0 else f
	var v := results_view()
	var other := other_ear(ee)
	var n_ac := ClinicRules.best_thresholds(v, other, false)
	var ac := int(n_ac.get(ff, 0))
	var nb: Variant = ClinicRules.nontest_bone_estimate(v, ee, ff)
	var gap := 0 if nb == null or not n_ac.has(ff) else maxi(0, ac - int(nb))
	return ClinicRules.initial_masking(ac, ff, test_for(transducer, true), gap, air_transducer)


## (v3) Masker level at which overmasking starts for a tone at tone_db (default: the dial).
## Bone: tone + IA (the tone tracks the test cochlea). Air: the test ear's bone + IA, whatever the
## tone (masked bone where measured, else unmasked; with no bone at this frequency, the nearest
## frequency's bone stands in, e.g. 500 for 250); with no bone at all, tone + IA.
func overmask_limit_db(e: String = "", f: int = -1, tone_db: int = -999) -> int:
	var ee := ear if e == "" else e
	var ff := freq if f < 0 else f
	var tone := db if tone_db == -999 else tone_db
	var t := test_for(transducer, true)
	var gap := 0
	if not ClinicRules.test_is_bone(t):
		var bc := ClinicRules.best_thresholds(results_view(), ee, true)
		var nf := _nearest_freq(bc, ff)
		if nf > 0:
			gap = maxi(0, tone - int(bc[nf]))
	return ClinicRules.overmask_limit(tone, t, gap, air_transducer)


## (Clinical review E9) The most noise the rules allow at (e, f) for a tone at tone_db (default: the
## dial): one 5 dB step under the overmasking limit, never below the masker's minimum.
func safe_mask_max_db(e: String = "", f: int = -1, tone_db: int = -999) -> int:
	return maxi(ClinicRules.MASK_MIN_DB, overmask_limit_db(e, f, tone_db) - ClinicRules.MASK_STEP_DB)


## (E9) Where the noise starts for a masked tone at tone_db: the initial masking, or in a masking
## dilemma (that level would already overmask) the safe maximum instead.
func start_mask_db(e: String = "", f: int = -1, tone_db: int = -999) -> int:
	return mini(initial_mask_db(e, f), safe_mask_max_db(e, f, tone_db))


## (E9) A masking dilemma at (e, f) for a tone at tone_db: the initial masking already reaches the
## overmasking limit, so no safe window is left (BSA 2018, 8.9: a large conductive loss in both ears).
func in_dilemma(e: String = "", f: int = -1, tone_db: int = -999) -> bool:
	return ClinicRules.masking_dilemma(initial_mask_db(e, f), overmask_limit_db(e, f, tone_db))


## The key of `by_freq` (freq -> value) closest to f in octaves (f itself when present); 0 if empty.
static func _nearest_freq(by_freq: Dictionary, f: int) -> int:
	var best := 0
	var best_d := INF
	for k: int in by_freq:
		var d := absf(log(float(k) / float(f)))
		if d < best_d - 0.0001:
			best = k
			best_d = d
	return best


## (v3) Do the rules ask for masking at (e, f) on the current transducer, from this visit's stamps?
## Bone: the ear's air-bone gap (best air - unmasked bone, or the best bone estimate) is 10 dB or more.
## (v4) Unmasked bone from EITHER mastoid counts (ClinicRules.unmasked_bone(), as masked_freqs_needed).
## Air: the ear's air threshold (or the dial level, before it is stored) - IA >= the non-test bone.
func masking_needed_here(e: String = "", f: int = -1) -> bool:
	var ee := ear if e == "" else e
	var ff := freq if f < 0 else f
	var v := results_view()
	if transducer == &"bone":
		var ac := ClinicRules.best_thresholds(v, ee, false)
		if not ac.has(ff):
			return false
		var est: Variant = ClinicRules.unmasked_bone(v, ff)
		if est == null:
			est = ClinicRules.nontest_bone_estimate(v, ee, ff)
		return est != null and ClinicRules.bc_masking_needed(int(ac[ff]), int(est))
	var ac2 := ClinicRules.sheet_thresholds(v, ee, &"ac")
	var level := int(ac2[ff]) if ac2.has(ff) else db
	var nb: Variant = ClinicRules.nontest_bone_estimate(v, ee, ff)
	return nb != null and ClinicRules.ac_masking_needed(level, int(nb), air_transducer, ff)


## (v3) The masking-help light for the current ear / freq / dial (ClinicRules.MASK_STATUSES).
func mask_status() -> StringName:
	return ClinicRules.mask_status(mask_on, masking_needed_here(), mask_db, initial_mask_db(), overmask_limit_db())


## (v3) This visit's stamps in the results shape (§5.1 ears[e].freqs / .bc / .bc_masked /
## .ac_masked: freq -> info), live and read-only, for the ClinicRules masking helpers.
func results_view() -> Dictionary:
	var ears := {}
	for e: String in ClinicRules.EARS:
		var d := {}
		for t: StringName in ClinicRules.TESTS:
			d["freqs" if t == &"ac" else String(t)] = ((_sheets[t] as Dictionary)["stored"] as Dictionary)[e]
		ears[e] = d
	return {"ears": ears}


## Presentations a textbook search needs on a perfectly consistent patient (hears iff
## level >= threshold): familiarise (up 10 until heard), then down 10 / up 5 until a level is
## heard on 2 ascending runs, or the maximum output is missed (no response). Pure.
static func textbook_presentations(start_db: int, threshold: int, f: int) -> int:
	var top := ClinicRules.max_db(f)
	var level := ClinicRules.clamp_db(start_db, f)
	var hits: Dictionary = {}
	var prev_heard := true
	var any_hit := false
	var floor_hits := 0
	var n := 0
	while n < 80:
		n += 1
		var heard := level >= threshold
		if heard:
			if not prev_heard and any_hit:
				hits[level] = int(hits.get(level, 0)) + 1
				if int(hits[level]) >= ClinicRules.ASCENDING_HITS_NEEDED:
					return n
			if level <= ClinicRules.MIN_DB:
				floor_hits += 1
				if floor_hits >= ClinicRules.ASCENDING_HITS_NEEDED:
					return n  # heard twice at the very bottom of the scale: nothing softer to try
			any_hit = true
			level = maxi(level - ClinicRules.DOWN_AFTER_HIT_DB, ClinicRules.MIN_DB)
		else:
			if level >= top:
				return n  # missed at maximum output: no response
			level = mini(level + (ClinicRules.UP_AFTER_MISS_DB if any_hit else ClinicRules.UP_SEARCH_DB), top)
		prev_heard = heard
	return n


## Par for the measurement at (e, f): the presentations a textbook search needs from the
## RECOMMENDED start (recommended_start(), not wherever the player began: starting at 95 dB
## must not buy an easier par) on this patient, i.e. what an expert typically needs. A real
## patient wobbles: one extra ascending run costs about 3 presentations, so par is the median
## result, not the lucky minimum.
func par_for(e: String, f: int) -> int:
	var start := recommended_start(e, f)
	if ClinicRules.test_is_masked(test):
		return maxi(1, textbook_mask_presentations(e, f, start, start_mask_db(e, f, start)) + MASK_PAR_SLACK)
	var t := response_truth(e, f)
	var typical := expected_presentations(start - t, _top(f) - t, ClinicRules.MIN_DB - t, patient.psychometric_slope_db)
	return maxi(1, int(round(typical)) + PAR_SLACK)


## (v3) What an accurate tester records on the current sheet at (e, f) (the truth for scoring):
## air: the ear's air threshold (Chapter 1); unmasked bone: the BETTER cochlea's answer (bone
## crosses the head for free, so an unmasked bone stamp at the other cochlea's level is right);
## masked air / bone: the test ear's own air / bone threshold.
## (Polish) Unmasked air uses the cross-hearing model too (a dead ear's "shadow curve" is what an
## accurate unmasked tester records), always for the ear asked for: Day 1's swapped-earphones gag
## still scores against the requested ear. For Gus and Bonnie this is the ear's own air threshold.
func response_truth(e: String, f: int) -> int:
	match test:
		&"bc":
			return int(sim.condition_for(e, f, &"bone", -1, air_transducer)["threshold"])
		&"bc_masked":
			return patient.get_bc_threshold(e, f)
		&"ac":
			var o := other_ear(e)
			var ia := patient.get_ia(air_transducer)
			return int(ClinicRules.response_threshold(patient.get_threshold(e, f), patient.get_bc_threshold(e, f),
				patient.get_threshold(o, f), patient.get_bc_threshold(o, f), false, -1, ia, ia, 0)["threshold"])
	return patient.get_threshold(e, f)


## (v3) Presentations of a by-the-book plateau dance on a perfectly consistent patient (hears iff
## the tone reaches the response threshold under that masker), from (start_db, start_mask), until
## the plateau is complete, the safe window is full (E9: one more noise step would overmask) or the
## maximum is missed. Uses the current sheet's transducer.
func textbook_mask_presentations(e: String, f: int, start_db: int, start_mask: int) -> int:
	var tr := transducer
	var top := ClinicRules.max_db_for(f, tr)
	var tone := start_db
	var m := start_mask
	var recs: Array = []
	var n := 0
	while n < 60:
		n += 1
		var thr := int(sim.condition_for(e, f, tr, m, air_transducer)["threshold"])
		var heard := tone >= thr
		recs.append({"db": tone, "mask_db": m, "responded": heard})
		if heard and int(_plateau_steps(recs, start_mask)["steps"]) >= ClinicRules.PLATEAU_STEPS:
			return n
		if heard and m + ClinicRules.MASK_STEP_DB >= overmask_limit_db(e, f, tone):
			return n
		if not heard and tone >= top:
			return n
		var nx := ClinicRules.next_mask_step(tone, m, heard)
		tone = mini(nx.x, top)
		m = nx.y
		if m > ClinicRules.MASK_MAX_DB:
			return n
	return n


## (v4) Forget the open (unstored) measurement at (e, f) on the current sheet and its bookkeeping:
## the Ghost demo's one tone (plan demo_tone) is a demonstration, not the start of a bone search.
## A press still on its way for that tone is dropped too.
func discard_open(e: String, f: int) -> void:
	var recs: Array = (_open[e] as Dictionary).get(f, [])
	if not _cur.is_empty() and recs.has(_cur):
		if _pending_rec == _cur:
			_cancel_pending()
		_cur["closed"] = true
		_cur = {}
		_anticip_t = -1.0
	(_open[e] as Dictionary).erase(f)
	var key := _mkey(e, f)
	for d: Dictionary in [_start_ref, _loud_hit, _marathon_hit, _meas_errors, _overmask_hit]:
		d.erase(key)


## Where a textbook clinician starts the measurement at (e, f): 40 dB HL for the first 1 kHz of
## an ear; the stored 1 kHz threshold + 10 for the 1 kHz retest (never above START_DB); otherwise
## 10 dB above the previous stamp, clamped to 20..MAX_START_DB. Fixed once the measurement opens.
## (v3) A masked search starts at the unmasked threshold; (v4) for masked bone that is the
## unmasked bone from EITHER mastoid (ClinicRules.unmasked_bone(): the better cochlea).
func recommended_start(e: String, f: int) -> int:
	var key := _mkey(e, f)
	if _start_ref.has(key):
		return int(_start_ref[key])
	return _compute_start(e, f)


func _compute_start(e: String, f: int) -> int:
	var st: Dictionary = stored[e]
	if ClinicRules.test_is_masked(test):
		# v3: a masked search starts at the unmasked threshold
		var un: Dictionary = ((_sheets[ClinicRules.unmasked_test(test)] as Dictionary)["stored"] as Dictionary)[e]
		if un.has(f):
			return _clamp_level(int(un[f]["stored_db"]), f)
		# (v4) masked bone on the poorer ear after unmasked bone on the better one (Day 2): the
		# unmasked bone stamp from either mastoid is the better cochlea's, the textbook start
		if test == &"bc_masked":
			var ub: Variant = ClinicRules.unmasked_bone(results_view(), f)
			if ub != null:
				return _clamp_level(int(ub), f)
	if test == &"bc" and goal_test == &"bc_masked" and (order[e] as Array).is_empty():
		# (v4) a masked bone test opens on the unmasked bone sheet (noise off) before the player
		# presses M: show the unmasked bone from either mastoid, where the masked search starts
		var ub2: Variant = ClinicRules.unmasked_bone(results_view(), f)
		if ub2 != null:
			return _clamp_level(int(ub2), f)
	if measurement_kind(e, f) == &"retest":
		return _clamp_level(mini(int(st[1000]["stored_db"]) + 10, ClinicRules.START_DB), f)
	var ord: Array = order[e]
	if ord.is_empty():
		return _clamp_level(ClinicRules.START_DB, f)
	var last_f := int(ord[-1])
	var last_db := ClinicRules.START_DB
	if last_f == ClinicRules.START_FREQ and ord.count(ClinicRules.START_FREQ) >= 2 and not (retest[e] as Dictionary).is_empty():
		last_db = int(retest[e]["stored_db"])
	elif st.has(last_f):
		last_db = int(st[last_f]["stored_db"])
	return _clamp_level(clampi(last_db + 10, 20, ClinicRules.MAX_START_DB), f)


static var _par_cache: Dictionary = {}

## Typical (median) presentations of a textbook search for a patient whose hearing follows the
## logistic curve (50 % at threshold, given slope), with levels as offsets from threshold.
## A fixed-seed Monte Carlo, cached: the same inputs always give the same par.
static func expected_presentations(start_off: int, top_off: int, min_off: int, slope: float) -> float:
	var key := "%d:%d:%d:%.2f" % [start_off, top_off, maxi(min_off, -60), slope]
	if _par_cache.has(key):
		return _par_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var counts: Array[int] = []
	for run in PAR_RUNS:
		var level := clampi(start_off, min_off, top_off)
		var hits: Dictionary = {}
		var prev_heard := true
		var any_hit := false
		var n := 0
		while n < 60:
			n += 1
			var heard := rng.randf() < 1.0 / (1.0 + exp(-float(level) / maxf(0.5, slope)))
			if heard:
				if not prev_heard and any_hit:
					hits[level] = int(hits.get(level, 0)) + 1
					if int(hits[level]) >= ClinicRules.ASCENDING_HITS_NEEDED:
						break
				if level <= min_off and any_hit:
					break
				any_hit = true
				level = maxi(level - ClinicRules.DOWN_AFTER_HIT_DB, min_off)
			else:
				if level >= top_off:
					break
				level = mini(level + (ClinicRules.UP_AFTER_MISS_DB if any_hit else ClinicRules.UP_SEARCH_DB), top_off)
			prev_heard = heard
		counts.append(n)
	counts.sort()
	var median := float(counts[PAR_RUNS / 2])
	_par_cache[key] = median
	return median


## Required measurements still missing for an ear, in textbook order: 1k, (1.5k), 2k, (3k), 4k,
## (6k), 8k, 1k retest, (750), 500, 250. Half-octaves appear once both neighbours are stored
## and differ by INTEROCTAVE_DIFF_DB or more. 1000 after the highs means "1 kHz retest".
## (v3) t = the sheet (default: the plan's goal sheet; Chapter 1: &"ac").
func required_remaining(e: String, t: StringName = &"") -> Array[int]:
	var g := goal_test if t == &"" else t
	var sh: Dictionary = _sheets[g]
	var st: Dictionary = (sh["stored"] as Dictionary)[e]
	var rem: Array[int] = []
	if g != &"ac":
		for f: int in sheet_required(e, g):
			if not st.has(f):
				rem.append(f)
		return rem
	var rt: Dictionary = (sh["retest"] as Dictionary)[e]
	var need := ClinicRules.required_interoctaves(stored_thresholds(e, &"ac"))
	for f: int in [1000, 1500, 2000, 3000, 4000, 6000, 8000]:
		if (ClinicRules.is_octave(f) or need.has(f)) and not st.has(f):
			rem.append(f)
	if st.has(1000) and rt.is_empty() and not retest_waived.has(e):
		rem.append(1000)
	for f: int in [750, 500, 250]:
		if (ClinicRules.is_octave(f) or need.has(f)) and not st.has(f):
			rem.append(f)
	return rem


## (v3) Every frequency a non-air sheet needs for an ear, in the recommended order: unmasked
## bone = the plan's bc_freqs; masked sheets = where the rules call for masking (from the stamps).
func sheet_required(e: String, t: StringName) -> Array[int]:
	match t:
		&"bc":
			return _bc_freqs.duplicate()
		&"bc_masked", &"ac_masked":
			return ClinicRules.masked_freqs_needed(results_view(), e, t, air_transducer)
	return []


## (v3) t = the sheet (default: the goal sheet). Air needs at least one stamp; a masked sheet with
## nothing to mask is complete at once.
func is_ear_complete(e: String, t: StringName = &"") -> bool:
	var g := goal_test if t == &"" else t
	if g == &"ac" or g == &"bc":
		return not (((_sheets[g] as Dictionary)["stored"] as Dictionary)[e] as Dictionary).is_empty() and required_remaining(e, g).is_empty()
	return required_remaining(e, g).is_empty()


## Required measurements of an ear: [done, total] (the retest counts as one). v3: on the goal sheet.
func ear_progress(e: String, t: StringName = &"") -> Array[int]:
	var g := goal_test if t == &"" else t
	var sh: Dictionary = _sheets[g]
	var st: Dictionary = (sh["stored"] as Dictionary)[e]
	if g != &"ac":
		var req := sheet_required(e, g)
		var d := 0
		for f: int in req:
			if st.has(f):
				d += 1
		return [d, req.size()]
	var rt: Dictionary = (sh["retest"] as Dictionary)[e]
	var rem := required_remaining(e, g).size()
	if not st.has(1000) and rt.is_empty() and not retest_waived.has(e):
		rem += 1  # the 1k retest is still ahead (required_remaining lists it once 1k is stored)
	var done := st.size() + (0 if rt.is_empty() else 1)
	return [done, done + rem]


## freq -> stored dB of an ear on a sheet (default: the current sheet).
func stored_thresholds(e: String, t: StringName = &"") -> Dictionary:
	var st: Dictionary = (((_sheets[test if t == &"" else t] as Dictionary)["stored"] as Dictionary)[e] as Dictionary)
	var out := {}
	for f: int in st:
		out[f] = int(st[f]["stored_db"])
	return out


func build_results() -> Dictionary:
	var ears := {}
	var acc_sum := 0.0
	var acc_n := 0
	var strokes_total := 0
	var par_total := 0
	var view := results_view()
	var tests_done: Array[String] = []
	for e: String in ClinicRules.EARS:
		var ac_sheet: Dictionary = _sheets[&"ac"]
		var st: Dictionary = (ac_sheet["stored"] as Dictionary)[e]
		var strokes := 0
		var par := 0
		var fair := 0
		var hoot_holes := 0
		var e_acc := 0.0
		var e_n := 0
		var birdies := 0
		for t: StringName in ClinicRules.TESTS:
			var sh: Dictionary = _sheets[t]
			for m: Dictionary in (sh["archive"] as Dictionary)[e]:
				if bool(m.get("auto", false)):
					hoot_holes += 1
					continue
				strokes += int(m["strokes"])
				par += int(m["par"])
				# fair golf: a clean hole never counts over par (Gus wobbled), a slip never under
				var d := int(m["strokes"]) - int(m["par"])
				fair += mini(d, 0) if bool(m.get("clean", true)) else maxi(d, 0)
			var sst: Dictionary = (sh["stored"] as Dictionary)[e]
			if not sst.is_empty() and not tests_done.has(String(t)):
				tests_done.append(String(t))
			birdies += _count_birdies(sst)
			for f: int in sst:
				if bool(sst[f].get("by_hoot", false)):
					continue
				e_acc += float(sst[f]["accuracy"])
				e_n += 1
		acc_sum += e_acc
		acc_n += e_n
		strokes_total += strokes
		par_total += par
		var thr := ClinicRules.best_thresholds(view, e, false)
		var bone := ClinicRules.best_thresholds(view, e, true)
		var abg := {}
		for f: int in bone:
			if thr.has(f):
				abg[f] = int(thr[f]) - int(bone[f])
		var complete_tests := {}
		for t: StringName in ClinicRules.TESTS:
			complete_tests[String(t)] = is_ear_complete(e, t)
		ears[e] = {
			"freqs": st.duplicate(true),
			"complete": is_ear_complete(e, &"ac"),
			"retest_1k": ((ac_sheet["retest"] as Dictionary)[e] as Dictionary).duplicate(),
			"order": ((ac_sheet["order"] as Dictionary)[e] as Array).duplicate(),
			"strokes": strokes,
			"par": par,
			"golf": fair,
			"golf_raw": strokes - par,
			"hoot_holes": hoot_holes,
			"birdies": birdies,
			"accuracy": e_acc / e_n if e_n > 0 else 0.0,
			"shape": ClinicRules.classify_shape(thr),
			"pta": ClinicRules.pta(thr),
			"coached": bool(coached.get(e, false)),
			# v3: the other sheets (freq -> info, like "freqs") and what they say
			"bc": (((_sheets[&"bc"] as Dictionary)["stored"] as Dictionary)[e] as Dictionary).duplicate(true),
			"bc_masked": (((_sheets[&"bc_masked"] as Dictionary)["stored"] as Dictionary)[e] as Dictionary).duplicate(true),
			"ac_masked": (((_sheets[&"ac_masked"] as Dictionary)["stored"] as Dictionary)[e] as Dictionary).duplicate(true),
			"complete_tests": complete_tests,
			"best_ac": thr,
			"best_bc": bone,
			"abg": abg,
			"hearing_type": ClinicRules.hearing_type(thr, bone),
			"abg_red_flag": ClinicRules.abg_red_flag(thr, bone),
			"carhart_notch": ClinicRules.has_carhart_notch(ClinicRules.sheet_thresholds(view, e, &"bc_masked")),
		}
	var accuracy := acc_sum / acc_n if acc_n > 0 else 0.0
	var tech := float(clean_checks) / checks if checks > 0 else 0.0
	var eff := clampf(float(par_total) / strokes_total, 0.0, 1.0) if strokes_total > 0 else 0.0
	var w := ClinicRules.SCORE_WEIGHTS
	var part: float = w["accuracy"] + w["technique"] + w["efficiency"]
	var score: float = 100.0 * (w["accuracy"] * accuracy + w["technique"] * tech + w["efficiency"] * eff) / part
	return {
		"patient_id": patient.id,
		"patient_name": patient.display_name,
		"ears": ears,
		"technique_errors": errors.duplicate(true),
		"presentations": presentations,
		"hoot_presentations": auto_presentations,
		"false_alarms": false_alarms,
		"false_hits": false_hits,
		"max_combo": max_combo,
		"points": points,
		"accuracy": accuracy,
		"technique": tech,
		"efficiency": eff,
		"score": score,
		"grade": ClinicRules.grade_for_score(score),
		"duration_s": time,
		"tests": tests_done,
		"air_transducer": String(air_transducer),
	}


# ---------------------------------------------------------------- internals

static func _count_birdies(st: Dictionary) -> int:
	var n := 0
	for f: int in st:
		if StringName(String(st[f].get("golf", ""))) in [&"birdie", &"eagle", &"albatross"]:
			n += 1
	return n


## Throw away the presentation just made (a blip too short to hear): it never happened.
func _void_current() -> void:
	var sh: Dictionary = _sheets.get(StringName(_cur.get("test", test)), _sheets[test])
	var recs: Array = ((sh["open"] as Dictionary)[_cur_ear] as Dictionary).get(_cur_freq, [])
	var i := recs.find(_cur)
	if i >= 0:
		recs.remove_at(i)
	if _pending_rec == _cur:
		_cancel_pending()
	_cur = {}
	last_short = true


static func _any_response(recs: Array) -> bool:
	for r: Dictionary in recs:
		if bool(r["responded"]):
			return true
	return false


func _measurement_for_write(e: String, f: int) -> Array:
	var d: Dictionary = _open[e]
	if not d.has(f):
		d[f] = []
	return d[f]


func _press(kind: StringName) -> void:
	var related := not _cur.is_empty() and not bool(_cur["closed"]) and (tone_on or time <= window_end_t)
	if kind == &"anticipated":
		# he really pressed on the beat: that's the rhythm lesson, and it costs the combo
		_error(&"rhythmic", {"spread_s": -1.0, "anticipated": true}, false)
	elif kind == &"guess" and not _once.has("short_gap"):
		_once["short_gap"] = true
		_observe(&"short_gap", {})
	if related:
		var again := bool(_cur["responded"])
		_cur["responded"] = true
		if kind == &"anticipated":
			_cur["anticipated"] = true
		if not bool(_cur["heard"]) and not again:
			false_hits += 1
		if not tone_on and not again:
			_cur["closed"] = true
			_emit_closed()
		responded.emit(_cur_ear, _cur_freq, int(_cur["db"]), true)
		reaction.emit(&"grooving" if kind == &"anticipated" else &"heard", {"ear": _cur_ear, "db": int(_cur["db"])})
		if not again and bool(_cur["heard"]) and StringName(_cur.get("by", &"")) == &"cross":
			# v3: the Cross-Hearing Ghost: the OTHER cochlea answered this one
			reaction.emit(&"cross_heard", {"ear": _cur_ear, "via": other_ear(_cur_ear), "db": int(_cur["db"]), "masked": int(_cur.get("mask_db", -1)) >= 0})
			var lesson := &"undermasked" if int(_cur.get("mask_db", -1)) >= 0 else &"cross_hearing"
			if not _once.has(String(lesson)):
				_once[String(lesson)] = true
				_observe(lesson, {"db": int(_cur["db"])})
		if sim.swapped and not _once.has("phones_swapped"):
			_once["phones_swapped"] = true
			reaction.emit(&"point_wrong_way", {"ear": _cur_ear})
			_observe(&"phones_swapped", {"db": int(_cur["db"])})
		return
	false_alarms += 1
	responded.emit(ear, freq, db, false)
	reaction.emit(&"grooving" if kind == &"anticipated" else &"false_alarm", {"ear": ear})
	technique.emit(&"false_alarm", {"ear": ear, "freq": freq, "db": db, "anticipated": kind == &"anticipated"})
	if not sim.instructed and not _once.has("not_instructed"):
		_once["not_instructed"] = true
		_observe(&"not_instructed", {"db": db})


## Give the last presentation its verdict now (missed if nobody pressed).
func _close_current() -> void:
	if _cur.is_empty() or bool(_cur["closed"]) or tone_on:
		return
	_cur["closed"] = true
	if not bool(_cur["responded"]):
		reaction.emit(&"missed", {"ear": _cur_ear})
		technique.emit(&"missed", {"ear": _cur_ear, "freq": _cur_freq, "db": int(_cur["db"])})
	_emit_closed()


## presentation_closed for the current record, plus (v3, masked sheets) the plateau progress:
## technique &"plateau_step" {steps, needed, db, mask_db, found, window_full} after a heard masked
## tone, and the lesson &"plateau_found" once a plateau is complete (E9: &"plateau_not_reached",
## once per visit, when the safe window fills first).
func _emit_closed() -> void:
	presentation_closed.emit(_cur_ear, _cur_freq, public_record(_cur))
	if int(_cur.get("mask_db", -1)) < 0 or StringName(_cur.get("test", &"")) != test or _cur_ear != ear or _cur_freq != freq:
		return
	if not bool(_cur["responded"]):
		return
	var pl := plateau_info(_cur_ear, _cur_freq)
	var full := not bool(pl["found"]) and window_full(_cur_ear, _cur_freq)
	technique.emit(&"plateau_step", {"ear": _cur_ear, "freq": _cur_freq, "steps": int(pl["steps"]), "needed": ClinicRules.PLATEAU_STEPS,
		"db": int(_cur["db"]), "mask_db": int(_cur["mask_db"]), "found": bool(pl["found"]), "window_full": full, "auto": not scoring})
	if bool(pl["found"]) and int(pl["steps"]) == ClinicRules.PLATEAU_STEPS:
		_observe(&"plateau_found", {"db": int(pl["db"]), "start_mask": int(pl["start_mask"]), "end_mask": int(_cur["mask_db"])})
	elif full and scoring and not _once.has("plateau_not_reached"):
		_once["plateau_not_reached"] = true
		_observe(&"plateau_not_reached", {"db": int(pl["db"]), "mask_db": int(_cur["mask_db"]),
			"limit_db": overmask_limit_db(_cur_ear, _cur_freq, int(pl["db"]))})


## Storing ends the wait: a press still on its way for the last tone is dropped.
func _settle_before_store() -> void:
	if _pending_rec == _cur:
		_cancel_pending()
	_anticip_t = -1.0
	_close_current()


func _cancel_pending() -> void:
	_pending_press_t = -1.0
	_pending_rec = {}


func _check_step(recs: Array) -> void:
	if scoring:
		checks += 1
	if recs.is_empty():
		if db > ClinicRules.MAX_START_DB:
			_error(&"start_too_high", {"db": db}, true)
		else:
			_clean(&"good_start")
		return
	var prev: Dictionary = recs[-1]
	var prev_db := int(prev["db"])
	var prev_heard := bool(prev["responded"])
	var top := _top()
	var expected := expected_next_db(recs, freq, top)
	var ok := db == expected
	if not ok and not prev_heard:
		var any_hit := false
		for r: Dictionary in recs:
			if bool(r["responded"]):
				any_hit = true
		if not any_hit:
			for up: int in [ClinicRules.UP_AFTER_MISS_DB, ClinicRules.UP_SEARCH_DB, 2 * ClinicRules.UP_SEARCH_DB]:
				if db == mini(prev_db + up, top):
					ok = true
		if prev_db >= top and db == top:
			ok = true  # confirming a miss at maximum output
	if ok:
		_clean(&"textbook_step")
	else:
		_error(&"wrong_step", {"expected": expected, "got": db, "prev_db": prev_db, "prev_heard": prev_heard}, true)


## (v3) The technique check of a masked presentation (the plateau dance, see the file header).
func _check_mask_step(recs: Array) -> void:
	if scoring:
		checks += 1
	var init := initial_mask_db()
	if recs.is_empty():
		var start := recommended_start(ear, freq)
		if scoring and in_dilemma(ear, freq, db) and not _once.has("masking_dilemma"):
			_once["masking_dilemma"] = true
			_observe(&"masking_dilemma", {"initial_db": init, "limit_db": overmask_limit_db(ear, freq, db)})
		if mask_db < start_mask_db(ear, freq, db):
			_error(&"mask_too_low", {"mask_db": mask_db, "initial_db": init}, true)
		elif absi(db - start) > MASK_START_TOLERANCE_DB:
			_error(&"mask_start", {"db": db, "start_db": start}, true)
		else:
			_clean(&"good_start")
		return
	var prev: Dictionary = recs[-1]
	# (E9) the textbook step, or the same step with the noise capped one step under overmasking.
	# A full window is graded uncapped as before (the right move there is to store).
	var nxt := _next_masked(recs, false)
	var ok := db == nxt.x and mask_db == nxt.y
	if not ok and not window_full(ear, freq):
		var safe := _next_masked(recs)
		ok = db == safe.x and mask_db == safe.y
	if not ok and not bool(prev["responded"]) and int(prev["db"]) >= _top() and db == int(prev["db"]):
		ok = true  # confirming a miss at maximum output
	if ok:
		_clean(&"textbook_step")
	else:
		_error(&"mask_wrong_step", {"expected": nxt.x, "expected_mask": nxt.y, "got": db, "got_mask": mask_db,
			"prev_db": int(prev["db"]), "prev_heard": bool(prev["responded"])}, true)


func _check_rhythm(gap: float) -> void:
	if gap < 0.0:
		return
	_gaps.append(gap)
	while _gaps.size() > ClinicRules.RHYTHM_WINDOW:
		_gaps.pop_front()
	if _gaps.size() == ClinicRules.RHYTHM_WINDOW:
		var spread: float = _gaps.max() - _gaps.min()
		var mean := 0.0
		for g: float in _gaps:
			mean += g
		mean /= _gaps.size()
		if spread < maxf(ClinicRules.RHYTHM_REL_SPREAD * mean, 0.05):
			_error(&"rhythmic", {"spread_s": spread}, false)
			reaction.emit(&"grooving", {"ear": ear})
			_gaps.clear()


func _make_info(recs: Array, errs: Array[StringName], no_response: bool, kind: StringName, candidate: Variant) -> Dictionary:
	var true_db := response_truth(ear, freq)
	var err_db := float(db - true_db)
	var acc := ClinicRules.accuracy_for_error(err_db)
	if ClinicRules.test_is_masked(test) and err_db > 0.0:
		acc = ClinicRules.accuracy_for_error(maxf(0.0, err_db - MASKED_GRACE_DB))
	# (E9) a full window with no plateau: the held level is the honest answer, and the true threshold
	# may be poorer (the other cochlea may still answer), so a stamp at or above the truth is not an error
	var not_reached := ClinicRules.test_is_masked(test) and not no_response and candidate != null \
		and not bool(plateau_info(ear, freq)["found"])
	if not_reached and err_db <= 0.0 and errs.is_empty():
		acc = 1.0
	if no_response:
		acc = 1.0 if true_db > _top() else 0.0
	var strokes := recs.size()
	var par := par_for(ear, freq)
	var masked := ClinicRules.test_is_masked(test)
	var responses: Array = []
	for r: Dictionary in recs:
		if masked:
			responses.append([int(r["db"]), bool(r["responded"]), int(r.get("mask_db", -1))])
		else:
			responses.append([int(r["db"]), bool(r["responded"])])
	var clean := errs.is_empty() and int(_meas_errors.get(_mkey(ear, freq), 0)) == 0
	var golf: StringName = ClinicRules.fair_golf(strokes, par, clean) if scoring else &"hoot"
	return {
		"ear": ear,
		"freq": freq,
		"stored_db": db,
		"true_db": true_db,
		"error_db": err_db,
		"no_response": no_response,
		"strokes": strokes,
		"par": par,
		"golf": golf,
		"golf_raw": ClinicRules.golf_name(strokes, par),
		"clean": clean,
		"by_hoot": not scoring,
		"start_db": recommended_start(ear, freq),
		"accuracy": acc,
		"errors": errs,
		"technique_ok": errs.is_empty(),
		"retest": kind == &"retest",
		"redo": kind == &"redo",
		"masked": masked,
		"order_index": (order[ear] as Array).size(),
		"candidate_db": int(candidate) if candidate != null else -1,
		"responses": responses,
		# v3
		"test": String(test),
		"transducer": String(transducer),
		"mask_db": mask_db if mask_on else -1,
		"plateau": plateau_info(ear, freq) if masked else {},
		"plateau_not_reached": not_reached,
	}


func _finish_store(info: Dictionary, errs: Array[StringName]) -> void:
	if scoring:
		checks += maxi(1, errs.size())
	for k: StringName in errs:
		_error(k, {"db": db}, true)
	if errs.is_empty():
		_clean(&"store_ok")
	var may_be_poorer := bool(info.get("plateau_not_reached", false)) and float(info["error_db"]) < 0.0
	if not bool(info["no_response"]) and absf(float(info["error_db"])) > 10.0 and not may_be_poorer:
		_observe(&"store_far_off", {"db": db})
	var e := ear
	var f := freq
	(_archive[e] as Array).append({"freq": f, "strokes": int(info["strokes"]), "par": int(info["par"]), "kind": "retest" if bool(info["retest"]) else ("redo" if bool(info["redo"]) else "first"), "auto": not scoring, "clean": bool(info.get("clean", true)), "test": String(test)})
	var st: Dictionary = stored[e]
	if bool(info["retest"]):
		var first_db := int(st[1000]["stored_db"])
		var diff := absi(db - first_db)
		retest[e] = {"stored_db": db, "diff": diff, "strokes": int(info["strokes"]), "par": int(info["par"]), "first_db": first_db}
		if diff <= ClinicRules.RETEST_TOLERANCE_DB:
			# the two agree: the better (lower) of the two is the 1 kHz threshold on the audiogram
			if db < first_db:
				var k: Dictionary = st[1000]
				k["stored_db"] = db
				k["error_db"] = float(db - int(k["true_db"]))
				k["accuracy"] = ClinicRules.accuracy_for_error(float(k["error_db"]))
				k["retest_better"] = true
				info["better_db"] = db
			technique.emit(&"retest_ok", {"ear": e, "freq": f, "diff": diff, "plotted_db": mini(db, first_db)})
	elif test == &"ac":
		var before := ClinicRules.required_interoctaves(stored_thresholds(e))
		st[f] = info
		var after := ClinicRules.required_interoctaves(stored_thresholds(e))
		for io: int in after:
			if not before.has(io) and not st.has(io):
				technique.emit(&"interoctave_needed", {"ear": e, "freq": io})
	else:
		st[f] = info
	(order[e] as Array).append(f)
	(_open[e] as Dictionary).erase(f)
	var key := _mkey(e, f)
	_loud_hit.erase(key)
	_marathon_hit.erase(key)
	_meas_errors.erase(key)
	_start_ref.erase(key)
	_overmask_hit.erase(key)
	var golf: StringName = info["golf"]
	var clean := bool(info.get("clean", true))
	var bonus: int = GOLF_POINTS.get(golf, 0) if scoring and clean and not bool(info["no_response"]) else 0
	points += bonus
	info["points"] = bonus
	if golf in [&"birdie", &"eagle", &"albatross"] and clean and scoring:
		technique.emit(golf, {"ear": e, "freq": f, "points": bonus})
	stored_point.emit(e, f, db, info)
	var rem := required_remaining(e)
	if not rem.is_empty() and set_freq(rem[0]):
		# a textbook start for the next pitch (the retest starts just above the first 1 kHz)
		set_level(recommended_start(e, rem[0]))
		if mask_on and ClinicRules.test_is_masked(test):
			# v3: and the noise at its starting level (E9: one step short of overmasking in a dilemma)
			set_mask_level(start_mask_db(e, rem[0], db))


func _clean(kind: StringName) -> void:
	if not scoring:
		technique.emit(kind, {"ear": ear, "freq": freq, "db": db, "combo": 0, "multiplier": 1, "points": 0, "auto": true})
		return
	clean_checks += 1
	combo += 1
	max_combo = maxi(max_combo, combo)
	var mult := ClinicRules.combo_multiplier(combo)
	var gained: int = POINTS.get(kind, 0) * mult
	points += gained
	combo_changed.emit(combo, mult)
	technique.emit(kind, {"ear": ear, "freq": freq, "db": db, "combo": combo, "multiplier": mult, "points": gained})


## The tip for a technique kind, with this patient's pronouns ("" when there is none).
func tip_text(kind: StringName) -> String:
	var t: String = TIPS.get(kind, "")
	return patient.say(t) if patient != null else PatientProfile.pronouns(t, "he")


## counts_as_check: false for extra observations (timing, rhythm, blasts) that still break the
## combo and cost technique; true when the check was already counted (steps, stores).
func _error(kind: StringName, data: Dictionary, counts_as_check: bool) -> void:
	var d := data.duplicate()
	d["ear"] = ear
	d["freq"] = freq
	d["message"] = tip_text(kind)
	if not scoring:
		d["auto"] = true
		technique.emit(kind, d)
		return
	var mk := _mkey(ear, freq)
	_meas_errors[mk] = int(_meas_errors.get(mk, 0)) + 1
	if not counts_as_check:
		checks += 1
	errors.append({"kind": String(kind), "ear": ear, "freq": freq, "db": db, "message": d["message"]})
	if combo > 0:
		combo = 0
		combo_changed.emit(0, 1)
	technique.emit(kind, d)


## A lesson that is not a technique error (no combo break, no score change).
func _observe(kind: StringName, data: Dictionary) -> void:
	var d := data.duplicate()
	d["ear"] = ear
	d["freq"] = freq
	d["message"] = tip_text(kind)
	technique.emit(kind, d)
