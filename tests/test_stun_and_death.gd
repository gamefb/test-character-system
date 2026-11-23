extends GutTest
## What stops a character acting: a status lists what it blocks. Stuns and death block
## everything, which stops the Brain; others block movement, weapons or abilities only.

const EX := "res://character_system/starter_pack/"


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
	return Health.find_on(node)


func physics_frames(count := 2) -> void:
	for i in count:
		await get_tree().physics_frame


func pull_trigger(who: Node) -> void:
	var brain := Brain.find_on(who)
	brain.press(&"primary")
	# A press counts from the next frame; process_frame comes just before nodes run.
	for i in 3:
		await get_tree().process_frame
	brain.release(&"primary")


func blocking(what: StringName) -> StatusData:
	var s := StatusData.new()
	s.blocks = [what]
	s.duration = 5.0
	return s


func test_a_stunned_character_cannot_act() -> void:
	var who: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var brain := Brain.find_on(who)
	var statuses := Statuses.find_on(who)
	var abilities := Abilities.find_on(who)
	brain.move_dir = Vector3.FORWARD
	brain.press(&"primary")
	var stunned: StatusData = blocking(&"everything")
	statuses.add(stunned)
	assert_true(brain.is_blocked())
	assert_eq(brain.move_dir, Vector3.ZERO)
	assert_false(brain.is_action_pressed(&"primary"))
	assert_eq(abilities.why_not(AbilityData.new()), &"blocked", "even when called from code")
	statuses.remove(stunned)
	assert_eq(brain.move_dir, Vector3.FORWARD)
	assert_true(brain.is_action_pressed(&"primary"), "a button still held counts again")


func test_a_dead_character_cannot_act_until_revived() -> void:
	var who: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var brain := Brain.find_on(who)
	var abilities := Abilities.find_on(who)
	brain.move_dir = Vector3.FORWARD
	health_of(who).change(-500.0)
	assert_true(brain.is_blocked())
	assert_eq(brain.move_dir, Vector3.ZERO)
	assert_false(abilities.use(AbilityData.new()))
	health_of(who).revive()
	assert_false(brain.is_blocked())
	assert_true(abilities.use(AbilityData.new()))
	assert_eq(health_of(who).death_status.id, &"dead", "death is a status, Dead by default")
	var downed := StatusData.new()
	downed.blocks = [&"weapons"]
	health_of(who).death_status = downed
	health_of(who).change(-500.0)
	assert_true(health_of(who).is_dead())
	assert_false(brain.is_blocked(), "a different death status decides what death stops")
	assert_true(Statuses.find_on(who).active.has(downed))
	health_of(who).revive()
	assert_false(Statuses.find_on(who).active.has(downed))
	health_of(who).death_status = null
	health_of(who).change(-500.0)
	assert_false(health_of(who).is_dead(), "no death status: nothing dies")
	health_of(who).change(30.0)
	assert_eq(health_of(who).current, 30.0, "and health goes on changing at zero")


func test_the_brain_answers_to_the_names_it_lists() -> void:
	var who: CharacterBody3D = make_character()
	var brain := Brain.find_on(who)
	var statuses := Statuses.find_on(who)
	brain.blocked_by = [&"sleep"]
	statuses.add(blocking(&"everything"))
	assert_false(brain.is_blocked(), "everything is only the default")
	statuses.add(blocking(&"sleep"))
	assert_true(brain.is_blocked())
	brain.blocked_by = []
	assert_false(brain.is_blocked(), "a brain that answers to nothing can't be stopped")


func test_blocks_are_counted_and_code_can_block_too() -> void:
	var who: CharacterBody3D = make_character()
	var brain := Brain.find_on(who)
	var statuses := Statuses.find_on(who)
	var manager := ComponentManager.of(who)
	var first: StatusData = blocking(&"everything")
	var second: StatusData = blocking(&"everything")
	statuses.add(first)
	statuses.add(second)
	statuses.remove(first)
	assert_true(brain.is_blocked(), "still blocked by the second status")
	statuses.remove(second)
	assert_false(brain.is_blocked())
	manager.block(&"everything")  # A cutscene, say.
	assert_true(brain.is_blocked())
	assert_true(ComponentManager.blocked(who, &"everything"))
	manager.unblock(&"everything")
	assert_false(brain.is_blocked())
	assert_false(ComponentManager.blocked(null, &"everything"), "safe without a manager")


