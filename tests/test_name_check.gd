extends GutTest
## NameCheck flags stat, event and tag names nothing in the project recognizes.

const NameWarning = preload("res://addons/character_system_warnings/name_warning.gd")


func before_each() -> void:
	NameCheck.rescan()


func modifier(stat: StringName) -> StatModifier:
	var m := StatModifier.new()
	m.stat = stat
	return m


func trigger(event: StringName) -> StatusTrigger:
	var t := StatusTrigger.new()
	t.event = event
	return t


func test_finds_names_in_the_project() -> void:
	var stats: Array[StringName] = [
		&"max_health",
		&"move_speed",
		&"jump_velocity",
		&"air_jumps",
		&"cooldown_speed",
		# Listed in the stats of the example mage.
		&"spell_power",
		&"crit_chance",
		# From the example mage's two Pools.
		&"max_mana",
		&"mana_regen",
		&"max_shield",
		&"shield_regen",
	]
	for stat in stats:
		assert_has(NameCheck.known_stats(), String(stat))
	for pool_name in [&"mana", &"shield"]:
		assert_has(NameCheck.known_pools(), String(pool_name))
	var events: Array[StringName] = [
		&"started",
		&"died",
		&"taking_damage",
		&"took_damage",
		&"dealing_damage",
		&"dealt_damage",
		&"absorbing_damage",
		&"killed",
		&"revived",
		&"giving_healing",
		&"receiving_healing",
		&"gave_healing",
		&"received_healing",
		&"ability_cast_started",
		&"ability_used",
		&"ability_interrupted",
		&"inventory_changed",
		&"walk_mode_entered",
		&"air_mode_exited",
		&"wall_slide_mode_entered",
		&"dash_move_started",
		&"glide_move_finished",
	]
	for event in events:
		assert_has(NameCheck.known_events(), String(event))
	for tag in [&"fire", &"wet", &"poison", &"undead"]:
		assert_has(NameCheck.known_tags(), String(tag))


func test_known_stats_pass() -> void:
	assert_eq(NameCheck.problems(modifier(&"move_speed")).size(), 0)
	assert_eq(NameCheck.problems(modifier(&"resist_lightning")).size(), 0, "any resist_ stat")
	assert_eq(NameCheck.problems(modifier(&"bonus_lightning")).size(), 0, "any bonus_ stat")
	assert_eq(NameCheck.problems(modifier(&"max_mana")).size(), 0, "a pool's stats")
	assert_eq(NameCheck.problems(modifier(&"spell_power")).size(), 0, "a listed attribute")


func test_amounts_pools_and_abilities_are_checked() -> void:
	var scaling := StatAmount.new()
	scaling.stat = &"spel_power"
	var blow := DamageEffect.new()
	blow.scaling = [scaling]
	var found: PackedStringArray = NameCheck.problems(blow)
	assert_eq(found.size(), 1, "inside an effect")
	assert_string_contains(found[0], "Did you mean 'spell_power'?")
	var roll := ChanceCondition.new()
	assert_eq(NameCheck.problems(roll).size(), 0, "a bonus stat is optional")
	roll.bonus_stat = &"crit_chanse"
	assert_string_contains(NameCheck.problems(roll)[0], "Did you mean 'crit_chance'?")
	var draught := ChangePoolEffect.new()
	assert_eq(NameCheck.problems(draught).size(), 0)
	draught.pool = &"manna"
	assert_string_contains(NameCheck.problems(draught)[0], "Did you mean 'mana'?")
	var spell := AbilityData.new()
	spell.costs = { &"mana": 5.0, &"stamnia": 5.0 }
	spell.blocked_by = [&"abilities", &"spells", &"spels"]
	found = NameCheck.problems(spell)
	assert_eq(found.size(), 2)
	assert_string_contains(found[0], "'stamnia'")
	assert_string_contains(found[1], "Did you mean 'spells'?")
	var daze := StatusData.new()
	daze.blocks = [&"everything", &"spells", &"wepons"]
	found = NameCheck.problems(daze)
	assert_eq(found.size(), 1, "spells is known because the example Fireball answers to it")
	assert_string_contains(found[0], "Did you mean 'weapons'?")
	var cure := RemoveStatusEffect.new()
	cure.tag = &"poisn"
	assert_string_contains(NameCheck.problems(cure)[0], "Did you mean 'poison'?")
	var potion := ItemData.new()
	potion.use_effects = [draught]
	assert_eq(NameCheck.problems(potion).size(), 1, "an item's use effects")


func test_misspelled_stat_is_flagged_with_a_guess() -> void:
	var found: PackedStringArray = NameCheck.problems(modifier(&"move_sped"))
	assert_eq(found.size(), 1)
	assert_string_contains(found[0], "'move_sped'")
	assert_string_contains(found[0], "Did you mean 'move_speed'?")


