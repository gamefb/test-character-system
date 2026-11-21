@tool
@icon("res://character_system/icons/trigger.svg")
class_name Trigger
extends ItemComponent
## Decides when the item fires, from the wielder's button presses and the fire rate.
##
## Each press of [member action] on the wielder's [Brain] fires once, and an automatic item
## keeps firing while it's held. If a [Magazine] is beside it, each shot
## takes a round. Delivery components such as [Hitscan] listen to [signal fired].

## Emitted each time the item activates. Delivery components ([Hitscan], ...) listen to this.
signal fired

## The input action that fires the item, as sent by the wielder's [Brain].
@export var action: StringName = &"primary"
## Activations per second.
@export var fire_rate: float = 5.0
## On: fire while held. Off: one shot per press.
@export var automatic := false
## Seconds a press is remembered during cooldown, so fast clicks aren't lost.
@export var buffer_time: float = 0.15

var _buffered: float = 0.0
var _cooldown: float = 0.0


func _process(delta: float) -> void:
	_cooldown -= delta
	_buffered -= delta
	var wielder_brain: Brain = brain
	if not wielder_brain:
		return
	if wielder_brain.is_action_just_pressed(action):
		# Remembered, so a press during the cooldown still fires.
		_buffered = buffer_time
	var held: bool = automatic and wielder_brain.is_action_pressed(action)
	var wants_to_fire: bool = held or _buffered > 0.0
	var magazine := find(Magazine) as Magazine
	if wants_to_fire and _cooldown <= 0.0 and (not magazine or magazine.take()):
		_cooldown = 1.0 / fire_rate
		_buffered = 0.0
		fired.emit()
