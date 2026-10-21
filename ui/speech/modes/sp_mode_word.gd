class_name SpModeWord
extends SpMode
## SpModeWord: the SPEECH screen's WORD mode, Day 4's word lists (CONTRACTS.md §9.17 and §9.19,
## with the clinical amendments; CHAPTER4 §5). The screen makes it once (test "wrs") and calls
## enter() for every list. One list is 25 one-syllable words at ONE level with ONE noise set-up:
## PRESENT says the word, the patient answers in the bubble, REPEATED or MISSED scores the whole word,
## and after word 25 the list ends itself (no STORE).
##
## What it adds to the screen:
##   - the score strip (SpScoreStrip) in the middle, the Banana Board (SpBanana) beside it from the
##     first lens press, the ear compare (SpEarCompare) in the meter slot once both ears have a
##     counted list, and the Ghost (SpGhost) in the booth window
##   - the lens ("<NAME>-VISION", V or speech_lens_button): a "REACHES HER:" row on the word card, each
##     spelling piece inked by SpeechRules.lens_alpha of its margin on the MEASURED thresholds (the
##     word above it is always crisp); on a different answer the row's letters turn into what she said
##   - the two-press confirm on solo lists (a chip; BOO! when words could cross unmasked) and, on
##     coached lists, the denial with the coach's tip instead
##   - Call it: an overlay card before a chosen word ("Will she get it?"), unscored
##   - the chat demo (a Hoot turn at speed 1 before List 2) and the patient's asides
##   - the beats lens_try, call_it and speech, with their solvers' inputs and mouse routes
## Every line keeps to 18 words with its tokens at their longest, and every key it names is a
## {key:<action>} placeholder. Nothing here plays a sound louder than the screen's own voice.

## The solo list's confirm chip stays this long; a second PRESENT inside it tests anyway.
const CONFIRM_S := 4.0
## The coached denial's tip holds the coach's place this long, then the coach repeats the step.
const DENY_S := 4.0
## The lens row's letters turn into her answer over this long (a crossfade with reduced motion).
const SCRAMBLE_S := 0.6
## Each chat-demo line shows this long (or until Hoot's bubble is clicked away).
const DEMO_LINE_S := 2.5
## The Call it card (canvas px; centred on the middle area) and its two buttons (key chips inside).
const CALL_W := 470.0
const CALL_H := 236.0
const CALL_BTN_H := 108.0
## The card grows to at least this height (taken from the bubble) so the lens row has room.
const CARD_MIN_H := 200.0
## Her answers keep clear of the score badge in the bubble's corner (a chatty hit wraps to two lines).
const BUBBLE_BADGE_INSET := 56.0
const LINES: Dictionary[String, String] = {
	"lens_try": "{Lens}! Press {key:toggle_lens} to see each word as {his} ear gets it.",
	"busy": "Read {his} answer in the bubble when it pops up.",
	"level_low_up": "PTA {pta}, plus 35 is {sum}. But never below 55! Hold {key:louder} to 55.",
	"level_low_down": "PTA {pta}, plus 35 is {sum}. But never below 55! Tap {key:softer} down to 55.",
	"level_up": "PTA {pta}, plus 35 is about {target}. Tap {key:louder} up to {target}.",
	"level_down": "PTA {pta}, plus 35 is about {target}. Tap {key:softer} down to {target}.",
	"louder_up": "Rollover check: 20 louder. Tap {key:louder} up to {target}. Noise stays on.",
	"louder_down": "Rollover check: 20 above the comfy list. Tap {key:softer} down to {target}.",
	"redo_up": "Word list {n}, coached: {key:louder} to {target}, noise on, then {key:present_tone}.",
	"redo_down": "Word list {n}, coached: {key:softer} to {target}, noise on, then {key:present_tone}.",
	"mask": "This loud, words can cross to the other ear. Noise on: {key:toggle_mask}.",
	"first_quiet": "Too soft to cross {his} skull, so no noise for this ear. {key:present_tone}: first word!",
	"first_masked": "Noise on, level set: {key:present_tone} for the first word!",
	"next": "Next word: {key:present_tone}.",
	"score_hit": "{He} said the whole word! Score it: {key:speech_correct}.",
	"score_chatty": "The word is inside {his} sentence. That's a hit: {key:speech_correct}.",
	"score_self": "{His} final answer is the word. That's a hit: {key:speech_correct}.",
	"score_miss": "Not the exact word, or no answer? That's a miss: {key:speech_incorrect}.",
	"score_plural": "One sound extra makes a different word. That's a miss: {key:speech_incorrect}.",
	"score_rhyme": "A rhyme is a different word. That's a miss: {key:speech_incorrect}.",
	"call_it": "Call it! {key:speech_correct}: {he}'ll get it. {key:speech_incorrect}: {he}'ll miss it.",
	"prompt_faint_hit": "{Lens} shows a faint '{chunk}'. Will {he} get '{word}'?",
	"prompt_audible_miss": "Every sound of '{word}' reaches {him}. Will {he} get it?",
	"faint_after": "{He} got it! One faint letter, and {his} brain filled the gap.",
	"busted": "Ghost busted! Now only {his} {ear} ear can answer.",
	"confirm_level": "Loud enough for every sound: PTA + 35 = {target}.",
	"confirm_louder": "The louder list goes 20 above the comfy one: {target}.",
	"confirm_level_2": "{key:present_tone} again: test at {db} anyway.",
	"boo": "BOO! At {db}, words can cross to {his} other ear.",
	"boo_2": "{key:toggle_mask}: noise on. {key:present_tone} again: test without it.",
	"demo_turn": "This is chatting level, {db}. Watch what reaches {his} {ear} ear.",
	"confirmed_turn": "That set-up can't count, so I'll finish this list at top speed!",
}
## Day 4's asides (CHAPTER4 §5.6), by trigger; plan `asides` {noise, loud, lens} replaces them.
## The item asides ("Mike? He's in the break room.") come with the answer (trial.aside).
const DEFAULT_ASIDES: Dictionary[String, String] = {
	"noise": "Is that the sopranos warming up?",
	"loud": "Ooh, that's LOUD.",
	"lens": "Borrow my opera glasses, Professor. They're tuned to me.",
}
const CHIP_LEVEL_LOCKED := "One level per list"
const CHIP_NOISE_LOCKED := "Same noise, every word"

var strip: SpScoreStrip
var banana: SpBanana
var ghost: SpGhost
var compare: SpEarCompare
## Draws the Call it card, the confirm chip and the AUDIBLE, BUT MISSED stamp (canvas coordinates).
var overlay: Control
var _lens_btn: SpButton
var _yes: SpButton
var _no: SpButton
var _plan: Dictionary = {}
var _rects: Dictionary = {}
var _call_rect := Rect2()
var _confirm_t := -100.0
var _confirm_why: StringName = &""
var _deny_t := -100.0
var _deny_line := ""
var _deny_target := ""
var _deny_n := 0
var _demo_pending := false
var _demo_running := false
var _demo_i := 0
var _demo_t := 0.0
var _demo_tip := -1
## The tip on Hoot's perch when the demo started ({text, target}): it comes back once the demo ends.
var _demo_kept: Dictionary = {}
var _mask_was := false
var _lurk_told := false
var _stamp_t := -100.0
var _stamp_word := ""
## {item_id, to, t0}: the lens row turning into her answer.
var _scramble: Dictionary = {}
## Hoot's end-of-list lines already said for this list (the verdict kinds repeat some).
var _said_lines: Dictionary = {}
## Card text -> item, for the lens row (the card flips: the row follows the word it shows).
var _row_items: Dictionary = {}
var _lens_aside_done := false
var _call_seen := false


# ---------------------------------------------------------------- lifecycle

func setup(s: SpeechScreen) -> void:
	super(s)
	var root := s.ui_root()
	strip = SpScoreStrip.new()
	strip.name = "SpeechScoreStrip"
	banana = SpBanana.new()
	banana.name = "SpeechBanana"
	ghost = SpGhost.new()
	ghost.name = "SpeechGhost"
	compare = SpEarCompare.new()
	compare.name = "SpeechEarCompare"
	overlay = Control.new()
	overlay.name = "WordOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	var widgets: Array[Control] = [strip, banana, ghost, compare, overlay]
	# under Hoot's x8 banner and the effects, over the deck
	var above: Node = root.get_node_or_null("HootTurnBanner")
	if above == null:
		above = s.fx
	for c: Control in widgets:
		c.visible = false
		root.add_child(c)
		root.move_child(c, above.get_index())


