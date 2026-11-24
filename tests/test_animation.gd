extends GutTest
## Wind-ups, swings that stay live and follow the blade, and animations that play along.

const EX := "res://character_system/starter_pack/"


func make_character(position := Vector3.ZERO, extra: Array[Node] = []) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.position = position
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 1.0
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, 1, 0)
	var gear := Equipment.new()
	gear.sockets = { &"weapon": ^"../Hand" }
	for node: Node in [
		shape, hand, ComponentManager.new(), Health.new(), Statuses.new(), Brain.new(), gear,
	] + extra:
		body.add_child(node)
	add_child_autofree(body)
	return body


## A sword: the swing is a box half a metre across, one and a half metres out from the hand.
func sword(wind_up: float, active: float, extra: Array[Node] = []) -> ItemData:
	var root := Node3D.new()
	var trigger := Trigger.new()
	trigger.fire_rate = 1.0
	trigger.wind_up = wind_up
	var sweep := MeleeSweep.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	sweep.shape = box
	sweep.offset = Vector3(0, 0, -1.5)
	sweep.active = active
	sweep.effects = [DamageEffect.new()]
	for node: Node in [ComponentManager.new(), trigger, sweep] + extra:
		root.add_child(node)
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var data := ItemData.new()
	data.id = &"sword"
	data.slot = &"weapon"
	data.scene = scene
	return data


## Presses as a player's input does: it counts in the frame it arrives. Returns that frame.
func press(who: Node, action: StringName = &"primary") -> int:
	await get_tree().process_frame
	Brain.find_on(who)._press(action, Engine.get_process_frames())
	return Engine.get_process_frames()


## Seconds of game time until the target is next hurt, or -1.0 if it isn't within the limit.
func seconds_until_hurt(target: Node, limit: float = 0.6) -> float:
	var before: float = Health.find_on(target).current
	var waited: float = 0.0
	while waited < limit:
		await get_tree().process_frame
		if Health.find_on(target).current < before:
			return waited
		waited += get_process_delta_time()
	return -1.0


## The events the character hears from now on, in order, with their contexts beside them.
func hear(who: Node, events: Array[StringName], contexts: Array[EffectContext] = []) -> Array:
	var heard: Array[StringName] = []
	for event in events:
		ComponentManager.of(who).event(event).connect(func(ctx: EffectContext) -> void:
			heard.append(event)
			contexts.append(ctx))
	return heard


## An AnimationPlayer on the character with one clip, whose "hit" marker is at the given time.
func animated(who: Node, clip_name: StringName, hit_at: float) -> AnimationPlayer:
	var clip := Animation.new()
	clip.length = 1.0
	clip.add_marker(&"hit", hit_at)
	var library := AnimationLibrary.new()
	library.add_animation(clip_name, clip)
	var player := AnimationPlayer.new()
	who.add_child(player)
	player.add_animation_library(&"", library)
	return player


func animator_on(who: Node, player: AnimationPlayer, table: Dictionary) -> Animator:
	var animator := Animator.new()
	animator.player = player
	animator.animations.assign(table)
	who.add_child(animator)
	return animator


func test_a_rifle_still_hits_in_the_frame_of_the_press() -> void:
	var shooter: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -6))
	var rifle: ItemData = load(EX + "items/rifle.tres")
	Equipment.find_on(shooter).equip(ItemInstance.new(rifle))
	Brain.find_on(shooter).aim_point = target.global_position + Vector3.UP
	await get_tree().physics_frame
	var contexts: Array[EffectContext] = []
	var heard: Array = hear(shooter, [&"weapon_started", &"weapon_fired"], contexts)
	var pressed_on: int = await press(shooter)
	# The press is recorded before the frame's processing; one frame later it has all run.
	await get_tree().process_frame
	assert_eq(Health.find_on(target).current, 90.0)
	assert_eq(Engine.get_process_frames() - pressed_on, 1, "it ran in the frame of the press")
	assert_eq(heard, [&"weapon_started", &"weapon_fired"])
	assert_eq(contexts[0].origin, rifle, "the wielder is told which item")
	assert_eq(contexts[0].duration, 0.0)


func test_an_instant_swing_still_hits_in_the_frame_of_the_press() -> void:
	var swinger: CharacterBody3D = make_character()
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.0, 0.0)))
	await get_tree().physics_frame
	var pressed_on: int = await press(swinger)
	await get_tree().process_frame
	assert_eq(Health.find_on(front).current, 90.0)
	assert_eq(Engine.get_process_frames() - pressed_on, 1)


