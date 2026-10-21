extends TestCase
## v3: chapters (days), the save fields behind them, and the Chapter 2 input actions.
## (Polish) Every day is open from the start: "requires" only picks the suggested (UP NEXT) day.

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
	# Days 1-2, then the speech days (3+); later chapters may add more
	assert_true(Game.chapters().size() >= 3, "Days 1 and 2, the speech days, plus any later chapters")
	var d1 := Game.chapter_for_day(1)
	var d2 := Game.chapter_for_day(2)
	var d3 := Game.chapter_for_day(3)
	assert_eq(d3["id"], "mike")
	assert_eq(d3["requires"], "bonnie", "speech follows Day 2 (the suggested order)")
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
	for p: StringName in [&"familiarize", &"speech"]:
		assert_has(Game.PHASES, p, "speech phase")


## (polish) Steve's rule: every chapter is open from the start, in any order.
func test_every_day_open_from_the_start() -> void:
	Game.reset_save()
	var all_ids: Array[String] = []
	for c: Dictionary in Game.chapters():
		assert_true(Game.is_chapter_unlocked(String(c["id"])), "open: " + String(c["id"]))
		all_ids.append(String(c["id"]))
	assert_eq(Game.unlocked_chapter_ids(), all_ids, "every chapter, in day order")
	assert_eq(Game.suggested_chapter_id(), "gus", "a fresh save suggests Day 1")
	assert_eq(Game.next_chapter_id(), "gus")
	assert_false(Game.DEFAULT_SETTINGS.has("unlock_all_days"), "no demo unlock setting any more")
	var went := []
	var cb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(cb)
	assert_true(Game.start_chapter("bonnie"), "Day 2 starts on a fresh save")
	Events.goto_scene.disconnect(cb)
	assert_eq(went, ["res://story/level_bonnie.tscn"])
	assert_false(Game.start_chapter("nope"), "an unknown chapter does not start")


