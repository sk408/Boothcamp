extends "res://story/explainers/explainer_stage.gd"
## A stand-in movie stage for test_speech_seams.gd (not a test file itself, never in the game). It
## draws exactly like the real stage and writes down the stage's own `t` each time anything asks it
## for a timing helper (_k, _pop, _ring): its own sets, and a movie's sets script through s._k(),
## s._pop(), s._ring(). So a test can see which clock scene 1's old content really read during
## Steve's card hold (the stage's t shifted by card_hold - 2 s), and that the clock came back.

## The stage's t at every timing-helper call, in order (cleared by the tests).
var seen_t: Array[float] = []


func _k(a: float, b: float) -> float:
	seen_t.append(t)
	return super(a, b)


func _pop(t0: float, dur: float = 0.45) -> float:
	seen_t.append(t)
	return super(t0, dur)


func _ring(t0: float, amp: float, freq: float = 16.0, decay: float = 5.0) -> float:
	seen_t.append(t)
	return super(t0, amp, freq, decay)
