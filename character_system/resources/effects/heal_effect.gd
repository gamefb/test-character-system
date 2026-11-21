class_name HealEffect
extends Effect
## Restores health, scaled by magnitude.

## Health restored, before magnitude.
@export var amount: float = 10.0


func _execute(ctx: EffectContext) -> void:
	var health := Component.of(ctx.target, Health) as Health
	if health:
		health.change(amount * ctx.magnitude, ctx)
