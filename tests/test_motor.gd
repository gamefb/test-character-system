extends GutTest
## CharacterMotor with WalkMode, AirMode and DashMove: one mode at a time, requests used up once,
## so a floor jump and an air jump can't both happen on one press.

var floor_body: StaticBody3D


func before_each() -> void:
	floor_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(200.0, 1.0, 200.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	add_child_autofree(floor_body)


## A capsule character standing on the floor. With [param modes_first], the modes come before
## the motor in the tree, to show the order doesn't matter.
func make_character(modes_first := false, with_dash := false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	body.add_child(ComponentManager.new())
	body.add_child(Brain.new())
	var parts: Array[Component] = [CharacterMotor.new(), WalkMode.new(), AirMode.new()]
	if with_dash:
		parts.append(DashMove.new())
	if modes_first:
		parts.reverse()
	for part in parts:
		body.add_child(part)
	body.position = Vector3(0.0, 1.05, 0.0)
	add_child_autofree(body)
	return body


func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func tap(body: CharacterBody3D, action: StringName) -> void:
	var brain := Component.of(body, Brain) as Brain
	brain.press(action)
	await physics_frames(3)
	brain.release(action)
	await physics_frames(2)


func land(body: CharacterBody3D) -> void:
	for i in 240:
		await get_tree().physics_frame
		if body.is_on_floor():
			await get_tree().physics_frame  # Let the air mode hand back to walking.
			return


func motor_of(body: CharacterBody3D) -> CharacterMotor:
	return Component.of(body, CharacterMotor) as CharacterMotor


func flat_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func check_jumps(modes_first: bool) -> void:
	var body := make_character(modes_first)
	var motor := motor_of(body)
	var air := Component.of(body, AirMode) as AirMode
	await land(body)
	assert_is(motor.mode, WalkMode, "Starts walking")

	await tap(body, &"jump")
	assert_is(motor.mode, AirMode, "The first press jumps from the floor")
	assert_eq(air.jumps_left, 1, "and doesn't use the air jump")

	await physics_frames(10)
	var before: float = body.velocity.y
	await tap(body, &"jump")
	assert_eq(air.jumps_left, 0, "The second press uses the air jump")
	assert_gt(body.velocity.y, before, "and goes up again")

	await physics_frames(10)
	before = body.velocity.y
	await tap(body, &"jump")
	assert_lt(body.velocity.y, before, "A third press does nothing")

	await land(body)
	assert_is(motor.mode, WalkMode, "Landing goes back to walking")
	await tap(body, &"jump")
	assert_eq(air.jumps_left, 1, "and the next take-off refills the air jump")


func test_double_jump_motor_first() -> void:
	await check_jumps(false)


func test_double_jump_modes_first() -> void:
	await check_jumps(true)


func test_walks_at_move_speed_and_stats_change_it() -> void:
	var body := make_character()
	var brain := Component.of(body, Brain) as Brain
	await land(body)
	brain.move_dir = Vector3.RIGHT
	await physics_frames(3)
	assert_almost_eq(body.velocity.x, 5.0, 0.01, "Walks at move_speed")

	var haste := StatModifier.new()
	haste.stat = &"move_speed"
	haste.mul = 1.5
	ComponentManager.of(body).add_modifier(haste)
	await physics_frames(2)
	assert_almost_eq(body.velocity.x, 7.5, 0.01, "A status changes the speed")

	var boots := StatModifier.new()
	boots.stat = &"air_jumps"
	boots.add = 1.0
	ComponentManager.of(body).add_modifier(boots)
	await tap(body, &"jump")
	assert_eq((Component.of(body, AirMode) as AirMode).jumps_left, 2, "and the air jumps")


func test_dash() -> void:
	var body := make_character(false, true)
	var brain := Component.of(body, Brain) as Brain
	var dash := Component.of(body, DashMove) as DashMove
	await land(body)

	brain.press(&"dash")
	await physics_frames(2)
	assert_true(dash.active, "The dash request starts it")
	assert_almost_eq(flat_speed(body), dash.speed, 0.01, "at dash speed")
	assert_almost_eq(body.velocity.z, -dash.speed, 0.01, "forward when standing still")
	brain.release(&"dash")
	await physics_frames(20)
	assert_false(dash.active, "It ends after its duration")
	assert_almost_eq(flat_speed(body), 0.0, 0.01, "and walking takes over again")

	brain.press(&"dash")
	await physics_frames(2)
	brain.release(&"dash")
	assert_false(dash.active, "A dash during the cooldown does nothing")
	await physics_frames(30)

	await tap(body, &"jump")
	await physics_frames(5)
	brain.move_dir = Vector3.RIGHT
	brain.press(&"dash")
	await physics_frames(2)
	assert_true(dash.active, "It works in the air too")
	assert_almost_eq(body.velocity.x, dash.speed, 0.01, "the way it's moving")
	assert_almost_eq(body.velocity.y, 0.0, 0.01, "with no gravity")
	var height := body.global_position.y
	await physics_frames(5)
	assert_almost_eq(body.global_position.y, height, 0.01, "so it doesn't fall")
	brain.release(&"dash")


func test_actions_can_be_changed() -> void:
	var body := make_character()
	var motor := motor_of(body)
	(Component.of(body, WalkMode) as WalkMode).jump_action = &"hop"
	await land(body)
	await tap(body, &"jump")
	assert_is(motor.mode, WalkMode, "The old action no longer jumps")
	await tap(body, &"hop")
	assert_is(motor.mode, AirMode, "The new one does")


func test_knockback_pushes_motor_characters() -> void:
	var body := make_character()
	await land(body)
	var source := Node3D.new()
	add_child_autofree(source)
	source.global_position = Vector3(0.0, 1.0, 5.0)
	KnockbackEffect.new().apply(EffectContext.new(source, body))
	await physics_frames(2)
	assert_lt(body.velocity.z, -4.0, "Pushed away from the source")
	assert_is(motor_of(body).mode, AirMode, "and lifted off the floor")
	await physics_frames(60)
	assert_almost_eq(body.velocity.z, 0.0, 0.1, "The push fades")


func test_modes_can_be_removed_and_added() -> void:
	var body := make_character()
	var motor := motor_of(body)
	var air := Component.of(body, AirMode) as AirMode
	await land(body)
	await tap(body, &"jump")
	assert_eq(motor.mode, air, "In the air")

	body.remove_child(air)
	await physics_frames(1)
	assert_is(motor.mode, WalkMode, "Removing the current mode goes back to the start mode")
	await land(body)
	await tap(body, &"jump")
	await physics_frames(10)
	var before: float = body.velocity.y
	await tap(body, &"jump")
	assert_lt(body.velocity.y, before, "With no air mode there's no air jump")

	await land(body)
	body.add_child(air)
	await tap(body, &"jump")
	assert_eq(motor.mode, air, "Adding it back during play works")
	air.free()


## A new feature written only against the motor: while falling with jump held, fall slowly.
## Nothing else had to change, and it can't clash with the double jump over the press.
class Glide extends LayeredMove:
	var fall_speed := 1.0

	func _can_start() -> bool:
		return motor.mode is AirMode and motor.brain.is_action_pressed(&"jump") \
				and body.velocity.y < 0.0

	func _physics_update(_delta: float) -> void:
		body.velocity.y = maxf(body.velocity.y, -fall_speed)
		if not motor.brain.is_action_pressed(&"jump") or not motor.mode is AirMode:
			active = false


func test_new_moves_need_no_changes_elsewhere() -> void:
	var body := make_character()
	var glide := Glide.new()
	body.add_child(glide)
	var brain := Component.of(body, Brain) as Brain
	var air := Component.of(body, AirMode) as AirMode
	await land(body)

	await tap(body, &"jump")
	await physics_frames(40)
	assert_lt(body.velocity.y, -1.0, "Falling normally with jump released")
	brain.press(&"jump")
	await physics_frames(3)
	assert_eq(air.jumps_left, 0, "The press still double jumps")
	await physics_frames(40)
	assert_true(glide.active, "then holding it glides on the way down")
	assert_almost_eq(body.velocity.y, -glide.fall_speed, 0.01, "at the glide speed")
	brain.release(&"jump")
	await physics_frames(2)
	assert_false(glide.active, "Letting go stops gliding")


func test_signals_and_switching_from_code() -> void:
	var body := make_character(false, true)
	var motor := motor_of(body)
	var walk := Component.of(body, WalkMode) as WalkMode
	var air := Component.of(body, AirMode) as AirMode
	var dash := Component.of(body, DashMove) as DashMove
	await land(body)
	watch_signals(motor)
	watch_signals(dash)
	await tap(body, &"jump")
	assert_signal_emitted_with_parameters(motor, "mode_changed", [walk, air])

	await land(body)
	dash.active = true
	assert_signal_emitted(dash, "started", "A move can be started from code")
	await physics_frames(20)
	assert_signal_emitted(dash, "finished", "and says when it's done")

	motor.mode = air
	assert_eq(motor.mode, air, "Modes can be switched from code")
	await physics_frames(2)
	assert_eq(motor.mode, walk, "and hand back as usual")