func test_empty_stat_is_flagged() -> void:
	assert_string_contains(NameCheck.problems(modifier(&""))[0], "No stat set")


func test_stat_condition_is_checked() -> void:
	var c := StatCondition.new()
	c.stat = &"max_helth"
	assert_string_contains(NameCheck.problems(c)[0], "'max_health'")


func test_unknown_event_is_flagged() -> void:
	assert_eq(NameCheck.problems(trigger(&"took_damage")).size(), 0)
	var found: PackedStringArray = NameCheck.problems(trigger(&"took_damgae"))
	assert_eq(found.size(), 1)
	assert_string_contains(found[0], "Did you mean 'took_damage'?")


func test_unknown_tags_are_flagged() -> void:
	var s := StatusData.new()
	s.immune_to = [&"fire", &"fier"]
	s.removes_tags = [&"poison"]
	var found: PackedStringArray = NameCheck.problems(s)
	assert_eq(found.size(), 1)
	assert_string_contains(found[0], "Immune To")
	assert_string_contains(found[0], "'fier'")
	var c := HasTagCondition.new()
	c.tag = &"wett"
	assert_string_contains(NameCheck.problems(c)[0], "Did you mean 'wet'?")


func test_problems_deep_inside_a_status_are_found() -> void:
	var is_wet := HasTagCondition.new()
	is_wet.tag = &"wett"
	var hit := DamageEffect.new()
	var conditions: Array[Condition] = [is_wet]
	hit.conditions = conditions
	var t: StatusTrigger = trigger(&"took_damage")
	var effects: Array[Effect] = [hit]
	t.effects = effects
	var s := StatusData.new()
	var triggers: Array[StatusTrigger] = [t]
	s.triggers = triggers
	var mods: Array[StatModifier] = [modifier(&"move_sped")]
	s.modifiers = mods
	assert_eq(NameCheck.problems(s).size(), 2)


func test_statuses_saved_elsewhere_are_not_rechecked() -> void:
	var apply := ApplyStatusEffect.new()
	apply.status = load("res://character_system/starter_pack/statuses/burning.tres")
	assert_eq(NameCheck.problems(apply).size(), 0)


func test_every_example_is_clean() -> void:
	var paths: Array[String] = [
		"statuses/burning.tres",
		"statuses/wet.tres",
		"statuses/warded.tres",
		"statuses/thorns.tres",
		"traits/construct.tres",
		"abilities/sprint.tres",
		"abilities/fireball.tres",
		"statuses/vampiric.tres",
		"statuses/bloodlust.tres",
		"statuses/fire_ward.tres",
		"statuses/sharpshooter.tres",
		"statuses/lucky_strikes.tres",
		"items/health_potion.tres",
		"statuses/executioner.tres",
		"statuses/berserk.tres",
		"statuses/bleeding.tres",
		"abilities/shockwave.tres",
		"items/sword.tres",
		"items/rocket_launcher.tres",
		"items/marksman_rifle.tres",
		"items/soldier_rifle.tres",
		"items/mana_potion.tres",
		"items/grenade.tres",
	]
	for path in paths:
		var example: Resource = load("res://character_system/starter_pack/" + path)
		assert_eq(NameCheck.problems(example), PackedStringArray(), path)


func test_components_warn_about_their_resources() -> void:
	var bad := StatusData.new()
	var mods: Array[StatModifier] = [modifier(&"move_sped")]
	bad.modifiers = mods
	var statuses := Statuses.new()
	statuses.innate = [bad]
	assert_eq(statuses._warnings().size(), 1)
	var grant := Grants.new()
	grant.statuses = [bad]
	assert_eq(grant._warnings().size(), 1)
	var hitscan := Hitscan.new()
	var c := HasTagCondition.new()
	c.tag = &"wett"
	var hit := DamageEffect.new()
	hit.conditions = [c]
	hitscan.effects = [hit]
	assert_eq(hitscan._warnings().size(), 1)
	var trigger := Trigger.new()
	trigger.user_effects = [hit]
	assert_eq(trigger._warnings().size(), 1)
	for node in [statuses, grant, hitscan, trigger]:
		node.free()


func test_inspector_warning_shows_and_hides() -> void:
	var m: StatModifier = modifier(&"move_sped")
	var warning: Label = NameWarning.new()
	warning.target = m
	add_child_autofree(warning)
	assert_true(warning.visible)
	assert_string_contains(warning.text, "move_speed")
	m.stat = &"move_speed"
	warning.refresh()
	assert_false(warning.visible)
