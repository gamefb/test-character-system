@tool
@abstract
class_name WeaponDelivery
extends ItemComponent
## The part of a weapon that decides what each shot reaches, and runs the effects on it.
##
## [Hitscan] and [MeleeSweep] are two. To make another, such as a cone, a beam or a chain of
## lightning, extend this and write [method _fire]: find what is hit, and for each thing call
## [method context_for] and apply [member effects] to it.
## [codeblock]
## class_name Pulse
## extends WeaponDelivery
## ## Hits whatever a Targeting finds around the wielder, e.g. a shock baton.
##
## @export var targeting: Targeting
##
## func _fire() -> void:
## 	for target in targeting.find(context_for(wielder)):
## 		Effect.apply_all(effects, context_for(target))
## [/codeblock]
## It needs a [Trigger] beside it, and fires each time the trigger does.

## The physics layers it can hit. Every layer by default.
@export_flags_3d_physics var collision_mask: int = 0xffff_ffff
## Applied to each thing hit, in order.
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


## The [EffectContext] for a hit on [param collider] by this weapon: from the wielder, with the
## item as its origin, and a [Hurtbox] resolved to its character. Pass where the hit landed if
## it has a point.
func context_for(collider: Object, position := Vector3.INF,
		normal := Vector3.ZERO) -> EffectContext:
	return Hurtbox.hit(wielder, collider, item.data if item else null, position, normal)


## Called each time the [Trigger] fires. Find what is hit and apply [member effects] to it.
@abstract func _fire() -> void
