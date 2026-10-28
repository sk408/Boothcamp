extends TestCase
## The Practical, the Training room's second lesson (docs/training/PRACTICAL_EXAM.md): the deck is
## complete, every dealt "Pack the bag" card is honest, the room's lesson tabs switch the board, and
## Station 1 plays through by its beats' solvers.

const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const PracticalSchool := preload("res://story/training/practical/practical_school.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const TrainingRoom := preload("res://story/training/training_room.gd")
const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const PracticalArt := preload("res://story/training/practical/practical_art.gd")


func before_each() -> void:
	Game.reset_save()
	Game.cli = {}
	TrainingRoom.lesson = "masking"
	TrainingRoom.last = 0


func after_each() -> void:
	Game.reset_save()
	Game.cli = {}
	TrainingRoom.lesson = "masking"
	TrainingRoom.last = 0


## Eight stations in the real exam's order, eight cards, each card earned by a station.
func test_deck_is_complete() -> void:
	assert_eq(PracticalDeck.station_ids(), ["kit", "hands", "tones", "td", "impression", "delivery", "bench", "exam"])
	for i in PracticalDeck.STATIONS.size():
		var s: Dictionary = PracticalDeck.STATIONS[i]
		assert_eq(int(s["num"]), i + 1)
		for k: String in ["name", "pitch", "color", "card", "built", "intro"]:
			assert_true(s.has(k), "%s has %s" % [s["id"], k])
	assert_eq(PracticalDeck.CARD_ORDER.size(), 8)
	for id: String in PracticalDeck.CARD_ORDER:
		var c := PracticalDeck.cheat_card(id)
		assert_false(c.is_empty(), "card %s" % id)
		assert_true(PracticalDeck.card_station(id) > 0, "a station earns %s" % id)
		assert_true((c["lines"] as Array).size() >= 3 and (c["lines"] as Array).size() <= 4, "%s: 3-4 lines fit a pinned card" % id)
	assert_true(bool(PracticalDeck.station("kit")["built"]))
	assert_true(bool(PracticalDeck.station("hands")["built"]))
	assert_eq(PracticalDeck.cheat_card("nope"), {})


## The kit table: twelve items go in the bag, and every decoy says why it stays home.
func test_kit_items_follow_the_bulletin() -> void:
	var goods := 0
	for id: String in PracticalDeck.ITEMS:
		var it: Dictionary = PracticalDeck.ITEMS[id]
		if bool(it["ok"]):
			goods += 1
		else:
			assert_true(String(it.get("why", "")) != "", "%s says why" % id)
	assert_eq(goods, 12)
	assert_false(bool(PracticalDeck.ITEMS["inserts"]["ok"]), "the exam wants non-insert headphones")
	assert_true(String(PracticalDeck.ITEMS["jumbo_gel"]["why"]).contains(str(PracticalDeck.SANITIZER_MAX_OZ)))


## Every dealt round is honest: one decoy per tray, one sticker in date, the fix matches the fault, one
## subject who qualifies and one who doesn't.
func test_kit_round_is_honest() -> void:
	for seed in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cards := PracticalDeck.kit_round(rng)
		assert_eq(cards.size(), PracticalDeck.ROUND_HOLES)
		var kinds: Array = cards.map(func(c: Dictionary) -> String: return String(c["kind"]))
		assert_eq(kinds, ["tray", "tray", "sticker", "listen", "subject", "subject"])
		var decoys: Array = []
		var oks := 0
		for c: Dictionary in cards:
			var ans := int(c["answer"])
			assert_true(ans >= 0 and ans < (c["options"] as Array).size(), "answer in range")
			assert_eq((c["lines"] as Array).size(), 2)
			assert_true(String(c["hint"]) != "")
			match String(c["kind"]):
				"tray":
					var bad := 0
					for id: Variant in c["items"]:
						if not bool(PracticalDeck.ITEMS[String(id)]["ok"]):
							bad += 1
					assert_eq(bad, 1, "one decoy per tray")
					assert_false(bool(PracticalDeck.ITEMS[String(c["items"][ans])]["ok"]))
					decoys.append(String(c["items"][ans]))
				"sticker":
					var backs: Array = c["backs"]
					for i in backs.size():
						assert_eq(int(backs[i]) <= PracticalDeck.CAL_MONTHS, i == ans, "only the answer is in date")
						assert_true(absi(int(backs[i]) - PracticalDeck.CAL_MONTHS) >= 2, "no sticker on the edge")
				"listen":
					assert_eq(PracticalDeck.FIXES[ans], String(c["fault"]))
				"subject":
					assert_eq(ans == 0, bool(c["ok"]))
					if bool(c["ok"]):
						oks += 1
		assert_ne(decoys[0], decoys[1], "two different decoys")
		assert_eq(oks, 1, "one subject qualifies, one doesn't")


func test_kit_tries_and_months() -> void:
	var tries := PracticalDeck.tries("kit")
	assert_eq(tries.size(), 2)
	for t: Dictionary in tries:
		assert_true(String(t["line"]) != "")
		assert_true(int(t["answer"]) >= 0)
	assert_eq(String(tries[0]["items"][int(tries[0]["answer"])]), "inserts")
	assert_eq(PracticalDeck.month_word(PracticalDeck.EXAM_MONTH), "Mar 2027")
	assert_eq(PracticalDeck.month_word(PracticalDeck.EXAM_MONTH - 3), "Dec 2026")
	assert_eq(PracticalDeck.deal("delivery", RandomNumberGenerator.new()), [], "unbuilt stations deal nothing")


## The room's tabs: Masking School first; THE PRACTICAL shows eight chips and its own cards, emits its
## beat again, and its first chip opens Pack the bag; a SOON chip stays put.
func test_room_switches_to_the_practical() -> void:
	var room: Control = (load("res://story/training/training_room.tscn") as PackedScene).instantiate()
	var beats: Array[Dictionary] = []
	var solvers: Array[Callable] = []
	var acb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"training_room":
			beats.append(info)
			solvers.append(solver)
	Events.awaiting_input.connect(acb)
	add_node(room)
	await wait_frames(2)
	assert_eq(String(beats[0]["lesson"]), "masking")
	assert_eq((room.get("_chips") as Array).size(), 6)
	room.call("select_lesson", "practical")
	await wait_frames(2)
	Events.awaiting_input.disconnect(acb)
	assert_eq(beats.size(), 2, "the switch emits the beat again")
	assert_eq(String(beats[1]["lesson"]), "practical")
	assert_eq(beats[1]["built"], ["kit", "hands", "tones", "td", "impression"])
	assert_eq((room.get("_chips") as Array).size(), 8)
	assert_true(room.find_child("card_kit_bag", true, false) != null, "the practical's pins")
	assert_true(room.find_child("card_skull_wall", true, false) == null, "masking's pins are gone")
	assert_false(bool(room.call("can_print")), "no print view on The Practical")
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	room.call("open_station", 5)   # SOON
	assert_eq(went, [])
	PracticalSchool.next_station = ""
	solvers[1].call()
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/practical/practical_school.tscn"])
	assert_eq(PracticalSchool.next_station, "kit")
	assert_eq(TrainingRoom.lesson, "practical", "the room comes back on the same lesson")


## Tab cycles the lessons.
func test_tab_key_switches_lessons() -> void:
	var room: Control = (load("res://story/training/training_room.tscn") as PackedScene).instantiate()
	add_node(room)
	await wait_frames(2)
	room.call("next_lesson")
	assert_eq(TrainingRoom.lesson, "practical")
	room.call("next_lesson")
	assert_eq(TrainingRoom.lesson, "masking")


## Station 1 plays through by its solvers: two guided tries, six holes at par, the star and the Kit Bag
## card saved, back to the room.
func test_kit_plays_by_solvers() -> void:
	Game.cli = {"seed": 7}
	PracticalSchool.next_station = "kit"
	PracticalSchool.last_result = {}
	var beats := {}
	var acb := func(beat: StringName, _info: Dictionary, solver: Callable) -> void:
		beats[beat] = int(beats.get(beat, 0)) + 1
		solver.call_deferred()
	Events.awaiting_input.connect(acb)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	add_node(school)
	for i in 600:
		if not went.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"], "back to the room")
	assert_eq(int(beats.get(&"practical_try", 0)), 2)
	assert_eq(int(beats.get(&"practical_card", 0)), 6)
	assert_eq(int(beats.get(&"practical_next", 0)), 8, "two tries and six holes")
	assert_eq(int(beats.get(&"practical_scorecard", 0)), 1)
	assert_eq(PracticalSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1])
	assert_true(bool(TrainingProgress.station("practical", "kit")["star"]))
	assert_true(TrainingProgress.has_card("practical", "kit_bag"))
	assert_eq(TrainingProgress.stars("masking"), 0, "the lessons keep their own saves")