## (Clinical review D1-7) A safety slip (the paperclip, or ignoring the seed) keeps a perfect visit off S.
func test_safety_slip_keeps_the_visit_off_s() -> void:
	Game.reset_save()
	Game.begin_visit("gus")
	Game.set_audiometry_results({"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0})
	assert_eq(String(Game.finish_visit()["grade"]), "S", "a clean perfect visit")
	Game.begin_visit("gus")
	Game.set_audiometry_results({"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0})
	Game.set_visit_flag(Game.NO_S_FLAG, true)
	assert_eq(String(Game.finish_visit()["grade"]), "A", "the slip keeps it off S")


func test_finishing_day1_suggests_day2() -> void:
	Game.reset_save()
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
	assert_eq(s["newly_unlocked"], [], "nothing is ever locked")
	assert_true(bool(s["first_clear"]))
	assert_eq(s["next_chapter_id"], "bonnie")
	assert_eq(s["suggested_next"], "bonnie")
	assert_eq(got, [["gus", []]])
	assert_true(Game.is_chapter_done("gus"))
	assert_eq(Game.next_chapter_id(), "bonnie", "Play continues with Day 2")
	# a replay is not a first clear
	Game.begin_visit("gus")
	assert_false(bool(Game.finish_visit()["first_clear"]))
	# saved
	Game.progress = Game.DEFAULT_PROGRESS.duplicate(true)
	assert_true(Game.load_game())
	assert_true(Game.is_chapter_done("gus"), "chapters_done survives a reload")


## Merge safety: CHAPTERS stay in day order (unique ids, unique and strictly increasing days), so a bad
## merge of two chapter blocks can't put Day 6 before Day 3.
func test_chapters_in_day_order() -> void:
	var last_day := 0
	var ids := {}
	for c: Dictionary in Game.chapters():
		var id := String(c["id"])
		var day := int(c["day"])
		assert_false(ids.has(id), "chapter id %s appears once" % id)
		ids[id] = true
		assert_true(day > last_day, "%s (Day %d) comes after Day %d" % [id, day, last_day])
		last_day = day


## Day 2 played first (picked from the Days card): Day 1 is still the suggested day.
func test_any_order() -> void:
	Game.reset_save()
	var ids := Game.unlocked_chapter_ids()
	var last: String = ids[ids.size() - 1]
	Game.begin_visit("bonnie")
	Game.set_audiometry_results({"accuracy": 1.0, "technique": 1.0, "efficiency": 1.0})
	var s := Game.finish_visit()
	assert_eq(s["chapter_id"], "bonnie")
	assert_eq(s["next_chapter_id"], "gus", "the paper's Next goes back to the suggested day (Day 1)")
	assert_eq(Game.suggested_chapter_id(), "gus")
	assert_eq(Game.next_chapter_id(), "gus")
	if last != "bonnie":
		Game.begin_visit(last)
		assert_eq(Game.finish_visit()["next_chapter_id"], "gus", "the paper's Next goes to the suggested day after the last one")
	Game.begin_visit("gus")
	var s2 := Game.finish_visit()
	assert_eq(s2["next_chapter_id"], "bonnie", "Day 1 done: Next is Day 2 (already played)")
	# the days in between, in order: each one's Next is the day after it
	for i in range(1, ids.size() - 1):
		Game.begin_visit(ids[i])
		assert_eq(Game.finish_visit()["next_chapter_id"], ids[i + 1], "Next after " + ids[i])
	Game.begin_visit(last)
	var s3 := Game.finish_visit()
	assert_eq(s3["next_chapter_id"], "", "the last day with every day done: no Next")
	assert_eq(Game.suggested_chapter_id(), "", "every day done: nothing suggested")
	assert_eq(Game.next_chapter_id(), "gus", "then Play replays the last day started (none: Day 1)")
	# a case day first: Next goes back to Day 1; after Day 1, Next is the next suggested day (Day 2)
	if ids.has("rocco"):
		Game.reset_save()
		Game.begin_visit("rocco")
		assert_eq(Game.finish_visit()["next_chapter_id"], "gus", "Day 6 played first: Next is Day 1")
		Game.reset_save()
		Game.begin_visit("gus")
		Game.finish_visit()
		Game.begin_visit("rocco")
		assert_eq(Game.finish_visit()["next_chapter_id"], "bonnie", "Day 6 after Day 1: Next is Day 2, the suggested day")


## The suggestion rule over any list: the first day not done whose requires is done (or empty).
func test_suggested_from() -> void:
	var list := [
		{"id": "a", "requires": ""}, {"id": "b", "requires": "a"}, {"id": "c", "requires": "b"},
		{"id": "d", "requires": "c"}, {"id": "e", "requires": "zzz"},
	]
	assert_eq(Game.suggested_from(list, []), "a")
	assert_eq(Game.suggested_from(list, ["a"]), "b")
	assert_eq(Game.suggested_from(list, ["a", "c"]), "b", "skipped ahead: still the gap")
	assert_eq(Game.suggested_from(list, ["c"]), "a")
	assert_eq(Game.suggested_from(list, ["a", "b", "c"]), "d")
	assert_eq(Game.suggested_from(list, ["a", "b", "c", "d"]), "e", "an unknown requires never blocks")
	assert_eq(Game.suggested_from(list, ["a", "b", "c", "d", "e"]), "")


## An old save that still has the demo setting loads fine (the key is just dropped).
func test_old_save_with_unlock_setting_loads() -> void:
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "settings": {"unlock_all_days": true, "quick_visit": false}, "progress": {"coins": 12}}))
	f.close()
	assert_true(Game.load_game())
	assert_false(Game.settings.has("unlock_all_days"))
	assert_false(bool(Game.settings["quick_visit"]), "the other settings survive")
	assert_eq(int(Game.progress["coins"]), 12)
	assert_true(Game.is_chapter_unlocked("bonnie"))


func test_cli_day_picks_that_chapter() -> void:
	Game.reset_save()
	Game.cli["day"] = "2"
	assert_eq(Game.cli_chapter_id(), "bonnie")
	assert_eq(Game.next_chapter_id(), "bonnie")


## A save from before chapters existed: Gus played once means Day 1 done.
func test_old_save_migrates() -> void:
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "settings": {}, "progress": {"coins": 50, "patients": {"gus": {"best_score": 90.0, "best_grade": "A", "last_grade": "A", "plays": 1}}}}))
	f.close()
	assert_true(Game.load_game())
	assert_true(Game.is_chapter_done("gus"))
	assert_eq(Game.suggested_chapter_id(), "bonnie")


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


