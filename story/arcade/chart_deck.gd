extends RefCounted
## ChartDeck (arcade, story-internal): seeded audiograms for Chart Chute (docs/ARCADE.md). Every
## chart is labelled by shape_of (ClinicRules.classify_shape, the same rule the story's reveals use,
## plus the reverse cookie bite) and kept clear of its edges: the shape still holds if any one frequency is 5 dB off, so a right answer is
## never a coin toss. Pure and static apart from the RandomNumberGenerator it is handed.
##   const ChartDeck := preload("res://story/arcade/chart_deck.gd")
##   var card := ChartDeck.make_card(rng, &"notch", {"ear": "right", "lookalike": false}, 7)
##   card = {"shape", "ear" (right | left | both), "sort_ear", "ac": {ear: {freq: dB}}, "name",
##           "look", "who", "golden", "line", "serial", "other_shape" (two-ear cards, else &"")}
##   ChartDeck.stable(thresholds, shape)    # the margin check every card passes
##   ChartDeck.golden_card(&"notch", 3)     # a story patient's own chart (Rocco's notch)

## The chutes, in key order (1-5).
const SHAPES: Array[StringName] = [&"sloping", &"notch", &"cookie_bite", &"rising", &"reverse_bite"]
## One word under each chute's picture.
const CHUTE_WORDS: Dictionary[StringName, String] = {&"sloping": "SLOPE", &"notch": "NOTCH", &"cookie_bite": "COOKIE BITE", &"rising": "RISING",
	&"reverse_bite": "REVERSE BITE", &"sensorineural": "SENSORINEURAL", &"conductive": "CONDUCTIVE", &"mixed": "MIXED",
	&"tymp_a": "TYPE A", &"tymp_b": "TYPE B", &"tymp_as": "TYPE As", &"tymp_c": "TYPE C", &"tymp_ad": "TYPE Ad",
	&"deg_mild": "MILD", &"deg_moderate": "MODERATE", &"deg_modsevere": "MOD-SEVERE", &"deg_severe": "SEVERE", &"deg_profound": "PROFOUND"}
## AIR & BONE's chutes, in key order (1-3): where the loss lives (ClinicRules.hearing_type).
const TYPES: Array[StringName] = [&"sensorineural", &"conductive", &"mixed"]
## TYMP TOSS's chutes, in key order (1-5): the Jerger tympanogram types (CaseRules.tymp_type).
const TYMPS: Array[StringName] = [&"tymp_a", &"tymp_b", &"tymp_as", &"tymp_c", &"tymp_ad"]
## Each tymp chute's Jerger type.
const TYMP_TYPE: Dictionary[StringName, StringName] = {&"tymp_a": &"A", &"tymp_b": &"B", &"tymp_as": &"As", &"tymp_c": &"C", &"tymp_ad": &"Ad"}
## DEGREE DROP's chutes, in key order (1-5): the degree of loss by the 500/1k/2k average.
const DEGREES: Array[StringName] = [&"deg_mild", &"deg_moderate", &"deg_modsevere", &"deg_severe", &"deg_profound"]
## Each degree chute's name in ClinicRules.degree_name, and its band (above lo, up to hi; dB HL).
const DEGREE_NAME: Dictionary[StringName, String] = {&"deg_mild": "mild", &"deg_moderate": "moderate",
	&"deg_modsevere": "moderately severe", &"deg_severe": "severe", &"deg_profound": "profound"}
const DEGREE_BAND: Dictionary[StringName, Vector2i] = {&"deg_mild": Vector2i(25, 40), &"deg_moderate": Vector2i(40, 55),
	&"deg_modsevere": Vector2i(55, 70), &"deg_severe": Vector2i(70, 90), &"deg_profound": Vector2i(90, 120)}
