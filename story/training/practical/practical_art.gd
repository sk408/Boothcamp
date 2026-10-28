extends RefCounted
## PracticalArt (training, story-internal): the drawings of The Practical's cards
## (docs/training/PRACTICAL_EXAM.md). Pure drawing on any CanvasItem, in the stage's own coordinates
## (880 x 440). The game's own cartoon kit: no vendor shapes, logos or photos.
##   PracticalArt.draw_card(ci, size, card, reveal, wrong, t)
## card: a PracticalDeck card; reveal: the answer is shown; wrong: option indexes already tried and
## missed; t: seconds since the card was shown (for small wobbles).

const UiKit := preload("res://story/ui_kit.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")

const TEAL := Color("#1f9aa5")
const GREEN := Color("#3a9d76")
const RED := Color("#e5383b")
const GREY := Color("#7d8398")
const METAL := Color("#c9ccd6")
const CLEAR := Color("#dff4ff")


static func draw_card(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	UiDraw.rounded_rect(ci, Rect2(Vector2.ZERO, size), Color("#fdf6e9"), 26, 4, Palette.INK)
	# the title banner
	var band := Rect2(18, 16, size.x - 36, 52)
	UiDraw.rounded_rect(ci, band, TEAL, 16, 3, Palette.INK)
	ci.draw_string(UiKit.font(700), band.position + Vector2(0, 37), String(card.get("title", "")), HORIZONTAL_ALIGNMENT_CENTER, band.size.x, 30, Palette.PAPER)
	match String(card.get("kind", "")):
		"tray":
			_tray(ci, size, card, reveal, wrong, t)
		"sticker":
			_stickers(ci, size, card, reveal, wrong)
		"listen":
			_listen(ci, size, card, reveal, t)
		"subject":
			_subject(ci, size, card, reveal, t)


# ---------------------------------------------------------------- the kit tray

static func _tray(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	var items: Array = card["items"]
	var w := (size.x - 36 - 3 * 14) / 4.0
	for i in items.size():
		var r := Rect2(18 + i * (w + 14), 88, w, 318)
		var id := String(items[i])
		var it: Dictionary = PracticalDeck.ITEMS[id]
		var home := reveal and i == int(card["answer"])
		var missed := wrong.has(i)
		var bg := Palette.PAPER
		if home:
			bg = Color(RED, 0.18)
		elif reveal:
			bg = Color(GREEN, 0.15)
		UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.18), 20)
		UiDraw.rounded_rect(ci, r, bg, 20, 3, Palette.INK)
		# the key chip
		UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(10, 10), Vector2(34, 34)), Palette.SUNNY, 9, 3, Palette.INK)
		ci.draw_string(UiKit.font(700), r.position + Vector2(10, 35), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Palette.INK)
		var bob := 0.0 if Game.settings.get("reduced_motion", false) else sin(t * 2.0 + i) * 2.0
		draw_item(ci, id, r.position + Vector2(w * 0.5, 118 + bob), 1.0)
		_wrap(ci, String(it["name"]), Rect2(r.position + Vector2(8, 192), Vector2(w - 16, 60)), 20, Palette.INK)
		if home:
			_stamp(ci, r.position + Vector2(w * 0.5, 280), "STAYS HOME", RED, -0.08)
		elif reveal:
			_stamp(ci, r.position + Vector2(w * 0.5, 280), "IN THE BAG", GREEN, 0.06)
		elif missed:
			_stamp(ci, r.position + Vector2(w * 0.5, 280), "IT'S FINE", GREY, 0.05)


