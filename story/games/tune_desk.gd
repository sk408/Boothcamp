extends Control
## TuneDesk (Day 15, docs/TUNEUP.md §3): the tune-up desk. First the aid's datalog (hours worn a day,
## the last 14 days), then Gus's complaint tickets one at a time above a tray of seven tools: Left /
## Right picks a tool, Enter uses it; with the mouse, a click on a tool uses it. The level plays each
## result (a right tool stamps the ticket FIXED; a wrong tool is greyed for that ticket) from the
## static TICKETS table, which also feeds the paper and the tests.
## Story-internal:
##   var g := TuneDesk.new(); hud.add_game(g)
##   await g.show_datalog()                 # the 14-day chart slides in
##   g.show_ticket(i)                       # ticket i of TICKETS
##   var tool: String = await g.pick()      # beat tune_desk; returns the tool's id
##   g.mark_wrong(tool) / g.stamp_fixed()
##   var r: Dictionary = g.result()         # {tickets: [{id, fix, tries, wrong}], tools_used, par}
## The lines are Hoot lines or patient lines: 18 words or fewer.

signal _picked(tool: String)

const UiKit := preload("res://story/ui_kit.gd")

## The tray, in display order: [id, label]. Row 1 holds the first four, row 2 the rest.
const TOOLS: Array = [
	["soften_loud", "Soften loud highs"],
	["all_down", "Whole aid down"],
	["all_up", "Whole aid up"],
	["tighter_dome", "Tighter dome"],
	["feedback_test", "Feedback test"],
	["noise_program", "Noisy-places program"],
	["talk", "Talk it through"],
]
## The tool that is too loud for Gus wherever it is used (the first use costs a comfort point).
const HARM_TOOL := "all_up"
## Gus's complaint tickets, in play order. right: the tool that fixes it. lines: the result of each
## tool, [speaker, text] in turn ("default" for any tool not listed). The right tool's lines say why.
const TICKETS: Array = [
	{
		"id": "sharp", "chip": "SHARP", "who": "Gus", "text": "Paper and teaspoons sound sharp",
		"right": "soften_loud",
		"lines": {
			"soften_loud": [["Hoot", "A small cut for LOUD high sounds only. Soft voices keep their boost."],
				["Gus", "The paper rustles. It just... rustles. Lovely."],
				["Hoot", "The rest settles as his brain gets used to sound again."]],
			"all_down": [["Doris", "Your _ea'_ ready, dear!"],
				["Gus", "Doris, why are you mumbling again?"],
				["Hoot", "Down for everything loses soft speech too. Only the loud highs are the trouble."]],
			"all_up": [["Gus", "AAH! The teaspoon! It's a GONG!"],
				["Hoot", "Louder makes sharp sounds sharper. Never up for this one."]],
			"tighter_dome": [["Gus", "Now my voice is in a barrel, and the spoon still clangs!"],
				["Hoot", "A sealed dome blocks his good lows. Sharp highs need softening, not a plug."]],
			"feedback_test": [["Hoot", "The feedback test hunts whistles. This ticket is about sharp loud sounds."]],
			"noise_program": [["Hoot", "That's for crowds. A teaspoon in a quiet kitchen needs the loud highs softened."]],
			"talk": [["Hoot", "We'll talk too. But he's pulling them out over it. A small tweak keeps them in."]],
		},
	},
	{
		"id": "whistle", "chip": "WHISTLE", "who": "Doris", "text": "Whistles at hugs and under his cap",
		"right": "feedback_test",
		"lines": {
			"feedback_test": [["Hoot", "The aid plays a test sound, learns its own whistle path, then cancels it."],
				["Doris", "Come here, you."],
				["Gus", "Silence! Romantic silence."]],
			"tighter_dome": [["Gus", "No whistle! But why do I sound like I'm talking in a barrel?"],
				["Hoot", "Sealing stops whistles but traps his voice: occlusion. Try the feedback test first."]],
			"all_down": [["Hoot", "Quieter whistle, quieter Doris. The feedback test fixes the whistle itself."]],
			"soften_loud": [["Hoot", "A whistle isn't a loud sound coming in. It's the aid hearing itself."]],
			"all_up": [["Gus", "WHEEEEE! Doris, I'm a kettle!"],
				["Hoot", "More boost, more whistle. That's feedback!"]],
			"noise_program": [["Hoot", "A crowd program won't stop a whistle at hug time."]],
			"talk": [["Hoot", "No talk stops a whistle. The aid needs its feedback test."]],
		},
	},
	{
		"id": "bingo", "chip": "BINGO", "who": "Gus", "text": "Bingo numbers lost in the crowd",
		"right": "noise_program",
		"lines": {
			"noise_program": [["Hoot", "A noisy-places program: the mics focus forward on Bev and calm the chatter behind."],
				["Hoot", "Sit facing Bev, back to the crowd. It won't erase the noise, but it helps."],
				["Gus", "Front row, facing Bev. My lucky seat."]],
			"all_up": [["Gus", "Now the CROWD is louder too! And my ear is singing!"],
				["Hoot", "Turning up boosts the noise too. He needs Bev louder than the crowd."]],
			"all_down": [["Hoot", "Quieter crowd, quieter Bev. Down for everything won't pick her out."]],
			"soften_loud": [["Hoot", "The crowd isn't sharp, it's busy. Softening loud highs won't pick Bev out."]],
			"feedback_test": [["Hoot", "No whistle on this ticket. It's a crowd problem."]],
			"tighter_dome": [["Gus", "Barrel voice at bingo? Bev will think I'm calling from a well."],
				["Hoot", "Plugging his ear won't pick Bev out of the crowd."]],
			"talk": [["Hoot", "Good tips, and we'll give them. But a crowd program can tip the balance too."]],
		},
	},
	{
		"id": "hours", "chip": "HOURS", "who": "Aid diary", "text": "Worn 3.5 hours a day",
		"right": "talk",
		"lines": {
			"talk": [["Hoot", "Gus, the spoons are fixed. So: all day, every day. Your brain needs the practice."],
				["Gus", "All day. Even at bingo. ESPECIALLY at bingo."]],
			"all_up": [["Gus", "Ow! Now I'll wear them even less!"],
				["Hoot", "No knob fixes wear time. Some tickets need a talk, not a tweak."]],
			"default": [["Hoot", "No knob fixes wear time. Some tickets need a talk, not a tweak."]],
		},
	},
]
## Accuracy per ticket by tries: the first tool, the second, more.
const TRY_SCORES: Array[float] = [1.0, 0.5, 0.2]
## The datalog: hours worn on each of the last 14 days (oldest first); the two zeros are bingo nights.
const DATALOG_HOURS: Array[float] = [4.5, 4.0, 5.0, 3.5, 4.0, 0.0, 4.5, 4.0, 3.5, 5.0, 4.5, 4.0, 0.0, 2.5]
const DATALOG_BINGO: Array[int] = [5, 12]
## The goal line on the chart: all waking hours (drawn at this many hours).
const DATALOG_GOAL_H := 12.0
const DATALOG_MAX_H := 14.0
const START_TIP := "Pick the tool that fixes this ticket. Not every ticket needs a knob."

