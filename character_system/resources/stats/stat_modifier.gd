class_name StatModifier
extends Resource
## A change to one stat while it's applied.
##
## A stat's value is (base + all adds) × all muls. The base comes from the component that owns
## the stat in [method Component._stats]. Statuses apply theirs once per stack; see
## [member StatusData.modifiers].
##
## The built-in stats are [code]max_health[/code], [code]move_speed[/code],
## [code]jump_velocity[/code], [code]air_jumps[/code] and [code]resist_<type>[/code] (e.g.
## [code]resist_fire[/code], where 1 means immune). Your own components add more through
## [method Component._stats].
## Use a negative [member add] or a [member mul] below 1 for penalties. A stat no component
## owns has nothing to change, so the modifier does nothing (the editor warns about the name).

## The stat to change, e.g. &"move_speed".
@export var stat: StringName
## Added to the base value.
@export var add: float = 0.0
## Multiplies the total. 1.5 = +50%.
@export var mul: float = 1.0
