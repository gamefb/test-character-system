@tool
@icon("res://character_system/icons/component.svg")
@abstract
class_name Component
extends Node
## Base class for every component: a child node that adds one feature to its parent, the host.
##
## The host also needs a [ComponentManager] child. Components register with it by themselves,
## and through it they find each other, share stats and hear events. A component only runs,
## between [method _start] and [method _stop], while everything in [method _requires] is
## present, so components can be added or removed at any time, in any order.
##
## [b]Setting up a host.[/b] Any node can be a host: a [CharacterBody3D] character, a weapon
## scene, a crate. Add a ComponentManager and the components as its direct children, in any
## order:
## [codeblock]
## Player (CharacterBody3D)
##     ComponentManager
##     Health
##     PlayerBrain
##     CharacterMotor
## [/codeblock]
##
## [b]What happens, in order.[/b]
## [br]1. The component enters the tree and registers with the manager. From now on its
## [method _stats] can be read.
## [br]2. When the host is ready (after the host's own [code]_ready()[/code]), every component
## whose [method _requires] are present gets [method _start]. A component added later, during
## play, starts as soon as it's added.
## [br]3. While running, it hears the events it asked for with [method on], and its
## [code]_process()[/code], [code]_physics_process()[/code] and input callbacks run. Before it
## starts they don't run at all, so they can use what [method _requires] promises without null
## checks.
## [br]4. [method _stop] runs when it leaves the tree, when the host is freed, or when something
## it requires is removed. Everything connected with [method listen] or [method on] is
## disconnected, and everything given with [method hold_modifier] or [method hold_status] is
## taken back.
## [br]5. If what it required comes back, [method _start] runs again. Write [method _start] and
## [method _stop] so they can run more than once.
##
## If a component can't start, the editor shows a warning on it and the Output panel reports
## once what's missing. The rest of the host keeps working.
##
## [b]Using components from other code.[/b] Get one with its type's [code]find_on()[/code],
## such as [method Health.find_on], read stats with [method ComponentManager.stat_of] and send
## events with [method ComponentManager.notify]. All three are safe on null and on nodes
## without components, such as walls.
## [codeblock]
## var health := Health.find_on(body)  # null if body has no Health.
## if health:
## 	health.change(-10.0)
## [/codeblock]
##
## [b]Writing your own.[/b] Extend this class and override any of [method _requires],
## [method _stats], [method _start], [method _stop] and [method _warnings]. Do setup in
## [method _start], not [code]_ready()[/code]: it runs once everything is in place, and never
## in the editor. This outline shows where each part goes; [Sprint] in
## [code]starter_pack/scripts/[/code] is a complete one to copy.
##
## [codeblock]
## @tool  # Optional: shows this component's warnings in the editor.
## class_name Shield
## extends Component
##
## @export var max_shield := 50.0
##
## func _requires() -> Array[Script]:
## 	return [Health]  # Waits until there's a Health beside it.
##
## func _stats() -> Dictionary[StringName, float]:
## 	return { &"max_shield": max_shield }  # Statuses can change it by name.
##
## func _start() -> void:
## 	listen(manager.stat_changed, _on_stat_changed)  # Disconnected on stop.
## 	on(&"taking_damage", _on_taking_damage)  # An event on this host. Also undone on stop.
##
## func _process(_delta: float) -> void:
## 	pass  # Runs only while the component runs, e.g. to recharge.
##
## func _on_stat_changed(_stat_name: StringName) -> void:
## 	pass  # E.g. cut the shield down when max_shield drops.
##
## func _on_taking_damage(ctx: EffectContext) -> void:
## 	ctx.mul *= 0.5  # A hit about to land: take half of it.
## [/codeblock]
##
## [b]Rules of thumb.[/b]
## [br]- Don't keep references to other components in variables; [method find] them when you
## need them. They can be removed and added during play, and [method find] is cheap.
## [br]- Don't store stat values. Read [method stat] each time, or [method listen] to
## [signal ComponentManager.stat_changed]; a stored speed ignores every status.
## [br]- Connect with [method listen], not [code]connect()[/code], and hear events with
## [method on], so both are undone when the component stops.
## [br]- Change a stat with [method hold_modifier] and give a status with [method hold_status],
## for the same reason: a modifier left behind would change the character for good.
## [br]- A component that's optional for yours (used if present) doesn't go in
## [method _requires]. [method find] it and check for null.