## Left of the fitting shot, like the target match, so Gus stays in view.
const PANEL := Rect2(14, 86, 620, 454)
const CARD := Rect2(22, 104, 576, 198)
const CHART := Rect2(70, 150, 500, 120)
const ROW1_Y := 318.0
const ROW2_Y := 372.0
const TOOL_H := 46.0
const GREEN := Color("#5bc8a3")

var _mode := ""
var _ticket := -1
var _tries: Array[int] = []
var _wrong: Array = []
var _fixed: Array[bool] = []
var _tools_used := 0
var _sel := 0
var _accepting := false
var _greyed: Array[String] = []
var _stamp_t := -1.0
var _slide := 1.0
var _shake := 0.0
var _t := 0.0
var _panel: Control
var _art: Control
var _buttons: Array[Button] = []
var _hints: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = Control.new()
	_panel.position = PANEL.position
	_panel.size = PANEL.size
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	_art = UiKit.full_rect()
	_art.draw.connect(_draw_panel)
	_panel.add_child(_art)
	for i in TOOLS.size():
		var r := tool_rect(i)
		var b := UiKit.button(String(TOOLS[i][1]), &"", r.size)
		b.position = r.position
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(_use.bind(i))
		b.mouse_entered.connect(func() -> void:
			if _accepting and not b.disabled:
				_sel = i
				_art.queue_redraw())
		_panel.add_child(b)
		_buttons.append(b)
	for k in TICKETS.size():
		_tries.append(0)
		_wrong.append([])
		_fixed.append(false)
	_set_tools_enabled(false)
	visible = false


