extends GutTest
## Stats you list yourself, percentages, conditional modifiers, breakdowns, and pools.


func make_host(parts: Array = [], stats: Dictionary[StringName, float] = {}) -> Node3D:
	var host := Node3D.new()
	var hub := ComponentManager.new()
	hub.stats = stats
	for node: Node in [hub, Health.new(), Statuses.new()] + parts:
		host.add_child(node)
	add_child_autofree(host)
	return host



func modifier(stat_name: StringName, add := 0.0, percent := 0.0, mul := 1.0) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat_name
	m.add = add
	m.percent = percent
	m.mul = mul
	return m


func test_the_manager_owns_the_stats_listed_on_it() -> void:
	var host: Node3D = make_host([], { &"strength": 10.0, &"level": 1.0 })
	var manager := ComponentManager.of(host)
	assert_eq(manager.stat(&"strength"), 10.0)
	watch_signals(manager)
	manager.add_base(&"level", 1.0)
	assert_eq(manager.stat(&"level"), 2.0)
	assert_signal_emitted_with_parameters(manager, "stat_changed", [&"level"])
	manager.set_base(&"luck", 3.0)
	assert_eq(manager.stat(&"luck"), 3.0, "a stat can be added during play")


func test_percentages_add_up_before_multipliers() -> void:
	var host: Node3D = make_host([], { &"power": 10.0 })
	var manager := ComponentManager.of(host)
	for m: StatModifier in [
		modifier(&"power", 2.0),
		modifier(&"power", 0.0, 0.5),
		modifier(&"power", 0.0, 0.5),
		modifier(&"power", 0.0, 0.0, 0.5),
	]:
		manager.add_modifier(m)
	assert_eq(manager.stat(&"power"), 12.0, "(10 + 2) x (1 + 0.5 + 0.5) x 0.5")
	assert_eq(manager.base_of(&"power"), 10.0)


func test_a_conditional_modifier_follows_its_condition() -> void:
	var host: Node3D = make_host([], { &"speed": 10.0 })
	var manager := ComponentManager.of(host)
	var health := Health.find_on(host)
	var hurt := PoolBelowCondition.new()
	hurt.fraction = 0.5
	var adrenaline: StatModifier = modifier(&"speed", 0.0, 0.5)
	adrenaline.conditions = [hurt]
	manager.add_modifier(adrenaline)
	assert_eq(manager.stat(&"speed"), 10.0)
	health.change(-60.0)
	assert_eq(manager.stat(&"speed"), 15.0, "faster while badly hurt, with nothing to refresh")
	health.change(30.0)
	assert_eq(manager.stat(&"speed"), 10.0)


func test_a_condition_on_a_stat_can_read_that_stat() -> void:
	var host: Node3D = make_host([], { &"power": 10.0 })
	var manager := ComponentManager.of(host)
	var strong := StatCondition.new()
	strong.stat = &"power"
	strong.value = 5.0
	var momentum: StatModifier = modifier(&"power", 4.0)
	momentum.conditions = [strong]
	manager.add_modifier(momentum)
	assert_eq(manager.stat(&"power"), 14.0, "the condition sees the base value, not a loop")


func test_modifiers_of_explains_a_number() -> void:
	var host: Node3D = make_host([], { &"speed": 10.0 })
	var manager := ComponentManager.of(host)
	var haste := StatusData.new()
	haste.display_name = "Haste"
	haste.modifiers = [modifier(&"speed", 0.0, 0.5), modifier(&"max_health", 10.0)]
	Statuses.find_on(host).add(haste)
	var aiming: StatModifier = modifier(&"speed", 0.0, 0.0, 0.5)
	manager.add_modifier(aiming)
	var entries: Array[Dictionary] = manager.modifiers_of(&"speed")
	assert_eq(entries.size(), 2)
	assert_eq(entries[0].source, haste, "added by the status")
	assert_eq(entries[0].modifier, haste.modifiers[0])
	assert_true(entries[0].active)
	assert_null(entries[1].source, "added from code without saying what by")
	manager.remove_modifier(haste.modifiers[0])
	assert_eq(manager.modifiers_of(&"speed")[0].modifier, aiming)
	assert_eq(manager.modifiers_of(&"max_health")[0].source, haste, "sources stay in step")


func test_pool_spends_only_what_it_has() -> void:
	var mana := Pool.new()
	mana.max_value = 50.0
	make_host([mana])
	watch_signals(mana)
	assert_eq(mana.current, 50.0, "starts full")
	assert_true(mana.spend(30.0))
	assert_false(mana.spend(30.0), "not enough: nothing is taken")
	assert_eq(mana.current, 20.0)
	assert_eq(mana.fraction(), 0.4)
	mana.change(100.0)
	assert_eq(mana.current, 50.0, "never above the maximum")
	mana.change(-100.0)
	assert_eq(mana.current, 0.0, "never below 0")
	assert_signal_emitted(mana, "emptied")


