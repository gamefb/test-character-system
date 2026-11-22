@tool
class_name Stamina
extends Component
## An example component to copy: sprint while an action is held, using up stamina that comes
## back when you let go.
##
## It uses each part of a component once: [method Component._requires] waits for a [Brain]
## and a [CharacterMotor], [method Component._stats] gives statuses a [code]max_stamina[/code]
## stat to change, [code]_process()[/code] reads a held button, a [StatModifier] raises
## [code]move_speed[/code] while sprinting, and [method Component._stop] takes it off again.
## Add the action to the Input Map and to [member PlayerBrain.extra_actions].

## Emitted when stamina goes up or down, for a stamina bar.
signal changed(current: float, maximum: float)

## Stamina when full. Statuses change it through the max_stamina stat.
@export var max_stamina: float = 100.0:
	set(value):
		max_stamina = value
		update_stats()
## Held to sprint.
@export var action: StringName = &"sprint"
## Speed while sprinting, as a multiplier of move_speed.
@export var sprint_speed: float = 1.5
## Stamina used per second of sprinting.
@export var drain: float = 25.0
## Stamina regained per second while not sprinting.
@export var regen: float = 15.0

## Stamina right now.
var current: float = 0.0

var _boost := StatModifier.new()  # Added to the manager only while sprinting.
var _sprinting := false


func _process(delta: float) -> void:
	var held: bool = (find(Brain) as Brain).is_action_pressed(action)
	_set_sprinting(held and current > 0.0)
	var maximum: float = stat(&"max_stamina")
	var before: float = current
	if _sprinting:
		current = maxf(current - drain * delta, 0.0)
	else:
		current = minf(current + regen * delta, maximum)
	if current != before:
		changed.emit(current, maximum)


func _requires() -> Array[Script]:
	return [Brain, CharacterMotor]


func _stats() -> Dictionary[StringName, float]:
	return { &"max_stamina": max_stamina }


func _start() -> void:
	_boost.stat = &"move_speed"
	current = stat(&"max_stamina")


func _stop() -> void:
	_set_sprinting(false)  # Never leave the speed boost behind.


func _set_sprinting(on: bool) -> void:
	if on == _sprinting:
		return
	_sprinting = on
	if on:
		_boost.mul = sprint_speed
		manager.add_modifier(_boost)
	else:
		manager.remove_modifier(_boost)
