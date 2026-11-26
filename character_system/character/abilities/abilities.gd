@tool
class_name Abilities
extends Component
## Uses abilities when their action is pressed, and tracks cooldowns, charges, costs and casts.
##
## Put an [AbilityData] in [member slots] under an action name, e.g. [code]secondary[/code].
## For a player, the action must be one [PlayerBrain] passes on: one of its
## [constant PlayerBrain.ACTIONS] or your own in [member PlayerBrain.extra_actions]. Code and AI
## can call [method use] directly.
##
## [br][br]An ability is used only if [method why_not] finds nothing against it: the character
## can act, isn't casting something else, has a charge and enough in its [Pool]s, and the
## ability's conditions pass. Otherwise [signal failed] says why, e.g. for a "Not enough mana"
## message. Costs and the charge are taken when the effects run, so an interrupted cast costs
## nothing.
## [br][br]The character's components and statuses hear [code]ability_cast_started[/code],
## [code]ability_used[/code] and [code]ability_interrupted[/code] as events, with the ability
## as [member EffectContext.origin].

## Emitted when an ability's effects run.
signal used(ability: AbilityData)
## Emitted when an ability with a [member AbilityData.cast_time] starts casting.
signal cast_started(ability: AbilityData)
## Emitted when a cast is cut short. Nothing was spent.
signal cast_interrupted(ability: AbilityData)
## Emitted when [method use] refuses. [param reason] is what [method why_not] returned.
signal failed(ability: AbilityData, reason: StringName)

## Action name to ability, e.g. { &"secondary": fireball }. Change it at any time to grant
## abilities, or let an item do it with [Grants].
@export var slots: Dictionary[StringName, AbilityData] = {}
## How fast cooldowns run, through the cooldown_speed stat: 1 is normal, 2 is twice as fast.
## A status with a [StatModifier] of percent 0.2 on cooldown_speed is 20% faster cooldowns.
@export var cooldown_speed: float = 1.0:
	set(value):
		cooldown_speed = value
		update_stats()

## The ability being cast right now, or null.
var casting: AbilityData

var _cast_left: float = 0.0
var _states: Dictionary[AbilityData, State] = {}


## The [Abilities] of [param node]'s character, or null if there is none.
static func find_on(node: Node) -> Abilities:
	return Component.of(node, Abilities) as Abilities


func _process(delta: float) -> void:
	# Game time: cooldowns stop while the game is paused and follow Engine.time_scale.
	var recharge: float = delta * maxf(stat(&"cooldown_speed"), 0.0)
	for ability: AbilityData in _states:
		var state: State = _states[ability]
		if state.used > 0:
			state.recharge_left -= recharge
			if state.recharge_left <= 0.0:
				state.used -= 1
				# Any time left over counts toward the next charge.
				state.recharge_left = state.recharge_left + ability.cooldown if state.used > 0 else 0.0
	if casting:
		_cast_left -= delta
		if _blocked(casting):
			interrupt()
		elif _cast_left <= 0.0:
			_finish_cast()
	var brain := find(Brain) as Brain
	for action in slots:
		if slots[action] and brain.is_action_just_pressed(action):
			use(slots[action])


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(slots.values())


func _requires() -> Array[Script]:
	return [Brain]


func _stats() -> Dictionary[StringName, float]:
	return { &"cooldown_speed": cooldown_speed }


func _start() -> void:
	on(&"took_damage", _on_took_damage)


func _stop() -> void:
	interrupt()


## Uses [param ability] if nothing is against it. Returns true if it was used, or if its cast
## started. Otherwise emits [signal failed] and returns false.
func use(ability: AbilityData) -> bool:
	var reason: StringName = why_not(ability)
	if reason:
		failed.emit(ability, reason)
		return false
	if ability.cast_time <= 0.0:
		return _fire(ability)
	casting = ability
	_cast_left = ability.cast_time
	hold_status(ability.status_while_casting, true, host)
	cast_started.emit(ability)
	var ctx := EffectContext.new(host, host, ability)
	ctx.duration = ability.cast_time
	manager.send(&"ability_cast_started", ctx)
	return true


## True if [method use] would use [param ability] right now, e.g. to grey out a button.
func can_use(ability: AbilityData) -> bool:
	return why_not(ability).is_empty()


