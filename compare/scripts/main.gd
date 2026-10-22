extends Control
## Hearing Aid Finder: the whole page, built in code from data/*.json in the game's look.
## Home (Hoot's welcome, needs, the five aid cards that open in place, side by side by topic, sources), Hoot's
## five questions one at a time, the shortlist, and the 3D view. Sized in real phone pixels, with a text-size control.

const Data := preload("res://scripts/data.gd")
const Ui := preload("res://scripts/ui.gd")
const Icon := preload("res://scripts/icon.gd")
const Hoot := preload("res://scripts/hoot.gd")
const Sketch := preload("res://scripts/sketch.gd")
const Turntable := preload("res://scripts/turntable.gd")
const AidModel := preload("res://scripts/aid_model.gd")

const SETTINGS := "user://compare.cfg"
const TEXT_SCALES := [1.0, 1.2, 1.45]
const STYLE_CAPTIONS := {
	"ric": "Sits behind the ear. A thin wire takes the sound into your ear.",
	"bte": "A little bigger behind the ear, with a clear sound tube.",
	"itc": "Made from a mould of your ear. Sits in the bowl of the ear.",
	"cic": "Tiny and made from a mould of your ear. Hidden in the canal.",
}
const STATUS_WORDS := {
	"verified": "The maker or Costco says so",
	"reported": "Review sites say so",
	"unverified": "Not found yet: ask at the warehouse",
}

var data := Data.new()
var full := false           # false = Plain words, true = Full specs
var only_diff := false
var wanted: Array = []      # need ids
var selected: Array = []    # aid ids in the side-by-side
var expanded := ""          # the aid card that is open
var quiz_answers: Array = []  # per question: the picked answer index, or -1
var text_scale_i := 0
var W := 1280.0             # logical page width

var _scroll: ScrollContainer
var _page: VBoxContainer
var _margin: MarginContainer
var _overlay: Control
var _bucket := -1
var _anchors := {}          # name -> Control, for scrolling to a section
var _press_at := Vector2.ZERO


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Ui.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	if not data.load_all():
		add_child(Ui.wrap("Could not load the data files:\n" + "\n".join(data.errors)))
		return
	for a in data.aids:
		selected.append(a.id)
	for q in data.quiz:
		quiz_answers.append(-1)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		text_scale_i = clampi(int(cfg.get_value("view", "text_scale", 0)), 0, TEXT_SCALES.size() - 1)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.scroll_deadzone = 8
	add_child(_scroll)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_margin)
	get_viewport().size_changed.connect(_fit)
	_fit()


## Real page width: the window in device pixels over the screen's pixel ratio and the chosen text size.
func _fit() -> void:
	var win := get_window()
	var factor: float = maxf(1.0, DisplayServer.screen_get_scale()) * TEXT_SCALES[text_scale_i]
	if OS.get_cmdline_user_args().has("--dpr=3"):
		factor = 3.0 * TEXT_SCALES[text_scale_i]
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	win.content_scale_size = Vector2i(maxi(320, int(win.size.x / factor)), maxi(320, int(win.size.y / factor)))
	W = win.size.x / factor
	var side: float = (8.0 if W < 360 else 14.0) if W < 640 else maxf(24.0, (W - 1180.0) * 0.5)
	_margin.add_theme_constant_override("margin_left", int(side))
	_margin.add_theme_constant_override("margin_right", int(side))
	_margin.add_theme_constant_override("margin_top", 16 if W < 640 else 28)
	_margin.add_theme_constant_override("margin_bottom", 48)
	var bucket := 0 if W < 640 else (1 if W < 980 else 2)
	if bucket != _bucket:
		_bucket = bucket
		_rebuild()


func narrow() -> bool:
	return W < 640


## Very small: a phone with the biggest text size.
func tiny() -> bool:
	return W < 360


func _rebuild(keep_scroll: bool = true) -> void:
	var at := _scroll.scroll_vertical
	if _page:
		_page.queue_free()
	_anchors.clear()
	_page = Ui.vbox(26)
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_margin.add_child(_page)
	_build_header()
	_build_hoot()
	_build_needs()
	_build_aids()
	_build_compare()
	_build_footer()
	if keep_scroll:
		_restore_scroll.call_deferred(at)


func _restore_scroll(at: int) -> void:
	await get_tree().process_frame
	_scroll.scroll_vertical = at