## One kit item, centred on c (about 150 x 130 at k = 1).
static func draw_item(ci: CanvasItem, id: String, c: Vector2, k: float) -> void:
	match id:
		"audiometer":
			_box(ci, Rect2(c + Vector2(-62, -40) * k, Vector2(124, 72) * k), Color("#e8e2d6"))
			for i in 3:
				ci.draw_circle(c + Vector2(-34 + i * 30, -10) * k, 10.0 * k, Palette.INK)
				ci.draw_circle(c + Vector2(-34 + i * 30, -10) * k, 6.0 * k, METAL)
			UiDraw.rounded_rect(ci, Rect2(c + Vector2(-44, 12) * k, Vector2(88, 14) * k), Palette.LCD_BG, 4)
			_tag(ci, c + Vector2(40, 46) * k, "CAL", Palette.MINT, k)
		"phones":
			_headset(ci, c, k, Palette.RIGHT_RED, Palette.LEFT_BLUE)
		"inserts":
			for s: float in [-1.0, 1.0]:
				var tip := c + Vector2(s * 36, 10) * k
				ci.draw_line(tip, c + Vector2(s * 12, -46) * k, Palette.INK, 3.0 * k, true)
				ci.draw_circle(tip, 15.0 * k, Color("#ffd9a8"))
				ci.draw_arc(tip, 15.0 * k, 0.0, TAU, 20, Palette.INK, 3.0, true)
				ci.draw_circle(tip + Vector2(0, 0), 4.0 * k, Palette.RIGHT_RED if s > 0 else Palette.LEFT_BLUE)
			_box(ci, Rect2(c + Vector2(-24, -60) * k, Vector2(48, 24) * k), METAL)
		"bone":
			ci.draw_arc(c + Vector2(0, 10) * k, 54.0 * k, PI * 1.1, PI * 1.9, 24, Palette.INK, 7.0 * k, true)
			ci.draw_arc(c + Vector2(0, 10) * k, 54.0 * k, PI * 1.1, PI * 1.9, 24, METAL, 3.5 * k, true)
			_box(ci, Rect2(c + Vector2(30, -14) * k, Vector2(30, 30) * k), Color("#5a5f73"))
			ci.draw_line(c + Vector2(45, 16) * k, c + Vector2(50, 50) * k, Palette.INK, 3.0 * k, true)
		"otoscope":
			_box(ci, Rect2(c + Vector2(-14, -10) * k, Vector2(28, 70) * k), Color("#3b3f52"))
			var head := PackedVector2Array([c + Vector2(-26, -10) * k, c + Vector2(26, -10) * k, c + Vector2(8, -48) * k, c + Vector2(-8, -48) * k])
			_poly(ci, head, METAL)
			_poly(ci, PackedVector2Array([c + Vector2(-8, -48) * k, c + Vector2(8, -48) * k, c + Vector2(3, -64) * k, c + Vector2(-3, -64) * k]), Palette.INK)
		"earlight":
			_box(ci, Rect2(c + Vector2(-10, -30) * k, Vector2(20, 84) * k), Color("#ffb347"))
			ci.draw_line(c + Vector2(0, -30) * k, c + Vector2(0, -62) * k, Palette.INK, 4.0 * k, true)
			ci.draw_circle(c + Vector2(0, -64) * k, 5.0 * k, Palette.SUNNY)
			ci.draw_circle(c + Vector2(0, -64) * k, 12.0 * k, Color(Palette.SUNNY, 0.3))
		"syringe", "tip_syringe":
			var body := Rect2(c + Vector2(-60, -14) * k, Vector2(84, 28) * k)
			UiDraw.rounded_rect(ci, body, CLEAR, 6, 3, Palette.INK)
			ci.draw_rect(Rect2(body.position + Vector2(6, 6) * k, Vector2(40, 16) * k), Color(Palette.SELECT_ORANGE, 0.7))
			ci.draw_line(c + Vector2(-60, 0) * k, c + Vector2(-82, 0) * k, Palette.INK, 5.0 * k, true)
			ci.draw_line(c + Vector2(-82, -14) * k, c + Vector2(-82, 14) * k, Palette.INK, 5.0 * k, true)
			var gap := 10.0 if id == "tip_syringe" else 0.0
			var tip := PackedVector2Array([c + Vector2(24 + gap, -10) * k, c + Vector2(64 + gap, -4) * k, c + Vector2(64 + gap, 4) * k, c + Vector2(24 + gap, 10) * k])
			_poly(ci, tip, CLEAR)
			if gap > 0.0:
				ci.draw_string(UiKit.font(700), c + Vector2(14, 40) * k, "snap-on", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * k), RED)
		"gun", "e_gun":
			var g := PackedVector2Array([c + Vector2(-56, -30) * k, c + Vector2(40, -30) * k, c + Vector2(40, -6) * k, c + Vector2(-10, -6) * k,
				c + Vector2(-16, 50) * k, c + Vector2(-40, 50) * k, c + Vector2(-36, -6) * k, c + Vector2(-56, -6) * k])
			_poly(ci, g, Color("#5bc8a3") if id == "gun" else Color("#9aa0b5"))
			_poly(ci, PackedVector2Array([c + Vector2(40, -24) * k, c + Vector2(70, -20) * k, c + Vector2(70, -16) * k, c + Vector2(40, -12) * k]), CLEAR)
			if id == "e_gun":
				var bolt := PackedVector2Array([c + Vector2(0, -26) * k, c + Vector2(-12, -14) * k, c + Vector2(-2, -14) * k, c + Vector2(-10, 0) * k,
					c + Vector2(8, -16) * k, c + Vector2(-2, -16) * k])
				_poly(ci, bolt, Palette.SUNNY)
				ci.draw_line(c + Vector2(-28, 50) * k, c + Vector2(-50, 64) * k, Palette.INK, 3.0 * k, true)
		"material", "old_material":
			for i in 2:
				var tr := Rect2(c + Vector2(-46 + i * 50, -44) * k, Vector2(40, 74) * k)
				UiDraw.rounded_rect(ci, tr, Palette.SELECT_ORANGE if i == 0 else Color("#7fb8ff"), 8, 3, Palette.INK)
			_tag(ci, c + Vector2(0, 50) * k, "EXP 2019" if id == "old_material" else "EXP 2028", RED if id == "old_material" else Palette.MINT, k)
		"dams":
			for i in 3:
				var p := c + Vector2(-44 + i * 44, 0) * k
				var r := (9.0 + i * 5.0) * k
				ci.draw_circle(p, r, Palette.PAPER)
				ci.draw_arc(p, r, 0.0, TAU, 20, Palette.INK, 3.0, true)
				ci.draw_line(p + Vector2(0, r), p + Vector2(0, r + 30 * k), Palette.INK, 2.0 * k, true)
		"tube":
			ci.draw_line(c + Vector2(-40, -44) * k, c + Vector2(0, 0) * k, Palette.INK, 6.0 * k, true)
			ci.draw_line(c + Vector2(40, -44) * k, c + Vector2(0, 0) * k, Palette.INK, 6.0 * k, true)
			ci.draw_line(c, c + Vector2(0, 50) * k, Palette.INK, 6.0 * k, true)
			for s: float in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(s * 42, -48) * k, 8.0 * k, Color("#7fb8ff"))
			ci.draw_circle(c + Vector2(0, 54) * k, 10.0 * k, CLEAR)
			ci.draw_arc(c + Vector2(0, 54) * k, 10.0 * k, 0.0, TAU, 16, Palette.INK, 3.0, true)
		"gel", "jumbo_gel":
			var big := id == "jumbo_gel"
			var bw := 64.0 if big else 40.0
			var bh := 100.0 if big else 62.0
			var b := Rect2(c + Vector2(-bw * 0.5, 50 - bh) * k, Vector2(bw, bh) * k)
			UiDraw.rounded_rect(ci, b, Color("#b8f0e0"), 10, 3, Palette.INK)
			ci.draw_rect(Rect2(c + Vector2(-6, 50 - bh - 16) * k, Vector2(12, 16) * k), Palette.INK)
			ci.draw_string(UiKit.font(700), b.position + Vector2(0, b.size.y * 0.6), "32 oz" if big else "8 oz", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, int(15 * k), Palette.INK)
		"wipes", "bleach":
			var tub := Rect2(c + Vector2(-50, -30) * k, Vector2(100, 70) * k)
			UiDraw.rounded_rect(ci, tub, Color("#ffe3e0") if id == "bleach" else Color("#dfeaff"), 12, 3, Palette.INK)
			ci.draw_rect(Rect2(c + Vector2(-50, -40) * k, Vector2(100, 14) * k), Palette.INK)
			ci.draw_string(UiKit.font(700), tub.position + Vector2(0, 44 * k), "BLEACH" if id == "bleach" else "NO BLEACH", HORIZONTAL_ALIGNMENT_CENTER, tub.size.x, int(15 * k), RED if id == "bleach" else Palette.INK)
		"watch":
			ci.draw_rect(Rect2(c + Vector2(-14, -60) * k, Vector2(28, 120) * k), Color("#8a5a3c"))
			ci.draw_circle(c, 30.0 * k, Palette.PAPER)
			ci.draw_arc(c, 30.0 * k, 0.0, TAU, 28, Palette.INK, 4.0, true)
			ci.draw_line(c, c + Vector2(0, -20) * k, Palette.INK, 3.0, true)
			ci.draw_line(c, c + Vector2(14, 0) * k, Palette.INK, 3.0, true)
		"phone":
			UiDraw.rounded_rect(ci, Rect2(c + Vector2(-32, -58) * k, Vector2(64, 116) * k), Palette.INK, 12)
			ci.draw_rect(Rect2(c + Vector2(-26, -48) * k, Vector2(52, 92) * k), Palette.SKY)
		"notes":
			var pg := Rect2(c + Vector2(-46, -56) * k, Vector2(92, 112) * k)
			UiDraw.rounded_rect(ci, pg, Palette.PAPER, 6, 3, Palette.INK)
			for i in 6:
				ci.draw_line(pg.position + Vector2(12, 20 + i * 15) * k, pg.position + Vector2(80, 20 + i * 15) * k, Color(Palette.LEFT_BLUE, 0.6), 2.0, true)
			ci.draw_string(UiKit.font(700), pg.position + Vector2(0, 16 * k), "ANSWERS!", HORIZONTAL_ALIGNMENT_CENTER, pg.size.x, int(13 * k), RED)


