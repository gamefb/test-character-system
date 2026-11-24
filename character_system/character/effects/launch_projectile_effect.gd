class_name LaunchProjectileEffect
extends Effect
## Launches a [Projectile] from whoever caused the effect, e.g. a fireball ability.
##
## Put it in [member AbilityData.user_effects]. The projectile starts at the user, raised by
## [member height] and moved [member forward] toward the aim, and flies toward the user's
## [member Brain.aim_point]. A source without a [Brain] launches it at the effect's target, or
## straight ahead if the target is the source itself. The ability is recorded as the origin of
## every hit, so a kill feed can say "killed by Fireball".

## The scene to launch. Its root needs the [Projectile] script.
@export var projectile: PackedScene
## Applied in order to what the projectile hits directly, before the projectile's own effects.
@export var effects: Array[Effect] = []
## Added to the projectile's own speed, in metres per second: a [ChargeAmount] for a bow whose
## arrow flies faster the further it is drawn, a [StatAmount] for a stronger arm.
@export var speed_scaling: Array[Amount] = []
## How high above the user's origin it starts, in metres. About chest height for a character
## whose origin is at its feet.
@export var height: float = 1.2
## How far toward the aim it starts, in metres, so it clears the user's own body.
@export var forward: float = 0.6


func _execute(ctx: EffectContext) -> void:
	var user := ctx.source as Node3D
	if not is_instance_valid(user) or not user.is_inside_tree():
		return
	# From the weapon that fired, if the context says where it is; otherwise from the chest.
	var from_weapon: bool = ctx.position.is_finite()
	var from: Vector3 = ctx.position if from_weapon else user.global_position + Vector3.UP * height
	var toward: Vector3 = from - user.global_basis.z
	var brain := Brain.find_on(user)
	var target := ctx.target as Node3D
	if brain:
		toward = brain.aim_point
	elif target and target != user:
		toward = target.global_position
	if not from_weapon:
		from += from.direction_to(toward) * forward
	# Effects can run inside physics callbacks, where the projectile can't be added yet.
	Projectile.launch.call_deferred(projectile, user, from, toward, effects, ctx.origin,
			ctx.charge, Amount.total(0.0, speed_scaling, ctx))
