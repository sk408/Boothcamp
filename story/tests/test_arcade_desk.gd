extends TestCase
## Ears, Please! (docs/ARCADE.md): the rules decide every file from CaseRules and ClinicRules, the
## deck only makes clear-cut files, and no blanket strategy (always FIT, always REFER, guessing)
## comes close to reading the file.

const DeskRules := preload("res://story/arcade/desk_rules.gd")
const DeskDeck := preload("res://story/arcade/desk_deck.gd")

const SEEDS := 80


func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r


## A hand-built file: both ears from one table, with optional changes.
func _file(right: Dictionary, left: Dictionary, intake: Dictionary = {}, sudden: Dictionary = {}, bc_right: Dictionary = {}, bc_left: Dictionary = {}) -> Dictionary:
	var bcr := bc_right if not bc_right.is_empty() else {500: int(right[500]), 1000: int(right[1000]), 2000: int(right[2000]), 4000: int(right[4000])}
	var bcl := bc_left if not bc_left.is_empty() else {500: int(left[500]), 1000: int(left[1000]), 2000: int(left[2000]), 4000: int(left[4000])}
	return {"ac": {"right": right, "left": left}, "bc": {"right": bcr, "left": bcl}, "intake": intake, "sudden": sudden}


func _slope(shift_db: int = 0) -> Dictionary:
	return {250: 20 + shift_db, 500: 25 + shift_db, 1000: 35 + shift_db, 1500: 40 + shift_db, 2000: 45 + shift_db, 3000: 50 + shift_db,
		4000: 55 + shift_db, 6000: 60 + shift_db, 8000: 65 + shift_db}


func test_symmetric_aidable_loss_is_fit() -> void:
	var v := DeskRules.decide(_file(_slope(), _slope()))
	assert_eq(v["decision"], &"fit")
	assert_true((v["proofs"] as Array).is_empty())


func test_one_ear_worse_is_refer_proved_by_its_columns() -> void:
	var left := _slope()
	left[2000] = 70
	left[3000] = 75
	var v := DeskRules.decide(_file(_slope(), left))
	assert_eq(v["decision"], &"refer")
	assert_true(DeskRules.proof_ok(v, {"kind": "chart", "freq": 2000}))
	assert_true(DeskRules.proof_ok(v, {"kind": "chart", "freq": 3000}))
	assert_false(DeskRules.proof_ok(v, {"kind": "chart", "freq": 500}), "a column where the ears match proves nothing")
	assert_false(DeskRules.proof_ok(v, {"kind": "intake", "id": "pain"}))


func test_a_single_odd_frequency_is_not_one_ear_worse() -> void:
	var left := _slope()
	left[4000] = 80
	assert_eq(DeskRules.decide(_file(_slope(), left))["decision"], &"fit", "one frequency is not a run of two")


func test_every_intake_flag_refers_and_proves_itself() -> void:
	for id: String in DeskRules.INTAKE_WORDS:
		var v := DeskRules.decide(_file(_slope(), _slope(), {id: true}))
		assert_eq(v["decision"], &"refer", id)
		assert_true(DeskRules.proof_ok(v, {"kind": "intake", "id": id}), id)
		var flags: Array = CaseRules.RED_FLAGS.map(func(f: Dictionary) -> String: return String(f["id"]))
		assert_has(flags, id, "%s is one of CaseRules.RED_FLAGS" % id)


func test_air_bone_gap_refers() -> void:
	var right := {250: 40, 500: 40, 1000: 40, 1500: 40, 2000: 40, 3000: 40, 4000: 40, 6000: 20, 8000: 20}
	var v := DeskRules.decide(_file(right, _slope(-10), {}, {}, {500: 10, 1000: 10, 2000: 10, 4000: 15}))
	assert_eq(v["decision"], &"refer")
	assert_true(DeskRules.proof_ok(v, {"kind": "chart", "freq": 1000}))
	assert_true(DeskRules.proof_ok(v, {"kind": "chart", "freq": 4000}), "a 25 dB gap at 4k shows the gap too")
	assert_eq(DeskRules.best_target(v)["freq"], 1000, "Hoot points at the gap, not at the split it causes")
	assert_eq(DeskRules.card_for(DeskRules.best_proof(v)), "gap")


