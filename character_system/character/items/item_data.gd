@icon("res://character_system/icons/item_data.svg")
class_name ItemData
extends Resource
## Shared definition of an item type, saved as a .tres file.
##
## It never changes while playing. Each copy a character carries is an [ItemInstance].

## A unique name for your code and save files, e.g. &"rifle".
@export var id: StringName
## The name players see.
@export var display_name: String
## For your inventory and HUD. The system doesn't use it.
@export var icon: Texture2D
## Tooltip text for your UI.
@export_multiline var description: String
## How many fit in one inventory stack. Use 1 for items with their own state, such as weapons.
@export var max_stack: int = 1
## [Equipment] slot, e.g. &"weapon". The character's [member Equipment.sockets] needs an entry
## with the same name. Leave empty if the item can't be equipped, such as ammo.
@export var slot: StringName
## Spawned when equipped. Its root is the model, with a [ComponentManager] and the
## [ItemComponent]s that decide what the item does as children.
@export var scene: PackedScene
## Run in order on the character that uses the item with [method Inventory.use], e.g. a
## [HealEffect] for a health potion or an [ApplyStatusEffect] for a strength elixir. Leave
## empty for items that can't be used this way.
@export var use_effects: Array[Effect] = []
## On: one is taken from the stack each time it's used. Off: it can be used again and again,
## e.g. a horn.
@export var consumed_on_use := true
