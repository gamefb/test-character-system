@tool
@icon("res://character_system/icons/component_manager.svg")
class_name ComponentManager
extends Node
## The hub that connects a host's components.
##
## Add one as a child of every character, item scene or prop, beside its components. They
## register here by themselves; through it they find each other by type, share stats and hear
## events. You never change it to add a new kind of component. It has no settings, and one per
## host is used.
##
## It does three jobs:
## [br]- [b]Lookup.[/b] [method find] returns a component by type.
## [br]- [b]Stats.[/b] Components declare numbers in [method Component._stats]; [method stat]
## returns them with every [StatModifier] applied, and [signal stat_changed] reports changes.
## [br]- [b]Events.[/b] [method send] passes an event to every running component's
## [method Component._on_event].
##
## From other code, use the static helpers [method of], [method notify] and [method stat_of].
## They take any node and do nothing (or return 0) if it has no manager, so they're safe on
## walls, props and freed nodes.
## [codeblock]
## var speed := ComponentManager.stat_of(player, &"move_speed")
## ComponentManager.notify(player, &"level_up", EffectContext.new(null, player))
## ComponentManager.of(player).stat_changed.connect(_on_player_stat_changed)
## [/codeblock]

## Emitted when [param stat_name]'s value may have changed: a modifier for it was added or
## removed, or a component was added, removed or called [method Component.update_stats]. Read the
## new value with [method stat]. Useful for UI, such as a health bar that follows max health.
signal stat_changed(stat_name: StringName)

## True once the host is ready and its components have had the chance to start. At that moment
## every running component also hears the [code]started[/code] event.
var started := false
## The node this manager belongs to (its parent).
var host: Node:
	get:
		return get_parent()

# True while the components first start, before [member started].
var _starting := false
var _components: Array[Component] = []
var _modifiers: Array[StatModifier] = []
var _cache: Dictionary[StringName, float] = {}  # Stat values, cleared whenever anything changes.


## Returns [param node]'s [ComponentManager] child, or null. Safe on null or freed nodes.
static func of(node: Node) -> ComponentManager:
	if is_instance_valid(node):
		for child in node.get_children():
			if child is ComponentManager:
				return child
	return null


## Sends [param event] to [param node]'s components, if it has a [ComponentManager].
##
## Use it for your own events, e.g. [code]&"jumped"[/code] or [code]&"level_up"[/code]. Every
## running component hears it in [method Component._on_event], and status triggers with that
## [member StatusTrigger.event] fire. [param ctx] can be null, but then status triggers ignore
## the event, so pass one if statuses should react to it.
static func notify(node: Node, event: StringName, ctx: EffectContext) -> void:
	var m: ComponentManager = of(node)
	if m:
		m.send(event, ctx)


## Reads [param stat_name] from [param node], or 0 if it has no [ComponentManager].
static func stat_of(node: Node, stat_name: StringName) -> float:
	var m: ComponentManager = of(node)
	return m.stat(stat_name) if m else 0.0


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		_editor_notification(what)
		return
	match what:
		NOTIFICATION_ENTER_TREE:
			for child in host.get_children():
				if child is Component:
					register(child)
			if is_node_ready():
				# Re-entering the tree, e.g. after moving to a new parent.
				_start_all.call_deferred()
		NOTIFICATION_READY:
			if host.is_node_ready():
				_start_all()
			else:
				host.ready.connect(_start_all, CONNECT_ONE_SHOT)
		NOTIFICATION_EXIT_TREE:
			started = false


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	var owners: Dictionary[StringName, String] = {}
	for child in (host.get_children() if host else []):
		# Scripts without @tool don't run in the editor, so only ask the ones that do.
		if child is Component and (child.get_script() as Script).is_tool():
			for stat_name in child._stats():
				if owners.has(stat_name):
					out.append("Both %s and %s own the stat '%s'; the first one's value is used."
							% [owners[stat_name], child.name, stat_name])
				owners[stat_name] = child.name
	if ComponentManager.of(host) != self:
		out.append("Only one ComponentManager per host is used.")
	return out


## The first component on the host that is a [param type] (subclasses count), or null.
## Works before the host is added to the scene too, e.g. to set a spawned enemy's team.
func find(type: Script) -> Component:
	for child in (host.get_children() if host else []):
		if is_instance_of(child, type):
			return child
	return null


## True if a registered (in the scene) component is a [param type]. Used to decide
## whether a component has everything it requires.
func has_registered(type: Script) -> bool:
	return _components.any(func(c: Component) -> bool: return is_instance_of(c, type))


