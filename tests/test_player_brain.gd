extends GutTest
## PlayerBrain passes on the actions the Input Map has, including weapon switching,
## and only warns about the ones it doesn't.

const MOVES: Array[StringName] = [&"left", &"right", &"forward", &"back"]
var added: Array[StringName] = []


func after_each() -> void:
	for action in added:
		InputMap.erase_action(action)
	added.clear()


func add_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
		added.append(action)


func make_player(set_camera := true) -> PlayerBrain:
	var host := Node3D.new()
	var camera := Camera3D.new()
	var brain := PlayerBrain.new()
	if set_camera:
		brain.camera = camera
	for node in [camera, ComponentManager.new(), brain]:
		host.add_child(node)
	add_child_autofree(host)
	return brain


func press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	get_viewport().push_input(event)


func frames() -> void:
	for i in 2:
		await get_tree().physics_frame
	await get_tree().process_frame


func wall_at(z: float) -> StaticBody3D:
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(4, 4, 1)
	wall.add_child(shape)
	wall.position = Vector3(0, 1.6, z)
	add_child_autofree(wall)
	return wall


func test_the_aim_point_is_what_the_crosshair_is_on() -> void:
	for action in MOVES:
		add_action(action)
	var brain: PlayerBrain = make_player()
	brain.camera.position = Vector3(0, 1.6, 0)
	await frames()
	assert_almost_eq(brain.aim_point, Vector3(0, 1.6, -PlayerBrain.AIM_DISTANCE),
			Vector3.ONE * 0.01, "nothing in the way: as far as the player can aim")
	var wall: StaticBody3D = wall_at(-10.5)
	await frames()
	assert_almost_eq(brain.aim_point, Vector3(0, 1.6, -10), Vector3.ONE * 0.01,
			"the near face of the wall the camera looks at")
	wall.position.z = -1.3
	await frames()
	assert_almost_eq(brain.aim_point, Vector3(0, 1.6, -PlayerBrain.MIN_AIM_DISTANCE),
			Vector3.ONE * 0.01, "a wall in the player's face: never behind the weapon")
	brain.aim_mask = 0
	await frames()
	assert_almost_eq(brain.aim_point.z, -PlayerBrain.AIM_DISTANCE, 0.01, "a layer aimed through")
	brain.aim_mask = 0xffffffff
	wall.queue_free()
	var volume := Area3D.new()
	volume.add_child(CollisionShape3D.new())
	(volume.get_child(0) as CollisionShape3D).shape = BoxShape3D.new()
	volume.position = Vector3(0, 1.6, -5)
	add_child_autofree(volume)
	await frames()
	assert_almost_eq(brain.aim_point.z, -PlayerBrain.AIM_DISTANCE, 0.01,
			"an area that isn't a hurtbox is aimed through, as shots pass through it")


func test_a_camera_behind_the_character_aims_from_the_character() -> void:
	for action in MOVES:
		add_action(action)
	var brain: PlayerBrain = make_player()
	brain.camera.position = Vector3(0, 1.6, 4)
	wall_at(2.0)  # Between the camera and the character.
	wall_at(-20.5)
	await frames()
	assert_almost_eq(brain.aim_point, Vector3(0, 1.6, -20), Vector3.ONE * 0.01,
			"what is between the camera and the character is not aimed at")


func test_weapon_actions_are_passed_on() -> void:
	for action in MOVES + [&"next_weapon", &"previous_weapon"]:
		add_action(action)
	var brain: PlayerBrain = make_player()
	press(&"next_weapon")
	assert_true(brain.is_action_just_pressed(&"next_weapon"))
	press(&"previous_weapon")
	assert_true(brain.is_action_just_pressed(&"previous_weapon"))


func test_extra_actions_are_passed_on() -> void:
	for action in MOVES + PlayerBrain.ACTIONS + [&"sprint"]:
		add_action(action)
	var host := Node3D.new()
	var brain := PlayerBrain.new()
	brain.extra_actions = [&"sprint"]
	for node in [Camera3D.new(), ComponentManager.new(), brain]:
		host.add_child(node)
	add_child_autofree(host)
	press(&"sprint")
	assert_true(brain.is_action_just_pressed(&"sprint"))


func test_camera_left_empty_is_found() -> void:
	for action in MOVES + PlayerBrain.ACTIONS:
		add_action(action)
	var brain: PlayerBrain = make_player(false)
	assert_eq(brain.camera, brain.host.get_child(0))


func test_missing_actions_are_skipped_without_errors() -> void:
	for action in MOVES:
		add_action(action)
	# No primary, next_weapon, ... in this Input Map.
	var brain: PlayerBrain = make_player()
	if has_method(&"assert_push_warning"):  # GUT 9.5 or later.
		call(&"assert_push_warning", "next_weapon")
	press(&"left")
	assert_false(brain.is_action_pressed(&"left"), "movement isn't a button")
