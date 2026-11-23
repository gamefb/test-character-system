class_name PoolAmount
extends Amount
## A share of what is in a [Pool], such as 2% of the target's maximum health for a bleed, or
## more damage the less mana the caster has left. Health is the pool named
## [code]health[/code].

enum Part {
	## What the pool holds now.
	CURRENT,
	## How far the pool is below its maximum.
	MISSING,
	## The most the pool can hold.
	MAXIMUM,
}

## Whose pool to read.
@export var of := Condition.Subject.TARGET
## The pool's name.
@export var pool: StringName = &"health"
## Which number of the pool to take a share of.
@export var part := Part.MAXIMUM
## The share: 0.1 is 10%.
@export var fraction: float = 0.1


func value(ctx: EffectContext) -> float:
	var found := Pool.named(ctx.source if of == Condition.Subject.SOURCE else ctx.target, pool)
	if not found:
		return 0.0
	match part:
		Part.CURRENT:
			return found.current * fraction
		Part.MISSING:
			return (found.maximum() - found.current) * fraction
	return found.maximum() * fraction
