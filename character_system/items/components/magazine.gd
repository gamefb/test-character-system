@tool
@icon("res://character_system/icons/magazine.svg")
class_name Magazine
extends ItemComponent
## Limits shots to [member capacity] and reloads from the wielder's Inventory.
##
## Rounds are kept in [member ItemInstance.state], so they survive unequipping and switching.

## Emitted when the rounds loaded change: a shot or a reload.
signal changed(rounds: int)

## The ammo item used to reload.
@export var ammo: ItemData
## Rounds a full magazine holds.
@export var capacity: int = 30

## Rounds loaded. Kept in item.state, so it survives unequipping.
var rounds: int:
	get:
		return item.state.get(&"rounds", capacity)
	set(value):
		item.state[&"rounds"] = value
		changed.emit(value)


func _process(_delta: float) -> void:
	var wielder_brain: Brain = brain
	if wielder_brain and wielder_brain.is_action_just_pressed(&"reload"):
		reload()


## Uses one round. Returns false when empty.
func take() -> bool:
	if rounds == 0:
		return false
	rounds -= 1
	return true


## Refills from the wielder's [Inventory]. Wielders without one (most AI) reload for free.
func reload() -> void:
	var inventory := Component.of(wielder, Inventory) as Inventory
	var needed: int = capacity - rounds
	if inventory:
		needed = mini(needed, inventory.count(ammo))
		inventory.remove(ammo, needed)
	rounds += needed
