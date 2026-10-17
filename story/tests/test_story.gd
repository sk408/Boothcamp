extends TestCase
## Story (story/): dialogue box keys + solvers, mini-game solvers, Hoot bubble, pause menu,
## results paper, title beats and the voice synth's safety ceiling.

const Otoscopy := preload("res://story/games/otoscopy.gd")
const Evidence := preload("res://story/games/evidence.gd")
const Fitting := preload("res://story/games/fitting.gd")
const Reveal := preload("res://story/games/reveal.gd")
const Voice := preload("res://story/voice.gd")

var beats: Array = []


func before_each() -> void:
	beats.clear()
	Events.awaiting_input.connect(_on_awaiting)
	Game.begin_visit("gus")


func after_each() -> void:
	Events.awaiting_input.disconnect(_on_awaiting)
	Hoot.clear()
	Hoot.clear_bubble_hint()
	if tree.paused:
		tree.paused = false


func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
	beats.append({"beat": beat, "info": info, "solver": solver})


func _last(beat: StringName) -> Dictionary:
	for i in range(beats.size() - 1, -1, -1):
		if beats[i]["beat"] == beat:
			return beats[i]
	return {}


func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait_frames(2)
	var up := InputEventKey.new()
	up.keycode = code
	up.pressed = false
	Input.parse_input_event(up)
	await wait_frames(2)


