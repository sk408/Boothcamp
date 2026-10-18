extends Node
## Game: global game state (autoload "Game").
##
## Owns: settings (incl. key style), the save file, the current patient, the per-visit state
## (comfort hearts, medals, flags, audiometry results), coins, command-line options and the
## game clock. Pure scoring rules live in ClinicRules; this node only stores and combines.
## See CONTRACTS.md §2.

const SAVE_VERSION := 1
const DEFAULT_SAVE_PATH := "user://save.json"
const AUTOPLAY_SAVE_PATH := "user://save_autoplay.json"
const PATIENT_DIR := "res://core/patients/"

## Every story phase id (Events.phase_changed). Story may add more; keep these stable.
const PHASES: Array[StringName] = [
	&"disclaimer", &"title", &"intro", &"history", &"otoscopy", &"instructions", &"earphones",
	&"audiometry", &"reveal", &"evidence", &"fitting", &"results",
	# v3 (Chapter 2): the title's day picker, the bone oscillator, the masking lesson, the referral stamp
	&"chapter_select", &"bc_placement", &"masking", &"referral",
	# cases (docs/CASES.md): the tympanometer and the fit / refer / doctor-today call
	&"tymp", &"decision",
	# cases batch 2: the patient comes back after treatment (Day 10's wax)
	&"retest",
]

## (v3) The chapters ("days"), in order. A chapter is one patient visit with its own level scene.
## Every chapter is open from the start and can be played in any order (Steve's rule, polish).
## requires: the chapter that is best played first; it only picks the "UP NEXT" (suggested) day,
## it never locks anything ("" = a fine first day). Optional keys for the title's day picker:
## "face" (a Portraits speaker id) and "tint" (Color or "#rrggbb"), used when the title's own
## DAY_FACES / DAY_TINTS tables have no entry (CONTRACTS.md §2.2).
const CHAPTERS: Array[Dictionary] = [
	{"id": "gus", "day": 1, "title": "Day 1: Grandpa Gus", "patient_id": "gus", "teaches": "Air conduction",
		"scene": "res://story/level_gus.tscn", "requires": ""},
	{"id": "bonnie", "day": 2, "title": "Day 2: Bonnie Bunsworth", "patient_id": "bonnie", "teaches": "Bone conduction + masking",
		"scene": "res://story/level_bonnie.tscn", "requires": "gus"},
	# --- cases (docs/CASES.md, CONTRACTS.md §11): one shared runner plays the chapter's "case" file
	# (story/cases/<case>.json). "face" = the portrait speaker, "tint" = the day card's colour.
	{"id": "rocco", "day": 6, "title": "Day 6: Rocco Rimshot", "patient_id": "rocco", "teaches": "Case file: ringing ears",
		"scene": "res://story/level_case.tscn", "requires": "bonnie", "case": "noise_notch", "face": "Rocco", "tint": Color("#ffd9c7")},
	{"id": "marina", "day": 7, "title": "Day 7: Captain Marina Gale", "patient_id": "marina", "teaches": "Case file: the ferry captain",
		"scene": "res://story/level_case.tscn", "requires": "rocco", "case": "menieres", "face": "Marina", "tint": Color("#cfe3ff")},
	{"id": "dash", "day": 8, "title": "Day 8: Dash Delgado", "patient_id": "dash", "teaches": "Case file: the pizza rush",
		"scene": "res://story/level_case.tscn", "requires": "marina", "case": "sudden", "face": "Dash", "tint": Color("#ffe0d6")},
	{"id": "ginger", "day": 9, "title": "Day 9: Ginger Snapp", "patient_id": "ginger", "teaches": "Case file: the ventriloquist",
		"scene": "res://story/level_case.tscn", "requires": "dash", "case": "cookie_bite", "face": "Ginger", "tint": Color("#f3e1ff")},
	# cases batch 2: the conductive cases (where is the sound stuck?)
	{"id": "barnaby", "day": 10, "title": "Day 10: Barnaby Bumble", "patient_id": "barnaby", "teaches": "Case file: the beekeeper",
		"scene": "res://story/level_case.tscn", "requires": "ginger", "case": "wax", "face": "Barnaby", "tint": Color("#e6f4c4")},
	{"id": "skye", "day": 11, "title": "Day 11: Skye Tailwind", "patient_id": "skye", "teaches": "Case file: the cabin crew",
		"scene": "res://story/level_case.tscn", "requires": "barnaby", "case": "fluid", "face": "Skye", "tint": Color("#ffe4ef")},
]

