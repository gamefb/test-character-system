class_name ChangePoolEffect
extends Effect
## Adds to or takes from one of the target's [Pool]s, e.g. a mana potion, a stamina drain or a
## shield recharge. Targets without that pool are left alone.

## The pool to change, e.g. &"mana". Matches [member Pool.pool].
@export var pool: StringName = &"mana"
## Added to the pool, before scaling and magnitude. Negative takes away.
@export var amount: float = 10.0
## Added to [member amount] each time it runs, e.g. a [StatAmount] of the target's max_mana for
## a share of the whole pool.
@export var scaling: Array[Amount] = []


func _execute(ctx: EffectContext) -> void:
	var found := Pool.named(ctx.target, pool)
	if found:
		found.change(Amount.total(amount, scaling, ctx) * ctx.magnitude)
