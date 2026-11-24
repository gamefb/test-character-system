@tool
@icon("res://character_system/icons/movement_mode.svg")
class_name WallSlideMode
extends MovementMode
## An example movement mode to copy: slide slowly down a wall while falling against it, and jump
## off it.
##
## It takes over by itself, in [method MovementMode._can_enter], so [WalkMode] and [AirMode]
## don't need to know it exists. Add it as a child of the [CharacterMotor]. The character stays
## on the wall while it steers into it, and lets go by steering away or jumping.

## Fastest fall while sliding.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s") var slide_speed := 2.0
## Speed away from the wall when jumping off it.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s") var push_off := 6.0
## The [Brain] action that jumps off the wall.
@export var jump_action := &"jump"


func _can_enter() -> bool:
	return body.is_on_wall_only() and body.velocity.y < 0.0


func _physics_update(delta: float) -> void:
	var speed := stat(&"move_speed")
	body.velocity.x = motor.move_dir.x * speed
	body.velocity.z = motor.move_dir.z * speed
	body.velocity += body.get_gravity() * delta
	body.velocity.y = maxf(body.velocity.y, -slide_speed)
	if motor.consume_action(jump_action):
		body.velocity = body.get_wall_normal() * push_off + Vector3.UP * stat(&"jump_velocity")


func _get_next_mode() -> MovementMode:
	if body.is_on_wall_only():
		return null
	return motor.get_mode(WalkMode) if body.is_on_floor() else motor.get_mode(AirMode)