# ---------------------------------------------------------------- calibration stickers

static func _stickers(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array) -> void:
	# the exam date, a desk calendar
	var cal := Rect2(size.x - 210, 80, 180, 60)
	UiDraw.rounded_rect(ci, cal, Palette.PAPER, 10, 3, Palette.INK)
	ci.draw_rect(Rect2(cal.position, Vector2(cal.size.x, 18)), RED)
	ci.draw_string(UiKit.font(700), cal.position + Vector2(0, 15), "EXAM DAY", HORIZONTAL_ALIGNMENT_CENTER, cal.size.x, 14, Palette.PAPER)
	ci.draw_string(UiKit.font(700), cal.position + Vector2(0, 50), String(card["exam"]), HORIZONTAL_ALIGNMENT_CENTER, cal.size.x, 26, Palette.INK)
	var backs: Array = card["backs"]
	for i in backs.size():
		var x := 40.0 + i * 270.0
		var c := Vector2(x + 110, 250)
		UiDraw.rounded_rect(ci, Rect2(Vector2(x, 160), Vector2(220, 240)), Palette.PAPER, 18, 3, Palette.INK)
		UiDraw.rounded_rect(ci, Rect2(Vector2(x + 10, 170), Vector2(34, 34)), Palette.SUNNY, 9, 3, Palette.INK)
		ci.draw_string(UiKit.font(700), Vector2(x + 10, 195), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Palette.INK)
		draw_item(ci, "audiometer", c, 1.1)
		var st := Rect2(Vector2(x + 26, 318), Vector2(168, 54))
		UiDraw.rounded_rect(ci, st, Color("#fff7c2"), 8, 2, Palette.INK)
		ci.draw_string(UiKit.font(600), st.position + Vector2(0, 21), "CALIBRATED", HORIZONTAL_ALIGNMENT_CENTER, st.size.x, 15, Palette.INK_SOFT)
		ci.draw_string(UiKit.font(700), st.position + Vector2(0, 45), PracticalDeck.month_word(PracticalDeck.EXAM_MONTH - int(backs[i])), HORIZONTAL_ALIGNMENT_CENTER, st.size.x, 22, Palette.INK)
		if reveal:
			var ok := i == int(card["answer"])
			_stamp(ci, Vector2(x + 110, 220), "IN DATE" if ok else "%d MONTHS" % int(backs[i]), GREEN if ok else RED, -0.1 if ok else 0.08)
		elif wrong.has(i):
			_stamp(ci, Vector2(x + 110, 220), "%d MONTHS" % int(backs[i]), RED, 0.08)


