extends Node
## Movie harness for the audio-safety check (integrator tool, not part of the game flow).
## Seats Gus in the booth, opens the AudiOtron and lets the autoplay bot test BOTH ears, logging
## every tone with its movie frame so the recorded WAV can be cut per tone. Quits when done.
##   xvfb-run ... godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie /abs/out.avi \
##     -- --scene=res://tools/movie_ac.tscn --autoplay --speed=6
## See tools/movie_check.sh, which also analyses the audio (per-channel peaks per tone).
##
## (v3) --day=2: Bonnie's right ear through Day 2's tests (air by Hoot at x8, then unmasked bone,
## masked bone and masked air played by the bot), logging every tone with its transducer and every
## (v4) in the v4 order: both airs, unmasked bone on her LEFT mastoid, the one-tone Ghost demo on the
## right mastoid (plan demo_tone), then masked right bone (noise in the left ear) and masked right air;
## masker change (MOVIE_MASK). The Sfx, Music and Voice buses are MUTED in this mode, so the capture
## holds only the ToneGenerator's output and tools/analyze_movie_bc.py can check it exactly: tone
## channel and level, the bone cross-feed, and the masker (non-test ear only, level, ceiling).
##
## (Speech) --day=3: Mike's SRT on the SPEECH screen, right ear then left, played by the bot.
## Run it at --speed=1: each word's murmur plays in real (audio) time, so a faster game clock
## would start the next word before the last one ends and cut it off. MASK goes on after the
## MASK_ON_AFTER-th scored word of each ear and off after the MASK_OFF_AFTER-th, so the capture
## holds words with and without the speech noise, and the noise following the dial. UI buses are
## muted as for Day 2; tools/analyze_movie_audio.py --speech checks the words (test ear only, level
## vs AudioSafety.speech_to_rms) and the noise (other ear only, level vs masker_to_rms, ceiling).
## Any other --day, and any --chapter, is refused with a message and exit 2: nothing is recorded in
## its place.

const CLINIC := "res://world/clinic.tscn"
const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const SPEECH := "res://ui/speech/speech_screen.tscn"
const LevelMike := preload("res://story/level_mike.gd")
## (Speech) MASK on after this many scored words of an ear, off again after MASK_OFF_AFTER.
const MASK_ON_AFTER := 3
const MASK_OFF_AFTER := 7

var _speech: Node
var _voice: SpeechVoice
var _scored := 0
var _noise_logged := ""
var _toggle_t := -100.0


func demo_start() -> void:
	if Game.cli.has("chapter"):
		printerr("MOVIE: --chapter is not supported: pick the movie with --day=1 (Gus's air), --day=2 (Bonnie's bone and masking) or --day=3 (Mike's speech). Nothing recorded.")
		Events.quit_requested.emit(2)
		return
	var day := String(Game.cli_value("day", "1"))
	if day == "2":
		await _day2()
		return
	if day == "3":
		await _day3()
		return
	if day != "1":
		printerr("MOVIE: --day=%s is not supported: the movie records --day=1 (Gus's air), --day=2 (Bonnie's bone and masking) or --day=3 (Mike's speech). Nothing recorded." % day)
		Events.quit_requested.emit(2)
		return
	Game.begin_visit("gus")
	Events.tone_started.connect(func(ear: String, freq: int, db: int) -> void:
		print("MOVIE_TONE_ON %s %d %d %d" % [ear, freq, db, Engine.get_frames_drawn()]))
	Events.tone_stopped.connect(func(ear: String, freq: int, db: int, dur: float) -> void:
		print("MOVIE_TONE_OFF %s %d %d %d" % [ear, freq, db, Engine.get_frames_drawn()]))
	var clinic: Node = (load(CLINIC) as PackedScene).instantiate()
	add_child(clinic)
	await get_tree().process_frame
	clinic.call("put_on_earphones", true)
	await clinic.call("sit")
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_child(screen)
	var patient: Resource = Game.load_patient("gus")
	for ear: String in ["right", "left"]:
		Events.phase_changed.emit(&"audiometry", {"ear": ear})
		screen.call("start_test", patient, ear, ear == "right")
		await screen.test_finished
	print("MOVIE_DONE %d" % Engine.get_frames_drawn())
	await get_tree().create_timer(0.5).timeout
	Events.quit_requested.emit(0)


