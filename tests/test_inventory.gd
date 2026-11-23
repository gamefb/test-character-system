extends GutTest
## Carrying several weapons, holding one at a time, and keeping Equipment and Inventory in step.

var host: Node3D
var hand: Node3D
var bag: Inventory
var gear: Equipment
var switch: WeaponSwitch
var brain: Brain
var statuses: Statuses
var rifle: ItemData
var pistol: ItemData
var flare: ItemData
var ammo: ItemData
var cloak: ItemData
var fireproof: StatusData


func before_each() -> void:
	fireproof = StatusData.new()
	fireproof.tags = [&"fireproof"]
	fireproof.immune_to = [&"fire"]
	var grant := Grants.new()
	grant.statuses = [fireproof]
	rifle = make_item(&"rifle", &"weapon")
	pistol = make_item(&"pistol", &"weapon")
	flare = make_item(&"flare", &"weapon")
	cloak = make_item(&"cloak", &"cloak", [grant])
	ammo = ItemData.new()
	ammo.max_stack = 30

	host = Node3D.new()
	hand = Node3D.new()
	hand.name = "Hand"
	brain = Brain.new()
	bag = Inventory.new()
	gear = Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand", &"cloak": ^"../Hand" }
	switch = WeaponSwitch.new()
	statuses = Statuses.new()
	for node in [hand, ComponentManager.new(), brain, bag, gear, switch, statuses]:
		host.add_child(node)
	add_child_autofree(host)


## An item whose scene is just a ComponentManager plus [param parts].
func make_item(id: StringName, slot: StringName, parts: Array[Node] = []) -> ItemData:
	var root := Node3D.new()
	root.name = id
	for node: Node in [ComponentManager.new()] + parts:
		root.add_child(node)
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var data := ItemData.new()
	data.id = id
	data.slot = slot
	data.scene = scene
	return data


func held() -> ItemData:
	var item: ItemInstance = switch.current()
	return item.data if item else null


func settle() -> void:
	# Auto-draw is deferred; freed item scenes leave at frame end.
	await get_tree().process_frame
	await get_tree().process_frame


func test_first_weapon_picked_up_is_drawn_and_stays_drawn() -> void:
	bag.add(rifle)
	await settle()
	assert_eq(held(), rifle)
	bag.add(pistol)
	await settle()
	assert_eq(held(), rifle, "a second pickup doesn't switch")
	assert_eq(bag.count(rifle), 1, "the held weapon is still carried")


func test_next_and_previous_wrap_around() -> void:
	for w in [rifle, pistol, flare]:
		bag.add(w)
	await settle()
	var order: Array[ItemData] = []
	for i in 3:
		switch.cycle(1)
		order.append(held())
	assert_eq(order, [pistol, flare, rifle] as Array[ItemData])
	switch.cycle(-1)
	assert_eq(held(), flare)


func test_actions_switch_weapons() -> void:
	bag.add(rifle)
	bag.add(pistol)
	await settle()
	brain.press(&"next_weapon")
	await settle()
	assert_eq(held(), pistol)
	brain.release(&"next_weapon")
	await settle()
	assert_eq(held(), pistol, "releasing the button does nothing")
	brain.press(&"previous_weapon")
	await settle()
	assert_eq(held(), rifle)


func test_only_the_held_weapon_is_in_the_hand() -> void:
	for w in [rifle, pistol, flare]:
		bag.add(w)
	await settle()
	switch.cycle(1)
	switch.cycle(1)
	await settle()
	assert_eq(hand.get_child_count(), 1)
	assert_eq(String(hand.get_child(0).name), "flare")


func test_switching_keeps_each_weapons_own_state() -> void:
	bag.add(rifle)
	bag.add(pistol)
	await settle()
	var my_rifle: ItemInstance = switch.current()
	my_rifle.state[&"rounds"] = 4
	switch.select(1)
	switch.select(0)
	assert_eq(switch.current(), my_rifle, "the same copy comes back")
	assert_eq(my_rifle.state[&"rounds"], 4)


func test_holstered_stays_holstered_until_chosen() -> void:
	bag.add(rifle)
	await settle()
	switch.holster()
	bag.add(ammo, 10)
	await settle()
	assert_null(switch.current(), "picking up ammo doesn't draw")
	assert_eq(bag.count(rifle), 1)
	switch.select(0)
	assert_eq(held(), rifle)


func test_dropping_the_held_weapon_draws_the_next() -> void:
	bag.add(rifle)
	bag.add(pistol)
	await settle()
	var dropped: ItemInstance = switch.current()
	assert_true(bag.remove_instance(dropped))
	assert_null(switch.current(), "unequipped as soon as it leaves the bag")
	await settle()
	assert_eq(held(), pistol)
	assert_eq(bag.count(rifle), 0)
	assert_false(bag.remove_instance(dropped), "already gone")


func test_cycling_with_no_weapons_does_nothing() -> void:
	switch.cycle(1)
	switch.cycle(-1)
	switch.select(3)
	assert_null(switch.current())


func test_equipping_an_uncarried_item_carries_it() -> void:
	gear.equip(ItemInstance.new(cloak))
	assert_eq(bag.count(cloak), 1)
	assert_eq(gear.equipped[&"cloak"].data, cloak)


func test_switching_weapons_leaves_other_slots_alone() -> void:
	bag.add(rifle)
	bag.add(pistol)
	gear.equip(ItemInstance.new(cloak))
	await settle()
	switch.cycle(1)
	assert_eq(gear.equipped[&"cloak"].data, cloak)
	assert_true(statuses.has_tag(&"fireproof"))


func test_removing_a_worn_item_from_the_bag_ends_its_passive() -> void:
	gear.equip(ItemInstance.new(cloak))
	assert_true(statuses.has_tag(&"fireproof"))
	bag.remove(cloak)
	await settle()
	assert_false(gear.equipped.has(&"cloak"))
	assert_false(statuses.has_tag(&"fireproof"))


func test_equipment_without_an_inventory_still_works() -> void:
	var turret := Node3D.new()
	var socket := Node3D.new()
	socket.name = "Hand"
	var turret_gear := Equipment.new()
	turret_gear.sockets = { &"weapon": ^"../Hand" }
	for node in [socket, ComponentManager.new(), turret_gear]:
		turret.add_child(node)
	add_child_autofree(turret)
	var gun := ItemInstance.new(rifle)
	turret_gear.equip(gun)
	assert_eq(turret_gear.equipped[&"weapon"], gun)
	assert_eq(turret_gear.unequip(&"weapon"), gun)
