extends RefCounted
## DeskDeck (arcade, story-internal): seeded patient files for Ears, Please! (docs/ARCADE.md).
## Each file is built from a true air and bone table, then charted the way a clinician records it
## (masked where ClinicRules says masking is needed), then checked with DeskRules.decide() and the
## clear-cut margins below. A file that fails is rebuilt, so every call is decided by the rules,
## never by a coin toss at a rule's edge:
##   - between the ears, every shared frequency differs by 5 dB or less, or by 20 or more
##   - every air-bone gap on the chart is 5 dB or less, or 20 or more
##   - a FIT file's ears both have a pure-tone average of 30 to 65 dB HL (a loss aids can help)
##   - a same-day file's poorer ear is at least CaseRules.SUDDEN_MIN_DB worse at
##     CaseRules.SUDDEN_MIN_FREQS or more neighbouring frequencies
##   - every patient is an adult; nobody gets an emergency-room sign (no stamp covers those)
##   - outside the gap kinds, both ears are sensorineural (no conductive part a doctor should see)
##   - nobody's line names a cause for their loss (noise, an injury): "one ear worse" on the wall
##     means "no known cause", and a file never gives one
##   const DeskDeck := preload("res://story/arcade/desk_deck.gd")
##   var f := DeskDeck.make_file(rng, DeskRules.shift(1), &"refer", 7)
##   var w := DeskDeck.make_kind(rng, DeskRules.shift(2), "gap_both", 8)   # a warm-up file
##   var line := DeskDeck.make_line(rng, DeskRules.shift(1), 40)   # a shift's patients, in order

const DeskRules := preload("res://story/arcade/desk_rules.gd")

const MAX_TRIES := 60
const MARGIN_DB := 5
const CLEAR_DB := 20
const FIT_PTA := Vector2(30.0, 65.0)

## Air archetypes over DeskRules.FREQS (250 to 8k, with 1.5k): symmetric losses hearing aids can help.
const FIT_SHAPES: Dictionary[String, Array] = {
	"slope": [20, 25, 35, 40, 45, 50, 55, 60, 65],
	"steep": [20, 25, 35, 45, 50, 55, 60, 65, 70],
	"flat": [35, 40, 45, 45, 45, 50, 50, 55, 55],
	"gentle": [25, 30, 35, 40, 40, 45, 50, 55, 60],
	"cookie": [20, 30, 45, 50, 50, 45, 35, 30, 30],
}
## Milder bases for one-sided files (the better ear), so the poorer ear stays on the chart. A
## one-sided file sits on a FIT shape too (ONE_EAR_ON_FIT of the time), so "one line near the top"
## is never the tell: the split is.
const MILD_SHAPES: Dictionary[String, Array] = {
	"near_normal": [10, 10, 15, 15, 15, 20, 20, 25, 30],
	"mild": [15, 20, 20, 25, 25, 30, 35, 40, 45],
}
const ONE_EAR_ON_FIT := 0.6
## A two-ear air-bone gap (gap_both): air like a FIT file, bone this far above it at 500, 1k and 2k.
## Kept at 20 to 25 dB, below the size where masking both ears runs into the masking dilemma.
const GAP_BOTH_DB: Array[int] = [20, 25]
## Where a one-sided band of poorer hearing may start (it then runs upward in pitch).
const BAND_STARTS: Array[int] = [1000, 2000, 3000, 4000]

const FIRST_A: PackedStringArray = ["Barry", "Dennis", "Frank", "Hank", "Lou", "Norm", "Percy", "Ray", "Sal", "Vince", "Walt", "Ziggy", "Monty", "Otis", "Clem", "Gil"]
const FIRST_B: PackedStringArray = ["Agnes", "Cora", "Edna", "Gloria", "Irene", "Kitty", "Mabel", "Olive", "Queenie", "Trudy", "Wanda", "Yvonne", "Hattie", "Peg", "Rosa", "Viv"]
const LAST: PackedStringArray = ["Pickles", "Bellweather", "Crumb", "Doolittle", "Featherstone", "Gumm", "Honk", "Juniper", "Kettle", "Lark",
	"Muffin", "Noodle", "Puddle", "Quill", "Rumble", "Sprocket", "Tinker", "Waddle", "Whisk", "Bramble", "Fizz", "Marmalade", "Toffee", "Wobble"]