func test_a_wind_up_delays_the_hit_by_its_length() -> void:
	var swinger: CharacterBody3D = make_character()
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.2, 0.0)))
	await get_tree().physics_frame
	var contexts: Array[EffectContext] = []
	hear(swinger, [&"weapon_started"], contexts)
	await press(swinger)
	var waited: float = await seconds_until_hurt(front)
	# At 60 frames a second this is 12 frames exactly; a frame either way at other rates.
	assert_almost_eq(waited, 0.2, 0.02)
	assert_eq(contexts[0].duration, 0.2, "the start says how long the wind-up is")


func test_a_stun_in_the_wind_up_cancels_the_shot_and_returns_the_round() -> void:
	var magazine := Magazine.new()
	magazine.capacity = 3
	var swinger: CharacterBody3D = make_character()
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.2, 0.0, [magazine])))
	await get_tree().physics_frame
	var heard: Array = hear(swinger, [&"weapon_started", &"weapon_fired", &"weapon_interrupted"])
	await press(swinger)
	await get_tree().process_frame
	await get_tree().process_frame
	var loaded := Magazine.find_on(Equipment.find_on(swinger).node_in(&"weapon"))
	assert_eq(loaded.rounds, 2, "taken at the press")
	Statuses.find_on(swinger).add(load(EX + "statuses/stunned.tres"))
	assert_eq(await seconds_until_hurt(front, 0.4), -1.0)
	assert_eq(loaded.rounds, 3, "and given back")
	assert_eq(heard, [&"weapon_started", &"weapon_interrupted"])


func test_putting_the_weapon_away_in_the_wind_up_cancels_the_shot() -> void:
	var swinger: CharacterBody3D = make_character()
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.2, 0.0)))
	await get_tree().physics_frame
	var heard: Array = hear(swinger, [&"weapon_fired", &"weapon_interrupted"])
	await press(swinger)
	await get_tree().process_frame
	await get_tree().process_frame
	Equipment.find_on(swinger).unequip(&"weapon")
	assert_eq(await seconds_until_hurt(front, 0.4), -1.0)
	assert_eq(heard, [&"weapon_interrupted"])


func test_a_live_swing_follows_the_hand_and_hits_each_character_once() -> void:
	var swinger: CharacterBody3D = make_character()
	# To the left: outside the swing when it starts, inside as the hand turns.
	var left: CharacterBody3D = make_character(Vector3(-1.6, 0, 0))
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.0, 0.3)))
	var hand: Node3D = swinger.get_node("Hand")
	await get_tree().physics_frame
	await press(swinger)
	for i in 18:  # A quarter turn to the left over the 0.3 s the swing is live.
		await get_tree().physics_frame
		hand.rotation.y = deg_to_rad(5.0 * (i + 1))
	await get_tree().physics_frame
	assert_eq(Health.find_on(front).current, 90.0, "inside for many checks, hit once")
	assert_eq(Health.find_on(left).current, 90.0, "reached as the hand turned")


func test_a_swing_with_no_live_time_only_reaches_who_is_there_at_the_shot() -> void:
	var swinger: CharacterBody3D = make_character()
	var left: CharacterBody3D = make_character(Vector3(-1.6, 0, 0))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.0, 0.0)))
	var hand: Node3D = swinger.get_node("Hand")
	await get_tree().physics_frame
	await press(swinger)
	for i in 18:
		await get_tree().physics_frame
		hand.rotation.y = deg_to_rad(5.0 * (i + 1))
	assert_eq(Health.find_on(left).current, 100.0)


func test_a_fast_blade_cannot_pass_through_a_thin_target() -> void:
	var swinger: CharacterBody3D = make_character()
	# Half-way round a turn the hand makes in a single physics frame.
	var between: CharacterBody3D = make_character(Vector3(-1.13, 0, -1.13))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.0, 0.2)))
	var hand: Node3D = swinger.get_node("Hand")
	hand.rotation.y = deg_to_rad(-20.0)
	await get_tree().physics_frame
	await press(swinger)
	await get_tree().physics_frame
	hand.rotation.y = deg_to_rad(110.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert_eq(Health.find_on(between).current, 90.0, "caught between the two positions")


func test_a_stun_ends_a_live_swing() -> void:
	var swinger: CharacterBody3D = make_character()
	var left: CharacterBody3D = make_character(Vector3(-1.6, 0, 0))
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.0, 0.3)))
	var hand: Node3D = swinger.get_node("Hand")
	await get_tree().physics_frame
	await press(swinger)
	await get_tree().physics_frame
	Statuses.find_on(swinger).add(load(EX + "statuses/stunned.tres"))
	for i in 18:
		await get_tree().physics_frame
		hand.rotation.y = deg_to_rad(5.0 * (i + 1))
	assert_eq(Health.find_on(left).current, 100.0)


