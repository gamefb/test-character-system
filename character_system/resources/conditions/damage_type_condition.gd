class_name DamageTypeCondition
extends Condition
## Passes when the hit's damage is one of [member types], e.g. so a ward only blocks fire.
##
## Use it in a [StatusTrigger] on a damage event. It reads the hit that set the trigger off,
## so [member Condition.subject] isn't used.

## The damage types that pass, e.g. &"fire" and &"lightning". See [member DamageEffect.type].
@export var types: Array[StringName] = []


func check(ctx: EffectContext) -> bool:
	return (ctx.hit().damage_type in types) != negate
