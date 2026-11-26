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
## [br]- [b]Lookup.[/b] [method find] returns a component by type. It remembers the answer
## until the host's children change, so it's cheap enough to call every frame.
## [br]- [b]Stats.[/b] Components declare numbers in [method Component._stats], and
## [member stats] lists any others; [method stat] returns them with every [StatModifier]
## applied, and [signal stat_changed] reports changes. [method modifiers_of] lists what is
## changing a stat, for a character sheet.
## [br]- [b]Events.[/b] Every event is a signal. [method event] returns the signal for one
## event on this host, and [method send] emits it. [WorldEvents] has the same signals for
## every host at once.
##
## From other code, use the static helpers [method of], [method notify] and [method stat_of].
## They take any node, or null, and do nothing (or return 0) if it has no manager, so they're
## safe on walls and props.
## [codeblock]
## var speed := ComponentManager.stat_of(player, &"move_speed")
## ComponentManager.notify(player, &"level_up")
## ComponentManager.of(player).stat_changed.connect(_on_player_stat_changed)
## ComponentManager.of(player).event(&"took_damage").connect(_on_player_hurt)
## [/codeblock]
## Keep this node's default name. [method of] looks for a child with that name first, and only
## searches all the children when there isn't one.

## Emitted when [param stat_name]'s value may have changed: a modifier for it was added or
## removed, the component that owns it was added or removed, or a component called
## [method Component.update_stats]. Read the new value with [method stat]. Useful for UI, such as
## a health bar that follows max health.
signal stat_changed(stat_name: StringName)
## Emitted for every event sent to this host, before the event's own signal. [Statuses] uses
## it to run status triggers. To hear one event, connect to [method event] instead.
signal event_sent(event_name: StringName, ctx: EffectContext)

## Stats of your game's own, and their values before statuses and items: strength, level,
## crit_chance. A stat listed here works everywhere stats do, with no script: a [StatModifier]
## changes it, a [StatAmount] scales an effect with it, and [method stat] reads it. A
## component that returns the same name from [method Component._stats] wins.
@export var stats: Dictionary[StringName, float] = {}:
	set(value):
		stats = value
		refresh_stats()

## True once the host is ready and its components have had the chance to start. At that moment
## every running component also hears the [code]started[/code] event.
var started := false
## The node this manager belongs to (its parent).
var host: Node:
	get:
		return get_parent()

# True while the components first start, before [member started].
## What is blocked on this host right now, and by how many things: see [method block]. Read
## it; change it only through [method block] and [method unblock].
var blocks: Dictionary[StringName, int] = {}

var _starting := false
var _components: Array[Component] = []
var _modifiers: Array[StatModifier] = []
var _modifier_sources: Array[Object] = []  # What added each modifier, in the same order.
var _cache: Dictionary[StringName, float] = {}  # Stat values, cleared whenever anything changes.
var _bases: Dictionary[StringName, float] = {}  # Base values, cleared when a component changes.
var _resolving: Dictionary[StringName, bool] = {}  # Stats being worked out right now.
var _found: Dictionary[Script, Component] = {}  # find() answers, cleared when children change.
var _events: Dictionary[StringName, Signal] = {}  # The signals event() has handed out.


## Returns [param node]'s [ComponentManager] child, or null if it has none or [param node] is
## null. A node you kept in a variable may have been freed since: check it with
## [code]is_instance_valid()[/code] first, as for any call that takes a node.
static func of(node: Node) -> ComponentManager:
	if not node:
		return null
	# The usual name is a quick lookup; searching the children is the fallback.
	var named := node.get_node_or_null(^"ComponentManager") as ComponentManager
	if named:
		return named
	for child in node.get_children():
		if child is ComponentManager:
			return child
	return null


## Sends [param event] to [param node]'s components, if it has a [ComponentManager].
##
## Use it for your own events, e.g. [code]&"jumped"[/code] or [code]&"level_up"[/code]. Every
## listener connected with [method event] or [method Component.on] hears it, and status
## triggers with that [member StatusTrigger.event] fire. Leave out [param ctx] and a context
## with [param node] as the target is made for you; pass your own to say who caused it.
static func notify(node: Node, event: StringName, ctx: EffectContext = null) -> void:
	var m: ComponentManager = of(node)
	if m:
		m.send(event, ctx if ctx else EffectContext.new(null, node))


## Reads [param stat_name] from [param node], or 0 if it has no [ComponentManager].
static func stat_of(node: Node, stat_name: StringName) -> float:
	var m: ComponentManager = of(node)
	return m.stat(stat_name) if m else 0.0


## Whether [param node]'s host is blocking [param what], e.g. [code]&"damage"[/code]. False
## for a node without a manager.
static func blocked(node: Node, what: StringName) -> bool:
	var m := of(node)
	return m != null and m.blocks.has(what)


func _init() -> void:
	name = &"ComponentManager"  # So ComponentManager.new() gets the name of() looks for first.


