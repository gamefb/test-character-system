extends GutTest
## Numbers worked out when an effect runs: per point of a stat, a share of health, a share of
## the hit, and random ranges.


func make_host(parts: Array = [], stats: Dictionary[StringName, float] = {}) -> Node3D:
	var host := Node3D.new()
	var hub := ComponentManager.new()
	hub.stats = stats
	for node: Node in [hub, Health.new(), Statuses.new()] + parts:
		host.add_child(node)
	add_child_autofree(host)
	return host


func health_of(node: Node) -> Health:
	return Health.find_on(node)


func per_point(stat_name: StringName, amount: float, of := Condition.Subject.SOURCE) -> StatAmount:
	var a := StatAmount.new()
	a.stat = stat_name
	a.per_point = amount
	a.of = of
	return a


func share_of_hit(fraction: float) -> HitAmount:
	var a := HitAmount.new()
	a.fraction = fraction
	return a


## A passive that runs [param effect] on [param event].
func reacting(event: StringName, effect: Effect, affects_other := false) -> StatusData:
	var t := StatusTrigger.new()
	t.event = event
	t.effects = [effect]
	t.affects_other = affects_other
	var s := StatusData.new()
	s.triggers = [t]
	return s


func test_total_adds_every_amount_to_the_base() -> void:
	var ctx := EffectContext.new()
	var six := RandomAmount.new()
	six.low = 6.0
	six.high = 6.0
	assert_eq(Amount.total(10.0, [], ctx), 10.0)
	assert_eq(Amount.total(10.0, [six, null, six], ctx), 22.0, "an empty slot is skipped")


func test_damage_scales_with_the_users_stat() -> void:
	var attacker: Node3D = make_host([], { &"strength": 5.0 })
	var target: Node3D = make_host()
	var swing := DamageEffect.new()
	swing.amount = 10.0
	swing.scaling = [per_point(&"strength", 2.0)]
	swing.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(target).current, 80.0, "10 + 2 per point of 5 strength")
	ComponentManager.of(attacker).add_base(&"strength", 5.0)
	swing.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(target).current, 50.0, "levelling up is felt at once")
	swing.apply(EffectContext.new(null, target))
	assert_eq(health_of(target).current, 40.0, "no user: just the plain amount")


func test_stat_modifiers_are_included() -> void:
	var attacker: Node3D = make_host([], { &"strength": 5.0 })
	var target: Node3D = make_host()
	var potion := StatModifier.new()
	potion.stat = &"strength"
	potion.add = 5.0
	ComponentManager.of(attacker).add_modifier(potion)
	var swing := DamageEffect.new()
	swing.amount = 0.0
	swing.scaling = [per_point(&"strength", 1.0)]
	swing.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(target).current, 90.0)


func test_a_curve_gives_numbers_by_level() -> void:
	var attacker: Node3D = make_host([], { &"level": 30.0 })
	var target: Node3D = make_host()
	var by_level := Curve.new()
	by_level.min_domain = 1.0
	by_level.max_domain = 50.0
	by_level.max_value = 100.0
	by_level.add_point(Vector2(1.0, 5.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	by_level.add_point(Vector2(50.0, 54.0), 0.0, 0.0, Curve.TANGENT_LINEAR, Curve.TANGENT_LINEAR)
	var scaling: StatAmount = per_point(&"level", 1.0)
	scaling.curve = by_level
	assert_almost_eq(scaling.value(EffectContext.new(attacker, target)), 34.0, 0.01,
			"level 30 on a line from 5 at level 1 to 54 at level 50")


func test_a_share_of_health() -> void:
	var target: Node3D = make_host()
	health_of(target).change(-60.0)
	var ctx := EffectContext.new(null, target)
	var share := PoolAmount.new()
	share.fraction = 0.5
	share.part = PoolAmount.Part.MAXIMUM
	assert_eq(share.value(ctx), 50.0)
	share.part = PoolAmount.Part.CURRENT
	assert_eq(share.value(ctx), 20.0)
	share.part = PoolAmount.Part.MISSING
	assert_eq(share.value(ctx), 30.0)
	assert_eq(share.value(EffectContext.new(null, autofree(Node.new()))), 0.0, "no Health: 0")
	var mend := HealEffect.new()
	mend.amount = 0.0
	mend.scaling = [share]
	mend.apply(ctx)
	assert_eq(health_of(target).current, 70.0, "healed half of what was missing")


func test_life_steal_is_a_share_of_the_hit() -> void:
	var attacker: Node3D = make_host()
	var target: Node3D = make_host()
	health_of(attacker).change(-50.0)
	var steal := HealEffect.new()
	steal.amount = 0.0
	steal.scaling = [share_of_hit(0.5)]
	Statuses.find_on(attacker).add(reacting(&"dealt_damage", steal))
	var bite := DamageEffect.new()
	bite.amount = 10.0
	bite.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(attacker).current, 55.0, "half of the 10 dealt")
	health_of(target).resistances = { &"physical": 0.5 }
	bite.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(attacker).current, 57.5, "half of what landed, not of what was aimed")


func test_thorns_return_a_share_of_the_hit() -> void:
	var attacker: Node3D = make_host()
	var target: Node3D = make_host()
	var prick := DamageEffect.new()
	prick.amount = 0.0
	prick.scaling = [share_of_hit(0.3)]
	Statuses.find_on(target).add(reacting(&"took_damage", prick, true))
	var bite := DamageEffect.new()
	bite.amount = 10.0
	bite.apply(EffectContext.new(attacker, target))
	assert_eq(health_of(target).current, 90.0)
	assert_eq(health_of(attacker).current, 97.0)
	assert_eq(share_of_hit(0.3).value(EffectContext.new(attacker, target)), 0.0,
			"outside a trigger there's no hit")


func test_a_status_tick_scales_with_whoever_applied_it() -> void:
	var mage: Node3D = make_host([], { &"spell_power": 4.0 })
	var target: Node3D = make_host()
	var burn := DamageEffect.new()
	burn.amount = 1.0
	burn.type = &"fire"
	burn.scaling = [per_point(&"spell_power", 1.0)]
	var burning := StatusData.new()
	burning.duration = 5.0
	burning.tick_interval = 1.0
	burning.on_tick = [burn]
	var statuses := Statuses.find_on(target)
	statuses.add(burning, mage)
	statuses._process(1.0)
	assert_eq(health_of(target).current, 95.0, "1 + the mage's 4 spell power")


func test_a_random_amount_stays_in_its_range() -> void:
	var roll := RandomAmount.new()
	roll.low = 2.0
	roll.high = 4.0
	for i in 50:
		var value: float = roll.value(EffectContext.new())
		assert_between(value, 2.0, 4.0)


func test_a_pool_effect_scales_too() -> void:
	var mana := Pool.new()
	mana.starts_full = false
	var target: Node3D = make_host([mana])
	var draught := ChangePoolEffect.new()
	draught.amount = 5.0
	draught.scaling = [per_point(&"max_mana", 0.25, Condition.Subject.TARGET)]
	draught.apply(EffectContext.new(null, target))
	assert_eq(mana.current, 30.0, "5 + a quarter of the pool")
	draught.apply(EffectContext.new(null, autofree(Node.new())))
	pass_test("a target without the pool is left alone")
