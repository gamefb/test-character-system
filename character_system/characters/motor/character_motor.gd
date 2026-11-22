@tool
@icon("res://character_system/icons/character_motor.svg")
class_name CharacterMotor
extends Component
## Moves a [CharacterBody3D] through one [MovementMode] at a time, plus any [LayeredMove]s.
##
## It's the only node that sets the body's velocity and calls [code]move_and_slide()[/code].
## Each physics frame:
## [br]1. It reads the [Brain] into [member input], a [MoveInput]. Modes and moves only see that.
## [br]2. The current [member mode] sets the velocity, e.g. walking or falling, and may use a
## request such as [code]jump[/code].
## [br]3. A layered move may start on a request the mode didn't use, then changes the velocity
## while it runs, e.g. a dash.
## [br]4. The body moves, and the mode says whether to hand over to another, e.g. walk to air
## once the floor is gone.
##
## Only the current mode sees a request, and a used press is gone, so two features can't both
## act on one press. Modes and moves are components beside the motor: add or remove them during
## play and it picks them up.

## Emitted when [member mode] changes, e.g. to play a landing animation.
signal mode_changed(from: StringName, to: StringName)

## Walking speed, in metres per second. Statuses change it through the move_speed stat.
@export var move_speed: float = 5.0:
	set(value):
		move_speed = value
		update_stats()
## Upward speed of a jump, in metres per second, through the jump_velocity stat.
@export var jump_velocity: float = 4.5:
	set(value):
		jump_velocity = value
		update_stats()
## The mode to start in, and to fall back to if the current mode is removed.
@export var start_mode: StringName = &"walk"
## Which input action sends each movement request. Change it to remap the controls: modes and
## moves only know the request names.
@export var requests: Dictionary[StringName, StringName] = { &"jump": &"jump", &"dash": &"dash" }
## How quickly a knockback's sideways push fades, per second.
@export var push_damping: float = 6.0

## The mode in charge right now, or null if none has been added yet.
var mode: MovementMode
## This frame's input. Modes and moves read it, and use up presses with [method MoveInput.consume].
var input := MoveInput.new()

var _brain: Brain
var _body: CharacterBody3D
var _modes: Dictionary[StringName, MovementMode] = {}
var _moves: Array[LayeredMove] = []
var _push := Vector3.ZERO  # Sideways knockback still to be applied.
var _pushed := Vector3.ZERO  # The part of the velocity that is last frame's push.


func _physics_process(delta: float) -> void:
	_read_input()
	if not mode:
		return
	var body := _body
	body.velocity -= _pushed  # Modes work from the character's own velocity.
	mode._tick(delta)
	for move in _moves:
		if not move.active and move._wants_to_start():
			move.active = true
			move._activate()
	for move in _moves:
		if move.active:
			move._tick(delta)
	_pushed = Vector3(_push.x, 0.0, _push.z)
	body.velocity += _pushed
	body.move_and_slide()
	_push *= maxf(1.0 - push_damping * delta, 0.0)
	switch_to(mode._next_mode())


## Hands over to the mode named [param mode_name]. Returns false if there's no such mode. Modes
## call this through [method MovementMode._next_mode]; call it yourself for things such as a
## ladder that starts climbing.
func switch_to(mode_name: StringName) -> bool:
	if mode_name == &"" or not _modes.has(mode_name):
		return false
	var next: MovementMode = _modes[mode_name]
	if next == mode:
		return true
	var from: StringName = mode.mode_name if mode else &""
	if mode:
		mode._exit()
	mode = next
	mode._enter()
	mode_changed.emit(from, mode_name)
	return true


## Shoves the character, e.g. from a [KnockbackEffect]. The upward part applies at once; the
## sideways part fades over time.
func push(velocity: Vector3) -> void:
	_body.velocity.y += velocity.y
	_push += Vector3(velocity.x, 0.0, velocity.z)


## Called by a [MovementMode] when it starts. You don't need to call it yourself.
func add_mode(m: MovementMode) -> void:
	_modes[m.mode_name] = m
	if not mode and m.mode_name == start_mode:
		switch_to(start_mode)


## Called by a [MovementMode] when it stops.
func remove_mode(m: MovementMode) -> void:
	if _modes.get(m.mode_name) == m:
		_modes.erase(m.mode_name)
	if mode == m:
		m._exit()
		mode = null
		if not switch_to(start_mode) and not _modes.is_empty():
			switch_to(_modes.keys()[0])


## Called by a [LayeredMove] when it starts. Higher priorities go first.
func add_move(move: LayeredMove) -> void:
	_moves.append(move)
	_moves.sort_custom(func(a: LayeredMove, b: LayeredMove) -> bool: return a.priority > b.priority)


## Called by a [LayeredMove] when it stops.
func remove_move(move: LayeredMove) -> void:
	_moves.erase(move)


func _read_input() -> void:
	input.clear()
	input.direction = _brain.move_dir
	for request in requests:
		var action: StringName = requests[request]
		input.set_request(request, _brain.is_action_just_pressed(action),
				_brain.is_action_pressed(action))


func _requires() -> Array[Script]:
	return [Brain]


func _stats() -> Dictionary[StringName, float]:
	return { &"move_speed": move_speed, &"jump_velocity": jump_velocity }


func _start() -> void:
	_brain = find(Brain) as Brain
	_body = host as CharacterBody3D


func _stop() -> void:
	mode = null
	_modes.clear()
	_moves.clear()


func _warnings() -> PackedStringArray:
	var out := PackedStringArray()
	if not host is CharacterBody3D:
		out.append("CharacterMotor only works on a CharacterBody3D.")
	var has_start := false
	for child in host.get_children():
		if child is MovementMode and child.mode_name == start_mode:
			has_start = true
	if not has_start:
		out.append("Add a mode named \"%s\", e.g. a WalkMode." % start_mode)
	return out
