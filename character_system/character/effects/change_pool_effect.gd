@tool
class_name ChangePoolEffect
extends AmountEffect
## Adds [method AmountEffect.total] to one of the target's [Pool]s, or takes it away when the
## amount is negative: a mana potion, a stamina drain or a shield recharge. Targets without
## that pool are left alone.

## The pool to change, e.g. &"mana". Matches [member Pool.pool].
@export var pool: StringName = &"mana"


func _execute(ctx: EffectContext) -> void:
	var found := Pool.named(ctx.target, pool)
	if found:
		found.change(total(ctx))
