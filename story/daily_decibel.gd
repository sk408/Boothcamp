extends CanvasLayer
## DailyDecibel (CanvasLayer 40): the end-of-visit newspaper.
##   var next: String = await paper.show_summary(Game.finish_visit())   # "title" or "again"
## Headline from the grade, score bars, micro-game medals, a golf card per frequency,
## a coin count-up and the one-item upgrade shop (comfy chair, saved in Game.progress).
## Keys: B buys, A plays again, Enter / Space continues to the title. Every control is clickable.
## Beat: results_continue. Left alone for IDLE_S (a booth display), it returns to the title.
## (v3) Day-aware: headlines per chapter, "Vol. <day>", the shop item of that day (Game.SHOP_ITEMS)
## and a "Next day" button (key N, returns "next") once the next chapter is open.
## (Speech) On a speech day (audiometry results with "speech", CONTRACTS.md §9.5) column 2 is the
## word golf card instead: per ear the stored SRT, the PTA, the agreement chip and words vs par.

signal _continued

const UiKit := preload("res://story/ui_kit.gd")
const NEWSPRINT := Color("#f5efdf")
const CHAIR_ID := "comfy_chair"
const CHAIR_COST := 40
const IDLE_S := 90.0

const HEADLINES: Dictionary = {
	"S": "TRAINEE BEEPS PERFECTLY; OWL WEEPS WITH PRIDE",
	"A": "LOCAL GRANDPA HEARS \"DISHES\" FOR FIRST TIME IN YEARS",
	"B": "SOLID BEEPING REPORTED AT BOOTH CAMP",
	"C": "BEEPS MOSTLY BEEPED, CONFIRMS OWL",
	"Do-over": "TRAINEE DEMANDS REMATCH; GUS HAPPY TO COME BACK (\"THEY HAVE BAGELS\")",
}
const SUBHEADS: Dictionary = {
	"S": "Hoot calls the audiogram \"frame-worthy\". Gus frames it.",
	"A": "Doris reports dishes finally done. \"I'm framing the sponge.\"",
	"B": "Gus: \"Best beeps I've had all week.\"",
	"C": "A few beeps went astray. Hoot recommends practice and a snack.",
	"Do-over": "Experts agree: every audiologist's first booth is a little wobbly.",
}
## (v3) Day 2 (Bonnie): grade -> headline / subhead.
const CHAPTER_HEADLINES: Dictionary = {
	"bonnie": {
		"S": "GHOST BUSTED: TRAINEE MASKS LIKE A PRO",
		"A": "BAKER'S EAR SENT TO ENT; OWL SUSPECTS A STIFF LITTLE BONE",
		"B": "BONE BEEPS BRAVELY BEEPED AT BOOTH CAMP",
		"C": "NOISE MOSTLY IN THE RIGHT EAR, CONFIRMS OWL",
		"Do-over": "BONNIE BACK TOMORROW WITH CROISSANTS; GHOST STILL AT LARGE",
	},
	# (Speech) Day 3 (Mike): forklift and needle puns, never an accusation
	"mike": {
		"S": "TRAINEE'S SRT LIFTS THE CASE; NEEDLE CLUNKS, NOBODY BLAMED",
		"A": "FORKLIFT LEGEND HEARS \"GLAZED\" FROM THE HALLWAY",
		"B": "SPEECH TEST DELIVERS THE GOODS, PALLET BY PALLET",
		"C": "SOME WORDS FELL OFF THE FORKLIFT, CONFIRMS OWL",
		"Do-over": "MIKE BACK TOMORROW; NECK BRACE OPTIONAL",
	},
}
const CHAPTER_SUBHEADS: Dictionary = {
	"bonnie": {
		"S": "A textbook plateau at every pitch. The Cross-Hearing Ghost has filed a complaint.",
		"A": "Air down, bone up: a conductive loss, referred to the ear doctor. Bonnie brings scones.",
		"B": "The plateau held; a few noise steps wandered. Hoot recommends more practice and a bun.",
		"C": "Some masked beeps went astray. Remember: heard means noise up 5.",
		"Do-over": "Masking is the trickiest trick in the booth. Everyone overmasks once.",
	},
	"mike": {
		"S": "Words and beeps disagreed by a mile. Recheck and objective tests booked, kindly.",
		"A": "Poor agreement, recorded without blame. Objective tests next. The donuts were glazed.",
		"B": "Words bracketed, needle read, referral stamped. One more lap of the dance, says Hoot.",
		"C": "A few words went astray. Remember: got it, down 10; missed it, up 5.",
		"Do-over": "Speech testing is a whole new dance. Everyone steps on a toe once.",
	},
}
const MEDAL_COLORS: Dictionary = {"gold": Color("#ffc93c"), "silver": Color("#c9ced8"), "bronze": Color("#d99a5b")}
const MEDAL_BEATS: Array[Array] = [["history", "Chat"], ["otoscopy", "Peek"], ["earphones", "Phones"], ["evidence", "Evidence"]]
## (v3) Medal rows per chapter (chapters not listed use MEDAL_BEATS).
const CHAPTER_MEDAL_BEATS: Dictionary = {
	"bonnie": [["history", "Chat"], ["bc_placement", "Bone"], ["masking", "Mask"], ["evidence", "Case"], ["referral", "Refer"]],
	"mike": [["history", "Chat"], ["instructions", "Explain"], ["familiarize", "Words"], ["evidence", "Case"], ["referral", "Next"]],
}
## (v3) Extra golf-card rows for the bone and masked sheets: [sheet key, label, ear].
const GOLF_EXTRA_ROWS: Array[Array] = [["bc_masked", "R  [", "right"], ["ac_masked", "R  O+", "right"],
	["bc_masked", "L  ]", "left"], ["ac_masked", "L  □", "left"]]
