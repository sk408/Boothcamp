class_name SpModeParty
extends SpMode
## SpModeParty: the SPEECH screen's PARTY mode, the Party Noise Test (plan test "sin"; CONTRACTS.md
## §9.18, §9.19; docs/CHAPTER5.md §5). SpMode.make() loads it by path, so speech_screen.gd never names
## it, and Day 3's SRT (no mode) never reaches a line of it.
##
## The layout: the answer bubble (taller) over the SpSentenceCard, which runs along the bottom of the
## left and middle columns; SpCourses (the six plates and the dining room) in the middle; the
## SpSnrMeter in the meter's slot; the SpPartyBooth over the booth window. The ladder, the agreement
## meter, the word card, the LCD's THIS LEVEL line, MASK and STORE hide (the LCD says NO MASKING where
## its NOISE box was). The deck: LEVEL + SENTENCE
## (SOFTER, PRESENT, LOUDER) . KEY WORDS (MISSED, GOT IT, ALL GOT) . BILL (LOCK IN).
##
## One sentence (§9.18.2): PRESENT starts the party, then the talker (BABBLE_LEAD_S later; both
## quiet, both capped by AudioSafety, both silent in Hoot's x8 turn). The answer pops into the bubble
## and the chips wake with the focus on chip 1. The walk (speech_correct / speech_incorrect, or GOT IT
## / MISSED) marks the focus chip; 1-5 (party_word_n) or a chip click flips a chip; a right click marks
## it missed; G or ALL GOT ticks all five. LOCK IN (store: S / Enter) bills the sentence, blanks as
## missed: the plate fills and Events.party_sentence_locked follows. PRESENT before LOCK IN is refused
## (lock_first) with a wiggle of LOCK IN. After sentence 6, Events.party_list_done, the total lands,
## then celebrate() and complete_list().
##
## Hoot's turns (H14-H16): the practice (plan practice) is a turn at speed 1 that hoot_step() ends
## after its LOCK IN; hoot_first N is a turn at the plan's speed that ends once sentence N is locked;
## any other turn (hoot_only, hoot_turn_after) runs to the end of the list by recommended_action().
##
## Plan keys read here besides SinTest's: revealed (bool, default false: the blind tasting is over, so
## the LCD names the programme "A: OMNI" / "B: FOCUS" and the booth shows FOCUS's bright front half).

## The party starts this long before the talker.
const BABBLE_LEAD_S := SpeechVoice.BABBLE_LEAD_S
## ... and stops this long after him.
const BABBLE_TAIL_S := SpeechVoice.BABBLE_TAIL_S
## Hoot's practice ticks its chips one at a time (game seconds, at speed 1).
const PRACTICE_TICK_S := 0.45
## The total lands, then the list completes this long after the last LOCK IN.
const END_SHOW_S := 1.4
## The coach's quiet line: no line, and the SRT's lines are not used either.
const QUIET: Array = ["", "", ""]
## Marco's asides inside a list (CHAPTER5 §5.3; Appendix B).
const ASIDE_PRACTICE := "An amuse-bouche! A little taste before the meal."
const ASIDE_LOUDER_SOUP := "It's louder. But louder soup is still soup."
## Hoot's first line on a sentence's answer, and the key-fix line (18 words or fewer).
const COACH_TICK := "Tick the key words {he} got. Little words like 'the' never count."
const COACH_FIX := "Check chip %d against what {he} SAID: {key:party_word_%d} flips it."
const COACH_LEVEL := "Set the talker to %d dB HL: {key:%s}. The party follows by itself."
const COACH_PRACTICE := "A practice sentence first: {key:present_tone}. I'll score it; you watch the chips."
const COACH_FIRST := "Your turn. {key:present_tone} plays the first sentence."
const COACH_MAIN := "Ten dB gap. Most people still get everything here. Watch {name}."
const COACH_LISTEN := "Listen... what does {he} say back?"
const WAIT_ANSWER := "Wait for {his} answer, then tick the key words {he} said."
const PLAY_FIRST := "Play a sentence first: {key:present_tone}. Then tick what {he} said."
## The bubble before the first answer, and the LCD's note where the NOISE box was (no masking here).
const IDLE_BUBBLE := "(waiting for a sentence)"
const NOISE_NOTE_PHONES: Array[String] = ["NO MASKING", "same mix in", "both ears"]
const NOISE_NOTE_FIELD: Array[String] = ["NO MASKING", "speakers reach", "both ears"]

var _card: SpSentenceCard
var _courses: SpCourses
var _snr: SpSnrMeter
var _party_booth: SpPartyBooth
var _lock_btn: SpButton
var _all_btn: SpButton
var _plan: Dictionary = {}
## Every timer and sound callback checks the serial it was made for (a new list or a new sentence).
var _serial := 0
var _snd := 0
## The next Hoot turn is the practice (act present asked for it); the turn running now.
var _practice_req := false
var _turn: StringName = &""
var _answer_at := -100.0
## The sentence card's rows for this list (its longest sentence at the smallest chip font).
var _rows := 1
var _items: Array[Dictionary] = []
## The plate the last LOCK IN filled (callouts land there).
var _callout_at := Vector2.ZERO
## Each LOCK IN's own number: Hoot names only the first wrong chip of a lock (the others flash).
var _lock_n := 0
var _misscored_lock := -1
var _lock_points := 0
var _lock_ok := false
var _done_sheet: Dictionary = {}
var _end_started := false
## The coach's line as shown (keys filled), so LOCK IN can take it down from sentence 2 on.
var _coach_shown := ""


# ---------------------------------------------------------------- lifecycle

