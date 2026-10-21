extends TestCase
## (Days 4-5) Day 5, Marco (story/level_marco.gd, story/games/marco_board.gd, marco_seats.gd,
## marco_dinner.gd, story/papers/paper_party_golf.gd, story/dev_marco.gd): the movie beat (announced
## only before its first play), the party plans (contract §9.21) on Hoot's textbook visit, the bill's
## options and the medals, the band ruler, the plates (keys, drag, click-then-click, the solver, a
## distractor's tip), the switch and the reveal, the seats, the dinner, the party golf card on the
## paper, Hoot's line lengths and words, a smoke run of the first beats, and (clinical review A1
## and A2, all days) the routine lines and the masking recap before the first masked test.

const LevelMarco := preload("res://story/level_marco.gd")
const MarcoBoard := preload("res://story/games/marco_board.gd")
const MarcoSeats := preload("res://story/games/marco_seats.gd")
const MarcoDinner := preload("res://story/games/marco_dinner.gd")
const PaperPartyGolf := preload("res://story/papers/paper_party_golf.gd")
const DevMarco := preload("res://story/dev_marco.gd")
const Movies := preload("res://story/explainers/movies.gd")
const Hud := preload("res://story/hud.gd")
const LevelMike := preload("res://story/level_mike.gd")
const LevelCase := preload("res://story/level_case.gd")

## Words Hoot never says on Day 5: no diagnosis, no cause, no age label (CHAPTER5 §9).
const BANNED: Array[String] = ["tumour", "tumor", "neuroma", "schwannoma", "cancer", "hidden", "processing", "presbycusis",
	"age-related", "old age", "small:"]
## The paper's banned words (CHAPTER5 §8.4): the day speaks of key words and SNRs.
const PAPER_BANNED: Array[String] = ["beeps", "spondee"]

var beats: Array = []
var phases: Array[StringName] = []
var phase_info: Array[Dictionary] = []
var resolved: Array[StringName] = []
var lines: Array[String] = []
## (A1, A2) Phases with their test ("audiometry:bc_masked"), movies ("movie:masking_recap") and
## lines ("Hoot: ..."), in order.
var timeline: Array[String] = []
## (A1) A label showed the caption _play_until_test watched for.
var caption_seen := false
var _progress: Dictionary = {}
var _settings: Dictionary = {}


func before_each() -> void:
	beats.clear()
	phases.clear()
	phase_info.clear()
	resolved.clear()
	lines.clear()
	timeline.clear()
	_progress = Game.progress.duplicate(true)
	_settings = Game.settings.duplicate(true)
	Events.awaiting_input.connect(_on_awaiting)
	Events.phase_changed.connect(_on_phase)
	Events.input_resolved.connect(_on_resolved)
	Events.dialogue_line.connect(_on_line)
	Game.begin_visit("marco")


func after_each() -> void:
	Events.awaiting_input.disconnect(_on_awaiting)
	Events.phase_changed.disconnect(_on_phase)
	Events.input_resolved.disconnect(_on_resolved)
	Events.dialogue_line.disconnect(_on_line)
	Game.progress = _progress
	Game.settings = _settings
	Hoot.clear()
	Hoot.clear_bubble_hint()
	Engine.time_scale = 1.0
	if tree.paused:
		tree.paused = false


func _on_awaiting(beat: StringName, info: Dictionary, solver: Callable) -> void:
	beats.append({"beat": beat, "info": info, "solver": solver})
	if beat == &"explainer":
		timeline.append("movie:" + String(info.get("movie", "")))


func _on_phase(p: StringName, info: Dictionary) -> void:
	phases.append(p)
	phase_info.append(info)
	timeline.append("%s:%s" % [p, String(info.get("test", ""))])


func _on_resolved(beat: StringName) -> void:
	resolved.append(beat)


func _on_line(speaker: String, text: String) -> void:
	lines.append("%s: %s" % [speaker, text])
	timeline.append("%s: %s" % [speaker, text])


func _count(beat: StringName) -> int:
	return beats.filter(func(b: Dictionary) -> bool: return b["beat"] == beat).size()


func _last(beat: StringName) -> Dictionary:
	for i in range(beats.size() - 1, -1, -1):
		if beats[i]["beat"] == beat:
			return beats[i]
	return {}


func _marco() -> PatientProfile:
	return Game.load_patient("marco") as PatientProfile


## The level from the top until `stop` (a phase), every beat solved as the bot solves it.
func _play_until(stop: StringName, max_ms: int = 60000) -> Node:
	Engine.time_scale = 6.0
	var lv: Node = (load(LevelMarco.LEVEL_SCENE) as PackedScene).instantiate()
	add_node(lv)
	var t0 := Time.get_ticks_msec()
	var handled := 0
	while Time.get_ticks_msec() - t0 < max_ms:
		await wait_frames(2)
		if phases.has(stop):
			break
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		await wait_seconds(0.05)
		assert_true((b["solver"] as Callable).is_valid(), "beat %s has a solver" % b["beat"])
		(b["solver"] as Callable).call()
	return lv