func make_buttons() -> Dictionary:
	_lens_btn = screen.make_button("speech_lens_button", "LENS OFF", AoButton.Icon.NONE, SpButton.Glyph.EYE, Palette.SKY, &"toggle_lens", &"")
	_lens_btn.font_size = 16
	_lens_btn.icon_size = 30.0
	_lens_btn.lamp = 0
	_lens_btn.lamp_color = Palette.TONE_CYAN
	_lens_btn.clicked.connect(_on_lens_clicked)
	_yes = screen.make_button("call_it_yes_button", "GET IT", AoButton.Icon.NONE, SpButton.Glyph.CHECK, Palette.MINT, &"speech_correct", &"call_it_yes")
	_no = screen.make_button("call_it_no_button", "MISS IT", AoButton.Icon.NONE, SpButton.Glyph.CROSS, Palette.CORAL, &"speech_incorrect", &"call_it_no")
	_no.text_color = Palette.PAPER
	for b: SpButton in [_yes, _no]:
		b.font_size = 17
		b.icon_size = 26.0
	return {&"lens_toggle": _lens_btn, &"call_it_yes": _yes, &"call_it_no": _no}


func enter(plan: Dictionary) -> void:
	_plan = plan
	_confirm_t = -100.0
	_confirm_why = &""
	_deny_t = -100.0
	_demo_running = false
	_demo_pending = false
	_demo_tip = -1
	_lurk_told = false
	_stamp_t = -100.0
	_scramble = {}
	_said_lines.clear()
	_row_items.clear()
	_call_seen = false
	for c: Control in [strip, banana, ghost, overlay]:
		c.visible = true
	compare.visible = bool(screen.memory.get("compare_shown", false))
	strip.reset()
	ghost.reset()
	var s := screen.session
	ghost.side = -1.0 if s != null and s.ear == "left" else 1.0
	var on := bool(screen.memory.get("lens_on", plan.get("lens", false)))
	screen.memory["lens_on"] = on
	if s != null and s.mode != null:
		s.mode.act(&"toggle_lens", {"on": on})
	if bool(screen.memory.get("banana_shown", false)):
		banana.reveal(false)
	_mask_was = s != null and s.mask_on
	screen.card.carrier = "LIST SAYS:"
	screen.bubble.text_inset = BUBBLE_BADGE_INSET
	var hit := screen.button(&"score_correct")
	if hit != null:
		hit.text = "REPEATED"
	_lens_btn.text = "LENS ON" if _lens_on() else "LENS OFF"
	_yes.text = _say("{He}'ll get it").to_upper()
	_no.text = _say("{He}'ll miss it").to_upper()
	var demo: Dictionary = plan.get("chat_demo", {})
	if not demo.is_empty() and s != null and not bool(screen.memory.get("demo_done:" + s.measure_key(), false)):
		_demo_pending = true
		_start_demo.call_deferred()


func exit() -> void:
	_end_demo_view()
	_demo_pending = false
	_confirm_t = -100.0
	_deny_t = -100.0
	_scramble = {}
	for c: Control in [strip, banana, ghost, compare, overlay]:
		if c != null:
			c.visible = false
	if screen != null and screen.voice != null:
		screen.voice.stop()
		screen.voice.stop_noise()


func restore_base() -> void:
	# the screen puts back the labels, the card, the bubble's style and aside, the LCD and the dance;
	# the bubble and card sizes come back with its SRT layout
	if screen != null and screen.bubble != null:
		screen.bubble.text_inset = 0.0


func hidden_base_widgets() -> Array[StringName]:
	return [&"ladder", &"meter", &"tally", &"store_button"]


func deck_groups() -> Array[Dictionary]:
	return [
		{"title": "LEVEL + WORD", "buttons": [{"action": &"softer", "width": [96.0, 110.0]}, {"action": &"present", "width": [196.0, 230.0]},
			{"action": &"louder", "width": [96.0, 110.0]}]},
		{"title": "SCORE THE WHOLE WORD", "buttons": [{"id": "speech_incorrect_button", "width": [128.0, 150.0]},
			{"id": "speech_correct_button", "width": [128.0, 150.0]}]},
		{"title": _lens_label(), "buttons": [{"id": "speech_lens_button", "width": [146.0, 164.0]}]},
		{"title": "NOISE", "buttons": [{"id": "speech_mask_button", "width": [116.0, 130.0]}]},
	]


func anchors() -> Dictionary:
	return {"speech_score_strip": strip, "speech_banana": banana, "speech_ghost": ghost, "speech_ear_compare": compare}


# ---------------------------------------------------------------- layout

func layout(r: Dictionary) -> void:
	_rects = r
	var bub: Rect2 = r["bubble"]
	var crd: Rect2 = r["card"]
	# the lens row needs a taller card: take it from the bubble (never below its 136 px floor)
	var d := clampf(CARD_MIN_H - crd.size.y, 0.0, maxf(0.0, bub.size.y - 136.0))
	if d > 0.0:
		screen.bubble.size = Vector2(bub.size.x, bub.size.y - d)
		screen.card.position = Vector2(crd.position.x, crd.position.y - d)
		screen.card.size = Vector2(crd.size.x, crd.size.y + d)
	var mid: Rect2 = r["mid"]
	var slot: Rect2 = r["meter"]
	strip.position = mid.position
	strip.size = Vector2(slot.position.x - 12.0 - mid.position.x, mid.size.y)
	var comp_h := clampf(slot.size.y * 0.36, 112.0, 150.0)
	var shown := bool(screen.memory.get("compare_shown", false))
	banana.position = slot.position
	banana.size = Vector2(slot.size.x, slot.size.y - (comp_h + 8.0 if shown else 0.0))
	compare.position = Vector2(slot.position.x, slot.end.y - comp_h)
	compare.size = Vector2(slot.size.x, comp_h)
	compare.visible = shown and _on()
	var booth: Rect2 = r["booth"]
	var glass := screen.booth.glass_rect()
	ghost.position = booth.position + glass.position
	ghost.size = glass.size
	overlay.position = Vector2.ZERO
	overlay.size = screen.ui_root().size
	var w := minf(CALL_W, mid.size.x - 40.0)
	_call_rect = Rect2(mid.get_center() - Vector2(w, CALL_H) * 0.5, Vector2(w, CALL_H))
	var bw := (w - 16.0 * 3.0) * 0.5
	var by := _call_rect.end.y - 14.0 - CALL_BTN_H
	_no.position = Vector2(_call_rect.position.x + 16.0, by)
	_no.size = Vector2(bw, CALL_BTN_H)
	_yes.position = Vector2(_call_rect.position.x + 32.0 + bw, by)
	_yes.size = Vector2(bw, CALL_BTN_H)
	_sync_call_buttons()


# ---------------------------------------------------------------- controls

func act(action: StringName, args: Dictionary = {}) -> bool:
	if not _on():
		return super(action, args)
	match action:
		&"store":
			screen.session.store()   # refused: the list scores itself (wrs_no_store, once)
			Sfx.play(&"error", 1.0, -12.0)
			return true
		&"score_correct", &"score_missed":
			if _call_up():
				_answer_call(action == &"score_correct")
			else:
				screen.score_word(action == &"score_correct")
			return true
		&"present":
			return _present_pressed()
		&"louder", &"softer":
			return _level_pressed(action)
		&"mask_toggle":
			return _noise_pressed()
		&"lens_toggle":
			_toggle_lens()
			return true
		&"call_it_yes", &"call_it_no":
			_answer_call(action == &"call_it_yes")
			return true
	return super(action, args)


## V works whenever a list is up, even in Hoot's turn (the lens is only a view). With a Call it
## card up, Right / Left answer it.
func handle_input(event: InputEvent) -> bool:
	if not _on():
		return false
	if event.is_action_pressed(&"toggle_lens"):
		screen.do_action(&"lens_toggle")
		return true
	if _call_up() and screen.player_ok():
		if event.is_action_pressed(&"speech_correct"):
			screen.do_action(&"call_it_yes")
			return true
		if event.is_action_pressed(&"speech_incorrect"):
			screen.do_action(&"call_it_no")
			return true
	return false


func input_for(action: StringName, args: Dictionary = {}) -> StringName:
	match action:
		&"lens_toggle":
			return &"toggle_lens"
		&"call_it":
			return &"speech_correct" if bool(args.get("guess", true)) else &"speech_incorrect"
	return &""


func mouse_for(action: StringName, args: Dictionary = {}) -> String:
	match action:
		&"lens_toggle":
			return "speech_lens_button"
		&"call_it":
			return "call_it_yes_button" if bool(args.get("guess", true)) else "call_it_no_button"
	return ""


