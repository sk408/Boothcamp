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

signal responded(ear: String, freq: int, db: int, tone_related: bool)
signal technique(kind: StringName, data: Dictionary)
signal combo_changed(n: int, multiplier: int)
signal stored_point(ear: String, freq: int, db: int, info: Dictionary)
signal reaction(kind: StringName, data: Dictionary)
## A presentation got its verdict (responded or missed). rec = public_record() shape.
signal presentation_closed(ear: String, freq: int, rec: Dictionary)

## Hoot's one-liners per technique kind (original wording, 18 words max, CONTRACTS.md §4.5).
const TIPS: Dictionary[StringName, String] = {
	&"wrong_step": "Heard it? Down 10. Missed it? Up 5. That's the whole dance!",
	&"start_too_high": "Start around 40 dB and work down. Ears aren't pinatas!",
	&"store_without_bracket": "Store only after two answers on the way UP at the same level.",
	&"store_wrong_level": "Threshold is the LOWEST level heard twice on the way up. Check your trail!",
	&"tone_too_short": "Was that a mosquito? Hold each beep for 1 to 2 seconds.",
	&"tone_too_long": "Long beeps make patients sleepy. 1 to 2 seconds is the sweet spot.",
	&"rhythmic": "He's learned your groove and presses on the beat! Vary the gaps between beeps.",
	&"too_loud": "Hair blast! Way above his threshold. Come back down gently.",
	&"retest_mismatch": "Retest is off by more than 5 dB: re-instruct him and recheck the earlier pitches.",
	&"start_not_1k": "Start each ear at 1000 Hz, the friendliest pitch in town.",
	&"missed_retest": "Before the low pitches, re-check 1000 Hz. Trust, but verify!",
	&"nr_too_early": "No response is only for a miss at the AudiOtron's loudest level.",
	&"marathon": "Tired patients guess. Bracket quickly and store!",
	&"store_far_off": "That stamp is far from his real hearing. Bracket carefully before you store.",
	&"not_instructed": "He's pressing for the air-con hum! Always say: press for EVERY beep.",
	&"phones_swapped": "He's pointing at the other ear. Red = Right!",
	&"short_gap": "Leave at least a beep's worth of quiet between beeps, or he guesses.",
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


func _init(p: PatientProfile, seed_value: int = 0) -> void:
	patient = p
	sim = PatientSim.new(p, seed_value)


# ---------------------------------------------------------------- controls

## Returns false if the ear did not change (tone on, or same ear).
func set_ear(e: String) -> bool:
	if tone_on or e == ear or not ClinicRules.EARS.has(e):
		return false
	ear = e
	return true


func step_freq(direction: int) -> bool:
	var i := ClinicRules.AC_FREQS.find(freq)
	var j := clampi(i + direction, 0, ClinicRules.AC_FREQS.size() - 1)
	return set_freq(ClinicRules.AC_FREQS[j])


func set_freq(f: int) -> bool:
	if tone_on or not ClinicRules.AC_FREQS.has(f) or f == freq:
		return false
	freq = f
	db = ClinicRules.clamp_db(db, freq)
	return true


## direction +1 = louder (higher dB HL), -1 = softer. Blocked while a tone plays: present
## discrete beeps and change the level between them. Returns false if nothing changed.
func step_level(direction: int) -> bool:
	if tone_on:
		return false
	var before := db
	db = ClinicRules.clamp_db(db + direction * ClinicRules.LEVEL_STEP_DB, freq)
	return db != before


func set_level(level: int) -> bool:
	if tone_on:
		return false
	var before := db
	db = ClinicRules.clamp_db(level, freq)
	return db != before


func tone_down() -> void:
	if tone_on:
		return
	_close_current()
	last_short = false
	var recs := _measurement_for_write(ear, freq)
	var first := recs.is_empty()
	if first:
		_start_ref["%s:%d" % [ear, freq]] = _compute_start(ear, freq)
	var gap := time - last_tone_end_t if last_tone_end_t > -50.0 else -1.0
	if recs.is_empty() and not sim.instructed and not _once.has("not_instructed"):
		_once["not_instructed"] = true
		_observe(&"not_instructed", {"db": db})
	_check_step(recs)
	_check_rhythm(gap)
	tone_on = true
	tone_start_t = time
	if scoring:
		presentations += 1
	else:
		auto_presentations += 1
	var decision := sim.on_tone_start(ear, freq, db, gap)
	var rec := {
		"i": recs.size(), "db": db, "t": time, "duration": 0.0, "responded": false, "closed": false,
		"ascending": _any_response(recs) and int(recs[-1]["db"]) < db and not bool(recs[-1]["responded"]),
		"heard": bool(decision["heard"]), "guess": bool(decision["guess"]), "anticipated": false,
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
		var key := "%s:%d" % [ear, freq]
		first = not _loud_hit.has(key)
		_loud_hit[key] = true
		_error(&"too_loud", {"db": db, "sl": sl, "comfort_loss": 1 if first and scoring else 0}, false)
		reaction.emit(&"too_loud_blast", {"ear": ear, "db": db, "intensity": clampf(float(sl) / 80.0, 0.3, 1.0)})
	elif sl >= -STRAIN_BELOW_DB and sl <= STRAIN_ABOVE_DB:
		reaction.emit(&"straining", {"ear": ear, "db": db, "intensity": 0.6})
	var strokes := recs.size()
	var marathon_at := int(ceil(par_for(ear, freq) * ClinicRules.MARATHON_FACTOR)) + 1
	if scoring and strokes == marathon_at and not _marathon_hit.has("%s:%d" % [ear, freq]):
		_marathon_hit["%s:%d" % [ear, freq]] = true
		_error(&"marathon", {"strokes": strokes}, false)
		reaction.emit(&"bored", {"ear": ear})


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
		presentation_closed.emit(_cur_ear, _cur_freq, public_record(_cur))


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
	if not tone_on and time > window_end_t and sim.false_alarm_tick(delta):
		_press(&"false_alarm")


## Store the current level as threshold. Returns the info dict (CONTRACTS.md §4.4).
func store() -> Dictionary:
	if tone_on:
		return {}
	_settle_before_store()
	var recs := measurement(ear, freq)
	var errs: Array[StringName] = []
	var candidate: Variant = ascending_threshold(ear, freq)
	if candidate == null:
		errs.append(&"store_without_bracket")
	elif int(candidate) != db:
		errs.append(&"store_wrong_level")
	var kind := measurement_kind(ear, freq)
	var st: Dictionary = stored[ear]
	if kind == &"first" and st.is_empty() and freq != ClinicRules.START_FREQ:
		errs.append(&"start_not_1k")
	if kind == &"first" and (freq == 500 or freq == 250) and st.has(1000) and (retest[ear] as Dictionary).is_empty():
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
	var top := ClinicRules.max_db(freq)
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
		"ascending": rec["ascending"], "duration": rec["duration"]}


## first / retest (1 kHz again after other frequencies) / redo (anything stored again).
func measurement_kind(e: String, f: int) -> StringName:
	var st: Dictionary = stored[e]
	if not st.has(f):
		return &"first"
	if f == ClinicRules.START_FREQ and (retest[e] as Dictionary).is_empty() and (order[e] as Array).size() >= 2:
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
func ascending_threshold(e: String, f: int) -> Variant:
	var counts := ascending_counts(e, f)
	var best: Variant = null
	for lvl: int in counts:
		var c: Array = counts[lvl]
		if int(c[0]) >= ClinicRules.ASCENDING_HITS_NEEDED and int(c[0]) * 2 >= int(c[1]):
			if best == null or lvl < int(best):
				best = lvl
	return best


## Ascending hits at a level in the open measurement (for "1 of 2" badges).
func ascending_hits(e: String, f: int, level: int) -> int:
	var c: Array = ascending_counts(e, f).get(level, [0, 0])
	return int(c[0])


## The textbook next level after these records (Hughson-Westlake), or -1 with no records.
static func expected_next_db(recs: Array, f: int) -> int:
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
	return mini(lvl + up, ClinicRules.max_db(f))


## What a textbook clinician would do next at the current ear/frequency (coach and hints).
## {"action": &"present" | &"softer" | &"louder" | &"store" | &"no_response" | &"wait" | &"release",
##  "target_db": int, "then": StringName}
func recommended_action() -> Dictionary:
	if tone_on:
		return {"action": &"release", "target_db": db, "then": &""}
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
	var top := ClinicRules.max_db(freq)
	if int(last["db"]) >= top and not bool(last["responded"]):
		return {"action": &"no_response", "target_db": top, "then": &""}
	var want := expected_next_db(recs, freq)
	if want != db:
		return {"action": &"louder" if want > db else &"softer", "target_db": want, "then": &"present"}
	return {"action": &"present", "target_db": want, "then": &""}


## Presentations a textbook search needs on a perfectly consistent patient (hears iff
## level >= threshold): familiarise (up 10 until heard), then down 10 / up 5 until a level is
## heard on 2 ascending runs, or the maximum output is missed (no response). Pure.
static func textbook_presentations(start_db: int, threshold: int, f: int) -> int:
	var top := ClinicRules.max_db(f)
	var level := ClinicRules.clamp_db(start_db, f)
	var hits: Dictionary = {}
	var prev_heard := true
	var any_hit := false
	var n := 0
	while n < 80:
		n += 1
		var heard := level >= threshold
		if heard:
			if not prev_heard and any_hit:
				hits[level] = int(hits.get(level, 0)) + 1
				if int(hits[level]) >= ClinicRules.ASCENDING_HITS_NEEDED:
					return n
			if level <= ClinicRules.MIN_DB and any_hit:
				return n  # heard at the very bottom of the scale: nothing softer to try
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
	var t := patient.get_threshold(e, f)
	var typical := expected_presentations(start - t, ClinicRules.max_db(f) - t, ClinicRules.MIN_DB - t, patient.psychometric_slope_db)
	return maxi(1, int(round(typical)) + PAR_SLACK)


## Where a textbook clinician starts the measurement at (e, f): 40 dB HL for the first 1 kHz of
## an ear; the stored 1 kHz threshold + 10 for the 1 kHz retest (never above START_DB); otherwise
## 10 dB above the previous stamp, clamped to 20..MAX_START_DB. Fixed once the measurement opens.
func recommended_start(e: String, f: int) -> int:
	var key := "%s:%d" % [e, f]
	if _start_ref.has(key):
		return int(_start_ref[key])
	return _compute_start(e, f)


func _compute_start(e: String, f: int) -> int:
	var st: Dictionary = stored[e]
	if measurement_kind(e, f) == &"retest":
		return ClinicRules.clamp_db(mini(int(st[1000]["stored_db"]) + 10, ClinicRules.START_DB), f)
	var ord: Array = order[e]
	if ord.is_empty():
		return ClinicRules.clamp_db(ClinicRules.START_DB, f)
	var last_f := int(ord[-1])
	var last_db := ClinicRules.START_DB
	if last_f == ClinicRules.START_FREQ and ord.count(ClinicRules.START_FREQ) >= 2 and not (retest[e] as Dictionary).is_empty():
		last_db = int(retest[e]["stored_db"])
	elif st.has(last_f):
		last_db = int(st[last_f]["stored_db"])
	return ClinicRules.clamp_db(clampi(last_db + 10, 20, ClinicRules.MAX_START_DB), f)


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
func required_remaining(e: String) -> Array[int]:
	var st: Dictionary = stored[e]
	var need := ClinicRules.required_interoctaves(stored_thresholds(e))
	var rem: Array[int] = []
	for f: int in [1000, 1500, 2000, 3000, 4000, 6000, 8000]:
		if (ClinicRules.is_octave(f) or need.has(f)) and not st.has(f):
			rem.append(f)
	if st.has(1000) and (retest[e] as Dictionary).is_empty():
		rem.append(1000)
	for f: int in [750, 500, 250]:
		if (ClinicRules.is_octave(f) or need.has(f)) and not st.has(f):
			rem.append(f)
	return rem


func is_ear_complete(e: String) -> bool:
	return not (stored[e] as Dictionary).is_empty() and required_remaining(e).is_empty()


## Required measurements of an ear: [done, total] (the retest counts as one).
func ear_progress(e: String) -> Array[int]:
	var rem := required_remaining(e).size()
	var st: Dictionary = stored[e]
	if not st.has(1000) and (retest[e] as Dictionary).is_empty():
		rem += 1  # the 1k retest is still ahead (required_remaining lists it once 1k is stored)
	var done := st.size() + (0 if (retest[e] as Dictionary).is_empty() else 1)
	return [done, done + rem]


func stored_thresholds(e: String) -> Dictionary:
	var out := {}
	for f: int in stored[e]:
		out[f] = int(stored[e][f]["stored_db"])
	return out


func build_results() -> Dictionary:
	var ears := {}
	var acc_sum := 0.0
	var acc_n := 0
	var strokes_total := 0
	var par_total := 0
	for e: String in ClinicRules.EARS:
		var st: Dictionary = stored[e]
		var strokes := 0
		var par := 0
		var fair := 0
		var hoot_holes := 0
		for m: Dictionary in _archive[e]:
			if bool(m.get("auto", false)):
				hoot_holes += 1
				continue
			strokes += int(m["strokes"])
			par += int(m["par"])
			# fair golf: a clean hole never counts over par (Gus wobbled), a slip never under
			var d := int(m["strokes"]) - int(m["par"])
			fair += mini(d, 0) if bool(m.get("clean", true)) else maxi(d, 0)
		var e_acc := 0.0
		var e_n := 0
		for f: int in st:
			if bool(st[f].get("by_hoot", false)):
				continue
			e_acc += float(st[f]["accuracy"])
			e_n += 1
		acc_sum += e_acc
		acc_n += e_n
		strokes_total += strokes
		par_total += par
		var thr := stored_thresholds(e)
		ears[e] = {
			"freqs": st.duplicate(true),
			"complete": is_ear_complete(e),
			"retest_1k": (retest[e] as Dictionary).duplicate(),
			"order": (order[e] as Array).duplicate(),
			"strokes": strokes,
			"par": par,
			"golf": fair,
			"golf_raw": strokes - par,
			"hoot_holes": hoot_holes,
			"birdies": _count_birdies(st),
			"accuracy": e_acc / e_n if e_n > 0 else 0.0,
			"shape": ClinicRules.classify_shape(thr),
			"pta": ClinicRules.pta(thr),
			"coached": bool(coached.get(e, false)),
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
	var recs: Array = (_open[_cur_ear] as Dictionary).get(_cur_freq, [])
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
			presentation_closed.emit(_cur_ear, _cur_freq, public_record(_cur))
		responded.emit(_cur_ear, _cur_freq, int(_cur["db"]), true)
		reaction.emit(&"grooving" if kind == &"anticipated" else &"heard", {"ear": _cur_ear, "db": int(_cur["db"])})
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
	presentation_closed.emit(_cur_ear, _cur_freq, public_record(_cur))


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
	var expected := expected_next_db(recs, freq)
	var ok := db == expected
	if not ok and not prev_heard:
		var any_hit := false
		for r: Dictionary in recs:
			if bool(r["responded"]):
				any_hit = true
		var top := ClinicRules.max_db(freq)
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
	var true_db := patient.get_threshold(ear, freq)
	var err_db := float(db - true_db)
	var acc := ClinicRules.accuracy_for_error(err_db)
	if no_response:
		acc = 1.0 if true_db > ClinicRules.max_db(freq) else 0.0
	var strokes := recs.size()
	var par := par_for(ear, freq)
	var responses: Array = []
	for r: Dictionary in recs:
		responses.append([int(r["db"]), bool(r["responded"])])
	var clean := errs.is_empty() and int(_meas_errors.get("%s:%d" % [ear, freq], 0)) == 0
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
		"masked": false,
		"order_index": (order[ear] as Array).size(),
		"candidate_db": int(candidate) if candidate != null else -1,
		"responses": responses,
	}


func _finish_store(info: Dictionary, errs: Array[StringName]) -> void:
	if scoring:
		checks += maxi(1, errs.size())
	for k: StringName in errs:
		_error(k, {"db": db}, true)
	if errs.is_empty():
		_clean(&"store_ok")
	if not bool(info["no_response"]) and absf(float(info["error_db"])) > 10.0:
		_observe(&"store_far_off", {"db": db})
	var e := ear
	var f := freq
	(_archive[e] as Array).append({"freq": f, "strokes": int(info["strokes"]), "par": int(info["par"]), "kind": "retest" if bool(info["retest"]) else ("redo" if bool(info["redo"]) else "first"), "auto": not scoring, "clean": bool(info.get("clean", true))})
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
	else:
		var before := ClinicRules.required_interoctaves(stored_thresholds(e))
		st[f] = info
		var after := ClinicRules.required_interoctaves(stored_thresholds(e))
		for io: int in after:
			if not before.has(io) and not st.has(io):
				technique.emit(&"interoctave_needed", {"ear": e, "freq": io})
	(order[e] as Array).append(f)
	(_open[e] as Dictionary).erase(f)
	var key := "%s:%d" % [e, f]
	_loud_hit.erase(key)
	_marathon_hit.erase(key)
	_meas_errors.erase(key)
	_start_ref.erase(key)
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


## counts_as_check: false for extra observations (timing, rhythm, blasts) that still break the
## combo and cost technique; true when the check was already counted (steps, stores).
func _error(kind: StringName, data: Dictionary, counts_as_check: bool) -> void:
	var d := data.duplicate()
	d["ear"] = ear
	d["freq"] = freq
	d["message"] = TIPS.get(kind, "")
	if not scoring:
		d["auto"] = true
		technique.emit(kind, d)
		return
	var mk := "%s:%d" % [ear, freq]
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
	d["message"] = TIPS.get(kind, "")
	technique.emit(kind, d)