## (A1, A2) The level from the top until a phase whose info names `test` (Hoot's words in quiet:
## "wrs"), every beat solved as the bot solves it; caption_seen turns true once a label in the
## level shows `caption` (the otoscope's).
func _play_until_test(test: String, caption: String, max_ms: int = 120000) -> Node:
	Engine.time_scale = 6.0
	caption_seen = false
	var lv: Node = (load(LevelMarco.LEVEL_SCENE) as PackedScene).instantiate()
	add_node(lv)
	var t0 := Time.get_ticks_msec()
	var handled := 0
	while Time.get_ticks_msec() - t0 < max_ms:
		await wait_frames(2)
		if not caption_seen and phases.has(&"otoscopy"):
			for n: Node in lv.find_children("*", "Label", true, false):
				caption_seen = caption_seen or (n as Label).text == caption
		if timeline.has("audiometry:" + test) or timeline.has("speech:" + test):
			break
		if handled >= beats.size():
			continue
		var b: Dictionary = beats[handled]
		handled += 1
		await wait_seconds(0.05)
		assert_true((b["solver"] as Callable).is_valid(), "beat %s has a solver" % b["beat"])
		(b["solver"] as Callable).call()
	return lv


func _words(line: String) -> int:
	return line.split(" ", false).size()


## A line with its tokens at their longest: numbers as "100.5", the band and verdict as their longest
## names, the movie's title in full.
func _longest(line: String) -> String:
	var verdict := ""
	for v: String in SpeechRules.WRS_BAND_TITLES.values():
		verdict = v if _words(v) > _words(verdict) else verdict
	var out := line.replace("{title}", Movies.title(LevelMarco.MOVIE_ID)).replace("{band}", "Near-normal").replace("{verdict}", verdict)
	var re := RegEx.create_from_string("\\{[a-z_]+\\}")
	return re.sub(out, "100.5", true)


