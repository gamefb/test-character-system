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
	for stat in [&"max_health", &"move_speed", &"jump_velocity"]:
		assert_has(NameCheck.known_stats(), String(stat))
	var events: Array[StringName] = [
		&"started",
		&"died",
		&"taking_damage",
		&"took_damage",
		&"dealing_damage",
		&"dealt_damage",
		&"inventory_changed",
	]
	for event in events:
		assert_has(NameCheck.known_events(), String(event))
	for tag in [&"fire", &"wet", &"poison", &"undead"]:
		assert_has(NameCheck.known_tags(), String(tag))


func test_known_stats_pass() -> void:
	assert_eq(NameCheck.problems(modifier(&"move_speed")).size(), 0)
	assert_eq(NameCheck.problems(modifier(&"resist_lightning")).size(), 0, "any resist_ stat")


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
	apply.status = load("res://character_system/examples/statuses/burning.tres")
	assert_eq(NameCheck.problems(apply).size(), 0)


func test_every_example_is_clean() -> void:
	var paths: Array[String] = [
		"statuses/burning.tres",
		"statuses/wet.tres",
		"statuses/warded.tres",
		"statuses/thorns.tres",
		"traits/construct.tres",
		"abilities/sprint.tres",
	]
	for path in paths:
		var example: Resource = load("res://character_system/examples/" + path)
		assert_eq(NameCheck.problems(example), PackedStringArray(), path)


func test_components_warn_about_their_resources() -> void:
	var bad := StatusData.new()
	var mods: Array[StatModifier] = [modifier(&"move_sped")]
	bad.modifiers = mods
	var statuses := Statuses.new()
	statuses.innate = [bad]
	assert_eq(statuses._warnings().size(), 1)
	var grant := GrantStatuses.new()
	grant.statuses = [bad]
	assert_eq(grant._warnings().size(), 1)
	var hitscan := Hitscan.new()
	var c := HasTagCondition.new()
	c.tag = &"wett"
	var hit := DamageEffect.new()
	hit.conditions = [c]
	hitscan.effects = [hit]
	assert_eq(hitscan._warnings().size(), 1)
	for node in [statuses, grant, hitscan]:
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
