extends GutTest
## The core: components start once what they need is there, stop when it leaves, only
## process while running, and share stats and events through the ComponentManager.

var host: Node3D


func before_each() -> void:
	host = Node3D.new()
	host.add_child(ComponentManager.new())


func expect_error(text: String) -> void:
	if has_method(&"assert_push_error"):  # GUT 9.5 or later.
		call(&"assert_push_error", text)


## Lets a few process and physics frames pass.
func frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame
		await get_tree().physics_frame


func press_key() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	get_viewport().push_input(key)


func test_requirement_added_later_starts_the_component() -> void:
	var needy := Needy.new()
	host.add_child(needy)
	add_child_autofree(host)
	assert_false(needy.running, "waits for Needed")
	expect_error("can't start")
	host.add_child(Needed.new())
	assert_true(needy.running)
	assert_eq(needy.starts, 1)


func test_order_does_not_matter() -> void:
	var needy := Needy.new()
	host.add_child(needy)
	host.move_child(needy, 0)  # Before the manager.
	host.add_child(Needed.new())
	add_child_autofree(host)
	assert_true(needy.running)


func test_component_added_mid_game_starts_straight_away() -> void:
	host.add_child(Needed.new())
	add_child_autofree(host)
	var needy := Needy.new()
	host.add_child(needy)
	assert_true(needy.running)


func test_only_processes_while_running() -> void:
	var needed := Needed.new()
	var needy := Needy.new()
	host.add_child(needy)
	add_child_autofree(host)
	await frames()
	assert_eq([needy.frames, needy.physics_frames], [0, 0], "no processing before it starts")
	expect_error("can't start")
	host.add_child(needed)
	await frames()
	assert_gt(needy.frames, 0)
	assert_gt(needy.physics_frames, 0)
	host.remove_child(needed)
	var frozen := [needy.frames, needy.physics_frames]
	await frames()
	assert_eq([needy.frames, needy.physics_frames], frozen, "stops processing when Needed leaves")
	needed.free()


func test_only_gets_input_while_running() -> void:
	var needed := Needed.new()
	var needy := Needy.new()
	host.add_child(needed)
	host.add_child(needy)
	add_child_autofree(host)
	press_key()
	assert_eq(needy.inputs, 1)
	host.remove_child(needed)
	press_key()
	assert_eq(needy.inputs, 1, "no input while stopped")
	host.add_child(needed)
	press_key()
	assert_eq(needy.inputs, 2, "input again after restarting")


func test_stops_and_restarts_with_its_requirement() -> void:
	var needed := Needed.new()
	var needy := Needy.new()
	host.add_child(needed)
	host.add_child(needy)
	add_child_autofree(host)
	needed.pinged.emit()
	assert_eq(needy.pings, 1)
	host.remove_child(needed)
	assert_false(needy.running)
	assert_eq(needy.stops, 1)
	needed.pinged.emit()
	assert_eq(needy.pings, 1, "listen() connections are undone on stop")
	host.add_child(needed)
	assert_eq(needy.starts, 2)
	needed.pinged.emit()
	assert_eq(needy.pings, 2, "and made again on restart")


func test_keeps_running_while_another_of_the_required_type_is_left() -> void:
	var first := Needed.new()
	var needy := Needy.new()
	for node in [first, Needed.new(), needy]:
		host.add_child(node)
	add_child_autofree(host)
	host.remove_child(first)
	assert_true(needy.running)
	first.free()


func test_removing_a_component_stops_it() -> void:
	var needy := Needy.new()
	host.add_child(Needed.new())
	host.add_child(needy)
	add_child_autofree(host)
	host.remove_child(needy)
	assert_false(needy.running)
	assert_eq(needy.stops, 1)
	needy.free()


