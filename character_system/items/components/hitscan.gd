@tool
@icon("res://character_system/icons/hitscan.svg")
class_name Hitscan
extends ItemComponent
## Fires an instant ray on each [Trigger] shot and applies [member effects] to what it hits.
##
## The ray goes from the item toward the wielder's [member Brain.aim_point]. A hit on a
## [Hurtbox] scales the effects by its multiplier.

## How far the ray reaches, in metres.
@export var max_distance: float = 100.0
## Physics layers the shot can hit. Areas on these layers count too, so hurtboxes
## can be hit. Zones put themselves on no layer, so shots pass through them.
@export_flags_3d_physics var collision_mask: int = 0xffffffff
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
	var to: Vector3 = from + from.direction_to(brain.aim_point) * max_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, _wielder_rids)
	query.collide_with_areas = true  # So hurtboxes can be hit.
	var hit: Dictionary = muzzle.get_world_3d().direct_space_state.intersect_ray(query)
	if hit:
		Effect.apply_all(effects, Hurtbox.hit(wielder, hit.collider))
