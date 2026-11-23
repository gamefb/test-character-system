extends GutTest
## Abilities: costs, charges, conditions, casting, interruption, and what stops a character
## acting at all.


## Targets nobody, or whoever it's told to.
class FixedTargeting:
	extends Targeting

	var targets: Array[Node] = []

	func find(_ctx: EffectContext) -> Array[Node]:
		return targets


var caster: Node3D
var abilities: Abilities
var brain: Brain
var health: Health
var statuses: Statuses
var mana: Pool


func before_each() -> void:
	caster = make_host()
	abilities = Component.of(caster, Abilities)
	brain = Component.of(caster, Brain)
	health = Component.of(caster, Health)
	statuses = Component.of(caster, Statuses)
	mana = Pool.named(caster, &"mana")


func make_host() -> Node3D:
	var host := Node3D.new()
	var pool := Pool.new()
	pool.max_value = 50.0
	for node: Node in [
		ComponentManager.new(), Health.new(), Statuses.new(), Brain.new(), Abilities.new(), pool,
	]:
		host.add_child(node)
	add_child_autofree(host)
	return host


## An ability that heals its user for 10.
func mend(cooldown := 1.0) -> AbilityData:
	var heal := HealEffect.new()
	heal.amount = 10.0
	var ability := AbilityData.new()
	ability.cooldown = cooldown
	ability.effects = [heal]
	return ability


func tagged(tag: StringName, duration := 5.0) -> StatusData:
	var s := StatusData.new()
	s.tags = [tag]
	s.duration = duration
	return s


func test_a_cost_is_taken_from_the_pool() -> void:
	var spell: AbilityData = mend(0.0)
	spell.costs = { &"mana": 30.0 }
	watch_signals(abilities)
	assert_true(abilities.use(spell))
	assert_eq(mana.current, 20.0)
	abilities._process(0.1)
	assert_eq(abilities.why_not(spell), &"cost")
	assert_false(abilities.use(spell))
	assert_eq(mana.current, 20.0, "nothing is taken when it fails")
	assert_signal_emitted_with_parameters(abilities, "failed", [spell, &"cost"])


func test_a_missing_pool_cannot_be_paid_from() -> void:
	var spell: AbilityData = mend()
	spell.costs = { &"rage": 5.0 }
	assert_eq(abilities.why_not(spell), &"cost")


func test_charges_bank_several_uses() -> void:
	var dash: AbilityData = mend(1.0)
	dash.charges = 2
	assert_eq(abilities.charges_left(dash), 2)
	assert_true(abilities.use(dash))
	assert_eq(abilities.cooldown_left(dash), 0.0, "a charge is still ready")
	assert_true(abilities.use(dash))
	assert_false(abilities.use(dash))
	assert_eq(abilities.why_not(dash), &"cooldown")
	assert_almost_eq(abilities.cooldown_left(dash), 1.0, 0.001)
	abilities._process(1.0)
	assert_eq(abilities.charges_left(dash), 1, "one charge back per cooldown")
	abilities._process(1.0)
	assert_eq(abilities.charges_left(dash), 2)
	assert_eq(abilities.recharge_left(dash), 0.0)


func test_cooldown_speed_is_a_stat() -> void:
	var spell: AbilityData = mend(1.0)
	var quick := StatModifier.new()
	quick.stat = &"cooldown_speed"
	quick.percent = 1.0
	ComponentManager.of(caster).add_modifier(quick)
	abilities.use(spell)
	abilities._process(0.5)
	assert_eq(abilities.charges_left(spell), 1, "twice as fast")


func test_reset_cooldown_makes_it_ready() -> void:
	var spell: AbilityData = mend(30.0)
	abilities.use(spell)
	assert_false(abilities.can_use(spell))
	abilities.reset_cooldown(spell)
	assert_true(abilities.can_use(spell))


func test_conditions_decide_when_it_can_be_used() -> void:
	var last_stand: AbilityData = mend()
	var hurt := HealthBelowCondition.new()
	hurt.fraction = 0.5
	last_stand.conditions = [hurt]
	assert_eq(abilities.why_not(last_stand), &"condition")
	assert_false(abilities.use(last_stand))
	health.change(-70.0)
	assert_true(abilities.use(last_stand), "and the failed try spent no cooldown")
	assert_eq(health.current, 40.0)


func test_a_status_tag_blocks_the_ability() -> void:
	var spell: AbilityData = mend()
	spell.blocked_by_tags = [&"silenced"]
	var silenced: StatusData = tagged(&"silenced")
	statuses.add(silenced)
	assert_eq(abilities.why_not(spell), &"blocked")
	assert_true(abilities.can_use(mend()), "other abilities still work")
	statuses.remove(silenced)
	assert_true(abilities.use(spell))