func test_pool_regenerates_after_its_delay() -> void:
	var stamina := Pool.new()
	stamina.pool = &"stamina"
	stamina.regen = 10.0
	stamina.regen_delay = 1.0
	make_host([stamina])
	stamina.spend(50.0)
	stamina._process(0.5)
	assert_eq(stamina.current, 50.0, "still waiting")
	stamina._process(0.6)
	stamina._process(1.0)
	assert_eq(stamina.current, 60.0, "10 a second once the delay has passed")
	stamina._process(100.0)
	assert_eq(stamina.current, 100.0)


func test_a_pool_can_start_empty_and_fade() -> void:
	var rage := Pool.new()
	rage.pool = &"rage"
	rage.starts_full = false
	rage.regen = -5.0
	make_host([rage])
	assert_eq(rage.current, 0.0)
	rage.change(20.0)
	rage._process(1.0)
	assert_eq(rage.current, 15.0)


func test_statuses_change_a_pools_size_and_regen() -> void:
	var mana := Pool.new()
	var host: Node3D = make_host([mana])
	var manager := ComponentManager.of(host)
	assert_eq(manager.stat(&"max_mana"), 100.0)
	var wisdom: StatModifier = modifier(&"max_mana", 50.0)
	manager.add_modifier(wisdom)
	assert_eq(mana.maximum(), 150.0)
	mana.change(50.0)
	assert_eq(mana.current, 150.0)
	manager.remove_modifier(wisdom)
	assert_eq(mana.current, 100.0, "cut down with the maximum")
	manager.add_modifier(modifier(&"mana_regen", 4.0))
	mana.spend(20.0)
	mana._process(1.0)
	assert_eq(mana.current, 84.0)


func test_a_pool_starts_at_its_buffed_maximum_whatever_the_node_order() -> void:
	var wise := StatusData.new()
	wise.modifiers = [modifier(&"max_mana", 50.0)]
	var traits := Statuses.new()
	traits.innate = [wise]
	var host := Node3D.new()
	var mana := Pool.new()
	# The pool comes before the Statuses that will raise its maximum.
	for node: Node in [ComponentManager.new(), mana, traits]:
		host.add_child(node)
	add_child_autofree(host)
	assert_eq(mana.maximum(), 150.0)
	assert_eq(mana.current, 150.0, "full, innate passives included")


func test_pools_are_found_by_name() -> void:
	var mana := Pool.new()
	var stamina := Pool.new()
	stamina.pool = &"stamina"
	var host: Node3D = make_host([mana, stamina])
	assert_eq(Pool.named(host, &"mana"), mana)
	assert_eq(Pool.named(host, &"stamina"), stamina)
	assert_null(Pool.named(host, &"rage"))
	assert_null(Pool.named(null, &"mana"), "safe on anything")
	var health := Health.find_on(host)
	assert_eq(Pool.named(host, &"health"), health, "health is the pool named health")
	assert_eq(ComponentManager.of(host).find_all(Pool),
			[health, mana, stamina] as Array[Component])


func test_health_is_a_pool() -> void:
	var host: Node3D = make_host()
	var manager := ComponentManager.of(host)
	var health := Health.find_on(host)
	assert_eq(health.pool, &"health")
	assert_eq(manager.stat(&"max_health"), 100.0, "its stats are named like any pool's")
	manager.add_modifier(modifier(&"health_regen", 10.0))
	health.change(-50.0)
	health._process(1.0)
	assert_eq(health.current, 60.0, "so health_regen works with no extra code")
	var blood_magic := AbilityData.new()
	blood_magic.costs = { &"health": 25.0 }
	var abilities := Abilities.new()
	host.add_child(Brain.new())
	host.add_child(abilities)
	assert_true(abilities.use(blood_magic), "and an ability can cost health")
	assert_eq(health.current, 35.0)
	var share := PoolAmount.new()
	share.part = PoolAmount.Part.MISSING
	share.fraction = 1.0
	assert_eq(share.value(EffectContext.new(host, host)), 65.0)
	var low := PoolBelowCondition.new()
	low.fraction = 0.5
	assert_true(low.check(EffectContext.new(host, host)))


func test_a_pool_gives_a_status_while_it_is_empty() -> void:
	var exhausted := StatusData.new()
	exhausted.blocks = [&"movement"]
	var stamina := Pool.new()
	stamina.pool = &"stamina"
	stamina.status_while_empty = exhausted
	var host: Node3D = make_host([stamina])
	var statuses := Statuses.find_on(host)
	assert_false(statuses.active.has(exhausted))
	stamina.change(-100.0)
	assert_true(statuses.active.has(exhausted), "given when the pool runs out")
	assert_true(ComponentManager.blocked(host, &"movement"))
	stamina.change(1.0)
	assert_false(statuses.active.has(exhausted), "and taken back when it has something again")
	var low := PoolBelowCondition.new()
	low.pool = &"stamina"
	low.fraction = 0.1
	assert_true(low.check(EffectContext.new(host, host)), "conditions read any pool")
	var rage := Pool.new()
	rage.pool = &"rage"
	rage.starts_full = false
	rage.status_while_empty = exhausted
	host.add_child(rage)
	assert_true(statuses.active.has(exhausted), "a pool that starts empty gives it at once")