## The node this component belongs to (its parent).
var host: Node:
	get:
		return get_parent()
## The host's [ComponentManager], or null if it has none. Set when the component enters the
## tree, so it's null in [code]_init()[/code] and while the component is outside the tree.
var manager: ComponentManager
## True between [method _start] and [method _stop]. Check it in methods other nodes call,
## because they can be called while the component is stopped.
var running := false

var _connections: Array[Array] = []  # [Signal, Callable] pairs made with listen().
# Each modifier and status given with hold_modifier() or hold_status(), and the node it is on.
var _holds: Dictionary[Resource, Node] = {}
# The process_mode to restore when the component starts.
var _mode := PROCESS_MODE_INHERIT
# Whether a "can't start" error was already shown.
var _reported := false
# What _requires() returned when the component started.
var _required: Array[Script] = []


## Returns the [param type] component on [param node], or null. Safe on a null node.
##
## Use it from any script: effects, level scripts, UI. Subclasses count, so asking for
## [Brain] finds a [PlayerBrain] or [AIBrain]. The components a game looks up most have a
## typed shortcut, such as [method Health.find_on]. For a type of your own, cast the result,
## or give the type the same two lines:
## [codeblock]
## var statuses := Statuses.find_on(enemy)
## var sprint := Component.of(enemy, Sprint) as Sprint
##
## # In sprint.gd, so other scripts can write Sprint.find_on(enemy):
## static func find_on(node: Node) -> Sprint:
## 	return Component.of(node, Sprint) as Sprint
## [/codeblock]
## It works on a scene that hasn't been added to the level yet, e.g. to set a spawned
## enemy's [member Faction.team] before [code]add_child()[/code].
static func of(node: Node, type: Script) -> Component:
	var m := ComponentManager.of(node)
	return m.find(type) if m else null


## A readable name for a component type, for messages: its [code]class_name[/code], or its
## file name if it has none.
static func type_name(type: Script) -> String:
	var global: StringName = type.get_global_name()
	return global if global else type.resource_path.get_file().get_basename()


#region Engine callbacks: no need to change these


func _validate_property(property: Dictionary) -> void:
	if Engine.is_editor_hint():
		NameCheck.suggest(self, property)  # Name fields become lists to pick from.


func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		_editor_notification(what)
		return
	match what:
		NOTIFICATION_ENTER_TREE:
			var m := ComponentManager.of(host)
			if m:
				m.register(self)
		NOTIFICATION_READY:
			_mode = process_mode
			# No _process, _physics_process or input until it starts.
			process_mode = PROCESS_MODE_DISABLED
			if manager:
				manager.try_start(self)
			else:
				_check_manager.call_deferred()
		NOTIFICATION_EXIT_TREE:
			if manager:
				manager.unregister(self)


func _get_configuration_warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if not host or (is_inside_tree() and self == get_tree().edited_scene_root):
		return out
	if not ComponentManager.of(host):
		out.append("Add a ComponentManager node beside this one (another child of '%s')."
				% host.name)
	for type in missing():
		out.append("Needs a %s beside it." % type_name(type))
	out.append_array(_warnings())
	return out


#endregion


## Returns the [param type] component on the same host, or null. Subclasses count. If the host
## has several, the first is returned. The manager remembers the answer, so calling it every
## frame is cheap.
##
## Types in [method _requires] are never null while the component runs, so in [method _start]
## and [code]_process()[/code] you can cast and use them directly:
## [codeblock]
## var brain := find(Brain) as Brain
## [/codeblock]
func find(type: Script) -> Component:
	return manager.find(type) if manager else null


