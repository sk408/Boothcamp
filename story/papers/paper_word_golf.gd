extends RefCounted
## (Days 4-5) Day 4's sports column on The Daily Decibel: THE WORD GOLF CARD (CHAPTER4 §10).
## daily_decibel.gd loads this script from the summary's "sports_script" and calls
## build(c2, audiometry, summary) to fill column 2. One row per word list in play order (Ear . List .
## Level, Noise, Score + band, Golf); a redone list is struck through and marked "(redone)". Under the
## table: what the tones predict, the louder list, the SRTs, the Roll Call and the word counts. Every
## number comes from the visit.

const UiKit := preload("res://story/ui_kit.gd")

const HEADER := "SPORTS: THE WORD GOLF CARD"
const COLUMNS: Array[String] = ["Ear · List · Level", "Noise", "Score + band", "Golf"]
const CELL_W: Array[int] = [196, 64, 150, 96]
const CELL_H := 26
const HOOT_SAYS_GOOD := "HOOT SAYS: Whole words, both ears, louder once, flags raised. Lovely, careful work, trainee."
const HOOT_SAYS_REST := "HOOT SAYS: Whole words, both ears, louder once, flags raised. We'll tune the rest together."
const ARTS := "ARTS: Nightingale Singers' altos now stand on the director's right."
const ROLL_CALL_CARDS := 9


