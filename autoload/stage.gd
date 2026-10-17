extends Node
## Stage: registry of the live 3D world and the active audiometer (autoload "Stage").
##
## Decouples ui/ from world/: the audiometer never references the clinic directly.
##  - res://world/clinic.tscn calls Stage.register_clinic(self) in _enter_tree() and
##    Stage.unregister_clinic(self) in _exit_tree().
##  - The audiometer screen calls Stage.get_booth_texture() for its booth window and emits
##    Events.patient_reaction (or Stage.react()) to make the patient react.
## If no clinic is loaded (e.g. the audiometer demo scene), a placeholder texture is returned.

var clinic: Node = null
var audiometer: Node = null
var _placeholder: Texture2D


func register_clinic(node: Node) -> void:
	clinic = node


func unregister_clinic(node: Node) -> void:
	if clinic == node:
		clinic = null


func register_audiometer(node: Node) -> void:
	audiometer = node


func unregister_audiometer(node: Node) -> void:
	if audiometer == node:
		audiometer = null


func has_clinic() -> bool:
	return clinic != null and is_instance_valid(clinic)


## Live view of the patient in the booth (ViewportTexture from the clinic), or a placeholder.
func get_booth_texture() -> Texture2D:
	if has_clinic() and clinic.has_method("get_booth_texture"):
		var tex: Texture2D = clinic.call("get_booth_texture")
		if tex != null:
			return tex
	return placeholder_texture()


## Tell the clinic whether the booth camera should render (saves GPU when hidden).
func set_booth_view_active(active: bool) -> void:
	if has_clinic() and clinic.has_method("set_booth_view_active"):
		clinic.call("set_booth_view_active", active)


## Convenience: Events.patient_reaction.emit(kind, data).
func react(kind: StringName, data: Dictionary = {}) -> void:
	Events.patient_reaction.emit(kind, data)


func placeholder_texture() -> Texture2D:
	if _placeholder == null:
		var g := Gradient.new()
		g.set_color(0, Palette.SKY)
		g.set_color(1, Palette.WALL)
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 320
		gt.height = 200
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		_placeholder = gt
	return _placeholder
