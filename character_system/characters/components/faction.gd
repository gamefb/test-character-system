@tool
@icon("res://character_system/icons/faction.svg")
class_name Faction
extends Component
## Which team this character is on and which teams it fights.
##
## While it runs, the character is in the Godot group named after its [member team], so
## [code]get_tree().get_nodes_in_group(&"enemy")[/code] finds every enemy. AI decision logic
## uses [method is_hostile] to pick targets.

## This character's team, e.g. &"player" or &"enemy". Changing it during play (charm,
## betrayal) moves the character to the new team's group.
@export var team: StringName:
	set(value):
		if running:
			_stop()
		team = value
		if running:
			_start()
## Teams this character fights. Hostility is one-way, so list it on both sides
## for a mutual fight.
@export var hostile_to: Array[StringName] = []


func _start() -> void:
	if team:
		host.add_to_group(team)


func _stop() -> void:
	host.remove_from_group(team)


## True if [param other] is in the group of a team this character fights.
func is_hostile(other: Variant) -> bool:
	return is_instance_valid(other) and other is Node and hostile_to.any(other.is_in_group)
