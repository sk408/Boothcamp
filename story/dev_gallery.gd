extends Node
## Dev gallery (developer tool, not part of the game flow): shows every story screen in turn
## with made-up results, solving each beat itself, and asks for a screenshot at each step.
##   xvfb-run ... godot --path . -- --scene=res://story/dev_gallery.tscn --shots=/abs/dir
## Results are fabricated from Gus's profile (a sample audiogram); no audiometry runs here.

const Hud := preload("res://story/hud.gd")
const Otoscopy := preload("res://story/games/otoscopy.gd")
const Earphones := preload("res://story/games/earphones.gd")
const Reveal := preload("res://story/games/reveal.gd")
const Evidence := preload("res://story/games/evidence.gd")
const Fitting := preload("res://story/games/fitting.gd")

var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var _auto_solve := true


func _ready() -> void:
	Game.begin_visit("gus")
	clinic = (load("res://world/clinic.tscn") as PackedScene).instantiate()
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.awaiting_input.connect(_on_awaiting)


func _on_awaiting(beat: StringName, _info: Dictionary, solver: Callable) -> void:
	if not _auto_solve:
		return
	await get_tree().create_timer(1.0).timeout
	if beat == &"dialogue" or beat == &"choice":
		await _shot("beat_" + String(beat))
		await get_tree().create_timer(0.1).timeout
	if solver.is_valid():
		solver.call()


func _shot(n: String) -> void:
	Events.screenshot_requested.emit("gallery_" + n)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func demo_start() -> void:
	Events.phase_changed.emit(&"history", {})
	hud.call("set_step", &"chat")
	clinic.call("walk_to", &"desk", 0.1)
	await clinic.call("focus_camera", &"desk", 0.0)
	hud.call("add_clue", "Hardest: birds, whistles, kids, 'dishes'")
	hud.call("add_clue", "Pain, drainage, dizziness, sudden change: NONE.\nAny one = see a doctor first!", "flag")
	Hoot.say("Red = Right. Blue = Left. Pop each cup onto the matching ear.", Hoot.NORMAL, "")
	await dialogue.say("Gus", "Everyone MUMBLES these days! Especially Doris. Especially when she says something about... fishes?")
	await dialogue.choose("Ask Gus a question:", ["Is it harder to follow talk in noisy places?", "Is your walker turbocharged?", "Which sounds are hardest to hear?"], 2)
	# otoscopy
	Events.phase_changed.emit(&"otoscopy", {})
	await clinic.call("focus_camera", &"otoscope", 0.3)
	var o := Otoscopy.new()
	hud.call("add_game", o)
	_auto_solve = false
	var finder := func() -> void:
		await o.run_find()
	finder.call()
	await _wait(0.6)
	o.light = o.view_center + Vector2(-80, 30)
	await _wait(0.3)
	await _shot("otoscopy_search")
	o.call("_examine", o.view_center + Vector2(-6, 6))
	await _wait(0.4)
	await _shot("otoscopy_eardrum")
	o.call("_solve")
	await _wait(0.5)
	await _shot("otoscopy_found")
	await o.sneeze_out()
	await _shot("otoscopy_sneeze")
	var lefty := func() -> void:
		await o.show_left_clear()
	lefty.call()
	await _wait(0.5)
	await _shot("otoscopy_left")
	await _wait(1.5)
	o.queue_free()
	# earphones
	Events.phase_changed.emit(&"earphones", {})
	await clinic.call("sit")
	await clinic.call("focus_camera", &"face", 0.3)
	var e := Earphones.new()
	e.setup(clinic)
	hud.call("add_game", e)
	var placer := func() -> void:
		await e.run()
	placer.call()
	await _wait(0.6)
	await _shot("earphones_start")
	e.call("_drop", "right", (e.get("_targets")["left"] as Control).get_global_rect().get_center())
	await _wait(0.4)
	await _shot("earphones_wrong")
	await _wait(0.8)
	e.call("_solve")
	await _wait(0.5)
	await _shot("earphones_placed")
	clinic.call("put_on_earphones", true)
	e.queue_free()
	await _wait(0.8)
	await _shot("earphones_on")
	_auto_solve = true
	# reveal
	var results := _fake_results()
	Events.phase_changed.emit(&"reveal", {})
	clinic.call("take_off_earphones")
	var r := Reveal.new()
	hud.call("add_game", r)
	var rev := func() -> void:
		await r.run(results)
	rev.call()
	await _wait(1.3)
	await _shot("reveal_hop")
	await _wait(1.9)
	await _shot("reveal_ski")
	var waited := 0.0
	while waited < 8.0 and not ((r.get("_title") as Label) != null and (r.get("_title") as Label).visible):
		await _wait(0.2)
		waited += 0.2
	await _wait(0.9)
	await _shot("reveal_title")
	r.queue_free()
	# evidence
	Events.phase_changed.emit(&"evidence", {})
	var ev := Evidence.new()
	hud.call("add_game", ev)
	_auto_solve = false
	var pres := func() -> void:
		await ev.run(results)
	pres.call()
	await _wait(0.5)
	ev.call("_select", 1)
	await _wait(0.3)
	await _shot("evidence_select")
	ev.call("_present", 0)
	await _wait(0.3)
	await _shot("evidence_objection")
	await _wait(1.5)
	ev.call("_present", 1)
	await _wait(0.4)
	await _shot("evidence_solved")
	await _wait(1.0)
	ev.queue_free()
	_auto_solve = true
	# fitting
	Events.phase_changed.emit(&"fitting", {})
	await clinic.call("walk_to", &"desk", 0.5)
	clinic.call("set_world_saturation", 0.0)
	clinic.call("focus_camera", &"fitting", 0.0)
	await clinic.call("doris_enter")
	clinic.call("gus_look", &"doris")
	var f := Fitting.new()
	hud.call("add_game", f)
	_auto_solve = false
	var sw := func() -> void:
		await f.run()
	sw.call()
	await _wait(0.6)
	await _shot("fitting_switch")
	f.call("_switch_on")
	clinic.call("gus_look", &"camera")
	clinic.call("put_on_hearing_aids")
	var t := create_tween()
	t.tween_method(func(v: float) -> void: clinic.call("set_world_saturation", v), 0.0, 1.0, 2.0)
	await _wait(1.0)
	await _shot("fitting_wave")
	await t.finished
	Events.patient_reaction.emit(&"cheer", {})
	await _wait(0.4)
	await _shot("fitting_colour")
	f.queue_free()
	_auto_solve = true
	# pause menu
	var pm := get_tree().get_first_node_in_group("pause_menu")
	if pm:
		pm.call("open")
		await get_tree().process_frame
		await get_tree().process_frame
		await _shot("pause_menu")
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		pm.call("close")
	# results
	Events.phase_changed.emit(&"results", {})
	Game.set_audiometry_results(results)
	Game.record_medal("history", "gold")
	Game.record_medal("otoscopy", "silver")
	Game.record_medal("earphones", "bronze")
	Game.record_medal("evidence", "gold")
	var summary := Game.finish_visit()
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_child(paper)
	await paper.call("show_summary", summary)
	await _wait(0.3)
	get_tree().quit(0)