func _on_lens_clicked() -> void:
	if _on():
		screen.do_action(&"lens_toggle")


## PRESENT: refused while a Call it waits; the first word of a list with a wrong set-up shows the
## confirm chip (solo) or the denial (coached); a second press inside the chip tests anyway.
func _present_pressed() -> bool:
	var w := _w()
	if w.is_empty():
		return false
	if _call_up():
		for b: AoButton in [_yes, _no]:
			b.wiggle()
		Sfx.play(&"error", 1.0, -12.0)
		return true
	if bool(w["started"]) or bool(w["done"]) or screen.busy() or screen.session.awaiting_score:
		return false
	if _lens_try_due():
		screen.memory["lens_try_done"] = true
	var why := StringName(w["confirm_needed"])
	if why == &"" or screen.hoot_running():
		_confirm_t = -100.0
		return false
	if not bool(w["confirm_wrong_setup"]):
		_deny_coached(why, w)
		return true
	if _confirm_up() and _confirm_why == why:
		_confirm_t = -100.0   # the second press: test anyway (the list records confirmed_wrong)
		return false
	_show_confirm(why)
	return true


func _show_confirm(why: StringName) -> void:
	_confirm_t = screen.clock()
	_confirm_why = why
	screen.session.mode.act(&"confirm_chip", {"why": why})   # the BOO is observed here (once per list)
	if why == &"unmasked":
		ghost.pop()
	var b := screen.button(&"present")
	if b != null:
		b.wiggle()
	Sfx.play(&"error", 1.0, -10.0)
	screen.refresh()


## Coached lists have no "anyway": PRESENT is denied, the coach shows the tip, then repeats the step.
func _deny_coached(why: StringName, w: Dictionary) -> void:
	var kind := &"wrs_unmasked"
	if why == &"level":
		kind = &"rollover_level" if int(w["louder_than"]) > 0 else &"wrs_level"
	_deny_line = screen.session.tip_text(kind)
	_deny_target = target_for(kind, {"expected": int(screen.session.mode.textbook_target()), "got": screen.session.db})
	_deny_t = screen.clock()
	_deny_n += 1
	screen.session.mode.act(&"prompted")
	if Hoot.is_showing() and int(Hoot.current_tip().get("priority", Hoot.HIGH)) < Hoot.HIGH:
		Hoot.dismiss_current()   # the intro steps aside: the press is answered now
	var b := screen.button(&"present")
	if b != null:
		b.wiggle()
	screen.lcd.deny()
	Sfx.play(&"error", 1.0, -12.0)
	screen.refresh()


## One level per list: a press after the first word shows the chip (the session observes it once).
func _level_pressed(action: StringName) -> bool:
	var w := _w()
	if w.is_empty() or not bool(w["level_locked"]):
		return false
	if screen.hoot_running():
		return true
	screen.session.step_level(1 if action == &"louder" else -1)   # refused: wrs_level_locked
	screen.lcd.deny()
	var b := screen.button(action)
	if b != null:
		b.wiggle()
	Sfx.play(&"error", 1.0, -12.0)
	var lr := screen.lcd.get_global_rect()
	screen.fx.chip(CHIP_LEVEL_LOCKED, Vector2(lr.position.x + 170.0, lr.end.y - 6.0), Palette.PAPER, Palette.INK, 15, 1.6)
	return true


## The noise is set before the first word (and never off on a lock_noise list).
func _noise_pressed() -> bool:
	var w := _w()
	if w.is_empty() or not bool(w["noise_locked"]):
		return false
	if screen.hoot_running():
		return true
	screen.session.toggle_mask()   # refused: wrs_noise_locked
	var b := screen.button(&"mask_toggle")
	if b != null:
		b.wiggle()
	Sfx.play(&"error", 1.0, -12.0)
	var at := b.get_global_rect().get_center() + Vector2(0, -84) if b != null else Vector2(640, 500)
	screen.fx.chip(CHIP_NOISE_LOCKED, at, Palette.PAPER, Palette.INK, 15, 1.6)
	return true


func _toggle_lens() -> void:
	var s := screen.session
	if s == null:
		return
	var on := not _lens_on()
	screen.memory["lens_on"] = on
	if s.mode != null:
		s.mode.act(&"toggle_lens", {"on": on})
	if _lens_try_due() or on:
		screen.memory["lens_try_done"] = true
	if on and not banana.is_revealed():
		banana.reveal(true)
		screen.memory["banana_shown"] = true
	Events.speech_lens_toggled.emit(s.ear, on)
	Sfx.play(&"click", 1.3 if on else 0.9, -8.0)
	screen.refresh()


func _answer_call(guess: bool) -> void:
	if not _call_up():
		return
	var rec := screen.session.mode.act(&"call_it", {"guess": guess})
	if rec.is_empty():
		return
	Sfx.play(&"pop", 1.2 if guess else 0.9, -8.0)
	var who := _say("{He}'ll get it" if guess else "{He}'ll miss it")
	screen.fx.chip("You called it: %s" % who.to_lower(), screen.card.get_global_rect().get_center() + Vector2(0, -60),
		Palette.SUNNY, Palette.INK, 15, 1.6)
	screen.refresh()


# ---------------------------------------------------------------- one word

func on_present(trial: Dictionary) -> float:
	if not _on():
		return -1.0
	var s := screen.session
	var it := SpeechMaterial.item(String(trial.get("list_id", s.list_id)), String(trial.get("item_id", "")))
	_confirm_t = -100.0
	_deny_t = -100.0
	_stamp_t = -100.0
	_scramble = {}
	screen.bubble.aside = ""
	screen.bubble.style = &"loud" if bool(_w().get("loud_bubble", false)) else &"normal"
	screen.card.state = &"talking"
	screen.card.set_word(String(trial.get("word", "")), it.get("parts", []), int(trial.get("n", 0)), s.mode.words_left())
	var dur := 0.0
	if screen.hoot_running():
		# Hoot's x8 turn is silent (the murmur would be cut to an eighth); the TALK lamp still lights
		var syl := SpeechVoice.syllables_for(it)
		dur = syl * SpeechVoice.SYLLABLE_S + maxi(0, syl - 1) * SpeechVoice.SYLLABLE_GAP_S
	else:
		dur = screen.voice.play_item(s.ear, s.list_id, it, float(int(trial.get("db", s.db))))
	return maxf(SpeechScreen.MIN_TALK_S, dur)


func on_answer(trial: Dictionary) -> bool:
	if not _on():
		return false
	var s := screen.session
	var w := _w()
	var said := String(trial.get("said", ""))
	var style := &"normal"
	if bool(w.get("loud_bubble", false)):
		style = &"loud"
	elif trial.get("heard_by") == &"cross":
		style = &"ghost"
	screen.bubble.style = style
	screen.bubble.show_answer(said)
	Juice.pop(screen.bubble, 1.06, 0.25)
	screen.card.state = &"score"
	Sfx.play(&"pop", 1.15, -8.0 if not screen.hoot_running() else -16.0)
	# the asides (each once per visit; they never hold up the beat)
	var aside := String(trial.get("aside", ""))
	if aside != "":
		s.observe_once("aside:item:%s" % String(trial.get("item_id", "")), &"aside", {"text": aside, "why": "item"})
	elif style == &"loud":
		s.observe_once("aside:loud", &"aside", {"text": _aside_text("loud"), "why": "loud"})
	# Call it: the faint hit's follow-up line
	if trial.get("call_it", &"") == &"faint_hit" and bool(trial.get("correct", false)):
		_hoot_line(&"wrs_faint_hit_after", LINES["faint_after"])
	# on a miss the lens row turns into what she said (a chatty hit still holds the word)
	if _lens_on() and not bool(trial.get("correct", false)) and _norm(said) != _norm(String(trial.get("word", ""))):
		_scramble = {"item_id": String(trial.get("item_id", "")), "to": said, "t0": screen.clock()}
	return true


func on_scored(_trial: Dictionary) -> void:
	if not _on():
		return
	# a confirmed wrong set-up: Hoot finishes the list after N player words (outside the quick-visit gate)
	var n := int(_plan.get("confirmed_wrong_hoot_after", 0))
	var w := _w()
	if n > 0 and bool(w.get("confirmed_wrong", false)) and not bool(w.get("done", false)) and not screen.hoot_running() and _units() >= n:
		screen.hoot_turn()


