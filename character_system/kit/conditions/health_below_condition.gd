class_name HealthBelowCondition
extends Condition
## Passes if the node's health is below [member fraction] of its maximum.

## 0 to 1. With 0.25, passes when health is below a quarter of the maximum.
@export_range(0.0, 1.0) var fraction: float = 0.5


func _test(node: Node) -> bool:
	var health := Component.of(node, Health) as Health
	return health != null and health.current < health.maximum() * fraction
