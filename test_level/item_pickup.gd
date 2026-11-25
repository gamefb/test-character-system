class_name ItemPickup
extends Area3D
## Test-level helper: puts an item into the Inventory of whoever walks over it, then disappears.
## It only fills the bag. Equipping is up to the game (see test_level.gd).

## Emitted when [param by] picks the item up.
signal picked_up(by: Node)

## The item to give.
@export var item: ItemData
## How many to give, e.g. 15 rounds of ammo.
@export var count: int = 1


func _ready() -> void:
	# Shots pass through; bodies are still detected by the mask.
	collision_layer = 0
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var bag := Inventory.find_on(body)
	if not bag or not item:
		return
	bag.add(item, count)
	picked_up.emit(body)
	queue_free()
