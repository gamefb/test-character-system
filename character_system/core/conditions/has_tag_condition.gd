@tool
class_name HasTagCondition
extends SubjectCondition
## Passes if the node has a status with [member tag], e.g. &"wet".

## The tag to look for, e.g. &"wet".
@export var tag: StringName


func _test(node: Node) -> bool:
	var statuses := Statuses.find_on(node)
	return statuses != null and statuses.has_tag(tag)
