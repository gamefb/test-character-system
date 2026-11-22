@tool
@icon("res://character_system/icons/air_mode.svg")
class_name AirMode
extends MovementMode
## In the air: fall, steer, and jump again while air jumps are left.
##
## Air jumps refill each time the character takes off, so a double jump is just
## [member air_jumps] = 1 here. Statuses change it through the air_jumps stat, e.g. boots that
## add 1. It hands back to [member walk_mode] on landing.

## Jumps allowed in the air before landing. 1 is a double jump, 0 none.
@export var air_jumps: int = 1:
	set(value):
		air_jumps = value
		update_stats()
## How quickly steering changes sideways speed in the air, in metres per second per second.
## Lower keeps more of the speed it took off with.
@export var air_acceleration: float = 20.0
## The mode to switch to on landing.
@export var walk_mode: StringName = &"walk"

var _jumps_left: int = 0


func _init() -> void:
	mode_name = &"air"


## Air jumps left before landing, e.g. for a HUD.
func jumps_left() -> int:
	return _jumps_left


func _enter() -> void:
	_jumps_left = int(stat(&"air_jumps"))


func _tick(delta: float) -> void:
	var wish: Vector3 = motor.input.direction * stat(&"move_speed")
	var sideways := Vector3(body.velocity.x, 0.0, body.velocity.z)
	sideways = sideways.move_toward(Vector3(wish.x, 0.0, wish.z), air_acceleration * delta)
	body.velocity = Vector3(sideways.x, body.velocity.y, sideways.z) + body.get_gravity() * delta
	if _jumps_left > 0 and motor.input.consume(&"jump"):
		_jumps_left -= 1
		body.velocity.y = stat(&"jump_velocity")


func _next_mode() -> StringName:
	return walk_mode if body.is_on_floor() else &""


func _stats() -> Dictionary[StringName, float]:
	return { &"air_jumps": air_jumps }
