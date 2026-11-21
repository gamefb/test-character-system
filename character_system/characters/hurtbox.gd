@icon("res://character_system/icons/hurtbox.svg")
class_name Hurtbox
extends Area3D
## An optional hit zone, such as a head or armor plate, that passes hits on to its character.
##
## Characters without hurtboxes are hit through their own body collider. [member multiplier]
## scales effects that land here, e.g. 2 for headshots.

## The character this belongs to. Defaults to the scene root.
@export var character: Node
## Scales effects that land here, e.g. 2.0 for a headshot.
@export var multiplier: float = 1.0


## Builds the [EffectContext] for a hit on [param collider], resolving a hurtbox to its character.
## [param origin] is what dealt it, e.g. the weapon's [ItemData], so a kill feed can name it.
static func hit(source: Node, collider: Object, origin: Resource = null) -> EffectContext:
	if collider is Hurtbox:
		var ctx := EffectContext.new(source, collider.character, origin)
		ctx.magnitude = collider.multiplier
		return ctx
	return EffectContext.new(source, collider as Node, origin)


## RIDs of a character's body and hurtboxes, so its own shots can ignore them. It searches the
## whole character, so call it once (e.g. when a weapon is equipped), not on every shot.
static func rids_of(character: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if not is_instance_valid(character):
		return rids
	if character is CollisionObject3D:
		rids.append(character.get_rid())
	for node in character.find_children("*", "Hurtbox", true, false):
		rids.append(node.get_rid())
	return rids


func _ready() -> void:
	if not character:
		character = owner
