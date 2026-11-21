class_name StatCondition
extends Condition
## Passes if the node's [member stat] is at least [member value].
##
## For example, [code]resist_fire[/code] at least 1. Turn on [member Condition.negate] for
## "below", e.g. "can only burn if resist_fire is below 1".

## The stat to read, e.g. &"resist_fire".
@export var stat: StringName
## Passes when the stat is at least this.
@export var value: float = 0.0


func _test(node: Node) -> bool:
	return ComponentManager.stat_of(node, stat) >= value