## What they say at the desk: an everyday trouble spot, never the answer and never a cause.
## [line, goal]: a FIT file's goal sticker reads "GOAL: <goal>" (the fitting aims at it).
const LINES: Array = [
	["Everyone mumbles at book club.", "book club"], ["My family turns the TV down. I turn it up.", "the TV"],
	["I keep missing the punchline.", "jokes"], ["Restaurants sound like a waterfall.", "restaurants"],
	["My grandkids talk so fast!", "the grandkids"], ["I laugh along and hope.", "chatting"],
	["Phone calls are a guessing game.", "the phone"], ["The kettle whistles? Since when?", "home sounds"],
	["My spouse says I say 'what?' a lot.", "home chats"], ["Church sounds like a swimming pool.", "church"],
	["I nod a lot at parties.", "parties"], ["The birds went quiet years ago.", "birdsong"],
	["Meetings are the worst.", "meetings"], ["I hear you. I just can't understand you.", "conversation"],
	["Whispering is a conspiracy.", "quiet voices"],
]
const SKINS: PackedStringArray = ["#ffcf9e", "#f1c6a1", "#e0a77f", "#c98d64", "#b98058", "#8d5a3b", "#6b4229"]
const HAIRS: PackedStringArray = ["#e8e4dc", "#c9c4bb", "#9a948b", "#5a3d2b", "#3b2a20", "#c2410c", "#1d1410"]
const CLOTHES: PackedStringArray = ["#3a9d96", "#7b2cbf", "#e5383b", "#2d6cdf", "#ff9f1c", "#5bc8a3", "#c0479c", "#1f3a5f", "#8e5cc4"]
const BGS: PackedStringArray = ["#ffe6a8", "#d9e6ff", "#d6f5e3", "#ffd9e8", "#fff1a8", "#ffe0d6", "#e9dcff"]

## The boss of each shift: a patient who tempts the wrong stamp.
const BOSSES: Dictionary[String, Dictionary] = {
	"wedding": {"name": "Wendy Bliss", "age": 66, "face": "doris", "want": &"refer", "kind": "intake", "flag": "drainage",
		"line": "My daughter's wedding is Saturday! Just fit me, dear!", "goal": "the wedding", "extras": ["pillbox_hat"]},
	"plane": {"name": "Gary Rush", "age": 58, "face": "gus", "want": &"refer", "kind": "gap_both",
		"line": "Quick, I've a plane to catch! Fit me and go!", "goal": "the flight", "extras": ["captain_cap"]},
	"wax": {"name": "Walter Wick", "age": 71, "face": "gus", "want": &"today", "kind": "today",
		"line": "It's only wax, dear. Just pop the aids in!", "goal": "the TV", "extras": ["captain_cap"]},
}


## (seeded) The right calls of a shift's line, by the shift's mix. A run never repeats the same
## call more than three times in a row, so the line can't be guessed.
static func make_line(rng: RandomNumberGenerator, sh: Dictionary, n: int) -> Array[StringName]:
	var out: Array[StringName] = []
	var mix: Dictionary = sh["mix"]
	for i in n:
		var want := _pick_weighted(rng, mix) as StringName
		if out.size() >= 3 and out[-1] == want and out[-2] == want and out[-3] == want:
			var others: Array = mix.keys().filter(func(k: Variant) -> bool: return k != want)
			want = others[rng.randi() % others.size()]
		out.append(want)
	return out


## (seeded) One patient file whose right call is `want`. serial: a running number (unique ids).
static func make_file(rng: RandomNumberGenerator, sh: Dictionary, want: StringName, serial: int) -> Dictionary:
	var kind := "fit"
	match want:
		&"refer":
			kind = String(_pick_weighted(rng, sh["refer_kinds"]))
		&"today":
			kind = "today"
	return make_kind(rng, sh, kind, serial)


