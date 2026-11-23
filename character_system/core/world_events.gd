class_name WorldEvents
extends RefCounted
## Every host's events in one place: any death, any kill, any ability used.
##
## Each event a [ComponentManager] sends is also emitted here, with the host it was sent to.
## Use it for things that watch the whole level rather than one character: experience for
## kills, quest counters, a kill feed, achievements, a director that spawns more enemies.
## [codeblock]
## func _ready() -> void:
## 	WorldEvents.event(&"died").connect(_on_anything_died)
##
## func _on_anything_died(who: Node, ctx: EffectContext) -> void:
## 	if who.is_in_group(&"enemy") and ctx and ctx.source == player:
## 		experience += 25
## [/codeblock]
## Nothing needs adding to the scene or the project settings: the signals live on the scene
## tree's root. As with any signal, a connection ends by itself when the listener is freed.
## [br][br]To hear one character's events only, use its own signals:
## [method ComponentManager.event], or [method Component.on] from a component.

# Event -> the name of its signal on the root. Only names are kept here; the connections
# belong to the root, so they end with the game.
static var _signals: Dictionary[StringName, StringName] = {}


## The signal for one event from every host, e.g. [code]WorldEvents.event(&"died")[/code].
## Connect a method that takes the host and the event's [EffectContext], which is null for
## events sent without one: [code]func(host: Node, ctx: EffectContext)[/code].
static func event(event_name: StringName) -> Signal:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var signal_name: StringName = _signals.get_or_add(
			event_name, StringName("world_event_" + event_name))
	if not root.has_user_signal(signal_name):
		root.add_user_signal(signal_name, [
			{ "name": "host", "type": TYPE_OBJECT }, { "name": "ctx", "type": TYPE_OBJECT },
		])
	return Signal(root, signal_name)


## Emits an event for its listeners. [method ComponentManager.send] calls this; you don't
## need to.
static func emit(host: Node, event_name: StringName, ctx: EffectContext) -> void:
	if _signals.has(event_name):
		event(event_name).emit(host, ctx)
