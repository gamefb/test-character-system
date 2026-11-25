extends Label3D
## Shows the parent character's name, health and statuses above its head.


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
