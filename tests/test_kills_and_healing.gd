extends GutTest
## What follows a hit: deaths and kills, reviving, healing, loop protection, and statuses that
## end or are taken away.


## An effect that counts how often it ran.
class CountEffect:
	extends Effect

	var count: int = 0

	func _execute(_ctx: EffectContext) -> void:
		count += 1


func make_host(parts: Array = []) -> Node3D:
	var host := Node3D.new()
	for node: Node in [ComponentManager.new(), Health.new(), Statuses.new()] + parts:
		host.add_child(node)
	add_child_autofree(host)
	return host


func health_of(node: Node) -> Health:
	return Component.of(node, Health) as Health


func statuses_of(node: Node) -> Statuses:
	return Component.of(node, Statuses) as Statuses


func modify(add := 0.0, percent := 0.0, mul := 1.0) -> ModifyAmountEffect:
	var e := ModifyAmountEffect.new()
	e.add = add
	e.percent = percent
	e.mul = mul
	return e


## A passive that runs [param effects] on [param event].
func reacting(event: StringName, effects: Array[Effect]) -> StatusData:
	var t := StatusTrigger.new()
	t.event = event
	t.effects = effects
	var s := StatusData.new()
	s.triggers = [t]
	return s


func damage(amount := 10.0, type: StringName = &"physical") -> DamageEffect:
	var e := DamageEffect.new()
	e.amount = amount
	e.type = type
	return e


func hit(target: Node, amount := 10.0, type: StringName = &"physical",
		source: Node = null) -> EffectContext:
	var ctx := EffectContext.new(source, target)
	damage(amount, type).apply(ctx)
	return ctx


func test_a_dead_target_takes_no_more_hits() -> void:
	var target: Node3D = make_host()
	var events: Array[StringName] = []
	for event: StringName in [&"taking_damage", &"took_damage", &"died"]:
		ComponentManager.of(target).subscribe(event,
				func(_ctx: EffectContext) -> void: events.append(event))
	hit(target, 500.0)
	assert_eq(events, [&"taking_damage", &"died", &"took_damage"] as Array[StringName])
	hit(target, 10.0)
	assert_eq(events.size(), 3, "nothing is sent for a hit on a corpse")


func test_the_killer_hears_killed() -> void:
	var attacker: Node3D = make_host()
	var target: Node3D = make_host()
	health_of(attacker).change(-50.0)
	# Bloodlust: heal 20 for every kill.
	var heal := HealEffect.new()
	heal.amount = 20.0
	statuses_of(attacker).add(reacting(&"killed", [heal]))
	var victims: Array = []
	ComponentManager.of(attacker).subscribe(&"killed",
			func(ctx: EffectContext) -> void: victims.append(ctx.target))
	hit(target, 10.0, &"physical", attacker)
	assert_eq(victims, [], "a hit that doesn't kill")
	hit(target, 500.0, &"physical", attacker)
	assert_eq(victims, [target])
	assert_eq(health_of(attacker).current, 70.0, "the status trigger healed its holder")


func test_killing_yourself_is_not_a_kill() -> void:
	var who: Node3D = make_host()
	var kills: Array = []
	ComponentManager.of(who).subscribe(&"killed",
			func(ctx: EffectContext) -> void: kills.append(ctx))
	hit(who, 500.0, &"physical", who)
	assert_true(health_of(who).is_dead())
	assert_eq(kills, [])


func test_revive_sends_revived() -> void:
	var who: Node3D = make_host()
	var revived: Array = [0]
	ComponentManager.of(who).subscribe(&"revived",
			func(_ctx: EffectContext) -> void: revived[0] += 1)
	health_of(who).revive()
	assert_eq(revived[0], 0, "nothing to revive")
	hit(who, 500.0)
	health_of(who).revive(30.0)
	assert_eq(revived[0], 1)
	assert_eq(health_of(who).current, 30.0)


func test_statuses_change_healing_too() -> void:
	var healer: Node3D = make_host()
	var target: Node3D = make_host()
	health_of(target).change(-60.0)
	statuses_of(target).add(reacting(&"receiving_healing", [modify(0.0, 0.0, 0.5)]))
	statuses_of(healer).add(reacting(&"giving_healing", [modify(4.0)]))
	var heal := HealEffect.new()
	heal.amount = 16.0
	var ctx := EffectContext.new(healer, target)
	heal.apply(ctx)
	assert_eq(health_of(target).current, 50.0, "(16 + 4) x 0.5")
	assert_eq(ctx.amount, 10.0)


func test_triggers_that_set_each_other_off_are_cut_short() -> void:
	var target: Node3D = make_host()
	# Each hit taken deals 1 more, and reacts to its own damage: a loop without the limit.
	var cursed: StatusData = reacting(&"took_damage", [damage(1.0)])
	cursed.triggers[0].react_to_statuses = true
	statuses_of(target).add(cursed)
	hit(target)
	assert_eq(health_of(target).current, 90.0 - EffectContext.MAX_DEPTH,
			"the hit, then one more for each link the chain is allowed")


func test_on_remove_is_for_statuses_that_end_not_characters_that_go() -> void:
	var count := CountEffect.new()
	var bomb := StatusData.new()
	bomb.duration = 5.0
	bomb.on_remove = [count]
	var leaving: Node3D = make_host()
	statuses_of(leaving).add(bomb)
	leaving.free()
	assert_eq(count.count, 0, "despawning the character doesn't set it off")
	var staying: Node3D = make_host()
	statuses_of(staying).add(bomb)
	statuses_of(staying).remove(bomb)
	assert_eq(count.count, 1)


func test_a_status_outlives_whoever_applied_it() -> void:
	var mage: Node3D = make_host()
	var target: Node3D = make_host()
	var burning := StatusData.new()
	burning.duration = 5.0
	burning.tick_interval = 1.0
	burning.on_tick = [damage(4.0, &"fire")]
	statuses_of(target).add(burning, mage)
	mage.free()
	statuses_of(target)._process(1.0)
	statuses_of(target)._process(1.0)
	assert_eq(health_of(target).current, 92.0, "it keeps ticking, with nobody to credit")


func test_removing_statuses_by_tag() -> void:
	var target: Node3D = make_host()
	var venom := StatusData.new()
	venom.tags = [&"poison"]
	venom.duration = 5.0
	var toxin := StatusData.new()
	toxin.tags = [&"poison", &"acid"]
	toxin.duration = 5.0
	var haste := StatusData.new()
	haste.tags = [&"haste"]
	haste.duration = 5.0
	for s: StatusData in [venom, toxin, haste]:
		statuses_of(target).add(s)
	var antidote := RemoveStatusEffect.new()
	antidote.tag = &"poison"
	antidote.apply(EffectContext.new(null, target))
	assert_false(statuses_of(target).has_tag(&"poison"))
	assert_true(statuses_of(target).has_tag(&"haste"))
