@tool
@icon("res://character_system/icons/abilities.svg")
class_name Abilities
extends Component
## Uses abilities when their action is pressed, and tracks cooldowns.
##
## Put an [AbilityData] in [member slots] under an action name, e.g. [code]secondary[/code].
## For a player, the action must be one [PlayerBrain] passes on: one of its
## [constant PlayerBrain.ACTIONS] or your own in [member PlayerBrain.extra_actions]. Code and AI
## can call [method use] directly.

## Action name to ability, e.g. { &"secondary": fireball }. Change it at any time to grant
## abilities.
@export var slots: Dictionary[StringName, AbilityData] = {}

var _cooldowns: Dictionary[AbilityData, SceneTreeTimer] = {}


func _process(_delta: float) -> void:
	var brain := find(Brain) as Brain
	for action in slots:
		if brain.is_action_just_pressed(action):
			use(slots[action])


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(slots.values())


func _requires() -> Array[Script]:
	return [Brain]


## Uses [param ability] if it is off cooldown. Returns true if it was used.
func use(ability: AbilityData) -> bool:
	if cooldown_left(ability) > 0.0:
		return false
	# Game time: the cooldown stops while the game is paused and follows Engine.time_scale.
	_cooldowns[ability] = get_tree().create_timer(ability.cooldown, false)
	# No Targeting set: the ability affects its user.
	var targets: Array[Node] = [host]
	if ability.targeting:
		targets = ability.targeting.find(EffectContext.new(host, null, ability))
	for target in targets:
		Effect.apply_all(ability.effects, EffectContext.new(host, target, ability))
	return true


## Seconds until [param ability] can be used again, or 0. Handy for an ability bar.
func cooldown_left(ability: AbilityData) -> float:
	var timer: SceneTreeTimer = _cooldowns.get(ability)
	return timer.time_left if timer else 0.0