func test_a_gap_in_both_ears_refers_with_matching_ears() -> void:
	var bc := {500: 0, 1000: 10, 2000: 25, 4000: 55}
	var v := DeskRules.decide(_file(_slope(), _slope(), {}, {}, bc, bc.duplicate()))
	assert_eq(v["decision"], &"refer", "air alone looks like a FIT; bone says middle ear")
	assert_false(CaseRules.is_asymmetric(_slope(), _slope()))
	assert_eq(DeskRules.card_for(DeskRules.best_proof(v)), "gap")
	assert_false(DeskRules.proof_ok(v, {"kind": "chart", "freq": 4000}), "no gap at 4k here")


func test_sudden_and_recent_is_today_and_only_the_card_proves_it() -> void:
	var left := _slope()
	for f: int in [1000, 1500, 2000, 3000, 4000]:
		left[f] = int(left[f]) + 35
	var s := {"pattern": "sudden", "came_on_h": 8, "days_ago": 3, "ear": "left"}
	var v := DeskRules.decide(_file(_slope(), left, {}, s))
	assert_eq(v["decision"], &"today")
	assert_true(DeskRules.proof_ok(v, {"kind": "sudden"}))
	assert_false(DeskRules.proof_ok(v, {"kind": "chart", "freq": 2000}), "TODAY is proved by the sudden card")
	# the same loss that started two months ago is an urgent REFER, not TODAY (CaseRules header)
	var late := {"pattern": "sudden", "came_on_h": 8, "days_ago": 60, "ear": "left"}
	assert_eq(DeskRules.decide(_file(_slope(), left, {}, late))["decision"], &"refer")
	assert_true(DeskRules.sudden_words(late).begins_with("Sudden, but"))
	# came on slowly: no sudden flag (one ear worse still refers)
	var slow := DeskRules.decide(_file(_slope(), left, {}, {"pattern": "gradual", "came_on_h": 0, "days_ago": 900}))
	assert_eq(slow["decision"], &"refer")
	assert_false(DeskRules.proof_ok(slow, {"kind": "sudden"}))
	# a fluctuating loss is a red flag, not same-day
	var on_off := {"pattern": "fluctuating", "came_on_h": 0, "days_ago": 10}
	var fl := DeskRules.decide(_file(_slope(), _slope(), {}, on_off))
	assert_eq(fl["decision"], &"refer")
	assert_true(DeskRules.proof_ok(fl, {"kind": "sudden"}))
	assert_true(DeskRules.sudden_words(on_off).begins_with("Comes and goes"))


func test_wax_does_not_explain_a_sudden_drop_when_bone_is_down_too() -> void:
	# sudden.json: "Wax would block air, not bone: bone settles it."
	var left := _slope()
	for f: int in [1000, 1500, 2000, 3000, 4000]:
		left[f] = int(left[f]) + 35
	var s := {"pattern": "sudden", "came_on_h": 8, "days_ago": 3, "ear": "left"}
	assert_eq(DeskRules.decide(_file(_slope(), left, {"wax": true}, s))["decision"], &"today", "wax + bone down with air: still TODAY")
	# wax and a gap on the sudden ear (Barnaby): the wax explains it, refer
	var bcl := {500: 10, 1000: 15, 2000: 25, 4000: 50}
	var v := DeskRules.decide(_file(_slope(), left, {"wax": true}, s, {}, bcl))
	assert_eq(v["decision"], &"refer")
	# a gap in the OTHER ear does not cancel TODAY
	var right := _slope()
	var bcr := {500: 0, 1000: 10, 2000: 25, 4000: 55}
	assert_eq(DeskRules.decide(_file(right, left, {}, s, bcr))["decision"], &"today")


