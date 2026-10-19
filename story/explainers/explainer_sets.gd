extends RefCounted
## ExplainerSets (v4, CONTRACTS.md §3.4): the base for a movie's OWN scene sets, so a later chapter
## never edits story/explainers/explainer_stage.gd. A movie points at its sets script with
##   MOVIE.stage = "res://<your chapter's folder>/<movie id>_sets.gd"
## and that script extends this base, declares its own `const SETS: Array[StringName]` and one
## `func _set_<id>() -> void` per set. The stage draws its built-in sets itself and hands any set it
## does not know to this script (then to the "card" fallback); Movies.validate() accepts a set from
## either list.
##
## Draw exactly like a built-in set: a pure function of `t` (no tweens, nodes or RNG), so pause,
## screenshots and skips stay exact. Inputs, refreshed before every draw:
##   t (seconds into the scene), duration, params (the scene's "params"), scene_id, scene_title.
## The palette and helpers are the stage's: `s` is the drawing stage (s._snail(...), s._chip(...),
## s._text(...), s._cloud(...), s._head_open(...), s._push(...) / s._pop_xf(), draw_* via s.draw_*)
## and Stage2D.<COLOR> its palette constants (Stage2D.INK, Stage2D.NOISE, Stage2D.GOLD...). The
## timing helpers _k(), _pop() and _ring() are here too. Sounds stay in the movie's "cues" data.
##
## Minimal example (tests/fixtures/fake_movie_sets.gd is a working one):
##   extends "res://story/explainers/explainer_sets.gd"
##   const SETS: Array[StringName] = [&"sparkle"]
##   func _set_sparkle() -> void:
##       s._chip(String(params.get("word", "Hi!")), Vector2(440, 220), Stage2D.GOLD, 40, Stage2D.INK, _pop(0.2))

const Stage2D := preload("res://story/explainers/explainer_stage.gd")

## The stage drawing right now (set by the stage).
var s: Stage2D
var t := 0.0
var duration := 1.0
var params: Dictionary = {}
var scene_id := ""
var scene_title := ""


## The set ids this script declares (its `const SETS`).
func set_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var sc := get_script() as Script
	var sets: Variant = sc.get_script_constant_map().get("SETS", []) if sc != null else []
	if sets is Array:
		for id: Variant in sets:
			out.append(StringName(String(id)))
	return out


## True when this script declares the set AND has its `_set_<id>()` function.
func has_set(id: StringName) -> bool:
	return set_ids().has(id) and has_method("_set_%s" % id)


## Called by the stage inside its _draw(): copy the inputs, then draw the set.
func draw_set(stage: Stage2D, id: StringName) -> void:
	s = stage
	t = stage.t
	duration = stage.duration
	params = stage.params
	scene_id = stage.scene_id
	scene_title = stage.scene_title
	call("_set_%s" % id)


## 0..1 between two scene times (eased by the caller as it likes).
func _k(a: float, b: float) -> float:
	return s._k(a, b)


## A pop-in from 0 to 1 (with a little overshoot) starting at t0.
func _pop(t0: float, dur: float = 0.45) -> float:
	return s._pop(t0, dur)


## A decaying wobble starting at t0 (bonks, rings).
func _ring(t0: float, amp: float, freq: float = 16.0, decay: float = 5.0) -> float:
	return s._ring(t0, amp, freq, decay)
