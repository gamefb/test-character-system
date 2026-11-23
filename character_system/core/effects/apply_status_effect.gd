class_name ApplyStatusEffect
extends Effect
## Gives the target a status.

## The status to give. A status with duration 0 stays until something removes it,
## so give timed statuses here and passives through zones, items or innate.
@export var status: StatusData


func _execute(ctx: EffectContext) -> void:
	var statuses := Statuses.find_on(ctx.target)
	if statuses:
		statuses.add(status, ctx.source)
