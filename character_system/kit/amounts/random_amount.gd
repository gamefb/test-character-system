class_name RandomAmount
extends Amount
## A random number from [member low] to [member high], rolled each time the effect runs, e.g.
## 0 to 6 extra damage on every shot.

## The least it can be.
@export var low: float = 0.0
## The most it can be.
@export var high: float = 5.0


func value(_ctx: EffectContext) -> float:
	return randf_range(low, high)