## Why [param ability] can't be used right now, or an empty name if it can:
## [br]- [code]&"blocked"[/code]: a status is blocking the [Brain], as Stunned and Dead do,
## or one of the ability's [member AbilityData.blocked_by].
## [br]- [code]&"casting"[/code]: another ability is being cast.
## [br]- [code]&"cooldown"[/code]: no charge is ready.
## [br]- [code]&"cost"[/code]: a [Pool] in [member AbilityData.costs] is missing or too low.
## [br]- [code]&"condition"[/code]: one of its [member AbilityData.conditions] fails.
## [br]- [code]&"no_target"[/code]: it needs a target and its targeting found none.
func why_not(ability: AbilityData) -> StringName:
	var reason: StringName = &""
	if not running or _blocked(ability):
		reason = &"blocked"
	elif casting:
		reason = &"casting"
	elif charges_left(ability) <= 0:
		reason = &"cooldown"
	elif not _can_pay(ability):
		reason = &"cost"
	elif not Condition.all_pass(ability.conditions, EffectContext.new(host, host, ability)):
		reason = &"condition"
	elif ability.needs_target and _targets(ability).is_empty():
		reason = &"no_target"
	return reason


## Stops the cast in progress, if any. Nothing is spent and no cooldown starts. Call it for
## your own interruptions, such as a counterspell.
func interrupt() -> void:
	if not casting:
		return
	var ability: AbilityData = casting
	_end_cast()
	cast_interrupted.emit(ability)
	if manager:
		manager.send(&"ability_interrupted", EffectContext.new(host, host, ability))


## Seconds until [param ability] can be used again, or 0 if a charge is ready. Handy for an
## ability bar.
func cooldown_left(ability: AbilityData) -> float:
	return recharge_left(ability) if charges_left(ability) <= 0 else 0.0


## Seconds until [param ability] regains its next charge, or 0 if it has them all.
func recharge_left(ability: AbilityData) -> float:
	var state: State = _states.get(ability)
	return maxf(state.recharge_left, 0.0) if state and state.used > 0 else 0.0


## How many uses of [param ability] are ready, from 0 to [member AbilityData.charges].
func charges_left(ability: AbilityData) -> int:
	var state: State = _states.get(ability)
	return maxi(ability.charges - (state.used if state else 0), 0)


## How far the cast in progress has got, from 0 to 1, e.g. for a cast bar. 0 when not casting.
func cast_progress() -> float:
	if not casting or casting.cast_time <= 0.0:
		return 0.0
	return clampf(1.0 - _cast_left / casting.cast_time, 0.0, 1.0)


## Makes every charge of [param ability] ready at once, e.g. for a "reset cooldowns" pickup.
## Leave it out to reset every ability.
func reset_cooldown(ability: AbilityData = null) -> void:
	if ability:
		_states.erase(ability)
	else:
		_states.clear()


# Takes the costs and a charge, then runs the effects. False if it can no longer be paid for.
func _fire(ability: AbilityData) -> bool:
	# No Targeting set: the ability affects its user.
	var targets: Array[Node] = _targets(ability)
	if not _can_pay(ability) or (ability.needs_target and targets.is_empty()):
		failed.emit(ability, &"cost" if not _can_pay(ability) else &"no_target")
		return false
	for pool_name in ability.costs:
		Pool.named(host, pool_name).spend(ability.costs[pool_name])
	var state: State = _states.get_or_add(ability, State.new())
	if state.used == 0:
		state.recharge_left = ability.cooldown
	state.used += 1
	for target in targets:
		Effect.apply_all(ability.effects, EffectContext.new(host, target, ability))
	Effect.apply_all(ability.user_effects, EffectContext.new(host, host, ability))
	used.emit(ability)
	manager.send(&"ability_used", EffectContext.new(host, host, ability))
	return true


func _finish_cast() -> void:
	var ability: AbilityData = casting
	_end_cast()
	_fire(ability)


func _end_cast() -> void:
	hold_status(casting.status_while_casting, false)
	casting = null
	_cast_left = 0.0


func _targets(ability: AbilityData) -> Array[Node]:
	if ability.targeting:
		return ability.targeting.find(EffectContext.new(host, null, ability))
	return [host]


func _can_pay(ability: AbilityData) -> bool:
	for pool_name in ability.costs:
		var found := Pool.named(host, pool_name)
		if not found or found.current < ability.costs[pool_name]:
			return false
	return true


# True while the character can't act, or a status blocks this ability.
func _blocked(ability: AbilityData) -> bool:
	var brain := find(Brain) as Brain
	return (brain and brain.is_blocked()) or manager.is_blocked(ability.blocked_by)


func _on_took_damage(ctx: EffectContext) -> void:
	if casting and casting.interrupted_by_damage and ctx and ctx.amount > 0.0:
		interrupt()


## Cooldown state of one ability on this character.
class State:
	## Charges used and not yet regained.
	var used: int = 0
	## Seconds until the next charge comes back.
	var recharge_left: float = 0.0
