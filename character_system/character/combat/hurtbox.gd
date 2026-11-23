@tool
@icon("res://character_system/icons/hurtbox.svg")
class_name Hurtbox
extends Area3D
## An optional hit zone, such as a head or armor plate, that passes hits on to its character.
##
## Characters without hurtboxes are hit through their own body collider. [member multiplier]
## scales effects that land here, e.g. 2 for headshots, and [member tags] label the hit so
## statuses can react to it ("headshots set the target alight").
##
## It also holds the ray that every shot uses, [method raycast], which decides what a shot
## stops at.

## How many things one ray can pass through before it gives up.
const MAX_PASSED_THROUGH := 32

## The character this belongs to. Defaults to the scene root.
@export var character: Node
## Scales effects that land here, e.g. 2.0 for a headshot.
@export var multiplier: float = 1.0
## Labels put on every hit that lands here, e.g. &"head" or &"weak_point". They end up in
## [member EffectContext.tags], where [HitCondition] tests them.
@export var tags: Array[StringName] = []


## Builds the [EffectContext] for a hit on [param collider], resolving a hurtbox to its character.
## [param origin] is what dealt it, e.g. the weapon's [ItemData], so a kill feed can name it.
## [param source] is who dealt it; one that has been freed since, such as the shooter of a
## rocket still in the air, counts as null.
## Pass [param position] and [param normal] when the hit has a point, e.g. from a ray, so
## effects can spawn sparks there.
static func hit(source: Variant, collider: Object, origin: Resource = null,
		position := Vector3.INF, normal := Vector3.ZERO) -> EffectContext:
	var ctx := EffectContext.new(source, collider as Node, origin)
	if collider is Hurtbox:
		ctx.target = collider.character
		ctx.magnitude = collider.multiplier
		ctx.tags = collider.tags.duplicate()
	ctx.position = position
	ctx.normal = normal
	return ctx


## Casts the ray of [param query] and returns the first thing a shot stops at, in the form
## [method PhysicsDirectSpaceState3D.intersect_ray] uses, or an empty dictionary. The ray
## passes through what [method stops_shots] says no to: areas that aren't hurtboxes, and
## characters that can't be targeted, such as the dead. [Hitscan], [Projectile] and the
## [PlayerBrain]'s aim all look through this.
static func raycast(space: PhysicsDirectSpaceState3D,
		query: PhysicsRayQueryParameters3D) -> Dictionary:
	query.collide_with_areas = true  # Hurtboxes are areas.
	for i in MAX_PASSED_THROUGH:
		var found: Dictionary = space.intersect_ray(query)
		if not found or stops_shots(found.collider):
			return found
		query.exclude += [found.rid]
	return {}


## Whether a shot stops at [param collider]. A [Hurtbox] and a body do, unless a status on
## their character blocks [code]targeting[/code], as Dead does. Any other area doesn't, so
## trigger volumes and detection ranges never soak up shots. A wall always does.
static func stops_shots(collider: Object) -> bool:
	if collider is Area3D and not collider is Hurtbox:
		return false
	return not ComponentManager.blocked(
			collider.character if collider is Hurtbox else collider, &"targeting")


## RIDs of a character's body and hurtboxes, so its own shots can ignore them. It searches the
## whole character, so call it once (e.g. when a weapon is equipped), not on every shot.
static func rids_of(character: Variant) -> Array[RID]:
	var rids: Array[RID] = []
	if not is_instance_valid(character) or not character is Node:
		return rids
	if character is CollisionObject3D:
		rids.append(character.get_rid())
	for node in character.find_children("*", "Hurtbox", true, false):
		rids.append(node.get_rid())
	return rids


func _ready() -> void:
	if not character and not Engine.is_editor_hint():
		character = owner


func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint():
		NameCheck.suggest(self, property)  # Tags become a list to pick from.
