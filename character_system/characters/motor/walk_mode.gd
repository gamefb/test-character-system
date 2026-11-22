@tool
@icon("res://character_system/icons/walk_mode.svg")
class_name WalkMode
extends MovementMode
## On the floor: walk at the move_speed stat, and jump on [member jump_action]. Hands over to
## [member air_mode] once the floor is gone.

## The [Brain] action that jumps.
@export var jump_action := &"jump"
## The mode to switch to off the floor. Left empty, it's the [AirMode] beside this one.
@export var air_mode: MovementMode


func _physics_update(delta: float) -> void:
	var speed := stat(&"move_speed")
	body.velocity.x = motor.brain.move_dir.x * speed
	body.velocity.z = motor.brain.move_dir.z * speed
	body.velocity += body.get_gravity() * delta
	if body.is_on_floor() and motor.consume_action(jump_action):
		body.velocity.y = stat(&"jump_velocity")


func _get_next_mode() -> MovementMode:
	if body.is_on_floor():
		return null
	return air_mode if air_mode else motor.get_mode(AirMode)
