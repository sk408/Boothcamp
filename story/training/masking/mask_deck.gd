extends RefCounted
## MaskDeck (training, story-internal): the Masking School's stations, cheat-sheet cards and card
## generators (docs/training/MASKING_TRAINER.md). Pure data and pure functions: every number comes
## from ClinicRules, so the trainer always teaches what the story's audiometer scores.
##   const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
##   MaskDeck.who_heard({"transducer": "phones", "tone": 70, "test_thr": 20, "other_thr": 10})  # &"either"
##   MaskDeck.who_heard_round(rng)   # six honest "Who heard it?" cards

const LESSON := "masking"

## The six stations, in the suggested order (all open). built: playable in this version; the others
## show a "SOON" chip in the Training room until their PR lands. card: the cheat-sheet card it earns.
const STATIONS: Array = [
	{"id": "why", "num": 1, "name": "Why mask?", "pitch": "Ears cheat. Catch the Ghost!", "color": Color("#1f3a5f"),
		"card": "skull_wall", "built": true, "movie": "masking",
		"intro": "Ears cheat. A loud beep in one ear can sneak across the skull to the other.\n"
			+ "Learn the skull wall, then catch the Cross-Hearing Ghost: six beeps, who heard each one?"},
	{"id": "when", "num": 2, "name": "When to mask?", "pitch": "Spot the cross-hearing risk.", "color": Color("#d99a2b"),
		"card": "when_to_mask", "built": true, "movie": "",
		"intro": "Before every test, ask: could the other ear be answering?\n"
			+ "Two quick checks. Bone: a gap of 10 or more. Air: air minus the wall reaches the bone. Six charts: mask or not?"},
	{"id": "start", "num": 3, "name": "How much to start?", "pitch": "Set the noise dial.", "color": Color("#7d8398"),
		"card": "start_level", "built": true, "movie": "",
		"intro": "Masking on: how loud should the shhh start?\n"
			+ "The other ear's AIR plus 10. Bone at low pitches with a normal ear covered? Add the occlusion boom. Six dials to set."},
	{"id": "plateau", "num": 4, "name": "The plateau walk", "pitch": "Shhh up, or beep up?", "color": Color("#3a9d76"),
		"card": "plateau", "built": true, "movie": "",
		"intro": "Masking on, now walk it. Heard? Shhh up 5. Missed? Beep up 5.\n"
			+ "When the beep stays put through three shhh raises, that's the plateau: Righty's real bone. Three patients."},
	{"id": "occlusion", "num": 5, "name": "The occlusion effect", "pitch": "Why a covered ear booms.", "color": Color("#ff9f1c"),
		"card": "occlusion", "built": true, "movie": "plugged_ear",
		"intro": "Cover a normal ear and low bone tones get LOUDER in it. That's the occlusion effect.\n"
			+ "Play in the plug lab, call six cards (add it or not?), then fill the pocket card from memory."},
	{"id": "exam", "num": 6, "name": "The masking exam", "pitch": "Nine holes, the whole job.", "color": Color("#8e5cc4"),
		"card": "", "built": true, "movie": "",
		"intro": "Nine holes, all mixed: who heard it, mask it?, set the dial, a plateau walk, the boom, and a dilemma.\n"
			+ "No hints on a first try. Finish for the Masking School diploma; even par earns an S."},
]

## Holes in a station's round (the plateau walk deals three longer walks).
static func holes(station_id: String) -> int:
	match station_id:
		"plateau":
			return WALK_KINDS.size()
		"occlusion":
			return ROUND_HOLES + 1   # six "Does it count?" cards, then the pocket card
		"exam":
			return EXAM_RULES.size()
	return ROUND_HOLES


## Answers of "Who heard it?" (station 1), in key order 1-3.
const WHO: Array[StringName] = [&"test", &"ghost", &"either"]
const WHO_WORDS: Dictionary = {&"test": "THE TEST EAR", &"ghost": "THE OTHER EAR (GHOST!)", &"either": "COULD BE EITHER"}
const WHO_VERDICTS: Dictionary = {
	&"test": "Only the test ear: no Ghost this time.",
	&"ghost": "The Ghost answered! The test ear can't hear it.",
	&"either": "Could be either: that's why we mask.",
}
const TRANSDUCER_WORDS: Dictionary = {"phones": "Headphones", "inserts": "Inserts", "bone": "Bone buzzer"}
## Round length (holes) and the earphones a round deals, by weight.
const ROUND_HOLES := 6
const TRANSDUCER_WEIGHTS: Dictionary = {"phones": 3, "inserts": 2, "bone": 1}
## "Try it" (station 1): raise the beep until the other ear hears it through the wall. The test ear
## hears from far above that, so the first answer always comes from the Ghost.
const WHY_TRIES: Array = [
	{"transducer": "phones", "tone": 30, "test_thr": 90, "other_thr": 10,
		"line": "Headphones. Raise the beep. When does Lefty hear it through the wall?"},
	{"transducer": "inserts", "tone": 30, "test_thr": 90, "other_thr": 10,
		"line": "Now inserts. Deep foam tips make the wall thicker. Raise it again!"},
	{"transducer": "bone", "tone": 0, "test_thr": 50, "other_thr": 10,
		"line": "Now the bone buzzer. It shakes the whole skull. Raise it!"},
]
const TRY_STEP_DB := 5
## The loudest beep a dealt card uses (a teaching card, never near the dial's top).
const TONE_TOP_DB := 90
## Cheat-sheet cards: earned once per station round, pinned in the Training room.
const CARD_ORDER: Array[String] = ["skull_wall", "when_to_mask", "start_level", "plateau", "occlusion"]


