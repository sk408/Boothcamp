extends Node
## LevelTuneup (Day 15, docs/TUNEUP.md): Gus's first follow-up, two weeks after his fitting. The
## calendar card, the opening question (an open one opens the stories), the aid's datalog, the tune-up
## desk (story/games/tune_desk.gd: one complaint ticket at a time, pick the tool that fixes it), bingo
## night at Bev's hall (story/games/bingo_night.gd) and the paper. Talks to other modules only by
## contract, like level_fitting.gd:
##   world:  res://world/clinic.tscn (Clinic API §6 and its extras, called by name)
##   global: Game (visit, scores), Events (phases, awaiting_input), Hoot (tips)
## Blocking beats: dialogue, choice, tune_desk, results_continue.
## Scores (TUNEUP.md §4): accuracy from the desk's tickets, technique from the opening question and
## staying safe (no WHOLE AID UP), efficiency from tools against par, care from comfort (the first
## WHOLE AID UP costs a point).

const Hud := preload("res://story/hud.gd")
const TuneDesk := preload("res://story/games/tune_desk.gd")
const BingoNight := preload("res://story/games/bingo_night.gd")
const CaseProps := preload("res://story/games/case_props.gd")

const CLINIC_SCENE := "res://world/clinic.tscn"
const RESULTS_SCENE := "res://story/daily_decibel.tscn"
const TITLE_SCENE := "res://story/title_screen.tscn"
const LEVEL_SCENE := "res://story/level_tuneup.tscn"
const PAPER_SCRIPT := "res://story/papers/paper_tuneup.gd"
const PATIENT_ID := "gus_tune"

const STEPS: Array[StringName] = [&"hello", &"ask", &"log", &"tune", &"bingo"]
const STEP_LABELS: Dictionary = {&"hello": "Hello", &"ask": "Ask", &"log": "Diary", &"tune": "Tune", &"bingo": "Bingo"}
const STEPS_TITLE := "Gus's tune-up"
const LATER_CARD := "TWO WEEKS LATER"
const ASK_PROMPT := "How should we start?"
## The opening questions in display order: [text, id, Gus's answer, Hoot's line]. Right: the open one.
const ASKS: Array = [
	["Are they perfect?", "perfect", "Perfect!",
		"A yes-or-no question gets a polite yes. Doris's list says otherwise."],
	["Where do you have trouble with them?", "where", "Where DON'T I?",
		"An open question opens the stories. Now we know what to tune."],
	["Have you been wearing them?", "wearing", "Oh, yes. Mostly.",
		"True, but it tells us little. The aid's own diary will answer that one."],
]
const RIGHT_ASK := "where"
## The three stories the open question brings, each a ticket on the notes board: [speaker, line, note].
const STORIES: Array = [
	["Gus", "The newspaper crackles like a bonfire. And teaspoons! Every cup of tea is a fire alarm.", "Ticket 1: paper and teaspoons sound sharp"],
	["Doris", "And he whistles, Hoot. Every hug, and every time he puts his cap on.", "Ticket 2: whistles at hugs and under his cap"],
	["Gus", "Bingo's no better. Bev calls a number and the whole hall talks over her.", "Ticket 3: bingo numbers lost in the crowd"],
]
const DATALOG_NOTE := "Ticket 4: worn 3.5 hours a day"
const PART_SCORES: Array[float] = [1.0, 0.5, 0.2]
const MEDALS: Array[String] = ["gold", "silver", "bronze"]
const MEDAL_BEATS: Array = [["ask", "Ask"], ["tune", "Tune"]]
const WEATHER := "Weather: noisy in the hall, clear in the kitchen"
const HEADLINES: Dictionary = {
	"S": "FOUR TICKETS, FOUR FIXES; GUS WINS BINGO, LOSES DISHES ARGUMENT",
	"A": "TEASPOONS TAMED, WHISTLE SILENCED, BINGO CALLED",
	"B": "GUS TUNED UP; A FEW KNOBS TURNED ON THE WAY",
	"C": "TUNE-UP DONE THE LONG WAY, REPORTS OWL",
	"Do-over": "GUS BACK FOR ANOTHER TUNE-UP; BRINGS HIS OWN TEASPOON",
}
const SUBHEADS: Dictionary = {
	"S": "Asked the open question, fixed each ticket with the right tool. Twenty-two!",
	"A": "Every complaint fixed, nothing turned up for the whole aid. Doris approves.",
	"B": "Every ticket fixed in the end. Tip: soften what's too loud, not everything.",
	"C": "Fixed, with detours. Ask where he has trouble, then match each fix to the ticket.",
	"Do-over": "Follow-ups take practice. Every ticket has one right tool.",
}

var patient: PatientProfile
var clinic: Node3D
var hud: CanvasLayer
var dialogue: DialogueBox
var ask_tries := 0
## WHOLE AID UP uses across the desk (the first one costs a comfort point).
var ups := 0
var _desk: Control
var _desk_result := {}