## A degree card's average sits this far inside its band.
const DEGREE_MARGIN_DB := 5
## Degree shapes over FREQS, lifted or lowered to the band (make_degree_chart). Lookalikes: a steep
## slope whose highs are far worse than its average, or a chart whose lows are the worst.
const DEGREE_ARCH: Dictionary[StringName, Dictionary] = {
	&"deg_mild": {"plain": [[15, 20, 25, 40, 50, 60, 65, 70], [20, 25, 30, 35, 45, 50, 60, 70], [40, 40, 45, 45, 50, 50, 55, 55], [45, 45, 45, 50, 50, 55, 55, 60]],
		"lookalike": [[10, 15, 20, 30, 55, 70, 80, 85], [65, 55, 40, 30, 25, 20, 20, 20]]},
	&"deg_moderate": {"plain": [[15, 20, 25, 40, 50, 60, 65, 70], [20, 25, 30, 35, 45, 50, 60, 70], [40, 40, 45, 45, 50, 50, 55, 55], [45, 45, 45, 50, 50, 55, 55, 60]],
		"lookalike": [[10, 15, 20, 30, 55, 70, 80, 85], [65, 55, 40, 30, 25, 20, 20, 20]]},
	&"deg_modsevere": {"plain": [[20, 25, 30, 35, 45, 50, 60, 70], [40, 40, 45, 45, 50, 50, 55, 55], [45, 45, 45, 50, 50, 55, 55, 60]],
		"lookalike": [[20, 25, 30, 40, 60, 75, 85, 90], [65, 60, 50, 40, 35, 35, 35, 35]]},
	&"deg_severe": {"plain": [[40, 40, 45, 45, 50, 50, 55, 55], [45, 45, 45, 50, 50, 55, 55, 60], [35, 40, 45, 50, 55, 55, 60, 65]],
		"lookalike": [[60, 70, 75, 80, 90, 95, 95, 100], [90, 85, 80, 75, 70, 65, 65, 70]]},
	&"deg_profound": {"plain": [[75, 95, 100, 105, 110, 115, 105, 95], [85, 100, 100, 100, 105, 110, 105, 100]],
		"lookalike": [[60, 90, 100, 110, 115, 115, 110, 100]]},
}
## The belts: shapes (Chart Chute), types (AIR & BONE), tymps (TYMP TOSS) and degrees (DEGREE DROP).
const BELTS: Dictionary[StringName, Array] = {&"shapes": SHAPES, &"types": TYPES, &"tymps": TYMPS, &"degrees": DEGREES}
## A tymp card's peak keeps its type this far either way (daPa, mL).
const TYMP_MARGIN_DAPA := 40
const TYMP_MARGIN_ML := 0.04
## Peak ranges per chute: {"plain" | "lookalike": [[daPa lo, daPa hi], [mL lo, mL hi]]} (docs/ARCADE.md
## section 19). A lookalike sits near a line: an A near the box's edges, a C just past -100.
const TYMP_ARCH: Dictionary[StringName, Dictionary] = {
	&"tymp_a": {"plain": [[-50, 20], [0.5, 1.2]], "lookalike": [[-60, 25], [0.4, 1.5]]},
	&"tymp_b": {"plain": [[0, 0], [0.02, 0.05]], "lookalike": [[0, 0], [0.02, 0.05]]},
	&"tymp_as": {"plain": [[-50, 20], [0.15, 0.2]], "lookalike": [[-50, 20], [0.25, 0.25]]},
	&"tymp_c": {"plain": [[-300, -200], [0.4, 1.0]], "lookalike": [[-160, -150], [0.4, 1.0]]},
	&"tymp_ad": {"plain": [[-40, 20], [2.2, 2.8]], "lookalike": [[-40, 20], [1.8, 1.9]]},
}
## Canal volume (mL): normal on every card but a lookalike B, which is tiny (a wax plug) or large
## (an old hole or a grommet).
const TYMP_ECV_NORMAL := Vector2(0.8, 1.6)
const TYMP_ECV_TINY := Vector2(0.3, 0.45)
const TYMP_ECV_LARGE := Vector2(2.6, 3.2)
## The patient's line on a lookalike B, by its canal volume.
const TYMP_B_LINES: Dictionary = {&"tiny": "Never cleaned my ears. Ever.", &"large": "I had grommets as a kid."}
## Bone on a type card: these frequencies (the ones hearing_type reads).
const BONE_FREQS: Array[int] = [500, 1000, 2000, 4000]
## A type card's gaps are big (20 dB or more) or none (5 or less), so any one point 5 dB off
## keeps the call; conductive bone averages 15 or better, mixed bone 35 or worse.
const GAP_BIG_DB := 20
const GAP_NONE_DB := 5
const BONE_NORMAL_MAX := 15.0
const BONE_DOWN_MIN := 35.0
## The air line's shape on each type (docs/ARCADE.md section 17).
const TYPE_AIR: Dictionary[StringName, Array] = {&"sensorineural": [&"sloping", &"flat"], &"conductive": [&"flat", &"rising"],
	&"mixed": [&"sloping", &"flat"]}
## A reverse cookie bite: the lows (250 / 500) and the highs (4k / 8k) each this much worse than
## the middle (1k / 2k), on average (docs/ARCADE.md section 16).
const REVERSE_BITE_DB := 15.0
## The chart's test frequencies (plus 750 / 1500 where ClinicRules.required_interoctaves asks).
const FREQS: Array[int] = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]
const MARGIN_DB := 5
## A notch on this belt bottoms out at 40 dB HL or worse, so it reads as a notch at a glance.
const NOTCH_FLOOR_MIN := 40
const MAX_TRIES := 80
const PORTRAIT_IDS := 4

