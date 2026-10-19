extends RefCounted
## ChartDeck (arcade, story-internal): seeded audiograms for Chart Chute (docs/ARCADE.md). Every
## chart is labelled by ClinicRules.classify_shape, the same rule the story's reveals use, and kept
## clear of its edges: the shape still holds if any one frequency is 5 dB off, so a right answer is
## never a coin toss. Pure and static apart from the RandomNumberGenerator it is handed.
##   const ChartDeck := preload("res://story/arcade/chart_deck.gd")
##   var card := ChartDeck.make_card(rng, &"notch", {"ear": "right", "lookalike": false}, 7)
##   card = {"shape", "ear" (right | left | both), "sort_ear", "ac": {ear: {freq: dB}}, "name",
##           "look", "who", "golden", "line", "serial"}
##   ChartDeck.stable(thresholds, shape)    # the margin check every card passes
##   ChartDeck.golden_card(&"notch", 3)     # a story patient's own chart (Rocco's notch)

## The chutes, in key order (1-4).
const SHAPES: Array[StringName] = [&"sloping", &"notch", &"cookie_bite", &"rising"]
## One word under each chute's picture.
const CHUTE_WORDS: Dictionary[StringName, String] = {&"sloping": "SLOPE", &"notch": "NOTCH", &"cookie_bite": "COOKIE BITE", &"rising": "RISING"}
## The chart's test frequencies (plus 750 / 1500 where ClinicRules.required_interoctaves asks).
const FREQS: Array[int] = [250, 500, 1000, 2000, 3000, 4000, 6000, 8000]
const MARGIN_DB := 5
## A notch on this belt bottoms out at 40 dB HL or worse, so it reads as a notch at a glance.
const NOTCH_FLOOR_MIN := 40
const MAX_TRIES := 80

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
}
## The tell, drawn on the chart after a wrong drop or a HOOT HELP: where to look, in a few words.
## {freq_lo, freq_hi}: the part of the chart that glows.
const TELLS: Dictionary[StringName, Dictionary] = {
	&"sloping": {"text": "Worse and worse toward the high pitches", "freq_lo": 250, "freq_hi": 8000},
	&"notch": {"text": "Dips at 3-6k, comes back up at 8k", "freq_lo": 3000, "freq_hi": 8000},
	&"cookie_bite": {"text": "Worst in the middle, better at both ends", "freq_lo": 500, "freq_hi": 4000},
	&"rising": {"text": "The low pitches are the worst", "freq_lo": 250, "freq_hi": 1000},
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
static func make_card(rng: RandomNumberGenerator, shape: StringName, opts: Dictionary, serial: int) -> Dictionary:
	var ear := String(opts.get("ear", "right"))
	var sort_ear := ear
	if ear == "both":
		sort_ear = "right" if rng.randf() < 0.5 else "left"
	var ac := {}
	ac[sort_ear] = make_chart(rng, shape, bool(opts.get("lookalike", false)))
	if ear == "both":
		var others: Array = SHAPES.filter(func(s: StringName) -> bool: return s != shape)
		var other_ear := "left" if sort_ear == "right" else "right"
		ac[other_ear] = make_chart(rng, others[rng.randi() % others.size()], false)
	var lines: Array = LINES[shape]
	var first := FIRST[rng.randi() % FIRST.size()]
	return {
		"serial": serial, "shape": shape, "ear": ear, "sort_ear": sort_ear, "ac": ac, "golden": false,
		"name": "%s %s" % [first, LAST[rng.randi() % LAST.size()]], "who": "chute_%d" % serial,
		"look": _look(rng, "doris" if FIRST.find(first) >= 12 else "gus"), "line": lines[rng.randi() % lines.size()],
	}


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
		"name": String(g["who"]), "who": String(g["who"]), "look": {}, "line": String(g["line"])}


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


## The margin check: classify_shape says `shape`, it still says so with any one frequency 5 dB
## better or worse, the chart is clearly not normal, and a notch bottoms out at NOTCH_FLOOR_MIN.
static func stable(t: Dictionary, shape: StringName) -> bool:
	if ClinicRules.classify_shape(t) != shape:
		return false
	var worst := -999
	for f: int in FREQS:
		worst = maxi(worst, int(t.get(f, -999)))
	if worst <= 25 + 2 * MARGIN_DB:
		return false
	if shape == &"notch" and maxi(int(t[3000]), maxi(int(t[4000]), int(t[6000]))) < NOTCH_FLOOR_MIN:
		return false
	for f: int in FREQS:
		for d: int in [-MARGIN_DB, MARGIN_DB]:
			var p := t.duplicate()
			p[f] = int(t[f]) + d
			if ClinicRules.classify_shape(p) != shape:
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
