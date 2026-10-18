extends Node
## Dev gallery for Day 2 (developer tool, not part of the game flow): the oscillator placement
## game (with a unicorn slip), then Bonnie's board (reveal, toll bridge, referral stamp), with a
## screenshot at each step. Results are made up from Bonnie's profile; no audiometry runs here.
##   tools/scene_shot.sh res://story/dev_day2.tscn /abs/dir "1" 30   (shots come from the script)
## Add --part=world (the 3D extras: basket, oscillator, ghost, masking, payoff), --part=placement or
## --part=board to shoot only one part (default: all).

const Hud := preload("res://story/hud.gd")
const BonePlacement := preload("res://story/games/bone_placement.gd")
const Day2Board := preload("res://story/games/day2_board.gd")

var clinic: Node3D
var hud: CanvasLayer


func _ready() -> void:
	Game.begin_visit("bonnie")
	clinic = (load("res://world/clinic.tscn") as PackedScene).instantiate()
	clinic.set("patient_id", "bonnie")
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	var lv: Script = load("res://story/level_bonnie.gd")
	hud.call("set_steps", lv.get("STEPS"), lv.get("STEP_LABELS"), "BONNIE BUNSWORTH'S VISIT")
	hud.call("set_step", &"bone")


func demo_start() -> void:
	var part := Game.cli_value("part", "all")
	if part in ["all", "world"]:
		await _world()
	if part in ["all", "placement"]:
		await _placement()
	if part in ["all", "board"]:
		await _board()
	if part == "title":
		await _title()


## The 3D extras, with the booth window shown picture-in-picture.
func _world() -> void:
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.3)
	await clinic.call("walk_in")
	clinic.call("focus_camera", &"desk", 0.0)
	await _wait(0.3)
	await _shot("dev_day2_w_basket")
	clinic.call("put_down_basket")
	Events.dialogue_line.emit("Bonnie", "Croissants for the waiting room!")
	await _wait(0.8)
	await _shot("dev_day2_w_desk")
	await clinic.call("sit")
	clinic.call("put_on_bone_oscillator", "right")
	clinic.call("put_on_masking_phone", "left")
	await clinic.call("focus_camera", &"face", 0.0)
	await _wait(0.6)
	await _shot("dev_day2_w_face")
	clinic.call("focus_camera", &"ear_right", 0.0)
	await _wait(0.3)
	await _shot("dev_day2_w_ear_right")
	clinic.call("focus_camera", &"ear_left", 0.0)
	await _wait(0.3)
	await _shot("dev_day2_w_ear_left")
	# the booth window, big
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var tr := TextureRect.new()
	tr.texture = clinic.call("get_booth_texture")
	tr.position = Vector2(140, 40)
	tr.size = Vector2(1000, 625)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.add_child(tr)
	clinic.call("set_booth_view_active", true)
	Events.transducer_changed.emit(&"bone", "right")
	Events.tone_started.emit("right", 1000, 10)
	await _wait(0.4)
	await _shot("dev_day2_w_buzz")
	Events.tone_stopped.emit("right", 1000, 10, 1.0)
	Events.patient_reaction.emit(&"heard", {"ear": "right"})
	Events.patient_reaction.emit(&"cross_heard", {"ear": "right", "via": "left", "db": 5, "masked": false})
	await _wait(0.12)
	await _shot("dev_day2_w_ghost_a")
	await _wait(0.33)
	await _shot("dev_day2_w_ghost_b")
	await _wait(0.25)
	await _shot("dev_day2_w_ghost_c")
	await _wait(0.6)
	await _shot("dev_day2_w_ghost_d")
	await _wait(0.8)
	Events.masker_changed.emit("left", 1000, 25, true)
	await _wait(0.45)
	await _shot("dev_day2_w_bust_a")
	await _wait(0.4)
	await _shot("dev_day2_w_bust_b")
	await _wait(1.0)
	await _shot("dev_day2_w_shh")
	Events.patient_reaction.emit(&"tickle", {"ear": "right", "db": 35})
	await _wait(0.25)
	await _shot("dev_day2_w_tickle")
	await _wait(1.2)
	Events.patient_reaction.emit(&"overmasked", {"ear": "right", "masker_ear": "left", "mask_db": 70})
	await _wait(0.3)
	await _shot("dev_day2_w_overmasked")
	Events.masker_changed.emit("left", 1000, 0, false)
	layer.queue_free()
	clinic.call("set_booth_view_active", false)
	await _wait(1.5)
	clinic.call("take_off_bone_oscillator")
	await clinic.call("walk_to", &"desk", 1.5)
	clinic.call("focus_camera", &"desk", 0.0)
	clinic.call("give_croissant")
	await _wait(0.45)
	await _shot("dev_day2_w_croissant")
	await _wait(1.0)
	clinic.call("walk_out")
	await _wait(1.6)
	await _shot("dev_day2_w_wave_out")
	await _wait(2.5)