## The list's end: the strip flashes, the band chip lands, the card shows the score, then the
## screen's celebrate-and-finish (complete_list) once Hoot's lines have queued.
func on_stored(sheet: Dictionary) -> bool:
	if not _on():
		return false
	var lists: Array = sheet.get("lists", [])
	var rec: Dictionary = lists.back() if not lists.is_empty() else {}
	var pct := int(rec.get("pct", sheet.get("pct", 0)))
	var band := StringName(String(rec.get("band", SpeechRules.wrs_band(pct))))
	screen.memory["ruler_shown"] = true
	strip.show_ruler = true
	strip.flash()
	strip.land_band(band, pct)
	screen.card.done_text = "%d%%" % pct
	screen.card.done_sub = String(SpeechRules.WRS_BAND_TITLES.get(band, "")) + ("" if bool(rec.get("counts", true)) else ": can't count")
	screen.card.state = &"done"
	_confirm_t = -100.0
	Sfx.play(&"stamp", randf_range(0.95, 1.05), -2.0 if int(rec.get("player_words", 0)) > 0 else -8.0)
	if int(rec.get("player_words", 0)) > 0:
		_golf_callout(rec)
	else:
		screen.fx.chip("Hoot: %s, %d%%" % [String(rec.get("list_title", "")), pct], callout_point(), Palette.HOOT_FACE, Palette.INK, 16, 1.4)
	screen.after(0.3, screen.complete_list.bind(sheet))
	return true


func celebrate(sheet: Dictionary) -> bool:
	var lists: Array = sheet.get("lists", [])
	if lists.is_empty():
		return false
	var rec: Dictionary = lists.back()
	var pct := int(rec.get("pct", 0))
	var title := String(_plan.get("done_title", "%s: %d%%" % [String(rec.get("list_title", "Word list")).to_upper(), pct]))
	var band := String(SpeechRules.WRS_BAND_TITLES.get(StringName(String(rec.get("band", ""))), ""))
	var sub := band + (" · counts" if bool(rec.get("counts", false)) else " · can't count")
	var at := strip.get_global_rect().get_center() + Vector2(0, -20)
	if bool(rec.get("counts", false)):
		Sfx.play(&"fanfare", 1.0, -6.0)
		screen.fx.confetti(at + Vector2(0, -40), 30, 360.0)
	screen.fx.callout(title, at, Palette.SUNNY, 38, sub, -3.0, 2.6)
	return true


func _golf_callout(rec: Dictionary) -> void:
	var golf := StringName(String(rec.get("golf", "par")))
	var slips := int(rec.get("slips", 0))
	var word := String(golf).replace("_", " ").capitalize() + "!"
	var sub := "%d strokes, par %d" % [int(rec.get("golf_strokes", 0)), int(rec.get("golf_par", 0))]
	var col: Color = SpeechScreen.GOLF_COLORS.get(golf, Palette.PAPER)
	if slips > 0 and golf not in [&"birdie", &"eagle", &"albatross", &"par"]:
		col = Palette.PAPER
	screen.fx.callout(word, callout_point() + Vector2(0, -30), col, 34, sub, randf_range(-6.0, 3.0), 1.6)


# ---------------------------------------------------------------- techniques and Hoot's lines

func on_technique(kind: StringName, data: Dictionary) -> bool:
	if not _on():
		return false
	match kind:
		&"aside":
			screen.bubble.aside = _say(String(data.get("text", "")))
			return true
		&"boo":
			ghost.pop()
			Sfx.play(&"whoosh", 1.3, -10.0)
			return true
		&"call_it":
			return true   # the card said it all; the answer is in the list's call_its
		&"wrs_done":
			_end_line(String(data.get("message", "")))
			if int(data.get("points", 0)) > 0:
				# above the golf callout (which sits just over the running line)
				screen.fx.callout("+%d" % int(data["points"]), callout_point() + Vector2(0, -96), Palette.MINT, 22, "", 0.0, 0.9)
			return true
		&"wrs_verdict":
			for line: Variant in data.get("lines", []):
				_end_line(String(line))
			return true
		&"rollover_found", &"wrs_below_predicted", &"wrs_asymmetry":
			_end_line(String(data.get("message", "")))
			return true
		&"audible_miss":
			_stamp_t = screen.clock()
			_stamp_word = String(data.get("word", ""))
			Sfx.play(&"stamp", 1.1, -6.0)
			return false   # the screen shows the tip
	return false


func kind_class(kind: StringName) -> StringName:
	match kind:
		&"wrs_level", &"rollover_level", &"wrs_unmasked":
			return &"error"
		&"misscored":
			return &"repeat"
		&"speech_textbook", &"wrs_good_start", &"wrs_mask_ok":
			return &"clean"
		&"ghost_word", &"cross_heard_speech":
			return &"hold"
	return &""


func target_for(kind: StringName, data: Dictionary) -> String:
	match kind:
		&"misscored":
			return "speech_incorrect_button" if bool(data.get("scored", false)) else "speech_correct_button"
		&"wrs_level", &"rollover_level":
			return "speech_louder_button" if int(data.get("got", 0)) < int(data.get("expected", 0)) else "speech_softer_button"
		&"wrs_unmasked", &"wrs_mask_ok", &"wrs_mask_capped", &"wrs_noise_locked":
			return "speech_mask_button"
		&"wrs_good_start", &"speech_textbook", &"wrs_no_store", &"wrs_list_reused":
			return "speech_score_strip"
		&"ghost_lurk":
			return "speech_ghost"
		&"wrs_ghost_busted":
			return "speech_mask_button"   # the Ghost has flown: the noise that busted it
		# never the card: the hand would sit on the word the player reads
		&"ghost_word", &"score_first", &"audible_miss", &"wrs_faint_hit_after":
			return "speech_response"
		&"wrs_level_locked":
			return "speech_louder_button"
	return ""


func mastery_skill(kind: StringName) -> StringName:
	match kind:
		&"speech_textbook":
			return &"wrs_score"
		&"wrs_good_start", &"wrs_mask_ok":
			return &"wrs_setup"
	return &""


func callout_point() -> Vector2:
	if strip == null or not strip.visible:
		return Vector2.ZERO
	return strip.running_line_global()


## A Hoot line that must wait its turn behind the coach: it goes out as a technique kind of its own,
## so the screen shows it as a tip (once per visit) or in the coach's place for a moment.
func _hoot_line(kind: StringName, text: String) -> void:
	screen.session.emit_kind(kind, {"line": true}, _fill(text))


## An end-of-list line (the verdicts): said once per list, even after Hoot's turn. No ghost hand:
## the strip, the board and the ear compare all carry the numbers, and a hand would cover them.
func _end_line(text: String) -> void:
	if text == "" or _said_lines.has(text):
		return
	_said_lines[text] = true
	Hoot.say(_fill(text), Hoot.HIGH, "", "", 4.0)


# ---------------------------------------------------------------- the coach and the beats

func coach_text(rec: Dictionary) -> Array:
	var none := ["", "", ""]
	if not _on():
		return none
	if _deny_up():
		return [_deny_line, _deny_target, "deny%d" % _deny_n]
	var w := _w()
	if w.is_empty() or bool(w["done"]):
		return none
	var s := screen.session
	var act := StringName(String(rec.get("action", "none")))
	var n := int(w["word_n"])
	if _lens_try_due():
		return [_fill(LINES["lens_try"]), "speech_lens_button", "lens_try"]
	if act == &"call_it":
		return [_fill(LINES["call_it"]), "", "callit%d" % n]   # no hand: it would give the answer away
	if screen.busy():
		return [_fill(LINES["busy"]), "speech_response", "busy%d" % n]
	var target := int(rec.get("target_db", s.db))
	match act:
		&"louder", &"softer":
			var up := act == &"louder"
			var key := "level_up" if up else "level_down"
			var pta := s.pta_for(s.ear)
			var p := roundi(pta) if not is_nan(pta) else 0
			if int(w["louder_than"]) > 0:
				key = "louder_up" if up else "louder_down"
			elif int(_plan.get("redo_of", 0)) > 0:
				key = "redo_up" if up else "redo_down"
			elif p + SpeechRules.WRS_ABOVE_PTA_DB < SpeechRules.WRS_MIN_DB:
				key = "level_low_up" if up else "level_low_down"
			var line := LINES[key].replace("{pta}", str(p)).replace("{sum}", str(p + SpeechRules.WRS_ABOVE_PTA_DB)) \
				.replace("{target}", str(target)).replace("{n}", str(int(w["list_n"])))
			return [_fill(line), "speech_louder_button" if up else "speech_softer_button", "lvl_%s_%d" % [String(act), target]]
		&"mask_toggle":
			return [_fill(LINES["mask"]), "speech_mask_button", "mask"]
		&"present":
			if not bool(w["started"]):
				var line := LINES["first_masked"] if s.mask_on else LINES["first_quiet"]
				return [_fill(line), "speech_present_button", "present0"]
			return [_fill(LINES["next"]), "speech_present_button", "present%d" % n]
		&"score_correct":
			var st := StringName(String(s.current.get("style", "")))
			var line := LINES["score_chatty"] if st == &"chatty_hit" else (LINES["score_self"] if st == &"self_correct" else LINES["score_hit"])
			return [_fill(line), "speech_correct_button", "score%d" % n]
		&"score_missed":
			var line := LINES["score_miss"]
			if bool(s.current.get("trap", false)):
				line = LINES["score_plural"]
			elif bool(s.current.get("rhyme", false)):
				line = LINES["score_rhyme"]
			return [_fill(line), "speech_incorrect_button", "score%d" % n]
	return none


