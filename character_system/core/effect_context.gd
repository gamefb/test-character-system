@icon("res://character_system/icons/effect_context.svg")
class_name EffectContext
extends RefCounted
## Who did what to whom, and how strongly: passed to every effect, condition and event.
##
## [member source] caused it (null for the environment), [member target] receives it, and
## [member origin] is the ability, status or item behind it. Damage and healing carry the
## number being worked out in [member amount], which statuses and components change through
## [member add], [member percent] and [member mul] before it lands.
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
## [b]Changing a hit before it lands.[/b] In [code]dealing_damage[/code] and
## [code]taking_damage[/code], change the three totals, never [member amount] itself:
## [codeblock]
## func _on_taking_damage(ctx: EffectContext) -> void:
## 	ctx.add -= 3.0      # Armour: 3 less.
## 	ctx.percent += 0.2  # Marked: 20% more. Several of these add up.
## 	ctx.mul *= 0.5      # Shield: half of everything.
## [/codeblock]
## The hit then lands for (amount + add) × (1 + percent) × mul, the same formula stats use, so
## the result doesn't depend on which status was applied first. See [method resolve].
##
## [b]Sources can die.[/b] A status may outlive whoever applied it, and a rocket whoever fired
## it. Building a context is where that is settled: a node that has been freed becomes null
## here, so effects, conditions and listeners get a [member source] and a [member target]
## that are each a live node or null, and only need the null check.

## The two nodes an effect involves. Conditions and amounts export one to say which they read.
enum Role {
	## Whoever receives the effect or status.
	TARGET,
	## Whoever caused it. Null for the environment.
	SOURCE,
}

## How many status triggers may set each other off in a row before the chain is cut. It only
## matters for triggers with [member StatusTrigger.react_to_statuses] on, which could otherwise
## loop forever.
const MAX_DEPTH := 8

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
## The damage or healing being worked out. Before it lands this is the effect's own number;
## afterwards it's what actually landed, e.g. for damage numbers.
var amount: float = 0.0
## Flat change to [member amount], set by statuses and components before it lands. Negative for
## armour.
var add: float = 0.0
## Percentage change to [member amount]: 0.2 is 20% more, -0.2 is 20% less. Several add up
## before they're applied, so two +50% bonuses make +100%.
var percent: float = 0.0
## Multiplies the total, e.g. 0.5 for a shield that halves everything, 2 for a critical hit.
var mul: float = 1.0
## The kind of damage, e.g. &"fire". Set by [DamageEffect]; empty for anything else.
## [HitCondition] tests it.
var damage_type: StringName
## Labels on this hit, e.g. &"head" from a [Hurtbox], &"melee" from a [DamageEffect] or
## &"crit" from a [ModifyAmountEffect]. [HitCondition] tests them; your damage numbers can
## colour by them.
var tags: Array[StringName] = []
## Where the hit landed, in world space. [constant Vector3.INF] when nothing recorded it, e.g.
## for a status tick. Use [method hit_position] to always get a point.
var position := Vector3.INF
## The surface direction at [member position], for decals and sparks. Zero if unknown.
var normal := Vector3.ZERO
## True if a status caused this. Most status triggers ignore these, which prevents loops.
var from_status := false
## For effects run by a status trigger: the context of the event that set it off, such as
## the hit for &"taking_damage". [ModifyAmountEffect] changes its totals.
var cause: EffectContext
## How many status triggers led to this one. See [constant MAX_DEPTH].
var depth: int = 0
## For events that start something timed, such as [code]weapon_started[/code] and
## [code]ability_cast_started[/code]: the seconds until it goes off. 0 when it is instant.
var duration: float = 0.0
## How far what caused this was charged, from 0 to 1. 0 for anything that doesn't charge. A
## [Trigger] with a [member Trigger.charge_time] sets it, and it does nothing by itself: a
## [ChargeAmount] or a [ChargeCondition] on an effect decides what a charge is worth.
var charge: float = 0.0


## [param p_source] caused it, [param p_target] receives it, and [param p_origin] is the
## ability, status or item behind it. A node that has already been freed counts as null, so a
## status whose applier is gone can still build its context. The two have no type because
## GDScript refuses a freed node for a typed parameter.
func _init(p_source: Variant = null, p_target: Variant = null, p_origin: Resource = null) -> void:
	source = p_source if is_instance_valid(p_source) else null
	target = p_target if is_instance_valid(p_target) else null
	origin = p_origin


## The node in [param role]: [member source] or [member target].
func node(role: Role) -> Node:
	return source if role == Role.SOURCE else target


## The hit this is about: [member cause] inside a status trigger, otherwise this context.
## Conditions and amounts use it so the same resource works in both places:
## [codeblock]
## func _passes(ctx: EffectContext) -> bool:
## 	return ctx.hit().damage_type == &"fire"
## [/codeblock]
func hit() -> EffectContext:
	return cause if cause else self


## True if this hit has [param tag].
func has_tag(tag: StringName) -> bool:
	return tag in tags


## [member amount] with [member add], [member percent] and [member mul] applied:
## (amount + add) × (1 + percent) × mul, never below 0. [DamageEffect] and [HealEffect] call
## it once every listener has had its say.
func resolve() -> float:
	return maxf((amount + add) * (1.0 + percent) * mul, 0.0)


## Where the hit landed: [member position] if it was recorded, otherwise where the target is.
## Zero if neither is known.
func hit_position() -> Vector3:
	if position.is_finite():
		return position
	var node := target as Node3D
	return node.global_position if node and node.is_inside_tree() else Vector3.ZERO


## Clears the running totals before a new number is worked out. Effects call this.
func reset_amount(value: float) -> void:
	amount = value
	add = 0.0
	percent = 0.0
	mul = 1.0
