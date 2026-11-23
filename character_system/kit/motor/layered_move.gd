@tool
@icon("res://character_system/icons/layered_move.svg")
@abstract
class_name LayeredMove
extends MotorNode
## Extra movement for a while, on top of the current [MovementMode]: a dash, a jump pad, a
## grapple pull. Add moves as children of a [CharacterMotor]; several can run at once.
##
## Each physics frame, after the mode, the motor asks every idle move [method _can_start],
## usually by using up a press with [method CharacterMotor.consume_action]. It doesn't ask
## while the move is on [member cooldown] or blocked by a status, so the press is left for
## something else. While
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

## Time from the start of one run until the next may start, in game time like an ability's
## cooldown. 0 for none.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var cooldown := 0.0

## True while the move runs. Set it from code to start or end the move, e.g. from a jump pad.
## It won't start while [method cooldown_left] is above 0.
var active := false:
	set(value):
		if value == active or (value and cooldown_left() > 0.0):
			return
		active = value
		if active:
			if cooldown > 0.0 and is_inside_tree():
				_cooldown = get_tree().create_timer(cooldown, false, true)
			_enter()
			started.emit()
		else:
			_exit()
			finished.emit()
		if motor and motor.running:
			ComponentManager.notify(body, event_prefix + ("_started" if active else "_finished"))

var _cooldown: SceneTreeTimer


## Seconds until the move may start again, e.g. for a HUD. 0 when it's ready.
func cooldown_left() -> float:
	return _cooldown.time_left if _cooldown else 0.0


## Asked every physics frame while idle. Return true to start, e.g.
## [code]return motor.consume_action(&"dash")[/code].
func _can_start() -> bool:
	return false
