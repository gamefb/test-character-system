@tool
@icon("res://character_system/icons/layered_move.svg")
class_name GlideMove
extends LayeredMove
## An example layered move to copy: hold jump while falling to glide down slowly.
##
## It runs on top of [AirMode] without changing it: the air mode still steers and double jumps,
## and the glide only limits how fast the character falls while the button is held. Add it as a
## child of the [CharacterMotor].

## Fastest fall while gliding.
@export_range(0.0, 10.0, 0.1, "or_greater", "suffix:m/s") var fall_speed := 1.0
## Held to glide.
@export var action := &"jump"


func _can_start() -> bool:
	return (
			motor.mode is AirMode and body.velocity.y < 0.0
			and motor.brain.is_action_pressed(action)
	)


func _physics_update(_delta: float) -> void:
	body.velocity.y = maxf(body.velocity.y, -fall_speed)
	if not motor.brain.is_action_pressed(action) or not motor.mode is AirMode:
		active = false