const GOLF_COLORS: Dictionary = {
	&"albatross": Color("#8e5cc4"), &"eagle": Color("#2d6cdf"), &"birdie": Color("#2f9e73"), &"par": Color("#6b5e7e"),
	&"bogey": Color("#e08a1c"), &"double_bogey": Color("#e5383b"), &"triple_bogey": Color("#b02a2d"),
	&"hoot": Color("#8a6a4a"),
}
## (Speech) PTA/SRT agreement chip colours.
const AGREE_COLORS: Dictionary = {&"good": Color("#2f9e73"), &"fair": Color("#e08a1c"), &"poor": Color("#e5383b")}

var _paper: PanelContainer
var _coins_label: Label
var _total_label: Label
var _buy: Button
var _shop_note: Label
var _summary: Dictionary = {}
var _accepting := false
var _done := false
var _next := "title"
var _idle := 0.0
## (polish) the "UP NEXT!" rubber stamp on the masthead (null unless this visit was a first clear)
var _unlock_stamp: Control


func _ready() -> void:
	layer = 40


func _process(delta: float) -> void:
	if _accepting and not get_tree().paused:
		_idle += delta
		if _idle > IDLE_S:
			_continue()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event.is_pressed():
		_idle = 0.0


## (coroutine) summary: CONTRACTS.md §5.3. Returns "title", "again" (same patient again) or
## (v3) "next" (start summary.next_chapter_id).
func show_summary(summary: Dictionary) -> String:
	_summary = summary
	_build(summary)
	await get_tree().process_frame
	_paper.pivot_offset = _paper.size * 0.5
	_paper.rotation = -0.9
	_paper.scale = Vector2(0.15, 0.15)
	var t := create_tween().set_parallel(true)
	t.tween_property(_paper, "rotation", -0.015, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_paper, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play(&"whoosh")
	await t.finished
	Sfx.play(&"stamp")
	Events.screen_shake.emit(0.2, 0.15)
	if _unlock_stamp != null:
		_slam_unlock_stamp()
	_count_coins(int(summary.get("coins_earned", 0)), int(summary.get("coins_total", Game.progress.get("coins", 0))))
	_accepting = true
	Events.awaiting_input.emit(&"results_continue", {"summary": summary}, _continue)
	await _continued
	_accepting = false
	Events.input_resolved.emit(&"results_continue")
	return _next


func _continue() -> void:
	if _done:
		return
	_done = true
	Sfx.play(&"click")
	_continued.emit()


func _again() -> void:
	if _done:
		return
	_next = "again"
	_continue()


## (v3) Continue straight to the next day (only offered when it is open).
func _next_day() -> void:
	if _done or not _has_next_day():
		return
	_next = "next"
	_continue()


func _has_next_day() -> bool:
	var nid := String(_summary.get("next_chapter_id", ""))
	return nid != "" and not Game.chapter(nid).is_empty()   # every day is open (polish)


## (polish) What the paper calls the patient: the profile's short name ("Gus", not "Grandpa").
func _first_name() -> String:
	var short := String(_summary.get("patient_short", ""))
	if short != "":
		return short
	return String(_summary.get("patient_name", "Gus")).split(" ")[0]


## (polish) This visit finished the day for the first time and the next day is still new: an
## "UP NEXT!" stamp, and Next is the big button ([Space]).
func _next_is_primary() -> bool:
	if not _has_next_day():
		return false
	var nid := String(_summary.get("next_chapter_id", ""))
	var first := bool(_summary.get("first_clear", (_summary.get("newly_unlocked", []) as Array).has(nid)))
	return first and not Game.is_chapter_done(nid)


## "Day 2" from "Day 2: Bonnie Bunsworth".
func _next_short_title() -> String:
	var nch := Game.chapter(String(_summary.get("next_chapter_id", "")))
	return String(nch.get("title", "Next day")).get_slice(":", 0).strip_edges()


func _slam_unlock_stamp() -> void:
	_unlock_stamp.visible = true
	_unlock_stamp.pivot_offset = _unlock_stamp.size * 0.5
	_unlock_stamp.scale = Vector2(2.4, 2.4)
	_unlock_stamp.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_unlock_stamp, "scale", Vector2.ONE, 0.22).set_delay(0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(_unlock_stamp, "modulate:a", 1.0, 0.12).set_delay(0.35)
	t.chain().tween_callback(func() -> void:
		Sfx.play(&"stamp", 1.15)
		Events.screen_shake.emit(0.15, 0.12))


## (v3) The classified ad's item: the one offered on this day (Game.SHOP_ITEMS).
func _shop_id() -> String:
	var day := int(_summary.get("day", 1))
	for id: String in Game.SHOP_ITEMS:
		if int(Game.SHOP_ITEMS[id]["day"]) == day:
			return id
	return CHAIR_ID


func _shop_cost() -> int:
	return int((Game.SHOP_ITEMS.get(_shop_id(), {"cost": CHAIR_COST}) as Dictionary)["cost"])


func _try_buy() -> void:
	if Game.has_upgrade(_shop_id()):
		return
	if Game.buy_upgrade(_shop_id(), _shop_cost()):
		Sfx.play(&"kaching")
		_buy.text = "Owned!"
		_buy.disabled = true
		_shop_note.text = "Delivered to the booth. %s approves." % _first_name()
		_total_label.text = "Wallet: %d Decibucks" % int(Game.progress.get("coins", 0))
		Juice.pop(_buy, 1.3, 0.3)
	else:
		Sfx.play(&"error")
		_shop_note.text = "Not enough Decibucks yet. Keep beeping!"
		Juice.shake(_buy, 6.0, 0.25)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey and (event as InputEventKey).keycode == KEY_B:
		_try_buy()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_A:
		_again()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_N and _has_next_day():
		_next_day()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_T and _next_is_primary():
		_continue()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"advance_dialogue") or event.is_action_pressed(&"ui_accept"):
		if _next_is_primary():
			_next_day()
		else:
			_continue()
		get_viewport().set_input_as_handled()