## A guided card only takes the right answer; a wrong pick in the round costs a stroke, a hint another.
func test_wrong_picks_and_hints_cost_strokes() -> void:
	Game.cli = {"seed": 3}
	PracticalSchool.next_station = "kit"
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	var tries: Array[Dictionary] = []
	var cards: Array[Dictionary] = []
	var acb := func(beat: StringName, info: Dictionary, _solver: Callable) -> void:
		if beat == &"practical_try":
			tries.append(info)
		elif beat == &"practical_card":
			cards.append(info)
	Events.awaiting_input.connect(acb)
	add_node(school)
	await wait_frames(3)
	school.call("start")
	await wait_frames(3)
	var best := int(tries[0]["best"])
	school.call("pick", (best + 1) % 4)
	assert_eq(StringName(school.get("_state")), &"card", "a guided card ignores a wrong pick")
	school.call("pick", best)
	await wait_frames(2)
	school.call("press_next")
	await wait_frames(2)
	school.call("pick", int(tries[1]["best"]))
	await wait_frames(2)
	school.call("press_next")
	await wait_frames(3)
	Events.awaiting_input.disconnect(acb)
	assert_eq(cards.size(), 1, "the round's first hole")
	var b := int(cards[0]["best"])
	school.call("hint")
	school.call("pick", (b + 1) % (cards[0]["options"] as Array).size())
	school.call("pick", b)
	assert_eq(int(school.get("_hole_strokes")), 3, "par + a hint + a miss")
	school.queue_free()


