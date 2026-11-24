@tool
@icon("res://character_system/icons/component.svg")
class_name Pool
extends Component
## An amount that is spent and refilled: health, mana, stamina, rage or a shield.
##
## Add one for each resource a character has and name it with [member pool]. It owns the stats
## [code]max_<pool>[/code] and [code]<pool>_regen[/code], so gear and statuses can change
## them. Everything that uses up or gives back a resource works on pools: an ability's
## [member AbilityData.costs], a [ChangePoolEffect], a [PoolAmount] and a
## [PoolBelowCondition]. [Health] is the pool named [code]health[/code].
## [br][br]
## [b]Running out.[/b] [member status_while_empty] is on the character for as long as the pool
## is empty: Exhausted for stamina, Dead for health. What the character can't do meanwhile is
## up to that status and its [member StatusData.blocks].
## [br][br]
## [b]Shields.[/b] With [member absorbs_damage] on, the pool soaks up damage before health
## does, after resistances have been applied.

## Emitted when the amount or its maximum changes.
signal changed(current: float, maximum: float)
## Emitted when the pool runs out.
signal emptied

## The pool's name, e.g. &"mana". Costs and effects find the pool by it.
@export var pool: StringName = &"mana":
	set(value):
		pool = value
		_max_stat = StringName("max_" + pool)
		_regen_stat = StringName(pool + "_regen")
		update_stats()
## The base of the stat [code]max_<pool>[/code].
@export var max_value: float = 100.0:
	set(value):
		max_value = value
		update_stats()
## The base of the stat [code]<pool>_regen[/code]: how much comes back each second. Negative
## drains it.
@export var regen: float = 0.0:
	set(value):
		regen = value
		update_stats()
## Seconds without regeneration after the pool was last spent from or damaged.
@export var regen_delay: float = 0.0
## Off: the pool starts empty, e.g. rage.
@export var starts_full := true
## Given to the character while the pool is empty and taken back when it has something again.
## Use a status with duration 0.
@export var status_while_empty: StatusData
## Soaks up damage before health does, like a shield.
@export var absorbs_damage := false:
	set(value):
		absorbs_damage = value
		if running:
			_listen_for_damage()
## The damage types it soaks up. Empty means all of them.
@export var absorbed_types: Array[StringName] = []

## How much is in the pool.
var current: float:
	get:
		return _start_value() if _fresh else _current
	set(value):
		_set_current(value)

var _current: float = 0.0
# Until the character has started, the pool follows its maximum.
var _fresh := true
var _regen_in: float = 0.0  # Seconds until regen starts again.
var _held: StatusData  # The status this pool is holding on the character, if any.
var _max_stat: StringName = &"max_mana"
var _regen_stat: StringName = &"mana_regen"


## The pool called [param pool_name] on [param node]'s character, or null. Safe on a freed node.
static func named(node: Variant, pool_name: StringName) -> Pool:
	var m := ComponentManager.of(node)
	if m:
		for found: Pool in m.find_all(Pool):
			if found.pool == pool_name:
				return found
	return null


func _process(delta: float) -> void:
	if _regen_in > 0.0:
		_regen_in -= delta
	elif _regenerates():
		_set_current(current + stat(_regen_stat) * delta)


func _stats() -> Dictionary[StringName, float]:
	return { _max_stat: max_value, _regen_stat: regen }


func _start() -> void:
	listen(manager.stat_changed, _on_stat_changed)
	_listen_for_damage()
	# Innate passives may raise the maximum after this pool starts, so it only settles on a
	# number once the whole character has started.
	on(&"started", _settle)
	_regen_in = 0.0
	set_process(stat(_regen_stat) != 0.0)
	if manager.started:
		_settle()  # Added mid-game.


func _stop() -> void:
	_release()


func _warnings() -> PackedStringArray:
	if _empty_status() and not get_parent().get_children().any(
			func(node: Node) -> bool: return node is Statuses):
		return PackedStringArray(["Add a Statuses component beside this, or the '%s' status "
				% _empty_status().display_name + "can't be given when the pool is empty."])
	return PackedStringArray()


## The most the pool holds: the stat [code]max_<pool>[/code].
func maximum() -> float:
	return stat(_max_stat) if manager else max_value


## How full the pool is, from 0 to 1.
func fraction() -> float:
	var most: float = maximum()
	return current / most if most > 0.0 else 0.0


## Takes [param amount] if the pool has that much. Returns false, and takes nothing, if not.
func spend(amount: float) -> bool:
	if amount > current:
		return false
	change(-amount)
	return true


## Adds [param amount], or takes it away when it is negative. [param ctx] says who did it, so
## the status given at zero can credit them.
func change(amount: float, ctx: EffectContext = null) -> void:
	if amount < 0.0:
		_regen_in = regen_delay
	_set_current(current + amount, ctx)


# Whether the pool refills by itself right now.
func _regenerates() -> bool:
	return true


# The status the character has while this pool is empty.
func _empty_status() -> StatusData:
	return status_while_empty


# The pool has just run out.
func _emptied(_ctx: EffectContext) -> void:
	pass


# The pool has something in it again.
func _refilled() -> void:
	pass


# Only a pool that absorbs damage hears about hits, so the others cost a hit nothing.
func _listen_for_damage() -> void:
	if absorbs_damage:
		on(&"absorbing_damage", _on_absorbing_damage)


func _start_value() -> float:
	return maximum() if starts_full else 0.0


# The character has finished starting: from now on, the pool only changes when told to.
func _settle(_ctx: EffectContext = null) -> void:
	if _fresh:
		_current = _start_value()
		_fresh = false
		if _current <= 0.0:
			_hold(null)
	changed.emit(_current, maximum())


func _set_current(value: float, ctx: EffectContext = null) -> void:
	var before: float = _start_value() if _fresh else _current
	_current = clampf(value, 0.0, maximum())
	_fresh = false
	if _current == before:
		return
	changed.emit(_current, maximum())
	if _current <= 0.0:
		_hold(ctx)
		emptied.emit()
		_emptied(ctx)
	elif before <= 0.0:
		_release()
		_refilled()


func _hold(ctx: EffectContext) -> void:
	var data: StatusData = _empty_status()
	var statuses := find(Statuses) as Statuses
	if data and statuses and not _held:
		var source: Node = ctx.source if ctx and is_instance_valid(ctx.source) else null
		if statuses.add(data, source):
			_held = data


func _release() -> void:
	var statuses := find(Statuses) as Statuses
	if _held and statuses:
		statuses.drop_hold(_held)
	_held = null


func _on_stat_changed(stat_name: StringName) -> void:
	if stat_name == _max_stat:
		if not _fresh and _current > maximum():
			_current = maximum()  # A buff to the maximum ended.
		changed.emit(current, maximum())
	elif stat_name == _regen_stat:
		set_process(stat(_regen_stat) != 0.0)


func _on_absorbing_damage(ctx: EffectContext) -> void:
	if not absorbs_damage or not ctx or ctx.amount <= 0.0 or current <= 0.0:
		return
	if absorbed_types.is_empty() or ctx.damage_type in absorbed_types:
		var soaked: float = minf(current, ctx.amount)
		ctx.amount -= soaked
		change(-soaked)
