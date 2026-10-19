extends RefCounted
## ArcadeScores (arcade, story-internal): high-score tables and run history for the arcade modes,
## kept in the save under Game.progress["arcade"][mode] (docs/ARCADE.md). JSON brings ints back as
## floats and a hand-edited save can hold anything, so every read is defensive.
##   const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
##   ArcadeScores.table("chart_chute")                 # [{initials, score, accuracy}], best first
##   ArcadeScores.qualifies("chart_chute", 4200)       # makes the top TABLE_SIZE
##   ArcadeScores.add_score("chart_chute", "ABC", 4200, 0.96)   # -> its place (0-based), saved
##   ArcadeScores.add_run("chart_chute", {"right": 21, "oops": 1, "score": 4200})

const TABLE_SIZE := 10
const RUNS_KEPT := 12
## Every table starts with the cast on it, so a first-timer has someone to beat.
const SEED_TABLE: Array[Dictionary] = [
	{"initials": "HOO", "score": 6000, "accuracy": 1.0},
	{"initials": "GUS", "score": 3000, "accuracy": 0.95},
	{"initials": "BON", "score": 1500, "accuracy": 0.92},
]
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"


## This mode's save record, created on first use: {"table", "runs", "found", "initials"}.
static func data(mode: String) -> Dictionary:
	if not Game.progress.get("arcade", null) is Dictionary:
		Game.progress["arcade"] = {}
	var all: Dictionary = Game.progress["arcade"]
	if not all.get(mode, null) is Dictionary:
		all[mode] = {}
	var d: Dictionary = all[mode]
	for k: String in ["table", "runs", "found"]:
		if not d.get(k, null) is Array:
			d[k] = []
	if not d.get("initials", null) is String:
		d["initials"] = "AAA"
	return d


## Best first; the seed rows until the player beats them.
static func table(mode: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Variant in data(mode)["table"]:
		if row is Dictionary:
			out.append({"initials": clean_initials(str((row as Dictionary).get("initials", "???"))),
				"score": int((row as Dictionary).get("score", 0)), "accuracy": float((row as Dictionary).get("accuracy", 0.0)), "you": false})
	if out.is_empty():
		for row: Dictionary in SEED_TABLE:
			var r := row.duplicate()
			r["you"] = false
			out.append(r)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	return out


static func qualifies(mode: String, score: int) -> bool:
	if score <= 0:
		return false
	var t := table(mode)
	return t.size() < TABLE_SIZE or score > int(t[-1]["score"])


## Add a row and save; returns its place (0 = top), or -1 when it didn't make the table.
static func add_score(mode: String, initials: String, score: int, accuracy: float) -> int:
	if not qualifies(mode, score):
		return -1
	var t := table(mode)
	var row := {"initials": clean_initials(initials), "score": score, "accuracy": snappedf(accuracy, 0.001)}
	t.append(row)
	t.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	t.resize(mini(t.size(), TABLE_SIZE))
	var d := data(mode)
	var keep: Array = []
	for r: Dictionary in t:
		keep.append({"initials": r["initials"], "score": int(r["score"]), "accuracy": float(r["accuracy"])})
	d["table"] = keep
	d["initials"] = row["initials"]
	Game.save_game()
	return t.find(row)


## Keep the last RUNS_KEPT runs (for the results card's speed chart) and save.
static func add_run(mode: String, run: Dictionary) -> void:
	var d := data(mode)
	var runs: Array = d["runs"]
	runs.append(run)
	while runs.size() > RUNS_KEPT:
		runs.pop_front()
	Game.save_game()


static func runs(mode: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Variant in data(mode)["runs"]:
		if r is Dictionary:
			out.append({"right": int((r as Dictionary).get("right", 0)), "oops": int((r as Dictionary).get("oops", 0)),
				"score": int((r as Dictionary).get("score", 0))})
	return out


## Collectibles (Chart Chute's golden story charts): ids found so far.
static func found(mode: String) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in data(mode)["found"]:
		out.append(str(v))
	return out


static func mark_found(mode: String, id: String) -> void:
	var f: Array = data(mode)["found"]
	if not f.has(id):
		f.append(id)


## Three capital letters (anything else becomes "A").
static func clean_initials(s: String) -> String:
	var out := ""
	for c in s.to_upper().substr(0, 3):
		out += c if LETTERS.contains(c) else "A"
	while out.length() < 3:
		out += "A"
	return out


static func last_initials(mode: String) -> String:
	return clean_initials(str(data(mode)["initials"]))
