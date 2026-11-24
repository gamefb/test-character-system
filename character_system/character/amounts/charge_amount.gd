class_name ChargeAmount
extends Amount
## More the further the weapon was charged: nothing at no charge, [member at_full] at a full
## one. This is what makes a charge worth something.
##
## Put it in the scaling of whatever should grow with the charge: a [DamageEffect] for a
## harder hit, a [LaunchProjectileEffect]'s speed scaling for a faster arrow, a
## [KnockbackEffect] for a bigger shove. It reads [member EffectContext.charge], which a
## [Trigger] with a [member Trigger.charge_time] sets, and a projectile passes on to what it
## hits. In an effect run by a [StatusTrigger] it reads the charge of the hit that set it off.

## The amount at a full charge.
@export var at_full: float = 10.0
## How the amount grows, from no charge on the left to a full one on the right, both from 0 to
## 1. Empty: evenly. A curve that stays low and rises late rewards a full draw.
@export var curve: Curve


func value(ctx: EffectContext) -> float:
	var charge: float = ctx.hit().charge
	return at_full * (curve.sample(charge) if curve else charge)
