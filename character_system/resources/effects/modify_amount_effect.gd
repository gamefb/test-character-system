class_name ModifyAmountEffect
extends Effect
## Changes the damage of the hit that set off a status trigger.
##
## Use it in a trigger on [code]dealing_damage[/code] (crits, bonus damage) or
## [code]taking_damage[/code] (shields, armor). It changes the [member EffectContext.amount] of
## [member EffectContext.cause]. Outside a trigger there's nothing to change, so it does nothing.
## Stacks don't strengthen it: a status with 3 stacks still applies it once.

## The amount is multiplied by [member mul] first, then this is added.
## Negative for shields and armour, e.g. -3.
@export var add: float = 0.0
## Multiplies the amount, e.g. 0.5 halves it and 1.5 adds 50%.
@export var mul: float = 1.0


func _execute(ctx: EffectContext) -> void:
	if ctx.cause:
		ctx.cause.amount = ctx.cause.amount * mul + add