func build(c2: VBoxContainer, aud: Dictionary, s: Dictionary) -> void:
	var sp: Dictionary = aud.get("speech", {})
	c2.add_child(UiKit.label(HEADER, 16, Palette.INK, 700))
	c2.add_child(_table(rows(sp)))
	# the lines sit close together, so a visit with a redone list still fits the page
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -1)
	c2.add_child(box)
	for line: String in lines(sp, s):
		var l := UiKit.label(line, 14, Palette.INK, 700 if line.begins_with("HOOT SAYS") else 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(500, 0)
		box.add_child(l)


## Every word list of the visit (both ears) in play order: {ear, n, title, level_db, masked,
## mask_db, pct, band, golf, redone, louder, by_hoot}.
static func rows(sp: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var wrs: Dictionary = sp.get("wrs", {})
	for e: String in ClinicRules.EARS:
		var sh: Dictionary = wrs.get(e, {})
		for v: Variant in sh.get("lists", []):
			var l: Dictionary = v
			var pct := int(l.get("pct", -1))
			out.append({
				"ear": e, "n": int(l.get("n", 0)), "seq": int(l.get("seq", 0)),
				"title": String(l.get("list_title", SpeechMaterial.title(String(l.get("list_id", ""))))),
				"level_db": int(l.get("level_db", 0)), "masked": bool(l.get("masked", false)),
				"mask_db": int(l.get("mask_db", 0)), "pct": pct,
				"band": StringName(String(l.get("band", SpeechRules.wrs_band(pct)))),
				"golf": StringName(String(l.get("golf", "hoot"))),
				"redone": int(l.get("redone_by", 0)) > 0,
				"louder": int(l.get("louder_than", 0)) > 0, "by_hoot": bool(l.get("by_hoot", false)),
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["seq"]) < int(b["seq"]) if int(a["seq"]) != int(b["seq"]) else int(a["n"]) < int(b["n"]))
	return out


## The lines under the table, in order (a line with nothing to say is left out).
static func lines(sp: Dictionary, s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var wrs: Dictionary = sp.get("wrs", {})
	var mins: Array[String] = []
	for e: String in ClinicRules.EARS:
		var sh: Dictionary = wrs.get(e, {})
		if sh.has("predicted_min"):
			mins.append("%s %d%%" % [e, int(sh["predicted_min"])])
	if not mins.is_empty():
		out.append("Tones predict at least: %s." % ", ".join(mins))
	var roll: Dictionary = (sp.get("wrs_summary", {}) as Dictionary).get("rollover", {})
	if int(roll.get("louder_pct", -1)) >= 0:
		if bool(roll.get("flag", false)):
			out.append("Louder: %d%% fell to %d%% (rollover)." % [int(roll["comfy_pct"]), int(roll["louder_pct"])])
		else:
			out.append("Louder: %d%%, then %d%%: no rollover." % [int(roll["comfy_pct"]), int(roll["louder_pct"])])
	var srt_line := srt_line(sp)
	if srt_line != "":
		out.append(srt_line)
	var rc: Dictionary = s.get("roll_call", {})
	if not rc.is_empty():
		var cards := int(rc.get("cards", ROLL_CALL_CARDS))
		out.append("Red flags sorted: %d of %d (wrong sorts: %d)." % [int(rc.get("sorted", cards)), cards, int(rc.get("slips", 0))])
	var hoots := int(sp.get("hoot_presentations", 0))
	out.append("Your words: %d%s. Best combo: %d." % [int(sp.get("presentations", 0)),
		(" (Hoot: %d)" % hoots) if hoots > 0 else "", int(sp.get("max_combo", 0))])
	var grade := String(s.get("grade", ""))
	out.append(HOOT_SAYS_GOOD if grade == "S" or grade == "A" else HOOT_SAYS_REST)
	out.append(ARTS)
	return out


## "SRT by Hoot: right 15 (good), left 40 (good)." or "Your SRT: ..." when the player ran them.
static func srt_line(sp: Dictionary) -> String:
	var srt: Dictionary = sp.get("srt", {})
	var parts: Array[String] = []
	var all_hoot := true
	var any_hoot := false
	for e: String in ClinicRules.EARS:
		if not srt.has(e):
			continue
		var by_hoot := bool((srt[e] as Dictionary).get("by_hoot", false))
		all_hoot = all_hoot and by_hoot
		any_hoot = any_hoot or by_hoot
	for e: String in ClinicRules.EARS:
		if not srt.has(e):
			continue
		var sh: Dictionary = srt[e]
		var ag := String(sh.get("agreement", ""))
		var tags: Array[String] = []
		if ag != "":
			tags.append(ag)
		if any_hoot and not all_hoot and bool(sh.get("by_hoot", false)):
			tags.append("Hoot's")
		parts.append("%s %d%s" % [e, int(sh.get("stored_db", 0)), (" (%s)" % ", ".join(tags)) if not tags.is_empty() else ""])
	if parts.is_empty():
		return ""
	return "%s: %s." % ["SRT by Hoot" if all_hoot else "Your SRT", ", ".join(parts)]


## The row's text per column: [ear . list . level, noise, score + band, golf].
static func row_texts(r: Dictionary) -> Array[String]:
	var ear := "R" if String(r["ear"]) == "right" else "L"
	var first := "%s · %s · %d dB" % [ear, String(r["title"]), int(r["level_db"])]
	if bool(r["redone"]):
		first += " (redone)"
	var noise := "%d" % int(r["mask_db"]) if bool(r["masked"]) else "none"
	var pct := int(r["pct"])
	var band := StringName(r["band"])
	var score := "%d%% %s" % [pct, String(SpeechRules.WRS_BAND_TITLES.get(band, "")).to_upper()] if pct >= 0 else "-"
	return [first, noise, score, golf_name(StringName(r["golf"]))]


static func golf_name(g: StringName) -> String:
	if g == &"hoot" or g == &"":
		return "Hoot's"
	return String(g).replace("double_", "2x ").replace("triple_", "3x ").replace("_", " ")


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
		var ear_col := Palette.ear_color(String(r["ear"]))
		var band_col: Color = SpScoreStrip.BAND_COLORS.get(StringName(r["band"]), Color(Palette.INK, 0.3))
		var golf := StringName(r["golf"])
		var golf_col: Color = SpeechScreen.GOLF_COLORS.get(golf, Palette.HOOT_BROWN if golf == &"hoot" else Color(Palette.INK, 0.3))
		var cols: Array[Color] = [ear_col, Color(Palette.INK, 0.45) if bool(r["masked"]) else Color(Palette.INK, 0.25), band_col, golf_col]
		for i in texts.size():
			grid.add_child(_cell(texts[i], CELL_W[i], cols[i], bool(r["redone"])))
	return grid


static func _cell(text: String, w: int, col: Color, struck: bool) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(w, CELL_H)
	cell.add_theme_stylebox_override("panel", UiKit.style(Color(col, 0.07 if struck else 0.16), Color(col, 0.5 if struck else 1.0), 6, 2, 0, 2))
	var l := UiKit.label(text, 14 if text.length() > 20 else 15, Color(Palette.INK, 0.55) if struck else Palette.INK, 700)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.clip_text = true
	cell.add_child(l)
	if struck:
		var line := Control.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.draw.connect(func() -> void:
			var y := line.size.y * 0.5
			line.draw_line(Vector2(4, y), Vector2(line.size.x - 4, y), Color(Palette.INK, 0.7), 2.0, true))
		cell.add_child(line)
	return cell
