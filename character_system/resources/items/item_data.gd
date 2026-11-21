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
## How many fit in one inventory stack. Use 1 for items with their own state, such as weapons.
@export var max_stack: int = 1
## [Equipment] slot, e.g. &"weapon". Leave empty if the item can't be equipped.
@export var slot: StringName
## Spawned when equipped. Its [ItemComponent] children decide what the item does.
@export var scene: PackedScene