# ================================================================ Station 2: Steady hands

## California's eight, every one taught by a look; the looks that go ahead are on nobody's list.
func test_refer_8_and_the_looks() -> void:
	assert_eq(PracticalDeck.REFER_8.size(), 8)
	var seen := {}
	for l: Dictionary in PracticalDeck.LOOKS:
		var f := int(l["flag"])
		assert_true(f >= 0 and f <= 8, "%s flag" % l["id"])
		seen[f] = true
		assert_true(String(l["why"]) != "" and String(l["note"]) != "")
		assert_true(["clear", "wax", "object"].has(String(l["view"])), "%s: a view ArcadeArt draws" % l["id"])
	for f in 9:
		assert_true(seen.has(f), "a look for flag %d" % f)
	assert_true(String(PracticalDeck.cheat_card("refer_8")["lines"][0]).contains("90"), "the card says 90 days")
	assert_eq(PracticalDeck.REFER_DAYS, 90)


## Every dealt round is honest: one safe grip among four, every other grip an unsafe pick; a judged grip
## is unsafe exactly when it isn't braced; the clean answer is the wash's right one; three different
## looks, at least one to go ahead and one to refer.
func test_hands_round_is_honest() -> void:
	for seed in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cards := PracticalDeck.hands_round(rng)
		assert_eq(cards.size(), PracticalDeck.ROUND_HOLES)
		var kinds: Array = cards.map(func(c: Dictionary) -> String: return String(c["kind"]))
		assert_eq(kinds, ["grip", "brace", "wash", "look", "look", "look"])
		var looks := {}
		var go := 0
		var refer := 0
		for c: Dictionary in cards:
			var ans := int(c["answer"])
			assert_true(ans >= 0 and ans < (c["options"] as Array).size(), "answer in range")
			assert_eq((c["lines"] as Array).size(), 2)
			assert_false((c.get("unsafe", []) as Array).has(ans), "the answer is never unsafe")
			match String(c["kind"]):
				"grip":
					var grips: Array = c["grips"]
					assert_eq(grips.count("safe"), 1)
					assert_eq(String(grips[ans]), "safe")
					assert_eq((c["unsafe"] as Array).size(), 3)
					assert_true(PracticalDeck.TOOLS.has(String(c["tool"])))
				"brace":
					var safe := String(c["grip"]) == "safe"
					assert_eq(ans, 0 if safe else 1)
					assert_eq(c["unsafe"], [] if safe else [0])
				"wash":
					assert_eq(String(c["options"][ans]), String(PracticalDeck.wash(String(c["wash"]))["right"]))
				"look":
					looks[String(c["look"])] = true
					var named := String(PracticalDeck.look(String(c["look"])).get("ear", ""))
					if named != "":
						assert_eq(String(c["ear"]), named, "the ear the note names")
					assert_eq(ans == 1, int(c["flag"]) > 0)
					if int(c["flag"]) > 0:
						refer += 1
						assert_true(String(c["lines"][1]).contains(PracticalDeck.REFER_8[int(c["flag"]) - 1]))
					else:
						go += 1
		assert_eq(looks.size(), 3, "three different looks")
		assert_true(go >= 1 and refer >= 1, "one to go ahead, one to refer")


## A sneeze jolts only for a moment, again and again, and never before it starts.
func test_sneeze_and_grips_draw() -> void:
	assert_eq(PracticalArt.sneeze(-1.0), 0.0)
	assert_true(PracticalArt.sneeze(PracticalArt.SNEEZE_S * 0.5) > 0.9)
	assert_eq(PracticalArt.sneeze(PracticalArt.SNEEZE_S + 0.1), 0.0)
	assert_true(PracticalArt.sneeze(PracticalArt.SNEEZE_EVERY + PracticalArt.SNEEZE_S * 0.5) > 0.9)
	assert_true(bool(PracticalDeck.GRIPS["safe"]["bridge"]) and bool(PracticalDeck.GRIPS["safe"]["braced"]))
	for g: String in PracticalDeck.UNSAFE_GRIPS:
		assert_false(bool(PracticalDeck.GRIPS[g]["braced"]), "%s is not braced" % g)
	# every card kind draws, before and after the answer, sneezing
	var c := Control.new()
	c.size = Vector2(880, 440)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cards := PracticalDeck.hands_round(rng) + PracticalDeck.hands_tries()
	var k := [0]
	c.draw.connect(func() -> void:
		var card: Dictionary = cards[k[0] % cards.size()]
		card["sneeze_at"] = 0.0
		PracticalArt.draw_card(c, c.size, card, k[0] % 2 == 0, [] if k[0] % 2 == 0 else [int(card["answer"]) ^ 1], 0.3))
	add_node(c)
	for i in cards.size() * 2:
		k[0] = i
		c.queue_redraw()
		await wait_frames(1)
	c.queue_free()


