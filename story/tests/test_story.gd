extends TestCase
## Story (story/): dialogue box keys + solvers, mini-game solvers, Hoot bubble, pause menu,
## results paper, title beats, the voice synth's safety ceiling and Hoot's line length on Days 1-2.

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


## (polish) The first clear of Day 1: an UP NEXT! stamp, "Next: Day 2" is the big
## button and the advance key takes it; the patient is called by the short name.
func test_daily_decibel_new_day_stamp_and_short_name() -> void:
	Game.reset_save()
	(Game.progress["chapters_done"] as Array).append("gus")
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var summary := {"patient_id": "gus", "score": 88.0, "grade": "A", "accuracy": 0.9, "technique": 0.9, "efficiency": 0.8,
		"care": 1.0, "comfort": 3, "medals": {}, "coins_earned": 60, "coins_total": 60, "audiometry": _results(),
		"patient_name": "Grandpa Gus", "patient_short": "Gus", "chapter_id": "gus", "day": 1,
		"newly_unlocked": [], "first_clear": true, "next_chapter_id": "bonnie", "suggested_next": "bonnie"}
	var out := [""]
	var run := func() -> void:
		out[0] = await paper.call("show_summary", summary)
	run.call()
	await wait_seconds(1.6)
	var stamp: Control = paper.get("_unlock_stamp")
	assert_true(stamp != null and stamp.visible, "the unlock stamp shows")
	var texts: Array[String] = []
	var next_btn: Button = null
	for b: Node in paper.find_children("*", "Button", true, false):
		texts.append((b as Button).text)
		if (b as Button).text.begins_with("Next: Day 2"):
			next_btn = b
	assert_true(next_btn != null, "Next: Day 2 button: %s" % str(texts))
	assert_eq(next_btn.theme_type_variation, &"AccentButton", "Next is the big button")
	assert_true(texts.any(func(t: String) -> bool: return t.begins_with("Play Gus again")), "short name: %s" % str(texts))
	await tap_action(&"advance_dialogue")
	await wait_frames(2)
	assert_eq(String(out[0]), "next", "the advance key goes on to Day 2")


## (polish) A replay (not a first clear): no stamp, Back to the title stays the big button, and
## Next: Day 2 is still offered (every day is open).
func test_daily_decibel_replay_has_no_stamp() -> void:
	Game.reset_save()
	(Game.progress["chapters_done"] as Array).append("gus")
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_node(paper)
	var summary := {"patient_id": "gus", "score": 88.0, "grade": "A", "accuracy": 0.9, "technique": 0.9, "efficiency": 0.8,
		"care": 1.0, "comfort": 3, "medals": {}, "coins_earned": 60, "coins_total": 60, "audiometry": _results(),
		"patient_name": "Grandpa Gus", "patient_short": "Gus", "chapter_id": "gus", "day": 1,
		"newly_unlocked": [], "first_clear": false, "next_chapter_id": "bonnie", "suggested_next": "bonnie"}
	var run := func() -> void:
		await paper.call("show_summary", summary)
	run.call()
	await wait_seconds(1.6)
	assert_true(paper.get("_unlock_stamp") == null, "no stamp on a replay")
	var accent := ""
	var has_next := false
	for b: Node in paper.find_children("*", "Button", true, false):
		if (b as Button).theme_type_variation == &"AccentButton":
			accent = (b as Button).text
		if (b as Button).text.begins_with("Next: Day 2"):
			has_next = true
	assert_true(accent.begins_with("Back to the title"), accent)
	assert_true(has_next, "Next: Day 2 is offered")


## A paper that fits the window settles at exactly scale 1 (Days 1, 2 and 6-9 unchanged); one
## too tall for it is scaled down until its tilted box fits with a margin.
func test_daily_decibel_fit_scale() -> void:
	var paper_script := load("res://story/daily_decibel.gd") as GDScript
	var window := Vector2(1280, 720)
	assert_eq(float(paper_script.call("fit_scale", Vector2(1178, 688), window)), 1.0, "a tall paper that fits")
	assert_eq(float(paper_script.call("fit_scale", Vector2(1060, 595), window)), 1.0, "a short paper")
	var tilt := absf(float(paper_script.get("TILT")))
	for sz: Vector2 in [Vector2(1178, 710), Vector2(1212, 836)]:
		var fit := float(paper_script.call("fit_scale", sz, window))
		assert_true(fit < 1.0, "scaled down: %s" % sz)
		var box := (sz.y * cos(tilt) + sz.x * sin(tilt)) * fit
		assert_near(box, window.y - float(paper_script.get("FIT_MARGIN")), 0.01, "fits with the margin: %s" % sz)


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
	for who: String in ["Gus", "Hoot", "Doris", "Mike", "Gus|muffled", "Doris|muffled"]:
		var parts := who.split("|")
		var bank: Array = Voice.bank_for(parts[0], parts.size() > 1)
		assert_true(bank.size() > 0)
		for w: AudioStreamWAV in bank:
			var peak := 0.0
			var data := w.data
			for i in range(0, data.size(), 2):
				peak = maxf(peak, absf(data.decode_s16(i) / 32767.0))
			assert_true(peak <= ceiling, "%s syllable peak %.4f under %.1f dBFS" % [who, peak, Voice.VOICE_PEAK_DBFS])


# ---------------------------------------------------------------- (v3) Day 2

