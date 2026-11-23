class_name HealEffect
extends Effect
## Restores health, scaled by magnitude.
##
## Healing goes through the same steps as damage, without types or resistance. The source hears
## [code]giving_healing[/code] and the target [code]receiving_healing[/code] before it lands,
## so statuses can change [member EffectContext.add], [member EffectContext.percent] and
## [member EffectContext.mul] (a curse that halves healing, a talent that adds 20%). After it
## lands they hear [code]gave_healing[/code] and [code]received_healing[/code]. A target that
## is dead, or has a status that blocks [code]healing[/code], isn't healed; use
## [method Health.revive] for the dead.

## Health restored, before scaling and magnitude.
@export var amount: float = 10.0
## Added to [member amount] each time it runs, e.g. a [PoolAmount] for 30% of the health the
## target is missing, or a [HitAmount] for a quarter of the damage just dealt (life steal).
@export var scaling: Array[Amount] = []


func _execute(ctx: EffectContext) -> void:
	var health := Component.of(ctx.target, Health) as Health
	if not health or health.is_dead() or health.manager.blocks.has(&"healing"):
		return
	ctx.damage_type = &""
	ctx.reset_amount(Amount.total(amount, scaling, ctx) * ctx.magnitude)
	ComponentManager.notify(ctx.source, &"giving_healing", ctx)
	ComponentManager.notify(ctx.target, &"receiving_healing", ctx)
	ctx.reset_amount(ctx.resolve())
	health.change(ctx.amount, ctx)
	ComponentManager.notify(ctx.source, &"gave_healing", ctx)
	ComponentManager.notify(ctx.target, &"received_healing", ctx)
