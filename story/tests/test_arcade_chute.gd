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
				assert_eq(ChartDeck.shape_of(t), shape, "%s classifies as itself (seed %d, lookalike %s)" % [shape, s, lookalike])
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
					assert_ne(ChartDeck.shape_of(c["ac"][other]), shape, "the other ear on a two-ear card is a different shape")
				assert_eq(ChartDeck.shape_of(c["ac"][sort_ear]), shape, "the named ear has the chute's shape")
				assert_true(String(c["name"]).contains(" "), "a first and last name")
				assert_false(String(c["line"]).is_empty(), "a line for the right chute")


## A slope that comes back up 10 dB at 6k reads as a 4k notch to a clinician (the noise-notch rule
## looks at 6k or 8k), so the belt never deals one, lookalikes included.
func test_slopes_never_recover_at_6k() -> void:
	for lookalike: bool in [false, true]:
		for s in SEEDS:
			var t := ChartDeck.make_chart(_rng(s * 3 + 50), &"sloping", lookalike)
			assert_true(maxi(int(t[3000]), int(t[4000])) - int(t[6000]) < 10, "slope seed %d: no 6k recovery (%s)" % [s, str(t)])
	var bounce := {250: 15, 500: 20, 1000: 25, 2000: 40, 3000: 50, 4000: 65, 6000: 55, 8000: 70}
	if ClinicRules.classify_shape(bounce) == &"sloping":
		assert_false(ChartDeck.stable(bounce, &"sloping"), "a 10 dB bounce at 6k is not a clean slope")


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
	for shape: StringName in ChartDeck.GOLDEN:
		var c := ChartDeck.golden_card(shape, 1)
		assert_false(c.is_empty(), "%s: the story patient's file loads" % shape)
		assert_true(bool(c["golden"]), "golden")
		var g: Dictionary = ChartDeck.GOLDEN[shape]
		var sort_ear := String(c["sort_ear"])
		assert_eq(ChartDeck.shape_of(c["ac"][sort_ear]), shape, "%s's %s ear really is %s" % [g["who"], sort_ear, shape])
		assert_true(ChartDeck.stable(c["ac"][sort_ear], shape), "%s's chart keeps its shape 5 dB either way" % g["who"])


## A story chart shows a Day's pattern (and for Marina, a clue to her call), so it only rides the
## belt once that Day is finished; unfound ones come first, then all of them come round again.
func test_story_charts_wait_for_their_day() -> void:
	Game.progress["chapters_done"] = []
	assert_eq(ChartDeck.golden_pool(PackedStringArray()), [], "no Days done: no story charts")
	Game.progress["chapters_done"] = ["gus", "bonnie"]
	assert_eq(ChartDeck.golden_pool(PackedStringArray()), [&"sloping"], "Day 1 done: only Gus")
	assert_eq(ChartDeck.golden_pool(PackedStringArray(["sloping"])), [&"sloping"], "found, and the only one open: it comes round again")
	Game.progress["chapters_done"] = ["gus", "rocco", "marina", "ginger"]
	assert_eq(ChartDeck.golden_pool(PackedStringArray(["sloping", "notch"])), [&"cookie_bite", &"rising"], "the unfound ones first")
	assert_eq(ChartDeck.golden_pool(PackedStringArray(["sloping", "notch", "cookie_bite", "rising"])).size(), 4, "all found: all again")


