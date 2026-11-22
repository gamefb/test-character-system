@tool
@icon("res://character_system/icons/layered_move.svg")
class_name LayeredMove
extends MotorNode
## Extra movement for a while, on top of the current [MovementMode]: a dash, a jump pad, a
## grapple pull. Add moves as children of a [CharacterMotor]; several can run at once.
##
## Each physics frame, after the mode, the motor asks every idle move [method _can_start],
## usually by using up a press with [method CharacterMotor.consume_action]. While
## [member active], its [method MotorNode._physics_update] changes [code]body.velocity[/code].
## Set [member active] to false when it's done.
## [codeblock]
## class_name JumpPadBoost
## extends LayeredMove
##
## func _physics_update(_delta: float) -> void:
## 	body.velocity.y = 12.0
## 	active = false  # One frame is enough.
## [/codeblock]
## A jump pad would set [code]boost.active = true[/code] when the character steps on it.

## Emitted when the move starts, e.g. to play a sound.
signal started
## Emitted when the move ends.
signal finished

## True while the move runs. Set it from code to start or end the move, e.g. from a jump pad.
var active := false:
	set(value):
		if value == active:
			return
		active = value
		if active:
			_enter()
			started.emit()
		else:
			_exit()
			finished.emit()


## Asked every physics frame while idle. Return true to start, e.g.
## [code]return motor.consume_action(&"dash")[/code].
func _can_start() -> bool:
	return false