func setup(s: SpeechScreen) -> void:
	super.setup(s)
	var root := s.ui_root()
	_card = SpSentenceCard.new()
	_card.name = "PartySentenceCard"
	_courses = SpCourses.new()
	_courses.name = "PartyCourses"
	_snr = SpSnrMeter.new()
	_snr.name = "PartySnrMeter"
	# in the base widgets' layer: under the fx, Hoot's perch and the Hoot-turn banner
	var at := s.card.get_index() + 1
	for w: Control in [_card, _courses, _snr]:
		w.visible = false
		root.add_child(w)
		root.move_child(w, at)
		at += 1
	_party_booth = SpPartyBooth.new()
	_party_booth.name = "PartyBooth"
	_party_booth.visible = false
	root.add_child(_party_booth)
	root.move_child(_party_booth, s.booth.get_index() + 1)
	_party_booth.follow(s.booth)
	_card.chip_pressed.connect(_on_chip)
	_card.chip_right_pressed.connect(_on_chip_right)


func make_buttons() -> Dictionary:
	_lock_btn = screen.make_button("party_lock_button", "LOCK IN", AoButton.Icon.NONE, SpButton.Glyph.LOCK, Palette.MINT, &"store", &"lock")
	_lock_btn.font_size = 20
	_all_btn = screen.make_button("party_all_got_button", "ALL GOT", AoButton.Icon.NONE, SpButton.Glyph.ALL, Palette.PRESS_LIME, &"party_all_got", &"all_got")
	_all_btn.font_size = 19
	return {&"store": _lock_btn, &"lock": _lock_btn, &"all_got": _all_btn}


func enter(plan: Dictionary) -> void:
	_plan = plan.duplicate(true)
	_serial += 1
	_snd += 1
	_practice_req = false
	_turn = &""
	_answer_at = -100.0
	_callout_at = Vector2.ZERO
	_misscored_lock = -1
	_done_sheet = {}
	_end_started = false
	_coach_shown = ""
	var list_id := String(_plan.get("list", SpeechRules.SIN_LISTS[0]))
	_items = SpeechMaterial.items(list_id)
	var practice := String(_plan.get("practice", ""))
	if practice != "":
		_items.append_array(SpeechMaterial.items(practice))
	var title := SpeechMaterial.title(list_id)
	for w: Control in [_card, _courses, _snr, _party_booth]:
		w.visible = true
	_card.list_title = title
	_card.state = &"idle"
	_card.done_text = ""
	_card.done_sub = ""
	_courses.reset()
	_courses.list_title = title
	_snr.reset()
	var cond := String(_plan.get("condition", "unaided"))
	_party_booth.aided = cond != "unaided"
	_party_booth.transducer = String(_plan.get("transducer", "soundfield" if cond != "unaided" else "phones"))
	_party_booth.focus_on = cond == "directional" and bool(_plan.get("revealed", false))
	_party_booth.babble = false
	# the walk's buttons: GOT IT / MISSED (the screen puts the SRT's labels back when the test changes)
	var got := screen.button(&"score_correct")
	if got != null:
		got.text = "GOT IT"
	var miss := screen.button(&"score_missed")
	if miss != null:
		miss.text = "MISSED"
	screen.bubble.aside = ""
	screen.bubble.idle_text = IDLE_BUBBLE
	# the coached list: once the intro has had its say, why there is no masking
	if cond == "unaided":
		screen.after(0.1, _no_mask_note.bind(_serial))


func exit() -> void:
	_serial += 1
	_snd += 1
	_turn = &""
	_practice_req = false
	if screen != null and screen.voice != null:
		screen.voice.stop_babble()
		screen.voice.stop()
	for w: Control in [_card, _courses, _snr, _party_booth]:
		if w != null:
			w.visible = false
	if screen != null and screen.bubble != null:
		screen.bubble.aside = ""


func hidden_base_widgets() -> Array[StringName]:
	return [&"ladder", &"meter", &"card", &"tally", &"mask_button", &"store_button"]


## The bubble grows down the left column; the card runs under the left and middle columns; the
## courses and the SNR-O-METER share the middle above it (the meter at the slot's right).
func layout(rects: Dictionary) -> void:
	var bubble: Rect2 = rects["bubble"]
	var mid: Rect2 = rects["mid"]
	var slot: Rect2 = rects["meter"]
	var m := 12.0
	var card_x := bubble.position.x
	var card_w := mid.end.x - card_x
	_rows = 1
	for it: Dictionary in _items:
		_rows = maxi(_rows, SpSentenceCard.rows_needed(String(it.get("text", "")), it.get("key_words", []), card_w))
	_rows = mini(_rows, 2)
	var card_h := SpSentenceCard.height_for(_rows)
	var card_y := mid.end.y - card_h
	_card.position = Vector2(card_x, card_y)
	_card.size = Vector2(card_w, card_h)
	var top_h := maxf(80.0, card_y - m - mid.position.y)
	var snr_w := clampf(slot.size.x * 0.62, 150.0, 210.0)
	_snr.position = Vector2(mid.end.x - snr_w, mid.position.y)
	_snr.size = Vector2(snr_w, top_h)
	_courses.position = mid.position
	_courses.size = Vector2(mid.size.x - snr_w - m, top_h)
	var b := screen.bubble
	b.position = bubble.position
	b.size = Vector2(bubble.size.x, maxf(bubble.size.y, card_y - m - bubble.position.y))
	var booth: Rect2 = rects["booth"]
	_party_booth.position = booth.position
	_party_booth.size = booth.size


func deck_groups() -> Array[Dictionary]:
	return [
		{"title": "LEVEL + SENTENCE", "buttons": [{"id": "speech_softer_button", "width": [96.0, 110.0]},
			{"id": "speech_present_button", "width": [184.0, 220.0]}, {"id": "speech_louder_button", "width": [96.0, 110.0]}]},
		{"title": "KEY WORDS", "buttons": [{"id": "speech_incorrect_button", "width": [118.0, 140.0]},
			{"id": "speech_correct_button", "width": [118.0, 140.0]}, {"id": "party_all_got_button", "width": [118.0, 140.0]}]},
		{"title": "BILL", "buttons": [{"id": "party_lock_button", "width": [140.0, 156.0]}]},
	]