## Archetypes over FREQS. "plain" first; "lookalike" ones are the same shape with a trap in it.
const ARCH: Dictionary[StringName, Dictionary] = {
	&"sloping": {
		"plain": [[15, 20, 25, 40, 50, 60, 65, 70], [20, 25, 30, 35, 45, 50, 60, 70], [10, 15, 20, 30, 45, 55, 65, 75], [25, 25, 30, 45, 55, 60, 65, 65]],
		# a dip at 4k that never comes back up at 8k: still a slope, not a notch
		"lookalike": [[15, 20, 25, 35, 45, 60, 60, 65], [20, 20, 25, 30, 45, 55, 55, 60]],
	},
	&"notch": {
		"plain": [[10, 15, 15, 20, 40, 55, 45, 25], [15, 15, 20, 25, 45, 60, 50, 30], [10, 10, 15, 15, 35, 50, 40, 20], [5, 10, 10, 15, 30, 45, 40, 20]],
		# a notch sitting on a sloping loss: 8k recovers a little, not all the way
		"lookalike": [[15, 20, 25, 30, 50, 60, 55, 45], [20, 20, 25, 30, 45, 55, 55, 40]],
	},
	&"cookie_bite": {
		"plain": [[20, 25, 45, 50, 35, 25, 25, 25], [15, 25, 45, 45, 35, 25, 20, 20], [20, 30, 50, 55, 40, 30, 30, 25]],
		# a shallow bite
		"lookalike": [[20, 25, 45, 45, 35, 25, 25, 25], [25, 25, 45, 45, 30, 25, 25, 20]],
	},
	&"rising": {
		"plain": [[55, 50, 40, 30, 25, 20, 20, 20], [60, 55, 45, 30, 25, 25, 20, 25], [50, 45, 40, 25, 20, 15, 15, 20]],
		# gentle: only the lowest pitches are clearly worse
		"lookalike": [[45, 40, 35, 25, 20, 15, 15, 15], [50, 45, 35, 25, 25, 20, 20, 20]],
	},
	&"reverse_bite": {
		"plain": [[50, 40, 25, 25, 30, 40, 50, 55], [50, 45, 30, 25, 30, 40, 50, 55], [55, 45, 30, 30, 35, 45, 55, 60]],
		# one end only just worse: it looks rising (the top barely turns down) or sloping (the
		# bottom barely turns up), but both ends are past the line
		"lookalike": [[60, 50, 30, 25, 30, 40, 50, 50], [45, 40, 25, 25, 40, 50, 60, 65]],
	},
}

## Type archetypes: [air over FREQS, bone over BONE_FREQS]. Lookalikes: a sensorineural chart
## split 5 dB all along, a conductive one with bone at 20, a mixed one whose bone is only just down
## or whose gap is only at the low end.
const TYPE_ARCH: Dictionary[StringName, Dictionary] = {
	&"sensorineural": {
		"plain": [[[20, 25, 30, 40, 50, 55, 60, 65], [25, 30, 35, 55]], [[40, 40, 45, 45, 50, 50, 55, 55], [35, 45, 45, 50]],
			[[15, 20, 30, 45, 55, 60, 65, 70], [20, 25, 45, 60]]],
		"lookalike": [[[30, 35, 40, 50, 55, 60, 65, 70], [30, 35, 45, 55]], [[20, 20, 25, 35, 55, 65, 70, 75], [20, 25, 35, 60]]],
	},
	&"conductive": {
		"plain": [[[40, 40, 40, 40, 35, 35, 40, 40], [5, 10, 15, 10]], [[50, 45, 40, 30, 25, 25, 25, 30], [10, 5, 10, 20]],
			[[45, 45, 45, 40, 40, 35, 40, 45], [10, 10, 15, 10]]],
		"lookalike": [[[45, 45, 40, 40, 40, 40, 45, 45], [5, 10, 20, 15]], [[40, 35, 35, 30, 30, 30, 35, 40], [10, 10, 10, 5]]],
	},
	&"mixed": {
		"plain": [[[55, 60, 60, 65, 70, 70, 75, 80], [35, 40, 45, 50]], [[65, 65, 65, 65, 65, 70, 70, 70], [40, 40, 45, 45]],
			[[50, 55, 60, 70, 75, 80, 85, 90], [30, 35, 45, 55]]],
		"lookalike": [[[55, 55, 55, 60, 60, 65, 70, 70], [30, 35, 35, 40]], [[60, 60, 55, 55, 60, 65, 70, 75], [35, 35, 50, 60]]],
	},
}

## The story patients whose charts turn up as golden cards (x3). Marina's rising loss is in her
## LEFT ear only, and hers comes and goes (a REFER on her Day), so her card shows the blue line.
const GOLDEN: Dictionary[StringName, Dictionary] = {
	&"sloping": {"patient": "gus", "who": "Gus", "ear": "both", "sort_ear": "right", "line": "Gus says everyone mumbles. Day 1!"},
	&"notch": {"patient": "rocco", "who": "Rocco", "ear": "both", "sort_ear": "right", "line": "Rocco's drums left a notch. Day 6!"},
	&"cookie_bite": {"patient": "ginger", "who": "Ginger", "ear": "both", "sort_ear": "right", "line": "Ginger's cookie bite runs in her family. Day 9!"},
	&"rising": {"patient": "marina", "who": "Marina", "ear": "left", "sort_ear": "left", "line": "Marina's left ear comes and goes. Day 7!"},
}