func beat_id(rec: Dictionary) -> StringName:
	match StringName(String(rec.get("action", ""))):
		&"lens_toggle":
			return &"lens_try"
		&"call_it":
			return &"call_it"
	return &"speech"


func beat_action(rec: Dictionary) -> Dictionary:
	if not _on():
		return {}
	var s := screen.session
	if _demo_pending or _demo_running or _confirm_up():
		return {"action": &"none", "target_db": s.db}
	if _lens_try_due():
		return {"action": &"lens_toggle", "target_db": s.db}
	return rec if rec.has("action") else {}


func beat_info(info: Dictionary) -> Dictionary:
	var w := _w()
	if w.is_empty():
		return info
	info["list"] = String(w["list_id"])
	info["list_n"] = int(w["list_n"])
	info["word_n"] = int(w["word_n"])
	info["louder_than"] = int(w["louder_than"])
	if String(info.get("action", "")) == "call_it":
		var rec := screen.session.recommended_action()
		var guess := bool(rec.get("guess", true))
		info["word"] = String(w["call_it_word"])
		info["prompt"] = _call_prompt(w)
		info["options"] = [
			{"id": "call_it_yes_button", "label": _yes.text, "input": "speech_correct", "guess": true},
			{"id": "call_it_no_button", "label": _no.text, "input": "speech_incorrect", "guess": false}]
		info["best"] = "call_it_yes_button" if guess else "call_it_no_button"
	return info


func beat_key(rec: Dictionary) -> String:
	var s := screen.session
	var w := _w()
	return "wrs|%s|%d|%s|%d|%s|%s" % [s.measure_key(), int(w.get("word_n", 0)), String(rec.get("action", "none")), s.db, s.mask_on, _lens_on()]


# ---------------------------------------------------------------- Hoot's turn (and the chat demo)

func hoot_turn_text() -> String:
	if not _on():
		return ""
	var s := screen.session
	if _demo_running:
		var first := _demo_lines()
		if not first.is_empty() and _is_hoot(String((first[0] as Array)[0])):
			return _fill(String((first[0] as Array)[1]))
		return _fill(LINES["demo_turn"].replace("{db}", str(s.db)))
	var w := _w()
	if bool(w.get("confirmed_wrong", false)):
		return _fill(LINES["confirmed_turn"])
	return _fill(String(w.get("hoot_turn_text", WrsTest.HOOT_TURN_TEXT)))


func hoot_step() -> float:
	if not _demo_running:
		return -1.0
	var lines := _demo_lines()
	var c := screen.clock()
	if _demo_i > 0 and _demo_i <= lines.size():
		var shown := c - _demo_t
		var clicked := _demo_tip >= 0 and int(Hoot.current_tip().get("id", -1)) != _demo_tip
		if shown < DEMO_LINE_S and not clicked:
			return 0.1
	if _demo_i >= lines.size():
		_finish_demo()
		return -2.0
	var line: Array = lines[_demo_i]
	_demo_i += 1
	_demo_t = c
	var who := String(line[0])
	var text := String(line[1])
	_demo_tip = -1
	if _is_hoot(who):
		# URGENT: the line shows now, in step with her bubble (a queued line would race ahead)
		_demo_tip = Hoot.say(_fill(text), Hoot.URGENT, "", "", DEMO_LINE_S)
	else:
		screen.bubble.show_answer(_say(text))
		Juice.pop(screen.bubble, 1.06, 0.25)
		Events.dialogue_line.emit(screen.session.patient.short_name(), _say(text))
	return 0.1


## The chat demo (D28): a Hoot turn at speed 1 before List 2's first word. The dial parks at the
## demo's level, the card shows its text and the REACHES HER row (lens or not); nothing is presented,
## dealt or locked.
func _start_demo() -> void:
	if not _demo_pending or not _on() or not screen.is_inside_tree():
		_demo_pending = false
		return
	var s := screen.session
	var demo: Dictionary = _plan.get("chat_demo", {})
	_demo_pending = false
	if bool(_w().get("started", false)):
		return
	s.set_level(int(demo.get("level", SpeechRules.CHAT_DB)))
	# the demo's first line is the turn's own line: it goes on the perch now, and the tip it pushes
	# aside (the list's intro) comes back after the demo
	var cur := Hoot.current_tip()
	_demo_kept = {} if cur.is_empty() else {"text": String(cur.get("text", "")), "target": String(cur.get("target", ""))}
	Hoot.clear()
	_demo_running = true
	_demo_i = 0
	var lines := _demo_lines()
	if not lines.is_empty() and _is_hoot(String((lines[0] as Array)[0])):
		_demo_i = 1   # the first Hoot line is the turn's own line
	_demo_t = screen.clock()
	screen.hoot_turn(1.0)
	if not screen.hoot_running():
		_demo_running = false   # no turn (a hidden run, or the list is over): no demo
		return
	screen.refresh()


func _finish_demo() -> void:
	_end_demo_view()
	var s := screen.session
	if s != null:
		screen.memory["demo_done:" + s.measure_key()] = true
	screen.bubble.clear()
	if _demo_tip >= 0:
		Hoot.dismiss(_demo_tip)
	_demo_tip = -1
	if not _demo_kept.is_empty() and String(_demo_kept["text"]) != "":
		Hoot.say(String(_demo_kept["text"]), Hoot.NORMAL, String(_demo_kept["target"]))
	_demo_kept = {}


func _end_demo_view() -> void:
	if not _demo_running:
		return
	_demo_running = false
	if screen != null and screen.card != null:
		screen.card.hide_word = false


func _demo_lines() -> Array:
	var demo: Dictionary = _plan.get("chat_demo", {})
	var out: Array = []
	for l: Variant in demo.get("lines", []):
		if l is Array and (l as Array).size() >= 2:
			out.append(l)
	return out


static func _is_hoot(who: String) -> bool:
	return who.to_lower() in ["hoot", "professor hoot", "h"]


# ---------------------------------------------------------------- the views

func lcd_view(view: Dictionary) -> Dictionary:
	var w := _w()
	if w.is_empty():
		return view
	var s := screen.session
	view["test_chip"] = "WORDS"
	var words := int(w["words"])
	var shown_n := int(w["word_n"]) if (screen.busy() or s.awaiting_score or bool(w["done"])) else mini(words, int(w["word_n"]) + 1)
	view["info_line"] = "%s · word %d of %d · %d%% so far" % [String(w["list_title"]), maxi(1, shown_n), words, int(w["pct_so_far"])]
	var pta := s.pta_for(s.ear)
	var diff := 0
	if int(w["louder_than"]) > 0:
		var comfy := int(w["comfy_db"])
		diff = s.db - comfy
		view["start_chip"] = "LOUDER = COMFY %d %s %d = %d" % [comfy, "+" if diff >= 0 else "-", absi(diff), s.db]
	elif not is_nan(pta):
		var p := roundi(pta)
		diff = s.db - p
		view["start_chip"] = "PTA %d %s %d = %d · min %d" % [p, "+" if diff >= 0 else "-", absi(diff), s.db, SpeechRules.WRS_MIN_DB]
	var ia := int(SpeechRules.SPEECH_IA_DB.get(s.transducer, 40))
	var best := float(w["nontest_best_bone"])
	var other := "left" if s.ear == "right" else "right"
	if bool(w["coached"]):
		var over := s.db - ia
		var needed := bool(w["masking_needed"])
		var sign := ">=" if needed else "<"
		var value := ("NOISE ON" if s.mask_on else "NOISE!") if needed else "NO NOISE"
		var label := "%d - %d = %d %s %s:" % [s.db, ia, over, sign, "--" if is_nan(best) else str(roundi(best))]
		view["aux"] = [{"label": label, "value": value}]
	else:
		# the solo list shows the rule and the other ear's number, never the answer
		view["aux"] = [{"label": "NOISE? LEVEL - %d vs %s BEST:" % [ia, other.to_upper()], "value": "--" if is_nan(best) else str(roundi(best))}]
		view["masking_needed"] = false
	return view


