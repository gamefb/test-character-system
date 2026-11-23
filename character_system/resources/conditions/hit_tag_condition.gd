class_name HitTagCondition
extends Condition
## Passes when the hit has [member tag], e.g. &"head" for a perk that only rewards headshots.
##
## Tags come from the [Hurtbox] that was hit ([member Hurtbox.tags]), from the
## [DamageEffect] ([member DamageEffect.tags]) and from earlier [ModifyAmountEffect]s, such as
## &"crit". Use it in a [StatusTrigger]; it reads the hit that set the trigger off, so
## [member Condition.subject] isn't used.

## The tag to look for on the hit, e.g. &"head".
@export var tag: StringName


func check(ctx: EffectContext) -> bool:
	return ctx.hit().has_tag(tag) != negate
