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
		"card": "skull_wall", "built": true},
	{"id": "when", "num": 2, "name": "When to mask?", "pitch": "Spot the cross-hearing risk.", "color": Color("#d99a2b"),
		"card": "when_to_mask", "built": false},
	{"id": "start", "num": 3, "name": "How much to start?", "pitch": "Set the noise dial.", "color": Color("#7d8398"),
		"card": "start_level", "built": false},
	{"id": "plateau", "num": 4, "name": "The plateau walk", "pitch": "Shhh up, or beep up?", "color": Color("#3a9d76"),
		"card": "plateau", "built": false},
	{"id": "occlusion", "num": 5, "name": "The occlusion effect", "pitch": "Why a covered ear booms.", "color": Color("#ff9f1c"),
		"card": "occlusion", "built": false},
	{"id": "exam", "num": 6, "name": "The masking exam", "pitch": "Nine holes, the whole job.", "color": Color("#8e5cc4"),
		"card": "", "built": false},
]

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
	var total := 0
	for k: String in TRANSDUCER_WEIGHTS:
		total += int(TRANSDUCER_WEIGHTS[k])
	var r := rng.randi_range(1, total)
	for k: String in TRANSDUCER_WEIGHTS:
		r -= int(TRANSDUCER_WEIGHTS[k])
		if r <= 0:
			return k
	return "phones"


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = a[i]
		a[i] = a[j]
		a[j] = tmp


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