## [25 x 4%] [WHOLE WORD ONLY] [COMFY: PTA + 35] (§9.17.1). The screen lights the first chip after a
## word scored repeated and the second after a miss, so the order follows SpDance's GOT / MISSED.
func dance_specs() -> Array[Dictionary]:
	var w := _w()
	var level := {"title": "COMFY", "sub": "PTA + 35", "icon": &"none", "color": Palette.MINT}
	if not w.is_empty() and int(w["louder_than"]) > 0:
		level = {"title": "LOUDER", "sub": "COMFY + 20", "icon": &"none", "color": Palette.MINT}
	var words := int(w.get("words", SpeechRules.WRS_WORDS))
	return [
		{"title": "EACH WORD", "sub": "%d x %d%%" % [words, roundi(100.0 / maxf(1.0, words))], "icon": &"check", "color": Palette.PRESS_LIME},
		{"title": "WHOLE WORD", "sub": "ONLY", "icon": &"cross", "color": Palette.SUNNY},
		level,
	]


func refresh(st: Dictionary) -> void:
	if not _on():
		return
	var w: Dictionary = st.get("wrs", {})
	if w.is_empty():
		return
	var s := screen.session
	_update_ghost(st, w)
	_update_strip(w)
	_update_banana(w)
	_update_compare()
	_update_card(st, w)
	_update_buttons(st, w)
	if _lens_try_due() and not _lens_aside_done:
		_lens_aside_done = true
		s.observe_once("aside:lens", &"aside", {"text": _aside_text("lens"), "why": "lens"})
		if not bool(w["coached"]):
			Hoot.say_once("wrs_lens_try", _fill(LINES["lens_try"]), Hoot.NORMAL, "speech_lens_button")
	if _call_up() and not _call_seen:
		_call_seen = true
		Sfx.play(&"sparkle", 1.1, -10.0)
	elif not _call_up():
		_call_seen = false
	overlay.queue_redraw()


func _update_strip(w: Dictionary) -> void:
	strip.set_view({"title": String(w["list_title"]), "ear": screen.session.ear, "words": int(w["words"]), "right": int(w["right_so_far"]),
		"pct_so_far": int(w["pct_so_far"]), "show_ruler": bool(screen.memory.get("ruler_shown", false)),
		"predicted_min": int(w["predicted_min"]) if bool(w["best_final"]) else -1, "trials": screen.session.trials_for()})


func _update_banana(w: Dictionary) -> void:
	var s := screen.session
	banana.ear = s.ear
	banana.thresholds = s.measured_thresholds(s.ear)
	banana.dial_db = s.db
	banana.hint = "%s: %s" % [_lens_label(), screen.k(&"toggle_lens")]
	banana.predicted_min = int(w["predicted_min"])
	var sheet := _sheet(s.ear)
	banana.best = int(sheet.get("pb_max", -1))
	banana.best_final = bool(sheet.get("best_final", false))
	var slide: Array = []
	if int(sheet.get("louder_pct", -1)) >= 0 and int(sheet.get("pct", -1)) >= 0:
		slide = [[int(sheet["level_db"]), int(sheet["pct"])], [int(sheet["louder_level_db"]), int(sheet["louder_pct"])]]
		if not banana.is_revealed():
			banana.reveal(true)
			screen.memory["banana_shown"] = true
	banana.set_slide(slide)


func _update_compare() -> void:
	var r := _sheet("right")
	var l := _sheet("left")
	var rd := {"pct": int(r.get("pb_max", -1)), "words": SpeechRules.WRS_WORDS, "final": bool(r.get("best_final", false))}
	var ld := {"pct": int(l.get("pb_max", -1)), "words": SpeechRules.WRS_WORDS, "final": bool(l.get("best_final", false))}
	compare.set_ears(rd if int(rd["pct"]) >= 0 else {}, ld if int(ld["pct"]) >= 0 else {})
	if compare.ready_to_show() and not bool(screen.memory.get("compare_shown", false)):
		screen.memory["compare_shown"] = true
		if not _rects.is_empty():
			layout(_rects)
	compare.visible = bool(screen.memory.get("compare_shown", false))


func _update_ghost(st: Dictionary, w: Dictionary) -> void:
	var s := screen.session
	var on := bool(st["mask_on"])
	if on and not _mask_was:
		var was_boo := ghost.is_booing()
		if was_boo or ghost.shown_alpha() > 0.05:
			var at := ghost.bust()
			# across the booth window and out over the LCD side, never off the top of the screen
			var to := at + Vector2(-ghost.side * 150.0, 30.0)
			var b: Rect2 = _rects.get("booth", Rect2(12, 20, 292, 176))
			screen.fx.ghost(at, to, "GHOST BUSTED!", "", Vector2(b.get_center().x, b.position.y + 34.0), 1.8)
			Sfx.play(&"whoosh", 0.8, -8.0)
		if was_boo:
			_hoot_line(&"wrs_ghost_busted", LINES["busted"])
		_confirm_t = -100.0 if _confirm_why == &"unmasked" else _confirm_t
		if bool(w["masking_needed"]) and not bool(w["started"]):
			s.observe_once("aside:noise", &"aside", {"text": _aside_text("noise"), "why": "noise"})
	_mask_was = on
	if bool(w["started"]) or bool(w["done"]):
		if ghost.is_booing() or ghost.lurk > 0.0:
			ghost.reset()
		return
	if bool(w["coached"]) and bool(w["ghost_lurk"]):
		ghost.lurk = float(w["ghost_alpha"])
		if ghost.lurk > 0.0 and not _lurk_told and not screen.hoot_running():
			_lurk_told = true
			s.mode.act(&"ghost_lurk")
	else:
		ghost.lurk = 0.0


func _update_card(_st: Dictionary, w: Dictionary) -> void:
	var c := screen.card
	c.carrier = "LIST SAYS:"
	_row_items.clear()
	var s := screen.session
	if not s.current.is_empty():
		var cur := SpeechMaterial.item(s.list_id, String(s.current.get("item_id", "")))
		if not cur.is_empty():
			_row_items[String(cur.get("text", ""))] = cur
	var nx := s.next_item()
	if not nx.is_empty():
		_row_items[String(nx.get("text", ""))] = nx
	if bool(w["done"]):
		c.state = &"done"   # the screen's score path sets the card idle after the 25th mark
	if _demo_running:
		c.hide_word = true
		c.word_drawer = _draw_demo_card
	else:
		c.hide_word = false
		c.word_drawer = _draw_lens_row if _lens_on() and not bool(w["done"]) else Callable()
	c.queue_redraw()


func _update_buttons(st: Dictionary, w: Dictionary) -> void:
	var done := bool(w["done"]) or bool(st.get("finishing", false))
	_lens_btn.text = "LENS ON" if _lens_on() else "LENS OFF"
	_lens_btn.lamp = 1 if _lens_on() else 0
	_lens_btn.locked = done
	var try_due := _lens_try_due() and not screen.hoot_running()
	_lens_btn.beckon = try_due
	if try_due:
		var pb := screen.button(&"present")
		if pb != null:
			pb.beckon = false
	if not bool(w["coached"]):
		var mb := screen.button(&"mask_toggle")
		if mb != null:
			mb.beckon = false   # the solo noise decision is the player's: no hint
	_sync_call_buttons()


func _sync_call_buttons() -> void:
	if _yes == null:
		return
	var up := _call_up()
	for b: AoButton in [_yes, _no]:
		b.visible = up
		b.locked = false
		b.beckon = false
		b.queue_redraw()


func extra_state() -> Dictionary:
	return {"lens_on": _lens_on(), "confirm_pending": _confirm_up(), "practice": false, "demo": _demo_running or _demo_pending,
		"call_it_card": _call_up(), "banana_shown": banana != null and banana.is_revealed(),
		"ruler_shown": bool(screen.memory.get("ruler_shown", false)), "compare_shown": bool(screen.memory.get("compare_shown", false)),
		"stamp": _stamp_up(), "confirm_why": String(_confirm_why) if _confirm_up() else "", "deny_pending": _deny_up(),
		"ghost": {"alpha": ghost.shown_alpha() if ghost != null else 0.0, "lurk": ghost.lurk if ghost != null else 0.0,
			"booing": ghost != null and ghost.is_booing()}}


