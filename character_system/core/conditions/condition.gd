@tool
@icon("res://character_system/icons/condition.svg")
@abstract
class_name Condition
extends DataResource
## A yes/no check, used to gate effects and statuses.
##
## [Effect] uses its [member Effect.conditions] to decide whether it runs, and [StatusData] uses
## [member StatusData.apply_conditions] to decide whether it can be applied. Turn on
## [member negate] to flip the answer. The built-in ones are [HasTagCondition],
## [StatCondition], [PoolBelowCondition], [ChanceCondition], [HitCondition],
## [ChargeCondition], [IsHostileCondition] and [AnyCondition].
##
## [b]Making your own.[/b] A check on one node, such as "is burning", extends
## [SubjectCondition] and overrides [method SubjectCondition._test]; the Inspector then also
## offers which side to check. A check that needs both sides, or the hit itself, extends this
## class and overrides [method _passes]:
## [codeblock]
## class_name IsCloseCondition
## extends Condition
##
## @export var within := 3.0
##
## func _passes(ctx: EffectContext) -> bool:
## 	var from := ctx.source as Node3D
## 	var to := ctx.target as Node3D
## 	return from and to and from.global_position.distance_to(to.global_position) <= within
## [/codeblock]
## Either way [member negate] is applied for you, by [method check].

## Flip the result ("target is NOT wet").
@export var negate := false


## True if every condition passes. An empty list always passes.
static func all_pass(conditions: Array[Condition], ctx: EffectContext) -> bool:
	for c in conditions:
		if not c.check(ctx):
			return false
	return true


## Whether the condition passes for [param ctx], with [member negate] applied. Callers use
## this, never [method _passes].
func check(ctx: EffectContext) -> bool:
	return _passes(ctx) != negate


## Override this: return true if [param ctx] passes. Either side may be null or have no
## components. Leave [member negate] to [method check].
@abstract func _passes(ctx: EffectContext) -> bool
