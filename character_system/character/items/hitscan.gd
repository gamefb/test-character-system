@tool
@icon("res://character_system/icons/hitscan.svg")
class_name Hitscan
extends ItemComponent
## Fires an instant ray on each [Trigger] shot and applies [member effects] to what it hits.
##
## The ray goes from the item toward the wielder's [member Brain.aim_point]. A hit on a
## [Hurtbox] scales the effects by its multiplier and adds its tags. The hit point is recorded
## in [member EffectContext.position], so a [SpawnSceneEffect] can put sparks there.
## [br][br]For a shotgun, raise [member pellets] and [member spread]: every pellet is its own
## ray and applies the effects by itself.

## How far the ray reaches, in metres.
@export var max_distance: float = 100.0
## Physics layers the shot can hit. Areas on these layers count too, so hurtboxes
## can be hit. Zones put themselves on no layer, so shots pass through them.
@export_flags_3d_physics var collision_mask: int = 0xffffffff
## Rays per shot. Each applies [member effects] to what it hits.
@export_range(1, 20, 1, "or_greater") var pellets: int = 1
## How far, in degrees, a ray may stray from the aim. 0 is perfectly accurate.
@export_range(0.0, 45.0, 0.1, "suffix:°") var spread: float = 0.0
## Applied in order to whatever the ray hits. A [Hurtbox] scales them through
## [member EffectContext.magnitude], e.g. 2 for a headshot.
@export var effects: Array[Effect] = []

# The wielder's body and hurtboxes, so its own shots pass through them. Found once, on equip.
var _wielder_rids: Array[RID] = []


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(effects)


func _requires() -> Array[Script]:
	return [Trigger]


func _start() -> void:
	_wielder_rids = Hurtbox.rids_of(wielder)
	listen((find(Trigger) as Trigger).fired, _fire)


func _fire() -> void:
	var muzzle := host as Node3D
	var from: Vector3 = muzzle.global_position
	var aim: Vector3 = from.direction_to(brain.aim_point)
	for i in pellets:
		var to: Vector3 = from + Projectile.spread_direction(aim, spread) * max_distance
		var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, _wielder_rids)
		var hit: Dictionary = Hurtbox.raycast(muzzle.get_world_3d().direct_space_state, query)
		if hit:
			Effect.apply_all(effects, Hurtbox.hit(wielder, hit.collider,
					item.data if item else null, hit.position, hit.normal))
