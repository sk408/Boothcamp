extends Node
## Movie harness for the audio-safety check (integrator tool, not part of the game flow).
## Seats Gus in the booth, opens the AudiOtron and lets the autoplay bot test BOTH ears, logging
## every tone with its movie frame so the recorded WAV can be cut per tone. Quits when done.
##   xvfb-run ... godot --path . --rendering-driver opengl3 --fixed-fps 30 --write-movie /abs/out.avi \
##     -- --scene=res://tools/movie_ac.tscn --autoplay --speed=6
## See tools/movie_check.sh, which also analyses the audio (per-channel peaks per tone).

const CLINIC := "res://world/clinic.tscn"
const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"


func demo_start() -> void:
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
