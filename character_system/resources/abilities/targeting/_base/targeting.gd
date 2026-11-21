@icon("res://character_system/icons/targeting.svg")
class_name Targeting
extends Resource
## Picks an ability's targets.
##
## This base version targets the user. [RadiusTargeting] picks everything within a radius. For
## anything else, extend this class and override [method find], e.g. to hit what the user aims
## at:
## [codeblock]
## class_name AimedTargeting
## extends Targeting
##
## @export var reach := 20.0
##
## func find(ctx: EffectContext) -> Array[Node]:
## 	var user := ctx.source as Node3D
## 	var brain := Component.of(user, Brain) as Brain
## 	var to: Vector3 = user.global_position.move_toward(brain.aim_point, reach)
## 	var query := PhysicsRayQueryParameters3D.create(user.global_position, to)
## 	query.exclude = Hurtbox.rids_of(user)  # Not the user itself.
## 	var hit := user.get_world_3d().direct_space_state.intersect_ray(query)
## 	var targets: Array[Node] = []
## 	if hit:
## 		targets.append(Hurtbox.hit(user, hit.collider).target)
## 	return targets
## [/codeblock]


## Returns the nodes the ability affects. In [param ctx], [member EffectContext.source] is the
## user, [member EffectContext.origin] is the ability, and the target is null.
func find(ctx: EffectContext) -> Array[Node]:
	return [ctx.source]
