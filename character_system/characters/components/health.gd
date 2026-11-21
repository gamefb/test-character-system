@tool
@icon("res://character_system/icons/health.svg")
class_name Health
extends Component
## Hit points, death and damage resistances.
##
## The maximum is the [code]max_health[/code] stat, so statuses and items can raise or lower it.
## Raising it doesn't heal; lowering it only cuts health above the new maximum. A character
## starts at full health, innate passives included, whatever the node order.
##
## [DamageEffect] and [HealEffect] call [method change] for you. Every component on the
## character hears [code]died[/code] as an event.

## Emitted when health or the maximum changes, including when a max-health buff starts or ends.
signal changed(current: float, maximum: float)
## Emitted once when health reaches zero. [param ctx] is the killing blow (may be null).
signal died(ctx: EffectContext)

## Health before statuses and items. They change it through the max_health stat.
@export var max_health: float = 100.0:
	set(value):
		max_health = value
		update_stats()
## Fraction of each damage type that is ignored, e.g. { &"fire": 0.5 }. 1 = immune.
## Statuses change these through stats named resist_<type>, e.g. resist_fire.
@export var resistances: Dictionary[StringName, float] = {}:
	set(value):
		resistances = value
		update_stats()

## Health right now.
var current: float:
	get:
		return maximum() if _full else _current

var _current: float = 0.0
# Until the character has started, health stays full as the maximum changes.
var _full := true


func _stats() -> Dictionary[StringName, float]:
	var owned: Dictionary[StringName, float] = { &"max_health": max_health }
	for type in resistances:
		owned[StringName("resist_" + type)] = resistances[type]
	return owned


func _start() -> void:
	listen(manager.stat_changed, _on_stat_changed)
	if manager.started:
		# Added mid-game: the character has already started.
		_settle()


func _on_event(event: StringName, _ctx: EffectContext) -> void:
	if event == &"started":
		_settle()


## The current maximum: [member max_health] after statuses and items (the
## [code]max_health[/code] stat).
func maximum() -> float:
	return stat(&"max_health") if manager else max_health


## True once health has reached zero, until [method revive].
func is_dead() -> bool:
	return not _full and _current <= 0.0


## Adds [param amount] to health. Use a negative amount for damage. Ignored once dead.
func change(amount: float, ctx: EffectContext = null) -> void:
	if is_dead():
		return
	_current = clampf(current + amount, 0.0, maximum())
	_full = false
	changed.emit(_current, maximum())
	if _current <= 0.0:
		died.emit(ctx)
		if manager:
			manager.send(&"died", ctx)


## Brings the character back with [param amount] health, or full health if left out.
func revive(amount := -1.0) -> void:
	_current = maximum() if amount < 0.0 else minf(amount, maximum())
	_full = false
	changed.emit(_current, maximum())


# The character has finished starting: from now on, health only changes through change().
func _settle() -> void:
	if _full:
		_current = maximum()
		_full = false


func _on_stat_changed(stat_name: StringName) -> void:
	if stat_name == &"max_health":
		if not _full and _current > maximum():
			_current = maximum()  # A max-health buff ended.
		changed.emit(current, maximum())
