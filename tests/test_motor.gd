extends GutTest
## CharacterMotor with WalkMode, AirMode and DashMove: one mode at a time, and each press used
## once, so a floor jump and an air jump can't both happen on one press.

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


func test_double_jump() -> void:
	await _check_jumps(false)


func test_double_jump_air_mode_first() -> void:
	await _check_jumps(true)


func test_walks_at_move_speed_and_stats_change_it() -> void:
	var body := _make_character()
	var brain := Component.of(body, Brain) as Brain
	await _land(body)
	brain.move_dir = Vector3.RIGHT
	await _physics_frames(3)
	assert_almost_eq(body.velocity.x, 5.0, 0.01, "Walks at move_speed")

	var haste := StatModifier.new()
	haste.stat = &"move_speed"
	haste.mul = 1.5
	ComponentManager.of(body).add_modifier(haste)
	await _physics_frames(2)
	assert_almost_eq(body.velocity.x, 7.5, 0.01, "A status changes the speed")

	var boots := StatModifier.new()
	boots.stat = &"air_jumps"
	boots.add = 1.0
	ComponentManager.of(body).add_modifier(boots)
	await _tap(body, &"jump")
	assert_eq((_part(body, AirMode) as AirMode).jumps_left, 2, "and the air jumps")


func test_dash() -> void:
	var body := _make_character(false, true)
	var brain := Component.of(body, Brain) as Brain
	var dash := _part(body, DashMove) as DashMove
	await _land(body)

	brain.press(&"dash")
	await _physics_frames(2)
	assert_true(dash.active, "The dash request starts it")
	assert_almost_eq(_flat_speed(body), dash.speed, 0.01, "at dash speed")
	assert_almost_eq(body.velocity.z, -dash.speed, 0.01, "forward when standing still")
	brain.release(&"dash")
	await _physics_frames(20)
	assert_false(dash.active, "It ends after its duration")
	assert_almost_eq(_flat_speed(body), 0.0, 0.01, "and walking takes over again")

	brain.press(&"dash")
	await _physics_frames(2)
	brain.release(&"dash")
	assert_false(dash.active, "A dash during the cooldown does nothing")
	await _physics_frames(30)

	await _tap(body, &"jump")
	await _physics_frames(5)
	brain.move_dir = Vector3.RIGHT
	brain.press(&"dash")
	await _physics_frames(2)
	assert_true(dash.active, "It works in the air too")
	assert_almost_eq(body.velocity.x, dash.speed, 0.01, "the way it's moving")
	assert_almost_eq(body.velocity.y, 0.0, 0.01, "with no gravity")
	var height := body.global_position.y
	await _physics_frames(5)
	assert_almost_eq(body.global_position.y, height, 0.01, "so it doesn't fall")
	brain.release(&"dash")


func test_actions_can_be_changed() -> void:
	var body := _make_character()
	var motor := _motor_of(body)
	(_part(body, WalkMode) as WalkMode).jump_action = &"hop"
	await _land(body)
	await _tap(body, &"jump")
	assert_is(motor.mode, WalkMode, "The old action no longer jumps")
	await _tap(body, &"hop")
	assert_is(motor.mode, AirMode, "The new one does")


func test_knockback_pushes_motor_characters() -> void:
	var body := _make_character()
	await _land(body)
	var source := Node3D.new()
	add_child_autofree(source)
	source.global_position = Vector3(0.0, 1.0, 5.0)
	KnockbackEffect.new().apply(EffectContext.new(source, body))
	await _physics_frames(2)
	assert_lt(body.velocity.z, -4.0, "Pushed away from the source")
	assert_is(_motor_of(body).mode, AirMode, "and lifted off the floor")
	await _physics_frames(60)
	assert_almost_eq(body.velocity.z, 0.0, 0.1, "The push fades")


func test_modes_can_be_removed_and_added() -> void:
	var body := _make_character()
	var motor := _motor_of(body)
	var air := _part(body, AirMode) as AirMode
	await _land(body)
	await _tap(body, &"jump")
	assert_eq(motor.mode, air, "In the air")

	motor.remove_child(air)
	await _physics_frames(1)
	assert_is(motor.mode, WalkMode, "Removing the current mode goes back to the start mode")
	await _land(body)
	await _tap(body, &"jump")
	await _physics_frames(10)
	var before: float = body.velocity.y
	await _tap(body, &"jump")
	assert_lt(body.velocity.y, before, "With no air mode there's no air jump")

	await _land(body)
	motor.add_child(air)
	await _tap(body, &"jump")
	assert_eq(motor.mode, air, "Adding it back during play works")