## classify_shape has no reverse bite (it calls one flat); the belt's label adds it on top and
## leaves every other shape where classify_shape put it.
func test_reverse_bite_is_worse_at_both_ends() -> void:
	var rb := {250: 50, 500: 40, 1000: 25, 2000: 25, 3000: 30, 4000: 40, 6000: 50, 8000: 55}
	assert_eq(ClinicRules.classify_shape(rb), &"flat", "the clinic rule calls it flat")
	assert_eq(ChartDeck.shape_of(rb), &"reverse_bite", "the belt calls it a reverse bite")
	var low_only := {250: 50, 500: 40, 1000: 25, 2000: 25, 3000: 30, 4000: 30, 6000: 30, 8000: 30}
	assert_ne(ChartDeck.shape_of(low_only), &"reverse_bite", "worse at one end only is not a reverse bite")
	for shape: StringName in ChartDeck.SHAPES:
		if shape == &"reverse_bite":
			continue
		for s in SEEDS:
			var t := ChartDeck.make_chart(_rng(s + 1300), shape, s % 2 == 1)
			assert_eq(ChartDeck.shape_of(t), ClinicRules.classify_shape(t), "%s: the belt agrees with the clinic rule" % shape)
	assert_false(ChartDeck.GOLDEN.has(&"reverse_bite"), "no story patient has a reverse bite: no story chart")


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
	assert_eq(ChuteRules.unlocked(25.0).size(), 4, "four at 25 s")
	assert_false(ChuteRules.unlocked(34.9).has(&"reverse_bite"), "reverse bite waits for 35 s")
	assert_eq(ChuteRules.unlocked(35.0).size(), 5, "all five at 35 s")


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


func test_a_story_chart_never_makes_three_in_a_row() -> void:
	var s := ChuteRules.next_spec(_rng(2), 55.0, [&"notch", &"notch"], [&"notch"])
	assert_false(bool(s["golden"]) and s["shape"] == &"notch", "Rocco waits a card after two notches")
	assert_ne(s["shape"], &"notch", "and the card dealt instead is not a third notch")
	s = ChuteRules.next_spec(_rng(2), 55.0, [&"notch", &"notch"], [&"notch", &"rising"])
	assert_true(bool(s["golden"]), "another story chart is free to come")
	assert_eq(s["shape"], &"rising", "and it is not the third notch")


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
	assert_eq(ChuteRules.rank(0, 5), "Jam Master", "only slips is jamming, not watching")
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


## Hand-edited or odd saves: numbers where strings belong read as text, never crash.
func test_scores_read_numbers_as_text() -> void:
	Game.progress["arcade"] = {"chart_chute": {"table": [{"initials": 123.0, "score": 500.0, "accuracy": 1.0}], "found": [1.0, "notch"], "initials": 42.0}}
	var t := ArcadeScores.table("chart_chute")
	assert_eq(t.size(), 1, "the row reads")
	assert_eq(String(t[0]["initials"]).length(), 3, "initials are three letters")
	assert_eq(ArcadeScores.found("chart_chute").size(), 2, "found reads both")
	assert_eq(ArcadeScores.last_initials("chart_chute").length(), 3, "last initials read")


func test_arcade_save_key_is_in_the_defaults() -> void:
	assert_true(Game.DEFAULT_PROGRESS.has("arcade"), "Game.DEFAULT_PROGRESS has an arcade key, or high scores never load")


# ================================================================ AIR & BONE (the type belt)

## Every type card is what the engine's own rule says, with a margin: any one air or bone point
## 5 dB either way keeps the call; bone is honest (never poorer than air, inside the bone limits).
func test_every_type_card_has_its_type_with_a_margin() -> void:
	for type: StringName in ChartDeck.TYPES:
		for lookalike: bool in [false, true]:
			for s in SEEDS:
				var c := ChartDeck.make_card(_rng(s * 11 + 3), type, {"ear": "left" if s % 3 == 0 else "right", "lookalike": lookalike}, s)
				var ear := String(c["sort_ear"])
				var ac: Dictionary = c["ac"][ear]
				var bc: Dictionary = c["bc"][ear]
				assert_false(bc.is_empty(), "%s: bone drawn (seed %d)" % [type, s])
				assert_eq(ClinicRules.hearing_type(ac, bc), type, "%s is %s by hearing_type (seed %d, lookalike %s)" % [type, type, s, lookalike])
				assert_true(ChartDeck.stable_type(ac, bc, type), "%s keeps its type 5 dB either way (seed %d)" % [type, s])
				assert_has(ChartDeck.TYPE_AIR[type], ChartDeck.shape_of(ac), "%s: the air line has a %s shape" % [type, type])
				for f: int in bc:
					assert_true(int(bc[f]) <= int(ac[f]), "%s: bone never poorer than air at %d" % [type, f])
					assert_true(int(bc[f]) <= int(ClinicRules.BC_MAX_DB[f]), "%s: bone inside the oscillator's range at %d" % [type, f])
					assert_eq(int(bc[f]) % 5, 0, "5 dB steps")
					var masked: bool = (c["bc_masked"][ear] as Dictionary).has(f)
					assert_eq(masked, int(ac[f]) - int(bc[f]) >= ClinicRules.BC_MASK_GAP_DB, "%s: bone masked exactly where a clinician would" % type)
				assert_eq(String(c["ear"]), ear, "a type card is one ear")
				assert_eq((c["ac"] as Dictionary).size(), 1, "one ear's air")