func _key_event(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = keycode
		ev.physical_keycode = keycode
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await wait_frames(2)


func _click(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = at
	ev.global_position = at
	return ev


# ---------------------------------------------------------------- the movie (contract §9.20)

func test_movie_announced_only_when_unseen() -> void:
	assert_true(Movies.has(LevelMarco.MOVIE_ID), "the party movie is in")
	assert_false(Game.is_movie_seen(LevelMarco.MOVIE_ID), "a fresh save has not seen the party movie")
	var lv := await _play_until(&"intro")
	assert_has(phases, &"intro", "the visit went on to the intro")
	var announce := "Hoot: New trick today: WORDS IN NOISE. A quick cartoon first, then our next patient!"
	assert_has(lines, announce, "the one-line announcement before the first play")
	assert_eq(_count(&"explainer"), 1, "the movie played (its explainer beat)")
	var i := phases.find(&"explainer")
	assert_true(i >= 0 and not bool(phase_info[i].get("seen", true)), "phase explainer, seen false")
	assert_eq(String(phase_info[i].get("movie", "")), LevelMarco.MOVIE_ID)
	assert_eq(String(phase_info[i].get("source", "")), "day_start")
	lv.queue_free()
	await wait_seconds(0.3)
	# once seen: only the replay choice, no announcement; the best answer skips it
	Game.mark_movie_seen(LevelMarco.MOVIE_ID)
	beats.clear()
	phases.clear()
	phase_info.clear()
	lines.clear()
	var lv2 := await _play_until(&"intro")
	assert_false(lines.has(announce), "no announcement once the movie is seen")
	var first: Dictionary = beats[0] if not beats.is_empty() else {}
	assert_eq(first.get("beat", &""), &"choice", "the first beat is the replay choice")
	var info: Dictionary = first.get("info", {})
	assert_eq(String(info.get("prompt", "")), LevelMarco.line("movie_again"), "the replay offer")
	assert_eq(int(info.get("best", -1)), 1, "skipping is the default")
	assert_eq(_count(&"explainer"), 0, "the solver skips the replay")
	var j := phases.find(&"explainer")
	assert_true(j >= 0 and bool(phase_info[j].get("seen", false)), "phase explainer, seen true")
	lv2.queue_free()
	await wait_seconds(0.3)


# ---------------------------------------------------------------- the routine (clinical review A1, A2)

## (A1, all days) A fresh speculum on the otoscope's caption, and the cases' listening-check line
## once, before the first tone test. (A2, all days) While the masking movie is unseen, the recap
## card plays once, before Hoot's masked bone where a gap shows (his measured tones decide; with no
## gap, no card: the words' noise is not the tone plateau the card teaches).
func test_routine_and_masking_recap_when_unseen() -> void:
	assert_eq(LevelMarco.line("routine"), LevelCase.ROUTINE_LINE, "the cases' own words")
	assert_eq(LevelMarco.line("masking_hint"), LevelCase.MASKING_HINT, "the cases' own words")
	assert_eq(LevelMarco.MASKING_RECAP, LevelCase.MASKING_RECAP)
	assert_eq(LevelMarco.MASKING_MOVIE, LevelCase.MASKING_MOVIE)
	Game.mark_movie_seen(LevelMarco.MOVIE_ID)
	assert_false(Game.is_movie_seen(LevelMarco.MASKING_MOVIE), "a fresh save has not seen the masking movie")
	var caption := LevelMike.SPECULUM_CAPTION % ["Marco", "RIGHT"]
	assert_true(_words(caption) <= Hoot.MAX_WORDS, caption)
	var lv := await _play_until_test("wrs", caption)
	assert_has(timeline, "speech:wrs", "the visit reached Hoot's words in quiet")
	assert_true(caption_seen, "the otoscope's caption: " + caption)
	var routine := "Hoot: " + LevelCase.ROUTINE_LINE
	assert_eq(timeline.count(routine), 1, "the listening check, once")
	assert_true(timeline.find(routine) < timeline.find("audiometry:ac"), "before the first tone test")
	var first := timeline.find("audiometry:bc_masked")
	var recap := "movie:" + LevelMarco.MASKING_RECAP
	var hint := "Hoot: " + LevelCase.MASKING_HINT
	assert_eq(timeline.count(recap), 1 if first >= 0 else 0, "the recap card once, before masked bone only")
	assert_eq(timeline.count(hint), timeline.count(recap), "then where the full movie lives")
	if first >= 0:
		var at := timeline.find(recap)
		assert_true(at > timeline.find("audiometry:bc") and at < first, "after unmasked bone, before the masked bone")
		assert_true(timeline.find(hint) > at and timeline.find(hint) < first, "right after the card")
		assert_true(lv.is_in_group(Movies.MASKING_LEVEL_GROUP), "the pause menu offers every replay movie now (E19)")
		# a second call plays nothing (only once the card has played: with no gap a call here would
		# play it for real, and nobody answers its beats once _play_until_test returns)
		await lv.call("_recap")
		assert_eq(timeline.count(recap), 1, "never twice a visit")
	else:
		assert_false(lv.is_in_group(Movies.MASKING_LEVEL_GROUP), "no gap: the pause menu keeps the day's own movie")
	lv.queue_free()
	await wait_seconds(0.5)


## (A2, all days) A watched masking movie: no recap card, no pointer, the pause menu as it was.
func test_no_masking_recap_once_the_movie_is_seen() -> void:
	Game.mark_movie_seen(LevelMarco.MOVIE_ID)
	Game.mark_movie_seen(LevelMarco.MASKING_MOVIE)
	var lv := await _play_until_test("wrs", LevelMike.SPECULUM_CAPTION % ["Marco", "RIGHT"])
	assert_has(timeline, "speech:wrs", "the visit reached Hoot's words in quiet")
	assert_false(timeline.has("movie:" + LevelMarco.MASKING_RECAP), "no recap card")
	assert_false(timeline.has("Hoot: " + LevelCase.MASKING_HINT), "no pointer to the movie")
	assert_false(lv.is_in_group(Movies.MASKING_LEVEL_GROUP), "the pause menu keeps the day's own movie")
	assert_eq(timeline.count("Hoot: " + LevelCase.ROUTINE_LINE), 1, "the listening check still")
	lv.queue_free()
	await wait_seconds(0.5)


# ---------------------------------------------------------------- plans (contract §9.21)

func test_party_plans() -> void:
	var lv := LevelMarco.new()
	lv.tones = SpeechSession.tone_results_from(_marco())
	for quick: bool in [true, false]:
		var conds: Array[String] = []
		var ids: Array[String] = []
		for n in range(1, 7):
			var p := lv.party_plan(n, quick)
			assert_eq(String(p["test"]), "sin")
			conds.append(String(p["condition"]))
			ids.append(String(p["list"]))
			assert_eq(bool(p.get("hide_loss", false)), n == 1, "hide_loss on list 1 only (list %d)" % n)
			assert_eq(bool(p.get("hoot_only", false)), n == 4 or n == 6, "hoot_only on lists 4 and 6 (list %d)" % n)
			assert_eq(p.has("compare_to"), n >= 5, "list %d compares to OMNI" % n)
			if n <= 2:
				assert_eq(String(p["transducer"]), "phones", "unaided under the earphones")
			else:
				assert_false(p.has("transducer") or p.has("level"), "aided lists: the sound field at SinTest's level (list %d)" % n)
				assert_eq(String(p["programme"]), "A" if n <= 4 else "B")
			var poured := quick and (n == 2 or n == 3 or n == 5)
			assert_eq(int(p.get("hoot_first", 0)), 3 if poured else 0, "Hoot's first courses on list %d (quick %s)" % [n, quick])
			if not bool(p.get("hoot_only", false)):
				assert_eq(p["lost_lines"], LevelMarco.MARCO_LOST, "Marco's lost lines on list %d" % n)
		assert_eq(conds, ["unaided", "unaided", "omni", "omni", "directional", "directional"] as Array[String])
		assert_eq(ids, SpeechRules.SIN_LISTS, "Party lists 1-6 in order")
	var p1 := lv.party_plan(1, true)
	assert_eq(int(p1["level"]), 50, "list 1 starts at 50: the player sets the talker")
	assert_eq(String(p1["practice"]), SpeechRules.SIN_PRACTICE_LIST)
	assert_true(bool(lv.party_plan(2, true).get("level_first", false)), "list 2: the player sets the level first")
	lv.free()


## Hoot's textbook visit runs every plan to a sheet: three slots with two lists each, six distinct
## lists, the aided ones at SIN_AIDED_DB with no band, the unaided one moderate.
func test_textbook_visit_sheets() -> void:
	var res := DevMarco.textbook_results(_marco())
	var sp: Dictionary = res["speech"]
	for e: String in ["right", "left"]:
		assert_true(((sp["srt"] as Dictionary)[e] as Dictionary).size() > 0, "SRT " + e)
		var w: Dictionary = (sp["wrs"] as Dictionary)[e]
		assert_true(String(w.get("band", "")) in ["excellent", "good"], "words in quiet %s: %s" % [e, w.get("band", "")])
	var sin: Dictionary = sp["sin"]
	var ids: Array[String] = []
	for slot: String in ["both", "aided_omni", "aided_directional"]:
		var sh: Dictionary = sin[slot]
		assert_eq(int(sh["lists_done"]), 2, slot)
		for l: Dictionary in sh["lists"]:
			ids.append(String(l["list_id"]))
			if slot != "both":
				assert_eq(int(l["level_db"]), SpeechRules.SIN_AIDED_DB, "%s at the chatting level" % slot)
		if slot != "both":
			assert_eq(String(sh["band"]), "", "no band on an aided sheet")
	assert_eq(ids.size(), 6)
	for id: String in ids:
		assert_eq(ids.count(id), 1, "fresh lists every time: " + id)
	assert_eq(String((sin["both"] as Dictionary)["band"]), "moderate", "Marco's unaided band")
	var sm: Dictionary = sp["sin_summary"]
	assert_true(bool(sm.get("real_change", false)) or (bool(sm.get("benefit_unsure", false)) and float(sm.get("benefit_db", 0.0)) > 0.0),
		"FOCUS helps: %s" % str(sm.get("benefit_db", "")))
	# the montage's line takes the poorer ear's band; the board's cards take the visit's numbers
	var cards := DevMarco.plate_cards_of(res)
	assert_eq(cards.size(), 4)
	var by := {}
	for c: Dictionary in cards:
		by[String(c["id"])] = c
	assert_eq(by.keys(), ["pta", "snr_loss", "canals", "words_quiet"], "the fixed card order")
	var avg := float((sin["both"] as Dictionary)["snr_loss"])
	assert_eq(String((by["snr_loss"] as Dictionary)["text"]), "Party test: SNR loss %.1f dB" % avg)
	assert_eq(String((by["snr_loss"] as Dictionary)["right_line"]), "Moderate SNR loss. Claim two: also true!")
	assert_true(String((by["words_quiet"] as Dictionary)["text"]).begins_with("Words in quiet: %d%% and " % int((sp["wrs"] as Dictionary)["right"]["pct"])))


# ---------------------------------------------------------------- the bill and the medals

func test_bill_options_and_medals() -> void:
	for total: int in [14, 16, 17]:
		var opts := LevelMarco.bill_options(total)
		assert_eq(opts.size(), 3)
		var by := {}
		var prefixes: Array[String] = []
		for o: Array in opts:
			by[String(o[0])] = String(o[1])
			prefixes.append(String(o[1]).substr(0, 18))
		assert_eq(String(by["loss"]), "%.1f dB" % (25.5 - total), "the bill is 25.5 - the key words")
		assert_eq(String(by["total"]), "%d dB" % total)
		assert_eq(String(by["added"]), "%.1f dB" % (25.5 + total))
		for p: String in prefixes:
			assert_eq(prefixes.count(p), 1, "unique prefix " + p)
		assert_eq(String(opts[(3 - total % 3) % 3][0]), "loss", "the right answer moves with the total")
	assert_eq(LevelMarco.bill_medal(1, 1), "gold")
	assert_eq(LevelMarco.bill_medal(2, 1), "silver")
	assert_eq(LevelMarco.bill_medal(1, 2), "silver")
	assert_eq(LevelMarco.bill_medal(2, 2), "bronze")
	assert_eq(LevelMarco.plates_medal(0, false), "gold")
	assert_eq(LevelMarco.plates_medal(0, true), "silver")
	assert_eq(LevelMarco.plates_medal(1, false), "silver")
	assert_eq(LevelMarco.plates_medal(1, true), "bronze")
	assert_eq(LevelMarco.plates_medal(2, false), "bronze")
	assert_eq(LevelMarco.history_medal(4), "gold")
	assert_eq(LevelMarco.history_medal(3), "silver")
	assert_eq(LevelMarco.history_medal(1), "bronze")


func test_band_ruler_keys_and_a_wrong_band() -> void:
	var res := DevMarco.textbook_results(_marco())
	var rec: Dictionary = (((res["speech"] as Dictionary)["sin"] as Dictionary)["both"]["lists"] as Array)[0]
	var b := MarcoBoard.new()
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 4.0
	for band: StringName in MarcoBoard.BANDS:
		assert_true(Hoot.has_anchor("band_" + String(band)), "anchor band_" + String(band))
	await b.show_bill(rec)
	# nothing on the board starts like a bill option (the mouse bot clicks the dialogue's)
	for l: Node in b.find_children("*", "Label", true, false):
		for o: Array in LevelMarco.bill_options(int(rec["total"])):
			assert_false((l as Label).text.begins_with(String(o[1])), "board label '%s' looks like an option" % (l as Label).text)
	var got := [&""]
	var pick := func() -> void:
		got[0] = await b.pick_band(9.5)
	pick.call()
	await wait_frames(4)
	var info: Dictionary = _last(&"band_pick")["info"]
	assert_eq(int(info["best"]), 2, "9.5 dB is moderate")
	assert_eq(String((info["mouse"] as Dictionary)["click"]), "band_moderate")
	assert_eq(info["bands"], ["normal", "mild", "moderate", "severe"])
	# a wrong band by key (the pointer starts on the first band)
	await wait_seconds(0.2)
	await tap_action(&"advance_dialogue")
	await wait_seconds(0.9)
	assert_eq(got[0], &"normal", "the band picked")
	assert_true(String((b.get("_caption") as Label).text).contains("Which band holds it?"), "the wrong-band caption")
	# then the right one: the pointer steps off the greyed band, Right once more, and pick
	pick.call()
	await wait_seconds(0.25)
	assert_eq(int(b.get("_pointer")), 1, "the pointer leaves the greyed band")
	await tap_action(&"speech_incorrect")
	assert_eq(int(b.get("_pointer")), 1, "a greyed band can't be pointed at")
	await tap_action(&"speech_correct")
	assert_eq(int(b.get("_pointer")), 2, "the pointer on MODERATE")
	await tap_action(&"store")
	await wait_seconds(0.4)
	assert_eq(got[0], &"moderate")
	assert_eq(_count(&"band_pick"), 2, "one beat per pick")
	assert_true(resolved.has(&"band_pick"))
	await b.pay(&"moderate")
	assert_eq(b.get("_paid"), &"moderate", "PAID")


func test_plates_keys_drag_click_and_solver() -> void:
	var res := DevMarco.textbook_results(_marco())
	var cards := DevMarco.plate_cards_of(res)
	var b := MarcoBoard.new()
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 4.0
	await b.setup_plates(cards)
	for id: String in ["plate_quiet", "plate_noisy", "clue_words_quiet", "clue_pta", "clue_snr_loss", "clue_canals"]:
		assert_true(Hoot.has_anchor(id), "anchor " + id)
	var done := [false]
	var run := func() -> void:
		await b.run_plates()
		done[0] = true
	run.call()
	await wait_seconds(0.3)
	var info: Dictionary = _last(&"plates_serve")["info"]
	assert_eq(String(info["plate"]), "quiet", "the quiet plate first")
	assert_eq(String(info["best"]), "words_quiet")
	assert_eq((info["mouse"] as Dictionary)["drag"], ["clue_words_quiet", "plate_quiet"])
	# key 3: the canals card proves neither claim (a slip and its tip)
	await _key_event(KEY_3)
	await wait_seconds(0.8)
	assert_eq(b.plate_slips, 1)
	assert_eq(String((b.get("_caption") as Label).text), "HOOT: " + MarcoBoard.line("distractor"))
	# key 2: the SNR loss proves the other claim
	await _key_event(KEY_2)
	await wait_seconds(0.8)
	assert_eq(b.plate_slips, 2)
	assert_eq(String((b.get("_caption") as Label).text), "HOOT: " + MarcoBoard.line("other_plate"))
	# click the words card, then the quiet plate
	var nodes: Array = b.get("_card_nodes")
	var words := nodes[3] as Control
	var at := words.get_global_rect().get_center()
	b.call("_on_card_input", _click(at, true), 3)
	b.call("_on_card_input", _click(at, false), 3)
	assert_eq(int(b.get("_selected")), 3, "a click selects the card")
	b.call("_on_plate_input", _click(MarcoBoard.PLATE_AT["quiet"], true), "quiet")
	await wait_seconds(0.8)
	assert_eq((b.get("_served") as Dictionary).get("quiet", -1), 3, "words in quiet on the quiet plate")
	assert_eq(String(_last(&"plates_serve")["info"]["plate"]), "noisy", "then the noisy plate")
	# drag the SNR-loss card onto the noisy plate
	var snr := nodes[1] as Control
	b.call("_on_card_input", _click(snr.get_global_rect().get_center(), true), 1)
	b.call("_on_card_input", _click(MarcoBoard.PLATE_AT["noisy"], false), 1)
	var t0 := Time.get_ticks_msec()
	while not done[0] and Time.get_ticks_msec() - t0 < 8000:
		await wait_frames(2)
	assert_true(done[0], "both plates served")
	assert_eq(b.plate_slips, 2)
	assert_false(b.pta_used)
	assert_eq(_count(&"plates_serve"), 4, "a beat per try")
	# the PTA card on the quiet plate is accepted (silver); the solver serves the rest
	var b2 := MarcoBoard.new()
	add_node(b2)
	await wait_frames(2)
	await b2.setup_plates(cards)
	var done2 := [false]
	var run2 := func() -> void:
		await b2.run_plates()
		done2[0] = true
	run2.call()
	await wait_seconds(0.3)
	await _key_event(KEY_1)
	await wait_seconds(0.8)
	assert_true(b2.pta_used, "the PTA card went on the quiet plate")
	(_last(&"plates_serve")["solver"] as Callable).call()
	t0 = Time.get_ticks_msec()
	while not done2[0] and Time.get_ticks_msec() - t0 < 8000:
		await wait_frames(2)
	assert_true(done2[0])
	assert_eq(b2.plate_slips, 0)
	assert_eq(LevelMarco.plates_medal(b2.plate_slips, b2.pta_used), "silver")


func test_pizza_switch_and_reveal() -> void:
	var res := DevMarco.textbook_results(_marco())
	var sin: Dictionary = (res["speech"] as Dictionary)["sin"]
	var b := MarcoBoard.new()
	add_node(b)
	await wait_frames(2)
	Engine.time_scale = 4.0
	await b.show_pizza()
	b.pizza_focus(true)
	await wait_seconds(0.8)
	assert_near(float(b.get("_focus_k")), 1.0, 0.01, "the back half dimmed")
	await b.show_switch()
	assert_true(Hoot.has_anchor("party_focus_switch"))
	var done := [false]
	var run := func() -> void:
		await b.flip_switch()
		done[0] = true
	run.call()
	await wait_seconds(0.3)
	var info: Dictionary = _last(&"focus_switch")["info"]
	assert_eq(String((info["mouse"] as Dictionary)["click"]), "party_focus_switch")
	await tap_action(&"advance_dialogue")
	await wait_seconds(0.6)
	assert_true(done[0], "the switch flips by key")
	assert_true(bool(b.get("_switch_on")))
	var omni: Dictionary = sin["aided_omni"]
	var focus: Dictionary = sin["aided_directional"]
	await b.show_reveal(omni, focus, 4.0, 2.7, true)
	var rv: Dictionary = b.get("_reveal")
	assert_true(bool(rv["named"]), "the chips read A: OMNI and B: FOCUS")
	assert_eq(((rv["a"] as Dictionary)["rows"] as Array).size(), 2, "two lists each")


## Marco guesses after the blind lists: "B!" when the benefit is real, unsure (and the flag) when not.
func test_reveal_guess_follows_the_benefit() -> void:
	var res := DevMarco.textbook_results(_marco())
	for real: bool in [true, false]:
		var r := res.duplicate(true)
		var focus: Dictionary = (((r["speech"] as Dictionary)["sin"] as Dictionary)["aided_directional"] as Dictionary)
		focus.merge({"benefit_db": 4.0 if real else 1.5, "crit_diff_db": 2.7, "real_change": real}, true)
		lines.clear()
		var lv := LevelMarco.new()
		var hud := Hud.new()
		add_node(hud)
		var box := DialogueBox.new()
		add_node(box)
		lv.hud = hud
		lv.dialogue = box
		lv.results = r
		lv.board = MarcoBoard.new()
		hud.call("add_game", lv.board)
		var finished := [false]
		var run := func() -> void:
			await lv.call("_reveal")
			finished[0] = true
		var handled := beats.size()
		Engine.time_scale = 6.0
		run.call()
		var t0 := Time.get_ticks_msec()
		while not finished[0] and Time.get_ticks_msec() - t0 < 15000:
			await wait_frames(2)
			while handled < beats.size():
				(beats[handled]["solver"] as Callable).call()
				handled += 1
		assert_true(finished[0], "the reveal ends")
		assert_has(lines, "Marco: B! B was the main course." if real else "Marco: A... or B? Both tasted rather similar.")
		assert_has(lines, "Hoot: " + LevelMarco.line("booth_kinder"), "the booth's honest caveat (A7)")
		assert_eq(bool(Game.get_visit_flag("benefit_unsure", real)), not real)
		if not real:
			assert_has(lines, "Hoot: " + LevelMarco.line("benefit_small_then"))
		lv.free()
		hud.queue_free()
		box.queue_free()
		await wait_frames(2)


# ---------------------------------------------------------------- the seats and the dinner

func test_seats_choice_keys_and_buttons() -> void:
	var s := MarcoSeats.new()
	add_node(s)
	await wait_frames(2)
	Engine.time_scale = 4.0
	var texts: Array[String] = []
	var prefixes: Array[String] = []
	for seat: Dictionary in LevelMarco.SEATS:
		texts.append(String(seat["text"]))
		prefixes.append(String(seat["text"]).substr(0, 18))
	for p: String in prefixes:
		assert_eq(prefixes.count(p), 1, "unique seat prefix " + p)
	var got := [-1]
	var choose := func() -> void:
		got[0] = await s.choose(LevelMarco.line("seat_prompt"), texts, 3)
	choose.call()
	await wait_frames(2)
	var info: Dictionary = _last(&"choice")["info"]
	assert_eq(info["options"], texts)
	assert_eq(int(info["best"]), 3)
	# every seat is a Button holding a Label that starts with its option (the mouse bot reads it)
	var buttons: Array = s.get("_buttons")
	for i in texts.size():
		var l := (buttons[i] as Button).find_child("Text", true, false) as Label
		assert_true(l != null and l.text.begins_with(texts[i].substr(0, 18)), "seat %d label" % i)
	await _key_event(KEY_1)
	assert_eq(int(got[0]), 0, "key 1 = the kitchen doors")
	await s.sit("kitchen")
	assert_true((buttons[0] as Button).disabled, "a wrong seat greys out")
	got[0] = -1
	choose.call()
	await wait_frames(2)
	await _key_event(KEY_1)
	assert_eq(int(got[0]), -1, "a greyed seat can't be picked again")
	(_last(&"choice")["solver"] as Callable).call()
	await wait_frames(2)
	assert_eq(int(got[0]), 3, "the solver picks the booth, back to the room")
	await s.sit("back")
	assert_false((buttons[3] as Button).disabled)


func test_dinner_plays_through() -> void:
	var d := MarcoDinner.new()
	add_node(d)
	Engine.time_scale = 4.0
	await d.open()
	assert_near(d.modulate.a, 1.0, 0.01)
	d.cheer()
	d.tray_crash()
	await d.write_review()
	assert_true(float(d.get("_review_t")) > 0.0, "the notebook page is up")
	assert_eq(MarcoDinner.REVIEW, "BOOTH CAMP. Service: precise. Owl: wise, slightly smug.")
	await d.fade_out()
	assert_near(d.modulate.a, 0.0, 0.01)


# ---------------------------------------------------------------- the paper (CHAPTER5 §8.4)

func _player_visit() -> Dictionary:
	var res := DevMarco.textbook_results(_marco())
	DevMarco.as_player_visit(res)
	return res


func test_party_golf_card_rows_and_lines() -> void:
	var res := _player_visit()
	var sp: Dictionary = res["speech"]
	var rs := PaperPartyGolf.rows(sp)
	assert_eq(rs.size(), 3, "three conditions")
	var titles: Array[String] = []
	for r: Dictionary in rs:
		titles.append(String(r["title"]))
	assert_eq(titles, ["UNAIDED, phones", "A: OMNI, speakers", "B: FOCUS, speakers"] as Array[String])
	var t0 := PaperPartyGolf.row_texts(rs[0])
	assert_eq(t0[3], "MODERATE")
	assert_eq(t0[4], "par · birdie · 3 forks", "list 2 is the day's birdie")
	assert_eq(t0[2], "%.1f dB" % float((sp["sin"] as Dictionary)["both"]["snr_loss"]))
	var t1 := PaperPartyGolf.row_texts(rs[1])
	assert_eq(t1[3], "(aided)")
	assert_true(t1[1].ends_with("*"), "Hoot's list 4 is starred: " + t1[1])
	assert_true(t1[1].split("  ")[0].ends_with("*"), "Hoot poured list 3's first courses: " + t1[1])
	var ls := PaperPartyGolf.lines(sp, DevMarco.paper_summary(res, "S"))
	assert_has(ls, PaperPartyGolf.FORMULA + "  " + PaperPartyGolf.STAR_LINE, "the formula, and the star's note")
	assert_has(ls, PaperPartyGolf.BOOTH_KINDER)
	assert_eq(PaperPartyGolf.BOOTH_KINDER, LevelMarco.line("booth_kinder"), "the paper says Hoot's A7 line")
	for tip: String in PaperPartyGolf.TIPS:
		assert_has(ls, tip)
	assert_eq(ls.back(), PaperPartyGolf.HOOT_SAYS)
	var sm: Dictionary = sp["sin_summary"]
	var want := "Directional benefit %.1f dB (%.1f needed: %s)." % [float(sm["benefit_db"]), float(sm["crit_diff_db"]),
		"real" if bool(sm["real_change"]) else "run another list each"]
	assert_has(ls, want)
	sm.merge({"benefit_db": 1.5, "real_change": false}, true)
	assert_has(PaperPartyGolf.lines(sp, {}), "Directional benefit 1.5 dB (2.7 needed: run another list each).")
	assert_true(ls.any(func(l: String) -> bool: return l.begins_with("Your key words: ")), "the counts line")
	assert_eq(PaperPartyGolf.forks_text(1), "1 fork")
	assert_eq(PaperPartyGolf.forks_text(0), "sent back")
	assert_eq(PaperPartyGolf.forks_text(-1), "Hoot's")
	for l: String in ls:
		for w: String in PAPER_BANNED:
			assert_false(l.to_lower().contains(w), "no %s on the paper: %s" % [w, l])


func test_daily_decibel_day5_paper_fits_the_window() -> void:
	for g: String in ["S", "A"]:
		var res := _player_visit()
		var summary := DevMarco.paper_summary(res, g)
		var paper: Node = (load("res://story/daily_decibel.tscn") as PackedScene).instantiate()
		add_node(paper)
		var run := func() -> void:
			await paper.call("show_summary", summary)
		run.call()
		await wait_seconds(1.0)
		var labels: Array[String] = []
		for l: Node in paper.find_children("*", "Label", true, false):
			labels.append((l as Label).text)
		assert_has(labels, PaperPartyGolf.HEADER, "the day's own sports column")
		assert_has(labels, LevelMarco.WEATHER, "the day's weather")
		assert_has(labels, LevelMarco.HEADLINES[g])
		assert_has(labels, LevelMarco.SUBHEADS[g], "Marco's review is the subhead")
		for t: String in labels:
			for w: String in PAPER_BANNED:
				assert_false(t.to_lower().contains(w), "no %s on Day 5's paper: %s" % [w, t])
		var sz: Vector2 = (paper.get("_paper") as Control).size
		assert_eq(float(paper.call("fit_scale", sz, Vector2(1280, 720))), 1.0, "fits at scale 1 (%s): %s" % [g, sz])
		var b := _last(&"results_continue")
		if not b.is_empty():
			(b["solver"] as Callable).call()
		await wait_frames(2)
		paper.queue_free()
		await wait_frames(2)


# ---------------------------------------------------------------- lines

func test_hoot_lines_fit_and_name_no_diagnosis() -> void:
	var found: Array[String] = []
	for k: String in LevelMarco.HOOT:
		found.append(LevelMarco.HOOT[k])
	for k: String in MarcoBoard.LINES:
		found.append(MarcoBoard.LINES[k])
	for c: Dictionary in MarcoBoard.plate_cards(96, 92, "Excellent", 22, 9.0, "Moderate"):
		found.append(String(c["right_line"]))
		found.append(String(c["wrong_line"]))
	var src := FileAccess.get_file_as_string((LevelMarco as Script).resource_path)
	var re := RegEx.create_from_string("\"(?:intro|hoot_turn_text)\": \"((?:[^\"\\\\]|\\\\.)*)\"")
	for m: RegExMatch in re.search_all(src):
		found.append(m.get_string(1))
	assert_true(found.size() >= 80, "found Hoot's lines (%d)" % found.size())
	for line: String in found:
		if line == "":
			continue
		var full := _longest(line)
		assert_true(_words(full) <= Hoot.MAX_WORDS, "%d words: %s" % [_words(full), full])
		assert_false(full.contains("[") or full.contains("Space") or full.contains("Enter"), "keys only through {key:}: " + full)
		var low := full.to_lower()
		for w: String in BANNED:
			assert_false(low.contains(w), "no diagnosis or cause (%s): %s" % [w, full])
	# A7: the band names, the plates' line, the booth caveat
	assert_eq(LevelMarco.line("band_normal").begins_with("Near-normal:"), true)
	assert_eq(LevelMarco.line("whole_story", {"avg": "9.0"}), "His audiogram can't tell us how he copes in noise. Measured: 9.0 dB.")
	assert_eq(LevelMarco.line("booth_kinder"), "The booth is kinder than a real restaurant. We'll check how the aids do at your table.")


func test_choice_prefixes_are_unique() -> void:
	for rd: Dictionary in LevelMarco.HISTORY:
		var prefixes: Array[String] = []
		for o: Array in rd["options"]:
			prefixes.append(String(o[0]).substr(0, 18))
		for p: String in prefixes:
			assert_eq(prefixes.count(p), 1, "history prefix " + p)
	var ins: Array[String] = [LevelMarco.INSTRUCT_BEST.substr(0, 18), LevelMarco.INSTRUCT_STRICT.substr(0, 18), LevelMarco.INSTRUCT_PARTY.substr(0, 18)]
	for p: String in ins:
		assert_eq(ins.count(p), 1, "instructions prefix " + p)


func test_level_constants() -> void:
	var ch := Game.chapter("marco")
	assert_eq(int(ch.get("day", 0)), 5)
	assert_eq(String(ch.get("scene", "")), LevelMarco.LEVEL_SCENE)
	assert_eq(String(ch.get("requires", "")), "nora")
	assert_eq(String(ch.get("patient_id", "")), LevelMarco.PATIENT_ID)
	assert_true(ResourceLoader.exists(LevelMarco.LEVEL_SCENE), "the level scene exists")
	assert_true(ResourceLoader.exists(LevelMarco.SPORTS_SCRIPT), "the sports column exists")
	assert_eq(LevelMarco.MEDAL_BEATS.size(), 5)
	for g: String in ["S", "A", "B", "C", "Do-over"]:
		assert_true(LevelMarco.HEADLINES.has(g) and LevelMarco.SUBHEADS.has(g), g)
	assert_eq(LevelMarco.SEATS.filter(func(s: Dictionary) -> bool: return bool(s.get("best", false))).size(), 1, "one right seat")
	var p := _marco()
	assert_eq(p.display_name, "Marco Polenta")
	assert_eq(float(p.speech["directional_benefit"]), 4.0)
	for f: int in [250, 500, 750, 1000, 1500, 2000, 3000, 4000, 6000, 8000]:
		assert_true(p.thresholds_right.has(f) and p.thresholds_left.has(f), "thresholds at %d" % f)


# ---------------------------------------------------------------- smoke: the first beats

## The level from the start to the AudiOtron, every beat solved like the bot does.
func test_level_smoke_to_the_tones() -> void:
	Game.mark_movie_seen(LevelMarco.MOVIE_ID)
	var lv := await _play_until(&"audiometry")
	for ph: StringName in [&"explainer", &"intro", &"history", &"otoscopy", &"instructions", &"audiometry"]:
		assert_has(phases, ph, "phase " + String(ph))
	var medals: Dictionary = Game.visit.get("medals", {})
	assert_eq(String(medals.get("history", "")), "gold", "best questions = gold")
	assert_eq(String(medals.get("instructions", "")), "gold", "right instructions first = gold")
	assert_true(bool(Game.get_visit_flag("asked_red_flags", false)) or lines.has("Hoot: " + LevelMarco.line("sweep_flags")),
		"red flags asked, or swept by Hoot")
	assert_has(lines, "Hoot: " + LevelMarco.line("after_history"))
	var clinic: Node = lv.get("clinic")
	assert_eq(String(clinic.call("patient_name")), "Marco", "Marco walked in")
	lv.queue_free()
	await wait_seconds(0.5)
