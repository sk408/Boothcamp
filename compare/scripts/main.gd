extends Control
## Hearing Aid Compare: the whole page, built in code from data/*.json.

const Data := preload("res://scripts/data.gd")
const Turntable := preload("res://scripts/turntable.gd")
const AidModel := preload("res://scripts/aid_model.gd")

const BG := Color("f5f6f8")
const SURFACE := Color("ffffff")
const BORDER := Color("e1e4e9")
const TEXT := Color("141922")
const MUTED := Color("5b6472")
const ACCENT := Color("0b6b6b")
const ACCENT_SOFT := Color("e2f1f0")
const GOOD := Color("1d7a3c")
const GOOD_SOFT := Color("e3f4e8")
const WARN := Color("925c00")
const WARN_SOFT := Color("fdf1dc")
const NO_SOFT := Color("eef0f3")
const DIFF := Color("fff8e6")
const STATUS_COL := {"verified": Color("1d7a3c"), "reported": Color("c08a1a"), "unverified": Color("9aa1ab")}
const STATUS_TEXT := {
	"verified": "Verified: from the maker's or Costco's own page.",
	"reported": "Reported: from third-party reviews or price trackers only.",
	"unverified": "Not verified: no source found. Ask at the hearing aid centre.",
}
const MAX_W := 1280.0

var data := Data.new()
var detail := false          # false = plain words, true = full specs
var only_diff := false
var wanted: Array = []        # need ids
var selected: Array = []      # aid ids in the table
var bold: FontVariation

var _scroll: ScrollContainer
var _page: VBoxContainer
var _margin: MarginContainer
var _chips := {}
var _cards_box: GridContainer
var _table_box: VBoxContainer
var _mode_btns: Array[Button] = []
var _match_label: Label
var _overlay: Control


func _ready() -> void:
	bold = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	if not data.load_all():
		var err := Label.new()
		err.text = "Could not load the data files:\n" + "\n".join(data.errors)
		err.position = Vector2(24, 24)
		add_child(err)
		return
	for a in data.aids:
		selected.append(a.id)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_margin = MarginContainer.new()
	_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_margin)
	_page = VBoxContainer.new()
	_page.add_theme_constant_override("separation", 22)
	_margin.add_child(_page)
	_build_header()
	_build_needs()
	_cards_box = GridContainer.new()
	_cards_box.columns = 5
	_cards_box.add_theme_constant_override("h_separation", 16)
	_cards_box.add_theme_constant_override("v_separation", 16)
	_page.add_child(_cards_box)
	_build_table_header()
	_table_box = VBoxContainer.new()
	_table_box.add_theme_constant_override("separation", 0)
	var table_scroll := ScrollContainer.new()
	table_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var table_panel := _panel(SURFACE, 14, BORDER)
	table_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_panel.add_child(_table_box)
	_table_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table_scroll.add_child(table_panel)
	_page.add_child(table_scroll)
	_build_footer()
	get_viewport().size_changed.connect(_fit)
	_fit()
	_refresh()


func _fit() -> void:
	var w := get_viewport_rect().size.x
	var side: float = max(16.0, (w - MAX_W) * 0.5)
	_margin.add_theme_constant_override("margin_left", int(side))
	_margin.add_theme_constant_override("margin_right", int(side))
	_margin.add_theme_constant_override("margin_top", 28)
	_margin.add_theme_constant_override("margin_bottom", 40)
	var inner: float = min(w, MAX_W) - side * 2.0 if w < MAX_W else MAX_W - 32.0
	_cards_box.columns = clampi(int((inner + 16.0) / 236.0), 1, 5)


# ---------------------------------------------------------------- header and needs

func _build_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_page.add_child(row)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	row.add_child(titles)
	var t := _label(data.meta.get("title", "Hearing Aid Compare"), 32, TEXT, true)
	titles.add_child(t)
	titles.add_child(_label(data.meta.get("subtitle", ""), 16, MUTED))
	var asof := _label("Specs as of %s" % _date(data.meta.get("specs_as_of", "")), 13, ACCENT, true)
	titles.add_child(asof)
	var right := HBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 10)
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	var quiz := _button("Help me choose", false)
	quiz.pressed.connect(_open_quiz)
	right.add_child(quiz)
	var seg := HBoxContainer.new()
	seg.add_theme_constant_override("separation", 0)
	right.add_child(seg)
	for i in 2:
		var b := _button(["Plain words", "Full specs"][i], true)
		b.toggle_mode = true
		b.button_pressed = (i == 1) == detail
		b.tooltip_text = ["What each feature means for you", "Every spec, with its sources"][i]
		b.pressed.connect(_set_mode.bind(i == 1))
		seg.add_child(b)
		_mode_btns.append(b)


