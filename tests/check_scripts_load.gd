extends SceneTree
## Loads every script under [code]res://character_system[/code] and exits with 1 if one fails.
## CI runs it on a copy of the project without [code]kit/[/code] and [code]examples/[/code],
## to prove the core needs neither:
## [codeblock lang=text]
## godot --headless --path <copy> -s <this file>
## [/codeblock]


func _init() -> void:
	var failed: PackedStringArray = []
	var count: int = 0
	var folders: Array[String] = ["res://character_system"]
	while not folders.is_empty():
		var folder: String = folders.pop_back()
		for name: String in DirAccess.get_directories_at(folder):
			folders.append(folder.path_join(name))
		for name: String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):
				count += 1
				var script := load(folder.path_join(name)) as GDScript
				if not script or not (script.can_instantiate() or script.is_abstract()):
					failed.append(folder.path_join(name))
	print("Loaded %d scripts, %d failed. %s" % [count, failed.size(), ", ".join(failed)])
	quit(1 if failed.size() > 0 or count == 0 else 0)
