@tool
extends EditorInspectorPlugin
## Puts a NameWarning above the properties of statuses, triggers, modifiers,
## conditions, effects and abilities.

const NameWarning = preload("name_warning.gd")


func _can_handle(object: Object) -> bool:
	return NameCheck.handles(object)


func _parse_begin(object: Object) -> void:
	var warning := NameWarning.new()
	warning.target = object
	add_custom_control(warning)