func test_the_animator_plays_the_clip_so_its_marker_lands_on_the_hit() -> void:
	var swinger: CharacterBody3D = make_character()
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	# A clip whose blade connects at 0.5 s, on a sword that winds up for 0.25 s.
	var player: AnimationPlayer = animated(swinger, &"swing", 0.5)
	animator_on(swinger, player, { &"weapon_started": &"swing" })
	Equipment.find_on(swinger).equip(ItemInstance.new(sword(0.25, 0.0)))
	await get_tree().physics_frame
	var at_hit: Array[float] = []
	ComponentManager.of(swinger).event(&"weapon_fired").connect(
			func(_ctx: EffectContext) -> void: at_hit.append(player.current_animation_position))
	await press(swinger)
	await get_tree().process_frame
	assert_eq(player.current_animation, "swing", "started in the frame of the press")
	assert_almost_eq(player.get_playing_speed(), 2.0, 0.001, "0.5 s of clip in 0.25 s")
	assert_almost_eq(await seconds_until_hurt(front), 0.25, 0.03)
	assert_almost_eq(at_hit[0], 0.5, 0.07, "the clip was at its marker when the hit landed")


func test_one_item_can_have_its_own_clip_and_casts_and_deaths_play_too() -> void:
	var caster: CharacterBody3D = make_character(Vector3.ZERO, [Abilities.new()])
	var player: AnimationPlayer = animated(caster, &"heavy_swing", 0.5)
	for clip_name: StringName in [&"swing", &"cast", &"death"]:
		var clip := Animation.new()
		clip.add_marker(&"hit", 0.6)
		player.get_animation_library(&"").add_animation(clip_name, clip)
	animator_on(caster, player, {
		&"weapon_started": &"swing",
		&"weapon_started:sword": &"heavy_swing",
		&"ability_cast_started": &"cast",
		&"died": &"death",
	})
	Equipment.find_on(caster).equip(ItemInstance.new(sword(0.0, 0.0)))
	await get_tree().physics_frame
	await press(caster)
	await get_tree().process_frame
	assert_eq(player.current_animation, "heavy_swing", "the sword's own row wins")
	assert_eq(player.get_playing_speed(), 1.0, "an instant weapon's clip plays at its own speed")
	var slow := AbilityData.new()
	slow.cast_time = 1.2
	Abilities.find_on(caster).use(slow)
	assert_eq(player.current_animation, "cast")
	assert_almost_eq(player.get_playing_speed(), 0.5, 0.001, "0.6 s of clip over a 1.2 s cast")
	Health.find_on(caster).change(-1000.0)
	assert_eq(player.current_animation, "death")


func test_animations_are_optional() -> void:
	var swinger: CharacterBody3D = make_character()
	var front: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	# No player at all, and on the next character a row whose clip the player doesn't have.
	animator_on(swinger, null, { &"weapon_started": &"swing" })
	var other: CharacterBody3D = make_character(Vector3(20, 0, 0))
	var player: AnimationPlayer = animated(other, &"swing", 0.5)
	animator_on(other, player, { &"weapon_started": &"missing", &"weapon_fired": &"swing" })
	for who: Node in [swinger, other]:
		Equipment.find_on(who).equip(ItemInstance.new(sword(0.0, 0.0)))
	await get_tree().physics_frame
	await press(swinger)
	await press(other)
	await get_tree().process_frame
	assert_eq(Health.find_on(front).current, 90.0, "the rules don't need the animation")
	assert_eq(player.current_animation, "swing", "the missing clip was skipped, the next row played")


func test_the_animator_warns_in_the_editor_and_lists_the_events() -> void:
	var who: CharacterBody3D = make_character()
	var player: AnimationPlayer = animated(who, &"swing", 0.5)
	var animator: Animator = animator_on(who, null, { &"weapon_started": &"swing" })
	assert_eq(animator._warnings().size(), 1, "no player")
	animator.player = player
	assert_eq(animator._warnings().size(), 0)
	animator.animations = { &"weapon_stated": &"swing", &"died:boss": &"roar" }
	var warnings: PackedStringArray = animator._warnings()
	assert_eq(warnings.size(), 2)
	assert_string_contains(warnings[0], "weapon_stated")
	assert_string_contains(warnings[1], "roar")
	var field := { "name": "animations", "type": TYPE_DICTIONARY, "hint_string": "21:;21:" }
	NameCheck.suggest(animator, field)
	assert_string_starts_with(field.hint_string, "21/3:", "each key is an event to pick")
	assert_has(field.hint_string.get_slice(";", 0).get_slice(":", 1).split(","), "weapon_started")
