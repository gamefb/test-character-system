@tool
@icon("res://character_system/icons/grant_statuses.svg")
class_name GrantAbilities
extends ItemComponent
## Gives the wielder abilities while the item is equipped: a staff that casts Fireball, boots
## with a dash.
##
## Each ability goes into the wielder's [member Abilities.slots] under its action name, and
## whatever was there before comes back when the item is unequipped. A wielder without an
## [Abilities] component gets nothing. Cooldowns belong to the wielder, so swapping the item
## out and back in doesn't reset them.

## Action name to ability, e.g. { &"secondary": fireball }, as in [member Abilities.slots].
@export var abilities: Dictionary[StringName, AbilityData] = {}

var _previous: Dictionary[StringName, AbilityData] = {}


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(abilities.values())


func _start() -> void:
	var target := Component.of(wielder, Abilities) as Abilities
	if not target:
		return
	for action in abilities:
		_previous[action] = target.slots.get(action)
		target.slots[action] = abilities[action]


func _stop() -> void:
	var target := Component.of(wielder, Abilities) as Abilities
	if target:
		for action in _previous:
			if target.slots.get(action) != abilities.get(action):
				continue  # Something else took the slot meanwhile: leave it.
			if _previous[action]:
				target.slots[action] = _previous[action]
			else:
				target.slots.erase(action)
	_previous.clear()
