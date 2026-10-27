extends TestCase
## The Training room and Masking School (docs/training/MASKING_TRAINER.md): the deck's rules match
## ClinicRules, every dealt card is honest, the save is defensive, the title opens the room, and a
## station plays through by its beats' solvers.

const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const MaskingSchool := preload("res://story/training/masking/masking_school.gd")
const TitleScreen := preload("res://story/title_screen.gd")
const Movies := preload("res://story/explainers/movies.gd")


func before_each() -> void:
	Game.reset_save()
	Game.cli = {}


func after_each() -> void:
	Game.reset_save()
	Game.cli = {}


func _card(tr: String, tone: int, test_thr: int, other_thr: int) -> Dictionary:
	return {"transducer": tr, "tone": tone, "test_thr": test_thr, "other_thr": other_thr}


## The wall is the story's rule IA, and "who heard it" is ClinicRules.ac_masking_needed.
func test_who_heard_follows_the_rules() -> void:
	assert_eq(MaskDeck.wall("phones"), ClinicRules.IA_RULE_DB[&"phones"])
	assert_eq(MaskDeck.wall("inserts"), ClinicRules.IA_RULE_DB[&"inserts"])
	assert_eq(MaskDeck.wall("bone"), 0)
	assert_eq(MaskDeck.who_heard(_card("phones", 70, 20, 10)), &"either", "70 - 40 = 30 reaches 10, and the test ear hears 70")
	assert_eq(MaskDeck.who_heard(_card("inserts", 70, 20, 10)), &"either", "70 - 55 = 15 still reaches 10")
	assert_eq(MaskDeck.who_heard(_card("inserts", 60, 20, 20)), &"test", "60 - 55 = 5 is under 20")
	assert_eq(MaskDeck.who_heard(_card("phones", 70, 100, 10)), &"ghost", "a dead test ear: only the Ghost")
	assert_eq(MaskDeck.who_heard(_card("bone", 20, 5, 10)), &"either", "bone has no wall")
	assert_eq(MaskDeck.who_heard(_card("bone", 20, 5, 40)), &"test", "bone, a poorer other cochlea")
	assert_eq(MaskDeck.who_heard(_card("phones", 30, 50, 20)), &"", "nobody hears it")
	assert_eq(MaskDeck.who_heard(_card("phones", 50, 20, 10)), &"either", "exactly on the line: 50 - 40 = 10 counts")


## Rounds deal six honest cards with every answer at least once, over many seeds.
func test_rounds_are_honest() -> void:
	var rng := RandomNumberGenerator.new()
	var seen_tr := {}
	for seed_i in 60:
		rng.seed = seed_i + 1
		var cards := MaskDeck.who_heard_round(rng)
		assert_eq(cards.size(), MaskDeck.ROUND_HOLES, "seed %d" % seed_i)
		var answers := {}
		for c: Dictionary in cards:
			var a := MaskDeck.who_heard(c)
			answers[a] = true
			seen_tr[String(c["transducer"])] = true
			assert_true(MaskDeck.is_honest(c), "seed %d: card %s hangs on a 5 dB wobble" % [seed_i, str(c)])
			assert_eq(int(c["tone"]) % 5, 0, "a real 5 dB step")
			assert_between(int(c["tone"]), 10, MaskDeck.TONE_TOP_DB, "the beep in range")
			assert_true(int(c["tone"]) <= ClinicRules.max_db_for(1000, StringName(String(c["transducer"]))), "inside the transducer's output")
			assert_eq(a == &"either" or a == &"ghost", ClinicRules.ac_masking_needed(int(c["tone"]), int(c["other_thr"]), StringName(String(c["transducer"]))),
				"the Ghost can answer exactly when the story's masking rule says so")
		for a: StringName in MaskDeck.WHO:
			assert_true(answers.has(a), "seed %d: no %s card" % [seed_i, a])
	for tr: String in MaskDeck.TRANSDUCER_WEIGHTS:
		assert_true(seen_tr.has(tr), "%s is dealt" % tr)


