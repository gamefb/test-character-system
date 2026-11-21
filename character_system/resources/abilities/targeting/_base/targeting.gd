@icon("res://character_system/icons/targeting.svg")
class_name Targeting
extends Resource
## Picks an ability's targets.
##
## This base version targets the user. Extend it and override [method find] to return what a
## ray, sphere or cone finds.


## Returns the nodes the ability affects. In [param ctx], [member EffectContext.source] is the
## user, [member EffectContext.origin] is the ability, and the target is null.
func find(ctx: EffectContext) -> Array[Node]:
	return [ctx.source]
