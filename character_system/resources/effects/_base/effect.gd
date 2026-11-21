@icon("res://character_system/icons/effect.svg")
class_name Effect
extends Resource
## One instant change to a target: damage, healing, a status, and so on.
##
## Effects are resources, so weapons, abilities, statuses and zones all set them up in the
## Inspector. Code calls [method apply], which checks [member conditions] first. To make your
## own, extend this class and override [method _execute]. It must cope with a target that lacks
## the component it needs, so any effect can be used on any node.
##
## [codeblock]
## class_name LaunchEffect
## extends Effect
##
## @export var strength := 5.0
##
## func _execute(ctx: EffectContext) -> void:
## 	var movement := Component.of(ctx.target, Movement) as Movement
## 	if movement:  # Walls and props have no Movement.
## 		movement.push(Vector3.UP * strength * ctx.magnitude)
## [/codeblock]
##
## [b]Where effects run.[/b] The same effect resource works in all of these:
## [br]- weapons: [member Hitscan.effects], on whatever the shot hits,
## [br]- abilities: [member AbilityData.effects], on each target,
## [br]- statuses: [member StatusData.on_apply], [member StatusData.on_tick],
## [member StatusData.on_remove] and [member StatusTrigger.effects],
## [br]- zones: [member EffectZone.on_enter] and [member EffectZone.on_exit],
## [br]- your own code, with [method apply_all] and a new [EffectContext].
## [br]Make the numbers [code]@export[/code] variables, and scale amounts by
## [member EffectContext.magnitude] so stacks and headshots strengthen them.

## The effect only runs if all of these pass.
@export var conditions: Array[Condition] = []


## Applies each effect in order with the same context, so a later effect sees what an earlier
## one changed. Each effect checks its own [member conditions].
static func apply_all(effects: Array[Effect], ctx: EffectContext) -> void:
	for e in effects:
		e.apply(ctx)


## Runs the effect if all [member conditions] pass. Callers use this, never [method _execute].
## The effect is one resource shared by every user, so it must not keep anything from one
## call to the next; per-call values belong in [param ctx].
func apply(ctx: EffectContext) -> void:
	if Condition.all_pass(conditions, ctx):
		_execute(ctx)


## Override this to make the change. If the target lacks what you need, do nothing.
func _execute(_ctx: EffectContext) -> void:
	pass