func test_type_belt_ramp() -> void:
	assert_eq(ChuteRules.unlocked(-1.0, &"types"), [&"sensorineural", &"conductive"], "warm-up: SN and conductive")
	assert_false(ChuteRules.unlocked(14.9, &"types").has(&"mixed"), "mixed waits for 15 s")
	assert_eq(ChuteRules.unlocked(15.0, &"types"), ChartDeck.TYPES, "all three at 15 s")
	var r := _rng(9)
	for i in 300:
		var t := r.randf_range(0.0, ChuteRules.RUN_S)
		var spec := ChuteRules.next_spec(r, t, [], [], &"types")
		assert_has(ChartDeck.TYPES, spec["shape"], "only types on the type belt")
		assert_ne(String(spec["ear"]), "both", "no two-ear cards on the type belt")
		assert_false(bool(spec["golden"]), "no story charts on the type belt")


func test_type_belt_reads_and_lines() -> void:
	for type: StringName in ChartDeck.TYPES:
		assert_true(ChartDeck.CHUTE_WORDS.has(type) and ChartDeck.TELLS.has(type) and ChartDeck.LINES.has(type), "%s has a word, a tell and lines" % type)
		for pool: String in ["plain", "lookalike"]:
			for arch: Array in ChartDeck.TYPE_ARCH[type][pool]:
				var ac := {}
				for i in ChartDeck.FREQS.size():
					ac[ChartDeck.FREQS[i]] = int(arch[0][i])
				var bc := {}
				for i in ChartDeck.BONE_FREQS.size():
					bc[ChartDeck.BONE_FREQS[i]] = int(arch[1][i])
				assert_true(ChartDeck.stable_type(ac, bc, type), "%s %s archetype %s is itself a clean chart" % [type, pool, str(arch)])
	var gap_free := {250: 20, 500: 25, 1000: 30, 2000: 40, 3000: 50, 4000: 55, 6000: 60, 8000: 65}
	assert_eq(ClinicRules.hearing_type(gap_free, {500: 25, 1000: 30, 2000: 35, 4000: 55}), &"sensorineural", "bone on air: SN")


# ================================================================ TYMP TOSS (the tymp belt)

## Every tymp card is the Jerger type its chute claims (CaseRules.tymp_type, the tympanometer's own
## rule), with the peak 40 daPa and 0.04 mL clear of every line; canal volume normal except on a
## lookalike B, whose line then hints at wax or a hole.
func test_every_tymp_card_has_its_type_with_a_margin() -> void:
	for id: StringName in ChartDeck.TYMPS:
		for lookalike: bool in [false, true]:
			for s in SEEDS:
				var c := ChartDeck.make_card(_rng(s * 13 + 5), id, {"ear": "left" if s % 3 == 0 else "right", "lookalike": lookalike}, s)
				var t: Dictionary = c["tymp"]
				assert_false(t.is_empty(), "%s: a tymp (seed %d)" % [id, s])
				assert_eq(CaseRules.tymp_type_of(t), ChartDeck.TYMP_TYPE[id], "%s is type %s (seed %d, lookalike %s)" % [id, ChartDeck.TYMP_TYPE[id], s, lookalike])
				assert_true(ChartDeck.stable_tymp(t, id), "%s keeps its type with the peak nudged (seed %d)" % [id, s])
				assert_eq(int(t["peak_daPa"]) % 5, 0, "5 daPa steps")
				var ecv := float(t["ecv_ml"])
				if id == &"tymp_b" and lookalike:
					assert_true(ecv < CaseRules.TYMP_BLOCKED_ECV or ecv > CaseRules.TYMP_ADULT_ECV.y, "a lookalike B has a tiny or large canal (%.1f)" % ecv)
					assert_has(ChartDeck.TYMP_B_LINES.values(), c["line"], "and its line hints at why")
				else:
					assert_true(ecv >= CaseRules.TYMP_ADULT_ECV.x and ecv <= CaseRules.TYMP_ADULT_ECV.y, "%s: canal volume inside the adult band" % id)
				assert_eq(String(c["ear"]), String(c["sort_ear"]), "a tymp card is one ear")


