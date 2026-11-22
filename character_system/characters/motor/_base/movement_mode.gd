@tool
@icon("res://character_system/icons/movement_mode.svg")
class_name MovementMode
extends Component
## One way of moving, such as walking, falling, swimming or climbing. The [CharacterMotor] runs
## exactly one at a time.
##
## Extend it and override:
## [br]- [method _tick] to set [code]body.velocity[/code] from [code]motor.input[/code],
## [br]- [method _next_mode] to say when to hand over, e.g. to &"air" once the floor is gone,
## [br]- [method _enter] and [method _exit] for anything to set up or undo when it takes over.
##
## Only the current mode's [method _tick] runs, so it can use a request such as
## [code]jump[/code] without knowing what the other modes do. Use these hooks rather than
## [method Component._start] and [method Component._stop], which add the mode to the motor; if
## you do override them, call [code]super()[/code].

## The name the motor and other modes use for it, e.g. &"walk".
@export var mode_name: StringName

## The motor running this mode. Set when it starts.
var motor: CharacterMotor
## The body being moved. Set when it starts.
var body: CharacterBody3D


## Called when the motor switches to this mode.
func _enter() -> void:
	pass


## Called when the motor switches away from this mode.
func _exit() -> void:
	pass


## Sets [code]body.velocity[/code] for this frame, before the body moves.
func _tick(_delta: float) -> void:
	pass


## The mode to switch to after this frame's move, or &"" to stay.
func _next_mode() -> StringName:
	return &""


func _requires() -> Array[Script]:
	return [CharacterMotor]


func _start() -> void:
	motor = find(CharacterMotor) as CharacterMotor
	body = host as CharacterBody3D
	motor.add_mode(self)


func _stop() -> void:
	motor.remove_mode(self)
