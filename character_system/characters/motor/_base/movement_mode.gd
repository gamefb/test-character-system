@tool
@icon("res://character_system/icons/movement_mode.svg")
class_name MovementMode
extends Component
## One way of moving, such as walking, falling, swimming or climbing. The [CharacterMotor] runs
## one mode at a time, its [member CharacterMotor.mode].
##
## To make your own, extend it and override:
## [br]- [method _physics_update] to set [code]body.velocity[/code]. It's like
## [code]_physics_process()[/code], but only runs while this mode is in charge.
## [br]- [method _get_next_mode] to hand over to another mode, e.g. once the floor is gone.
## [br]- [method _enter] and [method _exit] for anything to set up or undo.
## [codeblock]
## class_name SwimMode
## extends MovementMode
##
## func _physics_update(_delta: float) -> void:
## 	body.velocity = motor.brain.move_dir * 2.0
## [/codeblock]
## Don't call [code]move_and_slide()[/code]: the motor does, once the mode and moves are done.
## If you override [method Component._start] or [method Component._stop], call
## [code]super()[/code].

## The motor running this mode. Set when the mode starts.
var motor: CharacterMotor
## The body being moved. Set when the mode starts.
var body: CharacterBody3D


func _requires() -> Array[Script]:
	return [CharacterMotor]


func _start() -> void:
	motor = find(CharacterMotor) as CharacterMotor
	body = host as CharacterBody3D


func _stop() -> void:
	if motor.mode == self:
		motor.mode = null  # The motor goes back to its start mode next frame.


## Called when this mode takes over.
func _enter() -> void:
	pass


## Called when another mode takes over, or when this one is removed.
func _exit() -> void:
	pass


## Called every physics frame while this mode is in charge, before the body moves.
func _physics_update(_delta: float) -> void:
	pass


## Called after the body moves. Return the mode to hand over to, or null to stay.
func _get_next_mode() -> MovementMode:
	return null