func test_a_sudden_card_needs_the_drop_on_the_chart() -> void:
	var s := {"pattern": "sudden", "came_on_h": 8, "days_ago": 3, "ear": "left"}
	var v := DeskRules.decide(_file(_slope(), _slope(), {}, s))
	assert_eq(v["decision"], &"refer", "no 30 dB drop at 3 neighbours: a sudden card alone is a red flag, not TODAY")
	assert_true(DeskRules.proof_ok(v, {"kind": "sudden"}))
	# quickly worsening (over 5 days) in the last 6 months: a red flag the card proves
	var slowish := {"pattern": "sudden", "came_on_h": 120, "days_ago": 10, "ear": "left"}
	var w := DeskRules.decide(_file(_slope(), _slope(), {}, slowish))
	assert_eq(w["decision"], &"refer")
	assert_true(DeskRules.proof_ok(w, {"kind": "sudden"}))


func test_the_desk_lists_match_the_engine() -> void:
	var bone := ClinicRules.BC_REQUIRED.duplicate()
	bone.sort()
	assert_eq(DeskRules.BONE_FREQS, bone, "bone frequencies = ClinicRules.BC_REQUIRED")
	for f: int in DeskRules.FREQS:
		assert_has(ClinicRules.AC_FREQS, f)
	for f: int in [1500, 3000, 6000]:
		assert_has(DeskRules.FREQS, f, "Steve's E1: %d Hz is routine" % f)
	assert_false(DeskRules.FREQS.has(750), "750 Hz only when 500 and 1k differ by 20 dB")
	assert_eq(DeskRules.FREQS, ClinicRules.ROUTINE_FREQS, "the engine's routine list")
	for id: String in DeskRules.ASKED + DeskRules.LOOKED:
		assert_true(DeskRules.INTAKE_WORDS.has(id), id)
	assert_eq((DeskRules.ASKED + DeskRules.LOOKED).size(), DeskRules.INTAKE_WORDS.size())


func test_no_line_names_a_cause() -> void:
	# the wall's ONE EAR WORSE means "no known cause"; a line naming one would make it a FIT in Freestyle
	var causes: PackedStringArray = ["noise", "loud", "gun", "shoot", "music", "band", "gig", "factory", "drill", "engine", "hit", "injur", "accident", "concert"]
	var lines: Array[String] = []
	for l: Array in DeskDeck.LINES:
		lines.append(String(l[0]))
		assert_true(String(l[1]).length() > 0 and String(l[1]).length() <= 14, "goal '%s' fits the sticker" % l[1])
	for b: String in DeskDeck.BOSSES:
		lines.append(String(DeskDeck.BOSSES[b]["line"]))
	for l: String in lines:
		for c: String in causes:
			assert_false(l.to_lower().contains(c), "'%s' names a cause (%s)" % [l, c])


func test_score_table_is_lopsided() -> void:
	var fit := {"decision": &"fit", "proofs": []}
	var refer := {"decision": &"refer", "proofs": [{"kind": "intake", "id": "pain"}]}
	var today := {"decision": &"today", "proofs": [{"kind": "sudden"}]}
	assert_eq(DeskRules.score_call(fit, &"fit", false, 0)["outcome"], DeskRules.CLEAN)
	assert_eq(DeskRules.score_call(refer, &"refer", true, 0)["outcome"], DeskRules.CLEAN)
	assert_eq(DeskRules.score_call(refer, &"refer", false, 4)["outcome"], DeskRules.WRONG_REASON)
	assert_eq(DeskRules.score_call(refer, &"refer", false, 4)["combo"], 0, "a wrong reason clears the combo")
	assert_true(DeskRules.POINTS_MISSED_FLAG <= -2 * DeskRules.POINTS_BASE, "a missed flag costs two clean calls")
	assert_eq(DeskRules.score_call(fit, &"refer", true, 0)["outcome"], DeskRules.OVER)
	assert_eq(DeskRules.score_call(refer, &"fit", false, 0)["outcome"], DeskRules.MISSED_FLAG)
	assert_eq(DeskRules.score_call(refer, &"today", true, 0)["outcome"], DeskRules.TOO_URGENT)
	assert_eq(DeskRules.score_call(today, &"refer", true, 0)["outcome"], DeskRules.MISSED_TODAY)
	assert_true(bool(DeskRules.score_call(today, &"fit", false, 0)["incident"]))
	var over := int(DeskRules.score_call(fit, &"refer", true, 0)["points"])
	var missed := int(DeskRules.score_call(refer, &"fit", false, 0)["points"])
	var missed_today := int(DeskRules.score_call(today, &"refer", true, 0)["points"])
	assert_true(missed < over and missed_today < missed, "a missed flag costs more than an extra referral")
	assert_eq(int(DeskRules.score_call(fit, &"fit", false, 2)["points"]), DeskRules.POINTS_BASE * 2, "the third clean call in a row is x2")
	assert_eq(int(DeskRules.score_call(fit, &"fit", false, 0, true)["points"]), DeskRules.POINTS_BASE * DeskRules.BOSS_FACTOR)


