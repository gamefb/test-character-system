@icon("res://character_system/icons/item_instance.svg")
class_name ItemInstance
extends Resource
## One copy (or one stack) of an item, with its own state.
##
## The same instance moves between [Inventory] and [Equipment], so its [member state] (rounds
## loaded, durability) is kept.

## What item this is.
@export var data: ItemData
## How many are in this stack. Always 1 for items whose max stack is 1.
@export var count: int = 1
## Values item components keep between equips, e.g. { &"rounds": 12 }.
@export var state: Dictionary[StringName, Variant] = {}


## A new copy of [param p_data], or a stack of [param p_count].
func _init(p_data: ItemData = null, p_count := 1) -> void:
	data = p_data
	count = p_count
