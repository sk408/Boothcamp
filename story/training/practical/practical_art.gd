extends RefCounted
## PracticalArt (training, story-internal): the drawings of The Practical's cards
## (docs/training/PRACTICAL_EXAM.md). Pure drawing on any CanvasItem, in the stage's own coordinates
## (880 x 440). The game's own cartoon kit: no vendor shapes, logos or photos.
##   PracticalArt.draw_card(ci, size, card, reveal, wrong, t)
## card: a PracticalDeck card; reveal: the answer is shown; wrong: option indexes already tried and
## missed; t: seconds since the card was shown (for small wobbles).

const UiKit := preload("res://story/ui_kit.gd")
const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
const ArcadeArt := preload("res://story/arcade/arcade_art.gd")

const TEAL := Color("#1f9aa5")
const GREEN := Color("#3a9d76")
const RED := Color("#e5383b")
const GREY := Color("#7d8398")
const METAL := Color("#c9ccd6")
const CLEAR := Color("#dff4ff")
const HAND := Color("#f2c9a0")
const SHIRT := Color("#5b7fc7")
const HAIR := Color("#6b4a2f")
## A sneeze, after a grip is judged: one every SNEEZE_EVERY s, the head jolting for SNEEZE_S.
const SNEEZE_EVERY := 2.6
const SNEEZE_S := 0.7


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
		"grip":
			_grips(ci, size, card, reveal, wrong, t)
		"brace":
			_brace(ci, size, card, reveal, wrong, t)
		"wash":
			_wash(ci, size, card, reveal, wrong, t)
		"look":
			_look(ci, size, card, reveal, t)
		"seat":
			_seats(ci, size, card, reveal, wrong, t)
		"order":
			_order(ci, size, card, reveal, wrong)
		"rule":
			_rule(ci, size, card, reveal, wrong)
		"walk":
			_walk(ci, size, card, reveal, wrong, t)


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


# ---------------------------------------------------------------- Station 2: grips

## How far the head has jolted in a sneeze (0..1), t seconds after the sneezing started (-1: none yet).
static func sneeze(t: float) -> float:
	if t < 0.0:
		return 0.0
	var ph := fmod(t, SNEEZE_EVERY)
	if ph > SNEEZE_S:
		return 0.0
	return sin(ph / SNEEZE_S * PI)


## One grip: a head in profile (facing left) with its ear at e, the hands and the tool, at scale k.
## jolt (0..1): a sneeze moves the head toward the tool; whatever is braced on the head moves with it,
## the rest stays put, and an unbraced tip pokes in (a red OW!). wobble: a floating hand's shake.
## o: {"bridge": show the bridge hand (default: the grip's), "tool": show the tool and its hand (true)}.
static func draw_grip(ci: CanvasItem, e: Vector2, k: float, tool: String, grip: String, jolt: float, wobble := 0.0, o := {}) -> void:
	var g: Dictionary = PracticalDeck.GRIPS.get(grip, PracticalDeck.GRIPS["safe"])
	var bridge := bool(o.get("bridge", g["bridge"]))
	var braced := bool(g["braced"]) and bridge
	var show_tool := bool(o.get("tool", true))
	var jv := Vector2(16, -2) * jolt * k
	var he := e + jv   # the ear, where the head is now
	_profile(ci, e, k, jv)
	if bridge:
		_bridge_hand(ci, he, k)
	if not show_tool:
		return
	var te := he if braced else e + Vector2(0, wobble) * k   # where the tool thinks the ear is
	var tip := te + Vector2(2, 0) * k
	if grip == "pencil":
		tip = te + Vector2(8, 4) * k
	_tool(ci, tip, k, tool, grip == "pencil")
	var hold := _hold_point(tip, k, tool, grip == "pencil")
	if grip != "pencil":
		UiDraw.rounded_rect(ci, Rect2(hold - Vector2(20, 16) * k, Vector2(40, 32) * k), HAND, int(12 * k), 3, Palette.INK)
	else:
		for i in 2:
			ci.draw_circle(hold + Vector2(i * 10, -6 + i * 12) * k, 8.0 * k, HAND)
			ci.draw_arc(hold + Vector2(i * 10, -6 + i * 12) * k, 8.0 * k, 0.0, TAU, 14, Palette.INK, 2.5, true)
	# the bracing finger: onto the bridge hand (or the head behind the ear, handle down)
	if grip == "safe" or grip == "float":
		var to := _brace_point(he, k, tool)
		var from := hold + (to - hold).normalized() * 18.0 * k
		var reach := to if braced else from.lerp(to, 0.55)
		ci.draw_line(from, reach, Palette.INK, 11.0 * k, true)
		ci.draw_line(from, reach, HAND, 7.0 * k, true)
		if braced:
			ci.draw_circle(to, 5.0 * k, GREEN)
		else:
			for i in 3:
				var wv := reach.lerp(to, 0.25 + i * 0.25)
				ci.draw_arc(wv, 4.0 * k, 0.0, PI, 6, Color(RED, 0.8), 2.0, true)
	if not braced and jolt > 0.35:
		_ow(ci, e + Vector2(-6, -40) * k, k * (0.7 + 0.5 * jolt))


