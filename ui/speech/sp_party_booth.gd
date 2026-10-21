class_name SpPartyBooth
extends Control
## SpPartyBooth: the PARTY mode's overlay on the booth window (ui/speech only; CONTRACTS.md §9.18.1,
## docs/CHAPTER5.md §5.1-§5.2). It sits exactly over the AoBoothWindow and draws on its glass:
##  - unaided: the BOTH EARS chip (ink, never an ear colour) and the talk waves into both ears, with
##    the party's grey clatter around him while the babble plays;
##  - aided (the sound field): the TALKER speaker in front of him and the PARTY speaker behind; with
##    FOCUS (only once the reveal names it) the front half of the room is drawn bright and the back
##    half dimmed, never removed, and both halves are labelled FRONT and BACK (colour is never the
##    only cue). Everything is drawn; nothing here plays.

var aided := false
## Earphones, inserts or the sound field ("phones", "inserts", "soundfield").
var transducer := "phones"
## FOCUS is on and the player knows it (after the reveal): the halves.
var focus_on := false
## The party babble is playing (or would be: Hoot's x8 turn keeps it silent, the clatter still shows).
var babble := false
var _booth: WeakRef = null
var _glow := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## The booth window this overlay covers (its glass and its talk glow).
func follow(booth: AoBoothWindow) -> void:
	_booth = weakref(booth) if booth != null else null


func _the_booth() -> AoBoothWindow:
	return _booth.get_ref() as AoBoothWindow if _booth != null else null


func _process(delta: float) -> void:
	_t += delta
	var b := _the_booth()
	_glow = b.tone_glow if b != null else 0.0
	queue_redraw()


func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _glass() -> Rect2:
	var b := _the_booth()
	return b.glass_rect() if b != null else Rect2(Vector2(12, 12), size - Vector2(24, 24))


func _draw() -> void:
	var g := _glass()
	if aided:
		_draw_soundfield(g)
	else:
		_draw_both(g)


## Unaided: the same mix into both ears.
func _draw_both(g: Rect2) -> void:
	var label := "BOTH EARS . %s" % ("INSERTS" if transducer == "inserts" else ("SPEAKERS" if transducer == "soundfield" else "PHONES"))
	var lw := AoDraw.text_size(label, 12, AoDraw.FONT_BOLD).x + 18.0
	var chip := Rect2(Vector2(g.position.x + 8.0, g.end.y - 30.0), Vector2(lw, 22.0))
	AoDraw.rbox(self, chip, Palette.BOTH_INK, 11, 2, Palette.PAPER)
	AoDraw.text_c(self, chip.get_center(), label, 12, Palette.PAPER, AoDraw.FONT_BOLD)
	# the talker's waves on his right ear too (the window draws the left of the picture's two)
	if _glow > 0.0:
		var c := Vector2(g.position.x + g.size.x * 0.22, g.position.y + g.size.y * 0.42)
		for i in 3:
			var k := fmod(_t * 1.6 + i / 3.0, 1.0)
			var rr := 10.0 + 34.0 * k
			draw_arc(c, rr, PI - 0.7, PI + 0.7, 16, Color(Palette.PAPER, _glow * (1.0 - k)), 6.0, true)
			draw_arc(c, rr, PI - 0.7, PI + 0.7, 16, Color(Palette.BOTH_INK, _glow * (1.0 - k)), 3.0, true)
	if babble:
		_draw_clatter(Vector2(g.get_center().x, g.position.y + g.size.y * 0.3), g.size.x * 0.42)


## Aided: two speakers, the voice in front and the party behind.
func _draw_soundfield(g: Rect2) -> void:
	var front := Rect2(Vector2(g.position.x, g.position.y + g.size.y * 0.5), Vector2(g.size.x, g.size.y * 0.5))
	var back := Rect2(g.position, Vector2(g.size.x, g.size.y * 0.5))
	if focus_on:
		AoDraw.rbox(self, back, Color(Palette.INK, 0.38), 12)
		AoDraw.rbox(self, front, Color(Palette.SUNNY, 0.12), 12)
		draw_line(Vector2(g.position.x + 6.0, front.position.y), Vector2(g.end.x - 6.0, front.position.y), Color(Palette.PAPER, 0.7), 2.0)
		AoDraw.text_l(self, Vector2(g.position.x + 10.0, back.position.y + 44.0), "BACK", 12, Palette.PAPER, AoDraw.FONT_BOLD, 4, Palette.INK)
		AoDraw.text_l(self, Vector2(g.position.x + 10.0, front.position.y + 14.0), "FRONT", 12, Palette.PAPER, AoDraw.FONT_BOLD, 4, Palette.INK)
	# the party speaker behind him (small: it is further back), clear of the window's own sound
	# waves on the right of the glass
	var pc := Vector2(g.get_center().x + g.size.x * 0.04, g.position.y + 30.0)
	if babble:
		_draw_clatter(pc + Vector2(0, 6), 46.0)   # under the speaker, so its label stays readable
	_draw_speaker(pc, 0.7, "PARTY", Color("#a9a3b6"))
	# the talker speaker in front of him
	var tc := Vector2(g.get_center().x - g.size.x * 0.12, g.end.y - 26.0)
	_draw_speaker(tc, 1.0, "TALKER", Palette.MINT)
	if _glow > 0.0:
		for i in 3:
			var k := fmod(_t * 1.6 + i / 3.0, 1.0)
			var rr := 14.0 + 30.0 * k
			draw_arc(tc + Vector2(0, -10), rr, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 14, Color(Palette.PAPER, _glow * (1.0 - k)), 5.0, true)
			draw_arc(tc + Vector2(0, -10), rr, -PI * 0.5 - 0.6, -PI * 0.5 + 0.6, 14, Color(Palette.MINT.darkened(0.2), _glow * (1.0 - k)), 2.5, true)


func _draw_speaker(c: Vector2, k: float, label: String, col: Color) -> void:
	var box := Rect2(c - Vector2(16, 18) * k, Vector2(32, 36) * k)
	AoDraw.rbox(self, Rect2(box.position + Vector2(0, 3), box.size), Color(Palette.INK, 0.3), int(7 * k))
	AoDraw.rbox(self, box, Palette.LCD_BG, int(7 * k), 2, Palette.INK)
	draw_circle(c + Vector2(0, 4) * k, 9.0 * k, col)
	draw_circle(c + Vector2(0, 4) * k, 4.0 * k, Palette.INK)
	draw_circle(c + Vector2(0, -10) * k, 3.5 * k, Color(col, 0.8))
	AoDraw.text_l(self, Vector2(box.end.x + 5.0, c.y), label, int(12 * k + 1), Palette.PAPER, AoDraw.FONT_BOLD, 4, Palette.INK)


## Grey clatter squiggles around a point (still with reduced motion).
func _draw_clatter(c: Vector2, spread: float) -> void:
	var still := _reduced()
	for i in 6:
		var a := TAU * i / 6.0 + (0.0 if still else _t * 0.6)
		var at := c + Vector2(cos(a) * spread, sin(a) * spread * 0.35)
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(at + Vector2(j * 5.0 - 7.5, (3.0 if j % 2 == 0 else -3.0) + (0.0 if still else sin(_t * 9.0 + i + j) * 1.5)))
		draw_polyline(pts, Color(Palette.PAPER, 0.7), 4.0, true)
		draw_polyline(pts, Color("#8d869c"), 2.0, true)
