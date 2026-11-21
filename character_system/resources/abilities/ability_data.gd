class_name AbilityData
extends Resource
## An active ability: who it targets and what it does to them.
##
## Put it in [member Abilities.slots] under an action name.

## A unique name for your code and save files, e.g. &"fireball".
@export var id: StringName
## The name players see.
@export var display_name: String
## For your ability bar. The system doesn't use it.
@export var icon: Texture2D
## Seconds before it can be used again.
@export var cooldown: float = 1.0
## Picks who the effects apply to. Leave empty to affect the user.
@export var targeting: Targeting
## Run in order on each node [member targeting] returns.
@export var effects: Array[Effect] = []