func test_signals_and_switching_from_code() -> void:
	var body := _make_character(false, true)
	var motor := _motor_of(body)
	var walk := _part(body, WalkMode) as WalkMode
	var air := _part(body, AirMode) as AirMode
	var dash := _part(body, DashMove) as DashMove
	await _land(body)
	watch_signals(motor)
	watch_signals(dash)
	await _tap(body, &"jump")
	assert_signal_emitted_with_parameters(motor, "mode_changed", [walk, air])

	await _land(body)
	dash.active = true
	assert_signal_emitted(dash, "started", "A move can be started from code")
	await _physics_frames(20)
	assert_signal_emitted(dash, "finished", "and says when it's done")

	motor.mode = air
	assert_eq(motor.mode, air, "Modes can be switched from code")
	await _physics_frames(2)
	assert_eq(motor.mode, walk, "and hand back as usual")


func test_no_air_jumps() -> void:
	var body := _make_character()
	var air := _part(body, AirMode) as AirMode
	air.air_jumps = 0
	await _land(body)
	await _tap(body, &"jump")
	assert_is(_motor_of(body).mode, AirMode, "The floor jump still works")
	await _physics_frames(5)
	var before: float = body.velocity.y
	await _tap(body, &"jump")
	assert_lt(body.velocity.y, before, "but with air_jumps 0 a press in the air does nothing")


func test_parts_need_a_motor_parent() -> void:
	var stray := AirMode.new()
	add_child_autofree(stray)
	assert_eq(stray._get_configuration_warnings().size(), 1, "A mode outside a motor warns")
	var body := _make_character()
	assert_eq(_part(body, AirMode)._get_configuration_warnings().size(), 0, "One under it doesn't")


func test_a_press_is_used_once() -> void:
	var body := _make_character(false, true)
	var dash := _part(body, DashMove) as DashMove
	dash.action = &"jump"
	await _land(body)
	await _tap(body, &"jump")
	assert_is(_motor_of(body).mode, AirMode, "Walking used the press to jump")
	assert_false(dash.active, "so a dash on the same action doesn't also start")


func test_statuses_block_modes_and_moves() -> void:
	var body := _make_character(false, true)
	var motor := _motor_of(body)
	var air := _part(body, AirMode) as AirMode
	var dash := _part(body, DashMove) as DashMove
	var statuses := Component.of(body, Statuses) as Statuses
	dash.blocked_by_tags = [&"rooted"]
	air.blocked_by_tags = [&"grounded"]
	var rooted: StatusData = load("res://character_system/examples/statuses/rooted.tres")
	var grounded := _tagged(&"grounded")
	await _land(body)

	statuses.add(rooted)
	await _tap(body, &"dash")
	assert_false(dash.active, "Rooted stops a dash with rooted in its tags")
	await _tap(body, &"jump")
	assert_is(motor.mode, WalkMode, "and the example status cancels jumps through jump_velocity")
	statuses.remove(rooted)
	await _tap(body, &"dash")
	assert_true(dash.active, "Once it's gone, the dash works")
	statuses.add(rooted)
	await _physics_frames(1)
	assert_false(dash.active, "and a running dash ends when rooted")
	statuses.remove(rooted)
	await _physics_frames(40)

	await _tap(body, &"jump")
	assert_is(motor.mode, AirMode, "Jumping")
	statuses.add(grounded)
	await _physics_frames(1)
	assert_is(motor.mode, WalkMode, "A blocked mode in charge hands back to the start mode")
	await _physics_frames(10)
	assert_is(motor.mode, WalkMode, "and can't take over again while blocked")
	statuses.remove(grounded)
	await _physics_frames(1)
	assert_is(motor.mode, AirMode, "until the status is gone")


func test_motor_sends_events() -> void:
	var body := _make_character(false, true)
	var log := EventLog.new()
	body.add_child(log)
	await _land(body)
	assert_eq(log.events.front(), &"walk_mode_exited",
			"Starting in a mode sends nothing; the first event is dropping onto the floor")
	log.events.clear()

	await _tap(body, &"jump")
	await _land(body)
	assert_eq(log.events, [&"walk_mode_exited", &"air_mode_entered", &"air_mode_exited",
			&"walk_mode_entered"] as Array[StringName], "A jump and a landing")

	log.events.clear()
	await _tap(body, &"dash")
	await _physics_frames(20)
	assert_eq(log.events, [&"dash_move_started", &"dash_move_finished"] as Array[StringName],
			"A dash")

	var stomp := StatusData.new()
	stomp.id = &"stomp"
	var trigger := StatusTrigger.new()
	trigger.event = &"walk_mode_entered"
	var damage := DamageEffect.new()
	damage.amount = 5.0
	trigger.effects = [damage]
	stomp.triggers = [trigger]
	(Component.of(body, Statuses) as Statuses).add(stomp)
	var health := Component.of(body, Health) as Health
	var before := health.current
	await _tap(body, &"jump")
	await _land(body)
	assert_almost_eq(health.current, before - 5.0, 0.01, "Status triggers react to landing")


