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
	for t: Dictionary in MaskDeck.WHEN_TRIES + MaskDeck.START_TRIES:
		lines.append(String(t["line"]))
	for a: StringName in MaskDeck.CALLS:
		lines.append(String(MaskDeck.CALL_VERDICTS[a]))
	lines.append(MaskDeck.when_hint({"transducer": "inserts"}))
	lines.append(MaskDeck.start_hint({}))
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
	room.call("open_station", 3)   # The plateau walk (not built yet)
	assert_eq(went, [], "a SOON station does not open")
	solvers[0].call()
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/masking/masking_school.tscn"])
	assert_eq(MaskingSchool.next_station, "why")


## A station plays through by its solvers: the movie on a fresh save (station 1 only), three tries,
## six holes at par, the scorecard saves the star and the card, and the solver leaves for the room.
func test_station_plays_by_solvers() -> void:
	await _play_by_solvers("why", 1)


func test_station_2_plays_by_solvers() -> void:
	await _play_by_solvers("when", 0)


func test_station_3_plays_by_solvers() -> void:
	await _play_by_solvers("start", 0)


func _play_by_solvers(id: String, movies: int) -> void:
	Game.cli = {"seed": 5}
	MaskingSchool.next_station = id
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
	assert_eq(int(beats.get(&"explainer", 0)), movies, "%s: the masking movie plays on a fresh save only before station 1" % id)
	assert_eq(int(beats.get(&"training_try", 0)), 3)
	assert_eq(int(beats.get(&"training_card", 0)), MaskDeck.ROUND_HOLES)
	assert_eq(MaskingSchool.last_result.get("station"), id)
	assert_eq(MaskingSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1])
	assert_true(bool(TrainingProgress.station("masking", id)["star"]))
	assert_true(TrainingProgress.has_card("masking", String(MaskDeck.station(id)["card"])))


# ---------------------------------------------------------------- station 2: mask it?

func _chart(tr: String, air: int, bone: int, f := 1000) -> Dictionary:
	return {"transducer": tr, "freq": f, "air": air, "bone": bone, "other_air": bone}


## Bone: a gap of 10 or more. Air: air minus the wall reaches the bone. Both from ClinicRules.
func test_mask_call_follows_the_rules() -> void:
	assert_eq(MaskDeck.mask_call(_chart("phones", 30, 30)), &"none")
	assert_eq(MaskDeck.mask_call(_chart("phones", 40, 30)), &"bone", "a gap of exactly 10 is masked")
	assert_eq(MaskDeck.mask_call(_chart("phones", 35, 30)), &"none", "a gap of 5 is not")
	assert_eq(MaskDeck.mask_call(_chart("phones", 70, 30)), &"both", "70 - 40 = 30 reaches 30")
	assert_eq(MaskDeck.mask_call(_chart("phones", 65, 30)), &"bone", "65 - 40 = 25 is under 30")
	assert_eq(MaskDeck.mask_call(_chart("inserts", 70, 30)), &"bone", "inserts: 70 - 55 = 15 is under 30")
	assert_eq(MaskDeck.mask_call(_chart("inserts", 85, 30)), &"both", "inserts: 85 - 55 = 30 reaches 30")
	for c: Dictionary in [_chart("phones", 70, 30), _chart("inserts", 70, 30), _chart("phones", 45, 40)]:
		assert_eq(MaskDeck.mask_bone(c), ClinicRules.bc_masking_needed(int(c["air"]), int(c["bone"])))
		assert_eq(MaskDeck.mask_air(c), ClinicRules.ac_masking_needed(int(c["air"]), int(c["bone"]), StringName(String(c["transducer"]))))


## With the unmasked bone as the other ear's bone, air never needs masking alone: a crossing tone
## means a gap of at least the wall (why station 2 has three answers, not four).
func test_air_alone_never_happens() -> void:
	for tr: String in ["phones", "inserts"]:
		for bone in range(-10, 75, 5):
			for air in range(bone, 125, 5):
				assert_true(MaskDeck.mask_call(_chart(tr, air, bone)) != &"air", "%s air %d bone %d" % [tr, air, bone])


