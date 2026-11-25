@tool
class_name WalkerBrain
extends Brain
## Test-scene brain: walks straight to a point when told to. Stands in for real AI
## decision logic, so the scene can move characters through zones on cue.

## Emitted when the character reaches the point given to [method walk_to].
signal arrived

var _destination := Vector3.ZERO
var _walking := false


func _physics_process(_delta: float) -> void:
	if not _walking:
		move_dir = Vector3.ZERO
		return
	var to_point: Vector3 = _destination - (host as Node3D).global_position
	to_point.y = 0.0
	if to_point.length() < 0.15:
		_walking = false
		move_dir = Vector3.ZERO
		arrived.emit()
	else:
		move_dir = to_point.normalized()


## Starts walking to [param point]. Height is ignored.
func walk_to(point: Vector3) -> void:
	_destination = point
	_walking = true