## (seeded) One patient file of a given kind: fit, intake, one_ear, gap, gap_both, today,
## sudden_late or fluctuating (the warm-up asks for kinds by name). flag: an intake id to tick.
static func make_kind(rng: RandomNumberGenerator, sh: Dictionary, kind: String, serial: int, flag := "") -> Dictionary:
	for attempt in MAX_TRIES:
		var f := _build(rng, sh, kind, serial, flag)
		if valid(f, sh, kind):
			return f
	push_error("DeskDeck: no valid %s file after %d tries" % [kind, MAX_TRIES])
	return {}


## (seeded) The shift's boss file.
static func make_boss(rng: RandomNumberGenerator, sh: Dictionary, serial: int) -> Dictionary:
	var b: Dictionary = BOSSES.get(String(sh.get("boss", "wedding")), BOSSES["wedding"])
	for attempt in MAX_TRIES:
		var f := _build(rng, sh, String(b["kind"]), serial, String(b.get("flag", "")))
		if not valid(f, sh, String(b["kind"])):
			continue
		f["name"] = b["name"]
		f["age"] = b["age"]
		f["line"] = b["line"]
		f["goal"] = b["goal"]
		f["boss"] = String(sh.get("boss", "wedding"))
		f["look"] = _look(rng, String(b["face"]))
		f["look"]["extras"] = (b["extras"] as Array).duplicate()
		return f
	push_error("DeskDeck: no valid boss file")
	return {}


## Does a built file make the call it was built for, with every margin clear?
static func valid(f: Dictionary, sh: Dictionary, kind: String) -> bool:
	if f.is_empty():
		return false
	var v := DeskRules.decide(f)
	var want: StringName = f["want"]
	if v["decision"] != want:
		return false
	var ac: Dictionary = f["ac"]
	var bc: Dictionary = f["bc"]
	var r: Dictionary = ac["right"]
	var l: Dictionary = ac["left"]
	for fr: int in r:
		if not l.has(fr):
			return false
		var d := absi(int(r[fr]) - int(l[fr]))
		if d > MARGIN_DB and d < CLEAR_DB:
			return false
		if int(r[fr]) > ClinicRules.max_db(fr) or int(l[fr]) > ClinicRules.max_db(fr):
			return false
	for ear: String in ClinicRules.EARS:
		for fr: int in bc[ear]:
			var g := int(ac[ear][fr]) - int(bc[ear][fr])
			if g < -MARGIN_DB or (g > MARGIN_DB and g < CLEAR_DB):
				return false
			if int(bc[ear][fr]) > int(ClinicRules.BC_MAX_DB.get(fr, 70)) or int(bc[ear][fr]) < ClinicRules.MIN_DB:
				return false
	# only the flags this kind is about (a gap ear may also read as one ear worse)
	var kinds := {}
	for p: Dictionary in v["proofs"]:
		kinds[String(p["kind"]) + ":" + String(p.get("rule", p.get("id", "")))] = true
	if not kind.begins_with("gap"):
		for ear: String in ClinicRules.EARS:
			if ClinicRules.hearing_type(ac[ear], bc[ear]) in [&"conductive", &"mixed"]:
				return false
	var intake_on := 0
	for id: String in f["intake"]:
		if bool(f["intake"][id]):
			intake_on += 1
			if not (sh["intake"] as Array).has(id):
				return false
	match kind:
		"fit":
			if not kinds.is_empty():
				return false
			for ear: String in ClinicRules.EARS:
				var p := ClinicRules.pta(ac[ear])
				if p < FIT_PTA.x or p > FIT_PTA.y:
					return false
		"intake":
			if intake_on != 1 or kinds.size() != 1:
				return false
		"one_ear":
			if intake_on != 0 or kinds.size() != 1 or not kinds.has("chart:one_ear"):
				return false
		"gap":
			if intake_on != 0 or not kinds.has("chart:gap"):
				return false
			var gap_ears := 0
			for ear: String in ClinicRules.EARS:
				if ClinicRules.abg_red_flag(ac[ear], bc[ear]):
					gap_ears += 1
			if gap_ears != 1 or kinds.has("sudden:"):
				return false
		"gap_both":
			# looks like a FIT on air alone: the ears match, and only bone shows the middle ear
			if intake_on != 0 or kinds.has("chart:one_ear") or kinds.has("sudden:"):
				return false
			for ear: String in ClinicRules.EARS:
				if not ClinicRules.abg_red_flag(ac[ear], bc[ear]):
					return false
		"today", "sudden_late":
			if intake_on != 0 or not DeskRules.sudden_drop(ac, String(f["sudden"].get("ear", ""))):
				return false
			if kind == "sudden_late" and not kinds.has("sudden:"):
				return false
		"fluctuating":
			if intake_on != 0 or kinds.size() != 1 or not kinds.has("sudden:"):
				return false
	var has_card := not (f["sudden"] as Dictionary).is_empty()
	if bool(sh.get("sudden", false)) != has_card:
		return false
	return int(f["age"]) >= 18