## The station record by id ({} when unknown).
static func station(id: String) -> Dictionary:
	for s: Dictionary in STATIONS:
		if String(s["id"]) == id:
			return s
	return {}


static func station_ids() -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in STATIONS:
		out.append(String(s["id"]))
	return out


## A cheat-sheet card: {id, title, color, lines}. The numbers are read from ClinicRules.
static func cheat_card(id: String) -> Dictionary:
	var ia := ClinicRules.IA_RULE_DB
	match id:
		"skull_wall":
			return {"id": id, "title": "Skull Wall", "color": Color("#1f3a5f"), "ink": Palette.PAPER,
				"lines": ["Headphones %d." % ia[&"phones"], "Inserts %d." % ia[&"inserts"], "Bone %d." % ia[&"bone"],
					"Beep - wall reaches the other ear? Ghost!"]}
		"when_to_mask":
			return {"id": id, "title": "When to Mask", "color": Color("#f2b632"), "ink": Palette.INK,
				"lines": ["BONE: gap %d or more." % ClinicRules.BC_MASK_GAP_DB, "AIR: test air - wall", "reaches other bone."]}
		"start_level":
			return {"id": id, "title": "Start Level", "color": Color("#c9ccd6"), "ink": Palette.INK,
				"lines": ["Other ear's AIR + %d." % ClinicRules.MASK_SAFETY_DB, "Bone, low pitches:", "+ occlusion."]}
		"plateau":
			return {"id": id, "title": "Plateau", "color": Color("#5bc8a3"), "ink": Palette.INK,
				"lines": ["Heard: shhh +%d." % ClinicRules.MASK_STEP_DB, "Missed: beep +%d." % ClinicRules.LEVEL_STEP_DB,
					"Flat for %d = the truth." % (ClinicRules.MASK_STEP_DB * ClinicRules.PLATEAU_STEPS)]}
		"occlusion":
			var oe: Dictionary = ClinicRules.OCCLUSION_DB[&"phones"]
			return {"id": id, "title": "Occlusion Pocket Card", "color": Color("#ff9f1c"), "ink": Palette.INK,
				"lines": ["250 +%d, 500 +%d, 750 +%d, 1k +%d" % [oe[250], oe[500], oe[750], oe[1000]], "2k up: 0. Inserts: 0.",
					"Only bone, only a covered", "NORMAL ear."]}
	return {}


# ---------------------------------------------------------------- station 1: who heard it?

## The rule wall (interaural attenuation) for an earphone: headphones 40, inserts 55, bone 0.
static func wall(transducer: String) -> int:
	return ClinicRules.ia_rule(StringName(transducer))


## What reaches the other cochlea: the beep minus the wall.
static func crossed(card: Dictionary) -> int:
	return int(card["tone"]) - wall(String(card["transducer"]))


static func test_hears(card: Dictionary) -> bool:
	return int(card["tone"]) >= int(card["test_thr"])


## The other cochlea hears the crossed beep: the same rule as ClinicRules.ac_masking_needed
## (test level - IA >= the other ear's bone).
static func other_hears(card: Dictionary) -> bool:
	return ClinicRules.ac_masking_needed(int(card["tone"]), int(card["other_thr"]), StringName(String(card["transducer"])))


## &"test", &"ghost", &"either", or &"" when neither cochlea can hear the beep (never dealt).
static func who_heard(card: Dictionary) -> StringName:
	var a := test_hears(card)
	var b := other_hears(card)
	if a and b:
		return &"either"
	if a:
		return &"test"
	if b:
		return &"ghost"
	return &""


## The card holds with any one of its numbers 5 dB off (no answer hangs on test-retest wobble).
static func is_honest(card: Dictionary) -> bool:
	var want := who_heard(card)
	if want == &"":
		return false
	for key: String in ["tone", "test_thr", "other_thr"]:
		for d: int in [-5, 5]:
			var c := card.duplicate()
			c[key] = int(c[key]) + d
			if who_heard(c) != want:
				return false
	return true


## The two "why" lines under a revealed card: the test ear, then the crossing.
static func why_lines(card: Dictionary) -> Array[String]:
	var tone := int(card["tone"])
	var w := wall(String(card["transducer"]))
	var a := "Test ear: beep %d, it hears from %d. %s" % [tone, int(card["test_thr"]), "It hears it." if test_hears(card) else "Too soft for it."]
	var b := ""
	if w == 0:
		b = "Bone has no wall: %d reaches the other ear, which hears from %d. %s" % [tone, int(card["other_thr"]),
			"It hears it!" if other_hears(card) else "Too soft."]
	else:
		b = "Across the wall: %d - %d = %d. The other ear hears from %d. %s" % [tone, w, crossed(card), int(card["other_thr"]),
			"It hears it!" if other_hears(card) else "Too soft."]
	return [a, b]