## What the patient says when their chart lands in the right chute. (Untyped on purpose: a typed
## dictionary const keeps its array literals as Arrays, and reading one as a PackedStringArray
## crashes the engine.)
const LINES: Dictionary = {
	&"sloping": ["Everyone mumbles these days!", "I hear talking, not words.", "Birds? What birds?", "S and F sound the same."],
	&"notch": ["Thirty years of loud gigs...", "My workshop is LOUD.", "Jet engines, every day.", "I never wore earplugs."],
	&"cookie_bite": ["Mum's chart looks like this too!", "Middle voices just vanish.", "Grandad had the same bite."],
	&"rising": ["The fridge hum is gone!", "Deep voices are hard.", "Low notes went missing."],
	&"reverse_bite": ["Mid voices are fine, the rest fades.", "Low hum AND birdsong are gone.", "I hear you best in the middle."],
	&"sensorineural": ["Loud enough, just not clear.", "Everyone mumbles!", "It's the S sounds."],
	&"conductive": ["Like my head's under water.", "My own voice booms!", "It feels blocked."],
	&"mixed": ["Blocked AND fuzzy.", "Ear trouble since I was a lad, and now this.", "Louder helps, but not enough."],
	&"tymp_a": ["Just here for a check-up.", "My ears feel fine, honest!", "The wife sent me."],
	&"tymp_b": ["My ear feels full of water.", "Had a stinking cold for weeks.", "Everything's muffled on this side."],
	&"tymp_as": ["My hearing faded slowly.", "Mum had stiff ears too.", "Quieter every year, no pain."],
	&"tymp_c": ["My ears won't pop since the flight.", "Bit of a cold lately.", "Like I'm still on the plane."],
	&"tymp_ad": ["I took a knock to that ear once.", "Old scar on my eardrum.", "A big bang, years ago."],
	&"deg_mild": ["I miss the odd word.", "Fine one-to-one, not in a crowd."],
	&"deg_moderate": ["I live on 'pardon?'.", "The TV is too loud, says my wife."],
	&"deg_modsevere": ["I only catch people who face me.", "Phone calls are hopeless."],
	&"deg_severe": ["I hear voices, not words.", "Shouting is all I get."],
	&"deg_profound": ["I feel the bass more than hear it.", "I lip-read everything."],
}
## The tell, drawn on the chart after a wrong drop or a HOOT HELP: where to look, in a few words.
## {freq_lo, freq_hi}: the part of the chart that glows.
const TELLS: Dictionary[StringName, Dictionary] = {
	&"sloping": {"text": "Worse and worse toward the high pitches", "freq_lo": 250, "freq_hi": 8000},
	&"notch": {"text": "Dips at 3-6k, comes back up at 8k", "freq_lo": 3000, "freq_hi": 8000},
	&"cookie_bite": {"text": "Worst in the middle, better at both ends", "freq_lo": 500, "freq_hi": 4000},
	&"rising": {"text": "The low pitches are the worst", "freq_lo": 250, "freq_hi": 1000},
	&"reverse_bite": {"text": "Better in the middle, worse at both ends", "freq_lo": 250, "freq_hi": 8000},
	&"sensorineural": {"text": "Bone sits on air: the inner ear", "freq_lo": 500, "freq_hi": 4000},
	&"conductive": {"text": "Bone is normal, air is down: the middle ear", "freq_lo": 500, "freq_hi": 4000},
	&"mixed": {"text": "Bone is down too, AND a gap: both", "freq_lo": 500, "freq_hi": 4000},
	# tymp tells glow over a pressure (daPa) by admittance (mL) patch of the tympanogram instead
	&"tymp_a": {"text": "Peak inside the box: the eardrum moves fine", "p_lo": -100, "p_hi": 50, "ml_lo": 0.3, "ml_hi": 1.7},
	&"tymp_b": {"text": "No peak at all: flat as a pancake", "p_lo": -400, "p_hi": 200, "ml_lo": 0.0, "ml_hi": 0.3},
	&"tymp_as": {"text": "Peak too low: a stiff eardrum", "p_lo": -100, "p_hi": 50, "ml_lo": 0.0, "ml_hi": 0.3},
	&"tymp_c": {"text": "Peak moved left: negative pressure", "p_lo": -400, "p_hi": -100, "ml_lo": 0.0, "ml_hi": 3.0},
	&"tymp_ad": {"text": "Peak sky-high: a floppy eardrum", "p_lo": -100, "p_hi": 50, "ml_lo": 1.7, "ml_hi": 3.0},
	&"deg_mild": {"text": "500-2k average 26 to 40", "freq_lo": 500, "freq_hi": 2000},
	&"deg_moderate": {"text": "500-2k average 41 to 55", "freq_lo": 500, "freq_hi": 2000},
	&"deg_modsevere": {"text": "500-2k average 56 to 70: moderately severe", "freq_lo": 500, "freq_hi": 2000},
	&"deg_severe": {"text": "500-2k average 71 to 90", "freq_lo": 500, "freq_hi": 2000},
	&"deg_profound": {"text": "500-2k average over 90", "freq_lo": 500, "freq_hi": 2000},
}

const FIRST: PackedStringArray = ["Barry", "Dennis", "Frank", "Hank", "Lou", "Norm", "Percy", "Ray", "Sal", "Vince", "Walt", "Otis",
	"Agnes", "Cora", "Edna", "Gloria", "Irene", "Kitty", "Mabel", "Olive", "Trudy", "Wanda", "Hattie", "Viv"]