func _count_coins(n: int, total: int) -> void:
	var steps := 12
	var start := total - n
	for i in steps + 1:
		var v := int(round(float(n) * i / steps))
		_coins_label.text = "+%d Decibucks" % v
		_total_label.text = "Wallet: %d Decibucks" % (start + v)
		if i % 2 == 0:
			Sfx.play(&"click", 1.4 + i * 0.03, -8.0)
		await get_tree().create_timer(0.035).timeout
	_coins_label.text = "+%d Decibucks" % n
	_total_label.text = "Wallet: %d Decibucks" % total
	Juice.pop(_coins_label, 1.25, 0.3)
	Sfx.play(&"kaching")


# ---------------------------------------------------------------- layout

func _rule(parent: Control, h: int = 3) -> void:
	var r := ColorRect.new()
	r.color = Palette.INK
	r.custom_minimum_size.y = h
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


func _build(s: Dictionary) -> void:
	var root := UiKit.full_rect(Control.MOUSE_FILTER_STOP)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(1060, 0)
	var sb := UiKit.style(NEWSPRINT, Palette.INK, 6, 3, 18, 26)
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_paper.add_theme_stylebox_override("panel", sb)
	center.add_child(_paper)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_paper.add_child(v)

	var top := HBoxContainer.new()
	v.add_child(top)
	var l1 := UiKit.label("Vol. %d  -  Booth Camp Edition" % maxi(1, int(s.get("day", 1))), 14, Palette.INK_SOFT, 600)
	l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(l1)
	var aud0: Dictionary = s.get("audiometry", {})
	top.add_child(UiKit.label("Weather: scattered spondees, clearing later" if _is_speech(aud0) else "Weather: 100% chance of beeps", 14, Palette.INK_SOFT, 600))
	var mast := UiKit.label("THE DAILY DECIBEL", 58, Palette.INK, 700)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(mast)
	if _next_is_primary():
		_unlock_stamp = _make_unlock_stamp(mast)
	_rule(v, 4)
	var grade := String(s.get("grade", "?"))
	var cid := String(s.get("chapter_id", "gus"))
	# (cases) a summary may carry its own "headlines" / "subheads" / "medal_beats" (the case runner's)
	var heads: Dictionary = s.get("headlines", CHAPTER_HEADLINES.get(cid, HEADLINES))
	var head := UiKit.label(heads.get(grade, heads.get("B", HEADLINES["B"])), 30, Palette.INK, 700)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)
	var subs: Dictionary = s.get("subheads", CHAPTER_SUBHEADS.get(cid, SUBHEADS))
	var sub := UiKit.label(subs.get(grade, ""), 18, Palette.INK_SOFT, 500)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	_rule(v, 2)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	# --- column 1: grade stamp + bars + medals
	var c1 := VBoxContainer.new()
	c1.custom_minimum_size = Vector2(430, 0)
	c1.add_theme_constant_override("separation", 6)
	cols.add_child(c1)
	var gr := HBoxContainer.new()
	gr.add_theme_constant_override("separation", 16)
	c1.add_child(gr)
	var stamp := Control.new()
	stamp.custom_minimum_size = Vector2(150, 150)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gcol := Palette.grade_color(grade)
	stamp.draw.connect(func() -> void:
		var cc := Vector2(75, 75)
		stamp.draw_circle(cc, 70, Palette.INK)
		stamp.draw_circle(cc, 64, gcol)
		stamp.draw_arc(cc, 56, 0, TAU, 40, Color(1, 1, 1, 0.6), 3.0, true)
		var f := UiKit.font(700)
		var fs := 84 if grade.length() <= 1 else 34
		var w := f.get_string_size(grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		stamp.draw_string_outline(f, cc + Vector2(-w * 0.5, fs * 0.36), grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Palette.INK)
		stamp.draw_string(f, cc + Vector2(-w * 0.5, fs * 0.36), grade, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE))
	gr.add_child(stamp)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 4)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gr.add_child(bars)
	bars.add_child(UiKit.label("Score  %d / 100" % int(round(float(s.get("score", 0.0)))), 24, Palette.INK, 700))
	for pair: Array in [["Accuracy", "accuracy", Palette.MINT], ["Technique", "technique", Palette.SKY.darkened(0.25)], ["Efficiency", "efficiency", Palette.SUNNY], ["Care", "care", Palette.CORAL]]:
		bars.add_child(_bar(pair[0], float(s.get(pair[1], 0.0)), pair[2]))
	c1.add_child(UiKit.label("MICRO-GAME MEDALS", 14, Palette.INK_SOFT, 700))
	var medals := HBoxContainer.new()
	medals.add_theme_constant_override("separation", 10)
	c1.add_child(medals)
	var md: Dictionary = s.get("medals", {})
	for pair: Array in s.get("medal_beats", CHAPTER_MEDAL_BEATS.get(String(s.get("chapter_id", "")), MEDAL_BEATS)):
		medals.add_child(_medal(String(pair[1]), String(md.get(pair[0], ""))))

	var vr := ColorRect.new()
	vr.color = Color(Palette.INK, 0.5)
	vr.custom_minimum_size.x = 2
	cols.add_child(vr)
	# --- column 2: golf card (Speech: the word golf card on a speech day)
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.add_theme_constant_override("separation", 4)
	cols.add_child(c2)
	var aud: Dictionary = s.get("audiometry", {})
	if _is_speech(aud):
		_speech_column(c2, aud["speech"] as Dictionary)
	else:
		c2.add_child(UiKit.label("SPORTS: THE BEEP GOLF CARD", 16, Palette.INK, 700))
		c2.add_child(UiKit.label(_par_caption(aud), 14, Palette.INK_SOFT, 500))
		c2.add_child(_golf_card(aud))
		var retest := _retest_line(aud)
		if retest != "":
			var rl := UiKit.label(retest, 14, Palette.INK, 600)
			rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			c2.add_child(rl)
		var hoot_beeps := int(aud.get("hoot_presentations", 0))
		var facts := UiKit.label("Your beeps: %d%s   -   False alarms: %d   -   Best combo: %d" % [int(aud.get("presentations", 0)), ("  (Hoot: %d)" % hoot_beeps) if hoot_beeps > 0 else "", int(aud.get("false_alarms", 0)), int(aud.get("max_combo", 0))], 15, Palette.INK_SOFT, 500)
		c2.add_child(facts)
	var wanted := PanelContainer.new()
	wanted.add_theme_stylebox_override("panel", UiKit.style(Color("#fffaf0"), Palette.INK, 6, 2, 0, 8))
	var wl := UiKit.label("WANTED: people who like puzzles AND people. Hearing care professionals do this every day. Ask at this booth!", 14, Palette.INK, 600)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wl.custom_minimum_size = Vector2(500, 0)
	wanted.add_child(wl)
	c2.add_child(wanted)
	_rule(v, 2)

	# --- bottom: coins + shop + continue
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	v.add_child(bottom)
	var coins_box := VBoxContainer.new()
	coins_box.add_theme_constant_override("separation", 0)
	coins_box.custom_minimum_size = Vector2(300, 0)
	coins_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(coins_box)
	_coins_label = UiKit.label("+0 Decibucks", 28, Palette.SELECT_ORANGE.darkened(0.2), 700)
	coins_box.add_child(_coins_label)
	_total_label = UiKit.label("Wallet: %d Decibucks" % (int(s.get("coins_total", 0)) - int(s.get("coins_earned", 0))), 15, Palette.INK_SOFT, 600)
	coins_box.add_child(_total_label)
	var shop := PanelContainer.new()
	shop.add_theme_stylebox_override("panel", UiKit.style(Color("#fffaf0"), Palette.INK, 10, 2, 0, 10))
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(shop)
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	shop.add_child(sh)
	var chair := Control.new()
	chair.custom_minimum_size = Vector2(48, 48)
	chair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_chair := _shop_id() == CHAIR_ID
	chair.draw.connect(func() -> void:
		if not is_chair:
			# (v3) insert earphones: two foam tips on a thin tube
			chair.draw_arc(Vector2(24, 22), 16.0, PI * 0.15, PI * 0.85, 12, Palette.INK, 3.0, true)
			for p: Vector2 in [Vector2(10, 32), Vector2(38, 32)]:
				UiDraw.rounded_rect(chair, Rect2(p - Vector2(7, 11), Vector2(14, 22)), Color("#ffc46b"), 7, 2, Palette.INK)
				chair.draw_line(p + Vector2(-5, -3), p + Vector2(5, -3), Color(Palette.INK, 0.35), 2.0)
				chair.draw_line(p + Vector2(-5, 3), p + Vector2(5, 3), Color(Palette.INK, 0.35), 2.0)
			chair.draw_circle(Vector2(10, 21), 3.0, Palette.RIGHT_RED)
			chair.draw_circle(Vector2(38, 21), 3.0, Palette.LEFT_BLUE)
			return
		UiDraw.rounded_rect(chair, Rect2(8, 4, 32, 26), Color("#8e5cc4"), 8, 2, Palette.INK)
		UiDraw.rounded_rect(chair, Rect2(4, 24, 40, 14), Color("#a77bd6"), 6, 2, Palette.INK)
		chair.draw_line(Vector2(10, 38), Vector2(10, 46), Palette.INK, 3.0)
		chair.draw_line(Vector2(38, 38), Vector2(38, 46), Palette.INK, 3.0))
	sh.add_child(chair)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 0)
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sh.add_child(sv)
	var item: Dictionary = Game.SHOP_ITEMS.get(_shop_id(), {})
	var item_title := String(item.get("title", "Comfy booth chair"))
	sv.add_child(UiKit.label("CLASSIFIEDS: %s, %d Decibucks" % [item_title, _shop_cost()], 16, Palette.INK, 700))
	_shop_note = UiKit.label("Comfier patients stay alert and guess less." if _shop_id() == CHAIR_ID else String(item.get("blurb", "")), 14, Palette.INK_SOFT, 500)
	sv.add_child(_shop_note)
	var owned := Game.has_upgrade(_shop_id())
	_buy = UiKit.button("Owned!" if owned else ("Buy  [B]" if UiKit.show_key_hints() else "Buy"), &"", Vector2(120, 46))
	_buy.disabled = owned
	_buy.pressed.connect(_try_buy)
	_buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_buy)
	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(btns)
	var hints := UiKit.show_key_hints()
	var primary_next := _next_is_primary()
	if primary_next:
		# (polish) the visit just opened the next day: that is the big button, on [Space]
		var ntxt := "Next: %s" % _next_short_title()
		var nb := UiKit.button(ntxt + ("  [%s]" % Game.key_label(&"advance_dialogue")) if hints else ntxt, &"AccentButton", Vector2(250, 50))
		nb.tooltip_text = String(Game.chapter(String(s.get("next_chapter_id", ""))).get("title", ""))
		nb.pressed.connect(_next_day)
		btns.add_child(nb)
	var ctxt := "Back to the title"
	var cont := UiKit.button(ctxt + ("  [T]" if primary_next else "  [%s]" % Game.key_label(&"advance_dialogue")) if hints else ctxt, &"" if primary_next else &"AccentButton", Vector2(250, 40 if primary_next else 50))
	cont.pressed.connect(_continue)
	btns.add_child(cont)
	var again_txt := "Play %s again" % _first_name()
	var again := UiKit.button(again_txt + "  [A]" if hints else again_txt, &"", Vector2(250, 40))
	again.pressed.connect(_again)
	btns.add_child(again)
	if _has_next_day() and not primary_next:
		var ntxt := "Next: %s" % _next_short_title()
		var nb := UiKit.button(ntxt + "  [N]" if hints else ntxt, &"", Vector2(250, 40))
		nb.tooltip_text = String(Game.chapter(String(s.get("next_chapter_id", ""))).get("title", ""))
		nb.pressed.connect(_next_day)
		btns.add_child(nb)


