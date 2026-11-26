@tool
class_name Scope
extends ItemComponent
## An example item component to copy: while the aim action is held, the wielder zooms in and
## walks slower.
##
## It shows how an item changes the character holding it. The zoom uses the camera of the
## wielder's [PlayerBrain], so an AI wielder only slows down. The slowdown is a [StatModifier]
## held on the wielder with [method Component.hold_modifier], which takes it off again on
## unequip. The zoom is this script's own change, so [method Component._stop] undoes it.

## Held to aim, as sent by the wielder's [Brain].
@export var action: StringName = &"secondary"
## Field of view while aiming, in degrees.
@export var zoom_fov: float = 40.0
## Walking speed while aiming, as a multiplier of move_speed.
@export var aim_speed: float = 0.5

var _slow := StatModifier.new()  # Held on the wielder only while aiming.
var _aiming := false
var _camera: Camera3D
var _normal_fov: float = 75.0


func _process(_delta: float) -> void:
	var wielder_brain: Brain = brain
	_set_aiming(wielder_brain != null and wielder_brain.is_action_pressed(action))


func _start() -> void:
	_slow.stat = &"move_speed"
	var player := brain as PlayerBrain
	_camera = player.camera if player else null


func _stop() -> void:
	_set_aiming(false)


func _set_aiming(on: bool) -> void:
	if on == _aiming:
		return
	_aiming = on
	_slow.mul = aim_speed
	hold_modifier(_slow, on)
	if _camera:
		if on:
			_normal_fov = _camera.fov
		_camera.fov = zoom_fov if on else _normal_fov
