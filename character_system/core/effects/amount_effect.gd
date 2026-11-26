@tool
@abstract
class_name AmountEffect
extends Effect
## An effect with a number: a base amount, plus whatever it scales with.
##
## [DamageEffect], [HealEffect], [ChangePoolEffect] and [KnockbackEffect] are built on it.
## Extend it for an effect of your own that needs a number designers can scale with stats,
## pools or the hit, and read the number for this run with [method total].

## The number before scaling and magnitude.
@export var amount: float = 10.0
## Added to [member amount] each time the effect runs, e.g. a [StatAmount] for 2 per point of
## the user's strength, a [PoolAmount] for 5% of the target's health, or a [HitAmount] for a
## quarter of the damage just dealt.
@export var scaling: Array[Amount] = []


## The number for this run: [member amount] plus [member scaling], times
## [member EffectContext.magnitude] (stacks, a headshot, the edge of a blast).
func total(ctx: EffectContext) -> float:
	return Amount.total(amount, scaling, ctx) * ctx.magnitude
