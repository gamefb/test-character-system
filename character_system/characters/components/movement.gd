@tool
@icon("res://character_system/icons/movement.svg")
class_name Movement
extends Component
## Walks a [CharacterBody3D] host where its [Brain] wants to go.
##
## Jumps on the [code]jump[/code] action. Speed and jump height are the [code]move_speed[/code]
## and [code]jump_velocity[/code] stats, so statuses can change them. Effects shove it with
## [method push], e.g. knockback or a dash.

## Metres per second. Statuses change it through the move_speed stat.
@export var move_speed: float = 5.0:
	set(value):
		move_speed = value
		update_stats()
## Upward speed when jumping. Statuses change it through the jump_velocity stat.
@export var jump_velocity: float = 4.5:
	set(value):
		jump_velocity = value
		update_stats()
## How quickly pushes fade out. Higher = shorter slides.
@export var push_damping: float = 6.0

var _push := Vector3.ZERO
# Physics frame of the last jump from the floor.
var _jumped_on: int = -1


func _physics_process(delta: float) -> void:
	var body := host as CharacterBody3D
	var brain := find(Brain) as Brain
	var walk: Vector3 = brain.move_dir * stat(&"move_speed") + _push
	body.velocity = Vector3(walk.x, body.velocity.y, walk.z) + body.get_gravity() * delta
	if brain.is_action_just_pressed(&"jump") and body.is_on_floor():
		body.velocity.y = stat(&"jump_velocity")
		_jumped_on = Engine.get_physics_frames()
	body.move_and_slide()
	_push *= maxf(1.0 - push_damping * delta, 0.0)


func _requires() -> Array[Script]:
	return [Brain]


func _stats() -> Dictionary[StringName, float]:
	return { &"move_speed": move_speed, &"jump_velocity": jump_velocity }


func _warnings() -> PackedStringArray:
	if host is CharacterBody3D:
		return PackedStringArray()
	return PackedStringArray(["Movement only works on a CharacterBody3D."])


## True during the physics frame the character jumped from the floor. [DoubleJump] uses it so
## the press that starts a jump doesn't also use up an air jump.
func jumped_this_frame() -> bool:
	return _jumped_on == Engine.get_physics_frames()


## Shoves the character by [param velocity]. The sideways part fades out over time.
func push(velocity: Vector3) -> void:
	(host as CharacterBody3D).velocity.y += velocity.y
	_push += Vector3(velocity.x, 0.0, velocity.z)