func test_tymp_belt_ramp() -> void:
	assert_eq(ChuteRules.unlocked(-1.0, &"tymps"), [&"tymp_a", &"tymp_b"], "warm-up: A and B")
	assert_false(ChuteRules.unlocked(9.9, &"tymps").has(&"tymp_as"), "As waits for 10 s")
	assert_false(ChuteRules.unlocked(19.9, &"tymps").has(&"tymp_c"), "C waits for 20 s")
	assert_false(ChuteRules.unlocked(29.9, &"tymps").has(&"tymp_ad"), "Ad waits for 30 s")
	assert_eq(ChuteRules.unlocked(30.0, &"tymps"), ChartDeck.TYMPS, "all five at 30 s")
	var r := _rng(11)
	for i in 300:
		var spec := ChuteRules.next_spec(r, r.randf_range(0.0, ChuteRules.RUN_S), [], [], &"tymps")
		assert_has(ChartDeck.TYMPS, spec["shape"], "only tymps on the tymp belt")
		assert_ne(String(spec["ear"]), "both", "no two-ear cards")
		assert_false(bool(spec["golden"]), "no story charts")
	for id: StringName in ChartDeck.TYMPS:
		assert_true(ChartDeck.CHUTE_WORDS.has(id) and ChartDeck.TELLS.has(id) and ChartDeck.LINES.has(id), "%s has a word, a tell and lines" % id)
		var tell: Dictionary = ChartDeck.TELLS[id]
		assert_true(tell.has("p_lo") and tell.has("ml_hi"), "%s's tell is a patch of the tympanogram" % id)


# ================================================================ DEGREE DROP (the degree belt)

## Every degree card's 500/1k/2k average names its chute's degree (ClinicRules.degree_name), sits
## 5 dB inside the band, and every point is a real threshold inside the audiometer's range.
func test_every_degree_card_has_its_degree_with_a_margin() -> void:
	for id: StringName in ChartDeck.DEGREES:
		for lookalike: bool in [false, true]:
			for s in SEEDS:
				var c := ChartDeck.make_card(_rng(s * 17 + 7), id, {"ear": "left" if s % 3 == 0 else "right", "lookalike": lookalike}, s)
				var ear := String(c["sort_ear"])
				var t: Dictionary = c["ac"][ear]
				assert_false(t.is_empty(), "%s: a chart (seed %d, lookalike %s)" % [id, s, lookalike])
				var avg := ClinicRules.pta(t)
				assert_eq(ClinicRules.degree_name(avg), ChartDeck.DEGREE_NAME[id], "%s: average %.1f (seed %d)" % [id, avg, s])
				for d: int in [-5, 5]:
					for f: int in [500, 1000, 2000]:
						var p := t.duplicate()
						p[f] = int(t[f]) + d
						assert_eq(ClinicRules.degree_name(ClinicRules.pta(p)), ChartDeck.DEGREE_NAME[id], "%s keeps its degree with %d Hz 5 dB off" % [id, f])
				for f: int in t:
					assert_eq(int(t[f]), ClinicRules.clamp_db(int(t[f]), f), "%s: inside the audiometer's range at %d" % [id, f])