## Where tool i sits in the panel: four on the first row, three wider ones on the second.
static func tool_rect(i: int) -> Rect2:
	if i < 4:
		return Rect2(22.0 + 146.0 * float(i), ROW1_Y, 138.0, TOOL_H)
	return Rect2(22.0 + 195.0 * float(i - 4), ROW2_Y, 187.0, TOOL_H)


## (coroutine) The panel slides in on the datalog chart.
func show_datalog() -> void:
	_mode = "log"
	visible = true
	Juice.bounce_in(_panel, 0.45)
	_art.queue_redraw()
	await get_tree().create_timer(0.5, false).timeout


## Shows ticket i (of TICKETS): every tool usable again.
func show_ticket(i: int) -> void:
	_mode = "ticket"
	_ticket = i
	_greyed.clear()
	_stamp_t = -1.0
	_slide = 0.0
	visible = true
	Sfx.play(&"whoosh", 1.1, -14.0)
	_art.queue_redraw()


## (coroutine) Waits for the player's tool on the current ticket (beat tune_desk) and returns its id.
func pick() -> String:
	_accepting = true
	_set_tools_enabled(true)
	if _greyed.has(String(TOOLS[_sel][0])):
		_sel = _first_usable()
	if _tries[_ticket] == 0 and _ticket == 0:
		Hoot.say(START_TIP, Hoot.NORMAL, "", "tune_start")
	if UiKit.show_key_hints() and _hints == null:
		_hints = UiKit.hint_panel(["Tool", ["Left"], ["Right"], " Use", ["Enter"]], 15)
		_hints.position = Vector2(PANEL.position.x + 16, PANEL.end.y - 46)
		add_child(_hints)
	Events.awaiting_input.emit(&"tune_desk", {"ticket": String(TICKETS[_ticket]["id"])}, solve)
	var tool: String = await _picked
	return tool


## The bot's solver: the right tool for this ticket.
func solve() -> void:
	if not _accepting:
		return
	var right := right_tool()
	while String(TOOLS[_sel][0]) != right:
		_move(1)
	_use(_sel)


## The current ticket's right tool (bot, mouse).
func right_tool() -> String:
	return String(TICKETS[_ticket]["right"]) if _ticket >= 0 else ""


func tool_button(tool: String) -> Button:
	return _buttons[tool_index(tool)]


static func tool_index(tool: String) -> int:
	for i in TOOLS.size():
		if String(TOOLS[i][0]) == tool:
			return i
	return -1


## Greys a wrong tool for the rest of this ticket.
func mark_wrong(tool: String) -> void:
	_greyed.append(tool)
	_shake = 1.0
	_buttons[tool_index(tool)].disabled = true
	_art.queue_redraw()


## Stamps the current ticket FIXED and ticks its chip.
func stamp_fixed() -> void:
	_fixed[_ticket] = true
	_stamp_t = 0.0
	Sfx.play(&"stamp", 1.0, -8.0)
	Sfx.play(&"ding", 1.2, -10.0)
	_art.queue_redraw()


## {tickets: [{id, fix, tries, wrong}], tools_used, par}: par is one tool per ticket.
func result() -> Dictionary:
	var out: Array = []
	for k in TICKETS.size():
		out.append({"id": String(TICKETS[k]["id"]), "fix": String(TICKETS[k]["right"]), "tries": _tries[k],
			"wrong": (_wrong[k] as Array).duplicate(), "fixed": _fixed[k]})
	return {"tickets": out, "tools_used": _tools_used, "par": TICKETS.size()}


# ---------------------------------------------------------------- the rules (static, tested)

