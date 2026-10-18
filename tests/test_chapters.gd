extends TestCase
## v3: chapters (days), unlocks, the save fields behind them, and the Chapter 2 input actions.

var _saved_path := ""
var _saved_settings := {}
var _saved_progress := {}
var _saved_cli := {}


func before_each() -> void:
	_saved_path = Game.save_path
	_saved_settings = Game.settings.duplicate(true)
	_saved_progress = Game.progress.duplicate(true)
	_saved_cli = Game.cli.duplicate(true)
	Game.save_path = "user://test_chapters_save.json"
	Game.cli.erase("day")
	Game.cli.erase("chapter")
	Game.cli.erase("unlock-all")


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_chapters_save.json"))
	Game.save_path = _saved_path
	Game.settings = _saved_settings
	Game.progress = _saved_progress
	Game.cli = _saved_cli
	Game.apply_settings()


func test_registry() -> void:
	assert_eq(Game.chapters().size(), 2)
	var d1 := Game.chapter_for_day(1)
	var d2 := Game.chapter_for_day(2)
	assert_eq(d1["id"], "gus")
	assert_eq(d2["id"], "bonnie")
	assert_eq(d1["title"], "Day 1: Grandpa Gus")
	assert_eq(d2["title"], "Day 2: Bonnie Bunsworth")
	for c: Dictionary in Game.chapters():
		assert_true(ResourceLoader.exists(String(c["scene"])), "level scene for " + String(c["id"]))
		assert_true(ResourceLoader.exists(Game.PATIENT_DIR + String(c["patient_id"]) + ".tres"), "patient for " + String(c["id"]))
	assert_eq(Game.chapter_for_patient("bonnie")["day"], 2)
	for p: StringName in [&"chapter_select", &"bc_placement", &"masking", &"referral"]:
		assert_has(Game.PHASES, p, "v3 phase")


func test_day2_unlocks_after_day1() -> void:
	Game.reset_save()
	assert_true(Game.is_chapter_unlocked("gus"))
	assert_false(Game.is_chapter_unlocked("bonnie"), "Day 2 locked on a fresh save")
	assert_eq(Game.next_chapter_id(), "gus")
	var got := []
	var cb := func(id: String, newly: Array) -> void: got.append([id, newly])
	Events.chapter_completed.connect(cb)
	Game.begin_visit("gus")
	assert_eq(Game.current_chapter_id, "gus")
	Game.set_audiometry_results({"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0})
	var s := Game.finish_visit()
	Events.chapter_completed.disconnect(cb)
	assert_eq(s["chapter_id"], "gus")
	assert_eq(s["day"], 1)
	assert_eq(s["newly_unlocked"], ["bonnie"])
	assert_eq(s["next_chapter_id"], "bonnie")
	assert_eq(got, [["gus", ["bonnie"]]])
	assert_true(Game.is_chapter_done("gus"))
	assert_true(Game.is_chapter_unlocked("bonnie"))
	assert_eq(Game.next_chapter_id(), "bonnie", "Play continues with Day 2")
	# a replay unlocks nothing new
	Game.begin_visit("gus")
	assert_eq(Game.finish_visit()["newly_unlocked"], [])
	# saved
	Game.progress = Game.DEFAULT_PROGRESS.duplicate(true)
	assert_true(Game.load_game())
	assert_true(Game.is_chapter_done("gus"), "chapters_done survives a reload")


func test_unlock_all_days_toggle() -> void:
	Game.reset_save()
	assert_has(Game.DEFAULT_SETTINGS, "unlock_all_days")
	Game.set_setting("unlock_all_days", true)
	assert_true(Game.is_chapter_unlocked("bonnie"), "career-fair toggle opens every day")
	assert_eq(Game.unlocked_chapter_ids(), ["gus", "bonnie"] as Array[String])
	Game.set_setting("unlock_all_days", false)
	assert_false(Game.is_chapter_unlocked("bonnie"))


func test_cli_day_opens_that_chapter() -> void:
	Game.reset_save()
	Game.cli["day"] = "2"
	assert_eq(Game.cli_chapter_id(), "bonnie")
	assert_true(Game.is_chapter_unlocked("bonnie"))
	assert_eq(Game.next_chapter_id(), "bonnie")


## A save from before chapters existed: Gus played once means Day 1 done.
func test_old_save_migrates() -> void:
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "settings": {}, "progress": {"coins": 50, "patients": {"gus": {"best_score": 90.0, "best_grade": "A", "last_grade": "A", "plays": 1}}}}))
	f.close()
	assert_true(Game.load_game())
	assert_true(Game.is_chapter_done("gus"))
	assert_true(Game.is_chapter_unlocked("bonnie"))


