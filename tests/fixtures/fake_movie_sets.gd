extends "res://story/explainers/explainer_sets.gd"
## Test fixture (tests/test_contracts_v4.gd, test_movie_sets_hook): a movie's OWN scene sets, the
## way a later chapter adds them without touching story/explainers/explainer_stage.gd
## (CONTRACTS.md §3.4). Draws a bouncing word chip and a snail with the stage's helpers and
## palette, and records what it drew so the test can check the inputs arrived.

const SETS: Array[StringName] = [&"fake_word", &"fake_snail"]

## Every draw: [set id, t, duration, params.word] (the test reads and clears it).
static var drawn: Array = []


func _set_fake_word() -> void:
	drawn.append(["fake_word", t, duration, String(params.get("word", ""))])
	var k := _pop(0.2)
	s._chip(String(params.get("word", "Hi!")), Vector2(440, 200 - 20.0 * absf(sin(t * 3.0))), Stage2D.GOLD, 40, Stage2D.INK, k)
	s._text(scene_title, Vector2(440, 300), 22, Stage2D.INK, 700, 0, Palette.PAPER, 0.5, _pop(0.6))


func _set_fake_snail() -> void:
	drawn.append(["fake_snail", t, duration, String(params.get("word", ""))])
	s._snail(Stage2D.RIGHTY_AT + Vector2(40.0 * _k(0.0, duration), 0), -1.0, Palette.RIGHT_RED, Stage2D.RIGHTY_BODY, {"mood": &"happy", "arm": 0.8, "wave": true})
	s._big_sign("SNAIL!", Vector2(440, 120), _pop(0.3), -0.05)
