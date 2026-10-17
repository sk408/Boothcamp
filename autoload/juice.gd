class_name Juice
extends RefCounted
## Juice: shared tween helpers for bouncy, squashy, satisfying feedback.
## All use the node's own tweens, so they follow Engine.time_scale and stop with the node.
## They respect Game.settings.reduced_motion (smaller motion, never zero feedback).


static func _reduced() -> bool:
	var game: Node = Engine.get_main_loop().root.get_node_or_null("Game")
	return game != null and bool(game.get("settings").get("reduced_motion", false))


static func _center_pivot(c: CanvasItem) -> void:
	if c is Control:
		(c as Control).pivot_offset = (c as Control).size * 0.5


## Scale up and settle with overshoot (stamps, callouts, buttons).
static func pop(node: CanvasItem, from_scale: float = 1.35, duration: float = 0.35) -> Tween:
	_center_pivot(node)
	if _reduced():
		from_scale = lerpf(1.0, from_scale, 0.3)
	node.scale = Vector2.ONE * from_scale
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Appear from nothing with a springy overshoot.
static func bounce_in(node: CanvasItem, duration: float = 0.45) -> Tween:
	_center_pivot(node)
	node.scale = Vector2.ONE * (0.6 if _reduced() else 0.1)
	node.modulate.a = 0.0
	var t := node.create_tween().set_parallel(true)
	t.tween_property(node, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "modulate:a", 1.0, duration * 0.4)
	return t


## Squash then stretch back (a press, a landing).
static func squash(node: CanvasItem, amount: float = 0.2, duration: float = 0.3) -> Tween:
	_center_pivot(node)
	var t := node.create_tween()
	t.tween_property(node, "scale", Vector2(1.0 + amount, 1.0 - amount), duration * 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2(1.0 - amount * 0.5, 1.0 + amount * 0.5), duration * 0.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "scale", Vector2.ONE, duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return t


## Short positional shake of a CanvasItem (Control or Node2D). strength in px.
static func shake(node: CanvasItem, strength: float = 8.0, duration: float = 0.3) -> Tween:
	if _reduced():
		strength *= 0.25
	# A shake that starts while another runs must not take the displaced spot as "home"
	# (the node would drift away): the first shake's origin is kept until the last one ends.
	var origin: Vector2 = node.get_meta(&"_shake_origin", node.get("position"))
	if node.has_meta(&"_shake_tween"):
		var old: Variant = node.get_meta(&"_shake_tween")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	node.set_meta(&"_shake_origin", origin)
	var t := node.create_tween()
	node.set_meta(&"_shake_tween", t)
	var steps := 6
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		t.tween_property(node, "position", origin + off, duration / steps)
	t.tween_property(node, "position", origin, duration / steps)
	t.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.remove_meta(&"_shake_origin")
			node.remove_meta(&"_shake_tween"))
	return t


## Gentle looping bob (idle life). Returns the looping tween so callers can kill() it.
static func bob(node: CanvasItem, height: float = 6.0, period: float = 1.2) -> Tween:
	var origin: Vector2 = node.get("position")
	var t := node.create_tween().set_loops()
	t.tween_property(node, "position", origin + Vector2(0, -height), period * 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "position", origin, period * 0.5).set_trans(Tween.TRANS_SINE)
	return t


## Floating "+1" / "Textbook!" style text that rises and fades. Adds a Label under parent.
static func float_text(parent: Node, text: String, at: Vector2, color: Color = Palette.INK, size: int = 34) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.PAPER)
	l.add_theme_constant_override("outline_size", 10)
	l.position = at
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.reset_size()
	l.position -= l.size * 0.5
	pop(l, 1.6, 0.3)
	var t := l.create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 70.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	t.chain().tween_callback(l.queue_free)
	return l
