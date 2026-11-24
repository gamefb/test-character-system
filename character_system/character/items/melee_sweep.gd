@tool
@icon("res://character_system/icons/melee_sweep.svg")
class_name MeleeSweep
extends WeaponDelivery
## Hits everything inside [member shape] on each [Trigger] shot, e.g. a sword swing.
##
## The shape sits [member offset] in front of the item and turns with it. Each character is hit
## once per swing, through the most vulnerable part inside the shape, so a [Hurtbox] head inside
## the swing scales the effects by its multiplier. The wielder is never hit.

## The space a swing covers, e.g. a box about a metre across.
@export var shape: Shape3D:
	set(value):
		shape = value
		update_configuration_warnings()
## Where the shape's centre sits, relative to the item. The item's forward is -Z.
@export var offset := Vector3(0, 0, -1)


func _warnings() -> PackedStringArray:
	var out: PackedStringArray = super()
	if not shape:
		out.append("Set the Shape a swing covers.")
	return out


func _fire() -> void:
	if not shape:
		return
	var blade := host as Node3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = blade.global_transform.translated_local(offset)
	query.collision_mask = collision_mask
	query.collide_with_areas = true  # So hurtboxes can be hit.
	query.exclude = _wielder_rids
	# Character -> its context, keeping the strongest when several of its parts are inside.
	var hits: Dictionary[Node, EffectContext] = {}
	for hit in blade.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var ctx: EffectContext = context_for(hit.collider, query.transform.origin)
		if not hits.has(ctx.target) or ctx.magnitude > hits[ctx.target].magnitude:
			hits[ctx.target] = ctx
	for ctx: EffectContext in hits.values():
		Effect.apply_all(effects, ctx)
