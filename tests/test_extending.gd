extends GutTest
## The pieces the Extending page builds on: radius targeting, the hostility condition, scene
## spawning and melee swings, and the example Stamina, Scope, AttackNearest and HUD scripts.

const EX := "res://character_system/examples/"
const HUD := preload("res://character_system/examples/scripts/character_hud.gd")


func make_character(position := Vector3.ZERO, extra: Array[Node] = []) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, 1, -0.8)
	var gear := Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand" }
	for node in [shape, hand, ComponentManager.new(), Health.new(), gear] + extra:
		body.add_child(node)
	add_child_autofree(body)
	return body


func faction(team: StringName, hostile_to: Array[StringName] = []) -> Faction:
	var f := Faction.new()
	f.team = team
	f.hostile_to = hostile_to
	return f


## An item whose scene holds a ComponentManager and the given item components.
func item(parts: Array[Node]) -> ItemData:
	var root := Node3D.new()
	for node: Node in [ComponentManager.new()] + parts:
		root.add_child(node)
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var data := ItemData.new()
	data.slot = &"weapon"
	data.scene = scene
	return data


## Lets new bodies reach the physics space.
func physics_frames() -> void:
	for i in 2:
		await get_tree().physics_frame


## Presses and releases an action, letting every component see it.
func tap(who: Node, action: StringName) -> void:
	var brain := Component.of(who, Brain) as Brain
	brain.press(action)
	for i in 3:
		await get_tree().process_frame
	brain.release(action)


func test_radius_targeting_picks_enemies_in_range() -> void:
	var user: CharacterBody3D = make_character(Vector3.ZERO, [faction(&"player", [&"enemy"])])
	var near: CharacterBody3D = make_character(Vector3(3, 0, 0), [faction(&"enemy")])
	var far: CharacterBody3D = make_character(Vector3(20, 0, 0), [faction(&"enemy")])
	var ally: CharacterBody3D = make_character(Vector3(0, 0, 3), [faction(&"player")])
	await physics_frames()
	var nova := RadiusTargeting.new()
	var ctx := EffectContext.new(user)
	assert_eq(nova.find(ctx), [near] as Array[Node])
	nova.hostile_only = false
	nova.include_user = true
	var everyone: Array[Node] = nova.find(ctx)
	assert_eq(everyone.size(), 3)
	for who in [user, near, ally]:
		assert_has(everyone, who)
	assert_does_not_have(everyone, far)


func test_is_hostile_condition_spares_allies() -> void:
	var player: CharacterBody3D = make_character(Vector3.ZERO, [faction(&"player", [&"enemy"])])
	var grunt: CharacterBody3D = make_character(Vector3(5, 0, 0), [faction(&"enemy")])
	var ally: CharacterBody3D = make_character(Vector3(-5, 0, 0), [faction(&"player")])
	var c := IsHostileCondition.new()
	assert_true(c.check(EffectContext.new(player, grunt)))
	assert_false(c.check(EffectContext.new(player, ally)))
	assert_true(c.check(EffectContext.new(null, ally)), "a trap is hostile to everyone")
	c.negate = true
	assert_false(c.check(EffectContext.new(player, grunt)))


func test_spawn_scene_effect_spawns_where_the_target_is() -> void:
	var target: CharacterBody3D = make_character(Vector3(2, 0, 3))
	var puddle := Node3D.new()
	puddle.name = "Puddle"
	var scene := PackedScene.new()
	scene.pack(puddle)
	puddle.free()
	var spawn := SpawnSceneEffect.new()
	spawn.scene = scene
	spawn.lifetime = 0.2
	spawn.apply(EffectContext.new(null, target))
	await get_tree().process_frame
	var spawned := get_tree().root.find_child("Puddle", true, false) as Node3D
	assert_not_null(spawned)
	assert_eq(spawned.global_position, Vector3(2, 0, 3))
	await wait_seconds(0.4)
	assert_false(is_instance_valid(spawned), "freed after its lifetime")


func test_melee_sweep_hits_what_is_in_front() -> void:
	var swinger: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new()])
	var front: CharacterBody3D = make_character(Vector3(0, 0, -2.2))
	var behind: CharacterBody3D = make_character(Vector3(0, 0, 2.2))
	var sweep := MeleeSweep.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.5, 1.5)
	sweep.shape = box
	sweep.effects = [DamageEffect.new()]
	var sword: ItemData = item([Trigger.new(), sweep])
	(Component.of(swinger, Equipment) as Equipment).equip(ItemInstance.new(sword))
	await physics_frames()
	await tap(swinger, &"primary")
	assert_eq((Component.of(front, Health) as Health).current, 90.0)
	assert_eq((Component.of(behind, Health) as Health).current, 100.0)
	assert_eq((Component.of(swinger, Health) as Health).current, 100.0, "never the wielder")