## Hoot's hint for a card (costs a stroke).
static func hint_line(card: Dictionary) -> String:
	var w := wall(String(card["transducer"]))
	if w == 0:
		return "Bone: no wall. Does the beep reach the other ear's number? And the test ear's?"
	return "Take %d off the beep. Does that reach the other ear's number? And the test ear's?" % w


## The tone level at which the other cochlea first hears a "Try it" beep.
static func try_target(card: Dictionary) -> int:
	return int(card["other_thr"]) + wall(String(card["transducer"]))


## The loudest a "Try it" beep may go (the audiometer's output at 1 kHz on that transducer).
static func try_max(card: Dictionary) -> int:
	return ClinicRules.max_db_for(1000, StringName(String(card["transducer"])))


## One honest card with this answer (rng-driven; the test ear is Righty, as in the movie).
static func who_card(rng: RandomNumberGenerator, answer: StringName, transducer: String) -> Dictionary:
	var top := mini(TONE_TOP_DB, ClinicRules.max_db_for(1000, StringName(transducer)))
	for i in 400:
		var tone := 5 * rng.randi_range(2, top / 5)
		var test_thr := 5 * rng.randi_range(-1, 22)
		var other_thr := 5 * rng.randi_range(-1, 12)
		var c := {"transducer": transducer, "tone": tone, "test_thr": test_thr, "other_thr": other_thr, "ear": "right", "freq": 1000}
		if who_heard(c) == answer and is_honest(c) and test_thr <= ClinicRules.max_db_for(1000, &"phones"):
			return c
	# a fixed fallback per answer (never reached with the ranges above; tests check every pair)
	var fb := {&"test": [40, 20, 30], &"ghost": [70, 100, 10], &"either": [70, 20, 10]}
	var v: Array = fb[answer]
	return {"transducer": "phones", "tone": v[0], "test_thr": v[1], "other_thr": v[2], "ear": "right", "freq": 1000}


## A round: ROUND_HOLES cards, every answer at least once, the earphones by TRANSDUCER_WEIGHTS.
## (Bone "test only" happens too: no wall, but the other cochlea is the poorer one.)
static func who_heard_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var answers: Array[StringName] = WHO.duplicate()
	while answers.size() < ROUND_HOLES:
		answers.append(WHO[rng.randi_range(0, WHO.size() - 1)])
	_shuffle(answers, rng)
	var out: Array[Dictionary] = []
	for a: StringName in answers:
		out.append(who_card(rng, a, _pick_transducer(rng)))
	return out


static func _pick_transducer(rng: RandomNumberGenerator) -> String:
	return _pick_weighted(rng, TRANSDUCER_WEIGHTS)


static func _pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total := 0
	for k: String in weights:
		total += int(weights[k])
	var r := rng.randi_range(1, total)
	for k: String in weights:
		r -= int(weights[k])
		if r <= 0:
			return k
	return "phones"


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


# ---------------------------------------------------------------- station 2: mask it?

## Answers of "Mask it?" (station 2), in key order 1-3. Air alone never needs it here: the non-test
## ear's bone is the unmasked bone (the better cochlea), so a crossing air tone already means a gap
## of at least the wall, and bone needs masking too (&"air" is never dealt).
const CALLS: Array[StringName] = [&"none", &"bone", &"both"]
const CALL_WORDS: Dictionary = {&"none": "NO MASKING", &"bone": "MASK BONE ONLY", &"both": "MASK BONE AND AIR"}
const CALL_VERDICTS: Dictionary = {
	&"none": "No masking: no gap, and air can't reach.",
	&"bone": "Mask the bone test. Air is safe.",
	&"both": "Mask both: bone AND air!",
}
const WHEN_FREQS: Array[int] = [500, 1000, 2000, 4000]
## Station 2's earphones: headphones on two cards in three, inserts on the third.
const WHEN_WEIGHTS: Dictionary = {"phones": 2, "inserts": 1}
## "Try it" (station 2): Hoot walks three charts, one check at a time. The middle one is the first
## one with inserts on: the thicker wall saves the air test.
const WHEN_TRIES: Array = [
	{"transducer": "phones", "freq": 1000, "air": 75, "bone": 20, "other_air": 25,
		"line": "Bone first. Righty's air minus the bone: a gap of 10 or more?"},
	{"transducer": "inserts", "freq": 1000, "air": 65, "bone": 20, "other_air": 25,
		"line": "Same ear, inserts on. Gap check, then air minus a thicker wall."},
	{"transducer": "phones", "freq": 2000, "air": 40, "bone": 40, "other_air": 45,
		"line": "One more. Is there any gap at all?"},
]


