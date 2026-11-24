@tool
class_name Sprint
extends Component
## Example: hold a button to run faster for as long as a [Pool] has something left.
##
## The stamina itself is an ordinary Pool named [code]stamina[/code], added beside this
## component: give it a Regen, and a Regen Delay so it waits a moment before refilling. This
## script only spends from it, which is all a component of your own has to do to use a
## resource. Copy it for anything that drains a pool while a button is held: a jetpack, a
## shield raised, a focus mode.

## The action that sprints while held. Add it to the Input Map, and to the PlayerBrain's Extra
## Actions.
@export var action: StringName = &"sprint"
## The pool sprinting spends from.
@export var pool: StringName = &"stamina"
## How much of the pool a second of sprinting costs.
@export var drain: float = 25.0
## How much faster sprinting is: 1.5 is half as fast again.
@export var sprint_speed: float = 1.5

var _boost := StatModifier.new()  # Added to the manager only while sprinting.
var _sprinting := false


func _process(delta: float) -> void:
	var tank := Pool.named(host, pool)
	var held: bool = (find(Brain) as Brain).is_action_pressed(action)
	_set_sprinting(held and tank != null and tank.current > 0.0)
	if _sprinting:
		tank.change(-drain * delta)


func _requires() -> Array[Script]:
	return [Brain, CharacterMotor]


func _start() -> void:
	_boost.stat = &"move_speed"
	_boost.mul = sprint_speed


func _stop() -> void:
	_set_sprinting(false)


func _warnings() -> PackedStringArray:
	if not get_parent().get_children().any(
			func(node: Node) -> bool: return node is Pool and node.pool == pool):
		return PackedStringArray(["Add a Pool named '%s' beside this." % pool])
	return PackedStringArray()


func _set_sprinting(on: bool) -> void:
	if on == _sprinting:
		return
	_sprinting = on
	if on:
		manager.add_modifier(_boost, self)
	else:
		manager.remove_modifier(_boost)
