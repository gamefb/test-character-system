@icon("res://character_system/icons/condition.svg")
@abstract
class_name Condition
extends Resource
## A yes/no check on a node, used to gate effects and statuses.
##
## [Effect] uses its [member Effect.conditions] to decide whether it runs, and [StatusData] uses
## [member StatusData.apply_conditions] to decide whether it can be applied. To make your own,
## extend this class and override [method _test].
##
## [codeblock]
## class_name IsBurningCondition
## extends Condition
##
## func _test(node: Node) -> bool:
## 	var statuses := Component.of(node, Statuses) as Statuses
## 	return statuses != null and statuses.has_tag(&"fire")
## [/codeblock]
##
## Set [member subject] to check whoever caused it instead ("only rangers can apply this"),
## and [member negate] to flip the result. The built-in ones are [HasTagCondition],
## [StatCondition], [HealthBelowCondition] and [IsHostileCondition].
##
## A check that needs both sides, such as "the source is hostile to the target", overrides
## [method check] instead and reads [member EffectContext.source] and
## [member EffectContext.target] itself. [IsHostileCondition] is a short example.

enum Subject {
	## Whoever receives the effect or status.
	TARGET,
	## Whoever caused it. Null for the environment.
	SOURCE,
}

## Which side to check: who receives the effect or status, or who caused it.
@export var subject := Subject.TARGET
## Flip the result ("target is NOT wet").
@export var negate := false


## True if every condition passes. An empty list always passes.
static func all_pass(conditions: Array[Condition], ctx: EffectContext) -> bool:
	for c in conditions:
		if not c.check(ctx):
			return false
	return true


## Tests the node [member subject] picks and applies [member negate]. Override this
## instead of [method _test] for a check that compares both sides.
func check(ctx: EffectContext) -> bool:
	var node: Node = ctx.target if subject == Subject.TARGET else ctx.source
	return _test(node) != negate


## Override this: return true if the node passes. It may be null or have no components.
func _test(_node: Node) -> bool:
	return true