## The movie: valid, quiet, a Training movie on the title's list, never Gus's own; every scene draws.
func test_steady_hand_movie() -> void:
	var bad := Movies.validate("steady_hand", Stage2D.SETS)
	assert_true(bad.is_empty(), ", ".join(bad))
	assert_has(Movies.replay_ids(), "steady_hand", "on the title's movie list")
	assert_true(Movies.is_training("steady_hand"))
	assert_false(Movies.for_chapter("gus").has("steady_hand"), "never Day 1's own movie")
	assert_eq(Movies.day_label("steady_hand"), "Training")
	assert_eq(String(PracticalDeck.station("hands")["movie"]), "steady_hand")
	var total := Movies.total_s("steady_hand")
	assert_true(total >= 60.0 and total <= 90.0, "about a minute and a bit (%.0f s)" % total)
	var player_script: GDScript = load("res://story/explainers/explainer_player.gd")
	var cue_max := float(player_script.get_script_constant_map()["CUE_MAX_DB"])
	var m := Movies.movie("steady_hand")
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	st.call("use_movie", m)
	for sc: Dictionary in m["scenes"]:
		for cue: Dictionary in sc.get("cues", []):
			assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s: a known Sfx" % sc["id"])
			assert_true(float(cue.get("vol_db", 0.0)) <= cue_max, "%s: quiet" % sc["id"])
		st.call("show_scene", sc)
		var d := float(sc["duration"])
		for tt: float in [0.0, d * 0.3, d * 0.6, d]:
			st.set("t", tt)
			st.queue_redraw()
			await wait_frames(1)
	st.queue_free()


## Station 2 plays through by its solvers on a fresh save: the movie (skipped), three guided cards, six
## holes at par, both cards earned.
func test_hands_plays_by_solvers() -> void:
	Game.cli = {"seed": 11}
	PracticalSchool.next_station = "hands"
	PracticalSchool.last_result = {}
	var beats := {}
	var acb := func(beat: StringName, _info: Dictionary, solver: Callable) -> void:
		beats[beat] = int(beats.get(beat, 0)) + 1
		solver.call_deferred()
	Events.awaiting_input.connect(acb)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	add_node(school)
	for i in 900:
		if not went.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"], "back to the room")
	assert_eq(int(beats.get(&"explainer", 0)), 1, "Hoot's movie on a first visit")
	assert_eq(int(beats.get(&"practical_try", 0)), 3)
	assert_eq(int(beats.get(&"practical_card", 0)), 6)
	assert_eq(PracticalSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1])
	assert_true(bool(TrainingProgress.station("practical", "hands")["star"]))
	assert_true(TrainingProgress.has_card("practical", "safe_support"))
	assert_true(TrainingProgress.has_card("practical", "refer_8"), "the second card")
	assert_eq(PracticalDeck.card_station("refer_8"), 2)


## An unsafe pick is a STOP: two strokes, the sneeze plays; an over-careful one is a plain miss.
func test_unsafe_pick_is_a_stop() -> void:
	Game.cli = {"seed": 4}
	Game.mark_movie_seen("steady_hand")
	PracticalSchool.next_station = "hands"
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	var cards: Array[Dictionary] = []
	var acb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"practical_try" or beat == &"practical_next":
			solver.call_deferred()
		elif beat == &"practical_card":
			cards.append(info)
	Events.awaiting_input.connect(acb)
	add_node(school)
	await wait_frames(3)
	school.call("start")
	for i in 120:
		if not cards.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	assert_eq(String(cards[0]["kind"]), "grip")
	var b := int(cards[0]["best"])
	var bad := int((cards[0]["unsafe"] as Array)[0])
	school.call("pick", bad)
	assert_eq(int(school.get("_hole_strokes")), 1 + PracticalDeck.UNSAFE_STROKES, "par + the STOP")
	assert_true((school.get("_card") as Dictionary).has("sneeze_at"), "the sneeze plays")
	school.call("pick", b)
	assert_eq(int(school.get("_hole_strokes")), 3)
	school.queue_free()


# ================================================================ Station 4: Too loud?