## The test ear's air-bone gap (air minus the unmasked bone).
static func gap(card: Dictionary) -> int:
	return int(card["air"]) - int(card["bone"])


## Masked bone needed: ClinicRules.bc_masking_needed (a gap of 10 or more).
static func mask_bone(card: Dictionary) -> bool:
	return ClinicRules.bc_masking_needed(int(card["air"]), int(card["bone"]))


## Masked air needed: ClinicRules.ac_masking_needed (air minus the wall reaches the other ear's bone,
## here the unmasked bone: the best the other cochlea can be).
static func mask_air(card: Dictionary) -> bool:
	return ClinicRules.ac_masking_needed(int(card["air"]), int(card["bone"]), StringName(String(card["transducer"])), int(card["freq"]))


## &"none", &"bone", &"both" (or &"air", never dealt).
static func mask_call(card: Dictionary) -> StringName:
	var b := mask_bone(card)
	var a := mask_air(card)
	if a and b:
		return &"both"
	if b:
		return &"bone"
	if a:
		return &"air"
	return &"none"


## The call holds with either reading 5 dB off.
static func when_honest(card: Dictionary) -> bool:
	var want := mask_call(card)
	for key: String in ["air", "bone"]:
		for d: int in [-5, 5]:
			var c := card.duplicate()
			c[key] = int(c[key]) + d
			if mask_call(c) != want:
				return false
	return true


## One honest "Mask it?" chart with this call (Righty is the test ear).
static func when_card(rng: RandomNumberGenerator, answer: StringName, transducer: String) -> Dictionary:
	for i in 400:
		var f: int = WHEN_FREQS[rng.randi_range(0, WHEN_FREQS.size() - 1)]
		var bone := 5 * rng.randi_range(0, mini(8, (ClinicRules.BC_MAX_DB[f] - 10) / 5))
		var air := bone + 5 * rng.randi_range(0, 15)
		if air > mini(TONE_TOP_DB, ClinicRules.max_db(f)) or air < 0:
			continue
		var c := {"transducer": transducer, "freq": f, "air": air, "bone": bone, "other_air": bone + 5 * rng.randi_range(0, 3), "ear": "right"}
		if mask_call(c) == answer and when_honest(c):
			return c
	var fb := {&"none": [30, 30], &"bone": [50, 20], &"both": [80, 20]}
	var v: Array = fb[answer]
	return {"transducer": "phones", "freq": 1000, "air": v[0], "bone": v[1], "other_air": v[1] + 5, "ear": "right"}


## A round: ROUND_HOLES charts, every call at least once.
static func when_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var answers: Array[StringName] = CALLS.duplicate()
	while answers.size() < ROUND_HOLES:
		answers.append(CALLS[rng.randi_range(0, CALLS.size() - 1)])
	_shuffle(answers, rng)
	var out: Array[Dictionary] = []
	for a: StringName in answers:
		out.append(when_card(rng, a, _pick_weighted(rng, WHEN_WEIGHTS)))
	return out


## The two checks under a revealed chart: bone, then air.
static func when_lines(card: Dictionary) -> Array[String]:
	var g := gap(card)
	var w := wall(String(card["transducer"]))
	var a := "BONE: %d - %d = a gap of %d. %s" % [int(card["air"]), int(card["bone"]), g,
		"10 or more: mask bone." if mask_bone(card) else "Under 10: no bone masking."]
	var b := "AIR: %d - %d wall = %d. Bone is %d. %s" % [int(card["air"]), w, int(card["air"]) - w, int(card["bone"]),
		"It reaches: mask air too!" if mask_air(card) else "Can't reach it: air is safe."]
	return [a, b]


static func when_hint(card: Dictionary) -> String:
	return "Gap first: air minus bone. Then air minus the %d wall: does it reach the bone?" % wall(String(card["transducer"]))


# ---------------------------------------------------------------- station 3: set the dial

## The dial's step and range (the audiometer's masker).
const DIAL_STEP_DB := ClinicRules.MASK_STEP_DB
const START_KINDS: Array[String] = ["air", "boom", "boom", "high", "blocked", "inserts"]
const MASKER_WORDS: Dictionary = {"phones": "headphone", "inserts": "insert"}
## "Try it" (station 3): Hoot names the sum, the player turns the dial to it.
const START_TRIES: Array = [
	{"test": "ac", "freq": 2000, "other_air": 15, "other_gap": 0, "masker": "phones",
		"line": "Air test. Lefty's air is 15. Add 10: turn the shhh to 25."},
	{"test": "bc", "freq": 500, "other_air": 15, "other_gap": 0, "masker": "phones",
		"line": "Bone at 500, Lefty normal and covered: it booms. 15 + 10 + 15 = 40."},
	{"test": "bc", "freq": 500, "other_air": 15, "other_gap": 0, "masker": "inserts",
		"line": "Same, but an insert masker. Deep foam: no boom. 15 + 10 = 25."},
]


static func is_bone_test(card: Dictionary) -> bool:
	return String(card["test"]) == "bc"


