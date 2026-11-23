class_name DamageEffect
extends Effect
## Deals damage, scaled by magnitude and reduced by the target's resistance to its type.
##
## The number starts as [member amount] plus everything in [member scaling], times
## [member EffectContext.magnitude]. Then, in a fixed order:
## [br]1. The source's [code]bonus_<type>[/code] stat is added as a percentage, e.g.
## [code]bonus_fire[/code] 0.2 for 20% more fire damage.
## [br]2. The source hears [code]dealing_damage[/code] and the target
## [code]taking_damage[/code]. Their statuses and components change
## [member EffectContext.add], [member EffectContext.percent] and [member EffectContext.mul].
## [br]3. The totals are applied: (amount + add) × (1 + percent) × mul.
## [br]4. The target's [code]resist_<type>[/code] stat takes its share: 0.5 halves it, 1 is
## immune, and a negative value is a weakness (-0.5 is 50% more).
## [br]5. The target hears [code]absorbing_damage[/code] with the final number in
## [member EffectContext.amount]. Shields lower it by what they soak up.
## [br]6. [Health] loses what's left, and the source hears [code]dealt_damage[/code] and the
## target [code]took_damage[/code]. A killing blow also sends [code]died[/code] to the target
## and [code]killed[/code] to the source.
## [br][br]Steps 2 and 3 don't depend on the order statuses were applied in. A target with
## no health left, or with a status that blocks [code]damage[/code], is left alone: no damage
## and no events.

const _NO_NAMES: Array = []

# Damage type -> its [bonus, resist] stat names, so they aren't built again for every hit.
static var _stat_names: Dictionary[StringName, Array] = {}

## Damage before scaling, magnitude and resistance.
@export var amount: float = 10.0
## Added to [member amount] each time it runs, e.g. a [StatAmount] for 2 per point of the
## user's strength, or a [PoolAmount] for 5% of the target's health.
@export var scaling: Array[Amount] = []
## Matched against the source's bonus_<type> stat and the target's resist_<type> stat, e.g.
## bonus_fire and resist_fire. [HitCondition] tests it.
@export var type: StringName = &"physical"
## Labels for this hit, e.g. &"melee" or &"explosion", beside any the [Hurtbox] added.
## [HitCondition] tests them, so a status can react to melee hits only.
@export var tags: Array[StringName] = []


func _execute(ctx: EffectContext) -> void:
	var health := Component.of(ctx.target, Health) as Health
	# Nothing left to take, or a status is keeping damage off.
	if not health or health.current <= 0.0 or health.manager.blocks.has(&"damage"):
		return
	# This effect's tags only last while it runs; the hit's own tags (a hurtbox's) stay.
	var own_tags: int = ctx.tags.size()
	for tag in tags:
		if tag not in ctx.tags:
			ctx.tags.append(tag)
	ctx.damage_type = type
	ctx.reset_amount(Amount.total(amount, scaling, ctx) * ctx.magnitude)
	var names: Array = _stat_names.get(type, _NO_NAMES)
	if names.is_empty():
		names = [StringName("bonus_" + type), StringName("resist_" + type)]
		_stat_names[type] = names
	ctx.percent = ComponentManager.stat_of(ctx.source, names[0])
	# Before: both sides add to ctx.add, ctx.percent and ctx.mul (armour, crits, damage buffs).
	ComponentManager.notify(ctx.source, &"dealing_damage", ctx)
	ComponentManager.notify(ctx.target, &"taking_damage", ctx)
	var resist: float = minf(ComponentManager.stat_of(ctx.target, names[1]), 1.0)
	ctx.reset_amount(ctx.resolve() * (1.0 - resist))
	# The number is final: shields soak up what they can.
	ComponentManager.notify(ctx.target, &"absorbing_damage", ctx)
	ctx.amount = maxf(ctx.amount, 0.0)
	health.change(-ctx.amount, ctx)
	# After: statuses may react (thorns, life steal, on-hit procs).
	ComponentManager.notify(ctx.source, &"dealt_damage", ctx)
	ComponentManager.notify(ctx.target, &"took_damage", ctx)
	ctx.tags.resize(own_tags)
