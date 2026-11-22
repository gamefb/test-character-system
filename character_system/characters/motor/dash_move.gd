@tool
@icon("res://character_system/icons/dash_move.svg")
class_name DashMove
extends LayeredMove
## On the dash request, shoots the character the way it's moving, or facing if it's standing
## still, for a moment.
##
## While it runs it replaces the mode's velocity, so there's no gravity and no steering, on the
## floor or in the air. Afterwards the mode takes over again: walking stops at once, while the
## air keeps some of the speed.

## The request that starts it.
@export var request: StringName = &"dash"
## Speed during the dash, in metres per second.
@export var speed: float = 15.0
## How long a dash lasts, in seconds.
@export var duration: float = 0.2
## Seconds from the start of one dash until the next is allowed.
@export var cooldown: float = 0.6

var _time_left: float = 0.0
var _cooldown_left: float = 0.0
var _direction := Vector3.ZERO


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _wants_to_start() -> bool:
	return _cooldown_left == 0.0 and motor.input.consume(request)


func _activate() -> void:
	var way: Vector3 = motor.input.direction
	if way == Vector3.ZERO:
		way = -body.global_basis.z  # Standing still: dash forward.
	_direction = way.slide(Vector3.UP).normalized()
	_time_left = duration
	_cooldown_left = cooldown


func _tick(delta: float) -> void:
	body.velocity = _direction * speed
	_time_left -= delta
	if _time_left <= 0.0:
		finish()