# ---------------------------------------------------------------- the listening check

static func _listen(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, t: float) -> void:
	var fault := String(card["fault"])
	# the symptom, a speech-style note
	var note := Rect2(30, 80, size.x - 60, 70)
	UiDraw.rounded_rect(ci, note, Palette.PAPER, 16, 3, Palette.INK)
	_wrap(ci, String(card["symptom"]), note.grow(-12), 22, Palette.INK)
	# the audiometer, its cords, the cups and the bone oscillator
	var am := Vector2(200, 300)
	draw_item(ci, "audiometer", am, 1.5)
	var right_cup := Vector2(520, 230)
	var left_cup := Vector2(660, 230)
	var bone := Vector2(600, 370)
	var red_col := Palette.RIGHT_RED
	var blue_col := Palette.LEFT_BLUE
	# the cups: on a swap, the red cup sits where the blue should be
	var rc := left_cup if fault == "swap" else right_cup
	var lc := right_cup if fault == "swap" else left_cup
	_cord(ci, am + Vector2(90, -20), rc + Vector2(0, 30), red_col, fault == "cord" and reveal, t)
	_cord(ci, am + Vector2(90, 0), lc + Vector2(0, 30), blue_col, false, t)
	_cord(ci, am + Vector2(90, 30), bone + Vector2(-20, 0), Palette.INK, false, t)
	ci.draw_arc((right_cup + left_cup) * 0.5 + Vector2(0, 10), 82.0, PI * 1.12, PI * 1.88, 24, Palette.INK, 7.0, true)
	_cup(ci, rc, red_col, "R")
	_cup(ci, lc, blue_col, "L")
	_box(ci, Rect2(bone + Vector2(-22, -22), Vector2(44, 44)), Color("#5a5f73"))
	ci.draw_string(UiKit.font(700), bone + Vector2(-22, 8), "BONE", HORIZONTAL_ALIGNMENT_CENTER, 44, 13, Palette.PAPER)
	# the headset's sides, as worn on the subject
	ci.draw_string(UiKit.font(600), right_cup + Vector2(-162, 6), "right side", HORIZONTAL_ALIGNMENT_RIGHT, 120, 16, Palette.INK_SOFT)
	ci.draw_string(UiKit.font(600), left_cup + Vector2(42, 6), "left side", HORIZONTAL_ALIGNMENT_LEFT, 120, 16, Palette.INK_SOFT)
	if not reveal:
		return
	match fault:
		"cord":
			_stamp(ci, Vector2(420, 230), "CRACKLY CORD", RED, -0.06)
		"swap":
			_stamp(ci, Vector2(590, 300), "CUPS SWAPPED", RED, 0.05)
		"bone":
			UiDraw.cross(ci, bone, 30.0, RED, 6.0)
			_stamp(ci, bone + Vector2(140, 0), "SILENT", RED, -0.05)
		_:
			_stamp(ci, Vector2(590, 300), "ALL CLEAR", GREEN, -0.05)