func _scroll_to(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var c: Control = _anchors.get(name)
	if c:
		_scroll.scroll_vertical = int(c.global_position.y - _page.global_position.y) + _margin.get_theme_constant("margin_top") - 8


# ---------------------------------------------------------------- header, Hoot, needs

func _build_header() -> void:
	var band := Ui.card(Ui.INK, Ui.INK, 26, 18 if narrow() else 22)
	_page.add_child(band)
	var box: BoxContainer = Ui.vbox(8) if narrow() else Ui.hbox(16)
	band.add_child(box)
	var titles := Ui.vbox(4)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(titles)
	var t := Ui.wrap(String(data.meta.get("title", "Hearing Aid Finder")).to_upper(), Ui.H1 if not narrow() else 30, Ui.SUNNY, 700)
	titles.add_child(t)
	titles.add_child(Ui.wrap(data.meta.get("subtitle", ""), Ui.BODY, Ui.PAPER, 500))
	titles.add_child(Ui.wrap("Facts checked %s" % _date(data.meta.get("specs_as_of", "")), Ui.SMALL, Color("#cfc6e0"), 500))
	var size_box := Ui.vbox(6)
	size_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(size_box)
	size_box.add_child(Ui.label("Text size", Ui.SMALL, Color("#cfc6e0"), 600))
	var row := Ui.hbox(8)
	size_box.add_child(row)
	for i in TEXT_SCALES.size():
		var b := Ui.button(["A", "A+", "A++"][i], "chip", [18, 22, 26][i], 48)
		b.toggle_mode = true
		b.button_pressed = i == text_scale_i
		b.custom_minimum_size.x = 52
		b.pressed.connect(_set_text_scale.bind(i))
		row.add_child(b)


func _set_text_scale(i: int) -> void:
	text_scale_i = i
	var cfg := ConfigFile.new()
	cfg.set_value("view", "text_scale", i)
	cfg.save(SETTINGS)
	_bucket = -1
	_fit()
	_rebuild(false)


func _build_hoot() -> void:
	var card := Ui.card(Ui.PAPER, Ui.INK, 24, 18)
	_page.add_child(card)
	var box: BoxContainer = Ui.vbox(14) if narrow() else Ui.hbox(20)
	card.add_child(box)
	var top := Ui.hbox(14)
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(top)
	var hoot: Control = Hoot.new()
	hoot.custom_minimum_size = Vector2(92, 92) if narrow() else Vector2(124, 124)
	hoot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(hoot)
	var words := Ui.vbox(6)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(words)
	words.add_child(Ui.wrap("Hi, I'm Hoot!", Ui.H2, Ui.INK, 700))
	var done := _quiz_done()
	words.add_child(Ui.wrap(
		"Answer five easy questions and I'll show you which of these hearing aids fit your life." if not done
		else "Your answers are in. The hearing aids that fit you are first below.", Ui.BODY, Ui.INK, 500))
	var buttons := Ui.vbox(10)
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow() else Control.SIZE_SHRINK_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.custom_minimum_size.x = 0 if narrow() else 300
	box.add_child(buttons)
	var go := Ui.button("Help me choose" if not done else "See my shortlist", "main", Ui.H3, 62, true)
	go.pressed.connect(_open_quiz if not done else _open_results)
	buttons.add_child(go)
	var all := Ui.button("Show me all five", "plain", Ui.BODY, 54, true)
	all.pressed.connect(_scroll_to.bind("aids"))
	buttons.add_child(all)
	if done:
		var again := Ui.button("Start the questions again", "plain", Ui.BODY, 54, true)
		again.pressed.connect(_restart_quiz)
		buttons.add_child(again)


func _build_needs() -> void:
	var card := Ui.card(Color("#dff1ff"), Ui.INK, 24, 18)
	_page.add_child(card)
	_anchors["needs"] = card
	var v := Ui.vbox(10)
	card.add_child(v)
	var head := Ui.hbox(12)
	v.add_child(head)
	head.add_child(Icon.make("ear", Ui.INK, 34))
	head.add_child(Ui.wrap("What matters to you?", Ui.H3, Ui.INK, 700))
	v.add_child(Ui.wrap("Tap any that matter. Hearing aids that miss one move to the end of the list.", Ui.BODY, Ui.INK_SOFT))
	# Phones get one big toggle per line; wider screens a flow of chips.
	var f: Container = Ui.vbox(10) if narrow() else Ui.flow(10)
	v.add_child(f)
	for n in data.needs:
		if n.get("detail_only", false) and not full:
			continue
		var chip := Ui.button(n.label, "chip", Ui.BODY, 50, narrow())
		chip.toggle_mode = true
		chip.button_pressed = wanted.has(n.id)
		chip.toggled.connect(_toggle_need.bind(n.id))
		f.add_child(chip)
	if not wanted.is_empty():
		var clear := Ui.button("Clear all", "plain", Ui.BODY, 50)
		clear.pressed.connect(_set_needs.bind([]))
		f.add_child(clear)


func _toggle_need(on: bool, id: String) -> void:
	if on and not wanted.has(id):
		wanted.append(id)
	elif not on:
		wanted.erase(id)
	_rebuild()


func _set_needs(ids: Array) -> void:
	wanted = ids.duplicate()
	_rebuild()


# ---------------------------------------------------------------- the aid cards

func _build_aids() -> void:
	var head := Ui.vbox(4)
	_page.add_child(head)
	_anchors["aids"] = head
	head.add_child(Ui.wrap("The five hearing aids", Ui.H2, Ui.INK, 700))
	head.add_child(Ui.wrap("Tap a hearing aid to open everything about it.", Ui.BODY, Ui.INK_SOFT))
	var fits := []
	var misses := []
	for a in data.aids:
		(fits if data.missing_needs(a, wanted).is_empty() else misses).append(a)
	_card_rows(fits)
	if not misses.is_empty() and not wanted.is_empty():
		var h := Ui.vbox(4)
		_page.add_child(h)
		h.add_child(Ui.wrap("These miss something you asked for" if not fits.is_empty()
				else "None has everything you asked for. Here they all are:", Ui.H3, Ui.INK, 700))
		_card_rows(misses)


func _cols() -> int:
	return 1 if W < 640 else (2 if W < 980 else 3)


## Cards in rows; an open card's details open full width right under its row.
func _card_rows(aids: Array) -> void:
	var cols := _cols()
	var i := 0
	while i < aids.size():
		var row := Ui.hbox(18)
		_page.add_child(row)
		var open_here: Dictionary = {}
		for k in cols:
			if i + k < aids.size():
				var a: Dictionary = aids[i + k]
				row.add_child(_aid_card(a))
				if a.id == expanded:
					open_here = a
			else:
				var spacer := Control.new()
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(spacer)
		if not open_here.is_empty():
			var det := _aid_details(open_here)
			_anchors["details"] = det
			_page.add_child(det)
		i += cols


func _aid_color(a: Dictionary) -> Color:
	return Color(String(a.get("color", "#2a62c9")))


func _aid_card(a: Dictionary) -> Control:
	var col := _aid_color(a)
	var card := Ui.card(col, Ui.INK, 24, 12)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_card_input.bind(a.id))
	_anchors["aid_" + a.id] = card
	var v := Ui.vbox(10)
	card.add_child(v)
	# Name band.
	var band := Ui.card(Ui.INK, Ui.INK, 16, 12, 0)
	v.add_child(band)
	var bv := Ui.vbox(2)
	band.add_child(bv)
	bv.add_child(Ui.wrap(a.name, Ui.H3, Ui.SUNNY, 700))
	bv.add_child(Ui.wrap(str(data.cell(a, "maker").get("v", "")), Ui.SMALL, Color("#cfc6e0"), 500))
	# The picture on a paper inset.
	var inset := Ui.card(Ui.PAPER, Ui.INK, 18, 8, 0)
	v.add_child(inset)
	var iv := Ui.vbox(4)
	inset.add_child(iv)
	var styles: Array = a.model_styles
	var pics := Ui.hbox(4)
	pics.alignment = BoxContainer.ALIGNMENT_CENTER
	iv.add_child(pics)
	var main_h := 190.0 if narrow() else 200.0
	pics.add_child(_picture(styles[0], a.shell, main_h))
	if styles.size() > 1:
		var also := Ui.vbox(2)
		also.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for s in styles.slice(1):
			also.add_child(_picture(s, a.shell, main_h * 0.42))
		pics.add_child(also)
	iv.add_child(_center(Ui.wrap(STYLE_CAPTIONS.get(styles[0], ""), Ui.SMALL, Ui.INK_SOFT, 500)))
	if styles.size() > 1:
		var names := []
		for s in styles.slice(1):
			names.append(AidModel.STYLE_NAMES.get(s, s).split(" (")[0].to_lower())
		var also_tag := Ui.card(Ui.SUNNY_SOFT, Color.TRANSPARENT, 14, 8, 0)
		also_tag.add_child(_center(Ui.wrap("Also comes as " + " or ".join(names), Ui.SMALL, Ui.INK, 600)))
		iv.add_child(also_tag)
	# Price.
	var price: Dictionary = data.cell(a, "price_pair")
	var pr := Ui.hbox(8)
	v.add_child(pr)
	pr.add_child(Ui.label(price.v if price.v != "" else "Price not found", Ui.H2, Ui.PAPER, 700))
	var per := Ui.label("for two", Ui.BODY, Ui.PAPER, 500)
	per.size_flags_vertical = Control.SIZE_SHRINK_END
	pr.add_child(per)
	# What it is good for.
	for g in a.get("good_for", []):
		var line := Ui.hbox(8)
		line.add_child(Icon.make("check", Ui.PAPER, 22))
		line.add_child(Ui.wrap(g, Ui.BODY, Ui.PAPER, 500))
		v.add_child(line)
	if not wanted.is_empty():
		var miss := data.missing_needs(a, wanted)
		if miss.is_empty():
			v.add_child(Ui.pill("Has everything you asked for", Ui.MINT_SOFT, Ui.GOOD, Ui.SMALL))
		else:
			var names2 := []
			for m in miss:
				names2.append(data.need_label(m).to_lower())
			var p := Ui.card(Ui.SUNNY_SOFT, Color.TRANSPARENT, 12, 8, 0)
			p.add_child(Ui.wrap("Missing: " + ", ".join(names2), Ui.SMALL, Ui.INK, 600))
			v.add_child(p)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(spacer)
	var foot: BoxContainer = Ui.vbox(10) if tiny() else Ui.hbox(10)
	v.add_child(foot)
	var open: bool = expanded == a.id
	var more := Ui.button("Hide details" if open else "See details", "main", Ui.BODY, 52)
	more.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	more.pressed.connect(_toggle_expand.bind(a.id))
	foot.add_child(more)
	var cmp := Ui.button("Compare", "chip", Ui.BODY, 52)
	cmp.toggle_mode = true
	cmp.button_pressed = selected.has(a.id)
	cmp.text = "In compare" if cmp.button_pressed else "Compare"
	cmp.toggled.connect(_toggle_selected.bind(a.id))
	foot.add_child(cmp)
	return card