# ---------------------------------------------------------------- building

static func _build(rng: RandomNumberGenerator, sh: Dictionary, kind: String, serial: int, flag := "") -> Dictionary:
	var want: StringName = &"fit"
	if kind == "today":
		want = &"today"
	elif kind != "fit":
		want = &"refer"
	var air := {"right": {}, "left": {}}
	var bone_gap := {"right": {}, "left": {}}   # true air minus true bone, every frequency
	var poorer := "right" if rng.randf() < 0.5 else "left"
	var better := "left" if poorer == "right" else "right"
	match kind:
		"fit", "intake", "fluctuating":
			_symmetric(rng, air, _pick_shape(rng, FIT_SHAPES))
		"gap_both":
			_symmetric(rng, air, _pick_shape(rng, FIT_SHAPES))
			var g: int = GAP_BOTH_DB[rng.randi() % GAP_BOTH_DB.size()]
			for ear: String in ClinicRules.EARS:
				for fr: int in [500, 1000, 2000]:
					bone_gap[ear][fr] = g
				bone_gap[ear][4000] = g if rng.randf() < 0.5 else 0
		"one_ear", "today", "sudden_late":
			var on_fit := kind == "one_ear" and rng.randf() < ONE_EAR_ON_FIT
			_symmetric(rng, air, _pick_shape(rng, FIT_SHAPES if on_fit else MILD_SHAPES))
			var min_run := 3 if kind != "one_ear" else 2
			var min_delta := CaseRules.SUDDEN_MIN_DB if kind != "one_ear" else 25
			_band(rng, air[poorer], min_run, min_delta)
		"gap":
			_symmetric(rng, air, _pick_shape(rng, MILD_SHAPES))
			_conductive(rng, air, bone_gap, poorer)
	_fill_interoctaves(air)
	for ear: String in ClinicRules.EARS:
		for fr: int in air[ear]:
			if not bone_gap[ear].has(fr):
				bone_gap[ear][fr] = 5 if rng.randf() < 0.3 else 0
	var chart := final_chart(air, bone_gap)
	var intake := {}
	for id: String in sh["intake"]:
		intake[id] = false
	if kind == "intake":
		var ids: Array = sh["intake"]
		intake[flag if flag != "" else String(ids[rng.randi() % ids.size()])] = true
	var sudden := {}
	if bool(sh.get("sudden", false)):
		sudden = _sudden_card(rng, kind, poorer)
	var face := "gus" if rng.randf() < 0.5 else "doris"
	var first: String = (FIRST_A if face == "gus" else FIRST_B)[rng.randi() % FIRST_A.size()]
	var last: String = LAST[rng.randi() % LAST.size()]
	var said: Array = LINES[rng.randi() % LINES.size()]
	var f := {
		"serial": serial, "who": "desk_%d" % serial, "name": "%s %s" % [first, last],
		"age": rng.randi_range(50, 88) if want == &"fit" else rng.randi_range(34, 86),
		"line": said[0], "goal": said[1], "look": _look(rng, face), "want": want, "kind": kind, "boss": "",
		"ac": chart["ac"], "ac_masked": chart["ac_masked"], "bc": chart["bc"], "bc_masked": chart["bc_masked"],
		"intake": intake, "sudden": sudden, "poorer": poorer if kind in ["one_ear", "today", "sudden_late", "gap"] else "",
	}
	return f


