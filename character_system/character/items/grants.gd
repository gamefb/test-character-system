@tool
@icon("res://character_system/icons/grants.svg")
class_name Grants
extends ItemComponent
## What the wielder gains while the item is equipped: passives, stat changes and abilities.
##
## Fill in whichever lists the item needs. Everything is taken back when it's unequipped.
## [br]- [member modifiers] are the shortest way to put numbers on gear: "+20 max health".
## [br]- [member statuses] are for bonuses that should show on a status bar, grant an immunity
## or react to events. Use passives ([member StatusData.duration] 0). They're held, not
## owned: two items that grant the same passive share it, and it stays until both are off.
## [br]- [member abilities] go into the wielder's [member Abilities.slots], and whatever was in
## a slot before comes back. Cooldowns belong to the wielder, so swapping the item out and
## back in doesn't reset them.
## [br][br][b]Rolled loot.[/b] Modifiers in [member ItemInstance.state] under
## [code]&"modifiers"[/code] are applied too, so two copies of an item can carry different
## bonuses:
## [codeblock]
## var ring := ItemInstance.new(ring_data)
## var bonus := StatModifier.new()
## bonus.stat = &"max_health"
## bonus.add = randf_range(5.0, 25.0)
## ring.state[&"modifiers"] = [bonus]
## inventory.add_instance(ring)
## [/codeblock]

## Passives the wielder has while this is equipped.
@export var statuses: Array[StatusData] = []
## Stat changes the wielder has while this is equipped, on every copy of the item.
@export var modifiers: Array[StatModifier] = []
## Action name to ability, e.g. { &"secondary": fireball }, as in [member Abilities.slots].
## A wielder without an [Abilities] component gets none.
@export var abilities: Dictionary[StringName, AbilityData] = {}

# Only what was accepted or applied, so only that is taken back.
var _statuses: Array[StatusData] = []
var _modifiers: Array[StatModifier] = []
var _replaced: Dictionary[StringName, AbilityData] = {}


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(statuses + modifiers + abilities.values())


func _start() -> void:
	var holder := Statuses.find_on(wielder)
	for s in statuses if holder else []:
		if holder.add(s, wielder):
			_statuses.append(s)
	var wielder_manager := ComponentManager.of(wielder)
	var rolled: Array = item.state.get(&"modifiers", []) if item else []
	for m in (modifiers + rolled) if wielder_manager else []:
		wielder_manager.add_modifier(m, item.data if item else null)
		_modifiers.append(m)
	var caster := Abilities.find_on(wielder)
	for action in abilities if caster else {}:
		_replaced[action] = caster.slots.get(action)
		caster.slots[action] = abilities[action]


func _stop() -> void:
	var holder := Statuses.find_on(wielder)
	for s in _statuses if holder else []:
		holder.drop_hold(s)
	var wielder_manager := ComponentManager.of(wielder)
	for m in _modifiers if wielder_manager else []:
		wielder_manager.remove_modifier(m)
	var caster := Abilities.find_on(wielder)
	for action in _replaced if caster else {}:
		if caster.slots.get(action) != abilities.get(action):
			continue  # Something else took the slot meanwhile: leave it.
		if _replaced[action]:
			caster.slots[action] = _replaced[action]
		else:
			caster.slots.erase(action)
	_statuses.clear()
	_modifiers.clear()
	_replaced.clear()