func _build_needs() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_page.add_child(box)
	var head := HBoxContainer.new()
	box.add_child(head)
	head.add_child(_label("What matters to you?", 18, TEXT, true))
	_match_label = _label("", 14, MUTED)
	_match_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(_match_label)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	box.add_child(flow)
	for n in data.needs:
		var chip := _button(n.label, true)
		chip.toggle_mode = true
		chip.toggled.connect(_toggle_need.bind(n.id))
		var r := data.row(n.id)
		chip.tooltip_text = r.get("help", "")
		flow.add_child(chip)
		_chips[n.id] = chip
	var clear := Button.new()
	clear.text = "Clear"
	clear.flat = true
	clear.add_theme_color_override("font_color", ACCENT)
	clear.pressed.connect(_set_needs.bind([]))
	flow.add_child(clear)


func _build_table_header() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	_page.add_child(row)
	var t := _label("Side by side", 22, TEXT, true)
	row.add_child(t)
	var hint := _label("Tick up to five aids above. Click any value for its meaning and sources.", 14, MUTED)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hint)
	var diff := CheckBox.new()
	diff.text = "Only show differences"
	diff.toggled.connect(func(on: bool) -> void:
		only_diff = on
		_refresh_table())
	row.add_child(diff)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 14)
	_page.add_child(legend)
	for st in ["verified", "reported", "unverified"]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 6)
		var dot := _dot(STATUS_COL[st])
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		item.add_child(dot)
		item.add_child(_label(STATUS_TEXT[st].split(":")[0], 13, MUTED))
		item.tooltip_text = STATUS_TEXT[st]
		legend.add_child(item)
	# The legend sits right under the title: move it up next to it.
	_page.move_child(legend, row.get_index() + 1)


func _build_footer() -> void:
	var care := _panel(ACCENT_SOFT, 12)
	var cbox := VBoxContainer.new()
	care.add_child(cbox)
	cbox.add_child(_label("What every Costco hearing aid includes", 16, ACCENT, true))
	cbox.add_child(_wrap(data.meta.get("care", "") + _src_marks(data.meta.get("care_src", [])), 14, TEXT))
	_page.add_child(care)
	var pmeta := _wrap(data.prices_meta.get("note", ""), 13, MUTED)
	_page.add_child(pmeta)
	_page.add_child(_label("Sources", 18, TEXT, true))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.selection_enabled = true
	rt.add_theme_color_override("default_color", MUTED)
	rt.add_theme_font_size_override("normal_font_size", 13)
	rt.meta_clicked.connect(func(m: Variant) -> void: OS.shell_open(str(m)))
	var lines := PackedStringArray()
	var i := 1
	for id in data.source_order:
		var s: Dictionary = data.sources[id]
		var kind: String = {"costco": "Costco", "maker": "Maker", "third": "Third party"}.get(s.kind, s.kind)
		lines.append("[%d] [color=#%s][url=%s]%s[/url][/color]  (%s, read %s)" % [i, ACCENT.to_html(false), s.url, s.title, kind, s.read])
		i += 1
	rt.text = "\n".join(lines)
	_page.add_child(rt)
	_page.add_child(_wrap(data.meta.get("disclaimer", ""), 13, MUTED))
	_page.add_child(_wrap("The 3D shapes are generic drawings of each style, not the products themselves.", 13, MUTED))


# ---------------------------------------------------------------- state

func _set_mode(full: bool) -> void:
	detail = full
	for i in _mode_btns.size():
		_mode_btns[i].set_pressed_no_signal((i == 1) == detail)
	_refresh_table()


func _toggle_need(on: bool, id: String) -> void:
	if on and not wanted.has(id):
		wanted.append(id)
	elif not on:
		wanted.erase(id)
	_refresh()