## (v3) The upgrade shop. day = the first day the paper offers it. Owning one is never needed to
## play: every chapter is fully playable without coins.
const SHOP_ITEMS: Dictionary = {
	"comfy_chair": {"cost": 40, "day": 1, "title": "Comfy booth chair", "blurb": "Patients tire half as fast."},
	"insert_earphones": {"cost": 60, "day": 2, "title": "Insert earphones", "blurb": "55 dB of interaural attenuation: fewer ghosts."},
}

const KEY_STYLES: PackedStringArray = ["otosuite", "affinity"]

const DEFAULT_SETTINGS: Dictionary = {
	"key_style": "otosuite",     ## "otosuite": Up = louder (default). "affinity": Up = softer.
	"master_volume": 0.8,        ## 0..1, Master bus
	"tone_volume": 0.8,          ## 0..1, Tones bus (still capped by AudioSafety)
	"sfx_volume": 0.8,           ## 0..1, Sfx bus
	"music_volume": 0.6,         ## 0..1, Music bus
	"show_key_hints": true,      ## on-screen key chips next to every control
	"reduced_motion": false,     ## smaller shakes / bounces
	"no_startle": false,         ## tone the blast gag down to a wobble
	"fullscreen": false,
	"text_speed": 1.0,           ## dialogue typewriter speed multiplier
	"quick_visit": true,         ## Hoot finishes the second ear at x8 after a few stamps (~10 min level)
	# (polish) "unlock_all_days" is gone: every day is always open. Old saves that still carry it
	# load fine (load_game() only copies known keys).
}

const DEFAULT_PROGRESS: Dictionary = {
	"coins": 0,
	"upgrades": [],              ## Array of upgrade ids, e.g. "comfy_chair"
	"patients": {},              ## id -> {best_score, best_grade, last_grade, plays}
	"seen_disclaimer": false,
	"hoot_mastery": {},          ## skill -> clean uses (Hoot autoload)
	"plays": 0,
	"chapters_done": [],         ## (v3) chapter ids completed at least once (CHAPTERS)
	"last_chapter": "",          ## (v3) the chapter started most recently
}

var save_path: String = DEFAULT_SAVE_PATH
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var progress: Dictionary = DEFAULT_PROGRESS.duplicate(true)
var current_patient_id: String = "gus"
## (v3) The chapter being played (CHAPTERS id). begin_visit() sets it from the patient.
var current_chapter_id: String = "gus"
## Per-visit state, reset by begin_visit(). Shape: CONTRACTS.md §2.3.
var visit: Dictionary = {}
## Parsed user args (after "--"). Keys without "--"; flags map to true. CONTRACTS.md §7.
var cli: Dictionary = {}
## Seeded RNG for anything that should be reproducible in autoplay (--seed=N).
var rng := RandomNumberGenerator.new()
## Game clock in scaled seconds (pauses with the tree, follows Engine.time_scale).
var clock: float = 0.0

