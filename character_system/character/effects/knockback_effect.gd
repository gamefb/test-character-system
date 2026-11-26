class_name KnockbackEffect
extends AmountEffect
## Pushes the target away from the source, e.g. on a shotgun blast or an explosion.
##
## Its [member AmountEffect.amount] is the sideways speed of the push, in metres per second.
## [member AmountEffect.scaling] adds to it: a [StatAmount] for a shove that grows with a stat,
## a [ChargeAmount] for one that grows with the charge.

## Upward speed added, so the target lifts off the ground a little.
@export var lift: float = 2.0


func _execute(ctx: EffectContext) -> void:
	var target := ctx.target as Node3D
	var from := ctx.source as Node3D
	if not target or not from:
		return
	var away: Vector3 = from.global_position.direction_to(target.global_position)
	away = away.slide(Vector3.UP).normalized()
	var push: Vector3 = away * total(ctx) + Vector3.UP * lift
	var motor := CharacterMotor.find_on(target)
	if motor:
		motor.push(push)
	elif target is RigidBody3D:
		target.apply_central_impulse(push * target.mass)