func _set_needs(ids: Array) -> void:
	wanted = ids.duplicate()
	for id in _chips:
		_chips[id].set_pressed_no_signal(wanted.has(id))
	_refresh()


func _toggle_selected(on: bool, id: String) -> void:
	if on and not selected.has(id):
		selected.append(id)
	elif not on:
		selected.erase(id)
	# Keep the table in line-up order.
	var ordered := []
	for a in data.aids:
		if selected.has(a.id):
			ordered.append(a.id)
	selected = ordered
	_refresh_table()


func _refresh() -> void:
	_refresh_cards()
	_refresh_table()
	if wanted.is_empty():
		_match_label.text = "Pick what you need. Aids that miss it fade but stay on the page."
	else:
		var n := 0
		for a in data.aids:
			if data.missing_needs(a, wanted).is_empty():
				n += 1
		_match_label.text = "%d of %d aids meet all %d of your needs" % [n, data.aids.size(), wanted.size()]


# ---------------------------------------------------------------- cards

func _refresh_cards() -> void:
	# The cards are built once (their 3D views keep turning); later calls only update the needs line.
	if _cards_box.get_child_count() == 0:
		for a in data.aids:
			_cards_box.add_child(_make_card(a))
	for card in _cards_box.get_children():
		var a: Dictionary = data.aid(card.get_meta("aid"))
		var miss := data.missing_needs(a, wanted)
		var line: Label = card.get_meta("needs_line")
		var pill: PanelContainer = card.get_meta("needs_pill")
		pill.visible = not wanted.is_empty()
		if miss.is_empty():
			line.text = "Meets your needs"
			line.add_theme_color_override("font_color", GOOD)
			pill.add_theme_stylebox_override("panel", _box(GOOD_SOFT, 8))
		else:
			var names := []
			for m in miss:
				names.append(data.need_label(m))
			line.text = "Missing: " + ", ".join(names)
			line.add_theme_color_override("font_color", WARN)
			pill.add_theme_stylebox_override("panel", _box(WARN_SOFT, 8))
		card.modulate = Color(1, 1, 1, 1.0 if miss.is_empty() else 0.55)


