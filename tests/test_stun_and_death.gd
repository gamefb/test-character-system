extends GutTest
## What stops a character acting: stuns and death stop its Brain, and single tags stop one
## weapon or ability.

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


func test_a_stunned_character_cannot_act() -> void:
	var who: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var brain := Component.of(who, Brain) as Brain
	var statuses := Component.of(who, Statuses) as Statuses
	var abilities := Component.of(who, Abilities) as Abilities
	brain.move_dir = Vector3.FORWARD
	brain.press(&"primary")
	var stunned: StatusData = tagged(&"stunned")
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
	var brain := Component.of(who, Brain) as Brain
	var abilities := Component.of(who, Abilities) as Abilities
	brain.move_dir = Vector3.FORWARD
	health_of(who).change(-500.0)
	assert_true(brain.is_blocked())
	assert_eq(brain.move_dir, Vector3.ZERO)
	assert_false(abilities.use(AbilityData.new()))
	health_of(who).revive()
	assert_false(brain.is_blocked())
	assert_true(abilities.use(AbilityData.new()))
	brain.acts_while_dead = true
	health_of(who).change(-500.0)
	assert_false(brain.is_blocked(), "unless the brain is told to carry on")


func test_the_brain_can_stop_on_other_tags() -> void:
	var who: CharacterBody3D = make_character()
	var brain := Component.of(who, Brain) as Brain
	var statuses := Component.of(who, Statuses) as Statuses
	brain.blocked_by_tags = [&"frozen", &"asleep"]
	statuses.add(tagged(&"stunned"))
	assert_false(brain.is_blocked(), "stunned is only the default")
	statuses.add(tagged(&"asleep"))
	assert_true(brain.is_blocked())


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
	var brain := Component.of(who, Brain) as Brain
	brain.move_dir = Vector3.FORWARD
	await physics_frames(20)
	var walked: float = -who.position.z
	assert_gt(walked, 0.5, "walking")
	(Component.of(who, Statuses) as Statuses).add(tagged(&"stunned"))
	await physics_frames(2)
	var stopped_at: float = who.position.z
	await physics_frames(20)
	assert_almost_eq(who.position.z, stopped_at, 0.01, "the motor reads no intent")


func test_a_status_tag_stops_the_trigger() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -6))
	var gear := Component.of(shooter, Equipment) as Equipment
	gear.equip(ItemInstance.new(load(EX + "items/rifle.tres")))
	(Component.of(gear.node_in(&"weapon"), Trigger) as Trigger).blocked_by_tags = [&"disarmed"]
	(Component.of(shooter, Brain) as Brain).aim_point = target.global_position + Vector3.UP
	var statuses := Component.of(shooter, Statuses) as Statuses
	var disarmed: StatusData = tagged(&"disarmed")
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
	(Component.of(shooter, Equipment) as Equipment).equip(
			ItemInstance.new(load(EX + "items/rifle.tres")))
	(Component.of(shooter, Brain) as Brain).aim_point = target.global_position + Vector3.UP
	var statuses := Component.of(shooter, Statuses) as Statuses
	var stunned: StatusData = tagged(&"stunned")
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