func test_deck_files_decide_as_built_with_clear_margins() -> void:
	for sh: Dictionary in DeskRules.SHIFTS:
		var counts := {}
		for seed in SEEDS:
			var rng := _rng(seed * 31 + int(sh["id"]))
			for want: StringName in (sh["mix"] as Dictionary):
				var f := DeskDeck.make_file(rng, sh, want, seed)
				assert_false(f.is_empty(), "shift %d %s seed %d" % [sh["id"], want, seed])
				if f.is_empty():
					continue
				assert_eq(DeskRules.decide(f)["decision"], want, "shift %d seed %d %s" % [sh["id"], seed, f["kind"]])
				assert_true(DeskDeck.valid(f, sh, String(f["kind"])), "shift %d seed %d %s" % [sh["id"], seed, f["kind"]])
				counts[f["kind"]] = int(counts.get(f["kind"], 0)) + 1
		for kind: String in (sh["refer_kinds"] as Dictionary):
			assert_true(int(counts.get(kind, 0)) > 0, "shift %d makes %s files" % [sh["id"], kind])


func test_every_gap_on_the_chart_is_masked_bone() -> void:
	# E5: bone is masked from a 10 dB gap (ClinicRules.BC_MASK_GAP_DB), so any gap that size is real
	for sh: Dictionary in DeskRules.SHIFTS:
		for seed in SEEDS:
			for want: StringName in (sh["mix"] as Dictionary):
				var f := DeskDeck.make_file(_rng(seed * 7 + int(sh["id"])), sh, want, seed)
				for ear: String in ClinicRules.EARS:
					for fr: int in f["bc"][ear]:
						var gap := int(f["ac"][ear][fr]) - int(f["bc"][ear][fr])
						if gap >= ClinicRules.BC_MASK_GAP_DB:
							assert_true(bool(f["bc_masked"][ear].get(fr, false)), "shift %d seed %d %s %d Hz: a %d dB gap on unmasked bone" % [sh["id"], seed, ear, fr, gap])


func test_age_never_gives_the_call_away() -> void:
	# adults are never referred for their age, so every kind draws from the same ages
	for sh: Dictionary in DeskRules.SHIFTS:
		for kind: String in ["fit"] + (sh["refer_kinds"] as Dictionary).keys():
			for seed in SEEDS:
				var f := DeskDeck.make_kind(_rng(seed * 17 + int(sh["id"])), sh, kind, seed)
				assert_between(int(f["age"]), 50, 88, "shift %d %s seed %d" % [sh["id"], kind, seed])


func test_every_masked_point_could_really_be_measured() -> void:
	# a made-up two-ear gap of 25 dB with the ears 5 dB apart is a masking dilemma: final_chart says so
	var air := {"right": {}, "left": {}}
	var gaps := {"right": {}, "left": {}}
	for fr: int in DeskRules.FREQS:
		air["right"][fr] = 45
		air["left"][fr] = 50
	for ear: String in ClinicRules.EARS:
		for fr: int in [500, 1000, 2000]:
			gaps[ear][fr] = 25
	assert_true(bool(DeskDeck.final_chart(air, gaps)["dilemma"]), "a 25 dB gap in both ears, 5 dB apart")
	for ear: String in ClinicRules.EARS:
		for fr: int in [500, 1000, 2000]:
			gaps[ear][fr] = DeskDeck.GAP_BOTH_DB.max()
	assert_false(bool(DeskDeck.final_chart(air, gaps)["dilemma"]), "the deck's two-ear gap keeps a safe window")
	# and the deck never deals one
	for sh: Dictionary in DeskRules.SHIFTS:
		for kind: String in ["fit"] + (sh["refer_kinds"] as Dictionary).keys():
			for seed in SEEDS:
				var f := DeskDeck.make_kind(_rng(seed * 19 + int(sh["id"])), sh, kind, seed)
				assert_false(bool(f.get("dilemma", true)), "shift %d %s seed %d" % [sh["id"], kind, seed])