## Returns every [param type] component on the same host, in scene order. Subclasses count.
## Use it for components a host can have several of, such as [Pool]. The answer isn't
## remembered, so call it in [method _start] or when something happens, not every frame.
func find_all(type: Script) -> Array[Component]:
	var none: Array[Component] = []
	return manager.find_all(type) if manager else none


## Returns the first node of the built-in class [param type] anywhere under the host, or null.
## Use it to fill in an export that was left empty, the way [PlayerBrain] finds its camera:
## [codeblock]
## if not camera:
## 	camera = find_node_of_type(&"Camera3D")
## [/codeblock]
## It searches the whole host, so call it once, e.g. in [method _start], not every frame.
func find_node_of_type(type: StringName) -> Node:
	if not host:
		return null
	var found: Array[Node] = host.find_children("*", type, true, false)
	return found[0] if not found.is_empty() else null


## Current value of [param stat_name] on this host: the owner's base value with every
## [StatModifier] applied, e.g. [code]stat(&"move_speed")[/code]. It's 0 if no component owns
## the stat. Totals are cached, so reading it every frame is cheap.
## See [method ComponentManager.stat].
func stat(stat_name: StringName) -> float:
	return manager.stat(stat_name) if manager else 0.0


## Connects [param sig] to [param method] until this component stops. Use it in [method _start].
##
## The signal can be on any object: a sibling component, the host, another character or a
## timer. If that object is freed first, nothing breaks. Connecting the same pair twice
## before the component stops is an error, as with [code]connect()[/code].
## [codeblock]
## func _start() -> void:
## 	listen((find(Health) as Health).died, _on_died)
## 	listen(manager.stat_changed, _on_stat_changed)
## [/codeblock]
func listen(sig: Signal, method: Callable) -> void:
	sig.connect(method)
	_connections.append([sig, method])


## Calls [param method] with the event's [EffectContext] each time [param event_name] is sent
## to this host, until this component stops. Use it in [method _start].
##
## It's the usual way to react to something that happened to the character:
## [codeblock]
## func _start() -> void:
## 	on(&"took_damage", _on_took_damage)
## 	on(&"killed", _on_killed)
##
## func _on_took_damage(ctx: EffectContext) -> void:
## 	print("Lost %s to %s damage" % [ctx.amount, ctx.damage_type])
##
## func _on_killed(ctx: EffectContext) -> void:
## 	kills += 1  # ctx.target is who died.
## [/codeblock]
## The context is null for events sent without one, such as [code]started[/code]. It's short
## for [code]listen(manager.event(event_name), method)[/code]: every event is a signal on the
## [ComponentManager]. The built-in events:
## [br]- [code]dealing_damage[/code], [code]taking_damage[/code]: a hit about to land. Change
## [member EffectContext.add], [member EffectContext.percent] and [member EffectContext.mul]
## to change the damage.
## [br]- [code]absorbing_damage[/code]: the same hit with its final number in
## [member EffectContext.amount]. Lower it by what a shield soaks up.
## [br]- [code]dealt_damage[/code], [code]took_damage[/code]: the same hit, after it landed.
## [br]- [code]giving_healing[/code], [code]receiving_healing[/code], [code]gave_healing[/code],
## [code]received_healing[/code]: the same for healing.
## [br]- [code]died[/code]: the killing blow, or null. [code]killed[/code]: the same blow, sent
## to whoever dealt it.
## [br]- [code]ability_cast_started[/code], [code]ability_used[/code],
## [code]ability_interrupted[/code]: [member EffectContext.origin] is the [AbilityData].
## [br]- [code]started[/code], [code]revived[/code], [code]inventory_changed[/code]: null.
## [br]- The [CharacterMotor] adds one for each mode and move, such as
## [code]walk_mode_entered[/code] and [code]dash_move_started[/code].
## [br]Send your own with [method ComponentManager.notify]. Prefer events for "something
## happened to this character"; for one component's own changes, a signal of its own is
## simpler.
## [br][br]Pass [param node] to hear another host's events instead, e.g. an item listening to
## its wielder: [code]on(&"killed", _on_wielder_killed, wielder)[/code]. A node without a
## [ComponentManager] has no events, so nothing happens.
func on(event_name: StringName, method: Callable, node: Node = null) -> void:
	var m: ComponentManager = ComponentManager.of(node) if node else manager
	if m:
		listen(m.event(event_name), method)


