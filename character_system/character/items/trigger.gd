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
## backswing, a rocket launcher's spin-up. Being stunned in between cancels it, and the round
## goes back.
## [br][br]With a [member charge_time] the press starts a charge and letting go fires. How far
## it got is the shot's [member charge], from 0 to 1, which goes into the
## [member EffectContext.charge] of everything the shot does. The trigger doesn't decide what
## a charge is worth: a [ChargeAmount] in an effect's scaling makes it hit harder or fly
## faster, and a [ChargeCondition] switches an effect on from some charge up.
## [br][br]The wielder hears each use as events, with the item's data as the origin:
## [code]weapon_started[/code] in the frame of the press, with the wind-up or the charge time
## as its [member EffectContext.duration]; [code]weapon_fired[/code] at the shot, with its
## [member EffectContext.charge]; and
## [code]weapon_interrupted[/code] if the wind-up or the charge was cut short. An [Animator]
## plays clips from them, and statuses can react to them.
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
## Seconds between the press and the shot: a sword's backswing, a rocket launcher's spin-up.
## 0 fires in the frame of the press. Being stunned or disarmed in between cancels the shot.
## Not used with a [member charge_time]: there the hold is the wind-up.
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

@export_group("Charge")
## Seconds of holding for a full charge: a bow's draw. The press starts the charge and letting
## go fires. 0: the item doesn't charge, and fires at the press.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var charge_time: float = 0.0
## The share of a full charge the shot needs. Letting go sooner cancels it, and the round goes
## back. 0 fires on any tap, and 1 only fires fully charged.
@export_range(0.0, 1.0, 0.01) var min_charge: float = 0.0
## The wielder has this status for as long as it is charging, e.g. one that slows it or
## drains stamina. Use a status with duration 0.
@export var status_while_charging: StatusData

## How far the shot is charged, from 0 to 1: rising while the button is held, then kept for
## the shot it fires. Always 0 without a [member charge_time].
var charge: float = 0.0

var _buffered: float = 0.0
var _cooldown: float = 0.0
# Seconds until the shot being wound up; 0 when there is none.
var _winding: float = 0.0
var _charging := false


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
	if _charging:
		charge = minf(charge + delta / charge_time, 1.0)
		if is_blocked():
			_interrupt()
		elif not wielder_brain.is_action_pressed(action):
			_let_go()
		return
	if _winding > 0.0:
		_winding -= delta
		if is_blocked():
			_interrupt()
		elif _winding < delta * 0.5:  # On the frame nearest the moment, not the one after.
			_shoot()
		return
	# A weapon that charges starts as soon as it can while the button is down, as an automatic
	# one fires: the hold is the point, so a press made during the cooldown isn't lost.
	var holds: bool = automatic or charge_time > 0.0
	var held: bool = holds and wielder_brain.is_action_pressed(action)
	var wants_to_fire: bool = held or _buffered > 0.0
	if not wants_to_fire or _cooldown > 0.0 or is_blocked():
		return
	var magazine := find(Magazine) as Magazine
	if magazine and not magazine.take():
		return
	_buffered = 0.0
	charge = 0.0
	var until_shot: float = charge_time if charge_time > 0.0 else wind_up
	ComponentManager.notify(wielder, &"weapon_started", _context(until_shot))
	if charge_time > 0.0:
		_set_charging(true)  # Its cooldown starts at the shot, when the button is let go.
		return
	# Keep what this frame overshot by, so the fire rate doesn't drop with the frame rate.
	_cooldown = maxf(_cooldown, -delta) + 1.0 / fire_rate
	if wind_up > 0.0:
		_winding = wind_up
	else:
		_shoot()


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(user_effects)


func _stop() -> void:
	if _winding > 0.0 or _charging:
		_interrupt()


## True while the button is held and the charge is building, e.g. to show a charge bar.
func is_charging() -> bool:
	return _charging


## True while the wielder can't use this: its [Brain] is blocked, or a status blocks one of
## [member blocked_by].
func is_blocked() -> bool:
	var m := ComponentManager.of(wielder)
	if m == null or m.blocks.is_empty():
		return false
	return m.is_blocked(blocked_by) or (brain != null and brain.is_blocked())


# The button was let go: the shot goes off with the charge it reached, or not at all.
func _let_go() -> void:
	if charge < min_charge:
		_interrupt()
		return
	_set_charging(false)
	# The time to the next shot counts from this one, not from the press.
	_cooldown = 1.0 / fire_rate
	_shoot()


func _set_charging(on: bool) -> void:
	_charging = on
	var statuses := Statuses.find_on(wielder)
	if status_while_charging and statuses:
		if on:
			statuses.add(status_while_charging, wielder)
		else:
			statuses.drop_hold(status_while_charging)


func _shoot() -> void:
	_winding = 0.0
	var ctx: EffectContext = _context()
	Effect.apply_all(user_effects, ctx)
	fired.emit()
	ComponentManager.notify(wielder, &"weapon_fired", ctx)


# A wind-up or a charge cut short: the round it took goes back, and nothing fires.
func _interrupt() -> void:
	_winding = 0.0
	if _charging:
		_set_charging(false)
		charge = 0.0
	var magazine := find(Magazine) as Magazine
	if magazine:
		magazine.rounds += 1
	ComponentManager.notify(wielder, &"weapon_interrupted", _context())


func _context(until_shot: float = 0.0) -> EffectContext:
	var ctx := EffectContext.new(wielder, wielder, item.data if item else null)
	ctx.duration = until_shot
	ctx.charge = charge
	if host is Node3D:
		ctx.position = (host as Node3D).global_position
	return ctx