func test_degree_belt_ramp() -> void:
	assert_eq(ChuteRules.unlocked(-1.0, &"degrees"), [&"deg_mild", &"deg_moderate"], "warm-up: mild and moderate")
	assert_eq(ChuteRules.unlocked(30.0, &"degrees"), ChartDeck.DEGREES, "all five at 30 s")
	assert_false(ChuteRules.unlocked(29.9, &"degrees").has(&"deg_profound"), "profound waits for 30 s")
	for id: StringName in ChartDeck.DEGREES:
		assert_true(ChartDeck.CHUTE_WORDS.has(id) and ChartDeck.TELLS.has(id) and ChartDeck.LINES.has(id), "%s has a word, a tell and lines" % id)
	# the lookalikes are the point of the belt: their worst point is in a worse band than their average
	var r := _rng(4)
	var traps := 0
	for i in 40:
		var t := ChartDeck.make_degree_chart(r, &"deg_mild", true)
		var worst := 0
		for f: int in t:
			worst = maxi(worst, int(t[f]))
		if ClinicRules.degree_name(float(worst)) != "mild":
			traps += 1
	assert_eq(traps, 40, "every mild lookalike has a point far worse than mild")


# ================================================================ FLAT OUT (the flat-tymp belt)

## Every flat card is a type B whose canal volume reads its chute (CaseRules.tymp_b_reading), with
## 0.1 mL to spare either way; every PEAK card is a TYMP TOSS-stable A, As or C with a normal volume.
func test_every_flat_card_reads_its_chute_with_a_margin() -> void:
	for id: StringName in ChartDeck.FLATS:
		for lookalike: bool in [false, true]:
			for s in SEEDS:
				var c := ChartDeck.make_card(_rng(s * 13 + 5), id, {"ear": "left" if s % 3 == 0 else "right", "lookalike": lookalike}, s)
				var t: Dictionary = c.get("tymp", {})
				assert_false(t.is_empty(), "%s: a tympanogram (seed %d, lookalike %s)" % [id, s, lookalike])
				assert_eq(c["shape"], id, "%s: the card names its chute" % id)
				assert_true(ChartDeck.stable_flat(t, id), "%s: clear of every line (seed %d)" % [id, s])
				var ecv := float(t["ecv_ml"])
				if id == &"flat_peak":
					assert_ne(CaseRules.tymp_type_of(t), &"B", "PEAK: not flat")
					assert_ne(CaseRules.tymp_type_of(t), &"Ad", "PEAK: no Ad, its peak would climb under the gauge")
					assert_eq(CaseRules.ecv_band(ecv), &"normal", "PEAK: a normal canal volume")
				else:
					assert_eq(CaseRules.tymp_type_of(t), &"B", "%s: flat" % id)
					assert_eq(CaseRules.tymp_b_reading(ecv), ChartDeck.FLAT_READING[id], "%s: volume %.1f reads right" % [id, ecv])
				if lookalike:
					assert_eq(String(c["line"]), String(ChartDeck.FLAT_TRAP_LINES[id]), "%s: a lookalike tells the wrong story" % id)
					if id == &"flat_peak":
						assert_eq(CaseRules.tymp_type_of(t), &"As", "PEAK's lookalike is a shallow As")