## Every dealt round is honest: one chair shows the face; the first pitch is the highest tested; each
## ladder climbs from 70 in 5s and ends on the hand (TD) or at 110 with no hand (the arrow), its faces
## only ever getting worse.
func test_td_round_is_honest() -> void:
	var order := ["calm", "frown", "finger", "hand"]
	var arrows := 0
	for seed in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cards := PracticalDeck.td_round(rng)
		assert_eq(cards.size(), PracticalDeck.ROUND_HOLES)
		var kinds: Array = cards.map(func(c: Dictionary) -> String: return String(c["kind"]))
		assert_eq(kinds, ["seat", "order", "rule", "walk", "walk", "rule"])
		assert_ne(String(cards[2]["rule"]), String(cards[5]["rule"]), "two different rules")
		for c: Dictionary in cards:
			var ans := int(c["answer"])
			assert_true(ans >= 0 and ans < (c["options"] as Array).size(), "answer in range")
			assert_eq((c["lines"] as Array).size(), 2)
			match String(c["kind"]):
				"seat":
					assert_eq(String(c["seats"][ans]), "face")
				"order":
					var top := 0
					for f: Variant in c["tested"]:
						top = maxi(top, int(f))
					assert_eq(int(c["freqs"][ans]), top)
					var uniq := {}
					for f: Variant in c["freqs"]:
						uniq[int(f)] = true
					assert_eq(uniq.size(), 4, "four different pitches")
				"rule":
					assert_eq(String(c["options"][ans]), String(PracticalDeck.td_rule(String(c["rule"]))["right"]))
				"walk":
					var levels: Array = c["levels"]
					var answers: Array = c["answers"]
					var faces: Array = c["faces"]
					assert_eq(int(levels[0]), PracticalDeck.TD_START_DB)
					for i in levels.size():
						assert_eq(int(levels[i]), PracticalDeck.TD_START_DB + i * PracticalDeck.TD_STEP_DB, "up 5 a rung")
						assert_true(int(levels[i]) <= PracticalDeck.TD_LIMIT_DB)
						if i > 0:
							assert_true(order.find(faces[i]) >= order.find(faces[i - 1]), "faces only get worse")
						if i < levels.size() - 1:
							assert_eq(int(answers[i]), PracticalDeck.WALK_NEXT)
							assert_ne(String(faces[i]), "hand")
					assert_eq(ans, int(answers[0]))
					if int(c["td"]) > 0:
						assert_eq(int(answers[-1]), PracticalDeck.WALK_RECORD)
						assert_eq(String(faces[-1]), "hand")
						assert_eq(int(levels[-1]), int(c["td"]))
					else:
						arrows += 1
						assert_eq(int(answers[-1]), PracticalDeck.WALK_ARROW)
						assert_eq(int(levels[-1]), PracticalDeck.TD_LIMIT_DB)
						assert_ne(String(faces[-1]), "hand")
	assert_true(arrows > 5, "some subjects reach the limit with no hand (%d)" % arrows)


func test_td_cards_draw() -> void:
	var c := Control.new()
	c.size = Vector2(880, 440)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var cards := PracticalDeck.td_round(rng) + PracticalDeck.td_tries()
	var k := [0]
	c.draw.connect(func() -> void:
		var card: Dictionary = cards[(k[0] / 2) % cards.size()]
		if card.has("levels"):
			card["step"] = (card["levels"] as Array).size() - 1 if k[0] % 2 == 0 else 0
		PracticalArt.draw_card(c, c.size, card, k[0] % 2 == 0, [] if k[0] % 2 == 0 else [1], 0.4))
	add_node(c)
	for i in cards.size() * 2:
		k[0] = i
		c.queue_redraw()
		await wait_frames(1)
	c.queue_free()


## Station 4 plays through by its solvers: two guided cards (the ladder one rung at a time), six holes at
## par, the TD Steps card.
func test_td_plays_by_solvers() -> void:
	Game.cli = {"seed": 9}
	PracticalSchool.next_station = "td"
	PracticalSchool.last_result = {}
	var firsts := {}
	var rungs := [0]
	var acb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if int(info.get("sub", 0)) == 0:
			firsts[beat] = int(firsts.get(beat, 0)) + 1
		elif beat == &"practical_card":
			rungs[0] += 1
		solver.call_deferred()
	Events.awaiting_input.connect(acb)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	add_node(school)
	for i in 1200:
		if not went.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"], "back to the room")
	assert_eq(int(firsts.get(&"practical_try", 0)), 2)
	assert_eq(int(firsts.get(&"practical_card", 0)), 6)
	assert_true(rungs[0] >= 6, "the ladders ask once per rung (%d more)" % rungs[0])
	assert_eq(PracticalSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1])
	assert_true(TrainingProgress.has_card("practical", "td_steps"))