## (polish) A tilted rubber stamp on the masthead's right: UP NEXT! / Day 2: Bonnie.
## A child of the label (not a container), so it rides along with the paper's tilt.
func _make_unlock_stamp(mast: Label) -> Control:
	var st := Control.new()
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	st.size = Vector2(230, 70)
	st.rotation = -0.1
	st.visible = false
	# "Day 2: Bonnie": the day and the next patient's short name
	var nch := Game.chapter(String(_summary.get("next_chapter_id", "")))
	var sub := String(nch.get("title", "")).get_slice(":", 0).strip_edges()
	var pid := String(nch.get("patient_id", ""))
	var np: Resource = Game.load_patient(pid) if ResourceLoader.exists(Game.PATIENT_DIR + pid + ".tres") else null
	if np != null and np.has_method("short_name"):
		sub += ": " + String(np.call("short_name"))
	var ink := Palette.CORAL.darkened(0.15)
	st.draw.connect(func() -> void:
		var r := Rect2(Vector2(3, 3), st.size - Vector2(6, 6))
		st.draw_rect(r, Color(NEWSPRINT, 0.9))
		UiDraw.rounded_rect(st, r, Color(0, 0, 0, 0), 8, 4, ink)
		UiDraw.rounded_rect(st, r.grow(-6), Color(0, 0, 0, 0), 5, 2, Color(ink, 0.6))
		var f := UiKit.font(700)
		var t1 := "UP NEXT!"
		var w1 := f.get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 21).x
		st.draw_string(f, Vector2((st.size.x - w1) * 0.5, 33), t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, ink)
		var w2 := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		st.draw_string(f, Vector2((st.size.x - w2) * 0.5, 55), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, ink))
	mast.add_child(st)
	mast.resized.connect(func() -> void: st.position = Vector2(mast.size.x - st.size.x + 6, (mast.size.y - st.size.y) * 0.5 + 2))
	return st


