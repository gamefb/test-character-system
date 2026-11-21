class_name EffectContext
extends RefCounted
## Who did what to whom, and how strongly: passed to every effect, condition and event.
##
## [member source] caused it (null for the environment), [member target] receives it, and
## [member origin] is the ability, status or item behind it. Damage carries the hit's
## [member amount], which status triggers can change before it lands.
##
## Weapons, abilities, statuses and zones build these for you. Build one yourself to run
## effects from your own code, such as a trap or a cutscene:
## [codeblock]
## @export var effects: Array[Effect] = []
##
## func _on_trap_triggered(body: Node3D) -> void:
## 	Effect.apply_all(effects, EffectContext.new(null, body, null))
## [/codeblock]
## Use a new context for each target. Effects write to it ([member amount]) and events pass it
## on, so it's only meant for one target at a time.
##
## [member source] may have been freed by the time a status ticks. [method Component.of] and the
## [ComponentManager] helpers cope with that; check [code]is_instance_valid(ctx.source)[/code]
## before using it directly.

## Who caused it. Null for the environment. When it deals damage, it hears
## [code]dealing_damage[/code] and [code]dealt_damage[/code].
var source: Node
## Who it happens to. Every effect must cope with a target that has no components, such as
## a wall.
var target: Node
## The ability, status or item it came from, e.g. to show "killed by Fireball". Abilities set
## their [AbilityData], statuses their [StatusData], and weapons their [ItemData].
var origin: Resource
## Scales numeric effects: status stacks, headshot multipliers. 1 = normal strength.
var magnitude: float = 1.0
## The damage about to land. Statuses can change it before it does. [HealEffect] doesn't use it.
var amount: float = 0.0
## True if a status caused this. Most status triggers ignore these, which prevents loops.
var from_status := false
## For effects run by a status trigger: the context of the event that set it off, such as
## the hit for &"taking_damage". [ModifyAmountEffect] changes its [member amount].
var cause: EffectContext


## [param p_source] caused it, [param p_target] receives it, and [param p_origin] is the
## ability, status or item behind it.
func _init(p_source: Node = null, p_target: Node = null, p_origin: Resource = null) -> void:
	source = p_source
	target = p_target
	origin = p_origin
