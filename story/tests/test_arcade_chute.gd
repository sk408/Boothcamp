extends TestCase
## Chart Chute (docs/ARCADE.md): every chart on the belt really has the shape its chute says, by the
## same rule the story uses (ClinicRules.classify_shape), and keeps it with any one point 5 dB off;
## the ramp, the points and the high-score table behave; and reading beats guessing.

const ChartDeck := preload("res://story/arcade/chart_deck.gd")
const ChuteRules := preload("res://story/arcade/chute_rules.gd")
const ArcadeScores := preload("res://story/arcade/arcade_scores.gd")
const SEEDS := 60

var _saved_progress: Dictionary = {}


func before_each() -> void:
	_saved_progress = Game.progress.duplicate(true)
	Game.progress["arcade"] = {}


func after_each() -> void:
	Game.progress = _saved_progress


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func test_every_chart_has_its_shape_with_a_margin() -> void:
	for shape: StringName in ChartDeck.SHAPES:
		for lookalike: bool in [false, true]:
			for s in SEEDS:
				var t := ChartDeck.make_chart(_rng(s * 7 + 1), shape, lookalike)
				assert_false(t.is_empty(), "%s chart made (seed %d)" % [shape, s])
				assert_eq(ClinicRules.classify_shape(t), shape, "%s classifies as itself (seed %d, lookalike %s)" % [shape, s, lookalike])
				assert_true(ChartDeck.stable(t, shape), "%s keeps its shape 5 dB either way (seed %d)" % [shape, s])


func test_every_card_sorts_by_the_ear_it_names() -> void:
	for ear: String in ["right", "left", "both"]:
		for shape: StringName in ChartDeck.SHAPES:
			for s in 20:
				var c := ChartDeck.make_card(_rng(s + 100), shape, {"ear": ear, "lookalike": s % 2 == 1}, s)
				var sort_ear := String(c["sort_ear"])
				assert_true(sort_ear in ["right", "left"], "a real ear to sort")
				if ear != "both":
					assert_eq(sort_ear, ear, "a one-ear card sorts that ear")
					assert_eq((c["ac"] as Dictionary).size(), 1, "a one-ear card shows one ear")
				else:
					var other := "left" if sort_ear == "right" else "right"
					assert_ne(ClinicRules.classify_shape(c["ac"][other]), shape, "the other ear on a two-ear card is a different shape")
				assert_eq(ClinicRules.classify_shape(c["ac"][sort_ear]), shape, "the named ear has the chute's shape")
				assert_true(String(c["name"]).contains(" "), "a first and last name")
				assert_false(String(c["line"]).is_empty(), "a line for the right chute")


func test_notches_bottom_out_deep_enough_to_see() -> void:
	for s in SEEDS:
		var t := ChartDeck.make_chart(_rng(s + 900), &"notch", s % 2 == 0)
		var floor_db := maxi(int(t[3000]), maxi(int(t[4000]), int(t[6000])))
		assert_true(floor_db >= ChartDeck.NOTCH_FLOOR_MIN, "notch floor %d dB HL" % floor_db)
		assert_true(int(t[8000]) < floor_db, "8k comes back up")


func test_charts_are_clearly_not_normal_and_on_the_grid() -> void:
	for shape: StringName in ChartDeck.SHAPES:
		for s in SEEDS:
			var t := ChartDeck.make_chart(_rng(s + 400), shape, false)
			var worst := 0
			for f: int in t:
				assert_eq(int(t[f]) % 5, 0, "5 dB steps")
				assert_eq(int(t[f]), ClinicRules.clamp_db(int(t[f]), f), "inside the audiometer's range")
				worst = maxi(worst, int(t[f]))
			assert_true(worst > 35, "%s: the worst point is past mild (%d)" % [shape, worst])
			for f: int in ClinicRules.required_interoctaves(t):
				assert_true(t.has(f), "%s: the inter-octave %d is plotted" % [shape, f])


func test_the_same_seed_gives_the_same_belt() -> void:
	var a := ChartDeck.make_card(_rng(5), &"cookie_bite", {"ear": "both"}, 1)
	var b := ChartDeck.make_card(_rng(5), &"cookie_bite", {"ear": "both"}, 1)
	assert_eq(a, b, "seeded")


func test_story_charts_have_the_shape_their_chute_claims() -> void:
	for shape: StringName in ChartDeck.SHAPES:
		var c := ChartDeck.golden_card(shape, 1)
		assert_false(c.is_empty(), "%s: the story patient's file loads" % shape)
		assert_true(bool(c["golden"]), "golden")
		var g: Dictionary = ChartDeck.GOLDEN[shape]
		var sort_ear := String(c["sort_ear"])
		assert_eq(ClinicRules.classify_shape(c["ac"][sort_ear]), shape, "%s's %s ear really is %s" % [g["who"], sort_ear, shape])
		assert_true(ChartDeck.stable(c["ac"][sort_ear], shape), "%s's chart keeps its shape 5 dB either way" % g["who"])


