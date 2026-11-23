class_name RadiusTargeting
extends Targeting
## Targets everything within [member radius] metres of the user, e.g. for a shockwave or a
## healing aura.
##
## With [member hostile_only] on, it only picks what the user's [Faction] fights, so an attack
## spares allies. A user without a Faction can't tell friend from foe, so everything in range
## counts. A character is picked once, however many of its hurtboxes are in range.

## How far it reaches, in metres.
@export var radius: float = 5.0
## Only pick targets the user's Faction is hostile to. Turn it off for a heal that should also
## reach allies.
@export var hostile_only := true
## Also pick the user, e.g. for a party heal.
@export var include_user := false


func find(ctx: EffectContext) -> Array[Node]:
	var user := ctx.source as Node3D
	var found: Array[Node] = []
	if not user:
		return found
	if include_user:
		found.append(user)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), user.global_position)
	query.collide_with_areas = true  # So hurtboxes count.
	query.exclude = Hurtbox.rids_of(user)
	var faction := Faction.find_on(user)
	for hit in user.get_world_3d().direct_space_state.intersect_shape(query, 64):
		# A hurtbox stands for its character.
		var target: Node = hit.collider.character if hit.collider is Hurtbox else hit.collider
		if target in found or ComponentManager.blocked(target, &"targeting"):
			continue
		if hostile_only and faction and not faction.is_hostile(target):
			continue
		found.append(target)
	return found