func _bar(name: String, value: float, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var l := UiKit.label(name, 17, Palette.INK, 600)
	l.custom_minimum_size = Vector2(92, 0)
	h.add_child(l)
	var bar := Control.new()
	bar.custom_minimum_size = Vector2(130, 18)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k := clampf(value, 0.0, 1.0)
	bar.draw.connect(func() -> void:
		UiDraw.rounded_rect(bar, Rect2(Vector2.ZERO, bar.size), Color(Palette.INK, 0.1), 9)
		if k > 0.0:
			UiDraw.rounded_rect(bar, Rect2(Vector2.ZERO, Vector2(maxf(18.0, bar.size.x * k), bar.size.y)), col, 9)
		UiDraw.rounded_rect(bar, Rect2(Vector2.ZERO, bar.size), Color(0, 0, 0, 0), 9, 2, Palette.INK))
	h.add_child(bar)
	h.add_child(UiKit.label("%d%%" % int(round(k * 100.0)), 17, Palette.INK, 700))
	return h


func _medal(beat_label: String, medal: String) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var c := Control.new()
	c.custom_minimum_size = Vector2(70, 46)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func() -> void:
		var cc := Vector2(35, 24)
		if medal == "":
			c.draw_arc(cc, 18, 0, TAU, 24, Color(Palette.INK, 0.3), 2.0, true)
			return
		c.draw_colored_polygon(PackedVector2Array([cc + Vector2(-10, -24), cc + Vector2(-2, -24), cc + Vector2(2, -6), cc + Vector2(-6, -6)]), Palette.RIGHT_RED)
		c.draw_colored_polygon(PackedVector2Array([cc + Vector2(10, -24), cc + Vector2(2, -24), cc + Vector2(-2, -6), cc + Vector2(6, -6)]), Palette.LEFT_BLUE)
		c.draw_circle(cc, 19, Palette.INK)
		c.draw_circle(cc, 16, MEDAL_COLORS.get(medal, Palette.SUNNY))
		UiDraw.star(c, cc, 9.0, Color(1, 1, 1, 0.7)))
	v.add_child(c)
	var l := UiKit.label(beat_label, 14, Palette.INK, 600)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var m := UiKit.label(medal.capitalize() if medal != "" else "-", 12, Palette.INK_SOFT, 500)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(m)
	return v