func _make_card(a: Dictionary) -> Control:
	var card := _panel(SURFACE, 14, BORDER)
	card.custom_minimum_size = Vector2(200, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.set_meta("aid", a.id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var stage_bg := _panel(Color("eef1f4"), 10)
	stage_bg.add_theme_stylebox_override("panel", _box(Color("eef1f4"), 10, Color.TRANSPARENT, 0))
	var tt: SubViewportContainer = Turntable.new()
	tt.custom_minimum_size = Vector2(170, 140)
	tt.setup(a.model_styles[0], a.shell, false, false)
	tt.tooltip_text = "Open the 3D view"
	tt.clicked.connect(_open_viewer.bind(a.id))
	stage_bg.add_child(tt)
	v.add_child(stage_bg)
	v.add_child(_label(a.name, 17, TEXT, true))
	var maker: Dictionary = data.cell(a, "maker")
	v.add_child(_label(str(maker.get("v", "")), 13, MUTED))
	var price: Dictionary = data.cell(a, "price_pair")
	var pr := HBoxContainer.new()
	pr.add_child(_label(price.v if price.v != "" else "Price not found", 20, TEXT, true))
	var per := _label(" a pair", 13, MUTED)
	per.size_flags_vertical = Control.SIZE_SHRINK_END
	pr.add_child(per)
	v.add_child(pr)
	for g in a.get("good_for", []):
		v.add_child(_wrap("•  " + g, 13, TEXT))
	var pill := PanelContainer.new()
	var nl := _wrap("", 13, GOOD, true)
	pill.add_child(nl)
	v.add_child(pill)
	card.set_meta("needs_line", nl)
	card.set_meta("needs_pill", pill)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var foot := HBoxContainer.new()
	v.add_child(foot)
	var cb := CheckBox.new()
	cb.text = "Compare"
	cb.button_pressed = selected.has(a.id)
	cb.toggled.connect(_toggle_selected.bind(a.id))
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(cb)
	var view := Button.new()
	view.text = "View in 3D"
	view.flat = true
	view.add_theme_color_override("font_color", ACCENT)
	view.pressed.connect(_open_viewer.bind(a.id))
	foot.add_child(view)
	return card


# ---------------------------------------------------------------- table

func _refresh_table() -> void:
	for c in _table_box.get_children():
		c.queue_free()
	var aids := []
	for id in selected:
		aids.append(data.aid(id))
	if aids.is_empty():
		var m := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + side, 20)
		m.add_child(_label("Tick \"Compare\" on a card to add it here.", 15, MUTED))
		_table_box.add_child(m)
		return
	# Column heads.
	var head := _table_row(aids.size())
	head.add_theme_stylebox_override("panel", _box(SURFACE, 0, Color.TRANSPARENT, 0))
	var hrow: HBoxContainer = head.get_child(0)
	hrow.get_child(0).get_child(0).add_child(_label("Plain words" if not detail else "Full specs", 13, MUTED, true))
	for i in aids.size():
		var a: Dictionary = aids[i]
		var cell: VBoxContainer = hrow.get_child(i + 1).get_child(0)
		cell.add_child(_wrap(a.name, 15, TEXT, true))
		var miss := data.missing_needs(a, wanted)
		if not miss.is_empty():
			cell.add_child(_wrap("Misses %d of your needs" % miss.size(), 12, WARN))
		cell.modulate.a = 1.0 if miss.is_empty() else 0.6
	_table_box.add_child(head)
	var shown := 0
	for g in data.groups:
		var rows := []
		for r in data.rows:
			if r.group != g.id or (r.get("detail_only", false) and not detail):
				continue
			var differs := _differs(r.id, aids)
			if only_diff and not differs and aids.size() > 1:
				continue
			# Only yes-no rows and prices get the tint: free text nearly always differs.
			differs = differs and r.kind != "text"
			rows.append([r, differs])
		if rows.is_empty():
			continue
		var gp := PanelContainer.new()
		gp.add_theme_stylebox_override("panel", _box(Color("f0f2f5"), 0, Color.TRANSPARENT, 0, 8))
		gp.add_child(_label(g.label.to_upper(), 12, MUTED, true))
		_table_box.add_child(gp)
		for pair in rows:
			_table_box.add_child(_value_row(pair[0], aids, pair[1] and aids.size() > 1))
			shown += 1
	if shown == 0:
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 20)
		m.add_theme_constant_override("margin_top", 14)
		m.add_theme_constant_override("margin_bottom", 14)
		m.add_child(_label("These aids match on every row shown.", 14, MUTED))
		_table_box.add_child(m)


func _differs(field: String, aids: Array) -> bool:
	var first: Variant = null
	for a in aids:
		var v := str(data.cell(a, field).get("v", ""))
		if first == null:
			first = v
		elif v != first:
			return true
	return false


func _table_row(n: int) -> PanelContainer:
	# PanelContainer > HBoxContainer > n + 1 x (MarginContainer > VBoxContainer): the label cell, then one per aid.
	var p := PanelContainer.new()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	p.add_child(h)
	for i in n + 1:
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_right", 14)
		m.add_theme_constant_override("margin_top", 10)
		m.add_theme_constant_override("margin_bottom", 10)
		if i == 0:
			m.custom_minimum_size = Vector2(250, 0)
		else:
			m.custom_minimum_size = Vector2(170, 0)
			m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m.size_flags_stretch_ratio = 1.0
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 3)
		m.add_child(box)
		h.add_child(m)
	return p


func _value_row(r: Dictionary, aids: Array, differs: bool) -> Control:
	var row := _table_row(aids.size())
	row.add_theme_stylebox_override("panel", _box(DIFF if differs else SURFACE, 0, BORDER, 0, 0, true))
	var cells: HBoxContainer = row.get_child(0)
	var lab: VBoxContainer = cells.get_child(0).get_child(0)
	lab.add_child(_wrap(r.label if detail else r.plain, 14, TEXT, true))
	if not detail:
		lab.add_child(_wrap(r.get("help", ""), 12, MUTED))
	if differs:
		lab.add_child(_label("Differs", 11, WARN, true))
	for i in aids.size():
		var a: Dictionary = aids[i]
		var box: VBoxContainer = cells.get_child(i + 1).get_child(0)
		var c := data.cell(a, r.id)
		_fill_cell(box, r, c)
		var host: Control = cells.get_child(i + 1)
		host.mouse_filter = Control.MOUSE_FILTER_STOP
		host.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		host.tooltip_text = "Click for the meaning and sources"
		host.gui_input.connect(_cell_input.bind(a.id, r.id))
	return row


