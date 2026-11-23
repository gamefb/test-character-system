class_name RemoveStatusEffect
extends Effect
## Takes a status away from the target: one status, or every status with a tag.

## The status to take away. Leave empty to go by [member tag] alone.
@export var status: StatusData
## Every status with this tag is taken away too, e.g. &"poison" for an antidote that cures
## every kind of poison.
@export var tag: StringName
## On: only drop one hold of [member status], for a permanent source you manage yourself.
## Off: remove it completely (use for cleanses). Zones use status_while_inside instead.
@export var drop_hold_only := false


func _execute(ctx: EffectContext) -> void:
	var statuses := Component.of(ctx.target, Statuses) as Statuses
	if not statuses:
		return
	if status:
		if drop_hold_only:
			statuses.drop_hold(status)
		else:
			statuses.remove(status)
	if tag:
		statuses.remove_tagged(tag)
