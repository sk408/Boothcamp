extends RefCounted
## TrainingProgress (training, story-internal): the Training room's save, kept under
## Game.progress["training"][lesson] (docs/training/MASKING_TRAINER.md §6). JSON brings ints back as
## floats and a hand-edited save can hold anything, so every read is defensive.
##   const TrainingProgress := preload("res://story/training/training_progress.gd")
##   TrainingProgress.record_round("masking", "why", 2, "skull_wall")   # -> {best, star, new_best, new_card}
##   TrainingProgress.station("masking", "why")                           # {best (-1 = never), star, plays}
##   TrainingProgress.cards("masking")                                    # earned cheat-sheet card ids


## This lesson's save record, created on first use: {"stations": {id: {...}}, "cards": [ids]}.
static func data(lesson: String) -> Dictionary:
	if not Game.progress.get("training", null) is Dictionary:
		Game.progress["training"] = {}
	var all: Dictionary = Game.progress["training"]
	if not all.get(lesson, null) is Dictionary:
		all[lesson] = {}
	var d: Dictionary = all[lesson]
	if not d.get("stations", null) is Dictionary:
		d["stations"] = {}
	if not d.get("cards", null) is Array:
		d["cards"] = []
	return d


## One station's record: best (strokes over par, -1 = never finished), star (a round at par), plays.
static func station(lesson: String, id: String) -> Dictionary:
	var rec: Variant = (data(lesson)["stations"] as Dictionary).get(id, {})
	var r: Dictionary = rec if rec is Dictionary else {}
	return {"best": int(r.get("best", -1)), "star": bool(r.get("star", false)), "plays": int(r.get("plays", 0))}


## A finished round: keep the best, star it at par or better (and star_ok: a station may ask for more,
## like the pocket card filled from blank), earn the station's card. Saves.
static func record_round(lesson: String, id: String, over_par: int, card := "", star_ok := true) -> Dictionary:
	var old := station(lesson, id)
	var over := maxi(0, over_par)
	var new_best: bool = int(old["best"]) < 0 or over < int(old["best"])
	var rec := {"best": over if new_best else int(old["best"]), "star": bool(old["star"]) or (over == 0 and star_ok), "plays": int(old["plays"]) + 1}
	(data(lesson)["stations"] as Dictionary)[id] = rec
	var new_card := false
	if card != "" and not has_card(lesson, card):
		(data(lesson)["cards"] as Array).append(card)
		new_card = true
	Game.save_game()
	return {"best": rec["best"], "star": rec["star"], "new_best": new_best, "new_card": new_card, "new_star": rec["star"] and not old["star"]}


## (the Practical) Earn a card outside a round's own (Station 2 earns two). True when it is new. Saves.
static func earn_card(lesson: String, id: String) -> bool:
	if id == "" or has_card(lesson, id):
		return false
	(data(lesson)["cards"] as Array).append(id)
	Game.save_game()
	return true


static func cards(lesson: String) -> PackedStringArray:
	var out := PackedStringArray()
	for v: Variant in data(lesson)["cards"]:
		out.append(str(v))
	return out


static func has_card(lesson: String, id: String) -> bool:
	return cards(lesson).has(id)


## Stars earned in a lesson.
static func stars(lesson: String) -> int:
	var n := 0
	for id: Variant in (data(lesson)["stations"] as Dictionary):
		if station(lesson, str(id))["star"]:
			n += 1
	return n
