extends Control
## MarcoDinner (Day 5): the payoff at Trattoria Clatter (docs/CHAPTER5.md §7.3). A 2D diorama
## drawn in code, captioned "Saturday, 9 pm": the full dining room, the SNR-O-Meter pinned at LOUD,
## Marco in the corner booth with his back to the room, his daughter Rosa across from him, the
## bright front half of his pizza on her. Grey chatter bubbles everywhere; hers stays crisp.
## cheer(): the room applauds, confetti (none with reduced motion). tray_crash(): a waiter's tray
## falls behind him, CRASH, drawn small and dim ("just a little"). write_review(): his notebook page.
## Story-internal:
##   var d := MarcoDinner.new(); hud.add_game(d)
##   await d.open(); d.cheer(); d.tray_crash(); await d.write_review(); await d.fade_out()
## No input and no beats of its own: the level's dialogue carries the scene. The room's noise is
## drawn, never played; the Sfx are the shared quiet ones.

const UiKit := preload("res://story/ui_kit.gd")
const Portraits := preload("res://story/portraits.gd")

const CAPTION := "Saturday, 9 pm"
const REVIEW := "BOOTH CAMP. Service: precise. Owl: wise, slightly smug."
const ROOM := Rect2(40, 100, 1200, 436)
const MARCO_AT := Vector2(470, 330)
const ROSA_AT := Vector2(810, 330)
const PORTRAIT_R := 82.0
const METER := Rect2(1010, 116, 210, 118)
const NOTEBOOK := Rect2(390, 150, 500, 300)
## The room's chatter (drawn, grey): text and where its bubble sits.
const CHATTER: Array = [["HAHA", Vector2(120, 170)], ["clink", Vector2(250, 250)], ["BIRTHDAY!", Vector2(150, 420)],
	["more wine?", Vector2(300, 480)], ["...and then", Vector2(1000, 300)], ["ha-ha!", Vector2(1120, 420)],
	["clatter", Vector2(990, 480)], ["no WAY", Vector2(640, 140)]]
const DINERS: Array[Vector2] = [Vector2(90, 230), Vector2(200, 320), Vector2(110, 360), Vector2(260, 400), Vector2(1080, 360),
	Vector2(1180, 300), Vector2(1150, 480), Vector2(1040, 430)]
const CONFETTI_N := 60

var _t := 0.0
var _cheer_t := -1.0
var _crash_t := -1.0
var _review_t := -1.0
var _art: Control
var _fx: Control
var _seed := 5


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = Color("#3b2a3f", 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_art = UiKit.full_rect()
	_art.name = "Art"
	_art.draw.connect(_draw_art)
	add_child(_art)
	var cap := UiKit.label(CAPTION, 30, Palette.PAPER, 700, 8, Color(Palette.INK, 0.8))
	cap.position = Vector2(64, 50)
	add_child(cap)
	_fx = UiKit.full_rect()
	_fx.name = "Fx"
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	modulate.a = 0.0


## (coroutine) The diorama fades in.
func open() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.4)
	Sfx.play(&"door", 1.0, -14.0)
	await t.finished
	await _wait(0.3)


## The room applauds: CLAP bubbles and confetti (no confetti with reduced motion).
func cheer() -> void:
	_cheer_t = 0.0
	Sfx.play(&"fanfare", 1.0, -12.0)


## A waiter drops a tray behind Marco: CRASH, drawn small and dim.
func tray_crash() -> void:
	_crash_t = 0.0
	Sfx.play(&"thunk", 0.6, -14.0)


## (coroutine) Marco's notebook page: the review writes itself, then stays a moment.
func write_review() -> void:
	_review_t = 0.0
	Sfx.play(&"pen", 1.0, -10.0)
	await _wait(0.4 if _reduced() else 2.2)


## (coroutine) Fade the whole diorama away.
func fade_out() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.35)
	await t.finished


func _process(delta: float) -> void:
	_t += delta
	for v: String in ["_cheer_t", "_crash_t", "_review_t"]:
		var x: float = get(v)
		if x >= 0.0:
			set(v, x + delta)
	_art.queue_redraw()
	_fx.queue_redraw()


