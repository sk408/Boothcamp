extends CanvasLayer
## ExplainerPlayer (v4, CONTRACTS.md §3.4): plays one of Hoot's movies (story/explainers/movies.gd)
## as a cartoon short: a cinema screen (the stage animates each scene's set), Hoot's captions with a
## typewriter and a quiet gibberish voice, and quiet Sfx stings (the scene "cues"). Data-driven: the
## movie file is a scene list; this player never knows what a movie is about.
##
## Usage (story):  var p: CanvasLayer = load(PLAYER).instantiate(); add_child(p)
##                 var r: Dictionary = await p.call("play", "masking", "day_start"); p.queue_free()
## r = {"movie", "skipped", "scenes_seen", "source", "watched"}; the signal `finished` carries the same.
## Controls (polish: like the dialogue box): Space / Enter / a click on the screen / the "Next" button
## = advance(): finish the typing, else the scene's next caption, else the next scene. Esc and the
## "Skip movie" button = skip the movie. P (or the "II" button) pauses when the game is not paused
## already. The last scene's button says "Start the day" (day start) or "Done" (replays).
## Seen: Game.mark_movie_seen(id) only once the movie reached its "seen_at" scene (default: the last
## one), so an early Esc plays it again next visit ("watched" in the result).
## Beat: Events.awaiting_input(&"explainer", {movie, title, scenes, source}, skip_all).
## Events: explainer_started, explainer_scene (every scene), explainer_finished. Game.mark_movie_seen().
## Process mode INHERIT: under a level it pauses with the game; under the pause menu (ALWAYS) it
## plays while the game stays paused. Layer 85: above the Hoot bubble (80), below the pause menu (90).
## Music: ducked while it plays through Sfx.music_duck(on, owner) (reference-counted owners), so a
## replay over the AudiOtron never brings the marimba back, and freeing it mid-play undoes its duck.
## Sounds: Sfx stings at -6 dB or softer, Hoot's voice syllables (-24 dBFS peaks): never loud, and
## the masking noise itself is only drawn (CONTRACTS.md §1.3).

signal finished(result: Dictionary)

const Movies := preload("res://story/explainers/movies.gd")
const Stage2D := preload("res://story/explainers/explainer_stage.gd")
const Voice := preload("res://story/voice.gd")
const Portraits := preload("res://story/portraits.gd")
const UiKit := preload("res://story/ui_kit.gd")

const LAYER := 85
const CHARS_PER_SECOND := 42.0
## A scene lasts at least its "duration", and long enough to type and read its last caption.
const READ_S := 1.6
## Keys are ignored this long after the movie starts (the key that started the day).
const INPUT_GRACE_S := 0.3
## The loudest a cue may play (dB, on top of the Sfx -18 dBFS normalisation).
const CUE_MAX_DB := -6.0
const VOICE_DB := -4.0

var movie_id := ""
var movie: Dictionary = {}
var source := ""
var scene_index := -1
var skipped := false
## Dev scenes only (dev_explainer --from=): the scene to start at.
var start_scene := 0
var _playing := false
var _next := false
var _age := 0.0
var _scene_t := 0.0
var _scene_len := 1.0
var _caps: Array = []
var _cap_at: Array = []
var _cap_i := -1
var _typed := 0.0
var _last_syl := 0
var _cues: Array = []
var _cue_i := 0
var _talk := false
var _rng := RandomNumberGenerator.new()
var _voice_players: Array[AudioStreamPlayer] = []
var _voice_next := 0
var _seen_at := 0      # the scene index that counts as "seen" (movie key "seen_at", default the last)

var _root: Control
var _backdrop: Control
var _stage: Control
var _caption: Label
var _face: Control
var _title: Label
var _dots: Control
var _next_btn: Button
var _skip_btn: Button
var _pause_btn: Button
var _hints: HBoxContainer


func _ready() -> void:
	layer = LAYER
	_rng.seed = 2468   # its own RNG: the movie never shifts Game.rng (autoplay stays reproducible)
	_build()
	visible = false


func is_playing() -> bool:
	return _playing


## Freed mid-play (P during the day-start movie, then Quit to title): undo the music duck and leave
## the group, so nothing stays silent or "playing".
func _exit_tree() -> void:
	if _playing:
		_playing = false
		_duck(false)
	if is_in_group("explainer_player"):
		remove_from_group("explainer_player")