static func _cord(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, crackle: bool, t: float) -> void:
	var pts := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		var p := a.lerp(b, u) + Vector2(0, sin(u * PI) * 40.0)
		if crackle and i % 2 == 1:
			p += Vector2(0, 7.0 * sin(t * 30.0 + i))
		pts.append(p)
	ci.draw_polyline(pts, Palette.INK, 7.0, true)
	ci.draw_polyline(pts, col, 3.5, true)


static func _cup(ci: CanvasItem, c: Vector2, col: Color, letter: String) -> void:
	ci.draw_circle(c, 34.0, Palette.INK)
	ci.draw_circle(c, 29.0, col)
	ci.draw_string(UiKit.font(700), c + Vector2(-34, 10), letter, HORIZONTAL_ALIGNMENT_CENTER, 68, 28, Palette.PAPER)


static func _headset(ci: CanvasItem, c: Vector2, k: float, r: Color, l: Color) -> void:
	ci.draw_arc(c + Vector2(0, 16) * k, 52.0 * k, PI * 1.05, PI * 1.95, 24, Palette.INK, 8.0 * k, true)
	for s: float in [-1.0, 1.0]:
		var p := c + Vector2(s * 52, 22) * k
		ci.draw_circle(p, 24.0 * k, Palette.INK)
		ci.draw_circle(p, 20.0 * k, r if s < 0 else l)


# ---------------------------------------------------------------- the subject