## run_hidden's show: the strip fills in finished and the band chip lands.
func montage(sheet: Dictionary) -> float:
	var lists: Array = sheet.get("lists", [])
	if lists.is_empty() or strip == null:
		return -1.0
	var rec: Dictionary = lists.back()
	screen.memory["ruler_shown"] = true
	strip.set_view({"title": String(rec.get("list_title", "")), "ear": String(sheet.get("ear", "right")), "words": int(rec.get("words", 25)),
		"right": int(rec.get("right", 0)), "pct_so_far": int(rec.get("pct", 0)), "show_ruler": true, "trials": rec.get("trials", [])})
	strip.land_band(StringName(String(rec.get("band", ""))), int(rec.get("pct", 0)))
	_update_compare()
	screen.fx.chip("Hoot: %s, %d%%" % [String(rec.get("list_title", "")), int(rec.get("pct", 0))], strip.get_global_rect().get_center(),
		Palette.HOOT_FACE, Palette.INK, 16, 1.6)
	return 2.5


func _process(_delta: float) -> void:
	if screen == null or overlay == null or not _on():
		return
	if overlay.visible:
		overlay.queue_redraw()
	var c := screen.clock()
	if _confirm_t >= 0.0 and c - _confirm_t >= CONFIRM_S:
		_confirm_t = -100.0
		screen.refresh()
	if _deny_t >= 0.0 and c - _deny_t >= DENY_S:
		_deny_t = -100.0
		screen.refresh()


# ---------------------------------------------------------------- the lens

