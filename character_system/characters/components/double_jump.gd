@tool
@icon("res://character_system/icons/double_jump.svg")
class_name DoubleJump
extends Component
## Lets the character jump again while in the air.
##
## Pressing [code]jump[/code] in the air jumps as high as a jump from the floor (the
## [code]jump_velocity[/code] stat). The air jumps come back on landing. How many there are is the
## [code]air_jumps[/code] stat, so statuses and items can change it: add 1 for a triple jump, or
## multiply by 0 to take it away while rooted or slowed.
##
## To grant it with an item instead of on the character, give the item's status a
## [StatModifier] on [code]air_jumps[/code] and leave [member air_jumps] at 0 here.

## Jumps allowed before landing again. Statuses change it through the air_jumps stat.
@export var air_jumps: int = 1:
	set(value):
		air_jumps = value
		update_stats()

var _air_jumps_left: int = 0


func _physics_process(_delta: float) -> void:
	var body := host as CharacterBody3D
	var movement := find(Movement) as Movement
	if body.is_on_floor():
		_air_jumps_left = int(stat(&"air_jumps"))
	elif (
			(find(Brain) as Brain).is_action_just_pressed(&"jump")
			and not movement.jumped_this_frame() and _air_jumps_left > 0
	):
		_air_jumps_left -= 1
		body.velocity.y = stat(&"jump_velocity")


func _requires() -> Array[Script]:
	return [Brain, Movement]


func _stats() -> Dictionary[StringName, float]:
	return { &"air_jumps": air_jumps }


func _warnings() -> PackedStringArray:
	if host is CharacterBody3D:
		return PackedStringArray()
	return PackedStringArray(["DoubleJump only works on a CharacterBody3D."])


## Air jumps left before the character lands. For a HUD, or AI deciding whether to jump.
func air_jumps_left() -> int:
	return _air_jumps_left
