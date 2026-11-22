class_name MoveInput
extends RefCounted
## What a character wants to do this physics frame, as movement sees it.
##
## [CharacterMotor] fills one in from the [Brain] every physics frame, so modes and moves never
## read buttons or input actions. A request is a movement verb, such as [code]&"jump"[/code] or
## [code]&"dash"[/code]; [member CharacterMotor.requests] says which input action sends each one.

## Where to move: flat, in world space, at most 1 long.
var direction := Vector3.ZERO

var _pressed: Dictionary[StringName, bool] = {}  # Pressed this frame and not used yet.
var _held: Dictionary[StringName, bool] = {}


## True if [param request] was pressed this frame and nothing has used it yet. It uses the press
## up, so only one mode or move acts on each press.
func consume(request: StringName) -> bool:
	return _pressed.erase(request)


## True while [param request]'s button is held, e.g. to glide.
func is_held(request: StringName) -> bool:
	return _held.has(request)


## Sets one request for this frame. The motor calls it; tests and cutscenes can too.
func set_request(request: StringName, pressed: bool, held: bool) -> void:
	if pressed:
		_pressed[request] = true
	if held:
		_held[request] = true


## Forgets every request, ready for the next frame.
func clear() -> void:
	_pressed.clear()
	_held.clear()
