@tool
@icon("res://character_system/icons/ai_brain.svg")
class_name AIBrain
extends Brain
## Steers toward [member target] along the navigation mesh.
##
## Decision logic (a state machine or behavior tree) sets [member target] and calls
## [method Brain.press] and [method Brain.release] to attack, exactly like a player pressing a
## button.

## If the character has a path but stands still, set this agent's Path Height Offset to how
## far the baked navigation mesh sits above the floor (0.5 m for a default bake).
@export var agent: NavigationAgent3D:
	set(value):
		agent = value
		update_configuration_warnings()
## The node to move toward and aim at. Null = stand still.
var target: Node3D


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(target):
		move_dir = Vector3.ZERO
		return
	agent.target_position = target.global_position
	aim_point = target.global_position
	var next_position: Vector3 = agent.get_next_path_position()
	var to_next: Vector3 = (host as Node3D).global_position.direction_to(next_position)
	# Flat, so slopes don't slow the AI.
	move_dir = to_next.slide(Vector3.UP).normalized()


func _warnings() -> PackedStringArray:
	var out: PackedStringArray = super()
	if not agent:
		out.append("Set the Agent to a NavigationAgent3D.")
	return out