func _fill_cell(box: VBoxContainer, r: Dictionary, c: Dictionary) -> void:
	var v := str(c.get("v", ""))
	var st: String = c.get("status", "unverified")
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	box.add_child(line)
	if r.kind == "flag" and v != "":
		var pill := PanelContainer.new()
		var col: Color = {"yes": GOOD, "no": MUTED, "some": WARN, "later": WARN}.get(v, MUTED)
		var soft: Color = {"yes": GOOD_SOFT, "no": NO_SOFT, "some": WARN_SOFT, "later": WARN_SOFT}.get(v, NO_SOFT)
		pill.add_theme_stylebox_override("panel", _box(soft, 10, Color.TRANSPARENT, 0, 3, false, 9))
		pill.add_child(_label(Data.flag_text(v), 13, col, true))
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(pill)
	elif v == "":
		line.add_child(_label("Not verified", 13, STATUS_COL.unverified))
	else:
		var t := _wrap(v, 14 if r.kind != "price" else 15, TEXT, r.kind == "price")
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(t)
	var dot := _dot(STATUS_COL.get(st, MUTED))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.tooltip_text = STATUS_TEXT.get(st, "")
	line.add_child(dot)
	var note := str(c.get("note", ""))
	if detail:
		if note != "":
			box.add_child(_wrap(note, 12, MUTED))
		var marks := _src_marks(c.get("src", []))
		if marks != "":
			box.add_child(_label(marks.strip_edges(), 11, ACCENT))
	elif r.kind == "flag" and (v == "some" or v == "later") and note != "":
		box.add_child(_wrap(note, 12, MUTED))


