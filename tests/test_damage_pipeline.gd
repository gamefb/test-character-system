extends GutTest
## How a hit is worked out: totals that don't depend on order, damage types and tags, bonus and
## resist stats, trigger conditions and shields.


func make_host(parts: Array = []) -> Node3D:
	var host := Node3D.new()
	for node: Node in [ComponentManager.new(), Health.new(), Statuses.new()] + parts:
		host.add_child(node)
	add_child_autofree(host)
	return host


func health_of(node: Node) -> Health:
	return Health.find_on(node)


func statuses_of(node: Node) -> Statuses:
	return Statuses.find_on(node)


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


func test_armour_and_shield_give_the_same_result_in_either_order() -> void:
	var armour: StatusData = reacting(&"taking_damage", [modify(-3.0)])
	var shield: StatusData = reacting(&"taking_damage", [modify(0.0, 0.0, 0.5)])
	var first: Node3D = make_host()
	statuses_of(first).add(armour)
	statuses_of(first).add(shield)
	var second: Node3D = make_host()
	statuses_of(second).add(shield)
	statuses_of(second).add(armour)
	hit(first)
	hit(second)
	assert_eq(health_of(first).current, 96.5, "(10 - 3) x 0.5")
	assert_eq(health_of(second).current, 96.5, "the same with the statuses the other way round")


func test_percentages_add_up_and_multipliers_multiply() -> void:
	var target: Node3D = make_host()
	statuses_of(target).add(reacting(&"taking_damage", [modify(0.0, 0.5)]))
	statuses_of(target).add(reacting(&"taking_damage", [modify(0.0, 0.5)]))
	hit(target)
	assert_eq(health_of(target).current, 80.0, "two +50% make +100%, not +125%")
	statuses_of(target).add(reacting(&"taking_damage", [modify(0.0, 0.0, 0.5)]))
	statuses_of(target).add(reacting(&"taking_damage", [modify(0.0, 0.0, 0.5)]))
	hit(target)
	assert_eq(health_of(target).current, 75.0, "10 x 2 x 0.5 x 0.5")


func test_per_stack_counts_every_stack() -> void:
	var target: Node3D = make_host()
	var marked: StatusData = reacting(&"taking_damage", [modify(0.0, 0.1)])
	(marked.triggers[0].effects[0] as ModifyAmountEffect).per_stack = true
	marked.stacking = StatusData.Stacking.STACK
	marked.max_stacks = 3
	marked.duration = 10.0
	for i in 3:
		statuses_of(target).add(marked)
	hit(target)
	assert_almost_eq(health_of(target).current, 87.0, 0.001, "three stacks of +10%")


func test_the_hit_reports_what_landed() -> void:
	var target: Node3D = make_host()
	statuses_of(target).add(reacting(&"taking_damage", [modify(-4.0)]))
	var ctx: EffectContext = hit(target)
	assert_eq(ctx.amount, 6.0, "for damage numbers")
	assert_eq(ctx.damage_type, &"physical")
	assert_eq([ctx.add, ctx.percent, ctx.mul], [0.0, 0.0, 1.0], "the totals are used up")


func test_source_bonus_stat_adds_a_percentage_of_its_type() -> void:
	var attacker: Node3D = make_host()
	var target: Node3D = make_host()
	var pyromancer := StatusData.new()
	var bonus := StatModifier.new()
	bonus.stat = &"bonus_fire"
	bonus.add = 0.5
	pyromancer.modifiers = [bonus]
	statuses_of(attacker).add(pyromancer)
	hit(target, 10.0, &"fire", attacker)
	assert_eq(health_of(target).current, 85.0, "bonus_fire 0.5 is 50% more fire damage")
	hit(target, 10.0, &"physical", attacker)
	assert_eq(health_of(target).current, 75.0, "other types are untouched")


func test_negative_resistance_is_a_weakness() -> void:
	var target: Node3D = make_host()
	health_of(target).resistances = { &"fire": -0.5 }
	hit(target, 10.0, &"fire")
	assert_eq(health_of(target).current, 85.0)


func test_resistance_applies_after_the_modifiers() -> void:
	var target: Node3D = make_host()
	health_of(target).resistances = { &"fire": 0.5 }
	statuses_of(target).add(reacting(&"taking_damage", [modify(10.0)]))
	hit(target, 10.0, &"fire")
	assert_eq(health_of(target).current, 90.0, "(10 + 10) x 0.5")


