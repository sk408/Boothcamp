class_name PatientSim
extends RefCounted
## PatientSim: the patient's "brain" (builder A). Decides whether a tone is heard, when the
## patient presses, and when they press for nothing. It never uses the player's ears.
##
## Model (test-content.md §3.1, air conduction only, no masking in this slice):
##   P(heard) = logistic((level - threshold) / slope) * (1 - lapse)
##   with slope ~1.7 dB and the 50 % point THRESHOLD_BIAS_DB (2 dB) below the profile threshold:
##   ~76 % at threshold, ~98 % at +5 dB, ~15 % at -5 dB (attentive patient).
##   lapse = inattention near threshold (attention drops a little with every tone: fatigue).
## Tricks a real patient plays, which the player must learn to handle:
##   - false alarms in silence (profile rate; x6 when nobody told them what to do),
##   - "groove": a steady rhythm of gaps makes them press on the beat (anticipation),
##   - very short gaps make them trigger-happy (a guess press without hearing anything),
##   - very short tones are often lost (temporal integration).
## Cross-hearing is out of scope (symmetric patient) but cross_hearing is the hook for it.

## Shift of the 50 % point below the profile threshold. A real 2-of-3 ascending search lands
## on or above the 50 % point (a coin flip between T and T+5 when the 50 % point sits exactly on
## T). The profile threshold is what a textbook clinician should write down, so the curve's 50 %
## point sits 2 dB lower: a by-the-book search then finds the profile value ~80 % of the time,
## and 5 dB either side (normal test-retest) otherwise. (Integrator, CONTRACTS.md §4.8.)
const THRESHOLD_BIAS_DB := 2.0
## Inattention only matters within this many dB above threshold: loud tones are always noticed.
const NEAR_RANGE_DB := 12.0
## How much of (1 - attention) turns into missed tones right at threshold.
const LAPSE_SCALE := 0.35
## Lowest attention fatigue can push the patient to.
const MIN_ATTENTION := 0.8
## Attention regained by a short break (between ears).
const BREAK_RECOVERY := 0.1
## Gaps shorter than this make a patient trigger-happy...
const SHORT_GAP_S := 0.6
## ...with this chance of a guess press on a tone they did not hear.
const SHORT_GAP_GUESS_P := 0.15
## Gaps whose spread (max - min) is below this count as a steady rhythm.
const STEADY_SPREAD_S := 0.3
## Groove at or above this makes the patient anticipate the next beat.
const ANTICIPATE_GROOVE := 0.5
## False alarms per minute are multiplied by this when the patient was never instructed.
const NOT_INSTRUCTED_FA_FACTOR := 6.0
## Extra reaction time right at threshold (people hesitate on faint tones).
const NEAR_THRESHOLD_EXTRA_S := 0.25
## Temporal integration: a tone this much shorter than min_tone_s loses up to this many dB.
const SHORT_TONE_PENALTY_DB := 12.0

var profile: PatientProfile
var rng := RandomNumberGenerator.new()
var attention: float = 1.0
## 0..1, how much the patient has "learned your groove".
var groove: float = 0.0
## false = the player skipped the instructions: the patient presses for every hum and tick.
var instructed: bool = true
## true = earphones on the wrong ears: a "right" tone actually plays into the left ear.
var swapped: bool = false
## Multiplies fatigue_per_tone (the comfy chair upgrade halves it).
var fatigue_scale: float = 1.0
## Hook for cross-hearing (not in this slice). Callable(ear: String, freq: int, db: int) -> float:
## the probability that the NON-test ear hears the tone. Invalid Callable = no cross-hearing.
var cross_hearing: Callable = Callable()

var _gaps: Array[float] = []


func _init(p: PatientProfile, seed_value: int = 0) -> void:
	profile = p
	rng.seed = seed_value if seed_value != 0 else randi()
	attention = p.attention if p != null else 1.0


## The threshold of the ear the tone really reaches (swapped earphones flip the ears).
func effective_threshold(ear: String, freq: int) -> int:
	var real_ear := ear
	if swapped:
		real_ear = "left" if ear == "right" else "right"
	return profile.get_threshold(real_ear, freq)


