class_name AnyCondition
extends Condition
## Passes when at least one of [member conditions] passes: "the target is wet OR below half
## health".
##
## A list of conditions normally needs all of them to pass. Put the alternatives in here to
## need only one. An empty list never passes.

## The alternatives. One passing is enough.
@export var conditions: Array[Condition] = []


func _passes(ctx: EffectContext) -> bool:
	for c in conditions:
		if c and c.check(ctx):
			return true
	return false
