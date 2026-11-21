@tool
class_name AttackNearest
extends Component
## An example of AI decision logic to copy: chase the nearest character this one's [Faction]
## fights, and attack it when it's in range.
##
## Decisions live in their own component beside an [AIBrain]. This one only sets
## [member AIBrain.target] and taps a button, exactly as a player would click, so every weapon
## and ability works with it. Grow it into a state machine or behaviour tree as your AI needs.

## Seconds between decisions. Each one searches for a target, so not every frame.
@export var think_interval: float = 0.5
## How close, in metres, the target must be to attack it.
@export var attack_range: float = 15.0
## Tapped once per decision while the target is in range.
@export var action: StringName = &"primary"

var _think_in: float = 0.0


func _requires() -> Array[Script]:
	return [AIBrain, Faction]


func _process(delta: float) -> void:
	_think_in -= delta
	if _think_in > 0.0:
		return
	_think_in = think_interval
	var brain := find(AIBrain) as AIBrain
	var previous: Node3D = brain.target
	brain.target = _nearest_enemy()
	# Only attack a target it already had, so the brain has had time to aim at it. That also
	# gives the AI a reaction time of one think_interval.
	if brain.target and brain.target == previous and _distance_to(brain.target) <= attack_range:
		# A tap: the weapon sees one press, like a click.
		brain.press(action)
		brain.release(action)


# The closest node in a group this character is hostile to, or null.
func _nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	for team in (find(Faction) as Faction).hostile_to:
		for other in get_tree().get_nodes_in_group(team):
			if other is Node3D and other != host:
				if not nearest or _distance_to(other) < _distance_to(nearest):
					nearest = other
	return nearest


func _distance_to(node: Node3D) -> float:
	return (host as Node3D).global_position.distance_to(node.global_position)
