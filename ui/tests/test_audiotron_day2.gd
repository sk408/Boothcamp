extends TestCase
## Builder A (ui/): the AudiOtron's Chapter 2 layer. Day 1 stays exactly as it was (no overlays,
## Gus's name and pronouns); the coached bone route lesson; the masking assistant's blinking
## symbols; the air-bone gap bridge; the noise curtain / leak line on the charts; the NOISE pill on
## the masked ear's card; the LCD's masking view; the Cross-Hearing Ghost; the FLAT LINE! callout;
## bone / masked symbol placement; the patient's own quips and speech-bubble name.

const AUDIOMETER := "res://ui/audiometer/audiometer_screen.tscn"
const AUDIOGRAM := "res://ui/audiogram/audiogram.tscn"


## A perfectly consistent patient: hears iff level >= the response threshold (cross-hearing
## included), fixed latency, no tricks.
class FixedSim extends PatientSim:
	func _init(p: PatientProfile) -> void:
		super(p, 1)

	func on_tone_start(ear: String, freq: int, db: int, _gap_s: float) -> Dictionary:
		var c := condition(ear, freq)
		var heard := db >= int(c["threshold"])
		last_heard_by = StringName(c["by"]) if heard else &""
		return {"heard": heard, "press": heard, "guess": false, "latency_s": 0.5}

	func false_alarm_tick(_delta: float) -> bool:
		return false

	func anticipation_delay() -> float:
		return -1.0

	func keeps_press_after_short_tone(_e: String, _f: int, _d: int, _dur: float) -> bool:
		return true


const GAPS: Array[float] = [0.7, 1.6, 1.0, 2.1, 0.8, 1.8, 1.2, 2.4]
const SCRATCH_SAVE := "user://test_audiotron_day2_save.json"
var _n := 0
var _saved_path := ""


func before_each() -> void:
	super()
	_saved_path = Game.save_path
	Game.save_path = SCRATCH_SAVE


func after_each() -> void:
	Game.save_path = _saved_path
	if FileAccess.file_exists(SCRATCH_SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SCRATCH_SAVE))
	Hoot.clear()
	super()


func _screen() -> AudiometerScreen:
	var screen := (load(AUDIOMETER) as PackedScene).instantiate() as AudiometerScreen
	add_node(screen)
	return screen


func _tick(s: AudiometrySession, seconds: float) -> void:
	for i in int(round(seconds / 0.05)):
		s.advance(0.05)


## One presentation through the screen's own mouse path (hold the TONE pad).
func _present(screen: AudiometerScreen) -> void:
	var s := screen.session
	_tick(s, GAPS[_n % GAPS.size()])
	_n += 1
	screen._hold_add("mouse")
	_tick(s, 1.5)
	screen._hold_remove("mouse")
	_tick(s, ClinicRules.RESPONSE_WINDOW_S + 0.1)


## Follow recommended_action() on the session until the plan's sheet is done for the ear
## (or `stores` stamps were made).
func _play(screen: AudiometerScreen, e: String, stores: int = 99) -> void:
	var s := screen.session
	var guard := 0
	var done := 0
	while not s.is_ear_complete(e) and guard < 600 and done < stores:
		guard += 1
		var rem := s.required_remaining(e)
		if s.test == s.goal_test and s.measurement(e, s.freq).is_empty() and not rem.is_empty() and s.freq != rem[0]:
			s.set_freq(rem[0])
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(screen)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"mask_louder", &"mask_softer":
				s.set_mask_level(int(a["target_mask"]))
			&"mask_toggle":
				s.toggle_mask()
			&"transducer":
				s.set_transducer(a["target"])
			&"store":
				s.store()
				done += 1
			&"no_response":
				s.store_no_response()
				done += 1
			_:
				_tick(s, 0.1)
	assert_true(guard < 600, "%s %s finished" % [s.goal_test, e])
	screen._refresh()


func _bonnie_test(screen: AudiometerScreen, ear: String, coached: bool, plan: Dictionary) -> void:
	var p := Game.load_patient("bonnie") as PatientProfile
	plan["hoot_turn_after"] = 99
	screen.start_test(p, ear, coached, plan)
	if not (screen.session.sim is FixedSim):
		screen.session.sim = FixedSim.new(p)


## Bonnie: air on both ears, then unmasked bone on the right (uncoached, the oscillator on).
func _bonnie_to_masked_bone(screen: AudiometerScreen) -> void:
	Game.begin_visit("bonnie")
	_bonnie_test(screen, "right", false, {"test": "ac"})
	_play(screen, "right")
	_bonnie_test(screen, "left", false, {"test": "ac"})
	_play(screen, "left")
	_bonnie_test(screen, "right", false, {"test": "bc", "masking_controls": true})
	_play(screen, "right")


