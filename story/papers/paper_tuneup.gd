extends RefCounted
## (Day 15) The Daily Decibel's sports column for the tune-up: THE TUNE-UP TICKETS (docs/TUNEUP.md §4).
## daily_decibel.gd loads this script from the summary's "sports_script" and calls
## build(c2, audiometry, summary). One row per ticket (Ticket . Fix . Tries . Result), then the tools
## against par, the opening question, the whole-aid-up count, a tip and Hoot's line. Every number
## comes from the visit's "tuneup" results.

const UiKit := preload("res://story/ui_kit.gd")
const PaperWordGolf := preload("res://story/papers/paper_word_golf.gd")
const PaperFitting := preload("res://story/papers/paper_fitting.gd")
const TuneDesk := preload("res://story/games/tune_desk.gd")

const HEADER := "SPORTS: THE TUNE-UP TICKETS"
const COLUMNS: Array[String] = ["Ticket", "Fix", "Tries", "Result"]
const CELL_W: Array[int] = [170, 180, 60, 100]
const CELL_H := 24
const TICKET_NAMES: Dictionary = {"sharp": "Sharp teaspoons", "whistle": "Whistle at hugs", "bingo": "Bingo crowd", "hours": "3.5 hours a day"}
const PICKS: Array[String] = ["first pick", "second pick", "third pick"]
const TIP := "Real follow-ups: ask where it's hard, read the datalog, then fix one complaint at a time."
const HOOT_SAYS := "HOOT SAYS: A fitting starts at the target. It gets good at the follow-ups."


func build(c2: VBoxContainer, aud: Dictionary, _s: Dictionary) -> void:
	var tune: Dictionary = aud.get("tuneup", {})
	c2.add_child(UiKit.label(HEADER, 16, Palette.INK, 700))
	c2.add_child(_table(tune))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	c2.add_child(box)
	for line: String in lines(tune):
		var l := UiKit.label(line, 14, Palette.INK, 700 if line.begins_with("HOOT SAYS") else 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(500, 0)
		box.add_child(l)


## One row per ticket: [ticket, fix, tries, result].
static func rows(tune: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for t: Dictionary in tune.get("tickets", []):
		var tries := int(t.get("tries", 0))
		out.append([String(TICKET_NAMES.get(String(t.get("id", "")), t.get("id", ""))), tool_name(String(t.get("fix", ""))),
			str(tries), result_name(tries)])
	return out


static func tool_name(id: String) -> String:
	var i := TuneDesk.tool_index(id)
	return String(TuneDesk.TOOLS[i][1]) if i >= 0 else id


static func result_name(tries: int) -> String:
	if tries <= 1:
		return "FIRST TRY"
	return "FIXED"


## The lines under the table, in order.
static func lines(tune: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var used := int(tune.get("tools_used", 0))
	var par := int(tune.get("par", TuneDesk.TICKETS.size()))
	out.append("Tools: %d, par %d: %s" % [used, par, PaperFitting.golf_word(used, par)])
	var asks := clampi(int(tune.get("ask_tries", 1)), 1, PICKS.size())
	out.append("Opening question: \"Where do you have trouble?\" (%s)." % PICKS[asks - 1])
	var ups := int(tune.get("ups", 0))
	if ups > 0:
		out.append("Whole aid up: %s. Louder makes sharp sounds sharper." % ("once" if ups == 1 else "%d times" % ups))
	else:
		out.append("Whole aid up: never. Gus's ears thank you.")
	out.append(TIP)
	out.append(HOOT_SAYS)
	return out


static func _table(tune: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	for i in COLUMNS.size():
		var h := UiKit.label(COLUMNS[i], 13, Palette.INK_SOFT, 700)
		h.custom_minimum_size = Vector2(CELL_W[i], 0)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)
	for r: Array in rows(tune):
		var res_col: Color = TuneDesk.GREEN if String(r[3]) == "FIRST TRY" else Palette.SUNNY
		var cols: Array[Color] = [Color(Palette.INK, 0.25), Color(Palette.INK, 0.45), Color(Palette.INK, 0.25), res_col]
		for i in r.size():
			grid.add_child(PaperWordGolf._cell(String(r[i]), CELL_W[i], cols[i], false, CELL_H))
	return grid