const LAST: PackedStringArray = ["Pickles", "Bellweather", "Crumb", "Doolittle", "Gumm", "Honk", "Juniper", "Kettle", "Lark", "Muffin",
	"Noodle", "Puddle", "Quill", "Rumble", "Sprocket", "Tinker", "Waddle", "Whisk", "Bramble", "Fizz", "Toffee", "Wobble"]
const SKINS: PackedStringArray = ["#ffcf9e", "#f1c6a1", "#e0a77f", "#c98d64", "#b98058", "#8d5a3b", "#6b4229"]
const HAIRS: PackedStringArray = ["#e8e4dc", "#c9c4bb", "#9a948b", "#5a3d2b", "#3b2a20", "#c2410c", "#1d1410"]
const CLOTHES: PackedStringArray = ["#3a9d96", "#7b2cbf", "#e5383b", "#2d6cdf", "#ff9f1c", "#5bc8a3", "#c0479c", "#1f3a5f"]
const BGS: PackedStringArray = ["#ffe6a8", "#d9e6ff", "#d6f5e3", "#ffd9e8", "#fff1a8", "#ffe0d6", "#e9dcff"]


## (seeded) One card whose chart (on the ear it asks you to sort) has `shape`.
## opts: {"ear": "right" | "left" | "both", "lookalike": bool}. "both" puts a different shape on
## the other ear, so you have to sort the colour the card names.
## A type id (TYPES) deals a one-ear air-and-bone card instead (make_type_card).
static func make_card(rng: RandomNumberGenerator, shape: StringName, opts: Dictionary, serial: int) -> Dictionary:
	if TYPES.has(shape):
		return make_type_card(rng, shape, opts, serial)
	if TYMPS.has(shape):
		return make_tymp_card(rng, shape, opts, serial)
	if DEGREES.has(shape):
		var dear := "left" if String(opts.get("ear", "right")) == "left" else "right"
		var dlines: Array = LINES[shape]
		var dfirst := FIRST[rng.randi() % FIRST.size()]
		return {"serial": serial, "shape": shape, "ear": dear, "sort_ear": dear,
			"ac": {dear: make_degree_chart(rng, shape, bool(opts.get("lookalike", false)))}, "golden": false, "other_shape": &"",
			"name": "%s %s" % [dfirst, LAST[rng.randi() % LAST.size()]], "who": "chute_%d" % (serial % PORTRAIT_IDS),
			"look": _look(rng, "doris" if FIRST.find(dfirst) >= 12 else "gus"), "line": dlines[rng.randi() % dlines.size()]}
	var ear := String(opts.get("ear", "right"))
	var sort_ear := ear
	if ear == "both":
		sort_ear = "right" if rng.randf() < 0.5 else "left"
	var ac := {}
	ac[sort_ear] = make_chart(rng, shape, bool(opts.get("lookalike", false)))
	var other_shape: StringName = &""
	if ear == "both":
		var others: Array = SHAPES.filter(func(s: StringName) -> bool: return s != shape)
		var other_ear := "left" if sort_ear == "right" else "right"
		other_shape = others[rng.randi() % others.size()]
		ac[other_ear] = make_chart(rng, other_shape, false)
	var lines: Array = LINES[shape]
	var first := FIRST[rng.randi() % FIRST.size()]
	return {
		"serial": serial, "shape": shape, "ear": ear, "sort_ear": sort_ear, "ac": ac, "golden": false, "other_shape": other_shape,
		# a few portrait ids, reused: only two cards are ever on screen, so the look registry stays small
		"name": "%s %s" % [first, LAST[rng.randi() % LAST.size()]], "who": "chute_%d" % (serial % PORTRAIT_IDS),
		"look": _look(rng, "doris" if FIRST.find(first) >= 12 else "gus"), "line": lines[rng.randi() % lines.size()],
	}


## (seeded) One AIR & BONE card: one ear's air and bone whose type (ClinicRules.hearing_type) is
## `type`. Adds "bc" {ear: {freq: dB}} and "bc_masked" {ear: {freq: true}} (bone drawn masked [ ]
## where it sits BC_MASK_GAP_DB or more better than air) to the usual card keys.
static func make_type_card(rng: RandomNumberGenerator, type: StringName, opts: Dictionary, serial: int) -> Dictionary:
	var ear := "left" if String(opts.get("ear", "right")) == "left" else "right"
	var chart := make_type_chart(rng, type, bool(opts.get("lookalike", false)))
	var ac: Dictionary = chart.get("ac", {})
	var bc: Dictionary = chart.get("bc", {})
	var masked := {}
	for f: int in bc:
		if int(ac[f]) - int(bc[f]) >= ClinicRules.BC_MASK_GAP_DB:
			masked[f] = true
	var lines: Array = LINES[type]
	var first := FIRST[rng.randi() % FIRST.size()]
	return {
		"serial": serial, "shape": type, "ear": ear, "sort_ear": ear, "ac": {ear: ac}, "bc": {ear: bc}, "bc_masked": {ear: masked},
		"golden": false, "other_shape": &"", "name": "%s %s" % [first, LAST[rng.randi() % LAST.size()]],
		"who": "chute_%d" % (serial % PORTRAIT_IDS), "look": _look(rng, "doris" if FIRST.find(first) >= 12 else "gus"),
		"line": lines[rng.randi() % lines.size()],
	}