## (v3) Day 2: bone and masking. Logs:
##   MOVIE_TONE_ON <ear> <freq> <db> <frame> <transducer>      MOVIE_TONE_OFF <ear> <freq> <db> <frame>
##   MOVIE_MASK <masked ear> <freq> <db EM> <on 0/1> <frame>     MOVIE_TEST <test> <frame>
func _day2() -> void:
	for bus: StringName in [AudioSafety.SFX_BUS, AudioSafety.MUSIC_BUS, AudioSafety.VOICE_BUS]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, true)
	Game.begin_visit("bonnie")
	Game.set_visit_flag("instructed", true)
	Events.tone_started.connect(func(ear: String, freq: int, db: int) -> void:
		var tr := "phones"
		if Stage.audiometer != null:
			tr = String(Stage.audiometer.call("get_state").get("transducer", "phones"))
		print("MOVIE_TONE_ON %s %d %d %d %s" % [ear, freq, db, Engine.get_frames_drawn(), tr]))
	Events.tone_stopped.connect(func(ear: String, freq: int, db: int, _dur: float) -> void:
		print("MOVIE_TONE_OFF %s %d %d %d" % [ear, freq, db, Engine.get_frames_drawn()]))
	Events.masker_changed.connect(func(ear: String, freq: int, db: int, on: bool) -> void:
		print("MOVIE_MASK %s %d %d %d %d" % [ear, freq, db, 1 if on else 0, Engine.get_frames_drawn()]))
	var clinic: Node = (load(CLINIC) as PackedScene).instantiate()
	clinic.set("patient_id", "bonnie")
	add_child(clinic)
	await get_tree().process_frame
	clinic.call("put_on_earphones", true)
	await clinic.call("sit")
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	var screen: Node = (load(AUDIOMETER) as PackedScene).instantiate()
	add_child(screen)
	var patient: Resource = Game.load_patient("bonnie")
	var plans: Array = [
		["right", {"test": "ac", "hoot_turn_after": 0}],
		["left", {"test": "ac", "hoot_turn_after": 0}],
		["left", {"test": "bc", "masking_controls": true, "hoot_turn_after": 99}],
		["right", {"test": "bc", "bc_freqs": [1000], "masking_controls": false, "hoot_turn_after": 99, "demo_tone": {}}],
		["right", {"test": "bc_masked", "masking_controls": true, "hoot_turn_after": 99}],
		["right", {"test": "ac_masked", "masking_controls": true, "hoot_turn_after": 99}],
	]
	for p: Array in plans:
		var plan: Dictionary = (p[1] as Dictionary).duplicate()
		if plan.has("demo_tone"):
			# (v4) the Ghost demo: one tone 5 dB above her measured left bone, as level_bonnie plays it
			var lb := ClinicRules.sheet_thresholds(screen.call("get_results"), "left", &"bc")
			var ddb := int(lb.get(1000, 5)) + ClinicRules.LEVEL_STEP_DB
			plan["demo_tone"] = {"freq": 1000, "db": ddb, "title": "Bone %d? BOO!" % ddb, "idle_s": 3.0}
		if String(plan["test"]) == "bc":
			clinic.call("put_on_bone_oscillator", String(p[0]))
		elif String(plan["test"]) == "bc_masked":
			clinic.call("put_on_masking_phone", "left")
		elif String(plan["test"]) == "ac_masked":
			clinic.call("take_off_bone_oscillator")
			clinic.call("put_on_earphones", true)
		print("MOVIE_TEST %s %d" % [String(plan["test"]), Engine.get_frames_drawn()])
		Events.phase_changed.emit(&"audiometry", {"ear": p[0], "test": String(plan["test"])})
		screen.call("start_test", patient, String(p[0]), false, plan)
		await screen.test_finished
	print("MOVIE_DONE %d" % Engine.get_frames_drawn())
	await get_tree().create_timer(0.5).timeout
	Events.quit_requested.emit(0)