func test_death_ends_timed_statuses_and_blocks_healing() -> void:
	var who: CharacterBody3D = make_character()
	var statuses := Statuses.find_on(who)
	var burning: StatusData = load(EX + "statuses/burning.tres")
	var passive := StatusData.new()
	statuses.add(burning)
	statuses.add(passive)
	health_of(who).change(-500.0)
	assert_false(statuses.active.has(burning), "Dead removes timed statuses")
	assert_true(statuses.active.has(passive), "passives stay for a revive")
	var heal := HealEffect.new()
	heal.amount = 50.0
	heal.apply(EffectContext.new(who, who))
	assert_true(health_of(who).is_dead(), "Dead blocks healing")
	health_of(who).change(50.0)
	assert_true(health_of(who).is_dead(), "and health doesn't change while dead")
	health_of(who).revive(40.0)
	assert_eq(health_of(who).current, 40.0)
	heal.apply(EffectContext.new(who, who))
	assert_eq(health_of(who).current, 90.0)


func test_a_stunned_character_stops_walking() -> void:
	var motor := CharacterMotor.new()
	motor.add_child(WalkMode.new())
	motor.add_child(AirMode.new())
	var who: CharacterBody3D = make_character(Vector3.ZERO, [motor])
	var floor_body := StaticBody3D.new()
	var slab := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	slab.shape = box
	floor_body.add_child(slab)
	floor_body.position.y = -0.5
	add_child_autofree(floor_body)
	var brain := Brain.find_on(who)
	brain.move_dir = Vector3.FORWARD
	await physics_frames(20)
	var walked: float = -who.position.z
	assert_gt(walked, 0.5, "walking")
	var statuses := Statuses.find_on(who)
	for what: StringName in [&"everything", &"movement"]:
		var status: StatusData = blocking(what)
		statuses.add(status)
		await physics_frames(2)
		var stopped_at: float = who.position.z
		await physics_frames(20)
		assert_almost_eq(who.position.z, stopped_at, 0.01, "%s: the motor reads no intent" % what)
		statuses.remove(status)
		await physics_frames(5)
		assert_lt(who.position.z, stopped_at - 0.1, "walking again")


func test_a_status_that_blocks_weapons_stops_the_trigger() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -6))
	var gear := Equipment.find_on(shooter)
	gear.equip(ItemInstance.new(load(EX + "items/rifle.tres")))
	Brain.find_on(shooter).aim_point = target.global_position + Vector3.UP
	var statuses := Statuses.find_on(shooter)
	var disarmed: StatusData = blocking(&"weapons")
	statuses.add(disarmed)
	await physics_frames()
	await pull_trigger(shooter)
	assert_eq(health_of(target).current, 100.0, "disarmed: no shot")
	statuses.remove(disarmed)
	await pull_trigger(shooter)
	assert_eq(health_of(target).current, 90.0)


func test_a_stunned_or_dead_wielder_cannot_fire() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -6))
	Equipment.find_on(shooter).equip(
			ItemInstance.new(load(EX + "items/rifle.tres")))
	Brain.find_on(shooter).aim_point = target.global_position + Vector3.UP
	var statuses := Statuses.find_on(shooter)
	var stunned: StatusData = blocking(&"everything")
	statuses.add(stunned)
	await physics_frames()
	await pull_trigger(shooter)
	assert_eq(health_of(target).current, 100.0, "stunned")
	statuses.remove(stunned)
	health_of(shooter).change(-500.0)
	await pull_trigger(shooter)
	assert_eq(health_of(target).current, 100.0, "dead")
	health_of(shooter).revive()
	await pull_trigger(shooter)
	assert_eq(health_of(target).current, 90.0)
