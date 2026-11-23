@tool
@icon("res://character_system/icons/movement_mode.svg")
@abstract
class_name MovementMode
extends MotorNode
## One way of moving, such as walking, falling, swimming or climbing. Add modes as children of a
## [CharacterMotor], which runs one at a time: its [member CharacterMotor.mode].
##
## To make your own, extend it and override:
## [br]- [method MotorNode._physics_update] to set [code]body.velocity[/code]. It's like
## [code]_physics_process()[/code], but only runs while this mode is in charge.
## [br]- [method _get_next_mode] to hand over to another mode, e.g. once the floor is gone.
## [br]- [method _can_enter] to take over by itself, e.g. once the character is in water. Then
## the other modes don't need to know this one exists.
## [br]- [method MotorNode._enter] and [method MotorNode._exit] for anything to set up or undo.
## [codeblock]
## class_name SwimMode
## extends MovementMode
##
## func _physics_update(_delta: float) -> void:
## 	body.velocity = motor.brain.move_dir * 2.0
## [/codeblock]


## Asked after the body moves, while another mode is in charge and isn't handing over. Return
## true to take over, e.g. [code]return body.is_on_wall_only()[/code].
func _can_enter() -> bool:
	return false


## Called after the body moves while this mode is in charge. Return the mode to hand over to,
## or null to stay.
func _get_next_mode() -> MovementMode:
	return null
