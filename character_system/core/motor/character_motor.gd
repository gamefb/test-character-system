@tool
@icon("res://character_system/icons/character_motor.svg")
class_name CharacterMotor
extends Component
## Moves a [CharacterBody3D] with one [MovementMode] at a time, plus any [LayeredMove]s.
##
## Add it to a character that has a [Brain], with modes and moves as its children:
## [codeblock lang=text]
## Player (CharacterBody3D)
##  ├─ ComponentManager
##  ├─ PlayerBrain
##  └─ CharacterMotor
##      ├─ WalkMode
##      ├─ AirMode
##      └─ DashMove
## [/codeblock]
## The motor is the only node that calls [method CharacterBody3D.move_and_slide]. Each physics
## frame:
## [br]1. The current [member mode] sets the body's velocity, e.g. walking.
## [br]2. Each [LayeredMove], in scene order, may start, then changes the velocity while it
## runs, e.g. a dash.
## [br]3. The body moves, and the mode may hand over to another, e.g. walking to the air once
## the floor is gone. If it doesn't, any other mode may take over, e.g. a wall slide once the
## character falls against a wall.
## [br][br]Modes and moves read the [member brain], and use [method consume_action] for
## presses, so only one of them acts on each press. To change which key does what, edit the
## Input Map.
## [br][br]A mode or move whose [member MotorNode.blocked_by_tags] match a status can't take
## over or start. The motor also tells the character's components and statuses when a mode
## takes over or hands over, e.g. [code]walk_mode_entered[/code] on landing and
## [code]air_mode_entered[/code] on take-off, and when a move starts or finishes, e.g.
## [code]dash_move_started[/code]. The first mode it starts in sends no event.

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
## first movement mode under the motor.
@export var start_mode: MovementMode
## How quickly the sideways part of a [method push] wears off.
@export_range(0.0, 100.0, 0.1, "or_greater", "suffix:m/s²") var push_friction := 20.0

## The mode in charge. Set it to switch modes from code, e.g. [code]motor.mode = climb[/code]
## when a ladder is grabbed; a mode that isn't a child of this motor is ignored. Check it with
## [code]is[/code], e.g. [code]if motor.mode is AirMode:[/code]
var mode: MovementMode:
	set(value):
		if value == mode or (value and value.get_parent() != self):
			return
		var old_mode := mode
		if old_mode:
			old_mode._exit()
		mode = value
		if value:
			value._enter()
		mode_changed.emit(old_mode, value)
		if running and old_mode:
			ComponentManager.notify(host, old_mode.event_prefix + "_exited")
			if value:
				ComponentManager.notify(host, value.event_prefix + "_entered")
## The [Brain] giving orders. Read [member Brain.move_dir] and held actions from it.
var brain: Brain
## The character being moved.
var body: CharacterBody3D

var _modes: Array[MovementMode] = []
var _moves: Array[LayeredMove] = []
var _consumed: Dictionary[StringName, bool] = {}  # Presses already used this frame.
var _push := Vector3.ZERO  # Sideways knockback, kept in the body's velocity between frames.


func _physics_process(delta: float) -> void:
	_consumed.clear()
	if not mode or mode.is_blocked():
		mode = start_mode if start_mode else get_mode(MovementMode)
		if not mode:
			return
	body.velocity -= _push  # Modes work from the character's own velocity.
	mode._physics_update(delta)
	for move in _moves:
		if move.active and move.is_blocked():
			move.active = false
		elif not move.active and _may_start(move) and move._can_start():
			move.active = true
		if move.active:
			move._physics_update(delta)
	_push = _push.move_toward(Vector3.ZERO, push_friction * delta)
	body.velocity += _push
	body.move_and_slide()
	var next := mode._get_next_mode()
	if next and next.is_blocked():
		next = null
	if not next:
		for other in _modes:
			if other != mode and not other.is_blocked() and other._can_enter():
				next = other
				break
	if next:
		mode = next


func _notification(what: int) -> void:
	if what != NOTIFICATION_CHILD_ORDER_CHANGED:
		return
	for move in _moves:
		if move.get_parent() != self:
			move.active = false
	_modes.assign(get_children().filter(func(node: Node) -> bool: return node is MovementMode))
	_moves.assign(get_children().filter(func(node: Node) -> bool: return node is LayeredMove))
	if mode and mode.get_parent() != self:
		mode = null
	update_stats()
	update_configuration_warnings()


func _requires() -> Array[Script]:
	return [Brain]


func _stats() -> Dictionary[StringName, float]:
	var stats: Dictionary[StringName, float] = {
		&"move_speed": move_speed,
		&"jump_velocity": jump_velocity,
	}
	for node in get_children():
		if node is MotorNode:
			stats.merge(node._stats())
	return stats


func _start() -> void:
	brain = find(Brain) as Brain
	body = host as CharacterBody3D


func _stop() -> void:
	mode = null
	for move in _moves:
		move.active = false


func _warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not host is CharacterBody3D:
		warnings.append("CharacterMotor only works on a CharacterBody3D.")
	if not start_mode and not get_mode(MovementMode):
		warnings.append("Add a movement mode, such as a WalkMode, as a child.")
	return warnings


## True if [param action] was just pressed and no other mode or move has used it this frame.
## Use it for presses only one thing should act on, such as jump.
func consume_action(action: StringName) -> bool:
	if _consumed.has(action) or not brain.is_action_just_pressed(action):
		return false
	_consumed[action] = true
	return true


## The first child mode that is a [param type], or null, e.g.
## [code]motor.get_mode(AirMode)[/code].
func get_mode(type: Script) -> MovementMode:
	for node in get_children():
		if is_instance_of(node, type):
			return node as MovementMode
	return null


## Shoves the character, e.g. from a [KnockbackEffect]. The sideways part wears off over time.
func push(velocity: Vector3) -> void:
	if not running:
		return
	body.velocity += velocity
	_push += Vector3(velocity.x, 0.0, velocity.z)


func _may_start(move: LayeredMove) -> bool:
	return move.cooldown_left() <= 0.0 and not move.is_blocked()
