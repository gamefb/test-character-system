extends GutTest
## Status rules: countering, blocking, holds, restrictions, stacking and zones.

var character: Node3D
var statuses: Statuses
var health: Health


func before_each() -> void:
	character = Node3D.new()
	for type in [ComponentManager, Statuses, Health]:
		character.add_child(type.new())
	add_child_autofree(character)
	statuses = Component.of(character, Statuses)
	health = Component.of(character, Health)


func make_status(tags: Array[StringName], duration := 0.0) -> StatusData:
	var s := StatusData.new()
	s.tags = tags
	s.duration = duration
	return s


func modifier(stat_name: StringName, add: float) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat_name
	m.add = add
	return m


func test_wet_puts_out_and_blocks_burning() -> void:
	var burning: StatusData = make_status([&"fire"], 4.0)
	var wet: StatusData = make_status([&"wet"], 10.0)
	wet.removes_tags = [&"fire"]
	wet.immune_to = [&"fire"]
	statuses.add(burning)
	statuses.add(wet)
	statuses.add(burning)
	assert_false(statuses.has_tag(&"fire"))


func test_passive_from_two_items_survives_removing_one() -> void:
	var haste: StatusData = make_status([&"haste"])
	statuses.add(haste)
	statuses.add(haste)
	statuses.drop_hold(haste)
	assert_true(statuses.has_tag(&"haste"))
	statuses.drop_hold(haste)
	assert_false(statuses.has_tag(&"haste"))


func test_resistance_never_heals() -> void:
	health.resistances = { &"fire": 0.5 }
	var fireproof: StatusData = make_status([])
	fireproof.modifiers = [modifier(&"resist_fire", 2.0)]
	statuses.add(fireproof)
	var hit := DamageEffect.new()
	hit.type = &"fire"
	hit.apply(EffectContext.new(null, character))
	assert_eq(health.current, 100.0)


func test_status_can_add_a_resistance_health_does_not_list() -> void:
	var fireproof: StatusData = make_status([])
	fireproof.modifiers = [modifier(&"resist_fire", 0.5)]
	statuses.add(fireproof)
	var hit := DamageEffect.new()
	hit.type = &"fire"
	hit.apply(EffectContext.new(null, character))
	assert_eq(health.current, 95.0)


func test_apply_condition_refuses_immune_target() -> void:
	var burning: StatusData = make_status([&"fire"], 4.0)
	var not_immune := StatCondition.new()
	not_immune.stat = &"resist_fire"
	not_immune.value = 1.0
	not_immune.negate = true
	burning.apply_conditions = [not_immune]
	assert_true(statuses.add(burning))
	statuses.remove(burning)
	health.resistances = { &"fire": 1.0 }
	watch_signals(statuses)
	assert_false(statuses.add(burning))
	assert_signal_emitted(statuses, "refused")


func test_immune_status_refuses_tagged_statuses() -> void:
	var wet: StatusData = make_status([&"wet"], 10.0)
	wet.immune_to = [&"fire"]
	statuses.add(wet)
	watch_signals(statuses)
	assert_false(statuses.add(make_status([&"fire"], 4.0)))
	assert_signal_emitted(statuses, "refused")
	assert_true(statuses.add(make_status([&"poison"], 4.0)), "other tags still land")


func test_trait_immunity_skips_tagged_statuses() -> void:
	# A trait is just a passive with a tag.
	var undead: StatusData = make_status([&"undead"])
	undead.immune_to = [&"poison"]
	statuses.add(undead)
	var poison: StatusData = make_status([&"poison"], 6.0)
	assert_false(poison.can_apply(character), "UI can ask before applying")
	assert_false(statuses.add(poison))


func test_immunity_ends_with_its_status() -> void:
	var fireproof: StatusData = make_status([&"fireproof"])
	fireproof.immune_to = [&"fire"]
	statuses.add(fireproof)
	var burning: StatusData = make_status([&"fire"], 4.0)
	assert_false(statuses.add(burning))
	# e.g. the cloak granting it is unequipped
	statuses.drop_hold(fireproof)
	assert_true(statuses.add(burning))


func test_gaining_immunity_keeps_existing_statuses_unless_removed() -> void:
	var burning: StatusData = make_status([&"fire"], 4.0)
	statuses.add(burning)
	var fireproof: StatusData = make_status([&"fireproof"])
	fireproof.immune_to = [&"fire"]
	statuses.add(fireproof)
	assert_true(statuses.has_tag(&"fire"), "immune_to only stops new ones")
	fireproof.removes_tags = [&"fire"]
	statuses.remove(fireproof)
	statuses.add(fireproof)
	assert_false(statuses.has_tag(&"fire"), "removes_tags clears the current one")


func test_stacks_scale_ticks_and_modifiers() -> void:
	var poison: StatusData = make_status([&"poison"], 6.0)
	poison.stacking = StatusData.Stacking.STACK
	poison.max_stacks = 3
	poison.tick_interval = 1.0
	var tick := DamageEffect.new()
	tick.amount = 2.0
	poison.on_tick = [tick]
	poison.modifiers = [modifier(&"max_health", -10.0)]
	for i in 4:
		statuses.add(poison)
	assert_eq(statuses.active[poison].stacks, 3, "capped at max_stacks")
	assert_eq(health.maximum(), 70.0)
	await wait_seconds(1.1)
	assert_eq(health.current, 64.0, "one tick of 2 damage per stack")


func test_only_processes_while_a_status_can_expire_or_tick() -> void:
	statuses.add(make_status([&"undead"]))
	assert_false(statuses.is_processing(), "passives need nothing per frame")
	var burning: StatusData = make_status([&"fire"], 4.0)
	statuses.add(burning)
	assert_true(statuses.is_processing())
	statuses.remove(burning)
	assert_false(statuses.is_processing())


func test_events_sent_without_a_context_reach_triggers() -> void:
	var t := StatusTrigger.new()
	t.event = &"level_up"
	t.effects = [DamageEffect.new()]
	var cursed: StatusData = make_status([&"curse"])
	cursed.triggers = [t]
	statuses.add(cursed)
	ComponentManager.notify(character, &"level_up")
	assert_eq(health.current, 90.0)


func test_zone_drops_only_the_hold_it_added() -> void:
	var water: StatusData = make_status([&"wet"])
	var zone := EffectZone.new()
	zone.status_while_inside = water
	add_child_autofree(zone)
	statuses.add(water)  # Another source already holds it.
	zone._on_body_entered(character)
	zone._on_body_exited(character)
	assert_true(statuses.has_tag(&"wet"))
	statuses.drop_hold(water)
	assert_false(statuses.has_tag(&"wet"))
