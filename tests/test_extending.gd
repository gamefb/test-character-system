extends GutTest
## The pieces the Extending page builds on: radius targeting, the hostility condition, scene
## spawning and melee swings, and the example Sprint, Scope, AttackNearest, HUD, GlideMove and
## WallSlideMode scripts.

const EX := "res://character_system/starter_pack/"
const HUD := preload("res://character_system/starter_pack/scripts/character_hud.gd")


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
	var brain := Brain.find_on(who)
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
	Equipment.find_on(swinger).equip(ItemInstance.new(sword))
	await physics_frames()
	await tap(swinger, &"primary")
	assert_eq(Health.find_on(front).current, 90.0)
	assert_eq(Health.find_on(behind).current, 100.0)
	assert_eq(Health.find_on(swinger).current, 100.0, "never the wielder")


## A new weapon part writes only what a shot reaches.
class Pulse extends WeaponDelivery:
	var targeting := RadiusTargeting.new()

	func _fire() -> void:
		for target in targeting.find(context_for(wielder)):
			Effect.apply_all(effects, context_for(target))


func test_a_new_weapon_part_only_writes_what_a_shot_reaches() -> void:
	var wielder: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new()])
	var near: CharacterBody3D = make_character(Vector3(0, 0, -3))
	var far: CharacterBody3D = make_character(Vector3(0, 0, -20))
	var pulse := Pulse.new()
	pulse.effects = [DamageEffect.new()]
	var baton: ItemData = item([Trigger.new(), pulse])
	Equipment.find_on(wielder).equip(ItemInstance.new(baton))
	await physics_frames()
	await tap(wielder, &"primary")
	assert_eq(Health.find_on(near).current, 90.0, "the trigger, effects and context are inherited")
	assert_eq(Health.find_on(far).current, 100.0)
	assert_eq(Health.find_on(wielder).current, 100.0)


## A new effect with a number writes only what the number does.
class ShoveEffect extends AmountEffect:
	func _execute(ctx: EffectContext) -> void:
		(ctx.target as Node3D).position.z -= total(ctx)


func test_a_new_effect_with_a_number_inherits_amount_and_scaling() -> void:
	var pusher: CharacterBody3D = make_character()
	var pushed: CharacterBody3D = make_character(Vector3(0, 0, -2))
	ComponentManager.of(pusher).set_base(&"strength", 4.0)
	var per_strength := StatAmount.new()
	per_strength.stat = &"strength"
	per_strength.per_point = 0.5
	var shove := ShoveEffect.new()
	shove.amount = 1.0
	shove.scaling = [per_strength]
	var ctx := EffectContext.new(pusher, pushed)
	ctx.magnitude = 2.0
	shove.apply(ctx)
	assert_eq(pushed.position.z, -8.0, "(1 + 4 strength x 0.5) x 2 further away")


func test_sprint_spends_a_pool_while_held_and_cleans_up() -> void:
	var stamina := Pool.new()
	stamina.pool = &"stamina"
	var sprint := Sprint.new()
	var runner: CharacterBody3D = make_character(Vector3.ZERO,
			[Brain.new(), walker(), stamina, sprint])
	var manager := ComponentManager.of(runner)
	var brain := Brain.find_on(runner)
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
	runner.remove_child(sprint)
	assert_eq(manager.stat(&"move_speed"), 5.0, "removing it mid-sprint leaves no boost")
	sprint.free()
	stamina.change(-1000.0)
	runner.add_child(Sprint.new())
	brain.press(&"sprint")
	for i in 3:
		await get_tree().process_frame
	assert_eq(manager.stat(&"move_speed"), 5.0, "an empty pool: no sprint")


func test_scope_slows_the_wielder_only_while_aiming() -> void:
	var shooter: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new(), walker()])
	var manager := ComponentManager.of(shooter)
	var gear := Equipment.find_on(shooter)
	gear.equip(ItemInstance.new(item([Scope.new()])))
	Brain.find_on(shooter).press(&"secondary")
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
	Equipment.find_on(enemy).equip(ItemInstance.new(rifle))
	await wait_seconds(0.75)
	assert_eq(Health.find_on(player).current, 90.0, "one shot, at the chest")


func test_character_hud_shows_health_statuses_and_ammo() -> void:
	var hero: CharacterBody3D = make_character(Vector3.ZERO, [Brain.new(), Statuses.new()])
	var rifle: ItemData = load(EX + "items/rifle.tres")
	Equipment.find_on(hero).equip(ItemInstance.new(rifle))
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
	Health.find_on(hero).change(-30.0)
	Statuses.find_on(hero).add(load(EX + "statuses/haste.tres"))
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



## A standing character with a motor holding WalkMode, AirMode and [param extra], on a floor
## with a wall 1 m to its right.
func make_mover(extra: Array[MotorNode]) -> CharacterBody3D:
	for spec in [[Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0)],
			[Vector3(2.0, 5.0, 0.0), Vector3(1.0, 10.0, 10.0)]]:
		var solid := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		(shape.shape as BoxShape3D).size = spec[1]
		solid.add_child(shape)
		solid.position = spec[0]
		add_child_autofree(solid)
	var motor := walker()
	for node in extra:
		motor.add_child(node)
	var body := make_character(Vector3(0.0, 0.05, 0.0), [Brain.new(), motor])
	for i in 10:
		await get_tree().physics_frame
	return body


func test_glide_move_slows_the_fall_while_held() -> void:
	var glide := GlideMove.new()
	var body: CharacterBody3D = await make_mover([glide])
	var brain := Brain.find_on(body)
	var air := CharacterMotor.find_on(body).get_mode(AirMode) as AirMode
	await tap(body, &"jump")
	for i in 40:
		await get_tree().physics_frame
	assert_lt(body.velocity.y, -1.0, "Falling normally with jump released")
	brain.press(&"jump")
	for i in 3:
		await get_tree().physics_frame
	assert_eq(air.jumps_left, 0, "The press still double jumps")
	for i in 40:
		await get_tree().physics_frame
	assert_true(glide.active, "then holding it glides on the way down")
	assert_almost_eq(body.velocity.y, -glide.fall_speed, 0.01, "at the glide speed")
	brain.release(&"jump")
	for i in 2:
		await get_tree().physics_frame
	assert_false(glide.active, "Letting go stops gliding")


func test_wall_slide_mode_takes_over_by_itself() -> void:
	var slide := WallSlideMode.new()
	var body: CharacterBody3D = await make_mover([slide])
	var motor := CharacterMotor.find_on(body)
	var brain := Brain.find_on(body)
	brain.move_dir = Vector3.RIGHT
	await tap(body, &"jump")
	for i in 40:
		await get_tree().physics_frame
	assert_eq(motor.mode, slide, "Falling against the wall slides")
	assert_gt(body.velocity.y, -slide.slide_speed - 0.01, "slowly")
	await tap(body, &"jump")
	for i in 2:
		await get_tree().physics_frame  # Movement runs on physics frames, tap() on drawn ones.
	assert_lt(body.velocity.x, -3.0, "Jumping pushes off the wall")
	assert_is(motor.mode, AirMode, "into the air")


## A CharacterMotor that walks and jumps, as in the docs.
func walker() -> CharacterMotor:
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	return motor