## The head in profile (facing left): hair, face, eye, nose, the neck and the shoulders (which never
## jolt), and the outer ear at e + jv.
static func _profile(ci: CanvasItem, e: Vector2, k: float, jv: Vector2) -> void:
	var h := e + Vector2(-40, -18) * k + jv
	# shoulders and neck stay put
	var sh := e + Vector2(-26, 150) * k
	ci.draw_colored_polygon(_oval(sh, 120.0 * k, 42.0 * k, 24), SHIRT)
	ci.draw_polyline(_ring(_oval(sh, 120.0 * k, 42.0 * k, 24)), Palette.INK, 3.0, true)
	var neck := Rect2(e + Vector2(-58, 52) * k + jv * 0.4, Vector2(52, 66) * k)
	ci.draw_rect(neck, Palette.SKIN)
	ci.draw_line(neck.position, neck.position + Vector2(0, neck.size.y), Palette.INK, 3.0, true)
	ci.draw_line(neck.position + Vector2(neck.size.x, 0), neck.end, Palette.INK, 3.0, true)
	ci.draw_circle(h + Vector2(8, -10) * k, 96.0 * k, HAIR)
	ci.draw_colored_polygon(_oval(h, 92.0 * k, 88.0 * k, 32), Palette.SKIN)
	var nose := PackedVector2Array([h + Vector2(-84, -10) * k, h + Vector2(-112, 18) * k, h + Vector2(-82, 26) * k])
	ci.draw_colored_polygon(nose, Palette.SKIN)
	ci.draw_polyline(nose, Palette.INK, 3.0, true)
	ci.draw_arc(h, 92.0 * k, PI * 0.62, PI * 1.08, 16, Palette.INK, 3.0, true)
	ci.draw_arc(h, 92.0 * k, PI * 1.22, PI * 2.36, 30, Palette.INK, 3.0, true)
	ci.draw_circle(h + Vector2(-52, -14) * k, 7.0 * k, Palette.INK)
	ci.draw_arc(h + Vector2(-56, 40) * k, 14.0 * k, 0.4, PI - 0.6, 8, Palette.INK, 3.0, true)
	# the outer ear and the canal's mouth
	var ear := _oval(e + jv + Vector2(6, -4) * k, 20.0 * k, 32.0 * k, 20)
	ci.draw_colored_polygon(ear, Palette.SKIN.darkened(0.08))
	ci.draw_polyline(_ring(ear), Palette.INK, 3.0, true)
	ci.draw_arc(e + jv + Vector2(8, -6) * k, 12.0 * k, -PI * 0.6, PI * 0.5, 10, Color(Palette.INK, 0.5), 2.0, true)
	ci.draw_circle(e + jv, 6.0 * k, Color("#5a2f2f"))


## Where the bridge hand sits: on the head, above and behind the ear.
const BRIDGE_AT := Vector2(4, -80)


## The bridge hand: on the head above and behind the ear (its arm off the top), its thumb lifting the
## outer ear.
static func _bridge_hand(ci: CanvasItem, he: Vector2, k: float) -> void:
	var p := he + BRIDGE_AT * k
	ci.draw_line(p + Vector2(18, -14) * k, p + Vector2(74, -116) * k, Palette.INK, 30.0 * k, true)
	ci.draw_line(p + Vector2(18, -14) * k, p + Vector2(74, -116) * k, SHIRT.lightened(0.2), 24.0 * k, true)
	UiDraw.rounded_rect(ci, Rect2(p - Vector2(30, 18) * k, Vector2(62, 38) * k), HAND, int(14 * k), 3, Palette.INK)
	ci.draw_line(p + Vector2(-8, 16) * k, he + Vector2(2, -36) * k, Palette.INK, 10.0 * k, true)
	ci.draw_line(p + Vector2(-8, 16) * k, he + Vector2(2, -36) * k, HAND, 6.0 * k, true)


## Where the instrument hand's finger rests: the bridge hand, or (handle down) the head behind the ear,
## or (a straight tool) the head just behind the top of the ear.
static func _brace_point(he: Vector2, k: float, tool: String) -> Vector2:
	match tool:
		"oto_down":
			return he + Vector2(26, 34) * k
		"earlight", "syringe":
			return he + Vector2(34, -28) * k
	return he + (BRIDGE_AT + Vector2(32, 6)) * k