## The lens row of `item` at `db`: each spelling piece with its sound, margin (dB above her measured
## threshold; INF for a silent piece), alpha (SpeechRules.lens_alpha) and style (&"plain" silent,
## &"lost" below 0, &"just" 0 to 3, &"clear").
func lens_row(item: Dictionary, db: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var s := screen.session
	var thr := s.measured_thresholds(s.ear) if s != null else {}
	for c: Variant in SpeechRules.chunk_sounds(item):
		var piece: Array = c
		var sound := String(piece[1])
		if sound == "":
			out.append({"piece": String(piece[0]), "sound": "", "margin": INF, "alpha": 1.0, "style": &"plain"})
			continue
		var m := SpeechRules.sound_margin(sound, db, thr)
		var style := &"clear"
		if m < 0.0:
			style = &"lost"
		elif m < 3.0:
			style = &"just"
		out.append({"piece": String(piece[0]), "sound": sound, "margin": m, "alpha": SpeechRules.lens_alpha(m), "style": style})
	return out


## How the row turns into her answer: &"fade" with reduced motion, else &"scramble".
static func scramble_style() -> StringName:
	return &"fade" if AoFx._reduced() else &"scramble"


func _draw_lens_row(c: SpWordCard, row: Rect2) -> void:
	var item: Dictionary = _row_items.get(c.shown_word(), {})
	if item.is_empty() or row.size.y < 14.0:
		return
	var s := screen.session
	var db := float(int(s.current.get("db", s.db))) if not s.current.is_empty() and String(s.current.get("item_id", "")) == String(item.get("id", "")) else float(s.db)
	var y := row.get_center().y
	var k := -1.0
	if not _scramble.is_empty() and String(_scramble["item_id"]) == String(item.get("id", "")):
		k = clampf((screen.clock() - float(_scramble["t0"])) / SCRAMBLE_S, 0.0, 1.0)
	var label := _say("REACHES {him}:" if k < 0.5 else "{He} SAID:").to_upper()
	var lw := AoDraw.text_l(c, Vector2(row.position.x, y), label, 10, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var area := Rect2(Vector2(row.position.x + lw + 8.0, row.position.y), Vector2(row.size.x - lw - 8.0, row.size.y))
	var pieces := lens_row(item, db)
	if k < 0.0:
		_draw_pieces(c, area, pieces, 1.0)
		return
	var to := String(_scramble["to"]).to_upper()
	if scramble_style() == &"fade":
		_draw_pieces(c, area, pieces, 1.0 - k)
		_draw_plain(c, area, to, k)
		return
	if k >= 1.0:
		_draw_plain(c, area, to, 1.0)
		return
	# the letters tumble: each position shows a random letter until it settles on her answer's
	var src := ""
	for p: Dictionary in pieces:
		src += String(p["piece"]).to_upper()
	var n := maxi(src.length(), to.length())
	var shown := ""
	var settle := int(floor(k * (n + 1)))
	var seed_i := int(screen.clock() * 30.0)
	for i in n:
		if i < settle:
			shown += to[i] if i < to.length() else ""
		elif to.length() > i and to[i] == " ":
			shown += " "
		else:
			shown += String.chr(65 + ((seed_i * 7 + i * 13) % 26))
	_draw_plain(c, area, shown, 1.0)


## The pieces at their lens alpha (times `a`), shrunk to fit, with the dotted outline (lost) and the
## dotted underline (only just).
func _draw_pieces(c: Control, area: Rect2, pieces: Array[Dictionary], a: float) -> void:
	if a <= 0.01 or pieces.is_empty():
		return
	var fs := 24
	var total := 0.0
	while fs > 12:
		total = 0.0
		for p: Dictionary in pieces:
			total += AoDraw.text_size(String(p["piece"]).to_upper(), fs, AoDraw.FONT_BOLD).x + 2.0
		if total <= area.size.x:
			break
		fs -= 2
	var x := area.position.x + maxf(0.0, (area.size.x - total) * 0.5)
	var y := area.get_center().y
	for p: Dictionary in pieces:
		var txt := String(p["piece"]).to_upper()
		var w := AoDraw.text_size(txt, fs, AoDraw.FONT_BOLD).x
		var style := StringName(p["style"])
		var alpha := float(p["alpha"]) * a
		if txt.strip_edges() != "":
			AoDraw.text_l(c, Vector2(x, y), txt, fs, Color(Palette.INK, alpha), AoDraw.FONT_BOLD)
		match style:
			&"lost":
				var r := Rect2(Vector2(x - 1.0, y - fs * 0.55), Vector2(w + 2.0, fs * 1.1))
				var col := Color(Palette.INK_SOFT, 0.75 * a)
				var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
				for i in 4:
					AoDraw.dashed(c, pts[i], pts[(i + 1) % 4], col, 1.5, 3.0, 3.0)
			&"just":
				AoDraw.dashed(c, Vector2(x, y + fs * 0.52), Vector2(x + w, y + fs * 0.52), Color(Palette.SELECT_ORANGE.darkened(0.2), a), 2.0, 3.0, 3.0)
		x += w + 2.0


func _draw_plain(c: Control, area: Rect2, text: String, a: float) -> void:
	if a <= 0.01 or text == "":
		return
	var fs := 22
	while fs > 11 and AoDraw.text_size(text, fs, AoDraw.FONT_BOLD).x > area.size.x:
		fs -= 1
	AoDraw.text_c(c, area.get_center(), text, fs, Color(Palette.CORAL.darkened(0.25), a), AoDraw.FONT_BOLD)


## The chat demo's card: what the line says, crisp, and what reaches her (the demo's own chunks).
func _draw_demo_card(c: SpWordCard, body: Rect2) -> void:
	var demo: Dictionary = _plan.get("chat_demo", {})
	if demo.is_empty():
		return
	var text := String(demo.get("text", ""))
	var db := float(int(demo.get("level", SpeechRules.CHAT_DB)))
	var x := body.position.x
	AoDraw.text_l(c, Vector2(x, body.position.y + 10.0), "LIST SAYS:", 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var fs := 24
	while fs > 12 and AoDraw.text_size(text, fs, AoDraw.FONT_BOLD).x > body.size.x:
		fs -= 1
	AoDraw.text_c(c, Vector2(body.get_center().x, body.position.y + 36.0), text, fs, Palette.INK, AoDraw.FONT_BOLD)
	var ry := body.position.y + 64.0
	AoDraw.text_l(c, Vector2(x, ry), _say("REACHES {him}").to_upper() + " (%d dB):" % int(db), 11, Palette.INK_SOFT, AoDraw.FONT_BOLD)
	var pieces := lens_row({"text": text, "chunks": demo.get("chunks", [])}, db)
	_draw_pieces(c, Rect2(Vector2(x, ry + 12.0), Vector2(body.size.x, maxf(20.0, body.end.y - ry - 12.0))), pieces, 1.0)


# ---------------------------------------------------------------- the overlay (Call it, the chip, the stamp)

func _draw_overlay() -> void:
	if not _on():
		return
	if _stamp_up():
		_draw_stamp()
	if _call_up():
		_draw_call_card()
	if _confirm_up():
		_draw_confirm_chip()


func _draw_call_card() -> void:
	var o := overlay
	var r := _call_rect
	AoDraw.rbox(o, Rect2(r.position + Vector2(0, 6), r.size), Color(Palette.INK, 0.3), 22)
	AoDraw.rbox(o, r, Palette.PAPER, 22, 4, Palette.INK)
	var tag := Rect2(r.position + Vector2(18, -14), Vector2(116, 28))
	AoDraw.rbox(o, tag, Palette.SUNNY, 14, 3, Palette.INK)
	AoDraw.text_c(o, tag.get_center(), "CALL IT!", 16, Palette.INK, AoDraw.FONT_BOLD)
	AoDraw.text_r(o, Vector2(r.end.x - 18.0, r.position.y + 18.0), "unscored: your guess", 12, Palette.INK_SOFT, AoDraw.FONT_SEMI)
	var prompt := _call_prompt(_w())
	var lines := AoFx._wrap(prompt, 19, r.size.x - 40.0)
	var y := r.position.y + 50.0
	for ln: String in lines:
		AoDraw.text_c(o, Vector2(r.get_center().x, y), ln, 19, Palette.INK, AoDraw.FONT_BOLD)
		y += 24.0


func _draw_confirm_chip() -> void:
	var o := overlay
	var pb := screen.button(&"present")
	var anchor := pb.get_global_rect() if pb != null else Rect2(400, 560, 200, 120)
	var lines := _confirm_lines()
	var w := 0.0
	for i in lines.size():
		w = maxf(w, AoDraw.text_size(lines[i], 16 if i == 0 else 14, AoDraw.FONT_BOLD).x)
	w = minf(w + 40.0, o.size.x - 24.0)
	var h := 26.0 + 22.0 * lines.size()
	var cx := clampf(anchor.get_center().x, 12.0 + w * 0.5, o.size.x - 12.0 - w * 0.5)
	var r := Rect2(Vector2(cx - w * 0.5, anchor.position.y - h - 14.0), Vector2(w, h))
	var boo := _confirm_why == &"unmasked"
	var col := Palette.CORAL if boo else Palette.SUNNY
	AoDraw.rbox(o, Rect2(r.position + Vector2(0, 4), r.size), Color(Palette.INK, 0.3), 16)
	AoDraw.rbox(o, r, Palette.PAPER, 16, 3, col.darkened(0.2))
	for i in lines.size():
		AoDraw.text_c(o, Vector2(r.get_center().x, r.position.y + 20.0 + 22.0 * i), lines[i], 16 if i == 0 else 14,
			Palette.INK if i == 0 else Palette.INK_SOFT, AoDraw.FONT_BOLD)
	# what is left of the chip's 4 seconds
	var left := clampf(1.0 - (screen.clock() - _confirm_t) / CONFIRM_S, 0.0, 1.0)
	var bar := Rect2(Vector2(r.position.x + 16.0, r.end.y - 9.0), Vector2((r.size.x - 32.0) * left, 4.0))
	AoDraw.rbox(o, bar, col, 2)


func _draw_stamp() -> void:
	var o := overlay
	var cr := screen.card.get_global_rect()
	var k := clampf((screen.clock() - _stamp_t) / 0.25, 0.0, 1.0)
	var s := 1.0 if AoFx._reduced() else 1.0 + 0.7 * (1.0 - k) * (1.0 - k)
	var a := k if AoFx._reduced() else minf(1.0, k * 2.0)
	var c := Vector2(cr.get_center().x + 8.0, cr.position.y + 58.0)
	o.draw_set_transform(c, deg_to_rad(-8.0), Vector2.ONE * s)
	var txt := "AUDIBLE, BUT MISSED."
	var w := AoDraw.text_size(txt, 17, AoDraw.FONT_BOLD).x + 26.0
	var r := Rect2(Vector2(-w * 0.5, -22.0), Vector2(w, 44.0))
	AoDraw.rbox(o, r, Color(Palette.PAPER, 0.92 * a), 8, 3, Color(Palette.RIGHT_RED, a))
	AoDraw.ring(o, r.grow(-5.0), Color(Palette.RIGHT_RED, 0.6 * a), 6, 1)
	AoDraw.text_c(o, Vector2(0, -6), txt, 17, Color(Palette.RIGHT_RED, a), AoDraw.FONT_BOLD)
	if _stamp_word != "":
		AoDraw.text_c(o, Vector2(0, 11), "'%s': every sound arrived" % _stamp_word, 11, Color(Palette.INK_SOFT, a), AoDraw.FONT_SEMI)
	o.draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- helpers

## This screen's list is a word list.
func _on() -> bool:
	return screen != null and screen.session != null and screen.session.test == &"wrs" and screen.session.mode != null


func _w() -> Dictionary:
	if not _on():
		return {}
	return screen.session.mode.state()


func _sheet(ear: String) -> Dictionary:
	var s := screen.session
	if s == null or not s.sheets.has(&"wrs"):
		return {}
	return (s.sheets[&"wrs"] as Dictionary).get(ear, {})


func _lens_on() -> bool:
	return screen != null and bool(screen.memory.get("lens_on", false))


## "NORA-VISION": the patient's short name in capitals, plus "-VISION".
func _lens_label() -> String:
	return _lens_name().to_upper()


func _lens_name() -> String:
	var s := screen.session if screen != null else null
	var who := s.patient.short_name() if s != null and s.patient != null else "Patient"
	return who + "-vision"


## The player's scored words on this list.
func _units() -> int:
	var n := 0
	for tr: Dictionary in screen.session.trials_for():
		if not bool(tr.get("by_hoot", false)) and tr.get("scored") != null:
			n += 1
	return n


## lens_try (once per visit): after plan lens_try_after player words, with the lens still off.
func _lens_try_due() -> bool:
	var after := int(_plan.get("lens_try_after", 0))
	if after <= 0 or not _on() or bool(screen.memory.get("lens_try_done", false)) or _lens_on():
		return false
	var w := _w()
	if bool(w["done"]) or StringName(w["call_it_pending"]) != &"" or screen.session.awaiting_score:
		return false
	return _units() >= after


## The Call it card is up: a moment is due, the player's turn, nothing playing.
func _call_up() -> bool:
	if not _on() or screen.hoot_running() or screen.busy():
		return false
	var w := _w()
	return not bool(w["done"]) and StringName(w["call_it_pending"]) != &""


func _call_prompt(w: Dictionary) -> String:
	var moment := StringName(w.get("call_it_pending", &""))
	if moment == &"":
		return ""
	var key := "prompt_" + String(moment)
	var t := String(LINES.get(key, LINES["prompt_audible_miss"]))
	t = t.replace("{word}", String(w.get("call_it_word", ""))).replace("{chunk}", String(w.get("call_it_chunk", "")))
	return _fill(t)


func _confirm_up() -> bool:
	return _confirm_t >= 0.0 and screen.clock() - _confirm_t < CONFIRM_S


func _deny_up() -> bool:
	return _deny_t >= 0.0 and screen.clock() - _deny_t < DENY_S


func _stamp_up() -> bool:
	return _stamp_t >= 0.0 and not screen.busy()


func _confirm_lines() -> PackedStringArray:
	var s := screen.session
	var target := int(s.mode.textbook_target())
	if _confirm_why == &"unmasked":
		return PackedStringArray([_fill(LINES["boo"].replace("{db}", str(s.db))), _fill(LINES["boo_2"])])
	var first := LINES["confirm_louder"] if int(_w().get("louder_than", 0)) > 0 else LINES["confirm_level"]
	return PackedStringArray([_fill(first.replace("{target}", str(target))), _fill(LINES["confirm_level_2"].replace("{db}", str(s.db)))])


func _aside_text(key: String) -> String:
	var given: Dictionary = _plan.get("asides", {})
	return String(given.get(key, DEFAULT_ASIDES.get(key, "")))


## {key:<action>} chips, {Lens}, {ear} and the patient's pronouns.
func _fill(text: String) -> String:
	var t := text
	var at := t.find("{key:")
	while at >= 0:
		var end := t.find("}", at)
		if end < 0:
			break
		var chip := screen.k(StringName(t.substr(at + 5, end - at - 5)))
		t = t.substr(0, at) + chip + t.substr(end + 1)
		at = t.find("{key:", at + chip.length())
	t = t.replace("{Lens}", _lens_name())
	if screen.session != null:
		t = t.replace("{ear}", screen.session.ear)
	return _say(t)


func _say(t: String) -> String:
	return screen.say(t) if screen != null else t


static func _norm(t: String) -> String:
	var out := ""
	for ch in t.to_lower():
		if (ch >= "a" and ch <= "z") or ch == " ":
			out += ch
	return out.strip_edges()
