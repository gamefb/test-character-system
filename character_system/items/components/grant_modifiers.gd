@tool
@icon("res://character_system/icons/grant_statuses.svg")
class_name GrantModifiers
extends ItemComponent
## Changes the wielder's stats while the item is equipped: "+20 max health", "+10% speed".
##
## It's the shortest way to make gear with numbers on it: no status file is needed. Use
## [GrantStatuses] instead when the bonus should show on a status bar, block other statuses or
## react to events.
## [br][br][b]Rolled loot.[/b] Modifiers in [member ItemInstance.state] under
## [code]&"modifiers"[/code] are applied too, so two copies of the same item can carry
## different bonuses:
## [codeblock]
## var ring := ItemInstance.new(ring_data)
## var bonus := StatModifier.new()
## bonus.stat = &"max_health"
## bonus.add = randf_range(5.0, 25.0)
## ring.state[&"modifiers"] = [bonus]
## inventory.add_instance(ring)
## [/codeblock]

## Applied to the wielder while equipped, on every copy of the item.
@export var modifiers: Array[StatModifier] = []

var _applied: Array[StatModifier] = []


func _warnings() -> PackedStringArray:
	return NameCheck.problems_in(modifiers)


func _start() -> void:
	var wielder_manager := ComponentManager.of(wielder)
	if not wielder_manager:
		return
	var all: Array = modifiers.duplicate()
	if item:
		all.append_array(item.state.get(&"modifiers", []))  # This copy's own rolls.
	for m in all:
		if m is StatModifier:
			wielder_manager.add_modifier(m, item.data if item else null)
			_applied.append(m)


func _stop() -> void:
	var wielder_manager := ComponentManager.of(wielder)
	if wielder_manager:
		for m in _applied:
			wielder_manager.remove_modifier(m)
	_applied.clear()
