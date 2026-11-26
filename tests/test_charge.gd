extends GutTest
## Weapons that charge: hold to build it, let go to fire, and data decides what it is worth.

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
	var parts: Array[Node] = [
		shape, hand, ComponentManager.new(), Health.new(), Statuses.new(), gear,
	]
	if not extra.any(func(part: Node) -> bool: return part is Brain):
		parts.append(Brain.new())
	for node: Node in parts + extra:
		body.add_child(node)
	add_child_autofree(body)
	return body


## Damage of 10, and 20 more at a full charge.
func damage_by_charge() -> DamageEffect:
	var by_charge := ChargeAmount.new()
	by_charge.at_full = 20.0
	var damage := DamageEffect.new()
	damage.scaling = [by_charge]
	return damage


## A weapon that takes half a second to charge and hits what is in front of it. [param setup]
## is called with its trigger, to change it.
func charged(effects: Array[Effect], setup: Callable = Callable(),
		extra: Array[Node] = []) -> ItemData:
	var root := Node3D.new()
	var trigger := Trigger.new()
	trigger.fire_rate = 4.0
	trigger.charge_time = 0.5
	if setup.is_valid():
		setup.call(trigger)
	var sweep := MeleeSweep.new()
	sweep.shape = BoxShape3D.new()
	sweep.offset = Vector3(0, 0, -1.5)
	sweep.effects = effects
	for node: Node in [ComponentManager.new(), trigger, sweep] + extra:
		root.add_child(node)
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	var data := ItemData.new()
	data.id = &"charger"
	data.slot = &"weapon"
	data.scene = scene
	return data


## A wielder holding [param weapon] and a target in front of it.
func pair(weapon: ItemData) -> Array[CharacterBody3D]:
	var user: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -1.6))
	Equipment.find_on(user).equip(ItemInstance.new(weapon))
	await get_tree().physics_frame
	return [user, target]


func test_a_charge_is_worth_what_the_effects_say() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()]))
	await _hold(p[0], 0.0)
	assert_almost_eq(_hurt(p[1]), 10.0, 1.0, "a tap: hardly any charge")
	Health.find_on(p[1]).revive()
	await _wait(0.3)
	await _hold(p[0], 0.25)
	assert_almost_eq(_hurt(p[1]), 20.0, 1.5, "half a charge: half of the 20 more")
	Health.find_on(p[1]).revive()
	await _wait(0.3)
	await _hold(p[0], 0.8)
	assert_eq(_hurt(p[1]), 30.0, "held past full: all of it, and no more")


func test_a_charge_does_nothing_by_itself() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([DamageEffect.new()]))
	await _hold(p[0], 0.8)
	assert_eq(_hurt(p[1]), 10.0, "no effect asked about the charge")


func test_nothing_fires_until_the_button_is_let_go() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()]))
	var durations: Array[float] = []
	var fired: Array[EffectContext] = []
	var manager := ComponentManager.of(p[0])
	manager.event(&"weapon_started").connect(
			func(ctx: EffectContext) -> void: durations.append(ctx.duration))
	manager.event(&"weapon_fired").connect(func(ctx: EffectContext) -> void: fired.append(ctx))
	var trigger: Trigger = _trigger_of(p[0])
	assert_false(trigger.is_charging())
	await _press(p[0])
	await _wait(0.8)
	assert_eq(_hurt(p[1]), 0.0)
	assert_true(trigger.is_charging())
	assert_eq(trigger.charge, 1.0, "a full charge is held")
	assert_eq(durations, [0.5] as Array[float], "the start says how long a full charge takes")
	Brain.find_on(p[0]).release(&"primary")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(_hurt(p[1]), 30.0)
	assert_false(trigger.is_charging())
	assert_eq(fired[0].charge, 1.0, "the shot says how far it was charged")
	assert_eq(fired[0].duration, 0.0)


