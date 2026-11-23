extends GutTest
## The files in character_system/examples load and do what their descriptions say.

const EX := "res://character_system/examples/"


func ex(path: String) -> Resource:
	return load(EX + path)


func make_character() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var hand := Node3D.new()
	hand.name = "Hand"
	var gear := Equipment.new()
	gear.sockets = {
		&"weapon": ^"../Hand", &"cloak": ^"../Hand", &"neck": ^"../Hand", &"ring": ^"../Hand",
	}
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	var parts: Array[Node] = [
		shape,
		hand,
		ComponentManager.new(),
		Statuses.new(),
		Health.new(),
		Brain.new(),
		walker(),
		Abilities.new(),
		Inventory.new(),
		gear,
		WeaponSwitch.new(),
	]
	for node in parts:
		body.add_child(node)
	add_child_autofree(body)
	return body


func statuses(who: Node) -> Statuses:
	return Component.of(who, Statuses)


func health(who: Node) -> Health:
	return Component.of(who, Health)


func all_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".tres") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(all_files(dir.path_join(d)))
	return out


func test_every_example_loads() -> void:
	var files: PackedStringArray = all_files(EX)
	assert_gt(files.size(), 20)
	for path in files:
		var res: Resource = load(path)
		assert_not_null(res, path)
		if res is StatusData:
			assert_ne(res.description, "", path + " has a description")
		elif res is ItemData and res.slot:
			assert_not_null(res.scene, path + " has a scene")
		elif res is PackedScene:
			var node: Node = (res as PackedScene).instantiate()
			assert_true(
					node is EffectZone or node is Projectile or ComponentManager.of(node) != null
					or node.get_script() == null,
					path + " is a zone, a projectile, an item scene, a character or a plain scene")
			node.free()


func test_burning_ticks_fire_damage() -> void:
	var who: CharacterBody3D = make_character()
	statuses(who).add(ex("statuses/burning.tres"))
	await wait_seconds(1.1)
	assert_eq(health(who).current, 96.0)


func test_traits_refuse_what_they_are_immune_to() -> void:
	var undead: CharacterBody3D = make_character()
	statuses(undead).add(ex("traits/undead.tres"))
	assert_false(statuses(undead).add(ex("statuses/poisoned.tres")))
	assert_true(statuses(undead).add(ex("statuses/burning.tres")))
	var construct: CharacterBody3D = make_character()
	statuses(construct).add(ex("traits/construct.tres"))
	assert_false(statuses(construct).add(ex("statuses/poisoned.tres")))
	assert_false(statuses(construct).add(ex("statuses/burning.tres")))


func test_wet_puts_out_burning_and_slows() -> void:
	var who: CharacterBody3D = make_character()
	statuses(who).add(ex("statuses/burning.tres"))
	statuses(who).add(ex("statuses/wet.tres"))
	assert_false(statuses(who).has_tag(&"fire"))
	assert_false(statuses(who).add(ex("statuses/burning.tres")))
	assert_almost_eq(ComponentManager.stat_of(who, &"move_speed"), 3.0, 0.001)


func test_ward_halves_damage() -> void:
	var who: CharacterBody3D = make_character()
	statuses(who).add(ex("statuses/warded.tres"))
	var hit := DamageEffect.new()
	hit.amount = 20.0
	hit.apply(EffectContext.new(null, who))
	assert_eq(health(who).current, 90.0)


func test_thorns_hurt_the_attacker() -> void:
	var attacker: CharacterBody3D = make_character()
	var thorny: CharacterBody3D = make_character()
	statuses(thorny).add(ex("statuses/thorns.tres"))
	DamageEffect.new().apply(EffectContext.new(attacker, thorny))
	assert_eq(health(attacker).current, 97.0)


func test_abilities_heal_and_haste_the_user() -> void:
	var who: CharacterBody3D = make_character()
	health(who).change(-50.0)
	var abilities := Component.of(who, Abilities) as Abilities
	assert_true(abilities.use(ex("abilities/second_wind.tres")))
	assert_eq(health(who).current, 80.0)
	assert_false(abilities.use(ex("abilities/second_wind.tres")), "on cooldown")
	abilities.use(ex("abilities/sprint.tres"))
	assert_almost_eq(ComponentManager.stat_of(who, &"move_speed"), 7.5, 0.001)


func test_items_equip_and_grant_their_passives() -> void:
	var who: CharacterBody3D = make_character()
	var bag := Component.of(who, Inventory) as Inventory
	bag.add(ex("items/rifle.tres"))
	bag.add(ex("items/flare_gun.tres"))
	bag.add(ex("items/rifle_ammo.tres"), 30)
	await get_tree().process_frame
	var gear := Component.of(who, Equipment) as Equipment
	assert_eq(gear.equipped[&"weapon"].data, ex("items/rifle.tres"), "first weapon drawn")
	gear.equip(ItemInstance.new(ex("items/fireproof_cloak.tres")))
	gear.equip(ItemInstance.new(ex("items/ward_amulet.tres")))
	assert_true(statuses(who).has_tag(&"fireproof"))
	assert_true(statuses(who).has_tag(&"ward"))


## A CharacterMotor that walks and jumps, as in the docs.
func walker() -> CharacterMotor:
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	return motor