func _duck(on: bool) -> void:
	if Sfx.has_method("music_duck"):
		Sfx.music_duck(on, "explainer:%d" % get_instance_id())


## (coroutine) Play a movie to the end (or until skipped). Returns the result dictionary.
func play(id: String, p_source: String = "menu") -> Dictionary:
	movie_id = id
	source = p_source
	movie = Movies.movie(id)
	skipped = false
	scene_index = -1
	var scenes: Array = movie.get("scenes", [])
	if scenes.is_empty():
		push_warning("ExplainerPlayer: no movie '%s'" % id)
		var none := {"movie": id, "skipped": true, "scenes_seen": 0, "source": source}
		finished.emit(none)
		return none
	_playing = true
	_age = 0.0
	visible = true
	add_to_group("explainer_player")
	_title.text = "%s: %s" % [String(movie.get("title", "")), String(movie.get("subtitle", ""))]
	_seen_at = scenes.size() - 1
	var seen_id := String(movie.get("seen_at", ""))
	for k in scenes.size():
		if String((scenes[k] as Dictionary).get("id", "")) == seen_id:
			_seen_at = k
	_stage.call("use_movie", movie)   # a movie may bring its own sets (MOVIE.stage, CONTRACTS.md §3.4)
	_refresh_hints()
	_duck(true)
	Juice.bounce_in(_stage, 0.4)
	Events.explainer_started.emit(id, source)
	Events.awaiting_input.emit(&"explainer", {"movie": id, "title": String(movie.get("title", "")), "scenes": scenes.size(), "source": source}, skip_all)
	for i in range(clampi(start_scene, 0, scenes.size() - 1), scenes.size()):
		if skipped or not is_inside_tree():
			break
		await _play_scene(i, scenes[i])
	_playing = false
	if is_in_group("explainer_player"):
		remove_from_group("explainer_player")
	_duck(false)
	var watched := scene_index >= _seen_at
	if watched:
		Game.mark_movie_seen(id)
	Events.explainer_finished.emit(id, skipped)
	Events.input_resolved.emit(&"explainer")
	var r := {"movie": id, "skipped": skipped, "scenes_seen": scene_index + 1, "source": source, "watched": watched}
	finished.emit(r)
	return r


## Next scene now (dev tools and tests; players use advance()).
func skip_scene() -> void:
	if _playing:
		_next = true


## (polish) Space / Enter / a click / the "Next" button, like the dialogue box: finish the caption
## being typed; else jump to the scene's next caption (the drawing jumps with it: _scene_t moves to
## that caption's time, and the cues in between are skipped, never played in a burst); else the
## next scene (on the last scene: the end of the movie, watched).
func advance() -> void:
	if not _playing:
		return
	if _cap_i >= 0 and _caption.visible_characters >= 0 and _caption.visible_characters < _caption.text.length():
		_caption.visible_characters = -1
		_talk = false
		return
	if _cap_i + 1 < _caps.size():
		var at := float(_cap_at[_cap_i + 1])
		if at > _scene_t:
			_scene_t = at
			while _cue_i < _cues.size() and float((_cues[_cue_i] as Dictionary).get("t", 0.0)) < at - 0.05:
				_cue_i += 1
			_stage.set("t", _scene_t)
		return
	skip_scene()


## Skip the rest of the movie (Esc / the "Skip movie" button / the beat's solver).
func skip_all() -> void:
	if _playing:
		skipped = true
		_next = true


func _play_scene(i: int, sc: Dictionary) -> void:
	scene_index = i
	_next = false
	_scene_t = 0.0
	_caps = sc.get("captions", [])
	var dur := maxf(1.0, float(sc.get("duration", 4.0)))
	_cap_at = sc.get("caption_at", [])
	if _cap_at.size() != _caps.size():
		_cap_at = []
		for k in _caps.size():
			_cap_at.append(0.3 + dur * k / maxf(1.0, _caps.size()))
	_cap_i = -1
	_caption.text = ""
	_cues = (sc.get("cues", []) as Array).duplicate()
	_cues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("t", 0.0)) < float(b.get("t", 0.0)))
	_cue_i = 0
	var speed := maxf(0.2, float(Game.settings.get("text_speed", 1.0)))
	_scene_len = dur
	if not _caps.is_empty():
		var last := String(_caps[-1])
		_scene_len = maxf(dur, float(_cap_at[-1]) + last.length() / (CHARS_PER_SECOND * speed) + READ_S)
	_stage.set("scene_no", i + 1)
	_stage.call("show_scene", sc)
	_dots.queue_redraw()
	var last := i == (movie.get("scenes", []) as Array).size() - 1
	_next_btn.text = ("Start the day" if source == "day_start" else "Done") if last else "Next"
	Events.explainer_scene.emit(movie_id, i, String(sc.get("id", "")))
	while _scene_t < _scene_len and not _next:
		if not is_inside_tree():
			return
		await get_tree().process_frame