## Rounds deal six honest charts with every call at least once, inside the audiometer's range.
func test_when_rounds_are_honest() -> void:
	var rng := RandomNumberGenerator.new()
	var seen_tr := {}
	for seed_i in 60:
		rng.seed = seed_i + 1
		var cards := MaskDeck.when_round(rng)
		assert_eq(cards.size(), MaskDeck.ROUND_HOLES)
		var calls := {}
		for c: Dictionary in cards:
			calls[MaskDeck.mask_call(c)] = true
			seen_tr[String(c["transducer"])] = true
			assert_true(MaskDeck.when_honest(c), "seed %d: chart %s hangs on a 5 dB wobble" % [seed_i, str(c)])
			assert_true(MaskDeck.WHEN_FREQS.has(int(c["freq"])))
			assert_true(int(c["air"]) >= int(c["bone"]), "air is never better than bone")
			assert_true(int(c["air"]) <= mini(MaskDeck.TONE_TOP_DB, ClinicRules.max_db(int(c["freq"]))), "air in range")
			assert_true(int(c["bone"]) < ClinicRules.BC_MAX_DB[int(c["freq"])], "bone under the buzzer's limit")
			assert_true(int(c["other_air"]) >= int(c["bone"]), "Lefty's air is no better than the best bone")
		for a: StringName in MaskDeck.CALLS:
			assert_true(calls.has(a), "seed %d: no %s chart" % [seed_i, a])
	assert_eq(seen_tr.keys().size(), 2, "headphones and inserts are both dealt")
	for tr: String in MaskDeck.WHEN_WEIGHTS:
		for a: StringName in MaskDeck.CALLS:
			assert_eq(String(MaskDeck.when_card(rng, a, tr)["transducer"]), tr, "%s / %s fell back" % [tr, a])


## Try it walks mask both, then the same ear with inserts (bone only), then no gap.
func test_when_tries() -> void:
	var calls: Array[StringName] = []
	for t: Dictionary in MaskDeck.WHEN_TRIES:
		calls.append(MaskDeck.mask_call(t))
	assert_eq(calls, [&"both", &"bone", &"none"])
	assert_eq(String(MaskDeck.WHEN_TRIES[1]["transducer"]), "inserts", "inserts save the air test")


# ---------------------------------------------------------------- station 3: set the dial

func _dial_card(test: String, f: int, other_air: int, gap: int, masker := "phones") -> Dictionary:
	return {"test": test, "freq": f, "other_air": other_air, "other_gap": gap, "masker": masker}


## The start level is ClinicRules.initial_masking: other air + 10, + occlusion for low bone on a
## normal ear under a headphone.
func test_start_level_follows_the_rules() -> void:
	assert_eq(MaskDeck.start_level(_dial_card("ac", 2000, 15, 0)), 25)
	assert_eq(MaskDeck.start_level(_dial_card("ac", 500, 15, 0)), 25, "air tests never add occlusion")
	assert_eq(MaskDeck.start_level(_dial_card("bc", 500, 15, 0)), 40, "15 + 10 + 15")
	assert_eq(MaskDeck.start_level(_dial_card("bc", 1000, 15, 5)), 35, "15 + 10 + 10")
	assert_eq(MaskDeck.start_level(_dial_card("bc", 4000, 15, 0)), 25, "no occlusion at 2k and up")
	assert_eq(MaskDeck.start_level(_dial_card("bc", 500, 15, 0, "inserts")), 25, "inserts: no occlusion")
	assert_eq(MaskDeck.start_level(_dial_card("bc", 500, 40, 30)), 50, "a blocked ear: no occlusion")
	assert_eq(MaskDeck.boom(_dial_card("bc", 250, 15, 10)), 15, "a gap of 10 is still a normal ear")
	assert_eq(MaskDeck.boom(_dial_card("bc", 250, 15, 15)), 0)
	assert_eq(MaskDeck.dial_strokes(40, _dial_card("bc", 500, 15, 0)), 1)
	assert_eq(MaskDeck.dial_strokes(35, _dial_card("bc", 500, 15, 0)), 2, "one step off: a bogey")
	assert_eq(MaskDeck.dial_strokes(25, _dial_card("bc", 500, 15, 0)), 3, "forgot the boom")


## Rounds deal one card of each kind (the boom twice), each honest about its kind.
func test_start_rounds() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_i in 60:
		rng.seed = seed_i + 1
		var cards := MaskDeck.start_round(rng)
		assert_eq(cards.size(), MaskDeck.ROUND_HOLES)
		var booms := 0
		for c: Dictionary in cards:
			var lvl := MaskDeck.start_level(c)
			assert_eq(lvl, ClinicRules.initial_masking(int(c["other_air"]), int(c["freq"]), &"bc" if c["test"] == "bc" else &"ac",
				int(c["other_gap"]), StringName(String(c["masker"]))))
			assert_between(lvl, ClinicRules.MASK_MIN_DB, ClinicRules.MASK_MAX_DB - 20, "the level fits the dial")
			assert_true(int(c["other_air"]) >= int(c["other_gap"]), "air is the bone plus the gap")
			assert_eq(MaskDeck.boom(c) > 0, String(c["kind"]) == "boom", "%s: the boom only on boom cards" % c["kind"])
			if MaskDeck.boom(c) > 0:
				booms += 1
			assert_false(MaskDeck.boom_line(c).is_empty())
		assert_eq(booms, 2)


func test_start_tries() -> void:
	var targets: Array[int] = []
	for t: Dictionary in MaskDeck.START_TRIES:
		targets.append(MaskDeck.start_level(t))
		assert_true(MaskDeck.start_level(t) > int(t["other_air"]), "the dial starts below Hoot's level")
	assert_eq(targets, [25, 40, 25], "air + 10; bone at 500 + 15 boom; inserts no boom")
