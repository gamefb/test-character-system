@tool
@icon("res://character_system/icons/dash_move.svg")
class_name DashMove
extends LayeredMove
## On [member action], shoots the character the way it's moving, or forward if it's standing
## still. While it runs it replaces the velocity, so there's no gravity and no steering.

## The [Brain] action that dashes.
@export var action := &"dash"
## Speed during the dash.
@export_range(0.0, 50.0, 0.1, "or_greater", "suffix:m/s") var speed := 15.0
## How long a dash lasts.
@export_range(0.0, 2.0, 0.01, "or_greater", "suffix:s") var duration := 0.2
## Time from the start of one dash until the next one is allowed.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var cooldown := 0.6

var _velocity := Vector3.ZERO
var _time_left := 0.0
var _cooldown_left := 0.0


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)


func _can_start() -> bool:
	return _cooldown_left <= 0.0 and motor.consume_action(action)


func _enter() -> void:
	var direction := motor.brain.move_dir
	if direction.is_zero_approx():
		direction = -body.global_basis.z
	_velocity = direction.normalized() * speed
	_time_left = duration
	_cooldown_left = cooldown


func _physics_update(delta: float) -> void:
	body.velocity = _velocity
	_time_left -= delta
	if _time_left <= 0.0:
		active = false
