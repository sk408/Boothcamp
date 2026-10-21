class_name SpSnrMeter
extends Control
## SpSnrMeter: the SNR-O-METER (ui/speech only; CONTRACTS.md §9.18.1, docs/CHAPTER5.md §5.2), in the
## agreement meter's slot. A fixed mint TALKER bar and a grey PARTY bar that rises one step per
## sentence (the six course levels are ticked beside it), with the gap bracketed between their tops:
## "SNR 25 dB" down to "0 dB!", where the bars meet. The levels are drawn, never played loud.

## dB below the talker the scale starts (the party bar's floor), and above it the scale ends.
const SPAN_BELOW := 32.0
const SPAN_ABOVE := 6.0

var talker_db := 70
## The gap for the sentence playing (or the next one).
var snr := 25
## true while a sentence plays: the bars glow.
var live := false
var _party_shown := -1.0     ## the party bar's drawn level (it glides up)
var _meet := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_view(d: Dictionary) -> void:
	talker_db = int(d.get("talker_db", talker_db))
	var was := snr
	snr = int(d.get("snr", snr))
	live = bool(d.get("live", live))
	if snr == 0 and was != 0 and not _reduced():
		_meet = 1.0
	queue_redraw()


## A new list: the party bar jumps (no glide) to the first course.
func reset() -> void:
	_party_shown = -1.0
	_meet = 0.0
	queue_redraw()


func party_db() -> int:
	return talker_db - snr


func _reduced() -> bool:
	return bool(Game.settings.get("reduced_motion", false))


func _process(delta: float) -> void:
	_t += delta
	var target := float(party_db())
	if _party_shown < 0.0 or _reduced():
		_party_shown = target
	else:
		_party_shown = move_toward(_party_shown, target, delta * 30.0)
	_meet = maxf(0.0, _meet - delta * 1.5)
	queue_redraw()


func _level_y(db: float, track: Rect2) -> float:
	var lo := talker_db - SPAN_BELOW
	var hi := talker_db + SPAN_ABOVE
	return track.end.y - clampf((db - lo) / (hi - lo), 0.0, 1.0) * track.size.y


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	AoDraw.card(self, r, Color("#3b3154"), 16)
	AoDraw.text_c(self, Vector2(r.size.x * 0.5, 15), "SNR-O-METER", 12, Color(Palette.SUNNY, 0.85), AoDraw.FONT_BOLD)
	var track := Rect2(Vector2(14.0, 34.0), Vector2(r.size.x - 28.0, maxf(30.0, r.size.y - 34.0 - 44.0)))
	AoDraw.rbox(self, track.grow(4.0), Palette.LCD_BG, 10)
	var bw := clampf(track.size.x * 0.26, 18.0, 40.0)
	var tx := track.position.x + track.size.x * 0.22
	var px := track.position.x + track.size.x * 0.66
	var base := track.end.y
	var ty := _level_y(talker_db, track)
	var py := _level_y(_party_shown if _party_shown >= 0.0 else party_db(), track)
	var glow := 0.5 + 0.5 * sin(_t * 6.0) if live else 0.0
	# the course levels beside the party bar (25 .. 0 below the talker)
	for s: int in SpeechRules.SIN_SNRS:
		var y := _level_y(talker_db - s, track)
		var on := s == snr
		draw_line(Vector2(px + bw * 0.5 + 3.0, y), Vector2(px + bw * 0.5 + 9.0, y), Color(Palette.LCD_TEXT, 0.8 if on else 0.3), 2.0)
	# TALKER: fixed, mint
	if glow > 0.0:
		AoDraw.rbox(self, Rect2(Vector2(tx - bw * 0.5 - 4.0, ty - 4.0), Vector2(bw + 8.0, base - ty + 4.0)), Color(Palette.MINT, 0.25 * glow), 8)
	AoDraw.rbox(self, Rect2(Vector2(tx - bw * 0.5, ty), Vector2(bw, base - ty)), Palette.MINT, 6, 2, Palette.INK)
	# PARTY: grey, rising
	var shake := sin(_t * 40.0) * 3.0 * _meet
	AoDraw.rbox(self, Rect2(Vector2(px - bw * 0.5 + shake, py), Vector2(bw, base - py)), Color("#a9a3b6"), 6, 2, Palette.INK)
	# the bracket between the tops
	var bx := (tx + px) * 0.5
	var zero := snr <= 0
	var col := Palette.CORAL if zero else Palette.SUNNY
	if not zero:
		draw_line(Vector2(tx + bw * 0.5 + 2.0, ty), Vector2(bx + 6.0, ty), Color(col, 0.8), 2.0)
		draw_line(Vector2(bx + 6.0, py), Vector2(px - bw * 0.5 - 2.0, py), Color(col, 0.8), 2.0)
		draw_line(Vector2(bx, ty), Vector2(bx, py), col, 3.0)
		draw_line(Vector2(bx - 5.0, ty), Vector2(bx + 5.0, ty), col, 3.0)
		draw_line(Vector2(bx - 5.0, py), Vector2(bx + 5.0, py), col, 3.0)
	else:
		draw_line(Vector2(tx, ty - 6.0), Vector2(px, ty - 6.0), col, 3.0)
	var label := "0 dB!" if zero else "SNR %d dB" % snr
	var lw := AoDraw.text_size(label, 14, AoDraw.FONT_BOLD).x + 12.0
	var ly := ty - 14.0 if zero else clampf((ty + py) * 0.5, track.position.y + 12.0, track.end.y - 12.0)
	var lr := Rect2(Vector2(clampf(bx - lw * 0.5, 4.0, r.size.x - lw - 4.0), ly - 10.0), Vector2(lw, 20.0))
	AoDraw.rbox(self, lr, col, 9, 2, Palette.INK)
	AoDraw.text_c(self, lr.get_center(), label, 14, Palette.INK, AoDraw.FONT_BOLD)
	# names and levels under the bars
	var ny := r.size.y - 30.0
	AoDraw.text_c(self, Vector2(tx, ny), "TALKER", 11, Palette.MINT.lightened(0.2), AoDraw.FONT_BOLD)
	AoDraw.text_c(self, Vector2(tx, ny + 15.0), "%d" % talker_db, 15, Palette.LCD_TEXT, AoDraw.FONT_BOLD)
	AoDraw.text_c(self, Vector2(px, ny), "PARTY", 11, Color("#c9c4d6"), AoDraw.FONT_BOLD)
	AoDraw.text_c(self, Vector2(px, ny + 15.0), "%d" % party_db(), 15, Palette.LCD_TEXT, AoDraw.FONT_BOLD)
