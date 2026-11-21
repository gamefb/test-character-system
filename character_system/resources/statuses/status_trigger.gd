class_name StatusTrigger
extends Resource
## Runs effects when the status holder takes part in an event.
##
## Add it to [member StatusData.triggers]. [member event] lists the built-in events.

## The event to react to. Built in: [code]dealing_damage[/code] and [code]taking_damage[/code]
## (before a hit lands), [code]dealt_damage[/code] and [code]took_damage[/code] (after), and
## [code]died[/code] when something dealt the killing blow. Send your own with
## [method ComponentManager.notify] and an [EffectContext]: triggers ignore events sent
## without one, such as [code]started[/code] and [code]inventory_changed[/code].
@export var event: StringName
## Off: effects hit the holder. On: they hit the other side (the attacker or the victim).
@export var affects_other := false
## Also react to events caused by statuses, such as burn ticks. Use for shields and
## damage modifiers only; a damaging trigger with this on can loop forever.
@export var react_to_statuses := false
## Run in order each time the event happens. [member EffectContext.cause] holds the
## event's own context, which [ModifyAmountEffect] changes.
@export var effects: Array[Effect] = []