static func _pick_shape(rng: RandomNumberGenerator, shapes: Dictionary) -> Array:
	var keys := shapes.keys()
	return shapes[keys[rng.randi() % keys.size()]]


## Both ears from one archetype: a shared 5 dB wobble per frequency, then up to 5 dB between ears.
static func _symmetric(rng: RandomNumberGenerator, air: Dictionary, shape: Array) -> void:
	for i in DeskRules.FREQS.size():
		var fr: int = DeskRules.FREQS[i]
		var base := int(shape[i]) + 5 * rng.randi_range(-1, 1)
		var other := base + 5 * rng.randi_range(-1, 1) if rng.randf() < 0.4 else base
		air["right"][fr] = ClinicRules.clamp_db(base, fr)
		air["left"][fr] = ClinicRules.clamp_db(other, fr)


## One ear made worse over a band of neighbouring frequencies, from a start pitch upward.
static func _band(rng: RandomNumberGenerator, ear_air: Dictionary, min_run: int, min_delta: int) -> void:
	var start: int = BAND_STARTS[rng.randi() % BAND_STARTS.size()]
	var i0 := DeskRules.FREQS.find(start)
	var room := DeskRules.FREQS.size() - i0
	var n := rng.randi_range(min_run, maxi(min_run, room))
	var delta := min_delta + 5 * rng.randi_range(0, 2)
	for i in range(i0, mini(i0 + n, DeskRules.FREQS.size())):
		var fr: int = DeskRules.FREQS[i]
		ear_air[fr] = ClinicRules.clamp_db(int(ear_air[fr]) + delta + 5 * rng.randi_range(0, 1), fr)


## One conductive ear: normal bone with a 20+ dB gap at every bone frequency (masked bone on the
## chart). The other ear keeps its milder sensorineural hearing.
static func _conductive(rng: RandomNumberGenerator, air: Dictionary, bone_gap: Dictionary, ear: String) -> void:
	var other := "left" if ear == "right" else "right"
	var g := 25 + 5 * rng.randi_range(0, 2)
	for fr: int in DeskRules.FREQS:
		var bone := 5 + 5 * rng.randi_range(0, 1)
		var gap := g + 5 * rng.randi_range(-1, 1)
		var v := bone + gap
		var o := int(air[other][fr])
		if fr >= 6000:
			# above the bone frequencies the air line follows the other ear, or sits clearly below it
			v = o if absi(v - o) < CLEAR_DB else v
			gap = 0
		elif absi(v - o) > MARGIN_DB and absi(v - o) < CLEAR_DB:
			# clearly worse than the other ear, never in between: a bigger gap on the same bone
			v = o + CLEAR_DB
			gap = v - bone
		air[ear][fr] = ClinicRules.clamp_db(v, fr)
		bone_gap[ear][fr] = int(air[ear][fr]) - bone if gap > 0 else 0


## Add 750 where the rules require it (both ears, as a clinic would): halfway, rounded to 5 dB, kept
## clear of the between-ear margin. 1.5, 3 and 6 kHz are always charted (DeskRules.FREQS).
static func _fill_interoctaves(air: Dictionary) -> void:
	var need := {}
	for ear: String in ClinicRules.EARS:
		for fr: int in ClinicRules.required_interoctaves(air[ear]):
			if not DeskRules.FREQS.has(fr):
				need[fr] = true
	for fr: int in need:
		if air["right"].has(fr):
			continue
		var pair: Array = ClinicRules.INTEROCTAVES[fr]
		var v := {}
		for ear: String in ClinicRules.EARS:
			var a: Dictionary = air[ear]
			v[ear] = int(round((int(a[pair[0]]) + int(a[pair[1]])) / 10.0)) * 5
		var d := int(v["right"]) - int(v["left"])
		if absi(d) > MARGIN_DB and absi(d) < CLEAR_DB:
			# keep the lower neighbour's difference between the ears (clear one way or the other)
			v["right"] = int(v["left"]) + int(air["right"][pair[0]]) - int(air["left"][pair[0]])
		for ear: String in ClinicRules.EARS:
			air[ear][fr] = ClinicRules.clamp_db(int(v[ear]), fr)