## The tool, its tip at the ear's mouth, pointing left into it.
static func _tool(ci: CanvasItem, tip: Vector2, k: float, tool: String, tilted: bool) -> void:
	var rot := -0.3 if tilted else 0.0
	var p := func(v: Vector2) -> Vector2: return tip + (v * k).rotated(rot)
	match tool:
		"oto_up", "oto_down":
			var up := -1.0 if tool == "oto_up" else 1.0
			_poly(ci, PackedVector2Array([p.call(Vector2(0, -4)), p.call(Vector2(40, -10)), p.call(Vector2(40, 10)), p.call(Vector2(0, 4))]), Palette.INK)
			_poly(ci, PackedVector2Array([p.call(Vector2(40, -16)), p.call(Vector2(78, -16)), p.call(Vector2(78, 16)), p.call(Vector2(40, 16))]), METAL)
			_poly(ci, PackedVector2Array([p.call(Vector2(50, 16 * up)), p.call(Vector2(68, 16 * up)), p.call(Vector2(68, 96 * up)), p.call(Vector2(50, 96 * up))]), Color("#3b3f52"))
		"earlight":
			ci.draw_line(p.call(Vector2(0, 0)), p.call(Vector2(36, 0)), Palette.INK, 5.0 * k, true)
			ci.draw_circle(tip, 6.0 * k, Color(Palette.SUNNY, 0.6))
			_poly(ci, PackedVector2Array([p.call(Vector2(36, -10)), p.call(Vector2(120, -10)), p.call(Vector2(120, 10)), p.call(Vector2(36, 10))]), Color("#ffb347"))
		_:
			_poly(ci, PackedVector2Array([p.call(Vector2(0, -3)), p.call(Vector2(26, -10)), p.call(Vector2(26, 10)), p.call(Vector2(0, 3))]), CLEAR)
			_poly(ci, PackedVector2Array([p.call(Vector2(26, -14)), p.call(Vector2(104, -14)), p.call(Vector2(104, 14)), p.call(Vector2(26, 14))]), CLEAR)
			_poly(ci, PackedVector2Array([p.call(Vector2(32, -8)), p.call(Vector2(70, -8)), p.call(Vector2(70, 8)), p.call(Vector2(32, 8))]), Color(Palette.SELECT_ORANGE, 0.8))
			ci.draw_line(p.call(Vector2(104, 0)), p.call(Vector2(130, 0)), Palette.INK, 5.0 * k, true)
			ci.draw_line(p.call(Vector2(130, -14)), p.call(Vector2(130, 14)), Palette.INK, 5.0 * k, true)


## Where the instrument hand holds the tool.
static func _hold_point(tip: Vector2, k: float, tool: String, tilted: bool) -> Vector2:
	if tilted:
		return tip + (Vector2(126, 0) * k).rotated(-0.3) if tool == "earlight" or tool == "syringe" else tip + (Vector2(60, -90) * k).rotated(-0.3)
	match tool:
		"oto_up":
			return tip + Vector2(59, -62) * k
		"oto_down":
			return tip + Vector2(59, 62) * k
	return tip + Vector2(66, 0) * k


## A red cartoon OW! burst.
static func _ow(ci: CanvasItem, c: Vector2, k: float) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var r := (34.0 if i % 2 == 0 else 20.0) * k
		pts.append(c + Vector2.from_angle(TAU * i / 16.0) * r)
	ci.draw_colored_polygon(pts, Palette.SUNNY)
	ci.draw_polyline(_ring(pts), RED, 3.0, true)
	ci.draw_string(UiKit.font(700), c + Vector2(-30, 7) * k, "OW!", HORIZONTAL_ALIGNMENT_CENTER, 60.0 * k, int(20 * k), RED)


## "Which grip is safe?": four panels. After the answer (or an unsafe pick) the heads start sneezing.
static func _grips(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	var grips: Array = card["grips"]
	var w := (size.x - 36 - 3 * 14) / 4.0
	var st := t - float(card.get("sneeze_at", INF))
	var j := sneeze(st)
	ci.draw_string(UiKit.font(700), Vector2(0, 92), PracticalDeck.TOOL_WORDS.get(String(card["tool"]), ""), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Palette.INK_SOFT)
	for i in grips.size():
		var r := Rect2(18 + i * (w + 14), 100, w, 306)
		var safe := String(grips[i]) == "safe"
		var bg := Palette.PAPER
		if reveal and safe:
			bg = Color(GREEN, 0.15)
		elif wrong.has(i):
			bg = Color(RED, 0.15)
		UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.18), 20)
		UiDraw.rounded_rect(ci, r, bg, 20, 3, Palette.INK)
		var wob := 0.0 if Game.settings.get("reduced_motion", false) or bool(PracticalDeck.GRIPS[String(grips[i])]["braced"]) else sin(t * 9.0 + i) * 2.0
		draw_grip(ci, r.position + Vector2(w * 0.55, 150), 0.68, String(card["tool"]), String(grips[i]), j, wob)
		UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(10, 10), Vector2(34, 34)), Palette.SUNNY, 9, 3, Palette.INK)
		ci.draw_string(UiKit.font(700), r.position + Vector2(10, 35), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Palette.INK)
		if reveal and safe:
			_stamp(ci, r.position + Vector2(w * 0.5, 276), "SAFE", GREEN, -0.08)
		elif wrong.has(i) or (reveal and not safe):
			_stamp(ci, r.position + Vector2(w * 0.5, 276), "STOP", RED, 0.06)