func _results() -> Dictionary:
	var p := Game.load_patient("gus") as PatientProfile
	var ears := {}
	for ear: String in ["right", "left"]:
		var freqs := {}
		var th := {}
		for f: int in [250, 500, 1000, 2000, 4000, 8000]:
			var db := p.get_threshold(ear, f)
			th[f] = db
			freqs[f] = {"ear": ear, "freq": f, "stored_db": db, "true_db": db, "no_response": false, "strokes": 7, "par": 7, "golf": &"par"}
		ears[ear] = {"freqs": freqs, "complete": true, "shape": ClinicRules.classify_shape(th), "pta": ClinicRules.pta(th)}
	return {"patient_id": "gus", "ears": ears, "presentations": 84, "false_alarms": 0, "max_combo": 10,
		"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0, "score": 100.0, "grade": "S"}


# ---------------------------------------------------------------- dialogue

func test_say_advances_with_the_action_and_emits_beat() -> void:
	var box := DialogueBox.new()
	add_node(box)
	var done := [false]
	var lines: Array = []
	var on_line := func(s: String, t: String) -> void: lines.append([s, t])
	Events.dialogue_line.connect(on_line)
	var run := func() -> void:
		await box.say("Gus", "Everyone mumbles these days!")
		done[0] = true
	run.call()
	await wait_frames(2)
	assert_false(_last(&"dialogue").is_empty(), "dialogue beat emitted")
	assert_eq(lines.size(), 1, "dialogue_line emitted")
	await tap_action(&"advance_dialogue")   # finishes the typing
	await tap_action(&"advance_dialogue")   # continues
	assert_true(done[0], "say() returned after the second press")
	Events.dialogue_line.disconnect(on_line)


func test_choose_with_number_key() -> void:
	var box := DialogueBox.new()
	add_node(box)
	var got := [-1]
	var run := func() -> void:
		got[0] = await box.choose("Ask Gus:", ["A", "B", "C"], 2)
	run.call()
	await wait_seconds(0.3)
	assert_eq((_last(&"choice")["info"] as Dictionary).get("best"), 2)
	await _key(KEY_2)
	await wait_seconds(0.3)
	assert_eq(got[0], 1, "key 2 picks the second option")


func test_choose_with_arrows_and_enter() -> void:
	var box := DialogueBox.new()
	add_node(box)
	var got := [-1]
	var run := func() -> void:
		got[0] = await box.choose("Tell Gus:", ["A", "B", "C"], 0)
	run.call()
	await wait_seconds(0.3)
	await tap_action(&"ui_down")
	await tap_action(&"ui_down")
	await tap_action(&"ui_accept")
	await wait_seconds(0.3)
	assert_eq(got[0], 1, "down, down from nothing selects the 2nd option")


func test_choice_solver_picks_best() -> void:
	var box := DialogueBox.new()
	add_node(box)
	var got := [-1]
	var run := func() -> void:
		got[0] = await box.choose("Q", ["A", "B", "C"], 2)
	run.call()
	await wait_seconds(0.3)
	(_last(&"choice")["solver"] as Callable).call()
	await wait_seconds(0.3)
	assert_eq(got[0], 2)


# ---------------------------------------------------------------- mini-games

func test_otoscopy_solver_finds_the_seed() -> void:
	var g := Otoscopy.new()
	add_node(g)
	var done := [false]
	var run := func() -> void:
		await g.run_find()
		done[0] = true
	run.call()
	await wait_frames(2)
	var b := _last(&"otoscopy_find")
	assert_false(b.is_empty(), "otoscopy_find beat")
	assert_eq((b["info"] as Dictionary).get("target"), "otoscope_seed")
	assert_true(Hoot.has_anchor("otoscope_seed"), "seed anchor registered")
	(b["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(done[0] and g.found, "found")
	await g.sneeze_out()
	assert_false(g.seed_visible, "seed sneezed out")


func test_otoscopy_keyboard_light_and_enter() -> void:
	var g := Otoscopy.new()
	add_node(g)
	var run := func() -> void:
		await g.run_find()
	run.call()
	await wait_frames(2)
	g.light = g.view_center + g.seed_offset
	await tap_action(&"ui_accept")
	assert_true(g.found, "Enter examines where the light is")


func test_evidence_wrong_then_solver() -> void:
	var e := Evidence.new()
	add_node(e)
	var done := [false]
	var run := func() -> void:
		await e.run(_results())
		done[0] = true
	run.call()
	await wait_frames(3)
	await _key(KEY_1)
	await tap_action(&"ui_accept")
	assert_false(e.solved, "low pitches are the wrong exhibit")
	assert_eq(e.attempts, 1)
	(_last(&"evidence_present")["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(done[0] and e.solved, "solver presents the high-pitch slope")
	assert_eq(e.attempts, 2)


func test_fitting_switch_with_key() -> void:
	var f := Fitting.new()
	add_node(f)
	var done := [false]
	var run := func() -> void:
		await f.run()
		done[0] = true
	run.call()
	await wait_frames(2)
	assert_false(_last(&"fitting_switch_on").is_empty(), "fitting beat")
	await tap_action(&"advance_dialogue")
	assert_true(done[0], "space flips the switch")


func test_reveal_runs_to_the_end() -> void:
	var r := Reveal.new()
	add_node(r)
	var scale := Engine.time_scale
	Engine.time_scale = 6.0
	await r.run(_results())
	Engine.time_scale = scale
	assert_true(Hoot.has_anchor("reveal_audiogram"))


# ---------------------------------------------------------------- overlays and screens

func test_hoot_bubble_shows_and_dismisses() -> void:
	var b: Node = (load("res://story/hoot_bubble.tscn") as PackedScene).instantiate()
	add_node(b)
	await wait_frames(1)
	Hoot.say("Red = Right!", Hoot.NORMAL, "", "", 0.0)
	await wait_frames(2)
	var panel: Control = b.get("_panel")
	assert_true(panel.visible, "bubble visible")
	Hoot.dismiss_current()
	await wait_seconds(0.3)
	assert_false(panel.visible, "bubble hidden after dismiss")


func test_pause_menu_open_close_and_key_style_label() -> void:
	var pm: Node = (load("res://story/pause_menu.tscn") as PackedScene).instantiate()
	add_node(pm)
	await wait_frames(1)
	assert_true(pm.is_in_group("pause_menu"))
	pm.call("open")
	assert_true(tree.paused and bool(pm.call("is_open")))
	var style_row: Dictionary = (pm.get("_rows") as Array)[0]
	var before := Game.get_key_style()
	assert_true(String((style_row["control"] as Button).text).contains("Up = LOUDER (default)") or String((style_row["control"] as Button).text).contains("Up = SOFTER (swapped)"))
	(style_row["control"] as Button).pressed.emit()
	assert_ne(Game.get_key_style(), before, "toggle swaps the key style")
	(style_row["control"] as Button).pressed.emit()
	assert_eq(Game.get_key_style(), before)
	pm.call("close")
	assert_false(tree.paused)


func test_daily_decibel_continue_beat() -> void:
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var summary := {"patient_id": "gus", "score": 88.0, "grade": "A", "accuracy": 0.9, "technique": 0.9, "efficiency": 0.8,
		"care": 1.0, "comfort": 3, "medals": {"history": "gold", "otoscopy": "silver"}, "coins_earned": 60, "coins_total": 60,
		"audiometry": _results()}
	var done := [false]
	var run := func() -> void:
		await paper.call("show_summary", summary)
		done[0] = true
	run.call()
	await wait_seconds(1.2)
	var b := _last(&"results_continue")
	assert_false(b.is_empty(), "results_continue beat")
	(b["solver"] as Callable).call()
	await wait_frames(2)
	assert_true(done[0])


func test_title_screen_beats() -> void:
	var t: Node = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(t)
	await wait_frames(3)
	var notice := _last(&"disclaimer_ok")
	if not notice.is_empty():
		(notice["solver"] as Callable).call()
		await wait_seconds(0.4)
	assert_false(_last(&"title_start").is_empty(), "title_start beat after the notice")
	t.queue_free()
	await wait_frames(2)


func test_voice_bank_is_quiet() -> void:
	var ceiling := pow(10.0, (Voice.VOICE_PEAK_DBFS + 0.5) / 20.0)
	for who: String in ["Gus", "Hoot", "Doris", "Gus|muffled", "Doris|muffled"]:
		var parts := who.split("|")
		var bank: Array = Voice.bank_for(parts[0], parts.size() > 1)
		assert_true(bank.size() > 0)
		for w: AudioStreamWAV in bank:
			var peak := 0.0
			var data := w.data
			for i in range(0, data.size(), 2):
				peak = maxf(peak, absf(data.decode_s16(i) / 32767.0))
			assert_true(peak <= ceiling, "%s syllable peak %.4f under %.1f dBFS" % [who, peak, Voice.VOICE_PEAK_DBFS])
