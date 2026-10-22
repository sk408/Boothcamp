extends SubViewportContainer
## A small 3D stage that turns one aid shape. Drag to turn, scroll to zoom (when interactive).

signal clicked

const AidModel := preload("res://scripts/aid_model.gd")

var interactive := false
var show_labels := false
var _vp: SubViewport
var _pivot: Node3D
var _cam: Camera3D
var _dragging := false
var _moved := 0.0
var _yaw := 0.35
var _pitch := -0.25
var _dist := 7.5
var _idle := 0.0
var _labels: Array[Label3D] = []
# --still (screenshots): no idle turning, so every shot shows the same angle.
var _still := OS.get_cmdline_user_args().has("--still")


func setup(style: String, shell: String, is_interactive: bool, labels: bool) -> void:
	interactive = is_interactive
	show_labels = labels
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not interactive else Control.CURSOR_DRAG
	if _vp == null:
		_vp = SubViewport.new()
		_vp.own_world_3d = true
		_vp.transparent_bg = true
		_vp.msaa_3d = Viewport.MSAA_4X
		add_child(_vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.9, 0.92, 0.95)
		e.ambient_light_energy = 0.9
		env.environment = e
		_vp.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-40, 35, 0)
		key.light_energy = 1.1
		_vp.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, -150, 0)
		rim.light_energy = 0.5
		_vp.add_child(rim)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(20, -60, 0)
		fill.light_energy = 0.35
		_vp.add_child(fill)
		_cam = Camera3D.new()
		_cam.fov = 32
		_vp.add_child(_cam)
	if _pivot:
		_pivot.queue_free()
	_labels.clear()
	_pivot = Node3D.new()
	_vp.add_child(_pivot)
	var built: Dictionary = AidModel.build(style, shell)
	var model: Node3D = built.root
	_pivot.add_child(model)
	# Centre the shape on the pivot.
	var aabb := _bounds(model)
	model.position = -aabb.get_center()
	_dist = max(aabb.size.length() * (1.35 if interactive else 1.45), 4.0 if interactive else 3.5)
	if show_labels:
		for part in built.parts:
			var l := Label3D.new()
			l.text = part
			l.font_size = 40
			l.pixel_size = 0.0045
			l.outline_size = 10
			l.modulate = Color(0.08, 0.1, 0.13)
			l.outline_modulate = Color(1, 1, 1, 0.9)
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.position = built.parts[part]
			model.add_child(l)
			_labels.append(l)
	_place_camera()


func set_labels_visible(v: bool) -> void:
	for l in _labels:
		l.visible = v


func _process(delta: float) -> void:
	if _pivot == null:
		return
	_idle += delta
	if not _dragging and (_idle > 2.5 or not interactive) and not _still:
		_yaw += delta * 0.45
	_place_camera()


func _place_camera() -> void:
	if _cam == null:
		return
	_pivot.rotation = Vector3(_pitch, _yaw, 0)
	_cam.position = Vector3(0, 0, _dist)
	_cam.rotation = Vector3.ZERO


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = interactive
				_moved = 0.0
			else:
				_dragging = false
				if _moved < 6.0:
					clicked.emit()
			accept_event()
		elif interactive and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = max(_dist * 0.9, 2.5)
			accept_event()
		elif interactive and mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = min(_dist * 1.1, 16.0)
			accept_event()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_moved += mm.relative.length()
		if _dragging:
			_idle = 0.0
			_yaw += mm.relative.x * 0.01
			_pitch = clamp(_pitch + mm.relative.y * 0.01, -1.3, 1.3)
			accept_event()


static func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.get_children():
		if c is MeshInstance3D:
			var b: AABB = c.transform * c.get_aabb()
			if first:
				box = b
				first = false
			else:
				box = box.merge(b)
	return box