func _notification(what: int) -> void:
	# find() remembers its answers until the host's children change, in the editor too.
	if what == NOTIFICATION_PARENTED:
		_found.clear()
		host.child_order_changed.connect(_found_clear)
	elif what == NOTIFICATION_UNPARENTED:
		_found.clear()
		if host.child_order_changed.is_connected(_found_clear):
			host.child_order_changed.disconnect(_found_clear)
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
## The answer is remembered until a child is added, removed or moved, so calling it every frame
## is cheap.
func find(type: Script) -> Component:
	if not _found.has(type):
		_found[type] = null
		for child in (host.get_children() if host else []):
			if is_instance_of(child, type):
				_found[type] = child
				break
	return _found[type]


## Every component on the host that is a [param type] (subclasses count), in scene order, e.g.
## all of a character's [Pool]s. Unlike [method find], the answer isn't remembered, so don't
## call it every frame.
func find_all(type: Script) -> Array[Component]:
	var out: Array[Component] = []
	for child in (host.get_children() if host else []):
		if is_instance_of(child, type):
			out.append(child)
	return out


## True if a registered (in the scene) component is a [param type]. Used to decide
## whether a component has everything it requires.
func has_registered(type: Script) -> bool:
	for c in _components:
		if is_instance_of(c, type):
			return true
	return false


## Sends [param event_name] to this host: emits [signal event_sent], then the event's own
## signal if anything has asked for it with [method event], then the same event on
## [WorldEvents]. From outside the host, use [method notify], which also copes with a null
## node.
func send(event_name: StringName, ctx: EffectContext) -> void:
	event_sent.emit(event_name, ctx)
	if _events.has(event_name):
		_events[event_name].emit(ctx)
	WorldEvents.emit(host, event_name, ctx)


## The signal for one event on this host, e.g. [code]event(&"took_damage")[/code]. It's an
## ordinary signal: connect a method that takes the event's [EffectContext], which is null for
## events sent without one. Components use [method Component.on], which also disconnects when
## the component stops; everything else connects directly, such as a HUD:
## [codeblock]
## func _ready() -> void:
## 	ComponentManager.of(player).event(&"took_damage").connect(_flash_red)
##
## func _flash_red(ctx: EffectContext) -> void:
## 	flash.modulate.a = clampf(ctx.amount / 20.0, 0.2, 1.0)
## [/codeblock]
## As with any signal, a connection ends by itself when the listener is freed, and listeners
## are called in the order they connected. [method Component._start] lists the built-in events.
func event(event_name: StringName) -> Signal:
	if not _events.has(event_name):
		# Prefixed, so an event may share its name with one of Node's own signals.
		var signal_name := StringName("event_" + event_name)
		add_user_signal(signal_name, [{ "name": "ctx", "type": TYPE_OBJECT }])
		_events[event_name] = Signal(self, signal_name)
	return _events[event_name]


## Sets the base value of a stat in [member stats], adding it if it isn't listed yet.
func set_base(stat_name: StringName, value: float) -> void:
	stats[stat_name] = value
	_bases.erase(stat_name)
	_cache.erase(stat_name)
	stat_changed.emit(stat_name)


## Adds [param amount] to the base value of a stat in [member stats], e.g. a level on level
## up: [code]manager.add_base(&"level", 1)[/code]. Everything scaled by the stat follows.
func add_base(stat_name: StringName, amount: float) -> void:
	set_base(stat_name, stats.get(stat_name, 0.0) + amount)


## Stops everything on this host that answers to the name [param what], such as
## [code]&"movement"[/code], until [method unblock] is called as many times. A status does this
## with each of its [member StatusData.blocks]; a cutscene can do it from code.
func block(what: StringName) -> void:
	blocks[what] = blocks.get(what, 0) + 1


## Takes back one [method block] of [param what].
func unblock(what: StringName) -> void:
	if blocks.get(what, 0) > 1:
		blocks[what] -= 1
	else:
		blocks.erase(what)


## Whether anything is blocking one of [param names] right now.
func is_blocked(names: Array[StringName]) -> bool:
	if blocks.is_empty():
		# Nearly always, so this is asked many times a frame for nothing.
		return false
	for what in names:
		if blocks.has(what):
			return true
	return false


## Current value of a stat: (base + all adds) × (1 + all percents) × all muls. The base comes
## from the component that lists it in [method Component._stats], or is 0 if none does.
##
## For example, with [member CharacterMotor.move_speed] 5 and modifiers [code]add 1[/code],
## [code]percent 0.5[/code] and [code]mul 0.5[/code], [code]move_speed[/code] is
## (5 + 1) × 1.5 × 0.5 = 4.5. Results are cached until something changes, so read it whenever
## you need it instead of keeping a copy. A stat with a conditional modifier (see
## [member StatModifier.conditions]) is worked out on every read instead.
func stat(stat_name: StringName) -> float:
	if _cache.has(stat_name):
		return _cache[stat_name]
	var base: float = base_of(stat_name)
	if _resolving.has(stat_name):
		# A condition on one of this stat's own modifiers is reading it.
		return base
	_resolving[stat_name] = true
	var add: float = 0.0
	var percent: float = 0.0
	var mul: float = 1.0
	var conditional := false
	for i in _modifiers.size():
		var m: StatModifier = _modifiers[i]
		if m.stat != stat_name:
			continue
		if not m.conditions.is_empty():
			conditional = true
			if not _conditions_pass(i):
				continue
		add += m.add
		percent += m.percent
		mul *= m.mul
	_resolving.erase(stat_name)
	var value: float = (base + add) * (1.0 + percent) * mul
	if not conditional:
		_cache[stat_name] = value
	return value