## "Ready to go in?": one big grip; the sneeze plays once it is judged.
static func _brace(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	var r := Rect2(18, 84, 470, 322)
	UiDraw.rounded_rect(ci, Rect2(r.position + Vector2(0, 6), r.size), Color(0, 0, 0, 0.18), 22)
	UiDraw.rounded_rect(ci, r, Palette.PAPER, 22, 3, Palette.INK)
	var grip := String(card["grip"])
	var st := t - float(card.get("sneeze_at", INF))
	var j := sneeze(st)
	var wob := 0.0 if Game.settings.get("reduced_motion", false) or grip == "safe" else sin(t * 9.0) * 2.5
	draw_grip(ci, r.position + Vector2(270, 150), 0.86, String(card["tool"]), grip, j, wob)
	if j > 0.15:
		ci.draw_string(UiKit.font(700), r.position + Vector2(24, 60), "ACHOO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, RED)
	var side := Rect2(508, 84, size.x - 526, 322)
	UiDraw.rounded_rect(ci, side, Color("#e3f1ee"), 22, 3, Palette.INK)
	_wrap(ci, String(PracticalDeck.TOOL_WORDS.get(String(card["tool"]), "")), Rect2(side.position + Vector2(22, 14), Vector2(side.size.x - 44, 40)), 24, Palette.INK)
	_wrap(ci, "Your hands are set. The subject might sneeze. Safe to go in?", Rect2(side.position + Vector2(22, 70), Vector2(side.size.x - 44, 140)), 22, Palette.INK)
	var safe := grip == "safe"
	if reveal:
		_stamp(ci, side.position + Vector2(side.size.x * 0.5, 262), "MOVES WITH THE HEAD" if safe else "STOP: UNSAFE", GREEN if safe else RED, -0.06)
	elif not wrong.is_empty():
		_stamp(ci, side.position + Vector2(side.size.x * 0.5, 262), "STOP: UNSAFE" if wrong.has(0) else "IT WAS FINE", RED if wrong.has(0) else GREY, 0.05)


# ---------------------------------------------------------------- Station 2: wash and look

static func _wash(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	# the hygiene chip: a gel bottle and a speculum
	var chip := Rect2(36, 96, 240, 300)
	UiDraw.rounded_rect(ci, chip, Color("#d9dce4"), 26, 3, Palette.INK)
	var c := chip.position + Vector2(84, 150)
	_box(ci, Rect2(c + Vector2(-34, -40), Vector2(68, 110)), Color("#bfe6ff"))
	_box(ci, Rect2(c + Vector2(-12, -64), Vector2(24, 26)), Palette.INK_SOFT)
	ci.draw_line(c + Vector2(0, -64), c + Vector2(26, -74), Palette.INK, 5.0, true)
	ci.draw_string(UiKit.font(700), c + Vector2(-34, 18), "GEL", HORIZONTAL_ALIGNMENT_CENTER, 68, 20, Palette.INK)
	var sp := chip.position + Vector2(176, 110)
	_poly(ci, PackedVector2Array([sp + Vector2(-8, -40), sp + Vector2(8, -40), sp + Vector2(22, 40), sp + Vector2(-22, 40)]), Palette.INK_SOFT)
	ci.draw_string(UiKit.font(700), chip.position + Vector2(0, 280), "HYGIENE", HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 22, Palette.INK)
	var paper := Rect2(300, 96, size.x - 336, 300)
	UiDraw.rounded_rect(ci, Rect2(paper.position + Vector2(0, 6), paper.size), Color(0, 0, 0, 0.18), 22)
	UiDraw.rounded_rect(ci, paper, Palette.PAPER, 22, 3, Palette.INK)
	_wrap(ci, String(card["ask"]), Rect2(paper.position + Vector2(28, 26), Vector2(paper.size.x - 56, 180)), 30, Palette.INK)
	if reveal:
		_stamp(ci, paper.position + Vector2(paper.size.x * 0.5, 250), "CLEAN", GREEN, -0.07)
	elif not wrong.is_empty():
		_germ(ci, paper.position + Vector2(paper.size.x - 90, 236), t)
		_stamp(ci, paper.position + Vector2(paper.size.x * 0.4, 250), "GERMS!", Color("#4f9a3a"), 0.06)


## A cartoon germ, wiggling.
static func _germ(ci: CanvasItem, c: Vector2, t: float) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2.from_angle(a) * (30.0 + 5.0 * sin(a * 5.0 + t * 4.0)))
	ci.draw_colored_polygon(pts, Color("#8fd16a"))
	ci.draw_polyline(_ring(pts), Palette.INK, 3.0, true)
	for s: float in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(s * 10, -6), 6.0, Palette.PAPER)
		ci.draw_circle(c + Vector2(s * 10, -5), 3.0, Palette.INK)
	ci.draw_arc(c + Vector2(0, 8), 10.0, 0.2, PI - 0.2, 8, Palette.INK, 3.0, true)


static func _look(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, t: float) -> void:
	var ear := String(card["ear"])
	var col: Color = Palette.RIGHT_RED if ear == "right" else Palette.LEFT_BLUE
	var vr := Rect2(54, 92, 300, 300)
	ArcadeArt.oto_view(ci, vr, {"view": StringName(card["view"]), "lookalike": bool(card["lookalike"]), "variant": 1}, ear, t)
	if bool(card["sore"]):
		ci.draw_arc(vr.get_center(), vr.size.x * 0.36, 0.0, TAU, 40, Color(RED, 0.4), vr.size.x * 0.12, true)
	_tag(ci, vr.position + Vector2(vr.size.x * 0.5, vr.size.y + 4), "RIGHT EAR" if ear == "right" else "LEFT EAR", col, 1.4)
	var paper := Rect2(392, 92, size.x - 410, 314)
	UiDraw.rounded_rect(ci, Rect2(paper.position + Vector2(0, 6), paper.size), Color(0, 0, 0, 0.18), 22)
	UiDraw.rounded_rect(ci, paper, Palette.PAPER, 22, 3, Palette.INK)
	ci.draw_string(UiKit.font(700), paper.position + Vector2(24, 40), "Intake card", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, TEAL)
	ci.draw_line(paper.position + Vector2(24, 52), paper.position + Vector2(paper.size.x - 24, 52), Color(TEAL, 0.5), 2.0)
	_wrap(ci, "\"%s\"" % String(card["note"]) if not String(card["note"]).begins_with("You see") else String(card["note"]),
		Rect2(paper.position + Vector2(24, 64), Vector2(paper.size.x - 48, 160)), 26, Palette.INK)
	if reveal:
		var flag := int(card["flag"])
		var line := "Not on the list: go ahead" if flag == 0 else "On the list, %d: %s" % [flag, PracticalDeck.REFER_8[flag - 1]]
		var chip := Rect2(paper.position + Vector2(16, 240), Vector2(paper.size.x - 32, 56))
		UiDraw.rounded_rect(ci, chip, GREEN if flag == 0 else RED, 14, 3, Palette.INK)
		_wrap(ci, line, Rect2(chip.position + Vector2(12, 4), chip.size - Vector2(24, 8)), 18, Palette.PAPER)


# ---------------------------------------------------------------- Station 4: Too loud?

const GOLD := Color("#f2b632")
## What you'd see of each seat from the desk (a description, drawn under the chair).
const SEAT_LOOKS: Dictionary = {"face": "side-on to you", "back": "back to you", "wall": "facing the wall", "far": "behind the post"}


## The booth from above: the audiometer desk (YOU) at the bottom, four chairs; each subject's head shows
## a face (toward you, side-on), hair (back to you), or sits behind the window post.
static func _seats(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	var room := Rect2(30, 84, size.x - 60, 330)
	UiDraw.rounded_rect(ci, room, Color("#efe6d2"), 22, 3, Palette.INK)
	# the booth window and its post
	ci.draw_line(Vector2(room.position.x + 20, 314), Vector2(room.end.x - 20, 314), Color("#9ad0ec"), 10.0, true)
	ci.draw_line(Vector2(room.position.x + 20, 314), Vector2(room.end.x - 20, 314), Palette.INK, 2.0, true)
	# the desk and you
	var desk := Rect2(Vector2(size.x * 0.5 - 150, 340), Vector2(300, 56))
	_box(ci, desk, Color("#c9a77c"))
	_box(ci, Rect2(desk.position + Vector2(100, 8), Vector2(100, 40)), Color("#e8e2d6"))
	ci.draw_string(UiKit.font(700), desk.position + Vector2(0, 40), "YOU", HORIZONTAL_ALIGNMENT_LEFT, 90, 22, Palette.INK)
	var seats: Array = card["seats"]
	for i in seats.size():
		var c := Vector2(150 + i * 194, 186)
		var id := String(seats[i])
		var hl := Palette.PAPER
		if reveal and id == "face":
			hl = Color(GREEN, 0.3)
		elif wrong.has(i):
			hl = Color(RED, 0.2)
		ci.draw_circle(c, 70.0, hl)
		ci.draw_arc(c, 70.0, 0.0, TAU, 32, Color(Palette.INK, 0.4), 2.0, true)
		# which way they face: toward the desk (down-right, side-on), away (up), the wall (sideways out)
		var dir := Vector2(0.55, 0.85).normalized()
		match id:
			"back":
				dir = Vector2(0, -1)
			"wall":
				dir = Vector2(-1, 0) if i < 2 else Vector2(1, 0)
			"far":
				dir = Vector2(0.3, 0.95).normalized()
		# where they look: a soft cone
		var cone := PackedVector2Array([c + dir * 20, c + dir.rotated(0.45) * 92, c + dir.rotated(-0.45) * 92])
		ci.draw_colored_polygon(cone, Color(Palette.SUNNY, 0.45))
		_chair(ci, c, dir)
		if id == "far":
			ci.draw_rect(Rect2(c + Vector2(-16, 24), Vector2(34, 60)), Color("#7d8398"))   # the window post in the way
			ci.draw_rect(Rect2(c + Vector2(-16, 24), Vector2(34, 60)), Palette.INK, false, 2.0)
		ci.draw_string(UiKit.font(700), c + Vector2(-90, 96), String(SEAT_LOOKS[id]), HORIZONTAL_ALIGNMENT_CENTER, 180, 16, Palette.INK)
		UiDraw.rounded_rect(ci, Rect2(c + Vector2(-60, -96), Vector2(34, 34)), Palette.SUNNY, 9, 3, Palette.INK)
		ci.draw_string(UiKit.font(700), c + Vector2(-60, -71), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Palette.INK)
		if reveal and id == "face":
			_stamp(ci, c + Vector2(0, -78), "FACE IN VIEW", GREEN, -0.06)


## A chair seen from above with its sitter facing dir: the seat, the back rest behind them, the head (a
## face drawn toward dir).
static func _chair(ci: CanvasItem, c: Vector2, dir: Vector2) -> void:
	var side := dir.orthogonal()
	var seat := PackedVector2Array([c + (dir + side) * 34, c + (dir - side) * 34, c + (-dir - side) * 34, c + (-dir + side) * 34])
	_poly(ci, seat, Color("#c9a77c"))
	ci.draw_line(c - dir * 36 + side * 38, c - dir * 36 - side * 38, Palette.INK, 14.0, true)
	ci.draw_line(c - dir * 36 + side * 36, c - dir * 36 - side * 36, Color("#6b4a2f"), 10.0, true)
	ci.draw_circle(c, 24.0, HAIR)
	ci.draw_circle(c + dir * 6, 19.0, Palette.SKIN)
	ci.draw_arc(c, 24.0, 0.0, TAU, 24, Palette.INK, 2.5, true)
	for s: float in [-1.0, 1.0]:
		ci.draw_circle(c + dir * 14 + side * 7 * s, 3.0, Palette.INK)
	ci.draw_circle(c + dir * 24, 4.0, Palette.SKIN.darkened(0.15))


## "Which pitch first?": the chart's top row with the tested pitches dotted, then the four choices.
static func _order(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array) -> void:
	var r := Rect2(40, 92, size.x - 80, 150)
	UiDraw.rounded_rect(ci, r, Palette.PAPER, 18, 3, Palette.INK)
	ci.draw_string(UiKit.font(700), r.position + Vector2(18, 30), "Tested on this chart:", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Palette.INK)
	var all: Array = PracticalDeck.TD_FREQ_POOL
	var tested: Array = card["tested"]
	for i in all.size():
		var x := r.position.x + 70 + i * (r.size.x - 140) / (all.size() - 1)
		var f := int(all[i])
		var on := tested.has(f)
		ci.draw_line(Vector2(x, r.position.y + 54), Vector2(x, r.position.y + 104), Color(Palette.INK, 0.25), 2.0)
		if on:
			ci.draw_circle(Vector2(x, r.position.y + 80), 13.0, Palette.RIGHT_RED)
			ci.draw_arc(Vector2(x, r.position.y + 80), 13.0, 0.0, TAU, 18, Palette.INK, 2.0, true)
		else:
			ci.draw_string(UiKit.font(700), Vector2(x - 40, r.position.y + 88), "not tested", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Palette.INK_SOFT)
		ci.draw_string(UiKit.font(700), Vector2(x - 40, r.position.y + 132), "%dk" % (f / 1000) if f >= 1000 else str(f), HORIZONTAL_ALIGNMENT_CENTER, 80, 18, Palette.INK)
	var freqs: Array = card["freqs"]
	var w := (size.x - 80 - 3 * 14) / 4.0
	for i in freqs.size():
		var b := Rect2(40 + i * (w + 14), 262, w, 140)
		var right := reveal and i == int(card["answer"])
		UiDraw.rounded_rect(ci, b, Color(GREEN, 0.18) if right else (Color(RED, 0.15) if wrong.has(i) else Color("#fff4cf")), 18, 3, Palette.INK)
		UiDraw.rounded_rect(ci, Rect2(b.position + Vector2(10, 10), Vector2(34, 34)), Palette.SUNNY, 9, 3, Palette.INK)
		ci.draw_string(UiKit.font(700), b.position + Vector2(10, 35), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 34, 20, Palette.INK)
		ci.draw_string(UiKit.font(700), b.position + Vector2(0, 92), "%d Hz" % int(freqs[i]), HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 30, Palette.INK)
		if right:
			_stamp(ci, b.position + Vector2(b.size.x * 0.5, 122), "FIRST", GREEN, -0.06)
		elif wrong.has(i):
			_stamp(ci, b.position + Vector2(b.size.x * 0.5, 122), "NOT YET", GREY, 0.05)


## A TD rule: a gold ladder chip and the question.
static func _rule(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array) -> void:
	var chip := Rect2(36, 96, 240, 300)
	UiDraw.rounded_rect(ci, chip, Color("#fff1c2"), 26, 3, Palette.INK)
	var x0 := chip.position.x + 80
	for side: float in [0.0, 80.0]:
		ci.draw_line(Vector2(x0 + side, chip.position.y + 30), Vector2(x0 + side, chip.position.y + 240), Palette.INK, 6.0, true)
	for k in 6:
		var y := chip.position.y + 50 + k * 36
		ci.draw_line(Vector2(x0, y), Vector2(x0 + 80, y), GOLD.darkened(0.2), 5.0, true)
	ci.draw_string(UiKit.font(700), chip.position + Vector2(0, 280), "TD ROUTINE", HORIZONTAL_ALIGNMENT_CENTER, chip.size.x, 22, Palette.INK)
	var paper := Rect2(300, 96, size.x - 336, 300)
	UiDraw.rounded_rect(ci, Rect2(paper.position + Vector2(0, 6), paper.size), Color(0, 0, 0, 0.18), 22)
	UiDraw.rounded_rect(ci, paper, Palette.PAPER, 22, 3, Palette.INK)
	_wrap(ci, String(card["ask"]), Rect2(paper.position + Vector2(28, 26), Vector2(paper.size.x - 56, 180)), 30, Palette.INK)
	if reveal:
		_stamp(ci, paper.position + Vector2(paper.size.x * 0.5, 250), "BY THE ROUTINE", GREEN, -0.07)
	elif not wrong.is_empty():
		_stamp(ci, paper.position + Vector2(paper.size.x * 0.5, 250), "NOT QUITE", GREY, 0.06)


## The ladder walk: the subject's face (big, left) and the ladder from 70 to 110 with the live rung, the
## pairs already given, and a drawn pair of bursts (no sound).
static func _walk(ci: CanvasItem, size: Vector2, card: Dictionary, reveal: bool, wrong: Array, t: float) -> void:
	var step := int(card["step"])
	var levels: Array = card["levels"]
	var faces: Array = card["faces"]
	var face := String(faces[step])
	var db := int(levels[step])
	# the face, in a booth window
	var win := Rect2(24, 84, 420, 322)
	UiDraw.rounded_rect(ci, win, Color("#d8eef7"), 22, 3, Palette.INK)
	var since := t - float(card.get("rung_at", 0.0))
	_td_face(ci, win.position + Vector2(210, 176), face, bool(card["blink"]) and face == "finger", since)
	_headset(ci, win.position + Vector2(210, 150), 1.4, Palette.RIGHT_RED, Palette.LEFT_BLUE)
	# the pair of bursts just given, drawn
	var pk := clampf(since / 0.6, 0.0, 1.0)
	for b in 2:
		var bx := win.position.x + 30 + b * 60
		for k in 6:
			var x := bx + k * 7
			var hgt := 18.0 * sin(PI * k / 5.0) * (1.0 if pk > 0.3 + b * 0.3 else 0.3)
			ci.draw_line(Vector2(x, win.position.y + 40 - hgt), Vector2(x, win.position.y + 40 + hgt), GOLD.darkened(0.2), 3.0, true)
	ci.draw_string(UiKit.font(700), win.position + Vector2(20, 300), "%d dB" % db, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.INK)
	# the ladder
	var lad := Rect2(470, 84, size.x - 488, 322)
	UiDraw.rounded_rect(ci, lad, Palette.PAPER, 22, 3, Palette.INK)
	var top_db := PracticalDeck.TD_LIMIT_DB
	var rungs := (top_db - PracticalDeck.TD_START_DB) / PracticalDeck.TD_STEP_DB + 1
	var y_of := func(d: int) -> float: return lad.end.y - 30 - (d - PracticalDeck.TD_START_DB) / float(PracticalDeck.TD_STEP_DB) * (lad.size.y - 60) / (rungs - 1)
	var lx := lad.position.x + 150
	ci.draw_line(Vector2(lx, lad.position.y + 20), Vector2(lx, lad.end.y - 20), Palette.INK, 4.0, true)
	ci.draw_line(Vector2(lx + 120, lad.position.y + 20), Vector2(lx + 120, lad.end.y - 20), Palette.INK, 4.0, true)
	for k in rungs:
		var d := PracticalDeck.TD_START_DB + k * PracticalDeck.TD_STEP_DB
		var y: float = y_of.call(d)
		var given := k <= step
		ci.draw_line(Vector2(lx, y), Vector2(lx + 120, y), GOLD if given else Color(Palette.INK, 0.25), 5.0 if given else 3.0, true)
		ci.draw_string(UiKit.font(700), Vector2(lad.position.x + 20, y + 7), "%d" % d, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Palette.INK if given else Palette.INK_SOFT)
		if given and k < faces.size():
			var f := String(faces[k])
			var tag: String = {"calm": "", "frown": "frown", "finger": "finger", "hand": "HAND"}[f]
			if tag != "":
				ci.draw_string(UiKit.font(700), Vector2(lx + 130, y + 6), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, RED if f == "hand" else Palette.INK)
	var ly: float = y_of.call(db)
	ci.draw_circle(Vector2(lx + 60, ly), 12.0, Palette.CORAL)
	ci.draw_arc(Vector2(lx + 60, ly), 12.0, 0.0, TAU, 16, Palette.INK, 2.5, true)
	if reveal:
		var td := int(card["td"])
		if td > 0:
			_stamp(ci, Vector2(lx + 60, ly - 34), "TD %d" % td, GREEN, -0.06)
		else:
			ci.draw_line(Vector2(lx + 60, ly - 50), Vector2(lx + 60, ly + 4), RED, 4.0, true)
			ci.draw_line(Vector2(lx + 60, ly + 4), Vector2(lx + 50, ly - 8), RED, 4.0, true)
			ci.draw_line(Vector2(lx + 60, ly + 4), Vector2(lx + 70, ly - 8), RED, 4.0, true)
			_stamp(ci, Vector2(lx + 60, ly + 40), "TD: no hand", RED, 0.05)
	elif not wrong.is_empty():
		_stamp(ci, lad.get_center() + Vector2(0, 40), "EXAMINER: NO", RED, 0.06)


## The TD subject's face, big: calm, a frown, a raised finger (annoying), the whole hand (stop); blink:
## a hard blink and a flinch (a reflex to watch for).
static func _td_face(ci: CanvasItem, c: Vector2, face: String, blink: bool, since: float) -> void:
	ci.draw_circle(c + Vector2(0, -10), 98.0, Color("#5a3a22"))
	ci.draw_circle(c, 86.0, Palette.SKIN)
	ci.draw_arc(c, 86.0, 0.0, TAU, 40, Palette.INK, 4.0, true)
	var shut := blink and fmod(since, 1.6) < 0.25
	for s: float in [-1.0, 1.0]:
		var e := c + Vector2(s * 30, -14)
		if shut:
			ci.draw_line(e - Vector2(12, 0), e + Vector2(12, 0), Palette.INK, 4.0, true)
		else:
			ci.draw_circle(e, 9.0, Palette.INK)
		if face != "calm":
			var tilt := 6.0 if face == "frown" else 10.0
			ci.draw_line(e + Vector2(-14, -22 + (tilt if s > 0 else 0.0)), e + Vector2(14, -22 + (0.0 if s > 0 else tilt)), Palette.INK, 4.0, true)
	match face:
		"calm":
			ci.draw_arc(c + Vector2(0, 26), 24.0, 0.3, PI - 0.3, 12, Palette.INK, 4.0, true)
		"frown", "finger":
			ci.draw_line(c + Vector2(-20, 40), c + Vector2(20, 40), Palette.INK, 4.0, true)
		"hand":
			ci.draw_arc(c + Vector2(0, 52), 22.0, PI + 0.3, TAU - 0.3, 12, Palette.INK, 4.0, true)
	if face == "finger":
		var h := c + Vector2(118, 40)
		UiDraw.rounded_rect(ci, Rect2(h + Vector2(-18, -8), Vector2(36, 40)), Palette.SKIN, 10, 3, Palette.INK)
		UiDraw.rounded_rect(ci, Rect2(h + Vector2(-6, -52), Vector2(12, 48)), Palette.SKIN, 6, 3, Palette.INK)
	elif face == "hand":
		var h := c + Vector2(122, -10)
		UiDraw.rounded_rect(ci, Rect2(h + Vector2(-26, 0), Vector2(52, 48)), Palette.SKIN, 12, 3, Palette.INK)
		for k in 4:
			UiDraw.rounded_rect(ci, Rect2(h + Vector2(-24 + k * 13, -40), Vector2(11, 44)), Palette.SKIN, 5, 2, Palette.INK)
	if blink and face == "finger":
		ci.draw_string(UiKit.font(700), c + Vector2(-130, -96), "blink!", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, RED)


# ---------------------------------------------------------------- helpers

static func _oval(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func _ring(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o


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
