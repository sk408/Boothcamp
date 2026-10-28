extends TestCase
## The Practical, the Training room's second lesson (docs/training/PRACTICAL_EXAM.md): the deck is
## complete, every dealt "Pack the bag" card is honest, the room's lesson tabs switch the board, and
## Station 1 plays through by its beats' solvers.

const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const PracticalSchool := preload("res://story/training/practical/practical_school.gd")
const TrainingProgress := preload("res://story/training/training_progress.gd")
const TrainingRoom := preload("res://story/training/training_room.gd")


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
		assert_true((c["lines"] as Array).size() >= 3)
	assert_true(bool(PracticalDeck.station("kit")["built"]))
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
	assert_eq(PracticalDeck.deal("hands", RandomNumberGenerator.new()), [], "unbuilt stations deal nothing")


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
	assert_eq(beats[1]["built"], ["kit"])
	assert_eq((room.get("_chips") as Array).size(), 8)
	assert_true(room.find_child("card_kit_bag", true, false) != null, "the practical's pins")
	assert_true(room.find_child("card_skull_wall", true, false) == null, "masking's pins are gone")
	assert_false(bool(room.call("can_print")), "no print view on The Practical")
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	room.call("open_station", 3)   # SOON
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