## (seeded) {"ac": {freq: dB}, "bc": {freq: dB}} of `type`, clear of every rule edge (stable_type).
static func make_type_chart(rng: RandomNumberGenerator, type: StringName, lookalike: bool) -> Dictionary:
	var pool: Array = TYPE_ARCH[type]["lookalike" if lookalike else "plain"]
	for attempt in MAX_TRIES:
		var base: Array = pool[rng.randi() % pool.size()]
		var lift := 5 * rng.randi_range(-1, 1)
		var ac := {}
		for i in FREQS.size():
			var f: int = FREQS[i]
			var wobble := 5 * rng.randi_range(-1, 1) if rng.randf() < 0.35 else 0
			ac[f] = ClinicRules.clamp_db(int(base[0][i]) + lift + wobble, f)
		var bc := {}
		for i in BONE_FREQS.size():
			var f: int = BONE_FREQS[i]
			var wobble := 5 * rng.randi_range(-1, 1) if rng.randf() < 0.35 else 0
			bc[f] = int(base[1][i]) + lift + wobble
		if stable_type(ac, bc, type):
			_add_interoctaves(ac)
			return {"ac": ac, "bc": bc}
	push_error("ChartDeck: no stable %s chart" % type)
	return {}


## The type card's honesty and margin check: hearing_type says `type` and still does with any one
## air or bone point 5 dB better or worse; bone is never poorer than air, never past the bone
## limits, and each gap is big (GAP_BIG_DB) or none (GAP_NONE_DB); conductive bone is clearly
## normal and mixed bone clearly down; the air line has the type's shape and is clearly a loss.
static func stable_type(ac: Dictionary, bc: Dictionary, type: StringName) -> bool:
	if ClinicRules.hearing_type(ac, bc) != type:
		return false
	if not (TYPE_AIR[type] as Array).has(shape_of(ac)):
		return false
	var worst := -999
	for f: int in FREQS:
		worst = maxi(worst, int(ac.get(f, -999)))
	if worst <= 25 + 2 * MARGIN_DB:
		return false
	var bone_sum := 0
	for f: int in BONE_FREQS:
		var b := int(bc.get(f, 999))
		var gap := int(ac[f]) - b
		if b < -10 or b > int(ClinicRules.BC_MAX_DB[f]) or gap < 0:
			return false
		if gap > GAP_NONE_DB and gap < GAP_BIG_DB:
			return false
		bone_sum += b
	var bone_avg := float(bone_sum) / BONE_FREQS.size()
	if type == &"conductive" and bone_avg > BONE_NORMAL_MAX:
		return false
	if type == &"mixed" and bone_avg < BONE_DOWN_MIN:
		return false
	for f: int in BONE_FREQS:
		for d: int in [-MARGIN_DB, MARGIN_DB]:
			var a := ac.duplicate()
			a[f] = int(ac[f]) + d
			var b := bc.duplicate()
			b[f] = int(bc[f]) + d
			if ClinicRules.hearing_type(a, bc) != type or ClinicRules.hearing_type(ac, b) != type:
				return false
	return true


## (seeded) One TYMP TOSS card: one ear's tympanogram whose Jerger type (CaseRules.tymp_type) is
## the chute's. Adds "tymp" {"type", "peak_daPa", "peak_ml", "ecv_ml"} (CaseRules' own keys, so
## CaseRules.tymp_admittance draws it); "ac" is empty.
static func make_tymp_card(rng: RandomNumberGenerator, id: StringName, opts: Dictionary, serial: int) -> Dictionary:
	var ear := "left" if String(opts.get("ear", "right")) == "left" else "right"
	var lookalike := bool(opts.get("lookalike", false))
	var tymp := make_tymp(rng, id, lookalike)
	var lines: Array = LINES[id]
	var line: String = lines[rng.randi() % lines.size()]
	if id == &"tymp_b" and lookalike:
		var big := rng.randf() < 0.5
		var r: Vector2 = TYMP_ECV_LARGE if big else TYMP_ECV_TINY
		tymp["ecv_ml"] = snappedf(rng.randf_range(r.x, r.y), 0.1)
		line = String(TYMP_B_LINES[&"large" if big else &"tiny"])
	var first := FIRST[rng.randi() % FIRST.size()]
	return {
		"serial": serial, "shape": id, "ear": ear, "sort_ear": ear, "ac": {}, "tymp": tymp, "golden": false, "other_shape": &"",
		"name": "%s %s" % [first, LAST[rng.randi() % LAST.size()]], "who": "chute_%d" % (serial % PORTRAIT_IDS),
		"look": _look(rng, "doris" if FIRST.find(first) >= 12 else "gus"), "line": line,
	}