func test_marina_shows_only_her_left_ear() -> void:
	var c := ChartDeck.golden_card(&"rising", 1)
	assert_eq(String(c["ear"]), "left", "Marina's card is her left ear")
	assert_eq((c["ac"] as Dictionary).keys(), ["left"], "only the left ear is drawn")


func test_warmup_opens_two_chutes_and_the_run_opens_the_rest_on_time() -> void:
	assert_eq(ChuteRules.unlocked(-1.0), [&"sloping", &"notch"], "warm-up: slope and notch")
	assert_eq(ChuteRules.unlocked(0.0), [&"sloping", &"notch"], "start of the run")
	assert_eq(ChuteRules.unlocked(9.9).size(), 2, "cookie bite opens at 10 s")
	assert_has(ChuteRules.unlocked(10.0), &"cookie_bite", "cookie bite at 10 s")
	assert_false(ChuteRules.unlocked(24.9).has(&"rising"), "rising waits for 25 s")
	assert_eq(ChuteRules.unlocked(25.0).size(), 4, "all four at 25 s")


func test_the_ramp() -> void:
	var r := _rng(3)
	for i in 200:
		var early := ChuteRules.next_spec(r, 5.0, [], [])
		assert_eq(String(early["ear"]), "right", "right ear only early on")
		assert_false(bool(early["lookalike"]), "no lookalikes early on")
		assert_true(ChuteRules.unlocked(5.0).has(early["shape"]), "only open chutes")
	var saw := {"left": false, "both": false, "lookalike": false}
	for i in 300:
		var late := ChuteRules.next_spec(r, 45.0, [], [])
		if String(late["ear"]) == "left":
			saw["left"] = true
		if String(late["ear"]) == "both":
			saw["both"] = true
		if bool(late["lookalike"]):
			saw["lookalike"] = true
	assert_true(saw["left"] and saw["both"] and saw["lookalike"], "the late run mixes in left, two-ear and lookalike cards")
	var g := ChuteRules.next_spec(r, 51.0, [], [&"notch"])
	assert_true(bool(g["golden"]) and g["shape"] == &"notch", "a story chart after 50 s")
	assert_false(bool(ChuteRules.next_spec(r, 49.0, [], [&"notch"])["golden"]), "not before")


func test_a_new_chute_gets_the_next_card() -> void:
	var s := ChuteRules.next_spec(_rng(1), 10.5, [&"notch", &"sloping"], [])
	assert_eq(s["shape"], &"cookie_bite", "cookie bite straight after it opens")
	s = ChuteRules.next_spec(_rng(1), 25.2, [&"notch"], [])
	assert_eq(s["shape"], &"rising", "rising straight after it opens")


func test_never_three_of_a_shape_running() -> void:
	var r := _rng(9)
	var recent: Array = []
	for i in 400:
		var s := ChuteRules.next_spec(r, 30.0 + float(i % 20), recent, [])
		if recent.size() >= 2:
			assert_false(recent[-1] == recent[-2] and recent[-1] == s["shape"], "no three in a row")
		recent.append(s["shape"])
		if recent.size() > 4:
			recent.pop_front()


func test_points_and_streaks() -> void:
	assert_eq(ChuteRules.points(1, false), 100, "plain")
	assert_eq(ChuteRules.points(3, false), 200, "x2 at a streak of 3")
	assert_eq(ChuteRules.points(6, false), 300, "x3 at 6")
	assert_eq(ChuteRules.points(10, false), 500, "x5 at 10")
	assert_eq(ChuteRules.points(1, true), 300, "a story chart is x3")
	assert_eq(ChuteRules.points(10, true), 1500, "and stacks with the streak")


func test_fluent_rank_and_board() -> void:
	assert_true(ChuteRules.fluent(25, 1), "25 right, 1 slip")
	assert_false(ChuteRules.fluent(25, 2), "two slips is not fluent")
	assert_false(ChuteRules.fluent(24, 0), "24 is not quite")
	assert_eq(ChuteRules.rank(26, 0), "Chart Whisperer", "fluent")
	assert_eq(ChuteRules.rank(16, 1), "Sharp Eye", "accurate and quick")
	assert_eq(ChuteRules.rank(8, 2), "Steady Sorter", "80%")
	assert_eq(ChuteRules.rank(5, 5), "Jam Master", "guessing")
	assert_eq(ChuteRules.rank(0, 0), "Belt Watcher", "nothing sorted")
	assert_true(ChuteRules.on_board(9, 1), "90% makes the board")
	assert_false(ChuteRules.on_board(8, 2), "80% does not")
	assert_false(ChuteRules.on_board(0, 0), "an empty run does not")