## On the ladder: a jump of 10 costs a stroke and stays on the rung; the right call climbs a rung and
## clears the miss; one hint a hole.
func test_ladder_rungs_and_strokes() -> void:
	Game.cli = {"seed": 9}
	PracticalSchool.next_station = "td"
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	var walk := []
	var acb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if beat == &"practical_card" and String(info.get("kind", "")) == "walk":
			if walk.is_empty():
				walk.append(info)
			return
		if beat != &"practical_intro":
			solver.call_deferred()
	Events.awaiting_input.connect(acb)
	add_node(school)
	await wait_frames(3)
	school.call("start")
	for i in 600:
		if not walk.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	assert_false(walk.is_empty(), "reached a ladder")
	assert_eq(int(walk[0]["best"]), PracticalDeck.WALK_NEXT, "70 dB: never the TD")
	school.call("pick", PracticalDeck.WALK_JUMP)
	assert_eq(int(school.get("_hole_strokes")), 2, "a jump of 10 is a miss")
	assert_eq(int((school.get("_card") as Dictionary)["step"]), 0, "still on 70")
	school.call("pick", PracticalDeck.WALK_NEXT)
	assert_eq(int((school.get("_card") as Dictionary)["step"]), 1, "up a rung")
	assert_true((school.get("_wrong") as Array).is_empty(), "the miss is cleared for the new rung")
	school.call("hint")
	school.call("hint")
	assert_eq(int(school.get("_hole_strokes")), 3, "one hint a hole")
	school.queue_free()


# ---------------------------------------------------------------- Station 3: Station A, the tones

## Each practice subject answers by the rules: the AudiOtron's own textbook search finds their true air on
## both ears and the better cochlea's bone, and the masking rules ask for exactly what the subject says.
func test_tone_subjects_answer_by_the_rules() -> void:
	for sd: Dictionary in PracticalDeck.TONE_SUBJECTS:
		var p := PracticalDeck.tone_patient(sd)
		var better := String(sd["better"])
		var worse := PracticalDeck.other_ear(better)
		var s := AudiometrySession.new(p, 7)
		s.scoring = false
		s.configure({"test": "ac", "air_transducer": "phones"})
		for e: String in [better, worse]:
			var guard := 0
			while not s.is_ear_complete(e) and guard < 30:
				guard += 1
				assert_false(s.instant_measure(e, s.required_remaining(e)[0]).is_empty(), "%s %s measured" % [p.id, e])
			var ac := s.stored_thresholds(e, &"ac")
			var truth: Dictionary = sd["ac_" + e]
			for f: int in ac:
				assert_eq(int(ac[f]), int(truth[f]), "%s %s air %d by the rules" % [p.id, e, f])
		var avg := func(e: String) -> float:
			var t: Dictionary = sd["ac_" + e]
			return float(int(t[500]) + int(t[1000]) + int(t[2000])) / 3.0
		assert_true(float(avg.call(better)) < float(avg.call(worse)), "%s: the better ear is %s" % [p.id, better])
		s.configure({"test": "bc", "bc_freqs": ClinicRules.BC_REQUIRED})
		s.set_transducer(&"bone")
		while not s.is_ear_complete(better) and s.required_remaining(better).size() > 0:
			assert_false(s.instant_measure(better, s.required_remaining(better)[0]).is_empty())
		var res := s.results_view()
		var bone := ClinicRules.masked_freqs_needed(res, worse, &"bc_masked")
		var air := ClinicRules.masked_freqs_needed(res, worse, &"ac_masked")
		var m := String(sd["mask"])
		assert_eq(not bone.is_empty(), m in ["bone", "both"], "%s masked bone: %s" % [p.id, bone])
		assert_eq(not air.is_empty(), m in ["air", "both"], "%s masked air: %s" % [p.id, air])
		assert_true(ClinicRules.masked_freqs_needed(res, better, &"bc_masked").is_empty(), "%s: nothing to mask on the better ear" % p.id)
		assert_true(ClinicRules.masked_freqs_needed(res, better, &"ac_masked").is_empty())
		assert_eq(p.psychometric_slope_db, 0.5)
		assert_eq(p.false_alarms_per_minute, 0.0)


