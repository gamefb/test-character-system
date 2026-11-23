extends GutTest
## Weapons: fire rate, reloading, spread, projectiles and blasts.

const EX := "res://character_system/examples/"


func make_character(position := Vector3.ZERO, extra: Array[Node] = []) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	var hand := Node3D.new()
	hand.name = "Hand"
	# In front of the body, outside it.
	hand.position = Vector3(0, 1, -0.8)
	var gear := Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand" }
	for node: Node in [
		shape, hand, ComponentManager.new(), Health.new(), Statuses.new(), Brain.new(), gear,
	] + extra:
		body.add_child(node)
	add_child_autofree(body)
	return body


func health_of(node: Node) -> Health:
	return Component.of(node, Health) as Health


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


func damage(amount := 10.0, type: StringName = &"physical") -> DamageEffect:
	var e := DamageEffect.new()
	e.amount = amount
	e.type = type
	return e


## A projectile scene built in code.
func projectile_scene(setup: Callable = Callable()) -> PackedScene:
	var shot := Projectile.new()
	shot.speed = 60.0
	if setup.is_valid():
		setup.call(shot)
	var scene := PackedScene.new()
	scene.pack(shot)
	shot.free()
	return scene


func physics_frames(count := 2) -> void:
	for i in count:
		await get_tree().physics_frame


func pull_trigger(who: Node) -> void:
	var brain := Component.of(who, Brain) as Brain
	brain.press(&"primary")
	# A press counts from the next frame; process_frame comes just before nodes run.
	for i in 3:
		await get_tree().process_frame
	brain.release(&"primary")


func tagged(tag: StringName) -> StatusData:
	var s := StatusData.new()
	s.tags = [tag]
	s.duration = 5.0
	return s


func test_fire_rate_does_not_drop_with_the_frame_rate() -> void:
	var wielder: CharacterBody3D = make_character()
	var trigger: Trigger = autofree(Trigger.new())
	trigger.wielder = wielder
	trigger.automatic = true
	trigger.fire_rate = 10.0
	var shots: Array = [0]
	trigger.fired.connect(func() -> void: shots[0] += 1)
	(Component.of(wielder, Brain) as Brain).press(&"primary")
	# 7 seconds of frames that don't divide evenly into the 0.1 s between shots.
	for i in 100:
		trigger._process(0.07)
	assert_between(shots[0], 69, 71, "10 a second, not one every other frame")


func test_reloading_takes_time() -> void:
	var magazine: Magazine = autofree(Magazine.new())
	magazine.item = ItemInstance.new(ItemData.new())
	magazine.capacity = 6
	magazine.reload_time = 0.5
	magazine.rounds = 2
	watch_signals(magazine)
	magazine.reload()
	assert_true(magazine.is_reloading())
	assert_signal_emitted(magazine, "reload_started")
	assert_false(magazine.take(), "can't fire while reloading")
	magazine._process(0.3)
	assert_eq(magazine.rounds, 2)
	magazine._process(0.3)
	assert_eq(magazine.rounds, 6)
	assert_signal_emitted(magazine, "reload_finished")
	assert_true(magazine.take())
	magazine.rounds = 6
	magazine.reload()
	assert_false(magazine.is_reloading(), "a full magazine doesn't reload")


func test_an_empty_magazine_can_reload_itself() -> void:
	var magazine: Magazine = autofree(Magazine.new())
	magazine.item = ItemInstance.new(ItemData.new())
	magazine.capacity = 3
	magazine.auto_reload = true
	magazine.rounds = 0
	assert_false(magazine.take(), "this pull reloads instead of firing")
	assert_eq(magazine.rounds, 3)
	assert_true(magazine.take())


func test_spread_stays_inside_its_angle() -> void:
	var aim := Vector3(0.3, 0.1, -1.0).normalized()
	assert_eq(Projectile.spread_direction(aim, 0.0), aim, "no spread: unchanged")
	for i in 50:
		var strayed: Vector3 = Projectile.spread_direction(aim, 5.0)
		assert_almost_eq(strayed.length(), 1.0, 0.001)
		assert_lt(rad_to_deg(aim.angle_to(strayed)), 5.01)
	var up: Vector3 = Projectile.spread_direction(Vector3.UP, 5.0)
	assert_lt(rad_to_deg(Vector3.UP.angle_to(up)), 5.01, "straight up works too")


func test_shotgun_pellets_each_hit() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -4))
	var barrel := Hitscan.new()
	barrel.pellets = 5
	barrel.spread = 1.0
	barrel.effects = [damage(4.0)]
	(Component.of(shooter, Equipment) as Equipment).equip(
			ItemInstance.new(item([Trigger.new(), barrel])))
	(Component.of(shooter, Brain) as Brain).aim_point = target.global_position + Vector3.UP
	await physics_frames()
	await pull_trigger(shooter)
	assert_eq(health_of(target).current, 80.0, "five pellets of 4")


func test_a_projectile_hits_what_is_in_its_way_and_not_its_launcher() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -8))
	await physics_frames()
	var scene: PackedScene = projectile_scene()
	var hits: Array = []
	# From inside the shooter's own body.
	var shot: Projectile = Projectile.launch(scene, shooter, Vector3(0, 1, 0), Vector3(0, 1, -8),
			[damage(15.0)])
	shot.impacted.connect(func(ctx: EffectContext) -> void: hits.append(ctx))
	assert_eq(shot.velocity, Vector3(0, 0, -60))
	await physics_frames(20)
	assert_eq(health_of(target).current, 85.0)
	assert_eq(health_of(shooter).current, 100.0)
	assert_false(is_instance_valid(shot), "freed on impact")
	assert_eq(hits.size(), 1)
	assert_eq(hits[0].source, shooter, "the launcher gets the credit")
	assert_almost_eq(hits[0].position.z, -7.5, 0.1, "the hit point is recorded")


