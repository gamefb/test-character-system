class_name StatusTrigger
extends Resource
## Runs effects when the status holder takes part in an event.
##
## Add it to [member StatusData.triggers]. [member event] lists the built-in events.

## The event to react to. Built in: [code]dealing_damage[/code] and [code]taking_damage[/code]
## (before a hit lands), [code]dealt_damage[/code] and [code]took_damage[/code] (after),
## [code]killed[/code] when the holder deals a killing blow, [code]died[/code] when something
## kills the holder, the four healing events ([code]giving_healing[/code],
## [code]receiving_healing[/code], [code]gave_healing[/code], [code]received_healing[/code])
## and [code]ability_used[/code]. [method Component.on] lists them all. Send your own
## with [method ComponentManager.notify]. Triggers ignore the events that carry no context,
## such as [code]started[/code] and [code]inventory_changed[/code].
@export var event: StringName
## The trigger only runs if all of these pass. They're checked once, before any effect, so a
## [ChanceCondition] here rolls once for the whole trigger. The target is whoever
## [member affects_other] picks, and a [HitCondition] reads the hit
## that set the trigger off.
@export var conditions: Array[Condition] = []
## Off: effects hit the holder. On: they hit the other side (the attacker or the victim).
@export var affects_other := false
## Also react to events caused by statuses, such as burn ticks. Use for shields and
## damage modifiers only: two damaging triggers with this on would set each other off, until
## the chain is cut at [constant EffectContext.MAX_DEPTH].
@export var react_to_statuses := false
## Run in order each time the event happens. [member EffectContext.cause] holds the
## event's own context, which [ModifyAmountEffect] changes and [HitAmount] reads.
@export var effects: Array[Effect] = []
