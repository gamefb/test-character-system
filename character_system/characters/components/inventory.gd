@tool
@icon("res://character_system/icons/inventory.svg")
class_name Inventory
extends Component
## The items a character carries, as stacks.
##
## It knows nothing about what items do. Every change emits [signal changed] and is also
## sent to the host's components as the [code]inventory_changed[/code] event, which
## [Equipment] and [WeaponSwitch] use.

## Emitted whenever items are added or removed.
signal changed

## The stacks carried, in order. Change it through [method add], [method add_instance],
## [method remove] and [method remove_instance], so [signal changed] is emitted.
@export var items: Array[ItemInstance] = []


## Total number of [param data] across all stacks.
func count(data: ItemData) -> int:
	return items.reduce(func(total: int, item: ItemInstance) -> int:
		return total + (item.count if item.data == data else 0), 0)


## Adds [param amount] of [param data], filling existing stacks before making new ones.
func add(data: ItemData, amount := 1) -> void:
	for item in items:
		if item.data == data and item.count < data.max_stack:
			var moved: int = mini(amount, data.max_stack - item.count)
			item.count += moved
			amount -= moved
	while amount > 0:
		var moved: int = mini(amount, data.max_stack)
		items.append(ItemInstance.new(data, moved))
		amount -= moved
	_changed()


## Adds an existing copy and keeps its state. Use for picking up a dropped weapon.
func add_instance(item: ItemInstance) -> void:
	items.append(item)
	_changed()


## Removes [param amount] of [param data]. Returns false, removing nothing, if there isn't enough.
func remove(data: ItemData, amount := 1) -> bool:
	if count(data) < amount:
		return false
	for item in items.duplicate():
		if item.data == data and amount > 0:
			var taken: int = mini(amount, item.count)
			item.count -= taken
			amount -= taken
			if item.count == 0:
				items.erase(item)
	_changed()
	return true


## The first stack of [param data], or null if none is carried.
func first(data: ItemData) -> ItemInstance:
	var index: int = items.find_custom(func(item: ItemInstance) -> bool: return item.data == data)
	return items[index] if index != -1 else null


## Removes one particular copy, e.g. the weapon being dropped, and keeps its state.
## Returns false if it isn't carried.
func remove_instance(item: ItemInstance) -> bool:
	if item not in items:
		return false
	items.erase(item)
	_changed()
	return true


func _changed() -> void:
	changed.emit()
	if manager:
		manager.send(&"inventory_changed", null)
