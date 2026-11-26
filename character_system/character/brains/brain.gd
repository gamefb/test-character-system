@tool
@icon("res://character_system/icons/brain.svg")
class_name Brain
extends Component
## A character's intent: where to move, where to aim, and which buttons are pressed.
##
## [PlayerBrain] fills it in from input and [AIBrain] from navigation. A plain [Brain] can be
## driven by your own script, such as a turret's targeting logic. Other components, such as
## [CharacterMotor], [Trigger] and [WeaponSwitch], read intent from here and never ask where it came
## from. Use one brain per character.
##
## Read its buttons the way Godot's input docs read the [Input] singleton, polling in
## [code]_process()[/code] or [code]_physics_process()[/code]:
## [codeblock]
## func _physics_process(delta: float) -> void:
## 	if brain.is_action_just_pressed(&"jump"):
## 		jump()
## 	if brain.is_action_pressed(&"primary"):
## 		keep_firing()
## [/codeblock]
## A brain presses buttons with [method press] and [method release]. A press counts from the
## next frame, so every node sees it exactly once, wherever in the frame it was made.
##
## To drive a plain Brain yourself, set [member move_dir] and [member aim_point] and tap buttons
## from your own component, e.g. a turret that aims at the nearest enemy:
## [codeblock]
## var brain := find(Brain) as Brain
## brain.aim_point = enemy.global_position
## brain.press(&"primary")  # A tap: press and release in the same frame.
## brain.release(&"primary")
## [/codeblock]
##
## [b]Stuns and death.[/b] The brain knows about neither. While a status that
## [member StatusData.blocks] one of [member blocked_by] is active, it reports no intent:
## [member move_dir] is zero and no action counts as pressed. Everything that reads the brain
## stops with it, so a status that blocks [code]everything[/code], as Stunned and Dead do,
## stops walking, jumping, shooting, switching weapons and abilities without any of them
## knowing why. A status that should stop one thing only blocks [code]movement[/code],
## [code]weapons[/code] or [code]abilities[/code] instead.

## The names this brain answers to. A status that blocks one of them stops the character from
## acting at all. Empty: nothing stops it, e.g. for a turret that statuses shouldn't touch.
@export var blocked_by: Array[StringName] = [&"everything"]

var move_dir: Vector3:
	get:
		return Vector3.ZERO if is_blocked() else _move_dir
	set(value):
		_move_dir = value
## World-space point the character is aiming at.
var aim_point := Vector3.ZERO

var _move_dir := Vector3.ZERO

# Action -> (physics frame, process frame) on which it counts as just pressed. Pressed actions
# are in _held; a tap may already be released while still just pressed.
var _pressed_on: Dictionary[StringName, Vector2i] = {}
var _held: Dictionary[StringName, bool] = {}


## The [Brain] of [param node]'s character, or null if there is none.
static func find_on(node: Node) -> Brain:
	return Component.of(node, Brain) as Brain


func _init() -> void:
	# A brain decides before anything acts on what it decided, wherever the two sit in the
	# tree. A weapon in a hand under the camera would otherwise fire at last frame's aim point.
	process_priority = -1
	process_physics_priority = -1


func _warnings() -> PackedStringArray:
	var brains: Array = host.get_children().filter(func(node: Node) -> bool: return node is Brain)
	if brains.size() > 1:
		return PackedStringArray(["Use one Brain per character. Only the first one is used."])
	return PackedStringArray()


## Presses [param action], like [method Input.action_press]. Pressing a held action does nothing.
func press(action: StringName) -> void:
	# Next frame: nodes that already ran this frame would miss it otherwise.
	_press(action, Engine.get_process_frames() + 1)


## Releases [param action], like [method Input.action_release].
func release(action: StringName) -> void:
	_held.erase(action)


## True while the character can't act: a status is blocking one of [member blocked_by].
## Presses made meanwhile are lost; a button still held when it ends counts as held again.
func is_blocked() -> bool:
	# Asked many times a frame: nearly always nothing at all is blocked, which is one look.
	return (
			manager != null and not manager.blocks.is_empty()
			and manager.is_blocked(blocked_by)
	)


## True while [param action] is held down, like [method Input.is_action_pressed].
func is_action_pressed(action: StringName) -> bool:
	return _held.has(action) and not is_blocked()


## True during the frame [param action] was pressed, like [method Input.is_action_just_pressed].
## Works in both [code]_process()[/code] and [code]_physics_process()[/code], and a tap counts
## even if it was released in the same frame.
func is_action_just_pressed(action: StringName) -> bool:
	if is_blocked():
		return false
	var frames: Vector2i = _pressed_on.get(action, -Vector2i.ONE)
	if Engine.is_in_physics_frame():
		return frames.x == Engine.get_physics_frames()
	return frames.y == Engine.get_process_frames()


# Like Godot's Input: the next physics frame, and the given process frame.
func _press(action: StringName, process_frame: int) -> void:
	if not _held.has(action):
		_held[action] = true
		_pressed_on[action] = Vector2i(Engine.get_physics_frames() + 1, process_frame)
