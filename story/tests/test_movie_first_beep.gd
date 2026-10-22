extends TestCase
## (clinical review D1-8) Day 1's movie, Hoot's "The First Beep" (story/explainers/movies/first_beep.gd,
## its sets story/case_movies/first_beep_sets.gd): registered, valid and quiet, listed as "Day 1", short
## lines, the ladder stores the level heard twice going up, and every scene draws.

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const LevelGus := preload("res://story/level_gus.gd")


func _words(s: String) -> int:
	return s.split(" ", false).size()


func test_first_beep_movie() -> void:
	var id := LevelGus.MOVIE_ID
	assert_eq(id, "first_beep")
	var bad := Movies.validate(id, Stage2D.SETS)
	assert_true(bad.is_empty(), "%s: %s" % [id, ", ".join(bad)])
	assert_false(Movies.is_short(id), "a full movie")
	assert_has(Movies.replay_ids(), id, "on the title's list")
	assert_eq(Movies.day_label(id), "Day 1")
	assert_has(Movies.for_level("gus", false), id, "Day 1's pause menu")
	var player_script: GDScript = load("res://story/explainers/explainer_player.gd")
	var cue_max := float(player_script.get_script_constant_map()["CUE_MAX_DB"])
	var m := Movies.movie(id)
	assert_true(float((m["scenes"][0] as Dictionary).get("duration", 0.0)) >= 7.0, "the lead-in card holds")
	for sc: Dictionary in m["scenes"]:
		for c: Variant in sc.get("captions", []):
			assert_true(Movies.word_count(String(c)) <= Movies.MAX_CAPTION_WORDS, String(c))
		for cue: Dictionary in sc.get("cues", []):
			assert_has(Sfx.SOUNDS, StringName(String(cue["sfx"])), "%s: a known Sfx" % sc["id"])
			assert_true(float(cue.get("vol_db", 0.0)) <= cue_max, "%s: %s is quiet" % [sc["id"], cue["sfx"]])
		if String(sc["id"]) == "ladder":
			# down 10 after a heard tone, up 5 after a miss; two heard going up land on one level
			var p: Dictionary = sc["params"]
			var lv: Array[int] = [int(p["start"])]
			var ups: Array[int] = []
			var heard: Array = p["heard"]
			for i in heard.size():
				if bool(heard[i]) and i > 0 and not bool(heard[i - 1]):
					ups.append(lv[i])
				lv.append(lv[i] - 10 if bool(heard[i]) else lv[i] + 5)
			assert_eq(ups.size(), 2, "heard twice going up")
			assert_eq(ups[0], ups[1], "both at the same level")
			assert_eq(ups[0], 30, "the caption's 30 dB")
	for l: String in [LevelGus.MOVIE_NEW, LevelGus.MOVIE_AGAIN, LevelGus.MOVIE_SKIPPED]:
		assert_true(_words(l) <= 18, l)


func test_first_beep_draws_every_scene() -> void:
	var st: Control = Stage2D.new()
	st.size = Vector2(880, 440)
	add_node(st)
	var m := Movies.movie("first_beep")
	st.call("use_movie", m)
	for sc: Dictionary in m["scenes"]:
		st.call("show_scene", sc)
		var d := float(sc["duration"])
		for tt: float in [0.0, d * 0.2, d * 0.45, d * 0.7, d * 0.9, d]:
			st.set("t", tt)
			st.queue_redraw()
			await wait_frames(1)
	st.queue_free()