func test_750_sits_between_its_neighbours_in_each_ear() -> void:
	# the interoctave is filled in, never a dip or a peak the patient doesn't have
	for sh: Dictionary in DeskRules.SHIFTS:
		for kind: String in ["fit"] + (sh["refer_kinds"] as Dictionary).keys():
			for seed in SEEDS:
				var f := DeskDeck.make_kind(_rng(seed * 23 + int(sh["id"])), sh, kind, seed)
				for ear: String in ClinicRules.EARS:
					var a: Dictionary = f["ac"][ear]
					if not a.has(750):
						continue
					var lo := mini(int(a[500]), int(a[1000])) - 5
					var hi := maxi(int(a[500]), int(a[1000])) + 5
					assert_between(int(a[750]), lo, hi, "shift %d %s seed %d %s: 500/750/1k = %d/%d/%d" % [sh["id"], kind, seed, ear, a[500], a[750], a[1000]])


func test_fit_files_have_a_loss_aids_can_help() -> void:
	for sh: Dictionary in DeskRules.SHIFTS:
		for seed in SEEDS:
			var f := DeskDeck.make_file(_rng(seed), sh, &"fit", seed)
			assert_true(int(f["age"]) >= 18)
			for ear: String in ClinicRules.EARS:
				assert_between(ClinicRules.pta(f["ac"][ear]), 30.0, 65.0, "shift %d seed %d %s" % [sh["id"], seed, ear])
				assert_eq(ClinicRules.hearing_type(f["ac"][ear], f["bc"][ear]), &"sensorineural", "shift %d seed %d %s" % [sh["id"], seed, ear])


func test_only_gap_files_have_a_conductive_part() -> void:
	for sh: Dictionary in DeskRules.SHIFTS:
		for seed in SEEDS:
			for want: StringName in (sh["mix"] as Dictionary):
				var f := DeskDeck.make_file(_rng(seed * 13 + int(sh["id"])), sh, want, seed)
				if String(f["kind"]).begins_with("gap"):
					continue
				for ear: String in ClinicRules.EARS:
					assert_false(ClinicRules.hearing_type(f["ac"][ear], f["bc"][ear]) in [&"conductive", &"mixed"],
						"shift %d seed %d %s %s" % [sh["id"], seed, f["kind"], ear])


func test_make_kind_builds_every_kind_for_its_shift() -> void:
	var kinds := {1: ["fit", "intake", "one_ear"], 2: ["fit", "intake", "one_ear", "gap", "gap_both"],
		3: ["fit", "intake", "one_ear", "gap", "gap_both", "today", "sudden_late", "fluctuating"]}
	for id: int in kinds:
		var sh := DeskRules.shift(id)
		for kind: String in kinds[id]:
			for seed in 30:
				var f := DeskDeck.make_kind(_rng(seed + 500), sh, kind, seed)
				assert_false(f.is_empty(), "shift %d %s seed %d" % [id, kind, seed])
				if not f.is_empty():
					assert_eq(String(f["kind"]), kind)
					assert_true(DeskDeck.valid(f, sh, kind))


func test_two_ear_gap_files_look_like_a_fit_on_air_alone() -> void:
	for seed in SEEDS:
		var f := DeskDeck.make_kind(_rng(seed), DeskRules.shift(2), "gap_both", seed)
		assert_false(CaseRules.is_asymmetric(f["ac"]["right"], f["ac"]["left"]), "seed %d: no split to point at" % seed)
		var v := DeskRules.decide(f)
		assert_eq(DeskRules.card_for(DeskRules.best_proof(v)), "gap")
		for ear: String in ClinicRules.EARS:
			for fr: int in [500, 1000, 2000]:
				assert_true(bool(f["bc_masked"][ear].get(fr, false)), "seed %d %s %d: the gap is masked bone" % [seed, ear, fr])
				assert_between(int(f["ac"][ear][fr]) - int(f["bc"][ear][fr]), 20, 25, "seed %d %s %d" % [seed, ear, fr])


