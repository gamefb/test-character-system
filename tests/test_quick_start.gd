extends GutTest
## Builds the Quick start level the way the page describes it, and checks it plays as promised:
## the rifle is drawn at start, a click hits the dummy for 10, and the fire patch burns.

const MOVES: Array[StringName] = [&"left", &"right", &"forward", &"back"]
const EX := "res://character_system/starter_pack/"

var added: Array[StringName] = []


func after_each() -> void:
	for action in added:
		InputMap.erase_action(action)
	added.clear()


func add_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		added.append(action)


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
	var player := make_body(Vector3.ZERO)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.y = 1.6
	player.add_child(camera)
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0.3, -0.2, -0.5)
	camera.add_child(hand)
	var equipment := Equipment.new()
	equipment.sockets = { &"weapon": ^"../Camera3D/Hand" }
	var inventory := Inventory.new()
	var ammo := ItemInstance.new(load(EX + "items/rifle_ammo.tres"), 30)
	inventory.items = [ItemInstance.new(load(EX + "items/rifle.tres")), ammo]
	var parts: Array[Node] = [
		ComponentManager.new(), Health.new(), Statuses.new(), PlayerBrain.new(),
		walker(), MouseLook.new(), inventory, equipment, WeaponSwitch.new(),
	]
	for node in parts:
		player.add_child(node)
	return player


# Step 4: a dummy that can take hits and statuses.
func make_dummy() -> CharacterBody3D:
	var dummy := make_body(Vector3(0, 0, -6))
	for node in [ComponentManager.new(), Health.new(), Statuses.new()]:
		dummy.add_child(node)
	return dummy


func test_quick_start_level_plays_as_described() -> void:
	for action in MOVES + [&"jump", &"primary", &"reload"]:
		add_action(action)
	var level := Node3D.new()
	var player: CharacterBody3D = make_player()
	var dummy: CharacterBody3D = make_dummy()
	var fire := (load(EX + "zones/fire_patch.tscn") as PackedScene).instantiate() as Node3D
	fire.position = Vector3(4, 0, 0)  # Step 5.
	for node in [make_floor(), player, dummy, fire]:
		level.add_child(node)
	add_child_autofree(level)
	for i in 3:
		await get_tree().physics_frame
	var gear := Equipment.find_on(player)
	assert_true(gear.equipped.has(&"weapon"), "WeaponSwitch draws the rifle at start")
	# Step 6: a left click, as the Input Map sends it.
	var click := InputEventAction.new()
	click.action = &"primary"
	click.pressed = true
	await get_tree().process_frame
	get_viewport().push_input(click)
	for i in 3:
		await get_tree().physics_frame
	assert_eq(Health.find_on(dummy).current, 90.0, "10 damage per shot")
	player.global_position = fire.global_position
	for i in 3:
		await get_tree().physics_frame
	assert_true(Statuses.find_on(player).has_tag(&"fire"), "Burning")


## A CharacterMotor that walks and jumps, as in the docs.
func walker() -> CharacterMotor:
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	return motor
