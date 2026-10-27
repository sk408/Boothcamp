extends TestCase
## The Training room and Masking School (docs/training/MASKING_TRAINER.md): the deck's rules match
## ClinicRules, every dealt card is honest, the save is defensive, the title opens the room, and a
## station plays through by its beats' solvers.

const MaskDeck := preload("res://story/training/masking/mask_deck.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const MaskingSchool := preload("res://story/training/masking/masking_school.gd")
const TitleScreen := preload("res://story/title_screen.gd")
const Movies := preload("res://story/explainers/movies.gd")
const TrainingRoom := preload("res://story/training/training_room.gd")
const OeChip := preload("res://story/training/oe_chip.gd")


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
	for t: Dictionary in MaskDeck.PLUG_TRIES:
		lines.append(String(t["line"]))
	lines.append(MaskDeck.count_hint({}))
	for row: String in MaskDeck.OE_ROWS:
		for f: int in MaskDeck.OE_FREQS:
			lines.append(MaskDeck.oe_reason(row, f))
	for t: Dictionary in MaskDeck.WALK_TRIES:
		lines.append(String(t["line"]))
	for m: StringName in MaskDeck.MOVES:
		lines.append(MaskDeck.walk_nudge(m))
	var rng := RandomNumberGenerator.new()
	for k: String in MaskDeck.WALK_KINDS:
		lines.append(MaskDeck.walk_hint(MaskDeck.walk_patient(rng, k)))
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
	room.call("open_station", 9)   # no such station
	assert_eq(went, [], "only a station chip opens")
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


func test_station_4_plays_by_solvers() -> void:
	await _play_by_solvers("plateau", 0)


func test_station_5_plays_by_solvers() -> void:
	await _play_by_solvers("occlusion", 1, false)


## Station 5's star needs the pocket card filled from blank: the third visit starts blank.
func test_station_5_star_needs_a_blank_card() -> void:
	Game.progress["training"] = {"masking": {"stations": {"occlusion": {"best": 0, "star": false, "plays": 2}}, "cards": []}}
	Game.mark_movie_seen("plugged_ear")
	await _play_by_solvers("occlusion", 0, true)
	assert_true(bool(MaskingSchool.last_result.get("star_ok")), "a blank card on the third visit")


func _play_by_solvers(id: String, movies: int, star := true) -> void:
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
	assert_eq(int(beats.get(&"training_try", 0)), {"plateau": 1, "exam": 0}.get(id, 3))
	assert_eq(int(beats.get(&"training_scorecard", 0)), 1)
	assert_eq(int(beats.get(&"training_next", 0)), MaskDeck.holes(id))
	assert_eq(MaskingSchool.last_result.get("station"), id)
	var par: Array = []
	par.resize(MaskDeck.holes(id))
	par.fill(1)
	assert_eq(MaskingSchool.last_result.get("strokes"), par)
	assert_eq(bool(TrainingProgress.station("masking", id)["star"]), star, "%s: the star" % id)
	if id != "exam":
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


# ---------------------------------------------------------------- station 4: the plateau walk

func _walker(t_test: int, t_other: int, gap: int, f := 1000) -> Dictionary:
	return {"kind": "shift", "freq": f, "t_test": t_test, "t_other": t_other, "gap_other": gap, "masker": "phones"}


## The walk is ClinicRules' plateau dance: heard means shhh up, missed means beep up, three raises
## held at one beep = store; the practice patient's own numbers come out.
func test_walk_follows_the_rules() -> void:
	var p := _walker(30, 10, 0)
	assert_eq(MaskDeck.walk_initial(p), ClinicRules.initial_masking(10, 1000, &"bc", 0, &"phones"), "10 + 10 + 10 boom")
	assert_eq(MaskDeck.walk_start_tone(p), 10, "the unmasked bone: the better cochlea")
	var w := MaskDeck.walk_textbook(p)
	assert_eq(int(w["stored"]), 30, "the plateau is Righty's own bone")
	var recs: Array = w["records"]
	assert_eq(int(ClinicRules.plateau_run(recs)["steps"]), ClinicRules.PLATEAU_STEPS)
	for i in range(1, recs.size()):
		var a: Dictionary = recs[i - 1]
		var b: Dictionary = recs[i]
		var nx := ClinicRules.next_mask_step(int(a["db"]), int(a["mask_db"]), bool(a["responded"]))
		assert_eq(Vector2i(int(b["db"]), int(b["mask_db"])), nx, "step %d is the textbook move" % i)
	assert_false(bool((recs[0] as Dictionary)["responded"]), "the start masking covers Lefty at the start tone")
	# overmasking: enough noise crosses back onto Righty
	assert_false(MaskDeck.walk_hears(p, 30, ClinicRules.overmask_limit(30, &"bc") + 15), "too much shhh hushes Righty too")
	# a dilemma: both ears conductive, the start shhh already crosses back
	var d := _walker(5, 5, 45)
	assert_true(MaskDeck.walk_dilemma(d))
	assert_eq(MaskDeck.walk_move(d, MaskDeck.walk_first(d)), &"nosafe")
	assert_eq(int(MaskDeck.walk_textbook(d)["stored"]), -1)


## Rounds deal one patient of each kind, each walk honest: inside the green window and short.
func test_walk_rounds_are_honest() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_i in 40:
		rng.seed = seed_i + 1
		var ps := MaskDeck.walk_round(rng)
		assert_eq(ps.size(), MaskDeck.holes("plateau"))
		var kinds := {}
		for p: Dictionary in ps:
			kinds[String(p["kind"])] = true
			assert_true(MaskDeck.walk_honest(p), "seed %d: %s" % [seed_i, str(p)])
			var w := MaskDeck.walk_textbook(p)
			match String(p["kind"]):
				"shift":
					assert_true(int(p["t_test"]) > MaskDeck.walk_start_tone(p), "the beep shifts up")
				"true":
					assert_eq(int(w["stored"]), MaskDeck.walk_start_tone(p), "flat from the start")
					assert_eq(int(w["moves"]), ClinicRules.PLATEAU_STEPS + 1)
		assert_eq(kinds.size(), MaskDeck.WALK_KINDS.size())
	for k: String in MaskDeck.WALK_KINDS:
		rng.seed = 99
		assert_true(MaskDeck.walk_honest(MaskDeck.walk_patient(rng, k)), "%s never falls back to a dishonest patient" % k)


func test_walk_try() -> void:
	for t: Dictionary in MaskDeck.WALK_TRIES:
		assert_true(MaskDeck.walk_honest(t))
		assert_true(int(t["t_test"]) > MaskDeck.walk_start_tone(t), "Try it shows the beep chasing the shhh")


# ---------------------------------------------------------------- station 5: the occlusion effect

const Movies5 := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")


## The pocket card is ClinicRules.OCCLUSION_DB: headphones 15, 15, 10, 10, 0, 0; inserts all 0.
func test_pocket_card_follows_the_rules() -> void:
	var row: Array[int] = []
	for f: int in MaskDeck.OE_FREQS:
		row.append(MaskDeck.oe_cell("phones", f))
		assert_eq(MaskDeck.oe_cell("phones", f), ClinicRules.occlusion_effect(f, &"phones"))
		assert_eq(MaskDeck.oe_cell("inserts", f), 0)
		assert_has(MaskDeck.OE_TILES, MaskDeck.oe_cell("phones", f), "a tile exists for %d" % f)
	assert_eq(row, [15, 15, 10, 10, 0, 0])
	assert_eq(MaskDeck.oe_boost("open", 250), 0)
	assert_eq(MaskDeck.oe_boost("blocked", 250), 0)
	# the plug lab's steps land on +15, 0 and 0
	var got: Array[int] = []
	for t: Dictionary in MaskDeck.PLUG_TRIES:
		got.append(MaskDeck.oe_boost(String(t["cover"]), int(t["freq"])))
		assert_false(String(t["start_cover"]) == String(t["cover"]) and int(t["start_freq"]) == int(t["freq"]), "each step has something to set")
	assert_eq(got, [15, 0, 0])
	# spaced repetition: fewer helpers each visit, blank from the third
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var sizes: Array[int] = []
	for plays in 4:
		sizes.append(MaskDeck.oe_blanks(rng, MaskDeck.oe_prefilled(plays)).size())
	assert_eq(sizes, [4, 8, 12, 12])


## "Does it count?": only bone, a low pitch, a normal covered ear under a headphone. Two of six.
func test_does_it_count() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_i in 30:
		rng.seed = seed_i + 1
		var adds := 0
		for c: Dictionary in MaskDeck.count_round(rng):
			var want: bool = c["test"] == "bc" and int(c["freq"]) < 2000 and int(c["other_gap"]) <= ClinicRules.OCCLUSION_MAX_GAP_DB and c["masker"] == "phones"
			assert_eq(MaskDeck.count_answer(c) == &"add", want, str(c))
			if want:
				adds += 1
		assert_eq(adds, 2)


func test_plugged_ear_movie() -> void:
	var bad := Movies5.validate("plugged_ear", Stage2D.SETS)
	assert_true(bad.is_empty(), ", ".join(bad))
	assert_has(Movies5.replay_ids(), "plugged_ear", "on the title's movie list")
	assert_true(Movies5.is_training("plugged_ear"), "a training movie")
	assert_false(Movies5.for_chapter("bonnie").has("plugged_ear"), "never Day 2's own movie")
	assert_eq(Movies5.day_label("plugged_ear"), "Training")
	assert_eq(String(MaskDeck.station("occlusion")["movie"]), "plugged_ear")
	var player_script: GDScript = load("res://story/explainers/explainer_player.gd")
	var cue_max := float(player_script.get_script_constant_map()["CUE_MAX_DB"])
	var m := Movies5.movie("plugged_ear")
	for sc: Dictionary in m["scenes"]:
		for cue: Dictionary in sc.get("cues", []):
			assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s: a known Sfx" % sc["id"])
			assert_true(float(cue.get("vol_db", 0.0)) <= cue_max, "%s: quiet" % sc["id"])
	# the lows scene sweeps the pocket card's pitches
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", m)
	for sc: Dictionary in m["scenes"]:
		st.call("show_scene", sc)
		var d := float(sc["duration"])
		for tt: float in [0.0, d * 0.3, d * 0.6, d]:
			st.set("t", tt)
			st.queue_redraw()
			await wait_frames(1)
	st.queue_free()


# ---------------------------------------------------------------- station 6: the exam

## The exam: nine mixed holes, no Try it, no movie; par earns the star, an S and the diploma.
func test_station_6_plays_by_solvers() -> void:
	await _play_by_solvers("exam", 0)
	assert_eq(MaskingSchool.last_result.get("grade"), "S")
	assert_true(bool(MaskingSchool.last_result.get("diploma")), "the first finished exam earns the diploma")
	assert_true(TrainingRoom.has_diploma())


## Two of each pick, two dials, a walk, a boom call and a dilemma, every card honest by its own rules.
func test_exam_rounds_are_honest() -> void:
	var rng := RandomNumberGenerator.new()
	for seed in 60:
		rng.seed = seed
		var cards := MaskDeck.exam_round(rng)
		assert_eq(cards.size(), MaskDeck.holes("exam"))
		var by := {}
		var dilemmas := 0
		for c: Dictionary in cards:
			var r := String(c["rules"])
			by[r] = int(by.get(r, 0)) + 1
			match r:
				"why":
					assert_true(MaskDeck.who_heard(c) in MaskDeck.WHO, "a who-heard card")
				"when":
					assert_true(MaskDeck.mask_call(c) in MaskDeck.CALLS)
				"start", "occlusion":
					assert_true(MaskDeck.start_level(c) >= ClinicRules.MASK_MIN_DB)
				"plateau":
					assert_true(MaskDeck.walk_honest(c), "an honest walk")
					if MaskDeck.walk_dilemma(c):
						dilemmas += 1
			assert_ne(MaskDeck.exam_label(c), "")
		assert_eq(by, {"why": 2, "when": 2, "start": 2, "plateau": 2, "occlusion": 1}, "seed %d" % seed)
		assert_eq(dilemmas, 1, "one dilemma, seed %d" % seed)


func test_exam_grades() -> void:
	assert_eq(MaskDeck.exam_grade(0), "S")
	assert_eq(MaskDeck.exam_grade(2), "A")
	assert_eq(MaskDeck.exam_grade(5), "B")
	assert_eq(MaskDeck.exam_grade(6), "C")


## No hints on a first try: H does nothing (no stroke) until a wrong answer, then it costs one.
func test_exam_hint_waits_for_a_miss() -> void:
	Game.cli = {"seed": 3}
	MaskingSchool.next_station = "exam"
	var cards: Array = []
	var acb := func(beat: StringName, data: Dictionary, solver: Callable) -> void:
		if beat == &"training_intro":
			solver.call_deferred()
		elif beat == &"training_card":
			cards.append(data)
	Events.awaiting_input.connect(acb)
	var school: Control = (load("res://story/training/masking/masking_school.tscn") as PackedScene).instantiate()
	add_node(school)
	for i in 120:
		if not cards.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	assert_false(cards.is_empty(), "the first hole")
	var rules := String(cards[0]["rules"])
	school.call("hint")
	assert_eq(int(school.get("_hole_strokes")), 1, "a first-try hint is refused")
	if rules != "start":
		var opts: Array = cards[0]["options"]
		school.call("pick", school.call("_options")[(int(cards[0]["best"]) + 1) % opts.size()])
		assert_eq(int(school.get("_hole_strokes")), 2, "a miss")
		school.call("hint")
		assert_eq(int(school.get("_hole_strokes")), 3, "after a miss the hint opens (+1)")
	school.call("leave")
	await wait_frames(2)


## The print view: only with all five cards; it draws every card and closes with Enter.
func test_print_view() -> void:
	Game.progress["training"] = {"masking": {"stations": {}, "cards": ["skull_wall", "when_to_mask", "start_level", "plateau"]}}
	var room: Control = (load("res://story/training/training_room.tscn") as PackedScene).instantiate()
	add_node(room)
	await wait_frames(2)
	assert_false(bool(room.call("can_print")), "four cards: no print view")
	assert_true(room.find_child("print_view_button", true, false) == null)
	room.call("open_print")
	assert_true(room.find_child("PrintView", true, false) == null)
	room.queue_free()
	await wait_frames(2)
	(Game.progress["training"]["masking"]["cards"] as Array).append("occlusion")
	room = (load("res://story/training/training_room.tscn") as PackedScene).instantiate()
	add_node(room)
	await wait_frames(2)
	assert_true(bool(room.call("can_print")))
	assert_true(room.find_child("print_view_button", true, false) != null, "the tile replaces More lessons soon")
	room.call("open_print")
	await wait_frames(2)
	var pv: Node = room.find_child("PrintView", true, false)
	assert_true(pv != null, "the print view opens")
	for id: String in MaskDeck.CARD_ORDER:
		var cc: Node = pv.find_child("print_" + id, true, false)
		assert_true(cc != null and bool(cc.get("earned")), "%s on the page" % id)
	pv.call("close_view")
	await wait_frames(2)
	assert_true(room.find_child("PrintView", true, false) == null, "closed")


## The AudiOtron's OE chip: shown with the MASKING group once the pocket card is earned; opens the card.
func test_oe_chip() -> void:
	Game.progress["training"] = {}
	assert_false(OeChip.earned())
	Game.progress["training"] = {"masking": {"stations": {}, "cards": ["occlusion"]}}
	assert_true(OeChip.earned())
	var chip: Control = OeChip.new()
	add_node(chip)
	await wait_frames(1)
	chip.call("toggle")
	var card: Node = chip.find_child("oe_card", true, false)
	assert_true(card != null and String(card.get("card")["id"]) == "occlusion", "the pocket card opens")
	chip.call("toggle")
	assert_false(bool(chip.call("is_open")), "and closes")


## On a story day the chip rides the MASKING group: hidden before the card is earned, shown after.
func test_audiotron_oe_chip() -> void:
	for earned: bool in [false, true]:
		Game.progress["training"] = {"masking": {"stations": {}, "cards": ["occlusion"] if earned else []}}
		var screen: Node = (load("res://ui/audiometer/audiometer_screen.tscn") as PackedScene).instantiate()
		add_node(screen)
		await wait_frames(1)
		screen.call("start_test", Game.load_patient("bonnie"), "right", false, {"test": "bc", "hoot_turn_after": 99})
		await wait_frames(2)
		var chip: Control = screen.find_child("oe_chip", true, false)
		assert_true(chip != null, "the AudiOtron carries the chip")
		assert_eq(chip.visible, earned, "shown only with the pocket card earned")
		screen.queue_free()
		await wait_frames(2)
	# Day 1's air test has no MASKING group, so no chip even with the card
	var day1: Node = (load("res://ui/audiometer/audiometer_screen.tscn") as PackedScene).instantiate()
	add_node(day1)
	await wait_frames(1)
	day1.call("start_test", Game.load_patient("gus"), "right", true)
	await wait_frames(2)
	assert_false((day1.find_child("oe_chip", true, false) as Control).visible, "no chip without the MASKING group")