func test_day1_has_no_chapter2_overlays() -> void:
	var screen := _screen()
	await wait_frames(2)
	Game.begin_visit("gus")
	screen.start_test(Game.load_patient("gus") as PatientProfile, "right", true)
	screen._refresh()
	for k: String in screen._cards:
		var card: AoEarCard = screen._cards[k]
		assert_eq(card.audiogram.attention, {}, "%s: no blinking on Day 1" % k)
		assert_false(card.audiogram.show_gap, "%s: no gap bridge on Day 1" % k)
		assert_eq(card.audiogram.masker_view, {}, "%s: no noise curtain" % k)
		assert_eq(card.masker_text, "")
	assert_eq(screen._fx.speaker, "Gus")
	assert_eq(screen._quips, AudiometerScreen.GUS_QUIPS)
	assert_eq(screen._say("{He} heard 40! Watch {his} hand, give {him} a moment."), "He heard 40! Watch his hand, give him a moment.")
	assert_eq(screen._say("{name} wobbled: +2 on {him}, not you"), "Gus wobbled: +2 on him, not you")
	# the coach's first line on Day 1 is word for word what it was
	var line: Array = screen._coach_text(screen.session.recommended_action())
	assert_true(String(line[0]).ends_with("Watch his hand!"), String(line[0]))


func test_bonnie_quips_and_pronouns() -> void:
	var screen := _screen()
	await wait_frames(2)
	Game.begin_visit("bonnie")
	_bonnie_test(screen, "right", true, {"test": "ac"})
	assert_eq(screen._fx.speaker, "Bonnie")
	assert_eq(screen._quips, AudiometerScreen.BONNIE_QUIPS)
	assert_eq(screen._say("{He} heard 40! Watch {his} hand."), "She heard 40! Watch her hand.")
	for q: String in AudiometerScreen.BONNIE_QUIPS:
		assert_true(q.split(" ", false).size() <= 12, "short quip: %s" % q)
		assert_true(q.find("Doris") < 0 and q.find("librar") < 0, "Bonnie is not Gus: %s" % q)
	for lines: Array in AudiometerScreen.HOOT_GOLF_QUIPS.values():
		for t: String in lines:
			assert_true(screen._say(t).find("{") < 0, "no raw tokens: %s" % t)


## Coached first bone test with the masking deck: the route lesson starts on AIR so the player
## flips the switch; the coach names the key and the ROUTE button. Uncoached: straight to bone.
func test_coached_bone_route_lesson() -> void:
	var screen := _screen()
	await wait_frames(2)
	Game.begin_visit("bonnie")
	_bonnie_test(screen, "right", false, {"test": "ac"})
	_play(screen, "right")
	_bonnie_test(screen, "left", false, {"test": "ac"})
	_play(screen, "left")
	_bonnie_test(screen, "right", true, {"test": "bc", "masking_controls": true})
	var st := screen.get_state()
	assert_eq(st["goal_test"], &"bc")
	assert_eq(st["transducer"], &"phones", "the route lesson: start on air")
	assert_eq(screen.session.recommended_action()["action"], &"transducer")
	var line: Array = screen._coach_text(screen.session.recommended_action())
	assert_true(String(line[0]).begins_with("Bone time!"), String(line[0]))
	assert_eq(String(line[1]), "transducer_bone_button")
	screen.session.set_transducer(&"bone")
	assert_eq(screen.get_state()["test"], &"bc")
	# once bone stamps exist, a coached bone plan does not repeat the lesson
	_play(screen, "right", 1)
	_bonnie_test(screen, "right", true, {"test": "bc", "masking_controls": true})
	assert_eq(screen.get_state()["transducer"], &"bone")