## "1k retest: right 25 vs 30" with the clinic-grade note (real tests wobble about 5 dB).
func _retest_line(res: Dictionary) -> String:
	var parts: Array[String] = []
	var ok := true
	for e: String in ["right", "left"]:
		var rt: Dictionary = ((res.get("ears", {}) as Dictionary).get(e, {}) as Dictionary).get("retest_1k", {})
		if rt.is_empty():
			continue
		parts.append("%s %d then %d" % [e.capitalize(), int(rt.get("first_db", 0)), int(rt.get("stored_db", 0))])
		ok = ok and int(rt.get("diff", 99)) <= ClinicRules.RETEST_TOLERANCE_DB
	if parts.is_empty():
		return ""
	var tail := "Within 5 dB = clinic-grade: real tests wobble that much." if ok else "More than 5 dB apart: a real clinician would re-instruct and recheck."
	return "1k retest: %s dB.  %s" % [", ".join(parts), tail]


## "Beeps per threshold vs par (8-11)": par is set per hole by core (a textbook search from that start level).
func _par_caption(res: Dictionary) -> String:
	var lo := 999
	var hi := -1
	for e: String in ["right", "left"]:
		var fl: Dictionary = ((res.get("ears", {}) as Dictionary).get(e, {}) as Dictionary).get("freqs", {})
		for f: Variant in fl:
			if bool((fl[f] as Dictionary).get("by_hoot", false)):
				continue
			var p := int((fl[f] as Dictionary).get("par", ClinicRules.PAR_PER_MEASUREMENT))
			lo = mini(lo, p)
			hi = maxi(hi, p)
	if hi < 0:
		lo = ClinicRules.PAR_PER_MEASUREMENT
		hi = lo
	var par_txt := str(lo) if lo == hi else "%d-%d" % [lo, hi]
	return "Beeps per threshold vs par (%s per hole). Fewer = better; brown = Hoot's." % par_txt