func test_shop_registry() -> void:
	assert_has(Game.SHOP_ITEMS, "comfy_chair")
	assert_has(Game.SHOP_ITEMS, "insert_earphones")
	assert_eq(int(Game.SHOP_ITEMS["insert_earphones"]["day"]), 2)


func _has_key(action: StringName, key: Key, shift: bool = false) -> bool:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey and (ev as InputEventKey).keycode == key and (ev as InputEventKey).shift_pressed == shift:
			return true
	return false


func test_masking_and_transducer_keys() -> void:
	Game.set_key_style("otosuite")
	for a in ["toggle_mask", "mask_louder", "mask_softer", "transducer_air", "transducer_bone"]:
		assert_true(InputMap.has_action(a), "action " + a)
	assert_true(_has_key(&"toggle_mask", KEY_M), "M = masking on/off")
	assert_true(_has_key(&"mask_louder", KEY_PAGEUP), "PgUp = noise up")
	assert_true(_has_key(&"mask_louder", KEY_UP, true), "Shift+Up = noise up")
	assert_true(_has_key(&"mask_softer", KEY_PAGEDOWN), "PgDn = noise down")
	assert_true(_has_key(&"transducer_bone", KEY_B), "B = bone")
	assert_true(_has_key(&"transducer_bone", KEY_8), "8 = bone (the clinic-software habit)")
	assert_true(_has_key(&"transducer_air", KEY_A), "A = air")
	assert_eq(Game.key_label(&"mask_louder"), "PgUp")
	assert_eq(Game.key_labels(&"mask_louder")[1], "Shift+Up")
	Game.set_key_style("affinity")
	assert_true(_has_key(&"mask_louder", KEY_PAGEDOWN), "swapped style swaps the masker pair too")
	assert_true(_has_key(&"mask_softer", KEY_PAGEUP))
	Game.set_key_style("otosuite")
	assert_true(_has_key(&"mask_louder", KEY_PAGEUP))


## The title's Days card (phase / beat chapter_select): locked days refuse, the demo toggle opens them.
func test_title_day_picker() -> void:
	Game.reset_save()
	var beats := {}
	var cb := func(beat: StringName, info: Dictionary, solver: Callable) -> void: beats[beat] = [info, solver]
	Events.awaiting_input.connect(cb)
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	add_node(title)
	await wait_frames(3)
	if beats.has(&"disclaimer_ok"):
		(beats[&"disclaimer_ok"][1] as Callable).call()
		await wait_seconds(0.5)
	assert_has(beats, &"title_start")
	title.call("_on_days")
	await wait_frames(2)
	Events.awaiting_input.disconnect(cb)
	assert_has(beats, &"chapter_select")
	var info: Dictionary = beats[&"chapter_select"][0]
	assert_eq(info["chapters"], ["gus"], "only Day 1 open on a fresh save")
	assert_eq(info["next"], "gus")
	var day2: Button = null
	for b: Button in title.get("_day_buttons"):
		if String(b.get_meta("chapter", "")) == "bonnie":
			day2 = b
	assert_true(day2 != null, "a Day 2 card")
	assert_eq(String(day2.get_meta("label", "")), "Day 2: Bonnie Bunsworth  (locked)")
	title.call("_pick_day", "bonnie", day2)
	assert_eq(title.get("_state"), &"days", "a locked day does not start")
	title.call("_toggle_unlock_all")
	assert_true(Game.is_chapter_unlocked("bonnie"), "Unlock all days (demo)")
	assert_eq(String(day2.get_meta("label", "")), "Day 2: Bonnie Bunsworth")
	title.call("_days_back")
	assert_eq(title.get("_state"), &"menu")


## (polish) A day you finished stays open even when its prerequisite is not on the save.
func test_done_chapter_stays_unlocked() -> void:
	Game.reset_save()
	assert_false(Game.is_chapter_unlocked("bonnie"))
	(Game.progress["chapters_done"] as Array).append("bonnie")
	assert_true(Game.is_chapter_unlocked("bonnie"))
	Game.reset_save()
