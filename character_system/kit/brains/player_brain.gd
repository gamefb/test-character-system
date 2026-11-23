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
##
## [b]Aiming.[/b] [member Brain.aim_point] is the point the middle of the screen is on: the
## first thing a ray from the [member camera] meets. Weapons shoot from themselves toward that
## point, so a gun held at the hip still hits what the crosshair is on, at any range.

## Input actions passed on to [method Brain.is_action_pressed]. Add your own to
## [member extra_actions] instead of changing this list.
const ACTIONS: Array[StringName] = [
	&"primary",
	&"secondary",
	&"jump",
	&"reload",
	&"interact",
	&"next_weapon",
	&"previous_weapon",
]
## How far the player can aim, in metres. With nothing in the way, the aim point is this far
## along the camera's line of sight.
const AIM_DISTANCE := 100.0
## The aim point is never closer than this, so a shot at a wall right in front of the
## character leaves the weapon forwards, not back toward a point behind its muzzle.
const MIN_AIM_DISTANCE := 1.5

## Movement is relative to this camera, and the character aims where it looks. Leave it empty
## to use the first [Camera3D] under the character.
@export var camera: Camera3D:
	set(value):
		camera = value
		update_configuration_warnings()
## Your own input actions to pass on as well, e.g. &"sprint" or &"ability_1". Add each one to
## the Input Map too.
@export var extra_actions: Array[StringName] = []
## The physics layers the crosshair can rest on. Untick a layer to aim through it.
@export_flags_3d_physics var aim_mask: int = 0xffffffff

var _actions: Array[StringName] = []  # The actions passed on that the Input Map has.
var _own_rids: Array[RID] = []  # The character's body and hurtboxes, which the aim ignores.


func _process(_delta: float) -> void:
	var input: Vector2 = Input.get_vector(&"left", &"right", &"forward", &"back")
	var dir: Vector3 = camera.global_basis * Vector3(input.x, 0.0, input.y)
	move_dir = dir.slide(Vector3.UP).normalized() * input.length()
	aim_point = _point_under_crosshair()
	for a in _actions:
		# Read _held directly: a button let go while stunned must not stay held.
		if _held.has(a) and not Input.is_action_pressed(a):
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
	_own_rids = Hurtbox.rids_of(host)
	var moves: Array[StringName] = [&"left", &"right", &"forward", &"back"]
	var missing: Array = moves.filter(
			func(a: StringName) -> bool: return not InputMap.has_action(a))
	if not missing.is_empty():
		push_error("PlayerBrain needs these input actions (Project Settings > Input Map): %s"
				% ", ".join(missing))
	var wanted: Array[StringName] = ACTIONS.duplicate()
	wanted.append_array(extra_actions)
	_actions = wanted.filter(InputMap.has_action)
	var unused: Array = wanted.filter(func(a: StringName) -> bool: return a not in _actions)
	if not unused.is_empty():
		push_warning("PlayerBrain: add these to the Input Map to use them: %s" % ", ".join(unused))


# The first thing the middle of the screen is on, as far as AIM_DISTANCE.
func _point_under_crosshair() -> Vector3:
	var forward: Vector3 = -camera.global_basis.z
	var from: Vector3 = camera.global_position
	var body := host as Node3D
	if body:
		# Level with the character, so a camera behind it doesn't aim at what is in between.
		from += forward * maxf(forward.dot(body.global_position - from), 0.0)
	var far: Vector3 = from + forward * AIM_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, far, aim_mask, _own_rids)
	query.collide_with_areas = true  # Hurtboxes are areas.
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit:
		return far
	return from + forward * maxf(from.distance_to(hit.position), MIN_AIM_DISTANCE)