func test_one_ear_files_sit_on_fittable_losses_too() -> void:
	var on_fit := 0
	for seed in SEEDS:
		var f := DeskDeck.make_kind(_rng(seed), DeskRules.shift(1), "one_ear", seed)
		var better := "left" if String(f["poorer"]) == "right" else "right"
		if ClinicRules.pta(f["ac"][better]) >= 30.0:
			on_fit += 1
	assert_true(on_fit >= SEEDS / 10, "%d of %d one-ear files on a fittable better ear" % [on_fit, SEEDS])


func test_interoctaves_are_on_the_chart_where_the_rules_need_them() -> void:
	for seed in SEEDS:
		for want: StringName in [&"fit", &"refer"]:
			var f := DeskDeck.make_file(_rng(seed), DeskRules.shift(2), want, seed)
			for ear: String in ClinicRules.EARS:
				for fr: int in ClinicRules.required_interoctaves(f["ac"][ear]):
					assert_true((f["ac"][ear] as Dictionary).has(fr), "seed %d %s needs %d Hz" % [seed, ear, fr])


func test_bosses_tempt_the_wrong_stamp() -> void:
	for sh: Dictionary in DeskRules.SHIFTS:
		for seed in 10:
			var f := DeskDeck.make_boss(_rng(seed), sh, 99)
			assert_false(f.is_empty())
			var b: Dictionary = DeskDeck.BOSSES[String(sh["boss"])]
			assert_eq(DeskRules.decide(f)["decision"], b["want"], String(sh["boss"]))
			assert_eq(f["boss"], String(sh["boss"]))
	var wax := DeskDeck.make_boss(_rng(3), DeskRules.shift(3), 99)
	assert_false(bool(wax["intake"]["wax"]), "the 'only wax' boss has a clear canal")
	var plane := DeskDeck.make_boss(_rng(3), DeskRules.shift(2), 99)
	assert_false(CaseRules.is_asymmetric(plane["ac"]["right"], plane["ac"]["left"]), "Gary's gap is in both ears: only bone gives it away")


func test_a_line_never_runs_four_of_one_call() -> void:
	for seed in SEEDS:
		var line := DeskDeck.make_line(_rng(seed), DeskRules.shift(3), 40)
		for i in range(3, line.size()):
			assert_false(line[i] == line[i - 1] and line[i] == line[i - 2] and line[i] == line[i - 3], "seed %d at %d" % [seed, i])


## Play a shift with a strategy against the clock; returns {score (not floored), files}.
## Seconds per call: careful reads the file (READ_S) and points (PROVE_S); the blanket strategies
## stamp at once. Slips hold the shift clock (the desk does), so only reading and stamping cost time.
const READ_S := 5.0
const PROVE_S := 2.0
const STAMP_S := 0.6
const FEEDBACK_S := 0.7


func _play(strategy: String, seed: int, shift_id := 3, timed := false) -> Dictionary:
	var rng := _rng(seed)
	var pick := _rng(seed + 1000)
	var sh := DeskRules.shift(shift_id)
	var total := 0
	var combo := 0
	var t := 0.0
	var files := 0
	for want: StringName in DeskDeck.make_line(rng, sh, 120 if timed else 30):
		var f := DeskDeck.make_file(rng, sh, want, 0)
		var v := DeskRules.decide(f)
		var stamp: StringName = &"fit"
		var proof := {}
		var cost := STAMP_S + FEEDBACK_S
		match strategy:
			"careful":
				stamp = v["decision"]
				proof = DeskRules.best_target(v)
				cost += READ_S + (PROVE_S if DeskRules.needs_proof(stamp) else 0.0)
			"fit":
				stamp = &"fit"
			"refer", "today":
				stamp = StringName(strategy)
				proof = {"kind": "intake", "id": String((sh["intake"] as Array)[0])}
				cost += 0.5
			"guess":
				var stamps: Array = sh["stamps"]
				stamp = stamps[pick.randi() % stamps.size()]
				var targets: Array = [{"kind": "sudden"}, {"kind": "chart", "freq": DeskRules.FREQS[pick.randi() % DeskRules.FREQS.size()]}]
				for id: String in sh["intake"]:
					targets.append({"kind": "intake", "id": id})
				proof = targets[pick.randi() % targets.size()]
				cost += 0.5
		if timed:
			t += cost
			if t > DeskRules.SHIFT_S:
				break
		var r := DeskRules.score_call(v, stamp, DeskRules.proof_ok(v, proof), combo)
		combo = int(r["combo"])
		total += int(r["points"])
		files += 1
	return {"score": total, "files": files}


