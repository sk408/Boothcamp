extends "res://story/explainers/explainer_sets.gd"
## PracticalSets (training, story-internal): the boards of Hoot's Safe Support movie, "The Steady Hand"
## (story/explainers/movies/steady_hand.gd uses this script as its stage; docs/training/PRACTICAL_EXAM.md
## §3.2). The grips are PracticalArt.draw_grip, the same drawings as Station 2's cards.
##   sh_open: the marquee card (card_hold s, questions), Hoot waving.
##   sh_grip: one big grip: tool, grip (PracticalDeck.GRIPS id), bridge_at / tool_at (when the bridge hand
##     and the tool arrive; -1 = from the start), sneeze_at (when the sneezing starts; -1 = never),
##     chip (a callout) and chip_at, chip_color ("green", "red", "gold").
##   sh_grips: the four tools of the board's Safe Support sheet, all braced, popping in one by one
##     (every 2 s from pop_at), then all sneezing from sneeze_at.

const PracticalArt := preload("res://story/training/practical/practical_art.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const SETS: Array[StringName] = [&"sh_open", &"sh_grip", &"sh_grips"]
const CHIP_COLORS: Dictionary = {"green": Color("#5bc8a3"), "red": Color("#ff8a80"), "gold": Color("#ffd23f")}


func _set_sh_open() -> void:
	var hold := float(params.get("card_hold", 7.0))
	var k := _pop(0.05, 0.5) * (1.0 - _k(hold - 0.4, hold))
	if k > 0.02:
		s._push(Stage2D._about(Vector2(440, 220), 0.0, Vector2.ONE * k))
		s._panel(Rect2(110, 60, 660, 300), Stage2D.BACKDROP, 26)
		s._text("HOOT'S MOVIE MATINEE", Vector2(440, 112), 22, Palette.SUNNY, 700)
		s._text("The Steady Hand", Vector2(440, 170), 50, Palette.PAPER, 700)
		var qs: Array = params.get("questions", [])
		for i in qs.size():
			s._chip(String(qs[i]), Vector2(440, 244 + i * 54), Palette.SUNNY, 20, Stage2D.INK, _pop(1.6 + i * 2.4))
		s._pop_xf()
	else:
		PracticalArt.draw_grip(s, Vector2(470, 190), 1.12, "oto_up", "pencil", 0.0, sin(t * 9.0) * 3.0)
	s._hoot(Vector2(96, 380), 34.0, {"pop": _pop(0.6), "mood": &"wave"})


func _set_sh_grip() -> void:
	var tool := String(params.get("tool", "oto_up"))
	var grip := String(params.get("grip", "safe"))
	var bridge_at := float(params.get("bridge_at", -1.0))
	var tool_at := float(params.get("tool_at", -1.0))
	var sneeze_at := float(params.get("sneeze_at", -1.0))
	var g: Dictionary = PracticalDeck.GRIPS[grip]
	var j := PracticalArt.sneeze(t - sneeze_at) if sneeze_at >= 0.0 and t >= sneeze_at else 0.0
	var wob := 0.0 if bool(g["braced"]) else sin(t * 9.0) * 3.0
	var o := {"bridge": bool(g["bridge"]) and t >= bridge_at, "tool": t >= tool_at}
	PracticalArt.draw_grip(s, Vector2(470, 190), 1.12, tool, grip, j, wob, o)
	if j > 0.15:
		s._chip("ACHOO!", Vector2(220, 120), Palette.CORAL, 30)
	var chip := String(params.get("chip", ""))
	if chip != "":
		var ca := float(params.get("chip_at", 1.0))
		s._chip(chip, Vector2(700, 410), CHIP_COLORS.get(String(params.get("chip_color", "gold")), Palette.SUNNY), 20, Stage2D.INK, _pop(ca))


func _set_sh_grips() -> void:
	var pop_at := float(params.get("pop_at", 0.4))
	var sneeze_at := float(params.get("sneeze_at", 8.5))
	var j := PracticalArt.sneeze(t - sneeze_at) if t >= sneeze_at else 0.0
	for i in PracticalDeck.TOOLS.size():
		var tool: String = PracticalDeck.TOOLS[i]
		var k := _pop(pop_at + i * 2.0)
		if k <= 0.01:
			continue
		var x := 116 + i * 216
		s._panel(Rect2(x - 100, 40, 200, 340), Palette.PAPER, 20)
		PracticalArt.draw_grip(s, Vector2(x + 6, 190), 0.56, tool, "safe", j)
		s._text(String(PracticalDeck.TOOL_WORDS[tool]), Vector2(x, 360), 15, Palette.INK, 700)
	if j > 0.15:
		s._chip("ACHOO!", Vector2(440, 22), Palette.CORAL, 24)