func _cell_input(event: InputEvent, aid_id: String, field: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_open_detail(aid_id, field)


func _src_marks(ids: Array) -> String:
	var out := ""
	for id in ids:
		var n := data.source_order.find(id)
		if n >= 0:
			out += " [%d]" % (n + 1)
	return out


# ---------------------------------------------------------------- overlays

func _open_overlay(width: float) -> VBoxContainer:
	_close_overlay()
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.08, 0.1, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_overlay())
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(center)
	var panel := _panel(SURFACE, 16, BORDER, 24)
	panel.custom_minimum_size = Vector2(min(width, get_viewport_rect().size.x - 32), 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	return v


func _close_overlay() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _unhandled_input(event: InputEvent) -> void:
	if _overlay and event.is_action_pressed("ui_cancel"):
		_close_overlay()
		get_viewport().set_input_as_handled()


func _overlay_head(v: VBoxContainer, title: String, sub: String) -> void:
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := VBoxContainer.new()
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(_wrap(title, 20, TEXT, true))
	if sub != "":
		t.add_child(_wrap(sub, 14, MUTED))
	var x := _button("Close", false)
	x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	x.pressed.connect(_close_overlay)
	h.add_child(x)


func _open_detail(aid_id: String, field: String) -> void:
	var a := data.aid(aid_id)
	var r := data.row(field)
	var c := data.cell(a, field)
	var v := _open_overlay(560)
	_overlay_head(v, "%s: %s" % [a.name, r.label], r.get("help", ""))
	var val := str(c.get("v", ""))
	var shown := Data.flag_text(val) if r.kind == "flag" else (val if val != "" else "Not verified")
	v.add_child(_wrap(shown, 22, TEXT, true))
	if c.get("item", "") != "":
		v.add_child(_label("Costco item #%s" % c.item, 13, MUTED))
	if str(c.get("note", "")) != "":
		v.add_child(_wrap(c.note, 15, TEXT))
	var st: String = c.get("status", "unverified")
	var sline := HBoxContainer.new()
	sline.add_theme_constant_override("separation", 8)
	var dot := _dot(STATUS_COL.get(st, MUTED))
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sline.add_child(dot)
	var stl := _wrap(STATUS_TEXT.get(st, ""), 14, MUTED)
	stl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sline.add_child(stl)
	v.add_child(sline)
	var srcs: Array = c.get("src", [])
	if not srcs.is_empty():
		v.add_child(_label("Sources", 14, TEXT, true))
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.add_theme_font_size_override("normal_font_size", 13)
		rt.add_theme_color_override("default_color", MUTED)
		rt.meta_clicked.connect(func(m: Variant) -> void: OS.shell_open(str(m)))
		var lines := PackedStringArray()
		for id in srcs:
			if data.sources.has(id):
				var s: Dictionary = data.sources[id]
				lines.append("[%d] [color=#%s][url=%s]%s[/url][/color]" % [data.source_order.find(id) + 1, ACCENT.to_html(false), s.url, s.title])
		rt.text = "\n".join(lines)
		v.add_child(rt)


func _open_viewer(aid_id: String) -> void:
	var a := data.aid(aid_id)
	var v := _open_overlay(820)
	var styles_cell := data.cell(a, "styles")
	_overlay_head(v, a.name, "Styles: " + str(styles_cell.get("v", "")))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	v.add_child(body)
	var stage := _panel(Color("eef1f4"), 12)
	var tt: SubViewportContainer = Turntable.new()
	tt.custom_minimum_size = Vector2(500, 380)
	tt.setup(a.model_styles[0], a.shell, true, true)
	stage.add_child(tt)
	body.add_child(stage)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(240, 0)
	side.add_theme_constant_override("separation", 8)
	body.add_child(side)
	side.add_child(_label("Style", 13, MUTED, true))
	var help_box := VBoxContainer.new()
	help_box.add_theme_constant_override("separation", 6)
	var show_parts := func(style: String) -> void:
		for c in help_box.get_children():
			c.queue_free()
		var built: Dictionary = AidModel.build(style, a.shell)
		built.root.free()
		for part in built.parts:
			help_box.add_child(_wrap(part, 13, TEXT, true))
			help_box.add_child(_wrap(AidModel.PART_HELP.get(part, ""), 12, MUTED))
	var group := ButtonGroup.new()
	for s in a.model_styles:
		var b := _button(AidModel.STYLE_NAMES.get(s, s), true)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = s == a.model_styles[0]
		b.pressed.connect(func() -> void:
			tt.setup(s, a.shell, true, true)
			show_parts.call(s))
		side.add_child(b)
	var labels := CheckBox.new()
	labels.text = "Show part names"
	labels.button_pressed = true
	labels.toggled.connect(tt.set_labels_visible)
	side.add_child(labels)
	side.add_child(_label("Parts", 13, MUTED, true))
	side.add_child(help_box)
	show_parts.call(a.model_styles[0])
	v.add_child(_wrap("Drag to turn, scroll to zoom. A generic shape of the style, not the product itself.", 12, MUTED))


func _open_quiz() -> void:
	var v := _open_overlay(620)
	_overlay_head(v, "Help me choose", "Five quick questions. They set the filters; no aid is named the winner.")
	var answers := {}
	var qs := [
		["Which phone do you use?", [["iPhone", ["iphone"]], ["Android", ["android"]], ["No smartphone", []]]],
		["Do you want to take calls without holding the phone?", [["Yes", ["hands_free"]], ["Not needed", []]]],
		["Do you go to theatres, churches or counters with a hearing loop sign?", [["Yes", ["telecoil"]], ["No or not sure", []]]],
		["Charging or batteries?", [["Charge every night", ["rechargeable"]], ["Change small batteries", []], ["Either", []]]],
		["Would you like it hidden inside the ear canal?", [["Yes", ["in_canal"]], ["No preference", []]]],
	]
	for qi in qs.size():
		var q: Array = qs[qi]
		v.add_child(_wrap(q[0], 15, TEXT, true))
		var row := HFlowContainer.new()
		row.add_theme_constant_override("h_separation", 8)
		var group := ButtonGroup.new()
		for opt in q[1]:
			var b := _button(opt[0], true)
			b.toggle_mode = true
			b.button_group = group
			b.pressed.connect(func() -> void: answers[qi] = opt[1])
			row.add_child(b)
		v.add_child(row)
	var go := _button("Show my matches", false)
	go.add_theme_stylebox_override("normal", _box(ACCENT, 10, Color.TRANSPARENT, 0, 9, false, 18))
	go.add_theme_stylebox_override("hover", _box(ACCENT.lightened(0.1), 10, Color.TRANSPARENT, 0, 9, false, 18))
	go.add_theme_color_override("font_color", Color.WHITE)
	go.add_theme_color_override("font_hover_color", Color.WHITE)
	go.pressed.connect(func() -> void:
		var ids := []
		for k in answers:
			for id in answers[k]:
				if not ids.has(id):
					ids.append(id)
		_set_needs(ids)
		_close_overlay())
	v.add_child(go)


# ---------------------------------------------------------------- small builders

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	th.set_color("font_color", "Label", TEXT)
	for t in ["Button", "CheckBox"]:
		th.set_color("font_color", t, TEXT)
		th.set_color("font_hover_color", t, TEXT)
		th.set_color("font_pressed_color", t, ACCENT)
		th.set_color("font_hover_pressed_color", t, ACCENT)
		th.set_color("font_focus_color", t, TEXT)
	th.set_stylebox("normal", "Button", _box(SURFACE, 10, BORDER, 1, 8, false, 14))
	th.set_stylebox("hover", "Button", _box(Color("f2f4f7"), 10, Color("c9ced6"), 1, 8, false, 14))
	th.set_stylebox("pressed", "Button", _box(ACCENT_SOFT, 10, ACCENT, 1, 8, false, 14))
	th.set_stylebox("hover_pressed", "Button", _box(ACCENT_SOFT, 10, ACCENT, 1, 8, false, 14))
	th.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, 10, ACCENT, 2, 8, false, 14))
	var flat := StyleBoxEmpty.new()
	for s in ["normal", "hover", "pressed", "hover_pressed"]:
		th.set_stylebox(s, "CheckBox", flat)
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_stylebox("panel", "TooltipPanel", _box(SURFACE, 8, BORDER, 1, 6, false, 10))
	return th