## The lines a tool plays on ticket i: its own, or the ticket's "default", or a generic miss.
static func lines_for(i: int, tool: String) -> Array:
	var lines: Dictionary = TICKETS[i]["lines"]
	if lines.has(tool):
		return lines[tool]
	if lines.has("default"):
		return lines["default"]
	return [["Hoot", "That tool fixes something else. Read the ticket again."]]


static func is_right(i: int, tool: String) -> bool:
	return String(TICKETS[i]["right"]) == tool


## Accuracy for one ticket fixed on this try (1 = the first tool).
static func ticket_score(tries: int) -> float:
	return TRY_SCORES[clampi(tries - 1, 0, TRY_SCORES.size() - 1)]


## The mean ticket score.
static func accuracy_of(tries: Array) -> float:
	if tries.is_empty():
		return 0.0
	var s := 0.0
	for n: Variant in tries:
		s += ticket_score(int(n))
	return s / float(tries.size())


## 1.0 at par, 0.12 less per extra tool, never below 0.3 (as the fitting's moves).
static func efficiency(tools_used: int, par: int) -> float:
	return clampf(1.0 - 0.12 * float(tools_used - par), 0.3, 1.0)


static func datalog_average() -> float:
	var s := 0.0
	for h: float in DATALOG_HOURS:
		s += h
	return s / float(DATALOG_HOURS.size())


# ---------------------------------------------------------------- input

func _set_tools_enabled(on: bool) -> void:
	for i in _buttons.size():
		_buttons[i].disabled = not on or _greyed.has(String(TOOLS[i][0]))


func _first_usable() -> int:
	for i in TOOLS.size():
		if not _greyed.has(String(TOOLS[i][0])):
			return i
	return 0


func _move(dir: int) -> void:
	for step in TOOLS.size():
		_sel = posmod(_sel + dir, TOOLS.size())
		if not _greyed.has(String(TOOLS[_sel][0])):
			break
	Sfx.play(&"click", 1.0, -12.0)
	_art.queue_redraw()


func _use(i: int) -> void:
	if not _accepting or _greyed.has(String(TOOLS[i][0])):
		return
	_accepting = false
	_set_tools_enabled(false)
	_sel = i
	var tool := String(TOOLS[i][0])
	_tries[_ticket] += 1
	_tools_used += 1
	if not is_right(_ticket, tool):
		(_wrong[_ticket] as Array).append(tool)
	Sfx.play(&"click", 0.8, -8.0)
	if _hints != null:
		_hints.queue_free()
		_hints = null
	Events.input_resolved.emit(&"tune_desk")
	_picked.emit(tool)


