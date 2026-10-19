extends RefCounted
## A stand-in sports column for the Daily Decibel test in test_speech_seams.gd (not a test file
## itself, never in the game): a day's summary names it as "sports_script" (D8), and the paper calls
## build(column, audiometry, summary) instead of drawing its own column 2.

const UiKit := preload("res://story/ui_kit.gd")


func build(c2: VBoxContainer, aud: Dictionary, s: Dictionary) -> void:
	c2.add_child(UiKit.label("SPORTS: THE PROBE CARD", 16, Palette.INK, 700))
	var sp: Dictionary = aud.get("speech", {})
	c2.add_child(UiKit.label("tests %s, day %d" % [", ".join(PackedStringArray(sp.get("tests", []))), int(s.get("day", 0))], 14, Palette.INK_SOFT, 500))