## A plausible §5.1 results dictionary built from Gus's profile (for this gallery only).
func _fake_results() -> Dictionary:
	var p := Game.load_patient("gus") as PatientProfile
	var ears := {}
	var strokes := [5, 7, 9, 6, 8, 12, 7, 6]
	for ear: String in ["right", "left"]:
		var freqs := {}
		var i := 0
		for f: int in ClinicRules.ROUTINE_FREQS:   # (E1)
			var db := p.get_threshold(ear, f)
			var st: int = strokes[i % strokes.size()]
			freqs[f] = {"ear": ear, "freq": f, "stored_db": db, "true_db": db, "error_db": 0.0, "no_response": false,
				"strokes": st, "par": 7, "golf": ClinicRules.golf_name(st, 7), "accuracy": 1.0, "errors": [],
				"technique_ok": true, "retest": false, "masked": false, "order_index": i}
			i += 1
		var th := {}
		for f: int in freqs:
			th[f] = int(freqs[f]["stored_db"])
		ears[ear] = {"freqs": freqs, "complete": true, "retest_1k": {}, "order": [], "strokes": 50, "par": 49,
			"accuracy": 1.0, "shape": ClinicRules.classify_shape(th), "pta": ClinicRules.pta(th), "coached": ear == "right"}
	return {"patient_id": "gus", "patient_name": "Grandpa Gus", "ears": ears, "technique_errors": [],
		"presentations": 100, "false_alarms": 1, "max_combo": 23, "accuracy": 0.95, "technique": 0.9,
		"efficiency": 0.8, "score": 90.0, "grade": "A", "duration_s": 200.0}
