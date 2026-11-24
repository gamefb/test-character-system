@tool
class_name PoolBelowCondition
extends Condition
## Passes while a [Pool] is below a share of its maximum, e.g. health under half for an
## execute, or mana under a fifth. Health is the pool named [code]health[/code].

## The pool's name.
@export var pool: StringName = &"health"
## The share of the maximum the pool must be below.
@export_range(0.0, 1.0) var fraction: float = 0.5


func _test(node: Node) -> bool:
	var found := Pool.named(node, pool)
	return found != null and found.current < found.maximum() * fraction
