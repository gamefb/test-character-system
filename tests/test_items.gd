extends GutTest
## Gear with numbers on it, gear that grants abilities, and items that are used up.


func make_character(extra: Array[Node] = []) -> Node3D:
	var body := Node3D.new()
	var hand := Node3D.new()
	hand.name = "Hand"
	var gear := Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand", &"ring": ^"../Hand" }
	for node: Node in [
		hand, ComponentManager.new(), Health.new(), Statuses.new(), Brain.new(), Inventory.new(),
		gear,
	] + extra:
		body.add_child(node)
	add_child_autofree(body)
	return body


## An item whose scene holds a ComponentManager and the given item components.
func item(parts: Array[Node], slot: StringName = &"ring") -> ItemData:
	var root := Node3D.new()
	for node: Node in [ComponentManager.new()] + parts:
		root.add_child(node)
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var data := ItemData.new()
	data.slot = slot
	data.scene = scene
	return data


func modifier(stat_name: StringName, add: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat_name
	m.add = add
	return m


func heal(amount: float) -> HealEffect:
	var e := HealEffect.new()
	e.amount = amount
	return e


func test_gear_changes_stats_while_equipped() -> void:
	var who: Node3D = make_character()
	var gear := Equipment.find_on(who)
	var vigor := Grants.new()
	vigor.modifiers = [modifier(&"max_health", 25.0)]
	var ring: ItemData = item([vigor])
	gear.equip(ItemInstance.new(ring))
	assert_eq(ComponentManager.stat_of(who, &"max_health"), 125.0)
	assert_eq(ComponentManager.of(who).modifiers_of(&"max_health")[0].source, ring,
			"a character sheet can say where it comes from")
	gear.unequip(&"ring")
	await get_tree().process_frame
	assert_eq(ComponentManager.stat_of(who, &"max_health"), 100.0)


func test_each_copy_can_carry_its_own_rolls() -> void:
	var who: Node3D = make_character()
	var gear := Equipment.find_on(who)
	var ring: ItemData = item([Grants.new()])
	var lucky := ItemInstance.new(ring)
	lucky.state[&"modifiers"] = [modifier(&"max_health", 40.0)]
	var plain := ItemInstance.new(ring)
	gear.equip(lucky)
	assert_eq(ComponentManager.stat_of(who, &"max_health"), 140.0)
	gear.equip(plain)
	await get_tree().process_frame
	assert_eq(ComponentManager.stat_of(who, &"max_health"), 100.0, "the other copy has none")


func test_gear_grants_abilities_while_equipped() -> void:
	var who: Node3D = make_character([Abilities.new()])
	var gear := Equipment.find_on(who)
	var abilities := Abilities.find_on(who)
	var punch := AbilityData.new()
	var fireball := AbilityData.new()
	abilities.slots = { &"secondary": punch }
	var grant := Grants.new()
	grant.abilities = { &"secondary": fireball, &"ability_1": fireball }
	var staff: ItemData = item([grant], &"weapon")
	gear.equip(ItemInstance.new(staff))
	assert_eq(abilities.slots[&"secondary"], fireball)
	assert_eq(abilities.slots[&"ability_1"], fireball)
	gear.unequip(&"weapon")
	await get_tree().process_frame
	assert_eq(abilities.slots[&"secondary"], punch, "what was there before comes back")
	assert_false(abilities.slots.has(&"ability_1"))


func test_a_potion_is_used_up() -> void:
	var who: Node3D = make_character()
	var bag := Inventory.find_on(who)
	var health := Health.find_on(who)
	var potion := ItemData.new()
	potion.max_stack = 5
	potion.use_effects = [heal(30.0)]
	bag.add(potion, 2)
	health.change(-80.0)
	watch_signals(bag)
	assert_true(bag.use(potion))
	assert_eq(health.current, 50.0)
	assert_eq(bag.count(potion), 1)
	assert_signal_emitted(bag, "changed")
	assert_true(bag.use(potion))
	assert_false(bag.use(potion), "none left")
	assert_eq(health.current, 80.0)


func test_some_items_are_not_used_up_and_some_cannot_be_used() -> void:
	var who: Node3D = make_character()
	var bag := Inventory.find_on(who)
	var horn := ItemData.new()
	horn.use_effects = [heal(1.0)]
	horn.consumed_on_use = false
	var rock := ItemData.new()
	bag.add(horn)
	bag.add(rock)
	assert_true(bag.use(horn))
	assert_true(bag.use(horn))
	assert_eq(bag.count(horn), 1)
	assert_false(bag.use(rock), "nothing to do")
	assert_eq(bag.count(rock), 1)
