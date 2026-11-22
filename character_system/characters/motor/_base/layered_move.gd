@tool
@icon("res://character_system/icons/layered_move.svg")
class_name LayeredMove
extends Component
## Extra movement for a while, on top of the current [MovementMode]: a dash, a jump pad, a
## grapple pull. Several can run at once.
##
## Each physics frame, after the mode, the [CharacterMotor] asks every idle move
## [method _can_start], usually by using up a press with [method CharacterMotor.consume_action].
## While [member active], its [method _physics_update] changes [code]body.velocity[/code]. Set
## [member active] to false when it's done.
## [br][br]If you override [method Component._start] or [method Component._stop], call
## [code]super()[/code].

## Emitted when the move starts, e.g. to play a sound.
signal started
## Emitted when the move ends.
signal finished

## True while the move runs. Set it from code to start or end the move, e.g. from a jump pad.
var active := false:
	set(value):
		if value == active or (value and not running):
			return
		active = value
		if active:
			_enter()
			started.emit()
		else:
			_exit()
			finished.emit()
## The motor running this move. Set when the move starts.
var motor: CharacterMotor
## The body being moved. Set when the move starts.
var body: CharacterBody3D


func _requires() -> Array[Script]:
	return [CharacterMotor]


func _start() -> void:
	motor = find(CharacterMotor) as CharacterMotor
	body = host as CharacterBody3D
	motor.add_move(self)


func _stop() -> void:
	active = false
	motor.remove_move(self)


## Asked every physics frame while idle. Return true to start, e.g.
## [code]return motor.consume_action(&"dash")[/code].
func _can_start() -> bool:
	return false


## Called when the move starts.
func _enter() -> void:
	pass


## Called when the move ends, or when it's removed while running.
func _exit() -> void:
	pass


## Called every physics frame while [member active], after the mode, before the body moves.
func _physics_update(_delta: float) -> void:
	pass
