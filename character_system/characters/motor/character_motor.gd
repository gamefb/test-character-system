@tool
@icon("res://character_system/icons/character_motor.svg")
class_name CharacterMotor
extends Component
## Moves a [CharacterBody3D] with one [MovementMode] at a time, plus any [LayeredMove]s.
##
## Add it to a character that has a [Brain], then add modes and moves beside it, such as a
## [WalkMode], an [AirMode] and a [DashMove]. The motor is the only node that calls
## [method CharacterBody3D.move_and_slide]. Each physics frame:
## [br]1. The current [member mode] sets the body's velocity, e.g. walking.
## [br]2. Each [LayeredMove] may start, then changes the velocity while it runs, e.g. a dash.
## [br]3. The body moves, and the mode may hand over to another, e.g. walking to the air once
## the floor is gone.
## [br][br]Modes and moves read the [member brain], and use [method consume_action] for
## presses, so only one of them acts on each press. To change which key does what, edit the
## Input Map.

## Emitted when [member mode] changes, e.g. to play a landing animation.
signal mode_changed(old_mode: MovementMode, new_mode: MovementMode)

## Walking speed, through the move_speed stat so statuses can change it.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s") var move_speed := 5.0:
	set(value):
		move_speed = value
		update_stats()
## Upward speed of a jump, through the jump_velocity stat.
@export_range(0.0, 20.0, 0.1, "or_greater", "suffix:m/s") var jump_velocity := 4.5:
	set(value):
		jump_velocity = value
		update_stats()
## The mode to start in, and to go back to if the current one is removed. Left empty, it's the
## [WalkMode].
@export var start_mode: MovementMode
## How quickly the sideways part of a [method push] wears off.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var push_friction := 20.0

## The mode in charge. Set it to switch modes from code, e.g. [code]motor.mode = climb[/code]
## when a ladder is grabbed; a mode that isn't running is ignored. Check it with [code]is[/code],
## e.g. [code]if motor.mode is AirMode:[/code]
var mode: MovementMode:
	set(value):
		if value == mode or (value and not value.running):
			return
		var old_mode := mode
		if old_mode:
			old_mode._exit()
		mode = value
		if value:
			value._enter()
		mode_changed.emit(old_mode, value)
## The [Brain] giving orders. Read [member Brain.move_dir] and held actions from it.
var brain: Brain

var _body: CharacterBody3D
var _moves: Array[LayeredMove] = []
var _consumed: Dictionary[StringName, bool] = {}  # Presses already used this frame.
var _push := Vector3.ZERO  # Sideways knockback, kept in the body's velocity between frames.


func _physics_process(delta: float) -> void:
	_consumed.clear()
	if not mode:
		mode = start_mode if start_mode else find(WalkMode) as MovementMode
		if not mode:
			return
	_body.velocity -= _push  # Modes work from the character's own velocity.
	mode._physics_update(delta)
	for move in _moves:
		if not move.active and move._can_start():
			move.active = true
		if move.active:
			move._physics_update(delta)
	_push = _push.move_toward(Vector3.ZERO, push_friction * delta)
	_body.velocity += _push
	_body.move_and_slide()
	var next := mode._get_next_mode()
	if next:
		mode = next


func _requires() -> Array[Script]:
	return [Brain]


func _stats() -> Dictionary[StringName, float]:
	return { &"move_speed": move_speed, &"jump_velocity": jump_velocity }


func _start() -> void:
	brain = find(Brain) as Brain
	_body = host as CharacterBody3D


func _stop() -> void:
	mode = null
	_moves.clear()


func _warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not host is CharacterBody3D:
		warnings.append("CharacterMotor only works on a CharacterBody3D.")
	if not start_mode and not host.get_children().any(func(c: Node) -> bool: return c is WalkMode):
		warnings.append("Add a WalkMode, or set Start Mode.")
	return warnings


## True if [param action] was just pressed and no other mode or move has used it this frame.
## Use it for presses only one thing should act on, such as jump.
func consume_action(action: StringName) -> bool:
	if _consumed.has(action) or not brain.is_action_just_pressed(action):
		return false
	_consumed[action] = true
	return true


## Shoves the character, e.g. from a [KnockbackEffect]. The sideways part wears off over time.
func push(velocity: Vector3) -> void:
	if not running:
		return
	_body.velocity += velocity
	_push += Vector3(velocity.x, 0.0, velocity.z)


## Called by a [LayeredMove] when it starts. You don't need to call it yourself.
func add_move(move: LayeredMove) -> void:
	_moves.append(move)


## Called by a [LayeredMove] when it stops.
func remove_move(move: LayeredMove) -> void:
	_moves.erase(move)
