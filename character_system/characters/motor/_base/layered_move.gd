@tool
@icon("res://character_system/icons/layered_move.svg")
class_name LayeredMove
extends Component
## Extra movement for a while, on top of the current [MovementMode]: a dash, a jump pad, a
## grapple pull.
##
## Each frame the [CharacterMotor] runs the mode first, then asks every idle move whether it
## [method _wants_to_start], usually by using up a request the mode left. Once started, its
## [method _tick] runs every frame, after the mode's, so it can add to the velocity or replace
## it, until it calls [method finish]. Several can run at once.
##
## Like modes, use these hooks rather than [method Component._start] and
## [method Component._stop]; if you do override those, call [code]super()[/code].

## Moves with a higher priority are asked first, so they win a request two moves want.
@export var priority: int = 0

## True while the move is running.
var active := false

## The motor running this move. Set when it starts.
var motor: CharacterMotor
## The body being moved. Set when it starts.
var body: CharacterBody3D


## Ends the move. Call it from [method _tick] when it's done.
func finish() -> void:
	if active:
		active = false
		_deactivate()


## Asked every frame while idle: return true to start, e.g.
## [code]return motor.input.consume(&"dash")[/code].
func _wants_to_start() -> bool:
	return false


## Called when the move starts.
func _activate() -> void:
	pass


## Called when the move ends, from [method finish] or because the move was removed.
func _deactivate() -> void:
	pass


## Changes [code]body.velocity[/code] each frame while active, after the mode has set it.
func _tick(_delta: float) -> void:
	pass


func _requires() -> Array[Script]:
	return [CharacterMotor]


func _start() -> void:
	motor = find(CharacterMotor) as CharacterMotor
	body = host as CharacterBody3D
	motor.add_move(self)


func _stop() -> void:
	finish()
	motor.remove_move(self)
