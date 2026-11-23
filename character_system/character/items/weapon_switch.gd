@tool
@icon("res://character_system/icons/weapon_switch.svg")
class_name WeaponSwitch
extends Component
## Lets a character carry several weapons and hold one at a time.
##
## The weapons are the items in the [Inventory] whose slot is [member slot], in the order they
## were picked up. The one held is the one in that [Equipment] slot. Switching keeps each
## weapon's own state, such as rounds loaded, because the same [ItemInstance] goes back and forth.
##
## Players switch with the [code]next_weapon[/code] and [code]previous_weapon[/code] actions;
## AI and UI call [method cycle], [method select] or [method holster].

## The [Equipment] slot to switch, e.g. &"weapon".
@export var slot: StringName = &"weapon"
## Draws a weapon when the hands are empty and the [Inventory] changes, e.g. on the first pickup
## or after the held weapon is dropped. Not after [method holster].
@export var auto_draw := true

# Put away on purpose, so auto_draw leaves it.
var _holstered := false


## The [WeaponSwitch] of [param node]'s character, or null if there is none. Safe on a freed node.
static func find_on(node: Variant) -> WeaponSwitch:
	return Component.of(node, WeaponSwitch) as WeaponSwitch


func _process(_delta: float) -> void:
	var brain := find(Brain) as Brain
	if brain.is_action_just_pressed(&"next_weapon"):
		cycle(1)
	elif brain.is_action_just_pressed(&"previous_weapon"):
		cycle(-1)


func _requires() -> Array[Script]:
	return [Brain, Inventory, Equipment]


func _start() -> void:
	on(&"inventory_changed", _on_inventory_changed)
	_draw_if_empty()


## The weapons carried, in the order they were picked up.
func weapons() -> Array[ItemInstance]:
	return (find(Inventory) as Inventory).items.filter(
			func(item: ItemInstance) -> bool: return item.data.slot == slot)


## The weapon being held, or null.
func current() -> ItemInstance:
	return (find(Equipment) as Equipment).equipped.get(slot)


## Holds the weapon [param step] places after the current one, wrapping around.
## Use -1 for the previous one.
func cycle(step := 1) -> void:
	var list: Array[ItemInstance] = weapons()
	if list.is_empty():
		return
	var index: int = list.find(current())
	if index == -1 and step < 0:
		# Nothing held: -1 takes the last weapon, +1 the first.
		index = 0
	select(posmod(index + step, list.size()))


## Holds weapon number [param index], counting from 0. Does nothing if there isn't one.
func select(index: int) -> void:
	var list: Array[ItemInstance] = weapons()
	if index >= 0 and index < list.size():
		_holstered = false
		(find(Equipment) as Equipment).equip(list[index])


## Puts the held weapon away. It stays in the [Inventory].
func holster() -> void:
	_holstered = true
	(find(Equipment) as Equipment).unequip(slot)


func _draw_if_empty() -> void:
	if running and auto_draw and not _holstered and current() == null:
		select(0)


func _on_inventory_changed(_ctx: EffectContext) -> void:
	# After the change finishes, never in the middle of it.
	_draw_if_empty.call_deferred()