func _draw_art() -> void:
	var a := _art
	# the dining room: warm floor, a striped wall, lamps
	UiDraw.rounded_rect(a, ROOM, Color("#f7d9b0"), 18, 5, Color("#8a5a24"))
	for k in 12:
		a.draw_rect(Rect2(ROOM.position.x + 8.0 + k * 100.0, ROOM.position.y + 8.0, 50.0, 80.0), Color("#efc994"))
	for k in 5:
		var lamp := Vector2(160.0 + k * 240.0, ROOM.position.y + 18.0)
		a.draw_circle(lamp, 12.0, Color("#ffd966"))
		a.draw_circle(lamp, 26.0, Color("#ffd966", 0.18))
	# the busy room: grey diners and their chatter
	for d: Vector2 in DINERS:
		a.draw_circle(d, 28.0, Color("#b3abc2"))
		a.draw_circle(d + Vector2(0, -36), 18.0, Color("#cfc8db"))
	var f := UiKit.font(700)
	for c: Array in CHATTER:
		_bubble(a, f, String(c[0]), c[1] as Vector2, Color("#9aa0b0"), Color("#e9e6ef"), 16)
	# the corner booth: its bench, the table, the pizza's bright front half from Marco toward Rosa
	UiDraw.rounded_rect(a, Rect2(360, 220, 560, 270), Color("#b5652a"), 26, 4, Color("#6e3c16"))
	UiDraw.rounded_rect(a, Rect2(560, 300, 160, 140), Color("#fbf1dc"), 14, 3, Color("#8a5a24"))
	var wedge := PackedVector2Array([MARCO_AT])
	for j in 21:
		wedge.append(MARCO_AT + Vector2.from_angle(-0.45 + 0.9 * j / 20.0) * 350.0)
	a.draw_colored_polygon(wedge, Color("#ffd23f", 0.3))
	var dim := PackedVector2Array([MARCO_AT])
	for j in 21:
		dim.append(MARCO_AT + Vector2.from_angle(PI * 0.5 + PI * j / 20.0) * 140.0)
	a.draw_colored_polygon(dim, Color("#2e2442", 0.12))
	# tiramisu on the table, then the people
	a.draw_rect(Rect2(610, 350, 60, 34), Color("#c99a6b"))
	a.draw_rect(Rect2(610, 350, 60, 10), Color("#6e4a2e"))
	Portraits.draw(a, "Marco", MARCO_AT, PORTRAIT_R, fmod(_t, 0.5) < 0.25 and _cheer_t >= 0.0 and _cheer_t < 2.0, false)
	Portraits.draw(a, "Rosa", ROSA_AT, PORTRAIT_R, false, false)
	# Rosa's bubble stays crisp, the room's are grey
	_bubble(a, f, "We're getting married!", ROSA_AT + Vector2(10, -128), Palette.INK, Palette.PAPER, 20)
	_draw_meter(a, f)
	if _cheer_t >= 0.0:
		_bubble(a, f, "CLAP CLAP", Vector2(200, 160), Color("#2f9e73"), Palette.PAPER, 18)
		_bubble(a, f, "BRAVA!", Vector2(1100, 250), Color("#2f9e73"), Palette.PAPER, 18)


