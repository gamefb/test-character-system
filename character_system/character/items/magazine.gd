@tool
@icon("res://character_system/icons/magazine.svg")
class_name Magazine
extends ItemComponent
## Limits shots to [member capacity] and reloads from the wielder's Inventory.
##
## Rounds are kept in [member ItemInstance.state], so they survive unequipping and switching.
## With a [member reload_time], the item can't fire until the reload is done, and switching
## weapons mid-reload loses it.

## Emitted when the rounds loaded change: a shot or a reload.
signal changed(rounds: int)
## Emitted when a reload with a [member reload_time] begins, e.g. to play an animation.
signal reload_started
## Emitted when the rounds from a reload are loaded.
signal reload_finished

## The ammo item used to reload. Leave empty for a weapon that reloads for free.
@export var ammo: ItemData
## Rounds a full magazine holds.
@export var capacity: int = 30
## Seconds a reload takes. 0 is instant.
@export_range(0.0, 10.0, 0.05, "or_greater", "suffix:s") var reload_time: float = 0.0
## Reload by itself when the trigger is pulled on an empty magazine.
@export var auto_reload := false

## Rounds loaded. Kept in item.state, so it survives unequipping.
var rounds: int:
	get:
		return item.state.get(&"rounds", capacity)
	set(value):
		item.state[&"rounds"] = value
		changed.emit(value)


var _reload_left: float = 0.0


## The [Magazine] on the item scene [param node], or null if there is none. Safe on a freed node.
static func find_on(node: Variant) -> Magazine:
	return Component.of(node, Magazine) as Magazine


func _process(delta: float) -> void:
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_load()
		return
	var wielder_brain: Brain = brain
	if wielder_brain and wielder_brain.is_action_just_pressed(&"reload"):
		reload()


func _stop() -> void:
	_reload_left = 0.0  # Put away mid-reload: start again next time.


## True while a reload with a [member reload_time] is under way.
func is_reloading() -> bool:
	return _reload_left > 0.0


## Uses one round. Returns false when empty or reloading.
func take() -> bool:
	if is_reloading():
		return false
	if rounds == 0:
		if auto_reload:
			reload()
		return false
	rounds -= 1
	return true


## Refills from the wielder's [Inventory]. Wielders without one (most AI) reload for free, and
## so does a magazine without an [member ammo] item.
## With a [member reload_time] the rounds arrive when it has passed. Does nothing if the
## magazine is full, there's no ammo to load, or a reload is already under way.
func reload() -> void:
	if is_reloading() or _loadable() <= 0:
		return
	if reload_time <= 0.0:
		_load()
		return
	_reload_left = reload_time
	reload_started.emit()


# How many rounds a reload would load right now.
func _loadable() -> int:
	var inventory := Inventory.find_on(wielder)
	var needed: int = capacity - rounds
	return mini(needed, inventory.count(ammo)) if inventory and ammo else needed


func _load() -> void:
	var needed: int = _loadable()
	var inventory := Inventory.find_on(wielder)
	if inventory and ammo:
		inventory.remove(ammo, needed)
	rounds += needed
	reload_finished.emit()
