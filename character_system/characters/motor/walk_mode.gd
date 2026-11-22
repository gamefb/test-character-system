@tool
@icon("res://character_system/icons/walk_mode.svg")
class_name WalkMode
extends MovementMode
## On the floor: walk at the move_speed stat, and jump on the jump request.
##
## When the floor is gone, after a jump or off a ledge, it hands over to [member air_mode].

## The mode to switch to when the character leaves the floor.
@export var air_mode: StringName = &"air"


func _init() -> void:
	mode_name = &"walk"


func _tick(delta: float) -> void:
	var speed: float = stat(&"move_speed")
	body.velocity.x = motor.input.direction.x * speed
	body.velocity.z = motor.input.direction.z * speed
	body.velocity += body.get_gravity() * delta  # Keeps it pressed to the floor.
	if body.is_on_floor() and motor.input.consume(&"jump"):
		body.velocity.y = stat(&"jump_velocity")


func _next_mode() -> StringName:
	return &"" if body.is_on_floor() else air_mode