func _card_input(event: InputEvent, aid_id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.global_position
		elif event.global_position.distance_to(_press_at) < 12.0:
			_toggle_expand(aid_id)


func _toggle_expand(aid_id: String) -> void:
	expanded = "" if expanded == aid_id else aid_id
	_rebuild()
	if expanded != "":
		# A phone shows one card per row, so jump to the details; wider pages keep the card's row in view.
		_scroll_to("details" if narrow() else "aid_" + expanded)


func _toggle_selected(on: bool, aid_id: String) -> void:
	if on and not selected.has(aid_id):
		selected.append(aid_id)
	elif not on:
		selected.erase(aid_id)
	var ordered := []
	for a in data.aids:
		if selected.has(a.id):
			ordered.append(a.id)
	selected = ordered
	_rebuild()


func _picture(style: String, shell: String, h: float) -> Control:
	var tr := TextureRect.new()
	var factor: float = get_window().size.x / maxf(W, 1.0)
	tr.texture = Sketch.texture("%s-%s" % [style, shell], h * factor)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(h * 280.0 / 380.0, h)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


func _center(c: Control) -> Control:
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if c is Label:
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		return c
	cc.add_child(c)
	return cc


# ---------------------------------------------------------------- one aid, opened

func _aid_details(a: Dictionary) -> Control:
	var col := _aid_color(a)
	var outer := Ui.card(col, Ui.INK, 26, 10)
	var v := Ui.vbox(14)
	outer.add_child(v)
	var head := Ui.hbox(12)
	v.add_child(head)
	var ht := Ui.wrap("All about the " + a.name, Ui.H2, Ui.PAPER, 700)
	head.add_child(ht)
	var close := Ui.button("Close", "plain", Ui.BODY, 50)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(_toggle_expand.bind(a.id))
	head.add_child(close)
	# At a glance: four big tiles.
	var tiles := GridContainer.new()
	tiles.columns = 1 if tiny() else (2 if narrow() else 4)
	tiles.add_theme_constant_override("h_separation", 10)
	tiles.add_theme_constant_override("v_separation", 10)
	v.add_child(tiles)
	var tele := str(data.cell(a, "telecoil").get("v", ""))
	var phone_ok := data.meets(a, "iphone") and data.meets(a, "android")
	for t in [
		["price", "Price for two", str(data.cell(a, "price_pair").get("v", "")), Color("#ffd23f")],
		["battery", "Battery", _short(str(data.cell(a, "battery_hours").get("v", ""))), Color("#7fdcb8")],
		["phone", "iPhone and Android", "Both" if phone_ok else Data.flag_text(str(data.cell(a, "iphone").get("v", ""))), Color("#9fd3ff")],
		["ear", "Hearing loops", Data.flag_text(tele), Color("#c9b3f0")],
	]:
		var tile := Ui.card(t[3], Ui.INK, 18, 12, 4)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tv := Ui.vbox(4)
		tile.add_child(tv)
		var th := Ui.hbox(8)
		th.add_child(Icon.make(t[0], Ui.INK, 26))
		th.add_child(Ui.wrap(t[1], Ui.SMALL, Ui.INK, 600))
		tv.add_child(th)
		tv.add_child(Ui.wrap(t[2] if t[2] != "" else "Not found", Ui.H3, Ui.INK, 700))
		tiles.add_child(tile)
	# Pictures of each style, and the 3D view.
	var pic_card := Ui.card(Ui.PAPER, Ui.INK, 20, 14, 0)
	v.add_child(pic_card)
	var pv := Ui.vbox(10)
	pic_card.add_child(pv)
	var pics := Ui.flow(16)
	pics.alignment = FlowContainer.ALIGNMENT_CENTER
	pv.add_child(pics)
	for s in a.model_styles:
		var one := Ui.vbox(4)
		one.custom_minimum_size.x = 200
		one.add_child(_center(_picture(s, a.shell, 230.0)))
		one.add_child(Ui.wrap(AidModel.STYLE_NAMES.get(s, s), Ui.BODY, Ui.INK, 700))
		one.add_child(Ui.wrap(STYLE_CAPTIONS.get(s, ""), Ui.SMALL, Ui.INK_SOFT))
		pics.add_child(one)
	var three := Ui.button("Turn it around in 3D", "dark", Ui.BODY, 54)
	three.pressed.connect(_open_viewer.bind(a.id))
	pv.add_child(three)
	pv.add_child(Ui.wrap(STYLE_LINE, Ui.SMALL, Ui.INK_SOFT))
	# Every topic, in its own coloured card.
	for g in data.groups:
		var rows := _rows_for(g.id)
		if rows.is_empty():
			continue
		var tc := _topic_card(g)
		v.add_child(tc[0])
		var body: VBoxContainer = tc[1]
		for r in rows:
			var line := Ui.vbox(4)
			body.add_child(line)
			var lh := Ui.vbox(2)
			line.add_child(lh)
			lh.add_child(Ui.wrap(r.label if full else r.plain, Ui.BODY, Ui.INK, 700))
			if not full:
				lh.add_child(Ui.wrap(r.get("help", ""), Ui.SMALL, Ui.INK_SOFT))
			line.add_child(_value_view(r, data.cell(a, r.id), true))
			body.add_child(_rule())
		body.get_child(body.get_child_count() - 1).queue_free()
	v.add_child(_sources_card(_aid_sources(a), "Where these facts come from"))
	var bottom := Ui.button("Close " + a.name, "plain", Ui.BODY, 54, true)
	bottom.pressed.connect(_toggle_expand.bind(a.id))
	v.add_child(bottom)
	return outer


const STYLE_LINE := "These are simple drawings of each style, not photos of the product."


func _short(s: String) -> String:
	var cut := s.find(";")
	return s if cut < 0 else s.substr(0, cut)


func _rows_for(group: String) -> Array:
	var out := []
	for r in data.rows:
		if r.group == group and (full or r.get("consumer", false)):
			out.append(r)
	return out


func _topic_card(g: Dictionary) -> Array:
	var col := Color(String(g.get("color", "#ffd23f")))
	var card := Ui.card(Ui.PAPER, Ui.INK, 20, 0, 4)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ui.vbox(0)
	card.add_child(v)
	var band := PanelContainer.new()
	var sb := Ui.style(col, Color.TRANSPARENT, 0, 0, 0, 14)
	sb.corner_radius_top_left = 17
	sb.corner_radius_top_right = 17
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	band.add_theme_stylebox_override("panel", sb)
	band.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(band)
	var bh := Ui.hbox(10)
	band.add_child(bh)
	bh.add_child(Icon.make(g.get("icon", "info"), Ui.INK, 30))
	bh.add_child(Ui.wrap(g.label, Ui.H3, Ui.INK, 700))
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(m)
	var body := Ui.vbox(10)
	m.add_child(body)
	return [card, body]


func _rule() -> Control:
	var r := ColorRect.new()
	r.color = Color(Ui.INK, 0.12)
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## One value: a yes / no pill for flags, words otherwise; in Full specs with its note, status and source numbers.
func _value_view(r: Dictionary, c: Dictionary, wide_text: bool) -> Control:
	var v := Ui.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var val := str(c.get("v", ""))
	if r.kind == "flag" or val == "":
		v.add_child(_flag_pill(val))
	else:
		v.add_child(Ui.wrap(val, Ui.H3 if r.kind == "price" else Ui.BODY, Ui.INK, 700 if r.kind == "price" else 500))
	var note := str(c.get("note", ""))
	if note != "" and (full or val == "some" or val == "later"):
		v.add_child(Ui.wrap(note, Ui.SMALL, Ui.INK_SOFT))
	if full:
		var st: String = c.get("status", "unverified")
		var marks := _src_marks(c.get("src", []))
		v.add_child(Ui.wrap(STATUS_WORDS.get(st, "") + ("  " + marks if marks != "" else ""), Ui.SMALL,
				Ui.GOOD if st == "verified" else Ui.INK_SOFT, 600))
	return v


func _flag_pill(val: String) -> Control:
	var bg := Ui.GREY_SOFT
	var fg := Ui.INK_SOFT
	var icon := "dash"
	var text := Data.flag_text(val)
	match val:
		"yes":
			bg = Ui.MINT_SOFT
			fg = Ui.GOOD
			icon = "check"
		"no":
			icon = "cross"
		"some", "later":
			bg = Ui.SUNNY_SOFT
			fg = Ui.WARN
			icon = "info"
		"":
			text = "Not found yet"
	var p := PanelContainer.new()
	var sb := Ui.style(bg, Color.TRANSPARENT, 16, 0, 0, 10)
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var h := Ui.hbox(6)
	p.add_child(h)
	h.add_child(Icon.make(icon, fg, 22))
	h.add_child(Ui.label(text, Ui.BODY, fg, 700))
	return p


# ---------------------------------------------------------------- side by side

func _build_compare() -> void:
	var head := Ui.vbox(6)
	_page.add_child(head)
	_anchors["compare"] = head
	head.add_child(Ui.wrap("Side by side", Ui.H2, Ui.INK, 700))
	head.add_child(Ui.wrap("Tap Compare on a card to add or remove it. Each topic has its own card.", Ui.BODY, Ui.INK_SOFT))
	var controls: Container = Ui.vbox(10) if narrow() else Ui.flow(10)
	_page.add_child(controls)
	for i in 2:
		var b := Ui.button(["Plain words", "Full specs (for engineers)"][i], "chip", Ui.BODY, 50, narrow())
		b.toggle_mode = true
		b.button_pressed = (i == 1) == full
		b.pressed.connect(_set_full.bind(i == 1))
		controls.add_child(b)
	var diff := Ui.button("Only where they differ", "chip", Ui.BODY, 50, narrow())
	diff.toggle_mode = true
	diff.button_pressed = only_diff
	diff.toggled.connect(func(on: bool) -> void:
		only_diff = on
		_rebuild())
	controls.add_child(diff)
	var aids := []
	for id in selected:
		aids.append(data.aid(id))
	if aids.size() < 2:
		var hint := Ui.card(Ui.PAPER, Ui.INK, 20, 18, 0)
		hint.add_child(Ui.wrap("Tap Compare on two or more hearing aids above to see them side by side here.", Ui.BODY))
		_page.add_child(hint)
		return
	# Who is in the comparison, in their colours.
	var who := Ui.flow(8)
	_page.add_child(who)
	for a in aids:
		who.add_child(Ui.pill(a.short, _aid_color(a), Ui.PAPER, Ui.BODY, 700))
	var shown := 0
	var wide := W >= 820
	for g in data.groups:
		var rows := []
		for r in _rows_for(g.id):
			if only_diff and not _differs(r.id, aids):
				continue
			rows.append(r)
		if rows.is_empty():
			continue
		var tc := _topic_card(g)
		_page.add_child(tc[0])
		var body: VBoxContainer = tc[1]
		if wide:
			body.add_child(_grid_head(aids))
		for r in rows:
			body.add_child(_compare_row(r, aids, wide))
			body.add_child(_rule())
			shown += 1
		body.get_child(body.get_child_count() - 1).queue_free()
	if shown == 0:
		var same := Ui.card(Ui.PAPER, Ui.INK, 20, 18, 0)
		same.add_child(Ui.wrap("These hearing aids match on everything shown.", Ui.BODY))
		_page.add_child(same)


func _set_full(on: bool) -> void:
	full = on
	_rebuild()


func _differs(field: String, aids: Array) -> bool:
	var first := ""
	for i in aids.size():
		var v := str(data.cell(aids[i], field).get("v", ""))
		if i == 0:
			first = v
		elif v != first:
			return true
	return false


func _grid_head(aids: Array) -> Control:
	var h := Ui.hbox(12)
	var lab := Control.new()
	lab.custom_minimum_size = Vector2(230, 0)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(lab)
	for a in aids:
		var p := Ui.pill(a.short, _aid_color(a), Ui.PAPER, Ui.SMALL, 700)
		var holder := Ui.hbox(0)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		holder.size_flags_stretch_ratio = 1.0
		holder.add_child(p)
		h.add_child(holder)
	return h


func _compare_row(r: Dictionary, aids: Array, wide: bool) -> Control:
	var label_box := Ui.vbox(2)
	label_box.add_child(Ui.wrap(r.label if full else r.plain, Ui.BODY, Ui.INK, 700))
	if not full:
		label_box.add_child(Ui.wrap(r.get("help", ""), Ui.SMALL, Ui.INK_SOFT))
	if wide:
		var h := Ui.hbox(12)
		label_box.custom_minimum_size = Vector2(230, 0)
		label_box.size_flags_horizontal = Control.SIZE_FILL
		h.add_child(label_box)
		for a in aids:
			var cell := _value_view(r, data.cell(a, r.id), false)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_stretch_ratio = 1.0
			h.add_child(cell)
		return h
	# Phones: the row's name, then one line per hearing aid with its colour tag.
	var v := Ui.vbox(8)
	v.add_child(label_box)
	for a in aids:
		var line: BoxContainer = Ui.vbox(4) if tiny() else Ui.hbox(10)
		var tag := Ui.pill(a.short, _aid_color(a), Ui.PAPER, Ui.SMALL, 700)
		tag.custom_minimum_size = Vector2(0 if tiny() else 118, 0)
		tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(tag)
		line.add_child(_value_view(r, data.cell(a, r.id), false))
		v.add_child(line)
	return v


# ---------------------------------------------------------------- footer and sources

func _build_footer() -> void:
	var care := Ui.card(Ui.MINT_SOFT, Ui.INK, 22, 18, 4)
	_page.add_child(care)
	var cv := Ui.vbox(8)
	care.add_child(cv)
	cv.add_child(Ui.wrap("What every Costco hearing aid includes", Ui.H3, Ui.INK, 700))
	cv.add_child(Ui.wrap(data.meta.get("care", ""), Ui.BODY))
	cv.add_child(Ui.wrap(data.prices_meta.get("note", ""), Ui.SMALL, Ui.INK_SOFT))
	_page.add_child(_sources_card(data.source_order, "All sources (%d)" % data.source_order.size()))
	_page.add_child(Ui.wrap(data.meta.get("disclaimer", ""), Ui.SMALL, Ui.INK_SOFT))


func _aid_sources(a: Dictionary) -> Array:
	var ids := []
	for f in a.specs:
		for s in a.specs[f].get("src", []):
			if not ids.has(s):
				ids.append(s)
	var p: Dictionary = data.prices.get(a.id, {})
	for k in p:
		for s in p[k].get("src", []):
			if not ids.has(s):
				ids.append(s)
	ids.sort_custom(func(x: String, y: String) -> bool: return data.source_order.find(x) < data.source_order.find(y))
	return ids


## A card with a "show" button that opens the numbered list of sources, each a link.
func _sources_card(ids: Array, title: String) -> Control:
	var card := Ui.card(Ui.PAPER, Ui.INK, 20, 14, 0)
	var v := Ui.vbox(8)
	card.add_child(v)
	var b := Ui.button(title + "  (show)", "plain", Ui.BODY, 50, true)
	v.add_child(b)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.visible = false
	rt.add_theme_font_override("normal_font", Ui.font(500))
	rt.add_theme_font_size_override("normal_font_size", Ui.SMALL)
	rt.add_theme_color_override("default_color", Ui.INK_SOFT)
	rt.mouse_filter = Control.MOUSE_FILTER_PASS
	rt.meta_clicked.connect(func(m: Variant) -> void: OS.shell_open(str(m)))
	var lines := PackedStringArray()
	for id in ids:
		if not data.sources.has(id):
			continue
		var s: Dictionary = data.sources[id]
		var kind: String = {"costco": "Costco", "maker": "Maker", "third": "Review site or price tracker"}.get(s.kind, s.kind)
		lines.append("[%d] [color=#2a62c9][url=%s]%s[/url][/color] (%s, read %s)" % [data.source_order.find(id) + 1, s.url, s.title, kind, s.read])
	rt.text = "\n".join(lines)
	v.add_child(rt)
	b.pressed.connect(func() -> void:
		rt.visible = not rt.visible
		b.text = title + ("  (hide)" if rt.visible else "  (show)"))
	return card


func _src_marks(ids: Array) -> String:
	var out := ""
	for id in ids:
		var n := data.source_order.find(id)
		if n >= 0:
			out += "[%d]" % (n + 1)
	return out


# ---------------------------------------------------------------- overlays: Hoot's questions, the shortlist, 3D

## A full-screen sheet over the page; returns its content box. Scrolls when it is taller than the screen.
func _open_sheet(max_w: float = 760.0, bg: Color = Ui.CREAM) -> VBoxContainer:
	_close_sheet()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(Ui.INK, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.scroll_deadzone = 8
	_overlay.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	var side: float = 10.0 if narrow() else maxf(16.0, (W - max_w) * 0.5)
	m.add_theme_constant_override("margin_left", int(side))
	m.add_theme_constant_override("margin_right", int(side))
	m.add_theme_constant_override("margin_top", 10 if narrow() else 32)
	m.add_theme_constant_override("margin_bottom", 32)
	sc.add_child(m)
	var panel := Ui.card(bg, Ui.INK, 26, 16 if narrow() else 24)
	m.add_child(panel)
	var v := Ui.vbox(14)
	panel.add_child(v)
	return v


func _close_sheet() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	if _overlay and event.is_action_pressed("ui_cancel"):
		_close_sheet()
		get_viewport().set_input_as_handled()


func _hoot_says(v: VBoxContainer, title: String, line: String) -> void:
	var h := Ui.hbox(14)
	v.add_child(h)
	var hoot: Control = Hoot.new()
	hoot.custom_minimum_size = Vector2(76, 76) if narrow() else Vector2(104, 104)
	hoot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(hoot)
	var words := Ui.vbox(4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(words)
	if title != "":
		words.add_child(Ui.wrap(title, Ui.BODY if narrow() else Ui.SMALL, Ui.INK_SOFT, 600))
	# On a phone the big line gets the whole width, under Hoot.
	(v if narrow() else words).add_child(Ui.wrap(line, Ui.H2, Ui.INK, 700))
	var x := Ui.button("Close", "plain", Ui.BODY, 50)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(_close_sheet)
	h.add_child(x)


func _quiz_done() -> bool:
	for a in quiz_answers:
		if a >= 0:
			return true
	return false


func _restart_quiz() -> void:
	for i in quiz_answers.size():
		quiz_answers[i] = -1
	_open_quiz(0)


func _open_quiz(step: int = 0) -> void:
	var q: Dictionary = data.quiz[step]
	var v := _open_sheet(720)
	_hoot_says(v, "Question %d of %d" % [step + 1, data.quiz.size()], q.q)
	# Progress dots.
	var dots := Ui.hbox(8)
	for i in data.quiz.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(28 if i == step else 14, 14)
		d.add_theme_stylebox_override("panel", Ui.style(Ui.SUNNY if i <= step else Ui.GREY_SOFT, Ui.INK, 7, 2, 0, 0))
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dots.add_child(d)
	v.add_child(dots)
	if q.get("help", "") != "":
		v.add_child(Ui.wrap(q.help, Ui.BODY, Ui.INK_SOFT))
	for i in q.answers.size():
		var ans: Dictionary = q.answers[i]
		var b := Ui.button(ans.label, "main" if quiz_answers[step] == i else "plain", Ui.H3, 66, true)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_answer.bind(step, i))
		v.add_child(b)
	var nav := Ui.hbox(10)
	v.add_child(nav)
	if step > 0:
		var back := Ui.button("Back", "plain", Ui.BODY, 54, true)
		back.pressed.connect(_open_quiz.bind(step - 1))
		nav.add_child(back)
	var skip := Ui.button("Skip this one", "plain", Ui.BODY, 54, true)
	skip.pressed.connect(_answer.bind(step, -1))
	nav.add_child(skip)


func _answer(step: int, i: int) -> void:
	quiz_answers[step] = i
	if step + 1 < data.quiz.size():
		_open_quiz(step + 1)
	else:
		_apply_quiz()
		_open_results()


func _apply_quiz() -> void:
	var ids := []
	for qi in data.quiz.size():
		var pick: int = quiz_answers[qi]
		if pick >= 0:
			for n in data.quiz[qi].answers[pick].needs:
				if not ids.has(n):
					ids.append(n)
	wanted = ids
	# The shortlist goes into the side-by-side.
	var fits := _fits()
	if fits.size() >= 2:
		selected = []
		for a in fits:
			selected.append(a.id)
	_rebuild()


func _fits() -> Array:
	var out := []
	for a in data.aids:
		if data.missing_needs(a, wanted).is_empty():
			out.append(a)
	return out


func _open_results() -> void:
	var fits := _fits()
	var v := _open_sheet(760)
	if fits.is_empty():
		_hoot_says(v, "Your shortlist", "None has everything you asked for. These come closest.")
	elif fits.size() == data.aids.size():
		_hoot_says(v, "Your shortlist", "Good news: all five do what you asked for!")
	else:
		_hoot_says(v, "Your shortlist", "Ask about these at Costco.")
	var ordered := data.aids.duplicate()
	ordered.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return data.missing_needs(x, wanted).size() < data.missing_needs(y, wanted).size())
	var shown_misses := false
	for a in ordered:
		var miss := data.missing_needs(a, wanted)
		if not miss.is_empty() and not fits.is_empty() and not shown_misses:
			v.add_child(Ui.wrap("These miss something you asked for:", Ui.H3, Ui.INK, 700))
			shown_misses = true
		v.add_child(_result_card(a, miss, fits.is_empty() or miss.is_empty()))
	var cmp := Ui.button("Compare my shortlist side by side", "main", Ui.H3, 62, true)
	cmp.pressed.connect(func() -> void:
		_close_sheet()
		_scroll_to("compare"))
	v.add_child(cmp)
	var again := Ui.button("Change my answers", "plain", Ui.BODY, 54, true)
	again.pressed.connect(_open_quiz.bind(0))
	v.add_child(again)
	var close := Ui.button("Back to the page", "plain", Ui.BODY, 54, true)
	close.pressed.connect(_close_sheet)
	v.add_child(close)


func _result_card(a: Dictionary, miss: Array, big: bool) -> Control:
	var col := _aid_color(a)
	var card := Ui.card(col if big else Ui.PAPER, Ui.INK, 22, 14, 4 if big else 0)
	var h := Ui.hbox(12)
	card.add_child(h)
	if big:
		var inset := Ui.card(Ui.PAPER, Ui.INK, 16, 4, 0)
		inset.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		inset.add_child(_picture(a.model_styles[0], a.shell, 120.0 if narrow() else 150.0))
		h.add_child(inset)
	var v := Ui.vbox(6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var fg := Ui.PAPER if big else Ui.INK
	v.add_child(Ui.wrap(a.name, Ui.H3, fg, 700))
	v.add_child(Ui.wrap("%s for two" % data.cell(a, "price_pair").v, Ui.BODY, fg, 600))
	if big and not wanted.is_empty():
		for n in wanted:
			if data.meets(a, n):
				var line := Ui.hbox(6)
				line.add_child(Icon.make("check", fg, 20))
				line.add_child(Ui.wrap(data.need_label(n), Ui.BODY, fg))
				v.add_child(line)
	if not miss.is_empty():
		var names := []
		for m in miss:
			names.append(data.need_label(m).to_lower())
		v.add_child(Ui.wrap("Missing: " + ", ".join(names), Ui.BODY, fg, 600))
	var more := Ui.button("See details", "plain", Ui.BODY, 50)
	more.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	more.pressed.connect(func() -> void:
		_close_sheet()
		expanded = a.id
		_rebuild()
		_scroll_to("aid_" + a.id))
	v.add_child(more)
	return card


func _open_viewer(aid_id: String) -> void:
	var a := data.aid(aid_id)
	var v := _open_sheet(900, Ui.PAPER)
	var head := Ui.hbox(12)
	v.add_child(head)
	head.add_child(Ui.wrap(a.name + " in 3D", Ui.H2, Ui.INK, 700))
	var x := Ui.button("Close", "plain", Ui.BODY, 50)
	x.pressed.connect(_close_sheet)
	head.add_child(x)
	var body: BoxContainer = Ui.vbox(14) if narrow() else Ui.hbox(18)
	v.add_child(body)
	var stage := Ui.card(Color("#eef1f4"), Ui.INK, 18, 4, 0)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tt: SubViewportContainer = Turntable.new()
	tt.custom_minimum_size = Vector2(0, 320 if narrow() else 440)
	tt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tt.setup(a.model_styles[0], a.shell, true, true)
	stage.add_child(tt)
	body.add_child(stage)
	var side := Ui.vbox(10)
	side.custom_minimum_size.x = 0 if narrow() else 280
	body.add_child(side)
	var parts := Ui.vbox(6)
	var show_parts := func(style: String) -> void:
		for c in parts.get_children():
			c.queue_free()
		var built: Dictionary = AidModel.build(style, a.shell)
		built.root.free()
		var n := 0
		for part in built.parts:
			n += 1
			var name_row := Ui.hbox(8)
			var num := Ui.pill(str(n), Ui.SUNNY, Ui.INK, Ui.SMALL, 700)
			num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			name_row.add_child(num)
			name_row.add_child(Ui.wrap(part, Ui.BODY, Ui.INK, 700))
			parts.add_child(name_row)
			parts.add_child(Ui.wrap(AidModel.PART_HELP.get(part, ""), Ui.SMALL, Ui.INK_SOFT))
	if a.model_styles.size() > 1:
		side.add_child(Ui.label("Style", Ui.SMALL, Ui.INK_SOFT, 600))
		var group := ButtonGroup.new()
		for s in a.model_styles:
			var b := Ui.button(AidModel.STYLE_NAMES.get(s, s), "chip", Ui.BODY, 50)
			b.toggle_mode = true
			b.button_group = group
			b.button_pressed = s == a.model_styles[0]
			b.pressed.connect(func() -> void:
				tt.setup(s, a.shell, true, true)
				show_parts.call(s))
			side.add_child(b)
	var labels := Ui.button("Hide the numbers", "plain", Ui.BODY, 50)
	labels.toggle_mode = true
	labels.toggled.connect(func(on: bool) -> void:
		tt.set_labels_visible(not on)
		labels.text = "Show part names" if on else "Hide the numbers")
	side.add_child(labels)
	side.add_child(Ui.label("The parts", Ui.SMALL, Ui.INK_SOFT, 600))
	side.add_child(parts)
	show_parts.call(a.model_styles[0])
	v.add_child(Ui.wrap("Drag with a finger or the mouse to turn it. The numbers match the list. A simple model of the style, not the product itself.", Ui.SMALL, Ui.INK_SOFT))


static func _date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3:
		return iso
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September",
			"October", "November", "December"]
	return "%d %s %s" % [int(parts[2]), months[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]