func test_moves_have_a_cooldown() -> void:
	var body := _make_character(false, true)
	var dash := _part(body, DashMove) as DashMove
	var catcher := PressCatcher.new()
	_motor_of(body).add_child(catcher)
	await _land(body)

	await _tap(body, &"dash")
	assert_true(dash.active, "The first dash starts")
	assert_eq(catcher.caught, 0, "and uses the press")
	assert_between(dash.cooldown_left(), 0.01, dash.cooldown, "Its cooldown is counting")
	await _physics_frames(20)
	assert_false(dash.active, "It ends")
	await _tap(body, &"dash")
	assert_false(dash.active, "During the cooldown a press doesn't start it")
	assert_eq(catcher.caught, 1, "and is left for the next move")
	dash.active = true
	assert_false(dash.active, "Starting it from code waits for the cooldown too")
	await _physics_frames(30)
	assert_eq(dash.cooldown_left(), 0.0, "The cooldown runs out")
	await _tap(body, &"dash")
	assert_true(dash.active, "and it dashes again")



## A capsule character standing on the floor, with a motor and its modes. With
## [param air_first], AirMode comes before WalkMode, to show the order doesn't matter.
func _make_character(air_first := false, with_dash := false) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	body.add_child(shape)
	body.add_child(ComponentManager.new())
	body.add_child(Brain.new())
	body.add_child(Statuses.new())
	body.add_child(Health.new())
	var motor := CharacterMotor.new()
	var parts: Array[MotorNode] = [WalkMode.new(), AirMode.new()]
	if air_first:
		parts.reverse()
	if with_dash:
		parts.append(DashMove.new())
	for part in parts:
		motor.add_child(part)
	body.add_child(motor)
	body.position = Vector3(0.0, 1.05, 0.0)
	add_child_autofree(body)
	return body


func _physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _tap(body: CharacterBody3D, action: StringName) -> void:
	var brain := Component.of(body, Brain) as Brain
	brain.press(action)
	await _physics_frames(3)
	brain.release(action)
	await _physics_frames(2)


func _land(body: CharacterBody3D) -> void:
	for i in 240:
		await get_tree().physics_frame
		if body.is_on_floor():
			await get_tree().physics_frame  # Let the air mode hand back to walking.
			return


func _motor_of(body: CharacterBody3D) -> CharacterMotor:
	return Component.of(body, CharacterMotor) as CharacterMotor


## The first node under the motor that is a [param type].
func _part(body: CharacterBody3D, type: Script) -> Node:
	for node in _motor_of(body).get_children():
		if is_instance_of(node, type):
			return node
	return null


func _flat_speed(body: CharacterBody3D) -> float:
	return Vector2(body.velocity.x, body.velocity.z).length()


func _check_jumps(air_first: bool) -> void:
	var body := _make_character(air_first)
	var motor := _motor_of(body)
	var air := _part(body, AirMode) as AirMode
	await _land(body)
	assert_is(motor.mode, WalkMode, "Starts walking")

	await _tap(body, &"jump")
	assert_is(motor.mode, AirMode, "The first press jumps from the floor")
	assert_eq(air.jumps_left, 1, "and doesn't use the air jump")

	await _physics_frames(10)
	var before: float = body.velocity.y
	await _tap(body, &"jump")
	assert_eq(air.jumps_left, 0, "The second press uses the air jump")
	assert_gt(body.velocity.y, before, "and goes up again")

	await _physics_frames(10)
	before = body.velocity.y
	await _tap(body, &"jump")
	assert_lt(body.velocity.y, before, "A third press does nothing")

	await _land(body)
	assert_is(motor.mode, WalkMode, "Landing goes back to walking")
	await _tap(body, &"jump")
	assert_eq(air.jumps_left, 1, "and the next take-off refills the air jump")


## A status with [param tag] that lasts until removed.
func _tagged(tag: StringName) -> StatusData:
	var data := StatusData.new()
	data.id = tag
	data.tags = [tag]
	return data


## Records the events its host receives.
class EventLog extends Component:
	var events: Array[StringName] = []

	func _on_event(event: StringName, ctx: EffectContext) -> void:
		if (
				event.ends_with("_entered") or event.ends_with("_exited")
				or event.ends_with("_started") or event.ends_with("_finished")
		):
			events.append(event)
			assert(ctx != null)


## A move after the dash that counts the dash presses left for it.
class PressCatcher extends LayeredMove:
	var caught := 0

	func _can_start() -> bool:
		if motor.consume_action(&"dash"):
			caught += 1
		return false
