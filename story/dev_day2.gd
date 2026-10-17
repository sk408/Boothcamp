extends Node
## Dev gallery for Day 2 (developer tool, not part of the game flow): the oscillator placement
## game (with a unicorn slip), then Bonnie's board (reveal, toll bridge, referral stamp), with a
## screenshot at each step. Results are made up from Bonnie's profile; no audiometry runs here.
##   tools/scene_shot.sh res://story/dev_day2.tscn /abs/dir "1" 30   (shots come from the script)

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
	clinic.call("focus_camera", &"ear_right", 0.0)
	var g := BonePlacement.new()
	hud.call("add_game", g)
	g.call_deferred("run")
	await _wait(1.0)
	await _shot("dev_day2_placement")
	g.call("_place", "top")
	await _wait(0.5)
	await _shot("dev_day2_unicorn")
	await _wait(1.2)
	g.call("_place", "mastoid")
	await _wait(0.6)
	await _shot("dev_day2_placed")
	g.queue_free()
	clinic.call("put_on_bone_oscillator", "right")
	clinic.call("put_on_masking_phone", "left")
	await _wait(0.6)
	await _shot("dev_day2_oscillator_3d")
	var b := Day2Board.new()
	hud.call("add_game", b)
	await b.run_reveal(_results())
	await _shot("dev_day2_reveal")
	await b.show_gap()
	await _shot("dev_day2_bridge")
	b.call_deferred("run_stamp")
	await _wait(0.8)
	await _shot("dev_day2_stamp_button")
	b.call("_stamp")
	await _wait(0.8)
	await _shot("dev_day2_stamped")


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