func _process(delta: float) -> void:
	if not _playing:
		return
	_age += delta
	_scene_t += delta
	_stage.set("t", _scene_t)
	# captions: the next one starts at its time; the typewriter reveals it with Hoot's babble
	while _cap_i + 1 < _caps.size() and _scene_t >= float(_cap_at[_cap_i + 1]):
		_cap_i += 1
		_caption.text = String(_caps[_cap_i])
		_caption.visible_characters = 0
		_typed = 0.0
		_last_syl = 0
		Events.dialogue_line.emit(String(movie.get("narrator", "Hoot")), _caption.text)
	if _cap_i >= 0 and _caption.visible_characters >= 0 and _caption.visible_characters < _caption.text.length():
		_typed += delta * CHARS_PER_SECOND * maxf(0.2, float(Game.settings.get("text_speed", 1.0)))
		var n := mini(int(_typed), _caption.text.length())
		_caption.visible_characters = n
		if n / 3 != _last_syl:
			_last_syl = n / 3
			_syllable(_last_syl)
		_talk = (n / 2) % 2 == 0
		if n >= _caption.text.length():
			_caption.visible_characters = -1
			_talk = false
	else:
		_talk = false
	# cues: quiet stings at their time
	while _cue_i < _cues.size() and _scene_t >= float((_cues[_cue_i] as Dictionary).get("t", 0.0)):
		var cue: Dictionary = _cues[_cue_i]
		_cue_i += 1
		if cue.has("sfx"):
			Sfx.play(StringName(String(cue["sfx"])), float(cue.get("pitch", 1.0)), minf(float(cue.get("vol_db", -10.0)), CUE_MAX_DB))
	_face.queue_redraw()
	_backdrop.queue_redraw()
	_pause_btn.visible = not get_tree().paused


func _input(event: InputEvent) -> void:
	if not _playing or not visible:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if _age < INPUT_GRACE_S:
		if event is InputEventKey or event is InputEventAction:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		skip_all()
	elif event.is_action_pressed(&"advance_dialogue") or event.is_action_pressed(&"ui_accept"):
		advance()
	else:
		return
	Sfx.play(&"blip", 1.3, -12.0)
	get_viewport().set_input_as_handled()


func _syllable(i: int) -> void:
	if _voice_players.is_empty() or not Voice.has_voice(String(movie.get("narrator", "Hoot"))):
		return
	var bank: Array = Voice.bank_for(String(movie.get("narrator", "Hoot")))
	if bank.is_empty():
		return
	var p := _voice_players[_voice_next]
	_voice_next = (_voice_next + 1) % _voice_players.size()
	p.stream = bank[absi(i) % bank.size()]
	p.pitch_scale = _rng.randf_range(0.94, 1.07)
	p.volume_db = VOICE_DB
	p.play()


func _refresh_hints() -> void:
	for c in _hints.get_children():
		c.queue_free()
	if UiKit.show_key_hints():
		_hints.add_child(UiKit.hint_panel([[Game.key_label(&"advance_dialogue")], "or click: next", ["Esc"], "skip the movie", ["P"], "pause"], 15))


# ---------------------------------------------------------------- layout

