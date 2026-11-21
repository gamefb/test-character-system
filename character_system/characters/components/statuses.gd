@tool
@icon("res://character_system/icons/statuses.svg")
class_name Statuses
extends Component
## Holds a character's statuses and passives, and applies, ticks, expires and triggers them.
##
## Give statuses with [method add], or through effects ([ApplyStatusEffect]), items
## ([GrantStatuses]) and zones ([EffectZone]). A status with duration 0 counts its holds: each
## item, zone or innate entry that adds it is one hold, and [method drop_hold] drops one.
##
## [method remove] ends a status outright, e.g. for a cleanse.
##
## [codeblock]
## var statuses := Component.of(enemy, Statuses) as Statuses
## if not statuses.add(burning, player):
## 	print("Immune")  # Or connect to the refused signal.
## [/codeblock]

## Emitted after a status is added, reapplied or removed, or loses a stack.
signal changed
## Emitted when a status is not applied, because an active status is immune to one of its
## tags or its apply_conditions failed. Useful for "Immune" popups.
signal refused(data: StatusData, source: Node)

## Passives this character always has, such as racial traits.
@export var innate: Array[StatusData] = []

## Every status this character has right now, with its runtime state. Read it, but change it
## through [method add], [method remove] and [method drop_hold].
var active: Dictionary[StatusData, ActiveStatus] = {}


static func _overlaps(a: Array[StringName], b: Array[StringName]) -> bool:
	return a.any(func(tag: StringName) -> bool: return tag in b)


func _process(delta: float) -> void:
	for data: StatusData in active.keys():
		var s: ActiveStatus = active.get(data)
		if not s:
			continue  # Removed by another status this frame.
		if data.tick_interval > 0.0:
			s.tick_in -= delta
			if s.tick_in <= 0.0:
				s.tick_in += data.tick_interval
				_run(data.on_tick, data, s)
		if data.duration > 0.0:
			s.time_left -= delta
			if s.time_left <= 0.0:
				remove(data)


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(innate)


func _start() -> void:
	for data in innate:
		add(data, host)


func _stop() -> void:
	for data: StatusData in active.keys():
		remove(data)  # Takes its stat modifiers back off.


func _on_event(event: StringName, ctx: EffectContext) -> void:
	if event == &"died":
		for data: StatusData in active.keys():
			if data.duration > 0.0:
				# Timed statuses end on death. Passives stay for a revive.
				remove(data)
	if not ctx:
		return
	var other: Node = ctx.target if ctx.source == host else ctx.source
	for data: StatusData in active.keys():
		for t in data.triggers:
			if (
					t.event == event and active.has(data)
					and (t.react_to_statuses or not ctx.from_status)
			):
				_run(t.effects, data, active[data], other if t.affects_other else host, ctx)


## Applies a status, handling conditions, blocking, removal of opposing statuses,
## stacking and refresh. Returns false if the status was refused.
func add(data: StatusData, source: Node = null) -> bool:
	if not manager:
		push_error("Statuses on '%s' needs a ComponentManager node beside it." % host.name)
		return false
	if not data.can_apply(host, source):
		refused.emit(data, source)
		return false
	for other: StatusData in active.keys():
		if _overlaps(other.tags, data.removes_tags):
			remove(other)  # e.g. Wet puts out Burning.

	var s: ActiveStatus = active.get(data)
	var is_new: bool = s == null
	if is_new:
		s = ActiveStatus.new()
		s.tick_in = data.tick_interval
		active[data] = s
	if data.duration == 0.0:
		s.holds += 1
	if not is_new and data.stacking == StatusData.Stacking.IGNORE:
		return true

	s.source = source
	s.time_left = data.duration
	if s.stacks < data.stack_limit():
		_set_stacks(data, s, s.stacks + 1)
		_run(data.on_apply, data, s)
	changed.emit()
	return true


## Removes a status completely, whatever is keeping it active.
func remove(data: StatusData) -> void:
	var s: ActiveStatus = active.get(data)
	if not s:
		return
	_set_stacks(data, s, 0)
	active.erase(data)
	_run(data.on_remove, data, s)
	changed.emit()


## Drops one permanent source, such as an unequipped item.
## The status ends when no sources remain.
func drop_hold(data: StatusData) -> void:
	var s: ActiveStatus = active.get(data)
	if not s:
		return
	s.holds -= 1
	if s.holds <= 0:
		remove(data)
	elif s.stacks > s.holds:
		_set_stacks(data, s, s.holds)
		changed.emit()


## True if any active status has [param tag].
func has_tag(tag: StringName) -> bool:
	return active.keys().any(func(data: StatusData) -> bool: return tag in data.tags)


## True if an active status or trait is immune to one of [param data]'s tags,
## e.g. Wet is immune to &"fire", so Burning can't be added.
func is_immune_to(data: StatusData) -> bool:
	return active.keys().any(
			func(other: StatusData) -> bool: return _overlaps(data.tags, other.immune_to))


# Adds or removes stat modifiers so they match the stack count.
func _set_stacks(data: StatusData, s: ActiveStatus, count: int) -> void:
	while s.stacks < count:
		s.stacks += 1
		for m in data.modifiers:
			manager.add_modifier(m)
	while s.stacks > count:
		s.stacks -= 1
		for m in data.modifiers:
			manager.remove_modifier(m)


func _run(effects: Array[Effect], data: StatusData, s: ActiveStatus,
		target: Node = host, cause: EffectContext = null) -> void:
	# Effects on the holder credit whoever applied the status; effects on others credit the holder.
	var ctx := EffectContext.new(s.source if target == host else host, target, data)
	ctx.magnitude = maxi(s.stacks, 1)
	ctx.from_status = true
	ctx.cause = cause
	Effect.apply_all(effects, ctx)


## Runtime state of one status on this character.
class ActiveStatus:
	## Who applied it most recently.
	var source: Node
	## Current stack count: 1 or more while active.
	var stacks: int = 0
	## Permanent sources (items, zones) keeping it active.
	var holds: int = 0
	## Seconds until it expires. Not used by passives (duration 0).
	var time_left: float = 0.0
	## Seconds until [member StatusData.on_tick] runs again.
	var tick_in: float = 0.0
