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
## the node is freed when the item is unequipped.
##
## [codeblock]
## class_name Scope
## extends ItemComponent
##
## func _process(_delta: float) -> void:
## 	item.state[&"zoomed"] = brain.is_action_pressed(&"secondary")
## [/codeblock]

## The character holding the item.
var wielder: Node3D
## The copy being used. Keep per-copy state, such as rounds loaded, in item.state.
var item: ItemInstance
## The wielder's [Brain], for reading aim and button presses.
var brain: Brain:
	get:
		return Component.of(wielder, Brain)