func test_own_process_mode_is_kept() -> void:
	var needy := Needy.new()
	needy.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child(Needed.new())
	host.add_child(needy)
	add_child_autofree(host)
	assert_eq(needy.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_stats_combine_and_update() -> void:
	host.add_child(Needed.new())
	add_child_autofree(host)
	var manager := ComponentManager.of(host)
	assert_eq(manager.stat(&"power"), 10.0)
	var m := StatModifier.new()
	m.stat = &"power"
	m.add = 2.0
	m.mul = 1.5
	manager.add_modifier(m)
	assert_eq(manager.stat(&"power"), 18.0)
	manager.remove_modifier(m)
	assert_eq(manager.stat(&"power"), 10.0)
	assert_eq(manager.stat(&"unknown"), 0.0)


func test_events_reach_running_components_only() -> void:
	var needed := Needed.new()
	var needy := Needy.new()
	host.add_child(needy)
	add_child_autofree(host)
	expect_error("can't start")
	ComponentManager.notify(host, &"hello", null)
	assert_eq(needy.heard, [] as Array[StringName], "not running yet")
	host.add_child(needed)
	ComponentManager.notify(host, &"hello", null)
	assert_eq(needy.heard, [&"hello"] as Array[StringName])


func test_lookups_work_before_the_host_is_in_the_scene() -> void:
	var needed := Needed.new()
	host.add_child(needed)
	assert_eq(Component.of(host, Needed), needed)
	host.free()


func test_lookups_follow_components_that_come_and_go() -> void:
	assert_null(Component.of(host, Needed), "none yet")
	var needed := Needed.new()
	host.add_child(needed)
	assert_eq(Component.of(host, Needed), needed, "added outside the scene")
	add_child_autofree(host)
	host.remove_child(needed)
	assert_null(Component.of(host, Needed), "removed during play")
	needed.free()


func test_find_on_is_a_typed_lookup_that_is_safe_on_anything() -> void:
	var health := Health.new()
	host.add_child(health)
	assert_eq(Health.find_on(host), health)
	assert_null(Statuses.find_on(host), "none of that type")
	assert_null(Health.find_on(null))
	assert_null(Health.find_on(autofree(Node.new())), "not a character")
	host.free()
	assert_null(Health.find_on(host), "freed")


## A class that extends an engine class directly needs its own picture; classes built on it
## may share it. Compares the pictures, not the file names, so a copied file doesn't count.
func test_every_base_class_has_an_icon_of_its_own() -> void:
	var classes: Dictionary[StringName, Dictionary] = {}
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["path"]).begins_with("res://character_system/"):
			classes[entry["class"]] = entry
	# Picture -> the base class that has it.
	var pictures: Dictionary[String, StringName] = {}
	for name: StringName in classes:
		if classes.has(classes[name]["base"]):
			continue
		var icon: String = classes[name]["icon"]
		assert_ne(icon, "", "%s has no icon" % name)
		var picture: String = FileAccess.get_file_as_string(icon)
		assert_ne(picture, "", "%s: %s can't be read" % [name, icon])
		assert_false(pictures.has(picture),
				"%s has the same picture as %s" % [name, pictures.get(picture, &"")])
		pictures[picture] = name
	assert_gt(pictures.size(), 10)


func test_new_component_reports_its_stats() -> void:
	add_child_autofree(host)
	var manager := ComponentManager.of(host)
	watch_signals(manager)
	host.add_child(Needed.new())
	assert_signal_emitted_with_parameters(manager, "stat_changed", [&"power"])
	assert_eq(manager.stat(&"power"), 10.0)


class Needed extends Component:
	signal pinged

	func _stats() -> Dictionary[StringName, float]:
		return { &"power": 10.0 }


class Needy extends Component:
	var starts: int = 0
	var stops: int = 0
	var frames: int = 0
	var physics_frames: int = 0
	var inputs: int = 0
	var pings: int = 0
	var heard: Array[StringName] = []

	func _requires() -> Array[Script]:
		return [Needed]

	func _start() -> void:
		starts += 1
		listen((find(Needed) as Needed).pinged, func() -> void: pings += 1)
		listen(manager.event_sent, _on_event)

	func _stop() -> void:
		stops += 1

	func _process(_delta: float) -> void:
		frames += 1

	func _physics_process(_delta: float) -> void:
		physics_frames += 1

	func _unhandled_input(_event: InputEvent) -> void:
		inputs += 1

	func _on_event(event: StringName, _ctx: EffectContext) -> void:
		heard.append(event)
