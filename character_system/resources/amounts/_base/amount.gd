@icon("res://character_system/icons/effect.svg")
class_name Amount
extends Resource
## A number worked out when an effect runs, instead of typed in: "2 per point of strength",
## "5% of the target's health", "a third of the hit".
##
## Effects with a number have a plain field for it, such as [member DamageEffect.amount], and a
## [code]scaling[/code] list of these beside it. Each one's [method value] is added to the plain
## number, so "10 + 2 per strength" is amount 10 with one [StatAmount] in scaling. The built-in
## ones are [StatAmount], [HealthAmount], [HitAmount] and [RandomAmount]. To make your own,
## extend this class and override [method value]:
## [codeblock]
## class_name DistanceAmount
## extends Amount
## ## More the further away the target is, e.g. for a sniper perk.
##
## @export var per_metre := 0.5
##
## func value(ctx: EffectContext) -> float:
## 	var from := ctx.source as Node3D
## 	var to := ctx.target as Node3D
## 	if not is_instance_valid(from) or not to:
## 		return 0.0
## 	return from.global_position.distance_to(to.global_position) * per_metre
## [/codeblock]
## An amount is one resource shared by every user, so it must not keep anything from one call
## to the next.


## [param base] plus every amount in [param scaling]. Effects call this for their number.
static func total(base: float, scaling: Array[Amount], ctx: EffectContext) -> float:
	var sum: float = base
	for extra in scaling:
		if extra:
			sum += extra.value(ctx)
	return sum


## Override this: return the number for this use. [param _ctx] says who is involved; either
## side may be null or have no components.
func value(_ctx: EffectContext) -> float:
	return 0.0