func test_no_blanket_strategy_comes_close_to_reading_the_file() -> void:
	for seed in [1, 2, 3, 4, 5]:
		var careful := int(_play("careful", seed)["score"])
		for s: String in ["fit", "refer", "today", "guess"]:
			var got := int(_play(s, seed)["score"])
			assert_true(got * 4 < careful, "seed %d: %s scored %d against careful %d" % [seed, s, got, careful])


func test_against_the_clock_careful_beats_refer_everything_beats_fit_everything() -> void:
	for shift_id in [1, 2]:
		for seed in [1, 2, 3, 4, 5, 6]:
			var careful := _play("careful", seed, shift_id, true)
			var refer := _play("refer", seed, shift_id, true)
			var fit := _play("fit", seed, shift_id, true)
			assert_true(int(careful["score"]) > int(refer["score"]), "shift %d seed %d: careful %s vs refer %s" % [shift_id, seed, careful, refer])
			assert_true(int(refer["score"]) > int(fit["score"]), "shift %d seed %d: refer %s vs fit %s" % [shift_id, seed, refer, fit])
			assert_true(int(fit["score"]) < 0, "stamping FIT on everything loses points (%s)" % fit)


func test_accuracy_counts_hoot_help_and_gates_the_board() -> void:
	var good := {"files": 12, "clean": 11, "helps": 0, "missed_flag": 0, "missed_today": 0, "over": 1}
	assert_true(DeskRules.safe(good))
	assert_true(DeskRules.promoted(good))
	assert_eq(DeskRules.rank(good), "Desk Legend")
	# help on every flagged file, FIT on the rest: clean looks perfect, but helps count as not clean
	var helped := {"files": 10, "clean": 10, "helps": 10, "missed_flag": 0, "missed_today": 0}
	assert_between(DeskRules.accuracy(helped), 0.499, 0.501)
	assert_false(DeskRules.safe(helped))
	assert_false(DeskRules.promoted(helped))
	assert_eq(DeskRules.rank(helped), "Learning the Ropes", "helps, not extra referrals, made it unclean")
	var few := {"files": 6, "clean": 6, "helps": 0, "missed_flag": 0, "missed_today": 0}
	assert_true(DeskRules.safe(few))
	assert_false(DeskRules.promoted(few), "promotion needs %d files" % DeskRules.PROMOTE_FILES)
	var missed := {"files": 20, "clean": 19, "helps": 0, "missed_flag": 1, "missed_today": 0}
	assert_false(DeskRules.safe(missed), "one missed red flag keeps a shift off the board")
	assert_eq(DeskRules.rank(missed), "One Got Away", "never praise a shift that let a red flag through")
	var over := {"files": 12, "clean": 6, "helps": 0, "missed_flag": 0, "missed_today": 0, "over": 6, "wrong_reason": 0}
	assert_eq(DeskRules.rank(over), "Better Safe Than Sorry")
	var wrong := {"files": 12, "clean": 6, "helps": 0, "missed_flag": 0, "missed_today": 0, "over": 1, "wrong_reason": 5}
	assert_eq(DeskRules.rank(wrong), "Show Your Working")
	assert_eq(DeskRules.rank({"files": 0}), "Coffee Break")
	assert_eq(DeskRules.rank({"files": 5, "clean": 3, "missed_today": 1}), "Incident Report")
	assert_eq(DeskRules.rank({"files": 5, "clean": 3, "missed_today": 2, "closed": true}), "Desk Closed")
	assert_eq(DeskRules.accuracy({"files": 0, "helps": 0}), -1.0)
