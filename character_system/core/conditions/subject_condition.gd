@tool
@abstract
class_name SubjectCondition
extends Condition
## A condition that checks one node: whoever receives the effect, or whoever caused it.
##
## Most conditions are this kind. Extend it and override [method _test]:
## [codeblock]
## class_name IsBurningCondition
## extends SubjectCondition
##
## func _test(node: Node) -> bool:
## 	var statuses := Statuses.find_on(node)
## 	return statuses != null and statuses.has_tag(&"fire")
## [/codeblock]
## Set [member subject] to check whoever caused it instead ("only rangers can apply this"),
## and [member Condition.negate] to flip the result.

## Which side to check: who receives the effect or status, or who caused it.
@export var subject := EffectContext.Role.TARGET


func _passes(ctx: EffectContext) -> bool:
	return _test(ctx.node(subject))


## Override this: return true if the node passes. It may be null or have no components.
@abstract func _test(node: Node) -> bool