## Keeps [param m] on this host's stats for as long as [param on] is true, and takes it off when
## the component stops. An [ItemComponent]'s goes on its wielder.
##
## It only acts when [param on] changes, so it can be called every frame with a condition:
## [codeblock]
## var _boost := StatModifier.new()  # Its stat and mul are set in _start().
##
## func _process(_delta: float) -> void:
## 	hold_modifier(_boost, (find(Brain) as Brain).is_action_pressed(&"sprint"))
## [/codeblock]
## [param source] is what [method ComponentManager.modifiers_of] names as behind the change:
## this component if left out. A modifier is held once however often it is asked for, so use
## one object for each change. Nothing is held while the component isn't running.
func hold_modifier(m: StatModifier, on := true, source: Object = null) -> void:
	if on == _holds.has(m):
		return
	if not on:
		_release_hold(m)
		return
	var target := ComponentManager.of(_hold_target())
	if running and target:
		target.add_modifier(m, source if source else self)
		_holds[m] = target.host


## Gives this host [param data] for as long as [param on] is true, and drops the hold when the
## component stops. An [ItemComponent]'s goes to its wielder. Use a status with
## [member StatusData.duration] 0, which stays until its last hold is dropped.
##
## Returns whether the status is held now: false if it was refused (see
## [method StatusData.can_apply]), if there is no [Statuses] to take it, or if [param data] is
## null. Like [method hold_modifier], it only acts when [param on] changes, so a status that
## was refused isn't asked for again until [param on] has been false in between.
## [param source] is who is credited with applying it.
func hold_status(data: StatusData, on := true, source: Node = null) -> bool:
	if not data or (on and not running):
		return false
	if on and not _holds.has(data):
		var statuses := Statuses.find_on(_hold_target())
		# One that is refused is remembered too, as held on nobody, so it is asked for once.
		_holds[data] = statuses.host if statuses and statuses.add(data, source) else null
	elif not on and _holds.has(data):
		_release_hold(data)
	return _holds.get(data) != null


## Call after changing a number that [method _stats] returns, so statuses and readers see it.
## The usual place is the export's setter:
## [codeblock]
## @export var max_stamina := 100.0:
## 	set(value):
## 		max_stamina = value
## 		update_stats()
## [/codeblock]
func update_stats() -> void:
	if manager:
		manager.refresh_stats()


## Components of the types in [method _requires] that are not on the host. Empty when the
## component can start. Handy for your own debug display.
func missing() -> Array[Script]:
	var out: Array[Script] = []
	for type in _requires():
		if not _has_sibling(type):
			out.append(type)
	return out


#region Override these


## Component types this one can't work without, e.g. [code]return [Brain][/code].
##
## They must be on the same host. Subclasses count, so requiring [Brain] accepts a
## [PlayerBrain] or [AIBrain]. The component waits, with a warning, until all of them are
## present, and stops if one is removed. Leave out components you only use if present.
func _requires() -> Array[Script]:
	return []


