extends "res://story/explainers/explainer_sets.gd"
## A stand-in movie sets script for test_speech_seams.gd (not a test file itself, never in the game):
## two scene-1 sets with Steve's card hold (params.card_hold), one done the right way and one the
## wrong way, so the test can prove its card-hold check catches the mistake before a real choir or
## quiet set needs it. In a sets script `t` is only a copy of the stage's: _k(), _pop(), _ring() and
## every s._* helper read the STAGE's t, so the hold must shift s.t.

const SETS: Array[StringName] = [&"hold_right", &"hold_wrong"]


## The pattern for _set_choir() / _set_quiet(): the card while it holds, then the old content on the
## stage's clock shifted by card_hold - 2 s, then both clocks back before the curtains.
func _set_hold_right() -> void:
	var hold := float(params.get("card_hold", 2.0))
	var real_t := s.t
	var card_out := _k(hold, hold + 0.45)
	if card_out < 1.0:
		s._chip("Today's mystery?", Vector2(440, 220), Stage2D.GOLD, 28, Stage2D.INK, 1.0 - card_out)
	s.t = real_t - (hold - 2.0)
	t = s.t
	s._chip("old content", Vector2(440, 320), Palette.PAPER, 20, Stage2D.INK, _pop(0.5))
	s.t = real_t
	t = real_t
	s._curtains(Stage2D._ease_out(_k(0.1, 1.2)))


## The mistake: only the local copy is shifted, so the old content's _pop() still reads the real t
## and pops in behind the card while it holds.
func _set_hold_wrong() -> void:
	var hold := float(params.get("card_hold", 2.0))
	var real_t := t
	var card_out := _k(hold, hold + 0.45)
	if card_out < 1.0:
		s._chip("Today's mystery?", Vector2(440, 220), Stage2D.GOLD, 28, Stage2D.INK, 1.0 - card_out)
	t = real_t - (hold - 2.0)
	s._chip("old content", Vector2(440, 320), Palette.PAPER, 20, Stage2D.INK, _pop(0.5))
	t = real_t
	s._curtains(Stage2D._ease_out(_k(0.1, 1.2)))
