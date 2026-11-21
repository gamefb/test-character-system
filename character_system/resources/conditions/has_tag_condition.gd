class_name HasTagCondition
extends Condition
## Passes if the node has a status with [member tag], e.g. &"wet".

## The tag to look for, e.g. &"wet".
@export var tag: StringName


func _test(node: Node) -> bool:
	var statuses := Component.of(node, Statuses) as Statuses
	return statuses != null and statuses.has_tag(tag)