func _unhandled_input(event: InputEvent) -> void:
	if not _accepting or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed(&"ui_right") or event.is_action_pressed(&"ui_down"):
		_move(1)
	elif event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_up"):
		_move(-1)
	elif event.is_action_pressed(&"ui_accept"):
		_use(_sel)
	else:
		return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	_slide = minf(1.0, _slide + delta * 3.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	if _stamp_t >= 0.0:
		_stamp_t += delta
	if visible:
		_art.queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw_panel() -> void:
	var ci := _art
	var f := UiKit.font(700)
	var f5 := UiKit.font(500)
	UiDraw.rounded_rect(ci, Rect2(Vector2(0, 8), PANEL.size), Color(Palette.INK, 0.3), 22)
	UiDraw.rounded_rect(ci, Rect2(Vector2.ZERO, PANEL.size), Palette.PAPER, 22, 4, Palette.INK)
	ci.draw_string(f, Vector2(22, 36), "TUNE-UP DESK  ·  BOTH AIDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	_draw_chips(ci, f)
	if _mode == "log":
		_draw_datalog(ci, f, f5)
	elif _mode == "ticket":
		_draw_ticket(ci, f, f5)
	# the selected tool's outline, under its button
	if _accepting:
		var r := tool_rect(_sel).grow(4)
		UiDraw.rounded_rect(ci, r, Color(Palette.SUNNY, 0.0), 14, 4, Palette.SUNNY.darkened(0.15))


func _draw_chips(ci: CanvasItem, f: Font) -> void:
	if _mode != "ticket":
		return
	for k in TICKETS.size():
		var r := Rect2(22 + 92 * k, 52, 86, 26)
		var on := k == _ticket
		var bg: Color = GREEN if _fixed[k] else (Palette.SUNNY if on else Color(Palette.INK, 0.08))
		UiDraw.rounded_rect(ci, r, bg, 10, 2, Palette.INK if on else Color(Palette.INK, 0.35))
		var label := ("OK " if _fixed[k] else "%d " % (k + 1)) + String(TICKETS[k]["chip"])
		ci.draw_string(f, Vector2(r.position.x + 7, r.position.y + 18), label, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 10, 12, Palette.INK)


func _draw_datalog(ci: CanvasItem, f: Font, f5: Font) -> void:
	UiDraw.rounded_rect(ci, CARD, Color("#eef6ff"), 16, 3, Palette.INK)
	ci.draw_string(f, CARD.position + Vector2(16, 28), "AID DIARY: HOURS WORN A DAY, LAST 14 DAYS", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.INK)
	var base := CHART.end.y
	var hy := func(h: float) -> float: return base - CHART.size.y * h / DATALOG_MAX_H
	# the goal: all waking hours
	var gy: float = hy.call(DATALOG_GOAL_H)
	ci.draw_dashed_line(Vector2(CHART.position.x, gy), Vector2(CHART.end.x, gy), GREEN.darkened(0.2), 3.0, 10.0)
	ci.draw_string(f, Vector2(CHART.end.x - 140, gy - 6), "GOAL: ALL WAKING HOURS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GREEN.darkened(0.35))
	var n := DATALOG_HOURS.size()
	var w := CHART.size.x / float(n)
	for d in n:
		var h := DATALOG_HOURS[d]
		var x := CHART.position.x + w * float(d) + 4.0
		var top: float = hy.call(h)
		if h > 0.0:
			UiDraw.rounded_rect(ci, Rect2(x, top, w - 8.0, base - top), Palette.SKY, 4, 2, Palette.INK)
		if DATALOG_BINGO.has(d):
			ci.draw_string(f, Vector2(x - 6, base - 8), "BINGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.CORAL.darkened(0.2))
			ci.draw_string(f, Vector2(x + 6, base - 22), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.CORAL.darkened(0.2))
	ci.draw_line(Vector2(CHART.position.x, base), Vector2(CHART.end.x, base), Palette.INK, 3.0)
	var avg := "Average: %.1f hours a day" % datalog_average()
	ci.draw_string(f, Vector2(CARD.position.x + 16, CARD.end.y - 12), avg, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK)
	ci.draw_string(f5, Vector2(CARD.end.x - 170, CARD.end.y - 12), "two weeks since the fitting", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Palette.INK_SOFT)


func _draw_ticket(ci: CanvasItem, f: Font, f5: Font) -> void:
	var t: Dictionary = TICKETS[_ticket]
	var off := Vector2((1.0 - _back_ease(_slide)) * 300.0 + sin(_t * 40.0) * 6.0 * _shake, 0)
	var r := Rect2(CARD.position + off, CARD.size)
	UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(0, 6), r.size), Color(Palette.INK, 0.2), 16)
	UiDraw.rounded_rect(ci, r, Color("#fff7dc"), 16, 3, Palette.INK)
	ci.draw_string(f5, r.position + Vector2(18, 28), "TICKET %d OF %d  ·  FROM %s" % [_ticket + 1, TICKETS.size(), String(t["who"]).to_upper()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.INK_SOFT)
	_draw_icon(ci, String(t["id"]), r.position + Vector2(88, 116))
	var text := String(t["text"])
	var lines: PackedStringArray = _wrap(text, f, 26, r.size.x - 210)
	for k in lines.size():
		ci.draw_string(f, r.position + Vector2(184, 92 + 34 * k), lines[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Palette.INK)
	if _stamp_t >= 0.0:
		var k := clampf(_stamp_t / 0.25, 0.0, 1.0)
		var sc := lerpf(2.2, 1.0, k)
		var c := r.position + Vector2(r.size.x - 120, r.size.y - 50)
		ci.draw_set_transform(c, -0.18, Vector2.ONE * sc)
		var sw := f.get_string_size("FIXED", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
		UiDraw.rounded_rect(ci, Rect2(-sw * 0.5 - 14, -34, sw + 28, 48), Color(GREEN, 0.15 * k), 10, 5, Color(GREEN.darkened(0.3), k))
		ci.draw_string(f, Vector2(-sw * 0.5, 0), "FIXED", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(GREEN.darkened(0.3), k))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## An ease that overshoots a little and settles, for the ticket sliding in.
static func _back_ease(x: float) -> float:
	var u := clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u


## Greedy word wrap for the ticket's big text.
static func _wrap(text: String, f: Font, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word: String in text.split(" "):
		var next := word if line == "" else line + " " + word
		if f.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out


## Each ticket's little picture: a newspaper and a teaspoon, a heart and a cap, a bingo ball, a clock.
func _draw_icon(ci: CanvasItem, id: String, c: Vector2) -> void:
	var ink := Palette.INK
	match id:
		"sharp":
			var page := Rect2(c + Vector2(-52, -40), Vector2(70, 84))
			UiDraw.rounded_rect(ci, page, Palette.PAPER, 6, 3, ink)
			for k in 5:
				ci.draw_line(page.position + Vector2(10, 16 + 13 * k), page.position + Vector2(60, 16 + 13 * k), Color(ink, 0.5), 3.0)
			ci.draw_line(c + Vector2(26, 34), c + Vector2(48, -18), ink, 7.0, true)
			ci.draw_line(c + Vector2(26, 34), c + Vector2(48, -18), Color("#c3cad1"), 4.0, true)
			ci.draw_circle(c + Vector2(50, -26), 11.0, ink)
			ci.draw_circle(c + Vector2(50, -26), 8.0, Color("#c3cad1"))
			var zap := sin(_t * 9.0) * 3.0
			for k in 3:
				var a := -1.0 + 0.6 * float(k)
				ci.draw_line(c + Vector2(62, -30) + Vector2(cos(a), sin(a)) * 16.0, c + Vector2(62, -30) + Vector2(cos(a), sin(a)) * (26.0 + zap), Palette.CORAL, 3.0, true)
		"whistle":
			var pts := PackedVector2Array()
			for k in 24:
				var u := TAU * float(k) / 24.0
				pts.append(c + Vector2(16.0 * pow(sin(u), 3), -(13.0 * cos(u) - 5.0 * cos(2.0 * u) - 2.0 * cos(3.0 * u) - cos(4.0 * u))) * 2.4 + Vector2(-14, 0))
			ci.draw_colored_polygon(pts, Palette.CORAL)
			pts.append(pts[0])
			ci.draw_polyline(pts, ink, 3.0, true)
			for k in 3:
				var rr := 14.0 + 10.0 * float(k) + fmod(_t * 18.0, 10.0)
				ci.draw_arc(c + Vector2(40, -30), rr, -1.2, 0.2, 10, Color(ink, 0.6), 3.0, true)
		"bingo":
			ci.draw_circle(c, 46.0, ink)
			ci.draw_circle(c, 42.0, Palette.SUNNY)
			ci.draw_circle(c, 26.0, Palette.PAPER)
			var s := "22"
			var sw := f_bold().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			ci.draw_string(f_bold(), c + Vector2(-sw * 0.5, 11), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, ink)
		"hours":
			ci.draw_circle(c, 46.0, ink)
			ci.draw_circle(c, 42.0, Palette.PAPER)
			for k in 12:
				var a := TAU * float(k) / 12.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 34.0, c + Vector2(cos(a), sin(a)) * 40.0, ink, 3.0)
			ci.draw_line(c, c + Vector2(0, -28), ink, 5.0, true)
			ci.draw_line(c, c + Vector2(cos(-PI * 0.5 + 3.5 / 12.0 * TAU), sin(-PI * 0.5 + 3.5 / 12.0 * TAU)) * 20.0, ink, 6.0, true)
			ci.draw_circle(c, 5.0, ink)


static func f_bold() -> Font:
	return UiKit.font(700)