## (Speech) Day 3: Mike's SRT, both ears, with speech noise for part of each. Logs:
##   MOVIE_WORD_ON <ear> <db HL> <frame> <murmur ms> <item id>    MOVIE_TEST srt <ear> <frame>
##   MOVIE_NOISE <noise ear> <db EM> <on 0/1> <frame>   (on every change, including the level)
func _day3() -> void:
	for bus: StringName in [AudioSafety.SFX_BUS, AudioSafety.MUSIC_BUS, AudioSafety.VOICE_BUS]:
		var idx := AudioServer.get_bus_index(bus)
		if idx >= 0:
			AudioServer.set_bus_mute(idx, true)
	Game.begin_visit("mike")
	var clinic: Node = (load(CLINIC) as PackedScene).instantiate()
	clinic.set("patient_id", "mike")
	add_child(clinic)
	await get_tree().process_frame
	clinic.call("put_on_earphones", true)
	await clinic.call("sit")
	clinic.call("hold_response_button", false)
	var cam: Camera3D = clinic.call("get_main_camera")
	cam.current = false
	_speech = (load(SPEECH) as PackedScene).instantiate()
	add_child(_speech)
	_voice = _speech.get("_voice")
	Events.speech_presented.connect(func(ear: String, _test: StringName, db: int, it: Dictionary) -> void:
		var buf: PackedFloat32Array = _voice.get("_buf")
		print("MOVIE_WORD_ON %s %d %d %d %s" % [ear, db, Engine.get_frames_drawn(), roundi(buf.size() * 1000.0 / SpeechVoice.MIX_RATE),
			String(it.get("id", ""))]))
	Events.speech_scored.connect(func(_e: String, _t: StringName, _d: int, _c: bool, _r: bool) -> void: _scored += 1)
	var mike := Game.load_patient("mike") as PatientProfile
	var plan := {"test": "srt", "tones": SpeechSession.tone_results_from(mike), "list": LevelMike.LIST_ID, "exclude": [LevelMike.UNKNOWN_WORD]}
	for ear: String in ["right", "left"]:
		_scored = 0
		print("MOVIE_TEST srt %s %d" % [ear, Engine.get_frames_drawn()])
		Events.phase_changed.emit(&"speech", {"ear": ear, "test": "srt"})
		_speech.call("start_test", mike, ear, false, plan.duplicate(true))
		await _speech.test_finished
	_log_noise()
	print("MOVIE_DONE %d" % Engine.get_frames_drawn())
	await get_tree().create_timer(0.5).timeout
	Events.quit_requested.emit(0)


## (Speech) Every frame on Day 3: log noise changes, and flip MASK (by its key, like a player)
## when the word count says so and the screen is between words.
func _process(_delta: float) -> void:
	if _speech == null or not is_instance_valid(_speech):
		return
	_log_noise()
	var st: Dictionary = _speech.call("get_state")
	var want := _scored >= MASK_ON_AFTER and _scored < MASK_OFF_AFTER
	var idle := bool(st["accepting_input"]) and not bool(st["talking"]) and not bool(st["listening"]) and not bool(st["awaiting_score"])
	if idle and bool(st["mask_on"]) != want and Game.clock - _toggle_t > 0.3:
		_toggle_t = Game.clock
		for pressed: bool in [true, false]:
			var ev := InputEventAction.new()
			ev.action = &"toggle_mask"
			ev.pressed = pressed
			Input.parse_input_event(ev)


func _log_noise() -> void:
	if _voice == null:
		return
	var now := "%s %d" % [_voice.noise_ear, roundi(_voice.noise_db)] if _voice.noise_on else "off"
	if now == _noise_logged:
		return
	_noise_logged = now
	print("MOVIE_NOISE %s %d %d %d" % [_voice.noise_ear, roundi(_voice.noise_db), 1 if _voice.noise_on else 0, Engine.get_frames_drawn()])