func anchors() -> Dictionary:
	var out := {"party_sentence_card": _card, "party_courses": _courses, "party_snr_meter": _snr}
	out.merge(_card.chip_anchors())
	return out


func restore_base() -> void:
	screen.bubble.aside = ""
	screen.bubble.idle_text = SpBubble.IDLE_TEXT


func extra_state() -> Dictionary:
	var sin := _sin()
	return {"practice": bool(sin.get("practice", false)), "party_card": String(_card.state)}


# ---------------------------------------------------------------- input and controls

func input_for(action: StringName, args: Dictionary = {}) -> StringName:
	match action:
		&"key_got":
			return &"speech_correct"
		&"key_missed":
			return &"speech_incorrect"
		&"key_fix", &"flip_key":
			return StringName("party_word_%d" % int(args.get("key", 1)))
		&"lock":
			return &"store"
		&"all_got":
			return &"party_all_got"
	return &""


func mouse_for(action: StringName, args: Dictionary = {}) -> String:
	match action:
		&"key_got":
			return "speech_correct_button"
		&"key_missed":
			return "speech_incorrect_button"
		&"key_fix", &"flip_key":
			return "party_key_%d" % int(args.get("key", 1))
		&"lock":
			return "party_lock_button"
		&"all_got":
			return "party_all_got_button"
	return ""