## The occlusion add-on in this start level (0 for air, high pitches, a blocked ear or inserts).
static func boom(card: Dictionary) -> int:
	if not is_bone_test(card) or int(card["other_gap"]) > ClinicRules.OCCLUSION_MAX_GAP_DB:
		return 0
	return ClinicRules.occlusion_effect(int(card["freq"]), StringName(String(card["masker"])))


## The right start level: ClinicRules.initial_masking.
static func start_level(card: Dictionary) -> int:
	return ClinicRules.initial_masking(int(card["other_air"]), int(card["freq"]), &"bc" if is_bone_test(card) else &"ac",
		int(card["other_gap"]), StringName(String(card["masker"])))


## Strokes for a dial setting: on the dot is par, one step off a bogey, more a double bogey.
static func dial_strokes(dial_db: int, card: Dictionary) -> int:
	var off := absi(dial_db - start_level(card))
	if off == 0:
		return 1
	return 2 if off <= DIAL_STEP_DB else 3


## One "Set the dial" card of a kind: air, boom (low bone, normal covered ear, headphones), high
## (bone at 2k and up), blocked (low bone, the covered ear has its own gap), inserts (low bone).
static func start_card(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	var low: Array[int] = [250, 500, 750, 1000]
	var c := {"test": "bc", "masker": "phones", "other_gap": 5 * rng.randi_range(0, 1), "ear": "right"}
	var other_bone := 5 * rng.randi_range(0, 6)
	match kind:
		"air":
			c["test"] = "ac"
			c["freq"] = [250, 500, 1000, 2000, 4000, 8000][rng.randi_range(0, 5)]
			c["masker"] = "inserts" if rng.randi_range(0, 2) == 0 else "phones"
		"high":
			c["freq"] = [2000, 3000, 4000][rng.randi_range(0, 2)]
		"blocked":
			c["freq"] = low[rng.randi_range(0, 3)]
			c["other_gap"] = 5 * rng.randi_range(4, 7)
			other_bone = 5 * rng.randi_range(0, 3)
		"inserts":
			c["freq"] = low[rng.randi_range(0, 3)]
			c["masker"] = "inserts"
		_:
			c["freq"] = low[rng.randi_range(0, 3)]
	c["other_air"] = other_bone + int(c["other_gap"])
	c["kind"] = kind
	return c


## A round: one card of each START_KINDS (the boom twice), shuffled.
static func start_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var kinds: Array[String] = START_KINDS.duplicate()
	_shuffle(kinds, rng)
	var out: Array[Dictionary] = []
	for k: String in kinds:
		out.append(start_card(rng, k))
	return out


## Why there is (or isn't) an occlusion add-on, in one line.
static func boom_line(card: Dictionary) -> String:
	var b := boom(card)
	if b > 0:
		return "+ %d occlusion: low bone tone, normal ear covered by a headphone." % b
	if not is_bone_test(card):
		return "No occlusion add-on: this is an air test."
	if int(card["other_gap"]) > ClinicRules.OCCLUSION_MAX_GAP_DB:
		return "No occlusion: Lefty's middle ear is blocked already (gap %d)." % int(card["other_gap"])
	if String(card["masker"]) == "inserts":
		return "No occlusion: the insert sits deep in the canal."
	return "No occlusion at %d Hz: 2k and up has none." % int(card["freq"])


## The sum under a revealed dial.
static func start_lines(card: Dictionary) -> Array[String]:
	var b := boom(card)
	var sum := "Lefty's air %d + %d = %d" % [int(card["other_air"]), ClinicRules.MASK_SAFETY_DB, start_level(card)]
	if b > 0:
		sum = "Lefty's air %d + %d + %d = %d" % [int(card["other_air"]), ClinicRules.MASK_SAFETY_DB, b, start_level(card)]
	return ["%s. Start the shhh at %d." % [sum, start_level(card)], boom_line(card)]


static func start_hint(card: Dictionary) -> String:
	return "Lefty's air plus 10. Then: bone, low pitch, normal ear under a headphone? Add the boom."


# ---------------------------------------------------------------- station 4: the plateau walk

## The moves of a masked bone walk, in key order 1-4.
const MOVES: Array[StringName] = [&"shhh", &"beep", &"store", &"nosafe"]
const MOVE_WORDS: Dictionary = {&"shhh": "SHHH UP 5", &"beep": "BEEP UP 5", &"store": "STORE IT", &"nosafe": "NO SAFE LEVEL"}
## A walk round: three practice patients, one of each kind (shuffled): the tone shifts up before it
## plateaus, the first answer was the truth (flat from the start), and a dilemma (no safe window).
const WALK_KINDS: Array[String] = ["shift", "true", "dilemma"]
const WALK_FREQS: Array[int] = [500, 1000, 2000, 4000]
## The longest walk a dealt patient may need (moves), so a round stays bite-size.
const WALK_MAX_MOVES := 14
## "Try it" (station 4): Hoot walks one patient, a step per press.
const WALK_TRIES: Array = [
	{"kind": "shift", "freq": 1000, "t_test": 30, "t_other": 10, "gap_other": 0, "masker": "phones",
		"line": "Righty's bone, masked. Press Next step and watch the board."},
]


## The non-test (covered) ear's air: its cochlea plus its own gap.
static func walk_other_air(p: Dictionary) -> int:
	return int(p["t_other"]) + int(p["gap_other"])


## The masker's first level: ClinicRules.initial_masking for bone.
static func walk_initial(p: Dictionary) -> int:
	return ClinicRules.initial_masking(walk_other_air(p), int(p["freq"]), &"bc", int(p["gap_other"]), StringName(String(p["masker"])))


## The first masked tone: the unmasked bone threshold (the better cochlea).
static func walk_start_tone(p: Dictionary) -> int:
	return mini(int(p["t_test"]), int(p["t_other"]))


## Overmasking starts here for a bone tone at this level: ClinicRules.overmask_limit.
static func walk_limit(p: Dictionary, tone: int) -> int:
	return ClinicRules.overmask_limit(tone, &"bc", 0, StringName(String(p["masker"])))


static func walk_dilemma(p: Dictionary) -> bool:
	return ClinicRules.masking_dilemma(walk_initial(p), walk_limit(p, walk_start_tone(p)))


## The practice patient (a drawn cartoon: the player's own hearing is never tested). A bone tone
## reaches both cochleas (no wall). The covered ear hears it with its occlusion boost unless the noise
## covers it (noise minus its own gap reaches its cochlea); the test cochlea hears it unless noise
## crosses back over the wall onto it (overmasking).
static func walk_hears(p: Dictionary, tone: int, mask: int) -> bool:
	var masker := StringName(String(p["masker"]))
	var oe := ClinicRules.occlusion_effect(int(p["freq"]), masker) if int(p["gap_other"]) <= ClinicRules.OCCLUSION_MAX_GAP_DB else 0
	var other := tone + oe >= maxi(int(p["t_other"]), mask - int(p["gap_other"]))
	var test := tone >= maxi(int(p["t_test"]), mask - ClinicRules.ia_rule(masker))
	return other or test


## The first presentation: the start tone with the initial masking.
static func walk_first(p: Dictionary) -> Array[Dictionary]:
	var tone := walk_start_tone(p)
	var mask := walk_initial(p)
	return [{"db": tone, "mask_db": mask, "responded": walk_hears(p, tone, mask)}]


## The textbook move after the presentations so far (ClinicRules.next_mask_step, plateau_run).
static func walk_move(p: Dictionary, records: Array) -> StringName:
	if walk_dilemma(p):
		return &"nosafe"
	if not bool((records.back() as Dictionary)["responded"]):
		return &"beep"
	if int(ClinicRules.plateau_run(records)["steps"]) >= ClinicRules.PLATEAU_STEPS:
		return &"store"
	return &"shhh"


## Play a SHHH UP or BEEP UP move: the next presentation and the patient's answer.
static func walk_apply(p: Dictionary, records: Array, move: StringName) -> void:
	var last: Dictionary = records.back()
	var nx := ClinicRules.next_mask_step(int(last["db"]), int(last["mask_db"]), move == &"shhh")
	records.append({"db": nx.x, "mask_db": nx.y, "responded": walk_hears(p, nx.x, nx.y)})


## The whole textbook walk: {records, moves (count), stored (the threshold, or -1 for no safe level)}.
static func walk_textbook(p: Dictionary) -> Dictionary:
	var records := walk_first(p)
	var moves := 0
	while moves < 60:
		var m := walk_move(p, records)
		moves += 1
		if m == &"store":
			return {"records": records, "moves": moves, "stored": int((records.back() as Dictionary)["db"])}
		if m == &"nosafe":
			return {"records": records, "moves": moves, "stored": -1}
		walk_apply(p, records, m)
	return {"records": records, "moves": moves, "stored": -2}


## The textbook walk stays inside the green window: masker at or over the start level, under the
## overmasking limit, and the stored level is the test cochlea's own.
static func walk_honest(p: Dictionary) -> bool:
	var w := walk_textbook(p)
	if String(p["kind"]) == "dilemma":
		return walk_dilemma(p) and int(w["stored"]) == -1
	if walk_dilemma(p) or int(w["stored"]) != int(p["t_test"]) or int(w["moves"]) > WALK_MAX_MOVES:
		return false
	for r: Dictionary in w["records"]:
		if int(r["mask_db"]) >= walk_limit(p, int(r["db"])) or int(r["mask_db"]) > ClinicRules.MASK_MAX_DB:
			return false
		if int(r["db"]) > ClinicRules.BC_MAX_DB[int(p["freq"])] - 5:
			return false
	return true


## One practice patient of a kind (Righty tested on bone, a headphone masker on Lefty).
static func walk_patient(rng: RandomNumberGenerator, kind: String) -> Dictionary:
	for i in 400:
		var p := {"kind": kind, "masker": "phones", "freq": WALK_FREQS[rng.randi_range(0, WALK_FREQS.size() - 1)]}
		match kind:
			"dilemma":
				p["t_other"] = 5 * rng.randi_range(0, 2)
				p["gap_other"] = 5 * rng.randi_range(7, 10)
				p["t_test"] = int(p["t_other"]) + 5 * rng.randi_range(0, 2)
			"true":
				p["t_other"] = 5 * rng.randi_range(1, 5)
				p["gap_other"] = 5 * rng.randi_range(0, 1)
				p["t_test"] = int(p["t_other"]) - 5 * rng.randi_range(0, 2)
			_:
				p["t_other"] = 5 * rng.randi_range(0, 3)
				p["gap_other"] = 5 * rng.randi_range(0, 1)
				p["t_test"] = int(p["t_other"]) + 5 * rng.randi_range(3, 7)
		if walk_honest(p) and (kind != "true" or walk_start_tone(p) == int(p["t_test"])):
			return p
	var fb := {"shift": [30, 10, 0], "true": [20, 20, 0], "dilemma": [5, 5, 45]}
	var v: Array = fb.get(kind, fb["shift"])
	return {"kind": kind, "masker": "phones", "freq": 1000, "t_test": v[0], "t_other": v[1], "gap_other": v[2]}


static func walk_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var kinds: Array[String] = WALK_KINDS.duplicate()
	_shuffle(kinds, rng)
	var out: Array[Dictionary] = []
	for k: String in kinds:
		out.append(walk_patient(rng, k))
	return out


## Hoot's line for a wrong move (what the right one is, and why).
static func walk_nudge(want: StringName) -> String:
	match want:
		&"shhh":
			return "Heard it! Heard means shhh up 5. Is it still there?"
		&"beep":
			return "No answer. Missed means beep up 5."
		&"store":
			return "Heard through three shhh raises in a row. That's the plateau: store it!"
	return "Look at the board: the shhh is already too much at the start. No safe level."


static func walk_hint(p: Dictionary) -> String:
	if walk_dilemma(p):
		return "Where is the green window? Start shhh at %d, too much from %d." % [walk_initial(p), walk_limit(p, walk_start_tone(p))]
	return "Heard? Shhh up. Missed? Beep up. Heard on three raises in a row? Store."


## The two lines under a finished walk.
static func walk_lines(p: Dictionary) -> Array[String]:
	if walk_dilemma(p):
		return ["Start shhh %d, but %d already crosses back: %d + %d wall." % [walk_initial(p), walk_limit(p, walk_start_tone(p)),
				walk_start_tone(p), ClinicRules.ia_rule(StringName(String(p["masker"])))],
			"A masking dilemma: store nothing. Inserts' thicker wall may open a window."]
	var t := int(p["t_test"])
	var a := "Plateau at %d dB: three shhh raises (%d dB) and the beep held." % [t, ClinicRules.MASK_STEP_DB * ClinicRules.PLATEAU_STEPS]
	if t == walk_start_tone(p):
		return [a, "It was Righty all along: the first answer was the truth."]
	return [a, "Righty's real bone is %d, not %d. Lefty was answering before." % [t, walk_start_tone(p)]]


# ---------------------------------------------------------------- station 5: the occlusion effect

## The plug lab's covers, in key order 1-3 (a blocked ear is the movie's and the cards' fourth case).
const COVERS: Array[String] = ["open", "phones", "insert"]
const COVER_WORDS: Dictionary = {"open": "OPEN", "phones": "HEADPHONE", "insert": "DEEP INSERT", "blocked": "BLOCKED EAR"}
## The pocket card's columns, and its rows (the masker on the covered ear).
const OE_FREQS: Array[int] = [250, 500, 750, 1000, 2000, 4000]
const OE_ROWS: Array[String] = ["phones", "inserts"]
## The tiles the player places, in key order 1-3.
const OE_TILES: Array[int] = [0, 10, 15]
## Answers of "Does it count?", in key order 1-2.
const COUNTS: Array[StringName] = [&"add", &"skip"]
const COUNT_WORDS: Dictionary = {&"add": "ADD IT", &"skip": "NOT THIS TIME"}
## "Try it" (station 5): the plug lab, three things to set.
const PLUG_TRIES: Array = [
	{"cover": "phones", "freq": 500, "start_cover": "open", "start_freq": 250,
		"line": "Put the HEADPHONE on, then pick 500. Watch the meter."},
	{"cover": "phones", "freq": 2000, "start_cover": "phones", "start_freq": 500,
		"line": "Same headphone. Now pick 2k. Does it still boom?"},
	{"cover": "insert", "freq": 500, "start_cover": "phones", "start_freq": 2000,
		"line": "Swap to a DEEP INSERT, back at 500."},
]
## The pocket card's helper cells (already filled in) by visit: fewer each time, none from the third.
const OE_PREFILLED: Array[int] = [8, 4, 0]


## How much louder a bone tone gets in the ear under this cover (dB): ClinicRules.occlusion_effect
## for a headphone or insert on a normal ear; open, or a blocked ear (its own gap), adds nothing.
static func oe_boost(cover: String, freq: int) -> int:
	match cover:
		"phones":
			return ClinicRules.occlusion_effect(freq, &"phones")
		"insert", "inserts":
			return ClinicRules.occlusion_effect(freq, &"inserts")
	return 0


## A pocket-card cell's right tile.
static func oe_cell(row: String, freq: int) -> int:
	return oe_boost(row, freq)


static func oe_freq_word(freq: int) -> String:
	return "%dk" % (freq / 1000) if freq >= 1000 else str(freq)


## Why a pocket-card cell holds what it holds (shown when a tile bounces back).
static func oe_reason(row: String, freq: int) -> String:
	if row == "inserts":
		return "Inserts sit deep: almost no air to boom. +0 at every pitch."
	var b := oe_cell(row, freq)
	if b == 0:
		return "%s is high: quick waves don't boom. +0." % oe_freq_word(freq)
	if b == 15:
		return "%s is the lowest: big slow waves. +15." % oe_freq_word(freq)
	return "%s: still low, a bit less boom. +10." % oe_freq_word(freq)


## How many cells start filled on this visit (plays so far).
static func oe_prefilled(plays: int) -> int:
	return OE_PREFILLED[clampi(plays, 0, OE_PREFILLED.size() - 1)]


## The cells to fill, [{row, freq}], in a shuffled order, leaving `prefilled` of the 12 filled.
static func oe_blanks(rng: RandomNumberGenerator, prefilled: int) -> Array[Dictionary]:
	var cells: Array[Dictionary] = []
	for row: String in OE_ROWS:
		for f: int in OE_FREQS:
			cells.append({"row": row, "freq": f})
	_shuffle(cells, rng)
	return cells.slice(prefilled)


## "Does it count?": the answer for a card (start_card's shape): the boom is added only for bone, at
## a low pitch, with a headphone on a normal covered ear.
static func count_answer(card: Dictionary) -> StringName:
	return &"add" if boom(card) > 0 else &"skip"


## Six "Does it count?" cards: one of each START_KINDS (two that count), shuffled.
static func count_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	return start_round(rng)


static func count_hint(card: Dictionary) -> String:
	return "Four checks: bone? Low pitch? Normal ear? Covered by a headphone? All four: add it."


# ---------------------------------------------------------------- golf

## A hole's name from its strokes (par is one clean answer).
static func hole_name(strokes: int) -> String:
	match strokes:
		1:
			return "Par"
		2:
			return "Bogey"
		3:
			return "Double bogey"
	return "Triple bogey"


## "Even par", "+2"...
static func round_name(over_par: int) -> String:
	return "Even par" if over_par <= 0 else "+%d" % over_par


# ---------------------------------------------------------------- station 6: the exam

## The exam's nine holes by the station whose rules they use (a card's "rules" key): two "Who heard it?",
## two "Mask it?", two dials, one plateau walk, one "Does it count?" and one masking dilemma (a walk).
const EXAM_RULES: Array[String] = ["why", "why", "when", "when", "start", "start", "plateau", "occlusion", "dilemma"]
## The exam's grade from strokes over par: S at even par, then A, B, C (a finished exam always earns the
## diploma; its stamp shows the best grade).
const EXAM_GRADES: Array = [[0, "S"], [2, "A"], [5, "B"]]


static func exam_grade(over_par: int) -> String:
	for g: Array in EXAM_GRADES:
		if over_par <= int(g[0]):
			return String(g[1])
	return "C"


## Nine mixed holes. Each card is its station's own card plus "rules" (the station id whose rules it
## plays by; the dilemma is a plateau walk). Pairs never repeat an answer, so the exam covers each idea.
static func exam_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var who: Array[StringName] = WHO.duplicate()
	_shuffle(who, rng)
	var calls: Array[StringName] = CALLS.duplicate()
	_shuffle(calls, rng)
	var starts: Array[String] = ["air", "high", "blocked", "inserts"]
	_shuffle(starts, rng)
	for i in 2:
		out.append(_ruled(who_card(rng, who[i], _pick_transducer(rng)), "why"))
		out.append(_ruled(when_card(rng, calls[i], _pick_weighted(rng, WHEN_WEIGHTS)), "when"))
	out.append(_ruled(start_card(rng, "boom"), "start"))
	out.append(_ruled(start_card(rng, starts[0]), "start"))
	out.append(_ruled(walk_patient(rng, ["shift", "true"][rng.randi_range(0, 1)]), "plateau"))
	out.append(_ruled(start_card(rng, "boom" if rng.randf() < 0.5 else starts[1]), "occlusion"))
	out.append(_ruled(walk_patient(rng, "dilemma"), "plateau"))
	_shuffle(out, rng)
	return out


static func _ruled(card: Dictionary, rules: String) -> Dictionary:
	card["rules"] = rules
	return card


## The exam card's short label for the top bar ("Mask it?").
static func exam_label(card: Dictionary) -> String:
	var r := String(card.get("rules", ""))
	if r == "plateau" and walk_dilemma(card):
		return "a tricky walk"
	return {"why": "who heard it?", "when": "mask it?", "start": "set the dial", "plateau": "walk it", "occlusion": "does it count?"}.get(r, "") as String

