@tool
class_name ChanceCondition
extends Condition
## Passes some of the time: a critical hit chance, a 1 in 5 chance to set alight.
##
## It rolls again on every check. To roll once for several effects, put it in
## [member StatusTrigger.conditions] or [member AbilityData.conditions] instead of on each
## effect.

## How often it passes: 0 never, 1 always, 0.25 one time in four.
@export_range(0.0, 1.0) var chance: float = 0.25
## Optional. This stat of the node [member Condition.subject] picks is added to
## [member chance], e.g. &"crit_chance" so gear and statuses can raise it.
@export var bonus_stat: StringName


func _test(node: Node) -> bool:
	var odds: float = chance
	if bonus_stat:
		odds += ComponentManager.stat_of(node, bonus_stat)
	return randf() < odds
