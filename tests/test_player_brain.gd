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