## The chart a clinician records from the true air and bone (bone IA 0, phones IA 40):
## air is masked where ClinicRules.ac_masking_needed; bone is masked where the unmasked response
## (the better cochlea) leaves a gap of ClinicRules.BC_MASK_GAP_DB (10 dB) or more
## (ClinicRules.bc_masking_needed), and then shows the ear's own bone.
static func final_chart(air: Dictionary, bone_gap: Dictionary) -> Dictionary:
	var true_bc := {"right": {}, "left": {}}
	for ear: String in ClinicRules.EARS:
		for fr: int in air[ear]:
			true_bc[ear][fr] = int(air[ear][fr]) - int(bone_gap[ear].get(fr, 0))
	var out := {"ac": {"right": {}, "left": {}}, "ac_masked": {"right": {}, "left": {}},
		"bc": {"right": {}, "left": {}}, "bc_masked": {"right": {}, "left": {}}}
	for ear: String in ClinicRules.EARS:
		var other := "left" if ear == "right" else "right"
		var keys: Array = (air[ear] as Dictionary).keys()
		keys.sort()
		for fr: int in keys:
			var a := int(air[ear][fr])
			out["ac"][ear][fr] = a
			if ClinicRules.ac_masking_needed(a, int(true_bc[other].get(fr, a)), &"phones", fr):
				out["ac_masked"][ear][fr] = true
		for fr: int in DeskRules.BONE_FREQS:
			var own := int(true_bc[ear][fr])
			var unmasked := mini(own, int(true_bc[other][fr]))
			if ClinicRules.bc_masking_needed(int(air[ear][fr]), unmasked):
				out["bc"][ear][fr] = own
				out["bc_masked"][ear][fr] = true
			else:
				out["bc"][ear][fr] = unmasked
	return out


## The alarm-clock card (shift 3): how fast it came on and when it started.
static func _sudden_card(rng: RandomNumberGenerator, kind: String, ear: String) -> Dictionary:
	match kind:
		"today":
			return {"pattern": "sudden", "came_on_h": [8, 30, 48][rng.randi() % 3], "days_ago": [1, 2, 3, 5, 9, 14][rng.randi() % 6], "ear": ear}
		"sudden_late":
			return {"pattern": "sudden", "came_on_h": [8, 30, 48][rng.randi() % 3], "days_ago": [75, 90, 120][rng.randi() % 3], "ear": ear}
		"fluctuating":
			return {"pattern": "fluctuating", "came_on_h": 0, "days_ago": [7, 10, 20][rng.randi() % 3], "ear": ""}
	return {"pattern": "gradual", "came_on_h": 0, "days_ago": 365 * rng.randi_range(2, 9), "ear": ""}


static func _look(rng: RandomNumberGenerator, face: String) -> Dictionary:
	var skin: String = SKINS[rng.randi() % SKINS.size()]
	var lk := {
		"face": face, "skin": skin, "nose": skin, "hair": HAIRS[rng.randi() % HAIRS.size()],
		"hair_style": (["tufts", "none"] if face == "gus" else ["bun", "beehive", "tufts"])[rng.randi() % (2 if face == "gus" else 3)],
		"cardigan": CLOTHES[rng.randi() % CLOTHES.size()], "shirt": "#fffdf8", "accent": CLOTHES[rng.randi() % CLOTHES.size()],
		"mustache": face == "gus" and rng.randf() < 0.4, "brows": rng.randf() < 0.5,
		"glasses": ["none", "round", "perched", "cateye"][rng.randi() % 4] if rng.randf() < 0.6 else "none",
		"glasses_color": "#2e2442", "extras": [], "portrait_bg": BGS[rng.randi() % BGS.size()], "name_color": "#2e2442",
	}
	return lk


static func _pick_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> Variant:
	var total := 0.0
	for k: Variant in weights:
		total += float(weights[k])
	var x := rng.randf() * total
	for k: Variant in weights:
		x -= float(weights[k])
		if x <= 0.0:
			return k
	return weights.keys()[-1]