## Probability that a tone of this level is heard (0..1). penalty_db lowers the effective level
## (short tones). Pure: does not touch the RNG.
func hear_probability(ear: String, freq: int, db: int, penalty_db: float = 0.0) -> float:
	var thr := float(effective_threshold(ear, freq))
	var level := float(db) - penalty_db
	var slope := maxf(0.5, profile.psychometric_slope_db)
	var p := 1.0 / (1.0 + exp(-(level - thr + THRESHOLD_BIAS_DB) / slope))
	var near := clampf(1.0 - (level - thr) / NEAR_RANGE_DB, 0.0, 1.0)
	var lapse := (1.0 - attention) * LAPSE_SCALE * near
	p *= 1.0 - lapse
	if cross_hearing.is_valid():
		p = maxf(p, float(cross_hearing.call(ear, freq, db)))
	return clampf(p, 0.0, 1.0)


## How far above (+) or below (-) threshold a level is, for reactions (straining, blast).
func sensation_level(ear: String, freq: int, db: int) -> int:
	return db - effective_threshold(ear, freq)


## Decide at tone onset. gap_s = silence since the previous tone ended (< 0 = first tone).
## Returns {"heard": bool, "press": bool, "guess": bool, "latency_s": float}.
## press = the patient will press for this tone (heard, or a guess).
func on_tone_start(ear: String, freq: int, db: int, gap_s: float) -> Dictionary:
	if gap_s >= 0.0:
		_note_gap(gap_s)
	var p := hear_probability(ear, freq, db)
	var heard := rng.randf() < p
	var guess := false
	if not heard and gap_s >= 0.0 and gap_s < SHORT_GAP_S:
		guess = rng.randf() < SHORT_GAP_GUESS_P * (1.0 if instructed else 2.0)
	attention = maxf(MIN_ATTENTION, attention - profile.fatigue_per_tone * fatigue_scale)
	return {"heard": heard, "press": heard or guess, "guess": guess, "latency_s": reaction_time(ear, freq, db)}


## The tone ended after duration_s before the patient pressed. A too-short tone can be lost:
## re-decide with a temporal-integration penalty. Returns true if the press still happens.
func keeps_press_after_short_tone(ear: String, freq: int, db: int, duration_s: float) -> bool:
	if duration_s >= profile.min_tone_s:
		return true
	var shortfall := clampf(1.0 - duration_s / maxf(0.05, profile.min_tone_s), 0.0, 1.0)
	return rng.randf() < hear_probability(ear, freq, db, SHORT_TONE_PENALTY_DB * shortfall)


## Seconds from tone onset to the button press. Slower right at threshold.
func reaction_time(ear: String = "", freq: int = 0, db: int = 0) -> float:
	var t := rng.randf_range(profile.reaction_time_min_s, profile.reaction_time_max_s)
	if ear != "":
		var sl := float(sensation_level(ear, freq, db))
		t += NEAR_THRESHOLD_EXTRA_S * clampf(1.0 - sl / 10.0, 0.0, 1.0)
	return t


## Call every frame of silence (outside any response window). True = a press for nothing.
func false_alarm_tick(delta: float) -> bool:
	var rate := profile.false_alarms_per_minute / 60.0 * (1.0 + 3.0 * groove)
	if not instructed:
		rate *= NOT_INSTRUCTED_FA_FACTOR
	return rng.randf() < rate * delta


## Called when a tone ends. If the patient has caught the player's rhythm, returns the delay
## (seconds after this tone ended) at which they will press "on the beat", else -1.
func anticipation_delay() -> float:
	if groove < ANTICIPATE_GROOVE or _gaps.size() < 3:
		return -1.0
	if rng.randf() > groove * (0.4 + 0.6 * profile.rhythm_sensitivity):
		return -1.0
	var mean := 0.0
	for g: float in _gaps:
		mean += g
	mean /= _gaps.size()
	return maxf(0.2, mean + rng.randf_range(-0.12, 0.12))


## Spread (max - min) of the recent gaps, or -1 with too few gaps.
func gap_spread() -> float:
	if _gaps.size() < ClinicRules.RHYTHM_WINDOW:
		return -1.0
	return _gaps.max() - _gaps.min()


## A short break (the story moves to the other ear): some attention comes back.
func take_break() -> void:
	attention = minf(profile.attention, attention + BREAK_RECOVERY)
	reset_rhythm()


func reset_rhythm() -> void:
	_gaps.clear()
	groove = 0.0


func _note_gap(gap_s: float) -> void:
	_gaps.append(gap_s)
	while _gaps.size() > ClinicRules.RHYTHM_WINDOW:
		_gaps.pop_front()
	if _gaps.size() < 3:
		return
	var recent := _gaps.slice(-3)
	var spread: float = recent.max() - recent.min()
	if spread < STEADY_SPREAD_S:
		groove = minf(1.0, groove + 0.15 + 0.35 * profile.rhythm_sensitivity)
	else:
		groove = maxf(0.0, groove - 0.35)
