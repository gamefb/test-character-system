class_name DamageEffect
extends Effect
## Deals damage, scaled by magnitude and reduced by the target's resistance to its type.
##
## Before the hit lands, the source hears [code]dealing_damage[/code] and the target
## [code]taking_damage[/code], so their statuses can change [member EffectContext.amount]. After
## it lands they hear [code]dealt_damage[/code] and [code]took_damage[/code].

## Damage before magnitude and resistance.
@export var amount: float = 10.0
## Matched against the target's resist_<type> stat, e.g. resist_fire.
@export var type: StringName = &"physical"


func _execute(ctx: EffectContext) -> void:
	var health := Component.of(ctx.target, Health) as Health
	if not health:
		return
	var resist_stat := StringName("resist_" + type)
	var resist: float = clampf(ComponentManager.stat_of(ctx.target, resist_stat), 0.0, 1.0)
	ctx.amount = amount * ctx.magnitude * (1.0 - resist)
	# Before: statuses may change ctx.amount (shields, crits, damage buffs).
	ComponentManager.notify(ctx.source, &"dealing_damage", ctx)
	ComponentManager.notify(ctx.target, &"taking_damage", ctx)
	health.change(-maxf(ctx.amount, 0.0), ctx)
	# After: statuses may react (thorns, on-hit procs).
	ComponentManager.notify(ctx.source, &"dealt_damage", ctx)
	ComponentManager.notify(ctx.target, &"took_damage", ctx)