func _ready() -> void:
	Game.begin_visit(PATIENT_ID)
	patient = Game.load_patient(PATIENT_ID) as PatientProfile
	clinic = (load(CLINIC_SCENE) as PackedScene).instantiate()
	add_child(clinic)
	hud = Hud.new()
	add_child(hud)
	hud.call("set_steps", STEPS, STEP_LABELS, STEPS_TITLE)
	dialogue = DialogueBox.new()
	add_child(dialogue)
	Events.level_started.emit(PATIENT_ID)
	_run.call_deferred()


func _phase(p: StringName, info: Dictionary = {}) -> void:
	Events.phase_changed.emit(p, info)


func _say(who: String, text: String) -> void:
	await dialogue.say(who, text)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout


func _react(kind: StringName, data: Dictionary = {}) -> void:
	Events.patient_reaction.emit(kind, data)


## Extra story screenshots (only saved when the game runs with --shots).
func _shot(shot_name: String, delay: float = 0.0) -> void:
	if not Game.cli.has("shots"):
		return
	if delay > 0.0:
		await get_tree().create_timer(delay, false).timeout
	Events.screenshot_requested.emit("story_" + shot_name)


func _run() -> void:
	await _intro()
	await _ask()
	await _datalog()
	await _tune()
	await _bingo()
	await _results()


# ---------------------------------------------------------------- 1. two weeks later

func _intro() -> void:
	_phase(&"intro")
	hud.call("set_step", &"hello")
	clinic.call("focus_camera", &"door", 0.0)
	var props := CaseProps.new()
	hud.call("add_game", props)
	await props.play("later", LATER_CARD)
	props.queue_free()
	get_tree().create_timer(1.4, false).timeout.connect(func() -> void: clinic.call("focus_camera", &"desk", 2.2))
	await clinic.call("walk_in")
	clinic.call("put_on_hearing_aids")
	await _say("Gus", "The finches are back. So is every fridge, newspaper and teaspoon in town.")
	await clinic.call("doris_enter")
	clinic.call("gus_look", &"doris")
	await _say("Doris", "I brought a list, Hoot. A LONG list.")
	clinic.call("hoot_emote", &"wing_up")
	await _say("Hoot", "Welcome back! Follow-ups are where a fitting gets good. We tune to his real life.")
	clinic.call("gus_look", &"hoot")
	hud.call("complete_step", &"hello")


# ---------------------------------------------------------------- 2. the opening question

func _ask() -> void:
	_phase(&"history")
	hud.call("set_step", &"ask")
	var opts: Array[String] = []
	var ids: Array[String] = []
	for a: Array in ASKS:
		opts.append(String(a[0]))
		ids.append(String(a[1]))
	ask_tries = 0
	while true:
		if ask_tries == 0:
			_shot("tuneup_ask", 0.42)
		var c: int = await dialogue.choose(ASK_PROMPT, opts, ids.find(RIGHT_ASK))
		ask_tries += 1
		var a: Array = ASKS[_ask_index(ids[c])]
		if ids[c] == RIGHT_ASK:
			_react(&"startle")
			await _say("Gus", String(a[2]))
			clinic.call("hoot_emote", &"nod")
			await _say("Hoot", String(a[3]))
			break
		await _say("Gus", String(a[2]))
		if ids[c] == "perfect":
			clinic.call("doris_react", &"wince")
			await _say("Doris", "Ahem.")
		_react(&"confused")
		await _say("Hoot", String(a[3]))
		opts.remove_at(c)
		ids.remove_at(c)
	Game.record_medal("ask", MEDALS[mini(ask_tries, MEDALS.size()) - 1])
	Game.set_visit_flag("ask_tries", ask_tries)
	hud.call("clear_notes")
	hud.call("set_notes_visible", true)
	for s: Array in STORIES:
		if String(s[0]) == "Doris":
			clinic.call("gus_look", &"doris")
		await _say(String(s[0]), String(s[1]))
		hud.call("add_clue", String(s[2]))
	clinic.call("gus_look", &"hoot")
	hud.call("complete_step", &"ask")


static func _ask_index(id: String) -> int:
	for k in ASKS.size():
		if String(ASKS[k][1]) == id:
			return k
	return -1


# ---------------------------------------------------------------- 3. the datalog

func _datalog() -> void:
	_phase(&"datalog")
	hud.call("set_step", &"log")
	clinic.call("focus_camera", &"fitting", 0.8)
	await _say("Hoot", "First, the aids' diary. They log every hour they're worn.")
	_desk = TuneDesk.new()
	hud.call("add_game", _desk)
	await _desk.call("show_datalog")
	_shot("tuneup_datalog", 0.3)
	await _say("Hoot", "Three and a half hours a day. And zero on both bingo nights.")
	clinic.call("gus_look", &"camera")
	await _say("Gus", "The teaspoons, Hoot. I take them out for tea. And for bingo. And...")
	await _say("Hoot", "That's a ticket too. Aids work best worn all waking hours.")
	hud.call("add_clue", DATALOG_NOTE)
	hud.call("complete_step", &"log")


# ---------------------------------------------------------------- 4. the tune-up desk

