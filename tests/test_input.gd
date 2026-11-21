extends GutTest
## Brain's buttons are polled like Godot's Input singleton: presses arrive as events, releases
## are polled, a release the brain never saw doesn't leave a button stuck, and every node sees
## each press exactly once.

const MOVES: Array[StringName] = [&"left", &"right", &"forward", &"back"]

var added: Array[StringName] = []


## Checks the brain's buttons from [code]_process()[/code] and [code]_physics_process()[/code],
## and counts how often it sees each press.
class Spy:
	extends Node

	var brain: Brain
	var process_presses: int = 0
	var physics_presses: int = 0

	func _process(_delta: float) -> void:
		if brain.is_action_just_pressed(&"primary"):
			process_presses += 1

	func _physics_process(_delta: float) -> void:
		if brain.is_action_just_pressed(&"primary"):
			physics_presses += 1


## Presses primary once from _physics_process(), as AI decision logic would.
class Presser:
	extends Node

	var brain: Brain

	func _physics_process(_delta: float) -> void:
		if not brain.is_action_pressed(&"primary"):
			brain.press(&"primary")
			set_physics_process(false)


func before_each() -> void:
	for a in MOVES + [&"primary"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
			added.append(a)


func after_each() -> void:
	get_tree().paused = false
	Input.action_release(&"primary")
	for a in added:
		InputMap.erase_action(a)
	added.clear()


func make_player() -> PlayerBrain:
	var host := Node3D.new()
	var camera := Camera3D.new()
	var brain := PlayerBrain.new()
	brain.camera = camera
	for node in [camera, ComponentManager.new(), brain]:
		host.add_child(node)
	add_child_autofree(host)
	return brain


## Sends [param event] the way the engine does: Input's state first, then the scene tree.
func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func fire(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"primary"
	event.pressed = pressed
	send(event)


func key(keycode: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = pressed
	return event


## A wielder with a plain Brain and an automatic Trigger. Returns [wielder brain, shot count].
func make_gunner() -> Array:
	var body := Node3D.new()
	var brain := Brain.new()
	for node in [ComponentManager.new(), brain]:
		body.add_child(node)
	var item := Node3D.new()
	var trigger := Trigger.new()
	trigger.automatic = true
	trigger.fire_rate = 60.0
	trigger.wielder = body
	item.add_child(ComponentManager.new())
	item.add_child(trigger)
	body.add_child(item)
	add_child_autofree(body)
	var shots: Array[int] = [0]
	trigger.fired.connect(func() -> void: shots[0] += 1)
	return [brain, shots]


## Waits until every node has run [code]_process()[/code] [param count] times.
func frames(count: int) -> void:
	# process_frame is emitted just before the nodes' _process(), so wait for one more.
	for i in count + 1:
		await get_tree().process_frame


func test_press_and_release_events() -> void:
	var brain: PlayerBrain = make_player()
	fire(true)
	assert_true(brain.is_action_pressed(&"primary"))
	assert_true(brain.is_action_just_pressed(&"primary"))
	await frames(1)
	assert_false(brain.is_action_just_pressed(&"primary"), "just pressed lasts one frame")
	fire(false)
	await frames(1)
	assert_false(brain.is_action_pressed(&"primary"))


func test_release_while_paused_ends_the_hold() -> void:
	var brain: PlayerBrain = make_player()
	fire(true)
	get_tree().paused = true
	fire(false)
	assert_true(brain.is_action_pressed(&"primary"), "paused nodes get no input")
	get_tree().paused = false
	await frames(1)
	assert_false(brain.is_action_pressed(&"primary"), "polling noticed the release")


func test_release_the_brain_never_saw_ends_the_hold() -> void:
	var brain: PlayerBrain = make_player()
	fire(true)
	# Released without an event reaching the scene, e.g. the UI used it.
	Input.action_release(&"primary")
	await frames(1)
	assert_false(brain.is_action_pressed(&"primary"))


func test_press_the_brain_never_saw_is_ignored() -> void:
	var brain: PlayerBrain = make_player()
	# Held without an event reaching the scene, e.g. a click on a HUD button.
	Input.action_press(&"primary")
	await frames(2)
	assert_false(brain.is_action_pressed(&"primary"))


func test_two_keys_on_one_action() -> void:
	InputMap.action_add_event(&"primary", key(KEY_A, true))
	InputMap.action_add_event(&"primary", key(KEY_B, true))
	var brain: PlayerBrain = make_player()
	send(key(KEY_A, true))
	send(key(KEY_B, true))
	send(key(KEY_A, false))
	await frames(1)
	assert_true(brain.is_action_pressed(&"primary"), "B is still down")
	send(key(KEY_B, false))
	await frames(1)
	assert_false(brain.is_action_pressed(&"primary"))


func test_every_node_sees_an_ai_press_once() -> void:
	var brain: Brain = autofree(Brain.new())
	var spy := Spy.new()
	var presser := Presser.new()
	spy.brain = brain
	presser.brain = brain
	# The spy runs first, so it would miss a press that only counted for the rest of the frame.
	for node: Node in [spy, presser]:
		add_child_autofree(node)
	while not brain.is_action_pressed(&"primary"):
		await get_tree().physics_frame
	for i in 3:
		await get_tree().physics_frame
	await frames(2)
	assert_eq(spy.process_presses, 1)
	assert_eq(spy.physics_presses, 1)


func test_every_node_sees_a_press_made_after_they_ran() -> void:
	var brain: Brain = autofree(Brain.new())
	var spy := Spy.new()
	spy.brain = brain
	add_child_autofree(spy)
	# Timers fire after every node's _process(), like a coroutine resuming after a wait.
	get_tree().create_timer(0.0).timeout.connect(brain.press.bind(&"primary"))
	while not brain.is_action_pressed(&"primary"):
		await get_tree().process_frame
	for i in 3:
		await get_tree().physics_frame
	await frames(2)
	assert_eq(spy.process_presses, 1)
	assert_eq(spy.physics_presses, 1)


func test_automatic_fires_while_held_and_stops_on_release() -> void:
	var gunner: Array = make_gunner()
	var brain: Brain = gunner[0]
	var shots: Array[int] = gunner[1]
	brain.press(&"primary")
	await frames(10)
	assert_gt(shots[0], 1, "keeps firing while held")
	brain.release(&"primary")
	await frames(1)
	var after_release: int = shots[0]
	await frames(10)
	assert_eq(shots[0], after_release, "stops once released")


func test_automatic_fires_once_for_a_quick_tap() -> void:
	var gunner: Array = make_gunner()
	var brain: Brain = gunner[0]
	var shots: Array[int] = gunner[1]
	brain.press(&"primary")
	brain.release(&"primary")
	await frames(10)
	assert_eq(shots[0], 1)
