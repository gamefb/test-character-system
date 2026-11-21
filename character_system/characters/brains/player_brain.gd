@tool
@icon("res://character_system/icons/player_brain.svg")
class_name PlayerBrain
extends Brain
## Turns keyboard, mouse and gamepad input into intent.
##
## Needs the input actions [code]left[/code], [code]right[/code], [code]forward[/code] and
## [code]back[/code] (Project Settings > Input Map). The actions in [constant ACTIONS] are passed
## on if the Input Map has them; missing ones are listed once as a warning.
##
## Presses come from input events in [code]_unhandled_input()[/code], so a click the UI uses
## doesn't reach the character. Releases are polled every frame, so a button let go while the
## game was paused, over the UI or in another window doesn't stay held.

## Input actions passed on to [method Brain.is_action_pressed]. Add your own here.
const ACTIONS: Array[StringName] = [
	&"primary",
	&"secondary",
	&"jump",
	&"reload",
	&"interact",
	&"next_weapon",
	&"previous_weapon",
]

## Movement is relative to this camera, and the character aims where it looks. Leave it empty
## to use the first [Camera3D] under the character.
@export var camera: Camera3D:
	set(value):
		camera = value
		update_configuration_warnings()

var _actions: Array[StringName] = []  # The ACTIONS the Input Map has.


func _process(_delta: float) -> void:
	var input: Vector2 = Input.get_vector(&"left", &"right", &"forward", &"back")
	var dir: Vector3 = camera.global_basis * Vector3(input.x, 0.0, input.y)
	move_dir = dir.slide(Vector3.UP).normalized() * input.length()
	aim_point = camera.global_position - camera.global_basis.z * 100.0
	for a in _actions:
		if is_action_pressed(a) and not Input.is_action_pressed(a):
			release(a)


func _unhandled_input(event: InputEvent) -> void:
	for a in _actions:
		if event.is_action_pressed(a):
			# Events arrive before this frame's processing, so it counts now, as in Input.
			_press(a, Engine.get_process_frames())


func _warnings() -> PackedStringArray:
	var out: PackedStringArray = super()
	if not camera and not find_node_of_type(&"Camera3D"):
		out.append("Add a Camera3D to the character, or set the Camera.")
	return out


func _start() -> void:
	if not camera:
		camera = find_node_of_type(&"Camera3D")
	var moves: Array[StringName] = [&"left", &"right", &"forward", &"back"]
	var missing: Array = moves.filter(
			func(a: StringName) -> bool: return not InputMap.has_action(a))
	if not missing.is_empty():
		push_error("PlayerBrain needs these input actions (Project Settings > Input Map): %s"
				% ", ".join(missing))
	_actions = ACTIONS.filter(InputMap.has_action)
	var unused: Array = ACTIONS.filter(func(a: StringName) -> bool: return a not in _actions)
	if not unused.is_empty():
		push_warning("PlayerBrain: add these to the Input Map to use them: %s" % ", ".join(unused))
