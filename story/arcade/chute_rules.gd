extends RefCounted
## ChuteRules (arcade, story-internal): Chart Chute's clock, ramp and scoring (docs/ARCADE.md).
## A run: WARMUP_CARDS untimed charts on two chutes, then RUN_S seconds where the next chart arrives
## the moment you sort one. Recognition on a clock is fine here (no beeping is timed), and reading
## still beats guessing: a wrong drop jams the belt and sends the chart back, HOOT HELP keeps the
## streak, and only accurate runs reach the high-score board.
##   const ChuteRules := preload("res://story/arcade/chute_rules.gd")

const ChartDeck := preload("res://story/arcade/chart_deck.gd")

const WARMUP_CARDS := 3
const RUN_S := 60.0
## When each chute opens (seconds into the run).
const UNLOCK_AT: Dictionary[StringName, float] = {&"sloping": 0.0, &"notch": 0.0, &"cookie_bite": 10.0, &"rising": 25.0, &"reverse_bite": 35.0,
	&"sensorineural": 0.0, &"conductive": 0.0, &"mixed": 15.0,
	&"tymp_a": 0.0, &"tymp_b": 0.0, &"tymp_as": 10.0, &"tymp_c": 20.0, &"tymp_ad": 30.0,
	&"deg_mild": 0.0, &"deg_moderate": 0.0, &"deg_modsevere": 10.0, &"deg_severe": 20.0, &"deg_profound": 30.0,
	&"flat_fluid": 0.0, &"flat_wax": 0.0, &"flat_hole": 10.0, &"flat_peak": 25.0,
	&"oto_clear": 0.0, &"oto_wax": 0.0, &"oto_fluid": 10.0, &"oto_hole": 20.0, &"oto_object": 30.0,
	&"mask_none": 0.0, &"mask_bone": 0.0, &"mask_both": 15.0}
## The ramp inside the run.
const LEFT_FROM_S := 30.0       ## left-ear (blue) cards join
const BOTH_FROM_S := 40.0       ## two-ear cards: sort the colour the card names
const LOOKALIKE_FROM_S := 40.0  ## the same shape with a trap in it
const GOLDEN_FROM_S := 50.0     ## one story patient's chart, worth x3
## Costs.
const JAM_S := 1.2              ## a wrong drop stops the belt while the tell shows
const HELP_S := 1.5             ## HOOT HELP shows the tell, then sorts the card for you
const REQUEUE_AFTER := 3        ## a wrongly dropped chart comes back this many cards later
## Points: POINTS x the streak multiplier (ClinicRules.combo_multiplier), x GOLDEN_FACTOR golden.
const POINTS := 100
const GOLDEN_FACTOR := 3
## FLUENT: this many right a minute with at most FLUENT_MAX_OOPS slips (precision-teaching style).
## A starting aim; tune it in playtests.
const FLUENT_RIGHT_PM := 25.0
const FLUENT_MAX_OOPS := 1
## Only runs this accurate go on the high-score board.
const BOARD_MIN_ACCURACY := 0.9


## The chutes open at run time t (seconds; t < 0 = the warm-up), in key order. belt: a key of
## ChartDeck.BELTS (&"shapes" for Chart Chute, &"types" for AIR & BONE).
static func unlocked(t: float, belt: StringName = &"shapes") -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StringName in ChartDeck.BELTS[belt]:
		if t < 0.0:
			if is_zero_approx(float(UNLOCK_AT[s])):
				out.append(s)
		elif t >= float(UNLOCK_AT[s]):
			out.append(s)
	return out


## (seeded) What the next card looks like at run time t: {"shape", "ear", "lookalike", "golden"}.
## recent: the last shapes dealt (a shape never comes three times running). golden_left: shapes
## whose story chart has not been dealt this run. The type belt has no two-ear cards (and no story
## charts: its golden_left is empty).
static func next_spec(rng: RandomNumberGenerator, t: float, recent: Array, golden_left: Array, belt: StringName = &"shapes") -> Dictionary:
	var open := unlocked(t, belt)
	if t >= GOLDEN_FROM_S:
		var g: Array = golden_left.filter(func(s: Variant) -> bool: return open.has(s))
		if g.size() > 1 and recent.size() >= 2 and recent[-1] == recent[-2]:
			g.erase(recent[-1])
		elif g.size() == 1 and recent.size() >= 2 and recent[-1] == recent[-2] and recent[-1] == g[0]:
			g = []   # it waits a card: never three of a shape running
		if not g.is_empty():
			return {"shape": g[rng.randi() % g.size()], "ear": "", "lookalike": false, "golden": true}
	# a newly opened chute gets the next card, so the player meets it straight away
	for s: StringName in open:
		if t >= 0.0 and float(UNLOCK_AT[s]) > 0.0 and not recent.has(s) and t - float(UNLOCK_AT[s]) < 4.0:
			return {"shape": s, "ear": "right", "lookalike": false, "golden": false}
	var choices: Array = open.duplicate()
	if recent.size() >= 2 and recent[-1] == recent[-2] and choices.size() > 1:
		choices.erase(recent[-1])
	var shape: StringName = choices[rng.randi() % choices.size()]
	var ear := "right"
	if belt == &"shapes" and t >= BOTH_FROM_S and rng.randf() < 0.3:
		ear = "both"
	elif t >= LEFT_FROM_S and rng.randf() < 0.4:
		ear = "left"
	return {"shape": shape, "ear": ear, "lookalike": t >= LOOKALIKE_FROM_S and rng.randf() < 0.4, "golden": false}


## Points for a right drop that makes the streak `streak_after` long.
static func points(streak_after: int, golden: bool) -> int:
	return POINTS * ClinicRules.combo_multiplier(streak_after) * (GOLDEN_FACTOR if golden else 1)


static func accuracy(right: int, oops: int) -> float:
	return float(right) / float(right + oops) if right + oops > 0 else 0.0


## Per-minute rates over a run of `seconds`.
static func per_minute(count: int, seconds: float = RUN_S) -> float:
	return count * 60.0 / maxf(seconds, 1.0)


static func fluent(right: int, oops: int, seconds: float = RUN_S) -> bool:
	return per_minute(right, seconds) >= FLUENT_RIGHT_PM and oops <= FLUENT_MAX_OOPS


static func on_board(right: int, oops: int) -> bool:
	return right > 0 and accuracy(right, oops) >= BOARD_MIN_ACCURACY


## The title on the results card.
static func rank(right: int, oops: int, seconds: float = RUN_S) -> String:
	if fluent(right, oops, seconds):
		return "Chart Whisperer"
	var acc := accuracy(right, oops)
	var pm := per_minute(right, seconds)
	if acc >= 0.9 and pm >= 15.0:
		return "Sharp Eye"
	if acc >= 0.8:
		return "Steady Sorter"
	if right + oops == 0:
		return "Belt Watcher"
	return "Jam Master"