func test_tone_round_is_honest() -> void:
	var seen := {}
	for seed in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cards := PracticalDeck.tone_round(rng)
		var kinds: Array = cards.map(func(c: Dictionary) -> String: return String(c["kind"]))
		assert_eq(kinds.slice(0, 7), ["phones", "first", "booth", "booth", "bone", "booth", "mask"])
		assert_eq(String(kinds[-1]), "symbol")
		var sd := PracticalDeck.tone_subject(String(cards[1]["subject"]))
		seen[String(sd["id"])] = true
		var better := String(sd["better"])
		var tests: Array = []
		for c: Dictionary in cards:
			assert_eq((c["lines"] as Array).size(), 2)
			if String(c["kind"]) == "booth":
				tests.append("%s:%s" % [c["test"], c["ear"]])
				assert_eq(String(c["subject"]), String(sd["id"]))
				assert_eq(int(c["stamps"]), int(PracticalDeck.TONE_STAMPS[String(c["test"])]))
				continue
			var ans := int(c["answer"])
			var opts: Array = c["options"]
			assert_true(ans >= 0 and ans < opts.size() and opts.size() <= 4, "answer in range")
			var uniq := {}
			for o: Variant in opts:
				uniq[String(o)] = true
			assert_eq(uniq.size(), opts.size(), "no repeated options")
			match String(c["kind"]):
				"phones":
					assert_eq(String(opts[ans]), "Red cup" if String(c["ear"]) == "right" else "Blue cup")
				"first":
					assert_eq(String(opts[ans]), "%s ear" % better.capitalize())
				"mask":
					assert_eq(ans, int(PracticalDeck.MASK_ANSWER[String(sd["mask"])]))
				"symbol":
					var want: Array = c["want"]
					assert_ne(String(want[1]), "ac", "a bone or masked symbol")
					assert_eq(String(opts[ans]), String(PracticalDeck.SYMBOL_WORDS["%s:%s" % [want[0], want[1]]]))
					assert_true((c["symbols"] as Array).has([PracticalDeck.other_ear(String(want[0])), want[1]]), "the other ear's twin is a decoy")
		var worse := PracticalDeck.other_ear(better)
		var want_tests := ["ac:" + better, "ac:" + worse, "bc:" + better]
		if String(sd["mask"]) in ["bone", "both"]:
			want_tests.append("bc_masked:" + worse)
		if String(sd["mask"]) in ["air", "both"]:
			want_tests.append("ac_masked:" + worse)
		assert_eq(tests, want_tests, "%s's booth holes" % sd["id"])
	assert_eq(seen.size(), PracticalDeck.TONE_SUBJECTS.size(), "every subject comes up")


func test_tone_cards_draw() -> void:
	var c := Control.new()
	c.size = Vector2(880, 440)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var cards := PracticalDeck.tone_round(rng, "pt_may") + PracticalDeck.tone_tries()
	var marks := [["right", "ac", 1000, 10, false], ["left", "ac", 1000, 50, false], ["right", "bc", 1000, 10, false],
		["left", "bc_masked", 1000, 50, false], ["left", "ac_masked", 8000, 100, true]]
	for card: Dictionary in cards:
		if String(card["kind"]) in ["booth", "mask"]:
			card["chart"] = marks
	var k := [0]
	c.draw.connect(func() -> void:
		var card: Dictionary = cards[(k[0] / 2) % cards.size()]
		PracticalArt.draw_card(c, c.size, card, k[0] % 2 == 0, [] if k[0] % 2 == 0 else [1], 0.4))
	add_node(c)
	for i in cards.size() * 2:
		k[0] = i
		c.queue_redraw()
		await wait_frames(1)
	c.queue_free()