func test_a_button_held_through_the_cooldown_starts_the_next_charge() -> void:
	var slow_to_fire := func(t: Trigger) -> void: t.fire_rate = 2.0
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()], slow_to_fire))
	await _hold(p[0], 0.0)
	Health.find_on(p[1]).revive()
	# Pressed at once and kept down: the half-second cooldown passes, then the charge builds.
	await _hold(p[0], 1.2)
	assert_eq(_hurt(p[1]), 30.0, "the press wasn't lost, and the charge started when it could")


func test_letting_go_before_the_minimum_cancels_the_shot() -> void:
	var magazine := Magazine.new()
	magazine.capacity = 3
	var needs_half := func(t: Trigger) -> void: t.min_charge = 0.5
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()], needs_half, [magazine]))
	var heard: Array[StringName] = []
	for event: StringName in [&"weapon_fired", &"weapon_interrupted"]:
		ComponentManager.of(p[0]).event(event).connect(
				func(_ctx: EffectContext) -> void: heard.append(event))
	var loaded := Magazine.find_on(Equipment.find_on(p[0]).node_in(&"weapon"))
	await _hold(p[0], 0.1)
	assert_eq(_hurt(p[1]), 0.0, "a fifth of a charge is under the half it needs")
	assert_eq(loaded.rounds, 3, "the round went back")
	assert_eq(heard, [&"weapon_interrupted"] as Array[StringName])
	await _hold(p[0], 0.35)
	assert_almost_eq(_hurt(p[1]), 24.0, 1.5, "0.7 of a charge is enough")
	assert_eq(loaded.rounds, 2)


func test_a_weapon_can_need_a_full_charge() -> void:
	var needs_all := func(t: Trigger) -> void: t.min_charge = 1.0
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()], needs_all))
	await _hold(p[0], 0.4)
	assert_eq(_hurt(p[1]), 0.0)
	await _hold(p[0], 0.6)
	assert_eq(_hurt(p[1]), 30.0)


func test_the_status_is_held_while_charging_and_a_stun_cancels_the_charge() -> void:
	var slow: StatusData = load(EX + "statuses/drawing.tres")
	var with_status := func(t: Trigger) -> void: t.status_while_charging = slow
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()], with_status))
	var statuses := Statuses.find_on(p[0])
	await _press(p[0])
	await _wait(0.2)
	assert_eq(statuses.stacks_of(slow), 1, "held while charging")
	Brain.find_on(p[0]).release(&"primary")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(statuses.stacks_of(slow), 0, "and gone at the shot")
	Health.find_on(p[1]).revive()
	await _wait(0.3)
	await _press(p[0])
	await _wait(0.2)
	statuses.add(load(EX + "statuses/stunned.tres"))
	await _wait(0.1)
	assert_false(_trigger_of(p[0]).is_charging())
	assert_eq(statuses.stacks_of(slow), 0, "gone when the charge is cut short")
	Brain.find_on(p[0]).release(&"primary")
	await _wait(0.1)
	assert_eq(_hurt(p[1]), 0.0, "and nothing fired")


func test_putting_the_weapon_away_while_charging_cancels() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()]))
	await _press(p[0])
	await _wait(0.2)
	Equipment.find_on(p[0]).unequip(&"weapon")
	await _wait(0.1)
	Brain.find_on(p[0]).release(&"primary")
	await _wait(0.1)
	assert_eq(_hurt(p[1]), 0.0)


func test_a_condition_switches_an_effect_on_from_some_charge() -> void:
	var soak := ApplyStatusEffect.new()
	soak.status = load(EX + "statuses/wet.tres")
	soak.conditions = [ChargeCondition.new()]
	var chill := ApplyStatusEffect.new()
	chill.status = load(EX + "statuses/rooted.tres")
	var below_half := ChargeCondition.new()
	below_half.at_least = 0.5
	below_half.negate = true
	chill.conditions = [below_half]
	var p: Array[CharacterBody3D] = await pair(charged([soak, chill]))
	var statuses := Statuses.find_on(p[1])
	await _hold(p[0], 0.1)
	assert_false(statuses.has_tag(&"wet"), "not fully charged")
	assert_true(statuses.has_tag(&"rooted"), "under half: the negated condition passes")
	statuses.remove_tagged(&"rooted")
	await _wait(0.3)
	await _hold(p[0], 0.7)
	assert_true(statuses.has_tag(&"wet"), "fully charged")
	assert_false(statuses.has_tag(&"rooted"))


