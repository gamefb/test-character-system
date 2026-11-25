@tool
class_name MouseLook
extends Component
## Turns the character and tilts its camera with the mouse.
##
## Captures the mouse when the character starts. Esc frees it; clicking captures it again.

## Tilted up and down by the mouse. The host itself turns left and right. Leave it empty to use
## the first [Camera3D] under the character.
@export var camera: Camera3D:
	set(value):
		camera = value
		update_configuration_warnings()
## Radians per pixel of mouse movement.
@export var sensitivity: float = 0.003
## Capture the mouse as soon as the character starts.
@export var capture_on_start := true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif (
			event is InputEventMouseButton and event.pressed
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# So this click doesn't also fire a weapon.
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		(host as Node3D).rotate_y(-event.relative.x * sensitivity)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sensitivity, -1.4, 1.4)


func _warnings() -> PackedStringArray:
	if camera or find_node_of_type(&"Camera3D"):
		return PackedStringArray()
	return PackedStringArray(["Add a Camera3D to the character, or set the Camera."])


func _start() -> void:
	if not camera:
		camera = find_node_of_type(&"Camera3D")
	if capture_on_start:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