func test_flat_belt_ramp() -> void:
	assert_eq(ChuteRules.unlocked(-1.0, &"flats"), [&"flat_fluid", &"flat_wax"], "warm-up: fluid and wax")
	assert_false(ChuteRules.unlocked(9.9, &"flats").has(&"flat_hole"), "hole waits for 10 s")
	assert_false(ChuteRules.unlocked(24.9, &"flats").has(&"flat_peak"), "peak waits for 25 s")
	assert_eq(ChuteRules.unlocked(25.0, &"flats"), ChartDeck.FLATS, "all four at 25 s")
	var r := _rng(12)
	for i in 300:
		var spec := ChuteRules.next_spec(r, r.randf_range(0.0, ChuteRules.RUN_S), [], [], &"flats")
		assert_has(ChartDeck.FLATS, spec["shape"], "only flat chutes on the flat belt")
		assert_ne(String(spec["ear"]), "both", "no two-ear cards")
		assert_false(bool(spec["golden"]), "no story charts")
	for id: StringName in ChartDeck.FLATS:
		assert_true(ChartDeck.CHUTE_WORDS.has(id) and ChartDeck.TELLS.has(id) and ChartDeck.LINES.has(id), "%s has a word, a tell and lines" % id)
		var tell: Dictionary = ChartDeck.TELLS[id]
		assert_true(tell.has("gauge") or tell.has("p_lo"), "%s's tell glows over the gauge or the curve" % id)
	# the flat lines' own readings agree with the game's rule (the gauge draws CaseRules' numbers)
	assert_eq(CaseRules.tymp_b_reading(0.59), &"blocked", "under 0.6 mL is blocked")
	assert_eq(CaseRules.tymp_b_reading(2.01), &"hole", "over 2.0 mL is a hole")


# ================================================================ OTO SPOT (the look-in-the-ear belt)

## Every oto card names its chute's view, on the ear the card asks for, and a lookalike says so.
func test_every_oto_card_shows_its_chutes_view() -> void:
	for id: StringName in ChartDeck.OTOS:
		for lookalike: bool in [false, true]:
			for s in SEEDS:
				var c := ChartDeck.make_card(_rng(s * 11 + 3), id, {"ear": "left" if s % 3 == 0 else "right", "lookalike": lookalike}, s)
				assert_eq(c["shape"], id, "%s: the card names its chute" % id)
				var oto: Dictionary = c.get("oto", {})
				assert_eq(oto.get("view", &""), ChartDeck.OTO_VIEW[id], "%s: the view is the chute's (seed %d)" % [id, s])
				assert_eq(bool(oto.get("lookalike", false)), lookalike, "%s: the lookalike flag rides on the view" % id)
				assert_true((c["ac"] as Dictionary).is_empty() and not c.has("tymp"), "%s: no chart, no tympanogram" % id)
				assert_eq(String(c["sort_ear"]), "left" if s % 3 == 0 else "right", "%s: the asked ear" % id)


func test_oto_belt_ramp() -> void:
	assert_eq(ChuteRules.unlocked(-1.0, &"otos"), [&"oto_clear", &"oto_wax"], "warm-up: clear and wax")
	assert_false(ChuteRules.unlocked(9.9, &"otos").has(&"oto_fluid"), "fluid waits for 10 s")
	assert_false(ChuteRules.unlocked(19.9, &"otos").has(&"oto_hole"), "hole waits for 20 s")
	assert_false(ChuteRules.unlocked(29.9, &"otos").has(&"oto_object"), "object waits for 30 s")
	assert_eq(ChuteRules.unlocked(30.0, &"otos"), ChartDeck.OTOS, "all five at 30 s")
	var r := _rng(13)
	for i in 300:
		var spec := ChuteRules.next_spec(r, r.randf_range(0.0, ChuteRules.RUN_S), [], [], &"otos")
		assert_has(ChartDeck.OTOS, spec["shape"], "only looks in the ear on the oto belt")
		assert_ne(String(spec["ear"]), "both", "no two-ear cards")
		assert_false(bool(spec["golden"]), "no story charts")
	for id: StringName in ChartDeck.OTOS:
		assert_true(ChartDeck.CHUTE_WORDS.has(id) and ChartDeck.TELLS.has(id) and ChartDeck.LINES.has(id), "%s has a word, a tell and lines" % id)
		assert_true(ChartDeck.TELLS[id].has("view"), "%s's tell glows over the drum" % id)
		# the tell is said by Hoot on the NEW CHUTE line: keep it short
		assert_true(String(ChartDeck.TELLS[id]["text"]).split(" ").size() <= 12, "%s's tell is short" % id)
