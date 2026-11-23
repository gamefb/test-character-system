@tool
@icon("res://character_system/icons/trigger.svg")
class_name Trigger
extends ItemComponent
## Decides when the item fires, from the wielder's button presses and the fire rate.
##
## Each press of [member action] on the wielder's [Brain] fires once, and an automatic item
## keeps firing while it's held. If a [Magazine] is beside it, each shot
## takes a round. Delivery components such as [Hitscan] and [MeleeSweep] listen to
## [signal fired], and [member user_effects] run on the wielder.
## [br][br]A stunned or dead wielder can't fire, because its [Brain] reports no presses. For a
## status that stops weapons only, such as Disarmed, use [member blocked_by_tags].

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
## While the wielder has a status with one of these tags, the item doesn't fire, e.g.
## &"disarmed".
@export var blocked_by_tags: Array[StringName] = []
## Run in order on the wielder each time the item fires, e.g. a [LaunchProjectileEffect] for a
## rocket launcher or a bow, a [KnockbackEffect] for recoil, or a cost paid from a [Pool].
@export var user_effects: Array[Effect] = []

var _buffered: float = 0.0
var _cooldown: float = 0.0


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(user_effects)


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
	if not wants_to_fire or _cooldown > 0.0 or Statuses.has_any_tag(wielder, blocked_by_tags):
		return
	var magazine := find(Magazine) as Magazine
	if not magazine or magazine.take():
		# Keep what this frame overshot by, so the fire rate doesn't drop with the frame rate.
		_cooldown = maxf(_cooldown, -delta) + 1.0 / fire_rate
		_buffered = 0.0
		var origin: ItemData = item.data if item else null
		Effect.apply_all(user_effects, EffectContext.new(wielder, wielder, origin))
		fired.emit()