func test_a_status_reacting_to_a_hit_sees_its_charge() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([DamageEffect.new()]))
	# A passive on the target: a fully charged hit soaks whoever is hit.
	var soak := ApplyStatusEffect.new()
	soak.status = load(EX + "statuses/wet.tres")
	var on_charged_hit := StatusTrigger.new()
	on_charged_hit.event = &"took_damage"
	on_charged_hit.conditions = [ChargeCondition.new()]
	on_charged_hit.effects = [soak]
	var passive := StatusData.new()
	passive.id = &"soaked_by_charged_hits"
	passive.triggers = [on_charged_hit]
	Statuses.find_on(p[1]).add(passive)
	await _hold(p[0], 0.1)
	assert_false(Statuses.find_on(p[1]).has_tag(&"wet"))
	await _wait(0.3)
	await _hold(p[0], 0.7)
	assert_true(Statuses.find_on(p[1]).has_tag(&"wet"))


func test_knockback_and_projectile_speed_can_grow_with_the_charge() -> void:
	var by_charge := ChargeAmount.new()
	by_charge.at_full = 8.0
	var shove := KnockbackEffect.new()
	shove.amount = 8.0
	shove.lift = 0.0
	shove.scaling = [by_charge]
	var source := Node3D.new()
	add_child_autofree(source)
	var speeds: Array[float] = []
	for charge: float in [0.0, 1.0]:
		var crate := RigidBody3D.new()
		crate.gravity_scale = 0.0
		crate.position = Vector3(0, 0, -3)
		add_child_autofree(crate)
		var ctx := EffectContext.new(source, crate)
		ctx.charge = charge
		shove.apply(ctx)
		await get_tree().physics_frame
		await get_tree().physics_frame
		speeds.append(crate.linear_velocity.length())
		crate.position.y = 50.0
	assert_almost_eq(speeds[0], 8.0, 0.1)
	assert_almost_eq(speeds[1], 16.0, 0.1, "8 more at a full charge")
	var half := ChargeAmount.new()
	half.at_full = 30.0
	half.curve = Curve.new()
	half.curve.add_point(Vector2(0.0, 0.0))
	half.curve.add_point(Vector2(1.0, 0.5))
	var ctx := EffectContext.new(source, source)
	ctx.charge = 1.0
	assert_almost_eq(half.value(ctx), 15.0, 0.01, "a curve shapes how the amount grows")


func test_the_longbow_is_worth_more_the_further_it_is_drawn() -> void:
	var archer: CharacterBody3D = make_character()
	var target: CharacterBody3D = make_character(Vector3(0, 0, -6))
	Equipment.find_on(archer).equip(ItemInstance.new(load(EX + "items/longbow.tres")))
	Brain.find_on(archer).aim_point = target.global_position + Vector3.UP
	await get_tree().physics_frame
	await _hold(archer, 0.1)
	await _wait(0.4)
	assert_eq(_hurt(target), 0.0, "let go too soon: the bow is lowered")
	await _press(archer)
	await _wait(0.4)
	assert_true(Statuses.find_on(archer).has_tag(&"drawing"), "slowed while drawing")
	Brain.find_on(archer).release(&"primary")
	await get_tree().process_frame
	await get_tree().process_frame
	var arrows: Array[Node] = get_tree().root.find_children("*", "Projectile", true, false)
	assert_eq(arrows.size(), 1)
	assert_almost_eq((arrows[0] as Projectile).speed, 35.0, 1.5, "20, and half of the 30 more")
	await _wait(0.5)
	assert_almost_eq(_hurt(target), 19.0, 1.5, "8, and half of the 22 more")
	assert_false(Statuses.find_on(target).has_tag(&"bleed"), "only a full draw makes it bleed")
	Health.find_on(target).revive()
	await _hold(archer, 1.0)
	await _wait(0.4)
	assert_gte(_hurt(target), 30.0, "a full draw")
	assert_true(Statuses.find_on(target).has_tag(&"bleed"))