func test_a_ward_can_block_one_damage_type() -> void:
	var target: Node3D = make_host()
	var block: ModifyAmountEffect = modify(0.0, 0.0, 0.0)
	var only_fire := HitCondition.new()
	only_fire.types = [&"fire"]
	block.conditions = [only_fire]
	statuses_of(target).add(reacting(&"taking_damage", [block]))
	hit(target, 10.0, &"fire")
	assert_eq(health_of(target).current, 100.0)
	hit(target, 10.0, &"physical")
	assert_eq(health_of(target).current, 90.0)


func test_hurtbox_tags_reach_triggers_and_crits_are_labelled() -> void:
	var attacker: Node3D = make_host()
	var target: Node3D = make_host()
	var head: Hurtbox = autofree(Hurtbox.new())
	head.character = target
	head.tags = [&"head"]
	# A sharpshooter passive: headshots deal double and count as crits.
	var bonus: ModifyAmountEffect = modify(0.0, 1.0)
	bonus.tag = &"crit"
	var sharpshooter: StatusData = reacting(&"dealing_damage", [bonus])
	var on_head := HitCondition.new()
	on_head.tags = [&"head"]
	sharpshooter.triggers[0].conditions = [on_head]
	statuses_of(attacker).add(sharpshooter)
	var seen: Array = []
	ComponentManager.of(target).event(&"took_damage").connect(
			func(ctx: EffectContext) -> void: seen.append(ctx.tags.duplicate()))
	var swing: DamageEffect = damage()
	swing.tags = [&"melee"]
	var ctx: EffectContext = Hurtbox.hit(attacker, head, null, Vector3(1, 2, 3))
	swing.apply(ctx)
	assert_eq(health_of(target).current, 80.0, "a headshot")
	assert_eq(seen[0], [&"head", &"melee", &"crit"])
	assert_eq(ctx.tags, [&"head"], "the effect's own tags end with it")
	assert_eq(ctx.position, Vector3(1, 2, 3))
	swing.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(target).current, 70.0, "a body shot")


func test_a_trigger_checks_its_conditions_once_for_all_its_effects() -> void:
	var target: Node3D = make_host()
	var count := CountEffect.new()
	var fragile: StatusData = reacting(&"took_damage", [count, count])
	var hurt := PoolBelowCondition.new()
	hurt.fraction = 0.5
	fragile.triggers[0].conditions = [hurt]
	statuses_of(target).add(fragile)
	hit(target, 10.0)
	assert_eq(count.count, 0, "above half health: nothing runs")
	hit(target, 50.0)
	assert_eq(count.count, 2, "below: every effect runs")


func test_a_pool_that_absorbs_damage_is_a_shield() -> void:
	var shield := Pool.new()
	shield.pool = &"shield"
	shield.max_value = 15.0
	shield.absorbs_damage = true
	var target: Node3D = make_host([shield])
	hit(target)
	assert_eq([shield.current, health_of(target).current], [5.0, 100.0])
	var ctx: EffectContext = hit(target)
	assert_eq([shield.current, health_of(target).current], [0.0, 95.0], "the rest gets through")
	assert_eq(ctx.amount, 5.0, "what reached health")


func test_a_shield_can_be_limited_to_some_damage_types() -> void:
	var barrier := Pool.new()
	barrier.pool = &"barrier"
	barrier.absorbs_damage = true
	barrier.absorbed_types = [&"energy"]
	var target: Node3D = make_host([barrier])
	hit(target, 10.0, &"physical")
	assert_eq([barrier.current, health_of(target).current], [100.0, 90.0])
	hit(target, 10.0, &"energy")
	assert_eq([barrier.current, health_of(target).current], [90.0, 90.0])


func test_old_style_listeners_can_still_change_the_amount() -> void:
	var target: Node3D = make_host()
	ComponentManager.of(target).event(&"taking_damage").connect(
			func(ctx: EffectContext) -> void: ctx.amount *= 0.5)
	hit(target)
	assert_eq(health_of(target).current, 95.0)


## An effect that counts how often it ran.
class CountEffect:
	extends Effect

	var count: int = 0

	func _execute(_ctx: EffectContext) -> void:
		count += 1
