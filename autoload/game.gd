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
]

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
}

const DEFAULT_PROGRESS: Dictionary = {
	"coins": 0,
	"upgrades": [],              ## Array of upgrade ids, e.g. "comfy_chair"
	"patients": {},              ## id -> {best_score, best_grade, last_grade, plays}
	"seen_disclaimer": false,
	"hoot_mastery": {},          ## skill -> clean uses (Hoot autoload)
	"plays": 0,
}

var save_path: String = DEFAULT_SAVE_PATH
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var progress: Dictionary = DEFAULT_PROGRESS.duplicate(true)
var current_patient_id: String = "gus"
## Per-visit state, reset by begin_visit(). Shape: CONTRACTS.md §2.3.
var visit: Dictionary = {}
## Parsed user args (after "--"). Keys without "--"; flags map to true. CONTRACTS.md §7.
var cli: Dictionary = {}
## Seeded RNG for anything that should be reproducible in autoplay (--seed=N).
var rng := RandomNumberGenerator.new()
## Game clock in scaled seconds (pauses with the tree, follows Engine.time_scale).
var clock: float = 0.0

var _default_events: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_parse_cli()
	for action: StringName in [&"louder", &"softer"]:
		if InputMap.has_action(action):
			_default_events[action] = InputMap.action_get_events(action).duplicate()
	if cli_flag("autoplay"):
		save_path = AUTOPLAY_SAVE_PATH
	elif cli.has("scene"):
		save_path = "user://save_scene.json"  # dev scene runs (monkey, shots) never touch the player's save
	if cli.has("save"):
		save_path = String(cli["save"])
	if cli_flag("autoplay") or cli_flag("fresh"):
		reset_save()
	else:
		load_game()
	if cli_flag("affinity"):
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


## OTOsuite style: louder = Up, softer = Down. Affinity style swaps the two.
func _apply_key_style() -> void:
	if not _default_events.has(&"louder") or not _default_events.has(&"softer"):
		return
	var affinity := get_key_style() == "affinity"
	var louder_src: Array = _default_events[&"softer"] if affinity else _default_events[&"louder"]
	var softer_src: Array = _default_events[&"louder"] if affinity else _default_events[&"softer"]
	InputMap.action_erase_events(&"louder")
	InputMap.action_erase_events(&"softer")
	for ev: InputEvent in louder_src:
		InputMap.action_add_event(&"louder", ev)
	for ev: InputEvent in softer_src:
		InputMap.action_add_event(&"softer", ev)


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
	}
	visit["summary"] = summary
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


func _ensure_visit() -> void:
	if visit.is_empty():
		begin_visit(current_patient_id)


# ---------------------------------------------------------------- save / load

func save_game() -> bool:
	var data := {"version": SAVE_VERSION, "settings": settings, "progress": progress}
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


func reset_save() -> void:
	settings = DEFAULT_SETTINGS.duplicate(true)
	progress = DEFAULT_PROGRESS.duplicate(true)
	save_game()
