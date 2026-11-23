class_name HealthAmount
extends Amount
## A share of someone's health, e.g. 5% of the target's maximum per tick, or a heal for 30% of
## what the user is missing.
##
## It's 0 for anything without a [Health].

enum Part {
	## Health right now.
	CURRENT,
	## The gap between health right now and the maximum.
	MISSING,
	## The maximum, with statuses and items applied.
	MAXIMUM,
}

## Whose health: whoever receives the effect, or whoever caused it.
@export var of := Condition.Subject.TARGET
## Which number to take a share of.
@export var part := Part.MAXIMUM
## The share, e.g. 0.05 for 5%.
@export var fraction: float = 0.1


func value(ctx: EffectContext) -> float:
	var node: Node = ctx.source if of == Condition.Subject.SOURCE else ctx.target
	var health := Component.of(node, Health) as Health
	if not health:
		return 0.0
	match part:
		Part.CURRENT:
			return health.current * fraction
		Part.MISSING:
			return (health.maximum() - health.current) * fraction
	return health.maximum() * fraction
