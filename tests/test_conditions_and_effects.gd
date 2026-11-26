extends GutTest
## The conditions that roll dice, read the hit or offer alternatives, and where a spawned scene
## is put.


func make_host(parts: Array = []) -> Node3D:
	var host := Node3D.new()
	for node: Node in [ComponentManager.new(), Health.new(), Statuses.new()] + parts:
		host.add_child(node)
	add_child_autofree(host)
	return host


func tagged(tag: StringName) -> StatusData:
	var s := StatusData.new()
	s.tags = [tag]
	return s


func test_chance_runs_from_never_to_always() -> void:
	var who: Node3D = make_host()
	var ctx := EffectContext.new(null, who)
	var roll := ChanceCondition.new()
	roll.chance = 0.0
	var passes: int = 0
	for i in 50:
		passes += int(roll.check(ctx))
	assert_eq(passes, 0, "0 never passes")
	roll.chance = 1.0
	for i in 50:
		passes += int(roll.check(ctx))
	assert_eq(passes, 50, "1 always passes")
	roll.negate = true
	assert_false(roll.check(ctx))


func test_a_stat_adds_to_the_chance() -> void:
	var lucky: Node3D = make_host()
	ComponentManager.of(lucky).stats = { &"crit_chance": 1.0 }
	var plain: Node3D = make_host()
	var roll := ChanceCondition.new()
	roll.chance = 0.0
	roll.bonus_stat = &"crit_chance"
	assert_true(roll.check(EffectContext.new(null, lucky)))
	assert_false(roll.check(EffectContext.new(null, plain)), "no such stat: nothing is added")
	roll.subject = EffectContext.Role.SOURCE
	assert_true(roll.check(EffectContext.new(lucky, plain)), "the side Subject picks")


func test_any_condition_needs_only_one() -> void:
	var who: Node3D = make_host()
	var ctx := EffectContext.new(null, who)
	var wet := HasTagCondition.new()
	wet.tag = &"wet"
	var hurt := PoolBelowCondition.new()
	hurt.fraction = 0.5
	var either := AnyCondition.new()
	assert_false(either.check(ctx), "an empty list never passes")
	either.conditions = [wet, hurt]
	assert_false(either.check(ctx))
	Statuses.find_on(who).add(tagged(&"wet"))
	assert_true(either.check(ctx), "wet is enough")
	either.negate = true
	assert_false(either.check(ctx))
	assert_false(Condition.all_pass([wet, hurt], ctx), "a plain list needs both")


func test_hit_conditions_read_the_hit_inside_and_outside_a_trigger() -> void:
	var fire := HitCondition.new()
	fire.types = [&"fire", &"lightning"]
	var headshot := HitCondition.new()
	headshot.tags = [&"head"]
	var hit := EffectContext.new()
	hit.damage_type = &"lightning"
	hit.tags = [&"head"]
	assert_true(fire.check(hit))
	assert_true(headshot.check(hit))
	# What a status trigger's effects see: their own context, with the hit as its cause.
	var reaction := EffectContext.new()
	reaction.cause = hit
	assert_true(fire.check(reaction))
	assert_true(headshot.check(reaction))
	hit.damage_type = &"physical"
	hit.tags = []
	assert_false(fire.check(reaction))
	assert_false(headshot.check(reaction))
	fire.negate = true
	assert_true(fire.check(reaction), "anything but fire or lightning")


func test_a_scene_can_spawn_at_the_hit_point_or_the_source() -> void:
	var shooter: Node3D = make_host()
	shooter.position = Vector3(5, 0, 0)
	var target: Node3D = make_host()
	target.position = Vector3(0, 0, -4)
	# Spawned copies are renamed, so they're found by a child whose name stays.
	var marker := Node3D.new()
	var mark := Node3D.new()
	mark.name = "SparkMark"
	marker.add_child(mark)
	mark.owner = marker
	var scene := PackedScene.new()
	scene.pack(marker)
	marker.free()
	var spawn := SpawnSceneEffect.new()
	spawn.scene = scene
	for where: SpawnSceneEffect.Where in [
		SpawnSceneEffect.Where.TARGET,
		SpawnSceneEffect.Where.HIT_POINT,
		SpawnSceneEffect.Where.SOURCE,
	]:
		spawn.at = where
		var ctx := EffectContext.new(shooter, target)
		ctx.position = Vector3(0, 1.5, -3.5)
		spawn.apply(ctx)
	# No point was recorded for this one, so it falls back to the target.
	spawn.at = SpawnSceneEffect.Where.HIT_POINT
	spawn.apply(EffectContext.new(shooter, target))
	await get_tree().process_frame
	var places: Array[Vector3] = []
	for node: Node3D in get_tree().root.find_children("SparkMark", "Node3D", true, false):
		places.append(node.global_position)
		node.get_parent().queue_free()
	var expected: Array[Vector3] = [
		Vector3(0, 0, -4),
		Vector3(0, 1.5, -3.5),
		Vector3(5, 0, 0),
		Vector3(0, 0, -4),
	]
	assert_eq(places, expected, "the target, the hit point, the source, then the target again")


## Everything the docs call safe on a freed node, tried on one. A script error in here would
## end the function early, and the caller would get null instead of the list.
func lookups_on(node: Variant) -> Array:
	var out: Array = [
		Component.of(node, Health),
		ComponentManager.of(node),
		ComponentManager.stat_of(node, &"max_health"),
		Pool.named(node, &"mana"),
		Hurtbox.rids_of(node).size(),
		EffectContext.new(node, node).source,
		Hurtbox.hit(node, null).source,
	]
	ComponentManager.notify(node, &"ping")
	return out


func test_lookups_accept_a_node_that_was_just_freed() -> void:
	var gone: Node3D = make_host()
	var faction := Faction.new()
	faction.hostile_to = [&"enemy"]
	make_host([faction])
	gone.free()
	assert_eq(lookups_on(gone), [null, null, 0.0, null, 0, null, null])
	assert_eq(lookups_on(null), [null, null, 0.0, null, 0, null, null])
	assert_false(faction.is_hostile(gone))