func _build() -> void:
	_root = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	add_child(_root)
	_backdrop = UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	_backdrop.draw.connect(_draw_backdrop)
	_backdrop.gui_input.connect(func(e: InputEvent) -> void:
		var mb := e as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _age >= INPUT_GRACE_S:
			advance())
	_root.add_child(_backdrop)
	_stage = Stage2D.new()
	_stage.anchor_left = 0.5
	_stage.anchor_right = 0.5
	_stage.offset_left = -440
	_stage.offset_right = 440
	_stage.offset_top = 64
	_stage.offset_bottom = 64 + 440
	_stage.pivot_offset = Vector2(440, 220)
	_root.add_child(_stage)
	_title = UiKit.label("", 20, Palette.SUNNY, 700)
	_title.position = Vector2(28, 20)
	_root.add_child(_title)
	_dots = Control.new()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.anchor_left = 1.0
	_dots.anchor_right = 1.0
	_dots.offset_left = -360
	_dots.offset_right = -84   # clear of the pause menu's corner button
	_dots.offset_top = 22
	_dots.offset_bottom = 46
	_dots.draw.connect(_draw_dots)
	_root.add_child(_dots)
	# the caption bar: Hoot's face and his line
	var bar := UiKit.panel(Palette.PAPER, Palette.INK, 24)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_left = -520
	bar.offset_right = 520
	bar.offset_top = -200
	bar.offset_bottom = -76
	_root.add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(h)
	_face = Control.new()
	_face.custom_minimum_size = Vector2(96, 96)
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.draw.connect(func() -> void:
		Portraits.draw(_face, String(movie.get("narrator", "Hoot")), _face.size * 0.5, 44.0, _talk, false))
	h.add_child(_face)
	_caption = UiKit.label("", 27, Palette.INK, 600)
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_caption.custom_minimum_size = Vector2(0, 96)
	h.add_child(_caption)
	# buttons + key hints along the bottom
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_top = -64
	row.offset_bottom = -14
	_root.add_child(row)
	_hints = HBoxContainer.new()
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_hints)
	_next_btn = UiKit.button("Next", &"", Vector2(170, 46))
	_next_btn.pressed.connect(advance)
	row.add_child(_next_btn)
	_skip_btn = UiKit.button("Skip movie", &"AccentButton", Vector2(170, 46))
	_skip_btn.pressed.connect(skip_all)
	row.add_child(_skip_btn)
	# (polish) the mouse's pause: the level's pause menu (the movie freezes with the game under it)
	_pause_btn = UiKit.button("II", &"GhostButton", Vector2(46, 46))
	_pause_btn.tooltip_text = "Pause (P)"
	_pause_btn.add_theme_font_override("font", UiKit.font(700))
	_pause_btn.pressed.connect(func() -> void:
		var pm := get_tree().get_first_node_in_group("pause_menu")
		if pm != null and not get_tree().paused:
			pm.call("open"))
	row.add_child(_pause_btn)
	var bus: StringName = AudioSafety.VOICE_BUS if AudioServer.get_bus_index(AudioSafety.VOICE_BUS) >= 0 else &"Master"
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_voice_players.append(p)


func _draw_backdrop() -> void:
	var r := Rect2(Vector2.ZERO, _backdrop.size)
	_backdrop.draw_rect(r, Color("#2a2140"))
	# velvet curtains on both sides, gently swaying
	var sway := sin(_age * 1.3) * 6.0
	for side: float in [0.0, 1.0]:
		var x0 := r.size.x * side
		var dir := 1.0 if side == 0.0 else -1.0
		var pts := PackedVector2Array([Vector2(x0, 0), Vector2(x0 + dir * 150.0, 0), Vector2(x0 + dir * (110.0 + sway), r.size.y * 0.55), Vector2(x0 + dir * 170.0, r.size.y), Vector2(x0, r.size.y)])
		_backdrop.draw_colored_polygon(pts, Color("#c4453f"))
		for k in 3:
			var fx := x0 + dir * (30.0 + 40.0 * k)
			_backdrop.draw_line(Vector2(fx, 0), Vector2(fx + dir * sway * 0.5, r.size.y), Color("#9e2f2b"), 6.0, true)
	# a scalloped valance along the top
	var n := int(r.size.x / 80.0) + 1
	for i in n:
		_backdrop.draw_circle(Vector2(i * 80.0 + 40.0, 0), 34.0, Color("#c4453f"))
	_backdrop.draw_rect(Rect2(0, 0, r.size.x, 12), Color("#9e2f2b"))


func _draw_dots() -> void:
	var n := (movie.get("scenes", []) as Array).size()
	if n == 0:
		return
	var w := _dots.size.x
	var step := minf(26.0, w / n)
	for i in n:
		var c := Vector2(w - (n - i) * step + step * 0.5, _dots.size.y * 0.5)
		var col := Palette.SUNNY if i == scene_index else (Palette.PAPER if i < scene_index else Color(Palette.PAPER, 0.3))
		_dots.draw_circle(c, 7.0 if i == scene_index else 5.0, col)
