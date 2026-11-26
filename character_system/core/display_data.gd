@tool
@abstract
class_name DisplayData
extends DataResource
## Base class for data a player sees by name: [StatusData], [AbilityData] and [ItemData].
##
## It holds what a status bar, an ability bar or an inventory needs to show one. The system
## itself only reads [member id], to match an [Animator] row to one item or ability.

## A unique name for your code and save files, e.g. &"burning", &"fireball" or &"rifle".
@export var id: StringName
## The name players see.
@export var display_name: String
## For your UI. The system doesn't use it.
@export var icon: Texture2D
## Tooltip text for your UI.
@export_multiline var description: String