## Every answer can be dealt on every earphone (the generator never falls back).
func test_every_answer_on_every_earphone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for tr: String in MaskDeck.TRANSDUCER_WEIGHTS:
		for a: StringName in MaskDeck.WHO:
			var c := MaskDeck.who_card(rng, a, tr)
			assert_eq(String(c["transducer"]), tr, "%s / %s fell back" % [tr, a])
			assert_eq(MaskDeck.who_heard(c), a)


## Try it: the Ghost answers first, at other ear + wall, inside the output range.
func test_try_cards_reach_the_ghost() -> void:
	assert_eq(MaskDeck.WHY_TRIES.size(), 3)
	var targets: Array[int] = []
	for t: Dictionary in MaskDeck.WHY_TRIES:
		var target := MaskDeck.try_target(t)
		targets.append(target)
		assert_true(target <= MaskDeck.try_max(t), "%s: the target fits the dial" % t["transducer"])
		assert_true(target > int(t["tone"]), "it starts below the Ghost")
		assert_eq((target - int(t["tone"])) % MaskDeck.TRY_STEP_DB, 0, "reachable in steps")
		assert_true(int(t["test_thr"]) > target, "the test ear can't hear it first: the Ghost answers")
		var c := t.duplicate()
		c["tone"] = target
		assert_eq(MaskDeck.who_heard(c), &"ghost")
		c["tone"] = target - MaskDeck.TRY_STEP_DB
		assert_eq(MaskDeck.who_heard(c), &"", "one step softer, nobody hears it")
	assert_eq(targets, [50, 65, 10], "headphones 10 + 40, inserts 10 + 55, bone 10 + 0")


## The cheat-sheet cards read their numbers from ClinicRules.
func test_cheat_cards() -> void:
	for id: String in MaskDeck.CARD_ORDER:
		var c := MaskDeck.cheat_card(id)
		assert_false(c.is_empty(), id)
		assert_true((c["lines"] as Array).size() <= 4, "%s fits its card" % id)
		for line: String in c["lines"]:
			assert_true(line.length() <= 42, "%s: '%s' is short" % [id, line])
	var wall := " ".join(MaskDeck.cheat_card("skull_wall")["lines"])
	assert_has(wall, "Headphones %d" % ClinicRules.IA_RULE_DB[&"phones"])
	assert_has(wall, "Inserts %d" % ClinicRules.IA_RULE_DB[&"inserts"])
	var oe := " ".join(MaskDeck.cheat_card("occlusion")["lines"])
	assert_has(oe, "250 +%d" % ClinicRules.occlusion_effect(250))
	assert_has(oe, "1k +%d" % ClinicRules.occlusion_effect(1000))
	for s: Dictionary in MaskDeck.STATIONS:
		var card := String(s["card"])
		assert_true(card == "" or MaskDeck.CARD_ORDER.has(card), "%s earns a known card" % s["id"])


## Hoot's lines stay short (18 words or fewer).
func test_hoot_lines_are_short() -> void:
	var lines: Array[String] = []
	for t: Dictionary in MaskDeck.WHY_TRIES:
		lines.append(String(t["line"]))
	for a: StringName in MaskDeck.WHO:
		lines.append(String(MaskDeck.WHO_VERDICTS[a]))
	for tr: String in ["phones", "inserts", "bone"]:
		lines.append(MaskDeck.hint_line({"transducer": tr}))
	for l: String in lines:
		assert_true(Movies.word_count(l) <= Hoot.MAX_WORDS, "too long for Hoot: " + l)