func _placement() -> void:
	clinic.call("focus_camera", &"ear_right", 0.0)
	var g := BonePlacement.new()
	hud.call("add_game", g)
	g.call_deferred("run")
	await _wait(1.0)
	await _shot("dev_day2_placement")
	for spot: String in ["forehead", "top", "pinna", "nose"]:
		g.call("_place", spot)
		await _wait(0.45)
		await _shot("dev_day2_slip_" + spot)
		await _wait(1.6)
	g.call("_place", "mastoid")
	await _wait(0.6)
	await _shot("dev_day2_placed")
	g.queue_free()
	clinic.call("put_on_bone_oscillator", "right")
	clinic.call("put_on_masking_phone", "left")
	await _wait(0.6)
	await _shot("dev_day2_oscillator_3d")
	clinic.call("take_off_bone_oscillator")


func _board() -> void:
	var b := Day2Board.new()
	hud.call("add_game", b)
	await b.run_reveal(_results())
	await _shot("dev_day2_reveal")
	await b.show_gap()
	await _wait(0.6)
	await _shot("dev_day2_bridge")
	b.show_carhart()
	await _wait(1.0)
	await _shot("dev_day2_carhart")
	b.set_compact(true)
	await _wait(0.8)
	await _shot("dev_day2_compact")
	b.show_type("CONDUCTIVE")
	await _wait(0.8)
	await _shot("dev_day2_type")
	b.set_compact(false)
	await _wait(0.6)
	b.call_deferred("run_stamp")
	await _wait(0.8)
	await _shot("dev_day2_stamp_button")
	b.call("_stamp")
	await _wait(0.8)
	await _shot("dev_day2_stamped")


## The title's day picker: every day open; a fresh save suggests Day 1, then Day 2 is UP NEXT
## with a best grade on Day 1.
func _title() -> void:
	clinic.queue_free()
	hud.queue_free()
	var keep_settings: Dictionary = Game.settings.duplicate(true)
	var keep_progress: Dictionary = Game.progress.duplicate(true)
	Game.progress["patients"] = {}
	Game.progress["chapters_done"] = []
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_child(title)
	await _wait(0.6)
	title.call("_on_notice_ok")
	await _wait(0.8)
	title.call("_on_days")
	await _wait(0.8)
	await _shot("dev_day2_title_days_fresh")
	Game.progress["patients"] = {"gus": {"best_score": 91.0, "best_grade": "A", "last_grade": "A", "plays": 2}}
	Game.progress["chapters_done"] = ["gus"]
	title.call("_refresh_days")
	title.call("_set_hl", 1, false)
	await _wait(0.6)
	await _shot("dev_day2_title_days_open")
	Game.settings = keep_settings
	Game.progress = keep_progress


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## The service captures the NEXT drawn frame, so wait for that frame before changing anything.
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	Events.screenshot_requested.emit(n)
	await RenderingServer.frame_post_draw
	await get_tree().process_frame


func _sheet(p: PatientProfile, ear: String, freqs: Array, bone: bool, bump: int = 0) -> Dictionary:
	var out := {}
	for f: int in freqs:
		var t := p.get_bc_threshold(ear, f) if bone else p.get_threshold(ear, f)
		out[f] = {"stored_db": t + bump, "true_db": t, "no_response": false}
	return out


func _results() -> Dictionary:
	var p := Game.load_patient("bonnie") as PatientProfile
	var ac := [250, 500, 1000, 2000, 4000, 8000]
	var right := {"freqs": _sheet(p, "right", ac, false), "ac_masked": _sheet(p, "right", [250, 500, 1000, 2000], false),
		"bc": {}, "bc_masked": _sheet(p, "right", [500, 1000, 2000, 4000], true)}
	var unm := {}
	for f: int in [500, 1000, 2000, 4000]:
		unm[f] = {"stored_db": p.get_bc_threshold("left", f), "true_db": p.get_bc_threshold("left", f), "no_response": false}
	right["bc"] = unm
	var res := {"patient_id": "bonnie", "ears": {"right": right, "left": {"freqs": _sheet(p, "left", ac, false)}}}
	var thr := ClinicRules.best_thresholds(res, "right", false)
	var bone := ClinicRules.best_thresholds(res, "right", true)
	right["hearing_type"] = ClinicRules.hearing_type(thr, bone)
	right["carhart_notch"] = ClinicRules.has_carhart_notch(ClinicRules.sheet_thresholds(res, "right", &"bc_masked"))
	return res