## Every wrong spot is a slip with its own gag; the keyboard walks the spots and Enter places.
func test_bone_placement_gags_and_keyboard() -> void:
	Game.begin_visit("bonnie")
	var g: Control = (load("res://story/games/bone_placement.gd") as GDScript).new()
	add_node(g)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await wait_frames(2)
	var run := func() -> void:
		await g.call("run")
	run.call()
	await wait_frames(2)
	var slips := 0
	for spot: String in ["forehead", "top", "pinna"]:
		g.call("_place", spot)
		slips += 1
		assert_eq(String(g.get("_gag")), spot, "%s shows its gag" % spot)
		await wait_seconds(1.25)
	assert_eq(int(g.get("mistakes")), slips)
	assert_eq(g.get("wrong_spots"), ["forehead", "top", "pinna"])
	# she faces right, so the Left arrow walks the spots front (nose) to back; the mastoid is second to last
	var zones: Array = g.get("ZONES")
	var target := -1
	for i in zones.size():
		if String(zones[i][0]) == "mastoid":
			target = i
	for i in target + 1:
		await tap_action(&"ui_left")
	await tap_action(&"ui_accept")
	assert_true(bool(g.get("placed")), "Enter places it on the highlighted mastoid")
	Hoot.clear()


## The board shrinks for the choices, shows the type badge and the Carhart callout, and stamps.
func test_day2_board_compact_type_carhart_stamp() -> void:
	var b: Control = (load("res://story/games/day2_board.gd") as GDScript).new()
	add_node(b)
	await wait_frames(2)
	var scale := Engine.time_scale
	Engine.time_scale = 6.0
	b.call("set_compact", true)
	await wait_seconds(0.5)
	var card: Control = b.get("_card")
	assert_true(card.get_global_rect().size.y < 340.0, "compact board fits above the choices")
	assert_true(card.get_global_rect().position.y < 30.0, "and sits at the top")
	b.call("show_type", "Conductive loss")
	b.call("show_carhart")
	await wait_frames(3)
	assert_eq(String(b.get("_type_text")), "CONDUCTIVE LOSS")
	b.call("set_compact", false)
	await wait_seconds(0.5)
	Engine.time_scale = scale
	assert_eq(card.scale, Vector2.ONE, "full size again for the stamp")
	var run := func() -> void:
		await b.call("run_stamp")
	run.call()
	await wait_frames(2)
	await tap_action(&"ui_accept")
	assert_true(bool(b.get("stamped")), "Enter stamps")
	Hoot.clear()


## Day 2's otoscopy is a look, not a game: no beat, the seed stays hidden.
func test_otoscopy_show_clear_needs_no_input() -> void:
	var g := Otoscopy.new()
	add_node(g)
	await wait_frames(2)
	await g.show_clear("right", "Bonnie's RIGHT ear: clear canal, shiny eardrum.")
	assert_false(g.seed_visible, "nothing to find")
	assert_true(_last(&"otoscopy_find").is_empty(), "no beat")


## Title Days: cards for each day, Left/Right moves between them, the label meta stays the contract.
func test_title_day_cards_keyboard() -> void:
	Game.reset_save()
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	title.call("_on_notice_ok")
	await wait_seconds(0.4)
	title.call("_on_days")
	await wait_frames(2)
	var cards: Array = []
	for b: Button in title.get("_day_buttons"):
		if b.has_meta("chapter"):
			cards.append(b)
	assert_eq(cards.size(), Game.chapters().size(), "one card per day")
	assert_true(bool((cards[0] as Button).get_meta("hl", false)), "Day 1 (UP NEXT) highlighted first")
	assert_false((cards[1] as Button).has_meta("locked"), "Day 2 is open on a fresh save (no locks)")
	await tap_action(&"ui_right")
	assert_eq(int(title.get("_hl")), 1, "Right moves to Day 2")
	assert_true(bool((cards[1] as Button).get_meta("hl", false)))
	assert_eq((cards[1] as Button).text, "", "cards keep their own labels")
	await tap_action(&"ui_down")
	var cols := int(title.get("_days_cols"))
	var below := 1 + cols if 1 + cols < cards.size() else (cards.size() - 1 if cards.size() > cols else cards.size())
	assert_eq(int(title.get("_hl")), below, "Down: the card below Day 2, or Back from the last row")
	await tap_action(&"ui_up")
	await tap_action(&"ui_cancel")
	assert_eq(title.get("_state"), &"menu", "Esc goes back")
	title.call("_on_days")
	await wait_frames(2)
	await tap_action(&"ui_right")
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	await tap_action(&"ui_accept")
	Events.goto_scene.disconnect(gcb)
	assert_eq(went, ["res://story/level_bonnie.tscn"], "Enter on Day 2 starts it")


## (Speech) Mike's Day 3 card has his face and his tint from his chapter entry.
func test_title_day3_card_face() -> void:
	var ts: Script = load("res://story/title_screen.gd")
	var mike := Game.chapter("mike")
	assert_eq(ts.call("card_face", mike), "Mike")
	assert_eq(ts.call("card_tint", mike), Color("#fff0a6"))


## Hoot's lines on Days 1 and 2 stay at 18 words or fewer (a reader's count; "%s" is one word).
func test_day1_and_day2_hoot_lines_are_short() -> void:
	var re := RegEx.create_from_string("_say\\(\"Hoot\", \"((?:[^\"\\\\]|\\\\.)*)\"")
	var letters := RegEx.create_from_string("[A-Za-z0-9]")
	for path: String in ["res://story/level_gus.gd", "res://story/level_bonnie.gd"]:
		var found := 0
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			found += 1
			var words := 0
			for w: String in m.get_string(1).split(" ", false):
				if letters.search(w) != null:
					words += 1
			assert_true(words <= 18, "%s, %d words: %s" % [path.get_file(), words, m.get_string(1)])
		assert_true(found >= 20, "found Hoot's lines in %s (%d)" % [path.get_file(), found])
