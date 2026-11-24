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
## [br][br]With a [member wind_up] the shot comes that long after the press: a sword's
## backswing, a bow's draw. Being stunned in between cancels it, and the round goes back.
## [br][br]The wielder hears each use as events, with the item's data as the origin:
## [code]weapon_started[/code] in the frame of the press, with the wind-up as its
## [member EffectContext.duration]; [code]weapon_fired[/code] at the shot; and
## [code]weapon_interrupted[/code] if the wind-up was cut short. An [Animator] plays clips from
## them, and statuses can react to them.
## [br][br]A stunned or dead wielder can't fire, because its [Brain] reports no presses. A
## status that should stop weapons only, such as Disarmed, blocks [code]weapons[/code], which
## every trigger answers to through [member blocked_by].

## Emitted each time the item activates. Delivery components ([Hitscan], ...) listen to this.
signal fired

## The input action that fires the item, as sent by the wielder's [Brain].
@export var action: StringName = &"primary"
## Activations per second.
@export var fire_rate: float = 5.0
## On: fire while held. Off: one shot per press.
@export var automatic := false
## Seconds between the press and the shot: a sword's backswing, a bow's draw. 0 fires in the
## frame of the press. Being stunned or disarmed in between cancels the shot.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var wind_up: float = 0.0
## Seconds a press is remembered during cooldown, so fast clicks aren't lost.
@export var buffer_time: float = 0.15
## The names this item answers to. It doesn't fire while the wielder has a status that
## [member StatusData.blocks] one of them, e.g. a Disarmed status that blocks &"weapons".
@export var blocked_by: Array[StringName] = [&"weapons"]
## Run in order on the wielder each time the item fires, e.g. a [LaunchProjectileEffect] for a
## rocket launcher or a bow, a [KnockbackEffect] for recoil, or a cost paid from a [Pool].
## Their [member EffectContext.position] is where the item is, so what they launch or spawn
## leaves from the weapon.
@export var user_effects: Array[Effect] = []

var _buffered: float = 0.0
var _cooldown: float = 0.0
# Seconds until the shot being wound up; 0 when there is none.
var _winding: float = 0.0


## The [Trigger] on the item scene [param node], or null if there is none. Safe on a freed node.
static func find_on(node: Variant) -> Trigger:
	return Component.of(node, Trigger) as Trigger


func _process(delta: float) -> void:
	_cooldown -= delta
	_buffered -= delta
	var wielder_brain: Brain = brain
	if not wielder_brain:
		return
	if wielder_brain.is_action_just_pressed(action):
		# Remembered, so a press during the cooldown still fires.
		_buffered = buffer_time
	if _winding > 0.0:
		_winding -= delta
		if is_blocked():
			_interrupt()
		elif _winding < delta * 0.5:  # On the frame nearest the moment, not the one after.
			_shoot()
		return
	var held: bool = automatic and wielder_brain.is_action_pressed(action)
	var wants_to_fire: bool = held or _buffered > 0.0
	if not wants_to_fire or _cooldown > 0.0 or is_blocked():
		return
	var magazine := find(Magazine) as Magazine
	if magazine and not magazine.take():
		return
	# Keep what this frame overshot by, so the fire rate doesn't drop with the frame rate.
	_cooldown = maxf(_cooldown, -delta) + 1.0 / fire_rate
	_buffered = 0.0
	ComponentManager.notify(wielder, &"weapon_started", _context())
	if wind_up > 0.0:
		_winding = wind_up
	else:
		_shoot()


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(user_effects)


func _stop() -> void:
	if _winding > 0.0:
		_interrupt()


## True while the wielder can't use this: its [Brain] is blocked, or a status blocks one of
## [member blocked_by].
func is_blocked() -> bool:
	var m := ComponentManager.of(wielder)
	if m == null or m.blocks.is_empty():
		return false
	return m.is_blocked(blocked_by) or (brain != null and brain.is_blocked())


func _shoot() -> void:
	_winding = 0.0
	var ctx: EffectContext = _context()
	Effect.apply_all(user_effects, ctx)
	fired.emit()
	ComponentManager.notify(wielder, &"weapon_fired", ctx)


# A wind-up cut short: the round it took goes back, and nothing fires.
func _interrupt() -> void:
	_winding = 0.0
	var magazine := find(Magazine) as Magazine
	if magazine:
		magazine.rounds += 1
	ComponentManager.notify(wielder, &"weapon_interrupted", _context())


func _context() -> EffectContext:
	var ctx := EffectContext.new(wielder, wielder, item.data if item else null)
	ctx.duration = wind_up
	if host is Node3D:
		ctx.position = (host as Node3D).global_position
	return ctx