## The masking assistant blinks the unmasked symbols that still need a masked stamp; the gap
## bridge is on; a masked stamp stops its blink.
func test_assistant_blinks_and_gap_bridge() -> void:
	var screen := _screen()
	await wait_frames(2)
	_bonnie_to_masked_bone(screen)
	var right: Audiogram = screen._cards["right"].audiogram
	var left: Audiogram = screen._cards["left"].audiogram
	assert_true(right.show_gap, "the bridge shows on Day 2")
	var bc_blink: Dictionary = (right.attention.get(&"bc", {}) as Dictionary).get("right", {})
	for f: int in ClinicRules.BC_REQUIRED:
		assert_true(bc_blink.has(f), "bone %d blinks: a 40 dB gap needs masking" % f)
	var ac_blink: Dictionary = (right.attention.get(&"ac", {}) as Dictionary).get("right", {})
	assert_true(ac_blink.has(1000), "masked air wanted at 1 kHz (50 vs 0)")
	assert_false(ac_blink.has(4000), "35 vs 5 is under 40: no masking for air at 4 kHz")
	assert_eq(left.attention, {}, "the good ear has nothing to mask")
	assert_true(right._blink(&"bc", "right", 1000) >= 0.0)
	assert_eq(right._blink(&"bc", "right", 8000), -1.0)
	# one masked bone stamp at 1 kHz: its blink stops, the others keep going
	_bonnie_test(screen, "right", false, {"test": "bc_masked", "masking_controls": true})
	_play(screen, "right", 1)
	var still: Dictionary = (right.attention.get(&"bc", {}) as Dictionary).get("right", {})
	assert_false(still.has(1000), "masked at 1 kHz: no more blink")
	assert_true(still.has(2000))
	var best := right._best_bone("right")
	assert_eq(best[1000], [10, true], "the bridge stands on the masked bone")
	assert_false(bool((best[2000] as Array)[1]), "2 kHz still on the unmasked bone")
	# drawing every overlay at once is fine
	right.queue_redraw()
	await wait_frames(2)


## Noise on: the masked (left) ear's chart shows the noise curtain at the masker level and its card
## a NOISE [n] pill; the test ear's chart shows the leak line (masker - 40), hot when overmasked.
## The LCD gets the safe window (start and limit).
func test_noise_curtain_leak_and_lcd() -> void:
	var screen := _screen()
	await wait_frames(2)
	_bonnie_to_masked_bone(screen)
	_bonnie_test(screen, "right", false, {"test": "bc_masked", "masking_controls": true})
	var s := screen.session
	s.set_freq(1000)
	s.set_level(10)
	if not s.mask_on:
		s.toggle_mask()
	s.set_mask_level(25)
	screen._refresh()
	var left_card: AoEarCard = screen._cards["left"]
	var right_card: AoEarCard = screen._cards["right"]
	assert_eq(left_card.audiogram.masker_view.get("role"), &"noise")
	assert_eq(int(left_card.audiogram.masker_view.get("db", -1)), 25)
	assert_eq(left_card.masker_text, "NOISE [25]")
	assert_eq(right_card.masker_text, "")
	assert_eq(right_card.audiogram.masker_view.get("role"), &"leak")
	assert_eq(int(right_card.audiogram.masker_view.get("db", -1)), 25 - ClinicRules.ia_rule(&"phones"))
	assert_false(bool(right_card.audiogram.masker_view.get("hot", true)))
	var mask: Dictionary = screen._lcd.view.get("mask", {})
	assert_eq(int(mask.get("initial", -1)), 25)
	assert_eq(int(mask.get("limit", -1)), 50, "bone: tone 10 + 40")
	assert_eq(String(mask.get("status", "")), "ok")
	s.set_mask_level(55)
	screen._refresh()
	assert_true(bool(right_card.audiogram.masker_view.get("hot", false)), "the leak glows when it overmasks")
	assert_eq(String((screen._lcd.view.get("mask", {}) as Dictionary).get("status", "")), "over")
	await wait_frames(2)
	s.toggle_mask()
	screen._refresh()
	assert_eq(left_card.masker_text, "", "noise off: no pill")
	assert_eq(left_card.audiogram.masker_view, {})