var _default_events: Dictionary = {}
## --affinity is "for this run": the style the save had, written back by save_game() (integrator, v3).
## Cleared when the player picks a style in the game.
var _cli_style_keep := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_parse_cli()
	for action: StringName in [&"louder", &"softer", &"mask_louder", &"mask_softer"]:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()
	if cli_flag("autoplay"):
		save_path = AUTOPLAY_SAVE_PATH
	elif cli.has("scene"):
		save_path = "user://save_scene.json"  # dev scene runs (monkey, shots) never touch the player's save
	if cli.has("save"):
		save_path = String(cli["save"])
	# --keep-save (integrator): an autoplay run that continues an earlier run's save (Day 1 then Day 2)
	if cli_flag("fresh") or (cli_flag("autoplay") and not cli_flag("keep-save")):
		reset_save()
	else:
		load_game()
	# --upgrades=insert_earphones (polish, dev/test runs): own these shop items for this run
	if cli.has("upgrades"):
		for id: String in String(cli["upgrades"]).split(",", false):
			if SHOP_ITEMS.has(id) and not has_upgrade(id):
				(progress["upgrades"] as Array).append(id)
	if cli_flag("affinity"):
		_cli_style_keep = String(settings.get("key_style", "otosuite"))
		settings["key_style"] = "affinity"
	rng.seed = int(cli.get("seed", 1234 if cli_flag("autoplay") else Time.get_ticks_usec()))
	var speed := float(cli.get("speed", 1.0))
	if speed > 0.0 and speed != 1.0:
		Engine.time_scale = speed
	apply_settings()
	_fit_window()


func _process(delta: float) -> void:
	clock += delta


## F11 or Alt+Enter toggles fullscreen (any scene; the pause menu has the toggle too).
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		set_setting("fullscreen", not bool(settings.get("fullscreen", false)))
		get_viewport().set_input_as_handled()


## Windowed start: about 85% of the usable screen at 16:9 (a 1280x720 window looks tiny on a
## 1440p or 4K desktop), centred. Never for headless, autoplay, shots or scene demos.
func _fit_window() -> void:
	if DisplayServer.get_name() == "headless" or is_autoplay() or cli.has("shots") or cli.has("scene") or cli.has("shot"):
		return
	if bool(settings.get("fullscreen", false)) or DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return
	var w := int(usable.size.x * 0.85)
	var h := int(w * 9.0 / 16.0)
	if h > int(usable.size.y * 0.85):
		h = int(usable.size.y * 0.85)
		w = int(h * 16.0 / 9.0)
	if w <= 1280:
		return
	var win := get_window()
	win.size = Vector2i(w, h)
	win.position = usable.position + (usable.size - win.size) / 2


# ---------------------------------------------------------------- command line

func _parse_cli() -> void:
	cli.clear()
	for arg: String in OS.get_cmdline_user_args():
		if not arg.begins_with("--"):
			continue
		var body := arg.substr(2)
		var eq := body.find("=")
		if eq >= 0:
			cli[body.substr(0, eq)] = body.substr(eq + 1)
		else:
			cli[body] = true


func cli_flag(name: String) -> bool:
	if not cli.has(name):
		return false
	var v: Variant = cli[name]
	if v is bool:
		return v
	return String(v) != "false" and String(v) != "0"


func cli_value(name: String, default_value: String = "") -> String:
	var v: Variant = cli.get(name, default_value)
	return default_value if v is bool else String(v)


func is_autoplay() -> bool:
	return cli_flag("autoplay")


# ---------------------------------------------------------------- settings

func set_setting(key: String, value: Variant) -> void:
	if key == "key_style":
		_cli_style_keep = ""
	settings[key] = value
	apply_settings()
	save_game()
	_emit_setting_changed(key, value)


func _emit_setting_changed(key: String, value: Variant) -> void:
	Events.settings_changed.emit(key, value)
	if key == "key_style":
		Events.key_style_changed.emit(String(value))


func set_key_style(style: String) -> void:
	assert(KEY_STYLES.has(style), "unknown key style " + style)
	set_setting("key_style", style)


func get_key_style() -> String:
	return String(settings.get("key_style", "otosuite"))


func apply_settings() -> void:
	_apply_key_style()
	_set_bus_volume(&"Master", float(settings.get("master_volume", 0.8)))
	_set_bus_volume(AudioSafety.TONES_BUS, float(settings.get("tone_volume", 0.8)))
	_set_bus_volume(AudioSafety.SFX_BUS, float(settings.get("sfx_volume", 0.8)))
	_set_bus_volume(AudioSafety.MUSIC_BUS, float(settings.get("music_volume", 0.6)))
	if DisplayServer.get_name() != "headless" and not is_autoplay():
		var want_full := bool(settings.get("fullscreen", false))
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if want_full else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and (want_full or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(mode)


func _set_bus_volume(bus: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)) if linear > 0.001 else -80.0)


