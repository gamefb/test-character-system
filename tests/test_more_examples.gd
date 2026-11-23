extends GutTest
## More of the files in character_system/examples: stuns, combat passives, gear with numbers,
## consumables, and a mage that casts.

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


func hit(target: Node, amount := 10.0, type: StringName = &"physical",
		source: Node = null) -> EffectContext:
	var blow := DamageEffect.new()
	blow.amount = amount
	blow.type = type
	var ctx := EffectContext.new(source, target)
	blow.apply(ctx)
	return ctx


func test_stunned_stops_everything_and_silenced_stops_spells() -> void:
	var who: CharacterBody3D = make_character()
	var brain := Component.of(who, Brain) as Brain
	var abilities := Component.of(who, Abilities) as Abilities
	var fireball: AbilityData = ex("abilities/fireball.tres")
	statuses(who).add(ex("statuses/silenced.tres"))
	assert_false(brain.is_blocked())
	assert_eq(abilities.why_not(fireball), &"blocked")
	assert_true(abilities.can_use(ex("abilities/second_wind.tres")), "it only stops spells")
	statuses(who).add(ex("statuses/stunned.tres"))
	assert_true(brain.is_blocked())
	assert_false(abilities.can_use(ex("abilities/second_wind.tres")))


func test_combat_passives_react_to_hits_and_kills() -> void:
	var hunter: CharacterBody3D = make_character()
	var prey: CharacterBody3D = make_character()
	health(hunter).change(-60.0)
	statuses(hunter).add(ex("statuses/vampiric.tres"))
	statuses(hunter).add(ex("statuses/bloodlust.tres"))
	hit(prey, 20.0, &"physical", hunter)
	assert_eq(health(hunter).current, 45.0, "a quarter of the 20 dealt")
	hit(prey, 80.0, &"physical", hunter)
	assert_eq(health(hunter).current, 80.0, "20 for the hit and 15 for the kill")


func test_fire_ward_only_halves_fire() -> void:
	var who: CharacterBody3D = make_character()
	statuses(who).add(ex("statuses/fire_ward.tres"))
	hit(who, 20.0, &"fire")
	assert_eq(health(who).current, 90.0)
	hit(who, 20.0, &"physical")
	assert_eq(health(who).current, 70.0)


func test_sharpshooter_rewards_headshots() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character()
	statuses(shooter).add(ex("statuses/sharpshooter.tres"))
	var head: Hurtbox = autofree(Hurtbox.new())
	head.character = target
	head.multiplier = 2.0
	head.tags = [&"head"]
	var blow := DamageEffect.new()
	blow.apply(Hurtbox.hit(shooter, head))
	assert_eq(health(target).current, 70.0, "10 x 2 for the head, then 50% more")
	blow.apply(EffectContext.new(shooter, target))
	assert_eq(health(target).current, 60.0, "a body shot is plain")


func test_lucky_strikes_follow_the_crit_chance_stat() -> void:
	var target: CharacterBody3D = make_character()
	var lucky: CharacterBody3D = make_character()
	var certain := Attributes.new()
	certain.stats = { &"crit_chance": 1.0 }
	lucky.add_child(certain)
	statuses(lucky).add(ex("statuses/lucky_strikes.tres"))
	var ctx: EffectContext = hit(target, 10.0, &"physical", lucky)
	assert_eq(ctx.amount, 20.0, "always a crit")
	var hopeless := StatModifier.new()
	hopeless.stat = &"crit_chance"
	hopeless.add = -5.0
	ComponentManager.of(lucky).add_modifier(hopeless)
	assert_eq(hit(target, 10.0, &"physical", lucky).amount, 10.0, "never a crit")


func test_gear_examples_change_stats_and_grant_abilities() -> void:
	var who: CharacterBody3D = make_character()
	var gear := Component.of(who, Equipment) as Equipment
	gear.equip(ItemInstance.new(ex("items/ring_of_vigor.tres")))
	assert_eq(ComponentManager.stat_of(who, &"max_health"), 125.0)
	gear.equip(ItemInstance.new(ex("items/fire_staff.tres")))
	assert_eq((Component.of(who, Abilities) as Abilities).slots[&"secondary"],
			ex("abilities/fireball.tres"))
	assert_almost_eq(ComponentManager.stat_of(who, &"bonus_fire"), 0.2, 0.001)
	gear.equip(ItemInstance.new(ex("items/shotgun.tres")))
	await get_tree().process_frame
	assert_false((Component.of(who, Abilities) as Abilities).slots.has(&"secondary"),
			"the staff took its ability with it")
	var shotgun: Node = gear.node_in(&"weapon")
	assert_eq((Component.of(shotgun, Hitscan) as Hitscan).pellets, 8)
	var shells := Component.of(shotgun, Magazine) as Magazine
	shells.rounds = 0
	shells.reload()
	assert_true(shells.is_reloading(), "no ammo item: it reloads for free, but takes time")


func test_health_potion_heals_and_is_used_up() -> void:
	var who: CharacterBody3D = make_character()
	var bag := Component.of(who, Inventory) as Inventory
	bag.add(ex("items/health_potion.tres"), 2)
	health(who).change(-70.0)
	assert_true(bag.use(ex("items/health_potion.tres")))
	assert_eq(health(who).current, 70.0)
	assert_eq(bag.count(ex("items/health_potion.tres")), 1)


func test_mage_casts_a_fireball_and_has_a_shield() -> void:
	var mage: CharacterBody3D = (ex("characters/mage.tscn") as PackedScene).instantiate()
	add_child_autofree(mage)
	# No motor, so it doesn't fall while the fireball is on its way.
	var target := CharacterBody3D.new()
	target.position = Vector3(0, 0, -8)
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	for node: Node in [shape, ComponentManager.new(), Health.new(), Statuses.new()]:
		target.add_child(node)
	add_child_autofree(target)
	var abilities := Component.of(mage, Abilities) as Abilities
	var mana := Pool.named(mage, &"mana")
	(Component.of(mage, Brain) as Brain).aim_point = target.position + Vector3.UP
	for i in 2:
		await get_tree().physics_frame
	assert_true(abilities.use(ex("abilities/fireball.tres")))
	assert_eq(mana.current, 100.0, "nothing is spent until the cast is done")
	await wait_seconds(1.2)
	assert_lt(mana.current, 90.0, "20 spent, a little regained")
	assert_lt(health(target).current, 65.0, "20 + 2 per spell_power, then the blast")
	assert_true(statuses(target).has_tag(&"fire"), "and it's burning")
	var shield := Pool.named(mage, &"shield")
	hit(mage, 20.0)
	assert_eq([shield.current, health(mage).current], [10.0, 80.0], "the shield takes it")
	hit(mage, 20.0)
	assert_eq([shield.current, health(mage).current], [0.0, 70.0])


## A CharacterMotor that walks and jumps, as in the docs.
func walker() -> CharacterMotor:
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	return motor