func test_stamina_speeds_up_while_held_and_cleans_up() -> void:
	var stamina := Stamina.new()
	var runner: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new(), Movement.new(), stamina])
	var manager := ComponentManager.of(runner)
	var brain := Component.of(runner, Brain) as Brain
	brain.press(&"sprint")
	for i in 3:
		await get_tree().process_frame
	assert_eq(manager.stat(&"move_speed"), 7.5, "5 × 1.5 while sprinting")
	assert_lt(stamina.current, 100.0)
	brain.release(&"sprint")
	await get_tree().process_frame
	assert_eq(manager.stat(&"move_speed"), 5.0)
	brain.press(&"sprint")
	await get_tree().process_frame
	runner.remove_child(stamina)
	assert_eq(manager.stat(&"move_speed"), 5.0, "removing it mid-sprint leaves no boost")
	stamina.free()


func test_scope_slows_the_wielder_only_while_aiming() -> void:
	var shooter: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new(), Movement.new()])
	var manager := ComponentManager.of(shooter)
	var gear := Component.of(shooter, Equipment) as Equipment
	gear.equip(ItemInstance.new(item([Scope.new()])))
	(Component.of(shooter, Brain) as Brain).press(&"secondary")
	for i in 2:
		await get_tree().process_frame
	assert_eq(manager.stat(&"move_speed"), 2.5, "half speed while aiming")
	gear.unequip(&"weapon")
	await get_tree().process_frame
	assert_eq(manager.stat(&"move_speed"), 5.0, "unequipping while aiming leaves nothing behind")


func test_attack_nearest_chases_and_attacks_the_closest_enemy() -> void:
	var probe := PressProbe.new()
	var parts: Array[Node] = [
		NavigationAgent3D.new(), AIBrain.new(), faction(&"enemy", [&"player"]),
		AttackNearest.new(), probe,
	]
	var hunter: CharacterBody3D = make_character(Vector3.ZERO, parts)
	var near: CharacterBody3D = make_character(Vector3(4, 0, 0), [faction(&"player")])
	make_character(Vector3(9, 0, 0), [faction(&"player")])
	for i in 4:
		await get_tree().process_frame
	assert_eq((Component.of(hunter, AIBrain) as AIBrain).target, near)
	assert_eq(probe.presses, 0, "no attack on the decision that picks the target")
	await wait_seconds(0.75)
	assert_eq(probe.presses, 1, "then one tap per decision")


func test_an_enemy_with_attack_nearest_shoots_the_player() -> void:
	var player: CharacterBody3D = make_character(Vector3(0, 0, -8), [faction(&"player")])
	var parts: Array[Node] = [
		NavigationAgent3D.new(), AIBrain.new(), faction(&"enemy", [&"player"]),
		AttackNearest.new(),
	]
	var enemy: CharacterBody3D = make_character(Vector3.ZERO, parts)
	var rifle: ItemData = load(EX + "items/rifle.tres")
	(Component.of(enemy, Equipment) as Equipment).equip(ItemInstance.new(rifle))
	await wait_seconds(0.75)
	assert_eq((Component.of(player, Health) as Health).current, 90.0, "one shot, at the chest")


func test_character_hud_shows_health_statuses_and_ammo() -> void:
	var hero: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new(), Statuses.new()])
	var rifle: ItemData = load(EX + "items/rifle.tres")
	(Component.of(hero, Equipment) as Equipment).equip(ItemInstance.new(rifle))
	var hud := Control.new()
	var bar := ProgressBar.new()
	bar.name = "HealthBar"
	hud.add_child(bar)
	for label_name in ["Statuses", "Ammo", "Cooldown"]:
		var label := Label.new()
		label.name = label_name
		hud.add_child(label)
	hud.set_script(HUD)
	hud.set(&"character", hero)
	add_child_autofree(hud)
	(Component.of(hero, Health) as Health).change(-30.0)
	(Component.of(hero, Statuses) as Statuses).add(load(EX + "statuses/haste.tres"))
	await get_tree().process_frame
	assert_eq(bar.value, 70.0)
	assert_eq((hud.get_node("Statuses") as Label).text, "Haste")
	assert_eq((hud.get_node("Ammo") as Label).text, "Ammo: 12")


## Counts presses of primary, the way a weapon's Trigger sees them.
class PressProbe extends Component:
	var presses: int = 0

	func _process(_delta: float) -> void:
		if (find(Brain) as Brain).is_action_just_pressed(&"primary"):
			presses += 1