func test_the_hud_bar_fills_while_a_weapon_charges() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()]))
	var hud := Control.new()
	for bar_name: String in ["HealthBar", "ChargeBar"]:
		var bar := ProgressBar.new()
		bar.name = bar_name
		hud.add_child(bar)
	for label_name: String in ["Statuses", "Ammo", "Cooldown"]:
		var label := Label.new()
		label.name = label_name
		hud.add_child(label)
	hud.set_script(CharacterHud)
	hud.set(&"character", p[0])
	add_child_autofree(hud)
	var bar: ProgressBar = hud.get_node("ChargeBar")
	await get_tree().process_frame
	assert_false(bar.visible, "hidden when nothing is charging")
	await _press(p[0])
	await _wait(0.25)
	assert_true(bar.visible)
	assert_almost_eq(bar.value, 50.0, 8.0, "half-way after half the charge time")
	Brain.find_on(p[0]).release(&"primary")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(bar.visible)


func test_an_ai_holds_the_button_for_its_hold_time() -> void:
	var enemies := Faction.new()
	enemies.team = &"enemy"
	enemies.hostile_to = [&"player"]
	var players := Faction.new()
	players.team = &"player"
	var thinker := AttackNearest.new()
	thinker.think_interval = 0.1
	thinker.hold_time = 0.6
	var parts: Array[Node] = [NavigationAgent3D.new(), AIBrain.new(), enemies, thinker]
	var enemy: CharacterBody3D = make_character(Vector3.ZERO, parts)
	var player: CharacterBody3D = make_character(Vector3(0, 0, -1.6), [players])
	Equipment.find_on(enemy).equip(ItemInstance.new(charged([damage_by_charge()])))
	await _wait(1.2)
	assert_eq(_hurt(player), 30.0, "one fully charged hit")


func test_the_animator_keeps_a_draw_clip_in_step_with_the_charge() -> void:
	var p: Array[CharacterBody3D] = await pair(charged([damage_by_charge()]))
	var clip := Animation.new()
	clip.length = 2.0
	clip.add_marker(&"hit", 1.0)
	var library := AnimationLibrary.new()
	library.add_animation(&"draw", clip)
	var player := AnimationPlayer.new()
	p[0].add_child(player)
	player.add_animation_library(&"", library)
	var animator := Animator.new()
	animator.player = player
	animator.animations = { &"weapon_started": &"draw" }
	p[0].add_child(animator)
	await _press(p[0])
	await get_tree().process_frame
	assert_eq(player.current_animation, "draw")
	assert_almost_eq(player.get_playing_speed(), 2.0, 0.001, "its marker is reached at a full charge")
	Brain.find_on(p[0]).release(&"primary")


## Presses as a player's input does, in the frame it arrives.
func _press(who: Node) -> void:
	await get_tree().process_frame
	Brain.find_on(who)._press(&"primary", Engine.get_process_frames())


func _wait(seconds: float) -> void:
	var waited: float = 0.0
	while waited < seconds:
		await get_tree().process_frame
		waited += get_process_delta_time()


## Holds the button for a time, lets go, and waits for the shot to land.
func _hold(who: Node, seconds: float) -> void:
	await _press(who)
	await _wait(seconds)
	Brain.find_on(who).release(&"primary")
	await get_tree().process_frame
	await get_tree().process_frame


func _trigger_of(who: Node) -> Trigger:
	return Trigger.find_on(Equipment.find_on(who).node_in(&"weapon"))


func _hurt(who: Node) -> float:
	var health := Health.find_on(who)
	return health.maximum() - health.current
