extends RefCounted
## (Days 4-5) Day 5's sports column on The Daily Decibel: THE PARTY GOLF CARD (CHAPTER5 §8.4).
## daily_decibel.gd loads this script from the summary's "sports_script" and calls
## build(c2, audiometry, summary) to fill column 2. One row per condition (Condition . Lists . SNR
## loss . Band . Golf and forks): unaided under the earphones, then programmes A (OMNI) and B (FOCUS)
## in the sound field; a list Hoot scored any of is starred. Under the table: the formula, the
## directional benefit and whether it is real, the booth's honest caveat (A7), three tips, the key
## word counts and Hoot's line. Every number comes from the visit. No "beeps" or "spondees" here (a
## test): the day's words are key words and SNRs.

const UiKit := preload("res://story/ui_kit.gd")
const PaperWordGolf := preload("res://story/papers/paper_word_golf.gd")
const MarcoBoard := preload("res://story/games/marco_board.gd")

const HEADER := "SPORTS: THE PARTY GOLF CARD"
const COLUMNS: Array[String] = ["Condition", "Lists", "SNR loss", "Band", "Golf · forks"]
const CELL_W: Array[int] = [136, 62, 70, 92, 150]
const CELL_H := 22
## The rows in order: the sin slot, its title (the transducer is added to the unaided one).
const ROWS: Array = [["both", "UNAIDED"], ["aided_omni", "A: OMNI"], ["aided_directional", "B: FOCUS"]]
const STAR_LINE := "* Hoot scored some or all of that list."
const FORMULA := "SNR loss = 25.5 - key words right, two lists averaged."
const BOOTH_KINDER := "The booth is kinder than a real restaurant. We'll check how the aids do at your table."
const TIPS: Array[String] = [
	"Booths and corners beat the middle of the room. Ask when you book.",
	"Real fittings are checked with a tiny mic in the ear, then fine-tuned over weeks.",
	"Loud nights? Filtered earplugs keep the music and spare the ears.",
]
const HOOT_SAYS := "HOOT SAYS: The audiogram tells you about quiet. The party test tells you about life."


func build(c2: VBoxContainer, aud: Dictionary, s: Dictionary) -> void:
	var sp: Dictionary = aud.get("speech", {})
	c2.add_child(UiKit.label(HEADER, 16, Palette.INK, 700))
	c2.add_child(_table(rows(sp)))
	# the lines sit close together, so the WANTED panel still fits at 720p
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	c2.add_child(box)
	for line: String in lines(sp, s):
		var l := UiKit.label(line, 13, Palette.INK, 700 if line.begins_with("HOOT SAYS") else 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(500, 0)
		box.add_child(l)


## One row per condition the visit tested: {slot, title, totals: [[total, by_hoot]], loss, band,
## aided, golf: [names of the player's lists], forks}.
static func rows(sp: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var sin: Dictionary = sp.get("sin", {})
	for r: Array in ROWS:
		var sh: Dictionary = sin.get(String(r[0]), {})
		if sh.is_empty():
			continue
		var totals: Array = []
		var golf: Array[String] = []
		for v: Variant in sh.get("lists", []):
			var l: Dictionary = v
			totals.append([int(l.get("total", 0)), int(l.get("hoot_sentences", 0)) > 0])
			if int(l.get("player_sentences", 0)) > 0:
				golf.append(PaperWordGolf.golf_name(StringName(String(l.get("golf", "hoot")))))
		var aided := bool(sh.get("aided", String(r[0]) != "both"))
		var title := String(r[1])
		title += ", speakers" if aided else ", " + String(sh.get("transducer", "phones"))
		out.append({"slot": String(r[0]), "title": title, "totals": totals, "loss": float(sh.get("snr_loss", 0.0)),
			"band": StringName(String(sh.get("band", ""))), "aided": aided, "golf": golf, "forks": int(sh.get("forks", -1))})
	return out


## The row's text per column: [condition, lists, SNR loss, band, golf . forks].
static func row_texts(r: Dictionary) -> Array[String]:
	var lists: Array[String] = []
	for t: Array in r["totals"]:
		lists.append("%d%s" % [int(t[0]), "*" if bool(t[1]) else ""])
	var band := "(aided)" if bool(r["aided"]) else String(SpeechRules.SIN_BAND_NAMES.get(StringName(r["band"]), "")).to_upper()
	var golf: Array[String] = []
	for g: Variant in r["golf"]:
		golf.append(String(g))
	golf.append(forks_text(int(r["forks"])))
	return [String(r["title"]), "  ".join(lists), "%.1f dB" % float(r["loss"]), band, " · ".join(golf)]


## Marco's forks for a programme: 3, 2 or 1 fork, "sent back", or Hoot's when he scored it all.
static func forks_text(forks: int) -> String:
	if forks < 0:
		return "Hoot's"
	if forks == 0:
		return "sent back"
	return "%d fork%s" % [forks, "" if forks == 1 else "s"]


## The lines under the table, in order (a line with nothing to say is left out).
static func lines(sp: Dictionary, s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var starred := false
	for r: Dictionary in rows(sp):
		for t: Array in r["totals"]:
			starred = starred or bool(t[1])
	# the star's note shares the formula's line, so the WANTED panel still fits at 720p
	out.append(FORMULA + ("  " + STAR_LINE if starred else ""))
	var sm: Dictionary = sp.get("sin_summary", {})
	if sm.has("benefit_db"):
		out.append("Directional benefit %.1f dB (%.1f needed: %s)." % [float(sm["benefit_db"]), float(sm.get("crit_diff_db", 0.0)),
			"real" if bool(sm.get("real_change", false)) else "run another list each"])
		out.append(BOOTH_KINDER)
	out.append_array(TIPS)
	var judged := 0
	var matches := 0
	for slot: Variant in sp.get("sin", {}):
		var sh: Dictionary = (sp["sin"] as Dictionary)[slot]
		for v: Variant in sh.get("lists", []):
			judged += int((v as Dictionary).get("key_words", 0))
			matches += int((v as Dictionary).get("matches", 0))
	out.append("Your key words: %d · Scored as said: %d · Best combo: %d" % [judged, matches, int(sp.get("max_combo", 0))])
	out.append(HOOT_SAYS)
	return out


static func _table(rs: Array[Dictionary]) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	for i in COLUMNS.size():
		var h := UiKit.label(COLUMNS[i], 13, Palette.INK_SOFT, 700)
		h.custom_minimum_size = Vector2(CELL_W[i], 0)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)
	for r: Dictionary in rs:
		var texts := row_texts(r)
		var band_col: Color = Color(Palette.INK, 0.3) if bool(r["aided"]) else (MarcoBoard.BAND_COLORS.get(StringName(r["band"]), Color(Palette.INK, 0.3)) as Color)
		var row_col := Palette.BOTH_INK if not bool(r["aided"]) else (Palette.SUNNY.darkened(0.2) if String(r["slot"]) == "aided_omni" else Palette.MINT.darkened(0.1))
		var cols: Array[Color] = [row_col, Color(Palette.INK, 0.3), Color(Palette.INK, 0.45), band_col, Palette.HOOT_BROWN if int(r["forks"]) < 0 else Palette.MINT]
		for i in texts.size():
			grid.add_child(PaperWordGolf._cell(texts[i], CELL_W[i], cols[i], false, CELL_H))
	return grid

