@tool
@icon("res://character_system/icons/grant_statuses.svg")
class_name GrantStatuses
extends ItemComponent
## Gives the wielder passives while the item is equipped.
##
## Use statuses with duration 0. Each one is a hold, so two items granting the same passive keep
## it until both are unequipped.

## Passives given while equipped. Each is one hold, so two items granting the same
## passive keep it until both are unequipped.
@export var statuses: Array[StatusData] = []

# Only the ones accepted, so only their holds are dropped.
var _granted: Array[StatusData] = []


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(statuses)


func _start() -> void:
	var target := Component.of(wielder, Statuses) as Statuses
	if target:
		for s in statuses:
			if target.add(s, wielder):
				_granted.append(s)


func _stop() -> void:
	var target := Component.of(wielder, Statuses) as Statuses
	if target:
		for s in _granted:
			target.drop_hold(s)
	_granted.clear()
