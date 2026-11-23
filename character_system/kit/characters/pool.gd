@tool
@icon("res://character_system/icons/component.svg")
class_name Pool
extends Component
## A number that's spent and regained: mana, stamina, energy, rage, or a shield over health.
##
## Add one per kind and name it with [member pool]. A character can have several. Abilities
## spend from pools through [member AbilityData.costs], effects change them with a
## [ChangePoolEffect], and code uses [method spend] and [method change]:
## [codeblock]
## var mana := Pool.named(player, &"mana")
## if mana and mana.spend(20.0):
## 	cast()
## [/codeblock]
## The maximum is the [code]max_<pool>[/code] stat and the refill rate the
## [code]<pool>_regen[/code] stat (e.g. [code]max_mana[/code] and [code]mana_regen[/code]), so
## statuses and items change both. A pool that starts full starts at its buffed maximum,
## innate passives included, whatever the node order.
## [br][br][b]A shield.[/b] Turn on [member absorbs_damage] and the pool soaks up damage before
## [Health] loses any. With [member regen] and [member regen_delay] it's a shield that
## recharges once the character has been out of the fight for a moment.

## Emitted when the pool or its maximum changes, e.g. for a mana bar.
signal changed(current: float, maximum: float)
## Emitted when the pool reaches 0, e.g. to play a shield-break sound.
signal emptied

## Which pool this is, e.g. &"mana". Costs and effects find it by this name.
@export var pool: StringName = &"mana":
	set(value):
		pool = value
		update_stats()
## How much it holds before statuses and items. They change it through the max_<pool> stat.
@export var max_value: float = 100.0:
	set(value):
		max_value = value
		update_stats()
## Regained per second, through the <pool>_regen stat. Negative drains, e.g. rage that fades.
@export var regen: float = 0.0:
	set(value):
		regen = value
		update_stats()
## Seconds after the pool is spent or drained before [member regen] starts again.
@export var regen_delay: float = 0.0
## On: the pool starts full. Off: it starts empty, e.g. rage built up by fighting.
@export var starts_full := true
## On: damage is taken from this pool first, and only what's left reaches [Health].
@export var absorbs_damage := false
## With [member absorbs_damage] on: the damage types it soaks up. Empty for every type.
@export var absorbed_types: Array[StringName] = []

## How much is in the pool right now.
var current: float = 0.0

var _regen_in: float = 0.0  # Seconds until regen starts again.


## Returns [param node]'s pool called [param pool_name], or null. Safe on null or freed nodes
## and on nodes without components.
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
		return
	var rate: float = stat(StringName(pool + "_regen"))
	if rate != 0.0:
		_set_current(current + rate * delta)


func _stats() -> Dictionary[StringName, float]:
	return {
		StringName("max_" + pool): max_value,
		StringName(pool + "_regen"): regen,
	}


func _start() -> void:
	listen(manager.stat_changed, _on_stat_changed)
	on(&"absorbing_damage", _on_absorbing_damage)
	# Innate passives may raise the maximum after this pool starts: fill up again once the
	# whole character has started, as Health does.
	on(&"started", _fill)
	_regen_in = 0.0
	_fill()


## The most the pool can hold right now: [member max_value] after statuses and items.
func maximum() -> float:
	return stat(StringName("max_" + pool)) if manager else max_value


## How full the pool is, from 0 to 1, e.g. for a bar.
func fraction() -> float:
	var most: float = maximum()
	return current / most if most > 0.0 else 0.0


## Takes [param amount] if the pool has that much. Returns false, taking nothing, if it doesn't.
func spend(amount: float) -> bool:
	if amount > current:
		return false
	change(-amount)
	return true


## Adds [param amount] to the pool, or takes it away if negative, staying between 0 and the
## maximum. Taking away restarts [member regen_delay].
func change(amount: float) -> void:
	if amount < 0.0:
		_regen_in = regen_delay
	_set_current(current + amount)


func _fill(_ctx: EffectContext = null) -> void:
	current = maximum() if starts_full else 0.0
	changed.emit(current, maximum())


func _set_current(value: float) -> void:
	var before: float = current
	current = clampf(value, 0.0, maximum())
	if current != before:
		changed.emit(current, maximum())
		if current <= 0.0:
			emptied.emit()


func _on_stat_changed(stat_name: StringName) -> void:
	if stat_name == StringName("max_" + pool):
		current = minf(current, maximum())
		changed.emit(current, maximum())


func _on_absorbing_damage(ctx: EffectContext) -> void:
	if not absorbs_damage or not ctx or ctx.amount <= 0.0 or current <= 0.0:
		return
	if absorbed_types.is_empty() or ctx.damage_type in absorbed_types:
		var soaked: float = minf(current, ctx.amount)
		ctx.amount -= soaked
		change(-soaked)