func test_a_cast_takes_time_and_pays_at_the_end() -> void:
	var spell: AbilityData = mend()
	spell.cast_time = 0.5
	spell.costs = { &"mana": 10.0 }
	health.change(-50.0)
	watch_signals(abilities)
	assert_true(abilities.use(spell))
	assert_eq(abilities.casting, spell)
	assert_signal_emitted_with_parameters(abilities, "cast_started", [spell])
	assert_eq([health.current, mana.current], [50.0, 50.0], "nothing has happened yet")
	assert_eq(abilities.why_not(mend()), &"casting", "one cast at a time")
	abilities._process(0.3)
	assert_almost_eq(abilities.cast_progress(), 0.6, 0.001)
	assert_signal_not_emitted(abilities, "used")
	abilities._process(0.3)
	assert_null(abilities.casting)
	assert_signal_emitted_with_parameters(abilities, "used", [spell])
	assert_eq([health.current, mana.current], [60.0, 40.0])
	assert_false(abilities.can_use(spell), "the cooldown started when it fired")


func test_damage_can_interrupt_a_cast() -> void:
	var spell: AbilityData = mend()
	spell.cast_time = 1.0
	spell.costs = { &"mana": 10.0 }
	spell.interrupted_by_damage = true
	watch_signals(abilities)
	abilities.use(spell)
	var blow := DamageEffect.new()
	blow.apply(EffectContext.new(null, caster))
	assert_null(abilities.casting)
	assert_signal_emitted_with_parameters(abilities, "cast_interrupted", [spell])
	abilities._process(2.0)
	assert_signal_not_emitted(abilities, "used")
	assert_eq(mana.current, 50.0, "an interrupted cast costs nothing")
	assert_true(abilities.can_use(spell), "and starts no cooldown")


func test_a_blocking_status_interrupts_a_cast() -> void:
	var spell: AbilityData = mend()
	spell.cast_time = 1.0
	spell.blocked_by_tags = [&"silenced"]
	abilities.use(spell)
	statuses.add(tagged(&"silenced"))
	abilities._process(0.1)
	assert_null(abilities.casting)
	abilities.use(mend(0.0))
	assert_almost_eq(health.current, 100.0, 0.001)
	var long: AbilityData = mend()
	long.cast_time = 1.0
	abilities.use(long)
	statuses.add(tagged(&"stunned"))
	abilities._process(0.1)
	assert_null(abilities.casting, "so does a stun")


func test_a_status_is_held_for_as_long_as_the_cast() -> void:
	var rooted := StatusData.new()
	rooted.tags = [&"casting"]
	var spell: AbilityData = mend()
	spell.cast_time = 0.5
	spell.status_while_casting = rooted
	abilities.use(spell)
	assert_true(statuses.has_tag(&"casting"))
	abilities._process(0.6)
	assert_false(statuses.has_tag(&"casting"))
	abilities.reset_cooldown()
	abilities.use(spell)
	abilities.interrupt()
	assert_false(statuses.has_tag(&"casting"), "dropped on an interrupt too")


func test_an_ability_can_need_a_target() -> void:
	var friend: Node3D = make_host()
	(Component.of(friend, Health) as Health).change(-50.0)
	var nobody := FixedTargeting.new()
	var spell: AbilityData = mend()
	spell.targeting = nobody
	spell.costs = { &"mana": 10.0 }
	spell.needs_target = true
	assert_eq(abilities.why_not(spell), &"no_target")
	assert_false(abilities.use(spell))
	assert_eq(mana.current, 50.0)
	nobody.targets = [friend]
	assert_true(abilities.use(spell))
	assert_eq((Component.of(friend, Health) as Health).current, 60.0)
	nobody.targets = []
	spell.needs_target = false
	abilities.reset_cooldown()
	assert_true(abilities.use(spell), "without the setting it's used on nobody")
	assert_eq(mana.current, 30.0)


func test_user_effects_run_on_the_user() -> void:
	var enemy: Node3D = make_host()
	var at_enemy := FixedTargeting.new()
	at_enemy.targets = [enemy]
	var bite := DamageEffect.new()
	bite.amount = 20.0
	var drain: AbilityData = mend()
	drain.targeting = at_enemy
	drain.user_effects = drain.effects
	drain.effects = [bite]
	health.change(-50.0)
	abilities.use(drain)
	assert_eq((Component.of(enemy, Health) as Health).current, 80.0)
	assert_eq(health.current, 60.0, "the heal half of a life drain")


func test_statuses_can_react_to_abilities() -> void:
	var surge := HealEffect.new()
	surge.amount = 5.0
	var t := StatusTrigger.new()
	t.event = &"ability_used"
	t.effects = [surge]
	var battle_trance := StatusData.new()
	battle_trance.triggers = [t]
	statuses.add(battle_trance)
	health.change(-50.0)
	var seen: Array = []
	ComponentManager.of(caster).event(&"ability_used").connect(
			func(ctx: EffectContext) -> void: seen.append(ctx.origin))
	var spell: AbilityData = mend()
	abilities.use(spell)
	assert_eq(health.current, 65.0, "10 from the ability and 5 from the status")
	assert_eq(seen, [spell])


func test_a_pressed_action_uses_its_slot() -> void:
	var spell: AbilityData = mend()
	abilities.slots = { &"secondary": spell }
	health.change(-50.0)
	brain.press(&"secondary")
	for i in 3:
		await get_tree().process_frame
	brain.release(&"secondary")
	assert_eq(health.current, 60.0)
