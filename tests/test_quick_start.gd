extends GutTest
## Builds the Quick start level the way the page describes it, step by step, and checks it
## plays as the page promises. If a number changes here, change it on the page too.

const MOVES: Array[StringName] = [&"left", &"right", &"forward", &"back"]
const EX := "res://character_system/starter_pack/"

var added: Array[StringName] = []
var level: Node3D
var player: CharacterBody3D
var dummy: CharacterBody3D


func before_each() -> void:
	# Step 1: the input actions.
	for action: StringName in MOVES + [&"jump", &"primary", &"reload", &"next_weapon"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			added.append(action)
	level = Node3D.new()
	player = make_player()
	dummy = make_dummy()
	for node: Node in [make_floor(), player, dummy]:
		level.add_child(node)
	add_child_autofree(level)


func after_each() -> void:
	for action in added:
		InputMap.erase_action(action)
	added.clear()


# Step 2: a floor to stand on.
func make_floor() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	return ground


# A body with a capsule, its feet at its origin.
func make_body(position: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	body.add_child(shape)
	return body


# Step 3: the player, with a hand under its camera and a rifle and ammo in its bag.
func make_player() -> CharacterBody3D:
	var body := make_body(Vector3.ZERO)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.6
	body.add_child(camera)
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.3, -0.2, -0.5)
	camera.add_child(hand)
	var equipment := Equipment.new()
	equipment.sockets = { &"weapon": ^"../Camera3D/Hand" }
	var inventory := Inventory.new()
	var ammo := ItemInstance.new(load(EX + "items/rifle_ammo.tres"), 30)
	inventory.items = [ItemInstance.new(load(EX + "items/rifle.tres")), ammo]
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	var parts: Array[Node] = [
		ComponentManager.new(), Health.new(), Statuses.new(), PlayerBrain.new(),
		motor, MouseLook.new(), inventory, equipment, WeaponSwitch.new(),
	]
	for node in parts:
		body.add_child(node)
	return body


# Step 4: a dummy that can take hits and statuses, with a nameplate above it.
func make_dummy() -> CharacterBody3D:
	var body := make_body(Vector3(0, 0, -6))
	body.name = "Dummy"
	var plate := Nameplate.new()
	plate.name = "Nameplate"
	plate.position.y = 2.4
	for node: Node in [ComponentManager.new(), Health.new(), Statuses.new(), plate]:
		body.add_child(node)
	return body


# Step 6: half speed for as long as something holds it.
func make_chilled() -> StatusData:
	var slow := StatModifier.new()
	slow.stat = &"move_speed"
	slow.mul = 0.5
	var chilled := StatusData.new()
	chilled.id = &"chilled"
	chilled.display_name = "Chilled"
	chilled.tags = [&"cold"]
	chilled.modifiers = [slow]
	return chilled


# Step 7: a patch of ice that holds Chilled on whoever stands on it.
func make_ice_patch(chilled: StatusData) -> EffectZone:
	var patch := EffectZone.new()
	patch.position = Vector3(4, 0, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 2, 3)
	shape.shape = box
	shape.position.y = 1.0
	patch.add_child(shape)
	patch.status_while_inside = chilled
	return patch


# Step 8: 3 cold damage a second for 5 seconds.
func make_frostbite() -> StatusData:
	var bite := DamageEffect.new()
	bite.amount = 3.0
	bite.type = &"cold"
	var frostbite := StatusData.new()
	frostbite.id = &"frostbite"
	frostbite.display_name = "Frostbite"
	frostbite.tags = [&"cold"]
	frostbite.duration = 5.0
	frostbite.tick_interval = 1.0
	frostbite.on_tick = [bite]
	return frostbite


# Step 9: a pistol whose shots do 6, do 10 more to a target that is already cold, and
# give Frostbite.
func make_frost_pistol(frostbite: StatusData) -> ItemData:
	var hit := DamageEffect.new()
	hit.amount = 6.0
	hit.type = &"cold"
	var is_cold := HasTagCondition.new()
	is_cold.tag = &"cold"
	var shatter := DamageEffect.new()
	shatter.amount = 10.0
	shatter.type = &"cold"
	shatter.conditions = [is_cold]
	var freeze := ApplyStatusEffect.new()
	freeze.status = frostbite
	var root := Node3D.new()
	var trigger := Trigger.new()
	trigger.fire_rate = 2.0
	var ray := Hitscan.new()
	ray.effects = [hit, shatter, freeze]
	for node: Node in [ComponentManager.new(), trigger, ray]:
		root.add_child(node)
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var pistol := ItemData.new()
	pistol.id = &"frost_pistol"
	pistol.display_name = "Frost pistol"
	pistol.slot = &"weapon"
	pistol.scene = scene
	return pistol


func test_part_one_a_level_to_play_in() -> void:
	await _frames(3)
	assert_true(Equipment.find_on(player).equipped.has(&"weapon"), "the rifle is drawn at start")
	await _tap(&"primary")
	assert_eq(Health.find_on(dummy).current, 90.0, "10 damage per shot")
	await get_tree().process_frame
	var plate: Nameplate = dummy.get_node("Nameplate")
	assert_eq(plate.text, "Dummy\n90 / 100\n", "the nameplate shows it")
	assert_eq(Magazine.find_on(Equipment.find_on(player).node_in(&"weapon")).rounds, 11, "of 12")


func test_part_two_make_it_yours() -> void:
	var chilled: StatusData = make_chilled()
	var frostbite: StatusData = make_frostbite()
	var patch: EffectZone = make_ice_patch(chilled)
	level.add_child(patch)
	var pistol: ItemData = make_frost_pistol(frostbite)
	Inventory.find_on(player).add(pistol)
	await _frames(3)
	# Step 10: the ice patch slows whoever stands on it, and only while they do.
	var speed: float = ComponentManager.stat_of(player, &"move_speed")
	player.global_position = patch.global_position
	await _frames(3)
	assert_true(Statuses.find_on(player).has_tag(&"cold"))
	assert_eq(ComponentManager.stat_of(player, &"move_speed"), speed * 0.5, "half speed")
	player.global_position = Vector3.ZERO
	await _frames(3)
	assert_false(Statuses.find_on(player).has_tag(&"cold"), "gone on stepping off")
	assert_eq(ComponentManager.stat_of(player, &"move_speed"), speed)
	# The frost pistol.
	await _tap(&"next_weapon")
	assert_eq(Equipment.find_on(player).equipped[&"weapon"].data, pistol, "Q draws it")
	var health := Health.find_on(dummy)
	await _tap(&"primary")
	assert_eq(health.current, 94.0, "the first shot does 6: the dummy wasn't cold yet")
	await get_tree().process_frame
	assert_eq((dummy.get_node("Nameplate") as Nameplate).text, "Dummy\n94 / 100\nFrostbite")
	await get_tree().create_timer(0.6).timeout
	await _tap(&"primary")
	assert_eq(health.current, 78.0, "the second does 6 and 10 more, because it is cold now")
	await get_tree().create_timer(1.2).timeout
	assert_eq(health.current, 75.0, "and Frostbite takes 3 a second")


func test_things_to_try() -> void:
	var frostbite: StatusData = make_frostbite()
	frostbite.stacking = StatusData.Stacking.STACK
	frostbite.max_stacks = 3
	var pistol: ItemData = make_frost_pistol(frostbite)
	Inventory.find_on(player).add(pistol)
	await _frames(3)
	await _tap(&"next_weapon")
	var health := Health.find_on(dummy)
	var statuses := Statuses.find_on(dummy)
	# Make Frostbite stack: three shots, three stacks, and each tick takes 3 for every stack.
	for shot in 3:
		await _tap(&"primary")
		await get_tree().create_timer(0.5).timeout
	assert_eq(statuses.stacks_of(frostbite), 3)
	var before: float = health.current
	var waited: float = 0.0
	while health.current == before and waited < 1.5:
		await get_tree().process_frame
		waited += get_process_delta_time()
	assert_eq(before - health.current, 9.0, "9 a second at three stacks")
	# Make the dummy immune: it refuses Frostbite, so every shot does 6, and ice doesn't slow it.
	var fur := StatusData.new()
	fur.id = &"thick_fur"
	fur.display_name = "Thick fur"
	fur.immune_to = [&"cold"]
	statuses.remove(frostbite)
	statuses.add(fur)
	health.revive()
	await get_tree().create_timer(0.5).timeout
	await _tap(&"primary")
	assert_eq(health.current, 94.0)
	await get_tree().create_timer(0.6).timeout
	await _tap(&"primary")
	assert_eq(health.current, 88.0, "6 again: the shot before left nothing cold on it")
	var patch: EffectZone = make_ice_patch(make_chilled())
	level.add_child(patch)
	dummy.global_position = patch.global_position
	await _frames(4)
	assert_false(statuses.has_tag(&"cold"), "and it stays warm on the ice")


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


# Presses and lets go, as the Input Map sends it.
func _tap(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		await get_tree().process_frame
		get_viewport().push_input(event)
		await _frames(3)
