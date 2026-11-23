@tool
@icon("res://character_system/icons/component.svg")
class_name Attributes
extends Component
## Stats you make up, set in the Inspector: strength, level, crit_chance, spell_power.
##
## Other components own the stats they use ([Health] owns [code]max_health[/code]). This one
## owns whatever you list in [member stats], so a game's own numbers need no script. Once
## listed, a stat works everywhere stats do:
## [br]- statuses and items change it with a [StatModifier],
## [br]- effects scale with it through a [StatAmount] ("2 damage per point of strength"),
## [br]- [StatCondition] and [ChanceCondition] test it,
## [br]- code reads it with [method Component.stat] or [method ComponentManager.stat_of].
## [codeblock]
## var attributes := Component.of(player, Attributes) as Attributes
## attributes.add_base(&"level", 1)  # Level up: everything scaled by level follows.
## [/codeblock]

## Each stat and its value before statuses and items, e.g. { &"strength": 10, &"level": 1 }.
@export var stats: Dictionary[StringName, float] = {}:
	set(value):
		stats = value
		update_stats()


func _stats() -> Dictionary[StringName, float]:
	return stats


## Sets the base value of [param stat_name], adding the stat if it isn't listed yet.
func set_base(stat_name: StringName, value: float) -> void:
	stats[stat_name] = value
	update_stats()


## Adds [param amount] to the base value of [param stat_name], e.g. a point of strength on
## level up.
func add_base(stat_name: StringName, amount: float) -> void:
	set_base(stat_name, stats.get(stat_name, 0.0) + amount)