func _tune() -> void:
	_phase(&"tune_desk")
	hud.call("set_step", &"tune")
	await _say("Hoot", "Four tickets. For each one, pick the tool that fixes it.")
	ups = 0
	for i in TuneDesk.TICKETS.size():
		_desk.call("show_ticket", i)
		if i == 0:
			_shot("tuneup_desk", 0.45)
		while true:
			var tool: String = await _desk.call("pick")
			if tool == TuneDesk.HARM_TOOL:
				ups += 1
				_react(&"startle")
				if ups == 1:
					Game.lose_comfort("tune_all_up")
			elif not TuneDesk.is_right(i, tool):
				_react(&"confused")
			for line: Array in TuneDesk.lines_for(i, tool):
				await _say(String(line[0]), String(line[1]))
			if TuneDesk.is_right(i, tool):
				_desk.call("stamp_fixed")
				_react(&"cheer")
				await _wait(0.7)
				break
			_desk.call("mark_wrong", tool)
	_desk_result = _desk.call("result")
	Game.record_medal("tune", tune_medal(_desk_result))
	Game.set_visit_flag("tools_used", int(_desk_result.get("tools_used", 0)))
	Game.set_audiometry_results(results_for(_desk_result, ask_tries, ups))
	await _say("Gus", "Four for four! Doris, cross them off.")
	await _say("Doris", "Crossed. In pen.")
	var t := _desk.create_tween()
	t.tween_property(_desk, "modulate:a", 0.0, 0.3)
	await t.finished
	_desk.queue_free()
	hud.call("complete_step", &"tune")


## The visit's results (TUNEUP.md §4): the usual three parts plus "tuneup" for the paper and the bot.
static func results_for(desk: Dictionary, asks: int, harm: int) -> Dictionary:
	var tries: Array = []
	for t: Dictionary in desk.get("tickets", []):
		tries.append(int(t.get("tries", 1)))
	var safe := 1.0 if harm <= 0 else (0.5 if harm == 1 else 0.0)
	var ask_part: float = PART_SCORES[clampi(asks - 1, 0, PART_SCORES.size() - 1)]
	var tune := desk.duplicate(true)
	tune["ask_tries"] = maxi(1, asks)
	tune["ups"] = harm
	return {
		"accuracy": TuneDesk.accuracy_of(tries),
		"technique": 0.5 * ask_part + 0.5 * safe,
		"efficiency": TuneDesk.efficiency(int(desk.get("tools_used", 0)), int(desk.get("par", TuneDesk.TICKETS.size()))),
		"tuneup": tune,
	}


## gold with no wrong tool, silver with one or two, bronze with more.
static func tune_medal(desk: Dictionary) -> String:
	var wrong := 0
	for t: Dictionary in desk.get("tickets", []):
		wrong += (t.get("wrong", []) as Array).size()
	return "gold" if wrong == 0 else ("silver" if wrong <= 2 else "bronze")


# ---------------------------------------------------------------- 5. bingo night

func _bingo() -> void:
	_phase(&"fitting")
	hud.call("set_step", &"bingo")
	hud.call("set_notes_visible", false)
	await _say("Hoot", "Saturday, Bev's hall. Program on, front row, facing Bev.")
	var b := BingoNight.new()
	hud.call("add_game", b)
	await b.open()
	b.set_program(true)
	await _say("Bev", "Eyes down, everyone! Gus, lovely to see you in the front row.")
	b.call_ball(22)
	_shot("tuneup_bingo", 0.6)
	await _say("Bev", "Two little ducks: twenty-two!")
	await b.bingo()
	await _say("Gus", "BINGO! I HEARD it! Over all of you lot!")
	await _say("Doris", "Lovely. And when we get home, it's your turn to wash up.")
	await _say("Gus", "Pardon? The program's still on. Can't hear anything behind me.")
	await _say("Doris", "I'm standing in FRONT of you, Gus.")
	await b.close()
	clinic.call("hoot_emote", &"cheer")
	clinic.call("focus_camera", &"fitting", 0.5)
	await _say("Hoot", "Ask where, read the diary, fix each ticket. That's a follow-up, trainee!")
	hud.call("complete_step", &"bingo")


# ---------------------------------------------------------------- 6. results

func _results() -> void:
	_phase(&"results")
	var summary := Game.finish_visit()
	summary["headlines"] = HEADLINES
	summary["subheads"] = SUBHEADS
	summary["medal_beats"] = MEDAL_BEATS
	summary["weather"] = WEATHER
	summary["sports_script"] = PAPER_SCRIPT
	Events.level_finished.emit(summary)
	var paper: Node = (load(RESULTS_SCENE) as PackedScene).instantiate()
	add_child(paper)
	var next: Variant = await paper.call("show_summary", summary)
	match String(next):
		"again":
			Events.goto_scene.emit(LEVEL_SCENE)
		"next":
			if not Game.start_chapter(String(summary.get("next_chapter_id", ""))):
				Events.goto_scene.emit(TITLE_SCENE)
		_:
			Events.goto_scene.emit(TITLE_SCENE)