## OTOsuite style: louder = Up, softer = Down. Affinity style swaps the two (v3: and the masker's
## Page Up / Page Down pair the same way).
func _apply_key_style() -> void:
	var affinity := get_key_style() == "affinity"
	for pair: Array in [[&"louder", &"softer"], [&"mask_louder", &"mask_softer"]]:
		var up: StringName = pair[0]
		var down: StringName = pair[1]
		if not _default_events.has(up) or not _default_events.has(down):
			continue
		var up_src: Array = _default_events[down] if affinity else _default_events[up]
		var down_src: Array = _default_events[up] if affinity else _default_events[down]
		InputMap.action_erase_events(up)
		InputMap.action_erase_events(down)
		for ev: InputEvent in up_src:
			InputMap.action_add_event(up, ev)
		for ev: InputEvent in down_src:
			InputMap.action_add_event(down, ev)


## Short human label of the first key bound to an action, for on-screen key hints.
## e.g. "Space", "Up", "Down", "Left", "Right", "S", "N", "R", "L", "Esc".
func key_label(action: StringName) -> String:
	var labels := key_labels(action)
	return labels[0] if labels.size() > 0 else "?"


func key_labels(action: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	if not InputMap.has_action(action):
		return out
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k := ev as InputEventKey
			var code := k.keycode if k.keycode != KEY_NONE else k.physical_keycode
			var s := OS.get_keycode_string(code)
			if s == "Escape":
				s = "Esc"
			elif s == "PageUp":
				s = "PgUp"
			elif s == "PageDown":
				s = "PgDn"
			if k.shift_pressed:
				s = "Shift+" + s
			out.append(s)
		elif ev is InputEventMouseButton:
			out.append("Click")
	return out


# ---------------------------------------------------------------- patients and visits

## Loads res://core/patients/<id>.tres (a PatientProfile). Returns null if missing.
func load_patient(id: String) -> Resource:
	var path := PATIENT_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		push_error("Game.load_patient: no patient file " + path)
		return null
	return load(path)


## Start a new patient visit. Resets comfort, medals, flags and results. Story calls this first.
func begin_visit(patient_id: String) -> void:
	current_patient_id = patient_id
	var ch := chapter_for_patient(patient_id)
	if not ch.is_empty():
		current_chapter_id = String(ch["id"])
	visit = {
		"patient_id": patient_id,
		"comfort": ClinicRules.MAX_COMFORT,
		"comfort_log": [],
		"medals": {},
		"flags": {"instructed": true, "earphones_swapped": false},
		"audiometry": {},
		"started_at": clock,
	}
	Events.comfort_changed.emit(ClinicRules.MAX_COMFORT, "visit_start")


func lose_comfort(reason: String, amount: int = 1) -> void:
	_ensure_visit()
	var before: int = visit["comfort"]
	visit["comfort"] = clampi(before - amount, 0, ClinicRules.MAX_COMFORT)
	(visit["comfort_log"] as Array).append({"reason": reason, "delta": int(visit["comfort"]) - before})
	if visit["comfort"] != before:
		Events.comfort_changed.emit(visit["comfort"], reason)


func gain_comfort(reason: String, amount: int = 1) -> void:
	_ensure_visit()
	var before: int = visit["comfort"]
	visit["comfort"] = clampi(before + amount, 0, ClinicRules.MAX_COMFORT)
	(visit["comfort_log"] as Array).append({"reason": reason, "delta": int(visit["comfort"]) - before})
	if visit["comfort"] != before:
		Events.comfort_changed.emit(visit["comfort"], reason)


func get_comfort() -> int:
	return int(visit.get("comfort", ClinicRules.MAX_COMFORT))


func set_visit_flag(key: String, value: Variant) -> void:
	_ensure_visit()
	(visit["flags"] as Dictionary)[key] = value


func get_visit_flag(key: String, default_value: Variant = null) -> Variant:
	return (visit.get("flags", {}) as Dictionary).get(key, default_value)


## medal: "gold", "silver" or "bronze" for one micro-game (beat id, e.g. "otoscopy").
func record_medal(beat: String, medal: String) -> void:
	_ensure_visit()
	(visit["medals"] as Dictionary)[beat] = medal


## Store the audiometry results (CONTRACTS.md §5.1). Story calls this after test_finished.
func set_audiometry_results(results: Dictionary) -> void:
	_ensure_visit()
	visit["audiometry"] = results


## Combine audiometry + care into the visit score, award coins, update progress, save.
## Returns the summary (CONTRACTS.md §5.3). Story calls it once, on the results screen.
func finish_visit() -> Dictionary:
	_ensure_visit()
	var res: Dictionary = visit.get("audiometry", {})
	var a := float(res.get("accuracy", 0.0))
	var t := float(res.get("technique", 0.0))
	var e := float(res.get("efficiency", 0.0))
	var c := float(get_comfort()) / float(ClinicRules.MAX_COMFORT)
	var w := ClinicRules.SCORE_WEIGHTS
	var score := 100.0 * (w["accuracy"] * a + w["technique"] * t + w["efficiency"] * e + w["care"] * c)
	score = clampf(score, 0.0, 100.0)
	var grade := ClinicRules.grade_for_score(score)
	var medal_bonus := 0
	for m: String in (visit["medals"] as Dictionary).values():
		medal_bonus += {"gold": 10, "silver": 6, "bronze": 3}.get(m, 0)
	var coins := int(round(score / 2.0)) + medal_bonus
	add_coins(coins)
	var id: String = visit["patient_id"]
	var pats: Dictionary = progress["patients"]
	var rec: Dictionary = pats.get(id, {"best_score": 0.0, "best_grade": "", "last_grade": "", "plays": 0})
	rec["plays"] = int(rec.get("plays", 0)) + 1
	rec["last_grade"] = grade
	if score >= float(rec.get("best_score", 0.0)):
		rec["best_score"] = score
		rec["best_grade"] = grade
	pats[id] = rec
	progress["plays"] = int(progress.get("plays", 0)) + 1
	var ch := chapter_for_patient(id)
	var chapter_id := String(ch.get("id", ""))
	var first_clear := chapter_id != "" and not is_chapter_done(chapter_id)
	if first_clear:
		(progress["chapters_done"] as Array).append(chapter_id)
	var newly: Array = []   # (polish) nothing is ever locked, so nothing is newly unlocked
	save_game()
	var summary := {
		"patient_id": id,
		"score": score,
		"grade": grade,
		"accuracy": a,
		"technique": t,
		"efficiency": e,
		"care": c,
		"comfort": get_comfort(),
		"medals": (visit["medals"] as Dictionary).duplicate(),
		"coins_earned": coins,
		"coins_total": int(progress["coins"]),
		"duration_s": clock - float(visit.get("started_at", clock)),
		"audiometry": res,
		# v3
		"patient_name": _patient_name(id),
		"patient_short": _patient_short(id),  # (polish) "Gus", "Bonnie": PatientProfile.short_name()
		"chapter_id": chapter_id,
		"day": int(ch.get("day", 0)),
		"newly_unlocked": newly,
		"next_chapter_id": _paper_next(chapter_id),
		"first_clear": first_clear,               # (polish) this visit finished the chapter for the first time
		"suggested_next": suggested_chapter_id(),  # (polish) the day the title now suggests ("" = all done)
	}
	visit["summary"] = summary
	if chapter_id != "":
		Events.chapter_completed.emit(chapter_id, newly)
	return summary


func add_coins(amount: int) -> void:
	progress["coins"] = int(progress.get("coins", 0)) + amount
	Events.coins_changed.emit(int(progress["coins"]), amount)


func has_upgrade(id: String) -> bool:
	return (progress.get("upgrades", []) as Array).has(id)


## Spend coins on an upgrade. Returns false if already owned or too expensive.
func buy_upgrade(id: String, cost: int) -> bool:
	if has_upgrade(id) or int(progress.get("coins", 0)) < cost:
		return false
	(progress["upgrades"] as Array).append(id)
	add_coins(-cost)
	save_game()
	return true


# ---------------------------------------------------------------- chapters (v3)

func chapters() -> Array[Dictionary]:
	return CHAPTERS


## The CHAPTERS entry with this id ({} if none).
func chapter(id: String) -> Dictionary:
	for c: Dictionary in CHAPTERS:
		if String(c["id"]) == id:
			return c
	return {}


func chapter_for_patient(patient_id: String) -> Dictionary:
	for c: Dictionary in CHAPTERS:
		if String(c["patient_id"]) == patient_id:
			return c
	return {}


func chapter_for_day(day: int) -> Dictionary:
	for c: Dictionary in CHAPTERS:
		if int(c["day"]) == day:
			return c
	return {}


func is_chapter_done(id: String) -> bool:
	return (progress.get("chapters_done", []) as Array).has(id)


## (polish) Every chapter is open from the start, in any order: always true. Kept so callers
## (and the other chapter branches) need not change. "requires" only picks the suggested day.
func is_chapter_unlocked(_id: String) -> bool:
	return true


## Every chapter id, in day order (all of them are open).
func unlocked_chapter_ids() -> Array[String]:
	var out: Array[String] = []
	for c: Dictionary in CHAPTERS:
		out.append(String(c["id"]))
	return out


## (polish) The day the title suggests next (its card wears the "UP NEXT" badge): the first
## chapter in day order not done yet whose "requires" is done (or empty, or unknown); else the
## first chapter not done; "" when every day is done.
func suggested_chapter_id() -> String:
	return suggested_from(CHAPTERS, progress.get("chapters_done", []) as Array)


## suggested_chapter_id() over any chapter list (the title's day picker and its tests use it).
static func suggested_from(list: Array, done: Array) -> String:
	var first_open := ""
	var ids: Array = list.map(func(c: Dictionary) -> String: return String(c.get("id", "")))
	for c: Dictionary in list:
		var id := String(c.get("id", ""))
		if done.has(id):
			continue
		var req := String(c.get("requires", ""))
		if req == "" or done.has(req) or not ids.has(req):
			return id
		if first_open == "":
			first_open = id
	return first_open


## The chapter the command line asks for (--chapter=id or --day=N), "" if none.
func cli_chapter_id() -> String:
	if cli.has("chapter") and not chapter(cli_value("chapter")).is_empty():
		return cli_value("chapter")
	if cli.has("day"):
		return String(chapter_for_day(int(cli_value("day", "1"))).get("id", ""))
	return ""


## What the title's "Play" starts: the command-line chapter; else the suggested day
## (suggested_chapter_id()); else the last one played; else Day 1.
func next_chapter_id() -> String:
	var forced := cli_chapter_id()
	if forced != "":
		return forced
	var sug := suggested_chapter_id()
	if sug != "":
		return sug
	var last := String(progress.get("last_chapter", ""))
	if last != "" and not chapter(last).is_empty():
		return last
	return String(CHAPTERS[0]["id"])


func _patient_name(id: String) -> String:
	var p := load_patient(id)
	return String(p.get("display_name")) if p != null else id


func _patient_short(id: String) -> String:
	var p := load_patient(id)
	return String(p.call("short_name")) if p != null and p.has_method("short_name") else id.capitalize()


## (polish) The day the paper's Next button offers: the suggested day when it comes earlier in order
## than this one (a later day played first: Day 2 or Day 6 first goes back to Day 1), else the day
## after this one in order, after the last day the suggested day, or "" when every day is done.
func _paper_next(id: String) -> String:
	var sug := suggested_chapter_id()
	if sug != "" and sug != id and _chapter_index(sug) < _chapter_index(id):
		return sug    # a later day played first: Next goes back to the day the title suggests
	var nxt := _next_after(id)
	if nxt != "":
		return nxt
	return sug if sug != id else ""


func _chapter_index(id: String) -> int:
	for i in CHAPTERS.size():
		if String(CHAPTERS[i]["id"]) == id:
			return i
	return CHAPTERS.size()


func _next_after(id: String) -> String:
	for i in CHAPTERS.size() - 1:
		if String(CHAPTERS[i]["id"]) == id:
			return String(CHAPTERS[i + 1]["id"])
	return ""


func chapter_scene(id: String) -> String:
	return String(chapter(id).get("scene", ""))


## Start a chapter: remembers it and asks main to switch to its level scene. Returns false if the
## chapter is unknown or its scene is missing (every chapter is open: nothing is ever refused).
func start_chapter(id: String) -> bool:
	if chapter(id).is_empty() or not ResourceLoader.exists(chapter_scene(id)):
		push_warning("Game.start_chapter: %s is unknown or missing" % id)
		return false
	current_chapter_id = id
	progress["last_chapter"] = id
	save_game()
	Events.goto_scene.emit(chapter_scene(id))
	return true


func _ensure_visit() -> void:
	if visit.is_empty():
		begin_visit(current_patient_id)


# ---------------------------------------------------------------- save / load

func save_game() -> bool:
	var to_save := settings
	if _cli_style_keep != "":
		to_save = settings.duplicate(true)
		to_save["key_style"] = _cli_style_keep
	var data := {"version": SAVE_VERSION, "settings": to_save, "progress": progress}
	# write a temp file, then rename over the save: a crash mid-write never corrupts it
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Game.save_game: cannot write " + save_path)
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_save := ProjectSettings.globalize_path(save_path)
	if DirAccess.rename_absolute(abs_tmp, abs_save) != OK:
		# some platforms refuse to rename over an existing file
		DirAccess.remove_absolute(abs_save)
		if DirAccess.rename_absolute(abs_tmp, abs_save) != OK:
			push_warning("Game.save_game: cannot replace " + save_path)
			return false
	return true


func load_game() -> bool:
	settings = DEFAULT_SETTINGS.duplicate(true)
	progress = DEFAULT_PROGRESS.duplicate(true)
	if not FileAccess.file_exists(save_path):
		return false
	var text := FileAccess.get_file_as_string(save_path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_warning("Game.load_game: corrupt save, keeping a backup and starting fresh")
		DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak"))
		return false
	var d: Dictionary = parsed
	if int(d.get("version", SAVE_VERSION)) > SAVE_VERSION:
		push_warning("Game.load_game: save from a newer version, starting fresh")
		return false
	_merge_typed(settings, d.get("settings", {}))
	_merge_typed(progress, d.get("progress", {}))
	# JSON turns ints into floats; normalise the ones we use as ints.
	progress["coins"] = int(progress.get("coins", 0))
	progress["plays"] = int(progress.get("plays", 0))
	_migrate_chapters()
	if not KEY_STYLES.has(String(settings.get("key_style", ""))):
		settings["key_style"] = "otosuite"
	return true


## Copy known keys from a loaded dictionary, keeping the default when the type is wrong
## (a hand-edited or old save must never crash the game). Numbers may be int or float.
static func _merge_typed(into: Dictionary, from: Variant) -> void:
	if not from is Dictionary:
		return
	var src: Dictionary = from
	for k: Variant in src:
		if not into.has(k):
			continue
		var want := typeof(into[k])
		var got := typeof(src[k])
		var numeric := (want == TYPE_INT or want == TYPE_FLOAT) and (got == TYPE_INT or got == TYPE_FLOAT)
		if got == want or numeric:
			into[k] = src[k]


## (v3) Saves from before chapters existed: a patient with a finished visit counts as that
## chapter done (a Day 1 veteran sees Day 2 as UP NEXT).
func _migrate_chapters() -> void:
	var done: Array = progress.get("chapters_done", [])
	var pats: Dictionary = progress.get("patients", {})
	for c: Dictionary in CHAPTERS:
		var rec: Variant = pats.get(String(c["patient_id"]), {})
		if rec is Dictionary and int((rec as Dictionary).get("plays", 0)) > 0 and not done.has(String(c["id"])):
			done.append(String(c["id"]))
	progress["chapters_done"] = done


func reset_save() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	progress = DEFAULT_PROGRESS.duplicate(true)
	save_game()
