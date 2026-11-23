@tool
@icon("res://character_system/icons/air_mode.svg")
class_name AirMode
extends MovementMode
## In the air: fall, steer, and jump again while air jumps are left. Hands back to
## [member walk_mode] on landing.
##
## Air jumps refill on every take-off, so a double jump is [member air_jumps] = 1. Statuses
## change it through the air_jumps stat, e.g. boots that add 1.

## Jumps allowed in the air before landing: 1 is a double jump, 0 none.
@export_range(0, 5, 1, "or_greater") var air_jumps := 1:
	set(value):
		air_jumps = value
		update_stats()
## How quickly steering changes speed in the air. Lower keeps more of the take-off speed.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var air_acceleration := 20.0
## The [Brain] action that jumps.
@export var jump_action := &"jump"
## The mode to switch to on landing. Left empty, it's the [WalkMode] beside this one.
@export var walk_mode: MovementMode

## Air jumps left before landing, e.g. for a HUD.
var jumps_left := 0


func _stats() -> Dictionary[StringName, float]:
	return { &"air_jumps": air_jumps }


func _enter() -> void:
	jumps_left = int(stat(&"air_jumps"))


func _physics_update(delta: float) -> void:
	var target := motor.move_dir * stat(&"move_speed")
	body.velocity.x = move_toward(body.velocity.x, target.x, air_acceleration * delta)
	body.velocity.z = move_toward(body.velocity.z, target.z, air_acceleration * delta)
	body.velocity += body.get_gravity() * delta
	if jumps_left > 0 and motor.consume_action(jump_action):
		jumps_left -= 1
		body.velocity.y = stat(&"jump_velocity")


func _get_next_mode() -> MovementMode:
	if not body.is_on_floor():
		return null
	return walk_mode if walk_mode else motor.get_mode(WalkMode)