## Station 3 plays through by its solvers with Aunt May (both masked sheets): two guided cards, the pick
## holes and five booth holes on the real AudiOtron at par, Hoot's montage finishing each ear, the
## Station A Order card.
func test_tones_plays_by_solvers() -> void:
	Game.cli = {"seed": 3, "subject": "pt_may"}
	PracticalSchool.next_station = "tones"
	PracticalSchool.last_result = {}
	var firsts := {}
	var booths: Array = []
	var acb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		firsts[beat] = int(firsts.get(beat, 0)) + 1
		if beat == &"practical_booth":
			booths.append("%s:%s" % [info["test"], info["ear"]])
		solver.call_deferred()
	Events.awaiting_input.connect(acb)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	var scale := Engine.time_scale
	Engine.time_scale = 4.0
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	add_node(school)
	var t0 := Time.get_ticks_msec()
	while went.is_empty() and Time.get_ticks_msec() - t0 < 120000:
		await wait_frames(1)
	Engine.time_scale = scale
	Events.awaiting_input.disconnect(acb)
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"], "back to the room")
	assert_eq(int(firsts.get(&"practical_try", 0)), 2)
	assert_eq(int(firsts.get(&"practical_card", 0)), 5, "phones, first ear, bone, mask, symbol")
	assert_eq(booths, ["ac:right", "ac:left", "bc:right", "bc_masked:left", "ac_masked:left"])
	assert_eq(PracticalSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	assert_true(TrainingProgress.has_card("practical", "station_a"))
	assert_eq(school.get("_screen"), null, "the AudiOtron left with the round")
	assert_eq(school.find_children("*", "AudiometerScreen", true, false).size(), 0)


# ---------------------------------------------------------------- Station 5: One good impression

func test_impression_round_is_honest() -> void:
	var faults := {}
	for seed in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var cards := PracticalDeck.impression_round(rng)
		assert_eq(cards.size(), PracticalDeck.ROUND_HOLES)
		assert_eq(String(cards[0]["kind"]), "steps")
		assert_true(String(cards[1]["kind"]) in ["dam", "depth"])
		assert_true(String(cards[2]["kind"]) in ["tip", "fill"])
		assert_true(String(cards[3]["kind"]) in ["cure", "out"])
		assert_eq(String(cards[4]["kind"]), "judge")
		assert_eq(String(cards[5]["kind"]), "judge")
		assert_ne(String(cards[4]["fault"]), String(cards[5]["fault"]), "two different impressions")
		assert_false(String(cards[4]["fault"]) == "ok" and String(cards[5]["fault"]) == "ok")
		for c: Dictionary in cards:
			var opts: Array = c["options"]
			var ans := int(c["answer"])
			assert_true(ans >= 0 and ans < opts.size() and opts.size() <= 4)
			assert_eq((c["lines"] as Array).size(), 2)
			for u: Variant in c.get("unsafe", []):
				assert_ne(int(u), ans, "the right answer is never a STOP")
			match String(c["kind"]):
				"steps":
					var from := int(c["from"])
					var ro: Array = c["rung_options"]
					assert_eq(ro.size(), PracticalDeck.STEP_RUNGS)
					for r in ro.size():
						var words: Array = ro[r]
						assert_eq(words.size(), 4)
						assert_eq(String(words[int(c["answers"][r])]), PracticalDeck.IMP_STEPS[from + r], "the next step")
						for w: Variant in words:
							var i := PracticalDeck.IMP_STEPS.find(String(w))
							assert_true(i == from + r or i > from + r or i < from, "no step already done in this ladder")
				"dam":
					assert_eq(PracticalDeck.SIZES[ans], String(c["canal"]))
					assert_eq(c["unsafe"], [PracticalDeck.DAM_NONE])
				"depth":
					assert_eq(String(c["depths"][ans]), "second")
					assert_eq(String(c["depths"][int(c["unsafe"][0])]), "eardrum")
				"tip":
					assert_eq(String(c["tips"][ans]), "ready")
				"fill":
					assert_eq(String(opts[ans]), PracticalDeck.FILL_RIGHT)
				"cure":
					assert_eq(ans, 0 if bool(c["dent"]) else 1)
				"out":
					assert_eq(String(opts[ans]), PracticalDeck.AFTER_RIGHT if bool(c["after"]) else PracticalDeck.OUT_RIGHT)
				"judge":
					faults[String(c["fault"])] = true
					assert_eq(String(c["faults"][ans]), String(c["fault"]))
					assert_eq(String(opts[ans]), String(PracticalDeck.FAULTS_IMP[String(c["fault"])]["name"]))
	assert_eq(faults.size(), PracticalDeck.FAULTS_IMP.size(), "every fault and OK come up")


func test_impression_cards_draw() -> void:
	var c := Control.new()
	c.size = Vector2(880, 440)
	var cards: Array[Dictionary] = PracticalDeck.impression_tries()
	for seed in 6:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		cards.append_array(PracticalDeck.impression_round(rng))
	for f: String in PracticalDeck.FAULTS_IMP:
		cards.append(PracticalDeck.judge_card(f, ["ok", "void", "short", "fold"] if f in ["ok", "void", "short", "fold"] else [f, "ok", "void", "short"]))
	var k := [0]
	c.draw.connect(func() -> void:
		var card: Dictionary = cards[(k[0] / 2) % cards.size()]
		PracticalArt.draw_card(c, c.size, card, k[0] % 2 == 0, [] if k[0] % 2 == 0 else [1], 0.4))
	add_node(c)
	for i in cards.size() * 2:
		k[0] = i
		c.queue_redraw()
		await wait_frames(1)
	c.queue_free()


## Station 5 plays through by its solvers: two guided cards, six holes at par (the steps ladder asks once per
## rung with that rung's own four), the Impression Steps card.
func test_impression_plays_by_solvers() -> void:
	Game.cli = {"seed": 4}
	PracticalSchool.next_station = "impression"
	PracticalSchool.last_result = {}
	var firsts := {}
	var rung_opts: Array = []
	var acb := func(beat: StringName, info: Dictionary, solver: Callable) -> void:
		if int(info.get("sub", 0)) == 0:
			firsts[beat] = int(firsts.get(beat, 0)) + 1
		if beat == &"practical_card" and String(info.get("kind", "")) == "steps":
			rung_opts.append((info["options"] as Array)[int(info["best"])])
		solver.call_deferred()
	Events.awaiting_input.connect(acb)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	var school: Control = (load("res://story/training/practical/practical_school.tscn") as PackedScene).instantiate()
	add_node(school)
	for i in 1200:
		if not went.is_empty():
			break
		await wait_frames(1)
	Events.awaiting_input.disconnect(acb)
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/training/training_room.tscn"], "back to the room")
	assert_eq(int(firsts.get(&"practical_try", 0)), 2)
	assert_eq(int(firsts.get(&"practical_card", 0)), 6)
	assert_eq(rung_opts.size(), PracticalDeck.STEP_RUNGS, "one beat per rung")
	var i0 := PracticalDeck.IMP_STEPS.find(String(rung_opts[0]))
	for r in rung_opts.size():
		assert_eq(String(rung_opts[r]), PracticalDeck.IMP_STEPS[i0 + r], "each rung's best is the next step")
	assert_eq(PracticalSchool.last_result.get("strokes"), [1, 1, 1, 1, 1, 1])
	assert_true(TrainingProgress.has_card("practical", "impression"))
