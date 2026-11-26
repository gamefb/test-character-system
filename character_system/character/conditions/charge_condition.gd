class_name ChargeCondition
extends Condition
## Passes when the weapon was charged at least this far, e.g. so only a full charge pierces,
## stuns or sets alight.
##
## It reads [member EffectContext.charge], which a [Trigger] with a
## [member Trigger.charge_time] sets, and in a [StatusTrigger] the charge of the hit that set
## it off. With [member Condition.negate] it passes below the mark instead.

## The share of a full charge needed, from 0 to 1. 1 means fully charged.
@export_range(0.0, 1.0, 0.01) var at_least: float = 1.0


func _passes(ctx: EffectContext) -> bool:
	return ctx.hit().charge >= at_least
