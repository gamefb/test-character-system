class_name StatModifier
extends Resource
## A change to one stat while it's applied.
##
## A stat's value is (base + all adds) × (1 + all percents) × all muls. The base comes from the
## component that owns the stat in [method Component._stats]. Statuses apply theirs once per
## stack; see [member StatusData.modifiers].
##
## [br][br][b]Which field to use.[/b] [member add] for flat changes ("+20 max health").
## [member percent] for bonuses that should add up ("+10% speed" on three items is +30%).
## [member mul] for changes that should apply to everything else ("half speed while aiming").
##
## [br][br]The built-in stats are [code]max_health[/code], [code]move_speed[/code],
## [code]jump_velocity[/code], [code]air_jumps[/code], [code]cooldown_speed[/code],
## [code]resist_<type>[/code] (e.g. [code]resist_fire[/code], where 1 means immune) and
## [code]bonus_<type>[/code] (e.g. [code]bonus_fire[/code], where 0.2 means 20% more fire
## damage dealt). A [Pool] adds [code]max_<pool>[/code] and [code]<pool>_regen[/code], any
## you list in [member ComponentManager.stats] count too, and your own components add more
## through [method Component._stats].

## The stat to change, e.g. &"move_speed".
@export var stat: StringName
## Added to the base value.
@export var add: float = 0.0
## Percentage added: 0.1 is 10% more, -0.1 is 10% less. Percentages from every modifier of the
## stat add up before they're applied.
@export var percent: float = 0.0
## Multiplies the total. 1.5 = +50%, 0 = none at all.
@export var mul: float = 1.0
## The modifier only counts while all of these pass, e.g. a [PoolBelowCondition] for "faster
## while badly hurt". They're checked on the character that has the modifier, each time the
## stat is read. [signal ComponentManager.stat_changed] isn't emitted when one flips, so UI
## that shows such a stat should read it every frame.
@export var conditions: Array[Condition] = []
