@tool
class_name Equipment
extends Component
## Holds equipped items: spawns each item's scene at a socket, and frees it when unequipped.
##
## Add a socket to [member sockets] for every slot the character can use. An item scene needs its
## own [ComponentManager]; its [ItemComponent]s start when it's equipped and stop when it's
## unequipped.
##
## With an [Inventory] beside it, everything equipped is also carried: [method equip] adds the
## item to the Inventory if it isn't there, [method unequip] leaves it there, and an equipped
## item that leaves the Inventory (dropped, sold, used up) is unequipped.
##
## [codeblock]
## var gear := Equipment.find_on(player)
## var cloak := preload("res://character_system/starter_pack/items/fireproof_cloak.tres")
## gear.equip(ItemInstance.new(cloak))
## [/codeblock]

## Emitted when an item in [param slot] is equipped or unequipped.
signal changed(slot: StringName)

## Where each slot's scene is attached, e.g. { &"weapon": ^"../Hand" }. The key is the slot
## name an item's [member ItemData.slot] uses. Paths start from this node, so a Hand beside it
## is [code]../Hand[/code] and a Hand under the camera is [code]../Camera3D/Hand[/code].
@export var sockets: Dictionary[StringName, NodePath] = {}:
	set(value):
		sockets = value
		update_configuration_warnings()

## What is equipped in each slot.
var equipped: Dictionary[StringName, ItemInstance] = {}
var _nodes: Dictionary[StringName, Node] = {}


## The [Equipment] of [param node]'s character, or null if there is none.
static func find_on(node: Node) -> Equipment:
	return Component.of(node, Equipment) as Equipment


func _warnings() -> PackedStringArray:
	var out := PackedStringArray()
	for slot in sockets:
		if not has_node(sockets[slot]):
			out.append("The '%s' socket doesn't point at a node." % slot)
	return out


func _start() -> void:
	on(&"inventory_changed", _on_inventory_changed)


## Equips [param item], replacing whatever is in its slot. The replaced item stays carried.
func equip(item: ItemInstance) -> void:
	var slot: StringName = item.data.slot
	if not sockets.has(slot):
		push_error("Equipment on '%s' has no socket for the '%s' slot. Add one under Sockets."
				% [host.name, slot])
		return
	if equipped.get(slot) == item:
		return  # Already equipped.
	var bag := find(Inventory) as Inventory
	if bag and item not in bag.items:
		bag.add_instance(item)
	unequip(slot)
	var node: Node = item.data.scene.instantiate()
	for child in node.get_children():
		if child is ItemComponent:
			child.wielder = host
			child.item = item
	get_node(sockets[slot]).add_child(node)
	equipped[slot] = item
	_nodes[slot] = node
	changed.emit(slot)


## The scene spawned for the item in [param slot], or null if the slot is empty. Its item
## components are on it, e.g. for an ammo counter:
## [codeblock]
## var magazine := Magazine.find_on(gear.node_in(&"weapon"))
## [/codeblock]
func node_in(slot: StringName) -> Node:
	return _nodes.get(slot)


## Removes the item in [param slot] and returns it, or null if the slot was empty.
## With an [Inventory], the item is still carried.
func unequip(slot: StringName) -> ItemInstance:
	var item: ItemInstance = equipped.get(slot)
	if item:
		_nodes[slot].queue_free()
		equipped.erase(slot)
		_nodes.erase(slot)
		changed.emit(slot)
	return item


func _on_inventory_changed(_ctx: EffectContext) -> void:
	var bag := find(Inventory) as Inventory
	if bag:
		for slot in equipped.keys():
			if equipped[slot] not in bag.items:
				unequip(slot)  # No longer carried.