## The save: best and star kept, the card earned once, garbage tolerated.
func test_progress_save() -> void:
	assert_eq(TrainingProgress.station("masking", "why"), {"best": -1, "star": false, "plays": 0})
	var r1 := TrainingProgress.record_round("masking", "why", 3, "skull_wall")
	assert_true(bool(r1["new_card"]) and bool(r1["new_best"]))
	assert_false(bool(r1["star"]))
	var r2 := TrainingProgress.record_round("masking", "why", 0, "skull_wall")
	assert_false(bool(r2["new_card"]), "the card is earned once")
	assert_true(bool(r2["star"]) and bool(r2["new_star"]))
	var r3 := TrainingProgress.record_round("masking", "why", 4, "skull_wall")
	assert_eq(int(r3["best"]), 0, "the best stays")
	assert_true(bool(r3["star"]), "a star stays")
	assert_eq(TrainingProgress.station("masking", "why")["plays"], 3)
	assert_eq(TrainingProgress.cards("masking"), PackedStringArray(["skull_wall"]))
	assert_eq(TrainingProgress.stars("masking"), 1)
	# a hand-edited save
	Game.progress["training"] = {"masking": {"stations": {"why": "oops"}, "cards": "nope"}}
	assert_eq(TrainingProgress.station("masking", "why")["best"], -1)
	assert_eq(TrainingProgress.cards("masking").size(), 0)
	Game.progress["training"] = 5
	assert_eq(TrainingProgress.stars("masking"), 0)
	assert_true(Game.DEFAULT_PROGRESS.has("training"), "the save keeps the training key")


## The title has a Training button beside Days, and it opens the Training room.
func test_title_training_button() -> void:
	TitleScreen._notice_seen_this_session = true
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	await wait_seconds(0.6)
	var labels: Array[String] = []
	for b: Button in title.get("_menu_buttons"):
		labels.append(String(b.get_meta("label")))
	assert_eq(labels.slice(0, 5), ["Play", "Days", "Training", "Freestyle", "Arcade"])
	var days: Button = title.get("_menu_buttons")[1]
	var training: Button = title.get("_menu_buttons")[2]
	assert_eq(days.get_parent(), training.get_parent(), "Days and Training share a row")
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	title.call("_on_training")
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"])


## The room: a SOON station stays put; station 1 opens the school with next_station set.
func test_room_opens_built_stations_only() -> void:
	var room: Control = (load("res://story/training/training_room.tscn") as PackedScene).instantiate()
	var solvers: Array[Callable] = []
	var acb := func(beat: StringName, _info: Dictionary, solver: Callable) -> void:
		if beat == &"training_room":
			solvers.append(solver)
	Events.awaiting_input.connect(acb)
	add_node(room)
	await wait_frames(2)
	Events.awaiting_input.disconnect(acb)
	assert_eq(solvers.size(), 1, "the room emits its beat")
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	MaskingSchool.next_station = ""
	room.call("open_station", 1)   # When to mask? (not built yet)
	assert_eq(went, [], "a SOON station does not open")
	solvers[0].call()
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/masking/masking_school.tscn"])
	assert_eq(MaskingSchool.next_station, "why")


## A station plays through by its solvers: the movie on a fresh save, three tries, six holes at par,
## the scorecard saves the star and the card, and the solver leaves for the room.
func test_station_plays_by_solvers() -> void:
	Game.cli = {"seed": 5}
	MaskingSchool.next_station = "why"
	MaskingSchool.last_result = {}
	var beats := {}
	var acb := func(beat: StringName, _info: Dictionary, solver: Callable) -> void:
		beats[beat] = int(beats.get(beat, 0)) + 1
		solver.call_deferred()
	Events.awaiting_input.connect(acb)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	var school: Control = (load("res://story/training/masking/masking_school.tscn") as PackedScene).instantiate()
	add_node(school)
	for i in 600:
		if not went.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"], "back to the room")
	assert_eq(int(beats.get(&"explainer", 0)), 1, "the masking movie plays on a fresh save")
	assert_eq(int(beats.get(&"training_try", 0)), MaskDeck.WHY_TRIES.size())
	assert_eq(int(beats.get(&"training_card", 0)), MaskDeck.ROUND_HOLES)
	assert_eq(MaskingSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1])
	assert_true(bool(TrainingProgress.station("masking", "why")["star"]))
	assert_true(TrainingProgress.has_card("masking", "skull_wall"))
