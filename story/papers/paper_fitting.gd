extends RefCounted
## (Day 14) The Daily Decibel's sports column for the fitting: THE FITTING CARD (docs/FITTING.md §3).
## daily_decibel.gd loads this script from the summary's "sports_script" and calls
## build(c2, audiometry, summary). One row per band of the right ear (Band . Target . Fit . Off by .
## Result), then the moves against par, the style and how many picks it took, one line for the probe
## tube, the loud limit and the talk, the left ear (Hoot's), a tip and Hoot's line. Every number comes
## from the visit's "fitting" results.

const UiKit := preload("res://story/ui_kit.gd")
const PaperWordGolf := preload("res://story/papers/paper_word_golf.gd")
const TargetMatch := preload("res://story/games/target_match.gd")

const HEADER := "SPORTS: THE FITTING CARD"
const COLUMNS: Array[String] = ["Band", "Target", "Fit", "Off by", "Result"]
const CELL_W: Array[int] = [104, 76, 76, 76, 150]
const CELL_H := 24
const STYLE_NAMES: Dictionary = {"ric_open": "speaker in the canal, open dome"}
const PICKS: Array[String] = ["first pick", "second pick", "third pick"]
const TIP := "Real fittings: measure in the ear, then fine-tune over the first few weeks."
const HOOT_SAYS := "HOOT SAYS: The target is where we start. Gus's ears and Gus's life finish the job."


func build(c2: VBoxContainer, aud: Dictionary, _s: Dictionary) -> void:
	var fit: Dictionary = aud.get("fitting", {})
	c2.add_child(UiKit.label(HEADER, 16, Palette.INK, 700))
	c2.add_child(_table(fit))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", -2)
	c2.add_child(box)
	for line: String in lines(fit):
		var l := UiKit.label(line, 14, Palette.INK, 700 if line.begins_with("HOOT SAYS") else 600)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(500, 0)
		box.add_child(l)


## One row per band: [band, target, fit, off by, result].
static func rows(fit: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	for b: Dictionary in fit.get("bands", []):
		var i := TargetMatch.BANDS.find(int(b.get("freq", 0)))
		var name := "%s %s" % [TargetMatch.BAND_NAMES[i], TargetMatch.BAND_KHZ[i]] if i >= 0 else str(b.get("freq", ""))
		var err := int(b.get("err", 0))
		out.append([name, "%d dB" % int(b.get("target", 0)), "%d dB" % int(b.get("final", 0)), "%+d" % err if err != 0 else "0", result_name(err)])
	return out


static func result_name(err: int) -> String:
	if absi(err) <= TargetMatch.BULLSEYE_DB:
		return "BULLSEYE"
	if absi(err) <= TargetMatch.ZONE_DB:
		return "IN THE GREEN"
	return "TOO MUCH" if err > 0 else "TOO LITTLE"


## Golf on moves: par, or a bogey and worse (a birdie when a band started in the green).
static func golf_word(moves: int, par: int) -> String:
	match moves - par:
		-2:
			return "EAGLE"
		-1:
			return "BIRDIE"
		0:
			return "PAR"
		1:
			return "BOGEY"
		2:
			return "DOUBLE BOGEY"
	return "UNDER PAR" if moves < par else "%d OVER PAR" % (moves - par)


## The lines under the table, in order.
static func lines(fit: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var moves := int(fit.get("moves", 0))
	var par := int(fit.get("par", 0))
	out.append("Moves: %d, par %d: %s" % [moves, par, golf_word(moves, par)])
	var tries := clampi(int(fit.get("style_tries", 1)), 1, PICKS.size())
	out.append("Style: %s (%s)." % [String(STYLE_NAMES.get(String(fit.get("style", "")), "open fit")), PICKS[tries - 1]])
	if fit.has("probe_mistakes"):
		var drops := int(fit.get("loud_drops", 1))
		out.append("Tube: %s. Loud limit: %s. Talk: three of three, %s." % [_slips(int(fit["probe_mistakes"]), "first try"),
			"first drop" if drops <= 1 else "%d drops" % drops, _slips(int(fit.get("counsel_slips", 0)), "no slips")])
	var over: Array = fit.get("overshoots", [])
	if not over.is_empty():
		var kinds: Array[String] = []
		for k: Variant in over:
			kinds.append("whistled" if String(k) == "whistle" else "too loud")
		out.append("Overshoots: %s. Over the target is never better." % " and ".join(kinds))
	if bool(fit.get("left_by_hoot", false)):
		out.append("Left ear: matched by Hoot, at Hoot speed.")
	out.append(TIP)
	out.append(HOOT_SAYS)
	return out


static func _slips(n: int, none: String) -> String:
	if n <= 0:
		return none
	return "1 slip" if n == 1 else "%d slips" % n


static func _table(fit: Dictionary) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = COLUMNS.size()
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	for i in COLUMNS.size():
		var h := UiKit.label(COLUMNS[i], 13, Palette.INK_SOFT, 700)
		h.custom_minimum_size = Vector2(CELL_W[i], 0)
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(h)
	var ear_col := Palette.ear_color(String(fit.get("ear", "right")))
	for r: Array in rows(fit):
		var res_col: Color = TargetMatch.GREEN if String(r[4]) in ["BULLSEYE", "IN THE GREEN"] else Palette.CORAL
		var cols: Array[Color] = [ear_col, Color(Palette.INK, 0.25), Color(Palette.INK, 0.45), Color(Palette.INK, 0.25), res_col]
		for i in r.size():
			grid.add_child(PaperWordGolf._cell(String(r[i]), CELL_W[i], cols[i], false, CELL_H))
	return grid
