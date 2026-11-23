@tool
class_name StatAmount
extends Amount
## A stat's value times [member per_point], e.g. 2 damage per point of the user's strength.
##
## The stat is read when the effect runs, with every status and item applied. Any stat works:
## one a component owns, such as [code]max_health[/code], or one you list in
## [member ComponentManager.stats], such as [code]strength[/code] or [code]level[/code].
## [br][br]For numbers that don't grow in a straight line, set [member curve]: the stat is
## looked up on it first. A curve from level 1 to 50 gives damage by level.

## The stat to read, e.g. &"strength".
@export var stat: StringName
## Whose stat: whoever caused the effect, or whoever receives it. A status tick's source is
## whoever applied the status.
@export var of := Condition.Subject.SOURCE
## The amount for each point of the stat. Negative takes away.
@export var per_point: float = 1.0
## Optional. The stat is looked up on this curve, and the result is multiplied by
## [member per_point]. Set the curve's domain to the stat's range, e.g. 1 to 50 for a level.
@export var curve: Curve


func value(ctx: EffectContext) -> float:
	var node: Node = ctx.source if of == Condition.Subject.SOURCE else ctx.target
	var points: float = ComponentManager.stat_of(node, stat)
	if curve:
		points = curve.sample(points)
	return points * per_point
