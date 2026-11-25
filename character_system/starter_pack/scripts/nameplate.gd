@icon("res://character_system/icons/nameplate.svg")
class_name Nameplate
extends Label3D
## An example to copy: shows a character's name, health and statuses above its head.
##
## Add it as a child of the character, a little above its head. It turns to face the camera.
## It reads the character every frame, which is fine for a handful; for a crowd, update on
## [signal Pool.changed] and [signal Statuses.changed] as [CharacterHud] does.


func _init() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _process(_delta: float) -> void:
	var who: Node = get_parent()
	var lines: Array[String] = [who.name]
	var health := Health.find_on(who)
	if health:
		lines.append("%d / %d" % [health.current, health.maximum()])
	var statuses := Statuses.find_on(who)
	if statuses:
		var names: Array[String] = []
		for data in statuses.active:
			names.append(data.display_name)
		lines.append(", ".join(names))
	text = "\n".join(lines)
