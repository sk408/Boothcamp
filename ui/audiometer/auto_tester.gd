class_name AoAutoTester
extends Node
## AoAutoTester: "Hoot's turn: watch the dance x8" (ui/ only, quick visit).
## Finishes the remaining measurements of an ear by the textbook, the same Hughson-Westlake
## search the autoplay bot runs (down 10 / up 5, two hits going up, 1 kHz retest, half-octaves),
## by following AudiometrySession.recommended_action() step by step. It drives the AudiOtron
## through the screen's own controls, so the player sees every beep, answer, step and stamp.
## The screen speeds time up (Engine.time_scale x SPEED) and turns scoring off while it runs.
## (v3) Day 2 tests too: it switches the route, turns the masker on and runs the plateau dance
## (heard -> noise +5, missed -> tone +5) the same way, through the MASKING buttons.
## Timers are pausable: the pause menu freezes Hoot too.

signal finished

const SPEED := 8.0
## Gaps and tone lengths vary like a careful clinician's (never a steady rhythm).
const GAPS: Array[float] = [0.9, 1.6, 1.2, 2.0, 1.0, 1.8, 1.4, 2.2]
const DURATIONS: Array[float] = [1.3, 1.6, 1.2, 1.5, 1.7, 1.4]

var running := false
var _n := 0
var _stop := false


## (coroutine) screen: the AudiometerScreen (its _auto_* methods); ear: the ear to finish.
func run(screen: Node, session: AudiometrySession, ear: String) -> void:
	running = true
	_stop = false
	var guard := 0
	while not _stop and is_inside_tree() and not session.is_ear_complete(ear) and guard < 600:
		guard += 1
		var rem := session.required_remaining(ear)
		if session.measurement(ear, session.freq).is_empty() and not rem.is_empty() and session.freq != rem[0]:
			screen.call("_auto_jump", rem[0])
			await _wait(0.5)
			continue
		var a := session.recommended_action()
		match a["action"]:
			&"present":
				await _wait(GAPS[_n % GAPS.size()])
				if _stop or not is_inside_tree():
					break
				screen.call("_auto_tone", true)
				await _wait(DURATIONS[_n % DURATIONS.size()])
				screen.call("_auto_tone", false)
				_n += 1
				var t0 := session.time
				while is_inside_tree() and session.recommended_action()["action"] == &"wait" and session.time - t0 < 6.0:
					await get_tree().process_frame
			&"softer", &"louder":
				screen.call("_auto_level", 1 if a["action"] == &"louder" else -1)
				await _wait(0.15)
			&"store":
				await _wait(0.35)
				screen.call("_auto_store", false)
				await _wait(1.0)
			&"no_response":
				await _wait(0.35)
				screen.call("_auto_store", true)
				await _wait(1.0)
			&"transducer":
				screen.call("_auto_transducer", a["target"])
				await _wait(0.6)
			&"mask_toggle":
				screen.call("_auto_mask_toggle")
				await _wait(0.5)
			&"mask_louder", &"mask_softer":
				screen.call("_auto_mask_level", 1 if a["action"] == &"mask_louder" else -1)
				await _wait(0.15)
			_:
				await get_tree().process_frame
	running = false
	finished.emit()


func stop() -> void:
	_stop = true


func _wait(s: float) -> void:
	if is_inside_tree():
		await get_tree().create_timer(s, false).timeout
