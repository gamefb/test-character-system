@tool
extends EditorPlugin
## Adds the name warnings to the Inspector. See NameCheck for what is checked.

var _inspector: EditorInspectorPlugin


func _enter_tree() -> void:
	_inspector = preload("inspector_plugin.gd").new()
	add_inspector_plugin(_inspector)
	resource_saved.connect(_on_resource_saved)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(NameCheck.rescan)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector)
	resource_saved.disconnect(_on_resource_saved)
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(NameCheck.rescan)


# A newly saved status may add a tag, so read the project again on the next check.
func _on_resource_saved(_resource: Resource) -> void:
	NameCheck.rescan()
