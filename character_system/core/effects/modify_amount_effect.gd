@tool
class_name ModifyAmountEffect
extends Effect
## Changes the damage or healing of the hit that set off a status trigger.
##
## Use it in a trigger on an event sent before a hit lands: [code]dealing_damage[/code] (crits,
## bonus damage), [code]taking_damage[/code] (shields, armour), [code]giving_healing[/code] or
## [code]receiving_healing[/code]. It adds to the totals of [member EffectContext.cause], which
## are applied once every status has had its say: (amount + add) × (1 + percent) × mul. The
## result is the same whichever status was applied first. Outside a trigger there's nothing to
## change, so it does nothing.

## Added to the amount. Negative for armour, e.g. -3.
@export var add: float = 0.0
## Percentage added: 0.2 is 20% more, -0.2 is 20% less. Percentages from different statuses add
## up, so two +50% bonuses make +100%.
@export var percent: float = 0.0
## Multiplies the total, e.g. 0.5 halves it and 2 doubles it. Multipliers from different
## statuses multiply each other.
@export var mul: float = 1.0
## On: each stack of the status counts, so 3 stacks of "+5%" make +15%. Off: it applies once
## however many stacks there are.
@export var per_stack := false
## Optional. A label added to the hit, e.g. &"crit", for [HitCondition] and for your damage
## numbers to colour by.
@export var tag: StringName


func _execute(ctx: EffectContext) -> void:
	var hit: EffectContext = ctx.cause
	if not hit:
		return
	var stacks: float = ctx.magnitude if per_stack else 1.0
	hit.add += add * stacks
	hit.percent += percent * stacks
	hit.mul *= pow(mul, stacks)
	if tag and tag not in hit.tags:
		hit.tags.append(tag)
