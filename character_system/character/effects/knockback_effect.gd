class_name KnockbackEffect
extends Effect
## Pushes the target away from the source, e.g. on a shotgun blast or an explosion.

## Sideways speed of the push, in metres per second.
@export var strength: float = 8.0
## Added to the strength, as an [AmountEffect]'s scaling is: a [StatAmount] for a shove that
## grows with a stat, a [ChargeAmount] for one that grows with the charge.
@export var scaling: Array[Amount] = []
## Upward speed added, so the target lifts off the ground a little.
@export var lift: float = 2.0


func _execute(ctx: EffectContext) -> void:
	var target := ctx.target as Node3D
	var from := ctx.source as Node3D
	if not target or not from:
		return
	var away: Vector3 = from.global_position.direction_to(target.global_position)
	away = away.slide(Vector3.UP).normalized()
	var sideways: float = Amount.total(strength, scaling, ctx) * ctx.magnitude
	var push: Vector3 = away * sideways + Vector3.UP * lift
	var motor := CharacterMotor.find_on(target)
	if motor:
		motor.push(push)
	elif target is RigidBody3D:
		target.apply_central_impulse(push * target.mass)
