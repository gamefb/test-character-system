@tool
@icon("res://character_system/icons/ai_brain.svg")
class_name AIBrain
extends Brain
## Steers toward [member target] along the navigation mesh.
##
## Decision logic (a state machine or behavior tree) sets [member target] and calls
## [method Brain.press] and [method Brain.release] to attack, exactly like a player pressing a
## button. Put it in its own component beside the brain; [AttackNearest] in
## [code]examples/scripts/[/code] is a small one to start from.
##
## Finding a path is the expensive part of steering, so a new one is only asked for when the
## target has moved [member repath_distance] metres. Many characters can chase the same target
## without each one searching the navigation mesh every frame.

## Finds the paths. Leave it empty to use the first [NavigationAgent3D] under the character.
## If the character has a path but stands still, set the agent's Path Height Offset to how far
## the baked navigation mesh sits above the floor (0.5 m for a default bake).
@export var agent: NavigationAgent3D:
	set(value):
		agent = value
		update_configuration_warnings()
## How far, in metres, [member target] must move before a new path is found. Lower follows a
## fast target more closely and costs more. 0 finds a new path whenever it moves at all.
@export var repath_distance: float = 1.0
## How high above the target's origin to aim, in metres. 1 aims at the chest of a character
## whose origin is at its feet; use 0 if the target's origin is its centre.
@export var aim_height: float = 1.0
## The node to move toward and aim at. Null = stand still.
var target: Node3D

# Where the current path leads. INF means there's no path yet.
var _goal := Vector3.INF


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		move_dir = Vector3.ZERO
		return
	var goal: Vector3 = target.global_position
	aim_point = goal + Vector3.UP * aim_height
	if goal.distance_to(_goal) > repath_distance:
		_goal = goal
		agent.target_position = _goal  # Godot finds the new path on the next line.
	var next_position: Vector3 = agent.get_next_path_position()
	var to_next: Vector3 = (host as Node3D).global_position.direction_to(next_position)
	# Flat, so slopes don't slow the AI.
	move_dir = to_next.slide(Vector3.UP).normalized()


func _start() -> void:
	if not agent:
		agent = find_node_of_type(&"NavigationAgent3D")
	_goal = Vector3.INF


func _warnings() -> PackedStringArray:
	var out: PackedStringArray = super()
	if not agent and not find_node_of_type(&"NavigationAgent3D"):
		out.append("Add a NavigationAgent3D to the character, or set the Agent.")
	return out