## Numbers this component owns, e.g. [code]{ &"max_health": max_health }[/code].
## Statuses and items change them with stat modifiers of the same name.
##
## Return the base values, usually your exports, never values with modifiers applied. It's
## called often, so only build the dictionary. If two components on a host own the same stat,
## the editor warns and the first one's value is used. Call [method update_stats] when one of
## these numbers changes.
func _stats() -> Dictionary[StringName, float]:
	return {}


## Called once the host is ready and everything this component requires is present.
## Connect signals with [method listen] here.
##
## It runs after the host's own [code]_ready()[/code], and again after each restart (see
## [method _stop]). Anything it sets up by other means than [method listen], [method on],
## [method hold_modifier] and [method hold_status], such as a group or a spawned node, should
## be undone in [method _stop].
func _start() -> void:
	pass


## Called when this component is removed, or something it requires is removed.
##
## Also called when the host is freed. Connections made with [method listen] and [method on],
## and holds made with [method hold_modifier] and [method hold_status], are undone right after
## it, so only undo what [method _start] did by other means.
func _stop() -> void:
	pass


## Extra warnings to show in the editor, e.g. an export that must be set.
##
## They show as a yellow triangle on the node, next to the built-in ones (no manager, missing
## requirements). Only scripts with [code]@tool[/code] at the top run in the editor, so add it
## to see them. To refresh the warnings when an export changes, call
## [code]update_configuration_warnings()[/code] in its setter.
func _warnings() -> PackedStringArray:
	return PackedStringArray()


#endregion


#region Internals: no need to change these


## Called by the [ComponentManager]. Starts the component.
func _begin() -> void:
	running = true
	_required = _requires()
	process_mode = _mode
	_start()


## Called by the [ComponentManager]. Stops the component and undoes every [method listen],
## [method on], [method hold_modifier] and [method hold_status].
func _halt() -> void:
	if not running:
		return
	running = false
	process_mode = PROCESS_MODE_DISABLED
	_stop()
	for what: Resource in _holds.keys():
		_release_hold(what)
	for pair in _connections:
		var sig: Signal = pair[0]
		if is_instance_valid(sig.get_object()) and sig.is_connected(pair[1]):
			sig.disconnect(pair[1])
	_connections.clear()


# The node hold_modifier() and hold_status() act on. An ItemComponent answers with its wielder.
func _hold_target() -> Node:
	return host


# Takes back one thing hold_modifier() or hold_status() gave.
func _release_hold(what: Resource) -> void:
	var node: Variant = _holds[what]  # Untyped: the node may have been freed since.
	_holds.erase(what)
	if not is_instance_valid(node):
		return
	if what is StatModifier:
		var stats := ComponentManager.of(node)
		if stats:
			stats.remove_modifier(what)
	else:
		var statuses := Statuses.find_on(node)
		if statuses:
			statuses.drop_hold(what)


# Called by the ComponentManager when other leaves: true if this component required other's
# type when it started.
func _required_type_of(other: Component) -> bool:
	for type in _required:
		if is_instance_of(other, type):
			return true
	return false


func _has_sibling(type: Script) -> bool:
	if manager:
		return manager.has_registered(type)
	return host.get_children().any(func(child: Node) -> bool: return is_instance_of(child, type))


func _check_manager() -> void:
	if not manager and is_inside_tree():
		push_error("%s on '%s' needs a ComponentManager node beside it."
				% [type_name(get_script()), host.name])


# In the editor nothing runs; the component only keeps its warnings up to date.
func _editor_notification(what: int) -> void:
	match what:
		NOTIFICATION_READY:
			set_process(false)
			set_physics_process(false)
			set_process_input(false)
			set_process_unhandled_input(false)
		NOTIFICATION_ENTER_TREE:
			if host and not host.child_order_changed.is_connected(update_configuration_warnings):
				host.child_order_changed.connect(update_configuration_warnings)
		NOTIFICATION_EXIT_TREE:
			if host and host.child_order_changed.is_connected(update_configuration_warnings):
				host.child_order_changed.disconnect(update_configuration_warnings)


#endregion