func test_a_projectile_runs_its_own_effects_after_the_launchers() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -8))
	await physics_frames()
	var scene: PackedScene = projectile_scene(func(shot: Projectile) -> void:
		shot.effects = [damage(1.0)])
	Projectile.launch(scene, shooter, Vector3(0, 1, -1), Vector3(0, 1, -8), [damage(15.0)])
	# The shot is on its way: it lands even if whoever fired it is gone by then.
	shooter.free()
	await physics_frames(20)
	assert_eq(health_of(target).current, 84.0)


func test_a_blast_hits_everyone_near_the_impact() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -8))
	var bystander: CharacterBody3D = make_character(Vector3(2, 0, -8))
	var far_away: CharacterBody3D = make_character(Vector3(9, 0, -8))
	await physics_frames()
	var rocket: PackedScene = projectile_scene(func(shot: Projectile) -> void:
		shot.blast_radius = 4.0
		shot.blast_effects = [damage(20.0, &"fire")])
	Projectile.launch(rocket, shooter, Vector3(0, 1, -1), Vector3(0, 1, -8), [damage(30.0)])
	await physics_frames(20)
	assert_eq(health_of(target).current, 50.0, "the direct hit and the blast")
	assert_eq(health_of(bystander).current, 80.0, "the blast alone")
	assert_eq(health_of(far_away).current, 100.0)
	assert_eq(health_of(shooter).current, 100.0, "out of reach")


func test_a_blast_can_fade_toward_its_edge() -> void:
	var shooter: CharacterBody3D = make_character(Vector3(0, 0, 20))
	var target: CharacterBody3D = make_character(Vector3(0, 0, -8))
	var bystander: CharacterBody3D = make_character(Vector3(2, 0, -8))
	await physics_frames()
	var grenade: PackedScene = projectile_scene(func(shot: Projectile) -> void:
		shot.blast_radius = 4.0
		shot.blast_edge_strength = 0.0
		shot.blast_effects = [damage(20.0)])
	Projectile.launch(grenade, shooter, Vector3(0, 0.1, -1), Vector3(0, 0.1, -8))
	await physics_frames(20)
	var close: float = 100.0 - health_of(target).current
	var further: float = 100.0 - health_of(bystander).current
	assert_gt(close, further, "weaker further from the centre")
	assert_gt(further, 0.0)


func test_a_projectile_with_a_blast_goes_off_when_its_time_is_up() -> void:
	var shooter: CharacterBody3D = make_character(Vector3(0, 0, 30))
	var target: CharacterBody3D = make_character(Vector3(0, 0, -3))
	await physics_frames()
	var mine: PackedScene = projectile_scene(func(shot: Projectile) -> void:
		shot.speed = 0.0
		shot.lifetime = 0.1
		shot.blast_radius = 4.0
		shot.blast_effects = [damage(20.0)])
	var dud: PackedScene = projectile_scene(func(shot: Projectile) -> void:
		shot.speed = 0.0
		shot.lifetime = 0.1)
	var first: Projectile = Projectile.launch(mine, shooter, Vector3(0, 1, -1), Vector3(0, 1, -3))
	var second: Projectile = Projectile.launch(dud, shooter, Vector3(0, 1, -1), Vector3(0, 1, -3))
	await physics_frames(12)
	assert_eq(health_of(target).current, 80.0)
	assert_false(is_instance_valid(first))
	assert_false(is_instance_valid(second), "one without a blast just disappears")


func test_a_weapon_fires_projectiles_through_its_triggers_effects() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -8))
	var loose := LaunchProjectileEffect.new()
	loose.projectile = projectile_scene()
	loose.effects = [damage(25.0)]
	var string := Trigger.new()
	string.user_effects = [loose]
	var bow: ItemData = item([string])
	(Component.of(shooter, Equipment) as Equipment).equip(ItemInstance.new(bow))
	(Component.of(shooter, Brain) as Brain).aim_point = target.global_position + Vector3.UP
	var origins: Array = []
	ComponentManager.of(target).event(&"took_damage").connect(
			func(ctx: EffectContext) -> void: origins.append(ctx.origin))
	await physics_frames()
	await pull_trigger(shooter)
	await physics_frames(20)
	assert_eq(health_of(target).current, 75.0)
	assert_eq(origins, [bow], "the weapon is recorded as the origin")


func test_an_ability_can_launch_a_projectile() -> void:
	var caster: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var target: CharacterBody3D = make_character(Vector3(0, 0, -8))
	(Component.of(caster, Brain) as Brain).aim_point = target.global_position + Vector3.UP
	await physics_frames()
	var throw := LaunchProjectileEffect.new()
	throw.projectile = projectile_scene()
	throw.effects = [damage(35.0, &"fire")]
	var fireball := AbilityData.new()
	fireball.user_effects = [throw]
	var health: Health = health_of(target)
	watch_signals(health)
	health.max_health = 30.0
	assert_true((Component.of(caster, Abilities) as Abilities).use(fireball))
	await physics_frames(20)
	assert_true(health.is_dead())
	var ctx: EffectContext = get_signal_parameters(health, "died")[0]
	assert_eq(ctx.origin, fireball, "for a kill feed: killed by Fireball")
	assert_eq(ctx.source, caster)
