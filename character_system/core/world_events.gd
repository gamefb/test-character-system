class_name WorldEvents
extends RefCounted
## Hears an event from every host in the game: any death, any kill, any ability used.
##
## Every event a [ComponentManager] sends also arrives here, with the host it was sent to. Use
## it for things that watch the whole level rather than one character: experience for kills,
## quest counters, a kill feed, achievements, a director that spawns more enemies.
## [codeblock]
## func _ready() -> void:
## 	WorldEvents.on(&"died", _on_anything_died)
##
## func _on_anything_died(who: Node, ctx: EffectContext) -> void:
## 	if who.is_in_group(&"enemy") and ctx and ctx.source == player:
## 		experience += 25
## [/codeblock]
## Nothing needs adding to the scene or the project settings. A listener whose object has been
## freed is dropped by itself, so a level script that passes one of its own methods never has
## to call [method off]. Listeners outlive a change of scene for as long as their object does.
## [br][br]To hear one character's events only, subscribe on its manager instead:
## [method ComponentManager.subscribe], or [method Component.on] from a component.

# The listeners are kept on the scene tree's root, so they're freed with the game.
const _META := &"_character_system_world_events"

# How many listeners there are, so an event nobody listens for costs one comparison. Only the
# count is static: the listeners themselves must not be (see _listeners).
static var _count: int = 0


## Calls [param method] each time [param event] is sent to any host. The method takes the host
## and the event's [EffectContext], which is null for events sent without one:
## [code]func(host: Node, ctx: EffectContext)[/code]. Subscribing the same method twice does
## nothing.
## [br][br]Pass a method of the listening object where you can. A lambda that uses the object
## it was written in is dropped with that object too, but one that doesn't is never dropped:
## remove it with [method off].
static func on(event: StringName, method: Callable) -> void:
	var list: Array = _listeners().get_or_add(event, [])
	for entry: Array in list:
		if entry[0] == method:
			return
	list.append([method, owner_of(method)])
	_count += 1


## Stops [param method] hearing [param event].
static func off(event: StringName, method: Callable) -> void:
	var listeners: Dictionary = _listeners()
	var list: Array = listeners.get(event, [])
	for i in list.size():
		if list[i][0] == method:
			list.remove_at(i)
			_count -= 1
			break
	if list.is_empty():
		listeners.erase(event)


## Passes an event on to its listeners. [method ComponentManager.send] calls this; you don't
## need to.
static func emit(host: Node, event: StringName, ctx: EffectContext) -> void:
	if _count <= 0:
		return
	var listeners: Dictionary = _listeners()
	if not listeners.has(event):
		return
	for entry: Array in listeners[event].duplicate():
		if is_alive(entry[0], entry[1]):
			entry[0].call(host, ctx)
		else:
			off(event, entry[0])  # Its object was freed.


## The id of the object [param method] belongs to: for a lambda, the object it was written
## in. Taken when a listener subscribes, so [method is_alive] can tell later whether that
## object is still there. 0 if it has none.
static func owner_of(method: Callable) -> int:
	var object: Object = method.get_object()
	return object.get_instance_id() if object else 0


## True if a listener can still be called: the object recorded by [method owner_of] hasn't
## been freed.
static func is_alive(method: Callable, owner: int) -> bool:
	return is_instance_id_valid(owner) if owner else method.is_valid()


# Event -> [Callable, owner id] pairs, or an empty Dictionary when there's no scene tree.
static func _listeners() -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if not tree or not tree.root:
		return {}
	if not tree.root.has_meta(_META):
		tree.root.set_meta(_META, {})
	return tree.root.get_meta(_META)
