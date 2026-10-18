extends Node
## Dev gallery for Day 3 (developer tool, not part of the game flow): Mike in the clinic, his
## board (word cards, the dropped windmill, OBJECTION!, the referral stamp), the Day 3 paper and
## the title's Days row, with a screenshot at each step. Results are made up from Mike's profile
## (Hoot's textbook run); no audiometry runs here.
##   tools/scene_shot.sh res://story/dev_day3.tscn /abs/dir "1" 40   (shots come from the script)
## Add --part=world, --part=board, --part=paper or --part=title to shoot one part (default: all).

const Hud := preload("res://story/hud.gd")
const MikeBoard := preload("res://story/games/mike_board.gd")
const LevelMike := preload("res://story/level_mike.gd")

var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox


func _ready() -> void:
	Game.begin_visit("mike")
	clinic = (load("res://world/clinic.tscn") as PackedScene).instantiate()
	clinic.set("patient_id", "mike")
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", LevelMike.STEPS, LevelMike.STEP_LABELS, "MIKE LENDERS' VISIT", {&"srt_r": Palette.RIGHT_RED, &"srt_l": Palette.LEFT_BLUE})
	hud.call("set_step", &"words")
	dialogue = DialogueBox.new()
	add_child(dialogue)


func demo_start() -> void:
	var part := Game.cli_value("part", "all")
	if part in ["all", "world"]:
		await _world()
	if part in ["all", "board"]:
		await _board()
	if part in ["all", "paper"]:
		await _paper()
	if part in ["all", "title"]:
		await _title()


func _world() -> void:
	clinic.call("focus_camera", &"door", 0.0)
	await _wait(0.3)
	await clinic.call("walk_in")
	clinic.call("focus_camera", &"desk", 0.0)
	await _wait(0.3)
	await _shot("dev_day3_w_desk")
	clinic.call("focus_camera", &"face", 0.0)
	Events.dialogue_line.emit("Mike", "I can't hear ANYTHING since the forklift beeped at work.")
	await _wait(0.5)
	await _shot("dev_day3_w_face")
	await clinic.call("sit")
	clinic.call("put_on_earphones", true)
	clinic.call("hold_response_button", false)
	await clinic.call("focus_camera", &"face", 0.0)
	await _wait(0.6)
	await _shot("dev_day3_w_seated")
	clinic.call("focus_camera", &"desk", 0.0)
	await _wait(0.3)
	await _shot("dev_day3_w_clipboard")
	clinic.call("take_off_earphones")
	clinic.call("focus_camera", &"door", 0.0)
	await clinic.call("walk_out")
	await clinic.call("peek_in")
	await _wait(0.2)
	await _shot("dev_day3_w_glazed")
	await clinic.call("walk_out")


func _board() -> void:
	var b := MikeBoard.new()
	hud.call("add_game", b)
	var items: Array[Dictionary] = []
	for it: Dictionary in SpeechMaterial.items(LevelMike.LIST_ID):
		if items.size() < LevelMike.FAMILIAR_WORDS:
			items.append(it)
	await b.run_cards(items, SpeechMaterial.title(LevelMike.LIST_ID))
	b.read_along(0, 5, 1.0)
	await _wait(0.5)
	await _shot("dev_day3_cards_reading")
	await _wait(0.8)
	b.stumble(LevelMike.UNKNOWN_WORD)
	b.call_deferred("run_drop", LevelMike.UNKNOWN_WORD)
	await _wait(0.4)
	await _shot("dev_day3_cards_stumble")
	b.call("_try_drop", "cupcake")
	await _wait(0.5)
	await _shot("dev_day3_cards_slip")
	b.call("_try_drop", LevelMike.UNKNOWN_WORD)
	await _wait(0.5)
	await _shot("dev_day3_cards_dropped")
	await _wait(0.6)
	var lv: Node = LevelMike.new()
	lv.set("results", _merged())
	var cards: Array = lv.call("objection_cards")
	lv.free()
	b.show_objection(cards[0], cards[1])
	b.call_deferred("run_objection")
	await _wait(0.6)
	await _shot("dev_day3_objection_board")
	b.call("_select", 0)
	b.call("_present", 0)
	await _wait(0.5)
	await _shot("dev_day3_objection_wrong")
	b.call("_present", 1)
	await _wait(0.12)
	await _shot("dev_day3_objection_slam")
	await _wait(2.2)
	await _shot("dev_day3_objection_settled")
	b.set_referral_mode(true)
	var opts: Array[String] = ["Fit strong hearing aids today.", "Re-instruct, retest, refer for objective tests.", "Call him a fibber."]
	dialogue.call_deferred("choose", "What's next for Mike?", opts, 1)
	await _wait(0.8)
	await _shot("dev_day3_referral_choice")
	dialogue.call("_pick", 1)
	await _wait(0.4)
	b.call_deferred("run_stamp")
	await _wait(0.8)
	await _shot("dev_day3_stamp_button")
	b.call("_stamp")
	await _wait(0.8)
	await _shot("dev_day3_stamped")
	b.queue_free()


func _paper() -> void:
	var res := _merged()
	var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
	add_child(paper)
	var summary := {"patient_id": "mike", "score": 93.0, "grade": "A", "accuracy": 0.95, "technique": 0.97, "efficiency": 0.86,
		"care": 1.0, "comfort": 3, "medals": {"history": "gold", "instructions": "silver", "familiarize": "gold", "evidence": "gold", "referral": "bronze"},
		"coins_earned": 76, "coins_total": 140, "audiometry": res, "chapter_id": "mike", "day": 3, "patient_name": "Mike Lenders",
		"next_chapter_id": ""}
	paper.call_deferred("show_summary", summary)
	await _wait(2.5)
	await _shot("dev_day3_paper")
	paper.queue_free()


## The title's Days row with every day open.
func _title() -> void:
	clinic.queue_free()
	hud.queue_free()
	var keep_settings: Dictionary = Game.settings.duplicate(true)
	var keep_progress: Dictionary = Game.progress.duplicate(true)
	Game.settings["unlock_all_days"] = true
	Game.progress["patients"] = {"gus": {"best_score": 91.0, "best_grade": "A", "last_grade": "A", "plays": 2},
		"bonnie": {"best_score": 84.0, "best_grade": "B", "last_grade": "B", "plays": 1}}
	Game.progress["chapters_done"] = ["gus", "bonnie"]
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_child(title)
	await _wait(0.6)
	title.call("_on_notice_ok")
	await _wait(0.8)
	title.call("_on_days")
	await _wait(0.8)
	title.call("_set_hl", 2, false)
	await _wait(0.5)
	await _shot("dev_day3_title_days")
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


## Mike's tones (all Hoot's) plus two textbook SRTs, merged (§9.5).
func _merged() -> Dictionary:
	var p := Game.load_patient("mike") as PatientProfile
	var tones := SpeechSession.tone_results_from(p)
	var s := SpeechSession.new(p, 3)
	s.configure({"test": "srt", "tones": tones, "exclude": [LevelMike.UNKNOWN_WORD]})
	LevelMike.hoot_runs_ear(s, "right")
	LevelMike.hoot_runs_ear(s, "left")
	return SpeechSession.merge_results(tones, s.build_results())