## (seeded) A tympanogram {"type", "peak_daPa", "peak_ml", "ecv_ml"} for a tymp chute, clear of its
## type's lines (stable_tymp). Pressure on 5 daPa steps, admittance and volume on 0.05 / 0.1 mL.
static func make_tymp(rng: RandomNumberGenerator, id: StringName, lookalike: bool) -> Dictionary:
	var arch: Array = TYMP_ARCH[id]["lookalike" if lookalike else "plain"]
	for attempt in MAX_TRIES:
		var p := clampi(snappedi(rng.randi_range(int(arch[0][0]), int(arch[0][1])), 5), int(arch[0][0]), int(arch[0][1]))
		var ml := snappedf(rng.randf_range(float(arch[1][0]), float(arch[1][1])), 0.05)
		if id == &"tymp_a" and lookalike:
			# near an edge: the low or high end of the box's height, or its left side
			match rng.randi() % 3:
				0: ml = 0.4
				1: ml = 1.5
				_: p = -60
		var t := {"type": String(TYMP_TYPE[id]), "peak_daPa": p, "peak_ml": ml,
			"ecv_ml": snappedf(rng.randf_range(TYMP_ECV_NORMAL.x, TYMP_ECV_NORMAL.y), 0.1)}
		if stable_tymp(t, id):
			return t
	push_error("ChartDeck: no stable %s tymp" % id)
	return {}


## The tymp margin check: CaseRules.tymp_type says the chute's type, and still does with the peak
## TYMP_MARGIN_DAPA either way or TYMP_MARGIN_ML higher or lower.
static func stable_tymp(t: Dictionary, id: StringName) -> bool:
	var want: StringName = TYMP_TYPE[id]
	if CaseRules.tymp_type_of(t) != want:
		return false
	var p := int(t["peak_daPa"])
	var ml := float(t["peak_ml"])
	for dp: int in [-TYMP_MARGIN_DAPA, 0, TYMP_MARGIN_DAPA]:
		for dm: float in [-TYMP_MARGIN_ML, 0.0, TYMP_MARGIN_ML]:
			if CaseRules.tymp_type(p + dp, ml + dm) != want:
				return false
	return true


## (seeded) One ear's chart for a degree chute: a shape lifted or lowered so its 500/1k/2k average
## lands inside the band (stable_degree).
static func make_degree_chart(rng: RandomNumberGenerator, id: StringName, lookalike: bool) -> Dictionary:
	var pool: Array = DEGREE_ARCH[id]["lookalike" if lookalike else "plain"]
	var band: Vector2i = DEGREE_BAND[id]
	for attempt in MAX_TRIES:
		var base: Array = pool[rng.randi() % pool.size()]
		var base_pta := (float(base[1]) + float(base[2]) + float(base[3])) / 3.0
		var target := rng.randi_range(band.x + DEGREE_MARGIN_DB, mini(band.y - DEGREE_MARGIN_DB, 105))
		var shift := snappedi(roundi(target - base_pta), 5)
		var t := {}
		for i in FREQS.size():
			var f: int = FREQS[i]
			var wobble := 5 * rng.randi_range(-1, 1) if rng.randf() < 0.35 else 0
			t[f] = int(base[i]) + shift + wobble
		if stable_degree(t, id):
			_add_interoctaves(t)
			return t
	push_error("ChartDeck: no stable %s chart" % id)
	return {}


## The degree margin check: ClinicRules.degree_name of the 500/1k/2k average is the chute's, the
## average sits DEGREE_MARGIN_DB inside the band (so any one point 5 dB off keeps it), and every
## point is a real threshold inside the audiometer's range (no clamping, no "no response").
static func stable_degree(t: Dictionary, id: StringName) -> bool:
	var avg := ClinicRules.pta(t)
	if ClinicRules.degree_name(avg) != DEGREE_NAME[id]:
		return false
	var band: Vector2i = DEGREE_BAND[id]
	if avg < band.x + DEGREE_MARGIN_DB or (id != &"deg_profound" and avg > band.y - DEGREE_MARGIN_DB):
		return false
	for f: int in FREQS:
		var v := int(t.get(f, -999))
		if v < -10 or v % 5 != 0 or ClinicRules.clamp_db(v, f) != v:
			return false
	return true


## A story patient's own chart, as a golden card ({} if the patient file is missing).
static func golden_card(shape: StringName, serial: int) -> Dictionary:
	var g: Dictionary = GOLDEN.get(shape, {})
	if g.is_empty():
		return {}
	var p := Game.load_patient(String(g["patient"])) as PatientProfile
	if p == null:
		return {}
	var ac := {}
	for ear: String in ClinicRules.EARS:
		if String(g["ear"]) == "both" or String(g["ear"]) == ear:
			var t := {}
			var src := p.get_thresholds(ear)
			for f: int in src:
				t[f] = int(src[f])
			ac[ear] = t
	return {"serial": serial, "shape": shape, "ear": String(g["ear"]), "sort_ear": String(g["sort_ear"]), "ac": ac, "golden": true,
		"other_shape": &"", "name": String(g["who"]), "who": String(g["who"]), "look": {}, "line": String(g["line"])}


