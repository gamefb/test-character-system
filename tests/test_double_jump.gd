extends GutTest
## DoubleJump: one jump from the floor plus air_jumps in the air, refilled on landing, whatever
## the node order, and changed by statuses through the air_jumps stat.

var floor_body: StaticBody3D


func before_each() -> void:
	floor_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)


## A capsule character standing on the floor. With [param jump_first], DoubleJump comes before
## Movement in the tree, so it runs first each physics frame.
func make_character(jump_first: bool) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	body.add_child(ComponentManager.new())
	body.add_child(Brain.new())
	var parts: Array[Component] = [Movement.new(), DoubleJump.new()]
	if jump_first:
		parts.reverse()
	for part in parts:
		body.add_child(part)
	body.position = Vector3(0.0, 1.05, 0.0)
	add_child_autofree(body)
	return body


func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Presses and releases jump, then lets a few physics frames run.
func tap_jump(body: CharacterBody3D) -> void:
	var brain := Component.of(body, Brain) as Brain
	brain.press(&"jump")
	await physics_frames(3)
	brain.release(&"jump")
	await physics_frames(2)


func land(body: CharacterBody3D) -> void:
	for i in 240:
		await get_tree().physics_frame
		if body.is_on_floor():
			return


func check_jumps(jump_first: bool) -> void:
	var body: CharacterBody3D = make_character(jump_first)
	var double := Component.of(body, DoubleJump) as DoubleJump
	await land(body)
	await physics_frames(1)
	assert_true(body.is_on_floor(), "Starts on the floor")
	assert_eq(double.air_jumps_left(), 1, "One air jump while standing")

	await tap_jump(body)
	assert_false(body.is_on_floor(), "The first press jumps from the floor")
	assert_eq(double.air_jumps_left(), 1, "The floor jump doesn't use the air jump")

	await physics_frames(10)
	var before: float = body.velocity.y
	await tap_jump(body)
	assert_eq(double.air_jumps_left(), 0, "The second press uses the air jump")
	assert_gt(body.velocity.y, before, "and goes up again")

	await physics_frames(10)
	before = body.velocity.y
	await tap_jump(body)
	assert_lt(body.velocity.y, before, "A third press does nothing")

	await land(body)
	await physics_frames(1)
	assert_eq(double.air_jumps_left(), 1, "Landing gives the air jump back")


func test_double_jump_after_movement() -> void:
	await check_jumps(false)


func test_double_jump_before_movement() -> void:
	await check_jumps(true)


func test_statuses_change_air_jumps() -> void:
	var body: CharacterBody3D = make_character(false)
	var double := Component.of(body, DoubleJump) as DoubleJump
	var extra := StatModifier.new()
	extra.stat = &"air_jumps"
	extra.add = 1.0
	ComponentManager.of(body).add_modifier(extra)
	await land(body)
	await physics_frames(1)
	assert_eq(double.air_jumps_left(), 2, "A status adding 1 makes it a triple jump")

	ComponentManager.of(body).remove_modifier(extra)
	double.air_jumps = 0
	await physics_frames(1)
	assert_eq(double.air_jumps_left(), 0, "air_jumps 0 means no air jumps")
	await tap_jump(body)
	assert_false(body.is_on_floor(), "The floor jump still works")
	var before: float = body.velocity.y
	await tap_jump(body)
	assert_lt(body.velocity.y, before, "but a press in the air does nothing")
