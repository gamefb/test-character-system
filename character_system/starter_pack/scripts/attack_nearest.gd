@tool
class_name AttackNearest
extends Component
## An example of AI decision logic to copy: chase the nearest character this one's [Faction]
## fights, and attack it when it's in range.
##
## Decisions live in their own component beside an [AIBrain]. This one only sets
## [member AIBrain.target] and presses a button, exactly as a player would, so every weapon
## and ability works with it. Grow it into a state machine or behaviour tree as your AI needs.

## Seconds between decisions. Each one searches for a target, so not every frame.
@export var think_interval: float = 0.5
## How close, in metres, the target must be to attack it.
@export var attack_range: float = 15.0
## Pressed once per decision while the target is in range.
@export var action: StringName = &"primary"
## Seconds the button is held before it is let go. 0 taps it. For a weapon that charges, the
## time the AI should charge it for.
@export var hold_time: float = 0.0

var _think_in: float = 0.0
# Seconds until the held button is let go; negative when nothing is held.
var _let_go_in: float = -1.0


func _process(delta: float) -> void:
	if _let_go_in >= 0.0:
		_let_go_in -= delta
		if _let_go_in < 0.0:
			(find(AIBrain) as AIBrain).release(action)
		return
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
		brain.press(action)
		if hold_time > 0.0:
			_let_go_in = hold_time
		else:
			# A tap: the weapon sees one press, like a click.
			brain.release(action)


func _requires() -> Array[Script]:
	return [AIBrain, Faction]


func _stop() -> void:
	var brain := find(AIBrain) as AIBrain
	if brain and _let_go_in >= 0.0:
		brain.release(action)
	_let_go_in = -1.0


# The closest node in a group this character is hostile to, or null.
func _nearest_enemy() -> Node3D:
	var nearest: Node3D = null
	for team in (find(Faction) as Faction).hostile_to:
		for other in get_tree().get_nodes_in_group(team):
			if (
					other is Node3D and other != host
					and not ComponentManager.blocked(other, &"targeting")
			):
				if not nearest or _distance_to(other) < _distance_to(nearest):
					nearest = other
	return nearest


func _distance_to(node: Node3D) -> float:
	return (host as Node3D).global_position.distance_to(node.global_position)
