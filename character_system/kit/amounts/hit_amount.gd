class_name HitAmount
extends Amount
## A share of the hit that set off a status trigger, e.g. heal for a quarter of the damage
## dealt (life steal) or deal back a third of the damage taken (thorns).
##
## Use it in effects run by a [StatusTrigger] on the events sent after a hit lands, such as
## [code]dealt_damage[/code] and [code]took_damage[/code], when [member EffectContext.amount]
## is what actually landed. Outside a trigger there's no hit, so it's 0.

## The share of the hit, e.g. 0.25 for a quarter.
@export var fraction: float = 0.25


func value(ctx: EffectContext) -> float:
	return ctx.cause.amount * fraction if ctx.cause else 0.0