## A stat's value before any [StatModifier]: what the component that owns it returns from
## [method Component._stats], else its value in [member stats], else 0.
func base_of(stat_name: StringName) -> float:
	if not _bases.has(stat_name):
		var base: float = stats.get(stat_name, 0.0)
		for c in _components:
			var owned: Dictionary[StringName, float] = c._stats()
			if owned.has(stat_name):
				base = owned[stat_name]
				break
		_bases[stat_name] = base
	return _bases[stat_name]


## Everything changing [param stat_name] right now, in the order it was added, for a character
## sheet or a tooltip that explains a number. Each entry is a Dictionary with:
## [br]- [code]modifier[/code]: the [StatModifier].
## [br]- [code]source[/code]: what added it, e.g. the [StatusData], or null if it wasn't said.
## [br]- [code]active[/code]: false while the modifier's conditions don't pass.
## [codeblock]
## var lines := ["Base %s" % manager.base_of(&"move_speed")]
## for entry in manager.modifiers_of(&"move_speed"):
## 	var m: StatModifier = entry.modifier
## 	var status := entry.source as StatusData
## 	lines.append("%s: +%s, +%d%%, x%s"
## 			% [status.display_name if status else "?", m.add, m.percent * 100.0, m.mul])
## [/codeblock]
func modifiers_of(stat_name: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in _modifiers.size():
		var m: StatModifier = _modifiers[i]
		if m.stat == stat_name:
			out.append({
				"modifier": m,
				"source": _modifier_sources[i],
				"active": m.conditions.is_empty() or _conditions_pass(i),
			})
	return out


## Applies [param m] until [method remove_modifier] takes it off. [Statuses] does this for
## status modifiers; call it yourself for a one-off change.
##
## Keep the same object to remove it later. Most changes are better as a status (a
## [StatusData] with [member StatusData.modifiers]), which can end by itself and appear on a
## status bar; use this for changes your own code controls, such as aiming down sights.
## [param source] is whatever is behind it (a status, an item), for [method modifiers_of].
## [codeblock]
## var aiming := StatModifier.new()
## aiming.stat = &"move_speed"
## aiming.mul = 0.5
## manager.add_modifier(aiming)  # Half speed...
## manager.remove_modifier(aiming)  # ...until this.
## [/codeblock]
func add_modifier(m: StatModifier, source: Object = null) -> void:
	_modifiers.append(m)
	_modifier_sources.append(source)
	_cache.erase(m.stat)
	stat_changed.emit(m.stat)


## Removes one copy of [param m]. A modifier added twice must be removed twice.
func remove_modifier(m: StatModifier) -> void:
	var index: int = _modifiers.find(m)
	if index != -1:
		_modifiers.remove_at(index)
		_modifier_sources.remove_at(index)
	_cache.erase(m.stat)
	stat_changed.emit(m.stat)


## Re-reads every component's stats and emits [signal stat_changed] for each. Components call
## this through [method Component.update_stats]; you don't need to call it yourself.
func refresh_stats() -> void:
	var names: Array = _cache.keys()
	_cache.clear()
	_bases.clear()
	for c in _components:
		for stat_name in c._stats():
			if stat_name not in names:
				names.append(stat_name)
	for stat_name in stats:
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
	c.manager = self
	_stats_changed_by(c)
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
	c.manager = null
	_stats_changed_by(c)
	for other in _components.duplicate():
		if other.running and other._required_type_of(c) and not other.missing().is_empty():
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


# A component came or went, so only the stats it owns can have new totals.
func _stats_changed_by(c: Component) -> void:
	for stat_name in c._stats():
		_cache.erase(stat_name)
		_bases.erase(stat_name)
		stat_changed.emit(stat_name)


func _found_clear() -> void:
	_found.clear()


# Whether the conditions of the modifier at index pass, checked on the host.
func _conditions_pass(index: int) -> bool:
	var ctx := EffectContext.new(host, host, _modifier_sources[index] as Resource)
	return Condition.all_pass(_modifiers[index].conditions, ctx)


func _editor_notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if host and not host.child_order_changed.is_connected(update_configuration_warnings):
				host.child_order_changed.connect(update_configuration_warnings)
		NOTIFICATION_EXIT_TREE:
			if host and host.child_order_changed.is_connected(update_configuration_warnings):
				host.child_order_changed.disconnect(update_configuration_warnings)