static func _subject(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, t: float) -> void:
	var r := Rect2(120, 92, size.x - 240, 314)
	UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(0, 8), r.size), Color(0, 0, 0, 0.2), 24)
	UiDraw.rounded_rect(ci, r, Palette.PAPER, 24, 4, Palette.INK)
	# the face
	var seed := String(card["subject"]).hash()
	var skin: Color = [Palette.SKIN, Color("#d9a273"), Color("#a86b45"), Color("#f2c9a0")][posmod(seed, 4)]
	var hair: Color = [Color("#5a3a22"), Color("#c9ccd6"), Palette.INK, Color("#e0a940")][posmod(seed >> 3, 4)]
	var fc := r.position + Vector2(130, 150)
	var nod := 0.0 if Game.settings.get("reduced_motion", false) else sin(t * 1.6) * 3.0
	ci.draw_circle(fc + Vector2(0, -8 + nod), 74.0, hair)
	ci.draw_circle(fc + Vector2(0, nod), 62.0, skin)
	ci.draw_arc(fc + Vector2(0, nod), 62.0, 0.0, TAU, 32, Palette.INK, 4.0, true)
	for s: float in [-1.0, 1.0]:
		ci.draw_circle(fc + Vector2(s * 22, -8 + nod), 7.0, Palette.INK)
	ci.draw_arc(fc + Vector2(0, 16 + nod), 20.0, 0.3, PI - 0.3, 12, Palette.INK, 4.0, true)
	ci.draw_string(UiKit.font(700), r.position + Vector2(260, 110), String(card["who"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Palette.INK)
	_wrap(ci, String(card["about"]), Rect2(r.position + Vector2(260, 130), Vector2(r.size.x - 290, 120)), 24, Palette.INK)
	ci.draw_string(UiKit.font(600), r.position + Vector2(260, 280), "Subject application", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.INK_SOFT)
	if reveal:
		var ok := bool(card["ok"])
		_stamp(ci, r.position + Vector2(r.size.x - 140, 226), "APPROVED" if ok else "NOT THIS TIME", GREEN if ok else RED, -0.1)


# ---------------------------------------------------------------- helpers

static func _box(ci: CanvasItem, r: Rect2, col: Color) -> void:
	UiDraw.rounded_rect(ci, r, col, 8, 3, Palette.INK)


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	ci.draw_colored_polygon(pts, col)
	var o := pts.duplicate()
	o.append(pts[0])
	ci.draw_polyline(o, Palette.INK, 3.0, true)


static func _tag(ci: CanvasItem, c: Vector2, text: String, col: Color, k: float) -> void:
	var r := Rect2(c - Vector2(40, 12) * k, Vector2(80, 24) * k)
	UiDraw.rounded_rect(ci, r, col, 6, 2, Palette.INK)
	ci.draw_string(UiKit.font(700), r.position + Vector2(0, 18 * k), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(14 * k), Palette.INK)


## A rubber stamp, tilted.
static func _stamp(ci: CanvasItem, c: Vector2, text: String, col: Color, tilt: float) -> void:
	var f := UiKit.font(700)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x + 28
	ci.draw_set_transform(c, tilt, Vector2.ONE)
	UiDraw.rounded_rect(ci, Rect2(Vector2(-w * 0.5, -20), Vector2(w, 40)), Color(Palette.PAPER, 0.85), 8, 4, col)
	ci.draw_string(f, Vector2(-w * 0.5, 8), text, HORIZONTAL_ALIGNMENT_CENTER, w, 22, col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Word-wrapped text inside a rect (top-aligned).
static func _wrap(ci: CanvasItem, text: String, r: Rect2, px: int, col: Color) -> void:
	var f := UiKit.font(600)
	var lines: Array[String] = []
	var cur := ""
	for w: String in text.split(" "):
		var nxt := w if cur == "" else cur + " " + w
		if f.get_string_size(nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > r.size.x and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = nxt
	if cur != "":
		lines.append(cur)
	for i in lines.size():
		ci.draw_string(f, r.position + Vector2(0, px + i * (px + 6)), lines[i], HORIZONTAL_ALIGNMENT_CENTER if r.size.x < 260 else HORIZONTAL_ALIGNMENT_LEFT, r.size.x, px, col)