## The title's Days card (phase / beat chapter_select): every day open, Day 1 UP NEXT on a fresh
## save, a card starts its day straight away.
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
	assert_has(beats, &"chapter_select")
	var info: Dictionary = beats[&"chapter_select"][0]
	assert_eq(info["chapters"], Game.unlocked_chapter_ids(), "every day open on a fresh save")
	assert_eq(info["next"], "gus")
	assert_eq(info["suggested"], "gus")
	var day1: Button = null
	var day2: Button = null
	for b: Button in title.get("_day_buttons"):
		if String(b.get_meta("chapter", "")) == "gus":
			day1 = b
		if String(b.get_meta("chapter", "")) == "bonnie":
			day2 = b
	assert_true(day1 != null and day2 != null, "a card per day")
	assert_eq(String(day2.get_meta("label", "")), "Day 2: Bonnie Bunsworth")
	assert_true(bool(day1.get_meta("suggested", false)), "Day 1 wears UP NEXT")
	assert_false(bool(day2.get_meta("suggested", false)))
	assert_false(day2.has_meta("locked"), "no lock state at all")
	var hint_s: Control = title.get("_days_hint_scroll")
	if hint_s != null:
		var g: Dictionary = (title.get_script() as Script).call("grid_geometry", title.get_viewport_rect().size,
			Game.chapters().size(), float(title.call("_card_scale")))
		assert_eq(hint_s.visible, bool(g["scrolls"]), "the 'wheel scrolls' hint shows only when the grid scrolls")
	title.call("_days_back")
	assert_eq(title.get("_state"), &"menu")
	title.call("_on_days")
	await wait_frames(2)
	var went := []
	var gcb := func(path: String) -> void: went.append(path)
	Events.goto_scene.connect(gcb)
	title.call("_pick_day", "bonnie", day2)
	Events.goto_scene.disconnect(gcb)
	Events.awaiting_input.disconnect(cb)
	assert_eq(went, ["res://story/level_bonnie.tscn"], "Day 2 starts on a fresh save")


## (polish) The Days grid with a fake list of 11 days (never shipped): it fits the 1280x720 screen
## above the safety footer, scrolls, moves with the arrow keys (the highlighted card scrolls into
## view), the mouse wheel scrolls it, and cards fall back to the chapter's own face / tint keys.
func test_title_day_grid_many_days() -> void:
	Game.reset_save()
	Game.progress["chapters_done"] = ["fake1", "fake2"]
	var faces := ["Gus", "Bonnie", "Hoot", "Doris", "You", ""]
	var fake: Array = []
	for i in 11:
		var ch := {"id": "fake%d" % (i + 1), "day": i + 1, "title": "Day %d: Fake Patient Number %d" % [i + 1, i + 1],
			"patient_id": "fake%d" % (i + 1), "teaches": "Pretend lesson %d" % (i + 1), "scene": "res://nope.tscn",
			"requires": "" if i == 0 else "fake%d" % i, "face": faces[i % faces.size()]}
		if i % 3 == 1:
			ch["tint"] = Color("#cfe3ff")
		elif i % 3 == 2:
			ch["tint"] = "#ffd9c7"
		fake.append(ch)
	# the game's logical screen is 1280x720 at 16:9 (1920x1080 scales the same layout up 1.5x)
	var root := Engine.get_main_loop() as SceneTree
	var keep_size: Vector2i = root.root.size
	root.root.size = Vector2i(1280, 720)
	var title: Control = (load("res://story/title_screen.tscn") as PackedScene).instantiate()
	title.set("chapters_override", fake)
	add_node(title)
	await wait_frames(3)
	title.call("_on_notice_ok")
	await wait_seconds(0.4)
	title.call("_on_days")
	await wait_seconds(0.7)   # the card's bounce-in has settled
	var cards: Array = title.get("_day_cards")
	assert_eq(cards.size(), 11)
	assert_eq((title.get("_day_buttons") as Array).size(), 12, "11 cards + Back")
	var vp: Vector2 = title.get_viewport_rect().size
	var card_rect: Rect2 = (title.get("_days_card") as Control).get_global_rect()
	assert_true(card_rect.position.x >= 0.0 and card_rect.end.x <= vp.x, "fits the width: %s in %s" % [card_rect, vp])
	assert_true(card_rect.position.y >= 0.0 and card_rect.end.y <= vp.y - 46.0, "above the safety footer: %s" % card_rect)
	var cols := int(title.get("_days_cols"))
	assert_between(cols, 3, 6, "columns at %s" % vp)
	var scroll: ScrollContainer = title.get("_days_scroll")
	assert_eq(scroll.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_AUTO, "11 days scroll")
	var hint_s: Control = title.get("_days_hint_scroll")
	if hint_s != null:
		assert_true(hint_s.visible, "the 'wheel scrolls' hint shows when the grid scrolls")
	# the suggested day (first not done whose requires is done) is highlighted and wears the badge
	assert_eq(int(title.get("_hl")), 2, "fake3 is UP NEXT")
	assert_true(bool((cards[2] as Button).get_meta("suggested", false)))
	assert_eq(String((cards[0] as Button).get_meta("best", "")), "", "no grade without a record")
	# face / tint fallbacks
	var TS: Script = title.get_script()
	assert_eq(TS.call("card_face", fake[2]), "Hoot", "the chapter's own face key")
	assert_eq(TS.call("card_face", {"id": "gus", "face": "Hoot"}), "Gus", "DAY_FACES wins")
	assert_eq(TS.call("card_tint", fake[1]), Color("#cfe3ff"), "a Color tint")
	assert_eq(TS.call("card_tint", fake[2]), Color("#ffd9c7"), "a hex tint")
	assert_eq(TS.call("card_tint", fake[0]), Palette.CREAM, "no tint: cream")
	assert_eq(TS.call("card_tint", {"id": "bonnie", "tint": "#000000"}), Color("#ffe3c2"), "DAY_TINTS wins")
	# keyboard: right, down a row, then down to the last card scrolls it into view, then Back
	await tap_action(&"ui_right")
	assert_eq(int(title.get("_hl")), 3)
	await tap_action(&"ui_down")
	assert_eq(int(title.get("_hl")), mini(3 + cols, 10))
	for i in 4:
		await tap_action(&"ui_down")
		if int(title.get("_hl")) == 10:
			break
	assert_eq(int(title.get("_hl")), 10, "down reaches the last card")
	await wait_seconds(0.3)
	var last: Button = cards[10]
	var sr := scroll.get_global_rect()
	assert_true(scroll.scroll_vertical > 0, "scrolled down")
	assert_true(last.get_global_rect().end.y <= sr.end.y + 1.0 and last.get_global_rect().position.y >= sr.position.y - 1.0, "the highlighted card is in view")
	await tap_action(&"ui_down")
	assert_eq(int(title.get("_hl")), 11, "past the last row: Back")
	await tap_action(&"ui_up")
	assert_eq(int(title.get("_hl")), 10)
	# back to the top with the keys, then the mouse wheel scrolls (wheel over a card reaches the scroll)
	for i in 6:
		await tap_action(&"ui_up")
		if int(title.get("_hl")) < cols:
			break
	await wait_seconds(0.3)
	assert_eq(scroll.scroll_vertical, 0, "top row in view")
	var over: Vector2 = (cards[1] as Button).get_global_rect().get_center()
	for i in 3:
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		wheel.position = over
		wheel.global_position = over
		wheel.factor = 1.0
		title.get_viewport().push_input(wheel)
		var up := wheel.duplicate() as InputEventMouseButton
		up.pressed = false
		title.get_viewport().push_input(up)
		await wait_frames(2)
	assert_true(scroll.scroll_vertical > 0, "the wheel scrolls the grid")
	await tap_action(&"ui_cancel")
	assert_eq(title.get("_state"), &"menu", "Esc goes back")
	root.root.size = keep_size