## The SNR-O-Meter, pinned at LOUD.
func _draw_meter(a: Control, f: Font) -> void:
	UiDraw.rounded_rect(a, METER, Palette.LCD_BG, 14, 3, Palette.INK)
	var c := Vector2(METER.get_center().x, METER.end.y - 22.0)
	var r := 70.0
	var bands := [Color("#5bc8a3"), Color("#ffd23f"), Color("#ff9f1c"), Color("#ff6f59")]
	for k in 4:
		a.draw_arc(c, r, PI + PI * k / 4.0, PI + PI * (k + 1) / 4.0, 12, bands[k] as Color, 10.0)
	var jiggle := 0.0 if _reduced() else sin(_t * 9.0) * 0.03
	var ang := PI + PI * 0.92 + jiggle
	a.draw_line(c, c + Vector2.from_angle(ang) * (r - 6.0), Palette.LCD_TEXT, 4.0)
	a.draw_circle(c, 6.0, Palette.LCD_TEXT)
	a.draw_string(f, Vector2(METER.position.x + 12.0, METER.position.y + 24.0), "SNR-O-METER", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.LCD_TEXT)
	a.draw_string(f, Vector2(METER.end.x - 64.0, METER.end.y - 10.0), "LOUD", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#ff6f59"))


func _bubble(a: Control, f: Font, text: String, at: Vector2, ink: Color, fill: Color, size: int) -> void:
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var r := Rect2(at - Vector2(tw * 0.5 + 12.0, size * 0.9), Vector2(tw + 24.0, size * 1.7))
	UiDraw.rounded_rect(a, r, fill, 12, 2, ink)
	a.draw_colored_polygon(PackedVector2Array([r.position + Vector2(r.size.x * 0.4, r.size.y), r.position + Vector2(r.size.x * 0.5, r.size.y),
		r.position + Vector2(r.size.x * 0.42, r.size.y + 10.0)]), ink)
	a.draw_string(f, Vector2(r.position.x + 12.0, r.position.y + size * 1.25), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


func _draw_fx() -> void:
	var f := UiKit.font(700)
	if _cheer_t >= 0.0 and not _reduced() and _cheer_t < 4.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		var cols := [Palette.SUNNY, Palette.MINT, Palette.CORAL, Palette.SKY, Palette.PLUM]
		for k in CONFETTI_N:
			var x := rng.randf_range(ROOM.position.x, ROOM.end.x)
			var speed := rng.randf_range(120.0, 220.0)
			var y := ROOM.position.y - 20.0 + _cheer_t * speed + rng.randf_range(-60.0, 0.0)
			if y > ROOM.end.y:
				continue
			var w := sin(_cheer_t * 3.0 + k) * 10.0
			_fx.draw_rect(Rect2(Vector2(x + w, y), Vector2(8, 5)), cols[k % cols.size()] as Color)
	if _crash_t >= 0.0 and _crash_t < 3.0:
		# behind Marco (the room side, dimmed by his mics): small and pale
		var at := MARCO_AT + Vector2(-150, -155)
		var a := clampf(1.0 - _crash_t / 3.0, 0.0, 1.0) * 0.75
		_fx.draw_circle(at + Vector2(0, 10), 26.0, Color("#c0c4cf", a))
		_fx.draw_string(f, at + Vector2(-34, -14), "crash", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Palette.INK, a))
	if _review_t >= 0.0:
		var k := 1.0 if _reduced() else clampf(_review_t / 1.6, 0.0, 1.0)
		var page := NOTEBOOK
		UiDraw.rounded_rect(_fx, page.grow(6), Color(Palette.INK, 0.25), 10, 0)
		UiDraw.rounded_rect(_fx, page, Color("#fffdf6"), 8, 3, Palette.INK)
		for row in 7:
			var y := page.position.y + 70.0 + row * 32.0
			_fx.draw_line(Vector2(page.position.x + 20, y), Vector2(page.end.x - 20, y), Color("#9fb6d9", 0.5), 1.0)
		_fx.draw_line(Vector2(page.position.x + 56, page.position.y + 10), Vector2(page.position.x + 56, page.end.y - 10), Color("#e5383b", 0.4), 2.0)
		_fx.draw_string(f, page.position + Vector2(70, 46), "TABLE TALK . M. POLENTA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.INK_SOFT)
		var shown := REVIEW.substr(0, int(REVIEW.length() * k))
		var words := shown.split(". ")
		var y0 := page.position.y + 96.0
		for i in words.size():
			var text := words[i] + ("." if i < words.size() - 1 else "")
			_fx.draw_string(UiKit.font(600), Vector2(page.position.x + 70, y0 + i * 32.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#1f2f5c"))


static func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _wait(s: float) -> void:
	await get_tree().create_timer(s, false).timeout
