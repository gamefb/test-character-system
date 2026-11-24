@tool
class_name HitCondition
extends Condition
## Passes when the hit is of a kind: a damage type, a tag, or both.
##
## Use it in a [StatusTrigger] on a damage event, so a ward only blocks fire or a perk only
## rewards headshots. It reads the hit that set the trigger off
## ([method EffectContext.hit]), so [member Condition.subject] isn't used.
## [br][br]Tags come from the [Hurtbox] that was hit ([member Hurtbox.tags]), from the
## [DamageEffect] ([member DamageEffect.tags]) and from earlier [ModifyAmountEffect]s, such as
## &"crit".

## The damage types that pass, e.g. &"fire" and &"lightning". Empty for any type. See
## [member DamageEffect.type].
@export var types: Array[StringName] = []
## The hit must have every one of these tags, e.g. &"head". Empty for any hit.
@export var tags: Array[StringName] = []


func check(ctx: EffectContext) -> bool:
	var hit: EffectContext = ctx.hit()
	var passes: bool = (types.is_empty() or hit.damage_type in types) and tags.all(hit.has_tag)
	return passes != negate