## A golf row's tag: the ear letter and the row's real audiogram symbol (O X, [ masked bone,
## triangle masked air), drawn, so it matches the chart.
func _row_tag(ear: String, sheet: StringName) -> Control:
	var test: StringName = &"ac" if sheet == &"freqs" else sheet
	var c := Control.new()
	c.custom_minimum_size = Vector2(40, 40)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.tooltip_text = {&"ac": "air", &"bc_masked": "masked bone", &"ac_masked": "masked air"}.get(test, "")
	c.draw.connect(func() -> void:
		var col := Palette.ear_color(ear)
		var f := UiKit.font(700)
		c.draw_string(f, Vector2(0, 26), "R" if ear == "right" else "L", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
		UiDraw.audiogram_symbol(c, Vector2(26, 20), ear, test, 13.0, 2.5))
	return c


func _golf_card(res: Dictionary) -> Control:
	var grid := GridContainer.new()
	var freqs: Array[int] = []
	var ears: Dictionary = res.get("ears", {})
	for f: int in ClinicRules.AC_FREQS:
		for e: String in ["right", "left"]:
			if ((ears.get(e, {}) as Dictionary).get("freqs", {}) as Dictionary).has(f) and not freqs.has(f):
				freqs.append(f)
	grid.columns = freqs.size() + 1
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(UiKit.label("Hz", 13, Palette.INK_SOFT, 700))
	for f in freqs:
		var l := UiKit.label(("%dk" % (f / 1000)) if f >= 1000 and f % 1000 == 0 else (("%.1fk" % (f / 1000.0)) if f >= 1000 else str(f)), 13, Palette.INK_SOFT, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(44, 0)
		grid.add_child(l)
	var rows: Array[Array] = [["freqs", "R  O", "right"], ["freqs", "L  X", "left"]]
	for extra: Array in GOLF_EXTRA_ROWS:
		if not ((ears.get(String(extra[2]), {}) as Dictionary).get(String(extra[0]), {}) as Dictionary).is_empty():
			rows.append(extra)
	for row: Array in rows:
		var e := String(row[2])
		var fl: Dictionary = (ears.get(e, {}) as Dictionary).get(String(row[0]), {})
		grid.add_child(_row_tag(e, StringName(String(row[0]))))
		for f in freqs:
			var cell := PanelContainer.new()
			cell.custom_minimum_size = Vector2(44, 40)
			var info: Dictionary = fl.get(f, {})
			var golf: StringName = StringName(String(info.get("golf", "")))
			var col: Color = GOLF_COLORS.get(golf, Color(Palette.INK, 0.25))
			cell.add_theme_stylebox_override("panel", UiKit.style(Color(col, 0.16) if not info.is_empty() else Color(0, 0, 0, 0.03), col, 6, 2, 0, 2))
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", -4)
			cell.add_child(cv)
			var n := UiKit.label(str(int(info.get("strokes", 0))) if not info.is_empty() else "-", 17, Palette.INK, 700)
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(n)
			var gname := String(golf).replace("_", " ")
			gname = gname.replace("double ", "2x ").replace("triple ", "3x ")
			var g := UiKit.label(gname, 10, col.darkened(0.15), 600)
			g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(g)
			grid.add_child(cell)
	return grid


# ---------------------------------------------------------------- (Speech) the word golf card

## A speech day: the results carry stored speech sheets (§9.5).
static func _is_speech(aud: Dictionary) -> bool:
	var sp: Variant = aud.get("speech", {})
	if not (sp is Dictionary):
		return false
	return not ((sp as Dictionary).get("srt", {}) as Dictionary).is_empty()


func _speech_column(c2: VBoxContainer, sp: Dictionary) -> void:
	c2.add_child(UiKit.label("SPORTS: THE WORD GOLF CARD", 16, Palette.INK, 700))
	c2.add_child(UiKit.label("SRT per ear vs the PTA from the beeps. Words vs par; brown = Hoot's.", 14, Palette.INK_SOFT, 500))
	c2.add_child(_speech_card(sp))
	var al := UiKit.label("Agreement: SRT within %d dB of the PTA is good, up to %d fair, more is poor: recheck and refer." % [int(SpeechRules.AGREE_GOOD_DB), int(SpeechRules.AGREE_FAIR_DB)], 14, Palette.INK, 600)
	al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c2.add_child(al)
	var half := 0
	var srt: Dictionary = sp.get("srt", {})
	for e: Variant in srt:
		half += int((srt[e] as Dictionary).get("half_words", 0))
	var hoot_words := int(sp.get("hoot_presentations", 0))
	var facts := UiKit.label("Your words: %d%s   -   Half-words: %d   -   Best combo: %d" % [int(sp.get("presentations", 0)), ("  (Hoot: %d)" % hoot_words) if hoot_words > 0 else "", half, int(sp.get("max_combo", 0))], 15, Palette.INK_SOFT, 500)
	c2.add_child(facts)


## One row per ear: stored SRT, PTA, agreement chip (with the gap), words vs par, golf.
func _speech_card(sp: Dictionary) -> Control:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	for h: String in ["", "SRT", "PTA", "Agreement", "Words", "Golf"]:
		var l := UiKit.label(h, 13, Palette.INK_SOFT, 700)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(l)
	var srt: Dictionary = sp.get("srt", {})
	for e: String in ["right", "left"]:
		if not srt.has(e):
			continue
		var sh: Dictionary = srt[e]
		var tag := UiKit.label("R" if e == "right" else "L", 17, Palette.ear_color(e), 700)
		tag.custom_minimum_size = Vector2(22, 0)
		grid.add_child(tag)
		var pta := float(sh.get("pta", NAN))
		var ag := StringName(String(sh.get("agreement", "")))
		var golf := StringName(String(sh.get("golf", "")))
		var strokes := int(sh.get("strokes", 0))
		var hoot_n := maxi(0, int(sh.get("words", strokes)) - strokes)
		grid.add_child(_speech_cell("%d dB" % int(sh.get("stored_db", 0)), "stored", Palette.ear_color(e)))
		grid.add_child(_speech_cell("-" if is_nan(pta) else "%d dB" % roundi(pta), "beeps", Color(Palette.INK, 0.45)))
		grid.add_child(_speech_cell(String(ag).to_upper() if ag != &"" else "-", "%d dB apart" % absi(int(sh.get("diff", 0))), AGREE_COLORS.get(ag, Color(Palette.INK, 0.3))))
		grid.add_child(_speech_cell("%d / %d" % [strokes, int(sh.get("par", 0))], ("+%d by Hoot" % hoot_n) if hoot_n > 0 else "words / par", Color(Palette.INK, 0.45)))
		grid.add_child(_speech_cell(String(golf).replace("_", " ").replace("double ", "2x ").replace("triple ", "3x ") if golf != &"" else "-", "", GOLF_COLORS.get(golf, Color(Palette.INK, 0.3))))
	return grid


func _speech_cell(main: String, small: String, col: Color) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(88, 44)
	cell.add_theme_stylebox_override("panel", UiKit.style(Color(col, 0.14), col, 6, 2, 0, 2))
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", -4)
	cv.alignment = BoxContainer.ALIGNMENT_CENTER
	cell.add_child(cv)
	var n := UiKit.label(main, 16, Palette.INK, 700)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(n)
	if small != "":
		var g := UiKit.label(small, 10, col.darkened(0.2), 600)
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cv.add_child(g)
	return cell