## A guessing player against a reading one over the run's card mix: guessing never pays.
func test_guessing_scores_far_below_reading() -> void:
	var r := _rng(11)
	var read_pts := 0
	var guess_pts := 0
	var guess_right := 0
	var guess_oops := 0
	var streak_g := 0
	var t := 0.0
	var i := 0
	while t < ChuteRules.RUN_S:
		var spec := ChuteRules.next_spec(r, t, [], [])
		read_pts += ChuteRules.points(i + 1, false)
		var open := ChuteRules.unlocked(t)
		if open[r.randi() % open.size()] == spec["shape"]:
			streak_g += 1
			guess_right += 1
			guess_pts += ChuteRules.points(streak_g, false)
		else:
			streak_g = 0
			guess_oops += 1
			t += ChuteRules.JAM_S
		t += 1.2
		i += 1
	assert_true(guess_pts * 3 < read_pts, "guessing %d vs reading %d" % [guess_pts, read_pts])
	assert_false(ChuteRules.on_board(guess_right, guess_oops), "a guessing run is off the board")


func test_scores_table_starts_with_the_cast_and_takes_a_new_best() -> void:
	var t := ArcadeScores.table("chart_chute")
	assert_eq(t.size(), 3, "three seed rows")
	assert_eq(String(t[0]["initials"]), "HOO", "Hoot on top")
	assert_true(ArcadeScores.qualifies("chart_chute", 100), "a short table takes anything above zero")
	assert_false(ArcadeScores.qualifies("chart_chute", 0), "but not zero")
	var place := ArcadeScores.add_score("chart_chute", "abc", 7000, 0.96)
	assert_eq(place, 0, "a new top score")
	t = ArcadeScores.table("chart_chute")
	assert_eq(String(t[0]["initials"]), "ABC", "capitalised")
	assert_eq(t.size(), 4, "the cast stays on the board")
	assert_eq(ArcadeScores.last_initials("chart_chute"), "ABC", "remembered for next time")


func test_scores_table_keeps_ten_and_reads_floats() -> void:
	for i in 14:
		ArcadeScores.add_score("chart_chute", "AAA", 1000 + i * 100, 1.0)
	var t := ArcadeScores.table("chart_chute")
	assert_eq(t.size(), ArcadeScores.TABLE_SIZE, "ten rows")
	assert_false(ArcadeScores.qualifies("chart_chute", 1000), "a low score no longer qualifies")
	# a save read back from JSON: numbers are floats
	Game.progress["arcade"]["chart_chute"]["table"] = [{"initials": "ZZ", "score": 9000.0, "accuracy": 1.0}, "junk", {"score": "x"}]
	t = ArcadeScores.table("chart_chute")
	assert_eq(int(t[0]["score"]), 9000, "float scores read as ints")
	assert_eq(String(t[0]["initials"]), "ZZA", "short initials padded")
	assert_eq(t.size(), 2, "junk rows skipped, bad numbers read as 0")


func test_clean_initials() -> void:
	assert_eq(ArcadeScores.clean_initials("k9!"), "KAA", "letters only")
	assert_eq(ArcadeScores.clean_initials(""), "AAA", "padded")
	assert_eq(ArcadeScores.clean_initials("abcdef"), "ABC", "three letters")


func test_runs_and_found_survive_a_bad_save() -> void:
	Game.progress["arcade"] = {"chart_chute": {"runs": "nope", "found": 3, "table": {}}}
	assert_eq(ArcadeScores.runs("chart_chute"), [], "runs reset")
	ArcadeScores.add_run("chart_chute", {"right": 20.0, "oops": 1.0, "score": 4000.0})
	assert_eq(int(ArcadeScores.runs("chart_chute")[0]["right"]), 20, "a run stored and read")
	ArcadeScores.mark_found("chart_chute", "notch")
	ArcadeScores.mark_found("chart_chute", "notch")
	assert_eq(ArcadeScores.found("chart_chute"), PackedStringArray(["notch"]), "found once")
	for i in 20:
		ArcadeScores.add_run("chart_chute", {"right": i, "oops": 0, "score": 0})
	assert_eq(ArcadeScores.runs("chart_chute").size(), ArcadeScores.RUNS_KEPT, "the last twelve runs")


func test_arcade_save_key_is_in_the_defaults() -> void:
	assert_true(Game.DEFAULT_PROGRESS.has("arcade"), "Game.DEFAULT_PROGRESS has an arcade key, or high scores never load")