## 1-5 flip a chip, G ticks them all. The player's keys only (never in Hoot's turn).
func handle_input(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	for k in range(1, 6):
		if event.is_action_pressed(StringName("party_word_%d" % k)):
			if screen.player_ok():
				screen.do_action(&"flip_key", {"key": k})
			return true
	if event.is_action_pressed(&"party_all_got"):
		if screen.player_ok():
			screen.do_action(&"all_got")
		return true
	return false


func act(action: StringName, args: Dictionary = {}) -> bool:
	var s := screen.session
	if s == null:
		return action in MUST_CLAIM
	match action:
		&"present":
			if bool(_sin().get("awaiting_lock", false)) and not screen.busy():
				s.present()   # refused: lock_first, once a list
				_lock_btn.wiggle()
				Sfx.play(&"error", 1.0, -12.0)
				return true
			if bool(_sin().get("practice_pending", false)) and not screen.hoot_running() and not screen.busy():
				_practice_req = true
				screen.hoot_turn(1.0)
				if not screen.hoot_running():
					_practice_req = false
					return false
				return true
			return false
		&"score_correct", &"key_got":
			_walk(true, action == &"key_got")
			return true
		&"score_missed", &"key_missed":
			_walk(false, action == &"key_missed")
			return true
		&"flip_key", &"key_fix", &"mark_key", &"focus_key":
			_mark(&"flip_key" if action == &"key_fix" else action, args)
			return true
		&"all_got":
			_all_got()
			return true
		&"store", &"lock":
			_lock()
			return true
		&"mask_toggle":
			s.toggle_mask()   # refused: sin_no_mask (the same mix reaches both ears)
			Sfx.play(&"error", 1.0, -14.0)
			return true
		&"louder", &"softer":
			if screen.busy():
				# the level locked with the first sentence: say why (once a list), not the SRT's word line
				var b := screen.button(action)
				screen.lcd.deny()
				if b != null:
					b.wiggle()
				Sfx.play(&"error", 1.0, -12.0)
				s.step_level(1 if action == &"louder" else -1)
				return true
			return false
	return action in MUST_CLAIM


## The chips can be marked: an answer is up and waiting for LOCK IN.
func _marking_ok() -> bool:
	return bool(_sin().get("awaiting_lock", false)) and screen.answer_shown() and not screen.busy()


## A mark refused: why, once a visit (the sentence is still playing, or none is up yet).
func _deny_marks(key: int = 0) -> void:
	if key > 0:
		_card.wiggle_chip(key)
	Sfx.play(&"error", 1.0, -12.0)
	if screen.hoot_running():
		return
	if screen.busy():
		Hoot.say_once("party_wait_answer", screen.say(WAIT_ANSWER), Hoot.NORMAL, "speech_response")
	elif not bool(_sin().get("awaiting_lock", false)):
		Hoot.say_once("party_play_first", _fill(screen.say(PLAY_FIRST)), Hoot.NORMAL, "speech_present_button")


## The walk: GOT IT / MISSED mark the focus chip and the focus moves on.
func _walk(correct: bool, flash: bool) -> void:
	if not _marking_ok() or int(_sin().get("focus_key", -1)) < 0:
		for a: StringName in [&"score_correct", &"score_missed"]:
			var b := screen.button(a)
			if b != null:
				b.wiggle()
		_deny_marks()
		return
	if flash:
		var b := screen.button(&"score_correct" if correct else &"score_missed")
		if b != null:
			b.flash_press()
	if screen.session.score(correct).is_empty():
		return
	_tick_sound(correct)
	screen.refresh()


## A chip: flip_key {key}, mark_key {key, got}, focus_key {key} (SinTest.act()).
func _mark(action: StringName, args: Dictionary) -> void:
	var key := int(args.get("key", 0))
	if not _marking_ok():
		_deny_marks(key)
		return
	if screen.session.mode.act(action, args).is_empty():
		_card.wiggle_chip(key)
		return
	if action != &"focus_key":
		var marks: Array = _sin().get("marks", [])
		_tick_sound(key >= 1 and key <= marks.size() and marks[key - 1] == true)
	screen.refresh()


func _all_got() -> void:
	if not _marking_ok():
		_all_btn.wiggle()
		_deny_marks()
		return
	if screen.session.mode.act(&"all_got").is_empty():
		return
	Sfx.play(&"ding", 1.25, -8.0 if not screen.hoot_running() else -16.0)
	screen.refresh()


func _tick_sound(got: bool) -> void:
	Sfx.play(&"ding" if got else &"click", 1.1 if got else 0.8, -9.0 if not screen.hoot_running() else -18.0)


## LOCK IN: SinTest.store() bills the sentence (blanks are missed); the card sends the misses back,
## the plate fills, Events.party_sentence_locked. The list's sixth lock finishes it (on_stored()).
func _lock() -> void:
	var s := screen.session
	if screen.busy():
		_lock_btn.wiggle()
		_deny_marks()
		return
	if not bool(_sin().get("awaiting_lock", false)):
		_lock_btn.wiggle()
		_deny_marks()
		return
	var cur := s.current
	var n := int(cur.get("n", 0))
	var practice := bool(cur.get("practice", false))
	_lock_n += 1
	_lock_points = 0
	_lock_ok = false
	if not practice:
		_callout_at = _courses.plate_global(n) + Vector2(0, -40)
	var tr := s.store()
	if tr.is_empty():
		_lock_btn.wiggle()
		return
	var marks: Array = tr.get("marks", [])
	var count := int(tr.get("count_billed", 0))
	var hoot := screen.hoot_running()
	_card.lock_in(marks)
	_snd += 1
	screen.voice.stop_babble()
	Sfx.play(&"stamp", randf_range(0.95, 1.05), -6.0 if not hoot else -14.0)
	if not practice:
		_courses.fill(n, marks)
		Events.party_sentence_locked.emit(String(cur.get("condition", "unaided")), n, int(cur.get("snr", 0)), count)
		if not hoot:
			screen.fx.burst(_courses.plate_global(n), Palette.MINT, 8, 160.0)
			if _lock_points > 0:
				screen.fx.callout("+%d" % _lock_points, _callout_at, Palette.MINT, 24, "all 5 right!" if _lock_ok else "", 0.0, 0.9)
		# from sentence 2 on the coach only speaks for the slips and the two moments (CHAPTER5 §5.4)
		_drop_coach_tip()
	if bool(tr.get("list_done", false)):
		_end_show.call_deferred(_serial)
	elif not practice:
		screen.check_hoot_after()
	screen.refresh()


## Take the coach's sticky line down (it is the one on screen and it is ours).
func _drop_coach_tip() -> void:
	var cur := Hoot.current_tip()
	if _coach_shown != "" and not cur.is_empty() and float(cur.get("duration", -1.0)) == 0.0 and String(cur.get("text", "")) == _coach_shown:
		Hoot.dismiss(int(cur["id"]))


## A slip outranks the gentle reminders: the little-words or zero-gap tip on screen makes way, so Hoot
## names the wrong chip while the player still sees it flash (not 4 s later, under the next sentence).
func _drop_hold_tip() -> void:
	var cur := Hoot.current_tip()
	if cur.is_empty():
		return
	var text := String(cur.get("text", ""))
	for k: StringName in [&"little_words", &"noise_won"]:
		if text == _fill(screen.say(String(SinTest.TIPS[k]))):
			Hoot.dismiss(int(cur["id"]))
			return


func _on_chip(key: int) -> void:
	if not screen.player_ok():
		_card.wiggle_chip(key)
		return
	screen.do_action(&"flip_key", {"key": key})


func _on_chip_right(key: int) -> void:
	if not screen.player_ok():
		_card.wiggle_chip(key)
		return
	screen.do_action(&"mark_key", {"key": key, "got": false})


func _no_mask_note(serial: int) -> void:
	if serial != _serial or screen.session == null or screen.hoot_running() or not bool(screen.get_state().get("coached", false)):
		return
	var m := screen.session.mode as SinTest
	if m != null:
		m.on_mask_refused()


# ---------------------------------------------------------------- one sentence

func on_present(trial: Dictionary) -> float:
	_snd += 1
	var snd := _snd
	var practice := bool(trial.get("practice", false))
	var n := int(trial.get("n", 0))
	screen.bubble.aside = ""
	screen.bubble.style = &"normal"
	_card.show_sentence(String(trial.get("text", "")), trial.get("key_words", []), trial.get("marks", []), n, SpeechRules.SIN_SNRS.size(),
		SinTest.PRACTICE_COURSE if practice else SpeechRules.SIN_COURSES[clampi(n - 1, 0, 5)], int(trial.get("snr", 0)), practice, true)
	_card.state = &"talking"
	_card.focus = -1
	_card.by_hoot = screen.hoot_running()
	_snr.set_view({"talker_db": int(trial.get("db", 0)), "snr": int(trial.get("snr", 0)), "live": true})
	var it := _item_for(trial)
	var syl := SpeechVoice.syllables_for(it)
	var talk := syl * SpeechVoice.SYLLABLE_S + maxi(0, syl - 1) * SpeechVoice.SYLLABLE_GAP_S
	# Hoot's x8 turn is silent (the murmur and the party would be cut to an eighth); his practice is not
	var audible := not screen.hoot_running() or _turn == &"practice"
	if audible:
		screen.voice.start_babble(screen.session.ear, int(trial.get("babble_db", 0)))
		screen.after(BABBLE_LEAD_S, _talker.bind(snd, it, int(trial.get("db", 0))))
		screen.after(BABBLE_LEAD_S + talk + BABBLE_TAIL_S, _babble_off.bind(snd))
	_party_booth.babble = true
	return maxf(SpeechScreen.MIN_TALK_S, BABBLE_LEAD_S + talk)


## The item a trial says (its list's, or the practice's).
func _item_for(trial: Dictionary) -> Dictionary:
	var id := String(trial.get("item_id", ""))
	for it: Dictionary in _items:
		if String(it.get("id", "")) == id:
			return it
	return {"id": id, "text": String(trial.get("text", ""))}


func _talker(snd: int, it: Dictionary, db: int) -> void:
	if snd != _snd or screen.session == null or (screen.hoot_running() and _turn != &"practice"):
		return
	screen.voice.play_item(screen.session.ear, screen.session.list_id, it, float(db))


func _babble_off(snd: int) -> void:
	if snd == _snd:
		screen.voice.stop_babble()


func on_answer(trial: Dictionary) -> bool:
	_answer_at = screen.clock()
	var hoot := screen.hoot_running()
	screen.bubble.show_answer(String(trial.get("said", "")))
	Juice.pop(screen.bubble, 1.06, 0.25)
	Sfx.play(&"pop", 1.15, -8.0 if not hoot else -16.0)
	_card.state = &"marking"
	_card.by_hoot = hoot
	_party_booth.babble = false
	_snr.set_view({"live": false})
	# programme A's first answer by the player: Marco's verdict on louder soup (once a visit)
	if not hoot and not bool(trial.get("practice", false)) and String(_plan.get("condition", "")) == "omni":
		screen.session.observe_once("sin:louder_soup", &"party_aside", {"line": ASIDE_LOUDER_SOUP})
	return true


func on_stored(sheet: Dictionary) -> bool:
	_done_sheet = sheet
	# the sixth LOCK IN finishes its own work first (the plate, party_sentence_locked), then the show
	_end_show.call_deferred(_serial)
	return true


## The list is done: party_list_done, the total lands on the courses, then complete_list().
func _end_show(serial: int) -> void:
	if serial != _serial or _end_started or _done_sheet.is_empty() or screen.session == null:
		return
	_end_started = true
	_snd += 1
	screen.voice.stop_babble()
	_party_booth.babble = false
	var sheet := _done_sheet
	var lists: Array = sheet.get("lists", [])
	var list: Dictionary = lists.back() if not lists.is_empty() else {}
	var total := int(list.get("total", 0))
	var loss := float(list.get("snr_loss", 0.0))
	Events.party_list_done.emit(String(sheet.get("condition", "unaided")), String(list.get("list_id", "")), total, loss)
	var c := _courses.get_global_rect().get_center()
	var hidden := bool(_plan.get("hide_loss", false))
	var sub := _loss_text(loss, bool(sheet.get("aided", false)), hidden)
	screen.fx.callout("%d KEY WORDS" % total, c, Palette.SUNNY, 34, sub, -3.0, 1.8)
	Sfx.play(&"thunk", 1.0, -6.0)
	if int(list.get("player_sentences", 0)) > 0 and not screen.hoot_running():
		# the golf (or the slip) over the billed card, clear of the total on the courses
		var g := _golf_text(list)
		screen.fx.callout(g[0], _card.get_global_rect().get_center(), Palette.MINT if g[0] != "Oops!" else Palette.PAPER, 30, g[1], 4.0, 1.6)
	_card.done_text = "%d KEY WORDS" % total
	_card.done_sub = sub
	screen.after(END_SHOW_S, _complete.bind(serial, sheet))
	screen.refresh()


func _complete(serial: int, sheet: Dictionary) -> void:
	if serial != _serial:
		return
	_card.state = &"done"
	screen.complete_list(sheet)


## "SNR loss 4.5 dB", "SNR loss 6.5 dB . aided, sound field", or "the loss waits for the bill".
static func _loss_text(loss: float, aided: bool, hidden: bool) -> String:
	if hidden:
		return "the SNR loss waits for the bill"
	return "SNR loss %.1f dB%s" % [loss, " . aided, sound field" if aided else ""]


## [callout, small line] for the player's part of a list: the golf name, or "Oops!" after a slip.
static func _golf_text(list: Dictionary) -> Array[String]:
	if int(list.get("slips", 0)) > 0:
		return ["Oops!", "check Hoot's tips"]
	var golf := String(list.get("golf", "par"))
	return [golf.replace("_", " ").capitalize() + "!", "%d strokes, par %d" % [int(list.get("golf_strokes", 0)), int(list.get("golf_par", 0))]]


func celebrate(sheet: Dictionary) -> bool:
	var lists: Array = sheet.get("lists", [])
	var list: Dictionary = lists.back() if not lists.is_empty() else {}
	var c := _courses.get_global_rect().get_center()
	Sfx.play(&"fanfare", 1.0, -8.0)
	screen.fx.confetti(c + Vector2(0, -30), 26, 320.0)
	var title := String(_plan.get("done_title", "%s: %d KEY WORDS" % [String(list.get("list_title", "Party list")).to_upper(), int(list.get("total", 0))]))
	screen.fx.callout(title, c, Palette.SUNNY, 34, _loss_text(float(list.get("snr_loss", 0.0)), bool(sheet.get("aided", false)), bool(_plan.get("hide_loss", false))), -3.0, 2.4)
	return true


func montage(sheet: Dictionary) -> float:
	if not screen.is_inside_tree():
		return -1.0
	var lists: Array = sheet.get("lists", [])
	if lists.is_empty():
		return -1.0
	var list: Dictionary = lists.back()
	var courses: Array = []
	var total := 0
	for sn: Dictionary in list.get("sentences", []):
		var n := int(sn.get("n", 0))
		_courses.fill(n, sn.get("marks", []))
		courses.append({"n": n, "snr": int(sn.get("snr", 0)), "course": SpeechRules.SIN_COURSES[clampi(n - 1, 0, 5)],
			"count": int(sn.get("count", 0)), "by_hoot": true, "locked": true})
		total += int(sn.get("count", 0))
	_courses.set_view({"courses": courses, "current": 7, "total": total, "room": 6,
		"loss_line": _loss_text(float(list.get("snr_loss", 0.0)), bool(sheet.get("aided", false)), false), "loss_blank": bool(_plan.get("hide_loss", false))})
	_card.done_text = "%d KEY WORDS" % total
	_card.done_sub = "Hoot's list, by the book"
	_card.state = &"done"
	screen.fx.chip("Hoot: %d key words" % total, _courses.get_global_rect().get_center() + Vector2(0, -30), Palette.HOOT_FACE, Palette.INK, 16, 1.6)
	return 2.5


# ---------------------------------------------------------------- tips and the coach

func on_technique(kind: StringName, data: Dictionary) -> bool:
	match kind:
		&"party_aside":
			screen.bubble.aside = String(data.get("line", ""))
			return true
		&"practice_done":
			screen.bubble.aside = ASIDE_PRACTICE
			return true
		&"speech_textbook", &"sin_lock_ok":
			# one callout per LOCK IN (after it), a rising note per right chip
			if bool(data.get("auto", false)):
				return true
			_lock_points += int(data.get("points", 0))
			if kind == &"sin_lock_ok":
				_lock_ok = true
				Hoot.note_clean_use(&"sin_lock")
			var c := int(data.get("combo", 0))
			Sfx.play_note(523.25 * pow(2.0, minf(c, 24) / 12.0), -15.0)
			return true
		&"misscored":
			_card.flash(int(data.get("key", 0)))
			if _misscored_lock == _lock_n:
				return true   # Hoot names one wrong chip a lock; the others flash
			_misscored_lock = _lock_n
			_drop_hold_tip()
			return false
		&"sin_done":
			if bool(data.get("auto", false)) or screen.hoot_running():
				return true
			var msg := String(data.get("message", ""))
			if msg != "":
				Hoot.say(msg, Hoot.NORMAL, "party_courses", "", 4.0)
			return true
		&"chef_kiss":
			if bool(data.get("auto", false)) or screen.hoot_running():
				return true
			screen.fx.callout("Chef's kiss!", _courses.get_global_rect().get_center() + Vector2(0, -50), Palette.CORAL.lightened(0.2), 36, "", 6.0, 1.6)
			screen.fx.stars(_courses.get_global_rect().get_center(), 10, Palette.SUNNY)
			var line := String(data.get("message", ""))
			if line != "":
				Hoot.say(line, Hoot.NORMAL, "party_courses", "", 3.5)
			return true
		&"birdie", &"eagle", &"albatross":
			return true   # the list's golf callout (_end_show)
	return false


func kind_class(kind: StringName) -> StringName:
	match kind:
		&"little_words", &"noise_won":
			return &"hold"
		&"misscored":
			return &"repeat"
		&"sin_level":
			return &"error"
		&"sin_good_level", &"speech_textbook", &"sin_lock_ok":
			return &"clean"
		&"lock_first", &"sin_level_locked", &"sin_aided_level", &"sin_no_mask", &"blanks", &"practice", &"sin_list_reused", &"sin_benefit":
			return &"tip"
	return &""


func target_for(kind: StringName, data: Dictionary) -> String:
	match kind:
		&"misscored":
			return "party_key_%d" % clampi(int(data.get("key", 1)), 1, 5)
		&"little_words", &"practice", &"sin_list_reused":
			return "party_sentence_card"
		&"noise_won":
			return "party_snr_meter"
		&"lock_first", &"blanks":
			return "party_lock_button"
		&"sin_level":
			return "speech_louder_button" if int(data.get("got", 0)) < int(data.get("target", 0)) else "speech_softer_button"
		&"sin_good_level", &"sin_level_locked", &"sin_aided_level":
			return "speech_louder_button"
		&"sin_done", &"chef_kiss", &"sin_benefit":
			return "party_courses"
	# sin_no_mask: no hand (the MASK button is hidden; the booth's BOTH EARS chip says it)
	return ""


func mastery_skill(kind: StringName) -> StringName:
	return &"sin_level" if kind == &"sin_good_level" else &""


func callout_point() -> Vector2:
	if _callout_at != Vector2.ZERO:
		return _callout_at
	var n := clampi(int(_sin().get("sentence_n", 1)), 1, 6)
	return _courses.plate_global(n) + Vector2(0, -40)


## The coach on the coached list (CHAPTER5 §5.4): the talker level, the practice, the first
## sentence's walk and lock; from sentence 2 on only the Main course moment (and the slips).
func coach_text(rec: Dictionary) -> Array:
	var sin := _sin()
	if sin.is_empty():
		return []
	var act := StringName(String(rec.get("action", "none")))
	var n := int(sin.get("sentence_n", 1))
	var out: Array = QUIET
	if screen.busy():
		if n <= 1:
			out = [screen.say(COACH_LISTEN), "speech_response", "listen%d" % n]
	else:
		match act:
			&"louder", &"softer":
				var target := int(rec.get("target_db", sin.get("target_db", 0)))
				out = [COACH_LEVEL % [target, String(act)], "speech_%s_button" % String(act), "level%d_%s" % [target, String(act)]]
			&"present":
				if bool(sin.get("practice_pending", false)):
					out = [COACH_PRACTICE, "speech_present_button", "practice"]
				elif n == 1 and screen.session.trials_for().is_empty():
					out = [COACH_FIRST, "speech_present_button", "first"]
				elif n == 4 and int(sin.get("list_n", 1)) == 1:
					out = [screen.say(COACH_MAIN), "party_courses", "main"]
			&"key_got", &"key_missed", &"key_fix", &"lock":
				if n == 1 and not bool(sin.get("practice", false)):
					out = _marking_line(act, rec, sin)
	if String(out[0]) != "":
		_coach_shown = _fill(String(out[0]))
	return out


func _marking_line(act: StringName, rec: Dictionary, sin: Dictionary) -> Array:
	var mouse := screen.last_device() == &"mouse"
	if act == &"key_fix":
		var k := int(rec.get("key", 1))
		return [screen.say(COACH_FIX % [k, k]), "party_key_%d" % k, "fix%d" % k]
	if act == &"lock":
		if mouse:
			return [screen.say(SinTest.COACH_LINES[&"lock_mouse"]), "party_lock_button", "lock_mouse"]
		return [SinTest.COACH_LINES[&"lock_keys"], "party_lock_button", "lock"]
	var marked := false
	for m: Variant in sin.get("marks", []):
		marked = marked or m != null
	if not marked:
		return [screen.say(COACH_TICK), "party_key_1", "tick"]
	# the key names the focus chip, so the ghost hand follows the walk along the card
	var focus := int(sin.get("focus_key", -1))
	var at := "party_key_%d" % (focus + 1) if focus >= 0 else "party_lock_button"
	if mouse:
		return [screen.say(SinTest.COACH_LINES[&"lock_mouse"]), at, "walk_mouse%d" % focus]
	return [screen.say(SinTest.COACH_LINES[&"walk"]), at, "walk%d" % focus]


func hoot_turn_text() -> String:
	var locked := _locked_count()
	var first := int(_plan.get("hoot_first", 0))
	if _practice_req:
		_practice_req = false
		_turn = &"practice"
		return SinTest.TIPS[&"practice"]
	if first > 0 and locked < first and _turn != &"rest":
		_turn = &"first"
	else:
		_turn = &"rest"
	if String(_plan.get("hoot_turn_text", "")) != "":
		return ""
	var speed := roundi(float(_plan.get("hoot_speed", SpeechScreen.HOOT_SPEED)))
	if _turn == &"first":
		return "My turn: I'll serve the first %s at %dx. Watch the plates!" % ["course" if first == 1 else "%d courses" % first, speed]
	if locked > 0 and screen.session.presentations > 0:
		return "Nice work! My turn: I'll finish this list at %dx. Watch the plates!" % speed
	return "My turn! I'll run this list at %dx. Watch the plates!" % speed


## One step of Hoot's turn: he reads the answer first, ticks his practice chips one by one, and hands
## back after the practice or after sentence hoot_first.
func hoot_step() -> float:
	var sin := _sin()
	var waiting := bool(sin.get("awaiting_lock", false))
	if waiting and screen.answer_shown():
		var seen := screen.clock() - _answer_at
		if seen < SpeechScreen.HOOT_READ_S:
			return SpeechScreen.HOOT_READ_S - seen
	match _turn:
		&"practice":
			if not waiting and not bool(sin.get("practice_pending", false)):
				_turn = &""
				return -2.0
			if waiting and screen.answer_shown():
				var rec := screen.session.recommended_action()
				var act := StringName(String(rec.get("action", "none")))
				screen.do_action(act, rec)
				return PRACTICE_TICK_S if act != &"lock" else 0.9
		&"first":
			if not waiting and _locked_count() >= int(_plan.get("hoot_first", 0)):
				_turn = &"rest"
				return -2.0
	return -1.0


func beat_info(info: Dictionary) -> Dictionary:
	var sin := _sin()
	var rec := screen.session.recommended_action()
	info["condition"] = String(sin.get("condition", "unaided"))
	info["list"] = String(sin.get("list_id", ""))
	info["list_n"] = int(sin.get("list_n", 1))
	info["sentence_n"] = int(sin.get("sentence_n", 0))
	info["key"] = int(rec.get("key", 0))
	info["focus_key"] = int(sin.get("focus_key", -1)) + 1
	return info


## "sin|<measure_key>|<sentence_n>|<action>|<key>|<marks as 0/1/->|<db>" (§9.19.1).
func beat_key(rec: Dictionary) -> String:
	var sin := _sin()
	var marks := ""
	for m: Variant in sin.get("marks", []):
		marks += "-" if m == null else ("1" if m == true else "0")
	return "sin|%s|%d|%s|%d|%s|%d" % [screen.session.measure_key(), int(sin.get("sentence_n", 0)), String(rec.get("action", "none")),
		int(rec.get("key", 0)), marks, screen.session.db]


# ---------------------------------------------------------------- views

func lcd_view(view: Dictionary) -> Dictionary:
	var sin := _sin()
	if sin.is_empty():
		return view
	var s := screen.session
	view["ear_chip"] = "BOTH" if s.ear == "both" else s.ear.to_upper()
	view["test_chip"] = "PARTY"
	var t := String(sin.get("transducer", "phones"))
	var tchip := "SPEAKERS" if t == "soundfield" else ("INSERTS" if t == "inserts" else "PHONES")
	view["chips"] = [tchip, _condition_chip(sin)]
	view["noise_note"] = NOISE_NOTE_FIELD if t == "soundfield" else NOISE_NOTE_PHONES
	# "set by Hoot" lives on the start chip: the big caption stays clear of the TALK knob
	view["big_caption"] = "TALKER"
	view["aux"] = [{"label": "PARTY", "value": "%d" % int(sin.get("babble_db", 0))}, {"label": "SNR", "value": "%d" % int(sin.get("snr", 0))}]
	var n := int(sin.get("sentence_n", 1))
	if n == 0:
		view["info_line"] = "%s . practice sentence" % String(sin.get("list_title", ""))
	else:
		view["info_line"] = "%s . sentence %d of %d . %s" % [String(sin.get("list_title", "")), n, int(sin.get("sentences", 6)), String(sin.get("course", ""))]
	var target := int(sin.get("target_db", SpeechRules.SIN_LEVEL_DB))
	if bool(sin.get("aided", false)):
		view["start_chip"] = "AIDED: %d dB, set by Hoot" % target
	else:
		# the sum on the chip adds up, or the chip names the level alone (the standard 70, or the 90 cap)
		var pta := s.pta_for(s.ear)
		var base := SpeechRules.snap5(pta) if not is_nan(pta) else 0
		if not is_nan(pta) and pta > SpeechRules.SIN_PTA_LIMIT_DB and base + SpeechRules.SIN_LOUD_ABOVE_PTA_DB == target:
			view["start_chip"] = "TALKER = %d + %d = %d" % [base, SpeechRules.SIN_LOUD_ABOVE_PTA_DB, target]
		elif bool(sin.get("level_by_hoot", false)):
			view["start_chip"] = "TALKER: %d dB, set by Hoot" % target
		else:
			view["start_chip"] = "TALKER = %d dB" % target
	view["start_db"] = target
	return view


## UNAIDED; aided "PROGRAMME A" (blind) or, once revealed, "A: OMNI" / "B: FOCUS".
func _condition_chip(sin: Dictionary) -> String:
	if not bool(sin.get("aided", false)):
		return "UNAIDED"
	var prog := String(sin.get("programme", ""))
	var title := String(sin.get("condition_title", "")).to_upper()
	if prog == "":
		return title
	return "%s: %s" % [prog, title] if bool(_plan.get("revealed", false)) else "PROGRAMME %s" % prog


func dance_specs() -> Array[Dictionary]:
	return [
		{"title": "TICK WHAT", "sub": screen.say("{He} said").to_upper(), "icon": &"check", "color": Palette.PRESS_LIME},
		{"title": "LITTLE WORDS", "sub": "no score", "icon": &"cross", "color": Palette.SUNNY},
		{"title": "LOCK IN", "sub": "then next", "icon": &"stamp", "color": Palette.MINT},
	]


func refresh(st: Dictionary) -> void:
	var sin: Dictionary = st.get("sin", {})
	if sin.is_empty():
		return
	var busy := bool(st.get("talking", false)) or bool(st.get("listening", false))
	var waiting := bool(sin.get("awaiting_lock", false))
	var marking := waiting and bool(st.get("answer_shown", false)) and not busy
	var done := bool(sin.get("done", false))
	var n := int(sin.get("sentence_n", 1))
	# the card
	_card.show_keys = bool(Game.settings.get("show_key_hints", true))
	_card.key_got = screen.k(&"speech_correct")
	_card.key_missed = screen.k(&"speech_incorrect")
	_card.key_lock = screen.k(&"store")
	if not done:
		if waiting:
			_card.show_sentence(String(sin.get("text", "")), sin.get("key_words", []), sin.get("marks", []), n, int(sin.get("sentences", 6)),
				String(sin.get("course", "")), int(sin.get("snr", 0)), bool(sin.get("practice", false)), true)
			if bool(st.get("talking", false)):
				_card.state = &"talking"
			elif bool(st.get("listening", false)):
				_card.state = &"listening"
			else:
				_card.state = &"marking"
			_card.focus = int(sin.get("focus_key", -1))
		else:
			var practice := bool(sin.get("practice_pending", false))
			_card.show_sentence(String(sin.get("text", "")), sin.get("key_words", []), sin.get("marks", []), 0 if practice else n,
				int(sin.get("sentences", 6)), String(sin.get("course", "")), int(sin.get("snr", 0)), practice)
			if _card.state != &"locked":
				_card.state = &"idle"
	# the courses and the meter
	var aided := bool(sin.get("aided", false))
	var hidden := bool(sin.get("loss_hidden", false))
	var loss_line := ""
	if done and not hidden:
		var lists: Array = sin.get("lists", [])
		if not lists.is_empty():
			loss_line = "%.1f dB%s" % [float((lists.back() as Dictionary).get("snr_loss", 0.0)), " . aided, sound field" if aided else ""]
	_courses.set_view({"courses": sin.get("courses", []), "current": 7 if done else n, "total": int(sin.get("total_so_far", 0)),
		"room": clampi(n, 1, 6), "loss_line": loss_line, "loss_blank": hidden})
	_snr.set_view({"talker_db": int(sin.get("talker_db", 0)), "snr": int(sin.get("snr", 0)), "live": bool(st.get("talking", false))})
	_party_booth.babble = screen.voice.is_babbling() or (screen.hoot_running() and bool(st.get("talking", false)))
	# the buttons: LOCK IN and ALL GOT only while the chips are awake; the walk only with a focus chip
	var focus := int(sin.get("focus_key", -1))
	var finishing := bool(st.get("finishing", false)) or done
	_lock_btn.locked = not marking or finishing
	_all_btn.locked = not marking or finishing
	for a: StringName in [&"score_correct", &"score_missed"]:
		var b := screen.button(a)
		if b != null:
			b.locked = not marking or focus < 0 or finishing
			if b.locked:
				b.beckon = false
	var hoot := screen.hoot_running()
	_lock_btn.beckon = marking and not hoot and not finishing and (focus < 0 or _lock_btn.beckon)
	# the dance card: tick what he said, then lock in (no hint before the answer)
	if marking and not hoot:
		var blanks := false
		for m: Variant in sin.get("marks", []):
			blanks = blanks or m == null
		screen.dance.pulse(0 if blanks else 2)
	else:
		screen.dance.clear()


## SinTest.state() (get_state().sin): {} before a party list.
func _sin() -> Dictionary:
	var s := screen.session if screen != null else null
	if s == null or s.mode == null or s.test != &"sin":
		return {}
	return s.mode.state()


## Sentences of this list locked so far.
func _locked_count() -> int:
	var n := 0
	if screen.session == null:
		return 0
	for tr: Dictionary in screen.session.trials_for():
		if bool(tr.get("locked", false)):
			n += 1
	return n


## {key:<action>} filled as the screen fills it (the coach line as it shows).
func _fill(text: String) -> String:
	var at := text.find("{key:")
	while at >= 0:
		var end := text.find("}", at)
		if end < 0:
			break
		var chip := screen.k(StringName(text.substr(at + 5, end - at - 5)))
		text = text.substr(0, at) + chip + text.substr(end + 1)
		at = text.find("{key:", at + chip.length())
	return text
