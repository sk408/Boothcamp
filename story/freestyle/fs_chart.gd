extends Control
## FsChart (freestyle, story-internal): the visit's audiogram on a card above the tray, so the player
## can read it while choosing the next tool, the type of loss and the call. Every stamp the player
## (or Hoot) made: air, bone, masked bone and masked air (Audiogram, CONTRACTS.md §4.6).
##   var chart := FsChart.new(); hud.add_game(chart)
##   chart.show_chart("PENNY'S CHART", results)      # draws instantly; animate = true stamps them in
##   await chart.slam("REFER", true)                  # the call's rubber stamp lands on the chart
##   chart.hide_chart()
## Anchor: "freestyle_chart".

const UiKit := preload("res://story/ui_kit.gd")
const AUDIOGRAM_SCENE := "res://ui/audiogram/audiogram.tscn"

const CARD_POS := Vector2(300, 76)
const CHART_SIZE := Vector2(930, 372)

var ag: Control
var _card: PanelContainer
var _title: Label
var _empty: Label
var _stamp_text := ""
var _stamp_right := true
var _stamp_k := 0.0
var _fx: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_card = UiKit.panel(Color(Palette.PAPER, 0.97), Palette.INK, 22)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.position = CARD_POS
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	_title = UiKit.label("", 17, Palette.INK_SOFT, 700)
	v.add_child(_title)
	if ResourceLoader.exists(AUDIOGRAM_SCENE):
		ag = (load(AUDIOGRAM_SCENE) as PackedScene).instantiate() as Control
		ag.set("ear", "both")
		ag.set("show_notes", true)   # (E18) transducer, mastoids, reliability under the chart
		ag.set("true_aspect", true)  # (E12) one octave as wide as 20 dB is tall
		ag.custom_minimum_size = CHART_SIZE
		ag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(ag)
	_empty = UiKit.label("No tones tested yet.", 20, Palette.INK_SOFT, 600)
	_empty.position = Vector2(CHART_SIZE.x * 0.5 - 90.0, CHART_SIZE.y * 0.5)
	_empty.visible = false
	_card.add_child.call_deferred(_empty)
	_fx = UiKit.full_rect()
	_fx.draw.connect(_draw_stamp)
	add_child(_fx)
	Hoot.register_anchor("freestyle_chart", _card)


func _exit_tree() -> void:
	Hoot.unregister_anchor("freestyle_chart")


func _process(delta: float) -> void:
	if _stamp_text != "" and _stamp_k < 1.0:
		_stamp_k = minf(1.0, _stamp_k + delta / 0.22)
		_fx.queue_redraw()


func show_chart(title: String, results: Dictionary, animate: bool = false) -> void:
	_title.text = title
	var was := visible
	visible = true
	if ag != null:
		ag.call("show_results", results, animate)
	_empty.visible = ((results.get("ears", {}) as Dictionary)).is_empty()
	if not was:
		Juice.bounce_in(_card, 0.35)


func hide_chart() -> void:
	visible = false
	_stamp_text = ""
	_fx.queue_redraw()


func is_shown() -> bool:
	return visible


## (coroutine) A rubber stamp slams onto the chart: right = the chosen call (coral ink), else a
## grey "try again" stamp that fades.
func slam(text: String, right: bool) -> void:
	_stamp_text = text
	_stamp_right = right
	_stamp_k = 0.0
	await get_tree().create_timer(0.22, false).timeout
	Sfx.play(&"stamp", 0.9 if right else 1.2)
	Events.screen_shake.emit(0.25 if right else 0.12, 0.15)
	await get_tree().create_timer(0.5 if right else 0.7, false).timeout
	if not right:
		_stamp_text = ""
		_fx.queue_redraw()


func _draw_stamp() -> void:
	if _stamp_text == "":
		return
	var f := UiKit.font(700)
	var fs := 64
	var w := f.get_string_size(_stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var center := _card.position + _card.size * 0.5 + Vector2(120, 20)
	var s := lerpf(2.4, 1.0, _stamp_k)
	var ink := Palette.CORAL.darkened(0.1) if _stamp_right else Color(Palette.INK_SOFT, 0.8)
	_fx.draw_set_transform(center, -0.16, Vector2(s, s))
	var r := Rect2(Vector2(-w * 0.5 - 22.0, -52.0), Vector2(w + 44.0, 84.0))
	UiDraw.rounded_rect(_fx, r, Color(Palette.PAPER, 0.55 * _stamp_k), 12, 7, Color(ink, _stamp_k))
	_fx.draw_string(f, Vector2(-w * 0.5, 12.0), _stamp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(ink, _stamp_k))
	_fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