func _box(bg: Color, radius: int, border: Color = Color.TRANSPARENT, bw: int = 1, pad_v: int = 0,
		bottom_only: bool = false, pad_h: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	if bottom_only:
		s.border_width_bottom = 1
	else:
		s.set_border_width_all(bw)
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	s.content_margin_left = pad_h if pad_h >= 0 else pad_v
	s.content_margin_right = pad_h if pad_h >= 0 else pad_v
	s.anti_aliasing = true
	return s


func _panel(bg: Color, radius: int, border: Color = Color.TRANSPARENT, pad: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var s := _box(bg, radius, border, 1 if border.a > 0 else 0, pad)
	if border.a > 0:
		s.shadow_color = Color(0.05, 0.08, 0.12, 0.06)
		s.shadow_size = 6
		s.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s)
	return p


func _label(text: String, size: int, col: Color, is_bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if is_bold:
		l.add_theme_font_override("font", bold)
	return l


func _wrap(text: String, size: int, col: Color, is_bold: bool = false) -> Label:
	var l := _label(text, size, col, is_bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(60, 0)
	return l


func _button(text: String, chip: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if chip:
		b.add_theme_stylebox_override("normal", _box(SURFACE, 18, BORDER, 1, 7, false, 14))
		b.add_theme_stylebox_override("hover", _box(Color("f2f4f7"), 18, Color("c9ced6"), 1, 7, false, 14))
		b.add_theme_stylebox_override("pressed", _box(ACCENT_SOFT, 18, ACCENT, 1, 7, false, 14))
		b.add_theme_stylebox_override("hover_pressed", _box(ACCENT_SOFT, 18, ACCENT, 1, 7, false, 14))
	return b


func _dot(col: Color) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(9, 9)
	p.add_theme_stylebox_override("panel", _box(col, 5, Color.TRANSPARENT, 0))
	return p


static func _date(iso: String) -> String:
	var parts := iso.split("-")
	if parts.size() != 3:
		return iso
	var months := ["January", "February", "March", "April", "May", "June", "July", "August", "September",
			"October", "November", "December"]
	return "%d %s %s" % [int(parts[2]), months[clampi(int(parts[1]) - 1, 0, 11)], parts[0]]