## The shapes whose story chart may be dealt this run: only patients whose Day the player has
## finished (a story chart shows the day's pattern and, for Marina, a clue to her call), and of
## those the ones not found yet; once all of those are found they come round again.
static func golden_pool(found: PackedStringArray) -> Array:
	var done: Array = SHAPES.filter(func(s: StringName) -> bool: return GOLDEN.has(s) and Game.is_chapter_done(String(GOLDEN[s]["patient"])))
	var left: Array = done.filter(func(s: StringName) -> bool: return not found.has(String(s)))
	return left if not left.is_empty() else done


## (seeded) One ear's chart of `shape`, clear of every rule edge (stable()).
static func make_chart(rng: RandomNumberGenerator, shape: StringName, lookalike: bool) -> Dictionary:
	var pool: Array = ARCH[shape]["lookalike" if lookalike else "plain"]
	for attempt in MAX_TRIES:
		var base: Array = pool[rng.randi() % pool.size()]
		var lift := 5 * rng.randi_range(-1, 1)
		var t := {}
		for i in FREQS.size():
			var f: int = FREQS[i]
			var wobble := 5 * rng.randi_range(-1, 1) if rng.randf() < 0.35 else 0
			t[f] = ClinicRules.clamp_db(int(base[i]) + lift + wobble, f)
		if stable(t, shape):
			_add_interoctaves(t)
			return t
	push_error("ChartDeck: no stable %s chart" % shape)
	return {}


## The belt's label for one ear's chart: ClinicRules.classify_shape, except that a chart it calls
## sloping, rising or flat is a reverse bite when both ends are REVERSE_BITE_DB worse than the
## middle (classify_shape has no reverse bite and mostly calls one flat).
static func shape_of(t: Dictionary) -> StringName:
	var base := ClinicRules.classify_shape(t)
	if base != &"sloping" and base != &"rising" and base != &"flat":
		return base
	for f: int in [250, 500, 1000, 2000, 4000, 8000]:
		if not t.has(f):
			return base
	var mid := (float(t[1000]) + float(t[2000])) * 0.5
	var low := (float(t[250]) + float(t[500])) * 0.5
	var high := (float(t[4000]) + float(t[8000])) * 0.5
	if low - mid >= REVERSE_BITE_DB and high - mid >= REVERSE_BITE_DB:
		return &"reverse_bite"
	return base


## The margin check: shape_of says `shape`, it still says so with any one frequency 5 dB
## better or worse, the chart is clearly not normal, a notch bottoms out at NOTCH_FLOOR_MIN, and a
## slope never recovers 10 dB at 6k.
static func stable(t: Dictionary, shape: StringName) -> bool:
	if shape_of(t) != shape:
		return false
	var worst := -999
	for f: int in FREQS:
		worst = maxi(worst, int(t.get(f, -999)))
	if worst <= 25 + 2 * MARGIN_DB:
		return false
	if shape == &"notch" and maxi(int(t[3000]), maxi(int(t[4000]), int(t[6000]))) < NOTCH_FLOOR_MIN:
		return false
	# a slope never comes back up at 6k either: 10 dB of recovery there reads as a 4k notch to a
	# clinician (the usual noise-notch rule looks at 6k or 8k), even though classify_shape checks 8k
	if shape == &"sloping" and maxi(int(t[3000]), int(t[4000])) - int(t[6000]) >= 10:
		return false
	for f: int in FREQS:
		for d: int in [-MARGIN_DB, MARGIN_DB]:
			var p := t.duplicate()
			p[f] = int(t[f]) + d
			if shape_of(p) != shape:
				return false
	return true


## Add 750 / 1500 where the octaves either side differ by 20 dB or more (halfway, to 5 dB).
static func _add_interoctaves(t: Dictionary) -> void:
	for f: int in ClinicRules.required_interoctaves(t):
		if t.has(f):
			continue
		var pair: Array = ClinicRules.INTEROCTAVES[f]
		t[f] = int(round((int(t[pair[0]]) + int(t[pair[1]])) / 10.0)) * 5


static func _look(rng: RandomNumberGenerator, face: String) -> Dictionary:
	var skin: String = SKINS[rng.randi() % SKINS.size()]
	var styles: Array = ["tufts", "none"] if face == "gus" else ["bun", "beehive", "tufts"]
	return {
		"face": face, "skin": skin, "nose": skin, "hair": HAIRS[rng.randi() % HAIRS.size()],
		"hair_style": styles[rng.randi() % styles.size()], "cardigan": CLOTHES[rng.randi() % CLOTHES.size()],
		"shirt": "#fffdf8", "accent": CLOTHES[rng.randi() % CLOTHES.size()], "mustache": face == "gus" and rng.randf() < 0.4,
		"brows": rng.randf() < 0.5, "glasses": ["none", "round", "perched", "cateye"][rng.randi() % 4] if rng.randf() < 0.6 else "none",
		"glasses_color": "#2e2442", "extras": [], "portrait_bg": BGS[rng.randi() % BGS.size()], "name_color": "#2e2442",
	}