## (polish) The grid's shape on common screens (logical sizes: canvas_items / expand keeps 16:9 at
## 1280x720, so 1920x1080 is the same layout; 4:3 gets taller, ultrawide gets wider).
func test_day_grid_geometry() -> void:
	var TS: Script = load("res://story/title_screen.gd")
	var footer := 46.0
	for vp: Vector2 in [Vector2(1280, 720), Vector2(1280, 960), Vector2(1706, 720), Vector2(1280, 800)]:
		for n: int in [1, 2, 3, 4, 7, 11, 16]:
			var k := 1.25 if n <= 3 else 1.0
			var g: Dictionary = TS.call("grid_geometry", vp, n, k)
			var sz: Vector2 = g["scroll_size"]
			var card_h: float = sz.y + float(TS.get("DAYS_CHROME_H"))
			assert_true(sz.x + 32.0 <= vp.x - 40.0, "%d days at %s: width %.0f fits" % [n, vp, sz.x])
			assert_true(card_h <= vp.y - footer - 10.0, "%d days at %s: height %.0f fits above the footer" % [n, vp, card_h])
			assert_eq(int(g["rows"]), int(ceil(float(n) / int(g["cols"]))))
			assert_eq(bool(g["scrolls"]), int(g["rows"]) > int(g["vis_rows"]))
	var g720: Dictionary = TS.call("grid_geometry", Vector2(1280, 720), 11, 1.0)
	assert_eq(int(g720["cols"]), 4, "11 days at 1280x720: 4 columns")
	assert_eq(int(g720["vis_rows"]), 2, "two rows visible")
	assert_true(bool(g720["scrolls"]), "the third row scrolls")
	assert_eq(int((TS.call("grid_geometry", Vector2(1280, 720), 2, 1.25) as Dictionary)["cols"]), 2, "two big cards side by side")