## Sends [param event] to the [method Component._on_event] of every running component.
## Components that are stopped, or not yet started, miss it. From outside the host, use
## [method notify], which also copes with a null node.
func send(event: StringName, ctx: EffectContext) -> void:
	for c in _components.duplicate():
		if c.running:
			c._on_event(event, ctx)


## Current value of a stat: (base + all adds) * all muls. The base comes from the component
## that lists it in [method Component._stats]. With no such component, nothing reads it anyway.
##
## For example, with [member Movement.move_speed] 5 and modifiers [code]add 1[/code],
## [code]mul 1.5[/code] and [code]mul 0.5[/code], [code]move_speed[/code] is
## (5 + 1) × 1.5 × 0.5 = 4.5. Results are cached until something changes, so read it whenever
## you need it instead of keeping a copy.
func stat(stat_name: StringName) -> float:
	if not _cache.has(stat_name):
		var base: float = 0.0
		for c in _components:
			var owned: Dictionary[StringName, float] = c._stats()
			if owned.has(stat_name):
				base = owned[stat_name]
				break
		var add: float = 0.0
		var mul: float = 1.0
		for m in _modifiers:
			if m.stat == stat_name:
				add += m.add
				mul *= m.mul
		_cache[stat_name] = (base + add) * mul
	return _cache[stat_name]


## Applies [param m] until [method remove_modifier] takes it off. [Statuses] does this for
## status modifiers; call it yourself for a one-off change.
##
## Keep the same object to remove it later. Most changes are better as a status (a
## [StatusData] with [member StatusData.modifiers]), which can end by itself and appear on a
## status bar; use this for changes your own code controls, such as aiming down sights.
## [codeblock]
## var aiming := StatModifier.new()
## aiming.stat = &"move_speed"
## aiming.mul = 0.5
## manager.add_modifier(aiming)  # Half speed...
## manager.remove_modifier(aiming)  # ...until this.
## [/codeblock]
func add_modifier(m: StatModifier) -> void:
	_modifiers.append(m)
	_cache.erase(m.stat)
	stat_changed.emit(m.stat)


## Removes one copy of [param m]. A modifier added twice must be removed twice.
func remove_modifier(m: StatModifier) -> void:
	_modifiers.erase(m)
	_cache.erase(m.stat)
	stat_changed.emit(m.stat)


## Re-reads every component's stats and emits [signal stat_changed] for each. Components call
## this through [method Component.update_stats]; you don't need to call it yourself.
func refresh_stats() -> void:
	var names: Array = _cache.keys()
	_cache.clear()
	for c in _components:
		for stat_name in c._stats():
			if stat_name not in names:
				names.append(stat_name)
	for stat_name in names:
		stat_changed.emit(stat_name)


#region Called by components: you don't need these yourself


## Adds [param c]. Components call this themselves when they enter the tree.
func register(c: Component) -> void:
	if c in _components:
		return
	_components.append(c)
	c._manager = self
	refresh_stats()
	if started or _starting:
		for other in _components.duplicate():
			# The newcomer, and anything that was waiting for it.
			try_start(other)


## Stops and removes [param c]. Components call this themselves when they leave the tree.
func unregister(c: Component) -> void:
	if c not in _components:
		return
	c._halt()
	_components.erase(c)
	c._manager = null
	refresh_stats()
	for other in _components.duplicate():
		if other.running and not other.missing().is_empty():
			# It lost something it requires. It restarts if that comes back.
			other._halt()


## Starts [param c] if the host is ready and everything it requires is present.
## Otherwise reports what is missing, once.
func try_start(c: Component) -> void:
	if not (started or _starting) or c.running or not c.is_node_ready():
		return
	var missing: Array[Script] = c.missing()
	if missing.is_empty():
		c._begin()
	elif not c._reported:
		c._reported = true
		var names: Array = missing.map(Component.type_name)
		push_error("%s on '%s' can't start: it needs %s beside it." % [
			Component.type_name(c.get_script()), host.name, ", ".join(names)])


#endregion


func _start_all() -> void:
	if started or not is_inside_tree():
		return
	_starting = true
	for c in _components.duplicate():
		try_start(c)
	_starting = false
	started = true
	send(&"started", null)


func _editor_notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if host and not host.child_order_changed.is_connected(update_configuration_warnings):
				host.child_order_changed.connect(update_configuration_warnings)
		NOTIFICATION_EXIT_TREE:
			if host and host.child_order_changed.is_connected(update_configuration_warnings):
				host.child_order_changed.disconnect(update_configuration_warnings)