## An unmasked bone beep heard by the LEFT cochlea: before any bone mark only a "boo?" chip; once
## a bone mark sits next to the air mark the Cross-Hearing Ghost flies (the player's turn); the
## plateau's end pops FLAT LINE!.
func test_ghost_and_flat_line() -> void:
	var screen := _screen()
	await wait_frames(2)
	Game.begin_visit("bonnie")
	_bonnie_test(screen, "right", false, {"test": "ac"})
	_play(screen, "right")
	_bonnie_test(screen, "left", false, {"test": "ac"})
	_play(screen, "left")
	_bonnie_test(screen, "right", false, {"test": "bc", "masking_controls": true})
	var s := screen.session
	s.set_freq(1000)
	s.set_level(30)
	_tick(s, 2.0)
	assert_true(screen._fx._ghost.is_empty())
	_present(screen)
	assert_true(screen._fx._ghost.is_empty(), "no bone mark yet: only a small boo? chip")
	# one bone stamp, then the same beep again: now the Ghost flies with bone vs air
	_play(screen, "right", 1)
	s.set_freq(1000)
	s.set_level(30)
	_tick(s, 2.0)
	_present(screen)
	assert_false(screen._fx._ghost.is_empty(), "the Ghost flies")
	assert_true(String(screen._fx._ghost["text"]).ends_with("BOO!"), String(screen._fx._ghost.get("text", "")))
	assert_true(String(screen._fx._ghost["sub"]).contains("LEFT"))
	assert_true(screen._fx.busy())
	await wait_seconds(2.3)
	assert_true(screen._fx._ghost.is_empty(), "the Ghost leaves")
	# finish bone, then a masked plateau: FLAT LINE!
	_play(screen, "right")
	_bonnie_test(screen, "right", false, {"test": "bc_masked", "masking_controls": true})
	var guard := 0
	while not bool(s.plateau_info()["found"]) and guard < 80:
		guard += 1
		var a := s.recommended_action()
		match a["action"]:
			&"present":
				_present(screen)
			&"softer", &"louder":
				s.set_level(int(a["target_db"]))
			&"mask_louder", &"mask_softer":
				s.set_mask_level(int(a["target_mask"]))
			&"mask_toggle":
				s.toggle_mask()
			_:
				_tick(s, 0.1)
	assert_true(bool(s.plateau_info()["found"]))
	var texts: Array = []
	for c: Dictionary in screen._fx._calls:
		texts.append(String(c["text"]))
	assert_has(texts, "FLAT LINE!")


## Symbols: bone beside the frequency line (right ear to the left, left ear to the right), air
## and masked air on it; each sheet counts on its own.
func test_symbol_layers_and_offsets() -> void:
	var ag := (load(AUDIOGRAM) as PackedScene).instantiate() as Audiogram
	ag.ear = "both"
	ag.size = Vector2(520, 380)
	add_node(ag)
	await wait_frames(1)
	for e: String in ClinicRules.EARS:
		ag.set_point(e, 1000, 50, false, false, &"ac")
		ag.set_point(e, 1000, 50, false, false, &"ac_masked")
		ag.set_point(e, 1000, 50, false, false, &"bc")
		ag.set_point(e, 1000, 50, false, false, &"bc_masked")
	for t: StringName in ClinicRules.TESTS:
		for e: String in ClinicRules.EARS:
			assert_eq(ag.point_count(e, t), 1, "%s %s" % [e, t])
	var ac_r := ag.get_point_global_position("right", 1000, &"ac")
	assert_true(ag.get_point_global_position("right", 1000, &"bc").x < ac_r.x, "< sits left of the line")
	assert_true(ag.get_point_global_position("right", 1000, &"bc_masked").x < ac_r.x, "[ sits left of the line")
	assert_true(ag.get_point_global_position("left", 1000, &"bc").x > ac_r.x, "> sits right of the line")
	assert_true(ag.get_point_global_position("left", 1000, &"bc_masked").x > ac_r.x, "] sits right of the line")
	assert_eq(ag.get_point_global_position("right", 1000, &"ac_masked").x, ac_r.x, "triangle on the line")
	ag.show_gap = true
	ag.attention = {&"bc": {"right": {1000: true}}}
	ag.masker_view = {"freq": 1000, "db": 35, "role": &"noise"}
	await wait_frames(2)
	ag.masker_view = {"freq": 1000, "db": 60, "role": &"leak", "hot": true}
	await wait_frames(2)
	assert_true(ag._attention_count() >= 1)


## (polish) The reveal sorts many marks per ear at one frequency (air, masked air, bone, masked
## bone): its comparator must be a strict order, or Godot's sort reports "bad comparison function".
func test_reveal_order_is_strict() -> void:
	var queue: Array = []
	for e: String in ["right", "left"]:
		for test: StringName in [&"ac", &"ac_masked", &"bc", &"bc_masked"]:
			for f: int in [4000, 250, 1000, 500, 2000]:
				queue.append([e, f, 10, false, test])
	Audiogram.sort_reveal(queue)
	for a: Array in queue:
		assert_false(Audiogram.reveal_before(a, a), "irreflexive")
		for b: Array in queue:
			if a != b:
				assert_false(Audiogram.reveal_before(a, b) and Audiogram.reveal_before(b, a), "asymmetric")
	for i in range(1, queue.size()):
		var p: Array = queue[i - 1]
		var q: Array = queue[i]
		assert_true(int(p[1]) <= int(q[1]), "low to high pitch")
		if int(p[1]) == int(q[1]) and String(p[0]) != String(q[0]):
			assert_eq(String(p[0]), "right", "right ear first at each pitch")
	assert_eq(String(queue[0][0]), "right")
	assert_eq(StringName(queue[0][4]), &"ac", "air stamps before bone at the same pitch")
