class_name RemoveStatusEffect
extends Effect
## Takes a status away from the target.

## The status to take away.
@export var status: StatusData
## On: only drop one hold, for a permanent source you manage yourself.
## Off: remove it completely (use for cleanses). Zones use status_while_inside instead.
@export var drop_hold_only := false


func _execute(ctx: EffectContext) -> void:
	var statuses := Component.of(ctx.target, Statuses) as Statuses
	if statuses:
		if drop_hold_only:
			statuses.drop_hold(status)
		else:
			statuses.remove(status)
