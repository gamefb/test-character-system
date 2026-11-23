@tool
@icon("res://character_system/icons/item_component.svg")
class_name ItemComponent
extends Component
## Base class for components inside an item scene.
##
## The item scene needs its own [ComponentManager]. [Equipment] sets [member wielder] and
## [member item] before the scene is added, so both are ready in [method Component._start].
##
## Keep per-copy state, such as rounds loaded, in [member ItemInstance.state], not on the node:
## the node is freed when the item is unequipped. Anything you change on the wielder, such as a
## stat modifier, must be undone in [method Component._stop], which runs on unequip.
##
## A component that acts when the item is used listens to its [Trigger], as [Hitscan] and
## [MeleeSweep] do:
## [codeblock]
## class_name ShotCounter
## extends ItemComponent
##
## func _requires() -> Array[Script]:
## 	return [Trigger]
##
## func _start() -> void:
## 	listen((find(Trigger) as Trigger).fired, _on_fired)
##
## func _on_fired() -> void:
## 	item.state[&"shots"] = item.state.get(&"shots", 0) + 1  # Kept between equips.
## [/codeblock]
## [Scope] in [code]examples/scripts/[/code] is a complete one that changes its wielder.

## The character holding the item.
var wielder: Node3D
## The copy being used. Keep per-copy state, such as rounds loaded, in item.state.
var item: ItemInstance
## The wielder's [Brain], for reading aim and button presses.
var brain: Brain:
	get:
		return Component.of(wielder, Brain)


## True while the wielder has a status with one of [param tags], e.g. to stop the item working
## while its wielder is disarmed.
func wielder_has_tag(tags: Array[StringName]) -> bool:
	if tags.is_empty():
		return false
	var statuses := Component.of(wielder, Statuses) as Statuses
	return statuses != null and tags.any(statuses.has_tag)
